class_name EditorPlatformPreview

# Editor-only presentation preview. OS.has_feature("editor") is only ever
# true when running via the Godot editor's Play button — exported
# APK/AAB/IPA builds never carry this feature tag, so ACTIVE_PREVIEW can
# never reach a real build no matter what it's left set to.
#
# Presentation-only: use this ONLY where OS.get_name() picks wording/URLs
# for display. Never use it for billing SDK selection or any other real
# platform-gated behavior — those must keep calling OS.get_name() directly.

enum Preview { NONE, ANDROID, IOS }

const ACTIVE_PREVIEW : Preview = Preview.NONE   # flip here to preview a platform in-editor

static func presentation_platform() -> String:
	if OS.has_feature("editor") and ACTIVE_PREVIEW != Preview.NONE:
		return "Android" if ACTIVE_PREVIEW == Preview.ANDROID else "iOS"
	return OS.get_name()
