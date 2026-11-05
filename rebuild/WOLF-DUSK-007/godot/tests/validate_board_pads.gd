extends SceneTree

const Meadow = preload("res://scripts/meadow.gd")
const GameState = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var meadow = Meadow.new()
	root.add_child(meadow)
	await process_frame

	assert(meadow.node_visuals.size() == 25, "All 25 board nodes must have a visual platform")
	assert(Meadow.NODE_PAD_RADIUS * 2.0 < Meadow.SPACING, "Neighboring platforms must leave a visible path gap")
	for index in range(25):
		var visual: Node3D = meadow.node_visuals[index]
		var platform := visual.get_node_or_null("NodePlatform") as MeshInstance3D
		assert(platform != null, "Every node must expose a physical platform")
		assert(platform.mesh is CylinderMesh, "Node platform must use a cylindrical pad mesh")
		assert(visual.get_node_or_null("NodePlatformGoldTrim") is MeshInstance3D, "Every enlarged pad must have a visible gold rim")
		var pad := platform.mesh as CylinderMesh
		assert(pad.top_radius >= 1.00 and pad.bottom_radius >= 1.00, "Enlarged platform diameter must comfortably fit five clustered sheep")
		assert(pad.height >= 0.12, "Platform must have visible physical thickness")

	# Put five sheep on one start point and verify all five visible slots fit inside its platform.
	meadow.game.sheep[0] = 5
	meadow._refresh_board()
	var sheep_visual: Node3D = meadow.node_visuals[0]
	var slots: Array[Node3D] = []
	for child in sheep_visual.get_children():
		if child is Node3D and child.name.begins_with("SheepSlot_"):
			slots.append(child)
	assert(slots.size() == 5, "A start node must visibly accommodate all five sheep")
	for slot in slots:
		# Approximate the visible sheep footprint (forward nose/head and outer wool width), not only its pivot.
		var footprint_x := absf(slot.position.x) + 0.38
		var footprint_z := absf(slot.position.z) + 0.20
		var footprint_radius := Vector2(footprint_x, footprint_z).length()
		assert(footprint_radius < Meadow.NODE_PAD_RADIUS, "The complete sheep footprint must stay inside the enlarged platform")
	assert(Meadow.SHEEP_SLOT_SPACING <= 0.38, "Five sheep must remain grouped closely on the starting platform")

	# The enlarged platforms must not change the canonical graph or gameplay setup.
	assert(meadow.game.sheep.size() == 25, "Sheep state must remain mapped to 25 board nodes")
	assert(meadow.game.wolves.size() == 25, "Wolf state must remain mapped to 25 board nodes")
	assert(meadow.node_areas.size() == 25, "All 25 mobile touch areas must remain available")

	meadow.queue_free()
	print("WOLF-DUSK-021 checks passed: 25 physical node platforms, five sheep fit within a start pad, and board touch areas remain intact.")
	quit()
