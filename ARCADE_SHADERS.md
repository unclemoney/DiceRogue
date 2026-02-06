# Arcade Shader Collection

A comprehensive library of custom shaders for DiceRogue (Guhtzee), capturing the nostalgic aesthetic of late 80's/early 90's arcades, malls, and SNES-era pixel art. Purple/teal neon color schemes throughout.

## Overview

The shader collection is organized into three categories:

### Background Shaders (7 total)
Full-screen animated backgrounds applied to `ColorRect` nodes. All use the consistent three-color system (`colour_1`, `colour_2`, `colour_3`) and shared `pixel_filter` parameter for retro pixelation.

| Shader | Style | Era Feel |
|--------|-------|----------|
| `plasma_screen` | Organic demoscene plasma blobs | Amiga/C64 1988-1992 |
| `arcade_carpet` | Geometric tile patterns (3 modes) | 90s mall/bowling alley |
| `marquee_lights` | Chasing theater bulb borders | Casino/arcade marquee |
| `neon_grid` | Tron perspective grid | 80s vector graphics |
| `vhs_wave` | Analog TV interference | VHS tape degradation |
| `arcade_starfield` | Parallax stars with comets | 80s space arcade |
| `backgground_swirl` | Paint swirl (Balatro-sourced, legacy) | Balatro reference |

### UI Effect Shaders (3 upgraded)
Applied to sprites, texture rects, and particle systems for interactive visual feedback.

| Shader | Purpose |
|--------|---------|
| `glow_overlay` | Enhanced glow with chromatic aberration, pulsing, distortion |
| `power_up_ui` | Holographic energy field for power-up cards |
| `consumable_explosion` | Multi-stage dramatic burst with streaks and debris |

### Other Existing Shaders (not covered here)
`card_perspective`, `crt_shader`, `dice_combined_effects`, `debuff_ui_highlight`, `retro_dither`, `vhs_overlay`, etc. See individual shader file headers for documentation.

---

## Background Shaders - New Creative Set

### 1. Plasma Screen (`plasma_screen.gdshader`)

Classic demoscene plasma effect with flowing organic color blobs. Inspired by Amiga and C64 demo productions from 1988-1992, this shader uses multi-frequency sine wave interference to create mesmerizing, never-repeating patterns.

#### Visual Style
- 6 layered sine wave interference patterns
- Horizontal, vertical, diagonal, radial, and swirling components
- Smooth 3-color gradient cycling
- Organic flowing blob boundaries
- Retro scanlines and vignette

#### Technical Deep-Dive
The plasma effect works by summing 6 sine functions at different frequencies and orientations:
1. Horizontal wave: `sin(p.x + t)` — basic left-right undulation
2. Vertical wave: `sin(p.y + t)` — up-down complement
3. Diagonal ripple: `sin(p.x + p.y + t)` — classic demoscene interference
4. Radial pulse: `sin(sqrt(x² + y²) - t)` — expanding rings from center
5. Swirl: `sin(x·sin(t) + y·cos(t))` — rotating interference (warp_intensity)
6. Angular ring: `sin(r - t + angle·2)` — spiraling outward pattern

The combined value is mapped to a 3-color gradient using sine waves offset by 2π/3 (120°), creating smooth transitions between all three colors simultaneously.

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Deep purple | Base/dark blob color |
| `colour_2` | Color | - | Vivid magenta | Primary plasma accent |
| `colour_3` | Color | - | Teal/cyan | Secondary plasma accent |
| `plasma_speed` | Float | 0.0 - 2.0 | 0.4 | Overall animation speed |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation (higher = smoother) |
| `plasma_scale` | Float | 0.5 - 3.0 | 1.5 | Pattern zoom (higher = tighter) |
| `color_cycle_speed` | Float | 0.0 - 3.0 | 0.8 | Color gradient animation rate |
| `contrast` | Float | 0.5 - 2.0 | 1.2 | Blob boundary sharpness |
| `warp_intensity` | Float | 0.0 - 1.0 | 0.3 | Swirl/spiral layer strength |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.15 | CRT scanline overlay |

