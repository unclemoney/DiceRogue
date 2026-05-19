# BUILD_TWEENFX — TweenFX Integration Guide

## Overview

DiceRogue uses the **TweenFX** addon (v1.1) for standardized animation effects across all UI elements. Instead of scattered `create_tween()` calls, all game animations route through a central **TweenFXHelper** autoload wrapper, making it trivial to swap visuals globally without touching individual scripts.

### Architecture

```
TweenFX addon (67 animations)
  └── TweenFXHelper autoload (game-specific wrappers)
	   └── Individual scripts call TweenFXHelper methods
```

- **TweenFX** (`addons/TweenFX/TweenFX.gd`) — Low-level addon autoload. 47 one-shot + 20 looping animations. Manages lifecycle via `TweenManager`.
- **TweenFXHelper** (`Scripts/Core/tween_fx_helper.gd`) — Game-level autoload. Wraps TweenFX into named patterns (button_hover, spine_hover, idle_pulse, etc.). All game scripts call this instead of TweenFX directly.

### Why the Helper Layer?

1. **Single point of change** — Tweak `button_hover` once and every button updates.
2. **Safety** — `_valid()` guard prevents errors on freed/orphaned nodes.
3. **Discoverability** — Methods are grouped by domain (buttons, panels, icons, spines, idle, value, threat, reveal).
4. **Group toggles** — Every effect checks its group before firing, letting players disable categories of FX via Settings > FX.

---

## FX Group System

All TweenFXHelper methods belong to exactly one **FX Group**. Each group can be toggled on/off at runtime via the Settings menu's **FX** tab. Disabled groups cause their methods to early-return (no-op), so callers don't need `if` checks.

### Groups

| Enum Value | Display Name | Methods | Description |
|-----------|-------------|---------|-------------|
| `Group.BUTTONS` | Buttons | `button_hover`, `button_unhover`, `button_press`, `button_denied` | Hover jelly and press punch on buttons |
| `Group.SPINES` | Spines | `spine_hover`, `spine_unhover` | Scale snap on corkboard spine hover |
| `Group.IDLE` | Idle Animations | `idle_pulse`, `idle_float`, `idle_sway`, `idle_wiggle` | Looping sway, wiggle, pulse, and float |
| `Group.PANELS` | Panels | `panel_show`, `panel_hide`, `staggered_pop_in` | Pop-in / pop-out on panels and overlays |
| `Group.ICONS` | Icons | `icon_appear`, `icon_hover`, `icon_remove` | Pop-in, jelly hover, vanish on card icons |
| `Group.EVENTS` | Events | `value_change`, `negative_hit`, `positive_reward`, `celebration` | Celebration, reward glow, negative hit flash |
| `Group.THREATS` | Threats | `threat_alarm`, `threat_flicker` | Alarm pulse and flicker on debuffs |
| `Group.REVEALS` | Reveals | `spotlight_enter`, `spotlight_exit` | Spotlight glow enter / exit |
| `Group.DIALOGUE` | Dialogue | `dialogue_typewriter` | Typewriter text reveal for dialogs |
| `Group.SHADERS` | Shaders | `shader_pulse` | Shader parameter tween animations |
| `Group.COUNTERS` | Counters | `score_count_up` | Animated number count-up effects |

### API

```gdscript
# Check if a group is active
TweenFXHelper.is_group_enabled(TweenFXHelper.Group.BUTTONS)  # -> bool

# Toggle a group  (also emits group_toggled signal)
TweenFXHelper.set_group_enabled(TweenFXHelper.Group.IDLE, false)

# Bulk get/set for persistence
var states: Dictionary = TweenFXHelper.get_all_group_states()
TweenFXHelper.set_all_group_states(states)
```

### Persistence

- Group states are stored in `user://settings.cfg` under the `[fx]` section with keys `group_0`, `group_1`, etc.
- **GameSettings** loads them on startup (`load_settings`) and pushes to TweenFXHelper via `_apply_fx_settings()`.
- The Settings UI calls `GameSettings.set_fx_group(group_id, enabled)` which updates TweenFXHelper, saves to disk, and emits `fx_settings_changed`.

### Panel Fallback Behavior

