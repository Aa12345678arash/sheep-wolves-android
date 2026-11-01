extends RefCounted
class_name BoardGraph

# Canonical graph recovered from the archived, previously tested 0.5.1 HTML source.
# Row-major node IDs: A1..A5, B1..B5, ... E1..E5.
const NODE_COUNT := 25
const EXPECTED_EDGE_COUNT := 56
const NODE_LABELS := ["A1", "A2", "A3", "A4", "A5", "B1", "B2", "B3", "B4", "B5", "C1", "C2", "C3", "C4", "C5", "D1", "D2", "D3", "D4", "D5", "E1", "E2", "E3", "E4", "E5"]
const EDGES: Array[Array] = [
	[0, 1],
	[0, 5],
	[1, 2],
	[1, 6],
	[2, 3],
	[2, 7],
	[3, 4],
	[3, 8],
	[4, 9],
	[5, 6],
	[5, 10],
	[6, 7],
	[6, 11],
	[7, 8],
	[7, 12],
	[8, 9],
	[8, 13],
	[9, 14],
	[10, 11],
	[10, 15],
	[11, 12],
	[11, 16],
	[12, 13],
	[12, 17],
	[13, 14],
	[13, 18],
	[14, 19],
	[15, 16],
	[15, 20],
	[16, 17],
	[16, 21],
	[17, 18],
	[17, 22],
	[18, 19],
	[18, 23],
	[19, 24],
	[20, 21],
	[21, 22],
	[22, 23],
	[23, 24],
	[0, 6],
	[2, 6],
	[2, 8],
	[4, 8],
	[6, 10],
	[6, 12],
	[8, 12],
	[8, 14],
	[10, 16],
	[12, 16],
	[12, 18],
	[14, 18],
	[16, 20],
	[16, 22],
	[18, 22],
	[18, 24],
]

static func adjacency() -> Array[Array]:
	var result: Array[Array] = []
	for _i in range(NODE_COUNT):
		result.append([])
	for edge in EDGES:
		var a: int = edge[0]
		var b: int = edge[1]
		result[a].append(b)
		result[b].append(a)
	return result

static func are_adjacent(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= NODE_COUNT or b >= NODE_COUNT:
		return false
	for edge in EDGES:
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a):
			return true
	return false

static func node_label(index: int) -> String:
	if index < 0 or index >= NODE_COUNT:
		return ""
	return NODE_LABELS[index]
