# Synapse Blade Blocker

Experimental Blade exclusion for Razer Synapse: keep Synapse available for peripherals while suppressing recognized Blade discovery and selected laptop-specific routes.

The initial unreleased tool version is `0.1.0`. Query it offline with Windows PowerShell 5.1 or PowerShell 7; this command does not require Synapse, Node.js, installation discovery, or administrator access:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Version
```

There is **no Synapse version or executable-hash allowlist**. Each installed build is prepared from its own original archive. Preparation requires every structural edit to match exactly once, checks JavaScript syntax, and verifies untouched packed files byte-for-byte. Changed or incomplete layouts stop preparation and produce a sanitized issue report. Successful preparation is evidence that the edits fit that build, not proof of complete hardware isolation.

## Prepare locally

Requires Windows, PowerShell and Node.js 22 or newer. There are no npm dependencies. Exit Synapse and keep its updater closed while preparing and applying.

```powershell
npm test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Prepare.ps1
npm run test:local
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Apply -WhatIf
```

Discovery prefers the exact active AppEngine process directory, otherwise the newest `app-VERSION` directory under `%ProgramFiles%\Razer\RazerAppEngine`. Both scripts accept `-InstallDirectory` for an explicit directory within that standard layout. Ambiguous active installations and reparse-point installation paths are refused.

Each preparation creates a new ignored `prepared/<timestamp>-<id>/` folder with `original.asar`, `blocked.asar`, extracted patched modules, and `preparation.json`. The manifest records hashes of the actual source, executable, and output plus the embedded Blade registry IDs. Existing preparations, backups, and legacy local `original.asar` are preserved. Preparation only reads installed files.

Apply/Restore automatically find a local preparation whose archive and executable hashes match the selected installation. Use `-PreparationDirectory` to select one explicitly. Local module tests select the newest completed preparation; set `BLOCKER_PREPARATION_DIRECTORY` to test a particular folder.

Relative `-InstallDirectory` and `-PreparationDirectory` paths resolve from the current PowerShell location. Windows PowerShell 5.1 and PowerShell 7 are covered by scratch operation tests, including non-UTC local timezones and UTC marker validation. Future-dated markers are rejected. Early discovery failures retain the PowerShell version in sanitized diagnostics; a missing matching preparation is reported as missing input.

## Apply and restore

Exit Synapse and shut down OpenBlade through its Settings page. Run Apply from an administrator PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Apply
```

Confirm `Success: True` and `ToolVersion: 0.1.0`, then launch Synapse normally. Status, preparation, Apply, and Restore success output all report the same package-backed tool version. The helper verifies the original rollback archive, stages the patch, checks for a concurrent update, atomically replaces `app.asar`, preserves a unique installation backup, verifies the result, and then writes `resources/synapse-blade-blocker.json`.

The applied metadata contract is:

```json
{
  "schemaVersion": 1,
  "patchId": "OSSBlade/synapse-blade-blocker",
  "archiveSha256": "<full installed patched app.asar SHA-256>",
  "executableSha256": "<actual RazerAppEngine.exe SHA-256>",
  "appliedAtUtc": "<UTC ISO timestamp after verified replacement>",
  "bladeProductIds": [563, 736]
}
```

The IDs above are illustrative; the real marker contains all excluded numeric PIDs from the embedded registry. No paths are stored in the marker. An OpenBlade integration can verify the marker against the neighboring archive, parent executable, current process, and embedded registry. A missing or mismatched marker must disable recognition. The marker records an applied patch; it does not certify security isolation. Historical OpenBlade versions without that integration continue their normal conflict checks.

To undo, exit Synapse, shut down OpenBlade, and run in administrator PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Restore
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Status
```

Restore verifies and restores the matching original, then removes the applied marker. It does not need the patched archive. Repeated Apply/Restore calls are idempotent; Apply can recreate missing metadata after verifying an already-patched archive. Keep every local original and installation backup. Unknown archives or executable updates are preserved, never overwritten with an older build. Prepare a new original build after an update. No automatic repatching, process stopping, service installation, or driver installation occurs.

Keep the updater closed during replacement: the final hash check detects an observed update, but is not a filesystem lock against an updater racing immediately afterward. If replacement verification fails, preserve the reported backup and do not launch Synapse until the installation has been reconciled.

## If a patch fails

Preparation, Apply, and Restore failures print a copyable Markdown diagnostic and try to save it under ignored `diagnostics/`. It includes tool and runtime versions, patch contract, discovered AppEngine version, available full hashes, failure stage/category, and the missing or ambiguous anchor label/count when available. Raw exceptions, local paths, usernames, serials, archive contents, and native code are omitted. Failure to save a report does not hide the original error.

Paste the report into a [compatibility issue](https://github.com/OSSBlade/synapse-blade-blocker/issues/new/choose) and describe what you were trying to do. Do not upload vendor archives or raw captures. The tool never submits an issue automatically.

## Evidence and limits

- The registry includes 40 reviewed Blade product IDs; this is not a 40-model physical test matrix.
- The historical Blade 16 `1532:02E0` trial suppressed observed 90-byte and 374-byte reports in startup/exit traces. Short System-context requests remained.
- The user reported Pro Click V2 `1532:00D1` discovery, ordinary input, and requested customization checks working while the Blade was absent. This is user-reported evidence.
- Shared native/host routes remain available. Complete isolation, other peripherals, sleep/resume, and hardware behavior on future builds remain unverified.

See [VALIDATION.md](VALIDATION.md) for artifact and test scope. `npm test` runs source-only policy, compatibility and diagnostic checks. `npm run test:operations` exercises discovery and reversible replacement using disposable synthetic files. `npm run test:local` runs 88 checks against prepared modules with inert native mocks. Never commit generated archives, extracted vendor code, or raw diagnostic captures.

Project licensing remains for the repository owner to select. Razer components are not included or licensed by this repository.
