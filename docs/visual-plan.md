# Visual Overhaul — Plan

Goal: the game reads as the industrial neon arena in `docs/reference/industrial-neon-arena.webp`
during real play, with gameplay, controls and performance intact. Look: `art-direction.md`.
Build rules: `visual-architecture.md`. Starting point: `visual-audit.md`.

One milestone at a time. Each ends with evidence and Victor's OK before the next one starts.

## Decisions before M1 (from `visual-audit.md` §7)

| # | Decision | Recommended |
|---|---|---|
| 1 | Which arena branch is the base | merge both stadium branches into `main` first (M0) |
| 2 | Bloom vs "punch, not glow" | effects never bloom; environment emissives and mech eyes, cores and boosters may, gently |
| 3 | Team colors | keep `Mech.TEAM`; add a ground ring and an arrow per mech |
| 4 | 4-player HUD, minimap | out of scope (the Godot loop is 1v1) |
| 5 | Haze and follow spots | almost no haze; spots soft and unshadowed |

## How every milestone is checked

1. **Stills:** look checks at 1920×1080, seeds 3 and 7, tick 700, `--cam=0` and `--cam=4`, plus
   the milestone's own shots (sandbox for effects, garage for UI).
2. **Side by side:** reference | before | after, saved as
   `production/qa/evidence/visual-m<N>-<name>-<date>.png` (UTC date).
3. **Numbers:** look numbers on the `--cam=0` stills; perf probe, 30 s, seed 3. **Bright** is
   measured on the arena only, effects and the wind-up bar hidden (Victor, 2026-10-27):
   `tools/arena_shot.gd`, same seed and tick.
4. **Loop:** write down the three biggest gaps vs the reference, fix the biggest, re-shoot.
   Repeat until the acceptance list is green.
5. **Gates (every milestone):** the 4 test suites pass (`sim_rules`, `garage_parts`, `sound`,
   `hype`); no new errors or warnings in the Godot log; the golden hash doesn't move (the sim is
   never touched).
6. **Victor** looks at the stills and plays one match: feel can't be judged from stills.

**Budget** (GPU, 1080p, RTX 4070 Laptop, same probe): each milestone may add at most the
amount below over the M0 baseline, and the whole overhaul stays under 5.0 ms average and 6.5 ms
peak. Draw calls never go above the M0 baseline by more than 20 %. Not checked on other hardware;
the cap leaves ~3× headroom on a GPU about 3× slower.

**Rollback:** each milestone is its own run of commits on `feat/visual-overhaul`; undo =
`git revert` of that run. Look values live in knob dicts, so tuning is one line to undo.

## M0 — One baseline (no art)

What happened (2026-10-27):

