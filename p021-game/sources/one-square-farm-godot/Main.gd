extends Control

const FONT_PATH := "res://fonts/NotoSansJP.ttf"
const FARM_VISUAL = preload("res://FarmVisual.gd")
const DAY_SECONDS := 8.0
const RECORDS_PATH := "user://farm_records.cfg"

const CHALLENGES := {
    "standard": {
        "name": "スタンダード",
        "tagline": "15日で150G。基本ルールで農園経営を楽しむ。",
        "max_day": 15,
        "target_coins": 150,
        "start_coins": 60,
        "start_water": 3,
        "start_soil": 70,
        "water_refill": 2,
        "required_harvests": 0
    },
    "sprint": {
        "name": "10日スプリント",
        "tagline": "10日で115G、2回以上収穫。短期判断が勝負。",
        "max_day": 10,
        "target_coins": 115,
        "start_coins": 58,
        "start_water": 3,
        "start_soil": 72,
        "water_refill": 2,
        "required_harvests": 2
    },
    "drought": {
        "name": "節水チャレンジ",
        "tagline": "15日で130G、3回以上収穫。水補充は1日1回だけ。",
        "max_day": 15,
        "target_coins": 130,
        "start_coins": 62,
        "start_water": 1,
        "start_soil": 82,
        "water_refill": 1,
        "required_harvests": 3
    }
}

const CROPS := {
    "radish": {"name":"ラディッシュ","seed":8,"days":3.0,"sell":24,"note":"早い・安定"},
    "lettuce": {"name":"レタス","seed":12,"days":4.0,"sell":38,"note":"中速・バランス"},
    "tomato": {"name":"トマト","seed":18,"days":5.0,"sell":58,"note":"遅い・高収益"}
}

const WEATHERS := [
    {"key":"sun","name":"晴れ"},
    {"key":"cloud","name":"くもり"},
    {"key":"rain","name":"雨"}
]

const SFX_PATHS := {
    "select": "res://audio/select_001.ogg",
    "plant": "res://audio/click_001.ogg",
    "water": "res://audio/click_002.ogg",
    "compost": "res://audio/click_003.ogg",
    "harvest": "res://audio/confirmation_001.ogg",
    "success": "res://audio/confirmation_004.ogg",
    "error": "res://audio/error_001.ogg"
}
const AUDIO_LEVELS := [1.0, 0.7, 0.4, 0.0]
const AUDIO_SETTINGS_PATH := "user://audio_settings.cfg"

var day := 1
var coins := 60
var water_stock := 3
var soil := 70
var selected := "radish"
var crop: Dictionary = {}
var logs: Array[String] = []
var weather_index := 0
var day_time := DAY_SECONDS
var paused := false
var speed := 1.0
var ended := false
var started := false
var harvests := 0

var stats_grid: GridContainer
var stats_labels: Dictionary = {}
var timer_label: Label
var timer_bar: ProgressBar
var growth: Label
var log_view: Label
var crop_buttons: Dictionary = {}
var plant_btn: Button
var water_btn: Button
var compost_btn: Button
var harvest_btn: Button
var pause_btn: Button
var speed_btn: Button
var visual: Control
var main_grid: GridContainer
var side_panel_ref: PanelContainer
var farm_panel_ref: PanelContainer
var scroll: ScrollContainer
var content_root: VBoxContainer
var intro_layer: ColorRect
var result_layer: ColorRect
var result_text: Label
var audio_btn: Button
var sfx_player: AudioStreamPlayer
var audio_level_index := 1

var selected_challenge := "standard"
var challenge_max_day := 15
var challenge_target_coins := 150
var challenge_start_coins := 60
var challenge_start_water := 3
var challenge_start_soil := 70
var challenge_water_refill := 2
var challenge_required_harvests := 0
var challenge_buttons: Dictionary = {}
var intro_summary: Label
var intro_records: Label
var intro_start_button: Button
var intro_scroll: ScrollContainer
var intro_panel: PanelContainer
var intro_box: VBoxContainer
var intro_challenge_grid: GridContainer
var intro_title: Label
var intro_rules: Label
var intro_credit: Label
var record_cache: Dictionary = {}
var header_title: Label
var header_subtitle: Label
var help_label: Label

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and is_inside_tree():
        _apply_responsive_layout()

