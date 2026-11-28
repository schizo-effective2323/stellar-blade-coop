-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/modes/sp/commands.lua over coop.lua: coop sp status and host words; a bad word is the usage line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local reqs={}
local link={
    mode=function() return 'none' end,
    friend=function() end,
    loopback=function() return false end,
    notices=function() return {} end,
    changes=function() end,
    take_mode=function() return {} end,
    mode_line=function() return true end,
    request=function(word) reqs[#reqs+1]=word; return true end,
}
local sp=require('online.modes.sp.coop').new({link=link,log=function() end,clock=function() return 0 end})
local Cmd=require('online.modes.sp.commands').new({sp=sp})
local ok,said=Cmd.sp()
assert(ok and said:find('sp: none') and said:find('ver 016'),said)
ok,said=Cmd.sp('status')
assert(ok and said:find('sp: none'),said)
ok,said=Cmd.sp('host')
assert(ok and said:find('Survival Protocol: host %(2 players%)') and reqs[#reqs]=='host friends 2',said)
ok,said=Cmd.sp('host','public')
assert(ok and said:find('host public %(2 players%)') and reqs[#reqs]=='host public 2',said)
ok,said=Cmd.sp('join')
assert(ok and reqs[#reqs]=='join',said)
ok,said=Cmd.sp('stop')
assert(not ok and said:find('Use: coop sp'),said)
print('sp_test ok')
