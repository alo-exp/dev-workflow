#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Record Skill Invocation (Portable)
#
# PostToolUse hook for the Skill tool — records each skill invocation to a
# session state file. Source config.sh for customizable paths.
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Read skill name from stdin JSON (Claude Code PostToolUse provides tool_input on stdin)
SKILL=$(jq -r '.tool_input.skill // ""' 2>/dev/null)

# Normalize: strip namespace prefixes (superpowers:, engineering:, etc.)
SKILL=$(echo "$SKILL" | sed 's/^[a-zA-Z_-]*://')

if [ -n "$SKILL" ]; then
  touch "$STATE_FILE"
  if ! grep -qx "$SKILL" "$STATE_FILE" 2>/dev/null; then
    echo "$SKILL" >> "$STATE_FILE"
  fi
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "✅ Skill recorded: /$SKILL"
  }
}
EOF
fi