func _apply_responsive_layout() -> void:
    if main_grid == null:
        return
    var is_portrait := size.y > size.x
    main_grid.columns = 1 if is_portrait else 2
    if stats_grid != null:
        stats_grid.columns = 2 if is_portrait else 5
    if side_panel_ref != null:
        side_panel_ref.custom_minimum_size = Vector2(0, 0) if is_portrait else Vector2(340, 0)
    if visual != null:
        visual.custom_minimum_size = Vector2(0, 320) if is_portrait else Vector2(540, 360)

    var compact_landscape := not is_portrait and size.y <= 500.0
    if intro_challenge_grid != null:
        intro_challenge_grid.columns = 1 if is_portrait else 3
    if intro_panel != null:
        if is_portrait:
            intro_panel.custom_minimum_size = Vector2(minf(420.0, maxf(350.0, size.x - 24.0)), 0)
        else:
            intro_panel.custom_minimum_size = Vector2(minf(760.0, maxf(620.0, size.x - 24.0)), 0)
    if intro_box != null:
        intro_box.add_theme_constant_override("separation", 7 if compact_landscape else 13)
    if intro_title != null:
        intro_title.add_theme_font_size_override("font_size", 28 if compact_landscape else 36)
    if intro_summary != null:
        intro_summary.add_theme_font_size_override("font_size", 14 if compact_landscape else 17)
    if intro_records != null:
        intro_records.add_theme_font_size_override("font_size", 12 if compact_landscape else 14)
    if intro_rules != null:
        intro_rules.add_theme_font_size_override("font_size", 11 if compact_landscape else 13)
    if intro_credit != null:
        intro_credit.add_theme_font_size_override("font_size", 10 if compact_landscape else 11)
    if intro_start_button != null:
        intro_start_button.custom_minimum_size = Vector2(0, 52 if compact_landscape else 58)
    for raw_key in challenge_buttons.keys():
        var mode_btn: Button = challenge_buttons[raw_key]
        mode_btn.custom_minimum_size = Vector2(0, 56 if compact_landscape else 64)
        mode_btn.add_theme_font_size_override("font_size", 14 if compact_landscape else 15)
    queue_redraw()

func _ready() -> void:
    paused = true
    _load_audio_settings()
    _load_records()
    _apply_challenge_settings()
    _setup_audio_player()
    _setup_theme()
    _build_ui()
    _build_intro()
    _update_challenge_copy()
    _apply_responsive_layout()
    _log("準備完了。%sに挑戦しましょう。" % _challenge().name)
    _refresh()

func _process(delta: float) -> void:
    if not started or ended or paused:
        return
    day_time -= delta * speed
    if day_time <= 0.0:
        _advance_day()
    else:
        _refresh_timer()
        _sync_visual()

