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

uniform float grid_near = 900.0;    // full grid inside this camera distance (px)
uniform float grid_far  = 2200.0;   // no grid beyond this
uniform float noise_strength = 0.38;

// V6-lite terrain/water (backlog F1, visual layer): height relief on open ground and pooled
// water in the lowlands. Seeded per territory (MapGrid passes map_seed) so every world differs.
// Paths / spawns / base / claimed ground stay FLAT — the game reads exactly as before.
uniform float terrain_seed = 0.0;
// The Commander claims/constructs as it moves: the creep PATTERN shows at full strength
// only near it (the work in progress); settled territory keeps a faint trace (playtest).
uniform vec2 commander_pos = vec2(-99999.0, -99999.0);
uniform float height_amp : hint_range(0.0, 40.0) = 21.0;   // round 4: terrain read as flat
uniform float water_level : hint_range(0.0, 1.0) = 0.34;

// E1 biome palette (environment-skinning-plan.md): per-territory look, driven by MapGrid.
uniform vec3 ground_tint : source_color = vec3(1.0, 1.0, 1.0);   // multiplies open ground
uniform vec3 water_col : source_color = vec3(0.045, 0.115, 0.185);
uniform vec3 water_glow : source_color = vec3(0.08, 0.22, 0.32);
uniform float sparkle : hint_range(0.0, 1.5) = 0.0;      // crystalline glints on high ground

// E1b photoreal pass: 3-layer PBR splat (PolyHaven 2K scans, CC0) — grass hugs the
// waterline, soil owns the flats, rock takes heights + steep slopes. World-planar UVs.
uniform sampler2D tex_soil_d : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_soil_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_soil_r : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock_d : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock_r : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_grass_d : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_grass_r : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 0.0035;       // world px → texture uv (~4.5 cells per repeat)
uniform float detail_strength : hint_range(0.0, 1.5) = 1.0;
uniform float grid_strength : hint_range(0.0, 0.5) = 0.18;  // 0 = grid off (settings toggle)

varying vec3 wpos;
varying vec4 inst_col;
varying float v_hn;     // terrain height noise 0..1
varying float v_flat;   // 1 = open ground (may have relief/water), 0 = gameplay-flat
varying float v_slope;  // terrain steepness 0..1 (drives the rock splat layer)

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
	// Terrain relief: continuous across tiles (world-space noise → shared edge vertices get
	// identical heights, no cracks). relief² keeps lowlands flat and hills read as hills.
	vec2 tuv = clamp(wpos.xz / (map_cells * cell_size), vec2(0.0), vec2(1.0));
	vec4 td = textureLod(map_tex, tuv, 0.0);
	v_flat = 1.0 - td.b;   // paths/spawns/base flat; claiming does NOT flatten (water survives)
	v_hn = fbm(wpos.xz * 0.006 + vec2(terrain_seed));
	float relief = max(v_hn - water_level, 0.0);
	float amp = height_amp * 3.0 * v_flat;
	VERTEX.y += relief * relief * amp;
	// Recompute the normal from the height field (finite differences). Without this the
	// displaced hills are lit as if flat — the grid seemed to float over a phantom shadow.
	float e = 10.0;
	float hx = max(fbm((wpos.xz + vec2(e, 0.0)) * 0.006 + vec2(terrain_seed)) - water_level, 0.0);
	float hz = max(fbm((wpos.xz + vec2(0.0, e)) * 0.006 + vec2(terrain_seed)) - water_level, 0.0);
	float dhx = (hx * hx - relief * relief) * amp / e;
	float dhz = (hz * hz - relief * relief) * amp / e;
	NORMAL = normalize(vec3(-dhx, 1.0, -dhz));
	v_slope = clamp(length(vec2(dhx, dhz)) * 4.0, 0.0, 1.0);
}

