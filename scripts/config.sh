#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Workflow Enforcement Configuration
#
# Edit these values to customize for your project.
# ─────────────────────────────────────────────────────────────────────────────

# Skills required before any src/ edit (Stage A gate)
REQUIRED_PLANNING_SKILLS="brainstorming write-spec writing-plans"

# Skills required before deployment (deploy gate)
REQUIRED_DEPLOY_SKILLS="brainstorming write-spec code-review verification-before-completion"

# All tracked skills (for display purposes)
ALL_SKILLS="using-superpowers brainstorming write-spec writing-plans executing-plans test-driven-development code-review requesting-code-review receiving-code-review testing-strategy systematic-debugging debug tech-debt documentation verification-before-completion deploy-checklist"

# Path to these scripts from the repo root (used in settings.json)
SCRIPT_DIR_FROM_ROOT="scripts/workflow-enforcement"

# Source file pattern — edits matching this trigger enforcement
# Used in dev-cycle-check.sh to filter relevant files
SRC_PATTERN="/src/"
SRC_EXCLUDE_PATTERN="__tests__|\.test\."

# State file paths (session-scoped in /tmp/)
STATE_FILE="/tmp/.wyzr-workflow-state"
TRIVIAL_FILE="/tmp/.wyzr-workflow-trivial"
