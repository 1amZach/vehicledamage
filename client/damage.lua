vd = {}

local cfg = Config
local th = cfg.thresholds

local HEALTHY, DAMAGED, FAILING, DEAD = 1, 2, 3, 4

function vd.stateOf(engine)
    if engine > th.damaged then return HEALTHY end
    if engine > th.failing then return DAMAGED end
    if engine > th.dead then return FAILING end
    return DEAD
end

function vd.torqueFor(engine)
    if engine > th.damaged then return 1.0 end
    if engine <= th.dead then return cfg.limpMode and cfg.limpTorque or 0.0 end

    -- straight line from full power at `damaged` down to minTorque just above `dead`
    local t = (engine - th.dead) / (th.damaged - th.dead)
    return cfg.minTorque + (1.0 - cfg.minTorque) * t
end

--[[
    One damage step. `last` is what we saw (and wrote) on the previous step, `now` is
    what the game reports now. The game has already applied its own damage, we add to it.
    Returns the engine health to write back.
]]
function vd.step(last, now, opts)
    local factor = opts.classMult * (opts.weapon and cfg.damage.weapon or 1.0)
    local loss = 0.0

    if now.engine < last.engine then
        loss = loss + (last.engine - now.engine) * cfg.damage.engine
    end

    local bodyHit = last.body - now.body
    if bodyHit >= cfg.damage.minHit then
        loss = loss + bodyHit * cfg.damage.body
    end

    if now.tank < last.tank then
        loss = loss + (last.tank - now.tank) * cfg.damage.tank
    end

    -- start from whichever is higher so a repair from another script isn't undone
    local engine = math.max(last.engine, now.engine) - loss * factor

    if opts.running and engine <= th.damaged and engine > th.dead then
        local rate = engine > th.failing and cfg.degrade.damaged or cfg.degrade.failing
        engine = engine - rate * opts.dt
    end

    -- never let it drop past `dead` (that's where fires start), unless it was already lower
    return math.max(engine, math.min(last.engine, th.dead))
end

local messages = {
    [DAMAGED] = { 'Check engine light is on', 'warning' },
    [FAILING] = { 'Your engine is failing. Get to a mechanic', 'error' },
    [DEAD] = { 'Your engine died', 'error' },
}

local function setDead(vehicle, dead)
    if cfg.limpMode then return end

    SetVehicleUndriveable(vehicle, dead)
    if dead then SetVehicleEngineOn(vehicle, false, true, true) end
end

local function onState(vehicle, state, old)
    if state == DEAD or old == DEAD then
        setDead(vehicle, state == DEAD)
    end

    -- only shout about it getting worse
    if state > old and messages[state] then
        lib.notify({ description = messages[state][1], type = messages[state][2] })
    end
end

local wheels = { 0, 1, 4, 5 }

local function blowTire(vehicle)
    local intact = {}
    for _, i in ipairs(wheels) do
        if not IsVehicleTyreBurst(vehicle, i, false) then intact[#intact + 1] = i end
    end

    if #intact > 0 then
        SetVehicleTyreBurst(vehicle, intact[math.random(#intact)], false, 1000.0)
    end
end

local running = false

local function drive(vehicle)
    running = true

    local classMult = cfg.classMultiplier[GetVehicleClass(vehicle)] or 1.0

    if cfg.noFires then
        SetDisableVehicleEngineFires(vehicle, true)
        SetDisableVehiclePetrolTankFires(vehicle, true)
    end

    local last = {
        engine = GetVehicleEngineHealth(vehicle),
        body = GetVehicleBodyHealth(vehicle),
        tank = GetVehiclePetrolTankHealth(vehicle),
    }

    local state = vd.stateOf(last.engine)
    local torque = vd.torqueFor(last.engine)
    if state == DEAD then setDead(vehicle, true) end

    local lastTick, holding = GetGameTimer(), false

    while cache.vehicle == vehicle and cache.seat == -1 and DoesEntityExist(vehicle) do
        local now = GetGameTimer()

        if now - lastTick >= 100 then
            local dt = (now - lastTick) / 1000
            lastTick = now

            local weapon = HasEntityBeenDamagedByWeapon(vehicle, 0, 2)
            if weapon then ClearEntityLastWeaponDamage(vehicle) end

            local reading = {
                engine = GetVehicleEngineHealth(vehicle),
                body = GetVehicleBodyHealth(vehicle),
                tank = GetVehiclePetrolTankHealth(vehicle),
            }

            local engine = vd.step(last, reading, {
                classMult = classMult,
                weapon = weapon,
                running = GetIsVehicleEngineRunning(vehicle),
                dt = dt,
            })

            if math.abs(engine - reading.engine) > 0.01 then
                SetVehicleEngineHealth(vehicle, engine + 0.0)
            end

            if cfg.noFires and reading.tank < cfg.tankFloor then
                SetVehiclePetrolTankHealth(vehicle, cfg.tankFloor)
                reading.tank = cfg.tankFloor
            end

            last = { engine = engine, body = reading.body, tank = reading.tank }

            local newState = vd.stateOf(engine)
            if newState ~= state then
                onState(vehicle, newState, state)
                state = newState
            end

            torque = vd.torqueFor(engine)

            if cfg.tireBlowouts > 0 and GetEntitySpeed(vehicle) > 10.0
                and math.random() < dt / (cfg.tireBlowouts * 60) then
                blowTire(vehicle)
            end
        end

        -- everything below has to run every frame while it's active
        local everyFrame = false

        if torque < 1.0 then
            -- the multiplier resets each frame, so it has to be set every frame
            SetVehicleEngineTorqueMultiplier(vehicle, math.max(torque, 0.01))
            everyFrame = true
        end

        if cfg.brakeHold then
            local braking = IsDisabledControlPressed(0, 72)
            local forward = GetEntitySpeedVector(vehicle, true).y

            if braking and forward > 1.0 then
                holding = true
            elseif not braking then
                if holding then SetVehicleHandbrake(vehicle, false) end
                holding = false
            end

            if holding and forward < 1.0 then
                DisableControlAction(0, 72, true)
                SetVehicleHandbrake(vehicle, true)
                SetVehicleBrakeLights(vehicle, true)
            end

            everyFrame = everyFrame or holding
        end

        if cfg.preventFlip and math.abs(GetEntityRoll(vehicle)) > 75.0 then
            DisableControlAction(0, 59, true)
            DisableControlAction(0, 60, true)
            everyFrame = true
        end

        Wait(everyFrame and 0 or 100)
    end

    if holding and DoesEntityExist(vehicle) then SetVehicleHandbrake(vehicle, false) end
    running = false
end

local function check()
    if running or cache.seat ~= -1 or not cache.vehicle then return end
    drive(cache.vehicle)
end

-- cache.seat isn't updated until after the callback, so look a frame later
lib.onCache('seat', function()
    CreateThread(function()
        Wait(0)
        check()
    end)
end)

CreateThread(check)
