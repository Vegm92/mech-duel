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
| Landing shockwave: ring | `Fx.land` |
| Boost dash: afterimage + ground streak | `Fx.ghost` + `Fx.dash` |
| Armor break: metal fragments | `Fx.shatter` |
| Destruction: debris + energy shards | `Fx.ko` |
| Shield ripple, grapple endpoint | `Fx.ripple`, `Fx.hooked` + team-color cable (`view.tether`) |

Particle settings follow the Godot 4 particles guide (godot-mcp.abyo.net): high damping so
sparks start fast and stop short, scale curves that shrink sparks to nothing (`shrink`) or grow
smoke (`grow`), spin on debris, sphere emission for fireballs, box emission along beams.

## Sandbox

`--sandbox[=<weapon id>]` (main.gd): your mech and a target stand still `gap` apart (from the
weapon's range, `SANDBOX`), you fire at it every time the gun is ready, its armor refills, the
clock never runs out. ←/→ switch weapon (both hands), T toggles auto-fire, R fires your R skill
(`--core=<id>` picks it), F freezes, C close cameras, mouse wheel zooms. G (`--guard`): the target
raises a perfect shield before each shot lands (parry). K (`--norefill`): armor stops refilling, so
parts break and the target gets K.O.'d. J (`--dash`): your mech dashes every `SANDBOX.dash` ticks
(add `--legs=jets` or `--legs=stompers` for the landing hit). `--block`: the target holds its
shield up all the time (normal blocks, then the shield drops at max hold). `--hook`: your mech
throws the hook whenever it is ready. Combine with `--shot`
and `--at` for screenshots of any weapon.

## Recipes

| fx kind | Recipe |
|---|---|
| hit | flash + streaks (away from source) + 2–3 smoke puffs + chips when `w > 0.6` + damage number |
| boom | 1-frame fireball, thin fast floor shockwave ring, orange blobs turning into dark smoke, chips, scorch mark |
| muzzle | tiny team-color flash, 3 short forward streaks, small smoke puff |
| zap / beam | thin white core line + colored edge, 2-frame flicker, sparks at the far end |
| parry | cyan ring, bright "ting" streaks, hit-stop 4 — the best-feeling effect in the game |
| shield block | cyan flash card over the panel, cyan + white rings in the shield plane, sparks outward; a guard break adds flash, star and parry sparks (`RIPPLE`) |
| hook | chain = team-color cable with a white core; on catch: flash, star, ring, sparks in the thrower's color; a cable joins the two mechs while the pull lasts (`HOOKED`) |
| break | big chunks in the part's color, the mech trails black smoke for 3 s, hit-stop 4 |
| ko | hit-stop 8, slow-mo, big boom, a smoke column that stays |
| dash / land / crush | dust ring + streaks; land and crush leave a floor crack (`Fx.crush` = `Fx.land` in warm white, `CRUSH`) |
| heal / pickup | green + white rings on the floor, flat green squares floating up and spinning (`HEAL`) |
| emp | flash + cyan star, thin cyan and white rings out to the radius, cyan needles; a star and sparks on every other mech inside (`EMP`) |
| blink | purple: a ring shrinking at the start, sparks, a thin purple ray with a white core, a ring opening at the end (`BLINK`) |
| soak (bubble) | small cyan flash, star, ring and shield sparks (`SOAK`) |
| magnet | thin purple ray with a white core (`MAGNET`) |
| ping (ricochet off a wall) | tiny flash, warm star, sparks flying back from the wall (`PING`) |
| charge (R wind-up) | team + white rings shrinking in, team needles rising on a ring (`CHARGE`) |

## Build order

1. **Done:** `Mech.flat`, the hit recipe (`Fx.hit`), hit-stop for head and heavy hits.
2. **Done:** neon look; muzzle, tracers, flame color by age, missile smoke trail, laser / lance /
   rail (`Fx.ray`), tesla lightning (`Fx.arc`), boom with floor scorch marks (`BOOM.marks` max,
   cleared each round), un-glowed mortar warning; the sandbox.
3. **Done:** parry (`Fx.parry`, cyan star + rings, hit-stop 4), break (`Fx.shatter`: starburst,
   chunks in the mech's team color, 3 s of black smoke from the mech, hit-stop 4), K.O. (`Fx.ko`:
   big boom + team ring + shards, hit-stop 8, then `Engine.time_scale` 0.3 for 0.6 real seconds),
   land (`Fx.land`: team + white rings, needle spikes and dust on a ring, floor crack), dash
   (`Fx.dash`: ring, backward needles, dust; `Fx.ghost` afterimages every 3 ticks while dashing).
   Booster trails are flat now too.
4. **Done (Victor 2026-10-27: "keep working on the dashes and smoke"):** booster trails. Arc /
   flame / frost = `Fx.ribbon`, a soft additive ribbon on the floor over the sim's trail line,
   booster color in the middle fading to clear edges, pointed tail, fading with the trail's life
   (`RIBBON`). Keep `gain` at 1: brighter colors turn white under the AgX tonemapper. Smoke (Twin
   booster dash and the Shroud R skill) = `Fx.smoke`, lit grey low-poly puffs scattered along the
   line, growing in, swelling and rising slowly, fading in the last 35% (`SMOKE`). Same hide zone
   as the sim. Evidence: `production/qa/evidence/godot-dash-smoke-before-after-2026-10-27.png`.
   Victor: "too round and perfect … more of a gas than bubbles". So the puffs use
   `SMOKE_SHADER`: value noise pushes the surface in and out and drifts up over time (`bump`,
   `churn`), alpha fades toward the silhouette (`rim`) so puffs blend into one cloud, and toward
   the floor and mechs behind it (`touch`, depth-texture soft particles). Per-puff grey, seed and
   fade are instance uniforms, so all puffs share one material. Evidence:
   `godot-smoke-gas-2026-10-27.png`.
   Fire got the same noise (Victor: "we can do the same with the fire"): `FIRE_SHADER`
   (`Fx.fire_mat()`, additive, unshaded, noise rising with `churn`, hot middle, faded outline) on
   the explosion fireballs (`boom_fire`, `"fire": true`, color from the particle `COLOR`).
   **Flamer = one cone** (Victor: "a cone of fire not blobs"): the sim still fires small flame
   shots; the view hides them and draws one cone per mech (`view.cone`, `Fx.flame_cone`, knobs in
   `CONE`) from the gun to the farthest live flame, aimed at their average direction. When you
   stop firing, the cone's back leaves the gun and the cone flies out with the last flames. Same
   shader with `tail` 1: yellow-hot at the gun, red and fading toward the tip. Evidence:
   `godot-fire-before-after-2026-10-27.png`.
   **One smoke** (Victor: "we should really use one type of smoke"): every puff particle layer
   (`mesh` starting with `puff`: hit, muzzle, boom, break, dust, missile trail) and the K.O. wreck
   (`Fx.wreck`, layer `wreck_smoke`, built by view.gd for each mech) use `smoke_mat()`, the same
   `SMOKE_SHADER` as the trail puffs. Its color and alpha come from the particle ramp (`COLOR`), so
   dark smoke stays dark and dust stays tan. `SMOKE.gain` thickens particles (the soft outline eats
   a lot); trail puffs scale it back down with `SMOKE.alpha`. Evidence:
   `godot-one-smoke-2026-10-27.png`.
5. **Done (2026-10-27):** directional shake, shield ripple, hook cable and endpoint.
   - **Shake:** a hit with a `from` angle sets `view.kick` (push direction × `shake_of` ×
     `KICK.hit`); main.gd moves the camera along it as a damped spring (`KICK.decay`,
     `KICK.freq`), projected on the camera's own axes so close-ups work too. Hits without a
     direction and booms keep the random shake.
   - **Shield block:** the sim sends no event for a normal block, so the view watches
     `act.absorbed` grow (`view.guard`) and calls `Fx.ripple`. The sim stays untouched. A guard
     break is seen as the shield gone with `cd.shield` above `SHIELD.cd`.
   - **Hook:** cable child on the hook node; the `hooked` event calls `Fx.hooked`; the view
     draws a `cable` node for every mech with `pull`.
   Evidence: `godot-shield-ripple-2026-10-27.png`, `godot-hook-cable-2026-10-27.png`,
   `godot-hook-catch-2026-10-27.png`.
6. **Done (2026-10-27):** pooling. `Fx.bar` meshes, burst emitters (`Fx.spare`), damage numbers
   (`view.labels`) and dash afterimages (per mech, meta `ghosts`, pose copied on reuse) go back
   to a free list (`Fx.park`) instead of being freed. Tweens are still made per effect (small,
   not nodes). Persistent emitters (wreck smoke, missile trails, break smoke) aren't pooled.
7. **Done (2026-10-27):** the last old-style effects (emp, heal / pickup, crush, blink, soak,
   magnet, ping, charge) are rebuilt as `Fx` recipes in the neon look (recipes above). The old
   glowing `view.pop` / `beam` / `sparks` helpers are gone, so no one-shot effect uses `Mech.glow` now (arena props in `view.gd` still
   do: pads, heal station, hazard jets, reticle).
   Evidence: `godot-misc-fx-before-after-2026-10-27.png` (top before, bottom after).

Later: chips bouncing on the floor; calming the white arena lamps, which are bloomy too.
