extends Control

const FONT_PATH := "res://fonts/NotoSansJP.ttf"
const FARM_VISUAL = preload("res://FarmVisual.gd")
const DAY_SECONDS := 8.0
const MAX_DAY := 15

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
var harvests := 0

var stats: Label
var timer_label: Label
var timer_bar: ProgressBar
var growth: Label
var log_view: Label
var chooser: OptionButton
var plant_btn: Button
var water_btn: Button
var compost_btn: Button
var harvest_btn: Button
var pause_btn: Button
var speed_btn: Button
var visual: Control

func _ready() -> void:
    _setup_theme()
    _build_ui()
    _log("農園スタート。時間は自動で進みます。")
    _refresh()

func _process(delta: float) -> void:
    if ended or paused:
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
    ui_theme.default_font_size = 17

    ui_theme.set_color("font_color", "Label", Color8(36, 55, 45))
    ui_theme.set_color("font_color", "Button", Color8(36, 55, 45))
    ui_theme.set_color("font_hover_color", "Button", Color8(15, 82, 50))
    ui_theme.set_color("font_pressed_color", "Button", Color8(15, 82, 50))
    ui_theme.set_color("font_disabled_color", "Button", Color8(135, 145, 138))
    ui_theme.set_color("font_color", "OptionButton", Color8(36, 55, 45))

    var button_style := StyleBoxFlat.new()
    button_style.bg_color = Color8(244, 249, 244)
    button_style.border_color = Color8(198, 218, 203)
    button_style.set_border_width_all(1)
    button_style.set_corner_radius_all(14)
    button_style.content_margin_left = 14
    button_style.content_margin_right = 14
    button_style.content_margin_top = 10
    button_style.content_margin_bottom = 10
    ui_theme.set_stylebox("normal", "Button", button_style)
    ui_theme.set_stylebox("normal", "OptionButton", button_style)

    var hover_style := button_style.duplicate() as StyleBoxFlat
    hover_style.bg_color = Color8(225, 244, 230)
    hover_style.border_color = Color8(89, 173, 114)
    ui_theme.set_stylebox("hover", "Button", hover_style)
    ui_theme.set_stylebox("hover", "OptionButton", hover_style)

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color8(255, 255, 255, 245)
    panel_style.border_color = Color8(215, 229, 218)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(20)
    panel_style.content_margin_left = 18
    panel_style.content_margin_right = 18
    panel_style.content_margin_top = 16
    panel_style.content_margin_bottom = 16
    ui_theme.set_stylebox("panel", "PanelContainer", panel_style)

    theme = ui_theme

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color8(234, 242, 234)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    margin.add_child(root)

    var header := HBoxContainer.new()
    root.add_child(header)

    var title_box := VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_box)

    var title := Label.new()
    title.text = "GAME-G001  |  1マス農園"
    title.add_theme_font_size_override("font_size", 28)
    title_box.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Godot版 v3  •  時間自動進行  •  アニメ農園"
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", Color8(74, 112, 89))
    title_box.add_child(subtitle)

    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 8)
    header.add_child(controls)

    pause_btn = _button("一時停止", _toggle_pause)
    pause_btn.custom_minimum_size = Vector2(110, 44)
    speed_btn = _button("速度 ×1", _cycle_speed)
    speed_btn.custom_minimum_size = Vector2(105, 44)
    controls.add_child(pause_btn)
    controls.add_child(speed_btn)

    var status_panel := PanelContainer.new()
    root.add_child(status_panel)
    var status_box := VBoxContainer.new()
    status_box.add_theme_constant_override("separation", 7)
    status_panel.add_child(status_box)

    stats = Label.new()
    stats.add_theme_font_size_override("font_size", 17)
    status_box.add_child(stats)

    var timer_row := HBoxContainer.new()
    timer_row.add_theme_constant_override("separation", 10)
    status_box.add_child(timer_row)
    timer_label = Label.new()
    timer_label.custom_minimum_size = Vector2(150, 0)
    timer_row.add_child(timer_label)
    timer_bar = ProgressBar.new()
    timer_bar.min_value = 0
    timer_bar.max_value = DAY_SECONDS
    timer_bar.show_percentage = false
    timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    timer_bar.custom_minimum_size = Vector2(300, 18)
    timer_row.add_child(timer_bar)

    var main := HBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation", 12)
    root.add_child(main)

    var farm_panel := PanelContainer.new()
    farm_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    farm_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_child(farm_panel)

    var farm_box := VBoxContainer.new()
    farm_box.add_theme_constant_override("separation", 8)
    farm_panel.add_child(farm_box)

    visual = FARM_VISUAL.new()
    visual.custom_minimum_size = Vector2(540, 360)
    visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
    farm_box.add_child(visual)

    growth = Label.new()
    growth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    growth.add_theme_font_size_override("font_size", 16)
    farm_box.add_child(growth)

    var side_panel := PanelContainer.new()
    side_panel.custom_minimum_size = Vector2(315, 0)
    main.add_child(side_panel)

    var side := VBoxContainer.new()
    side.add_theme_constant_override("separation", 8)
    side_panel.add_child(side)

    var choose_title := Label.new()
    choose_title.text = "種を選ぶ"
    choose_title.add_theme_font_size_override("font_size", 19)
    side.add_child(choose_title)

    chooser = OptionButton.new()
    chooser.add_item("ラディッシュ　8G / 3日")
    chooser.add_item("レタス　12G / 4日")
    chooser.add_item("トマト　18G / 5日")
    chooser.item_selected.connect(_choose)
    side.add_child(chooser)

    plant_btn = _button("植える", _plant)
    water_btn = _button("水やり", _water)
    compost_btn = _button("土づくり　-5G", _compost)
    harvest_btn = _button("収穫", _harvest)
    side.add_child(plant_btn)
    side.add_child(water_btn)
    side.add_child(compost_btn)
    side.add_child(harvest_btn)

    var help := Label.new()
    help.text = "時間は止まりません。\n作物を見ながら、水・土・収穫を判断してください。"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.add_theme_font_size_override("font_size", 12)
    help.add_theme_color_override("font_color", Color8(92, 111, 99))
    side.add_child(help)

    var log_title := Label.new()
    log_title.text = "農園ログ"
    log_title.add_theme_font_size_override("font_size", 17)
    side.add_child(log_title)

    log_view = Label.new()
    log_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_view.add_theme_font_size_override("font_size", 12)
    side.add_child(log_view)

