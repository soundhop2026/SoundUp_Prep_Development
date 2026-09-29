extends Node2D

const PURPLE    : Color  = Color("#4B0082")
const AMBER     : Color  = Color("#FFB703")
const WHITE     : Color  = Color("#FFFFFF")

# ─── Logo ───────────────────────────────────────────────────────────────────
# The face stays hand-drawn artwork (GNB_SOUNDHOP_face_only.png). The SOUNDHOP
# letters are now real Schoolbell text on an arc above it, replacing the baked
# GNB_SOUNDHOP_letters_only.png treatment — the brand rule is that SOUNDHOP
# rendered as part of the PlayButton character/logo system is Schoolbell, and
# existing artwork is preserved only where it has been explicitly approved to
# remain artwork. The letters PNG is left in the repository, simply unused.
#
# Note for anyone reading git history: an earlier code-built version of these
# letters was tried and reverted for look and feel. This is a deliberate second
# attempt under the locked brand system, using the approved Title Scene
# treatment as its visual reference rather than inventing a new one.
#
# GNB Home is a STATIC navigation screen. It borrows the Title's arc geometry
# and nothing else — no idle drift, no settle, no tap behaviour.
const LOGO_FACE_IMG    : String = "res://UI_assets/GNB_SOUNDHOP_face_only.png"

# The arc is derived from this screen's own face, measured from the texture's
# alpha rather than eyeballed. Thresholding matters: sampling at alpha>8 finds
# stray faint marks from y=187 and an ink centre of x=618, but the real drawn
# head — rows carrying substantial ink — runs y 239..422, x 495..754, centred
# on x=625. The first pass used the faint bounds, which is why the wordmark
# floated ~47px clear of the head instead of resting on it.
#
# Wordmark scaled to 70%: letters 112 -> 78pt AND radius 300 -> 210, together,
# so the gaps between letters shrink with the glyphs and the arc keeps its
# proportions. Shrinking the glyphs alone would have left them scattered along
# an unchanged curve. Span and construction are unchanged.
#
# Centre y 405 seats the end letters ~10px into the top of the head, so the
# wordmark reads as hair on the character rather than a headline above it.
# The horizontal centre of the whole logo lockup. NOT 640: the face artwork is
# not centred in its own texture, so the drawn head's ink centre — and therefore
# the wordmark above it and the tagline below it — sits at 625. The nav boxes
# and Subscribe deliberately stay on the geometric 640; they are the card grid,
# not the logo. Both the arc and the tagline read this one constant so they can
# never drift apart.
const LOGO_CENTER_X    : float = 625.0

const LOGO_LETTERS     : Array[String] = ["S","O","U","N","D","H","O","P"]
const LOGO_LETTER_SIZE : int     = 78            # 112 x 0.7
const LOGO_LETTER_W    : float   = 45.0          # 64 x 0.7; widest glyph at 78pt is 43px
# LETTER_H must not be below the font's own line height (108px at 78pt) — a
# Label cannot shrink under its content, so a smaller box silently clamps up and
# the glyph centre lands (108 - LETTER_H)/2 BELOW the arc point the maths asked
# for. The 0.7-scaled 62 did exactly that and buried the wordmark 23px too deep
# in the head. At 108 the box is the real line height, so position + size/2 is
# genuinely the arc point and ARC_CENTER means what it says.
const LOGO_LETTER_H    : float   = 108.0
# y 293 seats the wordmark just above the head with a small visible gap, never
# cutting into the outline. Chosen by measuring the head's own top contour per
# column — requiring a real stroke (8+ consecutive ink pixels) rather than the
# first pixel found, because the texture carries stray 1-2px marks above the
# head that make a naive scan report the crown ~45px too high in places.
#
# Clearance from each letter's baseline to the contour beneath it, at y 290:
#   O +7   U +5   N +7   D +7   H +2   O +3   (S and P sit off the face)
#
# 293 is the furthest down the arc can go while every letter still clears the
# outline. The binding letter is H: the hand-drawn head is not symmetric, and
# its right side rises ~3px higher than the mirrored left (H's contour 119.3 vs
# U's 122.3), so H runs out of room first. Measured clearance by offset:
#   +2px -> H +3.0 clean   +3px -> H +2.0 clean
#   +4px -> H +1.0 touching   +5px -> H 0.0   +8px -> H -3.0 cutting the outline
# Anything past +3 trades the "no overlap" rule for a few more pixels of drop.
#
# The face itself does not move: only ARC_CENTER changes, not LOGO_TOP.
const LOGO_ARC_CENTER  : Vector2 = Vector2(LOGO_CENTER_X, 293.0)
const LOGO_ARC_RADIUS  : float   = 210.0         # 300 x 0.7
const LOGO_ARC_MIN_DEG : float   = -42.0
const LOGO_ARC_MAX_DEG : float   =  42.0
const LOGO_SIZE         : Vector2 = Vector2(604.0, 382.0)
# ─── Vertical composition ───────────────────────────────────────────────────
# GNB Home is laid out as one stack, not four independently placed elements:
#
#   18   logo unit (SOUNDHOP + face)  281 tall, ends 299
#   46   breathing room
#   345  Learning Sounds               36 tall, ends 381
#   58   breathing room
#   439  navigation boxes             170 tall, ends 609
#   32   breathing room
#   641  Subscribe                     36 tall, ends 677
#   43   bottom margin
#
# The four content heights are fixed and untouched (522px total), so the only
# lever is the 198px of margin and gaps between them. Previously those gaps ran
# 5 / 9 / 33 / 9 — everything crammed together and the stack pressed against the
# bottom edge, which is why nothing read as a separate layer and Subscribe was
# easy to miss.
#
# LOGO_TOP is NEGATIVE and that is correct: the logo box is 604x382 but the
# drawn face's ink does not begin until ~214px into it, so the box's empty top
# hangs off-screen while the face itself sits at y 116..299. Moving the group is
# a single shift applied to both LOGO_TOP and LOGO_ARC_CENTER.y, keeping the
# letters and the face locked together as one logo unit.
const LOGO_TOP          : float   = -98.0
const LOGO_FACE_SCALE   : float   = 1.10   # face only, relative to its size in the original art

