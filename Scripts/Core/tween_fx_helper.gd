# Scripts/Core/tween_fx_helper.gd
# Autoload singleton — do NOT add class_name
# Provides standardized TweenFX wrappers for common game animation patterns.
# All effects route through TweenFX; swap visuals here without touching 30+ scripts.
# Each effect belongs to a named group that can be toggled on/off at runtime.
extends Node

## ─── FX GROUP SYSTEM ───────────────────────────────────────────────

## FX group identifiers. Every wrapper method checks its group before firing.
enum Group {
	BUTTONS,   ## Hover, press, denied effects on buttons
	SPINES,    ## Spine hover/unhover snap effects
	IDLE,      ## Looping idle animations (pulse, float, sway, wiggle)
	PANELS,    ## Panel show/hide pop effects
	ICONS,     ## Icon appear/hover/remove effects
	EVENTS,    ## One-shot event effects (celebration, negative_hit, reward, value_change)
	THREATS,   ## Looping threat effects (alarm, flicker)
	REVEALS,   ## Spotlight enter/exit effects
	DIALOGUE,  ## Typewriter text reveal effects
	SHADERS,   ## Shader parameter tween effects
	COUNTERS,  ## Animated number counter effects
	CONTAINERS,## Container stagger and sequencing effects
}

## Human-readable display names for the settings UI.
const GROUP_NAMES := {
	Group.BUTTONS: "Buttons",
	Group.SPINES: "Spines",
	Group.IDLE: "Idle Animations",
	Group.PANELS: "Panels",
	Group.ICONS: "Icons",
	Group.EVENTS: "Events",
	Group.THREATS: "Threats",
	Group.REVEALS: "Reveals",
	Group.DIALOGUE: "Dialogue",
	Group.SHADERS: "Shaders",
	Group.COUNTERS: "Counters",
	Group.CONTAINERS: "Containers",
}

## Short descriptions shown in the settings UI.
const GROUP_DESCRIPTIONS := {
	Group.BUTTONS: "Hover jelly and press punch on buttons",
	Group.SPINES: "Scale snap on corkboard spine hover",
	Group.IDLE: "Looping sway, wiggle, pulse, and float",
	Group.PANELS: "Pop-in / pop-out on panels and overlays",
	Group.ICONS: "Pop-in, jelly hover, vanish on card icons",
	Group.EVENTS: "Celebration, reward glow, negative hit flash",
	Group.THREATS: "Alarm pulse and flicker on debuffs",
	Group.REVEALS: "Spotlight glow enter / exit",
	Group.DIALOGUE: "Typewriter text reveal for dialogs",
	Group.SHADERS: "Shader parameter tween animations",
	Group.COUNTERS: "Animated number count-up effects",
	Group.CONTAINERS: "Staggered container entrance and exit animations",
}

## Which groups are currently enabled. All default to true.
var _enabled_groups: Dictionary = {}

## Signal emitted when any group is toggled — settings UI can listen.
signal group_toggled(group: int, enabled: bool)


func _ready() -> void:
	# Enable all groups by default
	for g in Group.values():
		_enabled_groups[g] = true
	# Disable IDLE animations by default
	_enabled_groups[Group.IDLE] = false
	_enabled_groups[Group.SPINES] = false


## Groups that are permanently off and cannot be re-enabled by settings or profiles.
const PERMANENTLY_DISABLED_GROUPS: Array[int] = [Group.SPINES, Group.IDLE]


## is_group_enabled(group)
##
## Returns whether a specific FX group is currently active.
## SPINES and IDLE are permanently disabled and always return false.
func is_group_enabled(group: Group) -> bool:
	if group in PERMANENTLY_DISABLED_GROUPS:
		return false
	return _enabled_groups.get(group, true)


## set_group_enabled(group, enabled)
##
## Enables or disables an entire FX group at runtime.
## Calls for permanently disabled groups (SPINES, IDLE) are silently ignored.
func set_group_enabled(group: Group, enabled: bool) -> void:
	if group in PERMANENTLY_DISABLED_GROUPS:
		return
	_enabled_groups[group] = enabled
	group_toggled.emit(group, enabled)


