shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 shadow_color : source_color = vec4(0.075, 0.055, 0.04, 0.48);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float feather = smoothstep(0.02, 0.80, tex.a);
	COLOR = vec4(shadow_color.rgb, shadow_color.a * feather * COLOR.a);
}
