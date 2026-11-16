extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _assert_search_used(state, side: String) -> void:
	var action: Dictionary
	if side == "sheep":
		action = AI.choose_sheep_move(state, 4)
	else:
		action = AI.choose_wolf_move(state, 4)
	assert(not action.is_empty(), "Master AI must return a legal fallback for %s" % side)
	var stats: Dictionary = AI.last_search_stats
	assert(int(stats.get("nodes", 0)) > 0,
		"Master %s search must visit nodes after bounded move ordering; stats=%s" % [side, str(stats)])
	assert(int(stats.get("ordering_usec", 0)) <= int(stats.get("ordering_limit_usec", 0)) + 100000,
		"Move ordering must respect its reserved budget; stats=%s" % str(stats))
	assert(int(stats.get("total_usec", 0)) > 0,
		"Master %s search must report elapsed time" % side)
	var root_total := int(stats.get("root_moves", 0))
	var root_searched := int(stats.get("root_moves_searched", 0))
	var root_unsearched := int(stats.get("root_moves_unsearched", -1))
	assert(root_total > 0 and root_searched > 0 and root_searched <= root_total,
		"Master %s search must report actually searched root moves; stats=%s" % [side, str(stats)])
	assert(root_unsearched == root_total - root_searched,
		"Master %s search must account for every unsearched root move; stats=%s" % [side, str(stats)])
	assert(int(stats.get("root_repetition_candidates", -1)) >= 0,
		"Master %s search must report root repetition candidates" % side)

func _run() -> void:
	var state = GameState.new()
	for node in [2, 10, 14]:
		assert(state.place_wolf(node), "Fixture wolf placement must be legal")
	assert(state.turn == GameState.Turn.SHEEP, "Fixture must begin with sheep to move")

	_assert_search_used(state, "sheep")
	var sheep_move: Dictionary = AI.choose_sheep_move(state, 4)
	assert(not sheep_move.is_empty())
	assert(state.move_sheep(int(sheep_move.from), int(sheep_move.to)),
		"Selected sheep move must be legal before testing wolf search")
	_assert_search_used(state, "wolf")

	print("WOLF-DUSK-051 search-budget checks passed: move ordering is bounded and alpha-beta visits search nodes for both sides.")
	quit()
