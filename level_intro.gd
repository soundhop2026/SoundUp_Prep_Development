extends Node2D

const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"

# Layout
const COL_L_X  : float = 50.0
const COL_R_X  : float = 666.0
const COL_W    : float = 564.0
const TOP_Y    : float = 96.0
const LINE_H   : float = 27.0

# Font sizes
const TITLE_SIZE  : int = 36
const HEADER_SIZE : int = 20
const BODY_SIZE   : int = 18

const LEVEL_DATA : Dictionary = {
	"prep": {
		"bg_color":  "#A8E063",
		"txt_color": "#4B0082",
		"title":     "Prep — Training the Ear",
		"learn":     "Get your ears ready for English sounds —\nthe 21 consonant sounds, before any reading begins.",
		"matters":   "A strong ear is the foundation for everything ahead.",
		"sets_hdr":  "Sets  (6 groups)",
		"sets":      "A — m  s  t  b  v  k\nB — n  f  p  d  g  j\nC — h  w  y  l  z  r\nD — contrast pairs\nE — q  x  w  s  k\nF — all sounds mixed",
		"how_hdr":   "How to play",
		"how":       "Listen as each sound plays, then hear each picture.\nTap the picture that starts with the sound you heard.",
		"rc":        "Round cubes  —  fade away one by one as you play.",
		"sc":        "Set cubes  —  earned between sets.",
	},
	"level1": {
		"bg_color":  "#6EB5FF",
		"txt_color": "#4B0082",
		"title":     "Level 1 — Consonant Isolation",
		"learn":     "Hear a single consonant sound and\nfind the picture that matches it.",
		"matters":   "Recognizing each sound on its own\nbuilds the ear for reading words later.",
		"sets_hdr":  "Sets  (7 groups)",
		"sets":      "A — m  s  t  b  k  v\nB — n  f  p  d  g  j\nC — h  w  y  l  z  r\nD — contrast pairs\nE — c-soft  g-soft  x  q\nF — all 21 mixed\nG — ending sounds",
		"how_hdr":   "How to play",
		"how":       "Tap the LISTEN bar, hear the sound, and think.\nFind the picture that matches — on your own.\nWrong? \"Oops, try again\" — start the round over.",
		"rc":        "Round cubes  —  fade away one by one as you play.",
		"sc":        "Set cubes  —  earned between sets.",
	},
	"level2": {
		"bg_color":  "#8DB33A",
		"txt_color": "#4B0082",
		"title":     "Level 2 — Short Vowels",
		"learn":     "Short vowel sounds hide inside words —\na, i, o, u, and e.\nFind the vowel. Then carry it to its word.",
		"matters":   "Every word has a vowel at its heart.\nHearing short vowels unlocks reading.",
		"sets_hdr":  "Sets  (2 modes, 12 total)",
		"sets":      "A–H — hear the word, find its vowel\nI–L — hear the vowel, find its word",
		"how_hdr":   "How to play",
		"how":       "Listen to the word — find the vowel sound hiding inside.\nTap the cube at the right spot in the word.\nIn Sets I–L: hear the vowel, then drag\nthe cube to the matching picture.",
		"rc":        "Round cubes  —  fade away one by one as you play.",
		"sc":        "Set cubes  —  earned between sets.",
	},
	"level15": {
		"bg_color":  "#A83A22",
		"txt_color": "#EDE4D3",
		"title":     "Level 1.5 — Sounds Inside Words",
		"learn":     "Hear where sounds live inside words —\nat the start and at the end.\nThen build words, sound by sound.",
		"matters":   "Breaking words into their sounds trains the ear\nfor spelling and reading — not just sounds alone.",
		"sets_hdr":  "Sets  (6 groups, 13 total)",
		"sets":      "A — initial sound identification\nB — final sound identification\nC — initial sound isolation\nD — final sound isolation\nE — build the word\nF — count the sounds",
		"how_hdr":   "How to play",
		"how":       "Tap the picture that shares the matching sound.\nIn Build the Word — drag each sound into place.\nIn Sound Count — tap how many sounds you hear.",
		"rc":        "Round cubes  —  fade away one by one as you play.",
		"sc":        "Set cubes  —  earned between sets.",
	},
}

var _font      : Font   = null
var _ready_btn : Button = null
var _pulse     : Tween  = null

