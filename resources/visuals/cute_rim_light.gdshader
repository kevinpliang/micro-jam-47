shader_type canvas_item;

uniform vec4 warm_rim : source_color = vec4(1.0, 0.78, 0.44, 1.0);
uniform vec4 cool_shade : source_color = vec4(0.72, 0.78, 0.86, 1.0);
uniform vec2 light_direction = vec2(0.28, -0.96);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.16;
uniform float shade_strength : hint_range(0.0, 0.8) = 0.035;
uniform float edge_width : hint_range(1.0, 8.0) = 2.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE * edge_width;
	float a_left = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	float a_right = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float a_up = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float a_down = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float inner_edge = clamp(tex.a - min(min(a_left, a_right), min(a_up, a_down)), 0.0, 1.0);

	vec2 from_center = normalize(UV - vec2(0.5));
	vec2 light_dir = normalize(light_direction);
	float lit_side = smoothstep(-0.2, 0.85, dot(from_center, -light_dir));
	float shade_side = smoothstep(-0.25, 0.95, dot(from_center, light_dir));

	vec3 shaded = mix(tex.rgb, tex.rgb * cool_shade.rgb, shade_side * shade_strength);
	shaded = mix(shaded, warm_rim.rgb, inner_edge * lit_side * rim_strength);
	COLOR = vec4(shaded, tex.a);
}