func _button(text_value: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text_value
    b.custom_minimum_size = Vector2(0, 46)
    b.pressed.connect(callback)
    return b

func _choose(index: int) -> void:
    if ended or not crop.is_empty():
        return
    selected = ["radish", "lettuce", "tomato"][index]
    _log("%sの種を選びました。" % CROPS[selected].name)

func _plant() -> void:
    if ended or not crop.is_empty():
        return
    var data: Dictionary = CROPS[selected]
    if coins < int(data.seed):
        _log("種を買うお金が足りません。")
        return
    coins -= int(data.seed)
    crop = {"key": selected, "growth": 0.0, "watered": false, "health": 100}
    visual.plant_pop()
    _log("%sを植えました。" % data.name)

func _water() -> void:
    if ended or crop.is_empty() or bool(crop.watered) or water_stock <= 0:
        return
    water_stock -= 1
    crop.watered = true
    visual.splash_water()
    _log("水やりをしました。")

func _compost() -> void:
    if ended:
        return
    if coins < 5:
        _log("土づくり用の5Gが足りません。")
        return
    if soil >= 100:
        _log("土はすでに最高の状態です。")
        return
    coins -= 5
    soil = min(100, soil + 24)
    visual.soil_burst()
    _log("土づくりをしました。")

func _harvest() -> void:
    if ended or crop.is_empty():
        return
    var data: Dictionary = CROPS[crop.key]
    if float(crop.growth) < float(data.days):
        _log("まだ収穫には早いです。")
        return
    var revenue := roundi(float(data.sell) * maxf(0.55, float(crop.health) / 100.0) * (1.1 if soil >= 70 else 1.0))
    coins += revenue
    harvests += 1
    crop = {}
    soil = max(10, soil - 8)
    visual.harvest_burst()
    _log("収穫成功！ +%dG" % revenue)

func _toggle_pause() -> void:
    if ended:
        return
    paused = not paused
    pause_btn.text = "再開" if paused else "一時停止"
    _log("時間を一時停止しました。" if paused else "時間を再開しました。")

func _cycle_speed() -> void:
    if is_equal_approx(speed, 1.0):
        speed = 2.0
    elif is_equal_approx(speed, 2.0):
        speed = 4.0
    else:
        speed = 1.0
    speed_btn.text = "速度 ×%d" % int(speed)
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

    if day >= MAX_DAY:
        _finish_game()
        return

    day += 1
    water_stock = min(5, water_stock + 2)
    weather_index = _next_weather()
    day_time = DAY_SECONDS
    _log("DAY %d。天気は%s。水が2回分補充されました。" % [day, WEATHERS[weather_index].name])

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
    var result := "農園、大成功！" if coins >= 150 else "15日間終了！"
    _log("%s 最終資金 %dG / 収穫 %d回" % [result, coins, harvests])
    pause_btn.disabled = true
    speed_btn.disabled = true
    plant_btn.disabled = true
    water_btn.disabled = true
    compost_btn.disabled = true
    harvest_btn.disabled = true

func _refresh() -> void:
    var weather_name: String = WEATHERS[weather_index].name
    stats.text = "DAY %d / %d　　所持金 %dG　　水 %d/5　　土 %d　　天気 %s" % [day, MAX_DAY, coins, water_stock, soil, weather_name]

    if crop.is_empty():
        growth.text = "空きマス — 種を選んで植えてください"
    else:
        var data: Dictionary = CROPS[crop.key]
        var ratio := minf(1.0, float(crop.growth) / float(data.days))
        var ready := "　収穫できます！" if ratio >= 1.0 else ""
        var wet := "　水やり済み" if bool(crop.watered) else ""
        growth.text = "%s　成長 %d%%　元気 %d%%%s%s" % [data.name, roundi(ratio * 100.0), int(crop.health), wet, ready]

    chooser.disabled = ended or not crop.is_empty()
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
        timer_label.text = "15日間終了"
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
