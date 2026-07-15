class_name GreetdResponse
extends RefCounted

enum Type {
	SUCCESS,
	AUTH_MESSAGE,
	GREETD_ERROR,
	CLIENT_ERROR,
}

enum AuthMessageType {
	NONE,
	VISIBLE,
	SECRET,
	INFO,
	ERROR,
}

enum GreetdErrorType {
	NONE,
	GENERAL,
	AUTH,
}
 
var type: Type
var message := ""
var auth_message_type := AuthMessageType.NONE
var greetd_error_type := GreetdErrorType.NONE
var error_code: Error = OK


func _init(p_type: Type) -> void:
	type = p_type


static func success() -> GreetdResponse:
	return GreetdResponse.new(Type.SUCCESS)


static func auth_message(
	p_auth_message_type: AuthMessageType,
	p_message: String,
) -> GreetdResponse:
	var response := GreetdResponse.new(Type.AUTH_MESSAGE)
	response.auth_message_type = p_auth_message_type
	response.message = p_message
	return response


static func greetd_error(
	p_greetd_error_type: GreetdErrorType,
	p_message: String,
) -> GreetdResponse:
	var response := GreetdResponse.new(Type.GREETD_ERROR)
	response.greetd_error_type = p_greetd_error_type
	response.message = p_message
	return response


static func client_error(p_error_code: Error, p_message: String) -> GreetdResponse:
	var response := GreetdResponse.new(Type.CLIENT_ERROR)
	response.error_code = p_error_code
	response.message = p_message
	return response