func _setup_theme() -> void:
    var ui_theme := Theme.new()
    var jp_font: Font = load(FONT_PATH) as Font
    if jp_font != null:
        ui_theme.default_font = jp_font
    ui_theme.default_font_size = 18

    ui_theme.set_color("font_color", "Label", Color8(28, 48, 37))
    ui_theme.set_color("font_color", "Button", Color8(26, 61, 43))
    ui_theme.set_color("font_hover_color", "Button", Color8(10, 78, 44))
    ui_theme.set_color("font_pressed_color", "Button", Color8(10, 78, 44))
    ui_theme.set_color("font_disabled_color", "Button", Color8(105, 116, 108))

    var button_style := StyleBoxFlat.new()
    button_style.bg_color = Color8(246, 250, 246)
    button_style.border_color = Color8(176, 207, 185)
    button_style.set_border_width_all(2)
    button_style.set_corner_radius_all(14)
    button_style.content_margin_left = 14
    button_style.content_margin_right = 14
    button_style.content_margin_top = 11
    button_style.content_margin_bottom = 11
    ui_theme.set_stylebox("normal", "Button", button_style)

    var hover_style := button_style.duplicate() as StyleBoxFlat
    hover_style.bg_color = Color8(227, 246, 232)
    hover_style.border_color = Color8(71, 161, 99)
    ui_theme.set_stylebox("hover", "Button", hover_style)

    var pressed_style := button_style.duplicate() as StyleBoxFlat
    pressed_style.bg_color = Color8(207, 239, 218)
    pressed_style.border_color = Color8(35, 139, 73)
    ui_theme.set_stylebox("pressed", "Button", pressed_style)

    var disabled_style := button_style.duplicate() as StyleBoxFlat
    disabled_style.bg_color = Color8(232, 235, 232)
    disabled_style.border_color = Color8(203, 208, 204)
    ui_theme.set_stylebox("disabled", "Button", disabled_style)

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color8(255, 255, 255, 250)
    panel_style.border_color = Color8(205, 224, 210)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(18)
    panel_style.content_margin_left = 14
    panel_style.content_margin_right = 14
    panel_style.content_margin_top = 13
    panel_style.content_margin_bottom = 13
    ui_theme.set_stylebox("panel", "PanelContainer", panel_style)

    theme = ui_theme

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color8(232, 242, 233)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    scroll = ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(scroll)

    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 20)
    scroll.add_child(margin)

    content_root = VBoxContainer.new()
    content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_root.add_theme_constant_override("separation", 12)
    margin.add_child(content_root)

    var header_panel := PanelContainer.new()
    content_root.add_child(header_panel)

    var header := VBoxContainer.new()
    header.add_theme_constant_override("separation", 9)
    header_panel.add_child(header)

    header_title = Label.new()
    header_title.add_theme_font_size_override("font_size", 24)
    header_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    header.add_child(header_title)

    header_subtitle = Label.new()
    header_subtitle.add_theme_font_size_override("font_size", 14)
    header_subtitle.add_theme_color_override("font_color", Color8(64, 92, 74))
    header.add_child(header_subtitle)

    var controls := HBoxContainer.new()
    controls.alignment = BoxContainer.ALIGNMENT_END
    controls.add_theme_constant_override("separation", 8)
    header.add_child(controls)

    pause_btn = _button("一時停止", _toggle_pause)
    pause_btn.custom_minimum_size = Vector2(104, 58)
    speed_btn = _button("速度 ×1", _cycle_speed)
    speed_btn.custom_minimum_size = Vector2(96, 58)
    audio_btn = _button("", _cycle_audio_level)
    audio_btn.custom_minimum_size = Vector2(96, 58)
    controls.add_child(pause_btn)
    controls.add_child(speed_btn)
    controls.add_child(audio_btn)
    _update_audio_button()

    stats_grid = GridContainer.new()
    stats_grid.columns = 5
    stats_grid.add_theme_constant_override("h_separation", 8)
    stats_grid.add_theme_constant_override("v_separation", 8)
    content_root.add_child(stats_grid)

    var stat_items := [
        ["day", "DAY"],
        ["coin", "所持金"],
        ["water", "水"],
        ["soil", "土"],
        ["weather", "天気"]
    ]
    for item in stat_items:
        var key := str(item[0])
        var caption_text := str(item[1])
        var card := PanelContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.custom_minimum_size = Vector2(0, 76)
        stats_grid.add_child(card)

        var card_box := VBoxContainer.new()
        card_box.add_theme_constant_override("separation", 2)
        card.add_child(card_box)

        var caption := Label.new()
        caption.text = caption_text
        caption.add_theme_font_size_override("font_size", 13)
        caption.add_theme_color_override("font_color", Color8(74, 94, 81))
        card_box.add_child(caption)

        var value := Label.new()
        value.add_theme_font_size_override("font_size", 20)
        value.add_theme_color_override("font_color", Color8(22, 62, 39))
        card_box.add_child(value)
        stats_labels[key] = value

    var timer_panel := PanelContainer.new()
    content_root.add_child(timer_panel)

    var timer_row := HBoxContainer.new()
    timer_row.add_theme_constant_override("separation", 10)
    timer_panel.add_child(timer_row)

    timer_label = Label.new()
    timer_label.custom_minimum_size = Vector2(112, 0)
    timer_label.add_theme_font_size_override("font_size", 16)
    timer_row.add_child(timer_label)

    timer_bar = ProgressBar.new()
    timer_bar.min_value = 0
    timer_bar.max_value = DAY_SECONDS
    timer_bar.show_percentage = false
    timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    timer_bar.custom_minimum_size = Vector2(120, 20)
    timer_row.add_child(timer_bar)

    main_grid = GridContainer.new()
    main_grid.columns = 2
    main_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_grid.add_theme_constant_override("h_separation", 12)
    main_grid.add_theme_constant_override("v_separation", 12)
    content_root.add_child(main_grid)

    farm_panel_ref = PanelContainer.new()
    farm_panel_ref.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_grid.add_child(farm_panel_ref)

    var farm_box := VBoxContainer.new()
    farm_box.add_theme_constant_override("separation", 10)
    farm_panel_ref.add_child(farm_box)

    visual = FARM_VISUAL.new()
    visual.custom_minimum_size = Vector2(540, 360)
    visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    farm_box.add_child(visual)

    growth = Label.new()
    growth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    growth.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    growth.add_theme_font_size_override("font_size", 18)
    growth.add_theme_color_override("font_color", Color8(29, 70, 46))
    farm_box.add_child(growth)

    side_panel_ref = PanelContainer.new()
    side_panel_ref.custom_minimum_size = Vector2(340, 0)
    side_panel_ref.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_grid.add_child(side_panel_ref)

    var side := VBoxContainer.new()
    side.add_theme_constant_override("separation", 10)
    side_panel_ref.add_child(side)

    var choose_title := Label.new()
    choose_title.text = "種を選ぶ"
    choose_title.add_theme_font_size_override("font_size", 20)
    side.add_child(choose_title)

    var crop_grid := GridContainer.new()
    crop_grid.columns = 1
    crop_grid.add_theme_constant_override("v_separation", 8)
    side.add_child(crop_grid)

    for key in ["radish", "lettuce", "tomato"]:
        var data: Dictionary = CROPS[key]
        var crop_btn := Button.new()
        crop_btn.text = "%s  %dG / %d日\n%s" % [data.name, int(data.seed), int(data.days), data.note]
        crop_btn.custom_minimum_size = Vector2(0, 64)
        crop_btn.toggle_mode = true
        crop_btn.add_theme_font_size_override("font_size", 16)
        crop_btn.pressed.connect(_choose_crop.bind(key))
        crop_grid.add_child(crop_btn)
        crop_buttons[key] = crop_btn

    var action_title := Label.new()
    action_title.text = "今日の操作"
    action_title.add_theme_font_size_override("font_size", 20)
    side.add_child(action_title)

    var action_grid := GridContainer.new()
    action_grid.columns = 2
    action_grid.add_theme_constant_override("h_separation", 8)
    action_grid.add_theme_constant_override("v_separation", 8)
    side.add_child(action_grid)

    plant_btn = _button("種を植える", _plant)
    water_btn = _button("水やり", _water)
    compost_btn = _button("土を整える\n-5G", _compost)
    harvest_btn = _button("収穫", _harvest)
    action_grid.add_child(plant_btn)
    action_grid.add_child(water_btn)
    action_grid.add_child(compost_btn)
    action_grid.add_child(harvest_btn)

    help_label = Label.new()
    help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help_label.add_theme_font_size_override("font_size", 15)
    help_label.add_theme_color_override("font_color", Color8(63, 82, 70))
    side.add_child(help_label)

    var log_title := Label.new()
    log_title.text = "農園ログ"
    log_title.add_theme_font_size_override("font_size", 18)
    side.add_child(log_title)

    log_view = Label.new()
    log_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_view.custom_minimum_size = Vector2(0, 150)
    log_view.add_theme_font_size_override("font_size", 15)
    log_view.add_theme_color_override("font_color", Color8(49, 73, 58))
    side.add_child(log_view)

