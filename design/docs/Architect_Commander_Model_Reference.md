# Architect Commander — 3D Model Reference

**Status: LOCKED / SHIPPED.** This is the reference build — the design that already made it
through the pipeline into `assets/models/units/architect_commander_hifi.glb`, rigged and
playtest-confirmed in-engine. Use this doc to keep any future revision on-model, or as the
template for finishing Bloom and Mesh to the same bar.

---

## 1. Faction identity (canon lens)

- **Culture (codex/05):** "disciplined technological refinement... patient in the way a long
  calculation is patient. They do not see themselves as conquerors, they see themselves as an
  expedition." Efficiency is virtue.
- **Substrate (codex/08):** crystalline lattice — engineered, polished, precise.
- **Visual identity (codex/11.3):** cold precision, white-gold/amber-and-blue palette, minimal
  seams.
- **Gameplay identity:** the Commander is an engineer-leader (builds/repairs via a beam, claims
  ground by walking, mortal). The model should read as an instrument, not a soldier.
- **Style anchor:** Seraphim (Supreme Commander: Forged Alliance) — sleek, curved, glowing,
  alien-tech. **Inspired-by, not a clone** — original archetype/vibe, no 1:1 Seraphim silhouette
  copying (IP risk on a shippable game).

## 2. Design direction (as built)

Bipedal ACU (Armored Command Unit), 2–3 story class. Robotic and streamlined — explicitly
*less* bulky than a brawler silhouette; narrow waist, tapered abdomen, elegant leg
articulation, forward-leaning readiness rather than a hunch. Nothing about it should read
"heavy" — Architects glide through problems.

## 3. Silhouette & stance

Tall, narrow-waisted biped, digitigrade (bird/raptor-style reversed-knee) legs ending in
clawed talon feet. Head is an angular helmet with a top spike, not a rounded dome. Shoulders
carry curved horn-like fins swept back (not flat plates — this was a deliberate revision).
Both arms are forward-mounted cannons (symmetric — no off-hand claw/fist). Stands
forward-leaning, weight balanced over the talons, energy channels visibly threading the frame.

## 4. Proportions & scale

- Commander envelope target: ~70–75 game units tall (matches the other two factions' Commander
  scale so all three read as the same "class" of unit on the battlefield).
- In the shipped pipeline: source mesh (Rodin-generated) is ~1.42 Blender units tall,
  normalized; imported at `scale = 51.0` → ~73 game units. If re-generating, normalize to the
  same ~1.42u reference height before import, or adjust the Godot-side scale factor
  (`AssetLoader.FACTION_COMMANDER_SCALE["architects"]`) to compensate.
- Import facing correction: model's authored front faces +Z; Godot forward is +X, so it's
  imported with `yaw = +90°` (`AssetLoader.FACTION_COMMANDER_YAW["architects"]`). Build any new
  model with a clear, single front-facing axis so this stays a one-number fix.
- Narrow waist / broad-ish shoulders / long legs — proportion the leg length generously; the
  digitigrade stance reads correctly only when the "thigh" segment is short and the "shin+foot"
  segment is long.

## 5. Part breakdown

| Part | Shape language | Notes |
|---|---|---|
| Head | Angular helmet, top spike, visor-slit eyes (glowing) | No rounded dome — the original sphere head was flagged for squaring off if it ever reads soft |
| Chest | Faceted hex-plate, round core in the center, 3 vent lines, side panels | The core is the visual "energy heart" — should read from the front silhouette |
| Torso/abdomen | Tapered, narrows toward the waist | Keeps the "elegant" read vs. a boxy brawler |
| Shoulders | Curved swept-back horn/fin, rooted directly into the pauldron (not floating) | Trailing wing-blade motif; these are the Seraphim tell |
| Arms | Both forward-mounted cannon arms, symmetric | No asymmetric claw/fist variant — locked after the round-2 tweak |
| Back | Clean — no visible pack/tentacles/greebles beyond channel lines | Keep the silhouette uncluttered; Architects are minimal-seam by design |
| Legs | Digitigrade (reversed knee), tapered | Two clean leg segments; avoid extra mechanical clutter at the joints |
| Feet | Clawed talon feet: flat sole pad, centered leg-post, dark up-swept front AND back claws (a symmetric "\\_\_\|\_\_/" silhouette from the side) | Enlarge rather than shrink — undersized feet read as "on stilts" and lose ground contact |

## 6. Materials & color

- **Base:** silver/white polished plate, with charcoal/dark-gunmetal panel recesses for
  contrast (this is what the winning concept art used, and what the Rodin generation carried
  through). If working from the earlier "near-black plate" note, treat that as an alternate
  darker variant, not the shipped look — the shipped Architect is light-based with dark accents,
  not dark-based with light accents.
