fx_version 'cerulean'
game 'gta5'
author 'Glowie'
description 'Blackmarket Deliveries'
version '1.0'

shared_script "config.lua"

client_scripts {
  "@PolyZone/client.lua",
  "client/**/*",
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
  "server/**/*",
}

ui_page 'web/build/index.html'

files {
  'web/build/index.html',
	'web/build/**/*',
}

lua54 'yes'