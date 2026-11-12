---
title: Check complete model tables and pinned source links
author: Jack
date: 2026-11-12
branch: test/openblade-model-coverage
touches:
  - policy.test.cjs
  - fixtures/openblade-models.json
  - VALIDATION.md
---

## Decided
Compare each complete README model table with the pinned core fixture: laptop name and year, exact model number, USB identity and row cardinality. Verify every current catalog link in all six guides against the fixture source URL. Store the reviewed model count with the snapshot and check it against the entries; read each guide once. Claude's full-PR review found these maintenance gaps, and 22 scratch mutations verify the tightened checks.

## Tried and ruled out
Partial-cell comparisons left labels and row cardinality unchecked.

## Watch out
Preserve the pinned core display names even when a manifest uses different wording for the same VID/PID. Source-module tests and tests of policy bytes loaded from a saved generated archive cover separate artifacts. Current support-guide links and immutable catalog evidence links serve different purposes. Validation dates use client Pacific time; generated Trail metadata uses UTC.
