class_name Greeter
extends RefCounted

var socket_path := OS.get_environment("GREETD_SOCK")


func _init() -> void:
	if OS.is_debug_build() and socket_path.is_empty():
		socket_path = "/tmp/mock_greetd.sock"


func create_session(username: String) -> GreetdResponse:
	return _send_request({"type": "create_session", "username": username})


#func answer_auth_message(answer: Variant) -> GreetdResponse:
	#return _send_request({"type": "create_session", "username": username})


func _send_request(request: Dictionary) -> GreetdResponse:
	var stream := StreamPeerUDS.new()
	var error := stream.connect_to_host(socket_path)
	if error != OK:
		return GreetdResponse.client_error(
			error,
			"Failed to connect to greetd: %s" % error_string(error),
		)

	stream.put_utf8_string(JSON.stringify(request))
	var json_response := stream.get_utf8_string()
	stream.disconnect_from_host()

	var json := JSON.new()
	error = json.parse(json_response)
	if error != OK:
		return GreetdResponse.client_error(
			error,
			"Invalid JSON in greetd response at line %d: %s"
			% [json.get_error_line(), json.get_error_message()],
		)

	if typeof(json.data) != TYPE_DICTIONARY:
		return GreetdResponse.client_error(
			ERR_INVALID_DATA,
			"Expected a JSON object from greetd",
		)

	var data: Dictionary = json.data
	return _parse_response(data)


func _parse_response(data: Dictionary) -> GreetdResponse:
	var response_type: Variant = data.get("type")
	if response_type is not String:
		return GreetdResponse.client_error(
			ERR_INVALID_DATA,
			"Missing or invalid 'type' in greetd response",
		)

	match response_type:
		"success":
			return GreetdResponse.success()

		"auth_message":
			var message_type: Variant = data.get("auth_message_type")
			var message: Variant = data.get("auth_message")
			if not message_type is String or not message is String:
				return GreetdResponse.client_error(
					ERR_INVALID_DATA,
					"Invalid auth_message response",
				)

			var parsed_message_type := _parse_auth_message_type(message_type)
			if parsed_message_type == GreetdResponse.AuthMessageType.NONE:
				return GreetdResponse.client_error(
					ERR_INVALID_DATA,
					"Unknown auth message type: %s" % message_type,
				)

			return GreetdResponse.auth_message(parsed_message_type, message)

		"error":
			var error_type: Variant = data.get("error_type")
			var description: Variant = data.get("description")
			if not error_type is String or not description is String:
				return GreetdResponse.client_error(
					ERR_INVALID_DATA,
					"Invalid error response from greetd",
				)

			var parsed_error_type := _parse_greetd_error_type(error_type)
			if parsed_error_type == GreetdResponse.GreetdErrorType.NONE:
				return GreetdResponse.client_error(
					ERR_INVALID_DATA,
					"Unknown greetd error type: %s" % error_type,
				)

			return GreetdResponse.greetd_error(parsed_error_type, description)

		_:
			return GreetdResponse.client_error(
				ERR_INVALID_DATA,
				"Unknown greetd response type: %s" % response_type,
			)


func _parse_auth_message_type(value: String) -> GreetdResponse.AuthMessageType:
	match value:
		"visible":
			return GreetdResponse.AuthMessageType.VISIBLE
		"secret":
			return GreetdResponse.AuthMessageType.SECRET
		"info":
			return GreetdResponse.AuthMessageType.INFO
		"error":
			return GreetdResponse.AuthMessageType.ERROR
		_:
			return GreetdResponse.AuthMessageType.NONE


func _parse_greetd_error_type(value: String) -> GreetdResponse.GreetdErrorType:
	match value:
		"error":
			return GreetdResponse.GreetdErrorType.GENERAL
		"auth_error":
			return GreetdResponse.GreetdErrorType.AUTH
		_:
			return GreetdResponse.GreetdErrorType.NONE
