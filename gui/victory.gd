extends PanelContainer


func update_winner(winner: int) -> void:
	$VBoxContainer/Label.text = "Player " + str(winner) + " wins!"


# `players` is untyped: naming Player here would make Root, which preloads
# this scene, a dependency of its own victory screen
func show_stats(players: Array, turns: int) -> void:
	$VBoxContainer/Turns.text = "Turns: " + str(turns)
	var rows := [["", "Player 1", "Player 2"], ["Attacks"], ["Hit rate"], ["Ships left"]]
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
	get_tree().quit()


func _on_Title_pressed() -> void:
	get_tree().change_scene_to_file("res://title_screen.tscn")


func _on_Rematch_pressed() -> void:
	get_tree().reload_current_scene()
