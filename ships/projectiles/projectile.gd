class_name Projectile
extends Sprite2D

# Emitted on arrival, before the explosion plays, so the hit can be resolved
signal done
signal released

const WATER_MISS_SOUND := preload("res://audio/water_miss.wav")
const LAND_MISS_SOUND := preload("res://audio/land_miss.wav")
const FIRE_TEXTURE := preload("res://ships/sprites/projectiles/fire.png")
const SMOKE_TEXTURE := preload("res://ships/sprites/projectiles/smoke.png")

# Set by whoever fires it
var grid: Grid
var dest: Vector2
var dest_hex: Vector2i
var speed := 0.0
var moving := false
# Set by volleys that resolve all at once, so no shell reads its tile early
var held := false
# Set once the impact effect is over and only its sound is left
var fading := false


# Call after adding to the tree, with `grid` set
func launch(origin: Vector2, target: Vector2i) -> void:
	global_position = origin
	dest_hex = target
	dest = grid.get_hex_center(dest_hex)
	# The sprite's nose is +x
	rotation = (dest - position).angle()
	moving = true


func _process(delta: float) -> void:
	if not moving:
		return
	position = position.move_toward(dest, speed * delta)
	if grid.get_hex_from_coords(position) == dest_hex:
		moving = false
		done.emit()
		position = dest
		if held:
			await released
		await explode(dest)
		queue_free()


func release() -> void:
	held = false
	released.emit()


# Plays the impact effect at `pos`; returns when it's finished
func explode(pos: Vector2) -> void:
	texture = null
	var tile := grid.tile(dest_hex)
	var last_event := tile.get_last_event()
	if last_event.is_empty():
		return
	var struck: bool = last_event[1] in ["Hit", "Sunk"]
	if tile.island:
		await boom(pos, not struck)
	elif struck:
		await boom(pos, false)
	else:
		await splash(pos)


# An explosion: on a ship, or on land (with the land-miss sound if nothing
# was there)
func boom(pos: Vector2, land_miss: bool) -> void:
	var sound: AudioStreamPlayer2D
	if land_miss:
		sound = Sfx.play(self, LAND_MISS_SOUND)
	# The fireball's done well before the smoke has drifted off
	Explosion.blast(get_parent(), pos)
	await get_tree().create_timer(0.9, false).timeout
	fading = true
	if is_instance_valid(sound) and sound.playing:
		await sound.finished


func splash(pos: Vector2) -> void:
	var sound := Sfx.play(self, WATER_MISS_SOUND)
	await get_tree().create_timer(Explosion.splash(get_parent(), pos), false).timeout
	fading = true
	if is_instance_valid(sound) and sound.playing:
		await sound.finished
