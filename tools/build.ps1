<#
.SYNOPSIS
  Builds an installable copy of the addon in dist/ for manual testing in game.

.DESCRIPTION
  1. Fetches Libs/ via fetch-libs.ps1 (skips libs that already exist).
  2. Deletes dist/, then stages dist/CommunitiesForever with the addon files only.
  3. Stamps the version 0.1.<commit count> into the TOC (with "-dirty" if the
     working tree has uncommitted changes). Release builds get their version
     from the git tag via the packager instead (CF-02).
  4. Zips it to dist/CommunitiesForever-<version>.zip.
  Copy dist/CommunitiesForever into your WoW Interface/AddOns folder, or pass -AddOnsPath.

.PARAMETER RefreshLibs
  Re-download all libraries.

.PARAMETER AddOnsPath
  Optional Interface\AddOns folder; its CommunitiesForever folder is replaced with the build.
#>
param(
  [switch]$RefreshLibs,
  [string]$AddOnsPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$addonName = 'CommunitiesForever'

& (Join-Path $PSScriptRoot 'fetch-libs.ps1') -Force:$RefreshLibs

$count = (& git -C $root rev-list --count HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'git rev-list failed' }
$version = "0.1.$count"
if (& git -C $root status --porcelain) { $version += '-dirty' }

# Always start from an empty dist/ so old builds and zips never linger.
$dist = Join-Path $root 'dist'
if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
$stage = Join-Path $dist $addonName
New-Item -ItemType Directory -Force $stage | Out-Null

# Keep in sync with what .pkgmeta packages (everything tracked minus "ignore:").
foreach ($item in @('embeds.xml', 'Bindings.xml', 'LICENSE', 'CHANGELOG.md', 'src', 'Data', 'media', 'Libs')) {
  Copy-Item -Recurse (Join-Path $root $item) $stage
}

$toc = Get-Content -Raw (Join-Path $root "$addonName.toc")
$toc = $toc.Replace('@project-version@', $version)
[IO.File]::WriteAllText((Join-Path $stage "$addonName.toc"), $toc)

$zip = Join-Path $dist "$addonName-$version.zip"
# Windows tar (bsdtar) writes zip entries with forward slashes; Compress-Archive in Windows PowerShell 5.1
# writes backslashes, which other unzip tools (and possibly the CurseForge app) extract as flat file names.
& "$env:SystemRoot\System32\tar.exe" -a -c -f $zip -C $dist $addonName
if ($LASTEXITCODE -ne 0) { throw 'zip failed' }

Write-Host "Built $addonName $version"
Write-Host "  folder: $stage"
Write-Host "  zip:    $zip"

if ($AddOnsPath) {
  if (-not (Test-Path $AddOnsPath)) { throw "AddOns folder not found: $AddOnsPath" }
  $target = Join-Path $AddOnsPath $addonName
  if (Test-Path $target) { Remove-Item -Recurse -Force $target }
  Copy-Item -Recurse $stage $target
  Write-Host "  installed: $target"
}
