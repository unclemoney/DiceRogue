# BUILD_DEBUFF.md

## How to Create New Debuffs in DiceRogue

This guide provides step-by-step instructions for creating new debuffs in the DiceRogue game. Debuffs are negative effects that hinder the player's progress and add challenge to the gameplay.

### Overview

A complete debuff implementation requires three main components:
1. **Script** - The debuff logic and behavior
2. **Scene** - The Godot scene file containing the debuff node
3. **Resource** - The DebuffData resource that defines the debuff's metadata

### Step 1: Create the Debuff Script

Create a new script in `Scripts/Debuff/` that extends the base `Debuff` class:

```gdscript
extends Debuff
class_name YourDebuffName

## Your Debuff Description
##
## Detailed explanation of what this debuff does and how it affects gameplay

var additional_properties: type = default_value

## apply(_target)
##
## Called when the debuff is applied to the target.
## This is where you implement the debuff's negative effect.
func apply(_target) -> void:
	print("[YourDebuffName] Applied - Description of effect")
	
	# Store the target for cleanup
	self.target = _target
	
	# Implement your debuff logic here
	# Examples:
	# - Connect to signals
	# - Modify game state
	# - Intercept game mechanics
	# - Apply penalties

## remove()
##
## Called when the debuff is removed or expires.
## This must cleanly undo all effects applied in apply().
func remove() -> void:
	print("[YourDebuffName] Removed - Undoing effects")
	
	# Clean up all effects applied in apply()
	# Examples:
	# - Disconnect signals
	# - Restore original state
	# - Remove penalties
	# - Free resources
```

#### Key Guidelines for Debuff Scripts:

- **Always use `_target` parameter**: The base class has a `target` property, so use `_target` parameter to avoid shadowing
- **Store target reference**: Always set `self.target = _target` for proper cleanup
- **Implement both methods**: Both `apply()` and `remove()` must be implemented
- **Clean up properly**: `remove()` must undo everything that `apply()` did
- **Use appropriate class_name**: Follow PascalCase naming convention
- **Add comprehensive documentation**: Use GDScript doc comments for methods

#### Common Debuff Patterns:

1. **Signal-based debuffs**: Connect to game signals and apply penalties
2. **State modification debuffs**: Directly modify game state or properties
3. **Interception debuffs**: Replace or modify existing game methods
4. **Continuous effect debuffs**: Apply ongoing penalties during gameplay

### Step 2: Create the Debuff Scene

Create a new scene file in `Scenes/Debuff/` with the following structure:

1. Create new scene in Godot Editor
2. Add a Node as the root (name it after your debuff)
3. Attach your debuff script to the root node
4. Save the scene as `YourDebuffName.tscn`

**Alternative: Manual .tscn file creation** (for consistency with existing files):

```gdscene
[gd_scene load_steps=2 format=3 uid="uid://your_unique_id"]

[ext_resource type="Script" uid="uid://script_uid" path="res://Scripts/Debuff/your_debuff_script.gd" id="1_bequk"]

[node name="YourDebuffName" type="Node"]
script = ExtResource("1_bequk")
```

### Step 3: Create the DebuffData Resource

Create a new resource file in `Scripts/Debuff/` that defines the debuff's metadata and procedural glyph configuration:

```gdresource
[gd_resource type="Resource" script_class="DebuffData" load_steps=3 format=3 uid="uid://your_unique_id"]

[ext_resource type="Script" uid="uid://uiuqwtxbh7m0" path="res://Scripts/Debuff/DebuffData.gd" id="1_oh0j2"]
[ext_resource type="PackedScene" uid="uid://scene_uid" path="res://Scenes/Debuff/YourDebuffName.tscn" id="2_ta17l"]

[resource]
script = ExtResource("1_oh0j2")
id = "your_debuff_id"
display_name = "Your Debuff Display Name"
description = "Brief description shown in UI"
scene = ExtResource("2_ta17l")
glyph_id = 0
glow_color = Color(0, 0, 0, 0)
glyph_scale = 1.0
line_thickness = 0.1
rim_thickness = 0.03
bloom_softness = 0.18
wobble_strength = 0.4
roughness_strength = 0.35
glow_strength = 1.4
difficulty_rating = 1
is_grounding = false
metadata/_custom_type_script = "uid://uiuqwtxbh7m0"
```

#### DebuffData Properties:

- **id**: Unique string identifier (snake_case)
- **display_name**: Human-readable name shown in UI
- **description**: Brief explanation of the debuff's effect
- **scene**: PackedScene reference to your debuff scene
- **glyph_id**: Integer `0-15` selecting the procedural SDF glyph rendered by `debuff_glyph_glow.gdshader`
- **glow_color**: Optional glyph tint. Transparent (`Color(0,0,0,0)`) falls back to the difficulty tint
- **glyph_scale**: Overall glyph size multiplier
- **line_thickness**: Thickness of glyph line work
- **rim_thickness**: Thickness of outer rim outlines
- **bloom_softness**: Glow bloom softness
- **wobble_strength**: Subtle positional wobble amount
- **roughness_strength**: Subtle edge roughness amount
- **glow_strength**: Base brightness of the glyph glow
- **difficulty_rating**: `1-5` used for automatic selection and UI color tinting
- **is_grounding**: `false` for normal debuffs. Set `true` to move the entry into the **grounding pool** — groundings are drawn by per-round `grounding_chance` instead of the regular debuff schedule, and are excluded from normal and boss debuff draws (see "Groundings" below)

#### Glyph ID Reference

The debuff shader exposes 16 procedural glyphs:

| ID | Glyph Name       | Typical Meaning                  |
|----|------------------|----------------------------------|
| 0  | Coupon Block     | Blocked / not allowed            |
| 1  | Paid Rerolls     | Money cost on rolling            |
| 2  | Color Drain      | Disabled colors                  |
| 3  | Mod Lockout      | Disabled mods                    |
| 4  | No Twos          | Disabled twos                    |
| 5  | Chore Surge      | Faster chores / rising pressure  |
| 6  | Half Value       | Halved values                    |
| 7  | Sold Out         | Emptied / liquidation            |
| 8  | No Locks         | Locking disabled                 |
| 9  | D4 Swap          | Dice swapped to d4s              |
| 10 | Power Cut        | Power-up disabled                |
| 11 | One Roll Only    | Single roll restriction          |
| 12 | Level Loss       | Reduced levels                   |
| 13 | Roll Tax         | Roll-count penalty               |
| 14 | Divide All       | Multipliers become dividers      |
| 15 | Wealth Drain     | Money-based penalty              |

### Step 4: Register the Debuff

Add your debuff resource to the DebuffManager in the main game scene:

1. Open the main game scene in Godot Editor
2. Find the DebuffManager node
3. In the Inspector, add your DebuffData resource to the `debuff_defs` array
4. Save the scene

### Step 5: Integration with GameController

Add support for your debuff in `GameController.gd`:

```gdscript
# In the apply_debuff() method, add your case:
match id:
	"your_debuff_id":
		debuff.target = appropriate_target  # self, dice_hand, scorecard, etc.
		debuff.start()
	# ... existing cases
```

### Step 6: Testing and Debug Integration

Add debug support by updating `debug_panel.gd`:

```gdscript
# In _create_debug_buttons(), add a new button:
{"text": "Apply Your Debuff", "method": "_debug_apply_your_debuff"},

# Add the debug method:
func _debug_apply_your_debuff() -> void:
	if not game_controller:
		log_debug("ERROR: GameController not available")
		return
	
	game_controller.apply_debuff("your_debuff_id")
	log_debug("Applied your debuff for testing")
```

## Complete Example: TheDivisionDebuff

Here's a complete example of the newly created TheDivisionDebuff:

### Script (`Scripts/Debuff/the_division_debuff.gd`):
```gdscript
extends Debuff
class_name TheDivisionDebuff

## TheDivisionDebuff
##
## Converts all multiplier power-ups to work as dividers instead.
## When active, any power-up that would normally multiply scores will instead divide them.
## Example: A 2.0 multiplier becomes 1/2.0 = 0.5 (dividing score by 2)

var score_modifier_manager: Node
var original_get_total_multiplier_method: Callable
var is_intercepting: bool = false

func apply(_target) -> void:
	print("[TheDivisionDebuff] Applied - Converting multipliers to dividers")
	self.target = _target
	
	# Find and intercept ScoreModifierManager
	score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if score_modifier_manager:
		original_get_total_multiplier_method = score_modifier_manager.get_total_multiplier
		score_modifier_manager.get_total_multiplier = _get_total_divider_instead
		is_intercepting = true

func remove() -> void:
	print("[TheDivisionDebuff] Removed - Restoring normal multiplier behavior")
	if score_modifier_manager and is_intercepting:
		score_modifier_manager.get_total_multiplier = original_get_total_multiplier_method
		is_intercepting = false

func _get_total_divider_instead() -> float:
	# Custom logic to convert multipliers to dividers
	# Implementation details...
```

