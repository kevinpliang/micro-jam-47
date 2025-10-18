extends CharacterBody2D

@export var speed: float = 600.0
@export var click_radius: float = 64.0 # How close to click before considering it reached
@onready var flipper: Node2D = $Flipper
@onready var body: AnimatedSprite2D = $Flipper/Body # use $Body if it's not under Flipper

var _facing := 1.0 # remembers last facing when idle
const DEADZONE := 0.01
var target_position: Vector2
var has_target: bool = false

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

	if velocity.x < DEADZONE:
		_facing = - desired
	elif velocity.x > DEADZONE:
		_facing = desired

	flipper.scale.x = _facing

	if velocity != Vector2.ZERO:
		$Flipper/Body.play("run")
	else:
		$Flipper/Body.play("idle")

	# Animations without constant restarting
	#if velocity.length_squared() > DEADZONE * DEADZONE:
		#if body.animation != "run":
			#body.play('run')
	#else:
		#if body.animation != "idle":
			#body.play("idle")
		
func _on_area_entered(area):
	# Check if we collided with a lion - kill it!
	if area.get_parent().is_in_group("lion"):
		area.get_parent().queue_free()
	elif area.get_parent().is_in_group("baby_elephant"):
		var baby = area.get_parent()
		if baby.has_method("bounce_off_player"):
			baby.bounce_off_player(global_position)
