class_name Greeter
extends Node

#enum {IDLE, AWAITING_AUTH, READY}
#var state := IDLE

var stream := StreamPeerUDS.new()
var socket_path := OS.get_environment("GREETD_SOCK")


func _init() -> void:
	if OS.is_debug_build() and socket_path.is_empty():
		socket_path = "/tmp/mock_greetd.sock"
	
	var error := stream.connect_to_host(socket_path)
	print("FROM INIT:", error_string(error))
	
	if error != Error.OK:
		printerr(error_string(error))


func create_session(username: String):
	var request := { "type": "create_session", "username": username }
	var json_string := JSON.stringify(request)
	print(stream.get_status())
	print(json_string)
	stream.put_utf8_string(json_string)
	
	print(stream.get_status())
	
	#var error := stream.poll()
	#if error != Error.OK:
	
	#print(error_string(error))
	
	
	
	
