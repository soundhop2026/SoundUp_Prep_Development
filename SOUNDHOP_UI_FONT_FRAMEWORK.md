# SoundHop UI Typography & Brand Role Framework

**Status:** Permanent SoundHop operating standard. **Not** Game-1-specific documentation.
Locked 2026-09-29 after a full representative-screen visual QA pass on Game 1.

## Scope

This framework applies to **every SoundHop game — Game 1, Game 2, and all future games**.
Game 1 is the first implementation, not the owner of the rules.

Typography here is assigned by **semantic role**, never by screen and never by convenience.
An element's role — is this the brand, information structure, information content, or an
action the player takes? — decides its face. That is the whole system.

> **A typeface is chosen for what the text *is*, not for where it happens to sit.**

---

## 1. Existing artwork is not automatically protected

Artwork already in the project is **not** preserved merely because it exists. It is preserved
only where it has been **explicitly approved to remain artwork**.

The default is the opposite of what it may look like from the outside: when SOUNDHOP appears as
part of the **PlayButton character/logo system**, it is rendered as real Schoolbell text (§2),
not as baked lettering. An existing PNG of that lettering is a candidate for replacement, not a
protected asset.

**Corrected 2026-09-29.** This section previously cited GNB Home's
`GNB_SOUNDHOP_letters_only.png` as an example of artwork that must be preserved. That is no
longer correct: GNB Home's wordmark has been rebuilt as Schoolbell text on an arc above the
hand-drawn face, using the Title Scene treatment as its visual reference. The PNG remains in the
repository, unused — obsolete treatments are retired from the screen, not deleted from the repo.

What *is* still artwork, and stays that way:

- The **PlayButton face** itself — `GNB_SOUNDHOP_face_only.png` on GNB Home,
  `playbutton.png` elsewhere. Faces are drawn, never typeset.

When a piece of lettering artwork is genuinely meant to stay, that decision is recorded here
explicitly, with the reason. Absent such a record, assume the role system applies.

---

## 2. Character / logo text — `character()`

**Schoolbell Regular.**

Used wherever SOUNDHOP appears **as part of the PlayButton character/logo system** — the
wordmark integrated with the face. This is the default for that mark; baked lettering artwork
is replaced by it unless §1 records an explicit approval to keep the artwork.

Current examples:

- **Title Scene** — the letter arc above the PlayButton head. The reference treatment.
- **GNB Home** — the same construction, static. It derives its arc from its own face rather than
  copying the Title's numbers blind: that face measures 360px wide centred on x=618 with its top
  at y=187, which yields radius 300 centred at (618, 415) for the same head-to-letter
  relationship. Borrowing the Title's *geometry* is deliberate; borrowing its *animation* is not
  — GNB Home is a static navigation screen with no idle drift, settle or tap behaviour.

Never used for body text, UI chrome, navigation labels or Level Intro. Note the distinction from
§4: the wordmark **SOUNDHOP** in the logo system is Schoolbell, while **"SoundHop"** as a
UI/product-name heading is Andika Bold.

---

## 3. Learning / information body — `learning()`

**Andika Regular.**

- explanatory copy
- learning descriptions
- supporting information
- body copy
- secondary navigation and information

---

## 4. Major information hierarchy — `learning_bold()`

**Andika Bold.**

- major informational headings
- section headings
- major navigation labels
- the UI / product-name heading **"SoundHop"**
- the Title tagline **"Learning Sounds"**
- Level Intro hierarchy headings
- GNB hierarchy headings

Use the real `Andika-Bold.ttf`. **Never synthesize bold.**

---

## 5. Action / transaction — `action()` / `action_bold()`

**JetBrains Mono Regular** for normal action and transaction text.
**JetBrains Mono Bold** for emphasised action text.

Current examples: Ready to Play, the Subscription transaction UI, Parent Gate action text.

Use the real Regular and Bold files. **Never synthesize bold.**

`JetBrainsMono-ExtraBold.ttf` ships alongside them but is deliberately **not** exposed as a
role — an available asset, not a current answer.

---

## 6. Visual hierarchy principle

**Bold is not a global replacement for Regular.** Replacing every Regular with Bold destroys
the hierarchy instead of expressing it.

| | |
|---|---|
| Andika **Bold** | information *structure* — headings, major navigation |
| Andika Regular | information *content* — explanation, supporting text |
| JetBrains Mono | action / transaction |
| Schoolbell | the SOUNDHOP wordmark in the PlayButton character/logo system |
| Hand-drawn artwork | faces, and any lettering explicitly approved to stay artwork (§1) |

A corollary worth stating: when one line carries two roles — a heading and its explanation in
a single string, e.g. `"Round cubes  —  fade away one by one as you play."` — the roles still
apply separately. A `Label` has one font, so such a line is drawn as two labels laid end to
end, bold heading then regular remainder, same size and baseline. See
`level_intro.gd::_make_split_label()`.

