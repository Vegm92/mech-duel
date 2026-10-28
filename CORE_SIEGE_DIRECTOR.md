# Mech Duel — Core Siege Director v0

Draft 2026-10-28 (UTC). The **Producer** (code name `director`): a game manager for Core Siege
(`CORE_SIEGE_DESIGN.md`). Think TV show producer plus the AI director from co-op games: the show
must never bore the audience, so it tweaks each wave to the team in front of it. Every number here
is a v0 guess: **tune later**, all of them.

Victor's goals (2026-10-28): let people have fun and feel competent; if it gets too easy, crank it
up; leave room to breathe and gather forces; use tactics and squad moves for ambushes and different
levels of complexity.

Decisions (Victor, 2026-10-28, one question each):

| # | Question | Pick |
|---|---|---|
| 1 | When may it act? | **At the warning only.** It plans the whole wave 8 s ahead, ambush timing included. A live wave never changes. |
| 2 | How does it measure the team? | **A live meter.** One pressure sample per second, averaged per wave. |
| 3 | What does it aim for? | **A curve.** A 5-wave beat (warm-up, build-up, peak, breather, push), rising slowly over the run. |
| 4 | Too easy: how does it crank up? | **Smarter first.** Nastier tactics; the budget moves only ±15%. |
| 5 | How much new bot brain? | **Spawn tricks first (data).** One brain order, "gather then push", later. |
| 6 | What does a breather give? | **Just time.** A small wave, then a build phase 15 s longer. |
| 7 | How visible is it? | **Only the tactics.** The announcer calls the tactic; it never says it is going easy on you. |
| 8 | How do we test it? | **Skill knobs per brain** in `bot.gd`: skilled, average and weak bot teams. |

---

## 0. Ground rules

- Lives in the sim (`godot/src/siege.gd`), state in `state.siege.director`. Pure and seeded: it
  counts ticks (never the wall clock) and picks only with `Sim.rng(state)`. Same seed + same inputs
  = same hash. The duel and its `GOLDEN` are untouched (the director only runs in siege).
- Acts in one place: `plan(state, sg, n)`, called at the wave's 8 s warning. After that, the wave
  runs as queued.
