extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = GameState.new()
	var placements: Array[int] = []
	for _i in range(3):
		var node: int = AI.choose_wolf_placement(state, 4)
		assert(node >= 0 and node < 25 and not state.is_occupied(node),
			"Master placement must return a legal, unoccupied node")
		for previous in placements:
			assert(AI._graph_distance(node, previous) >= 2,
				"Master opening must distribute wolves instead of clustering adjacent placements")
		assert(state.place_wolf(node), "Rules rejected a master placement")
		placements.append(node)

	assert(placements.size() == 3 and state.turn == GameState.Turn.SHEEP,
		"Strategic opening must place all three wolves and start the sheep turn")
	var nearest_flock_distance := 99
	for wolf_node in placements:
		var nearest_for_wolf := 99
		for sheep_node in range(20, 25):
			nearest_for_wolf = mini(nearest_for_wolf, AI._graph_distance(wolf_node, sheep_node))
		nearest_flock_distance = mini(nearest_flock_distance, nearest_for_wolf)
	assert(nearest_flock_distance <= 2,
		"At least one master wolf must begin within two legal steps of the starting flock")

	# WOLF-DUSK-053: a wolf-supported sheep with only one open exit must
	# register as siege pressure and score better for the wolf side than an
	# otherwise equivalent sheep with all four exits open.
	var trapped = GameState.new()
	for node in range(25):
		trapped.sheep[node] = 0
		trapped.wolves[node] = false
	trapped.sheep[12] = 1
	trapped.wolves[7] = true
	trapped.wolves[11] = true
	trapped.wolves[13] = true
	trapped.turn = GameState.Turn.WOLVES
	var open = GameState.new()
	for node in range(25):
		open.sheep[node] = 0
		open.wolves[node] = false
	open.sheep[12] = 1
	open.wolves[0] = true
	open.wolves[4] = true
	open.wolves[20] = true
	open.turn = GameState.Turn.WOLVES
	assert(AI._sheep_escape_count(trapped, 12) == 1,
		"Siege fixture must leave exactly one legal sheep exit")
	assert(AI._sheep_escape_count(open, 12) == 4,
		"Open fixture must retain all four legal sheep exits")
	assert(AI._sheep_siege_pressure(trapped) > AI._sheep_siege_pressure(open),
		"Coordinated adjacent wolves must create measurable siege pressure")
	assert(AI._wolf_support_score(trapped) > 0.0,
		"Wolves positioned around the same hunting zone must receive a support score")
	assert(AI._evaluate_position(trapped, false) > AI._evaluate_position(open, false),
		"Master evaluation must prefer the wolf-supported siege over the open flock")

	print("WOLF-DUSK-053 siege and strategic placement passed: placements=%s; wolves are distributed and retain access to the starting flock." % str(placements))
	quit()
