fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Snowy Trailer'
description 'Towing stuff.'
author 'Snowylol'
version '0.0.1'

shared_scripts {
    '@ox_lib/init.lua'
}

client_scripts {
    'client/statebags.lua',
    'client/main.lua',
    'configs/client.lua'
}

dependencies {
    'ox_lib',
    'ox_target'
}