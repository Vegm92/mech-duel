# Mech Duel (working title)

Top-down mech arena: 1v1, free-for-all (4 mechs) or 2v2, picked in the garage. LoL-style Q/W/E/R/Passive kits, every action aimed, no auto-attacks,
no auto-targeting. Mechs are built Exteel-style from five body parts (Head = R ultimate, Core =
passive, Arms, Legs = movement, Booster = Space dash) plus two hands that each hold any weapon
(left click = left hand, right click = right hand). Inspired by Medabots and Exteel.

Stage: playable prototype, you vs an AI rival (or training dummies), 71 parts and 18 sets in the garage. The spec is `COMBAT_DESIGN.md`.

## Stack and run

Godot 4.7, GDScript, lit low-poly 3D. The project lives in `godot/`; Blender sources for the
models are in `art/`. Godot is portable at `C:\Users\victo\Tools\Godot\` (not on PATH).
The original plain JavaScript version is a separate repo, `Vegm92/mech-duel-js` (split 2026-10-27);
the two no longer share code or tests.

```bash
G=/c/Users/victo/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe
$G --path godot                                                # play
$G --headless --path godot -s res://tests/sim_rules_test.gd     # sim tests (golden hash, determinism, FFA)
$G --headless --path godot -s res://tests/garage_parts_test.gd  # parts build alone; garage clicks; match -> garage flow; gamepad in match + garage
$G --headless --path godot -s res://tests/sound_test.gd        # every fx/weapon has a sound, banks load, synth + music bake, volume settings
$G --headless --path godot -s res://tests/hype_test.gd         # crowd hype and crowd sounds
$G --headless --path godot -s res://tests/killcam_test.gd      # kill cam: re-run lands on the same K.O., one smooth move, pillars, match flow, skip
$G --headless --path godot -s res://tests/progress_test.gd     # Salvage: owned parts, claims, levels, rival ladder, save file
$G --headless --path godot -s res://tests/siege_rules_test.gd  # Core Siege: own golden hash, waves, gates, core rings, repair, respawn
$G --path godot -- --siege --team=2 --wave=6                    # Core Siege (co-op wave defense), from wave 6
$G --path godot -- --replay=0 --seed=1                          # watch a kill cam right away (bots fight to the first K.O.)
```

Same in PowerShell (Victor runs commands there; works from any folder):

```powershell
$G = "C:\Users\victo\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
$R = "C:\Users\victo\Proyectos\Claude-Code-Game-Studios\games\mech-duel"
$P = "$R\godot"
& $G --path $P                                                  # play
& $G --path $P -- --sandbox=laser                               # effects sandbox (see FX_DESIGN.md)
& $G --path $P -- --sandbox=rivet --ult                         # R skill on repeat: the lance wind-up bar
& $G --headless --path $P -s res://tests/sim_rules_test.gd      # sim tests
& $G --headless --path $P -s res://tests/garage_parts_test.gd   # garage, parts, flow, gamepad tests
& $G --headless --path $P -s res://tests/sound_test.gd          # sound tests
& $G --headless --path $P -s res://tests/hype_test.gd           # crowd tests
& $G --headless --path $P -s res://tests/killcam_test.gd        # kill cam tests
& $G --headless --path $P -s res://tests/progress_test.gd       # Salvage tests
& $G --path $P -- --unlock-all                                  # dev mode: every part open, nothing saved
& $G --path $P -- --replay=0 --seed=1                           # watch a kill cam right away
& $G --path $P --resolution 1920x1080 -s "$R\tools\perf_probe.gd" -- --autopilot --seed=3   # speed: one PERF line after ~40 s
& $G --path $P -- --horde=50 --team=4 --tiers=5                # play Core Siege now: you + 3 AI mates, all upgrades at max, a live wave of 50 bots from their spawns (dev run, nothing saved)
& $G --path $P --resolution 1920x1080 -s "$R\tools\siege_stress.gd" -- --siege --autopilot --team=4 --seed=3   # siege load: 20 -> 200 enemies (+10 every 4 s, --from/--step/--top/--hold), one BOTS line per step with ms per part; --near=1 spawns them around you (on screen), --steps=1 = one tick per frame (no catch-up), --own=0 = the real main loop (only fps/render numbers), --hide=particles|bots|legs|bars|botshadow|sharemat|shadows|hud|sound|interp to isolate a cost
& $G --path $P --resolution 1920x1080 -s "$R\tools\arena_shot.gd" -- --autopilot --seed=3 --tick=700 "--out=$env:TEMP\arena.png"   # arena-only still (--top: whole arena)
```

## Godot (`godot/`)

- `godot/src/sim.gd` (every game rule) and `godot/src/bot.gd` (the AI rival) started as
  line-by-line ports of the JS version: dict keys stay camelCase, functions snake_case. Every `/`
  has a float operand (GDScript int / int truncates) and `%` takes ints. `Sim.hypot` and
  `Sim.jround` copy V8's `Math.hypot` and `Math.round`.
- `godot/tests/sim_rules_test.gd`: `GOLDEN` is the golden hash of a fixed bot duel (it depends on
  the platform's trig); an intentional sim change changes it and the failing test prints the new
  value. Also checks same seed → same hash and that an FFA bot match ends with a winner.
- View: `main.gd` (fixed 60 Hz `_physics_process` loop with physics interpolation on, input with
  latched taps, calm follow camera, never rotating), `view.gd` (arena, projectiles, fx), `mech.gd`
  (mechs from primitive meshes + shared mesh/material helpers), `hud.gd`, `i18n.gd` (en + es built
  as `Translation` objects in code; L toggles). Sim (x, y) maps to `Vector3(x, height, y)`. The view
  tags state dicts with `seen` (fx) and `_n` (pooled node); the sim ignores both.
- **Effects** follow `FX_DESIGN.md` ("punch, not glow", Victor 2026-10-26): `fx.gd` holds the
  recipes and their knobs (`Fx.HIT`), drawn with `Mech.flat` (unshaded, no emission, so effects
  never bloom). Hit-stop: `view.stop` asks main.gd to hold sim + view for N physics frames
  (`view.process_mode` disabled, camera shake keeps going). Core Siege has no hit-stop at all (Victor
  2026-10-29: freezes on every hit felt like lag with many enemies): `Siege.step` zeroes
  `state.hitstop` and `view.sync` zeroes `view.stop`. Crowds trim small effects there too: `view.fx_load`
  over `FX_BUDGET.max` skips wall pings, cuts hits on bots to sparks + star and hits on players to
  the star (`Fx.hit` `lite`); booms and the numbers stay (Victor 2026-10-29: 60 fps with 100 bots). Rebuilt in the crisp neon look
  (additive `Mech.flat(c, true)`, team colors): hit, muzzle, bolts, flame, missile, laser, lance,
  rail, tesla, boom (+ scorch marks in `view.marks`), mortar warning, parry, break, K.O. (+ slow-mo:
  `view.slow` → main.gd sets `Engine.time_scale`), land, dash (+ `Fx.ghost` afterimages), booster
  trails (`Fx.ribbon` for arc/flame/frost, `Fx.smoke` puffs for smoke), flamer cone
  (`view.cone`), shield ripple (`Fx.ripple`, from `view.guard` watching `act.absorbed`), hook
  cable + catch (`view.tether`, `Fx.hooked`), directional camera kick (`view.kick` → main.gd), and emp, heal / pickup, crush, blink, soak, magnet, ping, R charge (`Fx.emp` … `Fx.charge`), R release (`Fx.ult`, from the sim's `ult` event, on every R skill). Lasting R skills show an aura instead of tinting the body (`mech.gd` `AURA`: Overdrive, Berserk, Deflect zone, Mirror arc; Victor 2026-10-27), and their fields, wall and mines are `Mech.flat` (`Fx.FIELD`). Dashes: team afterimages every 3 ticks plus white speed lines (`Fx.lines`).
  Effect nodes are pooled (`Fx.take`/`Fx.park`). Smoke and fire puffs use noise shaders (`SMOKE_SHADER`, `FIRE_SHADER` in fx.gd). **Sandbox:** `$G --path godot -- --sandbox=<weapon>` (two pinned mechs, auto-fire, ←/→
  weapon, T auto-fire, G guard, K refill, J dash, `--block` held shield, `--hook` auto hook, `--ult` R skill on repeat; see `FX_DESIGN.md`). Evidence:
  `production/qa/evidence/godot-hit-fx-before-after-2026-10-26.png`,
  `godot-weapon-fx-before-after-2026-10-27.png`, `godot-moves-fx-before-after-2026-10-27.png`.
- **Kill cam** (Victor 2026-10-28: "new and different perspectives to the last kill, zooms and
  slowmotions. dramatic stuff like on TV"). `killcam.gd`, presentation only. It re-runs the last
  `KILLCAM.secs` (4 s) instead of recording frames: at a round's first fight tick `record`
  deep-copies the state into a ghost (nothing is shared between dicts yet, so the copy is exact; later
  a dash trail is shared by `state.trails` and `m.act.trail`, which `duplicate(true)` would split)
  and steps it `lag()` ticks behind the live one with the saved inputs. When the round's last K.O.
  (`finalKo`) has played `live` ticks, main.gd swaps the ghost in as `state` (`cut_to`: view reset,
  hype kept) and steps it on with the queued inputs; view, crowd and sfx see it like live. `film` is
  the director: **one smooth camera move, no cuts** (Victor 2026-10-28, after a first version that cut
  4 times between 8 shot kinds: "TOO MANY CAMERA CHANGES, KEEP IT SIMPLER AND SMOOTHER"). `SHOT` keys
  it to ticks from the K.O.: wide on both mechs (backing off to fit them, `fit`), glide in on the
  victim (`close`), ease into 0.2× slow motion (`slow`, `speed_at`), then pull back and rise
  (`after`) and speed up (`fast`), with a slow orbit (`spin`, on game time) all along. The eye and
  the look ease toward the move (`dolly`, `track`), so nothing jumps. `aim` picks the side and start
  angle (rolled per K.O., then ±25/50°, then the mirror side) that keeps pillars and tesla pylons out
  of the way at the start, the K.O. and the pull-back (`hidden` = `blocked` or `crowded`); if one
  still gets in the way, the camera floats up over it (`lift`). Slow motion: `Engine.time_scale` alone only shrinks delta (the physics
  loop stays at 60 Hz and the sim steps once per tick), so `direct` also sets
  `physics_ticks_per_second` to 60 × speed; physics interpolation keeps the mechs smooth and the
  camera moves in `_process` on real time (`get_global_transform_interpolated`, its interpolation
  off).
  HUD: only black bars, a blinking ● REPLAY, a progress line and a skip hint (`kcReplay`, `kcSkip`),
  plus the damage numbers; the aim reticle and the team ring and arrow hide (`view.replaying`;
  Victor 2026-10-28: "Hide them"). Enter, click or A skip after `grace` ticks (mashing doesn't); a rewind swoosh (`ui_rewind`) starts
  it. The end (or a skip) steps the live state through the rest of the K.O. phase, so the next round
  starts at once. Look flag: `--replay=<n>` fast-forwards an autopilot match to its first K.O. and
  plays the kill cam; add `--shot=<abs>.png` to save its n-th step. Evidence (one replay, 8 moments):
  `production/qa/evidence/godot-kill-cam-shots-2026-10-28.png`.
- Look check without a player: `$G --path godot -- --autopilot --seed=3 --shot=<abs>.png --at=700`
  saves that tick's frame and quits. `--lang=en|es` picks the language and `--pad` shows the pad
  captions (HUD stills). Add `--cam=1..4` for a close-up and `--hands=<left>,<right>`
  to pick your two weapons (e.g. `--hands=mortar,rivet`; use `--at=200`, later ticks often show a
  broken, drooping arm). `--head=<id>` picks your head (e.g. `--head=demon`), `--core=<id>` your
  core (e.g. `--core=titan`; pair it with `--hands=rivet,rivet` so no blade hides the chest),
  `--arms=<id>` your arms (pair it with `--hands=laser,ricochet` so both forearms show), `--legs=<id>`
  your legs, `--booster=<id>` your booster (pair it with `--cam=3`, the back view), `--set=<id>` a
  whole ready-made build (`SETS`; the part flags still override single parts). The rival is always
  one of the 18 `SETS`, picked by the seed (`s % SETS.size()`); you get `DEFAULT_LOADOUT` without `--set`.
  **Set bonus (Victor 2026-10-29, spec `SET_BONUS_DESIGN.md`, numbers in `COMBAT_DESIGN.md` §5):**
  wearing all 7 parts of a set (hands in either order, any Mk) turns on its `SET_BONUS` row: one
  existing stat × a small multiplier, keyed by body slot or weapon id. `Sim.set_of(lo)` finds the
  set, `Sim.rows_of(lo)` builds the part rows (level twist + bonus) that `make_mech`, siege
  `outfit` and the garage `sheet` all use; `max_armor` reads the bonus core armor; `m.set` holds the
  set id (no key without a set). Text: `sb_`/`sbd_` (bonus name / one line). Garage: each set card
  shows its bonus, MECH INFO shows `SET · <set> · <bonus>` when the build (or hover) completes one;
  HUD: `<set> SET` under the mech's plate. Balance: `tools/set_robin.gd` (`-s <abs path> --
  --seeds=1,2 --shard=i/N --only=<set,...>`), every set vs every set with bonuses off and on; RAW
  lines sum across shards. Evidence: `production/qa/evidence/set-bonus-*-2026-10-29.png`.
  **Sets (Victor 2026-10-26: "pick the parts that make sense for those roles"):** sniper uses the
  Rail core (rail-shot R + faster bolts for the needle), artillery the heavy Bulwark arms and the
  Coolant core (stasis holds them still while the mortar lands). Evidence:
  `production/qa/evidence/godot-sets-2026-10-26.png`.
  `--parts=<slot>` (a `Sim.CATALOG` key: head, core, arms, legs, booster, left) shows every part
  of that slot alone instead of a match (add `--shot=<abs>.png`).
- Parts alone: `Mech.build_part(slot, key, team)` builds one part (core = its chest size + add-on,
  arms = the right arm in the braced pose, weapon = held weapon). `part_view.gd` is a
  `TextureRect` showing its own `SubViewport` (own 3D world, sized to the real screen pixels so a
  maximized window stays sharp). `show_part` frames the part from its bounds; `show_mech` puts a
  whole mech on a glowing stand with fixed framing (`FRAME`), so hovering never zooms. Light is
  fixed to the camera, boosters are seen from behind. It renders once and stays a still picture
  until `turn(true)`.
- **Garage** (`garage.gd`, ported from the JS garage; Victor 2026-10-26: "the full ui/ux so we can
  customize our bot"). Same layout and rules: PARTS / WEAPONS / SETS main tabs, 8 sub tabs
  (`SLOTS`, Tab / Shift+Tab), a card per part with its 3D part alone (spins while hovered),
  series or type, the R skill / dash move / trail line and stat bars (`card_stats`, same
  formulas as JS); set cards show the whole build. Right side: the turntable tries on the
  hovered part, L/R weapon slots and the R skill slot jump to their tab, MECH INFO (`sheet`)
  shows ▲/▼ for the hovered change, the info box has the description and skill. Built from
  plain Controls in a fixed 1280×720 frame, centered; long names shrink to fit (`fit`). FIGHT /
  Enter emits `fight(loadout)`; main.gd starts the match with it. L toggles the language.
  `--garage[=<tab 0..7>]` opens it, `--hover=<id>` fakes a hover for screenshots (the real
  mouse over the window wins). Evidence: `production/qa/evidence/godot-garage-*-2026-10-26.png`
  (every tab in both languages: `godot-garage-all-tabs-{english,spanish}-2026-10-26.png`).
  **Garage with a pad:** cards take focus only while you use the pad (`use_pad`, from `_input`:
  any pad press turns it on, moving the mouse turns it off and drops the cursor), so for mouse
  users Enter stays FIGHT instead of pressing a clicked card. The card under the cursor previews
  like a hover (`focus_entered` → `set_hover`); D-pad / left stick move it, A equips, LB / RB =
  Shift+Tab / Tab, Start = FIGHT. The cursor starts on the equipped card (`point`, also after
  every tab switch); the first pad press shows it and moves it. The cursor is the white `focus`
  ring in `paint` (Godot hides it on mouse clicks by default). Evidence:
  `godot-garage-pad-2026-10-26.png`.
- **Local players** (Victor 2026-10-29: "manage controllers or players first"; same PC, one shared
  screen). `menu.gd` opens on the join screen: Enter / Space joins keyboard + mouse, A / Start joins a
  pad, Esc / B leaves, a joined device's Enter / A (or CONTINUE) goes on; `menu.players` = devices in
  join order (-1 = keyboard + mouse). main.gd `seats` (one per human, `seat()`: dev, tap, aim, reach,
  recent, pad; `set_players`): a single player is dev -2 and reads every device as before; with more,
  each reads only its device (`key`, `pad`, `stick`, `mouse` take the seat, `seat_of` routes taps).
  `aim`, `on_pad`, `reach` are seat 0's. Duel: 2 players = 1v1, 3-4 = FFA with bots filling to 4, all
  on P1's loadout, no ladder (`rival_key` ""); `brains[i]` drive every bot slot. Core Siege: team =
  max(`--team`, players). Camera (`group`, `DUEL_CAM`, `SIEGE_CAM.group`) frames every mech in a duel
  and every human in a siege. HUD: `hud.humans`, a panel per mech at `corner(i)` named P1-P4
  (`name_of`), scores in the panels with more than 2 teams, `win_text`; the skill bar only for one
  player. Extra aim rings: `view.sync(..., more)`. The radial shop belongs to the player who opened
  it (`shop_seat`, `radial.device`). Look flag: `--players=<n>` (keyboard + pads 0..n-2; with no
  `--at` the shot is the join screen). Evidence: `players-*-2026-10-29.png`.
- **Duel setup** (Victor 2026-10-29: "parts and bots selector for each player", rogue-like option for
  PvE). `menu.gd` page `duel` after Duel: format (`TEAMS`: 1v1, 2v2 = slots 0-1 vs 2-3, ffa), one slot
  per mech (`setup.slots`: `who` = player index or -1 = bot, `level`), Free match / Ladder (`pve`: all
  players on one team and a bot on another). main.gd: `duel` (the setup; empty = the old lineup for look
  checks), `lineup_of` (humans first, then bots, with team and level), `who` (seat → player), garage
  turns (`garage_turn`, `built`, `garage.who` / `garage.last`), per-player mechs (`lo_of`, `set_lo`,
  `loadout_p<n>` in `loadout.cfg`, `[setup] duel`) and saves (`profile`: P1 = `progress.cfg`, others
  `progress_p<n>.cfg`; `prog` = a shared all-open `free` in a free match). The ladder rival is the first
  bot (`rival_id`), drawn from P1's ladder; a win queues a claim per player (`settle`, `next_claim`,
  `claim.open(..., who)`). The garage has no difficulty button any more.
- **Core Siege setup** (Victor 2026-10-29: "change parameters, rounds, time and it should be rogue like,
  start from basics and grow ingame"). `menu.gd` page `siege` after Core Siege (`fit_siege`,
  `option_row`): waves to win (`GOALS` 10/20/30/0 = endless), break between waves (`RESTS` 15/25/40 s),
  AI allies (0..4 - players), start (`STARTS`: basic / garage). main.gd `siege_setup` (empty = look
  checks; saved as `[setup] siege`): `team_n` = players + allies; `siege.goal` (clearing that wave sets
  `won` and ends the run: `CORE HELD`) and `siege.rest` (replaces `RUN.build` / `buildLate`) are read
  with `sg.get`, so the siege `GOLDEN` holds. `basic()`: START RUN skips the garage, every player starts
  on `DEFAULT_LOADOUT` at level 1 and grows with the run's tiers and swaps; `after_match` (Enter, pad A,
  Quit) goes back to the setup. A garage start gives each player a garage turn and their own mech and
  owned parts (`prog(i)`). AI allies stay full `SETS`. Evidence: `siege-*-2026-10-29.png`.
- **Flow:** the game opens on the join screen, then the mode menu (`menu.gd`: Duel, Core Siege, Back;
  Victor 2026-10-29). A mode opens the garage in that mode (`garage.mode`; siege hides the difficulty
  button and FIGHT reads START SIEGE); BACK, Esc or pad B goes back to the menu. FIGHT saves your bot to
  `user://loadout.cfg` (`ConfigFile`, read back through `Sim.normalize`) and starts the match.
  Esc pauses with three buttons in hud.gd (Resume, Restart match, Quit to garage); Enter after
  the match goes back to the garage (main marks that Enter handled, or the garage would take it
  as FIGHT). Look checks (`--autopilot`, `--shot` with `--at`) skip the garage, start from
  `DEFAULT_LOADOUT` and never save. While the garage is open the main 3D view is off
  (`disable_3d`) and main.gd ignores input. Evidence: `godot-pause-menu-2026-10-26.png`,
  `godot-match-over-2026-10-26.png`.
