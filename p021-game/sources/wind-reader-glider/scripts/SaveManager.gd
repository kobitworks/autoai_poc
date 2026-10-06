class_name WindReaderSaveManager
extends RefCounted

const SAVE_PATH := "user://wind_reader_glider.cfg"
const SFX_LEVELS := [1.0, 0.7, 0.4, 0.0]

var sfx_step := 1
var tutorial_completed := false
var unlocked_stage := 1
var stage_records: Dictionary = {}

func _default_record() -> Dictionary:
	return {"best_score": 0, "best_time_ms": -1, "best_medal": ""}

func load_state() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	sfx_step = 1
	tutorial_completed = false
	unlocked_stage = 1
	stage_records.clear()
	for stage_id in range(1, 4):
		stage_records[stage_id] = _default_record()
	if err != OK:
		return
	sfx_step = clampi(int(cfg.get_value("global", "sfx_volume_step", 1)), 0, SFX_LEVELS.size() - 1)
	tutorial_completed = bool(cfg.get_value("global", "tutorial_completed", false))
	unlocked_stage = clampi(int(cfg.get_value("global", "unlocked_stage", 1)), 1, 3)
	for stage_id in range(1, 4):
		var section := "stage_%d" % stage_id
		stage_records[stage_id] = {
			"best_score": maxi(0, int(cfg.get_value(section, "best_score", 0))),
			"best_time_ms": int(cfg.get_value(section, "best_time_ms", -1)),
			"best_medal": str(cfg.get_value(section, "best_medal", ""))
		}

func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("global", "tutorial_completed", tutorial_completed)
	cfg.set_value("global", "unlocked_stage", unlocked_stage)
	cfg.set_value("global", "sfx_volume_step", sfx_step)
	for stage_id in range(1, 4):
		var section := "stage_%d" % stage_id
		var record: Dictionary = stage_records.get(stage_id, _default_record())
		cfg.set_value(section, "best_score", int(record.get("best_score", 0)))
		cfg.set_value(section, "best_time_ms", int(record.get("best_time_ms", -1)))
		cfg.set_value(section, "best_medal", str(record.get("best_medal", "")))
	cfg.save(SAVE_PATH)

func cycle_sfx() -> void:
	sfx_step = (sfx_step + 1) % SFX_LEVELS.size()
	save_state()

func sfx_label() -> String:
	return ["SFX 100%", "SFX 70%", "SFX 40%", "SFX OFF"][sfx_step]

func get_stage_record(stage_id: int) -> Dictionary:
	var safe_id := clampi(stage_id, 1, 3)
	return (stage_records.get(safe_id, _default_record()) as Dictionary).duplicate()

func unlock_stage(stage_id: int) -> bool:
	var target := clampi(stage_id, 1, 3)
	if target <= unlocked_stage:
		return false
	unlocked_stage = target
	save_state()
	return true

func record_stage(stage_id: int, score: int, time_ms: int, medal: String) -> bool:
	var safe_id := clampi(stage_id, 1, 3)
	var record: Dictionary = stage_records.get(safe_id, _default_record())
	var changed := false
	if score > int(record.get("best_score", 0)):
		record["best_score"] = score
		changed = true
	var current_time := int(record.get("best_time_ms", -1))
	if current_time < 0 or time_ms < current_time:
		record["best_time_ms"] = time_ms
		changed = true
	var rank := {"": 0, "BRONZE": 1, "SILVER": 2, "GOLD": 3}
	if int(rank.get(medal, 0)) > int(rank.get(str(record.get("best_medal", "")), 0)):
		record["best_medal"] = medal
		changed = true
	if changed:
		stage_records[safe_id] = record
		save_state()
	return changed
