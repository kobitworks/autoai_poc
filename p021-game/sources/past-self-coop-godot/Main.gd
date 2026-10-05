extends Control

const PLAYER_SPEED := 205.0
const PLAYER_RADIUS := 18.0
const START_POS := Vector2(155, 330)
const START_RECT := Rect2(330, 432, 300, 62)
const NEXT_RECT := Rect2(330, 422, 300, 58)

const STAGES := [
	{
		"name": "STAGE 1  同時押し",
		"record": 11.0,
		"a": Vector2(390, 270),
		"b": Vector2(565, 390),
		"goal": Rect2(820, 250, 90, 160),
		"hint": "片方のスイッチ上で記録を終え、もう片方をNOWで踏もう"
	},
	{
		"name": "STAGE 2  時差協力",
		"record": 9.0,
		"a": Vector2(335, 405),
		"b": Vector2(650, 245),
		"goal": Rect2(820, 205, 90, 120),
		"hint": "PASTが遠いスイッチへ向かう時間を逆算しよう"
	},
	{
		"name": "STAGE 3  最終同期",
		"record": 8.0,
		"a": Vector2(455, 220),
		"b": Vector2(655, 405),
		"goal": Rect2(805, 300, 105, 120),
		"hint": "短い記録時間で経路を作り、解除後すぐGOALへ"
	}
]

enum Phase { RECORDING, REPLAYING, CLEAR, COMPLETE }

var phase: Phase = Phase.RECORDING
var stage_index := 0
var current_pos := START_POS
var ghost_pos := START_POS
var recorded_inputs: Array[Vector2] = []
var replay_index := 0
var record_elapsed := 0.0
var gate_unlocked := false
var touch_dir := Vector2.ZERO
var font: Font
var show_intro := true
var pulse := 0.0
var unlocked_flash := 0.0

var switch_a := Vector2.ZERO
var switch_b := Vector2.ZERO
var goal_rect := Rect2()
var record_seconds := 10.0
var stage_hint := ""

var ui_panel: Texture2D
var ui_button: Texture2D
var ui_icon: Texture2D
var audio_player: AudioStreamPlayer

var pad_up := Rect2(88, 474, 58, 58)
var pad_down := Rect2(88, 550, 58, 58)
var pad_left := Rect2(24, 512, 58, 58)
var pad_right := Rect2(152, 512, 58, 58)
var finish_rect := Rect2(730, 500, 180, 48)
var retry_rect := Rect2(730, 558, 180, 48)

func _ready() -> void:
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		font = load("res://fonts/NotoSansJP.ttf") as Font
	else:
		font = ThemeDB.fallback_font
	ui_panel = _load_texture("res://assets/kenney/ui_panel.png")
	ui_button = _load_texture("res://assets/kenney/ui_button.png")
	ui_icon = _load_texture("res://assets/kenney/ui_icon.png")
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	_apply_stage(0)
	set_process_input(true)
	queue_redraw()

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _physics_process(delta: float) -> void:
	pulse += delta
	unlocked_flash = maxf(0.0, unlocked_flash - delta)
	if show_intro or phase == Phase.CLEAR or phase == Phase.COMPLETE:
		queue_redraw()
		return

	var dir: Vector2 = _read_direction()
	current_pos += dir * PLAYER_SPEED * delta
	current_pos.x = clampf(current_pos.x, 42.0, 915.0)
	current_pos.y = clampf(current_pos.y, 135.0, 462.0)

	if phase == Phase.RECORDING:
		recorded_inputs.append(dir)
		record_elapsed += delta
		if record_elapsed >= record_seconds:
			_start_replay()
	elif phase == Phase.REPLAYING:
		if replay_index < recorded_inputs.size():
			ghost_pos += recorded_inputs[replay_index] * PLAYER_SPEED * delta
			ghost_pos.x = clampf(ghost_pos.x, 42.0, 915.0)
			ghost_pos.y = clampf(ghost_pos.y, 135.0, 462.0)
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

func _apply_stage(index: int) -> void:
	stage_index = index
	var data: Dictionary = STAGES[stage_index]
	switch_a = data["a"] as Vector2
	switch_b = data["b"] as Vector2
	goal_rect = data["goal"] as Rect2
	record_seconds = float(data["record"])
	stage_hint = str(data["hint"])
	_reset_stage_state()

