extends Node2D

const PlayerElephant = preload("res://characters/PlayerElephant.tscn")
const BabyElephant = preload("res://characters/BabyElephant.tscn")
const Lion = preload("res://characters/Lion.tscn")
const FollowerElephant = preload("res://characters/FollowerElephant.tscn")
const UpgradeSystem = preload("res://services/UpgradeSystem.tscn")

@export var lion_spawn_duration: float = 300.0 # Seconds before lions stop spawning (10 minutes by default)
@export var lion_spawn_start_interval: float = 5.0 # Early-game lion spawn interval (1 lion every 5 seconds)
@export var lion_spawn_max_rate: float = 10.0 # Maximum lions spawned per second near the end
@export var lion_spawn_ramp_ratio: float = 0.95 # Fraction of duration before max spawn rate is reached
@export var follower_spawn_chance: float = .001 # 1% chance per new tile area
@export var base_pts_per_sec: float = 10.0 # Base score gain per second
@export var player_elephant_speed: float = 600.0 # Shared speed for player and followers
@export var player_spawn_radius: float = 500.0
@export var baby_start_position: Vector2 = Vector2.ZERO
@export var max_followers: int = 210

var spawn_timer: float = 0.0
var screen_size: Vector2
var baby_elephant: Node2D
var player_elephant: Node2D
var exp_label: Label
var score_label: Label
var stopwatch_label: Label
var game_over_reason_label: Label
var game_over_time_label: Label
var game_over_xp_label: Label
var game_over_score_label: Label
var game_over_hiscore_label: Label
var game_over_result_label: Label
@onready var baby_arrow: AnimatedSprite2D = $UI/BabyArrow
@onready var follower_arrow: AnimatedSprite2D = $UI/FollowerArrow
@onready var water_arrow: AnimatedSprite2D = $UI/WaterArrow
var follower_arrow_container: Node2D
var follower_arrows: Array[AnimatedSprite2D] = []
var spawned_followers: Dictionary = {} # Track which tiles have spawned followers
var followers: Array = [] # Track all active followers
var activated_followers: int = 0 # Count of followers that have been activated
var follower_chain_tail: Node2D = null # The last follower in the chain
var last_baby_tile: Vector2i = Vector2i(999999, 999999) # Track baby's tile position
var elapsed_time: float = 0.0
var lion_spawn_stopped: bool = false
var lion_victory_announced: bool = false
var lions_defeated: int = 0
var player_exp: int
var is_game_over: bool = false
var score: int = 0
var score_multiplier: float = 1.0
var raw_score: float = 0.0
var score_update_timer: float = 0.0
var upgrade_system: Node = null
var total_followers_collected: int = 0
var player_speed_multiplier_upgrade: float = 1.0
var _tree_paused_before_upgrade: bool = false
var _state_before_upgrade: int = Main.GameState.PLAYING
var _upgrade_pause_active: bool = false
var upgrade_player_speed_multipler: float = 1.0
var upgrade_player_size_multiplier: float = 1.0
var upgrade_follower_size_multiplier: float = 1.0
var upgrade_baby_speed_multiplier: float = 1.0

func _ready():
	set_process(true)
	screen_size = get_viewport_rect().size
	exp_label = $UI/EXP
	score_label = $UI/Score
	stopwatch_label = $UI/Stopwatch
	game_over_reason_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/ReasonLabel
	game_over_time_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/GridContainer/TimeLabel
	game_over_xp_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/GridContainer/XPLabel
	game_over_score_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/GridContainer/ScoreLabel
	game_over_hiscore_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/GridContainer/HiScoreLabel
	game_over_result_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/ResultLabel
	is_game_over = false
	elapsed_time = 0.0
	score_multiplier = 1.0
	raw_score = 0.0
	score_update_timer = 0.0
	spawn_timer = 0.0
	lion_spawn_stopped = false
	lion_victory_announced = false
	lions_defeated = 0
	total_followers_collected = 0
	player_speed_multiplier_upgrade = 1.0
	_set_score(0)
	_update_stopwatch_label()
	_reset_game_over_ui()
	_spawn_elephants()
	follower_arrow_container = Node2D.new()
	follower_arrow_container.name = "FollowerArrows"
	$UI.add_child(follower_arrow_container)
	$UI/ColorRect.visible = true
	upgrade_system = UpgradeSystem.instantiate()
	$UI.add_child(upgrade_system)
	upgrade_system.initialize(self, $UI)
	if baby_arrow:
		baby_arrow.hide()
		baby_arrow.play("default")
	if follower_arrow:
		follower_arrow.hide()
	if water_arrow:
		water_arrow.hide()
	$AudioPlayer.stream = AudioStreamOggVorbis.load_from_file("res://resources/music/Deez Nuts.ogg")
	$AudioPlayer.play()

