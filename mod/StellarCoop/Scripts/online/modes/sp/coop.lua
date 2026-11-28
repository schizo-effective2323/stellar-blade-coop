-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Survival Protocol's online-session bridge on SBO's Steam Link (online/modes/sp/).
-- From Survival Protocol coop.lua v4 on schizo-effective-mods sp-coop-phase1 tip 873b240, under the SBO License by
-- SchizoEffective's approval on 2026-11-27. Transport is M.link (mode line word sp), not spnet.dll.
--
-- Host line:  h sp <ver> <n> <state> <run> <diff> <omega> <boss1> <boss2> <wave> <mk> <mtype> <malias>
-- Guest line: g sp <ver> <n> <state> <run> <diff> <wave> <why>
--   state (host)  idle | ask | arena | run | end
--   state (guest) idle | menu | loading | arena | run | end | refuse
--   why    '-' or a refusal: ver | diff | busy | locked
-- Unreliable pe / puppet position streams are dropped: online.partner ghosts carry the partner EVE.
-- Everything game-facing is passed in (env / link), so tests run with plain Lua.
local C={}
C.VERSION='016'
C.TICK_MS=250
C.HEARTBEAT_S=2.0
C.STALE_S=8.0
C.MODE_WORD='sp'

local HOST_STATES={idle=true,ask=true,arena=true,run=true,['end']=true}
local GUEST_STATES={idle=true,menu=true,loading=true,arena=true,run=true,['end']=true,refuse=true}
local WHY={['-']=true,ver=true,diff=true,busy=true,locked=true}

