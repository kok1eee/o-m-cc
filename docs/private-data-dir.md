# 私的データ層の分離（`O_M_CC_DATA_DIR`）

## 背景

`atoms.csv` / `pipeline.csv` / `outputs.csv`（および `journal.md`）は**個人の開発バックログ・作業記録**で、内部 app 名や作業文脈を含む。これらが公開される o-m-cc repo の `.claude/` にコミットされると**誰でも見られる状態**になる。「公開プラグイン（機構）」と「私的データ（バックログ）」は privacy 要件が違うので分離する。

## 仕組み

環境変数 `O_M_CC_DATA_DIR` を**私的な場所**のパスに設定すると、`bin/atoms` / `bin/atom-suggest` / `bin/edd-check` はそこを読み書きする。未設定なら後方互換で `<repo root>/.claude`。

```
公開 o-m-cc repo            = 機構（bin / hooks / skills / agents）。データは持たない
O_M_CC_DATA_DIR（私的な場所） = atoms.csv / pipeline.csv / outputs.csv
                             → そこの git で cross-machine 同期・定期改善
```

## どこに置くか — 2 つのパターン

### パターン A: 既存の private dotfiles に同居（推奨・最小構成）

**`~/.claude` を private な dotfiles に symlink している場合**、`${CLAUDE_PLUGIN_DATA}`（= `~/.claude/plugins/data/<plugin-id>/`）は既に dotfiles 同期下にある。ここを `O_M_CC_DATA_DIR` にすれば、**新しい repo を作らずに** atoms を analytics と同じ dir に集約でき、cross-machine 同期も既存の dotfiles 同期にそのまま乗る。

```bash
# ~/.claude が dotfiles symlink なら、CLAUDE_PLUGIN_DATA の dir をそのまま使う
export O_M_CC_DATA_DIR="$HOME/.claude/plugins/data/<plugin-id>"   # 例: o-m-cc-kok1eee
```

- merge=union: dotfiles の `.gitattributes` に `**/*.csv merge=union`（または該当 dir）があれば、Mac/EC2 の並行追記が両側保持される。
- analytics（`skill-usage.csv` 等）も同 dir なので、`bin/sync-plugin-data` の per-file symlink は不要（whole-dir symlink が同期を担う）。

### パターン B: 専用の private リポ

dotfiles を使わない / 分離したい場合は専用の private git リポを用意する。

```bash
mkdir -p ~/o-m-cc-data && cd ~/o-m-cc-data && jj git init   # or git init
printf '*.csv merge=union\n' > .gitattributes               # 並行追記の両側保持
export O_M_CC_DATA_DIR="$HOME/o-m-cc-data"
```

## env var は `.zshenv` に置く（重要）

`O_M_CC_DATA_DIR` は **`.zshenv`** に書く（`.zshrc` ではない）。理由: Claude Code の Bash ツール・hooks は**非対話 zsh** で動き、非対話 zsh は `.zshrc` を source せず `.zshenv` のみ source する。`.zshrc` に置くと `bin/atoms` を Claude が叩いたときに env var が見えず、公開 repo 側 `.claude` にフォールバックしてしまう。dotfiles 管理なら `.zshenv` 実体を dotfiles に置き、`~/.zshenv` から symlink して全マシンに同期する。

## 移行手順

```bash
# 1. 既存データを O_M_CC_DATA_DIR にコピー（o-m-cc repo の .claude から）
cp <o-m-cc>/.claude/{atoms,pipeline,outputs}.csv "$O_M_CC_DATA_DIR/"

# 2. env var を .zshenv に設定（上記）→ 新しいシェルで反映

# 3. 動作確認（私的な場所を読むはず）
bin/atoms list

# 4. o-m-cc repo 側の tracked データを除去（移行確認後）
#    .gitignore に追加済みなら、ファイル削除 or `jj file untrack`
```

## cross-machine 運用

各マシンで private な置き場（dotfiles or 専用リポ）の git を `pull` → 作業 → `commit && push`。append-only CSV なので `merge=union` でほぼ自動解決（重複行は `sort -u` で除去可）。これで atoms の定期改善が公開 repo を汚さずに回る。

## 過去履歴について

既に公開 repo の git 履歴に過去の `atoms.csv` が残っている。トークン等の**秘密**が含まれていた場合は履歴書き換え + ローテーションが必要（別途対応）。秘密でないバックログテキストは「以後 untrack で十分」とする判断もある。

## 補足: journal.md / analytics のスコープ

- **`journal.md`**: `/handoff` はどの repo でも `.claude/journal.md` に書く（**per-project** 設計）。`O_M_CC_DATA_DIR`（o-m-cc 固有の var）にルートすると全プロジェクトの journal が混ざるため**使わない**。o-m-cc は公開 repo なので**自身の journal.md を `.gitignore`** して local 扱いにする（他プロジェクトでは各 repo で VCS 共有される設計は不変）。
- **analytics（`skill-usage.csv` 等）**: `${CLAUDE_PLUGIN_DATA}`（repo 外）にあり privacy 問題はない。パターン A で `O_M_CC_DATA_DIR = CLAUDE_PLUGIN_DATA` にすると atoms と自然に統一される。
