extends Control

const FlightModelScript = preload("res://scripts/FlightModel.gd")
const StageDefinitionScript = preload("res://scripts/StageDefinition.gd")
const SaveManagerScript = preload("res://scripts/SaveManager.gd")

enum ScreenState { TITLE, STAGE_SELECT, RUNNING, RESULT }

var state: ScreenState = ScreenState.TITLE
var model: WindReaderFlightModel
var stage: Dictionary
var saves: WindReaderSaveManager
var font: Font
var qa_mode := false
var paused := false
var selected_stage_id := 1

var touch_steer := Vector2.ZERO
var steer_touch_id := -1
var steer_origin := Vector2.ZERO
var boost_touch_id := -1
var mouse_boost := false

var processed_gates: Dictionary = {}
var processed_obstacles: Dictionary = {}
var required_passed := 0
var bonus_passed := 0
var combo := 0
var score := 0
var result_clear := false
var result_reason := ""
var result_medal := ""
var result_best := false
var current_wind_label := "CALM"
var wind_strength := 0.0
var tutorial_step := 0
var tutorial_timer := 0.0
var sfx_player: AudioStreamPlayer
var sfx_streams: Dictionary = {}
var last_boost_active := false
var feedback_text := ""
var feedback_color := Color.WHITE
var feedback_timer := 0.0
var screen_flash := 0.0
var scene_time := 0.0

var play_rect := Rect2()
var stage_select_rect := Rect2()
var stage_buttons: Array[Rect2] = []
var back_rect := Rect2()
var retry_rect := Rect2()
var next_rect := Rect2()
var result_stage_select_rect := Rect2()
var title_rect := Rect2()
var sound_rect := Rect2()
var boost_rect := Rect2()

func _ready() -> void:
	stage = StageDefinitionScript.get_stage(selected_stage_id)
	model = FlightModelScript.new()
	model.reset(stage)
	saves = SaveManagerScript.new()
	saves.load_state()
	_setup_audio()
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		font = load("res://fonts/NotoSansJP.ttf") as Font
	else:
		font = ThemeDB.fallback_font
	qa_mode = _detect_qa_mode()
	set_process_input(true)
	queue_redraw()

func _setup_audio() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)
	sfx_streams = {
		"ui": _make_tone(520.0, 720.0, 0.07, 0.18),
		"gate": _make_tone(620.0, 980.0, 0.13, 0.24),
		"bonus": _make_tone(780.0, 1320.0, 0.17, 0.22),
		"miss": _make_tone(240.0, 170.0, 0.12, 0.16),
		"boost": _make_tone(180.0, 520.0, 0.16, 0.16),
		"collision": _make_tone(150.0, 72.0, 0.20, 0.26),
		"clear": _make_tone(520.0, 1180.0, 0.34, 0.22),
		"fail": _make_tone(310.0, 105.0, 0.30, 0.20)
	}

func _make_tone(start_hz: float, end_hz: float, duration: float, gain: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := maxi(128, int(duration * float(mix_rate)))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(maxi(1, sample_count - 1))
		var hz := lerpf(start_hz, end_hz, t)
		var envelope := sin(PI * t)
		var phase := TAU * hz * float(i) / float(mix_rate)
		var wave := sin(phase) * 0.76 + sin(phase * 2.0) * 0.24
		var sample := clampi(int(wave * envelope * gain * 32767.0), -32768, 32767)
		var unsigned_sample := sample if sample >= 0 else sample + 65536
		pcm[i * 2] = unsigned_sample & 0xff
		pcm[i * 2 + 1] = (unsigned_sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = pcm
	return stream

func _play_sfx(name: String) -> void:
	if sfx_player == null or saves == null or not sfx_streams.has(name):
		return
	var levels := [1.0, 0.7, 0.4, 0.0]
	var level := float(levels[clampi(saves.sfx_step, 0, levels.size() - 1)])
	if level <= 0.0:
		return
	sfx_player.stop()
	sfx_player.stream = sfx_streams[name] as AudioStream
	sfx_player.volume_db = linear_to_db(level)
	sfx_player.play()

func _cycle_sfx() -> void:
	saves.cycle_sfx()
	_play_sfx("ui")
	_set_feedback(saves.sfx_label(), Color("#bceeff"), 0.08)
	queue_redraw()

func _set_feedback(text_value: String, color_value: Color, flash_strength: float = 0.18) -> void:
	feedback_text = text_value
	feedback_color = color_value
	feedback_timer = 1.05
	screen_flash = maxf(screen_flash, flash_strength)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		queue_redraw()

func _detect_qa_mode() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true))
	return false

func _load_stage(stage_id: int) -> void:
	selected_stage_id = clampi(stage_id, 1, 3)
	stage = StageDefinitionScript.get_stage(selected_stage_id)

func _open_stage_select() -> void:
	_play_sfx("ui")
	state = ScreenState.STAGE_SELECT
	queue_redraw()

