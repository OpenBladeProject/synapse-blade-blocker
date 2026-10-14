# Technical guide

Use the [README](README.md) for the window workflow. The commands below prepare, apply, and restore the patch from PowerShell.

## Compatibility and status

To check the tool version offline, run the following command. It works without Synapse, Node.js, installation discovery, or administrator access:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Version
```

The tool prepares each installed build from its own original archive, without a Synapse version or executable-hash allowlist. Each structural edit must match exactly once. Preparation checks JavaScript syntax and verifies untouched packed files byte-for-byte. Changed or incomplete layouts stop preparation and produce a sanitized issue report.

The window stays responsive during checks and preparation and explains missing prerequisites, running controllers, missing backups, and changed installations. Cancelling the administrator prompt leaves the installed archive unchanged. Apply and Restore do not stop or restart applications. Only the selected operation runs elevated; the window keeps normal user permissions.

After a Synapse update, refresh the status and prepare the updated build. Do not reuse an older backup for a changed installation. If an operation fails, expand **Backups and diagnostics**. Use **Copy diagnostic details** for sanitized status or **Open saved reports** for compatibility reports from preparation or archive replacement. Follow the displayed recovery instructions. Keep backups if replacement cannot be verified, and do not launch Synapse until the installation is reconciled.

The window inspects archive contents to detect earlier patches, even without an applied marker or preparation folder. It reports recognized patches, incomplete or unfamiliar blocker traces, or no recognized edits. Unreadable archives remain unknown. Backup hash matches are reported separately; they do not establish that a saved original was never modified. Restore always requires the matching verified original.

## Prepare the patch

Open PowerShell in the extracted folder. Exit Synapse and keep its updater closed while preparing and applying.

```powershell
npm test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Prepare.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Apply -WhatIf
```

For local module checks, set `BLOCKER_PREPARATION_DIRECTORY` to the folder returned by Prepare, then run `npm run test:local`.

Discovery uses the exact active AppEngine process directory when available, or the newest `app-VERSION` directory under `%ProgramFiles%\Razer\RazerAppEngine`. Both scripts accept `-InstallDirectory` for an explicit directory within that standard layout. They reject ambiguous active installations and reparse-point installation paths.

Each preparation creates a new `<timestamp>-<id>` folder in **Documents > Synapse Blade Blocker > Backups** by default. It uses the Windows Documents location, including redirected folders. In the window's **Backups** row, use **Open folder** to open it or **Choose location…** to save new backups elsewhere. Earlier backups stay where they are. **Use Documents default** switches back to Documents. The blocker saves the choice and previous locations atomically in `%LOCALAPPDATA%\SynapseBladeBlocker\settings.json`.

Each folder contains `original.asar`, `blocked.asar`, extracted patched modules, and `preparation.json`. The manifest records hashes of the actual source, executable, and output plus the embedded Blade registry IDs and the patch-source fingerprint. Existing preparations, backups, and legacy local `original.asar` are preserved. Preparation only reads installed files.

Automatic lookup searches the selected folder, previously selected locations, the Documents default, the earlier `%LOCALAPPDATA%\SynapseBladeBlocker\Backups` location, and the package's legacy `prepared/` folder. It requires the installation's executable and archive hashes to match a preparation, and prefers an intact original backup over a damaged matching one. Explicit `-PreparationDirectory` selection never falls back to a different backup. Other older preparations can still be selected manually.

Desktop Patch reuses a preparation only after verifying it against the current patch source; otherwise it creates a fresh preparation. Apply checks the patch-source fingerprint and the deterministic transform of the verified original before writing, so an older or altered prepared patch cannot be reused as the current patch. Older originals remain usable for Restore. Apply and Restore receive the resolved preparation path explicitly, including across the administrator prompt; their executable/archive integrity and stopped-controller checks remain required.

Apply and Restore find a preparation whose archive and executable hashes match the selected installation. Use `-PreparationDirectory` to select one explicitly. Local module tests require `BLOCKER_PREPARATION_DIRECTORY` to point to a verified preparation made with the current source.

Relative `-InstallDirectory` and `-PreparationDirectory` paths resolve from the current PowerShell location. Windows PowerShell 5.1 and PowerShell 7 are covered by scratch operation tests, including non-UTC local timezones and UTC marker validation. Future-dated markers are rejected. Early discovery failures retain the PowerShell version in sanitized diagnostics; a missing matching preparation is reported as missing input.

## Apply the patch

Exit Synapse and shut down OpenBlade through its Settings page. Run Apply from an administrator PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Apply
```

