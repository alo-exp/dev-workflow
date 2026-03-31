# Dev Workflows Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `dev-workflows` Superpowers-native plugin that provides enforced development workflows via hooks, a setup skill, and modular workflow templates.

**Architecture:** New repo `alo-exp/dev-workflows` with `.claude-plugin/` manifests, `hooks/` (5 shell scripts + hooks.json), `skills/using-dev-workflows/SKILL.md`, and `templates/` (CLAUDE.md.base, config default, workflow files). Hooks use `jq` for JSON parsing and read per-project config from `.dev-workflows.json`.

**Tech Stack:** Bash (hooks), Markdown (skill, templates), JSON (manifests, config)

**Spec:** `docs/superpowers/specs/2026-03-31-dev-workflows-plugin-design.md`

---

## File Structure

```
alo-exp/dev-workflows/
├── .claude-plugin/
│   ├── plugin.json                            # Plugin identity + paths
│   └── marketplace.json                       # Ālo Labs marketplace metadata
├── hooks/
│   ├── hooks.json                             # All hook declarations
│   ├── session-start                          # SessionStart — inject /using-superpowers
│   ├── record-skill.sh                        # PostToolUse Skill — track invocations
│   ├── dev-cycle-check.sh                     # PostToolUse Edit|Write|Bash — phase gates
│   ├── compliance-status.sh                   # PostToolUse .* — universal progress score
│   ├── completion-audit.sh                    # PostToolUse Bash — block premature completion
│   └── run-hook.cmd                           # Cross-platform polyglot wrapper
├── scripts/
│   └── deploy-gate-snippet.sh                 # Copy-paste snippet for deploy scripts
├── skills/
│   └── using-dev-workflows/
│       └── SKILL.md                           # Single entry point skill
├── templates/
│   ├── CLAUDE.md.base                         # Base rules for any project
│   ├── dev-workflows.config.json.default      # Default per-project config
│   └── workflows/
│       └── full-dev-cycle.md                  # The 23-step enforced workflow
├── package.json                               # Metadata only
├── README.md                                  # Install instructions
├── CHANGELOG.md                               # Version history
└── LICENSE                                    # MIT
```

---

### Task 1: Initialize Repo + Plugin Manifests

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `package.json`
- Create: `LICENSE`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Create the new repo directory**

```bash
mkdir -p /Users/shafqat/Documents/Projects/dev-workflows
cd /Users/shafqat/Documents/Projects/dev-workflows
git init
```

- [ ] **Step 2: Create `.claude-plugin/plugin.json`**

```json
{
  "name": "dev-workflows",
  "description": "Enforced development workflows leveraging Superpowers and Engineering plugins. Full dev cycle, code review, TDD, deployment gates, and more.",
  "version": "1.0.0",
  "author": {
    "name": "Ālo Labs",
    "email": "info@alolabs.dev"
  },
  "homepage": "https://github.com/alo-exp/dev-workflows",
  "repository": {
    "type": "git",
    "url": "https://github.com/alo-exp/dev-workflows.git"
  },
  "license": "MIT",
  "keywords": ["dev-workflow", "enforcement", "tdd", "code-review", "deploy-gate", "ci-cd"],
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json"
}
```

- [ ] **Step 3: Create `.claude-plugin/marketplace.json`**

```json
{
  "marketplace": "Ālo Labs",
  "category": "workflows",
  "featured": true,
  "dependencies": {
    "plugins": [
      {
        "name": "superpowers",
        "source": "obra/superpowers",
        "url": "https://github.com/obra/superpowers",
        "required": true
      },
      {
        "name": "engineering",
        "source": "anthropics/knowledge-work-plugins",
        "url": "https://github.com/anthropics/knowledge-work-plugins/tree/main/engineering",
        "required": true
      }
    ]
  }
}
```

- [ ] **Step 4: Create `package.json`**

```json
{
  "name": "dev-workflows",
  "version": "1.0.0",
  "description": "Enforced development workflows for Claude Code — full dev cycle, code review, TDD, deployment gates.",
  "author": "Ālo Labs <info@alolabs.dev>",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/alo-exp/dev-workflows.git"
  },
  "keywords": ["claude-code", "plugin", "dev-workflow", "enforcement"]
}
```

- [ ] **Step 5: Create `LICENSE` (MIT)**

Standard MIT license text with "Copyright (c) 2026 Ālo Labs".

- [ ] **Step 6: Create `CHANGELOG.md`**

