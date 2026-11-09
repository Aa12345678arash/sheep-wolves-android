extends RefCounted
class_name WolfDuskAI

# Deterministic, rule-respecting move selector. Difficulty: 0 easy, 1 medium, 2 hard.
const BoardGraph = preload("res://scripts/board_graph.gd")
const GameState = preload("res://scripts/game_state.gd")

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
	if difficulty >= 2:
		return _search_best_move(state, true, _search_depth(difficulty))
	var best: Dictionary = moves[0]
	var best_score := -INF
	for move in moves:
		var score := _sheep_move_score(state, int(move.from), int(move.to), difficulty)
		if score > best_score:
			best_score = score
			best = move
	return best

static func choose_wolf_move(state, difficulty: int) -> Dictionary:
	# Every tier must receive the same legal chain choices, including an explicit
	# option to end the wolf turn. Tiers differ in how they rank those choices.
	if state.chain_wolf != -1:
		var chain_actions := _legal_search_moves(state, true)
		if chain_actions.is_empty():
			return {}
		if difficulty == 0:
			return chain_actions[randi() % chain_actions.size()]
		if difficulty >= 2:
			return _search_best_move(state, false, _search_depth(difficulty))
		var best_chain_action: Dictionary = chain_actions[0]
		var best_chain_score := -INF
		for action in chain_actions:
			var child = _copy_state(state)
			_apply_search_move(child, action)
			var score := _evaluate_position(child, false)
			if score > best_chain_score:
				best_chain_score = score
				best_chain_action = action
		return best_chain_action

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
	if difficulty >= 2:
		return _search_best_move(state, false, _search_depth(difficulty))
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
		var safety_weight := 1.0 if difficulty == 1 else (2.5 if difficulty == 2 else (3.4 if difficulty == 3 else 4.6))
		score += _sheep_safety_score(state, to, from) * safety_weight
	if difficulty >= 2:
		# Prefer destinations with genuine escape routes, not just forward progress.
		var mobility_weight := 0.65 if difficulty == 2 else (1.0 if difficulty == 3 else 1.35)
		score += float(_sheep_escape_mobility(state, from, to)) * mobility_weight
		# Penalize moves that leave the moved sheep directly exposed to a wolf.
		var pressure_weight := 1.5 if difficulty == 2 else (2.1 if difficulty == 3 else 2.8)
		score += _wolf_pressure_on_sheep(state, to, from) * -pressure_weight
		if difficulty >= 4 and _sheep_escape_mobility(state, from, to) <= 1:
			score -= 2.0
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
			var origin_frees: bool = false
			if vacated_from >= 0:
				origin_frees = landing == vacated_from and int(state.sheep[vacated_from]) == 1
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
		var follow_up_weight := 24.0 if difficulty == 2 else (31.0 if difficulty == 3 else 42.0)
		var threat_weight := 8.0 if difficulty == 2 else (12.0 if difficulty == 3 else 18.0)
		var mobility_weight := 0.8 if difficulty == 2 else (1.15 if difficulty == 3 else 1.6)
		score += float(follow_up_captures) * follow_up_weight
		score += float(_count_threatened_sheep_after(state, from, to, captured_middle)) * threat_weight
		score += float(mobility) * mobility_weight
		# Higher tiers avoid isolated wolves and favor coordinated hunting lanes.
		if mobility == 0 and follow_up_captures == 0:
			score -= 5.0 if difficulty == 2 else (9.0 if difficulty == 3 else 15.0)
		if difficulty >= 4 and mobility <= 1 and follow_up_captures == 0:
			score -= 4.0
	return score

static func _count_capture_options_after(state, wolf_from: int, wolf_to: int, captured_middle: int) -> int:
	var total := 0
	var adjacency := BoardGraph.adjacency()
	var wolf_row := int(wolf_to / 5)
	var wolf_col := wolf_to % 5
	for middle in adjacency[wolf_to]:
		if middle == captured_middle or state.sheep[middle] != 1:
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
		if middle == captured_middle or state.sheep[middle] != 1:
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
		if state.sheep[middle] == 1:
			total += 1.0
	return total

# WOLF-DUSK-AI-015: trigger a fresh validation run for the typed occupancy fix.

# WOLF-DUSK-038: turn-based alpha-beta search for levels 2-4.
static func _search_depth(difficulty: int) -> int:
	# Search complete turns more deeply; mobile limits are enforced by the shared budget.
	return 4 if difficulty == 2 else (6 if difficulty == 3 else 8)

static func _search_node_limit(depth: int) -> int:
	return 7000 if depth <= 4 else (16000 if depth <= 6 else 30000)

static func _search_time_limit_usec(depth: int) -> int:
	return 70000 if depth <= 4 else (150000 if depth <= 6 else 240000)

