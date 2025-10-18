# DiceRogue Logbook System

## Overview
The Logbook system provides comprehensive tracking and debugging capabilities for all hand scoring events in DiceRogue. It captures detailed information about each scoring action, including dice values, colors, modifiers, and calculation steps, presenting them in both human-readable logs and structured data for analysis.

## Purpose
- **Debug Complex Scoring**: Track multi-layered calculations involving PowerUps, Consumables, and Mods
- **Player Transparency**: Show players exactly how their scores were calculated
- **Development Insight**: Analyze game balance and identify scoring edge cases
- **Audit Trail**: Maintain complete history of all scoring decisions

## Core Data Structure

### LogEntry Class
```gdscript
class_name LogEntry

var timestamp: float
var turn_number: int
var dice_values: Array[int]
var dice_colors: Array[String]
var dice_mods: Array[String]
var scorecard_category: String
var scorecard_section: String
var consumables_applied: Array[String]
var powerups_applied: Array[String]
var base_score: int
var modifier_effects: Array[Dictionary]
var final_score: int
var calculation_summary: String
var formatted_log_line: String
```

### Modifier Effects Structure
Each modifier effect is tracked as:
```gdscript
{
	"source": "PowerUp_Double_Ones",  # Source of the effect
	"type": "multiplier",             # Effect type: multiplier, addition, reroll, etc.
	"value": 2.0,                     # Effect value
	"description": "Doubled Ones scoring", # Human readable description
	"before_value": 4,                # Value before this effect
	"after_value": 8                  # Value after this effect
}
```

## Implementation Details

### Statistics Manager Integration
- Add `logbook: Array[LogEntry] = []` to StatisticsManager
- Implement `log_hand_scored()` method to create entries
- Add `get_recent_logs()` for UI display
- Add `get_logbook_summary()` for statistics panel
- Include logbook management in `reset_statistics()`

### Key Methods

#### log_hand_scored()
```gdscript
func log_hand_scored(
	dice_values: Array[int],
	dice_colors: Array[String],
	dice_mods: Array[String],
	category: String,
	section: String,
	consumables: Array[String],
	powerups: Array[String],
	base_score: int,
	effects: Array[Dictionary],
	final_score: int
) -> void
```

#### get_formatted_log_line()
```gdscript
func get_formatted_log_line(entry: LogEntry) -> String
	# Returns: "Turn 15: [3,3,3,2,1] → Three of a Kind (9) +PowerUp(2x) = 18pts"
```

### UI Integration

#### ExtraInfo Display
- Show last 3-5 log entries in scrolling format
- Use BBCode for color coding and emphasis
- Auto-clear after configurable time period
- Toggle between summary and detailed views

#### Statistics Panel Integration
- Full logbook browser with filtering
- Search by category, turn range, modifiers
- Export functionality for analysis
- Performance statistics based on log data

## Log Format Examples

### Basic Hand
```
Turn 12: [2,2,2,4,6] (R,R,B,G,Y) → Twos = 6pts
```

### With PowerUps
```
Turn 8: [1,1,1,3,5] (R,R,R,B,G) → Ones (3) +Double(2x) = 6pts
```

### Complex Multi-Modifier
```
Turn 23: [5,5,5,5,2] (P,P,G,Y,R) → Four of a Kind: 
  Base(22) +Lucky(+5) +Purple Dice(2x) -Debuff(-3) = 41pts
```

### Failed Scoring
```
Turn 7: [1,2,3,4,6] (R,B,G,Y,P) → Chance = 16pts (No better option)
```

## File Structure

### Core Files
- `Scripts/Core/LogEntry.gd` - LogEntry class definition
- `Scripts/Managers/statistics_manager.gd` - Enhanced with logbook
- `Scripts/UI/score_card_ui.gd` - ExtraInfo integration
- `Scripts/UI/logbook_panel.gd` - Full logbook viewer (future)

### Data Files
- Session logs can be saved to `user://logs/` for persistence
- Export format: JSON for external analysis tools

## Integration Points

### Current Integrations
1. **ScoreCard System**: Call `Statistics.log_hand_scored()` after each scoring
2. **ExtraInfo Label**: Display recent entries with animations
3. **Statistics Panel**: Summary view of scoring patterns

### Future Integrations
4. **PowerUp System**: Register effects in real-time
5. **Consumable System**: Track one-time usage impacts
6. **Mod System**: Record permanent modifications
7. **Challenge System**: Log challenge completion effects
8. **Debuff System**: Track negative effects and their sources

## Extension Plan

### Phase 1: Basic Logging (Current)
- Core LogEntry structure
- Simple hand tracking
- ExtraInfo display integration

### Phase 2: Modifier Tracking
- PowerUp effect integration
- Consumable usage tracking
- Basic calculation chains

### Phase 3: Advanced Analytics
- Dedicated logbook viewer UI
- Filtering and search capabilities
- Performance analysis tools

### Phase 4: Debug Features
- Real-time calculation display
- Interactive log exploration
- Export/import functionality

## Configuration Options

### Settings (via Statistics Manager)
```gdscript
var max_logbook_entries: int = 1000     # Memory management
var show_detailed_logs: bool = true     # UI verbosity
var auto_clear_extrainfo: bool = true   # Clear old messages
var extrainfo_display_count: int = 3    # Number of recent logs shown
var save_logs_to_file: bool = false     # Persistence option
```

## Usage Examples

### Basic Logging Call
```gdscript
# In scorecard scoring method
Statistics.log_hand_scored(
	dice_hand.get_values(),
	dice_hand.get_colors(),
	dice_hand.get_mods(),
	"three_of_a_kind",
	"lower",
	active_consumables,
	active_powerups,
	base_calculation,
	effect_chain,
	final_score
)
```

### ExtraInfo Update
```gdscript
# In score_card_ui.gd
func _on_hand_scored():
	var recent_logs = Statistics.get_recent_log_entries(3)
	var display_text = ""
	for log in recent_logs:
		display_text += log.formatted_log_line + "\n"
	update_extra_info(display_text)
```

## Benefits

### For Players
- Understand exactly how scores are calculated
- Learn optimal strategies from scoring patterns
- Verify game fairness and consistency

### For Developers
- Debug complex modifier interactions
- Balance PowerUps and items based on usage data
- Identify and fix scoring edge cases
- Analyze player behavior patterns

### For Testing
- Automated verification of scoring correctness
- Regression testing for scoring changes
- Performance analysis of calculation chains
- Edge case discovery and documentation

## Future Enhancements

### Advanced Analytics
- Scoring efficiency metrics per modifier combination
- Optimal strategy recommendations based on historical data
- Pattern recognition for scoring opportunities
- Machine learning integration for game balance

### Integration Features
- Real-time overlay during gameplay (debug mode)
- Integration with external analytics tools
- Cloud-based log aggregation for population analysis
- A/B testing framework for scoring modifications

## Implementation Notes

### Performance Considerations
- Use ring buffer for memory management
- Lazy evaluation of formatted strings
- Optional detailed logging in release builds
- Efficient filtering and search algorithms

### Compatibility
- Maintain backwards compatibility with existing Statistics API
- Graceful degradation if logbook features are disabled
- Modular design for easy feature toggling
- Version migration support for saved logs

### Testing Strategy
- Unit tests for LogEntry creation and formatting
- Integration tests with scoring system
- Performance tests for large logbooks
- UI tests for ExtraInfo display accuracy