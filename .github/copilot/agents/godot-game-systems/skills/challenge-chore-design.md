---
skillName: Challenge & Chore Design
agentId: godot-game-systems
activationKeywords:
  - challenge
  - chore
  - goal
  - objective
  - difficulty
  - progression
  - unlock_condition
  - goal_tracking
filePatterns:
  - Scripts/Challenge/*.gd
  - Scripts/Managers/ChoresManager.gd
examplePrompts:
  - Design a Challenge for difficulty level 7
  - Create a goal tracking system for [mechanic]
  - How do challenges integrate with scoring?
  - Design 3 challenges that scale in difficulty
---

# Skill: Challenge & Chore Design

## Purpose
Design, implement, and balance Challenges and Chores in DiceRogue. Challenges are round-based goals (e.g., "Score 300 points"). Chores are internal progression tasks (e.g., "Unlock 10 PowerUps"). Both systems track progress and integrate with GameController.

## When to Use
- Creating new Challenge goals for a difficulty level
- Designing Chore progression tasks
- Debugging goal tracking or completion detection
- Balancing difficulty (1-10 scale)
- Integrating challenge with scoring/economy systems
- Creating conditional goals (if player has certain items, different goal)

## Inputs
- Goal type (score points, get yahtzee, use items, etc.)
- Difficulty rating (1-10)
- Goal value/target
- Optional: unlock progression, stat tracking

## Outputs
- Complete Challenge class with progress tracking
- Goal completion detection logic
- Integration with GameController
- Difficulty balancing notes
- Test cases for validation

## Behavior
- Follow Challenge base class pattern
- Implement progress tracking (0% → 100% → complete)
- Emit signals for UI updates
- Map to statistics for progression tracking
- Handle edge cases (impossible goals, negative progress)
- Provide difficulty tuning guidance

## Constraints
- Must extend Challenge base class
- Must implement check_progress() method
- Difficulty scale 1-10 (1=easy unlock, 10=legendary)
- Signals: challenge_started, challenge_updated, challenge_completed
- Do not couple tightly to specific items/systems

## DiceRogue Challenge System

### Challenge Base Class
```gdscript
extends Node
class_name Challenge

@export var challenge_id: String = ""
@export var description: String = ""
@export var goal_type: String = ""  # "score_points", "get_yahtzee", etc.
@export var goal_value: int = 0
@export var difficulty: int = 1  # 1-10 scale

var progress: int = 0
signal challenge_started
signal challenge_updated(progress, goal_value)
signal challenge_completed

func start() -> void:
    challenge_started.emit()

func check_progress() -> bool:
    # Return true if goal is complete
    return false

func update_progress(new_progress: int) -> void:
    progress = new_progress
    challenge_updated.emit(progress, goal_value)
    if check_progress():
        complete()

func complete() -> void:
    challenge_completed.emit()
```

### Challenge Types

**Score-Based**:
```gdscript
extends Challenge
class_name ScorePointsChallenge

func check_progress() -> bool:
    # Check current round score
    return current_score >= goal_value
```

**Yahtzee-Based**:
```gdscript
extends Challenge
class_name GetYahtzeesChallenge

func check_progress() -> bool:
    # Count Yahtzees in scorecard
    return yahtzee_count >= goal_value
```

**Item-Based**:
```gdscript
extends Challenge
class_name UsePowerUpsChallenge

func check_progress() -> bool:
    # Count active PowerUps
    return active_powerup_count >= goal_value
```

### Difficulty Balancing

**Score-Based Challenges** (1-10 scale):
- Difficulty 1: 100 points
- Difficulty 3: 250 points
- Difficulty 5: 500 points
- Difficulty 7: 1000 points
- Difficulty 10: 2500+ points

**Yahtzee-Based Challenges**:
- Difficulty 1: 1 Yahtzee
- Difficulty 3: 2 Yahtzees
- Difficulty 5: 3 Yahtzees
- Difficulty 7: 4 Yahtzees
- Difficulty 10: 5+ Yahtzees

**Item-Based Challenges**:
- Difficulty 1: Use 1 item
- Difficulty 5: Use 5 items
- Difficulty 10: Use 15 items

### Chore System

Chores are internal progression tasks tracked separately:

```gdscript
extends Node
class_name Chore

@export var chore_id: String = ""
@export var description: String = ""

func check_completion(stats: Statistics) -> bool:
    # Check if chore is complete based on statistics
    return false

func get_reward() -> int:
    # Return progression points or unlock reward
    return 0
```

**Common Chores**:
- "Unlock 10 PowerUps"
- "Complete 5 runs"
- "Score 10,000 total points"
- "Get 3 Yahtzees"

## Example Prompt
"Create a Challenge for difficulty 6 that tracks: 'Score 750 points in one round'"

## Example Output
```gdscript
extends Challenge
class_name Score750Challenge

@export var description: String = "Score 750 points in one round"
@export var goal_value: int = 750
@export var difficulty: int = 6

func check_progress() -> bool:
    var current_score = game_controller.scorecard.current_round_score
    return current_score >= goal_value
```

Balancing notes:
- Difficulty 6 = uncommon (750 pts is moderate challenge)
- Compare to difficulty 5 (500 pts) and 7 (1000 pts)
- Player needs good dice rolls or synergistic PowerUps
- Test with bot to verify achievability