local function words(text)
    local t={}
    for w in tostring(text or ''):gmatch('%S+') do t[#t+1]=w end
    return t
end
local function int(s,lo,hi)
    local n=tonumber(s)
    if not n or n~=math.floor(n) or n<lo or n>hi then return nil end
    return n
end
local function tok(s)
    return (s and s~='' and tostring(s):lower():gsub('[^0-9a-z/_:%-]','') ) or '-'
end
C.tok=function(s) local t=tok(s); return t~='' and t or '-' end

-- Printable ASCII for the mode line (link refuses non-printable). Same shape as the old night_ok check.
function C.lineOk(line)
    if type(line)~='string' or #line<3 or #line>300 then return false end
    if not line:match('^[hg] ') or line:sub(-1)==' ' or line:find('  ',1,true) then return false end
    return line:sub(3):match('^[0-9a-z/_: %-]+$')~=nil
end

function C.encodeHost(h)
    local line=table.concat({'h','sp',C.VERSION,tostring(h.n or 0),h.state or 'idle',tostring(h.run or 0),
        tostring(h.diff or 0),h.omega and '1' or '0',C.tok(h.boss1),C.tok(h.boss2),tostring(h.wave or 0),
        tostring(h.mk or 0),tostring(h.mtype or 0),C.tok(h.malias)},' ')
    return C.lineOk(line) and line or nil
end
function C.encodeGuest(g)
    local line=table.concat({'g','sp',C.VERSION,tostring(g.n or 0),g.state or 'idle',tostring(g.run or 0),
        tostring(g.diff or 0),tostring(g.wave or 0),WHY[g.why or '-'] and (g.why or '-') or '-'},' ')
    return C.lineOk(line) and line or nil
end
-- nil when the text is not an sp line; { bad = 'ver', ver = ... } when the version differs.
function C.decode(text)
    local f=words(text)
    if f[2]~='sp' or (f[1]~='h' and f[1]~='g') then return nil end
    if f[3]~=C.VERSION then return {bad='ver',ver=f[3],role=f[1]} end
    if f[1]=='h' then
        if #f~=14 or not HOST_STATES[f[5]] then return nil end
        local h={role='h',ver=f[3],n=int(f[4],0,1e9),state=f[5],run=int(f[6],0,255),diff=int(f[7],0,5),
            omega=f[8]=='1',boss1=f[9]~='-' and f[9] or nil,boss2=f[10]~='-' and f[10] or nil,
            wave=int(f[11],0,99),mk=int(f[12],0,1e6),mtype=int(f[13],0,255),malias=f[14]~='-' and f[14] or nil}
        if not (h.n and h.run and h.diff and h.wave and h.mk and h.mtype) then return nil end
        return h
    end
    if #f~=9 or not GUEST_STATES[f[5]] or not WHY[f[9]] then return nil end
    local g={role='g',ver=f[3],n=int(f[4],0,1e9),state=f[5],run=int(f[6],0,255),diff=int(f[7],0,5),
        wave=int(f[8],0,99),why=f[9]}
    if not (g.n and g.run and g.diff and g.wave) then return nil end
    return g
end

-- Status from core/link.lua: mode(), friend(), loopback(), notices(), list rows as games.
function C.fromLink(link)
    local s={online=link~=nil}
    if not link then return s end
    local mode=link.mode()
    s.steam=mode~=nil and 'ready' or 'off'
    s.mode=(mode=='host' or mode=='guest') and mode or 'none'
    s.role=s.mode
    local name,linked=link.friend()
    s.linked=linked==true or (link.loopback and link.loopback()==true) or false
    if link.loopback and link.loopback() then s.loopback=true end
    s.friend=name
    local listed=link.notices and link.notices() or {}
    if #listed>0 then
        local last=listed[#listed]
        s.noticeN,s.noticeText=last.n or last[1],last.text or last[2]
    end
    s.ingame,s.friendsOnline,s.games={},{},{}
    s.search='idle'
    if link.list then
        local search,found=link.list()
        if search then s.search=search.state or 'idle' end
        for _,row in ipairs(found or {}) do
            s.games[#s.games+1]={lobby=row.lobby,host=row.name,members=nil,max=nil,mode='public',
                diff=nil,state=nil}
        end
    end
    return s
end

-- o: link (core/link.lua's, or a fake), clock(), log().
function C.new(o)
    local self={link=o.link,clock=o.clock or os.clock,log=o.log or function() end,status={online=false},
        n=0,lastLine=nil,lastSentAt=-100,run=0,state='idle',gstate='idle',heard=nil,partner=nil,
        mk=0,mtype=0,malias=nil,applied=0,notices={},follower=false,line=nil}
    local link=self.link

    function self.poll()
        local was=self.status
        if link and link.changes then link.changes() end
        for _,m in ipairs(link and link.take_mode and link.take_mode(C.MODE_WORD) or {}) do
            local text=m.text or m
            if type(text)=='string' and (text:sub(1,5)=='h sp ' or text:sub(1,5)=='g sp ') then
                self.line=text
            elseif self.onMessage then
                pcall(self.onMessage,{reliable=true,text=text,from=m.from})
            end
        end
        self.status=C.fromLink(link)
        local s=self.status
        if not s.linked then self.line=nil end
        s.night=self.line
        if s.mode~=was.mode or s.linked~=was.linked then
            self.log(string.format('SP link: %s%s%s',s.mode or 'none',s.linked and ' linked' or '',
                s.friend and (' with '..s.friend) or ''))
            if not s.linked then self.partner,self.heard=nil,nil end
        end
        if s.linked and s.night~=self.heard then
            self.heard=s.night
            local p=C.decode(s.night)
            if p and p.bad then
                if not (self.partner and self.partner.bad) then
                    self.log('SP partner runs Survival Protocol '..tostring(p.ver)..', we run '..C.VERSION)
                end
                self.partner=p
            elseif p and ((s.mode=='host' and p.role=='g') or (s.mode=='guest' and p.role=='h')) then
                if not self.partner or self.partner.state~=p.state or self.partner.run~=p.run or self.partner.mk~=p.mk then
                    self.log('SP in: '..tostring(s.night))
                end
                self.partner=p
                self.partnerAt=self.clock()
            end
        end
        return s
    end
    function self.hosting()
        local t={}
        for _,f in ipairs(self.status.ingame or {}) do if f.lobby then t[#t+1]=f end end
        return t
    end
    function self.joinTarget()
        local h=self.hosting()
        if #h==0 then return nil end
        self.pick=((self.pick or 1)-1)%#h+1
        return h[self.pick],#h
    end
    function self.inviteList(max)
        local st=self.status
        if not st.friendsOnline then return nil end
        local t={}
        for _,f in ipairs(st.ingame or {}) do
            if #t>=(max or 9) then break end
            t[#t+1]={id=f.id,name=f.name,tag=f.lobby and 'IN A CO-OP GAME' or 'IN STELLAR BLADE',lit=not f.lobby}
        end
        for _,f in ipairs(st.friendsOnline) do
            if #t>=(max or 9) then break end
            t[#t+1]={id=f.id,name=f.name,tag='ONLINE',lit=false}
        end
        return t,#(st.ingame or {})+#st.friendsOnline
    end
    function self.role() local m=self.status.mode; return (m=='host' or m=='guest') and m or nil end
    function self.linked() return self.status.linked==true end
    function self.friend() return self.status.friend or 'your friend' end
    -- Maps to Link requests. 'host' alone means friends. 'find' opens the public session list.
    function self.request(word)
        if not link then return false,'Survival Protocol needs the Steam link' end
        if self.status.steam~='ready' and word~='loopback on' and word~='loopback off' then
            return false,'Steam is not ready yet'
        end
        -- Online sessions for Survival Protocol hold 2 players (the host included).
        if word=='host' then word='host friends 2'
        elseif word=='host public' then word='host public 2'
        elseif word=='host invitation' then word='host invitation 2'
        elseif word=='host closed' then word='host closed 2'
        elseif word=='find' then word='list public'
        elseif word=='loopback on' then word='loopback'
        elseif word=='loopback off' then word='leave' end
        local ok,why=link.request(word)
        if ok==false then return false,why or 'link refused' end
        self.log('SP request '..word)
        return true
    end
    function self.send(line,force)
        if not line or not self.linked() or not link then return false end
        local now=self.clock()
        if line==self.lastLine and not force and now-self.lastSentAt<C.HEARTBEAT_S then return true end
        local ok=link.mode_line(C.MODE_WORD,line)
        if ok==false then return false end
        if line~=self.lastLine then self.log('SP out: '..line) end
        self.lastLine,self.lastSentAt=line,now
        return true
    end
    -- Dropped: SBO ghosts replace the pe stream. Kept so older callers do not raise.
    function self.sendFast()
        return false
    end
    -- Lobby browser keys need a shared Link change. No-op until MotherSphere allows one.
    function self.lobbyData() end
    function self.mark(zeType,alias)
        if self.role()~='host' or self.state=='idle' then return end
        self.mk,self.mtype,self.malias=self.mk+1,zeType or 0,C.tok(alias)
    end
    function self.status_line()
        local s=self.status
        return string.format('sp: %s%s%s ver %s',s.mode or 'none',s.linked and ' linked' or '',
            s.friend and (' with '..s.friend) or '',C.VERSION)
    end
    return self
end

-- One step of the bridge (every TICK_MS). env fields match Survival Protocol's coop.step.
function C.step(self,env)
    local s=self.poll()
    local role=self.role()
    local p=self.partner
    local function say(key,big,small)
        if self.notices[key] then return end
        self.notices[key]=true
        self.log('SP notice: '..big..(small and (' | '..small) or ''))
        if env.notice then env.notice(big,small) end
    end
    local function forget(prefix)
        for k in pairs(self.notices) do if k:sub(1,#prefix)==prefix then self.notices[k]=nil end end
    end
    if not role or not self.linked() then
        if self.follower then self.follower=false; self.log('SP follower mode off (no link)') end
        if self.state~='idle' or self.gstate~='idle' then self.state,self.gstate='idle','idle'; forget('') end
        return
    end
    if p and p.bad=='ver' then
        say('ver','CO-OP: VERSION MISMATCH',
            string.format('You run Survival Protocol %s, %s runs %s',C.VERSION,self.friend(),tostring(p.ver)))
    end
    local ok=p and not p.bad
    local inRun=env.inRun and env.inRun()
    if role=='host' then
        local over=env.over and env.over()
        if inRun then
            if self.state=='idle' then
                self.run=self.run%255+1; self.state='ask'; self.mk,self.mtype,self.malias=0,0,nil
                forget('r')
                self.log(string.format('SP host run %d: difficulty %s%s',self.run,tostring(env.runDiff and env.runDiff()),
                    env.omega and env.omega() and ' (Omega)' or ''))
            end
            if over then self.state='end'
            elseif env.arena and env.arena() then self.state=((env.wave and env.wave() or 0)>=1) and 'run' or 'arena' end
        else
            if self.state~='idle' then self.state='idle'; forget('r') end
        end
        local k1,k2=nil,nil
        if env.bossKeys then k1,k2=env.bossKeys() end
        self.send(C.encodeHost({n=self.n,state=self.state,run=self.state~='idle' and self.run or 0,
            diff=inRun and env.runDiff and env.runDiff() or 0,omega=inRun and env.omega and env.omega() or false,
            boss1=k1,boss2=k2,wave=env.wave and env.wave() or 0,mk=self.mk,mtype=self.mtype,malias=self.malias}))
        local mine=self.state~='idle' and ok and p.run==self.run and p or nil
        if mine and mine.state=='refuse' then
            say('r'..self.run..'refuse','CO-OP',string.format("%s can't join this run (%s)",self.friend(),mine.why))
        elseif mine and (mine.state=='arena' or mine.state=='run') then
            say('r'..self.run..'ready','PARTNER READY',self.friend()..' is in the arena')
        elseif mine and mine.state=='end' then
            say('r'..self.run..'end','CO-OP',self.friend()..' is out of the run')
        elseif self.state=='arena' or self.state=='run' then
            say('r'..self.run..'wait','WAITING FOR PARTNER',self.friend()..' is still on the way')
        end
        return
    end
    local hostRun=ok and p.role=='h' and p.state~='idle' and p.run>0 and p or nil
    local why='-'
    if hostRun and self.run~=hostRun.run then
        self.run=hostRun.run; forget('r'); self.applied=0; self.bossSet=nil
        self.log(string.format('SP host started run %d on difficulty %d%s',hostRun.run,hostRun.diff,
            hostRun.omega and ' (Omega)' or ''))
    end
    if hostRun and hostRun.boss1 and hostRun.boss2 and self.bossSet~=hostRun.boss1..'/'..hostRun.boss2 and env.setBosses then
        if env.setBosses(hostRun.boss1,hostRun.boss2) then self.bossSet=hostRun.boss1..'/'..hostRun.boss2 end
    end
    if inRun then
        local d,om=env.runDiff and env.runDiff(),env.omega and env.omega() or false
        if hostRun and (d~=hostRun.diff or om~=hostRun.omega) then
            self.gstate,why='refuse','diff'
            say('r'..self.run..'diff','CO-OP','You started another difficulty than the host - this run is solo')
        elseif env.over and env.over() then self.gstate='end'
        elseif env.arena and env.arena() then self.gstate=((env.wave and env.wave() or 0)>=1) and 'run' or 'arena'
        else self.gstate='loading' end
    elseif hostRun and env.canPlay and not env.canPlay(hostRun.diff,hostRun.omega) then
        self.gstate,why='refuse','locked'
        say('r'..self.run..'locked','CO-OP',
            'The host\'s difficulty is still locked for you - finish the one before it first')
    elseif hostRun and env.inMenu and env.inMenu() then
        self.gstate='menu'
        if not self.notices['r'..self.run..'row'] and env.selectRow then env.selectRow(hostRun.diff,hostRun.omega) end
        say('r'..self.run..'row','CO-OP RUN STARTED',string.format('%s is starting - press Start to join',self.friend()))
    elseif hostRun then
        self.gstate='idle'
        say('r'..self.run..'menu','CO-OP RUN STARTED',
            string.format('%s is starting - open Survival Protocol and press Start',self.friend()))
    else
        self.gstate='idle'
    end
    local follow=env.followOn and env.followOn() and hostRun and inRun and self.gstate~='refuse' and self.gstate~='end'
        and hostRun.state~='end' or false
    if follow~=self.follower then self.follower=follow; self.log('SP follower mode '..(follow and 'ON' or 'off')) end
    if self.follower and hostRun.mk>self.applied and hostRun.malias and env.runPhase then
        self.log(string.format('SP follow: host phase event #%d %s (type %d)',hostRun.mk,hostRun.malias,hostRun.mtype))
        env.runPhase(hostRun.mtype,hostRun.malias)
        self.applied=hostRun.mk
    end
    if inRun and hostRun and (self.gstate=='arena' or self.gstate=='run') then
        if hostRun.state=='arena' or hostRun.state=='run' then
            say('r'..self.run..'ready','PARTNER READY',self.friend()..' is in the arena')
        elseif hostRun.state=='end' then
            say('r'..self.run..'end','CO-OP',self.friend()..' is out of the run')
        else
            say('r'..self.run..'wait','WAITING FOR PARTNER',self.friend()..' is still on the way')
        end
    end
    self.send(C.encodeGuest({n=self.n,state=self.gstate,run=hostRun and self.run or 0,
        diff=inRun and env.runDiff and env.runDiff() or 0,wave=env.wave and env.wave() or 0,why=why}))
end

return C
