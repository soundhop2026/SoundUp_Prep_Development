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
	_build_scene_shortcuts()
	_build_utilities()
	_build_premium_gate_demo()
	_build_status_label()


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
func _build_scene_shortcuts() -> void:
	_make_label("Scene Shortcuts", Vector2(70, 116), Vector2(600, 24),
		18, AMBER)

	var targets : Array[Dictionary] = [
		{ "label": "Title",         "fn": Callable(self, "_jump_title") },
		{ "label": "Prep",          "fn": Callable(self, "_jump_prep") },
		{ "label": "Level 1",       "fn": Callable(self, "_jump_level1") },
		{ "label": "Level 1.5",     "fn": Callable(self, "_jump_level15") },
		{ "label": "Level 2",       "fn": Callable(self, "_jump_level2") },
		{ "label": "Set Transition","fn": Callable(self, "_jump_set_transition") },
		{ "label": "Coronation",    "fn": Callable(self, "_jump_coronation") },
		{ "label": "Prep Set 2 (Boundary)", "fn": Callable(self, "_jump_prep_set2") },
	]

	const COL_W  : float = 560.0
	const COL_GAP: float =  20.0
	const ROW_H  : float =  60.0
	const ROW_GAP: float =  20.0
	const START_X: float =  70.0
	const START_Y: float = 146.0

	for i in range(targets.size()):
		var row : int = i / 2
		var col : int = i % 2
		var x   : float = START_X + col * (COL_W + COL_GAP)
		var y   : float = START_Y + row * (ROW_H + ROW_GAP)
		_make_action_button(targets[i]["label"], Vector2(x, y), Vector2(COL_W, ROW_H),
			targets[i]["fn"])


# ─── Utilities (single row) ────────────────────────────────────────────────────
func _build_utilities() -> void:
	_make_label("Utilities", Vector2(70, 470), Vector2(600, 24), 18, AMBER)

	var utils : Array[Dictionary] = [
		{ "label": "Reset Progress",     "fn": Callable(self, "_on_reset_progress_pressed") },
		{ "label": "Unlock All Levels",  "fn": Callable(self, "_on_unlock_all_pressed") },
		{ "label": "Clear Save Data",    "fn": Callable(self, "_on_clear_save_pressed") },
	]

	const BTN_W : float = 380.0
	const GAP   : float =  20.0
	const Y     : float = 500.0
	var start_x : float = (1280.0 - BTN_W * 3.0 - GAP * 2.0) / 2.0

	for i in range(utils.size()):
		var x : float = start_x + i * (BTN_W + GAP)
		_make_action_button(utils[i]["label"], Vector2(x, Y), Vector2(BTN_W, 70.0),
			utils[i]["fn"], WARN_RED)


# ─── Premium flow demo — jumps straight to the Premium Intro Scene, skipping
# the need to play through two full Prep sets. Permanent QA tool. ─────────────
func _build_premium_gate_demo() -> void:
	_make_label("Premium Flow Demo", Vector2(70, 610), Vector2(600, 24), 18, AMBER)

	const BTN_W : float = 380.0
	var start_x : float = (1280.0 - BTN_W) / 2.0
	_make_action_button("Test Premium Intro → Choose Plan", Vector2(start_x, 640),
		Vector2(BTN_W, 60.0), Callable(self, "_on_test_premium_flow_pressed"))


func _on_test_premium_flow_pressed() -> void:
	SaveManager.set_subscribed(false)
	PremiumIntroState.context_id = "prep"
	get_tree().change_scene_to_file("res://premium_intro.tscn")


func _build_status_label() -> void:
	_status                      = Label.new()
	_status.text                 = ""
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position             = Vector2(0, 590)
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
	get_tree().change_scene_to_file("res://prep_game.tscn")

# Lands on Set A2 (index 1) — the last free set. Completing it triggers the
# free/premium boundary: Transition -> Keep Hopping! -> Premium Intro -> Gate.
func _jump_prep_set2() -> void:
	PrepLevelProgress.current_index = 1
	PrepLevelProgress.is_retry      = false
	PrepLevelProgress.retry_rounds.clear()
	get_tree().change_scene_to_file("res://prep_game.tscn")

func _jump_level1() -> void:
	LevelProgress.current_index = 0
	LevelProgress.is_retry      = false
	LevelProgress.retry_rounds.clear()
	get_tree().change_scene_to_file("res://game.tscn")

func _jump_level15() -> void:
	Level15Progress.current_index = 0
	Level15Progress.is_retry      = false
	Level15Progress.retry_rounds.clear()
	get_tree().change_scene_to_file("res://game15.tscn")

func _jump_level2() -> void:
	Level2Progress.current_index = 0
	Level2Progress.active        = true
	Level2Progress.is_retry      = false
	Level2Progress.retry_rounds.clear()
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