```markdown
# Changelog

## 1.0.0 (2026-03-31)

- Initial release
- Full dev cycle workflow (23-step enforced process)
- Six-layer compliance enforcement system
- `/using-dev-workflows` setup skill
- Superpowers + Engineering plugin dependency management
```

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin/ package.json LICENSE CHANGELOG.md
git commit -m "feat: initialize plugin with manifests and metadata"
```

---

### Task 2: Hook Infrastructure — `hooks.json` + Shared Utilities

**Files:**
- Create: `hooks/hooks.json`
- Create: `hooks/run-hook.cmd`

- [ ] **Step 1: Create `hooks/hooks.json`**

The complete hook declarations as specified in spec Section 5.3. Five hooks:
- SessionStart: `session-start`
- PostToolUse Skill: `record-skill.sh`
- PostToolUse Edit|Write|Bash: `dev-cycle-check.sh`
- PostToolUse .*: `compliance-status.sh`
- PostToolUse Bash: `completion-audit.sh`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\"",
            "async": false
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/record-skill.sh\"",
            "async": false
          }
        ]
      },
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/dev-cycle-check.sh\"",
            "async": false
          }
        ]
      },
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/compliance-status.sh\"",
            "async": false
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/completion-audit.sh\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Create `hooks/run-hook.cmd`**

Polyglot wrapper (CMD batch + bash). Reference the Superpowers plugin's `run-hook.cmd` at `~/.claude/plugins/cache/superpowers-marketplace/superpowers/5.0.5/hooks/run-hook.cmd` for the exact pattern.

The wrapper should:
1. Detect if running on Windows (CMD) or Unix (bash)
2. Set `CLAUDE_PLUGIN_ROOT` to the plugin directory
3. Forward to the actual hook script passed as argument

- [ ] **Step 3: Commit**

```bash
git add hooks/hooks.json hooks/run-hook.cmd
git commit -m "feat: add hook declarations and cross-platform wrapper"
```

---

### Task 3: `session-start` Hook

**Files:**
- Create: `hooks/session-start`

- [ ] **Step 1: Write the `session-start` script**

Bash script (executable, no `.sh` extension per Superpowers convention). Logic from spec Section 10.1:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Locate Superpowers using-superpowers SKILL.md
SKILL_FILE=$(find ~/.claude/plugins/cache -path "*/superpowers/*/skills/using-superpowers/SKILL.md" 2>/dev/null | head -1)

if [ -z "$SKILL_FILE" ]; then
  # Superpowers not installed — silent no-op
  exit 0
fi

CONTENT=$(cat "$SKILL_FILE")

# Inject /using-superpowers content into session context
cat <<EOF
{
  "hookSpecificOutput": {
    "additionalContext": $(echo "$CONTENT" | jq -Rs .)
  }
}
EOF
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/session-start
```

- [ ] **Step 3: Test locally**

```bash
echo '{}' | ./hooks/session-start
```

Expected: JSON output with `hookSpecificOutput.additionalContext` containing the skill content, OR clean exit if Superpowers not installed.

- [ ] **Step 4: Commit**

```bash
git add hooks/session-start
git commit -m "feat: add session-start hook to inject /using-superpowers"
```

---

### Task 4: `record-skill.sh` Hook

**Files:**
- Create: `hooks/record-skill.sh`

- [ ] **Step 1: Write the hook script**

Logic from spec Section 10.2. Key behaviors:
- Read JSON from stdin, extract skill name via `jq`
- Strip namespace prefixes with `sed 's/^[a-zA-Z_-]*://'`
- Walk up from `$PWD` to find `.dev-workflows.json` (stop at `.git/` or `/`)
- Read `state.state_file` and `skills.all_tracked` from config (or use defaults)
- Only record if skill is in `all_tracked`; output informational message if not tracked
- Append to state file (no duplicates via `grep -qx`)
- Output JSON with `hookSpecificOutput.message`

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- jq check ---
if ! command -v jq &>/dev/null; then
  echo '{"hookSpecificOutput":{"message":"❌ Dev Workflows hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"}}'
  exit 0
fi

# --- Read stdin ---
INPUT=$(cat)
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // ""')
[ -z "$SKILL" ] && exit 0

# --- Strip namespace prefix ---
SKILL=$(echo "$SKILL" | sed 's/^[a-zA-Z_-]*://')

# --- Find config ---
CONFIG_FILE=""
SEARCH_DIR="$PWD"
while [ "$SEARCH_DIR" != "/" ]; do
  if [ -f "$SEARCH_DIR/.dev-workflows.json" ]; then
    CONFIG_FILE="$SEARCH_DIR/.dev-workflows.json"
    break
  fi
  [ -d "$SEARCH_DIR/.git" ] && break
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

# --- Read config or use defaults ---
STATE_FILE="${DEV_WORKFLOWS_STATE_FILE:-/tmp/.dev-workflows-state}"
ALL_TRACKED="using-superpowers brainstorming write-spec design-system ux-copy architecture system-design writing-plans executing-plans code-review requesting-code-review receiving-code-review testing-strategy systematic-debugging debug tech-debt documentation verification-before-completion finishing-a-development-branch deploy-checklist"

if [ -n "$CONFIG_FILE" ]; then
  STATE_FILE=$(jq -r '.state.state_file // "/tmp/.dev-workflows-state"' "$CONFIG_FILE")
  ALL_TRACKED=$(jq -r '.skills.all_tracked // [] | join(" ")' "$CONFIG_FILE")
fi

# --- Check if tracked ---
if ! echo " $ALL_TRACKED " | grep -q " $SKILL "; then
  echo "{\"hookSpecificOutput\":{\"message\":\"ℹ️ Skill not tracked by Dev Workflows: $SKILL\"}}"
  exit 0
fi

# --- Append to state file (no duplicates) ---
touch "$STATE_FILE"
if ! grep -qx "$SKILL" "$STATE_FILE"; then
  echo "$SKILL" >> "$STATE_FILE"
fi

