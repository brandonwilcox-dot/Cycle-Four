# NEVER_TOUCH.md — Guarded Code

> Claude Code: read this BEFORE writing any code. If your change touches these, STOP.
> These are confirmed regressions that were fixed. Re-breaking them is the #1 source of
> wasted sessions.

---

## Hard stops

| What | Where | Why you must not touch it |
|---|---|---|
| `CadetAvatar._unhandled_input` | `src/academy/CadetAvatar.gd` | This IS the Academy player control (click-to-move). Removing it leaves the Academy unplayable. "Cadet drifts on click" is click-to-move working — it is NOT a bug. |
| `func _unhandled_input` in `Main`/`Battle` | `scenes/main/Battle.gd` | Must stay `_unhandled_input`, never `_input`. GUI controls consume first; map clicks fall through. Changing to `_input` breaks all button clicks. (Fixed: Track G, 2026-06-03) |
| `MOUSE_FILTER_IGNORE` on entity Control children | `Base.gd`, `Commander.gd`, `Unit.gd`, `FriendlyUnit.gd`, `Building.gd`, `Tower.gd`, `Convoy.gd` | World-space Control nodes steal mouse events. Every `_build_visual` loop sets children to MOUSE_FILTER_IGNORE. Any new world-space visual using Controls must do the same. |
| `SaveManager.DEV_CLEAR_SAVE` | `src/autoloads/SaveManager.gd` | Must be `false`. Setting to `true` wipes the save every launch, disabling the entire persistence system. |
| `WaveTableBuilder.enemy_of(player)` | `src/core/waves/WaveTableBuilder.gd` | Enemies must be the player's weak-matchup faction. Do not change this to spawn the player's own faction — that breaks the combat triangle. |
| Academy → Battle handoff via `queue_free()` | `Battle._start_game_world()` | Academy subtree must be `queue_free()`d (not hidden). `hide()` on a Node2D leaves CanvasLayer children visible and interactive, which eats all left-clicks. |
| `SceneManager.change_to` routing | `src/autoloads/SceneManager.gd` | All screen transitions go through SceneManager. Do not add direct `get_tree().change_scene_to_file()` calls. |

---

## Things that look like bugs but aren't

- **Commander selection ring appears without being clicked** — it's the `set_selected` call from Main. Normal.
- **Cadet moves slightly when clicking during Academy** — this is click-to-move working correctly.
- **"game_saving" warning in debug output** — benign; it's a signal with no receivers in the current scene context.
- **EventBus "signal never used" warnings** — known false positives from Godot's per-class signal analysis. Benign.
- **Integer division warnings** — intentional design decisions. Benign.

---

## Safe to change (common points of confusion)

- Wave difficulty numbers in `WaveTableBuilder.gd` — balance tuning, not guarded
- `TERRITORY_RATE_PER_CELL` in `EconomyManager.gd` — balance tuning
- Sphere radii constants in `Base.gd`, `Commander.gd` — balance tuning
- Any `.tres` resource file — data only, no logic
- Anything under `scenes/test/` — throwaway, not shipped
