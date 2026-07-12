extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var greeter := Greeter.new()
	greeter.create_session("random")
