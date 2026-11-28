-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/modes/sp/coop.lua over a fake Link: encode/decode, host/guest run sync, mode line sp, no spnet.dll.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local C=require('online.modes.sp.coop')

local function has(list,text)
    for _,v in ipairs(list) do if tostring(v):find(text,1,true) then return true end end
end

-- encode / decode
local h=C.encodeHost({n=1,state='ask',run=1,diff=3,omega=false,boss1='RoyalGuards',boss2=nil,wave=0,mk=0,mtype=0})
assert(h=='h sp '..C.VERSION..' 1 ask 1 3 0 royalguards - 0 0 0 -',h)
local d=C.decode(h)
assert(d and d.role=='h' and d.state=='ask' and d.diff==3 and d.boss1=='royalguards' and not d.boss2)
local g=C.encodeGuest({n=2,state='menu',run=1,diff=0,wave=0,why='-'})
assert(g=='g sp '..C.VERSION..' 2 menu 1 0 0 -',g)
assert(C.decode(g).state=='menu')
assert(C.decode('h sp 999 1 idle 0 0 0 - - 0 0 0 -').bad=='ver')
assert(C.decode('h night 1')==nil)
assert(not C.lineOk('x sp 016'))
assert(not C.lineOk('h sp 016 1 idle 0 0 0 - - 0 0 0 - '))

