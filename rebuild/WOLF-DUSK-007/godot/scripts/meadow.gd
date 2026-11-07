extends Node3D

# WOLF-DUSK-032: cinematic twilight palette and fog in the active main scene.

# WOLF-DUSK-030: enlarged, gold-trimmed start pads keep five sheep compact and readable.

const GRID_SIZE := 5
const SPACING := 2.2
const BOARD_TOUCH_RADIUS := 1.08
const TOUCH_FALLBACK_RADIUS_PIXELS := 70.0
const NODE_MARKER_SELECTED_RADIUS := 0.44
const NODE_MARKER_IDLE_RADIUS := 0.25
const NODE_PAD_RADIUS := 1.08
const NODE_PAD_HEIGHT := 0.22
const SHEEP_SLOT_SPACING := 0.36
const BoardGraph = preload("res://scripts/board_graph.gd")
const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

var game = GameState.new()
var _shared_resources: Dictionary = {}
var camera: Camera3D
var camera_target_position: Vector3 = Vector3(0.0, 22.0, 8.0)
var camera_target_look_at: Vector3 = Vector3.ZERO
var camera_view_turn: int = -1
var camera_mode: String = "overview"
var camera_mode_generation: int = 0
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
var ai_difficulty: int = 3
var ai_busy: bool = false
var ai_turn_generation: int = 0
var move_audio: AudioStreamPlayer
var capture_audio: AudioStreamPlayer
var victory_audio: AudioStreamPlayer
var music_audio: AudioStreamPlayer
var music_button: Button
var setup_music_button: Button
var music_enabled: bool = true
var announced_winner: String = ""
var celebration_layer: CanvasLayer
# Two-finger camera gestures are deliberately separate from one-finger board taps.
var camera_orbit_yaw: float = 0.0
var camera_orbit_pitch: float = 1.249
var camera_orbit_distance: float = 28.46
var touch_points: Dictionary = {}
var last_pinch_distance: float = 0.0

func _ready() -> void:
	# WOLF-DUSK-036: paint the real startup screen before constructing the
	# procedural 3D meadow and synthesizing the 16-second music buffer.
	# These synchronous tasks previously ran before the first visible frame,
	# leaving Android users on a dark screen during startup.
	_build_hud()
	_update_hud()
	_show_setup_menu()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_build_audio()
	_build_environment()
	_build_board()
	_build_camera()
	_build_light()
	_refresh_board()
	_update_hud()
	# Build the long music buffer only after the first usable screen is visible.
	call_deferred("_prepare_meadow_music")

func _process(delta: float) -> void:
	sheep_anim_clock += delta
	# Animate one representative sheep per occupied flock, not all 125 possible sheep.
	# This gives the meadow a living feel while keeping the mobile frame budget small.
	for i in range(sheep_idle_pivots.size()):
		var sheep_pivot := sheep_idle_pivots[i]
		if is_instance_valid(sheep_pivot):
			var sheep_phase := sheep_anim_clock * 1.6 + float(i) * 1.37
			var base_y := float(sheep_pivot.get_meta("idle_base_y", 0.29))
			sheep_pivot.position.y = base_y + sin(sheep_phase) * 0.012
			sheep_pivot.rotation.x = sin(sheep_phase * 0.7) * 0.012
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
		# The phone camera is normally locked. Skip transforms and look_at every frame
		# unless a real camera transition or a short shake is active.
		var camera_moving := camera.position.distance_squared_to(camera_target_position) > 0.0001
		if camera_moving or camera_shake_time > 0.0:
			if camera_moving:
				var camera_smooth := 1.0 - exp(-6.0 * delta)
				camera.position = camera.position.lerp(camera_target_position, camera_smooth)
			if camera_shake_time > 0.0:
				camera_shake_time = maxf(0.0, camera_shake_time - delta)
				var shake_phase := sheep_anim_clock * 58.0
				var shake_fade := camera_shake_time / 0.24
				camera.position += Vector3(sin(shake_phase) * camera_shake_strength, cos(shake_phase * 1.31) * camera_shake_strength * 0.45, sin(shake_phase * 0.77) * camera_shake_strength * 0.55) * shake_fade
			else:
				camera_shake_strength = 0.0
			camera.look_at(camera_target_look_at, Vector3.UP)
	if chain_time_left > 0.0:
		chain_time_left = maxf(0.0, chain_time_left - delta)
		if chain_time_left <= 0.0:
			game.finish_wolf_turn()
			pass_button.visible = false
			selected_node = -1
			feedback_message = "مهلت شکار دوم تمام شد؛ نوبت گوسفندهاست."
			_refresh_board()
			_update_hud()
			# Expiry completes the wolf turn; trigger the computer sheep immediately.
			_schedule_ai_turn()
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
	music_audio.volume_db = -5.0
	music_audio.bus = "Master"
	music_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_audio)

func _prepare_meadow_music() -> void:
	var stream: AudioStreamWAV = await _make_meadow_music_async()
	if not is_inside_tree() or music_audio == null:
		return
	music_audio.stream = stream
	if music_enabled:
		music_audio.play()

func _make_meadow_music_async() -> AudioStreamWAV:
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
		if sample_index > 0 and sample_index % 8192 == 0:
			await get_tree().process_frame
		var time := float(sample_index) / float(sample_rate)
		var beat_time := fmod(time, 2.0)
		var chord_index := mini(int(time / 2.0), chords.size() - 1)
		var envelope := minf(1.0, beat_time / 0.22) * minf(1.0, (2.0 - beat_time) / 0.30)
		var sample := 0.0
		for frequency in chords[chord_index]:
			var hz := float(frequency)
			sample += sin(TAU * hz * time) * 0.62
			sample += sin(TAU * hz * 2.0 * time) * 0.10
		sample = sample / 3.0 * envelope * 0.42
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
	music_enabled = enabled
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

func _play_audio_test() -> void:
	# A clearly audible reference tone helps distinguish a silent output route from a music issue.
	if victory_audio != null:
		victory_audio.play()

func _ensure_music_playing() -> void:
	if music_audio != null and not music_audio.playing:		music_audio.play()

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
	sky_material.sky_top_color = Color(0.055, 0.09, 0.20)
	sky_material.sky_horizon_color = Color(0.72, 0.48, 0.39)
	sky_material.ground_bottom_color = Color(0.07, 0.12, 0.10)
	sky_material.ground_horizon_color = Color(0.31, 0.34, 0.27)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.63, 0.78)
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.49, 0.43, 0.49)
	environment.fog_density = 0.0045
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.08
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	_build_twilight_accents()

	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(26.0, 26.0)
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
	_build_stone_approach()
	_build_distant_meadow_ridges()


