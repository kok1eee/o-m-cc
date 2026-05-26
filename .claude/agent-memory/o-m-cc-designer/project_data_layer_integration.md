---
name: project-data-layer-integration
description: o-m-cc の CSV データレイヤー拡張時に踏襲すべき既存パターンと統合ポイント
metadata:
  type: project
---

o-m-cc の CSV データレイヤー（atoms.csv / pipeline.csv / outputs.csv / skill-usage.csv 等）を拡張するときの統合ポイント。

**Why:** スキルはコンテキストではなくファイルを介して連携する設計（CLAUDE.md データレイヤー表）。CSV のスキーマ変更は複数の reader/writer に波及するため、拡張箇所を把握しておくと設計が速い。

**How to apply:** CSV 列追加時は以下のパターンを踏襲する。

- **header migration パターン**: `hooks/skill-usage-log.sh` が手本。`NEW_HEADER` 定数 + 旧 header を列挙した `case` 文 + `sed -i.bak "1s/.*/$NEW_HEADER/"`。既存データ行は短いまま残し、reader 側の DictReader / `.get(col, "")` で吸収する（旧データを書き換えない）
- **CSV reader の後方互換**: `bin/atom-suggest` / `bin/atoms` は `csv.DictReader` 使用。header に無い列は返さず、`r.get("new_col", "")` で安全に無視できる。これが「列が空でも壊れない」の構造的保証
- **repo root 検出**: `bin/lib/repo_root.py` の `detect_root()`（jj root → git → cwd）。新 bin/ スクリプトは ROOT 相対で CSV を参照（multi-repo 各リポ独立、O016 で確認済み）
- **閾値の env var 上書き**: `hooks/simplify-diff-gate.sh` が手本。`THRESHOLD="${NEW_VAR:-${OLD_VAR:-default}}"` で新旧 fallback + デフォルト。重複防止は「最終実行時刻 vs 最終コミット時刻」比較
- **同一 CSV を複数 writer が書く罠**: skill-usage.csv は `skill-usage-log.sh`（proactive）と `skill-prompt-log.sh`（user-slash, O008）の両方が追記する。片方だけ列追加すると列数不整合 → セットで変更する
