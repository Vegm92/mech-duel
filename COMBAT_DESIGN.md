# Mech Duel — Combat Design v0

Draft 2026-10-16 (UTC). Every number here is a v0 starting point for playtest, not balance.

Top-down, one arena: 1v1, free-for-all (4 mechs) or 2v2 (see Match). No minions, no towers, no
auto-attacks, no auto-targeting, no aim assist. Every action is aimed by the player.

---

## 0. Ground rules (shared by every mech)

### Sim

- Fixed 60 ticks/s. Timings are in ticks (`t`): 6t = 0.1 s.
- Top-down 2D plane. Calm follow camera (2026-10-21, Victor's pick for the big stadium): never
  rotates (W is always up), frames the midpoint of both mechs but keeps you inside the middle 70%,
  has a dead zone and slow easing; an arrow on the screen edge points at an off-screen rival.
- Mech body radius 0.8 m (was 0.6; Victor wanted bigger robots, 2026-10-21).

### Frames (look only, 2026-10-19)

Two beetle frames so each side reads at a glance: **Cinderhorn** (you, orange, rhino horn) and
**Talonjaw** (rival, blue, stag-beetle pincers). Same rules and part catalog for both; the frame
only changes the art. Every part has its own drawing, top-down in the arena and front-view in the
garage and on the title screen.

### Anatomy: five body parts and two hands (Exteel-style, 2026-10-21)

| Slot | Owns | Also sets |
|---|---|---|
| Head | — | the KO armor pool, how fast the R meter fills |
| Core | **R** (skill) + passive | the R skill, plus a passive that scales heat, Surge, armor, damage or the dash |
| Arms | — | armor of both arms, hand speed (windup, recovery and cooldown of both hands) |
| Legs | movement + the dash move | top speed, accel, poise, leg armor, how Space dashes |
| Booster | **Space** dash | dash distance, recharge and its trail element |
| Left hand | **Left click** | any of the 20 weapons (gun or melee) |
| Right hand | **Right click** | any of the 20 weapons (gun or melee) |

**Skills, dash moves and trails (2026-10-22).** Victor moved the R skill from the weapon pair to the
Core ("skills should live in the core"); the garage's old SKILLS tab is now SETS, six ready-made full
builds. Legs choose how the dash moves, the booster adds an element to it. Tables in §5. Rules:
- Airborne dashes (Leap, Slam, Pounce) make bolts, rays, cones, melee and mines miss; lobs and
  strikes still hit. The landing spot is marked on the floor, so they can be punished.
- Ram and Roll hit once on contact (Ram stops, Roll goes through). Leap, Slam and Pounce hit on
  landing; Leap and Slam stun (Leap also lifts the target, visual only).
- Skitter and Double have two dash charges; each charge recharges on its own timer.
- Trails live 1.2–3 s. Arc zaps once per trail and locks skills for 0.5 s; Flame burns every 0.25 s
  and adds heat; Frost slows; Smoke hides anyone inside from the rival (the bot loses sight, its aim
  error ×4); Magnet pulls the rival 2.5 m toward you when the dash ends; Clean has no trail.

Shield (Q) and chain hook (E) are a fixed kit every mech has. Weapons are not arms any more: either
hand takes any weapon, so two guns, two blades or one of each all work. Each hand has its own
cooldown; heat is shared. A shot leaves from the side of the hand that fired it. A broken left arm
jams the left hand's weapon, a broken right arm the right one.

**Series and weight.** Every body part is Light (1), Standard (2) or Heavy (3). The five add up to
the mech's weight (5–15, all Standard = 10). Top speed × (1 + (10 − weight) × 0.025): all Light
+12.5%, all Heavy −12.5%. Heavy parts pay for their armor or reach with speed.

**Load.** Every skill lists one Load number. The Core decides what Load costs (heat, ammo, nothing).
That one number lets any weapon work with any Core.

### Armor and part breaks

- Head, R-Arm, L-Arm and Legs each have their own armor. **Head at 0 = KO.**
- Every hit carries a **hit tag**:
  - `ARMS` (most skills) — goes to the arm on the side the hit comes from, relative to the target's
    torso facing. Within ±15° of dead-front or dead-rear it goes to the more damaged arm (tie: right arm), so focused fire breaks parts.
  - `LEGS` (ground splashes, low sweeps, traps, walls) — goes to Legs.
  - `HEAD` (precision shots, some ultimates) — goes straight to Head. Rare by design, always telegraphed.
- Hits from the rear 90° arc deal ×1.25.
- A broken part (0 armor) still works, **jammed**:
  - Jammed arm: that skill's cooldown ×2, its damage / absorb ×0.6.
  - Jammed legs: top speed −30%, E distance −40%, E cooldown ×1.5.
  - Every further hit on a broken part goes to Head at 100%.
- Jammed, not disabled: a mech with no Q has nothing left to play. Jammed keeps the duel alive, but losing.

**Torso twist.** Hits land on the side facing the attacker, so a mech with a broken left arm wants its
right side toward the enemy. The torso faces the cursor, so twisting means not aiming. That trade is
intended.

### Movement and weight

- WASD sets a target velocity; the mech accelerates toward it. Nothing is instant.
- Legs set top speed, accel time and traction. Reversing means bleeding speed first, so committing to
  a direction has a cost and reads matter.
- The torso (aim) faces the cursor instantly. Weight lives in movement, windups, recoil and
  knockback — never in aim lag. Some skills cap turn rate while active (listed per skill).
- Recoil: heavy skills push the caster back along the aim line.

### Skill phases (every skill)

`windup → active → recovery`

- **Windup**: animation + sound tell. Windups ≥ 18t (0.3 s) also draw a ground telegraph the
  opponent can see.
- **Recovery**: no other skill can be used (except a listed cancel). This is the punish window.
- **Cast slow**: movement ×0.7 during windup and recovery unless the skill says rooted.
- **Aim locks at the end of windup**, not at key press.

### Impact, poise, stagger

- Every hit has Impact 0–4. Every mech has Poise from its legs: Light 1, Medium 2, Heavy 3.
- Impact ≥ Poise → **stagger**: 12t × (Impact − Poise + 1), knockback 0.6 m × Impact ÷ weight factor,
  and any windup is cancelled (**stuffed**). A stuffed skill goes on 50% cooldown.
- Impact below Poise → damage only. Heavy mechs trade through pokes; light mechs can't.

### Cancels and buffer

- Input buffer 6t: a skill pressed during recovery fires on the first legal tick. A press during a
  stagger stays buffered until the stagger ends, so you can always dash out the moment you recover.
- E can cancel Q's recovery, and the windup of any skill (a **feint**). A feinted skill refunds 70% of
  its cooldown and all its Load.
- Nothing else cancels anything. Every other commitment is real.

### Surge (ultimate meter)

- 0–100. R costs 100.
- Gain: +6 per cast that hits, +0.08 per damage dealt, +0.12 per damage taken, +15 per Perfect Guard.
- Taking damage pays more than dealing it: the losing player always holds a scary R.
- 50% carries into the next round.

### Readable state

Every part has a status light on the mech: lit = ready, dark = on cooldown. The Head glows when
Surge is full. Kit limiters are visible too (Cinderhorn's vents glow when hot). You never guess
whether their W is up — you see it. Baiting is a decision game, not a memory test.

### Arena

- Stadium octagon: a 76 × 60 m box with 18 m cut off each corner (8 walls), mirror-symmetric. Mechs
  spawn 30 m apart on the middle row. Walls: `WALLS` (8 half-planes) in `sim.gd`; `clampArena` keeps
  targets, mines and bounced shots inside. Everything is placed relative to the center.
- 8 pillars: 4 inner (1.5 m, center ± 6.5 / 5.5) and 4 outer (2 m, center ± 17 / 14): block movement,
  projectiles and beams. Lobbed ground skills go over them.
- Outside the walls (look only): tiered stands on the 6 non-side walls packed with pixel fans (orange
  on the left half, blue on the right, some neutral) that jump on big hits, part breaks and K.O.s;
  the north stands are tall, the south ones low so they never cover the arena. The left and right
  walls hold each robot's pit: platform, team wall, tool carts, a waving flag and 5 crew who cheer.
- 2 fog banks (4 × 3 m): a mech inside is invisible to the opponent unless within 3 m or it used a
  skill in the last 1 s.

### Match

- 3 s countdown, then the round. First to 3 rounds. Round timer 60 s (built; was 99 s before kills
  got faster).
- Not built yet: from 70% of the timer, sudden death walls close in at 0.3 m/s; touching a wall deals
  20/s (`LEGS`).
- Timeout: higher Head armor wins; tie → higher total armor; tie → draw.
- Between rounds: all parts repaired, 50% Surge kept. Not built yet: the round loser may swap one part
  (counter-pick).
- **Formats (built 2026-10-25, `FORMATS`):** `1v1` (teams [0, 1]), `ffa` (4 mechs, 4 teams),
  `2v2` (seats 0 + 2 vs 1 + 3). You are always seat 0; the other seats are bots. Picked in the garage.
  - Every attack hits every enemy it reaches (melee cleaves, lines pierce, blasts hit all in the
    radius); teammates are never hit (no friendly fire). Dash contact hits and the arc trail still hit
    only the first enemy. Homing locks onto the nearest enemy.
  - A K.O. mid-round leaves a wreck (no collision, no actions). The round ends when one team is left;
    its team scores. `finalKo` is the mech whose fall ended it (K.O. zoom, kill cam).
  - Timeout: the healthiest single mech (head %, then total armor) wins for its team; a tie between
    teams is a draw.
  - Spawns (`spawnsOf`): 1v1 as before; FFA in the four corners (±15, ±10 from the center);
    2v2 each team on its side at ±6 m.
  - Bot vs bot, 8 matches each: FFA rounds ~35 s, 1 timeout in 38 rounds, wins spread over all 4
    seats; 2v2 rounds ~26 s. 2v2 with mirrored loadouts, 60 matches: 124 / 112 rounds.

### Hit-stop (built)

- A hit that staggers freezes the whole sim for 5t; a part break for 7t; a K.O. for 24t. Buttons pressed
  during a freeze stay buffered. It sells weight without changing any timing the players react to.

### AI rival (built)

The default opponent (`godot/src/bot.gd`). It reads the same things a player sees: positions, velocities,
shots in flight, cooldown lights, heat.

- Keeps 12–16 m when you can still dash; closes to saw range when your E is dark, you're staggered or
  overheated, or your head is much weaker than its own.
- Strafes with random jukes (every 0.3–1.2 s), reverses when a shot is coming, and avoids walls.
- Leads its shots (two-step prediction) with ±0.9 m of aim error.
- Per incoming shot it decides once: 35% try a Perfect Guard (raises the plate ~5t before impact), 25%
  dodge-dash if it's late.
- Melee when you are inside 75% of its reach; dash-in when you are open; escape-dash from your melee
  when you aren't.
- Lead depends on the gun: travel time for bolts, fuse time for the mortar, none for the laser, the
  arc coil and homing missiles.
- Fires its ultimate by head type: the lance at a clear line when you're open or close, EMP/mines/
  berserk up close, the orbital strike and stasis field at your predicted spot, repair when hurt,
  bubble when a shot is coming.
- Steps out of mortar and orbital circles, mines and stasis fields.
- With more than one enemy it chases the nearest one and keeps it unless another is clearly closer
  (`BOT.stick`: 1.3× + 2 m). It ignores its teammates' shots, lobs, mines, fields and trails.
- Holds fire into a raised shield facing it (the mortar lobs over it), and above 82 Heat unless it can
  finish you.

---

## 1. Core combat loop

**Dodge distance** = how far away a juke still beats a well-aimed shot. Since shots became full range
(playtest 2026-10-16) the gun reaches everywhere; what changes with distance is whether you can dodge
it. Cinderhorn's Q at 60 m/s: about 15 m. Neutral is two players dancing around that line: inside
it you get hit, outside it you can read and juke.

```
 NEUTRAL ──(someone lands, whiffs, burns a cooldown, or hits a limiter)──► TRADE WINDOW
    ▲                                                                           │
    │                                                                           ▼
  RESET ◄──(defender escapes / attacker leaves before the lights come back)── COMMIT
                                           │
                         (R up + a reason) ▼
                                      CAPITALIZE ──► KO or RESET
```

### 1. Neutral (most of a round)

- Distance 15 m and up, using pillars to block lines.
- Strafing, Q pokes, fake approaches, pillar peeks.
- The goal is not damage. It is making the opponent spend something: a W, an E, heat, position.
- **Tuning target:** standing still loses, moving well wins, aiming well beats moving badly.
  Each line below is a test in the JS version (`Vegm92/mech-duel-js`, `src/sim.test.js`).
  - Q flies across the whole arena at 60 m/s (15 m ≈ 0.25 s). Clearing its path takes ~0.9 m of
    sideways movement.
  - Standing still, reacting after 0.22 s → hit. Too little time to accelerate out.
  - Strafing in a straight line → a shot aimed at you misses, a shot **led** ahead of you hits.
  - Strafing and reversing the moment they fire (a juke) → a led shot misses from 15 m, still hits
    from 11 m. Getting close is how you force damage; pillars are how you survive the approach.
  - So neutral is a guessing game: the shooter guesses your juke timing, you guess their release.

### 2. Trade window opens

A window opens when the opponent:

1. whiffs a skill (in recovery, that light is dark),
2. takes Impact ≥ their Poise (staggered),
3. burns W or E (their best answer to your commit is dark),
4. hits their kit limiter (Cinderhorn overheat: 60t locked).

Window length = their recovery + the time until that light comes back.

### 3. Commit

Spend your best tools inside the window (e.g. E in → Afterburn fan → Q). A commit is a cooldown loan:
you are now dark on E for 5 s. Finish or leave before their lights relight.

### 4. Reset

Someone disengages. The attacker who overstays eats the defender's returning cooldowns. Each loop moves
three things: armor (who is winning), Surge (who threatens R), lights (who can commit next).

### 5. Capitalize (R)

R needs a reason. Fire it when one is true:

- their E is dark (they can't leave the line),
- their W is dark or broken,
- they are staggered or in recovery,
- they are boxed in by a pillar or the sudden-death wall.

R fired into a mech with every light on gets dodged, and that miss is the biggest punish window in the game.

### A typical exchange (Cinderhorn mirror; A starts at Heat ~75, Surge 92)

| t (s) | A | B | Result |
|---|---|---|---|
| 0.0 | Strafing at 11 m, Hot Q | Already strafing | Dodged. Neutral. |
| 1.0 | Reverses direction | Q into A's reversal | Hits A's front: 65 to A's right arm (190 → 125). |
| 2.0 | Walks to 8 m, starts a Q windup | Taps W, expecting the shot | B's plate is up. |
| 2.1 | Feint: E cancels the windup, dashes to B's left | Plate still faces the old angle | B's tap whiffs: 0.5 s committed, W dark for 6 s. |
| 2.4 | Afterburn fan from 4 m into B's left side | Plate down, still in recovery | 135 to B's left arm. A's Surge hits 100. |
| 2.6 | Waits for Q | Dashes away (E) to 9 m | B escapes, but E is now dark for 5 s. |
| 3.2 | Q, mostly to pump Heat back up | Walks, dodges | Miss. A's Heat back above 60. |
| 3.5 | R windup, tracking | W and E dark; walking can't out-turn the tracking | — |
| 4.1 | Lance fires at Heat ~65 | — | 230 to B's Head (300 → 70). A's Heat → 0. Momentum shift. |

B now holds lots of Surge from the damage taken and A has spent R. The next loop belongs to B
unless A respects it.

---

## 2. Control scheme (PC, mouse + keyboard)

Current layout (Victor's call after the third playtest, 2026-10-19). Shooter-style: both attacks on
the mouse, utilities on the keys around WASD. The camera is fixed on the whole arena, so W is always
up the screen.

| Input | Action | Part |
|---|---|---|
| WASD | Move (screen-relative, 8-way) | Legs |
| Mouse | Aim. Torso always faces the cursor | — |
| Left click | Left hand weapon | Left hand |
| Right click | Right hand weapon (melee goes under shields) | Right hand |
| Space | Dash | Booster |
| Q (hold) | Shield, tap for a Perfect Guard | Core |
| E | Chain Hook | Core |
| R | R skill (the core picks it) | Core |
| Esc | Pause | |

**Parts and keys (Exteel rework, 2026-10-21):** left click = left hand, right click = right hand,
either hand holds any weapon; Space = booster dash; legs only walk. The default build keeps the old
feel: a rivet cannon in the left hand (left click shoots), a saw in the right (right click slashes).
Shield and hook are the fixed kit. The garage picks one part per slot (see §5).

### Chain Hook (E, built)

Skillshot claw: 13 m, 40 m/s, 30 damage. On a hit it pulls the target toward you at 22 m/s until
1.8 m away (max 0.4 s), then stuns it 12t. That's the setup for a melee hit. A raised shield in front
blocks it. Cooldown 8 s, +10 Heat.

### Brace (E on the Oni Horns head, built 2026-10-28)

Instant, no windup, no action: for 2 s you take half damage (`BRACE.cut`, applied before an overshield / bubble
soaks the rest, and to traps and hazards too) and walk at half speed (`BRACE.move`). You can still shoot, slash,
dash and raise the shield. Cooldown 12 s, no Heat. Shown as an amber ring burst, a warm glow on the body and the lit E
slot. The bot braces when a shot is incoming or the rival is within 5 m.

### Cleanse (E on the Sun Crest head, built 2026-10-28)

Instant and castable while stunned, jammed or hooked (it runs at the very top of `start`, before the "busy" gate). On
cast it clears your slow, skill lock (`buffs.jam`, from EMP and the arc trail), stagger and a hook pull. Then for 2 s
(`CLEANSE.time`, `buffs.cleanse`, `warded()`) those effects do not stick: slow (frost trail, stasis and bubble-type
fields), skill lock (EMP, arc trail), the hook's pull and stun, and the stun of a leg landing. Damage from them still
lands, and ordinary hit stagger (poise) still works. Pull-type displacement (magnet trail, gravity well) is not
blocked. Cooldown 14 s, no Heat. Shown as a white ring burst, a pale glow on the body and the lit E slot. The bot
casts it when it is slowed, jammed or pulled. Root (Trap, planned) will be cleansed the same way.

### Focus (E on the Sniper Visor head, built 2026-10-28)

Instant, like Brace (the E skills share `E_SPEC` and the cast code in `start`). For 3 s (`FOCUS.time`) every gun shot you
fire does 35% more damage (`FOCUS.dmg`; guns only, so melee, trails and R skills are unchanged) and bolts fly 30%
faster (`FOCUS.speed`, stacks with the Rail core's bolt speed), but you walk at half speed (`FOCUS.move`). No aim
help: you still aim by hand. Cooldown 10 s, no Heat. Shown as a green-white ring that closes in, a teal glow on the
body and the lit E slot. The bot uses it when its gun is ready and the rival is within 40% of the gun's range.

### The other six E skills (built 2026-10-28)

All instant, no windup, no Heat, castable only when not stunned or skill-locked (Cleanse is the exception). Numbers
are the constants in `sim.gd` (`PULSE`, `XRAY`, `FROST`, `ARCWALL`, `TRAP`, `LUNGE`), shown in the HUD slot (lit while a
buff runs) and each has its own `fx` kind and sound.

| Skill (head) | Rule | Cooldown |
|---|---|---|
| Repair Pulse (Medic Dome) | Heals your weakest part 60 over 3 s (`heal_weakest`, the same pick as the Leech core). Any damage that reaches armor stops it. | 14 s |
| Frost Field (Ward Orb) | A circle (3 m) at the cursor up to 10 m away, 4 s. Rivals inside are slowed and cannot dash. Built as a `stasis` field with no damage. | 12 s |
| Electric Wall (Tri-Antenna) | A 4 m wall at the cursor up to 8 m away, 2.5 s. It stops the rival's bolts, missiles, beams and cones like the Bastion wall; your own shots pass. A rival touching it takes 10 to the legs and is slowed 1.5 s, once per wall. | 12 s |
| Trap (Mine Hatch) | A mine 2 m ahead, armed after 0.5 s, lives 12 s. A rival stepping on it takes 35 and is rooted 1.5 s: `buffs.root` stops walking and dashing, shooting still works. Cleanse removes root and the ward blocks it. | 9 s |
| X-Ray (Radar Dish) | 1.5 s in which your bolts, missiles, beams and cones ignore pillars and placed walls (yours and theirs). Mechs still block them. | 16 s |
| Lunge (Rhino Horn) | A 6 m dash toward the cursor (`DASH_MOVES.lunge`, 15 ticks) that hits the first mech in the way for 70, impact 2, and stops there. Costs no dash charge and gives the usual dash-swing afterburn. | 7 s |

Bot rules (`wants_e` in `bot.gd`): Pulse when under 70% health, no shot incoming and the rival is over 8 m away; Frost
Field when it sees the rival 4 to 9 m away; Electric Wall when a shot is incoming; Trap when the rival is 2.5 to 8 m
away; X-Ray when its line to the rival is blocked and its gun is ready (it then fires without sight); Lunge with a
melee weapon, in sight, 3 to 7.5 m. It never presses E in the same tick as a dash.

### Repair pad (built)

At the arena center. Ready 8 s into each round; touching it repairs 60 on every part, broken ones
included, then it comes back 15 s later. A ring around it shows the respawn. It gives the fight a
place to contest, and gives the losing player a reason to take a risk.

### Pickup pads (built, 2026-10-21)

Four pads, one in each cut corner zone (8 m in from the box corners: `PADS`). Waves: the first lands
5 s into the round, then every 12 s; each wave refills every empty pad. The two top pads always get
the same item, the two bottom pads get a different one, so neither side gets luckier (seeded rng in
the state). 2 s before a wave the empty pads show the next item as a flickering hologram. Touch a
pad (0.7 m + body) to take it. Constants: `PICKUP`, `ITEMS` in `sim.gd`.

| Item | Effect |
|---|---|
| Repair kit | +40 to every part, broken ones included |
| Overshield | absorbs the next 120 damage for 8 s (same soak as the Orb head's bubble) |
| Speed boost | ×1.35 top speed, dash cooldown ×0.5, 6 s |
| Power boost | ×1.25 damage (guns, melee, ults), 6 s |
| Coolant | heat to 0, ends an overheat, no heat gain for 5 s |
| Surge cell | +35 Surge |

The bot goes for a pad within 9 m when it is not much farther than the rival and the item helps
(repair below 85% health, coolant above 40 heat, surge not nearly full). Bot vs bot: ~2.5 pickups
per round, rounds 20.8 s, 160 side-swapped matches 87/73.

### Traps and arena hazards (built, 2026-10-21)

Everything hurts both mechs, ignores the Q shield, is soaked by an overshield / bubble, and warns
first. Damage without an attacker goes through `envHit` (no Surge for anyone but the victim's
"taken" share, no hit-stop). Timers run off the round clock (`elapsed`), so they are fully
deterministic. Constants: `TRAPS`, `HAZARDS` in `sim.gd`.

| Thing | Where | Rule |
|---|---|---|
| Crusher plate | top and bottom lane, 5 m from the walls, 3 × 3 m | slams every 6 s (plates half a cycle apart), red flash + beeps 1 s before; 55 to Legs, impact 3 |
| Tesla pylon | center line, pillar rows (solid, r 0.45) | zaps everyone within 3 m every 4 s, glow + whine 0.8 s before; 40 to the arm facing it, impact 1 |
| Oil slick | middle row, in front of each spawn, r 2 | grip ×0.2 (slow to start, slow to stop); hover legs float over it |
| EMP zones (were fire vents; Victor 2026-10-27) | 3 along each of the 8 walls | from 20 s: straight walls and diagonals take turns every 3 s, 1 s warning (faint outline), 1.5 s live, 5 × 2 m off the wall; 12 to Legs every 0.5 s inside + Slow 40t (×0.4 top speed, no dash) |
| Sudden death | all walls | from 45 s the octagon shrinks up to 7 m by the 60 s mark; touching a wall then costs 4 Legs every 0.25 s |

The bot steps away from a plate, pylon or vent lane while it is warning or firing, avoids the moving
walls and skips pickups the walls have swallowed. Bot vs bot, 160 side-swapped matches: rounds
19.8 s, 3 timeouts in 619 rounds, wins 85/75.

Rules:

- **Quick cast** by default: the skill fires on press, aimed where the cursor is when the windup ends.
  Option per skill: hold to show the indicator, release to cast (release with the cursor on your
  own mech = cancel).
- **E dashes in the WASD direction** (no WASD held → toward the cursor). You can dash sideways while
  still aiming at the opponent.
- Ground-targeted skills clamp to max range along the cursor line. The game never walks you into range.
- No target lock, no aim assist, no snap. Mouse or gamepad.
- Raw mouse input, cursor confined to the window, crosshair cursor with the range ring of the last
  used skill.
- **Gamepad** (secondary; Godot port only so far): LS move, RS aim (ground-target distance =
  stick tilt × 16 m; letting go keeps the last aim), LT = left hand, RT = right hand, LB = dash,
  RB = shield (hold), L3 = hook, R3 = R skill, Start = pause. Still no aim assist.
- Not offered: LoL-style right-click-to-move. Click-to-move fights the momentum model.

---

## 3. Sample kit — CHR-01 "Cinderhorn"

*Sample kit numbers below are the v0 draft. Live weapon and part numbers are in §5; the 2026-10-28 balance pass cut the Rivet Cannon to 42 damage.*

Mid-range beetle-type gunner. Biped, medium weight. Plays the heat line: stay hot for damage, never
overheat, cash the heat out with R.

| Slot | Part | Armor | Weight |
|---|---|---|---|
| Head | Horn Sight | 300 | 9 |
| R-Arm | Rivet Cannon | 190 | 10 |
| L-Arm | Bulwark Plate | 190 | 11 |
| Legs | Thruster Greaves — biped, Medium, Poise 2, carries 32 | 190 | — |
| Core | Furnace Core | — | — |

Movement: top speed 6.5 m/s, 0 → top in 0.18 s, top → 0 in 0.12 s, normal traction.

### Passive — Furnace Core (Heat)

- Heat 0–100. Every skill adds its Load as Heat.
- Venting: −15 Heat/s, starting 0.5 s after the last Heat gain.
- **Hot (Heat ≥ 60):** Q deals +30% and +1 Impact. The vents glow; the opponent sees it.
- **Overheat:** a skill that pushes Heat to 100 still fires, then all skills lock for 60t (1 s),
  movement ×0.7. Heat drains 100 → 0 over that second (2026-10-19, Victor: faster and back to 0).
  Shown as steam jets from the back vents, a thermometer gauge over the mech, a red no-shoot
  crosshair with a draining ring, red-tinted skill slots, and a click when you can fire again.
- E vents 25 Heat instantly.
- The rhythm: spamming Q nets ~+11.5 Heat per shot (16 in, ~4.5 vented between 0.8 s shots), so Hot
  after ~5 shots and Overheat after ~9. A good Cinderhorn lives at 60–90 by pacing its shots.

### Q — Rivet Cannon (R-Arm): linear skillshot

| Range | Speed | Hit radius | Damage | Tag | Impact |
|---|---|---|---|---|---|
| Full arena | 60 m/s | 0.3 m | 65 (84 Hot) | `ARMS` | 1 (2 Hot) |

| Windup | Recovery | Cooldown | Load | Recoil | Cancel |
|---|---|---|---|---|---|
| 6t | 12t | 48t (0.8 s) | +16 Heat | 0.2 m | E |

- Stops at the first mech or pillar.
- Leaves the cannon on the right arm (0.25 m right of center) and flies toward the crosshair point,
  so it lands where you aim.
- Hot Q (Impact 2) staggers Light and Medium mechs and stuffs their windups. That is what makes Hot
  dangerous to stand in front of.

### Melee — Gyro Saw bayonet (R-Arm, RMB)

| Range | Arc | Damage | Tag | Impact | Windup | Recovery | Cooldown | Load |
|---|---|---|---|---|---|---|---|---|
| 2.8 m | 120° | 80 (104 Hot) | `LEGS` | 2 (3 Hot) | 8t | 16t | 42t | +14 Heat |

- Instant sweep at the end of the windup, plus a 0.8 m lunge.
- `LEGS` goes under shields: the saw is the answer to a turtling plate.
- Impact 2 staggers Light and Medium mechs, so a landed slash stops their windup.
- Own cooldown, separate from Q: shoot, then slash right away. Same arm, so a broken right arm jams both.
- After a dash (Afterburn): a 360° spin for 60.

### W — Bulwark Plate (L-Arm): directional shield + parry

- Press: the plate is up in 2t, covers a 100° arc toward the cursor and follows it at 540°/s.
  Hold up to 90t. Movement ×0.6. Load +20 Heat.
- **Perfect Guard** (hit in the first 8t): damage negated. Linear projectiles reflect back down their
  path as your hit (`ARMS`, same damage). Melee attackers within 3 m: stagger 30t. +15 Surge.
  Cooldown becomes 2 s (was 3 s).
- **Block:** absorbs up to 160 damage. Past that: **Guard Break** — the plate shatters, you're
  staggered 24t, cooldown 9 s.
- Release: 10t recovery, cooldown 4 s from release (was 6 s; Victor 2026-10-25, to answer missiles).
- **Whiffed tap:** the plate stays up at least 20t, then 10t recovery = 0.5 s committed. That is the bait.
- Doesn't stop: hits from outside the arc, `LEGS` splashes and low sweeps, lobbed shots.

### E — Thruster Greaves: Afterburn Dash (Legs)

- Dash 5 m over 10t in the WASD direction (none → toward cursor). 6t end lag, then a slide carrying
  40% of the dash speed.
- **No invulnerability.** You dodge by not being there.
- Vents 25 Heat.
- Cancels the recovery of Q or the saw, or any windup (feint: 70% cooldown refund, Load refunded; feinting R
  refunds 70 Surge).
- **Afterburn:** a Q within 48t after the dash fires a 3-rivet fan (±12°): 45 each, full range,
  Impact 1, normal Load. All three point-blank = 135. Or the saw instead: a 360° spin for 60.
- Cooldown 5 s.

### R — Horn Sight: Meltdown Lance (Head)

- Costs 100 Surge.
- Windup 36t, rooted. A 1.4 × 16 m line telegraph is shown to both players from the first tick.
  Turn cap during windup 120°/s. Poise +1 during windup.
- Fires an instant beam: **damage = 100 + 2 × Heat** at the moment it fires (100–298). Tag `HEAD`.
  Impact 4. Stopped by pillars.
- After: Heat → 0, recoil 2 m, 24t recovery.
- vs a shield: always breaks it; damage beyond the shield's remaining absorb passes through.
  Perfect Guard halves it, no reflect.
- Stuffed by Impact ≥ 3 during windup: refunds 50 Surge.

Why it works:

- **Heat is the bet.** R pays most at 90+ Heat, one Q from overheat. Venting with E keeps you safe and
  shrinks R.
- **Walking doesn't dodge it.** At 9 m a walking mech crosses ~41°/s of the caster's view; the
  lance tracks at 120°/s. A dash crosses ~190°/s and escapes — but only if it's late (last ~12t).
  Dash early and they re-aim. So R lands when E is dark, or when the dash is badly timed.
- **It finishes, it doesn't open.** Max 298 `HEAD` damage < 300 Head armor. No full-health one-shots.

### Combo routes

| Name | Inputs | Damage | When |
|---|---|---|---|
| Poke | Q | 65 / 84 | Neutral |
| Strafe-fan | E sideways → Q | 135 (one arm, side rule) | Flank, or punishing a whiff |
| Full | E → Q (fan) → Q → R | 135 + 84 + up to 298 | Their E is dark |
| Parry punish | W (Perfect) → Q | reflect + 84 | Against projectile spam |

How Cinderhorn loses: flanked by fast legs (the plate only covers 100°), splashed under the plate,
pressured into overheat, R baited by an opponent whose E is still lit.

---

## 4. Defense and counter-play

1. **Dodge with space.** No i-frames anywhere in v0. Projectiles have travel time; a strafing mech
   can dodge shots from 15 m and beyond. Close range takes that away — that is the real cost of going in.
2. **Cover.** Pillars stop projectiles and beams: peek, shoot, hide. Lobbed ground skills go over
   pillars — that is their job.
3. **Fog.** Inside fog you are invisible unless within 3 m or you used a skill in the last 1 s. They
   guess where to shoot; you guess when to leave.
4. **Facing.** Shields cover the front. Rear hits deal ×1.25. A sideways dash forces the defender to
   turn, and the shield's turn cap is the window.
5. **Parry, and the whiffed parry.** Perfect Guard pays big (negate, reflect, stagger, Surge, short
   cooldown). A whiffed tap is 0.5 s of nothing and 6 s dark. High risk both ways.
6. **Baiting.** Lights make every bait a known risk.
   - Show a windup, make them W, feint with E, hit them in W recovery.
   - Step into their threat range and back out to draw their E.
   - Hold a Hot Q: the glow makes them shield; walk around the shield.
7. **Stagger and stuff.** Impact ≥ Poise cancels windups, so long windups (R) can be stopped. Heavy
   legs trade through pokes; light legs must not stand in front of anything.
8. **Part strategy.** Break the left arm to jam their shield. Break the legs to jam their escape.
   On defense, torso-twist so hits land on the healthy side — at the cost of aim.
9. **Kit limiters.** Against Cinderhorn: bait the E first (it vents), then pressure so it shields
   (+20 Heat) and shoots its way into overheat. 1 s locked is a free punish.
10. **Comeback.** Taking damage pays more Surge than dealing it. The leader must respect a glowing head.

| You do | Beats | Loses to |
|---|---|---|
| Strike (Q / R) | Dash end lag, whiffed parry, recovery | Perfect Guard, cover |
| Guard (W) | Frontal strikes | Flanks, ground splashes, waiting it out |
| Move (E) | Slow strikes; guards (go around) | A strike aimed where the dash ends |

---

## 5. Parts

### Built (garage, Exteel rework 2026-10-21: 10 heads (+ the Rookie Helm, 2026-10-28), 10 cores, 6 arms, 10 legs, 6 boosters, 20 weapons)

Numbers live in `HEADS`, `CORES`, `ARMS`, `LEG_PARTS`, `BOOSTERS` and `WEAPONS` in `godot/src/sim.gd`. The
garage is a store in the Exteel style: PARTS (head, core, arms, legs, booster) and WEAPONS (left
hand, right hand) tabs, part pictures on every card, a turntable, and a stat sheet that shows the
change (green better, red worse) while you hover a card. The AI picks a random build each match.

Balance (2026-10-21): each part played 40 bot-vs-bot matches against a random part in the same slot,
rest of the build equal. Arms 47–55%, legs 45–56%, boosters 45–55%. Weapons were not retuned: guns
win 37–76% and melee 40–55% against a random weapon of either type; the mortar sits at 17–24%
because bots step out of every landing circle (it under-rates lobs). Bots, not people: re-tune from
playtests.

**Missile nerf (2026-10-25, Victor: "missiles are too OP").** Any enemy projectile (not the hook) or
beam (laser, rail, lance) that touches a missile destroys it mid-air; a projectile that does is used
up too (`intercept`, swept test on relative motion, so fast bolts can't tunnel). Covers the Swarm
ult's missiles too. Hornet Pod cooldown 1.2 → 1.8 s, shield cooldown 6 → 4 s (Perfect Guard 3 → 2 s).
Bot round-robin, Hornet Pod vs each other weapon in the same hand, 4 seeds side-swapped: 67% → 53%
of rounds; it now loses to the laser (18%) and the gatling (27%), which shred missiles.

#### Weapons (left or right hand)

Guns:

| Part | Kind | Damage | Range | Cooldown | Notes |
|---|---|---|---|---|---|
| Rivet Cannon | bolt | 42 | 40 m | 0.8 s | Fast bolts across the whole arena. Good at everything. |
| Needle Rifle | bolt | 69 | 40 m | 1.6 s | Slow to fire, but every shot hits hard and flies fastest. |
| Scatter Gun | bolt | 5 × 21 | 12 m | 0.9 s | 5 pellets, short range. Brutal up close. |
| Buzz Gatling | bolt | 11 | 30 m | 0.17 s | Tiny bullets, nonstop. Hold the button. |
| Blaze Thrower | bolt (flame) | 2 × 11 | 6.5 m | 0.13 s | Short cone of fire. Hold the button. Shields put it out. |
| Hornet Pod | bolt (missile) | 2 × 34 | 40 m | 1.8 s | Two missiles that chase the target. Enemy bullets and beams shoot them down. |
| Thump Mortar | lob | 154 | 16 m | 1.8 s | Lobs a shell at the cursor. Lands later, over shields and pillars. |
| Prism Laser | ray | 26 | 18 m | 0.67 s | Instant beam. Hits the moment you fire. |
| Arc Coil | cone | 71 | 7 m | 0.9 s | Short zap that jumps to whatever is in front of you. |
| Bounce Rifle | bolt | 44 | 40 m | 0.87 s | Bolts bounce off walls and pillars twice. |

Melee (hits Legs, goes under shields):

| Part | Damage | Reach | Arc | Windup | Cooldown | Impact | Notes |
|---|---|---|---|---|---|---|---|
| Gyro Saw | 77 | 2.8 m | 120° | 8t | 0.7 s | 2 | Quick, wide slash. |
| Drill Lance | 116 | 4.2 m | 48° | 10t | 1 s | 3 | Long, narrow thrust. Big damage. |
| Shock Hammer | 84 | 2.5 m | 170° | 14t | 1.2 s | 4 | Slow and wide. Sends them flying. |
| Rake Claws | 2 × 40 | 2.3 m | 100° | 6t | 0.57 s | 1 | Two fast slashes per swing. |
| Chain Lash | 108 | 5 m | 52° | 8t | 0.8 s | 2 | Longest reach. Yanks them toward you. |
| Piston Spike | 168 | 1.9 m | 60° | 16t | 1.67 s | 4 | Slow and short. Huge damage. |
| Ion Blade | 63 | 3 m | 140° | 6t | 0.57 s | 2 | Fast, wide energy cut. |
| Riot Plate | 65 | 2.2 m | 190° | 10t | 0.83 s | 3 | Shield bash. Wide, staggers hard. |
| Rocket Fist | 112 | 4.4 m | 68° | 9t | 1.1 s | 3 | Rockets you forward into a punch. |
| Wrecking Flail | 86 | 3.4 m | 360° | 9t | 1.1 s | 2 | Spins all around you. Hits every side. |

#### Arms (armor of both arms, hand speed)

Hand speed multiplies windup, recovery and cooldown of both hands' weapons.

| Part | Series | Armor (each arm) | Hand time |
|---|---|---|---|
| Wire Arms | Light | 155 | ×0.88 |
| Reed Arms | Light | 168 | ×0.93 |
| Frame Arms | Standard | 190 | ×1 |
| Brace Arms | Standard | 205 | ×1.04 |
| Bulwark Arms | Heavy | 230 | ×1.08 |
| Anvil Arms | Heavy | 258 | ×1.13 |

#### Legs (movement + dash move)

| Part | Series | Top speed | Accel | Poise | Armor | Dash move |
|---|---|---|---|---|---|---|
| Thruster Greaves | Standard | 6.5 m/s | 0.12 s | 2 | 190 | Dash: straight burst |
| Hover Skirt | Light | 8 m/s | 0.22 s | 2 | 175 | Glide: ×1.4 distance, ×1.6 time, steerable |
| Crawler Treads | Heavy | 5.2 m/s | 0.1 s | 3 | 235 | Ram: contact 45 dmg, impact 3, pushes 2.5 m, stops |
| Skitter Legs | Standard | 6.8 m/s | 0.07 s | 2 | 185 | Skitter: 2 charges, ×0.6 distance, ×0.65 recharge |
| Twin Wheels | Light | 9 m/s | 0.35 s | 2 | 185 | Drift: ×1.1 distance, steerable, keeps 85% speed |
| Jet Boots | Light | 7.6 m/s | 0.16 s | 1 | 180 | Leap: airborne, landing 2.2 m: 20 dmg + 0.5 s stun + lift |
| Quake Stompers | Heavy | 4.6 m/s | 0.12 s | 4 | 255 | Slam: short airborne hop, landing 3 m: 30 dmg + 0.6 s stun |
| Rail Skates | Light | 8.5 m/s | 0.3 s | 2 | 190 | Double: 2 charges, ×0.85 distance |
| Quad Strider | Standard | 7.4 m/s | 0.1 s | 2 | 182 | Pounce: airborne to the cursor, landing 1.6 m: 28 dmg, impact 3 |
| Unicycle | Standard | 7.8 m/s | 0.22 s | 2 | 195 | Roll: contact 35 dmg, impact 2, goes through |

#### Booster (Space dash + trail)

| Part | Series | Dash | Recharge | Trail |
|---|---|---|---|---|
| Flicker Jet | Light | 3.8 m | 3.33 s | Arc: 25 dmg once + 0.5 s skill lock |
| Wisp Fins | Light | 4.5 m | 4 s | Frost: slows inside, 2.5 s |
| Back Thruster | Standard | 5 m | 5 s | Flame: 8 dmg + 6 heat every 0.25 s, 2 s |
| Twin Thruster | Standard | 6 m | 5.33 s | Smoke: hides you, 3 s |
| Comet Engine | Heavy | 7 m | 5.5 s | Magnet: pulls them 2.5 m at the end (within 7 m) |
| Rocket Pack | Heavy | 8.5 m | 6.5 s | Clean: none |

#### Head (K.O. armor and R charge)

Heads do not pick the R skill (the core does). R charge multiplies every Surge gain.

A head carries the E skill (`e` in `HEADS`; Victor 2026-10-28). Q stays the shield for everyone. Every head has its own
E skill (table below); the Rookie Helm has none, so its E slot on the HUD is blank, the key does nothing and the bot
never presses it. Shockwave was parked: it duplicates the Stompers Slam and the EMP R skill.

| Part | Series | Armor | R charge | E skill |
|---|---|---|---|---|
| Rookie Helm (default) | Standard | 305 | ×1 | none |
| Rhino Horn | Standard | 310 | ×1 | Lunge |
| Stag Pincers | Standard | 292 | ×1.08 | Chain Hook |
| Sun Crest | Light | 295 | ×1.3 | Cleanse |
| Radar Dish | Standard | 296 | ×1.04 | X-Ray |
| Sniper Visor | Light | 288 | ×1.4 | Focus |
| Medic Dome | Heavy | 310 | ×0.86 | Repair Pulse |
| Ward Orb | Standard | 308 | ×0.92 | Frost Field |
| Tri-Antenna | Standard | 290 | ×1.12 | Electric Wall |
| Mine Hatch | Standard | 304 | ×0.94 | Trap |
| Oni Horns | Heavy | 305 | ×0.8 | Brace |

Bot check, 2026-10-28 (each head on a build vs the same build with the Rookie Helm; three builds: default, brawler set,
sniper set; both sides; draws did not occur). First run, 60 matches per head, wins: Rookie mirror 20, Lunge 21, Trap 24,
Focus 25, Frost Field 29, Hook 30, Cleanse 31, Repair Pulse 34, X-Ray 37, Brace 43, Electric Wall 44. Tuned from that:
Electric Wall 3 s to 2.5 s and 10 s to 12 s cooldown; Brace cooldown 9 s to 12 s and Oni Horns armor 335 to 325;
X-Ray cooldown 14 s to 16 s; Lunge 30 to 40 damage, 8 s to 7 s cooldown and a longer bot range; Trap 25 to 35 damage,
0.6 s to 0.5 s arming, 10 s to 9 s cooldown; Focus 25% to 35% damage and 12 s to 10 s cooldown. Second run, 90 matches
per head, wins: Lunge 41, Trap 41, Focus 43, Hook 46, Electric Wall 47, X-Ray 50, Brace 53. Every tuned head is now
within 46% to 59%; Hook is 51%. Cleanse, Frost Field and Repair Pulse were in range and left alone (52%, 48%, 57% on
the first run). The Rookie mirror wins only 33% on its own, so the builds favour the second name slightly: read the
numbers against Hook, not against 50%.

#### Core (R skill + passive)

| Part | Series | R skill | Windup | Skill effect | Passive |
|---|---|---|---|---|---|
| Furnace Core | Standard | Lance | 36t | aimed laser lance at the head. Hotter = stronger. | heat damage bonus from 50 heat instead of 60 |
| Coolant Core | Standard | Stasis | 12t | field at the cursor. Hurts, then slows and blocks dashes inside. | skills make 40% less heat, cools twice as fast, +4% armor |
| Surge Reactor | Standard | Overdrive | 6t | 12 s of double-speed cooldowns and no heat. | R meter fills 100% faster, starts at 60 |
| Leech Core | Standard | Repair | 18t | repairs every part by 50 and clears your heat. | 3% of damage dealt repairs your weakest part |
| Titan Core | Heavy | Mines | 14t | drops a ring of 6 mines around you. | +14% armor, 8% slower |
| Volt Core | Light | EMP | 24t | pulse around you. Hurts (75) and locks their skills for 2 s. | dash recharges twice as fast, 30% farther, dumps heat |
| Fury Core | Standard | Berserk | 6t | 6 s of harder, faster melee and more speed. | up to +25% damage as your head gets low |
| Flywheel Core | Light | Swarm | 12t | 8 homing missiles in a fan. | up to +12% damage at full speed |
| Aegis Core | Heavy | Bubble | 6t | bubble that soaks the next 180 damage for 4 s. | shield recharges twice as fast, holds 190, +5% armor |
| Glass Core | Light | Orbital | 10t | huge strike at the cursor after a short delay. | +15% damage, -12% armor |
| Phantom Core | Light | Blink | 6t | teleport to the cursor (9 m); the afterimage explodes 0.6 s later (2.2 m, 70) | after-dash power move lasts twice as long, +8% armor |
| Gravity Core | Standard | Gravity Well | 12t | field at the cursor (5 m, 4 s): 40 dmg, pulls 4 m/s toward the center | hook reaches 60% farther |
| Bastion Core | Heavy | Bastion | 8t | 4 m wall 2.5 m ahead blocks every shot and beam for 4 s | shield holds 210, +8% armor |
| Meltdown Core | Standard | Meltdown | 10t | blast around you (3.5 m): 40 + 1.4 × heat, impact 3; heat to 0 | running hot gives +50% damage instead of +30% |
| Deflector Core | Standard | Deflect | 6t | 3 s: enemy shots within 3 m bend away from you | Perfect Guard window 50% wider |
| Mirror Core | Standard | Mirror | 4t | 2 s: every shot hitting your front 140° bounces back; beams are blocked | reflected shots hit 15% harder |
| Rail Core | Standard | Rail Shot | 30t | 40 m beam through pillars: 130, impact 3 | bullets fly 15% faster, +6% armor |
| Shroud Core | Light | Shroud | 6t | 4 m smoke cloud around you for 4 s | moves 12% faster, +12% armor |

Balance (bots, 40 matches each, a part vs a random part in the same slot, rest equal, 2026-10-22):
cores 39–65%, legs 38–62%, boosters 49–57%, heads 42–60%. Bots, not people: re-tune from playtests.

**Balance pass (2026-10-28, Victor: balance as much as possible without making the weight types pointless).** About 13,000 bot-vs-bot matches of random mixed builds (4 in 5 parts picked from one series for half the builds, so weights 5 to 15 are all covered), fitted with a logistic model that scores each part against the rest of the build. Before: weapons won 23% to 78%, cores 31% to 73%, legs 37% to 61%, heads 40% to 61%; a weight-5 build won 41% and a weight-15 build 58%. After this pass (last round 2,635 matches): weapons 31% to 61%, cores 38% to 63%, legs 45% to 59%, heads 41% to 57%; weights 6 to 13 sit at 46% to 54%, weight 15 at 55%. Arms and boosters were already within 47% to 54% and are untouched. What moved: guns cut (Rivet 65 to 42, Needle 115 to 69, Laser 40 to 26, Hornet, Scatter, Bounce Rifle), melee up (Whip, Fist, Hammer, Flail, Flamer, Bash most), Leech, Aegis, Mirror, Fury, Furnace, Flywheel trimmed; Rail, Reactor, Shroud, Phantom, Gravity, Coolant lifted; heavy heads trimmed and light heads lifted; Quad Strider and Quake Stompers trimmed; Light and Unicycle legs poise 1 to 2 (poise 1 was staggered by every bolt). Raising `WEIGHT.speed` from 0.025 to 0.04 made no measurable difference, so weight matters through part stats, not speed. Known limits: bots, not people (they play guns better than melee and dodge the mortar, so Mortar numbers are a guess); the guns still lead melee by about 5 to 10 points; heavy builds keep a 3 to 5 point edge; Rail Core is still the weakest core. Re-tune from playtests.

### Sketch (not built)

| Slot | Part | Skill | Plays like |
|---|---|---|---|
| L-Arm | Snare Pod | trap at cursor ≤ 8 m, arms after 30t, roots 48t, lasts 10 s | Trapper |
| L-Arm | Phase Coil | blink 4 m toward cursor after a 12t windup | Slippery |
| Legs | Spring Quad | Pounce: leap to cursor ≤ 6 m, airborne 24t (splashes and traps miss) | Hunter |
| Core | Magazine Core | Load → rounds: 8 rounds, 1 per skill; empty → 1.4 s reload; last round +40% | Rhythm |

---|---|---|---|
| R-Arm | Arc Mortar | Q: ground target ≤ 10 m, lands after 40t, 1.8 m splash, `LEGS`, lobs over pillars and shields | Zoner |
| L-Arm | Snare Pod | W: trap at cursor ≤ 8 m, arms after 30t, roots 48t, lasts 10 s | Trapper |
| L-Arm | Phase Coil | W: blink 4 m toward cursor after a 12t windup | Slippery |
| Legs | Spring Quad (multi-leg, Light) | E: Pounce — leap to cursor ≤ 6 m, airborne 24t (splashes and traps miss) | Hunter |
| Head | Lock Array | R: 5 m field at cursor ≤ 10 m for 3 s; mechs inside can't use E | Setup |
| Head | Overclock Crest | R: 6 s of cooldowns ×0.5 and Load ×0 | Burst |
| Core | Magazine Core | Load → rounds: 8 rounds, 1 per skill (2 if Load ≥ 20); empty → 1.4 s reload; last round +40% | Rhythm |
| Core | Flywheel Core | Load is free. Momentum +20/s at top speed, drains when slowing; at 100 the next hit deals +50% and +1 Impact | Always moving |

---

## 6. Open questions

- **Stack.** Not chosen.
- **Netcode.** Two players with mice = online. A fixed-tick deterministic sim fits rollback
  (GGPO-style). Local 1v1 needs one player on a gamepad.
- **Fog vs rollback.** Rollback clients know both positions, so fog is hackable. Keep fog and accept
  it, or go server-authoritative, or drop fog.
- **Solo practice.** A training dummy that strafes and fires Q on a timer is enough for a first playable.
- **Hit side.** Is torso-twist readable in playtest, or should `ARMS` simply split 50/50?
