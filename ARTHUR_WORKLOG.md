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