-- two fake links that relay mode lines
local function fakeLink(role)
    local L={_mode=nil,_friend=nil,_linked=false,_loop=false,_reqs={},_out={},_inbox={},_notices={}}
    function L.mode() return L._mode end
    function L.friend() return L._friend,L._linked,false end
    function L.loopback() return L._loop end
    function L.notices() return L._notices end
    function L.changes() end
    function L.request(word)
        L._reqs[#L._reqs+1]=word
        return true
    end
    function L.mode_line(word,text)
        assert(word=='sp')
        L._out[#L._out+1]=text
        if L._linked and L.peer then
            L.peer._inbox[#L.peer._inbox+1]={from='1',text=text}
        end
        return true
    end
    function L.take_mode(word)
        assert(word=='sp')
        local t=L._inbox
        L._inbox={}
        return t
    end
    return L
end
local HA,HB=fakeLink(),fakeLink()
HA.peer,HB.peer=HB,HA
local function link(on)
    HA._mode,HB._mode=on and 'host' or 'none',on and 'guest' or 'none'
    HA._linked,HB._linked=on,on
    HA._friend,HB._friend=on and 'Guest' or nil,on and 'Host' or nil
end
local t=0
local logs={}
local function mk(L,tag)
    return C.new({link=L,clock=function() return t end,log=function(x) logs[#logs+1]=tag..' '..x end})
end
local H,G=mk(HA,'A'),mk(HB,'B')
local function lastSent(L)
    return L._out[#L._out]
end

local function game()
    return {menu=true,run=false,armed=nil,omega=false,arena=false,wave=0,over=false,bosses=nil,
        row=nil,notices={},phases={},set=nil,unlocked=6,follow=false}
end
local A,B=game(),game()
local function env(g)
    return {
        inMenu=function() return g.menu and not g.run end,inRun=function() return g.run end,
        arena=function() return g.arena end,runDiff=function() return g.armed end,omega=function() return g.omega end,
        bossKeys=function() if g.bosses then return g.bosses[1],g.bosses[2] end end,
        wave=function() return g.wave end,over=function() return g.over end,
        selectRow=function(d,om) g.row={d,om} end,
        setBosses=function(k1,k2) g.set={k1,k2}; return true end,
        canPlay=function(d) return d<=g.unlocked end,followOn=function() return g.follow end,
        runPhase=function(ty,alias) g.phases[#g.phases+1]=ty..':'..alias end,
        notice=function(big,small) g.notices[#g.notices+1]=big..' | '..(small or '') end,
    }
end
local EA,EB=env(A),env(B)
local function pass(n)
    for _=1,n or 1 do t=t+0.25; C.step(H,EA); C.step(G,EB) end
end

HA._mode,HB._mode='none','none'
H.poll(); G.poll()
assert(H.request('host public') and HA._reqs[#HA._reqs]=='host public')
assert(H.request('host') and HA._reqs[#HA._reqs]=='host friends')
assert(H.request('find') and HA._reqs[#HA._reqs]=='list public')
HA._mode=nil; H.poll()
local ok,why=H.request('find'); assert(not ok and why:find('Steam'))
HA._mode='none'; H.poll()
pass(2); assert(lastSent(HA)==nil and lastSent(HB)==nil)
link(true); pass(2)
assert(H.role()=='host' and G.role()=='guest' and H.linked() and G.friend()=='Host')
assert(lastSent(HA):match('^h sp '..C.VERSION..' %d+ idle 0 '),lastSent(HA))
assert(lastSent(HB):match('^g sp '..C.VERSION..' %d+ idle 0 '),lastSent(HB))
assert(H.sendFast()==false)

A.menu,A.run,A.armed=false,true,3
pass(2)
assert(lastSent(HA):find(' ask 1 3 0 '),lastSent(HA))
assert(B.row and B.row[1]==3 and B.row[2]==false)
assert(has(B.notices,'press Start to join'))
assert(lastSent(HB):find(' menu 1 '),lastSent(HB))
A.arena,A.bosses=true,{'RoyalGuards','Karakuri'}
pass(2)
assert(B.set and B.set[1]=='royalguards' and B.set[2]=='karakuri')
assert(has(A.notices,'WAITING FOR PARTNER'))
B.menu,B.run,B.armed=false,true,3
pass(1); assert(lastSent(HB):find(' loading 1 3 '),lastSent(HB))
B.arena=true; pass(2)
assert(has(A.notices,'PARTNER READY') and has(B.notices,'PARTNER READY'))
A.wave=1; H.mark(22,'RL3_Phase_001'); pass(2)
assert(lastSent(HA):find(' run 1 3 0 royalguards karakuri 1 1 22 rl3_phase_001$'),lastSent(HA))
assert(#B.phases==0 and not G.follower)
B.follow=true; pass(2)
assert(G.follower and #B.phases==1 and B.phases[1]=='22:rl3_phase_001',B.phases[1])
H.mark(22,'RL3_Phase_002'); pass(3)
assert(#B.phases==2 and B.phases[2]=='22:rl3_phase_002')
A.over=true; pass(2)
assert(lastSent(HA):find(' end 1 '),lastSent(HA))
assert(has(B.notices,'out of the run') and not G.follower)
A.run,A.over,A.arena,A.menu,A.wave=false,false,false,true,0
B.run,B.arena,B.menu,B.over,B.wave=false,false,true,false,0
pass(2); assert(lastSent(HA):find(' idle 0 '))
A.menu,A.run,A.armed,A.bosses=false,true,5,nil
pass(2); assert(lastSent(HA):find(' ask 2 5 0 '),lastSent(HA))
B.unlocked=4
pass(2); assert(lastSent(HB):find(' refuse 2 0 0 locked$'),lastSent(HB))
assert(has(A.notices,"can't join this run (locked)"))
B.unlocked=6; B.menu,B.run,B.armed=false,true,4
pass(2); assert(lastSent(HB):find(' refuse 2 4 0 diff$'),lastSent(HB))
link(false); local sentBefore=#HA._out
pass(2); assert(H.state=='idle' and not H.linked() and #HA._out==sentBefore)
link(true)
HA._inbox[#HA._inbox+1]={from='2',text='g sp 999 1 idle 0 0 0 -'}
t=t+10; C.step(H,EA)
assert(has(A.notices,'VERSION MISMATCH'))
local dead=C.new({link=nil})
dead.poll(); assert(not dead.status.online)
ok,why=dead.request('find'); assert(not ok and why:find('Steam link'))
print('sp_coop_test ok')
