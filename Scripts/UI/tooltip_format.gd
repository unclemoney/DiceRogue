class_name TooltipFormat
extends RefCounted

## TooltipFormat
##
## Static bbcode producers for tooltip numbers. These are the ONLY sanctioned
## markup producers — consumers never hand-write bbcode for numbers.


## money(n) -> String
##
## Gold-colored whole dollars: "$%d". No decimals, no k-abbreviation.
static func money(n: int) -> String:
	return "[color=#ffd75e]$%d[/color]" % n


## add(n) -> String
##
## Light-green additive: "+%d".
static func add(n: int) -> String:
	return "[color=#8eff8e]+%d[/color]" % n


## mult(x) -> String
##
## Cyan multiplier: "x%.1f".
static func mult(x: float) -> String:
	return "[color=#6ee7ff]x%.1f[/color]" % x
