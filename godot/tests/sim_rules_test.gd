extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")

const GOLDEN := 2143532238

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
	run("default_head_has_no_e_skill", test_default_head_has_no_e_skill)
	run("head_without_e_skill_never_throws_a_hook", test_head_without_e_skill_never_throws_a_hook)
	run("head_with_hook_throws_a_hook", test_head_with_hook_throws_a_hook)
	run("brace_halves_damage_taken", test_brace_halves_damage_taken)
	run("brace_halves_walking_speed", test_brace_halves_walking_speed)
	run("brace_ends_after_two_seconds_and_cools_down", test_brace_ends_after_two_seconds_and_cools_down)
	run("cleanse_removes_every_control_effect", test_cleanse_removes_every_control_effect)
	run("cleanse_blocks_new_slows_for_two_seconds", test_cleanse_blocks_new_slows_for_two_seconds)
	run("focus_makes_shots_faster_and_harder", test_focus_makes_shots_faster_and_harder)
	run("focus_halves_walking_speed", test_focus_halves_walking_speed)
	run("focus_ends_after_three_seconds_and_cools_down", test_focus_ends_after_three_seconds_and_cools_down)
	run("repair_pulse_heals_the_weakest_part_until_hit", test_repair_pulse_heals_the_weakest_part_until_hit)
	run("xray_lets_shots_through_pillars", test_xray_lets_shots_through_pillars)
	run("electric_wall_zaps_slows_and_spares_its_owner", test_electric_wall_zaps_slows_and_spares_its_owner)
	run("trap_roots_the_rival_who_steps_on_it", test_trap_roots_the_rival_who_steps_on_it)
	run("frost_field_slows_only_inside", test_frost_field_slows_only_inside)
	run("lunge_flies_six_metres", test_lunge_flies_six_metres)
	run("lunge_hits_the_first_mech_in_the_way", test_lunge_hits_the_first_mech_in_the_way)
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


func hook_cd_after_pressing_e(head: String) -> float:
	var s := Sim.create_state([{"head": head}, {}], Sim.FORMATS["1v1"])
	s.phase = "fight"
	var me: Dictionary = s.mechs[0]
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.hook = true
	inp.ax = s.mechs[1].x
	inp.ay = s.mechs[1].y
	for i in 12:
		Sim.step(s, [inp, null])
	return me.cd.hook


func head_after(head: String, press_e: bool, ticks: int, walk: bool) -> Dictionary:
	var s := Sim.create_state([{"head": head}, {}], Sim.FORMATS["1v1"])
	s.phase = "fight"
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.hook = press_e
	inp.mx = 1.0 if walk else 0.0
	inp.ax = s.mechs[1].x
	inp.ay = s.mechs[1].y
	for i in ticks:
		Sim.step(s, [inp, null])
	return s


func test_brace_halves_damage_taken() -> int:
	var braced := head_after("demon", true, 3, false)
	var plain := head_after("demon", false, 3, false)
	var b: Dictionary = braced.mechs[0]
	var p: Dictionary = plain.mechs[0]
	Sim.env_hit(braced, b, 40, "head", 0, 0.0)
	Sim.env_hit(plain, p, 40, "head", 0, 0.0)
	return ensure(p.max.head - p.armor.head == 40, "an unbraced demon loses all 40") or ensure(b.max.head - b.armor.head == 20, "a braced demon loses 20")


func test_brace_halves_walking_speed() -> int:
	var braced: Dictionary = head_after("demon", true, 90, true).mechs[0]
	var plain: Dictionary = head_after("demon", false, 90, true).mechs[0]
	var ratio: float = braced.vx / plain.vx
	return ensure(plain.vx > 1.0, "the plain demon is walking") or ensure(absf(ratio - Sim.BRACE.move) < 0.05, "braced speed is %.2f of normal" % ratio)


func test_brace_ends_after_two_seconds_and_cools_down() -> int:
	var m: Dictionary = head_after("demon", true, 3, false).mechs[0]
	var during: int = m.buffs.brace
	var after: Dictionary = head_after("demon", true, Sim.BRACE.time + 5, false).mechs[0]
	return ensure(during > 0, "pressing E starts the brace") or ensure(after.buffs.brace == 0, "the brace has ended") or ensure(after.cd.hook > 0, "E is still cooling down")


func crest_under_control(press_e: bool) -> Dictionary:
	var s := Sim.create_state([{"head": "crest"}, {}], Sim.FORMATS["1v1"])
	s.phase = "fight"
	var m: Dictionary = s.mechs[0]
	m.buffs.slow = 200
	m.buffs.jam = 200
	m.buffs.root = 200
	m.stagger = 200
	m.pull = {"by": 1, "t": 50}
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.hook = press_e
	Sim.step(s, [inp, null])
	return s


func slow_field_on(s: Dictionary, m: Dictionary) -> void:
	s.fields.append({"kind": "stasis", "owner": 1, "x": m.x, "y": m.y, "r": 4.5, "t": 100, "T": 100})
	Sim.update_fields(s)


