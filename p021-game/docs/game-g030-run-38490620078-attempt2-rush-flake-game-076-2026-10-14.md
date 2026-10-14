# GAME-076 — Independent audit: RUSH real-input retry failure

- Checked (JST): 2026-10-14 10:48
- Owner project: P021 / GAME-G030
- Baseline run: https://github.com/kobitworks/autoai_poc/actions/runs/38490620078
- Baseline HEAD: `15139e2eb47d4575d41acd5488302d2b55773fff`
- Baseline test source: `p021-game/qa/orbit-switch-courier-real-input.js`
- Source of truth: completed GitHub Actions run **attempt 2**, fresh-read job logs and the results JSON printed by the failed test. Artifact ZIP bytes and screenshots were NOT independently inspected in this audit; do not equate an uploaded artifact with independent ZIP or visual validation.

## Run and evidence

| Item | Verified observation |
| --- | --- |
| Run attempt | 2, completed / failure, 2026-10-14 10:26 JST |
| contract job | success |
| export-web job | success |
| browser-quality job | **failure**, job `115629673119` |
| Standard phone portrait 390×844 / touch | PASS |
| Standard phone landscape 844×390 / mouse | PASS |
| Standard tablet portrait 768×1024 / touch | **FAIL** |
| Standard tablet landscape 1024×768 / mouse | PASS |
| Small-layout geometry 320×568, 667×375, 800×600 | 3/3 PASS_GEOMETRY |
| Authored visual contract | PASS_STATIC; not a human legibility certification |
| Artifact for attempt 2 | ID `11863379652`, sha256 `3e13b4ba25a05af2a902304abe2cc27b184a5387258150d2c09e4af5613eaa20` (GitHub reported digest only; ZIP not independently hashed here) |

Failed viewport output: `RUSH 0->1 transfer: page.waitForFunction: Timeout 3500ms exceeded.` The final read-only snapshot still showed orbit=0, deliveries=1 and energy=2. The genuine touch attempt did NOT satisfy the orbit-transfer/energy checks; this is a failed scenario, not a passing E2E.

## RUSH diagnostic comparison (attempt 2)

| Viewport | Result | RUSH input-call duration | Passive angle nearest request | Sample gap max |
| --- | --- | ---: | ---: | ---: |
| Phone portrait | PASS | 107ms | 4.361 rad | 133ms |
| Phone landscape | PASS | 36ms | 4.374 rad | 146ms |
| Tablet portrait | **FAIL** | **221ms** | **4.458 rad** | **217ms** |
| Tablet landscape | PASS | 71ms | 4.326 rad | 207ms |

The failed tablet-portrait attempt was requested near the late edge of the QA observation band [4.31, 4.47] and incurred 221ms API-call duration, while the physics accepts a crossing around 4.50 ± 0.19 rad. The browser-side, read-only 75ms samples do **not** establish the precise angle when Godot received the physical event. Hence increased touch dispatch latency crossing the upper physics boundary is a **plausible hypothesis**, not a proven root cause. No game physics, state, score, mission timings, or energy requirements were overridden in this investigation.

The same earlier run's **attempt 1** passed all three jobs and the standard four-viewport E2E, confirming an intermittent failure on unchanged HEAD. Attempt-1 proof must not be misattributed to attempt 2.

## In-task corrective instrumentation

Develop-only commit: https://github.com/kobitworks/autoai_poc/commit/ae448b999037c6e9e2a91d2e0584e5a99f98f4e4

This changes only `p021-game/qa/orbit-switch-courier-real-input.js`. Before RUSH 0→1, the QA page installs a passive capture-phase `pointerdown` observer. It records the real input event time, pointer type, orbit, angle, remaining cargo time and energy, then removes the listener in a `finally` block. Evidence is emitted as `rushPointerCapture` and `rushDiagnostic.actualPointerdown`. Listener does not call `preventDefault`, intercept the click, set any game state, skip time, or decide PASS. Existing real-input orbit transfer and full-energy assertions remain mandatory. This is diagnostic-only; the underlying failure is not yet fixed.

## Required next comparison and gate

1. Confirm a new GitHub Actions workflow run executes the develop commit, not baseline HEAD, and completes.
2. For any RUSH 0→1 outcome, inspect `rushPointerCapture.events` and compare `pointerdown.angle` and timestamp with `rushDiagnostic.clickTiming`, browser polling gap and resulting energy/orbit. The passive observer may be absent in some input paths; absence is **not** proof of no tap.
3. If real event occurs outside the game physics gate, refine real-input test synchronization or test the actual user-facing touch tolerance. Never widen acceptance only to hide failing tests, and never replace actual physical interaction with QA success commands/state overrides.
4. Re-run independent four-viewport real-input E2E, export/test artifacts, review a representative set of actual PNGs, then independently reassess ten quality dimensions. One successful run does not prove intermittent failure is eliminated.
5. Human gates remain open for real-device first-30-second onboarding, Japanese text legibility, mistaps, speaker/headphone sound, FPS/heat. No PASS was inferred for any of these.
6. Quality remains provisionally **76/100 < 80 target** and GAME-076 is incomplete. No main merge, production deployment, paid services or change to the Godot game were performed by this audit.
