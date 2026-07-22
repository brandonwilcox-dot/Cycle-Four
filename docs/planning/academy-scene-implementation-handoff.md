# D-3 — Academy Scene: Implementation-Design Handoff

> Opus design pass for the Academy / Pilgrimage opening. Covers scene
> structure, scenario fidelity, data format, sorting algorithm, faction
> handoff, and the transition to the main map. Written so a Sonnet pass can
> build it step by step against the live project (`D:\AI\Cycle Four`).
>
> Design source: `core/16_first-session-flow.md` Chapters 0–2,
> `core/13_pilgrimage-site.md`. Build state: `D:\AI\Cycle Four\CLAUDE.md`.

---

## 0. What this is

The Academy is the game's **opening sequence and faction front-end** — it
replaces `FactionSelectScreen` as the first thing a new player sees. Three
beats, ~9 minutes total (core/16 Chapters 0–1):

1. **Chapter 0 (0:00–0:03) — Arrival.** Pilgrimage from orbit, slow descent,
   central chamber, a single faction-less cadet beneath the celestial
   aperture. Five seconds of nothing, then one line: *"Before you are
   assigned, you will be observed."*
2. **Chapter 1 (0:03–0:12) — Sorting.** Three scenarios, ~60–90 s each. The
   game watches *which instinct the player acts on*. No scores, no wrong
   answers stated.
3. **Chapter 1 end / Chapter 2 start — Recommendation + handoff.** Three
   faction sigils light by instinct-match degree. The player accepts the
   recommendation, picks another faction, or declines. On commit: a 2-second
   faction-color wash across the Ancient stone, then the main map loads.

The Academy's **job is to sort, not to teach combat.** Combat teaching
happens afterward on the real map (Chapters 2–5). That distinction drives
the central decision in §2.

---

## 1. Prerequisite reality check

The queue lists D-3's prerequisite as "D-2 complete." That is a *narrative*
ordering, not a hard code dependency. D-3 can be built now:

- **Sub-path is not chosen in the Academy.** Per core/16, faction is chosen
  here; sub-path is a later identity beat (waves 9–10, D-2). The Academy
  hands off `faction + a default sub-path` and D-2 owns the real sub-path
  commit. So the Academy does not call into D-2 at all.
- **The only D-2 touchpoint** is the "unsorted" decline path, which nudges
  the Dreamer/heresy sub-path later. The Academy expresses this as a single
  `GameState.unsorted` bool that D-2 reads whenever it ships. No coupling.
- `MilestoneManager` is already registered in `project.godot` autoloads, so
  D-1 is at least scaffolded; irrelevant to the Academy regardless.

**Conclusion:** build D-3 independently. It needs nothing from D-1 or D-2.

---

## 2. Central decision — scenario fidelity

**Decision: the three scenarios are interactive instinct-vignettes driven by
cadet movement, not full combat sandboxes and not multiple-choice menus.**

The player controls the cadet (the existing gold Commander avatar) inside a
small, self-contained Academy tableau. Each scenario presents a situation and
**three response zones** on the floor. The player expresses their instinct by
*moving the cadet toward a zone* (or by waiting). The scenario logs which zone
was acted on and ends. Visuals are lightweight primitives (ColorRects /
`_draw`), matching the project's current placeholder-art fidelity. No real
economy, no real waves, no damage model.

### Why not the two alternatives

- **Full combat sandbox (rejected).** Reusing WorldMap + Units + Towers +
  EconomyManager + WaveManager to script three micro-encounters would couple
  the Academy to every gameplay system, triple the engineering of the actual
  tutorial for a one-time 9-minute sequence, and make the opening fragile to
  every future balance change. The Academy does not need a simulation — it
  needs the player's *choice*. Overkill.
- **Multiple-choice menu (rejected).** core/16 is explicit: the player must
  *experience these as events, not read them as lessons*; "the player acts on
  instinct." A list of buttons reads as a personality quiz and kills the
  wonder/unease the opening is built to produce. The Bloom recommendation
  line — *"You watched before you moved. We noticed."* — only lands if the
  game actually observed movement (and stillness). A menu cannot earn that
  line.

