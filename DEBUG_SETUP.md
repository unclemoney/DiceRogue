# Debug Integration Instructions

## Adding Debug Panel to Main Game Scene

**IMPORTANT**: Only add the debug panel to your scene ONCE. The panel uses a singleton pattern to prevent duplicates.

### Method 1: Scene Integration (Recommended)
1. **Open Main Scene**: `Scenes/Controller/game_controller.tscn`
2. **Add Debug Panel**: 
   - Right-click root node
   - Add Child > Load > Select `Scenes/UI/DebugPanel.tscn`
   - Place as last child (highest z-order)
   - **Ensure only ONE debug panel is added**

### Method 2: Code Integration  
```gdscript
# In GameController _ready() or similar
if not DebugPanel.instance:
    var debug_panel = preload("res://Scenes/UI/DebugPanel.tscn").instantiate()
    add_child(debug_panel)
```

### Method 3: Static Creation
```gdscript
# From anywhere in code
DebugPanel.toggle_debug()  # Creates panel if it doesn't exist
```

## Troubleshooting Duplicate Panels

If you see duplicate panels:
1. **Check your scene tree** - ensure only ONE DebugPanel node exists
2. **Check console output** - the panel logs when duplicates are detected and removed
3. **Remove extra instances** - delete any duplicate DebugPanel nodes from your scene
4. **Use F12 to test** - only one panel should appear/disappear

## Input Setup

The debug panel handles F12 input automatically. No additional input map setup required.

## Usage

- Press **F12** during gameplay to toggle debug panel
- Navigate between tabs to find the appropriate debug tools
- Use quick action buttons for common testing scenarios  
- View debug output in the panel's text area
- All debug actions are logged with timestamps

## Debug Panel Organization

The debug panel is organized into logical tabs for better usability:

### **Economy Tab**
Financial testing and economy manipulation:
- Add Money ($100 or $1000)
- Reset Money to default

### **Items Tab** 
Power-ups, consumables, and mod management:
- Grant various items (PowerUps, Consumables, Mods)
- Register specific consumables
- Show/Clear all active items

### **Dice Control Tab**
Direct dice manipulation for testing scenarios:
- Force specific dice values (1s, 6s, Yahtzee, Large Straight)
- Activate specific PowerUps (Perfect Strangers)

### **Dice Colors Tab**
Dice color system testing:
- Toggle dice color display
- Force specific colors (Green, Red, Purple)
- Clear all colors
- Test color scoring pipeline
- Show color effects

### **Testing Tab**
Complex feature and interaction testing:
- Debuff testing (Division debuff)
- Challenge activation and testing
- Mod limit testing
- Cross-system integration tests

### **Game State Tab**
Game flow and state management:
- Show current game state (scores, stats, rolls)
- Manipulate turn flow (add rolls, end turn, skip to shop)
- Test scoring calculations
- Debug multiplier system
- Trigger signal tests

### **Utilities Tab**
Development and debugging utilities:
- Save/Load debug states
- Reset game
- Clear debug output

## Extending Debug Functionality

When adding new debug commands:

1. **Choose the appropriate tab** based on the feature category
2. **Update the tab definition** in `_create_debug_tabs()` in `debug_panel.gd`:
   ```gdscript
   "TabName": [
       {"text": "Button Label", "method": "_debug_your_new_method"},
       # Add to existing array for the appropriate tab
   ]
   ```
3. **Implement the debug method**:
   ```gdscript
   func _debug_your_new_method() -> void:
       # Implementation here
       log_debug("Debug action completed")
   ```
4. **Use consistent naming**: `_debug_[category]_[action]()` 
5. **Always log actions**: Use `log_debug("message")` for output
6. **Update this documentation** with the new feature

### Tab Assignment Guidelines

- **Economy**: Money, purchasing, economic systems
- **Items**: PowerUps, Consumables, Mods (granting, showing, clearing)
- **Dice Control**: Direct dice manipulation, forced rolls
- **Dice Colors**: Color system features and testing
- **Testing**: Cross-system tests, complex feature validation
- **Game State**: Game flow, state inspection, scoring
- **Utilities**: Development tools, save/load, reset functions

## Design Principles

- **Single responsibility**: Each tab focuses on one system domain
- **Logical grouping**: Related functions grouped together
- **Consistent naming**: Clear, descriptive button labels
- **Comprehensive logging**: All actions logged with timestamps
- **Non-intrusive**: Easy to disable/remove for release builds

The debug system is designed to be expandable while maintaining organization and usability.