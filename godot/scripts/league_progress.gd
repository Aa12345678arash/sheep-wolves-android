extends RefCounted
class_name WolfDuskLeague

const SAVE_PATH := "user://wolf_dusk_progress.cfg"
const LEAGUES := ["چوبی", "برنزی", "نقره‌ای", "طلایی", "قهرمان دشت سبز"]
const THRESHOLDS := [0, 100, 300, 650, 1100]

static func load_progress() -> Dictionary:
	var config := ConfigFile.new()
	var result := {"xp": 0, "coins": 0, "wins": 0, "losses": 0}
	if config.load(SAVE_PATH) == OK:
		result.xp = int(config.get_value("career", "xp", 0))
		result.coins = int(config.get_value("career", "coins", 0))
		result.wins = int(config.get_value("career", "wins", 0))
		result.losses = int(config.get_value("career", "losses", 0))
	return result

static func league_for_xp(xp: int) -> String:
	var index := 0
	for i in range(THRESHOLDS.size()):
		if xp >= THRESHOLDS[i]:
			index = i
	return LEAGUES[index]

static func award_result(player_won: bool, difficulty: int) -> Dictionary:
	var progress := load_progress()
	var multiplier := clampi(difficulty, 0, 2) + 1
	var earned_xp := (50 if player_won else 15) * multiplier
	var earned_coins := (20 if player_won else 5) * multiplier
	progress.xp += earned_xp
	progress.coins += earned_coins
	if player_won:
		progress.wins += 1
	else:
		progress.losses += 1
	var config := ConfigFile.new()
	for key in progress:
		config.set_value("career", key, progress[key])
	config.save(SAVE_PATH)
	return {
		"xp": earned_xp,
		"coins": earned_coins,
		"total_xp": progress.xp,
		"total_coins": progress.coins,
		"league": league_for_xp(progress.xp),
		"wins": progress.wins,
		"losses": progress.losses
	}
