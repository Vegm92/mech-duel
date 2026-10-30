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
- Model: Shield Petals (2026-10-30): a plasma column on a dark drum, 4 blue shield petals around it, a yellow HP
  ring on the floor. A petal flies off when its line is crossed (fx + sound).
- **Lose** = core HP 0. Score = waves survived.

## 3. Fortress (tune later)

- Ring wall: indestructible, blocks everyone and every shot (fliers pass over it).
- **Gates:** 1500 HP each, block bots only (players walk through and shoot out). Bots on a lane
  attack the gate until it breaks, then walk in. A broken gate is rebuilt between waves (scrap) at
  50% HP, or repaired 20% per purchase.
- **Fortress modules** go on build pads (§5). Most of them do not aim: the fortress has **fixed traps**
  and **player-aimed guns**. Victor 2026-10-30: auto turret added (the one module that aims on its own:
  it shoots the nearest bot in range; bots can destroy it, like a wall).

## 4. Enemies (tune later)

Toughness (T) and Difficulty (D) are 1–10. Cost = budget points (§6). HP ≈ 60 × T^1.5 (rounded).
Speed in m/s. Damage per hit. The HP column is the first draft; the live HP is the table in §8b2.

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

- Kills drop scrap = 5 × the bot's cost, paid to the mech that lands the killing blow (Victor
  2026-10-30: one personal wallet, last hit like LoL). A wave cleared with the core above 75% pays each
  living player +20% of the wave's total.
