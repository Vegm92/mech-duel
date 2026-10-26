extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")

const GOLDEN := 610374086
const TOL := 1e-9
const IGNORED := ["fx0", "fy0", "seen"]

var failed := 0
var filter := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--filter")
	if at >= 0 and at + 1 < args.size():
		filter = args[at + 1]
	run("bot_duel_matches_golden_hash", test_bot_duel_matches_golden_hash)
	run("same_seed_gives_same_hash", test_same_seed_gives_same_hash)
	run("ffa_bot_match_ends_with_a_winner", test_ffa_bot_match_ends_with_a_winner)
	run("every_step_matches_js", test_every_step_matches_js)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	if filter != "" and not name.contains(filter):
		print("test skipped: " + name)
		return
	var t0 := Time.get_ticks_msec()
	var r: int = test.call()
	if r == 2:
		print("test skipped: %s" % name)
	elif r == 1:
		failed += 1
		print("test failed: %s" % name)
	else:
		print("test passed: %s (%d ms)" % [name, Time.get_ticks_msec() - t0])


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
		return 1
	return 0


func bot_match(loadouts: Array, teams: Array, seed: int) -> Dictionary:
	var s := Sim.create_state(loadouts, teams)
	var brains := []
	for m in s.mechs:
		brains.append(Bot.create_brain(seed + m.id))
	var trail := ""
	var i := 0
	while s.phase != "over" and i < 40000:
		var ins := []
		for m in s.mechs:
			ins.append(Bot.bot_input(s, brains[m.id], m.id))
		Sim.step(s, ins)
		if i % 60 == 0:
			trail += str(Sim.hash_state(s))
		i += 1
	return {"state": s, "hash": trail.hash(), "ticks": i}


func test_bot_duel_matches_golden_hash() -> int:
	var h: int = bot_match([Sim.SETS.duelist, Sim.SETS.sniper], Sim.FORMATS["1v1"], 101).hash
	if h != GOLDEN:
		print("  golden hash is %d" % h)
	return ensure(h == GOLDEN, "hash == GOLDEN")


func test_same_seed_gives_same_hash() -> int:
	var lo := [Sim.SETS.brawler, Sim.SETS.artillery]
	var a: int = bot_match(lo, Sim.FORMATS["1v1"], 7).hash
	var b: int = bot_match(lo, Sim.FORMATS["1v1"], 7).hash
	return ensure(a == b, "same seed, same hash")


func test_ffa_bot_match_ends_with_a_winner() -> int:
	var teams: Array = Sim.FORMATS["ffa"]
	var lo := []
	for i in teams.size():
		lo.append(Bot.random_loadout(Bot.create_brain(40 + i)))
	var r := bot_match(lo, teams, 400)
	var s: Dictionary = r.state
	return ensure(s.phase == "over", "phase == over after %d ticks" % r.ticks) or ensure(s.score.max() == Sim.MATCH.wins, "a team won %d rounds" % Sim.MATCH.wins)


func fix(v):
	if v is float and v == floor(v) and absf(v) < 9007199254740992.0:
		return int(v)
	if v is String and v.length() == 17 and v.begins_with("~"):
		var b := PackedByteArray()
		b.resize(8)
		b.encode_u32(4, v.substr(1, 8).hex_to_int())
		b.encode_u32(0, v.substr(9, 8).hex_to_int())
		return b.decode_double(0)
	if v is Array:
		var out := []
		for x in v:
			out.append(fix(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = fix(v[k])
		return out
	return v


func relink_trails(state: Dictionary) -> void:
	for m in state.mechs:
		if m.act == null or m.act.get("trail") == null:
			continue
		var want = m.act.trail
		for tr in state.trails:
			if tr.owner == want.owner and tr.x1 == want.x1 and tr.y1 == want.y1 and tr.t == want.t:
				m.act.trail = tr
				break


func diff(a, b, path: String) -> String:
	var na := a is int or a is float
	var nb := b is int or b is float
	if na and nb:
		var x := float(a)
		var y := float(b)
		if absf(x - y) <= TOL * maxf(1.0, maxf(absf(x), absf(y))):
			return ""
		return "%s: godot %s vs js %s" % [path, String.num(x, 15), String.num(y, 15)]
	if a is Dictionary and b is Dictionary:
		for k in b:
			if not a.has(k):
				return "%s.%s missing in godot" % [path, k]
		for k in a:
			if not b.has(k) and not IGNORED.has(k):
				return "%s.%s only in godot (%s)" % [path, k, a[k]]
		for k in b:
			var d := diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "":
				return d
		return ""
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s: godot has %d items, js %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	if typeof(a) != typeof(b) or a != b:
		return "%s: godot %s vs js %s" % [path, a, b]
	return ""


func test_every_step_matches_js() -> int:
	var out := []
	var script := ProjectSettings.globalize_path("res://tests/js_steps.mjs")
	var code := OS.execute("node", [script], out, true)
	if code != 0 or out.is_empty():
		print("  node not available or failed (%d): %s" % [code, out])
		return 2
	var lines: PackedStringArray = out[0].split("\n", false)
	var bad := 0
	var bot_bad := 0
	for line in lines:
		var row = fix(JSON.parse_string(line))
		if row.has("init"):
			var made := diff(Sim.create_state(row.loadouts, row.teams), row.init, "init")
			if made != "":
				bad += 1
				print("  case %d: %s" % [row.case, made])
			continue
		var state: Dictionary = row.before.state
		relink_trails(state)
		var where := "case %d tick %d" % [row.case, row.tick]
		for i in state.mechs.size():
			var got := Bot.bot_input(state, row.before.brains[i], i)
			var d := diff(got, row.inputs[i], "inputs[%d]" % i)
			if d != "":
				bot_bad += 1
				if bot_bad <= 5:
					print("  bot  %s: %s" % [where, d])
		Sim.step(state, row.inputs)
		var d := diff(state, row.after, "state")
		if d != "":
			bad += 1
			if bad <= 8:
				print("  step %s: %s" % [where, d])
	print("  %d samples, %d step mismatches, %d bot mismatches" % [lines.size(), bad, bot_bad])
	return ensure(lines.size() > 500, "enough samples") or ensure(bad == 0, "every step matches js") or ensure(bot_bad == 0, "every bot input matches js")