func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	var lid : String = LevelIntroState.level_id
	if not LEVEL_DATA.has(lid):
		lid = "prep"
	var d : Dictionary = LEVEL_DATA[lid]

	var bg_col  : Color = Color(d["bg_color"])
	var txt_col : Color = Color(d["txt_color"])
	SceneBackground.set_color(bg_col)

	# Background
	var bg := ColorRect.new()
	bg.color        = bg_col
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Title — centered
	_make_label(d["title"], Vector2(0, 22), Vector2(1280, 52),
		TITLE_SIZE, txt_col, HORIZONTAL_ALIGNMENT_CENTER)

	# Thin divider
	var div := ColorRect.new()
	div.color    = Color(txt_col.r, txt_col.g, txt_col.b, 0.22)
	div.size     = Vector2(1200, 2)
	div.position = Vector2(40, 80)
	add_child(div)

	# ── Left column ──────────────────────────────────────────
	var y : float = TOP_Y

	y = _section("What you'll learn", d["learn"],  COL_L_X, y, txt_col)
	y += 12.0
	y = _section("Why it matters",    d["matters"], COL_L_X, y, txt_col)
	y += 12.0
	_make_label(d["sets_hdr"], Vector2(COL_L_X, y), Vector2(COL_W, LINE_H),
		HEADER_SIZE, txt_col)
	y += LINE_H
	_make_label(d["sets"], Vector2(COL_L_X + 20, y), Vector2(COL_W, 220),
		BODY_SIZE, txt_col)

	# ── Right column ─────────────────────────────────────────
	y = TOP_Y
	_make_label(d["how_hdr"], Vector2(COL_R_X, y), Vector2(COL_W, LINE_H),
		HEADER_SIZE, txt_col)
	y += LINE_H
	var how_lines : int = d["how"].count("\n") + 1
	_make_label(d["how"], Vector2(COL_R_X + 20, y), Vector2(COL_W, 140),
		BODY_SIZE, txt_col)
	y += how_lines * LINE_H + 30.0

	_make_label(d["rc"], Vector2(COL_R_X, y), Vector2(COL_W, LINE_H + 6),
		BODY_SIZE, txt_col)
	y += LINE_H + 14.0
	_make_label(d["sc"], Vector2(COL_R_X, y), Vector2(COL_W, LINE_H + 6),
		BODY_SIZE, txt_col)

	# ── Ready to Play button ──────────────────────────────────
	_build_ready_btn(txt_col, bg_col, lid)


func _section(header: String, body: String, x: float, y: float, col: Color) -> float:
	_make_label(header, Vector2(x, y), Vector2(COL_W, LINE_H), HEADER_SIZE, col)
	var lines : int = body.count("\n") + 1
	_make_label(body, Vector2(x + 20, y + LINE_H), Vector2(COL_W, lines * LINE_H + 8),
		BODY_SIZE, col)
	return y + LINE_H + lines * LINE_H


func _make_label(text: String, pos: Vector2, sz: Vector2, fsize: int, col: Color,
		halign: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.position             = pos
	lbl.size                 = sz
	lbl.horizontal_alignment = halign
	lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	if _font:
		lbl.add_theme_font_override("font", _font)
	add_child(lbl)


func _build_ready_btn(txt_col: Color, bg_col: Color, lid: String) -> void:
	const BTN_W : float = 300.0
	const BTN_H : float =  56.0
	const RADIUS : int  =  20

	_ready_btn              = Button.new()
	_ready_btn.text         = "Ready to Play"
	_ready_btn.size         = Vector2(BTN_W, BTN_H)
	_ready_btn.position     = Vector2((1280 - BTN_W) * 0.5, 644.0)
	_ready_btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)
	_ready_btn.z_index      = 5

	if _font:
		_ready_btn.add_theme_font_override("font", _font)
	_ready_btn.add_theme_font_size_override("font_size", 28)
	_ready_btn.add_theme_color_override("font_color",         bg_col)
	_ready_btn.add_theme_color_override("font_hover_color",   bg_col)
	_ready_btn.add_theme_color_override("font_pressed_color", bg_col)
	_ready_btn.add_theme_color_override("font_focus_color",   bg_col)

	var style := StyleBoxFlat.new()
	style.bg_color                   = txt_col
	style.corner_radius_top_left     = RADIUS
	style.corner_radius_top_right    = RADIUS
	style.corner_radius_bottom_left  = RADIUS
	style.corner_radius_bottom_right = RADIUS
	style.content_margin_left        = 20.0
	style.content_margin_right       = 20.0
	style.content_margin_top         = 10.0
	style.content_margin_bottom      = 10.0
	_ready_btn.add_theme_stylebox_override("normal",  style)
	_ready_btn.add_theme_stylebox_override("hover",   style)
	_ready_btn.add_theme_stylebox_override("pressed", style)
	_ready_btn.add_theme_stylebox_override("focus",   style)

	_ready_btn.pressed.connect(_on_ready_pressed.bind(lid))
	add_child(_ready_btn)

	_pulse = create_tween().set_loops()
	_pulse.tween_property(_ready_btn, "scale", Vector2(1.06, 1.06), 0.55) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_ready_btn, "scale", Vector2(1.0,  1.0),  0.55) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _on_ready_pressed(lid: String) -> void:
	if _pulse:
		_pulse.kill()
	_ready_btn.disabled = true
	match lid:
		"prep":
			PrepLevelProgress.load_from_save()
			get_tree().change_scene_to_file("res://prep_game.tscn")
		"level1":
			LevelProgress.current_index = 0
			get_tree().change_scene_to_file("res://game.tscn")
		"level15":
			Level15Progress.current_index = 0
			get_tree().change_scene_to_file("res://game15.tscn")
		"level2":
			Level2Progress.current_index = 0
			get_tree().change_scene_to_file("res://game2.tscn")
