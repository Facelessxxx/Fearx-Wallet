local Config = Config or {}
local ox_inventory = nil

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(100)
    end
    ox_inventory = exports.ox_inventory
end)

RegisterNetEvent('fearx_wallet:openWallet', function(item)
    if not ox_inventory then
        lib.notify({ title = 'Wallet', description = 'Inventory system not available.', type = 'error' })
        return
    end

    if not item then
        local items = ox_inventory:Search('slots', Config.WalletItem)
        if items and items[1] then
            item = items[1]
        end
    end
    if not item then
        lib.notify({ title = 'Wallet', description = 'You do not have a wallet.', type = 'error' })
        return
    end

    local ok, err = lib.callback.await('fearx_wallet:open', 5000, item)
    if not ok then
        lib.notify({ title = 'Wallet', description = err or 'Failed to open wallet', type = 'error' })
    end
end)

if Config.OpenOnUse then
end
