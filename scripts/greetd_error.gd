class_name GreetdError
extends GreetdResponse

enum Type {
	GENERAL,
	AUTH,
}

var error_type: Type
var error_description: String


func _init(p_type: Type, p_description: String) -> void:
	error_type = p_type
	error_description = p_description
