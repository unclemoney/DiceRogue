extends Resource
class_name BotConfig

## BotConfig
##
## Resource class for configuring automated bot test runs.
## Create instances in the Inspector or load from .tres files.

## Number of full game runs the bot will attempt
@export var attempts: int = 10

## Minimum channel to test (1-20)
@export_range(1, 20) var channel_min: int = 1

## Maximum channel to test (1-20)
@export_range(1, 20) var channel_max: int = 1

## If true, the bot plays visually with animations. If false, runs at max speed.
@export var visual_mode: bool = false

## Time scale multiplier when visual_mode is false (higher = faster)
@export_range(1.0, 100.0) var speed_multiplier: float = 10.0

## If true, reset the bot profile between each run. If false, carry over progression.
@export var reset_between_runs: bool = true

## Artificial delay (seconds) between bot actions in visual mode
@export_range(0.0, 2.0) var turn_delay: float = 0.1

## If true, log detailed info for every bot action
@export var log_verbose: bool = true

## If true, open the JSON report file location after all runs complete
@export var open_report_on_finish: bool = true

## Maximum shop rerolls per shop visit (safety cap for bot reroll logic)
@export_range(0, 20) var max_rerolls_per_shop: int = 5

## Strategy preset name (for future expansion)
@export var strategy_preset: String = "default"

## If true, mute the Master audio bus while the bot is running.
## Set to false to hear SFX and music during visual bot runs.
@export var mute_audio: bool = true