echo "{\"hookSpecificOutput\":{\"message\":\"✅ Skill recorded: $SKILL\"}}"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/record-skill.sh
```

- [ ] **Step 3: Write test — tracked skill**

All tests use `DEV_WORKFLOWS_STATE_FILE` env var to isolate from production state:

```bash
TEST_STATE=/tmp/.dev-workflows-test-state
rm -f "$TEST_STATE"
echo '{"tool_input":{"skill":"brainstorming"}}' | DEV_WORKFLOWS_STATE_FILE="$TEST_STATE" ./hooks/record-skill.sh
cat "$TEST_STATE"
```

Expected: output contains "✅ Skill recorded: brainstorming", state file contains `brainstorming`.

- [ ] **Step 4: Write test — untracked skill**

```bash
echo '{"tool_input":{"skill":"some-random-skill"}}' | DEV_WORKFLOWS_STATE_FILE="$TEST_STATE" ./hooks/record-skill.sh
```

Expected: output contains "ℹ️ Skill not tracked by Dev Workflows: some-random-skill".

- [ ] **Step 5: Write test — namespace stripping**

```bash
echo '{"tool_input":{"skill":"superpowers:brainstorming"}}' | DEV_WORKFLOWS_STATE_FILE="$TEST_STATE" ./hooks/record-skill.sh
```

Expected: strips prefix, records as `brainstorming`.

- [ ] **Step 6: Write test — duplicate prevention**

```bash
rm -f "$TEST_STATE"
echo '{"tool_input":{"skill":"brainstorming"}}' | DEV_WORKFLOWS_STATE_FILE="$TEST_STATE" ./hooks/record-skill.sh
echo '{"tool_input":{"skill":"brainstorming"}}' | DEV_WORKFLOWS_STATE_FILE="$TEST_STATE" ./hooks/record-skill.sh
grep -c "brainstorming" "$TEST_STATE"
```

Expected: count is 1 (not 2).

- [ ] **Step 7: Write test — jq missing behavior**

```bash
PATH="" echo '{"tool_input":{"skill":"brainstorming"}}' | ./hooks/record-skill.sh
```

Expected: output contains "❌ Dev Workflows hooks require jq" and exits cleanly.

- [ ] **Step 8: Clean up test state and commit**

```bash
rm -f /tmp/.dev-workflows-test-state
git add hooks/record-skill.sh
git commit -m "feat: add record-skill.sh hook with namespace stripping and tracked filtering"
```

---

### Task 5: `dev-cycle-check.sh` Hook

**Files:**
- Create: `hooks/dev-cycle-check.sh`

- [ ] **Step 1: Write the hook script**

Logic from spec Section 10.3. Key behaviors:
- Read JSON from stdin, extract file path (Edit/Write) or command (Bash)
- For Bash: check if command targets files matching `src_pattern`
- Walk up to find `.dev-workflows.json`, read config
- Check `src_pattern` match, exclude test patterns
- If trivial file exists → skip
- Four stages: A (HARD STOP), B (planning done), C (review done), D (all done)
- Phase skip detection: if invoking finalization skill without review → warning
- Error handling: output valid JSON on any failure, exit 0

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- jq check ---
if ! command -v jq &>/dev/null; then
  echo '{"hookSpecificOutput":{"message":"⚠️ Dev Workflows hook error: jq not found. Workflow enforcement skipped."}}'
  exit 0
fi

# --- Read stdin ---
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# --- Extract file path ---
FILE_PATH=""
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // ""')
elif [ "$TOOL_NAME" = "Bash" ]; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
  # Check if Bash command targets source files — extract paths from common commands
  # (sed, mv, cp, rm, cat > targeting src/)
  # Simple heuristic: check if command string contains src_pattern
  FILE_PATH="$CMD"
fi

[ -z "$FILE_PATH" ] && exit 0

# --- Find config (walk up) ---
CONFIG_FILE=""
SEARCH_DIR="$PWD"
while [ "$SEARCH_DIR" != "/" ]; do
  if [ -f "$SEARCH_DIR/.dev-workflows.json" ]; then
    CONFIG_FILE="$SEARCH_DIR/.dev-workflows.json"
    break
  fi
  [ -d "$SEARCH_DIR/.git" ] && break
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

# --- Read config or use defaults ---
SRC_PATTERN="/src/"
SRC_EXCLUDE="__tests__|\.test\."
REQUIRED_PLANNING="brainstorming write-spec writing-plans"
STATE_FILE="/tmp/.dev-workflows-state"
TRIVIAL_FILE="/tmp/.dev-workflows-trivial"

if [ -n "$CONFIG_FILE" ]; then
  SRC_PATTERN=$(jq -r '.project.src_pattern // "/src/"' "$CONFIG_FILE")
  SRC_EXCLUDE=$(jq -r '.project.src_exclude_pattern // "__tests__|\\.test\\."' "$CONFIG_FILE")
  REQUIRED_PLANNING=$(jq -r '.skills.required_planning // [] | join(" ")' "$CONFIG_FILE")
  STATE_FILE=$(jq -r '.state.state_file // "/tmp/.dev-workflows-state"' "$CONFIG_FILE")
  TRIVIAL_FILE=$(jq -r '.state.trivial_file // "/tmp/.dev-workflows-trivial"' "$CONFIG_FILE")
fi

# --- Check if file matches src pattern ---
if ! echo "$FILE_PATH" | grep -q "$SRC_PATTERN"; then
  exit 0  # Not a source file, no enforcement
fi

# --- Exclude test files ---
if echo "$FILE_PATH" | grep -qE "$SRC_EXCLUDE"; then
  exit 0  # Test file, no enforcement
fi

# --- Trivial override ---
if [ -f "$TRIVIAL_FILE" ]; then
  exit 0
fi

# --- Count required planning skills ---
MISSING=""
FOUND=0
TOTAL=0
for SKILL in $REQUIRED_PLANNING; do
  TOTAL=$((TOTAL + 1))
  if [ -f "$STATE_FILE" ] && grep -qx "$SKILL" "$STATE_FILE"; then
    FOUND=$((FOUND + 1))
  else
    MISSING="$MISSING  ❌ /$SKILL\n"
  fi
done

# --- Stage determination ---
HAS_CODE_REVIEW=false
HAS_VERIFICATION=false
if [ -f "$STATE_FILE" ]; then
  grep -qx "code-review" "$STATE_FILE" && HAS_CODE_REVIEW=true
  grep -qx "verification-before-completion" "$STATE_FILE" && HAS_VERIFICATION=true
fi

if [ "$FOUND" -lt "$TOTAL" ]; then
  # STAGE A: HARD STOP
  MSG="🛑 HARD STOP — Source change detected but PLANNING SKILLS NOT COMPLETE ($FOUND/$TOTAL).\n\nInvoke these skills via the Skill tool BEFORE writing more code:\n$MISSING\nDo NOT continue editing source files until all planning skills are invoked."
  echo "{\"hookSpecificOutput\":{\"message\":\"$(echo -e "$MSG")\"}}"
elif [ "$HAS_CODE_REVIEW" = false ]; then
  # STAGE B: Planning done, no code review yet
  MSG="📋 Planning complete ($FOUND/$TOTAL). Code review not yet done. Remember to invoke /code-review after implementation."
  echo "{\"hookSpecificOutput\":{\"message\":\"$MSG\"}}"
elif [ "$HAS_VERIFICATION" = false ]; then
  # STAGE C: Has code review, no verification
  MSG="📋 Review phase done. Finalization remaining — remember /verification-before-completion before claiming done."
  echo "{\"hookSpecificOutput\":{\"message\":\"$MSG\"}}"
else
  # STAGE D: All done
  MSG="✅ All workflow phases complete. Ready for deployment."
  echo "{\"hookSpecificOutput\":{\"message\":\"$MSG\"}}"
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/dev-cycle-check.sh
```

