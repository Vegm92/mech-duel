extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const Killcam = preload("res://src/killcam.gd")

const DUELS := [["speedster", "sniper", 21], ["artillery", "brawler", 22], ["duelist", "tank", 23]]

var failed := 0
var filter := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--filter")
	if at >= 0 and at + 1 < args.size():
		filter = args[at + 1]
	await run("replay_lands_on_the_same_ko", test_replay_lands_on_the_same_ko)
	await run("one_smooth_move_slows_down_at_the_ko", test_one_smooth_move_slows_down_at_the_ko)
	await run("pillar_blocks_a_low_camera_not_a_high_one", test_pillar_blocks_a_low_camera_not_a_high_one)
	await run("a_ko_in_a_match_plays_the_replay_then_the_next_round", test_a_ko_in_a_match_plays_the_replay_then_the_next_round)
	await run("enter_skips_the_replay", test_enter_skips_the_replay)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	if filter != "" and not name.contains(filter):
		print("test skipped: " + name)
		return
	var t0 := Time.get_ticks_msec()
	var r = await test.call()
	if not (r is int and r == 0):
		failed += 1
		print("test failed: %s" % name)
	else:
		print("test passed: %s (%d ms)" % [name, Time.get_ticks_msec() - t0])


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
		return 1
	return 0


func ko_round(duel: Array) -> Dictionary:
	var s := Sim.create_state([Sim.SETS[duel[0]], Sim.SETS[duel[1]]])
	var brains := [Bot.create_brain(duel[2]), Bot.create_brain(duel[2] + 1)]
	var rec := Killcam.recorder()
	var ko := {}
	var most := 0
	var i := 0
	while not Killcam.wants(s, rec) and s.phase != "over" and i < 40000:
		var ins := [Bot.bot_input(s, brains[0], 0), Bot.bot_input(s, brains[1], 1)]
		Killcam.record(rec, s, ins)
		Sim.step(s, ins)
		most = maxi(most, rec.ins.size())
		if s.phase == "ko" and ko.is_empty():
			ko = s.duplicate(true)
		elif s.phase == "countdown":
			ko = {}
		i += 1
	return {"state": s, "rec": rec, "ko": ko, "most": most}


func same(a: Dictionary, b: Dictionary) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.erase("fx")
	y.erase("fx")
	return JSON.stringify(x, "", true, true) == JSON.stringify(y, "", true, true)


func test_replay_lands_on_the_same_ko() -> int:
	for duel in DUELS:
		var r := ko_round(duel)
		var name := "%s vs %s" % [duel[0], duel[1]]
		if ensure(Killcam.wants(r.state, r.rec), name + ": a round ends in a K.O."):
			return 1
		var ko: Dictionary = r.ko
		var p := Killcam.start(r.rec, r.state)
		if ensure(r.most <= Killcam.lag(), name + ": keeps at most lag() inputs") or ensure(p.ko == ko.tick, name + ": knows the K.O. tick") or ensure(p.victim == ko.finalKo, name + ": films the last K.O."):
			return 1
		while p.i < p.ins.size():
			Killcam.advance(p)
		if ensure(same(p.state, ko), name + ": the re-run matches the live state at the K.O. (tick %d)" % ko.tick):
			return 1
	return 0


func test_one_smooth_move_slows_down_at_the_ko() -> int:
	var r := ko_round(DUELS[0])
	var p := Killcam.start(r.rec, r.state)
	var first := Killcam.speed_at(-p.ins.size())
	var at_ko := 1.0
	var last := Vector3.ZERO
	var jump := 0.0
	var bad := 0
	while not Killcam.done(p):
		var k := Killcam.spot_of(p.state.mechs[p.killer])
		var v := Killcam.spot_of(p.state.mechs[p.victim])
		var f := Killcam.film(p, k, v, 1.0 / Sim.TICKS)
		if p.i > 0:
			jump = maxf(jump, f.eye.distance_to(last))
		last = f.eye
		if p.state.tick == p.ko:
			at_ko = f.speed
		var c := Sim.clamp_arena(f.eye.x, f.eye.z, 0.5)
		var ok: bool = f.eye.is_finite() and is_equal_approx(c.x, f.eye.x) and is_equal_approx(c.y, f.eye.z) and f.fov > 10.0 and f.fov < 90.0
		if bad == 0 and not ok:
			bad = ensure(false, "tick %d: camera %s inside the arena, fov %.1f" % [p.state.tick, f.eye, f.fov])
		Killcam.advance(p)
	return bad or ensure(jump < 1.0, "the camera never jumps (largest step %.2f m)" % jump) or ensure(first == 1.0 and at_ko < 0.3, "normal speed at the start (%.2f), slow motion at the K.O. (%.2f)" % [first, at_ko])


func test_pillar_blocks_a_low_camera_not_a_high_one() -> int:
	var p: Dictionary = Sim.PILLARS[0]
	var mech := Vector3(p.x, 0, p.y + 4.0)
	var behind := Vector3(p.x, 2.0, p.y - 6.0)
	var high := Vector3(p.x, 15.0, p.y - 6.0)
	var side := Vector3(p.x + 4.0, 2.0, p.y + 4.0)
	return ensure(Killcam.blocked(behind, mech), "a low camera behind the pillar is blocked") or ensure(not Killcam.blocked(high, mech), "a high camera sees over it") or ensure(not Killcam.blocked(side, mech), "a camera off to the side is clear")


func match_to_replay(seed: int):
	var m = load("res://main.tscn").instantiate()
	m.autopilot = true
	m.seed_arg = seed
	root.add_child(m)
	await process_frame
	for i in 20000:
		if not m.replay.is_empty():
			break
		m._physics_process(1.0 / Sim.TICKS)
	return m


func frame(m) -> void:
	m._process(Engine.time_scale / Sim.TICKS)
	m._physics_process(Engine.time_scale / Sim.TICKS)


func test_a_ko_in_a_match_plays_the_replay_then_the_next_round() -> int:
	var m = await match_to_replay(1)
	var started: bool = not m.replay.is_empty()
	var round: int = m.replay.live.round if started else -1
	var bars: bool = started and m.hud.replay >= 0.0
	var slow := false
	for i in 4000:
		if m.replay.is_empty():
			break
		frame(m)
		slow = slow or Engine.physics_ticks_per_second < Sim.TICKS
	var next: bool = m.state.phase == "over" or (m.state.phase == "countdown" and m.state.round == round + 1)
	var bad := ensure(started, "a K.O. starts the replay") or ensure(bars, "the replay bars show") or ensure(slow, "the K.O. plays in slow motion") 		or ensure(m.replay.is_empty() and next, "then the next round starts (phase %s, round %d)" % [m.state.phase, m.state.round]) 		or ensure(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == Sim.TICKS and m.hud.replay < 0.0, "speed and HUD back to normal")
	m.queue_free()
	return bad


func test_enter_skips_the_replay() -> int:
	var m = await match_to_replay(1)
	var round: int = m.replay.live.round
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	m._input(enter)
	var early: bool = not m.replay.is_empty()
	for i in 600:
		if m.replay.i >= Killcam.KILLCAM.grace:
			break
		frame(m)
	m._input(enter)
	var bad := ensure(early, "an early Enter (mashing) does not skip") or ensure(m.replay.is_empty(), "Enter ends the replay") or ensure(m.state.phase == "over" or m.state.round == round + 1, "and goes on to the next round") 		or ensure(Engine.physics_ticks_per_second == Sim.TICKS, "at normal speed")
	m.queue_free()
	return bad
