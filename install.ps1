# ============================================================================
#  EvilClaude - Windows installer (PowerShell)
#  Run:  irm https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/install.ps1 | iex
#  Or:   irm https://evilclaude.swampmine.in/install.ps1 | iex
# ============================================================================
$ErrorActionPreference = 'Stop'

# ---- CONFIG ----------------------------------------------------------------
$GithubUser   = 'swampmine'
$GithubRepo   = 'evilclaude-cli'
$GithubBranch = 'main'
$RemoteCliUrl = if ($env:EVILCLAUDE_REMOTE_URL) { $env:EVILCLAUDE_REMOTE_URL } else { "https://evilclaude.swampmine.in/cli.js" }
$FallbackCliUrl = "https://raw.githubusercontent.com/$GithubUser/$GithubRepo/$GithubBranch/cli.js"

$InstallDir = if ($env:EVILCLAUDE_INSTALL_DIR) { $env:EVILCLAUDE_INSTALL_DIR } else { "$env:USERPROFILE\.evilclaude\bin" }
$BinName    = 'evilclaude'

# ---- COLORS / UI -----------------------------------------------------------
function Step([string]$m) { Write-Host ">>> $m" -ForegroundColor Cyan }
function Ok  ([string]$m) { Write-Host "OK: $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "WARN: $m" -ForegroundColor Yellow }
function Die ([string]$m) { Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

function Banner {
  Clear-Host
  Write-Host ''
  Write-Host '   EvilClaude Installer' -ForegroundColor Magenta
  Write-Host '    The unleashed Claude Code routed through SwampMine' -ForegroundColor DarkGray
  Write-Host ''
}

function Spin {
  param([scriptblock]$Action, [string]$Msg)
  $job = Start-Job -ScriptBlock $Action
  while ($job.State -eq 'Running') {
    Write-Host -NoNewline ("`r[.] $Msg...   ") -ForegroundColor Magenta
    Start-Sleep -Milliseconds 200
  }
  Receive-Job $job -ErrorAction SilentlyContinue | Out-Null
  Remove-Job $job
  Write-Host ("`rOK: $Msg                         ") -ForegroundColor Green
}

# ---- BUN -------------------------------------------------------------------
function Ensure-Bun {
  if (Get-Command bun -ErrorAction SilentlyContinue) {
    Ok ("bun " + (bun --version) + " detected")
    return
  }
  Step 'bun not found - installing'
  Spin -Msg 'downloading and installing bun' -Action {
    powershell -NoProfile -Command "irm https://bun.sh/install.ps1 | iex" 2>&1 | Out-Null
  }
  $env:Path = "$env:USERPROFILE\.bun\bin;$env:Path"
  if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Die 'bun install failed - install manually from https://bun.sh'
  }
  Ok ("bun " + (bun --version) + " installed")
}

# ---- LOCAL OR REMOTE -------------------------------------------------------
function Resolve-Cli {
  if ($env:EVILCLAUDE_LOCAL_PATH -and (Test-Path $env:EVILCLAUDE_LOCAL_PATH)) {
    Ok "using local cli.js: $env:EVILCLAUDE_LOCAL_PATH"
    return @{ Path = $env:EVILCLAUDE_LOCAL_PATH; Kind = 'local' }
  }
  $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
  foreach ($c in @(
    (Join-Path $scriptDir 'cli.js'),
    (Join-Path (Get-Location) 'cli.js'),
    (Join-Path (Get-Location) 'public\cli.js')
  )) {
    if (Test-Path $c) {
      Ok "found local cli.js: $c"
      return @{ Path = $c; Kind = 'local' }
    }
  }
  Warn 'no local cli.js - will download from GitHub'
  return @{ Path = $RemoteCliUrl; Kind = 'remote' }
}

function Download-Remote {
  param([string]$Out)
  Step 'downloading cli.js'
  try {
    Invoke-WebRequest -Uri $RemoteCliUrl -OutFile $Out -UseBasicParsing
  } catch {
    Die ("download failed: " + $_.Exception.Message)
  }
  if ((Get-Item $Out).Length -lt 1024) { Die 'downloaded file is too small' }
  $head = Get-Content $Out -TotalCount 1
  if ($head -match '<html|<!DOCTYPE') { Remove-Item $Out; Die 'remote returned HTML — set $GithubUser' }
}

# ---- INSTALL ---------------------------------------------------------------
function Do-Install {
  param($src)
  Step "install dir: $InstallDir"
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  $cliTarget = Join-Path $InstallDir 'cli.js'
  $cmdShim   = Join-Path $InstallDir "$BinName.cmd"

  if ($src.Kind -eq 'local') {
    Step "copying cli.js → $cliTarget"
    Copy-Item -Force $src.Path $cliTarget
  } else {
    Download-Remote -Out $cliTarget
  }

  # Windows .cmd shim that invokes bun
  $shim = "@echo off`r`nbun ""$cliTarget"" %*`r`n"
  Set-Content -Path $cmdShim -Value $shim -Encoding ASCII
  $sz = [math]::Round((Get-Item $cliTarget).Length / 1MB, 1)
  Ok "installed $BinName ($sz MB) → $cmdShim"
}

# ---- PATH ------------------------------------------------------------------
function Check-Path {
  $userPath = [Environment]::GetEnvironmentVariable('Path','User')
  if ($userPath -split ';' -contains $InstallDir) {
    Ok "$InstallDir is on your PATH"
    return
  }
  Step "adding $InstallDir to your PATH (user scope)"
  $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  $env:Path = "$env:Path;$InstallDir"
  Ok 'PATH updated - open a new terminal for it to take effect'
}

# ---- DONE ------------------------------------------------------------------
function Done-Banner {
  Write-Host ''
  Write-Host '---------------------------------------------------------------' -ForegroundColor Magenta
  Write-Host '   EvilClaude is ready.' -ForegroundColor Magenta
  Write-Host '---------------------------------------------------------------' -ForegroundColor Magenta
  Write-Host ''
  Write-Host 'First, save your SwampMine API key:' -ForegroundColor White
  Write-Host '   evilclaude --swampmine-login' -ForegroundColor Cyan
  Write-Host ''
  Write-Host 'Then launch:' -ForegroundColor White
  Write-Host '   evilclaude' -ForegroundColor Cyan
  Write-Host ''
}

# ---- MAIN ------------------------------------------------------------------
Banner
Step "detected OS: Windows"
Ensure-Bun
$src = Resolve-Cli
Do-Install -src $src
Check-Path
Done-Banner
