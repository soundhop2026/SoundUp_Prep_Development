extends Node2D
class_name LevelTransition

# ─── Routing (set before changing to this scene) ──────────────────────────────
static var next_level_id : String = "level1"   # matches LevelIntroState.level_id
static var level_name    : String = "Level 1"

# ─── Debug ────────────────────────────────────────────────────────────────────
# Set true to skip all waits and test the scene instantly with F6.
# Set false before release.
const DEBUG_FAST : bool = false

# ─── Colors ───────────────────────────────────────────────────────────────────
const BG_COLOR     : Color = Color("#EDE4D3")
const GOLD_COLOR   : Color = Color("#FFB703")
const PURPLE_COLOR : Color = Color("#4B0083")

# ─── Face ─────────────────────────────────────────────────────────────────────
const FACE_SCALE  : float   = 0.90                  # matches Title Scene PlayButton scale
const FACE_CENTER : Vector2 = Vector2(640.0, 400.0) # shifted down 100px from title's FACE_CENTER_Y — see crown note below

# ─── Crown ────────────────────────────────────────────────────────────────────
const CROWN_SCALE   : float = 0.291  # scaled with face: 0.189 × (0.90 / 0.585)
const CROWN_X       : float = 615.0
const CROWN_START_Y : float = -300.0
# The crown PNG's visible art sits in the upper portion of its 2000x2000 canvas
# (lots of empty space below, since the white background is keyed out at
# runtime), so Sprite2D's texture-center pivot sits well below the actual
# crown graphic. At the original CROWN_LAND_Y=126 the crown was cropped by
# the top of the screen even at rest, and worse during the celebration
# bounce. Shifted the whole face+crown+label group down 100px to fix it.
const CROWN_LAND_Y  : float = 226.0
const CROWN_TILT    : float = 1.0     # slight clockwise tilt

# ─── Layout ───────────────────────────────────────────────────────────────────
# Shifted up from the original 615 — with two lines of text (see
# _setup_label_group()) the block sits noticeably lower, and the celebration
# bounce was bringing it uncomfortably close to the bottom screen edge.
const LEVEL1_Y      : float = 575.0
const LEVEL1_LINE1_FONT : int = 34   # "You made it!" — larger, the headline
const LEVEL1_LINE2_FONT : int = 22   # "Keep hopping!" — smaller, the follow-on


# ─── State ────────────────────────────────────────────────────────────────────
var _face         : Sprite2D          = null
var _crown        : Sprite2D          = null
var _label_group  : Node2D            = null   # holds both text lines so the
                                                 # celebration tween can move
                                                 # them together as one unit
var _music_player : AudioStreamPlayer = null
var _font         : Font              = null

# ─── Ready ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	$background.color        = BG_COLOR
	$background.size         = get_viewport_rect().size
	$background.position     = Vector2(0, 0)
	$background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var font_path := "res://UI_assets/210 연필스케치R.ttf"
	if ResourceLoader.exists(font_path):
		_font = load(font_path)

	_setup_face()
	_setup_crown()
	_setup_label_group()
	_play_sequence()

# ─── Node setup ───────────────────────────────────────────────────────────────
func _setup_face() -> void:
	_face          = Sprite2D.new()
	_face.texture  = load("res://UI_assets/playbutton.png")
	_face.position = FACE_CENTER
	_face.scale    = Vector2(FACE_SCALE, FACE_SCALE)
	_face.z_index  = 4
	add_child(_face)

func _setup_crown() -> void:
	_crown                  = Sprite2D.new()
	_crown.texture          = load("res://UI_assets/level_transition_crown/SoundUp_crown.png")
	_crown.position         = Vector2(CROWN_X, CROWN_START_Y)
	_crown.scale            = Vector2(CROWN_SCALE, CROWN_SCALE)
	_crown.rotation_degrees = CROWN_TILT
	_crown.z_index          = 5
	_apply_white_strip_shader(_crown)
	add_child(_crown)

