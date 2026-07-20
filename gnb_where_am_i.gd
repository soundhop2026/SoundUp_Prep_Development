extends Node2D

# ─── Colors ───────────────────────────────────────────────────────────────────
const PURPLE     : Color = Color("#4B0082")
const PURPLE_TINT: Color = Color("#E8DCF5")   # selected Set Group tile
const AMBER      : Color = Color("#FFB703")
const CREAM      : Color = Color("#EDE4D3")
const WHITE      : Color = Color("#FFFFFF")
const D_AMBER    : Color = Color("#B8631A")   # completed level header
const GRAY_H     : Color = Color("#AAAAAA")   # in-progress / locked header
const BROWN      : Color = Color("#7A5A2A")   # phoneme text

const FONT_PATH  : String = "res://UI_assets/210 연필스케치R.ttf"
const LOUIS_PATH : String = "res://louisfaces/happylouis3-Photoroom.png"

# ─── Layout ───────────────────────────────────────────────────────────────────
# Symmetric: PAGE_PAD*2 + CELL_W*2 + CELL_GAP = 1280
const CELL_W       : float = 580.0
const CELL_H       : float = 68.0   # enlarged — fewer sets shown per screen now
const CELL_GAP     : float = 16.0
const PAGE_PAD     : float = 52.0   # (1280 - 580*2 - 16) / 2 = 52 — balanced margins
const ROW_STEP     : float = 76.0   # CELL_H + 8 gap
const HDR_H        : float = 46.0
const HDR_TOP      : float = 116.0  # scroll area starts here (after purple header)

# Set Group grid (Prep / Level 1 / Level 1.5)
const GRID_COLS     : int   = 3
const GRID_TILE_H   : float = 76.0
const GRID_GAP      : float = 16.0
const PANEL_CARD_H  : float = 138.0  # Set intro card height

# ─── State ────────────────────────────────────────────────────────────────────
var _font             : Font           = null
var _louis_tex        : Texture2D      = null
var _levels            : Array          = []
var _rows_containers  : Array[Control] = []
var _expanded_flags   : Array[bool]    = []

# Set Group grid + intro panel state (Prep / Level 1 / Level 1.5 only — empty
# entries for levels that stay flat, e.g. Level 2).
var _group_tiles      : Array = []   # per level: Array[Button]
var _group_panels     : Array = []   # per level: the fixed detail-panel VBoxContainer (or null)
var _selected_group    : Array[int] = []   # per level: selected tile index, -1 = none
var _group_ctx         : Array = []   # per level: { groups, done_counts, ld }

var is_overlay        : bool           = false
var _vbox             : VBoxContainer  = null
var _scroll            : ScrollContainer = null
signal close_requested

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	SceneBackground.set_color(CREAM)
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	if ResourceLoader.exists(LOUIS_PATH):
		_louis_tex = load(LOUIS_PATH)

	_build_level_meta()

	var bg := ColorRect.new()
	bg.color        = CREAM
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_header()       # purple bar: title + summary
	_build_back_button()  # overlaid on header, z_index=10
	_build_scroll_area()  # all sections start collapsed


