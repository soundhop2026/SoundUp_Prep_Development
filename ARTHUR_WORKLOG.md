# ARTHUR WORKLOG — SoundHop

## 2026-08-11

- **CONFIRMED — TestFlight Build 2:** Regular Prep gameplay worked, but Sound Quests were consistently skipped at Group boundaries. GNB `Where Am I` showed Sound Quest entries, but they would not launch.
- **CONFIRMED — Mac/Godot:** Direct play was normal.
- **RESOLVED — Root cause:** `SoundQuestState` used runtime `DirAccess` directory enumeration for word discovery. In the packed exported `.pck`, imported-resource enumeration caused the PNG filter to find zero files, leaving word pools empty and causing Sound Quest skips.
- **RESOLVED — Fix:** Replaced runtime directory enumeration with the checked-in/generated `sound_quest_word_manifest.json` and explicit resource-path loading. Sound Quest gameplay, design, and routing were not changed.
- **CONFIRMED — Export verification:** Actual packed export tests passed for all 6 Prep groups and Level 1 Sound Quest word pools for both iOS and the Android preset.
- **CONFIRMED — Android:** The submitted AAB was affected by the same packed-resource bug and must be replaced with Android `versionCode 3`.
- **CONFIRMED — Source control:** Sound Quest fix commit `355901d` was pushed to GitHub via GitHub Desktop.
- **CONFIRMED — iOS Build 3:** The signed iOS Version 1.0 Build 3 IPA was verified to contain the fix in its final packed `.pck`, uploaded through Transporter, and was processing in App Store Connect/TestFlight at the end of the session.
- **PENDING — iOS field verification:** Actual TestFlight device verification remains pending.
- **NEXT — Android Build 3:** On Windows, pull latest `main`, build the replacement AAB with `versionCode 3`, verify Sound Quest against the actual packed/release build, then upload the replacement to Google Play.
- **DEFERRED — Mobile gameplay alignment:** Gameplay scenes are horizontally shifted left on both iPhone and Galaxy phones; tablet gameplay and other phone scenes are centered. Decision **LOCKED**: defer the mobile gameplay alignment fix to the late-August next-level update and do not mix it into Build 3.

This file is maintained separately from Collie's `Worklog.md`.

## 2026-08-15

- **LOCKED — Official terminology:** Game 2 uses `Level` → `Set` → `Round`. Do not use `Phase`, `Stage`, `Layer`, or `Lesson`.
- **LOCKED — Curriculum roadmap:** Level 1 — Alphabet Names; Level 2 — Single Consonant Sounds; Level 3 — Short Vowel Sounds + Rime Families. Version 1 releases through Level 3.
- **LOCKED — Future curriculum:** Level 4 — Let's Read (CVC); Level 5 — Letter Sounds (digraphs, blends, clusters); Level 6 — Let's Read (CCVC, CVCC, CCCVC, and later patterns); Level 7 — Letter Sounds (long vowels and diphthongs); Level 8 — Let's Read (mixed reading using all learned sounds); Level 9 — Encoding (words, phrases, sentences); Level 10 — Advanced Encoding (expanded writing fluency).
- **LOCKED — Progression rule:** Game 2 has no bridge levels such as 1.5 or 2.5.
- **LOCKED — Design standards:** Game scene background `#F5E6CC`; title scene background `#FFB703`; game scene font color `#4B0082`.
- **LOCKED — Letter assets:** Andika is the asset-creation font. Alphabet letters are delivered only as transparent PNG assets; runtime font rendering is not used for them.
- **FINALIZED — Project structure:** `game2_specs` is the source of truth. Implementation/version control follows the GitHub workflow, and the Game 2 folder structure is aligned across Mac and Windows.

## 2026-08-27–28

