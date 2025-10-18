extends Node2D

const PlayerElephant = preload("res://characters/PlayerElephant.tscn")
const BabyElephant = preload("res://characters/BabyElephant.tscn")
const Lion = preload("res://characters/Lion.tscn")
const FollowerElephant = preload("res://characters/FollowerElephant.tscn")

@export var lion_spawn_interval: float = 3.0  # Spawn a lion every 3 seconds
@export var follower_spawn_chance: float = 0.03  # 3% chance per new tile area

var spawn_timer: float = 0.0
var screen_size: Vector2
var baby_elephant: Node2D
var player_elephant: Node2D
var follower_count_label: Label
var spawned_followers: Dictionary = {}  # Track which tiles have spawned followers
var followers: Array = []  # Track all active followers
var activated_followers: int = 0  # Count of followers that have been activated
var follower_chain_tail: Node2D = null  # The last follower in the chain
var deployed_followers: Array = []  # Track followers that have been deployed
var last_baby_tile: Vector2i = Vector2i(999999, 999999)  # Track baby's tile position

func _ready():
	screen_size = get_viewport_rect().size
	follower_count_label = $UI/FollowerCount
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

func _spawn_lion():
	var lion = Lion.instantiate()

	# Spawn off-screen around the player
	var camera_pos = player_elephant.position
	var edge = randi() % 4
	var spawn_pos = Vector2.ZERO

	# Account for camera zoom (0.4 means we see 2.5x more)
	var zoom_factor = 2.5  # 1 / 0.4
	var visible_width = screen_size.x * zoom_factor
	var visible_height = screen_size.y * zoom_factor
	var spawn_margin = 100  # Extra distance outside view

	match edge:
		0:  # Top
			spawn_pos = Vector2(
				camera_pos.x + randf_range(-visible_width/2, visible_width/2),
				camera_pos.y - visible_height/2 - spawn_margin
			)
		1:  # Right
			spawn_pos = Vector2(
				camera_pos.x + visible_width/2 + spawn_margin,
				camera_pos.y + randf_range(-visible_height/2, visible_height/2)
			)
		2:  # Bottom
			spawn_pos = Vector2(
				camera_pos.x + randf_range(-visible_width/2, visible_width/2),
				camera_pos.y + visible_height/2 + spawn_margin
			)
		3:  # Left
			spawn_pos = Vector2(
				camera_pos.x - visible_width/2 - spawn_margin,
				camera_pos.y + randf_range(-visible_height/2, visible_height/2)
			)

	# No bounds - infinite map!
	lion.position = spawn_pos
	add_child(lion)

func _check_baby_in_view():
	var camera_pos = player_elephant.position
	var baby_pos = baby_elephant.position

	# Calculate ACTUAL camera bounds accounting for zoom
	var zoom_factor = 2.5  # 1 / 0.4
	var visible_width = screen_size.x * zoom_factor
	var visible_height = screen_size.y * zoom_factor

	var half_width = visible_width / 2
	var half_height = visible_height / 2

	var camera_left = camera_pos.x - half_width
	var camera_right = camera_pos.x + half_width
	var camera_top = camera_pos.y - half_height
	var camera_bottom = camera_pos.y + half_height

	# Check if BABY is outside camera view (wandered too far)
	if baby_pos.x < camera_left or baby_pos.x > camera_right or \
	   baby_pos.y < camera_top or baby_pos.y > camera_bottom:
		_on_camera_lost()

func _on_camera_lost():
	# Baby wandered out of view
	set_process(false)
	$GameOverUI/Panel/CenterContainer/Label.text = "YOU LOSE\nBaby Wandered Off!"
	$GameOverUI.show()

func _on_game_over():
	# Stop spawning lions
	set_process(false)

	# Show game over UI
	$GameOverUI/Panel/CenterContainer/Label.text = "YOU LOSE\nLion Got Baby!"
	$GameOverUI.show()

func _check_follower_spawns():
	# Check if baby has moved to a new tile region
	var tile_size = 200  # Match background tile size
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
	var zoom_factor = 2.5  # 1 / 0.4
	var visible_width = screen_size.x * zoom_factor
	var visible_height = screen_size.y * zoom_factor

	# Calculate which tiles are visible
	var camera_tile_x = int(camera_pos.x / tile_size)
	var camera_tile_y = int(camera_pos.y / tile_size)
	var visible_tile_radius_x = int(visible_width / tile_size / 2) + 1
	var visible_tile_radius_y = int(visible_height / tile_size / 2) + 1

	# Check tiles in a larger radius around baby
	var search_radius = 8  # Check further out

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

func on_follower_activated(follower: Node2D, activator: Node2D):
	# Legacy method - no longer used
	pass

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
			if distance < 60:  # Click tolerance
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

	var camera_pos = player_elephant.position
	var zoom_factor = 2.5  # 1 / 0.4
	var visible_width = screen_size.x * zoom_factor
	var visible_height = screen_size.y * zoom_factor

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
