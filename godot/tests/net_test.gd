extends SceneTree

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const NetInput = preload("res://src/net/net_input.gd")
const NetSession = preload("res://src/net/net_session.gd")
const NetFake = preload("res://src/net/net_fake.gd")
const NetEnet = preload("res://src/net/net_enet.gd")

const SEED := 0x2545f491
const PORT := 47311

var failed := 0
var filter := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--filter")
	if at >= 0 and at + 1 < args.size():
		filter = args[at + 1]
	run("input_survives_the_wire_in_nine_bytes", test_input_survives_the_wire_in_nine_bytes)
	run("lobby_fills_seats_then_starts", test_lobby_fills_seats_then_starts)
	run("lobby_refuses_a_player_when_full", test_lobby_refuses_a_player_when_full)
	run("two_peers_match_one_local_run", test_two_peers_match_one_local_run)
	run("four_peers_ffa_match_one_local_run", test_four_peers_ffa_match_one_local_run)
	run("two_vs_two_with_two_bots_matches_one_local_run", test_two_vs_two_with_two_bots_matches_one_local_run)
	run("two_peers_survive_delay_and_loss", test_two_peers_survive_delay_and_loss)
	run("four_peers_survive_delay_and_loss", test_four_peers_survive_delay_and_loss)
	run("same_network_same_result", test_same_network_same_result)
	run("a_client_that_leaves_becomes_a_bot", test_a_client_that_leaves_becomes_a_bot)
	run("a_client_that_goes_silent_becomes_a_bot", test_a_client_that_goes_silent_becomes_a_bot)
	run("clients_end_when_the_host_is_lost", test_clients_end_when_the_host_is_lost)
	run("a_forced_desync_is_detected", test_a_forced_desync_is_detected)
	run("enet_loopback_smoke", test_enet_loopback_smoke)
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


func scripted(seat: int, t: int) -> Dictionary:
	return {
		"mx": float(((t / 45 + seat) % 3) - 1), "my": float(((t / 70 + seat * 2) % 3) - 1),
		"ax": float(10 + (t * 3 + seat * 17) % 56), "ay": float(8 + (t * 2 + seat * 7) % 44),
		"left": (t + seat * 5) % 30 < 12, "right": (t + seat * 7) % 90 < 5, "hook": t % 250 == 100 + seat,
		"shield": (t / 50 + seat) % 4 == 0, "dash": t % 100 == seat * 3, "ult": t % 400 == 300 + seat,
	}


func loadouts_for(n: int) -> Array:
	var keys := Sim.SETS.keys()
	var out := []
	for i in n:
		out.append(Sim.SETS[keys[i % keys.size()]])
	return out


func reference(teams: Array, ticks: int, bots_from := {}) -> int:
	var s := Sim.create_state(loadouts_for(teams.size()), teams)
	s.seed = SEED
	var brains := {}
	for t in range(1, ticks + 1):
		var ins := []
		for seat in teams.size():
			if bots_from.has(seat) and t >= bots_from[seat]:
				if not brains.has(seat):
					brains[seat] = Bot.create_brain(NetSession.brain_seed(SEED, seat))
				ins.append(Bot.bot_input(s, brains[seat], seat))
			else:
				ins.append(NetInput.snap(scripted(seat, t)))
		Sim.step(s, ins)
	return Sim.hash_state(s)


func rig(teams: Array, humans: int, opt := {}) -> Dictionary:
	var hub := NetFake.new(opt.get("seed", 7), opt.get("lag", 0), opt.get("jitter", 0), opt.get("loss", 0.0))
	var los := loadouts_for(teams.size())
	var cfg := {"teams": teams, "loadouts": los, "local": [0], "bots": range(humans, teams.size()), "delay": opt.get("delay", 6), "hash_every": opt.get("hash_every", 30), "silence": opt.get("silence", 60), "seed": SEED}
	var host := NetSession.new(hub.join(1), true, cfg)
	var all := [host]
	for i in range(1, humans):
		all.append(NetSession.new(hub.join(i + 1), false, {}, los[i]))
	return {"hub": hub, "all": all, "ok": lobby(hub, all)}


