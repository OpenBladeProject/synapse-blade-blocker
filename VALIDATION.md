# Validation record

## Current version-independent preparation

September 19, 2026: dynamic discovery selected the installed AppEngine **4.0.823**. Preparation succeeded using its actual archive and executable without adding a supported-version entry or accepted hash. All 10,059 untouched packed entries were verified byte-for-byte. The original archive hash was `170d9fa0d146cd3f9a3d6d7d00a8c1fd221e1f85da34f7d385fe378d43d0c0af`, executable hash `dd18cb63ec4277a80800f78bfa700c03d01fc13a0a199de1e576bda76e1d3455`, and generated archive hash `77b9fe55076135b5344b3766b5e591a26ab9fe63ef0e637234924f4797cf56de`. These identify tested artifacts; no code gates compatibility on them.

The 88 local-module checks passed against the generated 4.0.823 modules. Mocks discover native/service minifier aliases from each prepared build and never load native vendor dependencies. Source tests also cover a synthetic future version with changed executable bytes and renamed aliases, missing/duplicate mandatory routes, missing wrappers, malformed input, already-patched input, preserved prior preparations, and privacy-safe failure reports.

The PowerShell operation suite uses disposable synthetic files to verify newest/active installation selection, standard-path bounds, Apply/Restore, applied marker fields, missing-marker repair, idempotence, unique backup preservation, corrupted rollback refusal, unknown update refusal, and restore without the patch file. The scratch suite performs no native vendor execution. The subsequent installed trial is recorded below.

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

## Local integration trial: 2026-09-19

At blocker revision 1261363e1c53a963f23b06d9cef554d22d5932d5, fresh preparation of AppEngine 4.0.823 preserved 10,059 unrelated packed files and all 88 mocked-module checks passed. Real Apply and Restore succeeded under PowerShell 7.6.5 in Pacific time.

While four patched AppEngine processes ran after application, a read-only probe of OpenBlade core revision 466966e84c2114444684d53e2dc309ad1c7f3fc2 reported Safe=true, no conflicts and no detection error. OpenBlade and RGS were stopped. The user confirmed Pro Click V2 visible, Blade absent and mouse working, then exited Synapse. This trial did not separately exercise remapping, macros, profiles or lighting.

Restoration recovered the exact original archive hash and removed the marker. The installed OpenBlade service and Session Agent hashes remained unchanged; the service, one tray and one Session Agent were restarted. Synapse was left stopped. The trial exercised the new core guard without installing the new OpenBlade build, so it does not establish installed UI integration or complete hardware isolation.

## Delayed lighting-helper conflict

The subsequent installed trial used blocker revision `50375ea6` (tool version 0.1.0) and OpenBlade core revision `7ce1b87c`. The initial status was clear, but Synapse later launched its `razerwdl` Windows lighting helper and OpenBlade displayed a conflict. This supersedes the initial snapshot as coexistence-readiness evidence and is tracked in [#5](https://github.com/OSSBlade/synapse-blade-blocker/issues/5). The original archive was restored by hash, its applied marker removed, and OpenBlade restarted with no detected competing controllers.

The helper's parent argument identifies AppEngine and its session argument identifies an RPC session, not a mouse or laptop. Native inspection supports Windows LampArray as its observed device-access route; it does not establish that the archive patch filters the helper's native enumeration. A read-only Windows endpoint query found two Pro Click V2 LampArray interfaces and no Blade LampArray interface. Core is adding a narrow, fresh endpoint/provenance check; a final installed trial with the delayed helper running is still required. No helper version or historical binary hash is used as a compatibility allowlist.
