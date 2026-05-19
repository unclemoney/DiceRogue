class_name JuiceProfile
extends Resource

## JuiceProfile
##
## Global tuneable parameters for UI animation juice.
## Assign to a ContainerAnimator or TweenFXHelper to control timing,
## easing, and overshoot across an entire UI scene.

@export_group("Timing")
## Base duration for entrance and exit presets.
@export var default_duration: float = 0.4
## Delay between each child in a staggered container animation.
@export var default_stagger: float = 0.08

@export_group("Motion")
## How far nodes travel for fly / slide presets (in pixels).
@export var entrance_distance: float = 100.0
## Strength of the overshoot on pop-in animations (0.0 = none, 0.3 = heavy).
@export var overshoot_strength: float = 0.15
## Strength of the bounce settle on elastic animations.
@export var bounce_strength: float = 0.3

@export_group("Easing")
## Default easing mode for UI presets.
@export var default_easing: int = Tween.EASE_OUT
## Default transition type for UI presets.
@export var default_transition: int = Tween.TRANS_BACK

@export_group("Scale / Fade")
## Starting scale for pop_in presets.
@export var pop_in_scale: float = 0.8
## Duration for pure fade presets.
@export var fade_in_duration: float = 0.35

@export_group("Playback")
## Pause behavior for UI tweens. Use PROCESS so menus animate while game is paused.
@export var pause_mode: int = Tween.TWEEN_PAUSE_PROCESS


## get_duration(override) -> float
##
## Returns the effective duration, allowing per-call override.
## Pass a negative value to fall back to the profile default.
func get_duration(override: float = -1.0) -> float:
	if override > 0.0:
		return override
	return default_duration


## get_stagger(override) -> float
##
## Returns the effective stagger delay, allowing per-call override.
func get_stagger(override: float = -1.0) -> float:
	if override >= 0.0:
		return override
	return default_stagger
