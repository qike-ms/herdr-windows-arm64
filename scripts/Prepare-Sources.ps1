#Requires -Version 7.0
param(
    [string]$WorkRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'work/src'),
    [string]$LocalSourceRoot
)
. "$PSScriptRoot/Common.ps1"
$WorkRoot = [IO.Path]::GetFullPath($WorkRoot)
$pins = Get-Content -LiteralPath (Join-Path $BundleRoot 'sources.json') -Raw | ConvertFrom-Json
foreach ($project in $pins.projects) {
    if (Test-Path -LiteralPath (Join-Path $WorkRoot $project.name)) {
        throw 'Destination already exists. Choose a new WorkRoot; existing source is never reset.'
    }
}
New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
foreach ($project in $pins.projects) {
    $root = Join-Path $WorkRoot $project.name
    $url = if ($LocalSourceRoot) { Join-Path $LocalSourceRoot $project.name } else { $project.url }
    Invoke-Checked git @('-c','core.autocrlf=false','clone','--no-checkout','--no-hardlinks',$url,$root)
    Invoke-Checked git @('-C',$root,'config','core.autocrlf','false')
    Invoke-Checked git @('-C',$root,'remote','set-url','origin',$project.url)
    Invoke-Checked git @('-C',$root,'checkout','--detach',$project.commit)
    $ghostty = Join-Path $root 'vendor/ghostty'
    if ($LocalSourceRoot) {
        Invoke-Checked git @('-c','core.autocrlf=false','clone','--no-checkout','--no-hardlinks',
            (Join-Path $LocalSourceRoot "$($project.name)/vendor/ghostty"),$ghostty)
        Invoke-Checked git @('-C',$ghostty,'remote','set-url','origin',$pins.ghosttyUrl)
        Invoke-Checked git @('-C',$ghostty,'checkout','--detach',$project.ghosttyCommit)
    } else {
        Invoke-Checked git @('-C',$root,'-c','core.autocrlf=false','submodule','update','--init','--depth','1')
    }
    Invoke-Checked git @('-C',$ghostty,'config','core.autocrlf','true')
    foreach ($pair in @(@($root,"$($project.name).patch"),@($ghostty,"$($project.name)-ghostty.patch"))) {
        $patch = Join-Path $BundleRoot "patches/$($pair[1])"
        # Git for Windows checks some un-attributed templates out as CRLF.
        # Match the original patch-generation conversion at apply time.
        Invoke-Checked git @('-C',$pair[0],'-c','core.autocrlf=true','apply','--check',$patch)
        Invoke-Checked git @('-C',$pair[0],'-c','core.autocrlf=true','apply',$patch)
    }
    foreach ($mapping in @(@('ghostty',$ghostty),@($project.name,$root))) {
        $overlay = Join-Path $BundleRoot "overlay/$($mapping[0])"
        if (!(Test-Path -LiteralPath $overlay)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $overlay -File -Recurse -Force) {
            $relative = [IO.Path]::GetRelativePath($overlay,$file.FullName)
            $dest = Join-Path $mapping[1] $relative
            New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $dest
        }
    }
}
Test-SourceTree $WorkRoot
