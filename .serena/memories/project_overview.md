# Project Overview

Micro Jam 47 is a Godot 4.6 game project. The main scene is `res://game/Main.tscn` and the project name in `project.godot` is `Micro Jam 47`.

Primary folders:
- `game/`: main entry script and UI menus.
- `characters/`: player elephant, baby elephant, follower elephant, lion, movement arrow scenes/scripts.
- `environment/`: level, background, cutscene scenes/scripts.
- `services/`: herd service and upgrade system.
- `audio/`, `resources/`, `characters/assets/`, `environment/assets/`: imported media and art assets.
- `addons/godot_ai/`: Godot AI MCP editor plugin; treat as third-party/vendor code unless specifically updating the plugin.

Godot AI MCP is installed and enabled. When Godot editor is open, use MCP endpoint `http://127.0.0.1:8000/mcp` for scene/editor operations where available.