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
	assert(not defensive_probe.is_empty(), "Master tier must choose a legal defensive move")
	assert(not (int(defensive_probe.from) == 12 and int(defensive_probe.to) == 6),
		"Master tier must not choose the known immediately capturable square")
	assert(defence.sheep == sheep_before and defence.wolves == wolves_before,
		"Defensive tactical search must not mutate the source state")

	# Fixture E: the wolf has an optional second capture. Every tier must be
	# given both legal choices; stronger tiers must take the immediate winning
	# capture, while the random educational tier may choose either legal option.
	var chain = _empty_state()
	chain.wolves[14] = true
	chain.sheep[18] = 1
	chain.sheep[20] = 4
	chain.sheep[21] = 4
	chain.turn = GameState.Turn.WOLVES
	chain.chain_wolf = 14
	chain.chain_capture_count = 1
	var chain_actions := AI._legal_search_moves(chain, true)
	var has_decline := false
	var has_follow_up := false
	for action in chain_actions:
		if str(action.get("side", "")) == "decline_chain":
			has_decline = true
		elif int(action.get("from", -1)) == 14 and int(action.get("to", -1)) == 22:
			has_follow_up = true
	assert(has_decline and has_follow_up,
		"An optional chain turn must expose both decline and legal follow-up capture")
	var declined = AI._copy_state(chain)
	AI._apply_search_move(declined, {"side": "decline_chain"})
	assert(declined.turn == GameState.Turn.SHEEP and declined.chain_wolf == -1,
		"Declining the optional capture must legally finish the wolf turn")
	for difficulty in range(5):
		var chain_action: Dictionary = AI.choose_wolf_move(chain, difficulty)
		assert(not chain_action.is_empty(), "Every AI tier must choose an action during an optional chain")
		if str(chain_action.get("side", "")) == "decline_chain":
			assert(difficulty == 0, "Tactical tiers must take the immediate winning follow-up capture")
		else:
			assert(int(chain_action.get("from", -1)) == 14 and int(chain_action.get("to", -1)) == 22,
				"AI tier %d selected an invalid chain action" % difficulty)
			var chain_result = AI._copy_state(chain)
			assert(chain_result.move_wolf(14, 22) == "won",
				"Follow-up capture must be accepted as the immediate winning move")

	# Fixture F: moving one sheep into the final open neighbor blocks all three
	# wolves. Every deterministic tier must recognize and take this immediate win.
	var sheep_winning = _empty_state()
	sheep_winning.wolves[0] = true
	sheep_winning.wolves[4] = true
	sheep_winning.wolves[24] = true
	for node in [1, 5, 6, 3, 9, 8, 19, 23, 17, 2, 10, 12, 14, 22]:
		sheep_winning.sheep[node] = 1
	sheep_winning.turn = GameState.Turn.SHEEP
	assert(18 in sheep_winning.sheep_moves(17), "Sheep victory fixture must expose the final blocking move")
	for difficulty in range(1, 5):
		var sheep_winning_action: Dictionary = AI.choose_sheep_move(sheep_winning, difficulty)
		assert(int(sheep_winning_action.get("from", -1)) == 17 and int(sheep_winning_action.get("to", -1)) == 18,
			"Deterministic sheep tier %d must choose the immediate three-wolf block" % difficulty)
		var sheep_win_simulation = AI._copy_state(sheep_winning)
		assert(sheep_win_simulation.move_sheep(17, 18) and sheep_win_simulation.winner == "sheep",
			"Final blocking move must be accepted as an immediate sheep victory")

	print("WOLF-DUSK-047 tactical checks passed: immediate wolf capture wins, optional chain rules, and immediate sheep block wins are verified.")
	quit()
