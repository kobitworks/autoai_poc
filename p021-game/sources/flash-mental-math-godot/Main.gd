extends Control

# GAME-059 / GAME-G012 Flash Mental Math Godot redesign

const STAGE_NAMES := [
	"ADD ONLY",
	"ADD + TRAPS",
	"ADD / SUB",
	"ADD / SUB + TRAPS",
	"FOUR OPS + TRAPS",
]
const ROUND_OPTIONS := [1,2,3,4,5,6,7,8,9,10]
const TRAPS_ALPHA := ["A","B","C","D","E","F","G","H","J","K","M","N","P","R","S","T","U","V","W","X","Y","Z"]
const TRAPS_HIRA := ["あ","い","う","え","お","か","き","く","け","こ","さ","し","す","せ","そ","た","ち","つ","て","と"]
const TRAPS_KATA := ["ア","イ","ウ","エ","オ","カ","キ","ク","ケ","コ","サ","シ","ス","セ","ソ","タ","チ","ツ","テ","ト"]
const TRAPS_KANJI := ["未","末","土","士","口","日","目","自","木","本","千","干","申","甲","白","百","右","石"]

var stage := 1
var level := 1
var total_rounds := 3
var round_no := 1
var correct_count := 0
var miss_count := 0
var streak := 0
var best_streak := 0
var current_answer := 0
var answer_input := ""
var phase := "idle"
var qa_mode := false
var sound_on := true
var run_id := 0
var start_ms := 0
var elapsed_ms := 0
var current_tokens: Array = []
var best_records: Dictionary = {}
var rng := RandomNumberGenerator.new()

var ui_font: Font
var root_margin: MarginContainer
var content_grid: GridContainer
var arena_panel: PanelContainer
var config_panel: PanelContainer
var phase_label: Label
var token_label: Label
var progress_label: Label
var answer_label: Label
var feedback_label: Label
var keypad: GridContainer
var submit_button: Button
var stage_button: Button
var level_button: Button
var rounds_button: Button
var start_button: Button
var sound_button: Button
var best_label: Label
var rule_label: Label
var result_layer: Control
var result_title: Label
var result_detail: Label
var audio_player: AudioStreamPlayer
var tone_tick: AudioStreamWAV
var tone_ok: AudioStreamWAV
var tone_bad: AudioStreamWAV
var tone_clear: AudioStreamWAV

func _ready() -> void:
	_load_font()
	_load_storage()
	if OS.get_name() == "Web":
		var q = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true)
		qa_mode = bool(q)
	_build_ui()
	_setup_audio()
	_update_config_labels()
	_set_idle()
	set_process(true)
	call_deferred("_apply_responsive_layout")
	call_deferred("_update_debug_bridge")

func _process(_delta: float) -> void:
	if phase != "idle" and phase != "result":
		elapsed_ms = Time.get_ticks_msec() - start_ms
	if OS.get_name() == "Web":
		_update_debug_bridge()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_apply_responsive_layout")
		call_deferred("_update_debug_bridge")

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var e = event as InputEventKey
	if not e.pressed or e.echo:
		return

	if e.keycode == KEY_M:
		_toggle_sound()
		get_viewport().set_input_as_handled()
		return

	if qa_mode and e.keycode == KEY_F and phase == "answer":
		_qa_submit_correct()
		get_viewport().set_input_as_handled()
		return
	if qa_mode and e.keycode == KEY_X and phase == "answer":
		_qa_submit_wrong()
		get_viewport().set_input_as_handled()
		return

	if phase == "answer":
		if e.keycode >= KEY_0 and e.keycode <= KEY_9:
			_append_digit(int(e.keycode - KEY_0))
		elif e.keycode == KEY_MINUS:
			_toggle_sign()
		elif e.keycode == KEY_BACKSPACE:
			_backspace()
		elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
			_submit_answer()
		elif e.keycode == KEY_ESCAPE:
			_clear_answer()
		else:
			return
		get_viewport().set_input_as_handled()
		return

	if phase == "idle" or phase == "result":
		match e.keycode:
			KEY_S:
				_cycle_stage()
			KEY_L:
				_cycle_level()
			KEY_R:
				_cycle_rounds()
			KEY_N, KEY_ENTER:
				_start_game()
			_:
				return
		get_viewport().set_input_as_handled()

