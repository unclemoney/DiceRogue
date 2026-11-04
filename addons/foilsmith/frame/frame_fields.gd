@tool
class_name FoilsmithFields
extends RefCounted
## The frame's fields, as the web app shows them (web/src/lib/frames.ts, FrameForm.tsx): one table
## for the card base, the colours and each kind of component. The frame nodes build their
## Inspector from these, and write and read the same JSON as the web app and the CLI.
##
## A field: `p` the property (named after the web app's label), `k` the JSON key, `t` its type,
## `d` the spec's default (what a frame without the key gets), `s` what a new node starts with
## (default `d`), and for numbers `min`, `max`, `step` and `scale` (the Inspector shows the JSON
## value times `scale`: percent of the card). Types:
## `num`, `opt` (a number or auto: -1 in the Inspector, no key in the JSON), `enum` (`o` options),
## `text`, `area` (several lines), `list` (comma list of symbols), `bool`, `color` (an override of
## the theme: transparent = the theme's), `fill` (a pair of overrides), `attacks`, `stats`.

const ALIGN := ["start", "center", "end"]
const FACES := ["title", "body", "sans", "sans-text"]
const TEXTURES := ["stock", "bands", "flat", "gloss"]

## Where a component goes in the stack (fractions shown as percent of the card).
const PLACE := [
	{ p = "height", k = "height", t = "num", d = 0.0, min = 0, max = 100, step = 0.5, scale = 100,
		tip = "Height % of the card (0 = share what's left)." },
	{ p = "space_above", k = "space_before", t = "num", d = 0.0, min = -50, max = 50, step = 0.5, scale = 100,
		tip = "Space above, % of the card (negative overlaps the component before). In a row: space to the left." },
	{ p = "width", k = "width", t = "num", d = 0.0, min = 0, max = 100, step = 1, scale = 100,
		tip = "Width % of the space (0 = all of it, or share what's left in a row)." },
	{ p = "align", k = "align", t = "enum", o = ALIGN, d = "center", tip = "Where a narrower component sits." },
	{ p = "foil", k = "foil", t = "enum", o = ["auto", "none", "border", "full"], d = "auto", tip = "What takes the foil finish." },
]

