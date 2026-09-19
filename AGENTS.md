# Synapse Blade Blocker agent guide

Adapted from [OpenBlade core AGENTS.md](https://github.com/OSSBlade/openblade-core/blob/d058c70321b8036a5bf11ebad92efbd2bce50012/AGENTS.md). Apply the shared rules below to this repository. Work in the core repository must additionally follow its own current guide.

## Scope and architecture

- Keep changes narrow, evidence-based, and specific to Razer Blade laptops. Preserve Synapse functionality for other Razer peripherals.
- Discover the installed AppEngine and validate patch structure. Do not require approval of individual Synapse versions or maintain executable/archive hash allowlists. Hashes generated during preparation protect the integrity of that preparation and its backup.
- Fail with actionable, sanitized diagnostics when required patch sites are missing or ambiguous. Never silently apply a partial patch.
- Generate applied-patch metadata only after the replacement archive is verified. Restore removes that metadata after verifying the original archive. Preserve backups and use atomic replacement.
- OpenBlade detection is cooperative verification of the actual patched files and process restart. Do not describe a marker alone as proof of isolation or a security boundary.
- Do not add drivers, generic elevation runners, background services, or abstractions without a concrete requirement. Never stop competing Razer software automatically.

## Parallel work

Use independent, bounded subagents when the benefit justifies coordination and usage. Prefer read-only exploration, review, or test analysis. Assign disjoint ownership for edits, preserve other workers' changes, and integrate and verify the results. Keep dependent work with one owner.

## Change workflow

1. Inspect status and existing contracts and tests. Preserve unrelated edits and generated local evidence.
2. Make changes and run change-producing checks only in a dedicated Git worktree, based on main by default. Do not implement in the primary landing checkout.
3. Create a labeled tracking issue before implementing a fix and deliver changes through a pull request. Prefer authenticated gh for GitHub operations. Retry an access-denied sandbox authentication check with approved host access before diagnosing expired credentials.
4. Use descriptive branches such as feat/, fix/, docs/, or chore/; do not use codex/ or claude/. Use Conventional Commit subjects with a lowercase imperative summary after the colon.
5. Keep the authoritative implementation shared. Add focused regression tests for parsing, structural matching, failure handling, privacy, and reversible file operations.
6. Follow `VERSIONING.md`. Include Version impact, Version change, and Reason in every PR. `package.json` is the blocker version source. Use patch for fixes, minor for new compatible functionality, and major for incompatible public usage changes. Initial unreleased development may retain 0.1.0. Before readiness, refresh from main and reconsider the version impact.
7. Document user-visible changes in the README or validation documentation and `CHANGELOG.md`. Add entries under Unreleased with links to implementing PRs; preserve published entries.
8. Commit and push coherent slices. Never commit vendor archives, extracted vendor code, raw captures, serial numbers, user paths, or generated preparation folders. Reports intended for issues must be sanitized and must not contain source snippets or private paths.
9. Follow .gitattributes for every touched text file. Check mixed line endings explicitly; git diff --check alone does not detect them. Preserve exact bytes of embedded policy modules where declared.
10. Keep PRs draft until required validation of the final source is complete. Distinguish automated evidence, user-reported checks, and untested models or features. Hosted CI billing failures are not code failures; report local verification separately.

## Verification

Run npm test, npm run test:operations, and PowerShell syntax checks for affected scripts. Run npm run test:local against a fresh preparation when locally installed Synapse is available; do not redistribute its archive or extracted source. Confirm structural preparation preserves unrelated archive files. A future-version synthetic fixture must succeed without edits to a version list, and incompatible structure must produce a sanitized issue report.

Use scratch files for Apply/Restore regression tests. Preparation and inspection must leave the installed archive unchanged. When PowerShell execution policy blocks scripts, use a child powershell.exe -NoProfile -ExecutionPolicy Bypass process and propagate its exit code; do not change machine policy.

Core integration changes require that repository's build, test, version, and changelog workflow. This repository does not require unrelated .NET or WinUI builds.

## Live safety

- Installed Apply/Restore trials require explicit authorization, verified original backups, and the documented stopped-controller preconditions. Verify the replacement or restoration by hash. If state becomes ambiguous, stop and reconcile read-only.
- Never run USBPcap and OpenBlade control against the same interface concurrently. USBPcap must have its own process group; never send a console control event to group 0.
- Hardware writes require captured typed operations, fresh exact-device admission, prior confirmed state, readback, and restoration. Do not copy hardware commands between Blade models or weaken core capability admission.
- Sleep/resume testing requires fresh approval from a present user. Never initiate UAC or installation while the user is unavailable. Do not create a generic UAC auto-approver.
- Preserve capture-control and query-control directories. Publish only sanitized evidence, including restoration outcomes. Do not claim all Blade models or all peripheral functions were physically tested from a single laptop/mouse trial.

## Completion and cleanup

After a PR is merged or closed, verify its exact state and branch before cleanup. Preserve dirty and untracked worktree artifacts, including local preparations and backups. For merged branches prove the tip is reachable from origin/main; ensure no other worktree uses the branch. Remove the dedicated worktree before deleting its local and remote branch. Do not force deletion when safety checks fail. After a merge, safely fast-forward the primary checkout to main; report local changes or divergence instead of discarding them.
