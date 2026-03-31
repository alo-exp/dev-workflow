# Dev Workflow Enforcement

> **DEPRECATED**: This repo has been superseded by [**dev-workflows**](https://github.com/alo-exp/dev-workflows) — a proper Superpowers plugin with six-layer compliance enforcement. Install the new plugin: `/plugin install alo-exp/dev-workflows`. This repo is archived and will not receive updates.

---

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

## Plugin Locations

Skills are invoked by name (e.g. `/documentation`). If a skill cannot be found, Claude must stop and notify the user — never silently skip it.

### Superpowers plugin

```
~/.claude/plugins/cache/superpowers-marketplace/superpowers/<version>/skills/
```

Skills: `brainstorming`, `writing-plans`, `executing-plans`, `requesting-code-review`, `receiving-code-review`, `verification-before-completion`, `systematic-debugging`, `finishing-a-development-branch`, etc.

### Engineering plugin

The Engineering plugin is distributed via Claude's local agent mode session cache. It is **not** in the superpowers marketplace cache.

```
~/Library/Application Support/Claude/local-agent-mode-sessions/<session-id>/<agent-id>/rpm/plugin_01RAnuCvafZfGPUyv8T67WkN/skills/
```

Skills: `architecture`, `code-review`, `debug`, `deploy-checklist`, `documentation`, `incident-response`, `standup`, `system-design`, `tech-debt`, `testing-strategy`

To find it on a new machine:

```bash
find ~/Library/Application\ Support/Claude/local-agent-mode-sessions \
  -maxdepth 5 -name "README.md" \
  -exec grep -l "Engineering Plugin" {} \; 2>/dev/null
```

The plugin ID is `plugin_01RAnuCvafZfGPUyv8T67WkN`. Invoke skills with the `engineering:` prefix in Claude Code, e.g. `/engineering:documentation`.

## Requirements

- Claude Code CLI
- Superpowers skills plugin
- `jq` on PATH

## License

MIT
