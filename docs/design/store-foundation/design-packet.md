# Store foundation — design packet

Status: G0 ready for review, G1 in progress (no visuals yet, three product choices open). Nothing is implemented. · Owner: Claude (author only; no independent review) · Updated: 2026-11-16

Request: monetize the game. This packet covers only the layer every later sale depends on: taking a Roblox purchase, granting it exactly once, remembering what a player owns, and refusing to equip what they do not own. The shop screen, battle pass, subscription, ads and Roblox Plus prompt each get their own packet on top of this one.

Target model (user direction, 2026-11-16): monetize like Rivals and BedWars. Both sell gameplay content as well as cosmetics, and both let players earn that content by playing:

| | Rivals | BedWars | This game's equivalent |
| --- | --- | --- | --- |
| Earnable currency that can also be bought | Keys | BedCoins | Credits (the wallet in this packet) |
| Gameplay content unlocked with it | Weapons | Kits | Weapons (16 exist) and alter egos (1 exists: Titan) |
| Random cosmetic boxes | Skin cases, wrap boxes, charm capsules | Lucky crates | Skin cases (later packet; needs odds disclosure) |
| Season track | Season pass, grants Skin Tickets | Battle pass | Battle pass on the existing XP curve (later packet) |
| Try before buying | — | Weekly free kit rotation | Weekly free weapon/alter-ego rotation |
| Direct Robux sales | Bundles, daily shop | Kits, pass | Bundles, daily shop (later packet) |

