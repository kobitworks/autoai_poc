extends Control

# GAME-061 / GAME-G014 Switch Shortest Godot redesign
const BUILD_ID := "GAME-061-20261010"
const SAVE_PATH := "user://switch-shortest-best.json"
const DIFFICULTY_KEYS := ["easy", "normal", "hard"]
const DIFFICULTY_LABELS := ["EASY · 8", "NORMAL · 10", "HARD · 12"]
const DIFFICULTY_COUNTS := [8, 10, 12]

var ui_font: Font
var difficulty_index: int = 1
var switches_n: int = 10
var goal_mask: int = 0
var start_mask: int = 0
var current_mask: int = 0
var moves: int = 0
var optimal_start: int = 0
var start_solution: Array[int] = []
var current_solution: Array[int] = []
var press_pulse: Array[float] = []
var switch_centers: Array[Vector2] = []
var hint_index: int = -1
var hovered_index: int = -1
var status_text: String = ""
var phase: String = "playing"
var sound_on: bool = true
var qa_mode: bool = false
var anim_clock: float = 0.0
var result_clock: float = 0.0
var best_records: Dictionary = {}
var rng := RandomNumberGenerator.new()

var button_difficulty := Rect2()
var button_sound := Rect2()
var button_hint := Rect2()
var button_new := Rect2()
var button_retry := Rect2()
var button_hub := Rect2()
var result_retry := Rect2()
var result_new := Rect2()

var audio_player: AudioStreamPlayer
var tone_toggle: AudioStreamWAV
var tone_hint: AudioStreamWAV
var tone_clear: AudioStreamWAV

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_load_font()
	_load_storage()
	_setup_audio()
	if OS.get_name() == "Web":
		qa_mode = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true))
	rng.seed = 61014 if qa_mode else int(Time.get_unix_time_from_system())
	if qa_mode:
		difficulty_index = 0
	_new_puzzle()
	grab_focus()
	set_process(true)
	call_deferred("_update_debug_bridge")

func _process(delta: float) -> void:
	anim_clock += delta
	if phase == "result":
		result_clock += delta
	var active_animation := false
	for i in range(press_pulse.size()):
		if press_pulse[i] > 0.0:
			press_pulse[i] = maxf(0.0, press_pulse[i] - delta * 2.7)
			active_animation = true
	if hint_index >= 0 or phase == "result" or active_animation:
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		queue_redraw()
		call_deferred("_update_debug_bridge")

func _load_font() -> void:
	var loaded: Resource = load("res://fonts/NotoSansJP.ttf")
	ui_font = loaded as Font if loaded is Font else ThemeDB.fallback_font

func _load_storage() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		best_records = parsed as Dictionary

func _save_storage() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(best_records))

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_toggle = _make_tone(510.0, 0.055, 0.11)
	tone_hint = _make_tone(720.0, 0.09, 0.12)
	tone_clear = _make_chord()

