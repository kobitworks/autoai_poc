class_name ShadowStageDefinition
extends RefCounted

static func get_stage(stage_id: int) -> Dictionary:
	match stage_id:
		2:
			return stage_2()
		3:
			return stage_3()
		_:
			return stage_1()

static func stage_1() -> Dictionary:
	return {
		"id": 1,
		"name": "薄明の資料庫",
		"time_limit": 90.0,
		"par_time": 65.0,
		"start": "N1",
		"exit": "N9",
		"info": ["N5", "N7"],
		"nodes": [
			{"id":"N1","position":Vector2(0.10,0.82),"radius":0.055,"tags":["safe","tutorial"]},
			{"id":"N2","position":Vector2(0.28,0.76),"radius":0.050,"tags":["safe"]},
			{"id":"N3","position":Vector2(0.19,0.49),"radius":0.050,"tags":["safe"]},
			{"id":"N4","position":Vector2(0.43,0.58),"radius":0.048,"tags":["safe"]},
			{"id":"N5","position":Vector2(0.51,0.82),"radius":0.046,"tags":["risky","info"]},
			{"id":"N6","position":Vector2(0.56,0.35),"radius":0.050,"tags":["safe"]},
			{"id":"N7","position":Vector2(0.72,0.61),"radius":0.045,"tags":["risky","info"]},
			{"id":"N8","position":Vector2(0.79,0.30),"radius":0.050,"tags":["safe","exit_near"]},
			{"id":"N9","position":Vector2(0.92,0.18),"radius":0.052,"tags":["exit"]}
		],
		"edges": [
			{"from":"N1","to":"N2","time":0.55},{"from":"N1","to":"N3","time":0.65},
			{"from":"N2","to":"N4","time":0.60},{"from":"N2","to":"N5","time":0.78},
			{"from":"N3","to":"N4","time":0.62},{"from":"N3","to":"N6","time":0.82},
			{"from":"N4","to":"N5","time":0.52},{"from":"N4","to":"N6","time":0.58},
			{"from":"N4","to":"N7","time":0.78},{"from":"N5","to":"N7","time":0.66},
			{"from":"N6","to":"N8","time":0.74},{"from":"N7","to":"N8","time":0.61},
			{"from":"N8","to":"N9","time":0.52}
		],
		"lights": [
			{"origin":Vector2(0.47,0.08),"mode":"sweep","min_angle":0.92,"max_angle":2.20,"speed":0.78,"phase":0.0,"range":0.72,"half_fov":0.25,"intensity":1.0},
			{"origin":Vector2(0.91,0.48),"mode":"sweep","min_angle":2.42,"max_angle":3.55,"speed":0.63,"phase":1.7,"range":0.62,"half_fov":0.23,"intensity":1.0}
		]
	}

static func stage_2() -> Dictionary:
	return {
		"id": 2,
		"name": "交差する警備区画",
		"time_limit": 95.0,
		"par_time": 72.0,
		"start": "N1",
		"exit": "N13",
		"info": ["N3", "N6", "N8"],
		"nodes": [
			{"id":"N1","position":Vector2(0.07,0.84),"radius":0.050,"tags":["safe"]},
			{"id":"N2","position":Vector2(0.20,0.72),"radius":0.046,"tags":["safe"]},
			{"id":"N3","position":Vector2(0.34,0.86),"radius":0.043,"tags":["risky","info"]},
			{"id":"N4","position":Vector2(0.30,0.51),"radius":0.047,"tags":["safe"]},
			{"id":"N5","position":Vector2(0.47,0.70),"radius":0.044,"tags":["safe"]},
			{"id":"N6","position":Vector2(0.48,0.34),"radius":0.042,"tags":["risky","info"]},
			{"id":"N7","position":Vector2(0.61,0.55),"radius":0.045,"tags":["safe"]},
			{"id":"N8","position":Vector2(0.68,0.84),"radius":0.042,"tags":["risky","info"]},
			{"id":"N9","position":Vector2(0.70,0.30),"radius":0.045,"tags":["safe"]},
			{"id":"N10","position":Vector2(0.82,0.54),"radius":0.044,"tags":["safe"]},
			{"id":"N11","position":Vector2(0.86,0.78),"radius":0.044,"tags":["safe"]},
			{"id":"N12","position":Vector2(0.88,0.28),"radius":0.046,"tags":["safe","exit_near"]},
			{"id":"N13","position":Vector2(0.96,0.11),"radius":0.050,"tags":["exit"]}
		],
		"edges": [
			{"from":"N1","to":"N2","time":0.52},{"from":"N1","to":"N4","time":0.76},
			{"from":"N2","to":"N3","time":0.56},{"from":"N2","to":"N4","time":0.58},
			{"from":"N3","to":"N5","time":0.60,"one_way":true},{"from":"N4","to":"N5","time":0.56},
			{"from":"N4","to":"N6","time":0.63},{"from":"N5","to":"N6","time":0.57},
			{"from":"N5","to":"N7","time":0.52},{"from":"N5","to":"N8","time":0.72},
			{"from":"N6","to":"N7","time":0.59},{"from":"N6","to":"N9","time":0.67},
			{"from":"N7","to":"N8","time":0.58},{"from":"N7","to":"N9","time":0.55},
			{"from":"N7","to":"N10","time":0.66},{"from":"N8","to":"N11","time":0.55},
			{"from":"N9","to":"N10","time":0.54},{"from":"N9","to":"N12","time":0.65},
			{"from":"N10","to":"N11","time":0.54},{"from":"N10","to":"N12","time":0.55},
			{"from":"N11","to":"N12","time":0.63},{"from":"N12","to":"N13","time":0.48}
		],
		"lights": [
			{"origin":Vector2(0.36,0.08),"mode":"sweep","min_angle":0.78,"max_angle":2.42,"speed":1.02,"phase":0.0,"range":0.78,"half_fov":0.22,"intensity":1.0},
			{"origin":Vector2(0.69,0.10),"mode":"sweep","min_angle":0.74,"max_angle":2.52,"speed":0.74,"phase":2.1,"range":0.77,"half_fov":0.22,"intensity":1.0},
			{"origin":Vector2(0.94,0.52),"mode":"loop","min_angle":2.35,"max_angle":4.02,"speed":0.52,"phase":0.6,"range":0.60,"half_fov":0.20,"intensity":1.12}
		]
	}