Details of both games come from third-party guides of mixed dates ([Rivals keys](https://timesaver.gg/blog/how-to-get-keys-in-roblox-rivals), [Rivals unlocks](https://sportskeeda.com/roblox-news/how-unlock-weapons-skins-roblox-rivals), [BedWars kits](https://bloxodes.com/wiki/bedwars/kits), [BedWars season 13 notes](https://www.sportskeeda.com/roblox-news/bedwars-season-13-update-patch-notes)). Check prices in the live games before copying any number.

References: [developer products](https://create.roblox.com/docs/production/monetization/developer-products), [Roblox Plus](https://create.roblox.com/docs/production/monetization/roblox-plus), [managed pricing](https://create.roblox.com/docs/production/monetization/managed-pricing), [paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items).

## 1. Identity and intent

| Required question | Answer / evidence |
| --- | --- |
| Map, mode, or shared feature? ID and display name? | **Decided.** Shared feature. Internal ID `store-foundation`; services `StoreService` / `StoreController`. No player-facing name; players see "Locked", a price and "Buy". |
| Which modes/maps must it support? Authoritative spec? | **Decided.** All of them, because it never touches a match. Purchases are offered in the lobby only. This packet is the spec. |
| Player fantasy and repeatable decision? | **Decided.** "I want that skin, I tap it, I own it, it is still mine tomorrow." The repeatable decision is which cosmetic to buy next. |
| Who is it for, which devices? | **Decided.** Every player on phone, tablet, desktop and console. Roblox draws the payment prompt itself; our UI is the locked state and the result message. |
| Roster, session length, test preset? | **Not applicable** to a match. Test preset: one player in Studio (purchases there are free test purchases), then two players on a private published server. |
| Authorized / out of scope? | **Decided.** Authorized: this packet. Out of scope: shop screen, Credit earn rates and prices, battle pass, subscription, ads, Roblox Plus prompt, loot crates, gifting, trading, creating products in Creator Hub, publishing. |
| Baseline source/build/tuning? | **Decided.** Branch `claude/mymap-rotation-and-training` at `57c5264` with uncommitted local changes. No purchase code exists (`MarketplaceService` appears nowhere in `src`). |
| What problem will the player notice is fixed? | **Decided.** None yet for players: today every cosmetic is free. The owner's problem is that the game cannot earn. |

### Baseline findings that shape the design

- **Every cosmetic is free to equip.** [SkinService.lua:324](../../../src/server/Services/SkinService.lua:324) accepts any registered skin. [CharacterSkinService.lua:22](../../../src/server/Services/CharacterSkinService.lua:22), the celebration favourites and the alter-ego choice do the same. There is no ownership concept to extend.
- **Catalog size today:** 50 tiered cosmetics across weapon skins and celebrations: 17 Common, 13 Uncommon, 16 Rare, 2 Legendary, 2 Mythical.
- **Persistence is ProfileStore** ([DataService.lua](../../../src/server/Services/DataService.lua)), one profile per player with session locking. Data reaches the profile by mirroring player attributes. That is fine for loadouts and wrong for ownership, which needs an explicit write path.
- **Cosmetics cannot change gameplay numbers** (skin validator). That rule stays: a skin is never the thing that carries power. Gameplay content is sold as its own item (a weapon or an alter ego), with one set of numbers for every owner.
- **Gameplay content available to sell:** 16 weapons (8 primary, 6 secondary, 1 melee, 1 utility) and one alter ego. A BedWars-style kit store needs more alter egos before it has anything to sell.
- **Every weapon is free to equip today**, like the cosmetics. `LoadoutService` needs the same ownership check.

## 2. Rules (adapted from the game-mode questions)

**What can be granted.** Exactly two kinds: an *entitlement* (ownership of one catalog item: a cosmetic, a weapon, an alter ego or a boost; permanent unless it carries a duration) and *currency* (Credits added to the wallet). A grant of anything else fails the build gate.

**Fairness rules for sold gameplay content.** These are what keep the Rivals/BedWars model from becoming pay-to-win.

- Every weapon and alter ego that can be bought can also be unlocked with Credits earned by playing. Nothing with gameplay effect is Robux-only.
- An item has one set of numbers. There is no paid upgrade, paid ammo, paid armor, paid cooldown or stronger "premium" variant.
- A starter loadout covering every slot is free forever, so a new player is never unarmed or outclassed by default.
- A weekly rotation makes some locked weapons and alter egos free to use. Rotation ownership is temporary and is not written to the profile.
- Spending Credits is a server action with no Roblox prompt: check balance, deduct, grant, save.

**Two ways to pay.** Robux buys Credit packs, bundles and (later) cases and the pass. Credits buy weapons and alter egos. Whether cosmetics can also be bought with Credits is open (§8).

**What is locked.** An item is free unless the catalog lists it as locked. This keeps today's behaviour until an item is deliberately put on sale, and makes "what costs money" one reviewable list.

**Purchase states and transitions.** The server owns all of them.

```
Idle -> Prompted        client asks; server checks: store enabled, in lobby, item exists,
                        not already owned, product id set, not rate-limited
Prompted -> Idle        player cancels (no state change)
Prompted -> Granting    Roblox calls ProcessReceipt
Granting -> Granted     grant written, receipt id recorded, profile save confirmed
                        -> return PurchaseGranted
Granting -> Retry       profile not loaded, or save not confirmed
                        -> return NotProcessedYet; Roblox calls again later
Granted (repeat call)   receipt id already recorded -> return PurchaseGranted, grant nothing
```

- **Exactly once.** The receipt's `PurchaseId` is stored in the profile next to the grant, in the same save. A repeat call for a recorded id grants nothing.
- **Never lose a paid purchase.** `ProcessReceipt` returns `PurchaseGranted` only after the save holding the receipt id is confirmed. Any doubt returns `NotProcessedYet`.
- **Receipts grant in any state.** A receipt can arrive mid-match or on a later join. The lobby-only rule applies to prompting, not granting.
- **Unknown product id.** Logged with the id and returned as `NotProcessedYet`, so a product created before its catalog entry is granted once the entry ships.
- **Game passes.** Roblox is the authority. Ownership is read with `UserOwnsGamePassAsync` on join, cached for the session, and updated by `PromptGamePassPurchaseFinished`. A failed read is retried, never treated as "not owned" for the session.
- **Equipping.** Each cosmetic service asks `StoreService:Owns(player, kind, id)` before accepting a choice and returns `false, "not_owned"` otherwise.
- **Saved choice no longer owned** (item locked after launch, or a refund). The saved choice is kept but the default appearance is applied. Nothing is deleted.
- **Disconnect during purchase.** Roblox re-delivers the receipt on the next join; the retry path covers it.
- **Kill switch.** `Store_Enabled = false` stops new prompts. Receipts already paid for are still granted.
- **Prices.** No price appears in our code or data. The client reads it from `MarketplaceService`, so Roblox Plus discounts and regional prices show correctly.

**What persists.** Entitlements, wallet balance and the last `ReceiptHistory` receipt ids. Bot and practice matches are irrelevant: nothing here is earned in a match.

**Open hypotheses.**

| Hypothesis | Test | Owner |
| --- | --- | --- |
| Common and Uncommon stay free; Rare, Legendary and Mythical are sold (20 items). | Product decision, see §8. | User |
| The free starter loadout is one weapon per slot; the other 12 weapons are locked. | Product decision, see §8. Needs a time-to-first-unlock target before prices are set. | User |
| A new player earns their first weapon unlock within about three matches. | Playtest once earn rates exist; earn rates live in `Config.Store` and are not set by this packet. | Implementer |
| 100 stored receipt ids is enough. | Roblox retries unacknowledged receipts; confirm retry window against the docs before G2. | Implementer |
| ProfileStore's save-confirmation hook is usable inside `ProcessReceipt`. | Read the vendored `ProfileStore` module and prove it in Studio with API access on. | Implementer |

**Unknown.** Refunds and chargebacks: Roblox does not notify the game for developer products. No clawback is designed. Revisit if the dashboard shows a problem.

## 2a. Economy targets

Sources: [Rivals and BedWars market assessment](../../../reports/Rivals%20and%20BedWars%20market%20assessment.md) and the [wider shooter survey](../../../reports/Roblox%20FPS%20economics%20wider%20survey.md), which measured the catalogues of the six shooters ranked behind Rivals from Roblox's public APIs on 2026-11-16 ("the tier" below). Every Rivals number in the first two reports came from third-party guides. The [top shooter comparison](../../../reports/Top%20shooter%20monetization%20comparison.md) then measured all eleven catalogues from Roblox's public APIs on 2026-11-16 and found the guide prices were Rivals' GIFT prices; the table below uses the measured self-purchase prices. Those are prices served to an anonymous caller and may reflect regional pricing or a price test. Key amounts above 40 per pack are still third-party. Every row below is a **Hypothesis** to be tuned from our own Creator Hub sales data, and none is a foundation acceptance threshold. Robux prices are set in Creator Hub, never in code. Credit prices and earn rates live in the catalog and `Config.Store`.

| Lever | Rivals (reported) | Target for this game | Why |
| --- | --- | --- | --- |
| Credit price | 5.90 R$ per Key in the smallest pack, falling to 3.41 in the largest: a 42% bulk discount | About 6 R$ per Credit falling to about 3.5 | Corrected: the earlier "near-flat, 7%" reading used gift prices |
| Credit packs | 10 / 40 / 90 / 450 / 1,100 Keys for 59 / 199 / 385 / 1,649 / 3,749 R$ (gift versions 49 / 199 / 449 / 2,199 / 4,999) | Same five steps at about the self-purchase prices; the top two each include an exclusive skin | Developer products, repeatable |
| Free Credit income | About 55 to 60 a week (dailies, capped wheel, codes) | About 55 a week for a daily player | Sets every time wall below |
| Starter weapons | A free base set | One per slot, 4 of 16, free forever | SF-15 |
| Standard weapons | 26 at 5 to 75 Keys, 760 total, about 13 weeks free | 8 weapons at 10 to 75 Credits, about 300 total, about 5 to 6 weeks free | First unlock inside the first session or two |
| Prime weapons | 13 at 200 to 550 Keys, about 86 weeks free | 4 weapons at 200 to 400 Credits, about 1,200 total, about 20 weeks free | The time wall that makes Credits worth buying |
| Standard weapons bundle | 849 R$ game pass for "every current and future" standard weapon (999 as a gift) | One game pass for all current and future Standard weapons at 849 to 999 R$; Credits already spent on them are refunded once | The obvious first purchase; "and future" makes it a lifetime pass |
| Small cosmetic boxes | Wrap box 5, charm capsule 3, finisher pack 10 Keys | Deferred to the skin-case packet | Gives Credits a sink after weapons are owned |
| Skin cases | 289 R$, 545 R$ for three (249 and 724 as gifts), or 10 Skin Tickets (third-party); never Keys. The tier sells entry cases at 9 to 99 R$ in x10 and x100 multi-buys | A ladder, later packet: entry case under 100 R$, multi-buys, a chase case at 249 R$ or more; also openable with Skin Tickets | Showpiece cosmetics stay off the Credit economy; the tier shows cheap entry cases are the norm |
| Season pass | Two paid tiers at 689 and 749 R$ (599 and 999 as gifts); level skips 99 R$, 6,999 for all 70; free track pays 9 of the 10 tickets a case costs (third-party). Hypershot runs 499 and 899; base passes across the eleven games run 299 to 799 | Two tiers at about 499 and 899 R$, skips at 75 to 99 R$, no weapon exclusive to the paid track; later packet | Roblox's own tests say most creators price too high; judge the pass on how many players it converts |
| Permanent bundles | 59 to 1,425 R$, sold as game passes | Game passes (Standard weapons bundle, starter pack), later packet | One-time, permanent, works when bought on the website |
| Rotating bundles | The tier releases a 799 to 850 R$ bundle about weekly, as giftable developer products | Developer products on a rotation, later packet; cadence set by what the team can sustain | Repeatable, giftable, price can change; the tier is moving off game passes for these |
| Free growth loops | Code worth 3 Keys per 50,000 likes; reward for joining the group; reward for returning players | Same, armory packet | Costs nothing |

**What each sale returns** (derived: 70% share × $0.0038 per Robux = $0.00266; 42% more on spend by age-checked US adults, where it qualifies).

| Sale | Robux | Cash to us | With US adult rate |
| --- | --- | --- | --- |
| Smallest Credit pack | 59 | $0.16 | $0.22 |
| Entry skin case | 45 | $0.12 | $0.17 |
| Chase skin case | 249 | $0.66 | $0.94 |
| Base pass tier | 499 | $1.33 | $1.89 |
| Rotating bundle | 799 | $2.13 | $3.02 |
| Standard weapons bundle | 849 | $2.26 | $3.21 |
| Largest Credit pack | 3,749 | $9.97 | $14.16 |

**Decided from this.**

- **Permanent one-time unlocks are game passes; rotating bundles and anything repeatable or giftable are developer products.** Roblox names game passes as qualifying for the higher US adult rate, but only "select" in-game items, which favours passes. The tier has moved its bundles to products anyway, for gifting and repricing, and one small duel game earned almost nothing from its pass. Revised 2026-11-16 from "all bundles are passes".
- **Gifting is designed for, not built.** A grant names its recipient, who defaults to the buyer, so a later packet can add gifting without changing receipt handling.
- **No purchase prompt in a player's first minutes.** Roblox's recommendations count a first play that ends within three minutes against the game. The lobby shows locked items passively until the player has finished one match. Hypothesis; `Store_FirstPromptAfterMatches` (default 1, range 0–10).
- **Paid random items need a per-player policy check before they ship.** Brazil banned paid loot boxes for minors in March 2026 and Roblox PvP audiences are often Brazil-heavy. Cases get a show-contents-first or direct-purchase variant for restricted players. Owned by the skin-case packet.
- **The wallet holds more than one currency.** Skin Tickets must exist beside Credits so cases can stay off the Credit economy.
- **One purchase can grant several entitlements** (a weapons bundle, a pack with a bonus skin).
- **A pass bought on the Roblox website must work on next join**, with no receipt. Pass grants are derived from pass ownership each session, not written to the profile.

**Not copied.**

- A paid ranked-entry bypass. A guide reported one in Rivals at 200 R$, but the measured catalogue has no product for it, so it is unconfirmed. Either way it sells access to competitive integrity.
- In-match power for Robux: Hypershot's "INSTANT Revenge" (49 R$), Deagle Arena's permanent speed and reload products (69 and 99 R$), Pixel Arena's second weapon slot (399 R$), and paid revives in player-versus-player modes. The games selling these are off the Top Earning list or at #303, and hold three of the lowest like ratios measured.
- Luck multipliers on cases. Roblox treats them as paid random items whose displayed odds must update live.
- Single prompts of 19,800 to 80,000 R$. Four catalogues list them; nothing shows they sell, and refund exposure is real for a small team.
- BedWars' flat five-dollar gameplay passes with a shrinking free currency. Its like ratio is 82% against Rivals' 94%, and pay-to-win is its standing complaint.

**Adopted ideas, ranked** (from the top shooter comparison; suggested prices are hypotheses anchored on the measured examples).

| Rank | Idea | Measured example | Shape here | Owner | Foundation must support |
| --- | --- | --- | --- | --- | --- |
| 1 | Runtime prices with Roblox managed pricing left on | Roblox: 43% to 52% more pass purchases in discounted regions | Every price fetched per player | Foundation | Already decided; add a price-level check before a gift |
| 2 | Lifetime "current and future" weapons pass | Rivals 849 R$; Voxel Wars 3,499 R$ with currency refunded | 849 to 999 R$ pass; one-time Credit refund for weapons already bought | Armory | Pass grants by tag ("all Standard weapons"), not a fixed list; a one-time refund flag |
| 3 | Guaranteed-price twin, published odds and duplicate protection on every case | Voxel Wars "never one you already own"; Sniper Arena "Guaranteed after 50 opens"; Pixel Arena 1,249 R$ direct beside a 99 R$ crate | Each case skin also sold directly | Skin cases | Nothing new |
| 4 | Starter pack under 100 R$ and a half-price first purchase | Ten of eleven games, 19 to 149 R$; Blade Ball first roll 37 against 75 R$ | Starter at 49 to 79 R$; first case half price once | Skin shop | One-time-purchase flags in the profile |
| 5 | Gift versions at the same price | Eight of eleven games; BedWars has one gift product per price tier | One gift product per price tier, not per item | Skin shop | Recipient field (decided); purchase intent (below) |
| 6 | Reusable slot products and a fixed drop day | Rivals "Daily Skin A–E" 299 to 599 R$; Hypershot weekly 799 R$ bundle | Five to ten generic price-point products for a rotating shop | Skin shop | Purchase intent: the server records what the slot held when it prompted |
| 7 | Two-tier pass with level skips | Hypershot 499 / 899 R$; Rivals 689 / 749 R$, 99 R$ a level | 499 and 899 R$, skips 75 to 99 R$ | Battle pass | Nothing new |
| 8 | Rewarded-ad weapon trial or XP boost | Rivals, Hypershot and Pixel Arena all lend a weapon for an ad view | A fixed, named 30-minute trial or XP boost, lobby only, never ranked | Ads | Timed entitlements; a zero-price product as the ad reward |
| 9 | Bundle-first releases with piece pricing | BedWars 999 R$ bundle for two weeks, then pieces; Rivals piece 549 beside bundle 555 R$ | Cosmetic sets only; never gate a new weapon behind the window | Skin shop | Nothing new |
| 10 | Daily loop sized for Roblox's 10-minute engagement reward | Rivals "Refresh Tasks" 15 R$; Sniper Arena "Reclaim Reward" 19 R$ | Three-match daily contract; refresh at 5 to 15 R$ | Armory | Nothing new |
| 11 | Timed XP boosts and a permanent 2x XP pass | Voxel Wars 59 R$ per 30 minutes, counting down only in play; One Tap pass 149 R$ | Boosts 29 to 59 R$; pass 149 R$; XP and Credits rate only | Armory | Timed entitlements that count down only in a match |
| 12 | Private server with organizer tools | Tier prices 49 to 100 R$; The Strongest Battlegrounds tools pass 499 R$ | 100 R$ a month; tools pass 399 to 499 R$ | Later | Nothing new |
| 13 | Cosmetic VIP pass and a Roblox Plus prompt | Blade Ball VIP 240 R$; Hypershot 299 R$ | 249 to 299 R$; chat tag, kill effect, one Credit grant | Skin shop | Nothing new |
| 14 | Clan creation and set-completion rewards | KNIFE DUELS clan 99 R$; Deagle Arena free bundle for owning three others | Clan 99 to 240 R$; free cosmetic for owning a season's bundles | Later | Grant triggered by ownership of a set |
| 15 | Trading | BloxStrike, Sniper Arena, Blade Ball; no fee published anywhere | Deferred | Later | Out of scope |

**Foundation changes that follow from the shortlist.**

- **Purchase intent.** Before prompting, the server records what this player is buying, for whom, and what the product currently stands for. The receipt handler grants from that record. This is what lets one slot product sell a different skin each day and one gift product serve a whole price tier. An intent older than `Store_IntentSeconds` (default 300, range 30–3,600) or missing is treated as an unknown product and retried, never guessed.
- **Entitlements may carry a duration.** A weapon trial or an XP boost is an entitlement with an expiry. Boosts count down only during a match. The weekly rotation uses the same mechanism.
- **Passes may grant by tag.** "All Standard weapons, current and future" is a rule evaluated each session, so new weapons need no catalog edit.
- **One-time flags.** The profile records starter pack bought, first-purchase discount used and Credit refund paid.
- **Boosts are limited to XP and Credit rates.** `check_store` fails a boost that names damage, health, speed, reload, ammo or cooldown.

**Planning number.** About $50 a year per sustained concurrent player, low $25, high $110 (derived in the wider survey). The earlier $106 was the average across all of Roblox and is now the high case. The base rests on two small developers' own figures, one of which is not confirmed to be a shooter; if Roblox's dashboard reports revenue before its 30% cut, the cases fall to $17.50, $35 and $77.

| Sustained concurrent players | Low | Base | High |
| --- | --- | --- | --- |
| 100 | $2,500 | $5,000 | $11,000 |
| 1,000 | $25,000 | $50,000 | $110,000 |
| 10,000 | $250,000 | $500,000 | $1,100,000 |

Expect median daily payer conversion of 0.07% to 0.34% (developer dashboard panels, 2025), not the 2% to 5% calculator sites assume, and about half of revenue from the top 15% of payers (Roblox). Replace all of this with our own Creator Hub numbers, including its genre benchmark panel, in the first weeks after launch.

## 3. Map questions

**Not applicable.** No geometry. Purchases are offered only while the player is in the lobby (`InMatch` false and `QueueState` not `Committed`), the same condition the cosmetic pickers already use.

## 4. Player storyboard

This is a storyboard brief. Visuals are required before G1 can be accepted and none exist yet.

| Frame | Player view / visual | Player question | Decision/action | Feedback and next state | Shared component |
| --- | --- | --- | --- | --- | --- |
| 1 Arrival | Lobby, loadout open (concept: not drawn) | What can I use? | Browse skins | Owned items look as they do today | Loadout picker |
| 2 Discover | A locked skin: lock mark, tier, live price | What is this and what does it cost? | Tap it | Preview plays; BUY replaces EQUIP | Weapon preview, new locked state |
| 3 Decide | Roblox purchase prompt | Do I want it? | Confirm or cancel | Cancel returns to frame 2 unchanged | Roblox prompt |
| 4 Wait | "Purchasing…" on the button | Did it work? | None | Button disabled until the server answers | New pending state |
| 5 Setback | "Purchase is taking longer than usual. You will not be charged twice." | Did I lose my Robux? | Keep playing | Item unlocks when the receipt lands, even next session | New failure state |
| 6 Recovery | Next join: item shows as owned | Is it mine? | Equip | Normal equip flow | Loadout picker |
| 7 Result | Skin on the weapon in a match | Does everyone see it? | Play | No store UI during a match | SkinService |
| 8 Replay | Lobby, next locked item | What next? | Browse | Back to frame 2 | Loadout picker |

## 5. Visual and interaction contract

- **Art target.** None new. Locked state reuses the existing picker cards.
- **Colour and type.** Through `Theme` only; no new colour literals. Locked is shown by a lock mark and the word "Locked", not by colour alone.
- **HUD regions.** Lobby panels only, laid out through `Screen`. Nothing is added to the match HUD.
- **Input.** Tap, click or controller A on BUY. No hold. Cancel is Roblox's own prompt control.
- **States.** Owned · Locked (price shown) · Price loading ("…") · Unavailable (no product id yet, button hidden) · Pending · Granted · Delayed · Store disabled (BUY hidden, item still previewable).
- **Text.** Price is a number plus the Robux mark and cannot overflow. Messages are one line at phone width.
- **Devices.** Phone, tablet, desktop and console per the `roblox-ui-layout` QA gate. Load that skill before building any of this.
- **Not applicable:** camera policy, mutation occlusion, map materials.

## 6. Reuse and ownership contract

| Component | Reuse / extend / new | Owner/path | Data/input → result | Consumers affected | Regression evidence |
| --- | --- | --- | --- | --- | --- |
| `Shared/Store/Catalog.lua` | New | Pure data | Product key → kind (Product/Pass), Roblox id, grant (a list: several entitlements and currencies per purchase); Credit price per weapon and alter ego; plus the locked-item list | StoreService, StoreController, `check_store` | `check_store` |
| `Shared/Store/Entitlements.lua` | New | Pure functions | (profile data, pass cache, kind, id) → owned? | StoreService, tests | `check_store` unit cases |
| `StoreService` | New | Server | Sole owner of `ProcessReceipt` and both prompt-finished events; `Owns`, `Grant`, `RequestPurchase` | Cosmetic services | SF-01 to SF-07 |
| `StoreController` | New | Client | Reads prices, fires `RequestPurchase`, shows states | Loadout picker | SF-08 to SF-10 |
| `DataService` | Extend shared | [DataService.lua](../../../src/server/Services/DataService.lua) | Template gains `Entitlements = {}`, `Wallet = { Credits = 0, SkinTickets = 0 }` (a map, so a currency can be added without a migration), `Receipts = {}`; new explicit write function used only by StoreService | Every profile load (`Reconcile` adds the fields) | Existing profile loads with fields added and nothing else changed |
| `SkinService`, `CharacterSkinService`, `CelebrationService`, `AlterEgoService`, `LoadoutService` | Extend shared | Existing | One `Owns` check in each setter and at apply time. A saved loadout slot whose weapon is no longer usable (rotation ended) falls back to the starter weapon for that slot | Loadout picker, match start, bots | All currently free items still equip; nobody spawns with an empty slot |
| Weekly rotation | New, inside `StoreService` | Server | Week number + catalog rotation pool → temporarily usable ids, same for every server | `Owns`, loadout picker | SF-14 |
| `Config.Store` + `TuningService` | Extend shared | [Config.lua](../../../src/shared/Config.lua) | `Store_Enabled` (true), `Store_PromptCooldownSeconds` (2, range 0–30), `Store_ReceiptHistory` (100, range 20–500), `Store_FirstPromptAfterMatches` (1, range 0–10), `Store_IntentSeconds` (300, range 30–3,600) | TuningService | Out-of-range falls back to default |
| `tools/check_store.luau` | New | Build gate, added to CI and the CLAUDE.md gate list | Fails on: a locked id missing from its registry, a product with no grant, a grant kind other than entitlement or currency, a weapon or alter ego with no Credit price, a slot with no free starter weapon, duplicate Roblox ids, any Robux price literal in `src` | CI | Gate passes |

**Why new.** Nothing in the project talks to `MarketplaceService`, and ownership cannot ride the attribute mirror: that path saves whatever attribute a service sets, with no receipt beside it.

**Authority.** The client never states that something is owned or what it costs. It asks; the server decides. `ProcessReceipt` is assigned once, in `StoreService:KnitInit`, so it exists before any player joins.

**Cleanup.** Per-player pass cache and rate-limit state are dropped on `PlayerRemoving`. Nothing else is held in memory.

## 7. Acceptance and evidence

Every row is **Not started**.

| ID | Player-visible requirement | Test | Threshold |
| --- | --- | --- | --- |
| SF-01 | A purchase unlocks the item | Studio test purchase of a locked skin | Owned and equippable without rejoining |
| SF-02 | Never granted twice | Call the receipt handler twice with one `PurchaseId` | One entitlement, one currency credit |
| SF-03 | Never lost | Receipt arrives before the profile loads; save fails once | `NotProcessedYet` first, granted on retry |
| SF-04 | Ownership survives a rejoin | Buy, leave, rejoin on a server with API access | Still owned |
| SF-05 | Cannot equip unowned items | Fire each cosmetic setter directly with a locked id | `false, "not_owned"`; attribute unchanged |
| SF-06 | Free items still work | Equip every unlocked item in each picker | All succeed |
| SF-07 | No prompt in a match | `RequestPurchase` while `InMatch` | Refused; no Roblox prompt |
| SF-08 | Price is live | Change the price in Creator Hub | New price shows with no code change |
| SF-09 | Every state reads on every device | `roblox-ui-layout` QA gate | Passes on phone, tablet, desktop, console |
| SF-10 | Kill switch | `Store_Enabled = false` | BUY hidden; a pending receipt still grants |
| SF-11 | Nothing with gameplay effect is Robux-only, and nothing sold is a stat upgrade | `check_store` | Passes; a planted Robux-only weapon and a planted stat grant each fail it |
| SF-13 | Credits unlock a weapon | Spend Credits on a locked weapon; repeat the request rapidly | One deduction, one unlock, balance never negative |
| SF-14 | Rotation lends without giving | Equip a rotation weapon, then advance the week | Usable this week; next week the slot shows the starter weapon and the item is locked again |
| SF-16 | A bundle unlocks everything in it | Studio test purchase of a pass granting several weapons; rejoin | All items usable at once and after rejoin; nothing granted twice |
| SF-17 | A rotating slot sells what it showed | Prompt on a slot product, rotate the slot, then complete the purchase | Player receives the item shown at prompt time |
| SF-18 | A timed unlock expires | Grant a 30-minute weapon trial and a boost; play, idle in lobby, rejoin | Trial ends on time; boost time is spent only in matches; neither survives as permanent |
| SF-19 | One-time offers are one-time | Buy the starter pack; request it again; rejoin and request again | Second prompt refused |
| SF-15 | A new player is fully armed | Fresh profile joins a match | Every slot filled from the starter loadout |
| SF-12 | Existing gates stay green | Full pre-commit list | Zero warnings |

SF-04 and SF-08 need a published test place and real product ids. Studio's mock store does not persist, so Studio alone cannot pass SF-04.

## 8. Gates and handoff

| Gate | Status | Evidence / decision |
| --- | --- | --- |
| G0 Baseline | Ready for review | §1 findings, commit `57c5264` |
| G1 Design | In progress | Needs storyboard visuals and the three choices below |
| G2 Playability | Not started | |
| G3 Complete section | Not started | |
| G4 Extension | Not started | |
| G5 Release candidate | Not started | |

**Next concrete task.** Read the vendored `ProfileStore` module to confirm the save-confirmation hook, then build `Catalog`, `Entitlements` and `check_store` (pure code, no Roblox ids needed).

**Unresolved choices (user).**

1. Which existing cosmetics become locked. Proposal: Rare and above (20 of 50).
2. Whether any real players already have saved selections. If so, they keep what they have equipped as owned on first load after launch. If the game is unreleased, no grandfathering is built.
3. Which weapons form the free starter loadout. Proposal: one per slot, chosen as the easiest to use; the other 12 are locked.
4. Whether Credits can also buy cosmetics. Default unless you say otherwise: the Rivals split in §2a (Credits buy weapons and small cosmetic boxes; showpiece skins come from Robux cases, bundles and the pass).
5. Whether to build more alter egos. With only Titan there is no kit store.

**Dependencies.**

- Developer products and passes must be created in Creator Hub by the account owner; their ids go in the catalog. Until then items show as Unavailable.
- Managed pricing is an opt-in setting in Creator Hub, not code.
- Persistence tests need Studio API access or a published test place.

**Work that can continue independently.** Catalog, entitlement functions, `check_store`, the `DataService` template fields and the four equip checks need no product ids and no answers to the choices above (with an empty locked list they change nothing).

**Shared consumers needing regression checks.** Profile load for an existing player; every cosmetic picker; `GiveLoadout` after a skin change; match-start character skin application.

**Follow-on packets, in order.** Armory (weapon and alter-ego unlocks, Credit packs, earn rates) · skin shop, bundles and daily shop · battle pass · skin cases · subscription · ads and Roblox Plus prompt. Skin cases additionally require odds disclosure and the `PolicyService` restriction check before any design work.

**Decision log.**

- 2026-11-16 — Cosmetic-only store proposed, then replaced the same day by user direction: follow Rivals and BedWars, which sell weapons and kits. Weapons and alter egos are now sellable, bounded by the fairness rules in §2 (earnable with Credits, one set of numbers, free starter loadout, weekly rotation). Affects SF-11, SF-13 to SF-15.
- 2026-11-16 — Economy targets added from the market assessment (§2a), all as hypotheses. Foundation changes that follow: wallet is a currency map, grants are lists, bundles are game passes, pass grants are derived each session. Affects the catalog and `DataService` rows in §6.
- 2026-11-16 — Wider shooter survey applied to §2a: planning number lowered from $106 to $50 per concurrent player per year; case ladder replaces a single 249 R$ case; base pass target lowered to about 449 R$; rotating bundles become developer products while permanent unlocks stay passes; grants name a recipient; first-prompt delay added. All remain hypotheses except the pass/product split and the recipient field.
- 2026-11-16 — Top shooter comparison applied: Rivals prices corrected to measured self-purchase values (earlier figures were gift prices; bulk discount is 42%, not 7%); ranked bypass marked unconfirmed; 15 adopted ideas listed with owners; foundation gains purchase intent, timed entitlements, tag-based pass grants and one-time flags. Affects SF-17 to SF-19 and the catalog row in §6.
- 2026-11-16 — Credits ship in the foundation rather than later. Reason: both reference games unlock gameplay content with an earnable currency.
- 2026-11-16 — Items are free unless listed as locked. Reason: no behaviour change until an item is deliberately put on sale. Affects SF-06.
- 2026-11-16 — Prices are never stored. Reason: Roblox Plus discounts and regional pricing change what each player pays. Affects SF-08.
