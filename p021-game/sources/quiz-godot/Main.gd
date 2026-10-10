extends Control

# GAME-067 / GAME-G017 Quiz Arena
# Local source of truth: res://data/quiz_categories.json + quiz_questions.json

const QUESTIONS_PER_RUN := 10
const CATEGORY_PATH := "res://data/quiz_categories.json"
const QUESTION_PATH := "res://data/quiz_questions.json"
const BUILD_ID := "GAME-067"

var categories: Array = []
var questions: Array = []
var source_catalog: Dictionary = {}
var category_index := 0
var focus_level := 1
var run_questions: Array = []
var question_index := 0
var correct_count := 0
var wrong_count := 0
var current_answer := -1
var selected_answer := -1
var phase := "idle"
var sound_on := true
var qa_mode := false
var start_ms := 0
var elapsed_ms := 0
var best_records: Dictionary = {}
var rng := RandomNumberGenerator.new()

var ui_font: Font
var root_margin: MarginContainer
var title_label: Label
var subtitle_label: Label
var sound_button: Button
var content: VBoxContainer
var setup_panel: PanelContainer
var play_panel: PanelContainer
var category_grid: GridContainer
var category_buttons: Array[Button] = []
var level_row: HBoxContainer
var level_buttons: Array[Button] = []
var start_button: Button
var best_setup_label: Label
var progress_label: Label
var score_label: Label
var category_pill: Label
var question_label: Label
var level_badge: Label
var answers_grid: GridContainer
var answer_buttons: Array[Button] = []
var feedback_label: Label
var explanation_label: Label
var source_label: Label
var next_button: Button
var settings_button: Button
var audio_player: AudioStreamPlayer
var tone_click: AudioStreamWAV
var tone_ok: AudioStreamWAV
var tone_bad: AudioStreamWAV
var tone_clear: AudioStreamWAV

func _ready() -> void:
	_load_font()
	_load_data()
	_load_storage()
	if OS.get_name() == "Web":
		var q = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true)
		qa_mode = bool(q)
	if qa_mode:
		rng.seed = 17067
	else:
		rng.randomize()
	_build_ui()
	_setup_audio()
	_render_setup()
	_apply_responsive_layout()
	_update_debug_bridge()
	set_process(true)

