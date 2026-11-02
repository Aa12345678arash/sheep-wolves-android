extends Node3D

const GRID_SIZE := 5
const SPACING := 2.2
const BoardGraph = preload("res://scripts/board_graph.gd")
const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

var game = GameState.new()
var camera: Camera3D
var camera_target_position: Vector3 = Vector3(0.0, 20.0, 22.0)
var camera_view_turn: int = -1
var status_label: Label
var capture_count_label: Label
var detail_label: Label
var message_label: Label
var pass_button: Button
var selected_node: int = -1
var chain_time_left: float = 0.0
var node_areas: Array[Area3D] = []
var node_visuals: Array[Node3D] = []
var feedback_message: String = "سه نقطهٔ خالی را برای قرار دادن سه گرگ انتخاب کنید؛ سپس نوبت گوسفندهاست."
var setup_layer: CanvasLayer
var player_one_name: String = "بازیکن گوسفندها"
var player_two_name: String = "بازیکن گرگ‌ها"
var player_names_label: Label
var sheep_idle_pivots: Array[Node3D] = []
var wolf_idle_pivots: Array[Node3D] = []
var wolf_tail_pivots: Array[Node3D] = []
var sheep_anim_clock: float = 0.0
var camera_shake_time: float = 0.0
var camera_shake_strength: float = 0.0
var match_mode: String = "local"
var human_side: String = "sheep"
var ai_difficulty: int = 1
var ai_busy: bool = false
var ai_turn_generation: int = 0
var move_audio: AudioStreamPlayer
var capture_audio: AudioStreamPlayer
var victory_audio: AudioStreamPlayer
var music_audio: AudioStreamPlayer
var music_button: Button
var setup_music_button: Button
var announced_winner: String = ""

func _ready() -> void:
	_build_audio()
	_build_environment()
	_build_board()
	_build_camera()
	_build_light()
	_build_hud()
	# Start directly in the playable match; no blocking setup overlay.
	_refresh_board()
	_update_hud()

func _process(delta: float) -> void:
	sheep_anim_clock += delta
	# Sheep use static low-poly poses on mobile; avoid per-frame work for 25 individual pieces.
	for i in range(wolf_idle_pivots.size()):
		var wolf_pivot := wolf_idle_pivots[i]
		if is_instance_valid(wolf_pivot):
			var wolf_phase := sheep_anim_clock * 1.45 + float(i) * 1.7
			wolf_pivot.position.y = sin(wolf_phase) * 0.018
			wolf_pivot.rotation.y = sin(wolf_phase * 0.42) * 0.025
	for i in range(wolf_tail_pivots.size()):
		var tail_pivot := wolf_tail_pivots[i]
		if is_instance_valid(tail_pivot):
			tail_pivot.rotation.z = 0.96 + sin(sheep_anim_clock * 2.3 + float(i)) * 0.12
	if camera != null and camera.is_inside_tree():
		camera.position = camera.position.lerp(camera_target_position, minf(delta * 10.0, 1.0))
		if camera_shake_time > 0.0:
			camera_shake_time = maxf(0.0, camera_shake_time - delta)
			var shake_phase := sheep_anim_clock * 58.0
			var shake_fade := camera_shake_time / 0.24
			camera.position += Vector3(sin(shake_phase) * camera_shake_strength, cos(shake_phase * 1.31) * camera_shake_strength * 0.45, sin(shake_phase * 0.77) * camera_shake_strength * 0.55) * shake_fade
		else:
			camera_shake_strength = 0.0
		camera.look_at(Vector3.ZERO, Vector3.UP)
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

func _build_audio() -> void:
	# Original procedural sound effects: no external recordings or third-party music assets.
	move_audio = AudioStreamPlayer.new()
	move_audio.name = "MoveSound"
	move_audio.stream = _make_sfx([660.0, 990.0], 0.14, 0.18, 5.5)
	add_child(move_audio)
	capture_audio = AudioStreamPlayer.new()
	capture_audio.name = "CaptureSound"
	capture_audio.stream = _make_sfx([145.0, 92.0, 310.0], 0.38, 0.34, 7.0)
	add_child(capture_audio)
	victory_audio = AudioStreamPlayer.new()
	victory_audio.name = "VictorySound"
	victory_audio.stream = _make_sfx([523.25, 659.25, 783.99], 0.82, 0.22, 1.8)
	add_child(victory_audio)

	# Original synthesized meadow theme; no third-party recording or license dependency.
	music_audio = AudioStreamPlayer.new()
	music_audio.name = "OriginalMeadowTheme"
	music_audio.volume_db = -12.0
	music_audio.bus = "Master"
	music_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	music_audio.stream = _make_meadow_music()
	add_child(music_audio)
	music_audio.play()

