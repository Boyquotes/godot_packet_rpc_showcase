# godot_packet_rpc_showcase
Godot Packet RPC Showcase

Cool concept I've made for fun.

The Network global singleton handles the packet reception/sending. Emits a signal when a packet is recieved.
Uses packets in a general form of:
```gdscript
packet_id : int
packet_data : Variant
```
**Packet ids** are all specified in the Network.packets enum.

There are some functions to check out if its a server, if the client is registered and much more.
By default, this template includes a basic connection/hosting (including a checking ban system) and a registration system (registers a player's name) with a button to connect to localhost.

# Usage
## Client connecting
Start the project and click on the connect button to connect to localhost (127.0.0.1) with port 12345.
## Server hosting
Run the project with the command line argument "--host" in order to host a server.
## Sending packets
Four default methods are made for sending packets:
```gdscript
Network.send_packet_to_everyone(packet_id : int, packet_data)
Network.send_packet_to_id(target_id : int, packet_id : int, packet_data)
Network.send_fast_packet_to_everyone(packet_id : int, packet_data)
Network.send_fast_packet_to_id(target_id : int, packet_id : int, packet_data)
```
Sending **regular packets** will make sure they arrive to their destinaries, but too much regular packets can slow down performance.

**Fast packets** will deliver fast packets that can get lost (movement, rotation etc...).
## Grabbing and handling packets
Connect the Network's singleton "packet_recieved" signal to intercept when a packet got recieved.
It is made of 3 arguments:
```gdscript
# packet_recieved(peer_id : int, packet_id : int, packet_data)
Network.connect("packet_recieved", self, "packet_recieved")
func packet_recieved(peer_id, packet_id, packet_data):
  if packet_id == Network.packets.UPDATE_CONFIRMED:
    print("Welcome! Connected successfully.")
```
It is made to be as much as beginner-friendly as possible and can be largely expanded. All extra ENet signals can be connected (atleast for some exceptions, see how conecting/registration works).

# Conclusion
This project is perfect for those who are used to low-level Sockets and Godot's RPC Networking system without having to setup the annoying and confusing authority stuff and replicating nodes.
It's a very general example use and can be modified how you may feel like.
