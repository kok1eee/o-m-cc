# 私的データ層の分離（`O_M_CC_DATA_DIR`）

## 背景

`atoms.csv` / `pipeline.csv` / `outputs.csv`（および `journal.md`）は**個人の開発バックログ・作業記録**で、内部 app 名や作業文脈を含む。これらが公開される o-m-cc repo の `.claude/` にコミットされると、**誰でも見られる状態**になる。

「公開プラグイン（機構）」と「私的データ（バックログ）」は privacy 要件が違うので分離する。

## 仕組み

環境変数 `O_M_CC_DATA_DIR` を**私的リポ**のパスに設定すると、`bin/atoms` / `bin/atom-suggest` / `bin/edd-check` はそこを読み書きする。未設定なら後方互換で `<repo root>/.claude`。

```
公開 o-m-cc repo         = 機構（bin / hooks / skills / agents）。データは持たない
私的データリポ (O_M_CC_DATA_DIR) = atoms.csv / pipeline.csv / outputs.csv
                                  → このリポの git で cross-machine 同期・定期改善
```

## 移行手順

```bash
# 1. 私的 git リポを用意（GitHub private 推奨）
mkdir -p ~/o-m-cc-data && cd ~/o-m-cc-data && git init   # or jj git init

# 2. 既存データを移す（o-m-cc repo の .claude から）
cp ~/masayoshi/o-m-cc/.claude/atoms.csv    ~/o-m-cc-data/
cp ~/masayoshi/o-m-cc/.claude/pipeline.csv ~/o-m-cc-data/
cp ~/masayoshi/o-m-cc/.claude/outputs.csv  ~/o-m-cc-data/
cd ~/o-m-cc-data && git add . && git commit -m "init: o-m-cc 私的データ層" && git push  # private remote

# 3. 全マシンの shell 設定に env var を追加（~/.zshrc 等）
export O_M_CC_DATA_DIR="$HOME/o-m-cc-data"

# 4. 動作確認（私的リポ側を読むはず）
bin/atoms list

# 5. o-m-cc repo 側の tracked データを除去（私的リポへの移行を確認してから）
cd ~/masayoshi/o-m-cc
#   jj: gitignore 済みなら jj file untrack .claude/atoms.csv .claude/pipeline.csv .claude/outputs.csv
#   （ファイルはディスクに残り、repo の追跡からのみ外れる）
```

## cross-machine 運用

私的リポの git で同期する。append-only CSV なので衝突は起きにくいが、複数マシンで並行追記するなら `.gitattributes` に下記を入れて両側の追記行を保持する:

```
*.csv merge=union
```

各マシンで `git pull` → 作業 → `git commit && git push`。これで atoms の定期改善が公開 repo を汚さずに回る。

## 過去履歴について

既に公開 repo の git 履歴に過去の `atoms.csv` が残っている。トークン等の**秘密**が含まれていた場合は履歴書き換え + ローテーションが必要（別途対応）。秘密でないバックログテキストは「以後 untrack で十分」とする判断もある。

## 補足: journal.md / analytics は別スコープ

- **`journal.md`**: `/handoff` がプロジェクト repo の `.claude/journal.md` に書く（per-project、cross-machine handoff 用に VCS 共有が設計）。o-m-cc 自身の journal を私的化するかは handoff の cross-machine トレードオフと併せて別途判断。
- **analytics（`skill-usage.csv` 等）**: `${CLAUDE_PLUGIN_DATA}`（per-machine、repo 外）にあり privacy 問題はない。cross-machine 同期は `bin/sync-plugin-data`（dotfiles 経由）。これを `O_M_CC_DATA_DIR` に集約して dotfiles ハックを退役させるのは次段の課題。