func _build_twilight_accents() -> void:
	# A visible moon and warm meadow lanterns make the in-game scene distinct
	# from the flat green prototype while keeping every light shadow-free on mobile.
	var moon := MeshInstance3D.new()
	moon.name = "TwilightMoon"
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 0.82
	moon_mesh.height = 1.64
	moon_mesh.radial_segments = 24
	moon_mesh.rings = 12
	moon.mesh = moon_mesh
	var moon_material := StandardMaterial3D.new()
	moon_material.albedo_color = Color(1.0, 0.88, 0.62)
	moon_material.emission_enabled = true
	moon_material.emission = Color(0.92, 0.64, 0.30)
	moon_material.emission_energy_multiplier = 1.4
	moon_material.roughness = 0.72
	moon.material_override = moon_material
	moon.position = Vector3(-8.2, 7.8, -9.5)
	add_child(moon)

	var lantern_positions := [
		Vector3(-7.0, 0.0, -2.8), Vector3(7.0, 0.0, 2.8),
		Vector3(-6.8, 0.0, 6.0), Vector3(6.8, 0.0, -6.0)
	]
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.055
	post_mesh.bottom_radius = 0.085
	post_mesh.height = 1.35
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color(0.22, 0.12, 0.075)
	post_material.roughness = 0.86
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.19
	bulb_mesh.height = 0.38
	bulb_mesh.radial_segments = 12
	bulb_mesh.rings = 6
	var bulb_material := StandardMaterial3D.new()
	bulb_material.albedo_color = Color(1.0, 0.67, 0.31)
	bulb_material.emission_enabled = true
	bulb_material.emission = Color(1.0, 0.43, 0.12)
	bulb_material.emission_energy_multiplier = 1.8
	for position in lantern_positions:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = post_material
		post.position = position + Vector3(0.0, 0.68, 0.0)
		add_child(post)
		var bulb := MeshInstance3D.new()
		bulb.mesh = bulb_mesh
		bulb.material_override = bulb_material
		bulb.position = position + Vector3(0.0, 1.42, 0.0)
		add_child(bulb)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.58, 0.28)
		light.light_energy = 0.55
		light.omni_range = 3.4
		light.shadow_enabled = false
		light.position = position + Vector3(0.0, 1.5, 0.0)
		add_child(light)


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
	grass_batch.instance_count = 520
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
	flower_batch.instance_count = 96
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


func _build_distant_meadow_ridges() -> void:
	# Broad, softly lit low-poly hills make the playfield read as an outdoor valley.
	var ridge_mesh := SphereMesh.new()
	ridge_mesh.radius = 1.0
	ridge_mesh.height = 2.0
	ridge_mesh.radial_segments = 16
	ridge_mesh.rings = 8
	var ridge_colors := [Color(0.22, 0.39, 0.25), Color(0.30, 0.47, 0.29), Color(0.36, 0.49, 0.32)]
	var ridge_specs := [
		[Vector3(-10.5, 0.15, -8.5), Vector3(6.8, 2.2, 2.5)],
		[Vector3(-3.5, 0.10, -10.0), Vector3(7.5, 2.8, 2.2)],
		[Vector3(5.5, 0.12, -9.0), Vector3(8.2, 2.5, 2.6)],
		[Vector3(10.5, 0.12, 1.0), Vector3(3.0, 2.4, 8.0)],
		[Vector3(-10.5, 0.12, 2.0), Vector3(3.2, 2.1, 7.5)]
	]
	for i in range(ridge_specs.size()):
		var hill := MeshInstance3D.new()
		hill.mesh = ridge_mesh
		hill.material_override = _material(ridge_colors[i % ridge_colors.size()])
		hill.position = ridge_specs[i][0]
		hill.scale = ridge_specs[i][1]
		add_child(hill)

func _build_stone_approach() -> void:
	# A short hand-laid stone approach frames the front of the meadow board.
	# All slabs stay beyond the playable 5x5 field and use shared materials.
	var stone_mesh := BoxMesh.new()
	stone_mesh.size = Vector3(0.78, 0.13, 0.58)
	var stone_colors := [Color(0.48, 0.47, 0.40), Color(0.57, 0.53, 0.44), Color(0.40, 0.42, 0.38)]
	var stones := 9
	for i in range(stones):
		var t := float(i) / float(stones - 1)
		var slab := MeshInstance3D.new()
		slab.mesh = stone_mesh
		slab.material_override = _material(stone_colors[i % stone_colors.size()])
		var x := lerpf(-3.35, 3.35, t)
		var z := 7.35 - sin(t * PI) * 0.62
		slab.position = Vector3(x, -0.015, z)
		slab.rotation.y = sin(float(i) * 1.7) * 0.10
		slab.scale = Vector3(1.0 + float(i % 3) * 0.08, 1.0, 0.92 + float(i % 2) * 0.12)
		add_child(slab)

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
		sphere.radius = BOARD_TOUCH_RADIUS
		collision.shape = sphere
		area.add_child(collision)
		add_child(area)
		node_areas.append(area)
		var visual := Node3D.new()
		area.add_child(visual)
		node_visuals.append(visual)

func _build_camera() -> void:
	camera = Camera3D.new()
	# Phone-first overview: leave generous margins around the complete board.
	# Tactical selection and piece animation must never zoom past the playable area.
	camera.position = Vector3(0.0, 22.8, 7.8)
	camera.current = true
	camera.fov = 44.0
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	light.light_energy = 1.35
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
	header.offset_bottom = 250.0
	root.add_child(header)
	var header_column := VBoxContainer.new()
	header_column.add_theme_constant_override("separation", 5)
	header.add_child(header_column)

	player_names_label = Label.new()
	player_names_label.text = "گوسفندها: %s  |  گرگ‌ها: %s" % [player_one_name, player_two_name]
	player_names_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_names_label.add_theme_font_size_override("font_size", 25)
	header_column.add_child(player_names_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 34)
	header_column.add_child(status_label)

	capture_count_label = Label.new()
	capture_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_count_label.add_theme_font_size_override("font_size", 25)
	capture_count_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.36))
	header_column.add_child(capture_count_label)

	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 23)
	header_column.add_child(detail_label)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 23)
	header_column.add_child(message_label)

	# Bottom controls remain outside the board's central play area.
	var footer := PanelContainer.new()
	footer.anchor_left = 0.0
	footer.anchor_top = 1.0
	footer.anchor_right = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 12.0
	footer.offset_top = -250.0
	footer.offset_right = -12.0
	footer.offset_bottom = -12.0
	root.add_child(footer)
	var footer_column := VBoxContainer.new()
	footer_column.add_theme_constant_override("separation", 7)
	footer.add_child(footer_column)

	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 7)
	footer_column.add_child(controls)

	pass_button = Button.new()
	pass_button.text = "پایان شکار دوم"
	pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_button.custom_minimum_size = Vector2(0, 56)
	pass_button.add_theme_font_size_override("font_size", 20)
	pass_button.visible = false
	pass_button.pressed.connect(_decline_chain_capture)
	controls.add_child(pass_button)

	var reset_button := Button.new()
	reset_button.text = "بازی تازه"
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.custom_minimum_size = Vector2(0, 56)
	reset_button.add_theme_font_size_override("font_size", 20)
	reset_button.pressed.connect(_reset_game)
	controls.add_child(reset_button)

	music_button = Button.new()
	music_button.text = "موسیقی: روشن"
	music_button.toggle_mode = true
	music_button.button_pressed = true
	music_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_button.custom_minimum_size = Vector2(0, 56)
	music_button.add_theme_font_size_override("font_size", 19)
	music_button.toggled.connect(_toggle_meadow_music)
	controls.add_child(music_button)

	var setup_button := Button.new()
	setup_button.text = "تنظیم بازی"
	setup_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_button.custom_minimum_size = Vector2(0, 56)
	setup_button.add_theme_font_size_override("font_size", 19)
	setup_button.pressed.connect(_show_setup_menu)
	controls.add_child(setup_button)

	var sound_test_button := Button.new()
	sound_test_button.text = "آزمون صدا"
	sound_test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_test_button.custom_minimum_size = Vector2(0, 56)
	sound_test_button.add_theme_font_size_override("font_size", 19)
	sound_test_button.pressed.connect(_play_audio_test)
	controls.add_child(sound_test_button)

	var credit := Label.new()
	credit.text = "سازنده و معرفی‌کننده: آرش سلیمی"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 18)
	footer_column.add_child(credit)

