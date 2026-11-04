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

	assert(meadow.player_names_label.get_theme_font_size("font_size") >= 24, "Player names must be readable")
	assert(meadow.status_label.get_theme_font_size("font_size") >= 32, "Turn/status text must be comfortably readable")
	assert(meadow.capture_count_label.get_theme_font_size("font_size") >= 24, "Capture counter text must be readable")
	assert(meadow.detail_label.get_theme_font_size("font_size") >= 22, "Game instructions must be readable")
	assert(meadow.message_label.get_theme_font_size("font_size") >= 22, "Feedback messages must be readable")

	assert(is_instance_valid(meadow.setup_layer), "Settings panel must open on launch")
	assert(meadow.setup_layer.get_child_count() >= 2, "Settings overlay must contain shade and panel")
	var panel := meadow.setup_layer.get_child(1) as PanelContainer
	assert(panel != null, "Settings panel container must exist")
	var viewport_size := meadow.get_viewport().get_visible_rect().size
	assert(panel.size.x <= viewport_size.x + 1.0, "Settings panel must fit the available phone width")
	assert(panel.size.y <= viewport_size.y + 1.0, "Settings panel must fit the available phone height")
	assert(panel.size.y >= viewport_size.y - 40.0, "Settings panel should use most of the available screen for easier access")
	assert(panel.get_child_count() == 1 and panel.get_child(0) is ScrollContainer, "Settings content must scroll on smaller screens")

	var option_buttons := panel.find_children("*", "OptionButton", true, false)
	assert(option_buttons.size() == 3, "Mode, side and difficulty selectors must all be present")
	for option in option_buttons:
		assert(option.custom_minimum_size.y >= 62.0, "Settings selectors must have larger touch targets")
		assert(option.get_theme_font_size("font_size") >= 22, "Settings selector text must be readable")

	var edits := panel.find_children("*", "LineEdit", true, false)
	assert(edits.size() == 2, "Both player-name fields must remain available")
	for edit in edits:
		assert(edit.custom_minimum_size.y >= 62.0, "Player-name fields must have larger touch targets")

	var grids := meadow.find_children("*", "GridContainer", true, false)
	assert(not grids.is_empty(), "Bottom controls must be arranged in a two-column touch-friendly grid")
	var controls := grids[0] as GridContainer
	assert(controls.columns == 2, "Phone controls must use two columns rather than narrow one-row buttons")
	var control_buttons := controls.find_children("*", "Button", true, false)
	assert(control_buttons.size() >= 5, "All game controls must remain available")
	for button in control_buttons:
		assert(button.custom_minimum_size.y >= 54.0, "Game controls need comfortable touch targets")

	# The exported app should open directly into the game, not display the Godot logo splash.
	var config := FileAccess.get_file_as_string("res://project.godot")
	assert(config.contains("boot_splash/show_image=false"), "Godot boot splash must be hidden for direct game launch")

	meadow.queue_free()
	print("WOLF-DUSK-022 checks passed: direct game launch, larger readable HUD, two-column controls, responsive settings and larger touch targets.")
	quit()
