extends Node

const OVERLAY_SHADER := preload("res://resources/visuals/screen_golden_hour.gdshader")
const CHARACTER_SHADER := preload("res://resources/visuals/cute_rim_light.gdshader")

@export var sun_direction: Vector2 = Vector2(0.62, -0.78)
@export var ambient_color: Color = Color(0.42, 0.36, 0.30, 1.0)
@export_range(0.0, 1.0) var shadow_opacity: float = 0.82
@export_range(0.0, 1.0) var rim_strength: float = 0.18
@export_range(0.0, 1.0) var haze_strength: float = 0.09
@export_range(0.0, 1.0) var vignette_strength: float = 0.34

var _overlay_material: ShaderMaterial
var _character_material: ShaderMaterial
var _shadow_texture: GradientTexture2D
var _overlay_rect: ColorRect
var _decorate_timer: float = 0.0
var _decorated_ids: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_setup_runtime_visuals")

func _process(delta: float) -> void:
	if _overlay_material:
		_overlay_material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	if _overlay_rect:
		_overlay_rect.size = get_viewport().get_visible_rect().size
	_decorate_timer -= delta
	if _decorate_timer <= 0.0:
		_decorate_timer = 0.35
		_decorate_character_sprites()

func _setup_runtime_visuals() -> void:
	_build_materials()
	_add_canvas_modulate()
	_add_sun_light()
	_add_screen_overlay()
	_decorate_character_sprites()

func _build_materials() -> void:
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = OVERLAY_SHADER
	_overlay_material.set_shader_parameter("haze_strength", haze_strength)
	_overlay_material.set_shader_parameter("vignette_strength", vignette_strength)
	_overlay_material.set_shader_parameter("sun_screen_position", _screen_sun_position())

	_character_material = ShaderMaterial.new()
	_character_material.shader = CHARACTER_SHADER
	_character_material.set_shader_parameter("light_direction", sun_direction.normalized())
	_character_material.set_shader_parameter("rim_strength", rim_strength)

	_shadow_texture = _make_radial_texture(
		Color(1.0, 1.0, 1.0, 0.76),
		Color(1.0, 1.0, 1.0, 0.0),
		192,
		96
	)

func _add_canvas_modulate() -> void:
	if get_parent().get_node_or_null("GoldenHourCanvasModulate"):
		return
	var canvas := CanvasModulate.new()
	canvas.name = "GoldenHourCanvasModulate"
	canvas.color = ambient_color
	get_parent().add_child(canvas)

func _add_sun_light() -> void:
	if get_parent().get_node_or_null("GoldenHourSun"):
		return
	var sun := DirectionalLight2D.new()
	sun.name = "GoldenHourSun"
	sun.color = Color(1.0, 0.82, 0.58, 1.0)
	sun.energy = 0.96
	sun.height = 0.96
	sun.rotation = sun_direction.angle() + PI * 0.5
	sun.shadow_enabled = false
	get_parent().add_child(sun)

func _add_screen_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GoldenHourScreenOverlay"
	layer.layer = 0
	get_parent().add_child(layer)

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "Overlay"
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.color = Color.WHITE
	_overlay_rect.material = _overlay_material
	_overlay_rect.size = get_viewport().get_visible_rect().size
	layer.add_child(_overlay_rect)

func _decorate_character_sprites() -> void:
	for node in _get_character_candidates():
		if not is_instance_valid(node):
			continue
		var id := node.get_instance_id()
		if _decorated_ids.has(id):
			continue
		var body := node.get_node_or_null("Flipper/Body") as CanvasItem
		if body == null:
			continue
		body.material = _character_material
		body.light_mask = 1
		_add_contact_shadow(node)
		_add_character_occluder(node)
		_decorated_ids[id] = true

func _get_character_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	for group_name in ["friendly", "baby_elephant", "lion"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is CharacterBody2D and not candidates.has(node):
				candidates.append(node)
	return candidates

func _add_contact_shadow(character: Node) -> void:
	if character.get_node_or_null("GoldenHourContactShadow"):
		return
	var cast := _shadow_direction()

	var contact := Sprite2D.new()
	contact.name = "GoldenHourContactShadow"
	contact.texture = _shadow_texture
	contact.position = Vector2(0.0, 70.0)
	contact.scale = Vector2(1.95, 0.50)
	contact.self_modulate = Color(0.048, 0.031, 0.02, shadow_opacity * 0.86)
	contact.z_index = 0
	contact.light_mask = 1
	character.add_child(contact)
	character.move_child(contact, 0)

	var tail := Sprite2D.new()
	tail.name = "GoldenHourCastShadow"
	tail.texture = _shadow_texture
	tail.position = cast * 158.0 + Vector2(0.0, 76.0)
	tail.scale = Vector2(3.05, 0.46)
	tail.rotation = cast.angle()
	tail.self_modulate = Color(0.052, 0.034, 0.022, shadow_opacity * 0.70)
	tail.z_index = 0
	tail.light_mask = 1
	character.add_child(tail)
	character.move_child(tail, 1)

func _add_character_occluder(character: Node) -> void:
	if character.get_node_or_null("GoldenHourOccluder"):
		return
	var polygon := OccluderPolygon2D.new()
	polygon.closed = true
	polygon.polygon = PackedVector2Array([
		Vector2(-46.0, -42.0),
		Vector2(48.0, -42.0),
		Vector2(58.0, 34.0),
		Vector2(26.0, 72.0),
		Vector2(-42.0, 66.0),
		Vector2(-60.0, 14.0),
	])

	var occluder := LightOccluder2D.new()
	occluder.name = "GoldenHourOccluder"
	occluder.occluder = polygon
	occluder.occluder_light_mask = 1
	occluder.sdf_collision = true
	character.add_child(occluder)

func _find_player() -> Node2D:
	if Main.player_elephant != null and is_instance_valid(Main.player_elephant):
		return Main.player_elephant
	return get_parent().get_node_or_null("PlayerElephant") as Node2D

func _make_radial_texture(inner: Color, outer: Color, width: int, height: int) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)

	var texture := GradientTexture2D.new()
	texture.width = width
	texture.height = height
	texture.fill = 1
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture

func _shadow_direction() -> Vector2:
	return -sun_direction.normalized()

func _screen_sun_position() -> Vector2:
	var dir := sun_direction.normalized()
	return Vector2(0.5, 0.5) + dir * Vector2(0.46, 0.38)