- **CONFIRMED — Apple App Review 2.1(b):** The reviewer could not find the Monthly and Yearly in-app purchases.
- **CONFIRMED — Existing release access:** The subscription flow became accessible only after completing the first two free Prep Sets, each containing 10 rounds, for a total of 20 regular Prep rounds. Sound Quest did not count toward those 20 rounds.
- **RESOLVED — Subscription entry point:** Added a directly accessible Subscribe entry to GNB Home that is visible to all users and leads through premium intro → plan selection → Monthly/Yearly.
- **CONFIRMED — iOS Build 6 clean-build issue:** A clean build exposed a `godot-storekit2` Swift `next(isolation:)` linker problem. Changing the minimum iOS version from 14 to 15 alone did not resolve it.
- **RESOLVED — StoreKit plugin patch:** Removed the plugin source's iOS 18.4-only dead branch and retained the existing `product.currentEntitlement` path as a minimal patch, then rebuilt the plugin.
- **CONFIRMED — iOS Build 6 archive:** Archive and signed IPA creation succeeded from clean caches. The IPA was verified with `MinimumOSVersion` 15.0 and `CFBundleVersion` 6.
- **CONFIRMED — App Store submission:** Transporter upload succeeded. Monthly, Yearly, iOS App 1.0 Build 6, and the SoundHop Learning Access subscription group were resubmitted together as four items. Final status was Waiting for Review.
- **PENDING — Google Play Target API:** Google notified us that SoundHop must meet the Target API requirement by 2026-08-31. The exact required API level is not yet confirmed and remains TBD.
- **NEXT — Google Play verification:** In the next Windows session, open Play Console → 문제 보기, confirm the actual required Target API level, and only then make the change. Do not infer the API level.

## 2026-08-28

- **OPERATING PRINCIPLE — Prevent rework to create speed:** Speed does not come from skipping steps; it comes from a process that prevents rework.
- **LOCKED SEQUENCE:** Protect what is already verified → narrow the root cause using evidence → make the minimum necessary change → verify the actual release artifact → confirm the final submission state before closing.
- **TODAY'S EXAMPLE — Android release:** The API 36 / versionCode 6 release demonstrated this sequence: verified work was preserved, the blocking cause was isolated from evidence, the change stayed minimal, the release artifact itself was checked, and the Play submission state was confirmed before close-out.
- **SCOPE DISCIPLINE:** Newly discovered issues that are unrelated to an active release fix must be recorded for later and not mixed into the release change.

## 2026-09-10 — Game 1

- **VERIFIED — Parent Gate interaction:** Parent Gate requires a 3-second press-and-hold, shown by a bottom-up amber fill during the hold.
- **RESOLVED — Mobile-only horizontal centering:** The root cause was gameplay content being positioned from a fixed/design-space center instead of the phone's runtime viewport center. Game 1 gameplay scenes now share the runtime viewport-center solution so phone layouts center horizontally while non-phone layouts remain correct.
- **RESOLVED — Apple Silicon iPhone Simulator:** Restored iPhone Simulator testing on Apple Silicon. Godot 4.5.1's installed iOS export template lacked the required iOS Simulator `arm64` support; the export-template repair was made durable so it survives clean/export use rather than depending on a one-off generated-project edit.
- **VERIFIED — Mobile UI positioning:** Corrected mobile placement for `PointedHand`, `EvalPlayButton`, and `Where Am I` so these elements align correctly and avoid the prior overlap/offset behavior.
- **LOCKED — Where Am I lifecycle:** Pressing `Where Am I` immediately stops gameplay audio. Returning restores the same Round in an active, playable state without advancing the Round or changing progress.
- **PENDING — Galaxy physical-device verification:** Verification on a physical Galaxy device remains required before promoting these Game 1 changes to Framework. Framework was not modified.

## 2026-09-11