func _button(text_value: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text_value
    b.custom_minimum_size = Vector2(0, 58)
    b.add_theme_font_size_override("font_size", 17)
    b.pressed.connect(callback)
    return b

func _challenge() -> Dictionary:
    return CHALLENGES[selected_challenge]

func _apply_challenge_settings() -> void:
    var data := _challenge()
    challenge_max_day = int(data.max_day)
    challenge_target_coins = int(data.target_coins)
    challenge_start_coins = int(data.start_coins)
    challenge_start_water = int(data.start_water)
    challenge_start_soil = int(data.start_soil)
    challenge_water_refill = int(data.water_refill)
    challenge_required_harvests = int(data.required_harvests)

    day = 1
    coins = challenge_start_coins
    water_stock = challenge_start_water
    soil = challenge_start_soil
    selected = "radish"
    crop = {}
    logs = []
    weather_index = 0
    day_time = DAY_SECONDS
    paused = true
    speed = 1.0
    ended = false
    started = false
    harvests = 0

func _load_records() -> void:
    record_cache = {}
    var config := ConfigFile.new()
    var load_ok: bool = config.load(RECORDS_PATH) == OK
    for raw_key in CHALLENGES.keys():
        var key := str(raw_key)
        var section := "challenge_%s" % key
        record_cache[key] = {
            "best_coins": int(config.get_value(section, "best_coins", 0)) if load_ok else 0,
            "best_rank": str(config.get_value(section, "best_rank", "-")) if load_ok else "-",
            "cleared": bool(config.get_value(section, "cleared", false)) if load_ok else false,
            "plays": int(config.get_value(section, "plays", 0)) if load_ok else 0
        }

func _record_for(key: String) -> Dictionary:
    if record_cache.has(key):
        var saved: Dictionary = record_cache[key]
        return saved.duplicate(true)
    return {"best_coins": 0, "best_rank": "-", "cleared": false, "plays": 0}

func _rank_score(rank_text: String) -> int:
    match rank_text:
        "S":
            return 4
        "A":
            return 3
        "B":
            return 2
        "C":
            return 1
        _:
            return 0

func _grade_for_score(score: int) -> String:
    if score >= challenge_target_coins + 70:
        return "S"
    if score >= challenge_target_coins + 30:
        return "A"
    if score >= challenge_target_coins:
        return "B"
    return "C"

func _is_challenge_cleared() -> bool:
    return coins >= challenge_target_coins and harvests >= challenge_required_harvests

func _save_result_record(grade: String, cleared: bool) -> Dictionary:
    var record := _record_for(selected_challenge)
    record.best_coins = maxi(int(record.best_coins), coins)
    if _rank_score(grade) > _rank_score(str(record.best_rank)):
        record.best_rank = grade
    record.cleared = bool(record.cleared) or cleared
    record.plays = int(record.plays) + 1
    record_cache[selected_challenge] = record

    var config := ConfigFile.new()
    config.load(RECORDS_PATH)
    for raw_key in CHALLENGES.keys():
        var key := str(raw_key)
        var section := "challenge_%s" % key
        var saved := _record_for(key)
        config.set_value(section, "best_coins", int(saved.best_coins))
        config.set_value(section, "best_rank", str(saved.best_rank))
        config.set_value(section, "cleared", bool(saved.cleared))
        config.set_value(section, "plays", int(saved.plays))
    config.save(RECORDS_PATH)
    return record

func _challenge_condition_text(data: Dictionary) -> String:
    var required := int(data.required_harvests)
    var harvest_text := "" if required <= 0 else "・収穫%d回以上" % required
    return "%d日 / 目標%dG%s" % [int(data.max_day), int(data.target_coins), harvest_text]

func _record_text(key: String) -> String:
    var record := _record_for(key)
    if int(record.plays) <= 0:
        return "未挑戦"
    return "BEST %dG / RANK %s / %s" % [
        int(record.best_coins),
        str(record.best_rank),
        "CLEAR" if bool(record.cleared) else "未クリア"
    ]

func _choose_challenge(key: String) -> void:
    if started or not CHALLENGES.has(key):
        return
    selected_challenge = key
    _apply_challenge_settings()
    _update_challenge_copy()
    _play_sfx("select")
    _refresh()

func _update_challenge_copy() -> void:
    var data := _challenge()
    if header_title != null:
        header_title.text = "1マス農園  |  %s" % str(data.name)
    if header_subtitle != null:
        header_subtitle.text = "Kenney Tiny Farm × Godot 4.7.2  •  %s" % _challenge_condition_text(data)
    if help_label != null:
        help_label.text = "遊び方\n1. 種を選んで植える\n2. 水と土を管理する\n3. 育ったら収穫する\n\n%s\n%s" % [_challenge_condition_text(data), str(data.tagline)]
    if intro_summary != null:
        intro_summary.text = "%s\n%s" % [_challenge_condition_text(data), str(data.tagline)]
    if intro_records != null:
        intro_records.text = "このモードの記録: %s" % _record_text(selected_challenge)
    if intro_start_button != null:
        intro_start_button.text = "%sをはじめる" % str(data.name)
    for raw_key in challenge_buttons.keys():
        var key := str(raw_key)
        var button := challenge_buttons[key] as Button
        if button != null:
            button.button_pressed = key == selected_challenge

func _setup_audio_player() -> void:
    sfx_player = AudioStreamPlayer.new()
    add_child(sfx_player)

func _load_audio_settings() -> void:
    var config := ConfigFile.new()
    if config.load(AUDIO_SETTINGS_PATH) == OK:
        var saved_index := int(config.get_value("audio", "level_index", 1))
        audio_level_index = clampi(saved_index, 0, AUDIO_LEVELS.size() - 1)

func _save_audio_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "level_index", audio_level_index)
    config.save(AUDIO_SETTINGS_PATH)

