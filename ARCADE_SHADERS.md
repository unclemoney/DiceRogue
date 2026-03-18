# Arcade Shader Collection

A comprehensive library of custom shaders for DiceRogue (Guhtzee), capturing the nostalgic aesthetic of late 80's/early 90's arcades, malls, and SNES-era pixel art. Purple/teal neon color schemes throughout.

## Overview

The shader collection is organized into three categories:

### Background Shaders (11 total)
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
| `jazz_cup` | Teal swoosh & purple brush strokes | 90s Solo Jazz cup (1991) |
| `memphis_geo` | Scattered geometric shapes | Memphis Group design (late 80s) |
| `zigzag_bolts` | Bold zigzag stripes & confetti | Saved By The Bell / Trapper Keeper |
| `neon_city` | Scrolling cityscape silhouette | Synthwave / cyberpunk |

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

## Background Shaders - 90s Pop Culture Set

### 10. Jazz Cup (`jazz_cup.gdshader`)

Procedural recreation of the iconic Solo Jazz paper cup design (1991) — large teal swoosh arcs on an off-white field with thinner purple/magenta brush strokes. The design that defined disposable cup aesthetics for a decade.

#### Visual Style
- Multiple layered sine/cosine swoosh curves with varying thickness
- Natural brush-edge noise via fractional Brownian motion (fbm)
- Distance-tapered strokes: thick in center, thin at edges
- Paint texture variation within swoosh fills
- Subtle paper-grain speckle overlay
- Slow drift animation (swooshes gently shift position)

#### Technical Deep-Dive
Each swoosh is generated from a sine curve with distance-field rendering:
1. Curve position: `y = sin(x * freq + offset + drift)` at varying amplitudes
2. Distance from pixel to curve: `abs(uv.y - curve_y)`
3. Tapering: `smoothstep()` at both x-endpoints creates natural brush lift
4. Edge noise: 4-octave fbm adds organic brush-edge imperfections
5. Final blend: `smoothstep(thickness + noise, thickness*0.3 + noise, dist)` for anti-aliased strokes

Three teal swooshes (large arc, thinner upper, small accent) plus two purple strokes create the classic layered look.

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Off-white | Paper background color |
| `colour_2` | Color | - | Teal | Large splash/swoosh color |
| `colour_3` | Color | - | Purple | Thin brush stroke color |
| `drift_speed` | Float | 0.0 - 1.0 | 0.08 | Swoosh animation drift speed |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `swoosh_scale` | Float | 0.5 - 3.0 | 1.0 | Overall pattern zoom |
| `stroke_thickness` | Float | 0.5 - 2.0 | 1.0 | Brush stroke width multiplier |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.08 | CRT scanline overlay |
| `speckle_amount` | Float | 0.0 - 1.0 | 0.3 | Paper grain / paint splatter |
| `teal_opacity` | Float | 0.5 - 1.0 | 0.92 | Teal swoosh opacity |
| `purple_opacity` | Float | 0.5 - 1.0 | 0.88 | Purple stroke opacity |

#### Parameter Recipes
- **Classic Cup**: `drift_speed=0.08, swoosh_scale=1.0, stroke_thickness=1.0, pixel_filter=500`
- **Bold Statement**: `stroke_thickness=1.5, teal_opacity=1.0, purple_opacity=1.0, pixel_filter=600`
- **Subtle Background**: `drift_speed=0.04, speckle_amount=0.15, scanline_strength=0.15, pixel_filter=400`
- **Energetic**: `drift_speed=0.2, swoosh_scale=0.8, stroke_thickness=1.3`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/jazz_cup.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.95, 0.95, 0.93, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.0, 0.75, 0.78, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.55, 0.0, 0.85, 1.0))
shader_mat.set_shader_parameter("drift_speed", 0.08)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 11. Memphis Geo (`memphis_geo.gdshader`)

Scattered geometric shapes on a bright teal field, inspired by the Memphis Group postmodern design movement (late 80s/early 90s Italy). Features circles, triangles, diamonds, rings, grid-spheres, zigzag decorations, and confetti dots.