func test_cleanse_removes_every_control_effect() -> int:
	var held: Dictionary = crest_under_control(false).mechs[0]
	var m: Dictionary = crest_under_control(true).mechs[0]
	var free: bool = m.buffs.slow == 0 and m.buffs.jam == 0 and m.buffs.root == 0 and m.stagger == 0 and m.pull == null
	var stuck: bool = held.buffs.slow > 0 and held.buffs.jam > 0 and held.buffs.root > 0 and held.stagger > 0 and held.pull != null
	return ensure(stuck, "without E the crest stays slowed, jammed, rooted, stunned and pulled") or ensure(free, "with E every one of them is gone") or ensure(m.cd.hook > 0, "E starts cooling down")


func test_cleanse_blocks_new_slows_for_two_seconds() -> int:
	var s := crest_under_control(true)
	var m: Dictionary = s.mechs[0]
	slow_field_on(s, m)
	var while_warded: int = m.buffs.slow
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.hook = true
	for i in Sim.CLEANSE.time + 5:
		Sim.step(s, [inp, null])
	slow_field_on(s, m)
	return ensure(while_warded == 0, "a slow field does nothing while warded") or ensure(m.buffs.slow > 0, "the same field slows again once the ward ends")


func first_shot_of_visor(press_e: bool) -> Dictionary:
	var s := Sim.create_state([{"head": "visor"}, {}], Sim.FORMATS["1v1"])
	s.phase = "fight"
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.hook = press_e
	inp.left = true
	inp.ax = s.mechs[1].x
	inp.ay = s.mechs[1].y
	for i in 60:
		Sim.step(s, [inp, null])
		for shot in s.shots:
			if shot.owner == 0 and shot.kind == "bolt":
				return shot
	return {}


func test_focus_makes_shots_faster_and_harder() -> int:
	var plain := first_shot_of_visor(false)
	var focused := first_shot_of_visor(true)
	if plain.is_empty() or focused.is_empty():
		return ensure(false, "both runs fired a bolt")
	var ratio: float = Sim.hypot(focused.vx, focused.vy) / Sim.hypot(plain.vx, plain.vy)
	return ensure(absf(ratio - Sim.FOCUS.speed) < 0.02, "bolt speed is %.2f of normal" % ratio) or ensure(focused.dmg > plain.dmg, "a focused bolt hits harder (%d vs %d)" % [focused.dmg, plain.dmg])


func test_focus_halves_walking_speed() -> int:
	var focused: Dictionary = head_after("visor", true, 90, true).mechs[0]
	var plain: Dictionary = head_after("visor", false, 90, true).mechs[0]
	var ratio: float = focused.vx / plain.vx
	return ensure(plain.vx > 1.0, "the plain visor is walking") or ensure(absf(ratio - Sim.FOCUS.move) < 0.05, "focused speed is %.2f of normal" % ratio)


func test_focus_ends_after_three_seconds_and_cools_down() -> int:
	var during: int = head_after("visor", true, 3, false).mechs[0].buffs.focus
	var after: Dictionary = head_after("visor", true, Sim.FOCUS.time + 5, false).mechs[0]
	return ensure(during > 0, "pressing E starts the focus") or ensure(after.buffs.focus == 0, "the focus has ended") or ensure(after.cd.hook > 0, "E is still cooling down")


func fight_state(head0: String) -> Dictionary:
	var s := Sim.create_state([{"head": head0}, {}], Sim.FORMATS["1v1"])
	s.phase = "fight"
	return s


func armor_sum(m: Dictionary) -> float:
	var n := 0.0
	for p in m.armor:
		n += m.armor[p]
	return n


func test_repair_pulse_heals_the_weakest_part_until_hit() -> int:
	var s := fight_state("medic")
	var m: Dictionary = s.mechs[0]
	m.armor.larm = 100.0
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.hook = true
	for i in 90:
		Sim.step(s, [inp, null])
	var gained: float = m.armor.larm - 100.0
	var running: int = m.buffs.pulse
	Sim.env_hit(s, m, 5, "head", 0, 0.0)
	return ensure(absf(gained - 30.0) < 1.5, "half the pulse heals %.1f" % gained) or ensure(m.armor.rarm == m.max.rarm, "only the weakest part is healed") or ensure(running > 0 and m.buffs.pulse == 0, "a hit stops the pulse")


func bolts_left_after_a_pillar(xray: bool) -> int:
	var s := fight_state("dish")
	s.mechs[0].buffs.xray = 10 if xray else 0
	var p: Dictionary = Sim.PILLARS[0]
	Sim.spawn_shot(s, s.mechs[0], 1, p.x - p.r - 0.5, p.y, 0.0, {"speed": 60, "radius": 0.3, "range": 40}, 10, 0, "bolt")
	Sim.move_shots(s)
	return s.shots.size()


func test_xray_lets_shots_through_pillars() -> int:
	return ensure(bolts_left_after_a_pillar(false) == 0, "a normal bolt stops at the pillar") or ensure(bolts_left_after_a_pillar(true) == 1, "an x-ray bolt flies through it")