func _apply_white_strip_shader(node: CanvasItem) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = 1.0 - smoothstep(0.35, 0.65, tex.b);
	COLOR = vec4(tex.rgb, tex.a * a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	node.material = mat

func _setup_label_group() -> void:
	_label_group          = Node2D.new()
	_label_group.position = Vector2(0.0, LEVEL1_Y)
	_label_group.z_index  = 3
	add_child(_label_group)

	var line1 := _make_label_line("You made it!", 0.0, 44.0, LEVEL1_LINE1_FONT)
	var line2 := _make_label_line("Keep hopping!", 42.0, 34.0, LEVEL1_LINE2_FONT)
	_label_group.add_child(line1)
	_label_group.add_child(line2)

func _make_label_line(text: String, y: float, h: float, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(1280.0, h)
	lbl.position              = Vector2(0.0, y)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", PURPLE_COLOR)
	if _font:
		lbl.add_theme_font_override("font", _font)
	return lbl

# ─── Music ────────────────────────────────────────────────────────────────────
func _start_music() -> void:
	_music_player           = AudioStreamPlayer.new()
	_music_player.stream    = load("res://BGM&effect/SoundUp_level_transition_bgm.wav")
	_music_player.volume_db = 0.0
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	_music_player.play()

func _on_music_finished() -> void:
	if _music_player != null:
		_music_player.play()

# ─── Main sequence ────────────────────────────────────────────────────────────
func _t(seconds: float) -> float:
	return 0.01 if DEBUG_FAST else seconds

func _play_sequence() -> void:
	# 0s–2s: face still, no crown, build anticipation
	await get_tree().create_timer(_t(2.0)).timeout

	# 2s: crown begins descending + music starts
	_start_music()
	_descend_crown()

	# 2s–7s: wait for crown to land (5s descent, +25% from original 4s)
	await get_tree().create_timer(_t(5.0)).timeout

	# 7s–7.8s: brief hold so the player can enjoy the crown landing
	await get_tree().create_timer(_t(0.8)).timeout

	# 7.8s–11.8s: celebration
	await _celebrate()

	# 11.8s–16.8s: still with crown — let the player admire
	await get_tree().create_timer(_t(5.0)).timeout

	# Fade out looping music then advance
	if not DEBUG_FAST and _music_player != null and _music_player.playing:
		var fade := create_tween()
		fade.tween_property(_music_player, "volume_db", -40.0, 2.0)
		await fade.finished
	if _music_player != null:
		_music_player.stop()

	# Auto-advance to Level Intro
	LevelIntroState.level_id = next_level_id
	get_tree().change_scene_to_file("res://level_intro.tscn")

# ─── Crown descent (2s–7s) ────────────────────────────────────────────────────
func _descend_crown() -> void:
	var dur : float = _t(5.0)
	var t := create_tween()
	t.tween_property(_crown, "position:y", CROWN_LAND_Y, dur) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# ─── Celebration (6s–10s) ────────────────────────────────────────────────────
func _celebrate() -> void:
	var base_face  : Vector2 = FACE_CENTER
	var base_crown : Vector2 = Vector2(CROWN_X, CROWN_LAND_Y)
	var base_label : Vector2 = Vector2(0.0, LEVEL1_Y)

	# 8 bounces × 0.50s = 4.0s
	for i in range(8):
		var tilt : float = 15.0 if i % 2 == 0 else -15.0

		# Jump up + tilt
		var t_up := create_tween()
		t_up.set_parallel(true)
		t_up.tween_property(_face,  "position",
				base_face  + Vector2(0.0, -55.0), 0.14) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t_up.tween_property(_crown, "position",
				base_crown + Vector2(0.0, -55.0), 0.14) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t_up.tween_property(_label_group, "position",
				base_label + Vector2(0.0, -8.0), 0.14) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t_up.tween_property(_face,  "rotation_degrees", tilt,        0.14)
		t_up.tween_property(_crown, "rotation_degrees", tilt * 0.7,  0.14)
		t_up.tween_property(_label_group, "rotation_degrees", tilt * 0.3, 0.14)
		t_up.tween_property(_face,  "scale",
				Vector2(FACE_SCALE * 1.10, FACE_SCALE * 1.10), 0.14)
		await t_up.finished

		# Come down + reset
		var t_dn := create_tween()
		t_dn.set_parallel(true)
		t_dn.tween_property(_face,  "position",         base_face,  0.22) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t_dn.tween_property(_crown, "position",         base_crown, 0.22) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t_dn.tween_property(_label_group, "position",  base_label, 0.22) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t_dn.tween_property(_face,  "rotation_degrees", 0.0,        0.22)
		t_dn.tween_property(_crown, "rotation_degrees", 0.0,        0.22)
		t_dn.tween_property(_label_group, "rotation_degrees", 0.0, 0.22)
		t_dn.tween_property(_face,  "scale",
				Vector2(FACE_SCALE, FACE_SCALE), 0.22)
		await t_dn.finished

		await get_tree().create_timer(0.14).timeout

	# Snap to exact final positions
	_face.position               = base_face
	_face.rotation_degrees       = 0.0
	_face.scale                  = Vector2(FACE_SCALE, FACE_SCALE)
	_crown.position              = base_crown
	_crown.rotation_degrees      = CROWN_TILT
	_label_group.position        = base_label
	_label_group.rotation_degrees = 0.0
	_label_group.scale            = Vector2(1.0, 1.0)