When the Panels group is disabled, `panel_show()` and `panel_hide()` still set the visibility and modulate of the panel/overlay — they just skip the animation. This prevents panels from becoming invisible or stuck.

---

## TweenFXHelper API Reference

### Button Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `button_hover(node)` | Subtle rubber band on mouse enter | `TweenFX.rubber_band(node, 0.4, 0.15)` |
| `button_unhover(node)` | Stop jelly + reset scale | `TweenFX.stop` + `scale = Vector2.ONE` |
| `button_press(node)` | Quick inward punch on click | `TweenFX.punch_in(node, 0.12, 0.2)` |
| `button_denied(node)` | Horizontal shake (insufficient funds) | `TweenFX.shake(node, 0.3, 8.0, 4)` |

### Panel Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `panel_show(panel, overlay)` | Pop panel in + fade overlay | `TweenFX.pop_in` + `fade_in` |
| `panel_hide(panel, overlay)` | Pop panel out + fade overlay | `TweenFX.pop_out` + `fade_out` |

### Icon / Card Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `icon_appear(node)` | Pop-in when acquired | `TweenFX.pop_in(node, 0.3, 0.1)` |
| `icon_hover(node)` | Larger jelly for card hover | `TweenFX.jelly(node, 0.5, 0.2, 2)` |
| `icon_remove(node)` | Vanish on sell/consume/expire | `TweenFX.vanish(node, 0.3)` |

### Spine Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `spine_hover(node)` | Snap-in scale (stays until unhover) | `TweenFX.snap(ENTER)` |
| `spine_unhover(node)` | Snap-out restoring original scale | `TweenFX.snap(EXIT)` |

### Idle / Looping Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `idle_pulse(node, strength)` | Breathing attention draw | `TweenFX.breathe(node, 2.0, strength)` |
| `idle_float(node, height)` | Vertical bob for titles | `TweenFX.float_bob(node, 2.0, height)` |
| `idle_sway(node, angle)` | Rotation sway for spines | `TweenFX.sway(node, 2.5, angle)` |
| `idle_wiggle(node)` | Subtle wiggle for challenges | `TweenFX.wiggle(node, 1.2)` |

### Value Change Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `value_change(node)` | Punch on number change | `TweenFX.punch_in(node, 0.15, 0.2)` |
| `negative_hit(node)` | Red flash + scale punch | `TweenFX.critical_hit` |
| `positive_reward(node)` | Gold glow + swell | `TweenFX.upgrade` |
| `celebration(node)` | Tada for big wins | `TweenFX.tada(node, 0.6)` |

### Threat Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `threat_alarm(node)` | Looping red alarm pulse | `TweenFX.alarm` |
| `threat_flicker(node)` | Unsettling looping flicker | `TweenFX.flicker` |

### Reveal Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `spotlight_enter(node, glow)` | Brighten + glow (stays lit) | `TweenFX.spotlight(ENTER)` |
| `spotlight_exit(node, glow)` | Return to normal modulate | `TweenFX.spotlight(EXIT)` |

### Dialogue Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `dialogue_typewriter(label, text, speed)` | Typewriter text reveal for dialogs | `TweenFX.typewriter` |

### Counter Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `score_count_up(label, from, to, duration)` | Animated number counter | `TweenFX.count_up` |

### Shader Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `shader_pulse(node, param, from, to, duration)` | Animate shader parameter by name | `TweenFX.tween_shader_param` |

### Tooltip Effects
| Method | Description | TweenFX Call |
|--------|-------------|-------------|
| `tooltip_fade_in(node)` | Fade in a tooltip background | `TweenFX.fade_in` |
| `tooltip_fade_out(node)` | Fade out a tooltip background | `TweenFX.fade_out` |

### Utility
| Method | Description |
|--------|-------------|
| `stop_effect(node)` | Stop ALL TweenFX on a node |
| `stop_specific(node, anim)` | Stop one named animation |
| `staggered_pop_in(nodes, delay)` | Cascade pop-in for lists |

---

## Standard Patterns

### Adding TweenFX to a Button

