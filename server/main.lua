-- ╔══════════════════════════════════════════════╗
-- ║     qb-illegaltuner  |  server/main.lua     ║
-- ╚══════════════════════════════════════════════╝

local QBCore    = exports['qb-core']:GetCoreObject()
local cooldowns = {}
local COOLDOWN  = 3000  -- ms between purchases (anti-spam)

-- ─────────────────────────────────────────────
--  DB SETUP  — create table on first run
-- ─────────────────────────────────────────────

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS illegaltuner_mods (
            plate       VARCHAR(12)  NOT NULL,
            engine_chip TINYINT(1)   NOT NULL DEFAULT 0,
            drift_chip  TINYINT(1)   NOT NULL DEFAULT 0,
            nos         TINYINT(1)   NOT NULL DEFAULT 0,
            nos_cooldown BIGINT      NOT NULL DEFAULT 0,
            nos_empty   TINYINT(1)   NOT NULL DEFAULT 0,
            nos_active  TINYINT(1)   NOT NULL DEFAULT 0,
            neon_mode   VARCHAR(16)  DEFAULT NULL,
            neon_r      TINYINT UNSIGNED DEFAULT NULL,
            neon_g      TINYINT UNSIGNED DEFAULT NULL,
            neon_b      TINYINT UNSIGNED DEFAULT NULL,
            stance_camber      FLOAT DEFAULT NULL,
            stance_height      FLOAT DEFAULT NULL,
            stance_wheeldist   FLOAT DEFAULT NULL,
            PRIMARY KEY (plate)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    -- Add nos_empty column to existing tables that predate this column
    MySQL.query([[
        ALTER TABLE illegaltuner_mods
        ADD COLUMN IF NOT EXISTS nos_empty TINYINT(1) NOT NULL DEFAULT 0;
    ]])
end)

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────

local function HasJob(Player, job)
    return Player.PlayerData.job and Player.PlayerData.job.name == job
end

local function GetServerPrice(productKey)
    local prices = {
        stance_kit     = Config.StanceKit.price,
        nitrous_kit    = Config.Nitrous.price,
        nitrous_refill = Config.Nitrous.refillPrice,
        neon_static    = Config.NeonPrices.static,
        neon_rainbow   = Config.NeonPrices.rainbow,
        neon_rgb       = Config.NeonPrices.rgb,
        neon_strobe    = Config.NeonPrices.strobe,
    }
    return prices[productKey]
end

local function GetOrCreateRow(plate)
    local row = MySQL.single.await(
        'SELECT * FROM illegaltuner_mods WHERE plate = ?', { plate }
    )
    if not row then
        MySQL.insert.await(
            'INSERT INTO illegaltuner_mods (plate) VALUES (?)', { plate }
        )
        row = MySQL.single.await(
            'SELECT * FROM illegaltuner_mods WHERE plate = ?', { plate }
        )
    end
    return row
end

