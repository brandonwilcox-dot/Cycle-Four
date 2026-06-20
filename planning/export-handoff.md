# Handoff: Build a standalone RELEASE .exe of Cycle Four

> Start-here doc for a fresh session. Goal: produce a non-debug Windows `.exe`
> on the user's desktop so the "first commander click after the tutorial gets
> eaten" issue can be tested in a clean (no-editor, release) context.

## STATUS — COMPLETE (2026-06-20)
Done. `4.6.1.stable` export templates installed, `export_presets.cfg` written
(Windows Desktop / x86_64 / release / embedded PCK / no console wrapper), and a
verified release build sits at `C:\Users\Brand\OneDrive\Desktop\Cycle Four.exe`
(100 MB, single self-contained file, window title `Cycle Four` with no "(DEBUG)").
Rebuild + gotchas captured in memory `reference-cycle-four-release-export`. The
steps below are retained as the reference record of how it was done.

## Why we're doing this
The "first world left-click after the Academy is eaten" bug was traced (heavy
investigation, 2026-06-17) to an **OS/window-level input drop**: the click never
reaches Godot's input pipeline at all (a temp `Main._input()` probe never saw it),
so it's swallowed before becoming a Godot event. **It is NOT a game-code bug** —
selection logic is correct (RMB, keys, and the 2nd click always work). Prime
suspect: window focus/re-activation, amplified by running **from the editor**
(two windows: editor + game) and by the MCP test harness bouncing focus.
Full detail: memory note `reference-cycle-four-input-scene-gotchas`.

The user's hypothesis: it's the debug-from-editor context, not the game. To test
that, we need a **release build that runs with no editor window**. The temporary
launcher `…\OneDrive\Desktop\Play Cycle Four (standalone).bat` runs the game with
`--path` but that is STILL a debug build (title shows "(DEBUG)"), because running
a project through the editor binary is always debug. Only an exported build is
release. Hence: install export templates + export.

## Hard facts / exact paths
- Godot editor binary: `D:\01 - game development software\godot_v4.6.1-stable_win64\godot_v4.6.1-stable_win64.exe`
- Editor version: **4.6.1.stable** (export templates MUST match this EXACTLY or export fails)
- Project: `D:\AI\Cycle Four\` (`project.godot` present)
- **Real desktop is OneDrive-redirected:** write outputs to `C:\Users\Brand\OneDrive\Desktop\`
  — NOT `C:\Users\Brand\Desktop\` (that's a hidden leftover the user can't see).
- Export templates dir (currently EMPTY — this is the blocker):
  `C:\Users\Brand\AppData\Roaming\Godot\export_templates\` — needs a `4.6.1.stable\` subfolder.
- No `export_presets.cfg` exists yet in the project.

## Steps
1. **Install export templates for 4.6.1.stable** (the blocker). Options:
   - Easiest: open the editor and use **Editor → Manage Export Templates → Download and Install**.
     ~1 GB download, needs internet. Driving this needs computer-use (request_access for
     `Godot_v4.6.1-stable_win64`). FLAG TO USER before a ~1 GB download.
   - OR download the matching `.tpz` (export templates archive) for 4.6.1.stable and extract
     its contents into `…\AppData\Roaming\Godot\export_templates\4.6.1.stable\`.
     Verify the version string matches the editor build exactly.
2. **Create a Windows Desktop export preset.** Either:
   - In editor: **Project → Export → Add… → Windows Desktop**, accept defaults, save
     (writes `export_presets.cfg` to the project), OR
   - Hand-write a minimal `export_presets.cfg` with a `Windows Desktop` preset.
3. **Export from the command line** (headless), e.g. run from the project dir or with `--path`:
   ```
   "D:\01 - game development software\godot_v4.6.1-stable_win64\godot_v4.6.1-stable_win64.exe" \
     --headless --path "D:\AI\Cycle Four" \
     --export-release "Windows Desktop" "C:\Users\Brand\OneDrive\Desktop\Cycle Four.exe"
   ```
   (Use `--export-debug` if only debug templates are available; but we WANT release so the
   title isn't "(DEBUG)" and `OS.is_debug_build()` is false.)
4. **Verify:** launch the produced `.exe`. Title bar should read "Cycle Four" with **no "(DEBUG)"**.
   Confirms a release build. Note: dev keys F1/F2/F3 (faction skip) and F4 (offline sim) are
   gated on `OS.is_debug_build()`, so they're DISABLED in release — the tester must play the
   full Academy (no F1 skip). Each full tutorial is ~4 min (durations 75/90/90).
5. **Hand back to the user** to play-test the first-click issue by hand on the release `.exe`,
   keeping the window focused (no alt-tab). Expected: if the click works reliably there, the
   bug was the debug/editor focus context, not the game.

## Gotchas / reminders
- Do NOT re-investigate the first-click bug as a game-code defect — it's OS/window-level
  (the event never reaches Godot). See the memory note.
- Write ALL desktop outputs to the OneDrive desktop path above.
- Template version must EXACTLY equal `4.6.1.stable`.
- A ~1 GB template download should be surfaced to the user first.
- Project is on `main`, clean working tree from this session's commander-select investigation
  (all diagnostics reverted). Real fixes that stay: entity click-through (MOUSE_FILTER_IGNORE)
  and the Shift-held commander move-path.
