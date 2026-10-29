extends SceneTree

const Sim = preload("res://src/sim.gd")
const Progress = preload("res://src/progress.gd")

const TMP := "user://progress_test.cfg"
const SPAWN := {"x": 0, "y": 0, "aim": 0.0}

var failed := 0


func _initialize() -> void:
	run("new_player_owns_only_the_default_build", test_new_player_owns_only_the_default_build)
	run("claiming_a_new_part_unlocks_it_and_survives_a_reload", test_claiming_a_new_part_unlocks_it_and_survives_a_reload)
	run("claiming_an_owned_part_levels_it_up_to_the_cap", test_claiming_an_owned_part_levels_it_up_to_the_cap)
	run("unlock_all_opens_every_part_and_never_saves", test_unlock_all_opens_every_part_and_never_saves)
	run("pool_lists_what_broke_and_skips_maxed_parts", test_pool_lists_what_broke_and_skips_maxed_parts)
	run("every_part_can_be_won", test_every_part_can_be_won)
	run("rivals_cycle_the_ladder_then_come_back_stronger", test_rivals_cycle_the_ladder_then_come_back_stronger)
	run("levels_tune_the_part_and_level_one_changes_nothing", test_levels_tune_the_part_and_level_one_changes_nothing)
	run("a_save_with_junk_loads_only_the_valid_parts", test_a_save_with_junk_loads_only_the_valid_parts)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	if test.call() != 0:
		failed += 1
		print("test failed: " + name)
	else:
		print("test passed: %s (%d ms)" % [name, Time.get_ticks_msec() - t0])


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
	return int(not cond)


func locked() -> Progress:
	var p := Progress.new()
	p.unlock_all = false
	p.path = TMP
	return p


func wipe() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func test_new_player_owns_only_the_default_build() -> int:
	var p := locked()
	var bad := 0
	for slot in Sim.DEFAULT_LOADOUT:
		bad += ensure(p.has(slot, Sim.DEFAULT_LOADOUT[slot]), "owns the default " + slot)
	bad += ensure(not p.has("head", "demon"), "the demon head is locked")
	bad += ensure(p.has("right", "rivet"), "a weapon is owned for both hands")
	bad += ensure(not p.complete(Sim.SETS.tank), "the tank set is locked")
	bad += ensure(p.fit(Sim.SETS.tank) == Sim.DEFAULT_LOADOUT, "a build of locked parts falls back to the default build")
	return int(bad > 0)


func test_claiming_a_new_part_unlocks_it_and_survives_a_reload() -> int:
	wipe()
	var p := locked()
	p.claim("legs", "hover")
	p.win("duelist")
	p.save_file()
	var q := locked()
	q.load_file()
	wipe()
	var bad := ensure(q.has("legs", "hover") and q.level("legs", "hover") == 1, "the claimed part is owned at level 1 after a reload")
	bad += ensure(q.beaten.get("duelist", 0) == 1, "the win is remembered")
	return int(bad > 0)


func test_claiming_an_owned_part_levels_it_up_to_the_cap() -> int:
	var p := locked()
	p.claim("legs", "greaves")
	var bad := ensure(p.level("legs", "greaves") == 2, "a second copy makes Mk 2")
	p.claim("legs", "greaves")
	p.claim("legs", "greaves")
	bad += ensure(p.level("legs", "greaves") == Sim.MAX_LEVEL, "the level stops at the cap")
	p.claim("left", "saw")
	bad += ensure(p.level("right", "saw") == 2, "a weapon levels for both hands")
	return int(bad > 0)


func test_unlock_all_opens_every_part_and_never_saves() -> int:
	wipe()
	var p := Progress.new()
	p.path = TMP
	var bad := 0
	for slot in Sim.CATALOG:
		for key in Sim.CATALOG[slot]:
			bad += ensure(p.has(slot, key), "%s/%s is open" % [slot, key])
	p.claim("head", "demon")
	p.save_file()
	bad += ensure(not FileAccess.file_exists(TMP), "dev mode writes no progress file")
	return int(bad > 0)


func test_pool_lists_what_broke_and_skips_maxed_parts() -> int:
	var p := locked()
	var foe: Dictionary = Sim.SETS.tank
	var bad := ensure(p.pool(["legs"], foe, false) == [{"slot": "legs", "key": "stompers"}], "a broken leg drops the legs")
	var arm := p.pool(["larm"], foe, false)
	bad += ensure(arm == [{"slot": "arms", "key": "anvil"}, {"slot": "left", "key": "scatter"}], "a broken arm drops the arms and that hand's weapon")
	bad += ensure(p.pool(["larm", "rarm"], foe, false).size() == 3, "two broken arms drop the arms once")
	bad += ensure(p.pool([], foe, true).map(func(d): return d.slot) == ["head", "core", "booster"], "a K.O. drops the head, core and booster")
	bad += ensure(p.pool([], foe, false).is_empty(), "nothing broke, nothing drops")
	for i in Sim.MAX_LEVEL:
		p.claim("arms", "anvil")
	bad += ensure(p.pool(["larm"], foe, false) == [{"slot": "left", "key": "scatter"}], "a maxed part is not offered again")
	var twin := Sim.DEFAULT_LOADOUT.merged({"left": "fist", "right": "fist"}, true)
	bad += ensure(p.pool(["larm", "rarm"], twin, false).size() == 2, "the same weapon in both hands is offered once")
	return int(bad > 0)