# ─── Level metadata ───────────────────────────────────────────────────────────
func _build_level_meta() -> void:
	var prep_done  : int = 26 if SaveManager.is_prep_completed()   else SaveManager.get_prep_set_index()
	var l1_done    : int = 17 if SaveManager.is_level1_completed()  else SaveManager.get_level1_set_index()
	var l15_done   : int = 13 if SaveManager.is_level15_completed() else SaveManager.get_level15_set_index()
	var l2_done    : int = 12 if SaveManager.is_level2_completed()  else SaveManager.get_level2_set_index()

	# Curriculum order: each lock cascades — a later level can never be unlocked
	# while an earlier one is still locked.
	var l1_lock  : bool = not (SaveManager.is_prep_completed() or
		SaveManager.is_chose_level1_path() or SaveManager.get_level1_set_index() > 0)
	var l15_lock : bool = l1_lock  or not (SaveManager.is_level1_completed()  or SaveManager.get_level15_set_index() > 0)
	var l2_lock  : bool = l15_lock or not (SaveManager.is_level15_completed() or SaveManager.get_level2_set_index()  > 0)
	var l25_lock : bool = l2_lock  or not SaveManager.is_level2_completed()

	_levels = [
		{ "id": "prep",    "label": "Prep",      "done": prep_done, "total": 26,
		  "locked": false,   "sets": _prep_sets(),    "pfn": func(i): PrepLevelProgress.current_index = i,
		  "show_all": SaveManager.is_chose_level1_path(), "color": Color("#A8E063"), "txt_color": PURPLE,
		  "grouped": true, "group_meta": _prep_group_meta() },
		{ "id": "level1",  "label": "Level 1",   "done": l1_done,  "total": 17,
		  "locked": l1_lock, "sets": _level1_sets(),  "pfn": func(i): LevelProgress.current_index = i,
		  "show_all": false, "color": Color("#6EB5FF"), "txt_color": PURPLE,
		  "grouped": true, "group_meta": _level1_group_meta() },
		{ "id": "level15", "label": "Level 1.5", "done": l15_done, "total": 13,
		  "locked": l15_lock, "sets": _level15_sets(), "pfn": func(i): Level15Progress.current_index = i,
		  "show_all": false, "color": Color("#A83A22"), "txt_color": Color("#EDE4D3"),
		  "grouped": true, "group_meta": _level15_group_meta() },
		{ "id": "level2",  "label": "Level 2",   "done": l2_done,  "total": 12,
		  "locked": l2_lock, "sets": _level2_sets(),  "pfn": func(i): Level2Progress.current_index = i,
		  "show_all": false, "color": Color("#8DB33A"), "txt_color": PURPLE,
		  "grouped": false, "group_meta": {} },
		{ "id": "level25", "label": "Level 2.5", "done": 0, "total": 19,
		  "locked": l25_lock, "sets": [], "pfn": func(_i): pass,
		  "show_all": false, "color": Color("#7B68EE"), "txt_color": Color("#EDE4D3"),
		  "grouped": false, "group_meta": {} },
	]


func _prep_sets() -> Array:
	var ph : Dictionary = { "A": "m  s  t  b  v  k", "B": "n  f  p  d  g  j",
		"C": "h  w  y  l  z  r", "D": "contrast pairs", "E": "q  x  s  k",
		"F": "all sounds mixed" }
	var out : Array = []
	var labels : Array = PrepLevelProgress.set_labels
	for i in range(labels.size()):
		var lbl : String = labels[i]
		out.append({ "index": i, "label": lbl,
			"phonemes": ph.get(lbl.left(1), ""),
			"key": "prep_" + lbl,
			"scene": "res://prep_game.tscn" })
	return out


func _level1_sets() -> Array:
	var ph : Dictionary = { "A": "m  s  t  b  k  v", "B": "n  f  p  d  g  j",
		"C": "h  w  y  l  z  r", "D": "contrast pairs", "E": "c-soft  g-soft  x  q",
		"F": "all 21 mixed", "G": "ending sounds" }
	var out : Array = []
	var labels : Array = LevelProgress.set_labels
	for i in range(labels.size()):
		var lbl : String = labels[i]
		out.append({ "index": i, "label": lbl,
			"phonemes": ph.get(lbl.left(1), ""),
			"key": "level1_" + lbl,
			"scene": "res://game.tscn" })
	return out


func _level15_sets() -> Array:
	var ph : Dictionary = { "A": "initial phoneme ID", "B": "final phoneme ID",
		"C": "initial isolation", "D": "final isolation",
		"E": "build the word", "F": "sound count" }
	var out : Array = []
	var labels : Array = Level15Progress.set_labels
	for i in range(labels.size()):
		var lbl : String = labels[i]
		out.append({ "index": i, "label": lbl,
			"phonemes": ph.get(lbl.left(1), ""),
			"key": "level15_" + lbl,
			"scene": "res://game15.tscn" })
	return out


