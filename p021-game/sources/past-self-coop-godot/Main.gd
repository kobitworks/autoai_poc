extends Control

const PLAYER_SPEED := 205.0
const PLAYER_RADIUS := 18.0
const START_POS := Vector2(155, 330)
const LANDSCAPE_SIZE := Vector2(960, 640)
const PORTRAIT_SIZE := Vector2(640, 960)
const WORLD_RECT := Rect2(24, 116, 912, 360)
const PORTRAIT_STAGE := Rect2(24, 250, 592, 410)

const STAGES := [
	{"name":"STAGE 1  同時押し","record":11.0,"a":Vector2(390,270),"b":Vector2(565,390),"goal":Rect2(820,250,90,160),"hint":"片方のスイッチ上で記録を終え、もう片方をNOWで踏もう"},
	{"name":"STAGE 2  時差協力","record":9.0,"a":Vector2(335,405),"b":Vector2(650,245),"goal":Rect2(820,205,90,120),"hint":"PASTが遠いスイッチへ向かう時間を逆算しよう"},
	{"name":"STAGE 3  最終同期","record":8.0,"a":Vector2(455,220),"b":Vector2(655,405),"goal":Rect2(805,300,105,120),"hint":"短い記録時間で経路を作り、解除後すぐGOALへ"}
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
var run_elapsed := 0.0
var retry_count := 0
var best_time := -1.0
var best_retries := -1
var best_rank := "--"
var current_rank := "--"
var sfx_volume_index := 1
var qa_mode := false

const SFX_DB := [0.0, -6.0, -14.0, -80.0]
const SFX_LABELS := ["SFX 100%", "SFX 70%", "SFX 40%", "SFX OFF"]

var switch_a := Vector2.ZERO
var switch_b := Vector2.ZERO
var goal_rect := Rect2()
var record_seconds := 10.0
var stage_hint := ""

var ui_panel: Texture2D
var ui_button: Texture2D
var ui_icon: Texture2D
var audio_player: AudioStreamPlayer

var portrait := false
var logical_size := LANDSCAPE_SIZE
var layout_scale := 1.0
var layout_offset := Vector2.ZERO
var start_rect := Rect2(330, 432, 300, 62)
var next_rect := Rect2(330, 422, 300, 58)
var pad_up := Rect2()
var pad_down := Rect2()
var pad_left := Rect2()
var pad_right := Rect2()
var finish_rect := Rect2()
var retry_rect := Rect2()
var audio_rect := Rect2()
var restart_rect := Rect2()

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
	_load_persistent_state()
	_apply_audio_level()
	qa_mode = _detect_qa_mode()
	_apply_stage(0)
	_refresh_layout()
	set_process_input(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_refresh_layout()

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _refresh_layout() -> void:
	portrait = size.y > size.x
	logical_size = PORTRAIT_SIZE if portrait else LANDSCAPE_SIZE
	layout_scale = minf(size.x / logical_size.x, size.y / logical_size.y)
	layout_scale = maxf(layout_scale, 0.01)
	layout_offset = (size - logical_size * layout_scale) * 0.5

	if portrait:
		start_rect = Rect2(90, 730, 460, 72)
		next_rect = Rect2(90, 720, 460, 68)
		pad_up = Rect2(102, 694, 72, 72)
		pad_down = Rect2(102, 838, 72, 72)
		pad_left = Rect2(28, 766, 72, 72)
		pad_right = Rect2(176, 766, 72, 72)
		finish_rect = Rect2(350, 714, 252, 68)
		retry_rect = Rect2(350, 806, 252, 68)
		audio_rect = Rect2(350, 884, 252, 54)
		restart_rect = Rect2(120, 650, 400, 72)
	else:
		start_rect = Rect2(330, 432, 300, 62)
		next_rect = Rect2(330, 422, 300, 58)
		pad_up = Rect2(88, 474, 58, 58)
		pad_down = Rect2(88, 550, 58, 58)
		pad_left = Rect2(24, 512, 58, 58)
		pad_right = Rect2(152, 512, 58, 58)
		finish_rect = Rect2(730, 500, 180, 48)
		retry_rect = Rect2(730, 558, 180, 48)
		audio_rect = Rect2(540, 558, 170, 48)
		restart_rect = Rect2(330, 430, 300, 58)
	queue_redraw()

func _screen_to_layout(screen_pos: Vector2) -> Vector2:
	return (screen_pos - layout_offset) / layout_scale

func _world_to_layout(world_pos: Vector2) -> Vector2:
	if not portrait:
		return world_pos
	var nx := (world_pos.x - WORLD_RECT.position.x) / WORLD_RECT.size.x
	var ny := (world_pos.y - WORLD_RECT.position.y) / WORLD_RECT.size.y
	return PORTRAIT_STAGE.position + Vector2(nx * PORTRAIT_STAGE.size.x, ny * PORTRAIT_STAGE.size.y)

func _world_rect_to_layout(world_rect: Rect2) -> Rect2:
	if not portrait:
		return world_rect
	var p1 := _world_to_layout(world_rect.position)
	var p2 := _world_to_layout(world_rect.end)
	return Rect2(p1, p2 - p1)

func _physics_process(delta: float) -> void:
	pulse += delta
	unlocked_flash = maxf(0.0, unlocked_flash - delta)
	if not show_intro and phase != Phase.COMPLETE:
		run_elapsed += delta
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
	retry_count += 1
	_reset_stage_state()
	_play_sfx(0)

func _restart_run() -> void:
	run_elapsed = 0.0
	retry_count = 0
	current_rank = "--"
	_apply_stage(0)
	show_intro = true
	_play_sfx(0)
	queue_redraw()

func _finish_run() -> void:
	phase = Phase.COMPLETE
	touch_dir = Vector2.ZERO
	current_rank = _rank_for_run(run_elapsed, retry_count)
	if best_time < 0.0 or run_elapsed < best_time:
		best_time = run_elapsed
	if best_retries < 0 or retry_count < best_retries:
		best_retries = retry_count
	var order := {"--": 0, "C": 1, "B": 2, "A": 3, "S": 4}
	if int(order.get(current_rank, 0)) > int(order.get(best_rank, 0)):
		best_rank = current_rank
	_save_persistent_state()
	_play_sfx(3)
	queue_redraw()

func _rank_for_run(seconds: float, retries: int) -> String:
	if seconds <= 55.0 and retries == 0:
		return "S"
	if seconds <= 80.0 and retries <= 2:
		return "A"
	if seconds <= 120.0 and retries <= 5:
		return "B"
	return "C"

func _best_summary() -> String:
	var time_text := "--"
	if best_time >= 0.0:
		time_text = "%.1fs" % best_time
	var retry_text := "--" if best_retries < 0 else str(best_retries)
	return "BEST  %s / RETRY %s / RANK %s" % [time_text, retry_text, best_rank]

func _load_persistent_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://past_sync.cfg") == OK:
		sfx_volume_index = clampi(int(cfg.get_value("audio", "level", 1)), 0, SFX_DB.size() - 1)
		best_time = float(cfg.get_value("records", "best_time", -1.0))
		best_retries = int(cfg.get_value("records", "best_retries", -1))
		best_rank = str(cfg.get_value("records", "best_rank", "--"))

func _save_persistent_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "level", sfx_volume_index)
	cfg.set_value("records", "best_time", best_time)
	cfg.set_value("records", "best_retries", best_retries)
	cfg.set_value("records", "best_rank", best_rank)
	cfg.save("user://past_sync.cfg")

func _apply_audio_level() -> void:
	if audio_player != null:
		audio_player.volume_db = float(SFX_DB[sfx_volume_index])

func _cycle_audio() -> void:
	sfx_volume_index = (sfx_volume_index + 1) % SFX_DB.size()
	_apply_audio_level()
	_save_persistent_state()
	queue_redraw()

func _detect_qa_mode() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true))
	return false

