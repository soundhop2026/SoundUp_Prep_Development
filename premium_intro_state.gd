class_name PremiumIntroState

# Set context_id before routing to premium_intro.tscn — determines what
# "Continue" does once the Parent Gate has been passed. Mirrors
# LevelIntroState's pattern (simple string state, not a closure) so it
# survives the scene change cleanly.
static var context_id : String = "prep"
