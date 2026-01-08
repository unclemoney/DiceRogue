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
  - **Empty Shelves**: Multiply next score by the number of empty PowerUp slots (only during active rounds)
  - **Double or Nothing**: Use after Next Turn, before manual roll. Yahtzee = 2x score, No Yahtzee = next score becomes 0
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
- **Blue Dice**: Conditional multiplier/divisor - multiply score by dice value if used in scoring, divide if not used (very rare)

**Color Assignment:**
- **Green**: 1 in 25 chance per roll (4%)
- **Red**: 1 in 50 chance per roll (2%)
- **Purple**: 1 in 88 chance per roll (~1.1%)
- **Blue**: 1 in 100 chance per roll (1%) - Very rare

**Blue Dice Special Mechanics:**
- **Used in Scoring**: If the blue die contributes to the category score, multiply final score by the die value
- **Not Used in Scoring**: If the blue die doesn't contribute to the category score, divide final score by the die value
- **Examples**: 
  - Roll 4,4,4,4,5(blue) → Score in Fours → Blue 5 not used → 16÷5=3 points
  - Roll 1,2,3,4,5(blue) → Score Large Straight → Blue die used → 40×(blue value)=120+ points

**Bonus Mechanics:**
- **5+ Same Color Bonus**: When 5 or more dice of the same color are scored, all bonuses of that color are doubled
- **Calculation Order**: Money awarded first, then additives applied, then multipliers, then blue dice effects
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
- **Autoscoring Priority**: When "Next Turn" button auto-selects scoring category, uses priority system to prefer more specific categories when scores are tied (e.g., Four of a Kind over Three of a Kind)

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

### Audio System
- **AudioManager** (autoload) - Centralized audio playback with dynamic pitch variation
  - **Location**: `Scripts/Managers/audio_manager.gd`
  - **Dice Roll Sounds**: 5 randomized .wav files (`DICE_ROLL_1-5.wav`) with per-die playback
    - Base pitch randomized (0.9-1.1) plus linear progression (+0.05 per roll number)
    - Sound staggered by roll delay for natural feel
    - Pitch progression resets after scoring
  - **Scoring Sound**: `SCORE_1.wav` with progressive pitch during scoring sequence
    - Pitch starts at 0.8 and increases by 0.08 per scoring step (max 1.5)
    - Plays for each die scored, each additive/multiplier contribution, and final score
    - Pitch resets at start of each scoring animation sequence
  - **Money Sound**: `CASH_1.wav` played per non-zero bonus item with amount-based pitch scaling
  - **Button Click Sound**: `BUTTON_CLICK_1.wav` with slight random pitch variation (0.95-1.05)
    - Automatically connected to ALL buttons in the game via scene tree monitoring
  - **Firework Sound**: `FIREWORK_1.wav` for celebratory effects
    - Plays on challenge completion (first burst only)
    - Plays on consumable use (destruction effect)
  - **Master Volume**: Shared `@export var master_volume_db` across all players
  - **Audio Resources**: Located in `res://Resources/Audio/DICE/`, `SCORING/`, `MONEY/`, `UI/`

### Music System
- **MusicManager** (autoload) - Layered dynamic music that responds to gameplay intensity
  - **Location**: `Scripts/Managers/music_manager.gd`
  - **Layered Architecture**: Base layer + 6 optional layers that fade in/out based on intensity
    - **BOTTOM_LAYER.wav**: Continuously looping base layer (always plays)
    - **LAYER_N_X.wav**: Variant layers where N=1-6 (layer number), X=A-Z (variant ID)
    - All layers must have exactly the same duration as BOTTOM_LAYER.wav
  - **Intensity System**: Levels 0-6 control how many layers play simultaneously
    - Level 0: Base layer only (minimal music)
    - Level 3: Base + 3 random layers (moderate)
    - Level 6: Base + all 6 layers (maximum intensity)
  - **Smart Variant Selection**: Avoids recently-played variants using configurable memory depth
    - `@export var variant_memory_depth: int = 3` - How many recent variants to avoid
    - Prevents repetitive music by cycling through available variants
  - **Loop-Boundary Synchronization**: Intensity changes only apply at loop boundaries
    - Music transitions feel seamless and never cut mid-phrase
    - Pending intensity changes are queued and applied when base layer finishes
  - **Volume Transitions**: Smooth fade-in/fade-out using tweens
    - Default transition duration: 0.8 seconds
    - Old tweens are killed before starting new ones

**Intensity Presets (Game Event Mappings):**
| Event | Intensity | Description |
|-------|-----------|-------------|
| Game Start | 0 | Minimal music during setup |
| Shop Opened | 1 | Light background during shopping |
| Round Started | 3 | Moderate energy for active gameplay |
| Challenge Complete | 6 | Full intensity celebration |
| Round Complete | 2 | Calming down after success |
| Game Over | 0 | Return to minimal music |

**File Naming Convention:**
- Base layer: `BOTTOM_LAYER.wav`
- Layer variants: `LAYER_1_A.wav`, `LAYER_1_B.wav`, `LAYER_2_A.wav`, etc.
- All files must be in `res://Resources/Audio/MUSIC/`
- Duration validation: All layers must exactly match base layer duration (0.0s tolerance)

**Debug Mode:**
- `@export var debug_mode: bool = false` - Enable verbose logging
- Logs layer loading, variant selection, intensity changes, and timing

**Configuration:**
```gdscript
# Volume control
@export_range(-40, 0) var music_volume_db: float = -10.0

# Variant selection memory (avoid last N variants per layer)
@export_range(0, 10) var variant_memory_depth: int = 3

# Enable debug logging
@export var debug_mode: bool = false

# Intensity presets for game events
@export var intensity_shop: int = 1
@export var intensity_round_start: int = 3
@export var intensity_challenge_complete: int = 6
@export var intensity_round_complete: int = 2
@export var intensity_game_over: int = 0
```

