# Refactor Plan — Mall-Core Kiosk Tile Power-Up UI

## Objective
Modernize the fan-out power-up presentation by replacing the flat `PowerUpIcon` card with a glossy, mall-core **Kiosk Tile**, while preserving the existing Fan-Out behavior, selection/sell logic, and compact spine view.

---

## Current Architecture

| Component | Role |
|-----------|------|
| `PowerUpUI` (`Scripts/UI/power_up_ui.gd`) | Owns the compact spine row and fans out `PowerUpIcon` instances onto a shared overlay. |
| `PowerUpSpine` (`Scripts/UI/power_up_spine.gd`) | Small 72×80 shelf representation shown in the compact row. **Unchanged** by this refactor. |
| `PowerUpIcon` (`Scripts/UI/power_up_icon.gd` + `Scenes/PowerUp/power_up_icon.tscn`) | 120×180 card used only in the fan-out view. Contains card art, frame, title, hover tooltip, rarity icon, and sell button. |
| `FanOverlayHelper` | Provides the shared `CanvasLayer` overlay used by fan-out UIs. |
| `card_perspective.gdshader` | Gives the existing card a slight 3D tilt and glow. |
| `PowerUpData` | Resource with `id`, `display_name`, `description`, `icon`, `rarity`, `rating`, etc. |

The fan-out layout is calculated in `PowerUpUI._calculate_fan_positions(count)` using hard-coded 120×180 card dimensions and a max of 5 cards per row.

---

## Target Architecture

### Core Decision: Compatibility Wrapper
`PowerUpIcon` will be kept as a compatibility shell. It will internally instantiate and manage a new `KioskTile` scene, forwarding data, signals, and public methods. A boolean toggle (`_use_legacy_layout`) lets us fall back to the old card structure instantly if needed.

This preserves the contract with `PowerUpUI`, which instantiates `power_up_icon_scene` and expects `PowerUpIcon` signals (`power_up_selected`, `power_up_deselected`, `power_up_sell_requested`).

---

## New Scene: `Scenes/PowerUp/kiosk_tile.tscn`

### Script
`Scripts/UI/kiosk_tile.gd` — `extends Control`, `class_name KioskTile`.

### Node Hierarchy

```
KioskTile (Control)
│  custom_minimum_size = Vector2(160, 240)  # confirmed size
│  mouse_filter = MOUSE_FILTER_PASS
│
├── ChromePanel (PanelContainer)
│   │  size = full rect
│   │  material = kiosk_tile.gdshader (ShaderMaterial)
│   │
│   ├── ChromeBackground (ColorRect)
│   │      material = kiosk_tile.gdshader
│   │      anchors = full rect
│   │      mouse_filter = ignore
│   │
│   └── ChromePanel (PanelContainer)
│       │  mouse_filter = pass
│       │
│       └── InnerMargin (MarginContainer)
│           │  margins: 8
│           │
│           ├── ContentVBox (VBoxContainer)
│           │   │  separation = 6
│           │   │
│           │   ├── TitleBar (PanelContainer)
│           │   │   └── TitleLabel (Label)
│           │   │       font: VCR, size 14, uppercase, centered
│           │   │
│           │   ├── ArtPanel (PanelContainer)
│           │   │   │  size_flags_vertical = SIZE_EXPAND_FILL
│           │   │   │
│           │   │   ├── Artwork (TextureRect)
│           │   │   │      expand_mode = EXPAND_FIT_WIDTH_PROPORTIONAL
│           │   │   │      stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
│           │   │   │
│           │   │   └── ReflectionOverlay (TextureRect)
│           │   │          modulate = Color(1,1,1,0.0)
│           │   │          toggled on hover
│           │   │
│           │   ├── DescriptionPanel (PanelContainer)
│           │   │   └── DescriptionLabel (Label)
│           │   │       font: VCR, size 10, autowrap
│           │   │
│           │   └── ActionBar (HBoxContainer)
│           │       └── SellButton (Button)
│           │           text = "SELL"
│           │           theme = action_button_theme.tres
│           │
│           └── StickerBadge (StickerBadge)
│               anchor = top-right of ChromePanel
│               offset = (-4, 4)
```

### Visual Layers
| Node | Purpose |
|------|---------|
| `ChromeBackground` | Full-rect `ColorRect` that renders the chrome gradient, rounded mask, and neon border via `kiosk_tile.gdshader`. |
| `ChromePanel` | Frames content and owns `InnerMargin` / `ContentVBox`. |
| `GlowUnderlay` | Optional `ColorRect` sibling behind `ChromeBackground` for hover lift/glow (separate from shader so it can fade independently). |
| `ArtPanel` | Frames the artwork and hosts the reflection overlay. |
| `StickerBadge` | Self-contained rating sticker with rarity-colored frame. |

