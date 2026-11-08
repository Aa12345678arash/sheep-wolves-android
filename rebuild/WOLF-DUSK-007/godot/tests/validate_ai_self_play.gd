extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

const MAX_PLY := 96

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
	var repetition_count: Dictionary = {}
	var draw_reason := ""
	var initial_key := _position_key(state)
	repetition_count[initial_key] = 1
	while state.turn != GameState.Turn.FINISHED and ply < MAX_PLY and draw_reason == "":
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
		if state.turn != GameState.Turn.FINISHED:
			var key := _position_key(state)
			repetition_count[key] = int(repetition_count.get(key, 0)) + 1
			if int(repetition_count[key]) >= 3:
				draw_reason = "threefold_repetition"

	return {
		"wolf_level": wolf_level,
		"sheep_level": sheep_level,
		"plies": ply,
		"sheep_actions": sheep_actions,
		"wolf_actions": wolf_actions,
		"captures": captures,
		"winner": state.winner,
		"draw_reason": draw_reason if draw_reason != "" else ("ply_limit" if state.turn != GameState.Turn.FINISHED else ""),
		"repeated_positions": repetition_count.size(),
		"sheep_remaining": state.sheep_total(),
		"wolves_remaining": state.wolf_total(),
		"placements": placements
	}

func _position_key(state) -> String:
	# A repetition key must include every rule-relevant part of the position.
	return "%s|%s|%d|%d|%d" % [str(state.sheep), str(state.wolves), int(state.turn), int(state.chain_wolf), int(state.chain_capture_count)]

func _run() -> void:
	var total_matches := 0
	var total_plies := 0
	var total_captures := 0
	var completed_matches := 0
	var capped_matches := 0
	var repetition_draws := 0
	for level in range(5):
		# Run both seat assignments for every complementary level pairing.
		# Fixed seeds keep the fixtures reproducible while varying placements.
		for seat in range(2):
			var wolf_level: int = level if seat == 0 else 4 - level
			var sheep_level: int = 4 - level if seat == 0 else level
			var match_seed: int = 450045 + level * 2 + seat
			var result := _play_match(wolf_level, sheep_level, match_seed)
			assert(int(result.sheep_actions) > 0 and int(result.wolf_actions) > 0,
				"Self-play must exercise both sides in every match")
			assert(int(result.plies) > 0 and int(result.plies) <= MAX_PLY,
				"Self-play must remain within the bounded match budget")
			assert(int(result.wolves_remaining) <= 3 and int(result.wolves_remaining) >= 0,
				"Self-play produced an invalid wolf count")
			if str(result.winner) == "":
				if str(result.draw_reason) == "threefold_repetition":
					repetition_draws += 1
				else:
					capped_matches += 1
			else:
				completed_matches += 1
			total_matches += 1
			total_plies += int(result.plies)
			total_captures += int(result.captures)
			print("WOLF-DUSK-045 SELF-PLAY ", result)

	assert(total_plies >= total_matches * 24,
		"Self-play fixtures ended too early to provide a useful tactical sample")
	print("WOLF-DUSK-045 self-play passed: %d seeded matches, %d plies, %d legal captures, %d completed, %d repetition draws, %d ply-capped (limit %d)." % [total_matches, total_plies, total_captures, completed_matches, repetition_draws, capped_matches, MAX_PLY])
	quit()