## get_all_group_states()
##
## Returns the full Dictionary of group -> bool for saving/loading.
func get_all_group_states() -> Dictionary:
	return _enabled_groups.duplicate()


## set_all_group_states(states)
##
## Bulk-loads group states from a saved Dictionary.
func set_all_group_states(states: Dictionary) -> void:
	for g in Group.values():
		_enabled_groups[g] = states.get(g, true)

## ─── BUTTON EFFECTS ────────────────────────────────────────────────

## button_hover(node)
##
## Plays a subtle jelly effect on a button when the mouse enters.
## Commonly connected to mouse_entered on any Button or TextureButton.
## Skips disabled buttons to avoid animating inactive UI elements.
func button_hover(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.BUTTONS):
		return null
	if node is BaseButton and (node as BaseButton).disabled:
		return null
	_center_pivot(node)
	return TweenFX.rubber_band(node, 0.3, 0.05) #2

## button_unhover(node)
##
## Stops any active jelly on a button and resets scale.
## Commonly connected to mouse_exited.
## Skips disabled buttons to avoid animating inactive UI elements.
func button_unhover(node: CanvasItem) -> void:
	if not _valid(node) or not is_group_enabled(Group.BUTTONS):
		return
	if node is BaseButton and (node as BaseButton).disabled:
		return
	TweenFX.stop(node, TweenFX.Animations.JELLY)
	node.scale = Vector2.ONE

## button_press(node)
##
## Quick inward punch on a button press. Fire-and-forget.
## Returns the Tween so callers can await if desired.
## Skips disabled buttons to avoid animating inactive UI elements.
func button_press(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.BUTTONS):
		return null
	if node is BaseButton and (node as BaseButton).disabled:
		return null
	_center_pivot(node)
	return TweenFX.punch_in(node, 0.12, 0.2)

## button_denied(node)
##
## Horizontal shake indicating an invalid action (e.g., insufficient funds, locked).
## Skips disabled buttons to avoid animating inactive UI elements.
func button_denied(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.BUTTONS):
		return null
	if node is BaseButton and (node as BaseButton).disabled:
		return null
	return TweenFX.shake(node, 0.3, 8.0, 4)

## ─── PANEL EFFECTS ─────────────────────────────────────────────────

## panel_show(panel, overlay)
##
## Pops a panel in and fades the overlay backdrop. Await the returned Tween for
## sequencing logic after the animation finishes.
## Either parameter may be null to skip that part.
func panel_show(panel: CanvasItem, overlay: CanvasItem = null) -> Tween:
	if not is_group_enabled(Group.PANELS):
		if overlay and _valid(overlay):
			overlay.modulate.a = 1.0
			overlay.visible = true
		if panel and _valid(panel):
			panel.scale = Vector2.ONE
			panel.modulate.a = 1.0
			panel.visible = true
		return null
	var tween: Tween = null
	if overlay and _valid(overlay):
		overlay.modulate.a = 0.0
		overlay.visible = true
		TweenFX.fade_in(overlay, 0.25)
	if panel and _valid(panel):
		_center_pivot(panel)
		panel.scale = Vector2(0.8, 0.8)
		panel.modulate.a = 0.0
		panel.visible = true
		tween = TweenFX.pop_in(panel, 0.35, 0.1)
	return tween

## panel_hide(panel, overlay)
##
## Pops a panel out and fades the overlay. Returns the panel tween for await.
## Caller is responsible for setting visible = false after await if needed.
func panel_hide(panel: CanvasItem, overlay: CanvasItem = null) -> Tween:
	if not is_group_enabled(Group.PANELS):
		if overlay and _valid(overlay):
			overlay.visible = false
		if panel and _valid(panel):
			panel.visible = false
		return null
	var tween: Tween = null
	if overlay and _valid(overlay):
		TweenFX.fade_out(overlay, 0.2)
	if panel and _valid(panel):
		_center_pivot(panel)
		tween = TweenFX.pop_out(panel, 0.25, 0.1)
	return tween