---

## New Script: `Scripts/UI/sticker_badge.gd`

```gdscript
extends Control
class_name StickerBadge

const PLACEHOLDER_STICKER = preload("res://icon.svg")

@export var rating: String = "G"
@export var rarity: String = "common"

var _frame: PanelContainer   # rarity-colored frame
var _icon: TextureRect       # rating icon (placeholder asset)
var _label: Label            # sticker text label

func set_rating(new_rating: String) -> void
func set_rarity(new_rarity: String) -> void
static func get_sticker_label(rating: String) -> String
static func get_rarity_frame_color(rarity: String) -> Color
```

### Rating → Sticker Label Mapping

| Rating | Sticker Label |
|--------|---------------|
| G | Mom-Approved |
| PG | Questionable Taste |
| PG-13 | Parental Guidance |
| R | Grounded Material |
| NC-17 | Banned From The Mall |

### Rarity → Frame Color Mapping

| Rarity | Color |
|--------|-------|
| common | Gray |
| uncommon | Green |
| rare | Blue |
| epic | Purple |
| legendary | Orange |

### Asset Note
No dedicated sticker textures exist yet. The badge will reuse `res://icon.svg` as a placeholder icon texture. The rarity-colored frame and text label provide the primary visual distinction. When real sticker art is added later, only `PLACEHOLDER_STICKER` and the icon size in `_ensure_structure()` need to change.

---

## New Shader: `Scripts/Shaders/kiosk_tile.gdshader`

```glsl
shader_type canvas_item;

uniform float border_glow : hint_range(0.0, 2.0) = 0.0;
uniform vec4 neon_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform vec4 chrome_tint : source_color = vec4(0.12, 0.10, 0.14, 0.98);
uniform float reflection_amount : hint_range(0.0, 1.0) = 0.15;
uniform float corner_radius : hint_range(0.0, 64.0) = 18.0;
uniform float time : hint_range(0.0, 100000.0) = 0.0;

void fragment() {
    vec2 uv = UV;
    vec2 size = vec2(1.0) / TEXTURE_PIXEL_SIZE;

    // Rounded rectangle mask
    vec2 d = abs(uv - 0.5) - (0.5 - corner_radius / min(size.x, size.y));
    float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    float mask = smoothstep(0.0, 1.0, dist);

    // Chrome vertical gradient across the ENTIRE tile background
    float grad = mix(0.08, 0.18, uv.y);
    vec3 chrome = mix(chrome_tint.rgb, vec3(grad), 0.4);

    // Neon edge glow
    float edge = 1.0 - smoothstep(0.0, 0.12, max(d.x, d.y) + 0.5);
    vec3 glow = neon_color.rgb * border_glow * edge;

    // Subtle sheen overlay (subtle scanlines + moving highlight)
    float scan = sin((uv.y + time * 0.05) * 60.0) * 0.5 + 0.5;
    float reflection = reflection_amount * scan * (1.0 - edge);

    COLOR = vec4(chrome + glow + reflection, 1.0 - mask);
}
```

The shader is applied to `ChromePanel` and covers the entire tile background. The `border_glow` uniform is tweened on hover/selection. The reflection is a subtle sheen overlay, not a flipped artwork reflection.

---

## Refactor: `Scripts/UI/power_up_icon.gd`

### Changes
1. Add `const KioskTileScene = preload("res://Scenes/PowerUp/kiosk_tile.tscn")`.
2. Add `@export var use_kiosk_tile: bool = true`.
3. In `_ready()`:
   - If `use_kiosk_tile` and no `KioskTile` child exists, instantiate one.
   - Reparent existing child nodes (`CardArt`, `Title`, etc.) into a legacy group **or** hide them and let KioskTile take over.
   - Bind KioskTile signals to existing `power_up_selected`, `power_up_deselected`, `power_up_sell_requested`.
4. In `_apply_data_to_ui()`:
   - Forward data to KioskTile if present; otherwise run legacy path.
5. Keep `set_data`, `select`, `deselect`, `get_is_selected`, `check_outside_click`, and shader tilt methods as public API.
6. Hover/click animations on the wrapper delegate to KioskTile; wrapper no longer directly manipulates `CardArt`/`shadow`.

