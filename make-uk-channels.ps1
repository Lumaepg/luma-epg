# Builds uk.channels.xml for the iptv-org EPG grabber: the provider's UK and Irish channels,
# Up to four guide sites are collected per channel (sky.com first); finish-guide.ps1 then keeps
# whichever source returned the most listings, under the provider's own guide id.
# Usage (PowerShell 7):  pwsh -ExecutionPolicy Bypass -File make-uk-channels.ps1
param([string]$EpgDir = "$env:USERPROFILE\epg", [string]$Out = 'uk.channels.xml')

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $EpgDir)) { New-Item -ItemType Directory -Path $EpgDir | Out-Null }
Write-Host "Downloading iptv-org channel and guide lists (about a minute)..."
$channels = Invoke-RestMethod "https://iptv-org.github.io/api/channels.json"
$guides   = Invoke-RestMethod "https://iptv-org.github.io/api/guides.json"

# Guide websites, best first.
# (mytelly.co.uk is left out: it started refusing the collector.)
$sites = @('sky.com', 'freeview.co.uk', 'virgintvgo.virginmedia.com', 'player.ee.co.uk',
           'tvireland.ie', 'entertainment.ie', 'virginmediatelevision.ie')

# Provider channel names (from the provider's guide). Left out: 24/7, NOW EPL event feeds and foreign
# sports channels (no UK guide source), Club MTV/MTV 90s/MTV Live/MTV Music (no listings anywhere)
# and Sky Cinema Select (its old guide slot now carries Sky Cinema Animation).
$provider = @(
  '4SEVEN',
  '5 ACTION',
  '5 SELECT',
  '5 USA',
  '5*',
  'AL JAZEERA',
  'ALIBI HD',
  'ANIMAL PLANET',
  'B4U MOVIES',
  'B4U MUSIC',
  'BABY TV',
  'BBC ALBA',
  'BBC FOUR HD',
  'BBC NEWS',
  'BBC ONE',
  'BBC SCOTLAND',
  'BBC THREE HD',
  'BBC TWO',
  'BLAZE TV',
  'BOOMERANG',
  'CARTOON NETWORK HD',
  'CARTOONITO',
  'CBBC',
  'CBEEBIES',
  'CHALLENGE',
  'CHANNEL 4',
  'CHANNEL 5',
  'CLUBLAND TV',
  'CNN UK',
  'COMEDY CENTRAL EXTRA',
  'COMEDY CENTRAL HD',
  'COURT TV',
  'CRIME AND INVESTIGATION HD',
  'DAVE',
  'DISCOVERY HISTORY',
  'DISCOVERY SCIENCE',
  'DISCOVERY TURBO',
  'DISCOVERY UK',
  'DMAX',
  'DRAMA',
  'E4',
  'E4 EXTRA',
  'EDEN HD',
  'EURO NEWS',
  'FILM 4 HD',
  'FOOD NETWORK',
  'GB NEWS',
  'GOLD',
  'GREAT! ACTION',
  'GREAT! CHRISTMAS',
  'GREAT! MYSTERY',
  'GREAT! TV',
  'HISTORY 2 UK (HD)',
  'ID INVESTIGATION DISCOVERY',
  'ISLAM CHANNEL',
  'ITV 1',
  'ITV 2',
  'ITV QUIZ',
  'ITV+1',
  'ITV2 +1',
  'ITV3 HD',
  'ITV4 HD',
  'LEGEND',
  'LEGEND XTRA',
  'LFCTV',
  'MORE 4',
  'MTV',
  'MUTV',
  'NAT GEO WILD HD',
  'NATIONAL GEO HD',
  'NICK JR TOO',
  'NICK JUNIOR',
  'NICKELODEON HD',
  'NICKTOONS',
  'NOW 70s',
  'NOW 80s',
  'NOW ROCK',
  'POP',
  'PREMIER SPORTS',
  'PREMIER SPORTS 2',
  'PREMIER SPORTS RUGBY',
  'QUEST HD',
  'QUEST RED',
  'RACING TV',
  'REAL MADRID TV',
  'REALLY',
  'RTE JUNIOR',
  'RTE ONE',
  'RTE TWO',
  'S4C HD',
  'SKY ARTS',
  'SKY ATLANTIC',
  'SKY CINEMA ACTION',
  'SKY CINEMA ANIMATION',
  'SKY CINEMA COMEDY',
  'SKY CINEMA DRAMA',
  'SKY CINEMA FAMILY',
  'SKY CINEMA GREATS',
  'SKY CINEMA HITS',
  'SKY CINEMA PREMIERE',
  'SKY CINEMA SCIFI/HORROR',
  'SKY CINEMA THRILLER',
  'SKY CRIME',
  'SKY DOCUMENTARIES HD',
  'SKY HISTORY',
  'SKY MAX',
  'SKY MIX',
  'SKY NATURE HD',
  'SKY NEWS',
  'SKY NEWS HD',
  'SKY SCI-FI HD',
  'SKY SPORTS ACTION',
  'SKY SPORTS CRICKET',
  'SKY SPORTS F1',
  'SKY SPORTS FOOTBALL',
  'SKY SPORTS GOLF',
  'SKY SPORTS MAIN EVENT',
  'SKY SPORTS MIX',
  'SKY SPORTS NEWS',
  'SKY SPORTS NFL',
  'SKY SPORTS PREMIER LEAGUE',
  'SKY SPORTS RACING',
  'SKY SPORTS TENNIS',
  'SKY WITNESS',
  'SKYCOMEDY',
  'SKYCOMEDY HD',
  'SONY MAX',
  'SONY SAB',
  'STV SCOTLAND',
  'TALKING PICTURES',
  'TG4 HD',
  'TLC HD',
  'TNT SPORT 1',
  'TNT SPORT 10',
  'TNT SPORT 2',
  'TNT SPORT 3',
  'TNT SPORT 4',
  'TNT SPORT 5',
  'TNT SPORT 6',
  'TNT SPORT 7',
  'TNT SPORT 8',
  'TNT SPORT 9',
  'TRAVEL XP CHANNEL',
  'TRUE CRIME',
  'TRUE CRIME XTRA',
  'UTV',
  'VIRGIN MEDIA ONE HD',
  'VIRGIN MEDIA THREE HD',
  'VIRGIN MEDIA TWO HD',
  'W',
  'YESTERDAY',
  'ZEE TV'
)