## ─── ICON / CARD EFFECTS ───────────────────────────────────────────

## icon_appear(node)
##
## Plays a pop-in when a card icon first appears (shop purchase, power-up acquired).
func icon_appear(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.ICONS):
		return null
	_center_pivot(node)
	return TweenFX.pop_in(node, 0.3, 0.1)

## icon_hover(node)
##
## Jelly effect when hovering over a card icon. Slightly larger than button_hover.
func icon_hover(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.ICONS):
		return null
	_center_pivot(node)
	return TweenFX.jelly(node, 0.5, 0.2, 2)

## icon_remove(node)
##
## Vanish effect when selling/consuming/expiring an icon.
func icon_remove(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.ICONS):
		return null
	_center_pivot(node)
	return TweenFX.vanish(node, 0.3)

## ─── SPINE EFFECTS ─────────────────────────────────────────────────

## spine_hover(node)
##
## Snap-in scale effect when a spine (book-like shelf item) is hovered.
## Uses PlayState.ENTER so it stays scaled until spine_unhover is called.
func spine_hover(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.SPINES):
		return null
	_center_pivot(node)
	return TweenFX.snap(node, 0.1, Vector2(1.05, 1.05), TweenFX.PlayState.ENTER)

## spine_unhover(node)
##
## Snap-out restoring spine to its original scale.
func spine_unhover(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.SPINES):
		return null
	_center_pivot(node)
	return TweenFX.snap(node, 0.1, Vector2(1.05, 1.05), TweenFX.PlayState.EXIT)

## ─── IDLE / LOOPING EFFECTS ────────────────────────────────────────

## idle_pulse(node)
##
## Looping breathe animation to draw attention to a button or element.
## Call stop_effect(node) to end.
func idle_pulse(node: CanvasItem, strength: float = 0.04) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.IDLE):
		return null
	_center_pivot(node)
	return TweenFX.breathe(node, 2.0, strength)

## idle_float(node, height)
##
## Gentle looping vertical bob. Great for titles and decorative labels.
## Call stop_effect(node) to end.
func idle_float(node: CanvasItem, height: float = 5.0) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.IDLE):
		return null
	return TweenFX.float_bob(node, 2.0, height)

## idle_sway(node)
##
## Gentle looping rotation sway. Good for spine personality.
func idle_sway(node: CanvasItem, angle: float = 4.0) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.IDLE):
		return null
	_center_pivot(node)
	return TweenFX.sway(node, 2.5, angle)

## idle_wiggle(node)
##
## Subtle looping wiggle. Good for active challenges.
func idle_wiggle(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.IDLE):
		return null
	_center_pivot(node)
	return TweenFX.wiggle(node, 1.2)

## ─── VALUE CHANGE EFFECTS ──────────────────────────────────────────

## value_change(node)
##
## Quick punch to emphasise a number or label changing value.
func value_change(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.EVENTS):
		return null
	_center_pivot(node)
	return TweenFX.punch_in(node, 0.15, 0.2)

## negative_hit(node)
##
## Red flash + scale punch for negative effects (damage, penalties).
func negative_hit(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.EVENTS):
		return null
	_center_pivot(node)
	return TweenFX.critical_hit(node, 0.4, Color(2.0, 0.3, 0.3, 1.0))

## positive_reward(node)
##
## Gold glow + scale swell for positive rewards (level-ups, bonuses, unlocks).
func positive_reward(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.EVENTS):
		return null
	_center_pivot(node)
	return TweenFX.upgrade(node, 0.6, Color(2.0, 1.8, 0.2, 1.0))

## celebration(node)
##
## Celebratory tada when something impressive happens (Yahtzee, challenge complete).
func celebration(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.EVENTS):
		return null
	_center_pivot(node)
	return TweenFX.tada(node, 0.6)

## ─── THREAT EFFECTS ────────────────────────────────────────────────

