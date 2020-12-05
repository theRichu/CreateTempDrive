#Requires -Version 7

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [IO.DirectoryInfo] $path,
    [TimeSpan] $retentionPeriod = [TimeSpan]::FromDays(14),
    [DateTime] $now = [DateTime]::MinValue
)

if (!$PSBoundParameters.ContainsKey('WhatIf')) { $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference') }

if ($now -eq [DateTime]::MinValue) {

    $now = (Get-Date)
}

$oldFiles = Get-ChildItem $path -Recurse -File | Where-Object { $_.LastWriteTime -lt $now.Subtract($retentionPeriod) }
$folders = Get-ChildItem $path -Recurse -Directory 

$emptyFolders = $folders `
    | Where-Object { $null -eq (Get-ChildItem $_ -file -Recurse | Where-Object { $_.LastWriteTime -gt $now.Subtract($retentionPeriod) })} `
    | Sort-Object -Property @{ Expression={ $_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count }; Descending=$true }  

$oldFiles | Remove-Item -Force
$emptyFolders | Remove-Item -Force -Recurs