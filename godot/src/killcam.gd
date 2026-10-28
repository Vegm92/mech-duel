extends RefCounted

## The kill cam: after the round's last K.O. it re-runs the last seconds from a ghost copy of the
## round and films them like a TV replay, one smooth camera move with slow motion. Presentation only.

const Sim = preload("res://src/sim.gd")

const KILLCAM := {"secs": 4.0, "live": 60, "end": 50, "grace": 30, "look_y": 1.1, "pad": 1.0, "clear": 0.5, "tall": 4.5,
	"pylon": 0.6, "room": 2.5, "haze": 0.3, "margin": 2.5, "aspect": 1.6, "dolly": 2.0, "track": 5.0, "lift": 6.0}
## One continuous move, keyed to ticks from the K.O.: wide on both mechs, glide in on the victim
## (`close`), ease into slow motion (`slow`), then pull back and rise (`after`) and speed up (`fast`).
## `dist`, `up` and `speed` are [wide, at the K.O., at the end].
const SHOT := {"angle": 115.0, "spin": 0.12, "fov": 38.0, "fit": 1.1, "close": [-110, 0], "after": [0, 50],
	"slow": [-50, -6], "fast": [24, 50], "dist": [18.0, 7.0, 11.0], "up": [8.0, 2.6, 5.5], "speed": [1.0, 0.2, 0.5]}
const TRIES := [0.0, 25.0, -25.0, 50.0, -50.0]
const OBSTACLES := Sim.PILLARS + Sim.TRAPS.tesla.at


static func lag() -> int:
	return int(KILLCAM.secs * Sim.TICKS)


static func recorder() -> Dictionary:
	return {"round": -1, "ghost": null, "ins": []}


## Call before every live step. The ghost is copied at the round's first fight tick (nothing is
## shared between dicts yet, so a deep copy is exact) and stepped `lag()` ticks behind the live one.
static func record(rec: Dictionary, state: Dictionary, ins: Array) -> void:
	if state.phase != "fight":
		return
	if rec.round != state.round:
		rec.round = state.round
		rec.ghost = state.duplicate(true)
		untag(rec.ghost)
		rec.ins = []
	rec.ins.append(ins)
	if rec.ins.size() > lag():
		Sim.step(rec.ghost, rec.ins.pop_front())


static func wants(state: Dictionary, rec: Dictionary) -> bool:
	return state.phase == "ko" and state.finalKo >= 0 and state.timer == Sim.MATCH.ko - KILLCAM.live and rec.round == state.round and rec.ghost != null


static func start(rec: Dictionary, live: Dictionary) -> Dictionary:
	var s: Dictionary = rec.ghost
	rec.ghost = null
	s.fx = []
	var v: Dictionary = live.mechs[live.finalKo]
	var killer: int = v.id
	var best := INF
	for m in live.mechs:
		var d := Vector2(m.x - v.x, m.y - v.y).length()
		if m.team != v.team and d < best:
			best = d
			killer = m.id
	var ko: int = s.tick + rec.ins.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = ko
	var r := {"state": s, "ins": rec.ins, "i": 0, "ko": ko, "victim": v.id, "killer": killer, "u": 0.0,
		"side": 1.0 if rng.randf() < 0.5 else -1.0, "off": 0.0, "dir": Vector3.RIGHT, "eye": Vector3.ZERO, "look": Vector3.ZERO, "fov": SHOT.fov}
	var k1 := spot_of(live.mechs[killer])
	var v1 := spot_of(v)
	var d1 := Vector3(v1.x - k1.x, 0, v1.z - k1.z)
	r.dir = d1.normalized() if d1.length() > 0.01 else Vector3.RIGHT
	aim(r, spot_of(s.mechs[killer]), spot_of(s.mechs[v.id]), k1, v1)
	return r


static func advance(r: Dictionary) -> void:
	Sim.step(r.state, r.ins[r.i] if r.i < r.ins.size() else [])
	r.i += 1


static func done(r: Dictionary) -> bool:
	return r.i >= r.ins.size() + KILLCAM.end


static func progress(r: Dictionary) -> float:
	return -1.0 if r.is_empty() else clampf(r.i / float(r.ins.size() + KILLCAM.end), 0.0, 1.0)


static func spot_of(m: Dictionary) -> Vector3:
	return Vector3(m.x, Sim.height_of(m), m.y)


static func speed_at(t: float) -> float:
	var s := lerpf(SHOT.speed[0], SHOT.speed[1], smoothstep(SHOT.slow[0], SHOT.slow[1], t))
	return lerpf(s, SHOT.speed[2], smoothstep(SHOT.fast[0], SHOT.fast[1], t))


