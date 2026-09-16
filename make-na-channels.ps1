# Builds custom.channels.xml for the iptv-org EPG grabber with US and Canadian channels
# that Luma's provider carries (premium movies, entertainment, news and sports).
# Usage (PowerShell 7):  pwsh -ExecutionPolicy Bypass -File make-na-channels.ps1
param([string]$EpgDir = "$env:USERPROFILE\epg", [string]$Out = 'na.channels.xml')

$ErrorActionPreference = 'Stop'
Set-Location $EpgDir
Write-Host "Downloading iptv-org channel and guide lists (about a minute)..."
$channels = Invoke-RestMethod "https://iptv-org.github.io/api/channels.json"
$guides   = Invoke-RestMethod "https://iptv-org.github.io/api/guides.json"

# Channel names to include. Add words here if a US/Canada channel is still missing listings.
$want = '(?i)\b(starz|showtime|sony movies|hbo|cinemax|the movie channel|mgm\+?|paramount network|amc|fxx?|tnt|tbs|usa network|comedy central|the cw|cw|abc|cbs|nbc|fox|discovery|destination america|e!|food network|hgtv|tlc|history|a&e|lifetime|bravo|syfy|national geographic|nat geo|cnn|msnbc|fox news|cnbc|espn\w*|fox sports \d|fs1|fs2|nfl network|nba tv|mlb network|nhl network|golf channel|tennis channel|bein sports?|tsn\d?|sportsnet|ctv|global|citytv|crave|super channel|w network|investigation discovery|oxygen|animal planet|travel channel|cartoon network|nickelodeon|disney)\b'

# Guide websites, best first (English listings only). Up to three are collected per channel and
# finish-guide.ps1 keeps the one with the most listings. (tvtv.us returned errors in testing, so it is last.)
$sites = @('tvpassport.com', 'tvguide.com', 'ontvtonight.com', 'tvtv.us')
$maxSources = 3
$bySite = @{}
foreach ($g in $guides) {
  if (-not $g.channel -or -not $g.site_id -or $g.site -notin $sites -or $g.lang -ne 'en') { continue }
  $key = [string]$g.channel
  if (-not $bySite.ContainsKey($key)) { $bySite[$key] = [Collections.Generic.List[object]]::new() }
  $bySite[$key].Add($g)
}

$lines = [Collections.Generic.List[string]]::new()
$candidates = [ordered]@{}
foreach ($c in $channels) {
  if ($c.country -notin 'US', 'CA' -or $c.closed -or $c.name -notmatch $want) { continue }
  if (-not $c.id -or -not $bySite.ContainsKey([string]$c.id)) { continue }
  $id = [string]$c.id
  if ($candidates.Contains($id)) { continue }
  $picked = [Collections.Generic.List[object]]::new()
  $taken = @{}
  foreach ($g in ($bySite[$id] | Sort-Object -Stable { $sites.IndexOf($_.site) })) {
    if ($taken.ContainsKey($g.site)) { continue }
    $taken[$g.site] = $true
    $sid = if ($picked.Count -eq 0) { $id } else { "$id~$($picked.Count + 1)" }
    $lines.Add(('  <channel site="{0}" lang="en" xmltv_id="{1}" site_id="{2}">{3}</channel>' -f $g.site,
      [Security.SecurityElement]::Escape($sid), [Security.SecurityElement]::Escape([string]$g.site_id),
      [Security.SecurityElement]::Escape($c.name)))
    $picked.Add([pscustomobject]@{ id = $sid; site = $g.site; name = [string]$g.site_name; stage = 0 })
    if ($picked.Count -ge $maxSources) { break }
  }
  $candidates[$id] = $picked
}

@('<?xml version="1.0" encoding="UTF-8"?>', '<channels>') + $lines + '</channels>' |
  Set-Content -Path (Join-Path $EpgDir $Out) -Encoding utf8
$mapFile = Join-Path $EpgDir (([IO.Path]::GetFileNameWithoutExtension($Out) -replace '\.channels$', '') + '.sources.json')
$candidates | ConvertTo-Json -Depth 5 | Set-Content -Path $mapFile -Encoding utf8
Write-Host "Wrote $($candidates.Count) channels ($($lines.Count) sources) to $(Join-Path $EpgDir $Out)"