```gdscript
# In _ready() or wherever the button is created:
var btn = Button.new()
btn.text = "CLICK ME"
btn.pressed.connect(_on_button_pressed)

# TweenFX hover/press feedback
btn.mouse_entered.connect(TweenFXHelper.button_hover.bind(btn))
btn.mouse_exited.connect(TweenFXHelper.button_unhover.bind(btn))
btn.pressed.connect(TweenFXHelper.button_press.bind(btn))
```

For scene-placed buttons (no `pressed.connect` in code), add all 3 signals after the button is accessible:
```gdscript
@onready var close_button: Button = $CloseButton

func _ready() -> void:
	close_button.mouse_entered.connect(TweenFXHelper.button_hover.bind(close_button))
	close_button.mouse_exited.connect(TweenFXHelper.button_unhover.bind(close_button))
	close_button.pressed.connect(TweenFXHelper.button_press.bind(close_button))
```

### Adding Idle Animation to a Spine

```gdscript
func _ready() -> void:
	# ... existing setup ...
	
	# Idle personality animation
	TweenFXHelper.idle_sway(self, 2.0)

func _exit_tree() -> void:
	TweenFXHelper.stop_effect(self)
```

### Replacing a Manual Tween Loop

Before:
```gdscript
var title_tween: Tween
var title_base_position: Vector2

func _animate_title_float() -> void:
	if title_tween and title_tween.is_valid():
		title_tween.kill()
	title_tween = create_tween()
	title_tween.set_loops()
	title_tween.set_trans(Tween.TRANS_SINE)
	title_tween.set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property(node, "position:y", base_y - 8.0, 2.5)
	title_tween.tween_property(node, "position:y", base_y + 8.0, 2.5)

func _exit_tree() -> void:
	if title_tween and title_tween.is_valid():
		title_tween.kill()
```

After:
```gdscript
func _start_title_animation() -> void:
	TweenFXHelper.idle_float(shop_label, 8.0)

func _exit_tree() -> void:
	TweenFXHelper.stop_effect(shop_label)
```

---

## Files Modified

### Phase 0 — Setup
| File | Change |
|------|--------|
| `addons/TweenFX/` | Plugin enabled in editor_plugins.cfg |
| `Scripts/Core/safe_tween_mixin.gd` | **Deleted** — unused, replaced by TweenFXHelper |
| `Scripts/Core/tween_debugger.gd` | **Deleted** — unused debug tool |
| `project.godot` | Added `TweenFXHelper` autoload after `TweenFX` |

### Phase 1 — TweenFXHelper Autoload
| File | Change |
|------|--------|
| `Scripts/Core/tween_fx_helper.gd` | **Created** — central animation wrapper (28 methods) |

### Phase 2 — Menu Buttons
| File | Change |
|------|--------|
| `Scripts/UI/main_menu.gd` | Title float → `idle_float`, profile/nav buttons → hover/press, removed `_animate_title_float()` |
| `Scripts/UI/pause_menu.gd` | Resume/Settings/Main Menu buttons → hover/press |
| `Scripts/UI/settings_menu.gd` | Close, apply_video, keyboard reset, controller reset buttons → hover/press |

### Phase 3 — Game Buttons
| File | Change |
|------|--------|
| `Scripts/UI/game_button_ui.gd` | Roll/shop pulse → `idle_pulse`/`stop_effect`, all 4 buttons → hover/press, removed 80+ lines of manual tween code |

### Phase 4 — Card Icons & Spines
| File | Change |
|------|--------|
| `Scripts/UI/card_icon_base.gd` | Base hover → `icon_hover`/`stop_effect` |
| `Scripts/UI/power_up_spine.gd` | Hover scale → `spine_hover`/`spine_unhover`, idle sway added |
| `Scripts/UI/consumable_spine.gd` | Hover scale → `spine_hover`/`spine_unhover`, idle sway added |
| `Scripts/Debuff/debuff_spine.gd` | Hover scale → `spine_hover`/`spine_unhover`, idle sway added, `negative_hit` on count increase |
| `Scripts/Challenge/challenge_spine.gd` | Hover scale → `spine_hover`/`spine_unhover`, idle wiggle added, `celebration` on goal met |

