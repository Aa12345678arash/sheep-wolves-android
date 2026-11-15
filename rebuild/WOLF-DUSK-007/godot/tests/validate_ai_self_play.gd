extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

# WOLF-DUSK-048: expanded competitive audit, full 5x5 level matrix, four reproducible seeds.
# This run measures competitive outcomes; it does not yet claim the AI passes a
# strength threshold. Acceptance thresholds will be set after this baseline.
const MAX_PLY := 120
const SEEDS: Array[int] = [460046, 460047, 480048, 480049]

func _initialize() -> void:
	call_deferred("_run")

func _play_match(wolf_level: int, sheep_level: int, match_seed: int) -> Dictionary:
	seed(match_seed)
	var state = GameState.new()
	var placements: Array[int] = []
	for _i in range(3):
		var node: int = AI.choose_wolf_placement(state, wolf_level)
		assert(node >= 0 and node < 25 and not state.is_occupied(node),
			"Competitive audit: invalid wolf placement at level %d" % wolf_level)
		assert(state.place_wolf(node), "Competitive audit: rules rejected wolf placement")
		placements.append(node)

	var ply := 0
	var sheep_actions := 0
	var wolf_actions := 0
	var captures := 0
	var search_calls := 0
	var search_root_order_usec := 0
	var search_total_usec := 0
	var search_stopped := 0
	var search_nodes := 0
	var search_root_moves := 0
	var search_max_ply := 0
	var search_call_usec: Array[int] = []
	var search_root_moves_per_call: Array[int] = []
	var search_root_moves_available: Array[int] = []
	var sheep_search_times: Array[int] = []
	var sheep_root_searched: Array[int] = []
	var sheep_root_available: Array[int] = []
	var sheep_search_stopped := 0
	var sheep_search_nodes := 0
	var sheep_search_root_order_usec := 0
	var wolf_search_times: Array[int] = []
	var wolf_root_searched: Array[int] = []
	var wolf_root_available: Array[int] = []
	var wolf_search_stopped := 0
	var wolf_search_nodes := 0
	var wolf_search_root_order_usec := 0
	var repetition_count: Dictionary = {}
	var repetition_first_seen: Dictionary = {}
	var move_trace: Array[String] = []
	var draw_reason := ""
	var initial_key := _position_key(state)
	repetition_count[initial_key] = 1
	repetition_first_seen[initial_key] = 0
	while state.turn != GameState.Turn.FINISHED and ply < MAX_PLY and draw_reason == "":
		if state.turn == GameState.Turn.SHEEP:
			var move: Dictionary = AI.choose_sheep_move(state, sheep_level)
			if sheep_level >= 2:
				var call_usec := int(AI.last_search_stats.get("total_usec", 0))
				var root_searched := int(AI.last_search_stats.get("root_moves_searched", 0))
				var root_available := int(AI.last_search_stats.get("root_moves", 0))
				search_calls += 1
				search_root_order_usec += int(AI.last_search_stats.get("root_order_usec", 0))
				search_total_usec += call_usec
				search_nodes += int(AI.last_search_stats.get("nodes", 0))
				search_root_moves += root_searched
				search_max_ply = maxi(search_max_ply, int(AI.last_search_stats.get("max_search_ply", 0)))
				search_call_usec.append(call_usec)
				search_root_moves_per_call.append(root_searched)
				search_root_moves_available.append(root_available)
				sheep_search_times.append(call_usec)
				sheep_root_searched.append(root_searched)
				sheep_root_available.append(root_available)
				sheep_search_nodes += int(AI.last_search_stats.get("nodes", 0))
				sheep_search_root_order_usec += int(AI.last_search_stats.get("root_order_usec", 0))
				if bool(AI.last_search_stats.get("stopped", false)):
					search_stopped += 1
					sheep_search_stopped += 1
			assert(not move.is_empty(), "Sheep AI returned no move in an active match")
			var from_node := int(move.get("from", -1))
			var to_node := int(move.get("to", -1))
			move_trace.append("S:%d>%d" % [from_node, to_node])
			assert(to_node in state.sheep_moves(from_node),
				"Sheep level %d returned illegal move %d -> %d" % [sheep_level, from_node, to_node])
			assert(state.move_sheep(from_node, to_node), "Rules rejected sheep action")
			sheep_actions += 1
		elif state.turn == GameState.Turn.WOLVES:
			var move: Dictionary = AI.choose_wolf_move(state, wolf_level)
			if wolf_level >= 2:
				var call_usec := int(AI.last_search_stats.get("total_usec", 0))
				var root_searched := int(AI.last_search_stats.get("root_moves_searched", 0))
				var root_available := int(AI.last_search_stats.get("root_moves", 0))
				search_calls += 1
				search_root_order_usec += int(AI.last_search_stats.get("root_order_usec", 0))
				search_total_usec += call_usec
				search_nodes += int(AI.last_search_stats.get("nodes", 0))
				search_root_moves += root_searched
				search_max_ply = maxi(search_max_ply, int(AI.last_search_stats.get("max_search_ply", 0)))
				search_call_usec.append(call_usec)
				search_root_moves_per_call.append(root_searched)
				search_root_moves_available.append(root_available)
				wolf_search_times.append(call_usec)
				wolf_root_searched.append(root_searched)
				wolf_root_available.append(root_available)
				wolf_search_nodes += int(AI.last_search_stats.get("nodes", 0))
				wolf_search_root_order_usec += int(AI.last_search_stats.get("root_order_usec", 0))
				if bool(AI.last_search_stats.get("stopped", false)):
					search_stopped += 1
					wolf_search_stopped += 1
			assert(not move.is_empty(), "Wolf AI returned no move in an active match")
			if str(move.get("side", "")) == "decline_chain":
				move_trace.append("W:decline_chain")
				assert(state.chain_wolf != -1, "AI may decline only an active optional chain capture")
				state.finish_wolf_turn()
				wolf_actions += 1
			else:
				var from_node := int(move.get("from", -1))
				var to_node := int(move.get("to", -1))
				move_trace.append("W:%d>%d%s" % [from_node, to_node, "x" if bool(move.get("capture", false)) else ""])
				assert(from_node >= 0 and from_node < 25 and state.wolves[from_node],
					"Wolf AI selected a non-wolf origin")
				var was_capture := false
				for option in state.capture_options(from_node):
					if int(option.to) == to_node:
						was_capture = true
				assert(was_capture or to_node in state.wolf_moves(from_node),
					"Wolf level %d returned illegal move %d -> %d" % [wolf_level, from_node, to_node])
				var result: String = state.move_wolf(from_node, to_node)
				assert(result in ["moved", "captured", "captured_chain_available", "won"],
					"Rules rejected wolf action: " + result)
				if was_capture:
					captures += 1
				wolf_actions += 1
		else:
			assert(false, "Unexpected turn state")
		ply += 1
		if state.turn != GameState.Turn.FINISHED:
			var key := _position_key(state)
			var previous_count := int(repetition_count.get(key, 0))
			if not repetition_first_seen.has(key):
				repetition_first_seen[key] = ply
			repetition_count[key] = previous_count + 1
			if int(repetition_count[key]) == 3:
				var cycle_start_ply := int(repetition_first_seen[key])
				var cycle_moves: Array[String] = []
				for trace_index in range(cycle_start_ply, mini(ply, move_trace.size())):
					cycle_moves.append(move_trace[trace_index])
				print("WOLF-DUSK-048 CYCLE wolf=%d sheep=%d seed=%d first_seen_ply=%d repeated_at_ply=%d cycle_length=%d moves=%s position=%s" % [wolf_level, sheep_level, match_seed, cycle_start_ply, ply, ply - cycle_start_ply, str(cycle_moves), key])
				draw_reason = "threefold_repetition"

	var max_search_call_usec := 0
	var p95_search_call_usec := 0
	var min_root_moves_searched := 0
	var multi_root_decisions := 0
	var multi_root_covered := 0
	if not search_call_usec.is_empty():
		var sorted_search_times: Array[int] = search_call_usec.duplicate()
		sorted_search_times.sort()
		max_search_call_usec = sorted_search_times[sorted_search_times.size() - 1]
		var p95_index := maxi(0, int(ceil(float(sorted_search_times.size()) * 0.95)) - 1)
		p95_search_call_usec = sorted_search_times[p95_index]
		min_root_moves_searched = search_root_moves_per_call[0]
		for index in range(search_root_moves_per_call.size()):
			min_root_moves_searched = mini(min_root_moves_searched, search_root_moves_per_call[index])
			if search_root_moves_available[index] >= 2:
				multi_root_decisions += 1
				if search_root_moves_per_call[index] >= 2:
					multi_root_covered += 1

	return {
		"wolf_level": wolf_level,
		"sheep_level": sheep_level,
		"seed": match_seed,
		"plies": ply,
		"sheep_actions": sheep_actions,
		"wolf_actions": wolf_actions,
		"captures": captures,
		"search_calls": search_calls,
		"search_root_order_usec": search_root_order_usec,
		"search_total_usec": search_total_usec,
		"search_stopped": search_stopped,
		"search_nodes": search_nodes,
		"search_root_moves_searched": search_root_moves,
		"search_max_ply": search_max_ply,
		"sheep_search": _summarize_side_search(sheep_search_times, sheep_root_searched, sheep_root_available, sheep_search_stopped, sheep_search_nodes, sheep_search_root_order_usec),
		"wolf_search": _summarize_side_search(wolf_search_times, wolf_root_searched, wolf_root_available, wolf_search_stopped, wolf_search_nodes, wolf_search_root_order_usec),
		"max_search_call_usec": max_search_call_usec,
		"p95_search_call_usec": p95_search_call_usec,
		"min_root_moves_searched": min_root_moves_searched,
		"multi_root_decisions": multi_root_decisions,
		"multi_root_covered": multi_root_covered,
		"winner": state.winner,
		"draw_reason": draw_reason if draw_reason != "" else ("ply_limit" if state.turn != GameState.Turn.FINISHED else ""),
		"repeated_positions": repetition_count.size(),
		"sheep_remaining": state.sheep_total(),
		"wolves_remaining": state.wolf_total(),
		"placements": placements
	}

