# Dev Workflows Plugin — Design Specification

**Date**: 2026-03-31
**Author**: Ālo Labs
**Status**: Draft
**Repo**: `alo-exp/dev-workflows` (new repo; `alo-exp/dev-workflow` archived as v1)

---

## 1. Problem

Teams with no AI-driven software engineering experience need a single install that gives them an enforced, structured development workflow. Today, setting up the dev-workflow enforcement requires manually copying scripts, editing CLAUDE.md, and configuring hooks. This is too many steps for a zero-experience team.

## 2. Solution

A Superpowers-native plugin called **Dev Workflows** published under the **Ālo Labs** marketplace. It:

- Declares Superpowers and Engineering as dependencies (does not bundle them)
- Provides a single entry skill (`/using-dev-workflows`) that scaffolds everything for a project
- Ships PostToolUse hooks that enforce the workflow automatically after setup
- Uses modular workflow files so future workflows can be added without changing the base

## 3. Target Platforms

- **Primary**: Claude Desktop — Code tab
- **Secondary**: Claude Code CLI

## 4. Plugin Structure

```
alo-exp/dev-workflows/
├── .claude-plugin/
│   ├── plugin.json              # Plugin identity, paths, metadata
│   └── marketplace.json         # Ālo Labs marketplace, dependency declarations
├── hooks/
│   ├── hooks.json               # SessionStart + 2x PostToolUse declarations
│   ├── session-start            # Ensures /using-superpowers fires each session
│   ├── record-skill.sh          # PostToolUse Skill — tracks invocations to state file
│   ├── dev-cycle-check.sh       # PostToolUse Edit|Write — enforces planning gate
│   └── run-hook.cmd             # Cross-platform polyglot wrapper (CMD batch + bash)
├── scripts/
│   └── deploy-gate-snippet.sh   # Copy-paste snippet for deploy scripts (NOT a hook)
├── skills/
│   └── using-dev-workflows/
│       └── SKILL.md             # The single entry point skill
├── templates/
│   ├── CLAUDE.md.base           # Base rules stamped into every project
│   ├── dev-workflows.config.json.default  # Default per-project config
│   └── workflows/
│       ├── full-dev-cycle.md    # The 23-step enforced workflow
│       └── (future: bug-fix.md, spike.md, docs-only.md)
├── package.json                 # npm-style metadata (name, version, repo — not published to npm)
├── README.md                    # Install instructions + overview
├── CHANGELOG.md
└── LICENSE
```

**Notes on structure:**
- `deploy-gate-snippet.sh` lives in `scripts/` not `hooks/` — it is not a plugin hook, it is a snippet users paste into their own deploy scripts.
- `run-hook.cmd` is a polyglot file (valid as both CMD batch and bash) for Windows compatibility, same pattern as Superpowers.
- `package.json` provides metadata only (name, version, description, repository). It is NOT published to npm. This file exists for consistency with the Superpowers plugin convention.

### 4.1 System Dependencies

The hooks require `jq` for JSON parsing. If `jq` is not installed:
- Hooks output a clear error: `"❌ Dev Workflows hooks require jq. Install: brew install jq (macOS) / apt install jq (Linux)"`
- Hooks exit cleanly (no crash, no silent failure)
- `/using-dev-workflows` Phase 1 checks for `jq` alongside plugin dependency checks

## 5. Plugin Manifests

### 5.1 `.claude-plugin/plugin.json`

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

### 5.2 `.claude-plugin/marketplace.json`

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

### 5.3 `hooks/hooks.json`

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
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/dev-cycle-check.sh\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

## 6. The `/using-dev-workflows` Skill

Single entry point. Invoked explicitly by the user once per project. Three phases:

### 6.1 Phase 1: Dependency Check

**System dependencies:**
1. Check for `jq`: run `command -v jq`
   - If not found → output install instructions for jq and STOP

