extends Node3D

const GRID_SIZE := 11
const HALF := 5
const SAVE_PATH := "user://citycraft3d.json"
const COSTS := {
	"road": 200,
	"home": 1200,
	"shop": 2200,
	"park": 800
}

var money := 18000
var population_f := 12.0
var population := 12
var happiness := 62
var month := 1
var level := 1
var selected_tool := "road"
var camera_angle := PI / 4.0
var camera_zoom := 1.0

var cells: Dictionary = {}
var object_root: Node3D
var camera: Camera3D
var money_label: Label
var population_label: Label
var happiness_label: Label
var month_label: Label
var mission_label: Label
var help_label: Label
var toast_label: Label
var toast_timer: Timer
var simulation_timer: Timer
var tool_buttons: Dictionary = {}

func _ready() -> void:
	_build_world()
	_build_ui()
	if not _load_game(false):
		_seed_city()
		_save_game(false)
	_update_hud()
	_update_camera()

	simulation_timer = Timer.new()
	simulation_timer.wait_time = 5.5
	simulation_timer.autostart = true
	simulation_timer.timeout.connect(_monthly_tick)
	add_child(simulation_timer)

	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 1.8
	toast_timer.timeout.connect(func(): toast_label.visible = false)
	add_child(toast_timer)

	get_viewport().size_changed.connect(_on_viewport_resized)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fdcff")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dff8ff")
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	camera.current = true
	add_child(camera)

	var base := _box(Vector3(GRID_SIZE + 5, 0.45, GRID_SIZE + 5), Color("6ba45d"))
	base.position.y = -0.31
	add_child(base)

	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var c := Color("86c978") if (x + z) % 2 == 0 else Color("78bc6c")
			var tile := _box(Vector3(0.96, 0.08, 0.96), c)
			tile.position = Vector3(x - HALF, 0.0, z - HALF)
			add_child(tile)

	object_root = Node3D.new()
	object_root.name = "CityObjects"
	add_child(object_root)

	var scenery := [
		Vector2(-7.0, -6.2), Vector2(-6.3, -7.0), Vector2(-7.0, 6.1),
		Vector2(6.5, -7.0), Vector2(6.8, 6.3), Vector2(-5.8, 6.8),
		Vector2(0.0, 7.0), Vector2(7.0, -1.5)
	]
	for i in scenery.size():
		var tree := _make_tree(0.75 + float(i % 3) * 0.12)
		tree.position = Vector3(scenery[i].x, 0.0, scenery[i].y)
		add_child(tree)


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return node


func _make_tree(scale_factor := 1.0) -> Node3D:
	var root := Node3D.new()
	var trunk := _box(Vector3(0.12, 0.52, 0.12), Color("795338"))
	trunk.position.y = 0.28
	root.add_child(trunk)

	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.36 * scale_factor
	sphere.height = 0.72 * scale_factor
	crown.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3f9e5c")
	mat.roughness = 0.9
	crown.material_override = mat
	crown.position.y = 0.70
	root.add_child(crown)
	return root


func _make_road() -> Node3D:
	var root := Node3D.new()
	var slab := _box(Vector3(0.94, 0.11, 0.94), Color("65707d"))
	slab.position.y = 0.07
	root.add_child(slab)
	var line := _box(Vector3(0.06, 0.012, 0.50), Color("cbd5e1"))
	line.position.y = 0.132
	root.add_child(line)
	return root


func _make_home() -> Node3D:
	var root := Node3D.new()
	var foundation := _box(Vector3(0.76, 0.12, 0.76), Color("e6d1b2"))
	foundation.position.y = 0.08
	root.add_child(foundation)

	var body := _box(Vector3(0.66, 0.63, 0.62), Color("f5b971"))
	body.position.y = 0.44
	root.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 0.57
	roof_mesh.height = 0.42
	roof_mesh.radial_segments = 4
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color("c85d48")
	roof_mat.roughness = 0.85
	roof.material_override = roof_mat
	roof.rotation.y = PI / 4.0
	roof.position.y = 0.96
	root.add_child(roof)

	var door := _box(Vector3(0.16, 0.30, 0.03), Color("704d3a"))
	door.position = Vector3(0.0, 0.36, 0.326)
	root.add_child(door)

	for wx in [-0.20, 0.20]:
		var window := _box(Vector3(0.13, 0.13, 0.02), Color("dff5ff"))
		window.position = Vector3(wx, 0.57, 0.332)
		root.add_child(window)
	return root


