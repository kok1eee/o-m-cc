---
name: project-edd-layer
description: EDD（評価駆動開発）層の設計判断と、設計中に発見した requirements との齟齬2点
metadata:
  type: project
---

o-m-cc に EDD 層（数値ベース正確性検証、5 層モデルの Layer 4 欠落を埋める）を追加する設計を `plan/design.md` に作成した（2026-05-26）。FR-1〜FR-5。

**Why:** sisyphus の Layer 2 CTA（LLM 定性判断）に依存し、数値メトリクス検証ハーネスが構造的欠落。新規スキルを増やさず既存 bin/ + hook + CSV を拡張する方針（Progressive Disclosure / Lightweight 原則）。

**How to apply:** EDD は「測定 → レポート → 人が判断」の Sensors 止まり。edd-check は exit code + atoms.csv 追記のみで、コード/SKILL.md の自動書き換えは禁止（NFR-3）。

主要 ADR:
- ADR-1: parser を共有モジュール化せず Python 2 箇所で実装（A-1 で edd-check は Bash 指定、フォーマット `key:value;key:value` が単純なため抽象化コスト > 重複コスト）
- ADR-2: edd-check の outputs.csv 読み取りは `python3 -c` ワンライナー（既存行に自由テキストのカンマ/クオート混在 = O001 等。Bash 手 parse は壊れる）

設計中に発見した requirements との齟齬（planner/ユーザー判断要、design.md の「既知の不足」に記載）:
- **齟齬1**: `bin/atoms complete` は既に第4 positional で metric を受ける（`bin/atoms:153`）。FR-2 の「`--metric` 追加」は重複機能 → 後方互換維持して名前付きオプション追加で両立（ADR-3）
- **齟齬2**: FR-4 は `hooks/skill-usage-log.sh` のみ名指しだが、同じ skill-usage.csv を `hooks/skill-prompt-log.sh`（user-slash 起動、O008 実装済み）も書く。片方だけ 6 列化すると列数不整合 → skill-prompt-log.sh も同期変更が必須。requirements 文言を超える scope のため要確認