**Plugin dependencies:**
2. Check if Superpowers skills exist:
   - Primary: Glob for `~/.claude/plugins/cache/*/superpowers/*/skills/brainstorming/SKILL.md`
   - Fallback: Attempt to invoke `/brainstorming` and check if it resolves (handles non-standard install paths)
   - If not found by either method → Superpowers missing
3. Check if Engineering skills exist:
   - Primary: Glob known Engineering plugin paths
   - Fallback: Attempt to invoke `/engineering:documentation` and check if it resolves
   - If not found by either method → Engineering missing
4. If either missing, output install instructions and STOP:

```
⚠️ Dev Workflows requires these plugins:

❌ Superpowers — install with:
   /plugin install obra/superpowers

✅ Engineering — detected

Install the missing plugin(s), then run /using-dev-workflows again.
```

5. If both present → proceed to Phase 2.

**v1 incompatibility check:**
6. Check for v1 hook remnants — look for `.claude/settings.json` entries referencing `record-skill.sh`, `dev-cycle-check.sh`, or `/tmp/.wyzr-workflow-state` from the old `alo-exp/dev-workflow` repo.
   - If found → output warning: "⚠️ Found v1 dev-workflow hooks in .claude/settings.json. These are incompatible with the Dev Workflows plugin (they write to different state files). Remove the old PostToolUse hook entries before proceeding."
   - STOP until user confirms removal.

### 6.2 Phase 2: Auto-Detect Project

Read project signals to pre-fill configuration:

| Signal | Source |
|--------|--------|
| Project name | `package.json` name, `pyproject.toml` name, directory name (fallback) |
| Tech stack | `package.json` (Node/JS/TS), `pyproject.toml` (Python), `Cargo.toml` (Rust), `go.mod` (Go), `pom.xml`/`build.gradle` (Java), etc. |
| Git repo | `git remote get-url origin` |
| Source pattern | Detect `src/`, `app/`, `lib/` directories; default `/src/` |

Present summary for one-shot confirmation:

```
Detected:
  Project:  MyApp
  Stack:    Next.js + TypeScript
  Repo:     alo-exp/myapp
  Source:   src/

Look right? (yes / edit)
```

If user says "edit" → ask which fields to change.

### 6.3 Phase 3: Scaffold

