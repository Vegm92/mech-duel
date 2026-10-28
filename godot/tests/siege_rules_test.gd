extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const Siege = preload("res://src/siege.gd")
const S = preload("res://src/siege_state.gd")

const GOLDEN := 568555732

var failed := 0
var filter := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--filter")
	if at >= 0 and at + 1 < args.size():
		filter = args[at + 1]
	run("siege_run_matches_golden_hash", test_siege_run_matches_golden_hash)
	run("same_seed_gives_same_siege_hash", test_same_seed_gives_same_siege_hash)
	run("first_wave_warns_eight_seconds_ahead_then_spawns_scouts", test_first_wave_warns_eight_seconds_ahead_then_spawns_scouts)
	run("scout_walks_its_lane_and_shoots_the_gate", test_scout_walks_its_lane_and_shoots_the_gate)
	run("gate_stops_bots_but_lets_players_through", test_gate_stops_bots_but_lets_players_through)
	run("scouts_break_the_gate_and_reach_the_core", test_scouts_break_the_gate_and_reach_the_core)
	run("player_shot_kills_a_scout_and_drops_scrap", test_player_shot_kills_a_scout_and_drops_scrap)
	run("player_shots_pass_over_the_core", test_player_shots_pass_over_the_core)
	run("rings_break_in_order_and_core_at_zero_loses", test_rings_break_in_order_and_core_at_zero_loses)
	run("repair_stops_at_the_lowest_intact_ring", test_repair_stops_at_the_lowest_intact_ring)
	run("downed_player_respawns_at_the_core", test_downed_player_respawns_at_the_core)
	run("swarm_cube_blows_up_on_the_gate_without_scrap", test_swarm_cube_blows_up_on_the_gate_without_scrap)
	run("spider_pops_out_of_a_vent_and_bites_a_player", test_spider_pops_out_of_a_vent_and_bites_a_player)
	run("flyer_crosses_the_wall_to_the_core", test_flyer_crosses_the_wall_to_the_core)
	run("blades_miss_a_flyer_but_bolts_hit_it", test_blades_miss_a_flyer_but_bolts_hit_it)
	run("turret_plants_shoots_the_gate_and_takes_half_damage", test_turret_plants_shoots_the_gate_and_takes_half_damage)
	run("walker_claws_the_gate", test_walker_claws_the_gate)
	run("tripod_aims_two_seconds_before_the_rail_hits", test_tripod_aims_two_seconds_before_the_rail_hits)
	run("stepping_aside_after_the_tripod_locks_dodges_the_rail", test_stepping_aside_after_the_tripod_locks_dodges_the_rail)
	run("quad_heavy_shells_the_core_from_beyond_the_wall", test_quad_heavy_shells_the_core_from_beyond_the_wall)
	run("heavy_cannon_splashes_a_player_and_shrugs_off_a_rivet", test_heavy_cannon_splashes_a_player_and_shrugs_off_a_rivet)
	run("juggernaut_is_untouchable_rolling_and_open_after_a_ram", test_juggernaut_is_untouchable_rolling_and_open_after_a_ram)
	run("juggernaut_hits_a_gate_three_times_as_hard", test_juggernaut_hits_a_gate_three_times_as_hard)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	if filter != "" and not name.contains(filter):
		print("test skipped: " + name)
		return
	var t0 := Time.get_ticks_msec()
	var r = test.call()
	if typeof(r) != TYPE_INT or r != 0:
		failed += 1
		print("test failed: %s" % name)
	else:
		print("test passed: %s (%d ms)" % [name, Time.get_ticks_msec() - t0])


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
		return 1
	return 0


func idle(at := Vector2.ZERO) -> Dictionary:
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.ax = at.x
	inp.ay = at.y
	return inp


func park(s: Dictionary, x: float, y: float) -> void:
	var m: Dictionary = s.mechs[0]
	m.x = x
	m.y = y


func steps(s: Dictionary, n: int, inp := {}) -> void:
	for i in n:
		Siege.step(s, [inp if not inp.is_empty() else idle()])


func bot_run(seed: int, ticks: int) -> Dictionary:
	var s := Siege.create([Sim.SETS.duelist, Sim.SETS.sniper], seed)
	var brains := [Bot.create_brain(seed), Bot.create_brain(seed + 1)]
	var trail := ""
	for i in ticks:
		Siege.step(s, [Siege.ally_input(s, brains[0], 0), Siege.ally_input(s, brains[1], 1)])
		if i % 60 == 0:
			trail += str(Sim.hash_state(s))
	return {"state": s, "hash": trail.hash()}


