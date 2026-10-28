# Visual Audit — Industrial Neon Arena

Phase A of the visual overhaul, 2026-10-27. Look only: no game file was changed.
Target image: `docs/reference/industrial-neon-arena.webp` (Victor, 2026-10-27).
Companions: `art-direction.md` (the target look), `visual-architecture.md` (how the visuals are
built), `visual-plan.md` (milestones and acceptance criteria).

## 1. What was checked, and how

- **Code:** `godot/src/main.gd` (camera, look-check flags), `view.gd` (environment, lights, floor,
  arena, projectiles, effect dispatch), `mech.gd` (material helpers, team paint, mech build),
  `fx.gd` (effects), `hud.gd`, `garage.gd`, `part_view.gd`, `godot/project.godot`, the `.glb`
  import settings.
- **Blender:** all 9 `art/*.blend`, opened headless and read-only: collections, triangles,
  materials, build scripts, linked libraries.
- **Runtime:** the real game on autopilot (`--autopilot --seed=3`), 1920×1080, Godot 4.7.2
  Forward+ on Vulkan, NVIDIA RTX 4070 Laptop GPU. Stills at tick 700; 30 s timing runs with
  `--print-fps` and a probe script (GPU timer + render monitors, §2).
- **Two working copies**, because the arena is being reworked in two places at once (§7.1):
  - `games/mech-duel` on `feat/stadium-lighting` (491b057): follow spots, haze, steel deck floor.
  - `games/mech-duel-stadium` on `feat/stadium-polish` (9842907): stadium bowl, EMP zones,
    pickup icons.

## 2. Baseline

Retained shots, all in `production/qa/evidence/`:

| Shot | File |
|---|---|
| stadium-lighting, game camera, tick 700 | `godot-visual-baseline-cam0-2026-10-27.png` |
| stadium-lighting, close camera (`--cam=4`) | `godot-visual-baseline-cam4-2026-10-27.png` |
| stadium-lighting, game camera, tick 1800 | `godot-visual-baseline-perf-2026-10-27.png` |
| stadium-polish, game camera, tick 700 | `godot-visual-baseline-polish-cam0-2026-10-27.png` |
| reference vs both | `godot-visual-baseline-vs-reference-2026-10-27.png` |

### Look numbers

Measured on the play area only: a center crop (x 20–80 %, y 25–80 %) that leaves out most of the
HUD. Luma = Rec.709 on sRGB, 0–255. A *neon accent* pixel has HSV saturation > 0.5 and value > 0.6.

| | Luma p10 / p50 / p90 | Dark (< 40) | Bright (> 200) | Neon accents | Cyan/blue part | Mean saturation |
|---|---|---|---|---|---|---|
| Reference | 15 / 45 / 91 | 42 % | 1.0 % | 3.35 % | 2.80 % | 0.38 |
| stadium-lighting | 52 / 98 / 150 | 4 % | 1.6 % | 0.02 % | 0.00 % | 0.21 |
| stadium-polish | 4 / 6 / 62 | 88 % | 1.8 % | 0.17 % | 0.05 % | 0.71 |

In plain words: stadium-lighting is twice as bright as the reference and has no neon.
stadium-polish is a near-black navy void, also without neon. The reference sits in between: dark
metal you can still read, plus small bright cyan accents.

### Performance (30 s autopilot, seed 3, 1080p)

| | GPU ms avg / peak | Render CPU ms | Draw calls | Primitives | Objects | VRAM |
|---|---|---|---|---|---|---|
| stadium-lighting | 2.71 / 3.22 | 0.63 | 945 | 116 k | 1409 | 434 MB |
| stadium-polish | 2.10 / 2.62 | 0.45 | 663 | 157 k | 1120 | 364 MB |

`--print-fps` on stadium-lighting with vsync off: 319–369 FPS (2.7–3.1 ms a frame). There is a
lot of room, but on one fast GPU only. Budgets are in `visual-plan.md`.

The probe reads `RenderingServer.viewport_get_measured_render_time_gpu/cpu` and the
`Performance` monitors `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`,
`RENDER_TOTAL_OBJECTS_IN_FRAME`, `RENDER_VIDEO_MEM_USED`, `OBJECT_NODE_COUNT`, averaged from 8 s to
38 s after start. Both scripts are in the repo since M0: `tools/perf_probe.gd`,
`tools/look_stats.py`.

## 3. Tools: what really works