func _audio_gain() -> float:
    return float(AUDIO_LEVELS[audio_level_index])

func _update_audio_button() -> void:
    if audio_btn == null:
        return
    var percent := roundi(_audio_gain() * 100.0)
    audio_btn.text = "音 ミュート" if percent == 0 else "音 %d%%" % percent

func _cycle_audio_level() -> void:
    audio_level_index = (audio_level_index + 1) % AUDIO_LEVELS.size()
    _save_audio_settings()
    _update_audio_button()
    if _audio_gain() > 0.0:
        _play_sfx("select")

func _play_sfx(key: String) -> void:
    if sfx_player == null or _audio_gain() <= 0.0 or not SFX_PATHS.has(key):
        return
    var path := str(SFX_PATHS[key])
    if not ResourceLoader.exists(path):
        return
    var stream := load(path) as AudioStream
    if stream == null:
        return
    sfx_player.stop()
    sfx_player.stream = stream
    sfx_player.volume_db = linear_to_db(_audio_gain())
    sfx_player.play()

func _choose_crop(key: String) -> void:
    if ended or not crop.is_empty() or not CROPS.has(key):
        return
    selected = key
    _play_sfx("select")
    _log("%sの種を選びました。" % CROPS[selected].name)

func _plant() -> void:
    if ended or not crop.is_empty():
        return
    var data: Dictionary = CROPS[selected]
    if coins < int(data.seed):
        _play_sfx("error")
        _log("種を買うお金が足りません。")
        return
    coins -= int(data.seed)
    crop = {"key": selected, "growth": 0.0, "watered": false, "health": 100}
    visual.plant_pop()
    _play_sfx("plant")
    _log("%sを植えました。" % data.name)

