extends SceneTree

const Meadow = preload("res://scripts/meadow.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Exercise the responsive settings panel at a common narrow-phone viewport.
	root.size = Vector2i(360, 740)
	var meadow = Meadow.new()
	root.add_child(meadow)
	# Allow the CanvasLayer controls to enter the tree and receive their first layout pass.
	await process_frame
	await process_frame

	assert(meadow.player_names_label.get_theme_font_size("font_size") >= 24, "Player names must be readable")
	assert(meadow.status_label.get_theme_font_size("font_size") >= 32, "Turn/status text must be comfortably readable")
	assert(meadow.capture_count_label.get_theme_font_size("font_size") >= 24, "Capture counter text must be readable")
	assert(meadow.detail_label.get_theme_font_size("font_size") >= 22, "Game instructions must be readable")
	assert(meadow.message_label.get_theme_font_size("font_size") >= 22, "Feedback messages must be readable")

	var poster_backgrounds := meadow.find_children("StartScreenPosterBackground", "TextureRect", true, false)
	assert(poster_backgrounds.size() == 1, "Startup screen must include the cinematic poster background")
	assert((poster_backgrounds[0] as TextureRect).texture != null, "Poster background texture must load")
	var setup_headings: Array[Node] = meadow.setup_layer.find_children("*", "Label", true, false)
	var has_large_title := false
	for label in setup_headings:
		if (label as Label).text.contains("گرگ و میش"):
			has_large_title = (label as Label).get_theme_font_size("font_size") >= 40
	assert(has_large_title, "Startup title must use large readable Persian typography")
	var setup_edits: Array[Node] = meadow.setup_layer.find_children("*", "LineEdit", true, false)
	assert(setup_edits.size() == 2, "Both player-name fields must remain available")
	for edit in setup_edits:
		assert((edit as LineEdit).get_theme_font_size("font_size") >= 27, "Player-name text must be large and readable")
		assert((edit as LineEdit).custom_minimum_size.y >= 68.0, "Player-name fields must have comfortable touch targets")
	var setup_options: Array[Node] = meadow.setup_layer.find_children("*", "OptionButton", true, false)
	assert(setup_options.is_empty(), "Setup menu must not use compact dropdown selectors")
	var mode_grids := meadow.setup_layer.find_children("SetupModeChoices", "GridContainer", true, false)
	var side_grids := meadow.setup_layer.find_children("SetupSideChoices", "GridContainer", true, false)
	var difficulty_grids := meadow.setup_layer.find_children("SetupDifficultyChoices", "GridContainer", true, false)
	assert(mode_grids.size() == 1 and side_grids.size() == 1 and difficulty_grids.size() == 1, "All three large choice groups must be present")
	var mode_buttons := mode_grids[0].find_children("*", "Button", true, false)
	var side_buttons := side_grids[0].find_children("*", "Button", true, false)
	var difficulty_buttons := difficulty_grids[0].find_children("*", "Button", true, false)
	assert(mode_buttons.size() == 2, "Both match modes must be available as direct choices")
	assert(side_buttons.size() == 2, "Both player sides must be available as direct choices")
	assert(difficulty_buttons.size() == 5, "All five AI levels must be visible as direct choices")
	for choice in mode_buttons + side_buttons + difficulty_buttons:
		var button := choice as Button
		assert(button.toggle_mode and button.button_group != null, "Setup choices must behave as exclusive selectable buttons")
		assert(button.custom_minimum_size.y >= 68.0, "Setup choices must have large finger-friendly touch targets")
		assert(button.get_theme_font_size("font_size") >= 24, "Setup choice text must be large and readable")
	assert((difficulty_buttons[3] as Button).button_pressed, "Hard AI must remain the default selection")

	assert(is_instance_valid(meadow.setup_layer), "Settings panel must open on launch")
	assert(meadow.setup_layer.get_child_count() >= 2, "Settings overlay must contain shade and panel")
	# The startup panel is a direct child of the setup CanvasLayer. Inspect direct
	# children rather than recursively matching generated control names; this avoids
	# false negatives when Godot assigns an automatic node name during construction.
	var panels: Array[PanelContainer] = []
	for child in meadow.setup_layer.get_children():
		if child is PanelContainer:
			panels.append(child as PanelContainer)
	assert(panels.size() == 1, "Settings panel container must exist exactly once as a direct setup-layer child")
	var panel := panels[0]
	var viewport_size := meadow.get_viewport().get_visible_rect().size
	print("READABILITY_DIAGNOSTIC viewport=", viewport_size, " panel_size=", panel.size, " panel_min=", panel.get_combined_minimum_size(), " offsets=", [panel.offset_left, panel.offset_right, panel.offset_top, panel.offset_bottom])
	assert(panel.size.x <= viewport_size.x + 1.0, "Settings panel must fit the available phone width")
	assert(panel.size.y <= viewport_size.y + 1.0, "Settings panel must fit the available phone height")
	assert(panel.size.y >= viewport_size.y - 40.0, "Settings panel should use most of the available screen for easier access")
	assert(is_zero_approx(panel.offset_top) and is_zero_approx(panel.offset_bottom), "Startup settings panel must extend to the top and bottom viewport edges")
	assert(panel.get_child_count() == 1 and panel.get_child(0) is ScrollContainer, "Settings content must scroll on smaller screens")
	var scroll := panel.get_child(0) as ScrollContainer
	var column := scroll.get_child(0) as VBoxContainer
	assert(column != null, "Startup menu must use a vertical content column")
	assert(column.custom_minimum_size.y >= viewport_size.y - 60.0, "Startup content column must occupy the usable screen height")
	var top_spacers := column.find_children("StartScreenTopSpacer", "Control", true, false)
	var bottom_spacers := column.find_children("StartScreenBottomSpacer", "Control", true, false)
	assert(top_spacers.size() == 1 and bottom_spacers.size() == 1, "Startup menu must balance content with top and bottom flexible spacing")
	assert((top_spacers[0] as Control).size_flags_vertical == Control.SIZE_EXPAND_FILL, "Top spacer must expand to balance the menu")
	assert((bottom_spacers[0] as Control).size_flags_vertical == Control.SIZE_EXPAND_FILL, "Bottom spacer must expand to balance the menu")

	var option_buttons := panel.find_children("*", "OptionButton", true, false)
	assert(option_buttons.size() == 3, "Mode, side and difficulty selectors must all be present")
	var has_five_ai_tiers := false
	for option in option_buttons:
		assert(option.custom_minimum_size.y >= 62.0, "Settings selectors must have larger touch targets")
		assert(option.get_theme_font_size("font_size") >= 22, "Settings selector text must be readable")
		if option.item_count == 5:
			has_five_ai_tiers = true
	assert(has_five_ai_tiers, "AI difficulty selector must expose all five named levels")

	var edits := panel.find_children("*", "LineEdit", true, false)
	assert(edits.size() == 2, "Both player-name fields must remain available")
	for edit in edits:
		assert(edit.custom_minimum_size.y >= 62.0, "Player-name fields must have larger touch targets")

	var grids := meadow.find_children("HudControlGrid", "GridContainer", true, false)
	assert(not grids.is_empty(), "Bottom controls must be arranged in a two-column touch-friendly grid")
	var controls := grids[0] as GridContainer
	assert(controls.columns == 2, "Phone controls must use two columns rather than narrow one-row buttons")
	var control_buttons := controls.find_children("*", "Button", true, false)
	assert(control_buttons.size() >= 5, "All game controls must remain available")
	for button in control_buttons:
		assert(button.custom_minimum_size.y >= 54.0, "Game controls need comfortable touch targets")

	# WOLF-DUSK-024 compact-phone HUD layout regression check.
	var polish_script = load("res://scripts/ui_polish.gd")
	var polish = polish_script.new()
	var layout_root := Control.new()
	var header := PanelContainer.new()
	var footer := PanelContainer.new()
	footer.anchor_top = 1.0
	layout_root.add_child(header)
	layout_root.add_child(footer)
	polish._apply_responsive_layout(layout_root, Vector2(360.0, 740.0), true)
	assert(is_equal_approx(header.anchor_bottom, 0.31), "Compact phone header must have sufficient height")
	assert(is_equal_approx(footer.anchor_top, 0.70), "Compact phone footer must have sufficient height")
	assert(footer.anchor_top - header.anchor_bottom >= 0.38, "Compact phone must retain a central playable area")
	polish.free()
	layout_root.free()

	# Startup regression: opening the app must not construct the 3D world or audio.
	assert(not meadow._world_ready, "3D world must be deferred until the user starts a match")
	assert(not meadow._world_loading, "3D world must not be loading during startup")
	assert(meadow.camera == null, "Camera must not be constructed during cold startup")
	assert(meadow.node_areas.is_empty(), "Board hit areas must not be constructed during cold startup")
	assert(meadow.move_audio == null and meadow.music_audio == null, "Audio players must not be constructed during cold startup")
	assert(is_instance_valid(meadow.setup_layer), "Usable setup menu must be available before world construction")

	# Verify the deferred match path still builds the full playable world.
	await meadow._ensure_game_world()
	assert(meadow._world_ready, "Match world must become ready when requested")
	assert(meadow.camera != null and meadow.camera.current, "Match camera must be initialized")
	assert(meadow.node_areas.size() == 25, "All 25 playable board touch areas must be initialized")

	# The exported app should open directly into the game, not display the Godot logo splash.
	var config := FileAccess.get_file_as_string("res://project.godot")
	assert(config.contains("boot_splash/show_image=false"), "Godot boot splash must be hidden for direct game launch")

	meadow.queue_free()
	print("WOLF-DUSK-044-CONT-003 checks passed: menu-first cold startup, deferred playable world, 25 board touch areas, readable setup controls and direct launch.")
	quit()
