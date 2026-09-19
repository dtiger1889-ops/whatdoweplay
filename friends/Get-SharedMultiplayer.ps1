<#
.SYNOPSIS
  Build the set of games you share with at least one friend, fetch each one's
  store categories, and keep only the ones with an online-multiplayer category.

.DESCRIPTION
  Inputs:
    owned_games.json    your own library (from ..\steam\Build-SteamPortfolio.ps1)
    friends_games.json  everyone else's (from .\Get-FriendLibraries.ps1)

  Steps:
    1. shared set = every appid you own that at least one friend also owns;
       written in GetOwnedGames shape to shared_set.json.
    2. ..\steam\Get-AppDetails.ps1 fetches genres + categories for that set,
       ONE appid per request (batching silently drops name/genres/categories).
       Roughly 1.3 s per appid, so 200 shared games take about five minutes.
    3. shared_multiplayer.csv: appid, name, genres, cats, owners (semicolon list,
       you first), owner_count, then one hours_<persona> column per person.
       Only rows whose categories include one of: Multi-player, Co-op, Online
       Co-op, PvP, Online PvP, MMO, Cross-Platform Multiplayer.

  "Co-op" alone can mean local-only co-op (shared screen, no online). The
  category filter cannot tell; that is what the mode/skip columns in
  feel_tags.csv are for.

.EXAMPLE
  .\Get-SharedMultiplayer.ps1 -Me "you"
#>
param(
  [string]$Me                = "me",
  [string]$OwnedFile         = ".\owned_games.json",
  [string]$FriendsFile       = ".\friends_games.json",
  [string]$SharedSetFile     = ".\shared_set.json",
  [string]$SharedDetailsStem = "shared_details",
  [string]$OutCsv            = ".\shared_multiplayer.csv",
  [switch]$SkipAppDetails
)

$mpCats = @('Multi-player', 'Co-op', 'Online Co-op', 'PvP', 'Online PvP', 'MMO', 'Cross-Platform Multiplayer')

$owned = (Get-Content $OwnedFile -Raw | ConvertFrom-Json).response.games
$friends = Get-Content $FriendsFile -Raw | ConvertFrom-Json

$ownedById = @{}
foreach ($g in $owned) { $ownedById[[int]$g.appid] = $g }

$friendOwners = @{}
foreach ($f in $friends) {
  foreach ($g in $f.games) {
    $id = [int]$g.appid
    if (-not $friendOwners.ContainsKey($id)) { $friendOwners[$id] = @() }
    $friendOwners[$id] += $f.persona
  }
}

$sharedIds = $ownedById.Keys | Where-Object { $friendOwners.ContainsKey($_) } | Sort-Object
"Shared set: {0} appids" -f $sharedIds.Count

$sharedGames = foreach ($id in $sharedIds) {
  $og = $ownedById[$id]
  [pscustomobject]@{
    appid             = $id
    name              = $og.name
    playtime_forever  = $og.playtime_forever
    rtime_last_played = $og.rtime_last_played
  }
}
[pscustomobject]@{ response = [pscustomobject]@{ game_count = $sharedGames.Count; games = $sharedGames } } |
  ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $SharedSetFile
"Wrote {0}" -f $SharedSetFile

if (-not $SkipAppDetails) {
  & "$PSScriptRoot\..\steam\Get-AppDetails.ps1" -InFile $SharedSetFile -OwnedJson -OutStem $SharedDetailsStem -OutDir (Get-Location).Path
}

$details = Get-Content ".\$SharedDetailsStem.json" -Raw | ConvertFrom-Json
$detailsById = @{}
foreach ($d in $details) { $detailsById[[int]$d.appid] = $d }

$rows = @()
foreach ($id in $sharedIds) {
  $d = $detailsById[$id]
  if (-not $d -or -not $d.cats) { continue }
  $catList = $d.cats -split '\|'
  $hasMp = $false
  foreach ($c in $mpCats) { if ($catList -contains $c) { $hasMp = $true; break } }
  if (-not $hasMp) { continue }

  $owners = @($Me) + $friendOwners[$id]
  $row = [ordered]@{
    appid       = $id
    name        = $d.name
    genres      = $d.genres
    cats        = $d.cats
    owners      = ($owners -join ';')
    owner_count = $owners.Count
  }
  $row["hours_$Me"] = [math]::Round(($ownedById[$id].playtime_forever) / 60, 1)
  foreach ($f in $friends) {
    $fg = $f.games | Where-Object { [int]$_.appid -eq $id } | Select-Object -First 1
    $row["hours_$($f.persona)"] = if ($fg) { [math]::Round($fg.playtime_forever / 60, 1) } else { 0 }
  }
  $rows += [pscustomobject]$row
}

$rows | Sort-Object -Property @{Expression = 'owner_count'; Descending = $true}, name |
  Export-Csv -NoTypeInformation -Encoding utf8 $OutCsv
"DONE: {0} multiplayer rows -> {1}" -f $rows.Count, $OutCsv