- **Glow / emission:** cyan-blue energy, run as thin channel lines along torso, limbs, and the
  chest core; NOT a broad wash — Architects glow in thin engineered lines, never a diffuse haze.
  Treat glow density as "dense" (the user's locked variant pick over sparse/medium).
- **Faction color lock:** blue (cyan-leaning). This is the faction's identifying hue across all
  its structures/units — keep the Commander consistent with it.
- **Surface finish:** near-mirror polish read at RTS zoom — high specular, low roughness, subtle
  rim light. No matte or grimy surfaces; Architects are always clean.

## 7. Weapons & special features

- **Twin forward cannon arms** — the primary silhouette read; both arms identical, no
  off-hand tool. These double as the muzzle-fire origin points in-engine (two symmetric
  tracer sources, one per arm).
- No visible back-mounted weapon, pack, or drone swarm (that's Mesh's language) — Architects
  keep a clean back.
- Energy vents (3 lines on the chest) are a cosmetic tell, not a functional weapon slot.

## 8. Rig & animation requirements

- Biped skeleton: spine (allow slight flex), 2 shoulder/arm chains (cannon arms — these can be
  fairly rigid, Architects don't flail), 2 hip/leg chains with digitigrade knee bend, ankle
  articulation for the talon feet.
- **Idle:** dead-still, planted stance — no sway or bob (this was a deliberate fix; an idle sway
  read as unintentional jitter and was removed).
- **Walk:** smooth, mechanical, elegant — measured cadence, not a scurry. In-engine walk speed
  is scaled down (`WALK_SPEED_SCALE ≈ 0.75`) for a "lumbering colossus" cadence even though the
  silhouette is slender — don't compensate by animating a fast stride; let the engine-side speed
  scale carry that.
- Rigging technique used for the AI-generated mesh: nearest-bone rigid skinning (not voxel
  remesh — remeshing destroyed materials/detail). If hand-modeling a topologically clean mesh
  instead, standard smooth-skinned weights are preferable and will look better at the knee/hip
  than the rigid nearest-bone fallback did.

## 9. Technical pipeline specs

- **Export format:** GLTF 2.0 (`.glb`), embedded armature, animations NOT required to be baked
  in advance (Godot drives the skeleton), though the shipped model does carry baked Walk + Idle
  clips.
- **Poly budget:** original spec target was 5k–10k tris for a Commander. The shipped hi-fi mesh
  is ~23k tris (AI-generated, single fused shell) — accepted as a one-off tradeoff for fidelity;
  a hand-modeled replacement should aim back toward the original 5k–10k budget for a topologically
  clean, better-deforming result.
- **File location / naming:** `assets/models/units/architect_commander_hifi.glb` (live).
  `architect_commander_primitive.glb` and `architect_commander.glb` are the earlier
  primitive-biped backups, kept as a revert path.
- **Godot wiring:** `AssetLoader.FACTION_COMMANDER_MODELS["architects"]` points at the hifi
  path; `CommanderBodyRig._try_build_gltf()` loads it, scales/orients it per section 4 above,
  and looks for a "walk"/"idle" named AnimationPlayer clip (case-insensitive substring match).
  If no GLTF is found, it silently falls back to the older procedural hover-spire mech
  ("The Needle" — see `planning/commander-mech-directions.md`); that fallback is not the current
  target look and shouldn't be treated as a design reference anymore.
- **Known accepted defects:** minor mesh holes / open cannon ends / shell fragment-tearing at
  the joints under close zoom (artifact of the AI-generated, nearest-bone-rigged shell) — barely
  visible at RTS camera distance, not worth re-deriving unless the model is rebuilt from a clean
  topology.

## 10. Reference assets on file

- Style anchors: `design/reference/Seraphim example.jpg`, `Seraphim example 2.jpg`,
  `Aeon Example.jpg`, `Aeon Example 2.jpg`.
- User concept sketches (hand-drawn, the source for the final rebuild):
  `design/sketches/Architect ACU Sketch.jpg` (labeled front/side/arm/leg/torso/head views).
- Winning colored concept art (used for the actual image-to-3D generation):
  `design/sketches/sketch_front_bw_0.1.png`, `sketch_side_bw_0.1.png`.
- Generated + rigged output renders: `design/renders/rig8_rest.png`, `rig8_side.png`,
  `rig8_walkpose.png` (final, in-game state); `design/renders/commander_lineup.png` for a
  side-by-side with the other two factions.
- Part-callout diagram: `design/docs/Architects ACU Callout Diagram.rtf`,
  `design/docs/Architects_ACU_mech_parts_callout.png`.

## 11. Open items / not yet done

- Fine polish on joint tearing (needs a retopologized base mesh, not more rig tweaking).
- Per-faction walk cadence is currently a shared constant — if the Architect ever needs a
  visually distinct cadence from Bloom/Mesh beyond the speed-scale trick, that's engine work,
  not a model concern.
- IK foot-lock to remove minor foot slide during the walk cycle — a nice-to-have, not blocking.
