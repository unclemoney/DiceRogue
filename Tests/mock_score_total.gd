extends Label
class_name MockScoreTotal

## MockScoreTotal
##
## Test-scene total label implementing ScoreCardUI's conceal/reveal
## contract. The scenario buttons write the new total IMMEDIATELY (same as
## the real scorecard rendering at score-computation time); the controller
## conceals it back to the committed value for the sink sequence and the
## drain count-up reveals it. Without the conceal hook this label would
## spoil the score — that makes the test discriminate.

## Seconds to wait before committing the post-count-up text. Longer than
## COUNT_UP_T at any speed_scale (0.60s / max 3.2 = 0.19s).
const COMMIT_DELAY: float = 1.0

var _committed_text: String = "0"
var _concealed: bool = false

## spoil_to(value)
##
## Simulate the compute-time render: jump straight to the post-score total.
func spoil_to(value: int) -> void:
	text = str(value)

## get_committed() -> int
##
## The last revealed total (what the label showed before this event).
func get_committed() -> int:
	return int(_committed_text) if _committed_text.is_valid_int() else 0

## begin_scoring_concealment()
##
## Controller hook: hold the pre-event value for the whole sink sequence.
## Always restores (not just on first conceal) so a mid-animation restart
## re-hides the next event's spoiled value too.
func begin_scoring_concealment(_force: bool = true) -> void:
	text = _committed_text
	_concealed = true

func is_scoring_concealed() -> bool:
	return _concealed

## reveal_scoring_scores()
##
## Drain hook: lift concealment. The controller's count-up writes the text;
## commit whatever it lands on once the tween has finished.
func reveal_scoring_scores() -> void:
	if not _concealed:
		return
	_concealed = false
	await get_tree().create_timer(COMMIT_DELAY).timeout
	_committed_text = text
