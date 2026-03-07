-- ╔══════════════════════════════════════════════╗
-- ║     qb-illegaltuner  |  client/main.lua     ║
-- ╚══════════════════════════════════════════════╝

local QBCore = exports['qb-core']:GetCoreObject()

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────

local function HasTunerJob()
    local pd = QBCore.Functions.GetPlayerData()
    return pd.job and pd.job.name == Config.RequiredJob
end

local function GetDrivenVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

-- ─────────────────────────────────────────────
--  DRIFT CHIP APPLY / REMOVE  (defined early so all callers can see them)
-- ─────────────────────────────────────────────

local function ApplyDriftChip(v)
    SetVehicleModKit(v, 0)
    SetVehicleMod(v, 15, Config.DriftChip.suspensionLevel, false)
    local baseTraction = GetVehicleHandlingFloat(v, 'CHandlingData', 'fTractionCurveMax')
    SetVehicleHandlingFloat(v, 'CHandlingData', 'fTractionCurveMax',  baseTraction * Config.DriftChip.tractionMultiplier)
    SetVehicleHandlingFloat(v, 'CHandlingData', 'fTractionCurveMin',  baseTraction * Config.DriftChip.tractionMultiplier)
    SetVehicleHandlingFloat(v, 'CHandlingData', 'fTractionLossMult',  Config.DriftChip.tractionLossMult)
    SetVehicleHandlingFloat(v, 'CHandlingData', 'fInitialDragCoeff',  Config.DriftChip.dragCoeff)
    local ptfxDict = 'core'
    RequestNamedPtfxAsset(ptfxDict)
    local t = 0
    while not HasNamedPtfxAssetLoaded(ptfxDict) and t < 2000 do Wait(10); t = t + 10 end
    for wheel = 0, 3 do
        local boneName = ({ 'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr' })[wheel + 1]
        local boneIdx  = GetEntityBoneIndexByName(v, boneName)
        if boneIdx ~= -1 then
            UseParticleFxAssetNextCall(ptfxDict)
            StartParticleFxLoopedOnEntityBone('ent_sht_gravel', v, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, boneIdx, 0.8, false, false, false)
        end
    end
end

local function RemoveDriftChip(v)
    SetVehicleHandlingFloat(v, 'CHandlingData', 'fTractionLossMult',  1.0)
    SetVehicleHandlingFloat(v, 'CHandlingData', 'fTractionCurveMax',  2.73)
    SetVehicleHandlingFloat(v, 'CHandlingData', 'fTractionCurveMin',  1.80)
    SetVehicleHandlingFloat(v, 'CHandlingData', 'fInitialDragCoeff',  Config.DriftChip.baseDragCoeff)
    RemoveParticleFxFromEntity(v)
end

-- ─────────────────────────────────────────────
--  PASSENGER LOOKUP + PURCHASE
-- ─────────────────────────────────────────────

local function GetPassengerThenPurchase(veh, productKey, installMs, label, onSuccess)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getPassenger', function(passengerSrc)
        CreateThread(function()
            local completed = false
            if Config.ProgressBar then
                completed = lib.progressBar({
                    duration     = installMs,
                    label        = 'Installing ' .. label .. '...',
                    useWhileDead = false,
                    canCancel    = true,
                    disable      = { move = true, car = true, combat = true },
                    anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
                })
            else
                completed = true
            end

            if not completed then
                QBCore.Functions.Notify(Lang:t('cancelled'), 'error', 3000)
                return
            end

            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:purchase',
                function(result, reasonOrPrice)
                    if not result then
                        QBCore.Functions.Notify(reasonOrPrice or Lang:t('transaction_failed'), 'error', 4000)
                        return
                    end
                    onSuccess(veh)
                end,
            productKey, nil, passengerSrc, netId)
        end)
    end, netId)
end

-- ─────────────────────────────────────────────
--  ENGINE CHIP
-- ─────────────────────────────────────────────

