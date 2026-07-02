// V2 ground pass (visual-supercharge-plan.md): the board's tile MultiMesh material.
// Per-instance COLOR still carries the cell-type base (readability rule: type colors are
// canon for gameplay), this shader adds the *place*: procedural macro variation, grid lines
// that fade with camera distance (planning tool up close, terrain from afar), smooth
// fog-of-war sampled from a per-cell data texture (soft dissolve at the frontier — the
// unknown absorbs light, codex/04), and claimed territory rendered as faction substrate
// creep: Architect crystalline seams / Bloom bioluminescent growth / Mesh circuit traces.
//
// map_tex (COLS×ROWS, filter_linear): R = revealed (permanently explored), G = claimed,
// B = path-ness (paths/spawns/base get less noise), A = LIT (inside a friendly sight circle
// right now). Three fog tiers: unknown (near-black) / explored memory (dim, desaturated —
// the dark is ever-present) / watched (fully lit). MapGrid._refresh_terrain updates it.
shader_type spatial;
render_mode cull_back;

uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform vec2 map_cells = vec2(60.0, 34.0);
uniform float cell_size = 64.0;

uniform int creep_pattern = 1;                                   // 0 architects / 1 bloom / 2 mesh
uniform vec3 claim_base : source_color = vec3(0.10, 0.30, 0.16); // claimed ground base tone
uniform vec3 creep_accent : source_color = vec3(0.45, 1.0, 0.50);// substrate glow color
uniform vec3 fog_color : source_color = vec3(0.030, 0.038, 0.055);

uniform float grid_near = 1200.0;   // full grid inside this camera distance (px)
uniform float grid_far  = 3500.0;   // no grid beyond this
uniform float noise_strength = 0.30;

varying vec3 wpos;
varying vec4 inst_col;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec2(17.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inst_col = COLOR;
}

void fragment() {
	vec2 board = map_cells * cell_size;
	vec2 uv = clamp(wpos.xz / board, vec2(0.0), vec2(1.0));
	vec4 data = texture(map_tex, uv);
	float revealed = data.r;
	float claimed  = data.g;
	float pathness = data.b;
	float lit_raw  = data.a;

	// --- base: instance color + macro variation (paths stay smoother = readable corridors)
	float n = fbm(wpos.xz * 0.013);
	vec3 base = inst_col.rgb * (1.0 + (n - 0.5) * mix(noise_strength, 0.10, pathness));

	// --- claimed territory: faction substrate creep with a soft, noisy frontier
	float creep = smoothstep(0.30, 0.72, claimed + (fbm(wpos.xz * 0.03 + vec2(53.1)) - 0.5) * 0.45);
	vec3 emis = vec3(0.0);
	if (creep > 0.001) {
		base = mix(base, claim_base * (0.85 + 0.3 * n), creep * 0.85);
		float pat = 0.0;
		if (creep_pattern == 0) {
			// Architects: engineered crystalline seams — straight lines on the half-cell
			// lattice, constant (nothing organic, nothing pulsing).
			vec2 g = abs(fract(wpos.xz / (cell_size * 0.5)) - 0.5);
			pat = (1.0 - smoothstep(0.015, 0.06, min(g.x, g.y))) * 0.8;
		} else if (creep_pattern == 1) {
			// Bloom: bioluminescent growth — noise-thresholded speckle that breathes slowly.
			float s = fbm(wpos.xz * 0.085);
			pat = smoothstep(0.60, 0.74, s) * (0.55 + 0.45 * sin(TIME * 1.1 + s * 24.0));
		} else {
			// Mesh: conductive traces — thin horizontal lines carrying a traveling pulse.
			vec2 g = abs(fract(wpos.xz / (cell_size * 0.34)) - 0.5);
			float line = 1.0 - smoothstep(0.02, 0.06, g.y);
			float pulse = smoothstep(0.80, 1.0, fract(wpos.x / (cell_size * 9.0) - TIME * 0.12));
			pat = line * (0.20 + 1.05 * pulse);
		}
		emis = creep_accent * pat * creep;
	}

	// --- grid lines: a planning tool, not terrain — fade out as the camera pulls back
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float grid_fade = 1.0 - smoothstep(grid_near, grid_far, distance(cam, wpos));
	vec2 gc = abs(fract(wpos.xz / cell_size) - 0.5);
	float line = smoothstep(0.44, 0.478, max(gc.x, gc.y));
	base *= 1.0 - line * 0.38 * grid_fade;

	// --- fog of war, three tiers ---
	// unknown: near-black, noisy dissolve frontier (the unknown absorbs light).
	// explored memory: you keep the map knowledge, but unwatched ground sinks into a dim,
	// desaturated dark — the ever-present threat. Claims/paths stay legible, just shadowed.
	// watched: soft light pools around anything with eyes (Commander/FOB/towers/garrisons/units).
	float e = revealed + (fbm(wpos.xz * 0.02 + vec2(31.0)) - 0.5) * 0.35;
	float explored = smoothstep(0.35, 0.62, e);
	float lit = smoothstep(0.30, 0.70, lit_raw + (fbm(wpos.xz * 0.025 + vec2(7.3)) - 0.5) * 0.30);

	float luma = dot(base, vec3(0.3333));
	vec3 memory_col = (mix(vec3(luma), base, 0.45) * 0.38) + fog_color * 0.35;
	vec3 seen = mix(memory_col, base, lit);
	vec3 fogged = fog_color * (0.75 + 0.5 * n);

	ALBEDO = mix(fogged, seen, explored);
	EMISSION = emis * explored * (0.20 + 0.80 * lit);   // creep glows faintly from memory, fully when watched
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
