-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Survival Protocol (online/modes/sp/): the Link bridge (coop.lua) on mode line word sp. No spnet.dll.
-- Ghosts, revive and shared enemies stay in online.partner / online.group / fight.enemies; this module reads them later
-- through uses once the run loop lands. A main/pass.lua tick for M.sp.tick needs MotherSphere's OK (shared piece).
return {
uses={},
exports={'sp'},
new=function(M)
local print=M.print
local log=function(m) print('[StellarCoop][SP] '..tostring(m)..'\n') end
M.sp=require('online.modes.sp.coop').new({
    link=M.link,
    log=log,
    clock=os.clock,
})
return require('online.modes.sp.commands').new({sp=M.sp})
end,
}
