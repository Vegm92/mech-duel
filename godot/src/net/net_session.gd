extends RefCounted

## Delay-based lockstep over Sim.step (see NETCODE_DESIGN.md). The host is a relay and sequencer:
## it collects every seat's input for a tick, makes one frame of it and sends the frames to all.
## Every peer, host included, runs the sim on the same frames, so they keep the same state.
## Nothing here knows about menus or how local input is read: the game passes a sampler to pump().

const Sim = preload("res://src/sim.gd")
const Bot = preload("res://src/bot.gd")
const NetInput = preload("res://src/net/net_input.gd")

const VERSION := 1
const HELLO := 1
const WELCOME := 2
const REFUSE := 3
const START := 4
const IN := 5
const FR := 6
const HASH := 7
const DESYNC := 8

## delay: ticks between sampling an input and it being used. hash_every: ticks between state hashes.
## silence: polls without word from the other side before it counts as gone. window: most ticks per packet.
## lag: frames a client may fall behind before it is dropped.
const DEFAULTS := {"delay": 6, "hash_every": 30, "silence": 180, "window": 64, "lag": 600, "seed": 0x2545f491, "teams": [0, 1], "loadouts": [], "local": [0], "bots": []}

var net
var host: bool
var phase := "lobby"
var cfg := {}
var state = null
var seats := 0
var local: Array = []
var loadout = null
var bots := 0
var bot_since := {}
var brains := {}
var frames := {}
var pending := {}
var next_in := 1
var seq := 0
var have := 0
var acked := 0
var clients := {}
var hashes := {}
var quiet := 0
var events: Array = []
var stop_at := -1
var desynced := -1


func _init(transport, as_host: bool, config := {}, mine = null) -> void:
	net = transport
	host = as_host
	cfg = DEFAULTS.duplicate()
	cfg.merge(config, true)
	loadout = mine
	if host:
		seats = cfg.teams.size()
		local = cfg.local.duplicate()
		for s in cfg.bots:
			bots |= 1 << s


static func brain_seed(seed: int, seat: int) -> int:
	return seed + 1000 + seat


static func state_hash(s: Dictionary) -> int:
	var c := s.duplicate(true)
	strip(c)
	return Sim.hash_state(c)


static func strip(v) -> void:
	if v is Dictionary:
		v.erase("_n")
		v.erase("seen")
		for x in v.values():
			strip(x)
	elif v is Array:
		for x in v:
			strip(x)


func take_events() -> Array:
	var out := events
	events = []
	return out


func free_seat() -> int:
	for s in seats:
		if local.has(s) or cfg.bots.has(s):
			continue
		var taken := false
		for c in clients.values():
			taken = taken or c.seat == s
		if not taken:
			return s
	return -1


## Host only. Starts the match once every online seat has a player.
func begin() -> bool:
	if not host or phase != "lobby" or free_seat() >= 0:
		return false
	var los := []
	for s in seats:
		los.append(cfg.loadouts[s] if s < cfg.loadouts.size() else null)
	for c in clients.values():
		los[c.seat] = c.loadout
	var pack := {"teams": cfg.teams, "loadouts": los, "seed": cfg.seed, "delay": cfg.delay, "hash_every": cfg.hash_every, "bots": bots}
	for p in clients:
		net.send(p, var_to_bytes([START, pack]), true)
	launch(pack)
	return true


func launch(pack: Dictionary) -> void:
	cfg.seed = pack.seed
	cfg.delay = pack.delay
	cfg.hash_every = pack.hash_every
	seats = pack.teams.size()
	bots = pack.bots
	state = Sim.create_state(pack.loadouts, pack.teams)
	state.seed = pack.seed
	for s in seats:
		pending[s] = {}
	phase = "running"
	events.append({"k": "started", "seats": seats, "local": local})


## Pump the transport and handle what came in. Call it every frame, also in the lobby.
func poll() -> void:
	net.poll()
	for e in net.events():
		on_event(e)
	while true:
		var p: Dictionary = net.recv()
		if p.is_empty():
			break
		var msg = bytes_to_var(p.data)
		if msg is Array and msg.size() > 0 and msg[0] is int:
			on_message(p.peer, msg)


