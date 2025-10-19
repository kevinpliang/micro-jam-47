extends Node

# the name of the player can't be changed
var player: CharacterBody2D = null

# variables that effect the herd positioning
@export var level_spacing: float = 150
@export var inter_level_spacing: float = 150
@export var arc_degrees: float = 45
@export var max_position_age: float = 0.25
@export var invalidate_distance: float = 50

class Arc:
	var num = 0
	var elephants: Array[ElephantPosition] = []
	var radius = 0
	var degrees
		
class FollowerElephant:
	var position: Vector2 = Vector2(0, 0)
	
class ElephantPosition:
	var position: Vector2 = Vector2(0, 0)
	var age: float
	var follower_reference: CharacterBody2D
	
var arcs: Array[Arc] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_refresh_player_reference()
	for i in range(20):
		var a: Arc = Arc.new()
		a.radius = level_spacing * (i + 1)
		a.degrees = clamp(arc_degrees - 10 * i, 20, 200)
		arcs.push_back(a)

func _input(event):
	# clear the entire cache
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			follower_map.clear()
			for arc in arcs:
				arc.elephants.clear()
		
		
func clear_cache():
	follower_map.clear()
	for arc in arcs:
		arc.elephants.clear()

func _refresh_player_reference() -> void:
	if Main.player_elephant != null and !is_instance_valid(Main.player_elephant):
		Main.player_elephant = null

	if is_instance_valid(player):
		return

	if is_instance_valid(Main.player_elephant):
		player = Main.player_elephant
	else:
		player = null
		
var last_velocity = Vector2(0, 0)
var cleared = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_refresh_player_reference()

	if player == null:
		return
	if player.velocity.length() == 0 and !cleared:
		cleared = true
		clear_cache()

	if player.velocity.length() != 0:
		last_velocity = player.velocity
		
	# invalidate cache on change in velocity to 0
	
	var time = Time.get_ticks_msec()
	# clear the old positions
	#for i in follower_map.keys():
		#if abs(follower_map.get(i).age - time) / 1000 > max_position_age:
			#follower_map.erase(i)
	if player.velocity.length() > 0:
		cleared = false
		for arc in arcs:
			for i in range(arc.elephants.size()):
				if i >= arc.elephants.size():
					break
				if abs(arc.elephants[i].age - time) / 1000 > max_position_age:
					follower_map.erase(arc.elephants[i].follower_reference)
					arc.elephants.remove_at(i)
			# invalidate the cache
			#if arc.elephants[i].position.distance_to(player.position) / invalidate_distance:
			#	follower_map.erase(arc.elephants[i].follower_reference)
			#	arc.elephants.remove_at(i)
				
	# URGENT clear the cache of positions so followers can get fresh positions
	pass

# follower elephants call get_position every frame to get a new position to move to
# single thread by default, guaranteed order
# favortism towards elephants that are closer to the player?


var follower_map: Dictionary[CharacterBody2D, ElephantPosition] = {}
	
var arc_width_multiplier: float = 1.0
var test_arc_length: float = 500

func get_player_position() -> Vector2:
	if player != null and is_instance_valid(player):
		return player.position
	return Vector2.ZERO

func get_position(follower: CharacterBody2D) -> Vector2:
	if player == null or !is_instance_valid(player):
		return Vector2.ZERO
	# DEBUG
	#for i in arcs.size():
	#	print_debug("arc ", i, " size: ", arcs[i].elephants.size())
	# use old position
	if follower_map.has(follower):
		var cached_position: ElephantPosition = follower_map.get(follower)
		if cached_position != null:
			return cached_position.position
		
	#print_debug("new position")
	# new position
	for arc in arcs:
		# attempt to generate 5 random positions inside the current arc
		for g in range(arcs.size()):
			var arc_limits: Vector2 = arc_limits_from_velocity(last_velocity, arc.degrees)
			var point: Vector2 = point_on_arc(player.position, arc.radius, arc_limits.x, arc_limits.y)
			# check point against elephants already in the arc
			var valid = true
			for e in arc.elephants:
				var distance := point.distance_to(e.position)
				#print_debug(distance)
				if distance < inter_level_spacing:
					valid = false
			
			if valid:
				#print_debug("valid position found in arc: ", g)
				var position: ElephantPosition = ElephantPosition.new()
				position.age = Time.get_ticks_msec()
				position.position = point
				position.follower_reference = follower
				
				# add it to the arc and the map
				follower_map.set(follower, position)
				arc.elephants.push_back(position)
				break
		
		if follower_map.has(follower):
			#print_debug("breaking")
			break
			
	if follower_map.has(follower):
		var final_position: ElephantPosition = follower_map.get(follower)
		if final_position != null:
			return final_position.position

	if player != null and is_instance_valid(player):
		return player.position

	return Vector2.ZERO

# math helper functins

func arc_width_from_arc_length(arc_length: float, radius: float) -> float:
	return rad_to_deg(arc_length / radius) # in degrees
	
# Returns [start_deg, end_deg] of an arc centered opposite the velocity.
func arc_limits_from_velocity(vel: Vector2, arc_width_deg: float) -> Vector2:
	if vel.length_squared() == 0.0:
		# No direction: pick something sensible (e.g., up); change if needed
		var base_deg: float = -90.0
		return Vector2(base_deg - arc_width_deg * 0.5, base_deg + arc_width_deg * 0.5)

	var base_deg: float = rad_to_deg(vel.angle() + PI) # opposite of velocity
	var start_deg: float = base_deg - arc_width_deg * 0.5
	var end_deg: float = base_deg + arc_width_deg * 0.5
	# Normalize to [0,360) for convenience
	start_deg = fposmod(start_deg, 360.0)
	end_deg = fposmod(end_deg, 360.0)
	return Vector2(start_deg, end_deg)
	
# Returns a point exactly `radius` away from `center`,
# with the angle chosen uniformly between start_deg..end_deg.
func point_on_arc(center: Vector2, radius: float, start_deg: float, end_deg: float) -> Vector2:
	var rng := RandomNumberGenerator.new()
	var a_deg := random_angle_in_range(start_deg, end_deg, rng)
	var a := deg_to_rad(a_deg)
	return center + Vector2.from_angle(a) * radius

# Same idea but lets you choose a distance range (uniform in radius).
func point_in_sector(center: Vector2, min_r: float, max_r: float, start_deg: float, end_deg: float) -> Vector2:
	var rng := RandomNumberGenerator.new()
	var a_deg := random_angle_in_range(start_deg, end_deg, rng)
	var a := deg_to_rad(a_deg)
	# If you want points uniformly over *area*, use sqrt on rand:
	var r: float = lerp(min_r, max_r, sqrt(rng.randf()))
	return center + Vector2.from_angle(a) * r

# Helper that handles wrap-around (e.g., 350°..20°)
func random_angle_in_range(start_deg: float, end_deg: float, rng: RandomNumberGenerator) -> float:
	var s := fposmod(start_deg, 360.0)
	var e := fposmod(end_deg, 360.0)
	if e >= s:
		return rng.randf_range(s, e)
	else:
		# Range crosses 360°, choose from [s,360) ∪ [0,e]
		var span := (360.0 - s) + e
		var t := rng.randf() * span
		return (s + t) if (s + t) < 360.0 else (s + t - 360.0)
