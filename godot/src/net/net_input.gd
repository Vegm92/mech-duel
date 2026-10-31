extends RefCounted

## One seat's input for one tick as 9 bytes: button bits, mx, my, ax, ay. Every peer runs the sim
## on the unpacked values, so aim and movement are snapped (1/1000 and 1/64 m) before anyone uses them.

const SIZE := 9
const BUTTONS := ["left", "right", "hook", "shield", "dash", "ult"]
const MOVE := 1000.0
const AIM := 64.0


static func pack(inp: Dictionary) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(SIZE)
	var bits := 0
	for i in BUTTONS.size():
		if inp.get(BUTTONS[i], false):
			bits |= 1 << i
	b.encode_u8(0, bits)
	b.encode_s16(1, clampi(roundi(float(inp.get("mx", 0.0)) * MOVE), -32768, 32767))
	b.encode_s16(3, clampi(roundi(float(inp.get("my", 0.0)) * MOVE), -32768, 32767))
	b.encode_s16(5, clampi(roundi(float(inp.get("ax", 0.0)) * AIM), -32768, 32767))
	b.encode_s16(7, clampi(roundi(float(inp.get("ay", 0.0)) * AIM), -32768, 32767))
	return b


static func unpack(b: PackedByteArray) -> Dictionary:
	if b.size() != SIZE:
		return snap({})
	var bits := b.decode_u8(0)
	var out := {"mx": b.decode_s16(1) / MOVE, "my": b.decode_s16(3) / MOVE, "ax": b.decode_s16(5) / AIM, "ay": b.decode_s16(7) / AIM}
	for i in BUTTONS.size():
		out[BUTTONS[i]] = (bits >> i) & 1 == 1
	return out


## The input as every peer will see it. A local reference run must feed `snap(input)` to Sim.step.
static func snap(inp: Dictionary) -> Dictionary:
	return unpack(pack(inp))
