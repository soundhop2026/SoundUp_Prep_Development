extends Node

# ─── Sound Quest resource check against an EXPORTED package ─────────────────────
# Regression test for the Android-only "invisible Sound Quest images" defect: a res:// path whose
# case differs from the real file resolves on Windows/macOS but not in an exported .pck (or on
# Android), where the lookup is case-sensitive. Run it against a real export so it follows the
# same lookup rules as the device. Developer tool, not part of gameplay.
#
#   1. Export a PCK (any preset; the project has no export filter):
#        godot --headless --path . --export-pack "Android APK (testing)" /tmp/soundquest_check.pck
#   2. Run this script against the PACK, not the source folder:
#        godot --headless --main-pack /tmp/soundquest_check.pck res://tools/verify_sound_quest_resources.tscn
#
# It builds the real Sound Quest word pools through SoundQuestState.build_word_pool() for every
# Prep and Level 1 Group (the code path the game uses) and checks that every image, word audio
# and phoneme audio loads, then does the same for every Level 1.5 word and the fixed assets.
# Exit code 0 = clean, 1 = problems (each is printed as "FAIL ...").
#
# tools/audit_sound_quest_resources.py is the same audit against the source tree (no Godot needed).

const FIXED_ASSETS : Array = [
	"res://BGM&effect/SoundUp_feedback/gayageum_correct.wav",
	"res://UI_assets/flag.png",
	"res://UI_assets/handsigns/pointed.png",
	"res://UI_assets/playbutton.png",
	"res://louisfaces/happylouis3-Photoroom.png",
	"res://soundquest/assets/bubble_level15_soundquest_C_D.png",
	"res://soundquest/assets/drop_zone_level15_soundquest_F.png",
	"res://soundquest/assets/ladder_frame_level15_soundquest_E.png",
	"res://soundquest/assets/ladder_rung_level15_soundquest_E.png",
	"res://soundquest/assets/phoneme_bin_level1_soundquest.png.png",
	"res://soundquest/assets/playbutton_level15_soundquest_F_bleh.wav",
	"res://soundquest/assets/playbutton_level15_soundquest_F_nom.wav",
	"res://soundquest/assets/quest_level15_bgm.mp3",
	"res://soundquest/assets/quest_level1_bgm.mp3",
	"res://soundquest/assets/quest_preplevel_bgm.mp3",
]

var _checks : int = 0
var _fails  : int = 0


func _check(path: String, what: String) -> void:
	_checks += 1
	if path == "":
		_fails += 1
		print("FAIL  (empty path)  ", what)
		return
	if not ResourceLoader.exists(path):
		_fails += 1
		print("FAIL  not found in the package: ", path, "  [", what, "]")
		return
	if load(path) == null:
		_fails += 1
		print("FAIL  found but did not load: ", path, "  [", what, "]")


func _group_ranges(boundaries: Array) -> Array:
	var ranges : Array = []
	var start : int = 0
	for b in boundaries:
		ranges.append(Vector2i(start, b))
		start = b + 1
	return ranges


func _check_pools(label: String, sets: Array, boundaries: Array) -> void:
	var group : int = 0
	for r in _group_ranges(boundaries):
		var pool : Array = SoundQuestState.build_word_pool(sets.slice(r.x, r.y + 1))
		if pool.is_empty():
			_fails += 1
			print("FAIL  ", label, " group ", group, " has an EMPTY word pool")
		for w in pool:
			_check(w.get("image", ""), label + " group " + str(group) + " word image")
			_check(w.get("word_audio", ""), label + " group " + str(group) + " word audio")
			_check(w.get("phoneme_audio", ""), label + " group " + str(group) + " phoneme audio")
		print("  ", label, " group ", group, " (sets ", r.x, "-", r.y, "): ", pool.size(), " words checked")
		group += 1


func _ready() -> void:
	print("Sound Quest package resource check")
	_check_pools("Prep", PrepLevelProgress.sets, PrepLevelProgress.MAIN_SET_BOUNDARIES)
	_check_pools("Level 1", LevelProgress.sets, LevelProgress.MAIN_SET_BOUNDARIES)

	var words : Dictionary = Level15SoundQuestState.load_words()
	for key in words.keys():
		_check("res://SoundUp_level1.5_word_images/" + String(key) + ".png", "Level 1.5 word image")
		_check("res://BGM&effect/SoundUp_level1.5_word_sounds/" + String(key) + ".wav", "Level 1.5 word audio")
	print("  Level 1.5: ", words.size(), " words checked")

	for p in FIXED_ASSETS:
		_check(p, "fixed Sound Quest asset")
	print("  fixed assets: ", FIXED_ASSETS.size(), " checked")

	print("VERIFY_RESULT checks=", _checks, " fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)
