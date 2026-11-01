extends Node3D

const GRID_SIZE := 5
const SPACING := 2.2
const BoardGraph = preload("res://scripts/board_graph.gd")
const GameState = preload("res://scripts/game_state.gd")

var game = GameState.new()
var camera: Camera3D
var status_label: Label
var detail_label: Label
var message_label: Label
var pass_button: Button
var selected_node: int = -1
var chain_time_left: float = 0.0
var node_areas: Array[Area3D] = []
var node_visuals: Array[Node3D] = []
var feedback_message: String = "برای شروع، سه نقطهٔ خالی را برای گرگ‌ها انتخاب کنید."

func _ready() -> void:
	_build_environment()
	_build_board()
	_build_camera()
	_build_light()
	_build_hud()
	_refresh_board()
	_update_hud()

func _process(delta: float) -> void:
	if chain_time_left > 0.0:
		chain_time_left = maxf(0.0, chain_time_left - delta)
		if chain_time_left <= 0.0:
			game.finish_wolf_turn()
			pass_button.visible = false
			selected_node = -1
			feedback_message = "مهلت شکار دوم تمام شد؛ نوبت گوسفندهاست."
			_refresh_board()
			_update_hud()
		else:
			_update_chain_countdown()

func _build_environment() -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(18.0, 18.0)
	ground.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.38, 0.20)
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.12
	add_child(ground)

	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(11.0, 0.22, 11.0)
	board.mesh = board_mesh
	var board_material := StandardMaterial3D.new()
	board_material.albedo_color = Color(0.36, 0.25, 0.15)
	board_material.roughness = 0.9
	board.material_override = board_material
	add_child(board)

func _node_position(index: int) -> Vector3:
	var row: int = int(index / GRID_SIZE)
	var col: int = index % GRID_SIZE
	return Vector3((col - 2) * SPACING, 0.18, (row - 2) * SPACING)

func _build_board() -> void:
	# Two-layer path rails: a dark outline keeps every connection readable,
	# while the warm stone center remains visible against both board and ground.
	var rail_mesh := CylinderMesh.new()
	rail_mesh.top_radius = 0.115
	rail_mesh.bottom_radius = 0.115
	rail_mesh.height = 1.0
	rail_mesh.radial_segments = 12
	var rail_material := _material(Color(0.16, 0.19, 0.14))
	var path_mesh := CylinderMesh.new()
	path_mesh.top_radius = 0.068
	path_mesh.bottom_radius = 0.068
	path_mesh.height = 1.0
	path_mesh.radial_segments = 12
	var path_material := _material(Color(0.91, 0.78, 0.51))
	for edge in BoardGraph.EDGES:
		var start: Vector3 = _node_position(edge[0])
		var finish: Vector3 = _node_position(edge[1])
		var delta: Vector3 = finish - start
		var midpoint: Vector3 = (start + finish) * 0.5
		var direction: Vector3 = delta.normalized()
		var rail := MeshInstance3D.new()
		rail.mesh = rail_mesh
		rail.material_override = rail_material
		rail.position = midpoint + Vector3(0.0, -0.045, 0.0)
		rail.basis = Basis(Vector3.UP, direction)
		rail.scale = Vector3(1.0, delta.length(), 1.0)
		add_child(rail)
		var path := MeshInstance3D.new()
		path.mesh = path_mesh
		path.material_override = path_material
		path.position = midpoint + Vector3(0.0, 0.025, 0.0)
		path.basis = Basis(Vector3.UP, direction)
		path.scale = Vector3(1.0, delta.length(), 1.0)
		add_child(path)

	for index in range(BoardGraph.NODE_COUNT):
		var area := Area3D.new()
		area.position = _node_position(index)
		area.input_ray_pickable = true
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.62
		collision.shape = sphere
		area.add_child(collision)
		area.input_event.connect(_on_node_input_event.bind(index))
		add_child(area)
		node_areas.append(area)
		var visual := Node3D.new()
		area.add_child(visual)
		node_visuals.append(visual)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(10.5, 12.5, 15.5)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	add_child(camera)