func _spawn_elephants():
	# Spawn elephants at configured start positions
	var baby_start_pos = baby_start_position

	# Baby elephant spawns at configured location and wanders from there
	baby_elephant = BabyElephant.instantiate()
	baby_elephant.position = baby_start_pos
	baby_elephant.game_over.connect(_on_game_over)
	add_child(baby_elephant)

	# Spawn player elephant offset from baby within the configured radius
	player_elephant = PlayerElephant.instantiate()
	player_elephant.speed = player_elephant_speed
	Main.player_elephant = player_elephant
	var player_start_pos = _random_point_within_radius(baby_start_pos, player_spawn_radius, 300.0)
	player_elephant.position = player_start_pos
	add_child(player_elephant)

func _random_point_within_radius(center: Vector2, radius: float, min_distance: float = 0.0) -> Vector2:
	var clamped_radius = max(radius, 0.0)
	var clamped_min = clamp(min_distance, 0.0, clamped_radius)
	if clamped_radius == 0.0:
		return center

	var angle = randf() * TAU
	var distance = randf_range(clamped_min, clamped_radius)
	return center + Vector2(cos(angle), sin(angle)) * distance

func _process(delta):
	if is_game_over:
		return

	elapsed_time += delta
	_update_stopwatch_label()

	if not lion_spawn_stopped and elapsed_time >= lion_spawn_duration:
		lion_spawn_stopped = true

	_update_lion_spawning(delta)

	if lion_spawn_stopped and not lion_victory_announced:
		_check_for_lion_victory()

	# Check if baby is visible in player's camera
	if baby_elephant and player_elephant:
		_check_baby_in_view()
		_check_follower_spawns()
		_update_follower_count()

	if is_game_over:
		return

	var followers_with_player: int = _count_in_group_followers()
	var result: Array[float] = score_tick(raw_score, delta, base_pts_per_sec, followers_with_player)
	var new_raw_score: float = result[0]
	score_multiplier = result[1]

	raw_score = new_raw_score
	score_update_timer += delta
	while score_update_timer >= 1.0:
		score_update_timer -= 1.0
		var display_target: int = int(raw_score)
		if display_target != score:
			_set_score(display_target)

func _update_lion_spawning(delta: float) -> void:
	if is_game_over or lion_spawn_stopped:
		return

	spawn_timer += delta
	var current_interval: float = maxf(_get_current_lion_spawn_interval(), 0.001)

	while spawn_timer >= current_interval and !lion_spawn_stopped:
		spawn_timer -= current_interval
		_spawn_lion()
		current_interval = maxf(_get_current_lion_spawn_interval(), 0.001)

func _get_current_lion_spawn_interval() -> float:
	var start_interval: float = maxf(lion_spawn_start_interval, 0.001)
	var start_rate: float = 1.0 / start_interval
	var max_rate: float = maxf(lion_spawn_max_rate, start_rate)

	var ramp_target_time: float = lion_spawn_duration * lion_spawn_ramp_ratio
	if ramp_target_time <= 0.0:
		return 1.0 / max_rate

	var ramp_progress: float = clampf(elapsed_time / ramp_target_time, 0.0, 1.0)
	var current_rate: float = lerpf(start_rate, max_rate, ramp_progress)

	return 1.0 / maxf(current_rate, 0.001)

func _check_for_lion_victory() -> void:
	if is_game_over or lion_victory_announced:
		return

	if _get_active_lion_count() == 0:
		lion_victory_announced = true
		_show_game_over("The king is safe!", true)

