# SoundHop Store Review & Release Framework

**Status:** Permanent SoundHop operating standard. **Not** Game-1-specific documentation.

## Scope

This framework applies to **every SoundHop game — Game 1, Game 2, Game 3, and all future
games** — from the first day of development, not just at release time. It is not a history
of what went wrong on Game 1. It is the standard every future game inherits so the same
mistakes are not paid for twice.

> **A store-review lesson learned once becomes a SoundHop standard for every game that follows.**

We spent close to two months learning the contents of this document through real Apple and
Google submission problems on Game 1 — several of them costly, in re-review time, in delayed
release, and in engineering rework done under deadline pressure. The purpose of this framework
is simple: **we should never lose another release cycle because we forgot something we already
learned.**

Concretely, this means for every future SoundHop game:

- Store-compliance requirements that affect architecture or UI (subscription access flow,
  parental gate, Privacy Policy, Terms of Use, Restore Purchases, required subscription
  disclosures) must be **designed in from the start** — not patched in after a rejection.
- Platform-specific behavior and wording must be **separated correctly from the start**
  (see [Cross-Platform Rules](#3-cross-platform-rules)), not discovered as a bug during review.
- Apple-specific and Google-specific requirements must stay **clearly separated** — never
  assume a rule that applies to one platform applies to the other.
- The **[Preflight Gate](#6-preflight-gate)** must run before any release build is created.
- The **Submission Checklist** (§4B) must run before any store submission.
- After submission, the final store status must be **explicitly verified**, not assumed.
- A previous game's working implementation (subscription screen, parental gate, GNB Subscribe
  entry, etc.) should be **reused, not rebuilt from memory** — copy the verified pattern.

## Evidence classification — read this before trusting any bullet below

Every substantive claim in this document is tagged with exactly one of four labels. **Never
promote a `[SOUNDHOP-DECISION]` or `[LESSON-LEARNED]` to Apple/Google policy status**, and
never state a policy as `[…-CONFIRMED]` without a real rejection, notice, or published policy
document behind it.

| Tag | Meaning |
|---|---|
| `[APPLE-CONFIRMED]` | Apple App Review actually rejected a build for this, quoting this guideline/reason, or Apple's own published policy explicitly states it. |
| `[GOOGLE-CONFIRMED]` | Google Play Console actually flagged/rejected this, or Google's own published policy explicitly states it. |
| `[SOUNDHOP-DECISION]` | Our own product/engineering choice — not a store mandate, even if it was *informed* by one. |
| `[LESSON-LEARNED]` | A process or engineering mistake we made and fixed — a lesson for how we work, not a store rule. |

---

## 1. Apple App Store Requirements

### 1.1 Subscription discovery/access flow

- `[APPLE-CONFIRMED]` **Guideline 2.1(b)**, Apple App Review, 2026-08-27 — reviewer could not
  locate the Monthly/Yearly In-App Purchases. Root cause: the only path to the subscription
  screen was completing the first 2 free Prep Sets (10 rounds each = 20 regular rounds; Sound
  Quest rounds do not count toward this). Apple's own message offered two remedies: (a) reply
  with exact navigation steps, or (b) provide alternative direct access to the subscription
  interface.
- `[SOUNDHOP-DECISION]` Resolved by adding a permanent, always-visible **"Subscribe" entry to
  GNB Home** — reachable in one tap from the title screen, before any gameplay — routing
  through the same `premium_intro.tscn` → `choose_plan.tscn` flow every normal user already
  uses. This must exist on **every future SoundHop game from first release**, not added
  reactively after a rejection.
- `[LESSON-LEARNED]` A subscription screen that is only reachable after significant gameplay
  progress is a discoverability risk for App Review regardless of whether the *design* intent
  ("earn your way to the paywall") is sound. Always provide a direct, gameplay-independent
  entry point in addition to the natural in-context trigger.

### 1.2 Parental gate requirements

- `[SOUNDHOP-DECISION]` `premium_intro.gd` implements a **7-second press-and-hold
  "verification" gate** (`HOLD_DURATION = 7.0`) before the purchase screen is reachable —
  releasing early cancels and resets, with no confirmation dialog needed on success. This was
  built proactively, informed by Apple's Kids Category expectation that apps directed at or
  including children require a gate before purchases/external links a child could trigger
  unsupervised — it was **not** something Apple rejected us for missing.
- `[SOUNDHOP-DECISION]` This exact mechanism (press-and-hold, no question/challenge popup) is
  the SoundHop baseline parental gate. Future games should reuse this component rather than
  invent a new gate design.

### 1.3 Monthly / Yearly subscription configuration

- `[GOOGLE-CONFIRMED]` *(kept here for contrast — see §2.2 for the Android side)* Android uses
  Google Play's recommended catalog model: **one** subscription product with **two base
  plans** (`monthly`, `yearly`).
- `[APPLE-CONFIRMED]` StoreKit 2 has no multi-base-plan concept — Apple requires **two
  separate auto-renewable subscription products**, one per duration
  (`com.acron.learningsounds.monthly`, `com.acron.learningsounds.yearly`), ideally in the same
  Subscription Group so a monthly↔yearly switch is a plan change rather than two overlapping
  subscriptions.
- `[SOUNDHOP-DECISION]` Pricing: Monthly $9.99, Yearly $99.99 (framed in-app as "Pay for 10
  months, get 2 months free").

### 1.4 Subscription Group configuration

- `[APPLE-CONFIRMED]` Both Monthly and Yearly products must belong to the same Subscription
  Group for the upgrade/downgrade relationship to work correctly. Confirmed group name used
  for Game 1's submission: **"SoundHop Learning Access."**
- `[SOUNDHOP-DECISION]` Each future SoundHop game needs its own Subscription Group (do not
  reuse Game 1's group across games) — name it consistently, e.g. "`<GameName>` Learning
  Access," and record the exact name in that game's own worklog the first time it's created.

### 1.5 First subscription / first subscription group submission requirements

- `[APPLE-CONFIRMED]` A brand-new Subscription Group and its first subscription products must
  be **submitted together with an app version** the first time — they cannot be approved
  independently of an app binary on a first submission. Confirmed from Game 1's Build 6
  resubmission: Monthly, Yearly, the iOS App version, and the Subscription Group were
  resubmitted **together as four items**, reaching "Waiting for Review" as a set.
- `[SOUNDHOP-DECISION]` Treat "app version + both subscription products + subscription group"
  as one atomic submission unit for every future game's first release — never submit the
  binary without also having both products and the group ready in the same submission pass.

### 1.6 Required subscription information shown inside the app

- `[APPLE-CONFIRMED]` **Guideline 3.1.2(c) — Business, Payments, Subscriptions**, Apple App
  Review, **2026-09-07**. Apple explicitly required the auto-renewable subscription flow to
  display, inside the app:
  - Subscription title
  - Subscription length
  - Subscription price
  - A functional Privacy Policy link
  - A functional Terms of Use (EULA) link
- Title, length (via the `/month` and `/year` suffixes), and price were already present on the
  Monthly/Yearly cards before this rejection — the two links were the actual violation (see
  §1.7–§1.8).
- `[SOUNDHOP-DECISION]` This exact set of five items is now the **mandatory minimum content**
  for the subscription/plan-selection screen of every future SoundHop game, checked at
  design time, not discovered at review time.

### 1.7 Functional Privacy Policy link

- `[APPLE-CONFIRMED]` Required as part of §1.6's Guideline 3.1.2(c) rejection; must be
  functional on a physical iOS device, not just in the editor/simulator.
- `[SOUNDHOP-DECISION]` Implemented as a `LinkButton` in `choose_plan.gd`
  (`_build_privacy_policy_link()`), opening `https://www.getsoundhop.com/privacy-policy` via
  `OS.shell_open()`. Every future game needs an equivalent link, pointed at that game's own
  real, published privacy policy page — never a placeholder URL.

### 1.8 Functional Terms of Use (EULA) link

- `[APPLE-CONFIRMED]` Required as part of the same 2026-09-07, Guideline 3.1.2(c) rejection.
- `[SOUNDHOP-DECISION]` Implemented as a second `LinkButton`
  (`_build_terms_of_use_link()`), positioned directly below Privacy Policy, using the
  identical visual pattern (same font, colors, underline style) — opens Apple's Standard EULA
  (see §1.9). Every future game must include this link on its subscription screen from first
  submission, not added reactively.

### 1.9 Apple Standard EULA requirements

- `[APPLE-CONFIRMED]` When an app has no custom EULA, Apple's own Standard EULA is an
  acceptable, published substitute:
  `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
- `[SOUNDHOP-DECISION]` SoundHop uses Apple's Standard EULA for Game 1 rather than authoring a
  custom one. Future games should do the same unless there's a specific reason a custom EULA
  is required (e.g., unusual subscription terms) — a custom EULA adds legal-review overhead
  the Standard EULA avoids.

### 1.10 App Store metadata requirements

- `[APPLE-CONFIRMED]` Per the same 2026-09-07 rejection, Apple requires the **metadata**
  layer (not just in-app UI) to also carry:
  - Privacy Policy URL entered in **App Store Connect's dedicated Privacy Policy field**
  - Terms of Use (EULA) referenced in either the **App Description** or the **EULA field**
- `[LESSON-LEARNED]` These are App Store Connect *portal* fields, not code — they cannot be
  verified from the repository. **This is an open action item, not a confirmed-complete
  state**: before any future submission, explicitly open App Store Connect and confirm both
  fields are populated with the current game's real URLs. Do not assume a prior game's
  metadata carried forward correctly.

### 1.11 Platform-specific wording: no Android references in the iOS user experience

- `[APPLE-CONFIRMED]` **Guideline 2.3.10**, Apple App Review, Build 6, 2026 — quoted directly:
  *"Revise the app's binary to remove Android references."* Root cause: `choose_plan.gd`'s
  platform note (`_build_platform_note()`) and its dev-only unsupported-platform dialog both
  unconditionally said "Subscriptions are available on Android phones, tablets, and
  iPhone/iPad." on every platform, including a real iPhone.
- `[SOUNDHOP-DECISION]` Fixed with a runtime `OS.get_name()` check: iOS shows "Subscriptions
  are available on iPhone and iPad."; Android keeps its original wording verbatim. This
  satisfies the requirement because Apple's review process evaluates observable
  behavior/UI, not decompiled binary contents.
- `[LESSON-LEARNED]` We attempted true byte-level exclusion of the Android string from the iOS
  `.pck` via Godot's `exclude_filter` and confirmed (via direct pack inspection, not
  guesswork) that **`exclude_filter` has no effect when `export_filter="all_resources"`** —
  even a completely unreferenced dummy file wasn't excluded. True per-file exclusion requires
  switching to Godot's `EXCLUDE_SELECTED_RESOURCES` export mode, which is GUI-driven and not
  safely scriptable without risking other resources being dropped. **Do not attempt this again
  without going through the Editor's Export dialog by hand.** The runtime-conditional approach
  is the correct, verified-sufficient fix for this class of problem going forward.
- `[SOUNDHOP-DECISION]` Standing rule for every future game: **any user-facing string that
  differs by platform must be gated by an explicit `OS.get_name()` check at the point of
  display**, never a single unconditional string shared across platforms. Audit every
  cross-platform screen for this before first submission — see §3.

### 1.12 Review Notes requirements

- `[LESSON-LEARNED]` We have not yet had to write Review Notes explaining the parental gate,
  Restore Purchases behavior, or the "press and hold" mechanic to a reviewer directly — this
  section is intentionally left as an **open item**, not a confirmed requirement, until we
  have real evidence of what Apple asks for in Review Notes for a SoundHop-class app. When
  that evidence exists, record it here with the same rigor as every other item.

### 1.13 Build + App Version + subscriptions + Subscription Group submission procedure

Confirmed end-to-end from Game 1's actual Build 6 and Build 7 submissions, and **mandatory for
every future iOS submission that includes subscription changes** — but not every step in this
procedure is an Apple requirement. The procedure below is preserved exactly as run; each step
or group is tagged individually so it stays clear, permanently, which parts Apple actually
requires versus which parts SoundHop requires of itself. This distinction is the entire point
of this framework — do not let it collapse back into one blanket label at the next edit.

1. `[SOUNDHOP-DECISION]` Verify the actual build **locally first** (signature,
   `CFBundleVersion`, `MinimumOSVersion`, plugin symbols, packed-resource content) — never
   upload unverified. Apple does not require this step; it exists so we never spend an App
   Review cycle on a build we could have caught locally.
2. `[APPLE-CONFIRMED]` Upload the new build via Transporter — the actual required mechanism to
   get a build into App Store Connect.
3. `[APPLE-CONFIRMED]` Confirm **processing completes** in App Store Connect before acting on
   the build — a real App Store Connect workflow constraint, not a SoundHop preference.
4. `[APPLE-CONFIRMED]` Attach the correct, processed build to the **App Version** — App Store
   Connect requires a build be selected before a version can be submitted.
5. `[APPLE-CONFIRMED]` mechanic / `[SOUNDHOP-DECISION]` to use it — for External TestFlight
   testing, a build must be **explicitly added to the External Testing group**; it is never
   automatically visible to external testers just because it processed (that mechanic is a
   real App Store Connect/TestFlight fact). Whether we use external testing before every
   production submission at all is SoundHop's own release-quality bar, not something Apple
   mandates.
6. `[APPLE-CONFIRMED]` Complete **Beta App Review** if external testing is used — Apple
   requires Beta App Review for external TestFlight distribution; this is not optional once
   step 5 is chosen.
7. `[SOUNDHOP-DECISION]` Verify the build on an actual **external test device** before
   production submission (see §1.15). Apple does not require on-device verification before
   submission — this is a SoundHop release-quality decision, and it **remains mandatory for
   SoundHop** regardless of that distinction.
8. `[APPLE-CONFIRMED]` If responding to a prior rejection: **reply to App Review** explaining
   the fixes made, via App Store Connect's Resolution Center — the actual required response
   mechanism.
9. `[APPLE-CONFIRMED]` **Update Review** (attach the new build/metadata to the existing review
   thread where applicable) — required App Store Connect workflow action.
10. `[APPLE-CONFIRMED]` **Resubmit** to App Review — required to re-enter the review queue.
11. `[APPLE-CONFIRMED]` fact / `[LESSON-LEARNED]` discipline — the **App Version, Monthly
    subscription, Yearly subscription, and Subscription Group** each carry their own,
    independent review status in App Store Connect; this is a real platform fact, not a
    SoundHop convention. The lesson is ours: verify **all four** explicitly reach **Waiting
    for Review**, not just the app version — checking only the app version can miss a
    subscription product or the group silently not re-entering review.

### 1.14 Reply → Update Review → Resubmit → verify Waiting for Review

- `[APPLE-CONFIRMED]` Steps 8–10 of §1.13 (reply, update review, resubmit) are Apple's actual
  required workflow for responding to an existing rejection, distinct from a routine new
  submission. Confirmed working end-to-end on Game 1's Build 6 → Build 7 cycle.
- `[APPLE-CONFIRMED]` The fact that the App Version, Monthly subscription, Yearly
  subscription, and Subscription Group each carry independent review status is a real App
  Store Connect platform behavior.
- `[LESSON-LEARNED]` The discipline of explicitly checking "Waiting for Review" on **every**
  one of those four items, rather than assuming the app version's status speaks for all of
  them, is a SoundHop process lesson — not something Apple prompts you to do.

### 1.15 TestFlight / External Testing verification before production submission

- `[APPLE-CONFIRMED]` Apple's review process tests real, running behavior on real devices —
  not source code or decompiled binaries. Confirmed relevant to this framework because it is
  *why* runtime-conditional fixes (§1.11) are sufficient and why local-only verification
  (simulator, desktop) is not a substitute for actual device confirmation before production
  submission.
- `[SOUNDHOP-DECISION]` Standing rule: before any production submission that touches the
  subscription flow, Privacy Policy/Terms links, or platform-specific wording, verify on an
  **actual external TestFlight device**, not just a local build or simulator preview. (A
  simulator/desktop preview is acceptable for a quick visual/layout check — see the Build 7
  subscription-screen review in this game's own history — but is not a substitute for real
  on-device confirmation of tappable links and purchase flow.)

---

## 2. Google Play Requirements

### 2.1 All actual rejection/compliance issues encountered

- `[GOOGLE-CONFIRMED]` Google Play notified us that SoundHop must meet a **Target API
  requirement (Android 16 / API 36) by 2026-08-31**. This was a platform-wide Play Console
  policy deadline, not a per-app rejection of specific content.
- `[LESSON-LEARNED]` The exact required API level was confirmed by opening Play Console
  directly (문제 보기 / "View issues") rather than inferred — do not guess a target SDK number
  from general Android release news; Play Console states the exact number and deadline for
  the specific app.

### 2.2 Subscription requirements

- `[GOOGLE-CONFIRMED]` Google Play Billing's recommended (and effectively required, to avoid
  overlapping-subscription bugs) catalog model: **one subscription product with two base
  plans** (`monthly`, `yearly`) — configured in Play Console → Monetize → Products →
  Subscriptions. Product/base-plan IDs must match the client code **exactly** (case-sensitive)
  or every purchase attempt fails with `ITEM_UNAVAILABLE` / `DEVELOPER_ERROR`.
- `[GOOGLE-CONFIRMED]` An **internal testing track** must be live, with a **license tester
  account** added, before *any* purchase — including a test purchase — can succeed.
- `[SOUNDHOP-DECISION]` Confirmed product/plan IDs for Game 1: subscription product
  `soundhop_subscription`, base plans `monthly` ($9.99) and `yearly` ($99.99).

### 2.3 Store metadata requirements

- `[LESSON-LEARNED]` No Google Play metadata-field rejection has been confirmed yet for
  SoundHop (unlike Apple's explicit Privacy Policy/EULA field requirement in §1.10). This is
  intentionally left open rather than assumed — Play Console does have its own Privacy Policy
  and Data Safety declarations, but we do not yet have confirmed, first-hand evidence of a
  SoundHop rejection or explicit requirement tied to them. Do not treat this as "no
  requirement exists" — treat it as "not yet verified"; check current Play Console
  requirements directly before every future submission rather than relying on this document's
  silence here.

### 2.4 Target SDK requirements

- `[GOOGLE-CONFIRMED]` `gradle_build/target_sdk="36"` on both Android export presets, set to
  satisfy the 2026-08-31 deadline (§2.1). `compileSdk` 35→36, `buildTools` 35.0.0→36.1.0,
  Android Gradle Plugin left at 8.6.1 (confirmed working with `compileSdk` 36 via a clean
  build test).
- `[LESSON-LEARNED]` The Android Gradle build template lives in a **gitignored,
  Godot-regenerated folder** — a bare edit to it silently vanishes on the next template
  reinstall. Fixed by version-controlling `android/build/config.gradle`, `build.gradle`, and
  `gradle/wrapper/gradle-wrapper.properties` via narrow `.gitignore` exceptions rather than
  committing the full (~274MB) generated template. **Future Godot engine upgrades need these
  three tracked files re-diffed against a freshly regenerated template before recommitting** —
  this is a recurring maintenance task, not a one-time fix.
- `[LESSON-LEARNED]` Target SDK changes must be verified against the **actual clean-built
  AAB** (`targetSdkVersion` in the manifest, genuine release signing via `jarsigner`), not
  just the config file value — a config change that doesn't actually take effect in the build
  output is a silent failure mode.

### 2.5 Android-specific platform requirements

- `[GOOGLE-CONFIRMED]` `INTERNET` permission required and enabled on both Android export
  presets for Google Play Billing to function.
- `[LESSON-LEARNED]` The **production AAB export preset and the device-testing APK preset
  must stay separate**, with `runnable=false` on the production preset. Godot only supports
  one `runnable=true` preset per platform; leaving the production preset runnable created an
  ambiguous one-click-deploy choice and let an unrelated Editor auto-save silently corrupt the
  production `export_path` to end in `.apk` while still exporting in App Bundle format,
  breaking production exports outright. Check both presets' `runnable`/`export_path` fields
  before every Android release build.

### 2.6 Any business/compliance requirements we had to resolve

- `[LESSON-LEARNED]` No additional Google Play business/compliance issues (Families Policy,
  COPPA-specific declarations, Data Safety section content, ads/analytics restrictions for
  child-directed content) have been confirmed for SoundHop as of this document's writing.
  This is explicitly **not evidence that none apply** — SoundHop is a children's education
  app and these areas are plausible future compliance surfaces. Treat as an open verification
  item for every future submission, not a closed checklist item.

---

## 3. Cross-Platform Rules

These apply regardless of which store rejected (or might reject) something — they are rules
about how SoundHop is built, derived from confirmed incidents above.

1. **Never expose platform-inappropriate wording.** Any string that differs by platform
   (store name, device names, platform-specific instructions) must never be hardcoded as a
   single shared literal. Derived from `[APPLE-CONFIRMED §1.11]`.
2. **Platform-specific UI/text must be explicitly controlled**, gated by `OS.get_name()` (or
   an equivalent explicit platform check) at the point of display — not by relying on
   build-time exclusion, which Godot does not reliably support for individual script content
   (`[LESSON-LEARNED §1.11]`).
3. **Privacy Policy, Terms of Use, and required subscription disclosures must be designed
   into the product from the start**, not patched in reactively during App Review. Every new
   game's subscription screen must ship on day one with: title, length, price, functional
   Privacy Policy link, functional Terms of Use link — the exact set from `[APPLE-CONFIRMED
   §1.6]`.
4. **Store-review requirements must be checked before producing a release build** — this is
   the entire purpose of the Preflight Gate (§6). A release build produced without checking
   this framework first is a process failure, independent of whether that specific build
   happens to pass review.
5. **A platform-specific requirement confirmed for one store is never assumed to apply to the
   other.** Apple's subscription-group model, EULA requirement, and 2.3.10-style wording
   rules are Apple-specific; Google's base-plan model and target-SDK deadlines are
   Google-specific. Keep them in separate sections (§1 vs §2) permanently — never merge them
   into one generic "store requirements" list that blurs which platform actually requires
   what.

---

## 4. Pre-Release Checklist

This section has three parts, run in order: **(4A)** before any release build is produced,
**(4B)** during actual store submission, **(4C)** after submission. §6 restates 4A as a
compact, mandatory gate.

### 4A — Before producing a release build

- [ ] Every cross-platform user-facing string reviewed for platform-inappropriate wording
      (§3.1–§3.2); any Android/iOS-specific text is behind an explicit `OS.get_name()` check.
- [ ] Subscription screen shows: title, length, price, functional Privacy Policy link,
      functional Terms of Use link (§1.6–§1.9).
- [ ] Privacy Policy and Terms of Use URLs point to this game's real, published pages/Apple's
      Standard EULA — not placeholders or another game's URLs.
- [ ] Parental gate present before the purchase screen is reachable (§1.2).
- [ ] Subscription screen reachable via a direct, gameplay-independent entry point, not only
      after significant gameplay progress (§1.1).
- [ ] iOS: subscription products are two separate auto-renewable products in one Subscription
      Group (§1.3–§1.4). Android: one product, two base plans, IDs match code exactly (§2.2).
- [ ] iOS: `min_ios_version` matches the actual minimum required by every linked
      framework/plugin (verified via a **fully clean** archive — see §5's toolchain rules) —
      not just StoreKit 2's nominal minimum.
- [ ] Android: `target_sdk` matches Play Console's current stated requirement, verified
      directly in Play Console, not inferred (§2.1).
- [ ] Android: production AAB preset has `runnable=false`; export paths for both presets are
      correct (§2.5).
- [ ] No stray backup copies of plugin config files (e.g. `.gdip`) anywhere under a
      plugin-scanning directory (§5).
- [ ] Build produced from a **fully clean state** (cleared DerivedData/build caches) at least
      once before shipping, not only incrementally rebuilt (§5).

### 4B — Submission Checklist (run during actual store submission)

Follow §1.13 in full for iOS. For Android: build the AAB from the checked-in, version-controlled
Gradle config (§2.4), verify `targetSdkVersion` and release signing in the actual output
artifact, then upload to the correct Play Console track.

### 4C — Post-submission verification

- [ ] Confirm final status explicitly for every submitted item (iOS: App Version + both
      subscription products + Subscription Group all reach "Waiting for Review," not just the
      app version — §1.14). Android: confirm the release is visible on the intended track.
- [ ] Do not close out a release session until this verification is done and recorded.

---

## 5. Architecture / Development Rules

Reusable implementation rules every future SoundHop game should inherit automatically, not
rediscover.

1. `[SOUNDHOP-DECISION]` **Parental gate component**: reuse `premium_intro.gd`'s
   press-and-hold pattern (7-second hold, cancel-on-early-release, no confirmation dialog) as
   the baseline for every future game rather than designing a new gate.
2. `[SOUNDHOP-DECISION]` **GNB "Subscribe" direct-access entry**: every future game's GNB Home
   (or equivalent hub screen) should include a permanent, always-visible Subscribe entry from
   first release — do not wait for a 2.1(b)-style rejection to add it.
3. `[SOUNDHOP-DECISION]` **Privacy Policy / Terms of Use link component**: reuse the
   `LinkButton` pattern from `choose_plan.gd` (`_build_privacy_policy_link()` /
   `_build_terms_of_use_link()`) — same font, color, underline style — as the standard
   component for both links in every future game.
4. `[LESSON-LEARNED]` **Clean-build discipline**: a build produced from incrementally-cached
   DerivedData/build state can silently mask a real linker/toolchain incompatibility that
   only a fully clean build will surface (confirmed on Game 1's Build 6 StoreKit2 issue).
   Every future game's release pipeline must include at least one fully clean build/archive
   before shipping, not rely on incremental rebuilds throughout development.
5. `[LESSON-LEARNED]` **`#available` guards defer execution, not compilation.** A
   platform-version-gated code branch for a future/higher OS version still has to compile and
   link for every build, regardless of the project's actual deployment target. A branch that
   can never execute on the shipping minimum OS can still break the build. Audit any
   `#available`/equivalent guards against the actual deployment target, not just against
   "this code path is unreachable so it's safe."
6. `[LESSON-LEARNED]` **Godot export-filter limits**: `exclude_filter` does nothing when
   `export_filter="all_resources"`. True per-file export exclusion requires the GUI-driven
   `EXCLUDE_SELECTED_RESOURCES` mode. Do not attempt scripted/headless exclusion again without
   validating it against a throwaway unreferenced file first, exactly as done here.
7. `[LESSON-LEARNED]` **Plugin config hygiene**: never leave a copy of a `.gdip` (or
   equivalent plugin descriptor) anywhere under a directory Godot scans for plugins, including
   backup folders — it registers as a duplicate plugin and breaks the Xcode archive with
   "Unexpected duplicate tasks." Store backups of plugin binaries entirely outside the
   plugin-scanning path.
8. `[LESSON-LEARNED]` **Root-cause discipline** (elevated from `ARTHUR_WORKLOG.md`'s
   2026-08-28 operating principle, now permanent): protect what is already verified → narrow
   the root cause using evidence → make the minimum necessary change → verify the actual
   release artifact → confirm the final submission state before closing. Newly discovered,
   unrelated issues get recorded for later, never mixed into an active release fix.
9. `[SOUNDHOP-DECISION]` **Reuse over rebuild**: before implementing subscription
   architecture, purchase access, parental gate, Privacy Policy/Terms links, or Restore
   Purchases for a new game, check whether a previous SoundHop game already has a verified
   implementation to copy, rather than rebuilding from memory or from a generic tutorial.

---

## 6. Preflight Gate

**Before Collie (or anyone) produces any future SoundHop release build, this framework must be
checked first.** A release build must not proceed until every applicable item below is
explicitly marked **PASS** or **N/A** — not silently skipped.

| # | Gate item | Status |
|---|---|---|
| 1 | Cross-platform strings audited for platform-inappropriate wording (§3.1–§3.2) | PASS / N/A |
| 2 | Subscription screen shows title, length, price, Privacy Policy link, Terms of Use link (§1.6) | PASS / N/A |
| 3 | Privacy Policy / Terms of Use URLs correct for this game (§1.7–§1.9) | PASS / N/A |
| 4 | Parental gate present before purchase screen (§1.2) | PASS / N/A |
| 5 | Subscription screen reachable via a direct, gameplay-independent entry point (§1.1) | PASS / N/A |
| 6 | iOS subscription products/group configured correctly (§1.3–§1.4) | PASS / N/A |
| 7 | Android subscription product/base plans configured correctly, IDs match code (§2.2) | PASS / N/A |
| 8 | iOS `min_ios_version` verified against every linked plugin's real minimum (§4A) | PASS / N/A |
| 9 | Android `target_sdk` verified directly against current Play Console requirement (§2.1, §2.4) | PASS / N/A |
| 10 | Android production/testing export presets correctly separated (§2.5) | PASS / N/A |
| 11 | No stray plugin config backups under any plugin-scanning path (§5.7) | PASS / N/A |
| 12 | At least one fully clean build/archive completed before shipping (§5.4) | PASS / N/A |
| 13 | App Store Connect Privacy Policy field and App Description/EULA field confirmed current (§1.10) | PASS / N/A |
| 14 | Google Play metadata/Data Safety/Families items checked directly in Play Console (§2.3, §2.6) | PASS / N/A |

If any item cannot honestly be marked PASS or N/A, **stop and resolve it before building** —
do not produce the release artifact first and hope to patch the gap during review.
