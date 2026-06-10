import SwiftUI

@main
struct MagicStackBarApp: App {
  @StateObject private var state = AppState()
  @Environment(\.openSettings) private var openSettings

  var body: some Scene {
    MenuBarExtra {
      MenuContent()
        .environmentObject(state)
    } label: {
      Image(systemName: state.issues.isEmpty ? "calendar.badge.clock" : "calendar.badge.exclamationmark")
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SetupView()
        .environmentObject(state)
    }
  }
}

struct MenuContent: View {
  @EnvironmentObject var state: AppState
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Group {
      if !state.isConfigured {
        Button("初回セットアップ...") { openSettings() }
      } else {
        issuesSection
        Divider()
        Button("カレンダーから空き状況を公開") {
          Task { await state.publishAvailability() }
        }
        .disabled(state.isBusy)
        Button("最新の状態に更新") {
          Task { await state.refresh() }
        }
        .disabled(state.isBusy)
      }

      if let message = state.statusMessage {
        Divider()
        Text(message)
      }

      Divider()
      Button("設定...") { openSettings() }
      Button("リポジトリを開く") {
        if let url = URL(string: "https://github.com/\(state.repoFullName)") {
          NSWorkspace.shared.open(url)
        }
      }
      .disabled(state.repoFullName.isEmpty)
      Divider()
      Button("MagicStackBar を終了") { NSApplication.shared.terminate(nil) }
    }
    .task {
      if state.isConfigured {
        await state.refresh()
      }
    }
  }

  @ViewBuilder
  private var issuesSection: some View {
    if state.issues.isEmpty {
      Text("調整中の案件はありません")
    } else {
      Text("調整中の案件（\(state.issues.count) 件）")
      ForEach(state.issues) { issue in
        Menu("#\(issue.number) \(issue.title)") {
          let candidates = state.candidatesByIssue[issue.number] ?? []
          if candidates.isEmpty {
            Text("候補が見つかりません")
          } else {
            ForEach(candidates) { candidate in
              Menu(candidate.label) {
                Button("オンラインで確定") {
                  Task { await state.confirm(issue: issue, candidate: candidate, roomId: nil) }
                }
                ForEach(state.rooms) { room in
                  Button("\(room.name)（\(room.capacity) 名）で確定") {
                    Task {
                      await state.confirm(issue: issue, candidate: candidate, roomId: room.id)
                    }
                  }
                }
              }
            }
          }
          Divider()
          Button("Issue を開く") {
            if let url = URL(string: "https://github.com/\(state.repoFullName)/issues/\(issue.number)") {
              NSWorkspace.shared.open(url)
            }
          }
        }
      }
    }
  }
}
