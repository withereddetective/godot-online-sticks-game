extends Node

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal server_message(peer_id: int, message: Dictionary)
signal client_message(message: Dictionary)
signal client_disconnected

const PACKET_TYPE: int = 20
const MAX_CLIENTS: int = 1

var is_host: bool = false
var host_settings: Dictionary = {}
var peer_players: Dictionary = {}


func _ready() -> void:
	LowLevelNetworkHandler.on_peer_connected.connect(_on_peer_connected)
	LowLevelNetworkHandler.on_peer_disconnected.connect(_on_peer_disconnected)
	ServerNetworkGlobals.handle_sticks_game_packet.connect(_on_server_packet)
	ClientNetworkGlobals.handle_sticks_game_packet.connect(_on_client_packet)
	LowLevelNetworkHandler.on_disconnected_to_server.connect(_on_client_disconnected)


func start_host(port: int, settings: Dictionary) -> bool:
	LowLevelNetworkHandler.stop_network()
	is_host = true
	host_settings = settings.duplicate(true)
	peer_players.clear()
	LowLevelNetworkHandler.start_server("0.0.0.0", port)
	return LowLevelNetworkHandler.connection != null


func start_client(address: String, port: int) -> bool:
	LowLevelNetworkHandler.stop_network()
	is_host = false
	peer_players.clear()
	LowLevelNetworkHandler.start_client(address, port)
	return LowLevelNetworkHandler.connection != null


func send_to_peer(peer_id: int, message: Dictionary) -> void:
	if not LowLevelNetworkHandler.client_peers.has(peer_id):
		push_error("Cannot send sticks message: peer is not connected.")
		return
	LowLevelNetworkHandler.client_peers[peer_id].send(
		0, _encode_message(message), ENetPacketPeer.FLAG_RELIABLE
	)


func send_to_server(message: Dictionary) -> void:
	var peer: ENetPacketPeer = LowLevelNetworkHandler.server_peer
	if peer == null:
		push_error("Cannot send sticks message: not connected to a server.")
		return
	peer.send(0, _encode_message(message), ENetPacketPeer.FLAG_RELIABLE)


func _on_peer_connected(peer_id: int) -> void:
	if peer_players.size() >= MAX_CLIENTS:
		LowLevelNetworkHandler.client_peers[peer_id].peer_disconnect()
		return
	peer_players[peer_id] = 1
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_players.erase(peer_id):
		peer_left.emit(peer_id)


func _on_server_packet(peer_id: int, data: PackedByteArray) -> void:
	if not peer_players.has(peer_id):
		return
	var message: Dictionary = _decode_message(data)
	if not message.is_empty():
		server_message.emit(peer_id, message)


func _on_client_packet(data: PackedByteArray) -> void:
	var message: Dictionary = _decode_message(data)
	if not message.is_empty():
		client_message.emit(message)


func _on_client_disconnected() -> void:
	client_disconnected.emit()


func _encode_message(message: Dictionary) -> PackedByteArray:
	var packet: PackedByteArray = PackedByteArray([PACKET_TYPE])
	packet.append_array(JSON.stringify(message).to_utf8_buffer())
	return packet


func _decode_message(data: PackedByteArray) -> Dictionary:
	if data.size() < 2 or data.decode_u8(0) != PACKET_TYPE:
		return {}
	var parsed: Variant = JSON.parse_string(data.slice(1).get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	push_warning("Ignoring malformed sticks game packet.")
	return {}