func _level2_sets() -> Array:
	var ph : Dictionary = { "A": "/a/ only", "B": "/i/ only", "C": "/a/ vs /i/",
		"D": "/o/ only", "E": "/u/ only", "F": "/o/ vs /u/",
		"G": "/e/ only", "H": "all 5 mixed",
		"I": "/a/+/e/ — hear vowel", "J": "/o/+/u/ — hear vowel",
		"K": "/i/ — hear vowel", "L": "all 5 — hear vowel" }
	var out : Array = []
	var labels : Array = Level2Progress.set_labels
	for i in range(labels.size()):
		var lbl : String = labels[i]
		var sc  : String = "res://game25.tscn" if i >= 8 else "res://game2.tscn"
		out.append({ "index": i, "label": lbl,
			"phonemes": ph.get(lbl, ""),
			"key": "level2_" + lbl,
			"scene": sc })
	return out


# ─── Set Group intro metadata (draft copy — wording TBD with product) ─────────
# Each entry: { title, goal }. "title" mirrors the existing phoneme
# summary; "goal" is new, first-pass copy to get the UI working — not final
# wording.
func _prep_group_meta() -> Dictionary:
	return {
		"A": { "title": "m  s  t  b  v  k", "goal": "Find the picture that starts with the sound." },
		"B": { "title": "n  f  p  d  g  j", "goal": "Find the picture that starts with the sound." },
		"C": { "title": "h  w  y  l  z  r", "goal": "Find the picture that starts with the sound." },
		"D": { "title": "contrast pairs",   "goal": "Tell two similar sounds apart." },
		"E": { "title": "q  x  s  k",       "goal": "Find the picture that starts with the sound." },
		"F": { "title": "all sounds mixed", "goal": "Practice every sound together." },
	}


func _level1_group_meta() -> Dictionary:
	return {
		"A": { "title": "m  s  t  b  k  v",     "goal": "Find the picture that starts with the sound." },
		"B": { "title": "n  f  p  d  g  j",     "goal": "Find the picture that starts with the sound." },
		"C": { "title": "h  w  y  l  z  r",     "goal": "Find the picture that starts with the sound." },
		"D": { "title": "contrast pairs",       "goal": "Tell two similar sounds apart." },
		"E": { "title": "c-soft  g-soft  x  q", "goal": "Find the picture that starts with the sound." },
		"F": { "title": "all 21 mixed",         "goal": "Practice every sound together." },
		"G": { "title": "ending sounds",        "goal": "Find the sound at the end of the word." },
	}


func _level15_group_meta() -> Dictionary:
	return {
		"A": { "title": "initial phoneme ID", "goal": "Find the sound at the start of the word." },
		"B": { "title": "final phoneme ID",   "goal": "Find the sound at the end of the word." },
		"C": { "title": "initial isolation",  "goal": "Pull out the very first sound in the word." },
		"D": { "title": "final isolation",    "goal": "Pull out the very last sound in the word." },
		"E": { "title": "build the word",     "goal": "Build a word one sound at a time." },
		"F": { "title": "sound count",        "goal": "Count how many sounds are in the word." },
	}


