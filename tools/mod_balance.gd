extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")


func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return fallback


func _init() -> void:
	var n := arg("n", "6").to_int()
	var only := arg("only", "")
	var lines := ["part|variant|Mk2 vs plain|Mk3 vs plain|Mk3 vs other variant|unfinished"]
	var keys: Array = Sim.MODS.keys()
	for key in keys:
		if only != "" and not only.split(",").has(key):
			continue
		for v in ["a", "b"]:
			var o := "b" if v == "a" else "a"
			var mk2 := score(key, v, 2, "", 2, n)
			var mk3 := score(key, v, 3, "", 3, n)
			var mirror := score(key, v, 3, o, 3, n)
			lines.append("%s|%s|%s|%s|%s|%d" % [key, v, pct(mk2), pct(mk3), pct(mirror), mk2.open + mk3.open + mirror.open])
	print("\n".join(lines))
	quit()


func pct(r: Dictionary) -> String:
	return "%d%%" % roundi(100.0 * r.wins / maxi(1, r.games))


func build(key: String, v: String, lv: int) -> Dictionary:
	var slot := "head" if Sim.HEADS.has(key) else ("right" if Sim.WEAPONS[key].kind == "melee" else "left")
	var lo := Sim.DEFAULT_LOADOUT.merged({slot: key, "lv": {slot: lv}}, true)
	if v != "":
		lo.mod = {slot: v}
	return lo


func score(key: String, v: String, lv: int, rival_v: String, rival_lv: int, n: int) -> Dictionary:
	var wins := 0.0
	var open := 0
	for seed in n:
		var mine_first := seed % 2 == 0
		var mine := build(key, v, lv)
		var theirs := build(key, rival_v, rival_lv)
		var s := Sim.create_state([mine, theirs] if mine_first else [theirs, mine], Sim.FORMATS["1v1"])
		var brains := [Bot.create_brain(seed * 2 + 1), Bot.create_brain(seed * 2 + 2)]
		var i := 0
		while s.phase != "over" and i < 40000:
			Sim.step(s, [Bot.bot_input(s, brains[0], 0), Bot.bot_input(s, brains[1], 1)])
			i += 1
		if s.phase != "over":
			open += 1
			wins += 0.5
		elif s.winner == (0 if mine_first else 1):
			wins += 1.0
		elif s.winner < 0:
			wins += 0.5
	return {"wins": wins, "games": n, "open": open}
