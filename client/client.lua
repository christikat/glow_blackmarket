local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local marketItems, orderLocation, tabletProp, currentMoney
local targetZones = {}
local displayingUI = false

local function removeTargetZones()
    for i=1, #targetZones do
        exports['qb-target']:RemoveZone(targetZones[i])
    end
end

local function tabletAnim(state)
    local ped = PlayerPedId()
    if state then
        local tabletHash = joaat(Config.tabletAnim.prop)
        loadModel(tabletHash)
        loadAnimDict(Config.tabletAnim.dict)
    
        tabletProp = CreateObject(tabletHash, GetEntityCoords(ped), true, true, false)
        AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 28422), -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(tabletHash)
    
        TaskPlayAnim(ped, Config.tabletAnim.dict, Config.tabletAnim.anim, 1.0, 1.0, -1, 51, 0, 0, 0, 0)
    else
        DeleteObject(tabletProp)
        ClearPedTasks(ped)
    end
end

local function displayUI(state)
    displayingUI = state
    tabletAnim(state)
    if state then
        SendNUIMessage({
            action = "setVisible",
            data = true,
        })
    else
        SendNUIMessage({
            action = "setVisible",
            data = false,
        })
    end 
    SetNuiFocus(state, state)
end

local function tabletNotification(text, notifType)
    SendNUIMessage({
        action = "notification",
        data = {
            text = text,
            notifType = notifType,
        }
    })
end

local function doContainerAnim(index, containerNetId, lockNetId, collisionNetId)
    local container = NetworkGetEntityFromNetworkId(containerNetId)
    local lock = NetworkGetEntityFromNetworkId(lockNetId)
    local collision = NetworkGetEntityFromNetworkId(collisionNetId)

    NetworkRequestControlOfEntity(container)
    NetworkRequestControlOfEntity(lock)
    local timer = GetGameTimer()
    while not NetworkHasControlOfEntity(container) or not NetworkHasControlOfEntity(lock) do
        Wait(0)
        if GetGameTimer() - timer > 5000 then
            printError("Failed to get control of object")
            break
        end
    end

    loadAnimDict(Config.containerAnim.dict)
    loadPtfx(Config.containerAnim.ptfx)
    loadAudio(Config.containerAnim.audioBank)
    
    local grinderHash = joaat(Config.props.grinder)
    local bagHash = joaat(Config.props.bag)
    loadModel(grinderHash)
    loadModel(bagHash)

    local ped = PlayerPedId()
    local containerCoords = GetEntityCoords(container)
    local containerRot = GetEntityRotation(container)
    local playerCoords = GetEntityCoords(ped)
    local grinder = CreateObject(grinderHash, playerCoords, true, true, false)
    local bag = CreateObject(bagHash, playerCoords, true, true, false)
    SetEntityCollision(bag, false, false)

    FreezeEntityPosition(ped, true)
    
    local containerScene = NetworkCreateSynchronisedScene(containerCoords, containerRot, 2, true, false, 1.0, 0.0, 1.0)
    NetworkAddPedToSynchronisedScene(ped, containerScene, Config.containerAnim.dict, Config.containerAnim.player, 10.0, 10.0, 0, 0, 1000.0, 0)
    NetworkAddEntityToSynchronisedScene(lock, containerScene, Config.containerAnim.dict, Config.containerAnim.lock, 2.0, -4.0, 134149)
    NetworkAddEntityToSynchronisedScene(grinder, containerScene, Config.containerAnim.dict, Config.containerAnim.grinder, 2.0, -4.0, 134149)
    NetworkAddEntityToSynchronisedScene(bag, containerScene, Config.containerAnim.dict, Config.containerAnim.bag, 2.0, -4.0, 134149)
    NetworkStartSynchronisedScene(containerScene)

    PlayEntityAnim(container, Config.containerAnim.container, Config.containerAnim.dict, 8.0, false, true, false, 0, 0)   
    
    CreateThread(function()
        while NetworkGetLocalSceneFromNetworkId(containerScene) == -1 do Wait(0) end
        local localScene = NetworkGetLocalSceneFromNetworkId(containerScene)
        local ptfx
        
        while IsSynchronizedSceneRunning(localScene) do
            if HasAnimEventFired(ped, -1953940906) then
                UseParticleFxAsset("scr_tn_tr")
                ptfx = StartNetworkedParticleFxLoopedOnEntity("scr_tn_tr_angle_grinder_sparks", grinder, 0.0, 0.25, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false, 1065353216, 1065353216, 1065353216, 1)
            elseif HasAnimEventFired(ped, -258875766) then
                StopParticleFxLooped(ptfx, false)
            end
            Wait(0)
        end
    end)
    
    Wait(GetAnimDuration(Config.containerAnim.dict, Config.containerAnim.container) * 1000)
    
    FreezeEntityPosition(ped, false)
    NetworkStopSynchronisedScene(containerScene)

    DeleteObject(grinder)
    DeleteObject(lock)
    DeleteObject(bag)
    ClearPedTasks(ped)

    TriggerServerEvent("glow_blackmarket_sv:openContainer", index)

    DisposeSynchronizedScene(containerScene)
    RemoveNamedPtfxAsset(Config.containerAnim.ptfx)
    ReleaseNamedScriptAudioBank(Config.containerAnim.audioBank)
    RemoveAnimDict(Config.containerAnim.dict)
