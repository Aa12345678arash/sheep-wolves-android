extends SceneTree

const Meadow = preload("res://scripts/meadow.gd")
const GameState = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var meadow = Meadow.new()
	root.add_child(meadow)
	await process_frame
	meadow.match_mode = "ai"
	meadow.human_side = "wolves"
	meadow.ai_difficulty = 0
	meadow._update_hud()
	assert(is_equal_approx(meadow.camera_orbit_yaw, PI), "Wolf player must start from the wolf-side camera")

	var sheep_before: Array = meadow.game.sheep.duplicate()
	meadow._select_node(0)
	meadow._select_node(1)
	meadow._select_node(2)
	assert(meadow.game.turn == GameState.Turn.SHEEP, "Third human wolf placement must start the sheep turn")
	assert(meadow.ai_busy, "AI must be scheduled immediately after the third human wolf placement")

	await create_timer(1.2).timeout
	assert(meadow.game.turn == GameState.Turn.WOLVES, "AI sheep move must hand the turn back to the human wolf player")
	assert(meadow.game.sheep != sheep_before, "AI must actually move a sheep after wolf setup")
	assert(is_equal_approx(meadow.camera_orbit_yaw, PI), "Camera must stay on the human wolf side after the AI move")

	# Expiring the optional second-capture window must automatically trigger AI sheep.
	var sheep_before_timeout: Array = meadow.game.sheep.duplicate()
	meadow.game.turn = GameState.Turn.WOLVES
	meadow.game.chain_wolf = 0
	meadow.game.chain_capture_count = 1
	meadow.chain_time_left = 0.01
	meadow._process(0.02)
	assert(meadow.game.turn == GameState.Turn.SHEEP, "Capture-window expiry must hand the game to sheep")
	assert(meadow.ai_busy, "AI sheep turn must be scheduled when capture window expires")
	await create_timer(1.2).timeout
	assert(meadow.game.turn == GameState.Turn.WOLVES, "AI must move sheep after capture-window expiry")
	assert(meadow.game.sheep != sheep_before_timeout, "Sheep positions must change after timeout-triggered AI turn")
	assert(is_equal_approx(meadow.camera_orbit_yaw, PI), "Camera must not rotate when the AI turn changes")

	# Explicitly declining the optional capture must schedule the same AI response.
	var sheep_before_decline: Array = meadow.game.sheep.duplicate()
	meadow.game.turn = GameState.Turn.WOLVES
	meadow.game.chain_wolf = 0
	meadow.game.chain_capture_count = 1
	meadow.chain_time_left = 3.0
	meadow._decline_chain_capture()
	assert(meadow.game.turn == GameState.Turn.SHEEP, "Declining the second capture must hand the game to sheep")
	assert(meadow.ai_busy, "AI sheep turn must be scheduled after declining the second capture")
	await create_timer(1.2).timeout
	assert(meadow.game.turn == GameState.Turn.WOLVES, "AI must move sheep after the capture is declined")
	assert(meadow.game.sheep != sheep_before_decline, "Sheep positions must change after decline-triggered AI turn")
	assert(is_equal_approx(meadow.camera_orbit_yaw, PI), "Camera must remain fixed on the human wolf side")

	meadow.queue_free()
	print("WOLF-DUSK-AI-017 checks passed: wolf-side camera, human wolf setup, automatic AI sheep response and turn handoff.")
	quit()
