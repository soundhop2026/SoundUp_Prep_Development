extends Node2D

# ─── Constants ────────────────────────────────────────────────────────────────
const BG_COLOR   : Color = Color("#4B0082")
const FACE_COLOR : Color = Color("#F5E6CC")  # PlayButton face — cream beige
const LOGO_COLOR : Color = Color("#FFB703")  # SOUNDUP + subtitle — amber

const LETTERS       : Array[String] = ["S","O","U","N","D","H","O","P"]
const LETTER_SIZE   : int           = 112   # 86 x 1.3 — Schoolbell pass, 2026-09-29
const SUBTITLE_SIZE : int           = 25
const LETTER_W      : float         = 64.0
const LETTER_H      : float         = 88.0

# y 450 -> 410 lifted the arc above the larger Schoolbell letters; 410 -> 435
# then moved it back down in step with FACE_CENTER_Y (300 -> 325) so the
# approved gap between the settled arc and the top of the head is preserved
# exactly while both gain 25px of air above them. Radius and angle span are
# untouched, so the arc's shape is unchanged — only its vertical origin moves.
const ARC_CENTER  : Vector2 = Vector2(618.0, 435.0)
const ARC_RADIUS  : float   = 300.0
# Span widened 72deg -> 84deg (2026-09-29) purely to open up the gaps between
# letters after the Schoolbell size increase — letters sit further apart along
# the SAME circle, so ARC_CENTER and ARC_RADIUS are untouched and the curve's
# shape and apex position are unchanged. Letter spacing +16.7%.
const ARC_MIN_DEG : float   = -42.0
const ARC_MAX_DEG : float   =  42.0

const FACE_CENTER_Y : float = 325.0   # 300 -> 325: more air above the head for the idle letters
const BTN_SCALE     : float = 0.90
const PB_TEX_SIZE   : Vector2 = Vector2(907.0, 437.0)   # playbutton.png, unscaled

const WORD_TEXTS    : Array[String] = ["Learning", "Sounds"]
const WORD_W        : Array[float]  = [128.0, 96.0]
# Offsets from viewport centre. The two words are separate Labels, so the gap
# between them is whatever these offsets leave — it is not a real space
# character. With Andika at 25pt ('Learning' 101px, 'Sounds' 84px, natural
# space 6px) the original values left a 39px gap, 6.5x a space, which read as
# two separate words rather than one phrase.
# Recomputed again for Andika Bold ('Learning' 108px, 'Sounds' 88px, space
# 7px): the numbers changed so that the RESULT does not — still exactly one
# natural space between the words, still centred on x=618, the logo's true
# visual centre, matching ARC_CENTER and the drawn face's own ink centre, which
# is ~22px left of the 640 viewport centre. Bold is ~6% wider than Regular, so
# keeping the old offsets would have narrowed the gap and pushed the phrase
# right. Andika Bold is the same height as Regular, so nothing moves vertically.
const WORD_X_OFFSET : Array[float]  = [-123.5, -8.5]
const WORDS_Y       : float         = 450.0

const FLY_OUT : Array[Vector2] = [
	Vector2(-900.0,  -80.0),
	Vector2(-420.0, -800.0),
	Vector2(  60.0, -900.0),
	Vector2(  50.0, -950.0),
	Vector2( 900.0, -420.0),
	Vector2( 580.0, -760.0),
	Vector2( 800.0,  300.0),
	Vector2( 950.0,  -60.0),
]

# ─── State ────────────────────────────────────────────────────────────────────
var _letters : Array[Label] = []
var _words   : Array[Label] = []
var _word_x  : Array[float] = []
var _font      : Font       = null   # UIFonts.learning_bold() — the "Learning Sounds" tagline
var _head_font : Font       = null   # UIFonts.character() — head text only
var _mono_font : Font       = null   # UIFonts.action()
var _pressed        : bool         = false
var _can_press      : bool         = false
var _breathe_tweens : Array        = []   # face only — the letters drift instead
var _drift_active   : bool         = false  # true while the letters ride the breeze
var _drift_t        : float        = 0.0    # seconds of idle drift elapsed
var _drift_damp     : float        = 1.0    # 1 = full breeze, 0 = settled; tweened on tap
var _final_top_y    : float        = 0.0    # highest point of the settled arc, cached
var _pb_home        : Vector2      = Vector2.ZERO   # the face's resting position
var _debug_btn      : Button       = null
var _gnb_btn        : Button       = null
var _vp_cx          : float        = 640.0   # true horizontal centre of the viewport

