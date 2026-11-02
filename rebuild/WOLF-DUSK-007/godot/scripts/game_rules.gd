extends RefCounted
class_name GameRules

const SHEEP := "sheep"
const WOLVES := "wolves"

static func neighbors(node_id: String, edges: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in edges:
		var parts: PackedStringArray = key.split("|")
		if parts.size() == 2:
			if parts[0] == node_id:
				result.append(parts[1])
			elif parts[1] == node_id:
				result.append(parts[0])
	return result

static func legal_moves(node_id: String, occupied: Dictionary, edges: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for target in neighbors(node_id, edges):
		if not occupied.has(target):
			result.append(target)
	return result

static func legal_captures(wolf_node: String, occupied: Dictionary, sheep_nodes: Dictionary, edges: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sheep_node in neighbors(wolf_node, edges):
		if not sheep_nodes.has(sheep_node):
			continue
		var w: Vector2i = _coord(wolf_node)
		var s: Vector2i = _coord(sheep_node)
		var delta := s - w
		var landing := s + delta
		var landing_id := _node_id(landing)
		if landing_id == "" or occupied.has(landing_id):
			continue
		if edges.has(BoardData.edge_key(sheep_node, landing_id)):
			result.append({"sheep": sheep_node, "landing": landing_id})
	return result

static func _coord(id: String) -> Vector2i:
	return Vector2i(id.unicode_at(1) - 49, id.unicode_at(0) - 65)

static func _node_id(p: Vector2i) -> String:
	if p.x < 0 or p.x > 4 or p.y < 0 or p.y > 4:
		return ""
	return char(65 + p.y) + str(p.x + 1)

static func wolves_win(sheep_count: int) -> bool:
	return sheep_count <= 8

static func sheep_win(wolf_positions: Array[String], occupied: Dictionary, sheep_nodes: Dictionary, edges: Dictionary) -> bool:
	for wolf in wolf_positions:
		if not legal_moves(wolf, occupied, edges).is_empty():
			return false
		if not legal_captures(wolf, occupied, sheep_nodes, edges).is_empty():
			return false
	return wolf_positions.size() == 3
