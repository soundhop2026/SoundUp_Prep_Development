# SoundHop v1.0.0 — Release Notes

**Release date:** July 28, 2026
**Git tag:** [`v1.0.0`](../../.git) → commit `aaa7349` (`aaa73491101fec6dce142ddce390b6671a8da392`)
**Status:** First Google Play release candidate (Internal Testing → production upload)

---

## Version Information

| Field | Value |
|---|---|
| App label | SoundHop |
| Package (applicationId) | `com.acron.learningsounds` |
| versionCode | 1 |
| versionName | 1.0.0 |
| Build file | `build/android/LearningSounds.aab` (77,635,443 bytes) |
| Signed with | Production upload keystore (`learningsounds-upload.jks`, alias `learningsounds-upload`) — stored outside the repo at `C:\Users\user\AndroidKeystores\soundhop-learningsounds\`, never committed |
| Engine | Godot 4.5.1, GDScript 2.0, mobile renderer, gradle build (AGP 8.6.1 / Gradle 8.11.1) |
| `DEBUG_MODE` | `false` — QA/debug tooling (debug menu, scene-jump shortcuts) disabled for this build |

---

## Major Features

- **Prep Level** (26 sets) and **Level 1** (17 sets, 331 rounds) — full sound-first phonemic awareness gameplay, no letters ever shown, consistent with the product's core "sound comes first" philosophy.
- **Back button — product-wide navigation rule, now locked in CLAUDE.md**: unlimited review in every round-based level (Prep, Level 1, Level 1.5, Level 2 variants). Players can revisit any earlier round in the current set but can never skip forward. A round's contribution to score/pass-percentage/stars/completion is locked in on its *first* completed attempt only — replaying never changes the outcome.
- **Parent Gate + Choose Plan flow** — the free/premium boundary sits after Prep Set 2. Billing is intentionally **stubbed**, not implemented, for this release (see Technical Notes).
- **"Learning Sounds" branding pass** — title screen and GNB home subtitle renamed from "Start with the Sound" to "Learning Sounds," with the title screen's word-fly-in/fly-out animation geometry recalculated for the new phrase.

---

## Parent Gate — Final Behavior

- **Free content:** Prep Set 1 and Set 2 only (`PrepLevelProgress.FREE_SET_COUNT = 2`).
- **Crossing the boundary:** completing Set 2 does not auto-continue. The Prep set-transition screen shows a **"Keep Hopping!"** button instead.
- **Parent Gate verification:** pressing "Keep Hopping!" opens the Premium Intro scene, where the Louis face itself *is* the gate — press and hold for **7 seconds** to proceed. No popup, no question challenge.
- **Choose Plan screen:** Monthly / Yearly / Restore Purchases / **Not Now**. Selecting a plan currently grants access via a dev stub (`_purchase_plan()` → `_on_purchase_success()` immediately) rather than a real store transaction.
- **"Not Now" (both the Parent Gate hold screen and the Choose Plan screen) → Title Scene.** This was fixed during final QA — earlier behavior looped back into the gate or dead-ended. Declining costs the player nothing: `PrepLevelProgress.advance()` (the only thing that persists `prep_set_index`) never runs until the boundary is actually passed, so the save stays parked at Set 2 and the player can freely replay Set 1–2 indefinitely from the title screen.
- A **"Premium Flow Demo"** shortcut and a **Set 2 (Boundary)** scene-jump exist in the debug menu for QA — inert in this build since `DEBUG_MODE = false`.

---

## Major Fixes (this release cycle)

- **Round scoring integrity fix**: `game.gd`, `prep_game.gd`, `game2.gd`, `game25.gd`, and `game15.gd` previously re-counted a round's score on every replay via Back, with no de-duplication — letting a player inflate a set's pass percentage by backing up and cleanly replaying already-correct rounds. Fixed with a `_scored_rounds` guard (per `round_index`, reset per set) so a round's score locks in on first completion only.
- **Removed `game15.gd`'s inconsistent `BACK_USES_MAX = 2` press cap** — Back is now unlimited on every round-based screen, matching the locked product-wide rule.
- **`X_gz.wav` / `X_ks.wav` broken reference fix** — these files were briefly renamed to `gz.wav`/`ks.wav`, which silently broke phoneme audio in 16 round-data JSON files (Level 1 and Prep sets 1D/1E/1F) still referencing the old names. Restored to the expected filenames.
- **Level 1.5 short-vowel sync fix** — `SoundUp_level1.5_word_sounds/short_i.wav` and `short_u.wav` are an intentional duplicate of Level 2's copies (confirmed identical by git blob hash pre-update); updating only the Level 2 originals left Level 1.5 stale. Both copies are now back in sync.
- **GNB "What is SoundHop" back button** was spilling 30px past the bottom of its 90px purple header band into the content area below — recentered.
- **Title screen debug button** was overlapping the "Prep Level" / "Level 1" choice buttons when both were visible (blocking taps in the overlap region due to z-index) — relocated to the top-left corner, clear of everything else.
- **`export_presets.cfg` cross-contamination fix** — running the APK testing preset caused Godot to rewrite the whole file and mix the AAB and APK presets' settings together (the "Android"/AAB preset ended up with `export_format=0`, a `.apk` path, and no keystore lines). Restored before the final build; worth re-checking after any future APK test export.

---

## Audio Updates

Phonemes updated and verified against `data/phonemes.json` (the shared Level 1.5 mapping) plus all Level 1/Prep round-data JSON references:

- **Consonants:** J, ng, X_gz, X_ks, V, F, H, L, Q, R, W, Z
- **Vowels:** short_i, short_u (Level 2, mirrored into Level 1.5)

All are mono, 48kHz/16-bit WAV. `Q.wav` is intentionally longer than sibling phonemes (~1.5s vs ~0.4s) — a shorter trim introduced an audible mechanical artifact at the tail; length was kept for clean audio over uniformity.

## Image Updates

Root cause identified and fixed across the batch: `_place_button()` in `game.gd`/`prep_game.gd` scales each choice image to fit a 220×220 box based on **raw canvas size**, not the drawn subject's bounding box. Images exported on large canvases with excess padding rendered far smaller on-screen than tightly-cropped siblings, even at nominally correct choice-box size.

- **Re-cropped to match content bounds** (canvas trimmed close to the subject): `bag`, `bus`, `celery`, `cent`, `cereal`, `circus`, `city`, `crab`, `drum`, `exact`, `example`, `exhaust`, `exotic`, `farm`, `game`, `girl`, `guitar`, `gym`, `jam`, `kitchen`, `kite`, `leaf`, `mix`, `moon`, `mouse`, `mug`, `ox`, `pot`, `purse`, `quiet`, `road`, `six`, `taxi`, `tiger`, `train`, `truck`, `van`, `volcano`, `yak`, `yard`, `zebra`, `zigzag`, `zipper`, `zoo`.
- **`exact.png`** was additionally redrawn as a new concept (a boy holding up two identical drawings) — the old checklist/calendar composition was both too dark to read and an extreme wide aspect ratio (701×279) that rendered short on-screen even after cropping; the new artwork fixes both.
- **`jungle.png`** had a separate problem — correct canvas size, but linework drawn in uniformly medium-gray pencil shading (darkest pixel measured at luminance 29, ~2.7% of pixels near-black), which washed out against Prep's green background. Re-inked with solid black contours (darkest pixel now 0, ~15.6% near-black).
- Text/letters appearing inside images (e.g. `cereal.png`'s box text, `taxi.png`'s roof sign, `cent.png`'s coin text, `game.png`'s board-game titles) is an intentional, accepted exception to the product's "no letters" rule — kept specifically where a generic silhouette would otherwise be ambiguous (a plain box vs. a labeled cereal box).

---

## Technical Notes for Future Reference

- **JDK compatibility**: this project's gradle template (AGP 8.6.1 / Gradle 8.11.1) requires **JDK 21**, not JDK 25 — Gradle 8.11.1 doesn't support Java 25's class file version. Android Studio's bundled JBR (`C:\Program Files\Android\Android Studio\jbr`) works. Godot's `export/android/java_sdk_path` editor setting has been observed to spontaneously revert to the system JDK between sessions — **always re-verify it before running an export.**
- **Lint Vital crash workaround**: `lintVitalAnalyzeStandardRelease` can fail with an internal AGP/lint tooling exception (`MessageBus... Already disposed`) unrelated to any real lint finding. Fixed via `checkReleaseBuilds false` in `android/build/build.gradle`. This file lives in the gitignored `android/` folder and will need reapplying if the Android build template is ever reinstalled.
- **Keystore signing via env vars**: release signing is passed through `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD` at export time rather than stored in `export_presets.cfg`, keeping secrets out of git. The keystore itself lives entirely outside the repo.
- **Android SDK**: Platform 35 + Build-Tools 35.0.0 installed alongside the machine's existing 36.1 to match this Godot version's tested AGP 8.6.1 combination.
- **Billing is not implemented in v1.0.0.** `choose_plan.gd`'s `_purchase_plan()` is a clearly-marked single integration point for real Google Play Billing (Android) / StoreKit (iOS) — out of scope for this release.
- **Package name is permanent** once uploaded to Play Console. `com.acron.learningsounds` contains no hyphens or underscores, so the identical string is also valid as an iOS `CFBundleIdentifier` if/when a companion build targets the App Store.
