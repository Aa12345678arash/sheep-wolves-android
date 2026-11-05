extends RefCounted
class_name WolfDuskGameState

const BoardGraph = preload("res://scripts/board_graph.gd")
enum Turn { PLACE_WOLVES, SHEEP, WOLVES, FINISHED }

var sheep: Array[int] = []
var wolves: Array[bool] = []
var turn: Turn = Turn.PLACE_WOLVES
var chain_wolf: int = -1
var chain_capture_count: int = 0
var winner: String = ""

func _init() -> void:
	reset()

func reset() -> void:
	sheep.clear()
	wolves.clear()
	for i in range(BoardGraph.NODE_COUNT):
		sheep.append(5 if i >= 20 else 0)
		wolves.append(false)
	turn = Turn.PLACE_WOLVES
	chain_wolf = -1
	chain_capture_count = 0
	winner = ""

func sheep_total() -> int:
	var total := 0
	for count in sheep:
		total += count
	return total

func wolf_total() -> int:
	var total := 0
	for present in wolves:
		if present:
			total += 1
	return total

func is_occupied(node: int) -> bool:
	return sheep[node] > 0 or wolves[node]

func place_wolf(node: int) -> bool:
	if turn != Turn.PLACE_WOLVES or node < 0 or node >= BoardGraph.NODE_COUNT or is_occupied(node):
		return false
	wolves[node] = true
	if wolf_total() == 3:
		turn = Turn.SHEEP
		_check_winner()
	return true

func sheep_moves(from: int) -> Array[int]:
	var result: Array[int] = []
	if from < 0 or from >= BoardGraph.NODE_COUNT or sheep[from] <= 0:
		return result
	for to in BoardGraph.adjacency()[from]:
		if not is_occupied(to):
			result.append(to)
	return result

func wolf_moves(from: int) -> Array[int]:
	var result: Array[int] = []
	if from < 0 or from >= BoardGraph.NODE_COUNT or not wolves[from]:
		return result
	for to in BoardGraph.adjacency()[from]:
		if not is_occupied(to):
			result.append(to)
	return result

func capture_options(from: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if from < 0 or from >= BoardGraph.NODE_COUNT or not wolves[from]:
		return result
	var adjacency := BoardGraph.adjacency()
	var start_row: int = int(from / 5)
	var start_col: int = from % 5
	for middle in adjacency[from]:
		# A jump is legal only over exactly one sheep.
		if sheep[middle] != 1:
			continue
		var middle_row: int = int(middle / 5)
		var middle_col: int = middle % 5
		var dr: int = middle_row - start_row
		var dc: int = middle_col - start_col
		for destination in adjacency[middle]:
			if destination == from or is_occupied(destination):
				continue
			var dest_row: int = int(destination / 5)
			var dest_col: int = destination % 5
			if dest_row - middle_row == dr and dest_col - middle_col == dc:
				result.append({"middle": middle, "to": destination})
	return result

func move_sheep(from: int, to: int) -> bool:
	if turn != Turn.SHEEP or to not in sheep_moves(from):
		return false
	sheep[from] -= 1
	sheep[to] += 1
	turn = Turn.WOLVES
	_check_winner()
	return true

func move_wolf(from: int, to: int) -> String:
	if turn != Turn.WOLVES or from < 0 or from >= BoardGraph.NODE_COUNT or not wolves[from]:
		return "invalid"
	if chain_wolf != -1 and from != chain_wolf:
		return "wrong_chain_wolf"
	for capture in capture_options(from):
		if capture.to == to:
			wolves[from] = false
			wolves[to] = true
			sheep[capture.middle] -= 1
			chain_capture_count += 1
			chain_wolf = to
			if sheep_total() <= 8:
				winner = "wolves"
				turn = Turn.FINISHED
				return "won"
			if chain_capture_count == 1 and not capture_options(to).is_empty():
				return "captured_chain_available"
			finish_wolf_turn()
			return "captured"
	if chain_wolf != -1:
		return "chain_capture_required"
	if to not in wolf_moves(from):
		return "invalid"
	wolves[from] = false
	wolves[to] = true
	finish_wolf_turn()
	return "moved"

# Called when the player declines the optional follow-up capture or its 3-second window expires.
func finish_wolf_turn() -> void:
	chain_wolf = -1
	chain_capture_count = 0
	turn = Turn.SHEEP
	_check_winner()

func _check_winner() -> void:
	if sheep_total() <= 8:
		winner = "wolves"
		turn = Turn.FINISHED
		return
	if wolf_total() != 3:
		return
	for node in range(BoardGraph.NODE_COUNT):
		if wolves[node] and (not wolf_moves(node).is_empty() or not capture_options(node).is_empty()):
			return
	winner = "sheep"
	turn = Turn.FINISHED
