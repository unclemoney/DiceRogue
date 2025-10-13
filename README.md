# DiceRogue

A pixel-art roguelite dice game inspired by Yahtzee, built in Godot 4.4. Roll dice, collect power-ups, and beat challenges in this strategic dice-based adventure.

## Game Concept

Classic Yahtzee scoring meets roguelite progression. Players roll dice to fill scorecard categories while collecting:
- **Power-ups**: Permanent modifiers that enhance scoring
- **Consumables**: Single-use items for strategic advantages
- **Mods**: Dice modifiers that change how individual dice behave
- **Challenges**: Goals that unlock rewards and progression

## Quick Start

1. **Main Scene**: `Scenes/Controller/game_controller.tscn`
2. **Run in Editor**: Open project in Godot 4.4+, press F5
3. **Testing**: Use scenes in `Tests/` folder for isolated component testing

## Core Architecture

### Game Flow
- **GameController** (`Scripts/Core/game_controller.gd`) - Central coordination
- **RoundManager** (`Scripts/Managers/round_manager.gd`) - Round progression  
- **TurnTracker** (`Scripts/Core/turn_tracker.gd`) - Roll counting and turn logic

### Dice System
- **Dice** (`Scripts/Core/dice.gd`) - Individual die behavior
- **DiceHand** (`Scripts/Core/dice_hand.gd`) - Collection of 5 dice
- **DiceResults** (autoload) - Result data structure

### Scoring
- **Scorecard** (`Scenes/ScoreCard/score_card.gd`) - Yahtzee-style scoring
- **ScoreEvaluator** (autoload) - Score calculation logic
- **ScoreModifierManager** (autoload, file: `Scripts/Managers/MultiplierManager.gd`) - Handles all score bonuses and multipliers

### Economy & Items
- **PlayerEconomy** (autoload) - Money and shop transactions
- **PowerUps** (`Scripts/PowerUps/`) - Permanent scoring bonuses
- **Consumables** (`Scripts/Consumable/`) - Single-use strategic items
- **Mods** (`Scripts/Mods/`) - Dice behavior modifiers

## Key Systems

### Score Modifier System
The `ScoreModifierManager` handles all score modifications:
- **Additives**: Flat bonuses applied before multipliers
- **Multipliers**: Percentage modifiers applied after additives
- **Order**: `(base_score + additives) × multipliers`

Power-ups register their bonuses with this manager, which emits signals when totals change.

### UI Architecture
- **Spine/Fan System**: Cards can be displayed as compact spines or fanned out for interaction
- **PowerUpUI** (`Scripts/UI/power_up_ui.gd`) - Manages power-up display
- **ConsumableUI** (`Scripts/UI/consumable_ui.gd`) - Manages consumable display
- **ShopUI** (`Scripts/UI/shop_ui.gd`) - In-game purchasing

### Item Selling System
All game items (PowerUps, Consumables, and Mods) support selling mechanics:
- **Click to Sell**: Click any item icon to show a "SELL" button above it
- **Half-Price Refund**: Items sell for 50% of their original purchase price
- **Mod Selling**: Mods attached to dice can be sold by clicking their small icons on dice
- **Outside Click**: Click outside an item to hide the sell button
- **Signal Chain**: Item icons → UI managers → GameController → PlayerEconomy

### Testing Framework
Test scenes in `Tests/` folder allow isolated testing of components:
- `DiceTest.tscn` - Dice rolling and behavior
- `ScoreCardTest.tscn` - Scoring logic
- `PowerUpTest.tscn` - Power-up functionality
- `MultiplierManagerTest.tscn` - Score modifier system

## Development Guidelines

### Adding New Power-ups
1. Create script in `Scripts/PowerUps/` extending `PowerUp`
2. Register score effects with `ScoreModifierManager`
3. Add activation code to `GameController`
4. Create data entry in `PowerUpManager`

### Adding New Consumables  
1. Create script in `Scripts/Consumable/` extending base consumable
2. Implement `can_use()` and `use()` methods
3. Add data entry in `ConsumableManager`
4. Test usability logic in isolation

### Adding New Mods
1. Create script in `Scripts/Mods/` extending `Mod`
2. Implement `apply(target)` and `remove()` methods
3. Add data entry in `ModManager`
4. Selling mechanics are automatically handled by `ModIcon`

### Coding Standards
- Use GDScript 4.4 syntax
- Tabs for indentation (never spaces)
- `snake_case` for variables/methods, `PascalCase` for classes
- Document functions with `##` comment blocks
- Never use `class_name` in autoload scripts

## Debug System

For rapid testing and verification of new features, DiceRogue includes a comprehensive debug system:

### Debug Panel Features
- **Toggle**: Press `F12` to open/close debug panel
- **Location**: `Scenes/UI/DebugPanel.tscn`
- **Solid black background** for easy reading
- **Live system info**: FPS, process ID, node count
- **Timestamped output** with auto-scroll
- **Quick Actions**: 18+ debug commands organized by category

### Available Debug Commands
- **Items**: Grant random PowerUps/Consumables/Mods, show all active items, clear all
- **Economy**: Add money ($100/$1000), reset to default  
- **Dice Control**: Force specific values (all 6s, 1s, Yahtzee)
- **Game Flow**: Add extra rolls, force end turn, skip to shop
- **System Testing**: Test score calculations, trigger signals, show states
- **Debug State**: Save/load debug scenarios for quick testing
- **Utilities**: Clear output, reset entire game state

### Panel Controls
- **Clear Output**: Remove all debug messages
- **Close Button**: Properly hides panel (doesn't remove it)
- **F12 Toggle**: Works both to open and close

### Adding Debug Commands
To add new debug functionality:

1. **In DebugPanel**: Add button to `_create_debug_buttons()` array
2. **Implement Method**: Create `_debug_your_feature()` method
3. **Test Quickly**: Use F12 panel for immediate testing

**⚠️ IMPORTANT: When adding new game features, remember to add corresponding debug commands to test them quickly!**

### Available Debug Commands
- **Items**: Grant random PowerUps/Consumables/Mods, show all active items, clear all
- **Economy**: Add money ($100/$1000), reset to default
- **Dice Control**: Force specific values (all 6s, 1s, Yahtzee)
- **Game Flow**: Add extra rolls, force end turn, skip to shop
- **System Testing**: Test score calculations, trigger signals, show states
- **Utilities**: Clear output, reset entire game state

### Debug Logging
Enable debug output in any system:
```gdscript
var debug_enabled: bool = true

func your_function():
    if debug_enabled:
        print("[SystemName] Debug info here")
```

### Test Scene Pattern
For isolated testing:
1. Create scene in `Tests/` folder
2. Add minimal UI with test buttons
3. Print expected vs actual results
4. Use debug panel for setup

Example test structure:
```gdscript
extends Control

func _ready():
    var test_button = Button.new()
    test_button.text = "Test Feature"
    test_button.pressed.connect(_test_your_feature)
    add_child(test_button)

func _test_your_feature():
    print("=== Testing Your Feature ===")
    # Set up test conditions
    # Execute feature
    # Verify results
    print("Expected: X, Got: Y")
```

This debug system allows for rapid iteration and verification without rebuilding or complex setups.

## 🔧 Development Reminders

### When Adding New Features
**Always add debug commands for new features!** This includes:
- New power-ups → Add grant/test commands
- New game mechanics → Add state inspection and trigger commands  
- New UI systems → Add show/hide and state commands
- New scoring rules → Add test calculation commands
- New managers/systems → Add debug state display

### Debug Menu Maintenance
1. **Add buttons** to `_create_debug_buttons()` array in `debug_panel.gd`
2. **Implement methods** following `_debug_feature_name()` pattern
3. **Use `log_debug()`** for consistent output formatting
4. **Test thoroughly** - debug commands should be reliable

This prevents the need for complex manual testing setups and keeps development velocity high.

## Feature Ideas

### Short-term
- ✅ Mod selling mechanics (implemented)
- Additional power-up variety
- Challenge progression system
- Balance pass on economy

### Long-term
- Visual effects for dice interactions
- Sound design and music
- Save/load progression
- Analytics and balancing data

## Project Structure

```
Scripts/
├── Core/              # Game mechanics
├── Managers/          # System coordinators  
├── PowerUps/          # Permanent bonuses
├── Consumable/        # Single-use items
├── Mods/              # Dice modifiers
├── UI/                # Interface components
└── Effects/           # Visual/audio effects

Scenes/
├── Controller/        # Main game scene
├── ScoreCard/         # Scoring interface
├── PowerUp/           # Power-up visuals
├── Consumable/        # Consumable visuals
├── Shop/              # Shopping interface
└── UI/                # Reusable UI components

Tests/                 # Isolated test scenes
Resources/             # Art, audio, data
```

## Known Issues & Cleanup

### Deprecated Methods
These methods exist for compatibility but should not be used in new code:
- `Scorecard.clear_score_multiplier()` - Use `ScoreModifierManager` instead
- `ConsumableUI.get_consumable_icon()` - Use spine/fan methods instead

### Technical Debt
- UI card construction has some duplication (base class available at `Scripts/UI/card_icon_base.gd`)
- Spine/fan UI systems could share more common code
- Some power-ups have duplicated signal lifecycle patterns

These issues are documented and tracked but don't impact functionality.