func test_siege_run_matches_golden_hash() -> int:
	var r := bot_run(11, 3600)
	var h: int = r.hash
	if h != GOLDEN:
		print("  golden hash is %d (wave %d, core %d, scrap %d)" % [h, r.state.siege.wave.n, r.state.siege.core.hp, r.state.siege.scrap])
	return ensure(h == GOLDEN, "hash == GOLDEN") or ensure(r.state.siege.scrap > 0, "the bots killed something")


func test_same_seed_gives_same_siege_hash() -> int:
	return ensure(bot_run(5, 1800).hash == bot_run(5, 1800).hash, "same seed, same hash")


func test_first_wave_warns_eight_seconds_ahead_then_spawns_scouts() -> int:
	var s := Siege.create([{}], 3)
	park(s, -15, 15)
	var warned := -1
	for i in Siege.RUN.first - 1:
		Siege.step(s, [idle()])
		for f in s.fx:
			if f.k == "warn" and warned < 0:
				warned = s.tick
	var n: int = s.siege.enemies.size()
	steps(s, 1)
	return ensure(warned == Siege.RUN.first - Siege.RUN.warn, "warning at tick %d" % warned) or ensure(n == 0, "nobody before the wave") or ensure(s.siege.enemies.size() > 0 and s.siege.enemies[0].kind == "scout", "a scout spawns") or ensure(s.siege.wave.n == 1, "wave 1")


func test_scout_walks_its_lane_and_shoots_the_gate() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	park(s, -15, 15)
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var y0: float = e.y
	steps(s, 60 * 12)
	var g: Dictionary = s.siege.gates[0]
	return ensure(y0 < -70, "spawned at the north border") or ensure(e.y > -32 and e.y < -20, "stopped in front of the gate at %.1f" % e.y) or ensure(g.hp < g.max, "the gate took damage")


func test_gate_stops_bots_but_lets_players_through() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	b.x = 0.0
	b.y = -20.0
	park(s, 0, -10)
	var walk := idle()
	walk.my = -1.0
	for i in 120:
		b.x = 0.0
		Sim.move(s, b, {"mx": 0.0, "my": 1.0})
		Siege.step(s, [walk])
	var me: Dictionary = s.mechs[0]
	return ensure(b.y < -S.RING_OUT, "the scout is held outside at %.1f" % b.y) or ensure(me.y < -S.RING_OUT - 1, "the player walked out to %.1f" % me.y)


func test_scouts_break_the_gate_and_reach_the_core() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	park(s, -15, 15)
	s.siege.gates[0].hp = 30.0
	for i in 4:
		Siege.spawn(s, "scout", 0, (i - 1.5) * 1.5)
	steps(s, 60 * 25)
	var c: Dictionary = s.siege.core
	return ensure(s.siege.gates[0].hp == 0, "the gate broke") or ensure(c.hp < c.max, "the core took damage")


func test_player_shot_kills_a_scout_and_drops_scrap() -> int:
	var s := Siege.create([{"left": "rivet"}], 3)
	s.siege.wave.next_in = 99999
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	b.x = 0.0
	b.y = -40.0
	park(s, 0, -30)
	var inp := idle(Vector2(0, -40))
	inp.left = true
	for i in 60:
		b.x = 0.0
		b.y = -40.0
		Siege.step(s, [inp])
		inp.left = not inp.left
	return ensure(e.act == "die", "the scout died, act %s hp %d" % [e.act, e.hp]) or ensure(s.siege.scrap == Siege.BOTS.scout.cost * Siege.RUN.scrap, "scrap %d" % s.siege.scrap)


func test_player_shots_pass_over_the_core() -> int:
	var s := Siege.create([{"left": "rivet"}], 3)
	s.siege.wave.next_in = 99999
	park(s, 0, 6)
	var inp := idle(Vector2(0, -6))
	inp.left = true
	for i in 20:
		Siege.step(s, [inp])
	var far: Array = s.shots.filter(func(sh): return sh.y < -3)
	return ensure(s.siege.core.hp == s.siege.core.max, "the core is untouched") or ensure(not far.is_empty(), "the shot flew past the core")


func test_rings_break_in_order_and_core_at_zero_loses() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	var c: Dictionary = s.siege.core
	c.hp = c.max * 0.6
	steps(s, 1)
	var after_one: Array = c.rings.duplicate()
	c.hp = 0.0
	steps(s, 1)
	return ensure(c.broken == 4, "every ring broke") or ensure(after_one[0] == 0 and after_one[1] > 0, "the outer ring broke first: %s" % [after_one]) or ensure(s.siege.lost and s.phase == "over", "the run is lost")


