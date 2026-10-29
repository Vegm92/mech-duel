# Mech Duel V1 release

## Scope (decided 2026-10-28)

V1 is one build (`MechDuel-v<version>-windows.zip`). It opens on a mode menu (Victor 2026-10-29: "chose game mode first"):

- **Duel**: you against an AI rival, first to 3 rounds, in the garage → fight → claim a part → garage loop. Garage (63 parts, 20 weapons, 12 sets), Salvage unlocks, the 12-rival ladder, kill cam, crowd, sound, keyboard + mouse and gamepad, English and Spanish.
- **Core Siege**: co-op wave defense with an AI ally (Victor 2026-10-28: "one version with the other mode too").
- **V1 waits for the new menu** (Victor 2026-10-29): step 1 (mode menu) is done; next are local players (up to 4 on one PC), Duel setup and Core Siege setup.
- Not in V1: online play, more modes, a settings screen (pause menu sliders and M/N/L keys cover sound and language).

## V1 changes

- First launch opens a **How to play** screen (goal, every control on keyboard and pad). Button in the garage to open it again.
- **Quit** button in the garage. Version shown bottom right (`application/config/version` in `godot/project.godot`).
- Dev keys (F freeze, C cameras, Tab, T, K, J) are off in exported builds (`OS.is_debug_build()`).
- **Difficulty: Easy / Normal / Hard**, a button next to FIGHT (pad: Back), saved in `user://loadout.cfg`, shown on the rival's HUD plate. Knobs per level in `bot.gd` `LEVELS`: aim error, prediction (`lead`), reaction, dodging, shielding (`block`), top speed (`move`), fire pauses, heat limit, strafe rhythm.
- Measured by `tests/difficulty_test.gd` (8 mirror matches vs the old bot, 2026-10-28): rival round wins Easy 7/30, Normal 12/33, Hard 22/32; old bot 18/32. Normal is gentler than the old bot, Hard is tougher.
- **Mode menu** (`menu.gd`): Duel / Core Siege / Quit. The garage gets BACK (Esc, pad B) instead of Quit, and no CORE SIEGE button. Evidence: `menu-*-2026-10-29.png`.
- Tests: `garage_parts_test` (menu → garage → match in both modes, help, Esc back), `difficulty_test`.

## Build

Needs Godot 4.7.2 at `C:\Users\victo\Tools\Godot\` with the 4.7.2 export templates installed.

```powershell
& "C:\Users\victo\Proyectos\Claude-Code-Game-Studios\games\mech-duel\tools\build_release.ps1"
```

It runs the 11 test suites (duel and siege), exports the build to `build\MechDuel-v<version>-windows\` (exe + `CREDITS.txt` + `licenses\`) and zips it. To bump the version, change `config/version` in `godot/project.godot` and the two version lines in `godot/export_presets.cfg`.

## Release checklist

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | Launches, garage, clear route into a fight | done | `production/qa/evidence/v1-zip-first-launch-help-2026-10-28.png` |
| 2 | Full loop: fight, win/lose, claim, back to garage, restart | done (automated) | `garage_parts_test`: match flow, win → claim, loss → no claim |
| 3 | Controls explained | done | How to play screen |
| 4 | Enemy AI + difficulty choice | done (automated), **not human-tested** | `difficulty_test`, `v1-difficulty-*-2026-10-28.png` |
| 5 | Visuals and sound | done (existing) | `v1-exe-match`, `v1-exe-killcam`; sound not checked by ear |
| 6 | No crashes in tests | done | 11 suites ALL PASSED, 2026-10-28 |
| 6b | Core Siege from the full exe: garage button, help, waves 2 and 8 | done (autopilot), **not human-tested** | `v1-full-*-2026-10-28.png` |
| 7 | UI at 16:9, 21:9, 4:3 | done | `v1-exe-ultrawide`, `v1-exe-4x3-*` |
| 8 | Reproducible build + version | **rebuild after the menu work** (last build below is pre-menu) | `tools/build_release.ps1`, v1.0.0, built from commit `c90378f`: duel zip SHA-256 `E1D0CBFA…756463AE`, full zip `F9CC79D8…C708CD2C` |
| 9 | Store page text + screenshots | done (draft) | `production/store/itch-page.md`, `production/store/screens/` |
| 10 | Licences, secrets | done | `CREDITS.txt`; no keys in repo, no network code |
| 11 | A human plays 2 full matches from the zip | **open (Victor)** | |
| 12 | Upload to itch.io | **open (Victor)** | |

## Known issues (accepted for V1)

- Locked part cards cut long names short ("Cue…").
- Exe has the default Godot icon in Explorer (`application/modify_resources=false`; needs rcedit).
- Exe is not code-signed: Windows SmartScreen will warn on first run ("More info → Run anyway").
- Sound mix is not checked by ear.
- The difficulty button only changes the Duel rival; Core Siege ignores it.
- Core Siege is still being tuned by its own session; the full build ships whatever `main` has at build time.