- [ ] **Step 3: Test Stage A — no planning skills**

```bash
rm -f /tmp/.dev-workflows-state
echo '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts"}}' | ./hooks/dev-cycle-check.sh
```

Expected: HARD STOP message listing missing skills.

- [ ] **Step 4: Test — non-source file (no enforcement)**

```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"/project/README.md"}}' | ./hooks/dev-cycle-check.sh
```

Expected: silent exit (no output).

- [ ] **Step 5: Test — trivial override**

```bash
touch /tmp/.dev-workflows-trivial
echo '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts"}}' | ./hooks/dev-cycle-check.sh
rm /tmp/.dev-workflows-trivial
```

Expected: silent exit (trivial override).

- [ ] **Step 6: Test Stage A — Bash tool targeting source**

```bash
rm -f /tmp/.dev-workflows-state
echo '{"tool_name":"Bash","tool_input":{"command":"sed -i s/foo/bar/ /project/src/app.ts"}}' | ./hooks/dev-cycle-check.sh
```

Expected: HARD STOP message (Bash command contains `/src/`).

- [ ] **Step 7: Test Stage B — planning done, no code review**

```bash
printf "brainstorming\nwrite-spec\nwriting-plans\n" > /tmp/.dev-workflows-state
echo '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts"}}' | ./hooks/dev-cycle-check.sh
```

Expected: "Planning complete" message mentioning code review.

- [ ] **Step 8: Test Stage C — has code review, no verification**

```bash
printf "brainstorming\nwrite-spec\nwriting-plans\ncode-review\n" > /tmp/.dev-workflows-state
echo '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts"}}' | ./hooks/dev-cycle-check.sh
```

Expected: Finalization reminder mentioning verification.

- [ ] **Step 9: Test Stage D — all complete**

```bash
printf "brainstorming\nwrite-spec\nwriting-plans\ncode-review\nverification-before-completion\n" > /tmp/.dev-workflows-state
echo '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts"}}' | ./hooks/dev-cycle-check.sh
```

Expected: "All workflow phases complete. Ready for deployment."

- [ ] **Step 10: Clean up and commit**

```bash
rm -f /tmp/.dev-workflows-state /tmp/.dev-workflows-trivial
git add hooks/dev-cycle-check.sh
git commit -m "feat: add dev-cycle-check.sh with four-stage enforcement and Bash support"
```

---

### Task 6: `compliance-status.sh` Hook

**Files:**
- Create: `hooks/compliance-status.sh`

- [ ] **Step 1: Write the hook script**

Logic from spec Section 10.5 + 11.4. Fires on ALL tool uses, outputs a compact progress score. Must be <100ms.

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- Quick exit if no config (project not set up) ---
# Cache config path per-PWD for performance (avoids cross-project contamination)
PWD_HASH=$(echo "$PWD" | md5sum 2>/dev/null | cut -d' ' -f1 || md5 -q -s "$PWD" 2>/dev/null || echo "default")
CACHE_FILE="/tmp/.dev-workflows-config-path-${PWD_HASH}"
CONFIG_FILE=""

if [ -f "$CACHE_FILE" ]; then
  CONFIG_FILE=$(cat "$CACHE_FILE")
  [ ! -f "$CONFIG_FILE" ] && CONFIG_FILE=""
fi

if [ -z "$CONFIG_FILE" ]; then
  SEARCH_DIR="$PWD"
  while [ "$SEARCH_DIR" != "/" ]; do
    if [ -f "$SEARCH_DIR/.dev-workflows.json" ]; then
      CONFIG_FILE="$SEARCH_DIR/.dev-workflows.json"
      echo "$CONFIG_FILE" > "$CACHE_FILE"
      break
    fi
    [ -d "$SEARCH_DIR/.git" ] && break
    SEARCH_DIR=$(dirname "$SEARCH_DIR")
  done
fi

[ -z "$CONFIG_FILE" ] && exit 0

# --- jq check (silent fail for performance) ---
command -v jq &>/dev/null || exit 0

# --- Read config ---
STATE_FILE=$(jq -r '.state.state_file // "/tmp/.dev-workflows-state"' "$CONFIG_FILE")
REQ_PLANNING=$(jq -r '.skills.required_planning // [] | join(" ")' "$CONFIG_FILE")
REQ_DEPLOY=$(jq -r '.skills.required_deploy // [] | join(" ")' "$CONFIG_FILE")