local function BuyEngineChip(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getEngineChipPrice', function(price, depotValue, bonus)
        CreateThread(function()
            local confirmed = lib.alertDialog({
                header   = '🔧 Engine Chip',
                content  = string.format(
                    'Increases your vehicle\'s top speed by **%d%%**.\n\n💵 Cost: **$%s dirty cash**\n_(Base $%s + 30%% car value $%s)_',
                    Config.EngineChip.speedBoostPercent,
                    lib.math.groupdigits(price),
                    lib.math.groupdigits(Config.EngineChip.basePrice),
                    lib.math.groupdigits(bonus)
                ),
                centered = true,
                cancel   = true,
            })
            if confirmed ~= 'confirm' then return end
            GetPassengerThenPurchase(veh, 'engine_chip', Config.EngineChip.installMs, 'Engine Chip', function(v)
                CreateThread(function()
                    SetVehicleModKit(v, 0)
                    SetVehicleMod(v, 11, 3, false)
                    Wait(500)
                    local cur = GetVehicleHandlingFloat(v, 'CHandlingData', 'fInitialDriveMaxFlatVel')
                    SetVehicleHandlingFloat(v, 'CHandlingData', 'fInitialDriveMaxFlatVel', cur * (1.0 + Config.EngineChip.speedBoostPercent / 100.0))
                    QBCore.Functions.Notify(Lang:t('engine_chip_installed', { Config.EngineChip.speedBoostPercent }), 'success', 5000)
                end)
            end)
        end)
    end, netId)
end

-- ─────────────────────────────────────────────
--  UNINSTALL MENU
-- ─────────────────────────────────────────────