#### Parameter Recipes
- **Calm Menu**: `plasma_speed=0.25, contrast=0.8, warp_intensity=0.15, pixel_filter=600`
- **Energetic/Boss**: `plasma_speed=0.8, contrast=1.8, warp_intensity=0.6, color_cycle_speed=1.5`
- **Psychedelic**: `plasma_speed=0.5, contrast=2.0, warp_intensity=1.0, color_cycle_speed=2.5`
- **Subtle Background**: `plasma_speed=0.15, contrast=0.6, scanline_strength=0.3, pixel_filter=400`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/plasma_screen.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.08, 0.04, 0.15, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.6, 0.0, 0.9, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.0, 0.75, 0.8, 1.0))
shader_mat.set_shader_parameter("plasma_speed", 0.4)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 2. Arcade Carpet (`arcade_carpet.gdshader`)

Animated geometric tile patterns inspired by iconic 90s arcade and bowling alley carpet designs. Features a 5-color palette for authentic retro variety and 3 switchable pattern modes.

#### Visual Style
- Tiled geometric patterns with hash-based color randomization
- Slow diagonal scrolling animation
- UV-reactive blacklight glow effect
- Woven fabric texture overlay
- 3 distinct pattern modes: Diamonds, Starbursts, Memphis

#### Pattern Modes

**Mode 0 - Diamonds**: Classic diamond shapes with zigzag borders. The most common 90s arcade carpet look. Each tile gets randomized colors from the 5-color palette.

**Mode 1 - Starbursts**: Alternating starburst and concentric ring tiles with dot grid overlay. Bowling alley / roller rink aesthetic.

**Mode 2 - Memphis**: Squiggly sine lines with scattered triangles. Inspired by Memphis Group design movement (1980s Italian postmodern).

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Deep purple-black | Tile background |
| `colour_2` | Color | - | Electric purple | Primary shape color |
| `colour_3` | Color | - | Teal | Secondary shape color |
| `colour_4` | Color | - | Hot pink | Tertiary accent |
| `colour_5` | Color | - | Neon green | Quaternary accent |
| `scroll_speed` | Float | 0.0 - 1.5 | 0.15 | Diagonal scroll speed |
| `pixel_filter` | Float | 200 - 1000 | 450 | Pixelation amount |
| `tile_size` | Float | 5.0 - 30.0 | 12.0 | Pattern repeat density |
| `pattern_style` | Int | 0 - 2 | 0 | 0=Diamonds, 1=Starbursts, 2=Memphis |
| `fabric_texture` | Float | 0.0 - 1.0 | 0.25 | Woven texture overlay strength |
| `glow_amount` | Float | 0.0 - 1.0 | 0.4 | UV-reactive blacklight glow |

