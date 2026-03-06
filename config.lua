Config = {}

-- ─────────────────────────────────────────────
--  GENERAL
-- ─────────────────────────────────────────────
Config.RequiredJob      = 'tuner'
Config.PDJob            = 'police'   -- job allowed to use /removechip
Config.PaymentType      = 'black_money'
Config.ZoneRadius       = 8.0
Config.ProgressBar      = true

-- ─────────────────────────────────────────────
--  SHOP LOCATION
-- ─────────────────────────────────────────────
Config.ShopLocation = vector3(0.0, 0.0, 0.0)   -- ← swap with your coords

-- ─────────────────────────────────────────────
--  BLIP
-- ─────────────────────────────────────────────
Config.Blip = {
    enabled = true,
    label   = 'Illegal Tuner',
    sprite  = 72,
    colour  = 1,
    scale   = 0.8,
}

-- ─────────────────────────────────────────────
--  DISCORD / LOGGING
-- ─────────────────────────────────────────────
Config.DiscordWebhook = ''   -- paste your webhook URL here; leave '' to disable
Config.DiscordColour  = 16711680  -- red

-- ─────────────────────────────────────────────
--  ENGINE CHIP
-- ─────────────────────────────────────────────
Config.EngineChip = {
    installMs       = 10000,
    removeMs        = 8000,
    speedBoostMPH   = 15,
    basePrice       = 250000,
    carValuePercent = 0.30,   -- price = basePrice + (depotvalue * 30%)
}

-- ─────────────────────────────────────────────
--  DRIFT CHIP
-- ─────────────────────────────────────────────
Config.DriftChip = {
    price              = 20000,
    installMs          = 6000,
    removeMs           = 5000,
    tractionMultiplier = 1.45,
    suspensionLevel    = 2,
}

-- ─────────────────────────────────────────────
--  STANCE KIT
-- ─────────────────────────────────────────────
Config.StanceKit = {
    price          = 15000,
    installMs      = 7000,
    removeMs       = 5000,
    camberStep     = 0.01,
    rideHeightStep = 0.005,
    wheelDistStep  = 0.005,
    camberMin      = -0.20,  camberMax     = 0.20,
    rideHeightMin  = -0.10,  rideHeightMax = 0.10,
    wheelDistMin   = -0.10,  wheelDistMax  = 0.10,
}

-- ─────────────────────────────────────────────
--  NITROUS
-- ─────────────────────────────────────────────
Config.Nitrous = {
    price         = 30000,
    refillPrice   = 25000,
    installMs     = 9000,
    removeMs      = 7000,
    boostMPH      = 10,
    boostDuration = 10,      -- seconds active
    cooldown      = 1800,    -- 30 minutes in seconds
    key           = 321,     -- LEFT SHIFT
}

-- ─────────────────────────────────────────────
--  NEON KITS
-- ─────────────────────────────────────────────
Config.NeonPrices = {
    static  = 5000,
    rainbow = 8000,
    rgb     = 10000,
    strobe  = 9000,
}
Config.NeonInstallMs = 4000
Config.NeonRemoveMs  = 3000

Config.NeonColours = {
    { label = 'Red',    r = 255, g = 0,   b = 0   },
    { label = 'Blue',   r = 0,   g = 0,   b = 255 },
    { label = 'Green',  r = 0,   g = 255, b = 0   },
    { label = 'Purple', r = 128, g = 0,   b = 128 },
    { label = 'Pink',   r = 255, g = 0,   b = 127 },
    { label = 'White',  r = 255, g = 255, b = 255 },
    { label = 'Yellow', r = 255, g = 255, b = 0   },
    { label = 'Orange', r = 255, g = 128, b = 0   },
    { label = 'Cyan',   r = 0,   g = 255, b = 255 },
}
