shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 sun_color : source_color = vec4(1.0, 0.66, 0.27, 1.0);
uniform vec4 vignette_color : source_color = vec4(0.07, 0.045, 0.08, 1.0);
uniform vec2 sun_screen_position = vec2(0.63, 0.14);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.09;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.34;
uniform float grain_strength : hint_range(0.0, 0.12) = 0.012;
uniform float time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.0, 289.0))) * 17391.913);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered * vec2(1.15, 0.9));
	float vignette = smoothstep(0.34, 0.78, dist) * vignette_strength;

	float sun_glow = 1.0 - smoothstep(0.0, 0.62, distance(UV, sun_screen_position));
	float low_haze = smoothstep(0.22, 1.0, UV.y) * 0.22;
	float shimmer = hash(UV * vec2(12.0, 7.0) + vec2(time * 0.03, -time * 0.018));
	float haze = (sun_glow + low_haze) * haze_strength * (0.88 + shimmer * 0.12);

	float grain = (hash(FRAGCOORD.xy + vec2(time * 19.0, 0.0)) - 0.5) * grain_strength;
	vec3 overlay = sun_color.rgb * haze + vignette_color.rgb * vignette + vec3(grain);
	float alpha = clamp(haze * 0.34 + vignette * 0.62 + abs(grain) * 0.65, 0.0, 0.52);
	COLOR = vec4(clamp(overlay, vec3(0.0), vec3(1.0)), alpha);
}
