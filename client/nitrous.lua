-- ╔══════════════════════════════════════════════╗
-- ║   qb-illegaltuner  |  client/nitrous.lua    ║
-- ╚══════════════════════════════════════════════╝

local QBCore      = exports['qb-core']:GetCoreObject()
local nosInstalled = false
local nosActive    = false
local nosCooldown  = false   -- visual/local cooldown flag (30 min enforced server-side)
local nosVehicle   = nil
local nosThread    = nil

local function MPHtoMS(mph) return mph * 0.44704 end

local function DrawNOSHud()
    if not nosInstalled then return end
    local text
    if nosActive then
        text = '~r~● NOS ACTIVE'
    elseif nosCooldown then
        text = '~y~● NOS COOLING DOWN  (return to shop to refill)'
    else
        text = '~g~● NOS READY  ~w~[LEFT SHIFT]'
    end
    SetTextFont(4)
    SetTextScale(0.38, 0.38)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.02, 0.92)
end

local function ActivateNOS(veh)
    if nosActive or nosCooldown then return end
    nosActive = true

    local boostMS = MPHtoMS(Config.Nitrous.boostMPH)
    local baseSpd = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', baseSpd + boostMS)
    QBCore.Functions.Notify(Lang:t('nos_activated'), 'success', 2000)

    -- Notify server to start 30-min cooldown
    TriggerServerEvent('qb-illegaltuner:server:nosUsed', NetworkGetNetworkIdFromEntity(veh))

    -- Particle FX
    pcall(function()
        RequestNamedPtfxAsset('veh_exhaust_nos')
        local t = 0
        while not HasNamedPtfxAssetLoaded('veh_exhaust_nos') and t < 2000 do
            Wait(10); t = t + 10
        end
        if HasNamedPtfxAssetLoaded('veh_exhaust_nos') then
            UseParticleFxAssetNextCall('veh_exhaust_nos')
        end
    end)

    Wait(Config.Nitrous.boostDuration * 1000)

    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', baseSpd)
    nosActive   = false
    nosCooldown = true   -- local visual flag — actual cooldown is in DB (30 min)
    -- Don't reset nosCooldown client-side; refill from shop clears it
end

local function StartNOSThread(veh)
    if nosThread then return end
    nosThread = CreateThread(function()
        while nosInstalled and nosVehicle and DoesEntityExist(nosVehicle) do
            Wait(0)
            DrawNOSHud()
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) == nosVehicle
            and GetPedInVehicleSeat(nosVehicle, -1) == ped then
                if IsControlJustPressed(0, Config.Nitrous.key) then
                    if nosActive then
                        -- already active, ignore
                    elseif nosCooldown then
                        QBCore.Functions.Notify(Lang:t('nos_no_refill_here'), 'error', 3000)
                    else
                        CreateThread(function() ActivateNOS(nosVehicle) end)
                    end
                end
            end
        end
        nosThread = nil
    end)
end

-- ─────────────────────────────────────────────
--  EVENTS
-- ─────────────────────────────────────────────

-- silent = true when called from reapplyMods (no notification)
AddEventHandler('qb-illegaltuner:client:nosInstalled', function(veh, silent)
    nosInstalled = true
    nosVehicle   = veh
    nosCooldown  = false
    nosActive    = false
    if not silent then
        QBCore.Functions.Notify(Lang:t('nos_installed'), 'success', 5000)
    end
    StartNOSThread(veh)
end)

AddEventHandler('qb-illegaltuner:client:nosRefilled', function(veh)
    if not nosInstalled then
        QBCore.Functions.Notify(Lang:t('nos_not_installed'), 'error', 4000)
        return
    end
    nosActive   = false
    nosCooldown = false
    nosVehicle  = veh
    QBCore.Functions.Notify(Lang:t('nos_refilled'), 'success', 4000)
    StartNOSThread(veh)
end)

AddEventHandler('qb-illegaltuner:client:nosRemoved', function()
    nosInstalled = false
    nosActive    = false
    nosCooldown  = false
    nosVehicle   = nil
    nosThread    = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    nosInstalled = false
    nosActive    = false
    nosCooldown  = false
end)
