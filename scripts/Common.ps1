$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$BundleRoot = Split-Path $PSScriptRoot -Parent

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

function Assert-NativeArm64([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5a4d) { throw 'Missing DOS signature' }
        $stream.Position = 0x3c
        $stream.Position = $reader.ReadInt32()
        if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0xaa64) {
            throw "Not a native ARM64 PE file: $Path"
        }
    } finally { $reader.Dispose() }
}

function Get-LfHash([string]$Path) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}

function Test-SourceTree([string]$WorkRoot) {
    $pins = Get-Content -LiteralPath (Join-Path $BundleRoot 'sources.json') -Raw | ConvertFrom-Json
    foreach ($project in $pins.projects) {
        $root = Join-Path $WorkRoot $project.name
        $head = & git -C $root rev-parse HEAD
        if ($LASTEXITCODE -or $head -ne $project.commit) { throw "Wrong source revision: $($project.name)" }
        $head = & git -C (Join-Path $root 'vendor/ghostty') rev-parse HEAD
        if ($LASTEXITCODE -or $head -ne $project.ghosttyCommit) { throw "Wrong Ghostty revision: $($project.name)" }
    }
    $manifest = Get-Content -LiteralPath (Join-Path $BundleRoot 'source-manifest.json') -Raw | ConvertFrom-Json
    foreach ($entry in $manifest) {
        $path = Join-Path (Join-Path $WorkRoot $entry.project) $entry.path
        if ((Get-LfHash $path) -ne $entry.sha256Lf) { throw "Source mismatch: $($entry.project)/$($entry.path)" }
    }
    $preserved = @($manifest | ForEach-Object { "$($_.project)/$($_.path)" })
    foreach ($project in $pins.projects) {
        $root = Join-Path $WorkRoot $project.name
        $changed = @(& git -C $root diff HEAD --name-only --ignore-submodules=all)
        if ($LASTEXITCODE) { throw 'Cannot inspect source changes' }
        $changed += @(& git -C $root ls-files --others --exclude-standard)
        if ($LASTEXITCODE) { throw 'Cannot inspect new source files' }
        $ghostty = Join-Path $root 'vendor/ghostty'
        $nested = @(& git -C $ghostty diff HEAD --name-only)
        if ($LASTEXITCODE) { throw 'Cannot inspect Ghostty changes' }
        $nested += @(& git -C $ghostty ls-files --others --exclude-standard)
        if ($LASTEXITCODE) { throw 'Cannot inspect new Ghostty files' }
        $changed += @($nested | ForEach-Object { "vendor/ghostty/$_" })
        foreach ($path in $changed) {
            if ("$($project.name)/$path" -notin $preserved) { throw "Unrecorded source change: $($project.name)/$path" }
        }
    }
    Write-Output "Verified $($manifest.Count) preserved source files and lockfiles."
}