- **FINALIZED — Sound Quest architecture:** Main Game owns progression; Coronation celebrates Main Game completion; Where Am I is the navigation hub; Sound Quest is optional bonus content entered through Where Am I. Sound Quest is no longer a mandatory Group-boundary gate or a prerequisite for Coronation or the next Level.
- **LOCKED — Main progression:** Preserve `Prep Main Game completion -> Coronation -> Level 1 Intro -> Ready -> Level 1` and `Level 1 Main Game completion -> Coronation -> Level 1.5 Intro -> Ready -> Level 1.5`. The earlier proposal to route Coronation to Where Am I and blink the next Level was withdrawn. Existing Coronation/Intro flow and dormant Level 1 direct-entry/Set A code remain outside this change.
- **FINALIZED — Bonus navigation:** `Where Am I -> Sound Quest -> Where Am I`. All six Sound Quest scene types have a Where Am I exit. Completing Sound Quest returns to Where Am I without advancing or completing Main Game progression. Level 1.5 Sound Quest A-F access is included; forced chaining between different Quest types is removed while existing within-scene pairs are preserved.
- **NOT FINALIZED — Level 1.5 card placement:** Showing all A-F entries under Group A is an implementation placement, not a locked design decision. Do not infer a one-to-one mapping between Quest letters and Main Game Groups.
- **FINALIZED — Play counts:** Main Game Sets and Sound Quest count once per real gameplay session when the first Round starts, including first play, replay, and a session exited early. Debug/QA launches are excluded. Sound Quest cards show their own play counts distinctly from completed Main Set cells, without a completion checkmark.
- **CONFIRMED / RETAINED — Persistence audit:** Main Game saves Set progress, not the exact Round. Full app relaunch starts at Round 1 of that Set. Closing the Where Am I overlay with Back resumes the living scene at its current Round; selecting a Set card reloads the scene from Round 1, even in the same app session. Sound Quest does not persist internal Quest/Round position: leaving ends that Quest session, and re-entry or relaunch starts the selected content from its beginning. Decision after the audit: no persistence changes.
- **COMPLETED — QA tooling:** Separate commit `ca2b391c2658e22d2b3b664125539b72de3d0dba` (`DEVELOPMENT: add Prep final-set Coronation QA shortcut`) adds `Prep Last Set (Coronation Check)` for playing the actual final Prep Set F2 (index 25). Its purpose is to verify real F2 completion -> Coronation -> Level 1 Intro, not merely jump into Coronation. `DebugConfig.DEBUG_MODE = false` is confirmed in the committed source. The available conversation does not establish completion of that final manual end-to-end check; no test pass is claimed here.
- **CONFIRMED — Completed push milestone:** GitHub `refs/heads/main` was checked directly at `ca2b391c2658e22d2b3b664125539b72de3d0dba` before this worklog update. This includes gameplay commit `eb6a46658d4b8414e9af7d5477397d93f98e9a6e` (`GAMEPLAY: make Sound Quest optional and fix play counts`) and the separate QA shortcut commit. Earlier Android Emulator commits `edfc703` and `6547d3a` remain separate in history. This records a source-control milestone, not a new store build, submission, or device-test result.
- **SCOPE — Arthur worklog only:** This documentation update is separate from Collie's pending work and `Worklog.md`. No gameplay, subscription/review, editor-preview, or project-instruction changes belong in this commit.

## 2026-09-28 — Game 1 Level 1.5 Progression, Where Am I & Font System

The QA results below record the results confirmed in the 2026-09-28 conversation; this documentation update does not rerun gameplay QA.

### 1. Generic Incremental Release Progression Framework

- **COMPLETED / VERIFIED:** Game 1 now uses a generic progression framework for incremental releases, reusable for Level 1.5 and future Levels 2, 2.5, and beyond.
- **LOCKED — Entry sequence:** Previous Level completion -> new Level release -> Title -> Level Intro -> Ready -> actual gameplay entry. Release alone does not grant immediate access.
- **LOCKED — Entered state:** Record a Level as `entered` on its first actual gameplay entry. Previously entered Levels resume from saved Set progress without repeating Intro.
- **VERIFIED — Old-save compatibility:** The framework handles an existing 1.0.1 save with Level 1 already completed when updating to 1.0.2. Legacy saves infer prior entry from existing progress evidence so established access is preserved.

### 2. Where Am I Unlock Rule and Old-save QA

- **LOCKED:** Previous-Level completion does not grant direct access to the next Level through Where Am I. The new Level must be released and entered through normal progression, including Intro and actual gameplay entry.
- **CONFIRMED:** Title routing and Where Am I use the same `has_entered_level()` source of truth.
- **MANUAL QA — PASS:** Start with a 1.0.1-style Level 1 completion save -> simulate Level 1.5 release -> confirm Level 1.5 is LOCKED in Where Am I before Intro -> Title opens Level 1.5 Intro -> Ready enters Level 1.5 gameplay -> confirm Level 1.5 is UNLOCKED in Where Am I.

### 3. Persisted Reset Index Safety

