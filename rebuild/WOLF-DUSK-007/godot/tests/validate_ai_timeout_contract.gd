extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _new_playing_state():
	var state = GameState.new()
	assert(state.place_wolf(0))
	assert(state.place_wolf(4))
	assert(state.place_wolf(12))
	assert(state.turn == GameState.Turn.SHEEP)
	return state

func _context(node_limit: int) -> Dictionary:
	return {
		"nodes": 0,
		"node_limit": node_limit,
		"start": Time.get_ticks_usec(),
		"time_limit": 1000000000,
		"ordering_usec": 0,
		"ordering_limit_usec": 1000000000
	}

func _run() -> void:
	var state = _new_playing_state()

	# A forced node-budget stop below the root must be reported as incomplete
	# and must propagate to the caller instead of becoming an ordinary score.
	var interrupted_context := _context(2)
	var interrupted_path: Dictionary = {}
	var interrupted: Dictionary = AI._search_node(
		state, 4, -INF, INF, true, interrupted_context, interrupted_path
	)
	assert(not bool(interrupted.get("completed", true)),
		"An interrupted internal subtree must explicitly report completed=false")
	assert(int(interrupted_context.nodes) >= 2,
		"The deterministic node budget must actually interrupt the search")
	assert(interrupted_path.is_empty(),
		"Search-path identity entries must be removed after an interrupted return")

	# A shallow search with sufficient budget must still return a complete score.
	var complete_context := _context(10000)
	var complete_path: Dictionary = {}
	var complete: Dictionary = AI._search_node(
		state, 1, -INF, INF, true, complete_context, complete_path
	)
	assert(bool(complete.get("completed", false)),
		"A search that finishes its requested horizon must report completed=true")
	assert(complete.has("score"), "A completed search must provide a numeric score")
	assert(complete_path.is_empty(),
		"Search-path identity entries must be removed after a completed return")

	# If the first iterative-deepening pass cannot finish, the root must return
	# a legal fallback but must not claim any depth or root candidate was completed.
	var root_context := _context(2)
	var fallback: Dictionary = AI._search_best_move_with_context(state, true, 4, root_context)
	assert(not fallback.is_empty(), "Timeout must preserve a legal fallback move")
	var from_node := int(fallback.get("from", -1))
	var to_node := int(fallback.get("to", -1))
	assert(to_node in state.sheep_moves(from_node),
		"Timeout fallback must remain a legal sheep move")
	var interrupted_stats: Dictionary = AI.last_search_stats.duplicate()
	assert(int(interrupted_stats.get("completed_depth", -1)) == 0,
		"An incomplete first pass must not be reported as a completed depth")
	assert(int(interrupted_stats.get("root_moves_searched", -1)) == 0,
		"Partial root candidates must not be counted as completed searches")
	assert(bool(interrupted_stats.get("search_aborted", false)),
		"An interrupted iterative-deepening pass must be marked aborted")
	assert(int(interrupted_stats.get("root_moves_attempted", 0)) > 0,
		"The test must prove that a root candidate was actually attempted")

	# With ample budget, depth 2 must complete across every legal root move.
	var full_context := _context(100000)
	var full_move: Dictionary = AI._search_best_move_with_context(state, true, 2, full_context)
	assert(not full_move.is_empty(), "A fully budgeted search must return a move")
	var full_stats: Dictionary = AI.last_search_stats.duplicate()
	assert(int(full_stats.get("completed_depth", 0)) == 2,
		"Depth 2 must be recorded only after its full root pass completes")
	assert(int(full_stats.get("root_moves_searched", 0)) == int(full_stats.get("root_moves", -1)),
		"A completed root pass must account for every legal root candidate")

	print("WOLF-DUSK-059 timeout contract passed: incomplete child scores propagate as incomplete, path state is cleaned, fallback stays legal, and only a fully completed root iteration is committed.")
	quit()
