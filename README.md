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

1. **Main Scene**: `Scenes/UI/MainMenu.tscn` (launches Main Menu)
2. **Game Scene**: `Tests/DebuffTest.tscn` (full game with all components)
3. **Run in Editor**: Open project in Godot 4.4+, press F5
4. **Testing**: Use scenes in `Tests/` folder for isolated component testing

## Main Menu & Settings

### Main Menu
- **Location**: `Scenes/UI/MainMenu.tscn`, `Scripts/UI/main_menu.gd`
- **Features**:
  - Animated floating "GUHTZEE" title using BRICK_SANS font
  - 3 profile slots (P1/P2/P3) - click to select, right-click to rename
  - "Playing as: [ProfileName]" label showing active profile
  - New Game / Settings / Quit navigation buttons
  - Profile data includes games completed and highest channel reached

### Arcade Shader Collection
Custom shader library capturing the late 80's/early 90's arcade/mall/SNES-era aesthetic with purple/teal neon themes.

#### Background Shaders (20)
| Shader | Style |
|--------|-------|
| **Plasma Screen** (`plasma_screen.gdshader`) | Organic demoscene plasma blobs (Amiga/C64 era) |
| **Arcade Carpet** (`arcade_carpet.gdshader`) | 90s geometric tile patterns (3 modes: Diamond, Starburst, Memphis) |
| **Marquee Lights** (`marquee_lights.gdshader`) | Theater/casino chasing bulb borders |
| **Neon Grid** (`neon_grid.gdshader`) | Tron-inspired perspective grid with glowing lines |
| **VHS Static Wave** (`vhs_wave.gdshader`) | Analog TV interference with chromatic aberration |
| **Arcade Starfield** (`arcade_starfield.gdshader`) | Multi-layer parallax stars with color cycling |
| **Background Swirl** (`backgground_swirl.gdshader`) | Paint swirl effect (legacy, Balatro-sourced) |
| **Jazz Cup** (`jazz_cup.gdshader`) | 90s Solo Jazz paper cup swooshes |
| **Memphis Geo** (`memphis_geo.gdshader`) | Memphis Group scattered geometric shapes |
| **Zigzag Bolts** (`zigzag_bolts.gdshader`) | Saved By The Bell bold zigzag stripes |
| **Neon City** (`neon_city.gdshader`) | Scrolling cyberpunk cityscape with neon signs |
| **Neon Raindrop** (`neon_raindrop.gdshader`) | Trapper Keeper 3D water droplets on gradient |
| **Neon Objects** (`neon_objects.gdshader`) | Trapper Keeper floating 3D shapes on grid |
| **Paint Splatter** (`paint_splatter.gdshader`) | Animated neon splats accumulating & cycling |
| **Mystify Screen** (`mystify_screen.gdshader`) | Windows 3.1 Mystify Your Mind screensaver |
| **Nick Splat** (`nick_splat.gdshader`) | 90s Nickelodeon chaos doodles on orange |
| **Laser Show** (`laser_show.gdshader`) | 80s arena laser beams through smoke |
| **Pinball Machine** (`pinball_machine.gdshader`) | 80s pinball playfield with bumpers & rails |
| **Cassette Reel** (`cassette_reel.gdshader`) | 80s cassette tape with spinning reels |
| **Roller Rink** (`roller_rink.gdshader`) | 80s roller rink floor with disco lights |

#### UI Effect Shaders (3)
| Shader | Purpose |
|--------|---------|
| **Enhanced Glow** (`glow_overlay.gdshader`) | Chromatic aberration, pulsing, rainbow mode, distortion |
| **Holographic Energy** (`power_up_ui.gdshader`) | Sci-fi hologram with hex grid and scanline sweep |
| **Dramatic Burst** (`consumable_explosion.gdshader`) | Multi-stage explosion with streaks, debris, shockwave |

#### Features
- Consistent color uniform system (colour_1, colour_2, colour_3) across all background shaders
- Tunable pixel_filter parameter (200-1000) for retro pixelation
- Distinct speed controls per shader
- Purple/teal default color schemes matching game palette
- Optimized for 60 FPS performance
- UI shaders are backward compatible with existing code

#### Shader Gallery Test Scene
Preview all background shaders interactively:
```
Tests/ShaderGallery.tscn
```
Keys 1-0 for shaders 1-10, Shift+1-0 for 11-20, Up/Down for 21-22, C for side-by-side comparison, Left/Right to change comparison target.

#### Shader Debug Test Scene
Isolates the **neon_energy** and **score_panel_energy** shaders used on the ScoreCard UI:
```
Tests/ShaderDebugTest.tscn
```
- Additive panel (gold neon_energy), Multiplier panel (cyan neon_energy), Score panel (score_panel_energy)
- Sliders for **Effect Strength** (0—1) and **Intensity** (0—2)
- Tier +/- buttons to cycle milestone tiers (0—4) on the score panel shader
- Division toggle to switch multiplier between cyan (normal) and red (division mode)

#### Switching Background Shaders
Edit `Scripts/UI/main_menu.gd` in the `_build_ui()` method. Load your desired shader:
```gdscript
# Options (uncomment one):
var shader = load("res://Scripts/Shaders/plasma_screen.gdshader")      # Demoscene plasma
#var shader = load("res://Scripts/Shaders/arcade_carpet.gdshader")     # 90s geometric
#var shader = load("res://Scripts/Shaders/marquee_lights.gdshader")    # Theater lights
#var shader = load("res://Scripts/Shaders/neon_grid.gdshader")         # Tron grid
#var shader = load("res://Scripts/Shaders/vhs_wave.gdshader")          # VHS wave
#var shader = load("res://Scripts/Shaders/arcade_starfield.gdshader")  # Space stars
```

Full documentation with parameters, recipes, and technical deep-dives: See `ARCADE_SHADERS.md`

### Profile System
- **ProgressManager** handles 3 save slots (`user://profile_1.save` to `profile_3.save`)
- Legacy save migration: Old `user://save.json` auto-migrates to slot 1
- **Save Version 2**: Current format tracks chore completions, category scores, and difficulty stats
  - Old v1 profiles are auto-detected on load, user is notified, then deleted and recreated
- Profile names limited to 30 characters
- Statistics tracked per-profile: games completed, games won, highest channel, chores completed, category scores, etc.
- **IMPORTANT**: GameSettings must be loaded BEFORE ProgressManager in autoload order
  - ProgressManager reads `active_profile_slot` from GameSettings on startup
  - If order is wrong, profile 2/3 unlocks won't work correctly

### Item Unlock & Difficulty System
- All ~100 unlockable items (PowerUps, Consumables, Mods, Colored Dice) have a **difficulty rating** (1-10)
- Difficulty scales with item power: starter items at 1, ultimate items at 10
- **Diversified unlock conditions** include:
  - `GAMES_PLAYED`, `GAMES_WON`, `HIGH_SCORE`, `TOTAL_SCORE`
  - `CHALLENGES_COMPLETED`, `ROUNDS_SURVIVED`, `REACH_ROUND`, `COMPLETE_CHANNEL`
  - `SCORE_THRESHOLD_CATEGORY` (NEW): Score ≥ threshold in a specific Yahtzee category
  - `CHORE_COMPLETIONS` (NEW): Complete N chores total (cumulative or single-game)
