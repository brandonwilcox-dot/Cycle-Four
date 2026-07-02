# Visual Supercharge Plan — from "grids and boxes" to the Codex

> Goal (user, 2026-07-01): "I want something that looks like the vision described
> in the Codex." Mechanics are solid; the 3D migration proved the world; now make
> it *feel* like Cycle Four. This is the successor to the 2D visual-juice track
> (2026-06-28), re-expressed for the 3D build.

---

## 1. The target, in canon terms

The Codex already specifies the art direction — treat these as fixed
(codex/04, codex/09, codex/11.3):

| Element | Canon visual identity |
|---|---|
| **Architects** | Cold precision, white-gold / amber, **crystalline lattice** substrate. Engineered, even, exact. |
| **Bloom** | Forest green, **bioluminescence**, biological fiber weave. Irregular, growing, alive. |
| **Mesh** | **Near-black + electric blue**, conductive mesh substrate. Circuitry, signal, glitch. |
| **Ancients / Ruins / Pilgrimage** | Low-albedo dark stone that *absorbs* light ("closer to the deep of still water than to black"), seamless joins, structures 15–20% too large. Their presence **desaturates** the world — color drains, sound flattens. |
| **Tone** | Melancholy not grimdark; awe + cold quiet dread; **quiet over loud**. The scariest thing is a system going quiet. |
| **The unsaid** | Visuals stage evidence, never captions. The Mark's three substrates are the key art of the IP. |

Design rules that bind this track (core/22 + core/15):
- **Readability is inviolable.** No effect may obscure damage-type color, HP
  bars, threat telegraphy. Cosmetics never touch gameplay (the Vfx-track rule).
- **Constant layout, faction texture.** The world can be faction-skinned; the
  information design cannot move.

## 2. Where we actually are (audit, 2026-07-01, branch feat/3d)

- **Renderer: `rendering_method="mobile"`** (project.godot:69) — this alone
  caps the ceiling. No volumetric fog, no SSAO/SSIL, weaker glow path.
- **Environment:** flat `BG_COLOR` background, one DirectionalLight3D, flat
  ambient (Battle3D.gd `_build_world`). No sky, no tonemapping choice, no glow,
  no color grading. This is why everything reads as programmer-art.
- **World:** MapGrid = MultiMesh of flat colored tiles (fog = tile tint).
  No height, no water, no biomes (backlog F1), paths read as carved corridors (F2).
- **Entities:** procedural primitives (Box/Cylinder/Torus) + StandardMaterial3D
  flat colors + emissive accents. The A1 stat-driven silhouette system is good
  design and carries over — it's the *materials and surroundings* that are flat.
- **VFX:** emissive tracer bars, CPUParticles3D sparks, expanding spheres. Works,
  but pre-glow they can't bloom, so they read as shapes not light.
- **Assets:** `assets/{audio,fonts,shaders,sprites}` are all empty (icon only).
  No art pipeline exists — by design (solo dev, text-only local vision model).

**Strategy:** stay **procedural + shader-driven** — Godot shaders, primitives,
particles, environment. That's where one engineer gets AAA-adjacent mood without
an asset pipeline. Optional CC0 kitbash (Kenney/Quaternius) is a Stage V6
decision, not a prerequisite.

## 3. Sequencing gate — merge first

Stage 6c is nearly done (remaining: Academy scripted tutorial, AbilityController
plane pass, revert nothing — main_scene already restored — then merge
`feat/3d` → main). **Recommendation: land the merge before the visual track**,
so visuals build on the real game path (Root → Title → Battle3D) and `main` is
3D. Exception: **V1 (environment) is safe to do on feat/3d now** — it's one
self-contained node/resource and doubles as motivation fuel.

---

## 4. The stages (each ≈ one session, MCP-verified, export + playtest checkpoint)

### V1 — Atmosphere: the environment overhaul  ← START HERE (biggest single win)
The one-session change that transforms every existing mesh and effect at once.
1. **Switch renderer to Forward+** (desktop .exe target; Mobile buys us nothing).
   ⚠ Watch the [P1][MONITOR] OS-hang — if GPU pressure is the culprit, Forward+
   could surface it; keep the Mobile fallback one setting away. Verify perf via
   playtest on GPC.
2. Extract environment setup from `Battle3D._build_world` into a saved
   `Environment` resource (`assets/environment/battle_env.tres`) + a
   `WorldEnvironment` scene both Battle3D and future screens share.
3. **Glow/bloom ON** — instantly upgrades every emissive already in the game:
   tracer bolts, damage-type cores, muzzle/death pulses, ring overlays, galaxy
   spheres. This is the single highest ROI checkbox in the project.
