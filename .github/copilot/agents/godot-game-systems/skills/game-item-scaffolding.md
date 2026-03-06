---
skillName: Game Item Scaffolding
agentId: godot-game-systems
activationKeywords:
  - scaffold
  - template
  - boilerplate
  - create_new_item
  - new_powerup
  - new_consumable
  - new_challenge
  - new_debuff
filePatterns:
  - Scripts/PowerUps/*.gd
  - Scripts/Consumable/*.gd
  - Scripts/Challenge/*.gd
  - Scripts/Debuff/*.gd
examplePrompts:
  - Generate a new PowerUp called [Name]
  - Create boilerplate for a new Consumable
  - Scaffold a Challenge with [mechanics]
---

# Skill: Game Item Scaffolding

## Purpose
Generate complete, production-ready boilerplate code for new game items (PowerUps, Consumables, Challenges, Debuffs). Provides starter templates with proper inheritance, @export properties, and method stubs ready for customization. **CRITICAL: All items must register in the unlock system with UnlockCondition.**

## When to Use
- Creating a new PowerUp, Consumable, Challenge, or Debuff
- Need consistent boilerplate structure across new items
- Want proper class_name, inheritance, and method signatures
- Building multiple similar items (batch generation)
- **ALWAYS** - every item must register in unlock system, this ensures proper setup

## Inputs
- Item type: PowerUp, Consumable, Challenge, or Debuff
- Item name (in PascalCase for class_name)
- Item description/mechanics summary
- Optional: Base rarity (1-10), effect values, custom properties

## Outputs
- Complete GDScript file with proper structure
- @export properties for editor configuration
- Method stubs for customization
- Comments explaining custom implementation areas
- Ready to save to correct directory and iterate

## Behavior
- Follow DiceRogue item base class patterns exactly
- Use proper @export declarations for editor visibility
- Include class_name with correct parent class
- Add TODO comments for custom logic areas
- Provide both simple and complex examples
- Reference existing similar items for customization ideas

## Constraints
- Always inherit from proper base class (PowerUp, Consumable, Challenge, Debuff)
- Include class_name (must be PascalCase)
- Follow DiceRogue code conventions (tabs, snake_case methods, PascalCase classes)
- Do not include game logic outside custom areas
- Ensure code is immediately ready to use

## DiceRogue Item Patterns

### PowerUp Template Structure
```gdscript
extends PowerUp
class_name [ItemName]

@export var display_name: String = "[Readable Name]"
@export var description: String = "[Effect description]"
@export var rarity: int = 1  # 1-10 scale

func apply(game_controller: GameController) -> void:
    # TODO: Implement PowerUp effect here
    # Access properties: game_controller.player_economy, dice_results, etc.
    pass
```

### Consumable Template Structure
```gdscript
extends Consumable
class_name [ItemName]

@export var display_name: String = "[Readable Name]"
@export var effect_value: int = 0  # Damage, bonus amount, etc.
@export var description: String = "[Effect description]"

func apply(game_controller: GameController) -> void:
    # TODO: Implement Consumable effect (one-time use)
    pass
```

### Challenge Template Structure
```gdscript
extends Challenge
class_name [ItemName]

@export var goal_type: String = "custom"
@export var goal_value: int = 0
@export var description: String = "[Goal description]"

func check_progress() -> bool:
    # TODO: Return true when goal is complete
    return false
```

### Debuff Template Structure
```gdscript
extends Debuff  # Or custom if stateless
class_name [ItemName]

@export var display_name: String = "[Debuff Name]"
@export var duration_rounds: int = 1
@export var description: String = "[Debuff effect]"

func apply(game_controller: GameController) -> void:
    # TODO: Apply debuff to game state
    pass
```

## CRITICAL: Unlock System Registration
**Every item MUST register in the unlock system. This is non-negotiable.**

For each item created:
1. Create unique ID (e.g., `"dice_doubler"`, `"quick_cash_consumable"`)
2. Create UnlockCondition Resource defining when item unlocks
3. Register in appropriate manager (PowerUpManager, ConsumableManager, etc.)
4. Verify item loads with unlock condition and appears in progression

This ensures items are:
- Trackable in game progression
- Properly gated by unlock conditions
- Available for shop, rewards, and progression systems

## Example Prompt
"Generate a new PowerUp called 'DoubleYahtzee' that doubles the Yahtzee bonus (300 → 600)"

## Example Output
- Complete GDScript class with inheritance, @export properties, method stubs
- Comments explaining where to add custom logic
- Reference to similar existing items for inspiration
- Suggestions for testing this new item