func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(350, 170)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 21)
	column.add_child(status_label)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size = Vector2(330, 42)
	detail_label.add_theme_font_size_override("font_size", 15)
	column.add_child(detail_label)
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(330, 38)
	message_label.add_theme_font_size_override("font_size", 14)
	column.add_child(message_label)
	pass_button = Button.new()
	pass_button.text = "رد کردن شکار دوم و پایان نوبت گرگ"
	pass_button.visible = false
	pass_button.pressed.connect(_decline_chain_capture)
	column.add_child(pass_button)
	var reset_button := Button.new()
	reset_button.text = "شروع دوبارهٔ بازی"
	reset_button.pressed.connect(_reset_game)
	column.add_child(reset_button)
	var credit := Label.new()
	credit.text = "سازنده و معرفی‌کننده: آرش سلیمی"
	credit.position = Vector2(18, 205)
	layer.add_child(credit)

func _on_node_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, index: int) -> void:
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if pressed:
		_select_node(index)

func _select_node(index: int) -> void:
	if game.turn == GameState.Turn.FINISHED:
		feedback_message = "بازی تمام شده است؛ برای بازی تازه «شروع دوبارهٔ بازی» را بزنید."
		_update_hud()
		return

	if game.turn == GameState.Turn.PLACE_WOLVES:
		if game.place_wolf(index):
			selected_node = -1
			feedback_message = "گرگ %d از ۳ در جای خود قرار گرفت." % game.wolf_total()
		else:
			feedback_message = "این نقطه خالی نیست؛ برای گرگ یک نقطهٔ خالی انتخاب کنید."
		_refresh_board()
		_update_hud()
		return

	if selected_node == -1:
		if game.turn == GameState.Turn.SHEEP and game.sheep[index] > 0:
			selected_node = index
			feedback_message = "گوسفندها انتخاب شدند؛ اکنون یکی از مقصدهای سبز را بزنید."
		elif game.turn == GameState.Turn.WOLVES and game.wolves[index]:
			if game.chain_wolf == -1 or game.chain_wolf == index:
				selected_node = index
				feedback_message = "گرگ انتخاب شد؛ مقصد سبز را برای حرکت یا شکار بزنید."
			else:
				feedback_message = "در شکار زنجیره‌ای فقط همان گرگِ شکارکننده اجازهٔ حرکت دارد."
		else:
			feedback_message = "ابتدا یک مهرهٔ متعلق به بازیکنِ نوبت را انتخاب کنید."
		_refresh_board()
		_update_hud()
		return

	if index == selected_node:
		selected_node = -1
		feedback_message = "انتخاب لغو شد؛ مهرهٔ دیگری را انتخاب کنید."
		_refresh_board()
		_update_hud()
		return

	if game.turn == GameState.Turn.SHEEP:
		if game.move_sheep(selected_node, index):
			selected_node = -1
			feedback_message = "گوسفند جابه‌جا شد؛ اکنون نوبت گرگ‌هاست."
		else:
			feedback_message = "حرکت نامعتبر است؛ فقط به نقطهٔ خالیِ متصل حرکت کنید."
	else:
		var result: String = game.move_wolf(selected_node, index)
		if result == "captured_chain_available":
			selected_node = game.chain_wolf
			chain_time_left = 3.0
			pass_button.visible = true
			feedback_message = "شکار انجام شد؛ می‌توانید با همان گرگ شکار دوم کنید یا نوبت را پایان دهید."
		elif result in ["moved", "captured", "won"]:
			selected_node = -1
			chain_time_left = 0.0
			pass_button.visible = false
			if result == "won":
				feedback_message = "شرط پیروزی گرگ‌ها برقرار شد."
			elif result == "captured":
				feedback_message = "شکار انجام شد؛ نوبت گوسفندهاست."
			else:
				feedback_message = "گرگ حرکت کرد؛ نوبت گوسفندهاست."
		elif result == "chain_capture_required":
			feedback_message = "هنوز امکان شکار دوم وجود دارد؛ باید یکی از مقصدهای سبز را انتخاب کنید یا شکار دوم را رد کنید."
		elif result == "wrong_chain_wolf":
			feedback_message = "شکار دوم فقط با همان گرگ مجاز است."
		else:
			feedback_message = "حرکت نامعتبر است؛ فقط روی مقصد سبزِ مجاز بزنید. نوبت تغییر نکرد."
	_refresh_board()
	_update_hud()

