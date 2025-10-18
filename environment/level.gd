extends Node2D

const PlayerElephant = preload("res://characters/PlayerElephant.tscn")
const BabyElephant = preload("res://characters/BabyElephant.tscn")
const Lion = preload("res://characters/Lion.tscn")
const FollowerElephant = preload("res://characters/FollowerElephant.tscn")

@export var lion_spawn_interval: float = 3.0 # Spawn a lion every 3 seconds
@export var follower_spawn_chance: float = 0.03 # 3% chance per new tile area
@export var base_pts_per_sec: float = 10.0 # Base score gain per second

var spawn_timer: float = 0.0
var screen_size: Vector2
var baby_elephant: Node2D
var player_elephant: Node2D
var follower_count_label: Label
var score_label: Label
var stopwatch_label: Label
var game_over_reason_label: Label
var game_over_time_label: Label
var game_over_score_label: Label
var spawned_followers: Dictionary = {} # Track which tiles have spawned followers
var followers: Array = [] # Track all active followers
var activated_followers: int = 0 # Count of followers that have been activated
var follower_chain_tail: Node2D = null # The last follower in the chain
var deployed_followers: Array = [] # Track followers that have been deployed
var last_baby_tile: Vector2i = Vector2i(999999, 999999) # Track baby's tile position
var elapsed_time: float = 0.0
var is_game_over: bool = false
var score: int = 0
var score_multiplier: float = 1.0
var raw_score: float = 0.0
var score_update_timer: float = 0.0

func _ready():
	set_process(true)
	screen_size = get_viewport_rect().size
	follower_count_label = $UI/FollowerCount
	score_label = $UI/Score
	stopwatch_label = $UI/Stopwatch
	game_over_reason_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/ReasonLabel
	game_over_time_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/TimeLabel
	game_over_score_label = $GameOverUI/Panel/CenterContainer/VBoxContainer/ScoreLabel
	is_game_over = false
	elapsed_time = 0.0
	score_multiplier = 1.0
	raw_score = 0.0
	score_update_timer = 0.0
	_set_score(0)
	_update_stopwatch_label()
	_reset_game_over_ui()
	_spawn_elephants()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(event.position)

func _spawn_elephants():
	# Spawn both elephants at origin (infinite map)
	var start_pos = Vector2(0, 0)

	# Spawn player elephant
	player_elephant = PlayerElephant.instantiate()
	player_elephant.position = start_pos
	add_child(player_elephant)

	# Baby elephant will spawn at origin and move randomly
	baby_elephant = BabyElephant.instantiate()
	baby_elephant.position = start_pos
	baby_elephant.game_over.connect(_on_game_over)
	baby_elephant.camera_lost.connect(_on_camera_lost)
	add_child(baby_elephant)

func _process(delta):
	if is_game_over:
		return

	elapsed_time += delta
	_update_stopwatch_label()

	# Lion spawn timer
	spawn_timer += delta
	if spawn_timer >= lion_spawn_interval:
		spawn_timer = 0.0
		_spawn_lion()

	# Check if baby is visible in player's camera
	if baby_elephant and player_elephant:
		_check_baby_in_view()
		_check_follower_spawns()
		_update_follower_count()
		_check_deployed_followers_offscreen()

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

func _spawn_lion():
	var lion = Lion.instantiate()

	# Spawn off-screen around the player
	var camera_pos = player_elephant.position
	var edge = randi() % 4
	var spawn_pos = Vector2.ZERO

	# Account for camera zoom (0.4 means we see 2.5x more)
	var zoom_factor = 2.5 # 1 / 0.4
	var visible_width = screen_size.x * zoom_factor
	var visible_height = screen_size.y * zoom_factor
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
	var baby_pos = baby_elephant.position
	var camera = get_viewport().get_camera_2d()
	var camera_pos = camera.get_target_position()

	# Calculate ACTUAL camera bounds accounting for zoom
	var zoom_factor = camera.zoom
	var visible_width = screen_size.x / zoom_factor.x
	var visible_height = screen_size.y / zoom_factor.y

	var half_width = visible_width / 2
	var half_height = visible_height / 2
	
	var camera_left = camera_pos.x - half_width
	var camera_right = camera_pos.x + half_width
	var camera_top = camera_pos.y - half_height
	var camera_bottom = camera_pos.y + half_height

	var is_offscreen = baby_pos.x < camera_left or baby_pos.x > camera_right or \
					   baby_pos.y < camera_top or baby_pos.y > camera_bottom

	if is_offscreen:
		# Show arrow pointing to baby
		_update_baby_arrow(baby_pos)
		$UI/BabyArrow.show()
	else:
		# Baby is on screen, hide arrow
		$UI/BabyArrow.hide()

func _update_baby_arrow(baby_pos: Vector2):
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
		
	var camera_pos = camera.global_position
	var screen_size = get_viewport_rect().size
	var arrow = $UI/BabyArrow
	
	var direction = (baby_pos - camera_pos).normalized()
	var angle = direction.angle()
	arrow.rotation = angle

	# Calculate intersection with screen edge
	var half_w = screen_size.x / 2.0
	var half_h = screen_size.y / 2.0
	var padding = 90.0

	# Start with large values and clamp to find where line hits screen boundary
	var dx = direction.x
	var dy = direction.y
	var t = INF
	
	if abs(dx) > 0.0001:
		t = min(t, half_w / abs(dx))
	if abs(dy) > 0.0001:
		t = min(t, half_h / abs(dy))
	
	var edge_point = direction * t
	# Bring it slightly inward
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