func _make_tone(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var env := 1.0 - (float(i) / maxf(1.0, float(frames)))
		var wave := sin(TAU * freq * float(i) / float(rate))
		var sample := int(clampf(wave * env * amplitude, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func _make_chord() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.36
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := 1.0 - (float(i) / maxf(1.0, float(frames)))
		var wave := (sin(TAU * 660.0 * t) + sin(TAU * 880.0 * t) * 0.72 + sin(TAU * 1100.0 * t) * 0.42) / 2.14
		var sample := int(clampf(wave * env * 0.18, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func _play(stream: AudioStreamWAV) -> void:
	if not sound_on or stream == null:
		return
	audio_player.stream = stream
	audio_player.play()

func _toggle_mask(index: int, count: int) -> int:
	var mask := 1 << index
	if index > 0:
		mask |= 1 << (index - 1)
	if index < count - 1:
		mask |= 1 << (index + 1)
	return mask

func _shortest_path(from_mask: int, to_mask: int, count: int) -> Array[int]:
	var result: Array[int] = []
	if from_mask == to_mask:
		return result
	var state_count := 1 << count
	var seen := PackedByteArray()
	seen.resize(state_count)
	var parent := PackedInt32Array()
	parent.resize(state_count)
	parent.fill(-1)
	var action := PackedInt32Array()
	action.resize(state_count)
	action.fill(-1)
	var queue := PackedInt32Array()
	queue.append(from_mask)
	seen[from_mask] = 1
	var head := 0
	var found := false
	while head < queue.size() and not found:
		var state := int(queue[head])
		head += 1
		for i in range(count):
			var next_state := state ^ _toggle_mask(i, count)
			if seen[next_state] != 0:
				continue
			seen[next_state] = 1
			parent[next_state] = state
			action[next_state] = i
			if next_state == to_mask:
				found = true
				break
			queue.append(next_state)
	if not found:
		return result
	var cursor := to_mask
	while cursor != from_mask:
		result.push_front(int(action[cursor]))
		cursor = int(parent[cursor])
	return result

func _new_puzzle() -> void:
	switches_n = int(DIFFICULTY_COUNTS[difficulty_index])
	goal_mask = rng.randi_range(0, (1 << switches_n) - 1)
	start_mask = goal_mask
	var scramble := [4, 6, 8][difficulty_index]
	if qa_mode and difficulty_index == 0:
		goal_mask = 173
		start_mask = goal_mask
		for idx in [1, 4, 6]:
			start_mask ^= _toggle_mask(int(idx), switches_n)
	else:
		for _step in range(scramble):
			start_mask ^= _toggle_mask(rng.randi_range(0, switches_n - 1), switches_n)
		if start_mask == goal_mask:
			start_mask ^= _toggle_mask(rng.randi_range(0, switches_n - 1), switches_n)
	current_mask = start_mask
	moves = 0
	phase = "playing"
	result_clock = 0.0
	hint_index = -1
	start_solution = _shortest_path(start_mask, goal_mask, switches_n)
	current_solution = start_solution.duplicate()
	optimal_start = start_solution.size()
	if optimal_start == 0:
		start_mask ^= _toggle_mask(0, switches_n)
		current_mask = start_mask
		start_solution = _shortest_path(start_mask, goal_mask, switches_n)
		current_solution = start_solution.duplicate()
		optimal_start = start_solution.size()
	press_pulse.clear()
	for _i in range(switches_n):
		press_pulse.append(0.0)
	status_text = "TARGET と同じ点灯パターンを、できるだけ少ない手数で作ろう。"
	queue_redraw()
	_update_debug_bridge()

func _retry() -> void:
	current_mask = start_mask
	moves = 0
	phase = "playing"
	result_clock = 0.0
	hint_index = -1
	current_solution = _shortest_path(current_mask, goal_mask, switches_n)
	for i in range(press_pulse.size()):
		press_pulse[i] = 0.0
	status_text = "RETRY — 同じ問題を最初から。最短 %d 手。" % optimal_start
	_play(tone_hint)
	queue_redraw()
	_update_debug_bridge()

func _cycle_difficulty() -> void:
	difficulty_index = (difficulty_index + 1) % DIFFICULTY_KEYS.size()
	_new_puzzle()
	_play(tone_hint)

func _toggle_sound() -> void:
	sound_on = not sound_on
	if sound_on:
		_play(tone_toggle)
	status_text = "SOUND ON" if sound_on else "SOUND OFF"
	queue_redraw()
	_update_debug_bridge()

func _hint() -> void:
	if phase != "playing":
		return
	current_solution = _shortest_path(current_mask, goal_mask, switches_n)
	if current_solution.is_empty():
		hint_index = -1
		status_text = "もうTARGETと一致しています。"
	else:
		hint_index = int(current_solution[0])
		status_text = "HINT — SWITCH %02d が最短経路の一手です。" % (hint_index + 1)
	_play(tone_hint)
	queue_redraw()
	_update_debug_bridge()

func _press_switch(index: int) -> void:
	if phase != "playing" or index < 0 or index >= switches_n:
		return
	current_mask ^= _toggle_mask(index, switches_n)
	moves += 1
	hint_index = -1
	for offset in [-1, 0, 1]:
		var pulse_index := index + int(offset)
		if pulse_index >= 0 and pulse_index < press_pulse.size():
			press_pulse[pulse_index] = 1.0
	current_solution = _shortest_path(current_mask, goal_mask, switches_n)
	status_text = "SWITCH %02d — 自分と左右が反転。TARGETまで最短あと %d 手。" % [index + 1, current_solution.size()]
	_play(tone_toggle)
	if current_mask == goal_mask:
		_finish_game()
	queue_redraw()
	_update_debug_bridge()

func _finish_game() -> void:
	phase = "result"
	result_clock = 0.0
	var delta := moves - optimal_start
	var rank := "S" if delta <= 0 else ("A" if delta <= 2 else ("B" if delta <= 5 else "C"))
	status_text = "CLEAR! RANK %s — %d手 / 最短%d手" % [rank, moves, optimal_start]
	_record_best()
	_play(tone_clear)

func _record_best() -> void:
	var key: String = str(DIFFICULTY_KEYS[difficulty_index])
	var previous: Variant = best_records.get(key, null)
	if previous == null or moves < int(previous):
		best_records[key] = moves
		_save_storage()

func _best_text() -> String:
	var key: String = str(DIFFICULTY_KEYS[difficulty_index])
	var value: Variant = best_records.get(key, null)
	return "—" if value == null else str(int(value))

func _is_on(mask: int, index: int) -> bool:
	return (mask & (1 << index)) != 0

func _rounded_box(rect: Rect2, bg: Color, border: Color = Color.TRANSPARENT, radius: int = 12, border_width: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border.a > 0.0:
		style.border_color = border
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
	draw_style_box(style, rect)

func _font_size(base: float) -> int:
	var scale_value := clampf(minf(size.x / 390.0, size.y / 700.0), 0.74, 1.22)
	return maxi(10, int(round(base * scale_value)))

func _draw_center_text(text_value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var measured := ui_font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var x := rect.position.x + (rect.size.x - measured.x) * 0.5
	var y := rect.position.y + (rect.size.y + ui_font.get_ascent(font_size) - ui_font.get_descent(font_size)) * 0.5
	draw_string(ui_font, Vector2(x, y), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_label(text_value: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(ui_font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_button(rect: Rect2, label: String, accent: bool = false) -> void:
	var bg := Color("#132847") if not accent else Color("#0c5d78")
	var border := Color("#315577") if not accent else Color("#22d3ee")
	_rounded_box(rect, bg, border, 11, 1)
	_draw_center_text(label, rect, _font_size(12.5), Color("#e8f6ff"))

func _layout_switch_centers(rect: Rect2, count: int) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var columns := count
	if rect.size.x < 600.0:
		columns = mini(count, 6)
	var rows := int(ceil(float(count) / float(columns)))
	var cell_w := rect.size.x / float(columns)
	var cell_h := rect.size.y / float(rows)
	for i in range(count):
		var row := i / columns
		var column := i % columns
		centers.append(Vector2(rect.position.x + (float(column) + 0.5) * cell_w, rect.position.y + (float(row) + 0.5) * cell_h))
	return centers

func _draw_switch_row(rect: Rect2, mask: int, interactive: bool, target: bool = false) -> void:
	var centers := _layout_switch_centers(rect, switches_n)
	if interactive:
		switch_centers = centers
	for i in range(centers.size() - 1):
		var a := centers[i]
		var b := centers[i + 1]
		if absf(a.y - b.y) < rect.size.y * 0.30:
			draw_line(a, b, Color(0.18, 0.42, 0.63, 0.33), 2.0, true)
	var columns := switches_n if rect.size.x >= 600.0 else mini(switches_n, 6)
	var rows := int(ceil(float(switches_n) / float(columns)))
	var cell_w := rect.size.x / float(columns)
	var cell_h := rect.size.y / float(rows)
	var radius := clampf(minf(cell_w, cell_h) * (0.24 if target else 0.29), 10.0, 26.0 if target else 32.0)
	for i in range(switches_n):
		var center := centers[i]
		var on := _is_on(mask, i)
		var pulse := press_pulse[i] if interactive and i < press_pulse.size() else 0.0
		if on:
			draw_circle(center, radius * (1.42 + pulse * 0.15), Color(0.08, 0.85, 0.95, 0.08 + pulse * 0.10))
		elif pulse > 0.0:
			draw_circle(center, radius * 1.34, Color(0.61, 0.40, 0.98, pulse * 0.11))
		if interactive and i == hint_index:
			var hint_wave := 0.5 + sin(anim_clock * 6.0) * 0.5
			draw_arc(center, radius * (1.28 + hint_wave * 0.10), 0.0, TAU, 32, Color("#facc15"), 3.0, true)
		var outer := Color("#1d466b") if not on else Color("#1ed7e8")
		var inner := Color("#091325") if not on else Color("#5ee9f5")
		draw_circle(center, radius, outer)
		draw_circle(center, radius * 0.73, inner)
		if on:
			draw_circle(center - Vector2(radius * 0.18, radius * 0.18), radius * 0.20, Color(1, 1, 1, 0.48))
		if interactive:
			var index_rect := Rect2(center.x - radius, center.y - radius * 0.52, radius * 2.0, radius)
			_draw_center_text("%02d" % (i + 1), index_rect, maxi(9, int(radius * 0.62)), Color("#eafcff") if on else Color("#a9c0d7"))

func _draw() -> void:
	var w := size.x
	var h := size.y
	var compact := h < 520.0
	draw_rect(Rect2(Vector2.ZERO, size), Color("#050914"), true)
	var grid_step := 42.0
	var x := 0.0
	while x <= w:
		draw_line(Vector2(x, 0), Vector2(x, h), Color(0.11, 0.28, 0.42, 0.12), 1.0)
		x += grid_step
	var y_grid := 0.0
	while y_grid <= h:
		draw_line(Vector2(0, y_grid), Vector2(w, y_grid), Color(0.11, 0.28, 0.42, 0.12), 1.0)
		y_grid += grid_step
	draw_circle(Vector2(w * 0.12, h * 0.18), minf(w, h) * 0.30, Color(0.05, 0.58, 0.76, 0.06))
	draw_circle(Vector2(w * 0.90, h * 0.74), minf(w, h) * 0.28, Color(0.46, 0.22, 0.82, 0.06))

	var margin := clampf(w * 0.035, 12.0, 28.0)
	var panel := Rect2(margin, margin, w - margin * 2.0, h - margin * 2.0)
	_rounded_box(panel, Color(0.035, 0.071, 0.126, 0.96), Color(0.13, 0.36, 0.55, 0.78), 20, 1)

	var inner_x := panel.position.x + clampf(w * 0.025, 10.0, 24.0)
	var inner_w := panel.size.x - (inner_x - panel.position.x) * 2.0
	var top_y := panel.position.y + (18.0 if compact else 24.0)
	_draw_label("GAME-G014  /  GODOT 4.7.2", Vector2(inner_x, top_y), _font_size(10.5), Color("#67e8f9"))
	_draw_label("SWITCH SHORTEST", Vector2(inner_x, top_y + (24.0 if compact else 31.0)), _font_size(24.0 if compact else 31.0), Color("#f3f9ff"))
	if not compact:
		_draw_label("押すと自分と左右が反転。TARGETと同じ回路を最短手数で再現。", Vector2(inner_x, top_y + 58.0), _font_size(11.5), Color("#89a9c0"))

	var toolbar_y := top_y + (46.0 if compact else 78.0)
	var gap := 7.0
	var tool_w := (inner_w - gap * 3.0) / 4.0
	var tool_h := 38.0 if compact else 43.0
	button_difficulty = Rect2(inner_x, toolbar_y, tool_w, tool_h)
	button_sound = Rect2(inner_x + (tool_w + gap), toolbar_y, tool_w, tool_h)
	button_hint = Rect2(inner_x + (tool_w + gap) * 2.0, toolbar_y, tool_w, tool_h)
	button_new = Rect2(inner_x + (tool_w + gap) * 3.0, toolbar_y, tool_w, tool_h)
	_draw_button(button_difficulty, DIFFICULTY_LABELS[difficulty_index], true)
	_draw_button(button_sound, "SOUND ON" if sound_on else "SOUND OFF")
	_draw_button(button_hint, "HINT")
	_draw_button(button_new, "NEW")

	var stats_y := toolbar_y + tool_h + (8.0 if compact else 12.0)
	var stat_h := 42.0 if compact else 53.0
	var stat_gap := 8.0
	var stat_w := (inner_w - stat_gap * 2.0) / 3.0
	var stats := [
		["MOVES", str(moves)],
		["OPTIMAL", str(optimal_start)],
		["BEST", _best_text()]
	]
	for i in range(3):
		var stat_rect := Rect2(inner_x + float(i) * (stat_w + stat_gap), stats_y, stat_w, stat_h)
		_rounded_box(stat_rect, Color("#0a162a"), Color("#1c3854"), 12, 1)
		_draw_label(str(stats[i][0]), stat_rect.position + Vector2(10.0, 15.0), _font_size(9.0), Color("#6688a4"))
		_draw_label(str(stats[i][1]), stat_rect.position + Vector2(10.0, stat_h - 9.0), _font_size(18.0), Color("#f3f9ff"))

	var goal_label_y := stats_y + stat_h + (19.0 if compact else 30.0)
	_draw_label("TARGET CIRCUIT", Vector2(inner_x, goal_label_y), _font_size(10.0), Color("#7dd3fc"))
	var goal_rect := Rect2(inner_x, goal_label_y + 8.0, inner_w, 52.0 if compact else 78.0)
	_draw_switch_row(goal_rect, goal_mask, false, true)

	var play_label_y := goal_rect.end.y + (13.0 if compact else 23.0)
	_draw_label("YOUR CIRCUIT  ·  tap a switch", Vector2(inner_x, play_label_y), _font_size(10.0), Color("#c4b5fd"))
	var play_h := 58.0 if compact else minf(122.0, maxf(82.0, h * 0.17))
	var play_rect := Rect2(inner_x, play_label_y + 8.0, inner_w, play_h)
	_rounded_box(play_rect, Color(0.02, 0.06, 0.12, 0.66), Color("#183856"), 15, 1)
	_draw_switch_row(play_rect.grow(-4.0), current_mask, true, false)

	var feedback_y := play_rect.end.y + (10.0 if compact else 18.0)
	var feedback_h := 37.0 if compact else 48.0
	var feedback_rect := Rect2(inner_x, feedback_y, inner_w, feedback_h)
	_rounded_box(feedback_rect, Color(0.04, 0.11, 0.17, 0.84), Color("#1a425d"), 11, 1)
	var feedback_size := _font_size(10.5 if compact else 11.5)
	var clipped := status_text
	if compact and clipped.length() > 62:
		clipped = clipped.substr(0, 59) + "…"
	_draw_center_text(clipped, feedback_rect, feedback_size, Color("#bfe8f4"))

	var bottom_y := minf(h - margin - (38.0 if compact else 45.0) - 10.0, feedback_rect.end.y + (9.0 if compact else 15.0))
	var bottom_h := 38.0 if compact else 45.0
	var bottom_w := (inner_w - 9.0) * 0.5
	button_retry = Rect2(inner_x, bottom_y, bottom_w, bottom_h)
	button_hub = Rect2(inner_x + bottom_w + 9.0, bottom_y, bottom_w, bottom_h)
	_draw_button(button_retry, "RETRY  [R]")
	_draw_button(button_hub, "GAME HUB")

	if not compact and bottom_y + bottom_h + 23.0 < panel.end.y:
		_draw_center_text("KEYS  D mode  ·  M sound  ·  H hint  ·  N new  ·  R retry  ·  1–0 switches", Rect2(inner_x, bottom_y + bottom_h + 4.0, inner_w, 19.0), _font_size(9.0), Color("#57748c"))

	if phase == "result":
		_draw_result_overlay(panel, inner_x, inner_w)

func _draw_result_overlay(panel: Rect2, inner_x: float, inner_w: float) -> void:
	draw_rect(panel, Color(0.01, 0.025, 0.055, 0.72), true)
	var width := minf(inner_w, 460.0)
	var height := minf(245.0, panel.size.y - 36.0)
	var rect := Rect2(panel.position.x + (panel.size.x - width) * 0.5, panel.position.y + (panel.size.y - height) * 0.5, width, height)
	_rounded_box(rect, Color("#0b1b31"), Color("#22d3ee"), 22, 2)
	for i in range(12):
		var angle := float(i) / 12.0 * TAU + result_clock * 0.42
		var radius := minf(width, height) * (0.31 + 0.025 * sin(result_clock * 3.0 + float(i)))
		var point := rect.get_center() + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(point, 2.5 + 1.5 * sin(result_clock * 5.0 + float(i)), Color(0.40, 0.92, 1.0, 0.58))
	var delta := moves - optimal_start
	var rank := "S" if delta <= 0 else ("A" if delta <= 2 else ("B" if delta <= 5 else "C"))
	_draw_center_text("CIRCUIT MATCH", Rect2(rect.position.x, rect.position.y + 22.0, width, 30.0), _font_size(12.0), Color("#67e8f9"))
	_draw_center_text("CLEAR  ·  RANK %s" % rank, Rect2(rect.position.x, rect.position.y + 52.0, width, 48.0), _font_size(28.0), Color("#f4fbff"))
	_draw_center_text("%d moves  /  optimal %d  /  +%d" % [moves, optimal_start, maxi(0, delta)], Rect2(rect.position.x, rect.position.y + 102.0, width, 30.0), _font_size(12.0), Color("#a9c7d9"))
	var action_y := rect.end.y - 63.0
	result_retry = Rect2(rect.position.x + 20.0, action_y, (width - 50.0) * 0.5, 43.0)
	result_new = Rect2(result_retry.end.x + 10.0, action_y, (width - 50.0) * 0.5, 43.0)
	_draw_button(result_retry, "RETRY")
	_draw_button(result_new, "NEW PUZZLE", true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		hovered_index = _switch_at(motion.position)
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_handle_pointer(mouse.position)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_pointer(touch.position)
			accept_event()

func _switch_at(pos: Vector2) -> int:
	if phase != "playing":
		return -1
	if switch_centers.is_empty():
		return -1
	var nearest := -1
	var nearest_distance := 99999.0
	for i in range(switch_centers.size()):
		var distance := pos.distance_to(switch_centers[i])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	var threshold := 38.0 if size.x < 650.0 else 34.0
	return nearest if nearest_distance <= threshold else -1

func _handle_pointer(pos: Vector2) -> void:
	if phase == "result":
		if result_retry.has_point(pos):
			_retry()
		elif result_new.has_point(pos):
			_new_puzzle()
		return
	if button_difficulty.has_point(pos):
		_cycle_difficulty()
		return
	if button_sound.has_point(pos):
		_toggle_sound()
		return
	if button_hint.has_point(pos):
		_hint()
		return
	if button_new.has_point(pos):
		_new_puzzle()
		_play(tone_hint)
		return
	if button_retry.has_point(pos):
		_retry()
		return
	if button_hub.has_point(pos):
		_go_hub()
		return
	var switch_index := _switch_at(pos)
	if switch_index >= 0:
		_press_switch(switch_index)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_D:
			_cycle_difficulty()
		KEY_M:
			_toggle_sound()
		KEY_H:
			_hint()
		KEY_N:
			_new_puzzle()
		KEY_R:
			_retry()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			_press_switch(int(key_event.keycode - KEY_1))
		KEY_0:
			_press_switch(9)
		_:
			return
	get_viewport().set_input_as_handled()

func _go_hub() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)

func _rect_payload(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _update_debug_bridge() -> void:
	if OS.get_name() != "Web":
		return
	var centers_payload: Array = []
	for center in switch_centers:
		centers_payload.append([center.x, center.y])
	var solution_payload: Array = []
	for item in start_solution:
		solution_payload.append(item)
	var current_solution_payload: Array = []
	for item in current_solution:
		current_solution_payload.append(item)
	var payload := {
		"ready": true,
		"engine": "Godot 4.7.2",
		"build": BUILD_ID,
		"qa_mode": qa_mode,
		"viewport_w": int(get_viewport_rect().size.x),
		"viewport_h": int(get_viewport_rect().size.y),
		"difficulty": DIFFICULTY_KEYS[difficulty_index],
		"switches": switches_n,
		"moves": moves,
		"optimal": optimal_start,
		"best": _best_text(),
		"current_mask": current_mask,
		"start_mask": start_mask,
		"goal_mask": goal_mask,
		"phase": phase,
		"finished": phase == "result",
		"sound": sound_on,
		"hint_index": hint_index,
		"status": status_text,
		"solution_start": solution_payload,
		"solution_current": current_solution_payload,
		"switch_centers": centers_payload,
		"buttons": {
			"difficulty": _rect_payload(button_difficulty),
			"sound": _rect_payload(button_sound),
			"hint": _rect_payload(button_hint),
			"new": _rect_payload(button_new),
			"retry": _rect_payload(button_retry),
			"hub": _rect_payload(button_hub)
		}
	}
	JavaScriptBridge.eval("window.__P021_SWITCH_SHORTEST = %s;" % JSON.stringify(payload), true)
