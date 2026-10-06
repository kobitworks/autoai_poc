class_name WindReaderStageDefinition
extends RefCounted

static func get_stage(stage_id: int) -> Dictionary:
	match clampi(stage_id, 1, 3):
		2:
			return stage_2()
		3:
			return stage_3()
		_:
			return stage_1()

static func stage_1() -> Dictionary:
	return {
		"id": 1, "name": "朝凪の丘", "length": 1400.0, "base_speed": 18.0,
		"required_target": 6, "par_time": 80.0, "silver_score": 9000, "gold_score": 13000,
		"gates": [
			_gate("R1",150.0,54.0,0.00,14.0,0.38,true), _gate("R2",300.0,64.0,-0.25,13.0,0.34,true),
			_gate("B1",390.0,76.0,0.42,10.0,0.25,false), _gate("R3",470.0,45.0,0.18,13.0,0.34,true),
			_gate("R4",625.0,58.0,-0.38,13.0,0.34,true), _gate("B2",720.0,78.0,0.48,9.0,0.24,false),
			_gate("R5",790.0,66.0,0.15,13.0,0.34,true), _gate("R6",950.0,50.0,-0.18,13.0,0.34,true),
			_gate("B3",1040.0,72.0,-0.50,9.0,0.24,false), _gate("R7",1120.0,61.0,0.30,13.0,0.34,true),
			_gate("R8",1270.0,55.0,0.00,14.0,0.38,true)
		],
		"wind_zones": [
			_wind("U1","UPDRAFT",210.0,330.0,0.9,0.0), _wind("U2","UPDRAFT",510.0,620.0,0.8,0.0),
			_wind("C1","CROSSWIND",690.0,810.0,0.55,1.0), _wind("U3","UPDRAFT",850.0,980.0,1.0,0.0),
			_wind("C2","CROSSWIND",1010.0,1120.0,0.45,-1.0), _wind("U4","UPDRAFT",1160.0,1300.0,0.8,0.0)
		],
		"obstacles": [
			_obstacle(560.0,34.0,0.55,7.0,0.18,20.0), _obstacle(735.0,55.0,-0.58,8.0,0.18,20.0),
			_obstacle(1030.0,42.0,0.52,8.0,0.20,20.0), _obstacle(1205.0,72.0,-0.46,8.0,0.20,20.0)
		]
	}

static func stage_2() -> Dictionary:
	return {
		"id": 2, "name": "峡谷の横風", "length": 1550.0, "base_speed": 19.5,
		"required_target": 8, "par_time": 82.0, "silver_score": 11500, "gold_score": 16000,
		"gates": [
			_gate("R1",120.0,55.0,0.00,14.0,0.38,true), _gate("R2",245.0,66.0,-0.28,12.0,0.32,true),
			_gate("B1",330.0,78.0,0.52,9.0,0.23,false), _gate("R3",410.0,48.0,0.38,12.0,0.32,true),
			_gate("B2",505.0,72.0,-0.55,9.0,0.22,false), _gate("R4",575.0,60.0,-0.30,12.0,0.30,true),
			_gate("R5",720.0,42.0,0.42,11.0,0.29,true), _gate("B3",795.0,82.0,-0.50,8.0,0.21,false),
			_gate("R6",875.0,64.0,0.10,12.0,0.31,true), _gate("B4",965.0,50.0,0.58,8.0,0.21,false),
			_gate("R7",1045.0,70.0,-0.34,11.0,0.29,true), _gate("R8",1185.0,47.0,0.36,12.0,0.31,true),
			_gate("B5",1280.0,78.0,-0.56,8.0,0.21,false), _gate("R9",1360.0,62.0,-0.12,12.0,0.31,true),
			_gate("R10",1470.0,55.0,0.05,14.0,0.36,true)
		],
		"wind_zones": [
			_wind("C1","CROSSWIND",170.0,290.0,0.75,1.0), _wind("U1","UPDRAFT",300.0,410.0,0.9,0.0),
			_wind("C2","CROSSWIND",430.0,555.0,0.85,-1.0), _wind("T1","TAILWIND",585.0,695.0,0.8,0.0),
			_wind("U2","UPDRAFT",690.0,805.0,1.0,0.0), _wind("C3","CROSSWIND",810.0,930.0,0.9,1.0),
			_wind("U3","UPDRAFT",940.0,1050.0,0.85,0.0), _wind("C4","CROSSWIND",1055.0,1175.0,0.8,-1.0),
			_wind("T2","TAILWIND",1180.0,1290.0,0.9,0.0), _wind("U4","UPDRAFT",1285.0,1395.0,0.9,0.0),
			_wind("C5","CROSSWIND",1395.0,1495.0,0.75,1.0), _wind("U5","UPDRAFT",1450.0,1530.0,0.7,0.0)
		],
		"obstacles": [
			_obstacle(280.0,43.0,0.55,8.0,0.18,20.0), _obstacle(455.0,67.0,-0.58,8.0,0.18,20.0),
			_obstacle(535.0,36.0,0.48,9.0,0.19,20.0), _obstacle(760.0,58.0,-0.48,8.0,0.18,20.0),
			_obstacle(915.0,73.0,0.52,9.0,0.19,20.0), _obstacle(1085.0,48.0,-0.55,8.0,0.18,20.0),
			_obstacle(1250.0,68.0,0.48,9.0,0.19,20.0), _obstacle(1415.0,40.0,-0.52,9.0,0.19,20.0)
		]
	}