func _process(_delta: float) -> void:
	if phase == "question" or phase == "feedback":
		elapsed_ms = Time.get_ticks_msec() - start_ms
	if OS.get_name() == "Web":
		_update_debug_bridge()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_apply_responsive_layout")

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var e := event as InputEventKey
	if not e.pressed or e.echo:
		return
	if e.keycode == KEY_M:
		_toggle_sound()
		get_viewport().set_input_as_handled()
		return
	if phase == "idle":
		match e.keycode:
			KEY_C:
				_select_category((category_index + 1) % maxi(1, categories.size()))
			KEY_L:
				_select_level((focus_level % 5) + 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_N:
				_start_run()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if phase == "question":
		if qa_mode and e.keycode == KEY_F:
			_answer(current_answer)
		elif qa_mode and e.keycode == KEY_X:
			_answer((current_answer + 1) % 4)
		elif e.keycode >= KEY_1 and e.keycode <= KEY_4:
			_answer(int(e.keycode - KEY_1))
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if phase == "feedback":
		if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_N:
			_next_question()
			get_viewport().set_input_as_handled()
		return
	if phase == "result":
		if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_N:
			_start_run()
		elif e.keycode == KEY_R:
			_return_to_setup()
		else:
			return
		get_viewport().set_input_as_handled()

func _load_font() -> void:
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		var loaded = load("res://fonts/NotoSansJP.ttf")
		if loaded is Font:
			ui_font = loaded
			return
	ui_font = ThemeDB.fallback_font

func _load_data() -> void:
	var cats = JSON.parse_string(FileAccess.get_file_as_string(CATEGORY_PATH))
	var qs = JSON.parse_string(FileAccess.get_file_as_string(QUESTION_PATH))
	if typeof(cats) == TYPE_DICTIONARY:
		for item in cats.get("categories", []):
			if typeof(item) == TYPE_DICTIONARY and bool(item.get("enabled", false)):
				categories.append(item)
	if typeof(qs) == TYPE_DICTIONARY:
		questions = qs.get("questions", [])
		source_catalog = qs.get("sourceCatalog", {})
	if categories.is_empty() or questions.is_empty():
		push_error("GAME-067 local quiz data is missing or invalid")

func _load_storage() -> void:
	if FileAccess.file_exists("user://quiz-arena-records.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://quiz-arena-records.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			best_records = parsed

func _save_storage() -> void:
	var f = FileAccess.open("user://quiz-arena-records.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(best_records))

func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 15
	self.theme = theme

	var bg := ColorRect.new()
	bg.color = Color("#071226")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var glow_a := ColorRect.new()
	glow_a.color = Color("#0b3550")
	glow_a.position = Vector2(-80, -70)
	glow_a.size = Vector2(460, 185)
	glow_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_a)

	var glow_b := ColorRect.new()
	glow_b.color = Color("#2a1648")
	glow_b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	glow_b.position = Vector2(-430, -170)
	glow_b.size = Vector2(480, 220)
	glow_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_b)

	root_margin = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_margin)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	root_margin.add_child(content)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 46)
	top.add_theme_constant_override("separation", 7)
	content.add_child(top)

	var hub := _make_button("HUB", "ghost")
	hub.custom_minimum_size = Vector2(56, 40)
	hub.pressed.connect(_go_home)
	top.add_child(hub)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", -4)
	top.add_child(title_box)

	title_label = Label.new()
	title_label.text = "QUIZ ARENA"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	title_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "10 QUESTIONS · LOCAL VERIFIED DATA"
	subtitle_label.add_theme_font_size_override("font_size", 9)
	subtitle_label.add_theme_color_override("font_color", Color("#67e8f9"))
	title_box.add_child(subtitle_label)

	sound_button = _make_button("SOUND ON", "ghost")
	sound_button.custom_minimum_size = Vector2(94, 40)
	sound_button.pressed.connect(_toggle_sound)
	top.add_child(sound_button)

	setup_panel = _build_setup_panel()
	content.add_child(setup_panel)
	play_panel = _build_play_panel()
	content.add_child(play_panel)
	play_panel.visible = false

func _build_setup_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0b1730"), Color("#1f4f68"), 22, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var eyebrow := Label.new()
	eyebrow.text = "CHOOSE YOUR RUN"
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", Color("#c084fc"))
	box.add_child(eyebrow)

	var intro := Label.new()
	intro.text = "カテゴリとFocus Lvを選んで10問に挑戦。選択Lvを中心に近い難易度から重複なしで出題します。"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 14)
	intro.add_theme_color_override("font_color", Color("#dbeafe"))
	box.add_child(intro)

	var cat_title := Label.new()
	cat_title.text = "CATEGORY"
	cat_title.add_theme_font_size_override("font_size", 10)
	cat_title.add_theme_color_override("font_color", Color("#94a3b8"))
	box.add_child(cat_title)

	category_grid = GridContainer.new()
	category_grid.columns = 3
	category_grid.add_theme_constant_override("h_separation", 6)
	category_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(category_grid)
	for i in range(categories.size()):
		var b := _make_button(str(categories[i].get("name", "CATEGORY")), "select")
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_category.bind(i))
		category_buttons.append(b)
		category_grid.add_child(b)

	var lv_title := Label.new()
	lv_title.text = "FOCUS LEVEL · Lv1〜5"
	lv_title.add_theme_font_size_override("font_size", 10)
	lv_title.add_theme_color_override("font_color", Color("#94a3b8"))
	box.add_child(lv_title)

	level_row = HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 6)
	box.add_child(level_row)
	for lv in range(1, 6):
		var b := _make_button("Lv%d" % lv, "select")
		b.custom_minimum_size = Vector2(46, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_level.bind(lv))
		level_buttons.append(b)
		level_row.add_child(b)

	start_button = _make_button("START 10 QUESTIONS", "primary")
	start_button.custom_minimum_size = Vector2(0, 52)
	start_button.pressed.connect(_start_run)
	box.add_child(start_button)

	best_setup_label = Label.new()
	best_setup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_setup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	best_setup_label.add_theme_font_size_override("font_size", 11)
	best_setup_label.add_theme_color_override("font_color", Color("#93c5fd"))
	box.add_child(best_setup_label)

	var hint := Label.new()
	hint.text = "PC: C=カテゴリ / L=Lv / Enter=開始 / 1〜4=回答 / M=音"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color("#64748b"))
	box.add_child(hint)
	return panel

