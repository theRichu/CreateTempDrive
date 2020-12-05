using namespace System.Security.Principal

param(
    [IO.DirectoryInfo] $tempFolder = ([IO.DirectoryInfo]"c:\Temp\TempDrive"),
    [char] $driveLetter = 'T',
    [TimeSpan] $retentionPeriod = [TimeSpan]::FromDays(14),
    [switch] $elevatedForTaskScheduler
)

$isElevated = ([WindowsPrincipal][WindowsIdentity]::GetCurrent()).IsInRole([WindowsBuiltInRole]::Administrator)

if ($isElevated -and !$elevatedForTaskScheduler) {
    Write-Host "Please start script non elevated" -ForegroundColor Red
    Exit

    # http://www.powershellmagazine.com/2015/04/08/user-account-control-and-admin-approval-mode-the-impact-on-powershell/
}

if (!$elevatedForTaskScheduler) 
{
    if (!(Test-Path $tempFolder))
    {
        New-Item -ItemType Directory -Path $tempFolder -Force > $null
    }

    if (!(Test-Path "$($driveLetter):")) 
    {
        $uncTempFolderPath = Join-Path \\localhost ($tempFolder -replace ':', '$').TrimEnd('\')  

        New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $uncTempFolderPath -Persist -Scope Global

        $createDrivecmd = "New-PSDrive -Name $($driveLetter) -PSProvider FileSystem -Root $($uncTempFolderPath) -Persist -Scope Global -ea SilentlyContinue"

        New-Item -ItemType File -Force `
            -Path ("{0}\CreateTempDrive_$($driveLetter).bat" -f [Environment]::GetFolderPath("startup")) `
            -Value "powershell.exe -NoProfile -WindowStyle Hidden -Command `"$($createDrivecmd)`"" > $null
    }

    $psExecutable = if (Test-Path("pwsh.exe")) { "pwsh.exe" } else { "PowerShell.exe" }  

    $proc = [Diagnostics.ProcessStartInfo]::new($psExecutable)
    $proc.Verb = "runas"
    $proc.Arguments = " -NoProfile -WindowStyle Hidden $($MyInvocation.MyCommand.Definition) $tempFolder $driveLetter $retentionPeriod -elevatedForTaskScheduler" 
    [Diagnostics.Process]::Start($proc)
}

if ($elevatedForTaskScheduler) 
{
    $taskName = "TempDrive_$($driveLetter)_ClearFilesExceedingRetentionPeriod"
    $taskDescription = "Remove files in TempDrive older than a certain period"
    $scriptFilePath = Get-Item (Join-Path $PSScriptRoot PurgeOldFiles.ps1)

    $action = New-ScheduledTaskAction -Execute Powershell.exe `
        -Argument (' -NoProfile -WindowStyle Hidden -File {0} -path {1} -retentionPeriod {2}' `
        -f $scriptFilePath, $tempFolder, $retentionPeriod) 

    $trigger = New-ScheduledTaskTrigger -Daily -At 11am

    if ((Get-ScheduledTask $taskName -ea SilentlyContinue)) 
    {
        Unregister-ScheduledTask $taskName -Confirm:$False
    }

    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description $taskDescription
}