- **RESOLVED:** Generic Intro routing exposed stale persisted Set indexes: Level 1 and Level 2 reset their runtime position without saving index 0. Both resets now persist index 0.
- **RESOLVED:** Restoring an invalid/out-of-range saved Set index safely clamps it to 0.
- **VERIFIED:** Regression tests passed, as recorded in the conversation.

### 4. Level 1.5 Sound Quest — Where Am I Structure

- **RESOLVED:** Manual QA found all six Sound Quest A-F cards under Group A. Review of the learning structure confirmed that each Quest corresponds to its matching Main Game Group. This finalizes the placement left open in the 2026-09-11 entry.

| Group | Main Sets | Bonus card |
| --- | --- | --- |
| A | A1, A2 | Sound Quest A |
| B | B1, B2 | Sound Quest B |
| C | C1, C2 | Sound Quest C |
| D | D1, D2 | Sound Quest D |
| E | E1-E4 | Sound Quest E |
| F | F | Sound Quest F |

- **SCOPE:** Card redistribution only; Sound Quest gameplay, completion logic, review counts, unlocking, and routing retain their existing behavior.
- **MANUAL QA — PASS:** All six Group screens were checked and confirmed working correctly.

### 5. Level 1.5 Learning Information — Follow-up

- **PENDING — Phoneme-list audit:** Consider showing actual learning phonemes in Where Am I Group headers alongside/in place of functional descriptions such as `initial phoneme ID`. Audit the actual Level 1.5 dataset to establish the exact A-F target phonemes before deciding the header content. Do not infer or invent phoneme lists.

### 6. SOUNDHOP Shared Font System v1.0

- **FINALIZED:** Game 1 SOUNDHOP and Game 2 LetterHopHop share the same font roles, assigned by text function.

| Font | Role | Scope |
| --- | --- | --- |
| Schoolbell | Character / Brand Accent | Letters on the PlayButton head only |
| Andika | Learning / Information / Navigation | Intro text; all GNB and Where Am I text; Level/Set/Quest titles; learning descriptions; phoneme/letter information; progress information |
| JetBrains Mono | Action / Transaction | Ready to Play button and all Subscription UI |

- **LOCKED:** Schoolbell's thin strokes limit its use to the PlayButton character accent. Ready to Play uses JetBrains Mono within the otherwise Andika Intro. Apply these roles consistently in both games without arbitrary font mixing.
- **PENDING — Implementation QA:** Replace legacy 210 Pencil under the shared system and visually check size, weight, and spacing during implementation. This entry records the decision; it does not apply font changes.

### 7. Release Discipline

- **LOCKED:** Level 1.5 release simulation was for QA only. Temporary QA release-scope changes must not ship.
- **LOCKED:** Change the production release gate, public version, Android `versionCode`, and iOS build number only during final 1.0.2 release preparation after remaining QA is complete.
- **SOURCE CONTROL:** Before this documentation update, Mac Collie's work was committed as `0172420` (generic entry progression), `435da08` (persisted reset indexes), and `fd0e53b` (per-Group Sound Quest cards), with a clean working tree. The production release gate remained `level1`.
- **SCOPE — Arthur worklog only:** Keep this entry in a separate commit containing only `ARTHUR_WORKLOG.md`. Production release scope, version/build numbers, gameplay files, font files, and Collie's `Worklog.md` are outside this update. No push is requested.

## 2026-09-29 — Shared UI Typography Framework & GNB Home Finalization

This entry records decisions and QA results confirmed in the 2026-09-29 conversation. It refines the SOUNDHOP Shared Font System recorded on 2026-09-28 §6, which is now superseded on two points: Andika is split into Regular and Bold roles, and Schoolbell is no longer restricted to the Title PlayButton head.

### 1. Global Typography Framework Established

- **FINALIZED:** Game 1 now has a role-based UI typography system intended to be shared by SoundHop games rather than redesigned separately for each game. Typography is assigned by what the text **is**, not by which screen it sits on.

| Font | Role | Scope |
| --- | --- | --- |
| Schoolbell Regular | Character / logo lettering | SOUNDHOP lettering visually integrated with the PlayButton character |
| Andika Regular | Learning / information | Explanatory, informational and supporting UI text |
| Andika Bold | Major information hierarchy | Product-name headings, major titles, section headings, primary GNB/navigation labels |
| JetBrains Mono Regular / Bold | Action / transaction | Buttons, action instructions, subscription and pricing interactions, transactional surfaces |

