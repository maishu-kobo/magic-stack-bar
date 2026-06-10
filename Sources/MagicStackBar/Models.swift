import Foundation

struct SchedulingIssue: Codable, Identifiable, Hashable {
  let number: Int
  let title: String

  var id: Int { number }
}

struct Candidate: Codable, Identifiable, Hashable {
  let index: Int
  let startDate: String
  let endDate: String
  let instructor: String

  var id: Int { index }

  var label: String {
    "候補\(index): \(startDate)〜\(endDate)（\(instructor)）"
  }
}

struct Room: Codable, Identifiable, Hashable {
  let id: String
  let name: String
  let capacity: Int
  let location: String?
}

enum AppError: LocalizedError {
  case ghNotFound
  case ghFailed(String)
  case notConfigured
  case calendarDenied

  var errorDescription: String? {
    switch self {
    case .ghNotFound:
      return "gh CLI が見つかりません。`brew install gh` でインストールし、`gh auth login` で認証してください。"
    case .ghFailed(let message):
      return "GitHub の操作に失敗しました: \(message)"
    case .notConfigured:
      return "連携先リポジトリが未設定です。設定画面からセットアップしてください。"
    case .calendarDenied:
      return "カレンダーへのアクセスが許可されていません。システム設定 > プライバシーとセキュリティ > カレンダー で許可してください。"
    }
  }
}
