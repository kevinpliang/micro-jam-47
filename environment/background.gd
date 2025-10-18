extends Node2D

@export var tile_size: int = 100  # Smaller tiles for finer detail
@export var render_distance: int = 20  # More tiles to cover screen

var player: Node2D
var tiles: Dictionary = {}  # Track spawned tiles
var last_center_tile: Vector2i = Vector2i(999999, 999999)  # Track last update position
var grass_colors = [
	Color(0.45, 0.65, 0.25),  # Dark green
	Color(0.5, 0.7, 0.3),     # Medium dark green
	Color(0.55, 0.75, 0.35),  # Medium green
	Color(0.6, 0.8, 0.4),     # Medium light green
	Color(0.65, 0.85, 0.45),  # Light green
	Color(0.7, 0.9, 0.5),     # Very light green
]

func _ready():
	# Find player to follow
	await get_tree().process_frame
	player = get_parent().get_node("PlayerElephant")

func _process(_delta):
	if player:
		_update_tiles()

func _update_tiles():
	# Calculate which tiles should be visible
	var camera_pos = player.position
	var center_tile_x = int(camera_pos.x / tile_size)
	var center_tile_y = int(camera_pos.y / tile_size)
	var center_tile = Vector2i(center_tile_x, center_tile_y)

	# Only update if we've moved to a new tile (optimization)
	if center_tile == last_center_tile:
		return

	last_center_tile = center_tile

	# Track which tiles should exist
	var new_tiles = {}

	# Generate tiles in a radius around the camera
	for y in range(center_tile_y - render_distance, center_tile_y + render_distance + 1):
		for x in range(center_tile_x - render_distance, center_tile_x + render_distance + 1):
			var key = Vector2i(x, y)
			new_tiles[key] = true

			# Create tile if it doesn't exist
			if not tiles.has(key):
				var rect = ColorRect.new()
				rect.position = Vector2(x * tile_size, y * tile_size)
				rect.size = Vector2(tile_size, tile_size)
				# Use seeded random for consistent colors per tile
				var tile_seed = hash(Vector2i(x, y))
				rect.color = grass_colors[tile_seed % grass_colors.size()]
				add_child(rect)
				tiles[key] = rect

	# Remove tiles that are too far away (batch removal)
	var tiles_to_remove = []
	for key in tiles.keys():
		if not new_tiles.has(key):
			tiles_to_remove.append(key)

	for key in tiles_to_remove:
		tiles[key].queue_free()
		tiles.erase(key)
