extends Control

const CoverGraphScript = preload("res://scripts/CoverGraph.gd")
const VisibilityModelScript = preload("res://scripts/VisibilityModel.gd")
const AlertModelScript = preload("res://scripts/AlertModel.gd")
const StageDefinitionScript = preload("res://scripts/StageDefinition.gd")
const SaveManagerScript = preload("res://scripts/SaveManager.gd")
const AudioManagerScript = preload("res://scripts/AudioManager.gd")

var graph
var alert_model
var save_manager
var audio_manager
var stage: Dictionary = {}
var lights: Array = []
var font: Font

var screen := "title"
var current_node := "N1"
var move_from := "N1"
var move_to := ""
var moving := false
var move_elapsed := 0.0
var move_duration := 0.6
var player_norm := Vector2(0.10, 0.82)

var stage_elapsed := 0.0
var time_left := 90.0
var score := 0
var combo := 0
var collected: Dictionary = {}
var result_rank := ""
var result_reason := ""
var result_score := 0
var best_updated := false
var danger_latched := false

var press_active := false
var press_started_ms := 0
var press_target := ""
var peek_active := false
var peek_text := ""

var qa_mode := false
var tutorial_timer := 12.0

func _ready() -> void:
	stage = StageDefinitionScript.stage_1()
	graph = CoverGraphScript.new()
	graph.configure(stage["nodes"], stage["edges"])
	alert_model = AlertModelScript.new()
	save_manager = SaveManagerScript.new()
	save_manager.load_state()
	audio_manager = AudioManagerScript.new()
	add_child(audio_manager)
	audio_manager.set_level(save_manager.volume_linear())
	var loaded_font = load("res://fonts/NotoSansJP.ttf")
	if loaded_font is Font:
		font = loaded_font as Font
	else:
		font = ThemeDB.fallback_font
	qa_mode = _detect_qa_mode()
	set_process(true)
	queue_redraw()

func _detect_qa_mode() -> bool:
	if not OS.has_feature("web"):
		return false
	var query = JavaScriptBridge.eval("window.location.search", true)
	return str(query).contains("qa=1")

func _process(delta: float) -> void:
	if screen != "playing":
		queue_redraw()
		return
	stage_elapsed += delta
	time_left = maxf(0.0, time_left - delta)
	_update_lights()
	if moving:
		move_elapsed += delta
		var t := clampf(move_elapsed / move_duration, 0.0, 1.0)
		var eased := t * t * (3.0 - 2.0 * t)
		var a: Vector2 = graph.node(move_from).get("position", Vector2.ZERO)
		var b: Vector2 = graph.node(move_to).get("position", Vector2.ZERO)
		player_norm = a.lerp(b, eased)
		if t >= 1.0:
			_complete_move()
	var visible := _player_visible()
	var old_state: String = str(alert_model.state())
	alert_model.update(delta, visible, moving, 1.0)
	var new_state: String = str(alert_model.state())
	if new_state == "DANGER" and old_state != "DANGER" and not danger_latched:
		danger_latched = true
		audio_manager.play_sfx("danger")
	if alert_model.value < 60.0:
		danger_latched = false
	if alert_model.spotted():
		audio_manager.play_sfx("spotted")
		_finish_stage(false, "SPOTTED")
	if time_left <= 0.0 and screen == "playing":
		_finish_stage(false, "TIME UP")
	if tutorial_timer > 0.0:
		tutorial_timer -= delta
	if press_active and not peek_active and Time.get_ticks_msec() - press_started_ms >= 450:
		peek_active = true
		peek_text = "様子見: %s / %s" % [_exposure_label(press_target), _peek_safety(press_target)]
		audio_manager.play_sfx("ui")
	queue_redraw()

func _update_lights() -> void:
	for i in range(lights.size()):
		var item: Dictionary = lights[i] as Dictionary
		var min_angle := float(item.get("min_angle", 0.0))
		var max_angle := float(item.get("max_angle", 0.0))
		var speed := float(item.get("speed", 0.7))
		var phase := float(item.get("phase", 0.0))
		var wave := (sin(stage_elapsed * speed + phase) + 1.0) * 0.5
		item["angle"] = lerpf(min_angle, max_angle, wave)
		lights[i] = item