end

local function spawnObject(model, coords)
    local propHash = type(model) == 'string' and joaat(model) or model
    loadModel(propHash)
    local object = CreateObject(propHash, coords.xyz, true, true, false)
    while not DoesEntityExist(object) do
        Wait(10)
    end

    SetEntityAsMissionEntity(object, true, true)
    FreezeEntityPosition(object, true)
    SetEntityHeading(object, coords.w)

    SetModelAsNoLongerNeeded(propHash)
    return object
end

local function spawnContainer(coords)
    loadAnimDict(Config.containerAnim.dict)
    local container = spawnObject(Config.props.container, vector4(coords.x, coords.y, coords.z - 1, coords.w - 180))
    local containerCoords = GetEntityCoords(container)
    
    local lockCoords = GetAnimInitialOffsetPosition(Config.containerAnim.dict, Config.containerAnim.lock, GetEntityCoords(container), GetEntityRotation(container), 0.0, 0)
    local lock = spawnObject(Config.props.lock, vector4(lockCoords, coords.w - 180))
    SetEntityCoords(lock, lockCoords)

    local crateCoords = GetObjectOffsetFromCoords(coords, 0.0, -0.6, -0.8)
    local crate = spawnObject(Config.props.crate, vector4(crateCoords, coords.w + 90))

    local collision = spawnObject(Config.props.containerCollison, vector4(containerCoords, coords.w - 180))
    SetEntityCoords(collision, containerCoords, false, false, false)
    SetEntityCollision(collision, false, false)
    
    local props = {
        container = container, 
        lock = lock,
        crate = crate,
        collision = collision,
    }
    return props
end

RegisterNetEvent("glow_blackmarket_cl:openUI", function()
    displayUI(true)
end)

RegisterNetEvent("glow_blackmarket_cl:updateMarketItems", function(items)
    marketItems = items

    SendNUIMessage({
        action = "updateMarketItems",
        data = items
    })
end)

RegisterNetEvent("glow_blackmarket_cl:updateStock", function(items, orderSrc)
    marketItems = items
    if displayingUI then
        local isOwner = false
        if orderSrc == GetPlayerServerId(PlayerId()) then
            isOwner = true
        end
        SendNUIMessage({
            action = "updateStock",
            data = {
                items = items,
                notif = Config.notifText.stockUpdate,
                isOwner = isOwner,
            },
        })
    end
end)

RegisterNetEvent("glow_blackmarket_cl:orderReady", function(index, coords)
    orderLocation = coords
    local props = spawnContainer(orderLocation)
    local netIds = {}
    for k, v in pairs(props) do
        netIds[k] = NetworkGetNetworkIdFromEntity(v)
    end
    
    TriggerServerEvent("glow_blackmarket_sv:propsSpawned", netIds, index)

    if not displayingUI then
        QBCore.Functions.Notify(Config.notifText.orderReady, "success")
    else
        tabletNotification(Config.notifText.orderReady, "success")
    end

    SendNUIMessage({
        action = "orderReady",
    })

    if math.random() <= Config.policeNotifChance then
        Config.policeNotify(orderLocation)
    end
end)

