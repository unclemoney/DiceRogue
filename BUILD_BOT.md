# BUILD_BOT.md — Automated Bot Play-Test System

## Overview

The Bot system provides automated play-testing of the dice roguelite game. A state-machine-driven `BotController` plays through full game runs (channel selection → 6 rounds × 13 turns → shop phases → win/lose), collects statistics, logs errors, and writes JSON reports.

## File Inventory

| File | Purpose |
|------|---------|
| `Scripts/Bot/BotConfig.gd` | Resource class with configurable run parameters |
| `Scripts/Bot/bot_controller.gd` | Core state machine — drives the bot through the game loop |
| `Scripts/Bot/bot_strategy.gd` | Decision engine: scoring, dice locking, shopping |
| `Scripts/Bot/bot_statistics.gd` | Per-run and aggregate statistics collection |
| `Scripts/Bot/bot_report_writer.gd` | JSON report writer |
| `Scripts/Bot/bot_logger.gd` | Error/crash/edge-case logging |
| `Scripts/Bot/bot_profile.gd` | Persistent bot player profile (JSON save/load) |
| `Tests/bot_test.gd` | Scene script wiring BotController to game nodes |
| `Tests/bot_results_panel.gd` | In-game results panel (BBCode rich text) |
| `Tests/BotTest.tscn` | Godot scene file (mirrors DebuffTest.tscn + bot nodes) |
| `Resources/Data/default_bot_config.tres` | Default configuration resource |

## Setup Instructions

### Quick Start

1. Open the project in Godot 4.4.
2. Open `Tests/BotTest.tscn` in the editor.
3. Select the root `Node2D` node and assign `Resources/Data/default_bot_config.tres` to the **Bot Config** export in the Inspector.
4. Press F6 (Run Current Scene) or use:
   ```
   & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/BotTest.tscn
   ```
5. The bot will start automatically after a 0.3s delay.

### Configuration Options

Edit `default_bot_config.tres` in the Inspector or create a new `BotConfig` resource:

| Property | Default | Description |
|----------|---------|-------------|
| `attempts` | 10 | Number of full game runs |
| `channel_min` | 1 | Lowest channel to test |
| `channel_max` | 1 | Highest channel to test (bot picks randomly in range) |
| `visual_mode` | false | If true, plays with animations at normal speed |
| `speed_multiplier` | 10.0 | Time scale when visual_mode is false |
| `reset_between_runs` | true | Reset profile/progression between runs |
| `turn_delay` | 0.1 | Delay (seconds) between actions in visual mode |
| `log_verbose` | true | Log every bot action |
| `open_report_on_finish` | true | Open report file location when done |
| `strategy_preset` | "default" | Strategy name (for future expansion) |

## Bot Strategy

The bot follows these rules (defined in `bot_strategy.gd`):

### Scoring
- Evaluates all unscored categories using `scorecard.evaluate_category()`
- Always selects the category with the highest score
- Tiebreaks using `_get_category_priority()` (prefers harder-to-fill categories)

### Dice Locking
- Locks dice for 4+ of-a-kind when detected
- Recognizes and holds straight sequences
- Falls back to locking 3-of-a-kind, then pairs, then highest single die

### Rerolling
- Rerolls if `rolls_left > 0` AND current best score < 40 AND not already Yahtzee/Large Straight

### Shopping
- Evaluates items by rarity (higher rarity = higher priority)
- Buys greedily within budget, highest priority first
- When forced to sell a power-up, sells the lowest rarity one

### Chore / Goof-Off / Mom Handling
- After every roll, increments goof-off progress via `chores_manager.increment_progress(1)`
- After scoring, checks chore task completion with full context (category, dice values, score, etc.)
- When `request_chore_selection` fires (task rotation every ~20 rolls), bot picks EASY or HARD at random (60% bias toward HARD since it reduces progress by 30 vs 10)
- When `mom_triggered` fires (progress reaches threshold), bot auto-dismisses the Mom dialog popup
- Chores manager is reset between runs via `reset_for_new_game()` and updated with round number each round

## Output Files

All output goes to `user://bot_reports/`:

- **`bot_report_{timestamp}.json`** — Aggregate statistics, per-run details, config used
- **`bot_log_{timestamp}.json`** — Detailed action log with errors, edge cases, crashes

### Report Fields

```json
{
  "summary": {
    "total_runs": 10,
    "wins": 7,
    "losses": 3,
    "win_rate": 0.7,
    "average_score": 245,
    "highest_score": 380,
    "lowest_score": 120,
    "total_mom_visits": 4,
    "total_chores_easy": 2,
    "total_chores_hard": 5
  },
  "per_run": [...],
  "config": {...}
}
```

## Architecture

### State Machine Flow

```
IDLE → STARTING_RUN → WAITING_FOR_ROUND → ROLLING → LOCKING → SCORING
  → WAITING_FOR_NEXT_TURN → (back to ROLLING for 13 turns)
  → COMPLETING_ROUND → SHOP_PHASE → (back to WAITING_FOR_ROUND for 6 rounds)
  → RUN_WON / RUN_LOST → (back to STARTING_RUN) → FINISHED
```

### Signal Connections

BotController connects to these signals per run:
- `round_manager.round_started` / `round_completed` / `round_failed`
- `round_manager.all_rounds_completed`
- `turn_tracker.game_over` / `rolls_exhausted`
- `score_card.upper_bonus_achieved`
- `dice_hand.roll_complete`
- `chores_manager.request_chore_selection` / `mom_triggered`

### Game API Calls

The bot drives the game through direct method calls (not UI simulation):
- `dice_hand.prepare_dice_for_roll()` + `dice_hand.roll_all()`
- `turn_tracker.use_roll()`
- `score_card.on_category_selected(section, category)`
- `round_manager.start_game()` / `start_round()`
- Shop item purchasing via `shop_ui` methods

## Troubleshooting

### Scene won't load
- Ensure all scripts in `Scripts/Bot/` exist and have no parse errors
- Open Godot editor first to let it generate `.uid` files for new scripts
- Check the Output panel for missing resource errors

### Bot gets stuck
- Check the in-game status label (bottom-left panel) for current state
- Enable `log_verbose` and check `user://bot_reports/` for the log file
- Common causes: signal not firing, scoring returning no valid category

### No report generated
- Reports write to `user://bot_reports/` which is:
  - Windows: `%APPDATA%\Godot\app_userdata\DiceRogue\bot_reports\`
- Check the Output panel for file write errors

## Extending

### Custom Strategies
Create a new function in `bot_strategy.gd` or subclass it. The `strategy_preset` field on BotConfig is reserved for this.

### Adding New Statistics
Add tracking calls in `bot_statistics.gd` and update `bot_report_writer.gd` to include them in the report.