void fragment() {
	vec2 board = map_cells * cell_size;
	vec2 uv = clamp(wpos.xz / board, vec2(0.0), vec2(1.0));
	vec4 data = texture(map_tex, uv);
	float revealed = data.r;
	float claimed  = data.g;
	float pathness = data.b;
	float lit_raw  = data.a;

	// --- E1b PBR splat: photoreal scanned ground, blended by height + slope ------------
	float n = fbm(wpos.xz * 0.013);
	vec2 puv = wpos.xz * uv_scale;
	float h = v_hn - water_level;
	float w_rock = clamp(smoothstep(0.10, 0.24, h) + v_slope * 1.6, 0.0, 1.0);
	float w_grass = (1.0 - smoothstep(0.015, 0.075, h)) * (1.0 - w_rock);
	float w_soil = clamp(1.0 - w_rock - w_grass, 0.0, 1.0);
	vec3 alb1 = texture(tex_soil_d, puv).rgb * w_soil
	          + texture(tex_rock_d, puv).rgb * w_rock
	          + texture(tex_grass_d, puv).rgb * w_grass;
	// Anti-tiling: a second 180-degree-rotated scale blended in by macro noise. Every
	// PBR channel uses the same transform + blend so visible features and lighting agree.
	vec2 puv2 = puv * -0.37 + vec2(11.3);
	vec3 alb2 = texture(tex_soil_d, puv2).rgb * w_soil
	          + texture(tex_rock_d, puv2).rgb * w_rock
	          + texture(tex_grass_d, puv2).rgb * w_grass;
	float anti_mix = clamp(fbm(wpos.xz * 0.004) * 1.2 - 0.2, 0.0, 1.0);
	vec3 alb = mix(alb1, alb2, anti_mix);
	vec3 nrm1 = (texture(tex_soil_n, puv).rgb * 2.0 - 1.0) * w_soil
	          + (texture(tex_rock_n, puv).rgb * 2.0 - 1.0) * w_rock
	          + (texture(tex_grass_n, puv).rgb * 2.0 - 1.0) * w_grass;
	vec3 nrm2 = (texture(tex_soil_n, puv2).rgb * 2.0 - 1.0) * w_soil
	          + (texture(tex_rock_n, puv2).rgb * 2.0 - 1.0) * w_rock
	          + (texture(tex_grass_n, puv2).rgb * 2.0 - 1.0) * w_grass;
	// The secondary UV is rotated 180 degrees, so rotate its tangent-space XY normal too.
	nrm2.xy *= -1.0;
	vec3 nrm = normalize(mix(normalize(nrm1), normalize(nrm2), anti_mix));
	vec3 nrm_encoded = nrm * 0.5 + 0.5;
	float rgh1 = texture(tex_soil_r, puv).r * w_soil
	           + texture(tex_rock_r, puv).r * w_rock
	           + texture(tex_grass_r, puv).r * w_grass;
	float rgh2 = texture(tex_soil_r, puv2).r * w_soil
	           + texture(tex_rock_r, puv2).r * w_rock
	           + texture(tex_grass_r, puv2).r * w_grass;
	float rgh = mix(rgh1, rgh2, anti_mix);

	// paths/spawns/base keep the flat readable corridor style; open ground gets the scans
	vec3 path_col = inst_col.rgb * (1.0 + (n - 0.5) * 0.10);
	vec3 terr_col = alb * ground_tint * (1.0 + (n - 0.5) * noise_strength * detail_strength);
	terr_col *= 1.0 + max(h, 0.0) * 0.30;   // highlands catch more light
	float gmix = v_flat;
	vec3 base = mix(path_col, terr_col, gmix);

	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float grid_fade = 1.0 - smoothstep(grid_near, grid_far, distance(cam, wpos));

	// Water mask first: creep and grid never draw over water (claiming keeps the pool).
	float water = (1.0 - smoothstep(water_level - 0.05, water_level, v_hn)) * v_flat;
	vec3 water_nrm = vec3(0.5, 0.5, 1.0);

	// --- claimed territory: faction substrate creep with a soft, noisy frontier
	float creep = smoothstep(0.30, 0.72, claimed + (fbm(wpos.xz * 0.03 + vec2(53.1)) - 0.5) * 0.45) * (1.0 - water);
	vec3 emis = vec3(0.0);
	if (creep > 0.001) {
		float claim_luma = max(dot(claim_base, vec3(0.3333)), 0.05);
		vec3 claim_tint = claim_base / claim_luma;
		vec3 claim_surface = base * mix(vec3(1.0), claim_tint, 0.48) * (0.92 + 0.16 * n);
		base = mix(base, claim_surface, creep * 0.78);
		float pat = 0.0;
		if (creep_pattern == 0) {
			// Architects: engineered crystalline seams — straight lines on the half-cell
			// lattice, constant (nothing organic, nothing pulsing).
			vec2 g = abs(fract(wpos.xz / (cell_size * 0.5)) - 0.5);
			pat = (1.0 - smoothstep(0.008, 0.035, min(g.x, g.y))) * 0.5;
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
		// Active-work highlight: the pattern is the Commander's construction in progress.
		float work = 0.15 + 0.85 * (1.0 - smoothstep(220.0, 480.0, distance(wpos.xz, commander_pos)));
		emis = creep_accent * pat * creep * work;
	}

	// --- grid lines: a planning tool, not terrain — fade out as the camera pulls back
	vec2 gc = abs(fract(wpos.xz / cell_size) - 0.5);
	float line = smoothstep(0.458, 0.486, max(gc.x, gc.y));
	float flat_ground = 1.0 - smoothstep(0.02, 0.10, max(v_hn - water_level, 0.0) * v_flat);
	base *= 1.0 - line * grid_strength * grid_fade * (1.0 - water) * flat_ground;

	// --- water: pooled lowlands (visual only — the sim is untouched). Animated ripple with a
	// faint emissive sparkle so it still reads inside the fog tiers. Claim-proof.
	if (water > 0.001) {
		float ripple = fbm(wpos.xz * 0.05 + vec2(TIME * 0.22, TIME * 0.15));
		float ripple_x = fbm((wpos.xz + vec2(1.5, 0.0)) * 0.05 + vec2(TIME * 0.22, TIME * 0.15));
		float ripple_z = fbm((wpos.xz + vec2(0.0, 1.5)) * 0.05 + vec2(TIME * 0.22, TIME * 0.15));
		vec3 wn = normalize(vec3((ripple - ripple_x) * 2.6, (ripple - ripple_z) * 2.6, 1.0));
		water_nrm = wn * 0.5 + 0.5;
		vec3 wcol = water_col * (0.85 + 0.5 * ripple);
		base = mix(base, wcol, water);
		emis = mix(emis, water_glow * smoothstep(0.60, 0.74, ripple), water);
	}
	// E1 shoreline: a light foam band where ground meets water, gently animated.
	float shore = (1.0 - smoothstep(water_level + 0.008, water_level + 0.045, v_hn)) * (1.0 - water) * v_flat;
	if (shore > 0.001) {
		float foam = smoothstep(0.45, 0.75, fbm(wpos.xz * 0.09 + vec2(TIME * 0.10, -TIME * 0.07)));
		base = mix(base, base * 1.35 + water_col * 0.4, shore * 0.35);
		emis += water_glow * foam * shore * 0.35;
	}
	// E1 crystalline sparkle (Crystal biome): rare shimmering glints on high open ground.
	if (sparkle > 0.001) {
		vec2 gcell = floor(wpos.xz / 9.0);
		float gl = step(0.986, hash12(gcell));
		float shim = 0.5 + 0.5 * sin(TIME * 2.6 + hash12(gcell + 7.0) * 6.28);
		emis += vec3(0.55, 0.75, 1.0) * gl * shim * sparkle
			* smoothstep(0.05, 0.25, v_hn - water_level) * v_flat * (1.0 - water);
	}

	// --- fog of war, three tiers ---
	// unknown: near-black, noisy dissolve frontier (the unknown absorbs light).
	// explored memory: you keep the map knowledge, but unwatched ground sinks into a dim,
	// desaturated dark — the ever-present threat. Claims/paths stay legible, just shadowed.
	// watched: soft light pools around anything with eyes (Commander/FOB/towers/garrisons/units).
	float e = revealed + (fbm(wpos.xz * 0.02 + vec2(31.0)) - 0.5) * 0.35;
	float explored = smoothstep(0.35, 0.62, e);
	float lit = smoothstep(0.30, 0.70, lit_raw + (fbm(wpos.xz * 0.025 + vec2(7.3)) - 0.5) * 0.30);

	float luma = dot(base, vec3(0.3333));
	vec3 memory_col = (mix(vec3(luma), base, 0.68) * 0.52) + fog_color * 0.24;
	vec3 seen = mix(memory_col, base, lit);
	vec3 fogged = fog_color * (0.75 + 0.5 * n);

	ALBEDO = mix(fogged, seen, explored);
	EMISSION = emis * explored * (0.20 + 0.80 * lit);   // creep glows faintly from memory, fully when watched
	// E1b: scanned normal/roughness detail on lit open ground (flat neutral elsewhere so
	// paths, creep, water and fog keep their readable, non-bumpy look).
	float close_detail = clamp(detail_strength * mix(0.45, 1.0, grid_fade), 0.0, 1.0);
	float nmix = gmix * (1.0 - water) * (1.0 - creep * 0.22) * explored * close_detail;
	vec3 final_nrm = mix(vec3(0.5, 0.5, 1.0), nrm_encoded, nmix);
	final_nrm = mix(final_nrm, water_nrm, water * explored);
	NORMAL_MAP = final_nrm;
	NORMAL_MAP_DEPTH = 1.15;
	float surface_rgh = mix(1.0, rgh, gmix * (1.0 - water));
	surface_rgh = mix(surface_rgh, surface_rgh * 0.65 + 0.22, creep);
	ROUGHNESS = mix(surface_rgh, 0.22, water);
	SPECULAR = mix(0.15, 0.48, water);
}
