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
│   ├── deploy-gate-snippet.sh   # Copy-paste snippet for deploy scripts
│   └── run-hook.cmd             # Cross-platform wrapper (Windows + Unix)
├── skills/
│   └── using-dev-workflows/
│       └── SKILL.md             # The single entry point skill
├── templates/
│   ├── CLAUDE.md.base           # Base rules stamped into every project
│   ├── dev-workflows.config.json.default  # Default per-project config
│   └── workflows/
│       ├── full-dev-cycle.md    # The 23-step enforced workflow
│       └── (future: bug-fix.md, spike.md, docs-only.md)
├── package.json                 # Name, version, repo metadata
├── README.md                    # Install instructions + overview
├── CHANGELOG.md
└── LICENSE
```

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

1. Check if Superpowers skills exist:
   - Glob for `~/.claude/plugins/cache/*/superpowers/*/skills/brainstorming/SKILL.md`
   - If not found → Superpowers missing
2. Check if Engineering skills exist:
   - Glob for known Engineering plugin paths
   - Also attempt to resolve a known Engineering skill as fallback
   - If not found → Engineering missing
3. If either missing, output install instructions and STOP:

```
⚠️ Dev Workflows requires these plugins:

❌ Superpowers — install with:
   /plugin install obra/superpowers

✅ Engineering — detected

Install the missing plugin(s), then run /using-dev-workflows again.
```

4. If both present → proceed to Phase 2.

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

1. **Check for existing CLAUDE.md** — if found, ask: "Existing CLAUDE.md found. Merge or replace?"
2. **Write CLAUDE.md** from `templates/CLAUDE.md.base` — fill in `{{PROJECT_NAME}}`, `{{TECH_STACK}}`, `{{GIT_REPO}}`
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
7. **Commit all scaffolded files**
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

All hooks locate `.dev-workflows.json` by walking up from the current working directory (or from the edited file's path for `dev-cycle-check.sh`). If not found, hooks use hardcoded defaults matching the template above.

**Config resolution order:**
1. `.dev-workflows.json` in project root (detected by walking up)
2. Hardcoded defaults in hook scripts (fallback)

## 10. Hook Behavior

### 10.1 `session-start`

**Trigger**: SessionStart (startup|clear|compact)

**Logic**:
1. Check if Superpowers' own SessionStart hook already injected `/using-superpowers` content (look for a known marker string in the environment/context)
2. If already present → no-op, exit cleanly
3. If not present → inject `/using-superpowers` skill content via JSON output:
   ```json
   {
     "hookSpecificOutput": {
       "additionalContext": "<content of using-superpowers SKILL.md>"
     }
   }
   ```

### 10.2 `record-skill.sh`

**Trigger**: PostToolUse, matcher `Skill`

**Logic**:
1. Read JSON from stdin: `{"tool_input":{"skill":"brainstorming"}}`
2. Extract skill name via `jq`
3. Strip namespace prefixes (`superpowers:`, `engineering:`, `dev-workflows:`)
4. Locate `.dev-workflows.json`, read `state.state_file` (default: `/tmp/.dev-workflows-state`)
5. Check `skills.all_tracked` — only record if skill is in the tracked list
6. Append to state file (no duplicates, `grep -qx` check)
7. Output: `{"hookSpecificOutput": {"message": "✅ Skill recorded: brainstorming"}}`

### 10.3 `dev-cycle-check.sh`

**Trigger**: PostToolUse, matcher `Edit|Write`

**Logic**:
1. Read tool input from stdin, extract file path
2. Check if file matches `project.src_pattern` from config (default `/src/`)
3. Exclude if file matches `project.src_exclude_pattern` (tests)
4. If trivial file exists → skip all checks
5. Read state file, count required planning skills present
6. **Stage A** (0 of N planning skills): HARD STOP output, list missing skills
7. **Stage B** (all planning done, no code-review yet): Progress checklist
8. **Stage C** (has code-review, no verification): Finalization reminder
9. **Stage D** (all done): Ready for deployment

### 10.4 `deploy-gate-snippet.sh`

**Not a hook** — a copy-paste snippet for project deploy scripts.

**Logic**:
1. If trivial file exists → skip all checks
2. If `--skip-workflow-check` flag → warn but allow
3. Read state file, check all `skills.required_deploy` are present
4. If any missing → ERROR, block deploy
5. If all present → allow, clean up state files

## 11. Dependency Detection

### 11.1 During `/using-dev-workflows` (thorough)

| Plugin | Detection Method | Install Command |
|--------|-----------------|-----------------|
| Superpowers | Glob `~/.claude/plugins/cache/*/superpowers/*/skills/brainstorming/SKILL.md` | `/plugin install obra/superpowers` |
| Engineering | Glob known paths + attempt to resolve `engineering:documentation` | `/plugin install anthropics/knowledge-work-plugins/tree/main/engineering` |

If either missing → output table showing status of each, install commands, and STOP.

### 11.2 During SessionStart (lightweight)

Only checks if `/using-superpowers` was already injected. Does NOT check for Engineering plugin (that's a setup-time concern, not a per-session concern).

## 12. Existing Repo Transition

- **Archive** `alo-exp/dev-workflow` (singular) as v1 — mark as archived on GitHub
- **Create** `alo-exp/dev-workflows` (plural) as the new plugin repo
- No migration path needed — the old repo was a manual setup guide; the new repo replaces it entirely

## 13. Future Extensibility

### 13.1 Adding New Workflows

1. Create `templates/workflows/<name>.md` in the plugin
2. Update `dev-workflows.config.json.default` to include the new workflow in available options
3. Users pull update; new workflow appears in their `docs/workflows/` on next setup or manual copy
4. Claude selects the right workflow based on task context or user instruction

### 13.2 Adding New Plugins as Dependencies

As more leading plugins emerge:
1. Add to `marketplace.json` dependencies
2. Update `/using-dev-workflows` Phase 1 to check for the new plugin
3. Update workflows to reference new plugin's skills

### 13.3 Per-Team Customization

Teams customize via `.dev-workflows.json`:
- Change `src_pattern` for non-standard project layouts
- Modify `required_planning` / `required_deploy` skill lists
- Set `active_workflow` to a different workflow file
- Add custom tracked skills