func _load_font() -> void:
	var loaded = load("res://fonts/NotoSansJP.ttf")
	if loaded is Font:
		ui_font = loaded
	else:
		ui_font = ThemeDB.fallback_font

func _load_storage() -> void:
	if FileAccess.file_exists("user://flash-math-records.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://flash-math-records.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			best_records = parsed

func _save_storage() -> void:
	var f = FileAccess.open("user://flash-math-records.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(best_records))

func _build_ui() -> void:
	var theme = Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 15
	self.theme = theme

	var bg = ColorRect.new()
	bg.color = Color("#050916")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var glow_left = ColorRect.new()
	glow_left.color = Color("#0a2746")
	glow_left.position = Vector2(-120, -80)
	glow_left.size = Vector2(530, 250)
	glow_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_left)

	var glow_right = ColorRect.new()
	glow_right.color = Color("#201342")
	glow_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	glow_right.position = Vector2(-430, -190)
	glow_right.size = Vector2(500, 260)
	glow_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_right)

	root_margin = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 10)
	root_margin.add_theme_constant_override("margin_right", 10)
	root_margin.add_theme_constant_override("margin_top", 8)
	root_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(root_margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root_margin.add_child(root)

	var top = HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 46)
	top.add_theme_constant_override("separation", 7)
	root.add_child(top)

	var hub = _make_button("HUB", "ghost")
	hub.custom_minimum_size = Vector2(58, 40)
	hub.pressed.connect(_go_home)
	top.add_child(hub)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", -2)
	top.add_child(title_box)

	var title = Label.new()
	title.text = "FLASH MENTAL MATH"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f8fbff"))
	title_box.add_child(title)

	var sub = Label.new()
	sub.text = "SEE · HOLD · CALCULATE"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("#67e8f9"))
	title_box.add_child(sub)

	sound_button = _make_button("SOUND ON", "ghost")
	sound_button.custom_minimum_size = Vector2(92, 40)
	sound_button.pressed.connect(_toggle_sound)
	top.add_child(sound_button)

	content_grid = GridContainer.new()
	content_grid.columns = 1
	content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.add_theme_constant_override("h_separation", 8)
	content_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(content_grid)

	arena_panel = PanelContainer.new()
	arena_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_panel.add_theme_stylebox_override("panel", _panel_style(Color("#08142a"), Color("#155e75"), 20, 1))
	content_grid.add_child(arena_panel)

	var arena_margin = MarginContainer.new()
	arena_margin.add_theme_constant_override("margin_left", 12)
	arena_margin.add_theme_constant_override("margin_right", 12)
	arena_margin.add_theme_constant_override("margin_top", 10)
	arena_margin.add_theme_constant_override("margin_bottom", 10)
	arena_panel.add_child(arena_margin)

	var arena = VBoxContainer.new()
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 7)
	arena_margin.add_child(arena)

	var arena_top = HBoxContainer.new()
	arena_top.add_theme_constant_override("separation", 8)
	arena.add_child(arena_top)

	phase_label = Label.new()
	phase_label.text = "READY"
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.add_theme_font_size_override("font_size", 11)
	phase_label.add_theme_color_override("font_color", Color("#67e8f9"))
	arena_top.add_child(phase_label)

	progress_label = Label.new()
	progress_label.text = "ROUND 0/3"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.add_theme_color_override("font_color", Color("#a5b4fc"))
	arena_top.add_child(progress_label)

	var token_panel = PanelContainer.new()
	token_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	token_panel.custom_minimum_size = Vector2(0, 150)
	token_panel.add_theme_stylebox_override("panel", _panel_style(Color("#071b31"), Color("#0e7490"), 22, 2))
	arena.add_child(token_panel)

	var token_center = CenterContainer.new()
	token_panel.add_child(token_center)

	token_label = Label.new()
	token_label.text = "READY"
	token_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	token_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	token_label.add_theme_font_size_override("font_size", 64)
	token_label.add_theme_color_override("font_color", Color("#f8fafc"))
	token_center.add_child(token_label)

	var answer_panel = PanelContainer.new()
	answer_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0c1730"), Color("#273e68"), 14, 1))
	arena.add_child(answer_panel)

	var answer_margin = MarginContainer.new()
	answer_margin.add_theme_constant_override("margin_left", 10)
	answer_margin.add_theme_constant_override("margin_right", 10)
	answer_margin.add_theme_constant_override("margin_top", 6)
	answer_margin.add_theme_constant_override("margin_bottom", 6)
	answer_panel.add_child(answer_margin)

	answer_label = Label.new()
	answer_label.text = "ANSWER  —"
	answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer_label.add_theme_font_size_override("font_size", 27)
	answer_label.add_theme_color_override("font_color", Color("#e2e8f0"))
	answer_margin.add_child(answer_label)

	keypad = GridContainer.new()
	keypad.columns = 3
	keypad.add_theme_constant_override("h_separation", 6)
	keypad.add_theme_constant_override("v_separation", 5)
	arena.add_child(keypad)
	for value in [7,8,9,4,5,6,1,2,3]:
		var digit = _make_button(str(value), "key")
		digit.custom_minimum_size = Vector2(58, 42)
		digit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		digit.pressed.connect(_append_digit.bind(value))
		keypad.add_child(digit)
	var sign_btn = _make_button("±", "key")
	sign_btn.custom_minimum_size = Vector2(58, 42)
	sign_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_btn.pressed.connect(_toggle_sign)
	keypad.add_child(sign_btn)
	var zero_btn = _make_button("0", "key")
	zero_btn.custom_minimum_size = Vector2(58, 42)
	zero_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zero_btn.pressed.connect(_append_digit.bind(0))
	keypad.add_child(zero_btn)
	var back_btn = _make_button("⌫", "key")
	back_btn.custom_minimum_size = Vector2(58, 42)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_backspace)
	keypad.add_child(back_btn)

	submit_button = _make_button("LOCK ANSWER", "primary")
	submit_button.custom_minimum_size = Vector2(0, 44)
	submit_button.pressed.connect(_submit_answer)
	arena.add_child(submit_button)

	feedback_label = Label.new()
	feedback_label.text = "Watch the stream. Ignore trap characters."
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 11)
	feedback_label.add_theme_color_override("font_color", Color("#94a3b8"))
	arena.add_child(feedback_label)

	config_panel = PanelContainer.new()
	config_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	config_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0a1022"), Color("#29365a"), 20, 1))
	content_grid.add_child(config_panel)

	var config_scroll = ScrollContainer.new()
	config_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	config_panel.add_child(config_scroll)

	var config_margin = MarginContainer.new()
	config_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_margin.add_theme_constant_override("margin_left", 12)
	config_margin.add_theme_constant_override("margin_right", 12)
	config_margin.add_theme_constant_override("margin_top", 10)
	config_margin.add_theme_constant_override("margin_bottom", 10)
	config_scroll.add_child(config_margin)

	var config = VBoxContainer.new()
	config.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config.add_theme_constant_override("separation", 7)
	config_margin.add_child(config)

	var kicker = Label.new()
	kicker.text = "MISSION CONTROL"
	kicker.add_theme_font_size_override("font_size", 9)
	kicker.add_theme_color_override("font_color", Color("#c084fc"))
	config.add_child(kicker)

	stage_button = _make_button("", "select")
	level_button = _make_button("", "select")
	rounds_button = _make_button("", "select")
	stage_button.pressed.connect(_cycle_stage)
	level_button.pressed.connect(_cycle_level)
	rounds_button.pressed.connect(_cycle_rounds)
	config.add_child(stage_button)
	config.add_child(level_button)
	config.add_child(rounds_button)

	start_button = _make_button("START RUN", "primary")
	start_button.custom_minimum_size = Vector2(0, 44)
	start_button.pressed.connect(_start_game)
	config.add_child(start_button)

	var stat_grid = GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 6)
	stat_grid.add_theme_constant_override("v_separation", 6)
	config.add_child(stat_grid)
	_make_stat(stat_grid, "CORRECT", "score_live")
	_make_stat(stat_grid, "STREAK", "streak_live")

	best_label = Label.new()
	best_label.text = "BEST  --"
	best_label.add_theme_font_size_override("font_size", 11)
	best_label.add_theme_color_override("font_color", Color("#93c5fd"))
	best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	config.add_child(best_label)

	rule_label = Label.new()
	rule_label.text = "Stage 1 add · 2 add+traps · 3 ± · 4 ±+traps · 5 four ops+traps\nKeys: S stage / L level / R rounds / N start / M sound"
	rule_label.add_theme_font_size_override("font_size", 10)
	rule_label.add_theme_color_override("font_color", Color("#64748b"))
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	config.add_child(rule_label)

	_build_result_layer()