func _make_meadow_music() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := sample_rate * 16
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var chords := [
		[130.81, 164.81, 196.00], [110.00, 130.81, 164.81],
		[87.31, 110.00, 130.81], [98.00, 123.47, 146.83],
		[130.81, 164.81, 196.00], [110.00, 130.81, 164.81],
		[87.31, 110.00, 130.81], [98.00, 123.47, 146.83]
	]
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(sample_rate)
		var beat_time := fmod(time, 2.0)
		var chord_index := mini(int(time / 2.0), chords.size() - 1)
		var envelope := minf(1.0, beat_time / 0.22) * minf(1.0, (2.0 - beat_time) / 0.30)
		var sample := 0.0
		for frequency in chords[chord_index]:
			var hz := float(frequency)
			sample += sin(TAU * hz * time) * 0.62
			sample += sin(TAU * hz * 2.0 * time) * 0.10
		sample = sample / 3.0 * envelope * 0.13
		pcm.encode_s16(sample_index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func _make_sfx(frequencies: Array, duration: float, amplitude: float, decay: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(sample_rate)
		var envelope := minf(1.0, time / 0.008) * exp(-time * decay)
		var sample := 0.0
		for frequency in frequencies:
			sample += sin(TAU * float(frequency) * time) / float(frequencies.size())
		sample *= envelope * amplitude
		pcm.encode_s16(sample_index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm
	return stream

func _toggle_meadow_music(enabled: bool) -> void:
	if music_audio == null:
		return
	if enabled:
		_ensure_music_playing()
		if is_instance_valid(music_button):
			music_button.button_pressed = true
			music_button.text = "موسیقی دشت: روشن"
		if is_instance_valid(setup_music_button):
			setup_music_button.button_pressed = true
			setup_music_button.text = "موسیقی دشت: روشن"
	else:
		music_audio.stop()
		if is_instance_valid(music_button):
			music_button.button_pressed = false
			music_button.text = "موسیقی دشت: خاموش"
		if is_instance_valid(setup_music_button):
			setup_music_button.button_pressed = false
			setup_music_button.text = "موسیقی دشت: خاموش"

func _play_move_sound() -> void:
	if move_audio != null:
		move_audio.play()

func _ensure_music_playing() -> void:
	if music_audio != null and not music_audio.playing:
		music_audio.play()

func _play_capture_sound() -> void:
	if capture_audio != null:
		capture_audio.play()

func _build_environment() -> void:
	# Soft stylized sky and ambient light make the meadow read as an outdoor scene.
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.20, 0.43, 0.68)
	sky_material.sky_horizon_color = Color(0.78, 0.84, 0.79)
	sky_material.ground_bottom_color = Color(0.16, 0.25, 0.16)
	sky_material.ground_horizon_color = Color(0.45, 0.53, 0.39)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.79, 0.72)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

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
	_build_board_frame()

	# Decorative low-poly trees and stones stay outside the playable 5x5 board.
	var tree_spots := [
		Vector2(-7.0, -6.8), Vector2(-5.6, 7.0), Vector2(7.1, -6.4),
		Vector2(7.0, 6.8), Vector2(-7.4, 1.0), Vector2(7.5, -1.2)
	]
	for spot in tree_spots:
		_add_meadow_tree(Vector3(spot.x, 0.0, spot.y))
	var rock_spots := [
		Vector3(-6.5, 0.0, -3.8), Vector3(6.7, 0.0, 3.9),
		Vector3(-4.8, 0.0, 6.7), Vector3(5.0, 0.0, -6.8)
	]
	for spot in rock_spots:
		_add_meadow_rock(spot)
	_build_meadow_details()

func _build_board_frame() -> void:
	# A low timber frame gives the playable field a clear, tactile boundary.
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(11.4, 0.16, 0.20)
	var beam_material := _material(Color(0.25, 0.15, 0.085))
	for side in [-1.0, 1.0]:
		var near_beam := MeshInstance3D.new()
		near_beam.mesh = beam_mesh
		near_beam.material_override = beam_material
		near_beam.position = Vector3(0.0, 0.24, side * 5.42)
		add_child(near_beam)
		var side_beam := MeshInstance3D.new()
		side_beam.mesh = beam_mesh
		side_beam.material_override = beam_material
		side_beam.position = Vector3(side * 5.42, 0.24, 0.0)
		side_beam.rotation.y = PI * 0.5
		add_child(side_beam)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.16
	post_mesh.bottom_radius = 0.19
	post_mesh.height = 0.42
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.material_override = _material(Color(0.42, 0.27, 0.13))
			post.position = Vector3(x_side * 5.42, 0.28, z_side * 5.42)
			add_child(post)

func _build_meadow_details() -> void:
	# Instanced grass and tiny flowers add life without creating hundreds of nodes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5021405
	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(0.045, 0.34, 0.035)
	var grass_material := StandardMaterial3D.new()
	grass_material.vertex_color_use_as_albedo = true
	grass_material.roughness = 1.0
	var grass_batch := MultiMesh.new()
	grass_batch.transform_format = MultiMesh.TRANSFORM_3D
	grass_batch.use_colors = true
	grass_batch.mesh = grass_mesh
	grass_batch.instance_count = 240
	for i in range(grass_batch.instance_count):
		var x := rng.randf_range(-8.7, 8.7)
		var z := rng.randf_range(-8.7, 8.7)
		var attempts := 0
		while absf(x) < 5.85 and absf(z) < 5.85 and attempts < 12:
			x = rng.randf_range(-8.7, 8.7)
			z = rng.randf_range(-8.7, 8.7)
			attempts += 1
		var yaw := rng.randf_range(0.0, TAU)
		var lean := rng.randf_range(-0.20, 0.20)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, lean)
		basis = basis.scaled(Vector3(rng.randf_range(0.75, 1.35), rng.randf_range(0.65, 1.25), 1.0))
		grass_batch.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.06, z)))
		var green := rng.randf_range(0.78, 1.12)
		grass_batch.set_instance_color(i, Color(0.19 * green, 0.43 * green, 0.16 * green, 1.0))
	var grass_instance := MultiMeshInstance3D.new()
	grass_instance.multimesh = grass_batch
	grass_instance.material_override = grass_material
	add_child(grass_instance)

	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.055
	flower_mesh.height = 0.07
	var flower_material := StandardMaterial3D.new()
	flower_material.vertex_color_use_as_albedo = true
	flower_material.roughness = 0.75
	var flower_batch := MultiMesh.new()
	flower_batch.transform_format = MultiMesh.TRANSFORM_3D
	flower_batch.use_colors = true
	flower_batch.mesh = flower_mesh
	flower_batch.instance_count = 42
	var flower_colors := [
		Color(0.96, 0.83, 0.45), Color(0.91, 0.91, 0.82),
		Color(0.78, 0.55, 0.67), Color(0.91, 0.68, 0.39)
	]
	for i in range(flower_batch.instance_count):
		var x := rng.randf_range(-8.4, 8.4)
		var z := rng.randf_range(-8.4, 8.4)
		var attempts := 0
		while absf(x) < 5.95 and absf(z) < 5.95 and attempts < 12:
			x = rng.randf_range(-8.4, 8.4)
			z = rng.randf_range(-8.4, 8.4)
			attempts += 1
		var size := rng.randf_range(0.75, 1.35)
		flower_batch.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), Vector3(x, 0.075, z)))
		flower_batch.set_instance_color(i, flower_colors[rng.randi_range(0, flower_colors.size() - 1)])
	var flower_instance := MultiMeshInstance3D.new()
	flower_instance.multimesh = flower_batch
	flower_instance.material_override = flower_material
	add_child(flower_instance)