### Phase 5 — Panel Buttons
| File | Change |
|------|--------|
| `Scripts/UI/chore_selection_popup.gd` | SELECT button → hover/press |
| `Scripts/UI/end_of_round_stats_panel.gd` | Continue button → hover/press |
| `Scripts/UI/round_winner_panel.gd` | Next Channel button → hover/press |
| `Scripts/Managers/channel_manager_ui.gd` | Up/Down/Start buttons → hover/press |

### Phase 6 — Dice
| File | Change |
|------|--------|
| `Scripts/Core/dice.gd` | Lock → `spine_hover` jelly, Unlock → `spine_unhover` snap-back |

### Phase 7 — Easy Win Replacements
| File | Change |
|------|--------|
| `Scripts/UI/shop_ui.gd` | Title float → `idle_float`, removed `_animate_title_float()` + `title_tween` var, close/reroll buttons → hover/press |
| `Scripts/UI/tutorial_highlight.gd` | Pulse → `idle_pulse`, bounce → `idle_float`, removed `pulse_tween`/`bounce_tween` vars |

### Phase 8 — Creative Combinations
| File | Change |
|------|--------|
| `Scripts/UI/power_up_spine.gd` | Added `idle_sway(self, 2.0)` for idle personality |
| `Scripts/UI/consumable_spine.gd` | Added `idle_sway(self, 3.0)` for idle personality |
| `Scripts/Debuff/debuff_spine.gd` | Added `idle_sway(self, 2.0)` + `negative_hit(self)` on debuff count increase |
| `Scripts/Challenge/challenge_spine.gd` | Added `idle_wiggle(self)` + `celebration(self)` on challenge goal met |

### Phase 9 — FX Group Toggle System
| File | Change |
|------|--------|
| `Scripts/Core/tween_fx_helper.gd` | Added `Group` enum, `_enabled_groups` dict, `is_group_enabled`/`set_group_enabled`/`get_all_group_states`/`set_all_group_states`, group guard checks in every method, `GROUP_NAMES`/`GROUP_DESCRIPTIONS` constants, `group_toggled` signal |
| `Scripts/Managers/game_settings.gd` | Added `fx_group_enabled` dict, `fx_settings_changed` signal, `[fx]` section in load/save, `_apply_fx_settings()`, `set_fx_group()` public API |
| `Scripts/UI/settings_menu.gd` | Added `_build_fx_tab()` with scrollable CheckButton toggles per group, `_on_fx_group_toggled()` handler, FX tab added to TabContainer |

### Phase 10 — Missing Button FX
| File | Change |
|------|--------|
| `Scripts/UI/tutorial_dialog.gd` | skip_button + next_button → hover/unhover |
| `Scripts/UI/unlocked_item_panel.gd` | ok_button → hover/unhover |
| `Scripts/UI/mom_character.gd` | close_button → hover/unhover |
| `Scripts/Shop/shop_item.gd` | buy_button → hover/unhover |
| `Scripts/UI/main_menu.gd` | delete_btn → hover/unhover |
| `Scripts/UI/settings_menu.gd` | bind_btn (keybinding rows) → hover/unhover |
| `Scripts/UI/shop_ui.gd` | tab_reroll_button → hover/unhover |
| `Scripts/UI/power_up_icon.gd` | sell_button → hover/unhover |
| `Scripts/UI/card_icon_base.gd` | sell_button → hover/unhover |

---

## What Was NOT Changed (and Why)

### Panel Show/Hide Animations
Panel transitions in `end_of_round_stats_panel.gd`, `round_winner_panel.gd`, etc. use `await tween.finished` to chain subsequent game logic. TweenFXHelper's `panel_show`/`panel_hide` return tweens, but integrating them requires restructuring the await chains. Left for a future pass.

### Card Icon Subclass Hover
`PowerUpIcon`, `ConsumableIcon`, `DebuffIcon`, `ChallengeIcon` each have unique multi-step hover animations (shader tilt, glow ramp, label popup). These are complex sequences that don't map cleanly to a single TweenFX call. Only the base class (`card_icon_base.gd`) fallback methods were updated.

### Dice Hover Shader
`dice.gd` hover uses `tween_method` to drive a shader parameter — Now possible via `TweenFXHelper.shader_pulse()`, but the existing manual tweens have fine-grained parallel execution that TweenFX's generic wrapper can't replicate 1:1. Lock/unlock jelly was added as new juice instead.

