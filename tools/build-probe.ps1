<#
.SYNOPSIS
  Builds dist/FriendProbe.zip, the launch checklist addon to share with friends (CF-60).

.DESCRIPTION
  Stages tools/FriendProbe as dist/FriendProbe (the folder name the game needs) and zips it to
  dist/FriendProbe.zip. Friends unzip it into Interface\AddOns, play as usual (it runs by itself until
  2026-11-18, silently) and send WTF\Account\<account>\SavedVariables\FriendProbe.lua back.
  Leaves dist/CommunitiesForever (from build.ps1) alone.

.PARAMETER AddOnsPath
  Optional Interface\AddOns folder; its FriendProbe folder is replaced with the build.
#>
param(
  [string]$AddOnsPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'tools\FriendProbe'
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'FriendProbe'
$zip = Join-Path $dist 'FriendProbe.zip'

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
if (Test-Path $zip) { Remove-Item -Force $zip }
New-Item -ItemType Directory -Force $stage | Out-Null
Get-ChildItem $source -File | Where-Object { $_.Extension -in '.toc', '.lua' } | Copy-Item -Destination $stage

Compress-Archive -Path $stage -DestinationPath $zip
Write-Host "Built $zip"

if ($AddOnsPath) {
  $target = Join-Path $AddOnsPath 'FriendProbe'
  if (Test-Path $target) { Remove-Item -Recurse -Force $target }
  Copy-Item -Recurse $stage $target
  Write-Host "Copied to $target"
}
