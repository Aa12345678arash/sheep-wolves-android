extends SceneTree

func _initialize() -> void:
	var path := "res://data/canonical_board.json"
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "canonical_board.json must be present")
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	assert(data.get("nodes", []).size() == 25, "must have 25 nodes")
	assert(data.get("edges", []).size() == 56, "must have 56 edges")
	var known := {}
	for node in data.nodes:
		assert(not known.has(node.id), "duplicate node")
		known[node.id] = true
	var seen := {}
	for edge in data.edges:
		assert(known.has(edge.from) and known.has(edge.to), "edge endpoint missing")
		assert(edge.from != edge.to, "self edge")
		var key := BoardData.edge_key(edge.from, edge.to)
		assert(not seen.has(key), "duplicate undirected edge")
		seen[key] = true
	var total := 0
	assert(data.sheepStartingStacks.size() == 5, "five starting stacks")
	for stack in data.sheepStartingStacks:
		assert(int(stack.count) == 5, "five sheep per starting stack")
		assert(known.has(stack.node), "starting stack node missing")
		total += int(stack.count)
	assert(total == 25, "exactly 25 starting sheep")
	assert(int(data.wolves.count) == 3, "three wolves")
	print("PASS: canonical board has 25 nodes, 56 edges, 25 sheep and 3 wolves.")
	quit(0)