### Public API Preserved
```gdscript
signal power_up_selected(power_up_id: String)
signal power_up_deselected(power_up_id: String)
signal power_up_sell_requested(power_up_id: String)

@export var data: PowerUpData
func set_data(new_data: PowerUpData) -> void
func get_is_selected() -> bool
func select() -> void
func deselect() -> void
func check_outside_click(event_position: Vector2) -> bool
func update_hover_description() -> void
```

---

## Refactor: `Scenes/PowerUp/power_up_icon.tscn`

- Remove the `material` from the root `Control` (KioskTile manages its own shader).
- Keep all legacy children (`Shadow`, `CardArt`, `SellButton`, `CardFrame`, `RarityIcon`, `CardInfo`, `LabelBg`) so `use_kiosk_tile = false` still works.
- Optionally set legacy children `visible = false` by default so the KioskTile path is clean.

---

## Refactor: `Scripts/UI/power_up_ui.gd`

### Changes
1. Read fan-out card dimensions from the instantiated icon instead of hard-coding 120×180.
   ```gdscript
   var card_size: Vector2 = icon.custom_minimum_size
   ```
2. Change `max_per_row` from 5 to **4** to accommodate 160×240 kiosk tiles without overlap. Make it a const at the top.
3. Keep all fan-out, fold-back, idle animation, and sell logic intact.
4. Ensure `KioskTile`’s `SellButton` z-index sits above the fan-out background.

---

## Animation Flow

### 1. KioskTile Hover
```
On mouse enter:
  - Tween position.y -= 8
  - Tween scale to 1.02
  - Tween ChromePanel shader border_glow 0.0 → 0.6
  - Fade in GlowUnderlay
  - Tween StickerBadge scale 1.0 → 1.1 → 1.0 (pulse)
  - Show ReflectionOverlay
```

### 2. KioskTile Unhover
```
On mouse exit:
  - Reverse hover tween
  - Hide GlowUnderlay / ReflectionOverlay
  - Reset shader border_glow
```

### 3. Sell Button Press
```
On SellButton.pressed:
  - TweenFX.button_press(SellButton)
  - emit_signal("power_up_sell_requested", data.id)
```

### 4. Fan-Out Transition
```
PowerUpUI._fan_out_cards():
  - Keep existing staggered slide/scale/fade per icon
  - KioskTile shader border_glow remains low (0.15) so edges stay visible
  - No additional rotation (tile perspective comes from shader)
```

### 5. Selection
```
On select:
  - Set _is_selected = true
  - Tween border_glow to 1.2
  - Tint neon_color toward rarity color
```

### 6. TweenFX Integration
- `TweenFXHelper.button_hover`, `button_unhover`, `button_press` on `SellButton`.
- `TweenFXHelper.spine_hover` is **not** used here (that is for the compact spine view).
- Custom `create_tween()` calls in `KioskTile` for tile lift/glow.

---

## File Checklist

| Action | Path |
|--------|------|
| Create | `Scenes/PowerUp/kiosk_tile.tscn` |
| Create | `Scripts/UI/kiosk_tile.gd` |
| Create | `Scripts/UI/sticker_badge.gd` |
| Create | `Scripts/Shaders/kiosk_tile.gdshader` |
| Modify | `Scripts/UI/power_up_icon.gd` |
| Modify | `Scenes/PowerUp/power_up_icon.tscn` |
| Modify | `Scripts/UI/power_up_ui.gd` |
| Update | `README.md` (feature documentation) |
| Create | `Tests/KioskTileTest.tscn` + `Tests/kiosk_tile_test.gd` |

---

## Test Plan

1. **KioskTileTest** — Standalone scene with 5–7 sample `PowerUpData` resources.
   - Verify hover lift/glow.
   - Verify sell button emits the correct signal.
   - Verify sticker label/frame matches rating/rarity.
2. **PowerUpUIFanTest** — Run the existing fan-out via `Tests/DebuffTest.tscn` or a dedicated test scene.
   - Verify tiles fan out without overlap.
   - Verify selection/deselection propagates.
   - Verify fold-back restores compact spines.
3. **Regression Test** — Set `use_kiosk_tile = false` in `PowerUpIcon` and confirm the legacy card still renders.

---

## Resolved Decisions

| # | Topic | Decision |
|---|-------|----------|
| 1 | Sticker assets | Use `res://icon.svg` as placeholder icon; rarity frame + text label carry the visual identity. |
| 2 | Tile dimensions | **160×240**. |
| 3 | Fan-out row count | **4 per row** instead of 5. |
| 4 | Shader scope | Chrome/neon shader covers the **entire tile background**. |
| 5 | Reflection effect | **Subtle sheen overlay** only. |

## Open Questions

None remaining. The plan is ready for implementation.