func _start_game() -> void:
	screen = "playing"
	current_node = str(stage.get("start", "N1"))
	move_from = current_node
	move_to = ""
	moving = false
	var node_data: Dictionary = graph.node(current_node)
	player_norm = node_data.get("position", Vector2(0.10, 0.82))
	stage_elapsed = 0.0
	time_left = float(stage.get("time_limit", 90.0))
	score = 0
	combo = 0
	collected.clear()
	alert_model.reset()
	danger_latched = false
	tutorial_timer = 12.0 if not save_manager.tutorial_completed else 4.0
	lights = (stage.get("lights", []) as Array).duplicate(true)
	audio_manager.play_sfx("ui")
	queue_redraw()

func _start_move(target: String) -> void:
	if screen != "playing" or moving or not graph.can_move(current_node, target):
		return
	move_from = current_node
	move_to = target
	move_elapsed = 0.0
	move_duration = graph.edge_time(current_node, target)
	moving = true
	peek_active = false
	peek_text = ""
	audio_manager.play_sfx("move")

func _complete_move() -> void:
	moving = false
	current_node = move_to
	var node_data: Dictionary = graph.node(current_node)
	player_norm = node_data.get("position", player_norm)
	combo += 1
	score += mini(500, combo * 100)
	audio_manager.play_sfx("safe")
	var info_nodes: Array = stage.get("info", [])
	if info_nodes.has(current_node) and not collected.has(current_node):
		collected[current_node] = true
		score += 1200
		audio_manager.play_sfx("info")
	if current_node == str(stage.get("exit", "N9")):
		_finish_stage(true, "CLEAR")

func _finish_stage(clear: bool, reason: String) -> void:
	if screen != "playing":
		return
	screen = "result"
	result_reason = reason
	result_score = score
	result_rank = ""
	best_updated = false
	if clear:
		result_score += 5000
		if alert_model.peak < 35.0:
			result_score += 2000
		elif alert_model.peak < 70.0:
			result_score += 1000
		if alert_model.peak < 70.0:
			result_score += 500
		result_score += mini(2400, int(time_left) * 40)
		result_rank = _rank_for_clear()
		var elapsed_ms := int(stage_elapsed * 1000.0)
		best_updated = save_manager.record_stage(result_score, elapsed_ms, collected.size(), result_rank)
		save_manager.tutorial_completed = true
		save_manager.save_state()
		audio_manager.play_sfx("clear")
	else:
		audio_manager.play_sfx("fail")
	queue_redraw()

func _rank_for_clear() -> String:
	if collected.size() >= 2 and alert_model.peak < 70.0 and stage_elapsed <= float(stage.get("par_time", 65.0)):
		return "S"
	if collected.size() >= 2 and alert_model.peak < 100.0:
		return "A"
	if collected.size() >= 1:
		return "B"
	return "C"

func _game_rect() -> Rect2:
	var portrait := size.y > size.x
	if portrait:
		return Rect2(54.0, 250.0, maxf(300.0, size.x - 108.0), maxf(520.0, size.y - 610.0))
	return Rect2(34.0, 105.0, maxf(520.0, size.x - 68.0), maxf(400.0, size.y - 145.0))

func _node_screen(id: String) -> Vector2:
	var rect := _game_rect()
	var n: Dictionary = graph.node(id)
	var p: Vector2 = n.get("position", Vector2.ZERO)
	return rect.position + Vector2(p.x * rect.size.x, p.y * rect.size.y)

func _player_screen() -> Vector2:
	var rect := _game_rect()
	return rect.position + Vector2(player_norm.x * rect.size.x, player_norm.y * rect.size.y)

func _light_runtime(raw: Dictionary) -> Dictionary:
	var rect := _game_rect()
	var norm_origin: Vector2 = raw.get("origin", Vector2.ZERO)
	return {
		"origin": rect.position + Vector2(norm_origin.x * rect.size.x, norm_origin.y * rect.size.y),
		"angle": float(raw.get("angle", raw.get("min_angle", 0.0))),
		"half_fov": float(raw.get("half_fov", 0.25)),
		"range": minf(rect.size.x, rect.size.y) * float(raw.get("range", 0.65)),
		"intensity": float(raw.get("intensity", 1.0))
	}

