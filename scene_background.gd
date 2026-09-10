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
