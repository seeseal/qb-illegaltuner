fx_version 'cerulean'
game 'gta5'

author 'YourServer'
description 'QBCore Illegal Tuner Shop'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/stance.lua',
    'client/nitrous.lua',
    'client/neon.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'qb-core',
    'ox_lib',
    'oxmysql',
}
