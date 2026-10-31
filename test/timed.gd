extends RefCounted
# Awaits a coroutine (e.g. a ship's fire()) but gives up after `timeout`
# seconds, so one that never returns fails the test instead of hanging the run.
# Resumes the caller the moment the coroutine returns, as a plain await would
# (a salvo is resolved right then). Returns its result, or null on timeout.

signal finished


static func finish(coroutine: Callable, timeout: float = 10.0) -> Variant:
	var waiter := new()
	var state := {"done": false, "result": null}
	var run := func() -> void:
		state.result = await coroutine.call()
		state.done = true
		waiter.finished.emit()
	run.call()
	if not state.done:
		var tree := Engine.get_main_loop() as SceneTree
		tree.create_timer(timeout, true, false, true).timeout.connect(waiter.finished.emit)
		await waiter.finished
	if not state.done:
		push_error(str("Timed out after ", timeout, " s awaiting ", coroutine.get_method()))
	return state.result