local function OpenRemoveMenu(veh, state)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local items = {}

    items[#items + 1] = { type = 'section', label = 'Remove Mods' }

    if state.engine_chip then
        items[#items + 1] = {
            icon = '🔧', name = 'Remove Engine Chip',
            desc = 'Uninstall the engine speed chip',
            action = 'remove_engine_chip',
        }
    end
    if state.drift_chip then
        items[#items + 1] = {
            icon = '🚗', name = 'Remove Drift Chip',
            desc = 'Uninstall the drift handling chip',
            action = 'remove_drift_chip',
        }
    end
    if state.nos then
        items[#items + 1] = {
            icon = '🚀', name = 'Remove NOS Kit',
            desc = 'Uninstall the nitrous kit',
            action = 'remove_nos',
        }
    end
    if state.neon_mode then
        items[#items + 1] = {
            icon = '💡', name = 'Remove Neon',
            desc = 'Turn off and remove neon lighting',
            action = 'remove_neon',
        }
    end
    if state.has_stance then
        items[#items + 1] = {
            icon = '📐', name = 'Remove Stance Kit',
            desc = 'Reset camber and ride height',
            action = 'remove_stance',
        }
    end

    if #items <= 1 then
        QBCore.Functions.Notify('No mods installed on this vehicle.', 'primary', 3000)
        return
    end

    _currentMenuVeh   = veh
    _currentMenuState = state
    UI_OpenShop(items, 'Remove installed mods')
end

-- ─────────────────────────────────────────────
--  DRIFT CHIP  (dynamic price)
-- ─────────────────────────────────────────────

local function BuyDriftChip(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getDriftChipPrice', function(price, depotValue, bonus)
        CreateThread(function()
            local confirmed = lib.alertDialog({
                header   = '🚗 Drift Chip',
                content  = string.format(
                    'Reduces traction by **20%%** and produces heavy tyre smoke — turns your car into a drift machine.\n\n💵 Cost: **$%s dirty cash**\n_(Base $%s + 20%% car value $%s)_',
                    lib.math.groupdigits(price),
                    lib.math.groupdigits(Config.DriftChip.basePrice),
                    lib.math.groupdigits(bonus)
                ),
                centered = true,
                cancel   = true,
            })
            if confirmed ~= 'confirm' then return end
            GetPassengerThenPurchase(veh, 'drift_chip', Config.DriftChip.installMs, 'Drift Chip', function(v)
                ApplyDriftChip(v)
                QBCore.Functions.Notify(Lang:t('drift_chip_installed'), 'success', 4000)
            end)
        end)
    end, netId)
end

-- ─────────────────────────────────────────────
--  MAIN MENU  — reflects installed state
-- ─────────────────────────────────────────────

-- ─────────────────────────────────────────────
--  SHARED MENU STATE  (used by shopAction handler)
-- ─────────────────────────────────────────────

_currentMenuVeh   = nil
_currentMenuState = nil

-- ─────────────────────────────────────────────
--  BUILD SHOP ITEMS  — shared between ramp and regular menu
-- ─────────────────────────────────────────────

local function BuildShopItems(veh, state, isTuner, enginePrice, driftPrice)
    local items = {}

    -- ── PERFORMANCE ──────────────────────────────
    items[#items + 1] = { type = 'section', label = 'Performance' }

    -- Engine Chip
    if state.engine_chip then
        items[#items + 1] = { icon = '🔧', name = 'Engine Chip', desc = 'Already installed · PD /removechip required', installed = true }
    elseif state.drift_chip then
        items[#items + 1] = { icon = '🔧', name = 'Engine Chip  🚫 Blocked', desc = 'Remove drift chip first', disabled = true }
    else
        local ep = enginePrice or Config.EngineChip.basePrice
        items[#items + 1] = {
            icon = '🔧', name = 'Engine Chip  (+' .. Config.EngineChip.speedBoostPercent .. '% top speed)',
            desc = 'Base $' .. Config.EngineChip.basePrice .. ' + 30% car value · dirty cash' .. (not isTuner and '  🔒 Tuner required' or ''),
            price = ep, action = 'buy_engine_chip', disabled = not isTuner,
        }
    end

    -- Drift Chip
    if state.drift_chip then
        items[#items + 1] = { icon = '🚗', name = 'Drift Chip', desc = 'Soft suspension + high traction loss', installed = true }
    elseif state.engine_chip then
        items[#items + 1] = { icon = '🚗', name = 'Drift Chip  🚫 Blocked', desc = 'Remove engine chip first', disabled = true }
    else
        local dp = driftPrice or Config.DriftChip.basePrice
        items[#items + 1] = {
            icon = '🚗', name = 'Drift Chip',
            desc = 'Base $' .. Config.DriftChip.basePrice .. ' + 20% car value · dirty cash' .. (not isTuner and '  🔒 Tuner required' or ''),
            price = dp, action = 'buy_drift_chip', disabled = not isTuner,
        }
    end

    -- Stance Kit
    if state.has_stance then
        items[#items + 1] = { icon = '📐', name = 'Stance Kit', desc = 'Already installed', installed = true }
    else
        items[#items + 1] = {
            icon = '📐', name = 'Stance Kit  ($' .. lib.math.groupdigits(Config.StanceKit.price) .. ')',
            desc = 'Camber · ride height · wheel distance' .. (not isTuner and '  🔒 Tuner required' or ''),
            price = Config.StanceKit.price, action = 'buy_stance_kit', disabled = not isTuner,
        }
    end

    -- ── NITROUS ──────────────────────────────────
    items[#items + 1] = { type = 'section', label = 'Nitrous' }

    if state.nos then
        items[#items + 1] = { icon = '🚀', name = 'Nitrous Kit  (installed)', desc = 'Refill at NOS station · LEFT SHIFT to activate', installed = true }
    else
        items[#items + 1] = {
            icon = '🚀', name = 'Install Nitrous Kit  ($' .. lib.math.groupdigits(Config.Nitrous.price) .. ')',
            desc = '+' .. Config.Nitrous.boostMPH .. ' MPH · ' .. Config.Nitrous.boostDuration .. 's burst · refill at station' .. (not isTuner and '  🔒 Tuner required' or ''),
            price = Config.Nitrous.price, action = 'buy_nitrous_kit', disabled = not isTuner,
        }
    end

    -- ── NEON ─────────────────────────────────────
    items[#items + 1] = { type = 'section', label = 'Neon Kits' }

    local neonLock = not isTuner and '  🔒 Tuner required' or ''
    local neonDefs = {
        { key = 'neon_static',  icon = '💡', name = 'Static Neon',  price = Config.NeonPrices.static  },
        { key = 'neon_rainbow', icon = '🌈', name = 'Rainbow Neon', price = Config.NeonPrices.rainbow },
        { key = 'neon_rgb',     icon = '🎨', name = 'RGB Neon',     price = Config.NeonPrices.rgb     },
        { key = 'neon_strobe',  icon = '⚡', name = 'Strobe Neon',  price = Config.NeonPrices.strobe  },
    }
    for _, n in ipairs(neonDefs) do
        items[#items + 1] = {
            icon = n.icon, name = n.name .. '  ($' .. lib.math.groupdigits(n.price) .. ')' .. neonLock,
            desc = 'Neon lighting · dirty cash',
            price = n.price, action = 'buy_neon', actionData = { key = n.key },
            disabled = not isTuner,
        }
    end

    -- ── MANAGEMENT ───────────────────────────────
    items[#items + 1] = { type = 'section', label = 'Management' }
    items[#items + 1] = {
        icon = '🗑️', name = 'Remove Mods',
        desc = 'Uninstall any mod from this vehicle',
        action = 'open_remove_menu',
        disabled = not isTuner,
    }

    return items
end

local function OpenMenu(veh, state)
    _currentMenuVeh   = veh
    _currentMenuState = state
    local netId = NetworkGetNetworkIdFromEntity(veh)

    if not state.engine_chip and not state.drift_chip then
        QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getEngineChipPrice', function(enginePrice)
            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getDriftChipPrice', function(driftPrice)
                local items = BuildShopItems(veh, state, true, enginePrice, driftPrice)
                UI_OpenShop(items, 'Tuner Shop')
            end, netId)
        end, netId)
    else
        local items = BuildShopItems(veh, state, true, nil, nil)
        UI_OpenShop(items, 'Tuner Shop')
    end
end

-- ─────────────────────────────────────────────
--  RAMP MENU  — visible to all, install = tuner only
-- ─────────────────────────────────────────────

local function OpenRampMenu(veh, state, enginePrice, driftPrice)
    _currentMenuVeh   = veh
    _currentMenuState = state
    local isTuner = HasTunerJob()
    local items   = BuildShopItems(veh, state, isTuner, enginePrice, driftPrice)
    UI_OpenShop(items, isTuner and 'Tuner Ramp' or 'Tuner Ramp  🔒 View Only')
end

-- ─────────────────────────────────────────────
--  RAMP ZONES  — 4 workspaces, public view / tuner install
-- ─────────────────────────────────────────────

local inRamp    = false
local menuOpen  = false   -- prevents missed re-opens while a callback is in-flight

for _, rampCoords in ipairs(Config.RampLocations) do
    lib.zones.sphere({
        coords = rampCoords,
        radius = Config.RampRadius,
        onEnter = function()
            local veh = GetDrivenVehicle()
            if not veh then
                QBCore.Functions.Notify(Lang:t('ramp_no_vehicle'), 'error', 4000)
                return
            end
            inRamp = true

            -- Poll every frame (Wait(0)) so no E-press is ever missed.
            -- The old Wait(500) only checked twice per second; IsControlJustPressed
            -- is only true for a single ~16 ms frame, so presses were routinely dropped.
            CreateThread(function()
                while inRamp do
                    if not menuOpen and IsControlJustPressed(0, 51) then
                        local v = GetDrivenVehicle()
                        if not v then
                            QBCore.Functions.Notify(Lang:t('ramp_no_vehicle'), 'error', 3000)
                        else
                            menuOpen = true
                            local netId = NetworkGetNetworkIdFromEntity(v)
                            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getVehicleState', function(state)
                                if not state then menuOpen = false return end

                                -- Only fetch chip prices when neither chip is installed;
                                -- if one is installed the other is blocked so we need no price.
                                if not state.engine_chip and not state.drift_chip then
                                    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getEngineChipPrice', function(enginePrice)
                                        QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getDriftChipPrice', function(driftPrice)
                                            menuOpen = false
                                            OpenRampMenu(v, state, enginePrice, driftPrice)
                                        end, netId)
                                    end, netId)
                                else
                                    menuOpen = false
                                    OpenRampMenu(v, state, nil, nil)
                                end
                            end, netId)
                        end
                    end
                    Wait(0)
                end
            end)
        end,
        onExit = function()
            inRamp   = false
            menuOpen = false
        end,
    })
end

-- ─────────────────────────────────────────────
--  SHOP ACTION HANDLER  — routes NUI clicks to purchase logic
-- ─────────────────────────────────────────────

RegisterNetEvent('qb-illegaltuner:client:shopAction', function(action, data)
    local veh   = _currentMenuVeh
    local state = _currentMenuState
    if not veh or not DoesEntityExist(veh) then
        QBCore.Functions.Notify('Vehicle not found.', 'error', 3000)
        return
    end

    UI_CloseShop()

    if action == 'buy_engine_chip' then
        BuyEngineChip(veh)

    elseif action == 'buy_drift_chip' then
        BuyDriftChip(veh)

    elseif action == 'buy_stance_kit' then
        GetPassengerThenPurchase(veh, 'stance_kit', Config.StanceKit.installMs, 'Stance Kit', function(v)
            TriggerEvent('qb-illegaltuner:client:openStance', v)
        end)

    elseif action == 'buy_nitrous_kit' then
        GetPassengerThenPurchase(veh, 'nitrous_kit', Config.Nitrous.installMs, 'Nitrous Kit', function(v)
            TriggerEvent('qb-illegaltuner:client:nosInstalled', v)
        end)

    elseif action == 'buy_neon' then
        local key = data and data.key or 'neon_static'
        local neonEventMap = {
            neon_static  = function(v) TriggerEvent('qb-illegaltuner:client:openNeonPicker', v, 'static') end,
            neon_rainbow = function(v) TriggerEvent('qb-illegaltuner:client:startRainbow', v) end,
            neon_rgb     = function(v) TriggerEvent('qb-illegaltuner:client:openNeonPicker', v, 'rgb') end,
            neon_strobe  = function(v) TriggerEvent('qb-illegaltuner:client:startStrobe', v) end,
        }
        local fn = neonEventMap[key]
        if fn then
            GetPassengerThenPurchase(veh, key, Config.NeonInstallMs, key, fn)
        end

    elseif action == 'open_remove_menu' then
        -- Re-fetch state so the remove menu is always up to date
        local netId = NetworkGetNetworkIdFromEntity(veh)
        QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getVehicleState', function(freshState)
            if freshState then
                OpenRemoveMenu(veh, freshState)
            end
        end, netId)

    -- ── Remove actions ─────────────────────
    elseif action == 'remove_engine_chip' then
        CreateThread(function()
            local ok = lib.progressBar({ duration = Config.EngineChip.removeMs, label = 'Removing Engine Chip...', useWhileDead = false, canCancel = true, disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 } })
            if not ok then return end
            local netId = NetworkGetNetworkIdFromEntity(veh)
            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                local cur = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
                SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', math.max(10.0, cur / (1.0 + Config.EngineChip.speedBoostPercent / 100.0)))
                QBCore.Functions.Notify(Lang:t('engine_chip_removed'), 'success', 4000)
            end, netId, 'engine_chip')
        end)

    elseif action == 'remove_drift_chip' then
        CreateThread(function()
            local ok = lib.progressBar({ duration = Config.DriftChip.removeMs, label = 'Removing Drift Chip...', useWhileDead = false, canCancel = true, disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 } })
            if not ok then return end
            local netId = NetworkGetNetworkIdFromEntity(veh)
            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                RemoveDriftChip(veh)
                QBCore.Functions.Notify(Lang:t('drift_chip_removed'), 'success', 4000)
            end, netId, 'drift_chip')
        end)

    elseif action == 'remove_nos' then
        CreateThread(function()
            local ok = lib.progressBar({ duration = Config.Nitrous.removeMs, label = 'Removing NOS Kit...', useWhileDead = false, canCancel = true, disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 } })
            if not ok then return end
            local netId = NetworkGetNetworkIdFromEntity(veh)
            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                TriggerEvent('qb-illegaltuner:client:nosRemoved')
                QBCore.Functions.Notify(Lang:t('nos_removed'), 'success', 4000)
            end, netId, 'nos')
        end)

    elseif action == 'remove_neon' then
        CreateThread(function()
            local ok = lib.progressBar({ duration = Config.NeonRemoveMs, label = 'Removing Neon...', useWhileDead = false, canCancel = true, disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 } })
            if not ok then return end
            local netId = NetworkGetNetworkIdFromEntity(veh)
            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                TriggerEvent('qb-illegaltuner:client:neonRemoved', veh)
                QBCore.Functions.Notify(Lang:t('neon_removed'), 'success', 4000)
            end, netId, 'neon')
        end)

    elseif action == 'remove_stance' then
        CreateThread(function()
            local ok = lib.progressBar({ duration = Config.StanceKit.removeMs, label = 'Removing Stance Kit...', useWhileDead = false, canCancel = true, disable = { move = true, car = true, combat = true }, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 } })
            if not ok then return end
            local netId = NetworkGetNetworkIdFromEntity(veh)
            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                TriggerEvent('qb-illegaltuner:client:stanceRemoved', veh)
                QBCore.Functions.Notify(Lang:t('stance_removed'), 'success', 4000)
            end, netId, 'stance')
        end)
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    -- Give a moment for the player's vehicle data to settle
    Wait(5000)
    local veh = GetDrivenVehicle()
    if veh then
        TriggerEvent('qb-illegaltuner:client:reapplyMods', veh)
    end