The vignette-via-movement captures exactly the signal the design needs (which
instinct), preserves "instinct through action," makes **waiting itself a data
point** (Bloom lean), is fully deterministic, and is decoupled from the game
stack. It is the right fidelity for v1.

> If the user wants richer scenarios later, the vignette is a clean base to
> layer light interactivity onto (a probe that actually moves, a node that
> visibly takes a hit) without changing the architecture below.

### The three scenarios (core/16 Chapter 1), mapped to movement

| # | Situation | Zone A (Architect) | Zone B (Bloom) | Zone C (Mesh) |
|---|---|---|---|---|
| 1 | Two probes close from opposite angles | Move to the **production chain** to defend the economic core | Move to the **territory edge** to hold the ground | Move to **intercept the weaker probe** (find the weak point) |
| 2 | Surplus resources mid-situation | Move to the **build pad** (raise the next tier / optimize) | Move to the **perimeter** (expand territory) | Move to the **launch point** (throw a probe at the incoming wave) |
| 3 | Ancient Ruins appear at the map edge | Move to **catalog** it from a marked survey spot (methodical) | **Stay still / observe** from a distance (do not approach) | Move to **scout/interface** the Ruins (probe the system) |

Scenario 3 is where *waiting* is the Bloom answer and the Ruins stay inert no
matter what (core/16: "The Ruins do not respond to any interaction"). A
timeout with no movement is a valid, Bloom-weighted resolution in every
scenario, but it is the *intended* Bloom answer specifically in #3.

---

## 3. Scene structure

A single new scene, `scenes/main/Academy.tscn`, script
`src/ui/Academy.gd` (it is a front-end controller; lives with UI-adjacent
controllers). It is **self-contained** — it does not touch WorldMap. Node
tree:

```
Academy            (Node2D, script Academy.gd)
├── Chamber        (Node2D — the Pilgrimage tableau, all placeholder art)
│   ├── Backdrop       (ColorRect, full-rect deep still-water color)
│   ├── RingWall       (Polygon2D / Line2D ring — the caldera rim)
│   ├── Floor          (Node2D with _draw — chamber floor + subsonic pulse)
│   ├── Mark           (Node2D with _draw — the three-circle trefoil stamp)
│   ├── Aperture       (ColorRect/Polygon2D — circular gap, dim light shaft)
│   └── ZoneLayer      (Node2D — holds the 3 response-zone markers per scenario)
├── Cadet          (instance of the Commander visual, or a trimmed CadetAvatar)
├── Camera         (Camera2D — drives the orbit→descent zoom)
├── TextLayer      (CanvasLayer)
│   └── Line           (Label, centered, fades in/out; no speaker UI)
└── SortingLayer   (CanvasLayer — shown only at the recommendation beat)
    ├── SigilRow       (HBoxContainer — 3 faction sigils + 1 hidden "blank")
    ├── RecommendLine  (Label, faction-voiced)
    └── Buttons        (Accept / Choose-other / Decline)
```

**Cadet:** reuse the Commander's gold 32×32 visual so the avatar reads as
"the same you" across the cut to the map. Either instance `Commander.tscn`
with movement-only behavior, or — cleaner — a small `CadetAvatar.gd` that
copies just the visual + click-to-move from `Commander.gd` without combat,
territory, fog, or rank. Recommend the trimmed avatar to avoid dragging
MapGrid/EconomyManager dependencies into the Academy.

**Camera descent (Chapter 0):** a `Camera2D` zoom tween from far (the "orbit"
read — chamber small, ring wall as a geological feature) to the chamber
interior over ~3 s, with `Backdrop` darkening as it descends. No 3D, no real
orbit; the zoom + fade sells it.

---

## 4. Boot & skip flow

The Academy slots in *ahead of* the current faction-select wiring with minimal
change to `Main.gd`.