func test_repair_stops_at_the_lowest_intact_ring() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	var c: Dictionary = s.siege.core
	c.hp = c.max * 0.6
	park(s, 0, 3.5)
	steps(s, 60 * 40)
	return ensure(c.broken == 1, "one ring broken") or ensure(is_equal_approx(c.hp, c.max * 0.75), "repaired up to 75%%, got %.0f" % c.hp)


func test_downed_player_respawns_at_the_core() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	park(s, -15, 15)
	s.mechs[0].armor.head = 0
	steps(s, 2)
	var down: bool = s.mechs[0].ko
	steps(s, Siege.RUN.respawn + 2)
	var m: Dictionary = s.mechs[0]
	return ensure(down, "the player went down") or ensure(not m.ko and m.armor.head == m.max.head, "back up with full armor") or ensure(Sim.hypot(m.x, m.y) < 8, "at the core")


func lab(lo := {}) -> Dictionary:
	var s := Siege.create([lo], 3)
	s.siege.wave.next_in = 999999
	park(s, -15, 15)
	return s


func until(s: Dictionary, most: int, done: Callable) -> int:
	for i in most:
		Siege.step(s, [idle()])
		if done.call():
			return i + 1
	return -1


func test_swarm_cube_blows_up_on_the_gate_without_scrap() -> int:
	var s := lab()
	Siege.spawn(s, "swarm", 0, 0.0)
	var cubes: int = s.siege.enemies.size()
	var g: Dictionary = s.siege.gates[0]
	var t := until(s, 60 * 20, func(): return g.hp < g.max)
	return ensure(cubes == 3, "a swarm is 3 cubes") or ensure(t > 0, "a cube reached the gate") or ensure(g.max - g.hp >= Siege.BOTS.swarm.boom.dmg, "the gate lost %d" % (g.max - g.hp)) or ensure(s.siege.scrap == 0, "blowing up gives no scrap")


func test_spider_pops_out_of_a_vent_and_bites_a_player() -> int:
	var s := lab()
	park(s, 0, -36)
	var e := Siege.spawn(s, "spider", 0, 1.0)
	var at := Vector2(e.x, e.y)
	var me: Dictionary = s.mechs[0]
	var t := until(s, 60 * 10, func(): return me.armor.legs < me.max.legs)
	return ensure(absf(at.y + S.VENTS[0]) < 2.0 and absf(at.x) > 3.0, "spawned at the vent, at %s" % at) or ensure(t > 0, "it bit the player")


func test_flyer_crosses_the_wall_to_the_core() -> int:
	var s := lab()
	var e := Siege.spawn(s, "flyer", 0, 0.0)
	var c: Dictionary = s.siege.core
	var t := until(s, 60 * 30, func(): return c.hp < c.max)
	return ensure(Sim.hypot(e.x, e.y) < S.RING_IN, "inside the fortress at %.1f" % Sim.hypot(e.x, e.y)) or ensure(t > 0, "it shot the core")