func lobby(hub, all: Array) -> bool:
	for _i in 50:
		for s in all:
			s.poll()
		hub.advance()
	return all[0].begin() and settle(hub, all)


func settle(hub, all: Array) -> bool:
	for _i in 50:
		for s in all:
			s.poll()
		hub.advance()
	for s in all:
		if s.phase != "running":
			return false
	return true


## Plays rounds until every living session reached `ticks`. `each` runs after every round with the round number.
func play(r: Dictionary, ticks: int, each := Callable()) -> bool:
	for s in r.all:
		s.stop_at = ticks
	var round := 0
	while round < ticks * 40:
		var done := true
		for s in r.all:
			if s.phase == "running":
				s.pump(scripted)
				done = done and s.state.tick >= ticks
		r.hub.advance()
		round += 1
		if each.is_valid():
			each.call(round)
		if done:
			return true
	return false


func events_of(s, kind: String) -> Array:
	return s.events.filter(func(e): return e.k == kind)


func all_agree(sessions: Array, want: int) -> int:
	var bad := 0
	for s in sessions:
		bad += ensure(s.state.tick == s.stop_at, "peer reached tick %d (got %d)" % [s.stop_at, s.state.tick])
		bad += ensure(Sim.hash_state(s.state) == want, "peer ends on the reference hash")
		bad += ensure(s.desynced == -1, "no desync reported")
	return mini(bad, 1)


func test_input_survives_the_wire_in_nine_bytes() -> int:
	var inp := {"mx": -0.5, "my": 1.0, "ax": 37.25, "ay": 12.5, "left": true, "right": false, "hook": true, "shield": false, "dash": true, "ult": false}
	var b := NetInput.pack(inp)
	var back := NetInput.unpack(b)
	var bad := ensure(b.size() == 9, "nine bytes")
	for k in inp:
		bad += ensure(back[k] == inp[k], "%s survives (%s)" % [k, str(back[k])])
	var odd := NetInput.snap({"mx": 0.3333333, "ax": 10.123456})
	bad += ensure(NetInput.snap(odd) == odd, "snapping twice changes nothing")
	bad += ensure(NetInput.snap({})["left"] == false and NetInput.snap({})["ax"] == 0.0, "an empty input is idle")
	return mini(bad, 1)


func test_lobby_fills_seats_then_starts() -> int:
	var hub := NetFake.new()
	var cfg := {"teams": [0, 1, 0, 1], "loadouts": loadouts_for(4), "bots": [3], "seed": SEED}
	var host := NetSession.new(hub.join(1), true, cfg)
	var a := NetSession.new(hub.join(2), false, {}, loadouts_for(4)[1])
	var bad := ensure(not host.begin(), "cannot start with seats open")
	for _i in 10:
		host.poll()
		a.poll()
		hub.advance()
	bad += ensure(not host.begin(), "still one online seat open")
	var b := NetSession.new(hub.join(3), false, {}, loadouts_for(4)[2])
	for _i in 10:
		host.poll()
		a.poll()
		b.poll()
		hub.advance()
	bad += ensure(host.begin(), "starts once every online seat is filled")
	for _i in 10:
		a.poll()
		b.poll()
		hub.advance()
	bad += ensure(a.phase == "running" and b.phase == "running", "clients start too")
	bad += ensure(a.local == [1] and b.local == [2], "seats go out in order (%s %s)" % [str(a.local), str(b.local)])
	bad += ensure(a.state.mechs.size() == 4 and a.state.mechs[3].team == 1, "clients build the same 4 seat match")
	bad += ensure(a.bots == 8 and b.bots == 8, "seat 3 is a bot from the start")
	return mini(bad, 1)


