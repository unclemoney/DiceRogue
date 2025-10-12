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
- Use quick action buttons for common testing scenarios  
- View debug output in the panel's text area
- All debug actions are logged with timestamps

## Extending Debug Functionality

Add new debug commands by:
1. Adding entry to `_create_debug_buttons()` array in `debug_panel.gd`
2. Implementing corresponding `_debug_your_feature()` method
3. Using `log_debug("message")` for output

The debug system is designed to be non-intrusive and easily removable for release builds.