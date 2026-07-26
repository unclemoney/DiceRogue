extends Resource
class_name CastCharacter

## CastCharacter Resource
##
## One member of Mom's World: the recurring cast that exists through
## Mom's check-in dialogues (Mrs. Patterson, Dad, Cousin Derek,
## Aunt Debra, Mrs. Henderson). Cast members never speak directly -
## Mom relays everything - so a character is mostly identity plus
## line pools that story beats and zone flavor draw from.
##
## Files live in Resources/Data/Mom/Cast/ and are auto-validated by
## Tests/mom_data_validation_test.gd.

## Unique identifier (e.g. "patterson", "derek"). Referenced by
## MomStoryArc.character_id.
@export var id: String = ""

## Display name used in dialog text (e.g. "Mrs. Patterson").
@export var display_name: String = ""

## Designer-facing blurb: who this person is and their role in the cast.
@export_multiline var role_description: String = ""

## Placeholder portrait (Mom sprites reused until the art pass).
@export var portrait: Texture2D

## Silhouette tint applied to the placeholder portrait.
@export var portrait_tint: Color = Color.WHITE

## mall_zone_name values (see Resources/Data/Channels/) this character
## haunts. Empty = no zone affinity (e.g. Dad, who is always at home).
@export var zone_affinity: Array[String] = []

## Line pools: topic -> Array[String] of BBCode-safe lines.
## Topics in use: "sighting", "comparison", "gossip", "greeting",
## "escalation", "payoff", "zone_reference".
@export var line_pools: Dictionary = {}


## validate() -> bool
##
## Checks the character for data errors. Logs errors but does not throw.
## Zone affinity is cross-checked against the channel table by the
## validation test (not here - resources stay engine-light).
##
## Returns: bool - true if the character is well-formed
func validate() -> bool:
	var all_valid := true

	if id.is_empty():
		push_error("[CastCharacter] id is empty")
		all_valid = false

	if display_name.is_empty():
		push_error("[CastCharacter:'%s'] display_name is empty" % id)
		all_valid = false

	for topic in line_pools.keys():
		var lines: Array = line_pools[topic]
		if lines.is_empty():
			push_error("[CastCharacter:'%s'] line pool '%s' is empty" % [id, topic])
			all_valid = false
			continue
		for line in lines:
			if line == null or str(line).strip_edges().is_empty():
				push_error("[CastCharacter:'%s'] empty line in pool '%s'" % [id, topic])
				all_valid = false
			elif not _is_bbcode_safe(str(line)):
				push_error("[CastCharacter:'%s'] unsafe BBCode in pool '%s': %s" % [id, topic, line])
				all_valid = false

	return all_valid


## _is_bbcode_safe(line) -> bool
##
## Whitelist check: only [color], [shake], [b], [i] tags (and their
## closing forms) are allowed in cast lines. Brackets must balance.
static func _is_bbcode_safe(line: String) -> bool:
	if line.count("[") != line.count("]"):
		return false
	var regex := RegEx.new()
	regex.compile("\\[/?([a-z_]+)(=[^\\]]+)?\\]")
	for tag_match in regex.search_all(line):
		var tag: String = tag_match.get_string(1)
		if tag not in ["color", "shake", "b", "i"]:
			return false
	return true
