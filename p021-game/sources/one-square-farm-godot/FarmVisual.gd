extends Control

var crop: Dictionary = {}
var weather_key := "sun"
var soil := 70
var day_progress := 1.0

var clock := 0.0
var water_fx := 0.0
var harvest_fx := 0.0
var plant_fx := 0.0
var soil_fx := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func set_farm_state(crop_state: Dictionary, weather: String, soil_value: int, progress: float) -> void:
    crop = crop_state.duplicate(true)
    weather_key = weather
    soil = soil_value
    day_progress = progress
    queue_redraw()

func splash_water() -> void:
    water_fx = 1.1

func harvest_burst() -> void:
    harvest_fx = 1.3

func plant_pop() -> void:
    plant_fx = 0.8

func soil_burst() -> void:
    soil_fx = 0.8

func _process(delta: float) -> void:
    clock += delta
    water_fx = maxf(0.0, water_fx - delta)
    harvest_fx = maxf(0.0, harvest_fx - delta)
    plant_fx = maxf(0.0, plant_fx - delta)
    soil_fx = maxf(0.0, soil_fx - delta)
    queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    if w < 20.0 or h < 20.0:
        return

    _draw_sky(w, h)
    _draw_weather(w, h)
    _draw_ground(w, h)
    _draw_plot(w, h)
    _draw_plant(w, h)
    _draw_effects(w, h)

func _draw_sky(w: float, h: float) -> void:
    var sky_h := h * 0.58
    var sky_color := Color8(182, 224, 239)
    if weather_key == "cloud":
        sky_color = Color8(197, 215, 218)
    elif weather_key == "rain":
        sky_color = Color8(156, 184, 195)
    draw_rect(Rect2(0, 0, w, sky_h), sky_color)

    var sun_x := w * (0.18 + 0.64 * (1.0 - day_progress))
    var sun_y := 74.0 - sin((1.0 - day_progress) * PI) * 22.0
    if weather_key != "rain":
        draw_circle(Vector2(sun_x, sun_y), 28.0, Color8(255, 215, 85))
        draw_circle(Vector2(sun_x - 7, sun_y - 6), 4.0, Color8(255, 235, 150, 160))

func _draw_weather(w: float, h: float) -> void:
    if weather_key == "cloud" or weather_key == "rain":
        _cloud(Vector2(w * 0.28, 78), 1.0)
        _cloud(Vector2(w * 0.70, 104), 0.82)

    if weather_key == "rain":
        for i in range(18):
            var x := fmod(float(i * 71) + clock * 115.0, w + 40.0) - 20.0
            var y := 105.0 + fmod(float(i * 43) + clock * 175.0, h * 0.38)
            draw_line(Vector2(x, y), Vector2(x - 7, y + 17), Color8(82, 145, 205, 190), 3.0)

func _cloud(center: Vector2, scale_value: float) -> void:
    var c := Color8(245, 248, 247, 225)
    draw_circle(center + Vector2(-34, 5) * scale_value, 25.0 * scale_value, c)
    draw_circle(center + Vector2(0, -7) * scale_value, 34.0 * scale_value, c)
    draw_circle(center + Vector2(36, 7) * scale_value, 24.0 * scale_value, c)
    draw_rect(Rect2(center + Vector2(-48, 2) * scale_value, Vector2(96, 32) * scale_value), c)

func _draw_ground(w: float, h: float) -> void:
    var ground_y := h * 0.56
    draw_rect(Rect2(0, ground_y, w, h - ground_y), Color8(137, 194, 105))
    for i in range(10):
        var x := float(i) * w / 9.0
        var sway := sin(clock * 1.7 + float(i)) * 4.0
        draw_line(Vector2(x, ground_y + 26), Vector2(x + sway, ground_y + 8), Color8(88, 152, 77), 2.0)

func _draw_plot(w: float, h: float) -> void:
    var cx := w * 0.5
    var top_y := h * 0.58
    var bottom_y := h * 0.93
    var half_top := w * 0.29
    var half_bottom := w * 0.38
    var points := PackedVector2Array([
        Vector2(cx - half_top, top_y),
        Vector2(cx + half_top, top_y),
        Vector2(cx + half_bottom, bottom_y),
        Vector2(cx - half_bottom, bottom_y)
    ])
    var soil_color := Color8(106, 72, 48)
    if soil >= 75:
        soil_color = Color8(92, 63, 42)
    elif soil < 40:
        soil_color = Color8(132, 96, 68)
    draw_colored_polygon(points, soil_color)

    for row in range(5):
        var yy := lerpf(top_y + 26.0, bottom_y - 22.0, float(row) / 4.0)
        var width := lerpf(half_top * 1.45, half_bottom * 1.55, float(row) / 4.0)
        draw_line(Vector2(cx - width, yy), Vector2(cx + width, yy), Color8(72, 48, 34, 135), 3.0)

    if soil_fx > 0.0:
        var p := 1.0 - soil_fx / 0.8
        for i in range(9):
            var a := float(i) / 9.0 * TAU
            var pos := Vector2(cx, h * 0.72) + Vector2(cos(a), sin(a)) * (18.0 + p * 52.0)
            draw_circle(pos, 5.0 * (1.0 - p * 0.45), Color8(120, 82, 55, int(210.0 * (1.0 - p))))

