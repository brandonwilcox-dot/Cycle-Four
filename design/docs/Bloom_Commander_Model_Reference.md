# Bloom Commander — 3D Model Reference

**Status: PLACEHOLDER IN-GAME.** The current `assets/models/units/bloom_commander.glb` is a
rough procedural stand-in (internal codename "Groot" — a woody biped, NOT a design target, just
scratch geometry that happened to resemble it). It has not been through the concept-art →
Rodin image-to-3D → rig pipeline that finished the Architect. This doc is the brief for that
next pass.

---

## 1. Faction identity (canon lens)

- **Culture (codex/05):** "a living tide... it does not conquer territory, it *becomes*
  territory." Life spreads. Adapt or die. Fragile when young, nearly unkillable when mature.
- **Substrate (codex/08):** biological fiber weave — alive, matte, not engineered.
- **Visual identity (codex/11.3):** forest green + bioluminescence.
- **Gameplay identity:** the Commander is an engineer-leader (builds/repairs via a beam, claims
  ground by walking, mortal). For Bloom this should read as *cultivating*, not constructing.
- **Style anchor:** Aeon (hover-tech elegance) crossed with biological growth — smooth chassis
  overgrown with organic material. **Inspired-by, not a clone.**

## 2. Design direction (locked 2026-07-08, current target)

**This is the most important correction to internalize:** Bloom is a **mech piloted/grown by
the colony, with biological influence — not a pure creature.** Earlier internal exploration
leaned all the way into "hulking bark giant" (the "Groot" placeholder); the user's own
concept-spread review course-corrected this:

- Take the **aggressive insect styling** from Concept C (claws, horns, aggressive stance) and
  the **mass/bulk** of Concept B, but keep it legible as a **robot with biological overlay** —
  armor plating with organic material growing over/through it, not an all-organic body.
- This is a genuine design decision, not just flavor text: silhouette-read should say "machine
  wearing a living skin," and a viewer should be able to point at where the metal frame is and
  where the biology has taken over it.

## 3. Silhouette & stance

Wide, hulking, aggressive stance — more mass than the Architect, built low and heavy rather
than tall and slender. Claws and horn-like protrusions read as weapons/threat display, not
purely decorative growth. The head/face should be carved into the mass (no separate "helmet" —
the growth *is* the head), with the eyes as the clearest tell: illuminated, sap-green,
glowing from within the mass. Silhouette should be readable at a glance as "the aggressive,
overgrown one" next to the sleek Architect and the angular Mesh.

**What to keep from the earlier "Groot" placeholder, and what to change:** keep the idea of a
continuous, non-humanoid-smooth head mass (a carved face rather than a masked/plated one) and
the illuminated sap-green eyes — those read well. Change the "hulking bark giant with a flat
tree-stump crown" framing toward something that reads as armor-with-growth rather than pure
wood/bark — bring back visible mechanical structure (joints, plating, a chassis) under/through
the organic overlay so it doesn't collapse into a nature-spirit look.

## 4. Proportions & scale

- Commander envelope target: ~70–75 game units tall, matching Architects/Mesh so all three
  Commanders read as the same "class" on the field. Bloom should look *wider/heavier* at that
  same height class, not taller.
- Current Godot import scale for the placeholder biped: `scale = 21.0` (primitive biped ~3.5
  Blender units tall × 21 ≈ 73 game units). Keep new geometry normalized to roughly the same
  reference height so this scale factor stays valid — or adjust
  `AssetLoader.FACTION_COMMANDER_SCALE["bloom"]` if the new model's native size differs.
  Preserve the pipeline used for Architects: normalize the mesh to a known height before export.
- Import facing correction: currently `yaw = -90°` (`AssetLoader.FACTION_COMMANDER_YAW["bloom"]`)
  — the placeholder's authored front needed this correction to face Godot's +X forward. Author
  any replacement with one clear front axis and re-verify this number in-engine (F1/F3 dev-skip
  keys, or the Faction Preview screen).

## 5. Part breakdown

| Part | Shape language | Notes |
|---|---|---|
| Head/face | Carved into a continuous organic mass — no separate helmet | Illuminated sap-green eyes are the key readable feature; avoid a "mask" look |
| Torso/chest | Bulky, mass-forward — more volume than the Architect's tapered torso | This is where the biological-overlay-on-armor idea should read clearest: visible plate edges with growth breaching through the seams |
| Shoulders | Room for horn-like protrusions or heavy pauldrons | Aggressive stance cue — not swept/elegant like the Architect's fins, more like blunt/weighty growths |
| Arms | At least one arm should carry a visible weapon mount (bio-cannon/seed-launcher); claws are appropriate on the other | Claws from the Concept-C insect direction; keep at least one hand/limb clearly functional as the engineering "tool" limb |
| Back | Root-like or tendril structures, bud formations | Can be a cosmetic detail layer (bumps/pods) rather than full moving tentacles — keep the silhouette from getting too busy next to Mesh's tentacles |
| Legs | Heavier stance than Architect's digitigrade taper — read as planted, not sprinting | Root-system framing is appropriate (articulated segments), but should still resolve to a mechanical joint under the growth, not pure vine |
| Feet | Wide, planted base | Contrast with the Architect's narrow talon — Bloom should look rooted/stable, matching "becomes territory" |

## 6. Materials & color

- **Base:** armor plate as the structural material (metal/chassis, NOT all-bark), with
  biological growth — bark-like ridges, moss patches, root wrapping — breaching through seams
  and joints. The earlier placeholder skewed too far organic (continuous bark trunk with no
  visible machine underneath); pull that back toward "machine with a living skin."