- See [Docs/item_difficulty_ratings.md](Docs/item_difficulty_ratings.md) for the full item reference

### Settings System
- **GameSettings** (autoload) - Centralized settings management
  - **Location**: `Scripts/Managers/game_settings.gd`
  - **Config File**: `user://settings.cfg` (ConfigFile format)
  - **Settings Categories**:
    - **Audio**: SFX Volume (0-100%), Music Volume (0-100%) - immediate preview
    - **Video**: Resolution selection, Fullscreen toggle - requires Apply button
    - **Gameplay**: Scoring Animation Speed (0.5x-2.0x)
    - **Keyboard**: Rebindable keys for Roll, Confirm, Menu, Lock Dice 1-5
    - **Controller**: Rebindable gamepad buttons for same actions

### Pause Menu
- **Location**: `Scenes/UI/PauseMenu.tscn`, `Scripts/UI/pause_menu.gd`
- **Activation**: Press Escape during gameplay
- **Features**: Resume, Settings, Return to Main Menu options
- **Note**: Pauses game tree when shown

## Core Architecture

### Game Flow
- **GameController** (`Scripts/Core/game_controller.gd`) - Central coordination
- **RoundManager** (`Scripts/Managers/round_manager.gd`) - Round progression  
- **TurnTracker** (`Scripts/Core/turn_tracker.gd`) - Roll counting and turn logic

### Dice System
- **Dice** (`Scripts/Core/dice.gd`) - Individual die behavior
- **DiceHand** (`Scripts/Core/dice_hand.gd`) - Collection of 5 dice
- **DiceResults** (autoload) - Result data structure
- **DiceData** (`Scripts/Dice/DiceData.gd`) - Resource defining dice type (sides, textures)
- **DiceColor** (`Scripts/Core/dice_color.gd`) - Color system for dice enhancement
- **DiceAnimationIntensity** (`Scripts/Effects/dice_animation_intensity.gd`) - Score/challenge-linked animation scaling

#### Dice Animation System

All dice use multi-phase tween animations with bounce easing, randomization, and intensity scaling.

| Animation | Trigger | Description |
|-----------|---------|-------------|
| **Mouse Tilt** | Hover | 3D perspective rotation via `x_rot`/`y_rot` shader uniforms, following mouse position |
| **Squash/Stretch Roll** | Roll | 4-phase: anticipation squash → launch stretch + hop → impact squash → elastic settle |
| **Roll Stagger** | Roll All | Each die rolls with a `roll_stagger_delay` (0.08s) between them, preceded by anticipation tremble |
| **Bouncy Entry** | Spawn | 3-phase: fly in with overshoot → bounce back → elastic settle. Scale, rotation, and alpha all animate |
| **Explosion Exit** | Score/Exit | Scale punch + white flash → fly out with perpendicular scatter, spin, scale, and alpha fade |
| **Anticipation Tremble** | Pre-roll | 8-step position jitter with increasing intensity before dice roll |
| **Shockwave Ring** | Post-roll | Radial expanding ring shader (`dice_shockwave.gdshader`) spawned after each die settles |
| **Idle Breathing** | Rolled/Locked | Subtle Y bob (±2px) and scale breathing via `sin(TIME + phase_offset)`. Stops on hover |
| **Celebration Cascade** | High score | Left-to-right hop wave across all dice with squash/stretch, triggered at intensity ≥ 1.6 |
| **Critical Flash** | High score | All dice flash white + screen shake, triggered at intensity ≥ 1.6 |
| **Screen Shake** | High score | Rapid DiceHand position offsets for 0.15s |

**Intensity Scaling**: Animation parameters (bounce height, speed, rotation, shockwave size, idle amplitude) scale dynamically based on challenge progress (0-1) and total score milestone tier (0-4). Calculated by `DiceAnimationIntensity.calculate()` and distributed to dice via `intensity_params` dictionary.

**Shaders**:
- `dice_combined_effects.gdshader` — Glow, lock overlay, disabled pulse, 5 color effects, and perspective tilt (`x_rot`/`y_rot` vertex transforms)
- `dice_shockwave.gdshader` — Radial expanding ring with `progress`, `ring_width`, `ring_color`, `max_radius` uniforms

**Test Scene**: `Tests/DiceAnimationTest.tscn` — Interactive test with Spawn/Roll/Exit/Celebrate/Shake/Flash buttons, score slider (0-1500), and challenge progress slider (0-100%).

#### UI Popup Animations

All major UI popups use TweenFX-based bouncy entrance/exit animations for juicy game feel.

| UI System | Entrance | Exit | Notes |
|-----------|----------|------|-------|
| **ChannelManagerUI** | VHS shader overlay fade → "CHOOSE YOUR CHANNEL" label drop-in → TV remote panel bounce | Panel flies down → shader fades → overlay fades | Uses `vhs_wave.gdshader` overlay |
| **ChoreSelectionPopup** | Overlay fade + `TweenFX.drop_in` bounce from top + jelly settle | `TweenFX.drop_out` fly-off + overlay fade | — |
| **PauseMenu** | Overlay fade + `TweenFX.drop_in` from top + jelly wobble | `TweenFX.drop_out` flies UP (negative height) + fade | Uses `_is_animating` guard |
| **MomCharacter** | Overlay fade + `TweenFX.drop_in` bounce from below + jelly on panel & sprite | Hop on Mom sprite → `TweenFX.drop_out` fly down + fade | Dramatic personality wobble |
| **PowerUp Sell** | Jelly wobble → spin + shrink → fly toward money counter | — | Targets `MoneyLabel` global position |
| **PowerUp Expiry** | Alarm flash highlight → fidget wild spin → fly to random screen edge + vanish | — | Orange alarm color |
| **Mom Confiscation** | Auto-fan cards → red alarm flash on condemned → fidget + fly-to-Mom + vanish (staggered) | Folds cards back | Stagger: 0.2s (≤3 items) or 0.1s (>3) |
| **Consumable Sell** | Jelly wobble → spin + shrink → fly toward money counter | — | Same pattern as PowerUp sell |
| **Consumable Use** | Fidget wild spin → fly to random edge → `ConsumableExplosion` at exit | — | Explosion effect at exit point |

#### Dice Types
DiceRogue supports multiple dice types, each with their own face textures and value ranges:

| Type | Sides | Resource | Status |
|------|-------|----------|--------|
| d4   | 4     | `Scripts/Dice/d4_dice.tres` | Active |
| d6   | 6     | `Scripts/Dice/d6_dice.tres` | Active (default) |
| d8   | 8     | `Scripts/Dice/d8_dice.tres` | Scoring active |
| d10  | 10    | `Scripts/Dice/d10_dice.tres` | Scoring active |
| d12  | 12    | `Scripts/Dice/d12_dice.tres` | Scoring active |
| d20  | 20    | `Scripts/Dice/d20_dice.tres` | Scoring active |

