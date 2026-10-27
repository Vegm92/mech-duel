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

Acceptance:
- [ ] the wind-up bar no longer blooms: sandbox still of a lance wind-up
- [ ] seeds 1–10 at tick 700, `--cam=0`: in every still both mechs can be found and told apart
      by team at a glance (eye check, list kept in this file)
- [ ] sandbox stills for `rivet` (bolt), `laser` (ray), `mortar` (lob), `flamer` (cone), `saw`
      (melee), a dash and a boom: each effect stands out from floor and props
- [ ] `FX_DESIGN.md` rules hold; `sound_test` passes (no new fx kinds without sounds)
- [ ] GPU ≤ M0 + 1.9 ms
- [ ] gates

## M4 — Atmosphere

Scope: static scorch and debris decals (seeded, kept off pads, spawns and warning zones), grime
at wall bases, a few vents and grates, one low-count ambient particle system (dust or embers),
reflection strength tuned (no reflections after M2: probe and SSR left out).

Acceptance:
- [ ] no decor within 1.5 m of a pad, spawn or trap warning; nothing decorative moves on the floor
- [ ] M1 and M2 look targets still hold on seeds 3 and 7
- [ ] GPU ≤ 5.0 ms average, 6.5 ms peak
- [ ] gates

## M5 — HUD and polish

Scope: one bundled OFL font with Spanish glyphs; angled plates with cut corners; team-color score
plates; a more compact skill bar; clear callout colors (no muddy see-through text); the garage
uses the same plate style.

Acceptance:
- [ ] stills in English and Spanish, at 1280×720 and 1920×1080, with mouse and with pad
      captions: nothing overlaps or clips
- [ ] every HUD string still goes through `i18n.gd`
- [ ] the font's licence file sits next to the font
- [ ] GPU ≤ M4 + 0.1 ms
- [ ] gates

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