func _add_meadow_tree(at: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.23
	trunk_mesh.height = 1.45
	trunk.mesh = trunk_mesh
	trunk.material_override = _material(Color(0.31, 0.19, 0.11))
	trunk.position = at + Vector3(0.0, 0.72, 0.0)
	add_child(trunk)
	for layer in range(3):
		var crown := MeshInstance3D.new()
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.0
		crown_mesh.bottom_radius = 1.0 - float(layer) * 0.16
		crown_mesh.height = 1.55
		crown.mesh = crown_mesh
		crown.material_override = _material([Color(0.13, 0.34, 0.17), Color(0.18, 0.42, 0.20), Color(0.24, 0.49, 0.23)][layer])
		crown.position = at + Vector3(0.0, 1.55 + float(layer) * 0.62, 0.0)
		add_child(crown)

func _add_meadow_rock(at: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.48
	rock_mesh.height = 0.62
	rock.mesh = rock_mesh
	rock.material_override = _material(Color(0.43, 0.45, 0.39))
	rock.position = at + Vector3(0.0, 0.20, 0.0)
	rock.scale = Vector3(1.3, 0.75, 0.9)
	add_child(rock)

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
		var rail_x := direction.cross(Vector3.FORWARD).normalized()
		if rail_x.length_squared() < 0.001:
			rail_x = Vector3.RIGHT
		var rail_z := rail_x.cross(direction).normalized()
		rail.basis = Basis(rail_x, direction, rail_z)
		rail.scale = Vector3(1.0, delta.length(), 1.0)
		add_child(rail)
		var path := MeshInstance3D.new()
		path.mesh = path_mesh
		path.material_override = path_material
		path.position = midpoint + Vector3(0.0, 0.025, 0.0)
		path.basis = Basis(rail_x, direction, rail_z)
		path.scale = Vector3(1.0, delta.length(), 1.0)
		add_child(path)

	for index in range(BoardGraph.NODE_COUNT):
		var area := Area3D.new()
		area.position = _node_position(index)
		area.input_ray_pickable = true
		area.set_meta("board_node_index", index)
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.92
		collision.shape = sphere
		area.add_child(collision)
		add_child(area)
		node_areas.append(area)
		var visual := Node3D.new()
		area.add_child(visual)
		node_visuals.append(visual)

func _build_camera() -> void:
	camera = Camera3D.new()
	# Portrait framing: a slightly elevated, centered view keeps the full 5x5 board visible.
	camera.position = Vector3(0.0, 20.0, 22.0)
	camera.current = true
	camera.fov = 48.0
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	light.light_energy = 1.0
	# Mobile performance: avoid expensive real-time shadow maps.
	light.shadow_enabled = false
	add_child(light)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	# Compact header occupies its own safe area and never covers the board center.
	var header := PanelContainer.new()
	header.anchor_left = 0.0
	header.anchor_top = 0.0
	header.anchor_right = 1.0
	header.anchor_bottom = 0.0
	header.offset_left = 12.0
	header.offset_top = 12.0
	header.offset_right = -12.0
	header.offset_bottom = 166.0
	root.add_child(header)
	var header_column := VBoxContainer.new()
	header_column.add_theme_constant_override("separation", 3)
	header.add_child(header_column)

	player_names_label = Label.new()
	player_names_label.text = "گوسفندها: %s  |  گرگ‌ها: %s" % [player_one_name, player_two_name]
	player_names_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_names_label.add_theme_font_size_override("font_size", 19)
	header_column.add_child(player_names_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	header_column.add_child(status_label)

	capture_count_label = Label.new()
	capture_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_count_label.add_theme_font_size_override("font_size", 20)
	capture_count_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.36))
	header_column.add_child(capture_count_label)

	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 18)
	header_column.add_child(detail_label)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 18)
	header_column.add_child(message_label)

	# Bottom controls remain outside the board's central play area.
	var footer := PanelContainer.new()
	footer.anchor_left = 0.0
	footer.anchor_top = 1.0
	footer.anchor_right = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 12.0
	footer.offset_top = -116.0
	footer.offset_right = -12.0
	footer.offset_bottom = -12.0
	root.add_child(footer)
	var footer_column := VBoxContainer.new()
	footer_column.add_theme_constant_override("separation", 5)
	footer.add_child(footer_column)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	footer_column.add_child(controls)

	pass_button = Button.new()
	pass_button.text = "پایان شکار دوم"
	pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_button.custom_minimum_size = Vector2(0, 44)
	pass_button.add_theme_font_size_override("font_size", 15)
	pass_button.visible = false
	pass_button.pressed.connect(_decline_chain_capture)
	controls.add_child(pass_button)

	var reset_button := Button.new()
	reset_button.text = "بازی تازه"
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.custom_minimum_size = Vector2(0, 44)
	reset_button.add_theme_font_size_override("font_size", 15)
	reset_button.pressed.connect(_reset_game)
	controls.add_child(reset_button)

	music_button = Button.new()
	music_button.text = "موسیقی: روشن"
	music_button.toggle_mode = true
	music_button.button_pressed = true
	music_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_button.custom_minimum_size = Vector2(0, 44)
	music_button.add_theme_font_size_override("font_size", 14)
	music_button.toggled.connect(_toggle_meadow_music)
	controls.add_child(music_button)

	var credit := Label.new()
	credit.text = "سازنده و معرفی‌کننده: آرش سلیمی"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 14)
	footer_column.add_child(credit)