## One frame of the game loop: poll, feed the sim every frame that is ready (at most `max_steps`),
## send. `sample.call(seat, tick)` returns that local seat's input for a tick, when it is needed.
## Returns how many ticks the sim advanced.
func pump(sample: Callable, max_steps := 3) -> int:
	poll()
	var n := 0
	if phase == "running":
		var seq0 := seq
		while true:
			fill(sample)
			sequence()
			if n >= max_steps or not step():
				break
			n += 1
		watch(seq0)
		flush()
	return n


func fill(sample: Callable) -> void:
	while next_in <= state.tick + cfg.delay:
		for s in local:
			pending[s][next_in] = NetInput.pack(sample.call(s, next_in))
		next_in += 1


func sequence() -> void:
	if not host:
		return
	while true:
		var t := seq + 1
		var ins := []
		for s in seats:
			if (bots >> s) & 1:
				ins.append(PackedByteArray())
			elif pending[s].has(t):
				ins.append(pending[s][t])
			else:
				return
		for s in seats:
			pending[s].erase(t)
		frames[t] = {"bots": bots, "ins": ins}
		seq = t


## Runs the next tick if its frame is here. Seats the frame marks as bots are played by Bot.
func step() -> bool:
	if phase != "running" or (stop_at >= 0 and state.tick >= stop_at):
		return false
	var t: int = state.tick + 1
	if not frames.has(t):
		return false
	var f: Dictionary = frames[t]
	var ins := []
	for s in seats:
		if (f.bots >> s) & 1:
			if not bot_since.has(s):
				bot_since[s] = t
				brains[s] = Bot.create_brain(brain_seed(cfg.seed, s))
				events.append({"k": "bot", "seat": s, "tick": t})
			ins.append(Bot.bot_input(state, brains[s], s))
		else:
			ins.append(NetInput.unpack(f.ins[s]))
	Sim.step(state, ins)
	if not host:
		frames.erase(t)
	if t % cfg.hash_every == 0:
		report(t)
	return true


func report(t: int) -> void:
	var h := state_hash(state)
	if host:
		note(t, net.id(), h)
	else:
		net.send(net.HOST, var_to_bytes([HASH, t, h]), true)


func note(t: int, peer: int, h: int) -> void:
	if not hashes.has(t):
		hashes[t] = {}
	hashes[t][peer] = h
	judge(t)


func judge(t: int) -> void:
	if not hashes.has(t) or not hashes[t].has(net.id()):
		return
	var got: Dictionary = hashes[t]
	for p in clients:
		if not got.has(p):
			return
	hashes.erase(t)
	var vals := got.values()
	for v in vals:
		if v != vals[0]:
			desynced = t if desynced < 0 else desynced
			events.append({"k": "desync", "tick": t, "hashes": got})
			for p in clients:
				net.send(p, var_to_bytes([DESYNC, t]), true)
			return


func watch(seq0: int) -> void:
	if not host:
		quiet += 1
		if quiet > cfg.silence:
			finish("host_silent")
		return
	for p in clients.keys():
		var c: Dictionary = clients.get(p, {})
		if c.is_empty():
			continue
		if seq != seq0 or pending[c.seat].has(seq + 1):
			c.wait = 0
		else:
			c.wait += 1
		if c.wait > cfg.silence:
			drop(p, "timeout")
		elif seq - c.ack > cfg.lag:
			drop(p, "lag")
	var bound: int = state.tick
	for c in clients.values():
		bound = mini(bound, c.ack)
	for t in frames.keys():
		if t <= bound:
			frames.erase(t)


func flush() -> void:
	if host:
		for p in clients:
			var c: Dictionary = clients[p]
			var first: int = c.ack + 1
			var last := mini(seq, c.ack + cfg.window)
			var blob := PackedByteArray()
			for t in range(first, last + 1):
				var f: Dictionary = frames[t]
				blob.append(f.bots)
				for s in seats:
					blob.append_array(f.ins[s] if f.ins[s].size() == NetInput.SIZE else PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0]))
			net.send(p, var_to_bytes([FR, c.have, first, blob]), false)
	else:
		var first := acked + 1
		var last := mini(next_in - 1, acked + cfg.window)
		var blob := PackedByteArray()
		for t in range(first, last + 1):
			for s in local:
				blob.append_array(pending[s][t])
		net.send(net.HOST, var_to_bytes([IN, have, first, blob]), false)


