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
- Do not revert user changes. If unrelated files are dirty, leave them alone.
- Prefer `rg` / `rg --files` for search.
- Use `apply_patch` for manual file edits.
- Use Godot AI MCP for scene/editor operations instead of hand-editing `.tscn` files when possible.
- If Godot AI MCP tools are unavailable, ensure Godot editor is open and the server is listening on `127.0.0.1:8000`.
- Run focused verification before final response. For Godot work, prefer editor/MCP checks or Godot command-line smoke checks when available.

## Git

- Stage only files relevant to the current request.
- Commit messages should be concise, imperative, and technical.
- Push the current branch only after commit succeeds and the user requested push.
