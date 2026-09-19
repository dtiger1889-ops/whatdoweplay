# whatdoweplay

A Steam companion for the two questions that actually come up: **"would I play this?"** (during a sale, for a free claim, for a gift) and **"what do we play tonight?"** (when three friends are on Discord and nobody wants to pick). Both answered from real playtime and real ownership, not from review scores.

Formerly `game-sale-scout`; the old URL redirects.

## What is in the box

| Piece | What it does |
|---|---|
| [steam/Build-SteamPortfolio.ps1](steam/Build-SteamPortfolio.ps1) | Fetches your Steam library via the Web API and writes `playtime_ranked.md`: every owned game ranked by hours. The raw evidence for everything else. |
| [steam/Get-AppDetails.ps1](steam/Get-AppDetails.ps1) | Store details for a list of appids: genres, categories (where "Online Co-op" and "Shared/Split Screen" live), Metacritic, live price. One appid per request, on purpose (see gotchas). |
| [taste-profile/SKILL.md](taste-profile/SKILL.md) | The agent skill: distills playtime into a compact taste profile (high-affinity lanes, theme boosters, skip-lean genres, known bounces) and judges any game on any platform against it. |
| [epic-free-games-alert/SKILL.md](epic-free-games-alert/SKILL.md) | The scheduled version: a weekly unattended run that scores Epic's free games against the profile and pushes verdicts via Telegram. |
| [friends/](friends/) | **Friends night.** Builds the set of games you share with named friends, keeps the ones with online multiplayer, and renders *Ready Check*: tick who is on, say how much night you have, get three games everyone present can launch right now. |

## Friends night, end to end

1. **Your own library** (once): `.\steam\Build-SteamPortfolio.ps1 -ApiKey <key> -SteamId64 <yours>` in `friends/` (or copy the resulting `owned_games.json` there).
2. **Roster**: `friends/roster.json`, a JSON array of `{ "persona": "<display name>", "steamid": "<their SteamID64>", "clipping": "<optional markdown export filename>" }`. The file is gitignored: it names real people.
3. **Their libraries**: `.\Get-FriendLibraries.ps1 -ApiKey <key>` writes `friends_games.json`. A friend whose *Game Details* privacy is not Public returns 0 games; if you saved their public games page as markdown into `friends/clippings/`, the script falls back to that automatically.
4. **Shared multiplayer set**: `.\Get-SharedMultiplayer.ps1 -Me "<your display name>"` writes `shared_multiplayer.csv`: every game you and at least one friend own that carries an online-multiplayer category, with hours per person. About five minutes per 200 shared games.
5. **Feel tags, by hand**: copy `feel_tags.template.csv` to `feel_tags.csv` and give every row of `shared_multiplayer.csv` a line. This is the step no API can do for you, and it is where the picker gets its judgment:

   | column | values | meaning |
   |---|---|---|
   | `mode` | `coop` / `versus` / `both` | together against the game, against each other, or either |
   | `length` | `short` / `medium` / `long` | fits in 45 minutes / about 90 / a whole evening |
   | `effort` | `low` / `medium` / `high` | brain off / some attention / everyone needs the wiki open |
   | `teach_minutes` | integer | how long until a newcomer is actually playing |
   | `desc` | one line | what the game IS (the page shows it; nobody remembers why they own half their library) |
   | `note` | one line | why it fits a group, or what to watch for (dead servers, two-player cap) |
   | `skip` | empty or a reason | non-empty hides the row: local-only co-op, servers shut down, an older edition of a game you also own newer |

   Seed `mode` from the categories (Co-op only, PvP only, both) and `length`/`effort` from genre (strategy and simulation lean long and high; casual and party lean short and low), then correct every row against what the game actually is. The seed is wrong often enough that skipping the read-through shows on the page within a week.
6. **Build the page**: `.\Build-PickerPage.ps1 -Me "<your display name>"` writes `ready-check.html`, a single self-contained file. Host it anywhere static, or open it from disk; the group can share one link.

Rebuild = rerun 3, 4 and 6. Fix a tag by editing `feel_tags.csv` and rerunning 6.

### How the page ranks

Filter first: only games every ticked person owns; mode, length and effort as set (short fits any session, medium needs an hour, long needs two; brain-off shows low-effort only). Then rank by the group's combined hours ("safe bet") or by the fewest ("something new"). Three picks, because a group has to agree and a longer list turns back into browsing; "Show all" is there for when you want the whole overlap. Time and brain both have an "Any".

The page opens with everyone ticked. With a large roster that overlap can be one or two games; that is the real shape of the data, not a bug, and unticking one person usually opens it up.

## Gotchas that cost real time

- **Two privacy layers.** Your own *Friends List* setting gates `GetFriendList` (401 otherwise), which is why nothing here calls it: the roster carries SteamIDs. Each friend's *Game Details* setting gates whether the API returns their games at all, even with your key; friends-only is invisible. Hence the saved-page fallback.
- **Saved games pages under-count.** The community page omits some free and delisted titles (one library came back 753 from the saved page and 878 from the API). The API is the source of truth wherever it works.
- **One appid per `appdetails` request.** Comma-separating appids returns only prices and silently drops name, genres and categories. It looks like an optimisation and is not.
- **Keyless wishlist calls return 0 items and report success.** If a wishlist comes back empty, that is the bug, not the wishlist.
- **The `metacritic` field in `appdetails` is badly under-reported.** Check Metacritic directly for anything that matters, and show Steam review percentages with their review counts; 90% on 300 reviews and 94% on 13,000 are different claims.
- **An unquoted comma in `feel_tags.csv` shifts every later column** and the page silently loses that game. The first build of this lost 15 of 89 games that way and looked fine until the counts were checked.
- **A wrong appid usually still opens a store page** (Steam redirects demo and DLC ids to a parent), so a hand-typed id fails silently. Never type one; every appid on the page comes from the API-sourced CSV.
- **"Co-op" in Steam categories includes local-only co-op.** The category filter keeps those; the `skip` column is where you drop them.

## Privacy

Everything generated under `friends/` describes real people's libraries and hours and is gitignored: `roster.json`, `clippings/`, `friends_games.json`, `shared_*`, `feel_tags.csv`, and the built `ready-check.html`. The template ships empty. Your own `owned_games.json` and `playtime_ranked.md` are gitignored too.

The Web API key is used at run time and never written anywhere; revoke it at https://steamcommunity.com/dev/apikey if you do not need it again.

## License

MIT. See [LICENSE](LICENSE).