func _occluders(player: Vector2) -> Array:
	var out: Array = []
	var radius := maxf(28.0, minf(_game_rect().size.x, _game_rect().size.y) * 0.045)
	for raw in stage.get("nodes", []):
		var item: Dictionary = raw as Dictionary
		var id := str(item.get("id", ""))
		var center := _node_screen(id)
		if player.distance_to(center) < radius * 1.2:
			continue
		out.append({"center": center, "radius": radius * 0.72})
	return out

func _player_visible() -> bool:
	if not moving:
		return false
	var player := _player_screen()
	var blockers := _occluders(player)
	for raw in lights:
		var light := _light_runtime(raw as Dictionary)
		if VisibilityModelScript.is_visible(
			light["origin"],
			float(light["angle"]),
			float(light["half_fov"]),
			float(light["range"]),
			player,
			blockers
		):
			return true
	return false

func _target_at(position: Vector2) -> String:
	var hit_radius := 92.0 if size.y > size.x else 62.0
	for id in graph.neighbors(current_node):
		if position.distance_to(_node_screen(str(id))) <= hit_radius:
			return str(id)
	return ""

func _exposure_label(target: String) -> String:
	var travel: float = float(graph.edge_time(current_node, target))
	if travel >= 0.75:
		return "危険度 HIGH"
	if travel >= 0.62:
		return "危険度 MID"
	return "危険度 LOW"

func _peek_safety(target: String) -> String:
	var target_pos := _node_screen(target)
	for raw in lights:
		var light := _light_runtime(raw as Dictionary)
		if VisibilityModelScript.in_cone(
			light["origin"],
			float(light["angle"]),
			float(light["half_fov"]),
			float(light["range"]),
			target_pos
		):
			return "まもなく危険"
	return "今なら安全"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pointer_down(touch.position)
		else:
			_pointer_up(touch.position)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_pointer_down(mouse.position)
			else:
				_pointer_up(mouse.position)

func _pointer_down(position: Vector2) -> void:
	if screen == "title":
		if _play_rect().has_point(position):
			_start_game()
		elif _sound_rect().has_point(position):
			save_manager.cycle_sfx()
			audio_manager.set_level(save_manager.volume_linear())
			audio_manager.play_sfx("ui")
		return
	if screen == "result":
		if _retry_rect().has_point(position):
			_start_game()
		elif _title_rect().has_point(position):
			screen = "title"
			queue_redraw()
		return
	if screen != "playing" or moving:
		return
	var target := _target_at(position)
	if target == "":
		return
	press_active = true
	press_started_ms = Time.get_ticks_msec()
	press_target = target
	peek_active = false
	peek_text = ""

func _pointer_up(_position: Vector2) -> void:
	if not press_active:
		return
	var elapsed := Time.get_ticks_msec() - press_started_ms
	var target := press_target
	press_active = false
	press_target = ""
	if elapsed < 450 and not peek_active:
		_start_move(target)
	peek_active = false
	peek_text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		var key = key_event.keycode
		if qa_mode and key == KEY_F9:
			if screen == "title":
				_start_game()
			elif screen == "playing":
				_finish_stage(true, "QA CLEAR")
			elif screen == "result":
				_start_game()
			get_viewport().set_input_as_handled()
			return
		if qa_mode and key == KEY_F8 and screen == "playing":
			alert_model.value = 72.0
			alert_model.peak = maxf(alert_model.peak, 72.0)
			get_viewport().set_input_as_handled()
			return
		if screen == "result" and key == KEY_R:
			_start_game()
			return
		if screen == "title" and (key == KEY_ENTER or key == KEY_SPACE):
			_start_game()
			return
		if screen == "playing" and not moving:
			_keyboard_move(key)

