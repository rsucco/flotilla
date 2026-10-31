extends GutTest
# Settings: volume buses, fullscreen, saving, and where the page opens from

const ROOT_SCENE := preload("res://root.tscn")
const SETTINGS_SCENE := preload("res://gui/settings.tscn")
const TITLE_SCENE := preload("res://title_screen.tscn")
const TEST_PATH := "user://test_settings.cfg"

var saved_path: String


# Never touch the player's own settings file
func before_all() -> void:
	saved_path = Settings.path
	Settings.path = TEST_PATH
	Settings.load_settings()


func after_each() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(TEST_PATH)
	Settings.load_settings()


func after_all() -> void:
	Settings.path = saved_path
	Settings.load_settings()


func esc() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	get_viewport().push_input(event)
	# Overlays free themselves at the end of the frame
	await wait_process_frames(1)


func test_music_and_effects_have_their_own_buses() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	assert_eq(game.get_node("Music").bus, &"Music")
	assert_eq(game.get_node("TitleMusic").bus, &"Music")
	var title: Node = add_child_autofree(TITLE_SCENE.instantiate())
	assert_eq(title.get_node("Music").bus, &"Music")
	var sound := Sfx.play(game, Missile.FIRE_SOUND)
	assert_eq(sound.bus, &"Effects")
	for bus in Settings.BUSES:
		assert_ne(AudioServer.get_bus_index(bus), -1, bus)


func test_volume_applies_to_its_bus_and_is_saved() -> void:
	Settings.set_volume(&"Effects", 0.25)
	var bus := AudioServer.get_bus_index(&"Effects")
	assert_almost_eq(AudioServer.get_bus_volume_linear(bus), 0.25, 0.001)
	Settings.save()
	Settings.set_volume(&"Effects", 1.0)
	Settings.load_settings()
	assert_almost_eq(Settings.get_volume(&"Effects"), 0.25, 0.001, "loaded back")
	assert_almost_eq(AudioServer.get_bus_volume_linear(bus), 0.25, 0.001, "and applied")


func test_sliders_change_volume_live_and_closing_saves() -> void:
	var page: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	var music: HSlider = page.get_node("%Music")
	assert_eq(music.value, 1.0, "starts at the current volume")
	music.value = 0.5
	assert_almost_eq(Settings.get_volume(&"Music"), 0.5, 0.001)
	page.close()
	var file := ConfigFile.new()
	assert_eq(file.load(TEST_PATH), OK, "saved on closing")
	assert_almost_eq(file.get_value("volume", &"Music"), 0.5, 0.001)


func test_letting_go_of_master_or_effects_plays_the_sample() -> void:
	var page: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	var sample: AudioStreamPlayer = page.get_node("Sample")
	for bus: StringName in [&"Music", &"Master", &"Effects"]:
		sample.stop()
		page.get_node("%" + bus).drag_ended.emit(true)
		assert_eq(sample.playing, bus != &"Music", bus)


func test_fullscreen_toggle_is_saved() -> void:
	var page: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	var toggle: CheckButton = page.get_node("%Fullscreen")
	toggle.button_pressed = not toggle.button_pressed
	assert_eq(Settings.config.get_value("display", "fullscreen"), toggle.button_pressed)
	Settings.set_fullscreen(false)


func test_settings_open_from_the_title_screen() -> void:
	var title: Node = add_child_autofree(TITLE_SCENE.instantiate())
	title.get_node("TextureRect/PanelContainer/Buttons/Settings").pressed.emit()
	var page: Node = title.get_node("TextureRect/Settings")
	page.get_node("Panel/Margin/VBox/Back").pressed.emit()
	await wait_process_frames(1)
	assert_false(is_instance_valid(page), "Back closes it")


func test_pause_menu_overlays_replace_the_menu_until_closed() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var menu := game.pause_menu
	menu.open()
	for button in ["Settings", "HowToPlay"]:
		menu.get_node("Panel/Main/" + button).pressed.emit()
		assert_false(menu.panel.visible, button + " hides the menu")
		await esc()
		assert_true(menu.panel.visible, "Esc closes " + button + ", back to the menu")
		assert_true(menu.visible, "still paused")
	menu.close()


func test_hud_menu_button_opens_the_pause_menu() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var pressed: Array[String] = []
	game.gui.action_pressed.connect(func(action: String) -> void: pressed.append(action))
	game.gui.get_node("GUIGrid/Menu").pressed.emit()
	assert_true(game.pause_menu.visible)
	assert_eq(pressed, [] as Array[String], "not sent to the player as an action")
	game.pause_menu.close()
