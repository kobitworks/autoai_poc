class_name ShadowStageDefinition
extends RefCounted

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
			{"from":"N1","to":"N2","time":0.55},
			{"from":"N1","to":"N3","time":0.65},
			{"from":"N2","to":"N4","time":0.60},
			{"from":"N2","to":"N5","time":0.78},
			{"from":"N3","to":"N4","time":0.62},
			{"from":"N3","to":"N6","time":0.82},
			{"from":"N4","to":"N5","time":0.52},
			{"from":"N4","to":"N6","time":0.58},
			{"from":"N4","to":"N7","time":0.78},
			{"from":"N5","to":"N7","time":0.66},
			{"from":"N6","to":"N8","time":0.74},
			{"from":"N7","to":"N8","time":0.61},
			{"from":"N8","to":"N9","time":0.52}
		],
		"lights": [
			{"origin":Vector2(0.47,0.08),"min_angle":0.92,"max_angle":2.20,"speed":0.78,"phase":0.0,"range":0.72,"half_fov":0.25,"intensity":1.0},
			{"origin":Vector2(0.91,0.48),"min_angle":2.42,"max_angle":3.55,"speed":0.63,"phase":1.7,"range":0.62,"half_fov":0.23,"intensity":1.0}
		]
	}

static func stage_2() -> Dictionary:
	return {"id":2,"name":"交差する警備区画","status":"planned"}

static func stage_3() -> Dictionary:
	return {"id":3,"name":"零時の中枢保管室","status":"planned"}