- **Gamepad, in a match (Victor 2026-10-26 picked "dash on LB").** main.gd reads the pad next to
  keys and mouse, from `pad_id` (the last pad that sent anything). Left stick walks (analog, `DEAD`
  0.2 dead zone). Right stick aims at tilt × `REACH` (16 m) from your mech; an idle stick keeps that
  offset, so the aim follows you. Letting go uses the reading from `LOOKBACK` (6) ticks earlier, so
  the stick springing back to center doesn't pull a mortar shot in to your feet. Moving the mouse
  hands aim back to the mouse (`on_pad`). `PAD` / `TRIGGER`: LT left hand, RT right hand, LB dash,
  RB shield (hold), L3 hook, R3 R skill (Victor: "thumbs always on the joysticks"); Start does
  what Esc does. Taps latch like keys. While you aim with the pad the HUD slots show pad buttons
  (`hud.pad`, `cap*` strings). Pause menu: Resume has focus when it opens, D-pad / left stick
  move, A presses (main adds A to `ui_accept`; Godot 4.7 leaves it out). Garage with a pad: see
  Garage. Not built yet: rumble. Evidence:
  `godot-gamepad-hud-2026-10-26.png`, `godot-gamepad-pause-2026-10-26.png`.
- **Salvage** (Victor 2026-10-28, issue #12): parts are locked until you win them. `progress.gd`
  holds what you own (`user://progress.cfg`, separate from `loadout.cfg`): a level 1..3 per part
  (`Sim.MAX_LEVEL`; both hands share one weapon level), plus how often each rival was beaten.
  Lock logic lives in `garage.gd` and `main.gd`, never in the sim rules. Real play fights the
  `LADDER` (all 18 `SETS`, least-beaten first); rematches are the same set at Mk 2/3, bonus still on
  (every part but the starter Rookie Helm is in some set, so every part can be won; `progress_test`
  checks it; the old `BOSS` swaps are gone). While
  you fight, `main.track` collects the rival's broken parts (`break` fx) and K.O.s; on a match
  win `settle` opens `claim.gd` with `Progress.pool`: broken leg = legs, broken arm = arms + that
  hand's weapon, any K.O. = head, core, booster; a part you own is offered as a level up, a maxed
  one is not. The pick is auto-equipped, the win is saved, the garage opens. Levels: a loadout may
  carry `lv` (slot → level), `Sim.tuned` applies one small twist per slot (`TWIST`) once at
  `make_mech` into `m.rows`; level 1 adds no key, so the golden hash holds. Dev flags: `--unlock-all`
  (everything open, nothing saved, also on for `--autopilot`, `--shot` and `--sandbox`),
  `--progress=<abs path>` (use that file and lock parts even in look checks), `--claim` (open the
  claim screen for the first rival; look check). Not built: stakes, coop, PvP, the nemesis.
- **Core Siege** (Victor 2026-10-28; spec `CORE_SIEGE_DESIGN.md`, who edits what
  `CORE_SIEGE_SPLIT.md`): co-op wave defense, up to 4 mechs (you + `bot.gd` allies) hold a Reactor
  Core against grey enemy bots on 4 lanes. Core Siege on the menu, then START SIEGE in the garage, starts a run (`start(lo,
  true)`; `make_view` rebuilds the view when the mode changes), `--siege` starts look checks in it.
  View: `view.build(true)` keeps only marks and the reticle; `siege_view` (arena, core, gates,
  pads, crowd on the blocks, 4 floodlight towers whose spots join `view.towers`, crowd material
  shared as `view.crowd_mat` so `view.react` makes it cheer) and `siege_bots` are children of main.
  Camera (`SIEGE_CAM`): follows only you, dist 48 (wheel 36-64), focus clamped to ±62, never
  rotating. Look flags: `--top` (whole map, dist 205), `--core=<pct>` (start the core lower),
  `--shot-on=<fx kind>` (save the still when that fx fires, e.g. `ring`, `coreDown`),
  `--team=1..4`, `--wave=<n>` (dev: start at wave n). Sim: `siege.gd` (`create`, `step`, wave
  director `direct`/`plan`, bot AI `drive` (a bot re-picks its `target` every other tick, staggered by id; in between it keeps chasing `e.seek` while that mech stands; Victor 2026-10-29), core rings + repair + respawn in `settle`) on top of
  `sim.gd`; constants and the view contract in `siege_state.gd`; the views read only
  `state.siege` (`siege_view.gd` arena/core, `siege_bots.gd` bots; owned by the art sessions). Bots draw in
  batches (Victor 2026-10-29, for 60 fps with 100 on screen): each rig is a tree of plain `Node3D`
  joints that `pose` animates as before, and `draw` copies every joint into its part's shared
  `MultiMesh` slot (`batch`, `slot`); body tint + hit flash ride the instance color, eye color + glow
  the custom data (`BODY_SHADER`, `GLOW_SHADER`); `r.body` / `r.glow` are plain value dicts. Rigs off
  camera (`seen`, `VIEW_MARGIN`) skip posing and snap back when they come into view.
  Every bot also has a body in `state.mechs` (team 1, key `bot`, armor all in `head`, legs top
  ÷ `MOVE.jammed` because its leg pool is 0), so every player weapon, skill and dash hits it with no
  special case; dead bodies are recycled (`gone`). Arena shape lives in `state.geo` (walls,
  pillars, solids, `boxes` with optional `only` team + `hp` = gates, `rings` with lane `gaps`);
  `Sim.geo(state)` falls back to the duel arena, so the duel and its `GOLDEN` are untouched.
  Fortress has no auto-aim: only traps and player-aimed guns. Bots are data rows in `Siege.BOTS`
  (attack `bolt`, `bite`, `lunge`, `claw` + `gun`, `rail`, `salvo`, `cannon`, `ram`; flags `fly`,
  `vent`, `plant`, `hunt`, `keep`, `first`, `dodge`, `pack`; size `r` read by `Sim.rad`), Mk 1..3
  scale through `MK`. Bot shells reuse `state.lobs` (`shell_land` hurts gates and the core), the
  Tripod's rail is `Sim.line_attack` after a `sight` fx. `--spawn=<bot id>` puts 3 of one bot on
  the north lane and stops the waves (look check). Waves: `WAVES` (1-20), `LATE` (21-29, Mk 2),
  `LAST` (30), `ENDLESS`; a row has `lanes`, `pool`, `must`, `mk`, `boss`; `plan` fills
  `budget(n, team)` with `SQUADS`, spreads them over lanes, tanks first, `RANGED` 5 s later, and
  emits a `warn` fx per lane 8 s ahead. Scrap: kills pay 5 × cost, a wave cleared above 75% core
  pays +20%, G calls the wave early (+2 per second skipped). Build phase shop (`SHOP`, keys 1-8,
  `buy` in the input): gate repair, gate rebuild, core ring, mech repair, and pad modules
  (`MODULE`): barricade (a `boxes` entry bots must break), mine field (re-armed each wave), lane
  laser (fixed beam on a 3 s cycle, 1 s `laserWarn`), rail post (X fires a rail on your own aim).
  AI allies hold lane posts, fall back to the core when a bot gets inside, repair it between
  waves and buy only rings and gate fixes. HUD: wave plate, shop, warning markers over gates
  (edge arrow off screen), red arrows to gates or the core under attack. `--modules` builds one
  of each on the north lane. Progression: clearing wave 10, 20, 30 (`milestone` fx) opens the
  claim screen with a full set (`Progress.SIEGE_SPOILS`: tank, artillery, reflector); the best
  wave held is `progress.best` (`[siege] best` in `user://progress.cfg`). Endless from 31: `ENDLESS`
  row (Mk 3) and one more `MUTATORS` pick every 5 waves (`MUTATE`).
  **Scrapyard** (Victor 2026-10-28): the 4 corner blocks are walkable yards (`S.QUADS`, lane walls
  `LANE_WALL`, one `ARCH` per yard in the ring road's outer wall, a second `rings` entry with
  per-gap `half`). Each yard: 5 camps of neutral bots (team 2, `neutral`, `camp`, `home`; asleep
  as `dormant` with `sleep` on the body so they skip collision, `awake` wakes the whole camp,
  `YARD.leash` sends them home to heal), 3 crates (hold V, `use`), heaps (solid), steam
  (`geo.steam`, read by `Sim.hidden`), a crush plate and 2 EMP zones (`hazards`, hit bots too).
  Two currencies: `fund` (shared; lane kills 3 × cost, clean-wave bonus, call-early, donations)
  and `wallets`/`tokens` per player (camps pay the closest player, `camp_down`; crates).
  `WALLET` items (keys 9 0 - =, in the plaza): repair, upgrade (+1 level to your lowest part,
  `Sim.tuned` rows), reinforce (`toughen`, kept through respawns in `boost`), revive. Camps and
  crates `refill` each wave, the Elite every 5. From wave 15 a raid (`YARD.raid`) spawns at a
  yard's air corner and `raid_route`s camp to camp (`wipe`, no pay), out the arch, to a gate.
  AI ally 1 farms (`farm`, `waypoint` through gate gaps and arches); lane allies skip camp bots
  (`brain.lanes_only` in `Bot.pick`).
  **Garrison** (Victor 2026-10-28): one AI guardian, a real mech at index `siege.guard` (right
  after the players, `absent` until bought), tiers in `GARRISON` (parts + level, bought with the
  fund, shop key 8), `guard_input` = `bot.gd` leashed 14 m to the core, back to `GARRISON_DOCK`
  when hurt, R only from tier 4; it rebuilds free after 20 s × tier. `view.remake` rebuilds its
  model when the tier changes and adds a cyan halo. Tests check a tier-5 Garrison alone still
  loses at waves 15 and 25.
  **In-run upgrades** (Victor 2026-10-28, after playing to wave 6): `siege.tiers[i][slot]` 0..5 for
  the 7 slots, bought from the wallet in the plaza (`TIER.base` × tier²); `outfit` rebuilds
  `m.rows` from `Sim.tuned` + the tier effects (`TIER`) and scales `m.max` (plating tiers, reinforce
  `boost`), also on respawn. `swap:<slot>:<key>` puts an owned part in a slot (`SWAP` prices,
  `siege.owned[i]` from `progress`, `null` = all owned), `kit`/`coolant`/`surge`/`reinforce`/
  `revive` are instant (`WALLET`). Wallets start at `TIER.wallet` and every lane kill pays each
  player `TIER.share` × cost. Recall: hold B (pad X) 3 s, a hit breaks it (`recall`,
  `siege.recall`, 25 s cooldown). **Radial shop**: `radial.gd` (owned by `siege-bots`), opened by
  main.gd `open_shop` on the `siege_shop` action (physical Shift, pad Y) in the plaza only; entries
  from `hud.shop_menu`, a pick sets `tapped.buy`; while open, fire and aim are off and the sim
  keeps running; it closes when you leave the plaza. No punctuation keys are bound (a Spanish
  layout moves them). V / pad A = crates and donating. `siege.buys` counts purchases (arena buy
  pulse). AI teammates (`ai_wallet`, `next_buy`, `AI_SHOP`) walk in between waves to buy tiers in
  order hands → plating → engine → core, buy a kit when hurt, recall when hurt or rich.
  Balance tool: `tools/siege_balance.gd` (`-s <abs path> -- --from=<wave> --waves=<n> --team=<n>
  --tiers=<0..5> --guard=<0..5> --seeds=a,b`), one BALANCE line per seed. Look flags: `--shop`
  (opens the radial with scrap), `--farm` (your autopilot farms), `--guard=<tier>`.
  Bot HP follows the default Rivet (42 dmg since the duel balance pass): scout 1 hit, swarm 1,
  spider 2, walker 7 (table in `CORE_SIEGE_DESIGN.md` 8b2, `default_weapon_kills_*` checks it).
  **Director** (Victor 2026-10-28, spec `CORE_SIEGE_DIRECTOR.md`): `siege.gd` `sense` takes one
  pressure sample (0-100) per second of a live wave into `siege.director`; `score` turns each wave
  into W → strain → dial (from wave 4); `plan` applies the 5-wave `BEAT` (budget × mult × (1 ±
  15% dial), breather waves 4/9/14… are plain and add `DIRECTOR.rest` to the build phase) and picks
  a `TACTICS` row (probe, ambush, pincer, airdrop, feint, siege, hammer) that only reshapes the
  spawn queue: delayed groups get their own queued `warn` (`{"at", "fx"}` queue entries; bot
  entries carry `w` = their group's warn tick), and a `tactic` fx is the announcer call (`dir_*`
  text, `|` splits headline and sub line). No spawn within `DIRECTOR.near` (8 m) of a player: a
  vent flips side, else it waits `DIRECTOR.retry`. Waves 1-3 plan as if it were off.
  The game starts it off until the meter is tuned (Victor 2026-10-28: v0 made every bot team
  lose about a wave sooner); `--director=on` turns it on. `director.force = <tactic>` is the test hook. `bot.gd` `SKILL`
  (skilled / average / weak) merges into a brain; `tools/siege_balance.gd -- --director=both
  --skill=<k> --rows=1` prints a WAVE row per wave and one BALANCE line per run.
  Not built yet: netcode, VS (design only).
- Model viewing (dev keys, main.gd): F freezes the match (sim and view stop), C cycles `CAMS`
  (0 game, 1 front 3/4, 2 side, 3 back 3/4, 4 game angle close; HUD hidden in close-ups), Tab
  picks the mech, and while frozen drag orbits and the wheel zooms.
- Body is the **light frame** `godot/assets/models/light.glb` (Victor 2026-10-26: chibi blocky
  style, cube head + spike, visor eyes, grey pads, wheel-heel feet), made in Blender
  (`art/light.blend`; build script = text block `light_build.py`; re-run it, then export the
  Light collection as .glb). Objects: Head (pivot at the neck, 1.44), Chest_light /
  Chest_standard / Chest_heavy (incl. shoulder pads and the core socket), Hips,
  UpperArm_L/R (pivot at the shoulder) + Forearm_L/R (pivot at the elbow, incl. the fist), both modeled hanging down, Leg_L/R (pivot at the hip). The light `Head`,
  `UpperArm_*`, `Forearm_*` and `Leg_*` objects are no longer loaded: heads come from `heads.glb`,
  arms from `arms.glb`, legs from `legs.glb` (below).
  **Braced arm pose (Victor 2026-10-26: "readiness to tank the recoil", elbow bent, not stretched
  out):** `build` tilts the upper arm `ARM_UP` (0.2 rad) forward and puts the forearm level at
  `ELBOW`, fist at `FIST` (mech.gd consts, in the shoulder pivot's space).
  `Mech.add_part(parent, part, mats, file)` loads a mesh by object name from `<file>.glb` and swaps
  materials by name (body/trim/joint/gem/boost/core) for the team ones. The old chassis
  (`art/chassis.blend`, `chassis.glb`) is no longer loaded.
- Heads are `godot/assets/models/heads.glb` (one full head per head id, pivot at the neck, +X =
  face), made in Blender (`art/heads.blend`, build script = text block `heads_build.py`; re-run it,
  export the Heads collection as .glb; the Preview collection puts each head on a light body linked
  from `light.blend`, never exported). Light heads are built at 0.9×, heavy at 1.08×. Extra
  material: `heal` (Medic Dome cross). `build` loads one with `add_part(torso, lo.head, …, "heads")`.
- **Cores (Victor 2026-10-26: "3 sizes but reuse as much as possible").** The chest comes in 3
  sizes from one recipe, `chest(size)` in `light_build.py` (`SIZES`: width, depth, pad scale,
  shoulder z), picked by the core's `series`. Neck, waist and pad tops stay put on all 3, so every
  head, leg and shoulder gun fits unchanged; only the arm pivot moves out (`SHOULDER` in mech.gd,
  0.41 / 0.46 / 0.52; `streak` uses the same `shoulder`). Every chest has the same socket (frame +
  gem in material `core`) at `SOCKET` (0.271 × depth, y 1.22). Each core adds one small piece from
  `godot/assets/models/cores.glb` (`art/cores.blend`, build script = text block `cores_build.py`;
  re-run it, export the Cores collection; Preview = each core on its body, never exported), built
  in chest space (origin = chest origin, so `build` adds it at the torso origin), from shared bits
  (rod, disc, spike, bar, slats, dome, ring, hoop). Material `core` is painted `CORE_C[core]` (same
  colors as the JS version) so a core's color says which R skill it carries. Two parts spin
  (`WHIRL`: `flywheel_disc`, `gravity_ring`; separate objects built around their spin center).
  Evidence: `production/qa/evidence/godot-cores-2026-10-26.png`. At the game camera a core is a
  few pixels: chest width and glow color are what read there, the shapes read in close-ups.
- **Arms (Victor 2026-10-26: "the lower the armor the more skinny it has to look").** One
  `<id>_upper_L/R` (pivot at the shoulder) + `<id>_fore_L/R` (pivot at the elbow, incl. the fist)
  per arms id in `godot/assets/models/arms.glb` (`art/arms.blend`, build script = text block
  `arms_build.py`; re-run it, export the Arms collection; Preview = each arm set on a standard
  body, never exported). Thin → thick: wire (bare rod + cables, small orange cuff), reed (round
  tube in segments with dark rings), frame (the old light-frame arm), brace (+ bolted grey plate
  outside, wrist band), bulwark (chunky, grey top plate, flared orange guard outside), anvil (dark
  block, orange top plate, grey slab with studs outside). Shoulder, elbow and fist stay at the
  same spots on all 6 (`ELBOW`/`FIST` unchanged), so every weapon fits; extra armor only grows
  outward and on top (top = what the game camera sees when the forearm is level), never inward
  into the chest. Fists scale 0.85–1.3×, still inside every gauntlet. At the game camera held
  guns cover most of the arm; the difference reads in close-ups.
  Evidence: `production/qa/evidence/godot-arms-2026-10-26.png`.
- **Legs** are `godot/assets/models/legs.glb` (`art/legs.blend`, build script = text block
  `legs_build.py`; re-run it, export the Legs collection; Preview = each kind on a standard body,
  never exported). One shape per leg kind, made to match its dash: greaves (light-frame leg +
  calf thruster), hover (flared skirt on a glow ring), treads (two tank tracks), spider (4 thin
  splayed bug legs), wheels (2 big wheels), jets (slim legs, jet pods, glowing soles), stompers
  (huge legs, toed grey feet), skates (inline skate boots on a rail), quad (4 sturdy animal legs
  with paws, hips 0.64 apart front-to-back on a fixed strut frame `quad`; Victor 2026-10-26: they
  clipped into each other, so they're spread and `sync` swings them at 0.55× the usual stride),
  mono (one wheel in a fork). Objects are named `<kind>` (fixed), `<kind>_leg*` (swings
  at its pivot while walking) and `<kind>_tire*` (rolls); each object's position in the .glb is its
  pivot, in hips space. `build_legs` adds every object whose name is the kind or starts with
  `<kind>_` (sorted, so the 4-leg gait order is leg1..4), read through `Mech.models(file)` (mesh +
  position). Never name a part `*_wheel`: Godot's importer turns it into a `VehicleWheel3D`. Look
  flag: `--legs=<id>`. Evidence: `production/qa/evidence/godot-legs-2026-10-26.png`.
- **Boosters** are `godot/assets/models/boosters.glb` (`art/boosters.blend`, build script = text
  block `boosters_build.py`; re-run it, export the Boosters collection; Preview = each booster on a
  standard body, never exported). One object per booster id, origin = the middle of the chest's
  back (y in chest space, x 0 = the back face, -X = behind); `build` adds it at `-BACK[size]`
  (mech.gd: 0.279 / 0.313 / 0.349, the back face of each chest size). The chests no longer have
  their own back jets. The chest's back belongs to the booster: Furnace's two chimneys sit on the
  back inner corners of the shoulder pads instead (Victor 2026-10-26: they crowded the boosters). Size grows with dash distance: flicker (slim pack, one nozzle, two spark
  prongs), wisp (two swept fins with glowing trailing edges), thruster (dark pack, two nozzles),
  twin (wide pack, two big nozzles, two smoke stacks), comet (one big round engine in two glowing
  coil rings), rocket (two tall rockets with nose cones, nozzles down). Everything is drawn at
  `SCALE` (1.5) around `MOUNT` (y 1.2 on the back face; Victor 2026-10-26: "bigger so they look
  more dramatic"); tune that one knob, not the shapes. Glow parts use material
  `boost`, painted `BOOST_C[trail]` and brightened while dashing.
  Evidence: `production/qa/evidence/godot-boosters-2026-10-26.png`.
- **Arena props** (Victor 2026-10-27: "new looks only", same layout and rules) are
  `godot/assets/models/arena.glb` (`art/arena.blend`, build script = text block `arena_build.py`;
  built and exported headless so the open Blender file is never touched). Objects: `pillar`
  (radius 1, view scales x/z by the sim radius), `tesla` + `tesla_orb` (orb pulses via material
  `zap`), `crush_plate` + `crush_head` (block centered on the origin; their `hazard` surfaces
  take the per-crusher warn copy of the hazard shader), `heal_pad`, `pad`, `vent` (+X = into the
  arena), `wall` (a 4 m panel, arena face at z 0; `build_walls` tiles and stretches it per edge)
  and `wall_post`. `look.gd` `ARENA` maps the material names (steel, dark, trim, hazard, amber,
  zap, pad, heal, vent, strip). Restyled in visual overhaul M2: `hazard` is a shader (45° yellow
  and black stripes in world space), so model plain bands, never stripe geometry; the lights
  (`strip`, `pad`, `zap`, `vent`, `amber`) are `look.gd` `neon()`; the oil slicks have no mesh,
  the floor shader draws them. Evidence: `production/qa/evidence/godot-arena-{before,after,wide}-2026-10-27.png`,
  `visual-m2-*-2026-10-27.png`.
  **Stadium** (Victor 2026-10-27: "production ready", no gray box when the camera zooms out):
  `stadium` is the whole bowl in world space (added at the origin): a walkway, 3 tiers with seat
  rows, a riser LED board and a rail, one aisle with steps in the middle of each edge, a 7 m back
  wall with an LED ribbon and flood strip, a dark ribbed roof out to 26 m past the wall (the
  zoomed-out camera sees ~25 m past it) with a team-color rim, and a scoreboard on the north side.
  `tower` = 4 floodlight towers (no shadows). Side materials: `seat_a/b/n`, `led_a/b/n` (left =
  team 0, right = team 1, else neutral). The script copies the arena shape (`AW`, `AH`, `ACUT`,
  `WALLS`) from `sim.gd`, and `view.gd` `STAND` must match the script's `STAND` (fans stand on
  the tiers and skip the aisles). Outside the stadium is unshaded `Look.PAL.void`.
  Evidence: `godot-stadium-{left,bottom}-before-after-2026-10-27.png`, `godot-stadium-top-2026-10-27.png`.
  **Stadium lighting** (491b057, reworked in visual overhaul M1): four corner SpotLights follow
  the bots on an underdamped spring (`view.follow`; 2 per bot in 1v1, 1 each in FFA), soft and
  unshadowed, no haze; the key light is the only shadow caster. The floor shader (v2, visual
  overhaul M2) draws steel plates with soft bevels, grime, scuffs, hazard bands around pads,
  spawns and crushers, a dashed line 1 m inside the walls, chevrons in front of the spawns and
  the oil slicks; its arrays are sized to `sim.gd` (`docs/visual-architecture.md` Contracts).
  Knobs: `look.gd` `STAGE` and `FLOOR`. Evidence:
  `godot-stadium-lighting-before-after-2026-10-27.png`, `godot-stadium-follow-spots-2026-10-27.png`
  (before M1), `visual-m1-*-2026-10-27.png` (M1), `visual-m2-*-2026-10-27.png` (M2).
  **EMP zones** (Victor 2026-10-27: the fire vents became EMP zones, same spots and timing;
  the sim names stay `vents`/`HAZARDS`): 12 Legs + `HAZARDS.slow` ticks of Slow instead of Heat.
  Drawn with `EMP_SHADER` (additive crackle on a floor plane, `power` 0 = warning outline, 1 =
  live); a mech with Slow > 2 (EMP only, frost sets 2) gets the same crackle under it (`shocks`).
  **Pickups**: `item_<kind>` icons in `arena.glb` (repair wrench, shield, speed bolt, power
  burst, coolant snowflake, surge battery; material `icon` = item color, `dark` details), tilted
  to face the camera, and a colored ring on the pad. No name tags (Victor 2026-10-27: icons only).
  Knobs: `ITEM` in view.gd (icons at 1.5, 1.6 m up since 2026-10-27: at 2.4 they outshone the
  mechs). Evidence: `godot-emp-pickups-2026-10-27.png`, `visual-m3-pickups-before-after-2026-10-27.png`.
- **Crowd** (Victor 2026-10-27: more people, "same interactivity as the js version"). One
  `fan` mesh in `arena.glb` (92 faces, one material; UV.x tags shirt / sleeve / skin / hand /
  pants) drawn ~2650 times by one `MultiMeshInstance3D` (`view.build_stands`, 2 rows per tier,
  `CROWD` knobs), animated only in `CROWD_SHADER`: idle sway, cheer = jump + both arms up.
  Per-fan custom data = phase, slot (0–3 team, 4–7 neutral), shirt shade, skin. `seat_fans`
  gives each fan the team on its side (JS `sideOf`: left/right, quadrants with 4 teams).
  `view.react` ports the JS: big hit (≥30 or head), hook, break, K.O. make every team but the
  hurt one cheer (`Hype.cheer_for` seconds); `hype.gd` is JS `hype.js` (decay, floors, `mood`),
  a wild mood makes everyone cheer. CPU work per frame = one 4-float uniform. Test:
  `tests/hype_test.gd`. Not ported: the JS pit crews.
  **Crowd sounds** (Victor 2026-10-27: "bring the crowd sounds"): `crowd_sound.gd` ports the
  crowd half of JS `sfx.js` with the same clips (`godot/assets/sounds/crowd*.ogg`, CC BY 4.0
  credits in its `LICENSE.txt`). A looped bed (`crowdBed`) rises with hype during a match and
  fades out when paused or in the garage; gasp / ooh / cheer / roar / K.O. clips go through the
  JS rank gate (`react`: a busy crowd skips weaker reactions, stacked ones need `STACK` s);
  `moment` picks louder clips as the mood rises; the chant plays after 3 s of a wild crowd, at
  most every 22 s. Triggers as in JS: break (big), parry / hook / big boom (small), ult (ooh),
  K.O. (roar + cheer), fight start (cheer). It is a child of main with
  `PROCESS_MODE_ALWAYS` (hit-stop disables the view, which would pause its players); main feeds
  it `view.fresh_fx` and `view.hype` every physics frame.
  Evidence: `godot-crowd-{calm,cheer,stands}-2026-10-27.png`.
- **Sound** (Victor 2026-10-27: "full sound system for weapons, effects, and the game itself";
  spec `SOUND_DESIGN.md`, "punch, not mush"). `sfx.gd` is a child of main (`PROCESS_MODE_ALWAYS`)
  fed `sfx.update(state, view.fresh_fx, paused)` every physics frame, `sfx.menu()` in the garage,
  `sfx.ui(kind)` from the `ui` signals of garage.gd and hud.gd. Recipes are data in `RECIPES`
  (ported from JS `sfx.js`, which Victor tuned by ear): `key_of` maps an fx event to a key
  (`muzzle_<gun>`, `slash_<blade>`, `hitHead`, `boomBig`, `countGo`, else the fx `k`); a layer is
  a sample bank (`BANKS`, one `AudioStreamRandomizer` each, no-repeat) or a `synth` spec baked to
  `AudioStreamWAV` by `render` on a worker thread. Pooled `AudioStreamPlayer3D` voices sit at the
  event spot (camera = listener), events without a spot and menus use the flat pool. Also: per-mech
  hover/tread hums + footsteps (`LOOPS`, `STEPS`), overheat / cooled / low-head alarms, shield up
  and shield block (watched from `m.act`, not fx), K.O. slow-mo via
  `AudioServer.playback_speed_scale`. Music = the JS procedural loop baked into 3 stems of one
  `AudioStreamSynchronized` (calm in garage/pause, + bass in countdown, + drums in a fight).
  Buses (`Sfx.buses()`, code-built): Master (compressor + limiter) ← SFX, Env, Crowd, Music (ducked
  by SFX through a side-chain compressor). Pause menu sliders + M mute + N music, saved in
  `user://settings.cfg`. A new weapon or fx kind needs a `RECIPES` row, or `sound_test` fails.
  Not checked by ear (Claude can't hear). Evidence: `godot-sound-pause-sliders-{english,spanish}-2026-10-27.png`.
- Guns are `godot/assets/models/guns.glb` (one object per gun id, +X = barrel), made in Blender
  (`art/guns.blend`, build script = text block `guns_build.py`; re-run it, export the Guns
  collection as .glb; the Preview collection poses 3 robots for a fit check, never exported).
  Style follows Victor's "Robot Gladiator Bots" sheets: grey 8-sided barrels, one orange band,
  dark muzzle holes, glow strips. Extra materials: `glow` (team light), `flame`/`laser`/`arc`/`bounce`.
  `MOUNT` (mech.gd) places each gun like the sheets: `arm` replaces the forearm (rivet, scatter,
  gatling, tesla; origin = elbow, forearm hidden), `shoulder` sits on the pad (flamer, missiles,
  mortar; origin = pad top), anything else is held in the fist (needle = crossbow, laser,
  ricochet). Melee weapons live in the same `guns.glb` (same script, origin = fist, +X = reach;
  claws, bunker and fist are gauntlets over the fist), held in a raised, outward guard (Victor:
  "ready state but not just in front"). The saw's blade is its own object `saw_disc`, flat in
  XZ, placed at x 0.75 by `weapon_node` and spun around Y. Swings (`reach` + `pose` in mech.gd)
  follow the JS version's swing curve: pull back in wind/combo, snap to the hit (eased over
  ~3 ticks), hold for 45% of recovery, ease back to guard. Styles: thrust (`THRUST`: always level
  and pointing along the aim, only slides back/forward; Victor 2026-10-26), overhead slam
  (hammer), sweep (the rest, follow-through = the weapon's `arc`; the torso twists along).
  **Melee hit fx = weapon trail** (Victor 2026-10-26 chose it over the old flat wedge, which is
  gone): `streak` samples `pose_of` between ticks along the edge in `TRAIL` (weapon space) from
  guard to hit, `draw_trail` draws a fading additive ribbon (`TRAIL_LIFE`, world space,
  top-level `ImmediateMesh`); thrusts add a `TAIL` streak behind the tip. **Dash-swing** (wind
  act with `follow`, the sim's 360° `spinDmg` hit): `spin_of` turns the torso one full turn in the
  swing's direction over the first half of recovery, linear (keeps each tick under 180° so
  physics interpolation can't spin it backwards); the trail follows, so it draws a full ring.
- **Visual overhaul** (Victor 2026-10-27: industrial neon arena, target
  `docs/reference/industrial-neon-arena.webp`, branch `feat/visual-overhaul`). The look:
  `docs/art-direction.md`. How visuals are built: `docs/visual-architecture.md`. Starting
  state and numbers: `docs/visual-audit.md`. Milestones, budgets and acceptance:
  `docs/visual-plan.md`. **Look** (M1): `godot/src/look.gd` holds the palette `PAL`, material
  families (`FAMILY`, `paint`), the light rig and tonemap knobs `STAGE`, the floor shader values
  `FLOOR`, the arena slot materials `ARENA`, and `env()`, the one Environment for the arena and
  the garage previews (`env(true)` = see-through background). No other file sets environment
  colors. The glow threshold stays above stacked effects (`fx_peak`, asserted in `env()`): Godot
  4.7 multiplies the glow input by exposure before the threshold. **Arena** (M2): arena lights
  are `neon()`, a black surface that only emits at `NEON` 0.75, because AgX turns a brighter or
  lit light near white; no reflections (a probe and SSR were tried, neither showed at the game
  camera). **Robots** (M3): `mech.gd` `SKIN` sets metal and roughness per slot, and the `glow`
  slot is a team-color light on a black base (0.9); every match mech gets a team ring on the
  floor, a ▼ over its head and a 2 px screen-space rim in its team color (`view.gd` `MARK` and
  `mark()`, `look.gd` `RIM`; not in the garage), all off while the mech hides in smoke
  (`Sim.hidden`); the lance/rail wind-up bar is `Mech.flat`, so it no longer blooms. **Atmosphere** (M4): `godot/src/decor.gd` adds seeded scorch marks, metal scraps, floor grates, grime at the wall bases and floating dust, built once by `view.build`; `Decor.clear` keeps every piece 1.5 m off pads, spawns, trap warnings and oil (re-checked in `garage_parts_test`), and nothing on the floor moves. **HUD** (M5, reference `docs/reference/impact-numbers.webp`): two fonts, each with its `OFL.txt` in `godot/assets/fonts/<family>/`: Saira for the HUD, garage and menus, Exo 2 for the feedback in game (impact numbers and the big calls; Victor 2026-10-28) (`look.gd` `FONT`, `Look.font(weight, italic, family)`, Saira set as the default by `Look.ui()` first thing in main.gd); impact numbers are 2D text drawn by `hud.gd` from `view.pops` in the sheet's colors (`look.gd` `POP`: hit white, head (crit) orange and bigger with more pop, hurt red = damage a human player takes, BLOCKED blue when a shield takes a hit, heal green; Victor 2026-10-29: small, well above the target, quick hits on one mech climb a stair (`view.STAIR`, `hud.NUMBER.step`), gone in ~0.5 s, at most `view.POPS_MAX` on screen), never `Label3D` (AgX dulls 3D text); every plate is `Garage.plate`, team score tags around an m:ss clock, a compact skill bar, callouts on plates (a broken part under its owner's panel, arena calls under the clock); the aim reticle is `Mech.flat`. Tools: `tools/perf_probe.gd` (GPU ms, draw calls; `-s <absolute path>` with
  `--autopilot`), `tools/arena_shot.gd` (arena-only still with effects and the wind-up bar
  hidden, where bright is measured; `--top` = the whole arena; `-s <absolute path>`, `--tick=N
  --out=<abs png>`), `tools/look_stats.py` (look numbers vs the reference),
  `tools/side_by_side.py` (labeled rows of stills: `out.png
  Label=img … + Label=img …`), `tools/blender_export.py` (headless build + export of one
  `.blend`; every "export the X collection" step in this file is `blender -b art/<x>.blend
  --python tools/blender_export.py -- --build --save`). Sandbox stills need `--seed` (the rival,
  and so the K.O. tick, follows the seed). Run one Godot window at a time: two at once can hang.

## Hard rules

- **Zero auto-targeting, zero aim assist, zero auto-attacks**, on every input device. Anything that
  aims for the player is out.
- **Exteel anatomy (Victor, 2026-10-21/22).** Five body parts + two hands. Head = K.O. armor +
  `surge` (R charge rate). Core = the R skill (`ult` → `ULTS`, read through `ult_of(lo)`/`ult(m)`)
  plus a passive; 18 cores, one distinct skill each. Arms = armor of both arms + `handling` (hand
  speed). Legs = walking + the dash *move* (`move` → `DASH_MOVES`: straight, steer, contact hit,
  charges, airborne jumps with a landing hit; `airborne(m)` makes bolts/rays/cones/melee/mines
  miss, `height_of(m)` is the visual lift). Booster = dash distance/recharge + a `trail` element
  (`TRAILS`: arc, flame, frost, smoke (`hidden()`), magnet, clean) kept in `state.trails`. Hands:
  `left` (left click) and `right` (right click) each hold any of the 20 `WEAPONS` (a gun `kind` or
  `kind: 'melee'`); action, cooldown, buffer and fx keys are the hand names. `SETS` are ready-made
  full builds (garage SETS tab). Player text: `u_`/`ud_` (skills), `dm_` (dash moves), `tr_`
  (trails), `set_`/`sd_` (sets), `sb_`/`sbd_` (set bonus). Every body part has a `series` (light/standard/heavy) whose `SERIES` weight
  sets top speed (`speed_of`). Armor pools stay `head`/`rarm`/`larm`/`legs` (`ARM_OF` maps a hand
  to its arm). Shield (Q) is the fixed kit; the E skill comes from the head (`HEADS[id].e`, read through `e_skill(m)`; Victor 2026-10-28). The default head `rookie` (Rookie Helm, a plain cube head, `heads_build.py`) has none (`e` is `""`): the HUD E slot stays blank, `start` queues nothing and the bot never presses E. Every other head has one skill, in `E_SPEC` (brace, focus, pulse, xray, frost, arcwall, trap; each has `cd` and a `time`, a buff `m.buffs[skill]`, or a placed object) cast by `cast_e` from `start` (and its fx kind of the same name, with a `RECIPES` row in sfx.gd); `hook` (Stag Pincers) is the old claw, `cleanse` (Sun Crest) runs first in `start` so it works while stunned (`warded()` blocks new slow, jam, root, hook and landing stuns for 2 s) and `lunge` (Rhino Horn) is a dash act with `DASH_MOVES.lunge`. `e_active(m)` lights the HUD slot; `wants_e` in bot.gd is the bot's rule for each. Root is `buffs.root`; Electric Wall is a `state.walls` entry with `zap`; Trap is a `state.mines` entry with `root`; `wall_blocks()` decides what walls stop (X-Ray and the owner's own Electric Wall pass). Catalogs: `HEADS`, `CORES`, `ARMS`,
  `LEG_PARTS`, `BOOSTERS`, `WEAPONS` (all in `CATALOG`) in `godot/src/sim.gd`; a mech reads its parts
  through `weapon(m, hand)`, `arms(m)`, `feet(m)`, `booster(m)`, `head(m)`, `core(m)` and its max
  armor from `m.max`. Loadouts go through `normalize()` (unknown keys fall back to
  `DEFAULT_LOADOUT`). Guns have a `kind`:
  `bolt` (shots, optional `homing`/`bounces`/`auto` hold-to-fire), `lob` (lands after `delay`),
  `ray` (instant line), `cone`. R skills have a `kind`, handled in `fire_ult`. A new part = one
  catalog row + `p_`/`d_` text keys in `i18n.gd` (+ `s_` for weapons; a new core also needs a new
  `ULTS` kind with `fire_ult`, bot `wants_ult` and a `CORE_C` color in mech.gd) + a model in
  the matching Blender build script under `art/` (exported to `godot/assets/models/`). Check balance with a bot round-robin before shipping it.
- **Calm follow camera, never rotating.** W must always be up the screen. The first follow camera
  (2026-10-19) felt disorienting; for the big stadium (2026-10-21) Victor chose a calm one: dead
  zone, slow easing, you stay in the middle 70%, edge arrow for an off-screen rival. Only the K.O.
  zooms. The one exception is the kill cam replay (nobody plays during it): one smooth move that
  turns around the kill (Victor 2026-10-28).
- **Original names only** in anything player-facing. No Medabots names (Medabot, Medal, Robattle,
  Medaforce, Metabee...). Same rule as `../../../to_develop/medabots-survivor`.
- **Sim stays pure.** Randomness, time and DOM never enter `godot/src/sim.gd`.
- Tuning constants in `godot/src/sim.gd` mirror `COMBAT_DESIGN.md`. Change both together.
- Everything else: parent `C:\Users\victo\Proyectos\CLAUDE.md`.