func _reset_game() -> void:
	game.reset()
	selected_node = -1
	chain_time_left = 0.0
	pass_button.visible = false
	feedback_message = "بازی تازه آغاز شد؛ سه نقطهٔ خالی را برای گرگ‌ها انتخاب کنید."
	_refresh_board()
	_update_hud()

func _refresh_board() -> void:
	for index in range(BoardGraph.NODE_COUNT):
		var visual := node_visuals[index]
		for child in visual.get_children():
			child.queue_free()
		var marker := MeshInstance3D.new()
		var marker_mesh := SphereMesh.new()
		marker_mesh.radius = 0.19 if index == selected_node else 0.14
		marker_mesh.height = marker_mesh.radius * 2.0
		marker.mesh = marker_mesh
		var marker_material := StandardMaterial3D.new()
		if index == selected_node:
			marker_material.albedo_color = Color(1.0, 0.82, 0.22)
		elif index in _legal_targets():
			marker_material.albedo_color = Color(0.25, 0.92, 0.42)
		else:
			marker_material.albedo_color = Color(0.91, 0.78, 0.48)
		marker.material_override = marker_material
		marker.position.y = 0.03
		visual.add_child(marker)
		var node_name := Label3D.new()
		node_name.text = BoardGraph.node_label(index)
		node_name.font_size = 22
		node_name.outline_size = 5
		node_name.modulate = Color(0.12, 0.10, 0.07)
		node_name.position = Vector3(0.0, -0.08, 0.48)
		visual.add_child(node_name)
		if game.sheep[index] > 0:
			_add_sheep_piece(visual, game.sheep[index])
		if game.wolves[index]:
			_add_wolf_piece(visual)

func _add_sheep_piece(parent: Node3D, count: int) -> void:
	var wool := _material(Color(0.96, 0.94, 0.86))
	var face := _material(Color(0.32, 0.27, 0.23))
	var hoof := _material(Color(0.19, 0.17, 0.15))
	for i in range(min(count, 5)):
		var offset := Vector3((i % 3 - 1) * 0.15, 0.29 + float(i / 3) * 0.12, (i / 3) * 0.12)
		var body := MeshInstance3D.new()
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.205
		body_mesh.height = 0.36
		body.mesh = body_mesh
		body.material_override = wool
		body.position = offset
		parent.add_child(body)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.11
		head_mesh.height = 0.20
		head.mesh = head_mesh
		head.material_override = face
		head.position = offset + Vector3(0.17, 0.025, -0.035)
		parent.add_child(head)
		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var eye_mesh := SphereMesh.new()
			eye_mesh.radius = 0.022
			eye_mesh.height = 0.044
			eye.mesh = eye_mesh
			eye.material_override = hoof
			eye.position = offset + Vector3(0.245, 0.07, side * 0.065)
			parent.add_child(eye)
		for leg_index in range(4):
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.025
			leg_mesh.bottom_radius = 0.032
			leg_mesh.height = 0.18
			leg.mesh = leg_mesh
			leg.material_override = hoof
			leg.position = offset + Vector3(-0.08 if leg_index < 2 else 0.08, -0.16, -0.075 if leg_index % 2 == 0 else 0.075)
			parent.add_child(leg)
	var count_label := Label3D.new()
	count_label.text = str(count)
	count_label.font_size = 28
	count_label.outline_size = 5
	count_label.position = Vector3(0, 0.94, 0)
	parent.add_child(count_label)

