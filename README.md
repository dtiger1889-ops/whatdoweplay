# game-sale-scout

Help an AI agent answer the only question that matters during a game sale: **"would I actually play this?"** — using your real playtime history instead of guesses.

Three pieces, one loop:

| Piece | What it does |
|---|---|
| [steam/Build-SteamPortfolio.ps1](steam/Build-SteamPortfolio.ps1) | Fetches your Steam library via the Steam Web API and writes `playtime_ranked.md` — every owned game ranked by hours. The raw evidence. |
| [taste-profile/SKILL.md](taste-profile/SKILL.md) | The agent skill: distills the playtime data into a compact taste profile (high-affinity genre lanes, theme boosters, skip-lean genres), then judges **any game on any platform** against it — sale triage, free claims, bundles, backlog picks. |
| [epic-free-games-alert/SKILL.md](epic-free-games-alert/SKILL.md) | The scheduled version: a weekly unattended run that scores Epic's free games against the profile and pushes taste-fit verdicts via Telegram. |

Steam is the richest data source (the API hands you exact hours), but the profile itself is platform-agnostic — the skill documents fallbacks for console libraries or plain recall, and the verdicts apply to anything with a store page.

## Quickstart

1. **Extract** (Steam):
   ```powershell
   .\steam\Build-SteamPortfolio.ps1 -ApiKey <key> -SteamId64 <your SteamID64>
   ```
   API key: https://steamcommunity.com/dev/apikey (one fetch; revoke after if you don't need it again — never commit it). SteamID64: paste your profile URL into https://steamid.io/. Your profile's **Game Details** privacy setting must be Public.
2. **Derive**: give your agent `playtime_ranked.md` and [taste-profile/SKILL.md](taste-profile/SKILL.md); it produces the standing profile block.
3. **Use**: ask "would I like X?" any time, and/or schedule the Epic task with the profile pasted in.

## Privacy note

The generated files (`owned_games.json`, `playtime_ranked.md`) describe your gaming habits; both are gitignored by default — commit them only if you're comfortable with that being public. The derived profile block is more abstract but still yours to place.

## License

MIT. See [LICENSE](LICENSE).