**Public API:**
```gdscript
# Set intensity (0-6), change applies at next loop boundary
MusicManager.set_intensity(3, 0.8)  # Level 3, 0.8s transition

# Start/stop music playback
MusicManager.start_music()
MusicManager.stop_music()
```

### Channel System (Difficulty Scaling)
The **Channel Manager** provides an infinite difficulty progression system (Channels 1-99):

**Features:**
- **TV Remote UI**: Select starting channel at game start with Up/Down buttons
- **Quadratic Scaling**: Difficulty increases smoothly using formula: `1.0 + ((channel - 1) / 98)² × 99`
- **Target Score Scaling**: Challenge goals multiply by channel difficulty (100 pts at Ch1 → 10,000 pts at Ch99)
- **Infinite Loop**: After completing Round 6, RoundWinnerPanel offers "Next Channel" to advance and restart
- **Persistent Completion**: Completed channels are saved and display a checkmark when browsing
- **Achievement Tracking**: `highest_channel_completed` stat tracks player's best channel achievement

**Difficulty Curve:**
- **Channel 1**: 1.0x (100 points base → 100 points)
- **Channel 2**: ~1.01x (100 points base → 101 points) - Very mild bump
- **Channel 10**: ~1.08x (100 points base → 108 points)
- **Channel 50**: ~25.5x (100 points base → 2,550 points)
- **Channel 99**: 100x (100 points base → 10,000 points)

**Implementation:**
- **ChannelManager** (`Scripts/Managers/channel_manager.gd`) - Core difficulty logic
- **ChannelManagerUI** (`Scripts/Managers/channel_manager_ui.gd`) - TV remote selector UI with completion indicator
- **RoundWinnerPanel** (`Scripts/UI/round_winner_panel.gd`) - Victory screen with stats
- **ProgressManager** - Persists `completed_channels` array and `highest_channel_completed` stat
- **Integration**: GameController coordinates showing/hiding UI and scaling targets

**Game Flow:**
1. Game starts → Channel selector appears (completed channels show checkmark)
2. Player selects channel (1-99) and presses Start
3. Game progresses through 6 rounds with scaled target scores
4. After Round 6 completion → RoundWinnerPanel shows stats
5. "Next Channel" marks channel complete, saves progress, advances to next channel, resets to Round 1

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
- **Slot Tracking**: Available PowerUp and Consumable slots with real-time updates
- **Session**: Play time, highest scores, scoring streaks, performance trends

**Implementation:**
- **Autoload Singleton**: `Statistics` - globally accessible for real-time tracking
- **Detailed Logbook**: Enhanced calculation summaries with specific source attribution for additive/multiplier effects
- **Dice Lock Tracking**: Connected to dice_hand.die_locked signal for accurate dice lock counting
- **UI Panel**: `StatisticsPanel.tscn` - organized tabbed display with auto-refresh
- **Integration Points**: Connected to dice rolling, scoring, shop purchases, and item usage
- **API Design**: Simple increment/track methods with computed analytics

### Logbook System
The **Logbook System** provides detailed tracking and debugging of all hand scoring events:

**Features:**
- **Comprehensive Logging**: Records every hand scored with complete context including dice values, colors, mods, consumables, and powerups
- **Calculation Tracking**: Captures base scores, modifier effects, and final results with step-by-step breakdowns
- **Real-time Display**: Shows recent scoring history in the ExtraInfo area of the ScoreCard UI
- **Debug Support**: Enables detailed analysis of complex scoring interactions for development and balancing
- **Export Capability**: Save complete session logs to JSON files for external analysis

**Log Entry Contents:**
- **Dice Information**: Values, colors, and active mods for each die
- **Scoring Context**: Category selected, section (upper/lower), and base calculation
- **Modifiers Applied**: PowerUps, Consumables, and their specific effects on the score
- **Calculation Chain**: Step-by-step breakdown of how final score was calculated
- **Formatted Display**: Human-readable one-line summaries for UI presentation

**Usage Examples:**
```gdscript
# Basic logging (automatically called during scoring)
Statistics.log_hand_scored(dice_values, dice_colors, dice_mods, 
    "three_of_a_kind", "lower", consumables, powerups, 
    base_score, effects, final_score)

# Retrieve recent entries for display
var recent_logs = Statistics.get_recent_log_entries(3)

# Get formatted text for ExtraInfo display  
var display_text = Statistics.get_formatted_recent_logs()

# Export session logs for analysis
Statistics.export_logbook_to_file("session_analysis.json")
```

**Integration Points:**
- **ScoreCard UI**: Automatically displays recent log entries in ExtraInfo RichTextLabel
- **Statistics Panel**: Full logbook browser with filtering and search (future)
- **PowerUp/Consumable Systems**: Records modifier effects as they are applied
- **Debug Tools**: Enables real-time scoring verification and edge case identification

**File Location**: See `LOGBOOK.md` for detailed implementation specifications and future extension plans.

### Score Breakdown UI Panels
The **Score Breakdown UI** provides visual feedback during scoring animations, showing how bonuses and multipliers contribute to the final score:

**Panel Structure:**
- **LogbookPanel**: Shows recent scoring history (moved from ExtraInfo to dedicated panel)
- **BestHandPanel**: Contains best hand name and score breakdown labels
  - **BestHandScore**: Shows the highest-scoring category for current dice (simplified to category name only)
  - **AdditiveScoreLabel**: Displays cumulative additive bonuses ("+X") with themed background
  - **MultiplierScoreLabel**: Displays combined multiplier effects ("×Y") with themed background
- **TotalScorePanel**: Contains the total score display with animated updates

