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
var ui_theme: Theme
var top_panel: PanelContainer
var title_label: Label
var mission_panel: PanelContainer
var camera_panel: VBoxContainer
var camera_buttons: Array[Button] = []
var help_panel: PanelContainer
var dock_panel: PanelContainer
var dock_container: HBoxContainer
var menu_button: Button
var menu_panel: PanelContainer
var save_button: Button
var selection_marker: MeshInstance3D
var last_selection_cell := Vector2i(-1, -1)
var start_overlay: ColorRect
var start_card: PanelContainer
var start_button: Button
var start_subtitle: Label
var tutorial_panel: PanelContainer
var tutorial_label: Label
var tutorial_button: Button
var tutorial_step := 0
var tutorial_done := false
var fresh_game := false
var mission_complete_panel: PanelContainer
var mission_complete_title: Label
var mission_complete_text: Label
var mission_stage := 1

func _ready() -> void:
	_build_world()
	_build_ui()

	var loaded_existing := _load_game(false)
	if not loaded_existing:
		fresh_game = true
		_seed_city()
		_save_game(false)

	_update_hud()
	_update_camera()

	simulation_timer = Timer.new()
	simulation_timer.wait_time = 5.5
	simulation_timer.autostart = false
	simulation_timer.timeout.connect(_monthly_tick)
	add_child(simulation_timer)

	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 1.8
	toast_timer.timeout.connect(func(): toast_label.visible = false)
	add_child(toast_timer)

	_show_start_screen(loaded_existing)
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

	selection_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.96, 0.035, 0.96)
	selection_marker.mesh = marker_mesh
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(0.13, 0.83, 0.93, 0.44)
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_marker.material_override = marker_mat
	selection_marker.position.y = 0.15
	selection_marker.visible = false
	add_child(selection_marker)

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
			var next: Vector2i = current + d
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
			var distance: int = abs(park_cell.x - home_cell.x) + abs(park_cell.y - home_cell.y)
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
	var job_penalty: float = float(max(0, population - jobs - 24)) * 0.18
	var h: float = 58.0 + float(_park_influence()) * 3.5 + min(float(c["connected_shops"]) * 2.0, 10.0)
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

	_check_mission_completion(c)
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
			_flash_failure(cell)
			_toast("ここは撤去できません")
			return
		var refund: int = roundi(float(cells[cell]["cost"]) * 0.25)
		_show_floating_amount(cell, "+¥%s" % _comma(refund), Color("86efac"))
		_clear_cell(cell)
		money += refund
		_flash_success(cell, Color("fb7185"))
		_toast("撤去しました　+¥%s" % _comma(refund))
		_evaluate()
		_save_game(false)
		return

	if cells.has(cell):
		_flash_failure(cell)
		_toast("そのマスには建設できません")
		return

	var cost: int = int(COSTS[selected_tool])
	if money < cost:
		_flash_failure(cell)
		_toast("資金が足りません")
		return

	money -= cost
	_spawn(selected_tool, cell)

	var built_node: Node3D = cells[cell]["node"] as Node3D
	_animate_build(built_node)
	_show_floating_amount(cell, "-¥%s" % _comma(cost), Color("fde68a"))
	_flash_success(cell, Color("34d399"))

	_evaluate()
	_save_game(false)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	ui_theme = Theme.new()
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		ui_theme.default_font = load("res://fonts/NotoSansJP.ttf") as Font
	ui_theme.default_font_size = 20

	# Header: title + menu on the first row, four large status cards on the second.
	top_panel = PanelContainer.new()
	top_panel.theme = ui_theme
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.13, 0.97), 22))
	layer.add_child(top_panel)

	var top_root := VBoxContainer.new()
	top_root.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_root)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	top_root.add_child(title_row)

	title_label = Label.new()
	title_label.text = "CITYCRAFT 3D"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 30)
	title_row.add_child(title_label)

	menu_button = Button.new()
	menu_button.text = "メニュー"
	menu_button.pressed.connect(_toggle_menu)
	menu_button.add_theme_stylebox_override("normal", _menu_button_style(false))
	menu_button.add_theme_stylebox_override("hover", _menu_button_style(true))
	menu_button.add_theme_stylebox_override("pressed", _menu_button_style(true))
	title_row.add_child(menu_button)

	var stats_row := GridContainer.new()
	stats_row.columns = 4
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_theme_constant_override("h_separation", 10)
	top_root.add_child(stats_row)

	money_label = _stat_label()
	population_label = _stat_label()
	happiness_label = _stat_label()
	month_label = _stat_label()
	stats_row.add_child(_stat_card(money_label, Color("fbbf24")))
	stats_row.add_child(_stat_card(population_label, Color("38bdf8")))
	stats_row.add_child(_stat_card(happiness_label, Color("34d399")))
	stats_row.add_child(_stat_card(month_label, Color("a78bfa")))

	# Compact progress card. It no longer occupies a large block of the playfield.
	mission_panel = PanelContainer.new()
	mission_panel.theme = ui_theme
	mission_panel.add_theme_stylebox_override("panel", _accent_panel_style(Color("22d3ee")))
	layer.add_child(mission_panel)

	mission_label = Label.new()
	mission_label.text = "次の目標"
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.add_theme_color_override("font_color", Color.WHITE)
	mission_label.add_theme_font_size_override("font_size", 22)
	mission_panel.add_child(mission_label)

	# Camera controls are kept away from the building bar.
	camera_panel = VBoxContainer.new()
	camera_panel.theme = ui_theme
	camera_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	camera_panel.add_theme_constant_override("separation", 8)
	layer.add_child(camera_panel)
	for spec in [
		["↶", Callable(self, "_rotate_left")],
		["＋", Callable(self, "_zoom_in")],
		["－", Callable(self, "_zoom_out")],
		["↷", Callable(self, "_rotate_right")]
	]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		b.add_theme_font_size_override("font_size", 28)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_stylebox_override("normal", _camera_button_style(false))
		b.add_theme_stylebox_override("hover", _camera_button_style(true))
		b.add_theme_stylebox_override("pressed", _camera_button_style(true))
		camera_panel.add_child(b)
		camera_buttons.append(b)

	# Current action guide.
	help_panel = PanelContainer.new()
	help_panel.theme = ui_theme
	help_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help_panel.add_theme_stylebox_override("panel", _accent_panel_style(Color("0ea5e9")))
	layer.add_child(help_panel)

	help_label = Label.new()
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help_label.add_theme_color_override("font_color", Color.WHITE)
	help_label.add_theme_font_size_override("font_size", 22)
	help_panel.add_child(help_label)

	# Bottom action bar: building tools only.
	dock_panel = PanelContainer.new()
	dock_panel.theme = ui_theme
	dock_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.13, 0.98), 24))
	layer.add_child(dock_panel)

	dock_container = HBoxContainer.new()
	dock_container.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_container.add_theme_constant_override("separation", 10)
	dock_panel.add_child(dock_container)

	var tools := [
		["road", "道路\n¥200", Color("64748b")],
		["home", "住宅\n¥1,200", Color("f59e0b")],
		["shop", "商業\n¥2,200", Color("0ea5e9")],
		["park", "公園\n¥800", Color("22c55e")],
		["bulldoze", "撤去\n25%還元", Color("ef4444")]
	]
	for spec in tools:
		var button := Button.new()
		button.text = spec[1]
		button.toggle_mode = true
		button.set_meta("tool_color", spec[2])
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.pressed.connect(_set_tool.bind(spec[0]))
		dock_container.add_child(button)
		tool_buttons[spec[0]] = button

	# Save/load/new-game are moved into a menu so the action bar stays focused.
	menu_panel = PanelContainer.new()
	menu_panel.theme = ui_theme
	menu_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.13, 0.99), 20))
	menu_panel.visible = false
	layer.add_child(menu_panel)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	menu_panel.add_child(menu_box)

	var menu_title := Label.new()
	menu_title.text = "ゲームメニュー"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 26)
	menu_title.add_theme_color_override("font_color", Color.WHITE)
	menu_box.add_child(menu_title)

	save_button = Button.new()
	save_button.text = "保存する"
	save_button.pressed.connect(func():
		_save_game(true)
		menu_panel.visible = false
	)
	menu_box.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "保存を読み込む"
	load_button.pressed.connect(func():
		_load_game(true)
		menu_panel.visible = false
	)
	menu_box.add_child(load_button)

	var new_button := Button.new()
	new_button.text = "最初から始める"
	new_button.pressed.connect(_new_game)
	menu_box.add_child(new_button)

	for menu_item in [save_button, load_button, new_button]:
		menu_item.custom_minimum_size = Vector2(300, 62)
		menu_item.add_theme_font_size_override("font_size", 22)
		menu_item.add_theme_color_override("font_color", Color.WHITE)
		menu_item.add_theme_stylebox_override("normal", _menu_action_style(false))
		menu_item.add_theme_stylebox_override("hover", _menu_action_style(true))
		menu_item.add_theme_stylebox_override("pressed", _menu_action_style(true))

	toast_label = Label.new()
	toast_label.theme = ui_theme
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_stylebox_override("normal", _accent_panel_style(Color("0ea5e9")))
	toast_label.visible = false
	layer.add_child(toast_label)

	# First-view title/start overlay.
	start_overlay = ColorRect.new()
	start_overlay.theme = ui_theme
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.color = Color(0.01, 0.03, 0.06, 0.82)
	layer.add_child(start_overlay)

	start_card = PanelContainer.new()
	start_card.theme = ui_theme
	start_card.set_anchors_preset(Control.PRESET_CENTER, false)
	start_card.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.13, 0.99), 28))
	start_overlay.add_child(start_card)

	var start_box := VBoxContainer.new()
	start_box.alignment = BoxContainer.ALIGNMENT_CENTER
	start_box.add_theme_constant_override("separation", 18)
	start_card.add_child(start_box)

	var start_title := Label.new()
	start_title.text = "CITYCRAFT 3D"
	start_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_title.add_theme_font_size_override("font_size", 46)
	start_title.add_theme_color_override("font_color", Color.WHITE)
	start_box.add_child(start_title)

	start_subtitle = Label.new()
	start_subtitle.text = "道路をつなぎ、住宅・商業・公園を配置して\n住みやすい街を育てよう"
	start_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_subtitle.add_theme_font_size_override("font_size", 26)
	start_subtitle.add_theme_color_override("font_color", Color("dbeafe"))
	start_box.add_child(start_subtitle)

	var goal_label := Label.new()
	goal_label.text = "最初の目標：人口60人・商業2軒・満足度75%"
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.add_theme_font_size_override("font_size", 24)
	goal_label.add_theme_color_override("font_color", Color("67e8f9"))
	start_box.add_child(goal_label)

	start_button = Button.new()
	start_button.text = "街づくりを始める"
	start_button.custom_minimum_size = Vector2(520, 86)
	start_button.add_theme_font_size_override("font_size", 30)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_stylebox_override("normal", _menu_button_style(false))
	start_button.add_theme_stylebox_override("hover", _menu_button_style(true))
	start_button.add_theme_stylebox_override("pressed", _menu_button_style(true))
	start_button.pressed.connect(_begin_play_session)
	start_box.add_child(start_button)

	# Short first-run tutorial.
	tutorial_panel = PanelContainer.new()
	tutorial_panel.theme = ui_theme
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER, false)
	tutorial_panel.add_theme_stylebox_override("panel", _accent_panel_style(Color("22d3ee")))
	tutorial_panel.visible = false
	layer.add_child(tutorial_panel)

	var tutorial_box := VBoxContainer.new()
	tutorial_box.add_theme_constant_override("separation", 16)
	tutorial_panel.add_child(tutorial_box)

	tutorial_label = Label.new()
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.add_theme_font_size_override("font_size", 30)
	tutorial_label.add_theme_color_override("font_color", Color.WHITE)
	tutorial_box.add_child(tutorial_label)

	tutorial_button = Button.new()
	tutorial_button.text = "次へ"
	tutorial_button.custom_minimum_size = Vector2(300, 72)
	tutorial_button.add_theme_font_size_override("font_size", 26)
	tutorial_button.add_theme_color_override("font_color", Color.WHITE)
	tutorial_button.add_theme_stylebox_override("normal", _menu_button_style(false))
	tutorial_button.add_theme_stylebox_override("hover", _menu_button_style(true))
	tutorial_button.add_theme_stylebox_override("pressed", _menu_button_style(true))
	tutorial_button.pressed.connect(_tutorial_next)
	tutorial_box.add_child(tutorial_button)

	# Mission-complete celebration.
	mission_complete_panel = PanelContainer.new()
	mission_complete_panel.theme = ui_theme
	mission_complete_panel.set_anchors_preset(Control.PRESET_CENTER, false)
	mission_complete_panel.add_theme_stylebox_override("panel", _accent_panel_style(Color("fbbf24")))
	mission_complete_panel.visible = false
	layer.add_child(mission_complete_panel)

	var clear_box := VBoxContainer.new()
	clear_box.add_theme_constant_override("separation", 16)
	mission_complete_panel.add_child(clear_box)

	mission_complete_title = Label.new()
	mission_complete_title.text = "市長ミッション達成！"
	mission_complete_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_complete_title.add_theme_font_size_override("font_size", 40)
	mission_complete_title.add_theme_color_override("font_color", Color("fde68a"))
	clear_box.add_child(mission_complete_title)

	mission_complete_text = Label.new()
	mission_complete_text.text = ""
	mission_complete_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_complete_text.add_theme_font_size_override("font_size", 28)
	mission_complete_text.add_theme_color_override("font_color", Color.WHITE)
	clear_box.add_child(mission_complete_text)

	var clear_button := Button.new()
	clear_button.text = "街づくりを続ける"
	clear_button.custom_minimum_size = Vector2(420, 76)
	clear_button.add_theme_font_size_override("font_size", 26)
	clear_button.add_theme_color_override("font_color", Color.WHITE)
	clear_button.add_theme_stylebox_override("normal", _menu_button_style(false))
	clear_button.add_theme_stylebox_override("hover", _menu_button_style(true))
	clear_button.add_theme_stylebox_override("pressed", _menu_button_style(true))
	clear_button.pressed.connect(func(): mission_complete_panel.visible = false)
	clear_box.add_child(clear_button)

	_apply_ui_layout()
	_set_tool(selected_tool)