- **Moss/growth texture:** clustered dot patches (this was the locked variant pick over a single
  blobby wash) across shoulders, torso creases, arm and leg joints, and the pelvis — growth
  clusters at the seams, not a uniform coat.
- **Glow / emission:** warm green bioluminescence — sap-green eyes, pulsing vein-like emission
  at growth points. Treat it as a slow "breathing" pulse (organic, unhurried), not a fast
  blink or a hard-edged tech glow like Mesh's.
- **Faction color lock:** green. Keep the eye/vein glow in the same green family as the rest of
  the faction's units and structures.
- **Surface finish:** matte on the organic portions (no specular shine — living tissue doesn't
  gleam), can carry some sheen/plate reflectivity where bare armor is still visible.

## 7. Weapons & special features

- **Bio-weapon:** a seed-launcher / spore-cannon read, mounted on one arm — should look grown
  rather than bolted on (a flowering or budding cannon housing is on-brand, per the broader
  faction unit language).
- **Claw/crusher limb:** the aggressive Concept-C read — sized to be a visible threat silhouette,
  not just a decorative pincer.
- Optional cosmetic detail: bud formations on the shell that could be a "breakable" visual detail
  layer later (not required for the base model).
- Avoid: floating drones (that's Mesh's language), fully detached tentacles as the primary
  read (also drifts toward Mesh) — Bloom's "extra limbs" should read as grown/rooted, attached,
  and heavy, not mechanical or hovering.

## 8. Rig & animation requirements

- Biped-compatible skeleton (can reuse the shared rig architecture already proven on the
  Architect — spine, 2 arm chains, 2 leg chains) works fine; the "root-system" leg framing can
  still be a standard 2–3 segment leg with a heavier/wider foot, it doesn't need extra bones
  unless the final concept calls for genuinely multi-segment tendril legs.
- **Walk:** flowing, organic, but still HEAVY — a lumbering plant/beast weight, not skittish.
  Should visibly contrast with the Architect's smooth glide and Mesh's fast twitch.
- **Idle:** a slow breathing motion (subtle scale pulse on the torso/carapace mass) reads well
  and is cheap to animate — carries the "alive" feeling even standing still.
- If keeping any secondary jointed elements (tendrils, root-legs), a light secondary-motion
  sway/lag on top of the base walk sells the organic feel without needing full physics.

## 9. Technical pipeline specs

- **Target pipeline (same as Architects' successful run):** user produces clean, COLORED
  concept art, front + side orthographic views, plain white background → Hyper3D Rodin
  image-to-3D → clean/trim the generated mesh in Blender → nearest-bone rigid skin (or proper
  smooth skin if working from clean topology) → bake Walk + Idle → export `.glb` →
  `assets/models/units/bloom_commander.glb`.
  - **Do NOT feed line-art/sketches directly to image-to-3D** — confirmed failure mode on the
    Architect pass (pencil lineart reads as a flat texture, not structure). Concept art must be
    shaded/colored.
  - **Do NOT rely on text-to-3D prompts for pose/silhouette control** — confirmed weak on the
    Architect pass (produced off-model results even with explicit "neutral T-pose" prompting).
    Text-to-3D is a concept/mood-board tool only, not a final-asset generator here.
- **Poly budget:** target 5k–10k tris if hand-modeled/retopologized; accept a higher AI-generated
  fused-mesh count (the Architect landed around ~23k) only if the fidelity gain is worth the
  rig-quality tradeoff.
- **Export format:** GLTF 2.0 (`.glb`), embedded armature.
- **File location:** replace `assets/models/units/bloom_commander.glb` in place once the new
  pass is ready (current file is the "Groot" placeholder biped and should be treated as
  disposable scratch, not a design reference).
- **Godot wiring:** `AssetLoader.FACTION_COMMANDER_MODELS["bloom"]` already points at this path;
  no code change needed to swap the file, just re-verify `FACTION_COMMANDER_SCALE`/`YAW` for
  bloom against the new mesh's actual dimensions and front axis once it lands.

## 10. Reference assets on file

- Style anchors: `design/reference/Bloom Example.jpg`, `Bloom Example 2.jpg`,
  `Bloom Base Reference.png`, plus `Aeon Example.jpg` / `Aeon Example 2.jpg` for the hover-tech
  chassis language underneath the growth.
- Prior placeholder renders (for what NOT to repeat — too pure-organic): `design/bloom_head.png`,
  `design/renders/bloom_detail.png`, `design/renders/variants_bloom_moss.png`.
- Lineup context: `design/renders/commander_lineup.png`.
- Handoff format guide for any new hand sketches: `design/docs/sketch_handoff_guide.md`
  (front+side turnaround, joint/pivot dots, material-zone labels, IP-safe archetype note).

## 11. Open items / next steps

1. Produce clean colored concept art (front + side, plain background) reflecting the
   "mech-with-biological-influence" direction in section 2 — this is the blocking step; nothing
   else in the pipeline can start without it.
2. Run image-to-3D, clean/trim the shell, rig (reuse the Architect's `rig_mesh.py` approach as a
   starting point), bake Walk + Idle.
3. Re-verify scale/yaw in-engine (Faction Preview screen or F3 dev-skip) before calling it done.
4. Decide how much of the "root-system legs" idea survives as actual geometry vs. a texture/
   material read — affects rig complexity.