const LOGO_SUBTITLE_Y     : float = 332.0   # 33px clear of the face — closer, still its own layer
const LOGO_SUBTITLE_SIZE  : int   = 24

var _font : Font = null

func _ready() -> void:
	SceneBackground.set_color(AMBER)
	# Every text node on this screen is a major navigation label — the tagline,
	# the two menu buttons and Subscribe — so they all take the bold weight.
	# Andika Bold = major information/navigation hierarchy.
	_font = UIFonts.learning_bold()

	# Background
	var bg := ColorRect.new()
	bg.color        = AMBER
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_back_button()
	_build_logo()
	_build_menu_buttons()
	_build_subscribe_link()


func _build_back_button() -> void:
	var btn := TextureButton.new()
	btn.texture_normal      = load("res://UI_assets/back_button.png") as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size                = Vector2(90, 90)
	btn.position            = Vector2(30, 30)
	btn.z_index             = 10
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 c : source_color = vec4(0.294, 0.0, 0.51, 1.0);
void fragment() { vec4 t = texture(TEXTURE, UV); COLOR = vec4(c.rgb, t.a); }"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("c", PURPLE)
	btn.material = mat
	btn.pressed.connect(_on_back_pressed)
	add_child(btn)


func _build_logo() -> void:
	_build_logo_image()
	_build_logo_subtitle()


func _build_logo_image() -> void:
	var pos : Vector2 = Vector2((1280.0 - LOGO_SIZE.x) * 0.5, LOGO_TOP)

	# Face first (behind), scaled up around its own center — both layers
	# share the exact same source canvas, so this position/size also lines
	# up the letters layer drawn on top with no extra offset math needed.
	if ResourceLoader.exists(LOGO_FACE_IMG):
		var face := TextureRect.new()
		face.texture       = load(LOGO_FACE_IMG) as Texture2D
		face.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size          = LOGO_SIZE
		face.position      = pos
		face.pivot_offset  = LOGO_SIZE * 0.5
		face.scale         = Vector2(LOGO_FACE_SCALE, LOGO_FACE_SCALE)
		face.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		face.z_index       = 1
		add_child(face)

	_build_logo_letters()