func _get_active_lion_count() -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("lion"):
		if is_instance_valid(node) and node is CharacterBody2D:
			if node.has_method("is_defeated") and node.is_defeated():
				continue
			count += 1
	return count

func _on_lion_defeated() -> void:
	lions_defeated += 1
	_increase_player_exp(1)
	if lion_spawn_stopped and not lion_victory_announced:
		_check_for_lion_victory()

func _exit_tree():
	# Ensure global player reference doesn't point to a freed instance
	if Main.player_elephant == player_elephant:
		Main.player_elephant = null
	elif Main.player_elephant != null and !is_instance_valid(Main.player_elephant):
		Main.player_elephant = null

func _spawn_lion():
	var lion = Lion.instantiate()
	lion.lion_defeated.connect(_on_lion_defeated)

	# Spawn off-screen around the player
	var camera_pos = player_elephant.position
	var edge = randi() % 4
	var spawn_pos = Vector2.ZERO

	# Account for camera zoom dynamically so spawns stay just offscreen
	var camera := player_elephant.get_node_or_null("Camera2D") as Camera2D
	var zoom: Vector2 = Vector2.ONE
	if camera:
		zoom = camera.zoom
	var visible_width = screen_size.x / max(zoom.x, 0.001)
	var visible_height = screen_size.y / max(zoom.y, 0.001)
	var spawn_margin = 100 # Extra distance outside view

	match edge:
		0: # Top
			spawn_pos = Vector2(
				camera_pos.x + randf_range(-visible_width / 2, visible_width / 2),
				camera_pos.y - visible_height / 2 - spawn_margin
			)
		1: # Right
			spawn_pos = Vector2(
				camera_pos.x + visible_width / 2 + spawn_margin,
				camera_pos.y + randf_range(-visible_height / 2, visible_height / 2)
			)
		2: # Bottom
			spawn_pos = Vector2(
				camera_pos.x + randf_range(-visible_width / 2, visible_width / 2),
				camera_pos.y + visible_height / 2 + spawn_margin
			)
		3: # Left
			spawn_pos = Vector2(
				camera_pos.x - visible_width / 2 - spawn_margin,
				camera_pos.y + randf_range(-visible_height / 2, visible_height / 2)
			)

	# No bounds - infinite map!
	lion.position = spawn_pos
	add_child(lion)

func _check_baby_in_view():
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return

	var bounds = _calculate_camera_bounds(camera)
	var baby_pos = baby_elephant.position

	if _is_position_offscreen(baby_pos, bounds):
		_update_directional_arrow(baby_pos, baby_arrow, camera)
		baby_arrow.show()
	else:
		baby_arrow.hide()

	_update_follower_arrows(bounds, camera)

func _calculate_camera_bounds(camera: Camera2D) -> Rect2:
	var camera_pos = camera.get_target_position()
	var zoom_factor = camera.zoom
	var visible_width = screen_size.x / zoom_factor.x
	var visible_height = screen_size.y / zoom_factor.y
	var top_left = Vector2(camera_pos.x - visible_width / 2, camera_pos.y - visible_height / 2)
	return Rect2(top_left, Vector2(visible_width, visible_height))

func _is_position_offscreen(position: Vector2, bounds: Rect2) -> bool:
	return not bounds.has_point(position)

func _update_follower_arrows(bounds: Rect2, camera: Camera2D) -> void:
	if follower_arrow_container == null:
		return

	_cleanup_followers()
	
	var offscreen_data: Array = [] # Array of {pos, dist}
	var player_pos: Vector2 = player_elephant.global_position

	for follower in followers:
		if !is_instance_valid(follower):
			continue
		if follower.state != "inactive":
			continue

		var pos: Vector2 = follower.global_position
		if _is_position_offscreen(pos, bounds):
			var dist: float = player_pos.distance_to(pos)
			offscreen_data.append({"pos": pos, "dist": dist})

	# Sort by distance
	offscreen_data.sort_custom(func(a, b): return a["dist"] < b["dist"])

	# Keep only the three nearest
	if offscreen_data.size() > 3:
		offscreen_data = offscreen_data.slice(0, 3)

	# Ensure arrow capacity
	_ensure_follower_arrow_capacity(offscreen_data.size())

	# Update visible arrows
	for i in range(offscreen_data.size()):
		var arrow = follower_arrows[i]
		_update_directional_arrow(offscreen_data[i]["pos"], arrow, camera)
		arrow.show()

	# Hide any extra arrows
	for i in range(offscreen_data.size(), follower_arrows.size()):
		follower_arrows[i].hide()

	follower_arrow_container.visible = offscreen_data.size() > 0