func _summarize_side_search(times: Array[int], roots: Array[int], available: Array[int], stopped: int, nodes: int, root_order_usec: int) -> Dictionary:
	var result := {
		"calls": times.size(),
		"total_usec": 0,
		"average_usec": 0,
		"p95_usec": 0,
		"max_usec": 0,
		"stopped": stopped,
		"nodes": nodes,
		"root_order_usec": root_order_usec,
		"root_moves_searched": 0,
		"average_root_moves": 0.0,
		"minimum_root_moves": 0,
		"multi_root_decisions": 0,
		"multi_root_covered": 0
	}
	if times.is_empty():
		return result
	var sorted_times: Array[int] = times.duplicate()
	sorted_times.sort()
	var total_usec := 0
	var root_total := 0
	var min_roots := roots[0]
	var multi_decisions := 0
	var multi_covered := 0
	for index in range(times.size()):
		total_usec += times[index]
		root_total += roots[index]
		min_roots = mini(min_roots, roots[index])
		if available[index] >= 2:
			multi_decisions += 1
			if roots[index] >= 2:
				multi_covered += 1
	var p95_index := maxi(0, int(ceil(float(sorted_times.size()) * 0.95)) - 1)
	result.total_usec = total_usec
	result.average_usec = int(total_usec / times.size())
	result.p95_usec = sorted_times[p95_index]
	result.max_usec = sorted_times[sorted_times.size() - 1]
	result.root_moves_searched = root_total
	result.average_root_moves = float(root_total) / float(times.size())
	result.minimum_root_moves = min_roots
	result.multi_root_decisions = multi_decisions
	result.multi_root_covered = multi_covered
	return result