#### Visual Style
- Hash-based deterministic random placement of shapes in a grid
- 7 shape types: filled circle, ring, equilateral triangle, diamond, grid-sphere (crosshatch circle), confetti cluster, zigzag line
- 5-color palette for authentic Memphis variety
- Two shape layers: large background shapes + small foreground details
- Subtle diagonal stripe texture in background
- Slow pan/scroll animation; shapes gently float

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Bright teal | Background field color |
| `colour_2` | Color | - | Purple | Shape color 1 |
| `colour_3` | Color | - | Hot pink | Shape color 2 |
| `colour_4` | Color | - | Yellow | Shape color 3 |
| `colour_5` | Color | - | White | Accent / detail color |
| `scroll_speed` | Float | 0.0 - 1.0 | 0.06 | Pan scroll speed |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `shape_density` | Float | 3.0 - 15.0 | 7.0 | Grid cells per axis (more = more shapes) |
| `shape_scale` | Float | 0.5 - 2.0 | 1.0 | Individual shape size multiplier |
| `glow_amount` | Float | 0.0 - 1.0 | 0.3 | Shape glow / halo intensity |
| `rotation_speed` | Float | 0.0 - 1.0 | 0.15 | Shape rotation rate |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.05 | CRT scanline overlay |

#### Parameter Recipes
- **Classic Memphis**: `shape_density=7.0, shape_scale=1.0, rotation_speed=0.15, glow_amount=0.3`
- **Busy Pattern**: `shape_density=12.0, shape_scale=0.8, rotation_speed=0.25, glow_amount=0.4`
- **Minimal Accent**: `shape_density=4.0, shape_scale=1.3, rotation_speed=0.08, glow_amount=0.15`
- **Party Mode**: `shape_density=10.0, scroll_speed=0.15, rotation_speed=0.3, glow_amount=0.5`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/memphis_geo.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.0, 0.9, 0.82, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.55, 0.0, 0.85, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(1.0, 0.2, 0.55, 1.0))
shader_mat.set_shader_parameter("colour_4", Color(1.0, 0.85, 0.1, 1.0))
shader_mat.set_shader_parameter("colour_5", Color(0.95, 0.95, 0.95, 1.0))
shader_mat.set_shader_parameter("shape_density", 7.0)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 12. Zigzag Bolts (`zigzag_bolts.gdshader`)

Saved By The Bell–style bold zigzag stripes with scattered confetti shapes. Bright, energetic, unapologetically 90s — the visual language of teen TV show title cards and Trapper Keeper art.

#### Visual Style
- Multiple thick diagonal zigzag "lightning bolt" stripes across the screen
- Triangle, circle, and 4-pointed star confetti scattered between bolts
- Color-blocked background bands
- Bold outlines on zigzag stripes
- Thin sine-wave accent lines
- Horizontal scroll animation

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Neon yellow | Background color |
| `colour_2` | Color | - | Bold purple | Bolt/confetti color 1 |
| `colour_3` | Color | - | Teal | Bolt/confetti color 2 |
| `colour_4` | Color | - | Hot pink | Bolt/confetti color 3 |
| `scroll_speed` | Float | 0.0 - 1.0 | 0.1 | Horizontal scroll rate |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `bolt_count` | Float | 2.0 - 8.0 | 4.0 | Number of zigzag stripes |
| `bolt_thickness` | Float | 0.5 - 2.0 | 1.0 | Stripe width multiplier |
| `confetti_density` | Float | 0.0 - 1.0 | 0.5 | Scattered shape density |
| `color_block_strength` | Float | 0.0 - 1.0 | 0.4 | Background banding intensity |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.08 | CRT scanline overlay |