4. **Tonemap AgX (or ACES)** + subtle color grade toward the melancholy palette:
   cool desaturated shadows, warm-amber highlight bias ("warm light on a work
   surface").
5. **Sky:** procedural starfield shader (space TD — the board should sit in a
   galaxy, not a void color). Faint nebula gradient, slow parallax drift.
6. **Depth fog** (Forward+ volumetric if perf allows, else depth-range fog):
   distance haze sells scale at RTS pitch; also softens board edges.
7. Second light: cool fill/rim (moonlight blue) opposing the warm key —
   melancholy = warm/cool tension, not darkness.
8. SSAO (Forward+) at low intensity — grounds boxes onto tiles immediately.

### V2 — The ground: terrain + fog-of-war language (absorbs backlog F1/F2)
The board is 60×34 flat colored tiles; this stage makes it a *place*.
1. **Ground shader** (one ShaderMaterial on the MultiMesh or a ground plane
   beneath it): triplanar procedural noise (no textures needed), macro color
   variation, subtle cell-grid line that fades with camera distance —
   grid visible when planning, terrain when zoomed out.
2. **Height:** gentle vertex displacement for non-path terrain (paths stay
   flat = readable). Cliff/ridge tiles at map edges. (Real gameplay terrain =
   backlog F1 proper, later; this pass is visual relief only.)
3. **Water** tiles: animated shader (normal-scroll + fresnel + emissive
   sparkle), feeds F1 later.
4. **Fog of war as shader, not tile tint:** a fog texture sampled by the ground
   shader → soft dissolving edges, unexplored = darker + desaturated (canon:
   the unknown *absorbs light*). Sight radii become soft light pools.
5. **Claimed territory = faction creep** (the canon moment of this stage):
   claiming re-textures ground in the faction substrate — Architects: geometric
   crystalline tiling spreading in straight seams; Bloom: mossy growth +
   bioluminescent speckle; Mesh: near-black with electric-blue circuit traces
   that pulse toward the FOB. Territory reads at a glance AND states identity.

### V3 — Faction material language: the three substrates
One shared shader library (`assets/shaders/`), applied across Tower / Building /
Base / Unit / FriendlyUnit / Wall / Commander. Silhouettes (A1 system) stay;
materials carry the canon.
1. **Architect crystalline:** glass-adjacent (high specular, low roughness,
   slight rim), amber emissive edge seams, engineered precision. Damage →
   fractures (emission cracks), not grime.
2. **Bloom biological:** organic noise normal, deep green base, pulsing
   bioluminescent veins (sin-time emission), growth ticks visibly swell
   (already scale-up — add material brightening).
3. **Mesh conductive:** near-black metallic, electric-blue scrolling circuit
   emission; chain-linked towers pulse signal along the link direction (the
   4A endpoint mechanic made visible).
4. **Enemy variants** = same substrate shaders, hostile-tinted (readability
   rule: silhouette + HP bar + red accent, never ambiguous).
5. H5 (faction-distinct tower silhouettes) can ride along here or defer.

### V4 — Motion: make the world feel alive
3D successor of the juice pass. All cosmetic-only.
1. Upgrade `Vfx` internals to **GPUParticles3D** (keep API identical — callers
   untouched): impact sparks with light emission, faction-tinted death
   dissolves (shader alpha-noise dissolve, not sphere-pop).
2. **Construction:** structures *rise* — build progress drives a shader
   world-Y clip (hologram ghost above, solid below build line). Sells the
   Commander-engineer fantasy hard.
3. Tower **recoil** + barrel flash; Commander engineer beam gets particles
   drifting up the beam.
4. Unit locomotion: walk bob/sway per faction (Architect glide, Bloom lope,
   Mesh skitter) — 5 lines of transform sine each, huge life gain.
5. **Screen shake** (camera rig trauma system): base breach, base destroyed,
   Commander down. Subtle. Quiet over loud.
6. Hit feedback: brief emission flash via material param (no modulate conflict
   in 3D — hijack/pollen tints live on albedo, flash on emission).

### V5 — Set pieces: galaxy, Ancients, the dread
The canon-specific payoffs.
1. **Galaxy view beauty pass:** nebula backdrop, bloomed stars, owner-colored
   system glows, the Core visually *wrong* — darker than the space around it
   (light-absorbing, per canon). Slow drift. Awe.
2. **Ancient desaturation:** when an AncientWatcher observes / an Ancient event
   fires, a screen-space desaturation + slight vignette ramps in
   (Environment adjustment or post shader) and sound ducks. This is THE
   canon effect — "color drains, sound flattens." Cheap, devastating.
3. **Ruins/Ancient structures:** the low-albedo material — near-zero albedo,
   no specular catch, shadow-inward feel; slightly oversized proportions
   (15–20%) on their meshes.
4. Wave telegraphy: spawn-side horizon glow in the enemy faction's substrate
   color before a wave (readable threat + tone).

### V6 — DECISION POINT: asset adoption vs stay-procedural
After V1–V4, reassess with screenshots: if procedural still reads "clean but
austere," option to adopt CC0 mesh packs (Kenney space kit / Quaternius
sci-fi) re-materialed with the V3 substrate shaders so they stay on-canon.
Decide with the user; not assumed.

---

## 5. Verification per stage
- MCP `run_project` → zero new errors → `tools/export.ps1 -OnlyDebug` → playtest.
- **Perf gate:** frame time on GPC at max entities (late wave + full build-out),
  esp. after the Forward+ switch (V1.1) — the OS-hang monitor applies.
- **Readability gate:** after each stage, confirm damage-type colors, HP bars,
  selection rings, placement preview all still read instantly (core/22).

## 6. Open decisions for the user
1. **Merge `feat/3d` → main before or after V1?** (Rec: V1 on-branch now, then
   finish 6c + merge, then V2+ on main.)
2. **Forward+ renderer switch** — rec: yes (desktop target), monitor the hang.
3. **V6 asset packs** — defer until V4 screenshots exist.
