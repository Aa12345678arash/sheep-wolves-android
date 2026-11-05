extends Node

const GOLD := Color(1.0, 0.78, 0.30)
const CREAM := Color(0.96, 0.95, 0.87)
const MINT := Color(0.56, 0.94, 0.72)
const SKY := Color(0.53, 0.84, 1.0)
const CORAL := Color(1.0, 0.62, 0.48)

func _ready() -> void:
	# Android is already immersive by default; explicitly request fullscreen on
	# desktop previews too so the same responsive layout is exercised.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	call_deferred("_polish_hud")

func _polish_hud() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	var hud_layer := _find_hud_layer(scene)
	if hud_layer == null or hud_layer.get_child_count() == 0:
		return
	var root := hud_layer.get_child(0) as Control
	if root == null:
		return
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport := get_viewport().get_visible_rect().size
	var compact := viewport.y < 900.0
	_apply_responsive_layout(root, viewport, compact)

func _apply_responsive_layout(root: Control, viewport: Vector2, compact: bool) -> void:
	# On short phones the original 21.5% / 79.5% anchors squeezed the board
	# between two HUD panels. Give Persian labels room while preserving a larger
	# unobstructed central play area.
	var header_bottom := 0.31 if compact else 0.215
	var footer_top := 0.70 if compact else 0.795
	for child in root.get_children():
		if child is PanelContainer:
			var panel := child as PanelContainer
			if panel.anchor_bottom == 0.0:
				panel.anchor_bottom = header_bottom
				panel.offset_left = 9.0
				panel.offset_right = -9.0
				panel.offset_top = 9.0
				panel.offset_bottom = 0.0
				_style_panel(panel, Color(0.035, 0.105, 0.13, 0.96), Color(0.22, 0.72, 0.67))
			else:
				panel.anchor_top = footer_top
				panel.offset_left = 9.0
				panel.offset_right = -9.0
				panel.offset_top = 0.0
				panel.offset_bottom = -9.0
				_style_panel(panel, Color(0.045, 0.085, 0.15, 0.97), Color(0.91, 0.66, 0.27))
			_style_descendants(panel, compact)

func _find_hud_layer(node: Node) -> CanvasLayer:
	for child in node.get_children():
		if child is CanvasLayer and child.layer == 10:
			return child as CanvasLayer
		var found := _find_hud_layer(child)
		if found != null:
			return found
	return null

func _style_panel(panel: PanelContainer, background: Color, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(19)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", box)

func _style_descendants(node: Node, compact: bool) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			var value := label.text
			label.add_theme_color_override("font_color", CREAM)
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if value.contains("نوبت") or value.contains("پایان بازی") or value.contains("چیدمان"):
				label.add_theme_color_override("font_color", GOLD)
				label.add_theme_font_size_override("font_size", 30 if not compact else 25)
			elif value.contains("گوسفندها:") or value.contains("گرگ‌ها:"):
				label.add_theme_color_override("font_color", SKY)
				label.add_theme_font_size_override("font_size", 19 if not compact else 16)
			elif value.contains("شکارشده") or value.contains("باقی‌مانده"):
				label.add_theme_color_override("font_color", CORAL)
				label.add_theme_font_size_override("font_size", 21 if not compact else 18)
			else:
				label.add_theme_font_size_override("font_size", 19 if not compact else 16)
		elif child is Button:
			_style_button(child as Button)
		_style_descendants(child, compact)

func _style_button(button: Button) -> void:
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 54.0)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.94))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.70))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.34, 0.37, 1.0)
	normal.border_color = Color(0.35, 0.78, 0.70, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(13)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.48, 0.48, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.25, 0.31, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
