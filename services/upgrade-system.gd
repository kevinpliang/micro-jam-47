extends Node

signal upgrade_selected(upgrade_id: String)

const UPGRADE_OPTIONS := [
	{
		"id": "speed",
		"title": "Fleet Feet",
		"description": "+20% movement speed"
	},
	{
		"id": "hitbox",
		"title": "Bigger Bond",
		"description": "+30% player hitbox size"
	}
]

const GAME_THEME := preload("res://resources/Theme.tres")

var level_ref: Node = null
var ui_layer: CanvasLayer = null
var overlay: Control = null
var info_label: Label = null
var option_buttons: Dictionary = {}
var is_showing: bool = false
var current_rank: int = 1
var next_threshold: int = 1
var total_collected: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func initialize(level: Node, ui_parent: CanvasLayer) -> void:
	level_ref = level
	ui_layer = ui_parent
	_create_ui()
	_update_threshold()
	_update_progress_label()

func on_unique_follower_collected(total: int) -> void:
	total_collected = total
	_update_progress_label()
	if is_showing:
		return
	if total_collected >= next_threshold:
		_present_upgrade_menu()

func _create_ui() -> void:
	if overlay:
		return

	overlay = Control.new()
	overlay.name = "UpgradeOverlay"
	overlay.visible = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0

	if ui_layer:
		ui_layer.add_child(overlay)
	else:
		add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_left = 0.0
	dim.anchor_top = 0.0
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.offset_left = 0.0
	dim.offset_top = 0.0
	dim.offset_right = 0.0
	dim.offset_bottom = 0.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.anchor_left = 0.0
	center.anchor_top = 0.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(640, 0)
	panel.theme = GAME_THEME
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "Choose an upgrade"
	title.theme = GAME_THEME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	info_label = Label.new()
	info_label.name = "Info"
	info_label.theme = GAME_THEME
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info_label)

	var options_box := VBoxContainer.new()
	options_box.name = "Options"
	options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_box.add_theme_constant_override("separation", 12)
	vbox.add_child(options_box)

	for option in UPGRADE_OPTIONS:
		var button := Button.new()
		button.name = String(option["id"]).capitalize()
		button.theme = GAME_THEME
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = Vector2(0, 96)
		button.focus_mode = Control.FOCUS_ALL
		button.text = ""

		var content := VBoxContainer.new()
		content.name = "Content"
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 4)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)

		var title_label := Label.new()
		title_label.name = "TitleLabel"
		title_label.text = option["title"]
		title_label.theme = GAME_THEME
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(title_label)

		var description_label := Label.new()
		description_label.name = "DescriptionLabel"
		description_label.text = option["description"]
		description_label.theme = GAME_THEME
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(description_label)

		button.pressed.connect(Callable(self, "_on_option_pressed").bind(option["id"]))
		options_box.add_child(button)
		option_buttons[option["id"]] = button

	_set_buttons_disabled(true)

func _present_upgrade_menu() -> void:
	if not overlay:
		return

	is_showing = true
	_set_buttons_disabled(false)
	overlay.visible = true
	call_deferred("_focus_first_button")
	if level_ref and level_ref.has_method("pause_for_upgrade"):
		level_ref.pause_for_upgrade()
	_update_progress_label()

func _focus_first_button() -> void:
	if option_buttons.is_empty():
		return
	for option in UPGRADE_OPTIONS:
		if option_buttons.has(option.id):
			var button: Button = option_buttons[option.id]
			if is_instance_valid(button):
				button.grab_focus()
				return

func _on_option_pressed(upgrade_id: String) -> void:
	if not is_showing:
		return

	_set_buttons_disabled(true)
	if level_ref and level_ref.has_method("apply_selected_upgrade"):
		level_ref.apply_selected_upgrade(upgrade_id)

	emit_signal("upgrade_selected", upgrade_id)
	_advance_threshold()
	_hide_overlay()

func _hide_overlay() -> void:
	if not overlay:
		return

	overlay.visible = false
	is_showing = false
	_set_buttons_disabled(true)
	_update_progress_label()
	if level_ref and level_ref.has_method("resume_after_upgrade"):
		level_ref.resume_after_upgrade()

func _set_buttons_disabled(disabled: bool) -> void:
	for button in option_buttons.values():
		if is_instance_valid(button):
			button.disabled = disabled

func _advance_threshold() -> void:
	current_rank += 1
	_update_threshold()

func _update_threshold() -> void:
	next_threshold = _triangular_number(current_rank)

func _update_progress_label() -> void:
	if info_label:
		info_label.text = "Followers rescued: %d / %d" % [total_collected, next_threshold]

func _triangular_number(n: int) -> int:
	return int((n * (n + 1)) / 2)
