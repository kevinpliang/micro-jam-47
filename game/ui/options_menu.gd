extends Control

@onready var volume_slider = $MarginContainer/VBoxContainer/GridContainer/VolumeSlider
@onready var fullscreen_check = $MarginContainer/VBoxContainer/GridContainer/FullscreenCheckBox
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

const SETTINGS_PATH := "user://settings.cfg"

func _ready():
	# Connect signals
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)
	
	# Load saved settings
	_load_settings()

func _on_volume_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings()

func _on_fullscreen_toggled(toggled_on):
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if toggled_on else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _on_back_pressed() -> void:
	Main.load_scene("res://game/ui/MainMenu.tscn")
	
func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "volume", volume_slider.value)
	cfg.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	cfg.save(SETTINGS_PATH)

func _load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var vol = cfg.get_value("audio", "volume", 1.0)
		var fs = cfg.get_value("display", "fullscreen", false)

		volume_slider.value = vol
		fullscreen_check.button_pressed = fs

		_on_volume_changed(vol)
		_on_fullscreen_toggled(fs)
	else:
		volume_slider.value = 1.0
		fullscreen_check.button_pressed = false
