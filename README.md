# MagicStackBar

Magic Stack 研修の日程調整を Mac のメニューバーから行うアプリ。バックエンドは持たず、プライベートな調整リポジトリ(GitHub Issue + `schedule/` ディレクトリ)と `gh` CLI 経由で連携する。

## できること

- カレンダー.app(に同期された Outlook / Google 含む)から空き日を計算し、調整リポジトリの `schedule/availability/<自分>.json` に公開する
- 調整中の案件(`scheduling` ラベルの Issue)と候補日をメニューバーに表示する
- 候補日と会議室を選んで確定する(`/confirm` コメントを投稿。検証は リポジトリ側の GitHub Actions が実施)

## インストール

```bash
brew install gh && gh auth login   # 未認証の場合
brew tap maishu-kobo/tap
brew install --cask magic-stack-bar
```

アドホック署名のため、初回は Finder で右クリック > 開く で起動する。

## 初回セットアップ

1. メニューバーのカレンダーアイコン > 「初回セットアップ...」を開く
2. gh CLI の認証状態を確認する
3. 連携先リポジトリ(`owner/repo`)を入力して「接続を検証」する。スケジュールと顧客情報が入るためプライベートリポジトリを推奨
4. 講師名とスラッグ(空き状況のファイル名)を入力する
5. 「カレンダーから空き状況を公開」を初回実行時、カレンダーへのアクセスを許可する

## 設計

- トークンはアプリに保存しない。すべて `gh` CLI の認証に相乗りする
- 空き日の定義は「平日で 9:00〜18:00 に予定がない日」。今後 60 日分を公開する
- 確定の検証(ダブルブッキング等)はアプリでは行わず、調整リポジトリの Actions に委譲する

## 開発

```bash
swift build               # ビルド
swift run                 # 起動（メニューバーに表示される）
./scripts/build-app.sh 0.1.0   # .app バンドル + zip 作成
```

リリースは `v*` タグを push すると GitHub Actions が .app を添付した Release を作成する。
