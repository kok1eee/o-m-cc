---
name: retro
description: "スキル使用状況の振り返り。定期的な棚卸しや改善サイクルの一環として使う。どのスキルがどれくらい使われているか確認し、改善・削除の判断材料にする。「振り返り」「使用状況」「retro」「どのスキルが使われてる？」「スキルの棚卸し」で発動。"
allowed-tools: [Read, Bash, Glob, Grep]
effort: low
---

# Retro - スキル使用状況の振り返り

スキルの使用ログを分析し、改善・削除の判断材料を提供する。

## データソース

!`cat "${CLAUDE_PLUGIN_DATA}/skill-usage.log" 2>/dev/null | sort | uniq -c | sort -rn || echo "ログなし（まだスキルが使われていません）"`

## 直近7日間

!`D=$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null); if [ -f "${CLAUDE_PLUGIN_DATA}/skill-usage.log" ]; then awk -v d="$D" 'substr($0, 1, 10) >= d { sub(/^[^ ]+ /, ""); print }' "${CLAUDE_PLUGIN_DATA}/skill-usage.log" | sort | uniq -c | sort -rn; else echo "ログなし"; fi`

## タスク作成ログ

### 全期間
!`cat "${CLAUDE_PLUGIN_DATA}/task-created.log" 2>/dev/null | wc -l | tr -d ' ' | xargs -I{} echo "累計 {} タスク作成" || echo "ログなし"`

### 直近7日間
!`D=$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null); if [ -f "${CLAUDE_PLUGIN_DATA}/task-created.log" ]; then awk -v d="$D" 'substr($0, 1, 10) >= d' "${CLAUDE_PLUGIN_DATA}/task-created.log" | wc -l | tr -d ' ' | xargs -I{} echo "{} タスク（直近7日）"; else echo "ログなし"; fi`

## スキル実行時間分析（Claude Code 2.1.119+）

PostToolUse:Skill hook が duration_ms を記録する（`skill-duration.log`）。

### スキル別の平均 / 最大 / 合計実行時間（ミリ秒）
!`if [ -f "${CLAUDE_PLUGIN_DATA}/skill-duration.log" ]; then awk -F'\t' '$3 > 0 { count[$2]++; sum[$2]+=$3; if ($3 > max[$2]) max[$2]=$3 } END { printf "%-30s %8s %8s %8s %8s\n", "skill", "count", "avg_ms", "max_ms", "sum_ms"; for (s in count) printf "%-30s %8d %8d %8d %8d\n", s, count[s], sum[s]/count[s], max[s], sum[s] }' "${CLAUDE_PLUGIN_DATA}/skill-duration.log" | sort -k5 -rn; else echo "ログなし（Claude Code 2.1.119+ で記録開始）"; fi`

## 分析してほしいこと

1. **使用頻度ランキング**: どのスキルがよく使われているか
2. **未使用スキル**: 一度も使われていないスキルはないか
3. **実行時間分析**（`skill-duration.log` ベース）:
   - 平均実行時間が長いスキル → Gotchas や reference 分離で最適化余地
   - 合計実行時間（sum_ms）が大きいスキル → ROI が悪い可能性、使用頻度とのバランスで判断
   - 最大実行時間が突出しているスキル → 特定のエッジケースで詰まっている可能性
4. **改善提案**:
   - 未使用 → description の改善 or 削除を検討
   - 高頻度 → Gotchas を充実させる価値がある
   - 低頻度だが重要 → description のトリガー条件を見直す
   - 遅い → context: fork 導入 / Progressive Disclosure 強化 / reference 分離

4. **モデル進化時のガード再評価**（Anthropic 公式のツール設計哲学に従う）:
   - 各スキルが持つ防御的ガード（sisyphus の Step 0/0A/0A-lite/0B 等）は、**特定の失敗体験**への対応として追加された
   - モデルが世代交代した（例: Opus 4.6 → 4.7 で指示追従強化）タイミングで、以下を評価:
     - そのガードは依然として False positive を防いでいるか
     - 新モデルの能力向上でガード自体が過剰になっていないか
     - ガード追加時の元の事故（commit log / journal.md から辿る）は再現可能か
   - 結論:
     - まだ守っている → 維持
     - 過剰になった → 緩和または削除を提案（ただし元事故の再発リスクは必ずチェック）
     - 判断不能 → 継続観察でよい（保守的判断を優先）
