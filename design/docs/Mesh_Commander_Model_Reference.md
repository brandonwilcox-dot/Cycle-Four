# Mesh Commander — 3D Model Reference

**Status: PLACEHOLDER IN-GAME, DIRECTION UNRESOLVED.** The current
`assets/models/units/mesh_commander.glb` is a rough procedural stand-in (internal codename
"Doc Ock" — a biped with four back tentacles, NOT a design target, just scratch geometry).
Unlike Bloom, Mesh doesn't even have a locked target silhouette yet — the user explicitly ruled
out the existing concept spread ("none of A/B/C fit") and this faction still needs its own
concept-art pass before generation. This doc collects everything settled so far plus the open
question to resolve first.

---

## 1. Faction identity (canon lens)

- **Culture (codex/05):** "the network is the self... it does not decide, it computes." When a
  node is lost, it reroutes. Everything is a system — hack it.
- **Substrate (codex/08):** conductive mesh — the legs/limbs literally look like a network
  diagram made ambulatory.
- **Visual identity (codex/11.3):** near-black + electric blue (canon), though the current
  in-project working scheme for this faction's ACU line has been locked to **red**, not blue —
  see the color note in section 6. Resolve this discrepancy before final art (it's the one
  open contradiction in the current documentation).
- **Gameplay identity:** the Commander is an engineer-leader (builds/repairs via a beam, claims
  ground by walking, mortal). For Mesh this should read as *hacking/rerouting*, not building —
  dexterous, many-limbed, opportunistic.
- **Style anchor:** Cybran (angular, spiky, insectoid, exposed circuitry) crossed with a
  tentacled tech-raider read. **Inspired-by, not a clone** — avoid a literal multi-arm/
  tentacle-harness humanoid silhouette that reads as a direct copyrighted-character likeness;
  build an original archetype around the same functional idea (many reaching limbs, hot glow at
  every joint).

## 2. Design direction (open — decide before generating art)

The user's own review of the first concept spread (Concepts A/B/C) explicitly rejected all
three for Mesh: *"none of A/B/C fit — needs its own concept direction (tentacled tech-raider /
Cybran vibe)."* That means, unlike Bloom (which got a clear correction to apply to an existing
direction), **Mesh needs a fresh concept pass, not a refinement of what exists.**

What IS settled as a starting brief:
- Angular, faceted, exposed-mechanism aesthetic (no smooth/organic surfaces at all — the
  opposite pole from Bloom).
- Multiple reaching limbs beyond the standard two arms — tentacles, extra manipulator arms, or
  both — is the core differentiator from the other two factions' cleaner biped silhouettes.
  This is Mesh's "the network is the self, everything is reach" identity made literal.
  (Reference: `planning/commander-mech-directions.md` M1 "The Weaver" concept — an
  eight-legged, many-jointed body where "the legs ARE the network diagram" — is a good canon
  touchstone even though that specific quadruped/spider execution was superseded by the
  bipedal-ACU direction. Carry the *idea* — many limbs, signal traveling joint-to-joint —
  forward into the new bipedal concept.)
- Hot glowing joints/circuitry as the signature detail (parallel to Bloom's breathing polyps and
  Architect's energy channels — Mesh's version is sharper-edged and pulses in sequence around
  the body like a traveling signal, not a slow breath).

## 3. Silhouette & stance

Angular and aggressive — faceted surfaces with bevels intentionally sharp (a prior pass that
tried softened bevels on this faction was reverted; keep edges hard). Forward-aggressive combat
stance. Distinguishing read vs. the other two: extra limbs beyond the arm pair — either
shoulder-mounted back tentacles (4 is the placeholder count) or additional smaller manipulator
arms, weaving/reaching rather than hanging still. Head reads as a sensor array or mandible-jaw
form rather than a face — Mesh is a system, not a creature or a knight.

## 4. Proportions & scale

- Commander envelope target: ~70–75 game units tall, matching Architects/Bloom so all three
  Commanders read as the same "class" on the field.
- Current Godot import scale for the placeholder biped: `scale = 21.0` (primitive biped ~3.5
  Blender units tall × 21 ≈ 73 game units). Keep any replacement normalized to a similar
  reference height, or update `AssetLoader.FACTION_COMMANDER_SCALE["mesh"]` to match the new
  mesh's actual size.