Dice types are assigned per-round via `ChallengeData.dice_type` and applied through `DiceHand.switch_dice_type()`. When a non-d6 dice type is active, the scoring system adapts automatically:
- **Dynamic 6th slot**: The upper section's 6th row changes to match the dice's max value (e.g., "Eights" for d8, "Twenties" for d20)
- **Upper bonus scaling**: The bonus threshold adjusts per dice type (63 for d6, 69 for d8, 105 for d20)
- **Generalized straights**: Small and large straight detection works with any dice size
- See `BUILD_DICE.md` for full design rules and balance considerations.

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
  - **New Wave PowerUps** (10 total): Purple Payout, Mod Money, Blue Safety Net, Chore Sprint, Straight Triplet Master, Modded Dice Mastery, Debuff Destroyer, Challenge Easer, Azure Perfection, Rainbow Surge
    - Themes: dice color synergies, mod-powerup synergies, straight combos, economy/chores, debuff management, challenge easing
  - **Risk & Reward PowerUps** (6 total):
    - **The Replicator** (Rare/$300): After 1 turn, duplicates a random PowerUp you own — with dramatic visual/audio effects
    - **The Piggy Bank** (Uncommon/$125): Saves $3 per roll; sell to cash out accumulated savings with animated coin effects
    - **Random Card Level** (Rare/$300): 20% chance each turn to level up a random scorecard category
    - **Yahtzeed Dice** (Epic/$450): Gain +1 die every time you roll a Yahtzee (max 16 dice)
    - **Consumable Collector** (Rare/$275): +0.1× score multiplier for each consumable used during the game
    - **Daring Dice** (Rare/$300): Remove 2 dice but gain permanent +50 score bonus per category
  - **Trade-off & Color PowerUps**:
    - **The Great Exchange** (Rare/$350): +2 dice, -1 roll per turn — more dice but fewer re-roll chances
    - **Extra Rainbow** (Rare/$300): +10 additive score per colored die scored — rewards color dice strategy
- **Consumables** (`Scripts/Consumable/`) - Single-use strategic items
  - **Lucky Upgrade** ($25): Randomly upgrades one unscored scorecard category by 1 level
  - **Half Price** ($25): Halves PowerUp prices in the shop. Stacks multiplicatively. Expires on first PowerUp purchase or new turn.
  - **Loss Leader** ($25): Next consumable purchase is free. Stacks — each use grants one additional free purchase. Persists across turns.
  - **Insurance Policy** ($25): If your next score is 0, receive $75 as consolation. Consumed after any scoring action.
  - **Clearance Rack** ($25): All shop rerolls are free until you close the shop.
  - **Loaded Dice** ($75): Randomly sets one of your dice to a random value (1-6).
- **Mods** (`Scripts/Mods/`) - Dice behavior modifiers
- **Gaming Consoles** (`Scripts/GamingConsole/`) - Unique console abilities (one active at a time)
  - **Shop Layout**: Consoles displayed in a 3-column grid (2 rows of 3) to prevent overflow; consoles remain visible after purchase with "LIMIT (1)" on the buy button
  - **NES / Power Glove**: After ACTIVATE, compact +1/-1 buttons spawn above each rolled/locked die; buttons clear on use or next roll. Dice value changes are synced to `DiceResults` so scoring reads updated values.
  - **SNES / Blast Processing**: ACTIVATE button glows yellow with "1.5x READY" text when the multiplier is primed; resets after consumption. Category counter tracks via `score_assigned` only (no double-counting on auto-scored categories).
  - **SEGA / Combo System**: Combo break detection uses the **base score** (before modifiers) so that Sega's own additive bonus cannot prevent zero-score resets. A pre-scoring hook (`about_to_score`) unregisters the combo additive **before** score calculation when the base score is 0, ensuring zero-base scores stay zero.
  - **SEGA Saturn / Cartridge Tilt**: Shifts all rolled/locked dice by +1 or −1; syncs `DiceResults` after modification so scoring uses updated values.
  - **PlayStation / Continue?**: When the scorecard is completely filled, a **Continue? panel** appears if PlayStation is active. The player can choose to **Use Continue** (+3 bonus rolls + score reroll mode) or **Quit** (proceed to Game Over). The `game_completed` signal fires immediately when the last category is scored—no need to press Next Turn.

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
  - **Dice Lock Sound**: `DICE_CLICK.wav` for dice selection feedback
    - Plays when dice are locked or unlocked
    - Slight random pitch variation (0.95-1.05) for natural feel
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
The **Channel Manager** provides a resource-based difficulty progression system (Channels 1-20):

**Features:**
- **TV Remote UI**: Select starting channel at game start with Up/Down buttons
- **Resource-Based Configuration**: Each channel defined by a `.tres` file with manually tuned settings
- **Unlock Pacing**: Higher channels require completing lower channels first
- **Multiple Scaling Multipliers**: Goal scores, shop prices, goof-off meter, Yahtzee bonuses, debuff intensity
- **Per-Round Difficulty**: Each round has its own challenge difficulty range
- **Persistent Completion**: Completed channels are saved and display a checkmark when browsing
- **Lock Feedback**: Locked channels show 🔒 icon and disable Start button

**Channel Configuration Resources:**
Each channel is configured via `Resources/Data/Channels/channel_XX.tres`:
- `display_name`: Human-readable name (e.g., "Tutorial", "Expert", "ULTIMATE")
- `goal_score_multiplier`: Scales target scores for challenges
- `shop_price_multiplier`: Scales shop item prices
- `colored_dice_cost_multiplier`: Scales colored dice purchase costs
- `goof_off_multiplier`: Scales how fast the chore meter fills
- `yahtzee_bonus_multiplier`: Scales bonus Yahtzee points (rewards skill)
- `debuff_intensity_multiplier`: Scales debuff severity
- `unlock_requirement`: Number of channels that must be completed to unlock
- `round_configs`: Array of 6 RoundDifficultyConfig resources

**Round Difficulty Configuration:**
Each round within a channel has:
- `challenge_difficulty_range`: Vector2i (min, max) for challenge tier selection
- `max_debuffs`: Maximum debuffs allowed this round
- `debuff_difficulty_cap`: Maximum difficulty of debuffs allowed
- `bonus_multipliers`: Dictionary of category-specific scoring bonuses

**Difficulty Progression (20 Channels):**
| Channel | Name | Goal | Shop | Debuff | Unlock Req |
|---------|------|------|------|--------|------------|
| 1 | Tutorial | 1.0x | 1.0x | 1.0x | 0 |
| 5 | Moderate | 1.5x | 1.2x | 1.2x | 2 |
| 10 | Expert | 3.0x | 1.8x | 2.0x | 5 |
| 15 | Master | 5.0x | 2.5x | 3.0x | 10 |
| 20 | ULTIMATE | 8.0x | 3.5x | 4.0x | 18 |

