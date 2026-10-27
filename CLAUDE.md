# Mech Duel (working title)

Top-down mech arena: 1v1, free-for-all (4 mechs) or 2v2, picked in the garage. LoL-style Q/W/E/R/Passive kits, every action aimed, no auto-attacks,
no auto-targeting. Mechs are built Exteel-style from five body parts (Head = R ultimate, Core =
passive, Arms, Legs = movement, Booster = Space dash) plus two hands that each hold any weapon
(left click = left hand, right click = right hand). Inspired by Medabots and Exteel.

Stage: playable prototype, you vs an AI rival (or training dummies), 62 parts in the garage. The spec is `COMBAT_DESIGN.md`.

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
  (`view.process_mode` disabled, camera shake keeps going). Rebuilt in the crisp neon look
  (additive `Mech.flat(c, true)`, team colors): hit, muzzle, bolts, flame, missile, laser, lance,
  rail, tesla, boom (+ scorch marks in `view.marks`), mortar warning, parry, break, K.O. (+ slow-mo:
  `view.slow` → main.gd sets `Engine.time_scale`), land, dash (+ `Fx.ghost` afterimages), booster
  trails (`Fx.ribbon` for arc/flame/frost, `Fx.smoke` puffs for smoke), flamer cone
  (`view.cone`), shield ripple (`Fx.ripple`, from `view.guard` watching `act.absorbed`), hook
  cable + catch (`view.tether`, `Fx.hooked`), directional camera kick (`view.kick` → main.gd), and emp, heal / pickup, crush, blink, soak, magnet, ping, R charge (`Fx.emp` … `Fx.charge`).
  Effect nodes are pooled (`Fx.take`/`Fx.park`). Smoke and fire puffs use noise shaders (`SMOKE_SHADER`, `FIRE_SHADER` in fx.gd). **Sandbox:** `$G --path godot -- --sandbox=<weapon>` (two pinned mechs, auto-fire, ←/→
  weapon, T auto-fire, G guard, K refill, J dash, `--block` held shield, `--hook` auto hook; see `FX_DESIGN.md`). Evidence:
  `production/qa/evidence/godot-hit-fx-before-after-2026-10-26.png`,
  `godot-weapon-fx-before-after-2026-10-27.png`, `godot-moves-fx-before-after-2026-10-27.png`.
- Look check without a player: `$G --path godot -- --autopilot --seed=3 --shot=<abs>.png --at=700`
  saves that tick's frame and quits. Add `--cam=1..4` for a close-up and `--hands=<left>,<right>`
  to pick your two weapons (e.g. `--hands=mortar,rivet`; use `--at=200`, later ticks often show a
  broken, drooping arm). `--head=<id>` picks your head (e.g. `--head=demon`), `--core=<id>` your
  core (e.g. `--core=titan`; pair it with `--hands=rivet,rivet` so no blade hides the chest),
  `--arms=<id>` your arms (pair it with `--hands=laser,ricochet` so both forearms show), `--legs=<id>`
  your legs, `--booster=<id>` your booster (pair it with `--cam=3`, the back view), `--set=<id>` a
  whole ready-made build (`SETS`; the part flags still override single parts). The rival is always
  one of the 6 `SETS`, picked by the seed (`s % 6`); you get `DEFAULT_LOADOUT` without `--set`.
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
- **Flow (same as JS):** the game opens on the garage; FIGHT saves your bot to
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
  Garage. Not built yet: a second local player, rumble. Evidence:
  `godot-gamepad-hud-2026-10-26.png`, `godot-gamepad-pause-2026-10-26.png`.
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
  `zap`), `crush_plate` + `crush_head` (block centered on the origin; `hazard` stripes take the
  per-crusher warn material), `heal_pad`, `pad`, `vent` (+X = into the arena), `wall` (a 4 m
  panel, arena face at z 0; `build_walls` tiles and stretches it per edge) and `wall_post`.
  `view.gd` `ARENA` maps the material names (steel, dark, trim, hazard, amber, zap, pad, heal,
  vent). Evidence: `production/qa/evidence/godot-arena-{before,after,wide}-2026-10-27.png`.
  **Stadium** (Victor 2026-10-27: "production ready", no gray box when the camera zooms out):
  `stadium` is the whole bowl in world space (added at the origin): a walkway, 3 tiers with seat
  rows, a riser LED board and a rail, one aisle with steps in the middle of each edge, a 7 m back
  wall with an LED ribbon and flood strip, a dark ribbed roof out to 26 m past the wall (the
  zoomed-out camera sees ~25 m past it) with a team-color rim, and a scoreboard on the north side.
  `tower` = 4 floodlight towers (no shadows). Side materials: `seat_a/b/n`, `led_a/b/n` (left =
  team 0, right = team 1, else neutral). The script copies the arena shape (`AW`, `AH`, `ACUT`,
  `WALLS`) from `sim.gd`, and `view.gd` `STAND` must match the script's `STAND` (fans stand on
  the tiers and skip the aisles). Outside the stadium is unshaded `OUTSIDE` night color.
  Evidence: `godot-stadium-{left,bottom}-before-after-2026-10-27.png`, `godot-stadium-top-2026-10-27.png`.
  **EMP zones** (Victor 2026-10-27: the fire vents became EMP zones, same spots and timing;
  the sim names stay `vents`/`HAZARDS`): 12 Legs + `HAZARDS.slow` ticks of Slow instead of Heat.
  Drawn with `EMP_SHADER` (additive crackle on a floor plane, `power` 0 = warning outline, 1 =
  live); a mech with Slow > 2 (EMP only, frost sets 2) gets the same crackle under it (`shocks`).
  **Pickups**: `item_<kind>` icons in `arena.glb` (repair wrench, shield, speed bolt, power
  burst, coolant snowflake, surge battery; material `icon` = item color, `dark` details), tilted
  to face the camera, and a colored ring on the pad. No name tags (Victor 2026-10-27: icons only).
  Knobs: `ITEM` in view.gd. Evidence: `godot-emp-pickups-2026-10-27.png`.
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
  (trails), `set_`/`sd_` (sets). Every body part has a `series` (light/standard/heavy) whose `SERIES` weight
  sets top speed (`speed_of`). Armor pools stay `head`/`rarm`/`larm`/`legs` (`ARM_OF` maps a hand
  to its arm). Shield (Q) and hook (E) are the fixed kit. Catalogs: `HEADS`, `CORES`, `ARMS`,
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
  zooms.
- **Original names only** in anything player-facing. No Medabots names (Medabot, Medal, Robattle,
  Medaforce, Metabee...). Same rule as `../../../to_develop/medabots-survivor`.
- **Sim stays pure.** Randomness, time and DOM never enter `godot/src/sim.gd`.
- Tuning constants in `godot/src/sim.gd` mirror `COMBAT_DESIGN.md`. Change both together.
- Everything else: parent `C:\Users\victo\Proyectos\CLAUDE.md`.
