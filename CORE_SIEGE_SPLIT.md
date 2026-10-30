# Core Siege: how 3 sessions share one checkout

Victor 2026-10-28. Coop wave-defense mode (4 mechs defend a Reactor Core against 10 orange bot types
that walk 4 lanes). One branch, `feat/core-siege`, one working folder, three sessions at once.
Enemy art sheet: `docs/reference/robot-gladiator-silhouettes.webp`. Coop first, VS is design only.

## Who owns what

| Session | Name | Owns (only it edits these) |
|---|---|---|
| Sim lead | `core-siege` | `CORE_SIEGE_DESIGN.md`, `godot/src/siege.gd` (sim: waves, core, gates, bot AI, scrap), `godot/data/siege_*`, `godot/tests/siege_*`, and every shared file: `sim.gd`, `main.gd`, `hud.gd`, `i18n.gd`, `CLAUDE.md`, `progress.gd` |
| Arena art | `siege-arena` | `art/core_siege.blend`, `art/core_siege_build.py` (if kept outside the blend), `godot/assets/models/core_siege.glb`, `godot/src/siege_view.gd`, `godot/tests/siege_arena_test.gd` |
| Bot art | `siege-bots` | `art/bots.blend`, `godot/assets/models/bots.glb`, `godot/src/siege_bots.gd`, `godot/tests/siege_bots_test.gd` |

