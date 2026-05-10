# Agent Instructions

## Communication

- Follow higher-priority system/developer instructions first.
- Use `caveman` style for user-facing progress and final replies unless the user says `stop caveman` or `normal mode`.
- Keep commands, code, commit messages, and review findings precise and normal.

## Project Context

- Project: Godot 4.6 game, `Micro Jam 47`.
- Main scene: `res://game/Main.tscn`.
- Core gameplay scripts live in `game/`, `characters/`, `environment/`, and `services/`.
- Godot AI plugin is installed at `addons/godot_ai` and enabled in `project.godot`.
- Avoid editing `.godot/` cache files or generated `*.uid` / `*.import` files unless a Godot import/plugin workflow requires it.

## Available Tools and Skills

- **Godot AI MCP**: Use for live editor work when Godot is open. Endpoint is `http://127.0.0.1:8000/mcp`. It can inspect scenes, list nodes, create/delete nodes, set properties, attach scripts, connect signals, update project settings, run the project/tests, inspect logs, and capture editor/game screenshots.
- **Serena MCP**: Use for project memory and semantic/code navigation when useful. Serena has limited GDScript language support in this project, so prefer it for memories and targeted searches; use `rg` and direct file reads for GDScript implementation details.
- **Superpowers skills**: Use when relevant:
  - `superpowers:brainstorming` before creative feature/design work.
  - `superpowers:systematic-debugging` before fixing bugs or unexpected behavior.
  - `superpowers:test-driven-development` for feature or bugfix implementation where tests are practical.
  - `superpowers:verification-before-completion` before claiming work is complete.
  - `superpowers:requesting-code-review` for substantial completed changes.
- **Browser Use / Playwright**: Use for local browser verification when a task involves a browser target. This Godot project usually needs Godot/editor verification instead.
- **Web search / docs**: Browse for current docs, engine/API facts, third-party tools, or anything likely to have changed.

## Workflow

- Check `git status --short --branch` before edits.
- Run `bd prime` for current beads workflow context. Default to creating or claiming a bead before changing code, docs, configuration, tests, schema, workflows, or deployment setup unless the user explicitly asks not to track the task.
- Do not revert user changes. If unrelated files are dirty, leave them alone.
- Prefer `rg` / `rg --files` for search.
- Use `apply_patch` for manual file edits.
- Use Godot AI MCP for scene/editor operations instead of hand-editing `.tscn` files when possible.
- If Godot AI MCP tools are unavailable, ensure Godot editor is open and the server is listening on `127.0.0.1:8000`.
- Run focused verification before final response. For Godot work, prefer editor/MCP checks or Godot command-line smoke checks when available.

## Brooks-Lint Development Guardrails

Use these rules to prevent large-file refactors and maintain game-development conceptual integrity. They target Brooks-Lint decay risks: cognitive overload, change propagation, knowledge duplication, accidental complexity, dependency disorder, and domain model distortion.

The 800-line number is not a Brooks-Lint or book rule. It is a local repo guardrail derived from Brooks-Lint's cognitive-overload risk. Brooks-Lint's concrete signals are smaller: mixed-abstraction functions over 20 lines, parameter lists over 4 parameters, boolean expressions with 3 or more combined conditions, nesting deeper than 3, fan-out over 5 imports/preloads, and changes that ripple across more than 3 unrelated files.

Before adding behavior:

- Name the Brooks-Lint risk most likely to grow if the behavior is added inline.
- Choose the smallest existing scene, script, service, resource, or helper that owns the behavior, or create a focused module before adding feature logic.
- Keep Godot nodes/scenes responsible for state ownership, lifecycle callbacks, signals, editor wiring, and presentation. Move validation, state transitions, serialization, save payload building, spawn placement, timer math, movement math, steering math, upgrade selection, and runtime orchestration into focused helpers or services.
- If a change would add more than 50 lines to a file already over 500 lines, create or extend a helper module in the same branch.
- If a file is over 800 lines, add no new feature/business logic there unless the change is only wiring existing helpers. Extract first.
- If a function grows past 20 lines while mixing UI, state transitions, persistence, and runtime work, split it before continuing.
- If a helper needs more than 4 parameters, prefer a typed input object or small data Dictionary with domain names.
- If one change touches more than 3 unrelated modules, stop and write/update the implementation plan so the boundaries are explicit.
- Avoid speculative abstractions. Extract around current repeated decisions or current complexity, not imagined future systems.
- Treat large test files like large production files: if a test file is over 800 lines, add new scenarios to a focused sibling test file or colocated helper test unless the scenario is truly broad integration coverage.
- Before completion, state whether any large file grew, why, and what remains to extract.

## Issue Tracking

This project uses `bd` (beads) for issue tracking. Run `bd prime` for current workflow context, or install hooks with `bd hooks install` when hook-based workflow injection is wanted.

Bead creation expectations:

- Default to creating or claiming a bead before changing code, docs, configuration, tests, schema, workflows, or deployment setup unless the user explicitly asks not to track the task.
- Create beads for bug fixes, feature work, refactors, investigation tasks, verification tasks, and docs/process changes that future agents should remember.
- If a request is more than a tiny one-shot answer or command, make a bead. When unsure, create the bead; extra tracked context is better than lost chat context.
- For large or multi-part work, create a parent epic or feature bead plus child task/bug beads with dependencies instead of one oversized issue.
- When substantial follow-up work is discovered but not handled immediately, create a new bead. If it belongs to the current work, add a note or dependency instead of leaving it only in the chat.
- Do not create duplicate beads. Search existing open, in-progress, and recently closed issues first when the task sounds similar.
- At completion, close completed beads with a reason and leave any remaining follow-up as open beads.

Quick reference:

- `bd ready` - Find unblocked work.
- `bd create "Title" --type task --priority 2` - Create an issue.
- `bd show <id>` - Show issue details.
- `bd update <id> --claim` - Claim work.
- `bd close <id>` - Complete work.
- `bd dolt push` - Push beads to the configured remote.

## Git

- Stage only files relevant to the current request.
- Commit messages should be concise, imperative, and technical.
- Push the current branch only after commit succeeds and the user requested push.
