extends CanvasLayer

# Sits at layer=-100, permanently behind all scene content (which renders at layer 0).
# Each scene calls SceneBackground.set_color() at the top of _ready() so that
# the render-thread gap frame between scene changes shows the correct level color
# instead of the engine clear color (dark gray).

var _bg : ColorRect = null

func _ready() -> void:
	layer = -100
	_bg                = ColorRect.new()
	_bg.anchor_left    = 0.0
	_bg.anchor_top     = 0.0
	_bg.anchor_right   = 0.0
	_bg.anchor_bottom  = 0.0
	_bg.color          = Color(0.431, 0.710, 1.0, 1.0)  # sky blue — safe first-frame default
	_bg.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_bg.size           = get_viewport().get_visible_rect().size
	add_child(_bg)
	get_tree().root.size_changed.connect(_on_size_changed)

func set_color(c: Color) -> void:
	if _bg:
		_bg.color = c

func _on_size_changed() -> void:
	if _bg:
		_bg.size = get_viewport().get_visible_rect().size


# ─── Shared mobile-alignment fix ────────────────────────────────────────────
# window/stretch/mode="canvas_items" + aspect="expand" (project.godot) means
# the real viewport is NOT always 1280x720 — on any device wider than 16:9
# (virtually every phone in landscape: iPhone ~19.5:9, Android ~20:9), Godot
# expands the width beyond 1280 rather than letterboxing. Every gameplay
# scene was built assuming a fixed 640 center / 1280 width, so on those
# devices everything sits left of true center (or inset from the true right
# edge). Desktop/editor windows are usually close enough to 16:9 that this
# stays invisible there — see SOUNDHOP_MOBILE_ALIGNMENT_FIX notes in the
# affected scenes for how these are used.
func viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


# Scenes built around a design-time assumption of x=640 as center should add
# this to every such X coordinate: center_offset() = (true center) - 640.
# On a 1280-wide viewport this is exactly 0 (no-op). Uniformly shifts a
# whole composition right to sit on the real center without touching any
# relative spacing between elements.
func center_offset() -> float:
	return viewport_size().x / 2.0 - 640.0


# ─── Shared left-edge reference (Listen bar / Round-cube row) ─────────────────
# The Listen bar's left edge is the canonical reference for any other
# left-anchored gameplay element that must start at the same X — currently
# the Round-cube progress row. Both should read this one constant instead of
# each hardcoding its own literal, so they can never drift apart the way
# Prep's cube row (90) and its Listen bar (100) once did. Left-anchored by
# design (matches back_button.gd's convention), not affected by
# center_offset() — do not add centering math to this value.
const GAMEPLAY_LEFT_X : float = 100.0


# ─── Shared GNB ("Where Am I") flag button ──────────────────────────────────
# Same corner-clearance treatment approved for Level 1 / Prep. Level 1.5,
# Level 2 and Level 2.5 had each kept their own older, tighter (20, 20)
# margin and no scale-up -- reading from here instead means that can't
# happen again.
const GNB_BTN_SIZE   : Vector2 = Vector2(72.0, 56.0)
const GNB_BTN_SCALE  : float   = 1.65
const GNB_BTN_MARGIN : Vector2 = Vector2(92.0, 72.0)

func gnb_button_position() -> Vector2:
	return Vector2(
		viewport_size().x - GNB_BTN_SIZE.x - GNB_BTN_MARGIN.x,
		GNB_BTN_MARGIN.y
	)

# GNB_BTN_SIZE/scale are applied with pivot_offset = GNB_BTN_SIZE/2 (its own
# center) in every scene's _create_gnb_flag(), so scaling it up never moves
# its center -- only gnb_button_position() (the corner before scale) affects
# where that center actually lands. These two read the true rendered box back
# out, for anything that needs to line up against the real GNB button rather
# than its pre-scale corner.
func gnb_button_center() -> Vector2:
	return gnb_button_position() + GNB_BTN_SIZE / 2.0

func gnb_button_visual_left_edge() -> float:
	return gnb_button_center().x - (GNB_BTN_SIZE.x * GNB_BTN_SCALE) / 2.0

func gnb_button_visual_bottom_edge() -> float:
	return gnb_button_center().y + (GNB_BTN_SIZE.y * GNB_BTN_SCALE) / 2.0


# ─── Shared EvalPlayButton position ─────────────────────────────────────────
# A fixed canonical X, and a gap held to GNB's LEFT, both fought the fixed
# image-row layout: every gameplay scene positions its answer images at its
# own hand-picked X values, so a "just left of GNB" gap could (and did, on
# several actual scenes) land squarely on top of whichever image happens to
# sit near GNB's width at a given viewport size.
#
# Stacking EvalPlayButton BELOW Where Am I instead of beside it inherits
# GNB's own already-correct, always-on-screen X entirely -- same column, not
# an independent width-derived one -- so it can never drift into image
# territory: the images sit well below this row on every current scene.
# Center-aligned under GNB (tried right-edge-aligned instead -- that shifted
# it far enough right to overlap the third answer image on some rounds, so
# reverted back to this).
const EVAL_GNB_VERTICAL_GAP : float = 40.0

func eval_button_position(visual_size: Vector2) -> Vector2:
	var gnb_center : Vector2 = gnb_button_center()
	var gnb_bottom : float   = gnb_button_visual_bottom_edge()
	return Vector2(
		gnb_center.x - visual_size.x / 2.0,
		gnb_bottom + EVAL_GNB_VERTICAL_GAP
	)


# Every scene's EvalPlayButton must render at this same physical size, not
# just share the same center. Before this, each scene picked its own size
# independently (Prep/Level 1's texture*scale, Level 1.5's own constant,
# Level 2/2.5's own smaller constant) and could silently drift apart --
# which is exactly what happened: Level 1's .tscn scale (0.15) didn't match
# Prep's approved reference (0.21), so its button ended up both visibly
# smaller AND, because eval_button_position() centers on visual_size, sitting
# lower on screen than every other scene's button.
# Confirmed too small on a real iPhone even after the first pass, so this is
# now the original approved reference (190.47 x 91.77) x 1.65, not that first
# pass.
const EVAL_BTN_VISUAL_SIZE : Vector2 = Vector2(190.47 * 1.65, 91.77 * 1.65)

# For scenes using a real textured button (game.gd, prep_game.gd): pass the
# button's native, unscaled texture size in and get back the uniform scale
# that makes it render at EVAL_BTN_VISUAL_SIZE. Set this at runtime instead
# of hand-picking a scale value in the .tscn -- a hand-picked value is what
# drifted last time.
func eval_button_scale(native_texture_size: Vector2) -> float:
	return EVAL_BTN_VISUAL_SIZE.x / native_texture_size.x
