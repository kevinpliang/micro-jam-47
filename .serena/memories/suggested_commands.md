# Suggested Commands

Basic repo inspection:
- `git status --short --branch`
- `git diff -- <path>`
- `rg "pattern"`
- `rg --files`

Godot editor on Windows from WSL:
- `powershell.exe -NoProfile -Command 'Start-Process -FilePath "C:\\Users\\seanl\\Documents\\Godot\\Godot_v4.6.2-stable_win64.exe" -ArgumentList "--editor", "--path", "C:\\Users\\seanl\\Documents\\Godot\\micro-jam-47"'`

Godot AI MCP checks:
- Keep Godot editor open; plugin starts server on `127.0.0.1:8000` and WebSocket on `127.0.0.1:9500`.
- Browser opening `/mcp` may show `Not Acceptable`; that is normal because MCP clients need `text/event-stream`.

No project-local formatter/test runner is currently defined. Prefer Godot editor/MCP smoke checks for scene work and focused manual or command-line Godot checks when available.