#### Parameter Recipes
- **Classic SBTB**: `bolt_count=4.0, bolt_thickness=1.0, confetti_density=0.5, color_block_strength=0.4`
- **Intense**: `bolt_count=6.0, bolt_thickness=1.3, confetti_density=0.7, scroll_speed=0.2`
- **Minimal**: `bolt_count=3.0, bolt_thickness=0.7, confetti_density=0.2, color_block_strength=0.2`
- **Dark Variant**: Use dark colour_1, lighter bolt colors for a nightclub vibe

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/zigzag_bolts.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.95, 0.95, 0.1, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.55, 0.0, 0.9, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.0, 0.85, 0.8, 1.0))
shader_mat.set_shader_parameter("colour_4", Color(1.0, 0.15, 0.5, 1.0))
shader_mat.set_shader_parameter("bolt_count", 4.0)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 13. Neon City (`neon_city.gdshader`)

Scrolling pixel-art cityscape silhouette against a gradient night sky with flickering neon signs. Evokes synthwave album covers, cyberpunk aesthetics, and 80s/90s sci-fi.

#### Visual Style
- 3-layer parallax building silhouettes at different scroll speeds
- Procedurally generated building heights/widths via hash functions
- Lit/unlit window grid patterns on each building layer
- Flickering neon sign rectangles in teal/purple/pink
- Neon glow bleed effect around signs
- Twinkling stars in the sky portion
- Purple-to-dark gradient night sky with horizon glow

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Deep dark blue | Sky gradient top |
| `colour_2` | Color | - | Purple horizon | Sky gradient bottom |
| `colour_3` | Color | - | Near-black | Building silhouette color |
| `neon_color_1` | Color | - | Teal | Neon sign color 1 |
| `neon_color_2` | Color | - | Purple | Neon sign color 2 |
| `neon_color_3` | Color | - | Pink | Neon sign color 3 |
| `scroll_speed` | Float | 0.0 - 1.0 | 0.12 | Building scroll rate |
| `pixel_filter` | Float | 200 - 1000 | 450 | Pixelation amount |
| `building_density` | Float | 5.0 - 25.0 | 12.0 | Buildings per screen width |
| `neon_flicker_speed` | Float | 0.5 - 5.0 | 2.0 | Neon sign flicker rate |
| `neon_glow_intensity` | Float | 0.0 - 2.0 | 1.2 | Neon brightness/glow |
| `star_density` | Float | 50 - 500 | 150 | Stars in the sky |
| `horizon_glow` | Float | 0.0 - 1.0 | 0.5 | Glow at city horizon |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.12 | CRT scanline overlay |

