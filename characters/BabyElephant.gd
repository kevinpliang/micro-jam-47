extends CharacterBody2D

@export var speed: float = 100.0  # Slower movement
@export var min_move_distance: float = 600.0  # Much longer distances
@export var max_move_distance: float = 1200.0  # Very long distances
@export var arrival_threshold: float = 100.0  # Larger threshold

var target_position: Vector2

signal game_over
signal camera_lost

func _ready():
	# Pick first random target (position already set by level)
	_pick_new_target()

	# Connect area detection
	$Area2D.area_entered.connect(_on_area_entered)

func _pick_new_target():
	# Pick a random position that's a good distance away
	var angle = randf() * TAU  # Random angle
	var distance = randf_range(min_move_distance, max_move_distance)

	# Calculate target position from current position
	# No bounds - infinite map!
	target_position = position + Vector2(cos(angle), sin(angle)) * distance

func _physics_process(delta):
	var direction = (target_position - position).normalized()
	var distance = position.distance_to(target_position)

	# If we've reached the target, pick a new one immediately (no waiting)
	if distance < arrival_threshold:
		_pick_new_target()
		direction = (target_position - position).normalized()

	# Always move towards target (continuous movement)
	velocity = direction * speed
	move_and_slide()

func _on_area_entered(area):
	# Check if we collided with a lion
	if area.get_parent().is_in_group("lion"):
		game_over.emit()
		# Stop moving
		set_physics_process(false)
