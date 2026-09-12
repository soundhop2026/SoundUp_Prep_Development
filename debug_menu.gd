extends Node2D

# ─── Debug Menu ───────────────────────────────────────────────────────────────
# QA-only scene launcher + save-data utilities. Only reachable when
# DebugConfig.DEBUG_MODE is true (see title.gd). Not part of the shipping
# game — set DebugConfig.DEBUG_MODE = false to remove this entirely from a
# release build.
# ─────────────────────────────────────────────────────────────────────────────

const DARK_BG    : Color = Color("#1A1A1A")
const HEADER_BG  : Color = Color("#3A1010")
const WARN_RED   : Color = Color("#E0334D")
const AMBER      : Color = Color("#FFB703")
const WHITE      : Color = Color("#FFFFFF")
const BTN_BG     : Color = Color("#4B0082")

const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"

const HEADER_H : float = 100.0

var _font   : Font  = null
var _status : Label = null


func _ready() -> void:
	SceneBackground.set_color(DARK_BG)

	var bg := ColorRect.new()
	bg.color        = DARK_BG
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	_build_header()
	_build_back_button()
	var y : float = _build_scene_shortcuts(116.0)
	y = _build_utilities(y)
	y = _build_premium_gate_demo(y)
	_build_status_label(y)


# ─── Header ───────────────────────────────────────────────────────────────────
func _build_header() -> void:
	var bar := ColorRect.new()
	bar.color        = HEADER_BG
	bar.size         = Vector2(1280.0, HEADER_H)
	bar.position     = Vector2.ZERO
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	_make_label("DEBUG MENU — QA ONLY", Vector2(0, 32), Vector2(1280, 40),
		30, WARN_RED, HORIZONTAL_ALIGNMENT_CENTER)


func _build_back_button() -> void:
	var btn := TextureButton.new()
	btn.texture_normal      = load("res://UI_assets/back_button.png") as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size                = Vector2(90, 90)
	btn.position             = Vector2(16, 13)
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


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://title.tscn")


# ─── Scene shortcuts (2-column grid) ───────────────────────────────────────────
# Each _build_* layout function returns the Y just below its own content, and
# the next section starts from there -- sections used to sit at hand-picked
# absolute Y coordinates with no relation to how tall the grid above them
# actually was, which silently overlapped once an 11th shortcut made the grid
# taller than whoever picked those constants had in mind.
const SECTION_GAP : float = 14.0

func _build_scene_shortcuts(start_y: float) -> float:
	_make_label("Scene Shortcuts", Vector2(70, start_y), Vector2(600, 24),
		18, AMBER)
	var grid_y : float = start_y + 30.0

	var targets : Array[Dictionary] = [
		{ "label": "Title",         "fn": Callable(self, "_jump_title") },
		{ "label": "Prep",          "fn": Callable(self, "_jump_prep") },
		{ "label": "Prep Intro",    "fn": Callable(self, "_jump_prep_intro") },
		{ "label": "Level 1",       "fn": Callable(self, "_jump_level1") },
		{ "label": "Level 1.5",     "fn": Callable(self, "_jump_level15") },
		{ "label": "Level 2",       "fn": Callable(self, "_jump_level2") },
		{ "label": "Set Transition","fn": Callable(self, "_jump_set_transition") },
		{ "label": "Coronation",    "fn": Callable(self, "_jump_coronation") },
		{ "label": "Prep Set 2 (Boundary)", "fn": Callable(self, "_jump_prep_set2") },
		{ "label": "Prep Set 4 (Group Boundary)", "fn": Callable(self, "_jump_prep_set4") },
		{ "label": "Prep Last Set (Coronation Check)", "fn": Callable(self, "_jump_prep_last_set") },
	]

	const COL_W  : float = 560.0
	const COL_GAP: float =  20.0
	const ROW_H  : float =  46.0
	const ROW_GAP: float =  12.0
	const START_X: float =  70.0

	for i in range(targets.size()):
		var row : int = i / 2
		var col : int = i % 2
		var x   : float = START_X + col * (COL_W + COL_GAP)
		var y   : float = grid_y + row * (ROW_H + ROW_GAP)
		_make_action_button(targets[i]["label"], Vector2(x, y), Vector2(COL_W, ROW_H),
			targets[i]["fn"])

	var row_count : int = ceili(targets.size() / 2.0)
	return grid_y + row_count * ROW_H + (row_count - 1) * ROW_GAP + SECTION_GAP