**Implementation Files:**
- **RoundDifficultyConfig** (`Scripts/Core/RoundDifficultyConfig.gd`) - Per-round settings resource
- **ChannelDifficultyData** (`Scripts/Core/ChannelDifficultyData.gd`) - Channel-wide settings resource
- **ChannelManager** (`Scripts/Managers/channel_manager.gd`) - Core difficulty logic, loads configs
- **ChannelManagerUI** (`Scripts/Managers/channel_manager_ui.gd`) - TV remote UI with lock/completion indicators
- **Channel Resources** (`Resources/Data/Channels/channel_01.tres` to `channel_20.tres`)
- **ChannelDifficultyValidator** (`Scripts/Editor/ChannelDifficultyValidator.gd`) - Editor validation tool

**Integration Points:**
- **RoundManager**: Uses `get_challenge_difficulty_range()` for challenge selection
- **ShopItem**: Uses `get_shop_price_multiplier()` for price display
- **DiceColorManager**: Uses `get_colored_dice_cost_multiplier()` for dice costs
- **ChoresManager**: Uses `get_goof_off_multiplier()` for meter threshold
- **Scorecard**: Uses `get_yahtzee_bonus_multiplier()` for bonus Yahtzee points
- **DebuffManager**: Uses `get_debuff_intensity_multiplier()` for debuff scaling

**Game Flow:**
1. Game starts → Channel selector appears (locked/completed status shown)
2. Player selects unlocked channel (1-20) and presses Start
3. Game progresses through 6 rounds with scaled difficulty
4. After Round 6 completion → RoundWinnerPanel shows stats
5. "Next Channel" marks channel complete, saves progress, advances to next channel

**Channel Progression Reset Behavior:**
When advancing to the next channel, the following intentional resets occur:
- **Scorecard Levels**: All scorecard category levels reset to Level 1. This is by design to:
  - Maintain game balance as difficulty scales with each channel
  - Prevent runaway scoring from accumulated level bonuses
  - Create a fresh strategic challenge each channel
  - Encourage players to rebuild their scoring strategy
- **Round Counter**: Resets to Round 1
- **Scorecard**: All categories become available again for scoring
- **Player Inventory**: PowerUps, Consumables, and Mods are RETAINED across channels
- **Economy**: Player money is RETAINED across channels

> **Design Note**: The level reset is intentional game design, not a bug. Players keep their items and money but must rebuild scorecard levels each channel, creating a balanced progression where higher channels require strategic item management rather than relying on accumulated level bonuses.

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
- **LogbookPanel**: ~~Shows recent scoring history~~ **DEPRECATED** — hidden; kept in scene for future revival
- **BestHandPanel**: Contains best hand name with score preview and score breakdown labels
  - **BestHandScore**: Shows the highest-scoring category for current dice with score preview (e.g. "Full House → 25")
  - **AdditiveScoreLabel**: Displays cumulative additive bonuses ("+X") with **Neon Energy shader** (gold/yellow electric arcs)
  - **MultiplierScoreLabel**: Displays combined multiplier effects ("×Y") with **Neon Energy shader** (cyan/blue electric arcs; red in division mode)
  - **Category Highlight**: The matching scorecard button pulses gold to guide the player
  - **Idle Float**: Best hand label gently bobs up/down for a "living" feel
- **TotalScorePanel**: Contains the total score display with animated roll-up and milestone-driven shader background
  - **Score Counter Roll-Up**: Total score counts up from old→new with gold flash
  - **Score Panel Energy Shader**: Background energy field intensifies with score; color shifts at milestone tiers (100=gold, 250=blue, 500=purple, 1000=rainbow)
  - **Milestone Celebrations**: Screen shake + panel flash at 100/250/500/1000 point thresholds

**Neon Energy Shader System:**
Two GLSL shaders provide animated backgrounds behind the score labels and total score panel:
- `Scripts/Shaders/neon_energy.gdshader` — Electric plasma arcs with FBM noise, edge glow, and crackling sparks. Shared by additive (gold) and multiplier (cyan) labels with different uniform parameters.
- `Scripts/Shaders/score_panel_energy.gdshader` — Full-panel energy field that grows with total score. Supports 5 milestone tiers with distinct color palettes, edge lightning arcs, and rainbow mode at tier 4.

Shader uniforms are driven from GDScript in real-time:
- `effect_strength` (0→1): Master visibility toggle, tweened on score changes
- `intensity`: Proportional to score magnitude
- `milestone_tier` (0-4): Controls color palette in score panel shader

**Base Additive Score Calculation:**
The additive score starts with a **base value** calculated from the best hand:
- Formula: `Base Additive = Best Hand Score × Category Level`
- Example: Small Straight (30 points) at Level 2 = 30 × 2 = **+60 base additive**
- Updates dynamically as dice values change and new best hands are identified
- Additional bonuses from consumables/powerups add to this base during scoring

**Animation Integration:**
The panels update in real-time during the `ScoringAnimationController` sequence:
1. Dice bounce animation starts
2. Additive panel shows base score (yellow dim) during preview, then updates with consumable animations (yellow bounce + shader ramp-up)
3. Multiplier panel updates after powerup animations (cyan bounce + shader ramp-up on value > 1.0)
4. Final score floating number appears
5. Total score counter rolls up from old→new with gold flash
6. Score panel shader intensity updates; milestone celebrations fire if threshold crossed
7. Score label "pops" into existence (scale 0→1.2→1.0) when category first scored

**UX Extras:**
- **Score Label Pop**: When any category score is first set (null→value), plays a quick pop animation with gold flash
- **Best Hand Idle Float**: Subtle sin-wave bob (±2px) on the best hand label
- **Button Hover Glow**: Warm highlight (Color 1.1, 1.1, 0.9) on hover over unscored category buttons
- **Label Shimmer**: When additive/multiplier values are non-default, shader intensity gently oscillates

**Key Methods:**
- `prepare_for_scoring_animation()`: Resets breakdown labels and shaders before animation starts
- `update_additive_score_panel(value, animate)`: Updates additive display with bounce + shader driving
- `update_multiplier_score_panel(value, animate)`: Updates multiplier display with bounce + shader driving
- `animate_score_counter(old, new)`: Tweens displayed total from old→new with gold flash
- `check_score_milestones(score)`: Fires celebrations at 100/250/500/1000 thresholds
- `highlight_best_hand_category()`: Pulses gold on the matching scorecard button
- `pop_score_label(label)`: Scale-bounce animation when score first appears
- `reset_score_tracking()`: Resets counters/shaders for new game
- `_apply_score_breakdown_theme()`: Loads and applies themed background to score labels

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
- **Empty Category Bonus**: $10 for each unscored category on the scorecard
  - Rewards efficient play and early challenge completion
  - Max possible: 13 categories × $10 = $130 (if completed without scoring anything)
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
- `EndOfRoundStatsPanel` (`Scripts/UI/end_of_round_stats_panel.gd`) - Panel UI and animation; stops money sounds and cancels remaining animations when dismissed early
- `RoundManager.calculate_empty_category_bonus()` - Counts null categories × $10
- `RoundManager.calculate_score_above_target_bonus()` - (score - target) × $1
- Bonuses awarded via `PlayerEconomy.add_money()` when "Head to Shop" is clicked

