class_name DebugConfig

# Single switch for all QA debug tooling (Debug Menu button on title,
# menu itself, scene-jump/save-utility logic). Set false before any
# release build — every debug-only code path checks this flag.
const DEBUG_MODE : bool = false

# Set true by a debug_menu.gd scene jump right before changing scene; the
# target scene's real-gameplay-entry point (where play counts increment)
# consumes and resets it once, so a QA shortcut never counts toward a
# child's real play counts.
static var debug_launch : bool = false
