extends RefCounted

## In-memory network for tests: one hub, one End per peer. Time is hub rounds (advance()), never the
## wall clock. Loss and jitter hit unreliable messages only; reliable ones keep their order.

const Sim = preload("res://src/sim.gd")

var delay := 0
var jitter := 0
var loss := 0.0
var now := 0
var rolls := {"seed": 1}
var ends := {}
var wire := []
var count := 0
var last := {}
var muted := {}


class End extends "res://src/net/net_transport.gd":
	var hub
	var me := 0
	var inbox := []
	var log := []

	func id() -> int:
		return me

	func send(peer: int, data: PackedByteArray, reliable: bool) -> void:
		hub.put(me, peer, data, reliable)

	func recv() -> Dictionary:
		return inbox.pop_front() if inbox.size() else {}

	func events() -> Array:
		var out := log
		log = []
		return out

	func kick(peer: int) -> void:
		hub.cut(peer)

	func close() -> void:
		hub.cut(me)


func _init(seed := 1, lag := 0, spread := 0, drop := 0.0) -> void:
	rolls.seed = seed
	delay = lag
	jitter = spread
	loss = drop


func join(id: int) -> End:
	var e := End.new()
	e.hub = self
	e.me = id
	ends[id] = e
	if id != End.HOST and ends.has(End.HOST):
		ends[End.HOST].log.append({"k": "up", "peer": id})
		e.log.append({"k": "up", "peer": End.HOST})
	return e


func put(from: int, to: int, data: PackedByteArray, reliable: bool) -> void:
	if not ends.has(to) or not ends.has(from) or muted.has(from) or muted.has(to):
		return
	if not reliable and Sim.rng(rolls) < loss:
		return
	var due := now + delay
	if reliable:
		var key := "%d>%d" % [from, to]
		due = maxi(due, last.get(key, 0))
		last[key] = due
	elif jitter > 0:
		due += int(Sim.rng(rolls) * (jitter + 1))
	count += 1
	wire.append({"due": due, "n": count, "from": from, "to": to, "data": data})


## One round of time: everything now due lands in the receivers' inboxes, oldest first.
func advance() -> void:
	now += 1
	var ready := wire.filter(func(p): return p.due <= now)
	if ready.is_empty():
		return
	wire = wire.filter(func(p): return p.due > now)
	ready.sort_custom(func(a, b): return a.due < b.due or (a.due == b.due and a.n < b.n))
	for p in ready:
		if ends.has(p.to):
			ends[p.to].inbox.append({"peer": p.from, "data": p.data})


## The peer drops off the network. Whoever was connected to it hears a "down".
func cut(id: int) -> void:
	if not ends.has(id):
		return
	ends.erase(id)
	wire = wire.filter(func(p): return p.from != id and p.to != id)
	for other in ends:
		if id == End.HOST or other == End.HOST:
			ends[other].log.append({"k": "down", "peer": id})


## The peer goes silent without a "down": nothing it sends or is sent arrives.
func mute(id: int) -> void:
	muted[id] = true
	wire = wire.filter(func(p): return p.from != id and p.to != id)
