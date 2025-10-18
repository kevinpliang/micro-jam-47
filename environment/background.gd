extends Node2D

@export var tile_size: int = 150  # Medium-sized tiles for finer detail

var player: Node2D
var tiles: Dictionary = {}  # Track spawned tiles
var screen_size: Vector2
var grass_colors = [
	Color(0.75, 0.65, 0.35),  # Dry grass tan
	Color(0.80, 0.70, 0.40),  # Golden savannah
	Color(0.70, 0.60, 0.30),  # Darker brown
	Color(0.85, 0.75, 0.45),  # Light sandy
	Color(0.78, 0.68, 0.38),  # Medium tan
	Color(0.82, 0.72, 0.42),  # Warm gold
]

func _ready():
	# Find player to follow
	await get_tree().process_frame
	player = get_parent().get_node("PlayerElephant")
	screen_size = get_viewport_rect().size

func _process(_delta):
	if player:
		# Update tiles every frame for instant loading
		_update_tiles()

func _update_tiles():
	# Calculate which tiles should be visible based on actual camera bounds
	var camera_pos = player.position

	# Camera zoom is 0.4, so visible area is 2.5x larger
	var zoom_factor = 2.5  # 1 / 0.4
	var visible_width = screen_size.x * zoom_factor
	var visible_height = screen_size.y * zoom_factor

	# Calculate visible tile bounds with large buffer for preloading
	var buffer = 5  # Add 5 tiles buffer - preload before visible
	var left_tile = int((camera_pos.x - visible_width / 2) / tile_size) - buffer
	var right_tile = int((camera_pos.x + visible_width / 2) / tile_size) + buffer
	var top_tile = int((camera_pos.y - visible_height / 2) / tile_size) - buffer
	var bottom_tile = int((camera_pos.y + visible_height / 2) / tile_size) + buffer

	# Track which tiles should exist
	var new_tiles = {}

	# Generate only visible tiles - all at once for clean appearance
	for y in range(top_tile, bottom_tile + 1):
		for x in range(left_tile, right_tile + 1):
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

	# Remove tiles that are off-screen - all at once
	var tiles_to_remove = []
	for key in tiles.keys():
		if not new_tiles.has(key):
			tiles_to_remove.append(key)

	for key in tiles_to_remove:
		tiles[key].queue_free()
		tiles.erase(key)
