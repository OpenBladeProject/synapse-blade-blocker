# Validation record

Initial source import reproduces archive SHA-256 `3fa3cd488659d6c36cd8b8da580cf57f5873f5bb1769a3cb016df667b54cfe5f` from AppEngine 4.0.821. The builder verifies 9,947 untouched packed entries. Six source-only policy checks and 88 local-module checks pass in this repository.

The research suite previously had 103 tests. Fifteen tests depending on separate catalog snapshots or historical extracted FFI artifacts were not imported. Do not describe this repository's suite as 103 tests.

The earlier live UCX comparison used archive `88fd45b1a21d7c120a5f2704e2dfa781d77feaff8cb21e88a743792bbd1c6398`. Original Synapse dispatched 149 90-byte SET_REPORT, 148 90-byte GET_REPORT and 92 374-byte SET_REPORT requests in its main process. Patched startup/exit dispatched none of those reports. Both traces reported zero lost events. Exact Blade identity was correlated by controller and port, not report size alone. System-context requests remained; their indirect cause was not established.

The latest archive adds origin checks to electronAction StartService/StopService/GetServiceStatus. Actual-handler tests show Blade pages and child frames rejected before dispatch; shared and peripheral origins retain access. No real service operation is invoked by these tests.

September 18–19, 2026: the latest archive was used with a Razer Pro Click V2 (1532:00D1) and Blade 16 (1532:02E0). The user confirmed the mouse appeared, the Blade was absent and ordinary input worked. They then reported all requested customization checks working (remapping, harmless macro, profile switching, lighting if available). Per-feature screenshots, lighting availability and restoration of temporary mouse bindings were not independently documented.

Original Synapse was restored and OpenBlade restarted after the trial. No blocker remains installed on the test machine as of that verification. These are historical observations, not a statement about current machine state.

Private raw captures and vendor archives are excluded. This evidence supports an experimental one-device/build result, not universal enforcement or an OpenBlade conflict bypass.
