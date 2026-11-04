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
	var first_wolf: int = state.chain_wolf if state.chain_wolf != -1 else 0
	var last_wolf: int = state.chain_wolf + 1 if state.chain_wolf != -1 else BoardGraph.NODE_COUNT
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
		var score := _wolf_move_score(state, int(move.from), int(move.to), bool(move.capture), difficulty)
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
	if difficulty >= 2:
		# Prefer destinations with genuine escape routes, not just forward progress.
		score += float(_sheep_escape_mobility(state, from, to)) * 0.65
		# Penalize moves that leave the moved sheep directly exposed to a wolf.
		score += _wolf_pressure_on_sheep(state, to, from) * -1.5
	return score

static func _sheep_escape_mobility(state, from: int, to: int) -> int:
	var total := 0
	for next_node in BoardGraph.adjacency()[to]:
		if next_node == from:
			# The origin is only empty if this was the last sheep in its stack.
			if state.sheep[from] == 1 and not state.wolves[next_node]:
				total += 1
		elif not state.is_occupied(next_node):
			total += 1
	return total

static func _wolf_pressure_on_sheep(state, sheep_node: int, vacated_from: int = -1) -> float:
	var pressure := 0.0
	var adjacency := BoardGraph.adjacency()
	var row := int(sheep_node / 5)
	var col := sheep_node % 5
	for wolf_node in range(BoardGraph.NODE_COUNT):
		if not state.wolves[wolf_node] or sheep_node not in adjacency[wolf_node]:
			continue
		var dr := row - int(wolf_node / 5)
		var dc := col - wolf_node % 5
		for landing in adjacency[sheep_node]:
			if landing == wolf_node:
				continue
			if int(landing / 5) - row != dr or landing % 5 - col != dc:
				continue
			var origin_frees: bool = false
			if vacated_from >= 0:
				origin_frees = landing == vacated_from and int(state.sheep[vacated_from]) == 1
			if origin_frees or (not state.is_occupied(landing) and landing != vacated_from):
				pressure += 1.0
	return pressure

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
		var dc: int = node_col - wolf_col
		if node not in adjacency[wolf_node]:
			continue
		for landing in adjacency[node]:
			if landing == wolf_node:
				continue
			var landing_row := int(landing / 5)
			var landing_col: int = landing % 5
			if landing_row - node_row != dr or landing_col - node_col != dc:
				continue
			var origin_frees := landing == vacated_from and state.sheep[vacated_from] == 1
			if origin_frees or (not state.is_occupied(landing) and landing != vacated_from):
				danger += 3.0
	return -danger

static func _wolf_move_score(state, from: int, to: int, is_capture: bool, difficulty: int) -> float:
	# Score the position after the wolf has moved, not merely the destination.
	var score := 100.0 if is_capture else _centrality(to) * 2.0
	var captured_middle := -1
	if is_capture:
		for option in state.capture_options(from):
			if int(option.to) == to:
				captured_middle = int(option.middle)
				break
	if difficulty == 1:
		if is_capture:
			score += 12.0
		else:
			score += _count_capture_options_after(state, from, to, -1) * 4.0
		score += _count_threatened_sheep_after(state, from, to, captured_middle) * 3.0
		return score
	if difficulty >= 2:
		var follow_up_captures := _count_capture_options_after(state, from, to, captured_middle)
		var mobility := _wolf_mobility_after(state, from, to)
		score += float(follow_up_captures) * 24.0
		score += float(_count_threatened_sheep_after(state, from, to, captured_middle)) * 8.0
		score += float(mobility) * 0.8
		# Avoid moves that leave this wolf stranded when another wolf can cover the area.
		if mobility == 0 and follow_up_captures == 0:
			score -= 5.0
	return score

static func _count_capture_options_after(state, wolf_from: int, wolf_to: int, captured_middle: int) -> int:
	var total := 0
	var adjacency := BoardGraph.adjacency()
	var wolf_row := int(wolf_to / 5)
	var wolf_col := wolf_to % 5
	for middle in adjacency[wolf_to]:
		if middle == captured_middle or state.sheep[middle] <= 0:
			continue
		var dr: int = int(middle / 5) - wolf_row
		var dc: int = int(middle % 5) - wolf_col
		for landing in adjacency[middle]:
			if landing == wolf_to:
				continue
			if int(landing / 5) - int(middle / 5) != dr or landing % 5 - middle % 5 != dc:
				continue
			# The wolf's previous node becomes empty after the simulated move.
			if landing == wolf_from or not state.is_occupied(landing):
				total += 1
	return total

static func _count_threatened_sheep_after(state, wolf_from: int, wolf_to: int, captured_middle: int = -1) -> int:
	var total := 0
	var adjacency := BoardGraph.adjacency()
	var wolf_row := int(wolf_to / 5)
	var wolf_col := wolf_to % 5
	for middle in adjacency[wolf_to]:
		if middle == captured_middle or state.sheep[middle] <= 0:
			continue
		var dr := int(middle / 5) - wolf_row
		var dc := int(middle % 5) - wolf_col
		for landing in adjacency[middle]:
			if landing == wolf_to:
				continue
			if int(landing / 5) - int(middle / 5) != dr or landing % 5 - middle % 5 != dc:
				continue
			var origin_frees: bool = landing == wolf_from and int(state.sheep[wolf_from]) == 0
			if origin_frees or (not state.is_occupied(landing) and landing != wolf_from):
				total += 1
				break
	return total

static func _wolf_mobility_after(state, wolf_from: int, wolf_to: int) -> int:
	var total := 0
	for next_node in BoardGraph.adjacency()[wolf_to]:
		if next_node == wolf_from or not state.is_occupied(next_node):
			total += 1
	return total

static func _future_capture_potential(state, node: int) -> float:
	# Retained as a small positional heuristic for callers that need it.
	var total := 0.0
	for middle in BoardGraph.adjacency()[node]:
		if state.sheep[middle] > 0:
			total += 1.0
	return total
