extends CharacterBody2D

@export var speed: float = 600.0
@export var click_radius: float = 64.0 # How close to click before considering it reached
@onready var flipper: Node2D = $Flipper
@onready var body: AnimatedSprite2D = $Flipper/Body

const MovementArrow = preload("res://characters/MovementArrow.tscn")

var _facing := 1.0 # remembers last facing when idle
var target_position: Vector2
var has_target: bool = false
var in_cutscene = false

func _ready():
	target_position = position

	# Connect area detection to kill lions
	$Flipper/Area2D.area_entered.connect(_on_area_entered)
	$Flipper/Body.play("idle")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Set new target position on left click
			target_position = get_global_mouse_position()
			var movement_arrow = MovementArrow.instantiate()
			movement_arrow.position = target_position
			get_parent().add_child(movement_arrow)
			has_target = true

func _physics_process(_delta):
	if has_target:
		var direction = (target_position - position).normalized()
		var distance = position.distance_to(target_position)

		# If we're close enough to the target, stop moving
		if distance < click_radius:
			has_target = false
			velocity = Vector2.ZERO
		else:
			# Move towards target
			velocity = direction * speed

		move_and_slide()
		_change_sprite()

func _change_sprite():
	var desired := absf(flipper.scale.x)
	if desired == 0.0:
		desired = 1.0

	if velocity.x < -0.01:
		_facing = - desired
	elif velocity.x > 0.01:
		_facing = desired

	flipper.scale.x = _facing

	if velocity.length_squared() > .0001:
		if body.animation != "run":
			body.play('run')
	else:
		if body.animation != "idle":
			body.play("idle")
			
func scale_run_speed() -> void:
	$Flipper/Body.speed_scale += .2
		
func _get_collision_owner(area: Node) -> Node:
	var owner := area
	while owner:
		if owner is CharacterBody2D:
			return owner
		owner = owner.get_parent()
	return area.get_parent() if area else null

func _on_area_entered(area):
	var other := _get_collision_owner(area)
	if other == null:
		return

	# Check if we collided with a lion - kill it!
	if other.is_in_group("lion"):
		if other.has_method("die"):
			other.die()
	elif other.is_in_group("baby_elephant"):
		if other.has_method("bounce_off_player"):
			other.bounce_off_player(global_position)
