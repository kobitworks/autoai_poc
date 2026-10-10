extends Control

# GAME-062 / GAME-G015 Matchstick Godot redesign.
const BUILD_ID := "GAME-062-20261010"
const SAVE_PATH := "user://matchstick-best.json"
const HUB_URL := "../../"
const Logic = preload("res://MatchstickLogic.gd")

const LEVELS := ["easy", "normal", "hard"]
const LEVEL_LABELS := ["EASY", "NORMAL", "HARD"]
const ROUND_CHOICES := [1, 3, 5, 7, 10]

var logic = Logic.new()
var ui_font: Font
var screen := "top"
var level_index := 0
var round_choice_index := 2
var round_index := 0
var score := 0
var puzzle: Dictionary = {}
var original_masks: Array = []
var carry_pos := -1
var carry_seg := -1
var moved := false
var feedback := ""
var feedback_kind := "neutral"
var feedback_pulse := 0.0
var transition_timer := 0.0
var transition_kind := ""
var best_records: Dictionary = {}
var buttons: Dictionary = {}
var segment_hits: Array = []
var qa_solution_points: Dictionary = {}
var qa_mode := false
var qa_tick := 0.0

var audio_player: AudioStreamPlayer
var tone_pick: AudioStreamWAV
var tone_place: AudioStreamWAV
var tone_ok: AudioStreamWAV
var tone_ng: AudioStreamWAV
var audio_level := 0
var audio_enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		ui_font = load("res://fonts/NotoSansJP.ttf")
	else:
		ui_font = ThemeDB.fallback_font
	_load_storage()
	_setup_audio()
	if OS.get_name() == "Web":
		qa_mode = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true))
	logic.set_seed(62015 if qa_mode else int(Time.get_unix_time_from_system()))
	if qa_mode:
		level_index = 0
		round_choice_index = 0
	grab_focus()
	set_process(true)
	queue_redraw()
	call_deferred("_publish_qa")

func _process(delta: float) -> void:
	if feedback_pulse > 0.0:
		feedback_pulse = maxf(0.0, feedback_pulse - delta * 1.8)
		queue_redraw()
	if transition_timer > 0.0:
		transition_timer -= delta
		if transition_timer <= 0.0:
			if transition_kind == "advance":
				if round_index >= _rounds():
					_finish_game()
				else:
					_next_round()
			transition_kind = ""
	if qa_mode and OS.get_name() == "Web":
		qa_tick += delta
		_poll_qa_command()
		if qa_tick >= 0.08:
			qa_tick = 0.0
			_publish_qa()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		queue_redraw()
		call_deferred("_publish_qa")

func _load_storage() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		best_records = parsed

func _save_storage() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(best_records))

func _best_key() -> String:
	return "%s:%d" % [LEVELS[level_index], _rounds()]

func _best() -> int:
	return int(best_records.get(_best_key(), 0))

func _save_best() -> void:
	var key := _best_key()
	best_records[key] = maxi(int(best_records.get(key, 0)), score)
	_save_storage()

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_pick = _make_tone(520.0, 0.055, 0.16)
	tone_place = _make_tone(690.0, 0.065, 0.16)
	tone_ok = _make_chord()
	tone_ng = _make_tone(180.0, 0.16, 0.18)
	_apply_audio_level()

