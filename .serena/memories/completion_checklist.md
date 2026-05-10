# Completion Checklist

Before finishing a task:
- Check `git status --short --branch` and confirm only intended files were changed/staged.
- For GDScript changes, inspect diffs and run focused Godot/editor verification when practical.
- For scene/editor changes, prefer Godot AI MCP inspection or Godot editor smoke test.
- Do not claim tests pass unless a verification command or MCP check was actually run.
- Leave unrelated dirty files untouched.
- If committing, stage only relevant files and use a concise imperative commit message.