func _start_run() -> void:
	_play_sfx("ui")
	stage = StageDefinitionScript.get_stage(selected_stage_id)
	model = FlightModelScript.new()
	model.reset(stage)
	state = ScreenState.RUNNING
	paused = false
	touch_steer = Vector2.ZERO
	steer_touch_id = -1
	boost_touch_id = -1
	mouse_boost = false
	processed_gates.clear()
	processed_obstacles.clear()
	required_passed = 0
	bonus_passed = 0
	combo = 0
	score = 0
	result_clear = false
	result_reason = ""
	result_medal = ""
	result_best = false
	tutorial_step = 0 if not saves.tutorial_completed else 3
	tutorial_timer = 0.0
	last_boost_active = false
	feedback_text = ""
	feedback_timer = 0.0
	screen_flash = 0.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	scene_time += delta
	feedback_timer = maxf(0.0, feedback_timer - delta)
	screen_flash = maxf(0.0, screen_flash - delta * 2.8)
	if state != ScreenState.RUNNING or paused:
		queue_redraw()
		return

	if tutorial_step < 3:
		tutorial_timer += delta
		if tutorial_timer > 2.3:
			tutorial_timer = 0.0
			tutorial_step += 1
			if tutorial_step >= 3 and not saves.tutorial_completed:
				saves.tutorial_completed = true
				saves.save_state()

	var steer := _read_steer()
	var boost_pressed := Input.is_key_pressed(KEY_SPACE) or boost_touch_id >= 0 or mouse_boost
	var wind := _current_wind()
	model.step(delta, steer, boost_pressed, wind)
	if model.boosting and not last_boost_active:
		_play_sfx("boost")
		_set_feedback("BOOST!", Color("#73e8ff"), 0.10)
	last_boost_active = model.boosting
	_process_gates()
	_process_obstacles()

	if model.failed_reason != "":
		_finish_run(false, model.failed_reason)
	elif model.position.x >= float(stage["length"]):
		if required_passed >= int(stage["required_target"]):
			_finish_run(true, "ゴール到達")
		else:
			_finish_run(false, "必須ゲート不足 %d/%d" % [required_passed, int(stage["required_target"])])

	queue_redraw()

func _read_steer() -> Vector2:
	var steer := touch_steer
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		steer.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		steer.y -= 1.0
	if steer.length() > 1.0:
		steer = steer.normalized()
	return steer

func _current_wind() -> Dictionary:
	current_wind_label = "CALM"
	wind_strength = 0.0
	var out := {"lift": 0.0, "cross": 0.0, "forward": 0.0, "boost_recovery": 0.0}
	for zone in stage["wind_zones"]:
		if model.position.x >= float(zone["x_start"]) and model.position.x <= float(zone["x_end"]):
			var strength := float(zone["strength"])
			var direction := float(zone["direction"])
			current_wind_label = str(zone["type"])
			wind_strength = strength
			match str(zone["type"]):
				"UPDRAFT":
					out["lift"] = 3.8 * strength
					out["boost_recovery"] = 18.0 * strength
				"CROSSWIND":
					out["cross"] = 0.22 * strength * direction
				"TAILWIND":
					out["forward"] = 4.0 * strength
				"TURBULENCE":
					out["lift"] = sin(model.position.x * 0.041) * 1.5 * strength
					out["cross"] = sin(model.position.x * 0.027 + 1.7) * 0.12 * strength
			break
	return out

func _process_gates() -> void:
	for gate in stage["gates"]:
		var gate_id := str(gate["id"])
		if processed_gates.has(gate_id):
			continue
		if model.position.x < float(gate["x"]):
			continue
		var hit := absf(model.position.y - float(gate["altitude"])) <= float(gate["alt_tol"])
		hit = hit and absf(model.position.z - float(gate["depth"])) <= float(gate["depth_tol"])
		processed_gates[gate_id] = hit
		if hit:
			combo += 1
			if bool(gate["required"]):
				required_passed += 1
				score += 1000
				_play_sfx("gate")
				_set_feedback("GATE +1000", Color("#72f1c8"), 0.18)
			else:
				bonus_passed += 1
				score += 1500
				_play_sfx("bonus")
				_set_feedback("BONUS +1500", Color("#ffe58a"), 0.24)
			score += mini(1000, 250 * maxi(0, combo - 1))
		else:
			combo = 0
			_play_sfx("miss")
			_set_feedback("GATE MISSED", Color("#c5d3dc"), 0.10)

func _process_obstacles() -> void:
	var index := 0
	for obstacle in stage["obstacles"]:
		var key := str(index)
		index += 1
		if processed_obstacles.has(key):
			continue
		if model.position.x < float(obstacle["x"]):
			continue
		processed_obstacles[key] = true
		var hit := absf(model.position.y - float(obstacle["altitude"])) <= float(obstacle["alt_radius"])
		hit = hit and absf(model.position.z - float(obstacle["depth"])) <= float(obstacle["depth_radius"])
		if hit and model.apply_collision(float(obstacle["damage"])):
			combo = 0
			_play_sfx("collision")
			_set_feedback("HIT!  DURABILITY DOWN", Color("#ff9b91"), 0.34)

func _finish_run(clear: bool, reason: String) -> void:
	if state != ScreenState.RUNNING:
		return
	state = ScreenState.RESULT
	result_clear = clear
	result_reason = reason
	if clear:
		var par_time := float(stage["par_time"])
		var faster := maxf(0.0, par_time - model.elapsed)
		score += mini(2000, int(faster * 100.0))
		if model.durability >= 99.9:
			score += 2000
		elif model.durability >= 80.0:
			score += 1000
		result_medal = _medal_for_score(score)
		result_best = saves.record_stage(selected_stage_id, score, int(model.elapsed * 1000.0), result_medal)
		if selected_stage_id < 3:
			saves.unlock_stage(selected_stage_id + 1)
		_play_sfx("clear")
		_set_feedback("CLEAR!  %s" % result_medal, Color("#78f4ce"), 0.38)
	else:
		_play_sfx("fail")
		_set_feedback("FAILED", Color("#ff9b91"), 0.34)
	touch_steer = Vector2.ZERO
	steer_touch_id = -1
	boost_touch_id = -1
	mouse_boost = false
	last_boost_active = false
	queue_redraw()

