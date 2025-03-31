extends Node

const SERVER_ADDRESS: String = "127.0.0.1"
const SERVER_PORT: int = 8080
const MAX_PLAYERS: int = 10

var players = {}
var player_info = {
	"nick": "host",
	"skin": "blue"
}

signal player_connected(peer_id, player_info)
signal server_disconnected

var current_server_port: int = SERVER_PORT  # Store current server port

func _process(_delta):
	# Poll the WebSocket peer each frame to process incoming data.
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.poll()
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)
		
func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_connection_failed)
	multiplayer.connection_failed.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)

func start_host(address: String = SERVER_ADDRESS):
	# Determine the port to use.
	if address.strip_edges() == "":
		address = SERVER_ADDRESS
	
	# If the address contains a colon, extract the custom port.
	if address.find(":") != -1:
		var parts = address.split(":")
		# parts[0] is the IP, parts[1] is the port.
		current_server_port = int(parts[1])
		print("Using custom port: ", current_server_port)
	else:
		current_server_port = SERVER_PORT
	
	# For logging, construct a URL (if no port is in the address, add the default).
	var url: String = ""
	if address.find(":") == -1:
		url = "ws://" + address + ":" + str(SERVER_PORT)
	else:
		url = "ws://" + address
	print("Starting server on URL: ", url)
	
	# Use WebSocketMultiplayerPeer for hosting.
	var peer = WebSocketMultiplayerPeer.new()
	# Always call create_server() with the determined port.
	var error = peer.create_server(current_server_port, "0.0.0.0", null)
	if error != OK:
		print("Error creating server: ", error)
		return error
	print("Server started successfully on port: ", current_server_port)
	
	multiplayer.multiplayer_peer = peer
	players[1] = player_info
	player_connected.emit(1, player_info)

func join_game(nickname: String, skin_color: String, address: String = SERVER_ADDRESS):
	# If no address is provided, default to SERVER_ADDRESS.
	if address.strip_edges() == "":
		address = SERVER_ADDRESS
	
	var peer = WebSocketMultiplayerPeer.new()
	var url: String = ""
	
	# Debugging: Log the address to see what the user entered
	print("Entered address: ", address)
	
	# If the address field is still the default, add the port; otherwise, if a custom address is provided,
	# check if it already contains a ws:// or wss:// prefix. If not, add ws://.
	if address == SERVER_ADDRESS:
		url = "ws://" + address + ":" + str(SERVER_PORT)
		print("Using default server address and port: ", url)
	else:
		# Check if the address already contains a ws:// or wss:// prefix.
		if address.begins_with("ws://") or address.begins_with("wss://"):
			url = address
			print("Using provided WebSocket URL: ", url)
		else:
			url = "ws://" + address
			print("Using provided address with ws:// prefix: ", url)
	
	# Try to create the WebSocket client.
	var error = peer.create_client(url)
	if error != OK:
		print("Error creating WebSocket client: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	
	# Set nickname and skin color.
	if not nickname:
		nickname = "Player_" + str(multiplayer.get_unique_id())
	if not skin_color or (skin_color != "red" and skin_color != "blue" and skin_color != "green" and skin_color != "yellow"):
		skin_color = "blue"
	player_info["nick"] = nickname
	player_info["skin"] = skin_color
	
func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)
	
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	
func _on_player_disconnected(id):
	players.erase(id)
	
func _on_connection_failed():
	print("Connection failed!")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	print("Server disconnected!")
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
