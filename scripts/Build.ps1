#Requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$ToolchainConfig,
    [string]$WorkRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'work/src'),
    [switch]$Offline
)
. "$PSScriptRoot/Common.ps1"
$WorkRoot = [IO.Path]::GetFullPath($WorkRoot)
Test-SourceTree $WorkRoot
$config = Get-Content -LiteralPath $ToolchainConfig -Raw | ConvertFrom-Json -AsHashtable
. "$PSScriptRoot/Set-NativeEnvironment.ps1" @config
$argsList = @('build','--release','--locked','--target','aarch64-pc-windows-msvc')
if ($Offline) { $argsList += '--offline' }
foreach ($project in @('herdr-core','herdr-app')) {
    Push-Location (Join-Path $WorkRoot $project)
    try { Invoke-Checked "$RustRoot/bin/cargo.exe" $argsList } finally { Pop-Location }
    Assert-NativeArm64 (Join-Path $WorkRoot "$project/target/aarch64-pc-windows-msvc/release/$project.exe")
}
Test-SourceTree $WorkRoot