func _show_setup_menu() -> void:
	if is_instance_valid(setup_layer):
		setup_layer.queue_free()
	setup_layer = CanvasLayer.new()
	setup_layer.layer = 30
	add_child(setup_layer)
	var shade := ColorRect.new()
	# Keep the meadow visible but prevent the HUD behind the setup screen from competing.
	shade.color = Color(0.008, 0.025, 0.018, 0.34)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup_layer.add_child(shade)
	var poster := TextureRect.new()
	poster.name = "StartScreenPosterBackground"
	poster.texture = load("res://assets/start_poster.svg")
	poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	setup_layer.add_child(poster)
	setup_layer.move_child(poster, 0)
	setup_layer.move_child(shade, 1)
	var viewport_size := get_viewport().get_visible_rect().size
	# Use almost the full available phone height so every setting is easy to reach.
	# Keep a centered maximum width on tablets while preserving a 12 px safe margin.
	var horizontal_margin := clampf((viewport_size.x - 680.0) * 0.5, 8.0, 48.0)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = horizontal_margin
	panel.offset_right = -horizontal_margin
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.custom_minimum_size = Vector2(minf(300.0, maxf(0.0, viewport_size.x - horizontal_margin * 2.0)), 0.0)
	# Re-apply the full-rect layout after parenting to CanvasLayer so the
	# panel receives the live viewport rectangle on first frame on Android.
	setup_layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = horizontal_margin
	panel.offset_right = -horizontal_margin
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	var panel_style := StyleBoxFlat.new()
	# WOLF-DUSK-037: the poster must remain the dominant full-screen artwork.
	# The previous full-rect panel tinted almost the entire image and made the
	# start screen look unchanged. Keep only a subtle glass-like veil behind controls.
	panel_style.bg_color = Color(0.018, 0.045, 0.032, 0.16)
	panel_style.border_color = Color(0.88, 0.72, 0.42, 0.52)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	panel_style.shadow_size = 5
	# Narrow phones need compact inner gutters so the panel's minimum width
	# cannot exceed the visible viewport when large Persian controls are laid out.
	var inner_gutter := 12.0 if viewport_size.x < 420.0 else 24.0
	panel_style.content_margin_left = inner_gutter
	panel_style.content_margin_right = inner_gutter
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Give the content column the full usable screen height. The two flexible
	# spacers balance the menu vertically instead of leaving all unused space below.
	column.custom_minimum_size = Vector2(0.0, maxf(viewport_size.y - 52.0, 0.0))
	column.add_theme_constant_override("separation", 14)
	column.add_theme_font_size_override("font_size", 24)
	column.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	scroll.add_child(column)
	var top_spacer := Control.new()
	top_spacer.name = "StartScreenTopSpacer"
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.custom_minimum_size.y = 1.0
	column.add_child(top_spacer)
	var emblem := TextureRect.new()
	emblem.texture = load("res://assets/title_emblem.svg")
	emblem.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.12, 78.0, 108.0))
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(emblem)
	var heading := Label.new()
	heading.text = "گرگ و میش"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 42)
	heading.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	heading.add_theme_color_override("font_outline_color", Color(0.035, 0.07, 0.045, 1.0))
	heading.add_theme_constant_override("outline_size", 3)
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "راز دشت سبز | نوع مسابقه و نام بازیکن را انتخاب کنید"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", Color(0.98, 0.95, 0.83))
	column.add_child(subtitle)
	var sheep_name := LineEdit.new()
	sheep_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheep_name.placeholder_text = "نام بازیکن گوسفندها"
	sheep_name.text = player_one_name
	sheep_name.custom_minimum_size = Vector2(0, 70)
	sheep_name.add_theme_font_size_override("font_size", 28)
	column.add_child(sheep_name)
	var wolf_name := LineEdit.new()
	wolf_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wolf_name.placeholder_text = "نام بازیکن گرگ‌ها"
	wolf_name.text = player_two_name
	wolf_name.custom_minimum_size = Vector2(0, 70)
	wolf_name.add_theme_font_size_override("font_size", 28)
	column.add_child(wolf_name)
	var mode_picker := OptionButton.new()
	mode_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_picker.add_item("دو نفرهٔ حضوری روی یک دستگاه", 0)
	mode_picker.add_item("بازی با رایانه (هوش مصنوعی)", 1)
	column.add_child(mode_picker)
	var side_picker := OptionButton.new()
	side_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_picker.add_item("من گوسفندها باشم", 0)
	side_picker.add_item("من گرگ‌ها باشم", 1)
	column.add_child(side_picker)
	var difficulty_picker := OptionButton.new()
	difficulty_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_picker.add_item("هوش مصنوعی: آموزشی", 0)
	difficulty_picker.add_item("هوش مصنوعی: آسان", 1)
	difficulty_picker.add_item("هوش مصنوعی: متوسط", 2)
	difficulty_picker.add_item("هوش مصنوعی: سخت", 3)
	difficulty_picker.add_item("هوش مصنوعی: استاد", 4)
	# Oversized touch targets and popup typography are both required: setting
	# only the closed OptionButton font leaves Android's opened choice list tiny.
	mode_picker.custom_minimum_size = Vector2(0, 86)
	side_picker.custom_minimum_size = Vector2(0, 82)
	difficulty_picker.custom_minimum_size = Vector2(0, 82)
	difficulty_picker.select(3) # Default to hard; educational/random play is opt-in.
	column.add_child(difficulty_picker)
	mode_picker.add_theme_font_size_override("font_size", 31)
	side_picker.add_theme_font_size_override("font_size", 30)
	difficulty_picker.add_theme_font_size_override("font_size", 30)
	mode_picker.get_popup().add_theme_font_size_override("font_size", 29)
	side_picker.get_popup().add_theme_font_size_override("font_size", 29)
	difficulty_picker.get_popup().add_theme_font_size_override("font_size", 29)
	mode_picker.get_popup().add_theme_constant_override("v_separation", 14)
	side_picker.get_popup().add_theme_constant_override("v_separation", 12)
	difficulty_picker.get_popup().add_theme_constant_override("v_separation", 12)
	setup_music_button = Button.new()
	setup_music_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_music_button.text = "موسیقی دشت: روشن"
	setup_music_button.toggle_mode = true
	setup_music_button.button_pressed = true
	setup_music_button.custom_minimum_size = Vector2(0, 64)
	setup_music_button.add_theme_font_size_override("font_size", 24)
	setup_music_button.toggled.connect(_toggle_meadow_music)
	column.add_child(setup_music_button)
	var start_button := Button.new()
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.text = "شروع مسابقه"
	start_button.custom_minimum_size = Vector2(0, 82)
	start_button.add_theme_font_size_override("font_size", 34)
	var start_style := StyleBoxFlat.new()
	start_style.bg_color = Color(0.67, 0.31, 0.10, 1.0)
	start_style.border_color = Color(1.0, 0.83, 0.40, 1.0)
	start_style.set_border_width_all(2)
	start_style.set_corner_radius_all(18)
	start_style.content_margin_top = 10.0
	start_style.content_margin_bottom = 10.0
	start_button.add_theme_stylebox_override("normal", start_style)
	start_button.add_theme_stylebox_override("hover", start_style)
	start_button.pressed.connect(func():
		if is_instance_valid(celebration_layer):
			celebration_layer.queue_free()
			celebration_layer = null
		game.reset()
		ai_turn_generation += 1
		ai_busy = false
		selected_node = -1
		chain_time_left = 0.0
		pass_button.visible = false
		announced_winner = ""
		_refresh_board()
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
		var opponent_level_text := ""
		if match_mode == "ai":
			var level_names := ["آموزشی", "آسان", "متوسط", "سخت", "استاد"]
			opponent_level_text = "\nسطح هوش مصنوعی: %s" % level_names[clampi(ai_difficulty, 0, 4)]
		player_names_label.text = "گوسفندها: %s  |  گرگ‌ها: %s%s" % [player_one_name, player_two_name, opponent_level_text]
		setup_layer.queue_free()
		setup_layer = null
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
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(0.98, 0.90, 0.70))
	column.add_child(note)
	var bottom_spacer := Control.new()
	bottom_spacer.name = "StartScreenBottomSpacer"
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.custom_minimum_size.y = 1.0
	column.add_child(bottom_spacer)

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
				# Let the selected difficulty evaluate the optional second capture.
				# The rules permit only the same wolf to continue the chain.
				var chain_move: Dictionary = AI.choose_wolf_move(game, ai_difficulty)
				if not chain_move.is_empty():
					var chain_from := int(chain_move.from)
					var chain_to := int(chain_move.to)
					var chain_capture_node := -1
					for option in game.capture_options(chain_from):
						if int(option.to) == chain_to:
							chain_capture_node = int(option.middle)
							break
					var chain_result: String = game.move_wolf(chain_from, chain_to)
					if chain_result in ["captured", "won"]:
						ai_anim_to = chain_to
						ai_anim_kind = "wolf"
						if chain_capture_node >= 0:
							_play_capture_effect(chain_capture_node)
					elif chain_result == "captured_chain_available":
						# The current rules cap a chain at two captures; fail closed.
						game.finish_wolf_turn()
				else:
					game.finish_wolf_turn()
				feedback_message = "رایانه با ارزیابی تاکتیکی، شکار زنجیره‌ای را انجام داد."
			else:
				feedback_message = "رایانه گرگ‌ها را حرکت داد."
		else:			feedback_message = "رایانه حرکت قانونی دیگری ندارد."
	ai_busy = false
	selected_node = -1
	chain_time_left = 0.0
	pass_button.visible = false
	_refresh_board()
	_update_hud()
	if ai_anim_from >= 0 and ai_anim_to >= 0:
		_animate_piece_arrival(ai_anim_from, ai_anim_to, ai_anim_kind)
	_schedule_ai_turn()

