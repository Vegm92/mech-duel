extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const Siege = preload("res://src/siege.gd")
const S = preload("res://src/siege_state.gd")
const Progress = preload("res://src/progress.gd")

const GOLDEN := 4044432856

var failed := 0
var filter := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--filter")
	if at >= 0 and at + 1 < args.size():
		filter = args[at + 1]
	run("siege_run_matches_golden_hash", test_siege_run_matches_golden_hash)
	run("same_seed_gives_same_siege_hash", test_same_seed_gives_same_siege_hash)
	run("first_wave_warns_eight_seconds_ahead_then_spawns_scouts", test_first_wave_warns_eight_seconds_ahead_then_spawns_scouts)
	run("scout_walks_its_lane_and_shoots_the_gate", test_scout_walks_its_lane_and_shoots_the_gate)
	run("gate_stops_bots_but_lets_players_through", test_gate_stops_bots_but_lets_players_through)
	run("scouts_break_the_gate_and_reach_the_core", test_scouts_break_the_gate_and_reach_the_core)
	run("player_shot_kills_a_scout_and_drops_scrap", test_player_shot_kills_a_scout_and_drops_scrap)
	run("player_shots_pass_over_the_core", test_player_shots_pass_over_the_core)
	run("rings_break_in_order_and_core_at_zero_loses", test_rings_break_in_order_and_core_at_zero_loses)
	run("repair_stops_at_the_lowest_intact_ring", test_repair_stops_at_the_lowest_intact_ring)
	run("downed_player_respawns_at_the_core", test_downed_player_respawns_at_the_core)
	run("swarm_cube_blows_up_on_the_gate_without_scrap", test_swarm_cube_blows_up_on_the_gate_without_scrap)
	run("spider_pops_out_of_a_vent_and_bites_a_player", test_spider_pops_out_of_a_vent_and_bites_a_player)
	run("flyer_crosses_the_wall_to_the_core", test_flyer_crosses_the_wall_to_the_core)
	run("blades_miss_a_flyer_but_bolts_hit_it", test_blades_miss_a_flyer_but_bolts_hit_it)
	run("turret_plants_shoots_the_gate_and_takes_half_damage", test_turret_plants_shoots_the_gate_and_takes_half_damage)
	run("walker_claws_the_gate", test_walker_claws_the_gate)
	run("tripod_aims_two_seconds_before_the_rail_hits", test_tripod_aims_two_seconds_before_the_rail_hits)
	run("stepping_aside_after_the_tripod_locks_dodges_the_rail", test_stepping_aside_after_the_tripod_locks_dodges_the_rail)
	run("quad_heavy_shells_the_core_from_beyond_the_wall", test_quad_heavy_shells_the_core_from_beyond_the_wall)
	run("heavy_cannon_splashes_a_player_and_shrugs_off_a_rivet", test_heavy_cannon_splashes_a_player_and_shrugs_off_a_rivet)
	run("juggernaut_is_untouchable_rolling_and_open_after_a_ram", test_juggernaut_is_untouchable_rolling_and_open_after_a_ram)
	run("juggernaut_hits_a_gate_three_times_as_hard", test_juggernaut_hits_a_gate_three_times_as_hard)
	run("waves_one_to_thirty_follow_the_plan", test_waves_one_to_thirty_follow_the_plan)
	run("more_players_get_bigger_waves", test_more_players_get_bigger_waves)
	run("tanks_come_first_and_ranged_bots_five_seconds_later", test_tanks_come_first_and_ranged_bots_five_seconds_later)
	run("gate_repair_and_rebuild_cost_scrap", test_gate_repair_and_rebuild_cost_scrap)
	run("core_ring_rebuild_restores_its_line", test_core_ring_rebuild_restores_its_line)
	run("nothing_can_be_bought_during_a_wave_or_without_scrap", test_nothing_can_be_bought_during_a_wave_or_without_scrap)
	run("barricade_stops_bots_until_they_break_it", test_barricade_stops_bots_until_they_break_it)
	run("mine_field_blows_up_a_scout", test_mine_field_blows_up_a_scout)
	run("lane_laser_warns_then_burns_what_stands_in_it", test_lane_laser_warns_then_burns_what_stands_in_it)
	run("rail_post_fires_where_the_player_aims", test_rail_post_fires_where_the_player_aims)
	run("square_wheel_builds_on_the_pad_in_reach", test_square_wheel_builds_on_the_pad_in_reach)
	run("gate_wheel_fixes_the_gate_you_stand_at", test_gate_wheel_fixes_the_gate_you_stand_at)
	run("plaza_sells_no_modules_or_gate_fixes", test_plaza_sells_no_modules_or_gate_fixes)
	run("auto_turret_kills_a_bot_in_range_and_bots_can_destroy_it", test_auto_turret_kills_a_bot_in_range_and_bots_can_destroy_it)
	run("calling_the_wave_early_pays_scrap", test_calling_the_wave_early_pays_scrap)
	run("clean_wave_pays_a_bonus", test_clean_wave_pays_a_bonus)
	run("clearing_wave_ten_offers_salvage", test_clearing_wave_ten_offers_salvage)
	run("best_wave_is_saved_and_loaded", test_best_wave_is_saved_and_loaded)
	run("endless_waves_are_mk3_with_a_new_mutator_every_five", test_endless_waves_are_mk3_with_a_new_mutator_every_five)
	run("plated_mutator_gives_bots_more_armor", test_plated_mutator_gives_bots_more_armor)
	run("yards_open_through_the_arch_not_the_lane_wall", test_yards_open_through_the_arch_not_the_lane_wall)
	run("every_yard_opening_leads_onto_its_lane_and_back", test_every_yard_opening_leads_onto_its_lane_and_back)
	run("lane_bots_ignore_a_player_in_the_yard", test_lane_bots_ignore_a_player_in_the_yard)
	run("the_farming_ally_crosses_between_yards_through_the_openings", test_the_farming_ally_crosses_between_yards_through_the_openings)
	run("a_raid_leaves_a_yard_through_the_nearest_opening", test_a_raid_leaves_a_yard_through_the_nearest_opening)
	run("camp_sleeps_until_a_player_comes_close_then_all_of_it_wakes", test_camp_sleeps_until_a_player_comes_close_then_all_of_it_wakes)
	run("camp_bot_goes_home_past_its_leash_and_heals", test_camp_bot_goes_home_past_its_leash_and_heals)
	run("clearing_a_camp_pays_the_player_who_killed_it", test_clearing_a_camp_pays_the_player_who_killed_it)
	run("a_camp_nobody_killed_pays_nobody", test_a_camp_nobody_killed_pays_nobody)
	run("elite_pays_a_reinforce_token", test_elite_pays_a_reinforce_token)
	run("crate_takes_three_still_seconds_and_resets_if_you_move", test_crate_takes_three_still_seconds_and_resets_if_you_move)
	run("camps_and_crates_refill_each_wave_the_elite_every_five", test_camps_and_crates_refill_each_wave_the_elite_every_five)
	run("raids_from_wave_15_wipe_camps_and_pay_nothing", test_raids_from_wave_15_wipe_camps_and_pay_nothing)
	run("wallet_upgrade_reinforce_and_revive", test_wallet_upgrade_reinforce_and_revive)
	run("wallet_buys_only_in_the_plaza", test_wallet_buys_only_in_the_plaza)
	run("steam_hides_a_mech", test_steam_hides_a_mech)
	run("crush_plate_hits_bots_too", test_crush_plate_hits_bots_too)
	run("garrison_costs_the_fund_and_stands_at_its_dock", test_garrison_costs_the_fund_and_stands_at_its_dock)
	run("each_garrison_tier_swaps_parts_up", test_each_garrison_tier_swaps_parts_up)
	run("garrison_holds_its_leash_and_shoots_what_comes_in", test_garrison_holds_its_leash_and_shoots_what_comes_in)
	run("garrison_rebuilds_for_free_after_its_timer", test_garrison_rebuilds_for_free_after_its_timer)
	run("a_full_garrison_alone_still_loses_wave_15", test_a_full_garrison_alone_still_loses_wave_15)
	run("a_full_garrison_alone_still_loses_wave_25", test_a_full_garrison_alone_still_loses_wave_25)
	run("a_run_starts_with_a_small_wallet", test_a_run_starts_with_a_small_wallet)
	run("tier_prices_grow_with_the_square_and_raise_hand_damage", test_tier_prices_grow_with_the_square_and_raise_hand_damage)
	run("plating_tiers_raise_max_armor_and_survive_a_respawn", test_plating_tiers_raise_max_armor_and_survive_a_respawn)
	run("swapping_needs_an_owned_part_and_costs_by_series", test_swapping_needs_an_owned_part_and_costs_by_series)
	run("heal_buys_fix_armor_heat_and_surge", test_heal_buys_fix_armor_heat_and_surge)
	run("recall_takes_three_seconds_and_damage_breaks_it", test_recall_takes_three_seconds_and_damage_breaks_it)
	run("a_lane_kill_pays_only_the_killer", test_a_lane_kill_pays_only_the_killer)
	run("a_hazard_kill_pays_nobody", test_a_hazard_kill_pays_nobody)
	run("a_module_kill_pays_the_player_who_built_it", test_a_module_kill_pays_the_player_who_built_it)
	run("a_garrison_kill_pays_whoever_bought_its_tier", test_a_garrison_kill_pays_whoever_bought_its_tier)
	run("a_build_phase_buy_on_the_first_pad_works_with_the_starting_wallet", test_a_build_phase_buy_on_the_first_pad_works_with_the_starting_wallet)
	run("ai_teammate_spends_its_wallet_in_the_plaza_between_waves", test_ai_teammate_spends_its_wallet_in_the_plaza_between_waves)
	run("default_weapon_kills_scouts_swarms_and_spiders_in_three_hits", test_default_weapon_kills_scouts_swarms_and_spiders_in_three_hits)
	run("pressure_is_zero_when_calm_and_rises_with_core_loss_and_downed_mechs", test_pressure_is_zero_when_calm_and_rises_with_core_loss_and_downed_mechs)
	run("one_spike_barely_moves_strain_and_no_wave_moves_it_past_15", test_one_spike_barely_moves_strain_and_no_wave_moves_it_past_15)
	run("breathers_plan_less_go_straight_and_rest_15_s_longer", test_breathers_plan_less_go_straight_and_rest_15_s_longer)
	run("every_tactic_warns_each_group_and_spawns_only_at_mouths_vents_and_corners", test_every_tactic_warns_each_group_and_spawns_only_at_mouths_vents_and_corners)
	run("spawns_wait_while_a_player_stands_on_the_spot", test_spawns_wait_while_a_player_stands_on_the_spot)
	run("boss_waves_keep_their_must_list_and_mk_and_scrap_is_untouched", test_boss_waves_keep_their_must_list_and_mk_and_scrap_is_untouched)
	run("waves_one_to_three_plan_the_same_with_the_director_on_and_off", test_waves_one_to_three_plan_the_same_with_the_director_on_and_off)
	run("two_easy_waves_raise_the_tier_and_two_hard_waves_give_one_pity_wave", test_two_easy_waves_raise_the_tier_and_two_hard_waves_give_one_pity_wave)
	print("FAILED" if failed else "ALL PASSED")
	quit(1 if failed else 0)


