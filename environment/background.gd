extends Node2D

@export var tile_size: int = 150  # Tile size (used for positioning)

var player: Node2D
var tiles: Dictionary = {}  # Track spawned tiles
var screen_size: Vector2

var tile_textures: Array[Texture2D] = []
var vegetation_textures: Array[Texture2D] = []

func _ready():
	# Load background tile textures
	tile_textures = [
		load("res://environment/assets/background/sprite1.png"),
		load("res://environment/assets/background/sprite2.png"),
		load("res://environment/assets/background/sprite3.png")
	]

	# Load vegetation textures
	vegetation_textures = [
		load("res://environment/assets/background/grass1.png"),
		load("res://environment/assets/background/grass2.png"),
		load("res://environment/assets/background/grass3.png"),
		load("res://environment/assets/background/rock1.png"),
		load("res://environment/assets/background/rock2.png"),
		load("res://environment/assets/background/rock3.png"),
		load("res://environment/assets/background/bush1.png"),
		load("res://environment/assets/background/bush2.png"),
	]

	# Find player to follow
	await get_tree().process_frame
	player = get_parent().get_node("PlayerElephant")
	screen_size = get_viewport_rect().size

func _process(_delta):
	if player:
		_update_tiles()

func _update_tiles():
	var camera_pos = player.position
	var zoom_factor = 2.5
	var visible_width = screen_size.x * zoom_factor
	var visible_height = screen_size.y * zoom_factor

	var buffer = 5
	var left_tile = int((camera_pos.x - visible_width / 2) / tile_size) - buffer
	var right_tile = int((camera_pos.x + visible_width / 2) / tile_size) + buffer
	var top_tile = int((camera_pos.y - visible_height / 2) / tile_size) - buffer
	var bottom_tile = int((camera_pos.y + visible_height / 2) / tile_size) + buffer

	var new_tiles = {}

	for y in range(top_tile, bottom_tile + 1):
		for x in range(left_tile, right_tile + 1):
			var key = Vector2i(x, y)
			new_tiles[key] = true

			if not tiles.has(key):
				# --- Background tile ---
				var sprite = Sprite2D.new()
				var tile_seed = hash(Vector2i(x, y))
				sprite.texture = tile_textures[tile_seed % tile_textures.size()]
				sprite.position = Vector2(x * tile_size + tile_size / 2.0, y * tile_size + tile_size / 2.0)
				sprite.scale = Vector2(tile_size / sprite.texture.get_width(), tile_size / sprite.texture.get_height())
				sprite.z_index = -1
				add_child(sprite)
				
				# --- Vegetation layer ---
				var rng = RandomNumberGenerator.new()
				rng.seed = tile_seed  # consistent per tile
				var veg_count = rng.randi_range(0, 10) 
				
				if veg_count == 0:
					var veg_sprite = Sprite2D.new()
					var rand_texture = vegetation_textures[rng.randi_range(0, vegetation_textures.size() - 1)]
					print(rand_texture.resource_name)
					veg_sprite.texture = rand_texture
					
					veg_sprite.position = sprite.position 
					if rng.randi_range(0,1):
						veg_sprite.flip_h = true
						
					veg_sprite.position.y += veg_sprite.texture.get_height() / 2

					add_child(veg_sprite)
				
				tiles[key] = sprite

	# Remove tiles that are off-screen
	var tiles_to_remove = []
	for key in tiles.keys():
		if not new_tiles.has(key):
			tiles_to_remove.append(key)

	for key in tiles_to_remove:
		tiles[key].queue_free()
		tiles.erase(key)
