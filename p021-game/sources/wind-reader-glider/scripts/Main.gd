extends Control

const FlightModelScript = preload("res://scripts/FlightModel.gd")
const StageDefinitionScript = preload("res://scripts/StageDefinition.gd")
const SaveManagerScript = preload("res://scripts/SaveManager.gd")

enum ScreenState { TITLE, RUNNING, RESULT }

var state: ScreenState = ScreenState.TITLE
var model: WindReaderFlightModel
var stage: Dictionary
var saves: WindReaderSaveManager
var font: Font
var qa_mode := false
var paused := false

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

var play_rect := Rect2()
var retry_rect := Rect2()
var title_rect := Rect2()
var sound_rect := Rect2()
var boost_rect := Rect2()

func _ready() -> void:
	stage = StageDefinitionScript.stage_1()
	model = FlightModelScript.new()
	model.reset(stage)
	saves = SaveManagerScript.new()
	saves.load_state()
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		font = load("res://fonts/NotoSansJP.ttf") as Font
	else:
		font = ThemeDB.fallback_font
	qa_mode = _detect_qa_mode()
	set_process_input(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		queue_redraw()

func _detect_qa_mode() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true))
	return false

func _start_run() -> void:
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
	queue_redraw()

func _physics_process(delta: float) -> void:
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
			else:
				bonus_passed += 1
				score += 1500
			score += mini(1000, 250 * maxi(0, combo - 1))
		else:
			combo = 0

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
		result_best = saves.record_stage_1(score, int(model.elapsed * 1000.0), result_medal)
	touch_steer = Vector2.ZERO
	steer_touch_id = -1
	boost_touch_id = -1
	mouse_boost = false
	queue_redraw()

func _medal_for_score(value: int) -> String:
	if value >= 13000:
		return "GOLD"
	if value >= 9000:
		return "SILVER"
	return "BRONZE"

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ENTER and state == ScreenState.TITLE:
				_start_run()
				return
			if key.keycode == KEY_R and state == ScreenState.RESULT:
				_start_run()
				return
			if key.keycode == KEY_M:
				saves.cycle_sfx()
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
				elif sound_rect.has_point(touch.position):
					saves.cycle_sfx()
					queue_redraw()
				return
			if state == ScreenState.RESULT:
				if retry_rect.has_point(touch.position):
					_start_run()
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
			elif sound_rect.has_point(mouse.position):
				saves.cycle_sfx()
				queue_redraw()
		elif state == ScreenState.RESULT and mouse.pressed:
			if retry_rect.has_point(mouse.position):
				_start_run()
			elif title_rect.has_point(mouse.position):
				state = ScreenState.TITLE
				queue_redraw()
		elif state == ScreenState.RUNNING:
			mouse_boost = mouse.pressed and boost_rect.has_point(mouse.position)

func _qa_advance() -> void:
	if state == ScreenState.TITLE:
		_start_run()
	elif state == ScreenState.RUNNING:
		required_passed = int(stage["required_target"])
		score = 9000
		model.position.x = float(stage["length"])
		_finish_run(true, "QA CLEAR")
	else:
		_start_run()

func _draw() -> void:
	_update_ui_rects()
	_draw_sky()
	if state == ScreenState.TITLE:
		_draw_title()
	elif state == ScreenState.RUNNING:
		_draw_running()
	else:
		_draw_result()
	if qa_mode:
		_draw_qa_overlay()

func _update_ui_rects() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	if portrait:
		play_rect = Rect2(w * 0.12, h * 0.64, w * 0.76, maxf(58.0, h * 0.075))
		sound_rect = Rect2(w * 0.22, h * 0.75, w * 0.56, maxf(48.0, h * 0.06))
		retry_rect = Rect2(w * 0.12, h * 0.68, w * 0.76, maxf(58.0, h * 0.07))
		title_rect = Rect2(w * 0.18, h * 0.79, w * 0.64, maxf(48.0, h * 0.06))
	else:
		play_rect = Rect2(w * 0.32, h * 0.62, w * 0.36, maxf(54.0, h * 0.09))
		sound_rect = Rect2(w * 0.39, h * 0.75, w * 0.22, maxf(42.0, h * 0.07))
		retry_rect = Rect2(w * 0.31, h * 0.67, w * 0.38, maxf(52.0, h * 0.085))
		title_rect = Rect2(w * 0.37, h * 0.80, w * 0.26, maxf(42.0, h * 0.07))
	boost_rect = Rect2(w - maxf(112.0, w * 0.14), h - maxf(122.0, h * 0.23), maxf(88.0, w * 0.10), maxf(88.0, w * 0.10))

func _draw_sky() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("#72c8ee"), true)
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), Color("#9cdb9a"), true)
	draw_rect(Rect2(0, h * 0.73, w, h * 0.27), Color("#4f9d68"), true)
	for i in range(9):
		var cx := fmod(float(i * 211) + model.position.x * (0.08 + i * 0.006), w + 220.0) - 110.0
		var cy := h * (0.12 + 0.045 * float(i % 4))
		draw_circle(Vector2(cx, cy), 34.0 + float((i * 7) % 24), Color(1, 1, 1, 0.42))

