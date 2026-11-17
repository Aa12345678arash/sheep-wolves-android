extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")
const BoardGraph = preload("res://scripts/board_graph.gd")

func _initialize() -> void:
	call_deferred("_run")

func _assert_search_report(side: String, level: int, stats: Dictionary) -> void:
	var root_total := int(stats.get("root_moves", 0))
	var root_searched := int(stats.get("root_moves_searched", -1))
	var root_unsearched := int(stats.get("root_moves_unsearched", -1))
	var root_attempted := int(stats.get("root_moves_attempted", -1))
	var target_depth := int(stats.get("target_depth", stats.get("depth", 0)))
	var completed_depth := int(stats.get("completed_depth", -1))
	assert(int(stats.get("nodes", 0)) > 0, "%s level %d must visit search nodes" % [side, level])
	assert(root_total > 0 and root_searched >= 0 and root_searched <= root_total,
		"%s level %d must report valid completed root candidates: %s" % [side, level, str(stats)])
	assert(root_unsearched == root_total - root_searched,
		"%s level %d must account for every root candidate not covered by a completed pass" % [side, level])
	assert(root_attempted >= 0 and root_attempted <= root_total,
		"%s level %d must report valid attempted root candidates" % [side, level])
	assert(completed_depth >= 0 and completed_depth <= target_depth,
		"%s level %d must distinguish completed depth from target depth" % [side, level])
	if completed_depth > 0:
		assert(root_searched == root_total,
			"A completed iterative-deepening pass must cover every root move")
	else:
		assert(root_searched == 0,
			"Incomplete first pass must not count partial root scores as completed")
	var coverage := 100.0 * float(root_searched) / float(root_total)
	var attempted_coverage := 100.0 * float(root_attempted) / float(root_total)
	print("WOLF-DUSK-059 SEARCH side=%s level=%d target_depth=%d completed_depth=%d iterations=%d nodes=%d elapsed_ms=%.2f root_moves=%d completed_root=%d attempted_root=%d root_coverage_pct=%.1f attempted_coverage_pct=%.1f stop=%s time_budget_ms=%.2f" % [
		side, level, target_depth, completed_depth, int(stats.get("iterations_completed", 0)),
		int(stats.get("nodes", 0)), float(stats.get("total_usec", 0)) / 1000.0,
		root_total, root_searched, root_attempted, coverage, attempted_coverage,
		str(stats.get("stop_reason", "missing")), float(stats.get("time_limit_usec", 0)) / 1000.0
	])

func _run() -> void:
	for level in range(5):
		seed(460046 + level)
		var state = GameState.new()
		var placements: Array[int] = []
		for _i in range(3):
			var placement: int = AI.choose_wolf_placement(state, level)
			assert(placement >= 0 and placement < BoardGraph.NODE_COUNT)
			assert(not state.is_occupied(placement))
			assert(state.place_wolf(placement), "Level %d returned an illegal opening placement" % level)
			placements.append(placement)
		assert(placements.size() == 3 and state.turn == GameState.Turn.SHEEP)

		var sheep_move: Dictionary = AI.choose_sheep_move(state, level)
		assert(not sheep_move.is_empty(), "Level %d sheep AI returned no move" % level)
		var sheep_from := int(sheep_move.get("from", -1))
		var sheep_to := int(sheep_move.get("to", -1))
		assert(sheep_to in state.sheep_moves(sheep_from),
			"Level %d sheep AI returned an illegal move %d>%d" % [level, sheep_from, sheep_to])
		if level >= 2:
			_assert_search_report("sheep", level, AI.last_search_stats.duplicate())
		assert(state.move_sheep(sheep_from, sheep_to))

		var wolf_move: Dictionary = AI.choose_wolf_move(state, level)
		assert(not wolf_move.is_empty(), "Level %d wolf AI returned no move" % level)
		var wolf_from := int(wolf_move.get("from", -1))
		var wolf_to := int(wolf_move.get("to", -1))
		var legal_wolf_action := false
		for option in state.capture_options(wolf_from):
			if int(option.to) == wolf_to:
				legal_wolf_action = true
		if wolf_to in state.wolf_moves(wolf_from):
			legal_wolf_action = true
		assert(legal_wolf_action,
			"Level %d wolf AI returned an illegal move %d>%d" % [level, wolf_from, wolf_to])
		if level >= 2:
			_assert_search_report("wolf", level, AI.last_search_stats.duplicate())

	print("WOLF-DUSK-058 five-level audit passed: all five levels made legal placements and moves for both sides; search coverage was reported separately from target depth.")
	quit()