static func stage_3() -> Dictionary:
	return {
		"id": 3,
		"name": "零時の中枢保管室",
		"time_limit": 105.0,
		"par_time": 82.0,
		"phase_switch_sec": 50.0,
		"phase_warning_sec": 2.0,
		"phase2_speed_scale": 1.28,
		"start": "N1",
		"exit": "N16",
		"info": ["N4", "N7", "N11", "N14"],
		"nodes": [
			{"id":"N1","position":Vector2(0.06,0.86),"radius":0.048,"tags":["safe"]},
			{"id":"N2","position":Vector2(0.18,0.73),"radius":0.044,"tags":["safe"]},
			{"id":"N3","position":Vector2(0.15,0.48),"radius":0.043,"tags":["safe"]},
			{"id":"N4","position":Vector2(0.31,0.88),"radius":0.041,"tags":["risky","info"]},
			{"id":"N5","position":Vector2(0.33,0.65),"radius":0.044,"tags":["safe"]},
			{"id":"N6","position":Vector2(0.34,0.36),"radius":0.043,"tags":["safe"]},
			{"id":"N7","position":Vector2(0.49,0.79),"radius":0.040,"tags":["risky","info"]},
			{"id":"N8","position":Vector2(0.50,0.53),"radius":0.043,"tags":["safe"]},
			{"id":"N9","position":Vector2(0.51,0.25),"radius":0.042,"tags":["safe"]},
			{"id":"N10","position":Vector2(0.65,0.68),"radius":0.043,"tags":["safe"]},
			{"id":"N11","position":Vector2(0.68,0.88),"radius":0.040,"tags":["risky","info"]},
			{"id":"N12","position":Vector2(0.68,0.40),"radius":0.043,"tags":["safe"]},
			{"id":"N13","position":Vector2(0.81,0.61),"radius":0.043,"tags":["safe"]},
			{"id":"N14","position":Vector2(0.83,0.30),"radius":0.040,"tags":["risky","info"]},
			{"id":"N15","position":Vector2(0.91,0.48),"radius":0.044,"tags":["safe","exit_near"]},
			{"id":"N16","position":Vector2(0.96,0.15),"radius":0.050,"tags":["exit"]}
		],
		"edges": [
			{"from":"N1","to":"N2","time":0.48},{"from":"N1","to":"N3","time":0.68},
			{"from":"N2","to":"N3","time":0.55},{"from":"N2","to":"N4","time":0.60},
			{"from":"N2","to":"N5","time":0.54},{"from":"N3","to":"N5","time":0.60},
			{"from":"N3","to":"N6","time":0.54},{"from":"N4","to":"N5","time":0.56},
			{"from":"N4","to":"N7","time":0.67},{"from":"N5","to":"N6","time":0.52},
			{"from":"N5","to":"N7","time":0.56},{"from":"N5","to":"N8","time":0.50},
			{"from":"N6","to":"N8","time":0.57},{"from":"N6","to":"N9","time":0.62},
			{"from":"N7","to":"N10","time":0.55},{"from":"N7","to":"N11","time":0.52},
			{"from":"N8","to":"N9","time":0.50},{"from":"N8","to":"N10","time":0.50},
			{"from":"N8","to":"N12","time":0.58},{"from":"N9","to":"N12","time":0.54},
			{"from":"N10","to":"N11","time":0.51},{"from":"N10","to":"N12","time":0.49},
			{"from":"N10","to":"N13","time":0.58},{"from":"N11","to":"N13","time":0.62},
			{"from":"N12","to":"N13","time":0.50},{"from":"N12","to":"N14","time":0.61},
			{"from":"N13","to":"N14","time":0.48},{"from":"N13","to":"N15","time":0.50},
			{"from":"N14","to":"N15","time":0.52},{"from":"N14","to":"N16","time":0.74},
			{"from":"N15","to":"N16","time":0.51}
		],
		"lights": [
			{"origin":Vector2(0.28,0.08),"mode":"sweep","min_angle":0.72,"max_angle":2.38,"speed":1.00,"phase":0.0,"range":0.76,"half_fov":0.21,"intensity":1.0,"phase2_offset":0.20},
			{"origin":Vector2(0.56,0.09),"mode":"loop","min_angle":0.55,"max_angle":2.86,"speed":0.42,"phase":0.8,"range":0.79,"half_fov":0.20,"intensity":1.08,"phase2_offset":0.45},
			{"origin":Vector2(0.80,0.08),"mode":"scripted","min_angle":0.82,"max_angle":2.45,"speed":0.86,"phase":2.3,"range":0.72,"half_fov":0.22,"intensity":1.0,"phase2_offset":-0.32},
			{"origin":Vector2(0.96,0.56),"mode":"sweep","min_angle":2.42,"max_angle":4.08,"speed":0.68,"phase":1.1,"range":0.64,"half_fov":0.20,"intensity":1.18,"phase2_offset":0.26}
		]
	}