## threat_alarm(node)
##
## Looping red alarm pulse for debuffs. Call stop_effect(node) to end.
func threat_alarm(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.THREATS):
		return null
	return TweenFX.alarm(node, 0.3, Color(2.0, 0.2, 0.2, 1.0))

## threat_flicker(node)
##
## Unsettling looping flicker. Good for debuff spines.
func threat_flicker(node: CanvasItem) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.THREATS):
		return null
	return TweenFX.flicker(node, 0.08, 0.5)

## ─── REVEAL EFFECTS ────────────────────────────────────────────────

## spotlight_enter(node)
##
## Brightens a node with a glow—stays lit until spotlight_exit is called.
func spotlight_enter(node: CanvasItem, glow: Color = Color(1.5, 1.5, 1.5, 1.0)) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.REVEALS):
		return null
	return TweenFX.spotlight(node, 0.4, glow, TweenFX.PlayState.ENTER)

## spotlight_exit(node)
##
## Returns a spotlit node to its original modulate.
func spotlight_exit(node: CanvasItem, glow: Color = Color(1.5, 1.5, 1.5, 1.0)) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.REVEALS):
		return null
	return TweenFX.spotlight(node, 0.3, glow, TweenFX.PlayState.EXIT)

## ─── DIALOGUE EFFECTS ──────────────────────────────────────────────

## dialogue_typewriter(label, text, speed)
##
## Typewriter text reveal for tutorial and dialog panels.
func dialogue_typewriter(label: Label, text: String, speed: float = 0.04) -> Tween:
	if not _valid(label) or not is_group_enabled(Group.DIALOGUE):
		return null
	return TweenFX.typewriter(label, text, speed)

## ─── COUNTER EFFECTS ───────────────────────────────────────────────

## score_count_up(label, from, to, duration)
##
## Animated number counter for money, score, or any numeric display.
func score_count_up(label: Label, from: int, to: int, duration: float = 0.5) -> Tween:
	if not _valid(label) or not is_group_enabled(Group.COUNTERS):
		return null
	return TweenFX.count_up(label, from, to, duration)

## ─── SHADER EFFECTS ────────────────────────────────────────────────

## shader_pulse(node, param, from, to, duration)
##
## Animate a shader parameter by name (e.g., glow_strength, flash_intensity).
func shader_pulse(node: CanvasItem, param: String, from_val: Variant, to_val: Variant, duration: float = 0.3) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.SHADERS):
		return null
	return TweenFX.tween_shader_param(node, param, from_val, to_val, duration)

## ─── TOOLTIP EFFECTS ───────────────────────────────────────────────

## tooltip_fade_in(node)
##
## Fade in a tooltip background instead of instant alpha toggle.
func tooltip_fade_in(node: CanvasItem, duration: float = 0.1) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.ICONS):
		return null
	return TweenFX.fade_in(node, duration)

## tooltip_fade_out(node)
##
## Fade out a tooltip background instead of instant alpha toggle.
func tooltip_fade_out(node: CanvasItem, duration: float = 0.1) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.ICONS):
		return null
	return TweenFX.fade_out(node, duration)

## ─── STOP HELPERS ──────────────────────────────────────────────────

## stop_effect(node)
##
## Stops ALL running TweenFX animations on a node.
func stop_effect(node: CanvasItem) -> void:
	if not _valid(node):
		return
	TweenFX.stop_all(node)

## stop_specific(node, anim)
##
## Stops a single named TweenFX animation on a node.
func stop_specific(node: CanvasItem, anim: TweenFX.Animations) -> void:
	if not _valid(node):
		return
	TweenFX.stop(node, anim)

## ─── JUICE PROFILE ─────────────────────────────────────────────────

## Default juice profile used when none is explicitly provided.
## Lazy-initialised on first access so the autoload doesn't depend on
## Resources/Data existing at startup.
var default_juice_profile: JuiceProfile = null

