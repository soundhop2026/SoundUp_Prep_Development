class_name PremiumIntroState

# Set context_id before routing to premium_intro.tscn — determines what
# happens once access is granted (purchase or restore). Mirrors
# LevelIntroState's pattern (simple string state, not a closure) so it
# survives the scene change cleanly.
#
# Granting access never writes progress by itself: only CONTEXT_PREP_BOUNDARY
# moves the player, and only to the Set right after the one they just passed.
const CONTEXT_PREP_BOUNDARY : String = "prep_boundary"   # passed the last free Set; continue to the next
const CONTEXT_PREP_LOCKED   : String = "prep_locked"     # tried to enter a premium Set or Sound Quest; return to Where Am I
const CONTEXT_PREMIUM_LOCKED : String = "premium_locked" # premium gameplay refused or interrupted (no verified subscription); return to Where Am I
const CONTEXT_GNB           : String = "gnb"              # opened from GNB Home; return there, progress untouched

static var context_id : String = CONTEXT_GNB

# Index of the Set the player just passed, recorded only for CONTEXT_PREP_BOUNDARY
# so the grant never depends on whatever PrepLevelProgress.current_index holds
# by the time the purchase or restore completes.
static var boundary_index : int = -1
