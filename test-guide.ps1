# Test run of a guide region on this PC before uploading to GitHub.
# Grabs one day of listings and reports which channels came back with programmes.
# Usage (PowerShell 7):
#   pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region uk
#   pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region na
#   pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region intl
#   pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region au
param(
  [Parameter(Mandatory)][ValidateSet('uk', 'na', 'intl', 'au')][string]$Region,
  [string]$EpgDir = "$env:USERPROFILE\epg",
  [int]$Days = 1
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

# Git and Node.js are often installed but missing from PATH; add their usual folders.
foreach ($dir in "$env:ProgramFiles\Git\cmd", "$env:ProgramFiles\nodejs", "$env:APPDATA\npm",
                 "$env:LOCALAPPDATA\Programs\Git\cmd", "${env:ProgramFiles(x86)}\Git\cmd") {
  if ($dir -and (Test-Path $dir) -and ($env:Path -split ';') -notcontains $dir) { $env:Path = "$dir;$env:Path" }
}

foreach ($tool in 'git', 'node', 'npm') {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    Write-Host "$tool is not installed. Install it with:" -ForegroundColor Red
    Write-Host "  winget install Git.Git"
    Write-Host "  winget install OpenJS.NodeJS.LTS"
    Write-Host "then close and reopen PowerShell and run this again."
    exit 1
  }
}

if (-not (Test-Path (Join-Path $EpgDir 'package.json'))) {
  Write-Host "Downloading the iptv-org guide collector to $EpgDir ..."
  git clone --depth 1 -b master https://github.com/iptv-org/epg.git $EpgDir
  if ($LASTEXITCODE) { throw 'git clone failed' }
}
Push-Location $EpgDir
try {
  if (-not (Test-Path 'node_modules')) {
    Write-Host "Installing the collector (a few minutes the first time)..."
    npm install
    if ($LASTEXITCODE) { throw 'npm install failed' }
  }

  $channelsFile = "$Region.channels.xml"
  & (Join-Path $here "make-$Region-channels.ps1") -EpgDir $EpgDir -Out $channelsFile

  $output = "$Region.xml"
  if (Test-Path $output) { Remove-Item $output }
  $started = Get-Date
  Write-Host "Collecting $Days day(s) of listings. This can take a while..."
  npm run grab --- --channels=$channelsFile --output=$output --days=$Days --maxConnections=5
  $minutes = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)

  if (-not (Test-Path $output) -or (Get-Item $output).Length -lt 100) {
    Write-Host "No guide file was produced. Send me the messages above." -ForegroundColor Red
    exit 1
  }

  $sourcesFile = Join-Path $EpgDir "$Region.sources.json"
  & (Join-Path $here 'finish-guide.ps1') -Guide (Join-Path $EpgDir $output) -Sources $(if (Test-Path $sourcesFile) { $sourcesFile } else { '' })
  [xml]$guide = Get-Content $output -Raw
  $firstStart = ($guide.tv.programme | Select-Object -First 1).start
  Write-Host "First programme starts: $firstStart"
  Write-Host ("Guide file: {0} ({1:N1} MB), took {2} minutes" -f (Join-Path $EpgDir $output), ((Get-Item $output).Length / 1MB), $minutes)
}
finally { Pop-Location }