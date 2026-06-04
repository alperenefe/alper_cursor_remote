# Cursor Uzaktan — bkz. scripts/fast-phone.ps1 -Project cursor
param(
    [string]$Device = '',
    [string]$Connect = '',
    [switch]$SkipBuild,
    [switch]$Firebase,
    [switch]$Wireless,
    [switch]$FullApk,
    [string]$Notes = ''
)
$ws = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
& (Join-Path $ws 'scripts\fast-phone.ps1') -Project cursor @PSBoundParameters