### ScoringAnimationController Dice/Spine Bounces
`scoring_animation_controller.gd` uses `tween_method` for dice bounces (local-space positioning to avoid camera shake interference) and consumable/powerup spine bounces (sine-wave precision with per-frame validation). These are too tightly coupled to game logic and audio sync for safe replacement.

### ChallengeUI / DebuffUI Removal Animations
`challenge_ui.gd` and `debuff_ui.gd` use multi-step choreographed sequences (squish → stretch → move up + fade out). These complex sequences don't map cleanly to a single TweenFX preset.

### Score Card Tweens
`score_card_ui.gd` has 13+ tweens tightly coupled to the scoring animation pipeline. Modifying these risks breaking score display timing. Left untouched.

### Corkboard UI Tweens
`corkboard_ui.gd` has 12+ tweens with completion callbacks that trigger game state changes. Too many interdependencies for safe swaps.

---

## Adding New TweenFX Effects

1. **Add method to TweenFXHelper** — Pick the right TweenFX call, wrap it with a descriptive name and the `_valid()` guard. If the animation tweens `scale` or `rotation`, add `_center_pivot(node)` before the TweenFX call.
2. **Connect in the target script** — For one-shot: call directly. For signals: use `.bind(node)`. No need to set `pivot_offset` — the helper handles it automatically.
3. **Clean up in `_exit_tree()`** — Call `TweenFXHelper.stop_effect(self)` for any looping effects.
4. **Test visually** — Run the relevant test scene to verify the effect feels right.

### Property Conflict Rules
- **Scale effects** (`idle_pulse`, `spine_hover`) — Don't stack two scale-based effects on the same node.
- **Rotation effects** (`idle_sway`, `idle_wiggle`) — Safe to combine with scale-based hover since they use different properties.
- **Position effects** (`idle_float`) — Don't combine with manual position tweens on the same node.
- **Modulate effects** (`negative_hit`, `threat_alarm`) — Target `self` when child nodes set their own `modulate` directly.

---

## Phase 11 — Auto-Center Pivot

### Problem

TweenFX tweens `node.scale` and `node.rotation` but never touches `pivot_offset`. In Godot 4, `Control` nodes scale/rotate around their `pivot_offset`, which defaults to `Vector2(0, 0)` (top-left corner). This caused scale-based animations like `rubber_band` and `breathe` to appear anchored to the top-left instead of centered.

Some scripts (`game_button_ui.gd`, `tween_fx_test.gd`) had manually set `pivot_offset = size / 2.0` before calling TweenFXHelper, but 12+ other scripts did not — causing inconsistent animation behavior.

### Solution

Added a private `_center_pivot(node)` helper in `tween_fx_helper.gd` that auto-centers `pivot_offset` on any `Control` node before the TweenFX call. This is a no-op for non-Control nodes (e.g. `Node2D`).

```gdscript
func _center_pivot(node: CanvasItem) -> void:
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2.0
```

### Methods with `_center_pivot`

Inserted `_center_pivot(node)` before the TweenFX call in all 17 methods that tween `scale` or `rotation`:

| Method | Reason |
|--------|--------|
| `button_hover` | `rubber_band` → scale |
| `button_press` | `punch_in` → scale |
| `panel_show` | `pop_in` → scale (panel param) |
| `panel_hide` | `pop_out` → scale (panel param) |
| `icon_appear` | `pop_in` → scale |
| `icon_hover` | `jelly` → scale |
| `icon_remove` | `vanish` → scale |
| `spine_hover` | `snap` → scale |
| `spine_unhover` | `snap` → scale |
| `idle_pulse` | `breathe` → scale |
| `idle_sway` | `sway` → rotation |
| `idle_wiggle` | `wiggle` → rotation |
| `value_change` | `punch_in` → scale |
| `negative_hit` | `critical_hit` → scale |
| `positive_reward` | `upgrade` → scale |
| `celebration` | `tada` → scale + rotation |
| `staggered_pop_in` | `pop_in` → scale (per-node) |