#### Parameter Recipes
- **Cyberpunk Night**: `scroll_speed=0.12, neon_glow_intensity=1.2, horizon_glow=0.5, building_density=12`
- **Calm Evening**: `scroll_speed=0.06, neon_flicker_speed=1.0, neon_glow_intensity=0.7, star_density=250`
- **Blade Runner**: `scroll_speed=0.08, neon_glow_intensity=1.8, horizon_glow=0.8, building_density=18`
- **Quiet Suburbs**: `building_density=6.0, neon_glow_intensity=0.4, star_density=300, horizon_glow=0.2`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/neon_city.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.02, 0.01, 0.08, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.12, 0.04, 0.25, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.04, 0.03, 0.06, 1.0))
shader_mat.set_shader_parameter("neon_color_1", Color(0.0, 0.9, 0.85, 1.0))
shader_mat.set_shader_parameter("neon_color_2", Color(0.85, 0.0, 1.0, 1.0))
shader_mat.set_shader_parameter("neon_color_3", Color(1.0, 0.2, 0.5, 1.0))
shader_mat.set_shader_parameter("scroll_speed", 0.12)
shader_mat.set_shader_parameter("pixel_filter", 450.0)
background.material = shader_mat
```

---

### 14. Neon Raindrop (`neon_raindrop.gdshader`)

Trapper Keeper–inspired teal-to-pink gradient surface with procedural 3D water droplets across three parallax layers. Each droplet has refraction, dual specular highlights, iridescent rainbow edges, and drip streaks.

#### Visual Style
- Smooth teal-to-magenta gradient background
- 3 parallax droplet layers at different depths/speeds
- Fake refraction (UV offset inside droplet lens)
- Dual specular highlights per drop
- Iridescent thin-film rainbow along droplet edges
- Vertical drip streaks trailing below each drop
- Shadow underneath drops for depth

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Teal | Gradient top color |
| `colour_2` | Color | - | Magenta | Gradient bottom color |
| `colour_3` | Color | - | Pink | Highlight tint |
| `drop_density` | Float | 3.0 - 15.0 | 8.0 | Droplets per grid unit |
| `drift_speed` | Float | 0.0 - 0.5 | 0.15 | Droplet drift rate |
| `drop_size` | Float | 0.5 - 2.0 | 1.0 | Overall droplet scale |
| `refraction_strength` | Float | 0.0 - 1.0 | 0.5 | UV distortion inside drops |
| `highlight_intensity` | Float | 0.0 - 1.0 | 0.6 | Specular brightness |
| `streak_amount` | Float | 0.0 - 1.0 | 0.5 | Drip streak visibility |
| `iridescence` | Float | 0.0 - 1.0 | 0.4 | Rainbow edge strength |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.05 | CRT scanline overlay |

#### Parameter Recipes
- **Classic Trapper Keeper**: `drop_density=8, refraction_strength=0.5, iridescence=0.4`
- **Rainy Window**: `drop_density=12, drift_speed=0.25, streak_amount=0.8, drop_size=0.7`
- **Dew Drops**: `drop_density=5, drift_speed=0.05, highlight_intensity=0.8, drop_size=1.5`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/neon_raindrop.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.0, 0.6, 0.65, 1.0))
shader_mat.set_shader_parameter("colour_2", Color(0.85, 0.0, 0.55, 1.0))
shader_mat.set_shader_parameter("drop_density", 8.0)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 15. Neon Objects (`neon_objects.gdshader`)

Floating 3D geometric shapes on a dark perspective grid — cubes, spheres, wireframe pyramids, and faceted diamonds drifting in space with neon edge glow, chrome rainbow sheen, and depth fog. Classic Trapper Keeper art circa 1989.

#### Visual Style
- Dark void background with subtle perspective grid
- 4 shape types: sphere (specular), isometric cube (3-face lit), wireframe pyramid, faceted diamond
- Shapes rotate and bob in place at varying speeds
- Neon edge glow per shape
- Chrome/rainbow color sheen (hue shift over time)
- Depth fog fading distant shapes
- Hash-grid placement for even distribution

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Deep dark void | Background color |
| `colour_2` | Color | - | Teal | Grid line color |
| `colour_3` | Color | - | Purple | Grid accent color |
| `shape_color_1` | Color | - | Blue | Shape palette 1 |
| `shape_color_2` | Color | - | Pink | Shape palette 2 |
| `shape_color_3` | Color | - | Cyan | Shape palette 3 |
| `shape_density` | Float | 2.0 - 10.0 | 5.0 | Shapes per grid unit |
| `float_speed` | Float | 0.0 - 1.0 | 0.15 | Bobbing animation speed |
| `rotation_speed` | Float | 0.0 - 1.0 | 0.25 | Shape rotation speed |
| `grid_opacity` | Float | 0.0 - 1.0 | 0.35 | Background grid visibility |
| `glow_intensity` | Float | 0.0 - 2.0 | 1.0 | Neon edge glow |
| `chrome_sheen` | Float | 0.0 - 1.0 | 0.4 | Rainbow chrome effect |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.08 | CRT scanline overlay |

#### Parameter Recipes
- **Trapper Keeper Classic**: `shape_density=5, glow_intensity=1.0, chrome_sheen=0.4`
- **Minimal Float**: `shape_density=3, grid_opacity=0.1, glow_intensity=0.5`
- **Maximum Chrome**: `chrome_sheen=0.9, glow_intensity=1.5, rotation_speed=0.5`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/neon_objects.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.04, 0.02, 0.12, 1.0))
shader_mat.set_shader_parameter("shape_color_1", Color(0.1, 0.5, 0.95, 1.0))
shader_mat.set_shader_parameter("shape_density", 5.0)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 16. Paint Splatter (`paint_splatter.gdshader`)

Animated neon paint canvas where splats accumulate over a 20-second cycle, then cross-dissolve and reset. Each splat has FBM noise edges, spray particles, drip streaks, and glow halos. Trapper Keeper art-class energy.

#### Visual Style
- Dark canvas background with subtle texture
- 16 procedural splats appear one-by-one over the cycle
- FBM noise-edge blobs for organic splat shapes
- 10 spray particles per splat (radial scatter)
- Vertical drip streaks with rounded tips
- Glow halo around each splat
- Cross-dissolve fade at cycle end, then fresh cycle begins

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Dark canvas | Background |
| `colour_2` | Color | - | Teal | Splat color 1 |
| `colour_3` | Color | - | Magenta | Splat color 2 |
| `colour_4` | Color | - | Yellow | Splat color 3 |
| `colour_5` | Color | - | Blue | Splat color 4 |
| `splat_rate` | Float | 3.0 - 12.0 | 6.0 | Splats per cycle |
| `splat_size` | Float | 0.5 - 2.0 | 1.0 | Overall splat scale |
| `drip_amount` | Float | 0.0 - 1.0 | 0.5 | Drip streak length |
| `spray_density` | Float | 0.0 - 1.0 | 0.6 | Spray particle count |
| `cycle_duration` | Float | 10.0 - 60.0 | 20.0 | Seconds per cycle |
| `glow_amount` | Float | 0.0 - 1.0 | 0.4 | Glow halo intensity |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.05 | CRT scanline overlay |

#### Parameter Recipes
- **Paint Party**: `splat_rate=10, cycle_duration=15, glow_amount=0.6`
- **Slow Art**: `splat_rate=4, cycle_duration=30, drip_amount=0.8`
- **Neon Chaos**: `splat_rate=12, splat_size=1.5, spray_density=0.9, glow_amount=0.8`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/paint_splatter.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("cycle_duration", 20.0)
shader_mat.set_shader_parameter("splat_rate", 6.0)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 17. Mystify Screen (`mystify_screen.gdshader`)

Faithful recreation of the Windows 3.1 "Mystify Your Mind" screensaver — two quadrilateral polygons with vertices bouncing off screen walls, leaving glowing color trails that fade over time. Pure early-90s nostalgia on a black field.

#### Visual Style
- Black background (zero light)
- 2 polygon groups (cyan and magenta by default)
- 4 vertices per polygon bouncing linearly (triangle wave off walls)
- Ghost trail: 10 past polygon positions rendered with fading opacity
- Thin glowing line edges with soft bloom
- Older ghosts drawn thinner and dimmer
- Additive blending for glow buildup at trail crossings

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Black | Background color |
| `colour_2` | Color | - | Cyan | Polygon 1 color |
| `colour_3` | Color | - | Magenta | Polygon 2 color |
| `move_speed` | Float | 0.1 - 2.0 | 0.7 | Vertex bounce speed |
| `trail_length` | Float | 3.0 - 16.0 | 10.0 | Ghost trail count |
| `line_thickness` | Float | 0.001 - 0.008 | 0.003 | Line edge width |
| `glow_width` | Float | 0.5 - 3.0 | 1.5 | Bloom spread |
| `pixel_filter` | Float | 200 - 1000 | 600 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.05 | CRT scanline overlay |

#### Parameter Recipes
- **Classic Win 3.1**: `move_speed=0.7, trail_length=10, line_thickness=0.003`
- **Hyperactive**: `move_speed=1.5, trail_length=6, glow_width=2.0`
- **Zen Drift**: `move_speed=0.2, trail_length=14, glow_width=1.0`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/mystify_screen.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_2", Color(0.0, 0.95, 0.95, 1.0))
shader_mat.set_shader_parameter("colour_3", Color(0.95, 0.0, 0.95, 1.0))
shader_mat.set_shader_parameter("move_speed", 0.7)
shader_mat.set_shader_parameter("pixel_filter", 600.0)
background.material = shader_mat
```

