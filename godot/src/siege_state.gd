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
const CORE := {"r": 2.5, "hp": 4000, "repair": 5.0, "rings": [0.75, 0.5, 0.25, 0.0]}
const GATE := {"hp": 1500, "depth": 1.5}
const KINDS := ["scout", "swarm", "spider", "flyer", "turret", "walker", "tripod", "quadheavy", "heavy", "jugg"]
const ACTS := ["walk", "idle", "attack", "windup", "roll", "plant", "hit", "die"]


static func at(lane: int, d: float, side := 0.0) -> Dictionary:
	var l: Dictionary = LANES[lane]
	return {"x": l.dx * d - l.dy * side, "y": l.dy * d + l.dx * side}


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
		enemies.append({"id": i, "kind": KINDS[i], "lane": 0, "x": p.x, "y": p.y, "face": PI / 2.0, "hp": 100, "max": 100, "act": "walk", "t": 0, "mk": 1})
	return {
		"tick": 0, "wave": {"n": 1, "next_in": 480, "lanes_open": [true, false, false, false]},
		"core": {"x": 0.0, "y": 0.0, "hp": hp, "max": CORE.hp, "rings": rings, "repairing": false},
		"gates": gates, "pads": pads(), "enemies": enemies,
	}
