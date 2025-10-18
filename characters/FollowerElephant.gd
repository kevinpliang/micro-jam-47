extends CharacterBody2D

@export var follow_speed: float = 300.0  # Match player elephant speed
@export var stop_distance: float = 20.0  # Stop when very close (almost on top)
@export var base_spacing_distance: float = 45.0  # Base spacing for first follower - tight group

@export var dash_speed: float = 900.0 # speed of the elephant when it is moving

var target: Node2D = null  # Who to follow (player or another follower)
var is_activated: bool = false
var chain_position: int = 0  # Position in the follower chain (0 = first follower)
var spacing_distance: float = 80.0  # Actual spacing (calculated based on chain position)

# States: "inactive", "in_group", "deployed", "returning"
var state: String = "inactive"
var deployed_position: Vector2 = Vector2.ZERO  # Where follower was sent
var has_been_activated_before: bool = false  # Track if ever joined group

func _ready():
	# Connect area detection to activate on player touch
	$Area2D.area_entered.connect(_on_area_entered)

func _physics_process(_delta):
	if state == "inactive":
		return

	if state == "deployed":
		# Stay at deployed position
		var distance = global_position.distance_to(deployed_position)
		if distance > 10:
			var direction = (deployed_position - global_position).normalized()
			velocity = direction * dash_speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO
		return

	# For "in_group" and "returning" states, follow target
	if target == null or not is_instance_valid(target):
		return

	var target_pos = target.global_position
	var my_pos = global_position
	var distance = my_pos.distance_to(target_pos)

	if state == "returning":
		# Move directly to player until close enough to rejoin
		if distance > 60:  # Need to get close to rejoin
			var direction = (target_pos - my_pos).normalized()
			velocity = direction * follow_speed
			move_and_slide()
		else:
			# Close enough - rejoin the group
			if get_parent().has_method("add_follower_to_chain"):
				get_parent().add_follower_to_chain(self)
		return

	# "in_group" state - maintain spacing
	# Define acceptable range for spacing - tighter tolerance for tight group
	var min_spacing = spacing_distance - 8
	var max_spacing = spacing_distance + 8

	# Maintain spacing distance from target
	if distance > max_spacing:
		# Too far - move closer
		var direction = (target_pos - my_pos).normalized()
		velocity = direction * follow_speed
		move_and_slide()
	elif distance < min_spacing:
		# Too close - move away
		var direction = (my_pos - target_pos).normalized()
		velocity = direction * follow_speed * 0.5
		move_and_slide()
	else:
		# In acceptable range - stop completely
		velocity = Vector2.ZERO

func _on_area_entered(area):
	# Check if player touched us (only works for never-activated followers)
	if state == "inactive" and not has_been_activated_before:
		var parent = area.get_parent()
		if parent and parent.name == "PlayerElephant":
			# Notify level to add us to the chain
			if get_parent().has_method("add_follower_to_chain"):
				get_parent().add_follower_to_chain(self)
	# If a lion touches a follower, destroy the lion (same as player)
	var other = area.get_parent()
	if other and other.is_in_group("lion"):
		other.queue_free()

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
	var darkness = 1.0 - (chain_position * 0.05)  # Gradual darkening
	$Body.modulate = Color(0.5 * darkness, 0.65 * darkness, 0.5 * darkness, 1)

func deploy_to_position(pos: Vector2):
	# Send this follower to a position on the map
	state = "deployed"
	deployed_position = pos
	target = null

	# Make them a different color when deployed
	$Body.modulate = Color(0.8, 0.6, 0.4, 1)  # Brownish to show they're independent

func recall():
	# Call this follower back to the group
	state = "returning"
	# Target will be set by level when recalling
	# Color will change back when they rejoin
