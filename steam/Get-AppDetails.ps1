<#
.SYNOPSIS
  Given a list of Steam appids, fetch store details (name, genres, categories,
  Metacritic, live price, discount) into a CSV + JSON.

.DESCRIPTION
  Hits the undocumented-but-stable storefront endpoint
  https://store.steampowered.com/api/appdetails?appids=<id>
  ONE APPID AT A TIME. Passing several comma-separated appids only returns
  price_overview for each and drops name/genres/categories, so batching is a trap.

  Rate limit is roughly 200 requests / 5 minutes per IP. The 1.3s sleep below
  keeps it under that. 183 appids takes ~5 minutes; 266 takes ~7. Run it with
  Bash run_in_background (or PowerShell -run_in_background) and wait on the
  output file rather than blocking the session.

.PARAMETER InFile
  JSON array whose objects each have an .appid property. Both
  wishlist_items.json and the .response.games array of owned_games.json work
  (see -OwnedJson to unwrap the latter automatically).

.EXAMPLE
  # A wishlist export (JSON array of objects with .appid)
  pwsh -NoProfile -File .\Get-AppDetails.ps1 -InFile ..wishlist_items.json -OutStem wishlist_details

.EXAMPLE
  # Owned library
  pwsh -NoProfile -File .\Get-AppDetails.ps1 -InFile ..\owned_games.json -OwnedJson -OutStem owned_details
#>
param(
  [Parameter(Mandatory)][string]$InFile,
  [Parameter(Mandatory)][string]$OutStem,
  [switch]$OwnedJson,
  [string]$OutDir = ".",
  [string]$Region = 'us',
  [int]$SleepMs = 1300
)

$raw = Get-Content $InFile -Raw | ConvertFrom-Json
$items = if ($OwnedJson) { $raw.response.games } else { $raw }
"Fetching {0} appids..." -f $items.Count

$out = @()
$n = 0
foreach ($it in $items) {
  $id = $it.appid
  $n++
  $ok = $false
  for ($try = 0; $try -lt 3 -and -not $ok; $try++) {
    try {
      $d = Invoke-RestMethod "https://store.steampowered.com/api/appdetails?appids=$id&cc=$Region&l=english" `
             -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -TimeoutSec 30
      $node = $d.$id
      if ($node.success) {
        $x = $node.data
        $out += [pscustomobject]@{
          appid       = $id
          name        = $x.name
          type        = $x.type
          coming_soon = $x.release_date.coming_soon
          release     = $x.release_date.date
          genres      = ($x.genres.description -join '|')
          cats        = ($x.categories.description -join '|')   # 'Shared/Split Screen' lives here -- the couch co-op test
          metacritic  = $x.metacritic.score
          initial     = $x.price_overview.initial               # cents
          final       = $x.price_overview.final                 # cents
          discount    = $x.price_overview.discount_percent
          free        = $x.is_free
          playtime    = $it.playtime_forever                    # present only for owned
          last_played = $it.rtime_last_played                   # present only for owned
        }
      } else {
        # success:false means delisted, region-locked, or a DLC-only page
        $out += [pscustomobject]@{ appid=$id; name='(no data)'; type=''; coming_soon=''; release='';
          genres=''; cats=''; metacritic=''; initial=''; final=''; discount=''; free='';
          playtime=$it.playtime_forever; last_played=$it.rtime_last_played }
      }
      $ok = $true
    } catch {
      Start-Sleep -Seconds 20   # rate-limited: back off hard, then retry
    }
  }
  if ($n % 25 -eq 0) { "  ...$n / $($items.Count)" }
  Start-Sleep -Milliseconds $SleepMs
}

$out | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $OutDir "$OutStem.json")
$out | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $OutDir "$OutStem.csv")
"DONE: {0} rows -> {1}\{2}.csv" -f $out.Count, $OutDir, $OutStem
