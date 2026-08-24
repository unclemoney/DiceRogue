extends Resource
class_name BalanceTuning

## BalanceTuning
##
## Data-driven balance knobs derived from bot baseline measurement
## (see PLAN_BALANCE.md). Loaded by ChannelManager; consumed anywhere the
## target curve or the rebel premium is needed.

## Margin curve: channel target = margin × median bot score for that round.
## margin_c = margin_start + (margin_end - margin_start) × (c-1)/(MAX-1)
## Decided in Branch 1 of the balance plan: soft early, tight late.
@export var margin_start: float = 0.65
@export var margin_end: float = 0.90

## Win-rate anchors the margin curve was tuned against (verification targets).
@export var anchor_winrate_early: float = 0.80  # ~ch1-3 expected bot win rate
@export var anchor_winrate_late: float = 0.50   # ~ch20 expected bot win rate

## Rebel target premium per Rep tier (0-4), applied at round start:
##   final_target = scaled_target × (1 + premium[get_rep_tier()])
## premium[0] and [1] are 0 — comply players (Rep 0 resolves to tier 1) are
## never affected. Tiers 2-4 from the Phase 0 sass/comply measured uplift
## (tier 2 ≈ +34%) extended by the RebellionBuff per-stack ladder (+0.15).
## Recalibrate from A/B data in Phase 2.
@export var rebel_tier_premiums: Array[float] = [0.0, 0.0, 0.34, 0.49, 0.64]


## margin_for_channel(channel) -> float
func margin_for_channel(channel: int) -> float:
	var t := clampf((channel - 1) / 19.0, 0.0, 1.0)
	return margin_start + (margin_end - margin_start) * t


## premium_for_rep_tier(tier) -> float
func premium_for_rep_tier(tier: int) -> float:
	var idx := clampi(tier, 0, rebel_tier_premiums.size() - 1)
	return rebel_tier_premiums[idx]