func _stat_label() -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

func _stat_card(label: Label, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _status_card_style(accent))
	card.add_child(label)
	return card

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
	style.border_color = Color(1, 1, 1, 0.12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _status_card_style(accent: Color) -> StyleBoxFlat:
	var style := _panel_style(Color(0.06, 0.12, 0.20, 0.98), 16)
	style.border_width_left = 4
	style.border_color = accent
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _accent_panel_style(accent: Color) -> StyleBoxFlat:
	var style := _panel_style(Color(0.035, 0.075, 0.13, 0.94), 18)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = accent
	return style

func _tool_button_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.18 if selected else 0.34)
	var radius := 18
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	var width := 5 if selected else 2
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = Color("67e8f9") if selected else color.lightened(0.18)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _camera_button_style(active: bool) -> StyleBoxFlat:
	var style := _panel_style(Color(0.05, 0.11, 0.19, 0.98), 18)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("67e8f9") if active else Color("334155")
	return style

func _menu_button_style(active: bool) -> StyleBoxFlat:
	var style := _panel_style(Color("0e7490") if active else Color("155e75"), 16)
	style.border_color = Color("67e8f9")
	return style

func _menu_action_style(active: bool) -> StyleBoxFlat:
	var style := _panel_style(Color("155e75") if active else Color("0f3345"), 14)
	style.border_color = Color("2dd4bf")
	return style

