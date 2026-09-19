<#
.SYNOPSIS
  Join shared_multiplayer.csv with feel_tags.csv and inject the result into the
  page template as its data block, producing ready-check.html.

.DESCRIPTION
  Every row of shared_multiplayer.csv needs a row in feel_tags.csv (matched on
  appid) or it is dropped from the page, so the page never shows a game nobody
  has looked at. Rows whose skip column is non-empty are dropped too: use it
  for local-only co-op, dead servers, or an older edition of a game you also
  own in a newer edition.

  Appids are never typed by hand: they come from the API-sourced CSV, which is
  the only reason every Steam link on the page resolves to the right game.
  (A wrong appid usually still opens SOME store page, so it fails silently.)

  Writes feel_tags.csv with proper quoting when you edit it in a spreadsheet;
  if you hand-edit it in a text editor, quote any field that contains a comma.
  An unquoted comma in a note shifts every later column and the page silently
  loses that game.

.EXAMPLE
  .\Build-PickerPage.ps1 -Me "you"
#>
param(
  [string]$Me           = "me",
  [string]$SharedCsv    = ".\shared_multiplayer.csv",
  [string]$TagsCsv      = ".\feel_tags.csv",
  [string]$RosterFile   = ".\roster.json",
  [string]$TemplateFile = "$PSScriptRoot\ready-check.template.html",
  [string]$OutFile      = ".\ready-check.html"
)

$mp = Import-Csv $SharedCsv
$ft = Import-Csv $TagsCsv
$roster = Get-Content $RosterFile -Raw | ConvertFrom-Json
$personas = @($Me) + @($roster | ForEach-Object { $_.persona })

$tags = @{}
$ft | ForEach-Object { $tags[$_.appid] = $_ }

$untagged = @($mp | Where-Object { -not $tags.ContainsKey($_.appid) })
if ($untagged.Count) { "untagged (dropped from the page): {0}" -f (($untagged | ForEach-Object name) -join ', ') }

$games = foreach ($r in $mp) {
  $t = $tags[$r.appid]
  if (-not $t -or $t.skip) { continue }
  $hours = [ordered]@{}
  foreach ($p in $personas) {
    $v = $r."hours_$p"
    if ($v -and [double]$v -gt 0) { $hours[$p] = [math]::Round([double]$v, 1) }
  }
  [ordered]@{
    appid  = [int]$r.appid
    name   = $t.name
    desc   = $t.desc
    note   = $t.note
    mode   = $t.mode
    length = $t.length
    effort = $t.effort
    teach  = [int]$t.teach_minutes
    owners = @($r.owners -split ';')
    hours  = $hours
  }
}

$data = [ordered]@{
  generated = (Get-Date -Format 'yyyy-MM-dd')
  me        = $Me
  friends   = @($roster | ForEach-Object { [ordered]@{ persona = $_.persona } })
  games     = @($games)
}
$json = $data | ConvertTo-Json -Depth 6 -Compress

$html = Get-Content $TemplateFile -Raw
$block = "/*DATA-START*/`nconst DATA = $json;`n/*DATA-END*/"
$html = [regex]::Replace($html, '/\*DATA-START\*/[\s\S]*?/\*DATA-END\*/', { param($m) $block })
[IO.File]::WriteAllText((Resolve-Path -Path (Split-Path $OutFile -Parent)).Path + '\' + (Split-Path $OutFile -Leaf), $html, (New-Object System.Text.UTF8Encoding $false))
"DONE: {0} games on the page -> {1}" -f @($games).Count, $OutFile