- `Main.tscn`: replace `$UILayer/FactionSelectScreen` with an instance of
  `Academy.tscn` (or add Academy and delete the old screen). The Academy
  exposes the **same `selection_confirmed` signal** the old screen did, and
  calls `FactionManager.select_faction(faction, default_sub_path)` internally
  before emitting it. `Main._on_faction_confirmed → _start_game_world()` is
  reused verbatim.
- **Skip logic (returning players).** `Main._ready()` already short-circuits
  when `GameState.current_faction` is non-empty (prestige/save restore). Add a
  parallel `GameState.academy_completed` bool: the Academy plays only on a
  true first run (no saved faction *and* `academy_completed == false`). On
  Academy commit, set `academy_completed = true`. Prestige re-entry is the
  Collapse Ceremony's job (core/19), not the Academy's — out of scope here.

`Main.gd` diff is roughly: swap the `@onready` node reference and the
preload; everything downstream is unchanged because the Academy mimics the
old screen's contract.

---

## 5. Scenario data format

Data-driven so scenarios are tunable without code. New resource
`src/academy/AcademyScenario.gd`:

```gdscript
## AcademyScenario.gd — one Academy sorting scenario.
class_name AcademyScenario
extends Resource

@export var id           : StringName = &""
@export var prompt       : String     = ""        ## unattributed line shown on entry
@export var duration     : float      = 75.0      ## seconds before auto-timeout
@export var timeout_vote : StringName = &"bloom"  ## faction credited if player never acts

## Three response zones. Each: world offset in the chamber, a short label
## (shown faintly on approach, not as a button), and the faction it votes for.
## Zone = { "pos": Vector2, "label": String, "faction": StringName, "weight": float }
@export var zones : Array[Dictionary] = []
```

