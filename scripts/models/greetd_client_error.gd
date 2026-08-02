class_name GreetdClientError
extends GreetdResponse

var error_code: Error
var error_description: String


func _init(p_error_code: Error, p_description: String) -> void:
	error_code = p_error_code
	error_description = p_description
