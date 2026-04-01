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

!`if [ -f "${CLAUDE_PLUGIN_DATA}/skill-usage.log" ]; then awk -v d="$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null)" '$1 >= d' "${CLAUDE_PLUGIN_DATA}/skill-usage.log" | awk '{print $2}' | sort | uniq -c | sort -rn; else echo "ログなし"; fi`

## タスク作成ログ

### 全期間
!`cat "${CLAUDE_PLUGIN_DATA}/task-created.log" 2>/dev/null | wc -l | tr -d ' ' | xargs -I{} echo "累計 {} タスク作成" || echo "ログなし"`

### 直近7日間
!`if [ -f "${CLAUDE_PLUGIN_DATA}/task-created.log" ]; then awk -v d="$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null)" '$1 >= d' "${CLAUDE_PLUGIN_DATA}/task-created.log" | wc -l | tr -d ' ' | xargs -I{} echo "{} タスク（直近7日）"; else echo "ログなし"; fi`

## 分析してほしいこと

1. **使用頻度ランキング**: どのスキルがよく使われているか
2. **未使用スキル**: 一度も使われていないスキルはないか
3. **改善提案**:
   - 未使用 → description の改善 or 削除を検討
   - 高頻度 → Gotchas を充実させる価値がある
   - 低頻度だが重要 → description のトリガー条件を見直す
