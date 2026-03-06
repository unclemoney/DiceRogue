extends RefCounted
class_name BotReportWriter

## BotReportWriter
##
## Writes JSON reports from BotStatistics data after all bot runs complete.

# Preloads for LSP scope resolution
const BotStatisticsScript := preload("res://Scripts/Bot/bot_statistics.gd")
const BotConfigScript := preload("res://Scripts/Bot/BotConfig.gd")

const REPORT_DIR := "user://bot_reports/"


## write_report(statistics, config) -> String
##
## Writes the full report to a timestamped JSON file.
## Returns the file path written.
func write_report(statistics: BotStatistics, config: BotConfig) -> String:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var path = REPORT_DIR + "bot_report_" + timestamp + ".json"

	var report := {
		"generated_at": Time.get_datetime_string_from_system(),
		"config": _serialize_config(config),
		"aggregate": statistics.get_aggregate(),
		"runs": statistics.runs
	}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[BotReportWriter] Could not open report file: " + path)
		return ""

	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("[BotReportWriter] Report saved to: " + path)
	return path


## _serialize_config(config) -> Dictionary
func _serialize_config(config: BotConfig) -> Dictionary:
	return {
		"attempts": config.attempts,
		"channel_min": config.channel_min,
		"channel_max": config.channel_max,
		"visual_mode": config.visual_mode,
		"speed_multiplier": config.speed_multiplier,
		"reset_between_runs": config.reset_between_runs,
		"turn_delay": config.turn_delay,
		"strategy_preset": config.strategy_preset
	}