---

### 18. Nick Splat (`nick_splat.gdshader`)

90s Nickelodeon bumper/promo chaos — bold orange background covered in scattered hand-drawn doodles: scribble clouds with hatching, zigzag arrows, S-squiggles, spiral doodles, chevron waves, and confetti triangles. Every element drifts and rotates slowly.

#### Visual Style
- Bright orange background with subtle diagonal stripe texture
- Scattered large shapes (scribble clouds, arrows, squiggles, spirals, chevrons, triangles)
- Hand-drawn roughened edges via value noise
- Hatching texture inside cloud shapes
- Tiny confetti dots and mini-squiggles as detail layer
- Black outline behind each shape for hand-drawn look
- 5-color palette (orange, purple, teal, pink, yellow)

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Nick orange | Background |
| `colour_2` | Color | - | Purple | Scribble color 1 |
| `colour_3` | Color | - | Teal/mint | Shape color 2 |
| `colour_4` | Color | - | Hot pink | Accent color 3 |
| `colour_5` | Color | - | Yellow | Squiggle color 4 |
| `chaos_density` | Float | 3.0 - 12.0 | 6.0 | Element grid density |
| `drift_speed` | Float | 0.0 - 0.5 | 0.08 | Drift/rotation rate |
| `doodle_scale` | Float | 0.5 - 2.0 | 1.0 | Overall element size |
| `roughness` | Float | 0.0 - 1.0 | 0.6 | Edge roughness amount |
| `pixel_filter` | Float | 200 - 1000 | 450 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.05 | CRT scanline overlay |

