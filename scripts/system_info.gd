class_name SystemInfo
extends RefCounted

# TODO: Implement X11 sessions?
# TODO: I don't think this a standard on every distro. Probably need to check other places
const WAYLAND_SESSIONS_PATH := "/usr/share/wayland-sessions/"
# NOTE: not sure if these values are always correct
const MIN_USER_ID := 1000
const MAX_USER_ID := 60000


static func get_users() -> Array[String]:
	# HACK: Use fake data for debugging
	if not OS.has_feature("linux") or OS.has_feature("editor"):
		return ["fakeuser", "stubby", "godoty"]

	var output: Array[String] = []
	var exit_code := OS.execute("getent", PackedStringArray(["passwd"]), output)

	if exit_code != 0:
		push_error("Failed to read system users. Exit code: %d" % exit_code)
		return []

	var data := output[0].split("\n", false)
	var users: Array[String] = []

	for line in data:
		var fields := line.split(":", true)
		var name := fields[0]
		var uid := int(fields[2])

		if uid >= MIN_USER_ID and uid <= MAX_USER_ID:
			users.append(name)

	return users


# NOTE: very simple .desktop file parsing. Maybe it will be necessary to improve
# this later.
## Searches for wayland sessions in "/usr/share/wayland-sessions/" and
## performs a very simple parsing of .desktop files.[br][br]
## Returns an array of dictionaries where each dictionary has the desktop file keys.
static func get_wayland_sessions() -> Array[Dictionary]:
	# HACK: Use fake data for debugging
	if not OS.has_feature("linux") or OS.has_feature("editor"):
		return _stub_wayland_sessions()

	var sessions: Array[Dictionary] = []

	var dir := DirAccess.open(WAYLAND_SESSIONS_PATH)
	if not dir:
		var error := DirAccess.get_open_error()
		push_error("Failed to open \"%s\": %s" % [WAYLAND_SESSIONS_PATH, error_string(error)])
		return sessions

	for file_name in dir.get_files():
		var file_path := WAYLAND_SESSIONS_PATH + file_name
		var file := FileAccess.open(file_path, FileAccess.READ)

		if not file:
			var error := FileAccess.get_open_error()
			push_error("Failed to open \"%s\": %s" % [file_path, error_string(error)])
			continue

		var session := _parse_desktop_file(file)
		sessions.append(session)

	return sessions


static func _parse_desktop_file(file: FileAccess) -> Dictionary:
	var session := { }
	var length := file.get_length()
	while file.get_position() < length:
		var line := file.get_line()

		# Skip comments
		if line.begins_with("#"):
			continue
		# Skip section declaration
		if line.begins_with("["):
			continue
		if line.is_empty():
			continue

		var key_value := line.split("=", true, 1)
		session[key_value[0]] = key_value[1]

	return session


static func _stub_wayland_sessions() -> Array[Dictionary]:
	return [
		{
			"Name": "MockPlasma (Wayland)",
			"Exec": "/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland",
		},
		{
			"Name": "MockHyprland",
			"Exec": "/usr/bin/start-hyprland",
		},
		{
			"Name": "MockSway",
			"Exec": "sway",
		},
	]
