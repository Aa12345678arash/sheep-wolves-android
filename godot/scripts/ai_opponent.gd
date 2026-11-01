extends RefCounted
class_name WolfDuskAI

# Deterministic, rule-respecting move selector. Difficulty: 0 easy, 1 medium, 2 hard.
const BoardGraph = preload("res://scripts/board_graph.gd")

static func choose_wolf_placement(state, difficulty: int) -> int:
	var candidates: Array[int] = []
	for node in range(BoardGraph.NODE_COUNT):
		if not state.is_occupied(node):
			candidates.append(node)
	if candidates.is_empty():
		return -1
	if difficulty == 0:
		return candidates[randi() % candidates.size()]
	var best_node: int = candidates[0]
	var best_score := -INF
	for node in candidates:
		var score := _centrality(node)
		if difficulty >= 2:
			score += _future_mobility(state, node) * 0.35
		if score > best_score:
			best_score = score
			best_node = node
	return best_node

static func choose_sheep_move(state, difficulty: int) -> Dictionary:
	var moves: Array[Dictionary] = []
	for from in range(BoardGraph.NODE_COUNT):
		if state.sheep[from] <= 0:
			continue
		for to in state.sheep_moves(from):
			moves.append({"from": from, "to": to})
	if moves.is_empty():
		return {}
	if difficulty == 0:
		return moves[randi() % moves.size()]
	var best: Dictionary = moves[0]
	var best_score := -INF
	for move in moves:
		var score := _sheep_move_score(state, int(move.from), int(move.to), difficulty)
		if score > best_score:
			best_score = score
			best = move
	return best

static func choose_wolf_move(state, difficulty: int) -> Dictionary:
	var moves: Array[Dictionary] = []
	# During an optional chain capture, only the wolf that made the first
	# capture may move, and only another capture is legal.
	var first_wolf := state.chain_wolf if state.chain_wolf != -1 else 0
	var last_wolf := state.chain_wolf + 1 if state.chain_wolf != -1 else BoardGraph.NODE_COUNT
	for from in range(first_wolf, last_wolf):
		if not state.wolves[from]:
			continue
		for capture in state.capture_options(from):
			moves.append({"from": from, "to": capture.to, "capture": true})
		if state.chain_wolf == -1:
			for to in state.wolf_moves(from):
				moves.append({"from": from, "to": to, "capture": false})
	if moves.is_empty():
		return {}
	if difficulty == 0:
		return moves[randi() % moves.size()]
	var best: Dictionary = moves[0]
	var best_score := -INF
	for move in moves:
		var score := 100.0 if bool(move.capture) else _centrality(int(move.to)) * 2.0
		if difficulty >= 2:
			score += _future_capture_potential(state, int(move.to)) * 2.5
			score += _future_mobility(state, int(move.to)) * 0.25
		if score > best_score:
			best_score = score
			best = move
	return best

static func _centrality(node: int) -> float:
	var row := int(node / 5)
	var col := node % 5
	return 4.0 - absf(float(row) - 2.0) - absf(float(col) - 2.0)

static func _future_mobility(state, node: int) -> float:
	var count := 0.0
	for next_node in BoardGraph.adjacency()[node]:
		if not state.is_occupied(next_node):
			count += 1.0
	return count

static func _sheep_position_score(state, from: int, to: int) -> float:
	var from_row := int(from / 5)
	var to_row := int(to / 5)
	# Sheep begin on row E and advance toward row A, where the wolves approach.
	return float(from_row - to_row) * 0.4 + _centrality(to) * 0.2

static func _sheep_move_score(state, from: int, to: int, difficulty: int) -> float:
	var score := _sheep_position_score(state, from, to)
	if difficulty >= 1:
		var safety_weight := 1.0 if difficulty == 1 else 2.5
		score += _sheep_safety_score(state, to, from) * safety_weight
	return score

static func _sheep_safety_score(state, node: int, vacated_from: int = -1) -> float:
	# Evaluate the proposed destination as if the sheep had already moved there.
	# A wolf threatens this point when it can jump over it and land on a free node.
	var danger := 0.0
	var adjacency := BoardGraph.adjacency()
	var node_row := int(node / 5)
	var node_col := node % 5
	for wolf_node in range(BoardGraph.NODE_COUNT):
		if not state.wolves[wolf_node]:
			continue
		var wolf_row := int(wolf_node / 5)
		var wolf_col := wolf_node % 5
		var dr := node_row - wolf_row
		var dc := node_col - wolf_col
		if node not in adjacency[wolf_node]:
			continue
		for landing in adjacency[node]:
			if landing == wolf_node:
				continue
			var landing_row := int(landing / 5)
			var landing_col := landing % 5
			if landing_row - node_row != dr or landing_col - node_col != dc:
				continue
			if landing == vacated_from or not state.is_occupied(landing):
				danger += 3.0
	return -danger

static func _future_capture_potential(state, node: int) -> float:
	var total := 0.0
	for middle in BoardGraph.adjacency()[node]:
		if state.sheep[middle] > 0:
			total += 1.0
	return total
