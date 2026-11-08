extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _empty_state():
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
	assert(AI._count_capture_options_after(stacked, 0, 1, -1) == 0,
		"Wolf search must not count a stack as a future capture")
	assert(AI._count_threatened_sheep_after(stacked, 0, 1) == 0,
		"Wolf evaluation must not mark a stack as a capturable threat")
	# The educational/random tier is also checked for legality, though it is not
	# expected to choose the tactically best move.
	var random_action: Dictionary = AI.choose_wolf_move(stacked, 0)
	assert(not random_action.is_empty())
	assert(not bool(random_action.get("capture", false)))
	assert(int(random_action.to) in stacked.wolf_moves(int(random_action.from)))
	for difficulty in range(1, 5):
		var action: Dictionary = AI.choose_wolf_move(stacked, difficulty)
		assert(not action.is_empty(), "Every deterministic tier must find a legal fallback")
		assert(not bool(action.get("capture", false)), "AI must not invent a capture over multiple sheep")
		assert(int(action.to) in stacked.wolf_moves(int(action.from)), "AI selected a non-legal fallback move")
	assert(stacked.sheep[6] == 2, "AI selection must not mutate a sheep stack")

	# Fixture B: capture reduces the flock from nine to eight and wins immediately.
	var winning = _empty_state()
	winning.wolves[0] = true
	# One wolf keeps the only immediate winning capture unambiguous.
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

	assert(AI._search_node_limit(4) < AI._search_node_limit(6)
		and AI._search_node_limit(6) < AI._search_node_limit(8),
		"Higher search tiers must receive larger node budgets")
	assert(AI._search_time_limit_usec(4) < AI._search_time_limit_usec(6)
		and AI._search_time_limit_usec(6) < AI._search_time_limit_usec(8),
		"Higher search tiers must receive larger time budgets")

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
		var defensive_action: Dictionary = AI.choose_sheep_move(defence, difficulty)
		assert(not defensive_action.is_empty(), "Defensive tier failed to choose a move")
		assert(not (int(defensive_action.from) == 12 and int(defensive_action.to) == 6),
			"Defensive tier %d chose the known immediately capturable square" % difficulty)

	# Fixture D: a legal one-step retreat must remain available to the sheep
	# after the exposed candidate is rejected; selection must not mutate state.
	var sheep_before: Array = defence.sheep.duplicate()
	var wolves_before: Array = defence.wolves.duplicate()
	var defensive_probe: Dictionary = AI.choose_sheep_move(defence, 4)
	assert(int(defensive_probe.from) == 12 and int(defensive_probe.to) != 6,
		"Master tier must choose a move other than the known exposed square")
	assert(defence.sheep == sheep_before and defence.wolves == wolves_before,
		"Defensive tactical search must not mutate the source state")

	print("WOLF-DUSK-045 tactical behavior checks passed: stacked-sheep capture rejection, immediate winning capture, and selected-move avoidance of a directly capturable sheep square.")
	quit()
