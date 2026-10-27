# Art Direction — Industrial Neon Arena

Target: `docs/reference/industrial-neon-arena.webp` (Victor, 2026-10-27). It sets the look; the
game camera sets the scale. This is a game to play, not a still to render: when the two pull
apart, reading the fight wins.

**The look in one line:** dark, worn industrial metal under a cool overhead light; small cyan and
orange lights trace the structure; team colors and effects are the brightest, most saturated
things on screen.

## Visual hierarchy

What must win attention, in order:

1. Mechs: where they are, where they face, how they move.
2. Projectiles, hits, damage, incoming threats (mortar rings, tesla and crusher warnings, EMP).
3. Arena geometry and walkable space (cover vs floor).
4. Pickups and interactive pads.
5. Detail and atmosphere.

Rules that enforce it:

- Only levels 1–2 may be bright *and* saturated at once. Environment emissives stay small (thin
  strips, lamps) and dimmer than team colors.
- Big surfaces (floor, pillar tops, walls) stay dark to mid value. No prop surface is brighter
  than a mech body.
- Nothing decorative on the walkable floor has a mech's size, color or motion.
- Warnings use warning colors (red/orange, EMP cyan), never a team color.
- A detail that fights a mech for attention at the game camera is removed or toned down.

## Palette

Measured from the reference (median color of each band), turned into tokens. In code they live in
one place, `look.gd` (Milestone 1); no other file hard-codes environment colors.

