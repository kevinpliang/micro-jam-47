extends CharacterBody2D

@export var speed: float = 100.0 # Slower movement
@export var min_move_distance: float = 600.0 # Much longer distances
@export var max_move_distance: float = 1200.0 # Very long distances
@export var arrival_threshold: float = 100.0 # Larger threshold
@export var bounce_impulse: float = 1000.0
@export var bounce_decay_rate: float = 1.0

var target_position: Vector2
var knockback_velocity: Vector2 = Vector2.ZERO

signal game_over
signal camera_lost

func _ready():
	# Pick first random target (position already set by level)
	_pick_new_target()

	# Connect area detection
	$Area2D.area_entered.connect(_on_area_entered)

func _pick_new_target():
	# Pick a random position that's a good distance away
	var angle = randf() * TAU # Random angle
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
	var desired_velocity = direction * speed
	velocity = desired_velocity + knockback_velocity
	move_and_slide()
	_change_sprite()
	var decay = clamp(bounce_decay_rate * delta, 0.0, 1.0)
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, decay)
	
func _change_sprite():
	if velocity.x < 0:
		$Body.flip_h = true
	elif velocity.x > 0:
		$Body.flip_h = false
		
	if velocity != Vector2.ZERO:
		$Body.play("run")
	else:
		$Body.play("idle")

func _on_area_entered(area):
	# Check if we collided with a lion
	if area.get_parent().is_in_group("lion"):
		game_over.emit()
		# Stop moving
		set_physics_process(false)

func bounce_off_player(player_position: Vector2):
	var away = global_position - player_position
	if away.length_squared() == 0.0:
		away = Vector2.RIGHT
	knockback_velocity = away.normalized() * bounce_impulse
	_set_new_target_away_from(player_position)

func _set_new_target_away_from(origin: Vector2):
	var away_direction = (global_position - origin).normalized()
	if away_direction == Vector2.ZERO:
		away_direction = Vector2.RIGHT
	var distance = randf_range(min_move_distance, max_move_distance)
	var new_global_target = global_position + away_direction * distance
	target_position = to_local(new_global_target)
