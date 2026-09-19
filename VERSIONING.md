# Versioning

`package.json` is the authoritative Synapse Blade Blocker version. The tool follows Semantic Versioning:

- patch: backward-compatible fixes;
- minor: new backward-compatible user-facing behavior;
- major: incompatible changes to public commands or documented behavior.

Initial unreleased development may remain at `0.1.0`. Every pull request records its Version impact, exact Version change, and Reason, then reconsiders that decision after refreshing from `main` and before readiness.

`BladeBlocker.ps1 -Version`, successful command output, and diagnostics read the authoritative package version. Do not duplicate the version in the applied marker. The marker's `schemaVersion` describes its data contract and changes independently when that contract becomes incompatible; it is not the tool release version.

User-visible changes belong under `Unreleased` in `CHANGELOG.md`, with links to their implementing pull requests. A release moves the relevant entries into a dated version section without rewriting published history.
