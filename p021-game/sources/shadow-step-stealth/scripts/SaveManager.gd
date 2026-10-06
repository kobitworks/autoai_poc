class_name ShadowSaveManager
extends RefCounted

const SAVE_PATH := "user://shadow_step_stealth.cfg"
const SFX_LEVELS := [1.0, 0.7, 0.4, 0.0]

var tutorial_completed := false
var unlocked_stage := 1
var sfx_step := 1
var best_score := 0
var best_time_ms := -1
var best_info := 0
var best_rank := ""

func load_state() -> void:
	tutorial_completed = false
	unlocked_stage = 1
	sfx_step = 1
	best_score = 0
	best_time_ms = -1
	best_info = 0
	best_rank = ""
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	tutorial_completed = bool(cfg.get_value("global", "tutorial_completed", false))
	unlocked_stage = clampi(int(cfg.get_value("global", "unlocked_stage", 1)), 1, 3)
	sfx_step = clampi(int(cfg.get_value("global", "sfx_volume_step", 1)), 0, SFX_LEVELS.size() - 1)
	best_score = maxi(0, int(cfg.get_value("stage_1", "best_score", 0)))
	best_time_ms = int(cfg.get_value("stage_1", "best_time_ms", -1))
	best_info = maxi(0, int(cfg.get_value("stage_1", "best_info", 0)))
	best_rank = str(cfg.get_value("stage_1", "best_rank", ""))

func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("global", "tutorial_completed", tutorial_completed)
	cfg.set_value("global", "unlocked_stage", unlocked_stage)
	cfg.set_value("global", "sfx_volume_step", sfx_step)
	cfg.set_value("stage_1", "best_score", best_score)
	cfg.set_value("stage_1", "best_time_ms", best_time_ms)
	cfg.set_value("stage_1", "best_info", best_info)
	cfg.set_value("stage_1", "best_rank", best_rank)
	cfg.save(SAVE_PATH)

func cycle_sfx() -> void:
	sfx_step = (sfx_step + 1) % SFX_LEVELS.size()
	save_state()

func sfx_label() -> String:
	return ["SFX 100%", "SFX 70%", "SFX 40%", "SFX OFF"][sfx_step]

func volume_linear() -> float:
	return float(SFX_LEVELS[sfx_step])

func record_stage(score: int, time_ms: int, info_count: int, rank: String) -> bool:
	var changed := false
	if score > best_score:
		best_score = score
		changed = true
	if best_time_ms < 0 or time_ms < best_time_ms:
		best_time_ms = time_ms
		changed = true
	if info_count > best_info:
		best_info = info_count
		changed = true
	var order := {"":0,"C":1,"B":2,"A":3,"S":4}
	if int(order.get(rank, 0)) > int(order.get(best_rank, 0)):
		best_rank = rank
		changed = true
	if changed:
		save_state()
	return changed