# --- Count phases ---
count_present() {
  local skills="$1" found=0 total=0
  for s in $skills; do
    total=$((total + 1))
    [ -f "$STATE_FILE" ] && grep -qx "$s" "$STATE_FILE" && found=$((found + 1))
  done
  echo "$found/$total"
}

PLANNING=$(count_present "$REQ_PLANNING")

# Execution: check for executing-plans
EXEC="0/1"
[ -f "$STATE_FILE" ] && grep -qx "executing-plans" "$STATE_FILE" && EXEC="1/1"

# Review: code-review + receiving-code-review + testing-strategy
REVIEW_SKILLS="code-review receiving-code-review testing-strategy"
REVIEW=$(count_present "$REVIEW_SKILLS")

# Finalization: documentation + verification-before-completion + finishing-a-development-branch
FINAL_SKILLS="documentation verification-before-completion finishing-a-development-branch"
FINAL=$(count_present "$FINAL_SKILLS")

# Total skills recorded
TOTAL_RECORDED=0
[ -f "$STATE_FILE" ] && TOTAL_RECORDED=$(wc -l < "$STATE_FILE" | tr -d ' ')

# Next required skill
NEXT=""
for s in $REQ_PLANNING; do
  if [ ! -f "$STATE_FILE" ] || ! grep -qx "$s" "$STATE_FILE"; then
    NEXT="/$s"
    break
  fi
done
if [ -z "$NEXT" ]; then
  for s in executing-plans code-review receiving-code-review testing-strategy documentation verification-before-completion; do
    if [ ! -f "$STATE_FILE" ] || ! grep -qx "$s" "$STATE_FILE"; then
      NEXT="/$s"
      break
    fi
  done
fi
[ -z "$NEXT" ] && NEXT="(all complete)"

MSG="Dev Workflows: $TOTAL_RECORDED steps | PLANNING $PLANNING | EXECUTION $EXEC | REVIEW $REVIEW | FINALIZATION $FINAL | Next: $NEXT"
echo "{\"hookSpecificOutput\":{\"message\":\"$MSG\"}}"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/compliance-status.sh
```

- [ ] **Step 3: Test — no config file (silent no-op)**

```bash
cd /tmp && echo '{}' | /Users/shafqat/Documents/Projects/dev-workflows/hooks/compliance-status.sh
```

Expected: no output (clean exit).

- [ ] **Step 4: Test — with config, partial progress**

Create a temporary `.dev-workflows.json` and state file, run the hook, verify output shows correct counts.

- [ ] **Step 5: Commit**

```bash
git add hooks/compliance-status.sh
git commit -m "feat: add compliance-status.sh — universal progress score on every tool use"
```

---

### Task 7: `completion-audit.sh` Hook

**Files:**
- Create: `hooks/completion-audit.sh`

- [ ] **Step 1: Write the hook script**

Logic from spec Section 10.6. Fires on Bash, detects git commit/push/deploy commands, checks all required skills.

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- jq check ---
command -v jq &>/dev/null || exit 0

# --- Read stdin ---
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
[ -z "$CMD" ] && exit 0

# --- Check if command is a completion action ---
IS_COMPLETION=false
echo "$CMD" | grep -qE "\bgit commit\b|\bgit push\b|\bgh pr create\b" && IS_COMPLETION=true
echo "$CMD" | grep -qi "\bdeploy\b" && IS_COMPLETION=true

[ "$IS_COMPLETION" = false ] && exit 0

# --- Find config ---
CONFIG_FILE=""
SEARCH_DIR="$PWD"
while [ "$SEARCH_DIR" != "/" ]; do
  if [ -f "$SEARCH_DIR/.dev-workflows.json" ]; then
    CONFIG_FILE="$SEARCH_DIR/.dev-workflows.json"
    break
  fi
  [ -d "$SEARCH_DIR/.git" ] && break
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

# --- Read config or defaults ---
STATE_FILE="/tmp/.dev-workflows-state"
TRIVIAL_FILE="/tmp/.dev-workflows-trivial"
REQUIRED="brainstorming write-spec code-review verification-before-completion testing-strategy documentation"

if [ -n "$CONFIG_FILE" ]; then
  STATE_FILE=$(jq -r '.state.state_file // "/tmp/.dev-workflows-state"' "$CONFIG_FILE")
  TRIVIAL_FILE=$(jq -r '.state.trivial_file // "/tmp/.dev-workflows-trivial"' "$CONFIG_FILE")
  DEPLOY_SKILLS=$(jq -r '.skills.required_deploy // [] | join(" ")' "$CONFIG_FILE")
  [ -n "$DEPLOY_SKILLS" ] && REQUIRED="$DEPLOY_SKILLS testing-strategy documentation"
fi

# --- Trivial override ---
[ -f "$TRIVIAL_FILE" ] && exit 0

# --- Check compliance ---
MISSING=""
ALL_PRESENT=true
for SKILL in $REQUIRED; do
  if [ ! -f "$STATE_FILE" ] || ! grep -qx "$SKILL" "$STATE_FILE"; then
    MISSING="$MISSING  ❌ /$SKILL\n"
    ALL_PRESENT=false
  fi
done

if [ "$ALL_PRESENT" = true ]; then
  echo '{"hookSpecificOutput":{"message":"✅ Workflow compliance verified. Proceed."}}'
else
  MSG="🛑 COMPLETION BLOCKED — Workflow incomplete.\n\nYou are attempting to commit/push/deploy but these required steps are missing:\n$MISSING\nComplete ALL required workflow steps before finalizing.\nDo NOT proceed with this action."
  echo "{\"hookSpecificOutput\":{\"message\":\"$(echo -e "$MSG")\"}}"
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/completion-audit.sh
```

- [ ] **Step 3: Test — git commit with missing skills**