#### Parameter Recipes
- **Classic Arcade**: `pattern_style=0, tile_size=12, glow_amount=0.4, pixel_filter=450`
- **Bowling Alley**: `pattern_style=1, tile_size=10, fabric_texture=0.3, glow_amount=0.35`
- **Memphis Lounge**: `pattern_style=2, tile_size=14, fabric_texture=0.2, glow_amount=0.5`
- **Subtler BG**: `scroll_speed=0.08, glow_amount=0.2, fabric_texture=0.4, pixel_filter=350`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/arcade_carpet.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.06, 0.02, 0.12, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.5, 0.0, 0.8, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.0, 0.75, 0.75, 1.0))
shader_mat.set_shader_parameter("colour_4", Color(1.0, 0.2, 0.5, 1.0))
shader_mat.set_shader_parameter("colour_5", Color(0.0, 0.9, 0.4, 1.0))
shader_mat.set_shader_parameter("pattern_style", 0)
shader_mat.set_shader_parameter("pixel_filter", 450.0)
background.material = shader_mat
```

---

### 3. Marquee Lights (`marquee_lights.gdshader`)

Theater/casino-style chasing light bulb borders with glowing halos. Multiple nested rectangular frames chase in different directions with different colors, surrounding a diamond-tiled inner area.

#### Visual Style
- Sequential bulb activation (chase pattern: 3 lit, 2 off)
- Point light glow using inverse-square distance falloff
- Dim amber filament when bulb is "off"
- Up to 4 nested frames with different colors and chase directions
- Inner diamond grid with pulsing animation
- Counter-rotating chase directions between frames

#### Technical Deep-Dive
Each frame traces bulbs along a rectangular border path. The chase effect uses:
```
chase_phase = fract(perimeter_position + TIME * speed + offset)
is_lit = step(fract(chase_phase * 5.0), 0.6)  // 60% on, 40% off
```
This creates seamless looping around corners. Each frame can chase in opposite directions by negating the time value, creating visually rich interplay.

Glow uses simplified point-light physics: `glow = 1.0 / (1.0 + d² * 800 / radius²)`, giving natural falloff without expensive pow() calls.

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Dark background | Background color |
| `colour_2` | Color | - | Warm gold | Primary bulb lit color |
| `colour_3` | Color | - | Dim amber | Bulb off/filament color |
| `bulb_alt_1` | Color | - | Teal | Frame 2 bulb color |
| `bulb_alt_2` | Color | - | Purple | Frame 3 bulb color |
| `chase_speed` | Float | 0.0 - 3.0 | 1.0 | Bulb chase animation speed |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `bulb_size` | Float | 0.01 - 0.08 | 0.035 | Individual bulb radius |
| `bulb_spacing` | Float | 0.03 - 0.15 | 0.07 | Distance between bulbs |
| `glow_radius` | Float | 0.5 - 3.0 | 1.8 | Light spread intensity |
| `frame_count` | Int | 1 - 4 | 3 | Number of nested border frames |
| `inner_pattern` | Float | 0.0 - 1.0 | 0.5 | Diamond grid fill strength |

#### Parameter Recipes
- **Classic Marquee**: `frame_count=3, chase_speed=1.0, glow_radius=1.8, inner_pattern=0.5`
- **Casino Entrance**: `frame_count=4, chase_speed=1.5, glow_radius=2.5, bulb_spacing=0.05`
- **Subtle Accent**: `frame_count=2, chase_speed=0.5, glow_radius=1.0, inner_pattern=0.3`
- **High Energy**: `frame_count=4, chase_speed=2.5, glow_radius=3.0, bulb_size=0.05`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/marquee_lights.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.05, 0.02, 0.1, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(1.0, 0.85, 0.2, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.15, 0.08, 0.05, 1.0))
shader_mat.set_shader_parameter("bulb_alt_1", Color(0.0, 0.9, 0.8, 1.0))
shader_mat.set_shader_parameter("bulb_alt_2", Color(0.8, 0.0, 1.0, 1.0))
shader_mat.set_shader_parameter("chase_speed", 1.0)
shader_mat.set_shader_parameter("frame_count", 3)
background.material = shader_mat
```

---

## Background Shaders - Original Set

### 4. Neon Grid (`neon_grid.gdshader`)

Tron-inspired perspective grid with glowing neon lines, evoking Blade Runner and 80's vector graphics.

#### Visual Style
- Animated horizontal and vertical grid lines
- Perspective depth effect (compressed top, expanded bottom)
- Glowing neon lines with color gradients
- CRT scanlines overlay
- Horizon glow effect

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Dark purple | Base background color |
| `colour_2` | Color | - | Teal/cyan | Primary grid line color |
| `colour_3` | Color | - | Purple/magenta | Secondary grid color |
| `grid_speed` | Float | 0.0 - 2.0 | 0.3 | Animation speed of moving grid |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `grid_density` | Float | 5.0 - 50.0 | 20.0 | Number of grid lines |
| `perspective_strength` | Float | 0.0 - 2.0 | 1.0 | Depth perspective intensity |
| `glow_intensity` | Float | 0.0 - 2.0 | 1.2 | Brightness of neon glow |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.3 | CRT scanline visibility |

#### Parameter Recipes
- **Main Menu**: `grid_speed=0.3, glow_intensity=1.2, perspective_strength=1.0`
- **Settings Menu**: `grid_speed=0.15, glow_intensity=0.8`, darker colors
- **Gameplay Background**: `grid_speed=0.5`, more intense glow for energy

---

### 5. VHS Static Wave (`vhs_wave.gdshader`)

Layered horizontal wave patterns mimicking analog TV interference with chromatic aberration and rolling noise.

#### Visual Style
- Multi-frequency sine wave displacement
- Chromatic color separation (VHS tape degradation)
- Rolling interference bars
- TV static noise overlay
- CRT scanlines and vignette

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Very dark purple | Darkest wave layer |
| `colour_2` | Color | - | Medium purple | Mid-tone wave layer |
| `colour_3` | Color | - | Teal | Accent/highlight color |
| `wave_speed` | Float | 0.0 - 3.0 | 0.5 | Animation speed |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `wave_density` | Float | 3.0 - 20.0 | 8.0 | Number of wave patterns |
| `wave_amplitude` | Float | 0.0 - 0.2 | 0.05 | Wave displacement strength |
| `chromatic_drift` | Float | 0.0 - 0.1 | 0.02 | Color channel separation |
| `noise_strength` | Float | 0.0 - 0.5 | 0.15 | TV static intensity |
| `scanline_intensity` | Float | 0.0 - 1.0 | 0.4 | CRT scanline darkness |

