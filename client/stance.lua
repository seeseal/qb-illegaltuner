-- ╔══════════════════════════════════════════════╗
-- ║    qb-illegaltuner  |  client/stance.lua    ║
-- ╚══════════════════════════════════════════════╝

local QBCore       = exports['qb-core']:GetCoreObject()
local stanceActive = false

local function Clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

local function ApplyStance(veh, camber, rideHeight, wheelDist)
    for wheel = 0, 3 do
        SetVehicleWheelYOffset(veh, wheel, wheelDist)
        SetVehicleWheelCamber(veh, wheel, (wheel % 2 == 0) and -camber or camber)
    end
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionRaise', rideHeight)
end

local function DrawHUD(camber, rideHeight, wheelDist)
    local lines = {
        string.format('~b~↑↓~w~  Ride Height:  ~y~%.3f', rideHeight),
        string.format('~b~←→~w~  Camber:       ~y~%.3f', camber),
        string.format('~b~SHIFT+←→~w~  Wheel Dist:  ~y~%.3f', wheelDist),
        '~g~ENTER~w~ save   ~r~BACKSPACE~w~ cancel   ~o~ESC~w~ confirm exit',
    }
    for i, line in ipairs(lines) do
        SetTextFont(4)
        SetTextScale(0.35, 0.35)
        SetTextColour(255, 255, 255, 220)
        SetTextOutline()
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(line)
        EndTextCommandDisplayText(0.02, 0.84 + (i - 1) * 0.04)
    end
end

-- Resets vehicle to neutral stance
local function ClearStance(veh)
    for wheel = 0, 3 do
        SetVehicleWheelYOffset(veh, wheel, 0.0)
        SetVehicleWheelCamber(veh, wheel, 0.0)
    end
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionRaise', 0.0)
end

AddEventHandler('qb-illegaltuner:client:openStance', function(veh)
    if stanceActive then return end
    stanceActive = true

    -- Seed from vehicle's CURRENT persisted stance (not 0.0)
    local camber     = 0.0
    local rideHeight = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionRaise') or 0.0
    local wheelDist  = 0.0
    -- Try to read current wheel camber from front-left
    local existingCamber = GetVehicleWheelCamber(veh, 0)
    if existingCamber then camber = -existingCamber end  -- stored as negative on wheel 0
    local existingDist = GetVehicleWheelYOffset(veh, 0)
    if existingDist then wheelDist = existingDist end

    local originalCamber     = camber
    local originalRideHeight = rideHeight
    local originalWheelDist  = wheelDist

    QBCore.Functions.Notify(Lang:t('stance_mode'), 'primary', 5000)

    CreateThread(function()
        while stanceActive do
            Wait(0)
            DrawHUD(camber, rideHeight, wheelDist)

            local shift = IsControlPressed(0, 21)

            -- Ride height ↑↓
            if IsControlJustPressed(0, 172) and not shift then
                rideHeight = Clamp(rideHeight + Config.StanceKit.rideHeightStep, Config.StanceKit.rideHeightMin, Config.StanceKit.rideHeightMax)
                ApplyStance(veh, camber, rideHeight, wheelDist)
            elseif IsControlJustPressed(0, 173) and not shift then
                rideHeight = Clamp(rideHeight - Config.StanceKit.rideHeightStep, Config.StanceKit.rideHeightMin, Config.StanceKit.rideHeightMax)
                ApplyStance(veh, camber, rideHeight, wheelDist)
            end

            -- Camber ←→
            if IsControlJustPressed(0, 174) and not shift then
                camber = Clamp(camber - Config.StanceKit.camberStep, Config.StanceKit.camberMin, Config.StanceKit.camberMax)
                ApplyStance(veh, camber, rideHeight, wheelDist)
            elseif IsControlJustPressed(0, 175) and not shift then
                camber = Clamp(camber + Config.StanceKit.camberStep, Config.StanceKit.camberMin, Config.StanceKit.camberMax)
                ApplyStance(veh, camber, rideHeight, wheelDist)
            end

            -- Wheel dist SHIFT+←→
            if IsControlJustPressed(0, 174) and shift then
                wheelDist = Clamp(wheelDist - Config.StanceKit.wheelDistStep, Config.StanceKit.wheelDistMin, Config.StanceKit.wheelDistMax)
                ApplyStance(veh, camber, rideHeight, wheelDist)
            elseif IsControlJustPressed(0, 175) and shift then
                wheelDist = Clamp(wheelDist + Config.StanceKit.wheelDistStep, Config.StanceKit.wheelDistMin, Config.StanceKit.wheelDistMax)
                ApplyStance(veh, camber, rideHeight, wheelDist)
            end

            -- ENTER — save
            if IsControlJustPressed(0, 191) then
                stanceActive = false
                ApplyStance(veh, camber, rideHeight, wheelDist)
                -- Persist to DB
                TriggerServerEvent('qb-illegaltuner:server:saveStance',
                    NetworkGetNetworkIdFromEntity(veh), camber, rideHeight, wheelDist)
                QBCore.Functions.Notify(Lang:t('stance_saved'), 'success', 3000)
            end

            -- BACKSPACE — cancel, restore original
            if IsControlJustPressed(0, 194) then
                stanceActive = false
                ApplyStance(veh, originalCamber, originalRideHeight, originalWheelDist)
                QBCore.Functions.Notify(Lang:t('stance_cancelled'), 'error', 3000)
            end

            -- ESC — ask for confirmation before exiting without saving
            if IsControlJustPressed(0, 322) then
                stanceActive = false  -- pause the loop temporarily
                lib.alertDialog({
                    header   = 'Exit Stance Mode',
                    content  = 'You have unsaved changes. What would you like to do?',
                    centered = true,
                    cancel   = true,
                    labels   = { confirm = 'Save & Exit', cancel = 'Discard & Exit' },
                }, function(confirmed)
                    if confirmed then
                        ApplyStance(veh, camber, rideHeight, wheelDist)
                        TriggerServerEvent('qb-illegaltuner:server:saveStance',
                            NetworkGetNetworkIdFromEntity(veh), camber, rideHeight, wheelDist)
                        QBCore.Functions.Notify(Lang:t('stance_saved'), 'success', 3000)
                    else
                        ApplyStance(veh, originalCamber, originalRideHeight, originalWheelDist)
                        QBCore.Functions.Notify(Lang:t('stance_cancelled'), 'error', 3000)
                    end
                end)
                -- stanceActive remains false — loop has exited
            end
        end
    end)
end)

-- Apply stance from DB values (called on spawn/load)
AddEventHandler('qb-illegaltuner:client:applyStance', function(veh, camber, height, wheeldist)
    if not veh or not DoesEntityExist(veh) then return end
    ApplyStance(veh, camber or 0.0, height or 0.0, wheeldist or 0.0)
end)

-- Remove stance (reset to default)
AddEventHandler('qb-illegaltuner:client:stanceRemoved', function(veh)
    if not veh or not DoesEntityExist(veh) then return end
    ClearStance(veh)
end)
