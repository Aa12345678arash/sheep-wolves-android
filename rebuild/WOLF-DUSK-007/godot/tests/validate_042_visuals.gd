extends SceneTree

const Meadow = preload("res://scripts/meadow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var meadow = Meadow.new()
	root.add_child(meadow)
	# The real scene intentionally waits briefly before building the meadow;
	# allow that production startup sequence to finish before inspecting visuals.
	await create_timer(0.40).timeout

	assert(meadow.node_visuals.size() == 25, "The cinematic character pass must preserve all 25 board nodes")
	var expected_flocks := 0
	for count in meadow.game.sheep:
		if int(count) > 0:
			expected_flocks += 1
	assert(meadow.sheep_idle_pivots.size() == expected_flocks, "Exactly one lightweight idle pivot must be registered for each occupied sheep flock")

	if not meadow.sheep_idle_pivots.is_empty():
		var probe: Node3D = meadow.sheep_idle_pivots[0]
		var base_y := float(probe.get_meta("idle_base_y", 0.29))
		meadow.sheep_anim_clock = PI / 3.2
		meadow._process(0.0)
		assert(probe.position.y > base_y + 0.008, "Representative sheep must visibly breathe/bob during idle animation")
		assert(absf(probe.rotation.x) <= 0.02, "Sheep idle motion must remain subtle and must not distort board readability")

	# The visual animation is presentation-only: it must not alter board state or rules.
	var sheep_before: Variant = meadow.game.sheep.duplicate()
	var wolves_before: Variant = meadow.game.wolves.duplicate()
	meadow._process(0.016)
	assert(meadow.game.sheep == sheep_before, "Sheep idle animation must not mutate sheep positions or counts")
	assert(meadow.game.wolves == wolves_before, "Sheep idle animation must not mutate wolf positions")

	meadow.queue_free()
	print("WOLF-DUSK-042 visual checks passed: 25-node board retained, one animated representative per flock, subtle idle motion, and unchanged game state.")
	quit()
