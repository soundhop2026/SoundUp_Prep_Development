extends Node2D

# ─── THROWAWAY test harness — Level 1.5 Sound Quest Long Transition ───────
# Not part of the game. Instantiates Level15SoundQuestTransitions on its
# own and calls play_long() directly so the choreography can be watched
# and tuned without playing through a whole Quest type to trigger it.
#
# Run from the project root:
#   /Applications/Godot.app/Contents/MacOS/Godot --path . res://level15_long_transition_test.tscn
#
# Loops the Long Transition forever with a short pause between runs.
# Esc quits. Setting the env var LT_SHOT_DIR to an absolute folder path
# makes it save a PNG frame every LT_SHOT_INTERVAL seconds during the
# first run (for inspection from a headless/CI-style launch), then quit.
#
# Background: the Long Transition no longer covers the screen — it plays on
# whatever the calling Sound Quest scene set. Quest A/B's sky blue is used
# here as a representative Sound Quest gameplay color (same literal as
# level15_sound_quest_ab.gd's BG_COLOR).

const BG_COLOR : Color = Color(0.431, 0.710, 1.0, 1.0)
const PAUSE_BETWEEN_RUNS : float = 1.0
const LT_SHOT_INTERVAL   : float = 0.35

var _transitions : Level15SoundQuestTransitions = null
var _shot_dir : String = ""
var _shot_index : int = 0
var _shooting : bool = false

func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = get_viewport_rect().size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_transitions = Level15SoundQuestTransitions.new()
	# Plays the production defaults (8.0s / fade on the exit downbeat /
	# 0.5s tail, approved 2026-09-17). To A/B a different endpoint, set
	# long_dur / long_bgm_fade_lead / long_bgm_fade_len here before
	# add_child — the real Quest scenes never touch them.
	add_child(_transitions)

	_shot_dir = OS.get_environment("LT_SHOT_DIR")
	_run_loop()


func _run_loop() -> void:
	await get_tree().create_timer(0.5).timeout
	while true:
		if _shot_dir != "":
			_shooting = true
			_capture_frames()
		await _transitions.play_long()
		_shooting = false
		if _shot_dir != "":
			await get_tree().process_frame
			get_tree().quit()
			return
		await get_tree().create_timer(PAUSE_BETWEEN_RUNS).timeout


func _capture_frames() -> void:
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	while _shooting:
		await RenderingServer.frame_post_draw
		var img : Image = get_viewport().get_texture().get_image()
		img.save_png("%s/frame_%02d.png" % [_shot_dir, _shot_index])
		_shot_index += 1
		await get_tree().create_timer(LT_SHOT_INTERVAL).timeout


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
