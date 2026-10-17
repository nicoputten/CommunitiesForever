<#
.SYNOPSIS
  Fetches the .pkgmeta externals into Libs/ (what the BigWigs packager does on release).

.DESCRIPTION
  Supports the two external kinds used in .pkgmeta:
    - git URLs (GitHub), optionally pinned with "tag:"; cloned shallow, .git removed
    - WowAce/CurseForge SVN URLs; downloaded over plain HTTP, so no svn client is needed
  Afterwards checks that every file referenced by embeds.xml exists.
  Works on Windows PowerShell 5.1 and PowerShell 7 (CI).

.PARAMETER Force
  Re-download externals that already exist.
#>
param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($PSVersionTable.PSVersion.Major -lt 6) {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$root = Split-Path -Parent $PSScriptRoot

function Read-Externals([string]$pkgmetaPath) {
  $externals = @()
  $inExternals = $false
  $current = $null
  foreach ($line in Get-Content $pkgmetaPath) {
    if ($line -match '^\S') {
      $inExternals = $line -match '^externals:\s*$'
      continue
    }
    if (-not $inExternals -or $line -match '^\s*(#|$)') { continue }

    if ($line -match '^  (\S+):\s*(\S*)\s*$') {
      $current = @{ Path = $Matches[1]; Url = $Matches[2]; Tag = $null }
      $externals += $current
    } elseif ($line -match '^    (url|tag):\s*(\S+)\s*$' -and $current) {
      if ($Matches[1] -eq 'url') { $current.Url = $Matches[2] } else { $current.Tag = $Matches[2] }
    } else {
      throw "Unsupported .pkgmeta externals line: '$line'"
    }
  }
  return $externals
}

function Get-Git([hashtable]$ext, [string]$dest) {
  $gitArgs = @('-c', 'advice.detachedHead=false', 'clone', '--quiet', '--depth', '1')
  if ($ext.Tag) { $gitArgs += @('--branch', $ext.Tag) }
  $gitArgs += @($ext.Url, $dest)
  & git @gitArgs
  if ($LASTEXITCODE -ne 0) { throw "git clone failed for $($ext.Url)" }
  Remove-Item -Recurse -Force (Join-Path $dest '.git')
  Remove-Ignored $dest
}

# Like the packager: drop paths listed under "ignore:" in the external's own .pkgmeta.
function Remove-Ignored([string]$dest) {
  $pkgmeta = Join-Path $dest '.pkgmeta'
  if (-not (Test-Path $pkgmeta)) { return }
  $inIgnore = $false
  foreach ($line in Get-Content $pkgmeta) {
    if ($line -match '^\S') { $inIgnore = $line -match '^ignore:\s*$'; continue }
    if ($inIgnore -and $line -match '^\s+-\s*(\S+)\s*$') {
      Remove-Item -Recurse -Force (Join-Path $dest $Matches[1]) -ErrorAction SilentlyContinue
    }
  }
}

# mod_dav_svn serves an HTML index per directory: <li><a href="name">name</a></li>
function Get-Svn([string]$url, [string]$dest) {
  if (-not $url.EndsWith('/')) { $url += '/' }
  New-Item -ItemType Directory -Force $dest | Out-Null
  $index = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content
  foreach ($m in [regex]::Matches($index, '<li><a href="([^"]+)">')) {
    $name = $m.Groups[1].Value
    if ($name -eq '../') { continue }
    $target = Join-Path $dest ([Uri]::UnescapeDataString($name.TrimEnd('/')))
    if ($name.EndsWith('/')) {
      Get-Svn ($url + $name) $target
    } else {
      Invoke-WebRequest -UseBasicParsing -Uri ($url + $name) -OutFile $target
    }
  }
}

function Test-Embeds([string]$embedsPath) {
  $missing = @()
  $base = Split-Path -Parent $embedsPath
  foreach ($m in [regex]::Matches((Get-Content -Raw $embedsPath), 'file="([^"]+)"')) {
    $file = Join-Path $base ($m.Groups[1].Value -replace '\\', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path $file)) { $missing += $m.Groups[1].Value }
  }
  if ($missing.Count -gt 0) {
    throw "embeds.xml references missing files:`n  " + ($missing -join "`n  ")
  }
}

foreach ($ext in Read-Externals (Join-Path $root '.pkgmeta')) {
  $dest = Join-Path $root $ext.Path
  if ((Test-Path $dest) -and -not $Force) {
    Write-Host "skip   $($ext.Path) (exists, use -Force to refresh)"
    continue
  }
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }

  Write-Host "fetch  $($ext.Path) <- $($ext.Url)$(if ($ext.Tag) { " @ $($ext.Tag)" })"
  if ($ext.Url -match '^https://github\.com/') {
    Get-Git $ext $dest
  } elseif ($ext.Url -match '^https://repos\.(wowace|curseforge)\.com/') {
    if ($ext.Tag) { throw "SVN externals are not pinned by tag here; put the tag in the URL ($($ext.Path))" }
    Get-Svn $ext.Url $dest
  } else {
    throw "Unsupported external URL: $($ext.Url)"
  }
}

Test-Embeds (Join-Path $root 'embeds.xml')
Write-Host 'Libs OK: all embeds.xml files present.'
