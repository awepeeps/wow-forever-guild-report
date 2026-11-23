# Researched, not implemented

Features that were investigated and deliberately tabled. Re-check the listed
sources before reopening one; the reason may have changed.

## Calendar: holidays, BG weekends and guild events

Researched 2026-11-23. Tabled because no supported API exposes the data.

**Goal.** Show the server's holiday events and battleground weekends (and
possibly guild calendar events) in the export.

**Why not.**

- Blizzard's Battle.net Web API has no calendar, holiday, world-event or guild
  event endpoint for any WoW flavor. The documented guild routes are guild,
  activity, achievements and roster
  ([Profile APIs](https://develop.battle.net/documentation/world-of-warcraft/profile-apis),
  [Game Data APIs](https://develop.battle.net/documentation/world-of-warcraft/game-data-apis)).
  Guild Activity is a past achievement/boss-kill feed, not a schedule.
- Forever has no published API docs. The community Forever client
  ([guild](https://github.com/Pinta365/blizzard_api/blob/0f66238c7a4e4269cfcd37c19c76fe6062d9f4ba/src/wow_forever/guild.ts),
  [game data](https://github.com/Pinta365/blizzard_api/blob/0f66238c7a4e4269cfcd37c19c76fe6062d9f4ba/src/wow_forever/game_data.ts))
  and the [forum probing thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
  found no holiday, event or calendar route. This is "not found", not
  "documented absent".
- A Blizzard developer said in 2020 that a calendar API was "on our radar"
  ([forum reply](https://us.forums.blizzard.com/en/blizzard/t/request-wow-calendar-api/11704/2));
  nothing has shipped since.
- Holidays reach the game client through the in-game `C_Calendar` API, but the
  Forever client disables the calendar UI behind
  `Enum.GameRule.IngameCalendarDisabled`
  ([GameTime.lua](https://github.com/Ketho/wow-ui-source-forever/blob/forever/Interface/AddOns/Blizzard_Minimap/Mainline/GameTime.lua)).
  Whether `C_Calendar` still returns holidays on Forever is untested.
- Holidays and BG-weekend rotations are region-wide, not per server; whether
  Forever runs BG weekends at all is unconfirmed.

**Alternatives rejected.**

- Scraping Wowhead/ForeverDB or Armory HTML: not a supported API and contrary
  to this project's API-only rule.
- An in-game addon writing SavedVariables for the CLI to parse: permitted by
  Blizzard's addon policy, but needs someone to log in (data is written only on
  logout or `/reload`), and Forever may not supply calendar data at all.
- A hand-maintained private schedule in the roster config: reliable but manual;
  not what was wanted.
- Third-party schedulers for guild events (Raid-Helper
  `/api/v4/servers/{id}/events`, Discord scheduled events, sesh, ForeverDB):
  have APIs but cover guild-created events only, not Blizzard holidays, and
  each needs a new secret.

**Reopen if** Blizzard documents a calendar/holiday endpoint (check the
developer portal and the Forever forum thread), or the guild adopts a
scheduler whose events should appear in the export.
