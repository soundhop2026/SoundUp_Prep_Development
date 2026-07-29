# Pre-level Set Transition Scene — Design Spec

## Context
This spec covers the **set transition scene in Pre-level** specifically. Currently, when a player finishes a set in Pre-level, the PlayButton bounces several times with no sound, then abruptly cuts to the next set's first round. This spec replaces that with a structured, rewarding transition sequence.

This transition plays **26 times in Pre-level** (26 sets across 6 groups), so it needs to stay short and low-fatigue — this is a smaller, more frequent beat than the level-graduation Coronation scene (which plays 6 times and should remain the bigger celebration).

Note: the sound asset and general structure are designed to be reusable across future levels' set transitions as well, not exclusively hardcoded to Pre-level — but this spec's numbers (26 sets, 6 groups) refer to Pre-level's current curriculum.

## Sequence Structure

| Phase | Duration | Visual | Audio |
|---|---|---|---|
| Bounce 1 | ~0.35–0.4s | PlayButton bounce, discrete up-down | `SoundUp_set_transition_sfx`, pitch_scale step 1 |
| Bounce 2 | ~0.35–0.4s | Bounce | Same file, pitch_scale step 2 |
| Bounce 3 | ~0.35–0.4s | Bounce | Same file, pitch_scale step 3 |
| Bounce 4 | ~0.35–0.4s | Bounce | Same file, pitch_scale step 4 |
| Bob | 2.0s | Gentle continuous idle bob, lower amplitude than bounce | **Silence** (intentional — not a missing sound) |
| Advance | — | Next set's first round loads immediately | — |

**Total transition length:** ~3.4–3.6 seconds

## Audio Details
- **Source file:** `SoundUp_set_transition_sfx` (located in `SoundUp_prep_Development / BGM&effect`)
- **License:** Pixabay Content License — no attribution required
- Single source file, pitch-shifted per bounce using `AudioStreamPlayer.pitch_scale` — do NOT create 4 separate audio files
- Suggested starting pitch steps: `[1.0, 1.08, 1.16, 1.24]` — tune by ear once in-engine, ascending pitch reinforces the "building up" feel of the bounce phase
- Bob phase is deliberately silent — no audio asset needed for this phase. After 4 punchy hits, silence lets the moment land without overloading a young player's attention, and protects against fatigue across 26 repeats.

## Visual Details
- **Bounce phase:** 4 discrete, sharper bounces (larger amplitude)
- **Bob phase:** smaller, gentler continuous bobbing motion (visibly softer than the bounce phase — should read as "settling," not "still excited")
- Bounce height should be noticeably larger than bob height (e.g. bounce ~20px vs bob ~6px, as a starting point — adjust to match feel)

## Why This Structure
- Silent abrupt transitions felt "serene but no stimuli" for a 3–9 year old audience — needed clearer feedback that a set was completed
- Ascending pitch across identical bounces creates variety cheaply, without needing multiple sound files, so 26 repeats don't feel monotonous
- Bounce (exciting/short) → Bob (calm/settling) → Advance creates a clear beginning-middle-end arc for the reward moment, rather than the reward and the cut happening at the same instant
- Kept clearly smaller in scale than Coronation (set-level vs. group-level), preserving a two-tier celebration hierarchy: sets get a quick, low-key acknowledgment; group completions get the bigger payoff

## Reference Implementation
A draft `game.gd` function (`play_set_transition()`) implementing this sequence with tween-based bounce/bob motion and pitch-stepped audio has already been discussed and can be provided alongside this spec if useful as a starting point — not a required implementation, just a reference for the intended timing/logic.