func _medal_for_score(value: int) -> String:
	var gold_score := int(stage.get("gold_score", 13000))
	var silver_score := int(stage.get("silver_score", 9000))
	if value >= gold_score:
		return "GOLD"
	if value >= silver_score:
		return "SILVER"
	return "BRONZE"

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ENTER and state == ScreenState.TITLE:
				_start_run()
				return
			if state == ScreenState.STAGE_SELECT:
				var requested_stage := 0
				if key.keycode == KEY_1:
					requested_stage = 1
				elif key.keycode == KEY_2:
					requested_stage = 2
				elif key.keycode == KEY_3:
					requested_stage = 3
				if requested_stage > 0 and requested_stage <= saves.unlocked_stage:
					_load_stage(requested_stage)
					_start_run()
					return
				if key.keycode == KEY_ESCAPE:
					state = ScreenState.TITLE
					queue_redraw()
					return
			if key.keycode == KEY_R and state == ScreenState.RESULT:
				_start_run()
				return
			if key.keycode == KEY_ENTER and state == ScreenState.RESULT and result_clear and selected_stage_id < 3:
				_load_stage(selected_stage_id + 1)
				_start_run()
				return
			if key.keycode == KEY_M:
				_cycle_sfx()
				queue_redraw()
				return
			if (key.keycode == KEY_P or key.keycode == KEY_ESCAPE) and state == ScreenState.RUNNING:
				paused = not paused
				queue_redraw()
				return
			if key.keycode == KEY_F9 and qa_mode:
				_qa_advance()
				return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if state == ScreenState.TITLE:
				if play_rect.has_point(touch.position):
					_start_run()
				elif stage_select_rect.has_point(touch.position):
					_open_stage_select()
				elif sound_rect.has_point(touch.position):
					_cycle_sfx()
					queue_redraw()
				return
			if state == ScreenState.STAGE_SELECT:
				for i in range(stage_buttons.size()):
					if stage_buttons[i].has_point(touch.position) and i + 1 <= saves.unlocked_stage:
						_load_stage(i + 1)
						_start_run()
						return
				if back_rect.has_point(touch.position):
					state = ScreenState.TITLE
					queue_redraw()
				return
			if state == ScreenState.RESULT:
				if retry_rect.has_point(touch.position):
					_start_run()
				elif result_clear and selected_stage_id < 3 and next_rect.has_point(touch.position):
					_load_stage(selected_stage_id + 1)
					_start_run()
				elif result_stage_select_rect.has_point(touch.position):
					_open_stage_select()
				elif title_rect.has_point(touch.position):
					state = ScreenState.TITLE
					queue_redraw()
				return
			if state == ScreenState.RUNNING:
				if boost_rect.has_point(touch.position):
					boost_touch_id = touch.index
				elif touch.position.x <= size.x * 0.58 and steer_touch_id < 0:
					steer_touch_id = touch.index
					steer_origin = touch.position
					touch_steer = Vector2.ZERO
		else:
			if touch.index == steer_touch_id:
				steer_touch_id = -1
				touch_steer = Vector2.ZERO
			if touch.index == boost_touch_id:
				boost_touch_id = -1
		return

	if event is InputEventScreenDrag and state == ScreenState.RUNNING:
		var drag := event as InputEventScreenDrag
		if drag.index == steer_touch_id:
			var radius := maxf(56.0, minf(size.x, size.y) * 0.095)
			var diff := drag.position - steer_origin
			touch_steer = Vector2(
				clampf(diff.x / radius, -1.0, 1.0),
				clampf(-diff.y / radius, -1.0, 1.0)
			)
			if touch_steer.length() > 1.0:
				touch_steer = touch_steer.normalized()
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if state == ScreenState.TITLE and mouse.pressed:
			if play_rect.has_point(mouse.position):
				_start_run()
			elif stage_select_rect.has_point(mouse.position):
				_open_stage_select()
			elif sound_rect.has_point(mouse.position):
				_cycle_sfx()
				queue_redraw()
		elif state == ScreenState.STAGE_SELECT and mouse.pressed:
			for i in range(stage_buttons.size()):
				if stage_buttons[i].has_point(mouse.position) and i + 1 <= saves.unlocked_stage:
					_load_stage(i + 1)
					_start_run()
					return
			if back_rect.has_point(mouse.position):
				state = ScreenState.TITLE
				queue_redraw()
		elif state == ScreenState.RESULT and mouse.pressed:
			if retry_rect.has_point(mouse.position):
				_start_run()
			elif result_clear and selected_stage_id < 3 and next_rect.has_point(mouse.position):
				_load_stage(selected_stage_id + 1)
				_start_run()
			elif result_stage_select_rect.has_point(mouse.position):
				_open_stage_select()
			elif title_rect.has_point(mouse.position):
				state = ScreenState.TITLE
				queue_redraw()
		elif state == ScreenState.RUNNING:
			mouse_boost = mouse.pressed and boost_rect.has_point(mouse.position)

func _qa_advance() -> void:
	if state == ScreenState.TITLE:
		_open_stage_select()
	elif state == ScreenState.STAGE_SELECT:
		_load_stage(1)
		_start_run()
	elif state == ScreenState.RUNNING:
		required_passed = int(stage["required_target"])
		score = int(stage.get("gold_score", 13000)) - 500
		model.position.x = float(stage["length"])
		_finish_run(true, "QA CLEAR")
	elif selected_stage_id < 3:
		_load_stage(selected_stage_id + 1)
		_start_run()
	else:
		_open_stage_select()

