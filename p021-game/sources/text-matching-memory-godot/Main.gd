extends Control

# GAME-058 / GAME-G011 Text Matching Memory Godot redesign

const LEVELS := [
	{"cols": 4, "rows": 3, "pairs": 6},
	{"cols": 5, "rows": 4, "pairs": 10},
	{"cols": 6, "rows": 4, "pairs": 12},
	{"cols": 6, "rows": 5, "pairs": 15},
]
const TIER_MIX := [
	Vector3(1.0, 0.0, 0.0),
	Vector3(0.7, 0.3, 0.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(0.0, 0.8, 0.2),
	Vector3(0.0, 0.0, 1.0),
]
const STAGE_LABELS := [
	"DIGITS",
	"ALPHABET",
	"DIGITS + ALPHABET",
	"ALPHA + SYMBOLS",
	"KANJI I",
	"KANJI I + MIX",
	"KANJI I-II + MIX",
	"KANJI I-III + MIX",
	"HANGUL",
	"ALL MIX",
]
const DIGITS := ["0","1","2","3","4","5","6","7","8","9"]
const ALPHABET := ["A","B","C","D","E","F","G","H","J","K","L","M","N","P","Q","R","S","T","U","V","W","X","Y","Z"]
const SYMBOLS := ["!","@","#","$","%","&","+","-","*","=","○","●","◎","□","■","△","▲","▽","▼","☆","★","◇","◆"]
const KANJI1_TEXT := "日一国人年大十二本中長出三同時行見月後前生五間上東四今金九入学高円子外八六下来気小七山話女北午百書先名川千水半男西電校語土木聞食車何南万毎白天母火右読友左休父雨京"
const KANJI2_TEXT := "愛案以位衣医因映英栄塩央横屋温化荷界開階寒感漢館岸起期客急級球究局去橋業曲銀苦具君係軽血決研県庫湖向幸港候航告差菜最材昨刷察参産算仕試資寺持時治辞式識質実写社者取酒受周宿祝術順初所暑助昭消商章勝乗植申身神真深進森整世席昔折説浅戦選然祖送早草争走足即存続卒貸隊代第題達単置注丁調直提転都度徳特毒届内熱念農倍買博半反番必表秒病品負部服福物分別編便勉味命明面問役薬由輸優予養楽利理旅料量輪類令礼和"
const KANJI3 := ["𠮟"]
const HANGUL := ["가","나","다","라","마","바","사","아","자","차","카","타","파","하","한","글","국","어","랑","학","교","세","상","기","억","추","빛","꿈"]

var level := 2
var stage := 2
var tier := 2
var qa_mode := false
var sound_on := true
var playing := false
var finished := false
var locked := false
var misses := 0
var turns := 0
var matched_pairs := 0
var start_ms := 0
var elapsed_ms := 0
var cards: Array = []
var open_indices: Array = []
var card_buttons: Array = []
var recent_seeds: Array = []
var best_records: Dictionary = {}
var rng := RandomNumberGenerator.new()

var ui_font: Font
var root_margin: MarginContainer
var content_grid: GridContainer
var board_panel: PanelContainer
var side_panel: PanelContainer
var board_grid: GridContainer
var level_button: Button
var stage_button: Button
var tier_button: Button
var start_button: Button
var sound_button: Button
var status_label: Label
var time_label: Label
var miss_label: Label
var turn_label: Label
var progress_label: Label
var best_label: Label
var result_layer: Control
var result_title: Label
var result_detail: Label
var audio_player: AudioStreamPlayer
var tone_flip: AudioStreamWAV
var tone_match: AudioStreamWAV
var tone_miss: AudioStreamWAV
var tone_clear: AudioStreamWAV

func _ready() -> void:
	_load_font()
	_load_storage()
	if OS.get_name() == "Web":
		var q = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true)
		qa_mode = bool(q)
	_build_ui()
	_setup_audio()
	_start_game()
	set_process(true)
	call_deferred("_apply_responsive_layout")
	call_deferred("_update_debug_bridge")

