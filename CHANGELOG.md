# Changelog

## Unreleased

## [0.2.1] - 2026-09-20

### Added

- Add a standalone Windows window for verified patching and restoration, automatic preparation, backup recovery, and sanitized diagnostics. ([#7](https://github.com/OSSBlade/synapse-blade-blocker/pull/7))

### Fixed

- Preserve native exit-code handling and diagnostic reports when Node writes to stderr in the Windows PowerShell 5.1 desktop runspace. ([#10](https://github.com/OSSBlade/synapse-blade-blocker/pull/10))
- Keep desktop actions on the installation shown at confirmation, and provide backup recovery locations and accurate inspection guidance. ([#10](https://github.com/OSSBlade/synapse-blade-blocker/pull/10))
- Detect existing blocker edits from archive contents independently of local patch metadata, and distinguish content inspection from a saved-original hash match. ([#7](https://github.com/OSSBlade/synapse-blade-blocker/pull/7))

## [0.1.0] - 2026-09-19

### Added

- Exclude reviewed Blade identities and laptop-specific Synapse routes while preserving peripheral routes. ([#4](https://github.com/OSSBlade/synapse-blade-blocker/pull/4))
- Prepare compatible AppEngine builds without a version allowlist, apply and restore verified archives, publish applied-patch metadata, and produce sanitized failure reports. ([#4](https://github.com/OSSBlade/synapse-blade-blocker/pull/4))

- Provide offline version reporting and package-backed versions in successful command output. ([#4](https://github.com/OSSBlade/synapse-blade-blocker/pull/4))

[0.1.0]: https://github.com/OSSBlade/synapse-blade-blocker/releases/tag/v0.1.0

[0.2.1]: https://github.com/OSSBlade/synapse-blade-blocker/compare/v0.1.0...v0.2.1