func _ensure_follower_arrow_capacity(required: int) -> void:
	while follower_arrows.size() < required:
		var arrow := _create_follower_arrow()
		follower_arrows.append(arrow)

func _create_follower_arrow() -> AnimatedSprite2D:
	var arrow: AnimatedSprite2D = follower_arrow.duplicate()
	arrow.name = "FollowerArrow_%d" % follower_arrows.size()
	arrow.visible = false
	follower_arrow_container.add_child(arrow)
	return arrow

func _update_directional_arrow(target_pos: Vector2, arrow: AnimatedSprite2D, camera: Camera2D):
	if arrow == null or camera == null:
		return

	var camera_pos = camera.global_position
	var screen_size = get_viewport_rect().size
	var direction = target_pos - camera_pos
	if direction.length_squared() == 0:
		return

	direction = direction.normalized()
	arrow.rotation = direction.angle()

	var half_w = screen_size.x / 2.0
	var half_h = screen_size.y / 2.0
	var padding = 90.0
	var dx = direction.x
	var dy = direction.y
	var t := INF

	if abs(dx) > 0.0001:
		t = min(t, half_w / abs(dx))
	if abs(dy) > 0.0001:
		t = min(t, half_h / abs(dy))

	var edge_point = direction * t
	var arrow_pos = screen_size / 2 + (edge_point - direction * padding)
	arrow.position = arrow_pos


func _update_stopwatch_label():
	if stopwatch_label:
		stopwatch_label.text = _format_time(elapsed_time)

func _set_score(value: int) -> void:
	score = value
	_update_score_label()

func _update_score_label() -> void:
	if score_label:
		score_label.text = "Score: %s" % _format_score(score)

func _format_time(time_seconds: float) -> String:
	var total_seconds = int(time_seconds)
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _format_score(value: int) -> String:
	return "%d" % value

func score_tick(score: float, delta: float, base_pts_per_sec: float, followers_with_player: int) -> Array[float]:
	var t: float = clamp(float(min(followers_with_player, 10)) / 10.0, 0.0, 1.0)
	var mult: float = 1.0 + 2.0 * pow(t, 1.75)
	var new_score: float = score + base_pts_per_sec * mult * delta
	var result: Array[float] = []
	result.append(new_score)
	result.append(mult)
	return result

func _show_game_over(reason: String, victory: bool = false):
	if is_game_over:
		return
	is_game_over = true
	Main.current_state = Main.GameState.PAUSED
	set_process(false)
	if is_instance_valid(player_elephant):
		player_elephant.set_process(false)
		player_elephant.set_physics_process(false)
	if is_instance_valid(baby_elephant):
		baby_elephant.set_process(false)
		baby_elephant.set_physics_process(false)
	_update_stopwatch_label()
	var final_score: int = int(raw_score)
	if final_score != score:
		_set_score(final_score)
		
	var result_text := "YOU LOSE"
	var result_color := Color(1.0, 0.3, 0.3)
	if victory:
		result_text = "YOU WIN"
		result_color = Color(0.3, 0.9, 0.3)
	game_over_result_label.text = result_text
	game_over_result_label.add_theme_color_override("font_color", result_color)
	game_over_reason_label.add_theme_color_override("font_color", result_color)
	
	game_over_reason_label.text = reason
	game_over_time_label.text = "%s" % _format_time(elapsed_time)
	game_over_xp_label.text = str(player_exp)
	game_over_score_label.text = "%s" % _format_score(final_score)
	
	
	_update_score_label()
	$GameOverUI.show()

