#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Deploy Gate Snippet
#
# Paste this into your deploy script BEFORE the build step.
# It blocks deployment unless required skills were invoked.
# ─────────────────────────────────────────────────────────────────────────────

# ── Workflow Completion Gate ──
STATE_FILE="/tmp/.wyzr-workflow-state"
TRIVIAL_FILE="/tmp/.wyzr-workflow-trivial"
SKIP_WORKFLOW=false

# Add to your flag parser:  --skip-workflow-check) SKIP_WORKFLOW=true ;;

echo "── Workflow check ─────────────────────"
if [ -f "$TRIVIAL_FILE" ]; then
  echo "   ✓ Trivial change mode — skill checks skipped"
elif [ "$SKIP_WORKFLOW" = true ]; then
  echo "   ⚠ WARNING: Workflow check SKIPPED via --skip-workflow-check"
elif [ ! -f "$STATE_FILE" ]; then
  echo "   ❌ No workflow state found!"
  echo "   Run the §8 skill workflow before deploying."
  echo "   Required: /brainstorming /write-spec /code-review /verification-before-completion"
  exit 1
else
  REQUIRED="brainstorming write-spec code-review verification-before-completion"
  MISSING=""
  for skill in $REQUIRED; do
    if ! grep -qx "$skill" "$STATE_FILE" 2>/dev/null; then
      MISSING="$MISSING /$skill"
    fi
  done
  if [ -n "$MISSING" ]; then
    echo "   ❌ Workflow incomplete! Missing:$MISSING"
    exit 1
  else
    echo "   ✓ All required §8 skills completed"
  fi
fi

# ── Add AFTER successful deploy to clean up state: ──
# rm -f /tmp/.wyzr-workflow-state /tmp/.wyzr-workflow-trivial
