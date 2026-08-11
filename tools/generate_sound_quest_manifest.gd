extends Node

# ─── Sound Quest word manifest generator ───────────────────────────────────
# One-time/occasional dev tool — NOT part of the shipping game, not an
# autoload in the committed project.godot.
#
# SoundQuestState.build_word_pool() used to discover each phoneme's word
# bank at runtime via DirAccess folder enumeration. That silently breaks in
# any exported/packed build: Godot's packed-resource DirAccess enumerates
# ".import" sidecar filenames instead of the real ".png" names, so the
# extension filter never matches and every Group's word pool comes back
# empty. Fix: discover the word banks once from source (where DirAccess
# enumeration still works correctly, since it's reading the real
# filesystem) and bake the result into a checked-in JSON manifest that
# ships as a normal resource and is loaded via plain FileAccess — the same
# explicit-path loading regular gameplay already relies on successfully in
# packed builds.
#
# Re-run this whenever a phoneme's word bank changes (images added/removed
# under "SoundUp_level1_word images/"):
#   1. Temporarily add to project.godot's [autoload] section:
#        SoundQuestManifestGen="*res://tools/generate_sound_quest_manifest.gd"
#   2. Run once from a normal source checkout (real filesystem, not a
#      packed export): godot --path .
#   3. Remove the autoload line again.
#   4. Commit the updated res://sound_quest_word_manifest.json.

const OUTPUT_PATH : String = "res://sound_quest_word_manifest.json"

func _collect_letters(json_paths: Array, letters: Dictionary) -> void:
	for path in json_paths:
		if not FileAccess.file_exists(path):
			continue
		var file : FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) != TYPE_DICTIONARY:
			continue
		for rd in data.get("rounds", []):
			var ph_audio : String = rd.get("phoneme_audio", "")
			if ph_audio == "":
				continue
			letters[ph_audio.get_file().get_basename()] = true


func _ready() -> void:
	var letters : Dictionary = {}
	_collect_letters(PrepLevelProgress.sets, letters)
	_collect_letters(LevelProgress.sets, letters)

	var sorted_letters : Array = letters.keys()
	sorted_letters.sort()

	var manifest : Dictionary = {}
	for letter in sorted_letters:
		var folder : String = SoundQuestState._resolve_image_folder(letter)
		var words  : Array   = SoundQuestState._list_words_for_phoneme(folder)
		manifest[letter] = { "folder": folder, "words": words }
		print("  ", letter, " -> folder=", folder, " words=", words.size())

	var out := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(manifest, "\t"))
	out.close()

	print("MANIFEST_GEN_DONE: wrote ", sorted_letters.size(), " letters to ", OUTPUT_PATH)
	get_tree().quit()
