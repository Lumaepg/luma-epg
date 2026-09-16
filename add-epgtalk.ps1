# Fills US/Canada channels our collector can't reach (tvtv.us-only) from the EPGTalk US guide.
# Only channels that have no listings in our guide are added, under our own channel ids.
# Usage (PowerShell 7):  pwsh -File add-epgtalk.ps1 -Guide C:\Users\Ross\epg\na.xml
param(
  [Parameter(Mandatory)][string]$Guide,
  [string]$Url = 'https://raw.githubusercontent.com/acidjesuz/EPGTalk/master/US_guide.xml.gz',
  [int]$Days = 3
)
$ErrorActionPreference = 'Stop'
$Guide = (Resolve-Path $Guide).Path

# Our id -> (display name, Gracenote station number inside the EPGTalk id, e.g. I557.114759.schedulesdirect.org)
$wanted = [ordered]@{
  'AMCPlus.us'             = @('AMC+', '114759')
  'CNBCWorld.us'           = @('CNBC World', '26849')
  'CNNenEspanol.us'        = @('CNN en Espanol', '17054')
  'DiscoveryenEspanol.us'  = @('Discovery en Espanol', '19247')
  'DiscoveryFamilia.us'    = @('Discovery Familia', '58428')
  'ESPNDeportes.us'        = @('ESPN Deportes', '25595')
  'HistoryenEspanol.us'    = @('History en Espanol', '43362')
  'MGMPlus.us'             = @('MGM+', '65687')
  'NatGeoMundo.us'         = @('Nat Geo Mundo', '72449')
  'NBCSportsCalifornia.us' = @('NBC Sports California', '73565')
  'NBCSportsBayArea.us'    = @('NBC Sports Bay Area', '63138')
  'SonyMovies.us'          = @('Sony Movies', '69130')
}

[xml]$doc = Get-Content $Guide -Raw
$have = @{}
foreach ($p in $doc.tv.programme) { $have[$p.GetAttribute('channel')] = $true }
$need = @{}
foreach ($id in $wanted.Keys) { if (-not $have.ContainsKey($id)) { $need[$wanted[$id][1]] = $id } }
if ($need.Count -eq 0) { Write-Host 'All EPGTalk channels already have listings; nothing to add.'; return }

$gz = Join-Path ([IO.Path]::GetTempPath()) 'epgtalk-us.xml.gz'
Write-Host "Downloading $Url ..."
Invoke-WebRequest $Url -OutFile $gz
$from = (Get-Date).ToUniversalTime().AddHours(-6).ToString('yyyyMMddHHmm')
$until = (Get-Date).ToUniversalTime().AddDays($Days).ToString('yyyyMMddHHmm')

$added = @{}
$sourceFor = @{}   # EPGTalk repeats some stations under two channel numbers; keep the first
$settings = [Xml.XmlReaderSettings]::new(); $settings.DtdProcessing = 'Ignore'
$stream = [IO.Compression.GZipStream]::new([IO.File]::OpenRead($gz), [IO.Compression.CompressionMode]::Decompress)
$r = [Xml.XmlReader]::Create($stream, $settings)
$r.MoveToContent() | Out-Null
while (-not $r.EOF) {
  if ($r.NodeType -eq 'Element' -and $r.Name -eq 'programme') {
    $source = $r.GetAttribute('channel'); $start = $r.GetAttribute('start')
    $station = if ($source -match '^I\d+\.(\d+)\.') { $Matches[1] } else { '' }
    if ($station -and $need.ContainsKey($station) -and -not $sourceFor.ContainsKey($station)) { $sourceFor[$station] = $source }
    if ($station -and $need.ContainsKey($station) -and $sourceFor[$station] -eq $source -and $start -and $start.Substring(0, 12) -ge $from -and $start.Substring(0, 12) -le $until) {
      $node = $doc.ReadNode($r)          # advances the reader past this programme
      $target = $need[$station]
      $node.SetAttribute('channel', $target)
      $doc.tv.AppendChild($node) | Out-Null
      $added[$target] = 1 + [int]$added[$target]
      continue
    }
  }
  $r.Read() | Out-Null
}
$r.Dispose(); $stream.Dispose(); Remove-Item $gz

foreach ($target in $added.Keys) {
  if ($doc.tv.channel | Where-Object { $_.GetAttribute('id') -eq $target }) { continue }
  $ch = $doc.CreateElement('channel'); $ch.SetAttribute('id', $target)
  $dn = $doc.CreateElement('display-name'); $dn.InnerText = $wanted[$target][0]; $ch.AppendChild($dn) | Out-Null
  $first = $doc.tv.SelectSingleNode('programme')
  if ($first) { $doc.tv.InsertBefore($ch, $first) | Out-Null } else { $doc.tv.AppendChild($ch) | Out-Null }
}
$settingsOut = [Xml.XmlWriterSettings]::new(); $settingsOut.Encoding = [Text.UTF8Encoding]::new($false)
$w = [Xml.XmlWriter]::Create($Guide, $settingsOut); $doc.Save($w); $w.Dispose()

foreach ($id in $wanted.Keys) {
  $status = if ($have.ContainsKey($id)) { 'already had listings' } elseif ($added.ContainsKey($id)) { "added $($added[$id]) programmes" } else { 'not in EPGTalk today' }
  Write-Host ("  {0,-24} {1}" -f $wanted[$id][0], $status)
}
Write-Host "Updated $Guide"