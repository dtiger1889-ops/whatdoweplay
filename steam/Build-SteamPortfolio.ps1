<#
Build-SteamPortfolio.ps1
Fetches your owned-games list from the Steam Web API and builds a playtime-ranked
"preference portfolio" markdown file an AI assistant can use for taste-fit lookups.

Usage:
  .\Build-SteamPortfolio.ps1 -ApiKey <key> -SteamId64 <your SteamID64>

Get a key at https://steamcommunity.com/dev/apikey. Your profile's "Game Details"
privacy setting must be Public for the API to return data. The key is used for one
request; revoke it on the same page afterwards if you don't need it again.
Find your SteamID64 at https://steamid.io/ (paste your profile URL).

Outputs (current directory):
  owned_games.json    raw API response (cache; gitignored by default)
  playtime_ranked.md  the portfolio: games sorted by total playtime
#>
param(
    [Parameter(Mandatory = $true)] [string]$ApiKey,
    [Parameter(Mandatory = $true)] [string]$SteamId64
)

$url = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=$ApiKey&steamid=$SteamId64&include_appinfo=1&include_played_free_games=1&format=json"
$resp = Invoke-RestMethod $url
if (-not $resp.response.games) {
    Write-Error "No games returned. Check the SteamID64 and that your profile's Game Details setting is Public."
    exit 1
}

$resp | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 owned_games.json

$games = $resp.response.games
$played = @($games | Where-Object { $_.playtime_forever -gt 0 } | Sort-Object playtime_forever -Descending)

$lines = @(
    "# Steam library - playtime ranked",
    "",
    "Owned Steam games sorted by total playtime. Generated $(Get-Date -Format yyyy-MM-dd) via IPlayerService/GetOwnedGames.",
    "- Total owned: $($games.Count)",
    "- Played (>0 min): $($played.Count)",
    "",
    "| Hours | Game |",
    "|------:|------|"
)
foreach ($g in $played) {
    $hours = [math]::Round($g.playtime_forever / 60, 1)
    $lines += "| $hours | $($g.name) |"
}
$lines += ""
$lines += "## Unplayed (owned, 0 minutes)"
$lines += ""
foreach ($g in ($games | Where-Object { $_.playtime_forever -eq 0 } | Sort-Object name)) {
    $lines += "- $($g.name)"
}
$lines -join "`n" | Set-Content -Encoding utf8 playtime_ranked.md

Write-Host "Wrote owned_games.json and playtime_ranked.md ($($played.Count) played / $($games.Count) owned)."
Write-Host "Reminder: revoke the API key at https://steamcommunity.com/dev/apikey if you no longer need it."
