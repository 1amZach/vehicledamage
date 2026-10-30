local cfg = Config
local busy = false

local electric = {}
for _, model in ipairs(cfg.electric) do
    electric[joaat(model)] = true
end

local function notify(text, kind)
    lib.notify({ description = text, type = kind or 'inform' })
end

local function mechanicAt(coords)
    for _, zone in ipairs(cfg.mechanic.zones) do
        if #(coords - zone.coords) <= zone.radius then return zone end
    end
end

local function hasItem()
    if not cfg.field.item or GetResourceState('ox_inventory') ~= 'started' then return true end
    return (exports.ox_inventory:Search('count', cfg.field.item) or 0) > 0
end

-- the bonnet bone where there is one, otherwise just in front of the car
local function frontOf(vehicle)
    local bone = GetEntityBoneIndexByName(vehicle, 'bonnet')
    if bone ~= -1 then return GetWorldPositionOfEntityBone(vehicle, bone) end

    local _, max = GetModelDimensions(GetEntityModel(vehicle))
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, max.y, 0.0)
end

local function takeControl(vehicle)
    if NetworkHasControlOfEntity(vehicle) then return true end

    NetworkRequestControlOfEntity(vehicle)
    local ok = pcall(lib.waitFor, function()
        if NetworkHasControlOfEntity(vehicle) then return true end
        NetworkRequestControlOfEntity(vehicle)
    end, nil, 3000)

    return ok
end

local reasons = {
    beyond = 'This engine is beyond a roadside fix. Get it to a mechanic',
    no_item = 'You need a repair kit',
    not_at_mechanic = 'You need to be at a mechanic',
    no_money = 'You can\'t afford the repair',
    electric = 'Electric vehicles need a mechanic',
    too_far = 'You\'re too far from the vehicle',
}

local function repair(vehicle)
    if busy then return end

    if cache.vehicle then
        return notify('Get out of the vehicle first', 'error')
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        return notify('No vehicle nearby', 'error')
    end

    local zone = mechanicAt(GetEntityCoords(cache.ped))
    local engine = GetVehicleEngineHealth(vehicle)

    if not zone then
        if engine > cfg.thresholds.damaged then
            return notify('The engine is fine', 'inform')
        end

        if electric[GetEntityModel(vehicle)] then
            return notify(reasons.electric, 'error')
        end

        if (Entity(vehicle).state.vdFixes or 0) >= cfg.field.uses then
            return notify(reasons.beyond, 'error')
        end

        if not hasItem() then
            return notify(reasons.no_item, 'error')
        end
    end

    local front = frontOf(vehicle)
    if #(GetEntityCoords(cache.ped) - front) > 3.0 then
        return notify('Stand at the front of the vehicle', 'error')
    end

    busy = true
    TaskTurnPedToFaceCoord(cache.ped, front.x, front.y, front.z, 800)
    Wait(800)
    SetVehicleDoorOpen(vehicle, 4, false, false)

    local passed = zone or not cfg.field.skillCheck or lib.skillCheck(cfg.field.skillCheck, { 'e' })

    if not passed then
        SetVehicleDoorShut(vehicle, 4, false)
        busy = false
        return notify('Your hand slipped. Try again', 'error')
    end

    local done = lib.progressCircle({
        duration = zone and cfg.mechanic.duration or cfg.field.duration,
        label = zone and 'Repairing the vehicle' or 'Patching up the engine',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    })

    SetVehicleDoorShut(vehicle, 4, false)

    if not done then
        busy = false
        return
    end

    -- get control first, so a failed request doesn't burn a kit or a roadside use
    if not takeControl(vehicle) then
        busy = false
        return notify('Couldn\'t reach the vehicle, try again', 'error')
    end

    local ok, info = lib.callback.await('vehicledamage:repair', false, VehToNet(vehicle), zone and 'mechanic' or 'field')

    if not ok then
        busy = false
        return notify(reasons[info] or 'Repair failed', 'error')
    end

    if zone then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0)
        notify(('Fixed up at %s'):format(zone.label), 'success')
    else
        SetVehicleEngineHealth(vehicle, math.max(engine, cfg.field.health) + 0.0)
        local left = cfg.field.uses - info
        notify(left > 0 and ('Engine patched up. %d roadside fix%s left on this one'):format(left, left == 1 and '' or 'es')
            or 'Engine patched up. That was the last roadside fix it can take', 'success')
    end

    SetVehicleUndriveable(vehicle, false)
    busy = false
end

RegisterCommand('repair', function()
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    repair(vehicle)
end, false)

TriggerEvent('chat:addSuggestion', '/repair', 'Repair the vehicle in front of you')

if GetResourceState('ox_target') == 'started' then
    exports.ox_target:addGlobalVehicle({
        {
            name = 'vehicledamage:repair',
            icon = 'fa-solid fa-wrench',
            label = 'Repair engine',
            bones = { 'bonnet', 'engine' },
            distance = 2.0,
            canInteract = function(entity)
                return not busy and (GetVehicleEngineHealth(entity) <= cfg.thresholds.damaged or mechanicAt(GetEntityCoords(cache.ped)) ~= nil)
            end,
            onSelect = function(data)
                repair(data.entity)
            end,
        },
    })
end

if cfg.mechanic.blips then
    for _, zone in ipairs(cfg.mechanic.zones) do
        local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(blip, 446)
        SetBlipScale(blip, 0.75)
        SetBlipColour(blip, 47)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(zone.label)
        EndTextCommandSetBlipName(blip)
    end
end
