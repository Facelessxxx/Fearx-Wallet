fx_version 'cerulean'
game 'gta5'

name 'fearx_wallet'
author 'fearx'
description 'Wallet resource for ox_inventory'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'ox_inventory',
    'ox_lib'
}