func _make_shop() -> Node3D:
	var root := Node3D.new()
	var body := _box(Vector3(0.78, 0.72, 0.70), Color("44c5d4"))
	body.position.y = 0.40
	root.add_child(body)

	var roof := _box(Vector3(0.86, 0.08, 0.78), Color("effbfd"))
	roof.position.y = 0.81
	root.add_child(roof)

	var glass := _box(Vector3(0.55, 0.30, 0.02), Color("c9f5ff"))
	glass.position = Vector3(0.0, 0.43, 0.361)
	root.add_child(glass)

	var awning := _box(Vector3(0.62, 0.08, 0.16), Color("ffe082"))
	awning.position = Vector3(0.0, 0.66, 0.42)
	root.add_child(awning)
	return root


func _make_park() -> Node3D:
	var root := Node3D.new()
	var base := _box(Vector3(0.90, 0.08, 0.90), Color("55b962"))
	base.position.y = 0.06
	root.add_child(base)

	var path := _box(Vector3(0.18, 0.018, 0.88), Color("d7c39f"))
	path.position.y = 0.115
	root.add_child(path)

	var t1 := _make_tree(0.70)
	t1.scale = Vector3(0.78, 0.78, 0.78)
	t1.position = Vector3(-0.24, 0.08, -0.18)
	root.add_child(t1)

	var t2 := _make_tree(0.56)
	t2.scale = Vector3(0.70, 0.70, 0.70)
	t2.position = Vector3(0.25, 0.08, 0.20)
	root.add_child(t2)

	var bench := _box(Vector3(0.34, 0.09, 0.10), Color("8b5e3c"))
	bench.position = Vector3(0.24, 0.20, -0.28)
	root.add_child(bench)
	return root


func _make_city_hall() -> Node3D:
	var root := Node3D.new()
	var base := _box(Vector3(0.88, 0.14, 0.88), Color("cbd5e1"))
	base.position.y = 0.08
	root.add_child(base)

	var body := _box(Vector3(0.72, 0.72, 0.68), Color("f1f5f9"))
	body.position.y = 0.50
	root.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 0.58
	roof_mesh.height = 0.35
	roof_mesh.radial_segments = 4
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color("47627a")
	roof.material_override = roof_mat
	roof.rotation.y = PI / 4.0
	roof.position.y = 1.03
	root.add_child(roof)

	var door := _box(Vector3(0.18, 0.34, 0.03), Color("31506d"))
	door.position = Vector3(0.0, 0.42, 0.355)
	root.add_child(door)

	var pole := _box(Vector3(0.025, 0.60, 0.025), Color("e2e8f0"))
	pole.position = Vector3(0.26, 1.43, 0.0)
	root.add_child(pole)

	var flag := _box(Vector3(0.28, 0.16, 0.02), Color("22d3ee"))
	flag.position = Vector3(0.39, 1.62, 0.0)
	root.add_child(flag)
	return root


func _spawn(kind: String, cell: Vector2i) -> void:
	var node: Node3D
	match kind:
		"road": node = _make_road()
		"home": node = _make_home()
		"shop": node = _make_shop()
		"park": node = _make_park()
		"city": node = _make_city_hall()
		_: return

	node.position = Vector3(cell.x - HALF, 0.07, cell.y - HALF)
	node.name = kind + "_" + str(cell.x) + "_" + str(cell.y)
	object_root.add_child(node)
	cells[cell] = {
		"type": kind,
		"node": node,
		"cost": COSTS.get(kind, 0)
	}


func _clear_cell(cell: Vector2i) -> void:
	if not cells.has(cell):
		return
	var node: Node = cells[cell]["node"]
	node.queue_free()
	cells.erase(cell)


