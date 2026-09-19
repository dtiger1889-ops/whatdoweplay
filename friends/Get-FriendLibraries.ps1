<#
.SYNOPSIS
  Fetch each friend's Steam library (GetOwnedGames) for everyone in roster.json,
  with an optional fallback to a saved copy of their Steam Community games page
  when the API returns nothing (their Game Details privacy is not Public).

.DESCRIPTION
  roster.json is a JSON array; each object needs:
    persona   - the display name you want on the page
    steamid   - their SteamID64 (paste their profile URL into https://steamid.io/)
    clipping  - OPTIONAL: filename of a markdown export of
                https://steamcommunity.com/profiles/<steamid>/games/?tab=all
                (a browser "web clipper" that saves pages as markdown produces the
                expected shape). Used only when the API gives 0 games.

  Two privacy layers, learned the hard way:
    1. YOUR "Friends List" privacy does not matter here: this script never calls
       GetFriendList (which returns 401 unless that setting is Public). The roster
       carries the SteamIDs directly.
    2. EACH FRIEND's "Game Details" privacy must be Public for the Web API to return
       their games, even with your key. Friends-only is invisible to the API. That is
       what the clipping fallback is for.

  A saved games page under-counts (the community page hides some free and delisted
  titles); the API is the source of truth whenever it works.

  Output: friends_games.json, one object per friend: persona, steamid, fetched,
  source (api|clipping), games[appid, name, playtime_forever (minutes),
  rtime_last_played].

.EXAMPLE
  .\Get-FriendLibraries.ps1 -ApiKey <key>

.EXAMPLE
  .\Get-FriendLibraries.ps1 -FromClippings -ClippingsDir .\clippings
#>
param(
  [string]$ApiKey,
  [switch]$FromClippings,
  [string]$RosterFile = ".\roster.json",
  [string]$OutFile = ".\friends_games.json",
  [string]$ClippingsDir = ".\clippings",
  [int]$SleepMs = 300
)

if (-not $FromClippings -and -not $ApiKey) {
  Write-Error "Pass -ApiKey <key> (https://steamcommunity.com/dev/apikey) or use -FromClippings."
  exit 1
}

function Parse-ClippingFile {
  param([string]$Path)
  $games = @()
  if (-not $Path -or -not (Test-Path $Path)) {
    "  WARNING: clipping not found: $Path"
    return $games
  }
  $text = Get-Content $Path -Raw
  # Shape of a markdown-saved Steam Community games page:
  #   ](https://store.steampowered.com/app/<id>)[<Name>](https://store.steampowered.com/app/<id>) TOTAL PLAYED<n> hours
  # A game with 0 hours has no TOTAL PLAYED segment; that is 0 minutes, not a parse failure.
  $pattern = '\]\(https://store\.steampowered\.com/app/(\d+)\)\[([^\]]+)\]\(https://store\.steampowered\.com/app/\d+\)(?:\s*TOTAL PLAYED([\d,.]+)\s*hours?)?'
  foreach ($g in [regex]::Matches($text, $pattern)) {
    $hours = if ($g.Groups[3].Success) { [double]($g.Groups[3].Value -replace ',', '') } else { 0 }
    $games += [pscustomobject]@{
      appid             = [int]$g.Groups[1].Value
      name              = $g.Groups[2].Value
      playtime_forever  = [int][math]::Round($hours * 60)
      rtime_last_played = 0
    }
  }
  return $games
}

$roster = Get-Content $RosterFile -Raw | ConvertFrom-Json
$results = @()

foreach ($f in $roster) {
  $fetched = (Get-Date).ToString('s')
  $games = @()
  $source = 'clipping'
  $clippingPath = if ($f.clipping) { Join-Path $ClippingsDir $f.clipping } else { $null }

  if ($FromClippings) {
    $games = Parse-ClippingFile -Path $clippingPath
  } else {
    try {
      $url = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=$ApiKey&steamid=$($f.steamid)&include_appinfo=1&include_played_free_games=1&format=json"
      $resp = Invoke-RestMethod $url -TimeoutSec 30
      if ($resp.response.games -and $resp.response.games.Count -gt 0) {
        $games = $resp.response.games | ForEach-Object {
          [pscustomobject]@{
            appid             = $_.appid
            name              = $_.name
            playtime_forever  = $_.playtime_forever
            rtime_last_played = $_.rtime_last_played
          }
        }
        $source = 'api'
      } else {
        "  {0}: API returned 0 games (Game Details not Public?), trying the clipping" -f $f.persona
        $games = Parse-ClippingFile -Path $clippingPath
      }
    } catch {
      "  {0}: API call failed, trying the clipping" -f $f.persona
      $games = Parse-ClippingFile -Path $clippingPath
    }
    Start-Sleep -Milliseconds $SleepMs
  }

  "{0}: {1} games (source: {2})" -f $f.persona, $games.Count, $source
  $results += [pscustomobject]@{
    persona = $f.persona
    steamid = $f.steamid
    fetched = $fetched
    source  = $source
    games   = $games
  }
}

$results | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $OutFile
"DONE: wrote {0} friends to {1}" -f $results.Count, $OutFile
