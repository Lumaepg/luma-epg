# Builds intl.channels.xml for the iptv-org EPG grabber: foreign channels in the provider's UK section
# (ESPN Netherlands, Sport TV Portugal, SuperSport, beIN, Real Madrid TV, Court TV).
# Up to four guide sites are collected per channel; finish-guide.ps1 keeps the best one under the
# provider's own guide id. Listings may be in the channel's own language.
# Usage (PowerShell 7):  pwsh -ExecutionPolicy Bypass -File make-intl-channels.ps1
param([string]$EpgDir = "$env:USERPROFILE\epg", [string]$Out = 'intl.channels.xml')

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $EpgDir)) { New-Item -ItemType Directory -Path $EpgDir | Out-Null }
Write-Host "Downloading iptv-org channel and guide lists (about a minute)..."
$channels = Invoke-RestMethod "https://iptv-org.github.io/api/channels.json"
$guides   = Invoke-RestMethod "https://iptv-org.github.io/api/guides.json"

# Preferred sites (others for the same country are still used, after these).
$sites = @('ziggogo.tv', 'tvgids.nl', 'webtv.delta.nl', 'meo.pt', 'nostv.pt', 'dstv.com', 'bein.com',
           'movistarplus.es', 'tvpassport.com', 'tvguide.com', 'beinsports.com', 'plex.tv', 'pluto.tv')
# Sites never used: i.mjh.nz and epg.iptvx.one download whole-country files and ran the collector out
# of memory; tvprofil.com and chaines-tv.orange.fr refused requests in testing.
$skipSites = @('i.mjh.nz', 'epg.iptvx.one', 'tvprofil.com', 'chaines-tv.orange.fr')

# Provider guide id -> countries (iptv-org id suffix) and names used by guide sites.
$wanted = [ordered]@{
  'ESPN NL'               = @{ c = @('nl'); n = @('ESPN', 'ESPN 1', 'ESPN NL', 'ESPN1') }
  'ESPN 2 NL'             = @{ c = @('nl'); n = @('ESPN 2', 'ESPN2') }
  'ESPN 3 NL'             = @{ c = @('nl'); n = @('ESPN 3', 'ESPN3') }
  'ESPN 4 NL'             = @{ c = @('nl'); n = @('ESPN 4', 'ESPN4') }
  'SPORT TV1'             = @{ c = @('pt'); n = @('Sport TV1', 'Sport TV 1', 'SPORT TV1 HD') }
  'SPORT TV2'             = @{ c = @('pt'); n = @('Sport TV2', 'Sport TV 2') }
  'SPORT TV3'             = @{ c = @('pt'); n = @('Sport TV3', 'Sport TV 3') }
  'SPORT TV4'             = @{ c = @('pt'); n = @('Sport TV4', 'Sport TV 4') }
  'SPORT TV5'             = @{ c = @('pt'); n = @('Sport TV5', 'Sport TV 5') }
  'SPORT TV6'             = @{ c = @('pt'); n = @('Sport TV6', 'Sport TV 6') }
  'SUPERSPORT CRICKET'    = @{ c = @('za'); n = @('SuperSport Cricket', 'SS Cricket') }
  'BEIN SPORTS 1 ENGLISH' = @{ c = @('qa', 'ae', 'sa'); n = @('beIN Sports 1 English', 'beIN SPORTS 1', 'beIN Sports 1 HD') }
  'REAL MADRID TV'        = @{ c = @('es'); n = @('Real Madrid TV', 'Realmadrid TV') }
  'COURT TV'              = @{ c = @('us'); n = @('Court TV') }
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
  if (-not $g.site -or -not $g.site_id -or -not $g.channel -or $g.site -in $skipSites) { continue }
  $k = Norm $g.site_name
  if ($k) { if (-not $bySiteName.ContainsKey($k)) { $bySiteName[$k] = [Collections.Generic.List[object]]::new() }; $bySiteName[$k].Add($g) }
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
      foreach ($g in $bySiteName[$k]) { if ((CountryOf $g.channel) -in $countries) { $cands.Add([pscustomobject]@{ G = $g; R = (Rank $g 0) }) } }
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
$report | Export-Csv -NoTypeInformation -Path (Join-Path $EpgDir 'intl-channel-map.csv')
$report | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Host
Write-Host ("Matched {0} of {1} channels; {2} sources to collect" -f $candidates.Count, $wanted.Count, $lines.Count)
