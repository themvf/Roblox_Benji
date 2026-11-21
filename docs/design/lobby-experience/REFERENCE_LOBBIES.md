# Reference lobbies: how current Roblox shooters structure lobby and menu UI

Researched 2026-11-17 from public web sources only. Structure and behaviour only; no art reference.

**Confidence tags.** `[C]` Confirmed: official page or patch note, or two or more independent sources agree.
`[R]` Reported: one third-party source. `[U]` Unknown: not established; do not treat as fact.

**Read this first.** Text sources describe *what exists* (destinations, currencies, rotation rules, pass shape)
far better than *where it sits on screen*. Almost no source states nav position, press counts, notification
dots or card layout. Those cells are mostly `[U]`. A 30-minute hands-on capture of each game would settle
them; this document cannot. Fandom wikis refused direct fetches, so Fandom facts below come from search
snippets and are tagged `[R]` unless a second source agrees.

Games covered: RIVALS, Arsenal, Hypershot, Phantom Forces, BloxStrike, BedWars (non-shooter reference).
Frontlines was not researched; BloxStrike was kept but its evidence is the thinnest of the six.

## What the evidence supports

Patterns present in at least three games.

1. **One Play button opens a mode list and matchmakes.** RIVALS, BedWars, Phantom Forces, BloxStrike
   ("Modes", later "Gamemodes"). `[C]` for RIVALS and BedWars, `[R]` for the other two.
2. **Two lobby archetypes, not one.** Walkable 3D hub with physical queue points *plus* a Play button
   (RIVALS, BedWars) versus a menu laid over a running server that you deploy into (Arsenal, Phantom
   Forces; Hypershot appears to be this type). `[C]` for the first four, `[R]` Hypershot.
3. **A soft currency for gameplay unlocks, Robux for bundles and shortcuts.** Keys, BattleBucks,
   coins/gems, credits, Credits, BedCoins. All six. `[C]`
4. **A daily-rotating shop slice.** RIVALS (24 h, per player), Arsenal (8 items, resets 1 AM PST),
   Phantom Forces (daily skins). `[C]` RIVALS and Arsenal, `[R]` Phantom Forces.
5. **Try before you buy for anything that affects gameplay.** RIVALS "Try out for free!" on locked
   weapons; BedWars weekly free kits plus 3-day rentals; Hypershot two free abilities per week.
   `[C]` BedWars, `[R]` RIVALS and Hypershot.
6. **The starting loadout is complete and free; the first match needs no purchase.** RIVALS, Phantom
   Forces, Hypershot, BloxStrike (buys happen in-round). `[C]` RIVALS, `[R]` others.
7. **Slot-based loadouts.** RIVALS four slots; Hypershot four saved loadouts of primary/secondary/melee
   plus three abilities; Phantom Forces primary/secondary/melee. `[C]` RIVALS and Hypershot, `[R]` PF.
8. **Pass = free row plus paid row, levelled by play.** RIVALS (70 tiers, free and Prime), BedWars
   (free and premium, 799 Robux), Arsenal (2020 only, removed). Hypershot runs passes but their shape is
   `[U]`. `[C]` for the three named.
9. **Cosmetics come from cases with rarity tiers.** RIVALS, Arsenal, Hypershot, Phantom Forces,
   BloxStrike. `[C]` Region restrictions on cases are called out for RIVALS and Hypershot. `[C]`
10. **Daily tasks or login rewards are a main-menu surface.** RIVALS daily and streak tasks with login
    rewards; Arsenal daily challenges on the main menu; Hypershot daily rewards and a playtime gift icon
    at the top of the screen. `[C]` RIVALS, `[R]` Arsenal and Hypershot.
11. **Code redemption is a small persistent menu button.** Arsenal gift box bottom-left; Hypershot gift
    button in main menu; RIVALS Reward button inside the shop; BloxStrike "Redeem Code" on the left of
    the main menu. `[C]` Arsenal, `[R]` others.
12. **Mobile gets an editable touch layout.** RIVALS (layout profiles), Arsenal (layout editor, per-button
    settings), BedWars (adjustable button position and size). `[C]` Arsenal, `[R]` RIVALS and BedWars.

## Comparison table

