extends Control

# GAME-064 / GAME-G029 Jigsaw Godot Web integration.
const BUILD_ID := "GAME-064-20261011"
const CHILD_ID := "GAME-G029"
const SAVE_PATH := "user://jigsaw-best.json"
const HUB_URL := "../../"
const Logic = preload("res://JigsawLogic.gd")

const GRID_CHOICES := [3, 4, 5, 6, 7]
const ART_PATHS := [
	"res://assets/aurora.svg",
	"res://assets/harbor.svg",
	"res://assets/garden.svg",
	"res://assets/city.svg",
]
const ART_NAMES := ["AURORA", "HARBOR", "GARDEN", "CITY NIGHT"]

var logic = Logic.new()
var ui_font: Font
var textures: Array = []
var state := "top"
var grid_size := 3
var art_index := 0
var pieces: Array = []
var selected_piece := -1
var moves := 0
var hints := 0
var elapsed_ms := 0
var start_ticks := 0
var last_score := 0
var best_records: Dictionary = {}
var feedback := "絵と難易度を選んでスタート"
var feedback_kind := "neutral"
var feedback_timer := 0.0
var hint_timer := 0.0
var time_acc := 0.0
var board_rect := Rect2()
var buttons: Dictionary = {}
var qa_mode := false
var qa_tick := 0.0

var audio_player: AudioStreamPlayer
var tone_pick: AudioStreamWAV
var tone_swap: AudioStreamWAV
var tone_hint: AudioStreamWAV
var tone_clear: AudioStreamWAV
var audio_level := 0
var audio_enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		ui_font = load("res://fonts/NotoSansJP.ttf")
	else:
		ui_font = ThemeDB.fallback_font
	for path in ART_PATHS:
		if ResourceLoader.exists(path):
			textures.append(load(path))
		else:
			textures.append(null)
	_load_storage()
	_setup_audio()
	if OS.get_name() == "Web":
		qa_mode = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true))
	grab_focus()
	set_process(true)
	queue_redraw()
	call_deferred("_publish_qa")

func _process(delta: float) -> void:
	if state == "game":
		elapsed_ms = maxi(0, Time.get_ticks_msec() - start_ticks)
		time_acc += delta
		if time_acc >= 0.10:
			time_acc = 0.0
			queue_redraw()
	if hint_timer > 0.0:
		hint_timer = maxf(0.0, hint_timer - delta)
		queue_redraw()
	if feedback_timer > 0.0:
		feedback_timer = maxf(0.0, feedback_timer - delta)
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
	return "%dx%d:art%d" % [grid_size, grid_size, art_index]

func _best() -> int:
	return int(best_records.get(_best_key(), 0))

func _save_best() -> void:
	var key := _best_key()
	best_records[key] = maxi(int(best_records.get(key, 0)), last_score)
	_save_storage()

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_pick = _make_tone(520.0, 0.055, 0.14)
	tone_swap = _make_tone(690.0, 0.075, 0.15)
	tone_hint = _make_tone(880.0, 0.09, 0.12)
	tone_clear = _make_chord()
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
	var duration := 0.42
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := 1.0 - float(i) / maxf(1.0, float(frames))
		var wave := (sin(TAU * 523.25 * t) + sin(TAU * 659.25 * t) * 0.78 + sin(TAU * 783.99 * t) * 0.62) / 2.4
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

func _start_game() -> void:
	state = "game"
	selected_piece = -1
	moves = 0
	hints = 0
	elapsed_ms = 0
	last_score = 0
	hint_timer = 0.0
	feedback = "ピースを1つ選び、入れ替え先をタップ"
	feedback_kind = "neutral"
	var seed_value := 64029 if qa_mode else int(Time.get_unix_time_from_system()) + Time.get_ticks_msec()
	pieces = logic.shuffled(grid_size, seed_value)
	start_ticks = Time.get_ticks_msec()
	queue_redraw()
	call_deferred("_publish_qa")

func _retry() -> void:
	_start_game()

func _go_top() -> void:
	state = "top"
	selected_piece = -1
	hint_timer = 0.0
	feedback = "絵と難易度を選んでスタート"
	feedback_kind = "neutral"
	queue_redraw()
	_publish_qa()

func _go_hub() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)
	else:
		OS.shell_open(HUB_URL)

func _hint() -> void:
	if state != "game":
		return
	hints += 1
	hint_timer = 1.45
	feedback = "完成図を表示中 · HINT -500"
	feedback_kind = "hint"
	_play(tone_hint)
	queue_redraw()
	_publish_qa()

