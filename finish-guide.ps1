# Tidies a collected guide for Luma. When a .sources.json file exists (made by make-uk-channels.ps1),
# each provider channel keeps whichever source returned the most listings, under the provider's own id.
# Prints a per-channel report and saves it as <guide>-report.csv.
# Usage (PowerShell 7):  pwsh -File finish-guide.ps1 -Guide C:\Users\Ross\epg\uk.xml -Sources C:\Users\Ross\epg\uk.sources.json
param(
  [Parameter(Mandatory)][string]$Guide,
  [string]$Sources = ''
)
$ErrorActionPreference = 'Stop'
$Guide = (Resolve-Path $Guide).Path
[xml]$doc = Get-Content $Guide -Raw

$byChannel = @{}
foreach ($p in $doc.tv.programme) {
  $c = $p.GetAttribute('channel')
  if (-not $byChannel.ContainsKey($c)) { $byChannel[$c] = [Collections.Generic.List[Xml.XmlElement]]::new() }
  $byChannel[$c].Add($p)
}

$rows = [Collections.Generic.List[object]]::new()
if ($Sources -and (Test-Path $Sources)) {
  $map = Get-Content $Sources -Raw | ConvertFrom-Json
  $settings = [Xml.XmlWriterSettings]::new()
  $settings.Indent = $false
  $settings.Encoding = [Text.UTF8Encoding]::new($false)
  $settings.NewLineChars = "`n"
  $settings.NewLineHandling = 'Replace'
  $tmp = "$Guide.tmp"
  $w = [Xml.XmlWriter]::Create($tmp, $settings)
  $w.WriteStartDocument()
  $w.WriteStartElement('tv')
  foreach ($a in $doc.tv.Attributes) { $w.WriteAttributeString($a.Name, $a.Value) }

  $chosen = [ordered]@{}
  foreach ($prop in $map.PSObject.Properties) {
    # Sources are listed best first. Keep the first one (preferring exact name matches) that has
    # at least 80% of the highest listing count, so a site with one extra programme doesn't win.
    $list = @($prop.Value); $tried = @(); $max = 0
    foreach ($s in $list) {
      $n = if ($byChannel.ContainsKey($s.id)) { $byChannel[$s.id].Count } else { 0 }
      $s | Add-Member -NotePropertyName count -NotePropertyValue $n -Force
      $tried += "$($s.site)=$n"
      if ($n -gt $max) { $max = $n }
    }
    $best = $null; $bestCount = 0
    if ($max -gt 0) {
      $best = $list | Where-Object { $_.count -gt 0 -and $_.count -ge 0.8 * $max } |
        Sort-Object -Stable { if ($null -ne $_.stage) { [int]$_.stage } else { 0 } } | Select-Object -First 1
      $bestCount = $best.count
    }
    $rows.Add([pscustomobject]@{
      Channel = $prop.Name; Programmes = $bestCount
      Source = if ($best) { "$($best.site) ($($best.name))" } else { '' }
      Tried = $tried -join ', '
    })
    if ($best) { $chosen[$prop.Name] = $best.id }
  }
  $displayNames = @{}
  foreach ($c in $doc.tv.channel) {
    $dn = $c.SelectSingleNode('display-name')
    if ($dn) { $displayNames[$c.GetAttribute('id')] = $dn.InnerText }
  }
  foreach ($name in $chosen.Keys) {
    $label = if ($displayNames.ContainsKey($chosen[$name])) { $displayNames[$chosen[$name]] } else { $name }
    $w.WriteStartElement('channel'); $w.WriteAttributeString('id', $name)
    $w.WriteElementString('display-name', $label); $w.WriteEndElement()
  }
  foreach ($name in $chosen.Keys) {
    foreach ($p in $byChannel[$chosen[$name]]) {
      $copy = $p.Clone()
      $copy.SetAttribute('channel', $name)
      $copy.WriteTo($w)
      $w.WriteWhitespace("`n")
    }
  }
  $w.WriteEndElement()
  $w.WriteEndDocument()
  $w.Close()
  Move-Item -Force $tmp $Guide
}
else {
  foreach ($c in $doc.tv.channel) {
    $id = $c.GetAttribute('id')
    $rows.Add([pscustomobject]@{
      Channel = $id; Programmes = if ($byChannel.ContainsKey($id)) { $byChannel[$id].Count } else { 0 }
      Source = ''; Tried = ''
    })
  }
}

$rows | Sort-Object Programmes, Channel | Format-Table Channel, Programmes, Source -AutoSize | Out-String -Width 220 | Write-Host
$ok = @($rows | Where-Object Programmes -gt 0).Count
Write-Host ("Channels with listings: {0} of {1}" -f $ok, $rows.Count) -ForegroundColor Green
$rows | Where-Object Programmes -eq 0 | ForEach-Object { "  no listings: $($_.Channel)  [$($_.Tried)]" } | Write-Host
$report = [IO.Path]::ChangeExtension($Guide, $null).TrimEnd('.') + '-report.csv'
$rows | Export-Csv -NoTypeInformation -Path $report
Write-Host "Report saved to $report"
