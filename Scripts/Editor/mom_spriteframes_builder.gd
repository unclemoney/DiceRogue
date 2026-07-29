extends RefCounted

## mom_spriteframes_builder.gd
##
## Build logic for Mom's portrait SpriteFrames, shared by the editor tool
## (build_mom_spriteframes.gd, run from the Script editor) and the CLI
## runner (_run_mom_spriteframes_build.gd). Kept in a plain RefCounted
## because EditorScript can only be instantiated inside the editor.
##
## Slices the 10 Mom portrait sheets (Resources/Art/Characters/Mom/NEW/,
## each 1024x128 = 8 frames of 128x128 in a horizontal strip) into:
##   res://Resources/Art/Characters/Mom/mom_portrait_frames.tres

const SHEET_DIR := "res://Resources/Art/Characters/Mom/NEW/"
const OUTPUT_PATH := "res://Resources/Art/Characters/Mom/mom_portrait_frames.tres"
const FRAME_SIZE := Vector2i(128, 128)

## clip_name -> {sheet, fps, loop}
## Reactions are one-shots (loop = false); idle and speech loop.
const CLIP_TABLE := {
	"idle": {"sheet": "mom_still.png", "fps": 6.0, "loop": true},
	"blink": {"sheet": "mom_blink.png", "fps": 12.0, "loop": false},
	"shakehead": {"sheet": "mom_shakehead.png", "fps": 12.0, "loop": false},
	"eyeroll": {"sheet": "mom_eyeroll.png", "fps": 12.0, "loop": false},
	"glare": {"sheet": "mom_glare.png", "fps": 12.0, "loop": false},
	"angryshake": {"sheet": "mom_angryshake.png", "fps": 12.0, "loop": false},
	"laugh": {"sheet": "mom_laugh.png", "fps": 12.0, "loop": false},
	"speech_happy": {"sheet": "mom_happyspeech.png", "fps": 10.0, "loop": true},
	"speech_normal": {"sheet": "mom_normalspeech.png", "fps": 10.0, "loop": true},
	"speech_angry": {"sheet": "mom_angryspeech.png", "fps": 10.0, "loop": true},
}


## build() -> bool
##
## Generates the SpriteFrames .tres from the sheets.
## Returns: bool - true when the resource was written successfully
static func build() -> bool:
	print("[MomSpriteFramesBuilder] Building %s" % OUTPUT_PATH)
	var frames := SpriteFrames.new()
	# SpriteFrames starts with a "default" animation - drop it
	for anim in frames.get_animation_names():
		frames.remove_animation(anim)

	var failed := false
	for clip_name in CLIP_TABLE:
		var def: Dictionary = CLIP_TABLE[clip_name]
		var sheet_path: String = SHEET_DIR + def["sheet"]
		var sheet := load(sheet_path) as Texture2D
		if not sheet:
			push_error("[MomSpriteFramesBuilder] Could not load sheet: " + sheet_path)
			failed = true
			continue
		if sheet.get_height() != FRAME_SIZE.y:
			push_error("[MomSpriteFramesBuilder] Unexpected sheet height %d in %s" % [sheet.get_height(), sheet_path])
			failed = true
			continue

		frames.add_animation(clip_name)
		frames.set_animation_speed(clip_name, def["fps"])
		frames.set_animation_loop(clip_name, def["loop"])

		var frame_count := int(sheet.get_width() / FRAME_SIZE.x)
		for i in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(clip_name, atlas)
		print("[MomSpriteFramesBuilder]   %s: %d frames @ %s fps, loop=%s" % [clip_name, frame_count, def["fps"], def["loop"]])

	if failed:
		push_error("[MomSpriteFramesBuilder] Aborted - fix sheet errors above")
		return false

	var err := ResourceSaver.save(frames, OUTPUT_PATH)
	if err != OK:
		push_error("[MomSpriteFramesBuilder] ResourceSaver failed: %s" % error_string(err))
		return false
	print("[MomSpriteFramesBuilder] Done - %d clips written" % CLIP_TABLE.size())
	return true
