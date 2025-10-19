extends Node

var current_scene = null
var player_elephant = null
var tutorial_played = true # Change for debug

enum GameState {
	MENU, PLAYING, PAUSED, UPGRADE
}
var current_state: GameState = GameState.MENU

func _ready() -> void:
	var root = get_tree().root
	current_scene = root.get_child(-1)
	load_scene("res://game/ui/MainMenu.tscn")

# --- Scene management ---
# See https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
func load_scene(path):
	_deferred_load_scene.call_deferred(path)

func _deferred_load_scene(path):
	current_scene.free()
	var scene = ResourceLoader.load(path)
	current_scene = scene.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