```bash
rm -f /tmp/.dev-workflows-state
echo '{"tool_input":{"command":"git commit -m \"feat: add X\""}}' | ./hooks/completion-audit.sh
```

Expected: COMPLETION BLOCKED message listing all missing skills.

- [ ] **Step 4: Test — non-completion command (silent)**

```bash
echo '{"tool_input":{"command":"ls -la"}}' | ./hooks/completion-audit.sh
```

Expected: no output (clean exit).

- [ ] **Step 5: Test — all skills present**

```bash
printf "brainstorming\nwrite-spec\ncode-review\nverification-before-completion\ntesting-strategy\ndocumentation\n" > /tmp/.dev-workflows-state
echo '{"tool_input":{"command":"git commit -m \"feat: done\""}}' | ./hooks/completion-audit.sh
```

Expected: "✅ Workflow compliance verified. Proceed."

- [ ] **Step 6: Test — trivial override**

```bash
rm -f /tmp/.dev-workflows-state
touch /tmp/.dev-workflows-trivial
echo '{"tool_input":{"command":"git commit -m \"fix: typo\""}}' | ./hooks/completion-audit.sh
rm /tmp/.dev-workflows-trivial
```

Expected: silent exit (trivial override, no blocking).

- [ ] **Step 7: Test — chained command with git push**

```bash
rm -f /tmp/.dev-workflows-state
echo '{"tool_input":{"command":"cd project && git push origin main"}}' | ./hooks/completion-audit.sh
```

Expected: COMPLETION BLOCKED (word boundary match catches `git push` even in chained command).

- [ ] **Step 8: Clean up and commit**

```bash
rm -f /tmp/.dev-workflows-state /tmp/.dev-workflows-trivial
git add hooks/completion-audit.sh
git commit -m "feat: add completion-audit.sh — block premature commit/push/deploy"
```

---

### Task 8: `deploy-gate-snippet.sh`

**Files:**
- Create: `scripts/deploy-gate-snippet.sh`

- [ ] **Step 1: Write the deploy gate snippet**

Adapted from v1 but using new config format and state file paths. NOT a hook — users paste this into their deploy scripts.

```bash
#!/usr/bin/env bash
# Dev Workflows — Deploy Gate Snippet
# Paste this BEFORE your build/deploy step in your CI/CD script.
# It blocks deployment unless all required workflow skills were invoked.
set -euo pipefail

# --- Config ---
CONFIG_FILE=""
SEARCH_DIR="$PWD"
while [ "$SEARCH_DIR" != "/" ]; do
  if [ -f "$SEARCH_DIR/.dev-workflows.json" ]; then
    CONFIG_FILE="$SEARCH_DIR/.dev-workflows.json"
    break
  fi
  [ -d "$SEARCH_DIR/.git" ] && break
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

STATE_FILE="/tmp/.dev-workflows-state"
TRIVIAL_FILE="/tmp/.dev-workflows-trivial"
REQUIRED_DEPLOY="brainstorming write-spec code-review verification-before-completion"

if [ -n "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
  STATE_FILE=$(jq -r '.state.state_file // "/tmp/.dev-workflows-state"' "$CONFIG_FILE")
  TRIVIAL_FILE=$(jq -r '.state.trivial_file // "/tmp/.dev-workflows-trivial"' "$CONFIG_FILE")
  REQUIRED_DEPLOY=$(jq -r '.skills.required_deploy // [] | join(" ")' "$CONFIG_FILE")
fi

# --- Trivial override ---
if [ -f "$TRIVIAL_FILE" ]; then
  echo "ℹ️ Dev Workflows: trivial change — skipping deploy gate."
  rm -f "$STATE_FILE" "$TRIVIAL_FILE"
  exit 0
fi

# --- Skip flag ---
if [[ "${1:-}" == "--skip-workflow-check" ]]; then
  echo "⚠️ Dev Workflows: --skip-workflow-check flag used. Proceeding WITHOUT verification."
  exit 0
fi

# --- Check state file exists ---
if [ ! -f "$STATE_FILE" ]; then
  echo "❌ Dev Workflows: No workflow state found at $STATE_FILE."
  echo "   Did you run the dev workflow? Use /using-dev-workflows to set up."
  exit 1
fi

# --- Check required skills ---
MISSING=""
for SKILL in $REQUIRED_DEPLOY; do
  if ! grep -qx "$SKILL" "$STATE_FILE"; then
    MISSING="$MISSING  ❌ /$SKILL\n"
  fi
done

if [ -n "$MISSING" ]; then
  echo "❌ Dev Workflows: Deploy BLOCKED — workflow incomplete!"
  echo -e "Missing required skills:\n$MISSING"
  exit 1
fi

echo "✅ Dev Workflows: All required skills verified. Deploy proceeding."
rm -f "$STATE_FILE" "$TRIVIAL_FILE"
```

- [ ] **Step 2: Commit**

```bash
git add scripts/deploy-gate-snippet.sh
git commit -m "feat: add deploy-gate-snippet.sh for project deploy scripts"
```

---

### Task 9: Templates — CLAUDE.md.base

**Files:**
- Create: `templates/CLAUDE.md.base`

- [ ] **Step 1: Write the base CLAUDE.md template**

From spec Section 7. Includes:
- Session startup (§0)
- Project overview with `{{PROJECT_NAME}}`, `{{TECH_STACK}}`, `{{GIT_REPO}}` placeholders
- Automated enforcement description (§1)
- Active workflow reference (§2)
- **NON-NEGOTIABLE RULES** anti-rationalization block (from spec Section 11.8)

The anti-rationalization block is critical for compliance enforcement. Include it as a separate section in the base template:

```markdown
## NON-NEGOTIABLE RULES

These rules apply to EVERY non-trivial change. There are NO exceptions.

You MUST NOT:
- Skip a REQUIRED step because "it's simple enough"
- Combine or implicitly cover steps ("I did code review while writing")
- Claim a step is "not applicable" without explicit user approval
- Proceed to the next phase before completing the current phase
- Claim work is complete without running /verification-before-completion

If you believe a step is genuinely not applicable, you MUST:
1. State which step you want to skip
2. State why
3. Wait for explicit user approval before proceeding

"I already covered this" is NOT valid. Each skill MUST be explicitly
invoked via the Skill tool — implicit coverage does not count because
the enforcement hooks track Skill tool invocations, not your judgment.
```

- [ ] **Step 2: Commit**

```bash
git add templates/CLAUDE.md.base
git commit -m "feat: add CLAUDE.md.base template with anti-rationalization rules"
```

---

### Task 10: Templates — Default Config + Full Dev Cycle Workflow

**Files:**
- Create: `templates/dev-workflows.config.json.default`
- Create: `templates/workflows/full-dev-cycle.md`

- [ ] **Step 1: Write the default config**

From spec Section 9.1. JSON with `{{PROJECT_NAME}}` placeholder for the project name field.

```json
{
  "version": "1.0.0",
  "project": {
    "name": "{{PROJECT_NAME}}",
    "src_pattern": "/src/",
    "src_exclude_pattern": "__tests__|\\.test\\.",
    "active_workflow": "full-dev-cycle"
  },
  "skills": {
    "required_planning": ["brainstorming", "write-spec", "writing-plans"],
    "required_deploy": ["brainstorming", "write-spec", "code-review", "verification-before-completion"],
    "all_tracked": [
      "using-superpowers", "brainstorming", "write-spec", "design-system",
      "ux-copy", "architecture", "system-design", "writing-plans",
      "executing-plans", "code-review", "requesting-code-review",
      "receiving-code-review", "testing-strategy", "systematic-debugging",
      "debug", "tech-debt", "documentation", "verification-before-completion",
      "finishing-a-development-branch", "deploy-checklist"
    ]
  },
  "state": {
    "state_file": "/tmp/.dev-workflows-state",
    "trivial_file": "/tmp/.dev-workflows-trivial"
  }
}
```

- [ ] **Step 2: Write the full dev cycle workflow**

From spec Section 8.1. The complete 23-step workflow with REQUIRED markers and `← DO NOT SKIP` annotations on every required step.

Include the enforcement status block at the top:
```
> **ENFORCED** — Every skill invocation is tracked by PostToolUse hooks.
> HARD STOP fires if you edit source without completing planning.
> Completion audit BLOCKS git commit/push if required skills are missing.
> Compliance score is shown after EVERY tool use.
```

- [ ] **Step 3: Commit**

```bash
git add templates/dev-workflows.config.json.default templates/workflows/full-dev-cycle.md
git commit -m "feat: add default config and full-dev-cycle workflow template"
```

---

### Task 11: The `/using-dev-workflows` Skill (SKILL.md)

**Files:**
- Create: `skills/using-dev-workflows/SKILL.md`

- [ ] **Step 1: Write the SKILL.md frontmatter and overview**

```yaml
---
name: using-dev-workflows
description: Initialize Dev Workflows enforcement for a project — checks dependencies, auto-detects project, scaffolds CLAUDE.md + config + workflow files
---
```

The body is a prompt that directs Claude through three phases. Write each phase as a numbered section with explicit instructions.

- [ ] **Step 2: Write Phase 1 — Dependency Check section**

Must include ALL checks from spec Section 6.1:

1. **jq check**: Instruct Claude to run `command -v jq`. If missing → output install instructions and STOP.
2. **Superpowers check**: Instruct Claude to glob for `~/.claude/plugins/cache/*/superpowers/*/skills/brainstorming/SKILL.md`. If not found → fallback: try invoking `/brainstorming`. If still not found → output: "❌ Superpowers — install with: `/plugin install obra/superpowers`"
3. **Engineering check**: Instruct Claude to glob known paths. Fallback: try invoking `/engineering:documentation`. If not found → output: "❌ Engineering — install with: `/plugin install anthropics/knowledge-work-plugins/tree/main/engineering`"
4. **v1 incompatibility check**: Instruct Claude to read `.claude/settings.json` and check for entries referencing `record-skill.sh`, `dev-cycle-check.sh`, or `/tmp/.wyzr-workflow-state`. If found → output warning about incompatible v1 hooks and STOP until user confirms removal.

STOP means: do not proceed to Phase 2. Output the issue and wait for user to resolve it.

- [ ] **Step 3: Write Phase 2 — Auto-Detect Project section**

Instruct Claude to:
1. Read `package.json` name field, or `pyproject.toml` `[project].name`, or `Cargo.toml` `[package].name`, or directory name as fallback
2. Detect tech stack from manifest files (package.json → Node/TS, pyproject.toml → Python, etc.)
3. Run `git remote get-url origin` for repo URL
4. Detect source pattern by checking if `src/`, `app/`, or `lib/` directories exist; default `/src/`
5. Present all detected values for one-shot confirmation: "Look right? (yes / edit)"
6. If user says "edit" → ask which fields to change

- [ ] **Step 4: Write Phase 3 — Scaffold section**