# ─── Static header (purple bar with title + summary) ──────────────────────────
func _build_header() -> void:
	var prep_done  : int = 26 if SaveManager.is_prep_completed()   else SaveManager.get_prep_set_index()
	var l1_done    : int = 17 if SaveManager.is_level1_completed()  else SaveManager.get_level1_set_index()
	var l15_done   : int = 13 if SaveManager.is_level15_completed() else SaveManager.get_level15_set_index()
	var l2_done    : int = 12 if SaveManager.is_level2_completed()  else SaveManager.get_level2_set_index()
	var total_done : int = prep_done + l1_done + l15_done + l2_done
	var cubes      : int = total_done   # 1 cube per completed set

	var level_names : Array[String] = ["Prep", "Level 1", "Level 1.5", "Level 2", "Level 2.5"]
	var cur : String = level_names[_current_level_index()]

	var vp_w : float = get_viewport_rect().size.x

	# Purple background
	var bar := ColorRect.new()
	bar.color        = PURPLE
	bar.size         = Vector2(vp_w, HDR_TOP)
	bar.position     = Vector2.ZERO
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	# "Where am I" title — offset right so back button has its own zone
	var title := Label.new()
	title.text                 = "Where am I"
	title.position             = Vector2(120, 8)
	title.size                 = Vector2(vp_w - 240, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", AMBER)
	if _font: title.add_theme_font_override("font", _font)
	add_child(title)

	# Summary line
	var summary := Label.new()
	summary.text                 = "%d sets done  ·  %d cubes  ·  now: %s" % [total_done, cubes, cur]
	summary.position             = Vector2(0, 64)
	summary.size                 = Vector2(vp_w, 40)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 16)
	summary.add_theme_color_override("font_color", AMBER)
	if _font: summary.add_theme_font_override("font", _font)
	add_child(summary)


func _build_back_button() -> void:
	var btn := TextureButton.new()
	btn.texture_normal      = load("res://UI_assets/back_button.png") as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size                = Vector2(90, 90)
	btn.position            = Vector2(16, 13)
	btn.z_index             = 10
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 c : source_color;
void fragment() { vec4 t = texture(TEXTURE, UV); COLOR = vec4(c.rgb, t.a); }"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("c", AMBER)   # amber on purple bg
	btn.material = mat
	btn.pressed.connect(_on_back_pressed)
	add_child(btn)


# ─── Scroll area ──────────────────────────────────────────────────────────────
func _build_scroll_area() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position               = Vector2(0, HDR_TOP)
	_scroll.size                   = Vector2(get_viewport_rect().size.x, get_viewport_rect().size.y - HDR_TOP)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone        = 8
	add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 0)
	_scroll.add_child(_vbox)

	for i in range(_levels.size()):
		_add_level_section(_vbox, _levels[i], i)


func _add_level_section(vbox: VBoxContainer, ld: Dictionary, li: int) -> void:
	var is_locked : bool = ld["locked"]
	var is_done   : bool = (ld["done"] >= ld["total"])
	var done_count : int = ld["done"]

	# ── Header button ──────────────────────────────────────────────────────────
	var vp_w : float = get_viewport_rect().size.x
	var hdr := Button.new()
	hdr.custom_minimum_size   = Vector2(vp_w, HDR_H)
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.clip_text             = false
	hdr.alignment             = HORIZONTAL_ALIGNMENT_LEFT

	var hdr_text  : String
	var right_txt : String

	if is_locked:
		hdr_text  = "     🔒  " + ld["label"]
		right_txt = ""
	else:
		hdr_text  = "     ▶  " + ld["label"]
		right_txt = "%d / %d%s" % [done_count, ld["total"], "  ✓" if is_done else ""]

	var hdr_col  : Color = ld["color"] if not is_locked else GRAY_H
	var txt_col  : Color = ld["txt_color"] if not is_locked else WHITE

	if _font: hdr.add_theme_font_override("font", _font)
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color",         txt_col)
	hdr.add_theme_color_override("font_hover_color",   txt_col)
	hdr.add_theme_color_override("font_pressed_color", txt_col)
	hdr.add_theme_color_override("font_focus_color",   txt_col)

	var style := StyleBoxFlat.new()
	style.bg_color = hdr_col
	hdr.add_theme_stylebox_override("normal",  style)
	hdr.add_theme_stylebox_override("hover",   style)
	hdr.add_theme_stylebox_override("pressed", style)
	hdr.add_theme_stylebox_override("focus",   style)

	hdr.text = hdr_text
	vbox.add_child(hdr)

	# Right-side progress label — child of hdr so it never affects VBox layout
	if right_txt != "":
		var prog := Label.new()
		prog.text                 = right_txt
		prog.size                 = Vector2(200, HDR_H)
		prog.position             = Vector2(vp_w - 216, 0)
		prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		prog.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		prog.add_theme_font_size_override("font_size", 17)
		prog.add_theme_color_override("font_color", txt_col)
		if _font: prog.add_theme_font_override("font", _font)
		prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prog.z_index      = 1
		hdr.add_child(prog)   # attached to button, not VBox — zero layout impact

	# ── Rows container (accordion body) ───────────────────────────────────────
	var display_count : int = ld["total"] if ld.get("show_all", false) else done_count
	var rows : Control = null

	_group_tiles.append([])
	_group_panels.append(null)
	_selected_group.append(-1)
	_group_ctx.append({})

	if not is_locked and display_count > 0:
		if ld.get("grouped", false):
			# Set Group grid: tiles never move once built. Tapping a tile
			# only updates the fixed intro panel below the grid — the grid
			# itself never reflows, so every group stays reachable no matter
			# which one's intro is currently showing.
			rows = VBoxContainer.new()
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_theme_constant_override("separation", 14)
			rows.visible = false
			vbox.add_child(rows)
			_fill_group_grid(rows, ld, li, done_count)
		else:
			# Flat single-level list (Level 2: every set is already its own
			# standalone item, no natural sub-grouping).
			var n_rows  : int   = int(ceil(display_count / 2.0))
			var rows_h  : float = n_rows * ROW_STEP + 16.0
			rows = Control.new()
			rows.custom_minimum_size   = Vector2(vp_w, rows_h)
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.visible               = false
			vbox.add_child(rows)
			_fill_set_rows(rows, ld, done_count)

	_rows_containers.append(rows)
	_expanded_flags.append(false)

	if not is_locked:
		hdr.pressed.connect(_on_header_tapped.bind(li, hdr, rows))

	# Gap between level sections
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)