func _clear_city() -> void:
	for key in cells.keys():
		var node: Node = cells[key]["node"]
		node.queue_free()
	cells.clear()


func _seed_city() -> void:
	_clear_city()
	var c := Vector2i(HALF, HALF)
	_spawn("city", c)
	for road_cell in [
		Vector2i(HALF - 1, HALF), Vector2i(HALF + 1, HALF),
		Vector2i(HALF, HALF - 1), Vector2i(HALF, HALF + 1),
		Vector2i(HALF - 2, HALF), Vector2i(HALF + 2, HALF),
		Vector2i(HALF, HALF - 2)
	]:
		_spawn("road", road_cell)
	_spawn("home", Vector2i(HALF - 1, HALF - 1))
	_spawn("home", Vector2i(HALF + 1, HALF - 1))
	_spawn("shop", Vector2i(HALF + 1, HALF + 1))
	_spawn("park", Vector2i(HALF - 1, HALF + 1))

	money = 18000
	population_f = 12.0
	population = 12
	happiness = 62
	month = 1
	level = 1
	_set_tool("road")
	_evaluate()


func _road_network() -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = []
	var starts := [
		Vector2i(HALF - 1, HALF), Vector2i(HALF + 1, HALF),
		Vector2i(HALF, HALF - 1), Vector2i(HALF, HALF + 1)
	]
	for s in starts:
		if cells.has(s) and cells[s]["type"] == "road":
			seen[s] = true
			queue.push_back(s)

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next := current + d
			if next.x < 0 or next.y < 0 or next.x >= GRID_SIZE or next.y >= GRID_SIZE:
				continue
			if seen.has(next):
				continue
			if cells.has(next) and cells[next]["type"] == "road":
				seen[next] = true
				queue.push_back(next)
	return seen


func _connected_to_road(cell: Vector2i, network: Dictionary) -> bool:
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		if network.has(cell + d):
			return true
	return false


func _counts() -> Dictionary:
	var out := {
		"road": 0, "home": 0, "shop": 0, "park": 0, "city": 0,
		"connected_homes": 0, "connected_shops": 0
	}
	var network := _road_network()
	for key in cells.keys():
		var kind: String = cells[key]["type"]
		out[kind] += 1
		if kind == "home" and _connected_to_road(key, network):
			out["connected_homes"] += 1
		elif kind == "shop" and _connected_to_road(key, network):
			out["connected_shops"] += 1
	return out


func _park_influence() -> int:
	var score := 0
	for home_cell in cells.keys():
		if cells[home_cell]["type"] != "home":
			continue
		for park_cell in cells.keys():
			if cells[park_cell]["type"] != "park":
				continue
			var distance := abs(park_cell.x - home_cell.x) + abs(park_cell.y - home_cell.y)
			if distance <= 3:
				score += 1
				break
	return score


func _evaluate() -> void:
	var c := _counts()
	var max_population: int = c["connected_homes"] * 18

	if max_population == 0:
		population_f = max(0.0, population_f - 0.8)
	elif population_f < max_population:
		population_f = min(float(max_population), population_f + max(0.7, float(c["connected_homes"]) * 0.85))
	else:
		population_f = max(float(max_population), population_f - 0.5)

	population = roundi(population_f)
	var disconnected_homes: int = c["home"] - c["connected_homes"]
	var jobs: int = c["connected_shops"] * 28
	var job_penalty := max(0, population - jobs - 24) * 0.18
	var h := 58.0 + float(_park_influence()) * 3.5 + min(float(c["connected_shops"]) * 2.0, 10.0)
	h -= float(disconnected_homes) * 8.0
	h -= job_penalty
	if money < 0:
		h -= 12.0
	happiness = clampi(roundi(h), 10, 99)

	if population >= 120:
		level = 4
	elif population >= 70:
		level = 3
	elif population >= 30:
		level = 2
	else:
		level = 1

	_update_hud()


func _monthly_tick() -> void:
	var c := _counts()
	var income := roundi(float(population) * 16.0 + float(c["connected_shops"]) * 190.0)
	var upkeep: int = c["road"] * 9 + c["home"] * 18 + c["shop"] * 32 + c["park"] * 28 + 55
	money += income - upkeep
	month += 1
	_evaluate()
	_save_game(false)

	if money < 0:
		_toast("資金が赤字です。商業施設を道路につなげましょう。")
	elif month % 4 == 0:
		_toast("月次収支 %+d円" % (income - upkeep))


