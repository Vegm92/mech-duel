# Mech Duel — Effects and Particles

Goal (Victor, 2026-10-26): dynamic, impactful, **not bloomy**. Applies to the Godot view
(`godot/src/view.gd`, `godot/src/fx.gd`). The sim is untouched: everything an effect needs is
already in its `state.fx` entry.

## The rule: punch, not glow

Impact comes from timing, motion and contrast. Brightness is spent on one or two frames only.

1. **Three beats per hit.**
   | Beat | Time | What |
   |---|---|---|
   | Flash | 0–50 ms | small white core; the target's body flashes white (`mech.gd` stagger flash) |
   | Burst | 50–300 ms | streak sparks fly **away from the source**, long thin boxes aligned to velocity |
   | Settle | 0.3–2 s | grey smoke puffs, dark metal chips falling; floor marks on explosions |
2. **No glow on effects.** Effect materials are `Mech.flat(c, add)`: unshaded, no emission, alpha
   via vertex color. Energy (sparks, flashes, stars, beams, fire, tracers) uses `add = true`
   (additive blend): it reads as light on the dark arena and stays sharp. Smoke, chips and floor
   marks stay normal blend so they can be dark. Nothing passes `glow_hdr_threshold`, so no bloom.
   `Mech.glow` stays for the mechs' own lights (eyes, cores, boosters).
3. **Dark makes it pop.** Smoke and chips are grey and near-black, next to the bright burst.
4. **Weight scales everything.** `w = clamp(damage / 40, 0.2, 1.5)` drives count, speed, size,
   shake and hit-stop. Knobs live in `Fx.HIT` (and later one const per effect).
5. **Direction matters.** `hit.from` is the angle from the target toward the source. Sparks spray
   along `from + PI` with a narrow spread; they start on the side facing the source.
6. **Hit-stop.** `main.gd` freezes sim and view for a few physics frames; camera shake keeps going.
   | Event | Frames |
   |---|---|
   | head hit | 3 |
   | heavy hit (`w >= 1`) | 2 |
   | parry, part break | 4 |
   | K.O. | 8, then 0.3× slow-mo for 0.6 s |
7. **Color code.** Team color = whatever a mech fires: muzzle, tracer, and the sparks it makes on
   the target (with 2 teams the shooter is the other team; in FFA sparks are warm white). Orange
   = explosions and fire. Cyan = shield and energy. Green = heal. Purple = time and void.

## Look: crisp neon (Victor 2026-10-27)

Victor's reference sheet ("Neon Drift Arena VFX system": clean, readable, low poly, high impact)
sets the look. Saturated team colors on a dark arena, a white-hot core in the middle of every
bright thing, thin needle sparks, rings and starbursts. Read from it:

| Sheet | Ours |
|---|---|
| Blaster: muzzle starburst + dashed tracer | `Fx.muzzle` (flash + 4-ray `star` + needles + puff); bolts = bright head + 3 dashes (`DASHES` in view.gd) |
| Hit: directional sparks + white star flash | `Fx.hit`: flash, `star`, needles in the shooter's color away from the source |
| Damage number + hit marker | the number + a ring that opens at the hit point (`HIT.marker`) |
| Landing shockwave: ring | `Fx.ring`, used by boom; land/dash next |
| Armor break: metal fragments | chips today; break recipe next |
| Shield ripple, boost afterimage, grapple endpoint | not built yet |

Particle settings follow the Godot 4 particles guide (godot-mcp.abyo.net): high damping so
sparks start fast and stop short, scale curves that shrink sparks to nothing (`shrink`) or grow
smoke (`grow`), spin on debris, sphere emission for fireballs, box emission along beams.

## Sandbox

`--sandbox[=<weapon id>]` (main.gd): your mech and a target stand still `gap` apart (from the
weapon's range, `SANDBOX`), you fire at it every time the gun is ready, its armor refills, the
clock never runs out. ←/→ switch weapon (both hands), T toggles auto-fire, R fires your R skill
(`--core=<id>` picks it), F freezes, C close cameras, mouse wheel zooms. Combine with `--shot`
and `--at` for screenshots of any weapon.

## Recipes

| fx kind | Recipe |
|---|---|
| hit | flash + streaks (away from source) + 2–3 smoke puffs + chips when `w > 0.6` + damage number |
| boom | 1-frame fireball, thin fast floor shockwave ring, orange blobs turning into dark smoke, chips, scorch mark |
| muzzle | tiny team-color flash, 3 short forward streaks, small smoke puff |
| zap / beam | thin white core line + colored edge, 2-frame flicker, sparks at the far end |
| parry | cyan ring, bright "ting" streaks, hit-stop 4 — the best-feeling effect in the game |
| break | big chunks in the part's color, the mech trails black smoke for 3 s, hit-stop 4 |
| ko | hit-stop 8, slow-mo, big boom, a smoke column that stays |
| dash / land / crush | dust ring + streaks; land and crush leave a floor crack |
| heal / pickup | green squares floating up, no glow |
| emp | thin cyan ring expanding, sparks on every mech inside |

## Build order

1. **Done:** `Mech.flat`, the hit recipe (`Fx.hit`), hit-stop for head and heavy hits.
2. **Done:** neon look; muzzle, tracers, flame color by age, missile smoke trail, laser / lance /
   rail (`Fx.ray`), tesla lightning (`Fx.arc`), boom with floor scorch marks (`BOOM.marks` max,
   cleared each round), un-glowed mortar warning; the sandbox.
3. Directional shake (camera pushed along the hit line, not random jitter).
4. parry, break, ko (with slow-mo), land, dash, shield, hook endpoint.
5. Pool particle nodes if many hits per second cost frames (today each burst is a new node).

Later: chips bouncing on the floor; calming the white arena lamps, which are bloomy too.