# Other names a channel goes by on the guide sites.
$aliases = @{
  '5*'                         = @('5STAR', '5 Star')
  'ALIBI HD'                   = @('Alibi', 'U&Alibi')
  'AL JAZEERA'                 = @('Al Jazeera English')
  'BABY TV'                    = @('BabyTV')
  'BLAZE TV'                   = @('Blaze')
  'CNN UK'                     = @('CNN International', 'CNN')
  'CRIME AND INVESTIGATION HD' = @('Crime+Investigation', 'Crime & Investigation')
  'DAVE'                       = @('U&Dave')
  'DISCOVERY UK'               = @('Discovery Channel', 'Discovery')
  'DRAMA'                      = @('U&Drama')
  'EDEN HD'                    = @('U&Eden', 'Eden')
  'EURO NEWS'                  = @('Euronews')
  'GOLD'                       = @('U&Gold', 'UKTV Gold')
  'GREAT! CHRISTMAS'           = @('GREAT! Christmas', 'GREAT! romance')
  'HISTORY 2 UK (HD)'          = @('HISTORY2', 'Sky History 2', 'History 2')
  'ID INVESTIGATION DISCOVERY' = @('Investigation Discovery', 'ID')
  'ITV 1'                      = @('ITV1', 'ITV1 London')
  'ITV+1'                      = @('ITV1 +1', 'ITV1+1', 'ITV +1')
  'ITV2 +1'                    = @('ITV2+1')
  'ITV3 HD'                    = @('ITV3')
  'ITV4 HD'                    = @('ITV4')
  'MTV LIVE HD'                = @('MTV Live')
  'NAT GEO WILD HD'            = @('National Geographic Wild', 'Nat Geo Wild')
  'NATIONAL GEO HD'            = @('National Geographic', 'Nat Geo')
  'NICK JUNIOR'                = @('Nick Jr', 'Nick Jr.')
  'PREMIER SPORTS'             = @('Premier Sports 1')
  'RTE JUNIOR'                 = @('RTEjr', 'RTE Jr')
  'RTE TWO'                    = @('RTE2', 'RTE 2')
  'SKY CINEMA ANIMATION'       = @('SkyAnimationHD', 'Sky Animation HD')
  'SKY CINEMA SCIFI/HORROR'    = @('Sky Cinema Sci-Fi & Horror', 'Sky Cinema Sci-Fi/Horror')
  'SKY SPORTS ACTION'          = @('Sky Sports Action')
  'SKYCOMEDY'                  = @('Sky Comedy')
  'SKYCOMEDY HD'               = @('Sky Comedy')
  'SONY SAB'                   = @('SAB')
  'STV SCOTLAND'               = @('STV', 'STV HD')
  'TRAVEL XP CHANNEL'          = @('Travelxp', 'Travel XP')
  'W'                          = @('U&W')
  'YESTERDAY'                  = @('U&Yesterday')
}

function Norm([string]$s) {
  if (-not $s) { return '' }
  $s = ($s.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '').ToLower()
  $s = $s -replace '&', ' and ' -replace '\+\s*1\b', ' plus1 ' -replace '\+', ' plus ' -replace '\*', ' star ' -replace '\(.*?\)', ' '
  $s = $s -replace '[^a-z0-9]+', ' ' -replace '\bsports\b', 'sport' -replace '\bjunior\b', 'jr'
  $s = $s -replace '\b(hd|fhd|uhd|sd|uk|channel|tv)\b', ' '
  return ($s -replace '\s+', '')
}

