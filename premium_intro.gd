extends Node2D

# ─── Premium Intro Scene ────────────────────────────────────────────────────
# Shown after "Keep Hopping!" is pressed at the free/premium boundary.
#
# Verification is integrated directly into this scene — no separate popup,
# no challenge/question. The Play button inside Louis IS the verification
# control: press and hold for HOLD_DURATION seconds. Release early and it
# cancels, resets, and stays right here. Complete the hold and it moves on
# to Scene 2 (Choose Your Plan) automatically — no confirmation dialog.
#
# Structure/UX pass — copy is still placeholder.
# ─────────────────────────────────────────────────────────────────────────────

const FONT_PATH  : String = "res://UI_assets/210 연필스케치R.ttf"
const FACE_PATH  : String = "res://UI_assets/playbutton.png"

const BG_COLOR    : Color = Color("#FDF0E4")   # pale cream/peach
const PURPLE      : Color = Color("#4B0082")
const AMBER       : Color = Color("#FFB703")
const BROWN       : Color = Color(0.35, 0.25, 0.20)

const HOLD_DURATION : float = 7.0   # seconds to hold before verification succeeds
const FACE_SCALE     : float = 0.80

const BREATH_SCALE_LO : float = 0.98
const BREATH_SCALE_HI : float = 1.02
const BREATH_HALF_DUR : float = 1.8   # slow, continuous

const HOVER_SCALE_LO  : float = 0.96
const HOVER_SCALE_HI  : float = 1.04
const HOVER_HALF_DUR  : float = 0.9   # slightly stronger/quicker than idle breathing

var _font       : Font   = null
var _face       : TextureButton = null
var _instruction: Label  = null
var _holding    : bool   = false
var _hold_time  : float  = 0.0
var _idle_tween : Tween  = null   # breathing or hover — keeps running through hold too


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	SceneBackground.set_color(BG_COLOR)

	var bg := ColorRect.new()
	bg.color        = BG_COLOR
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_make_label("SoundHop", Vector2(0, 20), Vector2(1280, 64),
		48, PURPLE, HORIZONTAL_ALIGNMENT_CENTER)
	_make_label("Let's Keep Hopping!", Vector2(0, 90), Vector2(1280, 50),
		34, PURPLE, HORIZONTAL_ALIGNMENT_CENTER)
	_make_label("You've completed the free learning activities", Vector2(0, 150), Vector2(1280, 30),
		18, BROWN, HORIZONTAL_ALIGNMENT_CENTER)

	_build_face()

	_instruction = _make_label("Press and hold to continue", Vector2(0, 440), Vector2(1280, 32),
		20, PURPLE, HORIZONTAL_ALIGNMENT_CENTER)

	_build_not_now_btn()
	_build_copyright_label()


func _build_face() -> void:
	const CENTER : Vector2 = Vector2(640, 300)

	_face = TextureButton.new()
	_face.texture_normal      = load(FACE_PATH) as Texture2D
	_face.ignore_texture_size = true
	_face.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var tex_size : Vector2 = _face.texture_normal.get_size() * FACE_SCALE
	_face.size         = tex_size
	_face.position     = CENTER - tex_size / 2.0
	_face.pivot_offset = tex_size / 2.0   # scale from center, not top-left
	add_child(_face)
	# No overlaid triangle here — playbutton.png already draws Louis's
	# "nose" as a play triangle; adding another one doubled it up.

	_face.button_down.connect(_on_hold_start)
	_face.button_up.connect(_on_hold_release)
	_face.mouse_entered.connect(_on_hover_start)
	_face.mouse_exited.connect(_on_hover_end)

	_start_breathing()


# ─── Idle / hover animation — only one of these tweens runs at a time,
# and neither runs while actively held ─────────────────────────────────────
func _start_breathing() -> void:
	if _idle_tween:
		_idle_tween.kill()
	_face.scale = Vector2.ONE
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_face, "scale", Vector2(BREATH_SCALE_HI, BREATH_SCALE_HI), BREATH_HALF_DUR) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(_face, "scale", Vector2(BREATH_SCALE_LO, BREATH_SCALE_LO), BREATH_HALF_DUR) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _start_hover_pulse() -> void:
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_face, "scale", Vector2(HOVER_SCALE_HI, HOVER_SCALE_HI), HOVER_HALF_DUR) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(_face, "scale", Vector2(HOVER_SCALE_LO, HOVER_SCALE_LO), HOVER_HALF_DUR) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _on_hover_start() -> void:
	if _holding:
		return
	_start_hover_pulse()


func _on_hover_end() -> void:
	if _holding:
		return
	_start_breathing()


func _process(delta: float) -> void:
	if not _holding:
		return
	_hold_time += delta
	if _hold_time >= HOLD_DURATION:
		_on_hold_complete()


func _on_hold_start() -> void:
	# Breathing keeps running through the whole hold — no ring, no visual
	# state change beyond the breathing itself continuing.
	_holding    = true
	_hold_time  = 0.0


func _on_hold_release() -> void:
	if not _holding:
		return   # already completed/cleared in _on_hold_complete()
	_holding   = false
	_hold_time = 0.0
	# Breathing was never interrupted — nothing to resume.


func _on_hold_complete() -> void:
	_holding = false
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ignore the trailing button_up
	_fade_and_continue()


func _fade_and_continue() -> void:
	var fade := ColorRect.new()
	fade.color        = BG_COLOR
	fade.modulate.a   = 0.0
	fade.size         = get_viewport_rect().size
	fade.position     = Vector2.ZERO
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.z_index      = 100
	add_child(fade)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.5)
	await t.finished
	get_tree().change_scene_to_file("res://choose_plan.tscn")


func _build_not_now_btn() -> void:
	var btn := Button.new()
	btn.text     = "Not Now"
	btn.size     = Vector2(160, 44)
	btn.position = Vector2((1280.0 - 160.0) / 2.0, 490.0)
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color",         PURPLE)
	btn.add_theme_color_override("font_hover_color",   AMBER)
	btn.add_theme_color_override("font_pressed_color", AMBER)
	btn.add_theme_color_override("font_focus_color",   PURPLE)
	var blank := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(s, blank)
	btn.pressed.connect(_on_not_now_pressed)
	add_child(btn)


func _on_not_now_pressed() -> void:
	# Same destination as Choose Plan's "Not Now" — returns to Title Scene,
	# free to replay Set 1-2. prep_set_index isn't advanced past Set 2 until
	# the boundary is actually passed, so nothing is lost.
	get_tree().change_scene_to_file("res://title.tscn")


func _build_copyright_label() -> void:
	const BOTTOM_MARGIN : float = 50.0
	var lbl := Label.new()
	lbl.text                 = "© 2026 Acron Inc. All rights reserved."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position              = Vector2(-24.0, get_viewport_rect().size.y - BOTTOM_MARGIN)
	lbl.size                  = Vector2(get_viewport_rect().size.x, 20.0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", PURPLE)
	if _font:
		lbl.add_theme_font_override("font", _font)
	add_child(lbl)


func _make_label(text: String, pos: Vector2, sz: Vector2, fsize: int, col: Color,
		halign: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.position             = pos
	lbl.size                 = sz
	lbl.horizontal_alignment = halign
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	if _font:
		lbl.add_theme_font_override("font", _font)
	add_child(lbl)
	return lbl
