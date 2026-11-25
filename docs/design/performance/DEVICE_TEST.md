# Device performance test

The triangle budgets in `tools/asset_rules.py` are starting guesses. This test replaces
them with measurements from real devices. The game records the numbers itself; your part
is to play the listed situations on each device.

## What gets recorded

Every 30 seconds, per player, while `Debug_PerfProbe` is on:

| Number | Why it matters |
| --- | --- |
| Frame rate, average and low (slowest 1% of frames) | the low figure is what a player feels as stutter |
| Worst single frame, ms | hitches when something loads or spawns |
| Memory: total, textures, meshes (MB) | phones crash from memory before they slow down |
| Triangles and draw calls in view | what the asset budgets are meant to control |
| Ping | so a network stall is not mistaken for a rendering one |
| Device class, screen size, graphics quality level | quality 0 means Automatic: Roblox lowers detail under load |
| Map, player count, vehicle count (added by the server) | to tie a slow window to what was on screen |

Each window also appears as a `[Perf]` line in chat. Sessions are saved to the
`PerfProbe_v1` data store.

## Before you start

1. In Studio, select `ReplicatedStorage.Tuning` and tick `Debug_PerfProbe`.
2. Game Settings -> Security: "Enable Studio Access to API Services" must be on (needed to
   read the results back).
3. Publish the place. A phone cannot join a Studio test, only the published game.
4. On each device set graphics quality to **Automatic** for the first pass. That is what
   most players have.
5. Close other apps on the device. Note the device model and roughly how old it is.

## What to play

Stay in each situation for at least two minutes (four recorded windows). Say in chat what
you are about to do (for example "now driving") so the windows can be matched up later.

| # | Situation | What it stresses |
| --- | --- | --- |
| 1 | Lobby, standing still, then walking around | baseline memory and frame rate |
| 2 | Each map in rotation: stand at a spawn, turn slowly all the way round | the heaviest view of each map |
| 3 | Each map: walk the full length, both sides | streaming and texture memory growth |
| 4 | A full match with bots at the normal team size | fights, effects, many characters |
| 5 | Five Islands: drive the wave runner, then stand where several vehicles are in view | the vehicle meshes |
| 6 | Snow Fortress: hold a White Sniper, scope in and out, look at the second pickup | the 72,000-triangle rifle |
| 7 | Stay in one server for 20 minutes across two matches | memory that climbs and never comes back |

Devices worth covering, in order of value: the oldest phone you can borrow, a current
phone, an iPad, then a PC as the reference.

If the game crashes or the device gets hot enough to dim the screen, write down the
situation and the time. A crash loses at most the last two minutes of recording.

## Getting the results out

In Studio, with the place open, paste this into the command bar (View -> Command Bar) and
press Enter. It prints every saved session as one line of JSON in the Output window.

```lua
local d=game:GetService("DataStoreService"):GetDataStore("PerfProbe_v1") local h=game:GetService("HttpService") local p=d:ListKeysAsync() while true do for _,k in p:GetCurrentPage() do print("PERF "..k.KeyName.." "..h:JSONEncode(d:GetAsync(k.KeyName))) end if p.IsFinished then break end p:AdvanceToNextPageAsync() end
```

Copy the `PERF ...` lines into a text file under `docs/design/performance/results/`, named
for the day, for example `2026-11-20.txt`. Then:

```bash
python tools/perf_report.py docs/design/performance/results/2026-11-20.txt
```

It prints one row per device, map and situation, marks the windows that fall under the
targets below, and says what the measured triangle and draw-call ceilings were on the
weakest device that still met them.

## Targets

| | Phone | Tablet | Desktop |
| --- | --- | --- | --- |
| Average frame rate | 30 or more | 30 or more | 60 or more |
| Low frame rate | 20 or more | 20 or more | 40 or more |
| Total memory | under 1,200 MB | under 1,500 MB | no limit set |

These targets are also starting points. The memory lines are deliberately cautious: older
phones are closed by the system well before the newest ones are.

## When you are done

Untick `Debug_PerfProbe` and publish again. The recorder does nothing while it is off.

## What this does not tell you

- Which single asset is expensive. It shows what the whole view costs; comparing the same
  spot with and without an asset (situations 5 and 6) is how one asset is isolated.
- Anything about a device that was not tested.
- Whether a number was low because Roblox had already lowered the quality level. Check the
  recorded quality level, and repeat a slow situation with quality fixed at the middle of
  the slider.
