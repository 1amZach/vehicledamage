fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vehicledamage'
description 'Realistic engine failure, limp mode and repairs, synced for everyone'
version '1.0.0'
author 'IamZach'
discord 'https://discord.gg/agn'
repository 'https://github.com/1amZach/vehicledamage'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/damage.lua',
    'client/repair.lua',
}

server_script 'server/main.lua'

dependency 'ox_lib'