func _swap_piece(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= pieces.size() or b >= pieces.size() or a == b:
		return
	var tmp = pieces[a]
	pieces[a] = pieces[b]
	pieces[b] = tmp
	moves += 1
	selected_piece = -1
	feedback = "SWAP %d · 正しい位置 %d/%d" % [moves, _correct_count(), pieces.size()]
	feedback_kind = "neutral"
	_play(tone_swap)
	if logic.is_solved(pieces):
		_finish_game()
	else:
		queue_redraw()
		_publish_qa()

func _finish_game() -> void:
	if state != "game":
		return
	elapsed_ms = maxi(1, Time.get_ticks_msec() - start_ticks)
	last_score = logic.score(grid_size, elapsed_ms, moves, hints)
	_save_best()
	state = "result"
	selected_piece = -1
	hint_timer = 0.0
	feedback = "PUZZLE COMPLETE"
	feedback_kind = "ok"
	_play(tone_clear)
	queue_redraw()
	call_deferred("_publish_qa")

func _correct_count() -> int:
	var count := 0
	for i in range(pieces.size()):
		if int(pieces[i]) == i:
			count += 1
	return count

func _format_time(ms: int) -> String:
	var total := maxi(0, int(float(ms) / 1000.0))
	var min_part := int(total / 60)
	var sec_part := int(total % 60)
	return "%02d:%02d" % [min_part, sec_part]

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
	var bg := Color("#132B43")
	var border := Color("#2B536A")
	var color := Color("#DCEAF1")
	if primary:
		bg = Color("#087F75")
		border = Color("#4FE4C9")
		color = Color.WHITE
	if selected:
		bg = Color("#153D58")
		border = Color("#67E8F9")
		color = Color("#F0FDFF")
	if disabled:
		bg = Color("#172531")
		border = Color("#273846")
		color = Color("#657784")
	_rounded(rect, bg, 12.0, border, 1)
	_label(text, rect.position.x + 4.0, rect.position.y + rect.size.y * 0.65, rect.size.x - 8.0, 13, color)

func _draw() -> void:
	buttons.clear()
	board_rect = Rect2()
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("#061524"))
	draw_circle(Vector2(w * 0.88, h * 0.08), minf(w, h) * 0.28, Color(0.10, 0.63, 0.73, 0.12))
	draw_circle(Vector2(w * 0.08, h * 0.92), minf(w, h) * 0.30, Color(0.16, 0.76, 0.55, 0.09))
	if state == "top":
		_draw_top()
	elif state == "game":
		_draw_game()
	else:
		_draw_result()

func _draw_header(title: String, subtitle: String = "") -> float:
	var w := size.x
	var compact := size.y < 520.0
	var y := 9.0 if compact else 18.0
	_button("hub", Rect2(10.0, y, 66.0, 38.0), "← HUB")
	_button("audio", Rect2(w - 125.0, y, 115.0, 38.0), _audio_label())
	_label(title, 82.0, y + 28.0, w - 213.0, 22 if compact else 26, Color("#F0F8FC"))
	if subtitle != "" and not compact:
		_label(subtitle, 18.0, y + 58.0, w - 36.0, 12, Color("#89A6B6"))
	return y + (48.0 if compact else 72.0)

func _draw_top() -> void:
	var w := size.x
	var h := size.y
	var compact := h < 520.0
	var top := _draw_header("JIGSAW", "絵を分解して、タップ2回で元の景色へ戻そう")
	var margin := clampf(w * 0.035, 10.0, 24.0)
	var card := Rect2(margin, top + 4.0, w - margin * 2.0, h - top - margin - 4.0)
	_rounded(card, Color("#0B2236"), 22.0, Color("#1D4961"), 1)
	var x := card.position.x + 16.0
	var inner_w := card.size.x - 32.0
	var y := card.position.y + (22.0 if compact else 30.0)
	_label("GRID SIZE", x, y, inner_w, 11, Color("#67E8F9"), false)
	y += 10.0
	var gap := 6.0
	var bw := (inner_w - gap * 4.0) / 5.0
	for i in range(GRID_CHOICES.size()):
		var value := int(GRID_CHOICES[i])
		_button("grid_%d" % value, Rect2(x + float(i) * (bw + gap), y, bw, 40.0), "%d×%d" % [value, value], false, grid_size == value)
	y += 56.0
	_label("PUZZLE ART", x, y, inner_w, 11, Color("#67E8F9"), false)
	y += 10.0
	var cols := 4 if w >= 700.0 else 2
	var rows := int(ceil(float(ART_NAMES.size()) / float(cols)))
	var art_gap := 7.0
	var art_w := (inner_w - art_gap * float(cols - 1)) / float(cols)
	var art_h := 64.0 if compact else 86.0
	for i in range(ART_NAMES.size()):
		var col := i % cols
		var row := int(i / cols)
		var rect := Rect2(x + float(col) * (art_w + art_gap), y + float(row) * (art_h + art_gap), art_w, art_h)
		_draw_art_button(i, rect)
	y += float(rows) * art_h + float(maxi(0, rows - 1)) * art_gap + 14.0
	_button("start", Rect2(x, y, inner_w, 48.0 if compact else 52.0), "PUZZLE START", true)
	y += 65.0 if compact else 76.0
	if y < card.end.y - 16.0:
		_label("ピースを1つ選ぶ → 入れ替え先をタップ · HINTで完成図を1.45秒表示", x, y, inner_w, 11 if compact else 12, Color("#9CB3C1"))