func _add_wolf_piece(parent: Node3D) -> void:
	var fur := _material(Color(0.19, 0.23, 0.29))
	var muzzle := _material(Color(0.57, 0.57, 0.52))
	var dark := _material(Color(0.075, 0.08, 0.09))
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.29
	body_mesh.height = 0.49
	body.mesh = body_mesh
	body.material_override = fur
	body.position = Vector3(-0.025, 0.43, 0.0)
	parent.add_child(body)
	var chest := MeshInstance3D.new()
	var chest_mesh := SphereMesh.new()
	chest_mesh.radius = 0.19
	chest_mesh.height = 0.36
	chest.mesh = chest_mesh
	chest.material_override = muzzle
	chest.position = Vector3(0.13, 0.43, -0.015)
	parent.add_child(chest)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.material_override = fur
	head.position = Vector3(0.22, 0.59, -0.02)
	parent.add_child(head)
	var snout := MeshInstance3D.new()
	var snout_mesh := SphereMesh.new()
	snout_mesh.radius = 0.105
	snout_mesh.height = 0.15
	snout.mesh = snout_mesh
	snout.material_override = muzzle
	snout.position = Vector3(0.39, 0.53, -0.02)
	parent.add_child(snout)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := ConeMesh.new()
		ear_mesh.radius = 0.075
		ear_mesh.height = 0.23
		ear.mesh = ear_mesh
		ear.material_override = fur
		ear.position = Vector3(0.15, 0.80, side * 0.13)
		parent.add_child(ear)
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.027
		eye_mesh.height = 0.054
		eye.mesh = eye_mesh
		eye.material_override = dark
		eye.position = Vector3(0.34, 0.63, side * 0.135)
		parent.add_child(eye)
	for leg_index in range(4):
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.045
		leg_mesh.bottom_radius = 0.055
		leg_mesh.height = 0.24
		leg.mesh = leg_mesh
		leg.material_override = fur
		leg.position = Vector3(-0.12 if leg_index < 2 else 0.13, 0.20, -0.15 if leg_index % 2 == 0 else 0.15)
		parent.add_child(leg)
	var tail := MeshInstance3D.new()
	var tail_mesh := CapsuleMesh.new()
	tail_mesh.radius = 0.07
	tail_mesh.height = 0.25
	tail.mesh = tail_mesh
	tail.material_override = fur
	tail.position = Vector3(-0.31, 0.47, 0.0)
	tail.rotation_degrees.z = 55.0
	parent.add_child(tail)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result

func _update_chain_countdown() -> void:
	detail_label.text = "شکار دوم با همان گرگ اختیاری است؛ زمان باقی‌مانده: %.1f ثانیه" % chain_time_left

func _update_hud() -> void:
	if game.turn == GameState.Turn.PLACE_WOLVES:
		status_label.text = "گرگ و میش | چیدمان گرگ‌ها"
		detail_label.text = "گرگ‌ها: %d از ۳ | سه نقطهٔ خالی را انتخاب کنید." % game.wolf_total()
	elif game.turn == GameState.Turn.SHEEP:
		status_label.text = "نوبت گوسفندها"
		detail_label.text = "گوسفندان باقی‌مانده: %d | یک گوسفند را انتخاب کنید، سپس مقصد سبز را بزنید." % game.sheep_total()
	elif game.turn == GameState.Turn.WOLVES:
		status_label.text = "نوبت گرگ‌ها"
		detail_label.text = "گرگ را انتخاب کنید؛ مقصد سبز حرکت یا شکار قانونی را نشان می‌دهد."
	elif game.winner == "wolves":
		status_label.text = "پایان بازی | پیروزی گرگ‌ها"
		detail_label.text = "تعداد گوسفندان به ۸ یا کمتر رسیده است."
	elif game.winner == "sheep":
		status_label.text = "پایان بازی | پیروزی گوسفندها"
		detail_label.text = "هر سه گرگ بدون حرکت قانونی مانده‌اند."
	message_label.text = feedback_message
	if chain_time_left > 0.0:
		_update_chain_countdown()

func _legal_targets() -> Array[int]:
	var targets: Array[int] = []
	if selected_node < 0:
		return targets
	if game.turn == GameState.Turn.SHEEP:
		return game.sheep_moves(selected_node)
	if game.turn == GameState.Turn.WOLVES:
		if game.chain_wolf != -1:
			for capture in game.capture_options(selected_node):
				targets.append(capture["to"])
		else:
			for destination in game.wolf_moves(selected_node):
				targets.append(destination)
			for capture in game.capture_options(selected_node):
				if capture["to"] not in targets:
					targets.append(capture["to"])
	return targets

func _decline_chain_capture() -> void:
	if game.chain_wolf != -1 and chain_time_left > 0.0:
		game.finish_wolf_turn()
		feedback_message = "شکار دوم رد شد؛ نوبت گوسفندهاست."
	chain_time_left = 0.0
	selected_node = -1
	pass_button.visible = false
	_refresh_board()
	_update_hud()
