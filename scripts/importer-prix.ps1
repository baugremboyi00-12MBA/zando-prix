# Met à jour data/estimations.json avec les prix estimés de la Banque mondiale.
# Source : Monthly food price estimates by product and market (RTFP), données ouvertes.
# Usage : powershell -ExecutionPolicy Bypass -File scripts\importer-prix.ps1 -OutFile data\estimations.json
param([Parameter(Mandatory = $true)][string]$OutFile, [int]$Months = 13)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$api = 'https://microdata.worldbank.org/index.php/api/tables'
$table = 'fcv/wld_2021_rtfp_v02_m'

$products = [ordered]@{ rice = 'riz'; cassava_flour = 'foufou'; oil = 'huile'; beans = 'haricot' }
$depts = @{ 'Likouala' = 'Likouala'; 'Brazzaville' = 'Brazzaville'; 'Point-Noire' = 'Pointe-Noire'; 'Pointe-Noire' = 'Pointe-Noire'; 'Pool' = 'Pool'; 'Bouenza' = 'Bouenza'; 'Cuvette' = 'Cuvette'; 'Lekoumou' = 'Lékoumou' }
$towns = @{ 'Betou' = 'Bétou' }
$invariant = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-Monthly([string]$date) {
  $url = "$api/data/$table" + "?ISO3=COG&format=json&limit=40&price_date=$date"
  for ($try = 1; $try -le 3; $try++) {
    try { return Invoke-RestMethod -Uri $url -TimeoutSec 90 }
    catch { if ($try -eq 3) { throw }; Start-Sleep -Seconds (5 * $try) }
  }
}

# On remonte depuis le mois courant jusqu'à obtenir $Months mois publiés.
$collected = @()
$cursor = Get-Date -Day 1
for ($back = 0; $back -lt ($Months + 6) -and $collected.Count -lt $Months; $back++) {
  $date = $cursor.AddMonths(-$back).ToString('yyyy-MM-01')
  $res = Get-Monthly $date
  if ($res.found -gt 0) { $collected += , @{ month = $date.Substring(0, 7); rows = $res.data } }
}
if ($collected.Count -eq 0) { throw 'La Banque mondiale ne renvoie aucune donnée pour le Congo.' }

$markets = @{}
$lastSurvey = ''
foreach ($m in ($collected | Sort-Object { $_.month })) {
  foreach ($row in $m.rows) {
    if ($row.mkt_name -eq 'Market Average') { continue }
    if (-not $depts.ContainsKey($row.adm1_name)) { throw "Département inconnu : $($row.adm1_name). Ajoute-le à la table de correspondance." }
    $id = $row.geo_id
    if (-not $markets.ContainsKey($id)) {
      $town = $row.adm2_name
      if ($towns.ContainsKey($town)) { $town = $towns[$town] }
      $series = [ordered]@{}
      foreach ($p in $products.Values) { $series[$p] = New-Object System.Collections.ArrayList }
      $markets[$id] = [ordered]@{ id = $id; departement = $depts[$row.adm1_name]; ville = $town; marche = $row.mkt_name; series = $series }
    }
    $lastSurvey = $row.last_survey_point
    foreach ($key in $products.Keys) {
      $raw = $row."c_$key"
      if ("$raw" -eq '') { continue }
      $value = [double]::Parse("$raw", $invariant)
      if ($value -le 0) { continue }
      [void]$markets[$id].series[$products[$key]].Add([ordered]@{ m = $m.month; p = [int][Math]::Round($value) })
    }
  }
}
if ($markets.Count -lt 10) { throw "Seulement $($markets.Count) marchés reçus : import annulé, les données actuelles sont conservées." }

$info = Invoke-RestMethod -Uri "$api/info/$table" -TimeoutSec 90
$version = ''
if ($info.result.metadata.description -match 'version date:\s*(\d{4}-\d{2}-\d{2})') { $version = $Matches[1] }
$newest = ($collected | Sort-Object { $_.month } | Select-Object -Last 1).month
$surveyDate = ''
try { $surveyDate = [datetime]::ParseExact($lastSurvey, 'MMM yyyy', $invariant).ToString('yyyy-MM') } catch { $surveyDate = '' }

# Aucun changement à la source : on ne réécrit pas le fichier.
if (Test-Path $OutFile) {
  $old = [IO.File]::ReadAllText((Resolve-Path $OutFile), $utf8) | ConvertFrom-Json
  if ($old.source.version -eq $version -and $old.source.dernierMois -eq $newest) {
    Write-Output "Aucune nouvelle version (version $version, dernier mois $newest)."
    exit 0
  }
}

$list = @($markets.Keys | Sort-Object | ForEach-Object { $markets[$_] })
$doc = [ordered]@{
  source = [ordered]@{
    nom = 'Banque mondiale, Monthly food price estimates by product and market'
    version = $version; dernierMois = $newest; derniereEnquete = $surveyDate
    importeLe = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  }
  marches = $list
}
$dir = Split-Path -Parent $OutFile
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$full = Join-Path (Resolve-Path $(if ($dir) { $dir } else { '.' })) (Split-Path -Leaf $OutFile)
[IO.File]::WriteAllText($full, ($doc | ConvertTo-Json -Depth 8 -Compress), $utf8)
Write-Output ("OK : {0} marchés, dernier mois {1}, version {2}, dernière enquête {3}" -f $markets.Count, $newest, $version, $surveyDate)