func _make_stat(parent: Control, label_text: String, value_name: String) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101a33"), Color("#2a3d64"), 12, 1))
	parent.add_child(panel)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	margin.add_child(box)
	var lab = Label.new()
	lab.text = label_text
	lab.add_theme_font_size_override("font_size", 8)
	lab.add_theme_color_override("font_color", Color("#64748b"))
	box.add_child(lab)
	var val = Label.new()
	val.name = value_name
	val.text = "0"
	val.add_theme_font_size_override("font_size", 18)
	val.add_theme_color_override("font_color", Color("#f8fafc"))
	box.add_child(val)

func _stat(name_value: String) -> Label:
	return find_child(name_value, true, false) as Label

func _build_result_layer() -> void:
	result_layer = ColorRect.new()
	result_layer.color = Color(0.015, 0.025, 0.07, 0.91)
	result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.visible = false
	result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_layer)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(310, 245)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0d1833"), Color("#22d3ee"), 22, 2))
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	result_title = Label.new()
	result_title.text = "RUN COMPLETE"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 25)
	result_title.add_theme_color_override("font_color", Color("#67e8f9"))
	box.add_child(result_title)

	result_detail = Label.new()
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.add_theme_font_size_override("font_size", 13)
	result_detail.add_theme_color_override("font_color", Color("#e2e8f0"))
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result_detail)

	var again = _make_button("PLAY AGAIN", "primary")
	again.custom_minimum_size = Vector2(0, 45)
	again.pressed.connect(_start_game)
	box.add_child(again)

	var setup = _make_button("CHANGE SETTINGS", "ghost")
	setup.pressed.connect(_close_result)
	box.add_child(setup)

