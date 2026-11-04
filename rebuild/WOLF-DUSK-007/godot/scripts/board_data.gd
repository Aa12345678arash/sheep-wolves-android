extends RefCounted
class_name BoardData

const DATA_PATH := "res://data/canonical_board.json"

static func load_data() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open canonical board data: " + DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Canonical board JSON is invalid")
		return {}
	return parsed

static func node_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for node in data.get("nodes", []):
		result.append(str(node.get("id", "")))
	return result

static func edge_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func edge_set(data: Dictionary) -> Dictionary:
	var result := {}
	for edge in data.get("edges", []):
		result[edge_key(str(edge.from), str(edge.to))] = str(edge.get("type", ""))
	return result

static func validate(data: Dictionary) -> bool:
	var nodes := node_ids(data)
	var edges: Array = data.get("edges", [])
	if nodes.size() != 25 or edges.size() != 56:
		return false
	var known := {}
	for id in nodes:
		if known.has(id):
			return false
		known[id] = true
	var seen := {}
	for edge in edges:
		var a: String = str(edge.get("from", ""))
		var b: String = str(edge.get("to", ""))
		var key := edge_key(a, b)
		if a == b or not known.has(a) or not known.has(b) or seen.has(key):
			return false
		seen[key] = true
	return true
