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
	assert(is_equal_approx(meadow.camera_orbit_yaw, PI), "Camera must return to the wolf-side view on the human wolf turn")

	meadow.queue_free()
	print("WOLF-DUSK-AI-017 checks passed: wolf-side camera, human wolf setup, automatic AI sheep response and turn handoff.")
	quit()
