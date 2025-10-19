extends CharacterBody2D

@export var follow_speed: float = 600.0 # Match player elephant speed
@export var stop_distance: float = 20.0 # Stop when very close (almost on top)
@export var base_spacing_distance: float = 45.0 # Base spacing for first follower - tight group
@onready var flipper: Node2D = $Flipper
@onready var body: AnimatedSprite2D = $Flipper/Body

var _facing := 1.0 # remembers last facing when idle
var target: Node2D = null # Who to follow (player or another follower)
var is_activated: bool = false
var chain_position: int = 0 # Position in the follower chain (0 = first follower)
var spacing_distance: float = 80.0 # Actual spacing (calculated based on chain position)

# States: "inactive", "in_group"
var state: String = "inactive"
var has_been_activated_before: bool = false # Track if ever joined group

func _ready():
	# Connect area detection to activate on player touch
	$Flipper/Area2D.area_entered.connect(_on_area_entered)
	$Flipper/Body.play("idle")

func _get_collision_owner(area: Node) -> CharacterBody2D:
	var owner := area
	while owner and not (owner is CharacterBody2D):
		owner = owner.get_parent()
	return owner

func _physics_process(_delta):
	if state != "in_group":
		return

	if target == null or not is_instance_valid(target):
		return

	var herd_position: Vector2 = HerdService.get_position(self)
	var my_pos := global_position
	var distance := my_pos.distance_to(herd_position)
	var player_position: Vector2 = HerdService.get_player_position()

	var min_spacing = spacing_distance - 8
	var max_spacing = spacing_distance + 8

	if distance > max_spacing and position.distance_to(player_position) > 150:
		# Too far - move closer to assigned herd slot
		var direction = (herd_position - my_pos).normalized()
		velocity = direction * follow_speed
		move_and_slide()
	elif distance < min_spacing and position.distance_to(player_position) > 150:
		# Too close - ease back to maintain spacing
		var direction = (my_pos - herd_position).normalized()
		velocity = direction * follow_speed * 0.5
		move_and_slide()
	else:
		# In acceptable range - stop completely
		velocity = Vector2.ZERO

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

func _on_area_entered(area):
	var other := _get_collision_owner(area)
	if other == null:
		return

	# Check if player touched us (only works for never-activated followers)
	if state == "inactive" and not has_been_activated_before and other.name == "PlayerElephant":
		# Notify level to add us to the chain
		if get_parent().has_method("add_follower_to_chain"):
			get_parent().add_follower_to_chain(self)

	# If a lion touches a follower, destroy the lion (same as player)
	if other.is_in_group("lion") and state != "inactive":
		other.die()

func activate(player_ref: Node2D, chain_pos: int = 0):
	is_activated = true
	has_been_activated_before = true
	state = "in_group"
	target = player_ref
	chain_position = chain_pos

	# Calculate spacing based on chain position
	# Further followers have much less spacing for tight group effect
	# Using 0.5 makes spacing decrease very fast - creates tight cluster
	spacing_distance = base_spacing_distance * pow(0.5, chain_position)

	# Change color when activated - darker for followers further back
	var darkness = 1.0
	$Flipper/Body.modulate = Color(0.5 * darkness, 0.65 * darkness, 0.5 * darkness, 1)