**Base Additive Score Calculation:**
The additive score starts with a **base value** calculated from the best hand:
- Formula: `Base Additive = Best Hand Score × Category Level`
- Example: Small Straight (30 points) at Level 2 = 30 × 2 = **+60 base additive**
- Updates dynamically as dice values change and new best hands are identified
- Additional bonuses from consumables/powerups add to this base during scoring

**Themed Labels:**
Both additive and multiplier labels use a custom theme with `UI_BACKGROUND.png` texture:
- 1-pixel texture margin on all sides for subtle border effect
- Semi-transparent dark background (Color: 0.3, 0.3, 0.4, 0.8)
- Applied via `score_breakdown_theme.tres`

**Animation Integration:**
The panels update in real-time during the `ScoringAnimationController` sequence:
1. Dice bounce animation starts
2. Additive panel shows base score (yellow dim) during preview, then updates with consumable animations (yellow bounce)
3. Multiplier panel updates after powerup animations (cyan bounce on value > 1.0, white bounce on 1.0)
4. Final score floating number appears
5. Total score panel animates with bounce effect

**Key Methods:**
- `prepare_for_scoring_animation()`: Resets breakdown labels before animation starts
- `update_additive_score_panel(value, animate)`: Updates additive display with optional bounce
- `update_multiplier_score_panel(value, animate)`: Updates multiplier display with optional bounce
- `animate_total_score_bounce(new_score)`: Applies gold flash and bounce to total score
- `_apply_score_breakdown_theme()`: Loads and applies themed background to score labels

**Note**: BBCode tornado/rainbow effects are currently disabled for cleaner presentation.

### Progress Tracking System
The **Progress Tracking System** enables persistent player progression across multiple game sessions, unlocking new content based on gameplay achievements:

**Features:**
- **Persistent Progression**: Player progress saves across game sessions using JSON file storage
- **Unlock Conditions**: 15 different achievement types trigger item unlocks (score points, roll yahtzees, complete channels, etc.)
- **Item Locking**: PowerUps, Consumables, Mods, and Colored Dice can be locked behind progression requirements
- **LOCKED Shop Tab**: Shop interface shows locked items with unlock requirements and progress bars
- **Unlock Panel**: Sequential card-flip animations display newly unlocked items at end of round
- **Progress Tracking**: Visual progress bars show how close you are to unlocking items
- **Debug Controls**: Full testing suite for unlock/lock functionality

**Core Components:**
- **UnlockCondition** (`Scripts/Core/unlock_condition.gd`) - Defines achievement requirements
- **UnlockableItem** (`Scripts/Core/unlockable_item.gd`) - Represents items that can be unlocked
- **ProgressManager** (autoload) - Central progression tracking and persistence system
- **UnlockedItemPanel** (`Scripts/UI/unlocked_item_panel.gd`) - End-of-round unlock display
- **Shop UI Integration** - LOCKED tab with filtered item display and progress bars

**Unlock Condition Types:**

| Type | Description | Example |
|------|-------------|---------|
| `SCORE_POINTS` | Score X points in a single category | Score 100+ in one category |
| `ROLL_YAHTZEE` | Roll X yahtzees in a single game | Roll 2 yahtzees in one game |
| `COMPLETE_GAME` | Complete X number of games | Complete 5 games |
| `SCORE_CATEGORY` | Score in a specific category | Score in Full House |
| `ROLL_STRAIGHT` | Roll X straights in a single game | Roll 3 straights |
| `USE_CONSUMABLES` | Use X consumables in one game | Use 5 consumables |
| `EARN_MONEY` | Earn X dollars in a single game | Earn $200 in one game |
| `COLORED_DICE_BONUS` | Trigger X same color bonuses | Trigger 3 color bonuses |
| `SCORE_UPPER_BONUS` | Achieve upper section bonus | Get 63+ upper points |
| `WIN_GAMES` | Win X games (cumulative) | Win 10 total games |
| `CUMULATIVE_SCORE` | Achieve total score across all games | Score 5000 total |
| `DICE_COMBINATIONS` | Roll specific dice combinations | Roll specific patterns |
| `CUMULATIVE_YAHTZEES` | Roll X yahtzees across all games | Roll 10 total yahtzees |
| `COMPLETE_CHANNEL` | Complete channel X | Complete Channel 5 |
| `REACH_CHANNEL` | Reach channel X | Reach Channel 10 |

**End of Round Unlock Display:**
When items are unlocked at the end of a round, they're displayed sequentially in modal panels with:
- Card flip animation revealing the item
- Item icon, name, and description
- Type indicator (PowerUp, Consumable, Mod, etc.)
- Achievement that triggered the unlock
- OK button to acknowledge and continue

The unlock panel appears between game end and the End of Round Stats Panel, ensuring players see their achievements before viewing bonuses.

**Progress Tracking in LOCKED Tab:**
- Progress bars show cumulative progress toward unlock conditions
- Items ≥80% complete are highlighted with gold borders
- Star icon (⭐) replaces lock icon for items close to unlocking
- Progress displays "X/Y" format for trackable conditions

**Implementation:**
```gdscript
# Example unlock condition for a PowerUp
var condition = UnlockCondition.new()
condition.condition_type = UnlockCondition.ConditionType.CUMULATIVE_YAHTZEES
condition.target_value = 10
condition.description = "Roll 10 Yahtzees (total)"

# Check player's progress toward a condition
var progress = ProgressManager.get_condition_progress("item_id")
# Returns: {current: 5, target: 10, percentage: 50.0}
```

**Channel-Based Unlocks:**
New items can be unlocked by completing channels, providing progression rewards:
- **Channel 3**: Basic utility items (Lucky Streak, Channel Bonus)
- **Channel 5**: Uncommon items (Steady Progress, Reroll Master)
- **Channel 8**: Rare items (Combo King, Lucky Seven)
- **Channel 12**: Advanced items (Channel Champion, Precision Roller)
- **Channel 15**: Legendary items (Grand Master, Ultimate Reroll)
- **Channel 20**: Ultimate items (Dice Lord)