Three instances in `resources/academy/` (`scenario_1.tres` …
`scenario_3.tres`), authored from the §2 table. `weight` defaults to `1.0`;
left as a hook for partial-credit tuning later. `timeout_vote` is `&"bloom"`
for all three in v1 (waiting is the watcher's instinct).

`Academy.gd` runs the scenarios in sequence: show `prompt`, spawn three
`ZoneLayer` markers at `zones[i].pos`, start a `duration` timer; resolve when
the cadet enters a zone's radius **or** the timer expires (→ `timeout_vote`);
record the vote; clear; advance.

---

## 6. Sorting algorithm

Simple, legible, three votes total.

- Each scenario contributes **one vote** to the faction of the zone the cadet
  acted on (`weight` allows fractional/partial credit later; v1 uses 1.0).
- A timeout contributes one vote to `timeout_vote` (Bloom).
- After three scenarios, tally `votes := {architects, bloom, mesh}`.

**Sigil brightness** (core/16: "illuminated by instinct-match degree"): each
sigil's alpha/intensity = `votes[faction] / 3.0`. All three are always shown;
the strongest is the brightest. This makes the read visual, not numeric — the
player never sees a tally.

**Recommendation:** the faction with the highest vote count is highlighted as
the recommended path, with its faction-voiced line:

- Architects: *"Efficiency potential assessed. Path available."*
- Bloom: *"You watched before you moved. We noticed."*
- Mesh: *"You found the weak point first. Good."*

**Tie-break:** if two factions tie at the top, prefer the faction that won the
**most recent** scenario (instinct trends late). If still tied (e.g. all
three split 1/1/1), surface no single recommendation — light all three
equally and show a neutral line (*"Your instincts are not yet decided."*),
which naturally invites the decline path.

**Player choice (three outcomes):**
1. **Accept** → selected faction = recommendation.
2. **Choose other** → the player clicks any of the three sigils; selected
   faction = that one. No commentary (core/16: "No commentary from the game on
   their choice").
3. **Decline** → a fourth blank sigil appears with *"The unsorted cadets
   remember things they were never taught."* The player still must pick a
   faction to actually play (there is no "unsorted" faction), **but**
   `GameState.unsorted = true` is set. v1 effect: the flag is recorded and
   read later by D-2 to nudge the Dreamer/heresy sub-path. Harder-start tuning
   is deferred (see §10).

---

## 7. Faction handoff & sub-path deferral

The Academy chooses **faction only**. But `FactionManager.select_faction()`
requires `(faction_id, sub_path)`. Resolution:

- The Academy passes a **default sub-path** per faction:
  `architects → "standard"`, `bloom → "purist"`, `mesh → "networked"`.
  (Map in an Academy const; do not hardcode at the call site.)
- This means the **old `FactionSelectScreen` sub-path picker is superseded.**
  Up-front sub-path choice contradicts core/16 (sub-path is the waves-9–10
  identity beat). Remove the sub-path picker from the player's path; the
  default carries until D-2's commit overrides it.
- **D-2 dependency to flag (not build here):** `FactionManager` currently has
  no `set_sub_path()` — only `select_faction` and `restore_faction`. D-2 must
  add `set_sub_path(id)` + re-emit so the Suppression Field unlock (which
  listens on `faction_selected`) fires. The Academy does not need it; just
  noting the seam so D-2 isn't surprised.

---

## 8. Transition to the main map (Chapter 2 open)

On faction commit, before handing off:

1. Hide `SortingLayer`.
2. **Faction-color wash:** a full-rect `ColorRect` over the chamber tweens
   from alpha 0 → ~0.6 in the faction color over ~1 s, holds briefly, total
   ~2 s (core/16: "the player's chosen faction color washes across the Ancient
   stone… The Pilgrimage site acknowledged the choice"). Faction colors:
   Architect amber `Color(1.00,0.55,0.18)`, Bloom green-gold
   `Color(0.45,0.80,0.30)`, Mesh blue `Color(0.30,0.65,1.00)` (match the
   ability/faction palette already in the build).
3. Set `GameState.academy_completed = true`, call
   `FactionManager.select_faction(faction, default_sub_path)`, emit
   `selection_confirmed`. `Main._start_game_world()` hides the Academy and
   shows the HUD over the already-loaded WorldMap.

No explanation fires. The site simply acknowledges the choice and the map
appears.

---

## 9. Visual build spec (placeholder-art fidelity)

Everything in the build today is ColorRects/Polygon2D/`_draw`. The Academy
matches that. The one detail worth care is **the Mark** — it pays off across
prestiges (core/13), so build it correctly even in placeholder form.

- **Backdrop:** `Color(0.06, 0.08, 0.10)` — "deep of still water," low albedo.
- **Ring wall:** a thick dark ring (`Line2D` circle or `Polygon2D` annulus),
  marginally lighter than the backdrop, no reflection. Reads as terrain.
- **Floor + subsonic pulse:** a large dim disc; a slow sine alpha pulse
  (period ~6 s, irregular is better but a steady slow pulse is fine for v1) to
  sell "felt, not heard."
- **Aperture:** a small circle at the top-center with a faint vertical light
  shaft (a low-alpha tapering ColorRect) down to the Mark.
- **The Mark (`_draw`):** three overlapping circles in a trefoil, each
  slightly smaller, not quite touching at center, beneath the aperture. Tint
  the three arcs differently to seed the substrate idea — one crystalline
  (Architect amber), one fibrous (Bloom green), one conductive (Mesh blue) —
  at low saturation so a first-run player reads "a symbol," not "the answer."
- **Cadet:** gold 32×32, white center pip (the existing Commander look).
- **Zone markers:** faint outlined discs on the floor; label fades in only as
  the cadet approaches (so they don't read as menu buttons).
- **Text line:** centered Label, generous tracking, fade in over ~0.8 s, hold,
  fade out. No speaker name, no box, no portrait.

---

## 10. New signals / state / files

### `GameState.gd` (new fields)
```gdscript
var academy_completed : bool = false   # first-run gate for the Academy
var unsorted          : bool = false   # decline path; read by D-2 sub-path nudge
```
Add both to `to_dict()` / `from_dict()` (the save round-trip already there).

### `EventBus.gd` (new signals — optional but clean)
```gdscript
signal academy_scenario_resolved(index: int, faction: StringName)  # telemetry/feel hooks
signal academy_completed(faction: StringName, unsorted: bool)      # fired on commit
```
These are not strictly required (the Academy is self-contained), but they let
D-4's faction-voiced one-liners and any future analytics hook the sorting
without reaching into the Academy. Wire if cheap; skip if it adds friction.

### Files to touch / create
| File | Change |
|---|---|
| `scenes/main/Academy.tscn` *(new)* | The scene tree in §3. |
| `src/ui/Academy.gd` *(new)* | Sequence controller: descent, run 3 scenarios, tally, recommend, transition. Exposes `signal selection_confirmed`. |
| `src/academy/AcademyScenario.gd` *(new)* | Resource in §5. |
| `src/academy/CadetAvatar.gd` *(new, recommended)* | Trimmed Commander: visual + click-to-move only. |
| `resources/academy/scenario_1..3.tres` *(new)* | Authored scenarios from §2. |
| `scenes/main/Main.tscn` | Swap `FactionSelectScreen` node → `Academy` instance. |
| `scenes/main/Main.gd` | Repoint `@onready faction_select` / preload to Academy; add `academy_completed` to the skip guard in `_ready()`. |
| `src/autoloads/GameState.gd` | Add the two fields + save round-trip. |
| `src/autoloads/EventBus.gd` | Add the two signals (if used). |
| `src/ui/FactionSelectScreen.gd/.tscn` | **Retire** (or keep as a debug fast-path behind a flag). Its sub-path picker is superseded; do not route players through it. |

---

## 11. Sonnet build order (each step MCP-verifiable, zero new errors)

1. **GameState fields + save round-trip.** Run; confirm no parse errors.
2. **`AcademyScenario` resource + three `.tres`.** Author from §2. Run.
3. **`CadetAvatar`** (visual + click-to-move). Drop into a throwaway test
   scene; verify it moves on click.
4. **`Academy.tscn` chamber tableau** (backdrop, ring, floor+pulse, aperture,
   Mark via `_draw`). Run the scene directly; eyeball the Mark and pulse.
5. **Chapter 0 descent + opening line.** Camera zoom tween + the single text
   line with fade. Run.
6. **Scenario runner.** Load the three resources, spawn zones, detect
   cadet-in-zone / timeout, record votes, advance. Log votes to debug output;
   verify all four resolutions (3 picks + 1 timeout) register correctly.
7. **Sorting + recommendation UI.** Sigil brightness from tally, faction line,
   Accept / Choose-other / Decline (sets `unsorted`).
8. **Transition.** Faction-color wash → `select_faction(faction, default)` →
   `academy_completed = true` → emit `selection_confirmed`.
9. **Wire into `Main`.** Swap the node, update the skip guard, retire
   `FactionSelectScreen` from the player path. Run the **full boot**: launch →
   Academy → sort → commit → map loads with HUD and the correct faction. Then
   relaunch with a saved faction → Academy is skipped. Both verified via MCP.

---

## 12. Deferred / out of scope (v1)

- **Prestige re-entry / Collapse Ceremony** (core/19) — the Academy is
  first-run only; re-entry is a separate track.
- **Unsorted "harder start"** beyond the `unsorted` flag + later Dreamer nudge
  — tuning deferred to D-2 / a balance pass.
- **Rich scenario interactivity** (moving probes that deal real damage, nodes
  that visibly degrade) — the vignette architecture supports adding this later
  without rework.
- **Final Pilgrimage art** (orbit cinematic, 3D chamber, the receptacles and
  dormant equipment of core/13) — placeholder primitives for v1; art pass
  later. Only the Mark is built "for keeps."
- **Audio** (the absorbed-echo silence, subsonic carrier) — no audio system in
  the build yet; the visual pulse stands in.
