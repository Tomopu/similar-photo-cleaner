# SimilarPhotoCleaner

iPhoneのカメラロールから似た写真やスクリーンショットを見つけ、残す1枚を提案して削除を手伝うiOSアプリ。解析はすべて端末内で行う。

## 開発環境

- Xcode 26 / iOS 26 以上
- `SimilarPhotoCleaner.xcodeproj` を開き、スキーム `SimilarPhotoCleaner` で実行・テスト（Swift Testing）

```bash
xcodebuild test -project SimilarPhotoCleaner.xcodeproj -scheme SimilarPhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 17'
```

## ドキュメント

- [PRD（プロダクト要求仕様）](docs/PRD.md)
- 図: `docs/figure/*.png`（元になる mermaid ソースは `docs/figure/src/*.mmd`）
- 旧 AlbumCleaner の要件メモ: `docs/archive/AlbumCleaner/`（参考用。現行の仕様は PRD）

## 図の再生成

`docs/figure/src/*.mmd` を編集したら、次のコマンドでPNGを作り直す（`@mermaid-js/mermaid-cli` と Google Chrome が必要）。

```bash
./scripts/render_figures.sh
```
