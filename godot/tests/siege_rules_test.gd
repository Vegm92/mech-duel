extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const Siege = preload("res://src/siege.gd")
const S = preload("res://src/siege_state.gd")

const GOLDEN := 907870899

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
	park(s, -20, 20)
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
	park(s, -20, 20)
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
	park(s, -20, 20)
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
	park(s, -20, 20)
	s.mechs[0].armor.head = 0
	steps(s, 2)
	var down: bool = s.mechs[0].ko
	steps(s, Siege.RUN.respawn + 2)
	var m: Dictionary = s.mechs[0]
	return ensure(down, "the player went down") or ensure(not m.ko and m.armor.head == m.max.head, "back up with full armor") or ensure(Sim.hypot(m.x, m.y) < 8, "at the core")