func _reset_stage_state() -> void:
	phase = Phase.RECORDING
	current_pos = START_POS
	ghost_pos = START_POS
	recorded_inputs.clear()
	replay_index = 0
	record_elapsed = 0.0
	gate_unlocked = false
	touch_dir = Vector2.ZERO
	queue_redraw()

func _start_replay() -> void:
	if recorded_inputs.is_empty():
		return
	phase = Phase.REPLAYING
	current_pos = START_POS
	ghost_pos = START_POS
	replay_index = 0
	touch_dir = Vector2.ZERO
	_play_sfx(1)

func _retry() -> void:
	_reset_stage_state()
	_play_sfx(0)

func _update_switches_and_goal() -> void:
	var a_on: bool = _is_on_switch(current_pos, switch_a) or (phase != Phase.RECORDING and _is_on_switch(ghost_pos, switch_a))
	var b_on: bool = _is_on_switch(current_pos, switch_b) or (phase != Phase.RECORDING and _is_on_switch(ghost_pos, switch_b))
	if a_on and b_on and not gate_unlocked:
		gate_unlocked = true
		unlocked_flash = 1.0
		_play_sfx(2)
	if gate_unlocked and goal_rect.has_point(current_pos):
		phase = Phase.CLEAR
		touch_dir = Vector2.ZERO
		_play_sfx(3)

func _is_on_switch(pos: Vector2, sw: Vector2) -> bool:
	return pos.distance_to(sw) <= 34.0

func _play_sfx(slot: int) -> void:
	var base := "res://assets/kenney/sfx_%d" % slot
	for ext in ["ogg", "wav", "mp3"]:
		var path := "%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			audio_player.stream = load(path) as AudioStream
			audio_player.play()
			return

