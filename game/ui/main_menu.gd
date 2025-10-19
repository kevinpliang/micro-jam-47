extends Control

func _ready() -> void:
	Main.current_state = Main.GameState.MENU
	$MarginContainer/VBoxContainer/Play.grab_focus()

func _on_play_pressed() -> void:
	Main.current_state = Main.GameState.PLAYING
	if !Main.tutorial_played:
		Main.load_scene("res://environment/Cutscene.tscn")
	else:
		Main.load_scene("res://environment/Level.tscn")

func _on_options_pressed() -> void:
	Main.load_scene("res://game/ui/OptionsMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
