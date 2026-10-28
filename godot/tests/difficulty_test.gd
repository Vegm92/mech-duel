extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")

const SEEDS := [11, 22, 33, 44, 55, 66, 77, 88]
const SETS := ["duelist", "sniper", "brawler", "tank", "speedster", "artillery", "pyro", "vampire"]


func _initialize() -> void:
	var rows := {"old bot": duel_stats({})}
	for level in Bot.LEVELS:
		rows[level] = duel_stats(Bot.LEVELS[level])
	for k in rows:
		var r: Dictionary = rows[k]
		print("%-8s rival won %2d of %2d rounds   damage trade %.2f   hits per shot %.2f" % [k, r.won, r.rounds, r.trade, r.hit])
	var bad := 0
	bad += ensure(rows.easy.won < rows.normal.won and rows.normal.won < rows.hard.won, "rounds won rise easy < normal < hard")
	bad += ensure(rows.easy.trade < rows.normal.trade and rows.normal.trade < rows.hard.trade, "damage trade rises easy < normal < hard")
	bad += ensure(rows.easy.hit < rows.hard.hit, "easy lands fewer hits per shot than hard")
	bad += ensure(rows.normal.trade < rows["old bot"].trade and rows["old bot"].trade < rows.hard.trade, "normal is gentler than the old bot, hard is tougher")
	bad += ensure(rows.hard.won > rows["old bot"].won, "hard wins more rounds than the old bot")
	print("FAILED" if bad else "ALL PASSED")
	quit(1 if bad else 0)


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
	return int(not cond)


## Mirror matches: the player stand-in is the plain default bot with the same set; only the rival's level changes.
func duel_stats(level: Dictionary) -> Dictionary:
	var won := 0
	var rounds := 0
	var dealt := 0.0
	var taken := 0.0
	var shots := 0
	var hits := 0
	for i in SEEDS.size():
		var s := Sim.create_state([Sim.SETS[SETS[i]], Sim.SETS[SETS[i]]])
		var me := Bot.create_brain(SEEDS[i])
		var rival := Bot.create_brain(SEEDS[i] + 1)
		rival.merge(level, true)
		var last := [armor(s.mechs[0]), armor(s.mechs[1])]
		var t := 0
		while s.phase != "over" and t < 40000:
			Sim.step(s, [Bot.bot_input(s, me, 0), Bot.bot_input(s, rival, 1)])
			var now := [armor(s.mechs[0]), armor(s.mechs[1])]
			if s.phase == "fight" or s.phase == "ko":
				dealt += maxf(0.0, last[0] - now[0])
				taken += maxf(0.0, last[1] - now[1])
			last = now
			for f in s.fx:
				if f.has("seen"):
					continue
				f.seen = true
				if f.k == "muzzle" and f.id == 1:
					shots += 1
				elif f.k == "hit" and f.id == 0:
					hits += 1
			t += 1
		won += s.score[1]
		rounds += s.score[0] + s.score[1]
	return {"won": won, "rounds": rounds, "trade": dealt / maxf(1.0, taken), "hit": hits / float(maxi(1, shots))}


func armor(m) -> float:
	var a := 0.0
	for p in m.armor:
		a += maxf(0.0, m.armor[p])
	return a