1. **Check for existing CLAUDE.md** — if found, ask: "Existing CLAUDE.md found. Replace with Dev Workflows template, or keep yours and append the workflow reference?"
   - **Replace**: Overwrites with the template (user's content is lost — warn them)
   - **Append**: Keeps existing CLAUDE.md, appends only the "Active Workflow" section (§2 from the base template) so Claude knows to load `docs/workflows/`. User retains all their existing rules.
2. **Write CLAUDE.md** from `templates/CLAUDE.md.base` (if replace) or append workflow section (if append) — fill in `{{PROJECT_NAME}}`, `{{TECH_STACK}}`, `{{GIT_REPO}}`
3. **Write `.dev-workflows.json`** from `templates/dev-workflows.config.json.default` — fill in detected `src_pattern`, project name
4. **Copy active workflow** to `docs/workflows/full-dev-cycle.md`
5. **Create docs scaffold**:
   - `docs/specs/` — for brainstorming specs
   - `docs/workflows/` — workflow files
6. **Create placeholder docs**:
   - `Master-PRD.md`
   - `Architecture-and-Design.md`
   - `Testing-Strategy-and-Plan.md`
   - `CICD.md`
7. **Instruct Claude to stage and commit all scaffolded files** (the skill is a SKILL.md prompt, not executable code — it directs Claude to run `git add` and `git commit`)
8. **Invoke `/using-superpowers`** — ensure skills system is active

Output: "Dev Workflows initialized. Start any task and the active workflow will be enforced automatically."

## 7. Base CLAUDE.md Template

`templates/CLAUDE.md.base` contains only universal rules — no workflow steps:

```markdown
# {{PROJECT_NAME}} — Claude Code Instructions

> **Always adhere strictly to this file — it overrides all defaults.**

---

## 0. Session Startup (Automatic)

At the very start of any new session, perform these steps automatically:

1. **Switch to Opus 4.6 (1M context)** if not already selected.
2. **Read all project docs** — this file, docs/context.md, and 100% of docs/.
3. **Compact the context** — run /compact to free context for the task.
4. **Switch back to original model** if it was changed in step 1.

---

## Project Overview

- **Stack**: {{TECH_STACK}}
- **Git repo**: {{GIT_REPO}}

---

## 1. Automated Enforcement

Five layers enforce compliance:

1. **Pre-commit hook** — Blocks commits missing doc sync or with failing tests
2. **Pre-push hook** — Blocks pushes without Co-Authored-By footer
3. **PostToolUse — Skill tracker** — Records every skill invocation
4. **PostToolUse — Stage enforcer** — HARD STOP if planning incomplete
5. **Deploy gate** — BLOCKS deployment unless required skills invoked

**Trivial changes**: `touch /tmp/.dev-workflows-trivial`

**Subagent commits**: Every git commit MUST use HEREDOC format and end with:
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>

---

## 2. Active Workflow

The active workflow is loaded from `docs/workflows/`. Claude MUST read
the active workflow file before starting any non-trivial task.

**Default**: `docs/workflows/full-dev-cycle.md`

**Skill not found rule**: If a skill listed in the workflow cannot be
invoked, STOP and notify the user immediately. Do NOT silently skip.

**Rules**:
- Do NOT stop until the final outcome is achieved
- Always use /systematic-debugging + /debug for ANY bug
- Always strictly adhere to this CLAUDE.md 100%
```

## 8. Modular Workflows

### 8.1 `templates/workflows/full-dev-cycle.md`

The current 23-step process, extracted from the existing CLAUDE.md.template §3:

```
PLANNING (must complete before ANY src/ edit — HARD STOP enforced):
1.  /using-superpowers              — Establish available skills                 REQUIRED
2.  /using-git-worktrees            — ASK user: "Should I use a git worktree?"
3.  /brainstorming                  — Explore intent, constraints, approaches    REQUIRED
                                      Point to spec directory: docs/specs/
4.  /write-spec                     — Write or update spec in docs/specs/;       REQUIRED
                                      update Master-PRD.md
5.  /design-system      (if needed) — Visual/UI design
6.  /ux-copy            (if needed) — Review UX copy
7.  /architecture       (if needed) — ADR for architectural decisions
8.  /system-design      (if needed) — Service/component design
9.  /writing-plans                  — Detailed implementation plan               REQUIRED

EXECUTION:
10. /executing-plans                — Execute using BOTH:                        REQUIRED
                                        /test-driven-development (TDD)
                                        /subagent-driven-development (parallel)

REVIEW (must complete before deploy — deploy gate enforced):
11. /code-review                    — Round 1 self-review                        REQUIRED
    superpowers:code-reviewer agent — Run code-reviewer subagent
12. /requesting-code-review         — Request external/peer review
13. /receiving-code-review          — Accept/reject all items from 11-12         REQUIRED
14. /writing-plans                  — Plan to address accepted review items
15. /executing-plans                — Implement the review-driven plan
16. /testing-strategy               — Define best test strategy                  REQUIRED
17. /systematic-debugging + /debug  — Use BOTH for any bug encountered

FINALIZATION (must complete before deploy — deploy gate enforced):
18. /tech-debt                      — Identify and document technical debt
19. /documentation                  — Update/create all project docs              REQUIRED
                                      Minimum: Master-PRD.md,
                                      Architecture-and-Design.md,
                                      Testing-Strategy-and-Plan.md, CICD.md
20. /verification-before-completion — Produce evidence before claiming done      REQUIRED
21. /finishing-a-development-branch — If on dev branch: merge prep + cleanup     REQUIRED

DEPLOYMENT:
22. CICD pipeline                   — Use existing or set up before deploying    REQUIRED
                                      GitHub repos: use GitHub Actions
23. /deploy-checklist               — Pre-deployment verification gate           REQUIRED
```

### 8.2 Future Workflows (Planned)

These are placeholders — not built in v1.0.0:

- `bug-fix.md` — Abbreviated workflow: reproduce → debug → fix → test → verify
- `spike.md` — Exploratory: brainstorm → prototype → document findings
- `docs-only.md` — Documentation changes: write → review → commit

New workflows are added by creating a new file in `templates/workflows/` and copying to projects on next setup or update.

## 9. Per-Project Configuration

### 9.1 `.dev-workflows.json`

Lives in project root. Hooks read this at runtime via `jq`.

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

### 9.2 How Hooks Read Config

All hooks locate `.dev-workflows.json` by walking up from the relevant path:
- `record-skill.sh`: walks up from `$PWD`
- `dev-cycle-check.sh`: walks up from the edited file's directory

**Walk-up boundaries**: Stop at whichever is found first:
- A directory containing `.git/` (git root — most common boundary)
- Filesystem root `/` (absolute boundary)

This prevents hooks in a monorepo sub-package from accidentally reading a config file in a parent project.

**Config resolution order:**
1. `.dev-workflows.json` found by walking up (first match wins)
2. Hardcoded defaults in hook scripts (fallback, matching the template values above)

## 10. Hook Behavior

### 10.1 `session-start`

**Trigger**: SessionStart (startup|clear|compact)

**Note on SessionStart matcher syntax**: The Superpowers plugin uses this exact pattern (`"matcher": "startup|clear|compact"`). If Claude Code's SessionStart hook type does not support matchers (lifecycle hooks may differ from tool-use hooks), this will be validated during implementation. If matchers are not supported, the SessionStart entry will be declared without a matcher (fires on every session start), which is acceptable since the hook is lightweight and idempotent.

**Detection strategy for Superpowers' SessionStart**: The hook cannot reliably detect whether Superpowers already injected `/using-superpowers` in the current session. Instead, it uses a **write-always, last-wins** approach:
- The hook always outputs the `/using-superpowers` skill content
- If Superpowers already injected it, the duplicate content is harmless (Claude sees the same instructions twice, which is idempotent)
- This avoids fragile marker-detection logic that would break if Superpowers changes its output format

**Logic**:
1. Locate the Superpowers `using-superpowers/SKILL.md` file via glob (`~/.claude/plugins/cache/*/superpowers/*/skills/using-superpowers/SKILL.md`)
2. If found → read the file and inject its content via JSON output:
   ```json
   {
     "hookSpecificOutput": {
       "additionalContext": "<content of using-superpowers SKILL.md>"
     }
   }
   ```
3. If Superpowers not installed → output nothing (silent no-op). Dependency checking is the responsibility of `/using-dev-workflows`, not the session-start hook.

**Stdin schema for SessionStart hooks**: SessionStart hooks may receive no stdin or an empty JSON object. This hook does not read stdin — it only produces output.

### 10.2 `record-skill.sh`

**Trigger**: PostToolUse, matcher `Skill`

**Stdin schema**: `{"tool_input":{"skill":"brainstorming"}}` — the `tool_input` object contains the skill name as passed to the Skill tool.

**Logic**:
1. Read JSON from stdin
2. Extract skill name via `jq`: `.tool_input.skill`
3. Strip namespace prefixes using general pattern `sed 's/^[a-zA-Z_-]*://'` — this handles any plugin prefix (superpowers:, engineering:, dev-workflows:, design:, or future plugins) without maintaining an explicit allowlist
4. Locate `.dev-workflows.json` by walking up from `$PWD` (stop at filesystem root or `.git/` directory, whichever is found first). If not found → use hardcoded defaults.
5. Read `state.state_file` from config (default: `/tmp/.dev-workflows-state`)
6. Check `skills.all_tracked` — only record if the stripped skill name is in the tracked list. **If not tracked**: output `{"hookSpecificOutput": {"message": "ℹ️ Skill not tracked by Dev Workflows: <name>"}}` (informational, not an error)
7. If tracked: append to state file (no duplicates, `grep -qx` check)
8. Output: `{"hookSpecificOutput": {"message": "✅ Skill recorded: brainstorming"}}`

**Why filter against `all_tracked`**: Unlike v1 which recorded every skill indiscriminately, filtering prevents noise from unrelated plugins. This ensures the state file only contains skills relevant to the active workflow's enforcement checks.

### 10.3 `dev-cycle-check.sh`

**Trigger**: PostToolUse, matcher `Edit|Write`

**Stdin schema**: The PostToolUse payload varies by tool:
- For Edit: `{"tool_input":{"file_path":"/path/to/file", ...}}`
- For Write: `{"tool_input":{"file_path":"/path/to/file", ...}}`
- Fallback: `{"tool_response":{"filePath":"/path/to/file"}}` (some tool versions)
- Extraction: `.tool_input.file_path // .tool_response.filePath // ""` (try both with jq fallback)

**Logic**:
1. Read JSON from stdin, extract file path using the fallback pattern above
2. Locate `.dev-workflows.json` by walking up from the file's directory (stop at filesystem root or `.git/`, whichever first). If not found → use hardcoded defaults.
3. Check if file path matches `project.src_pattern` from config (default `/src/`)
4. Exclude if file matches `project.src_exclude_pattern` (tests)
5. If neither match → silent no-op (non-source file, no enforcement needed)
6. If trivial file exists (`state.trivial_file`) → skip all checks
7. Read state file, count required planning skills present
8. **Stage A** (0 of N planning skills): HARD STOP output, list missing skills
9. **Stage B** (all planning done, no code-review yet): Progress checklist
10. **Stage C** (has code-review, no verification): Finalization reminder
11. **Stage D** (all done): Ready for deployment

**Error handling**: If the hook fails (jq not found, permission denied, malformed JSON), output valid JSON: `{"hookSpecificOutput": {"message": "⚠️ Dev Workflows hook error: <description>. Workflow enforcement skipped for this edit."}}` and exit 0 (non-blocking). Never crash the user's edit operation.

### 10.4 `deploy-gate-snippet.sh`

**Not a hook** — a copy-paste snippet for project deploy scripts.

**Logic**:
1. If trivial file exists → skip all checks
2. If `--skip-workflow-check` flag → warn but allow
3. Read state file, check all `skills.required_deploy` are present
4. If any missing → ERROR, block deploy
5. If all present → allow, clean up state files

## 11. Known Limitations and Edge Cases

### 11.1 State File Scoping

The state file (default `/tmp/.dev-workflows-state`) is **session-scoped but not project-scoped**. Known implications:

- **Multiple projects in one session**: If a user switches between projects in the same Claude session, skill recordings from Project A will carry over to Project B. This is acceptable for v1.0.0 because Claude sessions are typically single-project.
- **Concurrent sessions**: Two Claude sessions against the same project share the same state file. Skill recordings from one session will be visible to the other. This is acceptable because it is additive (never removes skills).
- **Future improvement**: If project-scoping becomes necessary, the state file path can include a project hash: `/tmp/.dev-workflows-state-<hash-of-git-root>`. This is a config change in `.dev-workflows.json`, not a hook code change.

### 11.2 State File Persistence Across Sessions

On macOS, `/tmp/` survives across sessions but is cleared on reboot. On Linux, `/tmp/` behavior varies by distribution. Implications:

- A user who completed planning in session 1 will NOT be re-prompted in session 2 (state persists). This is **intentional** — re-invoking planning skills for an ongoing feature would be disruptive.
- A reboot clears state. The user will be HARD STOPPED and must re-invoke planning skills. This is **acceptable** — reboots are infrequent and re-invoking skills is fast.
- The deploy gate cleans up state files after successful deploy, ensuring a fresh start for the next feature.

### 11.3 The `active_workflow` Config Key

The `project.active_workflow` key in `.dev-workflows.json` is currently **informational only**. Hooks do not parse workflow files — they read `skills.required_planning` and `skills.required_deploy` directly from the config. The `active_workflow` value tells Claude which file to load from `docs/workflows/` when starting a task.

**Future**: When multiple workflows exist (bug-fix, spike, etc.), the `active_workflow` key could drive which `required_*` skill lists apply. This would be implemented by having the workflow files declare their own required skills, which the hooks read dynamically. This is a v2.0.0 concern — for now, the config is the single source of truth for enforcement.

### 11.4 Hook Failure Behavior

All hooks follow a **non-blocking failure** policy:
- If a hook script fails (jq missing, permission denied, malformed JSON, unexpected error), it outputs valid JSON with a warning message and exits 0.
- This ensures that a broken hook never prevents the user from editing files or invoking skills.
- The warning message gives the user enough information to diagnose the issue.

### 11.5 Update / Upgrade Path

When the plugin is updated (new version installed), existing projects are NOT automatically updated. The user must:
1. Run `/using-dev-workflows` again in their project
2. The skill detects existing `.dev-workflows.json` and `CLAUDE.md`, and offers: "Dev Workflows plugin updated to v1.1.0. Update your project files? (This will refresh workflow templates and config defaults. Your customizations in .dev-workflows.json will be preserved.)"
3. Template files (`docs/workflows/*.md`) are refreshed from the plugin
4. `.dev-workflows.json` is merged: new keys are added with defaults, existing customized values are preserved
5. `CLAUDE.md` base sections are updated, user-added sections preserved

---

## 12. Dependency Detection

### 12.1 During `/using-dev-workflows` (thorough)

| Plugin | Detection Method | Install Command |
|--------|-----------------|-----------------|
| Superpowers | Glob `~/.claude/plugins/cache/*/superpowers/*/skills/brainstorming/SKILL.md` | `/plugin install obra/superpowers` |
| Engineering | Glob known paths + attempt to resolve `engineering:documentation` | `/plugin install anthropics/knowledge-work-plugins/tree/main/engineering` |

If either missing → output table showing status of each, install commands, and STOP.

### 12.2 During SessionStart (lightweight)

Locates and injects `/using-superpowers` content unconditionally (write-always, idempotent). Does NOT check for Engineering plugin (that's a setup-time concern, not a per-session concern).

## 13. Existing Repo Transition

- **Archive** `alo-exp/dev-workflow` (singular) as v1 — mark as archived on GitHub
- **Create** `alo-exp/dev-workflows` (plural) as the new plugin repo
- No migration path needed — the old repo was a manual setup guide; the new repo replaces it entirely

## 14. Future Extensibility

### 14.1 Adding New Workflows

1. Create `templates/workflows/<name>.md` in the plugin
2. Update `dev-workflows.config.json.default` to include the new workflow in available options
3. Users pull update; new workflow appears in their `docs/workflows/` on next setup or manual copy
4. Claude selects the right workflow based on task context or user instruction

### 14.2 Adding New Plugins as Dependencies

As more leading plugins emerge:
1. Add to `marketplace.json` dependencies
2. Update `/using-dev-workflows` Phase 1 to check for the new plugin
3. Update workflows to reference new plugin's skills

### 14.3 Per-Team Customization

Teams customize via `.dev-workflows.json`:
- Change `src_pattern` for non-standard project layouts
- Modify `required_planning` / `required_deploy` skill lists
- Set `active_workflow` to a different workflow file
- Add custom tracked skills
