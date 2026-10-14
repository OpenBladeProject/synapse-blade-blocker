[CmdletBinding()]
param([switch]$SmokeTest,[switch]$SmokeInspect,[string]$SmokeScreenshot,[ValidateRange(560,1600)][int]$SmokeWidth=600)
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
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Synapse Blade Blocker" Width="600" Height="460" MinWidth="560" MinHeight="420" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="13" Background="#F7F8FA" Foreground="#202938" UseLayoutRounding="True">
 <Window.Icon><DrawingImage><DrawingImage.Drawing><GeometryDrawing Brush="White"><GeometryDrawing.Pen><Pen Brush="#0067C0" Thickness="1.5"/></GeometryDrawing.Pen><GeometryDrawing.Geometry><GeometryGroup><RectangleGeometry Rect="3,3,18,13" RadiusX="2" RadiusY="2"/><LineGeometry StartPoint="12,16" EndPoint="12,20"/><LineGeometry StartPoint="7,20" EndPoint="17,20"/></GeometryGroup></GeometryDrawing.Geometry></GeometryDrawing></DrawingImage.Drawing></DrawingImage></Window.Icon>
 <Window.Resources>
  <SolidColorBrush x:Key="MutedBrush" Color="#606B7B"/>
  <Style TargetType="Button">
   <Setter Property="Padding" Value="12,5"/><Setter Property="MinHeight" Value="32"/><Setter Property="Margin" Value="0,0,8,0"/>
   <Setter Property="Background" Value="White"/><Setter Property="Foreground" Value="#202938"/><Setter Property="BorderBrush" Value="#CAD0D9"/><Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
    <Grid>
    <Border x:Name="Surface" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5" Padding="{TemplateBinding Padding}">
     <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/>
    </Border>
    <Border x:Name="FocusRing" BorderBrush="Transparent" BorderThickness="2" CornerRadius="7" Margin="-2" IsHitTestVisible="False"/>
    </Grid>
    <ControlTemplate.Triggers><MultiTrigger><MultiTrigger.Conditions><Condition Property="IsKeyboardFocused" Value="True"/><Condition Property="IsEnabled" Value="True"/></MultiTrigger.Conditions><Setter TargetName="FocusRing" Property="BorderBrush" Value="#0067C0"/></MultiTrigger></ControlTemplate.Triggers>
   </ControlTemplate></Setter.Value></Setter>
   <Style.Triggers>
    <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#EDF1F6"/><Setter Property="BorderBrush" Value="#A9B5C5"/></Trigger>
    <Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="#E1E7EF"/></Trigger>
    <Trigger Property="IsEnabled" Value="False"><Setter Property="Background" Value="#EFF1F4"/><Setter Property="Foreground" Value="#6B7482"/><Setter Property="BorderBrush" Value="#D7DDE5"/><Setter Property="Cursor" Value="Arrow"/></Trigger>
   </Style.Triggers>
  </Style>
  <Style x:Key="PrimaryButtonStyle" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
   <Setter Property="Background" Value="#0067C0"/><Setter Property="BorderBrush" Value="#0067C0"/><Setter Property="Foreground" Value="White"/>
   <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#005AA9"/><Setter Property="BorderBrush" Value="#005AA9"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter Property="Background" Value="#004E92"/></Trigger></Style.Triggers>
  </Style>
  <Style TargetType="TextBlock"><Setter Property="TextWrapping" Value="Wrap"/></Style>
  <Style x:Key="NoticeStyle" TargetType="TextBlock" BasedOn="{StaticResource {x:Type TextBlock}}"><Setter Property="Background" Value="#FFF5E5"/><Setter Property="Foreground" Value="#805000"/><Setter Property="Padding" Value="10,8"/><Setter Property="Margin" Value="0,12,0,0"/><Style.Triggers><Trigger Property="Text" Value=""><Setter Property="Visibility" Value="Collapsed"/></Trigger></Style.Triggers></Style>
 </Window.Resources>
 <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
 <StackPanel Margin="20,18">
  <Grid>
   <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
   <StackPanel><TextBlock Text="Synapse Blade Blocker" FontSize="20" FontWeight="SemiBold"/><TextBlock Text="Keep Synapse for your peripherals" Margin="0,3,0,0" Foreground="{StaticResource MutedBrush}"/></StackPanel>
   <Border Grid.Column="1" Background="#E9EDF3" CornerRadius="4" Padding="8,3" VerticalAlignment="Top" Margin="12,4,0,0"><TextBlock Text="Experimental" FontSize="11" Foreground="#586477"/></Border>
  </Grid>
  <Border Background="White" BorderBrush="#DFE3EA" BorderThickness="1" CornerRadius="7" Padding="14" Margin="0,16,0,0">
   <StackPanel>
    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
     <StackPanel Orientation="Horizontal" VerticalAlignment="Center"><Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#64748B" Margin="0,0,8,0" VerticalAlignment="Center"/><TextBlock x:Name="StateText" Text="Checking Synapse..." FontSize="17" FontWeight="SemiBold" AutomationProperties.LiveSetting="Polite"/></StackPanel>
     <Button Grid.Column="1" x:Name="RefreshButton" Content="Re_fresh" IsEnabled="False" Margin="12,0,0,0" MinHeight="28" Padding="10,3"/>
    </Grid>
    <TextBlock x:Name="InstallText" Text="Finding your installation..." Margin="16,3,0,0" FontSize="12" Foreground="{StaticResource MutedBrush}"/>
    <TextBlock x:Name="SummaryText" Text="Checking files and backups..." Margin="0,12,0,0" LineHeight="19"/>
    <ProgressBar x:Name="BusyBar" Height="2" IsIndeterminate="True" Margin="0,12,0,0" AutomationProperties.Name="Operation in progress"/>
   </StackPanel>
  </Border>
  <TextBlock x:Name="NoticeText" Style="{StaticResource NoticeStyle}" AutomationProperties.LiveSetting="Assertive"/>
  <WrapPanel Margin="0,14,0,0">
   <Button x:Name="PatchButton" Content="_Patch" Style="{StaticResource PrimaryButtonStyle}" IsEnabled="False" MinWidth="80" ToolTip="Check or save the original backup, then apply the patch with administrator approval."/>
   <Button x:Name="RestoreButton" Content="_Restore" IsEnabled="False" MinWidth="80" ToolTip="Restore the matching original backup."/>
  </WrapPanel>
  <TextBlock x:Name="ActionHintText" Text="Windows asks for administrator approval. You close and restart the apps yourself." Foreground="{StaticResource MutedBrush}" FontSize="12" Margin="0,8,0,0" LineHeight="17"/>
  <Border BorderBrush="#DFE3EA" BorderThickness="0,1,0,1" Padding="0,13" Margin="0,16,0,0">
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <StackPanel Margin="0,0,12,0"><TextBlock Text="Backups" FontWeight="SemiBold"/><TextBlock x:Name="BackupLocationText" Text="Checking location..." Foreground="{StaticResource MutedBrush}" FontSize="12" Margin="0,3,0,0" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/></StackPanel>
    <Button Grid.Column="1" x:Name="OpenBackupsButton" Content="Open _folder" IsEnabled="False" VerticalAlignment="Center" ToolTip="Open the folder used for new backups."/>
    <Button Grid.Column="2" x:Name="ChangeBackupsButton" Content="Choose _location..." IsEnabled="False" Margin="0" VerticalAlignment="Center" ToolTip="Choose and remember where to save new backups."/>
   </Grid>
  </Border>
  <Expander x:Name="RecoveryExpander" Header="Backups and diagnostics" IsExpanded="False" Margin="0,12,0,0">
   <StackPanel Margin="0,12,0,0">
    <TextBlock Text="Backup used for Restore" FontWeight="SemiBold"/>
    <TextBlock x:Name="PreparationText" Text="Automatic: find a matching saved backup." Margin="0,6,0,10" FontSize="12" Foreground="{StaticResource MutedBrush}"/>
    <WrapPanel>
     <Button x:Name="ChooseButton" Content="_Choose preparation..." IsEnabled="False"/>
     <Button x:Name="AutomaticButton" Content="_Automatic" IsEnabled="False"/>
    </WrapPanel>
    <TextBlock Text="Backups go in Documents unless you choose another location. Earlier locations are also checked. Keep the original backups." Foreground="{StaticResource MutedBrush}" FontSize="12" Margin="0,8,0,12"/>
    <Button x:Name="DefaultBackupsButton" Content="Use _Documents default" IsEnabled="False" HorizontalAlignment="Left" Margin="0,0,0,16"/>
    <TextBlock Text="Installation" FontWeight="SemiBold"/><TextBlock x:Name="InstallationPathText" Foreground="{StaticResource MutedBrush}" FontSize="12" Margin="0,4,0,0"/>
    <TextBlock x:Name="RuntimeText" Margin="0,4,0,12" FontSize="12" Foreground="{StaticResource MutedBrush}"/>
    <TextBlock x:Name="DetailsText" Margin="0,0,0,12" LineHeight="19"/>
    <WrapPanel><Button x:Name="CopyButton" Content="_Copy diagnostic details" IsEnabled="False"/><Button x:Name="ReportsButton" Content="Open saved _reports" IsEnabled="False"/></WrapPanel>
    <TextBlock Text="Copied details include file hashes and status, without local paths or source code." FontSize="12" Foreground="{StaticResource MutedBrush}" Margin="0,8,0,0"/>
   </StackPanel>
  </Expander>
  <TextBlock Text="File checks don't guarantee Blade isolation or peripheral compatibility." FontSize="11" Foreground="{StaticResource MutedBrush}" Margin="0,14,0,0"/>
 </StackPanel>
 </ScrollViewer>
</Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $markup
$window=[Windows.Markup.XamlReader]::Load($reader)
$controls=@{}
foreach($name in @('StateText','StatusDot','SummaryText','ActionHintText','InstallText','InstallationPathText','RuntimeText','BusyBar','NoticeText','DetailsText','PatchButton','RestoreButton','RefreshButton','OpenBackupsButton','ChangeBackupsButton','DefaultBackupsButton','BackupLocationText','PreparationText','RecoveryExpander','ChooseButton','AutomaticButton','CopyButton','ReportsButton')){$controls[$name]=$window.FindName($name)}
$script:desktopJob=$null;$script:desktopResult=$null;$script:selectedPreparation='';$script:lastOutcome='Inspection'

function Set-DesktopBusy([bool]$Busy) {
 $controls.BusyBar.Visibility=if($Busy){'Visible'}else{'Collapsed'}
 foreach($name in @('RefreshButton','ChooseButton','AutomaticButton','ReportsButton','ChangeBackupsButton','DefaultBackupsButton')){$controls[$name].IsEnabled=!$Busy}
 $controls.CopyButton.IsEnabled=!$Busy -and $null -ne $script:desktopResult
 $controls.PatchButton.IsEnabled=!$Busy -and $null -ne $script:desktopResult -and $script:desktopResult.CanPatch
 $controls.RestoreButton.IsEnabled=!$Busy -and $null -ne $script:desktopResult -and $script:desktopResult.CanRestore
 $controls.OpenBackupsButton.IsEnabled=!$Busy -and $null -ne $script:desktopResult -and [bool]$script:desktopResult.BackupRoot
}
function Show-DesktopState($Result) {
 $script:desktopResult=$Result.State;$script:lastOutcome=$Result.Outcome
 $presentation=Get-DesktopPresentation $Result.State
 $controls.StateText.Text=$presentation.Title
 $controls.SummaryText.Text=$presentation.Summary
 $controls.ActionHintText.Text=$presentation.Hint
 $controls.StatusDot.Fill=(New-Object Windows.Media.BrushConverter).ConvertFromString($presentation.Color)
 if($presentation.ExpandRecovery){$controls.RecoveryExpander.IsExpanded=$true;if($window.Height -lt 640){$window.Height=640}}
 $controls.InstallText.Text=if($Result.State.Installation){'AppEngine '+((Split-Path -Leaf $Result.State.Installation) -replace '^app-','')}else{'Installation unavailable'}
 $controls.InstallText.ToolTip=$Result.State.Installation
 $controls.InstallationPathText.Text=$Result.State.Installation
 $controls.RuntimeText.Text='Node.js: '+$Result.State.NodeVersion+'  |  Synapse/OpenBlade: '+$(if($Result.State.ControllersStopped){'stopped'}else{'running or unknown'})
 $controls.DetailsText.Text=$Result.State.Message
 $controls.NoticeText.Text=$Result.Notice
 $controls.PreparationText.Text=if($Result.State.PreparationDirectory){$Result.State.PreparationDirectory}else{'Automatic: find a matching saved backup.'}
 $backupLabel=$Result.State.BackupRoot
 try{if($backupLabel -eq (Get-DefaultBackupRoot)){$backupLabel='Documents\Synapse Blade Blocker\Backups'}}catch{}
 $controls.BackupLocationText.Text=if($backupLabel){$backupLabel}else{'Choose a backup location'}
 $controls.BackupLocationText.ToolTip=$Result.State.BackupRoot
 $controls.PatchButton.Style=$window.FindResource($(if($Result.State.CanRestore){[Windows.Controls.Button]}else{'PrimaryButtonStyle'}))
 $controls.RestoreButton.Style=$window.FindResource($(if($Result.State.CanRestore){'PrimaryButtonStyle'}else{[Windows.Controls.Button]}))
 Set-DesktopBusy $false
}
function Start-DesktopTask([string]$Action) {
 if($SmokeTest -and $Action -ne 'Refresh'){throw 'Smoke testing permits read-only refresh only.'}
 if($script:desktopJob){return}
 Set-DesktopBusy $true
 $controls.NoticeText.Text=switch($Action){'Patch'{'Preparing and checking files, then requesting administrator approval. Keep this window open.'};'Restore'{'Checking the original backup, then requesting administrator approval. Keep this window open.'};default{'Refreshing read-only status...'}}
 # Pin mutation to the installation shown when the user confirmed the action.
 $installation=if($Action -eq 'Refresh'){''}elseif($script:desktopResult){$script:desktopResult.Installation}else{''}
 if($Action -ne 'Refresh' -and !$installation){$controls.NoticeText.Text='Refresh to select an installation before continuing.';Set-DesktopBusy $false;return}
 $powershell=[PowerShell]::Create()
 [void]$powershell.AddScript({param($Root,$Action,$Preparation,$Installation) . (Join-Path $Root 'BladeBlocker.Desktop.ps1'); Invoke-DesktopTask -Action $Action -PreparationDirectory $Preparation -InstallDirectory $Installation}).AddArgument($PSScriptRoot).AddArgument($Action).AddArgument($script:selectedPreparation).AddArgument($installation)
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
$controls.OpenBackupsButton.Add_Click({
 try{
  $directory=Get-BackupRoot
  [void][IO.Directory]::CreateDirectory($directory)
  Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList (ConvertTo-DesktopArgument $directory) | Out-Null
 }catch{$controls.NoticeText.Text='Could not open the backups folder. Check the location shown in the window.'}
})
function Use-BackupLocation([string]$Directory) {
 try{Set-BackupRoot $Directory;$script:selectedPreparation='';Start-DesktopTask 'Refresh'}
 catch{$controls.NoticeText.Text='Could not save that backup location. Choose a writable folder. Existing backups were preserved.'}
}
$controls.ChangeBackupsButton.Add_Click({
 $dialog=New-Object System.Windows.Forms.FolderBrowserDialog
 $dialog.Description='Choose where to save new Synapse backups. Existing backups stay in their current folders.'
 $dialog.ShowNewFolderButton=$true
 if($script:desktopResult -and $script:desktopResult.BackupRoot -and (Test-Path -LiteralPath $script:desktopResult.BackupRoot -PathType Container)){$dialog.SelectedPath=$script:desktopResult.BackupRoot}
 try{if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){Use-BackupLocation $dialog.SelectedPath}}finally{$dialog.Dispose()}
})
$controls.DefaultBackupsButton.Add_Click({
 try{Use-BackupLocation (Get-DefaultBackupRoot)}catch{$controls.NoticeText.Text='The Windows Documents folder is unavailable. Choose another backup location.'}
})
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
 if($script:desktopResult -and $script:desktopResult.BackupRoot -and (Test-Path -LiteralPath $script:desktopResult.BackupRoot -PathType Container)){$dialog.SelectedPath=$script:desktopResult.BackupRoot}
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
