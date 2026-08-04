# External Sources — ZH Update Package

**Date:** 2026-08-04
**Source repo:** https://github.com/HnDK0/external-sources

## What's inside

This package contains the updated `zh/` directory for the external-sources repo.

### Fixed
- `zh/ttkan.lua` (1.0.0 → 1.1.0): Fixed catalog/search pagination infinite loop,
  added category filters (13 categories), improved content transforms.

### New sources
- `zh/ixdzs8.lua` (1.0.0): ixdzs8.com — Simplified Chinese, with challenge-token
  anti-bot handling.
- `zh/xbiquge.lua` (1.0.0): xbiquge.info — biquge family, multi-page chapter list
  via http_get_batch.
- `zh/biquge_company.lua` (1.0.0): biquge.company — biquge family, POST search.

### Updated
- `zh/index.yaml`: Added the 3 new sources.

### Unchanged (kept for completeness)
- `zh/novel543.lua`, `zh/piaotia.lua`, `zh/quanben5.lua`, `zh/shuba69.lua`,
  `zh/sto9.lua`, `zh/twkan.lua`
- `icons/` (all existing icons; the 3 new sources don't have icons yet —
  the index.yaml references icon URLs that don't exist in the upstream repo
  yet, but the engine falls back to a default icon when an icon URL 404s).

## See CHANGES.md for full details.

Each new source was tested against real URLs — see the test scripts at
`/home/z/my-project/scripts/test_*.py` (not included in this zip; available
in the work session).
