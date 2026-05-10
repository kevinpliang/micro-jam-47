extends Node

const CHARACTER_SHADER := preload("res://resources/visuals/cute_rim_light.gdshader")
const SHADOW_SHADER := preload("res://resources/visuals/painted_shadow.gdshader")

const ACTOR_GROUPS := ["friendly", "baby_elephant", "lion"]
const PROP_GROUP := "render_25d_prop"

@export var enabled: bool = true
@export var shadow_direction: Vector2 = Vector2(-0.48, 0.88)
@export_range(0.0, 1.0) var shadow_opacity: float = 0.78
@export_range(0.0, 1.0) var rim_strength: float = 0.20
@export_range(0.0, 1.0) var contact_opacity: float = 0.42

var _shadow_material: ShaderMaterial
var _character_material: ShaderMaterial
var _contact_texture: GradientTexture2D
var _actor_proxies: Dictionary = {}
var _prop_proxies: Dictionary = {}

func _ready() -> void:
	if not enabled:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_materials()
	_scan_sources()

func _process(_delta: float) -> void:
	if not enabled:
		return
	_scan_sources()
	_sync_actor_proxies()
	_sync_prop_proxies()

func _exit_tree() -> void:
	for proxy_map in [_actor_proxies, _prop_proxies]:
		for entry in proxy_map.values():
			_free_entry_nodes(entry)

func _build_materials() -> void:
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = SHADOW_SHADER
	_shadow_material.set_shader_parameter("shadow_color", Color(0.055, 0.038, 0.018, shadow_opacity))

	_character_material = ShaderMaterial.new()
	_character_material.shader = CHARACTER_SHADER
	_character_material.set_shader_parameter("light_direction", -shadow_direction.normalized())
	_character_material.set_shader_parameter("rim_strength", rim_strength)
	_character_material.set_shader_parameter("shade_strength", 0.055)

	_contact_texture = _make_radial_texture(
		Color(1.0, 1.0, 1.0, contact_opacity),
		Color(1.0, 1.0, 1.0, 0.0),
		192,
		96
	)

func _scan_sources() -> void:
	_scan_actor_sources()
	_scan_prop_sources()

func _scan_actor_sources() -> void:
	for group_name in ACTOR_GROUPS:
		for actor in get_tree().get_nodes_in_group(group_name):
			if not (actor is CharacterBody2D):
				continue
			var key := actor.get_instance_id()
			if _actor_proxies.has(key):
				continue
			var body := actor.get_node_or_null("Flipper/Body") as AnimatedSprite2D
			if body == null:
				continue
			_actor_proxies[key] = _create_actor_proxy(actor, body)

func _scan_prop_sources() -> void:
	for source in get_tree().get_nodes_in_group(PROP_GROUP):
		if not (source is Sprite2D):
			continue
		var key := source.get_instance_id()
		if _prop_proxies.has(key):
			continue
		_prop_proxies[key] = _create_prop_proxy(source)

func _create_actor_proxy(actor: CharacterBody2D, body: AnimatedSprite2D) -> Dictionary:
	body.material = _character_material

	var contact := Sprite2D.new()
	contact.name = "World25DContactShadow"
	contact.texture = _contact_texture
	contact.z_index = 0
	contact.self_modulate = Color(0.08, 0.045, 0.018, contact_opacity)
	actor.add_child(contact)
	actor.move_child(contact, 0)

	var shadow := AnimatedSprite2D.new()
	shadow.name = "World25DCastShadow"
	shadow.material = _shadow_material
	shadow.z_index = 0
	shadow.light_mask = body.light_mask
	actor.add_child(shadow)
	actor.move_child(shadow, 1)

	return {
		"actor_ref": weakref(actor),
		"body_ref": weakref(body),
		"contact": contact,
		"shadow": shadow
	}

func _create_prop_proxy(source: Sprite2D) -> Dictionary:
	var shadow := Sprite2D.new()
	shadow.name = "%s_World25DShadow" % source.name
	shadow.texture = source.texture
	shadow.material = _shadow_material
	shadow.z_index = source.z_index
	shadow.light_mask = source.light_mask
	source.get_parent().add_child(shadow)
	source.get_parent().move_child(shadow, max(source.get_index(), 0))

	return {
		"source_ref": weakref(source),
		"shadow": shadow
	}