| Tool | Status | Can | Limits |
|---|---|---|---|
| Blender MCP (`mcp-for-blender` 2.2.4, add-on 1.8, protocol 15) | Connected to Blender 5.2.3 LTS while Blender is open | any `bpy` code (`execute_blender_code`), scene facts (`get_scene_info`), pictures of the viewport or of objects from several angles (`look`) | asset libraries (Poly Haven, Sketchfab, Poly Pizza) and all AI generators are off; fails when Blender is closed; works on Victor's live file, so opening a .blend through it can leave edits in his session |
| Blender headless (`blender.exe -b`) | Works | open a .blend, run its build script, export, without touching the open file (how `arena.glb` is made) | no picture unless rendered |
| Godot MCP | Not configured in this environment: no tools exist | — | no live scene tree, no editor control |
| Godot CLI 4.7.2 (console exe) | Works | look checks (`--autopilot --seed --shot --at --cam`, part flags, `--sandbox`, `--parts`, `--garage`), `--resolution`, `--print-fps`, headless tests, `-s` probe scripts | stills at chosen ticks only; no flag for FFA or 2v2 (the Godot loop is 1v1); nobody plays it live |
| Python + Pillow + NumPy | Works | the look numbers above, side-by-side composites | no meaning-aware diff: the numbers back up an eye check, they don't replace it |

What this means for the work:

- **Visual check** = fixed look-check stills (same seed, tick, camera, resolution) before and
  after, plus the look numbers and the perf probe. Claude can't play or hear the game; feel stays
  with Victor.
- **Blender work** goes through the build scripts, run headless (repeatable). The MCP is for
  looking at results and quick probes.
- **The export step is not scripted.** No build script contains its glTF export call (all 9
  checked); the settings exist only in past sessions. Repeatable rebuilds need a shared export
  script. Done in M0: `tools/blender_export.py` reproduces all 9 `.glb` files.
- **Post-cutoff engine APIs** (4.6 glow before tonemapping, AgX white point and contrast,
  reworked SSR; 4.7 `AreaLight3D`) are checked in `docs/engine-reference/godot/` or the 4.7 docs
  before use.

## 4. What exists today

| Area | Today | Where |
|---|---|---|
| Renderer | Forward+, MSAA 3D 2×, physics interpolation, 1280×720 `canvas_items` / `expand` | `godot/project.godot` |
| Scenes | One node (`Main`); everything else is built in code. No `.tscn` or `.tres` assets | `main.tscn`, `main.gd` |
| Camera | Pitch 60°, FOV 40°, follows the midpoint of both mechs at 28–64 m, dead zone 1.5 m, never rotates (hard rule), K.O. zoom, shake + directional kick | `main.gd` `follow`, `place_camera` |
| Environment | AgX, glow (intensity 0.5, HDR threshold 2.2), SSAO, volumetric fog + one FogVolume haze, sun with shadows, 4 shadowed follow-spot towers (stadium-lighting) | `view.gd` `build`, `STAGE` |
| Garage 3D | Its own Environment (AgX, glow) and camera-fixed light | `part_view.gd` `env()` |
| Floor | One procedural shader: 4 m plate seams, 2 m / 10 m lines, grime noise, scuffs, noise bump | `view.gd` `FLOOR_SHADER` |
| Arena props | Octagonal pillars, tesla pylons, crushers, heal pad, item pads, vents, wall panels, posts, crowd fan. stadium-polish adds the stadium bowl, light towers, pickup icons | `art/arena.blend` → `arena.glb` (3.8 k tris; 22.7 k on stadium-polish) |
| Mechs | Light-frame chests + 10 heads, 18 cores, 6 arms, 10 legs, 6 boosters, 20 weapons; flat-color slots painted per team in code | `art/*.blend` → `*.glb`, `Mech.paints` |
| Materials | `Mech.mat` (StandardMaterial3D cached by color/emit/metal/rough), `Mech.glow` (emissive), `Mech.flat` (unshaded, optional additive: every effect), `view.ARENA` (arena slots); 4 inline shaders (floor, crowd, smoke, fire) | `mech.gd`, `view.gd`, `fx.gd` |
| Effects | 25+ recipes, one knob dict each, pooled nodes, CPU particles, hit-stop, slow-mo, shake. "Punch, not glow": effects never bloom | `fx.gd`, `FX_DESIGN.md` |
| HUD | Drawn in `_draw`: 2 mech panels (wireframe + armor bars), clock + round pips, 6 skill slots, callouts. Fallback font. Plates shared with the garage (`Garage.plate`) | `hud.gd`, `garage.gd` |
| Textures | None. No UVs, except the crowd fan (UV.x tags body parts) | — |
| Tests | `sim_rules_test`, `garage_parts_test`, `sound_test`, `hype_test`, run by hand (no CI in this repo) | `godot/tests/` |

## 5. Reuse, improve, replace, create

**Reuse as is**
- The material-by-name contract (`Mech.add_part` swaps slots by name): the right hook for shared
  material families.
- `Mech.mat` cache; `Fx` recipes, knobs and pools; the one effect path `state.fx` →
  `view.spawn` → `Fx.*` (gameplay events already drive effects through one interface); smoke and
  fire noise shaders; scorch marks; crowd MultiMesh; build scripts; look-check flags.
