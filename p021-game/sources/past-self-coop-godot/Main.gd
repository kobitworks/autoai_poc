extends Control

const RECORD_SECONDS := 12.0
const PLAYER_SPEED := 190.0
const PLAYER_RADIUS := 18.0
const START_POS := Vector2(165, 330)
const SWITCH_A := Vector2(390, 270)
const SWITCH_B := Vector2(570, 390)
const GOAL_RECT := Rect2(820, 250, 90, 160)

enum Phase { RECORDING, REPLAYING, CLEAR }

var phase: Phase = Phase.RECORDING
var current_pos := START_POS
var ghost_pos := START_POS
var recorded_inputs: Array[Vector2] = []
var replay_index := 0
var record_elapsed := 0.0
var gate_unlocked := false
var touch_dir := Vector2.ZERO
var font: Font

var pad_up := Rect2(88, 474, 58, 58)
var pad_down := Rect2(88, 550, 58, 58)
var pad_left := Rect2(24, 512, 58, 58)
var pad_right := Rect2(152, 512, 58, 58)
var finish_rect := Rect2(730, 500, 180, 48)
var retry_rect := Rect2(730, 558, 180, 48)

func _ready() -> void:
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		font = load("res://fonts/NotoSansJP.ttf")
	else:
		font = ThemeDB.fallback_font
	set_process_input(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if phase == Phase.CLEAR:
		queue_redraw()
		return

	var dir := _read_direction()
	current_pos += dir * PLAYER_SPEED * delta
	current_pos.x = clamp(current_pos.x, 35.0, 920.0)
	current_pos.y = clamp(current_pos.y, 125.0, 465.0)

	if phase == Phase.RECORDING:
		recorded_inputs.append(dir)
		record_elapsed += delta
		if record_elapsed >= RECORD_SECONDS:
			_start_replay()
	elif phase == Phase.REPLAYING:
		if replay_index < recorded_inputs.size():
			ghost_pos += recorded_inputs[replay_index] * PLAYER_SPEED * delta
			ghost_pos.x = clamp(ghost_pos.x, 35.0, 920.0)
			ghost_pos.y = clamp(ghost_pos.y, 125.0, 465.0)
			replay_index += 1

	_update_switches_and_goal()
	queue_redraw()

func _read_direction() -> Vector2:
	var dir := touch_dir
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	return dir.normalized() if dir.length() > 1.0 else dir

func _start_replay() -> void:
	if recorded_inputs.is_empty():
		return
	phase = Phase.REPLAYING
	current_pos = START_POS
	ghost_pos = START_POS
	replay_index = 0
	touch_dir = Vector2.ZERO

func _retry() -> void:
	phase = Phase.RECORDING
	current_pos = START_POS
	ghost_pos = START_POS
	recorded_inputs.clear()
	replay_index = 0
	record_elapsed = 0.0
	gate_unlocked = false
	touch_dir = Vector2.ZERO
	queue_redraw()

func _update_switches_and_goal() -> void:
	var a_on := _is_on_switch(current_pos, SWITCH_A) or (phase != Phase.RECORDING and _is_on_switch(ghost_pos, SWITCH_A))
	var b_on := _is_on_switch(current_pos, SWITCH_B) or (phase != Phase.RECORDING and _is_on_switch(ghost_pos, SWITCH_B))
	if a_on and b_on:
		gate_unlocked = true
	if gate_unlocked and GOAL_RECT.has_point(current_pos):
		phase = Phase.CLEAR
		touch_dir = Vector2.ZERO

func _is_on_switch(pos: Vector2, sw: Vector2) -> bool:
	return pos.distance_to(sw) <= 32.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and phase == Phase.RECORDING:
			_start_replay()
		elif event.keycode == KEY_R:
			_retry()

	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_pointer_press(event.position)
		else:
			touch_dir = Vector2.ZERO

	if event is InputEventScreenDrag:
		_update_touch_direction(event.position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_pointer_press(event.position)
		else:
			touch_dir = Vector2.ZERO

func _handle_pointer_press(pos: Vector2) -> void:
	if finish_rect.has_point(pos) and phase == Phase.RECORDING:
		_start_replay()
		return
	if retry_rect.has_point(pos):
		_retry()
		return
	_update_touch_direction(pos)

func _update_touch_direction(pos: Vector2) -> void:
	if pad_up.has_point(pos):
		touch_dir = Vector2.UP
	elif pad_down.has_point(pos):
		touch_dir = Vector2.DOWN
	elif pad_left.has_point(pos):
		touch_dir = Vector2.LEFT
	elif pad_right.has_point(pos):
		touch_dir = Vector2.RIGHT
	else:
		touch_dir = Vector2.ZERO

func _draw() -> void:
	_draw_background()
	_draw_stage()
	_draw_hud()
	_draw_controls()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color("#0e1420"))
	draw_rect(Rect2(0, 0, 960, 96), Color("#152338"))
	draw_string(font, Vector2(32, 46), "GAME-G002  過去の自分と協力するゲーム", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#eaf7ff"))
	draw_string(font, Vector2(32, 76), "記録した自分を味方にして、2つのスイッチを同時に踏もう", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9fb8c9"))

func _draw_stage() -> void:
	draw_rect(Rect2(24, 116, 912, 360), Color("#182331"), true)
	draw_rect(Rect2(24, 116, 912, 360), Color("#344a60"), false, 2.0)

	_draw_switch(SWITCH_A, "A")
	_draw_switch(SWITCH_B, "B")

	var gate_color := Color("#3bd9a0") if gate_unlocked else Color("#ff7d7d")
	draw_rect(Rect2(755, 205, 18, 205), gate_color, true)
	draw_string(font, Vector2(710, 188), "出口ロック解除済み" if gate_unlocked else "出口ロック中", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gate_color)

	draw_rect(GOAL_RECT, Color(0.2, 0.9, 0.7, 0.15), true)
	draw_rect(GOAL_RECT, Color("#49e0ad"), false, 3.0)
	draw_string(font, Vector2(836, 335), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#8ff5d1"))

	_draw_player(current_pos, Color("#39bff8"), false)
	if phase != Phase.RECORDING:
		_draw_player(ghost_pos, Color(0.65, 0.45, 1.0, 0.55), true)

	if phase == Phase.RECORDING:
		draw_string(font, Vector2(300, 448), "まずAかBに移動し、そこで記録を終了", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#dbe9f4"))
	elif phase == Phase.REPLAYING and not gate_unlocked:
		draw_string(font, Vector2(278, 448), "過去の自分に片方を任せ、もう片方を踏もう", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#dbe9f4"))
	elif phase == Phase.REPLAYING:
		draw_string(font, Vector2(334, 448), "解除成功！ GOALへ進もう", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#7ff0c7"))

func _draw_player(pos: Vector2, color: Color, ghost: bool) -> void:
	draw_circle(pos, PLAYER_RADIUS + (4 if ghost else 0), Color(color, 0.18))
	draw_circle(pos, PLAYER_RADIUS, color)
	draw_circle(pos + Vector2(-6, -4), 2.5, Color("#071019"))
	draw_circle(pos + Vector2(6, -4), 2.5, Color("#071019"))
	draw_line(pos + Vector2(-7, 6), pos + Vector2(7, 6), Color("#071019"), 2.0)
	if ghost:
		draw_string(font, pos + Vector2(-24, -28), "PAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#decfff"))
	else:
		draw_string(font, pos + Vector2(-21, -28), "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b8edff"))

func _draw_switch(pos: Vector2, label: String) -> void:
	var active := _is_on_switch(current_pos, pos) or (phase != Phase.RECORDING and _is_on_switch(ghost_pos, pos))
	var c := Color("#ffd85d") if active else Color("#546478")
	draw_circle(pos, 32, Color(c, 0.18))
	draw_circle(pos, 25, c)
	draw_string(font, pos + Vector2(-6, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#111827"))

func _draw_hud() -> void:
	var phase_text := "REC 記録中"
	var phase_color := Color("#ff6b79")
	if phase == Phase.REPLAYING:
		phase_text = "REPLAY 協力中"
		phase_color = Color("#8b78ff")
	elif phase == Phase.CLEAR:
		phase_text = "CLEAR!"
		phase_color = Color("#4ee6ad")

	draw_rect(Rect2(660, 24, 268, 50), Color("#0d1725"), true)
	draw_string(font, Vector2(682, 55), phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, phase_color)

	if phase == Phase.RECORDING:
		var remain := max(0.0, RECORD_SECONDS - record_elapsed)
		draw_string(font, Vector2(515, 55), "残り %.1f 秒" % remain, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#f6d6da"))
		draw_rect(Rect2(515, 67, 125, 7), Color("#402833"), true)
		draw_rect(Rect2(515, 67, 125.0 * (remain / RECORD_SECONDS), 7), Color("#ff6b79"), true)

	if phase == Phase.CLEAR:
		draw_rect(Rect2(250, 210, 460, 170), Color(0.03, 0.08, 0.12, 0.94), true)
		draw_rect(Rect2(250, 210, 460, 170), Color("#49e0ad"), false, 3.0)
		draw_string(font, Vector2(390, 270), "ステージクリア！", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#7ff0c7"))
		draw_string(font, Vector2(330, 312), "過去の自分との協力に成功しました", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d9fff2"))
		draw_string(font, Vector2(382, 350), "R または リトライ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b9cbd8"))

func _draw_controls() -> void:
	_draw_button(pad_up, "↑", Color("#203349"))
	_draw_button(pad_down, "↓", Color("#203349"))
	_draw_button(pad_left, "←", Color("#203349"))
	_draw_button(pad_right, "→", Color("#203349"))
	_draw_button(finish_rect, "記録終了  Enter", Color("#7a3342") if phase == Phase.RECORDING else Color("#263340"))
	_draw_button(retry_rect, "リトライ  R", Color("#254a46"))

	draw_string(font, Vector2(245, 520), "PC: WASD / 矢印キー", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9fb8c9"))
	draw_string(font, Vector2(245, 548), "1回目の動きを記録し、2回目は過去の自分と同時に動きます", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9fb8c9"))
	draw_string(font, Vector2(245, 576), "ヒント: 片方のスイッチ上で記録を終えるのがコツ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c5d7e3"))

func _draw_button(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, Color("#5b7187"), false, 2.0)
	var size := 23 if label.length() <= 2 else 15
	draw_string(font, rect.position + Vector2(12, rect.size.y / 2 + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("#eff8ff"))