| Topic | RIVALS | Arsenal | Hypershot | Phantom Forces | BloxStrike | BedWars |
|---|---|---|---|---|---|---|
| 1. Lobby type | Walkable hub, 4 areas: Duels, Weapons, Market, Shooting Range `[C]`. Centre of screen `[U]` | Menu over a live match; opened with M `[C]`. Menu character shows selected skin `[R]` | Main menu before spawning `[R]`. Centre `[U]` | Menu then Deploy `[R]`. Active loadout shown as full weapon models since v10 `[R]` | Main menu `[R]`. Centre `[U]` | Walkable hub with NPCs `[C]` |
| 2. Navigation | Play; Weapons (bottom of screen, rifle icon); Shop; Tasks `[R]`. Roblox top bar used for buttons `[C]` | Locker, Shop, Settings, Server Browser, Career Page `[R]`. Position `[U]` | Loadout tab in main menu; Settings on K `[R]`. Position `[U]` | Play, Loadout, Shop `[R]`. Position `[U]` | Modes/Gamemodes, Redeem Code (left) `[R]` | Play button; NPCs; kit displays `[C]` |
| Presses to queued | Walk onto pad, or Play then mode = 2 `[C]` | 0: joins an active match `[R]` | `[U]` | Play, mode; then Deploy or Space `[R]` | Modes then mode tile = 2 `[R]` | Play then mode `[C]`; count `[U]` |
| 3. Persistent readouts | `[U]` beyond top bar and queue UI existing `[C]` | Daily challenges on main menu `[R]` | Gift icon top of screen for playtime rewards `[R]` | `[U]` | `[U]` | "Create Party" button above hotbar; invites bottom-right `[R]` |
| 4. Queue flow | Pad: fills or ready-up, 3 s countdown, same-lobby `[C]`. Play: cross-lobby, all modes `[C]`. Map pick before duel `[C]`. Party system `[C]` | Map and mode vote between rounds; team select screen `[C]`. Event Matchmaking button `[C]` | Public servers, duels 1v1/2v2 `[C]`. Flow `[U]` | Mode select then server; Squad Deploy `[R]` | Mode tile; team select with M; spectate `[R]`. Match-found step `[U]` | Leader queues the party `[R]`. Kit swap and kit shop available pre-match `[C]` |
| 5. Loadout / kit screen | 4 slots `[C]`. Weapon cards, detail view, try-for-free `[R]`. Stat on weapon page `[R]` | Locker with 6 cosmetic categories; inventory search `[C]` | 4 loadouts; select then Edit; Abilities tab `[R]` | Class then weapon; attachments drop down inline `[R]` | Inventory then equip `[R]`. Layout `[U]` | Kit shop opened from lobby kit displays `[R]`; ticket icon rents `[R]` |
| 6. Shop and pass | 6 shop sections; Daily resets 24 h, one item free `[R]`. Pass: 70 tiers, free + Prime `[R]` | Daily Shop, Cases, Bundles tabs; owned items greyed "owned" `[C]`. No pass now `[C]` | Six case tiers; short event passes (about 1 to 2.5 weeks) `[R]` | Daily skins, cases, community loadouts `[R]`. No pass found `[U]` | Cases opened with Credits, no keys `[R]`. Pass `[U]` | Kits 399 to 479 Robux or 10k to 12k BedCoins `[C]`. Seasonal pass paused, event passes instead `[R]` |
| 7. Onboarding | Shooting Range + one-time Beginner Tasks; Beginner 2v2 queue `[C]`. First purchase prompt `[U]` | Dropped straight into a match `[R]` | Free starting ability; `[U]` otherwise | Starts in loadout menu with usable defaults `[R]` | Built-in beginner tutorial `[R]`; codes locked until level 5 `[R]` | `[U]` |
| 8. Mobile / controller | Touch layout profiles; controller layout exists `[R]` | Mobile HUD rebuilt Feb 2026; layout editor; console View button opens menu `[C]` | Gamepad and mobile layouts exist `[R]` | `[U]` | Runs on mobile and console `[R]`; UI differences `[U]` | Adjustable touch buttons `[R]` |
| 9. Praise / complaints | Praised for phone and console play `[R]`. Top-bar buttons once covered the screen (fixed) `[C]` | Mobile UI failed to load for most polled users, May 2025 `[R]`. Mobile push reverted same day, Feb 2026 `[C]` | First pass described as criticised money-maker `[R]` | `[U]` | `[U]` | Pay-to-win debate over kits "unresolved" `[R]` |