func _draw() -> void:
	_update_ui_rects()
	_draw_sky()
	if state == ScreenState.TITLE:
		_draw_title()
	elif state == ScreenState.STAGE_SELECT:
		_draw_stage_select()
	elif state == ScreenState.RUNNING:
		_draw_running()
	else:
		_draw_result()
	_draw_feedback_overlay()
	if qa_mode:
		_draw_qa_overlay()

func _update_ui_rects() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	stage_buttons.clear()
	if portrait:
		play_rect = Rect2(w * 0.12, h * 0.56, w * 0.76, maxf(56.0, h * 0.068))
		stage_select_rect = Rect2(w * 0.12, h * 0.66, w * 0.76, maxf(52.0, h * 0.064))
		sound_rect = Rect2(w * 0.18, h * 0.76, w * 0.64, maxf(48.0, h * 0.058))
		for i in range(3):
			stage_buttons.append(Rect2(w * 0.10, h * (0.30 + i * 0.13), w * 0.80, maxf(58.0, h * 0.082)))
		back_rect = Rect2(w * 0.20, h * 0.73, w * 0.60, maxf(48.0, h * 0.06))
		retry_rect = Rect2(w * 0.10, h * 0.58, w * 0.80, maxf(52.0, h * 0.062))
		next_rect = Rect2(w * 0.10, h * 0.67, w * 0.80, maxf(52.0, h * 0.062))
		result_stage_select_rect = Rect2(w * 0.10, h * 0.76, w * 0.80, maxf(50.0, h * 0.060))
		title_rect = Rect2(w * 0.18, h * 0.85, w * 0.64, maxf(46.0, h * 0.055))
	else:
		play_rect = Rect2(w * 0.32, h * 0.49, w * 0.36, maxf(46.0, h * 0.11))
		stage_select_rect = Rect2(w * 0.32, h * 0.64, w * 0.36, maxf(44.0, h * 0.105))
		sound_rect = Rect2(w * 0.39, h * 0.79, w * 0.22, maxf(40.0, h * 0.095))
		for i in range(3):
			stage_buttons.append(Rect2(w * (0.075 + i * 0.305), h * 0.41, w * 0.26, maxf(62.0, h * 0.18)))
		back_rect = Rect2(w * 0.37, h * 0.73, w * 0.26, maxf(42.0, h * 0.10))
		retry_rect = Rect2(w * 0.08, h * 0.68, w * 0.22, maxf(42.0, h * 0.10))
		next_rect = Rect2(w * 0.39, h * 0.68, w * 0.22, maxf(42.0, h * 0.10))
		result_stage_select_rect = Rect2(w * 0.70, h * 0.68, w * 0.22, maxf(42.0, h * 0.10))
		title_rect = Rect2(w * 0.39, h * 0.83, w * 0.22, maxf(38.0, h * 0.09))
	boost_rect = Rect2(w - maxf(112.0, w * 0.14), h - maxf(122.0, h * 0.23), maxf(88.0, w * 0.10), maxf(88.0, w * 0.10))

func _draw_sky() -> void:
	var w := size.x
	var h := size.y
	var top := Color("#14547d")
	var horizon := Color("#8bd4ee")
	var far_mountain := Color("#497a8e")
	var near_mountain := Color("#2d6872")
	if selected_stage_id == 2:
		top = Color("#214b72")
		horizon = Color("#9dc8d8")
		far_mountain = Color("#5c7080")
		near_mountain = Color("#384f5d")
	elif selected_stage_id == 3:
		top = Color("#27365d")
		horizon = Color("#7c91b1")
		far_mountain = Color("#50536d")
		near_mountain = Color("#35394f")
	for i in range(16):
		var t := float(i) / 15.0
		var band_y := h * 0.055 * float(i)
		draw_rect(Rect2(0, band_y, w, h * 0.06 + 1.0), top.lerp(horizon, t), true)
	if selected_stage_id < 3:
		var sun := Vector2(w * 0.80, h * 0.18)
		draw_circle(sun, maxf(30.0, minf(w, h) * 0.055), Color(1.0, 0.91, 0.58, 0.28))
		draw_circle(sun, maxf(20.0, minf(w, h) * 0.038), Color("#fff2a6"))
	var far_points := PackedVector2Array([
		Vector2(0, h * 0.67), Vector2(w * 0.12, h * 0.48), Vector2(w * 0.25, h * 0.64),
		Vector2(w * 0.39, h * 0.43), Vector2(w * 0.56, h * 0.66), Vector2(w * 0.72, h * 0.46),
		Vector2(w * 0.88, h * 0.63), Vector2(w, h * 0.50), Vector2(w, h * 0.78), Vector2(0, h * 0.78)
	])
	draw_colored_polygon(far_points, far_mountain)
	var parallax := fmod(model.position.x * 0.035, maxf(1.0, w))
	var near_points := PackedVector2Array([
		Vector2(-parallax, h * 0.75), Vector2(w * 0.16 - parallax, h * 0.59),
		Vector2(w * 0.32 - parallax, h * 0.73), Vector2(w * 0.49 - parallax, h * 0.56),
		Vector2(w * 0.67 - parallax, h * 0.74), Vector2(w * 0.84 - parallax, h * 0.60),
		Vector2(w * 1.08 - parallax, h * 0.72), Vector2(w * 1.08 - parallax, h), Vector2(-parallax, h)
	])
	draw_colored_polygon(near_points, near_mountain)
	draw_rect(Rect2(0, h * 0.73, w, h * 0.27), Color("#3f855f"), true)
	for i in range(8):
		var cx := fmod(float(i * 223) - model.position.x * (0.04 + i * 0.004) + w * 1.5, w + 240.0) - 120.0
		var cy := h * (0.12 + 0.045 * float(i % 4))
		var cloud := Color(1.0, 1.0, 1.0, 0.40 if selected_stage_id < 3 else 0.22)
		draw_circle(Vector2(cx - 28, cy + 6), 24.0, cloud)
		draw_circle(Vector2(cx, cy), 34.0, cloud)
		draw_circle(Vector2(cx + 31, cy + 8), 22.0, cloud)
	if selected_stage_id == 3:
		var lightning_x := w * (0.72 + sin(scene_time * 0.8) * 0.02)
		draw_polyline(PackedVector2Array([
			Vector2(lightning_x, h * 0.18), Vector2(lightning_x - 18, h * 0.31),
			Vector2(lightning_x + 4, h * 0.30), Vector2(lightning_x - 12, h * 0.44)
		]), Color(0.84, 0.91, 1.0, 0.42), 3.0)

