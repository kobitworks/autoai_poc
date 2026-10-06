class_name WindReaderStageDefinition
extends RefCounted

static func stage_1() -> Dictionary:
	return {
		"id": 1,
		"name": "朝凪の丘",
		"length": 1400.0,
		"base_speed": 18.0,
		"required_target": 6,
		"par_time": 80.0,
		"gates": [
			_gate("R1", 150.0, 54.0, 0.00, 14.0, 0.38, true),
			_gate("R2", 300.0, 64.0, -0.25, 13.0, 0.34, true),
			_gate("B1", 390.0, 76.0, 0.42, 10.0, 0.25, false),
			_gate("R3", 470.0, 45.0, 0.18, 13.0, 0.34, true),
			_gate("R4", 625.0, 58.0, -0.38, 13.0, 0.34, true),
			_gate("B2", 720.0, 78.0, 0.48, 9.0, 0.24, false),
			_gate("R5", 790.0, 66.0, 0.15, 13.0, 0.34, true),
			_gate("R6", 950.0, 50.0, -0.18, 13.0, 0.34, true),
			_gate("B3", 1040.0, 72.0, -0.50, 9.0, 0.24, false),
			_gate("R7", 1120.0, 61.0, 0.30, 13.0, 0.34, true),
			_gate("R8", 1270.0, 55.0, 0.00, 14.0, 0.38, true)
		],
		"wind_zones": [
			_wind("U1", "UPDRAFT", 210.0, 330.0, 0.9, 0.0),
			_wind("U2", "UPDRAFT", 510.0, 620.0, 0.8, 0.0),
			_wind("C1", "CROSSWIND", 690.0, 810.0, 0.55, 1.0),
			_wind("U3", "UPDRAFT", 850.0, 980.0, 1.0, 0.0),
			_wind("C2", "CROSSWIND", 1010.0, 1120.0, 0.45, -1.0),
			_wind("U4", "UPDRAFT", 1160.0, 1300.0, 0.8, 0.0)
		],
		"obstacles": [
			_obstacle(560.0, 34.0, 0.55, 7.0, 0.18, 20.0),
			_obstacle(735.0, 55.0, -0.58, 8.0, 0.18, 20.0),
			_obstacle(1030.0, 42.0, 0.52, 8.0, 0.20, 20.0),
			_obstacle(1205.0, 72.0, -0.46, 8.0, 0.20, 20.0)
		]
	}

static func _gate(id: String, x: float, altitude: float, depth: float, alt_tol: float, depth_tol: float, required: bool) -> Dictionary:
	return {
		"id": id,
		"x": x,
		"altitude": altitude,
		"depth": depth,
		"alt_tol": alt_tol,
		"depth_tol": depth_tol,
		"required": required
	}

static func _wind(id: String, type: String, x_start: float, x_end: float, strength: float, direction: float) -> Dictionary:
	return {
		"id": id,
		"type": type,
		"x_start": x_start,
		"x_end": x_end,
		"strength": strength,
		"direction": direction
	}

static func _obstacle(x: float, altitude: float, depth: float, alt_radius: float, depth_radius: float, damage: float) -> Dictionary:
	return {
		"x": x,
		"altitude": altitude,
		"depth": depth,
		"alt_radius": alt_radius,
		"depth_radius": depth_radius,
		"damage": damage
	}