static func _search_best_move(state, ai_is_sheep: bool, depth: int) -> Dictionary:
	# At the real decision root, include declining an optional second capture.
	var include_chain_decline: bool = state.turn == GameState.Turn.WOLVES and state.chain_wolf != -1
	var moves := _legal_search_moves(state, include_chain_decline)
	if moves.is_empty():
		return {}
	# Start the deadline before move ordering: ordering itself evaluates children
	# and must consume the same mobile time budget as the search.
	var context := {"nodes": 0, "node_limit": _search_node_limit(depth), "start": Time.get_ticks_usec(), "time_limit": _search_time_limit_usec(depth)}
	moves = _order_search_moves(state, moves, true, ai_is_sheep, context)
	var root_order_usec: int = Time.get_ticks_usec() - int(context.start)
	var best_move: Dictionary = moves[0]
	var best_score := -INF
	var alpha := -INF
	var beta := INF
	for move in moves:
		var child = _copy_state(state)
		_apply_search_move(child, move)
		var score := _search_node(child, depth - 1, alpha, beta, ai_is_sheep, context)
		if score > best_score:
			best_score = score
			best_move = move
		alpha = maxf(alpha, best_score)
		if _search_stopped(context):
			break
	last_search_stats = {
			"depth": depth,
			"root_moves": moves.size(),
			"root_order_usec": root_order_usec,
			"total_usec": Time.get_ticks_usec() - int(context.start),
			"nodes": int(context.nodes),
			"node_limit": int(context.node_limit),
			"time_limit_usec": int(context.time_limit),
			"stopped": _search_stopped(context)
		}
	return best_move

static func _search_stopped(context: Dictionary) -> bool:
	return int(context.nodes) >= int(context.node_limit) or Time.get_ticks_usec() - int(context.start) >= int(context.time_limit)

static func _search_node(state, depth: int, alpha: float, beta: float, ai_is_sheep: bool, context: Dictionary) -> float:
	context.nodes = int(context.nodes) + 1
	if state.turn == GameState.Turn.FINISHED or depth <= 0 or _search_stopped(context):
		return _evaluate_position(state, ai_is_sheep)
	var moves := _legal_search_moves(state, true)
	if moves.is_empty():
		return _evaluate_position(state, ai_is_sheep)
	var maximizing: bool = (state.turn == GameState.Turn.SHEEP) == ai_is_sheep
	moves = _order_search_moves(state, moves, maximizing, ai_is_sheep, context)
	var value := -INF if maximizing else INF
	for move in moves:
		var child = _copy_state(state)
		_apply_search_move(child, move)
		var score := _search_node(child, depth - 1, alpha, beta, ai_is_sheep, context)
		if maximizing:
			value = maxf(value, score)
			alpha = maxf(alpha, value)
		else:
			value = minf(value, score)
			beta = minf(beta, value)
		if beta <= alpha or _search_stopped(context):
			break
	return value

