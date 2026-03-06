---
skillName: Resource & Data Creation
agentId: godot-data-resources
activationKeywords:
  - resource
  - data
  - create_resource
  - tres
  - export
  - typed_resource
  - data_structure
filePatterns:
  - Resources/Data/**/*.gd
  - Resources/Data/**/*.tres
examplePrompts:
  - Create a Resource class for [item type]
  - Generate .tres files for these items
  - How should I structure this data as a Resource?
  - Create an editor-friendly Resource inspector
---

# Skill: Resource & Data Creation

## Purpose
Create typed Resource classes and .tres files for DiceRogue's data-driven systems. Provides templates for PowerUp, Consumable, Challenge, Debuff, and custom Resource types with proper @export properties and editor visibility. **CRITICAL: Always create UnlockCondition Resources when creating game items.**

## When to Use
- Creating a new Resource class for game data
- Generating .tres (Resource) files from template
- Needing editor-friendly property exposure
- Designing data structure for new item type
- Creating custom Resource metadata (icons, descriptions, etc.)
- **MANDATORY**: Creating UnlockCondition Resources for item unlock setup
- Setting up Resource serialization and caching

## Inputs
- Resource type (PowerUp, Consumable, Challenge, Debuff, Custom)
- Properties needed (@export vars with types)
- Default values
- Optional: Icon/metadata requirements

## Outputs
- Complete GDScript Resource class (extends Resource, class_name)
- Example .tres file with default properties
- Editor property documentation
- Integration guide with game systems
- Examples of loading and accessing Resource

## Behavior
- Create typed Resource classes (not generic dictionaries)
- Expose properties as @export for inspector editing
- Use clear, descriptive property names (snake_case)
- Provide sensible defaults
- Include validation hints where applicable
- Support both editor and code creation

## Constraints
- Always use class_name after extends Resource
- All game data must be in Resources/Data/ directory
- Use @export for all inspectable properties
- Follow DiceRogue naming conventions exactly
- Ensure Resources serialize/deserialize correctly

## DiceRogue Resource Patterns

### PowerUp Resource
```gdscript
extends Resource
class_name PowerUpData

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: int = 1  # 1-10 scale
@export var unlock_condition: String = ""  # stat key
@export var unlock_value: int = 0  # value to reach
@export var icon_path: String = ""
```

### Consumable Resource
```gdscript
extends Resource
class_name ConsumableData

@export var id: String = ""
@export var display_name: String = ""
@export var effect_type: String = ""  # "score_bonus", "reroll", etc.
@export var effect_value: int = 0
@export var description: String = ""
@export var rarity: int = 1
```

### Challenge Resource
```gdscript
extends Resource
class_name ChallengeData

@export var id: String = ""
@export var description: String = ""
@export var goal_type: String = ""  # "score_points", "get_yahtzee"
@export var goal_value: int = 0
@export var difficulty: int = 1  # 1-10 scale
```

### Custom Data Resource
```gdscript
extends Resource
class_name [CustomTypeName]Data

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
# ... custom properties
```

### Directory Structure
```
Resources/
  Data/
    PowerUps/
      double_dice.tres
      bonus_points.tres
      ...
    Consumables/
      score_boost.tres
      extra_reroll.tres
      ...
    Challenges/
      score_750.tres
      three_yahtzees.tres
      ...
    Debuffs/
      ...
```

### Resource File Format (.tres)
```ini
[gd_resource type="PowerUpData" script_class="PowerUpData" load_steps=1 format=3]

[resource]
id = "double_dice"
display_name = "Double Dice"
description = "Roll all dice twice, pick better result"
rarity = 3
unlock_condition = "total_points_scored"
unlock_value = 5000
icon_path = "res://Resources/UI/Icons/double_dice.png"
```

### Loading Resources in Code
```gdscript
# Preload approach (used in managers)
const POWER_UP_DOUBLE_DICE = preload("res://Resources/Data/PowerUps/double_dice.tres")

# Dynamic loading approach
var resource = load("res://Resources/Data/PowerUps/double_dice.tres")
if resource:
    var powerup_data: PowerUpData = resource
    print(powerup_data.display_name)
```

## Editor Best Practices

### Property Hints
```gdscript
@export var id: String = ""  # Plain string
@export var rarity: int = 1  # Could add hint: slider 1 10
@export var enabled: bool = true  # Checkbox
@export var category: String = "basic":
    set(value):
        category = value  # Allow dropdown enum
@export var icon: Texture2D = null  # Texture picker
@export var effects: Array = []  # Array of effects
```

### Custom Icons
Store 16x16 PNG icons in `Resources/UI/Icons/` matching Resource ID:
- `Resources/UI/Icons/double_dice.png`
- `Resources/UI/Icons/score_boost.png`

## Example Prompt
"Create a Resource class for a new Mod item type with properties: id, name, description, effect, difficulty"

## Example Output
```gdscript
extends Resource
class_name ModData

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var effect_type: String = ""
@export var difficulty: int = 1
```

Plus: Example .tres file ready to be saved
Plus: Integration guide showing how to load and use
