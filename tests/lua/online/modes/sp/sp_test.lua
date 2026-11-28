-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop sp (online/modes/sp/commands.lua): alone and with status it answers the status line; another word is refused
-- with the use line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Cmd=require('online.modes.sp.commands').new({})
local ok,line=Cmd.sp()
assert(ok and line=='online.modes.sp: nothing built yet',line)
ok,line=Cmd.sp('status')
assert(ok and line=='online.modes.sp: nothing built yet',line)
ok,line=Cmd.sp('nope')
assert(not ok and line=='Use: coop sp [status]',line)
print('sp_test ok')