Confirm `Success: True` and a `ToolVersion` matching your package, then launch Synapse normally. Status, preparation, Apply, and Restore success output all report the same package-backed tool version. The helper verifies the original rollback archive, stages the patch, checks for a concurrent update, atomically replaces `app.asar`, preserves a unique installation backup, verifies the result, and then writes `resources/synapse-blade-blocker.json`.

Let Synapse finish loading, open a peripheral's page, and check that the peripheral works and the Blade is absent. Then start OpenBlade if you use it. If you see unexpected behavior, restore the original archive and report the issue below.

## Using OpenBlade

[OpenBlade 0.21.0 or newer](https://github.com/OSSBlade/openblade-core/releases/latest) recognizes the applied patch by checking the actual installed files and whether Synapse restarted after application. Normal conflict checks remain in place when the patch is missing, changed, or stale. Use the latest release for subsequent coexistence fixes.

Synapse may start its Windows lighting helper, `razerwdl`, after its UI loads. OpenBlade accepts that helper only when its identity and patched Synapse parent are verified and a fresh Windows device check finds no excluded Blade lighting interface. Unknown device identity, failed enumeration, independent helpers and other competing controllers retain their checks. This does not disable Windows lighting or peripheral features.

OpenBlade 0.24.3 also allows HyperBoost with a verified blocker patch while known Synapse service aliases are present. The verified RGS service does not block HyperBoost; an unverified process using an RGS or updater name still does. A Windows lighting helper with verified Razer identity does not block HyperBoost either; the other controller checks, exact-device checks, and power requirements still apply. See the [core coexistence guide](https://github.com/OpenBladeProject/openblade-core/blob/v0.24.3/docs/synapse-blade-blocker.md) for the full rules.

The September 2026 installed trial passed with Synapse AppEngine 4.0.823, the delayed helper running, and Pro Click V2 visible and working while the Blade stayed absent. OpenBlade showed no conflict warning. See [VALIDATION.md](VALIDATION.md) for the exact tested revisions and limits, and report your results on other configurations.

## Restore the original

To undo, exit Synapse, shut down OpenBlade, and run in administrator PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Restore
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Status
```

Restore verifies the matching original, restores it, and removes the applied marker. It works without the patched archive. Repeating Apply or Restore has the same effect as running it once; Apply can recreate missing metadata after verifying an already-patched archive. Keep every local original and installation backup. The tool preserves unknown archives and executable updates instead of overwriting them with an older build. Prepare a new original build after an update. Repatching requires a user action. The tool leaves process control to the user and installs no services or drivers.

Keep the updater closed during replacement. The final hash check detects updates that have already happened; it cannot prevent an updater from changing files immediately afterward. If replacement verification fails, preserve the reported backup and do not launch Synapse until the installation has been reconciled.

## If a patch fails

Preparation, Apply, and Restore failures print a copyable Markdown diagnostic and try to save it under ignored `diagnostics/`. It includes tool and runtime versions, patch contract, discovered AppEngine version, available full hashes, failure stage/category, and the missing or ambiguous anchor label/count when available. Raw exceptions, local paths, usernames, serials, archive contents, and native code are omitted. Failure to save a report does not hide the original error.

Paste the report into a [compatibility issue](https://github.com/OSSBlade/synapse-blade-blocker/issues/new/choose) and describe what you were trying to do. Do not upload vendor archives or raw captures. The tool never submits an issue automatically.

## Applied metadata

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

The IDs above are illustrative; the real marker contains all excluded numeric PIDs from the embedded registry. No paths are stored in the marker. An OpenBlade integration can verify the marker against the neighboring archive, parent executable, current process, and embedded registry. A missing or mismatched marker must disable recognition. Historical OpenBlade versions without that integration continue their normal conflict checks.

## Evidence and limits

- The historical Blade 16 `1532:02E0` trial suppressed observed 90-byte and 374-byte reports in startup/exit traces. Short System-context requests remained.
- The user reported Pro Click V2 `1532:00D1` discovery, ordinary input, and requested customization checks working while the Blade was absent. This is user-reported evidence.
- Shared native/host routes remain available. Complete isolation, other peripherals, sleep/resume, and hardware behavior on future builds remain unverified.

See [VALIDATION.md](VALIDATION.md) for artifact and test scope. `npm test` runs source-only policy, compatibility and diagnostic checks. `npm run test:operations` exercises discovery and reversible replacement using disposable synthetic files. Set `BLOCKER_PREPARATION_DIRECTORY` to the folder returned by a fresh preparation before running `npm run test:local`; it verifies that the preparation matches the current patch source, then runs the module checks with inert native mocks. Never commit generated archives, extracted vendor code, or raw diagnostic captures.

Project licensing remains for the repository owner to select. Razer components are not included or licensed by this repository.
