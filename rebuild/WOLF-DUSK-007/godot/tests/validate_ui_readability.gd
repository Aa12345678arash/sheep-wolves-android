extends SceneTree

const Meadow = preload("res://scripts/meadow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Exercise the responsive settings panel at a common narrow-phone viewport.
	root.size = Vector2i(360, 740)
	var meadow = Meadow.new()
	root.add_child(meadow)
	await process_frame

	assert(meadow.status_label.get_theme_font_size("font_size") >= 28, "Turn/status text must be comfortably readable")
	assert(meadow.capture_count_label.get_theme_font_size("font_size") >= 21, "Capture counter text must be readable")
	assert(meadow.detail_label.get_theme_font_size("font_size") >= 20, "Game instructions must be readable")
	assert(meadow.message_label.get_theme_font_size("font_size") >= 20, "Feedback messages must be readable")

	assert(is_instance_valid(meadow.setup_layer), "Settings panel must open on launch")
	assert(meadow.setup_layer.get_child_count() >= 2, "Settings overlay must contain shade and panel")
	var panel := meadow.setup_layer.get_child(1) as PanelContainer
	assert(panel != null, "Settings panel container must exist")
	var viewport_size := meadow.get_viewport().get_visible_rect().size
	assert(panel.size.x <= viewport_size.x + 1.0, "Settings panel must fit the available phone width")
	assert(panel.size.y <= viewport_size.y + 1.0, "Settings panel must fit the available phone height")
	assert(panel.get_child_count() == 1 and panel.get_child(0) is ScrollContainer, "Settings content must scroll on smaller screens")

	var option_buttons := panel.find_children("*", "OptionButton", true, false)
	assert(option_buttons.size() == 3, "Mode, side and difficulty selectors must all be present")
	for option in option_buttons:
		assert(option.custom_minimum_size.y >= 52.0, "Settings selectors must have larger touch targets")
		assert(option.get_theme_font_size("font_size") >= 18, "Settings selector text must be readable")

	var edits := panel.find_children("*", "LineEdit", true, false)
	assert(edits.size() == 2, "Both player-name fields must remain available")
	for edit in edits:
		assert(edit.custom_minimum_size.y >= 52.0, "Player-name fields must have larger touch targets")

	meadow.queue_free()
	print("WOLF-DUSK-UI-020 checks passed: readable HUD, responsive settings panel, scrolling content and larger touch targets.")
	quit()