func _unhandled_input(event: InputEvent) -> void:
	# Two-finger gestures orbit and zoom the camera; a normal one-finger tap
	# remains dedicated to selecting board nodes.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch_points.size() >= 1:
				touch_points[touch.index] = touch.position
				last_pinch_distance = _current_pinch_distance()
				get_viewport().set_input_as_handled()
				return
			touch_points[touch.index] = touch.position
		else:
			touch_points.erase(touch.index)
			if touch_points.size() < 2:
				last_pinch_distance = 0.0
			return
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if touch_points.has(drag.index):
			touch_points[drag.index] = drag.position
		if touch_points.size() >= 2:
			camera_orbit_yaw -= drag.relative.x * 0.006
			camera_orbit_pitch = clampf(camera_orbit_pitch + drag.relative.y * 0.004, 0.88, 1.35)
			var pinch_distance := _current_pinch_distance()
			if last_pinch_distance > 1.0 and pinch_distance > 1.0:
				camera_orbit_distance = clampf(camera_orbit_distance * last_pinch_distance / pinch_distance, 22.0, 38.0)
			last_pinch_distance = pinch_distance
			_apply_camera_orbit()
			get_viewport().set_input_as_handled()
		return

	# Reliable mobile input: ray-pick board areas directly from the screen touch.
	# This avoids depending on Area3D.input_event delivery, which can be swallowed
	# by the viewport/UI on some Android devices.
	var screen_position := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		screen_position = event.position
		pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Android can synthesize a mouse click for the same finger touch.
		# Ignore that duplicate so one tap cannot select and then cancel a piece.
		if OS.has_feature("mobile"):
			return
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
	if not hit.is_empty():
		var collider := hit.get("collider") as Area3D
		if collider != null and collider.has_meta("board_node_index"):
			_select_node(int(collider.get_meta("board_node_index")))
			get_viewport().set_input_as_handled()
			return
	# Touch fallback: choose the closest projected board point when physics picking misses.
	# This makes small Android touch targets forgiving without allowing taps on distant cells.
	var nearest_index := -1
	var nearest_distance := TOUCH_FALLBACK_RADIUS_PIXELS
	for node_index in range(node_areas.size()):
		var point_on_screen := camera.unproject_position(node_areas[node_index].global_position)
		var distance := point_on_screen.distance_to(screen_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = node_index
	if nearest_index >= 0:
		_select_node(nearest_index)
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
			_set_tactical_view(index)
			feedback_message = "گرگ %d از ۳ در جای خود قرار گرفت." % game.wolf_total()
		else:
			feedback_message = "این نقطه خالی نیست؛ برای گرگ یک نقطهٔ خالی انتخاب کنید."
		_refresh_board()
		_update_hud()
		# Once the human wolf player places the third wolf, the sheep turn
		# belongs to the AI. Schedule it here before returning from setup input.
		_schedule_ai_turn()
		return

	if selected_node == -1:
		if game.turn == GameState.Turn.SHEEP and game.sheep[index] > 0:
			var available_moves: Array[int] = game.sheep_moves(index)
			if not available_moves.is_empty():
				selected_node = index
				_set_tactical_view(index)
				feedback_message = "یک گوسفند از %d گوسفند این جایگاه انتخاب شد؛ حلقهٔ طلایی آن را نشان می‌دهد. مقصد سبز را لمس کنید." % game.sheep[index]
			else:
				feedback_message = "این گوسفند حرکت قانونی ندارد؛ گوسفند دیگری را انتخاب کنید."
		elif game.turn == GameState.Turn.WOLVES and game.wolves[index]:
			if game.chain_wolf == -1 or game.chain_wolf == index:
				selected_node = index
				_set_tactical_view(index)
				feedback_message = "گرگ انتخاب شد؛ مسیر حرکت و خطرها را بررسی کنید."
			else:
				feedback_message = "در شکار زنجیره‌ای فقط همان گرگِ شکارکننده اجازهٔ حرکت دارد."
		else:
			feedback_message = "ابتدا یک مهرهٔ متعلق به بازیکنِ نوبت را انتخاب کنید."
		_refresh_board()
		_update_hud()
		return

	if index == selected_node:
		selected_node = -1
		_set_turn_view(-1 if game.turn == GameState.Turn.WOLVES else 1, true)
		feedback_message = "انتخاب لغو شد؛ مهرهٔ دیگری را انتخاب کنید."
		_refresh_board()
		_update_hud()
		return

	if game.turn == GameState.Turn.SHEEP and game.sheep[index] > 0:
		var alternate_moves: Array[int] = game.sheep_moves(index)
		if not alternate_moves.is_empty():
			selected_node = index
			_set_tactical_view(index)
			feedback_message = "انتخاب به گوسفند دیگری تغییر کرد؛ مقصدهای مجاز روشن شدند."
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
	_update_hud()
	if animated_from >= 0 and animated_to >= 0:
		_animate_piece_arrival(animated_from, animated_to, animated_kind)
	_schedule_ai_turn()

func _animate_piece_arrival(from_index: int, to_index: int, piece_kind: String) -> void:
	var camera_generation := _set_jump_view(from_index, to_index)
	call_deferred("_restore_overview_after_jump", camera_generation)
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
	var takeoff := piece.position
	var apex := (takeoff + target_position) * 0.5 + Vector3(0.0, 0.82 if piece_kind == "sheep" else 1.05, 0.0)
	piece.scale = Vector3.ONE * 0.88
	var tween := create_tween()
	tween.tween_property(piece, "position", apex, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(piece, "scale", Vector3.ONE * 1.10, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position", target_position, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(piece, "scale", Vector3.ONE, 0.19).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_game() -> void:
	if is_instance_valid(celebration_layer):
		celebration_layer.queue_free()
		celebration_layer = null
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
	# Compute move hints once per refresh instead of recalculating them for all 25 nodes.
	var legal_targets := _legal_targets()
	var capture_targets := _capture_targets()
	for index in range(BoardGraph.NODE_COUNT):
		var visual := node_visuals[index]
		for child in visual.get_children():
			child.queue_free()
		# A real raised node platform gives five sheep or one wolf a clear physical footprint.
		# Its diameter stays below the 2.2-unit node spacing, preserving a visible path gap.
		var node_platform := MeshInstance3D.new()
		node_platform.name = "NodePlatform"
		node_platform.mesh = _cached_cylinder(NODE_PAD_RADIUS, NODE_PAD_RADIUS, NODE_PAD_HEIGHT)
		node_platform.material_override = _cached_material(Color(0.38, 0.31, 0.23))
		node_platform.position.y = -0.095
		visual.add_child(node_platform)
		var platform_trim := MeshInstance3D.new()
		platform_trim.name = "NodePlatformGoldTrim"
		var trim_mesh := TorusMesh.new()
		trim_mesh.inner_radius = 1.015
		trim_mesh.outer_radius = 1.095
		trim_mesh.rings = 12
		trim_mesh.ring_segments = 32
		platform_trim.mesh = trim_mesh
		platform_trim.material_override = _cached_material(Color(0.86, 0.65, 0.29))
		platform_trim.position.y = 0.012
		visual.add_child(platform_trim)
		var platform_top := MeshInstance3D.new()
		platform_top.name = "NodePlatformStoneTop"
		platform_top.mesh = _cached_cylinder(0.99, 0.99, 0.045)
		platform_top.material_override = _cached_material(Color(0.72, 0.62, 0.43))
		platform_top.position.y = 0.018
		visual.add_child(platform_top)
		# Broad, low-profile destination markers remain visible above the platform.
		# Selected and legal nodes use emissive colors so the next action is unmistakable.
		var marker := MeshInstance3D.new()
		var is_selected := index == selected_node
		var is_capture := index in capture_targets
		var is_legal := index in legal_targets
		var marker_radius := NODE_MARKER_SELECTED_RADIUS if (is_selected or is_legal) else NODE_MARKER_IDLE_RADIUS
		marker.mesh = _cached_cylinder(marker_radius, marker_radius, 0.035)
		if is_selected:
			marker.material_override = _cached_emissive_material(Color(1.0, 0.72, 0.08), Color(0.9, 0.48, 0.02))
		elif is_capture:
			# Amber distinguishes a legal wolf capture from an ordinary green move.
			marker.material_override = _cached_emissive_material(Color(1.0, 0.48, 0.12), Color(0.75, 0.19, 0.015))
		elif is_legal:
			marker.material_override = _cached_emissive_material(Color(0.18, 0.95, 0.38), Color(0.04, 0.55, 0.12))
		else:
			marker.material_override = _cached_material(Color(0.91, 0.78, 0.48))
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
			_add_sheep_piece(visual, index, game.sheep[index], game.turn == GameState.Turn.SHEEP and selected_node == index)
		if game.wolves[index]:
			_add_wolf_piece(visual, index)

func _add_sheep_piece(parent: Node3D, node_index: int, count: int, highlight_one: bool = false) -> void:
	# Shared low-poly resources reduce allocation and draw preparation on mobile.
	# Three fleece curls preserve the recognizable sheep silhouette with fewer parts.
	var wool := _cached_material(Color(0.98, 0.96, 0.88))
	var wool_light := _cached_material(Color(1.0, 0.99, 0.94))
	var face := _cached_material(Color(0.72, 0.53, 0.43))
	var inner_ear := _cached_material(Color(0.91, 0.63, 0.58))
	var hoof := _cached_material(Color(0.20, 0.17, 0.16))
	var eye := _cached_material(Color(0.055, 0.045, 0.04))
	var shine := _cached_material(Color(1.0, 1.0, 0.94))
	var visible_count: int = mini(count, 5)
	for i in range(visible_count):
		var pivot := Node3D.new()
		pivot.name = "SheepSlot_%d" % i
		pivot.add_to_group("animated_game_piece")
		var column := i % 3
		var row := int(i / 3)
		pivot.position = Vector3((column - 1) * SHEEP_SLOT_SPACING, 0.29, (row - 0.5) * SHEEP_SLOT_SPACING)
		pivot.scale = Vector3.ONE * (1.48 if highlight_one and i == visible_count - 1 else 1.38)
		pivot.rotation.y = _awareness_yaw(node_index, _sheep_attention_target(node_index))
		parent.add_child(pivot)
		# One animated representative per flock is enough to communicate breathing
		# without updating every sheep in a five-piece stack every frame.
		if i == 0:
			pivot.set_meta("idle_base_y", pivot.position.y)
			sheep_idle_pivots.append(pivot)
		if highlight_one and i == visible_count - 1:
			var ring := MeshInstance3D.new()
			var ring_mesh := TorusMesh.new()
			ring_mesh.inner_radius = 0.235
			ring_mesh.outer_radius = 0.285
			ring_mesh.rings = 12
			ring_mesh.ring_segments = 8
			ring.mesh = ring_mesh
			ring.material_override = _cached_material(Color(1.0, 0.72, 0.08))
			ring.position = Vector3(0.0, 0.045, 0.0)
			ring.rotation.x = PI * 0.5
			pivot.add_child(ring)

		var body := MeshInstance3D.new()
		body.mesh = _cached_sphere(0.205, 0.37)
		body.material_override = wool
		body.position = Vector3(-0.015, 0.36, 0.0)
		body.scale = Vector3(1.12, 0.94, 0.92)
		pivot.add_child(body)
		# Two side fleece puffs make the sheep read as a fuller, soft 3D character.
		for side in [-1.0, 1.0]:
			var side_fleece := MeshInstance3D.new()
			side_fleece.mesh = _cached_sphere(0.105, 0.22)
			side_fleece.material_override = wool_light
			side_fleece.position = Vector3(-0.07, 0.405, side * 0.155)
			pivot.add_child(side_fleece)

		var curl_positions := [
			Vector3(-0.11, 0.47, -0.105),
			Vector3(0.015, 0.535, 0.0),
			Vector3(0.105, 0.46, 0.105)
		]
		for curl_index in range(curl_positions.size()):
			var curl := MeshInstance3D.new()
			curl.mesh = _cached_sphere(0.092 if curl_index != 1 else 0.105, 0.20)
			curl.material_override = wool_light if curl_index == 1 else wool
			curl.position = curl_positions[curl_index]
			pivot.add_child(curl)

		var head := MeshInstance3D.new()
		head.mesh = _cached_sphere(0.125, 0.23)
		head.material_override = face
		head.position = Vector3(0.205, 0.405, 0.0)
		head.scale = Vector3(1.0, 1.05, 0.88)
		pivot.add_child(head)

		var muzzle := MeshInstance3D.new()
		muzzle.mesh = _cached_sphere(0.068, 0.105)
		muzzle.material_override = inner_ear
		muzzle.position = Vector3(0.292, 0.365, 0.0)
		pivot.add_child(muzzle)

		for side in [-1.0, 1.0]:
			var ear := MeshInstance3D.new()
			ear.mesh = _cached_sphere(0.052, 0.15)
			ear.material_override = face
			ear.position = Vector3(0.16, 0.47, side * 0.125)
			ear.rotation.z = -0.38
			ear.scale = Vector3(0.7, 1.0, 0.7)
			pivot.add_child(ear)

			var eye_white := MeshInstance3D.new()
			eye_white.mesh = _cached_sphere(0.033, 0.055)
			eye_white.material_override = shine
			eye_white.position = Vector3(0.286, 0.445, side * 0.066)
			pivot.add_child(eye_white)

			var pupil := MeshInstance3D.new()
			pupil.mesh = _cached_sphere(0.018, 0.034)
			pupil.material_override = eye
			pupil.position = Vector3(0.309, 0.447, side * 0.071)
			pivot.add_child(pupil)

		var nose := MeshInstance3D.new()
		nose.mesh = _cached_sphere(0.022, 0.035)
		nose.material_override = hoof
		nose.position = Vector3(0.354, 0.366, 0.0)
		pivot.add_child(nose)

		for leg_index in range(4):
			var leg := MeshInstance3D.new()
			leg.mesh = _cached_cylinder(0.027, 0.034, 0.17)
			leg.material_override = hoof
			leg.position = Vector3(-0.105 if leg_index < 2 else 0.12, 0.18, -0.115 if leg_index % 2 == 0 else 0.115)
			pivot.add_child(leg)

	var count_label := Label3D.new()
	count_label.text = str(count)
	count_label.font_size = 28
	count_label.outline_size = 6
	count_label.position = Vector3(0, 0.98, 0)
	parent.add_child(count_label)


# Awareness is cosmetic only: it never changes legal moves, turns or capture rules.
# Models face local +X, so this converts a board-space direction into a yaw.
func _awareness_yaw(from_index: int, to_index: int) -> float:
	if to_index < 0 or to_index >= BoardGraph.NODE_COUNT or from_index == to_index:
		return PI * 0.5
	var from_row := int(from_index / 5)
	var from_col := from_index % 5
	var to_row := int(to_index / 5)
	var to_col := to_index % 5
	var direction := Vector2(float(to_col - from_col), float(to_row - from_row))
	if direction.length_squared() < 0.0001:
		return PI * 0.5
	return atan2(-direction.y, direction.x)

func _sheep_attention_target(node_index: int) -> int:
	if selected_node == node_index and game.turn == GameState.Turn.SHEEP:
		var selected_moves := game.sheep_moves(node_index)
		if not selected_moves.is_empty():
			return int(selected_moves[0])
	var moves := game.sheep_moves(node_index)
	var best_target := -1
	var best_safety := -INF
	for destination in moves:
		var safety := INF
		for wolf_index in range(BoardGraph.NODE_COUNT):
			if game.wolves[wolf_index]:
				var distance := Vector2(float((destination % 5) - (wolf_index % 5)), float(int(destination / 5) - int(wolf_index / 5))).length_squared()
				safety = minf(safety, distance)
		if safety > best_safety:
			best_safety = safety
			best_target = int(destination)
	return best_target

func _wolf_attention_target(node_index: int) -> int:
	if selected_node == node_index and game.turn == GameState.Turn.WOLVES:
		var captures := game.capture_options(node_index)
		if not captures.is_empty():
			return int(captures[0]["middle"])
		var moves := game.wolf_moves(node_index)
		if not moves.is_empty():
			return int(moves[0])
	var nearest_sheep := -1
	var nearest_distance := INF
	for sheep_index in range(BoardGraph.NODE_COUNT):
		if game.sheep[sheep_index] <= 0:
			continue
		var distance := Vector2(float((sheep_index % 5) - (node_index % 5)), float(int(sheep_index / 5) - int(node_index / 5))).length_squared()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_sheep = sheep_index
	return nearest_sheep

func _cached_material(color: Color) -> StandardMaterial3D:
	var key := "mat_" + color.to_html(true)
	if not _shared_resources.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_shared_resources[key] = material
	return _shared_resources[key] as StandardMaterial3D

func _cached_sphere(radius: float, height: float) -> SphereMesh:
	var key := "sphere_%.3f_%.3f" % [radius, height]
	if not _shared_resources.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.radial_segments = 12
		mesh.rings = 6
		_shared_resources[key] = mesh
	return _shared_resources[key] as SphereMesh

func _cached_cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var key := "cylinder_%.3f_%.3f_%.3f" % [top_radius, bottom_radius, height]
	if not _shared_resources.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top_radius
		mesh.bottom_radius = bottom_radius
		mesh.height = height
		mesh.radial_segments = 12
		_shared_resources[key] = mesh
	return _shared_resources[key] as CylinderMesh

func _add_wolf_piece(parent: Node3D, node_index: int) -> void:
	# Stronger silhouette and amber eyes echo the wolf artwork on the new app icon.
	var pivot := Node3D.new()
	pivot.add_to_group("animated_game_piece")
	pivot.scale = Vector3.ONE * 1.62
	pivot.rotation.y = _awareness_yaw(node_index, _wolf_attention_target(node_index))
	parent.add_child(pivot)
	wolf_idle_pivots.append(pivot)
	var fur := _material(Color(0.27, 0.32, 0.39))
	var fur_light := _material(Color(0.43, 0.49, 0.55))
	var muzzle_mat := _material(Color(0.72, 0.70, 0.64))
	var dark := _material(Color(0.055, 0.065, 0.075))
	var ear_inner := _material(Color(0.68, 0.37, 0.35))
	var eye_amber := _material(Color(1.0, 0.66, 0.12))
	var eye_glint := _material(Color(1.0, 0.94, 0.68))

	var torso := MeshInstance3D.new()
	var torso_mesh := _cached_sphere(0.29, 0.49)
	torso.mesh = torso_mesh
	torso.material_override = fur
	torso.position = Vector3(-0.035, 0.39, 0.0)
	torso.scale = Vector3(1.22, 0.92, 0.88)
	pivot.add_child(torso)

	var chest := MeshInstance3D.new()
	var chest_mesh := _cached_sphere(0.18, 0.34)
	chest.mesh = chest_mesh
	chest.material_override = fur_light
	chest.position = Vector3(0.15, 0.39, 0.0)
	pivot.add_child(chest)
	# Layered shoulder ruff gives the wolf a clearer, more dimensional silhouette.
	for side in [-1.0, 1.0]:
		var ruff := MeshInstance3D.new()
		ruff.mesh = _cached_sphere(0.145, 0.28)
		ruff.material_override = fur_light
		ruff.position = Vector3(-0.015, 0.47, side * 0.19)
		ruff.scale = Vector3(1.0, 1.0, 0.82)
		pivot.add_child(ruff)

	var neck := MeshInstance3D.new()
	var neck_mesh := _cached_sphere(0.17, 0.30)
	neck.mesh = neck_mesh
	neck.material_override = fur_light
	neck.position = Vector3(0.16, 0.53, 0.0)
	neck.rotation.z = -0.22
	pivot.add_child(neck)

	var head := MeshInstance3D.new()
	var head_mesh := _cached_sphere(0.19, 0.34)
	head.mesh = head_mesh
	head.material_override = fur
	head.position = Vector3(0.235, 0.61, 0.0)
	head.scale = Vector3(1.0, 1.08, 0.92)
	pivot.add_child(head)

	# Pointed ears, visible even from the board overview.
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := _cached_cylinder(0.0, 0.095, 0.29)
		ear.mesh = ear_mesh
		ear.material_override = fur
		ear.position = Vector3(0.16, 0.83, side * 0.13)
		ear.rotation_degrees = Vector3(0.0, 0.0, -13.0)
		pivot.add_child(ear)

		var ear_center := MeshInstance3D.new()
		var ear_center_mesh := _cached_sphere(0.045, 0.12)
		ear_center.mesh = ear_center_mesh
		ear_center.material_override = ear_inner
		ear_center.position = Vector3(0.19, 0.82, side * 0.13)
		pivot.add_child(ear_center)

		var eye := MeshInstance3D.new()
		var eye_mesh := _cached_sphere(0.041, 0.072)
		eye.mesh = eye_mesh
		eye.material_override = eye_amber
		eye.position = Vector3(0.375, 0.655, side * 0.126)
		pivot.add_child(eye)

		var pupil := MeshInstance3D.new()
		var pupil_mesh := _cached_sphere(0.019, 0.038)
		pupil.mesh = pupil_mesh
		pupil.material_override = dark
		pupil.position = Vector3(0.401, 0.658, side * 0.139)
		pivot.add_child(pupil)

		var glint := MeshInstance3D.new()
		var glint_mesh := _cached_sphere(0.010, 0.018)
		glint.mesh = glint_mesh
		glint.material_override = eye_glint
		glint.position = Vector3(0.414, 0.676, side * 0.142)
		pivot.add_child(glint)

	var snout := MeshInstance3D.new()
	var snout_mesh := _cached_sphere(0.11, 0.17)
	snout.mesh = snout_mesh
	snout.material_override = muzzle_mat
	snout.position = Vector3(0.395, 0.525, 0.0)
	snout.scale = Vector3(1.18, 0.75, 0.82)
	pivot.add_child(snout)

	var nose := MeshInstance3D.new()
	var nose_mesh := _cached_sphere(0.045, 0.065)
	nose.mesh = nose_mesh
	nose.material_override = dark
	nose.position = Vector3(0.49, 0.545, 0.0)
	pivot.add_child(nose)

	var jaw := MeshInstance3D.new()
	var jaw_mesh := _cached_sphere(0.078, 0.10)
	jaw.mesh = jaw_mesh
	jaw.material_override = dark
	jaw.position = Vector3(0.385, 0.445, 0.0)
	jaw.scale = Vector3(1.2, 0.5, 0.9)
	pivot.add_child(jaw)

	for leg_index in range(4):
		var leg := MeshInstance3D.new()
		var leg_mesh := _cached_cylinder(0.047, 0.058, 0.25)
		leg.mesh = leg_mesh
		leg.material_override = fur
		leg.position = Vector3(-0.15 if leg_index < 2 else 0.15, 0.17, -0.16 if leg_index % 2 == 0 else 0.16)
		pivot.add_child(leg)

	var tail_pivot := Node3D.new()
	tail_pivot.position = Vector3(-0.30, 0.45, 0.0)
	pivot.add_child(tail_pivot)
	var tail := MeshInstance3D.new()
	var tail_mesh := CapsuleMesh.new()
	tail_mesh.radius = 0.085
	tail_mesh.height = 0.30
	tail.mesh = tail_mesh
	tail.material_override = fur
	tail.position = Vector3(-0.08, -0.015, 0.0)
	tail.rotation_degrees.z = 55.0
	tail_pivot.add_child(tail)
	wolf_tail_pivots.append(tail_pivot)

func _material(color: Color) -> StandardMaterial3D:
	# Reuse wolf and environment materials across board refreshes.
	return _cached_material(color)

func _cached_emissive_material(color: Color, emission: Color) -> StandardMaterial3D:
	var key := "emissive_" + color.to_html(true) + "_" + emission.to_html(true)
	if not _shared_resources.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.55
		material.emission_enabled = true
		material.emission = emission
		_shared_resources[key] = material
	return _shared_resources[key] as StandardMaterial3D

func _update_chain_countdown() -> void:
	detail_label.text = "شکار دوم با همان گرگ اختیاری است؛ زمان باقی‌مانده: %.1f ثانیه" % chain_time_left

func _update_hud() -> void:
	if game.turn == GameState.Turn.FINISHED and game.winner != "" and game.winner != announced_winner:
		announced_winner = game.winner
		if victory_audio != null:
			victory_audio.play()
		call_deferred("_show_victory_celebration")
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


func _show_victory_celebration() -> void:
	if is_instance_valid(celebration_layer) or game.winner == "":
		return
	celebration_layer = CanvasLayer.new()
	celebration_layer.layer = 20
	add_child(celebration_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	celebration_layer.add_child(shade)

	# Lightweight 2D confetti: short-lived UI shapes, independent of 3D physics.
	var palette := [Color(1.0, 0.72, 0.16), Color(0.25, 0.86, 0.48), Color(0.35, 0.72, 1.0), Color(1.0, 0.42, 0.48), Color(0.92, 0.82, 1.0)]
	var viewport_size := get_viewport().get_visible_rect().size
	for i in range(28):
		var confetti := ColorRect.new()
		confetti.color = palette[i % palette.size()]
		confetti.size = Vector2(7.0 + float(i % 3) * 3.0, 13.0)
		confetti.position = Vector2(randf_range(12.0, maxf(13.0, viewport_size.x - 20.0)), -24.0 - float(i % 7) * 18.0)
		confetti.rotation = randf_range(-0.7, 0.7)
		celebration_layer.add_child(confetti)
		var fall := create_tween()
		fall.tween_property(confetti, "position", Vector2(confetti.position.x + randf_range(-65.0, 65.0), viewport_size.y + 30.0), randf_range(1.8, 3.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		fall.parallel().tween_property(confetti, "rotation", randf_range(-4.0, 4.0), 2.2)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.28
	panel.anchor_bottom = 0.72
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.14, 0.105, 0.98)
	style.border_color = Color(0.96, 0.75, 0.28, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	celebration_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "جشن پیروزی!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.36))
	column.add_child(title)
	var winner_label := Label.new()
	winner_label.text = "برنده: %s" % (player_one_name if game.winner == "sheep" else player_two_name)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 27)
	column.add_child(winner_label)
	var reason := Label.new()
	reason.text = "گوسفندان پیروز شدند؛ هر سه گرگ محاصره شدند." if game.winner == "sheep" else "گرگ‌ها پیروز شدند؛ تعداد گوسفندان به ۸ رسید."
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.add_theme_font_size_override("font_size", 19)
	column.add_child(reason)
	var score := Label.new()
	score.text = "گوسفندان باقی‌مانده: %d از ۲۵" % game.sheep_total()
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 18)
	column.add_child(score)
	var replay := Button.new()
	replay.text = "بازی دوباره"
	replay.custom_minimum_size = Vector2(0, 52)
	replay.add_theme_font_size_override("font_size", 22)
	replay.pressed.connect(func():
		celebration_layer.queue_free()
		celebration_layer = null
		_reset_game()
	)
	column.add_child(replay)
	var settings := Button.new()
	settings.text = "تنظیم مسابقه / تغییر حریف"
	settings.custom_minimum_size = Vector2(0, 46)
	settings.add_theme_font_size_override("font_size", 18)
	settings.pressed.connect(func():
		celebration_layer.queue_free()
		celebration_layer = null
		_show_setup_menu()
	)
	column.add_child(settings)

func _current_pinch_distance() -> float:
	if touch_points.size() < 2:
		return 0.0
	var points: Array = touch_points.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)

func _apply_camera_orbit() -> void:
	if camera == null:
		return
	var horizontal_radius := camera_orbit_distance * cos(camera_orbit_pitch)
	var offset := Vector3(
		sin(camera_orbit_yaw) * horizontal_radius,
		camera_orbit_distance * sin(camera_orbit_pitch),
		cos(camera_orbit_yaw) * horizontal_radius
	)
	camera_target_look_at = Vector3.ZERO
	camera_target_position = camera_target_look_at + offset
	camera.fov = 48.0

func _set_turn_view(side: int, force_overview: bool = false) -> void:
	# In computer matches keep the human player's viewpoint for the entire match.
	# In local two-player mode, continue presenting the active side.
	camera_view_turn = side
	if match_mode == "ai":
		camera_orbit_yaw = 0.0 if human_side == "sheep" else PI
	else:
		camera_orbit_yaw = 0.0 if side >= 0 else PI
	camera_mode = "overview"
	if force_overview:
		camera_mode_generation += 1
	_apply_camera_orbit()

func _set_tactical_view(node_index: int) -> void:
	# Selection is communicated by the gold ring and legal-destination pads.
	# Keep the same stable full-board camera for both players.
	if node_index < 0 or node_index >= node_areas.size():
		return
	camera_mode = "overview"
	_apply_camera_orbit()

func _set_jump_view(from_index: int, to_index: int) -> int:
	# Keep the full board in frame while the piece animation plays.
	# No camera orbit or zoom during a move.
	if from_index < 0 or to_index < 0 or from_index >= node_areas.size() or to_index >= node_areas.size():
		return camera_mode_generation
	camera_mode = "overview"
	_apply_camera_orbit()
	return camera_mode_generation

func _restore_overview_after_jump(generation: int) -> void:
	await get_tree().create_timer(0.72).timeout
	if not is_inside_tree() or generation != camera_mode_generation:
		return
	var side := -1 if game.turn == GameState.Turn.PLACE_WOLVES or game.turn == GameState.Turn.WOLVES else 1
	_set_turn_view(side, true)

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
	# Declining the optional second capture also hands control to AI sheep.
	_schedule_ai_turn()