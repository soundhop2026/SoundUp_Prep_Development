extends Node2D

# ─── Colors ───────────────────────────────────────────────────────────────────
const PURPLE     : Color = Color("#4B0082")
const PURPLE_TINT: Color = Color("#E8DCF5")   # completed tile tint
const AMBER      : Color = Color("#FFB703")
const CREAM      : Color = Color("#EDE4D3")
const WHITE      : Color = Color("#FFFFFF")
const GRAY_H     : Color = Color("#AAAAAA")   # locked level tile
const BROWN      : Color = Color("#7A5A2A")   # phoneme / secondary text

const FONT_PATH  : String = "res://UI_assets/210 연필스케치R.ttf"
const LOUIS_PATH : String = "res://louisfaces/happylouis3-Photoroom.png"

# ─── Layout ───────────────────────────────────────────────────────────────────
# Three screens (Levels -> Set Groups -> Set detail), each a full-content swap
# rather than a nested accordion. Every screen is sized to fit within one
# viewport's worth of content in its worst case (see per-screen comments
# below) so none of them need to scroll.
const HDR_TOP   : float = 100.0   # shorter bar, more room for content
const PAGE_PAD  : float = 60.0
const TILE_GAP  : float = 24.0
const TOP_PAD   : float = 40.0    # breathing room between header and first row

# Screen 1 — Levels grid. Tile height is computed at runtime from the
# level count (see _lvl_tile_metrics()) and clamped to this range, so the
# grid keeps fitting one screen — no scrolling — as more Levels are added
# later (2 cols scales comfortably to ~10 Levels this way: 5 rows at the
# clamped minimum height still fit inside the body height).
const LVL_TILE_MIN_H : float = 84.0
const LVL_TILE_MAX_H : float = 150.0

# Screen 2 — Set Group grid (worst case Level 1: 7 groups, 2 cols -> 4 rows:
# TOP_PAD 40 + 4*116 + 3*24 = 576, within the 620px body height).
const GRP_TILE_H : float = 116.0

# Ungrouped levels (Level 2, Level 2.5, ...) with more than CHUNK_MAX sets
# get an auto-generated "Sets A–F" chunk-selection screen instead of ever
# shrinking the final Set list below its comfortable size — every Set list
# a child actually taps into stays at the full, large size, and a Level
# with even more Sets later just gets more chunk tiles, not smaller ones.
const CHUNK_MAX : int = 6

# Screen 3 — individual Set cards. Row height is computed at runtime from
# how many cards need to fit in the available area (see _cell_metrics()) and
# clamped to this range — same technique as the Levels grid. A single Set
# Group tops out at 6 sets today (3 rows, comfortably fits at the max size),
# but Level 2's flat, ungrouped list shows up to 12 at once (6 rows), which
# needs the smaller end of the range to avoid overflowing the screen.
const CELL_W           : float = 572.0
const CELL_GAP          : float = 16.0
const CELL_ROW_STEP_MIN : float = 74.0
const CELL_ROW_STEP_MAX : float = 108.0

# ─── State ────────────────────────────────────────────────────────────────────
var _font      : Font      = null
var _louis_tex : Texture2D = null
var _levels    : Array     = []

var _page      : String = "levels"   # "levels" | "groups" | "chunks" | "sets"
var _sel_level : int    = -1
var _sel_group : int    = -1
var _sel_chunk : int    = -1

var _content   : Control = null
var _title_lbl : Label   = null
var _sub_lbl   : Label   = null