func _keyboard_move(key) -> void:
	var direction := Vector2.ZERO
	if key == KEY_LEFT or key == KEY_A:
		direction = Vector2.LEFT
	elif key == KEY_RIGHT or key == KEY_D:
		direction = Vector2.RIGHT
	elif key == KEY_UP or key == KEY_W:
		direction = Vector2.UP
	elif key == KEY_DOWN or key == KEY_S:
		direction = Vector2.DOWN
	else:
		return
	var origin := _node_screen(current_node)
	var best := ""
	var best_dot := 0.35
	for id in graph.neighbors(current_node):
		var delta := (_node_screen(str(id)) - origin).normalized()
		var dot := delta.dot(direction)
		if dot > best_dot:
			best_dot = dot
			best = str(id)
	if best != "":
		_start_move(best)

func _play_rect() -> Rect2:
	var h := 160.0 if size.y > size.x else 82.0
	var w := minf(size.x * 0.68, 560.0)
	return Rect2((size.x - w) * 0.5, size.y * 0.66, w, h)

func _sound_rect() -> Rect2:
	var h := 130.0 if size.y > size.x else 72.0
	var w := minf(size.x * 0.54, 430.0)
	return Rect2((size.x - w) * 0.5, size.y * 0.82, w, h)

func _retry_rect() -> Rect2:
	var h := 150.0 if size.y > size.x else 78.0
	var w := minf(size.x * 0.62, 500.0)
	return Rect2((size.x - w) * 0.5, size.y * 0.62, w, h)

func _title_rect() -> Rect2:
	var h := 130.0 if size.y > size.x else 72.0
	var w := minf(size.x * 0.52, 430.0)
	return Rect2((size.x - w) * 0.5, size.y * 0.80, w, h)

func _font_size(landscape: int, portrait: int) -> int:
	return portrait if size.y > size.x else landscape

func _text(text: String, position: Vector2, width: float, size_px: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, position, text, align, width, size_px, color)

func _draw_button(rect: Rect2, label: String, accent := Color(0.16, 0.85, 0.92, 1.0)) -> void:
	draw_rect(rect, accent)
	draw_rect(Rect2(rect.position + Vector2(7, 7), rect.size - Vector2(14, 14)), Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 1.0), false, 3.0)
	_text(label, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.64), rect.size.x, _font_size(25, 42), Color(0.02, 0.07, 0.10), HORIZONTAL_ALIGNMENT_CENTER)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.04, 0.075))
	if screen == "title":
		_draw_title()
	elif screen == "playing":
		_draw_play()
	else:
		_draw_result()

