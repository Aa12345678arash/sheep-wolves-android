extends Node3D

const GRID_SIZE := 5
const SPACING := 2.2
const BoardGraph = preload("res://scripts/board_graph.gd")

func _ready() -> void:
	_build_environment()
	_build_board_markers()
	_build_camera()
	_build_light()

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

func _build_board_markers() -> void:
	# Render the recovered 0.5.1 graph; never infer or approximate connections.
	var path_mesh := CylinderMesh.new()
	path_mesh.top_radius = 0.055
	path_mesh.bottom_radius = 0.055
	path_mesh.height = 1.0
	path_mesh.radial_segments = 8
	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color(0.78, 0.66, 0.43)
	path_material.roughness = 0.95

	for edge in BoardGraph.EDGES:
		var start: Vector3 = _node_position(edge[0])
		var finish: Vector3 = _node_position(edge[1])
		var delta: Vector3 = finish - start
		var path := MeshInstance3D.new()
		path.mesh = path_mesh
		path.material_override = path_material
		path.position = (start + finish) * 0.5
		path.basis = Basis(Vector3.UP, delta.normalized())
		path.scale = Vector3(1.0, delta.length(), 1.0)
		add_child(path)

	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.16
	marker_mesh.height = 0.32
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.91, 0.78, 0.48)
	for index in range(BoardGraph.NODE_COUNT):
		var marker := MeshInstance3D.new()
		marker.mesh = marker_mesh
		marker.material_override = marker_material
		marker.position = _node_position(index)
		add_child(marker)

func _build_camera() -> void:
	var camera := Camera3D.new()
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