- Reads only what the sim already has (core, gates, mechs, enemies, wave timer). No view, no hype
  input (hype is the show's output, §6).
- Co-op scale 1–4: the budget already scales with `budget(n, team)`; the pressure sample divides by
  team size; tactics have a minimum team size where it matters (§4).
- Off switch for tests and A/B: `--director=off` (plans exactly like today).

**Never** (tests check each one, §8):
- spawn bots anywhere but the lane border mouths, the air corners and the side vents, and never
  within 8 m of a player (a vent with a player near it is skipped for the other vent, or the
  ambush waits 2 s and checks again);
- take away scrap anyone earned, or touch player stats (no hidden damage or armor changes);
- spawn a bot without a gate warning at least `RUN.warn` (8 s) before it (delayed groups get their
  own warning, §4);
- change a boss wave's `must` list (10, 15, 20, 30), or bring Mk 2/3 or boss squads earlier than
  `row(n)` allows;
- change a wave after it started.

## 1. Sense: the pressure meter (tune later)

While a wave is live (`wave.live`), every 60 ticks the sim takes one **pressure sample**, 0–100:

```
P = 100 × clamp(0.30·core + 0.25·armor + 0.20·down + 0.15·breach + 0.10·gate, 0, 1)
```

| Term | 0 → 1 means | Formula |
|---|---|---|
| core | the core is bleeding | core HP lost in the last 5 s ÷ (5% of core max), cap 1 |
| armor | the team is worn down | 1 − average (armor ÷ max armor) of team mechs not K.O. |
| down | mechs are out | team mechs K.O. ÷ team size |
| breach | bots are inside | enemy bots (not neutral) inside the fortress ring ÷ 3, cap 1 |
| gate | a gate is falling | worst gate's HP lost in the last 5 s ÷ (10% of gate max), cap 1 |

Neutral yard bots never count (farming risk is the player's choice).

**Wave score** `W(n)` = the average of the wave's samples, minus a speed term so a fast, clean
clear reads as easy:

```
W = average(P) − 15 × (1 − clear_ticks / RUN.cap)      (speed term only when the wave is cleared)
```

If the next wave is planned while this one is still live (the 90 s cap), `W` uses the samples so
far.

**Strain** `S` = the team's reading, smoothed so one bad moment never swings it:
- `S = 0.5·W(n) + 0.3·W(n−1) + 0.2·W(n−2)` (fewer waves: renormalize the weights);
- `S` moves at most **±15** from its last value per wave;
- an average, never a peak: one scary second is 1 sample out of 30–90.

Not inputs, on purpose: wallets and shop spending (reward, not struggle), crowd hype (output), how
clustered the players are (used to pick lanes for a tactic, §4, not to judge difficulty).

## 2. The curve: a 5-wave beat (tune later)

Beat position `b = ((n − 1) % 5) + 1`. The target pressure for wave n is the beat's target plus a
slow rise over the run: `target(n) = BEAT[b].target + min(10, floor(n / 3))`, cap 90.

| b | Beat | Target | Budget × | Tactic tier | After the wave |
|---|---|---|---|---|---|
| 1 | Warm-up | 40 | 0.9 | 0–1 | normal build phase |
| 2 | Build-up | 55 | 1.0 | 1 | normal |
| 3 | Peak | 70 | 1.1 | 2 | normal |
| 4 | Breather | 30 | 0.7 | 0 (no tactic) | build phase **+15 s** |
| 5 | Push | 85 | 1.15 | 2–3 | normal |

- Every breather (4, 9, 14, 19, 24, 29) lands right before a push or a boss (5, 10, 15, 20, 25,
  30): the extra 15 s is the "gather your forces" window (shop, repair, a yard run, Recall).
- Waves 1–3 teach: the director measures but does not steer (dial fixed at 0, tier 0).
- Boss waves keep their `must` list; the director only scales the filler budget and may pick a
  tactic for the filler.
- Endless (31+): the beat goes on, targets cap at 90, mutators stack as today.

## 3. Dial: how it steers (tune later)

At each wave's end (or at the next plan if the wave is still live):

```
gap = target(n) − S          (positive = it was easier than we wanted)
D   = clamp(D + gap / 50, −1, 1)        (the dial; starts at 0; remembers lasting skill)
```

Planning wave n+1 (smarter first, bigger second):
- **Tactic tier** = the beat's tier, +1 if `D > 0.5`, −1 if `D < −0.5`, clamped 0..3.
- **Budget** = `budget(n+1, team) × BEAT[b].mult × (1 + 0.15·D)`. The dial alone moves the
  budget by ±15% at most.

Both-ways rules:
- **Too easy:** `gap > 20` two waves in a row → the next non-breather wave picks from the top tier
  allowed for that wave.
- **Pity:** `gap < −20` two waves in a row → the next wave uses tier 0 (no tactic) and `D` acts as
  −1 for its budget (−15%). No gifts, no free scrap. One wave only, then the normal dial again.
- **Skill still wins:** the dial never goes past ±15% budget, never removes a boss, never touches
  stats. A weak team still loses; it just loses later and closer.

## 4. Tactics (data, tune later)

A tactic only decides **where, when and what** spawns. `plan()` already queues each bot with its
own tick, lane and side; a tactic reorders that queue. Each row is data in a `TACTICS` table in
`siege.gd`.

**Warning rule:** every group that spawns later than the wave start gets its own `warn` fx exactly
`RUN.warn` before its first bot (a queued warning entry), so the gate always tells the truth.

| Tactic | Tier | From wave | Min team | What it does | Code |
|---|---|---|---|---|---|
| straight | 0 | 1 | 1 | today's plan: lanes by `Sim.rng`, tanks first, ranged +5 s | none |
| probe | 1 | 4 | 1 | a Scout Pack (from the budget) on lane X at 0 s; the rest of lane X's load at +20 s | data + per-group delay |
| vent ambush | 1 | 4 | 1 | the wave's Ambush Cells spawn at the side vents at +25 s instead of with the lane push (spiders already spawn at vents) | data + delay |
| pincer | 1 | 6 | 1 | the load split over two **opposite** lanes (N+S or E+W), same tick | data (lane pick) |
| air drop | 2 | 7 | 1 | the Air Wing / Raiders flyers come from the corner between the two busiest lanes, timed with the lane push reaching the chokepoint at 36 m (+20 s) | data + delay |
| feint | 2 | 8 | 1 | ¼ of the budget on lane A at 0 s; ¾ on the lane with the fewest players near it at +15 s | data + delay + reads player positions |
| siege first | 2 | 12 | 1 | ranged bots (turret, tripod, quad heavy) go first and plant; tanks and escorts follow at +12 s | data (reverse the order) |
| hammer and anvil | 3 | 15 | 2 | pincer + vent ambush + air drop, all on one beat | data (combines rows) |
| gather then push | 3 | later | 2 | the lane's squads wait at the 58 m chokepoint until all arrive, then push as one | **new brain order in `drive`** (not v0) |

- Picking: among the rows allowed by tier, wave, team size and the wave's pool (e.g. no vent
  ambush without an Ambush Cell), pick with `Sim.rng`. Tier 0 always means `straight`.
- Breathers always use `straight`.
- Later, not v0: **retreat and regroup** (hurt bots pull back and join the next squad) and
  **sleepers** (team-1 bots lying `dormant` in a lane; the camp `awake` code is a start). Both need
  new sim code.

## 5. Breathing room

- Breather wave (beat 4): budget ×0.7, `straight`, then a build phase 15 s longer
  (`RUN.build + 15 s`, or `RUN.buildLate + 15 s` from wave 21).
- Pity wave (§3): the same plain shape, one wave.
- Calling the wave early still works and still pays; a team that skips its breather chose to.

## 6. Show

- One new fx: `{"k": "tactic", "id", "lanes": [..], "t": 180}`, emitted when the tactic's first
  group spawns (not at plan time, so the surprise lands with the bots).
- **Announcer:** one big call (Exo 2, like the K.O. calls) under the wave plate for 3 s, text from
  i18n `dir_<tactic>` with the lane names. Never a line about difficulty. Examples:

| Key | en | es |
|---|---|---|
| `dir_probe` | SCOUTS FIRST — the main push follows! | ¡EXPLORADORES! ¡El grueso viene detrás! |
| `dir_ambush` | AMBUSH! Spiders in the vents! | ¡EMBOSCADA! ¡Arañas en las rejillas! |
| `dir_pincer` | PINCER! {a} and {b}! | ¡PINZA! ¡{a} y {b}! |
| `dir_airdrop` | AIR DROP from the {corner}! | ¡DESEMBARCO AÉREO desde el {corner}! |
| `dir_feint` | FEINT! The real push hits {lane}! | ¡FINTA! ¡El ataque real va por {lane}! |
| `dir_siege` | ARTILLERY SETTING UP! | ¡ARTILLERÍA EN POSICIÓN! |
| `dir_hammer` | HAMMER AND ANVIL! Everything at once! | ¡MARTILLO Y YUNQUE! ¡Todo a la vez! |
| `dir_breather` | Catch your breath. Big push next. | Respira. Viene un gran ataque. |

- **Crowd:** the `tactic` fx adds hype (`POINTS.tactic` ≈ 10, an "ooh"); the live pressure sample
  can set a siege hype floor (`floor = 0.5 × P`) so a tense wave keeps the stands loud. Both are
  view-side; the sim only emits fx and keeps `director.pressure` readable.
- **Sound:** `tactic` needs a `RECIPES` row in `sfx.gd` (`sound_test` fails without it).
- No "PRODUCER" tag, no mood meter on the HUD.

## 7. State

```
siege.director = {
  on: bool, dial: float, strain: float, scores: [W x3, newest first],
  pressure: float,           # last sample, 0..100 (views may read it)
  sum: float, samples: int,  # this wave so far
  hist: {core: [5 s ring], gate: [5 s ring]},
  easy: int, hard: int,      # streaks for the both-ways rules
  tactic: String,            # this wave's pick
}
```

## 8. Test plan

In `godot/tests/siege_rules_test.gd` (fast):
- A calm crafted state samples 0; a core losing 5% in 5 s samples ≥ 30; all mechs down samples ≥ 20.
- One spike second in an otherwise calm wave moves `S` by less than 5; no wave moves `S` more than 15.
- Beat: waves 4/9/14 plan ×0.7 budget with `straight` and a build phase 15 s longer.
- Each tactic (forced by a test hook): every queued group has a `warn` fx ≥ `RUN.warn` before its
  first bot; every spawn is at a mouth, air corner or vent, ≥ 8 m from every player.
- Boss waves keep their `must` list; no Mk above `row(n)`; the fund and wallets never go down
  because of the director.
- Waves 1–3 plan the same with the director on and off.
- Same seed → same hash; the siege golden hash changes once (intentional); the duel `GOLDEN` and
  every other test are untouched.

Balance run (`tools/siege_balance.gd`, slow, not in the normal test list): bot-only teams of 2 on
3 seeds, waves 1–30, director **on vs off**, with per-brain skill knobs in `bot.gd` (default = today's
`BOT`, so the duel stays the same):

| Team | aimError | reaction | dodge |
|---|---|---|---|
| Skilled | 0.3 | 0.15 | 0.5 |
| Average | 0.9 | 0.3 | 0.25 (today) |
| Weak | 1.6 | 0.5 | 0.1 |

Pass when:
- **Skilled:** its average wave pressure is higher with the director on (it gets pushed), and its
  dial ends above +0.3.
- **Weak:** it lasts **at least 2 more waves** with the director on, and its dial ends below −0.3.
- **All three:** at least 70% of waves 4+ land in the fun band (pressure 30–80).
- **Skill still wins:** with the director on, skilled reaches ≥ 5 waves further than weak.
- The report prints per wave: n, beat, target, W, S, D, tactic, budget, core %, K.O.s.

## 9. Open questions

- Should the feint's "lane with the fewest players" read AI allies too, or only humans?
- Does a solo player (team 1) get pincers from wave 6, or from wave 10?
- When "gather then push" lands, does it replace `probe` at tier 1 or sit at tier 3 only?