func _input(event: InputEvent) -> void:
	if show_intro:
		var start_now := false
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			start_now = key_event.pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE)
		elif event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			start_now = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and START_RECT.has_point(mouse_event.position)
		elif event is InputEventScreenTouch:
			var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
			start_now = touch_event.pressed and START_RECT.has_point(touch_event.position)
		if start_now:
			show_intro = false
			_play_sfx(0)
			queue_redraw()
		return

	if phase == Phase.CLEAR:
		var advance := false
		if event is InputEventKey:
			var clear_key: InputEventKey = event as InputEventKey
			advance = clear_key.pressed and (clear_key.keycode == KEY_ENTER or clear_key.keycode == KEY_SPACE)
		elif event is InputEventMouseButton:
			var clear_mouse: InputEventMouseButton = event as InputEventMouseButton
			advance = clear_mouse.pressed and NEXT_RECT.has_point(clear_mouse.position)
		elif event is InputEventScreenTouch:
			var clear_touch: InputEventScreenTouch = event as InputEventScreenTouch
			advance = clear_touch.pressed and NEXT_RECT.has_point(clear_touch.position)
		if advance:
			if stage_index < STAGES.size() - 1:
				_apply_stage(stage_index + 1)
			else:
				phase = Phase.COMPLETE
			return

	if phase == Phase.COMPLETE:
		if event is InputEventKey:
			var final_key: InputEventKey = event as InputEventKey
			if final_key.pressed and final_key.keycode == KEY_R:
				_apply_stage(0)
				show_intro = true
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed:
			if key_event.keycode == KEY_ENTER and phase == Phase.RECORDING:
				_start_replay()
			elif key_event.keycode == KEY_R:
				_retry()

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_pointer_press(touch_event.position)
		else:
			touch_dir = Vector2.ZERO

	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		_update_touch_direction(drag_event.position)

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_handle_pointer_press(mouse_event.position)
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
	if show_intro:
		_draw_intro()
	elif phase == Phase.CLEAR:
		_draw_clear()
	elif phase == Phase.COMPLETE:
		_draw_complete()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color("#07111d"))
	for i in range(14):
		var x := float(i * 79 % 960)
		var y := 105.0 + float((i * 137) % 370)
		var alpha := 0.10 + 0.05 * sin(pulse * 1.5 + float(i))
		draw_circle(Vector2(x, y), 1.8, Color(0.35, 0.75, 1.0, alpha))
	draw_rect(Rect2(0, 0, 960, 96), Color("#101f33"))
	draw_rect(Rect2(0, 92, 960, 4), Color("#4bc4e8"))
	draw_string(font, Vector2(30, 44), "PAST//SYNC", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("#f1fbff"))
	draw_string(font, Vector2(30, 74), "過去の自分と協力するゲーム", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9fcadd"))
	if ui_icon != null:
		draw_texture_rect(ui_icon, Rect2(886, 24, 42, 42), false)

func _draw_stage() -> void:
	var room := Rect2(24, 116, 912, 360)
	draw_rect(room, Color("#101b2a"), true)
	for x in range(44, 930, 48):
		draw_line(Vector2(x, 120), Vector2(x, 474), Color(0.20, 0.45, 0.58, 0.10), 1.0)
	for y in range(132, 470, 48):
		draw_line(Vector2(28, y), Vector2(932, y), Color(0.20, 0.45, 0.58, 0.10), 1.0)
	draw_rect(room, Color("#37566c"), false, 2.0)

	if ui_panel != null:
		draw_texture_rect(ui_panel, Rect2(32, 126, 126, 44), false)
		draw_texture_rect(ui_panel, Rect2(782, 126, 140, 44), false)

	_draw_switch(switch_a, "A")
	_draw_switch(switch_b, "B")

	var gate_color := Color("#42efb3") if gate_unlocked else Color("#ff6e86")
	draw_rect(Rect2(755, 205, 18, 205), Color(gate_color, 0.30), true)
	for y in range(212, 406, 28):
		draw_rect(Rect2(757, y, 14, 14), gate_color, true)
	draw_string(font, Vector2(708, 190), "UNLOCKED" if gate_unlocked else "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gate_color)

	var glow := 0.14 + 0.06 * sin(pulse * 3.0)
	draw_rect(goal_rect, Color(0.15, 1.0, 0.72, glow), true)
	draw_rect(goal_rect, Color("#57eeb7"), false, 3.0)
	draw_string(font, goal_rect.position + Vector2(18, goal_rect.size.y * 0.55), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#b4ffe5"))

	_draw_player(current_pos, Color("#37c8ff"), false)
	if phase != Phase.RECORDING:
		_draw_player(ghost_pos, Color(0.67, 0.48, 1.0, 0.62), true)

	if unlocked_flash > 0.0:
		draw_rect(room, Color(0.25, 1.0, 0.72, unlocked_flash * 0.13), true)

func _draw_player(pos: Vector2, color: Color, ghost: bool) -> void:
	var aura := PLAYER_RADIUS + 8.0 + sin(pulse * 4.0) * 2.5
	draw_circle(pos, aura, Color(color, 0.14 if not ghost else 0.10))
	draw_circle(pos, PLAYER_RADIUS, color)
	draw_rect(Rect2(pos + Vector2(-9, -7), Vector2(18, 14)), Color("#07111d"), true)
	draw_circle(pos + Vector2(-5, 0), 2.5, Color("#eafaff"))
	draw_circle(pos + Vector2(5, 0), 2.5, Color("#eafaff"))
	draw_string(font, pos + Vector2(-24, -29), "PAST" if ghost else "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#dccfff") if ghost else Color("#b8f0ff"))
	if ghost:
		for i in range(4):
			var trail_pos := pos - Vector2(float(i + 1) * 13.0, 0)
			draw_circle(trail_pos, 8.0 - float(i), Color(color, 0.10))

func _draw_switch(pos: Vector2, label: String) -> void:
	var active: bool = _is_on_switch(current_pos, pos) or (phase != Phase.RECORDING and _is_on_switch(ghost_pos, pos))
	var c := Color("#ffd456") if active else Color("#597184")
	draw_circle(pos, 36.0 + sin(pulse * 3.5) * 2.0, Color(c, 0.12))
	draw_circle(pos, 27, c)
	draw_circle(pos, 18, Color("#14202d"))
	draw_string(font, pos + Vector2(-6, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f5fbff"))

func _draw_hud() -> void:
	var data: Dictionary = STAGES[stage_index]
	draw_string(font, Vector2(350, 44), str(data["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#d9f7ff"))
	draw_string(font, Vector2(350, 72), "STAGE %d / %d" % [stage_index + 1, STAGES.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#79a9be"))

	var phase_text := "REC  記録中"
	var phase_color := Color("#ff6b83")
	if phase == Phase.REPLAYING:
		phase_text = "SYNC  協力中"
		phase_color = Color("#a084ff")
	elif phase == Phase.CLEAR:
		phase_text = "CLEAR"
		phase_color = Color("#54efb5")
	elif phase == Phase.COMPLETE:
		phase_text = "COMPLETE"
		phase_color = Color("#54efb5")

	draw_rect(Rect2(700, 22, 220, 56), Color("#071423"), true)
	draw_rect(Rect2(700, 22, 220, 56), phase_color, false, 2.0)
	draw_string(font, Vector2(720, 56), phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, phase_color)

	if phase == Phase.RECORDING:
		var remain: float = maxf(0.0, record_seconds - record_elapsed)
		draw_string(font, Vector2(555, 52), "%.1fs" % remain, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffd7dd"))
		draw_rect(Rect2(555, 64, 120, 7), Color("#39222b"), true)
		draw_rect(Rect2(555, 64, 120.0 * (remain / record_seconds), 7), Color("#ff6b83"), true)

func _draw_controls() -> void:
	_draw_button(pad_up, "↑", Color("#163047"))
	_draw_button(pad_down, "↓", Color("#163047"))
	_draw_button(pad_left, "←", Color("#163047"))
	_draw_button(pad_right, "→", Color("#163047"))
	_draw_button(finish_rect, "記録終了  Enter", Color("#7e3146") if phase == Phase.RECORDING else Color("#223445"))
	_draw_button(retry_rect, "リトライ  R", Color("#1b5149"))
	draw_string(font, Vector2(245, 516), "WASD / 矢印キーで移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9fc5d7"))
	draw_string(font, Vector2(245, 544), stage_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d2e7f0"))
	draw_string(font, Vector2(245, 572), "RECで経路を記録 → SYNCでPASTと同時に動く", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8faec0"))
	draw_string(font, Vector2(245, 600), "Art/UI/SFX: Kenney CC0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#607f91"))

func _draw_button(rect: Rect2, label: String, color: Color) -> void:
	if ui_button != null:
		draw_texture_rect(ui_button, rect, false)
		draw_rect(rect, Color(color, 0.32), true)
	else:
		draw_rect(rect, color, true)
	draw_rect(rect, Color("#5f879b"), false, 2.0)
	var size := 23 if label.length() <= 2 else 15
	draw_string(font, rect.position + Vector2(12, rect.size.y / 2 + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("#effbff"))

func _draw_intro() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.02, 0.05, 0.08, 0.91), true)
	var box := Rect2(190, 130, 580, 385)
	draw_rect(box, Color("#0c1a29"), true)
	draw_rect(box, Color("#48ccea"), false, 2.0)
	draw_string(font, Vector2(318, 190), "PAST//SYNC", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#ecfbff"))
	draw_string(font, Vector2(276, 230), "過去の自分と協力するゲーム", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#bfefff"))
	draw_string(font, Vector2(257, 286), "1回目の動きを記録し、その動きをPASTとして再生。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b4cbd7"))
	draw_string(font, Vector2(235, 316), "NOWとPASTで2つのスイッチを同時に踏み、出口を開けよう。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b4cbd7"))
	draw_string(font, Vector2(300, 360), "全3ステージ  /  記録時間は徐々に短くなる", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8faec0"))
	_draw_button(START_RECT, "同期実験を開始  Enter", Color("#155d71"))
	draw_string(font, Vector2(349, 493), "Kenney Sci-Fi UI / Sounds (CC0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#668898"))

func _draw_clear() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.02, 0.07, 0.09, 0.75), true)
	var box := Rect2(240, 180, 480, 320)
	draw_rect(box, Color("#09211f"), true)
	draw_rect(box, Color("#50efb4"), false, 3.0)
	draw_string(font, Vector2(350, 247), "SYNC SUCCESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 29, Color("#74f5c4"))
	draw_string(font, Vector2(333, 292), "ステージ %d クリア" % [stage_index + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#e6fff7"))
	draw_string(font, Vector2(310, 335), "NOW と PAST の同期に成功しました", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#a7d8c8"))
	_draw_button(NEXT_RECT, "次のステージへ  Enter", Color("#176759"))

func _draw_complete() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.01, 0.05, 0.07, 0.93), true)
	var box := Rect2(185, 140, 590, 365)
	draw_rect(box, Color("#081b29"), true)
	draw_rect(box, Color("#61eec2"), false, 3.0)
	draw_string(font, Vector2(308, 215), "EXPERIMENT COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#7cf4ca"))
	draw_string(font, Vector2(300, 265), "3つの時間同期パズルを突破！", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#e5fff7"))
	draw_string(font, Vector2(245, 320), "過去の自分を「障害」ではなく「仲間」に変えることに成功しました。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#afccd6"))
	draw_string(font, Vector2(343, 380), "R で最初からリプレイ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#9fc4d3"))
	draw_string(font, Vector2(347, 430), "Art / UI / SFX: Kenney (CC0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#668898"))
