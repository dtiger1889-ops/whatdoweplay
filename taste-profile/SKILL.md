---
name: taste-profile
description: Build and apply a personal game-taste profile derived from real playtime data. Answers "would I like this game?" for any title on any platform — sale triage, free-game claims, gift ideas, backlog picks.
---

Turn the user's real play history into a standing **taste profile**, then judge any game against it. Platform-agnostic: the profile is derived from playtime evidence wherever it lives (Steam, console library, Epic, GOG, a hand-written list); the verdicts apply to any title on any storefront.

Use playtime as evidence of repeated choices, alongside the user's stated likes and
dislikes. Low playtime alone does not prove dislike: note unfinished games, shared
accounts, idle hours, and gaps in platform coverage.

## Part 1 — Build (or rebuild) the profile

Build when no profile exists; rebuild when the user refreshes the data or says their
preferences have changed. Do not create a recurring task.

**Input:** a playtime-ranked list of owned games. Sources, best first:
1. **Steam** — run [`steam/Build-SteamPortfolio.ps1`](../steam/Build-SteamPortfolio.ps1) (this repo); it outputs `playtime_ranked.md` from the Steam Web API.
2. **Any other platform with playtime stats** (console activity, GOG Galaxy) — export or transcribe the most-played games and hour counts, including enough variety to show the main patterns.
3. **No stats available** — ask the user to list their most-played games with rough hours from memory; mark the profile `source: recall` so future sessions know its confidence tier.

**Derivation:** read the ranked list and produce this block (shape, not values — every lane must be backed by named games and hour counts from the input):

```
## Taste profile — <user> (derived <YYYY-MM-DD> from <source>)

**High-affinity genres (strong-fit signal):**
- <GENRE_LANE_1> — <most-played title> (<N>h), <other titles in the lane>
- <GENRE_LANE_2> — ...
(Group only patterns the evidence supports; mark a lane inferred from one title as tentative.)

**Theme boosters** (lift a borderline genre): <themes that pull the user in regardless of genre>

**Low-fit genres (skip-lean):** <genres owned but barely played, or reliably bounced off>

**Confidence notes:** <anything that skews the data — shared account, kids' games, a platform not covered>
```

Save the block wherever the user keeps standing agent context (a skill file, a notes vault, a recurring-task prompt). It is deliberately compact: the point is that any future session — or any scheduled task — can paste it and score games without re-reading the library.

## Part 2 — Apply the profile (any game, any platform, any time)

When the user asks about a game — "would I like X?", "is this bundle worth it?", "what should I grab from the sale?" — produce exactly one verdict per title:

- 🟢 **Strong fit** — genre/theme directly overlaps a high-affinity lane. Cite the lane.
- 🟡 **Worth a look** — adjacent genre, strong-fit theme on an unfamiliar gameplay loop, or a critical standout outside the profile. A critic score of 85/100 can flag a standout; it does not establish personal fit.
- 🔴 **Skip** — low-fit genre AND no theme rescue AND not a critical standout.
- ⚪ **Cheap anyway** — short curio outside the profile whose price or free claim makes it worth considering; distinguish claiming from choosing to spend time playing.

Rules that keep verdicts honest:
- Every verdict gets a one-line *why* naming the matching lane or the disqualifier — never a bare emoji.
- Look up the game's actual gameplay, genre, and current reviews before judging; don't guess from the title. Name the score source and scale when citing a score.
- Sale math belongs in the why when the user asked about a sale: an off-profile 🟡 at −90% reads differently than at −20%.
- The profile cannot see current ownership — for anything in a high-affinity lane, append *"check if already owned."*
- If the user explains a preference that changes the verdict, update the private profile to reflect that preference. Do not turn disagreement about one title into a universal genre rule.

## Companion automation

[`epic-free-games-alert`](../epic-free-games-alert/SKILL.md) (this repo) is the scheduled version of Part 2: it scores each week's free Epic games against this profile unattended and pushes verdicts via Telegram.