Instruct Claude to:
1. **Check for existing `.dev-workflows.json`** — if found, this is an update/re-init. Offer: "Dev Workflows already configured. Refresh templates and config from plugin v{{version}}? (Your customizations in .dev-workflows.json will be preserved.)"
2. **Check for existing `CLAUDE.md`** — if found, ask: "Existing CLAUDE.md found. Replace with Dev Workflows template (your content will be lost), or keep yours and append the workflow reference?" Replace = overwrite. Append = keep existing, add only the Active Workflow section.
3. **Read template from** `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.base` — replace `{{PROJECT_NAME}}`, `{{TECH_STACK}}`, `{{GIT_REPO}}` with detected values. Write to project root.
4. **Read config from** `${CLAUDE_PLUGIN_ROOT}/templates/dev-workflows.config.json.default` — replace `{{PROJECT_NAME}}`, fill in detected `src_pattern`. Write to `.dev-workflows.json`.
5. **Read workflow from** `${CLAUDE_PLUGIN_ROOT}/templates/workflows/full-dev-cycle.md` — copy to `docs/workflows/full-dev-cycle.md`.
6. **Create directories**: `docs/specs/`, `docs/workflows/`
7. **Create placeholder docs**: `Master-PRD.md`, `Architecture-and-Design.md`, `Testing-Strategy-and-Plan.md`, `CICD.md` — each with a title heading and "TODO" placeholder.
8. **Stage and commit all scaffolded files** with message: "feat: initialize Dev Workflows enforcement"
9. **Invoke `/using-superpowers`** to ensure the skills system is active.
10. Output: "Dev Workflows initialized. Start any task and the active workflow will be enforced automatically."

- [ ] **Step 5: Add update/upgrade handling at the top of the skill**

Before Phase 1, instruct Claude to check if `.dev-workflows.json` already exists in the project root. If it does, this is a re-run (update scenario). Skip Phase 1 dependency checks (already verified on first setup). Go directly to Phase 3 with update mode: refresh templates, preserve user customizations.

- [ ] **Step 6: Commit**

```bash
git add skills/using-dev-workflows/SKILL.md
git commit -m "feat: add /using-dev-workflows skill — single entry point for project setup"
```

---

### Task 12: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

Sections:
1. **What is Dev Workflows?** — One paragraph: enforced development workflows for Claude Code
2. **Install** — `/plugin install alo-exp/dev-workflows`
3. **Prerequisites** — Superpowers + Engineering plugins (with install commands), `jq`
4. **Quick Start** — Install plugin → run `/using-dev-workflows` in your project → done
5. **What it does** — Brief description of the six-layer enforcement system
6. **Customization** — `.dev-workflows.json` config overview
7. **Workflows** — Description of full-dev-cycle, mention future workflows
8. **For Deploy Scripts** — How to use `deploy-gate-snippet.sh`
9. **License** — MIT

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with install instructions and overview"
```

---

### Task 13: .gitignore + Final Verification

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Create `.gitignore`**

```
.DS_Store
/tmp/
*.swp
*.swo
```

- [ ] **Step 2: Verify complete file tree**

```bash
find . -not -path './.git/*' -type f | sort
```

Expected: all files from the spec's plugin structure present.

- [ ] **Step 3: Verify all hooks are executable**

```bash
ls -la hooks/session-start hooks/record-skill.sh hooks/dev-cycle-check.sh hooks/compliance-status.sh hooks/completion-audit.sh
```

Expected: all have execute permission.

- [ ] **Step 4: Verify hooks.json references match actual files**

```bash
jq -r '.. | .command? // empty' hooks/hooks.json | sed 's/.*\///' | sed 's/".*//' | sort
ls hooks/ | grep -v hooks.json | grep -v run-hook.cmd | sort
```

Expected: both lists match.

- [ ] **Step 5: Commit .gitignore**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

- [ ] **Step 6: Add remote and push**

```bash
git remote add origin https://github.com/alo-exp/dev-workflows.git
git push -u origin main
```

Note: The GitHub repo must be created first. Ask user before pushing.

---

### Task 14: Archive v1 Repo

- [ ] **Step 1: Ask user to confirm archiving `alo-exp/dev-workflow`**

The user should archive `alo-exp/dev-workflow` on GitHub (Settings → Archive this repository). This is a manual step — do not automate it.

- [ ] **Step 2: Add archive notice to v1 README**

In the `alo-exp/dev-workflow` repo, prepend to README.md:

```markdown
> ⚠️ **This repo is archived.** Use [dev-workflows](https://github.com/alo-exp/dev-workflows) (the plugin version) instead.
```

---

## Task Dependency Graph

```
Task 1 (manifests)
  └── Task 2 (hooks infrastructure)
        ├── Task 3 (session-start)
        ├── Task 4 (record-skill.sh)
        ├── Task 5 (dev-cycle-check.sh)
        ├── Task 6 (compliance-status.sh)
        └── Task 7 (completion-audit.sh)
Task 8 (deploy-gate-snippet)     ← independent (not a hook)
Task 9 (CLAUDE.md.base)          ← independent
Task 10 (config + workflow)       ← independent
Task 11 (SKILL.md)                ← depends on 9, 10 (references template paths)
Task 12 (README)                  ← depends on all above
Task 13 (verification)            ← depends on all above
Task 14 (archive v1)              ← independent, manual
```

**Parallelizable groups:**
- Group A (hooks, after Task 2): Tasks 3, 4, 5, 6, 7
- Group B (independent, can run in parallel with Group A): Tasks 8, 9, 10
- Sequential: Task 1 → Task 2 → Groups A+B → Task 11 → Task 12 → Task 13 → Task 14

**Note on Bash heuristic in dev-cycle-check.sh**: For Bash tool inputs, the hook checks if the command string contains `src_pattern` (e.g., `/src/`). This is a simple heuristic — it may produce false positives on read-only commands like `cat /src/README.md`. This is an acceptable trade-off: false positives (unnecessary HARD STOP) are harmless (user sees the status and can proceed), while false negatives (missed enforcement) would undermine compliance. The heuristic can be refined in future versions.
