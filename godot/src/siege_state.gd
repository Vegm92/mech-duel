extends RefCounted

const HALF := 80.0
const PLAZA := 14.0
const RING_IN := 16.0
const RING_OUT := 17.5
const BLOCK := 26.0
const LANE_W := 10.0
const LANES := [{"name": "N", "dx": 0, "dy": -1}, {"name": "E", "dx": 1, "dy": 0}, {"name": "S", "dx": 0, "dy": 1}, {"name": "W", "dx": -1, "dy": 0}]
const CHOKES := [36.0, 58.0]
const CHOKE_R := 2.0
const PADS := [30.0, 48.0, 66.0]
const VENTS := [47.0]
const SPAWN := 78.0
const AIR := [[-74.0, -74.0], [74.0, -74.0], [74.0, 74.0], [-74.0, 74.0]]
const CORE := {"r": 2.5, "hp": 5000, "repair": 5.0, "rings": [0.75, 0.5, 0.25, 0.0]}
const GATE := {"hp": 2200, "depth": 1.5}
const KINDS := ["scout", "swarm", "spider", "flyer", "turret", "walker", "tripod", "quadheavy", "heavy", "jugg"]
const ACTS := ["walk", "idle", "attack", "windup", "roll", "plant", "hit", "die", "dormant", "wake"]
const LANE_WALL := 1.0
const YARD_IN := 27.5
const ARCH := 8.0
const QUADS := [{"name": "NE", "sx": 1, "sy": -1}, {"name": "SE", "sx": 1, "sy": 1}, {"name": "SW", "sx": -1, "sy": 1}, {"name": "NW", "sx": -1, "sy": -1}]
const CAMP_TIERS := {"small": {"scrap": 10}, "medium": {"scrap": 25}, "big": {"scrap": 45}, "elite": {"scrap": 120, "token": 1}}
const CAMPS := [
	{"tier": "small", "a": 30.0, "b": 40.0, "bots": [["swarm", 1]]},
	{"tier": "medium", "a": 42.0, "b": 28.0, "bots": [["turret", 1], ["spider", 2]]},
	{"tier": "big", "a": 50.0, "b": 50.0, "bots": [["walker", 1]]},
	{"tier": "elite", "a": 62.0, "b": 62.0, "bots": [["heavy", 1]]},
]
const CRATES := [[24.0, 32.0], [32.0, 64.0], [60.0, 36.0], [72.0, 46.0]]
const CRATE := {"secs": 3, "scrap": 15, "reach": 2.0}
const HEAPS := [
	{"a": 36.0, "b": 34.0, "r": 2.0, "kind": "stack"}, {"a": 24.0, "b": 46.0, "r": 3.0, "kind": "hulk"}, {"a": 52.0, "b": 38.0, "r": 1.5, "kind": "pillar"},
	{"a": 40.0, "b": 58.0, "r": 2.0, "kind": "stack"}, {"a": 66.0, "b": 40.0, "r": 3.0, "kind": "hulk"}, {"a": 46.0, "b": 70.0, "r": 2.0, "kind": "stack"},
	{"a": 70.0, "b": 56.0, "r": 1.5, "kind": "pillar"}, {"a": 58.0, "b": 26.0, "r": 2.0, "kind": "stack"}, {"a": 40.0, "b": 74.0, "r": 1.5, "kind": "crane"},
]
const WRECK := {"a": 67.0, "b": 67.0, "r": 3.5}
const STEAM := [{"a": 46.0, "b": 36.0, "r": 3.0}, {"a": 30.0, "b": 56.0, "r": 3.0}]
const YARD_HAZARDS := [{"kind": "crush", "a": 56.0, "b": 20.0, "half": 1.5}, {"kind": "emp", "a": 20.0, "b": 56.0, "r": 2.5}]
const GARRISON_DOCK := {"x": 0.0, "y": 8.0, "face": PI / 2.0}
const GARRISON_TIERS := 5
const BAY := {"x": -8.0, "y": 8.0, "face": -PI / 4.0}
const PART_SLOTS := ["head", "core", "arms", "legs", "booster", "left", "right"]
const RUN_TIERS := 5
const RECALL := {"secs": 3, "cd": 25}


static func at(lane: int, d: float, side := 0.0) -> Dictionary:
	var l: Dictionary = LANES[lane]
	return {"x": l.dx * d - l.dy * side, "y": l.dy * d + l.dx * side}


static func yard_at(q: int, a: float, b: float) -> Dictionary:
	var Q: Dictionary = QUADS[q]
	return {"x": Q.sx * a, "y": Q.sy * b}


static func yards() -> Array:
	var out := []
	for q in QUADS.size():
		var camps := []
		for i in CAMPS.size():
			var c: Dictionary = CAMPS[i]
			var p := yard_at(q, c.a, c.b)
			camps.append({"id": q * CAMPS.size() + i, "tier": c.tier, "x": p.x, "y": p.y, "alive": true, "respawn_in": 0})
		var crates := []
		for c in CRATES:
			var p := yard_at(q, c[0], c[1])
			crates.append({"x": p.x, "y": p.y, "progress": 0.0, "taken": false})
		out.append({"quadrant": QUADS[q].name, "camps": camps, "crates": crates, "raided": 0.0})
	return out


static func tiers() -> Dictionary:
	var out := {}
	for s in PART_SLOTS:
		out[s] = 0
	return out


static func garrison() -> Dictionary:
	return {"tier": 0, "hp": 0.0, "max": 0.0, "x": GARRISON_DOCK.x, "y": GARRISON_DOCK.y, "face": GARRISON_DOCK.face, "act": "idle", "respawn_in": 0, "buyer": -1}


static func ring_hp(rings_left: int) -> Array:
	var out := []
	for i in 4:
		out.append(CORE.hp / 4.0 if i >= 4 - rings_left else 0.0)
	return out


static func gate(lane: int) -> Dictionary:
	var p := at(lane, (RING_IN + RING_OUT) / 2.0)
	return {"lane": lane, "x": p.x, "y": p.y, "hp": GATE.hp, "max": GATE.hp}


static func pads() -> Array:
	var out := []
	for lane in 4:
		for d in PADS:
			var p := at(lane, d)
			out.append({"lane": lane, "x": p.x, "y": p.y, "module": ""})
	return out


static func stub(rings_left := 4) -> Dictionary:
	var rings := ring_hp(rings_left)
	var hp := 0.0
	for r in rings:
		hp += r
	var gates := []
	var enemies := []
	for lane in 4:
		gates.append(gate(lane))
	for i in KINDS.size():
		var p := at(0, 24.0 + i * 5.0)
		enemies.append({"id": i, "kind": KINDS[i], "lane": 0, "x": p.x, "y": p.y, "face": PI / 2.0, "hp": 100, "max": 100, "act": "walk", "t": 0, "mk": 1, "neutral": false})
	return {
		"tick": 0, "wave": {"n": 1, "next_in": 480, "lanes_open": [true, false, false, false]},
		"core": {"x": 0.0, "y": 0.0, "hp": hp, "max": CORE.hp, "rings": rings, "repairing": false},
		"gates": gates, "pads": pads(), "enemies": enemies, "yards": yards(),
		"wallets": [120], "tokens": [0], "garrison": garrison(),
		"tiers": [tiers()], "recall": [], "shop_open": [false],
	}