**Progress Persistence:**
- **JSON Storage**: Progress data saved to `user://progress.save`
- **Automatic Saving**: Progress updates saved immediately when conditions are met
- **Game Integration**: Seamless tracking of all player actions and achievements

**Debug Support:**
- **Progress Tab**: Full debug panel with test functions
- **Unlock/Lock Controls**: Toggle any item's unlock status for testing
- **Progress Simulation**: Simulate achieving any unlock condition
- **Reset Functions**: Clear progress for testing scenarios

**File Locations:**
- Core System: `Scripts/Core/unlock_condition.gd`, `Scripts/Core/unlockable_item.gd`
- Manager: `Scripts/Managers/progress_manager.gd` (autoload)
- UI Components: `Scripts/UI/shop_ui.gd`, `Scripts/UI/unlocked_item_panel.gd`
- Scenes: `Scenes/UI/UnlockedItemPanel.tscn`
- Build Guides: `BUILD_POWERUP.md`, `BUILD_CONSUMABLE.md`, `BUILD_MOD.md`

### Score Modifier System
The `ScoreModifierManager` handles all score modifications:
- **Additives**: Flat bonuses applied before multipliers
- **Multipliers**: Percentage modifiers applied after additives
- **Order**: `(base_score + additives) × multipliers`

### Scaling Difficulty System
The game features round-based difficulty scaling that increases challenge as players progress:

**Upper Section Bonus Scaling:**
- **Base Values**: Threshold 63 points, Bonus 35 points
- **Scaling**: Both threshold and bonus scale up 10% each round (starting round 2)
- **Trigger**: Bonus now triggers as soon as upper section score meets threshold (no longer requires all categories to be filled)
- **Example**: Round 1 = 63/35, Round 2 = 70/39, Round 5 = 93/52, Round 10 = 150/84

**Goof-Off Meter Scaling:**
- **Base Value**: Max progress 100 rolls before Mom triggers
- **Scaling**: Threshold decreases by 5% each round (starting round 2)
- **Clamping**: When round changes, if current progress exceeds new threshold, it's clamped to threshold - 1
- **Example**: Round 1 = 100, Round 2 = 95, Round 5 = 82, Round 10 = 64

### End of Round Statistics & Bonuses
After completing a challenge and clicking the Shop button, an End of Round Statistics Panel is displayed:

**Panel Features:**
- Shows round number, challenge target score, and final score
- Displays animated bonus calculations
- "Head to Shop" button to proceed after viewing stats

**End of Round Bonuses:**
- **Empty Category Bonus**: $25 for each unscored category on the scorecard
  - Rewards efficient play and early challenge completion
  - Max possible: 13 categories × $25 = $325 (if completed without scoring anything)
- **Points Above Target Bonus**: $1 for each point above the challenge target score
  - Rewards exceeding the challenge requirements
  - Example: Challenge target 100, final score 130 = $30 bonus