func _water() -> void:
    if ended or crop.is_empty() or bool(crop.watered) or water_stock <= 0:
        return
    water_stock -= 1
    crop.watered = true
    visual.splash_water()
    _play_sfx("water")
    _log("水やりをしました。")

func _compost() -> void:
    if ended:
        return
    if coins < 5:
        _play_sfx("error")
        _log("土づくり用の5Gが足りません。")
        return
    if soil >= 100:
        _play_sfx("error")
        _log("土はすでに最高の状態です。")
        return
    coins -= 5
    soil = min(100, soil + 24)
    visual.soil_burst()
    _play_sfx("compost")
    _log("土づくりをしました。")

func _harvest() -> void:
    if ended or crop.is_empty():
        return
    var data: Dictionary = CROPS[crop.key]
    if float(crop.growth) < float(data.days):
        _play_sfx("error")
        _log("まだ収穫には早いです。")
        return
    var revenue := roundi(float(data.sell) * maxf(0.55, float(crop.health) / 100.0) * (1.1 if soil >= 70 else 1.0))
    coins += revenue
    harvests += 1
    crop = {}
    soil = max(10, soil - 8)
    visual.harvest_burst()
    _play_sfx("harvest")
    _log("収穫成功！ +%dG" % revenue)

func _toggle_pause() -> void:
    if ended:
        return
    paused = not paused
    pause_btn.text = "再開" if paused else "一時停止"
    _play_sfx("select")
    _log("時間を一時停止しました。" if paused else "時間を再開しました。")

func _cycle_speed() -> void:
    if is_equal_approx(speed, 1.0):
        speed = 2.0
    elif is_equal_approx(speed, 2.0):
        speed = 4.0
    else:
        speed = 1.0
    speed_btn.text = "速度 ×%d" % int(speed)
    _play_sfx("select")
    _log("時間速度を×%dに変更しました。" % int(speed))

func _advance_day() -> void:
    if ended:
        return

    var weather_key: String = WEATHERS[weather_index].key
    if not crop.is_empty():
        var hydrated := bool(crop.watered) or weather_key == "rain"
        var soil_rate := 1.0 if soil >= 60 else (0.8 if soil >= 35 else 0.6)
        var water_rate := 1.0 if hydrated else 0.42
        crop.growth = float(crop.growth) + soil_rate * water_rate
        if not hydrated:
            crop.health = max(35, int(crop.health) - 14)
            logs.append("DAY %d: 水不足で作物が弱りました。" % day)
        else:
            crop.health = min(100, int(crop.health) + 2)
        crop.watered = false
        soil = max(10, soil - 6)

    if day >= challenge_max_day:
        _finish_game()
        return

    day += 1
    water_stock = min(5, water_stock + challenge_water_refill)
    weather_index = _next_weather()
    day_time = DAY_SECONDS
    _log("DAY %d。天気は%s。水が%d回分補充されました。" % [day, WEATHERS[weather_index].name, challenge_water_refill])

