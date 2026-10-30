# vehicledamage

Cars that break down like cars. Damage builds up instead of vanishing, a beaten engine loses power, smokes and eventually dies, and you can patch it up at the roadside or take it to a mechanic.

Works with any framework. Needs [ox_lib](https://github.com/overextended/ox_lib). ox_target and ox_inventory are picked up automatically if you run them.

## What it does

The engine goes through four states:

| State | Engine health | What happens |
|---|---|---|
| Healthy | above 800 | Normal |
| Damaged | 800 to 360 | Check engine warning, slowly gets worse while the engine runs, power starts dropping |
| Failing | 360 to 100 | Loses health fast, smokes, power keeps falling |
| Dead | 100 | Engine cuts out. With limp mode on it keeps running at very low power instead |

- Hits to the engine, body and fuel tank all wear the engine down. Weapons hit harder, small knocks (kicks, snowballs, windows) are ignored.
- Bikes, off-roaders, trucks, boats and emergency vehicles take less damage. Every class is configurable.
- Engines never drop low enough to catch fire, and the fuel tank is kept from exploding, so landing on the roof doesn't blow the car up.
- Upside-down cars can't be rocked back onto their wheels.
- Holding brake stops the car and keeps it stopped with the brake lights on instead of rolling into reverse.
- Optional random tire blowouts.

Engine health is synced by the game, so everyone sees the same smoke and the same dead car.

## Repairs

Stand at the front of the car and use `/repair`, or the **Repair engine** option on the bonnet if you run ox_target.

**At the roadside** you get a quick skill check and a progress bar, then the engine is patched up enough to drive (health 450). It's fragile, a decent crash will kill it again. Each car can only take a couple of roadside fixes before it needs a mechanic. Electric cars can't be fixed at the roadside at all.

**At a mechanic** (the Los Santos Customs locations and Beeker's Garage by default, shown on the map) the car is fully fixed and its roadside count resets. You can charge for it through `Config.charge`.

### Repair kit item

If ox_inventory is running, a roadside repair uses up one `repairkit`. Add it to `ox_inventory/data/items.lua` if you don't have it:

```lua
['repairkit'] = {
    label = 'Repair kit',
    weight = 2500,
    stack = true,
},
```

Set `Config.field.item = false` to make roadside repairs free.

## Install

```
ensure ox_lib
ensure vehicledamage
```

Start it after ox_target and ox_inventory if you use them.

## Config

Everything is in `config.lua`: the state thresholds, how hard each kind of hit lands, how fast engines wear down, power loss, limp mode, class multipliers, roadside repair limits, mechanic zones and prices, and which models count as electric.

Charging for mechanic repairs, ESX example:

```lua
Config.charge = function(source, amount)
    local player = ESX.GetPlayerFromId(source)
    if player.getMoney() < amount then return false end
    player.removeMoney(amount)
    return true
end
```

## Notes

- Repairs are checked on the server: distance to the car, mechanic zone, roadside uses left, and the repair kit.
- The damage logic only runs while you're driving, and drops to a 100 ms tick unless power loss, brake hold or flip prevention needs every frame.
- It never touches handling data, so other cars of the same model aren't affected.

## Support

Made by **IamZach**. Questions, bugs or ideas: [discord.gg/agn](https://discord.gg/agn)

## License

MIT