- The octagonal pillar silhouette (already the reference's shape), the central heal pad, team-color effects.

**Improve**
- Floor shader: darker base, plate bevels, painted lines, hazard bands, sheen.
- Environment: exposure, haze, light rig, bloom threshold, in one builder for arena and garage.
- Pillars, walls, heal pad, tesla, crushers: same silhouettes and sizes, better material zones
  (cyan strips, orange lamps, hazard paint, grilles).
- Mech materials: metal and roughness, a rim term to lift them off the floor, team-color accents.
- HUD styling: font, angled plates, team-color plates, callout colors.

**Replace**
- Oil slicks: big flat grey and purple discs that read as holes → a glossy dark puddle material.
- Four shadow-casting follow spots with fog beams (the grey wash) → one shadowed key light plus
  unshadowed accent lights.
- The fallback font → one bundled open-licence font.

**Create**
- One shared palette + material families + environment builder (`look.gd`, see
  `visual-architecture.md`).
- Floor stencils, static scorch and debris decals, vents and grates, only off the play lines.
- Team readability markers: a ground ring and an overhead arrow per mech.
- Repo tools: perf probe, look-numbers script, Blender export script.

## 6. Biggest gaps vs the reference, by impact

1. **Value structure.** stadium-lighting: grey haze and white spots flatten everything (p50 98
   vs 45, 4 % dark vs 42 %). stadium-polish: crushed to black (p50 6); the floor reads as empty
   space. Neither has a lit, dark-metal middle.
2. **No neon.** 0.02–0.17 % accent pixels vs 3.35 %. Almost no emissive strips, lamps or rim
   light; the only bright saturated things are effects and the heal cross.
3. **The floor has no material.** No visible plates, bevels, paint, hazard bands, wear or
   reflections at the game camera. The floor fills ~60 % of the frame, so it sets the look.
4. **Mech readability.** Mechs are ~70–100 px tall at 1080p. The blue rival sits on blue-grey
   haze (stadium-lighting) or navy (stadium-polish). Nothing on the ground ties a mech to its
   player.
5. **Props pull the eye.** Pillar caps are the brightest neutral in the frame (light-grey
   octagons) and the tesla coils are white stacks. Both outshine the mechs, against hierarchy
   rule 1.
6. **Oil slicks** look like holes or blobs.
7. **Shadow noise** (stadium-lighting): four moving follow-spot shadows paint big dark blades
   across the floor that read as geometry.
8. **HUD** works but looks generic: fallback font, flat navy boxes, a big skill bar (6 × 104 px),
   muddy see-through callouts ("¡A PELEAR!" in brown-grey). Its cyan/orange coding already
   matches the reference.
9. **Materials** are flat colors with even roughness: no edge wear, grime or scorch on props,
   and little metallic response because nothing bright surrounds them to reflect (no reflection
   probe, no SSR).
10. **Cost of the current rig:** 945 draw calls for a simple scene, vs 663 on stadium-polish
    (no shadowed spots, more geometry). The 4 spot shadow passes are the likely main cause.

## 7. Conflicts and decisions for Victor

1. **Two arena branches at once.** `feat/stadium-lighting` (this folder: bright, hazy) and
   `feat/stadium-polish` (`games/mech-duel-stadium`: dark, stadium bowl) both rewrite `view.gd`
   (146 and 164 changed lines vs `main`) and `mech.gd`, and pull the look in opposite directions. The
   overhaul starts after both are merged into `main` (or one is dropped). This folder also holds
   uncommitted sound wiring (`main.gd`, `hud.gd`, `garage.gd`, `crowd_sound.gd`, `i18n.gd`,
   `CLAUDE.md`, ~87 lines) and untracked sound files that already reached `main` in PR #5.
2. **Bloom.** `FX_DESIGN.md` (Victor 2026-10-26): effects never bloom ("punch, not glow"). The
   reference glows everywhere. Recommended: keep the rule for effects; let only environment
   emissives (strips, lamps) and mech eyes, cores and boosters bloom, gently. Revisit after the
   arena is darker, where additive effects read better on their own.
3. **Team colors vs environment accents.** Team 0 is orange, like the hazard lamps; team 1 is
   blue, like the cyan/blue strips. The reference players are blue, red, green, yellow.
   Recommended: keep `Mech.TEAM` (Victor's orange robot, the garage, the crowd, tests), keep
   environment orange and cyan small and darker than the mechs, and add a team ground ring and
   arrow per mech.
4. **Reference features the Godot loop doesn't have:** 4 players, 4 corner panels, a minimap,
   4-team score plates. The Godot main loop is 1v1 (`CONTEXT.md`). They stay out unless a
   4-player mode is planned; the HUD takes the reference's style for the 2 existing panels.
5. **Haze and follow spots** (stadium-lighting, committed minutes before this audit) vs the
   reference's dark, clear air. Recommended: keep the follow-spot idea as a soft, unshadowed
   lift on each mech, with almost no haze.
