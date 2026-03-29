# Dev Workflow — Agent Setup Guide

**Purpose**: Enforce a structured, skill-based development workflow in any project using Claude Code + Superpowers skills. This ensures Claude always follows brainstorming, planning, code review, and verification steps before shipping code.

**Audience**: Any AI agent (Claude, Gemini, etc.) or human developer setting up a new project.

---

## What This Enforces

A multi-stage development workflow where specific skills MUST be invoked via the Skill tool before code can be deployed:

| Stage | Required Skills | Enforcement |
|-------|----------------|-------------|
| **Planning** | /brainstorming, /write-spec, /writing-plans | PostToolUse HARD STOP on every src/ edit |
| **Review** | /code-review | Deploy gate blocks |
| **Verification** | /verification-before-completion | Deploy gate blocks |

Optional tracked skills: /using-superpowers, /executing-plans, /test-driven-development, /requesting-code-review, /receiving-code-review, /testing-strategy, /systematic-debugging, /debug, /tech-debt, /documentation, /deploy-checklist, /architecture, /system-design

## How It Works

```
[Skill tool invoked] → record-skill.sh → writes to /tmp/.wyzr-workflow-state
[src/ file edited]   → dev-cycle-check.sh → reads state → outputs enforcement message
[deploy command]     → deploy gate → checks state → blocks if skills missing
[deploy succeeds]    → cleans up state files → fresh start for next workflow
```

**Stages**:
- **Stage A** (no planning done): Every src/ edit triggers a HARD STOP message
- **Stage B** (planning done): Checklist shown with remaining review/finalization skills
- **Stage C** (review done): Finalization reminder
- **Stage D** (all done): Ready to deploy

**Trivial changes**: `touch /tmp/.wyzr-workflow-trivial` bypasses skill requirements for typos/copy fixes.

---

## Setup Instructions (Step by Step)

### Prerequisites

- Claude Code CLI installed
- Superpowers skills plugin installed
- `jq` available on PATH (for JSON parsing in hooks)
- A project with a `src/` directory (or configure `SRC_PATTERN` in config.sh)

### Step 1: Copy Files

```bash
# From your project root:
cp -r /path/to/dev-workflow/scripts/ ./scripts/workflow-enforcement/
chmod +x ./scripts/workflow-enforcement/*.sh
```

Files copied:
- `config.sh` — Customizable settings (skill lists, patterns, paths)
- `record-skill.sh` — PostToolUse hook that records Skill invocations
- `dev-cycle-check.sh` — PostToolUse hook with stage-aware enforcement
- `deploy-gate-snippet.sh` — Snippet to paste into your deploy script

### Step 2: Configure

Edit `scripts/workflow-enforcement/config.sh`:

```bash
# Adjust these for your project:
REQUIRED_PLANNING_SKILLS="brainstorming write-spec writing-plans"
REQUIRED_DEPLOY_SKILLS="brainstorming write-spec code-review verification-before-completion"
SRC_PATTERN="/src/"                    # Change if your source is elsewhere (e.g., "/lib/")
SRC_EXCLUDE_PATTERN="__tests__|\.test\."  # Test file patterns to ignore
```

### Step 3: Create .claude/settings.json

Create `.claude/settings.json` in your **repo root** (not inside src/):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "scripts/workflow-enforcement/dev-cycle-check.sh",
            "timeout": 5,
            "statusMessage": "Checking dev cycle..."
          }
        ]
      },
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "scripts/workflow-enforcement/record-skill.sh",
            "timeout": 3,
            "statusMessage": "Recording skill..."
          }
        ]
      }
    ]
  }
}
```

**Important**: The `command` paths are relative to the directory where Claude Code runs (usually the repo root). Adjust if your scripts directory is nested differently.

### Step 4: Add to CLAUDE.md

Add this section to your project's `CLAUDE.md` (create one if it doesn't exist):

```markdown
## Development Process for Non-Trivial Changes

> **ENFORCED** — Every skill invocation is tracked by the PostToolUse hook.
> The PostToolUse enforcer outputs a HARD STOP if you edit src/ without completing planning skills.
> The deploy gate BLOCKS deployment without required skills.

For every non-trivial change, follow this workflow. Each step invokes a named skill via the Skill tool.
For trivial changes (typos, copy fixes): `touch /tmp/.wyzr-workflow-trivial`

