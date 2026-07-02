// V1 atmosphere: procedural starfield sky. The board sits in a galaxy, not a void color.
// Tone target (codex/09): quiet awe — dim nebula, sparse stars, slow drift. Star peaks
// exceed 1.0 so the glow pass blooms them faintly. Keep everything DIM: the battlefield
// is the subject, the sky is the room it sits in.
shader_type sky;

uniform vec3 base_col : source_color = vec3(0.010, 0.014, 0.026);
uniform vec3 nebula_col_a : source_color = vec3(0.045, 0.065, 0.150);
uniform vec3 nebula_col_b : source_color = vec3(0.095, 0.050, 0.115);
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.55;
uniform float star_brightness : hint_range(0.0, 3.0) = 1.35;
uniform float drift_speed : hint_range(0.0, 0.05) = 0.004;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec3(11.3);
		a *= 0.5;
	}
	return v;
}

// Point stars from a 3D voxel grid: each cell may hold one star at a hashed offset.
float stars(vec3 d, float scale, float fill) {
	vec3 p = d * scale;
	vec3 id = floor(p);
	vec3 f = fract(p) - 0.5;
	float m = hash13(id + 7.7);
	if (m > fill) {
		return 0.0;
	}
	vec3 sp = (hash33(id) - 0.5) * 0.8;
	float r = length(f - sp);
	float b = m / fill;   // per-star brightness variation
	return smoothstep(0.10, 0.0, r) * b * b;
}

void sky() {
	// Slow drift — rotate the view direction around Y. Patient, per the tone compass.
	float a = TIME * drift_speed;
	float ca = cos(a);
	float sa = sin(a);
	vec3 d = vec3(ca * EYEDIR.x + sa * EYEDIR.z, EYEDIR.y, -sa * EYEDIR.x + ca * EYEDIR.z);

	vec3 col = base_col;

	// Nebula: two dim dye clouds, thinned hard so most of the sky stays near-black.
	float n = fbm(d * 2.3);
	float mask = smoothstep(0.52, 0.86, n);
	vec3 dye = mix(nebula_col_a, nebula_col_b, fbm(d * 1.6 + vec3(5.0)));
	col += dye * mask * nebula_strength;

	// Two star layers: dense faint dust + sparse bright points (these bloom slightly).
	float s = stars(d, 220.0, 0.12) * 0.55;
	s += stars(d, 80.0, 0.06);
	col += vec3(0.92, 0.95, 1.0) * s * star_brightness;

	COLOR = col;
}