#### Parameter Recipes
- **Main Menu**: `wave_speed=0.5, noise_strength=0.15`
- **Loading Screen**: `wave_speed=1.0, chromatic_drift=0.04` — more dramatic
- **Pause Menu**: `wave_speed=0.2` — subtle ambient

---

### 6. Arcade Starfield (`arcade_starfield.gdshader`)

Multi-layer parallax star field with color-cycling pixels, evoking 80's space arcade games.

#### Visual Style
- 4 depth layers of stars at different speeds
- Twinkling/pulsing star animation
- Color cycling between purple and teal
- Optional comet streak trails
- Subtle nebula color variations

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Dark purple | Space background |
| `colour_2` | Color | - | Purple/magenta | Primary star color |
| `colour_3` | Color | - | Teal/cyan | Secondary star color |
| `star_speed` | Float | 0.0 - 2.0 | 0.2 | Overall star movement |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `star_density` | Float | 50 - 500 | 200 | Number of stars |
| `twinkle_speed` | Float | 0.0 - 5.0 | 2.0 | Star pulsing rate |
| `comet_trails` | Float | 0.0 - 1.0 | 0.3 | Comet streak visibility |
| `color_cycle_speed` | Float | 0.0 - 3.0 | 1.0 | Color shift rate |

#### Parameter Recipes
- **Main Menu**: `star_speed=0.2, comet_trails=0.3` — calm
- **Victory Screen**: `star_speed=0.5, comet_trails=0.6` — celebratory
- **High Score**: `star_speed=0.1, color_cycle_speed=0.5` — gentle

---

## UI Effect Shaders

### 7. Enhanced Glow Overlay (`glow_overlay.gdshader`)

Upgraded from a basic color mix to a full retro effect system. **100% backward compatible** — existing code using `glow_strength` and `glow_color` continues to work unchanged. New parameters default to 0/off.

#### New Features
- **Chromatic Aberration**: RGB channel separation radiating from center
- **Pulse Animation**: Time-based glow strength oscillation
- **Edge Distortion**: Sine-wave UV warping around sprite edges
- **Rainbow Mode**: Hue-shifted glow based on angle from center
- **Multi-Radius Glow**: Inner sharp + outer soft bloom layers

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `glow_strength` | Float | 0.0 - 1.0 | 0.0 | Base glow intensity (original) |
| `glow_color` | Color | - | Yellow | Glow tint color (original) |
| `lock_overlay_strength` | Float | 0.0 - 1.0 | 0.0 | Lock darkening (original) |
| `lock_color` | Color | - | Semi-black | Lock tint (original) |
| `chromatic_offset` | Float | 0.0 - 0.05 | 0.0 | RGB channel separation |
| `pulse_speed` | Float | 0.0 - 5.0 | 0.0 | Pulsing animation rate |
| `edge_distortion` | Float | 0.0 - 0.3 | 0.0 | UV warp intensity |
| `rainbow_mode` | Bool | - | false | Angle-based hue shifting |
| `multi_radius_strength` | Float | 0.0 - 1.0 | 0.0 | Outer bloom strength |

#### Usage Example
```gdscript
# Basic usage (unchanged from before):
shader_mat.set_shader_parameter("glow_strength", 0.5)
shader_mat.set_shader_parameter("glow_color", Color(1, 1, 0.4, 1))

# Enhanced with new features:
shader_mat.set_shader_parameter("chromatic_offset", 0.02)
shader_mat.set_shader_parameter("pulse_speed", 2.0)
shader_mat.set_shader_parameter("multi_radius_strength", 0.5)
shader_mat.set_shader_parameter("rainbow_mode", true)
```

---

### 8. Holographic Energy Field (`power_up_ui.gdshader`)

Sci-fi hologram projection effect for power-up card art. Features scanning sweep lines, hexagonal energy grid overlay, and flickering edge glow. Controlled by `effect_strength` (0 = invisible, 1 = full hologram).