## get_default_juice_profile()
##
## Returns the default JuiceProfile, creating an inline default if none
## has been assigned. Callers can safely use this as a fallback.
func get_default_juice_profile() -> JuiceProfile:
	if default_juice_profile == null:
		var res = load("res://Resources/Data/default_juice_profile.tres")
		if res is JuiceProfile:
			default_juice_profile = res
		else:
			default_juice_profile = JuiceProfile.new()
	return default_juice_profile


## ─── PRESET ORCHESTRATION ──────────────────────────────────────────

## play_preset(node, preset_name, profile, delay)
##
## Plays a named UI animation preset on the target node.
## Valid preset names (entrance):
##   "pop_in", "fade_in", "fly_in_left", "fly_in_right",
##   "fly_in_up", "fly_in_down", "overshoot_pop", "slide_and_fade"
## Valid preset names (exit):
##   "pop_out", "fade_out", "fly_out_left", "fly_out_right",
##   "fly_out_up", "fly_out_down", "slide_and_fade_out"
## Returns the Tween so callers can await it, or null if invalid/disabled.
func play_preset(node: CanvasItem, preset_name: String, profile: JuiceProfile = null, delay: float = 0.0) -> Tween:
	if not _valid(node) or not is_group_enabled(Group.CONTAINERS):
		return null
	if profile == null:
		profile = get_default_juice_profile()

	var tween: Tween = null
	var dur: float = profile.default_duration
	var dist: float = profile.entrance_distance

	match preset_name:
		# ── Entrance presets ──
		"pop_in":
			_center_pivot(node)
			node.scale = Vector2.ZERO
			node.modulate.a = 0.0
			tween = TweenFX.pop_in(node, dur, profile.overshoot_strength)
		"fade_in":
			node.modulate.a = 0.0
			tween = TweenFX.fade_in(node, profile.fade_in_duration)
		"fly_in_left":
			tween = TweenFX.fly_in(node, Vector2.LEFT, dist, dur)
		"fly_in_right":
			tween = TweenFX.fly_in(node, Vector2.RIGHT, dist, dur)
		"fly_in_up":
			tween = TweenFX.fly_in(node, Vector2.UP, dist, dur)
		"fly_in_down":
			tween = TweenFX.fly_in(node, Vector2.DOWN, dist, dur)
		"overshoot_pop":
			_center_pivot(node)
			node.scale = Vector2.ONE * profile.pop_in_scale
			node.modulate.a = 0.0
			tween = TweenFX.overshoot_pop_in(node, dur, profile.overshoot_strength)
		"slide_and_fade":
			tween = TweenFX.slide_and_fade_in(node, Vector2.LEFT, dist, dur)

		# ── Exit presets ──
		"pop_out":
			_center_pivot(node)
			tween = TweenFX.pop_out(node, dur * 0.8, profile.overshoot_strength)
		"fade_out":
			tween = TweenFX.fade_out(node, profile.fade_in_duration)
		"fly_out_left":
			tween = TweenFX.fly_out(node, Vector2.LEFT, dist, dur)
		"fly_out_right":
			tween = TweenFX.fly_out(node, Vector2.RIGHT, dist, dur)
		"fly_out_up":
			tween = TweenFX.fly_out(node, Vector2.UP, dist, dur)
		"fly_out_down":
			tween = TweenFX.fly_out(node, Vector2.DOWN, dist, dur)
		"slide_and_fade_out":
			tween = TweenFX.slide_and_fade_out(node, Vector2.RIGHT, dist, dur)
		_:
			push_warning("[TweenFXHelper] Unknown preset: " + preset_name)
			return null

	if tween and delay > 0.0:
		tween.set_delay(delay)
	return tween