**End-of-Round Button Behavior:**
- When a challenge is completed, the **Next Turn** button is disabled to prevent skipping end-of-round rewards
- The **Shop** button pulses to guide the player toward the end-of-round stats flow
- When entering the Shop, the **Roll** button is disabled and the scorecard display is cleared (scores, additive/multiplier labels, Best Hand label, and category highlight) for visual closure

**PlayStation Reroll & Challenge Check:**
- After using the PlayStation Continue, the Shop button is disabled during bonus rolls
- When the rerolled category is scored and the scorecard completes again, the game checks if the challenge was completed — if so, it routes to the normal end-of-round flow (stats panel → shop) instead of game over
- **Fallback Detection**: Because the challenge self-destructs (disconnects from all scorecard signals) when the first `game_completed` fires with an insufficient score, a manual score-vs-target check in `_on_scorecard_complete` ensures challenge completion is detected after a PlayStation reroll

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
- **Progress Decrease**: Varies by chore difficulty (EASY: -10, HARD: -30)
- **Mom Trigger**: At 100 progress, Mom appears to check your PowerUps

**Chore Difficulty:**
Each chore has an EASY or HARD difficulty level:
- **EASY** tasks (meter -10): Score in upper section, generic lower section, use items, lock 3 dice
- **HARD** tasks (meter -30): Specific combos, Yahtzees, full house with specific triples, lock 4-5 dice

**Chore Selection Popup:**
When a chore completes or expires, a **ChoreSelectionPopup** appears at turn end:
- Shows current goof-off meter progress bar with color-coded fill
- Displays Mom's mood emoji and description (e.g., "😊 Content (3/10)")
- Presents EASY and HARD task cards side-by-side with names, descriptions, and reduction values
- Player must choose one before continuing — only one popup per turn

**Chore Tasks:**
Tasks are randomly selected from a pool of 40+ options across different categories:
- **Upper Section Tasks**: Score specific upper categories (Ones, Twos, etc.)
- **Lower Section Tasks**: Score specific lower categories (Full House, Straight, etc.)
- **Specific Tasks**: Score with particular dice combinations
- **Utility Tasks**: Lock dice, use consumables, scratch categories
- **Challenge Tasks**: Roll Yahtzees or specific high-value combinations

**Task Completion & Expiration:**
- Hover over ChoreUI to see current task requirements and **expiration timer**
- Expiration timer shows "Expires in X rolls" (turns red when < 5 rolls remain)
- Complete the task requirement during normal gameplay
- Progress reduces by task difficulty (EASY: -10, HARD: -30)
- Chore selection popup appears for the player to pick their next chore

**Chore Tracking (ProgressManager):**
- `total_chores_completed`: Cumulative across all games (per profile)
- `total_chores_completed_easy` / `total_chores_completed_hard`: By difficulty
- Used as unlock conditions for items (`CHORE_COMPLETIONS` condition type)

See [Docs/chores_list.md](Docs/chores_list.md) for the full chore reference.

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

### Tutorial System
An interactive, action-gated tutorial system that teaches new players the game mechanics with Mom's friendly guidance.

**Features:**
- **Auto-Start**: Automatically triggers for first-time players (tutorial_completed = false)
- **Manual Access**: "Play Tutorial" / "Replay Tutorial" button in main menu
- **Multi-Part Steps**: Complex topics split into digestible parts (e.g., "Scoring 1/3")
- **Action Gating**: Tutorial won't proceed until player performs the required action
- **UI Highlighting**: Golden pulsing border around target UI elements
- **Mom's Dialog**: Typewriter-animated messages with Skip/Next buttons
- **Skip Warning**: Confirmation dialog when leaving mid-tutorial

**Tutorial Flow:**
1. **Introduction**: Welcome message from Mom
2. **Rolling Dice**: How to roll and what the dice tray shows
3. **Locking Dice**: Click dice to lock them between rolls
4. **Scoring System (3 parts)**: Categories, bonuses, and strategy
5. **Score Card Navigation**: How to scroll and select categories
6. **Confirming Scores**: Committing dice to a category
7. **Turn Flow**: Rolls per turn, advancing turns
8. **Round Flow**: Turns per round, shop access
9. **Shop**: Buying items between rounds
10. **Chores System (2 parts)**: Progress bar and Mom's visits
11. **Power-Ups**: Effects and synergies
12. **Synergies (2 parts)**: Rating bonuses and combinations
13. **Completion**: Tutorial finished, flag saved

**Tutorial Step Resources:**
- **Location**: `Resources/Data/Tutorial/*.tres`
- **Format**: TutorialStep resources with step ID, parts, messages, actions

**Key Properties (TutorialStep):**
- `id`: Unique step identifier (e.g., "roll_dice", "scoring_1")
- `part` / `total_parts`: For multi-part steps
- `title`: Header text in dialog
- `message`: Mom's tutorial message (supports BBCode)
- `mom_expression`: "neutral", "happy", or "upset"
- `highlight_node_path`: NodePath to UI element to highlight
- `required_action`: Action player must perform (e.g., "roll_dice", "lock_die")
- `next_step_id`: ID of next step (empty for final step)

**Action Types:**
- `roll_dice`: Player rolls the dice
- `lock_die`: Player locks any die
- `select_category`: Player selects a score category
- `confirm_score`: Player confirms a score
- `next_turn`: Player clicks Next Turn button
- `next_round`: Player clicks Next Round button
- `open_shop`: Player opens the shop
- `continue`: No action required, just click Next

**Implementation Files:**
- **TutorialStep**: `Scripts/Core/tutorial_step.gd` - Step resource class
- **TutorialManager**: `Scripts/Game/tutorial_manager.gd` - Autoload orchestrator
- **TutorialHighlight**: `Scripts/UI/tutorial_highlight.gd` - UI highlighting
- **TutorialDialog**: `Scripts/UI/tutorial_dialog.gd` - Mom's dialog component

**ProgressManager Integration:**
- `tutorial_completed`: Boolean saved per profile
- `tutorial_in_progress`: Boolean for skip warning tracking

**Debug Commands (Tutorial Tab):**
- Start Tutorial: Begin from first step
- Skip Tutorial: Exit tutorial mode
- Next/Previous Step: Navigate steps manually
- Next Part: Advance multi-part steps
- Reset Progress: Clear completion flag for re-testing
- Show State: Display current tutorial status
- List Steps: Show all loaded tutorial steps
- Force Complete: Mark as completed without running

**Test Scene**: `Tests/TutorialTest.tscn` - Isolated tutorial testing with mock UI

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

