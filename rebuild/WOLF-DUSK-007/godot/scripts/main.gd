extends Node3D

const BOARD_JSON := "res://data/canonical_board.json"
const CELL := 2.0
var board: Dictionary = {}
var edges: Dictionary = {}
var sheep_stacks: Dictionary = {}
var wolves: Array[String] = []
var selected := ""
var phase := "setup"
var turn := "sheep"
var sheep_count := 25
var status_label: Label
var node_meshes := {}
var piece_root: Node3D

func _ready() -> void:
	_setup_environment()
	_setup_ui()
	var f := FileAccess.open(BOARD_JSON, FileAccess.READ)
	if f:
		board = JSON.parse_string(f.get_as_text())
	if not BoardData.validate(board):
		status_label.text = "خطا در نقشهٔ اصلی صفحه"
		return
	edges = BoardData.edge_set(board)
	for stack in board.sheepStartingStacks:
		sheep_stacks[str(stack.node)] = int(stack.count)
	_build_board()
	_refresh_pieces()
	status_label.text = "سه جایگاه خالی برای گرگ‌ها انتخاب کنید"

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#b7d99a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff2d7")
	env.ambient_light_energy = 0.8
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.25
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 14, 10)
	camera.rotation_degrees = Vector3(-52, 0, 0)
	camera.current = true
	camera.fov = 42
	add_child(camera)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 14)
	panel.size = Vector2(520, 70)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.text = "گرگ و میش؛ راز دشت سبز"
	status_label.add_theme_font_size_override("font_size", 24)
	panel.add_child(status_label)
	var start := Button.new()
	start.text = "شروع بازی"
	start.position = Vector2(1050, 20)
	start.size = Vector2(190, 64)
	start.pressed.connect(_start_match)
	layer.add_child(start)

func _build_board() -> void:
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(11.5, 11.5)
	ground.mesh = ground_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#d8c58a")
	mat.roughness = 0.95
	ground.material_override = mat
	ground.position.y = -0.18
	add_child(ground)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(11.5, 0.25, 11.5)
	floor_shape.shape = box
	floor_body.position.y = -0.18
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	for node in board.nodes:
		var id := str(node.id)
		var pos := _world_pos(id)
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		dot.mesh = sphere
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color("#6c573b")
		dot.material_override = dm
		dot.position = pos + Vector3(0, 0.04, 0)
		add_child(dot)
		node_meshes[id] = dot
	for edge in board.edges:
		var a := _world_pos(str(edge.from))
		var b := _world_pos(str(edge.to))
		var line := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		var length := a.distance_to(b)
		cylinder.top_radius = 0.035
		cylinder.bottom_radius = 0.035
		cylinder.height = length
		line.mesh = cylinder
		var lm := StandardMaterial3D.new()
		match str(edge.type):
			"diagonal": lm.albedo_color = Color("#a65c36")
			"vertical": lm.albedo_color = Color("#526f91")
			_: lm.albedo_color = Color("#6e8050")
		line.material_override = lm
		line.position = (a + b) * 0.5
		line.look_at(b, Vector3.UP)
		line.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		add_child(line)
	piece_root = Node3D.new()
	add_child(piece_root)

func _world_pos(id: String) -> Vector3:
	var row := id.unicode_at(0) - 65
	var col := id.unicode_at(1) - 49
	return Vector3((col - 2) * CELL, 0, (row - 2) * CELL)

func _make_piece(pos: Vector3, color: Color, radius: float, height: float) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	piece.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	piece.material_override = material
	piece.position = pos
	return piece

func _refresh_pieces() -> void:
	if piece_root == null:
		return
	for child in piece_root.get_children():
		child.queue_free()
	for node_id in sheep_stacks:
		var count: int = sheep_stacks[node_id]
		var base := _world_pos(node_id)
		for i in range(count):
			var offset := Vector3((i % 3 - 1) * 0.19, 0.22 + float(i / 3) * 0.2, (i / 3 - 1) * 0.19)
			piece_root.add_child(_make_piece(base + offset, Color("#f7f1dc"), 0.15, 0.34))
	for wolf in wolves:
		piece_root.add_child(_make_piece(_world_pos(wolf) + Vector3(0, 0.32, 0), Color("#713d35"), 0.27, 0.65))

func _start_match() -> void:
	if phase == "setup":
		if wolves.size() != 3:
			status_label.text = "ابتدا سه گرگ را روی جایگاه‌های خالی قرار دهید"
			return
		phase = "play"
		turn = "sheep"
		selected = ""
		status_label.text = "نوبت گوسفندها"
		_refresh_pieces()

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	var screen_pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		screen_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		screen_pos = event.position
	if not pressed:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var point: Vector3 = hit.position
	var col := roundi(point.x / CELL) + 2
	var row := roundi(point.z / CELL) + 2
	if row < 0 or row > 4 or col < 0 or col > 4:
		return
	_on_node(char(65 + row) + str(col + 1))

func _on_node(id: String) -> void:
	if phase == "setup":
		if not sheep_stacks.has(id) and not wolves.has(id) and wolves.size() < 3:
			wolves.append(id)
			_refresh_pieces()
			status_label.text = "گرگ‌ها: %d از ۳؛ سپس شروع بازی" % wolves.size()
		return
	if phase != "play":
		return
	var occupied := _occupied()
	if turn == "sheep":
		if sheep_stacks.has(id):
			if not GameRules.legal_moves(id, occupied, edges).is_empty():
				selected = id
				status_label.text = "گوسفند %s انتخاب شد؛ مقصد را لمس کنید" % id
			else:
				status_label.text = "این گروه گوسفند حرکت ندارد؛ گروه دیگری را انتخاب کنید"
			return
		if selected != "" and GameRules.legal_moves(selected, occupied, edges).has(id):
			sheep_stacks[selected] -= 1
			if sheep_stacks[selected] <= 0:
				sheep_stacks.erase(selected)
			sheep_stacks[id] = int(sheep_stacks.get(id, 0)) + 1
			selected = ""
			turn = "wolves"
			_refresh_pieces()
			status_label.text = "نوبت گرگ‌ها"
	else:
		if wolves.has(id):
			selected = id
			status_label.text = "گرگ %s انتخاب شد؛ مقصد را لمس کنید" % id
			return
		if selected == "":
			return
		var capture_list := GameRules.legal_captures(selected, occupied, sheep_stacks, edges)
		for capture in capture_list:
			if str(capture.landing) == id:
				sheep_stacks.erase(str(capture.sheep))
				wolves.erase(selected)
				wolves.append(id)
				selected = id
				sheep_count -= 1
				_refresh_pieces()
				if GameRules.wolves_win(sheep_count):
					phase = "over"
					status_label.text = "گرگ‌ها پیروز شدند!"
				elif not GameRules.legal_captures(id, _occupied(), sheep_stacks, edges).is_empty():
					status_label.text = "شکار زنجیره‌ای؛ با همان گرگ ادامه دهید"
				else:
					selected = ""
					turn = "sheep"
					status_label.text = "نوبت گوسفندها"
				return
		if GameRules.legal_moves(selected, occupied, edges).has(id):
			wolves.erase(selected)
			wolves.append(id)
			selected = ""
			turn = "sheep"
			_refresh_pieces()
			status_label.text = "نوبت گوسفندها"
	if GameRules.sheep_win(wolves, _occupied(), sheep_stacks, edges):
		phase = "over"
		status_label.text = "گوسفندها پیروز شدند!"

func _occupied() -> Dictionary:
	var result := {}
	for id in sheep_stacks:
		result[id] = true
	for id in wolves:
		result[id] = true
	return result
