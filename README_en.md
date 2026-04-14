# o-m-cc v0.35.1

[日本語](README.md)

**Sisyphus Loop for Claude Code** — A multi-agent workflow plugin that injects spec-driven development (SDD) into Claude Code.

## Overview

- **Skill Chain**: Requirements → Design → Task Decomposition → Implementation → Quality Gate, chained as independent skills with context separation per phase
- **Agent Teams**: Peer-to-peer multi-agent coordination via TeamCreate + SendMessage. 10 specialist agents cross-verify via SendMessage
- **Monitor Integration**: experiment/quality-gate/sisyphus leverage the Monitor tool for async long-running operations (lint/test streaming)
- **Two-stage Verification**: `verification` skill (self-evidence collection) + Verifier agent (independent adversarial check) to eliminate implementer bias
- **Progressive Disclosure**: Agent definitions split across 3 layers; constant load limited to ~10%

## Prerequisites

- **macOS / Linux** (Windows: use via WSL)
- [Claude Code](https://claude.com/claude-code) CLI installed
- `jq` (required for hooks): `brew install jq` / `apt install jq`

## Quick Start

```bash
# 1. Add marketplace
claude plugin marketplace add kok1eee/o-m-cc

# 2. Install plugin
claude plugin install o-m-cc@kok1eee

# 3. Initialize project (creates CLAUDE.md + enables Sisyphus)
/o-m-cc:install

# 4. Just work normally
"Fix the login button bug"
→ Automatically runs in Sisyphus mode
```

## Skills (13 total)

### Setup

| Skill | Description | Auto-trigger |
|-------|-------------|-------------|
| `/o-m-cc:install` | Project initialization (CLAUDE.md + Sisyphus) | Manual only |

### Planning

| Skill | Description | Context | Auto-trigger |
|-------|-------------|---------|-------------|
| `/o-m-cc:deep-interview <idea>` | Socratic requirements exploration → hands off to discovery-council | - | "requirements unclear", "dig deeper" |
| `/o-m-cc:sisyphus <task>` | Plan → Implement → Quality Gate (skill chain, never stops) | fork | "plan this", "implement feature" |
| `/o-m-cc:discovery-council <task>` | 3-agent parallel requirements analysis Council | fork | "analyze requirements" |
| `/o-m-cc:design` | Architecture design by designer agent | - | "design this" |
| `/o-m-cc:task-decomposition` | Task decomposition by planner agent | - | "break into tasks" |

### Verification

| Skill | Description | Context | Auto-trigger |
|-------|-------------|---------|-------------|
| `/o-m-cc:quality-gate [files]` | Review Council + Lint (Monitor parallel streaming) | fork | "review this", "quality check" |
| `/o-m-cc:verification` | Evidence collection before completion declaration (Iron Law) | - | "verify this", "is it actually working?" |
| `/o-m-cc:audit [target]` | Quality audit for agents/skills | - | Manual only |

### Experiment & Learning

| Skill | Description | Context | Auto-trigger |
|-------|-------------|---------|-------------|
| `/o-m-cc:experiment <goal>` | Autoresearch-style iterative improvement loop | - | "optimize", "experiment" |
| `/o-m-cc:retro` | Analyze skill usage patterns | - | "retrospective", "usage stats" |
| `/o-m-cc:evolve` | Self-evolve skills by extracting learnings into Gotchas (L3 inspired) | - | Auto CTA via PreCompact hook |

### Operations

| Skill | Description | Context | Auto-trigger |
|-------|-------------|---------|-------------|
| `/o-m-cc:handoff` | Save session context to `.claude/context.md` for handoff | - | "handoff", "save context" |

## Agents (10 specialists + @capabilities meta)

### Planning

| Agent | Role | Model |
|-------|------|-------|
| @analyst | Requirements analysis | sonnet |
| @scout | Gap analysis | sonnet |
| @designer | Architecture design | opus |
| @planner | Task breakdown | sonnet |
| @critic | Plan review | sonnet |

### Analysis

| Agent | Role | Model |
|-------|------|-------|
| @researcher | Codebase exploration & documentation research | sonnet |
| @debugger | Systematic debugging | sonnet |

### Quality

| Agent | Role | Model |
|-------|------|-------|
| @code-reviewer | Code quality review | sonnet |
| @security-reviewer | Security review | sonnet |

### Meta

| Agent | Role |
|-------|------|
| @capabilities | Reference doc for agent selection & dispatch strategy |

> **Deprecated (removed in v0.27.0 ADR-0008)**: @advisor, @vision, @frontend. Functionality merged into other agents or delegated to official plugins (e.g., frontend-design).

## Planning Workflow

```
Agent Teams (Council + Pipeline Hybrid):
┌─────────────────────────────────────────┐
│       Phase 1: Discovery Council        │
│  researcher ◄──► analyst ◄──► scout     │
│       Peer-to-peer findings sharing     │
└─────────────────────────────────────────┘
          │ requirements.md
          ▼
  Phase 2 (designer) → Phase 3 (planner)
  design.md             TaskCreate
                           │
          ┌────────────────────────────────┐
          │    Phase 5: Quality Gate        │
          │  code-reviewer ◄──► security-reviewer │
          │          ◄──► critic            │
          └────────────────────────────────┘
```

## Hooks

| Event | Matcher | Hook | Description |
|-------|---------|------|-------------|
| SessionStart | - | resolve-conflicts.sh | Auto-resolve chronicle/context conflicts |
| SessionStart | - | check-dependencies.sh | Check required commands (jq etc.) |
| SessionStart | - | archive-plans.sh | Archive old plan/ files |
| SessionStart | - | session-resume.sh | Display context.md + chronicle.md |
| SessionStart | - | memory-digest.sh | Subagent Memory digest |
| SessionStart | - | plugin-data-init.sh | Initialize CLAUDE_PLUGIN_DATA |
| UserPromptSubmit | - | session-title.sh | Auto-set sessionTitle from context.md Intent |
| PreToolUse | Skill | skill-usage-log.sh | Log skill usage (for /retro) |
| PreToolUse | Bash | quality-gate-cta.sh | Non-blocking CTA before push commands |
| PreCompact | - | pre-compact-handover.sh | Auto-save context + safety block on failure (2.1.105+) |
| PostCompact | - | post-compact-resume.sh | Project state reminder |
| SubagentStop | - | subagent-verify.sh | Verify subagent output |
| TaskCreated | - | task-created-log.sh | Log task creation |
| TaskCompleted | - | task-completed.sh | Task completion notification |
| PermissionDenied | - | permission-denied.sh | Log denial + suggest alternative |
| SessionEnd | - | pre-compact-handover.sh | Auto-save context on session end |

## Update

```bash
claude plugin update o-m-cc@kok1eee
```

## Why Multi-Agent?

"Can't a single Claude Code session just loop?" — Fair question.

Technical advantages of multi-agent:

1. **Context separation**: Each agent runs in an independent context. Single-session role-play mixes all information into one context, where analyst views get biased by security-reviewer perspectives
2. **Parallel execution**: Agent Teams can run 3 teammates simultaneously. Discovery Council (researcher + analyst + scout) reduces time cost via parallel spawn. Role-play is serial only
3. **Persistent memory**: Agents with `memory: project` accumulate project-specific knowledge (patterns, conventions, past decisions). Carried across sessions. Role-play context dies with the session

Honestly, not all 10 agents are needed for every task. The frequently used core is analyst, designer, planner, code-reviewer, and researcher (5-6 agents). The rest are specialists called for specific situations (security audit, debugging, gap analysis). Constant load is only frontmatter (~10% of total), so the existence cost is low.

## Token & Cost

The Sisyphus Loop's "never stop" philosophy has a cost.

### Estimates

| Setting | Per iteration | Max (50 iterations) |
|---------|-------------|---------------------|
| **Loop (main)** | ~10K-50K tokens | ~500K-2.5M tokens |
| **Council (Agent Teams)** | ~50K-200K tokens/Council | ~400K tokens for plan+review |
| **Total (large task)** | — | ~1M-3M tokens |

### Cost Management

- **Small tasks**: Skip `/o-m-cc:sisyphus`, ask normally or use `/o-m-cc:experiment`
- **Large tasks**: Sisyphus is designed assuming mid-session compaction
- **Cost-conscious**: Keep all agents on `sonnet` (default). `opus` is reserved for designer, quality-gate, sisyphus (200k+ context)

## Configuration

No special env vars required. Main behavior is self-contained via plugin.json + settings.json + hooks.json.

| Variable | Purpose |
|----------|---------|
| `CLAUDE_NON_INTERACTIVE=1` | Headless mode. Skip AskUserQuestion and move forward |
| `O_M_CC_DEBUG=1` | Enable hooks debug output |

## Inspired By

- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) — Multi-agent blueprint. Redesigned from central orchestrator to peer-to-peer
- [ralph-wiggum](https://ghuntley.com/ralph/) — Stop Hook loop continuation pattern
- [autoresearch](https://karpathy.github.io/) — Iterative experiment design behind `/o-m-cc:experiment`

## License

MIT
