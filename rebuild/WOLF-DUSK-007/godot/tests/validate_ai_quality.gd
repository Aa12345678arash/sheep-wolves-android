extends SceneTree

const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# The board contains diagonal links: A1 -> B2 -> C3 -> D4 -> E5
	# is four legal moves, although the Euclidean distance is much larger.
	assert(AI._graph_distance(0, 24) == 4, "Pursuit must use legal graph distance across diagonal links")
	assert(AI._graph_distance(0, 12) == 2, "A1 to C3 must be two legal graph moves")
	assert(AI._graph_distance(0, 6) == 1, "A1 to B2 must be one legal graph move")
	assert(AI._graph_distance(24, 0) == AI._graph_distance(0, 24), "Graph distance must be symmetric")
	assert(AI._graph_distance(7, 7) == 0, "Distance from a node to itself must be zero")
	assert(AI._graph_distance(-1, 7) == -1, "Invalid nodes must be rejected")
	print("WOLF-DUSK-045 graph-distance quality checks passed.")
	quit()
