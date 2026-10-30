Config = {}

-- Engine health runs from 1000 (new) down. These are the points where the car changes state.
--   damaged: check engine light, slowly gets worse while the engine runs
--   failing: loses health quickly, smokes, power drops off
--   dead:    the engine gives out. Health never goes below this, so cars don't catch fire.
Config.thresholds = {
    damaged = 800.0,
    failing = 360.0,
    dead = 100.0,
}

-- How hard hits land on the engine. 1.0 is vanilla.
Config.damage = {
    engine = 2.0,  -- direct engine damage
    body = 0.6,    -- share of body damage that also reaches the engine
    tank = 0.8,    -- share of fuel tank damage that reaches the engine
    weapon = 1.5,  -- extra multiplier when the damage came from a weapon
    minHit = 2.0,  -- body hits smaller than this are ignored (kicks, snowballs, broken windows)
}

-- Health lost per second while the engine is running.
Config.degrade = {
    damaged = 2.0,
    failing = 12.0,
}

-- Power left just before the engine dies. Power fades from 100% at `damaged` down to this.
Config.minTorque = 0.45

-- Limp mode keeps a dead engine running at very low power so you can still crawl to a mechanic.
Config.limpMode = false
Config.limpTorque = 0.15

-- Stop cars catching fire or exploding from engine or fuel tank damage (landing on the roof, etc).
Config.noFires = true
Config.tankFloor = 750.0

-- Can't rock an upside-down car back onto its wheels.
Config.preventFlip = true

-- Holding brake brings the car to a stop and keeps it there with the brake lights on,
-- instead of rolling into reverse. Let go and press again to reverse.
Config.brakeHold = true

-- Roughly how many minutes of driving above 36 km/h before a random tire blowout. 0 turns it off.
Config.tireBlowouts = 0

-- Damage multiplier per vehicle class (GetVehicleClass). Missing classes use 1.0.
Config.classMultiplier = {
    [8] = 0.25,  -- motorcycles
    [9] = 0.7,   -- off-road
    [10] = 0.25, -- industrial
    [14] = 0.5,  -- boats
    [18] = 0.75, -- emergency
    [19] = 0.75, -- military
}

-- Roadside repairs only get the car running again. They have a limited number of uses per
-- vehicle, after that it needs a mechanic.
Config.field = {
    health = 450.0,  -- engine health after a field repair
    uses = 2,
    duration = 12000,
    skillCheck = { 'easy', 'easy', 'medium' }, -- false to skip the minigame
    item = 'repairkit', -- needs ox_inventory, false for no item. Used up on success.
}

-- Full repair, anywhere inside one of these zones.
Config.mechanic = {
    duration = 20000,
    price = 0, -- charged through Config.charge on the server
    blips = true,
    zones = {
        { label = 'Los Santos Customs', coords = vec3(-337.4, -136.9, 39.0), radius = 12.0 },
        { label = 'Los Santos Customs', coords = vec3(731.8, -1088.9, 22.2), radius = 12.0 },
        { label = 'Los Santos Customs', coords = vec3(-1155.0, -2007.0, 13.2), radius = 12.0 },
        { label = 'Los Santos Customs', coords = vec3(1175.0, 2640.0, 37.8), radius = 12.0 },
        { label = 'Beeker\'s Garage', coords = vec3(110.8, 6626.5, 31.8), radius = 12.0 },
    },
}

-- Electric cars can't be patched up at the roadside, only by a mechanic.
Config.electric = {
    'voltic', 'voltic2', 'raiden', 'cyclone', 'tezeract', 'neon', 'khamelion', 'surge',
    'dilettante', 'imorgon', 'iwagen', 'omnisegt', 'virtue', 'caddy', 'caddy2', 'caddy3', 'airtug',
}

-- Hook your framework's money here. Runs on the server, return true if they paid.
Config.charge = function(source, amount)
    return true
end