func _draw_art_button(index: int, rect: Rect2) -> void:
	buttons["art_%d" % index] = rect
	_rounded(rect, Color("#102C43"), 12.0, Color("#67E8F9") if art_index == index else Color("#2A5369"), 2 if art_index == index else 1)
	var tex = textures[index] if index < textures.size() else null
	var image_rect := Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6.0, rect.size.y - 24.0))
	if tex != null:
		draw_texture_rect(tex, image_rect, false, Color(1, 1, 1, 0.92))
	else:
		draw_rect(image_rect, Color("#23465E"))
	_rounded(Rect2(rect.position.x + 3.0, rect.end.y - 24.0, rect.size.x - 6.0, 21.0), Color(0.02, 0.08, 0.13, 0.88), 7.0)
	_label(ART_NAMES[index], rect.position.x + 6.0, rect.end.y - 8.0, rect.size.x - 12.0, 10, Color("#F0FAFC"))

func _draw_game() -> void:
	var w := size.x
	var h := size.y
	var compact := h < 520.0
	var top := _draw_header("JIGSAW")
	var margin := clampf(w * 0.025, 8.0, 16.0)
	var stats_y := top + 2.0
	var stats_h := 40.0
	_rounded(Rect2(margin, stats_y, w - margin * 2.0, stats_h), Color("#0B2236"), 13.0, Color("#214A61"), 1)
	_label("%d×%d" % [grid_size, grid_size], margin + 10.0, stats_y + 27.0, (w - margin * 2.0) * 0.20, 14, Color("#67E8F9"), false)
	_label("TIME %s" % _format_time(elapsed_ms), w * 0.25, stats_y + 27.0, w * 0.28, 14, Color("#E8F3F7"))
	_label("MOVES %d" % moves, w * 0.56, stats_y + 27.0, w * 0.25, 14, Color("#FBD38D"))
	_label("%d/%d" % [_correct_count(), pieces.size()], w * 0.82, stats_y + 27.0, w * 0.15 - margin, 12, Color("#A7F3D0"))
	var controls_h := 58.0
	var controls_y := h - controls_h - 7.0
	var board_top := stats_y + stats_h + 9.0
	var board_bottom := controls_y - 9.0
	var max_board_w := w - margin * 2.0
	var max_board_h := board_bottom - board_top
	var side := floor(minf(max_board_w, max_board_h))
	board_rect = Rect2((w - side) * 0.5, board_top + maxf(0.0, (max_board_h - side) * 0.5), side, side)
	_draw_board()
	var feedback_color := Color("#8FA9B9")
	if feedback_kind == "ok":
		feedback_color = Color("#65E5B0")
	elif feedback_kind == "hint":
		feedback_color = Color("#FBD38D")
	var feedback_y := board_rect.position.y - 5.0
	if board_rect.position.y - board_top > 24.0:
		_label(feedback, margin, feedback_y, w - margin * 2.0, 11, feedback_color)
	var gap := 7.0
	var third := (w - margin * 2.0 - gap * 2.0) / 3.0
	_button("hint", Rect2(margin, controls_y, third, 48.0), "HINT")
	_button("retry", Rect2(margin + third + gap, controls_y, third, 48.0), "RETRY")
	_button("top", Rect2(margin + (third + gap) * 2.0, controls_y, third, 48.0), "ART / GRID")
	if compact and board_rect.size.x < 230.0:
		_label("tap 2 pieces to swap", board_rect.position.x, board_rect.end.y + 12.0, board_rect.size.x, 9, Color("#7E99A8"))