### Round Transition Overlay
A cinematic full-screen overlay displayed after challenge celebration fireworks, giving the player a moment to appreciate their progress before continuing.

**Entrance Animations (sequenced):**
1. **Background Fade**: Dark overlay fades in over 0.3s
2. **Completion Banner**: Slides in from the LEFT with `TRANS_BACK` overshoot, then `TweenFX.tada()` flourish
3. **Next Challenge Banner**: Slides in from the RIGHT with `TRANS_BACK`, then `TweenFX.pop_in()`
4. **Action Buttons**: Fly up from below with `TRANS_ELASTIC`, then idle loops (`breathe` + `float_bob`)

**Dismiss Animations:**
- Banners slide out opposite directions, buttons drop off-screen, overlay fades out

**Visual Styling:**
- Dark burgundy panels with gold borders (completion) and green borders (next challenge)
- VCR_OSD_MONO font throughout, matching game theme
- CanvasLayer layer 10 renders above all game UI

**Final Round Variant:**
- When all rounds are complete, displays "ALL ROUNDS COMPLETE!" with a special message
- **Enter Shop** button hidden since there's no next round

**Button Actions:**
- **Keep Playing**: Dismisses overlay, disables the Next Turn button (also guarded against re-enable during subsequent rolls), player continues current state
- **Enter Shop**: Dismisses overlay, opens shop via `_on_shop_button_pressed()`

**Trigger Flow:**
1. Challenge completed → fireworks fire
2. After 1.6s delay → overlay appears with transition data
3. Player chooses action → overlay dismisses with exit animation

**Implementation Files:**
- **Overlay Script**: `Scripts/UI/round_transition_overlay.gd` - Full overlay with animations and UI
- **Overlay Scene**: `Scenes/UI/RoundTransitionOverlay.tscn` - CanvasLayer scene wrapper
- **Game Controller Integration**: `Scripts/Core/game_controller.gd` - Trigger, signal handling, cleanup
- **Test Scene**: `Tests/RoundTransitionTest.tscn` - Manual test with Normal/Final/Early round buttons

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

### PowerUp Card Art & Layout
- **Sprite Sheet Art**: All 64 PowerUp icons use AtlasTexture regions from 5 VHS-style movie poster sprite sheets (500×750px, 5×5 grid each) in `Resources/Art/Powerups/`
  - Sheets: `80s_horror_500.png`, `campy_80s_500.png`, `onscure_90s_500.png`, `regular_movies_500.png`, `teen_classics_500px.png`
  - Atlas grid: 96×143px cells, formula `Rect2(8 + col*99, 7 + row*148, 96, 143)`
  - Assignment: interleaved across sheets by alphabetical order (`sheet = i % 5`, `slot = i / 5`)
- **Card Size**: 120×180 pixels (PowerUpIcon scene and script)
- **Fanout Layout**: ≤5 cards display as a single centered row; 6–10 cards display as 2 rows × 5 columns with 30px spacing

### UI Architecture
- **Spine/Fan System**: Cards can be displayed as compact spines or fanned out for interaction
- **PowerUpUI** (`Scripts/UI/power_up_ui.gd`) - Manages power-up display
- **ConsumableUI** (`Scripts/UI/consumable_ui.gd`) - Manages consumable display
- **ShopUI** (`Scripts/UI/shop_ui.gd`) - In-game purchasing with reroll functionality

### Shop UI Features
- **Tab System**: Five tabs (PowerUps, Consumables, Mods, Colors, Locked)
- **Reroll System**: Reroll button available on PowerUp and Consumable tabs
  - Base cost: $25, increases by $5 per reroll
  - 750ms cooldown between rerolls
  - Cost resets when starting a new game
  - Disabled when no items available or cannot afford

**New Game Reset:**
- The **New Game** button on the Game Over panel resets player economy (`PlayerEconomy.reset_to_starting_money()`) before reloading the scene, ensuring autoload state doesn't persist
  - Cost label displays with bounce animation on each reroll
- **Centered Item Layout**: Items automatically center horizontally and vertically regardless of count
- **Backdrop Click-to-Close**: Clicking outside the shop panel closes it
- **Improved Hover Tooltips**: Tooltip stays visible when moving from item card to purchase button
- **Shelf Panel Theme**: Blockbuster-style shelf background (128x128 pixel art texture with edge borders)

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
- `TutorialTest.tscn` - Tutorial system with mock UI elements
- `GamingConsoleTest.tscn` - All 6 gaming consoles (Atari, NES, SNES, Sega, PlayStation, Sega Saturn): spawn, apply, activate, reset, UI show/hide

## TweenFX Animation System

DiceRogue uses the **TweenFX** addon (v1.1) for standardized micro-animations across all interactive UI. A central **TweenFXHelper** autoload (`Scripts/Core/tween_fx_helper.gd`) wraps TweenFX's 62 animations into game-specific patterns.

### Key Features
- **Button hover/press** — Jelly + punch-in on every interactive button (menus, panels, shop, game controls)
- **Disabled button guard** — Buttons with `disabled = true` skip all hover/press/denied animations automatically
- **Auto-center pivot** — All scale/rotation effects automatically center `pivot_offset` on Control nodes, so animations appear balanced (not anchored top-left)
- **Spine idle personalities** — Power-up/consumable spines gently sway, challenge post-its wiggle, debuff notes sway
- **Spine hover** — Snap-scale effect on mouse enter/exit for all corkboard spines
- **Title float** — Shop and main menu titles bob with `idle_float`
- **Game button pulse** — Roll/Shop buttons breathe with `idle_pulse` when actionable
- **Dice lock/unlock** — Jelly feedback on locking/unlocking dice
- **Debuff feedback** — `negative_hit` red flash when debuff count increases
- **Challenge celebration** — `celebration` tada when challenge goal is met
- **Tutorial highlight** — Pulse + bounce replaced with `idle_pulse` and `idle_float`
- **FX Group Toggles** — 8 groups (Buttons, Spines, Idle, Panels, Icons, Events, Threats, Reveals) can be toggled on/off in Settings > FX tab; persisted to `user://settings.cfg` and per-profile via `progress_manager.gd`
- **Per-profile FX persistence** — FX toggle states are saved/loaded with each player profile, synced between GameSettings and TweenFXHelper on profile load

### Architecture
```
TweenFX addon (addons/TweenFX/) → TweenFXHelper autoload (Scripts/Core/) → Game scripts
```

### Signals
- `group_toggled(group: int, enabled: bool)` — Emitted by TweenFXHelper when any FX group is toggled
- `fx_settings_changed` — Emitted by GameSettings when FX toggles change

### Documentation
See [BUILD_TWEENFX.md](BUILD_TWEENFX.md) for full API reference, patterns, file change list, and integration guide.

## Editor Tools

### Resource Viewer Plugin
A read-only editor tool for viewing all game resources in one centralized interface.

**Location**: `addons/resource_viewer/`

