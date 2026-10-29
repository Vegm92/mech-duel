extends RefCounted

const Sim = preload("res://src/sim.gd")

const SAVE := "user://progress.cfg"
const LADDER := ["duelist", "sniper", "speedster", "hornet", "assassin", "glasscannon", "vampire", "overclock", "controller", "riposte", "wraith", "pyro", "reflector", "rampart", "artillery", "brawler", "juggernaut", "tank"]
const KO_DROPS := ["head", "core", "booster"]
const BREAK_DROPS := {"larm": ["arms", "left"], "rarm": ["arms", "right"], "legs": ["legs"]}
const SIEGE_SPOILS := {10: "tank", 20: "artillery", 30: "reflector"}

var owned := {}
var beaten := {}
var best := 0
var unlock_all := true
var path := SAVE


func _init() -> void:
	for slot in Sim.DEFAULT_LOADOUT:
		owned[id(slot, Sim.DEFAULT_LOADOUT[slot])] = 1


static func kind(slot: String) -> String:
	return "weapon" if Sim.HANDS.has(slot) else slot


static func id(slot: String, key: String) -> String:
	return kind(slot) + ":" + key


static func known(part_id: String) -> bool:
	var bits := part_id.split(":")
	if bits.size() != 2:
		return false
	var rows = Sim.WEAPONS if bits[0] == "weapon" else Sim.CATALOG.get(bits[0], {})
	return rows.has(bits[1])


func level(slot: String, key: String) -> int:
	var n: int = owned.get(id(slot, key), 0)
	return maxi(n, 1) if unlock_all else n


func has(slot: String, key: String) -> bool:
	return level(slot, key) > 0


func complete(lo: Dictionary) -> bool:
	return Sim.DEFAULT_LOADOUT.keys().all(func(s): return has(s, lo[s]))


func fit(lo: Dictionary) -> Dictionary:
	var out := Sim.normalize(lo)
	out.erase("lv")
	for slot in Sim.DEFAULT_LOADOUT:
		if not has(slot, out[slot]):
			out[slot] = Sim.DEFAULT_LOADOUT[slot]
	return out


func with_levels(lo: Dictionary) -> Dictionary:
	var lv := {}
	for slot in Sim.DEFAULT_LOADOUT:
		var n := level(slot, lo[slot])
		if n > 1:
			lv[slot] = n
	return lo.merged({"lv": lv}, true) if not lv.is_empty() else lo


func pool(broke: Array, foe: Dictionary, ko: bool) -> Array:
	var slots := []
	for part in broke:
		slots.append_array(BREAK_DROPS.get(part, []))
	if ko:
		slots.append_array(KO_DROPS)
	var out := []
	var seen := {}
	for slot in slots:
		var key: String = foe[slot]
		var part_id := id(slot, key)
		if seen.has(part_id) or level(slot, key) >= Sim.MAX_LEVEL:
			continue
		seen[part_id] = true
		out.append({"slot": slot, "key": key})
	return out


func spoils(wave: int) -> Array:
	if not SIEGE_SPOILS.has(wave):
		return []
	return pool(["larm", "rarm", "legs"], Sim.SETS[SIEGE_SPOILS[wave]], true)


func held(waves: int) -> bool:
	if waves <= best:
		return false
	best = waves
	return true


func claim(slot: String, key: String) -> void:
	owned[id(slot, key)] = mini(Sim.MAX_LEVEL, level(slot, key) + 1)


func win(set_key: String) -> void:
	beaten[set_key] = beaten.get(set_key, 0) + 1


func next_rival() -> String:
	var best: String = LADDER[0]
	for set_key in LADDER:
		if beaten.get(set_key, 0) < beaten.get(best, 0):
			best = set_key
	return best


func tier(set_key: String) -> int:
	return mini(Sim.MAX_LEVEL, 1 + beaten.get(set_key, 0))


func rival(set_key: String) -> Dictionary:
	var lo: Dictionary = Sim.SETS[set_key].duplicate()
	var t := tier(set_key)
	if t == 1:
		return lo
	var lv := {}
	for slot in Sim.DEFAULT_LOADOUT:
		lv[slot] = t
	lo.lv = lv
	return lo


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var saved = cfg.get_value("salvage", "owned", {})
	if saved is Dictionary:
		for part_id in saved:
			if part_id is String and known(part_id) and saved[part_id] is int:
				owned[part_id] = clampi(saved[part_id], 1, Sim.MAX_LEVEL)
	var wins = cfg.get_value("salvage", "beaten", {})
	if wins is Dictionary:
		for set_key in wins:
			if LADDER.has(set_key) and wins[set_key] is int:
				beaten[set_key] = maxi(0, wins[set_key])
	var top = cfg.get_value("siege", "best", 0)
	if top is int:
		best = maxi(0, top)


func save_file() -> void:
	if unlock_all or path == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("salvage", "owned", owned)
	cfg.set_value("salvage", "beaten", beaten)
	cfg.set_value("siege", "best", best)
	cfg.save(path)