func _show_setup_menu() -> void:
	setup_layer = CanvasLayer.new()
	setup_layer.layer = 5
	add_child(setup_layer)
	var shade := ColorRect.new()
	# Keep the meadow visible but prevent the HUD behind the setup screen from competing.
	shade.color = Color(0.015, 0.035, 0.025, 0.90)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 620)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -310)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.075, 0.12, 0.095, 0.98)
	panel_style.border_color = Color(0.72, 0.61, 0.38, 0.95)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(22)
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", panel_style)
	setup_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	column.add_theme_font_size_override("font_size", 24)
	column.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	panel.add_child(column)
	var emblem := TextureRect.new()
	emblem.texture = load("res://assets/title_emblem.svg")
	emblem.custom_minimum_size = Vector2(0, 112)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(emblem)
	var heading := Label.new()
	heading.text = "گرگ و میش | راز دشت سبز"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "نوع مسابقه و نام بازیکن را انتخاب کنید"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	column.add_child(subtitle)
	var sheep_name := LineEdit.new()
	sheep_name.placeholder_text = "نام بازیکن گوسفندها"
	sheep_name.text = player_one_name
	sheep_name.custom_minimum_size = Vector2(0, 48)
	sheep_name.add_theme_font_size_override("font_size", 20)
	column.add_child(sheep_name)
	var wolf_name := LineEdit.new()
	wolf_name.placeholder_text = "نام بازیکن گرگ‌ها"
	wolf_name.text = player_two_name
	wolf_name.custom_minimum_size = Vector2(0, 48)
	wolf_name.add_theme_font_size_override("font_size", 20)
	column.add_child(wolf_name)
	var mode_picker := OptionButton.new()
	mode_picker.add_item("دو نفرهٔ حضوری روی یک دستگاه", 0)
	mode_picker.add_item("بازی با رایانه (هوش مصنوعی)", 1)
	column.add_child(mode_picker)
	var side_picker := OptionButton.new()
	side_picker.add_item("من گوسفندها باشم", 0)
	side_picker.add_item("من گرگ‌ها باشم", 1)
	column.add_child(side_picker)
	var difficulty_picker := OptionButton.new()
	difficulty_picker.add_item("هوش مصنوعی: آسان", 0)
	difficulty_picker.add_item("هوش مصنوعی: متوسط", 1)
	difficulty_picker.add_item("هوش مصنوعی: سخت", 2)
	mode_picker.custom_minimum_size = Vector2(0, 48)
	side_picker.custom_minimum_size = Vector2(0, 48)
	difficulty_picker.custom_minimum_size = Vector2(0, 48)
	column.add_child(difficulty_picker)
	setup_music_button = Button.new()
	setup_music_button.text = "موسیقی دشت: روشن"
	setup_music_button.toggle_mode = true
	setup_music_button.button_pressed = true
	setup_music_button.custom_minimum_size = Vector2(0, 46)
	setup_music_button.add_theme_font_size_override("font_size", 20)
	setup_music_button.toggled.connect(_toggle_meadow_music)
	column.add_child(setup_music_button)
	var start_button := Button.new()
	start_button.text = "شروع مسابقه"
	start_button.custom_minimum_size = Vector2(0, 56)
	start_button.add_theme_font_size_override("font_size", 24)
	start_button.pressed.connect(func():
		player_one_name = sheep_name.text.strip_edges()
		player_two_name = wolf_name.text.strip_edges()
		if player_one_name.is_empty():
			player_one_name = "بازیکن گوسفندها"
		if player_two_name.is_empty():
			player_two_name = "بازیکن گرگ‌ها"
		match_mode = "ai" if mode_picker.get_selected_id() == 1 else "local"
		human_side = "wolves" if side_picker.get_selected_id() == 1 else "sheep"
		ai_difficulty = difficulty_picker.get_selected_id()
		if match_mode == "ai":
			if human_side == "sheep":
				player_two_name = "رایانه (گرگ‌ها)"
			else:
				player_one_name = "رایانه (گوسفندها)"
		player_names_label.text = "گوسفندها: %s  |  گرگ‌ها: %s" % [player_one_name, player_two_name]
		setup_layer.queue_free()
		feedback_message = "مسابقه آغاز شد؛ گوسفندها شروع می‌کنند."
		_update_hud()
		_schedule_ai_turn()
	)
	column.add_child(start_button)
	var private_online := Button.new()
	private_online.text = "بازی آنلاین با کد اتاق — در دست توسعه"
	private_online.disabled = true
	private_online.visible = false
	column.add_child(private_online)
	var random_online := Button.new()
	random_online.text = "حریف تصادفی آنلاین — در دست توسعه"
	random_online.disabled = true
	random_online.visible = false
	column.add_child(random_online)
	var note := Label.new()
	note.text = "سازنده و معرفی‌کننده: آرش سلیمی"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 18)
	column.add_child(note)

