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

local function RunProgress(label, ms, cb)
    if not Config.ProgressBar then cb(true) return end
    lib.progressBar({
        duration     = ms,
        label        = label,
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = false, combat = true },
        anim         = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
    }, function(cancelled) cb(not cancelled) end)
end

-- ─────────────────────────────────────────────
--  PASSENGER LOOKUP + PURCHASE
-- ─────────────────────────────────────────────

local function GetPassengerThenPurchase(veh, productKey, installMs, label, onSuccess)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getPassenger', function(passengerSrc)
        RunProgress(Lang:t('installing', { label }), installMs, function(ok)
            if not ok then
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
        lib.alertDialog({
            header   = '🔧 Engine Chip',
            content  = string.format(
                'Adds **+%d MPH** to your top speed.\n\n💵 Cost: **$%s black money**\n_(Base $%s + 30%% car value $%s)_',
                Config.EngineChip.speedBoostMPH,
                lib.math.groupdigits(price),
                lib.math.groupdigits(Config.EngineChip.basePrice),
                lib.math.groupdigits(bonus)
            ),
            centered = true,
            cancel   = true,
        }, function(confirmed)
            if not confirmed then return end
            GetPassengerThenPurchase(veh, 'engine_chip', Config.EngineChip.installMs, 'Engine Chip', function(v)
                local cur   = GetVehicleHandlingFloat(v, 'CHandlingData', 'fInitialDriveMaxFlatVel')
                local boost = Config.EngineChip.speedBoostMPH * 0.44704
                SetVehicleHandlingFloat(v, 'CHandlingData', 'fInitialDriveMaxFlatVel', cur + boost)
                SetVehicleEngineUpgrade(v, 3)
                QBCore.Functions.Notify(Lang:t('engine_chip_installed', { Config.EngineChip.speedBoostMPH }), 'success', 5000)
            end)
        end)
    end, netId)
end

-- ─────────────────────────────────────────────
--  UNINSTALL MENU
-- ─────────────────────────────────────────────

local function OpenRemoveMenu(veh, state)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local opts  = {}

    if state.engine_chip then
        opts[#opts + 1] = {
            title    = '🔧 Remove Engine Chip',
            icon     = 'microchip',
            onSelect = function()
                RunProgress(Lang:t('removing', { 'Engine Chip' }), Config.EngineChip.removeMs, function(ok)
                    if not ok then return end
                    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                        if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                        local cur   = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
                        local boost = Config.EngineChip.speedBoostMPH * 0.44704
                        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', math.max(10.0, cur - boost))
                        QBCore.Functions.Notify(Lang:t('engine_chip_removed'), 'success', 4000)
                    end, netId, 'engine_chip')
                end)
            end,
        }
    end

    if state.drift_chip then
        opts[#opts + 1] = {
            title    = '🚗 Remove Drift Chip',
            icon     = 'car',
            onSelect = function()
                RunProgress(Lang:t('removing', { 'Drift Chip' }), Config.DriftChip.removeMs, function(ok)
                    if not ok then return end
                    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                        if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                        -- Reset handling floats to default
                        SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionLossMulti', 1.0)
                        QBCore.Functions.Notify(Lang:t('drift_chip_removed'), 'success', 4000)
                    end, netId, 'drift_chip')
                end)
            end,
        }
    end

    if state.nos then
        opts[#opts + 1] = {
            title    = '🚀 Remove NOS Kit',
            icon     = 'bolt',
            onSelect = function()
                RunProgress(Lang:t('removing', { 'NOS Kit' }), Config.Nitrous.removeMs, function(ok)
                    if not ok then return end
                    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                        if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                        TriggerEvent('qb-illegaltuner:client:nosRemoved')
                        QBCore.Functions.Notify(Lang:t('nos_removed'), 'success', 4000)
                    end, netId, 'nos')
                end)
            end,
        }
    end

    if state.neon_mode then
        opts[#opts + 1] = {
            title    = '💡 Remove Neon',
            icon     = 'circle',
            onSelect = function()
                RunProgress(Lang:t('removing', { 'Neon' }), Config.NeonRemoveMs, function(ok)
                    if not ok then return end
                    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                        if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                        TriggerEvent('qb-illegaltuner:client:neonRemoved', veh)
                        QBCore.Functions.Notify(Lang:t('neon_removed'), 'success', 4000)
                    end, netId, 'neon')
                end)
            end,
        }
    end

    if state.has_stance then
        opts[#opts + 1] = {
            title    = '📐 Remove Stance Kit',
            icon     = 'sliders',
            onSelect = function()
                RunProgress(Lang:t('removing', { 'Stance Kit' }), Config.StanceKit.removeMs, function(ok)
                    if not ok then return end
                    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:removeMod', function(result, reason)
                        if not result then QBCore.Functions.Notify(reason, 'error', 4000) return end
                        TriggerEvent('qb-illegaltuner:client:stanceRemoved', veh)
                        QBCore.Functions.Notify(Lang:t('stance_removed'), 'success', 4000)
                    end, netId, 'stance')
                end)
            end,
        }
    end

    if #opts == 0 then
        QBCore.Functions.Notify('No mods installed on this vehicle.', 'primary', 3000)
        return
    end

    lib.registerContext({ id = 'illegaltuner_remove', title = '🔧 Remove Mods', options = opts })
    lib.showContext('illegaltuner_remove')
