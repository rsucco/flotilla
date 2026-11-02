extends GutTest
# The channel between two networked games: a version handshake, then plain
# messages in order, and word when the other end goes


func poll(links: Array, until: Callable, frames: int = 300) -> bool:
	for i in frames:
		for link: Link in links:
			link.poll()
		if until.call():
			return true
		await wait_process_frames(1)
	return false


func test_loopback_handshakes_then_carries_messages_in_order() -> void:
	var links := LoopbackLink.pair()
	var got := links[1].inbox
	await poll(links, func() -> bool: return links[0].linked and links[1].linked)
	assert_true(links[0].linked and links[1].linked, "said hello")
	links[0].send({"type": "move", "n": 1})
	links[0].send({"type": "move", "n": 2})
	await poll(links, func() -> bool: return got.size() == 2)
	assert_eq(got.map(func(m: Dictionary) -> int: return m.n), [1, 2], "in order")
	watch_signals(links[1])
	links[0].close()
	await poll(links, func() -> bool: return not links[1].linked)
	assert_signal_emitted(links[1], "dropped")


func test_different_builds_refuse_each_other() -> void:
	var links := LoopbackLink.pair()
	links[1].version = "0.0.0/0"
	watch_signals(links[0])
	await poll(links, func() -> bool: return false, 3)
	assert_false(links[0].linked)
	assert_signal_emitted(links[0], "failed")


func test_over_the_network() -> void:
	var port := EnetLink.PORT + 7
	var host := EnetLink.host(port)
	var guest := EnetLink.join("127.0.0.1", port)
	assert_not_null(host, "listening")
	assert_not_null(guest, "connecting")
	var both := [host, guest]
	assert_true(await poll(both, func() -> bool: return host.linked and guest.linked), "linked")
	var got := host.inbox
	guest.send({"type": "move", "target": Vector2i(20, 7)})
	await poll(both, func() -> bool: return not got.is_empty())
	assert_eq(got, [{"type": "move", "target": Vector2i(20, 7)}] as Array[Dictionary], "arrived")
	watch_signals(host)
	guest.close()
	assert_true(await poll([host], func() -> bool: return not host.linked), "noticed it go")
	assert_signal_emitted(host, "dropped")
	host.close()
