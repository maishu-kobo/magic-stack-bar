import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
  // 連携先の設定（プライベートな調整リポジトリ）
  @AppStorage("repoFullName") var repoFullName: String = ""
  @AppStorage("instructorName") var instructorName: String = ""
  @AppStorage("instructorSlug") var instructorSlug: String = ""

  @Published var issues: [SchedulingIssue] = []
  @Published var candidatesByIssue: [Int: [Candidate]] = [:]
  @Published var rooms: [Room] = []
  @Published var statusMessage: String?
  @Published var lastRefreshed: Date?
  @Published var isBusy = false

  var isConfigured: Bool {
    !repoFullName.isEmpty && !instructorName.isEmpty && !instructorSlug.isEmpty
  }

  private var client: GitHubClient? {
    repoFullName.isEmpty ? nil : GitHubClient(repo: repoFullName)
  }

  func refresh() async {
    guard let client else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      let issues = try await Task.detached { try client.listSchedulingIssues() }.value
      let rooms = try await Task.detached { try client.fetchRooms() }.value
      var candidates: [Int: [Candidate]] = [:]
      for issue in issues {
        candidates[issue.number] = try await Task.detached {
          try client.fetchCandidates(issueNumber: issue.number)
        }.value
      }
      self.issues = issues
      self.rooms = rooms
      self.candidatesByIssue = candidates
      self.lastRefreshed = Date()
      self.statusMessage = nil
    } catch {
      self.statusMessage = error.localizedDescription
    }
  }

  func confirm(issue: SchedulingIssue, candidate: Candidate, roomId: String?) async {
    guard let client else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      try await Task.detached {
        try client.postConfirm(
          issueNumber: issue.number, candidateIndex: candidate.index, roomId: roomId
        )
      }.value
      statusMessage = "Issue #\(issue.number) に確定コメントを送信しました"
      await refresh()
    } catch {
      statusMessage = error.localizedDescription
    }
  }

  func publishAvailability() async {
    guard let client, isConfigured else {
      statusMessage = AppError.notConfigured.localizedDescription
      return
    }
    isBusy = true
    defer { isBusy = false }
    do {
      let service = CalendarService()
      try await service.requestAccess()
      let dates = service.freeDates()
      let name = instructorName
      let slug = instructorSlug
      try await Task.detached {
        try client.publishAvailability(slug: slug, name: name, freeDates: dates)
      }.value
      statusMessage = "空き \(dates.count) 日分を公開しました"
    } catch {
      statusMessage = error.localizedDescription
    }
  }
}