# ─── Set Groups (Prep / Level 1 / Level 1.5) ───────────────────────────────────
# Splits a level's flat sets list into groups by label prefix (A1,A2,A3 -> "A").
func _group_sets(sets: Array) -> Array:
	var groups : Array = []
	for sd in sets:
		var letter : String = String(sd["label"]).left(1)
		if groups.is_empty() or groups[-1]["letter"] != letter:
			groups.append({ "letter": letter, "sets": [] })
		groups[-1]["sets"].append(sd)
	return groups


func _fill_group_grid(vbox: VBoxContainer, ld: Dictionary, li: int, done_count: int) -> void:
	var groups : Array = _group_sets(ld["sets"])

	var done_counts : Array = []
	var running_index : int = 0
	for group in groups:
		var gd : int = 0
		for _s in group["sets"]:
			if running_index < done_count:
				gd += 1
			running_index += 1
		done_counts.append(gd)

	_group_ctx[li] = { "groups": groups, "done": done_counts, "ld": ld }

	# ── Grid of Set Group tiles — fixed positions, never reflow ─────────────
	var vp_w   : float = get_viewport_rect().size.x
	var n_rows : int   = int(ceil(groups.size() / float(GRID_COLS)))
	var tile_w : float = (vp_w - PAGE_PAD * 2.0 - GRID_GAP * (GRID_COLS - 1)) / GRID_COLS
	var grid_h : float = n_rows * GRID_TILE_H + max(0, n_rows - 1) * GRID_GAP

	var grid := Control.new()
	grid.custom_minimum_size   = Vector2(vp_w, grid_h)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	for gi in range(groups.size()):
		var group : Dictionary = groups[gi]
		var row : int = gi / GRID_COLS
		var col : int = gi % GRID_COLS
		var tx  : float = PAGE_PAD + col * (tile_w + GRID_GAP)
		var ty  : float = row * (GRID_TILE_H + GRID_GAP)
		var tile := _make_group_tile(group["letter"], done_counts[gi], group["sets"].size(), tile_w)
		tile.position = Vector2(tx, ty)
		grid.add_child(tile)
		_group_tiles[li].append(tile)
		tile.pressed.connect(_on_tile_tapped.bind(li, gi))

	# ── Fixed Set intro panel, sits below the grid ──────────────────────────
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	vbox.add_child(panel)
	_group_panels[li] = panel

	if groups.size() > 0:
		_on_tile_tapped(li, 0)


