# agents-md-management

## Task
Manage `agents.md` by summarizing key sections and transferring them granularly into `docs/context`.

## Date
2026-04-18

## Assumptions
- The request means: keep `agents.md` as the canonical instruction source, but create granular summarized docs under `docs/context` for faster reference.
- "Granularly" means split by major topic instead of one large summary.

## Plan
1. Create `docs/context/` and topic-based summary files.
2. Add an index file that maps each summary to the relevant `agents.md` sections.
3. Update `agents.md` with a short pointer to the new context summaries.

## Design/Pattern Notes
- Pattern: canonical-source + derived summaries.
- Anti-pattern avoided: moving full content out of `agents.md` and risking instruction drift.
- Mitigation: keep summaries concise and explicitly mark `agents.md` as source of truth.
## Implementation Log
- Created `docs/context/README.md` as index and maintenance guide.
- Created granular summaries under `docs/context/agents/`:
  - `01-overview-and-structure.md`
  - `02-workflow-and-documentation.md`
  - `03-execution-principles.md`
  - `04-gdscript-standards.md`
  - `05-project-structuring.md`
  - `06-ai-architecture.md`
- Updated `agents.md` with a `Context Summaries` section pointing to the new docs.

## Verification
- Confirmed all new files are in `docs/context`.
- Confirmed `agents.md` remains intact and marked as source of truth.

## Notes
- Chose summarized transfer (not full migration) to avoid instruction drift and preserve canonical behavior in one place.

## Optimization Pass (2026-04-18)

### Goal
Optimize `agents.md` now that granular context summaries exist.

### Approach
- Reduce token/reading overhead in `agents.md`.
- Keep hard requirements and operational guardrails in `agents.md`.
- Move detailed reference material to `docs/context/agents/*.md` via explicit links.
- Fix readability issues (duplicate numbering and character encoding artifacts).

### Decisions
- `agents.md` stays canonical for mandatory process rules.
- Detailed style/architecture examples remain in the context summary docs.
- Add a "document priority" section to avoid conflicts.