func _draw_board() -> void:
	if pieces.is_empty() or board_rect.size.x <= 0.0:
		return
	var tex = textures[art_index] if art_index < textures.size() else null
	var cell := board_rect.size.x / float(grid_size)
	var tex_size := Vector2(720, 720)
	if tex != null:
		tex_size = tex.get_size()
	var src_cell := Vector2(tex_size.x / float(grid_size), tex_size.y / float(grid_size))
	_rounded(board_rect.grow(5.0), Color("#07101A"), 12.0, Color("#315B6F"), 1)
	for slot in range(pieces.size()):
		var dest_col := slot % grid_size
		var dest_row := int(slot / grid_size)
		var piece := int(pieces[slot])
		var src_col := piece % grid_size
		var src_row := int(piece / grid_size)
		var dest := Rect2(
			board_rect.position.x + float(dest_col) * cell + 1.5,
			board_rect.position.y + float(dest_row) * cell + 1.5,
			cell - 3.0,
			cell - 3.0
		)
		if tex != null:
			var src := Rect2(float(src_col) * src_cell.x, float(src_row) * src_cell.y, src_cell.x, src_cell.y)
			draw_texture_rect_region(tex, dest, src)
		else:
			var hue := float(piece) / maxf(1.0, float(pieces.size()))
			draw_rect(dest, Color.from_hsv(hue, 0.55, 0.80))
		var border := Color(0.75, 0.93, 1.0, 0.26)
		var width := 1.0
		if slot == selected_piece:
			border = Color("#67E8F9")
			width = 4.0
		elif piece == slot:
			border = Color(0.35, 0.95, 0.68, 0.48)
			width = 2.0
		draw_rect(dest, border, false, width)
	if hint_timer > 0.0 and tex != null:
		draw_rect(board_rect, Color(0.02, 0.07, 0.12, 0.30))
		draw_texture_rect(tex, board_rect.grow(-6.0), false, Color(1, 1, 1, 0.82))
		for n in range(1, grid_size):
			var px := board_rect.position.x + float(n) * cell
			var py := board_rect.position.y + float(n) * cell
			draw_line(Vector2(px, board_rect.position.y), Vector2(px, board_rect.end.y), Color(1,1,1,0.34), 1.0)
			draw_line(Vector2(board_rect.position.x, py), Vector2(board_rect.end.x, py), Color(1,1,1,0.34), 1.0)
		_rounded(Rect2(board_rect.position + Vector2(10,10), Vector2(118,28)), Color(0.02,0.08,0.13,0.86), 10.0)
		_label("HINT / COMPLETE", board_rect.position.x + 16.0, board_rect.position.y + 30.0, 106.0, 10, Color("#FDE68A"))

func _draw_result() -> void:
	var w := size.x
	var h := size.y
	var compact := h < 520.0
	var top := _draw_header("PUZZLE COMPLETE")
	var margin := clampf(w * 0.05, 14.0, 34.0)
	var card := Rect2(margin, top + 5.0, w - margin * 2.0, h - top - margin - 5.0)
	_rounded(card, Color("#0B2236"), 22.0, Color("#2C6175"), 1)
	var thumb_side := minf(card.size.x * (0.27 if w > 650 else 0.42), card.size.y * (0.42 if compact else 0.30))
	if not compact:
		thumb_side = minf(190.0, thumb_side + 30.0)
	var tex = textures[art_index] if art_index < textures.size() else null
	var thumb := Rect2(card.position.x + (card.size.x - thumb_side) * 0.5, card.position.y + 18.0, thumb_side, thumb_side)
	if compact and w > 650:
		thumb = Rect2(card.position.x + 18.0, card.position.y + 18.0, thumb_side, thumb_side)
	if tex != null:
		draw_texture_rect(tex, thumb, false)
	_rounded(thumb.grow(2.0), Color.TRANSPARENT, 10.0, Color("#67E8F9"), 2)
	var info_y := thumb.end.y + 34.0
	var info_x := card.position.x + 12.0
	var info_w := card.size.x - 24.0
	if compact and w > 650:
		info_x = thumb.end.x + 24.0
		info_w = card.end.x - info_x - 16.0
		info_y = card.position.y + 48.0
	_label("SCORE", info_x, info_y, info_w, 12, Color("#8FAABD"))
	info_y += 48.0
	_label(str(last_score), info_x, info_y, info_w, 38 if compact else 48, Color("#67E8F9"))
	info_y += 36.0
	_label("BEST %d" % _best(), info_x, info_y, info_w, 16, Color("#FDE68A"))
	info_y += 30.0
	_label("%d×%d · %s · %d MOVES · %d HINT" % [grid_size, grid_size, _format_time(elapsed_ms), moves, hints], info_x, info_y, info_w, 12, Color("#A7BBC6"))
	var by := card.end.y - 58.0
	var gap := 8.0
	var bw := (card.size.x - 32.0 - gap) / 2.0
	_button("restart", Rect2(card.position.x + 16.0, by, bw, 46.0), "PLAY AGAIN", true)
	_button("top", Rect2(card.position.x + 16.0 + bw + gap, by, bw, 46.0), "ART / GRID")

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
	if state == "game" and _handle_board(point):
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
		elif k == "hint":
			_hint()
		elif k == "retry":
			_retry()
		elif k == "restart":
			_retry()
		elif k == "top":
			_go_top()
		elif k.begins_with("grid_"):
			grid_size = clampi(int(k.trim_prefix("grid_")), 3, 7)
			queue_redraw()
		elif k.begins_with("art_"):
			art_index = clampi(int(k.trim_prefix("art_")), 0, ART_NAMES.size() - 1)
			queue_redraw()
		else:
			return false
		if audio_enabled and k != "audio" and k != "hint" and k != "retry" and k != "restart":
			_play(tone_pick)
		_publish_qa()
		return true
	return false

