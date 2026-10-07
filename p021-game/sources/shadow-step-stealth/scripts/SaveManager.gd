class_name ShadowSaveManager
extends RefCounted

const SAVE_PATH := "user://shadow_step_stealth.cfg"
const SFX_LEVELS := [1.0, 0.7, 0.4, 0.0]
const RANK_ORDER := {"":0,"C":1,"B":2,"A":3,"S":4}

var tutorial_completed := false
var unlocked_stage := 1
var sfx_step := 1
var records: Dictionary = {}

func _default_record() -> Dictionary:
	return {"best_score":0,"best_time_ms":-1,"best_info":0,"best_rank":""}

func load_state() -> void:
	tutorial_completed = false
	unlocked_stage = 1
	sfx_step = 1
	records.clear()
	for stage_id in range(1, 4):
		records[stage_id] = _default_record()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	tutorial_completed = bool(cfg.get_value("global", "tutorial_completed", false))
	unlocked_stage = clampi(int(cfg.get_value("global", "unlocked_stage", 1)), 1, 3)
	sfx_step = clampi(int(cfg.get_value("global", "sfx_volume_step", 1)), 0, SFX_LEVELS.size() - 1)
	for stage_id in range(1, 4):
		var section := "stage_%d" % stage_id
		records[stage_id] = {
			"best_score": maxi(0, int(cfg.get_value(section, "best_score", 0))),
			"best_time_ms": int(cfg.get_value(section, "best_time_ms", -1)),
			"best_info": maxi(0, int(cfg.get_value(section, "best_info", 0))),
			"best_rank": str(cfg.get_value(section, "best_rank", ""))
		}

func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("global", "tutorial_completed", tutorial_completed)
	cfg.set_value("global", "unlocked_stage", unlocked_stage)
	cfg.set_value("global", "sfx_volume_step", sfx_step)
	for stage_id in range(1, 4):
		var section := "stage_%d" % stage_id
		var record: Dictionary = records.get(stage_id, _default_record())
		cfg.set_value(section, "best_score", int(record.get("best_score", 0)))
		cfg.set_value(section, "best_time_ms", int(record.get("best_time_ms", -1)))
		cfg.set_value(section, "best_info", int(record.get("best_info", 0)))
		cfg.set_value(section, "best_rank", str(record.get("best_rank", "")))
	cfg.save(SAVE_PATH)

func cycle_sfx() -> void:
	sfx_step = (sfx_step + 1) % SFX_LEVELS.size()
	save_state()

func sfx_label() -> String:
	return ["SFX 100%", "SFX 70%", "SFX 40%", "SFX OFF"][sfx_step]

func volume_linear() -> float:
	return float(SFX_LEVELS[sfx_step])

func is_unlocked(stage_id: int) -> bool:
	return stage_id >= 1 and stage_id <= unlocked_stage

func stage_record(stage_id: int) -> Dictionary:
	return (records.get(stage_id, _default_record()) as Dictionary).duplicate(true)

func record_stage(stage_id: int, score: int, time_ms: int, info_count: int, rank: String) -> bool:
	var changed := false
	var record: Dictionary = records.get(stage_id, _default_record())
	if score > int(record.get("best_score", 0)):
		record["best_score"] = score
		changed = true
	var best_time_ms := int(record.get("best_time_ms", -1))
	if best_time_ms < 0 or time_ms < best_time_ms:
		record["best_time_ms"] = time_ms
		changed = true
	if info_count > int(record.get("best_info", 0)):
		record["best_info"] = info_count
		changed = true
	if int(RANK_ORDER.get(rank, 0)) > int(RANK_ORDER.get(str(record.get("best_rank", "")), 0)):
		record["best_rank"] = rank
		changed = true
	records[stage_id] = record
	if stage_id < 3 and unlocked_stage < stage_id + 1:
		unlocked_stage = stage_id + 1
		changed = true
	if changed:
		save_state()
	return changed

func reset_records() -> void:
	tutorial_completed = false
	unlocked_stage = 1
	for stage_id in range(1, 4):
		records[stage_id] = _default_record()
	save_state()
