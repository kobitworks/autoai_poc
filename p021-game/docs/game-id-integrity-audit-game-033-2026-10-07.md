# P021 Game ID Integrity Audit — GAME-033 — 2026-10-07

## Purpose

Audit the canonical `GAME-Gnnn` assignments in P021 before creating the next game, because the task-management series and the current `develop` portal disagree about `GAME-G003`.

P021 rule: game IDs use `GAME-Gnnn`, are not reused, and existing IDs/slugs must be checked before assigning a new ID.

## Fresh-read evidence

### Current develop portal assignments

The current `p021-game/index.html` registers these playable IDs:

| ID | Current portal title | Current path |
|---|---|---|
| GAME-G001 | 1マス農園 | `games/one-square-farm*` |
| GAME-G002 | 過去の自分と協力するゲーム | `games/past-self-coop-v2/` |
| GAME-G003 | CityCraft 3D | `games/citycraft-3d*` |
| GAME-G004 | VOID RUNNER | `games/void-runner/` |
| GAME-G005 | STAR VELOCITY | `games/star-velocity/` |
| GAME-G006 | 風の航路 SKYBOUND | `games/skybound-flight/` |

The repository also contains `p021-game/tasks/GAME-G003-gameplay-polish.md`, whose title is explicitly “GAME-G003 CityCraft 3D ゲーム体験改善”. This confirms that GAME-G003 was already assigned to CityCraft 3D.

### Conflicting wind-reader records

The task-management sequence GAME-027 through GAME-032 later selected and implemented “風読みグライダー” while calling it `GAME-G003`.

Current `develop` contains wind-reader-specific artifacts including:

- `.github/workflows/p021-game-g003-wind-reader-godot-web.yml`
- `p021-game/docs/game-g003-candidate-selection-2026-10-06.md`
- `p021-game/docs/game-g003-poc-spec-2026-10-06.md`
- `p021-game/docs/game-g003-quality-review-game-031-2026-10-06.md`
- `p021-game/docs/game-g003-quality-review-game-032-2026-10-07.md`
- `p021-game/sources/wind-reader-glider/`
- `p021-game/games/wind-reader-glider/`

Therefore the logical ID `GAME-G003` is duplicated between CityCraft 3D and 風読みグライダー.

### Next unused ID check

- The current develop portal uses GAME-G001 through GAME-G006.
- The develop tree has no path containing `GAME-G007`.
- Repository code search on the default branch returned no `GAME-G007` match.

For reconciliation, `GAME-G007` is the next available ID.

## Canonical decision

1. Preserve the existing published assignments GAME-G001 through GAME-G006.
2. Keep **GAME-G003 = CityCraft 3D**.
3. Reassign **風読みグライダー from GAME-G003 to GAME-G007**.
4. Keep the public slug/path `wind-reader-glider` unchanged so existing URLs do not break.
5. Do not rewrite unrelated CityCraft / VOID RUNNER / STAR VELOCITY / SKYBOUND files.
6. Treat GAME-027 through GAME-032 as historical records that used the old conflicting label; add an explicit correction note rather than erasing execution history.
7. After reconciliation, the next brand-new game ID is **GAME-G008**.

## Required remediation

Follow-up task GAME-034 should:

1. Rename wind-reader-specific workflow/document file names from `game-g003` to `game-g007` where practical.
2. Update wind-reader-specific titles, metadata, comments, and visible ID strings to `GAME-G007`.
3. Add/update the P021 portal card so “風読みグライダー” is registered as `GAME-G007`.
4. Preserve the `wind-reader-glider` slug and public URL.
5. Add a correction note to task-management history GAME-027–GAME-032 indicating the canonical reassignment to GAME-G007.
6. Fresh-read the repository afterward and verify:
   - CityCraft remains the only GAME-G003.
   - GAME-G004/G005/G006 remain unchanged.
   - Wind-reader is the only GAME-G007.
   - No wind-reader-specific current file still claims GAME-G003.
7. Run the existing wind-reader CI / four-viewport QA after the metadata/workflow rename if the workflow is touched.

## Outcome

The collision is identified and the non-destructive remediation path is fixed before any new game is assigned. This prevents further ID reuse and protects existing public URLs.