func _apply_ui_layout() -> void:
	if ui_theme == null or top_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var portrait: bool = viewport_size.y > viewport_size.x * 1.20

	if portrait:
		start_card.offset_left = -580
		start_card.offset_right = 580
		start_card.offset_top = -320
		start_card.offset_bottom = 320
		tutorial_panel.offset_left = -560
		tutorial_panel.offset_right = 560
		tutorial_panel.offset_top = -250
		tutorial_panel.offset_bottom = 250
		mission_complete_panel.offset_left = -540
		mission_complete_panel.offset_right = 540
		mission_complete_panel.offset_top = -240
		mission_complete_panel.offset_bottom = 240

		ui_theme.default_font_size = 30
		title_label.add_theme_font_size_override("font_size", 42)
		for label in [money_label, population_label, happiness_label, month_label]:
			label.add_theme_font_size_override("font_size", 34)
		mission_label.add_theme_font_size_override("font_size", 30)
		help_label.add_theme_font_size_override("font_size", 30)
		toast_label.add_theme_font_size_override("font_size", 28)

		top_panel.offset_left = 12
		top_panel.offset_top = 12
		top_panel.offset_right = -12
		top_panel.offset_bottom = 224
		menu_button.custom_minimum_size = Vector2(190, 64)
		menu_button.add_theme_font_size_override("font_size", 28)

		mission_panel.set_anchors_preset(Control.PRESET_CENTER_TOP, false)
		mission_panel.offset_left = -570
		mission_panel.offset_right = 570
		mission_panel.offset_top = 238
		mission_panel.offset_bottom = 390

		camera_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
		camera_panel.offset_left = -90
		camera_panel.offset_right = -16
		camera_panel.offset_top = 370
		camera_panel.offset_bottom = 730
		for button in camera_buttons:
			button.custom_minimum_size = Vector2(72, 72)
			button.add_theme_font_size_override("font_size", 36)

		help_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
		help_panel.offset_left = -560
		help_panel.offset_right = 560
		help_panel.offset_top = -304
		help_panel.offset_bottom = -220

		dock_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
		dock_panel.offset_left = -620
		dock_panel.offset_right = 620
		dock_panel.offset_top = -204
		dock_panel.offset_bottom = -16
		for key in tool_buttons.keys():
			var tool_button: Button = tool_buttons[key]
			tool_button.custom_minimum_size = Vector2(232, 146)
			tool_button.add_theme_font_size_override("font_size", 34)

		menu_panel.offset_left = -500
		menu_panel.offset_right = -16
		menu_panel.offset_top = 104
		menu_panel.offset_bottom = 500
		for menu_item in menu_panel.find_children("*", "Button", true, false):
			var button := menu_item as Button
			button.custom_minimum_size = Vector2(410, 82)
			button.add_theme_font_size_override("font_size", 30)

		toast_label.offset_left = -390
		toast_label.offset_right = 390
		toast_label.offset_top = 366
		toast_label.offset_bottom = 446
	else:
		start_card.offset_left = -470
		start_card.offset_right = 470
		start_card.offset_top = -270
		start_card.offset_bottom = 270
		tutorial_panel.offset_left = -460
		tutorial_panel.offset_right = 460
		tutorial_panel.offset_top = -210
		tutorial_panel.offset_bottom = 210
		mission_complete_panel.offset_left = -440
		mission_complete_panel.offset_right = 440
		mission_complete_panel.offset_top = -200
		mission_complete_panel.offset_bottom = 200

		ui_theme.default_font_size = 20
		title_label.add_theme_font_size_override("font_size", 30)
		for label in [money_label, population_label, happiness_label, month_label]:
			label.add_theme_font_size_override("font_size", 22)
		mission_label.add_theme_font_size_override("font_size", 20)
		help_label.add_theme_font_size_override("font_size", 20)
		toast_label.add_theme_font_size_override("font_size", 20)

		top_panel.offset_left = 16
		top_panel.offset_top = 14
		top_panel.offset_right = -16
		top_panel.offset_bottom = 144
		menu_button.custom_minimum_size = Vector2(130, 48)
		menu_button.add_theme_font_size_override("font_size", 20)

		mission_panel.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		mission_panel.offset_left = 16
		mission_panel.offset_right = 430
		mission_panel.offset_top = 158
		mission_panel.offset_bottom = 284

		camera_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
		camera_panel.offset_left = -76
		camera_panel.offset_right = -16
		camera_panel.offset_top = 160
		camera_panel.offset_bottom = 430
		for button in camera_buttons:
			button.custom_minimum_size = Vector2(58, 58)
			button.add_theme_font_size_override("font_size", 28)

		help_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
		help_panel.offset_left = -390
		help_panel.offset_right = 390
		help_panel.offset_top = -206
		help_panel.offset_bottom = -148

		dock_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
		dock_panel.offset_left = -530
		dock_panel.offset_right = 530
		dock_panel.offset_top = -136
		dock_panel.offset_bottom = -14
		for key in tool_buttons.keys():
			var tool_button: Button = tool_buttons[key]
			tool_button.custom_minimum_size = Vector2(192, 96)
			tool_button.add_theme_font_size_override("font_size", 24)

		menu_panel.offset_left = -370
		menu_panel.offset_right = -16
		menu_panel.offset_top = 82
		menu_panel.offset_bottom = 390

		toast_label.offset_left = -280
		toast_label.offset_right = 280
		toast_label.offset_top = 158
		toast_label.offset_bottom = 214

