extends ScoreCardUI
class_name MockScoreCardUI

## MockScoreCardUI
##
## Simplified ScoreCardUI for testing without node dependencies

func _ready():
	# Override _ready to avoid node lookups
	print("[MockScoreCardUI] MockScoreCardUI ready")

func update_all():
	print("[MockScoreCardUI] update_all() called - UI would be updated here")
	# Simplified update without node lookups

func connect_buttons():
	print("[MockScoreCardUI] connect_buttons() called - buttons would be connected here")
	# Skip button connections for testing