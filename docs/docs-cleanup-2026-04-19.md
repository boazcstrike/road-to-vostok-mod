# Docs Cleanup Task Context - 2026-04-19

## Task
Clean up `docs/` based on recent sessions and current code context by organizing, combining, and deleting redundant documentation.

## Assumptions
- Session-generated dated markdown files are historical artifacts and should be grouped under a dedicated reports area.
- Architecture/process entrypoints should stay at stable top-level folders (`context`, `domains`, `adr`, `rfc`, `system-maps`, `templates`).
- Duplicate team-hostility documents should be merged into one canonical report.

## Verification Plan
1. Organize root report sprawl into category folders.
   - Verify: dated session docs are moved under `docs/reports/*`.
2. Consolidate duplicate team-hostility docs.
   - Verify: one canonical team-hostility report remains; duplicate predecessors are deleted.
3. Improve top-level navigation/readmes.
   - Verify: `docs/README.md`, `docs/reports/README.md`, and `docs/domains/README.md` describe current structure and usage.

## Changes Applied
- Created `docs/reports/` with subfolders:
  - `investigations/`
  - `reviews/`
  - `operations/`
  - `planning/`
- Moved session artifact markdown files from `docs/` root into the category subfolders.
- Added canonical merged report:
  - `docs/reports/operations/team-hostility-and-combat-rules-2026-04-19.md`
- Deleted superseded duplicates:
  - `docs/enable-team-fighting-default.md`
  - `docs/enable-team-infighting.md`
  - `docs/reports.md`
- Rewrote navigation/index files:
  - `docs/README.md`
  - `docs/reports/README.md`
  - `docs/domains/README.md`

## Notes
- No gameplay scripts were modified in this task.
- Existing architecture and context subtrees were preserved; this pass focused on documentation structure and clarity.
