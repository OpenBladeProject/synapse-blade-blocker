---
title: Assess catalog coverage warnings against the actual changed files
author: Jack
date: 2026-11-12
branch: test/openblade-model-coverage
touches:
  - README.md
  - README.zh-CN.md
  - VALIDATION.md
  - policy.test.cjs
---

## Decided
The model coverage update changes guides, an offline catalog fixture and regression tests only. Existing exclusion modules and the reviewed device list have no diff. Links explaining core evidence and checks comparing exact catalog identities are intentional documentation and validation.

## Tried and ruled out
No extra runtime path was needed.

## Watch out
The first trail check produced four keyword-overlap warnings against the companion coverage learning. The actual changed code audits existing identities and explicitly separates hardware evidence; it does not implement the alternatives described there. Resolve this lexical false positive by recording the evidence in the commit and PR rather than weakening the coverage checks or rewriting the earlier learning.
