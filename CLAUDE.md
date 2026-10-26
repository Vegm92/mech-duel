# Mech Duel (working title)

Top-down mech arena: 1v1, free-for-all (4 mechs) or 2v2, picked in the garage. LoL-style Q/W/E/R/Passive kits, every action aimed, no auto-attacks,
no auto-targeting. Mechs are built Exteel-style from five body parts (Head = R ultimate, Core =
passive, Arms, Legs = movement, Booster = Space dash) plus two hands that each hold any weapon
(left click = left hand, right click = right hand). Inspired by Medabots and Exteel.

Stage: playable prototype, you vs an AI rival (or training dummies), 62 parts in the garage. The spec is `COMBAT_DESIGN.md`.

## Stack and run

Plain JavaScript ES modules + HTML canvas. No engine, no build step, no npm dependencies.

```bash
play.bat                     # double-click: opens the browser and serves the game
python serve.py              # same server without opening the browser ("mech-duel" in the root .claude/launch.json); sends no-store so a plain refresh always loads fresh modules
node --test                  # sim tests
```

## Godot port (slice, `godot/`)

A Godot 4.7 port being evaluated (2026-10-25): same rules, lit low-poly 3D instead of the pixel view.
Godot is portable at `C:\Users\victo\Tools\Godot\` (not on PATH).

```bash
G=/c/Users/victo/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe
$G --path godot                                                # play
$G --headless --path godot -s res://tests/sim_rules_test.gd     # tests (needs node for the JS check)
```

- `godot/src/sim.gd` and `godot/src/bot.gd` are line-by-line ports of `src/sim.js` and `src/bot.js`:
  same constants, same dict keys (camelCase), snake_case function names. Every `/` has a float
  operand (GDScript int / int truncates) and `%` takes ints. `Sim.hypot` and `Sim.jround` copy
  V8's `Math.hypot` and `Math.round` bit for bit; sin/cos/atan2 differ from V8 in the last bit.
  A rule change goes into both ports together until the port is adopted or dropped.
- `godot/tests/sim_rules_test.gd`: `every_step_matches_js` runs `godot/tests/js_steps.mjs` (bot
  matches in JS covering every core, weapon, leg and booster), loads each sampled state into
  Godot, steps once and compares with JS (1e-9 tolerance for the trig noise); numbers cross as
  hex bits because Godot's JSON parser rounds decimals. It also checks `create_state` and every
  round reset. `GOLDEN` is the Godot-side golden hash; it depends on the platform's trig.
- View: `main.gd` (fixed 60 Hz `_physics_process` loop with physics interpolation on, input with
  latched taps, calm follow camera, never rotating), `view.gd` (arena, projectiles, fx), `mech.gd`
  (mechs from primitive meshes + shared mesh/material helpers), `hud.gd`, `i18n.gd` (en + es built
  as `Translation` objects in code; L toggles). Sim (x, y) maps to `Vector3(x, height, y)`. The view
  tags state dicts with `seen` (fx) and `_n` (pooled node); the sim ignores both.
- Look check without a player: `$G --path godot -- --autopilot --seed=3 --shot=<abs>.png --at=700`
  saves that tick's frame and quits. Add `--cam=1..4` for a close-up.
- Model viewing (dev keys, main.gd): F freezes the match (sim and view stop), C cycles `CAMS`
  (0 game, 1 front 3/4, 2 side, 3 back 3/4, 4 game angle close; HUD hidden in close-ups), Tab
  picks the mech, and while frozen drag orbits and the wheel zooms.
- Body is the **light frame** `godot/assets/models/light.glb` (Victor 2026-10-26: chibi blocky
  style, cube head + spike, visor eyes, grey pads, wheel-heel feet), made in Blender
  (`art/light.blend`; build script = text block `light_build.py`; re-run it, then export the
  Light collection as .glb). Objects: Head (pivot at the neck, 1.44), Chest (incl. shoulder pads
  and back boosters), Hips, Arm_L/R (pivot at the shoulder, mesh hangs down; `build` raises it
  1.4 rad and puts the weapon at the fist), Leg_L/R (pivot at the hip; used by every two-legged
  leg kind, `stompers`/`skates` scale it). Head kinds add their extras on top of the light head.
  `Mech.add_part` swaps materials by name (body/trim/joint/gem/boost) for the team ones. The old
  chassis (`art/chassis.blend`, `chassis.glb`) is no longer loaded.

## Layout

- `src/sim.js` — every game rule. Pure: no DOM, no `Math.random`, no `Date`. Fixed 60 ticks/s,
  units are meters and ticks. Tuning constants at the top. Octagon walls are `WALLS` (+ `clampArena`,
  `arenaCorners`); pickup pads are `PADS`, `PICKUP`, `ITEMS`, run by `pickups()`; traps and hazards are `TRAPS`, `HAZARDS`, run by
  `traps()`, with pure timing helpers (`elapsed`, `untilSlam`, `untilZap`, `ventPhase`, `vents`, `shrinkOf`) that
  render.js, pix3d.js and bot.js read (spec: COMBAT_DESIGN.md).
  **2–4 mechs (2026-10-25):** `createState(loadouts, teams)` with `teams` from `FORMATS` (`1v1`,
  `ffa`, `2v2`); each mech has `id` (seat, 0 = you) and `team`; `state.score` has one slot per team.
  Never write "the other mech": every attack loops `foes(state, id)` (live enemies, never teammates).
  Mechs act in rotating order (`turns`). A K.O. leaves a wreck until one team is left; `finalKo` is the
  mech whose fall ended the round (-1 on a timeout). `spawnsOf(teams)` places them. 1v1 must stay
  tick-for-tick identical: compare a bot-vs-bot run before/after with the new keys stripped.
  Shots of kind `missile` (Hornet Pod, Swarm ult) can be shot down: `intercept` (end of `moveShots`,
  swept on relative motion) for enemy projectiles, a filter in `lineAttack` for beams.
- `src/bot.js` — the AI rival (default opponent, key 1). Pure function of the state plus a `brain`
  (seeded rng, juke timer, per-shot guard/dodge rolls). Tuning in `BOT` at the top. Handles every
  gun kind and every ultimate (`wantsUlt`), and steps out of enemy lobs, mines and fields. `pick`
  chooses the target: nearest enemy, sticky (`BOT.stick`). main.js gives seats 2–3 their own brains (`crew`).
- `src/dummy.js` — scripted training dummies (keys 2–5): idle / strafe / strafe + Q / saw rush.
- `src/sfx.js` — all audio (WebAudio). Mostly recorded samples from `sounds/` (Kenney CC0 packs,
  see `sounds/LICENSE.txt`): `BANK` maps a group name to its file variations, `play(group, opts)`
  picks a variation (never the same twice in a row) with random pitch, pan by arena x, optional
  trim/filter/reverb. Files are fetched when the page loads and decoded on the first key or click
  (`unlock`). Synth is kept for the body/head hit (Victor prefers the v1 tick), countdown/round
  beeps, heal chime, whooshes, alarms and the music (lookahead step sequencer, level 0 menus /
  1 countdown / 2 fight). `SOUNDS` = one recipe per sim `fx` kind; `engineSounds` = hover/tread loops
  + Greaves footsteps. M mutes all, N toggles music (localStorage). Mixer: `sfxBus`, `envBus` (traps,
  hazards, pad chimes; fades with distance from you via `near`), `crowdBus`, `musicBus`, each with its
  own reverb send so a 0 slider is silent; levels in `vol` (localStorage `mech-duel/volume`), set by
  `setVolume` from the pause menu. Crowd = `react(kind)` (gasp/ooh/cheer/roar, a higher rank cuts in,
  same or lower waits) playing real recordings `crowdGasp/Cheer/Roar/Ooh_*` (credits in
  `sounds/LICENSE.txt`: Gregor Quendel CC BY 4.0, keep that credit). Clips were cut at the moments
  the crowd erupts, faded, and level-matched to -14 dB. `crowdBed` loops a 12 s crowd ambience
  (crossfaded seam) quietly under every match, off on menus and pause (Victor 2026-10-25: the gaps
  between reactions felt empty). Everything crowd follows the hype meter (`src/hype.js`, below).
- `src/hype.js` — crowd excitement 0–100, presentation only (never feeds the sim). Events add points
  (`gain`), it halves every `HYPE.half` s, tension floors (`floor`: a head under 25%, last 10 s, match
  point). `mood` = calm / hot / wild. `trackHype(state)` runs once per frame in main.js before
  `sounds`; sfx (`moment`: reaction size, `crowdBed` volume, `chant` after 3 s wild, 22 s cooldown)
  and render (all fans bounce when wild) read `hype()`. Victor chose a neutral crowd (cheers both
  sides). Victor wants it lively ("rather crazier than plain"): half 4 s, hits ÷10 → in 30 bot
  matches calm 20% / hot 46% / wild 34%, a chant ~1.7 per fight-minute (half 3 s, hits ÷20 gave
  wild 11% and he found it too calm). When wild, reactions stack (`react(..., stack)` skips the
  rank gate, one new clip per 0.6 s) and half the time a second, softer layer follows 0.6–1 s
  later; a K.O. always gets roar + cheer. `duel.hype` shows it live. Victor rejected two synth crowds
  (2026-10-23/25: "know it's a cheer and still don't recognize it"), so no synth crowd. Menu sounds: `uiSound(kind)` plays
  a `UI` recipe (Victor's picks, 2026-10-22: servo hover/equip/up/down, holo tab, hangar set; Esc and
  setting keys stay silent). Hovering a garage card plays `up`/`down` when `verdict` (garage.js) says
  the sheet's ▲/▼ stats are mostly better/worse, else `hover` (cores and sets too: the sound must
  match the arrows everywhere, Victor 2026-10-23). Try new menu sounds in `sounds.html`.
  A new sound: drop the .ogg in `sounds/`, add it to `BANK`, use `play()` in a recipe.
- `src/render.js` — world drawing: follow camera (`cam`, frames both mechs, zooms on the K.O.),
  arena floor pre-rendered once into `floorCache`, decals (scorch, marks, debris) cleared per round,
  particles, mechs. Reads state, never writes it. `toWorld(px, py)` uses the last drawn camera.
  Two views, V toggles (`ui.pixel`, default on): `world3d` (pixel 3D, below) and `world2d` (the
  old flat top-down art). `world3d` draws floor effects (decals, rings, telegraphs) into a low-res
  canvas squashed by `SIN`, blends them into the 3D frame, rasterizes walls/pillars/mechs, then
  draws air effects (shots, sparks, smoke) and upscales with nearest-neighbor. Text and the heat
  gauge are drawn at full res on top. R skills show an Exteel-style cut-in banner (`drawBanners`,
  match screen only); booster jets, dash bursts and dash embers use `BOOST_C` (paint.js) by the
  booster's series. **Speed rules (2026-10-22):** reading pixels back from a canvas is the most
  expensive call here, so the air layer reads back only `airBox` (the area its entities can touch;
  a new air effect that draws away from its entity must grow `airBox`, or it gets clipped). The
  vignette is cached small and stretched. The garage skips the world draw. During the K.O. zoom
  the floor is the cached floor stretched (`clearFloorZoom`), never rebuilt per frame. Measure
  with a Chrome performance trace (chrome-devtools MCP), not a tight render loop: a loop with no
  frame pacing makes the GPU stall every ~25 frames and shows fake spikes.
- `src/pix3d.js` — the pixel 3D renderer, no libraries: a CPU triangle rasterizer into a low-res
  buffer (`PIX` ≈ 16 px per meter, integer upscale), fixed orthographic camera pitched ~49°
  (`SIN`/`COS`, W stays up), z-buffer, flat banded light from the north-west, projected real
  shadows, dark outlines + light top edges from depth/id jumps (`tri` records each row's drawn
  x-range in `r0`/`r1`, so the shadow and outline passes skip empty rows), x-ray team checker when a mech
  hides behind a pillar or wall, and `blend` (4-level alpha with Bayer dither) so 2D effects come
  out as crisp pixels. Procedural floor cached per camera. Mechs are boxes and octagon prisms: one
  function per part in `FEET`, `GUNS`, `BLADES`, `ARM_ART`, `BOOSTER_ART`, `HEAD_ART`; frame + head
  in `buildMech`. Gun art faces the right side, blade art the left; `weaponArt` mirrors a weapon
  (`MIRROR`) when it sits in the other hand. `buildPart` builds one part alone for the garage card
  pictures (`drawPartThumb` in render.js caches them). `VIS` is 2 × `MECH_R`, so the model grows
  with the hit circle. Walls are 8 slabs built from `arenaCorners()` (sim.js). The garage's big
  turntable uses the same code.
- `src/mechart.js` — all robot art. `drawMech` (top-down, arena) and `drawPortrait` (front view,
  garage + title), both built from the loadout: one function per part type (`legs`, `gunArm`,
  `meleeArm`, `frontLegs`, `frontArm`) plus the frame (`shell`, `head`, `frontTorso`, `frontHead`).
  Colors come from the mech's **team**, not its seat (`hue(m)` in paint.js = `m.team ?? m.id`; 4 colors in
  `TEAM`/`TEAM_LIGHT`/`TEAM_DARK`/`EYES`: orange, blue, green, purple). render.js keeps `hues` (seat → team)
  for shots/lobs/mines that only carry an owner seat. Seats: 0 Cinderhorn, 1 Talonjaw, 2 Mossfang,
  3 Duskvane. With 4 mechs: slim HUD cards (`slim`, seats 0/2 left, 1/3 right), P1–P4 tags under the
  mechs (`seatTag`, hidden in the replay), an edge arrow per enemy, camera on you + your nearest enemy.
  pix3d's stadium takes `sides` (2, or 4 in FFA): `sideOf`, `PITS[sides]` (FFA pits on the 4 cut corner
  walls), `FANS[sides]`, the floor cache is keyed by it. The
  head shape comes from `loadout.head`, the chest gem color from `loadout.core`. Damage shows per
  part (cracks ≤ 50%, broken arms droop and go dark). The 2D arm art was drawn for "gun on the
  right, melee on the left": `hands()` mirrors the canvas for the other side and passes an
  `asHand` view of the mech, so the old arm functions keep working unchanged.
- `src/hud.js` — HUD: part silhouettes, round clock + win pips, ability bar (R slot named by the
  hand pair, shows buff time left), callouts, title/pause screens, cursor. The title is in the
  store style too (2026-10-22): the demo fight dimmed behind a blue backdrop, logo plate, VS
  emblem, start button, key-cap controls panel that sizes itself to the text (`controls`, shared
  with pause), and the two demo mechs as pixel 3D models facing each other on team rings with a
  name plate (weapons + R skill). Pixel view passes `drawMechPreview3d` in as `preview` (bigger
  160 px buffer); the 2D view falls back to `drawPortrait`. The match HUD is hidden on the title.
  `src/garage.js` — the
  parts store, Exteel-style: PARTS / WEAPONS / SKILLS main tabs, 8 sub tabs (click or Tab /
  Shift+Tab), cards with series/family, stat bars and a part picture, skill cards that equip a
  pair, a turntable that tries on the hovered part with hand + skill slots, a stat sheet (`sheet`)
  that shows the change while you hover a card, `garageHit` for clicks. `src/paint.js` — shared
  palette and canvas helpers, including the store look every menu uses (`HOLO`, `UI_C`, `plate`
  for the angled panels).
- `src/main.js` — input, fixed-step loop, title screen with an AI-vs-AI demo behind it, Enter for a
  rematch. Esc opens the menu, plain DOM (`#menu` in index.html, native range sliders): pause in a
  match (resume, restart, quit to garage), options on the title; 5 volume sliders, language, view.
  `syncMenu` shows/hides it every frame from `paused`/`options`. `window.duel` debug hook: `state`, `tick(input)`, `render`, `restart`, `start`,
  `setMode`, `setPaused`, `setAutopilot` (AI plays your side, for checks in the browser pane),
  `replay` + `skip` (kill cam).