func _make_button(text_value: String, kind: String) -> Button:
	var b = Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 12)
	var normal = Color("#15203a")
	var hover = Color("#203456")
	var border = Color("#334a70")
	if kind == "primary":
		normal = Color("#075985")
		hover = Color("#0891b2")
		border = Color("#22d3ee")
	elif kind == "select":
		normal = Color("#111a31")
		hover = Color("#1b2a4c")
		border = Color("#3b4f79")
	elif kind == "key":
		normal = Color("#0d1b35")
		hover = Color("#18345e")
		border = Color("#294a73")
	b.add_theme_stylebox_override("normal", _panel_style(normal, border, 11, 1))
	b.add_theme_stylebox_override("hover", _panel_style(hover, Color("#67e8f9"), 11, 1))
	b.add_theme_stylebox_override("pressed", _panel_style(Color("#164e63"), Color("#cffafe"), 11, 2))
	b.add_theme_stylebox_override("disabled", _panel_style(Color("#111827"), Color("#263247"), 11, 1))
	b.add_theme_color_override("font_color", Color("#f8fafc"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_disabled_color", Color("#64748b"))
	return b

func _panel_style(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = width
	s.border_width_right = width
	s.border_width_top = width
	s.border_width_bottom = width
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_tick = _make_tone(520.0, 0.035, 0.09)
	tone_ok = _make_tone(760.0, 0.10, 0.18)
	tone_bad = _make_tone(180.0, 0.12, 0.15)
	tone_clear = _make_tone(980.0, 0.24, 0.18)

func _make_tone(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var rate = 22050
	var frames = int(float(rate) * duration)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var env = 1.0 - (float(i) / maxf(1.0, float(frames)))
		var wave = sin(TAU * freq * float(i) / float(rate))
		var sample = int(clamp(wave * env * amplitude, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream = AudioStreamWAV.new()
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

func _set_idle() -> void:
	run_id += 1
	phase = "idle"
	round_no = 1
	correct_count = 0
	miss_count = 0
	streak = 0
	best_streak = 0
	answer_input = ""
	token_label.text = "READY"
	phase_label.text = "READY / CONFIGURE YOUR RUN"
	feedback_label.text = "Watch the stream. Ignore trap characters."
	progress_label.text = "ROUND 0/%d" % total_rounds
	answer_label.text = "ANSWER  —"
	keypad.visible = false
	submit_button.visible = false
	result_layer.visible = false
	_update_stats()
	_update_controls()
	_update_best_label()
	_update_debug_bridge()

func _start_game() -> void:
	result_layer.visible = false
	run_id += 1
	round_no = 1
	correct_count = 0
	miss_count = 0
	streak = 0
	best_streak = 0
	elapsed_ms = 0
	start_ms = Time.get_ticks_msec()
	rng.randomize()
	_update_controls()
	_update_stats()
	_begin_round()

func _begin_round() -> void:
	var my_run = run_id
	phase = "countdown"
	answer_input = ""
	answer_label.text = "ANSWER  —"
	keypad.visible = false
	submit_button.visible = false
	feedback_label.text = "Lock in. The sequence starts now."
	progress_label.text = "ROUND %d/%d  ·  SCORE %d" % [round_no, total_rounds, correct_count]
	var built = _build_round()
	current_tokens = built["tokens"]
	current_answer = int(built["answer"])
	var params = built["params"]

	for n in [3,2,1]:
		if my_run != run_id:
			return
		token_label.text = str(n)
		phase_label.text = "FOCUS / %d" % n
		_pulse_token(Color("#a5f3fc"))
		await get_tree().create_timer(_delay(0.62)).timeout

	if my_run != run_id:
		return
	phase = "flash"
	phase_label.text = "FLASH STREAM / IGNORE TRAPS"
	for tok in current_tokens:
		if my_run != run_id:
			return
		token_label.text = str(tok["display"])
		token_label.add_theme_color_override("font_color", Color("#f8fafc") if not bool(tok.get("trap", false)) else Color("#c084fc"))
		_play(tone_tick)
		_pulse_token(Color("#ffffff"))
		await get_tree().create_timer(_delay(float(params["flash"]))).timeout
		if my_run != run_id:
			return
		token_label.text = "·"
		await get_tree().create_timer(_delay(float(params["gap"]))).timeout

	if my_run != run_id:
		return
	phase = "answer"
	token_label.text = "?"
	token_label.add_theme_color_override("font_color", Color("#67e8f9"))
	phase_label.text = "YOUR ANSWER"
	feedback_label.text = "Enter the total, then lock your answer."
	keypad.visible = true
	submit_button.visible = true
	_render_answer()
	_update_debug_bridge()

func _delay(seconds: float) -> float:
	if qa_mode:
		return minf(seconds, 0.035)
	return seconds

func _build_round() -> Dictionary:
	var params = _get_params()
	var base: Array = []
	var answer = 0

	if stage == 1 or stage == 2:
		for _i in range(int(params["count"])):
			var v = _make_number(int(params["digits"]))
			base.append({"display": str(v), "value": v, "trap": false})
			answer += v
	elif stage == 3 or stage == 4:
		for i in range(int(params["count"])):
			var sign = 1
			if i > 0 and rng.randf() < 0.48:
				sign = -1
			var v = _make_number(int(params["digits"]))
			base.append({"display": ("+" if sign > 0 else "-") + str(v), "value": sign * v, "trap": false})
			answer += sign * v
	else:
		var digits = mini(2, int(params["digits"]))
		var first = maxi(1, _make_number(digits))
		base.append({"display": str(first), "value": first, "trap": false})
		answer = first
		for _i in range(1, int(params["count"])):
			var ops = ["+","-","×","÷"]
			var op = str(ops[rng.randi_range(0, ops.size() - 1)])
			var operand = 0
			if op == "×":
				operand = rng.randi_range(2, 9)
				answer *= operand
			elif op == "÷":
				var divisors: Array = []
				var abs_answer = absi(answer)
				for d in range(2, 10):
					if abs_answer > 0 and abs_answer % d == 0:
						divisors.append(d)
				if divisors.is_empty():
					op = "+"
					operand = rng.randi_range(1, 9)
					answer += operand
				else:
					operand = int(divisors[rng.randi_range(0, divisors.size() - 1)])
					answer = int(answer / operand)
			elif op == "+":
				operand = _make_number(digits)
				answer += operand
			else:
				operand = _make_number(digits)
				answer -= operand
			base.append({"display": op + str(operand), "value": operand, "trap": false})

	var full = base.duplicate(true)
	var trap_count = int(params["traps"])
	for _i in range(trap_count):
		if full.size() < 2:
			break
		var pos = rng.randi_range(1, full.size() - 1)
		full.insert(pos, {"display": _trap_char(), "trap": true})
	return {"tokens": full, "answer": answer, "params": params}

func _get_params() -> Dictionary:
	var speeds = [0.70,0.56,0.44,0.34,0.25]
	var digits = 1
	if level == 2:
		digits = 2
	elif level >= 3:
		digits = mini(3, level)
	var count = 5 + level - 1
	if stage == 3 or stage == 4:
		count = 6 + level - 1
	elif stage == 5:
		count = mini(5, 3 + level - 1)
	var traps = 0
	if stage == 2 or stage == 4 or stage == 5:
		traps = mini(3, maxi(0, level - 2))
	return {
		"flash": speeds[level - 1],
		"gap": float(speeds[level - 1]) * 0.15,
		"digits": digits,
		"count": count,
		"traps": traps,
	}

func _make_number(digits: int) -> int:
	if digits <= 1:
		return rng.randi_range(0, 9)
	var min_value = int(pow(10.0, float(digits - 1)))
	var max_value = int(pow(10.0, float(digits))) - 1
	return rng.randi_range(min_value, max_value)

func _trap_char() -> String:
	var pool = TRAPS_ALPHA
	if stage == 5:
		pool = TRAPS_KANJI if level >= 3 else TRAPS_KATA
	elif level == 3:
		pool = TRAPS_HIRA
	elif level == 4:
		pool = TRAPS_KATA
	elif level >= 5:
		pool = TRAPS_KANJI
	return str(pool[rng.randi_range(0, pool.size() - 1)])

func _append_digit(value: int) -> void:
	if phase != "answer":
		return
	var negative = answer_input.begins_with("-")
	var body = answer_input.trim_prefix("-")
	if body.length() >= 10:
		return
	if body == "0":
		body = ""
	body += str(value)
	answer_input = ("-" if negative else "") + body
	_render_answer()

func _toggle_sign() -> void:
	if phase != "answer":
		return
	if answer_input.begins_with("-"):
		answer_input = answer_input.trim_prefix("-")
	else:
		answer_input = "-" + answer_input
	_render_answer()

func _backspace() -> void:
	if phase != "answer" or answer_input.is_empty():
		return
	answer_input = answer_input.substr(0, answer_input.length() - 1)
	_render_answer()

func _clear_answer() -> void:
	if phase != "answer":
		return
	answer_input = ""
	_render_answer()

func _render_answer() -> void:
	var shown = answer_input
	if shown.is_empty():
		shown = "0"
	answer_label.text = "ANSWER  %s" % shown

func _submit_answer(forced_value = null) -> void:
	if phase != "answer":
		return
	var given = 0
	if forced_value != null:
		given = int(forced_value)
	elif not answer_input.is_empty() and answer_input != "-":
		given = int(answer_input)
	var ok = given == current_answer
	if ok:
		correct_count += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		feedback_label.text = "PERFECT · +1  /  STREAK %d" % streak
		feedback_label.add_theme_color_override("font_color", Color("#6ee7b7"))
		_play(tone_ok)
	else:
		miss_count += 1
		streak = 0
		feedback_label.text = "MISS · ANSWER %d" % current_answer
		feedback_label.add_theme_color_override("font_color", Color("#fda4af"))
		_play(tone_bad)

	phase = "feedback"
	keypad.visible = false
	submit_button.visible = false
	token_label.text = "OK" if ok else "MISS"
	token_label.add_theme_color_override("font_color", Color("#6ee7b7") if ok else Color("#fb7185"))
	phase_label.text = "CORRECT" if ok else "CHECK"
	_update_stats()
	_update_debug_bridge()
	var my_run = run_id
	await get_tree().create_timer(_delay(0.65)).timeout
	if my_run != run_id:
		return
	if round_no >= total_rounds:
		_finish_game()
	else:
		round_no += 1
		_begin_round()

func _finish_game() -> void:
	phase = "result"
	elapsed_ms = Time.get_ticks_msec() - start_ms
	var key = _record_key()
	var previous = best_records.get(key, null)
	var is_best = false
	if previous == null or typeof(previous) != TYPE_DICTIONARY:
		is_best = true
	else:
		var prev_correct = int(previous.get("correct", -1))
		var prev_ms = int(previous.get("ms", 999999999))
		is_best = correct_count > prev_correct or (correct_count == prev_correct and elapsed_ms < prev_ms)
	if is_best:
		best_records[key] = {"correct": correct_count, "ms": elapsed_ms, "streak": best_streak}
		_save_storage()
	_play(tone_clear)
	_update_best_label()
	result_title.text = "RUN COMPLETE"
	var accuracy = int(round(100.0 * float(correct_count) / maxf(1.0, float(total_rounds))))
	result_detail.text = "SCORE %d / %d  ·  %d%%\nBEST STREAK %d  ·  %s\n%s" % [
		correct_count, total_rounds, accuracy, best_streak, _format_time(elapsed_ms),
		"NEW BEST" if is_best else "KEEP PUSHING"
	]
	result_layer.visible = true
	phase_label.text = "RESULT / %d OF %d" % [correct_count, total_rounds]
	token_label.text = "%d%%" % accuracy
	feedback_label.text = "Change settings or run the same challenge again."
	_update_controls()
	_update_stats()
	_update_debug_bridge()

func _record_key() -> String:
	return "s%d-l%d-r%d" % [stage, level, total_rounds]

func _format_time(ms: int) -> String:
	var total = maxi(0, int(float(ms) / 1000.0))
	return "%02d:%02d" % [int(total / 60), int(total % 60)]

func _update_stats() -> void:
	var score_label = _stat("score_live")
	var streak_label = _stat("streak_live")
	if score_label:
		score_label.text = "%d/%d" % [correct_count, total_rounds]
	if streak_label:
		streak_label.text = str(streak)
	progress_label.text = "ROUND %d/%d  ·  SCORE %d" % [mini(round_no, total_rounds), total_rounds, correct_count]

func _update_best_label() -> void:
	var record = best_records.get(_record_key(), null)
	if record == null or typeof(record) != TYPE_DICTIONARY:
		best_label.text = "BEST  --  / this setup"
		return
	best_label.text = "BEST  %d/%d · %s · streak %d" % [
		int(record.get("correct", 0)),
		total_rounds,
		_format_time(int(record.get("ms", 0))),
		int(record.get("streak", 0))
	]

func _cycle_stage() -> void:
	if phase != "idle" and phase != "result":
		return
	stage = (stage % 5) + 1
	_close_result()
	_update_config_labels()

func _cycle_level() -> void:
	if phase != "idle" and phase != "result":
		return
	level = (level % 5) + 1
	_close_result()
	_update_config_labels()

func _cycle_rounds() -> void:
	if phase != "idle" and phase != "result":
		return
	total_rounds = (total_rounds % 10) + 1
	_close_result()
	_update_config_labels()

func _update_config_labels() -> void:
	stage_button.text = "STAGE %d  ·  %s" % [stage, STAGE_NAMES[stage - 1]]
	var p = _get_params()
	level_button.text = "LEVEL %d  ·  %d digits / %.2fs" % [level, int(p["digits"]), float(p["flash"])]
	rounds_button.text = "ROUNDS %d  ·  higher score wins" % total_rounds
	sound_button.text = "SOUND ON" if sound_on else "SOUND OFF"
	_update_best_label()
	if phase == "idle":
		progress_label.text = "ROUND 0/%d" % total_rounds
	_update_debug_bridge()

func _update_controls() -> void:
	var locked = phase != "idle" and phase != "result"
	stage_button.disabled = locked
	level_button.disabled = locked
	rounds_button.disabled = locked
	start_button.disabled = locked
	start_button.text = "START RUN" if phase == "idle" or phase == "result" else "RUNNING…"

func _toggle_sound() -> void:
	sound_on = not sound_on
	sound_button.text = "SOUND ON" if sound_on else "SOUND OFF"
	if sound_on:
		_play(tone_tick)
	_update_debug_bridge()

func _close_result() -> void:
	if result_layer:
		result_layer.visible = false
	if phase == "result":
		phase = "idle"
		token_label.text = "READY"
		phase_label.text = "READY / CONFIGURE YOUR RUN"
		feedback_label.text = "Watch the stream. Ignore trap characters."
		answer_label.text = "ANSWER  —"
		keypad.visible = false
		submit_button.visible = false
		_update_controls()
		_update_stats()

func _pulse_token(color_value: Color) -> void:
	token_label.modulate = Color(1,1,1,0.72)
	var tween = create_tween()
	tween.tween_property(token_label, "modulate", color_value, _delay(0.05))
	tween.tween_property(token_label, "modulate", Color.WHITE, _delay(0.08))

func _apply_responsive_layout() -> void:
	if not is_instance_valid(content_grid):
		return
	var size = get_viewport_rect().size
	var landscape = size.x > size.y * 1.28
	content_grid.columns = 2 if landscape else 1
	if landscape:
		arena_panel.custom_minimum_size = Vector2(maxf(420.0, size.x * 0.62), 0)
		config_panel.custom_minimum_size = Vector2(maxf(245.0, size.x * 0.29), 0)
		token_label.add_theme_font_size_override("font_size", 56 if size.y < 480 else 68)
		for child in keypad.get_children():
			if child is Button:
				(child as Button).custom_minimum_size.y = 34 if size.y < 480 else 42
	else:
		arena_panel.custom_minimum_size = Vector2(0, maxf(430.0, size.y * 0.54))
		config_panel.custom_minimum_size = Vector2(0, 230)
		token_label.add_theme_font_size_override("font_size", 64 if size.x < 500 else 76)
		for child in keypad.get_children():
			if child is Button:
				(child as Button).custom_minimum_size.y = 42
	call_deferred("_update_debug_bridge")

func _go_home() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)

func _qa_submit_correct() -> void:
	if not qa_mode or phase != "answer":
		return
	answer_input = str(current_answer)
	_render_answer()
	_submit_answer(current_answer)

func _qa_submit_wrong() -> void:
	if not qa_mode or phase != "answer":
		return
	var wrong = current_answer + 1
	answer_input = str(wrong)
	_render_answer()
	_submit_answer(wrong)

func _update_debug_bridge() -> void:
	if OS.get_name() != "Web":
		return
	var payload = {
		"ready": true,
		"engine": "Godot",
		"build": "GAME-059",
		"qa_mode": qa_mode,
		"viewport_w": int(get_viewport_rect().size.x),
		"viewport_h": int(get_viewport_rect().size.y),
		"stage": stage,
		"level": level,
		"rounds": total_rounds,
		"round": round_no,
		"correct": correct_count,
		"miss": miss_count,
		"streak": streak,
		"best_streak": best_streak,
		"phase": phase,
		"sound": sound_on,
		"answer_input": answer_input,
		"qa_answer": current_answer if qa_mode else 0,
		"finished": phase == "result"
	}
	JavaScriptBridge.eval("window.__P021_FLASH_MATH = %s;" % JSON.stringify(payload), true)
