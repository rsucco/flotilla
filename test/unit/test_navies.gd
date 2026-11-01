extends GutTest
# The navies' details and ship name lists


func test_each_navy_can_name_a_full_fleet_without_repeats() -> void:
	for key: String in Navies.ALL:
		var navy: Dictionary = Navies.ALL[key]
		assert_not_null(Navies.ensign(key), key + " has an ensign")
		var names: Array = []
		for type: String in navy.ships:
			assert_gte(navy.ships[type].size(), 5, "%s %s: five of a type" % [key, type])
			names.append_array(navy.ships[type])
		for ship: String in names:
			assert_eq(names.count(ship), 1, "%s: %s named once" % [key, ship])
		for ship: String in navy.get("other_prefixes", {}):
			assert_has(names, ship, "%s: %s is on a list" % [key, ship])


func test_names_carry_their_prefix() -> void:
	var taken: Array[String] = []
	for i in 9:
		taken.append(Navies.ship_title("uk", "Supply Tender", taken))
	assert_has(taken, "RFA Tidespring")
	assert_has(taken, "MV Hurst Point")
	assert_eq(Navies.ship_title("uk", "Supply Tender", taken), "", "none left")
	assert_string_starts_with(Navies.ship_title("uk", "Destroyer", taken), "HMS ")
	assert_eq(Navies.ship_title("uk", "Coastal Battery", taken), "", "batteries have no list")
