extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _empty_state() -> GameState:
	var state = GameState.new()
	for node in range(25):
		state.sheep[node] = 0
		state.wolves[node] = false
	return state

func _run() -> void:
	# Fixture A: a stack of two sheep is never a legal jump target.
	var stacked = _empty_state()
	stacked.wolves[0] = true
	stacked.wolves[1] = true
	stacked.wolves[2] = true
	stacked.sheep[6] = 2
	stacked.turn = GameState.Turn.WOLVES
	assert(stacked.capture_options(0).is_empty(), "Rules must reject jumping over a stack")
	for difficulty in range(1, 5):
		var action: Dictionary = AI.choose_wolf_move(stacked, difficulty)
		assert(not action.is_empty(), "Every deterministic tier must find a legal fallback")
		assert(not bool(action.get("capture", false)), "AI must not invent a capture over multiple sheep")
		assert(int(action.to) in stacked.wolf_moves(int(action.from)), "AI selected a non-legal fallback move")
	assert(stacked.sheep[6] == 2, "AI selection must not mutate a sheep stack")

	# Fixture B: capture reduces the flock from nine to eight and wins immediately.
	var winning = _empty_state()
	winning.wolves[0] = true
	winning.wolves[1] = true
	winning.wolves[2] = true
	winning.sheep[6] = 1
	winning.sheep[20] = 4
	winning.sheep[21] = 4
	winning.turn = GameState.Turn.WOLVES
	assert(winning.sheep_total() == 9)
	var winning_options := winning.capture_options(0)
	assert(winning_options.size() == 1 and int(winning_options[0].to) == 12)
	for difficulty in range(1, 5):
		var action: Dictionary = AI.choose_wolf_move(winning, difficulty)
		assert(int(action.from) == 0 and int(action.to) == 12 and bool(action.capture),
			"Deterministic AI tiers must choose the immediate winning capture")
		var simulation = AI._copy_state(winning)
		assert(simulation.move_wolf(int(action.from), int(action.to)) == "won",
			"Chosen tactical capture must be accepted as an immediate win")

	# Fixture C: the sheep side must recognize that moving onto node 6 exposes
	# the single sheep to the wolf at node 0, while a two-sheep stack is not capturable.
	var defence = _empty_state()
	defence.wolves[0] = true
	defence.wolves[1] = true
	defence.wolves[2] = true
	defence.sheep[12] = 1
	defence.sheep[20] = 5
	defence.sheep[21] = 5
	defence.turn = GameState.Turn.SHEEP
	assert(6 in defence.sheep_moves(12), "Fixture must expose the threatened candidate move")
	var exposed_score := AI._sheep_move_score(defence, 12, 6, 1)
	var protected_score := AI._sheep_move_score(defence, 12, 11, 1)
	assert(exposed_score < protected_score,
		"Sheep AI must prefer the safer alternative over a directly capturable destination")
	for difficulty in range(1, 5):
		assert(AI._sheep_safety_score(defence, 6, 12) < 0.0,
			"Every defensive tier must detect the legal jump threat")

	print("WOLF-DUSK-041 tactical regression checks passed: stacked-sheep capture rejection, immediate winning capture, and sheep exposure avoidance.")
	quit()