Methods that do **not** need pivot (position/modulate only): `button_unhover`, `button_denied`, `idle_float`, `threat_alarm`, `threat_flicker`, `spotlight_enter`, `spotlight_exit`, `stop_effect`, `stop_specific`.

### Redundant Pivot Calls Removed

Previously these scripts manually set `pivot_offset` before calling TweenFXHelper. Now handled centrally:

| File | Lines Removed |
|------|---------------|
| `Scripts/UI/game_button_ui.gd` | 3 lines: button loop pivot, roll_button pivot, shop_button pivot |
| `Scripts/UI/tutorial_highlight.gd` | 1 line: highlight_panel pivot |
| `Tests/tween_fx_test.gd` | 6 lines: title, pulse, sway, wiggle, spine, button pivots |

### Pivot Calls Kept (Non-TweenFXHelper)

These manual pivot calls serve direct `create_tween()` animations and were **not** removed:

| File | Purpose |
|------|--------|
| `unlocked_item_panel.gd` | Manual scale:x flip animation |
| `end_of_round_stats_panel.gd` | Manual scale tween for counter animation |
| `chore_ui.gd` | Manual scale tween for card fan-in |
| `chore_selection_popup.gd` | Manual scale tween for popup entrance |
| `channel_manager_ui.gd` | Manual scale tween for checkmark appear/disappear |

### Phase 11 — Disabled Button Guard

All four button methods (`button_hover`, `button_unhover`, `button_press`, `button_denied`) now check `BaseButton.disabled` before animating. If a button is disabled, the method early-returns without playing any effect.

```gdscript
if node is BaseButton and (node as BaseButton).disabled:
	return null
```

### Phase 11 — Per-Profile FX Persistence

FX group toggle states are now saved/loaded per player profile in `progress_manager.gd`:

- `save_current_profile()` writes `fx_settings` dict (string keys `"0"` through `"10"` → bool values)
- `load_profile()` reads `fx_settings` and pushes to both `GameSettings.fx_group_enabled` and `TweenFXHelper.set_group_enabled()`
- `_create_default_profile()` initializes all 11 groups to `true`

### Files Modified — Phase 11

| File | Change |
|------|--------|
| `Scripts/Core/tween_fx_helper.gd` | Added `_center_pivot()`, inserted in 17 methods, added disabled button guard to 4 button methods |
| `Scripts/UI/game_button_ui.gd` | Removed 3 redundant `pivot_offset` lines |
| `Scripts/UI/tutorial_highlight.gd` | Removed 1 redundant `pivot_offset` line |
| `Tests/tween_fx_test.gd` | Removed 6 redundant `pivot_offset` lines |
| `Scripts/Managers/progress_manager.gd` | Added `fx_settings` to save/load/default profile |

---

## Phase 12 — UI Animation Framework

### Overview

A full container-aware UI animation framework built on top of TweenFX. Provides preset-based animations, global juice profiles, and plug-and-play `ContainerAnimator` nodes for staggered entrance/exit sequences.

### New Files

| File | Role |
|------|------|
| `Scripts/Core/juice_profile.gd` | `JuiceProfile` Resource — tuneable timing, easing, overshoot, and distance parameters |
| `Scripts/UI/ui_animated.gd` | `UIAnimated` component node — attach to any Control to declare entrance/exit presets |
| `Scripts/UI/container_animator.gd` | `ContainerAnimator` node — auto-detects parent Container and staggers children |
| `Scripts/UI/Examples/ui_animation_examples.gd` | Copy-paste reference snippets for common patterns |

### Modified Files

| File | Change |
|------|--------|
| `addons/TweenFX/TweenFX.gd` | Added `FLY_IN`, `FLY_OUT`, `OVERSHOOT_POP_IN`, `SLIDE_AND_FADE_IN`, `SLIDE_AND_FADE_OUT` enums and methods |
| `Scripts/Core/tween_fx_helper.gd` | Added `Group.CONTAINERS`, `play_preset()`, `animate_container_children()`, `get_default_juice_profile()`, `_sort_center_out()`, `_sort_random()` |
| `Tests/tween_fx_test.gd` | Added test rows for UI presets, container stagger, and helper preset playback |

---

### JuiceProfile