func _next_weather() -> int:
    var roll := randf()
    if roll < 0.55:
        return 0
    if roll < 0.80:
        return 1
    return 2

func _finish_game() -> void:
    ended = true
    paused = true
    day_time = 0.0
    var cleared := _is_challenge_cleared()
    var result := "チャレンジクリア！" if cleared else "チャレンジ終了！"
    var grade := _grade_for_score(coins)
    var record := _save_result_record(grade, cleared)
    _play_sfx("success" if cleared else "error")
    _log("%s 最終資金 %dG / 収穫 %d回 / ランク%s" % [result, coins, harvests, grade])
    _show_result(result, grade, cleared, record)
    pause_btn.disabled = true
    speed_btn.disabled = true
    plant_btn.disabled = true
    water_btn.disabled = true
    compost_btn.disabled = true
    harvest_btn.disabled = true

func _refresh() -> void:
    var weather_name: String = WEATHERS[weather_index].name
    if stats_labels.has("day"):
        stats_labels["day"].text = "%d / %d" % [day, challenge_max_day]
        stats_labels["coin"].text = "%d G" % coins
        stats_labels["water"].text = "%d / 5" % water_stock
        stats_labels["soil"].text = str(soil)
        stats_labels["weather"].text = weather_name

    if crop.is_empty():
        growth.text = "空きマス — 種を選んで植えてください"
    else:
        var data: Dictionary = CROPS[crop.key]
        var ratio := minf(1.0, float(crop.growth) / float(data.days))
        var ready := "　収穫できます！" if ratio >= 1.0 else ""
        var wet := "　水やり済み" if bool(crop.watered) else ""
        growth.text = "%s　成長 %d%%　元気 %d%%%s%s" % [data.name, roundi(ratio * 100.0), int(crop.health), wet, ready]

    for key in crop_buttons.keys():
        var crop_btn: Button = crop_buttons[key]
        crop_btn.disabled = ended or not crop.is_empty()
        crop_btn.button_pressed = key == selected

    plant_btn.disabled = ended or not crop.is_empty() or coins < int(CROPS[selected].seed)
    water_btn.disabled = ended or crop.is_empty() or bool(crop.get("watered", false)) or water_stock <= 0
    compost_btn.disabled = ended or coins < 5 or soil >= 100
    harvest_btn.disabled = ended or crop.is_empty() or (not crop.is_empty() and float(crop.growth) < float(CROPS[crop.key].days))
    log_view.text = "\n".join(logs.slice(max(0, logs.size() - 7)))
    _refresh_timer()
    _sync_visual()

func _refresh_timer() -> void:
    if timer_bar == null:
        return
    timer_bar.value = maxf(0.0, day_time)
    if ended:
        timer_label.text = "チャレンジ終了"
    elif paused:
        timer_label.text = "停止中"
    else:
        timer_label.text = "次の日まで %.1f秒" % (day_time / speed)

func _sync_visual() -> void:
    if visual == null:
        return
    var weather_key: String = WEATHERS[weather_index].key
    visual.set_farm_state(crop, weather_key, soil, clampf(day_time / DAY_SECONDS, 0.0, 1.0))

func _log(message: String) -> void:
    logs.append("DAY %d: %s" % [day, message])
    if logs.size() > 30:
        logs.pop_front()
    _refresh()


