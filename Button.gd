extends Button

var packets = Network.packets

func _ready():
	Network.connect("packet_recieved", self, "packet_recieved")
	connect("pressed", self, "go_connect")
	get_tree().connect("connected_to_server", self, "send_information")

func go_connect():
	Network.connect_to_server("127.0.0.1")

func send_information():
	Network.send_packet_to_id(1, packets.ASK_CONNECTION, null)

func send_registration():
	Network.send_packet_to_id(1, packets.REQUEST_UPDATE_PLAYER_DATA, {"player_name":str(randi())})

func packet_recieved(peer_id, packet_id, packet_data):
	if packet_id == packets.COUNTDOWN_REGISTRATION:
		print("counting down registration!")
		send_registration()
	if packet_id == packets.UPDATE_CONFIRMED:
		print("Welcome! Connected successfully.")

func _process(delta):
	pass
