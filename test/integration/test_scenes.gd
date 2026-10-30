extends GutTest
# Every scene loads and instantiates (catches broken references after edits)


func scene_paths(dir: String = "res://") -> Array[String]:
	var paths: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub not in ["addons", "test"]:
			paths.append_array(scene_paths(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tscn":
			paths.append(dir.path_join(file))
	return paths


func test_all_scenes_instantiate() -> void:
	var paths := scene_paths()
	assert_gt(paths.size(), 20, "found the project scenes")
	for path in paths:
		var scene: PackedScene = load(path)
		assert_not_null(scene, path)
		if scene:
			var node := scene.instantiate()
			assert_not_null(node, path)
			node.free()


func test_ew_strike_emits_from_mask() -> void:
	var ew: EWStrike = add_child_autofree(
		load("res://ships/projectiles/ew_strike.tscn").instantiate()
	)
	var particles := ew.make_static()
	assert_eq(particles.emission_points.size(), 31229, "one point per opaque mask pixel")
	particles.free()