func _draw_title() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	var panel_w := w * (0.90 if portrait else 0.66)
	var panel_h := h * (0.68 if portrait else 0.72)
	var panel := Rect2((w - panel_w) * 0.5, h * 0.11, panel_w, panel_h)
	draw_rect(panel, Color(0.04, 0.16, 0.27, 0.91), true)
	draw_rect(panel, Color("#dff8ff"), false, 2.0)

	var title_size := int(clampf(w * (0.060 if portrait else 0.037), 26.0, 46.0))
	_text(Vector2(panel.position.x + 28, panel.position.y + 65), "風読みグライダー", title_size, Color("#ffffff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 105), "風をつかみ、ゲートを抜けてゴールへ", int(clampf(title_size * 0.48, 14, 20)), Color("#bceeff"))

	var body_size := int(clampf(minf(w, h) * 0.027, 14, 19))
	var lines := [
		"自動で前進。左側をドラッグして高度と奥行きを操作",
		"青い上昇気流で高度とBOOSTを回復",
		"右下BOOSTは速いがゲージを消費",
		"必須ゲート 6 / 8 以上でゴールするとCLEAR"
	]
	var yy := panel.position.y + 155
	for line in lines:
		_text(Vector2(panel.position.x + 32, yy), line, body_size, Color("#e5f7ff"))
		yy += body_size + 14

	_button(play_rect, "PLAY  /  Enter", Color("#137b90"))
	_button(sound_rect, "%s  /  M" % saves.sfx_label(), Color("#355a70"))
	if saves.best_score > 0:
		_text(Vector2(panel.position.x + 32, panel.end.y - 24), "BEST %d  %s" % [saves.best_score, saves.best_medal], 14, Color("#ffe28b"))

func _draw_running() -> void:
	_draw_course()
	_draw_hud()
	_draw_touch_controls()
	if tutorial_step < 3:
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
		var color := Color(0.25, 0.85, 1.0, 0.15) if str(zone["type"]) == "UPDRAFT" else Color(1.0, 0.85, 0.35, 0.12)
		draw_rect(Rect2(sx, h * 0.19, ex - sx, h * 0.57), color, true)
		var symbol := "↑" if str(zone["type"]) == "UPDRAFT" else ("→" if float(zone["direction"]) > 0.0 else "←")
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

func _draw_hud() -> void:
	var w := size.x
	var h := size.y
	var portrait := h > w
	var hud_h := 126.0 if portrait else 82.0
	draw_rect(Rect2(0, 0, w, hud_h), Color(0.02, 0.12, 0.20, 0.90), true)
	var progress := clampf(model.position.x / float(stage["length"]), 0.0, 1.0)
	if portrait:
		_text(Vector2(18, 30), "STAGE 1  朝凪の丘", 17, Color.WHITE)
		_text(Vector2(18, 59), "GATE %d/%d   SCORE %d   COMBO x%d" % [required_passed, int(stage["required_target"]), score, combo], 14, Color("#d5f6ff"))
		_text(Vector2(18, 87), "ALT %.0f   BOOST %.0f   HP %.0f   WIND %s" % [model.position.y, model.boost, model.durability, current_wind_label], 14, Color("#d5f6ff"))
		draw_rect(Rect2(18, 104, w - 36, 8), Color("#24495d"), true)
		draw_rect(Rect2(18, 104, (w - 36) * progress, 8), Color("#58e0bb"), true)
	else:
		_text(Vector2(20, 32), "STAGE 1  朝凪の丘", 18, Color.WHITE)
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
	var panel := Rect2(w * (0.08 if portrait else 0.24), h * 0.12, w * (0.84 if portrait else 0.52), h * 0.70)
	draw_rect(panel, Color(0.03, 0.15, 0.23, 0.94), true)
	draw_rect(panel, Color("#6af0c6") if result_clear else Color("#ff8d83"), false, 3.0)
	var headline := "CLEAR!" if result_clear else "FAILED"
	_text(Vector2(panel.position.x + 28, panel.position.y + 70), headline, 40, Color("#75f3cc") if result_clear else Color("#ff9b91"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 110), result_reason, 16, Color("#d8f5ff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 160), "SCORE  %d" % score, 22, Color.WHITE)
	_text(Vector2(panel.position.x + 30, panel.position.y + 196), "TIME   %.1f s" % model.elapsed, 18, Color("#d8f5ff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 230), "GATE   %d/%d   BONUS %d" % [required_passed, int(stage["required_target"]), bonus_passed], 18, Color("#d8f5ff"))
	_text(Vector2(panel.position.x + 30, panel.position.y + 264), "HP     %.0f" % model.durability, 18, Color("#d8f5ff"))
	if result_clear:
		_text(Vector2(panel.position.x + 30, panel.position.y + 310), "MEDAL  %s%s" % [result_medal, "  NEW BEST!" if result_best else ""], 20, Color("#ffe28b"))
	_button(retry_rect, "RETRY  /  R", Color("#187868"))
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
	draw_rect(rect, Color(color, 0.92), true)
	draw_rect(rect, Color("#e1f8ff"), false, 2.0)
	var fs := int(clampf(rect.size.y * 0.34, 14.0, 22.0))
	_text(rect.position + Vector2(16, rect.size.y * 0.62), label, fs, Color.WHITE)

func _text(pos: Vector2, value: String, fs: int, color: Color) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
