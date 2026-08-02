class_name GreetdAuthMessage
extends GreetdResponse

enum Type {
	VISIBLE,
	SECRET,
	INFO,
	ERROR,
}

var auth_message_type: Type
var auth_message: String


func _init(p_type: Type, p_message: String) -> void:
	auth_message_type = p_type
	auth_message = p_message


## Returns the auth_message_type property as a String
func auth_message_type_string() -> String:
	return Type.keys()[auth_message_type]