end)

-- Reapply when entering a vehicle using a polling thread
CreateThread(function()
    local lastVeh = 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and veh ~= lastVeh then
            lastVeh = veh
            Wait(1000) -- let the vehicle fully load
            TriggerEvent('qb-illegaltuner:client:reapplyMods', veh)
        elseif veh == 0 then
            lastVeh = 0
        end
    end
end)

RegisterNetEvent('qb-illegaltuner:client:reapplyMods', function(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getVehicleState', function(state)
        if not state then return end

        -- Engine chip — 15% top speed boost
        if state.engine_chip then
            SetVehicleModKit(veh, 0)
            SetVehicleMod(veh, 11, 3, false)
            Wait(500)
            local cur = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', cur * (1.0 + Config.EngineChip.speedBoostPercent / 100.0))
        end

        -- Drift chip
        if state.drift_chip then
            ApplyDriftChip(veh)
        end

        -- NOS
        if state.nos then
            local cooldownUntil = state.nos_cooldown_until or 0
            local isEmpty       = state.nos_empty or false
            TriggerEvent('qb-illegaltuner:client:nosInstalled', veh, true, cooldownUntil, isEmpty)
        end

        -- Neon
        if state.neon_mode then
            if state.neon_mode == 'rainbow' then
                TriggerEvent('qb-illegaltuner:client:startRainbow', veh)
            elseif state.neon_mode == 'strobe' then
                TriggerEvent('qb-illegaltuner:client:startStrobe', veh)
            else
                -- static or rgb — need colour
                TriggerEvent('qb-illegaltuner:client:applyStaticNeon', veh, state.neon_r, state.neon_g, state.neon_b)
            end
        end

        -- Stance
        if state.has_stance and state.stance then
            TriggerEvent('qb-illegaltuner:client:applyStance', veh, state.stance.camber, state.stance.height, state.stance.wheeldist)
        end
    end, netId)
end)

-- ─────────────────────────────────────────────
--  /checkchip  — find nearest vehicle and send to server
-- ─────────────────────────────────────────────

RegisterNetEvent('qb-illegaltuner:client:checkChip', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then
        QBCore.Functions.Notify('You must be sitting inside a vehicle to check its chip.', 'error', 3000)
        return
    end
    TriggerServerEvent('qb-illegaltuner:server:checkChip', NetworkGetNetworkIdFromEntity(veh))
end)

RegisterNetEvent('qb-illegaltuner:client:pdRemoveChipRequest', function()
    -- Find nearest vehicle within 5m
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh    = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    if not veh or veh == 0 then
        QBCore.Functions.Notify('No vehicle nearby.', 'error', 3000)
        return
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('qb-illegaltuner:server:pdRemoveChip', netId)
end)

RegisterNetEvent('qb-illegaltuner:client:engineChipRemoved', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or not DoesEntityExist(veh) then return end
    local cur = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', math.max(10.0, cur / (1.0 + Config.EngineChip.speedBoostPercent / 100.0)))
end)