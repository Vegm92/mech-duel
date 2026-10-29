# Set Bonus — Design (draft, 2026-10-29)

Victor's idea: a set is only a shortcut today. Wearing a whole set should give a small extra that
fits what the set is for. Also: new sets for the parts no set uses (6 cores + Rocket Fist).

Status: **built 2026-10-29** (Victor: "Go, build it"). Final numbers and balance results: `COMBAT_DESIGN.md` §5 "Sets and set bonus".

## 1. Rule

**Full set only: all 7 parts.** No partial tiers.

- One rule, on or off. Easy to read in the garage and in a match. Tiers (4/7 pieces) invite
  "4 sniper parts + 3 others" builds and need two numbers per set and more UI.
- **Hand side does not matter.** Needle left + laser right = laser left + needle right. Swapping
  hands is a comfort choice, not a different build.
- **Level does not matter.** A Mk 2/3 part still counts. The bonus stacks on top of the level twist.
- Swap one part → bonus off. The garage shows it the moment you hover the swap.

## 2. How it works in the sim (no per-tick cost)

Every bonus is **one stat the game already reads**, multiplied once. No new combat logic.

- New table `SET_BONUS` in `sim.gd`: `{set: {slot or weapon id: {stat: multiplier}}}`.
  Body parts by slot (`core`, `legs`, ...), weapons by id (`needle`), so the hand does not matter.