func _set_tool(tool: String) -> void:
	selected_tool = tool
	for key in tool_buttons.keys():
		var b: Button = tool_buttons[key]
		var active: bool = key == tool
		b.button_pressed = active
		var color: Color = b.get_meta("tool_color", Color("64748b"))
		b.add_theme_stylebox_override("normal", _tool_button_style(color, active))
		b.add_theme_stylebox_override("hover", _tool_button_style(color, true))
		b.add_theme_stylebox_override("pressed", _tool_button_style(color, true))
		b.add_theme_stylebox_override("focus", _tool_button_style(color, active))

	var help := {
		"road": "道路を選択中　空いているマスをタップして道路をつなげます",
		"home": "住宅を選択中　道路沿いに建てると人口が増えます",
		"shop": "商業を選択中　道路につなぐと毎月の収入が増えます",
		"park": "公園を選択中　周辺住宅の満足度を上げます",
		"bulldoze": "撤去を選択中　撤去したい建物や道路をタップします"
	}
	if help_label:
		help_label.text = help.get(tool, "")

	if last_selection_cell.x >= 0:
		_show_selection(last_selection_cell)

func _update_hud() -> void:
	if not money_label:
		return

	money_label.text = "資金\n%s¥%s" % ["-" if money < 0 else "", _comma(abs(money))]
	population_label.text = "人口\n%s人" % _comma(population)
	happiness_label.text = "満足度\n%d%%" % happiness
	month_label.text = "月\n%d" % month

	var c := _counts()
	if mission_stage <= 3:
		var cfg: Dictionary = _mission_config(mission_stage)
		var pop_target: int = int(cfg["population"])
		var shop_target: int = int(cfg["shops"])
		var park_target: int = int(cfg["parks"])
		var happy_target: int = int(cfg["happiness"])
		var reward: int = int(cfg["reward"])

		mission_label.text = "市長ミッション %d/3「%s」　報酬 ¥%s\n人口 %d/%d　商業 %d/%d\n公園 %d/%d　満足度 %d/%d" % [
			mission_stage,
			str(cfg["name"]),
			_comma(reward),
			population,
			pop_target,
			int(c["shop"]),
			shop_target,
			int(c["park"]),
			park_target,
			happiness,
			happy_target
		]
	else:
		mission_label.text = "全ミッション達成！　自由都市モード\n人口 %d人　商業 %d軒\n公園 %dか所　満足度 %d%%" % [
			population,
			int(c["shop"]),
			int(c["park"]),
			happiness
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


func _show_start_screen(has_save: bool) -> void:
	if start_overlay == null:
		return
	start_overlay.visible = true
	start_button.text = "つづきから" if has_save else "街づくりを始める"
	start_subtitle.text = "保存した街のつづきから始めます" if has_save else "道路をつなぎ、住宅・商業・公園を配置して\n住みやすい街を育てよう"

func _begin_play_session() -> void:
	if start_overlay:
		start_overlay.visible = false
	if simulation_timer and simulation_timer.is_stopped():
		simulation_timer.start()
	if not tutorial_done:
		tutorial_step = 0
		_show_tutorial_step()

func _show_tutorial_step() -> void:
	if tutorial_panel == null:
		return
	tutorial_panel.visible = true
	match tutorial_step:
		0:
			tutorial_label.text = "1 / 3　道路を伸ばそう\n下の「道路」を選び、空いているマスをタップします。\n市役所から道路がつながることが街の基本です。"
			tutorial_button.text = "次へ"
			_set_tool("road")
		1:
			tutorial_label.text = "2 / 3　住宅を建てよう\n「住宅」を選び、道路の隣に建てます。\n道路につながった住宅には住民が増えていきます。"
			tutorial_button.text = "次へ"
			_set_tool("home")
		2:
			tutorial_label.text = "3 / 3　収入と満足度を伸ばそう\n商業は収入、公園は満足度を高めます。\n最初の市長ミッション達成を目指しましょう。"
			tutorial_button.text = "遊び始める"
			_set_tool("shop")

func _tutorial_next() -> void:
	tutorial_step += 1
	if tutorial_step >= 3:
		tutorial_done = true
		tutorial_panel.visible = false
		_set_tool("road")
		_save_game(false)
		_toast("チュートリアル完了　まずは人口60人を目指そう")
		return
	_show_tutorial_step()

func _mission_config(stage: int) -> Dictionary:
	match stage:
		1:
			return {
				"population": 60,
				"shops": 2,
				"parks": 1,
				"happiness": 75,
				"reward": 5000,
				"name": "小さな街"
			}
		2:
			return {
				"population": 100,
				"shops": 4,
				"parks": 3,
				"happiness": 80,
				"reward": 8000,
				"name": "にぎわう街"
			}
		3:
			return {
				"population": 150,
				"shops": 5,
				"parks": 5,
				"happiness": 85,
				"reward": 12000,
				"name": "住みたい都市"
			}
		_:
			return {}


func _check_mission_completion(count_data: Dictionary) -> void:
	if mission_stage > 3:
		return

	var cfg: Dictionary = _mission_config(mission_stage)
	if cfg.is_empty():
		return

	var complete: bool = (
		population >= int(cfg["population"])
		and int(count_data["shop"]) >= int(cfg["shops"])
		and int(count_data["park"]) >= int(cfg["parks"])
		and happiness >= int(cfg["happiness"])
	)
	if not complete:
		return

	var completed_stage: int = mission_stage
	var reward: int = int(cfg["reward"])
	money += reward
	mission_stage += 1

	if mission_complete_title:
		mission_complete_title.text = "市長ミッション Lv.%d 達成！" % completed_stage
	if mission_complete_text:
		if mission_stage <= 3:
			var next_cfg: Dictionary = _mission_config(mission_stage)
			mission_complete_text.text = "%s を達成しました。\n報酬 ¥%s を獲得！\n次は「%s」を目指そう。" % [
				str(cfg["name"]),
				_comma(reward),
				str(next_cfg["name"])
			]
		else:
			mission_complete_text.text = "%s を達成しました。\n報酬 ¥%s を獲得！\n全3段階クリア。ここからは自由都市モードです。" % [
				str(cfg["name"]),
				_comma(reward)
			]

	if mission_complete_panel:
		mission_complete_panel.visible = true

	_update_hud()
	_save_game(false)

func _animate_build(node: Node3D) -> void:
	if node == null:
		return
	var final_position: Vector3 = node.position
	node.position = final_position + Vector3(0.0, -0.22, 0.0)
	node.scale = Vector3(0.18, 0.18, 0.18)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, 0.34)
	tween.parallel().tween_property(node, "position", final_position, 0.28)


