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
	client.queue_free()
	print("WOLF_DUSK_ONLINE_CLIENT_SMOKE_OK")
	quit()
