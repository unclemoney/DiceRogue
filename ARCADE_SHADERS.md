# Arcade Background Shaders

Three custom background shaders designed for DiceRogue (Ghutzee), capturing the nostalgic aesthetic of late 80's/early 90's arcades and malls with purple/teal neon color schemes.

## Overview

All three shaders use a consistent three-color uniform system matching the game's visual identity:
- **colour_1**: Dark purple base/space background
- **colour_2**: Medium purple/magenta accents
- **colour_3**: Teal/cyan neon highlights

Each shader includes tunable `pixel_filter` parameter (200-1000) for retro pixelation effect and distinct speed controls for animation.

---

## 1. Neon Grid (`neon_grid.gdshader`)

Tron-inspired perspective grid with glowing neon lines, evoking Blade Runner and 80's vector graphics.

### Visual Style
- Animated horizontal and vertical grid lines
- Perspective depth effect (compressed top, expanded bottom)
- Glowing neon lines with color gradients
- CRT scanlines overlay
- Horizon glow effect

### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Dark purple | Base background color |
| `colour_2` | Color | - | Teal/cyan | Primary grid line color |
| `colour_3` | Color | - | Purple/magenta | Secondary grid color |
| `grid_speed` | Float | 0.0 - 2.0 | 0.3 | Animation speed of moving grid |
| `pixel_filter` | Float | 200.0 - 1000.0 | 500.0 | Pixelation amount (higher = less pixelated) |
| `grid_density` | Float | 5.0 - 50.0 | 20.0 | Number of grid lines |
| `perspective_strength` | Float | 0.0 - 2.0 | 1.0 | Depth perspective intensity |
| `glow_intensity` | Float | 0.0 - 2.0 | 1.2 | Brightness of neon glow |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.3 | CRT scanline visibility |

### Suggested Use Cases
- **Main Menu**: grid_speed=0.3, glow_intensity=1.2, perspective_strength=1.0
- **Settings Menu**: grid_speed=0.15, glow_intensity=0.8, darker colors
- **Gameplay Background**: grid_speed=0.5, more intense glow for energy

### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/neon_grid.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.15, 0.08, 0.25, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.0, 0.8, 0.8, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.8, 0.0, 1.0, 1.0))
shader_mat.set_shader_parameter("grid_speed", 0.3)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

## 2. VHS Static Wave (`vhs_wave.gdshader`)

Layered horizontal wave patterns mimicking analog TV interference with chromatic aberration and rolling noise.

### Visual Style
- Multi-frequency sine wave displacement
- Chromatic color separation (VHS tape degradation)
- Rolling interference bars
- TV static noise overlay
- CRT scanlines
- Vignette darkening at edges

### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Very dark purple | Darkest wave layer |
| `colour_2` | Color | - | Medium purple | Mid-tone wave layer |
| `colour_3` | Color | - | Teal | Accent/highlight color |
| `wave_speed` | Float | 0.0 - 3.0 | 0.5 | Animation speed of waves |
| `pixel_filter` | Float | 200.0 - 1000.0 | 500.0 | Pixelation amount |
| `wave_density` | Float | 3.0 - 20.0 | 8.0 | Number of wave patterns |
| `wave_amplitude` | Float | 0.0 - 0.2 | 0.05 | Wave displacement strength |
| `chromatic_drift` | Float | 0.0 - 0.1 | 0.02 | Color channel separation |
| `noise_strength` | Float | 0.0 - 0.5 | 0.15 | TV static intensity |
| `scanline_intensity` | Float | 0.0 - 1.0 | 0.4 | CRT scanline darkness |

### Suggested Use Cases
- **Main Menu**: wave_speed=0.5, moderate noise for atmosphere
- **Loading Screens**: Higher wave_speed=1.0, more dramatic effect
- **Pause Menu**: wave_speed=0.2, subtle ambient motion

### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/vhs_wave.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.08, 0.04, 0.15, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.25, 0.12, 0.35, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.0, 0.6, 0.7, 1.0))
shader_mat.set_shader_parameter("wave_speed", 0.5)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

## 3. Arcade Starfield (`arcade_starfield.gdshader`)

Multi-layer parallax star field with color-cycling pixels, evoking 80's space arcade games and mall fountain lights.

### Visual Style
- 4 depth layers of stars at different speeds
- Twinkling/pulsing star animation
- Color cycling between purple and teal
- Optional comet streak trails
- Subtle nebula color variations
- Parallax scrolling effect

### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Dark purple | Space background |
| `colour_2` | Color | - | Purple/magenta | Star color (primary) |
| `colour_3` | Color | - | Teal/cyan | Star color (secondary) |
| `star_speed` | Float | 0.0 - 2.0 | 0.2 | Overall star movement speed |
| `pixel_filter` | Float | 200.0 - 1000.0 | 500.0 | Pixelation amount |
| `star_density` | Float | 50.0 - 500.0 | 200.0 | Number of stars |
| `twinkle_speed` | Float | 0.0 - 5.0 | 2.0 | Star pulsing animation rate |
| `comet_trails` | Float | 0.0 - 1.0 | 0.3 | Comet streak visibility |
| `color_cycle_speed` | Float | 0.0 - 3.0 | 1.0 | Color shift animation rate |

### Suggested Use Cases
- **Main Menu**: star_speed=0.2, moderate twinkle for calm atmosphere
- **Victory Screen**: Higher star_speed=0.5, more comets for celebration
- **High Score Display**: Slower star_speed=0.1, gentle color cycling

### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/arcade_starfield.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.08, 0.04, 0.15, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.8, 0.0, 1.0, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.0, 0.8, 0.8, 1.0))
shader_mat.set_shader_parameter("star_speed", 0.2)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

## Color Palette Reference

Standard purple/teal palette used across all shaders:

```gdscript
# Dark backgrounds
var dark_purple = Color(0.08, 0.04, 0.15, 1.0)      # colour_1 (deep space)
var medium_dark = Color(0.15, 0.08, 0.25, 1.0)      # colour_1 (grid base)

# Mid-tones
var medium_purple = Color(0.25, 0.12, 0.35, 1.0)    # colour_2 (waves)

# Accents (neon colors)
var magenta_neon = Color(0.8, 0.0, 1.0, 1.0)        # colour_2 (grid/stars)
var teal_neon = Color(0.0, 0.8, 0.8, 1.0)           # colour_3 (highlights)
var cyan_neon = Color(0.0, 0.6, 0.7, 1.0)           # colour_3 (waves)
```

---

## Integration with Main Menu

To swap shaders in `main_menu.gd`, modify the `_build_ui()` method:

```gdscript
# In _build_ui() where shader is loaded:

# OPTION 1: Neon Grid (Tron-style)
var shader = load("res://Scripts/Shaders/neon_grid.gdshader")
# ... apply parameters from Neon Grid section above

# OPTION 2: VHS Static Wave (Analog TV)
#var shader = load("res://Scripts/Shaders/vhs_wave.gdshader")
# ... apply parameters from VHS Wave section above

# OPTION 3: Arcade Starfield (Space arcade)
#var shader = load("res://Scripts/Shaders/arcade_starfield.gdshader")
# ... apply parameters from Starfield section above
```

---

## Performance Notes

- All shaders use pixelation filters which reduce computation
- Higher `pixel_filter` values = better performance (less pixels computed)
- Recommended range: 400-600 for menus, 300-400 for gameplay
- All shaders tested at 60 FPS on mid-range hardware

---

## Credits

Created for **DiceRogue (Ghutzee)** - A late 80's/early 90's arcade-inspired dice game.
Designed to replace the Balatro-sourced swirl shader with original visual effects.