func _draw_title() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	var panel_w := w * (0.90 if portrait else 0.68)
	var panel_h := h * (0.82 if portrait else 0.86)
	var panel := Rect2((w - panel_w) * 0.5, h * 0.07, panel_w, panel_h)
	draw_rect(panel, Color(0.04, 0.16, 0.27, 0.91), true)
	draw_rect(panel, Color("#dff8ff"), false, 2.0)

	var title_size := int(clampf(w * (0.060 if portrait else 0.037), 26.0, 46.0))
	_text(Vector2(panel.position.x + 28, panel.position.y + 58), "風読みグライダー", title_size, Color("#ffffff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 96), "風をつかみ、ゲートを抜けてゴールへ", int(clampf(title_size * 0.48, 14, 20)), Color("#bceeff"))

	var body_size := int(clampf(minf(w, h) * 0.027, 14, 19))
	var lines := [
		"自動で前進。左側ドラッグで高度と奥行きを操作",
		"上昇気流で高度とBOOSTを回復、右下BOOSTで加速",
		"3ステージを攻略し、メダルとBEST更新を目指そう"
	]
	var yy := panel.position.y + 142
	for line in lines:
		_text(Vector2(panel.position.x + 32, yy), line, body_size, Color("#e5f7ff"))
		yy += body_size + 12

	var record := saves.get_stage_record(selected_stage_id)
	_text(Vector2(panel.position.x + 32, panel.position.y + 260), "選択: STAGE %d  %s" % [selected_stage_id, str(stage["name"])], body_size, Color("#ffe28b"))
	if int(record["best_score"]) > 0:
		_text(Vector2(panel.position.x + 32, panel.position.y + 290), "BEST %d  %s" % [int(record["best_score"]), str(record["best_medal"])], 14, Color("#dff8ff"))

	_button(play_rect, "PLAY STAGE %d  /  Enter" % selected_stage_id, Color("#137b90"))
	_button(stage_select_rect, "STAGE SELECT", Color("#246878"))
	_button(sound_rect, "%s  /  M" % saves.sfx_label(), Color("#355a70"))

func _draw_stage_select() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	var panel := Rect2(w * (0.06 if portrait else 0.04), h * 0.08, w * (0.88 if portrait else 0.92), h * 0.82)
	draw_rect(panel, Color(0.03, 0.14, 0.23, 0.94), true)
	draw_rect(panel, Color("#dff8ff"), false, 2.0)
	_text(Vector2(panel.position.x + 28, panel.position.y + 56), "STAGE SELECT", int(clampf(minf(w, h) * 0.052, 26, 42)), Color.WHITE)
	_text(Vector2(panel.position.x + 30, panel.position.y + 88), "クリアすると次のステージが解放されます", 15, Color("#bceeff"))
	for i in range(3):
		var stage_id := i + 1
		var info := StageDefinitionScript.get_stage(stage_id)
		var unlocked := stage_id <= saves.unlocked_stage
		var record := saves.get_stage_record(stage_id)
		var label := "STAGE %d  %s" % [stage_id, str(info["name"])]
		if not unlocked:
			label += "  [LOCKED]"
		elif int(record["best_score"]) > 0:
			label += "  BEST %d %s" % [int(record["best_score"]), str(record["best_medal"])]
		_button(stage_buttons[i], label, Color("#176f7e") if unlocked else Color("#4a5962"))
	_button(back_rect, "BACK / Esc", Color("#355a70"))

func _draw_running() -> void:
	_draw_course()
	_draw_course_fx()
	_draw_hud()
	_draw_touch_controls()
	if selected_stage_id == 1 and tutorial_step < 3:
		_draw_tutorial()
	if paused:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.08, 0.12, 0.70), true)
		_text(Vector2(size.x * 0.41, size.y * 0.48), "PAUSED", 34, Color.WHITE)
		_text(Vector2(size.x * 0.33, size.y * 0.55), "P / Esc で再開", 17, Color("#c7edff"))