Need a change in a file you do not own? Do not edit it. Write the exact change you need as a short
note in your final report; `core-siege` applies it. Art sessions add NO player-facing text
(names and i18n are `core-siege`'s job).

## Git rules (one checkout, three writers)

- Stay on `feat/core-siege`. Never switch branches, `stash`, `reset`, `rebase`, `pull`, `merge` or
  `checkout <file>`. Never `git add -A` or `git add .`.
- Commit only your own paths: `git add <your paths>` then `git commit -m "..." -- <your paths>`.
- If git says the index is locked, wait 5 s and retry. Do not delete lock files unless nothing
  else is running.
- Do not push or open a PR. Victor decides.

## Tool rules (shared machine)

- **Godot windows:** run one at a time across all sessions (two can hang). Before opening a window:
  `Get-Process | Where-Object { $_.ProcessName -like 'Godot*' }`. If one runs, wait and retry.
  Headless runs (`--headless -s res://tests/...`) are always fine. Godot:
  `C:\Users\victo\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path games\mech-duel\godot`
  (the godot MCP cannot find Godot; do not use it).
- **Blender:** models are built headless, never in the live Blender, so sessions cannot clobber one
  open file: `C:\Users\victo\Tools\Blender\blender-5.2.3-windows-x64\blender.exe -b art\<x>.blend
  --python tools\blender_export.py -- --build --save`. Same pattern as `art/cores.blend`,
  `art/legs.blend`: a build script as a text block in the .blend, a Preview collection that is never
  exported. Do not use the Blender MCP to edit. See your work in Godot stills (`--shot`) or headless
  Blender renders.
- Parent rules (`C:\Users\victo\Proyectos\CLAUDE.md`) and this folder's `CLAUDE.md` apply:
  no explanatory code comments, original names only, sim stays pure, zero auto-aim for players.

## Shared contract (so the three pieces fit without talking)

Units are meters. Sim `(x, y)` maps to `Vector3(x, height, y)`. Arena centre is `(0, 0)`.
Numbers are "tune later"; `core-siege` owns the final ones in `CORE_SIEGE_DESIGN.md` and in a first
tiny commit `godot/src/siege_state.gd` (constants + a stub state) so the others can read them.

- Arena: square, half-size 80. Plaza radius 14 with the Core at the centre. Fortress ring radius 16
  with 4 gates. Lanes 0..3 = N, E, S, W, N is -y (up screen, W is up the screen's left, calm
  non-rotating camera). Lane width 10, ~60 long, from the border spawn gate (at 80) to the fortress
  gate (at 16). Gates at `(0,-16)`, `(16,0)`, `(0,16)`, `(-16,0)`. 2 chokepoints and 3 build pads per
  lane. 4 corner air entries. Side vents in lane walls (spider ambush).
- Core: Shield Petals (plasma column on a drum, 4 petals that break at 75/50/25/0 %, yellow HP floor ring).
- State the views read (`state.siege`):

```
siege = {
  tick, wave: {n, next_in, lanes_open: [bool x4]},
  core:  {x, y, hp, max, rings: [hp x4], repairing: bool},
  gates: [{lane, x, y, hp, max}],
  pads:  [{lane, x, y, module: ""}],
  enemies: [{id, kind, lane, x, y, face, hp, max, act, t, mk, neutral}],
  yards: [{quadrant, camps: [{id, tier, x, y, alive, respawn_in}], crates: [{x, y, progress, taken}]}],
  fund, wallets: [int per player], tokens: [int per player],
  garrison: {tier, hp, max, x, y, face, act, respawn_in},
  tiers: [{head, core, arms, legs, booster, left, right: 0..5} per player],
  recall: [{player, t, max, x, y}],
  shop_open: [bool per player],
}
```

`kind` is one of the 10 bot ids below, `face` is radians in the sim plane, `act` is one of
`walk, idle, attack, windup, roll, plant, hit, die, dormant, wake`, `t` ticks in that act, `mk` is
1..3. `neutral` = a scrapyard camp bot (sleeps as `dormant`, plays `wake` once when a player comes
close). All shapes come from `godot/src/siege_state.gd` (`stub()` builds a full fake state).

### Scrapyard (2026-10-28, Victor)

The 4 corner blocks become walkable junkyards (`QUADS` NE, SE, SW, NW; `yard_at(q, a, b)` maps
quadrant-local (a, b) to world). What changes in the arena, numbers in `siege_state.gd`:
- The block between two lanes is no longer solid. Each lane keeps a wall on both sides, `LANE_WALL`
  1.5 m thick (from 5 to 6.5 off the lane axis), from the ring road out to the border. Side vents
  stay in those walls (spiders pop out into the lane and into the yard).
- The ring road keeps its outer wall from `BLOCK` 26 to `YARD_IN` 27.5, with the 4 lane gaps plus
  one yard arch per quadrant on the 45° diagonal, `ARCH` 6 m wide (no door).
- Layout numbers agreed with `siege-arena` 2026-10-28 (both read `siege_state.gd` at runtime):
  lane walls from lateral 5 (`LANE_WALL` thick, no doors), an `ARCH` m arch per yard, the elite
  wreck (`WRECK`, solid), 4 camps (`CAMPS`, `tier` is the string small/medium/big/elite; the bots
  are existing kinds), 4 crates (`CRATES`), 9 cover pieces (`HEAPS`, solid circles that block
  shots and sight), 2 steam patches (`STEAM`, hide a mech like duel smoke: `Sim.hidden`), a crush
  plate and an EMP zone (`YARD_HAZARDS`, they hit bots too). Crowd and floodlights move to an
  outer stadium past the border; the air entries (`AIR`) are inside the yards.
- `yards[].raided` is 0..1 while a raid squad is in that yard (0.5 when it arrives, 1 when every
  camp is wiped), else 0. Crates are `{x, y, progress 0..1, taken}`.

### In-run upgrades, recall, radial shop (2026-10-28, Victor)

- `tiers[i][slot]` 0..5 = run-only upgrade tier of each of the 7 slots (`PART_SLOTS`) for player
  `i`, on top of its Salvage level. A view may show pips on the HUD; nothing in the arena reads it.
- `recall` lists players channelling a recall: `t` ticks done of `max` (3 s), at (x, y). When it
  completes they appear at their plaza spot. Art: a beam/charge effect while it runs.
- `shop_open[i]` is true while player `i` holds the radial shop open (the sim keeps running).
- `BAY` (x -8, y 8, facing the core) is where the parts-bay prop stands in the plaza (`siege-arena`).
  Buying works anywhere in the plaza; the bay is the visual anchor.
- The radial widget is `godot/src/radial.gd` (owned by `siege-bots`). It takes entries
  `{id, label_key, cost, enabled, sub, note}` and returns the picked `id`; `core-siege` builds the
  entries (`Siege.menu`) and the buy logic.

### Garrison (2026-10-28, Victor)

One allied defender for the core, built from player parts (`Mech.build` + `SETS`, no new model).
`GARRISON_DOCK` is its dock in the plaza (x 0, y 8, pad r 2.5, facing south). `garrison.tier` 0 = not
built, 1..5 = bought tiers; `act` uses the mech acts (`idle`, `walk`, `attack`, `die`, `dock`).


## Bot models (`bots.glb`)

One top-level object per bot id, origin at the ground centre, +X forward, materials `body` (orange),
`trim` (grey), `joint` (dark), `glow` (blue eyes). Style: the sheet, same cube-head-with-spike,
chibi blocky language as the player mechs (`art/light.blend`, `heads.blend`). Moving parts, pivot
at their joint: `<id>_leg1..N` swing while walking, `<id>_spin` spins, `<id>_turret` yaws to aim.
Never name a part `*_wheel` (Godot imports it as `VehicleWheel3D`).

| id | Bot | Role | Approx height (m) | T | D | Cost |
|---|---|---|---|---|---|---|
| `scout` | Light Scout | fast flanker | 1.8 | 1 | 3 | 1 |
| `swarm` | Swarm Bot (one cube; the sim spawns clusters) | distraction, self-destruct | 0.7 | 1 | 4 | 2 |
| `spider` | Spider Bot | ambusher, low | 1.3 | 2 | 4 | 2 |
| `flyer` | Flying Bot | harasser, hovers at y 3 | 1.8 | 2 | 5 | 3 |
| `turret` | Turret Bot | plants and shoots | 2.4 | 4 | 5 | 4 |
| `walker` | Quad Walker | bruiser, 4 legs | 2.8 | 5 | 5 | 5 |
| `tripod` | Tripod | sniper, 3 legs | 4.2 | 3 | 7 | 5 |
| `quadheavy` | Quad Heavy | artillery, missile pods | 4.0 | 7 | 8 | 8 |
| `heavy` | Heavy Mech | tank, big cannon | 4.6 | 9 | 7 | 9 |
| `jugg` | Juggernaut | rolling ram, ball form | 3.2 | 8 (10 rolling) | 8 | 9 |

T = toughness, D = difficulty (1-10), cost = wave budget points. Mk 2 / Mk 3 variants are a material
swap and small add-ons (later; `core-siege` decides).

## Standalone look flags (so art sessions do not wait for the sim)

Each art session adds a flag that shows its work from a fake state, no sim needed:
`--siege-arena` (arena + core + gates, `--rings=<0..4>` to show broken rings) and
`--siege-bots` (all 10 bots in a row, `--bot=<id>` close up, `--act=<act>`), both with `--shot=<abs>.png`.
Retained evidence goes in `production/qa/evidence/`. A parse check is not a run: launch it and look.

## Done, per step

The thing runs in Godot and you looked at it, headless tests pass (existing ones too),
evidence is saved, you committed only your paths. Report in a fixed shape: status, commit SHA,
tests, files, one line of residual.