func _process(_delta: float) -> void:
	if playing and not finished:
		elapsed_ms = Time.get_ticks_msec() - start_ms
		time_label.text = _format_time(elapsed_ms)
	if OS.get_name() == "Web":
		_update_debug_bridge()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_apply_responsive_layout")
		call_deferred("_update_debug_bridge")

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			level = int(key_event.keycode - KEY_0)
			_start_game()
		KEY_S:
			stage = (stage % 10) + 1
			_start_game()
		KEY_T:
			tier = (tier % 5) + 1
			_start_game()
		KEY_M:
			_toggle_sound()
		KEY_R:
			_start_game()
		KEY_F:
			if qa_mode:
				_qa_finish()
			else:
				return
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
	if FileAccess.file_exists("user://memory-records.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://memory-records.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			best_records = parsed
	if FileAccess.file_exists("user://memory-seeds.json"):
		var parsed_seeds = JSON.parse_string(FileAccess.get_file_as_string("user://memory-seeds.json"))
		if typeof(parsed_seeds) == TYPE_ARRAY:
			recent_seeds = parsed_seeds

func _save_storage() -> void:
	var f := FileAccess.open("user://memory-records.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(best_records))
	var s := FileAccess.open("user://memory-seeds.json", FileAccess.WRITE)
	if s:
		s.store_string(JSON.stringify(recent_seeds.slice(0, 50)))

func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 15
	self.theme = theme

	var bg := ColorRect.new()
	bg.color = Color("#07101f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var glow_a := ColorRect.new()
	glow_a.color = Color("#102a50")
	glow_a.position = Vector2(-100, -80)
	glow_a.size = Vector2(520, 270)
	glow_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_a)

	var glow_b := ColorRect.new()
	glow_b.color = Color("#14213d")
	glow_b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	glow_b.position = Vector2(-360, -180)
	glow_b.size = Vector2(420, 220)
	glow_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_b)

	root_margin = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 10)
	root_margin.add_theme_constant_override("margin_right", 10)
	root_margin.add_theme_constant_override("margin_top", 8)
	root_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(root_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root_margin.add_child(root)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 46)
	top.add_theme_constant_override("separation", 7)
	root.add_child(top)

	var hub := _make_button("HUB", "ghost")
	hub.custom_minimum_size = Vector2(58, 40)
	hub.pressed.connect(_go_home)
	top.add_child(hub)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", -2)
	top.add_child(title_box)

	var title_label := Label.new()
	title_label.text = "TEXT MATCH"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("#f5f7ff"))
	title_box.add_child(title_label)

	var sub := Label.new()
	sub.text = "MEMORY GRID / GODOT"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("#7dd3fc"))
	title_box.add_child(sub)

	sound_button = _make_button("SOUND ON", "ghost")
	sound_button.custom_minimum_size = Vector2(90, 40)
	sound_button.pressed.connect(_toggle_sound)
	top.add_child(sound_button)

	content_grid = GridContainer.new()
	content_grid.columns = 1
	content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.add_theme_constant_override("h_separation", 8)
	content_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(content_grid)

	board_panel = PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0b1730"), Color("#284c7b"), 18, 1))
	content_grid.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 8)
	board_margin.add_theme_constant_override("margin_right", 8)
	board_margin.add_theme_constant_override("margin_top", 8)
	board_margin.add_theme_constant_override("margin_bottom", 8)
	board_panel.add_child(board_margin)

	board_grid = GridContainer.new()
	board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_grid.add_theme_constant_override("h_separation", 5)
	board_grid.add_theme_constant_override("v_separation", 5)
	board_margin.add_child(board_grid)

	side_panel = PanelContainer.new()
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0c1428"), Color("#25375c"), 18, 1))
	content_grid.add_child(side_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(scroll)

	var side_margin := MarginContainer.new()
	side_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_margin.add_theme_constant_override("margin_left", 12)
	side_margin.add_theme_constant_override("margin_right", 12)
	side_margin.add_theme_constant_override("margin_top", 10)
	side_margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(side_margin)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 7)
	side_margin.add_child(side)

	var kicker := Label.new()
	kicker.text = "CONFIG / LIVE RECORD"
	kicker.add_theme_font_size_override("font_size", 9)
	kicker.add_theme_color_override("font_color", Color("#38bdf8"))
	side.add_child(kicker)

	level_button = _make_button("", "select")
	stage_button = _make_button("", "select")
	tier_button = _make_button("", "select")
	level_button.pressed.connect(_cycle_level)
	stage_button.pressed.connect(_cycle_stage)
	tier_button.pressed.connect(_cycle_tier)
	side.add_child(level_button)
	side.add_child(stage_button)
	side.add_child(tier_button)

	start_button = _make_button("NEW SHUFFLE", "primary")
	start_button.custom_minimum_size = Vector2(0, 42)
	start_button.pressed.connect(_start_game)
	side.add_child(start_button)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 6)
	stats.add_theme_constant_override("v_separation", 6)
	side.add_child(stats)

	time_label = _make_stat(stats, "TIME", "00:00")
	miss_label = _make_stat(stats, "MISS", "0")
	turn_label = _make_stat(stats, "TURNS", "0")
	progress_label = _make_stat(stats, "PAIRS", "0/0")

	best_label = Label.new()
	best_label.text = "BEST  --"
	best_label.add_theme_font_size_override("font_size", 11)
	best_label.add_theme_color_override("font_color", Color("#93c5fd"))
	best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(best_label)

	status_label = Label.new()
	status_label.text = "Flip two cards and find the pair."
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(status_label)

	var keys := Label.new()
	keys.text = "Keys: 1-4 LEVEL / S STAGE / T TIER / R RESET / M SOUND"
	keys.add_theme_font_size_override("font_size", 9)
	keys.add_theme_color_override("font_color", Color("#64748b"))
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(keys)

	_build_result_layer()
	_update_selector_labels()

