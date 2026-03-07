-- ╔══════════════════════════════════════════════╗
-- ║   qb-illegaltuner  |  client/nitrous.lua    ║
-- ╚══════════════════════════════════════════════╝
-- NOTE: os.time() is server-only in FiveM. All time tracking
-- uses GetGameTimer() (ms) on the client side.

local QBCore         = exports['qb-core']:GetCoreObject()
local nosInstalled   = false
local nosActive      = false
local nosEmpty       = false   -- canister spent, needs refill
local nosVehicle     = nil
local nosThread      = nil
local nosCountdown   = 0.0     -- burn seconds remaining (HUD bar)

-- Cooldown tracked as a game-timer deadline (ms).
-- 0 means no cooldown active.
local nosCooldownEndMs = 0

local TORQUE_BOOST = 0.50   -- 50% fInitialDriveForce surge during burn

local function MPHtoMS(mph) return mph * 0.44704 end

local function NowMs() return GetGameTimer() end
local function NowSec() return GetGameTimer() / 1000.0 end

local function CooldownRemainingSec()
    if nosCooldownEndMs <= 0 then return 0 end
    return math.max(0.0, (nosCooldownEndMs - NowMs()) / 1000.0)
end

-- ─────────────────────────────────────────────
--  HUD  — delegates to NUI panel (client/ui.lua)
-- ─────────────────────────────────────────────

local function FormatCooldown(secs)
    local s = math.ceil(secs)
    local m = math.floor(s / 60)
    local r = s % 60
    if m > 0 then
        return string.format('%dm %ds', m, r)
    else
        return string.format('%ds', r)
    end
end

local function UpdateNOSHud()
    if not nosInstalled then return end
    local remaining = CooldownRemainingSec()

    if nosActive then
        local fraction = math.max(0.0, nosCountdown / Config.Nitrous.boostDuration)
        UI_UpdateNos('active', fraction, string.format('%.1fs', nosCountdown))
    elseif remaining > 0 then
        -- cooldown progress bar drains from 1→0
        local fraction = remaining / Config.Nitrous.cooldown
        UI_UpdateNos('cooldown', fraction, FormatCooldown(remaining))
    elseif nosEmpty then
        UI_UpdateNos('empty', 0, '')
    else
        UI_UpdateNos('ready', 1, '')
    end
end

-- ─────────────────────────────────────────────
--  ACTIVATE
-- ─────────────────────────────────────────────

local function ActivateNOS(veh)
    if nosActive or nosEmpty then return end

    local remaining = CooldownRemainingSec()
    if remaining > 0 then
        QBCore.Functions.Notify('⏳ NOS cooldown — ' .. FormatCooldown(remaining) .. ' remaining.', 'error', 3000)
        return
    end

    nosActive    = true
    nosCountdown = Config.Nitrous.boostDuration

    -- Snapshot engine health at moment of activation — held frozen for burn duration
    local lockedHealth = GetVehicleEngineHealth(veh)

    -- Boost: fInitialDriveForce for a real torque surge
    local baseDriveForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce')
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce', baseDriveForce * (1.0 + TORQUE_BOOST))

    local boostMS = MPHtoMS(Config.Nitrous.boostMPH)
    local baseSpd = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', baseSpd + boostMS)

    SetVehicleEngineOn(veh, true, true, false)

    QBCore.Functions.Notify(Lang:t('nos_activated'), 'success', 2000)
    TriggerServerEvent('qb-illegaltuner:server:nosUsed', NetworkGetNetworkIdFromEntity(veh))

    -- Set cooldown deadline locally so HUD ticks immediately
    nosCooldownEndMs = NowMs() + (Config.Nitrous.cooldown * 1000)

    local elapsed  = 0
    local interval = 100
    while elapsed < Config.Nitrous.boostDuration * 1000 do
        Wait(interval)
        elapsed      = elapsed + interval
        nosCountdown = math.max(0.0, Config.Nitrous.boostDuration - elapsed / 1000.0)
        SetVehicleEngineHealth(veh, lockedHealth)
        UpdateNOSHud()
    end

    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce',      baseDriveForce)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', baseSpd)

    nosActive    = false
    nosEmpty     = true
    nosCountdown = 0.0

    QBCore.Functions.Notify(Lang:t('nos_empty'), 'error', 5000)
end

-- ─────────────────────────────────────────────
--  INPUT LOOP
-- ─────────────────────────────────────────────