func _reset_game_over_ui():
	$GameOverUI.hide()
	if game_over_reason_label:
		game_over_reason_label.text = ""
	if game_over_time_label:
		game_over_time_label.text = "Time Survived: %s" % _format_time(0.0)
	if game_over_score_label:
		game_over_score_label.text = "Score: %s\nLions Defeated: %d" % [_format_score(0), 0]
	if game_over_result_label:
		game_over_result_label.text = ""
		game_over_result_label.remove_theme_color_override("font_color")
	score_multiplier = 1.0
	raw_score = 0.0
	score_update_timer = 0.0
	_set_score(0)

func _on_restart_button_pressed():
	Main.current_state = Main.GameState.PLAYING
	Main.load_scene("res://environment/Level.tscn")

func _on_main_menu_button_pressed():
	Main.current_state = Main.GameState.MENU
	Main.load_scene("res://game/ui/MainMenu.tscn")

func _on_game_over():
	resume_after_upgrade()
	_show_game_over("The lions got the king.")

func _check_follower_spawns():
	# Check if baby has moved to a new tile region
	var tile_size = 200 # Match background tile size
	var baby_pos = baby_elephant.position
	var current_tile = Vector2i(int(baby_pos.x / tile_size), int(baby_pos.y / tile_size))

	# If baby moved to a new tile, potentially spawn followers
	if current_tile != last_baby_tile:
		last_baby_tile = current_tile
		_try_spawn_follower_in_region(current_tile)

func _try_spawn_follower_in_region(center_tile: Vector2i):
	_cleanup_followers()

	# Spawn followers ONLY in tiles that are currently OFF-SCREEN
	var tile_size = 200
	var camera_pos = player_elephant.position

	# Calculate visible area based on the current camera zoom
	var camera := player_elephant.get_node_or_null("Camera2D") as Camera2D
	var zoom: Vector2 = Vector2.ONE
	if camera:
		zoom = camera.zoom
	var visible_width = screen_size.x / max(zoom.x, 0.001)
	var visible_height = screen_size.y / max(zoom.y, 0.001)

	# Calculate which tiles are visible
	var camera_tile_x = int(camera_pos.x / tile_size)
	var camera_tile_y = int(camera_pos.y / tile_size)
	var visible_tile_radius_x = int(visible_width / tile_size / 2) + 1
	var visible_tile_radius_y = int(visible_height / tile_size / 2) + 1

	# Check tiles in a larger radius around baby
	var search_radius = 8 # Check further out

	for dy in range(-search_radius, search_radius + 1):
		for dx in range(-search_radius, search_radius + 1):
			var tile_key = Vector2i(center_tile.x + dx, center_tile.y + dy)

			# Skip if already spawned a follower here
			if spawned_followers.has(tile_key):
				continue

			# Check if this tile is OFF-SCREEN (not visible by camera)
			var tile_dist_x = abs(tile_key.x - camera_tile_x)
			var tile_dist_y = abs(tile_key.y - camera_tile_y)

			# Only spawn if tile is outside visible area
			if tile_dist_x > visible_tile_radius_x or tile_dist_y > visible_tile_radius_y:
				# Random chance to spawn
				if randf() < follower_spawn_chance:
					if _spawn_follower(tile_key, tile_size):
						spawned_followers[tile_key] = true

func _spawn_follower(tile_pos: Vector2i, tile_size: int) -> bool:
	_cleanup_followers()

	var follower = FollowerElephant.instantiate()
	if is_instance_valid(player_elephant):
		follower.follow_speed = player_elephant.speed
	else:
		follower.follow_speed = player_elephant_speed

	# Spawn at random position within the tile
	var tile_world_x = tile_pos.x * tile_size
	var tile_world_y = tile_pos.y * tile_size
	var spawn_x = tile_world_x + randf_range(20, tile_size - 20)
	var spawn_y = tile_world_y + randf_range(20, tile_size - 20)
	follower.scale *= upgrade_follower_size_multiplier
	follower.position = Vector2(spawn_x, spawn_y)
	add_child(follower)
	followers.append(follower)
	return true

