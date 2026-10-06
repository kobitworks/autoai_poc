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
	var stage: Dictionary = StageDefinitionScript.stage_1()
	var graph = CoverGraphScript.new()
	graph.configure(stage["nodes"], stage["edges"])
	check((stage["nodes"] as Array).size() == 9, "stage 1 has 9 cover nodes")
	check((stage["lights"] as Array).size() == 2, "stage 1 has 2 search lights")
	check(graph.can_move("N1", "N2"), "connected node can move")
	check(not graph.can_move("N1", "N9"), "unconnected node cannot move")
	check(graph.neighbors("N4").size() >= 4, "branching route exists")

	var origin := Vector2.ZERO
	var point := Vector2(5, 0)
	check(VisibilityModelScript.in_cone(origin, 0.0, 0.4, 10.0, point), "point in light cone")
	check(not VisibilityModelScript.in_cone(origin, 1.5, 0.3, 10.0, point), "point outside FOV")
	check(not VisibilityModelScript.in_cone(origin, 0.0, 0.4, 4.0, point), "point outside range")
	var blockers := [{"center": Vector2(2.5, 0), "radius": 0.7}]
	check(not VisibilityModelScript.is_visible(origin, 0.0, 0.4, 10.0, point, blockers), "occluder blocks visibility")
	check(VisibilityModelScript.is_visible(origin, 0.0, 0.4, 10.0, point, []), "unoccluded point visible")

	var alert = AlertModelScript.new()
	alert.update(1.0, true, false)
	check(alert.value > 30.0 and alert.state() == "SUSPICIOUS", "alert rises in light")
	alert.update(1.0, false, false)
	check(alert.value < 5.0 and alert.state() == "HIDDEN", "alert recovers in shadow")
	for i in range(4):
		alert.update(1.0, true, true)
	check(alert.spotted() and alert.value == 100.0, "alert clamps and fails at 100")
	alert.reset()
	check(alert.value == 0.0 and alert.peak == 0.0, "retry reset clears alert")

	print("GAME-G008 headless logic checks complete: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