local function SendDiscordLog(title, description, colour)
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' then return end
    PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST',
        json.encode({
            embeds = {{
                title       = title,
                description = description,
                color       = colour or Config.DiscordColour,
                footer      = { text = os.date('%Y-%m-%d %H:%M:%S') },
            }}
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

local function QBLog(name, label, msg, src)
    TriggerEvent('qb-log:server:CreateLog', name, label, 'red', msg)
    -- also broadcast to Discord
    SendDiscordLog(label, msg .. '\n**Player:** ' .. (GetPlayerName(src) or 'unknown') .. ' (src:' .. tostring(src) .. ')')
end

local function CharName(Player)
    local ci = Player.PlayerData.charinfo
    return ci.firstname .. ' ' .. ci.lastname
end

-- ─────────────────────────────────────────────
--  GET PASSENGER
-- ─────────────────────────────────────────────

QBCore.Functions.CreateCallback('qb-illegaltuner:server:getPassenger', function(source, cb, netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then cb(nil) return end
    local driverPed = GetPedInVehicleSeat(veh, -1)
    for seat = 0, 5 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and ped ~= driverPed then
            for _, pid in ipairs(GetPlayers()) do
                if GetPlayerPed(tonumber(pid)) == ped then
                    cb(tonumber(pid))
                    return
                end
            end
        end
    end
    cb(nil)
end)

-- ─────────────────────────────────────────────
--  GET VEHICLE STATE (for menu rendering)
-- ─────────────────────────────────────────────

QBCore.Functions.CreateCallback('qb-illegaltuner:server:getVehicleState', function(source, cb, netId)
    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then cb(nil) return end
    plate = plate:gsub('%s+', '')
    local row = GetOrCreateRow(plate)
    local nowSec = os.time()
    local nosReady = (row.nos_cooldown or 0) <= nowSec
    local nosCooldownRemaining = math.max(0, (row.nos_cooldown or 0) - nowSec)
    cb({
        engine_chip        = row.engine_chip  == 1 or row.engine_chip  == true,
        drift_chip         = row.drift_chip   == 1 or row.drift_chip   == true,
        nos                = row.nos          == 1 or row.nos          == true,
        nos_ready          = nosReady,
        nos_empty          = row.nos_empty    == 1 or row.nos_empty    == true,
        nos_cooldown_until = nosCooldownRemaining,
        neon_mode          = row.neon_mode,
        has_stance         = row.stance_camber ~= nil,
        stance             = {
            camber    = row.stance_camber,
            height    = row.stance_height,
            wheeldist = row.stance_wheeldist,
        },
    })
end)

-- ─────────────────────────────────────────────
--  ENGINE CHIP PRICE  (fully server-calculated)
-- ─────────────────────────────────────────────

QBCore.Functions.CreateCallback('qb-illegaltuner:server:getEngineChipPrice', function(source, cb, netId)
    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then cb(Config.EngineChip.basePrice) return end
    plate = plate:gsub('%s+', '')

    local result = MySQL.single.await(
        'SELECT depotprice FROM player_vehicles WHERE plate = ?', { plate }
    )
    local depotValue = result and result.depotprice or 0
    local bonus = math.floor(depotValue * Config.EngineChip.carValuePercent)
    local price = Config.EngineChip.basePrice + bonus
    cb(price, depotValue, bonus)
end)

QBCore.Functions.CreateCallback('qb-illegaltuner:server:getDriftChipPrice', function(source, cb, netId)
    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then cb(Config.DriftChip.basePrice) return end
    plate = plate:gsub('%s+', '')

    local result = MySQL.single.await(
        'SELECT depotprice FROM player_vehicles WHERE plate = ?', { plate }
    )
    local depotValue = result and result.depotprice or 0
    local bonus = math.floor(depotValue * Config.DriftChip.carValuePercent)
    local price = Config.DriftChip.basePrice + bonus
    cb(price, depotValue, bonus)
end)

-- ─────────────────────────────────────────────
--  PURCHASE CALLBACK
-- ─────────────────────────────────────────────

QBCore.Functions.CreateCallback('qb-illegaltuner:server:purchase', function(source, cb, productKey, clientPrice, passengerSrc, netId)
    local src    = source
    local Driver = QBCore.Functions.GetPlayer(src)
    if not Driver then cb(false, Lang:t('transaction_failed')) return end

    if not HasJob(Driver, Config.RequiredJob) then
        cb(false, Lang:t('access_denied')) return
    end

    local now = GetGameTimer()
    if cooldowns[src] and (now - cooldowns[src]) < COOLDOWN then
        cb(false, Lang:t('slow_down')) return
    end

    -- ── Per-vehicle duplicate checks ─────────────────
    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then cb(false, Lang:t('transaction_failed')) return end
    plate = plate:gsub('%s+', '')

    local row = GetOrCreateRow(plate)

    if productKey == 'engine_chip' then
        if row.engine_chip == 1 or row.engine_chip == true then cb(false, Lang:t('engine_chip_already')) return end
        if row.drift_chip  == 1 or row.drift_chip  == true then cb(false, Lang:t('engine_chip_conflict')) return end
        local chipItem = Driver.Functions.GetItemByName('s3_chip')
        if not chipItem or chipItem.amount < 1 then
            cb(false, '🔧 You need an S3 Chip item in your inventory to install this.') return
        end
    elseif productKey == 'drift_chip' then
        if row.drift_chip  == 1 or row.drift_chip  == true then cb(false, Lang:t('drift_chip_already')) return end
        if row.engine_chip == 1 or row.engine_chip == true then cb(false, Lang:t('drift_chip_conflict')) return end
        local driftItem = Driver.Functions.GetItemByName('drift_chip')
        if not driftItem or driftItem.amount < 1 then
            cb(false, '🏎️ You need a Drift Chip item in your inventory to install this.') return
        end
    elseif productKey == 'stance_kit' then
        local rodItem = Driver.Functions.GetItemByName('stance_rod')
        if not rodItem or rodItem.amount < 1 then
            cb(false, '📐 You need a Stance Rod item in your inventory to install this.') return
        end
    elseif productKey == 'nitrous_kit' then
        if row.nos == 1 or row.nos == true then cb(false, Lang:t('nos_already')) return end
    elseif productKey == 'nitrous_refill' then
        if not (row.nos == 1 or row.nos == true) then cb(false, Lang:t('nos_not_installed')) return end
        local nowSec = os.time()
        if (row.nos_cooldown or 0) > nowSec then
            local remaining = math.ceil((row.nos_cooldown - nowSec) / 60)
            cb(false, 'NOS is on cooldown. ' .. remaining .. ' min remaining.') return
        end
    elseif productKey:sub(1, 4) == 'neon' then
        -- allow re-buying neon (replaces existing)
    end

    -- ── Price ────────────────────────────────────────
    local price
    if productKey == 'engine_chip' then
        local result = MySQL.single.await(
            'SELECT depotprice FROM player_vehicles WHERE plate = ?', { plate }
        )
        local depotValue = result and result.depotprice or 0
        local bonus = math.floor(depotValue * Config.EngineChip.carValuePercent)
        price = Config.EngineChip.basePrice + bonus
    elseif productKey == 'drift_chip' then
        local result = MySQL.single.await(
            'SELECT depotprice FROM player_vehicles WHERE plate = ?', { plate }
        )
        local depotValue = result and result.depotprice or 0
        local bonus = math.floor(depotValue * Config.DriftChip.carValuePercent)
        price = Config.DriftChip.basePrice + bonus
    else
        price = GetServerPrice(productKey)
        if not price then
            print('[qb-illegaltuner] Unknown product: ' .. tostring(productKey))
            cb(false, Lang:t('unknown_product')) return
        end
    end

    -- ── Payer ────────────────────────────────────────
    local Payer = (passengerSrc and QBCore.Functions.GetPlayer(tonumber(passengerSrc))) or Driver
    local item    = Payer.Functions.GetItemByName(Config.PaymentType)
    local balance = item and item.amount or 0

    if balance < price then
        local shortfall = price - balance
        local payerName = CharName(Payer)
        local whoLabel  = (Payer.PlayerData.source == src) and 'You are' or (payerName .. ' is')
        cb(false, '💸 Insufficient balance — ' .. whoLabel .. ' short $' .. lib.math.groupdigits(shortfall) .. ' dirty cash.') return
    end

    Payer.Functions.RemoveItem(Config.PaymentType, price)
    TriggerClientEvent('inventory:client:ItemBox', Payer.PlayerData.source,
        QBCore.Shared.Items[Config.PaymentType], 'remove')

    cooldowns[src] = now

    -- ── DB write ─────────────────────────────────────
    if productKey == 'engine_chip' then
        MySQL.update.await('UPDATE illegaltuner_mods SET engine_chip = 1 WHERE plate = ?', { plate })
        Driver.Functions.RemoveItem('s3_chip', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['s3_chip'], 'remove')
    elseif productKey == 'drift_chip' then
        MySQL.update.await('UPDATE illegaltuner_mods SET drift_chip = 1 WHERE plate = ?', { plate })
        Driver.Functions.RemoveItem('drift_chip', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['drift_chip'], 'remove')
    elseif productKey == 'stance_kit' then
        MySQL.update.await('UPDATE illegaltuner_mods SET stance_kit = 1 WHERE plate = ?', { plate })
        Driver.Functions.RemoveItem('stance_rod', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['stance_rod'], 'remove')
    elseif productKey == 'nitrous_kit' then
        MySQL.update.await('UPDATE illegaltuner_mods SET nos = 1, nos_cooldown = 0 WHERE plate = ?', { plate })
    elseif productKey == 'nitrous_refill' then
        -- Reset cooldown timestamp
        MySQL.update.await('UPDATE illegaltuner_mods SET nos_cooldown = 0 WHERE plate = ?', { plate })
    end

    -- ── Logging ──────────────────────────────────────
    local logMsg = string.format('**%s** installed **%s** on plate **%s** | $%d charged to **%s**',
        CharName(Driver), productKey, plate, price, CharName(Payer))
    QBLog('illegaltuner', 'Tuner Purchase', logMsg, src)

    cb(true, price)
end)

-- ─────────────────────────────────────────────
--  NOS REFILL STATION  — no job required, cooldown enforced
-- ─────────────────────────────────────────────

QBCore.Functions.CreateCallback('qb-illegaltuner:server:nosStationRefill', function(source, cb, netId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, Lang:t('transaction_failed')) return end

    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then cb(false, Lang:t('transaction_failed')) return end
    plate = plate:gsub('%s+', '')

    local row = MySQL.single.await('SELECT * FROM illegaltuner_mods WHERE plate = ?', { plate })

    if not row or not (row.nos == 1 or row.nos == true) then
        cb(false, Lang:t('nos_not_installed')) return
    end

    local nowSec = os.time()
    if (row.nos_cooldown or 0) > nowSec then
        local remaining = math.ceil((row.nos_cooldown - nowSec) / 60)
        cb(false, Lang:t('nos_cooldown', { remaining })) return
    end

    local price = Config.Nitrous.refillPrice
    local item    = Player.Functions.GetItemByName(Config.PaymentType)
    local balance = item and item.amount or 0

    if balance < price then
        local shortfall = price - balance
        cb(false, '💸 Short $' .. lib.math.groupdigits(shortfall) .. ' dirty cash.') return
    end

    Player.Functions.RemoveItem(Config.PaymentType, price)
    TriggerClientEvent('inventory:client:ItemBox', src,
        QBCore.Shared.Items[Config.PaymentType], 'remove')

    -- Cooldown resets to 0, nos_empty cleared — canister is full again
    MySQL.update.await('UPDATE illegaltuner_mods SET nos_cooldown = 0, nos_empty = 0 WHERE plate = ?', { plate })

    local logMsg = string.format('**%s** refilled NOS on plate **%s** at station | $%d',
        CharName(Player), plate, price)
    QBLog('illegaltuner', 'NOS Refill (Station)', logMsg, src)

    cb(true, price)
end)

-- ─────────────────────────────────────────────
--  NOS COOLDOWN  — set when NOS fires
-- ─────────────────────────────────────────────

RegisterNetEvent('qb-illegaltuner:server:nosUsed', function(netId)
    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then return end
    plate = plate:gsub('%s+', '')
    local cooldownUntil = os.time() + Config.Nitrous.cooldown
    MySQL.update.await('UPDATE illegaltuner_mods SET nos_cooldown = ?, nos_empty = 1 WHERE plate = ?',
        { cooldownUntil, plate })
end)

-- ─────────────────────────────────────────────
--  SAVE NEON STATE
-- ─────────────────────────────────────────────

RegisterNetEvent('qb-illegaltuner:server:saveNeon', function(netId, mode, r, g, b)
    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then return end
    plate = plate:gsub('%s+', '')
    GetOrCreateRow(plate)
    MySQL.update.await(
        'UPDATE illegaltuner_mods SET neon_mode = ?, neon_r = ?, neon_g = ?, neon_b = ? WHERE plate = ?',
        { mode, r, g, b, plate }
    )
end)

-- ─────────────────────────────────────────────
--  SAVE STANCE STATE
-- ─────────────────────────────────────────────

RegisterNetEvent('qb-illegaltuner:server:saveStance', function(netId, camber, height, wheeldist)
    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then return end
    plate = plate:gsub('%s+', '')
    GetOrCreateRow(plate)
    MySQL.update.await(
        'UPDATE illegaltuner_mods SET stance_camber = ?, stance_height = ?, stance_wheeldist = ? WHERE plate = ?',
        { camber, height, wheeldist, plate }
    )
end)

-- ─────────────────────────────────────────────
--  REMOVE MOD (generic — for uninstall menu)
-- ─────────────────────────────────────────────

QBCore.Functions.CreateCallback('qb-illegaltuner:server:removeMod', function(source, cb, netId, modKey)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false) return end
    if not HasJob(Player, Config.RequiredJob) then cb(false, Lang:t('access_denied')) return end

    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then cb(false) return end
    plate = plate:gsub('%s+', '')

    local row = GetOrCreateRow(plate)

    if modKey == 'engine_chip' then
        if not (row.engine_chip == 1 or row.engine_chip == true) then cb(false, Lang:t('engine_chip_no_chip')) return end
        MySQL.update.await('UPDATE illegaltuner_mods SET engine_chip = 0 WHERE plate = ?', { plate })
    elseif modKey == 'drift_chip' then
        if not (row.drift_chip == 1 or row.drift_chip == true) then cb(false, Lang:t('drift_chip_no_chip')) return end
        MySQL.update.await('UPDATE illegaltuner_mods SET drift_chip = 0 WHERE plate = ?', { plate })
    elseif modKey == 'nos' then
        if not (row.nos == 1 or row.nos == true) then cb(false, Lang:t('nos_not_installed')) return end
        MySQL.update.await('UPDATE illegaltuner_mods SET nos = 0, nos_cooldown = 0 WHERE plate = ?', { plate })
    elseif modKey == 'neon' then
        MySQL.update.await(
            'UPDATE illegaltuner_mods SET neon_mode = NULL, neon_r = NULL, neon_g = NULL, neon_b = NULL WHERE plate = ?',
            { plate })
    elseif modKey == 'stance' then
        MySQL.update.await(
            'UPDATE illegaltuner_mods SET stance_camber = NULL, stance_height = NULL, stance_wheeldist = NULL WHERE plate = ?',
            { plate })
    else
        cb(false, Lang:t('unknown_product')) return
    end

    local logMsg = string.format('**%s** removed **%s** from plate **%s**', CharName(Player), modKey, plate)
    QBLog('illegaltuner', 'Tuner Removal', logMsg, src)
    cb(true)
end)

-- ─────────────────────────────────────────────
--  PD COMMAND: /removechip  (engine chip only)
-- ─────────────────────────────────────────────

QBCore.Commands.Add('removechip', '(PD) Remove illegal engine chip from nearby vehicle', {}, false, function(source)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not HasJob(Player, Config.PDJob) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('remove_chip_no_perm'), 'error')
        return
    end

    -- Find nearest player vehicle to this officer's ped
    TriggerClientEvent('qb-illegaltuner:client:pdRemoveChipRequest', src)
end, Config.PDJob)

RegisterNetEvent('qb-illegaltuner:server:pdRemoveChip', function(netId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not HasJob(Player, Config.PDJob) then return end

    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then return end
    plate = plate:gsub('%s+', '')

    local row = MySQL.single.await('SELECT engine_chip FROM illegaltuner_mods WHERE plate = ?', { plate })

    if not row or row.engine_chip ~= 1 then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('remove_chip_none'), 'error')
        return
    end

    MySQL.update.await('UPDATE illegaltuner_mods SET engine_chip = 0 WHERE plate = ?', { plate })

    TriggerClientEvent('QBCore:Notify', src, Lang:t('remove_chip_success'), 'success')
    TriggerClientEvent('qb-illegaltuner:client:engineChipRemoved', src, netId)

    local logMsg = string.format('**%s** (PD) removed engine chip from plate **%s**', CharName(Player), plate)
    QBLog('illegaltuner', 'PD Engine Chip Removal', logMsg, src)
end)

-- ─────────────────────────────────────────────
--  /checkchip  — anyone can check nearest vehicle
-- ─────────────────────────────────────────────

QBCore.Commands.Add('checkchip', 'Check what chips are installed on the nearest vehicle', {}, false, function(source)
    TriggerClientEvent('qb-illegaltuner:client:checkChip', source)
end)

RegisterNetEvent('qb-illegaltuner:server:checkChip', function(netId)
    local src   = source
    local veh   = NetworkGetEntityFromNetworkId(netId)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then
        TriggerClientEvent('QBCore:Notify', src, 'Could not read vehicle plate.', 'error')
        return
    end
    plate = plate:gsub('%s+', '')

    local row = MySQL.single.await('SELECT * FROM illegaltuner_mods WHERE plate = ?', { plate })

    print('[qb-illegaltuner] checkchip plate=' .. plate .. ' row=' .. json.encode(row))

    local hasEngine = row and (row.engine_chip == 1 or row.engine_chip == true)
    local hasDrift  = row and (row.drift_chip  == 1 or row.drift_chip  == true)

    local msg
    if hasEngine then
        msg = '🚗 Plate [' .. plate .. '] — 🔧 Engine Chip Installed'
    elseif hasDrift then
        msg = '🚗 Plate [' .. plate .. '] — 🔧 Drift Chip Installed'
    else
        msg = '🚗 Plate [' .. plate .. '] — 🔧 No Chip Installed'
    end

    TriggerClientEvent('QBCore:Notify', src, msg, 'primary', 6000)
end)

-- ─────────────────────────────────────────────
--  CLEANUP
-- ─────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)