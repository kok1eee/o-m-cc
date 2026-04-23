# Releasing & Testing

o-m-cc の検証・デプロイ手順。CLAUDE.md から分離した詳細情報。

## テスト・検証

```bash
# hooks.json の構文チェック
jq . hooks/hooks.json

# エージェント定義の frontmatter 確認
head -10 agents/*.md

# lint（言語別、bin/ 経由）
bin/lint

# plan ドキュメントの形式検証
bin/validate-plan requirements
bin/validate-plan design
```

## デプロイ手順

1. **バージョンを更新**（`plugin.json`, `marketplace.json`, `README.md` のタイトル + Changelog）
2. **コミット & プッシュ**:
   ```bash
   jj describe -m "chore: bump to vX.Y.Z — <variation>"
   jj bookmark set main -r @
   jj git push
   ```
3. **Git tag を作成**（Claude Code 2.1.118+、version 整合性を自動検証）:
   ```bash
   # dry-run で tag 名と push 先を確認
   claude plugin tag --dry-run
   # 問題なければ tag 作成 + origin へ push
   claude plugin tag --push
   ```
   - tag 形式: `o-m-cc--v0.X.Y`（plugin name + `--v` + version）
   - `plugin.json` と `marketplace.json` の version 一致を自動検証（不一致ならエラー）
   - `agents/*.md` の frontmatter 欠落も警告（例: `capabilities.md` は frontmatter 必須）
4. **プラグイン更新**（ローカル環境で反映）:
   ```bash
   claude plugin update o-m-cc@kok1eee
   # → "Restart to apply changes" が出るので Claude Code を再起動
   ```

## バージョン規約

- **patch** (0.X.Y → 0.X.Y+1): バグ修正、ドキュメント更新のみ
- **minor** (0.X.Y → 0.X+1.0): 新機能追加、新 hook / skill 追加、後方互換あり
- **major** (現在は 0.x): 破壊的変更（現状は 0.x のまま）

version bump は必ず **独立した `chore: bump to vX.Y.Z` commit** にする。feature commit にバージョン bump を混ぜない（過去の 0.32.0〜0.34.0 で崩れた慣習の反省）。

## リリース後の確認

```bash
# remote と local が同期しているか
jj log -r 'main@origin | main' --no-graph -T 'change_id.short() ++ " " ++ bookmarks ++ "\n"'

# installed plugin version
jq '.plugins."o-m-cc@kok1eee"[0].version' ~/.claude/plugins/installed_plugins.json
```
