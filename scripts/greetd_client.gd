## Low-level async greetd IPC client. Each call opens and closes a socket connection.
##
## Needs to be added to the SceneTree to access [code]get_tree().process_frame[/code] for async functionality.
## [br][br]
## Uses the [code]GREETD_SOCK[/code] environment variable as the [member socket_path] by default.
## [br][br]
## If [member socket_path] is empty and it's running a debug build,it will try to connect to [code]"/tmp/mock_greetd.sock"[/code],
## which is the path used by the [code]"mock_server.py"[/code] script.
# TODO: I should probably create an integrated mock client for easier debugging instead of it being in a separate python script.
class_name GreetdClient
extends Node

var socket_path: String
var _stream := StreamPeerUDS.new()


func _init(p_socket_path: String = "") -> void:
	socket_path = p_socket_path

	if socket_path.is_empty():
		socket_path = OS.get_environment("GREETD_SOCK")

	if OS.is_debug_build() and socket_path.is_empty():
		socket_path = "/tmp/mock_greetd.sock"


func create_session(username: String) -> GreetdResponse:
	return await _send_request({ "type": "create_session", "username": username })


func answer_auth_message(answer: Variant) -> GreetdResponse:
	var answer_type := typeof(answer)
	if answer_type != TYPE_NIL and answer_type != TYPE_STRING:
		return GreetdClientError.new(
			ERR_INVALID_PARAMETER,
			"Parameter 'answer' must be String or null; got %s" % type_string(answer_type),
		)

	return await _send_request({ "type": "post_auth_message_response", "response": answer })


func start_session(cmd: Array[String], env: Array[String] = []) -> GreetdResponse:
	return await _send_request({ "type": "start_session", "cmd": cmd, "env": env })


func cancel_session() -> GreetdResponse:
	return await _send_request({ "type": "cancel_session" })


func _send_request(request: Dictionary) -> GreetdResponse:
	var error := await _connect_to_host()
	if error != OK:
		return GreetdClientError.new(error, "Failed to connect to greetd: %s" % error_string(error))

	_stream.put_utf8_string(JSON.stringify(request))

	# NOTE: Some requests may take a long time to get a response.
	# For example, if you answer an auth message with the wrong password
	# greetd will take around 3 seconds to answer.
	while _stream.get_available_bytes() == 0:
		await get_tree().process_frame

	var json_response := _stream.get_utf8_string()

	_stream.disconnect_from_host()

	var json := JSON.new()
	error = json.parse(json_response)
	if error != OK:
		return GreetdClientError.new(
			error,
			"Invalid JSON in greetd response: %s" % json.get_error_message(),
		)

	if typeof(json.data) != TYPE_DICTIONARY:
		return GreetdClientError.new(
			ERR_INVALID_DATA,
			"Expected a JSON object from greetd but got '%s'" % type_string(json.data),
		)

	var data: Dictionary = json.data
	return _parse_response(data)


func _parse_response(data: Dictionary) -> GreetdResponse:
	var response_type: Variant = data.get("type")
	if response_type is not String:
		return GreetdClientError.new(
			ERR_INVALID_DATA,
			"Missing or invalid 'type' in greetd response",
		)

	match response_type:
		"success":
			return GreetdSuccess.new()
		"auth_message":
			var message_type: Variant = data.get("auth_message_type")
			var message: Variant = data.get("auth_message")
			if not message_type is String or not message is String:
				return GreetdClientError.new(ERR_INVALID_DATA, "Invalid auth_message response")

			var parsed_type := _parse_auth_message_type(message_type)
			if parsed_type == -1:
				return GreetdClientError.new(
					ERR_INVALID_DATA,
					"Unknown auth message type: %s" % message_type,
				)

			return GreetdAuthMessage.new(parsed_type as GreetdAuthMessage.Type, message)
		"error":
			var error_type: Variant = data.get("error_type")
			var description: Variant = data.get("description")
			if not error_type is String or not description is String:
				return GreetdClientError.new(ERR_INVALID_DATA, "Invalid error response from greetd")

			var parsed_error_type := _parse_greetd_error_type(error_type)
			if parsed_error_type == -1:
				return GreetdClientError.new(
					ERR_INVALID_DATA,
					"Unknown greetd error type: %s" % error_type,
				)

			return GreetdError.new(parsed_error_type as GreetdError.Type, description)
		_:
			return GreetdClientError.new(
				ERR_INVALID_DATA,
				"Unknown greetd response type: %s" % response_type,
			)


func _connect_to_host() -> Error:
	var error := _stream.connect_to_host(socket_path)
	if error != OK:
		return error

	while _stream.get_status() == StreamPeerUDS.STATUS_CONNECTING:
		# TODO: print for debugging, remove later
		print_debug("I'm connecting!")
		await get_tree().process_frame
		_stream.poll()

	if _stream.get_status() != StreamPeerUDS.STATUS_CONNECTED:
		return ERR_CANT_CONNECT

	return OK


func _parse_auth_message_type(value: String) -> int:
	match value:
		"visible":
			return GreetdAuthMessage.Type.VISIBLE
		"secret":
			return GreetdAuthMessage.Type.SECRET
		"info":
			return GreetdAuthMessage.Type.INFO
		"error":
			return GreetdAuthMessage.Type.ERROR
		_:
			return -1


func _parse_greetd_error_type(value: String) -> int:
	match value:
		"error":
			return GreetdError.Type.GENERAL
		"auth_error":
			return GreetdError.Type.AUTH
		_:
			return -1