**Bonus Calculation Example:**
- Round 1, Challenge target: 100 points
- Player finishes with score: 130 points
- Empty categories: 3 (didn't need to fill them)
- Empty category bonus: 3 × $25 = $75
- Points above target bonus: 30 × $1 = $30
- **Total round bonus: $105**

**Implementation:**
- `EndOfRoundStatsPanel` (`Scripts/UI/end_of_round_stats_panel.gd`) - Panel UI and animation
- `RoundManager.calculate_empty_category_bonus()` - Counts null categories × $25
- `RoundManager.calculate_score_above_target_bonus()` - (score - target) × $1
- Bonuses awarded via `PlayerEconomy.add_money()` when "Head to Shop" is clicked

**Challenge Reward Display:**
- Challenge UI now displays reward amount on the post-it note
- Reward shown in green text at bottom of challenge spine

**UI Updates:**
- ScoreCard bonus label shows current scaled threshold: "Bonus(70):" instead of static "Bonus:"
- Chore UI hover tooltip shows progress as "X / Y" with scaled max value
- Progress bar max_value updates to reflect scaled threshold

**Implementation:**
- `Scorecard.update_round(n)`: Updates round and recalculates thresholds
- `Scorecard.get_scaled_upper_bonus_threshold()`: Returns ceil(63 * 1.1^(round-1))
- `Scorecard.get_scaled_upper_bonus_amount()`: Returns ceil(35 * 1.1^(round-1))
- `ChoresManager.update_round(n)`: Updates round with progress clamping
- `ChoresManager.get_scaled_max_progress()`: Returns ceil(100 * 0.95^(round-1))

**Test Scene**: `Tests/ScalingTest.tscn` - Verify scaling calculations and threshold triggers

Power-ups register their bonuses with this manager, which emits signals when totals change.

### Chores & Mom System
The **Chores System** adds a strategic tension mechanic where neglecting household duties brings parental consequences:

**Core Mechanics:**
- **Progress Bar**: Vertical progress bar (0-100) displayed in top-left corner
- **Progress Increase**: +1 per dice roll (automatic)
- **Progress Decrease**: -20 when completing a chore task
- **Mom Trigger**: At 100 progress, Mom appears to check your PowerUps

**Chore Tasks:**
Tasks are randomly selected from a pool of 40+ options across different categories:
- **Upper Section Tasks**: Score specific upper categories (Ones, Twos, etc.)
- **Lower Section Tasks**: Score specific lower categories (Full House, Straight, etc.)
- **Specific Tasks**: Score with particular dice combinations
- **Utility Tasks**: Lock dice, use consumables, scratch categories
- **Challenge Tasks**: Roll Yahtzees or specific high-value combinations

**Task Completion:**
- Hover over ChoreUI to see current task requirements
- Complete the task requirement during normal gameplay
- Progress reduces by 20 when task is completed
- New task is automatically selected

**PowerUp Rating System:**
All PowerUps now have movie-style content ratings that affect Mom's reaction:
- **G** (General): Safe for all audiences - Mom approves
- **PG** (Parental Guidance): Mild content - Mom approves
- **PG-13** (Parents Strongly Cautioned): Some mature content - Mom approves
- **R** (Restricted): Adult content - Mom removes the PowerUp
- **NC-17** (Adults Only): Explicit content - Mom removes PowerUp AND applies stacking debuff

**Mom Consequences:**
When Mom appears (progress reaches 100):
1. Mom checks all active PowerUps for restricted ratings
2. **R-rated PowerUps**: Confiscated (removed from inventory)
3. **NC-17 PowerUps**: Confiscated + "Grounded" debuff applied per item
4. **Grounded Debuff**: Stacks for each NC-17 item found, persists until round end
5. **No Restricted Items**: Mom is happy and leaves without consequence

**Mom Character:**
- **Three Expressions**: Neutral (checking), Upset (found restricted items), Happy (clean slate)
- **Tween Animations**: Smooth entrance/exit with bounce effects
- **BBCode Dialog**: Colored text with personality-driven messages
- **Pixel Art Sprites**: 48px character in top-down view style

**ChoreUI Display:**
- **Vertical Progress Bar**: Shows current progress (0-100) with color gradient
- **Hover Details Panel**: Shows current task name, description, and progress
- **Position**: Top-left corner, non-intrusive during gameplay

**Debug Commands (Chores Tab):**
- Add Progress +10/+50: Quickly advance progress for testing
- Complete Current Task: Force task completion
- Trigger Mom Immediately: Bypass progress threshold
- Select New Task: Force new random task selection
- Reset Progress: Set progress to 0
- Show Chore State: Display current system status
- Show PowerUp Ratings: List all active PowerUp ratings
- Test Mom Dialog: Preview Mom's expressions and dialog

**Implementation Files:**
- **ChoreData**: `Scripts/Managers/ChoreData.gd` - Task resource class
- **ChoreTasksLibrary**: `Scripts/Managers/chore_tasks_library.gd` - Task pool
- **ChoresManager**: `Scripts/Managers/ChoresManager.gd` - Progress tracking
- **MomLogicHandler**: `Scripts/Core/mom_logic_handler.gd` - Consequence logic
- **ChoreUI**: `Scripts/UI/chore_ui.gd` - Progress bar display
- **MomCharacter**: `Scripts/UI/mom_character.gd` - Dialog popup
- **Mom Sprites**: `Resources/Art/Characters/Mom/` - Character art

**Mom's Mood System:**
Mom's mood tracks player behavior across a game session:
- **Mood Scale**: 1 (Very Happy) to 10 (Extremely Angry), default 5 (Neutral)
- **Mood Adjustment**: +2 when finding restricted PowerUps, -1 when player completes chores
- **Mood Reset**: Resets to neutral (5) at the start of each new game
- **Very Happy Reward (1)**: Mom grants a reward item when very happy
- **Extremely Angry Punishment (10)**: Mom applies an enhanced debuff when extremely angry
- **Mood Display**: Available in the Chores UI fan-out view with emoji indicator

**Chores Fan-Out UI:**
Clicking the Goof-Off Meter displays a fan-out panel showing:
- **Mom's Current Mood**: Emoji indicator (😊 to 😡) with mood description
- **Completed Chores List**: Checkmark list of all chores completed this game
- **Empty State**: Shows "No chores completed yet" message when starting fresh

### Challenge Celebration System
When challenges are completed, celebratory GPU particle effects are displayed:

**Firework Effects:**
- **GPUParticles2D**: Hardware-accelerated particle system for smooth performance
- **Multiple Bursts**: 4 staggered explosions with 0.15s delay between each
- **Burst Spread**: Random positions within 60px radius of challenge spine
- **Particle Count**: 75 particles per burst for full visual impact
- **Color Gradient**: Gold to white gradient (champagne celebration colors)
- **Physics**: Upward velocity with gravity for realistic firework arc
- **Duration**: 1.5 second particle lifetime, bursts auto-cleanup

**Trigger Conditions:**
- Challenge completion via challenge manager signals
- Position anchored to challenge spine on corkboard
- Automatic cleanup of particle nodes after animation

**Implementation Files:**
- **ChallengeCelebration**: `Scripts/Effects/challenge_celebration.gd` - Celebration manager
- **Particle Scene**: `Scenes/Effects/ChallengeCelebration.tscn` - GPU particle configuration

### Debuff Animation System
Negative score contributions now feature dramatic visual feedback:

**Visual Effects:**
- **Red Floating Numbers**: Negative values float up with red coloring (same style as positive scores)
- **Camera Shake**: Brief shake effect on significant penalties (scales with penalty size)
- **Red Vignette Pulse**: Screen edges flash red briefly (intensity scales with penalty)
- **Source Animation**: Debuff icons shake to indicate their contribution

**Animation Scaling:**
- Small penalties (< 10 points): Minimal effects
- Medium penalties (10-50 points): Moderate shake and vignette
- Large penalties (50+ points): Intense camera shake and prominent vignette

**Integration:**
- Triggered during Phase 2.5 of scoring animation sequence
- Works with existing scoring animation controller
- Respects animation speed settings

### Shop Button Glow
The shop button now glows when available, matching the roll button behavior:

**Pulse Animation:**
- **Golden Tint**: Subtle color modulation (1.3, 1.2, 0.9)
- **Scale Pulse**: Grows to 1.05x scale rhythmically
- **0.5s Duration**: Smooth loop timing
- **Auto-Activate**: Starts when shop is available and player has money

### Challenge Hover Tooltip
Hovering over the Challenge Spine displays detailed challenge information:

**Tooltip Content:**
- **Challenge Name**: Bold title at top
- **Target Score**: Points required to complete
- **Current Progress**: Live progress vs target
- **Reward**: Money reward for completion (if applicable)

**Hover Behavior:**
- **0.3s Delay**: Matches other tooltip delays in the game
- **Smart Positioning**: Adjusts to avoid screen edges
- **Auto-Hide**: Disappears immediately on mouse exit

### Synergy System
The **Synergy System** rewards players for collecting PowerUps with matching ratings, creating strategic depth in PowerUp selection:

**Core Mechanics:**
- **Matching Set Bonus**: Collect 5 PowerUps of the same rating → +50 additive bonus per set
- **Rainbow Bonus**: Collect one PowerUp of each rating (G, PG, PG-13, R, NC-17) → 5x multiplier
- **Rating Display**: Each PowerUp spine shows its rating at the bottom (shortened: PG-13→"13", NC-17→"17")

**Rating Tiers:**
| Rating | Spine Display | Color | Description |
|--------|---------------|-------|-------------|
| G | G | Green | General audience - family friendly |
| PG | PG | Yellow | Parental guidance suggested |
| PG-13 | 13 | Orange | Parents strongly cautioned |
| R | R | Red | Restricted - Mom confiscates |
| NC-17 | 17 | Dark Red | Adults only - Mom confiscates + debuff |

**Synergy Bonuses:**
- **Set Bonus (Additive)**: For each complete set of 5 same-rated PowerUps, gain +50 additive points
  - Example: 10 G-rated PowerUps = 2 sets = +100 additive bonus
- **Rainbow Bonus (Multiplier)**: Having at least one of each rating (G, PG, PG-13, R, NC-17) grants 5x multiplier
  - Example: G, PG, 13, R, 17 = Rainbow bonus = 5x score multiplier
- **Stacking**: Set bonuses stack additively, rainbow bonus is either active (5x) or inactive (1x)

**Score Integration:**
- Synergy bonuses register with `ScoreModifierManager` as named sources
- Set bonuses appear as: `synergy_G_sets`, `synergy_PG_sets`, etc.
- Rainbow bonus appears as: `synergy_rainbow`
- Bonuses automatically recalculate when PowerUps are granted or revoked

**PowerUp Spine Display:**
- Each spine shows abbreviated title at top and rating at bottom
- Rating colors match tier (G=green, PG=yellow, 13=orange, R=red, 17=dark red)
- Helps players visually track their rating collection at a glance

**Debug Commands (Synergies Tab):**
- **Show Synergy Status**: Print complete status to console
- **Grant 5 X-Rated**: Grant 5 PowerUps of specific rating for testing
- **Grant Rainbow Set**: Grant one of each rating
- **Clear All PowerUps**: Remove all active PowerUps
- **Show Rating Counts**: Display current counts per rating
- **Show Active Bonuses**: Display currently active synergy bonuses

**Implementation Files:**
- **SynergyManager**: `Scripts/Managers/SynergyManager.gd` - Synergy tracking and calculation
- **SynergyManager Scene**: `Scenes/Managers/synergy_manager.tscn` - Manager node
- **PowerUpSpine Updates**: `Scripts/UI/power_up_spine.gd` - Rating display on spines
- **PowerUpData Rating**: `Scripts/PowerUps/PowerUpData.gd` - Rating property on data resources
- **Test Scene**: `Tests/SynergyTest.tscn` - Synergy system validation

**Usage Example:**
```gdscript
# SynergyManager automatically tracks via GameController signals
# Get current synergy status:
var counts = synergy_manager.get_rating_counts()
var bonuses = synergy_manager.get_active_synergies()
var has_rainbow = synergy_manager.has_rainbow_bonus()
var total_matching = synergy_manager.get_total_matching_bonus()
```

### UI Architecture
- **Spine/Fan System**: Cards can be displayed as compact spines or fanned out for interaction
- **PowerUpUI** (`Scripts/UI/power_up_ui.gd`) - Manages power-up display
- **ConsumableUI** (`Scripts/UI/consumable_ui.gd`) - Manages consumable display
- **ShopUI** (`Scripts/UI/shop_ui.gd`) - In-game purchasing

### Hover Tooltip System
All interactive game items feature consistent, themed hover tooltips:
- **Enhanced Styling**: Direct StyleBoxFlat application with 4px golden borders and 16px/12px padding
- **Thick Visible Borders**: 4px golden border (Color: 1, 0.8, 0.2, 1) with shadow effects for visibility
- **Generous Padding**: 16px horizontal, 12px vertical padding for comfortable text spacing
- **VCR Font Integration**: Retro gaming font with outline for better readability
- **Item Icons**: PowerUps, Consumables, Debuffs, Challenges, and Mods show descriptions on hover
- **Colored Dice**: Display effect descriptions (Green=$money, Red=+points, Purple/Blue=×multiplier)
- **Shop Items**: Show detailed descriptions when hovering over purchasable items with custom styling
- **Spine Tooltips**: Hover over spine UI elements to see complete item lists
- **Programmatic Implementation**: Direct StyleBoxFlat application ensures reliable theming

### Action Button Theme System
SELL and USE buttons throughout the game feature consistent themed styling:
- **Direct Style Application**: Custom StyleBoxFlat creation for reliable programmatic theming
- **Thick Golden Borders**: 3px borders with distinct colors for each state (normal/hover/pressed)
- **VCR Font Consistency**: Retro gaming font with outline effects
- **Multiple Visual States**: 
  - Normal: Dark background with golden border (1, 0.8, 0.2, 1)
  - Hover: Lighter background with brighter border (1, 0.9, 0.3, 1)
  - Pressed: Brightest background with yellow border (1, 1, 0.4, 1)
- **PowerUp SELL Buttons**: Themed sell buttons with debug output for verification
- **Consumable USE Buttons**: Themed use buttons with identical styling
- **Mod SELL Buttons**: High z-index themed buttons for proper UI layering
- **Reliable Implementation**: Direct theme override application ensures consistent appearance

### Item Selling System
All game items (PowerUps, Consumables, and Mods) support selling mechanics:
- **Click to Sell**: Click any item icon to show a "SELL" button above it
- **Half-Price Refund**: Items sell for 50% of their original purchase price
- **Mod Selling**: Mods attached to dice can be sold by clicking their small icons on dice
- **Outside Click**: Click outside an item to hide the sell button
- **Signal Chain**: Item icons → UI managers → GameController → PlayerEconomy

### Dice Display System
The dice display system provides dynamic positioning and animations for dice:

**Centered Positioning:**
- Dice are automatically centered horizontally regardless of count
- Supports 1-16 dice with single or multi-row layouts
- Balanced distribution: 9 dice → 5 top row, 4 bottom row

**Multi-Row Support:**
- Up to 8 dice per row (configurable via `max_dice_per_row`)
- Maximum 2 rows for 16 dice total
- Each row is independently centered

**Configuration (dice_hand.gd):**
- `dice_area_center`: Center point for dice display (default: 640, 200)
- `dice_area_size`: Bounding area for dice (default: 680x200)
- `spacing`: Horizontal spacing between dice (default: 80px)
- `row_spacing`: Vertical spacing between rows (default: 90px)

**Entry Animations:**
- Dice enter from varied directions (top, bottom, left, right, diagonals)
- Direction pattern varies based on dice count and position
- Staggered animation timing for visual appeal
- Bounce easing for playful feel

**Exit Animations:**
- Triggered after scoring a hand
- Dice exit in opposite direction from entry
- Scale down and fade out effect
- Staggered timing synchronized with entry

**Roll Button Pulse:**
- Roll button pulses with golden glow when waiting for first roll
- Subtle scale animation (1.0 → 1.05)
- Automatically stops when roll button pressed
- Helps draw attention to next action

**Test Scene:** `Tests/DiceDisplayTest.tscn`
- Press 1-8 for single row tests
- Press 9 for 9 dice (5+4 multi-row)
- Press 0 for 16 dice (8+8 max)
- Press E for exit animation test
- Press R to respawn dice

### Testing Framework
Test scenes in `Tests/` folder allow isolated testing of components:
- `DiceTest.tscn` - Dice rolling and behavior
- `DiceDisplayTest.tscn` - Dice positioning and animations
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
- **PinHeadPowerUp**: When scoring, picks a random dice value as multiplier (e.g., score 30 with random dice 3 = 90 points)
- **HighlightedScorePowerUp**: Highlights one random unscored category with golden border; highlighted category gets 1.5x multiplier when scored (Rare, $300)

### Economy PowerUps
- **BonusMoneyPowerUp**: +$50 for each bonus achieved (Upper Section or Yahtzee bonuses)
- **ConsumableCashPowerUp**: +$25 for each consumable used
- **MoneyMultiplierPowerUp**: +0.1x money multiplier per Yahtzee rolled (NEW)
- **TheConsumerIsAlwaysRightPowerUp**: +0.25x score multiplier per consumable used (Epic, $400)
  - Multiplier persists even if PowerUp is sold, based on permanent usage statistics
  - Example: After using 3 consumables, all scores are multiplied by 1.75x
  - Synergizes excellently with consumable-heavy strategies

### PowerUp Ratings
All PowerUps have content ratings that interact with the Mom system:
- **G/PG/PG-13**: Safe ratings - no penalty from Mom
- **R**: Restricted - Mom confiscates the PowerUp when progress reaches 100
- **NC-17**: Adults only - Mom confiscates AND applies "Grounded" debuff
- Ratings are displayed in PowerUp hover tooltips (e.g., "[R] PowerUp Name")
- See "Chores & Mom System" section for full details

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

### Score Card Upgrade Consumables
Score Card Upgrade consumables permanently increase the level of specific scoring categories. When a category is upgraded, its base score is multiplied by the level before other modifiers are applied.

**Calculation Order:** `(base_score × category_level) + additives × multipliers`

**Upper Section Upgrades** (Price: $150 each)
- **Ones Upgrade**: Upgrade the Ones category (+1 level)
- **Twos Upgrade**: Upgrade the Twos category (+1 level)
- **Threes Upgrade**: Upgrade the Threes category (+1 level)
- **Fours Upgrade**: Upgrade the Fours category (+1 level)
- **Fives Upgrade**: Upgrade the Fives category (+1 level)
- **Sixes Upgrade**: Upgrade the Sixes category (+1 level)

**Lower Section Upgrades** (Price: $200 each)
- **Three of a Kind Upgrade**: Upgrade the Three of a Kind category (+1 level)
- **Four of a Kind Upgrade**: Upgrade the Four of a Kind category (+1 level)
- **Full House Upgrade**: Upgrade the Full House category (+1 level)
- **Small Straight Upgrade**: Upgrade the Small Straight category (+1 level)
- **Large Straight Upgrade**: Upgrade the Large Straight category (+1 level)
- **Yahtzee Upgrade**: Upgrade the Yahtzee category (+1 level)

**Master Upgrade** (Price: $500)
- **All Categories Upgrade**: Upgrades ALL 12 scoring categories by one level at once

**Example:**
- Ones at Level 3: Roll three 1s → Base 3 × Level 3 = 9 points (before additives/multipliers)
- Yahtzee at Level 2: Roll five 6s → Base 50 × Level 2 = 100 points

**Visual Feedback:**
- Score card displays "Lv.N" next to each upgraded category (gold text)
- Scoring animations show the level multiplier "×N" floating above dice
- Labels only appear for categories at Level 2 or higher

**Notes:**
- There is no maximum level cap - categories can be upgraded indefinitely
- Levels reset when a new game starts
- Level multiplier is applied FIRST, before additives and other multipliers
- Stacks well with other score modifiers for massive scoring potential

### Scoring Aids
- **AnyScore**: Score current dice in any open category, ignoring normal requirements
- **ScoreReroll**: Reroll all dice, then auto-score best category
- **One Extra Dice**: Add +1 dice to the next hand only, removed after scoring (Price: $50)
  - Temporarily increases dice count from 5 to 6 for the next turn
  - Extra dice is automatically removed when any score is assigned (manual or auto)
  - Similar to Extra Dice PowerUp but temporary and single-use
  - Useful for difficult hands that need one more dice for a good score

### Economy
- **Green Envy**: 10x multiplier for all green dice money scored this turn (Price: $50)
- **Poor House**: Transfer all your money to add bonus points to the next scored hand (Price: $100)

### Strategic Multipliers
- **Empty Shelves**: Multiply next score by the number of empty PowerUp slots (Price: $150)
  - Can only be used when dice are rolled and ready to be scored
  - Example: With 4 empty PowerUp slots, a Full House worth 25 points becomes 100 points
  - Synergizes well with minimal PowerUp builds for maximum multiplier effect
- **Double or Nothing**: High-risk, high-reward consumable (Price: $150)
  - Use after pressing Next Turn (after auto-roll) but before manual rolling
  - If a Yahtzee is rolled during that turn, the Yahtzee score is doubled (50 → 100 points)
  - If no Yahtzee is rolled, the next score placed becomes 0
  - Strategic timing is crucial - use only when confident in rolling a Yahtzee
- **Go Broke or Go Home**: Ultimate high-risk economic gamble (Price: $200)
  - Use after pressing Next Turn, then manually select a lower section category only
  - If you score greater than 0, your money is doubled
  - If you score 0, you lose all your money
  - Only lower section categories can be selected (Three of a Kind, Four of a Kind, Full House, Small Straight, Large Straight, Yahtzee, Chance)
  - Most dangerous consumable - can lead to massive wealth or total bankruptcy

### PowerUp Acquisition
- **Random Uncommon Power-Up**: Grants a random uncommon rarity power-up

### PowerUp Economy
- **The Rarities**: Pays cash based on owned PowerUps by rarity (Price: $100)
  - Common: $20 each
  - Uncommon: $25 each  
  - Rare: $50 each
  - Epic: $75 each
  - Legendary: $150 each
  - Can be used at any time to convert PowerUp collection into immediate cash
  - Useful for funding expensive purchases or when needing quick money

- **The Pawn Shop**: Sells ALL owned PowerUps for 1.25x their purchase price (Price: $150)
  - **WARNING**: This permanently removes ALL PowerUps from your collection
  - Example: A $300 PowerUp becomes $375 cash
  - Only usable when you own at least one PowerUp
  - High-risk, high-reward strategy for major cash influx
  - Use when you need significant money for expensive purchases
  - Consider carefully as this resets your entire PowerUp collection

### Usage Notes
- Consumables are single-use items
- AnyScore is particularly useful for filling difficult categories
- Green Envy is most effective when you have multiple green dice
- Random PowerUps provide strategic risk/reward decisions

## Available Mods

Mods are special attachments that can be applied to individual dice to change their behavior. Each die can have one mod at a time, and mods persist until sold or the game ends.

### Dice Value Modifiers
- **EvenOnlyMod**: Forces die to only roll even numbers (2, 4, 6)
- **OddOnlyMod**: Forces die to only roll odd numbers (1, 3, 5)
- **ThreeButThreeMod**: Always rolls 3 and grants $3 per roll
- **FiveByOneMod**: Always rolls 1 but grants $5 per roll

### Special Behaviors
- **GoldSixMod**: When rolling a 6, grants additional money based on game state
- **WildCardMod**: Provides random special effects on each roll
- **HighRollerMod**: Cannot be locked; click to reroll for increasing Fibonacci costs (0,1,1,2,3,5,8...)
  - Prevents the die from being locked/unlocked
  - Click the die to perform a manual reroll
  - Each reroll (manual or from normal roll button) increases cost following Fibonacci sequence
  - Only manual clicks deduct money; normal rolls increment cost but don't charge
  - Strategic high-risk mod for players who want more control over individual dice

### Usage Notes
- Each die can only have one mod attached at a time
- Mods can be purchased from the shop and applied to any die
- Click a mod's icon on a die to sell it for 50% refund
- Mods affect dice behavior immediately when applied
- Some mods provide economic benefits while others focus on dice control

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
- **Dice Colors**: Toggle color system, force all dice to specific colors (Green/Red/Purple/Blue), show effects
- **Game Flow**: Add extra rolls, force end turn, skip to shop
- **Chores**: Add progress, complete tasks, trigger Mom, test dialog expressions
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
- ✅ Progress tracking system - Persistent player progression with unlock conditions (implemented)
- ✅ Chores & Mom system - Strategic tension mechanic with parental consequences (implemented)
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
- Do not run a taskkill command: taskkill /F /IM Godot_v4.4.1-stable_win64.exe

### Technical Debt
- UI card construction has some duplication (base class available at `Scripts/UI/card_icon_base.gd`)
- Spine/fan UI systems could share more common code
- Some power-ups have duplicated signal lifecycle patterns

These issues are documented and tracked but don't impact functionality.