- `feat/stadium-polish` was already in `main` (PR #7). `feat/stadium-lighting` was merged with
  `main` in the worktree `games/mech-duel-visual`: one conflict in `view.gd` (both sides kept),
  commit e9567dc, PR #8. Victor merged PR #8 into `main` (auto mode won't merge into `main`).
- `games/mech-duel` was left untouched (Victor declined stashing it). Its uncommitted sound
  wiring matches `main`, apart from a PowerShell command block in `CLAUDE.md`, now carried over
  on this branch.
- Tools in the repo: `tools/perf_probe.gd`, `tools/look_stats.py`, `tools/blender_export.py`.
- `feat/visual-overhaul` cut from e9567dc (the same files `main` gets from PR #8), in
  `games/mech-duel-visual`.

Acceptance:
- [x] `main` holds both stadium branches: polish through PR #7, lighting through PR #8
- [x] all 4 test suites pass on the merged code (e9567dc); the headless error and leak lines are
      the same as on `main`
- [x] the export script reproduces every current `.glb`: all 9, with and without `--build`
- [x] baseline table filled in, below

## M1 — Rendering foundation

Scope: `look.gd` (palette, material families, `env()`), used by `view.gd` and `part_view.gd`.
Light rig: one shadowed key, low navy ambient, unshadowed cyan and orange accent lights, haze
near zero, follow spots soft and unshadowed (if kept). Exposure, AgX contrast and white point,
glow threshold above stacked effects, restrained glow. A static reflection probe over the arena.
Camera unchanged (pitch, FOV or distance change only with Victor's OK; the hard rule stays).

Acceptance (2026-10-27, code 530b773; numbers in the table below):
- [x] seeds 3 and 7, `--cam=0`: luma p50 35–60, dark (< 40) 30–55 % (neon targets wait for M2:
      no strips yet). Seed 3: 45 / 36.1 %. Seed 7: 42 / 45.3 %.
- [x] same stills, bright (> 200) ≤ 2 %, measured on the arena only (Victor, 2026-10-27). Seed 3:
      1.01 % with effects on. Seed 7: 0.68 % with effects and the wind-up bar hidden
      (`visual-m1-seed7-cam0-no-fx-2026-10-27.png`); 2.80 % with them, because at tick 700 your
      lance wind-up bar (`mech.gd` `aim_line`, glow 4.0, unchanged since M0) and the hit effects
      cover about 2 % of the frame. The bar is fixed in M3.
- [x] both mechs clearly lighter or more saturated than the floor around them in all 4 stills
      (eye check, `visual-m1-seed{3,7}-cam{0,4}-2026-10-27.png`; the seed 7 close-up follows your
      mech, the rival is off-frame)
- [x] the garage previews use the same `env()`: `Look.env(true)` (see-through background).
      `visual-m1-garage-before-after-2026-10-27.png`: parts unchanged; the stand now uses the arena
      `dark` and `pad` materials, so its ring glows a little less.
- [x] no effect blooms: `visual-m1-fx-before-after-2026-10-27.png` (`--seed=3`, laser at tick 55,
      mortar at 160, K.O. with `--norefill` at 602): same effects, darker background. Threshold
      2.2, exposure 1 and glow strength 1 are M0's; `env()` asserts
      `glow_threshold ≥ fx_peak × exposure` (Godot 4.7 multiplies the glow input by exposure
      before the threshold: `copy.glsl`, glow first pass).
- [x] no environment color literals left in `view.gd` `build` or `part_view.gd`: `grep Color`
      finds only type names and the crowd's packed per-fan data
- [x] GPU ≤ M0 + 0.8 ms; draw calls ≤ M0: 2.32 / 2.90 ms (M0 3.21 / 4.43), 769 (M0 1051)
- [x] gates: the 4 suites pass (3 + 5 + 15 + 13 tests, golden hash unchanged); their log lines are
      the same as M0's (garage_parts' two headless "Parameter material is null" and sound's exit
      leak lines are on M0 too); the look-check runs log nothing

| Still set | Luma p10 / p50 / p90 | Dark | Bright | Neon | GPU ms avg / peak | Draw calls |
|---|---|---|---|---|---|---|
| seed 3, `--cam=0` | 22 / 45 / 60 | 36.1 % | 1.01 % | 0.42 % | 2.32 / 2.90 | 769 |
| seed 7, `--cam=0` | 20 / 42 / 72 | 45.3 % | 2.80 % | 0.30 % | — | — |
| seed 7, effects and lance bar hidden | 20 / 42 / 69 | 46.3 % | 0.68 % | 0.32 % | — | — |

Also: render CPU 0.48 ms (M0 0.76), 197 k primitives (263 k), 1488 objects (1514), 364 MB VRAM
(435), 782 nodes (766). Reference | M0 | M1: `visual-m1-side-by-side-2026-10-27.png`.

What changed:

- `godot/src/look.gd`: `PAL` (the art-direction tokens + `warn`), `FAMILY` + `paint()`, `STAGE`,
  `FLOOR`, `ARENA`, `env()`. `view.gd` places the lights; `part_view.gd` uses `env(true)`.
- **Key:** the only shadow caster, 0.5, neutral-warm, high (70°) and behind the camera, to its
  left. From M0's north-west angle its shine put a grey sheen on the lower half of the floor and
  turned the near oil slick white. A cool key under the navy fill turned the arena blue, while
  the reference's lit metal is neutral grey (`look_stats.py --palette`); `art-direction.md`
  updated.
- **Fill:** navy ambient at 1.0. **Follow spots:** kept, no shadows, no beams, 10 at 7° (M0: 45
  at 5°, shadowed). **Accents:** 17 unshadowed omni lights, energy 3, range 5 m: cyan at the 8
  pillar bases and the heal pad, cyan and orange in turn at the 8 wall corners. **Haze:** off
  (volumetric fog, the `FogVolume` and the `volume_size` project setting removed).
- **Tonemap:** AgX at Godot's defaults (white 16.29, contrast 1.25), exposure 1; the value targets
  are met with the lights. Contrast 1.5 was tried: floor too dark (p50 34–37, 57–62 % dark) and
  it changes how effects fade. **Glow:** intensity 0.5, threshold 2.2, as in M0.
- **Arena slots:** `dark` → gunmetal, `steel` → painted navy, `trim` → gunmetal in `steel` (pillar
  caps and tesla coils are no longer the brightest neutrals), `hazard` → hazard family,
  emissives → palette cyan, orange and heal, crusher warning → `warn`. The stadium slots and the
  oil slicks keep their old colors, now in `look.gd` (M2 maps them).
- **Floor:** plate albedo `steel` (the `floor` token as albedo renders near black), metal 0.6,
  roughness 0.35–0.6, per-plate tint 0.45, grime 0.75.

Left out: the **reflection probe.** Built and measured: at the game camera it changed the frame
by about 1/255 on average (nothing bright to reflect yet), cost 0.1 ms, took +510 MB VRAM with
Godot's default atlas (64 probes), and with it Godot 4.7.2 logs "7 RIDs of type Texture were
leaked" at exit, a new log line. Moved to M2, once strips give it something to reflect.

Three biggest gaps vs the reference after M1 (input for M2): no neon (0.3–0.4 % accents vs
3.35 %); a floor with soft grime clouds and a plate checker, no paint, bevels or sheen; oil
slicks that read as black holes on the dark floor. For M3: the lance and rail wind-up bar
(`aim_line`, glow 4.0) blooms; it should follow the bloom rule.

Process: run one Godot window at a time (two at once hung); sandbox stills need `--seed` (the
rival, and with it the K.O. tick, follows the seed).

## M2 — Arena

Scope: floor shader v2 (plate bevels, per-plate variation, painted lines, stencils, hazard bands
around crushers, pads and spawns, wear, sheen). Pillars v2 in `arena_build.py`: same octagon and
radius, cyan strips, orange lamps, hazard band, a dark top grille instead of the bright cap.
Walls and posts with cyan strips and orange lamps. Heal pad v2: octagonal base, cyan rim, hazard
chevrons, green cross kept. Oil slicks → glossy dark puddles. Tesla and crushers restyled with the
families; their warning behavior unchanged. The static reflection probe moved here from M1: add
it once the strips exist, with `rendering/reflections/reflection_atlas/reflection_count` cut to
what the arena uses, and check the exit log.

Victor's match (step 6, 2026-10-28): played one match on 6bd6b3f (M2 arena, M3 and the effects
follow-up, before M4): "Played it, the new effects feel good."

Acceptance (2026-10-27, code 41f43a4; numbers in the table below):
- [x] seeds 3 and 7, `--cam=0`: neon accents 1.5–5 %, cyan + blue ≥ 60 % of them, orange present,
      and the M1 value targets still hold. Seed 3: neon 2.10 %, 82 % of it cyan and blue, orange
      0.37 %; p50 45, dark 34.4 %, bright 0.38 % on the arena only. Seed 7: neon 1.77 %, 94 %,
      orange 0.11 %; p50 43, dark 42.5 %, bright 0.64 % on the arena only (2.75 % with the
      effects and your wind-up bar, fixed in M3).
- [x] every arena slot maps to a `look.gd` family; no new `Color8(` in arena code. The stadium
      slots now use palette colors and families too; their M0 literals are gone.
- [x] sizes and spots still from `sim.gd`; golden hash unchanged (`sim_rules` passes). The floor
      shader reads the pad, spawn, crusher, wall and oil positions and the oil radius from
      `sim.gd`.
- [x] `arena.glb` triangles ≤ M0 + 50 %: 23 432 (M0 22 732, +3 %)
- [x] stills: game camera `visual-m2-seed{3,7}-cam0-2026-10-27.png`, close camera
      `visual-m2-seed{3,7}-cam4-2026-10-27.png`, the whole arena `visual-m2-top-2026-10-27.png`
      (`tools/arena_shot.gd --top`); arena only `visual-m2-seed{3,7}-cam0-arena-2026-10-27.png`
- [x] GPU ≤ M0 + 1.5 ms: 2.69 / 4.10 ms (median of 3 runs; M0 3.21 / 4.43; the M1 code measured
      again the same day: 2.54–2.58); draw calls 801 (M0 1051)
- [x] gates: the 4 suites pass (3 + 5 + 15 + 13 tests) and print the same lines as on M1; the
      final look-check, arena-only and top-view runs log nothing (see "Exit lines" below)

| Still set | Luma p10 / p50 / p90 | Dark | Bright | Neon (cyan + blue / orange) | GPU ms avg / peak | Draw calls |
|---|---|---|---|---|---|---|
| seed 3, `--cam=0` | 27 / 45 / 60 | 34.4 % | 0.80 % | 2.10 % (1.72 / 0.37) | 2.69 / 4.10 | 801 |
| seed 7, `--cam=0` | 27 / 43 / 70 | 42.5 % | 2.75 % | 1.77 % (1.66 / 0.11) | — | — |
| seed 3, arena only | 30 / 45 / 59 | 33.8 % | 0.38 % | 2.30 % (1.88 / 0.41) | — | — |
| seed 7, arena only | 27 / 43 / 63 | 43.0 % | 0.64 % | 1.80 % (1.67 / 0.13) | — | — |

Also: render CPU 0.6 ms (M1 0.58 the same day), 208 k primitives (M1 197 k), 1611 objects (1487:
more material surfaces per prop), 364 MB VRAM (364), 781 nodes (782). Reference | M1 | M2:
`visual-m2-side-by-side-2026-10-27.png`. Garage: `visual-m2-garage-before-after-2026-10-27.png`
(the stand's ring uses the new neon material, a deeper cyan).

What changed:

- **Pillars** (`arena_build.py`): same octagon and radius. Gunmetal body with steel corner ribs, a
  hazard band at the base, one cyan strip per face, orange lamps under the cap on every other
  face, a dark grille on top (near-black plate, gunmetal bars, raised rim) instead of the bright
  cap, and a thin cyan ring on the floor around the base.
- **Walls and posts:** a cyan strip along the top of every wall panel (was orange); of each
  panel's two plates, one gets a vertical cyan strip and the other an orange lamp. Posts:
  gunmetal, a hazard skirt, 4 cyan strips, the orange lamp ring kept.
- **Heal pad:** octagonal base, a hazard band, a wide cyan rim and a cyan floor ring. The green
  ring and spinning cross stay (green = heal).
- **Tesla and crushers:** tesla base in hazard stripes, gunmetal body, a cyan floor ring; the idle
  orb glows at the strip level, its warning pulse is unchanged. Crusher heads in gunmetal with a
  hazard skirt; the plate keeps a hazard frame. The warning lights the hazard paint red with the
  same timing and energy as before.
- **Hazard stripes:** one shader for every `hazard` surface (`look.gd` `HAZARD_SHADER`): yellow and
  black 45° stripes in world space, chipped. The crusher warning is its `warn` uniform.
- **Neon:** the arena lights (`strip`, `pad`, `zap`, `vent`, `amber`) are `look.gd` `neon()`: a
  black surface that only emits, at energy 0.75 (`NEON`). Why: see the AgX note below.
- **Floor v2** (`view.gd` `FLOOR_SHADER`, knobs `look.gd` `FLOOR`): 4 m plates, a third of them
  split in four, dark seams with a soft bevel, per-plate tint and polish (35 % of the plates
  glossier), grime in patches and along the seams, scuffs. Chipped hazard bands around the 8 pads,
  the 2 spawns and the 4 crushers; a dashed yellow line 1 m inside the walls; three chevrons in
  front of each spawn, pointing at the center.
- **Oil slicks:** drawn by the floor shader (the disc meshes are gone): `grime` brown, roughness
  0.05, a wobbly edge around the sim radius, a thin-film rainbow rim, and a cyan accent light over
  each slick so the gloss shows a glint. They no longer read as holes.
- **Lights:** accent energy 4 (M1 3), range 4.5 (5); 19 accents, 2 of them new over the oil.
- **Stadium slots:** `concrete` navy, `tread` gunmetal, `aisle` and neutral seats steel (painted
  family), `roof` near-black gunmetal (also the pillar grille plate), floods in the follow-spot
  color, the screen `blue`, neutral LEDs cyan.
- The shaders share `look.gd` `NOISE` (hash, noise, fbm); `look.gd` `shader()` builds a shader
  material from a knob dict.

Left out:

- **Reflection probe** (moved here from M1): box-projected over the arena, static props only. Even
  with the strips it showed no visible reflections at the game camera; it lifted the floor evenly
  (seed 3 dark 32 % → 22 %, out of the target). Removed.
- **Screen-space reflections:** no visible change at the game camera (the reflected rays leave
  the screen), +34 MB VRAM. Removed. M4's "reflection strength" has nothing to tune unless a later
  look needs reflections.

Exit lines: 2 early seed-7 look-check runs printed "70 ObjectDB instances were leaked" and "38
resources still in use" at exit. Not seen again in 11 later runs (4 with `--verbose`), nor in 5
runs of the M1 code; no M2 resource was named. Watch for it.

Three biggest gaps vs the reference after M2 (input for M3 and M4): mechs with flat materials and
no rim, so they separate less from the busier arena (M3); a clean floor with no scorch, debris or
grates (M4); neon without halos: arena lights stay dim so AgX keeps them cyan, and effects stay
under the glow threshold ("punch, not glow"), while the reference's lights glow.

Process:

- **AgX turns bright lights white.** Cyan lights at energy 1.5–4, or lit by the key and the
  spots, came out about (160, 214, 228), saturation 0.3: pale, all alike, not counted as neon. On
  a black surface, seed 7 neon at energy 0.35 / 0.45 / 0.6 / 0.75 / 1.0 = 0.39 / 0.96 / 1.33 /
  1.36 / 1.12 %; 0.75 chosen. Tune emissives by measured saturation, not by eye.
- **Floor cost.** The first floor v2 cost 1.4 ms (the same frame with a flat floor: 2.2 ms). The
  oil maths now runs only near a slick, and M0's fbm bump on the floor normal is gone (the frame
  changed by 0.7/255 on average): 2.69 ms.
- `tools/arena_shot.gd` takes the arena-only stills (effects and the wind-up bar hidden) and the
  whole-arena view (`--top`).

## M3 — Robots and combat

Scope: mech materials (metal and roughness per slot, a rim term for separation, team-color
accents within the bloom rule). A team ground ring and a small overhead arrow per mech (meshes,
no text). Every effect family checked on the new floor in the sandbox; knobs tuned in `fx.gd`
only. The lance and rail wind-up bar (`mech.gd` `aim_line`, glow 4.0) brought under the bloom
rule (Victor, 2026-10-27).

Victor's match (step 6, 2026-10-28): played one match on 6bd6b3f (M2 arena, M3 and the effects
follow-up, before M4): "Played it, the new effects feel good."

