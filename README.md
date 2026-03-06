# qb-illegaltuner

An illegal tuner shop resource for **QBCore** FiveM servers. Players with the `tuner` job can install performance and cosmetic upgrades on client vehicles, paid with black money. All modifications persist across reconnects via database storage.

---

## Features

- **Engine Chip** — Adds +15 MPH top speed. Price is dynamically calculated server-side: base $250,000 + 30% of the vehicle's depot value. One install per vehicle — only removable by PD via `/removechip`.
- **Drift Chip** — Soft suspension and high traction loss for drifting. Mutually exclusive with the engine chip.
- **Stance Kit** — Live arrow-key editor for camber, ride height, and wheel distance. Settings saved to DB and restored on spawn.
- **Nitrous Kit** — +10 MPH burst for 10 seconds. One kit per vehicle, 30-minute cooldown enforced server-side. Must return to the shop to refill.
- **Neon Kits** — Static, RGB, Rainbow, and Strobe modes. Colour and mode saved to DB and restored on spawn.
- **Removal Menu** — All mods (except engine chip) can be removed at the shop by the tuner.
- **Persistent mods** — All installations survive reconnects and server restarts.
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
4. Configure the resource in `config.lua` (see below).

---

## Configuration

Open `config.lua` and update the following:

### Shop Location
```lua
Config.ShopLocation = vector3(0.0, 0.0, 0.0)   -- replace with your coords
```

### Jobs
```lua
Config.RequiredJob = 'tuner'   -- job required to open the shop
Config.PDJob       = 'police'  -- job allowed to use /removechip
```

### Discord Webhook
```lua
Config.DiscordWebhook = 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE'
```
Leave as `''` to disable Discord logging.

### Payment
```lua
Config.PaymentType = 'black_money'  -- QBCore item name used for payment
```

All prices, boost values, cooldowns, neon colours, and progress bar durations are also configurable in `config.lua`.

---

## PD Command

| Command | Job Required | Description |
|---|---|---|
| `/removechip` | police | Removes an illegal engine chip from the nearest vehicle |

---

## Locale / Translations

All player-facing strings are in `locales/en.lua`. To add a new language, duplicate the file (e.g. `locales/de.lua`), translate the values, and update `fxmanifest.lua` to load it.

---

## Author

Made by **seeseal** — https://github.com/seeseal

---

## License

MIT — free to use and modify. Credit appreciated.
