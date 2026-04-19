# Documentation Index

This directory is the canonical documentation root for the BosWar mod.

## Directory Structure
- `context/`: Operational guidance derived from `agents.md`.
- `domains/`: Domain ownership, boundaries, and per-domain map/index files.
- `system-maps/`: Cross-domain architecture and boundary maps.
- `adr/`: Architecture Decision Records.
- `rfc/`: Proposed changes before decision ratification.
- `templates/`: Standard templates for ADR, RFC, system map, and domain docs.
- `plans/`: Forward-looking implementation plans and backlog notes.
- `reports/`: Historical session reports, investigations, reviews, and operational logs.

## Where To Add New Docs
- Long-lived architecture or process docs: place in the appropriate architecture folder (`domains/`, `adr/`, `rfc/`, `system-maps/`).
- Session/task artifacts from implementation or investigations: place in `reports/`.

## Conventions
- Use clear, technical titles with dates for session reports: `kebab-case-topic-YYYY-MM-DD.md`.
- Keep one canonical report per resolved issue. Avoid parallel duplicate notes for the same root cause.
- If a report is superseded, consolidate and replace it instead of leaving multiple conflicting files.

## Quick Navigation
- Reports index: [`reports/README.md`](./reports/README.md)
- Domain index: [`domains/README.md`](./domains/README.md)
- Context index: [`context/README.md`](./context/README.md)
- Templates index: [`templates/README.md`](./templates/README.md)
