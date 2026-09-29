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

@export_group("Buff Fanfare")
## Horizontal distance beyond the viewport's right edge where fanfare icons spawn.
@export var fanfare_spawn_offset_x: float = 64.0
## Scale of the fanfare icon at spawn (settles to 1.0 on landing).
@export var fanfare_spawn_scale: float = 1.5
## Rotation of the fanfare icon at spawn, in degrees (wobbles to 0 on landing).
@export var fanfare_spawn_rotation_deg: float = 10.0
## Fly-in time from off-screen to the spine slot.
@export var fanfare_fly_time: float = 0.35
## Landing scale-punch time (spawn scale -> 1.0, bounce-out).
@export var fanfare_land_punch_time: float = 0.20
## Slot squash-and-stretch hop duration on landing.
@export var fanfare_hop_time: float = 0.15
## Slot hop height in pixels.
@export var fanfare_hop_height: float = 8.0
## Delay between multiple fanfare icons landing at once (top-to-bottom).
@export var fanfare_stagger: float = 0.08
## Explosion / ring tint for buff fanfares.
@export var fanfare_buff_tint: Color = Color(0.45, 1.0, 0.55)
## Explosion / ring tint for debuff fanfares.
@export var fanfare_debuff_tint: Color = Color(1.0, 0.35, 0.35)
## Volume of the landing jackpot beat.
@export var fanfare_jackpot_volume_db: float = -12.0
## Settle delay after the powerup-removal animation before later Mom juice plays.
@export var mom_sequence_powerup_settle: float = 0.6

@export_group("Console Scoring")
## Delay between console score chips flying into the score sink.
@export var console_score_stagger: float = 0.10
## Font scale of console score chips.
@export var console_chip_font_scale: float = 1.2
## Sink wobble intensity for console score arrivals.
@export var console_wobble: float = 1.0

@export_group("Money Pull")
## Delay between individual money chips leaving the money display.
@export var money_pull_stagger: float = 0.06
## Flight time of one money chip to the Mom portrait.
@export var money_pull_flight_time: float = 0.40
## Upward arc height of the chip flight path, in pixels.
@export var money_pull_arc_height: float = 40.0
## Red destination-flash duration at the Mom portrait.
@export var money_pull_flash_time: float = 0.15
## Base pitch for the per-chip coin sound (~0.8 = pitched down 20%).
@export var money_pull_base_pitch: float = 0.8
## Additional pitch drop per chip in the stream.
@export var money_pull_pitch_step: float = 0.01
## Safety cap on chip count (0 = strict one chip per dollar).
@export var money_pull_max_chips: int = 40
## Fallback Mom anchor when the dialog is gone (money-pull destination).
@export var money_pull_mom_fallback_pos: Vector2 = Vector2(640, 240)


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
