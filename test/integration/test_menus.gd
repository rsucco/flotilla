extends GutTest
# Menus and dialogs from the keyboard and a controller: each starts with a
# control to act on (its focus ring hidden from mouse players), A and Enter
# press it, and B and Esc go back

const ROOT_SCENE := preload("res://game/root.tscn")


func before_each() -> void:
	# GUT's own output panel would otherwise keep the focus
	get_viewport().gui_release_focus()


# Pressed and let go: buttons act on the release
func pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_process_frames(1)


func focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_each_screen_starts_on_something_to_press() -> void:
	var expected := {
		# Continue, when earlier tests left a save to carry on with
		"res://gui/title_screen.tscn": "Continue" if SaveGame.latest() != "" else "SinglePlayer",
		"res://gui/how_to_play.tscn": "Back",
		"res://gui/settings.tscn": "Master",
		"res://gui/local_turn_swap.tscn": "OK",
		"res://gui/victory.tscn": "Rematch",
		"res://gui/lan_lobby.tscn": "Host",
	}
	for scene: String in expected:
		var screen: Node = add_child_autofree(load(scene).instantiate())
		await wait_process_frames(1)
		assert_eq(focused().name if focused() else "", expected[scene], scene)
		assert_false(focused().has_focus(true), "its ring unshown until the arrows move it")
		screen.free()


func test_a_presses_the_focused_button() -> void:
	var swap: Node = add_child_autofree(load("res://gui/local_turn_swap.tscn").instantiate())
	await wait_process_frames(1)
	# The dialog frees itself once done, so note it here rather than watch it
	var done: Array[bool] = []
	swap.swap_done.connect(func(_watch: bool) -> void: done.append(true))
	await pad(JOY_BUTTON_A)
	assert_eq(done, [true] as Array[bool], "OK pressed")


func test_the_esc_menu_from_a_controller() -> void:
	var game: Root = add_child_autofree(ROOT_SCENE.instantiate())
	var menu := game.pause_menu
	await pad(JOY_BUTTON_START)
	assert_true(menu.visible)
	assert_eq(focused(), menu.get_node("Panel/Main/Resume"), "starts on Resume")
	menu.get_node("Panel/Main/NewGame").pressed.emit()
	assert_eq(focused(), menu.get_node("Panel/Confirm/Buttons/No"), "questions start on No")
	await pad(JOY_BUTTON_A)
	assert_eq(focused(), menu.get_node("Panel/Main/Resume"), "No: back to the menu")
	await pad(JOY_BUTTON_B)
	assert_false(menu.visible, "B closes it")


func test_title_screen_overlays_hand_the_focus_back() -> void:
	var title: Node = add_child_autofree(load("res://gui/title_screen.tscn").instantiate())
	await wait_process_frames(1)
	title.get_node("TextureRect/PanelContainer/Buttons/Settings").pressed.emit()
	await wait_process_frames(1)
	assert_eq(focused().name, "Master", "settings start on the first slider")
	await pad(JOY_BUTTON_B)
	await wait_process_frames(1)
	assert_not_null(focused(), "the menu has the focus again")
	assert_eq(focused().get_parent().name, "Buttons")
