---
skillName: Item System Scaffolding
agentId: godot-code-generation
activationKeywords:
  - scaffold
  - template
  - boilerplate
  - generate_item
  - bulk
  - create_powerup
  - create_consumable
filePatterns:
  - Scripts/PowerUps/*.gd
  - Scripts/Core/unlockable_item.gd
  - Scripts/Consumable/*.gd
  - Scripts/Challenge/*.gd
examplePrompts:
  - Generate boilerplate for a new PowerUp [name]
  - Create template for Consumable with [effect]
  - Scaffold Challenge that [goal]
  - Generate 5 PowerUps from this list
---

# Skill: Item System Scaffolding

## Purpose
Accelerate item creation through automated scaffolding. Generates boilerplate code for PowerUps, Consumables, Challenges, and Debuffs following DiceRogue patterns, reducing creation time from 30 min to 2 min per item. **CRITICAL: All generated items must include unlock system registration setup.**

## When to Use
- Creating new PowerUp/Consumable/Challenge/Debuff
- Bulk-creating items from design document
- Onboarding new team member (teach structure through examples)
- Refactoring existing items to match standard pattern
- **MANDATORY STEP**: Ensure each item integrates with unlock system
- Migrating legacy code to class_name pattern

## Inputs
- Item type (PowerUp, Consumable, Challenge, Debuff)
- Item name and display properties
- Core effect/behavior description
- Optional: Difficulty rating (1-10)
- Optional: Unlock conditions

## Outputs
- Complete GDScript class file (.gd) with boilerplate
- Example .tres resource file structure
- Integration instructions
- Registration in appropriate manager

## Behavior
- Generate proper class structure (extends, class_name, @export)
- Include proper signal declarations
- Add method stubs for key functions
- Provide inline documentation
- Include setup steps for game-specific registration
- Follow DiceRogue coding standards exactly

## Constraints
- Must follow exact Godot 4.4 syntax
- No placeholder code that won't compile
- Must include all required methods for item type
- class_name mandatory (except autoloads)
- @export/@onready required for properties
- No ternary operators (use if/else)

## DiceRogue Item Structure

### PowerUp Template
```gdscript
extends UnlockableItem
class_name [ItemName]PowerUp

## Brief description of what this PowerUp does
##
## Effect: [describe effect clearly]
## Rarity: [common|rare|epic|legendary]
## Synergies: [any known combos with other items]

@export var effect_magnitude: int = 10:
	get:
		return effect_magnitude

func _ready() -> void:
	super()
	item_name = "[Readable Name]"
	item_description = "Brief description"
	difficulty_rating = 3

## Activate this PowerUp's effect during gameplay
##
## Notes: Apply effect to game state when activated
func apply_effect() -> void:
	pass

## Get the score modification this PowerUp provides
func get_score_modifier() -> int:
	return effect_magnitude

## Check if this PowerUp can be used right now
func can_activate() -> bool:
	return is_active
```

### Consumable Template
```gdscript
extends UnlockableItem
class_name [ItemName]Consumable

## One-time use item with [effect]
##
## Effect: [describe effect]
## Usage: Single use, consumed after activation
## Cooldown: [if any]

@export var effect_radius: int = 1

func _ready() -> void:
	super()
	item_name = "[Readable Name]"
	item_description = "One-time effect"
	is_single_use = true

## Activate this Consumable's effect
##
## Notes: Called when player uses this item
func activate(target: Node = null) -> void:
	apply_effect(target)
	remove_from_inventory()

## Apply the primary effect
func apply_effect(target: Node) -> void:
	pass

## Check if this Consumable can be used right now
func can_use() -> bool:
	return not is_consumed
```

### Challenge Template
```gdscript
extends UnlockableItem
class_name [ChallengeName]Challenge

## Complete [goal description] to pass this Challenge
##
## Goal: [specific objective]
## Difficulty: [1-10]
## Reward: [points/items/unlocks]

@export var target_value: int = 10

func _ready() -> void:
	super()
	item_name = "[Readable Challenge Name]"
	item_description = "[Goal] to earn [reward]"
	difficulty_rating = 5

## Initialize challenge state
func initialize() -> void:
	progress = 0
	is_active = true

## Track progress toward challenge goal
##
## Called each turn/event that could affect progress
func update_progress(event_data: Dictionary) -> void:
	if event_data.has("target_metric"):
		progress += event_data["target_metric"]

## Check if challenge goal is met
func is_completed() -> bool:
	return progress >= target_value

## Get current progress percentage
func get_progress_percent() -> float:
	return float(progress) / float(target_value) * 100.0
```

### Debuff Template
```gdscript
extends UnlockableItem
class_name [DebuffName]Debuff

## Negative effect: [describe debuff]
##
## Effect: [describe impact]
## Duration: [permanent|turns|conditional]
## Mitigation: [how player can counteract]

@export var penalty_magnitude: int = -5

func _ready() -> void:
	super()
	item_name = "[Readable Debuff Name]"
	item_description = "[Negative effect description]"
	difficulty_rating = 7  # Higher = worse debuff

## Apply debuff to player
func apply_debuff() -> void:
	pass

## Calculate penalty modifier
func get_penalty() -> int:
	return penalty_magnitude

## Check if debuff is still active
func is_active() -> bool:
	return true
```

### Registration Pattern - THREE STEPS REQUIRED

**Step 1: Register in Manager Preloads**

All items must be registered in their manager:

```gdscript
# PowerUpManager
const POWERUP_PRELOADS = {
	"dice_doubler": preload("res://Scripts/PowerUps/DiceDoubler.gd"),
	# ...
}

# ConsumableManager
const CONSUMABLE_PRELOADS = {
	"quick_cash_consumable": preload("res://Scripts/Consumable/QuickCashConsumable.gd"),
	# ...
}

# Add to appropriate manager's get_item(name: String) method:
if POWERUP_PRELOADS.has(name):
	return POWERUP_PRELOADS[name].new()
```

**Step 2: Create UnlockCondition Resource** (CRITICAL!)

Create `Resources/Data/PowerUps/DiceDoubler.tres`:
```gdscript
[gd_resource type="UnlockableItem" script_class="UnlockableItem"]
id = "dice_doubler"
item_type = 0  # POWER_UP
display_name = "Dice Doubler"
description = "Doubles die values after each roll"
difficulty_rating = 4

[sub_resource type="UnlockCondition" id="1"]
condition_type = 0  # SCORE_POINTS
target_value = 200

[resource]
unlock_condition = SubResource("1")
```

**Step 3: Verify Unlock Integration**
- Item loads with UnlockCondition
- Item appears in shop (if applicable)
- Unlock triggers when condition met
- Test with `/debug add_item [item_id]`

**Checklist**:
- [ ] Item class created and added to manager preloads
- [ ] UnlockCondition Resource created with valid unlock_condition
- [ ] Item ID matches in both .gd and .tres files
- [ ] Unlock condition type is appropriate (SCORE_POINTS, YAHTZEE, etc.)
- [ ] Item tested to verify unlock system integration

## Example Prompt
"Generate scaffolding for a PowerUp called 'DiceDoubler' that doubles the next dice roll value"

## Example Output

**File**: `Scripts/PowerUps/DiceDoubler.gd`
```gdscript
extends UnlockableItem
class_name DiceDoublerPowerUp

## Doubles the result of the next dice roll
##
## Effect: Next die roll value is doubled (1→2, 6→12)
## Rarity: Rare
## Synergies: Pairs well with High Roller (multiplies multiplied dice twice)

@export var multiplier: int = 2

func _ready() -> void:
	super()
	item_name = "Dice Doubler"
	item_description = "Next roll is doubled"
	difficulty_rating = 4

func apply_effect() -> void:
	# Connect to next throw event
	pass

func get_score_modifier() -> int:
	return multiplier

func can_activate() -> bool:
	return is_active
```

**Registration Instructions**:
1. Add to `PowerUpManager.gd` preloads:
   ```gdscript
   "dice_doubler": preload("res://Scripts/PowerUps/DiceDoubler.gd"),
   ```
2. Run game and test with `/debug add_powerup dice_doubler`
3. Add to shop prices in `ShopManager.gd`

**Time saved**: 28 minutes (30 min manual → 2 min with scaffold)