func test_every_part_can_be_won() -> int:
	var reach := {}
	for slot in Sim.DEFAULT_LOADOUT:
		reach[Progress.id(slot, Sim.DEFAULT_LOADOUT[slot])] = true
	for set_key in Sim.SETS:
		for slot in Sim.DEFAULT_LOADOUT:
			reach[Progress.id(slot, Sim.SETS[set_key][slot])] = true
	var bad := ensure(Progress.LADDER.size() == Sim.SETS.size() and Sim.SETS.keys().all(func(k): return Progress.LADDER.has(k)), "every set is on the ladder")
	for slot in Sim.CATALOG:
		for key in Sim.CATALOG[slot]:
			bad += ensure(reach.has(Progress.id(slot, key)), "%s/%s can be won" % [slot, key])
	return int(bad > 0)


func test_rivals_cycle_the_ladder_then_come_back_stronger() -> int:
	var p := locked()
	var seen := {}
	for i in Progress.LADDER.size():
		var key := p.next_rival()
		seen[key] = true
		p.win(key)
	var bad := ensure(seen.size() == Progress.LADDER.size(), "every rival is met once before any repeats")
	bad += ensure(p.next_rival() == Progress.LADDER[0] and p.tier("duelist") == 2, "the first rival comes back at tier 2")
	var back := p.rival("duelist")
	bad += ensure(back.lv.head == 2 and Sim.set_of(back) == "duelist", "the rematch is the same set at Mk 2, set bonus on")
	bad += ensure(Sim.normalize(back) == back, "the rematch build is a valid loadout")
	bad += ensure(locked().rival("sniper") == Sim.SETS.sniper, "the first meeting is the plain set")
	p.win("duelist")
	p.win("duelist")
	bad += ensure(p.tier("duelist") == Sim.MAX_LEVEL, "the tier stops at the cap")
	return int(bad > 0)


func test_levels_tune_the_part_and_level_one_changes_nothing() -> int:
	var plain := Sim.make_mech(0, Sim.DEFAULT_LOADOUT, 0, SPAWN)
	var bad := ensure(not plain.has("rows") and Sim.head(plain) == Sim.HEADS.rookie, "a level 1 mech carries no extra data")
	var lo := Sim.DEFAULT_LOADOUT.merged({"lv": {"head": 3, "left": 2}}, true)
	var up := Sim.make_mech(0, lo, 0, SPAWN)
	bad += ensure(Sim.head(up).surge > Sim.HEADS.rookie.surge, "a Mk 3 head charges R faster")
	bad += ensure(Sim.weapon(up, "left").cd < Sim.WEAPONS.rivet.cd, "a Mk 2 weapon cools down faster")
	bad += ensure(Sim.weapon(up, "right") == Sim.WEAPONS.saw and Sim.core(up) == Sim.CORES.furnace, "parts without a level are untouched")
	bad += ensure(Sim.normalize({"lv": {"head": 9, "core": 1, "legs": "x"}}).lv == {"head": Sim.MAX_LEVEL}, "levels are clamped and junk is dropped")
	var state := Sim.create_state([lo, Sim.DEFAULT_LOADOUT])
	Sim.reset_round(state)
	bad += ensure(Sim.head(state.mechs[0]).surge > Sim.HEADS.rookie.surge, "the next round keeps the levels")
	return int(bad > 0)


func test_a_save_with_junk_loads_only_the_valid_parts() -> int:
	wipe()
	var cfg := ConfigFile.new()
	cfg.set_value("salvage", "owned", {"head:nope": 2, "head:demon": 9, "junk": 1, "weapon:fist": "x"})
	cfg.set_value("salvage", "beaten", {"nobody": 4, "tank": 2})
	cfg.save(TMP)
	var p := locked()
	p.load_file()
	wipe()
	var bad := ensure(p.level("head", "demon") == Sim.MAX_LEVEL, "a too-high level is capped")
	bad += ensure(not p.owned.has("head:nope") and not p.owned.has("junk") and not p.has("left", "fist"), "unknown and malformed parts are dropped")
	bad += ensure(p.beaten == {"tank": 2}, "an unknown rival is dropped")
	return int(bad > 0)
