extends Node

var peer : NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
var server_port : int = 12345
var max_players : int = 12

signal packet_recieved(peer_id, packet_id, packet_data)

var players : Dictionary = {
	# ID : {"player_name":"player"}
}
var bans : Dictionary = {
	# ID : {"author":"player","reason":"whatever"}
}
var admins : Array = [
	# player_name,
]

# Packets are common to player/server
enum packets {
	# Network
	ASK_CONNECTION,
	COUNTDOWN_REGISTRATION,
	UPDATE_CONFIRMED,
	WELCOME_CONNECTION,
	REQUEST_UPDATE_PLAYER_DATA,
	UPDATE_PLAYER_DATA,
	INFORM_DISCONNECTION,
	GET_PLAYER_AUTHORITY,
}

var timeout_in_seconds : float = 10

func create_connections():
	get_tree().connect("network_peer_connected", self, "player_connected")
	get_tree().connect("network_peer_disconnected", self, "player_disconnected")
	get_tree().connect("connected_to_server", self, "connected_ok")
	get_tree().connect("connection_failed", self, "connected_fail")
	get_tree().connect("server_disconnected", self, "server_disconnected")
	connect("tree_exiting", self, "on_close")
	connect("packet_recieved", self, "packet_recieved")

func _ready():
	for argument in OS.get_cmdline_args():
		if argument.find("--host"):
			create_server()
	
	create_connections()

# Common

func clear_connection():
	if get_tree().get_network_peer() != null:
		get_tree().network_peer = null

func bind_peer():
	get_tree().network_peer = peer

func send_packet_to_everyone(packet_id : int, packet_data):
	if get_tree().get_network_peer() != null:
		rpc("send_packet", packet_id, packet_data)

func send_fast_packet_to_everyone(packet_id : int, packet_data):
	if get_tree().get_network_peer() != null:
		rpc_unreliable("send_packet", packet_id, packet_data)

func send_packet_to_id(target_id : int, packet_id : int, packet_data):
	if get_tree().get_network_peer() != null:
		rpc_id(target_id, "send_packet", packet_id, packet_data)

func send_fast_packet_to_id(target_id : int, packet_id : int, packet_data):
	if get_tree().get_network_peer() != null:
		rpc_unreliable_id(target_id, "send_packet", packet_id, packet_data)

remote func send_packet(packet_id : int, packet_data):
	var player_id = get_tree().get_rpc_sender_id() # 1 is server
	
	emit_signal("packet_recieved", player_id, packet_id, packet_data)

func is_peer_server(peer_id : int):
	var result = false
	
	if peer_id == 1:
		result = true
	
	return result

func has_and_is_server():
	var result = false
	
	if get_tree().get_network_peer() != null:
		result = get_tree().is_network_server()
	
	return result

func packet_recieved(peer_id, packet_id, packet_data):
	print("PACKET RECIEVED - Sender: ", peer_id, " - PACKET ID: ", packet_id, " - PACKET_DATA: ", packet_data)
	
	if packet_id == packets.ASK_CONNECTION:
		if has_and_is_server():
			var peer_ip = peer.get_peer_address(peer_id)
			print("Connection incoming from [" + peer_ip + "] ID (" + str(peer_id) + ")")
			
			if process_connection(peer_id):
				print(str(peer_id) + " has connected")
				send_packet_to_id(peer_id, packets.COUNTDOWN_REGISTRATION, null)
				yield(get_tree().create_timer(timeout_in_seconds), "timeout") # Wait if user hasn't timed out
				
				if !is_player_registered(peer_id):
					if is_peer_connected(peer_id):
						print("Incoming connection from [" + peer_ip + "] ID (" + str(peer_id) + ") was dropped due to registration timeout (" + str(timeout_in_seconds) + "s).")
						kick_player(1, peer_id, "Registration timeout.", true)
	if packet_id == packets.REQUEST_UPDATE_PLAYER_DATA:
		if has_and_is_server():
			print("requesting update")
			var result = true
			var reason = "No reason specified."
			var player_name = packet_data["player_name"]
			
			if player_name in get_player_names():
				reason = "Someone is already logged in with this name."
				result = false
			
			if result:
				packet_data["admin"] = false
				if player_name in admins: packet_data["admin"] = true
				if !is_player_registered(peer_id):
					send_packet_to_id(peer_id, packets.WELCOME_CONNECTION, null)
				
				send_packet_to_id(peer_id, packets.UPDATE_CONFIRMED, null)
				players[peer_id] = packet_data
				send_packet_to_everyone(packets.UPDATE_PLAYER_DATA, players)
			else:
				if !is_player_registered(peer_id):
					kick_player(1, peer_id, "Registration failed.\nReason: " + reason, true)
	if packet_id == packets.UPDATE_PLAYER_DATA:
		players = packet_data