Acceptance (2026-10-27, code d890fba; numbers in the table below):
- [x] the wind-up bar no longer blooms: sandbox still of a lance wind-up (`--sandbox=rivet --ult`,
      tick 30) and the same seed 7 frame as M2: `visual-m3-lance-before-after-2026-10-27.png`.
      With the bar and the effects on screen, seed 7 bright is now 0.79 % (M2 2.75 %): the 2 %
      target holds without hiding anything.
- [x] seeds 1–10 at tick 700, `--cam=0`: in all 10, both mechs are found and told apart by team
      (list below; `visual-m3-seeds-1-10-2026-10-27.png`). Checked at half size, harsher than play.
- [x] sandbox stills, `--seed=3` (`visual-m3-fx-2026-10-27.png`): `rivet` bolt at 60, `laser` ray
      at 55, `mortar` lob warning at 130 and boom at 160, `flamer` cone at 60, `saw` swing at 53,
      a dash (`rivet --dash`) at 86, plus the K.O. at 602 and the lance wind-up at 30. Each stands
      out from the floor and props. Weakest: the rivet bolt where it crosses the bright heal pad
      (the sandbox fights on the pad, at the arena center); over the floor it reads. No knob
      changed.
- [x] `FX_DESIGN.md` rules hold: no new fx kind, no effect changed, and the wind-up bar now
      follows rule 2 (flat, additive); `sound_test` passes
