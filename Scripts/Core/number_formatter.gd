extends Node

## NumberFormatter
##
## Autoload singleton for formatting integers across the entire game UI.
## All integers get comma separators (1,115). Values >= 100,000,000 switch
## to configurable large-number notation: metric suffixes (1.5B) or
## scientific notation (1.5e8). Toggle via `format_mode` property.

enum FormatMode {
	METRIC_SUFFIXES,
	SCIENTIFIC_NOTATION,
}

## Active notation mode for values >= SCIENTIFIC_THRESHOLD.
## Default is metric suffixes for readability.
var format_mode: FormatMode = FormatMode.METRIC_SUFFIXES

const SCIENTIFIC_THRESHOLD := 100_000_000

const METRIC_SUFFIXES := [
	"", "K", "M", "B", "T",
	"Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"
]


## format_int(value)
##
## Formats an integer with comma separators. For |value| >= SCIENTIFIC_THRESHOLD,
## uses the active `format_mode` (metric suffixes or scientific notation).
## Negative values are preserved.
func format_int(value: int) -> String:
	if value == 0:
		return "0"

	var negative := value < 0
	var abs_val := absi(value)

	if abs_val >= SCIENTIFIC_THRESHOLD:
		if format_mode == FormatMode.SCIENTIFIC_NOTATION:
			return ("-" if negative else "") + _format_large_scientific(abs_val)
		else:
			return ("-" if negative else "") + _format_large_metric(abs_val)

	return ("-" if negative else "") + _add_commas(str(abs_val))


## format_money(value)
##
## Returns "$" + `format_int(value)`.
func format_money(value: int) -> String:
	return "$" + format_int(value)


## format_score(value)
##
## Alias for `format_int`. Use for semantic clarity in scoring contexts.
func format_score(value: int) -> String:
	return format_int(value)


## format_with_commas(value)
##
## Comma-separated only. Never falls back to large-number notation,
## even for values >= SCIENTIFIC_THRESHOLD.
func format_with_commas(value: int) -> String:
	if value == 0:
		return "0"
	var negative := value < 0
	var abs_val := absi(value)
	return ("-" if negative else "") + _add_commas(str(abs_val))


## _add_commas(s)
##
## Inserts commas every 3 digits from the right. Assumes `s` is a string
## of digits with no sign.
func _add_commas(s: String) -> String:
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


## _format_large_metric(value)
##
## Formats a large positive integer using metric suffixes.
## Examples: 100000000 -> "100.0M", 1500000000 -> "1.5B"
func _format_large_metric(value: int) -> String:
	var magnitude := 0
	var scaled := float(value)
	while scaled >= 1000.0 and magnitude < METRIC_SUFFIXES.size() - 1:
		scaled /= 1000.0
		magnitude += 1

	var suffix: String = METRIC_SUFFIXES[magnitude]

	# One decimal place, strip trailing .0 for cleaner display
	var formatted := "%.1f" % scaled
	if formatted.ends_with(".0"):
		formatted = formatted.substr(0, formatted.length() - 2)

	return formatted + suffix


## _format_large_scientific(value)
##
## Formats a large positive integer using scientific notation.
## Examples: 100000000 -> "1.0e8", 1500000000 -> "1.5e9"
func _format_large_scientific(value: int) -> String:
	var exponent := 0
	var mantissa := float(value)
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1

	var formatted := "%.1f" % mantissa
	if formatted.ends_with(".0"):
		formatted = formatted.substr(0, formatted.length() - 2)

	return formatted + "e" + str(exponent)
