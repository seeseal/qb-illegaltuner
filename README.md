# qb-illegaltuner

An illegal tuner shop resource for **QBCore** FiveM servers. Players with the `tuner` job can install performance and cosmetic upgrades on client vehicles, paid with black money. All modifications persist across reconnects via database storage.

---

## Preview

> Custom HTML UI replaces the default ox_lib context menu for a fully themed shop experience, with a dedicated NOS HUD displaying live canister status, cooldown timers, and boost progress.

---

## Features

- **Engine Chip** — +15% top speed. Price is dynamically calculated server-side: base $250,000 + 30% of the vehicle's depot value. One install per vehicle — removable at the tuner shop or by PD via `/removechip`. Mutually exclusive with Drift Chip.
- **Drift Chip** — Base $100,000 + 20% of car depot value. Soft suspension and high traction loss for drifting. Mutually exclusive with Engine Chip.
- **Stance Kit** — $50,000. Live arrow-key editor for camber, ride height, and wheel distance. Settings saved to DB and restored on spawn.
- **Nitrous Kit** — $50,000 install, $25,000 refill. +10 MPH burst for 5 seconds with a torque surge. One kit per vehicle, 30-minute cooldown enforced server-side. Must return to the refill station to recharge.
- **Neon Kits** — $25,000 each. Static, RGB, Rainbow, and Strobe modes. Colour and mode saved to DB and restored on spawn.
- **4 Ramp Zones** — Anyone can drive in and view prices. Only the `tuner` job can install mods.
- **Removal Menu** — All mods including the engine chip can be removed at the tuner shop by a tuner.
- **Persistent Mods** — All installations survive reconnects and server restarts.
- **Custom HTML UI** — Fully themed shop menu with live installed state indicators.
- **NOS HUD** — Bottom-right overlay showing canister charge, active burn progress, and cooldown timer.
- **QBCore logs + Discord webhook** — Every purchase and removal is logged.

---

## Dependencies

| Resource | Link |
|---|---|
| qb-core | https://github.com/qbcore-framework/qb-core |
| ox_lib | https://github.com/overextended/ox_lib |
| oxmysql | https://github.com/overextended/oxmysql |

---

## Installation

1. Drop the `qb-illegaltuner` folder into your server's `resources` directory.
2. Add `ensure qb-illegaltuner` to your `server.cfg`.
3. The database table (`illegaltuner_mods`) is created automatically on first start.
4. Configure the resource in `config.lua`.

---

## Configuration

### Ramp Locations
```lua
Config.RampLocations = {
    vector3(0.0, 0.0, 0.0), -- ramp 1
    vector3(0.0, 0.0, 0.0), -- ramp 2
    vector3(0.0, 0.0, 0.0), -- ramp 3
    vector3(0.0, 0.0, 0.0), -- ramp 4
}
```
Set these to the workspace spots inside your tuner shop.

### Jobs
```lua
Config.RequiredJob = 'tuner'   -- job required to install mods
Config.PDJob       = 'police'  -- job allowed to use /removechip
```

### Discord Webhook
```lua
Config.DiscordWebhook = 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE'
```
Leave as `''` to disable Discord logging.

### Payment
```lua
Config.PaymentType = 'dirty_cash'  -- QBCore item name used for payment
```

All prices, boost values, cooldowns, neon colours, and progress bar durations are configurable in `config.lua`.

---

## Pricing

| Mod | Price |
|---|---|
| Engine Chip | $250,000 base + 30% car depot value |
| Drift Chip | $100,000 base + 20% car depot value |
| Stance Kit | $50,000 |
| Nitrous Kit | $50,000 install · $25,000 refill |
| Neon (all types) | $25,000 each |

---

## Required Items

The following items must exist in your QBCore shared items. Images are included in the `Dependencies/` folder.

| Item | Used For |
|---|---|
| `s3_chip` | Engine Chip install |
| `drift_chip` | Drift Chip install |
| `stance_rod` | Stance Kit install |
| `dirty_cash` | Payment (or configure your own) |

---

## Commands

| Command | Job Required | Description |
|---|---|---|
| `/removechip` | police | Removes an illegal engine chip from the nearest vehicle |
| `/checkchip` | anyone | Shows what chip is installed on the nearest vehicle |

---

## Locale / Translations

All player-facing strings are in `locales/en.lua`. To add a new language, duplicate the file (e.g. `locales/de.lua`), translate the values, and update `fxmanifest.lua` to load it.

---

## Author

Made by **seeseal** — https://github.com/seeseal

---

## License

MIT — free to use and modify. Credit appreciated.