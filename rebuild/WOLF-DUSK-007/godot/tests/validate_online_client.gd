extends SceneTree

const OnlineClient = preload("res://scripts/online_room_client.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var client = OnlineClient.new()
	root.add_child(client)
	await process_frame
	assert(client is Node)
	assert(not client.is_configured(), "Online service must remain disabled until the owner deploys a real endpoint.")
	assert(client.create_room("CI Test") == ERR_UNCONFIGURED, "Room creation must fail safely without a configured service.")
	assert(client.set_ready() == ERR_UNAVAILABLE, "Ready must not be sent before the server authenticates the socket.")
	assert(client.send_action({"type":"place_wolf","node":0}) == ERR_UNAVAILABLE, "Game actions must not be sent before authentication.")
	var connected_count := [0]
	var message_count := [0]
	client.room_connected.connect(func(_snapshot: Dictionary): connected_count[0] += 1)
	client.room_message.connect(func(_payload: Dictionary): message_count[0] += 1)
	var snapshot := {"type":"snapshot","status":"waiting","nextActionSeq":4,"game":{"sheep":[],"wolves":[]}}
	client.call("_handle_packet", JSON.stringify(snapshot))
	assert(connected_count[0] == 1, "The initial authenticated snapshot must emit room_connected exactly once.")
	assert(message_count[0] == 1, "Every snapshot must still be forwarded to room_message.")
	assert(client.set_ready() == ERR_UNAVAILABLE, "The client must not send without an open WebSocket even after authentication.")
	client.call("_handle_packet", JSON.stringify(snapshot))
	assert(connected_count == 1, "Repeated snapshots must not emit room_connected again or trigger duplicate ready messages.")
	assert(message_count[0] == 2, "Subsequent snapshots must continue to update the game state.")
	assert(client.next_action_sequence == 4, "The expected action sequence must be loaded from the authoritative snapshot.")
	client.queue_free()
	print("WOLF_DUSK_ONLINE_CLIENT_SMOKE_OK")
	quit()
