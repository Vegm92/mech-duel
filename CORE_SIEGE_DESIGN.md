# Mech Duel — Core Siege Design v0

Draft 2026-10-28 (UTC). Working title **CORE SIEGE**. A co-op wave-defense mode. Every number in
this file is a v0 guess: **tune later**, all of them, even where a line does not say it again.

Up to 4 mechs, one team, defend a **Reactor Core** in the middle of a big square map. Waves of
grey robots spawn at the map border and walk 4 lanes to the core, LoL-minion style. A fortress
ring with 4 gates guards the core. Survive as many waves as you can. Early waves teach, late waves
are brutal.

Players use the normal mech kit from `COMBAT_DESIGN.md`: two hands, Q shield, E head skill, R core
skill, Space dash, every action aimed. The duel rules stay: **zero auto-aim, zero aim assist, zero
auto-attacks** for anything the player owns, fortress included. Enemy AI may aim.

Co-op is built first. The VS variant (§9) is design only, **not built until Victor says so**.

---

## 0. Ground rules

- Same sim as the duel: 60 ticks/s, top-down 2D plane, pure and seeded (no time, no `randf`, no
  DOM). The mode lives in `godot/src/siege.gd` and drives the same mech code in `sim.gd`.
- Enemies are **bots**: grey armor, light-grey trim, dark joints, blue glow eyes, cube heads with
  no spike (Victor 2026-10-28; Mk 2 gunmetal + plates, Mk 3 near-black + red eyes), the chibi
  blocky language of the player mechs (sheet: `docs/reference/robot-gladiator-silhouettes.webp`).
  Every bot name is original (no Medabots names).
- Calm follow camera on your own mech, never rotating, W is up. The siege map is bigger than one
  screen, so off-screen threats get arrows on the screen edge (§7).
- One human for now, plus AI teammates driven by `bot.gd`. See §8 for what local co-op and netcode
  need later.

## 1. Arena (tune later)

Square, **160 × 160 m** (half-size 80; about 5× the duel arena's floor area). Sim origin is the map
center, north is −y (up the screen). Distances below are from the center. The numbers live in
`godot/src/siege_state.gd`; this table mirrors it.

| Piece | Where | Notes |
|---|---|---|
| Reactor Core | center (0, 0), radius 2.5 m | blocks movement; see §2 |
| Center plaza | circle, radius 14 | repair ring around the core |
| Fortress ring | circular wall from 16 to 17.5 m | blocks everyone and every shot |
| Gates | 4, in the ring where the lanes meet it (N/E/S/W), 10 m wide | block bots only; players walk and shoot through; have HP (§3) |
| Ring road | from the ring out to 26 m | lets players switch lanes outside the walls |
| Lanes | 4, lanes 0..3 = N, E, S, W, 10 m wide, from the border (80) to the gate (16) | straight; bots spawn at 78 and walk to the gate |
| Chokepoints | 2 per lane, at 36 and 58 m | two pillars (radius 2) on the lane walls narrow it to 6 m |
| Build pads | 3 per lane, at 30, 48, 66 m, on the lane's center line | where fortress modules go (§5) |
| Blocks | the 4 corner quadrants between lanes, beyond 26 m | solid raised ground, nobody walks there |
| Side vents | 2 per lane, one in each lane wall at 47 m | Spider Bots pop out here |
| Air entries | 4 corners, (±74, ±74) | Flying Bots spawn here and fly straight at the core |

The blocks make pathing trivial: a ground bot walks its lane to the gate, through the gate (once it
is broken) and across the plaza to the core. No navmesh, no pathfinding, deterministic.

## 2. Reactor Core (tune later)

- **HP 4000.** Four shield **rings** break at 75%, 50%, 25% and 0% (the last one is the core
  itself: **lose**). A broken ring stays broken until rebuilt with scrap between waves.
- **Repair:** stand inside the repair ring (5 m from the core center) without firing for 1 s, then
  each mech there repairs **25 HP/s**. Repair never goes above the lowest intact ring's line (a core
  at 60% with the 75% ring broken repairs up to 75%). Taking damage or firing stops your repair for 1 s.