- [x] GPU ≤ M0 + 1.9 ms: 2.94 / 4.02 ms (median of 3 runs: 2.93, 2.94, 3.10; M2 2.69 / 4.10);
      draw calls 886 (M0 1051). The rim costs 0.24 ms and 81 draw calls (one run without it:
      2.70 ms, 805); rings and arrows cost nothing measurable.
- [x] gates: the 4 suites pass (3 + 5 + 15 + 13 tests, golden hash unchanged); `garage_parts`
      prints the same two headless "Parameter material is null" lines as M0–M2; the look-check
      runs log nothing new (see "Exit lines")

| Still set | Luma p10 / p50 / p90 | Dark | Bright | Neon (cyan + blue / orange) | GPU ms avg / peak | Draw calls |
|---|---|---|---|---|---|---|
| seed 3, `--cam=0` | 27 / 45 / 60 | 34.4 % | 0.76 % | 2.74 % (1.93 / 0.81) | 2.94 / 4.02 | 886 |
| seed 7, `--cam=0` | 27 / 43 / 71 | 42.6 % | 0.79 % | 2.32 % (2.08 / 0.24) | — | — |
| seed 3, arena only | 30 / 45 / 59 | 33.8 % | 0.39 % | 2.33 % (1.92 / 0.41) | — | — |
| seed 7, arena only | 27 / 43 / 63 | 43.1 % | 0.64 % | 1.81 % (1.68 / 0.13) | — | — |

