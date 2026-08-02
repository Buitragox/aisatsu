## High-level greetd session orchestrator. Manages the authentication state machine
## and emits signals for UI to react to.
##
## Intended to be used as an autoload. Call [method login], [method submit_input],
## [method start_session], and [method cancel] to drive the authentication flow.
## Connect to signals to update UI.
## [br][br]
## Example usage:
## [codeblock]
## Greeter.login("alice")
## # ... wait for auth_prompt_received signal ...
## Greeter.submit_input("password123")
## # ... wait for auth_completed signal ...
## Greeter.start_session(["sway"])
## [/codeblock]
extends Node

enum State {
	IDLE, ## No session in progress. Can call [method login].
	AWAITING_INPUT, ## greetd sent an auth prompt, waiting for user input. Can call [method submit_input] or [method cancel].
	AUTHENTICATED, ## Authentication succeeded. Can call [method start_session] or [method cancel].
}

## Emitted when greetd requests input from the user (password, OTP, etc.) or 
## for PAM info/error messages that don't require input but need to be acknowledged.[br][br]
signal auth_prompt_received(message: String, type: GreetdAuthMessage.Type)

## Emitted when authentication succeeds. Call [method start_session] to launch the session.
signal auth_completed

## Emitted when authentication is rejected (wrong password, etc.).
## [br][br] 
## State resets to [constant IDLE] and you need to restart the flow again with [method login]
signal login_failed(reason: String)

## Emitted when the session has been successfully started. The greeter should save config and quit.
signal session_started

## Emitted on client or protocol errors (socket failure, malformed response, etc.).
## [br][br]
## Distinct from [signal login_failed]. This indicates a system-level problem, not a wrong password.
## [br][br]
## State resets to [constant IDLE] and you need to restart the flow again with [method login]
signal error(description: String)

## Current authentication state.
var state: State = State.IDLE

var _client: GreetdClient


func _ready() -> void:
	_client = GreetdClient.new()
	add_child(_client)
	# Cancel any lingering session from a previous greeter instance.
	cancel.call_deferred()


## Begin authentication for [param username].
## Only valid when state is [constant IDLE]. Ignored otherwise.
func login(username: String) -> void:
	if state != State.IDLE:
		return

	var response := await _client.create_session(username)

	if response is GreetdSuccess:
		state = State.AUTHENTICATED
		auth_completed.emit()
	elif response is GreetdAuthMessage:
		state = State.AWAITING_INPUT
		auth_prompt_received.emit(response.auth_message, response.auth_message_type)
	elif response is GreetdError:
		_handle_greetd_error(response)
	elif response is GreetdClientError:
		_handle_client_error(response)


## Submit input in response to an auth prompt (password, OTP, etc.).
## [br][br]
## Only valid when state is [constant AWAITING_INPUT]. Ignored otherwise.
func submit_input(input: String) -> void:
	if state != State.AWAITING_INPUT:
		return

	var response := await _client.answer_auth_message(input)

	if response is GreetdSuccess:
		state = State.AUTHENTICATED
		auth_completed.emit()
	elif response is GreetdAuthMessage:
		# Multi-step auth: stay in AWAITING_INPUT and prompt again
		auth_prompt_received.emit(response.auth_message, response.auth_message_type)
	elif response is GreetdError:
		_handle_greetd_error(response)
	else:
		_handle_client_error(response as GreetdClientError)


## Start the session with the given command. Optionally pass environment variables.
## Only valid when state is [constant AUTHENTICATED].
func start_session(cmd: Array[String], env: Array[String] = []) -> void:
	if state != State.AUTHENTICATED:
		return

	var response := await _client.start_session(cmd, env)

	if response is GreetdSuccess:
		session_started.emit()
	elif response is GreetdError:
		_handle_greetd_error(response)
	elif response is GreetdClientError:
		_handle_client_error(response)


## Cancel the current session and reset to [constant IDLE].
## [br][br]
## Valid in [constant AWAITING_INPUT] and [constant AUTHENTICATED]. No-op in [constant IDLE].
func cancel() -> void:
	await _client.cancel_session()
	state = State.IDLE


func _handle_greetd_error(err: GreetdError) -> void:
	if err.error_type == GreetdError.Type.AUTH:
		# Auth errors auto-cancel the session in greetd, no need to send cancel.
		state = State.IDLE
		login_failed.emit(err.error_description)
	else:
		state = State.IDLE
		error.emit(err.error_description)


func _handle_client_error(err: GreetdClientError) -> void:
	state = State.IDLE
	error.emit(err.error_description)
