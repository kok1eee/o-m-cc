# o-m-cc v0.24.3

[日本語](README.md)

**Sisyphus Loop for Claude Code** — A multi-agent workflow that never stops until TODOs are done.

## Overview

o-m-cc is a Claude Code plugin that injects an "unstoppable developer" mindset.

- **Agent Teams**: Peer-to-peer multi-agent coordination via TeamCreate + SendMessage
- **Sisyphus Philosophy**: Never stop until the task is complete
- **TODO-Driven**: Work based on clear task lists
- **Spec-Driven Development**: Structured flow from requirements → design → tasks → implementation
- **Gap Analysis**: Discover missing requirements before planning

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
/o-m-cc:init

# 4. Just work normally
"Fix the login button bug"
→ Automatically runs in Sisyphus mode
```

> Agent Teams is enabled automatically via plugin settings.json. No manual env var setup needed.

## Usage

### Simple Tasks (bug fixes, small features)

Just ask normally after Sisyphus mode is enabled:

```
"Add error handling to the API"
"Change the button color to blue"
"Fix the login page bug"
```

Automatically runs: TODO creation → Implementation → Review → Done.

### Complex Tasks (new features, large refactoring)

Run the planning phase first:

```bash
/o-m-cc:sisyphus "Implement authentication system"
```

After planning completes:

```
"Start implementation based on the plan"
```

## Skills

### Setup

| Skill | Description | Auto-trigger |
|-------|-------------|-------------|
| `/o-m-cc:init` | Project initialization (CLAUDE.md + Sisyphus) | Manual only |

### Planning Phase

| Skill | Description | Context | Auto-trigger |
|-------|-------------|---------|-------------|
| `/o-m-cc:sisyphus <task>` | Plan → Implement → Quality Gate (skill chain, never stops) | fork | On "plan this" |
| `/o-m-cc:discovery-council <task>` | 3-agent parallel requirements analysis Council | fork | On "analyze requirements" |
| `/o-m-cc:design` | Architecture design by designer agent | - | On "design this" |
| `/o-m-cc:task-decomposition` | Task decomposition by planner agent | - | On "break into tasks" |

### Quality

| Skill | Description | Context | Auto-trigger |
|-------|-------------|---------|-------------|
| `/o-m-cc:quality-gate [files]` | Review Council + Lint for final quality check | fork | On "review this", "quality check" |
| `/o-m-cc:audit [target]` | Quality audit for agents/skills | - | Manual only |

## Agents (12 specialists)

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
| @advisor | Strategy & debugging consultation | opus |
| @researcher | Codebase exploration & documentation research | sonnet |
| @debugger | Systematic debugging | sonnet |
| @vision | PDF/image analysis | sonnet |

### Implementation

| Agent | Role | Model |
|-------|------|-------|
| @frontend | UI/UX component creation | sonnet |

### Quality

| Agent | Role | Model |
|-------|------|-------|
| @code-reviewer | Code quality review | sonnet |
| @security-reviewer | Security review | sonnet |

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
          │    Phase 4: Review Council      │
          │    critic ◄──► advisor          │
          └────────────────────────────────┘
```

## Hooks

| Hook | Event | Timeout | Description |
|------|-------|---------|-------------|
| check-dependencies | SessionStart | 3s | Check required commands (jq) |
| archive-plans | SessionStart | 5s | Archive old plan files |
| session-resume | SessionStart | 3s | Display `.claude/context.md` + `chronicle.md` context |
| memory-digest | SessionStart | 3s | Display subagent Memory digest |
| session-baseline | SessionStart | 5s | Record session start diff baseline |
| stop-guard | Stop | 10s | Sisyphus loop control (diff-based quality-gate enforcement) |
| pre-compact-handover | PreCompact | 30s | Auto-save context on compaction (3-layer rotation) |
| post-compact-resume | PostCompact | 5s | Project state reminder after compaction |
| task-completed | TaskCompleted | 5s | Progress tracking & next task assignment |
| pre-compact-handover | SessionEnd | 30s | Auto-save context on session end |

> **Note**: Claude Code 2.1.50+ adds `WorktreeCreate` / `WorktreeRemove` hook events for custom VCS setup/teardown with worktree isolation (useful for non-git VCS like jj).

## Update

```bash
claude plugin update o-m-cc@kok1eee
```

## Why Multi-Agent?

"Can't a single Claude Code session just loop?" — Fair question.

The advantage of multi-agent is **separation of expertise**. Even with the same model, different system prompts produce different output tendencies:

- **analyst vs scout**: analyst structures requirements (FR-X, NFR-X), scout looks for gaps. Different perspectives from the same input
- **code-reviewer vs security-reviewer**: code-reviewer focuses on logic/readability, security-reviewer hunts OWASP Top 10 vulnerabilities. More accurate than asking one agent to do both
- **Council pattern**: multiple agents analyze simultaneously and exchange messages peer-to-peer, reducing blind spots

Honestly, not all 12 agents are needed for every task. The frequently used core is analyst, designer, planner, code-reviewer, and researcher (5-6 agents). The rest are specialists called for specific situations.

## Token & Cost

The Sisyphus Loop's "never stop" philosophy has a cost.

### Estimates

| Setting | Per iteration | Max (50 iterations) |
|---------|-------------|---------------------|
| **Loop (main)** | ~10K-50K tokens | ~500K-2.5M tokens |
| **Council (Agent Teams)** | ~50K-200K tokens/Council | ~400K tokens for plan+review |
| **Total (large task)** | — | ~1M-3M tokens |

### Cost Management

```bash
# Limit iterations (default: 50)
export SISYPHUS_MAX_ITERATIONS=20

# Adjust quality-gate threshold (default: 500 lines)
export SISYPHUS_MIN_DIFF=500
```

- **Small tasks**: `MAX_ITERATIONS=10` is sufficient
- **Large tasks**: Default (50). Designed to handle compaction mid-session
- **Cost-conscious**: Keep all agents on `sonnet` (default). Only advisor and designer use `opus`

## Inspired By

- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) — Multi-agent blueprint. Redesigned from central orchestrator to peer-to-peer
- [ralph-wiggum](https://ghuntley.com/ralph/) — Stop Hook loop continuation pattern

## License

MIT
