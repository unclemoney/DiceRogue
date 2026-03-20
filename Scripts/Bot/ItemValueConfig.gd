extends Resource
class_name ItemValueConfig

## ItemValueConfig
##
## Configuration resource for the item value estimation tool.
## Controls which items are tested, simulation parameters, and output options.

## Number of simulated Yahtzee games per item (higher = more accurate but slower)
@export_range(10, 1000) var simulations_per_item: int = 100

## Channel to simulate on (affects target score scaling)
@export_range(1, 20) var target_channel: int = 2

## If true, test all powerups found in Scripts/PowerUps/*.tres
@export var test_all_powerups: bool = true

## If true, test all consumables found in Scripts/Consumable/*.tres
@export var test_all_consumables: bool = true

## Specific item IDs to test (used when test_all_* is false)
@export var specific_item_ids: Array[String] = []

## If true, save report to user://item_value_reports/
@export var save_report: bool = true

## If true, print each item result to console as it completes
@export var verbose: bool = true
