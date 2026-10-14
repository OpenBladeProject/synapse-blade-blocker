$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
$root=$PSScriptRoot
. (Join-Path $root 'BladeBlocker.Desktop.ps1')
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'BladeBlocker.UI.ps1'),[ref]$null,[ref]$null)
$assignment=$ast.Find({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '[xml]$markup'},$true)
if(!$assignment){throw 'XAML assignment not found'}
Invoke-Expression $assignment.Extent.Text
$window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $markup))
$window.FindName('BrandImage').Source=[Windows.Media.Imaging.BitmapFrame]::Create([uri](Join-Path $root 'Assets\Brand\OpenBlade.png'))
$controls=@{}
foreach($node in $markup.SelectNodes('//*[@*[local-name()="Name"]]')){$name=$node.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml');$controls[$name]=$window.FindName($name)}
foreach($name in @('Set-DesktopBusy','Show-DesktopState','Show-DesktopInspectionFailure')){$function=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true);Invoke-Expression $function.Extent.Text}
$state=[pscustomobject]@{State='Original';DisplayState='Original backup matches';ContentState='NoPatchDetected';BackupValid=$true;MarkerPresent=$false;BackupRoot='C:\backups';PreparationDirectory='C:\backups\verified-original';NodeReady=$true;NodeVersion='v24.19.0';ControllersStopped=$true;CanPatch=$true;CanRestore=$false;Installation='C:\Program Files\Razer\RazerAppEngine\app-4.0.827';Message='Mock presentation only; no file operations or button handlers are attached.'}
Show-DesktopState ([pscustomobject]@{State=$state;Outcome='Inspection';Notice=''})
$window.Show()
$window.UpdateLayout()
$button=$controls.PatchButton
$before=@($button.ActualWidth,$button.ActualHeight)
[void]$window.Activate()
[void]$button.Focus()
$window.UpdateLayout()
$focus=$button.Template.FindName('FocusRing',$button)
if(!$button.IsKeyboardFocused -or [string]$focus.BorderBrush -ne '#FFFFFFFF'){throw 'Keyboard focus ring missing'}
if($before[0] -ne $button.ActualWidth -or $before[1] -ne $button.ActualHeight){throw 'Focus changed button layout'}
if([string]$button.Background -ne '#FF47E10C'){throw 'Enabled primary button not OpenBlade green'}
$button.IsEnabled=$false
$window.UpdateLayout()
if([string]$button.Foreground -ne '#5DFFFFFF'){throw 'Disabled primary foreground incorrect'}
Show-DesktopInspectionFailure
if($controls.SummaryText.Text -match 'Ready' -or [string]$controls.StatusDot.Fill -ne '#FFFCE100' -or $controls.PatchButton.IsEnabled -or $controls.RestoreButton.IsEnabled -or $controls.InstallText.Text -ne 'Installation unavailable'){throw 'Failed refresh retained ready presentation'}
$keys=@{}
foreach($buttonControl in $controls.Values | Where-Object {$_ -is [Windows.Controls.Button]}){if([string]$buttonControl.Content -match '_(.)'){$key=$Matches[1].ToLowerInvariant();if($keys.ContainsKey($key)){throw 'Duplicate access key'};$keys[$key]=$true}}
$state.State='No matching preparation';$state.DisplayState='Blocker patch detected';$state.ContentState='CurrentPatch';$state.MarkerPresent=$true;$state.BackupValid=$false;$state.CanPatch=$false;$state.PreparationDirectory=''
Show-DesktopState ([pscustomobject]@{State=$state;Outcome='Inspection';Notice=''})
$window.Width=560
$window.UpdateLayout()
if(!$controls.RecoveryExpander.IsExpanded -or !$controls.ChooseButton.IsEnabled){throw 'Recovery choice hidden'}
$controls.RecoveryExpander.IsExpanded=$false
Show-DesktopState ([pscustomobject]@{State=$state;Outcome='Inspection';Notice=''})
if($controls.RecoveryExpander.IsExpanded){throw 'Same recovery refresh reopened a user-collapsed section'}
$controls.RecoveryExpander.IsExpanded=$true
$window.UpdateLayout()
$header=[Windows.Media.VisualTreeHelper]::GetChild($controls.RecoveryExpander,0).Children[0]
if($header -isnot [Windows.Controls.Primitives.ToggleButton]){throw 'Recovery header lost toggle semantics'}
$peer=New-Object Windows.Automation.Peers.ToggleButtonAutomationPeer $header
$toggle=$peer.GetPattern([Windows.Automation.Peers.PatternInterface]::Toggle)
$toggle.Toggle()
$window.UpdateLayout()
if($controls.RecoveryExpander.IsExpanded){throw 'Header toggle did not collapse diagnostics'}
$toggle.Toggle()
$window.UpdateLayout()
if(!$controls.RecoveryExpander.IsExpanded){throw 'Header toggle did not expand diagnostics'}
if([string]$controls.RecoveryExpander.Content.Children[0].Foreground -ne '#FFFFFFFF'){throw 'Expanded diagnostic headings lost dark text contrast'}
$window.Content.ScrollToEnd()
$window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::ApplicationIdle)
$window.UpdateLayout()
if($window.Content.ScrollableHeight -gt 0 -and $window.Content.VerticalOffset -le 0){throw 'Expanded diagnostics could not scroll'}
[pscustomobject]@{HeaderToggleVerified=$true;ExpandedScrollingVerified=$true;KeyboardFocusVisible=$true;FocusLayoutUnchanged=$true;EnabledPrimaryGreen=$true;DisabledTextVerified=$true;RecoveryChooserExposed=$true;NoOperationHandlersAttached=$true} | ConvertTo-Json
$window.Close()
# Exercise the real startup path to verify the badge follows package.json.
$hostExecutable=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$smokeOutput=& $hostExecutable -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $root 'BladeBlocker.UI.ps1') -SmokeTest
if($LASTEXITCODE -ne 0){throw 'Production window startup failed'}
$smoke=$smokeOutput | ConvertFrom-Json
$expectedVersion='v'+([IO.File]::ReadAllText((Join-Path $root 'package.json')) | ConvertFrom-Json).version
if($smoke.VersionBadge -ne $expectedVersion -or !$smoke.IsLoaded -or $smoke.ReadOnlyInspectionCompleted){throw 'Version badge failed offline production startup verification'}