func _draw_course() -> void:
	var w := size.x
	var h := size.y
	var anchor_x := w * 0.28
	var ground_y := h * 0.82
	var ppm := maxf(0.45, w / 760.0)
	var altitude_scale := h * 0.0057
	var depth_offset := h * 0.060

	for zone in stage["wind_zones"]:
		var sx := anchor_x + (float(zone["x_start"]) - model.position.x) * ppm
		var ex := anchor_x + (float(zone["x_end"]) - model.position.x) * ppm
		if ex < 0.0 or sx > w:
			continue
		var zone_type := str(zone["type"])
		var color := Color(0.25, 0.85, 1.0, 0.15)
		var symbol := "↑"
		if zone_type == "CROSSWIND":
			color = Color(1.0, 0.85, 0.35, 0.14)
			symbol = "→" if float(zone["direction"]) > 0.0 else "←"
		elif zone_type == "TAILWIND":
			color = Color(0.45, 1.0, 0.65, 0.14)
			symbol = "≫"
		elif zone_type == "TURBULENCE":
			color = Color(0.75, 0.55, 1.0, 0.15)
			symbol = "↯"
		draw_rect(Rect2(sx, h * 0.19, ex - sx, h * 0.57), color, true)
		_text(Vector2(sx + 10, h * 0.26), symbol, 24, Color(color, 0.9))

	for gate in stage["gates"]:
		var sx := anchor_x + (float(gate["x"]) - model.position.x) * ppm
		if sx < -80.0 or sx > w + 80.0:
			continue
		var sy := ground_y - float(gate["altitude"]) * altitude_scale + float(gate["depth"]) * depth_offset
		var passed: Variant = processed_gates.get(str(gate["id"]), null)
		var c := Color("#55f1c4") if bool(gate["required"]) else Color("#ffd96b")
		if passed != null and not bool(passed):
			c = Color("#8195a0")
		var rx := 34.0 if bool(gate["required"]) else 27.0
		var ry := maxf(28.0, float(gate["alt_tol"]) * altitude_scale * 1.9)
		draw_arc(Vector2(sx, sy), rx, 0.0, TAU, 36, c, 5.0)
		draw_line(Vector2(sx - rx, sy), Vector2(sx - rx, ground_y), Color(c, 0.24), 2.0)

	for obstacle in stage["obstacles"]:
		var sx := anchor_x + (float(obstacle["x"]) - model.position.x) * ppm
		if sx < -50.0 or sx > w + 50.0:
			continue
		var sy := ground_y - float(obstacle["altitude"]) * altitude_scale + float(obstacle["depth"]) * depth_offset
		draw_circle(Vector2(sx, sy), 20.0, Color("#596874"))
		draw_circle(Vector2(sx - 10, sy + 5), 12.0, Color("#45545f"))
		draw_circle(Vector2(sx + 12, sy + 4), 14.0, Color("#6c7880"))

	var glider_y := ground_y - model.position.y * altitude_scale + model.position.z * depth_offset
	var glider := Vector2(anchor_x, glider_y)
	var body := PackedVector2Array([
		glider + Vector2(-28, 4),
		glider + Vector2(0, -9),
		glider + Vector2(32, 4),
		glider + Vector2(0, 11)
	])
	draw_colored_polygon(body, Color("#fff2a6"))
	draw_line(glider + Vector2(-28, 4), glider + Vector2(32, 4), Color("#173f5f"), 3.0)
	draw_circle(glider, 5.5, Color("#e85858"))
	if model.boosting:
		draw_line(glider + Vector2(-30, 6), glider + Vector2(-64, 10), Color("#e8fbff"), 6.0)
		draw_line(glider + Vector2(-30, 2), glider + Vector2(-52, -4), Color("#63ddff"), 3.0)