func _show_floating_amount(cell: Vector2i, amount_text: String, amount_color: Color) -> void:
	var label := Label3D.new()
	label.text = amount_text
	label.font_size = 42
	label.outline_size = 10
	label.modulate = amount_color
	label.outline_modulate = Color(0.02, 0.04, 0.07, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0045
	if ResourceLoader.exists("res://fonts/NotoSansJP.ttf"):
		label.font = load("res://fonts/NotoSansJP.ttf") as Font
	label.position = Vector3(cell.x - HALF, 1.15, cell.y - HALF)
	add_child(label)

	var end_position: Vector3 = label.position + Vector3(0.0, 0.95, 0.0)
	var end_color: Color = amount_color
	end_color.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", end_position, 0.90).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", end_color, 0.90)
	tween.chain().tween_callback(label.queue_free)


func _flash_success(cell: Vector2i, flash_color: Color = Color("34d399")) -> void:
	if selection_marker == null:
		return
	selection_marker.visible = true
	selection_marker.position = Vector3(cell.x - HALF, 0.16, cell.y - HALF)
	selection_marker.scale = Vector3(1.28, 1.0, 1.28)

	var marker_mat := selection_marker.material_override as StandardMaterial3D
	if marker_mat:
		var c: Color = flash_color
		c.a = 0.64
		marker_mat.albedo_color = c

	var tween: Tween = create_tween()
	tween.tween_property(selection_marker, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.18)
	tween.tween_callback(func():
		if selection_marker:
			selection_marker.visible = false
	)


