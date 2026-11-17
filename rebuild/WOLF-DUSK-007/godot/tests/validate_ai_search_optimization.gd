extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")
const BoardGraph = preload("res://scripts/board_graph.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Warm the immutable topology cache and verify its contents remain canonical.
	var adjacency_a := BoardGraph.adjacency()
	var adjacency_b := BoardGraph.adjacency()
	assert(adjacency_a.size() == BoardGraph.NODE_COUNT)
	assert(adjacency_b.size() == BoardGraph.NODE_COUNT)
	for node in range(BoardGraph.NODE_COUNT):
		assert(adjacency_a[node] == adjacency_b[node])

	# Evaluation cache must return the exact same score without recomputing.
	var cache_state = GameState.new()
	for _i in range(3):
		var placement: int = AI.choose_wolf_placement(cache_state, 2)
		assert(placement >= 0 and cache_state.place_wolf(placement))
	var cache_context := {
		"evaluation_cache": {},
		"evaluation_calls": 0,
		"evaluation_cache_hits": 0,
		"evaluation_usec": 0
	}
	var first_score: float = AI._evaluate_position_cached(cache_state, true, cache_context)
	var second_score: float = AI._evaluate_position_cached(cache_state, true, cache_context)
	assert(is_equal_approx(first_score, second_score))
	assert(int(cache_context.evaluation_calls) == 1,
		"Repeated identical positions must be evaluated once")
	assert(int(cache_context.evaluation_cache_hits) == 1,
		"Second identical evaluation must be a cache hit")

	# Reproduce the known sheep level-2 case under its real 70ms budget.
	seed(460048)
	var search_state = GameState.new()
	for _i in range(3):
		var placement: int = AI.choose_wolf_placement(search_state, 2)
		assert(placement >= 0 and search_state.place_wolf(placement))
	var started_usec := Time.get_ticks_usec()
	var move: Dictionary = AI.choose_sheep_move(search_state, 2)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	assert(not move.is_empty(), "Optimized sheep level 2 must always return a move")
	assert(int(move.from) >= 0 and int(move.from) < BoardGraph.NODE_COUNT)
	assert(int(move.to) in search_state.sheep_moves(int(move.from)),
		"Optimized sheep level 2 must return an authoritative legal move")
	var stats: Dictionary = AI.last_search_stats.duplicate()
	assert(int(stats.get("completed_depth", 0)) >= 2,
		"Sheep level 2 must complete its first full depth-2 root iteration inside the 70ms budget: %s" % str(stats))
	assert(int(stats.get("root_moves_searched", 0)) == int(stats.get("root_moves", -1)),
		"Depth-2 root coverage must be complete, not merely attempted")
	assert(int(stats.get("evaluation_calls", 0)) > 0)
	assert(int(stats.get("evaluation_cache_hits", 0)) >= 0)
	print("WOLF-DUSK-060 SHEEP_L2 elapsed_ms=%.2f search_elapsed_ms=%.2f target_depth=%d completed_depth=%d nodes=%d root=%d/%d attempted=%d eval_calls=%d eval_cache_hits=%d eval_ms=%.2f stop=%s" % [
		float(elapsed_usec) / 1000.0,
		float(stats.get("total_usec", 0)) / 1000.0,
		int(stats.get("target_depth", 0)),
		int(stats.get("completed_depth", 0)),
		int(stats.get("nodes", 0)),
		int(stats.get("root_moves_searched", 0)),
		int(stats.get("root_moves", 0)),
		int(stats.get("root_moves_attempted", 0)),
		int(stats.get("evaluation_calls", 0)),
		int(stats.get("evaluation_cache_hits", 0)),
		float(stats.get("evaluation_usec", 0)) / 1000.0,
		str(stats.get("stop_reason", "missing"))
	])
	print("WOLF-DUSK-060 search optimization checks passed.")
	quit()
