class_name SystemInfo
extends RefCounted

# TODO: I don't think this a standard on every distro. Probably need to check other places
const WAYLAND_SESSIONS_PATH := "/usr/share/wayland-sessions/"
# NOTE: not sure if these values are always correct
const MIN_USER_ID := 1000
const MAX_USER_ID := 60000


static func get_users() -> Array[String]:
	# HACK: Use fake data for debugging
	if not OS.has_feature("linux") or OS.has_feature("editor"):
		return ["mocky", "stubby", "faky"]

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
