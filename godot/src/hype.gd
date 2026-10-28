extends RefCounted

const Sim = preload("res://src/sim.gd")

const HYPE := {"half": 4.0, "hit": 0.1, "calm": 30.0, "wild": 70.0, "danger": 40.0, "clutch": 30.0, "matchPoint": 10.0}
const POINTS := {"hooked": 15.0, "ult": 15.0, "parry": 20.0, "break": 25.0, "ko": 100.0, "tactic": 10.0}
const SIEGE := {"floor": 0.5}
const CHEER := {"hooked": 0.9, "break": 1.6, "ko": 3.5}


## Hype points one fx event adds.
static func gain(f: Dictionary) -> float:
	if f.k == "hit":
		return f.n * HYPE.hit * (2.0 if f.head else 1.0)
	if f.k == "boom":
		return 15.0 if f.big else 0.0
	if f.k == "tactic" and f.id == "breather":
		return 0.0
	return POINTS.get(f.k, 0.0)


## Tension keeps hype from cooling below this.
static func floor_of(state: Dictionary) -> float:
	if state.phase != "fight":
		return 0.0
	if state.has("siege"):
		return SIEGE.floor * state.siege.director.pressure
	var f := 0.0
	for m in state.mechs:
		if not m.ko and m.armor.head < m.max.head * 0.25:
			f = HYPE.danger
	if state.clock <= 10 * Sim.TICKS:
		f = maxf(f, HYPE.clutch)
	if state.score.max() == Sim.MATCH.wins - 1:
		f += HYPE.matchPoint
	return f


## Hype after dt seconds with these new events.
static func next(h: float, state: Dictionary, events: Array, dt: float) -> float:
	h *= pow(0.5, dt / HYPE.half)
	for f in events:
		h += gain(f)
	return minf(100.0, maxf(h, floor_of(state)))


## 0 calm, 1 lively, 2 wild.
static func mood(h: float) -> int:
	return 2 if h >= HYPE.wild else (1 if h >= HYPE.calm else 0)


## Seconds the other teams' fans cheer for this event (0 = no cheer).
static func cheer_for(f: Dictionary) -> float:
	if f.k == "hit":
		return 0.9 if f.n >= 30 or f.head else 0.0
	return CHEER.get(f.k, 0.0)
