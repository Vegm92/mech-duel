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
3. **Numbers:** look numbers on the `--cam=0` stills; perf probe, 30 s, seed 3.
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
  commit e9567dc, PR #8. Merging PR #8 into `main` is Victor's step: auto mode won't merge into
  `main`.
- `games/mech-duel` was left untouched (Victor declined stashing it). Its uncommitted sound
  wiring matches `main`, apart from a PowerShell command block in `CLAUDE.md`, now carried over
  on this branch.
- Tools in the repo: `tools/perf_probe.gd`, `tools/look_stats.py`, `tools/blender_export.py`.
- `feat/visual-overhaul` cut from e9567dc (the same files `main` gets from PR #8), in
  `games/mech-duel-visual`.

Acceptance:
- [ ] `main` holds both stadium branches: waiting on PR #8 (polish is in through PR #7)
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

Acceptance:
- [ ] seeds 3 and 7, `--cam=0`: luma p50 35–60, dark (< 40) 30–55 %, bright (> 200) ≤ 2 %
      (neon targets wait for M2: no strips yet)
- [ ] both mechs clearly lighter or more saturated than the floor around them in all 4 stills
- [ ] the garage previews use the same `env()` (garage still)
- [ ] no effect blooms: sandbox stills of `laser`, `mortar` and a K.O. look as before apart from the background
- [ ] no environment color literals left in `view.gd` `build` or `part_view.gd` (`grep Color`)
- [ ] GPU ≤ M0 + 0.8 ms; draw calls ≤ M0
- [ ] gates

## M2 — Arena

Scope: floor shader v2 (plate bevels, per-plate variation, painted lines, stencils, hazard bands
around crushers, pads and spawns, wear, sheen). Pillars v2 in `arena_build.py`: same octagon and
radius, cyan strips, orange lamps, hazard band, a dark top grille instead of the bright cap.
Walls and posts with cyan strips and orange lamps. Heal pad v2: octagonal base, cyan rim, hazard
chevrons, green cross kept. Oil slicks → glossy dark puddles. Tesla and crushers restyled with the
families; their warning behavior unchanged.

Acceptance:
- [ ] seeds 3 and 7, `--cam=0`: neon accents 1.5–5 %, cyan + blue ≥ 60 % of them, orange present,
      and the M1 value targets still hold
- [ ] every arena slot maps to a `look.gd` family; no new `Color8(` in arena code
- [ ] sizes and spots still from `sim.gd`; golden hash unchanged
- [ ] `arena.glb` triangles ≤ M0 + 50 %
- [ ] stills: game camera, close camera, and a wide top view of the whole arena
- [ ] GPU ≤ M0 + 1.5 ms
- [ ] gates

## M3 — Robots and combat

Scope: mech materials (metal and roughness per slot, a rim term for separation, team-color
accents within the bloom rule). A team ground ring and a small overhead arrow per mech (meshes,
no text). Every effect family checked on the new floor in the sandbox; knobs tuned in `fx.gd`
only.

Acceptance:
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
reflection strength tuned.

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
