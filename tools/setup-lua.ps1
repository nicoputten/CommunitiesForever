<#
.SYNOPSIS
  Installs a project-local Lua 5.1 + LuaRocks + busted + luacheck into .lua/ (gitignored).

.DESCRIPTION
  Prerequisites (one time):
    winget install -e --id Python.Python.3.12
    winget install -e --id BrechtSanders.WinLibs.POSIX.UCRT
  Then, from the repo root:
    powershell -ExecutionPolicy Bypass -File tools\setup-lua.ps1
  Use afterwards in a shell:
    $env:PATH = "$PWD\.lua\bin;$env:PATH"
    busted
    luacheck src tests
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$lua = Join-Path $root '.lua'

function Find-Tool([string]$name, [string]$fallbackGlob) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -notlike '*\WindowsApps\*' } | Select-Object -First 1
  if ($cmd) { return $cmd.Source }
  $hit = Get-ChildItem $fallbackGlob -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($hit) { return $hit.FullName }
  throw "$name not found. Install the prerequisites listed in this script's header."
}

$python = Find-Tool 'python' "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe"
$gcc = Find-Tool 'gcc' "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\BrechtSanders.WinLibs*\mingw64\bin\gcc.exe"
$env:PATH = "$(Split-Path -Parent $gcc);$env:PATH"

# hererocks runs LuaRocks' install.bat from its own folder; this setting would hide it.
Remove-Item Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue

& $python -m pip install --quiet --target (Join-Path $lua 'pytools') hererocks
if ($LASTEXITCODE -ne 0) { throw 'pip install hererocks failed' }

$env:PYTHONPATH = Join-Path $lua 'pytools'
& $python -W ignore -m hererocks $lua '--lua=5.1' '--luarocks=latest' '--target' 'mingw'
if ($LASTEXITCODE -ne 0) { throw 'hererocks failed' }

$env:PATH = "$(Join-Path $lua 'bin');$env:PATH"
# LuaRocks 3.8 misdetects the C runtime as MSVCR80 with UCRT MinGW; native rocks then fail to load.
& luarocks config --scope system variables.MSVCRT ucrt | Out-Null
foreach ($rock in @('busted', 'luacheck')) {
  & luarocks install $rock
  if ($LASTEXITCODE -ne 0) { throw "luarocks install $rock failed" }
}

Write-Host 'Done. In a shell: $env:PATH = "$PWD\.lua\bin;$env:PATH"; then busted / luacheck src tests'
