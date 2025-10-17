# DiceRogue

A pixel-art roguelite dice game inspired by Yahtzee, built in Godot 4.4. Roll dice, collect power-ups, and beat challenges in this strategic dice-based adventure.

## Game Concept

Classic Yahtzee scoring meets roguelite progression. Players roll dice to fill scorecard categories while collecting:
- **Power-ups**: Permanent modifiers that enhance scoring
- **Consumables**: Single-use items for strategic advantages
  - **AnyScore**: Score current dice in any open category, ignoring normal scoring requirements
  - **Random Uncommon Power-Up**: Grants a random uncommon rarity power-up
  - **Green Envy**: 10x multiplier for all green dice money scored this turn
  - **Poor House**: Transfer all your money to add bonus points to the next scored hand
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
- **DiceColor** (`Scripts/Core/dice_color.gd`) - Color system for dice enhancement

#### Dice Color System
The **Dice Color System** adds strategic depth through randomly colored dice that provide different bonuses:

**Color Types:**
- **Green Dice**: Award money bonuses equal to dice value when scored
- **Red Dice**: Add bonus points equal to dice value to final score  
- **Purple Dice**: Multiply final score by dice value

**Color Assignment:**
- **Green**: 1 in 10 chance per roll (10%)
- **Red**: 1 in 15 chance per roll (~6.7%)
- **Purple**: 1 in 50 chance per roll (2%)

**Bonus Mechanics:**
- **5+ Same Color Bonus**: When 5 or more dice of the same color are scored, all bonuses of that color are doubled
- **Calculation Order**: Money awarded first, then additives applied, then multipliers
- **Toggle System**: Colors can be disabled globally (useful for challenges/debuffs)

**Examples:**
- Full House (3×2s, 2×5s) with one green 5: Base score 25 + $5 money
- Full House with one red 5: Base score becomes (25 + 5) = 30 points  
- Full House with one purple 5: Base score becomes 25 × 5 = 125 points
- Five green dice (values 2,2,2,3,3): Money bonus = (2+2+2+3+3) × 2 = $24 (doubled)

### Scoring
- **Scorecard** (`Scenes/ScoreCard/score_card.gd`) - Yahtzee-style scoring
- **ScoreEvaluator** (autoload) - Score calculation logic
- **ScoreModifierManager** (autoload, file: `Scripts/Managers/MultiplierManager.gd`) - Handles all score bonuses and multipliers

### Economy & Items
- **PlayerEconomy** (autoload) - Money and shop transactions
- **PowerUps** (`Scripts/PowerUps/`) - Permanent scoring bonuses
  - **FullHousePowerUp**: Grants $7 × (total full houses rolled) for each new full house
- **Consumables** (`Scripts/Consumable/`) - Single-use strategic items
- **Mods** (`Scripts/Mods/`) - Dice behavior modifiers

### Statistics & Analytics
- **RollStats** (autoload) - Tracks game statistics like yahtzees, bonuses, and combinations
  - **Location**: `Scripts/Core/roll_stats.gd`
  - **Features**: Real-time tracking of yahtzees, straights, bonuses, and roll counts
  - **Debug Integration**: View stats via debug panel "Show Roll Stats" button
  - **Reset Support**: Statistics reset automatically between games

### Dice Color Management
- **DiceColorManager** (autoload) - Global dice color system coordination
  - **Location**: `Scripts/Managers/dice_color_manager.gd`
  - **Features**: Enable/disable colors, calculate effects, bonus determination
  - **Integration**: Works with scoring system and debug tools
  - **Effects**: Manages money, additive, and multiplier calculations

## Key Systems

### Statistics System
The **Statistics Manager** tracks comprehensive game metrics and player behavior:

**Features:**
- **Real-time Tracking**: Monitors all player actions including dice rolls, scoring, purchases, and item usage
- **Categorized Metrics**: Core game stats, economic data, dice behavior, hand completions, and session metrics  
- **Visual Dashboard**: Press **F10** to toggle statistics panel with tabbed interface
- **Milestone Detection**: Automatic recognition and celebration of achievement thresholds
- **Future Integration**: Designed for statistic-based power-ups, achievements, and dynamic difficulty

**Key Statistics Tracked:**
- **Game Metrics**: Total turns, rolls, rerolls, hands completed/failed, scoring percentage
- **Economics**: Money earned/spent by category, efficiency ratios, current balance
- **Dice Data**: Rolls by color, highest values, snake eyes count, lock behavior
- **Hand Types**: Frequency of each Yahtzee category scored (ones through yahtzee)
- **Items**: Purchases and usage counts for power-ups, consumables, and mods
- **Session**: Play time, highest scores, scoring streaks, performance trends

**Implementation:**
- **Autoload Singleton**: `Statistics` - globally accessible for real-time tracking
- **UI Panel**: `StatisticsPanel.tscn` - organized tabbed display with auto-refresh
- **Integration Points**: Connected to dice rolling, scoring, shop purchases, and item usage
- **API Design**: Simple increment/track methods with computed analytics

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

## Available PowerUps

### Score Modifiers
- **FoursomePowerUp**: +2x multiplier when dice contain a 4
- **UpperBonusMultPowerUp**: Multiplies upper section scores by bonus count
- **YahtzeeBonusMultPowerUp**: Multiplies lower section scores by Yahtzee bonus count
- **Chance520PowerUp**: +520 points when scoring Chance category
- **RedPowerRangerPowerUp**: Gain +additive score for each red dice scored (cumulative across all hands)

### Economy PowerUps
- **BonusMoneyPowerUp**: +$50 for each bonus achieved (Upper Section or Yahtzee bonuses)
- **ConsumableCashPowerUp**: +$25 for each consumable used
- **MoneyMultiplierPowerUp**: +0.1x money multiplier per Yahtzee rolled (NEW)

### Dice Modifiers  
- **ExtraDicePowerUp**: Adds 6th die to hand (enables lock dice debuff)
- **ExtraRollsPowerUp**: +2 extra rolls per turn
- **EvensNoOddsPowerUp**: Rerolls odd dice automatically
- **RandomizerPowerUp**: Randomly applies effects each turn

### Usage Notes
- PowerUps stack and interact with the scoring system
- Economy PowerUps provide strategic money management
- Dice modifiers change fundamental gameplay mechanics
- All PowerUps support selling for 50% refund

## Available Consumables

### Scoring Aids
- **AnyScore**: Score current dice in any open category, ignoring normal requirements
- **ScoreReroll**: Reroll all dice, then auto-score best category

### Economy
- **Green Envy**: 10x multiplier for all green dice money scored this turn (Price: $50)
- **Poor House**: Transfer all your money to add bonus points to the next scored hand (Price: $100)

### PowerUp Acquisition
- **Random Uncommon Power-Up**: Grants a random uncommon rarity power-up

### Usage Notes
- Consumables are single-use items
- AnyScore is particularly useful for filling difficult categories
- Green Envy is most effective when you have multiple green dice
- Random PowerUps provide strategic risk/reward decisions

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
- **Dice Colors**: Toggle color system, force all dice to specific colors, show effects
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
- ✅ AnyScore consumable - Score dice in any category ignoring requirements (implemented)
- ✅ Green Envy consumable - 10x multiplier for green dice money (implemented)
- ✅ Poor House consumable - Transfer money to next scored hand bonus (implemented)
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

