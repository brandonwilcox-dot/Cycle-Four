shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.16, 0.34, 0.12);
uniform vec3 tip_color : source_color = vec3(0.48, 0.72, 0.24);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_strength : hint_range(0.0, 2.0) = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.82;
uniform float wind_strength : hint_range(0.0, 0.35) = 0.12;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.15;

varying vec4 instance_tint;
varying float blade_height;
varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	instance_tint = COLOR;
	blade_height = clamp(UV.y, 0.0, 1.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * wind_speed + world_pos.x * 0.042 + world_pos.z * 0.031;
	float gust = sin(phase) * 0.68 + sin(phase * 2.17 + 1.9) * 0.32;
	float tip_weight = blade_height * blade_height;
	VERTEX.xz += vec2(gust, sin(phase * 0.73 + 0.8)) * wind_strength * tip_weight;
}

void fragment() {
	float variation = 0.86 + 0.22 * hash12(floor(world_pos.xz * 0.11));
	vec3 tint = max(instance_tint.rgb, vec3(0.01));
	ALBEDO = mix(base_color, tip_color, blade_height) * tint * variation;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.10;
	EMISSION = emission_color * emission_strength * (0.25 + 0.75 * blade_height) * tint;
}