# ─── Setup ────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	$ColorRect.color    = BG_COLOR
	$ColorRect.size     = get_viewport_rect().size
	$ColorRect.position = Vector2(0, 0)

	_vp_cx = get_viewport_rect().size.x / 2.0
	for off in WORD_X_OFFSET:
		_word_x.append(_vp_cx + off)

	_create_gnb_entry()

	# Scale the face about its own centre, not its top-left corner, so the idle
	# breathing below is position-neutral. A Control renders its local origin at
	# position + pivot_offset * (1 - scale), so moving the pivot while scale is
	# already BTN_SCALE would shift the face down-right by pivot * 0.1 — the
	# subtraction below cancels exactly that, leaving the face where it has
	# always been.
	$PlayButton.texture_click_mask = _build_face_click_mask()
	$PlayButton.pivot_offset = PB_TEX_SIZE * 0.5
	$PlayButton.scale        = Vector2(BTN_SCALE, BTN_SCALE)
	_pb_home = Vector2(
		_vp_cx - PB_TEX_SIZE.x * BTN_SCALE * 0.5,
		FACE_CENTER_Y - PB_TEX_SIZE.y * BTN_SCALE * 0.5
	) - PB_TEX_SIZE * 0.5 * (1.0 - BTN_SCALE)
	$PlayButton.position = _pb_home
	_apply_shader($PlayButton, FACE_COLOR)
	$PlayButton.pressed.connect(_on_play_pressed)

	$BGMPlayer.finished.connect(_on_bgm_finished)

	# Schoolbell is the character / brand accent face and is used for the
	# head text ONLY — the letter arc sitting on the PlayButton's head. The
	# "Learning Sounds" subtitle below the face is deliberately left on the
	# original face pending a decision; it is not head text.
	_head_font = UIFonts.character()

	# The tagline is learning/navigation copy, so it takes Andika — the last
	# thing on this screen still carrying the legacy face.
	_font = UIFonts.learning_bold()

	# Was a hardcoded root-level JetBrains Mono path, which the font
	# reorganisation moved into its own family folder — the old path silently
	# resolved to null and this label fell back to the engine default.
	_mono_font = UIFonts.action()

	_create_letters()
	_final_top_y = _letter_final_pos(0).y
	for i in range(LETTERS.size()):
		_final_top_y = minf(_final_top_y, _letter_final_pos(i).y)
	_create_words()
	_create_copyright_label()
	_create_debug_menu_button()
	_animate_in()

