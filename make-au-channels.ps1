# Builds au.channels.xml for the iptv-org EPG grabber: the provider's Australian sport channels
# (Fox Sports 501-507, ESPN, beIN, Sky Racing). Stan event feeds have no guide and are left out.
# Up to four guide sites are collected per channel; finish-guide.ps1 keeps the best one under the
# provider's channel name, so Luma matches "AU | FOX SPORTS 503" exactly.
# Usage (PowerShell 7):  pwsh -ExecutionPolicy Bypass -File make-au-channels.ps1
param([string]$EpgDir = "$env:USERPROFILE\epg", [string]$Out = 'au.channels.xml')

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $EpgDir)) { New-Item -ItemType Directory -Path $EpgDir | Out-Null }
Write-Host "Downloading iptv-org channel and guide lists (about a minute)..."
$channels = Invoke-RestMethod "https://iptv-org.github.io/api/channels.json"
$guides   = Invoke-RestMethod "https://iptv-org.github.io/api/guides.json"

# Preferred sites (others for Australia are still used, after these).
$sites = @('foxtel.com.au', 'foxsports.com.au', 'kayosports.com.au', 'binge.com.au')
# Whole-country file downloads (i.mjh.nz, epg.iptvx.one) ran the collector out of memory; epgshare01 likewise.
$skipSites = @('i.mjh.nz', 'epg.iptvx.one', 'epgshare01.online', 'tvprofil.com', 'nzxmltv.com', 'sky.co.nz')
# (Sky NZ listings are left out so ESPN uses Australian times and programmes.)

# Provider channel name -> countries and names used by guide sites (Foxtel channel numbers in brackets).
$wanted = [ordered]@{
  'AU | FOX CRICKET'    = @{ c = @('au'); n = @('Fox Cricket', 'Fox Sports 501') }
  'AU | FOX SPORTS 502' = @{ c = @('au'); n = @('Fox League', 'Fox Sports 502') }
  'AU | FOX SPORTS 503' = @{ c = @('au'); n = @('Fox Sports 503') }
  'AU | FOX SPORTS 504' = @{ c = @('au'); n = @('Fox Footy', 'Fox Sports 504') }
  'AU | FOX SPORTS 505' = @{ c = @('au'); n = @('Fox Sports 505') }
  'AU | FOX SPORTS 506' = @{ c = @('au'); n = @('Fox Sports 506') }
  'AU | FOX SPORTS 507' = @{ c = @('au'); n = @('Fox Sports More', 'Fox Sports More+', 'Fox Sports 507') }
  'AU | ESPN'           = @{ c = @('au'); n = @('ESPN', 'ESPN Australia') }
  'AU | ESPN 2'         = @{ c = @('au'); n = @('ESPN2', 'ESPN 2') }
  'AU | BEIN SPORT 1'   = @{ c = @('au'); n = @('beIN Sports 1', 'beIN SPORTS 1 HD') }
  'AU | BEIN SPORT 2'   = @{ c = @('au'); n = @('beIN Sports 2', 'beIN SPORTS 2 HD') }
  'AU | BEIN SPORT 3'   = @{ c = @('au'); n = @('beIN Sports 3', 'beIN SPORTS 3 HD') }
  'AU | SKY RACING 1'   = @{ c = @('au'); n = @('Sky Racing', 'Sky Racing 1', 'SKY Racing 1', 'Sky Racing HD', 'Sky Thoroughbred Central') }
  'AU | SKY RACING 2'   = @{ c = @('au'); n = @('Sky Racing 2') }
  'AU | RACING TV'      = @{ c = @('au'); n = @('Racing.com', 'Racing TV') }
}

function Norm([string]$s) {
  if (-not $s) { return '' }
  $s = ($s.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '').ToLower()
  $s = $s -replace '&', ' and ' -replace '\+', ' plus ' -replace '\(.*?\)', ' '
  $s = $s -replace '[^a-z0-9]+', ' ' -replace '\bsports\b', 'sport' -replace '\b(hd|fhd|uhd|sd)\b', ' '
  return ($s -replace '\s+', '')
}
function CountryOf([string]$id) { if ($id -match '\.([a-z]{2})(@|$)') { $Matches[1] } else { '' } }

