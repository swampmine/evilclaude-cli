# ============================================================================
#  EvilClaude Universal CLI Installer (Windows PowerShell)
# ============================================================================
$ErrorActionPreference = 'Stop'

$GatewayUrl   = if ($env:EVILCLAUDE_GATEWAY_URL) { $env:EVILCLAUDE_GATEWAY_URL } else { 'https://evilclaude.swampmine.in' }
$Version      = if ($env:EVILCLAUDE_VERSION) { $env:EVILCLAUDE_VERSION } else { '1.0.29' }
$RemoteCliUrl = if ($env:EVILCLAUDE_REMOTE_URL) { $env:EVILCLAUDE_REMOTE_URL } else { "$GatewayUrl/cli.js" }
$FallbackCliUrl = 'https://raw.githubusercontent.com/swampmine/evilclaude-cli/main/cli.js'

$InstallDir = if ($env:EVILCLAUDE_INSTALL_DIR) { $env:EVILCLAUDE_INSTALL_DIR } else { "$env:USERPROFILE\.evilclaude\bin" }
$ConfigDir  = "$env:USERPROFILE\.evilclaude"
$BinName    = 'evilclaude'

$DotFrames = @('⠋', '⠙', '⠸', '⠴', '⠦', '⠇')

function Spin-Step([string]$msg, [int]$cycles = 8, [int]$delayMs = 60) {
  for ($i = 0; $i -lt $cycles; $i++) {
    $f = $DotFrames[$i % $DotFrames.Count]
    Write-Host -NoNewline "`r$f $msg" -ForegroundColor Cyan
    Start-Sleep -Milliseconds $delayMs
  }
}

# 1. OS & Architecture Detection with 6-dot rotating loop & version {}
function Detect-Environment {
  Spin-Step 'Detecting operating system...' 8 60

  try {
    $liveVer = (Invoke-RestMethod -Uri "$GatewayUrl/version" -UseBasicParsing -TimeoutSec 2).Trim()
    if ($liveVer) { $script:Version = $liveVer }
  } catch {}

  $arch = if ([Environment]::Is64BitOperatingSystem) { 'x86_64' } else { 'x86' }
  Write-Host "`r✓ Detected OS: Windows ($arch) · Current Version: {v$Version}   " -ForegroundColor Green
}

# Runtime check
function Ensure-Runtime {
  if (Get-Command node -ErrorAction SilentlyContinue) {
    return 'node'
  }
  if (Get-Command bun -ErrorAction SilentlyContinue) {
    return 'bun'
  }

  Spin-Step 'Preparing runtime...' 6 60
  try {
    powershell -NoProfile -Command "irm https://bun.sh/install.ps1 | iex" 2>&1 | Out-Null
    $env:Path = "$env:USERPROFILE\.bun\bin;$env:Path"
    if (Get-Command bun -ErrorAction SilentlyContinue) {
      return 'bun'
    }
  } catch {}

  Write-Host 'error: Node.js (>= 18) or Bun is required to run EvilClaude CLI.' -ForegroundColor Red
  exit 1
}

# Progress bar renderer
function Render-Bar([long]$cur, [long]$tot) {
  $pct = 0
  if ($tot -gt 0) {
    $pct = [math]::Min(100, [int]($cur * 100 / $tot))
  }
  $width = 28
  $filled = [int]($pct * $width / 100)
  $empty = $width - $filled
  $bar = ('█' * $filled) + ('░' * $empty)

  $curMb = [math]::Round($cur / 1MB, 1)
  $totMb = [math]::Round($tot / 1MB, 1)

  Write-Host -NoNewline ("`rDownloading [$bar] {0,3}% ({1}MB/{2}MB)" -f $pct, $curMb, $totMb) -ForegroundColor Cyan
}

# 2. Download with % progress bar
function Download-Cli([string]$TargetJs) {
  $tot = 21036000
  $downloaded = $false

  try {
    # Fast simulated progress
    for ($p = 20; $p -le 100; $p += 20) {
      Render-Bar ($tot * $p / 100) $tot
      Start-Sleep -Milliseconds 60
    }
    Invoke-WebRequest -Uri $RemoteCliUrl -OutFile $TargetJs -UseBasicParsing -TimeoutSec 20
    if ((Get-Item $TargetJs).Length -gt 1024) { $downloaded = $true }
  } catch {}

  if (-not $downloaded) {
    try {
      Invoke-WebRequest -Uri $FallbackCliUrl -OutFile $TargetJs -UseBasicParsing -TimeoutSec 25
      if ((Get-Item $TargetJs).Length -gt 1024) { $downloaded = $true }
    } catch {}
  }

  if (-not $downloaded) {
    Write-Host "`nerror: Download failed. Please check internet connection." -ForegroundColor Red
    exit 1
  }

  $finalMb = [math]::Round((Get-Item $TargetJs).Length / 1MB, 1)
  Write-Host "`n✓ Downloaded EvilClaude v$Version ($finalMb MB)" -ForegroundColor Green
}

# 3. Doing setup with 6-dot braille spinner
function Do-Setup([string]$runtime, [string]$cliJs) {
  Spin-Step 'Doing setup...' 10 70

  # Command shims
  $cmdShim = Join-Path $InstallDir "$BinName.cmd"
  $ps1Shim = Join-Path $InstallDir "$BinName.ps1"

  $cmdContent = "@echo off`r`n$runtime ""$cliJs"" %*`r`n"
  Set-Content -Path $cmdShim -Value $cmdContent -Encoding ASCII

  $ps1Content = "& $runtime `"$cliJs`" `$args`r`n"
  Set-Content -Path $ps1Shim -Value $ps1Content -Encoding ASCII

  # User PATH
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($userPath -split ';' -notcontains $InstallDir) {
    $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    $env:Path = "$env:Path;$InstallDir"
  }

  # Authorization
  New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
  $keyFile = Join-Path $ConfigDir 'api_key'
  if (-not (Test-Path $keyFile) -or (Get-Item $keyFile).Length -eq 0) {
    try {
      $resp = Invoke-RestMethod -Uri "$GatewayUrl/api/v1/terminal/provision" -Method Post -ContentType 'application/json' -Body '{"platform":"windows"}' -TimeoutSec 4
      if ($resp.api_key) {
        Set-Content -Path $keyFile -Value $resp.api_key.Trim() -Encoding ASCII
      }
    } catch {
      Set-Content -Path $keyFile -Value "ec_offline_$env:COMPUTERNAME" -Encoding ASCII
    }
  }

  Write-Host "`r✓ Doing setup... complete              " -ForegroundColor Green
}

# 4. Done
function Show-Done {
  Write-Host '✓ Done' -ForegroundColor Green
}

# 5. Colorful finish
function Show-Colorful-Finish {
  Write-Host ''
  Write-Host 'You can run ' -NoNewline
  Write-Host 'EvilClaude' -ForegroundColor Magenta -NoNewline
  Write-Host ' with:'
  Write-Host '  evilclaude' -ForegroundColor Cyan
  Write-Host ''
}

Detect-Environment
$rt = Ensure-Runtime

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$cliPath = Join-Path $InstallDir 'cli.js'

Download-Cli $cliPath
Do-Setup $rt $cliPath
Show-Done
Show-Colorful-Finish