func _sync_actor_proxies() -> void:
	for key in _actor_proxies.keys():
		var entry: Dictionary = _actor_proxies[key]
		var actor_object := _ref_value(entry.get("actor_ref"))
		var body_object := _ref_value(entry.get("body_ref"))
		var shadow_object = entry.get("shadow")
		var contact_object = entry.get("contact")
		if not is_instance_valid(actor_object) or not is_instance_valid(body_object) or not is_instance_valid(shadow_object):
			_free_proxy(_actor_proxies, key)
			continue

		var actor := actor_object as CharacterBody2D
		var body := body_object as AnimatedSprite2D
		var shadow := shadow_object as AnimatedSprite2D
		var contact: Sprite2D = null
		if is_instance_valid(contact_object):
			contact = contact_object as Sprite2D
		if actor == null or body == null or shadow == null:
			_free_proxy(_actor_proxies, key)
			continue

		var texture := _get_animation_texture(body)
		if texture == null:
			continue

		var profile := _get_shadow_profile(texture, body.global_scale, actor.name)
		var cast := shadow_direction.normalized()
		var foot := body.position + Vector2(0.0, profile.foot_offset)
		shadow.sprite_frames = body.sprite_frames
		if shadow.animation != body.animation:
			shadow.animation = body.animation
		shadow.frame = body.frame
		shadow.flip_h = body.flip_h
		shadow.flip_v = body.flip_v
		shadow.centered = body.centered
		shadow.position = foot + cast * profile.cast_distance
		shadow.rotation = cast.angle() - PI * 0.5
		shadow.scale = profile.scale
		shadow.self_modulate = Color(1.0, 1.0, 1.0, shadow_opacity)

		if is_instance_valid(contact):
			contact.position = foot + Vector2(0.0, 2.0)
			contact.scale = Vector2(profile.contact_width, profile.contact_height)

func _sync_prop_proxies() -> void:
	for key in _prop_proxies.keys():
		var entry: Dictionary = _prop_proxies[key]
		var source_object := _ref_value(entry.get("source_ref"))
		var shadow_object = entry.get("shadow")
		if not is_instance_valid(source_object) or not is_instance_valid(shadow_object):
			_free_proxy(_prop_proxies, key)
			continue

		var source := source_object as Sprite2D
		var shadow := shadow_object as Sprite2D
		if source == null or shadow == null:
			_free_proxy(_prop_proxies, key)
			continue
		if source.texture == null:
			continue

		var profile := _get_shadow_profile(source.texture, source.global_scale, source.texture.resource_path)
		var cast := shadow_direction.normalized()
		var foot := source.global_position + Vector2(0.0, profile.foot_offset)
		shadow.texture = source.texture
		shadow.flip_h = source.flip_h
		shadow.flip_v = source.flip_v
		shadow.global_position = foot + cast * profile.cast_distance
		shadow.rotation = cast.angle() - PI * 0.5
		shadow.scale = profile.scale
		shadow.self_modulate = Color(1.0, 1.0, 1.0, shadow_opacity * profile.opacity)
		shadow.visible = source.visible

func _get_shadow_profile(texture: Texture2D, source_scale: Vector2, source_name: String) -> Dictionary:
	var width := float(texture.get_width()) * absf(source_scale.x)
	var height := float(texture.get_height()) * absf(source_scale.y)
	var name := source_name.to_lower()
	var target_width := width * 0.80
	var target_height := height * 0.36
	var foot_offset := height * 0.44
	var cast_distance := clampf(target_height * 0.42, 16.0, 72.0)
	var opacity := 1.0

	if name.contains("bush"):
		target_width = width * 0.78
		target_height = height * 0.34
		foot_offset = height * 0.42
		cast_distance = clampf(target_height * 0.42, 22.0, 54.0)
		opacity = 0.70
	elif name.contains("rock"):
		target_width = width * 0.82
		target_height = height * 0.28
		foot_offset = height * 0.40
		cast_distance = clampf(target_height * 0.42, 12.0, 34.0)
		opacity = 0.74
	elif name.contains("grass"):
		target_width = width * 0.42
		target_height = height * 0.44
		foot_offset = height * 0.44
		cast_distance = clampf(target_height * 0.42, 16.0, 42.0)
		opacity = 0.62
	elif name.contains("lion"):
		target_width = width * 0.88
		target_height = height * 0.36
		foot_offset = height * 0.42
		cast_distance = clampf(target_height * 0.44, 18.0, 64.0)
	elif name.contains("baby"):
		target_width = width * 0.76
		target_height = height * 0.34
		foot_offset = height * 0.42
		cast_distance = clampf(target_height * 0.42, 16.0, 52.0)

	return {
		"scale": Vector2(target_width / float(texture.get_width()), target_height / float(texture.get_height())),
		"foot_offset": foot_offset,
		"cast_distance": cast_distance,
		"contact_width": maxf(target_width / 192.0, 0.38),
		"contact_height": maxf(target_height / 96.0, 0.20),
		"opacity": opacity
	}

func _get_animation_texture(body: AnimatedSprite2D) -> Texture2D:
	if body.sprite_frames == null:
		return null
	if not body.sprite_frames.has_animation(body.animation):
		return null
	var frame_count := body.sprite_frames.get_frame_count(body.animation)
	if frame_count <= 0:
		return null
	var frame := clampi(body.frame, 0, frame_count - 1)
	return body.sprite_frames.get_frame_texture(body.animation, frame)

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

func _free_proxy(proxy_map: Dictionary, key: int) -> void:
	var entry: Dictionary = proxy_map.get(key, {})
	_free_entry_nodes(entry)
	proxy_map.erase(key)

func _free_entry_nodes(entry: Dictionary) -> void:
	for node_key in ["shadow", "contact"]:
		var node = entry.get(node_key)
		if is_instance_valid(node) and node is Node:
			node.queue_free()

func _ref_value(value: Variant) -> Object:
	var ref := value as WeakRef
	if ref == null:
		return null
	return ref.get_ref()