#### Parameter Recipes
- **Classic Nick**: `chaos_density=6, roughness=0.6, drift_speed=0.08`
- **Manic Energy**: `chaos_density=10, drift_speed=0.2, doodle_scale=0.7`
- **Chill Doodle**: `chaos_density=4, drift_speed=0.03, doodle_scale=1.3, roughness=0.3`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/nick_splat.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("colour_1", Color(0.98, 0.55, 0.0, 1.0))
shader_mat.set_shader_parameter("chaos_density", 6.0)
shader_mat.set_shader_parameter("pixel_filter", 450.0)
background.material = shader_mat
```

---

### 19. Laser Show (`laser_show.gdshader`)

80s arena rock laser light show — vivid laser beams sweeping through volumetric smoke in a dark venue. Beams originate from screen edges, sweep back and forth, scatter through procedural FBM fog, and create bright flares at intersection points.

#### Visual Style
- Near-black background with subtle gradient
- 7 laser beams (green, red, blue, yellow) from screen edges
- Each beam sweeps with unique speed and phase
- FBM fog volumes that scatter beam light
- Bright flares at beam origins
- White-hot flares at beam intersections
- Gaussian beam core with wider glow halo

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Deep purple-black | Background |
| `colour_2` | Color | - | Green | Argon laser |
| `colour_3` | Color | - | Red | Helium-neon laser |
| `colour_4` | Color | - | Blue | Krypton laser |
| `colour_5` | Color | - | Yellow | Fourth beam color |
| `beam_count` | Float | 3.0 - 12.0 | 7.0 | Number of beams |
| `sweep_speed` | Float | 0.1 - 2.0 | 0.6 | Sweep oscillation rate |
| `beam_width` | Float | 0.001 - 0.01 | 0.004 | Beam core thickness |
| `glow_intensity` | Float | 0.5 - 4.0 | 2.0 | Beam brightness |
| `fog_density` | Float | 0.0 - 1.0 | 0.5 | Fog volume amount |
| `flare_intensity` | Float | 0.0 - 2.0 | 1.0 | Origin/intersection flares |
| `pixel_filter` | Float | 200 - 1000 | 550 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.1 | CRT scanline overlay |

#### Parameter Recipes
- **Arena Rock**: `beam_count=7, sweep_speed=0.6, fog_density=0.5, flare_intensity=1.0`
- **Planetarium**: `beam_count=10, sweep_speed=0.3, fog_density=0.8, glow_intensity=3.0`
- **Disco Minimal**: `beam_count=4, sweep_speed=1.0, fog_density=0.2, beam_width=0.006`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/laser_show.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("beam_count", 7.0)
shader_mat.set_shader_parameter("fog_density", 0.5)
shader_mat.set_shader_parameter("pixel_filter", 550.0)
background.material = shader_mat
```