func _place(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE or cell.y >= GRID_SIZE:
		return

	if selected_tool == "bulldoze":
		if not cells.has(cell) or cells[cell]["type"] == "city":
			_toast("ここは撤去できません")
			return
		var refund := roundi(float(cells[cell]["cost"]) * 0.25)
		_clear_cell(cell)
		money += refund
		_toast("撤去しました +%d円" % refund)
		_evaluate()
		_save_game(false)
		return

	if cells.has(cell):
		_toast("空いている土地を選んでください")
		return

	var cost: int = COSTS[selected_tool]
	if money < cost:
		_toast("資金が足りません")
		return

	money -= cost
	_spawn(selected_tool, cell)
	_evaluate()
	_save_game(false)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 12
	top_panel.offset_top = 10
	top_panel.offset_right = -12
	top_panel.offset_bottom = 74
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.09, 0.16, 0.90), 16))
	layer.add_child(top_panel)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top_panel.add_child(top)

	var title := Label.new()
	title.text = "  CITYCRAFT 3D"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("f8fafc"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	money_label = _stat_label()
	population_label = _stat_label()
	happiness_label = _stat_label()
	month_label = _stat_label()
	top.add_child(money_label)
	top.add_child(population_label)
	top.add_child(happiness_label)
	top.add_child(month_label)

	var mission_panel := PanelContainer.new()
	mission_panel.position = Vector2(12, 86)
	mission_panel.size = Vector2(260, 108)
	mission_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.09, 0.16, 0.88), 16))
	layer.add_child(mission_panel)
	mission_label = Label.new()
	mission_label.text = "市長ミッション"
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.add_theme_font_size_override("font_size", 14)
	mission_label.add_theme_color_override("font_color", Color("dbeafe"))
	mission_panel.add_child(mission_label)

	var camera_panel := HBoxContainer.new()
	camera_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	camera_panel.position = Vector2(-194, 86)
	camera_panel.size = Vector2(182, 44)
	layer.add_child(camera_panel)
	for spec in [
		["↶", Callable(self, "_rotate_left")],
		["＋", Callable(self, "_zoom_in")],
		["−", Callable(self, "_zoom_out")],
		["↷", Callable(self, "_rotate_right")]
	]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(42, 42)
		b.pressed.connect(spec[1])
		camera_panel.add_child(b)

	help_label = Label.new()
	help_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help_label.position = Vector2(-270, -108)
	help_label.size = Vector2(540, 40)
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help_label.add_theme_color_override("font_color", Color("e0f2fe"))
	help_label.add_theme_font_size_override("font_size", 13)
	layer.add_child(help_label)

	var dock_panel := PanelContainer.new()
	dock_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock_panel.position = Vector2(-385, -82)
	dock_panel.size = Vector2(770, 72)
	dock_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.09, 0.16, 0.94), 18))
	layer.add_child(dock_panel)

	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 6)
	dock_panel.add_child(dock)

	var tools := [
		["road", "道路\n¥200"],
		["home", "住宅\n¥1,200"],
		["shop", "商業\n¥2,200"],
		["park", "公園\n¥800"],
		["bulldoze", "撤去\n25%還元"]
	]
	for spec in tools:
		var button := Button.new()
		button.text = spec[1]
		button.custom_minimum_size = Vector2(120, 58)
		button.toggle_mode = true
		button.pressed.connect(_set_tool.bind(spec[0]))
		dock.add_child(button)
		tool_buttons[spec[0]] = button

	var save_button := Button.new()
	save_button.text = "保存"
	save_button.custom_minimum_size = Vector2(74, 58)
	save_button.pressed.connect(func(): _save_game(true))
	dock.add_child(save_button)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-190, 84)
	toast_label.size = Vector2(380, 44)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_stylebox_override("normal", _panel_style(Color(0.06, 0.09, 0.16, 0.92), 14))
	toast_label.visible = false
	layer.add_child(toast_label)

	_set_tool(selected_tool)