func _draw_course_fx() -> void:
	var w := size.x
	var h := size.y
	var anchor_x := w * 0.28
	var ground_y := h * 0.82
	var ppm := maxf(0.45, w / 760.0)
	var altitude_scale := h * 0.0057
	var depth_offset := h * 0.060
	for zone in stage["wind_zones"]:
		var sx := anchor_x + (float(zone["x_start"]) - model.position.x) * ppm
		var ex := anchor_x + (float(zone["x_end"]) - model.position.x) * ppm
		if ex < 0.0 or sx > w:
			continue
		var flow_color := Color(0.65, 0.94, 1.0, 0.34)
		if str(zone["type"]) == "TAILWIND":
			flow_color = Color(0.58, 1.0, 0.72, 0.34)
		elif str(zone["type"]) == "CROSSWIND":
			flow_color = Color(1.0, 0.88, 0.48, 0.34)
		elif str(zone["type"]) == "TURBULENCE":
			flow_color = Color(0.83, 0.65, 1.0, 0.34)
		var span := maxf(1.0, ex - sx)
		for i in range(6):
			var phase := fmod(scene_time * (32.0 + float(i) * 5.0) + float(i) * 71.0, span)
			var px := sx + phase
			var py := h * (0.28 + 0.072 * float(i))
			draw_line(Vector2(px - 18, py), Vector2(px + 18, py), flow_color, 2.0)
			draw_line(Vector2(px + 18, py), Vector2(px + 10, py - 6), flow_color, 2.0)
	for gate in stage["gates"]:
		var gx := anchor_x + (float(gate["x"]) - model.position.x) * ppm
		if gx < -90.0 or gx > w + 90.0:
			continue
		var gy := ground_y - float(gate["altitude"]) * altitude_scale + float(gate["depth"]) * depth_offset
		var gate_id := str(gate["id"])
		var passed: Variant = processed_gates.get(gate_id, null)
		var c := Color("#5ef4c8") if bool(gate["required"]) else Color("#ffe16f")
		if passed != null and not bool(passed):
			c = Color("#82939c")
		var pulse := 2.0 + sin(scene_time * 5.0 + float(gate_id.length())) * 2.0
		draw_arc(Vector2(gx, gy), 40.0 + pulse, 0.0, TAU, 40, Color(c, 0.24), 7.0)
		draw_arc(Vector2(gx, gy), 48.0 + pulse, 0.0, TAU, 40, Color(c, 0.10), 4.0)
		if passed != null and bool(passed):
			for ray in range(6):
				var angle := TAU * float(ray) / 6.0 + scene_time
				var p1 := Vector2(gx, gy) + Vector2(cos(angle), sin(angle)) * 50.0
				var p2 := Vector2(gx, gy) + Vector2(cos(angle), sin(angle)) * 64.0
				draw_line(p1, p2, Color(c, 0.55), 2.0)
	for obstacle in stage["obstacles"]:
		var ox := anchor_x + (float(obstacle["x"]) - model.position.x) * ppm
		if ox < -60.0 or ox > w + 60.0:
			continue
		var oy := ground_y - float(obstacle["altitude"]) * altitude_scale + float(obstacle["depth"]) * depth_offset
		var rock := PackedVector2Array([
			Vector2(ox - 24, oy + 15), Vector2(ox - 17, oy - 14), Vector2(ox - 2, oy - 24),
			Vector2(ox + 20, oy - 11), Vector2(ox + 27, oy + 14), Vector2(ox + 8, oy + 25),
			Vector2(ox - 14, oy + 23)
		])
		draw_colored_polygon(rock, Color("#364954"))
		draw_line(Vector2(ox - 13, oy - 11), Vector2(ox + 11, oy - 16), Color(0.72, 0.82, 0.86, 0.42), 3.0)
	var glider_y := ground_y - model.position.y * altitude_scale + model.position.z * depth_offset
	var glider := Vector2(anchor_x, glider_y)
	var wing_shadow := PackedVector2Array([
		glider + Vector2(-38, 9), glider + Vector2(-7, -10), glider + Vector2(38, 7),
		glider + Vector2(10, 15), glider + Vector2(-8, 15)
	])
	draw_colored_polygon(wing_shadow, Color(0.02, 0.13, 0.20, 0.36))
	var wing := PackedVector2Array([
		glider + Vector2(-35, 3), glider + Vector2(-5, -15), glider + Vector2(38, 4),
		glider + Vector2(7, 11), glider + Vector2(-10, 10)
	])
	draw_colored_polygon(wing, Color("#f7e7a1"))
	draw_line(glider + Vector2(-30, 2), glider + Vector2(34, 4), Color("#174b67"), 3.0)
	draw_circle(glider + Vector2(2, 1), 7.0, Color("#e85b55"))
	draw_circle(glider + Vector2(2, -1), 3.0, Color("#bceeff"))
	if model.boosting:
		for i in range(4):
			var trail_len := 26.0 + float(i) * 14.0
			var trail_y := float(i - 2) * 5.0 + sin(scene_time * 13.0 + float(i)) * 2.0
			draw_line(glider + Vector2(-31, trail_y), glider + Vector2(-31 - trail_len, trail_y + 3), Color(0.60, 0.94, 1.0, 0.68 - float(i) * 0.11), 3.0)

func _draw_feedback_overlay() -> void:
	if screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(feedback_color, minf(0.16, screen_flash * 0.42)), true)
	if feedback_timer <= 0.0 or feedback_text == "":
		return
	var alpha := clampf(feedback_timer, 0.0, 1.0)
	var box_w := minf(size.x * 0.68, 430.0)
	var box_h := maxf(48.0, minf(size.y * 0.075, 68.0))
	var box := Rect2((size.x - box_w) * 0.5, size.y * 0.18, box_w, box_h)
	draw_rect(box, Color(0.02, 0.10, 0.17, 0.72 * alpha), true)
	draw_rect(box, Color(feedback_color, 0.90 * alpha), false, 2.0)
	_text(box.position + Vector2(18, box.size.y * 0.64), feedback_text, int(clampf(box.size.y * 0.36, 16.0, 24.0)), Color(feedback_color, alpha))

func _draw_hud() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	var hud_h := 126.0 if portrait else 82.0
	draw_rect(Rect2(0, 0, w, hud_h), Color(0.02, 0.12, 0.20, 0.90), true)
	var progress := clampf(model.position.x / float(stage["length"]), 0.0, 1.0)
	var stage_label := "STAGE %d  %s" % [selected_stage_id, str(stage["name"])]
	if portrait:
		_text(Vector2(18, 30), stage_label, 17, Color.WHITE)
		_text(Vector2(18, 59), "GATE %d/%d   SCORE %d   COMBO x%d" % [required_passed, int(stage["required_target"]), score, combo], 14, Color("#d5f6ff"))
		_text(Vector2(18, 87), "ALT %.0f   BOOST %.0f   HP %.0f   WIND %s" % [model.position.y, model.boost, model.durability, current_wind_label], 14, Color("#d5f6ff"))
		draw_rect(Rect2(18, 104, w - 36, 8), Color("#24495d"), true)
		draw_rect(Rect2(18, 104, (w - 36) * progress, 8), Color("#58e0bb"), true)
	else:
		_text(Vector2(20, 32), stage_label, 18, Color.WHITE)
		_text(Vector2(220, 32), "GATE %d/%d" % [required_passed, int(stage["required_target"])], 16, Color("#d5f6ff"))
		_text(Vector2(350, 32), "SCORE %d" % score, 16, Color("#d5f6ff"))
		_text(Vector2(500, 32), "ALT %.0f" % model.position.y, 16, Color("#d5f6ff"))
		_text(Vector2(610, 32), "BOOST %.0f" % model.boost, 16, Color("#d5f6ff"))
		_text(Vector2(750, 32), "HP %.0f" % model.durability, 16, Color("#d5f6ff"))
		_text(Vector2(w - 260, 32), "WIND %s" % current_wind_label, 15, Color("#c7ecff"))
		draw_rect(Rect2(20, 55, w - 40, 9), Color("#24495d"), true)
		draw_rect(Rect2(20, 55, (w - 40) * progress, 9), Color("#58e0bb"), true)

