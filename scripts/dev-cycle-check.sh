#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Dev Cycle Enforcement Hook — Stage-Aware (Portable)
#
# PostToolUse hook for Edit|Write — fires when source code is modified.
# Reads workflow state and outputs stage-appropriate enforcement content.
# Source config.sh for customizable skill lists and paths.
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Read the file path from stdin JSON
FILE=$(jq -r '.tool_input.file_path // .tool_response.filePath // ""' 2>/dev/null)

# Only trigger for source code changes (configurable patterns)
if [[ "$FILE" != *"$SRC_PATTERN"* ]]; then
  exit 0
fi
# Exclude test files
if echo "$FILE" | grep -qE "$SRC_EXCLUDE_PATTERN"; then
  exit 0
fi

# ── Helper: check if a skill is recorded ──
has_skill() {
  [ -f "$STATE_FILE" ] && grep -qx "$1" "$STATE_FILE" 2>/dev/null
}

# ── Helper: format skill status ──
skill_status() {
  if has_skill "$1"; then
    echo "  ✓ /$1"
  else
    echo "  ❌ /$1"
  fi
}

# ── Count planning skills ──
PLANNING_COUNT=0
for s in $REQUIRED_PLANNING_SKILLS; do
  has_skill "$s" && PLANNING_COUNT=$((PLANNING_COUNT + 1))
done
PLANNING_TOTAL=$(echo $REQUIRED_PLANNING_SKILLS | wc -w | tr -d ' ')

HAS_CODE_REVIEW=false
has_skill "code-review" && HAS_CODE_REVIEW=true

HAS_VERIFICATION=false
has_skill "verification-before-completion" && HAS_VERIFICATION=true

# ── Standard checklist ──
STANDARD="MANDATORY CHECKLIST:\n[ ] 1. Update docs if requirements/design changed\n[ ] 2. Run blast-radius check — identify ALL affected files\n[ ] 3. Run tests — 0 failures required\n[ ] 4. Update version identifier\n[ ] 5. git commit with docs in SAME commit\n\nSUBAGENT DISPATCH RULES — Include in EVERY subagent prompt that may commit:\n- Every git commit MUST end with:\n  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

# ── TRIVIAL PATH ──
if [ -f "$TRIVIAL_FILE" ]; then
  cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "🚨 DEV CYCLE — Source modified (trivial mode).\n\n${STANDARD}"
  }
}
HOOK_JSON
  exit 0
fi

# ── STAGE A: Pre-planning (HARD STOP) ──
if [ "$PLANNING_COUNT" -lt "$PLANNING_TOTAL" ]; then
  SKILL_LIST=""
  for s in $REQUIRED_PLANNING_SKILLS; do
    if has_skill "$s"; then
      SKILL_LIST="${SKILL_LIST}\n  ✓ /$s"
    else
      SKILL_LIST="${SKILL_LIST}\n  ❌ /$s ← REQUIRED"
    fi
  done

  cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "🛑 HARD STOP — Source change detected but PLANNING SKILLS NOT COMPLETE.\n\nInvoke these skills via the Skill tool BEFORE writing more code:\n${SKILL_LIST}\n\nSTOP EDITING. Invoke missing skills NOW.\nTrivial change? Run: touch /tmp/.wyzr-workflow-trivial\n\n${STANDARD}"
  }
}
HOOK_JSON
  exit 0
fi

# ── STAGE B: Implementing ──
if [ "$HAS_CODE_REVIEW" = false ]; then
  cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "✅ Planning complete. Implementation in progress.\n\nREMAINING AFTER IMPLEMENTATION:\n$(skill_status code-review) ← REQUIRED for deploy\n$(skill_status testing-strategy)\n$(skill_status verification-before-completion) ← REQUIRED for deploy\n\n${STANDARD}"
  }
}
HOOK_JSON
  exit 0
fi

# ── STAGE C: Reviewing ──
if [ "$HAS_VERIFICATION" = false ]; then
  cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "✅ Implementation and code review complete.\n\nREMAINING BEFORE DEPLOY:\n$(skill_status documentation)\n$(skill_status verification-before-completion) ← REQUIRED for deploy\n$(skill_status deploy-checklist)\n\n${STANDARD}"
  }
}
HOOK_JSON
  exit 0
fi

# ── STAGE D: Complete ──
cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "✅ All required skills complete. Ready for deployment.\n\n${STANDARD}"
  }
}
HOOK_JSON
