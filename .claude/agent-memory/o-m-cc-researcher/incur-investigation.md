# wevm/incur 調査ノート (2026-02-28)

## 基本情報
- **リポジトリ**: https://github.com/wevm/incur
- **バージョン**: 0.1.7 (MIT)
- **言語**: TypeScript (ESM only)
- **パッケージマネージャー**: pnpm
- **コードベース規模**: 中規模（src/配下 13ファイル + テスト、Cli.tsが58KBと最大）

## src/ 構造
- `Cli.ts` (58KB) - 核心実装（create/command/serve）
- `Skill.ts` (9.5KB) - スキルファイル生成（マークダウン変換）
- `SyncSkills.ts` (7.3KB) - スキルインストール・同期
- `Mcp.ts` (6.9KB) - MCPサーバー実装
- `SyncMcp.ts` (4.3KB) - MCP登録（claude/cursor等への登録）
- `Help.ts` (11KB) - ヘルプテキスト生成
- `Formatter.ts` (3.9KB) - 出力フォーマット（toon/json/yaml/md/jsonl）
- `Parser.ts` (8.6KB) - 引数パース
- `Errors.ts` (4.3KB) - エラーハンドリング
- `Register.ts` - 型安全登録インターフェース（Declaration Merging用）
- `Schema.ts` - Zod→JSONSchema変換
- `Skillgen.ts` (2.4KB) - スキルファイル生成エントリ
- `Typegen.ts` (4KB) - 型生成

## 主要依存関係
- `@modelcontextprotocol/sdk` (v1.27.1) - MCP通信
- `@toon-format/toon` (v2.1.0) - TOONエンコード（別ライブラリ）
- `yaml` (v2.8.2)
- `zod` (v4.3.6) - スキーマバリデーション

## API設計

### Cli.create(name, options)
- CLI/コマンドグループを初期化
- 内部WeakMapでコマンドマップ・ミドルウェアを管理

### .command(name, definition)
- コマンドを登録（チェーン可能）
- 別のCli/Rootをサブグループとしてマウント可能

### .serve()
- フラグ解析 → コマンド解決 → ミドルウェア合成（reduceRight）→ 実行 → 出力

## TOON出力形式
- `@toon-format/toon` ライブラリの `encode()` を呼ぶだけ
- JSONより最大60%トークン削減と主張
- `--format toon|json|yaml|md|jsonl` で切替

## CTA（Call-to-Actions）
```ts
return c.ok(data, { cta: { commands: [{ command: 'get 1', description: 'View item' }] } })
```
- CLI名をプレフィックスとして自動付与
- 型推論でコマンド名・引数を補完

## スキル自己登録の仕組み
1. `my-cli skills add` を実行
2. コマンドマップを走査してCommandInfo配列を構築
3. `Skill.split()` でマークダウンファイルに変換
4. 一時ディレクトリ（`incur-skills-{name}-*`）に書き込み
5. `Agents.install()` でグローバル/ローカルにインストール
6. XDG_DATA_HOMEにメタデータ保存（次回の変更検知用）

## MCP登録の仕組み
- `my-cli mcp add` で実行
- `npx add-mcp` を使って Claude Code / Cursor 等に登録
- Amp は個別対応（`~/.config/amp/settings.json` 直接書き込み）

## 出力エンベロップ構造
```json
{
  "ok": true,
  "data": {},
  "meta": {
    "command": "list",
    "duration": "42ms",
    "cta": { "commands": [...] }
  }
}
```

## o-m-ccとの関連性評価
- 「エージェント向けCLIフレームワーク」という異なる領域のツール
- Claude Code プラグインとは直接競合しない
- TOONフォーマットの概念（トークン効率化）は参考になる可能性
- スキル自己登録の発想はo-m-ccのSKILL.md的な仕組みと類似