func _build_intro() -> void:
    intro_layer = ColorRect.new()
    intro_layer.color = Color(0.035, 0.075, 0.055, 0.94)
    intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(intro_layer)

    intro_scroll = ScrollContainer.new()
    intro_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    intro_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    intro_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    intro_layer.add_child(intro_scroll)

    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 8)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    intro_scroll.add_child(margin)

    var center := CenterContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(center)

    intro_panel = PanelContainer.new()
    intro_panel.custom_minimum_size = Vector2(350, 0)
    center.add_child(intro_panel)

    intro_box = VBoxContainer.new()
    intro_box.add_theme_constant_override("separation", 13)
    intro_panel.add_child(intro_box)

    var eyebrow := Label.new()
    eyebrow.text = "GAME-G001 / FARM MANAGEMENT"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 13)
    eyebrow.add_theme_color_override("font_color", Color8(55, 122, 78))
    intro_box.add_child(eyebrow)

    intro_title = Label.new()
    intro_title.text = "1マス農園"
    intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro_title.add_theme_font_size_override("font_size", 36)
    intro_box.add_child(title)

    intro_summary = Label.new()
    intro_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro_summary.add_theme_font_size_override("font_size", 17)
    intro_box.add_child(intro_summary)

    var challenge_title := Label.new()
    challenge_title.text = "チャレンジを選ぶ"
    challenge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    challenge_title.add_theme_font_size_override("font_size", 16)
    challenge_title.add_theme_color_override("font_color", Color8(55, 122, 78))
    intro_box.add_child(challenge_title)

    intro_challenge_grid = GridContainer.new()
    intro_challenge_grid.columns = 1
    intro_challenge_grid.add_theme_constant_override("v_separation", 7)
    intro_box.add_child(intro_challenge_grid)

    for key in ["standard", "sprint", "drought"]:
        var data: Dictionary = CHALLENGES[key]
        var mode_btn := Button.new()
        mode_btn.text = "%s\n%s" % [str(data.name), _challenge_condition_text(data)]
        mode_btn.toggle_mode = true
        mode_btn.custom_minimum_size = Vector2(0, 64)
        mode_btn.add_theme_font_size_override("font_size", 15)
        mode_btn.pressed.connect(_choose_challenge.bind(key))
        intro_challenge_grid.add_child(mode_btn)
        challenge_buttons[key] = mode_btn

    intro_records = Label.new()
    intro_records.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro_records.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro_records.add_theme_font_size_override("font_size", 14)
    intro_records.add_theme_color_override("font_color", Color8(72, 94, 80))
    intro_box.add_child(intro_records)

    intro_rules = Label.new()
    intro_rules.text = "ラディッシュ：早い・安定 / レタス：バランス / トマト：遅い・高収益\n雨の日は水やり不要。土が弱ると成長が遅くなります。"
    intro_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro_rules.add_theme_font_size_override("font_size", 13)
    intro_rules.add_theme_color_override("font_color", Color8(72, 94, 80))
    intro_box.add_child(intro_rules)

    intro_start_button = _button("農園をはじめる", _start_game)
    intro_start_button.custom_minimum_size = Vector2(0, 58)
    intro_box.add_child(intro_start_button)

    intro_credit = Label.new()
    intro_credit.text = "Art: Kenney Tiny Farm (CC0) / Font: Noto Sans JP"
    intro_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intro_credit.add_theme_font_size_override("font_size", 11)
    intro_credit.add_theme_color_override("font_color", Color8(92, 110, 98))
    intro_box.add_child(intro_credit)

func _start_game() -> void:
    if started:
        return
    _apply_challenge_settings()
    started = true
    paused = false
    _update_challenge_copy()
    if intro_layer != null:
        intro_layer.hide()
    _play_sfx("success")
    _log("%sスタート！" % _challenge().name)

func _show_result(result: String, grade: String, cleared: bool, record: Dictionary) -> void:
    if result_layer != null:
        return
    result_layer = ColorRect.new()
    result_layer.color = Color(0.025, 0.07, 0.05, 0.92)
    result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(result_layer)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_layer.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(350, 300)
    center.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 15)
    panel.add_child(box)

    var title := Label.new()
    title.text = result
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    box.add_child(title)

    result_text = Label.new()
    var clear_text := "CLEAR" if cleared else "未クリア"
    result_text.text = "%s\n%s\n最終資金 %dG / 収穫 %d回\n農園ランク %s  •  %s\nBEST %dG / RANK %s / 挑戦%d回" % [
        str(_challenge().name),
        _challenge_condition_text(_challenge()),
        coins,
        harvests,
        grade,
        clear_text,
        int(record.best_coins),
        str(record.best_rank),
        int(record.plays)
    ]
    result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result_text.add_theme_font_size_override("font_size", 19)
    box.add_child(result_text)

    var again := _button("チャレンジ選択へ戻る", _restart_game)
    again.custom_minimum_size = Vector2(0, 58)
    box.add_child(again)

func _restart_game() -> void:
    get_tree().reload_current_scene()


func _input(event: InputEvent) -> void:
    if not started:
        if event is InputEventKey:
            var key_event: InputEventKey = event as InputEventKey
            if key_event.pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
                _start_game()
                get_viewport().set_input_as_handled()
        return

    if ended:
        return
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if not key_event.pressed:
            return
        if key_event.keycode == KEY_1:
            _plant()
        elif key_event.keycode == KEY_2:
            _water()
        elif key_event.keycode == KEY_3:
            _compost()
        elif key_event.keycode == KEY_4:
            _harvest()