static func _order_search_moves(state, moves: Array[Dictionary], maximizing: bool, ai_is_sheep: bool, context: Dictionary = {}) -> Array[Dictionary]:
	# Evaluate children before exploring them so alpha-beta sees forcing captures,
	# immediate escapes and blocking moves first instead of wasting its mobile budget.
	var scored: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for index in range(moves.size()):
		if not context.is_empty() and _search_stopped(context):
			for rest in range(index, moves.size()):
				remaining.append(moves[rest])
			break
		var move: Dictionary = moves[index]
		var child = _copy_state(state)
		_apply_search_move(child, move)
		scored.append({"move": move, "score": _evaluate_position(child, ai_is_sheep)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if maximizing:
			return float(a.score) > float(b.score)
		return float(a.score) < float(b.score)
	)
	var ordered: Array[Dictionary] = []
	for entry in scored:
		ordered.append(entry.move)
	# If the deadline interrupts ordering, preserve every unscored legal action.
	for move in remaining:
		ordered.append(move)
	return ordered

static func _legal_search_moves(state, include_chain_decline: bool) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if state.turn == GameState.Turn.SHEEP:
		for from in range(BoardGraph.NODE_COUNT):
			for to in state.sheep_moves(from):
				moves.append({"side": "sheep", "from": from, "to": to})
	elif state.turn == GameState.Turn.WOLVES:
		if state.chain_wolf != -1 and include_chain_decline:
			moves.append({"side": "decline_chain"})
		var first_wolf: int = state.chain_wolf if state.chain_wolf != -1 else 0
		var last_wolf: int = state.chain_wolf + 1 if state.chain_wolf != -1 else BoardGraph.NODE_COUNT
		for from in range(first_wolf, last_wolf):
			if not state.wolves[from]:
				continue
			for capture in state.capture_options(from):
				moves.append({"side": "wolf", "from": from, "to": int(capture.to), "capture": true})
			if state.chain_wolf == -1:
				for to in state.wolf_moves(from):
					moves.append({"side": "wolf", "from": from, "to": to, "capture": false})
	return moves

static func _copy_state(source):
	var copy = GameState.new()
	copy.sheep = source.sheep.duplicate()
	copy.wolves = source.wolves.duplicate()
	copy.turn = source.turn
	copy.chain_wolf = source.chain_wolf
	copy.chain_capture_count = source.chain_capture_count
	copy.winner = source.winner
	return copy

static func _apply_search_move(state, move: Dictionary) -> void:
	if move.side == "decline_chain":
		state.finish_wolf_turn()
	elif move.side == "sheep":
		state.move_sheep(int(move.from), int(move.to))
	else:
		state.move_wolf(int(move.from), int(move.to))

static func _evaluate_position(state, ai_is_sheep: bool) -> float:
	if state.winner == "wolves":
		return -100000.0 if ai_is_sheep else 100000.0
	if state.winner == "sheep":
		return 100000.0 if ai_is_sheep else -100000.0
	var sheep_count := float(state.sheep_total())
	var sheep_mobility := 0.0
	var sheep_progress := 0.0
	var blocked_sheep := 0.0
	var wolf_mobility := 0.0
	var capture_threats := 0.0
	var blocked_wolves := 0.0
	var wolf_centrality := 0.0
	var nearest_wolf_distance := 0.0
	var sheep_nodes := 0
	var wolf_nodes := 0
	for node in range(BoardGraph.NODE_COUNT):
		if state.sheep[node] > 0:
			sheep_nodes += 1
			var legal_sheep_moves: Array[int] = state.sheep_moves(node)
			sheep_mobility += float(legal_sheep_moves.size())
			sheep_progress += float(4 - int(node / 5)) * float(state.sheep[node])
			if legal_sheep_moves.is_empty():
				blocked_sheep += float(state.sheep[node])
		if state.wolves[node]:
			wolf_nodes += 1
			var wm: int = state.wolf_moves(node).size()
			var captures: int = state.capture_options(node).size()
			wolf_mobility += float(wm)
			capture_threats += float(captures)
			wolf_centrality += _centrality(node)
			if wm == 0 and captures == 0:
				blocked_wolves += 1.0
	# Reward wolves for closing distance, but do not let proximity outweigh legal tactics.
	if wolf_nodes > 0 and sheep_nodes > 0:
		for wolf_node in range(BoardGraph.NODE_COUNT):
			if not state.wolves[wolf_node]:
				continue
			var closest := INF
			for sheep_node in range(BoardGraph.NODE_COUNT):
				if state.sheep[sheep_node] <= 0:
					continue
				var distance := float(_graph_distance(wolf_node, sheep_node))
				closest = minf(closest, distance)
			nearest_wolf_distance += closest
	var sheep_score := sheep_count * 9.0 + sheep_mobility * 1.7 + sheep_progress * 0.55 - blocked_sheep * 3.0 + blocked_wolves * 48.0
	var wolf_score := (25.0 - sheep_count) * 17.0 + capture_threats * 22.0 + wolf_mobility * 1.1 + wolf_centrality * 1.4 - nearest_wolf_distance * 1.8
	var score := sheep_score - wolf_score
	return score if ai_is_sheep else -score


# WOLF-DUSK-045: use the actual 56-edge board graph for pursuit distance.
# Euclidean proximity is misleading on this board because diagonal links and
# missing edges make geometric distance differ from legal movement distance.
static var _graph_distance_cache: Dictionary = {}
# WOLF-DUSK-047 diagnostics: last bounded-search execution, exposed to headless tests.
static var last_search_stats: Dictionary = {}

static func _graph_distance(start_node: int, target_node: int) -> int:
	if start_node < 0 or start_node >= BoardGraph.NODE_COUNT or target_node < 0 or target_node >= BoardGraph.NODE_COUNT:
		return -1
	if start_node == target_node:
		return 0
	var cache_key: int = start_node * BoardGraph.NODE_COUNT + target_node
	if _graph_distance_cache.has(cache_key):
		return int(_graph_distance_cache[cache_key])
	var distances: Array[int] = []
	for _node in range(BoardGraph.NODE_COUNT):
		distances.append(-1)
	var queue: Array[int] = [start_node]
	var head := 0
	distances[start_node] = 0
	var adjacency := BoardGraph.adjacency()
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		for neighbor in adjacency[current]:
			if distances[neighbor] != -1:
				continue
			distances[neighbor] = distances[current] + 1
			if neighbor == target_node:
				var result: int = distances[neighbor]
				_graph_distance_cache[cache_key] = result
				_graph_distance_cache[target_node * BoardGraph.NODE_COUNT + start_node] = result
				return result
			queue.append(neighbor)
	return -1

# WOLF-DUSK-047: diagnostic-only checkpoint; no gameplay scoring changed.