static func stage_3() -> Dictionary:
	return {
		"id": 3, "name": "雷雲の切れ間", "length": 1750.0, "base_speed": 21.0,
		"required_target": 10, "par_time": 86.0, "silver_score": 14000, "gold_score": 19000,
		"gates": [
			_gate("R1",110.0,58.0,0.00,13.0,0.34,true), _gate("R2",225.0,68.0,-0.30,11.0,0.29,true),
			_gate("B1",300.0,82.0,0.55,8.0,0.21,false), _gate("R3",370.0,44.0,0.36,11.0,0.29,true),
			_gate("R4",500.0,62.0,-0.42,11.0,0.28,true), _gate("B2",575.0,76.0,0.56,8.0,0.20,false),
			_gate("R5",650.0,50.0,0.28,11.0,0.28,true), _gate("B3",735.0,86.0,-0.54,8.0,0.20,false),
			_gate("R6",810.0,68.0,-0.14,11.0,0.28,true), _gate("R7",945.0,42.0,0.44,10.0,0.27,true),
			_gate("B4",1020.0,80.0,0.58,8.0,0.20,false), _gate("R8",1095.0,60.0,-0.38,10.0,0.27,true),
			_gate("R9",1230.0,72.0,0.28,10.0,0.27,true), _gate("B5",1310.0,48.0,-0.58,8.0,0.20,false),
			_gate("R10",1390.0,56.0,-0.22,10.0,0.27,true), _gate("R11",1510.0,78.0,0.34,10.0,0.27,true),
			_gate("B6",1590.0,52.0,0.58,8.0,0.20,false), _gate("R12",1660.0,62.0,0.00,12.0,0.32,true)
		],
		"wind_zones": [
			_wind("U1","UPDRAFT",145.0,245.0,0.9,0.0), _wind("T1","TURBULENCE",260.0,350.0,0.65,0.0),
			_wind("C1","CROSSWIND",360.0,465.0,0.8,1.0), _wind("U2","UPDRAFT",470.0,570.0,1.0,0.0),
			_wind("T2","TURBULENCE",585.0,680.0,0.8,0.0), _wind("U3","UPDRAFT",690.0,790.0,0.9,0.0),
			_wind("C2","CROSSWIND",800.0,900.0,0.9,-1.0), _wind("T3","TURBULENCE",910.0,1005.0,0.9,0.0),
			_wind("U4","UPDRAFT",1010.0,1110.0,1.0,0.0), _wind("C3","CROSSWIND",1120.0,1220.0,0.9,1.0),
			_wind("T4","TURBULENCE",1230.0,1330.0,0.85,0.0), _wind("U5","UPDRAFT",1330.0,1435.0,0.9,0.0),
			_wind("C4","CROSSWIND",1440.0,1535.0,0.85,-1.0), _wind("T5","TURBULENCE",1540.0,1640.0,0.95,0.0),
			_wind("U6","UPDRAFT",1640.0,1730.0,0.8,0.0)
		],
		"obstacles": [
			_obstacle(245.0,38.0,0.50,8.0,0.18,20.0), _obstacle(335.0,70.0,-0.52,8.0,0.18,20.0),
			_obstacle(450.0,50.0,0.58,9.0,0.19,20.0), _obstacle(565.0,82.0,-0.48,8.0,0.18,20.0),
			_obstacle(700.0,42.0,0.50,9.0,0.19,20.0), _obstacle(845.0,68.0,-0.55,8.0,0.18,20.0),
			_obstacle(970.0,52.0,0.55,9.0,0.19,20.0), _obstacle(1085.0,78.0,-0.50,8.0,0.18,20.0),
			_obstacle(1215.0,45.0,0.52,9.0,0.19,20.0), _obstacle(1360.0,70.0,-0.56,8.0,0.18,20.0),
			_obstacle(1490.0,48.0,0.54,9.0,0.19,20.0), _obstacle(1615.0,74.0,-0.50,8.0,0.18,20.0)
		]
	}

static func _gate(id: String, x: float, altitude: float, depth: float, alt_tol: float, depth_tol: float, required: bool) -> Dictionary:
	return {"id": id, "x": x, "altitude": altitude, "depth": depth, "alt_tol": alt_tol, "depth_tol": depth_tol, "required": required}

static func _wind(id: String, type: String, x_start: float, x_end: float, strength: float, direction: float) -> Dictionary:
	return {"id": id, "type": type, "x_start": x_start, "x_end": x_end, "strength": strength, "direction": direction}

static func _obstacle(x: float, altitude: float, depth: float, alt_radius: float, depth_radius: float, damage: float) -> Dictionary:
	return {"x": x, "altitude": altitude, "depth": depth, "alt_radius": alt_radius, "depth_radius": depth_radius, "damage": damage}
