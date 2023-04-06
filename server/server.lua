local QBCore = exports['qb-core']:GetCoreObject()
local marketItems = {}
local pendingOrders = {}
local availableLocations = {}

local function getMarketItems()
    if not Config.randomItems then
        for i=1, #Config.items do
            local randomStock = math.random(Config.items[i].minStock, Config.items[i].maxStock)
            marketItems[i] = Config.items[i]
            marketItems[i].stock = randomStock
        end 
        TriggerClientEvent("glow_blackmarket_cl:updateMarketItems", -1, marketItems)
        SetTimeout(Config.reset * 60000, getMarketItems)
        return
    end
    
    local copyTable = {}
    for i=1, #Config.items do
        copyTable[i] = Config.items[i]
    end

    local newLen = #copyTable
    local chosenItems = {}
    for i=1, Config.randomItems do
        local randomIndex = math.random(newLen)
        local randomStock = math.random(copyTable[randomIndex].minStock, copyTable[randomIndex].maxStock)
        chosenItems[i] = copyTable[randomIndex]
        chosenItems[i].stock = randomStock
        table.remove(copyTable, randomIndex)
        newLen -= 1
    end

    marketItems = chosenItems

    TriggerClientEvent("glow_blackmarket_cl:updateMarketItems", -1, marketItems)
    SetTimeout(Config.reset * 60000, getMarketItems)
end

local function isMarketItem(item)
    local inMarket = false
    for i=1, #marketItems do
        if marketItems[i].item == item then
            inMarket = true
            break
        end
    end

    return inMarket
end

local function checkStock(item, quantity)
    local hasStock = false
    for i=1, #marketItems do
        if marketItems[i].item == item then
            if marketItems[i].stock >= quantity then
                hasStock = true
            end
            break
        end
    end
    return hasStock
end

local function getItemPrice(item)
    local price = 0 
    for i=1, #marketItems do
        if marketItems[i].item == item then
            price = marketItems[i].price
            break
        end
    end
    return price
end

local function updateMarketStock(item, quantity)
    for i=1, #marketItems do
        if marketItems[i].item == item then
            marketItems[i].stock -= quantity
            break
        end
    end
end

local function generateStashId()
    local id = "GBM_"
    for i=1, 6 do
        id = id .. tostring(math.random(0,9))
    end
    return id
end

local function saveOrderStash(stashId, items, cb)
    if not stashId or not items then return end

    for _, item in pairs(items) do
        item.description = nil
    end

    MySQL.insert('INSERT INTO stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
        ['stash'] = stashId,
        ['items'] = json.encode(items)
    }, function(id)
        cb(id)
    end)
end

local function deleteStash(stashId)
    MySQL.query("DELETE FROM stashitems WHERE stash = ?", {stashId})
end