# Eight Schoolbell letters on the arc above the head — same construction as the
# Title's, so the hand-drawn character carries across, but placed once and left
# alone. Static by design: this is a navigation screen.
func _build_logo_letters() -> void:
	var face : Font = UIFonts.character()
	var span : float = LOGO_ARC_MAX_DEG - LOGO_ARC_MIN_DEG
	for i in range(LOGO_LETTERS.size()):
		var t   : float = float(i) / float(LOGO_LETTERS.size() - 1)
		var deg : float = LOGO_ARC_MIN_DEG + t * span
		var rad : float = deg_to_rad(deg)
		var lbl := Label.new()
		lbl.text                 = LOGO_LETTERS[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size                 = Vector2(LOGO_LETTER_W, LOGO_LETTER_H)
		lbl.pivot_offset         = Vector2(LOGO_LETTER_W, LOGO_LETTER_H) * 0.5
		lbl.position             = Vector2(
			LOGO_ARC_CENTER.x + LOGO_ARC_RADIUS * sin(rad) - LOGO_LETTER_W * 0.5,
			LOGO_ARC_CENTER.y - LOGO_ARC_RADIUS * cos(rad) - LOGO_LETTER_H * 0.5)
		lbl.rotation_degrees     = deg
		lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		lbl.z_index              = 2
		if face:
			lbl.add_theme_font_override("font", face)
		lbl.add_theme_font_size_override("font_size", LOGO_LETTER_SIZE)
		lbl.add_theme_color_override("font_color", PURPLE)
		add_child(lbl)


func _build_logo_subtitle() -> void:
	var lbl := Label.new()
	lbl.text                 = "Learning Sounds"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(1280.0, 36.0)
	# Shifted 15px left so the tagline centres on the LOGO (x 625), not the
	# geometric middle (640). The face artwork is not centred in its own texture,
	# so the drawn head and the SOUNDHOP arc both sit on 625 — a full-width
	# centred label put the tagline 15px right of the mark it belongs to. The
	# nav boxes and Subscribe stay on 640: they are the card grid, not the logo.
	# Same reasoning as the Title scene, whose tagline centres on its own logo.
	lbl.position             = Vector2(LOGO_CENTER_X - 640.0, LOGO_SUBTITLE_Y)
	lbl.z_index              = 3
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", LOGO_SUBTITLE_SIZE)
	lbl.add_theme_color_override("font_color", PURPLE)
	add_child(lbl)


func _build_menu_buttons() -> void:
	const BTN_W  : float = 500.0
	const BTN_H  : float = 170.0
	const GAP    : float =  40.0
	const BTN_Y  : float = 439.0   # 58px below Learning Sounds — the widest gap in the stack
	const RADIUS : int   =  24

	var start_x : float = (1280 - BTN_W * 2 - GAP) * 0.5

	var labels  : Array[String] = ["What's SoundHop", "Where am I"]
	var targets : Array[String] = ["res://gnb_whats_soundhop.tscn", "res://gnb_where_am_i.tscn"]

	for i in range(2):
		var btn := Button.new()
		btn.text         = labels[i]
		btn.size         = Vector2(BTN_W, BTN_H)
		btn.position     = Vector2(start_x + i * (BTN_W + GAP), BTN_Y)
		btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)
		btn.z_index      = 5

		if _font:
			btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 38)
		btn.add_theme_color_override("font_color",         PURPLE)
		btn.add_theme_color_override("font_hover_color",   PURPLE)
		btn.add_theme_color_override("font_pressed_color", PURPLE)
		btn.add_theme_color_override("font_focus_color",   PURPLE)

		var style := StyleBoxFlat.new()
		style.bg_color                   = WHITE
		style.border_color               = PURPLE
		style.border_width_top           = 3
		style.border_width_bottom        = 3
		style.border_width_left          = 3
		style.border_width_right         = 3
		style.corner_radius_top_left     = RADIUS
		style.corner_radius_top_right    = RADIUS
		style.corner_radius_bottom_left  = RADIUS
		style.corner_radius_bottom_right = RADIUS

		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("#FFF4CC")

		btn.add_theme_stylebox_override("normal",  style)
		btn.add_theme_stylebox_override("hover",   hover)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus",   style)

		btn.pressed.connect(_on_menu_pressed.bind(targets[i]))
		add_child(btn)


func _build_subscribe_link() -> void:
	# Small, low-key direct entry to the subscription screen — visible to all
	# users, not just App Review. Existing paywall (prep_transition.gd, after
	# the 2 free Prep sets) is untouched; this just adds a second door into
	# the SAME premium_intro.tscn -> choose_plan.tscn flow, without setting
	# PremiumIntroState.context_id, so it falls into the same "prep" default
	# branch a genuinely fresh, never-played install already uses today.
	const BTN_W : float = 200.0
	const BTN_H : float =  36.0

	var btn := Button.new()
	btn.text         = "Subscribe"
	btn.size         = Vector2(BTN_W, BTN_H)
	# Lifted 675 -> 641: it used to sit 9px off the bottom edge, easy to miss.
	btn.position     = Vector2((1280.0 - BTN_W) * 0.5, 641.0)
	btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)
	btn.z_index      = 5

	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color",         PURPLE)
	btn.add_theme_color_override("font_hover_color",   PURPLE)
	btn.add_theme_color_override("font_pressed_color", PURPLE)
	btn.add_theme_color_override("font_focus_color",   PURPLE)

	var blank := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(s, blank)

	btn.pressed.connect(_on_subscribe_pressed)
	add_child(btn)


func _on_subscribe_pressed() -> void:
	get_tree().change_scene_to_file("res://premium_intro.tscn")


func _on_back_pressed() -> void:
	if GNBState.return_scene != "":
		var target := GNBState.return_scene
		GNBState.return_scene = ""
		get_tree().change_scene_to_file(target)
	else:
		get_tree().change_scene_to_file("res://title.tscn")


func _on_menu_pressed(target: String) -> void:
	get_tree().change_scene_to_file(target)