func _make_group_tile(letter: String, done: int, total: int, width: float) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(width, GRID_TILE_H)
	tile.size                = Vector2(width, GRID_TILE_H)
	tile.text                = ""

	_style_tile(tile, false)

	var is_done : bool = done >= total
	var letter_lbl := Label.new()
	letter_lbl.text                 = letter
	letter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_lbl.position             = Vector2(0, 6)
	letter_lbl.size                 = Vector2(width, 34)
	letter_lbl.add_theme_font_size_override("font_size", 26)
	letter_lbl.add_theme_color_override("font_color", PURPLE)
	letter_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font: letter_lbl.add_theme_font_override("font", _font)
	tile.add_child(letter_lbl)

	var prog_lbl := Label.new()
	prog_lbl.text                 = "%d / %d%s" % [done, total, "  ✓" if is_done else ""]
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prog_lbl.position             = Vector2(0, 44)
	prog_lbl.size                 = Vector2(width, 24)
	prog_lbl.add_theme_font_size_override("font_size", 14)
	prog_lbl.add_theme_color_override("font_color", BROWN)
	prog_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font: prog_lbl.add_theme_font_override("font", _font)
	tile.add_child(prog_lbl)

	return tile


func _style_tile(tile: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = PURPLE_TINT if selected else WHITE
	style.border_color               = PURPLE
	style.border_width_top           = 4 if selected else 2
	style.border_width_bottom        = 4 if selected else 2
	style.border_width_left          = 4 if selected else 2
	style.border_width_right         = 4 if selected else 2
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	tile.add_theme_stylebox_override("normal",  style)
	tile.add_theme_stylebox_override("hover",   style)
	tile.add_theme_stylebox_override("pressed", style)
	tile.add_theme_stylebox_override("focus",   style)


func _on_tile_tapped(li: int, gi: int) -> void:
	var prev : int = _selected_group[li]
	if prev != -1 and prev < _group_tiles[li].size():
		_style_tile(_group_tiles[li][prev], false)
	_selected_group[li] = gi
	_style_tile(_group_tiles[li][gi], true)

	var ctx         : Dictionary = _group_ctx[li]
	var groups      : Array      = ctx["groups"]
	var done_counts : Array      = ctx["done"]
	var ld          : Dictionary = ctx["ld"]

	var group       : Dictionary = groups[gi]
	var group_done  : int        = done_counts[gi]
	var group_total : int        = group["sets"].size()
	var meta        : Dictionary = ld.get("group_meta", {}).get(group["letter"], {})

	_render_group_panel(_group_panels[li], group, group_done, group_total, meta, ld)


# ─── Set intro panel (Set name / Title / Learning Goal / Progress) ────────────
func _render_group_panel(panel: VBoxContainer, group: Dictionary, group_done: int,
		group_total: int, meta: Dictionary, ld: Dictionary) -> void:
	# Immediate removal, not queue_free() — otherwise the old and new cards
	# can briefly coexist as siblings in the same frame, and the container
	# chain above can compute its height from the stale, larger child set.
	for c in panel.get_children():
		panel.remove_child(c)
		c.free()

	var vp_w   : float   = get_viewport_rect().size.x
	var letter : String  = group["letter"]
	var title  : String  = meta.get("title", "")
	var goal   : String  = meta.get("goal", "")

	var card := Panel.new()
	card.custom_minimum_size   = Vector2(vp_w, PANEL_CARD_H)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sty := StyleBoxFlat.new()
	sty.bg_color                   = WHITE
	sty.border_color               = PURPLE
	sty.border_width_top           = 2
	sty.border_width_bottom        = 2
	sty.border_width_left          = 2
	sty.border_width_right         = 2
	sty.corner_radius_top_left     = 16
	sty.corner_radius_top_right    = 16
	sty.corner_radius_bottom_left  = 16
	sty.corner_radius_bottom_right = 16
	card.add_theme_stylebox_override("panel", sty)
	panel.add_child(card)

	# Four stacked lines: Set name, phoneme title, learning goal, progress.
	_panel_label(card, "Set %s" % letter, Vector2(24, 12), Vector2(vp_w - 48, 30), 22, PURPLE)
	_panel_label(card, title, Vector2(24, 46), Vector2(vp_w - 48, 24), 16, BROWN)
	_panel_label(card, goal,  Vector2(24, 74), Vector2(vp_w - 48, 24), 16, PURPLE)
	_panel_label(card, "%d / %d Completed" % [group_done, group_total],
		Vector2(24, 102), Vector2(vp_w - 48, 22), 14, BROWN)

	var sets_area := Control.new()
	var n_rows : int   = int(ceil(group["sets"].size() / 2.0))
	var area_h : float = n_rows * ROW_STEP + 16.0
	sets_area.custom_minimum_size   = Vector2(vp_w, area_h)
	sets_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(sets_area)
	_render_set_cells(sets_area, group["sets"], ld, group_done)

	# Force a resort at every level in the chain — a plain Control's
	# custom_minimum_size change doesn't always reliably bubble all the way
	# up through nested VBoxContainers on its own.
	panel.queue_sort()
	var rows_container : Container = panel.get_parent() as Container
	if rows_container:
		rows_container.queue_sort()
	if _vbox:
		_vbox.queue_sort()


# ─── Set rows (flat list — Level 2) ────────────────────────────────────────────
func _fill_set_rows(parent: Control, ld: Dictionary, done_count: int) -> void:
	var sets          : Array = ld["sets"]
	var display_count : int   = ld["total"] if ld.get("show_all", false) else done_count
	var visible_sets  : Array = sets.slice(0, display_count)
	_render_set_cells(parent, visible_sets, ld, done_count)


# Shared low-level cell grid renderer — used both for Level 2's flat list and
# for a single Set Group's individual sets, shown in the intro panel.
func _render_set_cells(parent: Control, cell_sets: Array, ld: Dictionary, local_done: int) -> void:
	var page_pad : float = (get_viewport_rect().size.x - CELL_W * 2.0 - CELL_GAP) / 2.0
	for pair in range(int(ceil(cell_sets.size() / 2.0))):
		var row_y : float = 8.0 + pair * ROW_STEP
		for side in range(2):
			var idx : int = pair * 2 + side
			if idx >= cell_sets.size():
				break
			var cell_x : float = page_pad + side * (CELL_W + CELL_GAP)
			_make_completed_cell(parent, cell_sets[idx], ld, cell_x, row_y, idx < local_done)


func _make_completed_cell(parent: Control, sd: Dictionary,
		ld: Dictionary, cx: float, cy: float, is_completed: bool = true) -> void:
	var panel := Panel.new()
	panel.position = Vector2(cx, cy)
	panel.size     = Vector2(CELL_W, CELL_H)
	var sty := StyleBoxFlat.new()
	sty.bg_color                   = WHITE
	sty.border_color               = PURPLE
	sty.border_width_top           = 2
	sty.border_width_bottom        = 2
	sty.border_width_left          = 2
	sty.border_width_right         = 2
	sty.corner_radius_top_left     = 10
	sty.corner_radius_top_right    = 10
	sty.corner_radius_bottom_left  = 10
	sty.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sty)
	parent.add_child(panel)

	# ✓ checkmark (completed sets only)
	if is_completed:
		_panel_label(panel, "✓", Vector2(6, 22), Vector2(24, 24), 16, PURPLE)
	# Set label
	_panel_label(panel, sd["label"], Vector2(30, 20), Vector2(50, 28), 18, PURPLE)
	# Phoneme label
	_panel_label(panel, sd["phonemes"], Vector2(86, 22), Vector2(320, 26), 15, BROWN)

	# Happy Louis icon
	if _louis_tex != null:
		var img := TextureRect.new()
		img.texture        = _louis_tex
		img.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		img.size           = Vector2(44, 44)
		img.position       = Vector2(CELL_W - 138, 12)
		img.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		panel.add_child(img)

	# Replay count "×N" (completed sets only)
	if is_completed:
		var count : int = SaveManager.get_review_count(sd["key"])
		_panel_label(panel, "×%d" % count, Vector2(CELL_W - 92, 23), Vector2(46, 22), 14, PURPLE)

	# Replay button ▶
	var rp := Button.new()
	rp.text         = "▶"
	rp.position     = Vector2(CELL_W - 66, 13)
	rp.size         = Vector2(60, 42)
	rp.pivot_offset = Vector2(30, 21)
	if _font: rp.add_theme_font_override("font", _font)
	rp.add_theme_font_size_override("font_size", 16)
	rp.add_theme_color_override("font_color",         AMBER)
	rp.add_theme_color_override("font_hover_color",   AMBER)
	rp.add_theme_color_override("font_pressed_color", AMBER)
	rp.add_theme_color_override("font_focus_color",   AMBER)
	var rs := StyleBoxFlat.new()
	rs.bg_color                   = PURPLE
	rs.corner_radius_top_left     = 18
	rs.corner_radius_top_right    = 18
	rs.corner_radius_bottom_left  = 18
	rs.corner_radius_bottom_right = 18
	rp.add_theme_stylebox_override("normal",  rs)
	rp.add_theme_stylebox_override("hover",   rs)
	rp.add_theme_stylebox_override("pressed", rs)
	rp.add_theme_stylebox_override("focus",   rs)
	rp.pressed.connect(_on_replay_pressed.bind(sd, ld))
	panel.add_child(rp)


