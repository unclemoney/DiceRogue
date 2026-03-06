---
skillName: Dice & Mod System
agentId: godot-game-systems
activationKeywords:
  - dice
  - mod
  - modification
  - wildcard
  - evenonly
  - oddonly
  - lock
  - dice_state
  - color_effects
  - dice_mod
filePatterns:
  - Scripts/Core/dice.gd
  - Scripts/Managers/dice_color_manager.gd
  - Scripts/Mods/*.gd
examplePrompts:
  - Design a mod that forces even numbers
  - How do color bonuses interact with wildcards?
  - Create a mod that locks specific dice
  - How does the dice state machine work?
---

# Skill: Dice & Mod System

## Purpose
Design, debug, and understand DiceRogue's dice mechanics system. Covers dice state machines, modifications (mods) that alter behavior, color effects, and interactions between multiple mods. Handles complex scenarios where multiple mods stack.

## When to Use
- Designing a new dice modification
- Debugging mod application or removal
- Understanding color bonus calculation
- Fixing state machine issues (lock/unlock failures)
- Designing mods that interact with color dice
- Optimizing performance with many active mods

## Inputs
- Desired mod behavior description
- Target dice type (standard or colored)
- Interaction with other mods/effects
- Color effects expected (Green/Red/Purple)
- Optional: Code showing current behavior

## Outputs
- Complete mod class following DiceRogue patterns
- State machine implications explained
- Color effect calculations shown
- Stacking behavior clarified
- Code snippet ready for implementation

## Behavior
- Explain dice state machine first (ROLLABLE → ROLLED → LOCKED → DISABLED)
- Show how mods attach to individual dice
- Demonstrate color effect calculations
- Handle mod conflicts and stacking
- Reference dice.gd and DiceColorManager patterns
- Provide clear heuristics for mod ordering

## Constraints
- Each die can have multiple mods
- Mods must respect state machine (can't modify locked dice)
- Color effects must be calculated atomically
- Follow DiceRogue mod conventions exactly
- Consider performance when many mods are active

## DiceRogue Dice & Mod System

### Dice State Machine
```
ROLLABLE → (roll) → ROLLED → (lock) → LOCKED → (unlock) → ROLLABLE
      ↓ (disable)                ↓ (disable)
      └─────────────← DISABLED ←─┘
```

**State Transitions**:
- ROLLABLE: Can be rolled
- ROLLED: Locked after roll, value visible
- LOCKED: Locked by player/mod, cannot reroll
- DISABLED: Completely inactive (not rolled)

### Dice Classes
```gdscript
# Base Dice class (Scripts/Core/dice.gd)
extends Node
class_name Dice

var value: int = 0
var state: String = "ROLLABLE"
var mods: Array = []  # Active mods

func roll() -> void:
    if state == "ROLLABLE":
        value = randi() % 6 + 1
        state = "ROLLED"

func add_mod(mod: Mod) -> void:
    mods.append(mod)
    mod.apply_to_die(self)

func remove_mod(mod: Mod) -> void:
    mod.remove_from_die(self)
    mods.erase(mod)
```

### Mod Base Class
```gdscript
extends Node
class_name Mod

@export var mod_name: String = ""
@export var description: String = ""

func apply_to_die(die: Dice) -> void:
    # Override to modify die behavior
    pass

func remove_from_die(die: Dice) -> void:
    # Override to restore die behavior
    pass
```

### Color Effects System

**DiceColorManager** calculates bonuses:

```gdscript
signal color_effects_calculated(green_money, red_additive, purple_multiplier, same_color_bonus, rainbow_bonus)

func calculate_color_effects(dice_array: Array) -> void:
    var green_total = count_color(dice_array, "green") * 5  # 5 money per die
    var red_total = count_color(dice_array, "red") * 5      # +5 per die
    var purple_count = count_color(dice_array, "purple")
    var purple_multiplier = 1.0 + (purple_count * 0.1)      # ×1.1 per die
    
    var colors = collected_colors(dice_array)
    var same_color_bonus = 50 if all_same_color(colors) else 0
    var rainbow_bonus = 100 if colors.size() == 5 else 0
    
    color_effects_calculated.emit(green_total, red_total, purple_multiplier, same_color_bonus, rainbow_bonus)
```

### Common Mods

**EvenOnly Mod**:
- Forces die to show only even values (2, 4, 6)
- Rolls same die until even (or max attempts)

**OddOnly Mod**:
- Forces die to show only odd values (1, 3, 5)

**WildCard Mod**:
- Die can act as any value for scoring
- Creates multiple scoring options

**LockMod**:
- Die is automatically locked; cannot be rerolled

**DisableMod**:
- Die is disabled; cannot be part of score

### Mod Stacking & Conflicts

**Allowed Stacking**:
- EvenOnly + ColorBonus (no conflict)
- EvenOnly + LockMod (lock prevents reroll anyway)

**Conflicts**:
- EvenOnly + OddOnly (contradictory)
- Multiple stacking mods may need priority ordering

## Example Prompt
"Design a mod that forces a die to always show the same value as another die"

## Example Output
- Copy value from source die on roll
- Handle state transitions (lock when source locked)
- Account for conflicts (if source has EvenOnly, follow that constraint)
- Test: Multiple mods on same die should prioritize correctly