func test_electric_wall_zaps_slows_and_spares_its_owner() -> int:
	var s := fight_state("antenna")
	var m: Dictionary = s.mechs[0]
	var foe: Dictionary = s.mechs[1]
	m.tx = m.x + 5.0
	m.ty = m.y
	m.aim = 0.0
	Sim.cast_e(s, m, "arcwall", Sim.ARCWALL)
	var w: Dictionary = s.walls[0]
	foe.x = (w.x1 + w.x2) / 2.0
	foe.y = (w.y1 + w.y2) / 2.0
	Sim.zap_walls(s)
	var first: float = foe.max.legs - foe.armor.legs
	var slowed: int = foe.buffs.slow
	Sim.zap_walls(s)
	var second: float = foe.max.legs - foe.armor.legs
	return ensure(first == Sim.ARCWALL.dmg, "crossing costs %d" % Sim.ARCWALL.dmg) or ensure(slowed == Sim.ARCWALL.slow, "crossing slows") or ensure(second == first, "one zap per crossing") or ensure(not Sim.wall_blocks(s, 0, w), "the owner's shots pass") or ensure(Sim.wall_blocks(s, 1, w), "the rival's shots stop")


func test_trap_roots_the_rival_who_steps_on_it() -> int:
	var s := fight_state("dispenser")
	var m: Dictionary = s.mechs[0]
	var foe: Dictionary = s.mechs[1]
	m.aim = 0.0
	Sim.cast_e(s, m, "trap", Sim.TRAP)
	var mine: Dictionary = s.mines[0]
	mine.arm = 0
	foe.x = mine.x
	foe.y = mine.y
	Sim.update_mines(s)
	var rooted: int = foe.buffs.root
	var hurt: bool = foe.max.legs - foe.armor.legs > 0
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.mx = 1.0
	var x0: float = foe.x
	for i in 30:
		Sim.step(s, [null, inp])
	return ensure(rooted == Sim.TRAP.root and hurt, "the trap hurts and roots") or ensure(foe.buffs.root > 0 and absf(foe.x - x0) < 0.3, "a rooted mech cannot walk")


func test_frost_field_slows_only_inside() -> int:
	var s := fight_state("orb")
	var m: Dictionary = s.mechs[0]
	var foe: Dictionary = s.mechs[1]
	m.tx = m.x + 8.0
	m.ty = m.y
	Sim.cast_e(s, m, "frost", Sim.FROST)
	var f: Dictionary = s.fields[0]
	foe.x = f.x
	foe.y = f.y
	Sim.update_fields(s)
	var inside: int = foe.buffs.slow
	foe.buffs.slow = 0
	foe.x = f.x + f.r + 2.0
	Sim.update_fields(s)
	return ensure(inside > 0, "inside the field slows") or ensure(foe.buffs.slow == 0, "outside the field does not")


func lunge_run(press_e: bool, rival_close: bool) -> Dictionary:
	var s := fight_state("horn")
	var m: Dictionary = s.mechs[0]
	var foe: Dictionary = s.mechs[1]
	if rival_close:
		foe.x = m.x + 5.0
		foe.y = m.y
	var before := armor_sum(foe)
	var x0: float = m.x
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.hook = press_e
	inp.ax = m.x + 20.0
	inp.ay = m.y
	for i in 40:
		Sim.step(s, [inp, null])
	return {"flew": m.x - x0, "dealt": before - armor_sum(foe), "cd": m.cd.hook}


func test_lunge_flies_six_metres() -> int:
	var r := lunge_run(true, false)
	return ensure(r.flew > 5.0 and r.flew < 7.5, "flew %.1f m" % r.flew) or ensure(r.cd > 0, "E cools down")


func test_lunge_hits_the_first_mech_in_the_way() -> int:
	var hit := lunge_run(true, true)
	var miss := lunge_run(false, true)
	return ensure(hit.dealt > 0, "the lunge hurts the rival") or ensure(miss.dealt == 0, "nothing hurts the rival without it") or ensure(hit.flew < 4.0, "it stops at the rival (%.1f m)" % hit.flew)


func test_default_head_has_no_e_skill() -> int:
	var lo := Sim.normalize({})
	return ensure(lo.head == "rookie", "the default head is the rookie helm") or ensure(Sim.HEADS[lo.head].e == "", "the rookie helm carries no E skill")


func test_head_without_e_skill_never_throws_a_hook() -> int:
	return ensure(hook_cd_after_pressing_e("rookie") == 0, "pressing E with the rookie helm starts no hook")


func test_head_with_hook_throws_a_hook() -> int:
	return ensure(hook_cd_after_pressing_e("pincer") > 0, "pressing E with the pincers starts the hook cooldown")


func test_ffa_bot_match_ends_with_a_winner() -> int:
	var teams: Array = Sim.FORMATS["ffa"]
	var lo := []
	for i in teams.size():
		lo.append(Bot.random_loadout(Bot.create_brain(40 + i)))
	var r := bot_match(lo, teams, 400)
	var s: Dictionary = r.state
	return ensure(s.phase == "over", "phase == over after %d ticks" % r.ticks) or ensure(s.score.max() == Sim.MATCH.wins, "a team won %d rounds" % Sim.MATCH.wins)