func _build_result_layer() -> void:
	result_layer = ColorRect.new()
	result_layer.color = Color(0.02, 0.04, 0.10, 0.88)
	result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.visible = false
	result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 230)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101c36"), Color("#38bdf8"), 22, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	result_title = Label.new()
	result_title.text = "ALL MATCHED!"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 25)
	result_title.add_theme_color_override("font_color", Color("#7dd3fc"))
	box.add_child(result_title)

	result_detail = Label.new()
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.add_theme_font_size_override("font_size", 13)
	result_detail.add_theme_color_override("font_color", Color("#e2e8f0"))
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result_detail)

	var again := _make_button("PLAY AGAIN", "primary")
	again.custom_minimum_size = Vector2(0, 46)
	again.pressed.connect(_start_game)
	box.add_child(again)

	var close := _make_button("CHANGE SETTINGS", "ghost")
	close.pressed.connect(_close_result)
	box.add_child(close)

func _make_stat(parent: Control, label_text: String, value_text: String) -> Label:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _panel_style(Color("#101d36"), Color("#253b63"), 12, 1))
	parent.add_child(p)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	p.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	margin.add_child(box)
	var lab := Label.new()
	lab.text = label_text
	lab.add_theme_font_size_override("font_size", 8)
	lab.add_theme_color_override("font_color", Color("#64748b"))
	box.add_child(lab)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color("#f8fafc"))
	box.add_child(val)
	return val