The M1 and M2 targets still hold. The team rings count as neon accents: orange rose on seed 3
(0.37 → 0.81 %); cyan and blue are 70 % (seed 3) and 90 % (seed 7) of the accents. Also: render
CPU 0.69–0.86 ms (M2 0.6), 240 k primitives (208 k: the rim draws the mechs a second time), 1696
objects (1611), 364 MB VRAM (364), ~801 nodes (781). Reference | M2 | M3:
`visual-m3-side-by-side-2026-10-27.png`. Garage: `visual-m3-garage-before-after-2026-10-27.png`
(the grey parts read a little darker, as steel; the garage gets no rim and no markers).

Team check, seeds 1–10 (tick 700, `--cam=0`; your mech orange, the rival blue):

| Seed | Your mech | Rival | Note |
|---|---|---|---|
| 1 | lower middle | top, behind its shield flash | |
| 2 | top | middle, in hit sparks | |
| 3 | close fight | close fight | the rival's shield stands between them |
| 4 | top, by a pillar | lower middle, in smoke | weakest: your mech is small and a HUD callout sits on it |
| 5 | middle | top, inside an effect | |
| 6 | top, under a callout | lower middle | |
| 7 | top, in hit sparks | middle, under the lance bar | |
| 8 | close fight | close fight | |
| 9 | lower middle | top, under a callout | |
| 10 | top right | lower left | the thick ring reads apart from the thin cyan pad rings |

What changed:

- **Surfaces** (`mech.gd` `SKIN`): metal and roughness per slot. Body paint 0.35 / 0.4 (was 0.3 /
  0.5), steel trim 0.75 / 0.35 (0.55 / 0.5), joints 0.6 / 0.55 (0.4 / 0.6): the grey parts read
  as steel with highlights, and the team paint stands out against them. The `glow` slot (gun
  strips, saw marks) is a team-color light on a black base at 0.9; it was `TEAM_LIGHT` at 1.6,
  which AgX turned near white. Shared with the garage previews.
- **Rim** (`look.gd` `RIM`, `RIM_SHADER`): an additive overlay on every `.glb` part of a match
  mech. Each pixel checks the depth 2 px away in 8 directions; where the scene behind is more than
  0.6 m farther, it adds the team color at 0.7. A 2 px team edge around the outer silhouette at
  any zoom, none where the mech's own parts overlap. Not in the garage, and not in headless runs.
- **Team markers** (`view.gd` `MARK`, `mark()`): a ring on the floor (radius 0.9–1.12 m) and a ▼
  0.75 m wide, 2.9 m up, in the team color darkened by 30 %, unshaded, normal blend. Both float on
  their own (`top_level`), placed from the sim every tick: the ring stays on the floor during
  jumps, the ▼ follows `Sim.height_of`, a K.O. tilt moves neither, and the ▼ hides on a K.O.
  Ring, ▼ and rim switch off while the mech hides in smoke (`Sim.hidden`), so they never give a
  hidden mech away. Dash afterimages skip the markers and clear the rim (`Fx.ghost`).
- **Wind-up bar** (`mech.gd` `aim_line`): `Mech.flat(SKIN.aim, true)`, additive like the
  effects; same warm color, shape and fade. It was `Mech.glow` at 4.0.
- **Sandbox** (`main.gd`): `--ult` keeps your R charge full and fires the R skill whenever it can.
- Effects: no knob changed. Every family reads on the M2 floor.

Exit lines: "N ObjectDB instances were leaked" and "resources still in use" at exit came and went
between runs of the same command, on the M2 code too (2 of 20 runs before any M3 change, short
sandbox runs at tick 40) and after (2 of 25 final runs: mortar at 130, the K.O. at 602). Not from
M3; still not chased (M2: watch it).

Three biggest gaps vs the reference after M3 (input for M4 and M5): pickup icons fight the mechs
for attention (big, bright, saturated; the power-burst salmon is close to team orange) while the
hierarchy puts pickups at level 4. Not M3's scope: Victor chose "icons only" (2026-10-27); their
size and glow are one knob each (`ITEM.size`, the icon glow in `view.arena`). A clean floor with
no scorch, debris or grates (M4). HUD callouts ("¡BRAZO DERECHO ROTO!", "REPARACIÓN LISTA") sit
over the top of the play area and can cover a mech there (seeds 4, 6 and 9; M5). Smaller: team
blue sits close to the arena cyan (hue 208° vs 190°; the thick ring and the ▼ carry it), and the
aim reticle still blooms (`Mech.glow` at 3.0; M5).

Process:

- **Godot's rim does nothing here.** `StandardMaterial3D.rim` lights faces seen edge-on
  (`pow(1 - N·V, (1 - roughness) × 16)` per light). The mechs are flat-shaded boxes, and from the
  game camera no visible face is edge-on: rim 0.5 and 1.0 gave the same frame. The next native
  option, Godot 4.5's stencil outline, is experimental, sizes its outline in meters (thick in
  close-ups and the garage) and leaves gaps at box corners. The depth-based overlay has none of
  these.
- **Markers added as light came out pale.** Additive team rings at 0.8 measured saturation 0.46
  (orange) and 0.37 (blue), still 0.51 / 0.44 at 0.5: the floor under them adds grey and AgX
  desaturates. Solid and darkened by 30 %: 0.86 / 0.67, the body's own saturation.
- **Thin rings looked like pads.** The first ring (0.14 m wide, a 0.46 m ▼) read like the arena's
  thin cyan pad rings for the blue team, and the ▼ got lost when the camera zoomed out. Now 0.22 m
  and 0.75 m.
- **Headless runs skip the rim.** Godot's headless renderer logs "Parameter material is null" for
  the depth-reading overlay (6 extra lines in `garage_parts`), so `mark()` adds it only when there
  is a display. A windowed still with the check is the same as without it.

### M3 follow-up: pickups, R skills, dashes (Victor, 2026-10-27)

