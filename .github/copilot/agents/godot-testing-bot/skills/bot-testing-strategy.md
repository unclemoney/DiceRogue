---
skillName: Bot Testing & Strategy
agentId: godot-testing-bot
activationKeywords:
  - bot
  - strategy
  - ai
  - decision
  - heuristic
  - scoring_strategy
  - bot_logic
filePatterns:
  - Scripts/Bot/bot_strategy.gd
  - Scripts/Bot/bot_controller.gd
  - Tests/BotTest.tscn
examplePrompts:
  - Design a bot strategy that prioritizes [goal]
  - How do bots decide which category to score?
  - Create a bot that uses PowerUps strategically
  - Analyze bot performance on [mechanic]
---

# Skill: Bot Testing & Strategy

## Purpose
Design and implement bot decision-making strategies for DiceRogue. Covers bot heuristics for dice selection, category scoring, item usage, and strategic planning. Enables comprehensive game testing through automated AI opponents.

## When to Use
- Designing a new bot strategy (aggressive, conservative, balanced, etc.)
- Debugging bot decision quality
- Measuring bot performance on new mechanics
- Creating performance baseline for new features
- Tuning bot difficulty or playstyle
- Analyzing bot decision logs

## Inputs
- Strategy type/playstyle (aggressive, conservative, balanced, synergy, adaptive)
- Priority metrics (maximize points, minimize risk, combo efficiency)
- Optional: Specific mechanics bot should exploit
- Optional: Performance baseline to compare against

## Outputs
- Bot strategy GDScript with decision heuristics
- Performance baseline with metrics
- Decision logging for analysis
- Playstyle documentation
- Integration with BotController

## Behavior
- Implement clear, transparent decision heuristics
- Log decision rationale for debugging
- Measure performance (score, runs, decisions)
- Support multiple strategies running in parallel
- Enable comparative analysis between strategies
- Provide metrics for bot quality assessment

## Constraints
- Strategies must use available game information (no cheating)
- Decisions must be O(1) or O(n) complexity (not brute-force search)
- Each strategy has consistent personality
- Logging must not impact performance significantly
- Strategies should be transferable across different dice rolls

## DiceRogue Bot System

### Bot Architecture

**BotController** (`Scripts/Bot/bot_controller.gd`):
- Main orchestrator
- Manages game state, turns, decisions
- Integrates with GameController
- Collects performance metrics

**BotStrategy** (`Scripts/Bot/bot_strategy.gd`):
- Decision-making logic
- Heuristic implementation
- Score calculation for options

**BotLogger** (`Scripts/Bot/bot_logger.gd`):
- Records decisions
- Tracks game progression
- Generates reports

**BotReportWriter** (`Scripts/Bot/bot_report_writer.gd`):
- HTML/text report generation
- Performance statistics
- Decision analysis

### Strategy Types

**Aggressive** 🔥:
- Maximize points every turn
- Reroll to achieve high-value categories
- Use PowerUps for score multiplication
- Consume immediately for bonus points

**Conservative** 🛡️:
- Minimize risk; guarantee scores
- Clear easy categories first
- Save PowerUps for critical turns
- Focus on consistency over max points

**Balanced** ⚖️:
- Mix aggressive scoring with category clearing
- Use PowerUps when synergy is clear
- Reroll selectively (50/50 risk tolerance)
- Adapt based on current score

**Synergy-Focused** 🧩:
- Chain PowerUps and Consumables
- Use combo unlocks (X + Y effect)
- Sequence purchases strategically
- Maximize item interactions

**Adaptive** 🎯:
- Adjust strategy based on game state
- Switch to aggressive when behind
- Switch to conservative when ahead
- Learn from previous rolls

### Bot Decision Heuristics

**Category Selection**:
```gdscript
func get_best_category(dice_values: Array) -> String:
    var options = score_evaluator.get_all_possible_scores(dice_values)
    
    match strategy_type:
        "aggressive":
            # Pick highest-value category
            return options.max_by(func(score): return score)
        "conservative":
            # Pick guaranteed score (even if low)
            return options.values().min()
        "balanced":
            # Pick above-average category
            var avg = options.values().reduce(func(a, b): return a + b) / options.size()
            return options.filter(func(score): return score >= avg * 0.8).max()
    
    return ""
```

**Reroll Decision**:
```gdscript
func should_reroll(dice_values: Array, rolls_left: int) -> bool:
    var best_score = score_evaluator.get_best_score(dice_values)
    var expected_value = best_score / (rolls_left + 1)
    
    match strategy_type:
        "aggressive":
            # Reroll if expected value is higher
            return expected_value > best_score * 0.7
        "conservative":
            # Only reroll if severely bad  
            return best_score < 15
```

**PowerUp Usage**:
```gdscript
func should_use_power_up(active_powerups: Array, current_score: int) -> bool:
    match strategy_type:
        "aggressive":
            # Use immediately for bonus
            return true
        "conservative":
            # Save for critical moment
            return current_score < 100
        "synergy":
            # Use if synergy detected
            return power_up.has_synergy_with(other_active_powerups)
```

### Performance Metrics

Bot tracks:
- **Total Score**: Final score achieved
- **Average Category Score**: Quality of decisions
- **Reroll Efficiency**: How many rerolls → points
- **PowerUp Synergy**: How well items worked together
- **Decision Quality**: How many optimal vs suboptimal choices
- **Run Completion**: Runs completed / Started

### Bot Logging Pattern

```gdscript
extends Node
class_name BotLogger

var decisions: Array = []
var metrics: Dictionary = {}

func log_decision(turn: int, decision: String, rationale: String, value: int) -> void:
    decisions.append({
        "turn": turn,
        "decision": decision,
        "rationale": rationale,
        "value": value,
        "timestamp": Time.get_ticks_msec()
    })

func generate_report() -> String:
    # Create HTML/text report
    pass
```

## Example Prompt
"Design a 'Synergy-Focused' bot strategy that chains PowerUps for maximum effect"

## Example Output
```gdscript
extends Node
class_name SynergyBot

var active_powerups: Array = []
var strategy_type = "synergy"

func select_category(options: Dictionary) -> String:
    # Find category that synergizes with active PowerUps
    for category in options:
        if has_synergy(category, active_powerups):
            return category
    # Fallback to aggressive
    return options.max_by(func(score): return score)

func select_powerup_to_use(available: Array) -> PowerUp:
    # Choose PowerUp that combos with active ones
    for powerup in available:
        if powerup.synergizes_with(active_powerups):
            return powerup
    return available[0]
```

Performance baseline: Bot achieves X avg score across 100 runs
