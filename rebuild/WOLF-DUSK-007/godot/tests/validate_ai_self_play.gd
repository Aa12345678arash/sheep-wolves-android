extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

const MAX_PLY := 16

func _initialize() -> void:
	call_deferred("_run")

func _play_match(wolf_level: int, sheep_level: int, match_seed: int) -> Dictionary:
	seed(match_seed)
	var state = GameState.new()
	var placements: Array[int] = []
	for _i in range(3):
		var node: int = AI.choose_wolf_placement(state, wolf_level)
		assert(node >= 0 and node < 25 and not state.is_occupied(node),
			"Self-play: invalid wolf placement at level %d" % wolf_level)
		assert(state.place_wolf(node), "Self-play: rules rejected wolf placement")
		placements.append(node)

	var ply := 0
	var sheep_actions := 0
	var wolf_actions := 0
	var captures := 0
	while state.turn != GameState.Turn.FINISHED and ply < MAX_PLY:
		if state.turn == GameState.Turn.SHEEP:
			var move: Dictionary = AI.choose_sheep_move(state, sheep_level)
			assert(not move.is_empty(), "Self-play: sheep AI returned no move while game active")
			var from_node := int(move.get("from", -1))
			var to_node := int(move.get("to", -1))
			assert(to_node in state.sheep_moves(from_node),
				"Self-play: sheep level %d returned illegal move %d -> %d" % [sheep_level, from_node, to_node])
			assert(state.move_sheep(from_node, to_node), "Self-play: rules rejected sheep move")
			sheep_actions += 1
		elif state.turn == GameState.Turn.WOLVES:
			var move: Dictionary = AI.choose_wolf_move(state, wolf_level)
			assert(not move.is_empty(), "Self-play: wolf AI returned no move while game active")
			var from_node := int(move.get("from", -1))
			var to_node := int(move.get("to", -1))
			assert(from_node >= 0 and from_node < 25 and state.wolves[from_node],
				"Self-play: wolf AI selected a non-wolf origin")
			var was_capture := false
			for option in state.capture_options(from_node):
				if int(option.to) == to_node:
					was_capture = true
			assert(was_capture or to_node in state.wolf_moves(from_node),
				"Self-play: wolf level %d returned illegal move %d -> %d" % [wolf_level, from_node, to_node])
			var result: String = state.move_wolf(from_node, to_node)
			assert(result in ["moved", "captured", "captured_chain_available", "won"],
				"Self-play: rules rejected wolf action: " + result)
			if was_capture:
				captures += 1
			wolf_actions += 1
		else:
			assert(false, "Self-play: unexpected turn state")
		ply += 1

	return {
		"wolf_level": wolf_level,
		"sheep_level": sheep_level,
		"plies": ply,
		"sheep_actions": sheep_actions,
		"wolf_actions": wolf_actions,
		"captures": captures,
		"winner": state.winner,
		"sheep_remaining": state.sheep_total(),
		"wolves_remaining": state.wolf_total(),
		"placements": placements
	}

func _run() -> void:
	var total_matches := 0
	var total_plies := 0
	var total_captures := 0
	for level in range(5):
		# Cross the levels: each tier controls the wolves once and the sheep
		# opponent uses the complementary tier. Fixed seeds make fixtures repeatable.
		var result := _play_match(level, 4 - level, 450045 + level)
		assert(int(result.sheep_actions) > 0 and int(result.wolf_actions) > 0,
			"Self-play must exercise both sides at every tier")
		assert(int(result.plies) > 0 and int(result.plies) <= MAX_PLY,
			"Self-play must remain within the bounded match budget")
		assert(int(result.wolves_remaining) == 3,
			"Self-play must preserve all three wolves")
		total_matches += 1
		total_plies += int(result.plies)
		total_captures += int(result.captures)
		print("WOLF-DUSK-045 SELF-PLAY ", result)

	print("WOLF-DUSK-045 self-play passed: %d seeded matches, %d plies, %d legal captures." % [total_matches, total_plies, total_captures])
	quit()