---

## 7. Implementation principle

**Standardize the framework, not every screen blindly.**

- Do **not** perform repository-wide font replacement.
- Assign each UI element by its **semantic role**.
- Existing artwork is **not** automatically protected — see §1 before assuming it stays.
- Ambiguous legacy font uses are **reviewed**, never migrated automatically.

Implementation lives in `ui_fonts.gd` (`class_name UIFonts`) — one accessor per role, a static
cache, and a `push_error` when a face fails to load. That last point matters: every call site
guards with `if _font:`, so without the error a missing font renders the engine default
silently rather than failing loudly.

```gdscript
UIFonts.character()      # Schoolbell Regular
UIFonts.learning()       # Andika Regular
UIFonts.learning_bold()  # Andika Bold
UIFonts.action()         # JetBrains Mono Regular
UIFonts.action_bold()    # JetBrains Mono Bold
```

### Asset layout

Each family lives in its own folder under `UI_assets/` with its licence file. Do not move,
rename or replace these; change the constants in `ui_fonts.gd` if the layout ever does change.

```
UI_assets/Schoolbell/Schoolbell-Regular.ttf      + LICENSE.txt
UI_assets/Andika/Andika-Regular.ttf              + OFL.txt
UI_assets/Andika/Andika-Bold.ttf
UI_assets/JetBrainsMono/JetBrainsMono-Regular.ttf + OFL.txt
UI_assets/JetBrainsMono/JetBrainsMono-Bold.ttf
```

Andika also ships Italic / BoldItalic and JetBrains Mono ships ExtraBold — present, unused.
Schoolbell is Regular-only.

### Metrics gotchas, learned the hard way on Game 1

- **A font swap is a layout change.** Andika's line height ran ~57–60% taller than the legacy
  face at Level Intro sizes, and JetBrains Mono ~14% wider at button sizes. Always re-measure
  against the real fixed dimensions before assuming a swap is cosmetic.
- **Godot renders multi-line `Label`s at `font_height + line_spacing`** (theme default 3). Where
  a layout advances its own per-line constant, the two must agree or blocks read loose and boxes
  disagree with their text.
- **A `Button` cannot shrink below its content height.** Swapping in a taller face silently
  grows the control past its declared constant.
- **Andika Bold is the same height as Regular but ~6% wider.** Weight-only changes are
  vertically safe, but shift anything hand-positioned horizontally.

---

## 8. Current legacy exceptions

These still use the legacy `210 연필스케치R.ttf` and are **explicitly unresolved**. Do not
migrate them automatically; each needs its role reviewed and approved first.

| File | What it renders |
|---|---|
| `level_transition.gd` | Coronation — "You made it!", "Keep hopping!", level name |
| `prep_transition.gd` | the "Keep Hopping!" button at the free→premium boundary |
| `sound_quest.gd` | Prep Sound Quest gameplay copy |
| `level1_sound_quest.gd` | Level 1 Sound Quest gameplay copy (declares `FONT_PATH` but applies no override — dead constant) |
| `debug_menu.gd` | QA tooling; never ships visible (`DebugConfig.DEBUG_MODE = false`) |

Separately: **no gameplay scene sets any font at all.** `game.gd`, `game15.gd`, `game2.gd`,
`game25.gd`, `prep_game.gd` and `transition.gd` have zero font overrides, so their HUD and cube
text render in Godot's default face. Not a legacy reference — a gap in the role system, and an
open question for whoever extends this framework to gameplay.

---

## 9. Shared-game principle

This is a shared SoundHop UI framework. Game 2 and later games should inherit the same semantic
roles:

```
character  ·  learning  ·  learning_bold  ·  action  ·  action_bold
```

`ui_fonts.gd` is deliberately free of project-specific references so it can be copied across
verbatim; only the asset paths need to exist in the receiving project.

Adoption is a **deliberate act per game**, not an automatic one. A game inherits the *roles*
and the *principle*, then assigns its own elements by their own semantics.

### What is shared, and what is not

The boundary matters, because "shared framework" is easily over-read as "shared look".

**Shared across games — one framework:**

- the five semantic roles and what each one means
- the typefaces bound to those roles
- the surfaces that are themselves shared product furniture rather than game content:
  **GNB** (Home, Where Am I, What's SoundHop), the **Parent Gate**, and the **Subscription UI**.
  A parent meeting these in Game 2 should recognise them from Game 1.

**Per game — never inherited:**

- visual identity and brand artwork, including each game's own PlayButton face
- colours and background palettes
- layout, composition and spacing
- gameplay, progression and learning content

So two games can render the same Parent Gate copy in the same faces at the same roles while
looking entirely like themselves. Typography is the constant; identity is not.