func _is_ai_turn() -> bool:
	if match_mode != "ai" or game.turn == GameState.Turn.FINISHED:
		return false
	if game.turn == GameState.Turn.PLACE_WOLVES or game.turn == GameState.Turn.WOLVES:
		return human_side == "sheep"
	if game.turn == GameState.Turn.SHEEP:
		return human_side == "wolves"
	return false

func _schedule_ai_turn() -> void:
	if _is_ai_turn() and not ai_busy:
		ai_busy = true
		ai_turn_generation += 1
		call_deferred("_run_ai_turn", ai_turn_generation)

func _run_ai_turn(generation: int) -> void:
	await get_tree().create_timer(0.65).timeout
	var ai_anim_from := -1
	var ai_anim_to := -1
	var ai_anim_kind := ""
	# A reset can happen while the AI delay is running. Ignore stale callbacks
	# so an old turn cannot make an extra move in the newly reset match.
	if generation != ai_turn_generation:
		return
	if not is_inside_tree() or not _is_ai_turn():
		ai_busy = false
		return
	if game.turn == GameState.Turn.PLACE_WOLVES:
		var placement: int = AI.choose_wolf_placement(game, ai_difficulty)
		if placement >= 0:
			game.place_wolf(placement)
			feedback_message = "رایانه گرگ شمارهٔ %d را در جای خود قرار داد." % game.wolf_total()
	elif game.turn == GameState.Turn.SHEEP:
		var sheep_move: Dictionary = AI.choose_sheep_move(game, ai_difficulty)
		if not sheep_move.is_empty():
			ai_anim_from = int(sheep_move.from)
			ai_anim_to = int(sheep_move.to)
			ai_anim_kind = "sheep"
			if game.move_sheep(ai_anim_from, ai_anim_to):
				_play_move_sound()
			feedback_message = "رایانه یکی از گوسفندها را جابه‌جا کرد."
	elif game.turn == GameState.Turn.WOLVES:
		var wolf_move: Dictionary = AI.choose_wolf_move(game, ai_difficulty)
		if not wolf_move.is_empty():
			var wolf_from := int(wolf_move.from)
			var wolf_to := int(wolf_move.to)
			var ai_capture_node := -1
			for capture_option in game.capture_options(wolf_from):
				if int(capture_option["to"]) == wolf_to:
					ai_capture_node = int(capture_option["middle"])
					break
			var result: String = game.move_wolf(wolf_from, wolf_to)
			if result in ["moved", "captured", "captured_chain_available", "won"]:
				ai_anim_from = wolf_from
				ai_anim_to = wolf_to
				ai_anim_kind = "wolf"
			if result in ["captured", "captured_chain_available", "won"] and ai_capture_node >= 0:
				_play_capture_effect(ai_capture_node)
			elif result == "moved":
				_play_move_sound()
			if result == "captured_chain_available":
				var followups := game.capture_options(game.chain_wolf)
				if not followups.is_empty():
					var chain_from: int = game.chain_wolf
					var chain_to := int(followups[0].to)
					var chain_capture_node := int(followups[0].middle)
					game.move_wolf(chain_from, chain_to)
					ai_anim_from = chain_from
					ai_anim_to = chain_to
					ai_anim_kind = "wolf"
					_play_capture_effect(chain_capture_node)
				else:
					game.finish_wolf_turn()
				feedback_message = "رایانه حرکت شکار را انجام داد."
			else:
				feedback_message = "رایانه گرگ‌ها را حرکت داد."
		else:
			feedback_message = "رایانه حرکت قانونی دیگری ندارد."
	ai_busy = false
	selected_node = -1
	chain_time_left = 0.0
	pass_button.visible = false
	_refresh_board()
	if ai_anim_from >= 0 and ai_anim_to >= 0:
		_animate_piece_arrival(ai_anim_from, ai_anim_to, ai_anim_kind)
	_update_hud()
	_schedule_ai_turn()

func _unhandled_input(event: InputEvent) -> void:
	# Reliable mobile input: ray-pick board areas directly from the screen touch.
	# This avoids depending on Area3D.input_event delivery, which can be swallowed
	# by the viewport/UI on some Android devices.
	var screen_position := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		screen_position = event.position
		pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		screen_position = event.position
		pressed = true
	if not pressed or camera == null or not camera.is_inside_tree():
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Area3D
	if collider != null and collider.has_meta("board_node_index"):
		_select_node(int(collider.get_meta("board_node_index")))
		get_viewport().set_input_as_handled()