func test_blades_miss_a_flyer_but_bolts_hit_it() -> int:
	var s := lab({"left": "rivet", "right": "saw"})
	var e := Siege.spawn(s, "flyer", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	var me: Dictionary = s.mechs[0]
	b.x = me.x + 1.5
	b.y = me.y
	me.aim = 0.0
	Sim.swing(s, me, "right", false)
	var cut: float = b.armor.head
	Sim.spawn_shot(s, me, 99, me.x + 0.5, me.y, 0.0, Sim.WEAPONS.rivet, 65, 1, "bolt")
	Sim.move_shots(s)
	return ensure(cut == b.max.head, "the saw missed") or ensure(b.armor.head < b.max.head, "the bolt hit")


func test_turret_plants_shoots_the_gate_and_takes_half_damage() -> int:
	var s := lab()
	var e := Siege.spawn(s, "turret", 0, 0.0)
	var g: Dictionary = s.siege.gates[0]
	var t := until(s, 60 * 40, func(): return g.hp < g.max)
	var b: Dictionary = s.mechs[e.m]
	var was: float = b.armor.head
	Sim.env_hit(s, b, 100, "head", 0, 0.0)
	return ensure(t > 0, "it shot the gate") or ensure(e.rooted >= Siege.BOTS.turret.plant, "it planted first") or ensure(was - b.armor.head == 50, "planted, it took %d of 100" % (was - b.armor.head))


func test_walker_claws_the_gate() -> int:
	var s := lab()
	var e := Siege.spawn(s, "walker", 0, 0.0)
	var g: Dictionary = s.siege.gates[0]
	var t := until(s, 60 * 40, func(): return g.hp <= g.max - Siege.BOTS.walker.dmg)
	return ensure(t > 0, "the gate lost a claw's worth") or ensure(absf(e.y) < S.RING_OUT + 4.0, "in claw reach at %.1f" % e.y)


func rail_test(step_aside_at: int) -> Dictionary:
	var s := lab()
	park(s, 0, -50)
	Siege.spawn(s, "tripod", 0, 0.0)
	var me: Dictionary = s.mechs[0]
	var seen := -1
	var hurt := -1
	for i in 60 * 12:
		Siege.step(s, [idle()])
		me.x = 0.0 if seen < 0 or s.tick - seen < step_aside_at else 4.0
		me.y = -50.0
		for f in s.fx:
			if f.k == "sight" and seen < 0:
				seen = s.tick
		if hurt < 0 and me.armor.larm + me.armor.rarm < me.max.larm + me.max.rarm:
			hurt = s.tick
	return {"seen": seen, "hurt": hurt}


func test_tripod_aims_two_seconds_before_the_rail_hits() -> int:
	var r := rail_test(99999)
	return ensure(r.seen > 0 and r.hurt > 0, "it aimed and hit (%d, %d)" % [r.seen, r.hurt]) or ensure(r.hurt - r.seen >= Siege.BOTS.tripod.windup - 1, "warning lasted %d ticks" % (r.hurt - r.seen))


func test_stepping_aside_after_the_tripod_locks_dodges_the_rail() -> int:
	var lock: int = Siege.BOTS.tripod.windup - Siege.BOTS.tripod.lock
	var r := rail_test(lock + 5)
	return ensure(r.seen > 0, "it aimed") or ensure(r.hurt < 0 or r.hurt - r.seen > Siege.BOTS.tripod.windup + 5, "the first rail missed (hurt at +%d)" % (r.hurt - r.seen))


func test_quad_heavy_shells_the_core_from_beyond_the_wall() -> int:
	var s := lab()
	var e := Siege.spawn(s, "quadheavy", 0, 0.0)
	var c: Dictionary = s.siege.core
	var seen := {"marked": false}
	var t := until(s, 60 * 40, func():
		for l in s.lobs:
			if l.T == Siege.BOTS.quadheavy.delay:
				seen.marked = true
		return c.hp < c.max)
	return ensure(t > 0, "shells hit the core") or ensure(seen.marked, "landing spots were marked") or ensure(absf(e.y) > S.RING_OUT + 3.0, "it stayed outside at %.1f" % e.y)


func test_heavy_cannon_splashes_a_player_and_shrugs_off_a_rivet() -> int:
	var s := lab()
	park(s, 0, -45)
	var e := Siege.spawn(s, "heavy", 0, 0.0)
	var me: Dictionary = s.mechs[0]
	var t := until(s, 60 * 30, func(): return me.armor.legs < me.max.legs)
	var b: Dictionary = s.mechs[e.m]
	Sim.hit(s, me, b, 65, "ARMS", Sim.WEAPONS.rivet.impact, 0.0, 77)
	return ensure(t > 0, "the cannon hit the player") or ensure(me.max.legs - me.armor.legs >= Siege.BOTS.heavy.dmg, "splash did %d" % (me.max.legs - me.armor.legs)) or ensure(b.stagger == 0, "a rivet does not stagger it")


func test_juggernaut_is_untouchable_rolling_and_open_after_a_ram() -> int:
	var s := lab()
	park(s, 0, -40)
	var e := Siege.spawn(s, "jugg", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	var me: Dictionary = s.mechs[0]
	Siege.step(s, [idle()])
	Sim.hit(s, me, b, 200, "ARMS", 1, 0.0, 70)
	var rolling: float = b.armor.head
	var whole := Sim.total_armor(me)
	var t := until(s, 60 * 10, func(): return e.mode == "open")
	steps(s, 30)
	Sim.hit(s, me, b, 200, "ARMS", 1, 0.0, 71)
	return ensure(rolling == b.max.head, "no damage while rolling") or ensure(t > 0, "it rammed and opened") or ensure(Sim.total_armor(me) < whole, "the player was hit") or ensure(absf(me.y + 40.0) > 2.0, "the player was pushed to %.1f" % me.y) or ensure(b.armor.head < b.max.head, "open, it takes damage")


func test_juggernaut_hits_a_gate_three_times_as_hard() -> int:
	var s := lab()
	Siege.spawn(s, "jugg", 0, 0.0)
	var g: Dictionary = s.siege.gates[0]
	var t := until(s, 60 * 15, func(): return g.hp < g.max)
	return ensure(t > 0, "it hit the gate") or ensure(g.max - g.hp == Siege.BOTS.jugg.dmg * Siege.BOTS.jugg.gateK, "gate lost %d" % (g.max - g.hp))
