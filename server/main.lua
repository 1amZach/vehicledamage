local cfg = Config

local electric = {}
for _, model in ipairs(cfg.electric) do
    electric[joaat(model)] = true
end

local function mechanicAt(coords)
    for _, zone in ipairs(cfg.mechanic.zones) do
        if #(coords - zone.coords) <= zone.radius then return zone end
    end
end

local busy = {}

lib.callback.register('vehicledamage:repair', function(src, netId, mode)
    if busy[src] then return false end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    if #(coords - GetEntityCoords(vehicle)) > 8.0 then return false, 'too_far' end

    local state = Entity(vehicle).state
    busy[src] = true

    local ok, info = (function()
        if mode == 'mechanic' then
            if not mechanicAt(coords) then return false, 'not_at_mechanic' end
            if cfg.mechanic.price > 0 and not cfg.charge(src, cfg.mechanic.price) then return false, 'no_money' end

            state:set('vdFixes', 0, true)
            return true
        end

        if electric[GetEntityModel(vehicle)] then return false, 'electric' end

        local used = state.vdFixes or 0
        if used >= cfg.field.uses then return false, 'beyond' end

        if cfg.field.item and GetResourceState('ox_inventory') == 'started' then
            if not exports.ox_inventory:RemoveItem(src, cfg.field.item, 1) then return false, 'no_item' end
        end

        state:set('vdFixes', used + 1, true)
        return true, used + 1
    end)()

    busy[src] = nil
    return ok, info
end)