end

-- ─────────────────────────────────────────────
--  DRIFT CHIP  (dynamic price)
-- ─────────────────────────────────────────────

local function BuyDriftChip(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getDriftChipPrice', function(price, depotValue, bonus)
        lib.alertDialog({
            header   = '🚗 Drift Chip',
            content  = string.format(
                'Soft suspension + high traction loss for drifting.\n\n💵 Cost: **$%s black money**\n_(Base $%s + 20%% car value $%s)_',
                lib.math.groupdigits(price),
                lib.math.groupdigits(Config.DriftChip.basePrice),
                lib.math.groupdigits(bonus)
            ),
            centered = true,
            cancel   = true,
        }, function(confirmed)
            if not confirmed then return end
            GetPassengerThenPurchase(veh, 'drift_chip', Config.DriftChip.installMs, 'Drift Chip', function(v)
                SetVehicleSuspensionUpgrade(v, Config.DriftChip.suspensionLevel)
                SetVehicleHandlingFloat(v, 'CHandlingData', 'fTractionLossMulti', Config.DriftChip.tractionMultiplier)
                QBCore.Functions.Notify(Lang:t('drift_chip_installed'), 'success', 4000)
            end)
        end)
    end, netId)
end

-- ─────────────────────────────────────────────
--  MAIN MENU  — reflects installed state
-- ─────────────────────────────────────────────