func _draw_plant(w: float, h: float) -> void:
    if crop.is_empty():
        return

    var key: String = crop.get("key", "radish")
    var growth := maxf(0.0, float(crop.get("growth", 0.0)))
    var max_days := 3.0
    if key == "lettuce":
        max_days = 4.0
    elif key == "tomato":
        max_days = 5.0
    var g := clampf(growth / max_days, 0.08, 1.0)
    var health := clampf(float(crop.get("health", 100)) / 100.0, 0.35, 1.0)

    var cx := w * 0.5
    var base_y := h * 0.73
    var pop_scale := 1.0 + sin((1.0 - plant_fx / 0.8) * PI) * 0.18 if plant_fx > 0.0 else 1.0
    var sway := sin(clock * 2.2) * (3.0 + 5.0 * g)
    var height := (55.0 + 125.0 * g) * pop_scale
    var top := Vector2(cx + sway, base_y - height)

    var stem_color := Color8(int(72 + 25 * health), int(132 + 70 * health), 65)
    draw_line(Vector2(cx, base_y + 10), top, stem_color, 10.0 * maxf(0.55, g))

    var leaf_color := Color8(int(75 + 25 * health), int(145 + 70 * health), int(70 + 22 * health))
    var leaf_count := 2 + int(g * 4.0)
    for i in range(leaf_count):
        var t := float(i + 1) / float(leaf_count + 1)
        var y := lerpf(base_y - 18.0, top.y + 18.0, t)
        var side := -1.0 if i % 2 == 0 else 1.0
        var leaf_center := Vector2(cx + sway * t + side * (24.0 + 18.0 * g), y)
        draw_circle(leaf_center, 15.0 + 7.0 * g, leaf_color)
        draw_line(Vector2(cx + sway * t, y + 5), leaf_center, stem_color, 4.0)

    if g >= 0.72:
        if key == "tomato":
            _draw_tomatoes(Vector2(cx + sway * 0.7, top.y + 55), g)
        elif key == "lettuce":
            _draw_lettuce(Vector2(cx, base_y - 42), g, leaf_color)
        else:
            _draw_radish(Vector2(cx, base_y - 8), g)

func _draw_tomatoes(center: Vector2, g: float) -> void:
    var red := Color8(226, 69, 52)
    var shine := Color8(255, 153, 117)
    for offset in [Vector2(-28, 0), Vector2(8, 18), Vector2(34, -8)]:
        var radius := 12.0 + 8.0 * g
        draw_circle(center + offset, radius, red)
        draw_circle(center + offset + Vector2(-5, -6), 3.5, shine)

func _draw_lettuce(center: Vector2, g: float, base_color: Color) -> void:
    for i in range(8):
        var a := float(i) / 8.0 * TAU + clock * 0.03
        var pos := center + Vector2(cos(a), sin(a) * 0.55) * (18.0 + 12.0 * g)
        draw_circle(pos, 18.0 + 7.0 * g, base_color)
    draw_circle(center, 23.0 + 7.0 * g, Color8(125, 200, 90))

func _draw_radish(center: Vector2, g: float) -> void:
    var r := 17.0 + 11.0 * g
    draw_circle(center, r, Color8(226, 79, 104))
    draw_circle(center + Vector2(-7, -8), 5.0, Color8(250, 151, 165))
    draw_line(center + Vector2(0, r - 2), center + Vector2(4, r + 25), Color8(235, 215, 184), 4.0)

func _draw_effects(w: float, h: float) -> void:
    var center := Vector2(w * 0.5, h * 0.62)

    if water_fx > 0.0:
        var p := 1.0 - water_fx / 1.1
        for i in range(12):
            var a := -PI * 0.85 + float(i) / 11.0 * PI * 0.7
            var origin := Vector2(w * 0.72, h * 0.42)
            var dist := 55.0 + p * 115.0 + float(i % 3) * 9.0
            var pos := origin + Vector2(cos(a), sin(a)) * dist
            draw_circle(pos, 4.5, Color8(71, 159, 226, int(220.0 * (1.0 - p * 0.6))))

    if harvest_fx > 0.0:
        var p2 := 1.0 - harvest_fx / 1.3
        for i in range(10):
            var a2 := float(i) / 10.0 * TAU
            var radius := 30.0 + p2 * 105.0
            var pos2 := center + Vector2(cos(a2), sin(a2)) * radius + Vector2(0, -p2 * 45.0)
            draw_circle(pos2, 9.0 * (1.0 - p2 * 0.25), Color8(255, 199, 61, int(235.0 * (1.0 - p2))))
            draw_circle(pos2 + Vector2(-2.5, -2.5), 2.5, Color8(255, 239, 154, int(235.0 * (1.0 - p2))))