---

### 20. Pinball Machine (`pinball_machine.gdshader`)

Top-down 80s pinball playfield with round bumpers that flash on activation, chrome guide rails, chase-animated arrow lanes, blinking star inserts, and a chrome border frame. Inspired by classic pins like High Speed and Black Knight.

#### Visual Style
- Deep blue playfield with diamond pattern underlay
- Round bumpers with chrome cap rings and activation flash
- Curved chrome guide rails with sliding specular highlights
- 3 arrow chase lanes at bottom (triangles pointing up)
- Diamond-shaped star rollover inserts (blinking)
- Chrome rounded-rect frame border
- Occasional "TILT" red flash pulse

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Deep blue | Playfield color |
| `colour_2` | Color | - | Red | Bumper color 1 |
| `colour_3` | Color | - | Orange/gold | Bumper color 2 |
| `colour_4` | Color | - | Chrome silver | Rail/frame color |
| `colour_5` | Color | - | Green | Arrow/insert color |
| `bumper_density` | Float | 3.0 - 8.0 | 5.0 | Bumper grid density |
| `flash_speed` | Float | 0.5 - 3.0 | 1.5 | Activation flash rate |
| `rail_count` | Float | 2.0 - 6.0 | 4.0 | Number of guide rails |
| `glow_intensity` | Float | 0.5 - 3.0 | 1.8 | Bumper/arrow glow |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.08 | CRT scanline overlay |

#### Parameter Recipes
- **Classic Pin**: `bumper_density=5, flash_speed=1.5, rail_count=4`
- **High Score Frenzy**: `flash_speed=2.5, glow_intensity=2.5`
- **Quiet Table**: `flash_speed=0.7, glow_intensity=1.0, bumper_density=3`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/pinball_machine.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("bumper_density", 5.0)
shader_mat.set_shader_parameter("flash_speed", 1.5)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 21. Cassette Reel (`cassette_reel.gdshader`)

Detailed view of an 80s cassette tape with spinning reel hubs, visible magnetic tape with iridescent rainbow shimmer, chrome screw heads, a cream paper label with ruled lines, and a blinking recording LED. Pure Walkman-era nostalgia.

#### Visual Style
- Dark plastic cassette shell with chrome edge trim
- Cream-colored label area with horizontal ruled lines
- Tape window showing moving magnetic tape between reels
- Two reel hubs (6-spoke) spinning at different rates (supply slower, take-up faster)
- Iridescent thin-film rainbow on tape surface
- 4 Phillips-head chrome screws at corners
- Tape guide pins flanking the window
- Red recording LED with blinking glow halo

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Dark grey | Shell plastic |
| `colour_2` | Color | - | Brown | Magnetic tape |
| `colour_3` | Color | - | Chrome silver | Metallic parts |
| `colour_4` | Color | - | Cream | Label area |
| `colour_5` | Color | - | Red | Recording LED |
| `reel_speed` | Float | 0.2 - 3.0 | 1.2 | Reel rotation speed |
| `tape_shimmer` | Float | 0.0 - 1.0 | 0.7 | Tape streak visibility |
| `iridescence_amount` | Float | 0.0 - 1.0 | 0.6 | Rainbow tape sheen |
| `recording_blink` | Float | 0.0 - 1.0 | 0.8 | LED blink intensity |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.08 | CRT scanline overlay |