local function OpenMenu(veh, state)
    local opts = {}

    -- ── PERFORMANCE ──────────────────────────
    opts[#opts + 1] = { title = '━━━ Performance ━━━', disabled = true }

    -- Engine Chip
    if state.engine_chip then
        opts[#opts + 1] = {
            title       = '✅ Engine Chip  (installed)',
            description = 'Already installed · PD /removechip required to remove',
            icon        = 'microchip',
            disabled    = true,
        }
    elseif state.drift_chip then
        opts[#opts + 1] = {
            title       = '🚫 Engine Chip  (blocked)',
            description = 'Remove drift chip first',
            icon        = 'microchip',
            disabled    = true,
        }
    else
        opts[#opts + 1] = {
            title       = 'Engine Chip  (+' .. Config.EngineChip.speedBoostMPH .. ' MPH)',
            description = 'Base $' .. Config.EngineChip.basePrice .. ' + 30% car value · black money',
            icon        = 'microchip',
            onSelect    = function() BuyEngineChip(veh) end,
        }
    end

    -- Drift Chip
    if state.drift_chip then
        opts[#opts + 1] = {
            title       = '✅ Drift Chip  (installed)',
            description = 'Soft suspension + high traction loss',
            icon        = 'car',
            disabled    = true,
        }
    elseif state.engine_chip then
        opts[#opts + 1] = {
            title       = '🚫 Drift Chip  (blocked)',
            description = 'Remove engine chip first',
            icon        = 'car',
            disabled    = true,
        }
    else
        opts[#opts + 1] = {
            title       = 'Drift Chip  ($' .. Config.DriftChip.basePrice .. ' + 20% car value)',
            description = 'Soft suspension + high traction loss for drifting · black money',
            icon        = 'car',
            onSelect    = function() BuyDriftChip(veh) end,
        }
    end

    -- Stance Kit
    if state.has_stance then
        opts[#opts + 1] = {
            title       = '✅ Stance Kit  (installed)',
            description = 'Already installed · open removal menu to re-configure',
            icon        = 'sliders',
            disabled    = true,
        }
    else
        opts[#opts + 1] = {
            title       = 'Stance Kit  ($' .. Config.StanceKit.price .. ')',
            description = '↑↓ ride height · ←→ camber · SHIFT+←→ wheel dist · ENTER save',
            icon        = 'sliders',
            onSelect    = function()
                GetPassengerThenPurchase(veh, 'stance_kit', Config.StanceKit.installMs, 'Stance Kit', function(v)
                    TriggerEvent('qb-illegaltuner:client:openStance', v)
                end)
            end,
        }
    end

    -- ── NITROUS ──────────────────────────────
    opts[#opts + 1] = { title = '━━━ Nitrous ━━━', disabled = true }

    if state.nos then
        -- Kit installed — show refill if cooldown expired, or status if not
        if state.nos_ready then
            opts[#opts + 1] = {
                title       = 'Refill Nitrous  ($' .. Config.Nitrous.refillPrice .. ')',
                description = 'Return here to top up your NOS canister · black money',
                icon        = 'fill-drip',
                onSelect    = function()
                    GetPassengerThenPurchase(veh, 'nitrous_refill', 3000, 'Nitrous Refill', function(v)
                        TriggerEvent('qb-illegaltuner:client:nosRefilled', v)
                    end)
                end,
            }
        else
            opts[#opts + 1] = {
                title       = '⏳ NOS On Cooldown',
                description = 'Drive to the shop and wait for cooldown to expire',
                icon        = 'clock',
                disabled    = true,
            }
        end
    else
        opts[#opts + 1] = {
            title       = 'Install Nitrous Kit  ($' .. Config.Nitrous.price .. ')',
            description = '+' .. Config.Nitrous.boostMPH .. ' MPH for ' .. Config.Nitrous.boostDuration .. 's  · 30 min cooldown · LEFT SHIFT',
            icon        = 'bolt',
            onSelect    = function()
                GetPassengerThenPurchase(veh, 'nitrous_kit', Config.Nitrous.installMs, 'Nitrous Kit', function(v)
                    TriggerEvent('qb-illegaltuner:client:nosInstalled', v)
                end)
            end,
        }
    end

    -- ── NEON ─────────────────────────────────
    opts[#opts + 1] = { title = '━━━ Neon Kits ━━━', disabled = true }

    local neonInstalled = state.neon_mode ~= nil and state.neon_mode ~= ''
    local neonNote = neonInstalled and '  ✅ (replace)' or ''

    opts[#opts + 1] = {
        title    = 'Static Neon  ($' .. Config.NeonPrices.static .. ')' .. neonNote,
        icon     = 'circle',
        onSelect = function()
            GetPassengerThenPurchase(veh, 'neon_static', Config.NeonInstallMs, 'Static Neon', function(v)
                TriggerEvent('qb-illegaltuner:client:openNeonPicker', v, 'static')
            end)
        end,
    }
    opts[#opts + 1] = {
        title    = 'Rainbow Neon  ($' .. Config.NeonPrices.rainbow .. ')' .. neonNote,
        icon     = 'rainbow',
        onSelect = function()
            GetPassengerThenPurchase(veh, 'neon_rainbow', Config.NeonPrices.rainbow, 'Rainbow Neon', function(v)
                TriggerEvent('qb-illegaltuner:client:startRainbow', v)
            end)
        end,
    }
    opts[#opts + 1] = {
        title    = 'RGB Neon  ($' .. Config.NeonPrices.rgb .. ')' .. neonNote,
        icon     = 'palette',
        onSelect = function()
            GetPassengerThenPurchase(veh, 'neon_rgb', Config.NeonPrices.rgb, 'RGB Neon', function(v)
                TriggerEvent('qb-illegaltuner:client:openNeonPicker', v, 'rgb')
            end)
        end,
    }
    opts[#opts + 1] = {
        title    = 'Strobe Neon  ($' .. Config.NeonPrices.strobe .. ')' .. neonNote,
        icon     = 'bolt',
        onSelect = function()
            GetPassengerThenPurchase(veh, 'neon_strobe', Config.NeonPrices.strobe, 'Strobe Neon', function(v)
                TriggerEvent('qb-illegaltuner:client:startStrobe', v)
            end)
        end,
    }

    -- ── REMOVE MODS ──────────────────────────
    opts[#opts + 1] = { title = '━━━ Management ━━━', disabled = true }
    opts[#opts + 1] = {
        title    = '🗑️ Remove Mods',
        icon     = 'trash',
        onSelect = function() OpenRemoveMenu(veh, state) end,
    }

    lib.registerContext({ id = 'illegaltuner_main', title = '🔧 Illegal Tuner Shop', options = opts })
    lib.showContext('illegaltuner_main')
end

-- ─────────────────────────────────────────────
--  RAMP MENU  — visible to all, install = tuner only
-- ─────────────────────────────────────────────

local function OpenRampMenu(veh, state)
    local isTuner = HasTunerJob()
    local opts    = {}

    local function tunerOnly(label, fn)
        if isTuner then
            return fn
        else
            return function()
                QBCore.Functions.Notify(Lang:t('ramp_not_tuner'), 'error', 4000)
            end
        end
    end

    -- ── PERFORMANCE ──────────────────────────
    opts[#opts + 1] = { title = '━━━ Performance ━━━', disabled = true }

    -- Engine Chip
    if state.engine_chip then
        opts[#opts + 1] = { title = '✅ Engine Chip (installed)', icon = 'microchip', disabled = true }
    elseif state.drift_chip then
        opts[#opts + 1] = { title = '🚫 Engine Chip (blocked — remove drift chip first)', icon = 'microchip', disabled = true }
    else
        opts[#opts + 1] = {
            title       = 'Engine Chip  (+' .. Config.EngineChip.speedBoostMPH .. ' MPH)',
            description = 'Base $' .. lib.math.groupdigits(Config.EngineChip.basePrice) .. ' + 30% car value · black money' .. (not isTuner and '  🔒 Tuner required' or ''),
            icon        = 'microchip',
            onSelect    = tunerOnly('Engine Chip', function() BuyEngineChip(veh) end),
        }
    end

    -- Drift Chip
    if state.drift_chip then
        opts[#opts + 1] = { title = '✅ Drift Chip (installed)', icon = 'car', disabled = true }
    elseif state.engine_chip then
        opts[#opts + 1] = { title = '🚫 Drift Chip (blocked — remove engine chip first)', icon = 'car', disabled = true }
    else
        opts[#opts + 1] = {
            title       = 'Drift Chip',
            description = 'Base $' .. lib.math.groupdigits(Config.DriftChip.basePrice) .. ' + 20% car value · black money' .. (not isTuner and '  🔒 Tuner required' or ''),
            icon        = 'car',
            onSelect    = tunerOnly('Drift Chip', function() BuyDriftChip(veh) end),
        }
    end

    -- Stance Kit
    if state.has_stance then
        opts[#opts + 1] = { title = '✅ Stance Kit (installed)', icon = 'sliders', disabled = true }
    else
        opts[#opts + 1] = {
            title       = 'Stance Kit  ($' .. lib.math.groupdigits(Config.StanceKit.price) .. ')',
            description = 'Camber · ride height · wheel distance' .. (not isTuner and '  🔒 Tuner required' or ''),
            icon        = 'sliders',
            onSelect    = tunerOnly('Stance Kit', function()
                GetPassengerThenPurchase(veh, 'stance_kit', Config.StanceKit.installMs, 'Stance Kit', function(v)
                    TriggerEvent('qb-illegaltuner:client:openStance', v)
                end)
            end),
        }
    end

    -- ── NITROUS ──────────────────────────────
    opts[#opts + 1] = { title = '━━━ Nitrous ━━━', disabled = true }

    if state.nos then
        if state.nos_ready then
            opts[#opts + 1] = {
                title       = 'Refill Nitrous  ($' .. lib.math.groupdigits(Config.Nitrous.refillPrice) .. ')',
                description = 'Top up your NOS canister' .. (not isTuner and '  🔒 Tuner required' or ''),
                icon        = 'fill-drip',
                onSelect    = tunerOnly('Nitrous Refill', function()
                    GetPassengerThenPurchase(veh, 'nitrous_refill', 3000, 'Nitrous Refill', function(v)
                        TriggerEvent('qb-illegaltuner:client:nosRefilled', v)
                    end)
                end),
            }
        else
            opts[#opts + 1] = { title = '⏳ NOS On Cooldown', description = 'Wait for cooldown to expire', icon = 'clock', disabled = true }
        end
    else
        opts[#opts + 1] = {
            title       = 'Install Nitrous Kit  ($' .. lib.math.groupdigits(Config.Nitrous.price) .. ')',
            description = '+' .. Config.Nitrous.boostMPH .. ' MPH · 30 min cooldown · LEFT SHIFT' .. (not isTuner and '  🔒 Tuner required' or ''),
            icon        = 'bolt',
            onSelect    = tunerOnly('Nitrous Kit', function()
                GetPassengerThenPurchase(veh, 'nitrous_kit', Config.Nitrous.installMs, 'Nitrous Kit', function(v)
                    TriggerEvent('qb-illegaltuner:client:nosInstalled', v)
                end)
            end),
        }
    end

    -- ── NEON ─────────────────────────────────
    opts[#opts + 1] = { title = '━━━ Neon Kits ━━━', disabled = true }
    local neonNote = (not isTuner and '  🔒 Tuner required' or '')

    local neonItems = {
        { key = 'neon_static',  label = 'Static Neon',  event = 'openNeonPicker', arg = 'static'  },
        { key = 'neon_rainbow', label = 'Rainbow Neon', event = 'startRainbow',   arg = nil        },
        { key = 'neon_rgb',     label = 'RGB Neon',     event = 'openNeonPicker', arg = 'rgb'      },
        { key = 'neon_strobe',  label = 'Strobe Neon',  event = 'startStrobe',    arg = nil        },
    }
    local neonPriceMap = { neon_static = Config.NeonPrices.static, neon_rainbow = Config.NeonPrices.rainbow, neon_rgb = Config.NeonPrices.rgb, neon_strobe = Config.NeonPrices.strobe }

    for _, n in ipairs(neonItems) do
        local evtName = n.event
        local evtArg  = n.arg
        local prodKey = n.key
        opts[#opts + 1] = {
            title    = n.label .. '  ($' .. lib.math.groupdigits(neonPriceMap[prodKey]) .. ')' .. neonNote,
            icon     = 'circle',
            onSelect = tunerOnly(n.label, function()
                GetPassengerThenPurchase(veh, prodKey, Config.NeonInstallMs, n.label, function(v)
                    if evtArg then
                        TriggerEvent('qb-illegaltuner:client:' .. evtName, v, evtArg)
                    else
                        TriggerEvent('qb-illegaltuner:client:' .. evtName, v)
                    end
                end)
            end),
        }
    end

    -- ── REMOVE MODS ──────────────────────────
    opts[#opts + 1] = { title = '━━━ Management ━━━', disabled = true }
    opts[#opts + 1] = {
        title    = '🗑️ Remove Mods',
        icon     = 'trash',
        onSelect = tunerOnly('Remove Mods', function() OpenRemoveMenu(veh, state) end),
    }

    lib.registerContext({ id = 'illegaltuner_ramp', title = '🔧 Tuner Ramp', options = opts })
    lib.showContext('illegaltuner_ramp')
end

-- ─────────────────────────────────────────────
--  ZONE DETECTION  — using ox_lib zone
-- ─────────────────────────────────────────────

CreateThread(function()
    if Config.Blip.enabled then
        local blip = AddBlipForCoord(Config.ShopLocation.x, Config.ShopLocation.y, Config.ShopLocation.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipColour(blip, Config.Blip.colour)
        SetBlipScale(blip, Config.Blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Blip.label)
        EndTextCommandSetBlipName(blip)
    end
end)

local inZone = false

lib.zones.sphere({
    coords = Config.ShopLocation,
    radius = Config.ZoneRadius,
    onEnter = function()
        if not HasTunerJob() then return end
        local veh = GetDrivenVehicle()
        if not veh then
            QBCore.Functions.Notify(Lang:t('drive_in'), 'error', 4000)
            return
        end
        inZone = true

        CreateThread(function()
            while inZone do
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(Lang:t('press_open'))
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustPressed(0, 51) then
                    local v = GetDrivenVehicle()
                    if not v then
                        QBCore.Functions.Notify(Lang:t('get_in_vehicle'), 'error', 3000)
                    else
                        QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getVehicleState', function(state)
                            if state then OpenMenu(v, state) end
                        end, NetworkGetNetworkIdFromEntity(v))
                    end
                end
                Wait(500)
            end
        end)
    end,
    onExit = function()
        inZone = false
    end,
})

-- ─────────────────────────────────────────────
--  RAMP ZONE  — public access, tuner installs
-- ─────────────────────────────────────────────

-- ─────────────────────────────────────────────
--  RAMP ZONES  — 4 workspaces, public view / tuner install
-- ─────────────────────────────────────────────

local inRamp = false

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

            CreateThread(function()
                while inRamp do
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(Lang:t('ramp_press_open'))
                    EndTextCommandDisplayHelp(0, false, true, -1)

                    if IsControlJustPressed(0, 51) then
                        local v = GetDrivenVehicle()
                        if not v then
                            QBCore.Functions.Notify(Lang:t('ramp_no_vehicle'), 'error', 3000)
                        else
                            QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getVehicleState', function(state)
                                if state then OpenRampMenu(v, state) end
                            end, NetworkGetNetworkIdFromEntity(v))
                        end
                    end
                    Wait(500)
                end
            end)
        end,
        onExit = function()
            inRamp = false
        end,
    })
end

-- ─────────────────────────────────────────────
--  ON SPAWN — reapply all persistent mods
-- ─────────────────────────────────────────────

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    -- Give a moment for the player's vehicle data to settle
    Wait(5000)
    local veh = GetDrivenVehicle()
    if veh then
        TriggerEvent('qb-illegaltuner:client:reapplyMods', veh)
    end
end)

-- Also reapply when entering a vehicle (covers logging back in while seated)
AddEventHandler('getInVehicle', function(veh)
    Wait(1000)
    TriggerEvent('qb-illegaltuner:client:reapplyMods', veh)
end)

RegisterNetEvent('qb-illegaltuner:client:reapplyMods', function(veh)
    TriggerEvent('qb-illegaltuner:client:reapplyMods', veh)
end)

AddEventHandler('qb-illegaltuner:client:reapplyMods', function(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    QBCore.Functions.TriggerCallback('qb-illegaltuner:server:getVehicleState', function(state)
        if not state then return end

        -- Engine chip
        if state.engine_chip then
            local cur   = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
            local boost = Config.EngineChip.speedBoostMPH * 0.44704
            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', cur + boost)
            SetVehicleEngineUpgrade(veh, 3)
        end

        -- Drift chip
        if state.drift_chip then
            SetVehicleSuspensionUpgrade(veh, Config.DriftChip.suspensionLevel)
            SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionLossMulti', Config.DriftChip.tractionMultiplier)
        end

        -- NOS
        if state.nos then
            TriggerEvent('qb-illegaltuner:client:nosInstalled', veh, true) -- silent=true (no notify)
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
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh    = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 71)
    if not veh or veh == 0 then
        QBCore.Functions.Notify('No vehicle nearby.', 'error', 3000)
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
    -- Revert the speed boost
    local cur   = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    local boost = Config.EngineChip.speedBoostMPH * 0.44704
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel', math.max(10.0, cur - boost))
end)
