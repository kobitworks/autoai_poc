extends SceneTree

const CoverGraphScript = preload("res://scripts/CoverGraph.gd")
const VisibilityModelScript = preload("res://scripts/VisibilityModel.gd")
const AlertModelScript = preload("res://scripts/AlertModel.gd")
const StageDefinitionScript = preload("res://scripts/StageDefinition.gd")

var failures := 0

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _init() -> void:
	var stage1: Dictionary = StageDefinitionScript.stage_1()
	var graph1 = CoverGraphScript.new()
	graph1.configure(stage1["nodes"], stage1["edges"])
	check((stage1["nodes"] as Array).size() == 9, "stage 1 has 9 cover nodes")
	check((stage1["lights"] as Array).size() == 2, "stage 1 has 2 search lights")
	check(graph1.can_move("N1", "N2"), "connected node can move")
	check(not graph1.can_move("N1", "N9"), "unconnected node cannot move")
	check(graph1.neighbors("N4").size() >= 4, "stage 1 branching route exists")

	var stage2: Dictionary = StageDefinitionScript.stage_2()
	var graph2 = CoverGraphScript.new()
	graph2.configure(stage2["nodes"], stage2["edges"])
	check((stage2["nodes"] as Array).size() == 13, "stage 2 has 13 cover nodes")
	check((stage2["lights"] as Array).size() == 3, "stage 2 has 3 search lights")
	check((stage2["info"] as Array).size() == 3, "stage 2 has 3 info fragments")
	check(graph2.can_move("N3", "N5"), "stage 2 one-way edge allows forward move")
	check(not graph2.can_move("N5", "N3"), "stage 2 one-way edge blocks reverse move")
	check(graph2.can_move("N12", "N13"), "stage 2 exit is reachable from exit-near node")

	var stage3: Dictionary = StageDefinitionScript.stage_3()
	var graph3 = CoverGraphScript.new()
	graph3.configure(stage3["nodes"], stage3["edges"])
	check((stage3["nodes"] as Array).size() == 16, "stage 3 has 16 cover nodes")
	check((stage3["lights"] as Array).size() == 4, "stage 3 has 4 search lights")
	check((stage3["info"] as Array).size() == 4, "stage 3 has 4 info fragments")
	check(float(stage3.get("phase_switch_sec", -1.0)) > 0.0, "stage 3 defines deterministic phase switch")
	check(float(stage3.get("phase_warning_sec", 0.0)) >= 2.0, "stage 3 warns before phase switch")
	check(graph3.can_move("N15", "N16"), "stage 3 exit is reachable")
	check(str((stage3["lights"] as Array)[1].get("mode", "")) == "loop", "stage 3 mixes loop light mode")
	check(str((stage3["lights"] as Array)[2].get("mode", "")) == "scripted", "stage 3 mixes scripted light mode")

	var origin := Vector2.ZERO
	var point := Vector2(5, 0)
	check(VisibilityModelScript.in_cone(origin, 0.0, 0.4, 10.0, point), "point in light cone")
	check(not VisibilityModelScript.in_cone(origin, 1.5, 0.3, 10.0, point), "point outside FOV")
	check(not VisibilityModelScript.in_cone(origin, 0.0, 0.4, 4.0, point), "point outside range")
	var blockers := [{"center": Vector2(2.5, 0), "radius": 0.7}]
	check(not VisibilityModelScript.is_visible(origin, 0.0, 0.4, 10.0, point, blockers), "occluder blocks visibility")
	check(VisibilityModelScript.is_visible(origin, 0.0, 0.4, 10.0, point, []), "unoccluded point visible")

	var alert = AlertModelScript.new()
	alert.update(1.1, true, false)
	check(alert.value >= 35.0 and alert.state() == "SUSPICIOUS", "alert rises into suspicious state")
	alert.update(1.1, false, false)
	check(alert.value < 5.0 and alert.state() == "HIDDEN", "alert recovers in shadow")
	for i in range(4):
		alert.update(1.0, true, true)
	check(alert.spotted() and alert.value == 100.0, "alert clamps and fails at 100")
	alert.reset()
	check(alert.value == 0.0 and alert.peak == 0.0, "retry reset clears alert")

	var stage3_again: Dictionary = StageDefinitionScript.get_stage(3)
	check(stage3_again["nodes"] == stage3["nodes"], "stage seed/data is deterministic")
	check(str(StageDefinitionScript.get_stage(2).get("name", "")) == "交差する警備区画", "stage lookup returns stage 2")
	check(str(StageDefinitionScript.get_stage(3).get("name", "")) == "零時の中枢保管室", "stage lookup returns stage 3")

	print("GAME-G008 three-stage headless logic checks complete: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
