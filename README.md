# Dev Workflow Enforcement

Enforce a structured, skill-based development workflow in any project using Claude Code + Superpowers skills.

Ensures Claude always follows brainstorming, planning, code review, and verification steps before shipping code — automatically, via hooks.

## The Problem

Claude Code skips skill invocations (brainstorming, code review, verification) and jumps straight to coding, even when CLAUDE.md explicitly requires them. Documentation-level instructions are not enough.

## The Solution

A four-layer enforcement system that tracks skill invocations and blocks progress when required steps are missing:

| Layer | Mechanism | Effect |
|-------|-----------|--------|
| **Skill Tracker** | PostToolUse hook on `Skill` tool | Records every skill invocation to a state file |
| **Stage Enforcer** | PostToolUse hook on `Edit\|Write` | Outputs HARD STOP if planning skills incomplete |
| **Deploy Gate** | Snippet for your deploy script | Blocks deployment without required skills |
| **CLAUDE.md** | Template with enforcement language | Documents the workflow and rules |

## Quick Start

```bash
# 1. Copy scripts to your project
mkdir -p scripts/workflow-enforcement
cp scripts/* your-project/scripts/workflow-enforcement/
chmod +x your-project/scripts/workflow-enforcement/*.sh

# 2. Create .claude/settings.json in your repo root
# (see agent-readme.md for the full JSON)

# 3. Add workflow section to your CLAUDE.md
# (see CLAUDE.md.template)

# 4. Add deploy gate to your deploy script
# (see deploy-gate-snippet.sh)
```

See **[agent-readme.md](agent-readme.md)** for detailed step-by-step setup instructions.

## How It Works

```
Invoke /brainstorming  →  record-skill.sh  →  /tmp/.wyzr-workflow-state
Edit src/app.ts        →  dev-cycle-check.sh reads state →  "HARD STOP: planning incomplete"
Complete planning      →  dev-cycle-check.sh reads state →  "Planning complete, review needed"
Deploy                 →  deploy gate checks state       →  blocks if skills missing
Deploy succeeds        →  state files cleaned up          →  fresh start
```

### Stages

| Stage | Condition | Output |
|-------|-----------|--------|
| **A** | Planning skills incomplete | HARD STOP — lists missing skills |
| **B** | Planning done, review pending | Checklist + remaining skills |
| **C** | Review done, verification pending | Finalization reminder |
| **D** | All required skills complete | Ready to deploy |

### Trivial Changes

For typos, copy fixes, config tweaks:
```bash
touch /tmp/.wyzr-workflow-trivial
```

## Configuration

Edit `scripts/config.sh` to customize:

```bash
REQUIRED_PLANNING_SKILLS="brainstorming write-spec writing-plans"
REQUIRED_DEPLOY_SKILLS="brainstorming write-spec code-review verification-before-completion"
SRC_PATTERN="/src/"
SRC_EXCLUDE_PATTERN="__tests__|\.test\."
```

## Files

| File | Purpose |
|------|---------|
| `scripts/config.sh` | Customizable skill lists, patterns, paths |
| `scripts/record-skill.sh` | PostToolUse hook — records skill invocations |
| `scripts/dev-cycle-check.sh` | PostToolUse hook — stage-aware enforcement |
| `scripts/deploy-gate-snippet.sh` | Paste into your deploy script |
| `agent-readme.md` | Full setup guide for any agent or developer |
| `CLAUDE.md.template` | Drop-in CLAUDE.md section with workflow rules |

## Requirements

- Claude Code CLI
- Superpowers skills plugin
- `jq` on PATH

## License

MIT
