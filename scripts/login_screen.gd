extends Node

# TODO: implement state validation
var client := GreetdClient.new()
var is_authenticating := false


func _ready() -> void:
	# TODO: might remove this and make it start fullscreen from the start
	if OS.has_feature("template"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	add_child(client)

	_init_sessions()
	_init_users()

	%AuthAnswer.text_submitted.connect(_on_auth_answer_submitted)
	%LogIn.pressed.connect(login)
	%SessionSelect.item_selected.connect(_on_session_selected)
	%Username.item_selected.connect(_on_user_selected)
	%Shutdown.pressed.connect(_on_shutdown_pressed)
	%Restart.pressed.connect(_on_restart_pressed)

	%AuthAnswer.grab_focus() # Automatically focus the password field for quick login.
	get_tree().set_auto_accept_quit(false) # Handle quit manually


## Manually handle app closing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func login() -> void:
	# Prevent multiple simultaneous login attempts
	if is_authenticating:
		return

	is_authenticating = true
	_set_ui_enabled(false)
	%Alert.text = "Authenticating..."

	var username: String = %Username.text
	var password: String = %AuthAnswer.text
	var response := await client.create_session(username)

	if response is GreetdError:
		%Alert.text = response.error_description
		_log_info(response.error_description)
		is_authenticating = false
		_set_ui_enabled(true)
		return
	elif response is GreetdAuthMessage:
		_log_info("%s - %s" % [response.auth_message_type_string(), response.auth_message])
	else:
		# TODO if the response is a success then we can start the session
		# How does that happen? Users without passwords?
		pass

	_log_info("Session created")

	response = await client.answer_auth_message(password)

	_on_auth_complete(response)


func cancel_session() -> void:
	var response := await client.cancel_session()
	if response is GreetdError:
		_log_info(response.error_description)
		return

	%AuthAnswer.call_deferred("grab_focus")
	_log_info("Canceled successfully")


## Get the list of users and select the last user that logged in.
func _init_users():
	var last_user: String = Config.last_user
	var users := SystemInfo.get_users()

	for i in range(users.size()):
		var user := users[i]
		%Username.add_item(user)
		if user == last_user:
			%Username.select(i)


## Get a list of sessions and select the last used session.
func _init_sessions():
	var last_session = Config.last_session

	var sessions := SystemInfo.get_wayland_sessions()
	var index = 0
	for session in sessions:
		%SessionSelect.add_item(session["Name"])
		# TODO: maybe split Exec into an array of args
		# works without it but I think it's the correct thing to do
		%SessionSelect.set_item_metadata(index, session["Exec"])
		index += 1
		if session["Name"] == last_session:
			%SessionSelect.select(%SessionSelect.item_count - 1)


## Save the current selected session as the last one.
func _on_session_selected(_index: int):
	Config.last_session = %SessionSelect.text


## Save the selected user as the last one.
func _on_user_selected(_index: int):
	var user = %Username.text
	Config.last_user = user


## When pressing "Enter" run the login
func _on_auth_answer_submitted(_password):
	login()


func _on_auth_complete(response: GreetdResponse) -> void:
	if response is GreetdError:
		%Alert.text = response.error_description
		_log_info(response.error_description)
		cancel_session()
		is_authenticating = false
		_set_ui_enabled(true)
		return
	elif response is GreetdAuthMessage:
		# TODO: Instead of canceling the session, we should continue asking for stuff if necessary
		_log_info(
			"GreetdAuthMessage: %s - %s" % [response.auth_message_type, response.auth_message]
		)
		cancel_session()
		is_authenticating = false
		_set_ui_enabled(true)
		return
	else:
		_log_info("Auth answered")

	# TODO: Only do this if the answer is a success
	var cmd = %SessionSelect.get_selected_metadata()
	response = await client.start_session([cmd])
	if response is GreetdError or response is GreetdClientError:
		%Alert.text = response.error_description
		_log_info(response.error_description)
		cancel_session()
		is_authenticating = false
		_set_ui_enabled(true)
		return

	_log_info("Session started")
	_quit()


func _set_ui_enabled(enabled: bool) -> void:
	%LogIn.disabled = not enabled
	%AuthAnswer.editable = enabled
	%Username.disabled = not enabled
	%SessionSelect.disabled = not enabled


func _log_info(text: String) -> void:
	%Log.add_text(text + "\n")


## Save config and quit
func _quit() -> void:
	Config.save()
	get_tree().quit()


func _on_shutdown_pressed():
	OS.execute("shutdown", ["now"])


func _on_restart_pressed():
	OS.execute("shutdown", ["-r", "now"])