func _select_node(index: int) -> void:
	var animated_from := -1
	var animated_to := -1
	var animated_kind := ""
	if ai_busy or _is_ai_turn():
		return
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
			var available_moves: Array[int] = game.sheep_moves(index)
			if not available_moves.is_empty():
				selected_node = index
				feedback_message = "گوسفند انتخاب شد؛ اکنون یکی از مقصدهای سبز را بزنید."
			else:
				feedback_message = "این گوسفند حرکت قانونی ندارد؛ گوسفند دیگری را انتخاب کنید."
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

	if game.turn == GameState.Turn.SHEEP and game.sheep[index] > 0:
		var alternate_moves: Array[int] = game.sheep_moves(index)
		if not alternate_moves.is_empty():
			selected_node = index
			feedback_message = "انتخاب به گوسفند دیگری تغییر کرد؛ مقصد سبز را بزنید."
		else:
			feedback_message = "این گوسفند حرکت قانونی ندارد؛ گوسفند انتخاب‌شدهٔ قبلی حفظ شد."
		_refresh_board()
		_update_hud()
		return

	if game.turn == GameState.Turn.SHEEP:
		if game.move_sheep(selected_node, index):
			_play_move_sound()
			animated_from = selected_node
			animated_to = index
			animated_kind = "sheep"
			selected_node = -1
			feedback_message = "گوسفند جابه‌جا شد؛ اکنون نوبت گرگ‌هاست."
		else:
			feedback_message = "حرکت نامعتبر است؛ فقط به نقطهٔ خالیِ متصل حرکت کنید."
	else:
		var captured_node := -1
		for capture_option in game.capture_options(selected_node):
			if int(capture_option["to"]) == index:
				captured_node = int(capture_option["middle"])
				break
		var result: String = game.move_wolf(selected_node, index)
		if result in ["moved", "captured", "captured_chain_available", "won"]:
			animated_from = selected_node
			animated_to = index
			animated_kind = "wolf"
		if result == "captured_chain_available":
			if captured_node >= 0:
				_play_capture_effect(captured_node)
			selected_node = game.chain_wolf
			chain_time_left = 3.0
			pass_button.visible = true
			feedback_message = "شکار انجام شد؛ می‌توانید با همان گرگ شکار دوم کنید یا نوبت را پایان دهید."
		elif result in ["moved", "captured", "won"]:
			if result == "moved":
				_play_move_sound()
			if captured_node >= 0:
				_play_capture_effect(captured_node)
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
	if animated_from >= 0 and animated_to >= 0:
		_animate_piece_arrival(animated_from, animated_to, animated_kind)
	_update_hud()
	_schedule_ai_turn()