#### Visual Style
- Scanning sweep line (holographic projector feel)
- Hexagonal grid with randomly pulsing cells
- Flowing edge glow animation
- Color shimmer between primary and secondary colors
- Persistent horizontal scanlines
- Transparency modulation for shimmer effect

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `hologram_color` | Color | - | Teal | Primary energy color |
| `secondary_color` | Color | - | Purple | Shimmer shift color |
| `energy_speed` | Float | 0.0 - 3.0 | 1.5 | Animation speed |
| `scanline_frequency` | Float | 5.0 - 30.0 | 15.0 | Horizontal line density |
| `grid_scale` | Float | 0.1 - 1.0 | 0.4 | Hexagon size |
| `shimmer_strength` | Float | 0.0 - 1.0 | 0.5 | Overall effect opacity |
| `edge_glow_width` | Float | 0.0 - 0.2 | 0.08 | Border glow thickness |
| `effect_strength` | Float | 0.0 - 1.0 | 0.0 | Master on/off blend |

#### Usage Example
```gdscript
var shader = load("res://Scripts/Shaders/power_up_ui.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("effect_strength", 0.8)
shader_mat.set_shader_parameter("hologram_color", Color(0.0, 0.85, 0.9, 1.0))
shader_mat.set_shader_parameter("energy_speed", 1.5)
power_up_art.material = shader_mat

# Animate in via tween:
var tween = create_tween()
tween.tween_property(shader_mat, "shader_parameter/effect_strength", 1.0, 0.3)
```

---

### 9. Dramatic Burst (`consumable_explosion.gdshader`)

Multi-stage explosion effect for consumable use/sell animations. **Backward compatible** — when `explosion_stage = 0`, behaves exactly like the original simple circular fade. Set `explosion_stage > 0` to activate the new dramatic system.

#### Explosion Stages (explosion_stage 0.0 → 1.0)
1. **Flash** (0.0 - 0.15): White-hot center flash, rapid expansion
2. **Burst** (0.15 - 0.4): Main fireball expansion with color
3. **Streaks** (0.3 - 0.6): Radial lines emanating outward
4. **Shockwave** (0.35 - 0.8): Expanding ring
5. **Debris/Sparks** (0.2 - 0.9): Flying pixel particles scattered outward
6. **Fade** (0.7 - 1.0): Everything dissipates

#### Color Temperature Shift
When `color_temp_shift = true`, the explosion progresses:
- White-hot → base color → dark purple (over the explosion lifecycle)

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `color` | Color | - | Gold | Base explosion color |
| `spread` | Float | 0.0 - 1.0 | 0.5 | Legacy spread (compat) |
| `fade_speed` | Float | 0.1 - 5.0 | 1.0 | Legacy fade (compat) |
| `explosion_stage` | Float | 0.0 - 1.0 | 0.0 | Animation progress (0=legacy mode) |
| `streak_count` | Int | 4 - 24 | 12 | Number of radial streaks |
| `debris_size` | Float | 0.01 - 0.05 | 0.025 | Flying debris chunk size |
| `color_temp_shift` | Bool | - | true | White→color→purple fade |
| `shockwave_strength` | Float | 0.0 - 1.0 | 0.5 | Expanding ring intensity |
| `spark_intensity` | Float | 0.0 - 1.0 | 0.6 | Bright spark point amount |

#### Usage Example
```gdscript
# Animate explosion_stage from 0 to 1 over the particle lifetime:
var tween = create_tween()
tween.tween_property(shader_mat, "shader_parameter/explosion_stage", 1.0, 0.8)
```

---

## Color Palette Reference

### Standard 3-Color System (Background Shaders)
```gdscript
# Dark backgrounds
var dark_purple = Color(0.08, 0.04, 0.15, 1.0)      # colour_1 (deep space)
var medium_dark = Color(0.15, 0.08, 0.25, 1.0)       # colour_1 (grid base)

# Mid-tones
var medium_purple = Color(0.25, 0.12, 0.35, 1.0)     # colour_2 (waves)

# Accents (neon colors)
var magenta_neon = Color(0.8, 0.0, 1.0, 1.0)         # colour_2 (grid/stars)
var vivid_purple = Color(0.6, 0.0, 0.9, 1.0)         # colour_2 (plasma)
var teal_neon = Color(0.0, 0.8, 0.8, 1.0)            # colour_3 (highlights)
var cyan_neon = Color(0.0, 0.6, 0.7, 1.0)            # colour_3 (waves)
```

