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
