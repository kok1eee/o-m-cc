# Context

> compaction で失われる文脈を保存。compaction summary と合わせて復元に使用。
> Learnings に長期的価値があれば MEMORY.md に反映すること。

### Snapshot (03/12 14:14, end)

**Intent:** TeamCreate, TeamDelete, SendMessage ツールが使えるか確認して。使えるなら各ツールの inputSchema を ToolSearch で取得して表示して。使えないなら使えないと言って。

**Context:**

��ィードバック",
  "summary": "string (optional) — 5-10語のプレビュー要約（message, broadcast で必要）",
  "request_id": "string (optional) — 応答対象のリクエストID（shutdown_response, plan_approval_response で必要）",
  "approve": "boolean (optional) — 承認/拒否（shutdown_response, plan_approval_response で必要）"
}
```

すべて Agent Teams（TeammateTool）の peer-to-peer 協調に使うツールで、正常にロードされています。