func _draw_touch_controls() -> void:
	var w := size.x
	var h := size.y
	var radius := maxf(56.0, minf(w, h) * 0.095)
	var center := steer_origin if steer_touch_id >= 0 else Vector2(maxf(90.0, w * 0.14), h - maxf(100.0, h * 0.17))
	draw_circle(center, radius, Color(0.03, 0.17, 0.25, 0.30))
	draw_circle(center, radius, Color("#c9f4ff"), false, 2.0)
	var knob := center + Vector2(touch_steer.x, -touch_steer.y) * radius * 0.58
	draw_circle(knob, radius * 0.28, Color(0.40, 0.88, 1.0, 0.70))
	draw_circle(knob, radius * 0.28, Color.WHITE, false, 2.0)
	_button(boost_rect, "BOOST", Color("#e98134") if model.boost >= 5.0 else Color("#626d73"))
	_text(Vector2(18, h - 18), "WASD/矢印: 操舵  Space: BOOST  P: Pause", 12, Color(0.92, 1.0, 1.0, 0.72))

func _draw_tutorial() -> void:
	var w := size.x
	var h := size.y
	var messages := [
		"① 左側をドラッグして上下・奥行きを操作",
		"② 青い上昇気流に入り、高度とBOOSTを回復",
		"③ 必須ゲートを6つ以上通り、右下BOOSTも使おう"
	]
	var box := Rect2(w * 0.12, h * 0.16, w * 0.76, maxf(64.0, h * 0.10))
	draw_rect(box, Color(0.02, 0.10, 0.17, 0.88), true)
	draw_rect(box, Color("#d8f7ff"), false, 2.0)
	_text(Vector2(box.position.x + 18, box.position.y + box.size.y * 0.60), messages[tutorial_step], int(clampf(minf(w,h)*0.025, 14, 19)), Color.WHITE)

func _draw_result() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	var panel := Rect2(w * (0.06 if portrait else 0.17), h * 0.07, w * (0.88 if portrait else 0.66), h * 0.86)
	draw_rect(panel, Color(0.03, 0.15, 0.23, 0.94), true)
	draw_rect(panel, Color("#6af0c6") if result_clear else Color("#ff8d83"), false, 3.0)
	var headline := "CLEAR!" if result_clear else "FAILED"
	_text(Vector2(panel.position.x + 28, panel.position.y + 58), headline, 38, Color("#75f3cc") if result_clear else Color("#ff9b91"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 92), "STAGE %d  %s" % [selected_stage_id, str(stage["name"])], 17, Color("#d8f5ff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 123), result_reason, 15, Color("#d8f5ff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 164), "SCORE  %d" % score, 21, Color.WHITE)
	_text(Vector2(panel.position.x + 30, panel.position.y + 196), "TIME   %.1f s" % model.elapsed, 17, Color("#d8f5ff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 228), "GATE   %d/%d   BONUS %d" % [required_passed, int(stage["required_target"]), bonus_passed], 17, Color("#d8f5ff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 260), "HP     %.0f" % model.durability, 17, Color("#d8f5ff"))
	if result_clear:
		_text(Vector2(panel.position.x + 30, panel.position.y + 298), "MEDAL  %s%s" % [result_medal, "  NEW BEST!" if result_best else ""], 19, Color("#ffe28b"))
	_button(retry_rect, "RETRY  /  R", Color("#187868"))
	if result_clear and selected_stage_id < 3:
		_button(next_rect, "NEXT STAGE  /  Enter", Color("#147f91"))
	else:
		_button(next_rect, "ALL STAGES CLEAR" if result_clear else "CLEAR TO UNLOCK NEXT", Color("#4b6470"))
	_button(result_stage_select_rect, "STAGE SELECT", Color("#315f72"))
	_button(title_rect, "TITLE", Color("#355a70"))

func _draw_qa_overlay() -> void:
	if state != ScreenState.RUNNING:
		return
	var text_value := "QA | x %.1f | alt %.1f | z %.2f | boost %.1f | hp %.0f | gate %d | score %d" % [
		model.position.x, model.position.y, model.position.z, model.boost, model.durability, required_passed, score
	]
	var rect := Rect2(8, size.y - 42, minf(size.x - 16, 690.0), 28)
	draw_rect(rect, Color(0,0,0,0.72), true)
	_text(rect.position + Vector2(8, 20), text_value, 12, Color("#a7ffce"))

func _button(rect: Rect2, label: String, color: Color) -> void:
	var shadow := Rect2(rect.position + Vector2(0, 4), rect.size)
	draw_rect(shadow, Color(0.01, 0.06, 0.09, 0.42), true)
	draw_rect(rect, Color(color, 0.94), true)
	draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), Color(1, 1, 1, 0.08), false, 2.0)
	draw_rect(rect, Color("#e1f8ff"), false, 2.0)
	var fs := int(clampf(rect.size.y * 0.34, 14.0, 22.0))
	_text(rect.position + Vector2(16, rect.size.y * 0.62), label, fs, Color.WHITE)

func _text(pos: Vector2, value: String, fs: int, color: Color) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
