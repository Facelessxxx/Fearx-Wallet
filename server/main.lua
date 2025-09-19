local ox_inventory = nil

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(100)
    end
    ox_inventory = exports.ox_inventory
    print('[fearx_wallet] ox_inventory detected and loaded')
end)

local Config = Config or {}

local function logDebug(...)
    if Config.Debug then
        print('[fearx_wallet]', ...)
    end
end

local Allowed = {}
for _, name in ipairs(Config.AllowedItems or {}) do
    Allowed[name] = true
end

local function getIdentifier(src)
    if GetResourceState('ox_core') ~= 'missing' and exports.ox_core then
        local player = exports.ox_core:GetPlayer(src)
        if player then return player.charId or player.license or ('char:'..src) end
    end
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:find('license:') then return id end
    end
    return ('player:%s'):format(src)
end

local function makeStashId(src, item)
    if not item then return nil end
    if Config.UniquePerItem then
        local serial = item.metadata and (item.metadata.serial or item.metadata.id or item.metadata.uid)
        if serial and type(serial) == 'string' and #serial > 0 then
            local id = ('wallet:%s'):format(serial)
            logDebug('stash id (per-item)', id)
            return id
        end
        local id = ('wallet:%s'):format(getIdentifier(src))
        logDebug('stash id fallback (per-player)', id)
        return id
    end
    local id = ('wallet:%s'):format(getIdentifier(src))
    logDebug('stash id (per-player)', id)
    return id
end

local ActiveMonitors = {}

local function stopWalletMonitor(stashId)
    local m = ActiveMonitors[stashId]
    if m then m.active = false ActiveMonitors[stashId] = nil end
end

local function startWalletMonitor(stashId, src)
    if ActiveMonitors[stashId] then
        return
    end
    ActiveMonitors[stashId] = { active = true, src = src }
    CreateThread(function()
        logDebug('monitor start', stashId, 'src', src)
        local guard = 0
        while ActiveMonitors[stashId] and ActiveMonitors[stashId].active do
            if not ox_inventory then break end
            local inv = ox_inventory:GetInventory(stashId)
            if not inv or not inv.items then
                guard = guard + 1
                if guard > 10 then break end
                Wait(50)
                goto continue
            end

            local totalCash = 0
            for slot, item in pairs(inv.items) do
                if item and item.name then
                    if item.name == Config.MoneyItem then
                        totalCash = totalCash + (item.count or 0)
                    elseif not Allowed[item.name] then
                        ox_inventory:RemoveItem(stashId, item.name, item.count or 1, item.metadata, slot)
                        if src and src > 0 then
                            ox_inventory:AddItem(src, item.name, item.count or 1, item.metadata)
                            TriggerClientEvent('ox_lib:notify', src, {
                                title = 'Wallet',
                                description = ('%s not allowed in wallet'):format(item.name),
                                type = 'error'
                            })
                        end
                        logDebug('removed unauthorized', item.name, 'from', stashId)
                    end
                end
            end

            if (Config.MaxCash or 0) > 0 and totalCash > Config.MaxCash then
                local excess = totalCash - Config.MaxCash
                for slot, item in pairs(inv.items) do
                    if excess <= 0 then break end
                    if item and item.name == Config.MoneyItem and item.count and item.count > 0 then
                        local take = math.min(item.count, excess)
                        ox_inventory:RemoveItem(stashId, Config.MoneyItem, take, item.metadata, slot)
                        excess = excess - take
                    end
                end
                if src and src > 0 then
                    ox_inventory:AddItem(src, Config.MoneyItem, totalCash - Config.MaxCash)
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = 'Wallet',
                        description = 'Excess cash returned to your inventory',
                        type = 'warning'
                    })
                end
                logDebug('capped cash in', stashId, 'to', Config.MaxCash)
            end

            Wait(50)
            ::continue::
        end
        logDebug('monitor stop', stashId)
    end)
end

lib.callback.register('fearx_wallet:open', function(source, item)
    local src = source
    if not item or item.name ~= Config.WalletItem then
        return false, 'Invalid item'
    end

    if not ox_inventory then
        return false, 'ox_inventory not available'
    end

    local stashId = makeStashId(src, item)
    if not stashId then return false, 'No stash id' end

    local label = 'Wallet'
    local slots = Config.Slots or 4
    local maxWeight = Config.MaxWeight or 5000

    ox_inventory:RegisterStash(stashId, label, slots, maxWeight)

    TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
    if ox_inventory then
        startWalletMonitor(stashId, src)
    end
    return true
end)

local function isWalletStash(invType, invId)
    return invType == 'stash' and type(invId) == 'string' and invId:find('^wallet:') ~= nil
end

