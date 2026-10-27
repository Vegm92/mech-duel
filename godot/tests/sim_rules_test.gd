extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")

const GOLDEN := 610374086

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
