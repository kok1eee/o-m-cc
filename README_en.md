# o-m-cc v0.18.2

[日本語](README.md)

**Sisyphus Loop for Claude Code** — A multi-agent workflow that never stops until TODOs are done.

## Overview

o-m-cc is a Claude Code plugin that injects an "unstoppable developer" mindset.

- **Agent Teams**: Peer-to-peer multi-agent coordination via TeammateTool
- **Sisyphus Philosophy**: Never stop until the task is complete
- **TODO-Driven**: Work based on clear task lists
- **Spec-Driven Development**: Structured flow from requirements → design → tasks → implementation
- **Gap Analysis**: Discover missing requirements before planning

## Prerequisites

- **macOS / Linux** (Windows: use via WSL)
- [Claude Code](https://claude.com/claude-code) CLI installed
- `jq` (required for hooks): `brew install jq` / `apt install jq`
- `python3` (for security hook)

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
/o-m-cc:plan "Implement authentication system"
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
| `/o-m-cc:plan <task>` | Requirements → Design → Tasks (Agent Teams parallel + gap analysis) | fork | On "plan this" |

### Quality

| Skill | Description | Context | Auto-trigger |
|-------|-------------|---------|-------------|
| `/o-m-cc:review [files]` | Code review with Agent Teams (peer-to-peer discussion) | fork | On "review this" |
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
│  researcher ◄─► analyst (Lead) ◄─► scout│
│       Peer-to-peer findings sharing     │
└─────────────────────────────────────────┘
          │ requirements.md
          ▼
  Phase 2 (designer) → Phase 3 (planner)
  design.md             tasks.md
                           │
          ┌────────────────────────────────┐
          │    Phase 4: Review Council      │
          │    critic (Lead) ◄─► advisor    │
          └────────────────────────────────┘
```

## Hooks

| Hook | Event | Description |
|------|-------|-------------|
| check-dependencies | SessionStart | Check required commands (jq, python3) |
| archive-plans | SessionStart | Archive old plan files |
| session-resume | SessionStart | Display `.claude/context.md` + `chronicle.md` context |
| memory-digest | SessionStart | Display subagent Memory digest |
| stop-guard | Stop | Sisyphus loop control (detect `<promise>DONE</promise>`) |
| focus-guard | UserPromptSubmit | Keep focus on current tasks |
| security-reminder | PreToolUse | Security review reminder |
| pre-compact-handover | PreCompact | Auto-save context on compaction (3-layer rotation) |
| auto-verify | PostToolUse | Run project tests automatically |
| teammate-idle | TeammateIdle | Escalation protocol (3 stages) for idle teammates |
| task-completed | TaskCompleted | Progress tracking & next task assignment |

> **Note**: Claude Code 2.1.50+ adds `WorktreeCreate` / `WorktreeRemove` hook events for custom VCS setup/teardown with worktree isolation (useful for non-git VCS like jj).

## Update

```bash
claude plugin update o-m-cc@kok1eee
```

## License

MIT