- New `Sim.set_of(lo) -> String`: the 5 body slots must match, the 2 hands match as a pair in any
  order, `lv` is ignored. Garage, HUD and `make_mech` all use this one function (it replaces
  `garage.gd`'s own exact-match `set_of`).
- `make_mech`: if `set_of(lo) != ""`, build `m.rows` (same as levels already do) and multiply the
  bonus stats into those rows. Everything reads parts through `core(m)`, `weapon(m, hand)`,
  `feet(m)`, `booster(m)`, so it just works. One extra line: `max_armor` must read the core
  `armor` from the row, not from `CORES` (for the Tank bonus).
- `m.set` holds the set id (or `""`) for the HUD.
- Every stat below is already read through a row (checked): `dmg`, `range`, `splash`, `cd` on
  weapons; `top` on legs; `dashCd` on boosters; `fury`, `leech`, `momentum`, `hotDmg`,
  `reflectDmg`, `perfect`, `absorb`, `afterburn`, `surgeGain`, `speed`, `armor` on cores.

## 3. The 12 sets we have

| Set | Role | Bonus | Numbers |
|---|---|---|---|
| Duelist | All-rounder | **Well drilled**: both weapons cool down faster | Rivet + Drill cooldown ×0.92 (−8%) |
| Sniper | Kills from far away | **Steady shot**: Needle hits harder | Needle dmg ×1.12 (69 → 77) |
| Brawler | Rage up close | **Bad temper**: Fury grows more when hurt | Fury Core 0.25 → 0.35 (up to +35% dmg) |
| Tank | Soaks hits | **Plated**: more armor everywhere | Core armor ×1.05 (Aegis 1.05 → 1.10) |
| Speedster | Fastest build | **Redline**: higher top speed | Legs top ×1.05 (9 → 9.45 m/s) |
| Artillery | Shells from cover | **Wide shells**: bigger mortar blast | Mortar splash ×1.25 (1.8 → 2.25 m) |
| Assassin | Dash in, cut, leave | **Ambush**: power move after a dash lasts longer | Phantom afterburn 2 → 3 (1.6 → 2.4 s) |
| Pyro | Hot = strong | **Fever**: more damage while hot | Meltdown hot dmg ×1.1 (1.5 → 1.65) |
| Controller | Pulls and punishes | **Long arc**: Arc Coil reaches farther | Tesla range ×1.08 (7 → 7.6 m; was ×1.15, trimmed by the round-robin) |
| Vampire | Heals by hitting | **Thirst**: heals more per hit | Leech 3% → 4.5% |
| Reflector | Sends shots back | **Polished**: reflected shots hit harder | Mirror reflect ×1.13 (1.15 → 1.3) |
| Glass Cannon | Huge damage, breaks fast | **Overcharge**: even more damage | Glass dmg ×1.05 (1.15 → 1.21) |

**Parts check:** all 12 still read right for their role. No swaps. (Assassin and Speedster both use
Sun Crest; Cleanse fits both — escape a stun and run.)

## 4. Six new sets (one per unused core)

| Set (en / es) | Role | Head | Core | Arms | Legs | Booster | Left | Right | Bonus |
|---|---|---|---|---|---|---|---|---|---|
| Overclock / Turbo | Charges R fastest, then fires nonstop | antenna | **reactor** | frame | mono | thruster | laser | tesla | **Overload**: R charges faster — surgeGain ×1.1 (2.0 → 2.2) |
| Juggernaut / Coloso | Slow, armored, one huge punch | horn | **titan** | anvil | treads | rocket | **fist** | rivet | **Unstoppable**: Titan's slow mostly gone — core speed ×1.08 (0.92 → 0.99) |
| Hornet / Avispón | Fast kiter, missile swarm | crest | **flywheel** | wire | hover | flicker | missiles | rivet (was gatling: 74% win rate) | **Slipstream**: more damage at full speed — momentum 0.12 → 0.18 |
| Rampart / Muralla | Holds the line behind wall + shield | demon | **bastion** | bulwark | greaves | thruster | rivet | bash | **Hold fast**: shield holds more — absorb ×1.15 (210 → 241) |
| Riposte / Réplica | Parry, then cut | visor | **deflector** | brace | skates | twin | katana | ricochet | **Riposte**: wider Perfect Guard — perfect ×1.25 (0.2 → 0.25 s) |
| Wraith / Espectro | Ambush from smoke | dish | **shroud** | reed | spider | twin | scatter | claws | **Fog runner**: more smoke trails — booster dashCd ×0.85 |

Rocket Fist goes in **Juggernaut**: lunge 3 m + horn charge + treads ram = a mech that crashes in.

Descriptions (`sd_` keys):

| Set | en | es |
|---|---|---|
| Overclock | Charges its Overdrive first, then laser and coil never stop. | Carga su Sobremarcha primero; láser y bobina no paran. |
| Juggernaut | Heavy and slow, but one Rocket Fist ends the fight. Mines around it. | Pesado y lento, pero un Puño Cohete acaba la pelea. Minas alrededor. |
| Hornet | Never stops moving. Missiles and a rivet, a swarm to finish. | Nunca se para. Misiles y remache, un enjambre para rematar. |
| Rampart | A wall and a huge shield. Rivet from behind, plate up close. | Un muro y un escudo enorme. Remache desde atrás, placa de cerca. |
| Riposte | Blocks at the perfect moment, then cuts. Shots bend away. | Bloquea en el momento justo y luego corta. Los disparos se desvían. |
| Wraith | Lives in smoke. Sees through walls, strikes up close. | Vive en el humo. Ve a través de muros, golpea de cerca. |

Bonus text (new keys `sb_<set>` = name, `sbd_<set>` = one line) in en + es for all 18, e.g.
`sb_sniper` "Steady shot" / "Pulso firme", `sbd_sniper` "Needle Rifle +12% damage" /
"Rifle Aguja +12% de daño".

## 5. Balance

Bonuses are flavor plus a small edge: 5–15% on one stat. Never a must-have.

Check: **bot round-robin**, every set vs every other set (18 × 17), 4 seeds, sides swapped, run
twice — bonuses **off** and **on**. A headless tool `tools/set_robin.gd` prints a table per set:
win % off, win % on, change.

- Pass: no set gains more than **+8 points** from its bonus, and no set wins more than **65%**
  overall with bonuses on.
- A bonus over the line gets trimmed (halve the step) and re-run. Results go in `COMBAT_DESIGN.md`.
- Bots, not people (same caveat as the 2026-10-21 run): re-tune from playtests.

## 6. Salvage ladder and `BOSS`

With 18 sets, **every part is in some set** (checked by script: all 71 catalog parts, except the
starter Rookie Helm, which you own from the start).
So `BOSS` is no longer needed for "every part can be won".

**Recommend: delete `BOSS`.** Rematches = the same set at Mk 2/3, bonus still on. Today a rematch
swaps in a boss core, which would also break the set and turn its bonus off — confusing.

- `LADDER` grows to 18 (new sets slotted in by how hard they feel): duelist, sniper, speedster,
  hornet, assassin, glasscannon, vampire, overclock, controller, riposte, wraith, pyro, reflector,
  rampart, artillery, brawler, juggernaut, tank.
- `progress_test`: "every part can be won" now checks `SETS` alone; "rematch wears a boss core"
  becomes "rematch is the same set at Mk 2, set bonus on".
- First loop of the ladder is 18 wins instead of 12. Fine for a long mode; say if you want fewer.
- New sets are added at the **end** of `SETS`, so the first 12 keep their order. Rival pick by seed
  (`SETS.values()[s % SETS.size()]`) will shift for some seeds — look-check commands may show a
  different rival.

## 7. Touch list

| Where | Change |
|---|---|
| `godot/src/sim.gd` | 6 new `SETS`, `SET_BONUS`, `set_of(lo)`, `make_mech` applies it, `max_armor` reads row armor, `m.set` |
| `COMBAT_DESIGN.md` | New "Set bonus" section with the tables above + round-robin results |
| `godot/src/progress.gd` | `LADDER` = 18, delete `BOSS` and its swap in `rival()` |
| `godot/src/bot.gd` | Nothing: rivals already wear sets; all cores already have `wants_ult` |
| `godot/src/main.gd` | Nothing beyond the rival pick shift above |
| `godot/src/garage.gd` | SETS tab: 18 cards (3 cols × 6 rows, ~80 px; go 4 cols if cramped) and the bonus line in the hover text. MECH INFO: a "SET · Sniper — Steady shot" row when your build completes a set. Use `Sim.set_of` |
| `godot/src/hud.gd` | Small "SET · <name>" tag on your plate while the bonus is on |
| `godot/src/i18n.gd` | en + es: `set_`/`sd_` for 6 new sets, `sb_`/`sbd_` for all 18, `setTag` label |
| `godot/tests/sim_rules_test.gd` | New: each of the 18 bonuses is on with the full set (both hand orders, at Mk 2) and off with one part swapped. **`GOLDEN` changes on purpose** (the golden duel is duelist vs sniper, both now get bonuses) |
| `godot/tests/siege_rules_test.gd` | **`GOLDEN` changes on purpose** (siege run uses duelist + sniper) |
| `godot/tests/progress_test.gd` | Ladder/boss checks as in §6 |
| `godot/tests/garage_parts_test.gd` | Runs as is; check the 18-card grid fits |
| `tools/set_robin.gd` | Balance tool (§5) |
| `CLAUDE.md` | Sets bullet: 18 sets, the rule, `SET_BONUS`, Salvage without `BOSS` |
| `production/qa/evidence/` | Garage SETS tab (en + es) and MECH INFO with a completed set |

## Open questions for Victor

1. Full set only (recommended) — or do you want a 4-piece half bonus too?
2. Delete `BOSS` so rematches keep their set bonus (recommended) — or keep boss swaps?
