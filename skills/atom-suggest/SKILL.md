---
name: atom-suggest
description: "atoms.csv / pipeline.csv / outputs.csv / skill-usage.csv / skill-duration.csv / context.md を統合分析し、backlog 俯瞰 + skill ヘルス（top/duration/unused）を 1 レポートで提示する。kawai 氏型 analytics ループの起点。「次に何やる？」「atom 整理」「放置案件」「stale」「振り返り」「retro」「skill 使用統計」「unused skill」「atom-suggest」で発動。"
allowed-tools: [Read, Bash, Edit]
effort: low
---

# Atom-Suggest - analytics 駆動の次アクション提案

`bin/atom-suggest` を実行して、データレイヤーの状態から「次にやるべきこと」を抽出する。

## データソース（CSV 統一済み）

- `.claude/atoms.csv` — アイデアバックログ
- `.claude/pipeline.csv` — 要件化フェーズ
- `.claude/outputs.csv` — 完了履歴
- `${CLAUDE_PLUGIN_DATA}/skill-usage.csv` — skill 使用ログ
- `${CLAUDE_PLUGIN_DATA}/skill-duration.csv` — skill 実行時間ログ
- `.claude/context.md` — セッション間引き継ぎ（Next 欄）

## 提案カテゴリ

**Backlog issues**（要件化判断）

| カテゴリ | 検出条件 | アクション例 |
|---|---|---|
| stale-atoms | 30 日以上 atom 状態 | archive 化 or pipeline 昇格判断 |
| promote-ready | next に具体的 action verb | `bin/atoms promote <id>` |
| stuck-pipeline | 14 日以上 status 変化なし | ブロッカー特定 or 取り下げ |
| orphan-next | context.md Next にあるが atoms に無い | atoms に登録 or 無視確認 |

**Skill health**（プラグイン保守）

| カテゴリ | 検出条件 | アクション例 |
|---|---|---|
| top-skills | 累計使用回数 top 10 | 使用頻度の把握 |
| duration-stats | 実行時間 sum_ms 降順 top 10 | 重い skill の最適化候補 |
| unused-skills | 累計使用 ≤ 1 回 | description 改善 or 削除判断 |
| gotcha-ranking | AUTO-GOTCHAS 直近 30 日 + 累計 | 累計多 = `bin/atoms add` で atom 化候補 |

**Activity pulse**（直近 7 日）

| カテゴリ | 検出条件 | アクション例 |
|---|---|---|
| recent-atoms | 直近 7 日に追加された atom | 引き継ぎ参考 |
| recent-skills | 直近 7 日のトップ skill | 集中分野の把握 |

## 実行

!`CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" bin/atom-suggest 2>/dev/null || echo "bin/atom-suggest が見つかりません。プロジェクト root から実行してください。"`

## 推奨アクション

上記レポートを見て、以下を実施:

1. **stale-atoms**: 内容が今でも valid か判断
   - まだ valid → `bin/atoms promote <id> <plan_path>` で pipeline に昇格
   - 陳腐化 → `bin/atoms archive <id> <reason>`
2. **promote-ready**: 即 promote 候補
   - `bin/atoms promote <id> <plan_path>` で要件化開始
3. **stuck-pipeline**: 何が止めているか確認
   - ブロッカー解消できるなら implement、無理なら pipeline から取り下げ
4. **orphan-next**: 漏れ確認
   - 重要なら `bin/atoms add <source> <content>` で取り込み
   - 既に解決済みなら context.md から削除
5. **unused-skills**: 30 日近く 0〜1 回しか使われていない skill
   - description のトリガーフレーズを見直す（`/o-m-cc:evolve` で改善案）
   - 役目を終えていれば削除を検討
6. **duration-stats**: sum_ms / max_ms が突出している skill
   - 内部 subagent 構成の見直し、不要な並列の整理
   - effort: low/med/high を見直して期待値を調整
7. **gotcha-ranking**: AUTO-GOTCHAS が累計で多い skill = 改善余地あり
   - 累計上位の skill は **構造的な問題** が示唆される。`bin/atoms add "atom-suggest" "<skill> の <傾向> を改善" "<promote / 試行 / 議論>"` で atom 化
   - 直近 30 日の追加が突出していれば **回帰中** の可能性。最近の commit を確認

## 補足: atoms 操作

```bash
bin/atoms list           # 全 csv 一覧
bin/atoms list atom      # status=atom のみ
bin/atoms add "出元" "内容" "次のアクション"
bin/atoms promote A001 plan/feature-x.md
bin/atoms complete P001 .claude/atoms.csv "成功" "1日で完了"
bin/atoms archive A004 "陳腐化"
bin/atoms show A002
bin/atoms stats
```