- Between waves (**build phase**, 25 s, 15 s from wave 21) every player spends their own wallet. **Where you buy it**
  (Victor 2026-10-30: "go to the lane I want to reinforce and, from the squares available there,
  approach and with the same Shift buy and apply a buildable"): hold Shift (pad Y) and the radial that
  opens depends on where you stand.

| Buy | Cost | What | Bought at |
|---|---|---|---|
| Gate repair | 40 | +20% HP of the gate you stand at | gate wheel (within 4.5 m of a gate) |
| Gate rebuild | 120 | that broken gate back at 50% | gate wheel |
| Core ring | 200 | rebuild the highest broken ring (core HP back to its line) | plaza wheel, Team wedge |
| Garrison | tier cost | one more Garrison tier (§8c) | plaza wheel, Team wedge |
| Barricade wall | 60 | a 6 m wall on a build pad, 800 HP, blocks bots and shots | square wheel (within 4 m of a lane pad) |
| Mine field | 80 | 4 mines on a build pad, 60 dmg each, re-arm every wave | square wheel |
| Lane laser | 150 | a fixed beam across the lane on a pad, fires on a 3 s cycle with a 1 s warning line; hits anything in the beam | square wheel |
| Rail post | 120 | a post the player stands on and fires by hand: a 120 dmg rail on the player's own aim, 4 s cooldown | square wheel |
| Auto turret | 180 | aims at the nearest bot within 22 m and fires on its own, 30 dmg/s, 600 HP; bots shoot it down like a wall | square wheel |

- **Square wheel:** an empty pad, or the same module rebuilt once destroyed. Entries dim when your wallet
  cannot pay. **Gate wheel:** fixes only the gate you stand at, not the worst one. **Plaza wheel**
  (§8b2): weapons, upgrades, consumables, parts, and a Team wedge with only Core ring and Garrison.
  The 1-8 keys build nothing; the build-phase list on the right shows what the plaza Team wedge sells
  plus a hint line. AI allies walk to the gate they fix. Numbers: `MODULE` in `siege.gd`
  (`pad`, `gate` reach; `turret`: cost, hp, range, dmg, every).

- **Call next wave early:** press the call key in the build phase; bonus scrap = 2 × seconds left, paid to the player who called it.

## 6. Waves (tune later)

**Budget** for wave n: `B(n) = 2.7 + 1.98n + 0.144n²` (×0.9 on 2026-10-28 after the duel balance pass), × `1 + 0.4` per extra mech on the team (AI
teammates count). Wave 1 ≈ 5, wave 10 ≈ 37, wave 20 ≈ 100, wave 30 ≈ 190 points for one mech.

**Fuller waves** (Victor 2026-10-30: "the waves feel low in complexity; sometimes there are very few
enemies"). After the budget is spent, a wave is topped up with squads from its pool until it has
`FILL.lane` (6) bodies per active lane (a swarm cube counts), and from wave `FILL.mix` (3) on it
carries at least 2 bot kinds. The **Director is on by default** (`--director=off` turns it off).

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

## 8b. Scrapyard (Victor 2026-10-28, tune later)

Like a jungle, but a junkyard of mech parts and wrecks. The 4 blocks between the lanes (NE, SE, SW,
NW) become 4 walkable **yards**. Players leave the plaza to farm scrap there, taking a risk.

**Shape** (`siege_state.gd`): each lane keeps a 1.5 m wall on both sides out to the border. The
ring road's outer wall (26 to 27.5 m) gets one 6 m arch per yard on the 45° diagonal, so a yard is
reached only from the ring road. Inside: 5 camps, 3 salvage crates, scrap heaps (cover), a steam
patch (hides a mech, like smoke), a crush plate and 2 EMP zones (they hit bots too).

**One currency** (Victor 2026-10-30, after a playtest where the wallet had 80 and the shared fund 0, so
every build item was red: "fund and wallet should be one single, personal currency"). There is no
shared fund. The wallet (one per player) pays for everything: gates, core rings, pad modules, the
Garrison and the plaza items. Income: **only the killer is paid**: a lane, camp, raid or Elite kill
pays whoever landed the last hit (5 × cost); a pad module's kill pays the player who built it; a
Garrison kill pays whoever bought its current tier; hazards and raids that wipe a camp pay nobody.
Camp scrap and tokens go to the player who killed the camp's last bot; crates pay who opens them;
a clean wave pays each living player +20% of the wave's earnings; calling a wave early pays the caller.
Plaza items (spent within 14 m of the core) at any time: mech repair 30, part upgrade (+1 level to your lowest part for this run, 80 ×
  new level), reinforce (+15% max armor for this run, 100 scrap or 1 token), revive (bring a downed
  teammate back now, 50, from anywhere). V only opens crates.
- This makes roles: lane holders, farmers, a floater at the core. Core repair still needs someone
  standing at the core.

**Camps** (neutral bots, team 2, existing kinds, no new models). Asleep (`dormant`) until a player
comes within 8 m or hits one; then `wake` and fight players only (they ignore lane bots). They chase
up to 18 m from their camp, then walk home and heal to full.

| Camp | Bots | Scrap |
|---|---|---|
| Small Heap (×2 per yard) | 3 swarm cubes, or 2 scouts | 10 |
| Medium Wreck | 1 turret + 2 spiders | 25 |
| Big Hulk | 1 quad walker | 45 |
| Elite Titan Hulk (1 per yard) | 1 heavy mech | 120 + 1 reinforce token |
| Salvage crate (×3 per yard) | hold V 3 s, stand still | 15 |

The scrap goes to the player who killed the camp's last bot. Camps and
crates refill at the start of every wave; the Elite only every 5 waves. One yard pays about 135 per
wave (+120 from the Elite every 5 waves); lane kills at wave 10 pay about 190 in total for 2
players. Yards out-earn lanes about 3 to 1 but clearing all 4 takes most of a wave.

**Risks.** Spiders pop out of the side vents into the yard, flyers cross it from the air corners,
tripods on the lanes snipe into it, and from wave 15 every wave sends a **raid squad** (Scout Pack +
Ambush Cell, the wave's Mk) into one yard from its air corner: it wipes each camp it reaches (no
scrap), takes the crates, then leaves through the arch onto the ring road and attacks the nearest
gate from inside the fort's outer road.

**Tuning risks.** Farming too strong (players skip lanes and buy everything): knobs are camp
scrap, the refill rule and the 3 × cost lane rate. Players away too long: gates fall while
they farm; lane arrows on the HUD, raids from wave 15 and the growing respawn timer push back.

AI allies get roles: ally 1 farms the nearest yard while the wave is not live or its lane is quiet,
the others hold lanes, ally 3 floats at the core.

## 8b2. In-run upgrades and the radial shop (Victor 2026-10-28, tune later)

Victor played to wave 6: bots felt too hard to kill because your mech never grew during a run.
Now it grows like a LoL build, but with the parts we already have.

**Upgrade tiers.** Each of the 7 slots (head, core, arms, legs, booster, left hand, right hand) has a
run-only tier 0..5 on top of its Salvage level, bought from your **wallet** in the plaza. Price =
base × tier² (hands 40, head/arms/legs 35, booster 30, core 45; tier 5 of a hand = 1000). Tiers
stay with the slot when you swap the part in it.

| Slot | Per tier |
|---|---|
| Left / right hand | +12% damage, -5% cooldown |
| Head | +10% head armor, +6% R charge |
| Arms | +10% arm armor, -3% hand times |
| Legs | +10% leg armor, +4% top speed |
| Booster | -8% dash recharge |
| Core | +12% R charge gain, +4% damage |

**Buy parts.** In the plaza you can swap any part or weapon you **own** (Salvage) into a slot:
light 60, standard 150, heavy 300; weapons by class (by their Load: up to 14 = 60, up to 18 = 150,
more = 300). Parts you don't own stay locked. The parts bay prop stands at `BAY` in the plaza.

**Instant buys** (wallet): repair kit 40 (full armor), coolant 20 (heat to 0), surge cell 60 (+50 R
charge), reinforce 100 or a token (+15% max armor for the run), revive 50 (a downed teammate now).

**Wallet income.** Every run starts with 120 in each wallet (a barricade is 60, a mine field 80).
Yards stay the big earner.

**Recall.** Hold B (pad X) 3 s, broken by taking damage: you appear at your plaza spot. 25 s
cooldown. Makes the yard ↔ plaza loop work.

**Radial shop.** Hold Shift (pad Y) in the plaza (within 14 m of the core), move the mouse or stick
toward a wedge, release or click to buy, right click / Esc / pad B goes back. The sim keeps running.
Level 1: Weapons, Plating (head, arms, legs), Engine (legs, booster), Core, Heal (kit, coolant, surge
cell), Parts (swap), Team (Core ring, Garrison), Reinforce, Revive. Victor 2026-10-30: modules
and gate fixes moved out of the plaza: Shift next to a lane square opens a Build wheel (barricade, mine
field, lane laser, rail post, auto turret) and Shift next to a gate opens a Gate wheel (repair +20%,
rebuild at 50%), both build phase only (§5). Level 2 shows cost (dimmed when you can't pay) and the stat change. Keys checked
for the radial: Shift, B, V, X, G and 1-8 are free or siege-only; no punctuation keys are bound (a
Spanish layout moves them). All bindings use physical keycodes.

**AI teammates buy.** In the plaza between waves they spend their wallet on hand damage, then
plating, engine, core; they recall when armor is low or the wallet is over 300, then go back out.

**Balance targets.** Waves 1-10 beatable by a base build plus one AI teammate; Light Scout, Swarm
cube and Spider die in 3 or fewer default-weapon hits. A fully upgraded build clearly outlasts a
base one at waves 10/20/30, and a full-tier build without players still falls by wave 30.

**Bot HP and default Rivet hits** (2026-10-28 retune after the duel balance pass, Rivet 65 → 42
dmg: every bot HP × 0.65, so the hit counts stay the same; Mk 1, no tiers):

| Bot | HP | Rivet hits |
|---|---|---|
| Light Scout | 40 | 1 |
| Swarm cube (each of 3) | 25 | 1 |
| Spider | 84 | 2 |
| Flyer | 80 | 2 |
| Turret | 210 | 5 |
| Walker | 275 | 7 |
| Tripod | 155 | 4 |
| Quad Heavy | 520 | 13 |
| Heavy Mech | 750 | 18 |
| Juggernaut | 650 | 16 |

## 8c. Garrison (Victor 2026-10-28, tune later)

A fortress upgrade that gives the core **one** allied defender, upgraded many times for a lot of
fund scrap. One unit, not an army. AI-driven like the AI teammates (`bot.gd`), so the no-auto-aim
rule (about player input) is not touched.

- Built from the players' part catalog (no new model), team 0, a core-colored glow and team ring,
  docked at `GARRISON_DOCK` (9, 9) in the plaza.

| Tier | Cost (wallet) | Build | Part level |
|---|---|---|---|
| 1 | 150 | light frame: Wire arms, Greaves, Flicker, Rivet + Bash (one gun) | 1 |
| 2 | 400 | + Brace arms, Treads | 2 |
| 3 | 900 | + Gatling in the right hand (second gun) | 2 |
| 4 | 2000 | + Reactor core, uses its R skill (Overdrive) | 3 |
| 5 | 4500 | heavy: Oni Horns, Anvil arms, Stompers, Rocket booster, Aegis core (shield dome R), Gatling + Missiles | 3 |

- Behavior: guards the plaza (leash 14 m from the core), engages bots in range, goes first for
  anything hitting the core or a gate, retreats to its dock below 30% head armor. Dies like a mech
  (armor pools, breaks), rebuilds at its dock after 20 s × tier, free.
- It must not hold waves alone: a bot-only run at wave 15 and 25 with a tier-5 Garrison and no
  players still loses (a test checks it).
- HUD: tier and the next tier's cost in the shop; paid from your wallet; the buyer of the current tier is paid for its kills.
- VS: each team has its own Garrison.

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
- Each team's yards are its backyard; invade the enemy's yards to steal its scrap. Each team has its
  own Garrison.

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