# Server Side

func get_player_names():
	var names = []
	
	for player in players:
		names.append(player["player_name"])
	
	return names

func is_peer_connected(peer_id):
	var result = false
	
	if peer_id in get_tree().get_network_connected_peers(): result = true
	
	return result

func is_player_registered(peer_id):
	var result = false
	
	if players.has(peer_id): result = true
	
	return result

func is_player_banned(player_id : int): # Ban by IP as example
	var peer_ip = peer.get_peer_address(player_id)
	
	return bans.has(peer_ip)

func create_server():
	print("Created server")
	clear_connection()
	
	peer.create_server(server_port, max_players)
	bind_peer()

func has_authority(player_id : int): # Authority can only be seen by Server.
	var result = false
	
	if player_id == 1: # Server automatically has assigned authority
		result = true
	else:
		result = players[player_id]["is_admin"]
	
	return result

func kick_player(author_id : int, player_id : int, reason : String, is_disconnection : bool = false):
	if has_and_is_server() and has_authority(author_id):
		var message = ""
		if !is_peer_server(author_id):
			message = "You were kicked by " + players[author_id]["player_name"] + ".\nReason: " + reason
		
		if is_disconnection:
			message = "You were disconnected from server.\nReason: " + reason
		
		send_packet_to_id(player_id, packets.INFORM_DISCONNECTION, message)
		peer.disconnect_peer(player_id, false)

func ban_player(author_id : int, player_id : int, reason : String): 
	if has_and_is_server() and has_authority(author_id):
		var peer_ip = peer.get_peer_address(player_id)
		bans[peer_ip] = {"author":author_id,"reason":reason}
		
		send_packet_to_id(player_id, packets.INFORM_DISCONNECTION,"You were banned by " + players[author_id]["player_name"] + ".\nReason: " + reason)
		peer.disconnect_peer(player_id, false)

func process_connection(player_id):
	var passed = true
	
	if is_player_banned(player_id) and has_and_is_server():
		send_packet_to_id(player_id, packets.INFORM_DISCONNECTION,"You are banned.\nReason: " + bans[peer.get_peer_address(player_id)]["reason"])
		peer.disconnect_peer(player_id, false)
		passed = false
	
	return passed

func player_connected(player_id):
	pass

func player_disconnected(player_id):
	players.erase(player_id)

func kick_all(reason : String, is_disconnection : bool = false):
	for player_id in players.keys():
		kick_player(1, player_id, reason, is_disconnection)

func on_close():
	kick_all("Server closed", true)

func close_server():
	clear_connection()

# Client Side

func connect_to_server(ip_address : String):
	clear_connection()
	
	peer.create_client(ip_address, server_port)
	bind_peer()

func connected_ok():
	# Wait to get accepted by server.
	pass

func connected_fail():
	# Do whatever happens when we cant connect.
	clear_connection()
	print("Connection terminated: Failed connection")

func server_disconnected():
	# Server kicked us. Sad.
	print("Connection terminated: Disconnected from server")
