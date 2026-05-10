extends RefCounted

const SHADOW_SHADER := preload("res://resources/visuals/painted_shadow.gdshader")
const SHADOW_DIRECTION := Vector2(-0.62, 0.78)

var _shadow_material: ShaderMaterial

func _init() -> void:
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = SHADOW_SHADER
	_shadow_material.set_shader_parameter("shadow_color", Color(0.05, 0.034, 0.022, 0.82))

func pick_ground_texture(textures: Array[Texture2D], _tile_seed: int) -> Texture2D:
	return textures[0]

func style_ground_tile(sprite: Sprite2D, tile_seed: int) -> void:
	var tint_roll := float(abs(tile_seed) % 100) / 100.0
	var warm_shift := lerpf(0.995, 1.005, tint_roll)
	sprite.self_modulate = Color(0.92 * warm_shift, 0.87 * warm_shift, 0.72, 1.0)
	sprite.light_mask = 1

func decorate_vegetation(parent: Node, veg_sprite: Sprite2D, rng: RandomNumberGenerator) -> Array[Node]:
	veg_sprite.light_mask = 1
	veg_sprite.self_modulate = Color(0.98, 0.92, 0.76, 1.0)
	var shadow := _add_painted_shadow(parent, veg_sprite, rng)
	_add_soft_occluder(veg_sprite)
	var nodes: Array[Node] = []
	nodes.append(shadow)
	return nodes

func _add_painted_shadow(parent: Node, veg_sprite: Sprite2D, rng: RandomNumberGenerator) -> Sprite2D:
	var cast := SHADOW_DIRECTION.normalized()
	var profile := _get_shadow_profile(veg_sprite)
	var foot_offset: float = profile["foot_offset"]
	var cast_distance: float = profile["cast_distance"]
	var shadow_scale: Vector2 = profile["scale"]
	var shadow := Sprite2D.new()
	shadow.name = "%s_PaintedShadow" % veg_sprite.name
	shadow.texture = veg_sprite.texture
	shadow.flip_h = veg_sprite.flip_h
	shadow.material = _shadow_material
	shadow.position = veg_sprite.position + Vector2(0.0, foot_offset) + cast * cast_distance
	shadow.rotation = cast.angle() - PI * 0.5
	shadow.scale = shadow_scale * rng.randf_range(0.94, 1.08)
	shadow.z_index = veg_sprite.z_index - 1
	shadow.light_mask = 1
	parent.add_child(shadow)
	parent.move_child(shadow, max(veg_sprite.get_index(), 0))
	return shadow

func _add_soft_occluder(veg_sprite: Sprite2D) -> void:
	if veg_sprite.texture == null:
		return

	var half_width := minf(float(veg_sprite.texture.get_width()) * absf(veg_sprite.scale.x) * 0.26, 42.0)
	var height := minf(float(veg_sprite.texture.get_height()) * absf(veg_sprite.scale.y) * 0.24, 36.0)
	if half_width < 8.0 or height < 8.0:
		return

	var polygon := OccluderPolygon2D.new()
	polygon.closed = true
	polygon.polygon = PackedVector2Array([
		Vector2(-half_width, -height * 0.35),
		Vector2(half_width, -height * 0.35),
		Vector2(half_width * 0.72, height * 0.45),
		Vector2(-half_width * 0.72, height * 0.45),
	])

	var occluder := LightOccluder2D.new()
	occluder.name = "GoldenHourOccluder"
	occluder.occluder = polygon
	occluder.occluder_light_mask = 1
	occluder.sdf_collision = true
	occluder.position = Vector2(0.0, -height * 0.15)
	veg_sprite.add_child(occluder)

func _get_shadow_profile(veg_sprite: Sprite2D) -> Dictionary:
	if veg_sprite.texture == null:
		return {"foot_offset": 0.0, "cast_distance": 24.0, "scale": Vector2(1.0, 0.35)}

	var texture_path := veg_sprite.texture.resource_path.to_lower()
	var texture_width := float(veg_sprite.texture.get_width())
	var texture_height := float(veg_sprite.texture.get_height())
	var width := texture_width * absf(veg_sprite.scale.x)
	var height := texture_height * absf(veg_sprite.scale.y)
	var target_width := maxf(width * 0.62, 44.0)
	var target_height := maxf(height * 0.34, 22.0)
	var foot_offset := height * 0.20
	var cast_distance := clampf(height * 0.20, 18.0, 48.0)

	if texture_path.contains("bush"):
		target_width = maxf(width * 0.68, 108.0)
		target_height = maxf(height * 0.38, 52.0)
		foot_offset = height * 0.18
		cast_distance = clampf(height * 0.22, 34.0, 62.0)
	elif texture_path.contains("rock"):
		target_width = maxf(width * 0.74, 38.0)
		target_height = maxf(height * 0.34, 14.0)
		foot_offset = height * 0.20
		cast_distance = clampf(height * 0.18, 16.0, 42.0)
	elif texture_path.contains("grass"):
		target_width = maxf(width * 0.42, 22.0)
		target_height = maxf(height * 0.42, 24.0)
		foot_offset = height * 0.24
		cast_distance = clampf(height * 0.20, 20.0, 48.0)

	return {
		"foot_offset": foot_offset,
		"cast_distance": cast_distance,
		"scale": Vector2(target_width / texture_width, target_height / texture_height)
	}
