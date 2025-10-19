extends CanvasLayer

@onready var resume_button = $MarginContainer/VBoxContainer/Resume
@onready var menu_button = $MarginContainer/VBoxContainer/MainMenu
@onready var quit_button = $MarginContainer/VBoxContainer/Quit

func _ready():
	hide()
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if Main.current_state == Main.GameState.UPGRADE:
			return
		if Main.current_state == Main.GameState.PLAYING:
			show()
			Main.current_state = Main.GameState.PAUSED
			get_tree().paused = true

		elif Main.current_state == Main.GameState.PAUSED:
			hide()
			Main.current_state = Main.GameState.PLAYING
			get_tree().paused = false

func _on_resume_pressed():
	hide()
	Main.current_state = Main.GameState.PLAYING
	get_tree().paused = false

func _on_menu_pressed():
	hide()
	Main.current_state = Main.GameState.MENU
	get_tree().paused = false
	Main.load_scene("res://game/ui/MainMenu.tscn")

func _on_quit_pressed():
	get_tree().quit()
