extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for difficulty in range(5):
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

	# During an optional chain, every difficulty must keep the same wolf and choose
	# the only legal second capture. Selection itself must not mutate the board.
	for difficulty in range(5):
		var chain_state = GameState.new()
		for node in range(25):
			chain_state.sheep[node] = 0
			chain_state.wolves[node] = false
		chain_state.wolves[1] = true
		chain_state.wolves[2] = true
		chain_state.wolves[12] = true
		chain_state.sheep[18] = 1
		chain_state.sheep[20] = 5
		chain_state.sheep[21] = 5
		chain_state.turn = GameState.Turn.WOLVES
		chain_state.chain_wolf = 12
		chain_state.chain_capture_count = 1
		var sheep_before: Array = chain_state.sheep.duplicate()
		var wolves_before: Array = chain_state.wolves.duplicate()
		var chain_action: Dictionary = AI.choose_wolf_move(chain_state, difficulty)
		assert(int(chain_action.from) == 12, "AI switched wolves during a chain capture")
		assert(int(chain_action.to) == 24 and bool(chain_action.capture), "AI missed the only legal second capture")
		assert(chain_state.sheep == sheep_before and chain_state.wolves == wolves_before, "Chain selection mutated game state")
		assert(chain_state.move_wolf(int(chain_action.from), int(chain_action.to)) == "captured", "Rules rejected AI second capture")
		assert(chain_state.turn == GameState.Turn.SHEEP, "Second capture must finish the wolf turn")
	print("WOLF-DUSK-AI-015 checks passed: all five difficulty levels choose legal placements, sheep moves and wolf moves without mutating state.")
	quit()
