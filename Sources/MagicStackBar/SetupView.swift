import SwiftUI

/// 初回セットアップ / 設定画面。
/// 機密データ（スケジュール・顧客情報）はプライベートリポジトリに置く前提のため、
/// 連携先リポジトリの指定と検証をここで行う。
struct SetupView: View {
  @EnvironmentObject var state: AppState

  @State private var repoInput = ""
  @State private var validationMessage: String?
  @State private var validationOK = false
  @State private var ghAuthenticated: Bool?

  var body: some View {
    Form {
      Section("1. GitHub CLI") {
        HStack {
          switch ghAuthenticated {
          case .some(true):
            Label("gh CLI 認証済み", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          case .some(false):
            Label(
              "gh CLI が未認証です。ターミナルで `gh auth login` を実行してください",
              systemImage: "xmark.circle.fill"
            )
            .foregroundStyle(.red)
          case .none:
            ProgressView().controlSize(.small)
          }
          Spacer()
          Button("再確認") { checkAuth() }
        }
      }

      Section("2. 連携先リポジトリ（プライベート推奨）") {
        TextField("owner/repo", text: $repoInput, prompt: Text("例: maishu-kobo/smart-scheduler"))
          .textFieldStyle(.roundedBorder)
        HStack {
          Button("接続を検証") { validate() }
            .disabled(repoInput.isEmpty)
          if let message = validationMessage {
            Text(message)
              .font(.caption)
              .foregroundStyle(validationOK ? .green : .red)
          }
        }
      }

      Section("3. あなたの情報") {
        TextField("講師名（日本語）", text: state.$instructorName, prompt: Text("例: 佐藤花子"))
        TextField(
          "ファイル名スラッグ（半角英数とハイフン）", text: state.$instructorSlug,
          prompt: Text("例: sato-hanako")
        )
        Text("空き状況は schedule/availability/<スラッグ>.json に公開されます。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 480)
    .padding(.bottom, 8)
    .onAppear {
      repoInput = state.repoFullName
      checkAuth()
    }
  }

  private func checkAuth() {
    ghAuthenticated = nil
    Task.detached {
      let ok = GitHubClient.isAuthenticated()
      await MainActor.run { ghAuthenticated = ok }
    }
  }

  private func validate() {
    validationMessage = "検証中..."
    validationOK = false
    let repo = repoInput.trimmingCharacters(in: .whitespaces)
    Task.detached {
      do {
        let result = try GitHubClient.validateRepo(repo)
        await MainActor.run {
          state.repoFullName = repo
          if result.visibility.uppercased() == "PRIVATE" {
            validationMessage = "接続 OK（プライベートリポジトリ）"
          } else {
            validationMessage = "接続 OK。ただし公開リポジトリです。機密情報を扱う場合はプライベートにしてください"
          }
          validationOK = true
        }
      } catch {
        await MainActor.run {
          validationMessage = error.localizedDescription
          validationOK = false
        }
      }
    }
  }
}