func _build_play_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#08152b"), Color("#155e75"), 22, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 8)
	box.add_child(status)

	category_pill = Label.new()
	category_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_pill.add_theme_font_size_override("font_size", 10)
	category_pill.add_theme_color_override("font_color", Color("#67e8f9"))
	status.add_child(category_pill)

	level_badge = Label.new()
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_badge.add_theme_font_size_override("font_size", 10)
	level_badge.add_theme_color_override("font_color", Color("#c4b5fd"))
	status.add_child(level_badge)

	var score_row := HBoxContainer.new()
	box.add_child(score_row)
	progress_label = Label.new()
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.add_theme_color_override("font_color", Color("#94a3b8"))
	score_row.add_child(progress_label)
	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 11)
	score_label.add_theme_color_override("font_color", Color("#86efac"))
	score_row.add_child(score_label)

	var q_panel := PanelContainer.new()
	q_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0b213b"), Color("#17607b"), 18, 1))
	box.add_child(q_panel)
	var q_margin := MarginContainer.new()
	q_margin.add_theme_constant_override("margin_left", 14)
	q_margin.add_theme_constant_override("margin_right", 14)
	q_margin.add_theme_constant_override("margin_top", 12)
	q_margin.add_theme_constant_override("margin_bottom", 12)
	q_panel.add_child(q_margin)
	question_label = Label.new()
	question_label.text = "QUESTION"
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_label.custom_minimum_size = Vector2(0, 74)
	question_label.add_theme_font_size_override("font_size", 22)
	question_label.add_theme_color_override("font_color", Color("#f8fafc"))
	q_margin.add_child(question_label)

	answers_grid = GridContainer.new()
	answers_grid.columns = 1
	answers_grid.add_theme_constant_override("h_separation", 7)
	answers_grid.add_theme_constant_override("v_separation", 7)
	box.add_child(answers_grid)
	for i in range(4):
		var b := _make_button("", "answer")
		b.custom_minimum_size = Vector2(0, 49)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_answer.bind(i))
		answer_buttons.append(b)
		answers_grid.add_child(b)

	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 13)
	feedback_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	box.add_child(feedback_label)

	explanation_label = Label.new()
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation_label.add_theme_font_size_override("font_size", 11)
	explanation_label.add_theme_color_override("font_color", Color("#dbeafe"))
	box.add_child(explanation_label)

	source_label = Label.new()
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_label.add_theme_font_size_override("font_size", 9)
	source_label.add_theme_color_override("font_color", Color("#64748b"))
	box.add_child(source_label)

	next_button = _make_button("NEXT QUESTION", "primary")
	next_button.custom_minimum_size = Vector2(0, 46)
	next_button.pressed.connect(_next_question)
	box.add_child(next_button)

	settings_button = _make_button("CHANGE SETTINGS", "ghost")
	settings_button.custom_minimum_size = Vector2(0, 42)
	settings_button.visible = false
	settings_button.pressed.connect(_return_to_setup)
	box.add_child(settings_button)
	return panel

