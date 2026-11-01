extends GutHookScript
# Clears the run's saves (see pre_run.gd), and fails the run if a test script
# doesn't load. GUT skips one that fails to parse with just a warning ("does
# not extend GutTest"), and still passes.


func run() -> void:
	for file in DirAccess.get_files_at(SaveGame.dir):
		DirAccess.remove_absolute(SaveGame.dir.path_join(file))
	for path in _test_scripts("res://test"):
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			gut.logger.error("Could not load " + path)
			set_exit_code(1)


func _test_scripts(dir: String) -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("test_") and file.ends_with(".gd"):
			paths.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		paths.append_array(_test_scripts(dir.path_join(sub)))
	return paths