### Extended 5-Color System (Arcade Carpet)
```gdscript
var carpet_base = Color(0.06, 0.02, 0.12, 1.0)       # colour_1 (deep base)
var electric_purple = Color(0.5, 0.0, 0.8, 1.0)      # colour_2
var carpet_teal = Color(0.0, 0.75, 0.75, 1.0)        # colour_3
var hot_pink = Color(1.0, 0.2, 0.5, 1.0)             # colour_4
var neon_green = Color(0.0, 0.9, 0.4, 1.0)           # colour_5
```

### Marquee Bulb Colors
```gdscript
var bulb_gold = Color(1.0, 0.85, 0.2, 1.0)           # colour_2 (lit)
var bulb_dim = Color(0.15, 0.08, 0.05, 1.0)          # colour_3 (off)
var bulb_teal = Color(0.0, 0.9, 0.8, 1.0)            # bulb_alt_1
var bulb_purple = Color(0.8, 0.0, 1.0, 1.0)          # bulb_alt_2
```

---

## Integration Patterns

### Switching Background Shaders in main_menu.gd

```gdscript
# In _build_ui() where shader is loaded:

# NEW: Plasma Screen (demoscene organic)
var shader = load("res://Scripts/Shaders/plasma_screen.gdshader")

# NEW: Arcade Carpet (90s geometric)
#var shader = load("res://Scripts/Shaders/arcade_carpet.gdshader")

# NEW: Marquee Lights (theater borders)
#var shader = load("res://Scripts/Shaders/marquee_lights.gdshader")

# ORIGINAL: Neon Grid (Tron-style)
#var shader = load("res://Scripts/Shaders/neon_grid.gdshader")

# ORIGINAL: VHS Static Wave (Analog TV)
#var shader = load("res://Scripts/Shaders/vhs_wave.gdshader")

# ORIGINAL: Arcade Starfield (Space arcade)
#var shader = load("res://Scripts/Shaders/arcade_starfield.gdshader")
```

### Applying UI Effect Shaders to Cards

```gdscript
# Holographic power-up effect (in power_up_icon.gd):
var holo_shader = load("res://Scripts/Shaders/power_up_ui.gdshader")
var holo_mat = ShaderMaterial.new()
holo_mat.shader = holo_shader
holo_mat.set_shader_parameter("effect_strength", 0.0) # Start hidden
card_art.material = holo_mat

# Activate on hover:
func _on_mouse_entered():
    var tween = create_tween()
    tween.tween_property(holo_mat, "shader_parameter/effect_strength", 0.8, 0.2)
```

---

## Technical Reference

### Shared Pixelation Pattern
All background shaders use this identical technique:
```glsl
vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
float pixel_size = length(screen_size) / pixel_filter;
vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;
```
Higher `pixel_filter` = more pixels computed = smoother but more expensive.

### Pseudo-Random Hash Functions
```glsl
// Standard position hash:
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Secondary hash (different distribution):
float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(269.5, 183.3))) * 23761.9134211);
}
```

### Performance Notes
- All background shaders use pixelation filters which reduce computation
- Higher `pixel_filter` values = better performance (fewer pixels computed)
- Recommended range: 400-600 for menus, 300-400 for gameplay
- `marquee_lights` has a loop per frame — keep `frame_count` ≤ 3 for low-end hardware
- `arcade_carpet` pattern_style=2 (Memphis) is cheapest; style=1 (Starbursts) is most expensive
- UI effect shaders (`glow_overlay`, `power_up_ui`) are cheap when `effect_strength = 0`

---

## Shader Gallery Test Scene

Preview all background shaders interactively using:

```
& "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/ShaderGallery.tscn
```

### Controls
| Key | Action |
|-----|--------|
| 1-9 | Switch between shaders |
| C | Toggle side-by-side comparison mode |
| ←/→ | Change comparison shader (in compare mode) |
| ESC | Quit |

### Shader List in Gallery
1. Plasma Screen
2. Arcade Carpet - Diamonds
3. Arcade Carpet - Starbursts
4. Arcade Carpet - Memphis
5. Marquee Lights
6. Neon Grid (original)
7. VHS Static Wave (original)
8. Arcade Starfield (original)
9. Background Swirl (legacy)

---

## Credits

Created for **DiceRogue (Guhtzee)** — A late 80's/early 90's arcade-inspired dice roguelite.
Background swirl shader adapted from Balatro (credit: LocalThunk). All other shaders are original.
