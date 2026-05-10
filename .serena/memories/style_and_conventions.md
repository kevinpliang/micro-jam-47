# Style and Conventions

- GDScript scripts use Godot 4 syntax with `extends`, typed exports (`@export var speed: float = 600.0`), typed signals, and `_ready`, `_process`, `_physics_process` callbacks.
- Keep gameplay tuning values exported when designers may adjust them in the editor.
- Prefer scene/editor changes through Godot AI MCP when possible instead of hand-editing `.tscn` files.
- Avoid editing generated/import sidecars (`*.uid`, `*.import`) unless Godot import state requires it.
- Treat `addons/godot_ai/` as vendor/plugin code; do not modify it for game behavior.
- Use focused comments only for non-obvious logic. Avoid broad unrelated refactors during narrow gameplay fixes.