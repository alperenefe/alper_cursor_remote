# Eski ad — fast-phone.ps1
param(
    [string]$Device = '',
    [string]$Connect = '',
    [switch]$SkipBuild,
    [switch]$Firebase,
    [switch]$FullApk,
    [string]$Notes = ''
)
& (Join-Path $PSScriptRoot 'fast-phone.ps1') @PSBoundParameters
