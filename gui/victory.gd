extends PanelContainer

# What to call each player, set by Root before update_winner()
var names: Array[String] = ["Player 1", "Player 2"]
# Whether a rematch can start from here (a LAN game's needs the other player)
var rematch := true


func _ready() -> void:
	var button: Button = $VBoxContainer/HBoxContainer/Rematch
	button.visible = rematch
	if not rematch:
		button = $VBoxContainer/HBoxContainer/Title
	button.grab_focus(true)


# `winner` and `conceded` (the player who gave up, if one did) count from 1
func update_winner(winner: int, conceded: int = 0) -> void:
	var who := names[winner - 1]
	$VBoxContainer/Label.text = who + (" win!" if who == "You" else " wins!")
	if conceded != 0:
		$VBoxContainer/Label.text += " " + names[conceded - 1] + " conceded."


# `players` is untyped: naming Player here would make Root, which preloads
# this scene, a dependency of its own victory screen
func show_stats(players: Array, turns: int) -> void:
	$VBoxContainer/Turns.text = "Turns: " + str(turns)
	# Each side's flag heads its column
	$VBoxContainer/Stats.add_child(Control.new())
	for player in players:
		var flag := TextureRect.new()
		flag.texture = player.ensign()
		flag.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		$VBoxContainer/Stats.add_child(flag)
	var rows := [["", names[0], names[1]], ["Attacks"], ["Hit rate"], ["Ships left"]]
	for player in players:
		rows[1].append(str(player.attacks))
		rows[2].append(
			"-" if player.attacks == 0 else "%d%%" % roundi(100.0 * player.hits / player.attacks)
		)
		rows[3].append(str(player.ships.size()) + "/" + str(player.fleet_size))
	for row: Array in rows:
		for text: String in row:
			var label := Label.new()
			label.text = text
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			$VBoxContainer/Stats.add_child(label)


func _on_Quit_pressed() -> void:
	Sfx.quit(get_tree())


func _on_Title_pressed() -> void:
	get_tree().change_scene_to_file("res://title_screen.tscn")


func _on_Rematch_pressed() -> void:
	get_tree().reload_current_scene()
