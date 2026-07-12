extends Node

const CONFIG_PATH = "user://config.cfg"
var greeter := GreetdGreeter.new()
var config := ConfigFile.new()
var auth_thread: Thread = null
var is_authenticating := false


func _ready() -> void:
	var err := config.load(CONFIG_PATH)
	if err != Error.OK:
		printerr("Failed to open config.cfg")

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


## Get the list of users and select the last user that logged in.
func _init_users():
	var last_user: String = config.get_value("General", "last_user", "")
	var users := greeter.get_users()

	for i in range(users.size()):
		var user := users[i]
		%Username.add_item(user)
		if user == last_user:
			%Username.select(i)


## Get a list of sessions and select the last used session.
func _init_sessions():
	var last_session = config.get_value("General", "last_session", "")

	var sessions := greeter.get_wayland_sessions()
	var index = 0
	for session in sessions:
		%SessionSelect.add_item(session["Name"])
		%SessionSelect.set_item_metadata(index, session["Exec"])
		index += 1
		if session["Name"] == last_session:
			%SessionSelect.select(%SessionSelect.item_count - 1)


## Save the current selected session as the last one.
func _on_session_selected(_index: int):
	var session = %SessionSelect.text
	config.set_value("General", "last_session", session)


## Save the selected user as the last one.
func _on_user_selected(_index: int):
	var user = %Username.text
	config.set_value("General", "last_user", user)


## When pressing "Enter" run the login
func _on_auth_answer_submitted(_password):
	login()


func login() -> void:
	# Prevent multiple simultaneous login attempts
	if is_authenticating:
		return

	is_authenticating = true
	_set_ui_enabled(false)
	%Alert.text = "Authenticating..."

	var username: String = %Username.text
	var password: String = %AuthAnswer.text
	var response := greeter.create_session(username)

	if response is GreetdError:
		%Alert.text = response.error_description
		_log_info(response.error_description)
		is_authenticating = false
		_set_ui_enabled(true)
		return
	elif response is GreetdAuthMessage:
		_log_info("%s - %s" % [response.auth_message_type, response.auth_message])
	else:
		# TODO if the response is a success then we can start the session
		# How does that happen? Users without passwords?
		pass

	_log_info("Session created")

	# Run the blocking authentication on a separate thread
	auth_thread = Thread.new()
	auth_thread.start(_authenticate_thread.bind(password))


func _authenticate_thread(password: String) -> void:
	var response = greeter.answer_auth_message(password)
	# Call back to main thread to handle the response
	call_deferred("_on_auth_complete", response)


func _on_auth_complete(response: GreetdResponse) -> void:
	# Clean up the thread
	if auth_thread:
		auth_thread.wait_to_finish()
		auth_thread = null

	if response is GreetdError:
		%Alert.text = response.error_description
		_log_info(response.error_description)
		cancel_session()
		is_authenticating = false
		_set_ui_enabled(true)
		return
	elif response is GreetdAuthMessage:
		# TODO: Instead of canceling the session, we should continue asking for stuff if necessary
		_log_info("GreetdAuthMessage: %s - %s" % [response.auth_message_type, response.auth_message])
		cancel_session()
		is_authenticating = false
		_set_ui_enabled(true)
		return
	else:
		_log_info("Auth answered")

	# TODO: Only do this if the answer is a success
	var cmd = %SessionSelect.get_selected_metadata()
	response = greeter.start_session(cmd)
	if response is GreetdError:
		%Alert.text = response.error_description
		_log_info(response.error_description)
		cancel_session()
		is_authenticating = false
		_set_ui_enabled(true)
		return

	_log_info("Session started")
	_quit()


func cancel_session() -> void:
	var response := greeter.cancel_session()
	if response is GreetdError:
		_log_info(response.error_description)
		return

	%AuthAnswer.call_deferred("grab_focus")
	_log_info("Cancelled successfully")


func _set_ui_enabled(enabled: bool) -> void:
	%LogIn.disabled = not enabled
	%AuthAnswer.editable = enabled
	%Username.disabled = not enabled
	%SessionSelect.disabled = not enabled


func _log_info(text: String) -> void:
	%Log.add_text(text + "\n")


## Manually handle app closing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


## Save config and quit
func _quit() -> void:
	config.save(CONFIG_PATH)
	get_tree().quit()


func _on_shutdown_pressed():
	OS.execute("shutdown", ["now"])


func _on_restart_pressed():
	OS.execute("shutdown", ["-r", "now"])
