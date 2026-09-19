# Validation record

## Current version-independent preparation

September 19, 2026: dynamic discovery selected the installed AppEngine **4.0.823**. Preparation succeeded using its actual archive and executable without adding a supported-version entry or accepted hash. All 10,059 untouched packed entries were verified byte-for-byte. The original archive hash was `170d9fa0d146cd3f9a3d6d7d00a8c1fd221e1f85da34f7d385fe378d43d0c0af`, executable hash `dd18cb63ec4277a80800f78bfa700c03d01fc13a0a199de1e576bda76e1d3455`, and generated archive hash `77b9fe55076135b5344b3766b5e591a26ab9fe63ef0e637234924f4797cf56de`. These identify tested artifacts; no code gates compatibility on them.

The 88 local-module checks passed against the generated 4.0.823 modules. Mocks discover native/service minifier aliases from each prepared build and never load native vendor dependencies. Source tests also cover a synthetic future version with changed executable bytes and renamed aliases, missing/duplicate mandatory routes, missing wrappers, malformed input, already-patched input, preserved prior preparations, and privacy-safe failure reports.

The PowerShell operation suite uses disposable synthetic files to verify newest/active installation selection, standard-path bounds, Apply/Restore, applied marker fields, missing-marker repair, idempotence, unique backup preservation, corrupted rollback refusal, unknown update refusal, and restore without the patch file. Actual installed Apply/Restore and native execution were not performed for this revision. The marker lifecycle is verified with scratch fixtures, not a fresh physical trial.

The operation suite also covers relative paths after `Push-Location`, UTC timestamp comparisons and future rejection, and actual early-discovery diagnostic calls with missing archive/executable paths. The reports are checked for the PowerShell version and absence of private paths. CI runs this suite in both Windows PowerShell 5.1 and PowerShell 7 with the runner timezone set to Pacific Standard Time.

The retained historical 92,801,061-byte local original archive from 4.0.821 also transforms with the new structural builder and verifies 9,947 untouched entries. Its local files remain preserved.

## Historical physical evidence

The initial source import reproduced archive SHA-256 `3fa3cd488659d6c36cd8b8da580cf57f5873f5bb1769a3cb016df667b54cfe5f` from AppEngine 4.0.821. That exact output is historical evidence, not the output required for future builds. Six source-only policy checks and 88 local-module checks passed at that revision.

The research suite previously had 103 tests. Fifteen tests depending on separate catalog snapshots or historical extracted FFI artifacts were not imported. Do not describe the original imported suite as 103 tests.

The earlier live UCX comparison used archive `88fd45b1a21d7c120a5f2704e2dfa781d77feaff8cb21e88a743792bbd1c6398`. Original Synapse dispatched 149 90-byte SET_REPORT, 148 90-byte GET_REPORT and 92 374-byte SET_REPORT requests in its main process. Patched startup/exit dispatched none of those reports. Both traces reported zero lost events. Exact Blade identity was correlated by controller and port, not report size alone. System-context requests remained; their indirect cause was not established.

The subsequent archive added origin checks to electronAction StartService/StopService/GetServiceStatus. Actual-handler tests show Blade pages and child frames rejected before dispatch; shared and peripheral origins retain access. No real service operation is invoked by these tests.

September 18–19, 2026: that historical archive was used with a Razer Pro Click V2 (1532:00D1) and Blade 16 (1532:02E0). The user confirmed the mouse appeared, the Blade was absent and ordinary input worked. They then reported all requested customization checks working (remapping, harmless macro, profile switching, lighting if available). Per-feature screenshots, lighting availability and restoration of temporary mouse bindings were not independently documented.

Original Synapse was restored and OpenBlade restarted after the trial. No blocker remained installed at that verification. This is a historical observation, not a statement about current machine state.

Private raw captures and vendor archives are excluded. The evidence supports an experimental one-device physical result and structural preparation for additional builds, not universal enforcement. Applied metadata permits a separate OpenBlade integration to recognize matching artifacts; metadata alone does not establish isolation.
