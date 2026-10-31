extends "res://src/net/net_transport.gd"

## Godot's built-in ENet. `serve` on the host, `join` on a client. No scene tree or autoload needed:
## the session calls poll() itself.

var peer := ENetMultiplayerPeer.new()
var log := []


func serve(port: int, max_clients := 3) -> Error:
	var e := peer.create_server(port, max_clients)
	if e == OK:
		wire()
	return e


func join(address: String, port: int) -> Error:
	var e := peer.create_client(address, port)
	if e == OK:
		wire()
	return e


func wire() -> void:
	peer.peer_connected.connect(func(p): log.append({"k": "up", "peer": p}))
	peer.peer_disconnected.connect(func(p): log.append({"k": "down", "peer": p}))


func id() -> int:
	return peer.get_unique_id()


func poll() -> void:
	peer.poll()


func send(to: int, data: PackedByteArray, reliable: bool) -> void:
	peer.set_target_peer(to)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	peer.put_packet(data)


func recv() -> Dictionary:
	if peer.get_available_packet_count() == 0:
		return {}
	var from := peer.get_packet_peer()
	return {"peer": from, "data": peer.get_packet()}


func events() -> Array:
	var out := log
	log = []
	return out


func kick(to: int) -> void:
	peer.disconnect_peer(to)


func close() -> void:
	peer.close()
