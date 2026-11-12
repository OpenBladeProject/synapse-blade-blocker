---
title: Keep blocker model coverage aligned with the pinned core catalog
author: Jack
date: 2026-11-12
branch: test/openblade-model-coverage
touches:
  - fixtures/openblade-models.json
  - policy.test.cjs
  - preparation.test.cjs
  - README.md
  - VALIDATION.md
---

## Decided
All 19 officially supported profiles in OpenBlade core catalog 14da93e1cddca80b3fbbbf0d51e2a6add980608d already map to the blocker's existing 40 reviewed USB identities. Maintain the offline fixtures/openblade-models.json snapshot with its immutable source URL, use it for per-model policy and saved-preparation regressions, and keep the three README tables aligned. This coverage-only update leaves package version 0.3.1, runtime policy and generated patch bytes unchanged.

## Tried and ruled out
Expanding the registry or broadening product-name matching is unnecessary for these 19 models. Core source-reviewed support does not require new blocker firmware behavior. Verify the existing exact VID/PID paths instead of guessing more identities.

## Watch out
Core support evidence and physical blocker validation are separate: the historical blocker trial covers RZ09-0581 only. The fixture is an offline pinned snapshot, not a live synchronization check; refresh it from the full immutable core catalog when support changes. Local module tests use mocked native dependencies and do not establish a new physical model trial.
