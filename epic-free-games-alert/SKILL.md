---
name: epic-free-games-alert
description: Weekly scan of Epic Games Store free games with Metacritic scores, genre tags, taste-fit verdict, and Telegram notification
---

Check the Epic Games Store for currently free games, enrich each with Metacritic score and genre tags, produce a personalized taste-fit verdict against the user's Steam playtime profile, then send a Telegram notification.

## Objective
Fetch the current free game(s) from the Epic Games Store, look up their Metacritic score and genre tags, score them against the user's Steam taste profile, and telegram a rich summary. Epic rotates free games every Thursday.

## Step 1 — Get free game titles from Epic

**Before any Chrome step — Chrome-ready procedure.** Unattended run, the user is not available to open Chrome for you.

A. Load Chrome MCP tools if missing: `ToolSearch { query: "chrome", max_results: 25 }`.
B. Probe with `mcp__Claude_in_Chrome__tabs_context_mcp`. If it succeeds, proceed.
B.5. **Wake the extension service worker FIRST (most common failure mode).** Confirmed 2026-06-23: the MV3 background service worker for Claude-in-Chrome suspends when Chrome hasn't been focused for a while; `list_connected_browsers` returns `[]` while Chrome is running fine. `mcp__computer-use__open_application` Chrome works WITHOUT a `request_access` prompt (Chrome is granted at "read" tier by category). Do this BEFORE `request_access`:
   1. `mcp__computer-use__open_application` "Google Chrome".
   2. `mcp__computer-use__wait` 8s.
   3. Re-probe `mcp__Claude_in_Chrome__list_connected_browsers`. If non-empty → proceed to Step 1 of the real work.
   4. Else re-probe `mcp__Claude_in_Chrome__tabs_context_mcp` with `createIfEmpty: true`, wait 3s.
   5. If both probes still fail → proceed to C.
