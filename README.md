# fearx_wallet

FiveM resource adding a wallet container compatible with ox_inventory.

Features:
- Use wallet item to open a dedicated stash
- Restrict contents to ID cards and licenses
- Optional cash storage with configurable max limit
- Unique stash per wallet item (or per player)

## Requirements
- ox_inventory
- ox_lib
- (optional) oxmysql if your setup requires it; included in manifest by default

## Installation
1. Place the `fearx_wallet` folder in your server resources.
2. Add `ensure fearx_wallet` after ox_inventory in your server.cfg.
3. Import or add the wallet item to your ox_inventory items list (example below).

### Item config example (ox_inventory data/items.lua)
```lua
['wallet'] = {
    label = 'Wallet',
    weight = 150,
    stack = false,
    close = true,
    description = 'Hold your ID, licenses, and some cash.',
    client = {
        event = 'fearx_wallet:openWallet'
    }
}
```

If your item definitions are in JSON or via database, ensure the same name and client event.

### Allowed items
By default only these item names are allowed inside the wallet:
- `id_card`
- `driver_license`
- `weapon_license`
- plus the money item name defined in `Config.MoneyItem`

Adjust `Config.AllowedItems` in `config.lua` to match your items.

### Cash handling
- Set `Config.MaxCash` to the maximum amount allowed in a wallet (0 disables cash storage).
- Set `Config.MoneyItem` to your money item name if you use money as an item in ox_inventory.

If you use framework accounts (non-item cash), you need a custom UI and transfer logic; this resource focuses on item-based money.

### Commands
- `/openwallet` — fallback command to open the first wallet in your inventory.

### Config
See `config.lua` for:
- Wallet item name
- Allowed items
- Max cash and money item name
- Unique stash per item or per player
- Stash slots and weight

## Notes
- The resource uses ox_inventory RegisterHook to enforce allowed contents and cash limit. Ensure your ox_inventory is updated to a version that supports these hooks.
- If your IDs/licenses have different item names, update `Config.AllowedItems` accordingly.
- If you want the stash to only have 4 slots, change `Config.Slots` to 4. Restriction on item types remains enforced by hooks.
