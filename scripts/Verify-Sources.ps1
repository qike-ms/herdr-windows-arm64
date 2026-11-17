#Requires -Version 7.0
param([string]$WorkRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'work/src'))
. "$PSScriptRoot/Common.ps1"
Test-SourceTree ([IO.Path]::GetFullPath($WorkRoot))
