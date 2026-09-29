class_name UIFonts

# ─── SoundHop shared font system ────────────────────────────────────────────
# Implementation only. The rules — which role each part of the UI takes, and
# why — live in SOUNDHOP_UI_FONT_FRAMEWORK.md. Read that before assigning a
# face to anything; this file just resolves the five roles to real files.
#
#   character()      Schoolbell Regular       character / logo TEXT
#   learning()       Andika Regular           information content
#   learning_bold()  Andika Bold              information structure
#   action()         JetBrains Mono Regular   action / transaction
#   action_bold()    JetBrains Mono Bold      emphasised action
#
# Two things worth knowing at the call site:
#   - Original hand-drawn SOUNDHOP artwork is NOT a font decision and must not
#     be rebuilt in Schoolbell (framework doc §1).
#   - Bold roles resolve to real Bold files. Never synthesize bold.
#
# Every existing call site guards with `if _font:`, so a failed load would show
# the engine default silently — hence the push_error below.
#
# Kept free of project-specific references so it can be copied to Game 2
# verbatim; only the asset paths need to exist there.

const CHARACTER_PATH     : String = "res://UI_assets/Schoolbell/Schoolbell-Regular.ttf"
const LEARNING_PATH      : String = "res://UI_assets/Andika/Andika-Regular.ttf"
const LEARNING_BOLD_PATH : String = "res://UI_assets/Andika/Andika-Bold.ttf"
const ACTION_PATH        : String = "res://UI_assets/JetBrainsMono/JetBrainsMono-Regular.ttf"
const ACTION_BOLD_PATH   : String = "res://UI_assets/JetBrainsMono/JetBrainsMono-Bold.ttf"

static var _cache : Dictionary = {}

# Returns null when the font is missing or not yet imported, matching what
# every existing `if _font:` call site already expects.
# Named _load_font, not _get: _get(StringName) -> Variant is an Object virtual,
# and overriding it with a different signature fails to compile the whole file.
static func _load_font(path: String) -> Font:
	if _cache.has(path):
		return _cache[path]
	var f : Font = null
	if ResourceLoader.exists(path):
		f = load(path) as Font
	else:
		push_error("UIFonts: missing font '%s' (not imported?)" % path)
	_cache[path] = f
	return f


static func character() -> Font:
	return _load_font(CHARACTER_PATH)


static func learning() -> Font:
	return _load_font(LEARNING_PATH)


static func learning_bold() -> Font:
	return _load_font(LEARNING_BOLD_PATH)


static func action() -> Font:
	return _load_font(ACTION_PATH)


static func action_bold() -> Font:
	return _load_font(ACTION_BOLD_PATH)
