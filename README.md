# Synapse Blade Blocker

Keep Razer Synapse for your mouse, keyboard, and other peripherals while keeping your Razer Blade laptop out of Synapse's device list. You can then use OpenBlade to control the laptop.

The patch is experimental and reversible. It recognizes 40 reviewed Blade product IDs; physical testing covers a Blade 16 with a Pro Click V2 mouse. See the [tested configurations and limits](VALIDATION.md) for details. It does not provide security isolation.

## Download

Download [Synapse Blade Blocker 0.3.0](https://github.com/OpenBladeProject/synapse-blade-blocker/releases/tag/v0.3.0) and extract the ZIP.

You need:

- Windows with Razer Synapse already installed.
- Windows PowerShell 5.1 or PowerShell 7.
- Node.js 22 or newer.

Backups go in **Documents > Synapse Blade Blocker > Backups** by default. In the window's **Backups** row, use **Open folder** to find them or **Choose location…** to save new backups elsewhere. The blocker remembers your choice and checks earlier locations too, even after you move or replace the package.

## Patch Synapse

1. Exit Synapse and keep its updater closed. If OpenBlade is running, choose **Settings > Shut down OpenBlade**.
2. Double-click **Start-BladeBlocker.cmd** in the extracted folder. The window checks your installation and explains any missing requirements.
3. Choose **Patch**. The blocker checks the files and saves the original when needed. Accept the Windows administrator prompt when it appears.
4. Wait for the tool to confirm success, then start Synapse normally. Check that your peripheral works and the Blade is absent from the device list before starting OpenBlade.

Use the [latest OpenBlade release](https://github.com/OSSBlade/openblade-core/releases/latest) for the current coexistence fixes. It checks the applied patch and Synapse restart before allowing them to run together.

After a Synapse update, reopen the blocker, refresh its status, and prepare the updated installation before patching again. Keep the new originals; an older backup cannot restore a different build.

## Restore Synapse

Exit Synapse, keep its updater closed, and shut down OpenBlade. Open the blocker and choose **Restore**. It finds the matching saved backup automatically. Accept the administrator prompt and wait for confirmation before starting Synapse again.

For a patch made with an older blocker, open **Backups and diagnostics > Choose preparation…** and select the earlier folder containing `preparation.json` and `original.asar`. Older versions saved backups beside the extracted package, so keep that folder.

## If something goes wrong

Open **Backups and diagnostics** and follow the recovery instructions. If the tool cannot verify a replacement, keep its backups and leave Synapse closed until recovery is complete.

Use **Copy diagnostic details** or **Open saved reports**, then include the sanitized report in a [compatibility issue](https://github.com/OSSBlade/synapse-blade-blocker/issues/new/choose). Describe what you were trying to do. Do not upload Synapse archives or raw captures.

The [technical guide](TECHNICAL.md) covers PowerShell commands, compatibility checks, backups, diagnostics, and OpenBlade integration. [VALIDATION.md](VALIDATION.md) records the test results.

Project licensing remains for the repository owner to select. Razer components are not included or licensed by this repository.
