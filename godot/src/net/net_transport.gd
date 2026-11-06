extends RefCounted

## What the session needs from a network layer. Peer ids are ints and the host is always HOST.
## Implementations: net_fake.gd (tests), net_enet.gd (Godot ENet). A Steam one only fills these in.

const HOST := 1


func id() -> int:
	return HOST


## Pump the socket. Called once per session poll.
func poll() -> void:
	pass


## Send one message. `reliable` ones arrive once, in order. The rest may be lost or reordered.
func send(_peer: int, _data: PackedByteArray, _reliable: bool) -> void:
	pass


## Next received message as {"peer": int, "data": PackedByteArray}, or {} when there is none.
func recv() -> Dictionary:
	return {}


## Drains connection changes: {"k": "up" | "down", "peer": int}.
func events() -> Array:
	return []


func kick(_peer: int) -> void:
	pass


func close() -> void:
	pass
