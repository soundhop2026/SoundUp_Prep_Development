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