func test_lobby_refuses_a_player_when_full() -> int:
	var hub := NetFake.new()
	var host := NetSession.new(hub.join(1), true, {"teams": [0, 1], "loadouts": loadouts_for(2)})
	var a := NetSession.new(hub.join(2), false, {}, loadouts_for(2)[1])
	var b := NetSession.new(hub.join(3), false, {}, loadouts_for(2)[0])
	for _i in 10:
		host.poll()
		a.poll()
		b.poll()
		hub.advance()
	var bad := ensure(events_of(a, "joined").size() == 1, "first client gets the seat")
	bad += ensure(events_of(b, "refused").size() == 1, "second client is told the match is full")
	bad += ensure(host.clients.size() == 1, "host keeps one client")
	return mini(bad, 1)


func test_two_peers_match_one_local_run() -> int:
	var r := rig(Sim.FORMATS["1v1"], 2)
	return ensure(r.ok, "lobby starts") or ensure(play(r, 1500), "both reach the end") or all_agree(r.all, reference(Sim.FORMATS["1v1"], 1500))


func test_four_peers_ffa_match_one_local_run() -> int:
	var r := rig(Sim.FORMATS["ffa"], 4)
	return ensure(r.ok, "lobby starts") or ensure(play(r, 1200), "all reach the end") or all_agree(r.all, reference(Sim.FORMATS["ffa"], 1200))


func test_two_vs_two_with_two_bots_matches_one_local_run() -> int:
	var teams: Array = Sim.FORMATS["2v2"]
	var r := rig(teams, 2)
	var bot_seats := {2: 1, 3: 1}
	return ensure(r.ok, "lobby starts") or ensure(play(r, 1000), "both reach the end") or all_agree(r.all, reference(teams, 1000, bot_seats))


func test_two_peers_survive_delay_and_loss() -> int:
	var r := rig(Sim.FORMATS["1v1"], 2, {"lag": 2, "jitter": 2, "loss": 0.1, "seed": 11})
	return ensure(r.ok, "lobby starts") or ensure(play(r, 1500), "both reach the end") or all_agree(r.all, reference(Sim.FORMATS["1v1"], 1500))


func test_four_peers_survive_delay_and_loss() -> int:
	var r := rig(Sim.FORMATS["ffa"], 4, {"lag": 2, "jitter": 2, "loss": 0.1, "seed": 5})
	return ensure(r.ok, "lobby starts") or ensure(play(r, 1200), "all reach the end") or all_agree(r.all, reference(Sim.FORMATS["ffa"], 1200))


func test_same_network_same_result() -> int:
	var hashes := []
	var rounds := []
	for _i in 2:
		var r := rig(Sim.FORMATS["ffa"], 3, {"lag": 3, "jitter": 3, "loss": 0.1, "seed": 99})
		var n := 0
		var count := func(_round): n += 1
		var ok := play(r, 600, count)
		hashes.append(Sim.hash_state(r.all[0].state) if ok else -1)
		rounds.append(n)
	return ensure(hashes[0] != -1 and hashes[0] == hashes[1], "two runs end on one hash") or ensure(rounds[0] == rounds[1], "and take the same number of rounds")


func test_a_client_that_leaves_becomes_a_bot() -> int:
	var teams: Array = Sim.FORMATS["ffa"]
	var r := rig(teams, 4, {"lag": 1})
	var cut := func(_round):
		if r.all[0].state.tick >= 400 and r.hub.ends.has(3):
			r.hub.cut(3)
	var bad := ensure(r.ok, "lobby starts") + ensure(play(r, 1000, cut), "the rest reach the end")
	var rest := [r.all[0], r.all[1], r.all[3]]
	var at: int = rest[0].bot_since.get(2, -1)
	bad += ensure(at > 1, "seat 2 turned into a bot (tick %d)" % at)
	for s in rest:
		bad += ensure(s.bot_since.get(2, -2) == at, "everyone agrees seat 2 is a bot from tick %d" % at)
		bad += ensure(s.bot_since.size() == 1, "and nobody else is")
	bad += ensure(events_of(r.all[0], "left").size() == 1 and events_of(r.all[0], "left")[0].why == "left", "host saw the player leave")
	bad += ensure(r.all[2].phase == "ended" and r.all[2].state.tick < 1000, "the cut peer gave up on its own")
	return mini(bad, 1) or all_agree(rest, reference(teams, 1000, {2: at}))


