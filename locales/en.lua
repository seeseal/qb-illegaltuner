-- locales/en.lua
local Translations = {
    -- General
    ['no_job']            = "You don't have the right connections here.",
    ['drive_in']          = 'Drive your vehicle into the shop.',
    ['get_in_vehicle']    = 'Get back in your vehicle!',
    ['cancelled']         = 'Installation cancelled.',
    ['transaction_failed']= 'Transaction failed!',
    ['unknown_product']   = 'Unknown product.',
    ['invalid_price']     = 'Invalid price.',
    ['slow_down']         = 'Slow down!',
    ['access_denied']     = 'Access denied.',
    ['press_open']        = 'Press ~INPUT_CONTEXT~ to open Tuner Shop',
    ['no_funds']          = "%s doesn't have enough black money! ($%d needed)",

    -- Engine Chip
    ['engine_chip_installed']     = '+%d MPH engine chip installed! 🏎️',
    ['engine_chip_already']       = 'This vehicle already has an engine chip installed.',
    ['engine_chip_conflict']      = 'Remove the drift chip before installing an engine chip.',
    ['engine_chip_removed']       = 'Engine chip removed.',
    ['engine_chip_no_chip']       = 'This vehicle has no engine chip to remove.',

    -- Drift Chip
    ['drift_chip_installed']      = 'Drift chip installed!',
    ['drift_chip_already']        = 'This vehicle already has a drift chip installed.',
    ['drift_chip_conflict']       = 'Remove the engine chip before installing a drift chip.',
    ['drift_chip_removed']        = 'Drift chip removed.',
    ['drift_chip_no_chip']        = 'This vehicle has no drift chip to remove.',

    -- Stance
    ['stance_installed']          = 'Stance kit installed! Adjust with arrow keys.',
    ['stance_already']            = 'This vehicle already has a stance kit installed.',
    ['stance_saved']              = 'Stance saved! ✅',
    ['stance_cancelled']          = 'Stance cancelled.',
    ['stance_removed']            = 'Stance kit removed.',
    ['stance_mode']               = 'Stance mode — arrow keys to adjust. ENTER to save.',

    -- Nitrous
    ['nos_installed']             = 'Nitrous installed! LEFT SHIFT to activate 🚀',
    ['nos_already']               = 'This vehicle already has a NOS kit installed.',
    ['nos_activated']             = '🚀 NOS ACTIVATED!',
    ['nos_refilled']              = 'NOS refilled and ready! 🚀',
    ['nos_not_installed']         = 'No NOS kit installed on this vehicle.',
    ['nos_no_refill_here']        = 'Return to the tuner shop to refill your NOS.',
    ['nos_cooldown']              = 'NOS is cooling down.',
    ['nos_removed']               = 'NOS kit removed.',

    -- Neon
    ['neon_set']                  = '%s neon set to %s! 💡',
    ['neon_rainbow']              = 'Rainbow neon activated! 🌈',
    ['neon_strobe']               = 'Strobe neon activated! ⚡',
    ['neon_removed']              = 'Neon kit removed.',
    ['neon_already']              = 'This vehicle already has a neon kit. Visit removal menu first.',

    -- Removal (PD)
    ['remove_chip_no_perm']       = 'Only PD can remove engine chips.',
    ['remove_chip_success']       = 'Engine chip successfully removed from vehicle.',
    ['remove_chip_none']          = 'No engine chip found on this vehicle.',

    -- Progress bars
    ['installing']                = 'Installing %s...',
    ['removing']                  = 'Removing %s...',
}

Lang = Lang or Locale:new({ phrases = Translations, warnOnMissing = true })