func _cleanup_followers():
	for i in range(followers.size() - 1, -1, -1):
		var follower = followers[i]
		if !is_instance_valid(follower):
			followers.remove_at(i)

	if follower_chain_tail != null and !is_instance_valid(follower_chain_tail):
		follower_chain_tail = null

func _update_follower_count():
	_cleanup_followers()

func pause_for_upgrade() -> void:
	if _upgrade_pause_active:
		return
	_upgrade_pause_active = true
	_tree_paused_before_upgrade = get_tree().paused
	_state_before_upgrade = Main.current_state
	get_tree().paused = true
	Main.current_state = Main.GameState.UPGRADE

func resume_after_upgrade() -> void:
	if not _upgrade_pause_active:
		return
	get_tree().paused = _tree_paused_before_upgrade
	if _state_before_upgrade == Main.GameState.UPGRADE:
		Main.current_state = Main.GameState.PLAYING
	else:
		Main.current_state = _state_before_upgrade
	_upgrade_pause_active = false

func apply_selected_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"speed":
			_apply_speed_upgrade()
		"size":
			_apply_size_upgrade()
		"follower_size":
			_apply_follower_size_upgrade()
		"baby_speed":
			_apply_baby_speed_upgrade()
		_:
			print("Upgrade type not found")

func _apply_speed_upgrade() -> void:
	print('before', player_elephant.speed)
	upgrade_player_speed_multipler += .2
	var new_speed = player_elephant_speed * upgrade_player_speed_multipler
	player_elephant.speed = new_speed
	player_elephant.scale_run_speed()
	for follower in followers:
		follower.follow_speed *= new_speed
	print('after', player_elephant.speed)
		
func _apply_follower_size_upgrade():
	upgrade_follower_size_multiplier += .2
	for follower in followers:
		print('before', follower.scale)
		follower.scale += Vector2(.2, .2)
		print('after', follower.scale)
			
func _apply_size_upgrade():
	print('before', player_elephant.scale)
	player_elephant.scale += Vector2(.2, .2)
	print('after', player_elephant.scale)

func _apply_baby_speed_upgrade() -> void:
	print('baby speed before', baby_elephant.speed)
	if upgrade_baby_speed_multiplier > 0:
		upgrade_baby_speed_multiplier -= .20
		var new_speed = baby_elephant.base_speed * upgrade_baby_speed_multiplier
		baby_elephant.speed = new_speed
	else:
		pass
	print('after', baby_elephant.speed)

func add_follower_to_chain(follower: Node2D):
	var is_new_follower: bool = false
	if follower and follower.has_method("activate"):
		is_new_follower = follower.state == "inactive"

	var current_group_count = _count_in_group_followers()
	if current_group_count >= max_followers and follower.state != "in_group":
		return
	# Add follower to the end of the chain
	# Works for both new followers and existing followers
	if follower_chain_tail == null:
		# First follower - follow the player
		if is_instance_valid(player_elephant):
			follower.follow_speed = player_elephant.speed
		else:
			follower.follow_speed = player_elephant_speed
		follower.activate(player_elephant, 0)
		follower_chain_tail = follower
	else:
		# Add to end of chain - follow the current tail
		var chain_length = 1
		var current = follower_chain_tail

		# Count chain length by traversing back to player
		while current != null and current.target != player_elephant:
			chain_length += 1
			current = current.target

		if is_instance_valid(player_elephant):
			follower.follow_speed = player_elephant.speed
		else:
			follower.follow_speed = player_elephant_speed
		follower.activate(follower_chain_tail, chain_length)
		follower_chain_tail = follower


func _count_in_group_followers() -> int:
	_cleanup_followers()
	# Count followers currently in the group
	var count = 0
	for follower in followers:
		if is_instance_valid(follower) and follower.state == "in_group":
			count += 1
	return count

func _increase_player_exp(amount: int) -> void:
	if is_game_over:
		return
	player_exp += amount
	exp_label.text = "XP: " + str(player_exp)
	upgrade_system.on_exp_gained(player_exp)

func _on_audio_player_finished() -> void:
	$AudioPlayer.play()
