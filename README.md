# Synapse Blade Blocker

Experimental Blade exclusion for Razer Synapse: keep Synapse available for peripherals while suppressing recognized Blade discovery and selected laptop-specific routes.

**Supported input:** Razer AppEngine 4.0.821 with the exact archive and executable hashes in `source-metadata.json`. This is not a universal isolation layer. Unknown devices/builds are not guessed. OpenBlade conflict checks remain unchanged.

## Prepare locally

Requires Windows, PowerShell and Node.js 22 or newer. There are no npm dependencies. Exit Synapse before preparing, and ensure the original supported installation is present.

```powershell
npm test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Prepare.ps1
npm run test:local
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Apply -WhatIf
```

Preparation copies your installed archive locally and generates the patch. It does not modify installed Synapse. Generated archives and extracted modules are ignored by Git. ExecutionPolicy Bypass applies only to the child PowerShell process.

## Apply and restore

Exit Synapse and shut down OpenBlade through its Settings page. Run Apply from an administrator PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Apply
```

Confirm `Success: True`, then launch Synapse normally. Keep OpenBlade stopped during an experimental trial. The helper never stops other software, automatically repatches updates, or installs a service/driver.

To undo, exit Synapse, keep OpenBlade stopped, and run in administrator PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Restore
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Status
```

Status must say `Original` before restarting OpenBlade. Restore requires the verified local `original.asar`, but not `blocked.asar`. Keep the local original and the uniquely named installation backup. Unknown archive or executable hashes are refused; after a verification error, do not launch Synapse or overwrite unfamiliar files.

Restore before updating Synapse. A new build requires fresh review. Status examines the fixed 4.0.821 path, not whichever newer version a launcher might select. Keep the updater closed during replacement; hash checks are not a filesystem lock against a concurrent updater.

## Evidence and limits

- 40 reviewed Blade product IDs in the registry; this does not mean 40 models were physically tested.
- Blade 16 `1532:02E0`: the preceding revision suppressed observed 90-byte and 374-byte reports in startup/exit traces. Remaining short requests ran in Windows System context.
- Latest revision: the user reported Pro Click V2 `1532:00D1` detection, basic input and requested customization checks working while the Blade was absent. Lighting was conditional on availability. This is user-reported evidence, not an automated compatibility matrix.
- Shared native/host routes remain available. Complete isolation, other peripherals, sleep/resume and future builds remain unverified. Do not bypass OpenBlade's Synapse checks based on this tool.

See [VALIDATION.md](VALIDATION.md) for exact artifact and test scope. The goal is a small reversible experiment, not kernel enforcement or suppression of peripheral-triggered global Windows actions.

## Source and tests

`build-prototype-blades.cjs` applies exact, single-occurrence edits to a locally supplied original archive. The two policy modules and device registry are embedded into the resulting archive. The builder verifies every untouched packed entry byte-for-byte and rejects an unexpected original hash. `Prepare.ps1` also checks the executable and exact expected output hash.

`npm test` runs six source-only policy checks and can run in CI without Synapse. `npm run test:local` runs 88 checks against locally extracted/patched modules after preparation; native dependencies are replaced with inert mocks. Never commit generated archives, extracted vendor code, or raw diagnostic captures.

This initial draft intentionally leaves project licensing for the repository owner to select. Razer components are not included or licensed by this repository.