$bySiteName = @{}; $byChannel = @{}
foreach ($g in $guides) {
  if (-not $g.site -or -not $g.site_id -or $g.site -in $skipSites) { continue }
  # Australian sites sometimes list a channel without an iptv-org id (e.g. Foxtel's Fox Sports More).
  if (-not $g.channel -and $g.site -notin $sites) { continue }
  $k = Norm $g.site_name
  if ($k) { if (-not $bySiteName.ContainsKey($k)) { $bySiteName[$k] = [Collections.Generic.List[object]]::new() }; $bySiteName[$k].Add($g) }
  if (-not $g.channel) { continue }
  $c = [string]$g.channel
  if (-not $byChannel.ContainsKey($c)) { $byChannel[$c] = [Collections.Generic.List[object]]::new() }
  $byChannel[$c].Add($g)
}
$byName = @{}
foreach ($c in $channels) {
  if (-not $c.id -or $c.closed) { continue }
  foreach ($n in @($c.name) + @($c.alt_names)) {
    $k = Norm $n
    if (-not $k) { continue }
    if (-not $byName.ContainsKey($k)) { $byName[$k] = [Collections.Generic.List[object]]::new() }
    $byName[$k].Add($c)
  }
}

function Rank($g, [int]$stage) {
  $i = $sites.IndexOf($g.site); if ($i -lt 0) { $i = 50 }
  return ($stage * 1000) + ($i * 10)
}

$maxSources = 4
$idFor = @{}; $used = @{}
$candidates = [ordered]@{}
$lines = [Collections.Generic.List[string]]::new()
$report = foreach ($p in $wanted.Keys) {
  $countries = $wanted[$p].c
  $cands = [Collections.Generic.List[object]]::new()
  foreach ($t in @($p) + $wanted[$p].n) {
    $k = Norm $t
    if ($bySiteName.ContainsKey($k)) {
      foreach ($g in $bySiteName[$k]) { if ((-not $g.channel -and $g.site -in $sites) -or (CountryOf $g.channel) -in $countries) { $cands.Add([pscustomobject]@{ G = $g; R = (Rank $g 0) }) } }
    }
    if ($byName.ContainsKey($k)) {
      foreach ($c in $byName[$k]) {
        if ((CountryOf $c.id) -notin $countries -or -not $byChannel.ContainsKey([string]$c.id)) { continue }
        foreach ($g in $byChannel[[string]$c.id]) { $cands.Add([pscustomobject]@{ G = $g; R = (Rank $g 1) }) }
      }
    }
  }
  $picked = [Collections.Generic.List[object]]::new()
  $taken = @{}
  foreach ($cand in ($cands | Sort-Object -Stable R)) {
    $g = $cand.G
    if ($taken.ContainsKey($g.site)) { continue }
    $taken[$g.site] = $true
    $key = "$($g.site)|$($g.site_id)"
    if (-not $idFor.ContainsKey($key)) {
      $id = $p; $n = 1
      while ($used.ContainsKey($id)) { $n++; $id = "$p~$n" }
      $used[$id] = $true; $idFor[$key] = $id
      $lang = if ($g.lang) { $g.lang } else { 'en' }
      $lines.Add(('  <channel site="{0}" lang="{1}" xmltv_id="{2}" site_id="{3}">{4}</channel>' -f $g.site, $lang,
        [Security.SecurityElement]::Escape($id), [Security.SecurityElement]::Escape([string]$g.site_id),
        [Security.SecurityElement]::Escape($p)))
    }
    $picked.Add([pscustomobject]@{ id = $idFor[$key]; site = $g.site; name = [string]$g.site_name; stage = [int][math]::Floor($cand.R / 1000) })
    if ($picked.Count -ge $maxSources) { break }
  }
  if ($picked.Count -eq 0) { [pscustomobject]@{ Provider = $p; Sources = 'not found' }; continue }
  $candidates[$p] = $picked
  [pscustomobject]@{ Provider = $p; Sources = (($picked | ForEach-Object { "$($_.site) ($($_.name))" }) -join ' | ') }
}

@('<?xml version="1.0" encoding="UTF-8"?>', '<channels>') + $lines + '</channels>' |
  Set-Content -Path (Join-Path $EpgDir $Out) -Encoding utf8
$mapFile = Join-Path $EpgDir (([IO.Path]::GetFileNameWithoutExtension($Out) -replace '\.channels$', '') + '.sources.json')
$candidates | ConvertTo-Json -Depth 5 | Set-Content -Path $mapFile -Encoding utf8
$report | Export-Csv -NoTypeInformation -Path (Join-Path $EpgDir 'au-channel-map.csv')
$report | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Host
Write-Host ("Matched {0} of {1} channels; {2} sources to collect" -f $candidates.Count, $wanted.Count, $lines.Count)