- **LOCKED — Real weights only:** Use the actual font-weight files. Do not synthesize Bold.
- **REFINES 2026-09-28 §6:** Andika was previously recorded as a single role; it is now Regular for information content and Bold for information structure. Schoolbell was previously recorded as "PlayButton head only"; its scope is now SOUNDHOP lettering integrated with the PlayButton character wherever that occurs, which includes GNB Home.

### 2. Shared Product Surfaces

- **LOCKED:** GNB, Parent Gate and Subscription are shared product surfaces across games. Game 2 / LetterHopHop inherits the same typography framework and hierarchy rather than establishing a separate font system.
- **SHARED:** typography roles; hierarchy principles; GNB framework; Parent Gate framework; Subscription framework.
- **GAME-SPECIFIC:** character and artwork; colors; layout where appropriate; gameplay; learning design; game identity.
- **PRINCIPLE:** *Standardize the framework, not the learning design.*

### 3. GNB Home Redesign Finalized

- **RESOLVED:** The previous GNB Home SOUNDHOP logo treatment was replaced.
- **FINAL STATE:** PlayButton face retained as character artwork; SOUNDHOP rendered in Schoolbell Regular above the PlayButton head so the two read as one character/logo unit; Learning Sounds in Andika Bold; What's SoundHop, Where am I and Subscribe following the approved Andika hierarchy.
- **RESOLVED — Vertical composition:** Rebuilt as one stack with clear breathing space between PlayButton/logo -> Learning Sounds -> navigation cards -> Subscribe.
- **RESOLVED — Optical alignment:** Final visual QA caught a 15 px difference between screen center and the logo's true visual center. Learning Sounds is now aligned to the logo center rather than blindly centered to the screen; the navigation cards and Subscribe intentionally remain on the screen center, as they belong to the card grid rather than the logo.
- **LOCKED:** Final GNB Home visual state approved. No further design changes.

### 4. What's SoundHop Refinement

- **RESOLVED:** Refined under the same hierarchy — major headings and card titles in Andika Bold, explanatory copy in Andika Regular, spacing tightened where needed, and PlayButton artwork presentation corrected.
- **CONFIRMED:** Final visual result approved.

### 5. Other Verified Surfaces

- **CONFIRMED — Visually checked:** Title, Level Intro, GNB Home, What's SoundHop, Where am I, Parent Gate, Subscription.
- **CONFIRMED:** Title retains Schoolbell for the PlayButton-integrated SOUNDHOP character lettering; product-name "SoundHop" headings in UI use Andika Bold; action and transaction language continues to use JetBrains Mono.

### 6. Implementation / Release Safety

- **MANUAL QA — PASS:** Final live GNB navigation verification passed 14/14.
- **PACKAGE AUDIT — PASS:** Schoolbell, Andika and JetBrains Mono present; required Godot imports present; font licenses present; production font paths resolve; temporary QA files absent.
- **CONFIRMED — Release gate unchanged:** `HIGHEST_RELEASED_LEVEL_ID = "level1"`.
- **CONFIRMED — No version/build change.**
- **CONFIRMED — No unintended changes** to gameplay, progression, routing, save, subscription, Parent Gate, billing or release logic.
- **SOURCE CONTROL:** Font/UI framework commit `95befe3f9c26deef5c15d4a5234b9f0e3746dd25` — "Standardize Game 1 UI typography and GNB presentation". Mac `main` was pushed and verified equal to `origin/main` with a clean working tree.
- **NEXT — Windows:** The push also delivered the four previously local commits, so Windows is now five commits behind `origin/main` and must Fetch/Pull before its next commit.

### 7. Open Item

- **PENDING — Legacy 210-font references:** Five legacy 210-font references remain intentionally unresolved and are documented in the shared font framework. Do not migrate them automatically; each requires an explicit role/design decision.

### 8. Scope

- **SCOPE — Arthur worklog only:** This entry is committed separately, containing only `ARTHUR_WORKLOG.md`. Code, framework documentation, assets, release scope, version/build numbers and Collie's `Worklog.md` are outside this update.
