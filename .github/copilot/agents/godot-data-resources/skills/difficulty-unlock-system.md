---
skillName: Difficulty & Unlock System
agentId: godot-data-resources
activationKeywords:
  - difficulty
  - unlock
  - progression
  - unlock_condition
  - statistics
  - rarity
  - progression_system
  - unlock_mapping
filePatterns:
  - Scripts/Core/unlockable_item.gd
  - Resources/Data/**/*.gd
  - Scripts/Managers/ChoresManager.gd
examplePrompts:
  - Design unlock conditions for [item]
  - Map difficulty ratings across items
  - How do unlock conditions integrate with statistics?
  - Create progression tiers for difficulty 1-10
---

# Skill: Difficulty & Unlock System

## Purpose
Design and implement DiceRogue's difficulty/rarity system (1-10 scale) and unlock conditions. Maps game items to progression gates, statistics tracking, and conditional unlocks. Ensures balanced item availability and player progression. **CRITICAL: Every item MUST have an unlock condition—no exceptions.**

## When to Use
- Setting difficulty rating for new item
- Designing unlock condition (stat-based, chapter-based, item-based) - ALWAYS required
- Mapping items to Statistics tracking system
- Balancing progression pacing
- Creating conditional unlocks (if player has certain items, unlock new item)
- Validating unlock conditions are achievable and not impossible
- **MANDATORY**: Before any item is released, it needs unlock system integration

## Inputs
- Item name and type
- Desired difficulty rating (1-10)
- Unlock condition type (stat-based, chapter, item-based, etc.)
- Optional: unlock value/threshold
- Optional: prerequisite items

## Outputs
- Difficulty rating with rationale
- Unlock condition mapped to Statistics key
- UnlockableItem setup code
- Statistics integration
- Balance analysis vs similar items

## Behavior
- Follow 1-10 difficulty scale consistently
- Map unlock conditions to existing Statistics keys
- Handle progression pacing (not too easy, not impossible)
- Support conditional unlocks (if X use Y, unlock Z)
- Validate unlock conditions are achievable in gameplay
- Provide balance recommendations

## Constraints
- Difficulty scale 1-10 (1=common/easy, 10=legendary/hard)
- Unlock conditions must map to Statistics.gd keys
- Unlock values must be achievable through normal play
- Cannot create impossible unlock conditions
- Must balance progression across all items

## DiceRogue Difficulty & Unlock System

### Difficulty Scale
```
1-2:  Common      (Easy unlock, early game)
3-5:  Uncommon    (Normal progression, mid-game)
6-8:  Rare        (Challenging, late-game)
9-10: Legendary   (Very hard, end-game only)
```

### Unlock Condition Types

**1. Stat-Based** (most common):
- Unlock when player reaches stat threshold
- Examples: total_points_scored, runs_completed, yahtzees_obtained

**2. Chapter-Based**:
- Unlock after progressing through game
- Examples: After 5 runs, after reaching level 3

**3. Item-Based**:
- Unlock after using another item N times
- Examples: Use PowerUp X 10 times, use Consumable Y 5 times

**4. Challenge-Based**:
- Unlock after completing specific challenge
- Examples: Get 3 Yahtzees, score 5000 in one round

### UnlockableItem Class
```gdscript
extends Resource
class_name UnlockableItem

@export var item_id: String = ""
@export var item_type: String = ""  # "powerup", "consumable", etc.
@export var difficulty: int = 1  # 1-10 scale
@export var is_locked: bool = true
@export var unlock_condition: String = ""  # stat key or custom condition

func check_unlock(stats: Statistics) -> bool:
    # Return true if unlock condition is met
    match unlock_condition:
        "total_points_scored":
            return stats.total_points_scored >= 5000
        "runs_completed":
            return stats.runs_completed >= 10
        "yahtzees_obtained":
            return stats.yahtzees_obtained >= 5
    return false
```

### Statistics Integration

Statistics.gd tracks:
```gdscript
var total_points_scored: int = 0
var runs_completed: int = 0
var challenges_completed: int = 0
var yahtzees_obtained: int = 0
var power_ups_used: Dictionary = {}  # { id: count }
var consumables_used: Dictionary = {}  # { id: count }
var items_collected: Dictionary = {}  # { id: count }
```

### Progression Pacing

**Difficulty Distribution Example**:
```
125 PowerUps:
  Difficulty 1-2:  20 items (early access)
  Difficulty 3-5:  50 items (main progression)
  Difficulty 6-8:  40 items (late game)
  Difficulty 9-10: 15 items (legendary)
```

**Unlock Timeline** (Example):
- Hour 0: Start with 5 difficulty 1-2 items
- Hour 1: Unlock difficulty 3-5 items (score 2000 pts)
- Hour 3: Unlock difficulty 6-8 items (complete 5 runs)
- Hour 5: Legendary items available (complete challenges, use items 50+ times)

### Common Statistics Keys

For unlock mapping:

| Statistic | Scale | Unlock Gate |
|-----------|-------|-------------|
| total_points_scored | 0+ | Every 2500 pts → unlock tier |
| runs_completed | 0+ | Every 5 runs → unlock tier |
| yahtzees_obtained | 0+ | Every 3 yahtzees → unlock tier |
| [item]_used_count | 0+ | Use item X times to unlock Y |
| challenges_completed | 0+ | Every 10 challenges → unlock tier |
| playtime_seconds | 0+ | Playtime-gated items |

## Example Prompt
"This PowerUp has difficulty 5. Map it to an unlock condition that makes sense."

## Example Output
```gdscript
extends Resource
class_name DoubleYahtzeeUnlock

var difficulty: int = 5
var unlock_condition: String = "total_points_scored"
var unlock_value: int = 7500  # Need 7500 points total

# Rationale:
# - Difficulty 5 (uncommon/mid-game)
# - Requires solid player skill (7500 pts)
# - Achievable in 3-5 runs with decent rolls
# - Compares to other difficulty 5 items: score_boost (5000), etc.
# - Not too easy (would break balance), not impossible
```

Balance validation:
- Similar items at difficulty 5 unlock around 5000-10000 points
- This at 7500 is moderate within tier
- Player can achieve in normal play (not grinding required)