### Resource (`Scripts/Debuff/TheDivisionDebuff.tres`):
```gdresource
[gd_resource type="Resource" script_class="DebuffData" load_steps=3 format=3]

[ext_resource type="Script" uid="uid://uiuqwtxbh7m0" path="res://Scripts/Debuff/DebuffData.gd" id="1_oh0j2"]
[ext_resource type="PackedScene" uid="uid://scene_uid" path="res://Scenes/Debuff/TheDivisionDebuff.tscn" id="2_ta17l"]

[resource]
script = ExtResource("1_oh0j2")
id = "the_division"
display_name = "The Division"
description = "All multiplicative score factors now invert between multiply and divide"
scene = ExtResource("2_ta17l")
glyph_id = 14
glow_color = Color(0, 0, 0, 0)
glyph_scale = 1.0
line_thickness = 0.1
rim_thickness = 0.03
bloom_softness = 0.18
wobble_strength = 0.4
roughness_strength = 0.35
glow_strength = 1.4
difficulty_rating = 4
metadata/_custom_type_script = "uid://uiuqwtxbh7m0"
```

## Debuff Selection: Per-Zone Pool and Boss Rounds

Debuffs are drawn per round from the `RoundDifficultyConfig` of the active channel (`max_debuffs`, `debuff_difficulty_cap`):

- **Per-zone draw-once pool**: `DebuffManager` tracks `_drawn_this_zone`; once a debuff is drawn it cannot repeat within the same zone. The pool resets on zone change via `reset_zone_pool()` (also exposed through `get_drawn_this_zone()` / `set_drawn_this_zone()` for save/load).
- **Boss rounds**: Round 6 of each zone sets `is_boss_round = true` and `boss_debuff_level` (zone 1 = level 4, zones 2-4 = level 5). A boss round draws exactly one debuff of that exact level via `DebuffManager.select_boss_debuff(level)` and draws no regular debuffs (`max_debuffs = 0`).
- **Zone schedule**: Zone 1 rounds 1-5 have no debuffs; zones 2-4 draw one debuff per round with difficulty caps 2 / 3 / 4 respectively.
- **Grant-only debuffs**: IDs in `DebuffManager.GRANTED_ONLY_IDS` (e.g. `rebellion`) are never drawn — they are only applied explicitly by other systems.

### Per-Round Pre-Selection

At run start, `RoundManager._initialize_rounds_data()` pre-selects the debuffs and grounding for every round and stores them on each round's data dict as `debuff_ids` (Array) and `grounding_id` (String, empty when none). Draws go through `DebuffManager` using the round's `RoundDifficultyConfig`, so the per-zone draw-once pool and boss rules are fully decided before Round 1 begins. `RoundManager` exposes the selection source via the `debuff_manager_path` export.

`GameController._build_round_panel_data()` consumes these stored ids when building the round panel (store list, targets, debuff previews). For old saves that predate pre-selection, it falls back to a fresh draw. Test scene: `Tests/RoundPreselectTest.tscn`.

## Difficulty Ratings (1-5, retuned)

| Debuff | ID | Rating |
|--------|----|--------|
| Too Greedy | `too_greedy` | 5 |
| The Division | `the_division` | 5 |
| Murphy's Law | `rotating_disabled_powerup` | 4 |
| Reduced Levels | `reduced_levels` | 4 |
| Disabled Colors | `disabled_colors` | 4 |
| One Shot | `one_shot` | 3 |
| Costly Roll | `costly_roll` | 3 |
| Rolling Penalty | `roll_score_minus_one` | 2 |
| Locked Dice | `lock_dice` | 2 |
| Half Additive | `half_additive` | 2 |
| Disabled 2s | `disabled_twos` | 2 |
| Abstinence | `no_consumables_allowed` | 1 |
| Mixed Bag | `mixed_bag` | 1 |
| Faster Chores | `faster_chores` | 1 |
| Disabled Mods | `disabled_mods` | 1 |
| Window Shopping | `window_shopping` | 1 |
| Liquidation Sale | `all_powerups_sold` | 5 |