func _stat_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(105, 42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("f8fafc"))
	return label


func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _set_tool(tool: String) -> void:
	selected_tool = tool
	for key in tool_buttons.keys():
		var b: Button = tool_buttons[key]
		b.button_pressed = key == tool

	var help := {
		"road": "道路：市役所から道路を伸ばして街をつなげよう",
		"home": "住宅：道路沿いに建てると人口が増える",
		"shop": "商業：道路接続で毎月の収入が増える",
		"park": "公園：近くの住宅の満足度が上がる",
		"bulldoze": "撤去：建設費の25%が戻る"
	}
	if help_label:
		help_label.text = help.get(tool, "")


func _update_hud() -> void:
	if not money_label:
		return
	money_label.text = "資金\n%s¥%s" % ["-" if money < 0 else "", _comma(abs(money))]
	population_label.text = "人口\n%s人" % _comma(population)
	happiness_label.text = "満足度\n%d%%" % happiness
	month_label.text = "月\n%d" % month

	var c := _counts()
	var d1 := population >= 60
	var d2 := c["shop"] >= 2
	var d3 := happiness >= 75
	mission_label.text = "市長ミッション　Lv.%d\n%s 人口60人\n%s 商業施設2軒\n%s 満足度75%%" % [
		level,
		"●" if d1 else "○",
		"●" if d2 else "○",
		"●" if d3 else "○"
	]


func _comma(value: int) -> String:
	var s := str(value)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _toast(text: String) -> void:
	if not toast_label:
		return
	toast_label.text = text
	toast_label.visible = true
	if toast_timer:
		toast_timer.start()


func _rotate_left() -> void:
	camera_angle -= PI / 2.0
	_update_camera()


func _rotate_right() -> void:
	camera_angle += PI / 2.0
	_update_camera()


func _zoom_in() -> void:
	camera_zoom = min(1.55, camera_zoom + 0.15)
	_update_camera()


func _zoom_out() -> void:
	camera_zoom = max(0.70, camera_zoom - 0.15)
	_update_camera()


func _update_camera() -> void:
	if not camera:
		return
	var r := 13.5
	camera.position = Vector3(cos(camera_angle) * r, 11.5, sin(camera_angle) * r)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / max(viewport_size.y, 1.0)
	var portrait_boost := 1.25 if aspect < 0.85 else 1.0
	camera.size = 14.0 * portrait_boost / camera_zoom


func _on_viewport_resized() -> void:
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true

	if not pressed:
		return

	var origin := camera.project_ray_origin(pos)
	var direction := camera.project_ray_normal(pos)
	var ground := Plane(Vector3.UP, 0.0)
	var hit = ground.intersects_ray(origin, direction)
	if hit == null:
		return

	var world_pos: Vector3 = hit
	var cell := Vector2i(roundi(world_pos.x) + HALF, roundi(world_pos.z) + HALF)
	_place(cell)


func _save_game(show_message := true) -> void:
	var data := {
		"money": money,
		"population_f": population_f,
		"population": population,
		"happiness": happiness,
		"month": month,
		"level": level,
		"selected_tool": selected_tool,
		"cells": []
	}
	for key in cells.keys():
		data["cells"].append({
			"x": key.x,
			"y": key.y,
			"type": cells[key]["type"]
		})

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		if show_message:
			_toast("街を保存しました")


func _load_game(show_message := true) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	_clear_city()
	money = int(parsed.get("money", 18000))
	population_f = float(parsed.get("population_f", 12.0))
	population = int(parsed.get("population", roundi(population_f)))
	happiness = int(parsed.get("happiness", 62))
	month = int(parsed.get("month", 1))
	level = int(parsed.get("level", 1))
	selected_tool = str(parsed.get("selected_tool", "road"))

	for item in parsed.get("cells", []):
		_spawn(str(item["type"]), Vector2i(int(item["x"]), int(item["y"])))

	_set_tool(selected_tool)
	_evaluate()
	if show_message:
		_toast("保存データを読み込みました")
	return true