local function validateWalletItem(source, inventoryId, itemName, count)
    if not ox_inventory or not isWalletStash('stash', inventoryId) then
        return true
    end

    if itemName == Config.MoneyItem then
        if (Config.MaxCash or 0) > 0 then
            local current = 0
            local inv = ox_inventory:GetInventory(inventoryId)
            if inv and inv.items then
                for _, it in pairs(inv.items) do
                    if it.name == Config.MoneyItem then
                        current = current + (it.count or it.amount or 0)
                    end
                end
            end
            local addCount = count or 0
            if current + addCount > Config.MaxCash then
                if source and source > 0 then
                    TriggerClientEvent('ox_lib:notify', source, {
                        title = 'Wallet',
                        description = ('Wallet max cash is %d'):format(Config.MaxCash),
                        type = 'error'
                    })
                end
                return false
            end
        end
        return true
    end

    if not Allowed[itemName] then
        if source and source > 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Wallet',
                description = 'Only IDs, licenses and cash allowed in wallet',
                type = 'error'
            })
        end
        return false
    end
    return true
end

AddEventHandler('ox_inventory:server:canCarryItem', function(source, inventoryId, itemName, count, metadata, slot, cb)
    local canCarry = true
    if isWalletStash('stash', inventoryId) then
        canCarry = validateWalletItem(source, inventoryId, itemName, count)
    end
    cb(canCarry)
end)

AddEventHandler('ox_inventory:canCarryItem', function(source, inventoryId, itemName, count, metadata, slot, cb)
    local canCarry = true
    if isWalletStash('stash', inventoryId) then
        canCarry = validateWalletItem(source, inventoryId, itemName, count)
    end
    cb(canCarry)
end)

AddEventHandler('ox_inventory:moveItem', function(source, fromInventory, toInventory, fromSlot, toSlot, count, cb)
    if toInventory and isWalletStash('stash', toInventory) then
        local fromInv = ox_inventory and ox_inventory:GetInventory(fromInventory)
        if fromInv and fromInv.items and fromInv.items[fromSlot] then
            local item = fromInv.items[fromSlot]
            local canMove = validateWalletItem(source, toInventory, item.name, count or item.count or 1)
            if not canMove then
                cb(false)
                return
            end
        end
    end
    cb(true)
end)

AddEventHandler('ox_inventory:swapItems', function(source, fromInventory, toInventory, fromSlot, toSlot, cb)
    if toInventory and isWalletStash('stash', toInventory) then
        local fromInv = ox_inventory and ox_inventory:GetInventory(fromInventory)
        if fromInv and fromInv.items and fromInv.items[fromSlot] then
            local item = fromInv.items[fromSlot]
            local canSwap = validateWalletItem(source, toInventory, item.name, item.count or 1)
            if not canSwap then
                cb(false)
                return
            end
        end
    end
    cb(true)
end)

CreateThread(function()
    while not ox_inventory do
        Wait(100)
    end
    
    local function monitorWalletChanges(source, action, inventory, slot, item)
        if not inventory or not isWalletStash('stash', inventory) then
            return
        end
        
        if (action == 'added' or action == 'set' or action == 'update') and item then
            local canAdd = validateWalletItem(source, inventory, item.name, item.count or 0)
            if not canAdd then
                CreateThread(function()
                    Wait(50)
                    if ox_inventory then
                        ox_inventory:RemoveItem(inventory, item.name, item.count or 1, item.metadata, slot)
                        ox_inventory:AddItem(source, item.name, item.count or 1, item.metadata)
                    end
                end)
            end
        end
    end
    
    AddEventHandler('ox_inventory:updateInventory', monitorWalletChanges)
    AddEventHandler('ox_inventory:inventoryUpdate', monitorWalletChanges)
    AddEventHandler('ox_inventory:slotUpdate', monitorWalletChanges)
    AddEventHandler('ox_inventory:itemAdded', monitorWalletChanges)
    AddEventHandler('ox_inventory:setSlot', monitorWalletChanges)
end)

RegisterCommand('openwallet', function(src)
    TriggerClientEvent('fearx_wallet:openWallet', src)
end)

RegisterCommand('cleanwallets', function(src)
    if not IsPlayerAceAllowed(src, 'command.cleanwallets') then
        return
    end
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Wallet Cleanup',
        description = 'Wallet restrictions are now actively preventing unauthorized items.',
        type = 'success'
    })
end, true)

AddEventHandler('ox_inventory:closedInventory', function(source, invType, invId)
    if isWalletStash(invType, invId) then
        stopWalletMonitor(invId)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id, m in pairs(ActiveMonitors or {}) do
        m.active = false
    end
    ActiveMonitors = {}
end)