var is_overlay : bool = false
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

	_build_header_bar()
	_build_back_button()

	_content = Control.new()
	_content.position             = Vector2(0, HDR_TOP)
	_content.size                 = Vector2(get_viewport_rect().size.x, get_viewport_rect().size.y - HDR_TOP)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_content)

	_show_levels_page()


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
		{ "id": "prep",    "label": "Prep Level","tagline": "Consonant Sounds", "done": prep_done, "total": 26,
		  "locked": false,   "sets": _prep_sets(),    "pfn": func(i): PrepLevelProgress.current_index = i,
		  "show_all": SaveManager.is_chose_level1_path(), "color": Color("#A8E063"), "txt_color": PURPLE,
		  "grouped": true, "group_meta": _prep_group_meta() },
		{ "id": "level1",  "label": "Level 1",   "tagline": "Consonant Sounds", "done": l1_done,  "total": 17,
		  "locked": l1_lock, "sets": _level1_sets(),  "pfn": func(i): LevelProgress.current_index = i,
		  "show_all": false, "color": Color("#6EB5FF"), "txt_color": PURPLE,
		  "grouped": true, "group_meta": _level1_group_meta() },
		{ "id": "level15", "label": "Level 1.5", "tagline": "Sounds in Words", "done": l15_done, "total": 13,
		  "locked": l15_lock, "sets": _level15_sets(), "pfn": func(i): Level15Progress.current_index = i,
		  "show_all": false, "color": Color("#A83A22"), "txt_color": Color("#EDE4D3"),
		  "grouped": true, "group_meta": _level15_group_meta() },
		{ "id": "level2",  "label": "Level 2",   "tagline": "Single Vowels", "done": l2_done,  "total": 12,
		  "locked": l2_lock, "sets": _level2_sets(),  "pfn": func(i): Level2Progress.current_index = i,
		  "show_all": false, "color": Color("#8DB33A"), "txt_color": PURPLE,
		  "grouped": false, "group_meta": {} },
		{ "id": "level25", "label": "Level 2.5", "tagline": "Rimes", "done": 0, "total": 19,
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


# ─── Header (purple bar — title + subtitle text swap per screen) ──────────────
func _build_header_bar() -> void:
	var vp_w : float = get_viewport_rect().size.x

	var bar := ColorRect.new()
	bar.color        = PURPLE
	bar.size         = Vector2(vp_w, HDR_TOP)
	bar.position     = Vector2.ZERO
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	_title_lbl = Label.new()
	_title_lbl.position             = Vector2(120, 4)
	_title_lbl.size                 = Vector2(vp_w - 240, 46)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 36)
	_title_lbl.add_theme_color_override("font_color", AMBER)
	if _font: _title_lbl.add_theme_font_override("font", _font)
	add_child(_title_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.position             = Vector2(0, 52)
	_sub_lbl.size                 = Vector2(vp_w, 28)
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_sub_lbl.add_theme_font_size_override("font_size", 19)
	_sub_lbl.add_theme_color_override("font_color", AMBER)
	if _font: _sub_lbl.add_theme_font_override("font", _font)
	add_child(_sub_lbl)


func _set_header(title: String, sub: String) -> void:
	_title_lbl.text = title
	_sub_lbl.text    = sub
	_sub_lbl.visible = sub != ""


func _build_back_button() -> void:
	var btn := TextureButton.new()
	btn.texture_normal      = load("res://UI_assets/back_button.png") as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size                = Vector2(90, 90)
	btn.position             = Vector2(16, 5)
	btn.z_index              = 10
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 c : source_color;
void fragment() { vec4 t = texture(TEXTURE, UV); COLOR = vec4(c.rgb, t.a); }"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("c", AMBER)
	btn.material = mat
	btn.pressed.connect(_on_back_pressed)
	add_child(btn)


# ─── Content area helpers ──────────────────────────────────────────────────────
func _clear_content() -> void:
	# queue_free(), not free() — a page switch is triggered from inside a
	# tapped tile's own "pressed" signal, and that tile is a child of
	# _content. Freeing it immediately destroys the node while it's still on
	# the call stack for its own signal emission, which corrupts the frame.
	# remove_child() detaches it from the tree (stops it drawing/processing)
	# right away; queue_free() safely defers the actual deallocation.
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()


func _tile_w(cols: int) -> float:
	var vp_w : float = get_viewport_rect().size.x
	return (vp_w - PAGE_PAD * 2.0 - TILE_GAP * (cols - 1)) / cols


# Level tile height (and matching font sizes) computed from how many Levels
# there are, so the 2-col grid always fits one screen without scrolling —
# tiles start at LVL_TILE_MAX_H for today's 5 Levels and shrink gracefully
# toward LVL_TILE_MIN_H as more Levels are added (still a comfortable tap
# target at the floor: ~2x the standard mobile minimum touch size).
func _lvl_tile_metrics(count: int) -> Dictionary:
	var rows  : int   = int(ceil(count / 2.0))
	var avail : float = _content.size.y - TOP_PAD
	var raw_h : float = (avail - (rows - 1) * TILE_GAP) / rows
	var h     : float = clamp(raw_h, LVL_TILE_MIN_H, LVL_TILE_MAX_H)
	return {
		"h": h,
		"name_font": int(clamp(round(h * 0.253), 26, 38)),
		"prog_font": int(clamp(round(h * 0.147), 16, 22)),
	}


# ─── Screen 1 — Levels grid ────────────────────────────────────────────────────
func _show_levels_page() -> void:
	_page = "levels"
	_clear_content()

	var prep_done  : int = 26 if SaveManager.is_prep_completed()   else SaveManager.get_prep_set_index()
	var l1_done    : int = 17 if SaveManager.is_level1_completed()  else SaveManager.get_level1_set_index()
	var l15_done   : int = 13 if SaveManager.is_level15_completed() else SaveManager.get_level15_set_index()
	var l2_done    : int = 12 if SaveManager.is_level2_completed()  else SaveManager.get_level2_set_index()
	var total_done : int = prep_done + l1_done + l15_done + l2_done

	var level_names : Array[String] = ["Prep Level", "Level 1", "Level 1.5", "Level 2", "Level 2.5"]
	var cur : String = level_names[_current_level_index()]

	_set_header("Where am I", "%d sets done  ·  now: %s" % [total_done, cur])

	var cols    : int        = 2
	var tile_w  : float      = _tile_w(cols)
	var metrics : Dictionary = _lvl_tile_metrics(_levels.size())
	var tile_h  : float      = metrics["h"]

	for i in range(_levels.size()):
		var ld  : Dictionary = _levels[i]
		var row : int = i / cols
		var col : int = i % cols
		var tile := _make_level_tile(ld, tile_w, metrics)
		tile.position = Vector2(PAGE_PAD + col * (tile_w + TILE_GAP), TOP_PAD + row * (tile_h + TILE_GAP))
		_content.add_child(tile)
		if not ld["locked"]:
			tile.pressed.connect(_on_level_tapped.bind(i))


func _make_level_tile(ld: Dictionary, width: float, metrics: Dictionary) -> Button:
	var h : float = metrics["h"]
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(width, h)
	tile.size                = Vector2(width, h)
	tile.text                = ""
	tile.disabled            = ld["locked"]

	var is_done : bool = ld["done"] >= ld["total"] and not ld["locked"]

	var style := StyleBoxFlat.new()
	style.bg_color                   = GRAY_H if ld["locked"] else (PURPLE_TINT if is_done else WHITE)
	style.border_color               = PURPLE
	style.border_width_top           = 3
	style.border_width_bottom        = 3
	style.border_width_left          = 3
	style.border_width_right         = 3
	style.corner_radius_top_left     = 18
	style.corner_radius_top_right    = 18
	style.corner_radius_bottom_left  = 18
	style.corner_radius_bottom_right = 18
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		tile.add_theme_stylebox_override(state, style)

	var name_txt : String = ("🔒  " if ld["locked"] else "") + ld["label"]
	_panel_label(tile, name_txt, Vector2(0, h * 0.28), Vector2(width, h * 0.36), metrics["name_font"],
		WHITE if ld["locked"] else PURPLE, HORIZONTAL_ALIGNMENT_CENTER)

	if not ld["locked"]:
		var prog_txt : String = "%d / %d%s" % [ld["done"], ld["total"], "  ✓" if is_done else ""]
		_panel_label(tile, prog_txt, Vector2(0, h * 0.66), Vector2(width, h * 0.22), metrics["prog_font"],
			BROWN, HORIZONTAL_ALIGNMENT_CENTER)

	return tile


func _on_level_tapped(li: int) -> void:
	_sel_level = li
	var ld : Dictionary = _levels[li]
	if ld.get("grouped", false):
		_show_groups_page()
	elif ld["sets"].size() > CHUNK_MAX:
		_show_chunks_page()
	else:
		_show_sets_page_flat()


# ─── Screen 2 — Set Group grid (skipped entirely for ungrouped levels) ────────
func _show_groups_page() -> void:
	_page = "groups"
	_clear_content()

	var ld : Dictionary = _levels[_sel_level]
	_set_header(ld["label"], ld.get("tagline", ""))

	var groups      : Array = _group_sets(ld["sets"])
	var done_counts : Array = _group_done_counts(groups, ld["done"])

	var cols   : int   = 2
	var tile_w : float = _tile_w(cols)

	for gi in range(groups.size()):
		var group : Dictionary = groups[gi]
		var row : int = gi / cols
		var col : int = gi % cols
		var tile := _make_group_tile(group["letter"], done_counts[gi], group["sets"].size(), tile_w)
		tile.position = Vector2(PAGE_PAD + col * (tile_w + TILE_GAP), TOP_PAD + row * (GRP_TILE_H + TILE_GAP))
		_content.add_child(tile)
		tile.pressed.connect(_on_group_tapped.bind(gi))


# Splits a level's flat sets list into groups by label prefix (A1,A2,A3 -> "A").
func _group_sets(sets: Array) -> Array:
	var groups : Array = []
	for sd in sets:
		var letter : String = String(sd["label"]).left(1)
		if groups.is_empty() or groups[-1]["letter"] != letter:
			groups.append({ "letter": letter, "sets": [] })
		groups[-1]["sets"].append(sd)
	return groups


func _group_done_counts(groups: Array, level_done: int) -> Array:
	var done_counts : Array = []
	var running : int = 0
	for group in groups:
		var gd : int = 0
		for _s in group["sets"]:
			if running < level_done:
				gd += 1
			running += 1
		done_counts.append(gd)
	return done_counts


# ─── Screen 2 (ungrouped-but-many levels) — auto chunk-selection grid ─────────
# Splits a flat sets list into chunks of at most CHUNK_MAX, sized as evenly
# as possible (e.g. 19 sets -> 4 chunks of 5/5/5/4, not 6/6/6/1) so no chunk
# ends up oddly small. Returns [] when the list already fits in one screen.
func _chunk_sets(sets: Array) -> Array:
	var total : int = sets.size()
	if total <= CHUNK_MAX:
		return []
	var n_chunks : int = int(ceil(float(total) / CHUNK_MAX))
	var base     : int = total / n_chunks
	var extra    : int = total % n_chunks
	var chunks   : Array = []
	var idx      : int = 0
	for c in range(n_chunks):
		var size        : int   = base + (1 if c < extra else 0)
		var chunk_sets  : Array = sets.slice(idx, idx + size)
		var first_label : String = chunk_sets[0]["label"]
		var last_label  : String = chunk_sets[-1]["label"]
		var label : String = ("Sets %s–%s" % [first_label, last_label]) if size > 1 else ("Set %s" % first_label)
		chunks.append({ "label": label, "sets": chunk_sets })
		idx += size
	return chunks


func _show_chunks_page() -> void:
	_page = "chunks"
	_clear_content()

	var ld : Dictionary = _levels[_sel_level]
	_set_header(ld["label"], ld.get("tagline", ""))

	var chunks      : Array = _chunk_sets(ld["sets"])
	var done_counts : Array = _group_done_counts(chunks, ld["done"])

	var cols   : int   = 2
	var tile_w : float = _tile_w(cols)

	for ci in range(chunks.size()):
		var chunk : Dictionary = chunks[ci]
		var row : int = ci / cols
		var col : int = ci % cols
		var tile := _make_chunk_tile(chunk["label"], done_counts[ci], chunk["sets"].size(), tile_w)
		tile.position = Vector2(PAGE_PAD + col * (tile_w + TILE_GAP), TOP_PAD + row * (GRP_TILE_H + TILE_GAP))
		_content.add_child(tile)
		tile.pressed.connect(_on_chunk_tapped.bind(ci))


func _make_chunk_tile(label: String, done: int, total: int, width: float) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(width, GRP_TILE_H)
	tile.size                = Vector2(width, GRP_TILE_H)
	tile.text                = ""

	var is_done : bool = done >= total
	_style_tile(tile, is_done)

	_panel_label(tile, label, Vector2(0, 18), Vector2(width, 44), 30, PURPLE, HORIZONTAL_ALIGNMENT_CENTER)
	_panel_label(tile, "%d / %d%s" % [done, total, "  ✓" if is_done else ""],
		Vector2(0, 68), Vector2(width, 30), 20, BROWN, HORIZONTAL_ALIGNMENT_CENTER)

	return tile


func _on_chunk_tapped(ci: int) -> void:
	_sel_chunk = ci
	_show_sets_page_chunk()


func _make_group_tile(letter: String, done: int, total: int, width: float) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(width, GRP_TILE_H)
	tile.size                = Vector2(width, GRP_TILE_H)
	tile.text                = ""

	var is_done : bool = done >= total
	_style_tile(tile, is_done)

	_panel_label(tile, "Set %s" % letter, Vector2(0, 18), Vector2(width, 44), 34, PURPLE, HORIZONTAL_ALIGNMENT_CENTER)
	_panel_label(tile, "%d / %d%s" % [done, total, "  ✓" if is_done else ""],
		Vector2(0, 68), Vector2(width, 30), 20, BROWN, HORIZONTAL_ALIGNMENT_CENTER)

	return tile


func _style_tile(tile: Button, filled: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = PURPLE_TINT if filled else WHITE
	style.border_color               = PURPLE
	style.border_width_top           = 3
	style.border_width_bottom        = 3
	style.border_width_left          = 3
	style.border_width_right         = 3
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	for state in ["normal", "hover", "pressed", "focus"]:
		tile.add_theme_stylebox_override(state, style)


func _on_group_tapped(gi: int) -> void:
	_sel_group = gi
	_show_sets_page()


# ─── Screen 3 — Set detail (grouped levels) ────────────────────────────────────
func _show_sets_page() -> void:
	_page = "sets"
	_clear_content()

	var ld : Dictionary = _levels[_sel_level]
	_set_header(ld["label"], ld.get("tagline", ""))

	var groups : Array = _group_sets(ld["sets"])
	var group  : Dictionary = groups[_sel_group]
	var letter : String = group["letter"]

	var done_counts : Array = _group_done_counts(groups, ld["done"])
	var group_done  : int = done_counts[_sel_group]
	var group_total : int = group["sets"].size()
	var meta        : Dictionary = ld.get("group_meta", {}).get(letter, {})

	var vp_w : float = get_viewport_rect().size.x
	_panel_label(_content, "Set %s — %s" % [letter, meta.get("title", "")],
		Vector2(PAGE_PAD, TOP_PAD), Vector2(vp_w - PAGE_PAD * 2, 46), 32, PURPLE)
	_panel_label(_content, meta.get("goal", ""),
		Vector2(PAGE_PAD, TOP_PAD + 50), Vector2(vp_w - PAGE_PAD * 2, 32), 22, BROWN)
	_panel_label(_content, "%d / %d Completed" % [group_done, group_total],
		Vector2(PAGE_PAD, TOP_PAD + 88), Vector2(vp_w - PAGE_PAD * 2, 28), 19, PURPLE)

	var cells_area := Control.new()
	cells_area.position = Vector2(0, TOP_PAD + 130)
	cells_area.size     = Vector2(vp_w, _content.size.y - (TOP_PAD + 130))
	_content.add_child(cells_area)
	_render_set_cells(cells_area, group["sets"], ld, group_done)


# ─── Screen 3 — Set detail (ungrouped levels, e.g. Level 2) ───────────────────
func _show_sets_page_flat() -> void:
	_page = "sets"
	_clear_content()

	var ld : Dictionary = _levels[_sel_level]
	_set_header(ld["label"], ld.get("tagline", ""))

	var display_count : int   = ld["total"] if ld.get("show_all", false) else ld["done"]
	var visible_sets  : Array = ld["sets"].slice(0, display_count)

	var vp_w : float = get_viewport_rect().size.x
	var cells_area := Control.new()
	cells_area.position = Vector2(0, TOP_PAD)
	cells_area.size     = Vector2(vp_w, _content.size.y - TOP_PAD)
	_content.add_child(cells_area)

	if visible_sets.is_empty():
		_panel_label(cells_area, "Complete more sets to see them here.",
			Vector2(PAGE_PAD, 40), Vector2(vp_w - PAGE_PAD * 2, 30), 20, BROWN, HORIZONTAL_ALIGNMENT_CENTER)
		return

	_render_set_cells(cells_area, visible_sets, ld, ld["done"])


# ─── Screen 3 — Set detail (one chunk of an ungrouped-but-many level) ─────────
func _show_sets_page_chunk() -> void:
	_page = "sets"
	_clear_content()

	var ld : Dictionary = _levels[_sel_level]
	_set_header(ld["label"], ld.get("tagline", ""))

	var chunks      : Array      = _chunk_sets(ld["sets"])
	var chunk       : Dictionary = chunks[_sel_chunk]
	var done_counts : Array      = _group_done_counts(chunks, ld["done"])
	var chunk_done  : int        = done_counts[_sel_chunk]

	var vp_w : float = get_viewport_rect().size.x
	var cells_area := Control.new()
	cells_area.position = Vector2(0, TOP_PAD)
	cells_area.size     = Vector2(vp_w, _content.size.y - TOP_PAD)
	_content.add_child(cells_area)
	_render_set_cells(cells_area, chunk["sets"], ld, chunk_done)


# Row height for the Set-card grid, computed from how many cards actually
# need to fit in the available area — a single Set Group (<=6 sets, 3 rows)
# fits comfortably at the max size, but Level 2's flat list can show up to
# 12 at once (6 rows), which needs the smaller end of the range.
func _cell_metrics(count: int, area_h: float) -> Dictionary:
	var rows     : int   = int(ceil(count / 2.0))
	var raw_step : float = area_h / max(rows, 1)
	var row_step : float = clamp(raw_step, CELL_ROW_STEP_MIN, CELL_ROW_STEP_MAX)
	return { "row_step": row_step, "cell_h": row_step - CELL_GAP }


# Shared low-level cell grid renderer — used both for Level 2's flat list and
# for a single Set Group's individual sets on Screen 3.
func _render_set_cells(parent: Control, cell_sets: Array, ld: Dictionary, local_done: int) -> void:
	var metrics  : Dictionary = _cell_metrics(cell_sets.size(), parent.size.y)
	var row_step : float = metrics["row_step"]
	var cell_h   : float = metrics["cell_h"]
	var page_pad : float = (get_viewport_rect().size.x - CELL_W * 2.0 - CELL_GAP) / 2.0
	for pair in range(int(ceil(cell_sets.size() / 2.0))):
		var row_y : float = pair * row_step
		for side in range(2):
			var idx : int = pair * 2 + side
			if idx >= cell_sets.size():
				break
			var cell_x : float = page_pad + side * (CELL_W + CELL_GAP)
			_make_completed_cell(parent, cell_sets[idx], ld, cell_x, row_y, cell_h, idx < local_done)


# Sub-element offsets below were tuned at this reference height (the old
# fixed CELL_H) and scale proportionally via k for smaller row heights.
const CELL_H_REF : float = 92.0

func _make_completed_cell(parent: Control, sd: Dictionary,
		ld: Dictionary, cx: float, cy: float, cell_h: float, is_completed: bool = true) -> void:
	var k : float = cell_h / CELL_H_REF
	var panel := Panel.new()
	panel.position = Vector2(cx, cy)
	panel.size     = Vector2(CELL_W, cell_h)
	var sty := StyleBoxFlat.new()
	sty.bg_color                   = WHITE
	sty.border_color               = PURPLE
	sty.border_width_top           = 2
	sty.border_width_bottom        = 2
	sty.border_width_left          = 2
	sty.border_width_right         = 2
	sty.corner_radius_top_left     = 12
	sty.corner_radius_top_right    = 12
	sty.corner_radius_bottom_left  = 12
	sty.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", sty)
	parent.add_child(panel)

	# ✓ checkmark (completed sets only)
	if is_completed:
		_panel_label(panel, "✓", Vector2(10, 32 * k), Vector2(30, 32 * k), max(12, int(round(20 * k))), PURPLE)
	# Set label
	_panel_label(panel, sd["label"], Vector2(38, 28 * k), Vector2(58, 36 * k), max(14, int(round(24 * k))), PURPLE)
	# Phoneme label
	_panel_label(panel, sd["phonemes"], Vector2(100, 31 * k), Vector2(320, 34 * k), max(12, int(round(19 * k))), BROWN)

	# Happy Louis icon
	if _louis_tex != null:
		var img := TextureRect.new()
		img.texture        = _louis_tex
		img.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		img.size           = Vector2(52, 52) * k
		img.position       = Vector2(CELL_W - 138, 20 * k)
		img.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		panel.add_child(img)

	# Replay count "×N" (completed sets only)
	if is_completed:
		var count : int = SaveManager.get_review_count(sd["key"])
		_panel_label(panel, "×%d" % count, Vector2(CELL_W - 92, 33 * k), Vector2(46, 26 * k), max(11, int(round(16 * k))), PURPLE)

	# Replay button ▶
	var rp := Button.new()
	rp.text         = "▶"
	rp.position     = Vector2(CELL_W - 66, 23 * k)
	rp.size         = Vector2(60, 52 * k)
	rp.pivot_offset = Vector2(30, 26 * k)
	if _font: rp.add_theme_font_override("font", _font)
	rp.add_theme_font_size_override("font_size", max(24, int(round(36 * k))))
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


# ─── Back navigation — context-aware per screen ────────────────────────────────
func _on_back_pressed() -> void:
	match _page:
		"sets":
			var ld : Dictionary = _levels[_sel_level]
			if ld.get("grouped", false):
				_show_groups_page()
			elif ld["sets"].size() > CHUNK_MAX:
				_show_chunks_page()
			else:
				_show_levels_page()
		"groups", "chunks":
			_show_levels_page()
		_:
			if is_overlay:
				close_requested.emit()
			else:
				get_tree().change_scene_to_file("res://gnb_home.tscn")
