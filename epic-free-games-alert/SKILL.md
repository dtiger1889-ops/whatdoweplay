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

## Step 1 — Get every currently free title from Epic

One keyless request, no browser: opening a browser to read the store page costs memory, and
from an unattended background session it can leave an invisible browser holding the user's
profile.

```bash
curl -s --max-time 20 'https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=US&allowCountries=US'
```

Walk the whole array at `data.Catalog.searchStore.elements[]`; it holds current AND
upcoming promotions, and the first element is often not a free game. For each element:
- **Free right now** = `promotions.promotionalOffers` is non-empty, its window is active
  (`startDate` ≤ now < `endDate`), and `price.totalPrice.discountPrice == 0`. Title is
  `title`; the giveaway ends at `promotions.promotionalOffers[0].promotionalOffers[0].endDate`;
  the store slug is `productSlug` (fall back to `catalogNs.mappings[0].pageSlug`, then `urlSlug`).
- **Upcoming** = `promotions.upcomingPromotionalOffers` is non-empty; it starts at
  `promotions.upcomingPromotionalOffers[0].promotionalOffers[0].startDate`.

Dedupe by title/slug (Epic sometimes lists a base game and an edition), handle any count
(two is normal), and run every distinct free-right-now title through Steps 2–4. List
upcoming titles in one heads-up line at the end, without enrichment.

If the request fails or finds no free-right-now title, report that once with the link
https://store.epicgames.com/en-US/free-games and stop.

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