const KINDS := {
	"art": {
		label = "Art window",
		start = { height = 0.3 },
		fields = [
			{ p = "corner_radius", k = "radius", t = "num", d = 3.0, min = 0, max = 60, step = 1 },
			{ p = "trim", k = "trim", t = "enum", o = ["none", "ink", "gold", "bevel", "gloss"], d = "ink" },
		],
	},
	"bar": {
		label = "Bar",
		start = { height = 0.05, text = "Title", size = 24.0 },
		fields = [
			{ p = "style", k = "style", t = "enum", o = ["bevel", "plain", "pill", "metal", "band", "plate", "gloss"], d = "bevel" },
			{ p = "text", k = "text", t = "text", d = "" },
			{ p = "second_line", k = "sub", t = "text", d = "" },
			{ p = "text_at_the_end", k = "end", t = "text", d = "" },
			{ p = "caption_before_it", k = "end_label", t = "text", d = "" },
			{ p = "symbols", k = "symbols", t = "list", d = [], tip = "W, U, 2, grass, attr-light…" },
			{ p = "symbol_size", k = "symbol_size", t = "num", d = 12.0, min = 6, max = 30, step = 1 },
			{ p = "symbol_gap", k = "symbol_gap", t = "num", d = 4.0, min = 0, max = 30, step = 1 },
			{ p = "font_style", k = "face", t = "enum", o = FACES, d = "title" },
			{ p = "text_size", k = "size", t = "opt", d = null, min = 8, max = 80, step = 1 },
			{ p = "end_text_size", k = "end_size", t = "opt", d = null, min = 8, max = 80, step = 1 },
			{ p = "caption_size", k = "end_label_size", t = "num", d = 20.0, min = 6, max = 60, step = 1 },
			{ p = "inner_padding", k = "pad", t = "opt", d = null, min = 0, max = 80, step = 1 },
			{ p = "text_align", k = "text_align", t = "enum", o = ALIGN, d = "start" },
			{ p = "corner_radius", k = "radius", t = "num", d = 10.0, min = 0, max = 40, step = 1 },
			{ p = "fill", k = "fill", t = "fill", d = null },
			{ p = "text_colour", k = "ink", t = "color", d = null },
		],
	},
	"text": {
		label = "Text box",
		start = { height = 0.2, body = "Text", panel = "box" },
		fields = [
			{ p = "panel", k = "panel", t = "enum", o = ["none", "box", "bevel", "tint", "gloss"], d = "box" },
			{ p = "header", k = "header", t = "text", d = "" },
			{ p = "text", k = "body", t = "area", d = "" },
			{ p = "flavour", k = "secondary", t = "area", d = "" },
			{ p = "footer", k = "footer", t = "text", d = "", tip = "Footer (right)." },
			{ p = "font_style", k = "face", t = "enum", o = FACES, d = "body" },
			{ p = "text_size", k = "size", t = "opt", d = null, min = 8, max = 60, step = 0.5 },
			{ p = "vertical_align", k = "valign", t = "enum", o = ["top", "center", "bottom"], d = "top" },
			{ p = "italic_text", k = "italic", t = "bool", d = false },
			{ p = "italic_flavour", k = "secondary_italic", t = "bool", d = true },
			{ p = "line_height", k = "line_height", t = "num", d = 1.3, min = 0.8, max = 2.5, step = 0.05 },
			{ p = "header_size", k = "header_size", t = "num", d = 21.0, min = 8, max = 60, step = 0.5 },
			{ p = "footer_size", k = "footer_size", t = "num", d = 21.0, min = 8, max = 60, step = 0.5 },
			{ p = "corner_radius", k = "radius", t = "num", d = 6.0, min = 0, max = 40, step = 1 },
			{ p = "fill", k = "fill", t = "fill", d = null },
			{ p = "text_colour", k = "ink", t = "color", d = null },
		],
	},
	"symbols": {
		label = "Symbols",
		start = { height = 0.04, items = ["star*3"], justify = "end" },
		fields = [
			{ p = "symbols", k = "items", t = "list", d = [], tip = "star*4, W, grass…" },
			{ p = "symbol_size", k = "size", t = "num", d = 13.0, min = 6, max = 30, step = 1 },
			{ p = "gap", k = "gap", t = "num", d = 4.0, min = 0, max = 30, step = 1 },
			{ p = "symbols_sit", k = "justify", t = "enum", o = ALIGN, d = "start" },
		],
	},
	"attacks": {
		label = "Attacks",
		start = { height = 0.2, items = [{ cost = ["grass"], name = "Attack", damage = "10", text = "" }] },
		fields = [
			{ p = "attacks", k = "items", t = "attacks", d = [] },
			{ p = "cost_symbol_size", k = "cost_size", t = "num", d = 15.0, min = 6, max = 40, step = 1 },
			{ p = "name_size", k = "name_size", t = "num", d = 34.0, min = 8, max = 80, step = 1 },
			{ p = "damage_size", k = "damage_size", t = "num", d = 42.0, min = 8, max = 80, step = 1 },
			{ p = "text_size", k = "text_size", t = "num", d = 22.0, min = 8, max = 60, step = 0.5 },
		],
	},
	"stats": {
		label = "Stat columns",
		start = { height = 0.06, items = [{ label = "weakness", symbol = "fire", count = 1, value = "x2" }] },
		fields = [
			{ p = "columns", k = "items", t = "stats", d = [] },
			{ p = "rule_above", k = "rule", t = "bool", d = true },
			{ p = "label_size", k = "label_size", t = "num", d = 18.0, min = 6, max = 40, step = 0.5 },
			{ p = "value_size", k = "value_size", t = "num", d = 22.0, min = 6, max = 60, step = 0.5 },
			{ p = "symbol_size", k = "symbol_size", t = "num", d = 12.0, min = 6, max = 30, step = 1 },
		],
	},
	"spacer": { label = "Spacer", start = { height = 0.02 }, fields = [] },
	"row": { label = "Row", start = { height = 0.1 }, fields = [] },
}

## The card base (`base` in the JSON). `painted_body` turns `body` on (`{}`) or off (null).
const BASE := [
	{ p = "corner_radius", k = "corner", t = "num", d = 0.04, min = 0, max = 20, step = 0.5, scale = 100, tip = "Corner radius, % of the card's width." },
	{ p = "border_width", k = "border", t = "num", d = 0.0, min = 0, max = 20, step = 0.5, scale = 100, tip = "Border width, % of the card's width." },
	{ p = "padding", k = "padding", t = "num", d = 0.0, min = 0, max = 20, step = 0.5, scale = 100, tip = "Padding inside the border, % of the card's width." },
	{ p = "border_foil", k = "border_foil", t = "num", d = 0.0, min = 0, max = 1, step = 0.05 },
	{ p = "border_texture", k = "border_texture", t = "enum", o = TEXTURES, d = "stock" },
	{ p = "dark_rim", k = "lip", t = "num", d = 0.0, min = 0, max = 10, step = 0.5, scale = 100, tip = "Dark rim, %." },
	{ p = "grain_seed", k = "seed", t = "num", d = 2.0, min = 0, max = 99, step = 1, int = true },
	{ p = "print_id", k = "print_id", t = "text", d = "", tip = "Print / edition ID." },
	{ p = "print_id_position", k = "print_id_align", t = "enum", o = ALIGN, d = "start" },
	{ p = "print_id_size", k = "print_id_size", t = "num", d = 17.0, min = 6, max = 40, step = 0.5 },
]
const BODY := [
	{ p = "body_corner_radius", k = "radius", t = "num", d = 10.0, min = 0, max = 60, step = 1 },
	{ p = "body_foil", k = "foil", t = "num", d = 0.25, min = 0, max = 1, step = 0.05 },
	{ p = "body_texture", k = "texture", t = "enum", o = TEXTURES, d = "stock" },
]