RegisterNetEvent("glow_blackmarket_cl:addLockTarget", function(index, coords)
    local zoneName = "bm_lock_"..index
    
    for i=1, #targetZones do
        if targetZones[i] == zoneName then print("lock exists") return end
    end
    
    local min, max = GetModelDimensions(joaat(Config.props.lock))
    local lockDimensions = max - min
    exports["qb-target"]:AddBoxZone(zoneName, coords.xyz, lockDimensions.y, lockDimensions.x, {
        name = zoneName,
        heading = coords.w,
        debugPoly = false,
        minZ = coords.z -  lockDimensions.z/2,
        maxZ = coords.z + lockDimensions.z/2,
    }, {
        options = {
            {
                icon = "fa-solid fa-unlock",
                label = "Open",
                action = function()
                    TriggerServerEvent("glow_blackmarket_sv:attemptContainer", index)
                end
            }
        }, 
        distance = 2.0
    })
    targetZones[#targetZones + 1] = zoneName
end)


RegisterNetEvent("glow_blackmarket_cl:openContainer", function(index, propIds)
    doContainerAnim(index, propIds.container, propIds.lock, propIds.collision)
end)

RegisterNetEvent("glow_blackmarket_cl:updateOpenContainer", function(index, containerNetId, collisionNetId, crateCoords, removeLockTarget)
    local container = NetworkGetEntityFromNetworkId(containerNetId)
    local collision = NetworkGetEntityFromNetworkId(collisionNetId)
    SetEntityCollision(collision, true, true)
    SetEntityCompletelyDisableCollision(container, false, false)

    if removeLockTarget then
        exports['qb-target']:RemoveZone("bm_lock_"..index)
        for i=1, #targetZones do
            if targetZones[i] == "bm_lock_"..index then
                table.remove(targetZones, i)
                break
            end
        end
    end

    local zoneName = "bm_crate_"..index
    local min, max = GetModelDimensions(joaat(Config.props.crate))
    local crateDimensions = max - min
    exports["qb-target"]:AddBoxZone(zoneName, crateCoords.xyz, crateDimensions.y, crateDimensions.x, {
        name = zoneName,
        heading = crateCoords.w,
        debugPoly = false,
        minZ = crateCoords.z,
        maxZ = crateCoords.z + crateDimensions.z,
    }, {
        options = {
            {
                icon = "fa-solid fa-boxes-stacked",
                label = "Loot",
                action = function()
                    TriggerServerEvent("glow_blackmarket_sv:attemptLoot", index)
                end
            }
        }, 
        distance = 2.0
    })
    targetZones[#targetZones + 1] = zoneName
end)

RegisterNetEvent("glow_blackmarket_cl:removeLockTarget", function(index)
    print("removing lock target ", index)
    exports['qb-target']:RemoveZone("bm_lock_"..index)
    for i=1, #targetZones do
        if targetZones[i] == "bm_lock_"..index then
            table.remove(targetZones, i)
            break
        end
    end
end)

RegisterNetEvent("glow_blackmarket_cl:removeLootTarget", function(index)
    exports['qb-target']:RemoveZone("bm_crate_"..index)
    for i=1, #targetZones do
        if targetZones[i] == "bm_crate_"..index then
            table.remove(targetZones, i)
            break
        end
    end
end)

RegisterNetEvent("glow_blackmarket_cl:lootContainer", function(index)
    local ped = PlayerPedId()
    loadAnimDict(Config.lootAnim.dict)
    TaskPlayAnim(ped, Config.lootAnim.dict, Config.lootAnim.anim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
    QBCore.Functions.Progressbar("looting_crate", "Grabbing Items..", Config.lootTime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {}, {}, {}, function() -- Done
        TriggerServerEvent("glow_blackmarket_sv:finishLooting", index)
    end, function() -- Cancel
        TriggerServerEvent("glow_blackmarket_sv:cancelLooting", index)
        QBCore.Functions.Notify("Cancelled", "error")
    end)
end)

RegisterNetEvent("glow_blackmarket_cl:orderComplete", function()
    SendNUIMessage({
        action = "clearOrder"
    })
end)

RegisterNetEvent("glow_blackmarket_cl:hasPendingOrder", function(items, order, epochTime)
    SendNUIMessage({
        action = "loadPendingOrder",
        data = {
            marketItems = items,
            order = order,
            epochTime = epochTime,
        }
    })
end)

RegisterNetEvent("glow_blackmarket_cl:enableLocateButton", function(index)
    orderLocation = Config.deliveryLocations[index]
    SendNUIMessage({
        action = "orderReady",
    })
end)

RegisterNUICallback("getClientData", function(data, cb)
    currentMoney = PlayerData.money[Config.paymentType]
    if not marketItems then
        QBCore.Functions.TriggerCallback("glow_blackmarket_sv:getMarketItems", function(items)
            marketItems = items
            cb({ marketItems = marketItems, currencyAmt = currentMoney })
        end)
    else
        cb({ marketItems = marketItems, currencyAmt = currentMoney })
    end
end)

RegisterNUICallback("submitOrder", function(data, cb)
    QBCore.Functions.TriggerCallback("glow_blackmarket_sv:attemptOrder", function(result)
        cb(result)
        if result.notif then
            if result.success then
                tabletNotification(result.notif, "success")
            else
                tabletNotification(result.notif, "error")
            end
        end
        if result.error then
            printError(result.error)
        end
    end, (data))
end)

RegisterNUICallback("deliveryLocation", function(data, cb)
    if orderLocation then
        SetNewWaypoint(orderLocation.x, orderLocation.y)
        tabletNotification(Config.notifText.gpsSet, "success")
    end
    cb({})
end)

RegisterNUICallback("close", function(data, cb)
    displayUI(false)
    cb({})
end)

RegisterNUICallback("fetchConfig", function(data, cb)
    cb({
        configData = {
            inventory = Config.inventory,
            paymentType = Config.paymentType,
            acronym = Config.cryptoAcronym,
            cryptoIcon = Config.cryptoIcon,
            estDeliveryTime = tostring(math.floor((Config.deliveryTime.min + Config.deliveryTime.max)/2)),
            tabletColour = Config.tabletColour,
        },
        notifData = Config.notifs,
    })
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    if displayingUI then
        if PlayerData.money[Config.paymentType] ~= currentMoney then
            SendNUIMessage({
                action = "updateCash",
                data = PlayerData.money[Config.paymentType]
            })
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    TriggerServerEvent("glow_blackmarket_sv:initPendingOrders")
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = nil
    removeTargetZones()
    targetZones = {}
    SendNUIMessage({
        SendNUIMessage({
            action = "clearOrder"
        })
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i=1, #targetZones do
        exports['qb-target']:RemoveZone(targetZones[i])
    end
    targetZones = {}
end)