- `src/killcam.js` — the kill cam, presentation only. After a K.O. it re-runs the last 5 s instead
  of playing back a recording: `record` keeps a `structuredClone` of the state once a second plus
  every seat's inputs every fight tick (it plays when `finalKo >= 0` and focuses that mech), `replay` copies the oldest snapshot and steps it to 5 s before
  the K.O., `advance` steps it one tick with the saved inputs. A re-run makes fresh fx objects that
  render/sfx/hype see once, like live (cloned frames would fire every fx every frame). Keep
  `structuredClone`: a dash trail is shared by `state.trails` and `m.act.trail`, JSON would split
  it. main.js swaps the replay state in for drawing and sound; `cut()` (render.js) clears
  particles/decals and snaps the camera. `play` runs once per real tick: the last `slowTicks` before
  the K.O. and the `hold` after it run at `slow` speed (`speed(r)`). In slow-mo render scales its
  dt by `ui.speed` (particles, legs, shake) but the camera keeps real time and zooms on `ui.focus`
  (the mech that dies); sfx `setSlow` plays recorded sounds at `SLOW_RATE` (synth and music stay
  normal); `rewind()` (sfx) plays a falling swoosh as the replay starts. The replay hides the whole match HUD and the R cut-ins (Victor 2026-10-25: "remove the
  HUD, leave a minimal ui so the user knows it's not the next round"): only black bars, a blinking
  "● REPLAY", a progress line and a skip hint (`replayBars` in hud.js). Tuning in `KILLCAM`.
- `src/i18n.js` — en + es. Every player-visible string lives here.
- `sheet.html` — dev page: every part in both views (`?slot=head&view=front|top|all&act=idle|wind|rec`).
- `sounds.html` — dev page: menu sound board, 9 moments × styles, picks saved in localStorage.
- `src/sim.test.js` — design claims + golden hash. An intentional sim change changes `GOLDEN`;
  the failing test prints the new value.

## Hard rules

- **Zero auto-targeting, zero aim assist, zero auto-attacks**, on every input device. Anything that
  aims for the player is out.
- **Exteel anatomy (Victor, 2026-10-21/22).** Five body parts + two hands. Head = K.O. armor +
  `surge` (R charge rate). Core = the R skill (`ult` → `ULTS`, read through `ultOf(lo)`/`ult(m)`)
  plus a passive; 18 cores, one distinct skill each. Arms = armor of both arms + `handling` (hand
  speed). Legs = walking + the dash *move* (`move` → `DASH_MOVES`: straight, steer, contact hit,
  charges, airborne jumps with a landing hit; `airborne(m)` makes bolts/rays/cones/melee/mines
  miss, `heightOf(m)` is the visual lift). Booster = dash distance/recharge + a `trail` element
  (`TRAILS`: arc, flame, frost, smoke (`hidden()`), magnet, clean) kept in `state.trails`. Hands:
  `left` (left click) and `right` (right click) each hold any of the 20 `WEAPONS` (a gun `kind` or
  `kind: 'melee'`); action, cooldown, buffer and fx keys are the hand names. `SETS` are ready-made
  full builds (garage SETS tab). Player text: `u_`/`ud_` (skills), `dm_` (dash moves), `tr_`
  (trails), `set_`/`sd_` (sets). Every body part has a `series` (light/standard/heavy) whose `SERIES` weight
  sets top speed (`speedOf`). Armor pools stay `head`/`rarm`/`larm`/`legs` (`ARM_OF` maps a hand
  to its arm). Shield (Q) and hook (E) are the fixed kit. Catalogs: `HEADS`, `CORES`, `ARMS`,
  `LEG_PARTS`, `BOOSTERS`, `WEAPONS` (all in `CATALOG`) in `src/sim.js`; a mech reads its parts
  through `weapon(m, hand)`, `arms(m)`, `feet(m)`, `booster(m)`, `head(m)`, `core(m)` and its max
  armor from `m.max`. Loadouts go through `normalize()` (unknown keys fall back to
  `DEFAULT_LOADOUT`; main.js maps an old saved `rarm`/`larm` to `left`/`right`). Guns have a `kind`:
  `bolt` (shots, optional `homing`/`bounces`/`auto` hold-to-fire), `lob` (lands after `delay`),
  `ray` (instant line), `cone`. R skills have a `kind`, handled in `fireUlt`. A new part = one
  catalog row + `p_`/`d_` text keys in `i18n.js` (+ `s_` for weapons; a new core also needs a new
  `ULTS` kind with `fireUlt`, bot `wantsUlt`, `ULT_C`/`CORE_C` colors and a test job) + a drawing case in
  `pix3d.js` (and `mechart.js` for weapons/heads/legs). Check balance with a bot round-robin before shipping it.
- **Calm follow camera, never rotating.** W must always be up the screen. The first follow camera
  (2026-10-19) felt disorienting; for the big stadium (2026-10-21) Victor chose a calm one: dead
  zone, slow easing, you stay in the middle 70%, edge arrow for an off-screen rival. Only the K.O.
  zooms. The 3D floor is one cached image of the whole stadium; the camera snaps to whole low-res
  pixels so floor and models line up.
- **Original names only** in anything player-facing. No Medabots names (Medabot, Medal, Robattle,
  Medaforce, Metabee...). Same rule as `../../../to_develop/medabots-survivor`.
- **Sim stays pure.** Randomness, time and DOM never enter `src/sim.js`.
- Tuning constants in `src/sim.js` mirror `COMBAT_DESIGN.md`. Change both together.
- Everything else: parent `C:\Users\victo\Proyectos\CLAUDE.md`.
