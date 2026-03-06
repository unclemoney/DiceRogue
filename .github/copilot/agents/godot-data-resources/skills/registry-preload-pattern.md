---
skillName: Registry Pattern & Preloads
agentId: godot-data-resources
activationKeywords:
  - registry
  - preload
  - manager
  - lookup
  - dependency
  - organization
  - preload_registry
  - bulk_preload
filePatterns:
  - Scripts/Managers/*.gd
  - Scripts/Game/game_controller.gd
  - Scripts/PowerUps/*.gd
examplePrompts:
  - Organize preloads for [manager]
  - Generate preload registry for 20 items
  - How do I bulk-load items efficiently?
  - Detect circular dependencies in preloads
---

# Skill: Registry Pattern & Preloads

## Purpose
Organize and manage preload registries in DiceRogue managers. Handles bulk preload organization, dependency mapping, circular dependency detection, and performance optimization for item lookup.

## When to Use
- Organizing preloads for a new manager (30-50+ items)
- Adding new items to existing registry
- Optimizing preload lookup performance
- Detecting circular dependencies between managers
- Bulk organizing preloads by category
- Setting up automatic item registry updates

## Inputs
- Manager class needing preload organization
- List of items to preload
- Lookup access patterns (how items are accessed)
- Optional: Dependency constraints

## Outputs
- Organized preload registry (categorized by type)
- Manager lookup methods (get_item, get_all, filter)
- Performance analysis and optimization
- Circular dependency check results
- Integration guide

## Behavior
- Follow DiceRogue preload pattern exactly
- Organize by category/subdirectory for clarity
- Provide O(1) lookup via dictionary access
- Detect circular dependencies automatically
- Suggest optimization for large registries
- Document access patterns and performance

## Constraints
- All preloads at top of file (before class definitions)
- Must use snake_case_keys for dictionary lookups
- Cannot create circular preload dependencies
- Performance: 30-50 preloads = negligible load time
- Keep registry small enough for hot reloads

## DiceRogue Preload Registry Pattern

### Current Pattern (25+ files)
```gdscript
extends Node
class_name PowerUpManager

# 125+ PowerUp preloads organized alphabetically
const POWER_UPS = {
    "bonus_points": preload("res://Scripts/PowerUps/bonus_points.gd"),
    "double_dice": preload("res://Scripts/PowerUps/double_dice.gd"),
    "extra_roll": preload("res://Scripts/PowerUps/extra_roll.gd"),
    # ... 122 more
}

func get_power_up(id: String) -> PowerUp:
    return POWER_UPS.get(id)

func get_all_power_ups() -> Array:
    return POWER_UPS.values()
```

### Improved Pattern (Organized by Category)
```gdscript
extends Node
class_name PowerUpManager

# Utility: Lookup by category at index speed
const POWER_UPS_BY_CATEGORY = {
    "dice_mods": {
        "double_dice": preload("res://Scripts/PowerUps/double_dice.gd"),
        "lock_dice": preload("res://Scripts/PowerUps/lock_dice.gd"),
    },
    "scoring_bonuses": {
        "bonus_points": preload("res://Scripts/PowerUps/bonus_points.gd"),
        "category_bonus": preload("res://Scripts/PowerUps/category_bonus.gd"),
    },
    "economy_effects": {
        "money_boost": preload("res://Scripts/PowerUps/money_boost.gd"),
        "shop_discount": preload("res://Scripts/PowerUps/shop_discount.gd"),
    },
}

# Flat registry for quick access
const POWER_UPS = {}

func _init():
    # Build flat registry from categorized preloads
    for category in POWER_UPS_BY_CATEGORY:
        for item_id in POWER_UPS_BY_CATEGORY[category]:
            POWER_UPS[item_id] = POWER_UPS_BY_CATEGORY[category][item_id]

func get_power_up(id: String) -> PowerUp:
    return POWER_UPS.get(id)

func get_by_category(category: String) -> Array:
    return POWER_UPS_BY_CATEGORY.get(category, {}).values()
```

### Manager Structure

**GameController** (50+ preloads):
- Links to all managers
- Central node lookup registry
- Signal connection setup

**PowerUpManager** (125+ preloads):
- All PowerUp classes
- Fast lookup by ID

**ConsumableManager** (45+ preloads):
- All Consumable classes
- Effect type grouping

**ChallengeManager** (20+ preloads):
- All Challenge classes
- Difficulty categorization

**DebuffManager** (variable count):
- All Debuff classes
- Effect type grouping

### Dependencies & Ordering

**Initialization Order** (important for circular dep prevention):
1. Core systems load (Dice, Score)
2. Managers load (register items)
3. GameController initializes (wires everything)
4. Scenes load (reference managers)

**Avoid Circular References**:
- Items should NOT preload managers
- Managers can reference items they manage
- GameController can reference all managers
- Scenes can reference GameController

### Dependency Graph Visualization

```
GameController
├── PowerUpManager
│   ├── bonus_points.gd
│   ├── double_dice.gd
│   └── ... (125 more)
├── ConsumableManager
│   ├── score_boost.gd
│   ├── extra_reroll.gd
│   └── ... (45 more)
├── DiceColorManager
└── ScoreEvaluator
```

**Good** ✓: Downward dependencies (managers → items)  
**Bad** ✗: Upward dependencies (items → managers)  
**Broken** ✗: Circular (A → B → A)  

## Optimization Tips

### For Large Registries (50+ items)
- Group by category (reduces search mental load)
- Use _init() to build derived lookups
- Consider lazy loading if registry is huge
- Profile load time (should be <10ms)

### For Dynamic Item Addition
- Support late registration: `registry["new_id"] = class`
- Reload registry without restarting
- Update derived lookups (by_category, etc.)

## Example Prompt
"Organize 50 preloads in PowerUpManager by category (dice_mods, scoring, economy)"

## Example Output
Organized preload registry grouped by effect type, with flat lookup for speed:
- Categorized structure for finding similar items
- Flat "POWER_UPS" dictionary for O(1) lookup
- _init() method to build flat registry
- get_by_category() helper for filtered access
- Performance: 125 preloads = negligible overhead