func on_event(e: Dictionary) -> void:
	if e.k == "up":
		if not host:
			net.send(net.HOST, var_to_bytes([HELLO, VERSION, loadout]), true)
	elif host:
		drop(e.peer, "left")
	elif e.peer == net.HOST:
		finish("host_lost")


func on_message(peer: int, msg: Array) -> void:
	if not host:
		quiet = 0
	match msg[0]:
		HELLO:
			if host and msg.size() >= 3:
				hello(peer, msg)
		WELCOME:
			if not host and msg.size() >= 3:
				local = [msg[1]]
				seats = msg[2]
				events.append({"k": "joined", "seat": msg[1]})
		REFUSE:
			if not host:
				events.append({"k": "refused", "why": msg[1] if msg.size() > 1 else ""})
				close()
		START:
			if not host and phase == "lobby" and msg.size() >= 2 and msg[1] is Dictionary:
				launch(msg[1])
		IN:
			if host and phase == "running" and clients.has(peer) and msg.size() >= 4:
				got_in(clients[peer], msg)
		FR:
			if not host and phase == "running" and msg.size() >= 4:
				got_frames(msg)
		HASH:
			if host and phase == "running" and clients.has(peer) and msg.size() >= 3:
				note(msg[1], peer, msg[2])
		DESYNC:
			if not host and msg.size() >= 2:
				desynced = msg[1] if desynced < 0 else desynced
				events.append({"k": "desync", "tick": msg[1]})


func hello(peer: int, msg: Array) -> void:
	var s := free_seat()
	if phase != "lobby" or clients.has(peer) or msg[1] != VERSION or s < 0:
		net.send(peer, var_to_bytes([REFUSE, "full" if s < 0 else "version"]), true)
		return
	clients[peer] = {"seat": s, "loadout": msg[2], "ack": 0, "have": 0, "wait": 0}
	net.send(peer, var_to_bytes([WELCOME, s, seats]), true)
	events.append({"k": "joined", "seat": s, "peer": peer})


func got_in(c: Dictionary, msg: Array) -> void:
	var first: int = msg[2]
	var blob: PackedByteArray = msg[3]
	c.ack = maxi(c.ack, msg[1])
	var n := blob.size() / NetInput.SIZE
	if blob.size() % NetInput.SIZE != 0:
		return
	for i in n:
		var t := first + i
		if t > seq and not pending[c.seat].has(t) and ((bots >> c.seat) & 1) == 0:
			pending[c.seat][t] = blob.slice(i * NetInput.SIZE, (i + 1) * NetInput.SIZE)
	if first <= c.have + 1:
		c.have = maxi(c.have, first + n - 1)


func got_frames(msg: Array) -> void:
	var first: int = msg[2]
	var blob: PackedByteArray = msg[3]
	acked = maxi(acked, msg[1])
	for s in local:
		for t in pending[s].keys():
			if t <= acked:
				pending[s].erase(t)
	var stride := 1 + seats * NetInput.SIZE
	if blob.size() % stride != 0:
		return
	var n := blob.size() / stride
	for i in n:
		var t := first + i
		if t > state.tick and not frames.has(t):
			var at := i * stride
			var ins := []
			for s in seats:
				ins.append(blob.slice(at + 1 + s * NetInput.SIZE, at + 1 + (s + 1) * NetInput.SIZE))
			frames[t] = {"bots": blob[at], "ins": ins}
	if first <= have + 1:
		have = maxi(have, first + n - 1)


## Host only. The seat becomes a bot from the next frame that has not been made yet.
func drop(peer: int, why: String) -> void:
	if not clients.has(peer):
		return
	var s: int = clients[peer].seat
	clients.erase(peer)
	net.kick(peer)
	if phase == "running":
		bots |= 1 << s
		pending[s].clear()
		events.append({"k": "left", "seat": s, "why": why, "tick": seq + 1})
		for t in hashes.keys():
			judge(t)


func finish(why: String) -> void:
	if phase != "ended":
		phase = "ended"
		events.append({"k": "ended", "why": why})


func close() -> void:
	net.close()
	phase = "ended"
