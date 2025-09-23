# VCR Turn Tracker UI Integration Guide

## Overview
The VCRTurnTrackerUI replaces the basic TurnTrackerUI with a retro VCR-style display featuring dynamic animations and neon green styling.

## Features
- **VCR Font Styling**: Uses VCR_OSD_MONO font with neon green colors
- **Dynamic Money Animations**: Bounce and flash effects scale with money gained/lost
- **Subtle Change Indicators**: Turn, roll, and round changes get visual feedback
- **Flexible Layout**: Designed to fit over VCR display area in game scenes

## Scene Setup Instructions

### 1. Replace existing TurnTrackerUI in scenes:
```gdscript
# OLD:
[ext_resource type="PackedScene" uid="uid://df1otdcd66xb5" path="res://Scenes/UI/turn_tracker_ui.tscn" id="10_bv0jw"]

# NEW:
[ext_resource type="PackedScene" uid="uid://bkq3n8x8f1a2m" path="res://Scenes/UI/vcr_turn_tracker_ui.tscn" id="10_vcr_ui"]
```

### 2. Update node instantiation:
```gdscript
# OLD:
[node name="TurnTrackerUI" parent="." instance=ExtResource("10_bv0jw")]

# NEW:
[node name="VCRTurnTrackerUI" parent="." instance=ExtResource("10_vcr_ui")]
```

### 3. Position over VCR display area:
```gdscript
[node name="VCRTurnTrackerUI" parent="." instance=ExtResource("10_vcr_ui")]
anchors_preset = 0
anchor_right = 0.0
anchor_bottom = 0.0
offset_left = 401.0    # Adjust to fit VCR display
offset_top = 85.0      # Adjust to fit VCR display
offset_right = 580.0   # Adjust to fit VCR display
offset_bottom = 206.0  # Adjust to fit VCR display
round_manager_path = NodePath("../RoundManager")
```

## Signal Connections

### Required Connections:
1. **TurnTracker binding**: Call `bind_tracker()` from GameController or scene setup
2. **RoundManager**: Set `round_manager_path` in inspector or scene file
3. **PlayerEconomy**: Automatically connects to `money_changed` signal in `_ready()`

### Example GameController integration:
```gdscript
# In GameController._ready() or scene setup:
@onready var vcr_ui: VCRTurnTrackerUI = $VCRTurnTrackerUI
@onready var turn_tracker: TurnTracker = $TurnTracker

func _ready():
	if vcr_ui and turn_tracker:
		vcr_ui.bind_tracker(turn_tracker)
```

## Animation Details

### Money Animations:
- **Positive gains**: Scale bounce + bright flash (intensity scales with amount)
- **Negative changes**: Red color flash
- **Large gains**: Bigger bounce effects (capped at 1.5x scale)

### Change Indicators:
- **Turn changes**: Subtle scale pulse + color brightening
- **Roll updates**: Same as turn, plus color change for extra rolls
- **Round updates**: Same pulse animation

## Files Created:
- `Scripts/UI/vcr_turn_tracker_ui.gd` - Main script with class_name VCRTurnTrackerUI
- `Scenes/UI/vcr_turn_tracker_ui.tscn` - Scene with VCR display layout

## Dependencies:
- `Resources/Font/VCR_OSD_MONO_1.001.ttf` - VCR font (already exists)
- `PlayerEconomy` autoload for money tracking
- `TurnTracker` node for turn/roll data
- `RoundManager` for round progression

## Color Scheme:
- Primary: `Color(0.2, 1.0, 0.3, 1.0)` - VCR Green
- Bright: `Color(0.4, 1.0, 0.5, 1.0)` - Highlighted Green
- Dim: `Color(0.1, 0.8, 0.2, 1.0)` - Dimmed Green
- Error: Red tint for negative money changes