## The colours (`theme`), by role: `pair` roles are a gradient or a pair of stock tones.
const THEME := [
	{ k = "border", p = "border", pair = true },
	{ k = "body", p = "body", pair = true },
	{ k = "bar", p = "bars", pair = true },
	{ k = "panel", p = "text_panels", pair = true },
	{ k = "accent", p = "metal_trim", pair = true },
	{ k = "ink", p = "ink", pair = false },
	{ k = "outline", p = "outlines", pair = false },
	{ k = "muted", p = "flavour_text", pair = false },
	{ k = "light", p = "text_on_dark", pair = false },
	{ k = "line", p = "rules", pair = false },
]
## Rust's Theme::default() (crates/frames/src/spec.rs): what a frame without a theme is drawn with.
const DEFAULT_THEME := {
	"border": ["#080f27", "#335f99"], "body": ["#6b8ca8", "#9ebdd1"], "bar": ["#e6edf2", "#b3c7d9"],
	"panel": ["#dce3e6", "#f2f5f5"], "accent": ["#d9a640", "#d9a640"], "ink": "#120f14",
	"outline": "#120f14", "muted": "#40475a", "light": "#fff2d1", "line": "#120f14",
}

## The text fields of each kind, blanked in a template (as the web app's toTemplate).
const TEXT_KEYS := { "bar": ["text", "sub", "end"], "text": ["header", "body", "secondary", "footer"] }


## The Inspector entry for a field, under its group.
static func property(f: Dictionary) -> Dictionary:
	var prop := { name = f.p, usage = PROPERTY_USAGE_DEFAULT }
	match f.t:
		"num", "opt":
			prop.type = TYPE_INT if f.get("int", false) else TYPE_FLOAT
			var lo: float = -1 if f.t == "opt" else f.min
			var hint := "%s,%s,%s" % [lo, f.max, f.step]
			if f.get("scale", 1) == 100:
				hint += ",suffix:%"
			prop.hint = PROPERTY_HINT_RANGE
			prop.hint_string = hint
		"enum":
			prop.type = TYPE_STRING
			prop.hint = PROPERTY_HINT_ENUM
			prop.hint_string = ",".join(f.o)
		"text":
			prop.type = TYPE_STRING
		"area":
			prop.type = TYPE_STRING
			prop.hint = PROPERTY_HINT_MULTILINE_TEXT
		"list":
			prop.type = TYPE_PACKED_STRING_ARRAY
		"bool":
			prop.type = TYPE_BOOL
		"color":
			prop.type = TYPE_COLOR
		"attacks":
			prop.type = TYPE_ARRAY
			prop.hint = PROPERTY_HINT_TYPE_STRING
			prop.hint_string = "%d/%d:FoilsmithAttack" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE]
		"stats":
			prop.type = TYPE_ARRAY
			prop.hint = PROPERTY_HINT_TYPE_STRING
			prop.hint_string = "%d/%d:FoilsmithStat" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE]
	return prop


## A field's Inspector value for a JSON value (null: the spec's default).
static func to_inspector(f: Dictionary, v: Variant) -> Variant:
	if v == null:
		v = f.d
	match f.t:
		"num":
			var x: float = snappedf(float(v) * f.get("scale", 1), 0.0001)
			return int(round(x)) if f.get("int", false) else x
		"opt":
			return -1.0 if v == null else float(v)
		"enum", "text", "area":
			return str(v)
		"list":
			return PackedStringArray(v)
		"bool":
			return bool(v)
		"color":
			return Color(0, 0, 0, 0) if v == null else Color.html(v)
		"attacks":
			var out: Array[FoilsmithAttack] = []
			for a in v:
				out.append(FoilsmithAttack.from_spec(a))
			return out
		"stats":
			var out: Array[FoilsmithStat] = []
			for s in v:
				out.append(FoilsmithStat.from_spec(s))
			return out
	return v


## A field's JSON value for an Inspector value (null: leave the key out).
static func to_json(f: Dictionary, v: Variant) -> Variant:
	match f.t:
		"num":
			var x: float = float(v) / f.get("scale", 1)
			return int(x) if f.get("int", false) else snappedf(x, 0.000001)
		"opt":
			return null if v == null or float(v) < 0 else float(v)
		"list":
			return Array(v)
		"color":
			return null if v == null or (v as Color).a == 0 else hex(v)
		"attacks", "stats":
			return (v as Array).filter(func(x): return x != null).map(func(x): return x.to_spec())
	return v


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


## The fields of a kind, with the position fields first.
static func fields_of(kind: String) -> Array:
	return PLACE + KINDS[kind].fields


## A fill pair's two Inspector properties.
static func fill_props(f: Dictionary) -> Array[String]:
	return [f.p + "_top", f.p + "_bottom"]