func _show_game_over(reason: String):
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
	if game_over_reason_label:
		game_over_reason_label.text = reason
	if game_over_time_label:
		game_over_time_label.text = "Time Survived: %s" % _format_time(elapsed_time)
	if game_over_score_label:
		game_over_score_label.text = "Score: %s" % _format_score(final_score)
	_update_score_label()
	$GameOverUI.show()

func _reset_game_over_ui():
	$GameOverUI.hide()
	if game_over_reason_label:
		game_over_reason_label.text = ""
	if game_over_time_label:
		game_over_time_label.text = "Time Survived: %s" % _format_time(0.0)
	if game_over_score_label:
		game_over_score_label.text = "Score: %s" % _format_score(0)
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

func _on_camera_lost():
	_show_game_over("The baby wandered off!")

func _on_game_over():
	_show_game_over("The lions got the baby!")

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
	# Spawn followers ONLY in tiles that are currently OFF-SCREEN
	var tile_size = 200
	var camera_pos = player_elephant.position

	# Calculate visible area
	var zoom_factor = 2.5 # 1 / 0.4
	var visible_width = screen_size.x * zoom_factor
	var visible_height = screen_size.y * zoom_factor

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
					_spawn_follower(tile_key, tile_size)
					spawned_followers[tile_key] = true

func _spawn_follower(tile_pos: Vector2i, tile_size: int):
	var follower = FollowerElephant.instantiate()

	# Spawn at random position within the tile
	var tile_world_x = tile_pos.x * tile_size
	var tile_world_y = tile_pos.y * tile_size
	var spawn_x = tile_world_x + randf_range(20, tile_size - 20)
	var spawn_y = tile_world_y + randf_range(20, tile_size - 20)

	follower.position = Vector2(spawn_x, spawn_y)
	add_child(follower)
	followers.append(follower)

func _update_follower_count():
	# Count how many followers are currently in the group (not deployed)
	var count = 0
	for follower in followers:
		if is_instance_valid(follower) and follower.state == "in_group":
			count += 1

	# Update UI follower count display
	if count != activated_followers:
		activated_followers = count
		if follower_count_label:
			follower_count_label.text = str(count)

func add_follower_to_chain(follower: Node2D):
	# Add follower to the end of the chain
	# Works for both new followers and returning followers
	if follower_chain_tail == null:
		# First follower - follow the player
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

		follower.activate(follower_chain_tail, chain_length)
		follower_chain_tail = follower

	# Immediately update the count display
	_update_follower_count()


func _handle_right_click(screen_pos: Vector2):
	# Convert screen position to world position
	var camera = player_elephant.get_node("Camera2D")
	var world_pos = camera.get_screen_center_position() + (screen_pos - screen_size / 2) / camera.zoom

	# Check if we clicked on a deployed follower
	var clicked_follower = _get_follower_at_position(world_pos)

	if clicked_follower and clicked_follower.state == "deployed":
		# Recall this deployed follower
		_recall_follower(clicked_follower)
	elif _count_in_group_followers() > 0:
		# Deploy the last follower in the chain to this position
		_deploy_last_follower(world_pos)

func _get_follower_at_position(world_pos: Vector2) -> Node2D:
	# Check if we clicked on a deployed follower
	for follower in deployed_followers:
		if is_instance_valid(follower):
			var distance = follower.global_position.distance_to(world_pos)
			if distance < 150: # Click tolerance
				return follower
	return null

func _count_in_group_followers() -> int:
	# Count followers currently in the group
	var count = 0
	for follower in followers:
		if is_instance_valid(follower) and follower.state == "in_group":
			count += 1
	return count

func _deploy_last_follower(world_pos: Vector2):
	# Find the last follower in the chain
	if follower_chain_tail == null or not is_instance_valid(follower_chain_tail):
		return

	var follower_to_deploy = follower_chain_tail

	# The new tail is whoever this follower was following
	var new_tail = follower_to_deploy.target

	# If the new tail is the player, then we're removing the only follower
	if new_tail == player_elephant:
		follower_chain_tail = null
	else:
		follower_chain_tail = new_tail

	# Deploy the follower
	follower_to_deploy.deploy_to_position(world_pos)
	deployed_followers.append(follower_to_deploy)

	# Update count
	_update_follower_count()

func _recall_follower(follower: Node2D):
	# Set follower to return to the player
	follower.recall()
	follower.target = player_elephant

	# Remove from deployed list
	deployed_followers.erase(follower)

func _check_deployed_followers_offscreen():
	# Check if any deployed followers have left the camera view
	if deployed_followers.is_empty():
		return
		
	var camera = get_viewport().get_camera_2d()
	var camera_pos = camera.get_target_position()

	var zoom_factor = camera.zoom
	var visible_width = screen_size.x / zoom_factor.x
	var visible_height = screen_size.y / zoom_factor.y
	
	var half_width = visible_width / 2
	var half_height = visible_height / 2

	var camera_left = camera_pos.x - half_width
	var camera_right = camera_pos.x + half_width
	var camera_top = camera_pos.y - half_height
	var camera_bottom = camera_pos.y + half_height

	var to_remove = []
	for follower in deployed_followers:
		if is_instance_valid(follower):
			var pos = follower.global_position
			if pos.x < camera_left or pos.x > camera_right or pos.y < camera_top or pos.y > camera_bottom:
				# Off screen - remove permanently
				to_remove.append(follower)

	for follower in to_remove:
		deployed_followers.erase(follower)
		followers.erase(follower)
		follower.queue_free()