func run(name: String, test: Callable) -> void:
	if filter != "" and not name.contains(filter):
		print("test skipped: " + name)
		return
	var t0 := Time.get_ticks_msec()
	var r = test.call()
	if typeof(r) != TYPE_INT or r != 0:
		failed += 1
		print("test failed: %s" % name)
	else:
		print("test passed: %s (%d ms)" % [name, Time.get_ticks_msec() - t0])


func ensure(cond: bool, what: String) -> int:
	if not cond:
		print("  condition false: " + what)
		return 1
	return 0


func wave_bots(s: Dictionary) -> Array:
	return s.siege.enemies.filter(func(e): return not e.neutral)


func idle(at := Vector2.ZERO) -> Dictionary:
	var inp: Dictionary = Sim.IDLE.duplicate()
	inp.ax = at.x
	inp.ay = at.y
	return inp


func park(s: Dictionary, x: float, y: float) -> void:
	var m: Dictionary = s.mechs[0]
	m.x = x
	m.y = y


func steps(s: Dictionary, n: int, inp := {}) -> void:
	for i in n:
		Siege.step(s, [inp if not inp.is_empty() else idle()])


func bot_run(seed: int, ticks: int) -> Dictionary:
	var s := Siege.create([Sim.SETS.duelist, Sim.SETS.sniper], seed)
	var brains := [Bot.create_brain(seed), Bot.create_brain(seed + 1)]
	var trail := ""
	for i in ticks:
		Siege.step(s, [Siege.ally_input(s, brains[0], 0), Siege.ally_input(s, brains[1], 1)])
		if i % 60 == 0:
			trail += str(Sim.hash_state(s))
	return {"state": s, "hash": trail.hash()}


func test_siege_run_matches_golden_hash() -> int:
	var r := bot_run(11, 3600)
	var h: int = r.hash
	if h != GOLDEN:
		print("  golden hash is %d (wave %d, core %d, kills %d)" % [h, r.state.siege.wave.n, r.state.siege.core.hp, r.state.siege.kills])
	return ensure(h == GOLDEN, "hash == GOLDEN") or ensure(r.state.siege.kills > 0, "the bots killed something")


func test_same_seed_gives_same_siege_hash() -> int:
	return ensure(bot_run(5, 1800).hash == bot_run(5, 1800).hash, "same seed, same hash")


func test_first_wave_warns_eight_seconds_ahead_then_spawns_scouts() -> int:
	var s := Siege.create([{}], 3)
	park(s, -15, 15)
	var warned := -1
	for i in Siege.RUN.first - 1:
		Siege.step(s, [idle()])
		for f in s.fx:
			if f.k == "warn" and warned < 0:
				warned = s.tick
	var n: int = wave_bots(s).size()
	steps(s, 1)
	return ensure(warned == Siege.RUN.first - Siege.RUN.warn, "warning at tick %d" % warned) or ensure(n == 0, "nobody before the wave") or ensure(wave_bots(s).size() > 0 and wave_bots(s)[0].kind == "scout", "a scout spawns") or ensure(s.siege.wave.n == 1, "wave 1")


func test_scout_walks_its_lane_and_shoots_the_gate() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	park(s, -15, 15)
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var y0: float = e.y
	steps(s, 60 * 12)
	var g: Dictionary = s.siege.gates[0]
	return ensure(y0 < -70, "spawned at the north border") or ensure(e.y > -32 and e.y < -20, "stopped in front of the gate at %.1f" % e.y) or ensure(g.hp < g.max, "the gate took damage")


func test_gate_stops_bots_but_lets_players_through() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	b.x = 0.0
	b.y = -20.0
	park(s, 0, -10)
	var walk := idle()
	walk.my = -1.0
	for i in 120:
		b.x = 0.0
		Sim.move(s, b, {"mx": 0.0, "my": 1.0})
		Siege.step(s, [walk])
	var me: Dictionary = s.mechs[0]
	return ensure(b.y < -S.RING_OUT, "the scout is held outside at %.1f" % b.y) or ensure(me.y < -S.RING_OUT - 1, "the player walked out to %.1f" % me.y)


func test_scouts_break_the_gate_and_reach_the_core() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	park(s, -15, 15)
	s.siege.gates[0].hp = 30.0
	for i in 4:
		Siege.spawn(s, "scout", 0, (i - 1.5) * 1.5)
	steps(s, 60 * 25)
	var c: Dictionary = s.siege.core
	return ensure(s.siege.gates[0].hp == 0, "the gate broke") or ensure(c.hp < c.max, "the core took damage")


func test_player_shot_kills_a_scout_and_drops_scrap() -> int:
	var s := Siege.create([{"left": "rivet"}], 3)
	s.siege.wave.next_in = 99999
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	b.x = 0.0
	b.y = -40.0
	park(s, 0, -30)
	var inp := idle(Vector2(0, -40))
	inp.left = true
	for i in 60:
		b.x = 0.0
		b.y = -40.0
		Siege.step(s, [inp])
		inp.left = not inp.left
	return ensure(e.act == "die", "the scout died, act %s hp %d" % [e.act, e.hp]) or ensure(s.siege.wallets[0] == Siege.TIER.wallet + Siege.BOTS.scout.cost * Siege.RUN.scrap, "scrap %d" % s.siege.wallets[0])


func test_player_shots_pass_over_the_core() -> int:
	var s := Siege.create([{"left": "rivet"}], 3)
	s.siege.wave.next_in = 99999
	park(s, 0, 6)
	var inp := idle(Vector2(0, -6))
	inp.left = true
	for i in 20:
		Siege.step(s, [inp])
	var far: Array = s.shots.filter(func(sh): return sh.y < -3)
	return ensure(s.siege.core.hp == s.siege.core.max, "the core is untouched") or ensure(not far.is_empty(), "the shot flew past the core")


func test_rings_break_in_order_and_core_at_zero_loses() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	var c: Dictionary = s.siege.core
	c.hp = c.max * 0.6
	steps(s, 1)
	var after_one: Array = c.rings.duplicate()
	c.hp = 0.0
	steps(s, 1)
	return ensure(c.broken == 4, "every ring broke") or ensure(after_one[0] == 0 and after_one[1] > 0, "the outer ring broke first: %s" % [after_one]) or ensure(s.siege.lost and s.phase == "over", "the run is lost")


func test_repair_stops_at_the_lowest_intact_ring() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	var c: Dictionary = s.siege.core
	c.hp = c.max * 0.6
	park(s, 0, 3.5)
	steps(s, 60 * 40)
	return ensure(c.broken == 1, "one ring broken") or ensure(is_equal_approx(c.hp, c.max * 0.75), "repaired up to 75%%, got %.0f" % c.hp)


func test_downed_player_respawns_at_the_core() -> int:
	var s := Siege.create([{}], 3)
	s.siege.wave.next_in = 99999
	park(s, -15, 15)
	s.mechs[0].armor.head = 0
	steps(s, 2)
	var down: bool = s.mechs[0].ko
	steps(s, Siege.RUN.respawn + 2)
	var m: Dictionary = s.mechs[0]
	return ensure(down, "the player went down") or ensure(not m.ko and m.armor.head == m.max.head, "back up with full armor") or ensure(Sim.hypot(m.x, m.y) < 8, "at the core")


func lab(lo := {}) -> Dictionary:
	var s := Siege.create([lo], 3)
	s.siege.wallets[0] = 0
	s.siege.wave.next_in = 999999
	park(s, -15, 15)
	return s


func until(s: Dictionary, most: int, done: Callable) -> int:
	for i in most:
		Siege.step(s, [idle()])
		if done.call():
			return i + 1
	return -1


func test_swarm_cube_blows_up_on_the_gate_without_scrap() -> int:
	var s := lab()
	Siege.spawn(s, "swarm", 0, 0.0)
	var cubes: int = wave_bots(s).size()
	var g: Dictionary = s.siege.gates[0]
	var t := until(s, 60 * 20, func(): return g.hp < g.max)
	return ensure(cubes == 3, "a swarm is 3 cubes") or ensure(t > 0, "a cube reached the gate") or ensure(g.max - g.hp >= Siege.BOTS.swarm.boom.dmg * Siege.RUN.gateSoak, "the gate lost %d" % (g.max - g.hp)) or ensure(s.siege.wallets[0] == 0, "blowing up gives no scrap")


