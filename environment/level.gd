extends Node2D

const PlayerElephant = preload("res://characters/PlayerElephant.tscn")
const BabyElephant = preload("res://characters/BabyElephant.tscn")
const Lion = preload("res://characters/Lion.tscn")

@export var lion_spawn_interval: float = 3.0  # Spawn a lion every 3 seconds

var spawn_timer: float = 0.0
var screen_size: Vector2
var baby_elephant: Node2D
var player_elephant: Node2D

func _ready():
	screen_size = get_viewport_rect().size
	_spawn_elephants()

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