Victor after M3: "shrink pickup icons, and improve the effects for ultimates, and dashes".
Evidence: `visual-m3-pickups-before-after-2026-10-27.png`,
`visual-m3-ults-before-after-2026-10-27.png` (10 R skill moments, before | after),
`visual-m3-dash-before-after-2026-10-27.png` (ticks 3, 6, 9, 13 of a dash; top before).

What was wrong (all 18 R skills shot at the moment they fire and while they last):
- No R skill marked the moment it fired: the sim's `ult` event had no view.
- Deflect and Mirror had no visual at all. Overdrive and Berserk only tinted the body, which
  turned an orange mech pink and hid its team; Bubble's lit sphere turned it lavender.
- Stasis and Gravity Well drew big pale discs with blooming rims; Bastion's wall was a beige
  board (`TEAM_LIGHT` glow); Titan's mines glowed at 6.0.
- Dashes: additive afterimages piled up into a pale blob, and the flame trail came out beige.

What changed (details in `FX_DESIGN.md` build order 9):
- **Pickups:** `ITEM.size` 2.4 → 1.5, lift 2.2 → 1.6 m (gap 1 of M3; their glow is unchanged).
- **R skills:** `Fx.ult` on every release; auras for Overdrive, Berserk, Deflect (its 3 m zone)
  and Mirror (its 70° arc) in `mech.gd` `AURA`, no body tint; Bubble a thin shell; fields a faint
  fill, a crisp ring and a moving white ring (`Fx.FIELD`); the wall solid team color with a white
  top edge; mines a flat red light. Nothing on an R skill uses `Mech.glow` any more.
- **Dashes:** team afterimages with normal blend, darkened 25 %, every 3 ticks; white speed lines
  each tick; a flash and a wider ring at the start; booster trails at `RIBBON.gain` 0.45.

Checks: the 4 suites pass; no script errors in 20 sandbox runs; GPU 2.69 / 3.77 and 2.75 /
4.95 ms (2 runs, M3 median 2.94 / 4.02), draw calls 888 (886). Nodes 1029 (~801): the pooled
bars for speed lines and release bursts stay parked once made.

Process: the dash looked unchanged at first because the sandbox's thruster has a 5 s cooldown,
so `--dash` dashes once at the start; dash stills need ticks 1–13. Before/after stills came from
the committed code exported with `git archive` into a scratch folder (with its `.godot` import
cache copied), so both sides used the same ticks.

## M4 — Atmosphere

Scope: static scorch and debris decals (seeded, kept off pads, spawns and warning zones), grime
at wall bases, a few vents and grates, one low-count ambient particle system (dust or embers),
reflection strength tuned (no reflections after M2: probe and SSR left out).

Victor's picks (2026-10-28): dust, not embers (moving orange specks could read as flamer fire);
he had not played M2 yet when M4 started, so no M2 fixes went first (his match on M2 + M3
came later, see M3). M4 ran after M3, as planned. M4's own match (step 6) is still to come.

Acceptance (2026-10-27, code f36f50f; numbers in the table below):
- [x] no decor within 1.5 m of a pad, spawn or trap warning; nothing decorative moves on the
      floor. `Decor.clear` keeps every piece 1.5 m off the visible edge of each pad and the heal
      pad (band, 1.4 m), each spawn (chevrons, 4.7 m), each crusher (band, 2.0 m), each tesla's
      reach, each EMP vent strip and each oil slick; `garage_parts_test`
      `decor_keeps_off_pads_spawns_and_traps` re-checks every placement. Placed once from a fixed
      seed; only the dust moves, 0.6–4 m up. Whole arena: `visual-m4-top-2026-10-27.png`.
- [x] M1 and M2 look targets still hold on seeds 3 and 7: p50 45 / 42, dark 35.6 / 43.9 %, bright
      on the arena only 0.39 / 0.41 %, neon 2.73 / 2.31 % with cyan + blue 70 / 90 % of it,
      orange present (0.81 / 0.23 %)
- [x] GPU ≤ 5.0 ms average, 6.5 ms peak: 2.72 / 3.64 ms (median of 3 runs: 2.71, 2.72, 2.74;
      peaks 3.41, 3.66, 3.64). The same code with `Decor.build` switched off: 2.54 / 3.15, so M4
      costs ~0.18 ms and 3 draw calls. Draw calls 891 (M3 886, M0 1051).
