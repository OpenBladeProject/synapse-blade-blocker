[CmdletBinding()]
param([switch]$SmokeTest,[switch]$SmokeInspect,[string]$SmokeScreenshot,[ValidateRange(560,1600)][int]$SmokeWidth=680)
$ErrorActionPreference='Stop'
if($SmokeInspect -and !$SmokeTest){throw 'SmokeInspect requires SmokeTest and performs read-only inspection only.'}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
. (Join-Path $PSScriptRoot 'BladeBlocker.Desktop.ps1')
$administrator=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if($administrator -and !$SmokeTest){
 [System.Windows.MessageBox]::Show('Open Start-BladeBlocker.cmd normally, without Run as administrator. This window requests administrator approval only when you choose Patch or Restore.','Open normally','OK','Information') | Out-Null
 return
}
[xml]$markup=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Synapse Blade Blocker" Width="680" Height="640" MinWidth="560" MinHeight="520" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="14" Background="#F5F6F8" Foreground="#17212D">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Padding" Value="16,10"/><Setter Property="MinHeight" Value="44"/><Setter Property="Margin" Value="0,0,10,8"/></Style>
  <Style TargetType="TextBlock"><Setter Property="TextWrapping" Value="Wrap"/></Style>
  <Style x:Key="NoticeStyle" TargetType="TextBlock" BasedOn="{StaticResource {x:Type TextBlock}}"><Style.Triggers><Trigger Property="Text" Value=""><Setter Property="Visibility" Value="Collapsed"/></Trigger></Style.Triggers></Style>
 </Window.Resources>
 <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
 <StackPanel Margin="28">
  <TextBlock Text="Synapse Blade Blocker" FontSize="28" FontWeight="SemiBold"/>
  <TextBlock Text="Experimental Blade exclusion for Razer Synapse" Margin="0,4,0,20" Foreground="#46566A"/>
  <Border Background="White" BorderBrush="#D6DCE3" BorderThickness="1" CornerRadius="8" Padding="20">
   <StackPanel>
    <TextBlock Text="INSTALLATION STATUS" FontSize="12" FontWeight="SemiBold" Foreground="#46566A"/>
    <TextBlock x:Name="StateText" Text="Checking installation..." FontSize="22" FontWeight="SemiBold" Margin="0,6,0,10" AutomationProperties.LiveSetting="Polite"/>
    <TextBlock x:Name="InstallText" Text="Detecting the standard AppEngine installation." Foreground="#46566A"/>
    <TextBlock x:Name="RuntimeText" Margin="0,6,0,0" Foreground="#46566A"/>
   </StackPanel>
  </Border>
  <ProgressBar x:Name="BusyBar" Height="4" IsIndeterminate="True" Margin="0,12,0,12" AutomationProperties.Name="Operation in progress"/>
  <TextBlock x:Name="NoticeText" Style="{StaticResource NoticeStyle}" FontWeight="SemiBold" Margin="0,12,0,12" AutomationProperties.LiveSetting="Assertive"/>
  <TextBlock x:Name="DetailsText" Margin="0,16,0,18" Text="Inspection is read-only. Patch and Restore are available only after their requirements are checked."/>
  <TextBlock Text="Before Patch or Restore" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,6"/>
  <TextBlock Text="Exit Synapse and use OpenBlade Settings &gt; Shut down OpenBlade. Windows will ask for administrator approval. This tool does not stop or restart either application." Margin="0,0,0,16"/>
  <WrapPanel>
   <Button x:Name="PatchButton" Content="_Patch" IsEnabled="False" MinWidth="110" ToolTip="Prepare a verified backup, then request administrator approval to apply the patch."/>
   <Button x:Name="RestoreButton" Content="_Restore" IsEnabled="False" MinWidth="110" ToolTip="Restore the verified original archive from its matching preparation."/>
   <Button x:Name="RefreshButton" Content="Re_fresh" IsEnabled="False"/>
  </WrapPanel>
  <Expander Header="Backups and diagnostics" IsExpanded="False" Margin="0,12,0,16" FontSize="14">
   <StackPanel Margin="0,12,0,0">
    <TextBlock Text="Original backup and preparation" FontWeight="SemiBold"/>
    <TextBlock x:Name="PreparationText" Text="Automatic: search this package's prepared folder." Margin="0,6,0,12" Foreground="#46566A"/>
    <WrapPanel>
     <Button x:Name="ChooseButton" Content="_Choose preparation..." IsEnabled="False"/>
     <Button x:Name="AutomaticButton" Content="_Automatic" IsEnabled="False"/>
    </WrapPanel>
    <TextBlock Text="Keep the complete package and every prepared folder. After extracting a new copy, choose the previous preparation folder to recover its original backup." Foreground="#46566A" Margin="0,2,0,16"/>
    <WrapPanel><Button x:Name="CopyButton" Content="_Copy diagnostic details" IsEnabled="False"/><Button x:Name="ReportsButton" Content="Open saved _reports" IsEnabled="False"/></WrapPanel>
    <TextBlock Text="Copied details include file hashes and status, without local paths or source code." FontSize="12" Foreground="#46566A"/>
   </StackPanel>
  </Expander>
  <TextBlock Text="Experimental: file verification alone does not prove Blade isolation or compatibility with every peripheral." FontSize="12" Foreground="#46566A"/>
 </StackPanel>
 </ScrollViewer>
</Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $markup
$window=[Windows.Markup.XamlReader]::Load($reader)
$controls=@{}
foreach($name in @('StateText','InstallText','RuntimeText','BusyBar','NoticeText','DetailsText','PatchButton','RestoreButton','RefreshButton','PreparationText','ChooseButton','AutomaticButton','CopyButton','ReportsButton')){$controls[$name]=$window.FindName($name)}
$script:desktopJob=$null;$script:desktopResult=$null;$script:selectedPreparation='';$script:lastOutcome='Inspection'

function Set-DesktopBusy([bool]$Busy) {
 $controls.BusyBar.Visibility=if($Busy){'Visible'}else{'Collapsed'}
 foreach($name in @('RefreshButton','ChooseButton','AutomaticButton','ReportsButton')){$controls[$name].IsEnabled=!$Busy}
 $controls.CopyButton.IsEnabled=!$Busy -and $null -ne $script:desktopResult
 $controls.PatchButton.IsEnabled=!$Busy -and $null -ne $script:desktopResult -and $script:desktopResult.CanPatch
 $controls.RestoreButton.IsEnabled=!$Busy -and $null -ne $script:desktopResult -and $script:desktopResult.CanRestore
}
function Show-DesktopState($Result) {
 $script:desktopResult=$Result.State;$script:lastOutcome=$Result.Outcome
 $controls.StateText.Text=$Result.State.State
 $controls.InstallText.Text=if($Result.State.Installation){$Result.State.Installation}else{'No readable standard AppEngine installation detected.'}
 $controls.RuntimeText.Text='Node.js: '+$Result.State.NodeVersion+'  |  Controllers: '+$(if($Result.State.ControllersStopped){'stopped'}else{'running or unavailable'})
 $controls.DetailsText.Text=$Result.State.Message
 $controls.NoticeText.Text=$Result.Notice
 $controls.PreparationText.Text=if($Result.State.PreparationDirectory){$Result.State.PreparationDirectory}else{"Automatic: search this package's prepared folder."}
 Set-DesktopBusy $false
}
function Start-DesktopTask([string]$Action) {
 if($SmokeTest -and $Action -ne 'Refresh'){throw 'Smoke testing permits read-only refresh only.'}
 if($script:desktopJob){return}
 Set-DesktopBusy $true
 $controls.NoticeText.Text=switch($Action){'Patch'{'Preparing and checking files, then requesting administrator approval. Keep this window open.'};'Restore'{'Checking the original backup, then requesting administrator approval. Keep this window open.'};default{'Refreshing read-only status...'}}
 $powershell=[PowerShell]::Create()
 [void]$powershell.AddScript({param($Root,$Action,$Preparation) . (Join-Path $Root 'BladeBlocker.Desktop.ps1'); Invoke-DesktopTask -Action $Action -PreparationDirectory $Preparation}).AddArgument($PSScriptRoot).AddArgument($Action).AddArgument($script:selectedPreparation)
 try{$handle=$powershell.BeginInvoke();$script:desktopJob=[pscustomobject]@{PowerShell=$powershell;Handle=$handle}}
 catch{$powershell.Dispose();$controls.NoticeText.Text='Could not start the operation. Reopen the window and try again.';Set-DesktopBusy $false}
}
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
 if($script:desktopJob -and $script:desktopJob.Handle.IsCompleted){
  $job=$script:desktopJob;$script:desktopJob=$null
  try{
   $results=@($job.PowerShell.EndInvoke($job.Handle));$result=$results | Where-Object {$_ -and $_.PSObject.Properties['Outcome']} | Select-Object -Last 1
   if(!$result){throw 'NoResult'}
   Show-DesktopState $result
  }catch{$script:desktopResult=$null;$controls.StateText.Text='Inspection failed';$controls.NoticeText.Text='Could not read a complete status. Refresh before attempting an operation. Keep all backups.';Set-DesktopBusy $false}
  finally{$job.PowerShell.Dispose()}
 }
})
$controls.RefreshButton.Add_Click({Start-DesktopTask 'Refresh'})
$controls.PatchButton.Add_Click({
 if([Windows.MessageBox]::Show($window,'Patch the detected AppEngine installation? A new preparation is created when needed. Keep all preparations for Restore. Exit Synapse and shut down OpenBlade before continuing. Windows will ask for administrator approval.','Apply experimental patch','OKCancel','Warning') -eq 'OK'){Start-DesktopTask 'Patch'}
})
$controls.RestoreButton.Add_Click({
 if([Windows.MessageBox]::Show($window,'Restore the verified original archive? Exit Synapse and shut down OpenBlade before continuing. Windows will ask for administrator approval. All backups will be preserved.','Restore original archive','OKCancel','Question') -eq 'OK'){Start-DesktopTask 'Restore'}
})
$controls.ChooseButton.Add_Click({
 $dialog=New-Object System.Windows.Forms.FolderBrowserDialog
 $dialog.Description='Choose the preparation folder containing preparation.json and original.asar.'
 $dialog.ShowNewFolderButton=$false
 try{if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$script:selectedPreparation=$dialog.SelectedPath;Start-DesktopTask 'Refresh'}}finally{$dialog.Dispose()}
})
$controls.AutomaticButton.Add_Click({$script:selectedPreparation='';Start-DesktopTask 'Refresh'})
$controls.CopyButton.Add_Click({
 try{[Windows.Clipboard]::SetText((ConvertTo-DesktopDiagnostic $script:desktopResult $script:lastOutcome));$controls.NoticeText.Text='Diagnostic details copied without local paths or source code.'}
 catch{$controls.NoticeText.Text='The clipboard is busy. Try Copy diagnostic details again.'}
})
$controls.ReportsButton.Add_Click({
 $reportDirectory=Join-Path $PSScriptRoot 'diagnostics'
 if(Test-Path -LiteralPath $reportDirectory -PathType Container){
  try{Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList (ConvertTo-DesktopArgument $reportDirectory) | Out-Null}
  catch{$controls.NoticeText.Text='Could not open saved reports. Open the diagnostics folder in this package manually.'}
 }else{$controls.NoticeText.Text='No saved reports yet. A preparation or operation failure can save a sanitized compatibility report in this package''s diagnostics folder.'}
})
$window.Add_Closing({param($sender,$eventArgs)
 if($script:desktopJob){$eventArgs.Cancel=$true;$controls.NoticeText.Text='Wait for the current operation to finish before closing. If a Windows approval prompt is open, approve or cancel it.'}
})
$window.Add_Closed({$timer.Stop()})
if($SmokeTest){
 # The optional inspection exercises the production asynchronous Refresh path.
 # Mutation is rejected above even if someone clicks a button during this smoke run.
 $window.Width=$SmokeWidth
 $window.Show();$window.UpdateLayout()
 if($SmokeInspect){
  $timer.Start();Start-DesktopTask 'Refresh'
  $script:smokeFrame=New-Object Windows.Threading.DispatcherFrame
  $script:smokeDeadline=[DateTime]::UtcNow.AddSeconds(30)
  $script:smokeTimedOut=$false
  $smokeTimer=New-Object Windows.Threading.DispatcherTimer
  $smokeTimer.Interval=[TimeSpan]::FromMilliseconds(100)
  $smokeTimer.Add_Tick({
   if(!$script:desktopJob){$script:smokeFrame.Continue=$false}
   elseif([DateTime]::UtcNow -ge $script:smokeDeadline){$script:smokeTimedOut=$true;$script:smokeFrame.Continue=$false}
  })
  $smokeTimer.Start()
  try{[Windows.Threading.Dispatcher]::PushFrame($script:smokeFrame)}
  finally{$smokeTimer.Stop();$timer.Stop()}
  if($script:smokeTimedOut){
   if($script:desktopJob){$script:desktopJob.PowerShell.Stop();$script:desktopJob.PowerShell.Dispose();$script:desktopJob=$null}
   $window.Close();throw 'Read-only asynchronous inspection exceeded its 30-second smoke-test limit.'
  }
  if(!$script:desktopResult){$window.Close();throw 'The read-only asynchronous inspection did not return a complete status.'}
  $window.UpdateLayout()
 }
 if($SmokeScreenshot){
  $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]$window.ActualWidth),([int]$window.ActualHeight),96,96,([Windows.Media.PixelFormats]::Pbgra32)
  $bitmap.Render($window);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create($SmokeScreenshot);try{$encoder.Save($stream)}finally{$stream.Dispose()}
 }
 [pscustomobject]@{WindowConstructed=$true;IsVisible=$window.IsVisible;Visibility=[string]$window.Visibility;IsLoaded=$window.IsLoaded;ReadOnlyInspectionCompleted=[bool]($SmokeInspect -and $script:desktopResult);State=$controls.StateText.Text;ControlCount=$controls.Count;PatchEnabled=$controls.PatchButton.IsEnabled;RestoreEnabled=$controls.RestoreButton.IsEnabled;Width=$window.ActualWidth;Height=$window.ActualHeight} | ConvertTo-Json
 $window.Close();return
}
$window.Add_ContentRendered({$timer.Start();Start-DesktopTask 'Refresh'})
[void]$window.ShowDialog()