func test_a_client_that_goes_silent_becomes_a_bot() -> int:
	var teams: Array = Sim.FORMATS["ffa"]
	var r := rig(teams, 3, {"lag": 1, "silence": 40})
	var mute := func(_round):
		if r.all[0].state.tick >= 300 and not r.hub.muted.has(2):
			r.hub.mute(2)
	var bad := ensure(r.ok, "lobby starts") + ensure(play(r, 900, mute), "the rest reach the end")
	var rest := [r.all[0], r.all[2]]
	var at: int = rest[0].bot_since.get(1, -1)
	bad += ensure(at > 1, "seat 1 turned into a bot (tick %d)" % at)
	bad += ensure(rest[1].bot_since.get(1, -2) == at, "both agree on tick %d" % at)
	bad += ensure(events_of(r.all[0], "left").size() == 1 and events_of(r.all[0], "left")[0].why == "timeout", "host timed it out")
	return mini(bad, 1) or all_agree(rest, reference(teams, 900, {1: at, 3: 1}))


func test_clients_end_when_the_host_is_lost() -> int:
	var r := rig(Sim.FORMATS["ffa"], 3)
	var cut := func(_round):
		if r.all[0].state.tick >= 200 and r.hub.ends.has(1):
			r.hub.cut(1)
	play(r, 400, cut)
	var bad := ensure(r.ok, "lobby starts")
	for i in [1, 2]:
		bad += ensure(r.all[i].phase == "ended", "client %d ended" % i)
		bad += ensure(events_of(r.all[i], "ended").size() == 1 and events_of(r.all[i], "ended")[0].why == "host_lost", "because the host is lost")
	return mini(bad, 1)


func test_a_forced_desync_is_detected() -> int:
	var r := rig(Sim.FORMATS["ffa"], 3, {"lag": 1, "hash_every": 30})
	var shove := func(_round):
		var c = r.all[1]
		if c.state.tick >= 100 and not c.has_meta("shoved"):
			c.set_meta("shoved", true)
			c.state.mechs[1].x += 0.5
	var bad := ensure(r.ok, "lobby starts") + ensure(play(r, 200, shove), "all reach tick 200")
	for s in r.all:
		var e := events_of(s, "desync")
		bad += ensure(e.size() >= 1 and e[0].tick == 120, "peer saw the desync at tick 120 (%s)" % str(e.map(func(x): return x.tick)))
		bad += ensure(s.desynced == 120, "and remembers it")
	return mini(bad, 1)


func test_enet_loopback_smoke() -> int:
	var th := NetEnet.new()
	if th.serve(PORT) != OK:
		print("  could not bind 127.0.0.1:%d, skipping" % PORT)
		return 2
	var tc := NetEnet.new()
	if tc.join("127.0.0.1", PORT) != OK:
		print("  could not open the client, skipping")
		return 2
	var teams: Array = Sim.FORMATS["1v1"]
	var host := NetSession.new(th, true, {"teams": teams, "loadouts": loadouts_for(2), "silence": 3000, "seed": SEED})
	var client := NetSession.new(tc, false, {"silence": 3000}, loadouts_for(2)[1])
	var started := false
	for _i in 3000:
		host.poll()
		client.poll()
		if not started and events_of(client, "joined").size() == 1:
			started = host.begin()
		if client.phase == "running":
			break
		OS.delay_msec(2)
	var bad := ensure(started and client.phase == "running", "the client joined and started over ENet")
	if bad:
		th.close()
		tc.close()
		return 1
	host.stop_at = 300
	client.stop_at = 300
	for _i in 20000:
		host.pump(scripted)
		client.pump(scripted)
		if host.state.tick >= 300 and client.state.tick >= 300:
			break
		OS.delay_msec(1)
	bad += ensure(host.state.tick == 300 and client.state.tick == 300, "both reached tick 300")
	bad += ensure(Sim.hash_state(host.state) == Sim.hash_state(client.state), "same state on both ends")
	bad += ensure(Sim.hash_state(host.state) == reference(teams, 300), "and it is the local run")
	th.close()
	tc.close()
	return mini(bad, 1)