| Token | Hex | Role |
|---|---|---|
| `void` | `#09080d` | deepest shadow, outside the arena |
| `floor` | `#141418` | darkest floor tone the eye reads (seams, grime); the plates' albedo is `steel`, since `#141418` as albedo renders near black under a light that keeps the mechs in range (M1) |
| `gunmetal` | `#29262d` | structures: pillar bodies, walls, frames (the reference's median metal) |
| `steel` | `#54586c` | raised trim, edges, bolts |
| `steel_hi` | `#7090a1` | edge catch-light (comes from lighting, not paint) |
| `navy` | `#273149` | cool fill in shadow, ambient tint |
| `grime` | `#332426` | warm dirt, scorch edges |
| `cyan` | `#2bb6dd` | main emissive: strips, pad rings, structure lines |
| `blue` | `#2e84da` | second emissive, deeper accents |
| `orange` | `#d38c42` | lamps and hazard lights, small |
| `hazard` | `#c9a23e` | painted hazard stripes (the reference's `#fbd24b`, toned down for paint) |
| `heal` | `#4edb69` | heal cross, stays green (`FX_DESIGN.md`: green = heal) |
| `warn` | `#ff3c28` | warning lights only (crusher warning); never decoration, never a team color |

Team colors stay `Mech.TEAM` (orange, blue, green, purple). The reference's player colors (blue,
red, green, yellow) are an open option, not adopted (`visual-audit.md` §7.3).

**Value targets** for the play area at the game camera (method in `visual-audit.md` §2):
luma p50 35–60, 30–55 % of pixels below 40, bright (> 200) ≤ 2 %, neon accents 1.5–5 %, cyan and
blue at least 60 % of the accents. Reference: 45, 42 %, 1.0 %, 3.35 %, 84 %.

## Materials

Shared families: one material per family, variants by parameter, never one material per object.

| Family | Base color | Metallic | Roughness | Emission energy | Used on |
|---|---|---|---|---|---|
| Structural gunmetal | `gunmetal` | 0.6–0.8 | 0.35–0.55 | — | pillars, posts, crusher frames, tesla bases |
| Dark floor metal | `floor` | 0.5–0.7 | 0.3–0.6 (grime raises it) | — | floor plates |
| Painted metal | dark grey or navy paint | 0.1–0.3 | 0.5–0.7 | — | wall panels, pad bodies |
| Hazard stripes | `hazard` + black, 45° | 0.1–0.2 | 0.6–0.8, worn | — | edges of danger: crushers, pad rims, spawn lines |
| Emissive cyan | `cyan` on a black base | 0 | — | 0.75 (`look.gd` `NEON`) | strips, rings |
| Emissive blue | `blue` on a black base | 0 | — | 0.75 | second strips |
| Emissive orange | `orange` on a black base | 0 | — | 0.75 | lamps, hazard lights |
| Oil | `grime`, a thin-film rainbow rim | 0 | 0.05 | — | oil slicks, drawn by the floor shader |
| Scorched | `grime` → near black | 0.2 | 0.8–0.95 | — | scorch marks, burned edges |
| Mech paint | team color (`Mech.TEAM`) | 0.35 | 0.4 | — | mech bodies (`mech.gd` `SKIN`) |
| Mech steel | `Mech.STEEL` | 0.75 | 0.35 | — | mech trim: pads, frames, guns |
| Mech joint | `Mech.DARK` | 0.6 | 0.55 | — | joints, grips, cables |
| Team accent | team color on a black base | 0 | — | 0.9 | the `glow` slot: gun strips, saw marks |

- **No textures today** (and no UVs). Wear, grime and scratches come from procedural noise in
  shared shaders (world or object space) and from bevels in the Blender build scripts. Painted
  textures need UV unwrapping first: out of scope unless chosen.
- **Bloom budget:** emission above the glow threshold only on the emissive families and on mech
  eyes, cores and boosters. The threshold stays above what stacked additive effects reach
  (today 2.2), so effects never bloom.
- **Arena lights stay dim (M2):** AgX turns a brighter light, or one lit by the scene's lights,
  near white (saturation ~0.3), so it stops reading as cyan or orange. Arena lights are a black
  surface that only emits, at 0.75 (`look.gd` `neon()`); none of them blooms.
- **Effects** keep `FX_DESIGN.md`: unshaded, additive, no emission. The lance and rail wind-up
  bar follows it too since M3 (`Mech.flat`, was a glow at 4.0).
- **Mechs (M3):** a team-color rim lights each mech's outer edge wherever the floor or a prop is
  behind it: screen space, about 2 px at any zoom (`look.gd` `RIM`, in a match only). Godot's own
  rim light does nothing on the flat-shaded parts. Under every mech, a ring on the floor; over
  its head, a small ▼ (`view.gd` `MARK`). They are solid, unshaded team color at 70 %: added as
  light, the same color came out pale under AgX (saturation 0.37–0.46); solid, it keeps the
  body's saturation (0.67–0.86). Ring, ▼ and rim switch off while a mech hides in smoke
  (`Sim.hidden`), so they never give a hidden mech away.

## Lighting

- **Key:** one directional light from high above, the only shadow caster. High enough that
  shadows stay short and never read as geometry. It comes from behind the camera (the camera
  never rotates), so its shine never reflects off the floor into the view. Neutral to slightly
  warm white: the reference's lit metal is neutral grey, and a cool key under the navy fill
  turned the whole arena blue (M1).
- **Fill:** low navy ambient, so shadow sides stay readable.
- **Accents:** cyan and orange omni or spot lights without shadows at walls, pillar bases, the
  heal pad and over the oil slicks: low energy, short range. They make the local cyan and orange
  pools on the floor seen in the reference, and give the oil a glint.
- **Follow spots** (if kept): soft, unshadowed, a gentle lift on each mech, no visible beams.
- **Haze:** none, or barely visible. Clear air over the floor.
- **Reflections:** none for now. A static reflection probe and screen-space reflections were both
  tried in M2: neither showed at the game camera, and the probe lifted the whole floor out of the
  value targets.
- **Tonemap:** AgX. Exposure, contrast and white point tuned to the value targets.

## Combat effects

The spec stays `FX_DESIGN.md`: punch, not glow; flash, burst, settle; the shooter's team color.
This overhaul only checks that effects read on the new floor and adjusts their knobs. Muzzle,
projectile, boost, impact and explosion effects already exist and are fired by real sim events.

R skills and dashes (Victor, 2026-10-27): every R skill marks the moment it fires (team ring,
star, spikes); lasting ones show an aura or a zone in their element color (purple Overdrive and
Gravity Well, red Berserk, cyan Deflect, Stasis and Bubble, white Mirror), never a tint over the
mech, so the team color stays. Zones are a faint fill with a crisp ring, never a bright disc.
Pickup icons are smaller (`view.gd` `ITEM.size` 1.5, was 2.4): level 4 must not outshine a mech.

## HUD

- Dark see-through plates with cut corners and angled edges, thin cyan lines, orange highlights, a
  team-color strip per player (the existing `Garage.plate` style, pushed toward the reference).
- One bold, condensed sans with clear digits, bundled, under an open licence (SIL OFL), with
  Spanish glyphs. Numbers big, labels small and uppercase.
- Top center: clock and round pips on team-color plates. Top corners: the two mech panels.
  Bottom: a compact skill bar.
- Every string goes through `i18n.gd`, in English and Spanish.

## Scale and silhouette

- 1 unit = 1 m. A mech is ~2 m tall and ~70–100 px at 1080p at the game camera.
- What reads at the game camera, in order: silhouette, value, color, detail. Shapes under ~0.3 m
  vanish; spend geometry on silhouettes and big material zones.
- Sizes and positions the sim knows (pillars, pads, traps, walls) never change for looks.

## Don't

- Fog or glow over the play area.
- Big bright surfaces: pillar caps, white floor lines.
- Gameplay features copied from the reference (minimap, 4 HUD panels) without a decision.
- One material per object, or colors outside the palette.
