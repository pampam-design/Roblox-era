# Survive the Disaster

A branching-story Roblox game. Pick a situation, make decisions, and try to
survive. Every scenario has multiple routes and several endings (survived,
hero, or didn't make it), with a short real-world safety lesson at the end.

| Scenario | Setting | Disaster | Endings |
|---|---|---|---|
| Shaking Ground | Classroom | Earthquake | 4 |
| Rising Water | Subway | Flash flood | 4 |
| Ember Night | Campsite | Wildfire | 4 |
| The Sea Pulls Back | Beach resort | Tsunami | 4 |
| Dead Hours | Apartment block | Zombie outbreak | 6 |
| Flash Warning | Office tower | Nuclear missile | 4 |

## How it plays

- **Health** and **Calm** bars. Health 0 ends the story. Low Calm (25 or below)
  makes risky choices harder.
- **Items** you pick up unlock choices later (torch, belt, wet cloth...).
- **Risky** choices roll dice on the server; panic lowers your odds.
- Endings you discover are saved per player (DataStore) and shown on the menu.

## Starter packs (Robux): currently OFF

The shop is disabled by `ShopEnabled = false` in `src/shared/Config.lua`. Flip it
to `true` once you have Developer Product ids. Until then there is no shop
button, and the server ignores buy/equip and purchase receipts.

`src/shared/Shop.lua` defines consumable packs: Supply Pack (water, food),
Survival Knife, Extra HP (+50 starting health) and a bundle. A pack is used up
by one run. Items open extra choices in some scenes and boost some risk rolls.

To go live: create one **Developer Product** per pack in the Creator Dashboard
and paste each id into `productId`. While `productId` is 0 the packs are free
in Studio (for testing) and show as "Soon" in the live game. Purchases go
through `ProcessReceipt` (idempotent, saved before granting).

Design rule: **no ending is locked behind a pack.** Packs only add shortcuts and
a bigger safety margin. `tools/test_story.py` checks that every ending is
reachable with zero packs. Keep it that way if you add content.

## 3D stages and hold actions

Scenarios can have a walkable 3D stage (`world = "Classroom"` in the scenario,
builder in `src/server/Worlds/`). Currently only **Shaking Ground** has one;
the others are still the plain story screen.

- Each player gets a private copy of the set, far from other players.
- Story choices become `ProximityPrompt`s at glowing orbs you walk up to
  (keys E / F / R / T). The story text sits in a panel at the bottom.
- Moving to a new story step can teleport you (e.g. into the corridor) and
  triggers disaster effects: camera shake, falling ceiling tiles, lights out.
- **Hold actions:** a choice with `hold = seconds` must be held, e.g. hanging
  on to a railing. In the 3D stage this is the prompt's hold timer; in the
  plain story screen it is a press-and-hold button, and the server checks the
  elapsed time. Releasing early cancels it.
- "Buttons: ON" in the panel lets you click options instead of walking to them
  (a fallback if a prompt is awkward to reach).

`python3 tools/plan_view.py Classroom out.png` draws a top-down floor plan from
the real build code to sanity-check the layout without opening Studio.

## Running it

1. Install [Rojo](https://rojo.space) and run `rojo serve` in this folder.
2. In Roblox Studio, open a new Baseplate and connect the Rojo plugin.
3. Press Play. (Or `rojo build -o Disaster.rbxlx` and open the file.)
4. To save endings in Studio, enable *Game Settings > Security > Enable Studio Access to API Services*.

It is entirely UI-driven: no map is required. The player's character just
stands on the baseplate behind the story screen.

## Adding a scenario

Create `src/shared/Scenarios/MyScenario.lua`, add it to
`src/shared/Scenarios/init.lua`, and add its name to `tools/test_story.py`.

```lua
return {
  id = "my_scenario", title = "...", place = "...", disaster = "...",
  icon = "🌪", difficulty = "Easy", blurb = "...",
  start = "start", deathNode = "death", lesson = "default lesson",
  nodes = {
    start = {
      fx = "quake", -- none | calm | quake | flood | fire | wave | dark
      text = "Story text...",
      choices = {
        { text = "Do the thing", next = "other_node",
          effects = { health = -10, calm = 5, give = {"torch"}, set = {"flag"} },
          note = "Shown after choosing" },
        { text = "Use the torch", next = "x", requires = { items = {"torch"} },
          hiddenIfLocked = true },
        { text = "Gamble", next = "x", -- chance replaces next
          chance = { p = 0.5, win = "good", lose = "bad", boostItem = "torch" } },
      },
    },
    good = { text = "...", ending = { kind = "survived", title = "..." }, lesson = "..." },
    death = { text = "...", ending = { kind = "died", title = "..." }, lesson = "..." },
  },
}
```

## Testing the story graph

```
pip install lupa
python3 tools/test_story.py
```

Checks that every link resolves, every node is reachable, no choice list is a
dead end, and fuzz-plays each scenario 20,000 times with the real engine to
confirm every ending can be reached.