## This frame's camera (eye, look, fov) and game speed, from where the killer (k) and the victim (v)
## stand and the real seconds since the last frame. The eye and the look ease toward the move, so a
## camera that rises over a pillar or pylon (`lift`) floats up instead of jumping.
static func film(r: Dictionary, k: Vector3, v: Vector3, real: float) -> Dictionary:
	var t: float = r.state.tick - r.ko
	var first: bool = r.u == 0.0
	r.u += real
	var a := rig(r, k, v, t)
	var lift := 0.0
	while lift < KILLCAM.lift and hidden(a.eye + Vector3.UP * lift, k, v, a.go):
		lift += KILLCAM.lift / 3.0
	a.eye.y += lift
	var dolly := 1.0 if first else 1.0 - exp(-real * KILLCAM.dolly)
	var track := 1.0 if first else 1.0 - exp(-real * KILLCAM.track)
	r.eye = r.eye.lerp(a.eye, dolly)
	r.look = r.look.lerp(a.look, track)
	r.fov = lerpf(r.fov, a.fov, dolly)
	return {"eye": r.eye, "look": r.look, "fov": r.fov, "speed": speed_at(t)}


## The move at tick t from the K.O. (the slow orbit runs on game time, so it almost holds still in
## slow motion and `aim` can check the whole path ahead).
static func rig(r: Dictionary, k: Vector3, v: Vector3, t: float) -> Dictionary:
	var go := smoothstep(SHOT.close[0], SHOT.close[1], t)
	var after := smoothstep(SHOT.after[0], SHOT.after[1], t)
	var sep := Vector2(k.x - v.x, k.z - v.z).length()
	var pivot := ((k + v) / 2.0).lerp(v, go)
	var far := lerpf(lerpf(maxf(SHOT.dist[0], sep * SHOT.fit), SHOT.dist[1], go), SHOT.dist[2], after)
	var turn: float = r.side * (deg_to_rad(SHOT.angle) + r.off + SHOT.spin * (t + r.ins.size()) / Sim.TICKS)
	var flat: Vector3 = Vector3(pivot.x, 0, pivot.z) + r.dir.rotated(Vector3.UP, turn) * far
	var c := Sim.clamp_arena(flat.x, flat.z, KILLCAM.pad)
	var eye := Vector3(c.x, lerpf(lerpf(SHOT.up[0], SHOT.up[1], go), SHOT.up[2], after), c.y)
	var look := pivot + Vector3(0, KILLCAM.look_y, 0)
	var both := sep * (1.0 - go) * 0.5 + KILLCAM.margin
	var fov := maxf(SHOT.fov, rad_to_deg(2.0 * atan(both / (eye.distance_to(look) * KILLCAM.aspect))))
	return {"eye": eye, "look": look, "fov": fov, "go": go}


## Picks the side and start angle (the rolled side first, then ±25/50°, then the mirror side) whose
## camera sees the mechs at the most checks: the start, the K.O. and the pull-back after it (the
## mechs stand still from the K.O. on, so those are exact). The lift covers what is left.
static func aim(r: Dictionary, k0: Vector3, v0: Vector3, k1: Vector3, v1: Vector3) -> void:
	var end: float = SHOT.after[1]
	var checks := [[k0, v0, -float(r.ins.size())], [k1, v1, 0.0], [k1, v1, end * 0.5], [k1, v1, end]]
	var best := -1
	var pick := [r.side, 0.0]
	for side in [r.side, -r.side]:
		for off in TRIES:
			r.side = side
			r.off = deg_to_rad(off)
			var score := 0
			for c in checks:
				var a := rig(r, c[0], c[1], c[2])
				score += 0 if hidden(a.eye, c[0], c[1], a.go) else 1
			if score > best:
				best = score
				pick = [side, r.off]
	r.side = pick[0]
	r.off = pick[1]


## A pillar or pylon hides the victim (or the killer, while both are in the shot) or stands right
## next to the lens.
static func hidden(eye: Vector3, k: Vector3, v: Vector3, go: float) -> bool:
	return crowded(eye) or blocked(eye, v) or (go < 0.5 and blocked(eye, k))


static func crowded(eye: Vector3) -> bool:
	if eye.y >= KILLCAM.tall:
		return false
	for o in OBSTACLES:
		if Vector2(o.x - eye.x, o.y - eye.z).length() < o.get("r", KILLCAM.pylon) + KILLCAM.room:
			return true
	return false


## True when a pillar or tesla pylon stands between the eye and a mech's chest (the line passes
## close to it while still lower than its top).
static func blocked(eye: Vector3, at: Vector3) -> bool:
	var d := Vector2(at.x - eye.x, at.z - eye.z)
	var y: float = at.y + KILLCAM.look_y
	for o in OBSTACLES:
		var t := clampf(Vector2(o.x - eye.x, o.y - eye.z).dot(d) / maxf(d.length_squared(), 0.01), 0.0, 1.0)
		var near: bool = Vector2(eye.x + d.x * t - o.x, eye.z + d.y * t - o.y).length() < o.get("r", KILLCAM.pylon) + KILLCAM.clear
		if near and lerpf(eye.y, y, t) < KILLCAM.tall:
			return true
	return false


## Drops the view's pooled-node tags, so a state the view drew before can be drawn again.
static func untag(v) -> void:
	if v is Dictionary:
		v.erase("_n")
		for x in v.values():
			untag(x)
	elif v is Array:
		for x in v:
			untag(x)