func _panel_label(parent: Control, text: String, pos: Vector2, sz: Vector2,
		fsize: int, col: Color, halign: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.position             = pos
	lbl.size                 = sz
	lbl.horizontal_alignment = halign
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	if _font: lbl.add_theme_font_override("font", _font)
	parent.add_child(lbl)


# ─── Accordion toggle (Level headers) ──────────────────────────────────────────
func _on_header_tapped(li: int, hdr: Button, rows: Control) -> void:
	if rows == null:
		return
	var expanding : bool = not _expanded_flags[li]
	_expanded_flags[li]  = expanding
	rows.visible         = expanding
	# rows' contents were built while hidden, so its true size may never have
	# been computed. Force it (and everything above it) to resort now that
	# it's visible, plus one more deferred pass once this frame settles —
	# otherwise the ScrollContainer above can end up with a stale, too-short
	# scroll range and the bottom of the content becomes unreachable.
	if rows is Container:
		(rows as Container).queue_sort()
	if _vbox:
		_vbox.queue_sort()
		_vbox.call_deferred("queue_sort")
	var icon : String = "▼" if expanding else "▶"
	hdr.text = "     " + icon + "  " + _levels[li]["label"]


# ─── Replay launch ────────────────────────────────────────────────────────────
func _on_replay_pressed(sd: Dictionary, ld: Dictionary) -> void:
	ReviewState.active  = true
	ReviewState.set_key = sd["key"]
	ld["pfn"].call(sd["index"])
	get_tree().change_scene_to_file(sd["scene"])


# ─── Helpers ──────────────────────────────────────────────────────────────────
func _current_level_index() -> int:
	if not SaveManager.is_prep_completed():
		return 0
	if not SaveManager.is_level1_completed():
		return 1
	if not SaveManager.is_level15_completed():
		return 2
	if not SaveManager.is_level2_completed():
		return 3
	return 4


func _on_back_pressed() -> void:
	if is_overlay:
		close_requested.emit()
	else:
		get_tree().change_scene_to_file("res://gnb_home.tscn")