func _draw_title() -> void:
	var fs_title := _font_size(48, 72)
	var fs_body := _font_size(24, 40)
	var center_y := size.y * 0.27
	draw_circle(Vector2(size.x * 0.5, center_y), minf(size.x, size.y) * 0.18, Color(0.04, 0.16, 0.24))
	for i in range(6):
		var y := center_y - 120.0 + float(i) * 48.0
		draw_line(Vector2(size.x * 0.20, y), Vector2(size.x * 0.80, y + 60.0), Color(0.12, 0.72, 0.82, 0.10), 18.0)
	_text("GAME-G008", Vector2(size.x * 0.12, size.y * 0.12), size.x * 0.76, fs_body, Color(0.28, 0.88, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	_text("影渡りステルス", Vector2(size.x * 0.08, size.y * 0.37), size.x * 0.84, fs_title, Color(0.92, 0.98, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_text("光を避け、影から影へ。", Vector2(size.x * 0.08, size.y * 0.47), size.x * 0.84, fs_body, Color(0.65, 0.78, 0.86), HORIZONTAL_ALIGNMENT_CENTER)
	_text("タップ: 移動 / 長押し: 様子見", Vector2(size.x * 0.08, size.y * 0.55), size.x * 0.84, fs_body, Color(0.56, 0.67, 0.76), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_button(_play_rect(), "PLAY")
	_draw_button(_sound_rect(), save_manager.sfx_label(), Color(0.70, 0.78, 0.86))

func _draw_play() -> void:
	var rect := _game_rect()
	draw_rect(rect, Color(0.035, 0.075, 0.11))
	for i in range(9):
		var x := rect.position.x + rect.size.x * float(i) / 8.0
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.14, 0.30, 0.38, 0.20), 2.0)
	for j in range(7):
		var y := rect.position.y + rect.size.y * float(j) / 6.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.14, 0.30, 0.38, 0.16), 2.0)
	_draw_lights()
	_draw_edges()
	_draw_nodes()
	var player := _player_screen()
	draw_circle(player + Vector2(12, 14), 30.0, Color(0, 0, 0, 0.35))
	draw_circle(player, 26.0, Color(0.72, 0.96, 1.0))
	draw_circle(player, 12.0, Color(0.08, 0.23, 0.30))
	_draw_hud()
	if tutorial_timer > 0.0:
		var tutorial_h := 120.0 if size.y <= size.x else 230.0
		var box := Rect2(rect.position.x + rect.size.x * 0.08, rect.position.y + rect.size.y * 0.05, rect.size.x * 0.84, tutorial_h)
		draw_rect(box, Color(0.02, 0.05, 0.08, 0.90))
		var fs := _font_size(21, 34)
		_text("影から影へタップ → 光でAlert上昇 → EXITへ", Vector2(box.position.x + 20, box.position.y + fs * 1.8), box.size.x - 40, fs, Color(0.86, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		_text("情報片は任意。危険だが高得点。", Vector2(box.position.x + 20, box.position.y + fs * 3.4), box.size.x - 40, fs, Color(0.30, 0.90, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	if peek_active:
		var peek_h := 70.0 if size.y <= size.x else 130.0
		var box := Rect2(rect.position.x + rect.size.x * 0.12, rect.end.y - peek_h - 12.0, rect.size.x * 0.76, peek_h)
		draw_rect(box, Color(0.03, 0.12, 0.18, 0.95))
		_text(peek_text, Vector2(box.position.x, box.position.y + box.size.y * 0.64), box.size.x, _font_size(20, 34), Color(0.80, 0.98, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	if qa_mode:
		_text("QA | node=%s alert=%.1f moving=%s" % [current_node, alert_model.value, str(moving)], Vector2(rect.position.x + 16, rect.end.y - 18), rect.size.x - 32, _font_size(15, 26), Color(0.52, 1.0, 0.65))

func _draw_hud() -> void:
	var portrait := size.y > size.x
	var fs := _font_size(22, 36)
	var alert_state: String = str(alert_model.state())
	var state_color := Color(0.30, 0.92, 0.72)
	if alert_state == "SUSPICIOUS":
		state_color = Color(1.0, 0.78, 0.24)
	elif alert_state == "DANGER" or alert_state == "SPOTTED":
		state_color = Color(1.0, 0.28, 0.32)
	var bar_h := 84.0 if portrait else 64.0
	draw_rect(Rect2(0, 0, size.x, bar_h), Color(0.02, 0.07, 0.10, 0.98))
	_text("STAGE 1  薄明の資料庫", Vector2(22, bar_h * 0.63), size.x * 0.34, fs, Color(0.86, 0.96, 1.0))
	_text("TIME %02d" % int(ceil(time_left)), Vector2(size.x * 0.35, bar_h * 0.63), size.x * 0.18, fs, Color(0.94, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_text("INFO %d/2" % collected.size(), Vector2(size.x * 0.53, bar_h * 0.63), size.x * 0.17, fs, Color(0.30, 0.90, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	_text("%s %02d" % [alert_state, int(alert_model.value)], Vector2(size.x * 0.70, bar_h * 0.63), size.x * 0.28, fs, state_color, HORIZONTAL_ALIGNMENT_RIGHT)
	var meter := Rect2(size.x * 0.70, bar_h - 12.0, size.x * 0.28, 6.0)
	draw_rect(meter, Color(0.12, 0.18, 0.22))
	draw_rect(Rect2(meter.position, Vector2(meter.size.x * alert_model.value / 100.0, meter.size.y)), state_color)

func _draw_edges() -> void:
	for raw in stage.get("edges", []):
		var edge: Dictionary = raw as Dictionary
		var a := _node_screen(str(edge.get("from", "")))
		var b := _node_screen(str(edge.get("to", "")))
		draw_line(a, b, Color(0.18, 0.42, 0.48, 0.52), 8.0, true)

func _draw_nodes() -> void:
	var neighbors: Array = graph.neighbors(current_node)
	for raw in stage.get("nodes", []):
		var item: Dictionary = raw as Dictionary
		var id := str(item.get("id", ""))
		var p := _node_screen(id)
		var is_neighbor: bool = neighbors.has(id) and not moving
		var node_color := Color(0.10, 0.19, 0.23)
		if id == current_node and not moving:
			node_color = Color(0.12, 0.38, 0.42)
		if is_neighbor:
			draw_circle(p, 74.0 if size.y > size.x else 48.0, Color(0.18, 0.92, 0.92, 0.16))
		draw_circle(p, 46.0 if size.y > size.x else 30.0, node_color)
		draw_circle(p + Vector2(12, 16), 38.0 if size.y > size.x else 24.0, Color(0, 0, 0, 0.38))
		var info_nodes: Array = stage.get("info", [])
		if info_nodes.has(id) and not collected.has(id):
			draw_circle(p, 15.0, Color(0.25, 0.95, 1.0))
			_text("i", Vector2(p.x - 20, p.y + 10), 40, _font_size(18, 30), Color(0.02, 0.10, 0.14), HORIZONTAL_ALIGNMENT_CENTER)
		if id == str(stage.get("exit", "N9")):
			draw_arc(p, 58.0 if size.y > size.x else 40.0, 0, TAU, 24, Color(0.30, 1.0, 0.60), 8.0)
			_text("EXIT", Vector2(p.x - 70, p.y - 55), 140, _font_size(15, 26), Color(0.45, 1.0, 0.68), HORIZONTAL_ALIGNMENT_CENTER)

func _draw_lights() -> void:
	for raw in lights:
		var light := _light_runtime(raw as Dictionary)
		var origin: Vector2 = light["origin"]
		var angle := float(light["angle"])
		var half_fov := float(light["half_fov"])
		var range_px := float(light["range"])
		var p1 := origin + Vector2.RIGHT.rotated(angle - half_fov) * range_px
		var p2 := origin + Vector2.RIGHT.rotated(angle + half_fov) * range_px
		draw_colored_polygon(PackedVector2Array([origin, p1, p2]), Color(1.0, 0.86, 0.30, 0.16))
		draw_line(origin, p1, Color(1.0, 0.87, 0.36, 0.45), 4.0, true)
		draw_line(origin, p2, Color(1.0, 0.87, 0.36, 0.45), 4.0, true)
		draw_circle(origin, 16.0, Color(1.0, 0.80, 0.25))

func _draw_result() -> void:
	var clear := result_rank != ""
	var fs_title := _font_size(48, 72)
	var fs := _font_size(24, 40)
	var title := "CLEAR" if clear else result_reason
	var title_color := Color(0.35, 1.0, 0.72) if clear else Color(1.0, 0.32, 0.38)
	_text(title, Vector2(size.x * 0.10, size.y * 0.22), size.x * 0.80, fs_title, title_color, HORIZONTAL_ALIGNMENT_CENTER)
	if clear:
		_text("RANK %s" % result_rank, Vector2(size.x * 0.10, size.y * 0.34), size.x * 0.80, fs_title, Color(0.86, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_text("SCORE %d" % result_score, Vector2(size.x * 0.10, size.y * 0.45), size.x * 0.80, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_text("INFO %d/2 / ALERT PEAK %d" % [collected.size(), int(alert_model.peak)], Vector2(size.x * 0.10, size.y * 0.52), size.x * 0.80, fs, Color(0.65, 0.78, 0.86), HORIZONTAL_ALIGNMENT_CENTER)
	if best_updated:
		_text("BEST UPDATED", Vector2(size.x * 0.10, size.y * 0.57), size.x * 0.80, fs, Color(0.30, 0.90, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_button(_retry_rect(), "RETRY")
	_draw_button(_title_rect(), "TITLE", Color(0.70, 0.78, 0.86))
