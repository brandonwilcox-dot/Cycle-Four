// V5.0 Academy/Pilgrimage chamber veil: soft vignette + slow film grain over the chamber.
// The chamber is the Pilgrimage interior (codex/04) — the veil pulls the eye to the centre
// and gives the stone a held-breath stillness. Deliberately faint; readability untouched.
shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float v = smoothstep(0.32, 0.92, length(UV - vec2(0.5)) * 1.30);
	float g = (hash12(UV * vec2(913.0, 761.0) + vec2(floor(TIME * 18.0))) - 0.5) * grain_strength;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(v * vignette_strength + g, 0.0, 1.0));
}