func _make_button(text_value: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = false
	b.add_theme_font_size_override("font_size", 12)
	var normal := Color("#15203a")
	var hover := Color("#203456")
	var border := Color("#334a70")
	if kind == "primary":
		normal = Color("#075985")
		hover = Color("#0891b2")
		border = Color("#22d3ee")
	elif kind == "select":
		normal = Color("#111d36")
		hover = Color("#1c3155")
		border = Color("#314d73")
	elif kind == "answer":
		normal = Color("#0e1f39")
		hover = Color("#183b60")
		border = Color("#315273")
	b.add_theme_stylebox_override("normal", _panel_style(normal, border, 12, 1))
	b.add_theme_stylebox_override("hover", _panel_style(hover, Color("#67e8f9"), 12, 1))
	b.add_theme_stylebox_override("pressed", _panel_style(Color("#164e63"), Color("#cffafe"), 12, 2))
	b.add_theme_stylebox_override("disabled", _panel_style(Color("#111827"), Color("#25324a"), 12, 1))
	b.add_theme_color_override("font_color", Color("#f8fafc"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_disabled_color", Color("#64748b"))
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

func _select_category(index: int) -> void:
	if phase != "idle" or categories.is_empty():
		return
	category_index = clampi(index, 0, categories.size() - 1)
	_play(tone_click)
	_render_setup()

func _select_level(level: int) -> void:
	if phase != "idle":
		return
	focus_level = clampi(level, 1, 5)
	_play(tone_click)
	_render_setup()

func _render_setup() -> void:
	for i in range(category_buttons.size()):
		var selected := i == category_index
		var label := str(categories[i].get("name", "CATEGORY"))
		category_buttons[i].text = ("● " if selected else "") + label
		category_buttons[i].add_theme_color_override("font_color", Color("#67e8f9") if selected else Color("#f8fafc"))
	for i in range(level_buttons.size()):
		var lv := i + 1
		var selected := lv == focus_level
		level_buttons[i].text = ("●" if selected else "") + "Lv%d" % lv
		level_buttons[i].add_theme_color_override("font_color", Color("#c4b5fd") if selected else Color("#f8fafc"))
	sound_button.text = "SOUND ON" if sound_on else "SOUND OFF"
	var record = best_records.get(_record_key(), null)
	if typeof(record) == TYPE_DICTIONARY:
		best_setup_label.text = "BEST  %d/%d · %s" % [int(record.get("correct", 0)), QUESTIONS_PER_RUN, _format_time(int(record.get("ms", 0)))]
	else:
		best_setup_label.text = "BEST  -- / 10"
	_update_debug_bridge()

func _record_key() -> String:
	if categories.is_empty():
		return "none-l%d" % focus_level
	return "%s-l%d" % [str(categories[category_index].get("id", "none")), focus_level]

func _start_run() -> void:
	if categories.is_empty() or questions.is_empty():
		return
	run_questions = _pick_questions(str(categories[category_index].get("id", "")), focus_level)
	if run_questions.size() < QUESTIONS_PER_RUN:
		push_error("GAME-067 needs 10 questions for selected category")
		return
	question_index = 0
	correct_count = 0
	wrong_count = 0
	selected_answer = -1
	start_ms = Time.get_ticks_msec()
	elapsed_ms = 0
	setup_panel.visible = false
	play_panel.visible = true
	phase = "question"
	settings_button.visible = false
	_play(tone_click)
	_show_question()

func _pick_questions(category_id: String, target_level: int) -> Array:
	var buckets: Dictionary = {}
	for lv in range(1, 6):
		buckets[lv] = []
	for q in questions:
		if typeof(q) != TYPE_DICTIONARY:
			continue
		if str(q.get("categoryId", "")) != category_id:
			continue
		var lv := int(q.get("level", 1))
		if lv >= 1 and lv <= 5:
			buckets[lv].append(q)
	for lv in range(1, 6):
		_shuffle_array(buckets[lv])
	var order: Array[int] = []
	order.append(target_level)
	for distance in range(1, 5):
		var low := target_level - distance
		var high := target_level + distance
		if low >= 1:
			order.append(low)
		if high <= 5:
			order.append(high)
	var picked: Array = []
	while picked.size() < QUESTIONS_PER_RUN:
		var added := false
		for lv in order:
			if picked.size() >= QUESTIONS_PER_RUN:
				break
			var bucket: Array = buckets[lv]
			if not bucket.is_empty():
				picked.append(bucket.pop_back())
				added = true
		if not added:
			break
	return picked

func _shuffle_array(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = values[i]
		values[i] = values[j]
		values[j] = tmp

func _show_question() -> void:
	phase = "question"
	selected_answer = -1
	var q: Dictionary = run_questions[question_index]
	current_answer = int(q.get("answerIndex", 0))
	category_pill.text = str(categories[category_index].get("name", "CATEGORY")).to_upper()
	level_badge.text = "Q Lv%d · FOCUS Lv%d" % [int(q.get("level", 1)), focus_level]
	progress_label.text = "QUESTION %d / %d" % [question_index + 1, QUESTIONS_PER_RUN]
	score_label.text = "SCORE %d" % correct_count
	question_label.text = str(q.get("prompt", ""))
	var choices: Array = q.get("choices", [])
	for i in range(answer_buttons.size()):
		var b := answer_buttons[i]
		b.visible = true
		b.disabled = false
		b.text = "%d  %s" % [i + 1, str(choices[i]) if i < choices.size() else ""]
		_style_answer_button(b, "normal")
	feedback_label.text = "答えを選択してください"
	feedback_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	explanation_label.text = ""
	source_label.text = ""
	next_button.visible = false
	settings_button.visible = false
	_apply_responsive_layout()
	_update_debug_bridge()

func _answer(choice_index: int) -> void:
	if phase != "question" or choice_index < 0 or choice_index >= 4:
		return
	selected_answer = choice_index
	var q: Dictionary = run_questions[question_index]
	var ok := choice_index == current_answer
	if ok:
		correct_count += 1
		feedback_label.text = "CORRECT  +1"
		feedback_label.add_theme_color_override("font_color", Color("#86efac"))
		_play(tone_ok)
	else:
		wrong_count += 1
		feedback_label.text = "MISS · 正解は %d" % (current_answer + 1)
		feedback_label.add_theme_color_override("font_color", Color("#fda4af"))
		_play(tone_bad)
	for i in range(answer_buttons.size()):
		answer_buttons[i].disabled = true
		if i == current_answer:
			_style_answer_button(answer_buttons[i], "correct")
		elif i == selected_answer and not ok:
			_style_answer_button(answer_buttons[i], "wrong")
		else:
			_style_answer_button(answer_buttons[i], "muted")
	explanation_label.text = "解説: %s" % str(q.get("explanation", ""))
	source_label.text = _source_summary(q)
	score_label.text = "SCORE %d" % correct_count
	phase = "feedback"
	next_button.text = "RESULT" if question_index + 1 >= QUESTIONS_PER_RUN else "NEXT QUESTION"
	next_button.visible = true
	_update_debug_bridge()

func _style_answer_button(button: Button, state: String) -> void:
	var bg := Color("#0e1f39")
	var border := Color("#315273")
	var font := Color("#f8fafc")
	if state == "correct":
		bg = Color("#103b36")
		border = Color("#34d399")
		font = Color("#d1fae5")
	elif state == "wrong":
		bg = Color("#471e2a")
		border = Color("#fb7185")
		font = Color("#ffe4e6")
	elif state == "muted":
		bg = Color("#111827")
		border = Color("#28344a")
		font = Color("#64748b")
	button.add_theme_stylebox_override("normal", _panel_style(bg, border, 12, 2 if state == "correct" or state == "wrong" else 1))
	button.add_theme_stylebox_override("disabled", _panel_style(bg, border, 12, 2 if state == "correct" or state == "wrong" else 1))
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_disabled_color", font)

func _source_summary(q: Dictionary) -> String:
	var names: Array[String] = []
	for ref_value in q.get("sourceRefs", []):
		var ref := str(ref_value)
		if not source_catalog.has(ref):
			continue
		var item: Dictionary = source_catalog[ref]
		var title := str(item.get("title", ref))
		if ref == "original_math":
			title = "P021 original"
		elif ref == "nist_si":
			title = "NIST"
		elif ref == "nasa_planets":
			title = "NASA Science"
		elif ref == "rfc9110":
			title = "RFC 9110"
		elif ref == "mdn_strict_equality":
			title = "MDN"
		names.append(title)
	return "SOURCE  " + " / ".join(names)

func _next_question() -> void:
	if phase != "feedback":
		return
	if question_index + 1 >= QUESTIONS_PER_RUN:
		_finish_run()
		return
	question_index += 1
	_play(tone_click)
	_show_question()

func _finish_run() -> void:
	elapsed_ms = Time.get_ticks_msec() - start_ms
	phase = "result"
	var key := _record_key()
	var previous = best_records.get(key, null)
	var is_best := false
	if typeof(previous) != TYPE_DICTIONARY:
		is_best = true
	else:
		var prev_correct := int(previous.get("correct", -1))
		var prev_ms := int(previous.get("ms", 999999999))
		is_best = correct_count > prev_correct or (correct_count == prev_correct and elapsed_ms < prev_ms)
	if is_best:
		best_records[key] = {"correct": correct_count, "ms": elapsed_ms}
		_save_storage()
	_play(tone_clear)
	category_pill.text = "RUN COMPLETE"
	level_badge.text = "FOCUS Lv%d" % focus_level
	progress_label.text = "10 / 10 ANSWERED"
	score_label.text = "SCORE %d" % correct_count
	question_label.text = "%d / %d" % [correct_count, QUESTIONS_PER_RUN]
	question_label.add_theme_font_size_override("font_size", 40)
	for b in answer_buttons:
		b.visible = false
	feedback_label.text = "%d%% · %s" % [int(round(float(correct_count) / QUESTIONS_PER_RUN * 100.0)), _format_time(elapsed_ms)]
	feedback_label.add_theme_color_override("font_color", Color("#86efac") if correct_count >= 7 else Color("#fde68a"))
	explanation_label.text = "NEW BEST!" if is_best else "BEST %d/%d · %s" % [int(previous.get("correct", 0)), QUESTIONS_PER_RUN, _format_time(int(previous.get("ms", 0)))]
	source_label.text = "Score = correct-count (higher) · time = tie-break"
	next_button.text = "PLAY AGAIN"
	next_button.visible = true
	next_button.pressed.disconnect(_next_question) if next_button.pressed.is_connected(_next_question) else null
	if not next_button.pressed.is_connected(_start_run):
		next_button.pressed.connect(_start_run)
	settings_button.visible = true
	_update_debug_bridge()

func _return_to_setup() -> void:
	if next_button.pressed.is_connected(_start_run):
		next_button.pressed.disconnect(_start_run)
	if not next_button.pressed.is_connected(_next_question):
		next_button.pressed.connect(_next_question)
	phase = "idle"
	play_panel.visible = false
	setup_panel.visible = true
	question_label.add_theme_font_size_override("font_size", 22)
	_render_setup()
	_apply_responsive_layout()

func _format_time(ms: int) -> String:
	var total_sec := maxi(0, int(float(ms) / 1000.0))
	var tenths := int(ms / 100) % 10
	return "%02d:%02d.%d" % [int(total_sec / 60), int(total_sec % 60), tenths]

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_click = _make_tone(520.0, 0.045, 0.11)
	tone_ok = _make_tone(760.0, 0.11, 0.16)
	tone_bad = _make_tone(190.0, 0.13, 0.14)
	tone_clear = _make_tone(960.0, 0.24, 0.17)

func _make_tone(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var envelope := 1.0 - float(i) / float(maxi(1, frames))
		var value := sin(TAU * freq * t) * amplitude * envelope
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		if sample < 0:
			sample += 65536
		data[i * 2] = sample & 0xff
		data[i * 2 + 1] = (sample >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _play(stream: AudioStreamWAV) -> void:
	if not sound_on or not is_instance_valid(audio_player):
		return
	audio_player.stream = stream
	audio_player.play()

func _toggle_sound() -> void:
	sound_on = not sound_on
	sound_button.text = "SOUND ON" if sound_on else "SOUND OFF"
	if sound_on:
		_play(tone_click)
	_render_setup()
	_update_debug_bridge()

func _apply_responsive_layout() -> void:
	if not is_instance_valid(root_margin):
		return
	var size := get_viewport_rect().size
	var compact_landscape := size.x > size.y * 1.35
	var margin := 7 if size.x < 520 or compact_landscape else 12
	root_margin.add_theme_constant_override("margin_left", margin)
	root_margin.add_theme_constant_override("margin_right", margin)
	root_margin.add_theme_constant_override("margin_top", 6)
	root_margin.add_theme_constant_override("margin_bottom", 6)
	if is_instance_valid(category_grid):
		category_grid.columns = 3
	if is_instance_valid(answers_grid):
		answers_grid.columns = 2 if compact_landscape or size.x >= 700 else 1
		for b in answer_buttons:
			b.custom_minimum_size.y = 41 if compact_landscape else 49
	if is_instance_valid(question_label):
		if phase != "result":
			question_label.custom_minimum_size.y = 58 if compact_landscape else 74
			question_label.add_theme_font_size_override("font_size", 18 if compact_landscape else 22)
	if is_instance_valid(title_label):
		title_label.add_theme_font_size_override("font_size", 18 if compact_landscape else 22)
	if is_instance_valid(subtitle_label):
		subtitle_label.visible = not (compact_landscape and size.y < 430)
	_update_debug_bridge()

func _go_home() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)

func _update_debug_bridge() -> void:
	if OS.get_name() != "Web":
		return
	var category_id := ""
	var category_name := ""
	if not categories.is_empty():
		category_id = str(categories[category_index].get("id", ""))
		category_name = str(categories[category_index].get("name", ""))
	var question_id := ""
	var question_level := 0
	if not run_questions.is_empty() and question_index >= 0 and question_index < run_questions.size():
		var q: Dictionary = run_questions[question_index]
		question_id = str(q.get("id", ""))
		question_level = int(q.get("level", 0))
	var payload := {
		"ready": true,
		"engine": "Godot",
		"build": BUILD_ID,
		"qa_mode": qa_mode,
		"viewport_w": int(get_viewport_rect().size.x),
		"viewport_h": int(get_viewport_rect().size.y),
		"phase": phase,
		"category": category_id,
		"category_name": category_name,
		"focus_level": focus_level,
		"question_index": question_index,
		"question_number": question_index + 1 if phase != "idle" else 0,
		"question_id": question_id,
		"question_level": question_level,
		"current_answer": current_answer if qa_mode else -1,
		"selected_answer": selected_answer,
		"correct": correct_count,
		"wrong": wrong_count,
		"total": QUESTIONS_PER_RUN,
		"sound": sound_on,
		"finished": phase == "result",
		"dataset_questions": questions.size(),
		"dataset_categories": categories.size()
	}
	JavaScriptBridge.eval("window.__P021_QUIZ = %s;" % JSON.stringify(payload), true)