func _qa_advance() -> void:
	if not qa_mode:
		return
	if show_intro:
		show_intro = false
		run_elapsed = 0.0
		retry_count = 0
		queue_redraw()
		return
	if phase == Phase.RECORDING or phase == Phase.REPLAYING:
		phase = Phase.CLEAR
		touch_dir = Vector2.ZERO
		_play_sfx(3)
		queue_redraw()
		return
	if phase == Phase.CLEAR:
		if stage_index < STAGES.size() - 1:
			_apply_stage(stage_index + 1)
		else:
			_finish_run()
		return
	if phase == Phase.COMPLETE:
		_restart_run()

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
	var pointer_pressed := false
	var pointer_pos := Vector2(-9999, -9999)
	if event is InputEventMouseButton:
		var top_mouse: InputEventMouseButton = event as InputEventMouseButton
		if top_mouse.pressed and top_mouse.button_index == MOUSE_BUTTON_LEFT:
			pointer_pressed = true
			pointer_pos = _screen_to_layout(top_mouse.position)
	elif event is InputEventScreenTouch:
		var top_touch: InputEventScreenTouch = event as InputEventScreenTouch
		if top_touch.pressed:
			pointer_pressed = true
			pointer_pos = _screen_to_layout(top_touch.position)

	if event is InputEventKey:
		var global_key: InputEventKey = event as InputEventKey
		if global_key.pressed and global_key.keycode == KEY_M:
			_cycle_audio()
			return
		if qa_mode and global_key.pressed and global_key.keycode == KEY_F9:
			_qa_advance()
			return

	if pointer_pressed and audio_rect.has_point(pointer_pos):
		_cycle_audio()
		return

	if phase == Phase.COMPLETE:
		var restart_now := pointer_pressed and restart_rect.has_point(pointer_pos)
		if event is InputEventKey:
			var complete_key: InputEventKey = event as InputEventKey
			restart_now = restart_now or (complete_key.pressed and complete_key.keycode in [KEY_R, KEY_ENTER, KEY_SPACE])
		if restart_now:
			_restart_run()
		return

	if show_intro:
		var start_now := false
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			start_now = key_event.pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE)
		elif event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			start_now = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and start_rect.has_point(_screen_to_layout(mouse_event.position))
		elif event is InputEventScreenTouch:
			var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
			start_now = touch_event.pressed and start_rect.has_point(_screen_to_layout(touch_event.position))
		if start_now:
			show_intro = false
			run_elapsed = 0.0
			retry_count = 0
			current_rank = "--"
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
			advance = clear_mouse.pressed and next_rect.has_point(_screen_to_layout(clear_mouse.position))
		elif event is InputEventScreenTouch:
			var clear_touch: InputEventScreenTouch = event as InputEventScreenTouch
			advance = clear_touch.pressed and next_rect.has_point(_screen_to_layout(clear_touch.position))
		if advance:
			if stage_index < STAGES.size() - 1:
				_apply_stage(stage_index + 1)
			else:
				_finish_run()
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
			_handle_pointer_press(_screen_to_layout(touch_event.position))
		else:
			touch_dir = Vector2.ZERO
	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		_update_touch_direction(_screen_to_layout(drag_event.position))
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_handle_pointer_press(_screen_to_layout(mouse_event.position))
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
	draw_set_transform(layout_offset, 0.0, Vector2(layout_scale, layout_scale))
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
	_draw_button(audio_rect, "%s  M" % SFX_LABELS[sfx_volume_index], Color("#24475c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, logical_size), Color("#07111d"))
	for i in range(18):
		var x := float((i * 83) % int(logical_size.x))
		var y := 105.0 + float((i * 137) % int(maxf(120.0, logical_size.y - 180.0)))
		var alpha := 0.10 + 0.05 * sin(pulse * 1.5 + float(i))
		draw_circle(Vector2(x, y), 1.8, Color(0.35, 0.75, 1.0, alpha))
	var header_h := 210.0 if portrait else 96.0
	draw_rect(Rect2(0, 0, logical_size.x, header_h), Color("#101f33"))
	draw_rect(Rect2(0, header_h - 4, logical_size.x, 4), Color("#4bc4e8"))
	if portrait:
		draw_string(font, Vector2(26, 46), "PAST//SYNC", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#f1fbff"))
		draw_string(font, Vector2(26, 76), "過去の自分と協力するゲーム", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9fcadd"))
	else:
		draw_string(font, Vector2(30, 44), "PAST//SYNC", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("#f1fbff"))
		draw_string(font, Vector2(30, 74), "過去の自分と協力するゲーム", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9fcadd"))

func _draw_stage() -> void:
	var room := PORTRAIT_STAGE if portrait else WORLD_RECT
	draw_rect(room, Color("#101b2a"), true)
	for i in range(1, 12):
		var x := room.position.x + room.size.x * float(i) / 12.0
		draw_line(Vector2(x, room.position.y), Vector2(x, room.end.y), Color(0.20,0.45,0.58,0.10), 1.0)
	for j in range(1, 8):
		var y := room.position.y + room.size.y * float(j) / 8.0
		draw_line(Vector2(room.position.x, y), Vector2(room.end.x, y), Color(0.20,0.45,0.58,0.10), 1.0)
	draw_rect(room, Color("#37566c"), false, 2.0)

	var a := _world_to_layout(switch_a)
	var b := _world_to_layout(switch_b)
	var goal := _world_rect_to_layout(goal_rect)
	_draw_switch(a, "A")
	_draw_switch(b, "B")

	var gate_world := Vector2(764, 305)
	var gate := _world_to_layout(gate_world)
	var gate_h := 205.0 if not portrait else 175.0
	var gate_color := Color("#42efb3") if gate_unlocked else Color("#ff6e86")
	draw_rect(Rect2(gate.x - 9, gate.y - gate_h * 0.5, 18, gate_h), Color(gate_color,0.30), true)
	for yoff in range(-80, 81, 24):
		draw_rect(Rect2(gate.x - 7, gate.y + yoff - 7, 14, 14), gate_color, true)
	draw_string(font, gate + Vector2(-52, -gate_h * 0.55), "UNLOCKED" if gate_unlocked else "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gate_color)

	var glow := 0.14 + 0.06 * sin(pulse * 3.0)
	draw_rect(goal, Color(0.15,1.0,0.72,glow), true)
	draw_rect(goal, Color("#57eeb7"), false, 3.0)
	draw_string(font, goal.position + Vector2(14, goal.size.y * 0.55), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b4ffe5"))

	_draw_player(_world_to_layout(current_pos), Color("#37c8ff"), false)
	if phase != Phase.RECORDING:
		_draw_player(_world_to_layout(ghost_pos), Color(0.67,0.48,1.0,0.62), true)
	if unlocked_flash > 0.0:
		draw_rect(room, Color(0.25,1.0,0.72,unlocked_flash*0.13), true)

func _draw_player(pos: Vector2, color: Color, ghost: bool) -> void:
	var radius := 16.0 if portrait else PLAYER_RADIUS
	var aura := radius + 8.0 + sin(pulse * 4.0) * 2.5
	draw_circle(pos, aura, Color(color, 0.14 if not ghost else 0.10))
	draw_circle(pos, radius, color)
	draw_rect(Rect2(pos + Vector2(-8,-6), Vector2(16,12)), Color("#07111d"), true)
	draw_circle(pos + Vector2(-4,0), 2.2, Color("#eafaff"))
	draw_circle(pos + Vector2(4,0), 2.2, Color("#eafaff"))
	draw_string(font, pos + Vector2(-22,-27), "PAST" if ghost else "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#dccfff") if ghost else Color("#b8f0ff"))

func _draw_switch(pos: Vector2, label: String) -> void:
	var active: bool = _is_on_switch(current_pos, switch_a if label == "A" else switch_b) or (phase != Phase.RECORDING and _is_on_switch(ghost_pos, switch_a if label == "A" else switch_b))
	var c := Color("#ffd456") if active else Color("#597184")
	var r := 29.0 if portrait else 36.0
	draw_circle(pos, r + sin(pulse * 3.5) * 2.0, Color(c,0.12))
	draw_circle(pos, r - 8, c)
	draw_circle(pos, r - 17, Color("#14202d"))
	draw_string(font, pos + Vector2(-5,6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f5fbff"))

func _draw_hud() -> void:
	var data: Dictionary = STAGES[stage_index]
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

	if portrait:
		draw_string(font, Vector2(26, 122), str(data["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d9f7ff"))
		draw_string(font, Vector2(26, 150), "STAGE %d / %d" % [stage_index + 1, STAGES.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#79a9be"))
		draw_rect(Rect2(378, 104, 230, 58), Color("#071423"), true)
		draw_rect(Rect2(378, 104, 230, 58), phase_color, false, 2.0)
		draw_string(font, Vector2(396, 140), phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, phase_color)
		if phase == Phase.RECORDING:
			var remain: float = maxf(0.0, record_seconds - record_elapsed)
			draw_string(font, Vector2(380, 188), "残り %.1f 秒" % remain, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffd7dd"))
			draw_rect(Rect2(472, 178, 136, 8), Color("#39222b"), true)
			draw_rect(Rect2(472, 178, 136.0 * (remain / record_seconds), 8), Color("#ff6b83"), true)
	else:
		draw_string(font, Vector2(350, 44), str(data["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#d9f7ff"))
		draw_string(font, Vector2(350, 72), "STAGE %d / %d" % [stage_index + 1, STAGES.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#79a9be"))
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
	_draw_button(finish_rect, "記録終了" if portrait else "記録終了  Enter", Color("#7e3146") if phase == Phase.RECORDING else Color("#223445"))
	_draw_button(retry_rect, "リトライ", Color("#1b5149"))
	if portrait:
		draw_string(font, Vector2(28, 930), "タップ操作対応 / 端末回転で自動レイアウト", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#607f91"))
		draw_string(font, Vector2(280, 686), stage_hint, HORIZONTAL_ALIGNMENT_LEFT, 330, 13, Color("#d2e7f0"))
	else:
		draw_string(font, Vector2(245, 516), "WASD / 矢印キーで移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9fc5d7"))
		draw_string(font, Vector2(245, 544), stage_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d2e7f0"))
		draw_string(font, Vector2(245, 572), "RECで経路を記録 → SYNCでPASTと同時に動く", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8faec0"))
		draw_string(font, Vector2(245, 600), "Art/UI/SFX: Kenney CC0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#607f91"))

func _draw_button(rect: Rect2, label: String, color: Color) -> void:
	if ui_button != null:
		draw_texture_rect(ui_button, rect, false)
		draw_rect(rect, Color(color, 0.34), true)
	else:
		draw_rect(rect, color, true)
	draw_rect(rect, Color("#5f879b"), false, 2.0)
	var size := 25 if label.length() <= 2 else (17 if portrait else 15)
	draw_string(font, rect.position + Vector2(14, rect.size.y / 2 + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("#effbff"))

func _draw_intro() -> void:
	draw_rect(Rect2(Vector2.ZERO, logical_size), Color(0.02,0.05,0.08,0.93), true)
	if portrait:
		var box := Rect2(36, 86, 568, 780)
		draw_rect(box, Color("#0c1a29"), true)
		draw_rect(box, Color("#48ccea"), false, 2.0)
		draw_string(font, Vector2(176, 166), "PAST//SYNC", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#ecfbff"))
		draw_string(font, Vector2(122, 210), "過去の自分と協力するゲーム", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#bfefff"))
		draw_string(font, Vector2(82, 306), "1回目の動きを記録し、PASTとして再生。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b4cbd7"))
		draw_string(font, Vector2(70, 344), "NOWとPASTで2つのスイッチを同時に踏もう。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b4cbd7"))
		draw_string(font, Vector2(104, 410), "全3ステージ / 縦横画面に自動対応", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#8faec0"))
		draw_string(font, Vector2(80, 466), "スマホ・タブレットは画面下の操作パッドだけで遊べます。", HORIZONTAL_ALIGNMENT_LEFT, 480, 14, Color("#9fc5d7"))
		draw_string(font, Vector2(116, 590), _best_summary(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#7cf4ca"))
		_draw_button(start_rect, "同期実験を開始", Color("#155d71"))
		draw_string(font, Vector2(172, 838), "Kenney Sci-Fi UI / Sounds (CC0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#668898"))
	else:
		var box := Rect2(190, 130, 580, 385)
		draw_rect(box, Color("#0c1a29"), true)
		draw_rect(box, Color("#48ccea"), false, 2.0)
		draw_string(font, Vector2(318, 190), "PAST//SYNC", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#ecfbff"))
		draw_string(font, Vector2(276, 230), "過去の自分と協力するゲーム", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#bfefff"))
		draw_string(font, Vector2(257, 286), "1回目の動きを記録し、その動きをPASTとして再生。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b4cbd7"))
		draw_string(font, Vector2(235, 316), "NOWとPASTで2つのスイッチを同時に踏み、出口を開けよう。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b4cbd7"))
		draw_string(font, Vector2(300, 360), "全3ステージ / Portrait・Landscape対応", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8faec0"))
		draw_string(font, Vector2(337, 400), _best_summary(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#7cf4ca"))
		_draw_button(start_rect, "同期実験を開始  Enter", Color("#155d71"))
		draw_string(font, Vector2(349, 493), "Kenney Sci-Fi UI / Sounds (CC0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#668898"))

func _draw_clear() -> void:
	draw_rect(Rect2(Vector2.ZERO, logical_size), Color(0.02,0.07,0.09,0.78), true)
	var box := Rect2(46, 240, 548, 520) if portrait else Rect2(240,180,480,320)
	draw_rect(box, Color("#09211f"), true)
	draw_rect(box, Color("#50efb4"), false, 3.0)
	if portrait:
		draw_string(font, Vector2(154, 340), "SYNC SUCCESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#74f5c4"))
		draw_string(font, Vector2(176, 398), "ステージ %d クリア" % [stage_index + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#e6fff7"))
		draw_string(font, Vector2(112, 452), "NOW と PAST の同期に成功しました", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#a7d8c8"))
	else:
		draw_string(font, Vector2(350,247), "SYNC SUCCESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 29, Color("#74f5c4"))
		draw_string(font, Vector2(333,292), "ステージ %d クリア" % [stage_index + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#e6fff7"))
		draw_string(font, Vector2(310,335), "NOW と PAST の同期に成功しました", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#a7d8c8"))
	_draw_button(next_rect, "次のステージへ", Color("#176759"))

func _draw_complete() -> void:
	draw_rect(Rect2(Vector2.ZERO, logical_size), Color(0.01,0.05,0.07,0.94), true)
	var box := Rect2(40, 140, 560, 660) if portrait else Rect2(185,105,590,430)
	draw_rect(box, Color("#081b29"), true)
	draw_rect(box, Color("#61eec2"), false, 3.0)
	if portrait:
		draw_string(font, Vector2(92, 230), "EXPERIMENT COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#7cf4ca"))
		draw_string(font, Vector2(98, 286), "3つの時間同期パズルを突破！", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#e5fff7"))
		draw_string(font, Vector2(78, 350), "過去の自分を「障害」ではなく「仲間」に変えることに成功しました。", HORIZONTAL_ALIGNMENT_LEFT, 480, 15, Color("#afccd6"))
		draw_string(font, Vector2(105, 475), "今回  %.1fs / RETRY %d / RANK %s" % [run_elapsed, retry_count, current_rank], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d8f7ff"))
		draw_string(font, Vector2(105, 515), _best_summary(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#7cf4ca"))
		_draw_button(restart_rect, "最初からもう一度", Color("#176759"))
		draw_string(font, Vector2(184, 755), "Art / UI / SFX: Kenney (CC0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#668898"))
	else:
		draw_string(font, Vector2(308,180), "EXPERIMENT COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#7cf4ca"))
		draw_string(font, Vector2(300,230), "3つの時間同期パズルを突破！", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#e5fff7"))
		draw_string(font, Vector2(245,280), "過去の自分を「障害」ではなく「仲間」に変えることに成功しました。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#afccd6"))
		draw_string(font, Vector2(300,335), "今回 %.1fs / RETRY %d / RANK %s" % [run_elapsed, retry_count, current_rank], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d8f7ff"))
		draw_string(font, Vector2(320,370), _best_summary(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#7cf4ca"))
		_draw_button(restart_rect, "最初からもう一度  R", Color("#176759"))
		draw_string(font, Vector2(347,515), "Art / UI / SFX: Kenney (CC0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#668898"))
