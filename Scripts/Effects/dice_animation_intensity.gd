extends RefCounted
class_name DiceAnimationIntensity

## DiceAnimationIntensity
##
## Static utility that computes animation intensity parameters from
## challenge progress and total score. Used to scale dice animations
## dynamically throughout a game session.

## Score milestone tiers matching score_panel_energy shader
const MILESTONE_TIERS = [0, 100, 250, 500, 1000]

## calculate(challenge_progress: float, total_score: int) -> Dictionary
##
## Returns a dictionary of multipliers for animation systems.
## @param challenge_progress: 0.0 to 1.0 from active challenge
## @param total_score: cumulative score from scorecard
## @return Dictionary with animation multipliers
static func calculate(challenge_progress: float, total_score: int, good_roll_streak: int = 0) -> Dictionary:
	var milestone_tier = _get_milestone_tier(total_score)
	var streak_mult = clampf(good_roll_streak * 0.08, 0.0, 0.4)
	var base_mult = 1.0 + challenge_progress * 0.5 + milestone_tier * 0.2 + streak_mult
	return {
		"bounce_height_mult": base_mult,
		"speed_mult": 1.0 + milestone_tier * 0.1 + streak_mult * 0.5,
		"rotation_mult": base_mult * 1.2,
		"shockwave_scale": 1.0 + challenge_progress * 0.3 + milestone_tier * 0.15 + streak_mult,
		"idle_intensity": clampf(0.6 + challenge_progress * 0.4 + streak_mult, 0.6, 1.4),
	}


## _get_milestone_tier(total_score: int) -> int
##
## Returns 0-4 based on score_panel_energy milestone thresholds.
static func _get_milestone_tier(total_score: int) -> int:
	for i in range(MILESTONE_TIERS.size() - 1, -1, -1):
		if total_score >= MILESTONE_TIERS[i]:
			return i
	return 0