local function setupAvailableLocations()
    for i=1, #Config.deliveryLocations do
        availableLocations[#availableLocations + 1] = i 
    end
end

local function getRandomAvailLocation()
    local chosenIndex = math.random(#availableLocations)
    local locationIndex = availableLocations[chosenIndex]
    table.remove(availableLocations, chosenIndex)

    return locationIndex
end

local function orderComplete(index, stashId)
    if not pendingOrders[index] or not pendingOrders[index].stashId == stashId  then return end

    if pendingOrders[index].props then
        for _, v in pairs(pendingOrders[index].props) do
            local entity = NetworkGetEntityFromNetworkId(v)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
    end

    if pendingOrders[index].isOpen then
        TriggerClientEvent("glow_blackmarket_cl:removeLootTarget", -1, index)
    else
        TriggerClientEvent("glow_blackmarket_cl:removeLockTarget", -1, index)
    end

    deleteStash(pendingOrders[index].stashId)


    if pendingOrders[index].src then
        local Player = QBCore.Functions.GetPlayer(pendingOrders[index].src)
        if Player.PlayerData.citizenid == pendingOrders[index].cid then
            TriggerClientEvent("glow_blackmarket_cl:orderComplete", pendingOrders[index].src)
        end
    end

    availableLocations[#availableLocations + 1] = index
    pendingOrders[index] = nil
end

local function orderReady(index, stashId)
    if pendingOrders[index].src then
        local Player = QBCore.Functions.GetPlayer(pendingOrders[index].src)
        if Player.PlayerData.citizenid == pendingOrders[index].cid then
            TriggerClientEvent("glow_blackmarket_cl:orderReady", pendingOrders[index].src, index, Config.deliveryLocations[index])
        end
    end
    
    SetTimeout(Config.orderTimeout * 60000, function()
        orderComplete(index, stashId)
    end) 
end

local function cleanUpProps()
    for _, v in pairs(pendingOrders) do
        if v.props then
            for _, prop in pairs(v.props) do
                local entity = NetworkGetEntityFromNetworkId(prop)
                if DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
            end
        end
    end
end

local function cleanUpStashes()
    for _, v in pairs(pendingOrders) do
        deleteStash(v.stashId)
    end
end

QBCore.Functions.CreateUseableItem(Config.useItem, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
	if not Player or not Player.Functions.GetItemByName(Config.useItem) then return end
    TriggerClientEvent("glow_blackmarket_cl:openUI", source)
end)

QBCore.Functions.CreateCallback("glow_blackmarket_sv:getMarketItems", function(src, cb)
    cb(marketItems)
end)

QBCore.Functions.CreateCallback("glow_blackmarket_sv:attemptOrder", function(src, cb, order)
    if not order or #order == 0 then return end
    local cost = 0
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.Functions.GetItemByName(Config.useItem) then return end

    local numOfOrders = 0
    for _, v in pairs(pendingOrders) do 
        if v.src == src or v.cid == cid then
            cb({success = false, notif = "Order failed", error = "player already has order pending"})
            return
        end
        numOfOrders += 1
    end
    
    if numOfOrders >= Config.maxOrderQueue then
        cb({success = false, notif = Config.notifText.maxOrder})
        return
    end

    local playerOrder = {}

    for i=1, #order do
        local itemQuant = tonumber(order[i].quantity)
        if not isMarketItem(order[i].item) then
            cb({success = false, notif = "Order failed", error = "invalid item found in cart"})
            return
        end

        if not checkStock(order[i].item, itemQuant) then
            cb({success = false, notif = Config.notifText.insufficientStock})
            return
        end

        if playerOrder[order[i].item] then
            cb({success = false, notif = "Order failed", error = "order contains duplicate items"})
            return
        end

        playerOrder[order[i].item] = itemQuant
        cost += getItemPrice(order[i].item) * itemQuant
    end

    if Player.Functions.RemoveMoney(Config.paymentType, cost) then
        local locationIndex = getRandomAvailLocation()
        local deliveryMins = math.random(Config.deliveryTime.min, Config.deliveryTime.max)
        local deliveryTime = os.time() + (deliveryMins * 60)
        local stashId = generateStashId()

        pendingOrders[locationIndex] = {
            src = src,
            cid = Player.PlayerData.citizenid,
            order = playerOrder,
            deliveryTime = deliveryTime,
            stashId = stashId,
            lockInProgress = false,
            lootInProgress = false,
            isOpen = false,
            isLooted = false,
        }

        for k,v in pairs(playerOrder) do
            updateMarketStock(k, v)
        end

        SetTimeout(deliveryMins * 60000, function()
            orderReady(locationIndex, stashId)
        end)

        TriggerClientEvent("glow_blackmarket_cl:updateStock", -1, marketItems, src)
        cb({success = true, notif = Config.notifText.orderSuccess, epochTime = deliveryTime})
    else
        cb({success = false, notif = Config.notifText.cantAfford})
    end
end)

RegisterNetEvent("glow_blackmarket_sv:propsSpawned", function(netIds, locationIndex)
    if not pendingOrders[locationIndex] then return end
    local lock = NetworkGetEntityFromNetworkId(netIds.lock)
    local lockCoords = vec4(GetEntityCoords(lock), GetEntityHeading(lock))
    pendingOrders[locationIndex].props = netIds 

    TriggerClientEvent("glow_blackmarket_cl:addLockTarget", -1, locationIndex, lockCoords)
end)

RegisterNetEvent("glow_blackmarket_sv:attemptContainer", function(index)
    local src = source
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(Config.deliveryLocations[index])) > 5 or not pendingOrders[index] then return end

    if pendingOrders[index].lockInProgress then
        TriggerClientEvent('QBCore:Notify', src, "Someone is already doing that", "error")
        return
    end
    
    if pendingOrders[index].isOpen then
        TriggerClientEvent('QBCore:Notify', src, "This is already open", "error")
        return
    end

    pendingOrders[index].lockInProgress = true
    TriggerClientEvent("glow_blackmarket_cl:openContainer", src, index, pendingOrders[index].props)
end)

RegisterNetEvent("glow_blackmarket_sv:openContainer", function(index)
    local src = source
    local crate = NetworkGetEntityFromNetworkId(pendingOrders[index].props.crate)
    local crateCoords = vec4(GetEntityCoords(crate), GetEntityHeading(crate))
    pendingOrders[index].lockInProgress = false
    pendingOrders[index].isOpen = true
    pendingOrders[index].props.lock = nil

    TriggerClientEvent("glow_blackmarket_cl:updateOpenContainer", -1, index, pendingOrders[index].props.container, pendingOrders[index].props.collision, crateCoords, true)
end)

RegisterNetEvent("glow_blackmarket_sv:attemptLoot", function(index)
    local src = source
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(Config.deliveryLocations[index])) > 5 or not pendingOrders[index] then return end

    if pendingOrders[index].lootInProgress then
        TriggerClientEvent('QBCore:Notify', src, "Someone is already doing that", "error")
        return
    end

    if pendingOrders[index].isLooted then
        TriggerClientEvent("inventory:client:SetCurrentStash", src, pendingOrders[index].stashId)
        exports["qb-inventory"]:OpenInventory("stash", pendingOrders[index].stashId, nil, src)
        return
    end

    pendingOrders[index].lootInProgress = true
    TriggerClientEvent("glow_blackmarket_cl:lootContainer", src, index)
end)

RegisterNetEvent("glow_blackmarket_sv:finishLooting", function(index)
    local src = source
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(Config.deliveryLocations[index])) > 5 or not pendingOrders[index] or pendingOrders[index].isLooted then return end

    local orderItems = {}
    local stashId = pendingOrders[index].stashId
    local slot = 1
    for k, v in pairs(pendingOrders[index].order) do
        local itemInfo = QBCore.Shared.Items[k:lower()]
        if itemInfo then
            itemInfo.info = {}
            itemInfo.amount = v
            itemInfo.slot = slot
            -- If item has metedata add it here
            if itemInfo.type == "weapon" then
                itemInfo.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
                itemInfo.info.quality = 100
            end
            orderItems[#orderItems + 1] = itemInfo
        end
        slot += 1
    end

    saveOrderStash(stashId, orderItems, function(id)
        if id then
            TriggerClientEvent("inventory:client:SetCurrentStash", src, stashId)
            exports["qb-inventory"]:OpenInventory("stash", stashId, nil, src)
        end
    end)

    pendingOrders[index].lootInProgress = false
    pendingOrders[index].isLooted = true

    SetTimeout(Config.lootTimeout * 60000, function()
        orderComplete(index, stashId)
    end)
end)

RegisterNetEvent("glow_blackmarket_sv:cancelLooting", function(index)
    pendingOrders[index].lootInProgress = false
end)

RegisterNetEvent("glow_blackmarket_sv:initPendingOrders", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    for k, v in pairs(pendingOrders) do
        -- check if player has any pending orders
        if v.cid == Player.PlayerData.citizenid then
            v.src = src
            TriggerClientEvent("glow_blackmarket_cl:hasPendingOrder", src, marketItems, v.order, v.deliveryTime)      
            -- create props if needed
            local propDespawned = false
            if v.props then
                for prop, netId in pairs(v.props) do
                    local entity = NetworkGetEntityFromNetworkId(netId)
                    if not DoesEntityExist(entity) then
                        if not (v.isOpen and prop == "lock") then
                            propDespawned = true
                        end 
                    end
                end
            end
            
            if propDespawned then
                for prop, netId in pairs(v.props) do
                    local entity = NetworkGetEntityFromNetworkId(netId)
                    if not DoesEntityExist(entity) then
                        DeleteEntity(entity)
                    end
                end
                v.props = nil
            end
            
            if os.time() - v.deliveryTime > 0 then
                if not v.props then
                    -- removes targets since it gets recreated later
                    if v.isOpen then 
                        TriggerClientEvent("glow_blackmarket_cl:removeLootTarget", -1, k)
                        v.isOpen = false
                    end
                    TriggerClientEvent("glow_blackmarket_cl:orderReady", src, k, Config.deliveryLocations[k])
                else
                    TriggerClientEvent("glow_blackmarket_cl:enableLocateButton", src, k)
                end
            end
        end
        
        -- Create target zones for pending orders
        if v.props then
            if not v.isOpen then
                local lock = NetworkGetEntityFromNetworkId(v.props.lock)
                local lockCoords = vec4(GetEntityCoords(lock), GetEntityHeading(lock))
                TriggerClientEvent("glow_blackmarket_cl:addLockTarget", src, k, lockCoords)
            else
                local crate = NetworkGetEntityFromNetworkId(v.props.crate)
                local crateCoords = vec4(GetEntityCoords(crate), GetEntityHeading(crate))

                TriggerClientEvent("glow_blackmarket_cl:updateOpenContainer", src, k, v.props.container, v.props.collision, crateCoords, false)
            end
        end
        
    end
    
    TriggerClientEvent("glow_blackmarket_cl:updateMarketItems", src, marketItems)
end)


AddEventHandler('playerDropped', function()
    local src = source
    for _, v in pairs(pendingOrders) do
        if v.src == src then
            v.src = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    getMarketItems()
    setupAvailableLocations()
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanUpProps()
    cleanUpStashes()
end)