func _animate_piece_arrival(from_index: int, to_index: int, piece_kind: String) -> void:
	if from_index < 0 or to_index < 0 or to_index >= node_visuals.size():
		return
	var destination_visual := node_visuals[to_index]
	var candidates: Array[Node3D] = []
	for child in destination_visual.get_children():
		if child is Node3D and child.is_in_group("animated_game_piece"):
			candidates.append(child)
	if candidates.is_empty():
		return
	var piece: Node3D = candidates[candidates.size() - 1] if piece_kind == "sheep" else candidates[0]
	var target_position := piece.position
	var source_world := node_visuals[from_index].global_position
	var source_local := destination_visual.global_transform.affine_inverse() * source_world
	piece.position = Vector3(source_local.x, maxf(source_local.y + 0.28, 0.38), source_local.z)
	piece.scale = Vector3.ONE * 0.88
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(piece, "position", target_position, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "scale", Vector3.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_game() -> void:
	game.reset()
	announced_winner = ""
	ai_turn_generation += 1
	ai_busy = false
	selected_node = -1
	chain_time_left = 0.0
	pass_button.visible = false
	feedback_message = "بازی تازه آغاز شد؛ سه نقطهٔ خالی را برای گرگ‌ها انتخاب کنید."
	_refresh_board()
	_update_hud()
	_schedule_ai_turn()

func _trigger_camera_shake() -> void:
	camera_shake_time = 0.24
	camera_shake_strength = 0.075


func _play_capture_effect(node_index: int) -> void:
	_play_capture_sound()
	_trigger_camera_shake()
	if node_index < 0 or node_index >= node_visuals.size():
		return
	var effect_root := Node3D.new()
	add_child(effect_root)
	effect_root.global_position = node_visuals[node_index].global_position + Vector3(0.0, 0.16, 0.0)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.20
	ring_mesh.outer_radius = 0.27
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 32
	ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.58, 0.12)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.28, 0.035)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	ring.rotation.x = PI * 0.5
	effect_root.add_child(ring)
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.13
	flash_mesh.height = 0.26
	flash.mesh = flash_mesh
	var flash_material := StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.76, 0.32, 0.82)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.42, 0.08)
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = flash_material
	flash.position.y = 0.10
	effect_root.add_child(flash)
	var caption := Label3D.new()
	caption.text = "شکار!"
	caption.font_size = 30
	caption.outline_size = 7
	caption.modulate = Color(1.0, 0.88, 0.48)
	caption.position = Vector3(0.0, 0.48, 0.0)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	effect_root.add_child(caption)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(2.7, 2.7, 2.7), 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector3(2.2, 2.2, 2.2), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_material, "albedo_color:a", 0.0, 0.38)
	tween.tween_property(caption, "position:y", 0.95, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(caption, "modulate:a", 0.0, 0.62)
	tween.chain().tween_callback(effect_root.queue_free)


func _refresh_board() -> void:
	sheep_idle_pivots.clear()
	wolf_idle_pivots.clear()
	wolf_tail_pivots.clear()
	for index in range(BoardGraph.NODE_COUNT):
		var visual := node_visuals[index]
		for child in visual.get_children():
			child.queue_free()
		# Broad, low-profile destination pads remain visible around the feet of pieces.
		# Selected and legal nodes use emissive colors so the next action is unmistakable.
		var marker := MeshInstance3D.new()
		var marker_mesh := CylinderMesh.new()
		var is_selected := index == selected_node
		var is_capture := index in _capture_targets()
		var is_legal := index in _legal_targets()
		marker_mesh.top_radius = 0.34 if (is_selected or is_legal) else 0.19
		marker_mesh.bottom_radius = marker_mesh.top_radius
		marker_mesh.height = 0.035
		marker_mesh.radial_segments = 32
		marker.mesh = marker_mesh
		var marker_material := StandardMaterial3D.new()
		marker_material.roughness = 0.55
		if is_selected:
			marker_material.albedo_color = Color(1.0, 0.72, 0.08)
			marker_material.emission_enabled = true
			marker_material.emission = Color(0.9, 0.48, 0.02)
		elif is_capture:
			# Amber distinguishes a legal wolf capture from an ordinary green move.
			marker_material.albedo_color = Color(1.0, 0.48, 0.12)
			marker_material.emission_enabled = true
			marker_material.emission = Color(0.75, 0.19, 0.015)
		elif is_legal:
			marker_material.albedo_color = Color(0.18, 0.95, 0.38)
			marker_material.emission_enabled = true
			marker_material.emission = Color(0.04, 0.55, 0.12)
		else:
			marker_material.albedo_color = Color(0.91, 0.78, 0.48)
		marker.material_override = marker_material
		marker.position.y = 0.045
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
	# Five individually readable sheep, using a lightweight mesh budget for mobile.
	var wool := _material(Color(0.98, 0.96, 0.88))
	var face := _material(Color(0.24, 0.20, 0.17))
	var hoof := _material(Color(0.12, 0.11, 0.10))
	var visible_count: int = mini(count, 5)
	for i in range(visible_count):
		var pivot := Node3D.new()
		pivot.add_to_group("animated_game_piece")
		var column := i % 3
		var row := int(i / 3)
		pivot.position = Vector3((column - 1) * 0.34, 0.30, (row - 0.5) * 0.34)
		pivot.scale = Vector3.ONE * 1.18
		pivot.rotation.y = PI * 0.5
		parent.add_child(pivot)
		var body := MeshInstance3D.new()
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.19
		body_mesh.height = 0.34
		body.mesh = body_mesh
		body.material_override = wool
		pivot.add_child(body)
		for tuft_index in range(2):
			var tuft := MeshInstance3D.new()
			var tuft_mesh := SphereMesh.new()
			tuft_mesh.radius = 0.105
			tuft_mesh.height = 0.15
			tuft.mesh = tuft_mesh
			tuft.material_override = wool
			tuft.position = Vector3(-0.06 + float(tuft_index) * 0.13, 0.10, 0.0)
			pivot.add_child(tuft)
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.115
		head_mesh.height = 0.20
		head.mesh = head_mesh
		head.material_override = face
		head.position = Vector3(0.18, 0.04, 0.0)
		pivot.add_child(head)
		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var eye_mesh := SphereMesh.new()
			eye_mesh.radius = 0.025
			eye_mesh.height = 0.045
			eye.mesh = eye_mesh
			eye.material_override = hoof
			eye.position = Vector3(0.255, 0.085, side * 0.075)
			pivot.add_child(eye)
		var legs := MeshInstance3D.new()
		var legs_mesh := BoxMesh.new()
		legs_mesh.size = Vector3(0.25, 0.16, 0.24)
		legs.mesh = legs_mesh
		legs.material_override = hoof
		legs.position = Vector3(-0.015, -0.17, 0.0)
		pivot.add_child(legs)
	var count_label := Label3D.new()
	count_label.text = str(count)
	count_label.font_size = 28
	count_label.outline_size = 6
	count_label.position = Vector3(0, 0.98, 0)
	parent.add_child(count_label)

func _add_wolf_piece(parent: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.add_to_group("animated_game_piece")
	pivot.scale = Vector3.ONE * 1.28
	parent.add_child(pivot)
	wolf_idle_pivots.append(pivot)
	var fur := _material(Color(0.19, 0.23, 0.29))
	var muzzle := _material(Color(0.57, 0.57, 0.52))
	var dark := _material(Color(0.075, 0.08, 0.09))
	var eye_amber := _material(Color(0.98, 0.68, 0.18))
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.29
	body_mesh.height = 0.49
	body.mesh = body_mesh
	body.material_override = fur
	body.position = Vector3(-0.025, 0.43, 0.0)
	pivot.add_child(body)
	var chest := MeshInstance3D.new()
	var chest_mesh := SphereMesh.new()
	chest_mesh.radius = 0.19
	chest_mesh.height = 0.36
	chest.mesh = chest_mesh
	chest.material_override = muzzle
	chest.position = Vector3(0.13, 0.43, -0.015)
	pivot.add_child(chest)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.material_override = fur
	head.position = Vector3(0.22, 0.59, -0.02)
	pivot.add_child(head)
	var snout := MeshInstance3D.new()
	var snout_mesh := SphereMesh.new()
	snout_mesh.radius = 0.105
	snout_mesh.height = 0.15
	snout.mesh = snout_mesh
	snout.material_override = muzzle
	snout.position = Vector3(0.39, 0.53, -0.02)
	pivot.add_child(snout)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := CylinderMesh.new()
		ear_mesh.top_radius = 0.0
		ear_mesh.bottom_radius = 0.075
		ear_mesh.height = 0.23
		ear.mesh = ear_mesh
		ear.material_override = fur
		ear.position = Vector3(0.15, 0.80, side * 0.13)
		pivot.add_child(ear)
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.027
		eye_mesh.height = 0.054
		eye.mesh = eye_mesh
		eye.material_override = eye_amber
		eye.position = Vector3(0.34, 0.63, side * 0.135)
		pivot.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.012
		pupil_mesh.height = 0.024
		pupil.mesh = pupil_mesh
		pupil.material_override = dark
		pupil.position = Vector3(0.36, 0.635, side * 0.15)
		pivot.add_child(pupil)
	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.047
	nose_mesh.height = 0.065
	nose.mesh = nose_mesh
	nose.material_override = dark
	nose.position = Vector3(0.475, 0.54, -0.02)
	pivot.add_child(nose)
	for leg_index in range(4):
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.045
		leg_mesh.bottom_radius = 0.055
		leg_mesh.height = 0.24
		leg.mesh = leg_mesh
		leg.material_override = fur
		leg.position = Vector3(-0.12 if leg_index < 2 else 0.13, 0.20, -0.15 if leg_index % 2 == 0 else 0.15)
		pivot.add_child(leg)
	var tail := MeshInstance3D.new()
	var tail_mesh := CapsuleMesh.new()
	tail_mesh.radius = 0.07
	tail_mesh.height = 0.25
	tail.mesh = tail_mesh
	tail.material_override = fur
	tail.position = Vector3(-0.31, 0.47, 0.0)
	tail.rotation_degrees.z = 55.0
	pivot.add_child(tail)
	wolf_tail_pivots.append(tail)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result

func _update_chain_countdown() -> void:
	detail_label.text = "شکار دوم با همان گرگ اختیاری است؛ زمان باقی‌مانده: %.1f ثانیه" % chain_time_left

func _update_hud() -> void:
	if game.turn == GameState.Turn.FINISHED and game.winner != "" and game.winner != announced_winner:
		announced_winner = game.winner
		if victory_audio != null:
			victory_audio.play()
	if game.turn == GameState.Turn.PLACE_WOLVES:
		_set_turn_view(-1)
		status_label.text = "گرگ و میش | چیدمان گرگ‌ها"
		detail_label.text = "گرگ‌ها: %d از ۳ | سه نقطهٔ خالی را انتخاب کنید." % game.wolf_total()
	elif game.turn == GameState.Turn.SHEEP:
		_set_turn_view(1)
		status_label.text = "نوبت گوسفندها"
		detail_label.text = "گوسفندان باقی‌مانده: %d | یک گوسفند را انتخاب کنید، سپس مقصد سبز را بزنید." % game.sheep_total()
	elif game.turn == GameState.Turn.WOLVES:
		_set_turn_view(-1)
		status_label.text = "نوبت گرگ‌ها"
		detail_label.text = "گرگ را انتخاب کنید؛ مقصد سبز = حرکت، مقصد نارنجی = شکار."
	elif game.winner == "wolves":
		status_label.text = "پایان بازی | پیروزی گرگ‌ها"
		detail_label.text = "تعداد گوسفندان به ۸ یا کمتر رسیده است."
	elif game.winner == "sheep":
		status_label.text = "پایان بازی | پیروزی گوسفندها"
		detail_label.text = "هر سه گرگ بدون حرکت قانونی مانده‌اند."
	var remaining_sheep: int = game.sheep_total()
	var captured_sheep: int = maxi(0, 25 - remaining_sheep)
	capture_count_label.text = "🐺 گوسفند شکارشده: %d  |  باقی‌مانده: %d" % [captured_sheep, remaining_sheep]
	message_label.text = feedback_message
	if chain_time_left > 0.0:
		_update_chain_countdown()

func _set_turn_view(side: int) -> void:
	# Chess-like hot-seat orientation: each side sees the board from its own edge.
	# Sheep start on row E (z positive); wolves face them from row A (z negative).
	# The board and pieces never move; only the camera viewpoint rotates 180 degrees.
	camera_view_turn = side
	var view_sign := 1.0 if side >= 0 else -1.0
	camera_target_position = Vector3(0.0, 20.0, 22.0 * view_sign)

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

func _capture_targets() -> Array[int]:
	var targets: Array[int] = []
	if game.turn != GameState.Turn.WOLVES or selected_node < 0:
		return targets
	if game.chain_wolf != -1 and selected_node != game.chain_wolf:
		return targets
	for capture in game.capture_options(selected_node):
		targets.append(int(capture["to"]))
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