# Index 1: the channel names as the guide websites show them.
$bySiteName = @{}
$byChannel = @{}
foreach ($g in $guides) {
  if (-not $g.site -or $g.site -notin $sites -or -not $g.site_id) { continue }
  if ($g.lang -and $g.lang -ne 'en') { continue }
  $k = Norm $g.site_name
  if ($k) { if (-not $bySiteName.ContainsKey($k)) { $bySiteName[$k] = [Collections.Generic.List[object]]::new() }; $bySiteName[$k].Add($g) }
  if ($g.channel) {
    $c = [string]$g.channel
    if (-not $byChannel.ContainsKey($c)) { $byChannel[$c] = [Collections.Generic.List[object]]::new() }
    $byChannel[$c].Add($g)
  }
}
# Index 2: iptv-org's UK/Irish channel names and alternative names.
$byName = @{}
foreach ($c in $channels) {
  if (-not $c.id -or $c.closed -or $c.country -notin 'UK', 'GB', 'IE') { continue }
  foreach ($n in @($c.name) + @($c.alt_names)) {
    $k = Norm $n
    if (-not $k) { continue }
    if (-not $byName.ContainsKey($k)) { $byName[$k] = [Collections.Generic.List[object]]::new() }
    $byName[$k].Add($c)
  }
}

function Rank($g, [int]$stage) {
  $country = if ([string]$g.channel -match '\.uk$') { 0 } elseif ([string]$g.channel -match '\.ie$') { 1 } else { 2 }
  $regional = if ($g.site_name -match '(?i)\b(lon|london|hd)\b') { 0 } else { 1 }
  return ($stage * 1000) + ($sites.IndexOf($g.site) * 100) + ($country * 10) + $regional
}

$maxSources = 4          # listings are collected from up to this many sites per channel
$idFor = @{}             # "site|site_id" -> id used in the grab file (each source is grabbed once)
$used = @{}
$candidates = [ordered]@{}
$lines = [Collections.Generic.List[string]]::new()
$report = foreach ($p in $provider) {
  $terms = @($p) + @($aliases[$p] | Where-Object { $_ })
  $cands = [Collections.Generic.List[object]]::new()
  foreach ($t in $terms) {
    $k = Norm $t
    if ($bySiteName.ContainsKey($k)) { foreach ($g in $bySiteName[$k]) { $cands.Add([pscustomobject]@{ G = $g; R = (Rank $g 0) }) } }
    if ($byName.ContainsKey($k)) {
      foreach ($c in $byName[$k]) {
        if ($byChannel.ContainsKey([string]$c.id)) { foreach ($g in $byChannel[[string]$c.id]) { $cands.Add([pscustomobject]@{ G = $g; R = (Rank $g 1) }) } }
      }
    }
  }
  $picked = [Collections.Generic.List[object]]::new()
  $sitesTaken = @{}
  foreach ($cand in ($cands | Sort-Object R)) {
    $g = $cand.G
    if ($sitesTaken.ContainsKey($g.site)) { continue }
    $sitesTaken[$g.site] = $true
    $key = "$($g.site)|$($g.site_id)"
    if (-not $idFor.ContainsKey($key)) {
      $id = $p; $n = 1
      while ($used.ContainsKey($id)) { $n++; $id = "$p~$n" }
      $used[$id] = $true
      $idFor[$key] = $id
      $lines.Add(('  <channel site="{0}" lang="en" xmltv_id="{1}" site_id="{2}">{3}</channel>' -f $g.site,
        [Security.SecurityElement]::Escape($id), [Security.SecurityElement]::Escape([string]$g.site_id),
        [Security.SecurityElement]::Escape($p)))
    }
    $picked.Add([pscustomobject]@{ id = $idFor[$key]; site = $g.site; name = [string]$g.site_name; stage = [int][math]::Floor($cand.R / 1000) })
    if ($picked.Count -ge $maxSources) { break }
  }
  if ($picked.Count -eq 0) {
    [pscustomobject]@{ Provider = $p; Sources = 'not found' }
    continue
  }
  $candidates[$p] = $picked
  [pscustomobject]@{ Provider = $p; Sources = (($picked | ForEach-Object { "$($_.site) ($($_.name))" }) -join ' | ') }
}

@('<?xml version="1.0" encoding="UTF-8"?>', '<channels>') + $lines + '</channels>' |
  Set-Content -Path (Join-Path $EpgDir $Out) -Encoding utf8
$mapFile = Join-Path $EpgDir ([IO.Path]::GetFileNameWithoutExtension($Out) -replace '\.channels$', '') 
$mapFile = "$mapFile.sources.json"
$candidates | ConvertTo-Json -Depth 5 | Set-Content -Path $mapFile -Encoding utf8
$report | Export-Csv -NoTypeInformation -Path (Join-Path $EpgDir 'uk-channel-map.csv')
$found = @($candidates.Keys).Count
Write-Host ("Matched {0} of {1} provider channels; {2} sources to collect; list: {3}" -f $found, $report.Count, $lines.Count, (Join-Path $EpgDir $Out))
$report | Where-Object Sources -eq 'not found' | ForEach-Object { "  not found: $($_.Provider)" } | Write-Host
