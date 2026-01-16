# Statistics System

## Overview
The Statistics system tracks all player actions and game metrics throughout their play session. This data will be used for:
- Player analytics and progress tracking
- Dynamic power-ups and consumables that scale with player behavior
- Debug information and game balance analysis
- Future achievements and unlocks system

## Statistics Categories

### Core Game Metrics
- `total_turns`: Number of turns taken in current session
- `total_rolls`: Total dice rolls performed
- `total_rerolls`: Number of rerolls used
- `hands_completed`: Number of scoring hands achieved
- `failed_hands`: Number of turns with no valid scoring hand

### Economic Metrics
- `total_money_earned`: All money gained from scoring
- `total_money_spent`: All money spent in shops
- `money_spent_on_powerups`: Subset of total spent
- `money_spent_on_consumables`: Subset of total spent
- `money_spent_on_mods`: Subset of total spent
- `current_money`: Player's current money amount

### Dice Metrics
- `dice_rolled_by_color`: Dictionary tracking rolls per dice color
- `dice_locked_count`: Total dice locked during rerolls
- `highest_single_roll`: Highest value rolled on any die
- `snake_eyes_count`: Number of times rolled all 1s
- `yahtzee_count`: Number of Yahtzees achieved
- `even_dice_scored_this_round`: Count of even-valued dice scored this round (resets each round)
- `odd_dice_scored_this_round`: Count of odd-valued dice scored this round (resets each round)

### Hand Type Statistics
- `ones_scored`: Times scored in Ones category
- `twos_scored`: Times scored in Twos category
- `threes_scored`: Times scored in Threes category
- `fours_scored`: Times scored in Fours category
- `fives_scored`: Times scored in Fives category
- `sixes_scored`: Times scored in Sixes category
- `three_of_kind_scored`: Times scored Three of a Kind
- `four_of_kind_scored`: Times scored Four of a Kind
- `full_house_scored`: Times scored Full House
- `small_straight_scored`: Times scored Small Straight
- `large_straight_scored`: Times scored Large Straight
- `yahtzee_scored`: Times scored Yahtzee
- `chance_scored`: Times scored Chance

### Power-Up & Item Usage
- `powerups_purchased`: Total power-ups bought
- `consumables_purchased`: Total consumables bought
- `mods_purchased`: Total mods bought
- `powerups_used`: Total power-ups activated
- `consumables_used`: Total consumables consumed

### Session Metrics
- `session_start_time`: When current session began
- `total_play_time`: Cumulative play time in seconds
- `highest_score`: Best score achieved in session
- `longest_streak`: Longest consecutive scoring streak

## Architecture

### StatisticsManager (Autoload Singleton)
**Path**: `Scripts/Managers/statistics_manager.gd`
- Extends Node, configured as autoload named "Statistics"
- Tracks all statistics in real-time
- Provides getter/setter methods for each statistic
- Emits signals when significant milestones are reached
- Handles persistence (save/load) of statistics

### StatisticsUI Panel
**Path**: `Scenes/UI/StatisticsPanel.tscn` & `Scripts/UI/statistics_panel.gd`
- Toggle visibility with F10 key
- Tabbed interface showing different statistic categories
- Real-time updates while panel is visible
- Clean, readable formatting with proper labels

## Current Implementation Status

### ✅ Completed Features
- **StatisticsManager autoload singleton** - Fully implemented and active
- **Basic statistic storage and retrieval** - All core metrics tracked
- **Increment/decrement methods** - Complete API for all statistics
- **Session timing functionality** - Tracks play time and session data
- **Dice rolling system integration** - Connected to dice roll events
- **Scoring system integration** - Tracks hand completions and scores
- **Shop system integration** - Tracks purchases and spending
- **Power-up and consumable usage tracking** - Full item usage statistics
- **Money management integration** - Comprehensive economic tracking
- **StatisticsPanel UI** - F10 toggle with tabbed interface
- **Real-time updates** - Live refreshing while panel is visible
- **Dice lock tracking** - Connected to dice_hand.die_locked signal
- **Detailed logbook system** - Complete hand scoring history with modifiers

### 🔧 Recent Bug Fixes
- **Dice Color Tracking**: Fixed case sensitivity issues in color normalization
- **Duplicate Hand Scoring**: Eliminated double counting in score button handling  
- **Poor House Autoscoring**: Fixed bonus persistence after manual scoring
- **Logbook Source Attribution**: Enhanced calculation summaries with specific source details
- **Dice Lock Statistics**: Connected die_locked signal to statistics tracking

## Implementation TODO List

### Phase 4: Advanced Features
- [ ] Add milestone detection and celebration
- [ ] Implement statistic-based power-up conditions
- [ ] Add export functionality for debugging
- [ ] Create reset functionality for testing
- [ ] Add persistence system for cross-session tracking

### Phase 5: Power-Up Integration
- [ ] Create power-ups that scale with roll count
- [ ] Add consumables that trigger on specific statistics
- [ ] Implement achievements based on statistic thresholds
- [ ] Create dynamic difficulty scaling based on player performance

## API Design

### Key Methods
```gdscript
# Increment counters
Statistics.increment_turns()
Statistics.increment_rolls()
Statistics.increment_money_spent(amount)

# Track dice behavior
Statistics.track_dice_roll(color, value)
Statistics.track_dice_lock()

# Record hand completions
Statistics.record_hand_scored(hand_type, score)

# Get current values
Statistics.get_total_rolls()
Statistics.get_money_efficiency()
Statistics.get_favorite_dice_color()

# Advanced queries
Statistics.get_scoring_percentage()
Statistics.get_average_score_per_hand()
```

### Signals
```gdscript
# Milestone achievements
signal milestone_reached(milestone_name: String, value: int)
signal new_record_set(statistic_name: String, new_value)
signal session_summary_ready(summary_data: Dictionary)
```

## Integration Points

### GameController
- Initialize statistics on game start
- Handle F10 key input for statistics panel
- Update session timing

### DiceManager
- Track all dice rolls and rerolls
- Record dice colors and values
- Monitor locking behavior

### ScoreManager
- Record all hand completions and scores
- Track failed scoring attempts
- Monitor scoring streaks

### Shop System
- Record all purchases by category
- Track money flow and spending patterns

### PowerUp/Consumable Systems
- Record usage statistics
- Enable statistic-based activation conditions

## Future Expansions

### Cross-Session Persistence
- Save statistics to user data
- Accumulate lifetime statistics
- Enable progression unlocks

### Analytics Dashboard
- Detailed performance analysis
- Trend tracking over time
- Comparative statistics

### Dynamic Content
- Procedurally generated challenges based on play style
- Adaptive difficulty system
- Personalized power-up recommendations

## Testing Strategy
- Create unit tests for StatisticsManager methods
- Build integration tests for game system connections
- Develop UI tests for panel functionality
- Add performance tests for real-time updates