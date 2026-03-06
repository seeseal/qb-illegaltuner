-- ╔══════════════════════════════════════════════╗
-- ║     qb-illegaltuner  |  client/neon.lua     ║
-- ╚══════════════════════════════════════════════╝

local QBCore      = exports['qb-core']:GetCoreObject()
local currentMode = nil   -- controls all neon loops via flag; NO TerminateThread

local function StopNeon(veh)
    currentMode = nil   -- all running loops will exit on next iteration
    if veh and DoesEntityExist(veh) then
        SetVehicleNeonLightsColour(veh, 0, 0, 0)
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, false) end
    end
end

local function EnableAllNeons(veh)
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, true) end
end

-- ─────────────────────────────────────────────
--  STATIC / RGB  (single colour, no loop)
-- ─────────────────────────────────────────────

local function ApplyStaticNeon(veh, r, g, b)
    StopNeon(veh)
    currentMode = 'static'
    EnableAllNeons(veh)
    SetVehicleNeonLightsColour(veh, r, g, b)
end

AddEventHandler('qb-illegaltuner:client:openNeonPicker', function(veh, mode)
    local options = {}
    for i, c in ipairs(Config.NeonColours) do
        options[#options + 1] = { label = c.label, value = i }
    end

    local input = lib.inputDialog('🌈 Pick Neon Colour', {
        { type = 'select', label = 'Colour', options = options, required = true },
    })
    if not input then return end

    local chosen = Config.NeonColours[input[1]]
    if not chosen then return end

    ApplyStaticNeon(veh, chosen.r, chosen.g, chosen.b)
    -- Persist
    TriggerServerEvent('qb-illegaltuner:server:saveNeon',
        NetworkGetNetworkIdFromEntity(veh), mode, chosen.r, chosen.g, chosen.b)
    QBCore.Functions.Notify(Lang:t('neon_set', { mode:upper(), chosen.label }), 'success', 3000)
end)

-- For reapply on spawn
AddEventHandler('qb-illegaltuner:client:applyStaticNeon', function(veh, r, g, b)
    if not veh or not DoesEntityExist(veh) then return end
    ApplyStaticNeon(veh, r or 255, g or 255, b or 255)
end)

-- ─────────────────────────────────────────────
--  RAINBOW
-- ─────────────────────────────────────────────

AddEventHandler('qb-illegaltuner:client:startRainbow', function(veh)
    StopNeon(veh)
    currentMode = 'rainbow'
    EnableAllNeons(veh)

    -- Save persisted mode (no colour for rainbow)
    TriggerServerEvent('qb-illegaltuner:server:saveNeon',
        NetworkGetNetworkIdFromEntity(veh), 'rainbow', nil, nil, nil)

    local myMode = currentMode  -- capture for this loop instance
    CreateThread(function()
        local h = 0
        while currentMode == myMode do
            local i  = math.floor(h / 60) % 6
            local f  = (h / 60) - math.floor(h / 60)
            local p  = 0
            local q  = math.floor((1 - f) * 255)
            local t2 = math.floor(f * 255)
            local vv = 255
            local r, g, b
            if     i == 0 then r,g,b = vv,t2,p
            elseif i == 1 then r,g,b = q,vv,p
            elseif i == 2 then r,g,b = p,vv,t2
            elseif i == 3 then r,g,b = p,q,vv
            elseif i == 4 then r,g,b = t2,p,vv
            else               r,g,b = vv,p,q end
            SetVehicleNeonLightsColour(veh, r, g, b)
            h = (h + 1) % 360
            Wait(16)
        end
    end)

    QBCore.Functions.Notify(Lang:t('neon_rainbow'), 'success', 3000)
end)

-- ─────────────────────────────────────────────
--  STROBE
-- ─────────────────────────────────────────────

AddEventHandler('qb-illegaltuner:client:startStrobe', function(veh)
    StopNeon(veh)
    currentMode = 'strobe'
    EnableAllNeons(veh)

    TriggerServerEvent('qb-illegaltuner:server:saveNeon',
        NetworkGetNetworkIdFromEntity(veh), 'strobe', nil, nil, nil)

    local myMode = currentMode
    CreateThread(function()
        local on = true
        while currentMode == myMode do
            for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, on) end
            if on then SetVehicleNeonLightsColour(veh, 255, 255, 255) end
            on = not on
            Wait(120)
        end
    end)

    QBCore.Functions.Notify(Lang:t('neon_strobe'), 'success', 3000)
end)

-- ─────────────────────────────────────────────
--  REMOVAL
-- ─────────────────────────────────────────────

AddEventHandler('qb-illegaltuner:client:neonRemoved', function(veh)
    StopNeon(veh)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then StopNeon(veh) end
end)
