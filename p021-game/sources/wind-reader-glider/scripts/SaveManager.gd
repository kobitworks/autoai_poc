class_name WindReaderSaveManager
extends RefCounted

const SAVE_PATH := "user://wind_reader_glider.cfg"
const SFX_LEVELS := [1.0, 0.7, 0.4, 0.0]

var sfx_step := 1
var best_score := 0
var best_time_ms := -1
var best_medal := ""
var tutorial_completed := false
var unlocked_stage := 1

func load_state() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return
	sfx_step = clampi(int(cfg.get_value("global", "sfx_volume_step", 1)), 0, SFX_LEVELS.size() - 1)
	tutorial_completed = bool(cfg.get_value("global", "tutorial_completed", false))
	unlocked_stage = clampi(int(cfg.get_value("global", "unlocked_stage", 1)), 1, 3)
	best_score = maxi(0, int(cfg.get_value("stage_1", "best_score", 0)))
	best_time_ms = int(cfg.get_value("stage_1", "best_time_ms", -1))
	best_medal = str(cfg.get_value("stage_1", "best_medal", ""))

func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("global", "tutorial_completed", tutorial_completed)
	cfg.set_value("global", "unlocked_stage", unlocked_stage)
	cfg.set_value("global", "sfx_volume_step", sfx_step)
	cfg.set_value("stage_1", "best_score", best_score)
	cfg.set_value("stage_1", "best_time_ms", best_time_ms)
	cfg.set_value("stage_1", "best_medal", best_medal)
	cfg.save(SAVE_PATH)

func cycle_sfx() -> void:
	sfx_step = (sfx_step + 1) % SFX_LEVELS.size()
	save_state()

func sfx_label() -> String:
	return ["SFX 100%", "SFX 70%", "SFX 40%", "SFX OFF"][sfx_step]

func record_stage_1(score: int, time_ms: int, medal: String) -> bool:
	var changed := false
	if score > best_score:
		best_score = score
		changed = true
	if best_time_ms < 0 or time_ms < best_time_ms:
		best_time_ms = time_ms
		changed = true
	var rank := {"": 0, "BRONZE": 1, "SILVER": 2, "GOLD": 3}
	if int(rank.get(medal, 0)) > int(rank.get(best_medal, 0)):
		best_medal = medal
		changed = true
	if changed:
		save_state()
	return changed