func test_spider_pops_out_of_a_vent_and_bites_a_player() -> int:
	var s := lab()
	park(s, 0, -36)
	var e := Siege.spawn(s, "spider", 0, 1.0)
	var at := Vector2(e.x, e.y)
	var me: Dictionary = s.mechs[0]
	var t := until(s, 60 * 10, func(): return me.armor.legs < me.max.legs)
	return ensure(absf(at.y + S.VENTS[0]) < 2.0 and absf(at.x) > 3.0, "spawned at the vent, at %s" % at) or ensure(t > 0, "it bit the player")


func test_flyer_crosses_the_wall_to_the_core() -> int:
	var s := lab()
	var e := Siege.spawn(s, "flyer", 0, 0.0)
	var c: Dictionary = s.siege.core
	var t := until(s, 60 * 30, func(): return c.hp < c.max)
	return ensure(Sim.hypot(e.x, e.y) < S.RING_IN, "inside the fortress at %.1f" % Sim.hypot(e.x, e.y)) or ensure(t > 0, "it shot the core")


func test_blades_miss_a_flyer_but_bolts_hit_it() -> int:
	var s := lab({"left": "rivet", "right": "saw"})
	var e := Siege.spawn(s, "flyer", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	var me: Dictionary = s.mechs[0]
	b.x = me.x + 1.5
	b.y = me.y
	me.aim = 0.0
	Sim.swing(s, me, "right", false)
	var cut: float = b.armor.head
	Sim.spawn_shot(s, me, 99, me.x + 0.5, me.y, 0.0, Sim.WEAPONS.rivet, 65, 1, "bolt")
	Sim.move_shots(s)
	return ensure(cut == b.max.head, "the saw missed") or ensure(b.armor.head < b.max.head, "the bolt hit")


func test_turret_plants_shoots_the_gate_and_takes_half_damage() -> int:
	var s := lab()
	var e := Siege.spawn(s, "turret", 0, 0.0)
	var g: Dictionary = s.siege.gates[0]
	var t := until(s, 60 * 40, func(): return g.hp < g.max)
	var b: Dictionary = s.mechs[e.m]
	var was: float = b.armor.head
	Sim.env_hit(s, b, 100, "head", 0, 0.0)
	return ensure(t > 0, "it shot the gate") or ensure(e.rooted >= Siege.BOTS.turret.plant, "it planted first") or ensure(was - b.armor.head == 50, "planted, it took %d of 100" % (was - b.armor.head))


func test_walker_claws_the_gate() -> int:
	var s := lab()
	var e := Siege.spawn(s, "walker", 0, 0.0)
	var g: Dictionary = s.siege.gates[0]
	var t := until(s, 60 * 40, func(): return g.hp <= g.max - Siege.BOTS.walker.dmg)
	return ensure(t > 0, "the gate lost a claw's worth") or ensure(absf(e.y) < S.RING_OUT + 4.0, "in claw reach at %.1f" % e.y)


func rail_test(step_aside_at: int) -> Dictionary:
	var s := lab()
	park(s, 0, -50)
	Siege.spawn(s, "tripod", 0, 0.0)
	var me: Dictionary = s.mechs[0]
	var seen := -1
	var hurt := -1
	for i in 60 * 12:
		Siege.step(s, [idle()])
		me.x = 0.0 if seen < 0 or s.tick - seen < step_aside_at else 4.0
		me.y = -50.0
		for f in s.fx:
			if f.k == "sight" and seen < 0:
				seen = s.tick
		if hurt < 0 and me.armor.larm + me.armor.rarm < me.max.larm + me.max.rarm:
			hurt = s.tick
	return {"seen": seen, "hurt": hurt}


func test_tripod_aims_two_seconds_before_the_rail_hits() -> int:
	var r := rail_test(99999)
	return ensure(r.seen > 0 and r.hurt > 0, "it aimed and hit (%d, %d)" % [r.seen, r.hurt]) or ensure(r.hurt - r.seen >= Siege.BOTS.tripod.windup - 1, "warning lasted %d ticks" % (r.hurt - r.seen))


func test_stepping_aside_after_the_tripod_locks_dodges_the_rail() -> int:
	var lock: int = Siege.BOTS.tripod.windup - Siege.BOTS.tripod.lock
	var r := rail_test(lock + 5)
	return ensure(r.seen > 0, "it aimed") or ensure(r.hurt < 0 or r.hurt - r.seen > Siege.BOTS.tripod.windup + 5, "the first rail missed (hurt at +%d)" % (r.hurt - r.seen))


func test_quad_heavy_shells_the_core_from_beyond_the_wall() -> int:
	var s := lab()
	var e := Siege.spawn(s, "quadheavy", 0, 0.0)
	var c: Dictionary = s.siege.core
	var seen := {"marked": false}
	var t := until(s, 60 * 40, func():
		for l in s.lobs:
			if l.T == Siege.BOTS.quadheavy.delay:
				seen.marked = true
		return c.hp < c.max)
	return ensure(t > 0, "shells hit the core") or ensure(seen.marked, "landing spots were marked") or ensure(absf(e.y) > S.RING_OUT + 3.0, "it stayed outside at %.1f" % e.y)


func test_heavy_cannon_splashes_a_player_and_shrugs_off_a_rivet() -> int:
	var s := lab()
	park(s, 0, -45)
	var e := Siege.spawn(s, "heavy", 0, 0.0)
	var me: Dictionary = s.mechs[0]
	var t := until(s, 60 * 30, func(): return me.armor.legs < me.max.legs)
	var b: Dictionary = s.mechs[e.m]
	Sim.hit(s, me, b, 65, "ARMS", Sim.WEAPONS.rivet.impact, 0.0, 77)
	return ensure(t > 0, "the cannon hit the player") or ensure(me.max.legs - me.armor.legs >= Siege.BOTS.heavy.dmg, "splash did %d" % (me.max.legs - me.armor.legs)) or ensure(b.stagger == 0, "a rivet does not stagger it")


func test_juggernaut_is_untouchable_rolling_and_open_after_a_ram() -> int:
	var s := lab()
	park(s, 0, -40)
	var e := Siege.spawn(s, "jugg", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	var me: Dictionary = s.mechs[0]
	Siege.step(s, [idle()])
	Sim.hit(s, me, b, 200, "ARMS", 1, 0.0, 70)
	var rolling: float = b.armor.head
	var whole := Sim.total_armor(me)
	var t := until(s, 60 * 10, func(): return e.mode == "open")
	steps(s, 30)
	Sim.hit(s, me, b, 200, "ARMS", 1, 0.0, 71)
	return ensure(rolling == b.max.head, "no damage while rolling") or ensure(t > 0, "it rammed and opened") or ensure(Sim.total_armor(me) < whole, "the player was hit") or ensure(absf(me.y + 40.0) > 2.0, "the player was pushed to %.1f" % me.y) or ensure(b.armor.head < b.max.head, "open, it takes damage")


func test_juggernaut_hits_a_gate_three_times_as_hard() -> int:
	var s := lab()
	Siege.spawn(s, "jugg", 0, 0.0)
	var g: Dictionary = s.siege.gates[0]
	var t := until(s, 60 * 15, func(): return g.hp < g.max)
	return ensure(t > 0, "it hit the gate") or ensure(g.max - g.hp == Siege.BOTS.jugg.dmg * Siege.BOTS.jugg.gateK * Siege.RUN.gateSoak, "gate lost %d" % (g.max - g.hp))


func planned(n: int, team := 1, on := false) -> Array:
	var los := []
	for i in team:
		los.append({})
	var s := Siege.create(los, 9 + n)
	s.siege.director.on = on
	Siege.plan(s, s.siege, n)
	return s.siege.queue.filter(func(q): return q.has("kind"))


func kinds_of(q: Array) -> Dictionary:
	var out := {}
	for u in q:
		if u.has("kind"):
			out[u.kind] = out.get(u.kind, 0) + 1
	return out


func test_waves_one_to_thirty_follow_the_plan() -> int:
	var fails := []
	var want := {1: ["scout"], 4: ["spider"], 6: ["flyer"], 8: ["turret"], 9: ["walker"], 10: ["heavy"], 12: ["tripod"], 15: ["jugg"], 17: ["quadheavy"]}
	for n in range(1, 31):
		var q := planned(n)
		var k := kinds_of(q)
		if q.is_empty():
			fails.append("wave %d is empty" % n)
		for kind in want.get(n, []):
			if not k.has(kind):
				fails.append("wave %d has no %s" % [n, kind])
		var mk: int = q[0].mk if q.size() else 0
		if mk != (2 if n >= 21 else 1):
			fails.append("wave %d is Mk %d" % [n, mk])
	var w1: Dictionary = kinds_of(planned(1))
	var w20: Dictionary = kinds_of(planned(20))
	var w30: Dictionary = kinds_of(planned(30))
	if w1.keys() != ["scout"]:
		fails.append("wave 1 is scouts only: %s" % [w1])
	if w20.get("quadheavy", 0) < 2:
		fails.append("wave 20 has 2 Quad Heavies")
	if w30.get("heavy", 0) < 3 or w30.size() < Siege.BOTS.size():
		fails.append("wave 30 has every bot and 3 Heavy Mechs: %s" % [w30])
	for f in fails:
		print("  " + f)
	return ensure(fails.is_empty(), "waves follow the plan")


func test_more_players_get_bigger_waves() -> int:
	return ensure(planned(8, 4).size() > planned(8, 1).size(), "4 mechs face more bots than 1")


func test_tanks_come_first_and_ranged_bots_five_seconds_later() -> int:
	var q := planned(10)
	var first := 1 << 30
	var heavy := 1 << 30
	var turret := 1 << 30
	for u in q:
		first = mini(first, u.at)
		if u.kind == "heavy":
			heavy = mini(heavy, u.at)
		if u.kind == "turret":
			turret = mini(turret, u.at)
	return ensure(heavy == first, "the Heavy Mech leads") or ensure(turret >= first + Siege.RUN.ranged, "turrets come 5 s later")


func shop(scrap := 1000) -> Dictionary:
	var s := lab()
	s.siege.wallets[0] = scrap
	return s


func test_gate_repair_and_rebuild_cost_scrap() -> int:
	var s := shop()
	var g: Dictionary = s.siege.gates[1]
	g.hp = 300.0
	var h: Dictionary = s.siege.gates[2]
	h.hp = 0.0
	park(s, g.x, g.y)
	var a := Siege.buy(s, s.siege, "gate", s.mechs[0])
	park(s, h.x, h.y)
	var b := Siege.buy(s, s.siege, "rebuild", s.mechs[0])
	return ensure(a and g.hp == 300.0 + g.max * 0.2, "gate repair adds 20%%, got %d" % g.hp) or ensure(b and h.hp == h.max * 0.5, "rebuilt at 50%%") or ensure(s.siege.wallets[0] == 1000 - Siege.SHOP.gate - Siege.SHOP.rebuild, "paid %d" % (1000 - s.siege.wallets[0]))


func test_core_ring_rebuild_restores_its_line() -> int:
	var s := shop()
	var c: Dictionary = s.siege.core
	c.hp = c.max * 0.6
	steps(s, 1)
	var ok := Siege.buy(s, s.siege, "ring", s.mechs[0])
	steps(s, 1)
	return ensure(ok and c.broken == 0, "ring back") or ensure(c.hp == c.max, "core at 100%%, got %d" % c.hp)


func test_nothing_can_be_bought_during_a_wave_or_without_scrap() -> int:
	var s := shop(10)
	s.siege.gates[0].hp = 100.0
	var poor := Siege.buy(s, s.siege, "gate", s.mechs[0])
	s.siege.wallets[0] = 1000
	s.siege.wave.live = true
	var busy := Siege.buy(s, s.siege, "gate", s.mechs[0])
	return ensure(not poor, "too poor") or ensure(not busy, "not during a wave")


func on_pad(s: Dictionary, lane: int, i: int) -> Dictionary:
	var pd: Dictionary = s.siege.pads[lane * 3 + i]
	park(s, pd.x + 0.5, pd.y)
	return pd


func test_barricade_stops_bots_until_they_break_it() -> int:
	var s := shop()
	var pd := on_pad(s, 0, 1)
	var ok := Siege.buy(s, s.siege, "wall", s.mechs[0])
	park(s, -15, 15)
	var e := Siege.spawn(s, "walker", 0, 0.0)
	var t := until(s, 60 * 30, func(): return pd.hp < pd.max)
	var held: bool = absf(e.y) > absf(pd.y)
	return ensure(ok and pd.module == "wall", "built") or ensure(t > 0, "the walker hit the barricade") or ensure(held, "held behind it at %.1f" % e.y) or ensure(s.siege.gates[0].hp == s.siege.gates[0].max, "the gate is untouched")


func test_mine_field_blows_up_a_scout() -> int:
	var s := shop()
	var pd := on_pad(s, 0, 2)
	Siege.buy(s, s.siege, "mine", s.mechs[0])
	park(s, -15, 15)
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var t := until(s, 60 * 10, func(): return e.act == "die")
	return ensure(s.mines.size() < Siege.MODULE.mine.n, "a mine went off") or ensure(t > 0, "the scout died")


func test_lane_laser_warns_then_burns_what_stands_in_it() -> int:
	var s := shop()
	var pd := on_pad(s, 0, 1)
	Siege.buy(s, s.siege, "laser", s.mechs[0])
	park(s, -15, 15)
	s.siege.wave.live = true
	var e := Siege.spawn(s, "heavy", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	var warned := -1
	for i in Siege.MODULE.laser.every:
		b.x = pd.x
		b.y = pd.y
		b.vx = 0.0
		b.vy = 0.0
		Siege.step(s, [idle()])
		for f in s.fx:
			if f.k == "laserWarn" and warned < 0:
				warned = s.tick
	return ensure(warned > 0, "the laser warned") or ensure(b.armor.head <= b.max.head - Siege.MODULE.laser.dmg, "the heavy took the beam")


func test_rail_post_fires_where_the_player_aims() -> int:
	var s := shop()
	var pd := on_pad(s, 0, 1)
	Siege.buy(s, s.siege, "post", s.mechs[0])
	var e := Siege.spawn(s, "heavy", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	b.x = pd.x
	b.y = pd.y - 15.0
	var inp := idle(Vector2(b.x, b.y))
	inp.post = true
	Siege.step(s, [inp])
	var aimed: float = b.armor.head
	var away := idle(Vector2(pd.x + 30.0, pd.y))
	away.post = true
	steps(s, Siege.MODULE.post.cd + 1, away)
	return ensure(aimed == b.max.head - Siege.MODULE.post.dmg, "the post hit what the player aimed at (%d)" % (b.max.head - aimed)) or ensure(b.armor.head == aimed, "aimed away, it missed")


func test_calling_the_wave_early_pays_scrap() -> int:
	var s := Siege.create([{}], 3)
	park(s, -15, 15)
	steps(s, 1)
	var left: int = s.siege.wave.next_in
	var inp := idle()
	inp.call = true
	steps(s, 1, inp)
	var paid: int = s.siege.wallets[0] - Siege.TIER.wallet
	steps(s, 2)
	return ensure(paid == Siege.RUN.call * int(ceil((left - 1 - Siege.RUN.warn) / 60.0)), "paid %d scrap" % paid) or ensure(not s.siege.queue.is_empty(), "the wave is planned")


func test_clean_wave_pays_a_bonus() -> int:
	var s := lab()
	var e := Siege.spawn(s, "scout", 0, 0.0)
	s.siege.wave.next_in = 2
	steps(s, 2)
	s.siege.earned = 100
	s.mechs[e.m].armor.head = 0
	var before: int = s.siege.wallets[0]
	steps(s, 2)
	return ensure(not s.siege.wave.live, "the wave is over") or ensure(s.siege.wallets[0] >= before + 20, "bonus paid: %d" % (s.siege.wallets[0] - before))


func test_clearing_wave_ten_offers_salvage() -> int:
	var s := lab()
	var e := Siege.spawn(s, "scout", 0, 0.0)
	s.siege.wave.n = 9
	s.siege.wave.next_in = 2
	steps(s, 2)
	s.mechs[e.m].armor.head = 0
	var seen := false
	for i in 3:
		Siege.step(s, [idle()])
		for f in s.fx:
			if f.k == "milestone" and f.n == 10:
				seen = true
	var p := Progress.new()
	p.unlock_all = false
	var drops := p.spoils(10)
	return ensure(seen, "wave 10 cleared says milestone") or ensure(drops.size() >= 5, "a full set to pick from: %d" % drops.size()) or ensure(p.spoils(11).is_empty(), "only waves 10, 20 and 30 pay")


func test_best_wave_is_saved_and_loaded() -> int:
	var path := OS.get_user_data_dir() + "/siege_best_test.cfg"
	var p := Progress.new()
	p.unlock_all = false
	p.path = path
	var first := p.held(12)
	var lower := p.held(7)
	p.save_file()
	var q := Progress.new()
	q.path = path
	q.load_file()
	DirAccess.remove_absolute(path)
	return ensure(first and not lower, "only a better run counts") or ensure(q.best == 12, "best wave read back: %d" % q.best)


func test_endless_waves_are_mk3_with_a_new_mutator_every_five() -> int:
	var s := lab()
	var got := []
	for n in range(31, 42):
		Siege.plan(s, s.siege, n)
		got.append(s.siege.mutators.size())
	var mk: int = s.siege.queue[-1].mk
	return ensure(got[0] == 1 and got[4] == 1 and got[5] == 2 and got[10] == 3, "mutators by wave: %s" % [got]) or ensure(mk == 3, "endless bots are Mk 3")


func test_plated_mutator_gives_bots_more_armor() -> int:
	var s := lab()
	s.siege.mutators = ["plated"]
	var e := Siege.spawn(s, "scout", 0, 0.0)
	return ensure(e.max == floor(Siege.BOTS.scout.hp * Siege.MUTATE.hp), "plated scout has %d" % e.max)


func camp_bots(s: Dictionary, q: int, i: int) -> Array:
	var id: int = q * S.CAMPS.size() + i
	return s.siege.enemies.filter(func(e): return e.camp == id and e.act != "die")


func test_yards_open_through_the_arch_not_the_lane_wall() -> int:
	var s := lab()
	park(s, 2, -49)
	var east := idle()
	east.mx = 1.0
	steps(s, 90, east)
	var walled: float = s.mechs[0].x
	park(s, 14, -14)
	var out := idle()
	out.mx = Sim.Q
	out.my = -Sim.Q
	steps(s, 150, out)
	var me: Dictionary = s.mechs[0]
	return ensure(walled < S.LANE_W / 2.0, "the lane wall stops you at x %.1f" % walled) or ensure(Sim.hypot(me.x, me.y) > S.YARD_IN + 2.0, "the arch lets you into the yard (r %.1f)" % Sim.hypot(me.x, me.y))


func walk(s: Dictionary, to: Dictionary, most: int) -> int:
	var me: Dictionary = s.mechs[0]
	for i in most:
		var dx: float = to.x - me.x
		var dy: float = to.y - me.y
		var d := Sim.hypot(dx, dy)
		if d < 1.0:
			return i
		var inp := idle()
		inp.mx = dx / d
		inp.my = dy / d
		Siege.step(s, [inp])
	return -1


func test_every_yard_opening_leads_onto_its_lane_and_back() -> int:
	var s := lab()
	var bad := []
	for q in S.QUADS.size():
		for d in S.doors(q):
			var half: float = S.OPENINGS.filter(func(o): return o.d == d.d)[0].half
			for shift in [0.0, -(half - 1.5), half - 1.5]:
				var off: Vector2 = Vector2(S.QUADS[q].sx, S.QUADS[q].sy) * shift
				var from: Dictionary = d.yp
				var vert: bool = d.lane % 2 == 0
				park(s, from.x + (0.0 if vert else off.x), from.y + (off.y if vert else 0.0))
				var there := walk(s, d.lp, 120)
				var lane_ok: bool = Siege.in_lane(s.mechs[0]) and Siege.lane_near(s.mechs[0]) == d.lane
				var back := walk(s, d.yp, 120)
				if there < 0 or not lane_ok or back < 0:
					bad.append("%s lane %d d %.0f shift %.1f (%d, %s, %d)" % [S.QUADS[q].name, d.lane, d.d, shift, there, lane_ok, back])
	return ensure(bad.is_empty(), "stuck at " + str(bad))


func test_lane_bots_ignore_a_player_in_the_yard() -> int:
	var s := lab()
	var d: Dictionary = S.doors(0).filter(func(x): return x.lane == 0)[0]
	park(s, d.yp.x, d.yp.y)
	var e := Siege.spawn(s, "scout", 0, 0.0, 1, S.at(0, d.d, 0.0))
	steps(s, 90)
	return ensure(not Siege.in_yard(e), "the scout stayed in its lane at (%.1f, %.1f)" % [e.x, e.y]) or ensure(s.mechs[0].armor.larm == s.mechs[0].max.larm, "it never shot the yard")


func trace(from: Dictionary, goal: Dictionary, most: int) -> Dictionary:
	var m := {"x": from.x, "y": from.y}
	var doors := 0
	for i in most:
		if Siege.dist(m, goal) < 1.5:
			return {"steps": i, "doors": doors}
		var wp := Siege.waypoint(m, goal)
		var dx: float = wp.x - m.x
		var dy: float = wp.y - m.y
		var n := maxf(0.01, Sim.hypot(dx, dy))
		m.x += dx / n * minf(0.5, n)
		m.y += dy / n * minf(0.5, n)
		if Siege.in_lane(m) and minf(absf(m.x), absf(m.y)) > S.LANE_W / 2.0 and Sim.hypot(m.x, m.y) > S.YARD_IN + 4.0:
			doors += 1
	return {"steps": -1, "doors": doors}


func test_the_farming_ally_crosses_between_yards_through_the_openings() -> int:
	var next := trace(S.yard_at(0, 40.0, 14.0), S.yard_at(1, 30.0, 14.0), 600)
	var lane := trace(S.at(1, 60.0, 0.0), S.yard_at(1, 30.0, 40.0), 600)
	var far := trace(S.yard_at(0, 40.0, 40.0), S.yard_at(2, 40.0, 40.0), 1200)
	return ensure(next.steps > 0 and next.doors > 0, "next-door yard through an opening %s" % str(next)) or ensure(lane.steps > 0 and lane.doors > 0, "from the lane into the yard %s" % str(lane)) or ensure(far.steps > 0, "the opposite yard is still reachable %s" % str(far))


func test_a_raid_leaves_a_yard_through_the_nearest_opening() -> int:
	var s := lab()
	var q := 0
	for c in s.siege.yards[q].camps:
		c.alive = false
	var at := S.yard_at(q, 44.0, 14.0)
	var e := Siege.spawn(s, "scout", q, 0.0, 1, at)
	e.raid = q
	e.leg = 1
	var t := until(s, 60 * 20, func(): return e.leg == 3)
	steps(s, 60)
	return ensure(t > 0, "the raid reached its lane") or ensure(e.get("door", -1) >= 0, "it chose an opening") or ensure(Siege.in_lane(e) and Siege.lane_near(e) == e.lane, "it walks lane %d at (%.1f, %.1f)" % [e.lane, e.x, e.y])


func test_camp_sleeps_until_a_player_comes_close_then_all_of_it_wakes() -> int:
	var s := lab()
	var c: Dictionary = s.siege.yards[0].camps[1]
	park(s, c.x - 20.0, c.y)
	steps(s, 60)
	var asleep := camp_bots(s, 0, 1).all(func(e): return e.act == "dormant")
	park(s, c.x - 6.0, c.y)
	steps(s, 5)
	var woke := camp_bots(s, 0, 1).all(func(e): return e.act != "dormant")
	return ensure(camp_bots(s, 0, 1).size() == 3, "turret + 2 spiders") or ensure(asleep, "asleep while you are far") or ensure(woke, "the whole camp wakes")


func test_camp_bot_goes_home_past_its_leash_and_heals() -> int:
	var s := lab()
	var c: Dictionary = s.siege.yards[0].camps[2]
	var e: Dictionary = camp_bots(s, 0, 2)[0]
	var b: Dictionary = s.mechs[e.m]
	park(s, c.x - 5.0, c.y)
	steps(s, 60)
	b.armor.head = b.max.head * 0.5
	park(s, 0, 6)
	var t := until(s, 60 * 20, func(): return e.act == "dormant")
	return ensure(t > 0, "it went back to sleep") or ensure(b.armor.head == b.max.head, "healed at home") or ensure(Sim.hypot(b.x - e.home.x, b.y - e.home.y) < 1.0, "at home")


func test_clearing_a_camp_pays_the_player_who_killed_it() -> int:
	var s := Siege.create([{}, {}], 3)
	s.siege.wave.next_in = 999999
	s.siege.wallets = [0, 0]
	var c: Dictionary = s.siege.yards[1].camps[0]
	var bots := camp_bots(s, 1, 0)
	for e in bots:
		s.mechs[e.m].by = 1
		s.mechs[e.m].armor.head = 0
	Siege.step(s, [idle(), idle()])
	return ensure(s.siege.wallets == [0, S.CAMP_TIERS.small.scrap], "wallets %s" % [s.siege.wallets]) or ensure(not c.alive, "camp cleared")


func test_a_camp_nobody_killed_pays_nobody() -> int:
	var s := lab()
	var c: Dictionary = s.siege.yards[1].camps[0]
	for e in camp_bots(s, 1, 0):
		s.mechs[e.m].armor.head = 0
	steps(s, 2)
	return ensure(s.siege.wallets[0] == 0, "wallet %d" % s.siege.wallets[0]) or ensure(not c.alive, "camp cleared")


func test_elite_pays_a_reinforce_token() -> int:
	var s := lab()
	var c: Dictionary = s.siege.yards[2].camps[3]
	park(s, c.x - 4.0, c.y)
	for e in camp_bots(s, 2, 3):
		s.mechs[e.m].by = 0
		s.mechs[e.m].armor.head = 0
	steps(s, 2)
	return ensure(s.siege.wallets[0] == S.CAMP_TIERS.elite.scrap and s.siege.tokens[0] == 1, "120 scrap and a token")


func test_crate_takes_three_still_seconds_and_resets_if_you_move() -> int:
	var s := lab()
	var cr: Dictionary = s.siege.yards[0].crates[0]
	park(s, cr.x + 1.0, cr.y)
	var hold := idle()
	hold.use = true
	steps(s, 60, hold)
	var half: float = cr.progress
	steps(s, 1)
	var dropped: float = cr.progress
	steps(s, S.CRATE.secs * 60 + 2, hold)
	return ensure(half > 0.3 and dropped == 0.0, "letting go resets (%.2f, %.2f)" % [half, dropped]) or ensure(cr.taken and s.siege.wallets[0] == S.CRATE.scrap, "opened: wallet %d" % s.siege.wallets[0])


func test_camps_and_crates_refill_each_wave_the_elite_every_five() -> int:
	var s := lab()
	var y: Dictionary = s.siege.yards[0]
	for e in camp_bots(s, 0, 0) + camp_bots(s, 0, 3):
		s.mechs[e.m].armor.head = 0
	y.crates[0].taken = true
	steps(s, 2)
	Siege.refill(s, s.siege, 2)
	var small: bool = y.camps[0].alive
	var elite: bool = y.camps[3].alive
	Siege.refill(s, s.siege, 6)
	return ensure(small and not y.crates[0].taken, "small camp and crate back next wave") or ensure(not elite, "no elite at wave 2") or ensure(y.camps[3].alive, "elite back at wave 6")


func test_raids_from_wave_15_wipe_camps_and_pay_nothing() -> int:
	var s := lab()
	Siege.plan(s, s.siege, 15)
	var raid: Array = s.siege.queue.filter(func(q): return q.get("raid", -1) >= 0)
	var q: int = raid[0].raid
	for u in raid:
		Siege.spawn(s, u.kind, u.lane, u.side, 1, S.yard_at(q, Siege.YARD.raidAt[0], Siege.YARD.raidAt[1] + u.side))
	for r in s.siege.enemies:
		if not r.neutral and r.camp < 0:
			r.raid = q
	s.siege.queue.clear()
	var y: Dictionary = s.siege.yards[q]
	var t := until(s, 60 * 40, func(): return y.camps.filter(func(c): return not c.alive).size() >= 2)
	return ensure(not raid.is_empty(), "wave 15 has a raid") or ensure(t > 0, "the raid wiped camps") or ensure(s.siege.wallets[0] == 0, "nobody got paid")


func test_wallet_upgrade_reinforce_and_revive() -> int:
	var s := Siege.create([{}, {}], 3)
	s.siege.wave.next_in = 999999
	var me: Dictionary = s.mechs[0]
	s.siege.wallets[0] = 1000
	var cd0: float = Sim.weapon(me, "left").cd
	var up := Siege.buy(s, s.siege, "tier:left", me)
	var head0: float = me.max.head
	var tough := Siege.buy(s, s.siege, "reinforce", me)
	s.mechs[1].armor.head = 0
	steps2(s, 2)
	var rev := Siege.buy(s, s.siege, "revive", me)
	steps2(s, 2)
	return ensure(up and s.siege.tiers[0].left == 1 and Sim.weapon(me, "left").cd < cd0, "the left hand went up a tier") or ensure(tough and me.max.head == head0 + floor(head0 * 0.15), "max head %d" % me.max.head) or ensure(rev and not s.mechs[1].ko, "the ally is back")


func steps2(s: Dictionary, n: int) -> void:
	for i in n:
		Siege.step(s, [idle(), idle()])


func test_wallet_buys_only_in_the_plaza() -> int:
	var s := lab()
	var me: Dictionary = s.mechs[0]
	s.siege.wallets[0] = 100
	me.armor.larm = 10.0
	var far := Siege.buy(s, s.siege, "kit", me)
	park(s, 0, 6)
	var near := Siege.buy(s, s.siege, "kit", me)
	return ensure(not far, "no repair out on the ring road") or ensure(near and me.armor.larm == me.max.larm, "repair in the plaza")


func test_steam_hides_a_mech() -> int:
	var s := lab()
	var st: Dictionary = s.geo.steam[0]
	park(s, st.x, st.y)
	var hid := Sim.hidden(s, s.mechs[0])
	park(s, st.x + st.r + 1.0, st.y)
	return ensure(hid, "inside the steam you are hidden") or ensure(not Sim.hidden(s, s.mechs[0]), "outside you are not")


func test_crush_plate_hits_bots_too() -> int:
	var s := lab()
	var h: Dictionary = S.YARD_HAZARDS[0]
	var p := S.yard_at(0, h.a, h.b)
	var e := Siege.spawn(s, "walker", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	for i in Siege.YARD.crush.every + 2:
		b.x = p.x
		b.y = p.y
		b.vx = 0.0
		b.vy = 0.0
		Siege.step(s, [idle()])
	return ensure(b.armor.head < b.max.head, "the plate crushed the walker")


func guard_of(s: Dictionary) -> Dictionary:
	return s.mechs[s.siege.guard]


func test_garrison_costs_the_fund_and_stands_at_its_dock() -> int:
	var s := lab()
	s.siege.wallets[0] = 1000
	var absent: bool = guard_of(s).ko
	var ok := Siege.buy(s, s.siege, "garrison", s.mechs[0])
	steps(s, 1)
	var g := guard_of(s)
	return ensure(absent, "no garrison before you buy it") or ensure(ok and s.siege.garrison.tier == 1 and s.siege.wallets[0] == 1000 - Siege.GARRISON.cost[0], "tier 1 for %d" % Siege.GARRISON.cost[0]) or ensure(not g.ko and Sim.hypot(g.x - S.GARRISON_DOCK.x, g.y - S.GARRISON_DOCK.y) < 1.0, "it stands at the dock")


func test_each_garrison_tier_swaps_parts_up() -> int:
	var s := lab()
	s.siege.wallets[0] = 100000
	var seen := []
	for t in 5:
		Siege.buy(s, s.siege, "garrison", s.mechs[0])
		seen.append(guard_of(s).loadout.duplicate(true))
	var more := Siege.buy(s, s.siege, "garrison", s.mechs[0])
	return ensure(seen[0].right == "bash" and seen[2].right == "gatling", "a second gun at tier 3") or ensure(seen[3].core == "reactor" and seen[4].core == "aegis", "R skill cores at tiers 4 and 5") or ensure(seen[0].get("lv", {}).get("head", 1) == 1 and seen[4].lv.head == 3, "parts level up") or ensure(not more, "tier 5 is the top")


func test_garrison_holds_its_leash_and_shoots_what_comes_in() -> int:
	var s := lab()
	s.siege.wallets[0] = 1000
	Siege.buy(s, s.siege, "garrison", s.mechs[0])
	var far := Siege.spawn(s, "turret", 0, 0.0)
	var fb: Dictionary = s.mechs[far.m]
	var most := 0.0
	for i in 300:
		fb.x = 0.0
		fb.y = -50.0
		Siege.step(s, [idle()])
		most = maxf(most, Sim.hypot(guard_of(s).x, guard_of(s).y))
	var near := Siege.spawn(s, "scout", 0, 0.0)
	var nb: Dictionary = s.mechs[near.m]
	var t := until(s, 60 * 10, func():
		nb.x = 4.0
		nb.y = 4.0
		return near.act == "die")
	return ensure(most <= Siege.GARRISON.leash + 1.0, "stayed within %.1f m" % most) or ensure(t > 0, "it killed the scout in the plaza")


func test_garrison_rebuilds_for_free_after_its_timer() -> int:
	var s := lab()
	s.siege.wallets[0] = 1000
	Siege.buy(s, s.siege, "garrison", s.mechs[0])
	var fund: int = s.siege.wallets[0]
	guard_of(s).armor.head = 0
	steps(s, 2)
	var down: bool = guard_of(s).ko
	steps(s, Siege.GARRISON.respawn + 2)
	return ensure(down, "it went down") or ensure(not guard_of(s).ko and guard_of(s).armor.head == guard_of(s).max.head, "back up at full armor") or ensure(s.siege.wallets[0] == fund, "no scrap spent")


func lonely_guard_run(wave: int) -> Dictionary:
	var s := Siege.create([{}], 21)
	var me: Dictionary = s.mechs[0]
	me.ko = true
	s.siege.down[0] = 1 << 30
	s.siege.wallets[0] = 100000
	for t in 5:
		Siege.buy(s, s.siege, "garrison", me)
	s.siege.wallets[0] = 0
	s.siege.wave.n = wave - 1
	s.siege.wave.next_in = Siege.RUN.warn + 2
	var stop := 60 * 60 * 6
	for i in stop:
		Siege.step(s, [idle()])
		if s.phase == "over":
			break
	return s


func test_a_full_garrison_alone_still_loses_wave_15() -> int:
	var s := lonely_guard_run(15)
	return ensure(s.siege.lost, "lost at wave %d" % s.siege.wave.n)


func test_a_full_garrison_alone_still_loses_wave_25() -> int:
	var s := lonely_guard_run(25)
	return ensure(s.siege.lost, "lost at wave %d" % s.siege.wave.n)


func test_a_run_starts_with_a_small_wallet() -> int:
	var s := Siege.create([{}, {}], 3)
	return ensure(s.siege.wallets == [Siege.TIER.wallet, Siege.TIER.wallet], "wallets %s" % [s.siege.wallets])


func test_tier_prices_grow_with_the_square_and_raise_hand_damage() -> int:
	var s := lab()
	park(s, 0, 6)
	var me: Dictionary = s.mechs[0]
	s.siege.wallets[0] = 10000
	var dmg0: float = Sim.weapon(me, "left").dmg
	var p1 := Siege.price_of(s.siege, me, "tier:left")
	Siege.buy(s, s.siege, "tier:left", me)
	var p2 := Siege.price_of(s.siege, me, "tier:left")
	for t in 4:
		Siege.buy(s, s.siege, "tier:left", me)
	var top := Siege.price_of(s.siege, me, "tier:left")
	return ensure(p1 == Siege.TIER.base.left and p2 == Siege.TIER.base.left * 4, "prices %d, %d" % [p1, p2]) or ensure(top < 0 and s.siege.tiers[0].left == 5, "tier 5 is the top") or ensure(is_equal_approx(Sim.weapon(me, "left").dmg, dmg0 * (1 + 5 * Siege.TIER.hand.dmg)), "damage %.1f" % Sim.weapon(me, "left").dmg)


func test_plating_tiers_raise_max_armor_and_survive_a_respawn() -> int:
	var s := lab()
	park(s, 0, 6)
	var me: Dictionary = s.mechs[0]
	var head0: float = me.max.head
	s.siege.wallets[0] = 10000
	Siege.buy(s, s.siege, "tier:head", me)
	Siege.buy(s, s.siege, "tier:head", me)
	var head2: float = me.max.head
	me.armor.head = 0
	steps(s, Siege.RUN.respawn + 4)
	return ensure(head2 == floor(head0 * (1 + 2 * Siege.TIER.head.armor)), "head %d" % head2) or ensure(s.mechs[0].max.head == head2, "kept after respawn")


func test_swapping_needs_an_owned_part_and_costs_by_series() -> int:
	var s := lab()
	park(s, 0, 6)
	var me: Dictionary = s.mechs[0]
	s.siege.wallets[0] = 1000
	s.siege.owned[0] = {"legs": {"greaves": 1, "treads": 2}, "left": {"rivet": 1}}
	var locked := Siege.buy(s, s.siege, "swap:legs:hover", me)
	var price := Siege.price_of(s.siege, me, "swap:legs:treads")
	var ok := Siege.buy(s, s.siege, "swap:legs:treads", me)
	return ensure(not locked, "a part you don't own stays locked") or ensure(price == Siege.SWAP.heavy, "treads are heavy: %d" % price) or ensure(ok and me.loadout.legs == "treads" and me.loadout.lv.legs == 2, "treads equipped at their level")


func test_heal_buys_fix_armor_heat_and_surge() -> int:
	var s := lab()
	park(s, 0, 6)
	var me: Dictionary = s.mechs[0]
	s.siege.wallets[0] = 1000
	me.armor.larm = 10.0
	me.heat = 90.0
	me.surge = 0.0
	var a := Siege.buy(s, s.siege, "kit", me)
	var b := Siege.buy(s, s.siege, "coolant", me)
	var c := Siege.buy(s, s.siege, "surge", me)
	return ensure(a and me.armor.larm == me.max.larm, "kit") or ensure(b and me.heat == 0.0, "coolant") or ensure(c and me.surge == Siege.TIER.surge, "surge cell")


func test_recall_takes_three_seconds_and_damage_breaks_it() -> int:
	var s := lab()
	park(s, 0, -40)
	var hold := idle()
	hold.recall = true
	steps(s, 60, hold)
	s.mechs[0].armor.larm -= 10
	steps(s, 2, hold)
	var broken: bool = s.siege.recall.is_empty() and Sim.hypot(s.mechs[0].x, s.mechs[0].y) > 30
	steps(s, 40)
	steps(s, S.RECALL.secs * 60 + 2, hold)
	var me: Dictionary = s.mechs[0]
	return ensure(broken, "a hit stops the recall") or ensure(Sim.hypot(me.x, me.y) < 8.0, "back at the core") or ensure(s.siege.recall_cd[0] > 0, "on cooldown")


func test_a_lane_kill_pays_only_the_killer() -> int:
	var s := Siege.create([{}, {}], 3)
	s.siege.wave.next_in = 999999
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	var w0: int = s.siege.wallets[0]
	Sim.hit(s, s.mechs[1], b, 9999.0, "HEAD", 0, 0.0, Sim.next_cast(s))
	Siege.step(s, [idle(), idle()])
	var gain: int = Siege.BOTS.scout.cost * Siege.RUN.scrap
	return ensure(s.siege.wallets[1] == w0 + gain, "the killer got %d, wallet %d" % [gain, s.siege.wallets[1]]) or ensure(s.siege.wallets[0] == w0, "the other player got nothing")


func test_a_hazard_kill_pays_nobody() -> int:
	var s := Siege.create([{}, {}], 3)
	s.siege.wave.next_in = 999999
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	Sim.hit(s, s.mechs[1], b, 1.0, "HEAD", 0, 0.0, Sim.next_cast(s))
	Siege.unowned(b)
	b.armor.head = 0
	Siege.step(s, [idle(), idle()])
	return ensure(s.siege.wallets == [Siege.TIER.wallet, Siege.TIER.wallet], "wallets %s" % [s.siege.wallets])


func test_a_module_kill_pays_the_player_who_built_it() -> int:
	var s := Siege.create([{}, {}], 3)
	s.siege.wave.next_in = 999999
	var pd: Dictionary = s.siege.pads[1]
	s.mechs[1].x = pd.x + 0.5
	s.mechs[1].y = pd.y
	s.siege.wallets = [0, Siege.SHOP.turret]
	var ok := Siege.buy(s, s.siege, "turret", s.mechs[1])
	s.mechs[1].x = -15.0
	s.mechs[1].y = 15.0
	s.siege.wallets = [0, 0]
	s.siege.wave.live = true
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	b.x = pd.x
	b.y = pd.y - Siege.MODULE.turret.range * 0.7
	var t := 0
	for i in 60 * 10:
		Siege.step(s, [idle(), idle()])
		b.x = pd.x if e.act != "die" else b.x
		if e.act == "die":
			t = i
			break
	return ensure(ok and pd.owner == 1, "player 1 built the turret") or ensure(t > 0, "the turret killed the scout") or ensure(s.siege.wallets[1] - s.siege.wallets[0] == Siege.BOTS.scout.cost * Siege.RUN.scrap, "the builder was paid: %s" % [s.siege.wallets])


func test_a_garrison_kill_pays_whoever_bought_its_tier() -> int:
	var s := Siege.create([{}, {}], 3)
	s.siege.wave.next_in = 999999
	s.siege.wallets = [0, 2000]
	var ok := Siege.buy(s, s.siege, "garrison", s.mechs[1])
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	Sim.hit(s, s.mechs[s.siege.guard], b, 9999.0, "HEAD", 0, 0.0, Sim.next_cast(s))
	var before: int = s.siege.wallets[1]
	Siege.step(s, [idle(), idle()])
	return ensure(ok and s.siege.garrison.buyer == 1, "player 1 bought tier 1") or ensure(s.siege.wallets[1] == before + Siege.BOTS.scout.cost * Siege.RUN.scrap and s.siege.wallets[0] == 0, "wallets %s" % [s.siege.wallets])


func test_a_build_phase_buy_on_the_first_pad_works_with_the_starting_wallet() -> int:
	var s := Siege.create([{}], 3)
	var pd: Dictionary = s.siege.pads[0]
	park(s, pd.x, pd.y)
	steps(s, 1)
	var wall := Siege.buy(s, s.siege, "wall", s.mechs[0])
	return ensure(not s.siege.wave.live, "still the build phase") or ensure(wall and pd.module == "wall" and pd.owner == 0, "the barricade stands on pad 0") or ensure(s.siege.wallets[0] == Siege.TIER.wallet - Siege.SHOP.wall, "paid from the wallet, left %d" % s.siege.wallets[0])


func test_ai_teammate_spends_its_wallet_in_the_plaza_between_waves() -> int:
	var s := Siege.create([{}, {}], 3)
	s.siege.wave.next_in = 999999
	s.siege.wallets[1] = 400
	var brain := Bot.create_brain(5)
	for i in 600:
		Siege.step(s, [idle(), Siege.ally_input(s, brain, 1)])
	var t := 0
	for slot in S.PART_SLOTS:
		t += s.siege.tiers[1][slot]
	return ensure(t >= 2 and s.siege.tiers[1].left >= 1, "it bought tiers: %s" % [s.siege.tiers[1]])


func hits(kind: String, gun: String) -> int:
	return int(ceil(Siege.BOTS[kind].hp / float(Sim.WEAPONS[gun].dmg)))


func test_default_weapon_kills_scouts_swarms_and_spiders_in_three_hits() -> int:
	var d: String = Sim.DEFAULT_LOADOUT.left
	print("  hits with %s: scout %d, swarm %d, spider %d, walker %d" % [d, hits("scout", d), hits("swarm", d), hits("spider", d), hits("walker", d)])
	return ensure(hits("scout", d) <= 3 and hits("swarm", d) <= 3 and hits("spider", d) <= 3, "3 hits or fewer")


func sample(s: Dictionary, k: int) -> float:
	s.siege.tick = k * Siege.DIRECTOR.every
	Siege.sense(s, s.siege)
	return s.siege.director.pressure


func test_pressure_is_zero_when_calm_and_rises_with_core_loss_and_downed_mechs() -> int:
	var s := Siege.create([{}, {}], 3)
	s.siege.wave.live = true
	var calm := sample(s, 1)
	for k in range(2, 7):
		s.siege.core.hp -= s.siege.core.max * 0.01
		sample(s, k)
	var bleeding: float = s.siege.director.pressure
	var t := Siege.create([{}, {}], 3)
	t.siege.wave.live = true
	for m in t.mechs.slice(0, 2):
		m.ko = true
	var down := sample(t, 1)
	return ensure(calm == 0.0, "calm samples %f" % calm) or ensure(bleeding >= 30.0, "core -5%% in 5 s samples %f" % bleeding) or ensure(down >= 20.0, "all down samples %f" % down)


func scored(s: Dictionary, n: int, samples: Array) -> float:
	var dr: Dictionary = s.siege.director
	dr.sum = 0.0
	dr.samples = samples.size()
	for p in samples:
		dr.sum += p
	Siege.score(s.siege, n, -1)
	return dr.strain


func test_one_spike_barely_moves_strain_and_no_wave_moves_it_past_15() -> int:
	var s := lab()
	var calm := []
	calm.resize(30)
	calm.fill(40.0)
	scored(s, 1, calm)
	var before := scored(s, 2, calm)
	var spiked := calm.duplicate()
	spiked[10] = 100.0
	var after := scored(s, 3, spiked)
	var hot := []
	hot.resize(30)
	hot.fill(100.0)
	var jump := scored(s, 4, hot)
	return ensure(absf(after - before) < 5.0, "one spike moved S by %f" % (after - before)) or ensure(jump - after <= 15.0 + 0.001, "a hot wave moved S by %f" % (jump - after))


func test_breathers_plan_less_go_straight_and_rest_15_s_longer() -> int:
	var fails := []
	for n in [4, 9, 14]:
		var s := Siege.create([{}], 9 + n)
		Siege.plan(s, s.siege, n)
		var row: Dictionary = s.siege.director.log[n]
		if absf(row.budget - snappedf(Siege.budget(n, 1) * 0.7, 0.1)) > 0.11 or row.tactic != "straight":
			fails.append("wave %d: %s" % [n, row])
	for n in [3, 4]:
		var s := Siege.create([{}], 1)
		s.siege.wave.n = n
		s.siege.wave.live = true
		s.siege.wave.next_in = Siege.RUN.cap - 60
		Siege.direct(s, s.siege)
		var want: int = Siege.RUN.build + (Siege.DIRECTOR.rest if n == 4 else 0)
		if s.siege.wave.next_in != want:
			fails.append("after wave %d the build phase is %d, not %d" % [n, s.siege.wave.next_in, want])
	for f in fails:
		print("  " + f)
	return ensure(fails.is_empty(), "breathers")


func at_spawn_spot(e: Dictionary) -> bool:
	var far: bool = maxf(absf(e.x), absf(e.y)) >= 70.0
	var vent: bool = absf(Sim.hypot(e.x, e.y) - S.VENTS[0]) <= 3.0 and Siege.BOTS[e.kind].get("vent", false)
	return far or vent


func test_every_tactic_warns_each_group_and_spawns_only_at_mouths_vents_and_corners() -> int:
	var fails := []
	var waves := {"probe": 5, "ambush": 5, "pincer": 6, "airdrop": 7, "feint": 8, "siege": 12, "hammer": 21}
	for id in waves:
		var n: int = waves[id]
		var s := Siege.create([{}, {}], 4)
		s.siege.director.force = id
		s.siege.wave.n = n - 1
		s.siege.wave.next_in = Siege.RUN.warn + 1
		var warns := {}
		var seen := {}
		var called := false
		var queued := []
		var start := 0
		for k in 60 * 50:
			Siege.step(s, [idle(), idle()])
			if k == 0:
				queued = s.siege.queue.filter(func(q): return q.has("kind") and not q.has("raid"))
				start = s.tick + Siege.RUN.warn
			for f in s.fx:
				if f.k == "warn" and f.t == Siege.RUN.warn:
					warns[s.tick] = true
				if f.k == "tactic" and f.id == id:
					called = true
			for e in wave_bots(s):
				if not seen.has(e.id):
					seen[e.id] = true
					if e.raid < 0 and not at_spawn_spot(e):
						fails.append("%s: a %s spawned at (%d, %d)" % [id, e.kind, e.x, e.y])
					for m in s.mechs.slice(0, 2):
						if Sim.hypot(m.x - e.x, m.y - e.y) < Siege.DIRECTOR.near:
							fails.append("%s: a %s spawned next to a player" % [id, e.kind])
		var first := {}
		for q in queued:
			first[q.w] = mini(first.get(q.w, 1 << 30), q.at)
		for w in first:
			if not warns.has(w):
				fails.append("%s: no warning at tick %d" % [id, w])
			elif first[w] - w != Siege.RUN.warn:
				fails.append("%s: warned %d ticks ahead" % [id, first[w] - w])
		if not called:
			fails.append("%s: never announced" % id)
		if id != "pincer" and first.values().filter(func(t): return t > start).is_empty():
			fails.append("%s: no group comes late" % id)
	for f in fails:
		print("  " + f)
	return ensure(fails.is_empty(), "every tactic is fair")


func test_spawns_wait_while_a_player_stands_on_the_spot() -> int:
	var s := lab()
	var p := S.at(0, S.SPAWN)
	park(s, p.x, p.y)
	s.siege.queue.append({"at": s.tick + 1, "kind": "scout", "lane": 0, "side": 0.0, "mk": 1})
	steps(s, 30, idle(Vector2(p.x, p.y)))
	var waited: bool = wave_bots(s).is_empty()
	park(s, 0, 0)
	steps(s, Siege.DIRECTOR.retry + 5)
	return ensure(waited, "no scout spawns on top of the player") or ensure(wave_bots(s).size() == 1, "it spawns once the player leaves")


func test_boss_waves_keep_their_must_list_and_mk_and_scrap_is_untouched() -> int:
	var fails := []
	for n in [10, 15, 20, 30]:
		for dial in [-1.0, 1.0]:
			var s := Siege.create([{}, {}], 9 + n)
			s.siege.director.dial = dial
			s.siege.director.top = dial > 0
			s.siege.director.pity = dial < 0
			s.siege.wallets[0] = 77
			Siege.plan(s, s.siege, n)
			var k := kinds_of(s.siege.queue)
			var need := {}
			for key in Siege.row(n).must:
				for u in Siege.SQUADS[key]:
					need[u[0]] = need.get(u[0], 0) + u[1]
			for kind in need:
				if k.get(kind, 0) < need[kind]:
					fails.append("wave %d dial %d lost its %s" % [n, dial, kind])
			for q in s.siege.queue:
				if q.has("kind") and q.mk > Siege.row(n).get("mk", 1):
					fails.append("wave %d dial %d has Mk %d" % [n, dial, q.mk])
			if s.siege.wallets != [77, Siege.TIER.wallet]:
				fails.append("wave %d dial %d touched scrap" % [n, dial])
	for f in fails:
		print("  " + f)
	return ensure(fails.is_empty(), "boss waves stay boss waves")


func test_waves_one_to_three_plan_the_same_with_the_director_on_and_off() -> int:
	var same := true
	for n in [1, 2, 3]:
		same = same and str(planned(n, 1, true)) == str(planned(n, 1, false))
	return ensure(same, "waves 1-3 are the same")


func test_two_easy_waves_raise_the_tier_and_two_hard_waves_give_one_pity_wave() -> int:
	var s := Siege.create([{}, {}], 8)
	var dr: Dictionary = s.siege.director
	for n in [4, 5]:
		scored(s, n, [0.0])
	var top: bool = dr.top
	var raised: float = dr.dial
	var t := Siege.create([{}, {}], 8)
	for n in [6, 7]:
		scored(t, n, [100.0])
	var pity: bool = t.siege.director.pity
	Siege.plan(t, t.siege, 8)
	var row: Dictionary = t.siege.director.log[8]
	var want := snappedf(Siege.budget(8, 2) * Siege.beat(8).mult * (1.0 - Siege.DIRECTOR.budget), 0.1)
	return ensure(top and raised > 0.0, "easy waves raise the dial (%f) and the tier" % raised) or ensure(pity, "two hard waves ask for pity") or ensure(row.tactic == "straight" and absf(row.budget - want) < 0.11, "the pity wave is plain and 15%% smaller: %s" % [row]) or ensure(not t.siege.director.pity, "pity lasts one wave")


func test_square_wheel_builds_on_the_pad_in_reach() -> int:
	var s := shop()
	var pd := on_pad(s, 1, 2)
	var kind := Siege.where(s.siege, s.mechs[0])
	var ok := Siege.buy(s, s.siege, "turret", s.mechs[0])
	var taken := Siege.buy(s, s.siege, "mine", s.mechs[0])
	var built: Array = s.siege.pads.filter(func(p): return p.module != "")
	park(s, -15, 15)
	var away := Siege.buy(s, s.siege, "wall", s.mechs[0])
	return ensure(kind == "square", "standing on a lane pad opens the square wheel, got %s" % kind) or ensure(ok and built == [pd] and pd.module == "turret", "built on that pad only") or ensure(not taken, "an occupied pad takes nothing else") or ensure(not away, "nothing is built away from the pads") or ensure(s.siege.wallets[0] == 1000 - Siege.SHOP.turret, "paid once, got %d" % (1000 - s.siege.wallets[0]))


func test_gate_wheel_fixes_the_gate_you_stand_at() -> int:
	var s := shop()
	var gs: Array = s.siege.gates
	gs[0].hp = 100.0
	gs[1].hp = 300.0
	gs[2].hp = 0.0
	park(s, gs[1].x, gs[1].y)
	var kind := Siege.where(s.siege, s.mechs[0])
	var fixed := Siege.buy(s, s.siege, "gate", s.mechs[0])
	var alive := Siege.buy(s, s.siege, "rebuild", s.mechs[0])
	park(s, gs[2].x, gs[2].y)
	var gone := Siege.buy(s, s.siege, "gate", s.mechs[0])
	var rebuilt := Siege.buy(s, s.siege, "rebuild", s.mechs[0])
	park(s, -15, 15)
	var away := Siege.buy(s, s.siege, "gate", s.mechs[0])
	return ensure(kind == "gate", "standing at a gate opens the gate wheel") or ensure(fixed and gs[1].hp == 300.0 + gs[1].max * 0.2, "this gate got +20%") or ensure(gs[0].hp == 100.0, "the worst gate was not the one fixed") or ensure(not alive, "a standing gate cannot be rebuilt") or ensure(not gone, "a dead gate cannot be repaired") or ensure(rebuilt and gs[2].hp == gs[2].max * 0.5, "rebuilt at 50%") or ensure(not away, "no gate fixes away from a gate")


func test_plaza_sells_no_modules_or_gate_fixes() -> int:
	var s := shop()
	park(s, 5, 5)
	s.siege.gates[3].hp = 100.0
	var kind := Siege.where(s.siege, s.mechs[0])
	var wall := Siege.buy(s, s.siege, "wall", s.mechs[0])
	var gate := Siege.buy(s, s.siege, "gate", s.mechs[0])
	return ensure(kind == "plaza", "the middle is the plaza") or ensure(Siege.WHEEL.plaza == ["ring", "garrison"], "the team wedge sells a core ring and a garrison only") or ensure(not wall and not gate, "no module or gate fix is sold in the plaza") or ensure(s.siege.wallets[0] == 1000, "nothing was paid")


func test_auto_turret_kills_a_bot_in_range_and_bots_can_destroy_it() -> int:
	var s := shop()
	var pd := on_pad(s, 0, 1)
	var ok := Siege.buy(s, s.siege, "turret", s.mechs[0])
	park(s, -15, 15)
	s.siege.wave.live = true
	var e := Siege.spawn(s, "scout", 0, 0.0)
	var b: Dictionary = s.mechs[e.m]
	b.x = pd.x
	b.y = pd.y - Siege.MODULE.turret.range * 0.7
	var t := until(s, 60 * 10, func(): return e.act == "die")
	var far := Siege.spawn(s, "scout", 0, 0.0)
	var fb: Dictionary = s.mechs[far.m]
	fb.x = pd.x
	fb.y = pd.y - Siege.MODULE.turret.range - 6.0
	steps(s, 30)
	var untouched: bool = fb.armor.head == fb.max.head
	var heavies := []
	for i in 2:
		var h := Siege.spawn(s, "heavy", 0, (i - 0.5) * 3.0)
		s.mechs[h.m].x = pd.x + (i - 0.5) * 3.0
		s.mechs[h.m].y = pd.y - 14.0
		heavies.append(h)
	var gone := until(s, 60 * 60, func(): return pd.hp <= 0)
	s.siege.wave.live = false
	park(s, pd.x + 0.5, pd.y)
	var again := Siege.buy(s, s.siege, "turret", s.mechs[0])
	return ensure(ok and pd.module == "turret", "built") or ensure(t > 0, "the turret killed a scout in range") or ensure(untouched, "it ignores a bot out of range") or ensure(gone > 0, "heavies shelled it down") or ensure(again and pd.hp == pd.max, "a destroyed turret is rebuilt on its pad")
