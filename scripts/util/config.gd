extends Node

const CONFIG_PATH = "user://config.cfg"

var _config := ConfigFile.new()
var last_user: String:
	get = _get_last_user, set = _set_last_user
var last_session: String:
	get = _get_last_session, set = _set_last_session


func _ready() -> void:
	self.load()


# TODO: check if it is possible to autosave on exit/quit
func save() -> Error:
	var err := _config.save(CONFIG_PATH)
	if err != OK:
		push_error("Failed to save config.cfg: %s" % error_string(err))

	return err


func load() -> Error:
	var err := _config.load(CONFIG_PATH)
	if err != OK:
		push_error("Failed to load config.cfg: %s" % error_string(err))

	return err


func _get_last_user() -> String:
	return _config.get_value("General", "last_user", "")


func _set_last_user(p_last_user: String) -> void:
	_config.set_value("General", "last_user", p_last_user)


func _get_last_session() -> String:
	return _config.get_value("General", "last_session", "")


func _set_last_session(p_last_session: String) -> void:
	_config.set_value("General", "last_session", p_last_session)
