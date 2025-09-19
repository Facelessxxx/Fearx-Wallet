Config = {}

-- Name of the wallet item in ox_inventory
Config.WalletItem = 'wallet'

-- Max cash allowed in a wallet (set to 0 to disable cash storage)
Config.MaxCash = 5000

-- Name of ox_inventory money item (commonly 'money' or 'cash')
Config.MoneyItem = 'money'

-- Allowed item names that can be stored inside the wallet besides cash
Config.AllowedItems = {
    'id_card',          -- citizen ID
    'driver_license',   -- driver's license
    'weapon_license'    -- gun license
}

-- Stash properties
Config.Slots = 4          -- exactly 4 slots: ID, driver license, weapon license, cash
Config.MaxWeight = 2000   -- grams

-- If true, each wallet item will have a unique stash id tied to that item metadata
Config.UniquePerItem = true

-- Open on ox_inventory useItem event from item config
Config.OpenOnUse = true

-- Enable debug logs in server console
Config.Debug = false