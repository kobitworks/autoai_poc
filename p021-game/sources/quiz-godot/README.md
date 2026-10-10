# GAME-G017 Quiz — local question data source

GAME-066 establishes the public-facing local data source for GAME-G017 Quiz before the Godot runtime is implemented.

## Scope

- Dataset: `quiz-core-ja-v1`
- Language: Japanese (`ja-JP`)
- 3 enabled categories
- 5 levels per category
- 3 questions per level
- 45 questions total
- 15 questions per category, so a 10-question run can be sampled without repetition
- Exactly 4 choices per question: 1 correct + 3 distractors
- Explanation, verification date, and source references are stored on every question

## Files

- `data/quiz_categories.json` — category and runtime selection metadata
- `data/quiz_questions.json` — questions plus source catalog
- `tests/validate_quiz_data.py` — standard-library-only structural validator

## Provenance policy

The legacy `kobitworks/kobit_jsgames` SQLite question text is **not copied**. Arithmetic/logic questions were newly authored for P021. Science and Web facts use newly authored wording and are linked to the primary/reference sources recorded in `sourceCatalog`.

Verification date for this dataset: **2026-10-11**.

Primary/reference material:
- NIST — SI base-unit definitions
- NASA Science — Solar System planet size/location overview
- RFC 9110 — HTTP Semantics
- MDN — JavaScript strict equality

Runtime code must keep the source metadata available for audit but does not need network access. The dataset has no PHP, database, CDN, or external API dependency.

## Validate

From the repository root:

```bash
python3 p021-game/sources/quiz-godot/tests/validate_quiz_data.py
```

Expected summary:

```text
OK: 45 questions / 3 enabled categories / 5 levels each
```

## Next integration rule

The Godot integration task should read this JSON locally and preserve the canonical question IDs. If a build-time transformation is introduced, this directory remains the human/audit source of truth.


## Godot Web integration

GAME-067 integrates this unchanged audit dataset into **GAME-G017 Quiz Arena**.

- Engine: Godot 4.7.2 / GDScript / Compatibility renderer
- Web export: single-thread
- Public slug: `p021-game/games/quiz/`
- One run: 10 unique questions
- Category: choose one of the 3 enabled categories
- Focus Lv: 1 through 5; the run takes all available questions from the selected level first, then fills from adjacent levels without duplicates
- Feedback: correct/miss, answer highlight, explanation, and compact source label
- Score: numeric correct-count; higher is better; elapsed time is tie-break/meta
- Input: touch-first choice buttons plus keyboard 1-4
- Sound: generated UI tones with SOUND ON/OFF
- Storage: local best result per category / Focus Lv
- Runtime dependencies: no PHP, DB, CDN, or external API
- QA: URL-only start-to-result flow plus phone/tablet portrait/landscape browser checks

### Public-quality review target

| Category | Score |
| --- | ---: |
| Game design | 8 |
| Controls | 9 |
| Difficulty | 8 |
| UI/UX | 9 |
| Graphics | 8 |
| Effects | 8 |
| Sound | 8 |
| Content / variation | 10 |
| Replayability | 8 |
| Technical quality | 10 |
| **Total** | **86 / 100** |

The build is accepted as general-public quality only when Godot import/export, the data validator, and all four browser viewport checks pass. QA evidence is written to `p021-game/docs/qa/game-g017-quiz/latest.json`.
