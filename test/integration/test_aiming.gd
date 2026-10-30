extends GutTest
# Turrets and projectiles point where they're going

const ROOT_SCENE := preload("res://root.tscn")
const MISSILE_SCENE := preload("res://ships/projectiles/missile.tscn")
const TORPEDO_SCENE := preload("res://ships/projectiles/torpedo.tscn")
const SHELL_SCENE := preload("res://ships/projectiles/battleship_projectile.tscn")

var game: Root


func before_each() -> void:
	game = add_child_autofree(ROOT_SCENE.instantiate())
	for column: Array in game.grid.tiles:
		for tile: Tile in column:
			tile.island = false


func spawn(player: int, type: String, hex: Vector2i, dir: int = 0) -> Ship:
	var ship: Ship = load("res://ships/" + type + ".tscn").instantiate()
	game.players[player].add_child(ship)
	ship.set_grid_position(hex, dir)
	game.players[player].ships.append(ship)
	return ship


func remove(ship: Ship) -> void:
	ship.player.ships.erase(ship)
	ship.queue_free()


# Degrees between where a node's `nose` (in its own space) points and `dir`
func off_by(node: Node2D, nose: Vector2, dir: Vector2) -> float:
	return rad_to_deg(absf(nose.rotated(node.global_rotation).angle_to(dir)))


# Aims a turret and returns how far it swept, in degrees
func sweep(ship: Ship, turret: Node2D, target: Vector2i) -> float:
	var last := turret.global_rotation
	var swept := 0.0
	ship.aim_turret(turret, game.grid.get_hex_center(target), 0.2)
	var end := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		swept += absf(wrapf(turret.global_rotation - last, -PI, PI))
		last = turret.global_rotation
	return rad_to_deg(swept)


func assert_turret_faces(turret: Node2D, target: Vector2i) -> void:
	var dir := turret.global_position.direction_to(game.grid.get_hex_center(target))
	# Turret sprites point up
	assert_lt(off_by(turret, Vector2.UP, dir), 1.0, str(turret.name, " faces ", target))


func test_battleship_turrets_face_target() -> void:
	var ship: Battleship = spawn(0, "battleship", Vector2i(5, 7))
	for target in [Vector2i(22, 2), Vector2i(29, 13)]:
		await ship.point_turrets(target)
		for turret in ship.turrets:
			assert_turret_faces(turret, target)


func test_turrets_face_target_from_either_side_and_heading() -> void:
	var cases := [
		[0, "corvette", Vector2i(5, 7), 0, Vector2i(25, 3)],
		[0, "corvette", Vector2i(5, 7), 240, Vector2i(25, 11)],
		[1, "corvette", Vector2i(25, 7), 0, Vector2i(3, 3)],
		[1, "coastal_battery", Vector2i(25, 7), 0, Vector2i(3, 12)],
	]
	for c: Array in cases:
		var ship := spawn(c[0], c[1], c[2], c[3])
		var turret: Node2D = ship.get_node("Turret")
		await sweep(ship, turret, c[4])
		assert_turret_faces(turret, c[4])
		remove(ship)


func test_turret_takes_shortest_way_around() -> void:
	# Aiming from just above to just below due west is a small turn, unless
	# the angle wraps the long way through east
	var ship: Corvette = spawn(1, "corvette", Vector2i(25, 7))
	await sweep(ship, ship.turret, Vector2i(3, 6))
	assert_lt(await sweep(ship, ship.turret, Vector2i(3, 8)), 30.0)


func test_missile_turns_to_face_target() -> void:
	for shot: Array in [[Vector2i(5, 7), Vector2i(25, 2)], [Vector2i(25, 7), Vector2i(3, 12)]]:
		var missile: Missile = MISSILE_SCENE.instantiate()
		game.add_child(missile)
		missile.launch(game.grid.get_hex_center(shot[0]), shot[1])
		await wait_until(func() -> bool: return missile.enroute, 3)
		var dir := missile.global_position.direction_to(missile.dest)
		# The missile sprite points left
		assert_lt(off_by(missile, Vector2.LEFT, dir), 1.0, str("missile to ", shot[1]))
		missile.queue_free()


func test_torpedo_points_along_its_path() -> void:
	var torpedo: Torpedo = TORPEDO_SCENE.instantiate()
	game.add_child(torpedo)
	torpedo.launch(game.grid.get_hex_center(Vector2i(5, 7)), Vector2i(25, 9))
	await wait_seconds(1.0)
	var before := torpedo.sprite.global_position
	await wait_frames(5)
	var heading := before.direction_to(torpedo.sprite.global_position)
	# The torpedo sprite points right
	assert_lt(off_by(torpedo.sprite, Vector2.RIGHT, heading), 10.0)
	torpedo.queue_free()


func test_shell_points_at_target() -> void:
	for shot: Array in [[Vector2i(5, 7), Vector2i(25, 2)], [Vector2i(25, 7), Vector2i(3, 12)]]:
		var shell: Projectile = SHELL_SCENE.instantiate()
		game.add_child(shell)
		shell.launch(game.grid.get_hex_center(shot[0]), shot[1])
		var dir := shell.global_position.direction_to(shell.dest)
		# The shell sprite points right
		assert_lt(off_by(shell, Vector2.RIGHT, dir), 1.0, str("shell to ", shot[1]))
		shell.queue_free()