Create a `JuiceProfile` Resource in the inspector (or load one at runtime) to control animation personality across an entire scene.

| Property | Default | Description |
|----------|---------|-------------|
| `default_duration` | 0.4 | Base duration for entrance/exit presets |
| `default_stagger` | 0.08 | Delay between each child in a stagger |
| `entrance_distance` | 100.0 | Travel distance for fly/slide presets (px) |
| `overshoot_strength` | 0.15 | Overshoot on pop/elastic animations |
| `bounce_strength` | 0.3 | Bounce settle on elastic animations |
| `default_easing` | EASE_OUT | Default easing mode |
| `default_transition` | TRANS_BACK | Default transition type |
| `pop_in_scale` | 0.8 | Starting scale for pop_in presets |
| `fade_in_duration` | 0.35 | Duration for pure fade presets |
| `pause_mode` | TWEEN_PAUSE_PROCESS | Ensures UI tweens run while game is paused |

#### Global Default

TweenFXHelper lazy-loads `res://Resources/Data/default_juice_profile.tres` on first access. If the file doesn't exist, an inline default is created automatically.

```gdscript
# Override globally
TweenFXHelper.default_juice_profile = preload("res://Resources/Data/snappy_profile.tres")

# Override per-call
var profile = JuiceProfile.new()
profile.overshoot_strength = 0.25
TweenFXHelper.play_preset(my_button, "overshoot_pop", profile)
```

---

### Preset String Reference

All presets are passed as strings to `TweenFXHelper.play_preset()` or `ContainerAnimator`.

#### Entrance Presets

| Preset | Animation | Properties Affected |
|--------|-----------|---------------------|
| `"pop_in"` | Scale from 0 → 1 with overshoot | scale, modulate:a |
| `"fade_in"` | Alpha 0 → 1 | modulate:a |
| `"fly_in_left"` | Fly in from left + fade | position, modulate:a |
| `"fly_in_right"` | Fly in from right + fade | position, modulate:a |
| `"fly_in_up"` | Fly in from above + fade | position, modulate:a |
| `"fly_in_down"` | Fly in from below + fade | position, modulate:a |
| `"overshoot_pop"` | Scale 0.7 → 1.0 + overshoot → 1.0 with elastic settle | scale, modulate:a |
| `"slide_and_fade"` | Smooth slide from left + fade (softer than fly_in) | position, modulate:a |

#### Exit Presets

| Preset | Animation | Properties Affected |
|--------|-----------|---------------------|
| `"pop_out"` | Scale to 0 with overshoot pull | scale, modulate:a |
| `"fade_out"` | Alpha 1 → 0 | modulate:a |
| `"fly_out_left"` | Fly out left + fade | position, modulate:a |
| `"fly_out_right"` | Fly out right + fade | position, modulate:a |
| `"fly_out_up"` | Fly out up + fade | position, modulate:a |
| `"fly_out_down"` | Fly out down + fade | position, modulate:a |
| `"slide_and_fade_out"` | Smooth slide out right + fade | position, modulate:a |

---

### ContainerAnimator

Drop `ContainerAnimator` as a child of any `Container` (`VBoxContainer`, `HBoxContainer`, `GridContainer`, etc.).

#### Inspector Settings

| Property | Description |
|----------|-------------|
| `trigger_mode` | `READY` (auto on `_ready()`), `MANUAL` (call from code), `SIGNAL` (reserved) |
| `entrance_preset` | Preset applied to all children on entrance |
| `exit_preset` | Preset applied to all children on exit |
| `stagger_pattern` | `CASCADE`, `REVERSE`, `CENTER_OUT`, `RANDOM` |
| `stagger_delay` | Delay between children. `-1` uses profile default. |
| `delay_before_start` | Global delay before first child animates |
| `juice_profile` | Optional per-scene profile override |
| `respect_child_overrides` | If true, children with `UIAnimated` use their own preset/delay |

#### Stagger Patterns

- **CASCADE** — Tree order (top-to-bottom for VBox, left-to-right for HBox/Grid)
- **REVERSE** — Inverted tree order
- **CENTER_OUT** — Middle child first, radiating outward. For GridContainer, sorts by Manhattan distance from grid center.
- **RANDOM** — Deterministic shuffle seeded by container name hash

