#Requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$ConPtyPackage,
    [string]$WorkRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'work/src'),
    [string]$OutRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'dist')
)
. "$PSScriptRoot/Common.ps1"
$WorkRoot = [IO.Path]::GetFullPath($WorkRoot)
$OutRoot = [IO.Path]::GetFullPath($OutRoot)
Test-SourceTree $WorkRoot
if (Test-Path -LiteralPath $OutRoot) { throw 'Choose a new OutRoot; staging never replaces existing files' }
if ((Get-FileHash -LiteralPath $ConPtyPackage -Algorithm SHA256).Hash.ToLowerInvariant() -ne
    '9382ad7becb7e4d84e300578d8e4f4df28f43d979d9055d978c42913c47e0e9d') { throw 'ConPTY archive hash mismatch' }
New-Item -ItemType Directory -Path "$OutRoot/app","$OutRoot/core/conpty/arm64" -Force | Out-Null
foreach ($project in @('herdr-app','herdr-core')) {
    $part = if ($project -eq 'herdr-app') { 'app' } else { 'core' }
    $src = Join-Path $WorkRoot $project
    Copy-Item -LiteralPath "$src/target/aarch64-pc-windows-msvc/release/$project.exe" -Destination "$OutRoot/$part/"
    Copy-Item -LiteralPath "$src/LICENSE" -Destination "$OutRoot/$part/LICENSE"
    Assert-NativeArm64 "$OutRoot/$part/$project.exe"
}
Copy-Item -LiteralPath "$OutRoot/core/herdr-core.exe" -Destination "$OutRoot/core/hc.exe"
Copy-Item -LiteralPath "$WorkRoot/herdr-app/THIRD-PARTY-NOTICES" -Destination "$OutRoot/app/"
Copy-Item -LiteralPath "$WorkRoot/herdr-core/crates/herdr-core/THIRD-PARTY-NOTICES" -Destination "$OutRoot/core/"
Copy-Item -LiteralPath "$WorkRoot/herdr-app/assets/icons/herdr-ui-icon-clean.svg" -Destination "$OutRoot/app/herdr-app.svg"
foreach ($notice in @('Microsoft.Windows.Console.ConPTY-LICENSE.txt','Microsoft.Windows.Console.ConPTY-NOTICE.md')) {
    Copy-Item -LiteralPath (Join-Path $BundleRoot "licenses/$notice") -Destination "$OutRoot/core/"
}
$archive = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($ConPtyPackage))
try {
    foreach ($entry in @(
        @('runtimes/win-arm64/native/conpty.dll','core/conpty/conpty.dll','db3d173640b172bafd42d5b541b638a9aeec1c7d0e40dd636bf02822a32c912c'),
        @('build/native/runtimes/arm64/OpenConsole.exe','core/conpty/arm64/OpenConsole.exe','ed7622fd0d3bedc9ab9f122f5e58edf0def9e7999224f52dd395ba9f54edbe09')
    )) {
        $zipEntry = $archive.GetEntry($entry[0])
        if (!$zipEntry) { throw "Missing ConPTY entry: $($entry[0])" }
        $dest = Join-Path $OutRoot $entry[1]
        [IO.Compression.ZipFileExtensions]::ExtractToFile($zipEntry,$dest,$false)
        if ($entry[2]) {
            if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry[2]) { throw 'ConPTY member hash mismatch' }
            Assert-NativeArm64 $dest
            if ((Get-AuthenticodeSignature -LiteralPath $dest).Status -ne 'Valid') { throw 'ConPTY signature is not valid' }
        }
    }
} finally { $archive.Dispose() }
$files = @(Get-ChildItem -LiteralPath $OutRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath($OutRoot,$_.FullName).Replace('\','/');bytes=$_.Length;
        sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
})
@{architecture='aarch64-pc-windows-msvc';files=$files} | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath "$OutRoot/manifest.json" -Encoding utf8NoBOM
Write-Output "Staged $($files.Count) native ARM64 files. No user settings or installed programs changed."
