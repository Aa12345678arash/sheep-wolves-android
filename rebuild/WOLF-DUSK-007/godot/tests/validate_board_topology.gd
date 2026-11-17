extends SceneTree

const BoardGraph = preload("res://scripts/board_graph.gd")

func _initialize() -> void:
	assert(BoardGraph.NODE_COUNT == 25, "The canonical graph must contain 25 nodes")
	assert(BoardGraph.EDGES.size() == 56, "The canonical graph must contain 56 undirected edges")

	var adjacency := BoardGraph.adjacency()
	var orthogonal_edges := 0
	var diagonal_edges := 0
	for edge in BoardGraph.EDGES:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		var ar: int = int(a / 5)
		var ac: int = a % 5
		var br: int = int(b / 5)
		var bc: int = b % 5
		var dr: int = absi(br - ar)
		var dc: int = absi(bc - ac)
		if dr + dc == 1:
			orthogonal_edges += 1
		elif dr == 1 and dc == 1:
			diagonal_edges += 1
			assert((ar + ac) % 2 == 0 and (br + bc) % 2 == 0,
				"Diagonal edges must connect only even-parity nodes")
		else:
			assert(false, "Unexpected edge geometry: %d-%d" % [a, b])

	assert(orthogonal_edges == 40, "Expected 40 orthogonal edges")
	assert(diagonal_edges == 16, "Expected 16 diagonal edges")

	var degree_histogram: Dictionary = {}
	for node in range(BoardGraph.NODE_COUNT):
		var degree: int = adjacency[node].size()
		degree_histogram[degree] = int(degree_histogram.get(degree, 0)) + 1
	assert(int(degree_histogram.get(3, 0)) == 12, "Expected twelve degree-3 boundary nodes")
	assert(int(degree_histogram.get(4, 0)) == 4, "Expected four degree-4 nodes")
	assert(int(degree_histogram.get(5, 0)) == 4, "Expected four degree-5 nodes")
	assert(int(degree_histogram.get(8, 0)) == 5, "Expected five degree-8 even-parity interior nodes")

	# Interior even-parity nodes have degree 8; interior odd-parity nodes have degree 4.
	for row in range(1, 4):
		for col in range(1, 4):
			var node: int = row * 5 + col
			if (row + col) % 2 == 0:
				assert(adjacency[node].size() == 8, "Even-parity interior node must have degree 8")
			else:
				assert(adjacency[node].size() == 4, "Odd-parity interior node must have degree 4")

	# Count each straight three-node jump geometry once at its middle node.
	var all_triples := 0
	var orthogonal_triples := 0
	var diagonal_triples := 0
	for middle in range(BoardGraph.NODE_COUNT):
		for i in range(adjacency[middle].size()):
			for j in range(i + 1, adjacency[middle].size()):
				var a: int = int(adjacency[middle][i])
				var b: int = int(adjacency[middle][j])
				var adr: int = int(a / 5) - int(middle / 5)
				var adc: int = a % 5 - middle % 5
				var bdr: int = int(b / 5) - int(middle / 5)
				var bdc: int = b % 5 - middle % 5
				if adr == -bdr and adc == -bdc:
					all_triples += 1
					if absi(adr) + absi(adc) == 1:
						orthogonal_triples += 1
					elif absi(adr) == 1 and absi(adc) == 1:
						diagonal_triples += 1
					else:
						assert(false, "Unexpected straight-jump geometry")

	assert(all_triples == 40, "Expected 40 undirected straight jump triples")
	assert(orthogonal_triples == 30, "Expected 30 orthogonal jump triples")
	assert(diagonal_triples == 10, "Expected 10 diagonal jump triples")
	assert(all_triples * 2 == 80, "Expected 80 directed jump options before occupancy checks")

	print("PASS: canonical graph has 40 orthogonal + 16 diagonal edges, correct parity/degrees, and 40 straight jump triples (30 orthogonal, 10 diagonal).")
	quit(0)
