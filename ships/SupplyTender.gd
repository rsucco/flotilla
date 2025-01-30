extends Ship

class_name SupplyTender

var dc_timer
const repair_sound = preload('res://audio/repair.wav')

# Called when the node enters the scene tree for the first time.
func _ready():
	self.len_fore = 1
	self.len_aft = 1
	self.ship_type = 'supply_tender'
	self.hit_hexes = [false, false, false]
	self.ship_name = 'Supply Tender'
	self.weapon = 'None'
	self.special = SpecialAbility.new(3, 'UNREP', 'Completely heals an adjacent ship')
	self.passive = PassiveAbility.new('Damage Control', 'Heals one hex every 10 turns if damaged')
	self.dc_timer = -1
	self.drawback = Drawback.new('Flammable Cargo', 'Lose 2 AP per turn if damaged')
	self.move_sound = preload('res://audio/smallship.ogg')

# Supply tenders cannot fire
func can_fire(aim_hex = [0, 0]):
	return false

func new_turn():
	.new_turn()
	# Drawback - Flammable Cargo
	# Lose 2 AP per turn if damaged
	if true in hit_hexes:
		print('drawback - flammable cargo')
		ap = 2
		# Passive ability - Damage Control
		# Heal one hex every 10 turns if damaged
		if dc_timer == -1:
			dc_timer = 10
		elif dc_timer == 0:
			dc_timer = 10
			if true in hit_hexes:
				hit_hexes[hit_hexes.find_last(true)] = false
				print('passive - damage control')
		else:
			dc_timer -= 1

# Heal all adjacent ships
func use_special(x, y):
	.use_special(x, y)
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = repair_sound
	audio_player.play()
	for ship_hex in get_occupied_hexes():
		for neighbor_hex in get_parent().get_parent().grid.get_all_hex_neighbors(ship_hex[0], ship_hex[1]):
			var ship_at_hex = get_parent().get_ship_at_hex(neighbor_hex[0], neighbor_hex[1])
			if ship_at_hex != null:
				ship_at_hex.heal()
	emit_signal('special_animation_complete')
	yield(audio_player, 'finished')
	audio_player.queue_free()