func _make_button(text_value: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 12)
	var normal := Color("#15223e")
	var hover := Color("#20345b")
	var border := Color("#334b74")
	if kind == "primary":
		normal = Color("#0369a1")
		hover = Color("#0284c7")
		border = Color("#38bdf8")
	elif kind == "select":
		normal = Color("#111c34")
		hover = Color("#182b4d")
		border = Color("#2a4770")
	b.add_theme_stylebox_override("normal", _panel_style(normal, border, 11, 1))
	b.add_theme_stylebox_override("hover", _panel_style(hover, Color("#7dd3fc"), 11, 1))
	b.add_theme_stylebox_override("pressed", _panel_style(Color("#0c4a6e"), Color("#bae6fd"), 11, 2))
	b.add_theme_stylebox_override("disabled", _panel_style(Color("#172033"), Color("#253249"), 11, 1))
	b.add_theme_color_override("font_color", Color("#f8fafc"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_disabled_color", Color("#94a3b8"))
	return b

func _panel_style(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
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
	tone_flip = _make_tone(520.0, 0.055, 0.19)
	tone_match = _make_tone(760.0, 0.11, 0.20)
	tone_miss = _make_tone(190.0, 0.13, 0.16)
	tone_clear = _make_tone(980.0, 0.24, 0.19)

func _make_tone(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var env: float = 1.0 - (float(i) / maxf(1.0, float(frames)))
		var wave := sin(TAU * freq * float(i) / float(rate))
		var sample := int(clamp(wave * env * amplitude, -1.0, 1.0) * 32767.0)
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

func _start_game() -> void:
	result_layer.visible = false
	var seed_value := int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	for _i in range(12):
		if not recent_seeds.has(seed_value):
			break
		seed_value += 2654435761
	recent_seeds.push_front(seed_value)
	if recent_seeds.size() > 50:
		recent_seeds.resize(50)
	rng.seed = seed_value

	var cfg: Dictionary = LEVELS[level - 1]
	var pair_texts := _generate_unique_texts(int(cfg["pairs"]))
	cards.clear()
	for i in range(pair_texts.size()):
		cards.append({"pair": i, "text": pair_texts[i], "state": "hidden"})
		cards.append({"pair": i, "text": pair_texts[i], "state": "hidden"})
	_shuffle_cards()

	open_indices.clear()
	misses = 0
	turns = 0
	matched_pairs = 0
	elapsed_ms = 0
	locked = false
	finished = false
	playing = true
	start_ms = Time.get_ticks_msec()
	board_grid.columns = int(cfg["cols"])
	_rebuild_board()
	_update_selector_labels()
	_update_hud()
	status_label.text = "Find %d pairs. Match identical text." % int(cfg["pairs"])
	_save_storage()
	call_deferred("_apply_responsive_layout")
	call_deferred("_update_debug_bridge")

func _generate_unique_texts(pair_count: int) -> Array:
	var pool := _stage_pool(stage)
	var min_len := 1
	for length in range(1, 4):
		if int(pow(float(max(1, pool.size())), float(length))) >= pair_count * 2:
			min_len = length
			break
	var out: Array = []
	var used := {}
	var guard := 0
	while out.size() < pair_count and guard < 30000:
		guard += 1
		var length: int = maxi(min_len, _pick_length())
		var value := ""
		for _j in range(length):
			value += str(pool[rng.randi_range(0, pool.size() - 1)])
		if used.has(value):
			continue
		used[value] = true
		out.append(value)
	while out.size() < pair_count:
		var fallback := "%s%d" % [str(pool[rng.randi_range(0, pool.size() - 1)]), out.size()]
		if not used.has(fallback):
			used[fallback] = true
			out.append(fallback)
	return out

func _stage_pool(stage_id: int) -> Array:
	var pool: Array = []
	var kanji1 := _chars(KANJI1_TEXT)
	var kanji2 := _chars(KANJI2_TEXT)
	match stage_id:
		1:
			pool.append_array(DIGITS)
		2:
			pool.append_array(ALPHABET)
		3:
			pool.append_array(DIGITS); pool.append_array(ALPHABET)
		4:
			pool.append_array(DIGITS); pool.append_array(ALPHABET); pool.append_array(SYMBOLS)
		5:
			pool.append_array(kanji1)
		6:
			pool.append_array(kanji1); pool.append_array(DIGITS); pool.append_array(ALPHABET); pool.append_array(SYMBOLS)
		7:
			pool.append_array(kanji1); pool.append_array(kanji2); pool.append_array(DIGITS); pool.append_array(ALPHABET); pool.append_array(SYMBOLS)
		8:
			pool.append_array(kanji1); pool.append_array(kanji2); pool.append_array(KANJI3); pool.append_array(DIGITS); pool.append_array(ALPHABET); pool.append_array(SYMBOLS)
		9:
			pool.append_array(HANGUL)
		_:
			pool.append_array(kanji1); pool.append_array(kanji2); pool.append_array(KANJI3); pool.append_array(HANGUL); pool.append_array(DIGITS); pool.append_array(ALPHABET); pool.append_array(SYMBOLS)
	return pool

func _chars(value: String) -> Array:
	var out: Array = []
	for i in range(value.length()):
		out.append(value.substr(i, 1))
	return out

func _pick_length() -> int:
	var mix: Vector3 = TIER_MIX[tier - 1]
	var r := rng.randf()
	if r < mix.x:
		return 1
	if r < mix.x + mix.y:
		return 2
	return 3

func _shuffle_cards() -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

func _rebuild_board() -> void:
	for child in board_grid.get_children():
		child.queue_free()
	card_buttons.clear()
	for i in range(cards.size()):
		var b := Button.new()
		b.text = "?"
		b.custom_minimum_size = Vector2(38, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_on_card_pressed.bind(i))
		board_grid.add_child(b)
		card_buttons.append(b)
	_sync_board()

func _on_card_pressed(index: int) -> void:
	if not playing or finished or locked:
		return
	if index < 0 or index >= cards.size():
		return
	if str(cards[index]["state"]) != "hidden":
		return
	cards[index]["state"] = "open"
	open_indices.append(index)
	_play(tone_flip)
	_sync_board()
	if open_indices.size() < 2:
		status_label.text = "One card open. Choose its match."
		return

	turns += 1
	var a := int(open_indices[0])
	var b := int(open_indices[1])
	if int(cards[a]["pair"]) == int(cards[b]["pair"]):
		cards[a]["state"] = "matched"
		cards[b]["state"] = "matched"
		matched_pairs += 1
		open_indices.clear()
		status_label.text = "MATCH! %d / %d" % [matched_pairs, int(LEVELS[level - 1]["pairs"])]
		_play(tone_match)
		_sync_board()
		_update_hud()
		if matched_pairs >= int(LEVELS[level - 1]["pairs"]):
			_on_clear()
	else:
		misses += 1
		locked = true
		status_label.text = "MISS — remember both positions."
		_play(tone_miss)
		_sync_board()
		_update_hud()
		await get_tree().create_timer(0.58).timeout
		if is_instance_valid(self) and not finished:
			cards[a]["state"] = "hidden"
			cards[b]["state"] = "hidden"
			open_indices.clear()
			locked = false
			status_label.text = "Try again. Use the revealed positions."
			_sync_board()
			_update_debug_bridge()

func _sync_board() -> void:
	for i in range(min(card_buttons.size(), cards.size())):
		var b: Button = card_buttons[i]
		var card: Dictionary = cards[i]
		var state := str(card["state"])
		var text_value := str(card["text"])
		b.disabled = state == "matched" or locked
		if state == "hidden":
			b.text = "?"
			b.add_theme_font_size_override("font_size", 20)
			b.add_theme_stylebox_override("normal", _panel_style(Color("#152744"), Color("#335b88"), 10, 1))
			b.add_theme_stylebox_override("hover", _panel_style(Color("#1c3b62"), Color("#7dd3fc"), 10, 2))
			b.add_theme_stylebox_override("pressed", _panel_style(Color("#0c4a6e"), Color("#bae6fd"), 10, 2))
		else:
			b.text = text_value
			b.add_theme_font_size_override("font_size", _card_font_size(text_value))
			if state == "matched":
				b.add_theme_stylebox_override("disabled", _panel_style(Color("#064e3b"), Color("#34d399"), 10, 2))
				b.add_theme_color_override("font_disabled_color", Color("#d1fae5"))
			else:
				b.add_theme_stylebox_override("normal", _panel_style(Color("#075985"), Color("#7dd3fc"), 10, 2))
				b.add_theme_stylebox_override("disabled", _panel_style(Color("#075985"), Color("#7dd3fc"), 10, 2))
				b.add_theme_color_override("font_color", Color("#f0f9ff"))
				b.add_theme_color_override("font_disabled_color", Color("#f0f9ff"))

func _card_font_size(value: String) -> int:
	if value.length() <= 1:
		return 21
	if value.length() == 2:
		return 17
	return 14

func _on_clear() -> void:
	playing = false
	finished = true
	locked = false
	elapsed_ms = Time.get_ticks_msec() - start_ms
	_play(tone_clear)
	var key := _record_key()
	var score := elapsed_ms + misses * 2000
	var previous := int(best_records.get(key, 0))
	var is_best := previous <= 0 or score < previous
	if is_best:
		best_records[key] = score
	_save_storage()
	_update_hud()
	_update_best()
	result_title.text = "PERFECT GRID!"
	result_detail.text = "%s\nMISS %d / TURNS %d\n%s" % [_format_time(elapsed_ms), misses, turns, "NEW BEST" if is_best else "MEMORY COMPLETE"]
	result_layer.visible = true
	status_label.text = "All pairs matched. Try a harder grid or tier."
	_update_debug_bridge()

func _update_hud() -> void:
	time_label.text = _format_time(elapsed_ms)
	miss_label.text = str(misses)
	turn_label.text = str(turns)
	progress_label.text = "%d/%d" % [matched_pairs, int(LEVELS[level - 1]["pairs"])]
	_update_best()

func _update_best() -> void:
	var score := int(best_records.get(_record_key(), 0))
	if score <= 0:
		best_label.text = "BEST  --"
	else:
		best_label.text = "BEST  %s  (penalty included)" % _format_time(score)

func _record_key() -> String:
	return "l%d-s%d-t%d" % [level, stage, tier]

func _format_time(ms: int) -> String:
	var total: int = maxi(0, int(float(ms) / 1000.0))
	return "%02d:%02d" % [int(total / 60), int(total % 60)]

func _cycle_level() -> void:
	level = (level % 4) + 1
	_start_game()

func _cycle_stage() -> void:
	stage = (stage % 10) + 1
	_start_game()

func _cycle_tier() -> void:
	tier = (tier % 5) + 1
	_start_game()

func _update_selector_labels() -> void:
	var cfg: Dictionary = LEVELS[level - 1]
	level_button.text = "LEVEL %d  ·  %dx%d / %d CARDS" % [level, int(cfg["cols"]), int(cfg["rows"]), int(cfg["pairs"]) * 2]
	stage_button.text = "STAGE %d  ·  %s" % [stage, STAGE_LABELS[stage - 1]]
	tier_button.text = "TIER %d  ·  %s" % [tier, _tier_label()]
	if is_instance_valid(sound_button):
		sound_button.text = "SOUND ON" if sound_on else "SOUND OFF"

func _tier_label() -> String:
	match tier:
		1: return "1 CHAR"
		2: return "1-2 CHAR"
		3: return "2 CHAR"
		4: return "2-3 CHAR"
		_: return "3 CHAR"

func _toggle_sound() -> void:
	sound_on = not sound_on
	_update_selector_labels()
	if sound_on:
		_play(tone_flip)
	_update_debug_bridge()

func _close_result() -> void:
	result_layer.visible = false

func _apply_responsive_layout() -> void:
	if not is_instance_valid(content_grid):
		return
	var size := get_viewport_rect().size
	var landscape := size.x > size.y * 1.25
	content_grid.columns = 2 if landscape else 1
	if landscape:
		board_panel.custom_minimum_size = Vector2(max(350.0, size.x * 0.62), 0)
		side_panel.custom_minimum_size = Vector2(max(240.0, size.x * 0.30), 0)
		root_margin.add_theme_constant_override("margin_left", 8)
		root_margin.add_theme_constant_override("margin_right", 8)
	else:
		board_panel.custom_minimum_size = Vector2(0, max(300.0, size.y * 0.48))
		side_panel.custom_minimum_size = Vector2(0, 220)
		root_margin.add_theme_constant_override("margin_left", 10)
		root_margin.add_theme_constant_override("margin_right", 10)
	var compact := size.y < 480
	for b in card_buttons:
		if b is Button:
			(b as Button).custom_minimum_size = Vector2(34, 32 if compact else 40)

func _go_home() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)

func _qa_finish() -> void:
	if not qa_mode or finished:
		return
	for pair_id in range(int(LEVELS[level - 1]["pairs"])):
		var found: Array = []
		for i in range(cards.size()):
			if int(cards[i]["pair"]) == pair_id:
				found.append(i)
		if found.size() == 2:
			for idx in found:
				cards[int(idx)]["state"] = "matched"
			turns += 1
			matched_pairs += 1
	open_indices.clear()
	_sync_board()
	_on_clear()

func _test_pair_indices() -> Array:
	for pair_id in range(int(LEVELS[level - 1]["pairs"])):
		var found: Array = []
		for i in range(cards.size()):
			if int(cards[i]["pair"]) == pair_id and str(cards[i]["state"]) == "hidden":
				found.append(i)
		if found.size() == 2:
			return found
	return []

func _button_center(index: int) -> Vector2:
	if index < 0 or index >= card_buttons.size():
		return Vector2.ZERO
	var b: Button = card_buttons[index]
	var rect := b.get_global_rect()
	return rect.position + rect.size * 0.5

func _update_debug_bridge() -> void:
	if OS.get_name() != "Web" or not is_instance_valid(board_grid):
		return
	var pair := _test_pair_indices()
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	if pair.size() == 2:
		a = _button_center(int(pair[0]))
		b = _button_center(int(pair[1]))
	var payload := {
		"ready": true,
		"engine": "Godot",
		"build": "GAME-058",
		"qa_mode": qa_mode,
		"viewport_w": int(get_viewport_rect().size.x),
		"viewport_h": int(get_viewport_rect().size.y),
		"level": level,
		"stage": stage,
		"tier": tier,
		"cards": cards.size(),
		"pairs": int(LEVELS[level - 1]["pairs"]),
		"matched": matched_pairs,
		"miss": misses,
		"turn": turns,
		"open_count": open_indices.size(),
		"locked": locked,
		"finished": finished,
		"sound": sound_on,
		"test_a_x": a.x,
		"test_a_y": a.y,
		"test_b_x": b.x,
		"test_b_y": b.y
	}
	JavaScriptBridge.eval("window.__P021_MEMORY = %s;" % JSON.stringify(payload), true)