- Import facing correction: currently `yaw = -90°` (`AssetLoader.FACTION_COMMANDER_YAW["mesh"]`).
  Re-verify against whatever front axis the new model is authored with.
- The tentacles/extra limbs add visual mass beyond the core body — budget the base body itself
  on the leaner side (closer to Architect's proportions than Bloom's bulk) and let the limb count
  carry the "aggressive/busy" read, rather than making the torso itself heavy too — otherwise
  Mesh visually collides with Bloom's bulk instead of contrasting with it.

## 5. Part breakdown

| Part | Shape language | Notes |
|---|---|---|
| Head | Angular, devil-horn-like swept protrusions or a mandible/sensor-array read | Placeholder used big sharp swept horns; a sensor-mandible variant is also on-canon and worth exploring in the new concept pass |
| Chest | Faceted plate, no round "core gem" like the Architect — Mesh's tell should be a visible plate + circuit/tech-channel network rather than a single glowing heart | Placeholder used a solid colored chest plate with trim — good starting point |
| Shoulders | Angular wedge pauldrons | Sharp, not swept — contrast with the Architect's curved horn-fins |
| Arms | Forward cannon arms (matches the "both arms are weapons" language used across all three factions' ACUs) | Keep symmetric with the other factions' arm-cannon convention unless the new concept has a strong reason to diverge |
| Back / extra limbs | THE differentiator — multiple reaching tentacles or manipulator arms, weaving continuously, not static | This is the part that most needs fresh concept exploration; count, length, and whether they're rigid-segmented (mechanical) or flexible (bio-mechanical hybrid) are all open |
| Legs | Digitigrade or standard biped — angular, with exposed joint mechanisms (visible hydraulics/circuitry at knee/hip, per the original V6 spec) | Insectoid articulation (extra joint per leg) is on-brand if the silhouette supports it without reading cluttered |
| Feet | Sharp, clawed | Contrast with Architect's talon-pad (functional/stable) — Mesh's feet can be more purely aggressive/bladed |

## 6. Materials & color — RESOLVE BEFORE PRODUCTION

There are two conflicting color statements on file and this should be settled with the user
before generating final art:

- **Canon doc (codex/11.3, `V6_3D_Asset_Design.md`):** near-black metallic finish with
  hot-spot glows in **orange/red**, exposed circuitry, EMP/hacking aesthetic. This aligns with
  the original faction-color assignment used elsewhere in the project (Mesh = electric blue in
  the procedural `CommanderBodyRig.gd`/`SubstrateMaterials.gd` track, near-black + blue
  circuit-trace emission).
- **Active ACU backlog (`Commander_Visual_Backlog.md`, dated 2026-07-06 forward):** color scheme
  explicitly "LOCKED: ... Mesh red," with the placeholder built as "red chest plate + shoulder
  trim + red glow... red tech-channels, shoulder greeble vents, red knee/wrist nodes."

**Recommendation:** confirm with the user which is current intent before the new concept pass —
red/orange (matches the placeholder work already done and reads as more "hot/hacking/EMP") vs.
blue (matches the original codex 11.3 visual-identity doc and the rest of the game's Mesh
substrate/VFX, which use electric blue for Mesh circuit traces, hijack tint, and detector UI
elsewhere). Whichever is chosen, apply it consistently — the rest of the game's Mesh substrate
material (`SubstrateMaterials.gd`) currently uses blue, so a red Commander next to blue Mesh
towers/units would be an inconsistency worth deciding on purpose, not by accident.

- **Base:** near-black or dark gunmetal chassis regardless of glow-color choice — this part is
  NOT in conflict across sources.
- **Surface finish:** less polished than the Architect — Mesh should look assembled/exposed
  rather than seamless; visible panel lines, joints, and circuitry are a feature, not a flaw.
- **Glow behavior:** should read as a traveling signal — light pulsing joint-to-joint around the
  body in sequence, not a uniform glow or a slow breath (that's Bloom's territory). This
  "signal traveling the network" idea is cheap to animate and strongly on-canon; keep it
  regardless of which color is chosen.

## 7. Weapons & special features

- **Forward cannon arms** (paired with the other two factions' convention).
- **Multiple back tentacles or manipulator limbs** — the core differentiator; explore count/
  articulation in the new concept pass (placeholder used 4).
- **Nano-drones:** the placeholder pass added small angular hovering drones with glowing eyes,
  orbiting the Commander, as a construction/hacking-suite visual. Worth keeping as a concept —
  it's a strong "system, not a soldier" tell (the Commander doesn't build alone, it deploys
  sub-agents) — but note it's currently static/unanimated in-engine; if kept, plan for a simple
  orbit/bob animation.
- **EMP / stealth-field aura:** called out in the original V6 spec as a faction feature
  (barely-visible distortion effect) — a VFX/shader concern more than a modeling one, but worth
  flagging so the model leaves room for an aura emitter point.

## 8. Rig & animation requirements

- Biped-compatible base skeleton (spine, 2 arm chains, 2 leg chains) plus additional bone chains
  for however many back tentacles/limbs the final concept lands on — each as a simple FK chain
  (3–4 segments) is enough for a weaving/writhing idle, no inverse kinematics required.
- **Walk:** fast, insectoid, multi-jointed skitter — the most energetic gait of the three
  factions (Architect glides, Bloom lumbers, Mesh scurries).
- **Idle:** tentacles/limbs should stay in continuous subtle motion even at rest (a low-amplitude
  writhe/twitch) — Mesh should never look fully static the way the Architect's dead-still idle
  does; "always computing" is the read.
- Joint-node glow (per section 6) should be data-driven (an emissive material swept
  sequentially around the joints) rather than hand-keyframed — cheap and consistent with how
  the same "signal traveling the ring" effect is already implemented for Mesh elsewhere in the
  project (`CommanderBodyRig._process`, mesh branch).

## 9. Technical pipeline specs

- **Target pipeline (same as Architects' successful run):** resolve the color-direction question
  (section 6) first, then produce clean colored concept art (front + side orthographic, plain
  background) → Hyper3D Rodin image-to-3D → clean/trim in Blender → rig (nearest-bone rigid skin
  or proper smooth skin) → bake Walk + Idle → export `.glb` →
  `assets/models/units/mesh_commander.glb`.
  - Line-art/sketch inputs do not work for image-to-3D (confirmed failure on the Architect pass)
    — concept art must be shaded/colored.
  - Text-to-3D prompting alone is not reliable for pose/silhouette control — use it only for
    early mood-board exploration, not as the final-asset generator.
- **Poly budget:** target 5k–10k tris if hand-modeled/retopologized; the extra limbs will eat
  into this faster than the other two factions' cleaner silhouettes, so budget tentacle segment
  count accordingly.
- **Export format:** GLTF 2.0 (`.glb`), embedded armature.
- **File location:** replace `assets/models/units/mesh_commander.glb` in place (current file is
  the "Doc Ock" placeholder biped and should be treated as disposable scratch).
- **Godot wiring:** `AssetLoader.FACTION_COMMANDER_MODELS["mesh"]` already points at this path;
  re-verify `FACTION_COMMANDER_SCALE`/`YAW` for mesh once the new geometry lands.

## 10. Reference assets on file

- Style anchors: `design/reference/Cybran Example.jpg`, `Cybran Example 2.jpg`,
  `Mesh Base Reference.png`.
- Prior placeholder renders (useful for "what's already been tried," not a locked target):
  `design/renders/mesh_detail.png`, `design/renders/variants_mesh_red.png`.
- Callout diagram from the placeholder pass: `design/docs/Mesh ACU Callout Diagram.rtf`.
- Lineup context: `design/renders/commander_lineup.png`.
- Canon touchstone for the "many limbs, signal traveling the joints" idea (superseded execution,
  still useful for the concept brief): `planning/commander-mech-directions.md`, M1 "The Weaver."
- Handoff format guide for any new hand sketches: `design/docs/sketch_handoff_guide.md`.

## 11. Open items / next steps (in order)

1. **Resolve the red-vs-blue color question with the user** — this affects the concept art brief
   directly and should not be guessed.
2. Resolve limb count/type (tentacles vs. manipulator arms vs. both) and whether they're rigid
   or flexible — the one silhouette decision that's still genuinely open.
3. Produce clean colored concept art (front + side, plain background) reflecting the resolved
   direction.
4. Run image-to-3D, clean/trim, rig (reuse `rig_mesh.py` as a base), bake Walk + Idle.
5. Re-verify scale/yaw in-engine before calling it done.
