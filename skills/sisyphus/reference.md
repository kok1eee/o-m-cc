# Sisyphus - Reference

> SKILL.md から参照される詳細テンプレート。必要時のみ Read する。

## 実装 → 検証 → 修正ループ（詳細フロー）

```
┌──────────────────────────────────────────────────┐
│  タスク N                                         │
│                                                  │
│  1. 自分（Sisyphus）が実装する                      │
│                                                  │
│  2. Verifier を spawn — adversarial な検証          │
│     Agent: subagent_type=general-purpose           │
│     prompt: "以下の変更を検証してください。           │
│     テストを実行し、エッジケースを探し、              │
│     壊せるか試してください。                         │
│     証拠（コマンド出力）付きで合否を報告。            │
│     書いた人の「動くはず」は信用しないこと。           │
│     TODO/FIXME/後で実装 等の先送りがあれば fail。     │
│     繰り返し発見したパターンは memory に保存せよ。"    │
│                                                  │
│  3. Verifier が pass → 次のタスク                   │
│     Verifier が fail ↓                             │
│                                                  │
│  4. Debugger を spawn — 先入観なしの修正             │
│     Agent: subagent_type=o-m-cc:debugger           │
│     prompt: "Verifier が以下の問題を報告しました。    │
│     コードが何をしているかだけを見て                  │
│     根本原因を特定し修正してください。                │
│     修正後、テストを実行して結果を報告。"             │
│                                                  │
│  5. Debugger の修正を Verifier に再検証させる         │
│     → pass なら次のタスク                           │
│     → fail なら 4 に戻る（最大2回）                  │
│     → 2回失敗 → experiment ループに切り替え          │
│                                                  │
│  6. Experiment ループ（試行錯誤モード）               │
│     原因不明で Debugger が修正できない場合:           │
│     仮説を立てる → 1変更 → Verifier 検証             │
│     → pass なら次のタスク                           │
│     → fail なら revert して別の仮説（最大3回）        │
│     → 3回失敗 → AskUserQuestion                    │
│       （Headless なら [BLOCKED] 記録して次へ）        │
└──────────────────────────────────────────────────┘
```

**重要**: Debugger の修正結果は **Verifier に戻す**。修正者の「直した」を信用しない。
