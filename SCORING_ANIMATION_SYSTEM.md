# Enhanced Dynamic Scoring Animation System

## Overview
A comprehensive animation system that provides satisfying visual feedback when players score in DiceRogue. The system creates bouncy, animated effects that scale with score magnitude and only animates elements that actually contribute to the score.

## Features

### 🎲 Individual Dice Animations
- Each die bounces one by one in quick succession (staggered by 0.15s / speed_scale)
- Colored dice get enhanced bounce effects (+10 pixels)
- Each die's value appears as a floating number **above and centered** on the die
- Color-matched floating numbers:
  - White dice → White numbers
  - Green dice → Green numbers  
  - Red dice → Red numbers
  - Purple dice → Magenta numbers
  - Blue dice → Cyan numbers

### 💫 Floating Numbers with VCR Font
- All floating numbers use the VCR_OSD_MONO font for consistency
- **Improved positioning**: Numbers appear above and centered on their source
- Numbers float upward and fade out (duration scaled by speed)
- Different sizes and colors for different types of values
- Configurable outline for visibility

### 🧪 Smart Consumable Animations
- **Only animates consumables that actually contribute to the score**
- Uses real breakdown_info to detect active consumables
- Shows **actual contribution values** as green floating "+X" numbers
- Positioned above and centered on the consumable spine
- Animates after dice sequence completes

### ⚡ Smart PowerUp Animations
- **Only animates powerups that actually contribute to the score**
- Handles both additive and multiplier powerups separately
- Shows **real current values**:
  - Additive powerups: Yellow "+19" style numbers
  - Multiplier powerups: Cyan "x1.5" style numbers
- Positioned above and centered on the powerup spine
- Larger bounce effects than consumables
- Sequential animation with speed scaling

### 🔊 Dynamic Audio System
- Sound pitch scales with score magnitude (0.02 pitch increase per point)
- Base pitch: 1.0, Maximum pitch: 2.0
- Higher scores = more satisfying high-pitched audio

### 📏 Dual Scaling System

#### Animation Intensity (Visual Impact)
- **Small scores (< 15)**: Standard animations (1.0x intensity)
- **Medium scores (15-29)**: Enhanced animations (1.3x intensity)
- **Large scores (30-49)**: Dramatic animations (1.6x intensity)
- **Huge scores (50+)**: Epic animations (2.0x intensity)

#### Animation Speed (Excitement Factor)
- **Small scores (< 15)**: Normal speed (1.0x)
- **Medium scores (15-29)**: 20% faster (1.2x speed)
- **Large scores (30-49)**: 40% faster (1.4x speed)
- **Huge scores (50+)**: 60% faster (1.6x speed)

## Enhanced Animation Sequence

1. **Dice Phase** (0-1.5s/speed): Dice bounce one by one with value numbers
2. **Audio Phase** (0.2s): Scoring sound plays with dynamic pitch
3. **Consumable Phase** (1.8s/speed): **Only contributing** consumable spines bounce with real "+X" numbers
4. **PowerUp Phase** (2.3s/speed): **Only contributing** powerup spines bounce with real values ("xY" or "+Z")
5. **Final Score** (2.8s/speed): Large golden final score number appears
6. **Complete** (3.8s/speed): Animation sequence ends

## Technical Implementation

### Data-Driven Animations
- Uses real `breakdown_info` from ScoreCard scoring calculations
- Detects actual contributing elements via `additive_sources` and `multiplier_sources`
- Shows real powerup/consumable values instead of mock data

### Smart Positioning
- All floating numbers positioned above and centered using appropriate methods:
  - **Dice**: Uses sprite texture size for positioning (Area2D doesn't have get_rect())
  - **Spines**: Uses get_rect() calculations (Control-based elements)
- Improved visual hierarchy and readability

### Performance Optimizations
- Only animates elements that actually affect the score
- Speed scaling reduces total animation time for high scores
- Parallel animation execution where appropriate

## Configuration Options

### Animation Timing (All scaled by speed_scale)
- Base stagger delay: 0.15s between dice
- Consumable delay: 0.2s between each  
- PowerUp delay: 0.3s between each
- Bounce duration: 0.6-0.8s depending on element

### Speed Scaling Thresholds
- Speed scale calculation based on score thresholds
- Applies to all timing: stagger, duration, delays

### Visual Effects
- Font: VCR_OSD_MONO for all floating numbers
- Context-appropriate colors (green for bonuses, cyan for multipliers, yellow for additives)
- Smart positioning above and centered on source elements

## Data Integration

### Breakdown Info Structure
```gdscript
{
  "active_powerups": ["powerup_id1", "powerup_id2"],
  "active_consumables": ["consumable_id1"],
  "additive_sources": [
    {"name": "source_id", "category": "powerup", "value": 19}
  ],
  "multiplier_sources": [
    {"name": "source_id", "category": "powerup", "value": 1.5}
  ]
}
```

### Animation Logic
- Checks `active_powerups`/`active_consumables` for element presence
- Uses `additive_sources`/`multiplier_sources` for real contribution values
- Only animates elements that appear in both lists (active AND contributing)

## Testing

Use `SimpleScoringAnimationTest.tscn` to test:
- VCR font rendering
- Speed scaling effects (watch how animation speeds up with higher scores)
- Positioning improvements
- Visual feedback timing

## Future Enhancements

- Screen shake effects for epic scores (50+)
- Particle effects for legendary scores (100+)
- Sound effect variations based on score tiers
- Combo streak multiplier visual feedback