- [x] gates: the 4 suites pass (3 + 6 + 15 + 13 tests; garage_parts has the new decor test),
      golden hash unchanged, the same log lines as before M4 (garage_parts' two headless
      "Parameter material is null", sound's exit leak); the look-check, arena-only and top-view
      runs log nothing, except one seed-7 look check (see "Exit lines")
- [x] stills: game camera `visual-m4-seed{3,7}-cam0-2026-10-27.png`, close camera
      `visual-m4-seed{3,7}-cam4-2026-10-27.png`, arena only
      `visual-m4-seed{3,7}-cam0-arena-2026-10-27.png`, the whole arena
      `visual-m4-top-2026-10-27.png`; reference | M3 | M4 and M2 | M4 from the top:
      `visual-m4-side-by-side-2026-10-27.png`

| Still set | Luma p10 / p50 / p90 | Dark | Bright | Neon (cyan + blue / orange) | GPU ms avg / peak | Draw calls |
|---|---|---|---|---|---|---|
| seed 3, `--cam=0` | 25 / 45 / 60 | 35.6 % | 0.81 % | 2.73 % (1.92 / 0.81) | 2.72 / 3.64 | 891 |
| seed 7, `--cam=0` | 26 / 42 / 71 | 43.9 % | 0.50 % | 2.31 % (2.08 / 0.23) | — | — |
| seed 3, arena only | 27 / 45 / 59 | 35.0 % | 0.39 % | 2.35 % (1.94 / 0.41) | — | — |
| seed 7, arena only | 26 / 42 / 63 | 44.5 % | 0.41 % | 1.83 % (1.68 / 0.16) | — | — |

Also: render CPU 0.63 ms, 242 k primitives, 1702 objects, 364 MB VRAM, 1032 nodes (M3's later
auras and speed lines added most of the nodes; decor adds 3).

What changed (`godot/src/decor.gd`, one call in `view.build`; knobs `D`):

- **Scorch marks:** 18, radius 1–2.2 m, a near-black core with a spiky edge and flecks (family
  Scorched: `grime` → `void`), each with up to 5 small `trim` metal scraps around it.
- **Grates:** 6 on 4 m plate centers, a `steel` rim and grid over `void` slots.
- **Grime at the wall bases:** a dark band along the walls wherever the keep-out allows: the
  corners and between the EMP vents.
- **Dust:** 160 pale `steel_hi` specks drifting slowly 0.6–4 m up, unshaded, normal blend, so
  they never bloom; `arena_shot.gd` hides them with the effects.
- **Reflection strength:** nothing to tune; M2 left out the probe and SSR.
- **Vents:** none added. The arena already has 24 EMP vents in the walls; decorative ones would
  look like hazards.

Exit lines: one seed-7 look check printed "84 ObjectDB instances were leaked" and "48 resources
still in use" at exit; the same run again with `--verbose` printed neither. M2 saw the same
on seed 7 before M4 existed. Still unexplained; watch it.

Process:

- **First pass read as smudges.** Soft round scorch blobs looked like soft shadows; the
  reference's marks are spiky splatters. Spikes from noise sampled on the direction (no seam at
  ±180°) plus flecks fixed it. Scraps in `dark` gunmetal read as holes, so they are `trim` steel
  now. Grates with bars only, in gunmetal, read as black boxes; a `steel` rim and a grid fixed
  that.
- **A perf run with other Godot windows open is not a measurement.** The first probe ran while
  two other Godot processes held the GPU at 99 %: 8.27 / 45 ms. Alone: 2.71.

Three biggest gaps vs the reference after M4: the floor has no wet sheen or reflections (left
out in M2); the neon has no halos (AgX and "punch, not glow"); the reference's floor is far
busier with debris and markings (stencils, numbers) than a readable game floor should be.

## M5 — HUD and polish

Scope: one bundled OFL font with Spanish glyphs; angled plates with cut corners; team-color score
plates; a more compact skill bar; clear callout colors (no muddy see-through text); the garage
uses the same plate style.

Victor's input (2026-10-28): the impact-numbers sheet `docs/reference/impact-numbers.webp` is
M5's reference for type and number colors. Its font ("Techno Condensed Bold") is not a real
font: Saira and Exo 2 (both SIL OFL, both with Spanish glyphs) were compared in the game,
`visual-m5-fonts-2026-10-28.png` and `visual-m5-fonts-closeup-2026-10-28.png`. Victor's pick:
Saira for the HUD, Exo 2 for the feedback in game (`Look.FONT.family` and `FONT.impact`). The
big calls (countdown, ¡A PELEAR!, K.O., VICTORIA) count as feedback: they share the numbers'
style. PAUSA is a menu, so it stays Saira. M5's own match (step 6) is still to come.

Acceptance (2026-10-28, numbers in the table below):
- [x] stills in English and Spanish, at 1280×720 and 1920×1080, with mouse and with pad
      captions: nothing overlaps or clips. Match HUD, all 8 combinations:
      `visual-m5-hud-2026-10-28.png`; countdown, fight, K.O., match over and pause in Spanish
      at 1280×720 and English at 1920×1080: `visual-m5-screens-2026-10-28.png`; garage:
      `visual-m5-garage-2026-10-28.png`. Seeds 4, 6 and 9 (M3: callouts over a mech): the
      callout plate sits above both mechs on all three.
- [x] every HUD string still goes through `i18n.gd`: one new key, `blocked` (BLOCKED /
      BLOQUEADO); the clock and the numbers are digits only
- [x] the font's licence file sits next to the font: `godot/assets/fonts/saira/OFL.txt` and
      `godot/assets/fonts/exo2/OFL.txt`
- [x] GPU ≤ M4 + 0.1 ms: 2.55 / 3.10 ms (median of 3 runs: 2.51, 2.55, 2.59; peaks 3.01,
      3.10, 4.12), measured before the Exo 2 split. Draw calls 888 (M4 891). After the split
      (it only changes the font of 2D text): 2.81 and 2.86 while other sessions' Godot runs
      started and stopped, 3.92 with a game window open. Not a measurement; a quiet A/B
      against the M4 commit is still to do.
- [x] gates: the 4 suites pass, golden hash unchanged, the same log lines as M4 (garage_parts'
      two headless "Parameter material is null", sound's exit leak at 14 / 10 on both the M4
      commit and M5); see "Exit lines"

| Still set | Luma p10 / p50 / p90 | Dark | Bright | Neon (cyan + blue / orange) | GPU ms avg / peak | Draw calls |
|---|---|---|---|---|---|---|
| seed 3, `--cam=0` | 26 / 45 / 60 | 35.6 % | 0.77 % | 2.72 % (1.91 / 0.80) | 2.55 / 3.10 | 888 |
| seed 7, `--cam=0` | 26 / 42 / 72 | 43.8 % | 0.45 % | 2.32 % (2.08 / 0.24) | — | — |
| seed 3, arena only | 26 / 45 / 59 | 35.9 % | 0.39 % | 2.33 % (1.92 / 0.41) | — | — |
| seed 7, arena only | 26 / 42 / 63 | 44.4 % | 0.40 % | 1.85 % (1.70 / 0.16) | — | — |