#### Parameter Recipes
- **Mixtape Vibes**: `reel_speed=1.2, iridescence_amount=0.6, recording_blink=0.8`
- **Chrome Deluxe**: `tape_shimmer=0.9, iridescence_amount=0.9, reel_speed=0.8`
- **Stalled Tape**: `reel_speed=0.3, recording_blink=0.0, tape_shimmer=0.3`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/cassette_reel.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("reel_speed", 1.2)
shader_mat.set_shader_parameter("iridescence_amount", 0.6)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
```

---

### 22. Roller Rink (`roller_rink.gdshader`)

Perspective hardwood roller rink floor with sweeping disco ball light spots, colored gel washes, lane stripe markings, and a distant foggy horizon. A tiny disco ball sparkles at the top. Saturday night at the skating rink, circa 1986.

#### Visual Style
- Perspective-projected hardwood floor with plank texture and grain
- Multiple disco ball light spots following circular/elliptical orbits
- Light spots scale with perspective (bigger near camera)
- Pink/blue/purple colored light discs with specular centers
- Overhead color gel washes (broad pink and blue)
- Center and lane boundary stripe markings
- Dark ceiling above horizon with fog glow
- Chrome disco ball hint at top with spinning sparkle
- Staggered plank joints and gap lines

#### Parameters

| Parameter | Type | Range | Default | Description |
|-----------|------|-------|---------|-------------|
| `colour_1` | Color | - | Warm wood | Base wood tone |
| `colour_2` | Color | - | Light wood | Grain highlight |
| `colour_3` | Color | - | Pink | Disco light 1 |
| `colour_4` | Color | - | Blue | Disco light 2 |
| `colour_5` | Color | - | Purple | Disco light 3 |
| `disco_speed` | Float | 0.1 - 2.0 | 0.5 | Light orbit speed |
| `light_count` | Float | 3.0 - 12.0 | 8.0 | Number of light spots |
| `specular_intensity` | Float | 0.0 - 2.0 | 1.2 | Floor specular highlights |
| `fog_amount` | Float | 0.0 - 1.0 | 0.3 | Horizon fog density |
| `perspective_strength` | Float | 0.5 - 2.0 | 1.2 | Floor perspective effect |
| `pixel_filter` | Float | 200 - 1000 | 500 | Pixelation amount |
| `scanline_strength` | Float | 0.0 - 1.0 | 0.08 | CRT scanline overlay |

#### Parameter Recipes
- **Saturday Night**: `disco_speed=0.5, light_count=8, specular_intensity=1.2`
- **Twilight Session**: `disco_speed=0.3, light_count=5, fog_amount=0.6, specular_intensity=0.8`
- **Disco Inferno**: `disco_speed=1.0, light_count=12, specular_intensity=2.0, fog_amount=0.1`

#### Code Example
```gdscript
var shader = load("res://Scripts/Shaders/roller_rink.gdshader")
var shader_mat = ShaderMaterial.new()
shader_mat.shader = shader
shader_mat.set_shader_parameter("disco_speed", 0.5)
shader_mat.set_shader_parameter("light_count", 8.0)
shader_mat.set_shader_parameter("pixel_filter", 500.0)
background.material = shader_mat
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
| 1-0 | Switch shaders 1-10 |
| Shift+1-0 | Switch shaders 11-20 |
| Up/Down | Switch shaders 21-22 |
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
10. Jazz Cup (90s paper cup)
11. Memphis Geo (geometric shapes)
12. Zigzag Bolts (Saved By The Bell)
13. Neon City (cyberpunk skyline)
14. Neon Raindrop (Trapper Keeper water drops)
15. Neon Objects (floating 3D shapes)
16. Paint Splatter (accumulating neon splats)
17. Mystify Screen (Win 3.1 screensaver)
18. Nick Splat (90s Nickelodeon chaos)
19. Laser Show (80s arena lasers)
20. Pinball Machine (80s playfield)
21. Cassette Reel (Walkman tape)
22. Roller Rink (disco ball floor)

---

## Credits

Created for **DiceRogue (Guhtzee)** — A late 80's/early 90's arcade-inspired dice roguelite.
Background swirl shader adapted from Balatro (credit: LocalThunk). All other shaders are original.