func _handle_board(point: Vector2) -> bool:
	if not board_rect.has_point(point) or pieces.is_empty():
		return false
	var cell := board_rect.size.x / float(grid_size)
	var local := point - board_rect.position
	var col := clampi(int(floor(local.x / cell)), 0, grid_size - 1)
	var row := clampi(int(floor(local.y / cell)), 0, grid_size - 1)
	var slot := row * grid_size + col
	if selected_piece < 0:
		selected_piece = slot
		feedback = "選択中 · 入れ替え先をタップ"
		feedback_kind = "neutral"
		_play(tone_pick)
		queue_redraw()
		_publish_qa()
		return true
	if selected_piece == slot:
		selected_piece = -1
		feedback = "選択を解除しました"
		queue_redraw()
		_publish_qa()
		return true
	_swap_piece(selected_piece, slot)
	return true

func _poll_qa_command() -> void:
	if not qa_mode or OS.get_name() != "Web":
		return
	var raw = JavaScriptBridge.eval("(function(){var c=window.__P021_JIGSAW_COMMAND;if(!c){return '';}window.__P021_JIGSAW_COMMAND=null;return JSON.stringify(c);})()", true)
	if typeof(raw) != TYPE_STRING or String(raw) == "":
		return
	var parsed = JSON.parse_string(String(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var action := String(parsed.get("action", ""))
	if action == "set_grid":
		grid_size = clampi(int(parsed.get("value", 3)), 3, 7)
		queue_redraw()
	elif action == "set_art":
		art_index = clampi(int(parsed.get("value", 0)), 0, ART_NAMES.size() - 1)
		queue_redraw()
	elif action == "start":
		_start_game()
	elif action == "hint":
		_hint()
	elif action == "audio":
		_cycle_audio()
	elif action == "retry":
		_retry()
	elif action == "top":
		_go_top()
	elif action == "solve" and state == "game":
		pieces.clear()
		for i in range(grid_size * grid_size):
			pieces.append(i)
		moves = maxi(moves, grid_size + 2)
		elapsed_ms = maxi(elapsed_ms, 1800)
		start_ticks = Time.get_ticks_msec() - elapsed_ms
		_finish_game()
	_publish_qa()

func _publish_qa() -> void:
	if not qa_mode or OS.get_name() != "Web":
		return
	var payload := {
		"ready": true,
		"build": BUILD_ID,
		"child_id": CHILD_ID,
		"state": state,
		"viewport_w": int(get_viewport_rect().size.x),
		"viewport_h": int(get_viewport_rect().size.y),
		"grid": grid_size,
		"art": art_index,
		"moves": moves,
		"hints": hints,
		"elapsed_ms": elapsed_ms,
		"score": last_score,
		"best": _best(),
		"sound": _audio_label(),
		"solved": (not pieces.is_empty() and logic.is_solved(pieces)),
		"correct": _correct_count(),
		"piece_count": pieces.size(),
		"board": {
			"x": int(board_rect.position.x),
			"y": int(board_rect.position.y),
			"w": int(board_rect.size.x),
			"h": int(board_rect.size.y),
		},
	}
	JavaScriptBridge.eval("window.__P021_JIGSAW = %s;" % JSON.stringify(payload), true)
