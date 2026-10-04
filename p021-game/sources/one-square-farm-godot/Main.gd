extends Control

const CROPS := {
    "radish": {"name":"ラディッシュ","emoji":"🥕","seed":8,"days":3.0,"sell":24},
    "lettuce": {"name":"レタス","emoji":"🥬","seed":12,"days":4.0,"sell":38},
    "tomato": {"name":"トマト","emoji":"🍅","seed":18,"days":5.0,"sell":58}
}

var day := 1
var coins := 60
var water_stock := 3
var soil := 70
var selected := "radish"
var crop: Dictionary = {}
var logs: Array[String] = []

var stats: Label
var plot: Label
var growth: Label
var log_view: Label
var chooser: OptionButton
var plant_btn: Button
var water_btn: Button
var compost_btn: Button
var harvest_btn: Button
var next_btn: Button

func _ready() -> void:
    _build_ui()
    _log("1マス農園へようこそ。")
    _refresh()

func _build_ui() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",24)
    margin.add_theme_constant_override("margin_right",24)
    margin.add_theme_constant_override("margin_top",20)
    margin.add_theme_constant_override("margin_bottom",20)
    add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation",12)
    margin.add_child(root)

    var title := Label.new()
    title.text = "GAME-G001  |  1マス農園"
    title.add_theme_font_size_override("font_size",30)
    root.add_child(title)

    stats = Label.new()
    stats.add_theme_font_size_override("font_size",18)
    root.add_child(stats)

    var main := HBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation",18)
    root.add_child(main)

    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main.add_child(left)

    plot = Label.new()
    plot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    plot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    plot.custom_minimum_size = Vector2(420,330)
    plot.add_theme_font_size_override("font_size",116)
    left.add_child(plot)

    growth = Label.new()
    growth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    growth.add_theme_font_size_override("font_size",18)
    left.add_child(growth)

    var right := VBoxContainer.new()
    right.custom_minimum_size = Vector2(320,0)
    right.add_theme_constant_override("separation",8)
    main.add_child(right)

    chooser = OptionButton.new()
    chooser.add_item("ラディッシュ")
    chooser.add_item("レタス")
    chooser.add_item("トマト")
    chooser.item_selected.connect(_choose)
    right.add_child(chooser)

    plant_btn = _button("🌱 植える",_plant)
    water_btn = _button("💧 水やり",_water)
    compost_btn = _button("🪱 土づくり -5G",_compost)
    harvest_btn = _button("🧺 収穫",_harvest)
    next_btn = _button("日を進める →",_next_day)
    right.add_child(plant_btn)
    right.add_child(water_btn)
    right.add_child(compost_btn)
    right.add_child(harvest_btn)
    right.add_child(next_btn)

    log_view = Label.new()
    log_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(log_view)

func _button(text_value:String, callback:Callable) -> Button:
    var b := Button.new()
    b.text = text_value
    b.custom_minimum_size = Vector2(0,48)
    b.pressed.connect(callback)
    return b

func _choose(index:int) -> void:
    if not crop.is_empty(): return
    selected = ["radish","lettuce","tomato"][index]
    _log("%sの種を選んだ。" % CROPS[selected].name)

func _plant() -> void:
    if not crop.is_empty(): return
    var d:Dictionary = CROPS[selected]
    if coins < int(d.seed):
        _log("種を買うお金が足りない。")
        return
    coins -= int(d.seed)
    crop = {"key":selected,"growth":0.0,"watered":false,"health":100}
    _log("%sを植えた。" % d.name)

func _water() -> void:
    if crop.is_empty() or bool(crop.watered) or water_stock <= 0: return
    water_stock -= 1
    crop.watered = true
    _log("水をやった。")

func _compost() -> void:
    if coins < 5 or soil >= 100: return
    coins -= 5
    soil = min(100,soil + 24)
    _log("土づくりをした。")

func _harvest() -> void:
    if crop.is_empty(): return
    var d:Dictionary = CROPS[crop.key]
    if float(crop.growth) < float(d.days):
        _log("まだ収穫には早い。")
        return
    var revenue := roundi(float(d.sell) * maxf(0.55,float(crop.health)/100.0) * (1.1 if soil >= 70 else 1.0))
    coins += revenue
    crop = {}
    soil = max(10,soil - 8)
    _log("収穫！ +%dG" % revenue)

func _next_day() -> void:
    if day >= 15:
        _log(("農園、大成功！" if coins >= 150 else "15日終了！") + " 最終資金 %dG" % coins)
        next_btn.disabled = true
        return
    if not crop.is_empty():
        var hydrated := bool(crop.watered)
        crop.growth = float(crop.growth) + (1.0 if hydrated else 0.42) * (1.0 if soil >= 60 else 0.8)
        if not hydrated: crop.health = max(35,int(crop.health)-14)
        crop.watered = false
        soil = max(10,soil - 6)
    day += 1
    water_stock = min(5,water_stock + 2)
    _log("DAY %d。水が2回分補充された。" % day)

func _refresh() -> void:
    stats.text = "DAY %d / 15    所持金 %dG    水 %d/5    土 %d" % [day,coins,water_stock,soil]
    if crop.is_empty():
        plot.text = "🟫"
        growth.text = "空きマス — 作物を選んで植えよう"
    else:
        var d:Dictionary = CROPS[crop.key]
        var ratio := minf(1.0,float(crop.growth)/float(d.days))
        plot.text = d.emoji if ratio >= 1.0 else ("🌱" if ratio < 0.35 else "🌿")
        growth.text = "%s  成長 %d%%  元気 %d%%" % [d.name,roundi(ratio*100.0),int(crop.health)]
    chooser.disabled = not crop.is_empty()
    plant_btn.disabled = not crop.is_empty()
    water_btn.disabled = crop.is_empty() or bool(crop.get("watered",false)) or water_stock <= 0
    compost_btn.disabled = coins < 5 or soil >= 100
    harvest_btn.disabled = crop.is_empty() or (not crop.is_empty() and float(crop.growth) < float(CROPS[crop.key].days))
    next_btn.text = "結果を見る →" if day >= 15 else "日を進める →"
    log_view.text = "\n".join(logs.slice(max(0,logs.size()-9)))

func _log(message:String) -> void:
    logs.append("DAY %d: %s" % [day,message])
    _refresh()
