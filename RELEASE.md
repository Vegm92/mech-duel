# Mech Duel V1 release

## Scope (decided 2026-10-28)

V1 ships **Duel**: you against an AI rival, first to 3 rounds, in the garage → fight → claim a part → garage loop.

- In: garage (63 parts, 20 weapons, 12 sets), Salvage unlocks, the 12-rival ladder, kill cam, crowd, sound, keyboard + mouse and gamepad, English and Spanish.
- Cut from V1: **Core Siege**. The button is hidden; `--siege` still turns it on for development. It is still being built and is not tested enough to ship.
- Not in V1: multiplayer, more modes, a settings screen (pause menu sliders and M/N/L keys cover sound and language).

## V1 changes

- First launch opens a **How to play** screen (goal, every control on keyboard and pad). Button in the garage to open it again.
- **Quit** button in the garage. Version shown bottom right (`application/config/version` in `godot/project.godot`).
- Dev keys (F freeze, C cameras, Tab, T, K, J) are off in exported builds (`OS.is_debug_build()`).
- **Difficulty: Easy / Normal / Hard**, a button next to FIGHT (pad: Back), saved in `user://loadout.cfg`, shown on the rival's HUD plate. Knobs per level in `bot.gd` `LEVELS`: aim error, prediction (`lead`), reaction, dodging, shielding (`block`), top speed (`move`), fire pauses, heat limit, strafe rhythm.
- Measured by `tests/difficulty_test.gd` (8 mirror matches vs the old bot, 2026-10-28): rival round wins Easy 7/30, Normal 12/33, Hard 22/32; old bot 18/32. Normal is gentler than the old bot, Hard is tougher.
- Tests: `garage_parts_test` help/siege test, `difficulty_test`.

## Build

Needs Godot 4.7.2 at `C:\Users\victo\Tools\Godot\` with the 4.7.2 export templates installed.

```powershell
& "C:\Users\victo\Proyectos\Claude-Code-Game-Studios\games\mech-duel\tools\build_release.ps1"
```

It runs the 7 duel test suites, exports `build\MechDuel-v<version>-windows\` (exe + `CREDITS.txt` + `licenses\`) and zips it. To bump the version, change `config/version` in `godot/project.godot` and the two version lines in `godot/export_presets.cfg`.

## Release checklist

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | Launches, garage, clear route into a fight | done | `production/qa/evidence/v1-zip-first-launch-help-2026-10-28.png` |
| 2 | Full loop: fight, win/lose, claim, back to garage, restart | done (automated) | `garage_parts_test`: match flow, win → claim, loss → no claim |
| 3 | Controls explained | done | How to play screen |
| 4 | Enemy AI + difficulty choice | done (automated), **not human-tested** | `difficulty_test`, `v1-difficulty-*-2026-10-28.png` |
| 5 | Visuals and sound | done (existing) | `v1-exe-match`, `v1-exe-killcam`; sound not checked by ear |
| 6 | No crashes in tests | done | 7 suites ALL PASSED, 2026-10-28 |
| 7 | UI at 16:9, 21:9, 4:3 | done | `v1-exe-ultrawide`, `v1-exe-4x3-*` |
| 8 | Reproducible build + version | done | `tools/build_release.ps1`, v1.0.0, zip SHA-256 `18EB310A…9C9F750D` |
| 9 | Store page text + screenshots | done (draft) | `production/store/itch-page.md`, `production/store/screens/` |
| 10 | Licences, secrets | done | `CREDITS.txt`; no keys in repo, no network code |
| 11 | A human plays 2 full matches from the zip | **open (Victor)** | |
| 12 | Upload to itch.io | **open (Victor)** | |

## Known issues (accepted for V1)

- Locked part cards cut long names short ("Cue…").
- Exe has the default Godot icon in Explorer (`application/modify_resources=false`; needs rcedit).
- Exe is not code-signed: Windows SmartScreen will warn on first run ("More info → Run anyway").
- Sound mix is not checked by ear.
