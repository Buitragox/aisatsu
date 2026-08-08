extends Node


func _ready() -> void:
	# TODO: might remove this and make it start fullscreen from the start
	if OS.has_feature("template"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	_init_sessions()
	_init_users()

	%AuthAnswer.text_submitted.connect(_on_auth_answer_submitted)
	%LogIn.pressed.connect(_on_login_pressed)
	%SessionSelect.item_selected.connect(_on_session_selected)
	%Username.item_selected.connect(_on_user_selected)
	%Shutdown.pressed.connect(_on_shutdown_pressed)
	%Restart.pressed.connect(_on_restart_pressed)

	Greeter.auth_prompt_received.connect(_on_auth_prompt_received)
	Greeter.auth_completed.connect(_on_auth_completed)
	Greeter.login_failed.connect(_on_login_failed)
	Greeter.session_started.connect(_on_session_started)
	Greeter.error.connect(_on_error)

	%AuthAnswer.grab_focus() # Automatically focus the password field for quick login.
	get_tree().set_auto_accept_quit(false) # Handle quit manually


func _process(_delta: float) -> void:
	# TODO: should add config for 24 or 12 hour style clock
	var time_data := Time.get_time_dict_from_system()
	var hour := time_data["hour"] as int
	var period := "AM"
	if hour > 12:
		hour -= 12
		period = "PM"
	var time := "%02d:%02d %s" % [hour, time_data["minute"], period]

	%Clock.text = time


## Manually handle app closing.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _on_login_pressed() -> void:
	_set_ui_enabled(false)
	%Alert.text = "Authenticating..."

	var username: String = %Username.text
	Greeter.login(username)


func _on_auth_prompt_received(message: String, type: GreetdAuthMessage.Type) -> void:
	_log_info("%s - %s" % [GreetdAuthMessage.Type.keys()[type], message])

	if type == GreetdAuthMessage.Type.SECRET or type == GreetdAuthMessage.Type.VISIBLE:
		var input: String = %AuthAnswer.text
		Greeter.submit_input(input)
	else:
		# Acknowledge PAM Info/Error messages automatically (send empty response)
		_log_info("PAM message: %s" % message)
		Greeter.submit_input("")


func _on_auth_completed() -> void:
	_log_info("Authentication successful")

	var cmd: String = %SessionSelect.get_selected_metadata()
	Greeter.start_session([cmd])


func _on_login_failed(reason: String) -> void:
	%Alert.text = reason
	_log_info(reason)
	_set_ui_enabled(true)
	%AuthAnswer.grab_focus()


func _on_session_started() -> void:
	_log_info("Session started")
	_quit()


func _on_error(description: String) -> void:
	%Alert.text = description
	_log_info(description)
	_set_ui_enabled(true)
	%AuthAnswer.grab_focus()


# Get the list of users and select the last user that logged in.
func _init_users():
	var last_user: String = Config.last_user
	var users := SystemInfo.get_users()

	for i in range(users.size()):
		var user := users[i]
		%Username.add_item(user)
		if user == last_user:
			%Username.select(i)


# Get a list of sessions and select the last used session.
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
	_on_login_pressed()


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