- Model: a crystal in a cradle, 4 pylons facing the lanes, 4 shield rings stacked around the
  crystal. A ring shatters when its line is crossed (fx + sound).
- **Lose** = core HP 0. Score = waves survived.

## 3. Fortress (tune later)

- Ring wall: indestructible, blocks everyone and every shot (fliers pass over it).
- **Gates:** 1500 HP each, block bots only (players walk through and shoot out). Bots on a lane
  attack the gate until it breaks, then walk in. A broken gate is rebuilt between waves (scrap) at
  50% HP, or repaired 20% per purchase.
- **Fortress modules** go on build pads (§5). None of them aims: the fortress only has **fixed traps**
  and **player-aimed guns**.

## 4. Enemies (tune later)

Toughness (T) and Difficulty (D) are 1–10. Cost = budget points (§6). HP ≈ 60 × T^1.5 (rounded).
Speed in m/s. Damage per hit.

| Bot | Role | T | D | Cost | HP | Speed | Attack | Behavior |
|---|---|---|---|---|---|---|---|---|
| Light Scout | fast flanker | 1 | 3 | 1 | 60 | 7.5 | zap bolt, 10 dmg, 1/s, 12 m | runs the lane straight for the core, sidesteps aimed shots it sees coming |
| Swarm Bot | distraction | 1 each (3 cubes) | 4 | 2 | 3 × 40 | 6.5 | bite 6 dmg; self-destruct 40 dmg r 2.5 m at a gate or mech | cluster of 3 cubes that splits around blockers |
| Spider Bot | ambusher | 2 | 4 | 2 | 170 | 6.5 | lunge bite 25 dmg | low profile, pops out of a side vent, hunts the nearest player first |
| Flying Bot | harasser | 2 | 5 | 3 | 170 | 7 | dive bolt 15 dmg, 2/s, 10 m | spawns at a corner, flies over walls straight at the core; melee misses it, bolts hit it |
| Turret Bot | siege | 4 | 5 | 4 | 480 | 3.5 | cannon 30 dmg, 1/1.5 s, 22 m | walks to a stop point, plants (×0.5 damage taken from the front), shoots the gate, then mechs, then the core |
| Quad Walker | bruiser | 5 | 5 | 5 | 670 | 4 | claw 45 dmg + bolt 20 dmg | attacks gates, fights mechs that block it |
| Tripod | sniper | 3 | 7 | 5 | 310 | 3.5 | charged rail 90 dmg, 2 s telegraph line, 34 m | outranges, hunts players, keeps distance. Priority kill |
| Quad Heavy | artillery | 7 | 8 | 8 | 1110 | 3 | missile salvo, 4 × 35 dmg, r 2 m, 45 m, marked 1.5 s | stops far out and bombards the core over the wall. Priority kill |
| Heavy Mech | tank | 9 | 7 | 9 | 1620 | 2.8 | big cannon 80 dmg r 2.5 m, 1/2.5 s | soaks, area control, leads its squad |
| Juggernaut | rolling ram | 8 (10 rolling) | 8 | 9 | 1360 | 3 / 11 rolling | ram 120 dmg + push 6 m; gate ×3 | rolls down the lane invulnerable, unrolls after a hit or 8 s, exposed 4 s, rolls again |

Rules shared by every bot:
- One HP pool, no part breaks (a bot is not a mech). Stagger and push work like on mechs.
- Every bot attack is telegraphed (wind-up fx) and dodgeable. Bots never shoot through the fortress
  wall; artillery lobs over it.
- **Target priority** (unless the row says otherwise): a mech within 6 m that hit it, then the gate,
  then the core.
- **Mk 2 / Mk 3** (waves 21+ / 31+): Mk 2 = HP ×1.5, damage ×1.25, a glowing trim; Mk 3 = HP ×2.2,
  damage ×1.5, speed ×1.1.
- Kills drop scrap (§5): 5 × cost.

## 5. Scrap and the build phase (tune later)

- Kills drop scrap = 5 × the bot's cost, shared by the team. A wave cleared with the core above 75%
  adds +20%.
- Between waves (**build phase**, 25 s, 15 s from wave 21) the team spends scrap:

| Buy | Cost | What |
|---|---|---|
| Gate repair | 40 | +20% gate HP |
| Gate rebuild | 120 | broken gate back at 50% |
| Core ring | 200 | rebuild the highest broken ring (core HP back to its line) |
| Mech repair | 30 | refill every part of one mech |
| Barricade wall | 60 | a 6 m wall on a build pad, 800 HP, blocks bots and shots |
| Mine field | 80 | 4 mines on a build pad, 60 dmg each, re-arm every wave |
| Lane laser | 150 | a fixed beam across the lane on a pad, fires on a 3 s cycle with a 1 s warning line; hits anything in the beam |
| Rail post | 120 | a post the player stands on and fires by hand: a 120 dmg rail on the player's own aim, 4 s cooldown |

- **Call next wave early:** press the call key in the build phase; bonus scrap = 2 × seconds left.

## 6. Waves (tune later)

**Budget** for wave n: `B(n) = 3 + 2.5n + 0.18n²`, × `1 + 0.4` per extra mech on the team (AI
teammates count). Wave 1 ≈ 6, wave 10 ≈ 46, wave 20 ≈ 125, wave 30 ≈ 240 points for one mech.

**Squads** (cost):

| Squad | Bots | Cost |
|---|---|---|
| Scout Pack | 4 Scouts | 4 |
| Swarm Cloud | 2 Swarm | 4 |
| Raiders | 2 Scouts + 1 Flyer | 5 |
| Ambush Cell | 3 Spiders | 6 |
| Firebase | 1 Turret + 2 Swarm | 8 |
| Air Wing | 3 Flyers | 9 |
| Line Breakers | 2 Quad Walkers | 10 |
| Ram | 1 Juggernaut + 3 Scouts | 12 |
| Sniper Nest | 1 Tripod + 1 Turret + 2 Spiders | 13 |
| Shield Wall | 1 Heavy + 2 Turrets | 17 |
| Barrage | 1 Quad Heavy + 1 Tripod + 2 Swarm | 17 |
| Titan Push | Heavy + Juggernaut + Quad Walker | 23 |

**Divisions** = squads that arrive together on one lane:

| Division | Squads | Notes |
|---|---|---|
| Vanguard | Scout Pack, Raiders, Ambush Cell | |
| Swarm | 2 Swarm Clouds, Firebase | |
| Air | Air Wing, Raiders | corners, ignores lanes |
| Armor | Line Breakers, Shield Wall | |
| Siege | Barrage, Sniper Nest, escort | escort = a Scout Pack or Swarm Cloud |
| Shock | Ram, Titan Push | late only (wave 15+) |

**Spawning:** a division's bots spawn at the lane's border mouth, staggered 0.5 s apart, tanks
first, ranged bots ~5 s after the first bot. The director fills the budget with divisions the wave
plan allows, picking lanes with the seeded sim RNG.

**Triggers:** the next wave starts when the build phase timer runs out, or early on a call (§5).
A wave that is not cleared after 90 s lets the next one come anyway. The lane gate flashes with the
division's icon **8 s before** its first bot spawns.

**Wave plan:**

| Wave | What |
|---|---|
| 1–3 | one or two lanes, Scouts then Swarm |
| 4–5 | two lanes, Spiders |
| 6–7 | three then four lanes, first Flyers |
| 8–9 | Turret, then Quad Walkers |
| **10** | **BOSS: Shield Wall** |
| 11–14 | mixed, Tripod at 12, Air Wing at 13 |
| **15** | **BOSS: Ram**, Scouts in the other lanes |
| 16–19 | Quad Heavy from 17 |
| **20** | **BOSS: Siege Division** (2 Quad Heavy + Tripods) |
| 21–29 | Mk 2 elites, two divisions at once, shorter breaks |
| **30** | **Last Stand**: every type, 3 Heavy Mechs, air included |
| 31+ | endless, Mk 3, a new mutator every 5 waves |