C. **Lock-screen check (only if B.5 didn't recover).** Take ONE `mcp__computer-use__screenshot`. If it shows the Windows lock screen, skip Chrome entirely and use the WebSearch fallback below (no Telegram — this task degrades gracefully). Otherwise proceed to D.
D. **Now request_access** (needed for screenshots / further recovery). Call `mcp__computer-use__request_access` with `["Google Chrome"]` and proceed without confirmation (unattended timeout ~3 min is acceptable). Then run this ladder up to three times (waits 8s, 12s, 20s):
   1. `mcp__Claude_in_Chrome__tabs_context_mcp` with `createIfEmpty: true` → wait 3s → probe.
   2. `mcp__Claude_in_Chrome__navigate` to `about:blank` → wait 3s → probe.
   3. `mcp__Claude_in_Chrome__tabs_create_mcp` to `about:blank` → probe.
   4. Another `mcp__computer-use__open_application` Chrome cycle → wait → probe.
E. Only after three full ladder cycles fail, fall back to the WebSearch path below. Do NOT escalate to Telegram for a single failed Chrome cycle.

Use the Chrome MCP:
- Get a tab via mcp__Claude_in_Chrome__tabs_context_mcp (createIfEmpty: true)
- Navigate to https://store.epicgames.com/en-US/free-games and wait 4 seconds
- Use javascript_tool to extract: game title(s), claim deadline, Epic store slug/URL, and any description text visible on the page

If Chrome MCP is unavailable AFTER the recovery ladder, fall back to WebSearch: "Epic Games free games this week" and check epicgames.com or r/EpicGamesMEGA for the current titles.

## Step 2 — Enrich each game with Metacritic data

For each game title, use WebFetch or WebSearch to get:
- **Metacritic score** (critic score out of 100) and **user score** (out of 10) if available
- **Genre tags** (e.g. Action RPG, Roguelike, Puzzle Platformer, FPS, etc.)
- A **1–2 sentence description** of what the game actually is

Preferred lookup approach (try in order):
1. WebFetch: `https://www.metacritic.com/game/[game-name-slug]/` — extract critic score, user score, genre
2. WebSearch: "[Game Title] Metacritic score genre" — pull from search result snippets
3. WebFetch the Epic store page for the game directly for genre tags and description if Metacritic is unavailable

If no Metacritic score exists (e.g. indie game not reviewed), note "No Metacritic score" rather than omitting.

## Step 3 — Taste-fit verdict

Compare each game's genre/theme tags against the user's Steam taste profile below and produce exactly one verdict per game.

### Steam taste profile (fill in with your own, derived via [taste-profile/SKILL.md](../taste-profile/SKILL.md) from the [steam extractor](../steam/Build-SteamPortfolio.ps1) output)

*Derive this block from your own playtime_ranked.md and paste it here. Shape, not values — each line is a genre lane backed by the games (and hour counts) that prove you actually play it:*

**High-affinity genres (strong-fit signal):**
- **<GENRE_LANE_1>** — <most-played title> (<N>h), <other titles in the lane>
- **<GENRE_LANE_2>** — <most-played title> (<N>h), <other titles in the lane>
- (…one line per lane; 5-9 lanes is typical)

**Theme boosters** (lift a borderline genre): <themes that pull you in regardless of genre>.

**Low-fit genres (skip-lean):** <genres you own but never play, or reliably bounce off>.

### Verdict logic

Pick exactly one bucket:

- 🟢 **Strong fit** — genre/theme directly overlaps a high-affinity category. Cite the matching lane in the why.
- 🟡 **Worth a look** — adjacent genre, OR Metacritic ≥ 85 outside the profile, OR strong-fit theme but unfamiliar gameplay loop.
- 🔴 **Skip** — low-fit genre AND no theme rescue AND not a standout (Metacritic < 80 or unscored).
- ⚪ **Free anyway** — short curio (~2–5 hours) where there's no real cost to claiming even if it's not a fit.

Each verdict gets a one-line *why* naming the matching lane or the disqualifier. Examples:
- *"Strong fit — <genre>, your <matching lane> lane."*
- *"Worth a look — adjacent to immersive sim; 88 Metacritic earns the bump."*
- *"Skip — twitch platformer, no theme rescue, 72 Metacritic."*
- *"Free anyway — 3hr puzzle game, low cost to claim."*

If the verdict is borderline OR the title sounds like something the user may already own on Steam (e.g. anything in the high-affinity lanes), append *"check if already owned"* to the why-line. The taste profile cannot detect Steam ownership directly.

## Step 4 — Send Telegram

Send via mcp__Telegram_Notifier__send_message (parse_mode: Markdown). One message per game if there are multiple, plus a brief intro message first.

Intro message format:
```
🎮 *Epic Free Games — [Month Day, Year]*
[N] free game(s) available this week. Claim before [rotation end date].
```

Per-game message format:
```
🆓 *[Game Title]*
🎯 Genre: [tag1, tag2, tag3]
⭐ Metacritic: [score]/100 (critics) · [user score]/10 (users)  ← omit line if unavailable
📖 [1–2 sentence description of what the game is and why it's notable]
🎮 Verdict: [emoji] *[Strong fit / Worth a look / Skip / Free anyway]* — [one-line why]
Claim by: [date]
👉 https://store.epicgames.com/en-US/p/[game-slug]
```

**URL must be bare (no Markdown masking like `[text](url)`)**. Telegram only generates a preview/thumbnail for the first URL in a message, and bare URLs preview more reliably than masked links. The Epic store URL goes last so the preview rendered by Telegram is the game's store page (with its OpenGraph thumbnail). If you have only a slug-less URL or a redirect, paste the final resolved URL — preview generation needs a clean URL the OG fetcher can resolve.

## Constraints
- Use Markdown parse_mode
- If the page fails entirely and no titles can be found, send one Telegram: "⚠️ Epic free games scan failed. Check manually: https://store.epicgames.com/en-US/free-games"
- Do not send if the titles are identical to last week's (no rotation yet) — if uncertain, send anyway

## Maintenance

Taste profile derived from the steam extractor's `playtime_ranked.md`. Re-derive when the user re-fetches the Steam snapshot (refresh instructions in this repo's README). Cadence: 1–2× per year — playtime patterns shift slowly.