## Per-game notes and sources

### RIVALS (Nosniy Games)
- Lobby is walkable and split into Duels, Weapons, Market and Shooting Range; Market holds an NPC and the UGC
  shop. `[R]` [Fandom Lobby page, via search snippet, undated](https://robloxrivals.fandom.com/wiki/Lobby)
- Two ways to queue. Duel Zone pads: step on a pad for a team size; match starts when full or when one side is
  full and the other readies up; players stay in that lobby; only standard duels and 1v1v1/2v2v2; parties do not
  affect pads. Play button: pick a mode, matched across lobbies, lists 1v1 to 5v5, FFA, TDM, ranked and limited
  modes. `[C]` [Miraheze Duels, edited 2026-08-23](https://robloxrivals.miraheze.org/wiki/Duels),
  [Bloxodes gamemodes, 2026-10-21](https://bloxodes.com/wiki/rivals/gamemodes)
- Pad countdown is three seconds once two or more players are present. `[R]`
  [metanew guide, 2026-11-13](https://newgame.co.jp/metaverse/en/roblox/17625359962/rivals/guide/)
- Map is chosen before a standard duel; large maps only at 3v3 and above. `[C]` (same two sources; one says
  "vote", the other "choose").
- Party system and global matchmaking arrived in Update 2; Update 13 "improved top bar & queue UI", made lobby
  NPCs talkable and let private-server owners configure pads. `[C]`
  [Sportskeeda Update 2](https://www.sportskeeda.com/roblox-news/news-roblox-rivals-update-2-global-matchmaking-new-charms-balance-changes),
  [Sportskeeda Update 13](https://hindi3.sportskeeda.com/roblox-news/rivals-update-13-patch-notes)
- Weapons button sits along the bottom of the screen with a rifle icon and is separate from Shop. Locked weapon:
  open its card, open details, "Try out for free!" gives a temporary preview in the practice area; a separate
  button asks for Keys or Robux. `[R]`
  [pixeltwelve, verified 2026-10-02](https://pixeltwelve.com/guides/roblox-rivals-shooting-range-test-weapons)
- Four loadout slots (Primary, Secondary, Melee, Utility); free starters Assault Rifle, Handgun, Fists, Grenade.
  `[C]` [Bloxodes beginner guide, 2026-08-30](https://bloxodes.com/articles/rivals-beginner-guide),
  [rolearn, checked 2026-11-07](https://rolearn.dev/guides/rivals/)
- Shop has six sections: Home, bundles, Daily, Skin Cases, Weapons, Keys. Daily is per-player, resets every
  24 hours, always has at least one free item, and can list items for weapons you do not own. `[R]`
  [Miraheze Shop, edited 2026-08-01](https://robloxrivals.miraheze.org/wiki/Shop). Daily shows five skins priced
  by tier in Robux or 10 Skin Tickets; refreshing costs Keys. `[R]`
  [secretblox, 2026-09-13](https://secretblox.com/rivals)
- Season Pass (Season 4, Update 25, 2026-11-13): 70 tiers, free track and paid Prime track, one level per 25 round
  wins or 20 minutes, capped at 7 levels a week; single levels 99 Robux. Claim flow not described. `[R]`
  [timesaver.gg, updated 2026-11-16](https://timesaver.gg/blog/roblox-rivals-season-4). The official page
  confirms Season 4 and that patch notes live in-game. `[C]` [Roblox page](https://www.roblox.com/games/17625359962/RIVALS)
- Same update added a "Hide Lobby Elements" setting and a rebindable Interact key for lobby holograms. `[R]` (same source)
- Tasks: Beginner (one-time, done in the Shooting Range), Daily (streak), Bonus; Update 22 (2026-09-04) attached
  login rewards to tasks. `[C]` [rolearn](https://rolearn.dev/guides/rivals/), [rivalwiki updates](https://rivalwiki.com/updates)
- Onboarding: Shooting Range, Beginner Tasks that walk through slide, grenade, a Beginner 2v2 duel; a Beginner
  queue for new accounts. `[C]` [Joytify, about July 2026](https://www.joytify.com/blog/en-ph/fps-roblox-rivals-beginner-guide/), Bloxodes
- Conflict: ranked gate is given as level 30 (Miraheze) and level 100 (three other sources). Treat as changed over time.

### Arsenal (ROLVe)
- No walkable lobby. A player joins a running server; the menu is on M and team select on the period key on PC;
  Xbox View opens the menu. Maps and modes are voted between rounds. `[C]`
  [Miraheze Arsenal, edited 2026-11-11](https://arsenal.miraheze.org/wiki/Arsenal)
- Hub destinations listed by the wiki: Shop, Locker, Settings, Server Browser, Career Page, Event Matchmaking. `[R]` (same page)
- Locker equips six categories: Skins, Melees, Kill Effects, Announcers, Taunts, Weapon Skins. `[C]`
  [Miraheze Locker, 2025-12-29](https://arsenal.miraheze.org/wiki/Locker)
- Shop: Daily Shop of 8 items at 600 to 2400 B$, resets daily at 1 AM PST; Cases tab (600 to 1200 B$); Bundles tab
  for Robux. `[C]` [Miraheze Shop, 2025-10-18](https://arsenal.miraheze.org/wiki/Shop)
- Reloaded development log: owned shop items greyed and labelled "owned" (2024-05-25); inventory search
  (2024-05-07); matchmaking sidebar collapsed to a button (2024-05-07); unfinished "Profile" removed from main
  menu (2024-05-03); menu character resets to the equipped skin after a shop preview (2025-05-11); new voting UI
  (2024-06-18). `[C]` [Miraheze dev log](https://arsenal.miraheze.org/wiki/Arsenal_Reloaded_Updates/Development_of_Arsenal_Reloaded)
- 2020 Battle Pass had a free row and a premium row, premium buyable with Robux or BattleBucks; removed
  2020-07-31. `[R]` [Fandom Season Pass / Summer 2020, via snippet](https://robloxarsenal.fandom.com/wiki/Summer_2020)
- 2026: mobile HUD rebuilt, layout editor, per-button settings; pushed live 02-18, reverted the same day for
  bugs, restored 02-20. Promotional tab added to main menu 2026-10-29. Event Matchmaking added 2026-11-09. `[C]`
  [Miraheze update log](https://arsenal.miraheze.org/wiki/Update_Log/Version_History)
- A wider UI, settings and shop overhaul (new shop design, gifting) was announced by a fan news account in
  Feb 2026 and shown in a May 2026 video. Whether it shipped is `[U]`: the 2026 changelog does not mention it.
  [RAN post](https://x.com/RBX_ArsenalNews/status/2018363341660704913), [video, 2026-05-20](https://www.youtube.com/watch?v=SrQKiAjrBCE)
- Code redemption is a gift-box icon bottom-left of the main menu. `[C]` (several code guides, 2026, e.g.
  [allthings.how](https://allthings.how/arsenal-codes/))

### Hypershot
- Loadouts are edited "through the main menu before spawning"; four loadouts per account, each with primary,
  secondary, melee, three abilities, two passives, kill icon. `[C]`
  [Fandom Loadout, via snippet](https://roblox-hypershot.fandom.com/wiki/Loadout),
  [hypershotwiki beginner guide, 2026](https://hypershotwiki.wiki/guide/hypershot-beginner-guide/)
- Flow is main menu, Loadout tab, select a loadout, Edit, Abilities tab. `[R]` (Sportskeeda beginner guide, via snippet)
- Coins buy weapons, gems/diamonds buy abilities; ability prices 6K to 20K. `[C]`
  [OofWiki, 2026-11-09](https://oofwiki.com/hypershot/), hypershotwiki
- Six case tiers from Wooden to Mythical; a setting hides global case-opening notifications (2025-08-01). `[R]`
  hypershotwiki; [DroidGamers, 2025-08-27](https://www.droidgamers.com/guides/hypershot-update-guide/)
- Two abilities are free each week; weekly quests auto-claim. `[R]`
  [metanew guide](https://newgame.co.jp/metaverse/en/roblox/17516596118/hypershot/guide/)
- Playtime rewards claimed from a gift icon at the top of the screen; menu time counts. `[R]` hypershotwiki
- Battle passes are short events: 2026-03-13 to 03-19, 05-02 to 05-09, 10-02 to 10-19. `[R]`
  [Bloxodes, 2026](https://bloxodes.com/wiki/hypershot). Track layout, price and claim flow `[U]`.
- Lobby type, nav position, queue flow for duels: `[U]`. One fan wiki states outright that the official listing
  does not explain them. [hypershot-guide.wiki, 2026-08-02](https://hypershot-guide.wiki/guide/hypershot-roblox)

### Phantom Forces (StyLiS Studios)
- Play button, choose a mode, matchmaking places you in a server; you start in the loadout menu. `[R]`
  [robloxtutorial, 2026-07-07](https://www.robloxtutorial.com/games/phantom-forces/phantom-forces-how-to-play/)
- Choose class and weapon, then press Deploy or Space; Squad Deploy shows teammates. `[R]` (NamuWiki, via snippet)
- Weapons unlock by rank; any weapon can be bought early with credits, cheaper the closer you are to its rank. `[R]`
  (Fandom forum thread, via snippet). A main-menu Shop sells daily-changing skins and community loadouts. `[R]` (same)
- Menu rebuilt in v6.0.0 (with menu scale and aspect commands), rewritten again in 2022, visual overhaul in v10
  with the active loadout shown as full weapon models; v11.0.1 added advanced stats to the menu. `[R]`
  [Fandom change logs, via snippet](https://roblox-phantom-forces.fandom.com/wiki/Change_Log)
- Official page (Fall 2026) confirms cases and loadout customisation only. `[C]`
  [Roblox page](https://www.roblox.com/games/292439477/Phantom-Forces)

### BloxStrike
- No established wiki; all sources are fan sites. Recorded route is main menu, Modes, "Unranked Competitive";
  the same selector shows Defusal and Deathmatch; later footage labels it "Gamemodes". `[R]`
  [bloxstrike.pro, updated 2026-10-16](https://bloxstrike.pro/wiki/ranked/)
- M selects team; Spectate is offered first. `[R]` (guide, via snippet)
- Persistent Credits buy cases and skins; cases need no key; rarities Blue to Gold; skins are tradeable. `[R]`
  [bloxstrike-wiki.wiki, 2026-10-12](https://bloxstrike-wiki.wiki/en/guides/bloxstrike-beginner-guide/),
  [earnaldo, 2026-07-06](https://earnaldo.com/blog/bloxstrike-beginner-guide)
- Weapon choice is an in-round buy menu, so there is no pre-match loadout screen to learn from. `[C]` (both above)
- "Redeem Code" sits on the left of the main menu and is locked until level 5. `[R]`

### BedWars (Easy.gg), non-shooter reference
- Lobby is walkable; NPCs queue for modes, create custom matches and verify accounts; interacting with a kit
  display opens the kit shop; the Play button also lists modes. `[C]`
  [Fandom Lobby, via snippet](https://robloxbedwars.fandom.com/wiki/Lobby), [bedwarsroblox.wiki, 2026-10-06](https://bedwarsroblox.wiki/)
- Party: "Create Party" button above the hotbar, lobby only; invites pop up bottom-right; the leader queues. `[R]`
  [Fandom Party, via snippet](https://robloxbedwars.fandom.com/wiki/Party)
- Since 2025-04-18 kits can be swapped and the kit shop opened pre-match, and kits can be rented with BedCoins. `[C]`
  [Sportskeeda S13](https://www.sportskeeda.com/roblox-news/bedwars-season-13-update-patch-notes),
  [Fandom 2025-04-18, via snippet](https://robloxbedwars.fandom.com/wiki/April_18,_2025)
- Rental: ticket icon on a kit in the kit menu; 1,500 to 3,000 BedCoins; lasts 3 days. `[R]`
  [Fandom Kit Rental Ticket, via snippet](https://robloxbedwars.fandom.com/wiki/Kit_Rental_Ticket)
- Buy price is shown in both currencies: 399 Robux or 10,000 BedCoins; newer kits 479 or 12,000. `[C]` (Fandom Kit, earnaldo)
- Kit Fusion mode gives a 30-second window at match load to pick two kits. `[R]` [rbxbedwars.com](https://rbxbedwars.com/kit-fusion)
- Pass: free and premium rows, 799 Robux, some free tiers empty; pass ownership or Discord verification gives
  +20% XP. `[C]` [Fandom Battle Pass S13, via snippet](https://robloxbedwars.fandom.com/wiki/Battle_Pass/Season_13),
  [Sportskeeda S12](https://www.sportskeeda.com/roblox-news/bedwars-season-12-battlepass-all-rewards-premium-pass-price)
- Seasonal pass paused after Season 13 (Aug 2025) in favour of event passes; weekly free-kit rotation is the
  studio's answer to pay-to-win complaints, which the writer calls unresolved. `[R]`
  [RoWatcher, early 2026](https://rowatcher.com/news/bedwars-in-2026-can-easy-gg-s-kit-machine-outlast-rivals)

## Patterns worth adopting

- **Two routes to a match, one obvious.** A Play button that lists modes, with physical queue points in the hub
  as the social route (RIVALS, BedWars). Keep press count at two: Play, mode.
- **Queue point rules that are legible:** fills, or one side full and the other readies, then a short countdown (RIVALS).
- **Let the kit be changed after the match is found.** BedWars added pre-match kit swap and pre-match shop access
  in 2025; Kit Fusion uses a fixed 30-second pick window.
- **Try-before-buy on every gameplay item.** Free preview (RIVALS), short rental (BedWars), weekly free rotation
  (BedWars, Hypershot). This is also the stated defence against pay-to-win complaints.
- **Separate the gameplay inventory from the store.** RIVALS keeps Weapons and Shop as different buttons;
  Arsenal keeps Locker and Shop apart.
- **Show both prices on one item** when a soft currency and Robux both apply (BedWars kits, RIVALS daily skins).
- **Mark owned items in the shop** rather than hiding them (Arsenal: greyed, "owned").
- **Reset previews.** After previewing a shop item on the menu character, return to the equipped one (Arsenal fix, 2025).
- **Daily shop with a stated reset time and one free item** (Arsenal 1 AM PST; RIVALS one free item per day).
- **Onboarding as a short task list in a practice space**, paid in the unlock currency, ending in a protected
  beginner queue (RIVALS). No source shows a purchase prompt inside this flow.
- **Ship a touch layout editor** and treat it as its own release (Arsenal, RIVALS).
- **A setting to hide lobby clutter** (RIVALS "Hide Lobby Elements"; Hypershot toggle for global case notifications).

## Patterns to avoid

- **Shipping unfinished destinations.** Arsenal removed a "Profile" entry because it was not done.
- **Top-bar buttons without a size guard.** RIVALS shipped a bug where they covered the whole screen.
- **Leaving a queue that does not release.** RIVALS fixed pads that kept players queued after stepping off.
- **Daily shop items the player cannot use.** RIVALS lists daily items for unowned weapons; flag or filter them.
- **Empty free-track tiers.** BedWars free rows had tiers with nothing; press coverage called it out.
- **Gameplay power sold permanently with no free path.** The BedWars kit debate is the cautionary case.
- **Mobile UI pushed without a rollback plan.** Arsenal reverted a mobile release the same day in Feb 2026.

## What could not be established

- Nav placement (left rail, bottom bar, top tabs) for every game except single-source hints for RIVALS
  (Weapons at bottom) and BloxStrike/Arsenal (code button on the left).
- What fills the centre of the menu screen in RIVALS, Hypershot and BloxStrike.
- Persistent readouts: which currencies, level or XP bars and notification dots stay on screen, for all six.
- Whether any game lets you browse menus while queued, and any "match found / accept" step.
- Weapon or kit screen layout: grid versus list, stat bars, whether equip and buy share one button, how locked
  cards look. Only the flow is documented, not the layout.
- Pass track layout, claim-all, and timer presentation for every game.
- When the first purchase prompt appears in a new player's session, for all six.
- Controller-specific menu navigation, other than Arsenal's menu button.
- Hypershot's lobby type and duel queue flow.
- Whether Arsenal's 2026 UI and shop overhaul is live.
- Player sentiment about lobby or menu UI specifically. Searches returned monetisation complaints, not UI ones.
- Phantom Forces' current menu in any detail; all evidence is change-log snippets and one 2026 guide.
