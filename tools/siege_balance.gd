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
	var skill := arg("skill", "")
	var modes: Array = ["on", "off"] if arg("director", "on") == "both" else [arg("director", "on")]
	var rows := arg("rows", "0") == "1"
	for mode in modes:
		for seed_text in arg("seeds", "3").split(","):
			run(seed_text.to_int(), from, waves, team, tier, guard, skill, mode == "on", rows)
	quit()


func run(seed: int, from: int, waves: int, team: int, tier: int, guard: int, skill: String, on: bool, rows: bool) -> void:
	var los := []
	for i in team:
		los.append(Sim.DEFAULT_LOADOUT)
	var s := Siege.create(los, seed)
	s.siege.director.on = on
	var brains := []
	for i in team:
		brains.append(Bot.create_brain(seed * 10 + i))
		if skill != "":
			brains[i].merge(Bot.SKILL[skill], true)
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
	var per := {}
	var was := []
	for i in team:
		was.append(false)
	for k in 60 * 60 * 3 * waves:
		var ins := []
		for i in team:
			ins.append(Siege.ally_input(s, brains[i], i))
		Siege.step(s, ins)
		var n: int = s.siege.wave.n
		var c: float = s.siege.core.hp / float(s.siege.core.max)
		low = minf(low, c)
		if not per.has(n):
			per[n] = {"core": 1.0, "kos": 0}
		per[n].core = minf(per[n].core, c)
		for i in team:
			if s.mechs[i].ko and not was[i]:
				per[n].kos += 1
			was[i] = s.mechs[i].ko
		if s.phase == "over" or s.siege.wave.n >= from + waves:
			break
	var held: int = s.siege.wave.n - from + (0 if s.phase == "over" else 1)
	var dr: Dictionary = s.siege.director
	var fun := 0
	var counted := 0
	var psum := 0.0
	for n in dr.log:
		var r: Dictionary = dr.log[n]
		if r.has("P") and n >= 4:
			counted += 1
			psum += r.P
			if r.P >= 30.0 and r.P <= 80.0:
				fun += 1
		if rows:
			print("WAVE %s n %d beat %s target %d P %.1f W %.1f S %.1f D %.2f tactic %s budget %.1f core %d%% kos %d" % ["on" if on else "off", n, r.get("beat", "-"), r.get("target", 0), r.get("P", -1.0), r.get("W", -1.0), r.get("S", -1.0), r.get("D", 0.0), r.get("tactic", "-"), r.get("budget", 0.0), int(per.get(n, {"core": 0.0}).core * 100), per.get(n, {"kos": 0}).kos])
	print("BALANCE director %s skill %s seed %d from %d tiers %d team %d guard %d -> %s at wave %d, held %d, avg P(4+) %.1f, fun %d/%d, dial %.2f, game time %d s, kills %d, core low %d%%, %d s" % ["on" if on else "off", skill if skill != "" else "default", seed, from, tier, team, guard, "LOST" if s.phase == "over" else "ALIVE", s.siege.wave.n, held, psum / maxf(1, counted), fun, counted, dr.dial, (s.tick - tick0) / 60, s.siege.kills, int(low * 100), (Time.get_ticks_msec() - t0) / 1000])