func _make_tone(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := 1.0 - float(i) / maxf(1.0, float(frames))
		var wave := sin(TAU * freq * t)
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
	var duration := 0.34
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := 1.0 - float(i) / maxf(1.0, float(frames))
		var wave := (sin(TAU * 620.0 * t) + sin(TAU * 820.0 * t) * 0.72 + sin(TAU * 1040.0 * t) * 0.45) / 2.17
		var sample := int(clampf(wave * env * 0.20, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func _play(stream: AudioStreamWAV) -> void:
	if not audio_enabled or stream == null:
		return
	audio_player.stream = stream
	audio_player.play()

func _apply_audio_level() -> void:
	audio_enabled = audio_level < 2
	audio_player.volume_db = 0.0 if audio_level == 0 else (-8.0 if audio_level == 1 else -80.0)

func _cycle_audio() -> void:
	audio_level = (audio_level + 1) % 3
	_apply_audio_level()
	if audio_enabled:
		_play(tone_pick)
	queue_redraw()
	_publish_qa()

func _audio_label() -> String:
	return ["SOUND 100%", "SOUND 60%", "SOUND OFF"][audio_level]

func _rounds() -> int:
	return int(ROUND_CHOICES[round_choice_index])

func _start_game() -> void:
	screen = "game"
	round_index = 0
	score = 0
	feedback = ""
	transition_timer = 0.0
	transition_kind = ""
	_next_round()

func _next_round() -> void:
	round_index += 1
	puzzle = logic.generate_puzzle(LEVELS[level_index])
	original_masks = (puzzle["digit_masks"] as Array).duplicate()
	carry_pos = -1
	carry_seg = -1
	moved = false
	feedback = "光っているマッチを1本選んでください"
	feedback_kind = "neutral"
	queue_redraw()
	call_deferred("_publish_qa")

func _finish_game() -> void:
	_save_best()
	screen = "result"
	carry_pos = -1
	carry_seg = -1
	moved = false
	queue_redraw()
	call_deferred("_publish_qa")

func _reset_move() -> void:
	if puzzle.is_empty():
		return
	puzzle["digit_masks"] = original_masks.duplicate()
	carry_pos = -1
	carry_seg = -1
	moved = false
	feedback = "リセットしました。マッチを1本選んでください"
	feedback_kind = "neutral"
	_play(tone_pick)
	queue_redraw()
	call_deferred("_publish_qa")

func _skip() -> void:
	if screen != "game" or transition_timer > 0.0:
		return
	score = maxi(0, score - 1)
	feedback = "SKIP  正解例: " + String(puzzle.get("valid", ""))
	feedback_kind = "ng"
	feedback_pulse = 1.0
	transition_timer = 0.55
	transition_kind = "advance"
	_play(tone_ng)
	queue_redraw()
	_publish_qa()

func _check() -> void:
	if screen != "game" or not moved or transition_timer > 0.0:
		return
	var current := logic.equation_from(puzzle["chars"], puzzle["digit_masks"])
	if logic.is_equation_valid(current):
		score += 2
		feedback = "CORRECT!  " + current
		feedback_kind = "ok"
		feedback_pulse = 1.0
		transition_timer = 0.70
		transition_kind = "advance"
		_play(tone_ok)
	else:
		score = maxi(0, score - 1)
		feedback = "もう一度。現在: " + current
		feedback_kind = "ng"
		feedback_pulse = 1.0
		_play(tone_ng)
	queue_redraw()
	_publish_qa()

func _go_hub() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';")
	else:
		OS.shell_open(HUB_URL)

func _go_top() -> void:
	screen = "top"
	transition_timer = 0.0
	transition_kind = ""
	queue_redraw()
	_publish_qa()

func _rounded(rect: Rect2, color: Color, radius: float = 18.0, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)

func _label(text: String, x: float, baseline: float, width: float, font_size: int, color: Color, centered: bool = true) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(ui_font, Vector2(x, baseline), text, align, width, font_size, color)

func _button(key: String, rect: Rect2, text: String, primary: bool = false, selected: bool = false, disabled: bool = false) -> void:
	buttons[key] = rect
	var bg := Color("#14304A")
	var border := Color("#31516A")
	var color := Color("#DCE9F2")
	if primary:
		bg = Color("#0D8C80")
		border = Color("#36D6BD")
		color = Color.WHITE
	if selected:
		bg = Color("#183F56")
		border = Color("#59D3F1")
		color = Color("#E9FBFF")
	if disabled:
		bg = Color("#172431")
		border = Color("#2B3945")
		color = Color("#687887")
	_rounded(rect, bg, 12.0, border, 1)
	_label(text, rect.position.x + 4.0, rect.position.y + rect.size.y * 0.64, rect.size.x - 8.0, 14, color)

func _draw() -> void:
	buttons.clear()
	segment_hits.clear()
	qa_solution_points.clear()
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071526"))
	draw_circle(Vector2(w * 0.88, h * 0.08), minf(w, h) * 0.27, Color(0.05, 0.48, 0.58, 0.13))
	draw_circle(Vector2(w * 0.08, h * 0.92), minf(w, h) * 0.30, Color(0.12, 0.67, 0.48, 0.10))
	if screen == "top":
		_draw_top()
	elif screen == "game":
		_draw_game()
	else:
		_draw_result()

func _draw_header(title: String, subtitle: String = "") -> float:
	var w := size.x
	var compact := size.y < 520.0
	var y := 14.0 if compact else 22.0
	_button("hub", Rect2(12.0, y, 66.0, 38.0), "← HUB")
	_button("audio", Rect2(w - 126.0, y, 114.0, 38.0), _audio_label())
	_label(title, 84.0, y + 28.0, w - 216.0, 22 if compact else 26, Color("#F1F7FB"), true)
	if subtitle != "" and not compact:
		_label(subtitle, 20.0, y + 58.0, w - 40.0, 12, Color("#8FA9B9"), true)
	return y + (48.0 if compact else 74.0)

func _draw_top() -> void:
	var w := size.x
	var h := size.y
	var compact := h < 520.0
	var top := _draw_header("MATCHSTICK", "マッチ棒を1本だけ移動して、式を成立させよう")
	var margin := clampf(w * 0.035, 10.0, 24.0)
	var card := Rect2(margin, top + 4.0, w - margin * 2.0, h - top - margin - 4.0)
	_rounded(card, Color("#0C2135"), 22.0, Color("#1D4863"), 1)
	var inner_x := card.position.x + 18.0
	var inner_w := card.size.x - 36.0
	var y := card.position.y + 34.0
	if not compact:
		_label("ONE MATCH · ONE MOVE", inner_x, y, inner_w, 12, Color("#62DCCF"))
		y += 33.0
		_label("数字の棒を選び、青く光る場所へ移動", inner_x, y, inner_w, 17, Color("#E8F4F7"))
		y += 44.0
	else:
		_label("1本だけ移動 → 正しい式へ", inner_x, y, inner_w, 14, Color("#DDEEF3"))
		y += 30.0
	_label("難易度", inner_x, y, inner_w, 12, Color("#91AAB8"), false)
	y += 12.0
	var gap := 7.0
	var bw := (inner_w - gap * 2.0) / 3.0
	for i in range(3):
		_button("level_%d" % i, Rect2(inner_x + float(i) * (bw + gap), y, bw, 44.0), LEVEL_LABELS[i], false, level_index == i)
	y += 62.0
	_label("ラウンド", inner_x, y, inner_w, 12, Color("#91AAB8"), false)
	y += 12.0
	var rw := (inner_w - gap * 4.0) / 5.0
	for i in range(5):
		_button("round_%d" % i, Rect2(inner_x + float(i) * (rw + gap), y, rw, 42.0), str(ROUND_CHOICES[i]), false, round_choice_index == i)
	y += 62.0
	_button("start", Rect2(inner_x, y, inner_w, 52.0), "ゲーム開始", true)
	if not compact and card.end.y - y > 100.0:
		y += 78.0
		_label("遊び方", inner_x, y, inner_w, 12, Color("#62DCCF"))
		y += 26.0
		_label("① 点灯中の棒をタップ  ② 青い置き場所をタップ  ③ 判定", inner_x, y, inner_w, 13, Color("#A9BEC9"))

func _draw_game() -> void:
	var w := size.x
	var h := size.y
	var compact := h < 520.0
	var top := _draw_header("MATCHSTICK")
	var margin := clampf(w * 0.025, 8.0, 18.0)
	var hud_y := top + 2.0
	var hud_h := 42.0
	_rounded(Rect2(margin, hud_y, w - margin * 2.0, hud_h), Color("#0B2236"), 13.0, Color("#21455D"), 1)
	_label("ROUND %d/%d" % [round_index, _rounds()], margin + 12.0, hud_y + 28.0, (w - margin * 2.0) * 0.32, 14, Color("#B8CED8"), false)
	_label("SCORE %d" % score, w * 0.34, hud_y + 28.0, w * 0.28, 16, Color("#F5FAFC"))
	var carry_text := "棒: 未選択" if carry_pos < 0 else ("棒: 選択中" if not moved else "棒: 移動済")
	_label(carry_text, w * 0.65, hud_y + 28.0, w * 0.30 - margin, 12, Color("#FFD166"))
	var controls_h := 112.0 if compact else 132.0
	var eq_top := hud_y + hud_h + 8.0
	var eq_bottom := h - controls_h - margin
	var eq_rect := Rect2(margin, eq_top, w - margin * 2.0, maxf(132.0, eq_bottom - eq_top))
	_rounded(eq_rect, Color("#0A1D2D"), 20.0, Color("#1B4059"), 1)
	_label("1本だけ移動", eq_rect.position.x + 10.0, eq_rect.position.y + 28.0, eq_rect.size.x - 20.0, 12, Color("#6EDBCE"))
	_draw_equation(eq_rect)
	var feedback_color := Color("#8FA8B5")
	if feedback_kind == "ok":
		feedback_color = Color("#61E5B0")
	elif feedback_kind == "ng":
		feedback_color = Color("#FF7C8E")
	if feedback_pulse > 0.0:
		var glow := Color(feedback_color, 0.08 + feedback_pulse * 0.10)
		_rounded(Rect2(eq_rect.position + Vector2(8, 8), eq_rect.size - Vector2(16, 16)), glow, 16.0)
	_label(feedback, margin + 8.0, eq_rect.end.y - 14.0, w - margin * 2.0 - 16.0, 12 if compact else 13, feedback_color)
	var cy := h - controls_h + 8.0
	var gap := 7.0
	var third := (w - margin * 2.0 - gap * 2.0) / 3.0
	_button("reset", Rect2(margin, cy, third, 48.0), "リセット")
	_button("check", Rect2(margin + third + gap, cy, third, 48.0), "判定 +2", true, false, not moved)
	_button("skip", Rect2(margin + (third + gap) * 2.0, cy, third, 48.0), "スキップ -1")
	if not compact:
		_label("正解 +2 / 不正解・スキップ -1（0未満にはなりません）", margin, cy + 74.0, w - margin * 2.0, 11, Color("#718C9B"))

func _draw_equation(rect: Rect2) -> void:
	if puzzle.is_empty():
		return
	var chars: Array = puzzle["chars"]
	var masks: Array = puzzle["digit_masks"]
	var count := chars.size()
	if count <= 0:
		return
	var avail_w := rect.size.x - 24.0
	var symbol_w := minf(62.0, avail_w / float(count))
	var total_w := symbol_w * float(count)
	var start_x := rect.position.x + (rect.size.x - total_w) * 0.5
	var max_h := rect.size.y - 78.0
	var digit_h := clampf(max_h, 72.0, 120.0)
	var y := rect.position.y + 34.0 + maxf(0.0, (max_h - digit_h) * 0.5)
	var solution: Dictionary = puzzle.get("solution", {})
	for i in range(count):
		var ch := String(chars[i])
		var cell := Rect2(start_x + float(i) * symbol_w, y, symbol_w, digit_h)
		if "0123456789".contains(ch):
			_draw_digit(i, int(masks[i]), cell, solution)
		else:
			_label(ch, cell.position.x, cell.position.y + cell.size.y * 0.62, cell.size.x, int(clampf(symbol_w * 0.58, 22.0, 34.0)), Color("#E9F2F6"))

func _segment_points(seg: int, rect: Rect2) -> Array:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	match seg:
		0:
			return [Vector2(x + w * 0.27, y + h * 0.10), Vector2(x + w * 0.73, y + h * 0.10)]
		1:
			return [Vector2(x + w * 0.78, y + h * 0.17), Vector2(x + w * 0.78, y + h * 0.45)]
		2:
			return [Vector2(x + w * 0.78, y + h * 0.55), Vector2(x + w * 0.78, y + h * 0.83)]
		3:
			return [Vector2(x + w * 0.27, y + h * 0.90), Vector2(x + w * 0.73, y + h * 0.90)]
		4:
			return [Vector2(x + w * 0.22, y + h * 0.55), Vector2(x + w * 0.22, y + h * 0.83)]
		5:
			return [Vector2(x + w * 0.22, y + h * 0.17), Vector2(x + w * 0.22, y + h * 0.45)]
		_:
			return [Vector2(x + w * 0.27, y + h * 0.50), Vector2(x + w * 0.73, y + h * 0.50)]

func _draw_digit(pos: int, mask: int, rect: Rect2, solution: Dictionary) -> void:
	var stick_width := clampf(rect.size.x * 0.13, 5.0, 9.0)
	for seg in range(7):
		var points := _segment_points(seg, rect)
		var a: Vector2 = points[0]
		var b: Vector2 = points[1]
		var on := bool(mask & (1 << seg))
		var selected := carry_pos == pos and carry_seg == seg
		var placeable := carry_pos >= 0 and not moved and carry_seg == seg and not on and logic.can_add(mask, seg)
		var color := Color("#24394A")
		var width := maxf(4.0, stick_width * 0.72)
		if on:
			color = Color("#E6B867")
			width = stick_width
		if selected:
			color = Color("#FFD24A")
			width = stick_width * 1.18
		elif placeable:
			color = Color("#56D7F2")
			width = stick_width * 1.10
		if on or placeable:
			draw_line(a, b, Color(color, 0.18), width + 8.0, true)
		draw_line(a, b, color, width, true)
		if on:
			draw_circle(a, width * 0.52, Color("#D45D3C"))
			draw_circle(b, width * 0.52, Color("#D45D3C"))
		var hit := Rect2(Vector2(minf(a.x, b.x) - 13.0, minf(a.y, b.y) - 13.0), Vector2(absf(a.x - b.x) + 26.0, absf(a.y - b.y) + 26.0))
		segment_hits.append({"rect": hit, "pos": pos, "seg": seg})
		if not solution.is_empty() and int(solution.get("seg", -1)) == seg:
			if int(solution.get("from_pos", -1)) == pos:
				qa_solution_points["pick"] = hit.get_center()
			if int(solution.get("to_pos", -1)) == pos:
				qa_solution_points["place"] = hit.get_center()

func _draw_result() -> void:
	var w := size.x
	var h := size.y
	var compact := h < 520.0
	var top := _draw_header("RESULT")
	var margin := clampf(w * 0.05, 16.0, 36.0)
	var card := Rect2(margin, top + 8.0, w - margin * 2.0, h - top - margin - 8.0)
	_rounded(card, Color("#0C2135"), 22.0, Color("#1D4863"), 1)
	var y := card.position.y + (48.0 if compact else 72.0)
	_label("今回のスコア", card.position.x, y, card.size.x, 15, Color("#9EB4C1"))
	y += 62.0 if compact else 88.0
	_label(str(score), card.position.x, y, card.size.x, 58 if compact else 78, Color("#64E0C8"))
	y += 42.0 if compact else 64.0
	_label("BEST  %d" % _best(), card.position.x, y, card.size.x, 18, Color("#FFD166"))
	y += 34.0
	_label("%s · %d ROUND" % [LEVEL_LABELS[level_index], _rounds()], card.position.x, y, card.size.x, 13, Color("#91A8B6"))
	var by := card.end.y - 64.0
	var gap := 8.0
	var bw := (card.size.x - 32.0 - gap) / 2.0
	_button("restart", Rect2(card.position.x + 16.0, by, bw, 48.0), "もう一度", true)
	_button("top", Rect2(card.position.x + 16.0 + bw + gap, by, bw, 48.0), "設定へ戻る")

func _input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			point = mouse.position
			pressed = true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			point = touch.position
			pressed = true
	if not pressed:
		return
	if _handle_button(point):
		get_viewport().set_input_as_handled()
		return
	if screen == "game" and _handle_segment(point):
		get_viewport().set_input_as_handled()

func _handle_button(point: Vector2) -> bool:
	for key in buttons.keys():
		var rect: Rect2 = buttons[key]
		if not rect.has_point(point):
			continue
		var k := String(key)
		if k == "hub":
			_go_hub()
		elif k == "audio":
			_cycle_audio()
		elif k == "start":
			_start_game()
		elif k == "reset":
			_reset_move()
		elif k == "check":
			if moved:
				_check()
		elif k == "skip":
			_skip()
		elif k == "restart":
			_start_game()
		elif k == "top":
			_go_top()
		elif k.begins_with("level_"):
			level_index = int(k.trim_prefix("level_"))
			queue_redraw()
		elif k.begins_with("round_"):
			round_choice_index = int(k.trim_prefix("round_"))
			queue_redraw()
		else:
			return false
		_publish_qa()
		return true
	return false

func _handle_segment(point: Vector2) -> bool:
	if transition_timer > 0.0 or moved or puzzle.is_empty():
		return false
	for hit in segment_hits:
		var rect: Rect2 = hit["rect"]
		if not rect.has_point(point):
			continue
		var pos := int(hit["pos"])
		var seg := int(hit["seg"])
		var masks: Array = puzzle["digit_masks"]
		var mask := int(masks[pos])
		if carry_pos < 0:
			if logic.can_remove(mask, seg):
				carry_pos = pos
				carry_seg = seg
				feedback = "黄色のマッチを、青く光る場所へ移動"
				feedback_kind = "neutral"
				_play(tone_pick)
				queue_redraw()
				call_deferred("_publish_qa")
				return true
		else:
			if pos == carry_pos and seg == carry_seg:
				carry_pos = -1
				carry_seg = -1
				feedback = "選択を解除しました"
				queue_redraw()
				return true
			if seg == carry_seg and logic.can_add(mask, seg):
				var next := logic.apply_move_copy(masks, carry_pos, pos, seg)
				puzzle["digit_masks"] = next
				carry_pos = -1
				carry_seg = -1
				moved = true
				feedback = "移動完了。「判定」でチェック"
				feedback_kind = "neutral"
				_play(tone_place)
				queue_redraw()
				call_deferred("_publish_qa")
				return true
	return false

func _qa_hit(which: String) -> void:
	if screen != "game" or not qa_solution_points.has(which):
		return
	var point: Vector2 = qa_solution_points[which]
	_handle_segment(point)

func _poll_qa_command() -> void:
	var value = JavaScriptBridge.eval("window.__MATCHSTICK_QA_COMMAND__ || ''", true)
	if not (value is String):
		return
	var command := String(value)
	if command == "":
		return
	JavaScriptBridge.eval("window.__MATCHSTICK_QA_COMMAND__ = '';")
	match command:
		"start":
			level_index = 0
			round_choice_index = 0
			_start_game()
		"reset":
			_reset_move()
		"check":
			_check()
		"skip":
			_skip()
		"top":
			_go_top()
		"sound":
			_cycle_audio()
		"qa_pick":
			_qa_hit("pick")
		"qa_place":
			_qa_hit("place")
		_:
			pass

func _publish_qa() -> void:
	if not qa_mode or OS.get_name() != "Web":
		return
	var state := {
		"ready": true,
		"build": BUILD_ID,
		"screen": screen,
		"width": size.x,
		"height": size.y,
		"level": LEVELS[level_index],
		"rounds": _rounds(),
		"round": round_index,
		"score": score,
		"moved": moved,
		"carry": carry_pos >= 0,
		"feedback": feedback,
		"audio": _audio_label(),
		"quality_target": 82,
	}
	if qa_solution_points.has("pick") and qa_solution_points.has("place"):
		var pick: Vector2 = qa_solution_points["pick"]
		var place: Vector2 = qa_solution_points["place"]
		state["solution"] = {"pick_x": pick.x, "pick_y": pick.y, "place_x": place.x, "place_y": place.y}
	var payload := JSON.stringify(state)
	JavaScriptBridge.eval("window.__MATCHSTICK_QA__ = " + payload + ";")