local function StartNOSThread(veh)
    -- Always kill any existing thread so it restarts fresh with the new vehicle
    nosThread = nil
    UI_ShowNos(true)
    nosThread = CreateThread(function()
        while nosInstalled do
            Wait(500)  -- NUI update every 500ms is plenty
            local ped    = PlayerPedId()
            local curVeh = GetVehiclePedIsIn(ped, false)

            UpdateNOSHud()

            if curVeh ~= 0 and curVeh == nosVehicle and GetPedInVehicleSeat(nosVehicle, -1) == ped then
                if IsControlJustPressed(0, Config.Nitrous.key) then
                    local remaining = CooldownRemainingSec()
                    if nosActive then
                        -- burning, ignore
                    elseif remaining > 0 then
                        QBCore.Functions.Notify('⏳ NOS cooldown — ' .. FormatCooldown(remaining) .. ' remaining.', 'error', 3000)
                    elseif nosEmpty then
                        QBCore.Functions.Notify(Lang:t('nos_no_refill_here'), 'error', 3000)
                    else
                        CreateThread(function() ActivateNOS(nosVehicle) end)
                    end
                end
            end
        end
        UI_ShowNos(false)
        nosThread = nil
    end)
end

-- ─────────────────────────────────────────────
--  NOS REFILL STATION ZONE  (no map blip)
-- ─────────────────────────────────────────────

local inRefillZone = false

lib.zones.sphere({
    coords  = Config.NosRefillStation.coords,
    radius  = Config.NosRefillStation.radius,
    onEnter = function()
        inRefillZone = true
        CreateThread(function()
            while inRefillZone do
                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)

                if veh ~= 0 and nosInstalled and GetPedInVehicleSeat(veh, -1) == ped and not nosActive then
                    local remaining = CooldownRemainingSec()

                    if remaining > 0 then
                        -- On cooldown — show live timer, no interaction
                        SetTextFont(4)
                        SetTextScale(0.38, 0.38)
                        SetTextColour(255, 200, 0, 220)
                        SetTextOutline()
                        BeginTextCommandDisplayText('STRING')
                        AddTextComponentSubstringPlayerName('~y~⏳ Refill cooldown: ~w~' .. FormatCooldown(remaining))
                        EndTextCommandDisplayText(0.5, 0.88)

                    elseif nosEmpty then
                        -- Ready to refill — show price prompt
                        local priceLabel = lib.math.groupdigits(Config.Nitrous.refillPrice)
                        SetTextFont(4)
                        SetTextScale(0.38, 0.38)
                        SetTextColour(255, 255, 255, 220)
                        SetTextOutline()
                        BeginTextCommandDisplayText('STRING')
                        AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to refill NOS · $' .. priceLabel)
                        EndTextCommandDisplayText(0.5, 0.88)

                        if IsControlJustPressed(0, 51) then
                            local netId = NetworkGetNetworkIdFromEntity(veh)
                            QBCore.Functions.TriggerCallback(
                                'qb-illegaltuner:server:nosStationRefill',
                                function(result, reason)
                                    if not result then
                                        QBCore.Functions.Notify(reason or Lang:t('transaction_failed'), 'error', 4000)
                                        return
                                    end
                                    nosEmpty         = false
                                    nosCooldownEndMs = 0
                                    QBCore.Functions.Notify(Lang:t('nos_refilled'), 'success', 4000)
                                end,
                            netId)
                        end
                    else
                        -- Already full
                        SetTextFont(4)
                        SetTextScale(0.38, 0.38)
                        SetTextColour(255, 255, 255, 180)
                        SetTextOutline()
                        BeginTextCommandDisplayText('STRING')
                        AddTextComponentSubstringPlayerName('~g~✅ NOS is fully charged.')
                        EndTextCommandDisplayText(0.5, 0.88)
                    end
                end
                Wait(0)
            end
        end)
    end,
    onExit = function()
        inRefillZone = false
    end,
})

-- ─────────────────────────────────────────────
--  EVENTS
-- ─────────────────────────────────────────────

-- silent = true when called from reapplyMods (no notification)
AddEventHandler('qb-illegaltuner:client:nosInstalled', function(veh, silent, cooldownUntil, isEmpty)
    nosInstalled = true
    nosVehicle   = veh
    nosActive    = false

    -- nosEmpty comes explicitly from DB — cooldown expiring does NOT refill the canister
    nosEmpty = isEmpty or false

    if cooldownUntil and cooldownUntil > 0 then
        nosCooldownEndMs = NowMs() + (cooldownUntil * 1000)
    else
        nosCooldownEndMs = 0
    end

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
    nosActive        = false
    nosEmpty         = false
    nosCooldownEndMs = 0
    nosVehicle       = veh
    QBCore.Functions.Notify(Lang:t('nos_refilled'), 'success', 4000)
    StartNOSThread(veh)
end)

AddEventHandler('qb-illegaltuner:client:nosRemoved', function()
    nosInstalled     = false
    nosActive        = false
    nosEmpty         = false
    nosCooldownEndMs = 0
    nosVehicle       = nil
    nosThread        = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    nosInstalled     = false
    nosActive        = false
    nosEmpty         = false
    nosCooldownEndMs = 0
end)