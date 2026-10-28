extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const Siege = preload("res://src/siege.gd")
const S = preload("res://src/siege_state.gd")


func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return fallback


func _init() -> void:
	var from := arg("from", "1").to_int()
	var waves := arg("waves", "10").to_int()
	var team := arg("team", "2").to_int()
	var tier := arg("tiers", "0").to_int()
	var guard := arg("guard", "0").to_int()
	for seed_text in arg("seeds", "3").split(","):
		var seed := seed_text.to_int()
		var los := []
		for i in team:
			los.append(Sim.DEFAULT_LOADOUT)
		var s := Siege.create(los, seed)
		var brains := []
		for i in team:
			brains.append(Bot.create_brain(seed * 10 + i))
			for slot in S.PART_SLOTS:
				s.siege.tiers[i][slot] = tier
			Siege.outfit(s.mechs[i], s.siege.tiers[i], 0)
			s.mechs[i].armor = s.mechs[i].max.duplicate()
		for t in guard:
			s.siege.fund += Siege.GARRISON.cost[t]
			Siege.buy(s, s.siege, "garrison", s.mechs[0])
		s.siege.wave.n = from - 1
		var low := 1.0
		var t0 := Time.get_ticks_msec()
		var tick0: int = s.tick
		var cap := 60 * 60 * 3 * waves
		for k in cap:
			var ins := []
			for i in team:
				ins.append(Siege.ally_input(s, brains[i], i))
			Siege.step(s, ins)
			low = minf(low, s.siege.core.hp / float(s.siege.core.max))
			if s.phase == "over" or s.siege.wave.n >= from + waves:
				break
		var held: int = s.siege.wave.n - from + (0 if s.phase == "over" else 1)
		var tiers_now := []
		for i in team:
			var sum := 0
			for slot in S.PART_SLOTS:
				sum += s.siege.tiers[i][slot]
			tiers_now.append(sum)
		print("BALANCE seed %d from %d tiers %d team %d guard %d -> %s at wave %d, held %d, game time %d s, kills %d, core low %d%%, tier points %s, %d s" % [seed, from, tier, team, guard, "LOST" if s.phase == "over" else "ALIVE", s.siege.wave.n, held, (s.tick - tick0) / 60, s.siege.kills, int(low * 100), tiers_now, (Time.get_ticks_msec() - t0) / 1000])
	quit()
