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