func _create_copyright_label() -> void:
	const BOTTOM_MARGIN : float = 50.0   # distance from the bottom of the screen

	var lbl := Label.new()
	lbl.text                 = "© 2026 Acron Inc. All rights reserved."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position             = Vector2(-24.0, get_viewport_rect().size.y - BOTTOM_MARGIN)
	lbl.size                 = Vector2(get_viewport_rect().size.x, 20.0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", LOGO_COLOR)
	if _mono_font:
		lbl.add_theme_font_override("font", _mono_font)
	add_child(lbl)

func _create_debug_menu_button() -> void:
	if not DebugConfig.DEBUG_MODE:
		return
	_debug_btn              = Button.new()
	_debug_btn.text         = "DEBUG"
	_debug_btn.size         = Vector2(200, 70)
	_debug_btn.position     = Vector2(20.0, 20.0)
	_debug_btn.z_index      = 10
	_debug_btn.add_theme_font_size_override("font_size", 22)
	_debug_btn.add_theme_color_override("font_color", Color("#FFFFFF"))
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color("#E0334D")
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	_debug_btn.add_theme_stylebox_override("normal",  style)
	_debug_btn.add_theme_stylebox_override("hover",   style)
	_debug_btn.add_theme_stylebox_override("pressed", style)
	_debug_btn.add_theme_stylebox_override("focus",   style)
	_debug_btn.pressed.connect(_on_debug_menu_pressed)
	add_child(_debug_btn)

func _on_debug_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://debug_menu.tscn")

# playbutton.png is 907x437, but the drawn face only occupies x 27%-68% and
# y 20%-80% of that rect — so by default a TextureButton treats a wide band of
# empty purple either side of the face as clickable, and Play fires on taps
# that never touched the character. That was the false positive.
#
# An alpha mask is NOT the fix: the art is line work, only 3.9% of its pixels
# are opaque, and the face's interior is fully transparent (the purple is the
# background showing through). create_from_image_alpha() would leave only the
# pencil strokes tappable, which is far worse for a child.
#
# Instead: a filled ellipse inscribed in the drawn face's own ink bounding box,
# so the whole visible face is tappable and nothing outside it is. Built once,
# row by row via set_bit_rect (263 calls, not 396k per-pixel writes).
const FACE_INK_MIN : Vector2 = Vector2(245.0,  88.0)   # measured from the texture's alpha
const FACE_INK_MAX : Vector2 = Vector2(615.0, 350.0)
const FACE_HIT_PAD : float   = 8.0    # slightly forgiving at the very edge

func _build_face_click_mask() -> BitMap:
	var bm := BitMap.new()
	bm.create(Vector2i(int(PB_TEX_SIZE.x), int(PB_TEX_SIZE.y)))
	var c  : Vector2 = (FACE_INK_MIN + FACE_INK_MAX) * 0.5
	var r  : Vector2 = (FACE_INK_MAX - FACE_INK_MIN) * 0.5 + Vector2.ONE * FACE_HIT_PAD
	var y0 : int = int(maxf(c.y - r.y, 0.0))
	var y1 : int = int(minf(c.y + r.y, PB_TEX_SIZE.y - 1.0))
	for y in range(y0, y1 + 1):
		var dy : float = (float(y) - c.y) / r.y
		if absf(dy) > 1.0:
			continue
		var dx : float = r.x * sqrt(1.0 - dy * dy)
		var x0 : int = int(maxf(c.x - dx, 0.0))
		var w  : int = int(minf(dx * 2.0, PB_TEX_SIZE.x - float(x0)))
		if w > 0:
			bm.set_bit_rect(Rect2i(x0, y, w, 1), true)
	return bm


func _apply_shader(node: CanvasItem, color: Color) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 tint_color : source_color;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tint_color.rgb, tex.a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint_color", color)
	node.material = mat

# ─── Arc helpers ──────────────────────────────────────────────────────────────
func _letter_final_pos(idx: int) -> Vector2:
	var t   : float = float(idx) / float(LETTERS.size() - 1)
	var deg : float = ARC_MIN_DEG + t * (ARC_MAX_DEG - ARC_MIN_DEG)
	var rad : float = deg_to_rad(deg)
	var cx  : float = (_vp_cx - 22.0) + ARC_RADIUS * sin(rad)
	var cy  : float = ARC_CENTER.y - ARC_RADIUS * cos(rad)
	return Vector2(cx - LETTER_W * 0.5, cy - LETTER_H * 0.5)

func _letter_final_rot(idx: int) -> float:
	var t : float = float(idx) / float(LETTERS.size() - 1)
	return ARC_MIN_DEG + t * (ARC_MAX_DEG - ARC_MIN_DEG)

# ─── Node creation ────────────────────────────────────────────────────────────
func _create_letters() -> void:
	for i in range(LETTERS.size()):
		var lbl := Label.new()
		lbl.text                 = LETTERS[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size                 = Vector2(LETTER_W, LETTER_H)
		lbl.pivot_offset         = Vector2(LETTER_W * 0.5, LETTER_H * 0.5)
		lbl.position             = _letter_final_pos(i)
		lbl.rotation_degrees     = _letter_final_rot(i)
		lbl.modulate.a           = 0.0
		lbl.z_index              = 3
		if _head_font:
			lbl.add_theme_font_override("font", _head_font)
		lbl.add_theme_font_size_override("font_size", LETTER_SIZE)
		lbl.add_theme_color_override("font_color", LOGO_COLOR)
		add_child(lbl)
		_letters.append(lbl)

func _create_words() -> void:
	for i in range(WORD_TEXTS.size()):
		var lbl := Label.new()
		lbl.text                 = WORD_TEXTS[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size                 = Vector2(WORD_W[i], 34.0)
		lbl.position             = Vector2(_word_x[i], WORDS_Y)
		lbl.modulate.a           = 0.0
		lbl.z_index              = 3
		if _font:
			lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
		lbl.add_theme_color_override("font_color", LOGO_COLOR)
		add_child(lbl)
		_words.append(lbl)

# ─── Birds-flocking drift ─────────────────────────────────────────────────────
# ─── Intro animation ──────────────────────────────────────────────────────────
# The Title opens straight into its idle state: the letters fade in already
# near their own arc anchors and immediately ride the breeze, and the face
# begins breathing. No long automatic overture — the button is live at
# ~0.8s so a child never waits to touch it. The flocking-and-settling moment
# now belongs to the tap (see _settle_title), where the child causes it.
func _animate_in() -> void:
	for i in range(_letters.size()):
		_letters[i].position         = _idle_anchor(i)
		_letters[i].rotation_degrees = _letter_final_rot(i)
		_letters[i].modulate.a       = 0.0
	# "Learning Sounds" stays hidden (alpha 0 from _create_words) until the tap.

	_drift_t      = 0.0
	_drift_damp   = 1.0
	_drift_active = true
	_start_sway()

	for i in range(_letters.size()):
		var t := create_tween()
		t.tween_property(_letters[i], "modulate:a", 1.0, 0.5)

	await get_tree().create_timer(0.8).timeout
	_can_press = true

# ─── Idle motion: eight letters on a breeze, one face breathing ─────────────
# Each letter traces a slow Lissajous loop around its own anchor: two sine
# oscillations, X and Y, on DIFFERENT periods. That difference is what makes it
# read as air rather than sway — a single sine per letter is a visible
# left-right slide, and a shared period with staggered phase is the sequential
# march we do not want. Every letter has its own X period, Y period, rotation
# period and three phases, all spread by an irrational step, so no two letters
# and no two axes ever share a cadence and nothing repeats on a visible cycle.
#
# Driven from _process() rather than tweens: a Lissajous curve is continuous,
# and chaining tweens to approximate one produces audible corners at the joins.
# It also gives a single amplitude multiplier (_drift_damp) that the tap can
# ease to zero, which is what makes the letters glide to a stop instead of
# snapping.
const DRIFT_X_AMP   : float = 13.0   # each letter stays in a ~26x20 box around its
const DRIFT_Y_AMP   : float = 10.0   # anchor; with ~94px idle gaps two neighbours can
                                      # close to ~68px at worst, wider than any glyph
const DRIFT_ROT_AMP : float = 4.0    # degrees

const DRIFT_X_PERIOD : Array[float] = [3.10, 4.09, 3.48, 4.47, 3.86, 3.24, 4.23, 3.62]
const DRIFT_Y_PERIOD : Array[float] = [2.85, 3.78, 3.21, 2.64, 3.56, 2.99, 2.42, 3.34]
const DRIFT_R_PERIOD : Array[float] = [3.89, 3.36, 4.22, 3.69, 3.15, 4.02, 3.49, 2.95]
const DRIFT_X_PHASE  : Array[float] = [0.82, 4.70, 2.30, 6.18, 3.78, 1.38, 5.26, 2.87]
const DRIFT_Y_PHASE  : Array[float] = [3.64, 1.24, 5.12, 2.73, 0.33, 4.21, 1.81, 5.69]
const DRIFT_R_PHASE  : Array[float] = [1.82, 5.70, 3.30, 0.90, 4.79, 2.39, 6.27, 3.87]

# IDLE anchors are a deliberately DIFFERENT set of positions from the final
# arc: the word floats wider and higher while adrift, then the tap draws it
# inward and downward into the tighter approved arc. The first pass had this
# backwards (idle sat 26px BELOW final), which is why the letters crowded the
# head and each other.
#   spread — each letter's horizontal distance from the logo centre, x1.5, so
#            idle gaps are ~94px against the final arc's ~63px
#   lift   — the whole idle word sits this far above where it lands
#   flatten — the idle word also sits FLATTER than the final arc. Keeping the
#             arc's full 75px curve made the idle band as tall as the entire
#             space above the head, so the end letters grazed the head top
#             while the middle ones touched the screen edge; there was no lift
#             that satisfied both. At 0.45 the idle word occupies ~34px of
#             vertical range instead of 75, clearing both. The tap then curves
#             them back down into the approved arc, which reads as a gather.
const IDLE_SPREAD  : float = 1.50
const IDLE_LIFT    : float = 60.0
const IDLE_FLATTEN : float = 0.45

# The face keeps the approved idle behaviour: stationary, breathing in place.
const FACE_BREATHE_SCALE  : float = 1.012   # 1.2%
const FACE_BREATHE_PERIOD : float = 3.18
const FACE_BREATHE_PHASE  : float = 0.45

# ─── Tap settle timing ──────────────────────────────────────────────────────
const SETTLE_DAMP_DUR   : float = 0.25   # breeze eases to nothing
const SETTLE_RISE_DUR   : float = 0.90   # each letter into its arc slot
const SETTLE_STAGGER    : float = 0.07   # S -> P
const SETTLE_STILL_DUR  : float = 0.20   # beat of stillness once the arc is formed
const SUBTITLE_RISE_DUR : float = 0.50
const TITLE_HOLD_DUR    : float = 0.60   # whole logo seen complete before it leaves


func _idle_anchor(i: int) -> Vector2:
	# Spread about the same x the arc is built around, so the idle word stays
	# centred on the face while opening up; lift and flatten it vertically.
	var pivot_x : float = (_vp_cx - 22.0) - LETTER_W * 0.5
	var f : Vector2 = _letter_final_pos(i)
	return Vector2(
		pivot_x + (f.x - pivot_x) * IDLE_SPREAD,
		(_final_top_y - IDLE_LIFT) + (f.y - _final_top_y) * IDLE_FLATTEN)


func _process(delta: float) -> void:
	if not _drift_active:
		return
	_drift_t += delta
	for i in range(_letters.size()):
		var a : Vector2 = _idle_anchor(i)
		var dx : float = sin(TAU * _drift_t / DRIFT_X_PERIOD[i] + DRIFT_X_PHASE[i]) * DRIFT_X_AMP
		var dy : float = sin(TAU * _drift_t / DRIFT_Y_PERIOD[i] + DRIFT_Y_PHASE[i]) * DRIFT_Y_AMP
		var dr : float = sin(TAU * _drift_t / DRIFT_R_PERIOD[i] + DRIFT_R_PHASE[i]) * DRIFT_ROT_AMP
		_letters[i].position         = a + Vector2(dx, dy) * _drift_damp
		_letters[i].rotation_degrees = _letter_final_rot(i) + dr * _drift_damp


func _start_sway() -> void:
	# Idle-motion on switch. Letters ride _process(); only the face breathes.
	for old_t in _breathe_tweens:
		if old_t != null and old_t.is_valid():
			old_t.kill()
	_breathe_tweens.clear()
	var base : Vector2 = Vector2.ONE * BTN_SCALE
	$PlayButton.scale = base
	var half : float = FACE_BREATHE_PERIOD * 0.5
	var t := create_tween().set_loops()
	t.tween_interval(FACE_BREATHE_PHASE)
	t.tween_property($PlayButton, "scale", base * FACE_BREATHE_SCALE, half) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property($PlayButton, "scale", base, half) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_breathe_tweens.append(t)


func _stop_idle_motion() -> void:
	_drift_active = false
	for t in _breathe_tweens:
		if t != null and t.is_valid():
			t.kill()
	_breathe_tweens.clear()
	for lbl in _letters:
		lbl.scale = Vector2.ONE
	$PlayButton.scale    = Vector2(BTN_SCALE, BTN_SCALE)
	$PlayButton.position = _pb_home


# Tap response: the breeze dies, the letters rise into the arc, the subtitle
# arrives, the finished logo is held. Then the existing exit/route runs.
func _settle_title() -> void:
	# 1. Ease the breeze to nothing — letters glide to their anchors rather than
	#    stopping dead wherever the sine happened to be.
	var damp := create_tween()
	damp.tween_property(self, "_drift_damp", 0.0, SETTLE_DAMP_DUR) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await damp.finished
	_drift_active = false

	# 2. Rise into the approved arc, S -> P.
	for i in range(_letters.size()):
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_letters[i], "position", _letter_final_pos(i), SETTLE_RISE_DUR) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(_letters[i], "rotation_degrees", _letter_final_rot(i), SETTLE_RISE_DUR) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(SETTLE_STAGGER).timeout
	await get_tree().create_timer(SETTLE_RISE_DUR - SETTLE_STAGGER).timeout

	# 3. A beat of stillness so the arc registers as arrived.
	await get_tree().create_timer(SETTLE_STILL_DUR).timeout

	# 4. "Learning Sounds" — hidden for the whole idle state until now.
	for i in range(WORD_TEXTS.size()):
		_words[i].position   = Vector2(_word_x[i], 830.0)
		_words[i].modulate.a = 1.0
		var t := create_tween()
		t.tween_property(_words[i], "position:y", WORDS_Y, SUBTITLE_RISE_DUR) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(SUBTITLE_RISE_DUR).timeout

	# 5. Hold the completed title.
	await get_tree().create_timer(TITLE_HOLD_DUR).timeout

func _create_gnb_entry() -> void:
	const BTN_W  : float = 72.0
	const BTN_H  : float = 56.0
	const BAR_W  : float = 44.0
	const BAR_H  : float = 7.0
	const BAR_GAP: float = 9.0

	_gnb_btn             = Button.new()
	_gnb_btn.text        = ""
	_gnb_btn.size        = Vector2(BTN_W, BTN_H)
	_gnb_btn.position    = Vector2(get_viewport_rect().size.x - BTN_W - 20.0, 20.0)
	_gnb_btn.z_index     = 10
	_gnb_btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)

	var blank := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		_gnb_btn.add_theme_stylebox_override(s, blank)

	var x0 : float = (BTN_W - BAR_W) * 0.5
	var y0 : float = (BTN_H - (BAR_H * 3.0 + BAR_GAP * 2.0)) * 0.5
	for i in range(3):
		var bar := ColorRect.new()
		bar.color        = LOGO_COLOR
		bar.size         = Vector2(BAR_W, BAR_H)
		bar.position     = Vector2(x0, y0 + i * (BAR_H + BAR_GAP))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gnb_btn.add_child(bar)

	_gnb_btn.pressed.connect(_on_gnb_pressed)
	add_child(_gnb_btn)

func _on_gnb_pressed() -> void:
	get_tree().change_scene_to_file("res://gnb_home.tscn")

# ─── Play button pressed ──────────────────────────────────────────────────────
func _on_play_pressed() -> void:
	if _pressed or not _can_press:
		return
	_pressed = true
	# Disconnected immediately, and _pressed guards re-entry, so the tap sway
	# below can never be triggered twice.
	$PlayButton.pressed.disconnect(_on_play_pressed)
	# Idle -> settled title -> existing exit/route. _settle_title() only
	# presents; it never touches progression. The line below it is the original
	# call, unchanged, and everything downstream of it is untouched.
	await _settle_title()
	_animate_out_then_route()

# ─── BGM looping ──────────────────────────────────────────────────────────────
func _on_bgm_finished() -> void:
	$BGMPlayer.play()

# ─── Forward progression routing ──────────────────────────────────────────────
# Single source of truth for "what's next": walk ReleaseScope.PROGRESSION_ORDER
# and enter the first released Level that isn't complete yet. If every
# released Level is complete, the walk naturally lands on "prep" — its
# existing entry behavior (see _enter_level) already resumes at set 1 there,
# since PrepLevelProgress.reset() persists prep_set_index back to 0 the
# moment Prep completes (prep_transition.gd). No state is reset from here.
func _is_level_completed(level_id: String) -> bool:
	return ReleaseScope.is_level_completed(level_id)

func _progression_start_index() -> int:
	# Legacy pre-choice-button saves that explicitly chose the Level 1 path
	# and never touched Prep: exclude Prep from the forward walk, exactly as
	# the old chose_level1_path branch did.
	if SaveManager.is_chose_level1_path() \
			and not SaveManager.is_prep_completed() \
			and SaveManager.get_prep_set_index() == 0:
		return ReleaseScope.PROGRESSION_ORDER.find("level1")
	return 0

func _forward_target_level_id() -> String:
	var order : Array[String] = ReleaseScope.PROGRESSION_ORDER
	for i in range(_progression_start_index(), order.size()):
		var lid : String = order[i]
		if not ReleaseScope.is_level_released(lid):
			break
		if not ReleaseScope.is_level_enterable(lid):
			# Released but with no scene in this build — a configuration error,
			# not a player state. Skip it rather than selecting a level Title
			# cannot enter (that used to fall through _enter_level()'s match and
			# leave the Title frozen after its exit animation).
			push_error("ReleaseScope: '%s' is released but has no scene." % lid)
			continue
		if not _is_level_completed(lid):
			return lid
	return "prep"  # everything currently released is complete — new Prep cycle

# Generic for every level in PROGRESSION_ORDER — no per-level arms.
#   never entered  -> that level's Intro (Case B: a level newly released in an
#                     app update is met by its Intro, never by raw gameplay).
#                     Entry is recorded by the Intro's Ready button, not here,
#                     so abandoning the Intro leaves the level not-entered.
#   already entered -> resume at the saved set index (Case A / Case C).
# Prep keeps its historical behaviour through the same path: its pre-existing
# path_chosen flag is what _infer_entered_levels() derives "prep entered" from,
# and set_path_chosen() still fires on that first Intro so Where Am I's
# show_all and the legacy _progression_start_index() branch are unaffected.
func _enter_level(level_id: String) -> void:
	if not ReleaseScope.is_level_enterable(level_id):
		push_error("Title: '%s' has no scene to enter." % level_id)
		return
	if not SaveManager.has_entered_level(level_id):
		if level_id == "prep":
			SaveManager.set_path_chosen()
		LevelIntroState.level_id = level_id
		get_tree().change_scene_to_file("res://level_intro.tscn")
		return
	ReleaseScope.restore_index(level_id)
	get_tree().change_scene_to_file(ReleaseScope.scene_for(level_id))

# ─── Exit animation + routing ─────────────────────────────────────────────────
func _animate_out_then_route() -> void:
	_stop_idle_motion()

	var bgm_fade := create_tween()
	bgm_fade.tween_property($BGMPlayer, "volume_db", -40.0, 1.0)
	bgm_fade.tween_callback($BGMPlayer.stop)

	for i in range(LETTERS.size()):
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_letters[i], "position",
			_letter_final_pos(i) + FLY_OUT[i], 0.60) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.tween_property(_letters[i], "modulate:a", 0.0, 0.45)
		await get_tree().create_timer(0.55).timeout

	var slide_x : Array[float] = [-280.0, get_viewport_rect().size.x + 300.0]
	for i in range(WORD_TEXTS.size()):
		var t := create_tween()
		t.tween_property(_words[i], "position:x", slide_x[i], 0.55) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		await get_tree().create_timer(0.65).timeout

	# PlayButton hand-wave before scene change
	var base_x : float = $PlayButton.position.x
	var bt := create_tween().set_parallel(false)
	bt.tween_property($PlayButton, "position:x", base_x + 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x - 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x + 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x - 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x + 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x - 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x,        0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await bt.finished
	await get_tree().create_timer(1.0).timeout

	_enter_level(_forward_target_level_id())