# ─── Utilities (single row) ────────────────────────────────────────────────────
func _build_utilities(start_y: float) -> float:
	_make_label("Utilities", Vector2(70, start_y), Vector2(600, 24), 18, AMBER)
	var row_y : float = start_y + 30.0
	const BTN_H : float = 50.0

	var utils : Array[Dictionary] = [
		{ "label": "Reset Progress",     "fn": Callable(self, "_on_reset_progress_pressed") },
		{ "label": "Unlock All Levels",  "fn": Callable(self, "_on_unlock_all_pressed") },
		{ "label": "Clear Save Data",    "fn": Callable(self, "_on_clear_save_pressed") },
	]

	const BTN_W : float = 380.0
	const GAP   : float =  20.0
	var start_x : float = (1280.0 - BTN_W * 3.0 - GAP * 2.0) / 2.0

	for i in range(utils.size()):
		var x : float = start_x + i * (BTN_W + GAP)
		_make_action_button(utils[i]["label"], Vector2(x, row_y), Vector2(BTN_W, BTN_H),
			utils[i]["fn"], WARN_RED)

	return row_y + BTN_H + SECTION_GAP


# ─── Demo shortcuts — jump straight into a specific flow, skipping the setup
# needed to reach it through normal play. Permanent QA tools. ────────────────
func _build_premium_gate_demo(start_y: float) -> float:
	_make_label("Demo Shortcuts", Vector2(70, start_y), Vector2(600, 24), 18, AMBER)
	var row_y : float = start_y + 30.0
	const BTN_H : float = 50.0

	const BTN_W : float = 244.0
	const GAP   : float =  15.0
	var start_x : float = (1280.0 - BTN_W * 5.0 - GAP * 4.0) / 2.0
	_make_action_button("Test Premium Intro → Choose Plan", Vector2(start_x, row_y),
		Vector2(BTN_W, BTN_H), Callable(self, "_on_test_premium_flow_pressed"))
	_make_action_button("Test Sound Quest (Group A)", Vector2(start_x + (BTN_W + GAP), row_y),
		Vector2(BTN_W, BTN_H), Callable(self, "_on_test_sound_quest_pressed"))
	_make_action_button("Test Quest Transition", Vector2(start_x + (BTN_W + GAP) * 2.0, row_y),
		Vector2(BTN_W, BTN_H), Callable(self, "_on_test_quest_transition_pressed"))
	_make_action_button("Test L1 Sound Quest (Group A)", Vector2(start_x + (BTN_W + GAP) * 3.0, row_y),
		Vector2(BTN_W, BTN_H), Callable(self, "_on_test_level1_sound_quest_pressed"))
	_make_action_button("Test L1 Quest Transition", Vector2(start_x + (BTN_W + GAP) * 4.0, row_y),
		Vector2(BTN_W, BTN_H), Callable(self, "_on_test_level1_quest_transition_pressed"))

	return row_y + BTN_H + SECTION_GAP


func _on_test_premium_flow_pressed() -> void:
	SaveManager.set_subscribed(false)
	PremiumIntroState.context_id = "prep"
	get_tree().change_scene_to_file("res://premium_intro.tscn")


# Jumps straight into Sound Quest with Group A's real word range, skipping
# the need to play a full 20-round Prep set to trigger the Group boundary.
func _on_test_sound_quest_pressed() -> void:
	SoundQuestState.group_start_index = 0
	SoundQuestState.group_end_index   = 3
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://sound_quest.tscn")


# Jumps straight into the Quest Transition celebration itself, skipping the
# need to actually play through a full Quest to trigger it. Doesn't set
# DebugConfig.debug_launch — this path never reaches _start_round() (where
# the flag gets consumed), so setting it here would incorrectly suppress
# the next unrelated real play's count instead.
func _on_test_quest_transition_pressed() -> void:
	SoundQuestState.group_start_index        = 0
	SoundQuestState.group_end_index          = 3
	SoundQuestState.debug_skip_to_transition = true
	get_tree().change_scene_to_file("res://sound_quest.tscn")


# Level 1 Sound Quest's Quest Transition ("find the Play Button") — only
# the transition is built so far, so this jumps straight into it standalone.
func _on_test_level1_sound_quest_pressed() -> void:
	Level1SoundQuestState.group_start_index = 0
	Level1SoundQuestState.group_end_index   = 1
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://level1_sound_quest.tscn")


# Jumps straight into Level 1's Quest Transition celebration itself,
# skipping the Rounds phase — same idea as _on_test_quest_transition_pressed
# above, for isolated preview without grinding a full Quest. Doesn't set
# DebugConfig.debug_launch — same reason as that function: this path never
# reaches _start_round(), so the flag would go uncleared.
func _on_test_level1_quest_transition_pressed() -> void:
	Level1SoundQuestState.group_start_index        = 0
	Level1SoundQuestState.group_end_index          = 1
	Level1SoundQuestState.debug_skip_to_transition = true
	get_tree().change_scene_to_file("res://level1_sound_quest.tscn")


func _build_status_label(start_y: float) -> void:
	_status                      = Label.new()
	_status.text                 = ""
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position             = Vector2(0, start_y)
	_status.size                 = Vector2(1280, 30)
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", WHITE)
	if _font:
		_status.add_theme_font_override("font", _font)
	add_child(_status)


func _show_status(text: String) -> void:
	_status.text = text


