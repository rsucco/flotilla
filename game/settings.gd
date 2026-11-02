class_name Settings
# Player settings: volumes and fullscreen, saved to user:// (on Web, the
# browser's storage). The title screen loads them once at startup. Static
# rather than an autoload, which `-s` scripts (--check-only, the screenshot
# script) can't see when they compile.

const BUSES: Array[StringName] = [&"Master", &"Music", &"Effects"]

static var path := "user://settings.cfg"
# Null until loaded
static var config: ConfigFile


static func load_settings() -> void:
	config = ConfigFile.new()
	config.load(path)
	for bus in BUSES:
		set_volume(bus, get_volume(bus))
	# Browsers only allow fullscreen from a click, so Web starts windowed
	if not OS.has_feature("web"):
		set_fullscreen(config.get_value("display", "fullscreen", false))


# Linear, 0 to 1
static func get_volume(bus: StringName) -> float:
	return config.get_value("volume", bus, 1.0)


static func set_volume(bus: StringName, volume: float) -> void:
	config.set_value("volume", bus, volume)
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), volume)


# The window, not the saved value: the player can also leave fullscreen with
# the window manager or the browser
static func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


static func set_fullscreen(on: bool) -> void:
	config.set_value("display", "fullscreen", on)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	)


static func save() -> void:
	config.save(path)
