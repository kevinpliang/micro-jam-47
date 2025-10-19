extends Node

signal upgrade_selected(upgrade_id: String)

# --- Define your full upgrade pool ---
const ALL_UPGRADES := [
	{"id": "speed", "title": "Fleet Feet", "description": "+20% movement speed"},
	{"id": "size", "title": "Huge Heart", "description": "+20% player size"},
	{"id": "follower_size", "title": "Enlarged Elephants", "description": "+20% follower size"},
	{"id": "baby_speed", "title": "Lord's Lullaby", "description": "-20% baby movement speed"},
]

const GAME_THEME := preload("res://resources/Theme.tres")

var level_ref: Node = null
var ui_layer: CanvasLayer = null
var overlay: Control = null
var options_box: VBoxContainer = null
var option_buttons: Dictionary = {}
var is_showing: bool = false
var current_rank: int = 1
var next_threshold: int = 1
var total_collected: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui()
	_update_threshold()

func initialize(level: Node, ui_parent: CanvasLayer) -> void:
	level_ref = level
	ui_layer = ui_parent

func on_exp_gained(total: int) -> void:
	total_collected = total
	if is_showing:
		return
	if total_collected >= next_threshold:
		$AudioStreamPlayer.play()
		_present_upgrade_menu()

# --- UI CREATION ---
func _create_ui() -> void:
	if overlay:
		return

	overlay = Control.new()
	overlay.name = "UpgradeOverlay"
	overlay.visible = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1

	if ui_layer:
		ui_layer.add_child(overlay)
	else:
		add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1
	dim.anchor_bottom = 1
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1
	center.anchor_bottom = 1
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(640, 0)
	panel.theme = GAME_THEME
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "Choose an upgrade"
	title.theme = GAME_THEME
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.122, 0.675, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	options_box = VBoxContainer.new()
	options_box.name = "Options"
	options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options_box.add_theme_constant_override("separation", 12)
	vbox.add_child(options_box)

	_set_buttons_disabled(true)

# --- BUILD RANDOM OPTIONS ---
func _populate_random_upgrades() -> void:
	# Clear previous buttons
	for child in options_box.get_children():
		child.queue_free()
	option_buttons.clear()

	# Choose 3 random upgrades
	var pool = ALL_UPGRADES.duplicate()
	pool.shuffle()
	var chosen = pool.slice(0, 3)

	for option in chosen:
		var button := Button.new()
		button.name = String(option["id"]).capitalize()
		button.theme = GAME_THEME
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = Vector2(0, 96)
		button.focus_mode = Control.FOCUS_ALL
		button.text = ""
		button.expand_icon = true
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 6)
		button.add_child(content)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(margin)

		var label_box := VBoxContainer.new()
		label_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label_box.add_theme_constant_override("separation", 4)
		margin.add_child(label_box)

		var title_label := Label.new()
		title_label.text = option["title"]
		title_label.theme = GAME_THEME
		title_label.add_theme_font_size_override("font_size", 24)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_box.add_child(title_label)

		var desc_label := Label.new()
		desc_label.text = option["description"]
		desc_label.theme = GAME_THEME
		desc_label.add_theme_font_size_override("font_size", 24)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_box.add_child(desc_label)

		button.pressed.connect(Callable(self, "_on_option_pressed").bind(option["id"]))
		options_box.add_child(button)
		option_buttons[option["id"]] = button
		
var click_block_time := 0.2

# --- PRESENT MENU ---
func _present_upgrade_menu() -> void:
	_populate_random_upgrades()
	is_showing = true
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_buttons_disabled(true)
	await get_tree().create_timer(click_block_time).timeout
	_set_buttons_disabled(false)
	if level_ref and level_ref.has_method("pause_for_upgrade"):
		level_ref.pause_for_upgrade()

# --- BUTTON ACTIONS ---
func _on_option_pressed(upgrade_id: String) -> void:
	if not is_showing:
		return

	_set_buttons_disabled(true)
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
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if level_ref and level_ref.has_method("resume_after_upgrade"):
		level_ref.resume_after_upgrade()

func _set_buttons_disabled(disabled: bool) -> void:
	for button in option_buttons.values():
		if is_instance_valid(button):
			button.disabled = disabled

# --- PROGRESSION ---
func _advance_threshold() -> void:
	current_rank += 1
	_update_threshold()

func _update_threshold() -> void:
	next_threshold = _triangular_number(current_rank)

func _triangular_number(n: int) -> int:
	return int((n * (n + 1)) / 2)
