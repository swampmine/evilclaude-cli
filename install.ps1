# ============================================================================
#  EvilClaude CLI Installer (Windows PowerShell)
# ============================================================================
$ErrorActionPreference = 'Stop'

$Version = if ($env:EVILCLAUDE_VERSION) { $env:EVILCLAUDE_VERSION } else { '1.0.26' }
$GatewayUrl = if ($env:EVILCLAUDE_GATEWAY_URL) { $env:EVILCLAUDE_GATEWAY_URL } else { 'https://evilclaude.swampmine.in' }
$RemoteCliUrl = if ($env:EVILCLAUDE_REMOTE_URL) { $env:EVILCLAUDE_REMOTE_URL } else { "$GatewayUrl/cli.js" }
$FallbackCliUrl = 'https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/cli.js'

$InstallDir = if ($env:EVILCLAUDE_INSTALL_DIR) { $env:EVILCLAUDE_INSTALL_DIR } else { "$env:USERPROFILE\.evilclaude\bin" }
$ConfigDir  = "$env:USERPROFILE\.evilclaude"
$BinName    = 'evilclaude'

function Info($m)    { Write-Host "info: $m" -ForegroundColor DarkGray }
function Success($m) { Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m)    { Write-Host "warn: $m" -ForegroundColor Yellow }
function Die($m)     { Write-Host "error: $m" -ForegroundColor Red; exit 1 }

# Runtime resolution
function Ensure-Runtime {
  if (Get-Command node -ErrorAction SilentlyContinue) {
    return 'node'
  }
  if (Get-Command bun -ErrorAction SilentlyContinue) {
    return 'bun'
  }

  Info 'fetching runtime (bun)...'
  try {
    powershell -NoProfile -Command "irm https://bun.sh/install.ps1 | iex" 2>&1 | Out-Null
    $env:Path = "$env:USERPROFILE\.bun\bin;$env:Path"
    if (Get-Command bun -ErrorAction SilentlyContinue) {
      return 'bun'
    }
  } catch {}

  Die 'Node.js (>= 18) or Bun is required to run EvilClaude CLI.'
}

# Download CLI bundle
function Download-Cli($TargetJs) {
  Info "downloading evilclaude v$Version (windows-x64)..."
  $downloaded = $false

  try {
    Invoke-WebRequest -Uri $RemoteCliUrl -OutFile $TargetJs -UseBasicParsing -TimeoutSec 15
    if ((Get-Item $TargetJs).Length -gt 1024) { $downloaded = $true }
  } catch {}

  if (-not $downloaded) {
    Info 'connecting to GitHub mirror...'
    try {
      Invoke-WebRequest -Uri $FallbackCliUrl -OutFile $TargetJs -UseBasicParsing -TimeoutSec 20
      if ((Get-Item $TargetJs).Length -gt 1024) { $downloaded = $true }
    } catch {}
  }

  if (-not $downloaded) {
    Die 'failed to download EvilClaude CLI from all endpoints. Please check internet connectivity.'
  }
}

# Auto-configure user PATH
function Configure-Path {
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($userPath -split ';' -contains $InstallDir) {
    return
  }
  $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  $env:Path = "$env:Path;$InstallDir"
  Info "added $InstallDir to user PATH"
}

# Zero-code authorization setup
function Setup-Authorization {
  New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
  $keyFile = Join-Path $ConfigDir 'api_key'
  if (Test-Path $keyFile) {
    if ((Get-Item $keyFile).Length -gt 0) { return }
  }

  try {
    $resp = Invoke-RestMethod -Uri "$GatewayUrl/api/v1/terminal/provision" -Method Post -ContentType 'application/json' -Body '{"platform":"windows"}' -TimeoutSec 4
    if ($resp.api_key) {
      Set-Content -Path $keyFile -Value $resp.api_key.Trim() -Encoding ASCII
      return
    }
  } catch {}

  Set-Content -Path $keyFile -Value "ec_offline_$env:COMPUTERNAME" -Encoding ASCII
}

# Main flow
$runtime = Ensure-Runtime
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$cliJs   = Join-Path $InstallDir 'cli.js'
$cmdShim = Join-Path $InstallDir "$BinName.cmd"
$ps1Shim = Join-Path $InstallDir "$BinName.ps1"

Download-Cli $cliJs

# Create command shims
$cmdContent = "@echo off`r`n$runtime ""$cliJs"" %*`r`n"
Set-Content -Path $cmdShim -Value $cmdContent -Encoding ASCII

$ps1Content = "& $runtime `"$cliJs`" `$args`r`n"
Set-Content -Path $ps1Shim -Value $ps1Content -Encoding ASCII

Configure-Path
Setup-Authorization

Write-Host ''
Write-Host 'EvilClaude was installed successfully!' -ForegroundColor Green
Write-Host ''
Write-Host 'To get started, run:'
Write-Host "  $BinName" -ForegroundColor Cyan
Write-Host ''
