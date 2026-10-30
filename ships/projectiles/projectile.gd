class_name Projectile
extends Sprite2D

# Emitted on arrival, before the explosion plays, so the hit can be resolved
signal done

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
		await explode(dest)
		queue_free()


# Plays the impact effect at `pos`; returns when it's finished
func explode(pos: Vector2) -> void:
	texture = null
	var tile := grid.tile(dest_hex)
	var last_event := tile.get_last_event()
	if last_event.is_empty():
		return
	if tile.island:
		await boom(pos, not last_event[1] in ["Hit", "Sunk"])
	else:
		await splash(pos)


func boom(pos: Vector2, land_miss: bool) -> void:
	var sound: AudioStreamPlayer2D
	if land_miss:
		sound = Sfx.play(self, LAND_MISS_SOUND)

	var fire := CPUParticles2D.new()
	fire.spread = 180.0
	fire.gravity = Vector2.ZERO
	fire.initial_velocity_min = 15.0
	fire.initial_velocity_max = 15.0
	fire.damping_min = 10.0
	fire.damping_max = 10.0
	fire.color = Color.CORAL
	fire.scale_amount_min = 0.03
	fire.scale_amount_max = 0.03
	fire.texture = FIRE_TEXTURE
	fire.amount = 200
	fire.lifetime = 0.7
	fire.one_shot = true
	fire.explosiveness = 1.0
	fire.position = pos
	add_sibling(fire)

	var smoke := CPUParticles2D.new()
	smoke.spread = 180.0
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 30.0
	smoke.initial_velocity_max = 30.0
	smoke.damping_min = 15.0
	smoke.damping_max = 15.0
	smoke.scale_amount_min = 0.03
	smoke.scale_amount_max = 0.03
	smoke.texture = SMOKE_TEXTURE
	smoke.amount = 300
	smoke.lifetime = 0.9
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.position = pos
	add_sibling(smoke)

	await get_tree().create_timer(0.9, false).timeout
	fire.queue_free()
	smoke.queue_free()
	if is_instance_valid(sound) and sound.playing:
		await sound.finished


func splash(pos: Vector2) -> void:
	var sound := Sfx.play(self, WATER_MISS_SOUND)
	var ripples := CPUParticles2D.new()
	ripples.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	ripples.emission_ring_radius = 1.0
	ripples.spread = 180.0
	ripples.gravity = Vector2.ZERO
	ripples.initial_velocity_min = 35.0
	ripples.initial_velocity_max = 35.0
	ripples.damping_min = 35.0
	ripples.damping_max = 35.0
	ripples.color = Color(0.65, 1.0, 1.0, 0.5)
	ripples.scale_amount_min = 3.0
	ripples.scale_amount_max = 3.0
	ripples.amount = 1000
	ripples.lifetime = 0.75
	ripples.one_shot = true
	ripples.explosiveness = 1.0
	ripples.position = pos
	add_sibling(ripples)

	await get_tree().create_timer(ripples.lifetime, false).timeout
	ripples.queue_free()
	if is_instance_valid(sound) and sound.playing:
		await sound.finished