Also: render CPU 0.56 ms, 241 k primitives, 1706 objects, 398 MB VRAM (M4 364: the glyph
caches of three weights at many sizes and outlines), 1038 nodes. Stills:
`visual-m5-seed{3,7}-cam{0,4}-2026-10-28.png`, `visual-m5-seed{3,7}-cam0-arena-2026-10-28.png`;
reference | M4 | M5: `visual-m5-side-by-side-2026-10-28.png`; the sheet next to the game's
numbers: `visual-m5-numbers-2026-10-28.png`. The numbers and stills were taken with the M4
session's uncommitted floor-marks change (`fx.gd`, `FX_DESIGN.md`) on disk; the look numbers
match M4's within 0.05 points.

What changed (fonts and pop colors in `look.gd`, the HUD in `hud.gd`):

- **Fonts:** Saira (Omnibus-Type, variable weight 100–900 and width 50–125, plus its italic)
  for the HUD, the garage and the menus; Exo 2 (Natanael Gama, variable weight, plus its italic)
  for the feedback in game, at 900 italic. Each sits in `godot/assets/fonts/<family>/` with its
  `OFL.txt`. `Look.FONT` holds both families, Saira's width (87.5, semi-condensed; Exo 2 has no
  width axis) and three weights: text 600, bold 800, heavy 900. `Look.font(weight, italic,
  family)` returns one cached `FontVariation` with tabular digits (`tnum`, so the clock never
  jitters). `Look.ui()`, called first in `main.gd`, makes Saira's text weight the default of
  every Control and Label3D; the garage's and the HUD's bold come from `Look.font` too.
- **Impact numbers** follow the sheet: Exo 2 heavy italic, black outline and a two-step halo in their
  own color, `Look.POP`: hit white `#FFFFFF`, head hit orange `#FF8C28` and 20 % bigger (the
  game has no crits; head hits were already the special ones), heal green `#2DD66B` "+N", and a
  new blue `#2BA7FF` BLOCKED when a shield takes a hit (`view.guard`, at most every 20 ticks per
  mech, `BLOCK_GAP`). They pop in at 1.4×, rise 1.6 m, fade after 18 ticks and are gone at 45
  (`hud.gd` `NUMBER`). The view only records them (`view.pops`); the HUD draws them in 2D.
- **Plates:** every HUD plate is `Garage.plate` (cut corners), the same as the garage and the
  pause menu.
- **Score:** team-color tags on both sides of the clock with a pointed outer end and slanted
  round pips (like the reference's score plates); the clock reads m:ss.
- **Skill bar:** 6 slots of 84 × 58 (were 104 × 104), bold key caption, the name shrinks 11 → 8
  px to fit.
- **Callouts:** on a plate in their own color (sudden death orange, EMP blue, repair ready
  green; a broken part keeps its team color). A broken part shows under its owner's panel, arena
  calls under the clock. Countdown, ¡A PELEAR!, K.O. and VICTORIA are Exo 2 heavy italic with a
  black outline and a halo; PAUSA is Saira bold.
- **Aim reticle:** `Mech.flat`, so it no longer blooms (was `Mech.glow` at 3.0).
- **Look-check flags:** `--lang=en|es` and `--pad` (pad captions) for stills.

Process:

- **Godot names variable-font axes `weight` and `width`** (or the number tags); the strings
  `wght` and `wdth` are ignored without a warning. Saira's default instance is Thin (100), so a
  missing weight shows hairline text.
- **3D text goes through the tonemap.** The first numbers were `Label3D`s: AgX turned white
  grey and the orange brown. Drawn in the 2D HUD, the sheet's colors come out exact and the
  text is sharp at 1080p. `tools/arena_shot.gd` clears `view.pops` (it used to hide the
  `Label3D`s).
- **▲ and ▼** (garage stat arrows) are in neither Saira nor Exo 2; Godot draws them from a
  system font, as it did with the old fallback font.
- **Exit lines:** one 1280×720 Spanish garage shot printed "4 ObjectDB instances were leaked"
  and "1 resources still in use" at exit; the same run again printed nothing.

Three biggest gaps vs the reference after M5: the reference's corner panels are a portrait and
one bar, ours keep the wireframe with four armor readouts (they carry the part-break rules);
mechs carry a ▼ but no name tag; the minimap stays out (1v1).

## Done for the whole overhaul

- Arena, robots, materials, lighting and effects share `look.gd` and `FX_DESIGN.md`.
- Look numbers inside the targets on seeds 3, 7 and 11.
- Mechs and threats stand out from decoration (M3 check); effects come only from sim events.
- Conventions written down (`art-direction.md`, `visual-architecture.md`); tests pass; no new
  errors.
- Performance measured against the M0 baseline and within budget.
- Before/after composites and a short report at the end of this file.

## M0 baseline (merged code e9567dc = `main` after PR #8)

| Still set | Luma p10 / p50 / p90 | Dark | Bright | Neon | GPU ms avg / peak | Draw calls |
|---|---|---|---|---|---|---|
| seed 3, `--cam=0` | 52 / 98 / 150 | 4.1 % | 1.65 % | 0.02 % | 3.21 / 4.43 | 1051 |
| seed 7, `--cam=0` | 44 / 91 / 162 | 5.2 % | 3.89 % | 0.04 % | — | — |

Also: render CPU 0.76 ms, 263 k primitives, 1514 objects, 435 MB VRAM, 766 nodes. Stills:
`production/qa/evidence/visual-m0-baseline-seed{3,7}-cam{0,4}-2026-10-27.png`.

**Noise:** the same code measured 2.98 and 3.21 ms in two runs. When a result is within 0.3 ms
of its cap, take the median of 3 runs.

Pre-merge numbers are in `visual-audit.md` §2.
