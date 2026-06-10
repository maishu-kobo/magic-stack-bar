import Foundation

/// gh CLI のラッパー。メンバーの既存の `gh auth login` 認証に相乗りするため、
/// アプリ側ではトークンを一切保存しない（プライベートリポジトリ前提の設計）。
struct GitHubClient {
  let repo: String

  // MARK: - gh CLI 実行

  @discardableResult
  static func runGH(_ arguments: [String], stdin: Data? = nil) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["gh"] + arguments

    var environment = ProcessInfo.processInfo.environment
    let extraPaths = "/opt/homebrew/bin:/usr/local/bin"
    environment["PATH"] = "\(extraPaths):\(environment["PATH"] ?? "/usr/bin:/bin")"
    process.environment = environment

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    if let stdin {
      let stdinPipe = Pipe()
      process.standardInput = stdinPipe
      stdinPipe.fileHandleForWriting.write(stdin)
      stdinPipe.fileHandleForWriting.closeFile()
    }

    do {
      try process.run()
    } catch {
      throw AppError.ghNotFound
    }
    process.waitUntilExit()

    let output = stdout.fileHandleForReading.readDataToEndOfFile()
    if process.terminationStatus != 0 {
      let message = String(
        data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8
      ) ?? "unknown error"
      throw AppError.ghFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return output
  }

  static func isAuthenticated() -> Bool {
    (try? runGH(["auth", "status"])) != nil
  }

  /// セットアップフロー用: リポジトリにアクセスできるか + プライベートかを検証する
  static func validateRepo(_ repo: String) throws -> (visibility: String, ok: Bool) {
    let data = try runGH(["repo", "view", repo, "--json", "visibility"])
    struct RepoInfo: Codable { let visibility: String }
    let info = try JSONDecoder().decode(RepoInfo.self, from: data)
    return (info.visibility, true)
  }

  // MARK: - 調整フロー

  func listSchedulingIssues() throws -> [SchedulingIssue] {
    let data = try Self.runGH([
      "issue", "list", "--repo", repo,
      "--label", "scheduling", "--state", "open",
      "--json", "number,title", "--limit", "20",
    ])
    return try JSONDecoder().decode([SchedulingIssue].self, from: data)
  }

  /// Issue コメントから機械可読マーカー（magic-scheduler:candidates）の候補を取り出す
  func fetchCandidates(issueNumber: Int) throws -> [Candidate] {
    let data = try Self.runGH([
      "api", "repos/\(repo)/issues/\(issueNumber)/comments",
      "--paginate", "--jq", "[.[].body]",
    ])
    let bodies = try JSONDecoder().decode([String].self, from: data)
    let pattern = #"<!-- magic-scheduler:candidates (\[.*?\]) -->"#
    let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])

    for body in bodies.reversed() {
      let range = NSRange(body.startIndex..., in: body)
      guard let match = regex.firstMatch(in: body, range: range),
        let jsonRange = Range(match.range(at: 1), in: body),
        let jsonData = body[jsonRange].data(using: .utf8)
      else { continue }
      if let candidates = try? JSONDecoder().decode([Candidate].self, from: jsonData) {
        return candidates
      }
    }
    return []
  }

  func fetchRooms() throws -> [Room] {
    let data = try Self.runGH([
      "api", "-H", "Accept: application/vnd.github.raw",
      "repos/\(repo)/contents/schedule/rooms.json",
    ])
    return try JSONDecoder().decode([Room].self, from: data)
  }

  /// /confirm コメントを投稿する（検証と bookings.json 更新はリポジトリ側の Actions が行う）
  func postConfirm(issueNumber: Int, candidateIndex: Int, roomId: String?) throws {
    let body = roomId.map { "/confirm 候補\(candidateIndex) \($0)" }
      ?? "/confirm 候補\(candidateIndex)"
    try Self.runGH([
      "issue", "comment", "\(issueNumber)", "--repo", repo, "--body", body,
    ])
  }

  // MARK: - 空き状況の公開

  /// schedule/availability/<slug>.json を Contents API で作成・更新する
  func publishAvailability(slug: String, name: String, freeDates: [String]) throws {
    struct Payload: Codable {
      let name: String
      let updatedAt: String
      let freeDates: [String]
    }
    let formatter = ISO8601DateFormatter()
    let payload = Payload(
      name: name, updatedAt: formatter.string(from: Date()), freeDates: freeDates
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let json = try encoder.encode(payload)
    let content = (String(data: json, encoding: .utf8)! + "\n")
      .data(using: .utf8)!.base64EncodedString()

    let path = "schedule/availability/\(slug).json"

    // 既存ファイルの sha を取得（新規作成なら不要）
    var sha: String?
    if let existing = try? Self.runGH([
      "api", "repos/\(repo)/contents/\(path)", "--jq", ".sha",
    ]) {
      sha = String(data: existing, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var args = [
      "api", "-X", "PUT", "repos/\(repo)/contents/\(path)",
      "-f", "message=chore(schedule): \(name) の空き状況を更新",
      "-f", "content=\(content)",
    ]
    if let sha, !sha.isEmpty {
      args += ["-f", "sha=\(sha)"]
    }
    try Self.runGH(args)
  }
}
