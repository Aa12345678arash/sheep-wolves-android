extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for difficulty in range(3):
		var state = GameState.new()
		var placed: Array[int] = []
		for _i in range(3):
			var node: int = AI.choose_wolf_placement(state, difficulty)
			assert(node >= 0 and node < 25, "AI returned an invalid wolf placement")
			assert(not state.is_occupied(node), "AI placed a wolf on an occupied node")
			assert(state.place_wolf(node), "Game rejected AI wolf placement")
			placed.append(node)
		assert(state.turn == GameState.Turn.SHEEP, "Three placements must start the sheep turn")

		var sheep_move: Dictionary = AI.choose_sheep_move(state, difficulty)
		assert(not sheep_move.is_empty(), "AI failed to choose a legal sheep move")
		var sheep_from := int(sheep_move.from)
		var sheep_to := int(sheep_move.to)
		assert(sheep_to in state.sheep_moves(sheep_from), "AI selected an illegal sheep move")
		assert(state.move_sheep(sheep_from, sheep_to), "Game rejected AI sheep move")

		var wolf_move: Dictionary = AI.choose_wolf_move(state, difficulty)
		assert(not wolf_move.is_empty(), "AI failed to choose a legal wolf move")
		var wolf_from := int(wolf_move.from)
		var wolf_to := int(wolf_move.to)
		assert(state.wolves[wolf_from], "AI selected a node without a wolf")
		var is_capture := false
		for option in state.capture_options(wolf_from):
			if int(option.to) == wolf_to:
				is_capture = true
		assert(is_capture or wolf_to in state.wolf_moves(wolf_from), "AI selected an illegal wolf move")

		# AI selectors must be pure: asking for a move cannot mutate the match.
		var sheep_before: Array = state.sheep.duplicate()
		var wolves_before: Array = state.wolves.duplicate()
		AI.choose_wolf_move(state, difficulty)
		assert(state.sheep == sheep_before and state.wolves == wolves_before, "AI search mutated game state")

	print("WOLF-DUSK-AI-015 checks passed: all difficulty levels choose legal placements, sheep moves and wolf moves without mutating state.")
	quit()
