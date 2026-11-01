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
		var score := _sheep_position_score(state, int(move.from), int(move.to))
		if difficulty >= 2:
			score += _sheep_safety_score(state, int(move.to)) * 1.5
		if score > best_score:
			best_score = score
			best = move
	return best

static func choose_wolf_move(state, difficulty: int) -> Dictionary:
	var moves: Array[Dictionary] = []
	for from in range(BoardGraph.NODE_COUNT):
		if not state.wolves[from]:
			continue
		for capture in state.capture_options(from):
			moves.append({"from": from, "to": capture.to, "capture": true})
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
	var score := float(to_row - from_row) * 0.4 + _centrality(to) * 0.2
	score += _sheep_safety_score(state, to)
	return score

static func _sheep_safety_score(state, node: int) -> float:
	var danger := 0.0
	for wolf_node in range(BoardGraph.NODE_COUNT):
		if state.wolves[wolf_node]:
			for capture in state.capture_options(wolf_node):
				if int(capture.middle) == node:
					danger += 3.0
	return -danger

static func _future_capture_potential(state, node: int) -> float:
	var total := 0.0
	for middle in BoardGraph.adjacency()[node]:
		if state.sheep[middle] > 0:
			total += 1.0
	return total