**Features**:
- **Tabbed Interface**: View PowerUps, Consumables, Mods, and Colored Dice in separate tabs
- **Item Counts**: Tab labels show total count for each category (e.g., "PowerUps (25)")
- **Sorting**: Sort resources by Name, Price, Rarity, or Rating (ascending/descending)
- **Property Display**: Click any resource to view its full properties
- **Auto-Discovery**: Automatically scans resource folders on load and refresh

**Enabling the Plugin**:
1. Open Godot Editor
2. Go to **Project → Project Settings → Plugins**
3. Find "Resource Viewer" and set Status to **Active**
4. The plugin appears as a bottom panel dock

**Resource Locations Scanned**:
- `Scripts/PowerUps/*.tres` - PowerUp definitions
- `Scripts/Consumable/*.tres` - Consumable definitions
- `Scripts/Mods/*.tres` - Mod definitions
- `Resources/Data/ColoredDice/*.tres` - Colored Dice definitions

**Usage**:
- Click the "Resource Viewer" tab at the bottom of the editor
- Select a category tab (PowerUps, Consumables, Mods, Colors)
- Use the Sort dropdown and direction button to sort the list
- Click any item in the list to view its properties
- Click "Refresh" to rescan folders after adding new resources

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

### Inventory PowerUps
- **ExtraCouponsPowerUp**: Increases maximum consumable slots from 3 to 5 (Rare, $250, R-rated)
  - Allows holding 2 additional consumables beyond the default 3
  - When sold or removed, triggers overflow handling: if you have more than 3 consumables, the consumable UI opens in "overflow mode" forcing you to use or sell excess consumables before continuing
  - The overflow UI displays "Must sell [X]" message and blocks closing until you're back within limit
  - Great for consumable-heavy builds that rely on having multiple options available

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

### Shop & Inventory
- **Visit The Shop**: Opens the shop UI mid-round without ending your turn (Price: $125)
  - Can be used at any time during active play (before or after rolling)
  - Does not consume a roll or end your turn
  - Allows buying consumables, PowerUps, or Mods without waiting for round end
  - Shop closes after purchase or pressing the close button, returning to gameplay
  - Strategic use: grab that perfect PowerUp or consumable when you need it NOW

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

## Available Debuffs

Debuffs are negative effects that hinder the player's progress and add challenge to the gameplay. They are typically applied as part of challenges or by Mom when caught.

### Dice Control Debuffs
- **Lock Dice**: Prevents the player from locking any dice during their turn
- **Disabled Twos**: Dice showing 2 are visually disabled and don't count toward scoring

### Scoring Debuffs
- **Roll Score Minus One**: Reduces all scores by 1 point per roll made
- **The Division**: All multiplier powerups now divide scores instead of multiplying
- **Reduced Levels**: Reduces the scored category's level by 1 before each score (minimum level 1)
  - Example: Full House at level 4 → scores at level 3 (then level stays at 3)
  - This is a permanent effect - levels are NOT restored when the debuff is removed
  - Affects the category being scored, not all categories at once

### Economy Debuffs
- **Costly Roll**: Charges $10 per dice roll

### System Debuffs
- **Faster Chores**: Chore meter increases 3 points per roll instead of 1
  - Causes Mom to appear much faster
  - Effective strategy: Complete chores more frequently or avoid rolling unnecessarily
- **Disabled Mods**: Disables all dice mods while active
  - All existing mod effects are suspended
  - New dice spawned while active also have mods disabled
  - Mods are restored when the debuff is removed
- **Disabled Colors**: Disables all colored dice effects while active
  - Green, Red, Purple, and Blue dice provide no bonus
  - Colors are restored when the debuff is removed

### PowerUp Debuffs
- **Murphy's Law**: One random powerup is disabled each turn
  - A random active powerup is chosen and deactivated at the start of each turn
  - The previously disabled powerup is re-enabled when a new one is selected
  - Disabled powerup shows a red X overlay on its spine in the UI
  - All powerups are restored when the debuff is removed
- **Liquidation Sale**: All your powerups are sold immediately
  - One-time destructive effect: all active powerups are sold on apply
  - Player receives half-price refund for each powerup sold
  - Effect is permanent — removing the debuff does not restore powerups

### Consumable Debuffs
- **Abstinence**: Cannot use consumables (can still sell)
  - Blocks the USE button on all consumable icons
  - Player can still sell consumables for money
  - Usage is restored when the debuff is removed

### Extreme Debuffs
- **One Shot**: Only 1 roll per turn instead of 3
  - Reduces MAX_ROLLS to 1 for the duration of the debuff
  - Player must score with whatever they roll on their first attempt
  - Original roll count is restored when the debuff is removed

### Coding Standards
- Use GDScript 4.4 syntax
- Tabs for indentation (never spaces)
- `snake_case` for variables/methods, `PascalCase` for classes
- Document functions with `##` comment blocks
- Never use `class_name` in autoload scripts

## Available Gaming Consoles

Gaming Consoles are a unique item class that provides powerful, specialized abilities alongside PowerUps and Consumables. The player can own **one console at a time**, and each console offers a distinct play style. Consoles are purchased from a dedicated **Consoles** tab in the Shop and persist until the player changes channels or purchases a different console.

### Active Consoles (Click to Activate)
- **Atari — Save State** (Price: $300, 2 uses/round)
  - Toggle between **Save** and **Load** modes
  - **Save**: Stores all current dice values as a snapshot
  - **Load**: Restores dice to the saved snapshot and syncs the DiceResults cache for accurate scoring
  - Great for preserving a strong hand before a risky reroll
  - Target: Dice Hand

- **NES — Power Glove** (Price: $300, 3 uses/round)
  - Click on any individual die, then choose **+1** or **-1** to nudge its value
  - Values clamp between 1 and the die's max sides
  - Precise single-die manipulation for fine-tuning hands
  - Target: Dice Hand

- **Sega Saturn — Cartridge Tilt** (Price: $300, 1 use/round)
  - Choose **+1** or **-1** to shift **ALL** dice values at once
  - Values clamp between 1 and each die's max sides
  - Powerful for pushing an entire hand up or down by one
  - Target: Dice Hand

### Passive Consoles (Automatic Effects)
- **SNES — Blast Processing** (Price: $300, Passive)
  - Every **3rd category scored** receives a **1.5× score multiplier**
  - Tracks scoring count internally; resets on new game
  - Visual feedback: console icon flashes + VCR text notification
  - Target: Scorecard

- **Sega Genesis — Combo System** (Price: $300, Passive)
  - Builds a **running combo counter** that increments with each score
  - Grants a **combo × $3 additive bonus** to every scored category
  - Combo resets if a round is failed
  - Target: Scorecard

- **PlayStation — Continue?** (Price: $300, Passive)
  - Triggers immediately when the **last scorecard category is filled**
  - Shows an arcade-style **Continue?** panel with two choices:
    - **Use Continue**: Grants **+3 bonus rolls** and activates **score reroll** mode
    - **Quit**: Proceeds directly to Game Over
  - Single-use per round (one continue per round)
  - Target: Game Controller (via `game_completed` signal)

