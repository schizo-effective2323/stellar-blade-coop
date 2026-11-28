-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop sp: status, host, join, leave, invite. online/modes/sp/wiring.lua builds it with new(o) at each Lua load.
-- o: sp (online/modes/sp/coop.lua's).
local Commands={}
local USE='Use: coop sp [status|host [public|friends]|join|leave|invite]'
function Commands.new(o)
    local self={}
    function self.sp(sub,extra,more)
        if more~=nil then return false,USE end
        if sub==nil or sub=='status' then
            if extra~=nil then return false,USE end
            o.sp.poll()
            return true,o.sp.status_line()
        end
        if sub=='host' then
            local word=extra=='public' and 'host public' or (extra==nil or extra=='friends') and 'host' or nil
            if not word then return false,USE end
            local ok,why=o.sp.request(word)
            if not ok then return false,why end
            return true,'Survival Protocol: '..word
        end
        if sub=='join' or sub=='leave' or sub=='invite' then
            if extra~=nil then return false,USE end
            local ok,why=o.sp.request(sub)
            if not ok then return false,why end
            return true,'Survival Protocol: '..sub
        end
        return false,USE
    end
    return self
end
return Commands
