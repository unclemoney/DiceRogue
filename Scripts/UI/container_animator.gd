class_name ContainerAnimator
extends Node

## ContainerAnimator
##
## Drop this node into any UI scene to animate its parent Container's children
## with staggered entrance or exit presets.
##
## Usage:
##   1. Add ContainerAnimator as a child of a VBoxContainer, HBoxContainer, or GridContainer.
##   2. Configure entrance_preset, stagger_pattern, and juice_profile in the Inspector.
##   3. Set trigger_mode to READY for automatic playback, or call trigger_entrance() manually.

enum TriggerMode {
	READY,   ## Automatically plays entrance when _ready() fires
	MANUAL,  ## Must call trigger_entrance() / trigger_exit() from code
	SIGNAL   ## Reserved for future signal-driven trigger
}

enum StaggerPattern {
	CASCADE,    ## Top-to-bottom (VBox) or left-to-right (HBox/Grid)
	REVERSE,    ## Bottom-to-top or right-to-left
	CENTER_OUT, ## Middle child first, radiating outward
	RANDOM      ## Randomized order, deterministic per container name
}

@export_group("Trigger")
@export var trigger_mode: TriggerMode = TriggerMode.READY

@export_group("Presets")
## Preset applied to all children unless they have a UIAnimated override.
@export var entrance_preset: String = "pop_in"
## Preset applied to all children on exit unless they have a UIAnimated override.
@export var exit_preset: String = "fade_out"

@export_group("Stagger")
## How children are ordered for sequencing.
@export var stagger_pattern: StaggerPattern = StaggerPattern.CASCADE
## Delay between each child. -1 falls back to the JuiceProfile default.
@export var stagger_delay: float = -1.0
## Global delay before the first child animates.
@export var delay_before_start: float = 0.0

@export_group("Profile")
## Override juice profile. If null, uses TweenFXHelper.default_juice_profile.
@export var juice_profile: JuiceProfile = null

@export_group("Behaviour")
## If true, children with a UIAnimated component use their own preset/delay settings.
@export var respect_child_overrides: bool = true

@onready var _tfx: Node = get_node_or_null("/root/TweenFXHelper")
var _is_animating: bool = false


func _ready() -> void:
	if trigger_mode == TriggerMode.READY:
		call_deferred("trigger_entrance")


## trigger_entrance()
##
## Animates all children of the parent Container with the entrance preset,
## applying stagger and respecting UIAnimated overrides.
## Returns an array of Tweens fired (one per animated child).
func trigger_entrance() -> Array[Tween]:
	return _trigger(entrance_preset, false)


## trigger_exit()
##
## Animates all children of the parent Container with the exit preset.
## Returns an array of Tweens fired.
func trigger_exit() -> Array[Tween]:
	return _trigger(exit_preset, true)


## stop_all()
##
## Stops all running TweenFX animations on every child of the parent Container.
func stop_all() -> void:
	var container = _get_target_container()
	if not container:
		return
	for child in container.get_children():
		if child is CanvasItem and _tfx:
			_tfx.stop_effect(child)


## _trigger(preset, is_exit) -> Array[Tween]
##
## Core sequencing logic. Collects children, sorts by pattern, and fires
## staggered animations with optional delay.
func _trigger(preset: String, is_exit: bool) -> Array[Tween]:
	var container = _get_target_container()
	if not container:
		push_warning("[ContainerAnimator] Parent is not a Container: " + str(get_parent()))
		return []
	if not _tfx:
		_tfx = get_node_or_null("/root/TweenFXHelper")
	if not _tfx:
		return []

	var children := _get_sorted_children(container)
	if children.is_empty():
		return []

	var tweens: Array[Tween] = []
	var profile: JuiceProfile = juice_profile
	if not profile and _tfx.has_method("get_default_juice_profile"):
		profile = _tfx.get_default_juice_profile()
	if not profile:
		profile = JuiceProfile.new()

	var stagger: float = profile.get_stagger(stagger_delay)
	var cumulative_delay: float = delay_before_start

	for child in children:
		if not child is CanvasItem:
			continue
		if not child.visible and not is_exit:
			# Skip invisible children on entrance, but still consume stagger time
			cumulative_delay += stagger
			continue

		var target_preset: String = preset
		var target_delay: float = cumulative_delay
		var target_stagger: float = stagger

		# Respect UIAnimated overrides
		if respect_child_overrides:
			var ua := _find_ui_animated(child)
			if ua:
				if is_exit:
					if ua.exit_preset.length() > 0:
						target_preset = ua.exit_preset
				else:
					if ua.entrance_preset.length() > 0:
						target_preset = ua.entrance_preset
				if ua.stagger_override >= 0.0:
					target_stagger = ua.stagger_override
				if ua.delay > 0.0:
					target_delay += ua.delay

		var tween: Tween = _tfx.play_preset(child, target_preset, profile, target_delay)
		if tween:
			tweens.append(tween)

		cumulative_delay += target_stagger

	return tweens


## _get_target_container() -> Container
##
## Returns the parent node if it is a Container, otherwise null.
func _get_target_container() -> Container:
	var p = get_parent()
	if p is Container:
		return p
	return null


## _get_sorted_children(container) -> Array[Node]
##
## Returns the container's children sorted according to stagger_pattern.
func _get_sorted_children(container: Container) -> Array[Node]:
	var raw := container.get_children()
	# Filter out non-CanvasItem and self
	var filtered: Array[Node] = []
	for child in raw:
		if child == self:
			continue
		if child is CanvasItem:
			filtered.append(child)

	match stagger_pattern:
		StaggerPattern.CASCADE:
			return filtered
		StaggerPattern.REVERSE:
			filtered.reverse()
			return filtered
		StaggerPattern.CENTER_OUT:
			return _sort_center_out(filtered, container)
		StaggerPattern.RANDOM:
			return _sort_random(filtered, container)
		_:
			return filtered


## _sort_center_out(children, container) -> Array[Node]
##
## Sorts children by distance from the visual center of the container.
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

	# Simple bubble sort by distance (arrays are small, so performance is fine)
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


## _sort_random(children, container) -> Array[Node]
##
## Shuffles children deterministically based on container name hash.
func _sort_random(children: Array[Node], container: Container) -> Array[Node]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(container.name)
	var shuffled := children.duplicate()
	shuffled.shuffle()
	# Re-shuffle using our seeded RNG for determinism
	for i in range(shuffled.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled


## _find_ui_animated(node) -> UIAnimated
##
## Returns the first UIAnimated child component attached to the given node.
func _find_ui_animated(node: Node) -> UIAnimated:
	for child in node.get_children():
		if child is UIAnimated:
			return child
	return null