### Console Mechanics
- **One Console Limit**: Only one gaming console can be active at a time. Purchasing a new one replaces the old one.
- **Shop Tab**: All consoles appear in the dedicated "Consoles" tab, filtered by unlock status and current ownership.
- **Unlock Progression**: Consoles are locked behind ProgressManager milestones and unlock as the player advances.
- **Round Reset**: Active-use consoles reset their remaining uses at the start of each round.
- **UI Display**: The active console appears above the VCR area with an icon, name, and ACTIVATE button (for non-passive consoles).
- **Hover Tooltip**: Hovering the console UI shows a gold-bordered tooltip with the console's power description.

### Architecture & File Locations
- **Data Resource**: `Scripts/GamingConsole/gaming_console_data.gd` — `GamingConsoleData` extends `Resource`
- **Base Class**: `Scripts/GamingConsole/gaming_console.gd` — `GamingConsole` extends `Node2D`
- **Implementations**: `Scripts/GamingConsole/{atari,nes,snes,sega,playstation,sega_saturn}_console.gd`
- **Scenes**: `Scenes/GamingConsole/{Atari,Nes,Snes,Sega,Playstation,SegaSaturn}Console.tscn`
- **Resources**: `Resources/Data/GamingConsoles/{Atari,Nes,Snes,Sega,Playstation,SegaSaturn}Console.tres`
- **Manager**: `Scripts/Managers/gaming_console_manager.gd` + `Scenes/Managers/gaming_console_manager.tscn`
- **UI**: `Scripts/UI/gaming_console_ui.gd` + `Scenes/UI/gaming_console_ui.tscn`
- **Shop Integration**: Consoles tab added to `Scripts/UI/shop_ui.gd`
- **Game Controller**: Purchase flow, activation, and reset logic in `Scripts/Core/game_controller.gd`

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

### UI Z-Index Hierarchy
The UI layering system uses z_index values to control rendering and input order:

| Layer | Z-Index | Elements |
|-------|---------|----------|
| Base Game Elements | 0 | Dice, ScoreCard, etc. |
| Cork Board Spines | 10-19 | Challenge/Debuff spines (10), Consumable spines (15) |
| Shop UI | 100 | Shop panel, tabs, items |
| Fan-Out Backgrounds | 120-121 | PowerUpUI background (120), CorkboardUI background (121) |
| Fanned Icons | 125-135 | PowerUpIcon, ConsumableIcon, DebuffIcon (125 + i) |
| Tooltips | 140 | Spine and icon hover tooltips |

**Shop Auto-Minimize:** When PowerUpUI or CorkboardUI fans out while the shop is open, the shop is temporarily minimized. When the fan-out folds back, the shop is automatically restored.

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

### Automated Bot Testing System

An automated bot player that runs full game sessions for stress-testing and balance analysis. The bot plays through complete runs (channel selection → rounds → turns → shop phases → win/lose) using a configurable strategy.

**Key Features:**
- State-machine-driven `BotController` that hooks into real game systems
- Configurable via `BotConfig` resource (attempts, channels, speed, visual mode)
- Strategy engine: always picks best score, highest rarity purchases, sells lowest rarity
- Statistics collection: win rate, score distribution, loss round patterns, channel results
- Error/crash/edge-case logging with severity levels
- JSON report output to `user://bot_reports/`
- In-game results panel with live status updates
- **50/50 early shop exit**: After completing a challenge mid-round, the bot has a 50% chance each subsequent turn to stop early and visit the shop instead of playing all 13 turns
- **Consumable management**: Bot scans `active_consumables` at the start of each turn and auto-uses "fire and forget" consumables (upgrades, cash, rolls, chores, etc.); interactive consumables requiring UI (score_reroll, double_existing, any_score) are sold for half price
- **Mod & color dice purchasing**: 25% chance per shop visit to purchase a random mod or color dice
- **Auto-dismiss UI panels**: Chore Selection Popup and You Win panel are automatically dismissed so they don't block the bot
- **Item unlock management**: Bot profile defaults to `unlock_all_items: true`, which unlocks everything in ProgressManager at run start so the shop is fully stocked
- **Results panel fix**: All overlay panels (winner panel, chore popup, shop) are dismissed before showing the final results panel at z_index 200
- **End-of-round bonus awards**: Bot calculates and awards challenge reward, chore reward (×$50), empty categories bonus (×$10), and score-above-target bonus (×$1) — matching the stats panel logic the player sees
- **Full game reset between runs**: Properly frees power-ups, consumables, challenges, debuffs via game_controller methods; resets ScoreModifierManager, MAX_ROLLS, shop reroll cost/expansions, and round_manager
- **Expanded statistics**: Tracks highest channel reached, power-ups/consumables/mods/color dice purchased, consumables used vs sold, total money earned/spent, challenge rewards, end-of-round bonuses
- **Smart shop rerolling**: Rerolls the shop when no powerup outranks the bot's worst owned powerup and the reroll cost is ≤10% of current money (configurable max rerolls per shop visit)
- **Economy estimation**: Before each shop visit, estimates remaining budget pressure (low/medium/high/critical) based on projected income vs remaining targets, and filters purchases accordingly
- **Budget-aware purchasing**: Under high/critical budget pressure, skips common/uncommon items to conserve money for harder rounds ahead

**Quick Start:**
1. Open `Tests/BotTest.tscn`
2. Assign `Resources/Data/default_bot_config.tres` to the root node's **Bot Config** export
3. Run the scene (F6)

**Files:** `Scripts/Bot/` (9 scripts), `Tests/bot_test.gd`, `Tests/bot_results_panel.gd`, `Tests/BotTest.tscn`

See [BUILD_BOT.md](BUILD_BOT.md) for full setup instructions, configuration reference, and architecture details.

### Item Value Estimation Tool

A standalone Monte Carlo simulation tool that evaluates every PowerUp and Consumable in the game. Simulates Yahtzee games to estimate each item's expected score improvement, then assigns $/point efficiency ratings and tier rankings (S/A/B/C/D/F).

**Key Features:**
- Monte Carlo Yahtzee scoring simulation (configurable N games per item)
- Classifies items by effect type: score multipliers, additives, extra dice/rolls, economy, utility
- Produces tier rankings with color-coded BBCode output
- Saves text reports to `user://item_value_reports/`
- Configurable via `ItemValueConfig` resource

**Quick Start:**
1. Open `Tests/ItemValueTest.tscn`
2. Run the scene (F6)

**Files:** `Scripts/Bot/ItemValueEstimator.gd`, `Scripts/Bot/ItemValueConfig.gd`, `Tests/item_value_test.gd`, `Tests/item_value_results_panel.gd`, `Tests/ItemValueTest.tscn`

See [BUILD_BOT.md](BUILD_BOT.md) for item effect types, configuration reference, and how to add new items.