**Window Shopping** (new): `window_shopping`, difficulty 1, glyph 15 (Wealth Drain) — all shop prices increased by 25% while active. It is a normal debuff (not a grounding).

**Rebellion** (`rebellion`) is the sass-reward buff riding the debuff pipeline; it stays grant-only and is excluded from every draw pool.

## Groundings

Groundings are Mom-themed punishments in a **separate pool** from debuffs (`DebuffData.is_grounding = true`). They share the debuff UI slots and the per-zone draw-once pool, but they are drawn by `RoundDifficultyConfig.grounding_chance` (zones 2-4 rounds 1-5 = 0.25, zone 1 = 0) instead of `max_debuffs`, and are excluded from normal and boss debuff draws.

The three groundings:

| Grounding | ID | Effect |
|-----------|----|--------|
| Docked Allowance | `docked_allowance` | End-of-round award withheld; the stats panel shows "ALLOWANCE DOCKED:" with a $0 total |
| Coupons Revoked | `coupons_revoked` | Removes all held coupons (consumables) at round start |
| POGS Confiscated | `pogs_confiscated` | Revokes N random power-ups; N scales with REP tier (tiers 0-1 → 1, 2-3 → 2, 4 → 3) |

**Adding a grounding** is the same recipe as a debuff, plus two extra steps:
1. Create the script, scene, and `DebuffData` resource as usual, and set `is_grounding = true` on the resource.
2. Add the grounding's ID to the `match` arm in `GameController` (`game_controller.gd`, alongside `docked_allowance` / `coupons_revoked` / `pogs_confiscated`) so it gets the right target and startup behavior.
3. Test with `Tests/GroundingTest.tscn`.

## Best Practices

### Code Quality:
- Follow the project's coding standards (tabs, snake_case, etc.)
- Add comprehensive documentation with GDScript doc comments
- Use descriptive variable and method names
- Handle edge cases and error conditions

### Game Design:
- Ensure debuffs are challenging but not frustrating
- Balance negative effects appropriately
- Consider how debuffs interact with existing systems
- Test debuffs with various power-up combinations

### Technical Implementation:
- Always implement proper cleanup in `remove()`
- Avoid memory leaks by disconnecting signals
- Use appropriate target types (self, dice_hand, scorecard)
- Test debuff activation and deactivation thoroughly

### UI/UX Considerations:
- Choose a `glyph_id` that communicates the debuff's effect via the procedural SDF glyph shader
- Tune per-debuff shader overrides (`glyph_scale`, `line_thickness`, `glow_strength`, etc.) if the default look is too thick/thin or dim
- Write clear, concise descriptions
- Ensure debuff effects are visible to the player
- Consider animation or visual feedback for debuff application

## Testing Checklist

Before considering a debuff complete, verify:

- [ ] Script compiles without errors
- [ ] Scene file loads correctly
- [ ] Resource file is properly configured
- [ ] DebuffManager can spawn the debuff
- [ ] GameController can apply and remove the debuff
- [ ] `apply()` method works as intended
- [ ] `remove()` method properly cleans up
- [ ] No memory leaks or orphaned connections
- [ ] UI displays debuff correctly
- [ ] Debug panel integration works
- [ ] Debuff interacts properly with other systems
- [ ] Edge cases are handled gracefully

## Common Issues and Solutions

### Issue: "Failed to spawn Debuff"
**Solution**: Check that the scene path in the resource is correct and the scene file exists.

### Issue: Debuff effects don't apply
**Solution**: Verify the target is correct and the `apply()` method is properly implemented.

### Issue: Debuff effects persist after removal
**Solution**: Ensure `remove()` method undoes all changes made in `apply()`.

### Issue: Missing from DebuffManager
**Solution**: Add the DebuffData resource to the DebuffManager's `debuff_defs` array.

### Issue: GameController doesn't recognize debuff
**Solution**: Add a case for your debuff ID in the `apply_debuff()` method.

## File Structure Summary

```
DiceRogue/
├── Scripts/
│   └── Debuff/
│       ├── your_debuff_script.gd          # Main debuff logic
│       └── YourDebuffData.tres            # Debuff metadata resource
├── Scenes/
│   └── Debuff/
│       └── YourDebuffScene.tscn           # Debuff scene file
└── Resources/
    └── Art/
        └── Powerups/
            └── your_debuff_icon.png       # Icon for UI (optional new icon)
```

This guide ensures consistent, maintainable debuff implementation that integrates seamlessly with the existing DiceRogue codebase.