#### Code Example

```gdscript
func show_menu() -> void:
	visible = true
	$ButtonList/ContainerAnimator.trigger_entrance()

func hide_menu() -> void:
	var tweens = $ButtonList/ContainerAnimator.trigger_exit()
	if not tweens.is_empty():
		await tweens[-1].finished
	visible = false
```

---

### UIAnimated Component

Add `UIAnimated` as a child of any Control to declare per-node animation behavior.

```gdscript
# In the scene tree:
#   HeaderLabel (Label)
#   └── UIAnimated (Node)
#         entrance_preset = "slide_and_fade"
#         delay = 0.1
```

When a parent `ContainerAnimator` has `respect_child_overrides = true`, it will use the `UIAnimated` child's preset and delay instead of the container defaults.

---

### TweenFXHelper.play_preset()

Direct API for playing a preset on any node without a ContainerAnimator.

```gdscript
# Fire-and-forget
TweenFXHelper.play_preset(my_panel, "fly_in_up")

# With await
await TweenFXHelper.play_preset(my_panel, "overshoot_pop").finished

# With custom profile and delay
var profile = JuiceProfile.new()
profile.default_duration = 0.6
TweenFXHelper.play_preset(my_panel, "pop_in", profile, 0.2)
```

---

### TweenFXHelper.animate_container_children()

Programmatic container sequencing without adding a node.

```gdscript
TweenFXHelper.animate_container_children(
	$StatsVBox,
	"fly_in_up",
	"cascade",
	profile,
	0.12
)
```

---

### Best Practices

#### Tuning Juice for Different Art Styles

| Art Style | Recommended Tweaks |
|-----------|-------------------|
| Pixel art / retro | Lower `default_duration` (0.25–0.35), reduce `overshoot_strength` (0.08–0.12), use `TRANS_QUAD` instead of `TRANS_BACK` |
| Clean vector / flat | Medium `default_duration` (0.35–0.45), subtle overshoot (0.1), `TRANS_CUBIC` |
| Juicy cartoony | Higher `default_duration` (0.45–0.6), generous overshoot (0.18–0.25), `TRANS_BACK` / `TRANS_ELASTIC`, longer `default_stagger` (0.1–0.14) |
| Minimalist | Very low `default_duration` (0.2–0.3), zero overshoot, `TRANS_SINE`, short stagger (0.04–0.06) |

#### Avoiding Over-Juicing

- **One effect per property** — Don't stack `fly_in` with `idle_float` on the same node; they both fight for `position`.
- **Stagger caps** — For large lists (>12 items), consider reducing `default_stagger` or switching to `CASCADE` with a very short delay so the total sequence doesn't feel sluggish.
- **Exit restraint** — Exit animations should typically be faster than entrances (0.6×–0.8× duration) so the UI feels responsive when closing.
- **Disable during gameplay** — Container animations are great for menus and popups, but avoid them on HUD elements that update every frame.

#### Keeping UI Responsive While Animating

- All new UI preset tweens use `TWEEN_PAUSE_PROCESS` so they continue during pause menus.
- `ContainerAnimator` does NOT block input — it only tweens visual properties. Connect your buttons before triggering entrance.
- If you need to block input until animation
 finishes, use `await tweens[-1].finished` after `trigger_entrance()`.

#### Scene Structure for Clean Animation Flow

```
PopupRoot (Control)
├── Overlay (ColorRect)          <-- fade manually, do NOT scale
├── Panel (PanelContainer)
│   └── ContentVBox (VBoxContainer)
│       ├── ContainerAnimator    <-- animates ContentVBox's children
│       ├── TitleLabel
│       ├── BodyText
│       └── CloseButton
└── UIAnimated (Node)            <-- optional, for Panel itself
```

- **Never** animate `scale` on `PanelContainer` directly — animate `position` and `modulate:a` on the panel, and let `ContainerAnimator` handle the children.
- Use `UIAnimated` on the panel root for single-node entrance/exit (e.g., slide in from left).
- Use `ContainerAnimator` inside the panel for staggered child sequences.
- Keep animation nodes separate from logic nodes — animation components are children, not replacements for your UI scripts.
