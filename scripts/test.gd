extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#var client := GreetdClient.new()
	#client.connect_to_socket()
	#client.create_session("random")
	printerr("Hello what is this")

	var arr := PackedStringArray(["hey", "wassap", "yo"])

	print(JSON.stringify({ "foo": arr }))
	print(SystemInfo.get_users())
	print(SystemInfo.get_wayland_sessions())