func _flash_failure(cell: Vector2i) -> void:
	if selection_marker == null:
		return
	selection_marker.visible = true
	selection_marker.position = Vector3(cell.x - HALF, 0.16, cell.y - HALF)
	selection_marker.scale = Vector3.ONE

	var marker_mat := selection_marker.material_override as StandardMaterial3D
	if marker_mat:
		marker_mat.albedo_color = Color(0.98, 0.30, 0.36, 0.66)

	var tween: Tween = create_tween()
	tween.tween_property(selection_marker, "scale", Vector3(1.12, 1.0, 1.12), 0.10)
	tween.tween_property(selection_marker, "scale", Vector3.ONE, 0.10)
	tween.tween_interval(0.18)
	tween.tween_callback(func():
		if selection_marker:
			selection_marker.visible = false
	)


func _toggle_menu() -> void:
	if menu_panel:
		menu_panel.visible = not menu_panel.visible

func _new_game() -> void:
	tutorial_done = false
	mission_stage = 1
	fresh_game = true
	_seed_city()
	_save_game(false)
	if menu_panel:
		menu_panel.visible = false
	_begin_play_session()

func _can_place(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE or cell.y >= GRID_SIZE:
		return false
	if selected_tool == "bulldoze":
		return cells.has(cell) and cells[cell]["type"] != "city"
	return not cells.has(cell)

func _show_selection(cell: Vector2i) -> void:
	if selection_marker == null:
		return
	last_selection_cell = cell
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE or cell.y >= GRID_SIZE:
		selection_marker.visible = false
		return
	selection_marker.position = Vector3(cell.x - HALF, 0.15, cell.y - HALF)
	selection_marker.visible = true
	var marker_mat := selection_marker.material_override as StandardMaterial3D
	if marker_mat:
		marker_mat.albedo_color = Color(0.13, 0.83, 0.93, 0.46) if _can_place(cell) else Color(0.98, 0.30, 0.36, 0.46)

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
	var aspect: float = viewport_size.x / max(viewport_size.y, 1.0)
	var portrait_boost := 1.25 if aspect < 0.85 else 1.0
	camera.size = 14.0 * portrait_boost / camera_zoom


func _on_viewport_resized() -> void:
	_update_camera()
	_apply_ui_layout()


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
	_show_selection(cell)
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
		"tutorial_done": tutorial_done,
		"mission_stage": mission_stage,
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
	tutorial_done = bool(parsed.get("tutorial_done", true))
	if parsed.has("mission_stage"):
		mission_stage = clampi(int(parsed.get("mission_stage", 1)), 1, 4)
	else:
		# Backward compatibility with saves from the single-mission version.
		mission_stage = 2 if bool(parsed.get("mission_reward_claimed", false)) else 1

	for item in parsed.get("cells", []):
		_spawn(str(item["type"]), Vector2i(int(item["x"]), int(item["y"])))

	_set_tool(selected_tool)
	_evaluate()
	if show_message:
		_toast("保存データを読み込みました")
	return true
