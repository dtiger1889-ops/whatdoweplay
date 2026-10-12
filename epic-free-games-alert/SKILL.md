---
name: epic-free-games-alert
description: Check currently free Epic Games Store games, add review scores and genre tags, and judge fit against a configured playtime profile. Use when asked for the free-games scan or invoked by an already configured weekly task; send Telegram only through the user's configured channel.
---

Check the Epic Games Store for currently free games, enrich each with Metacritic score and genre tags, produce a personalized taste-fit verdict against the user's Steam playtime profile, then send a Telegram notification.

## Prerequisites
Use the user's configured private taste profile and authorized Telegram destination.
If the profile is still a placeholder, report the games without personal verdicts and
point to [taste-profile/SKILL.md](../taste-profile/SKILL.md). If Telegram is not configured
or authorized, return the summary in the session. This skill does not create a schedule.

## Step 1 — Get free game titles from Epic

**Before any Chrome step — Chrome-ready procedure.** Unattended run, the user is not available to open Chrome for you.

A. Load Chrome MCP tools if missing: `ToolSearch { query: "chrome", max_results: 25 }`.
B. Probe with `mcp__Claude_in_Chrome__tabs_context_mcp`. If it succeeds, proceed.
B.5. **If the connection probe fails, try opening Chrome once** using available computer-use tools, without restarting it or closing existing tabs:
   1. `mcp__computer-use__open_application` "Google Chrome".
   2. `mcp__computer-use__wait` 8s.
   3. Re-probe `mcp__Claude_in_Chrome__list_connected_browsers`. If non-empty → proceed to Step 1 of the real work.
   4. Else re-probe `mcp__Claude_in_Chrome__tabs_context_mcp` with `createIfEmpty: true`, wait 3s.
   5. If both probes still fail → proceed to C.
C. **If B.5 did not recover**, inspect one screenshot when available. If it shows a locked desktop, use the web-search fallback. Do not attempt to unlock it.
D. If computer-use access is available without a pending user prompt, try the following
recovery sequence up to three times (waits 8s, 12s, 20s). If access requires approval
during an unattended run, skip recovery and use web search:
   1. `mcp__Claude_in_Chrome__tabs_context_mcp` with `createIfEmpty: true` → wait 3s → probe.
   2. `mcp__Claude_in_Chrome__navigate` to `about:blank` → wait 3s → probe.
   3. `mcp__Claude_in_Chrome__tabs_create_mcp` to `about:blank` → probe.
   4. Another `mcp__computer-use__open_application` Chrome cycle → wait → probe.
E. If recovery fails or the necessary tools are unavailable, use the WebSearch path below. Report only a failure that prevents retrieval, not each failed browser probe.

Use the Chrome MCP:
- Get a tab via mcp__Claude_in_Chrome__tabs_context_mcp (createIfEmpty: true)
- Navigate to https://store.epicgames.com/en-US/free-games and wait 4 seconds
- Use javascript_tool to extract: game title(s), claim deadline, Epic store slug/URL, and any description text visible on the page

If Chrome MCP is unavailable, search for the current titles and verify them against
Epic's official store. Confirm claim deadlines and distinguish giveaways from permanently
free-to-play games. If a title or deadline cannot be verified, label it unconfirmed.

## Step 2 — Enrich each game with Metacritic data

For each game title, use WebFetch or WebSearch to get:
- **Metacritic score** (critic score out of 100) and **user score** (out of 10) if available
- **Genre tags** (e.g. Action RPG, Roguelike, Puzzle Platformer, FPS, etc.)
- A **1–2 sentence description** of what the game actually is

Preferred lookup approach (try in order):
1. WebFetch: `https://www.metacritic.com/game/[game-name-slug]/` — extract critic score, user score, genre
2. WebSearch: "[Game Title] Metacritic score genre" — open the Metacritic result to verify the platform, score, and review count; do not rely only on snippets
3. WebFetch the Epic store page for the game directly for genre tags and description if Metacritic is unavailable

If no Metacritic score exists (e.g. indie game not reviewed), note "No Metacritic score" rather than omitting.

## Step 3 — Taste-fit verdict

Compare each game's genre/theme tags against the user's Steam taste profile below and produce exactly one verdict per game.

### Steam taste profile (fill in with your own, derived via [taste-profile/SKILL.md](../taste-profile/SKILL.md) from the [steam extractor](../steam/Build-SteamPortfolio.ps1) output)

*Derive this block from your own playtime_ranked.md and paste it here. Shape, not values — each line is a genre lane backed by the games (and hour counts) that prove you actually play it:*

**High-affinity genres (strong-fit signal):**
- **<GENRE_LANE_1>** — <most-played title> (<N>h), <other titles in the lane>
- **<GENRE_LANE_2>** — <most-played title> (<N>h), <other titles in the lane>
- (…one line per supported lane)

**Theme boosters** (lift a borderline genre): <themes that pull you in regardless of genre>.

**Low-fit genres (skip-lean):** <genres you own but never play, or reliably bounce off>.

### Verdict logic

Pick exactly one bucket:

- 🟢 **Strong fit** — genre/theme directly overlaps a high-affinity category. Cite the matching lane in the why.
- 🟡 **Worth a look** — adjacent genre, Metacritic ≥ 85 outside the profile, or strong-fit theme but unfamiliar gameplay loop. The score is a standout heuristic, not evidence of personal fit.
- 🔴 **Skip** — low-fit genre AND no theme rescue AND not a standout (Metacritic < 80 or unscored).
- ⚪ **Free anyway** — short curio outside the profile that may be worth claiming; claiming and choosing to spend time playing are separate decisions.

Each verdict gets a one-line *why* naming the matching lane or disqualifier. Cite the
source when a score or expected play length influences the verdict.

If the verdict is borderline OR the title sounds like something the user may already own on Steam (e.g. anything in the high-affinity lanes), append *"check if already owned"* to the why-line. The taste profile cannot detect Steam ownership directly.

## Step 4 — Send Telegram

When the user has authorized the configured Telegram channel, send via
mcp__Telegram_Notifier__send_message (parse_mode: Markdown). One message per game if there
are multiple, plus a brief intro message first. If unavailable, return the contents in
the final response; do not create another delivery route.

Intro message format:
```
🎮 *Epic Free Games — [Month Day, Year]*
[N] free game(s) available this week. Claim before [rotation end date].
```

Per-game message format:
```
🆓 *[Game Title]*
🎯 Genre: [tag1, tag2, tag3]
⭐ Metacritic: [score]/100 (critics) · [user score]/10 (users)
📖 [1–2 sentence description of what the game is and why it's notable]
🎮 Verdict: [emoji] *[Strong fit / Worth a look / Skip / Free anyway]* — [one-line why]
Claim by: [date]
👉 https://store.epicgames.com/en-US/p/[game-slug]
```

Put the resolved Epic store URL last as a bare link. Avoid placing unrelated URLs
before it; the store page is the intended preview target.

Use `No Metacritic score` or `user score unavailable` for missing values. Do not promise
that Telegram will generate a preview.

## Constraints
- Use Markdown parse_mode
- If the page fails entirely and no titles can be found, report the failed scan with https://store.epicgames.com/en-US/free-games. Send through Telegram only when the user has authorized the configured channel; otherwise return the report in the current session.
- Do not send if the titles are identical to last week's (no rotation yet) — if uncertain, send anyway

## Maintenance

Taste profile derived from the steam extractor's `playtime_ranked.md`. Re-derive when
the user refreshes the snapshot or changes their preferences (see this repo's README).