# ─── Button helper ──────────────────────────────────────────────────────────────
func _make_action_button(text: String, pos: Vector2, size: Vector2,
		callback: Callable, bg_col: Color = BTN_BG) -> void:
	var btn := Button.new()
	btn.text         = text
	btn.position     = pos
	btn.size         = size
	btn.pivot_offset = size / 2.0

	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color",         WHITE)
	btn.add_theme_color_override("font_hover_color",   AMBER)
	btn.add_theme_color_override("font_pressed_color", AMBER)
	btn.add_theme_color_override("font_focus_color",   WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color                   = bg_col
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal",  style)
	btn.add_theme_stylebox_override("hover",   style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus",   style)

	btn.pressed.connect(callback)
	add_child(btn)


func _make_label(text: String, pos: Vector2, sz: Vector2, fsize: int, col: Color,
		halign: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.position             = pos
	lbl.size                 = sz
	lbl.horizontal_alignment = halign
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	if _font:
		lbl.add_theme_font_override("font", _font)
	add_child(lbl)


# ─── Scene jumps (sane defaults — no mid-content state picker) ────────────────
func _jump_title() -> void:
	get_tree().change_scene_to_file("res://title.tscn")

func _jump_prep() -> void:
	PrepLevelProgress.current_index = 0
	PrepLevelProgress.is_retry      = false
	PrepLevelProgress.retry_rounds.clear()
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://prep_game.tscn")

# Previews the Prep Intro screen directly -- normally only reachable via a
# save's genuine first-ever Play press (title.gd), which every other Prep
# shortcut here intentionally skips past.
func _jump_prep_intro() -> void:
	LevelIntroState.level_id = "prep"
	get_tree().change_scene_to_file("res://level_intro.tscn")

# Lands on Set A2 (index 1) — the last free set. Completing it triggers the
# free/premium boundary: Transition -> Keep Hopping! -> Premium Intro -> Gate.
func _jump_prep_set2() -> void:
	PrepLevelProgress.current_index = 1
	PrepLevelProgress.is_retry      = false
	PrepLevelProgress.retry_rounds.clear()
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://prep_game.tscn")

# Lands on Set A4 (index 3) — the last sub-set of Group A. Completing it now
# just continues Prep normally (Sound Quest is optional bonus content,
# reached only through Where Am I — it no longer gates this boundary).
func _jump_prep_set4() -> void:
	PrepLevelProgress.current_index = 3
	PrepLevelProgress.is_retry      = false
	PrepLevelProgress.retry_rounds.clear()
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://prep_game.tscn")

# Lands on Set F2 (index 25) — Prep's actual final Main Set. Completing it
# for real now exercises the genuine boundary path: pass -> premium check
# (already crossed) -> _continue_to_next_set() -> has_next() false ->
# set_prep_completed() -> Coronation. Verifies Sound Quest no longer
# intercepts this, without needing to play all 26 sets to reach it.
func _jump_prep_last_set() -> void:
	PrepLevelProgress.current_index = PrepLevelProgress.sets.size() - 1
	PrepLevelProgress.is_retry      = false
	PrepLevelProgress.retry_rounds.clear()
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://prep_game.tscn")

func _jump_level1() -> void:
	LevelProgress.current_index = 0
	LevelProgress.is_retry      = false
	LevelProgress.retry_rounds.clear()
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://game.tscn")

func _jump_level15() -> void:
	Level15Progress.current_index = 0
	Level15Progress.is_retry      = false
	Level15Progress.retry_rounds.clear()
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://game15.tscn")

func _jump_level2() -> void:
	Level2Progress.current_index = 0
	Level2Progress.active        = true
	Level2Progress.is_retry      = false
	Level2Progress.retry_rounds.clear()
	DebugConfig.debug_launch = true
	get_tree().change_scene_to_file("res://game2.tscn")

func _jump_set_transition() -> void:
	Level15Progress.active       = false
	Level2Progress.active        = false
	LevelProgress.current_index  = 0
	LevelProgress.last_score_pct = 100.0
	get_tree().change_scene_to_file("res://transition.tscn")

func _jump_coronation() -> void:
	LevelTransition.next_level_id = "level1"
	LevelTransition.level_name    = "Level 1"
	get_tree().change_scene_to_file("res://level_transition.tscn")


# ─── Utility actions ────────────────────────────────────────────────────────────
func _on_reset_progress_pressed() -> void:
	SaveManager.reset_progress()
	PrepLevelProgress.reset()
	LevelProgress.reset()
	Level15Progress.reset()
	Level2Progress.reset()
	_show_status("✓ Progress reset (path choice kept)")

func _on_unlock_all_pressed() -> void:
	SaveManager.unlock_all_levels()
	_show_status("✓ All levels unlocked")

func _on_clear_save_pressed() -> void:
	SaveManager.clear_all_data()
	PrepLevelProgress.reset()
	LevelProgress.reset()
	Level15Progress.reset()
	Level2Progress.reset()
	_show_status("✓ Save data cleared — fresh install state")