## animate_container_children(container, preset_name, pattern, profile, stagger)
##
## Animates every CanvasItem child of the given Container with the named preset,
## applying a stagger delay between each child.
## pattern: "cascade", "reverse", "center_out", or "random"
## Returns an array of Tweens fired (one per animated child).
func animate_container_children(container: Container, preset_name: String, pattern: String = "cascade", profile: JuiceProfile = null, stagger: float = -1.0) -> Array[Tween]:
	if not is_group_enabled(Group.CONTAINERS):
		return []
	if profile == null:
		profile = get_default_juice_profile()
	var stagger_delay: float = profile.get_stagger(stagger)
	var children := container.get_children()
	var filtered: Array[Node] = []
	for child in children:
		if child is CanvasItem:
			filtered.append(child)

	match pattern:
		"reverse":
			filtered.reverse()
		"center_out":
			filtered = _sort_center_out(filtered, container)
		"random":
			filtered = _sort_random(filtered, container)
		# "cascade" uses tree order (default)

	var tweens: Array[Tween] = []
	var cumulative_delay: float = 0.0
	for i in range(filtered.size()):
		var child = filtered[i] as CanvasItem
		if not _valid(child):
			continue
		var tween: Tween = play_preset(child, preset_name, profile, cumulative_delay)
		if tween:
			tweens.append(tween)
		cumulative_delay += stagger_delay
	return tweens


## ─── STAGGERED APPEAR ──────────────────────────────────────────────

## staggered_pop_in(nodes, delay_between)
##
## Pops in an array of nodes one after another with a staggered delay.
## Useful for menu buttons, shop items, or any list that should cascade.
## Returns the Tween from the last node for easy await.
func staggered_pop_in(nodes: Array, delay_between: float = 0.08) -> Tween:
	if not is_group_enabled(Group.PANELS):
		return null
	var last_tween: Tween = null
	for i in range(nodes.size()):
		var node = nodes[i] as CanvasItem
		if not _valid(node):
			continue
		node.scale = Vector2.ZERO
		node.modulate.a = 0.0
		_center_pivot(node)
		# Use a timer-based delay via get_tree (fire-and-forget)
		if i > 0:
			await get_tree().create_timer(delay_between).timeout
		last_tween = TweenFX.pop_in(node, 0.3, 0.1)
	return last_tween


## ─── INTERNAL ──────────────────────────────────────────────────────

## _sort_center_out(children, container)
##
## Sorts children by distance from the visual center of the container.
## Used by animate_container_children for the "center_out" pattern.
func _sort_center_out(children: Array[Node], container: Container) -> Array[Node]:
	if children.is_empty():
		return children
	var count: int = children.size()
	var center_indices: Array[float] = []
	if container is GridContainer:
		var cols: int = container.columns
		if cols < 1:
			cols = 1
		var rows: int = ceili(float(count) / float(cols))
		var center_row: float = (rows - 1) / 2.0
		var center_col: float = (cols - 1) / 2.0
		for i in range(count):
			var row: float = float(i) / float(cols)
			var col: float = float(i - (i / cols) * cols)
			var dist: float = abs(row - center_row) + abs(col - center_col)
			center_indices.append(dist)
	else:
		var center: float = (count - 1) / 2.0
		for i in range(count):
			center_indices.append(abs(i - center))
	var sorted := children.duplicate()
	for i in range(sorted.size()):
		for j in range(i + 1, sorted.size()):
			if center_indices[j] < center_indices[i]:
				var temp = sorted[i]
				sorted[i] = sorted[j]
				sorted[j] = temp
				var temp_idx = center_indices[i]
				center_indices[i] = center_indices[j]
				center_indices[j] = temp_idx
	return sorted


## _sort_random(children, container)
##
## Shuffles children deterministically based on container name hash.
## Used by animate_container_children for the "random" pattern.
func _sort_random(children: Array[Node], container: Container) -> Array[Node]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(container.name)
	var shuffled := children.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled


## _center_pivot(node)
##
## Ensures a Control node's pivot_offset is set to its center so that
## scale and rotation effects appear balanced (not anchored top-left).
## No-op for non-Control nodes (e.g. Node2D).
func _center_pivot(node: CanvasItem) -> void:
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2.0


## Returns true if the node is valid and in the scene tree.
func _valid(node: CanvasItem) -> bool:
	if not node:
		return false
	if not is_instance_valid(node):
		return false
	if not node.is_inside_tree():
		return false
	return true