func _position_key(state) -> String:
	return "%s|%s|%d|%d|%d" % [str(state.sheep), str(state.wolves), int(state.turn), int(state.chain_wolf), int(state.chain_capture_count)]

func _run() -> void:
	var totals := {
		"matches": 0,
		"plies": 0,
		"captures": 0,
		"wolf_wins": 0,
		"sheep_wins": 0,
		"repetition_draws": 0,
		"ply_limit_draws": 0
	}
	var matchup_stats: Dictionary = {}
	for wolf_level in range(5):
		for sheep_level in range(5):
			var key := "%d-%d" % [wolf_level, sheep_level]
			matchup_stats[key] = {
				"matches": 0, "wolf_wins": 0, "sheep_wins": 0,
				"repetition_draws": 0, "ply_limit_draws": 0,
				"plies": 0, "captures": 0, "sheep_remaining": 0
			}
			for match_seed in SEEDS:
				var result := _play_match(wolf_level, sheep_level, match_seed)
				assert(int(result.sheep_actions) > 0 and int(result.wolf_actions) > 0,
					"Both sides must act in every diagnostic match")
				assert(int(result.plies) > 0 and int(result.plies) <= MAX_PLY,
					"Match exceeded its bounded ply budget")
				var winner := str(result.winner)
				var draw_reason := str(result.draw_reason)
				var stats: Dictionary = matchup_stats[key]
				stats.matches = int(stats.matches) + 1
				stats.plies = int(stats.plies) + int(result.plies)
				stats.captures = int(stats.captures) + int(result.captures)
				stats.sheep_remaining = int(stats.sheep_remaining) + int(result.sheep_remaining)
				totals.matches = int(totals.matches) + 1
				totals.plies = int(totals.plies) + int(result.plies)
				totals.captures = int(totals.captures) + int(result.captures)
				if winner == "wolves":
					stats.wolf_wins = int(stats.wolf_wins) + 1
					totals.wolf_wins = int(totals.wolf_wins) + 1
				elif winner == "sheep":
					stats.sheep_wins = int(stats.sheep_wins) + 1
					totals.sheep_wins = int(totals.sheep_wins) + 1
				elif draw_reason == "threefold_repetition":
					stats.repetition_draws = int(stats.repetition_draws) + 1
					totals.repetition_draws = int(totals.repetition_draws) + 1
				else:
					stats.ply_limit_draws = int(stats.ply_limit_draws) + 1
					totals.ply_limit_draws = int(totals.ply_limit_draws) + 1
				print("WOLF-DUSK-048 MATCH ", result)
			print("WOLF-DUSK-048 MATCHUP wolf=%d sheep=%d stats=%s" % [wolf_level, sheep_level, str(matchup_stats[key])])

	assert(int(totals.matches) == 25 * SEEDS.size(),
		"Competitive audit must cover all 25 level pairings with every configured seed")
	assert(int(totals.plies) > 0 and int(totals.matches) > 0,
		"Competitive audit produced no usable match data")
	print("WOLF-DUSK-048 EXPANDED DIAGNOSTIC totals=%s max_ply=%d seeds=%s" % [str(totals), MAX_PLY, str(SEEDS)])
	print("WOLF-DUSK-048 coverage: 25/25 level pairings; %d seeded matches. This is a diagnostic baseline, not a competitive-strength pass." % int(totals.matches))
	quit()