**Mutators** (endless, one more every 5 waves, seeded pick, stack): Overclock (bots +15% speed),
Plated (+30% HP), Volatile (every bot explodes on death, 30 dmg r 2 m), Air Raid (an Air Wing on
top of every wave), Hive (Swarm Clouds cost half), Iron Rain (a Quad Heavy on top of every 3rd wave).

## 7. HUD (tune later)

- Top center: **WAVE n**, build-phase timer or bots left, scrap.
- Core panel: 4 ring pips and the HP bar.
- **Next-wave warning:** 8 s before a lane's first spawn, an icon (the division's bot) blinks over
  that lane's gate, and an arrow on the screen edge if the gate is off screen.
- **Lane under attack:** a red arrow on the screen edge toward any gate or the core taking damage.
- The rest is the duel HUD (your parts, skills, impact numbers).

## 8. Players and progression (tune later)

- Team: you + 0–3 AI teammates (`--team`, garage picker later; default 2), all on team 0. AI
  teammates run `bot.gd`, hold the open lanes' posts, fall back to the core when a bot gets inside,
  stand by the core to repair it between waves, and buy only core rings and gate fixes.
- A K.O.'d mech respawns at the core after 8 s + 0.5 s per wave.
- **Salvage hooks:** clearing wave 10, 20 and 30 opens the claim screen (`claim.gd`) with the parts
  of one ready-made set (wave 10 Tank, 20 Artillery, 30 Reflector) you do not own at max level.
  Best wave is saved in `user://progress.cfg`.
- **Entry:** the garage has a CORE SIEGE button next to FIGHT.
- **Endless** from wave 31: Mk 3 bots, mutators, the score is the wave number.
- **Later, not built:** a second local player (second pad, split input in `main.gd`, a shared
  camera that frames both, a second HUD panel) and netcode (lockstep fits: the sim is already
  deterministic and seeded, inputs are small dicts; needs a lobby, input delay and a desync check
  on `hash_state`).

## 9. VS variant (design only, not built)

Team vs team, LoL-style.
- Long map, 2 cores at opposite ends, 4 parallel lanes between them (2v2 uses the 2 middle lanes).
  One gate per team per lane.
- Each core sends the same bot squads, in team colors, at the enemy core on a shared timer.
- Spend scrap to send an extra squad down a lane.
- Break a lane gate to open that lane's pylon on the enemy core. Break all 4 rings, then the core.
- Respawn timer grows through the match (6 s → 20 s).
- Sudden death at 20 min: bot budget ×2.
- Gates shoot only slow, telegraphed, dodgeable shots (no aim help for anyone).

## 10. Code layout and the shared state

Built by three sessions at once (2026-10-28, see `CORE_SIEGE_SPLIT.md` for who edits what):
the sim (`siege.gd`, `siege_state.gd`), the arena and core art (`siege_view.gd`,
`core_siege.glb`) and the bot art (`siege_bots.gd`, `bots.glb`). The views read only
`state.siege`:

```
siege = {
  tick, wave: {n, next_in, lanes_open: [bool x4]},
  core:  {x, y, hp, max, rings: [hp x4], repairing: bool},
  gates: [{lane, x, y, hp, max}],
  pads:  [{lane, x, y, module: ""}],
  enemies: [{id, kind, lane, x, y, face, hp, max, act, t, mk}],
}
```

- `rings[0]` is the outer ring (breaks first, at 75%), `rings[3]` the last one (0% = lose). Each
  holds a quarter of the core HP; `core.hp` is their sum.
- `kind` is a bot id: `scout, swarm, spider, flyer, turret, walker, tripod, quadheavy, heavy, jugg`.
  `face` is radians in the sim plane, `act` one of `walk, idle, attack, windup, roll, plant, hit,
  die`, `t` ticks in that act, `mk` 1..3. `id` is unique for the whole run (never reused).
- Inside the sim each bot also has a body in `state.mechs` (team 1) so every player weapon, skill
  and dash hits it with no special case; the body's index is the record's `m`.
- `SiegeState.stub(rings_left)` builds a fake `state.siege` for look checks.

## 11. Open questions

- Does repair need a button (hold Q at the core) or is standing near enough?
- Should players be able to stand on the fortress wall?
- AI teammates: hold lanes, or follow the human?