```
PLANNING (must complete before ANY src/ edit — HARD STOP enforced):
1.  /using-superpowers              — Establish available skills (advisory)
2.  /brainstorming                  — Explore intent, constraints, approaches    REQUIRED
3.  /write-spec                     — Write or update spec document              REQUIRED
4.  /writing-plans                  — Detailed implementation plan               REQUIRED

EXECUTION:
5.  /executing-plans                — Execute plan using /test-driven-development

REVIEW (must complete before deploy — deploy gate enforced):
6.  /code-review                    — Self-review + /requesting-code-review      REQUIRED
7.  /receiving-code-review          — Address all review items
8.  /testing-strategy               — Define test approach

FINALIZATION (must complete before deploy — deploy gate enforced):
9.  /documentation                  — Update all project docs
10. /verification-before-completion — Produce evidence before claiming done      REQUIRED
11. /deploy-checklist               — Pre-deployment verification gate
```

Enforcement:
- State tracked in `/tmp/.wyzr-workflow-state` (auto-populated by Skill tool hook)
- Edit src/ without planning → HARD STOP output after every edit
- Deploy without required skills → BLOCKED
- State files cleaned up after successful deploy
```

### Step 5: Add Deploy Gate

If your project has a deploy script, add the workflow gate. Two options:

**Option A**: Paste from `deploy-gate-snippet.sh` into your existing deploy script (before the build step).

**Option B**: Source it:
```bash
# In your deploy script, before the build step:
source scripts/workflow-enforcement/deploy-gate-snippet.sh
```

Add cleanup after successful deploy:
```bash
# After successful deploy:
rm -f /tmp/.wyzr-workflow-state /tmp/.wyzr-workflow-trivial
```

### Step 6: Verify

```bash
# 1. Test skill recording
echo '{"tool_input":{"skill":"brainstorming"}}' | ./scripts/workflow-enforcement/record-skill.sh
cat /tmp/.wyzr-workflow-state
# Should show: brainstorming

# 2. Test HARD STOP (clear state first)
rm -f /tmp/.wyzr-workflow-state
echo '{"tool_input":{"file_path":"/your/project/src/app.ts"}}' | ./scripts/workflow-enforcement/dev-cycle-check.sh
# Should show: HARD STOP with missing skills

# 3. Test deploy gate
rm -f /tmp/.wyzr-workflow-state /tmp/.wyzr-workflow-trivial
# Your deploy command should fail with "No workflow state found"

# 4. Clean up test state
rm -f /tmp/.wyzr-workflow-state /tmp/.wyzr-workflow-trivial
```

---

## Directory Structure After Setup

```
your-project/
├── .claude/
│   └── settings.json          ← Hook configuration
├── scripts/
│   └── workflow-enforcement/
│       ├── config.sh           ← Customizable settings
│       ├── record-skill.sh     ← Skill invocation tracker
│       ├── dev-cycle-check.sh  ← Stage-aware enforcer
│       └── deploy-gate-snippet.sh ← Deploy gate code
├── src/                        ← Your source code
├── CLAUDE.md                   ← Project instructions with §8 workflow
└── ...
```

---

## Customization

### Different Source Directory

If your source code is not in `src/`, edit `config.sh`:
```bash
SRC_PATTERN="/lib/"           # or "/app/" or "/packages/"
SRC_EXCLUDE_PATTERN="__tests__|\.test\.|\.spec\."
```

### Different Required Skills

Edit `config.sh` to add or remove required skills:
```bash
REQUIRED_PLANNING_SKILLS="brainstorming writing-plans"  # removed write-spec
REQUIRED_DEPLOY_SKILLS="brainstorming code-review"      # minimal set
```

### No Deploy Script

If your project doesn't have a deploy script, the enforcement still works via:
1. PostToolUse HARD STOP (prevents coding without planning)
2. Stage-aware checklist (reminds about remaining skills)

The deploy gate is an additional layer, not the only one.

### Multiple Source Directories

For monorepos with multiple source dirs:
```bash
SRC_PATTERN="/src/\|/packages/\|/apps/"
```

---

## Troubleshooting

**Hook not firing**: Check that `.claude/settings.json` is at the repo root (where you run `claude`), and that `command` paths are correct relative to that root.

**"jq: command not found"**: Install jq: `brew install jq` (macOS) or `apt install jq` (Linux).

**State file persists across sessions**: State files live in `/tmp/` and persist until deploy cleanup or manual deletion. Run `rm -f /tmp/.wyzr-workflow-state /tmp/.wyzr-workflow-trivial` to reset.

**Skills not being recorded**: Verify the Skill matcher is in settings.json and the `record-skill.sh` path is correct. Test manually with the echo command in Step 6.
