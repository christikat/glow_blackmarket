<h1 align="center">Black Market Delivery Script for FiveM QBCore</h1>

## Description
A black market UI created in React for FiveM QBCore Framework. This script allows players view items on the market, add them to their cart, and place orders. The ordered items will then be delivered to a random location in the Config where players can pick it up.

<div align="center">
    <img width="700" src="https://i.imgur.com/7oGasqB.png" alt="Black Market UI" />
</div>

## Key Features
- Items on the black market are synced across all players. Stock decreases as orders are made
- Ability to have the market restock at set intervals
- Spawned in shipping containers when order is ready
- Synchronised scene animation to open the shipping container
- Looting the container creates a stash containing ordered item
- All player able to access the loot, allowing others to steal it
- Built in tablet notification system
- Ability to search to filter and quickly find items
- Chance to notify police when order is ready

## Installation
- Download latest release at https://github.com/christikat/glow_blackmarket/releases
- Open the ZIP and move `glow-blackmarket` into your resource folder and `ensure glow-blackmarket` in server.cfg
- This script uses the server sided export `OpenInventory`. If you are using a version of `qb-inventory` from before Dec 2022, you'll need to update
- Add a useable item that will trigger opening the UI, by default the script uses an item called "encryptedtablet" 
```lua
	['encryptedtablet'] 			 = {['name'] = 'encryptedtablet', 				['label'] = 'Encrypted Tablet', 		['weight'] = 2000, 		['type'] = 'item', 		['image'] = 'tablet.png', 				['unique'] = false, 	['useable'] = true, 	['shouldClose'] = true,	   ['combinable'] = nil,   ['description'] = 'A secured tablet'},
```

## Important Config Settings
- Make sure to update `Config.inventory` with the name of your inventory script
- If enabling police notify, edit `Config.policeNotify` with your police alert function. The default QBCore police notify will not work, since it pings the players location instead of the coords of the the container

## Adding items 
- Follow the format of the existing items in Config.items to add new items
- If you have items that require metadata, find the event `glow_blackmarket_sv:finishLooting` and create an if statement checking the item name and adding the metadata into the variable `itemInfo.info`


### Limitation
In order for the synchronised scene to work, the shipping container's collision must be removed and a new collision object is spawned in. This allows players to walk into the container. In testing, I found when removing the collision of an entity created by the server, the client crashes. This means the container must be spawned client sided.

Spawning the container through the client can cause it to de-spawn when the player logs off and no other players are nearby. To mitigate this issue, I have implemented a server-sided check that recreates de-spawned objects when the player logs back in. However, if the container has been opened prior to de-spawning, the recreated container is set back to the closed state.

Although this scenario is unlikely, it is worth noting. If this is a recurring issue for your server, I recommend not using the synchronised scene and moving object spawning to the server.