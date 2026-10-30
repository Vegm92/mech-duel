extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")


func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return fallback


func _init() -> void:
	var seeds := Array(arg("seeds", "1,2").split(",")).map(func(t): return t.to_int())
	var keys: Array = Sim.SETS.keys()
	var won := {"off": {}, "on": {}}
	var played := {"off": {}, "on": {}}
	for k in keys:
		for mode in won:
			won[mode][k] = 0
			played[mode][k] = 0
	var shard := arg("shard", "0/1").split("/")
	var only := arg("only", "")
	var n := -1
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			n += 1
			if n % shard[1].to_int() != shard[0].to_int() or (only != "" and not only.split(",").has(keys[i]) and not only.split(",").has(keys[j])):
				continue
			for seed in seeds:
				for side in [[keys[i], keys[j]], [keys[j], keys[i]]]:
					for mode in ["off", "on"]:
						var score := duel(side, seed, mode == "on")
						won[mode][side[0]] += score[0]
						won[mode][side[1]] += score[1]
						for k in side:
							played[mode][k] += score[0] + score[1]
	for k in keys:
		print("RAW %s %d %d %d %d" % [k, won.off[k], played.off[k], won.on[k], played.on[k]])
	print("SET          OFF%   ON%   CHANGE")
	for k in keys:
		var off: float = 100.0 * won.off[k] / maxf(1, played.off[k])
		var on: float = 100.0 * won.on[k] / maxf(1, played.on[k])
		print("ROBIN %-12s %5.1f %5.1f %+6.1f" % [k, off, on, on - off])
	quit()


func strip(m: Dictionary) -> void:
	m.erase("set")
	m.erase("rows")
	var k: float = Sim.CORES[m.loadout.core].get("armor", 1)
	m.max = {"head": Sim.jround(Sim.HEADS[m.loadout.head].armor * k), "rarm": Sim.jround(Sim.ARMS[m.loadout.arms].armor * k), "larm": Sim.jround(Sim.ARMS[m.loadout.arms].armor * k), "legs": Sim.jround(Sim.LEG_PARTS[m.loadout.legs].armor * k)}
	m.armor = m.max.duplicate()


func duel(pair: Array, seed: int, on: bool) -> Array:
	var s := Sim.create_state([Sim.SETS[pair[0]], Sim.SETS[pair[1]]], Sim.FORMATS["1v1"])
	var brains := [Bot.create_brain(seed), Bot.create_brain(seed + 1)]
	var i := 0
	while s.phase != "over" and i < 40000:
		if not on:
			for m in s.mechs:
				if m.has("set"):
					strip(m)
		Sim.step(s, [Bot.bot_input(s, brains[0], 0), Bot.bot_input(s, brains[1], 1)])
		i += 1
	return [s.score[0], s.score[1]]
