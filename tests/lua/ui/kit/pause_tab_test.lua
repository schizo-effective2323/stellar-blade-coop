-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The pause menu's Online tab (ui/kit/pause_tab.lua) over fakes. Covered: nothing before the game is ready; the class
-- loaded, the keeper made and the Construct hook registered once; a Construct adds one button after SB's 8 with the
-- word, SB's last button's style, RefreshDesign, Visible with its Button_Action HitTestInvisible; a button without
-- Button_Action stops the tab and leaves no half-made button; a second Construct adds none; a row rebuilt to SB's 8
-- gets it again at the next slow while paused. With no page: a click over the button (IsHovered; the cached geometry
-- is never read) closes the pause menu once through the native part's close (SB's own, never the widget's CloseSelf),
-- one elsewhere or with no pause menu does nothing; RB closes it, the co-op menu opens at the first tick after the
-- unpause, or after 2 s still paused a give-up line and notice; a close refused for now logs one line and waits for
-- nothing, one that can never work stops the tab with one STOP line and asks pausetab off; pause_tab off makes nothing
-- and asks pausetab off; the asks: once a change, a refused one again at the next slow and logged once; a pause menu of
-- another shape stops the tab with one STOP line and asks pausetab off; coop off stops it. With a page: RB and a
-- hovered click read the tab, build the page, enter, show it, focus our button and defocus SB's button of the tab
-- left, with the shown line and SB's pages now and 0.5 s later; a click logs its hover (no once a pause menu) and SB's
-- tab one frame later; the page hides when SB shows another tab or the menu closed; it forgets the master when that
-- is gone; Open the co-op menu closes then opens the co-op menu, back in the list closes only; the entry's locked and
-- none change nothing with one line each, off or a page that does not build take the path before the page; a page
-- that turns off while shown closes and opens the co-op menu; coop off hides it with SB's close.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local MASTER='/Game/Art/UI/Widget/GameMenu/WB_GameMenu_Master.WB_GameMenu_Master'
local MASTER_KEEPER=MASTER..'.StellarCoop_PauseTabKeeper'
local addresses=0
local function object(fields)
    fields=fields or {}
    addresses=addresses+8
    local address=addresses
    fields.type=function() return 'UObject' end
    fields.IsValid=function() return true end
    fields.GetAddress=function() return address end
    return fields
end
local missing=setmetatable({},{__index=function(_,k)
    if k=='type' then return function() return 'UObject' end end
    if k=='IsValid' then return function() return false end end
end})
local logs,hooks,objects,loaded,constructed
local hovered,ask_refusal
local function reset()
    logs,hooks,objects,loaded,constructed={},{},{},{},{}
    hovered,ask_refusal=false,nil
end
reset()
StaticFindObject=function(path) return objects[path] or missing end
LoadAsset=function(path)
    loaded[#loaded+1]=path
    objects[path..'_C']=object({GetOuter=function() return object() end})
end
StaticConstructObject=function(class,outer,name,flags,internal)
    constructed[#constructed+1]={class=class,outer=outer,name=name,flags=flags,internal=internal}
    objects[MASTER_KEEPER]=object()
    return objects[MASTER_KEEPER]
end
FName=function(s) return s end
FText=function(s) return s end
RegisterHook=function(path,f) hooks[#hooks+1]={path=path,f=f} end
local Tab=require('ui.kit.pause_tab')

-- SB's focus look on a tab button, counted.
local function looks(fields)
    fields.focus,fields.defocus=0,0
    fields.FocusTabButton=function(self) self.focus=self.focus+1 end
    fields.DefocusTabButton=function(self) self.defocus=self.defocus+1 end
    return fields
end
-- A pause menu whose tab row holds SB's 8 buttons, each with the five style fields; no_action: ours has no
-- Button_Action.
local function menu(no_tap_set,no_action)
    local buttons,class={},object()
    local function button(i)
        return object(looks({TextWidthValue=200+i,MinTextMargin=10+i,TextColor='color'..i,TextFont='font'..i,
            TextShadowColor='shadow'..i}))
    end
    for i=1,8 do buttons[i]=button(i) end
    local row=object({
        GetChildrenCount=function() return #buttons end,
        GetChildAt=function(_,i) return buttons[i+1] end,
        RemoveChild=function(_,c)
            for i,x in ipairs(buttons) do if x==c then table.remove(buttons,i); return true end end
        end,
    })
    local tabs=object({TabButtonClass=class,TabButtonContainer=row,
        CreateDynamicChildUserWidget=function(_,c,panel)
            assert(c==class and panel==row)
            local made=object(looks({refreshed=0,
                TextBlock=object({SetText=function(self,t) self.text=t end}),
                Button_Action=not no_action and object({SetVisibility=function(self,v) self.visibility=v end}) or nil,
                RefreshDesign=function(self) self.refreshed=self.refreshed+1 end,
                SetVisibility=function(self,v) self.visibility=v end,
                IsHovered=function() return hovered end,
                GetCachedGeometry=function() error('the cached geometry was read') end}))
            buttons[#buttons+1]=made
            return made
        end})
    -- CloseSelf counted: it skips SB's own close (its menu-close save, the shown tab's deactivate), so never called.
    local m=object({closes=0,CloseSelf=function(self) self.closes=self.closes+1 end})
    if not no_tap_set then m.WB_Tap_Set=object({WB_Common_Tabs=tabs}) end
    return m,buttons
end

local function new(page)
    -- closes: the native closes asked; answer: what the next ones return (closed by default). enters, tabs: the native
    -- entry's and tab read's calls; entry, now: what they answer.
    local s={opens=0,notices=0,asks={},paused=true,enabled=true,ready=true,closes=0,answer={true},enters=0,tabs=0,
        entry='entered',now=8}
    s.tab=Tab.new({log=function(line) logs[#logs+1]=line end,ready=function() return s.ready end,page=page,
        enter=page and function() s.enters=s.enters+1; return s.entry end or nil,
        tab=page and function() s.tabs=s.tabs+1; return s.now end or nil,
        enabled=function() return s.enabled end,word=function() return 'Online' end,
        paused=function() return s.paused end,open=function() s.opens=s.opens+1 end,
        notice=function() s.notices=s.notices+1 end,
        ask=function(line)
            s.asks[#s.asks+1]=line
            if ask_refusal then return false,ask_refusal end
            return true,'asked the native part: '..line
        end,
        close=function() s.closes=s.closes+1; return table.unpack(s.answer) end})
    return s
end
local function construct(m) for _,h in ipairs(hooks) do if h.path==MASTER..'_C:Construct' then h.f(m) end end end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end end

-- Not ready: no hook, no keeper, no load. Ready: the class loaded, one keeper, the Construct hook, once.
reset()
local s=new()
s.ready=false
s.tab.tick(0)
assert(#hooks==0 and #constructed==0 and #loaded==0,'Not ready: nothing')
s.ready=true
s.tab.tick(0); s.tab.tick(0)
assert(#loaded==1 and loaded[1]==MASTER and #constructed==1 and constructed[1].internal==0x40000000
    and constructed[1].name=='StellarCoop_PauseTabKeeper','The class loaded and kept once')
assert(#hooks==1 and hooks[1].path==MASTER..'_C:Construct' and #logs==1 and logs[1]:find('hook on',1,true),
    'One Construct hook')

-- A Construct: our button after SB's 8, with the word, SB's last button's style, refreshed and HitTestInvisible.
local m,buttons=menu()
construct(m)
local ours=buttons[9]
assert(#buttons==9 and ours.TextValue=='Online' and ours.TextBlock.text=='Online','Our button after SB\'s 8')
for _,k in ipairs({'TextWidthValue','MinTextMargin','TextColor','TextFont','TextShadowColor'}) do
    assert(ours[k]==buttons[8][k],'Style copied from SB\'s last button: '..k)
end
assert(ours.refreshed==1 and ours.visibility==0 and ours.Button_Action.visibility==3,
    'RefreshDesign once; ours Visible, its Button_Action HitTestInvisible')
construct(m)
assert(#buttons==9,'A second Construct of that pause menu adds none')
-- The asks: pausetab on at the first slow, none while nothing changes.
s.tab.slow(); s.tab.slow()
assert(#s.asks==1 and s.asks[1]=='pausetab on','Asked on once')
-- A row rebuilt to SB's 8 gets ours again as the 9th at the next slow while paused.
table.remove(buttons)
s.paused=false; s.tab.slow()
assert(#buttons==8,'Not paused: the row is left alone')
s.paused=true; s.tab.slow()
assert(#buttons==9 and buttons[9]~=ours and buttons[9].TextValue=='Online','Added again')

-- A click: over the button (IsHovered) closes the pause menu once; elsewhere nothing.
assert(s.tab.armed(),'Armed while a pause menu has our button')
s.tab.click(1); assert(s.closes==0,'A click elsewhere: nothing')
hovered=true
s.tab.click(1); s.tab.click(1.1)
assert(s.closes==1 and m.closes==0 and not s.tab.armed(),
    'A click over the button: closed once by SB\'s own close, then no pause menu')
s.tab.tick(1.5); assert(s.opens==0,'Still paused: not yet')
s.paused=false
s.tab.tick(1.6); s.tab.tick(1.7)
assert(s.opens==1,'The first tick after the unpause opens the co-op menu once')

-- RB on Settings: closed once; the co-op menu waits for the unpause; still paused 2 s on: the give-up.
s.paused=true
local m2=menu(); construct(m2)
s.tab.event(10); s.tab.event(10.1)
assert(s.closes==2 and m2.closes==0 and not logged('nothing opened'),'RB: closed once by SB\'s own close')
s.tab.tick(11); s.tab.tick(12.1); s.tab.tick(13)
assert(s.opens==1 and s.notices==1
    and logged("pause tab: the game stayed paused for 2 s; the pause menu is the player's"),
    'Still paused after 2 s: one line, one notice, no open')
-- With no pause menu seen: nothing closed, one line.
s.tab.event(20); assert(logged('nothing opened'))
-- A close refused for now (SB has no pause menu open): one line, no wait, the tab still works at the next pause menu.
s.answer={false,'the game has no pause menu open'}
local m7=menu(); construct(m7)
local before=#logs
s.tab.event(30); s.tab.tick(30.1); s.paused=false; s.tab.tick(30.2)
assert(s.closes==3 and #logs==before+1 and logs[#logs]=='pause tab: nothing closed: the game has no pause menu open'
    and s.opens==1 and s.notices==1,'Refused for now: one line, nothing opened')
s.paused=true; s.answer={true}
local m8=menu(); construct(m8)
s.tab.event(40); s.paused=false; s.tab.tick(40.1)
assert(s.closes==4 and s.opens==2,'The next pause menu closes and opens the co-op menu')
-- A close that can never work (no export in the native part, or it is off): one STOP line, pausetab off at the next
-- slow, no more buttons.
s.paused=true; s.answer={false,'the native part has no coop_pause_close (not exported)',true}
local m9,b9=menu(); construct(m9)
s.tab.event(50)
assert(logs[#logs]=='STOP: the native part has no coop_pause_close (not exported); the pause menu keeps its 8 tabs '
    ..'until the mod reloads' and not s.tab.armed(),logs[#logs])
s.tab.slow(); assert(s.asks[#s.asks]=='pausetab off','Stopped: off asked')
local m10,b10=menu(); construct(m10)
assert(#b9==9 and #b10==8 and m9.closes==0,'Stopped: no more buttons')

-- pause_tab off: no button, RB and a click do nothing, pausetab off asked at the next slow.
reset()
s=new(); s.tab.tick(0)
s.enabled=false
local m3,b3=menu(); construct(m3)
s.tab.event(1); hovered=true; s.tab.click(1)
assert(#b3==8 and s.closes==0 and m3.closes==0 and not s.tab.armed() and #logs==1,'Off: nothing')
s.tab.slow(); assert(s.asks[1]=='pausetab off','Off asked')
-- A refused ask: asked again at the next slow, logged once.
s.enabled=true; ask_refusal='coop-request.txt cannot be written'
s.tab.slow(); s.tab.slow()
assert(#s.asks==3 and s.asks[3]=='pausetab on' and #logs==2
    and logs[2]=='pause tab: pausetab on not asked: coop-request.txt cannot be written','Refused: again, one line')
ask_refusal=nil
s.tab.slow(); s.tab.slow(); assert(#s.asks==4,'Asked once more, then nothing')

-- A pause menu with no WB_Tap_Set: one STOP line, pausetab off at the next slow, RB does nothing.
reset()
s=new(); s.tab.tick(0); s.tab.slow()
local m4=menu(true); construct(m4); construct(m4)
assert(#logs==2 and logs[2]:find('^STOP: ') and logs[2]:find('the pause menu has no WB_Tap_Set; the pause menu keeps '
    ..'its 8 tabs until the mod reloads$'),logs[2])
s.tab.slow(); assert(s.asks[#s.asks]=='pausetab off','Failed: off asked')
s.tab.event(1); assert(s.closes==0 and m4.closes==0 and #logs==2,'Failed: RB does nothing')

-- coop off: no more buttons, not armed.
reset()
s=new(); s.tab.tick(0)
local m5,b5=menu(); construct(m5)
assert(s.tab.armed())
s.tab.stop()
assert(not s.tab.armed())
local m6,b6=menu(); construct(m6)
assert(#b5==9 and #b6==8,'Stopped: no more buttons')
-- The keep: the class wanted when the tab is made; while the keep has not settled the hook waits (hooked stays false:
-- no hook, no load); once settled it installs from the keep's class, with no lookup and no LoadAsset.
do
    local Keep=require('core.keep')
    local keep_fake=dofile('tests/lua/core/keep_fake.lua')
    reset()
    local function class(p)
        return object({GetOuter=function() return object() end,GetFullName=function() return 'Class '..p end})
    end
    objects[MASTER..'_C']=class(MASTER..'_C')
    local kf=keep_fake(function(p) return objects[p],true end)
    local s=new()
    assert(Keep.wanted(MASTER..'_C'))
    Keep.slow()
    for _=1,5 do s.tab.tick(0) end
    assert(#hooks==0 and #loaded==0,'The hook waits for the keep')
    kf.settle()
    local saved_find=StaticFindObject
    StaticFindObject=function(p) assert(not Keep.wanted(p),'A kept class looked up: '..p); return saved_find(p) end
    s.tab.tick(0)
    assert(#hooks==1 and #loaded==0,#hooks)
    StaticFindObject=saved_find
    Keep.reset()
end
-- A tab button without Button_Action: one STOP line, the half-made button removed.
reset()
s=new(); s.tab.tick(0)
local m11,b11=menu(false,true); construct(m11)
assert(#b11==8 and logs[#logs]:find('^STOP: ') and logs[#logs]:find('the tab button has no Button_Action; the pause '
    ..'menu keeps its 8 tabs until the mod reloads$'),logs[#logs])

-- With the page (a fake of ui/kit/online_page.lua's): what it was asked, in order.
local function fake_page()
    local p={calls={},on=false,off=false,built=true,answer=nil,clicked=nil,vis='WB_GameMenu_Setting=Hidden'}
    local function note(...) p.calls[#p.calls+1]=table.concat({...},' ') end
    p.page={build=function(m) note('build'); p.master=m; return p.built,not p.built and 'no canvas' or nil end,
        show=function(on) note('show',tostring(on)); if not p.off then p.on=on end end,
        shown=function() return p.on end,
        nav=function(word) note('nav',word); return p.answer end,
        click=function() note('click'); return p.clicked end,
        visibility=function() return p.vis end,
        forget=function() note('forget'); p.on=false end,
        off=function() return p.off end}
    return p
end
local function count(list,text) local n=0 for _,l in ipairs(list) do if l==text then n=n+1 end end return n end
-- RB on Settings: the tab read, the page built, the entry, the page shown; our button focused, SB's Settings button
-- defocused; the shown line and SB's pages now and 0.5 s later.
reset()
local p=fake_page()
s=new(p.page); s.tab.tick(0)
local m12,b12=menu(); construct(m12)
s.tab.event(10)
assert(s.tabs==1 and s.enters==1 and table.concat(p.calls,',')=='build,show true' and p.master==m12,
    table.concat(p.calls,','))
assert(b12[9].focus==1 and b12[8].defocus==1 and b12[7].defocus==0 and s.closes==0,'Ours focused, Settings defocused')
assert(s.tab.page_shown() and logged('online page shown (from tab 8, by RB)')
    and logs[#logs]=="online page: SB's pages after the deactivate: WB_GameMenu_Setting=Hidden",logs[#logs])
s.now=9
s.tab.tick(10.2); assert(not logged('0.5 s after'),'Not yet')
p.vis='WB_GameMenu_Setting=Collapsed'
s.tab.tick(10.6); s.tab.tick(10.7)
assert(count(logs,"online page: SB's pages 0.5 s after the deactivate: WB_GameMenu_Setting=Collapsed")==1)
-- The keys: a move stays on the page; back in the list closes the pause menu only (no co-op menu).
s.tab.nav('down',10.8); assert(s.closes==0 and p.calls[#p.calls]=='nav down')
p.answer='close'; s.tab.nav('back',10.9)
assert(s.closes==1 and not s.tab.page_shown() and b12[9].defocus==1,'Back in the list: SB\'s close, the page hidden')
s.paused=false; s.tab.tick(11); assert(s.opens==0,'No co-op menu after Back')
-- Open the co-op menu: SB's close, then the co-op menu once unpaused.
s.paused=true; p.answer=nil
local m13=menu(); construct(m13)
s.now=8; s.tab.event(20); s.now=9
p.answer='open_menu'; s.tab.nav('select',20.05)
assert(s.closes==2 and not s.tab.page_shown(),'Open the co-op menu: SB\'s close')
s.tab.tick(20.1); assert(s.opens==0,'Still paused: not yet')
s.paused=false; s.tab.tick(20.2); assert(s.opens==1,'Then the co-op menu')
-- A hovered click: the same entry by a click; SB's tab one frame later. Not hovered: one line a pause menu.
s.paused,p.answer,hovered=true,nil,false
local m14,b14=menu(); construct(m14)
s.now=3
s.tab.click(30); s.tab.click(30.1)
assert(count(logs,'click: Online tab hovered no')==1 and p.calls[#p.calls]=='show false','Not hovered: one line')
hovered=true
s.tab.click(30.2)
assert(logged('click: Online tab hovered yes') and logged('online page shown (from tab 3, by a click)')
    and b14[3].defocus==1 and b14[9].focus==1)
s.now=9
s.tab.tick(30.3)
assert(logged("click: one frame later SB's pause menu shows tab 9"),logs[#logs])
-- A click while the page shows is the page's: on Open the co-op menu SB's close, then the co-op menu.
p.clicked='open_menu'; s.tab.click(30.4)
assert(p.calls[#p.calls-1]=='click' and s.closes==3 and not s.tab.page_shown())
p.clicked,s.paused=nil,false
s.tab.tick(30.5); assert(s.opens==2,'Then the co-op menu')
s.paused=true
-- SB leaves tab 9 by itself: another tab, a close, the menu gone.
local m15,b15=menu(); construct(m15)
s.now=8; s.tab.event(40)
s.now=1; s.tab.tick(40.1)
assert(not s.tab.page_shown() and logs[#logs]=='online page hidden: SB shows tab 1' and b15[9].defocus==1)
s.now=8; s.tab.event(41); s.now='none'; s.tab.tick(41.1)
assert(logs[#logs]=='online page hidden: the pause menu closed')
s.now=8; s.tab.event(42); s.now=9
m15.IsValid=function() return false end
s.tab.tick(42.1)
assert(logs[#logs]=='online page hidden: the pause menu is gone' and p.calls[#p.calls]=='forget')
assert(s.closes==3,'SB closed it by itself: no close of ours')
-- The entry's answers: locked and none change nothing, one line each; off takes the path before the page.
local m16=menu(); construct(m16)
local calls=#p.calls
s.now=8; s.entry='locked'; s.tab.event(50)
assert(logs[#logs]=="online page: SB's tab lock is on; nothing changed" and not s.tab.page_shown())
s.entry='none'; s.tab.event(51)
assert(logs[#logs]=='online page: the game has no pause menu open' and not s.tab.page_shown() and s.closes==3)
assert(table.concat(p.calls,',',calls+1)=='build,build','Built, never shown')
s.entry='off'; s.tab.event(52)
assert(logged('online page: not entered (off)') and s.closes==4)
s.paused=false; s.tab.tick(52.1); assert(s.opens==3,'The path before the page: the co-op menu')
-- A page that does not build: the path before the page.
s.paused,s.entry,p.built=true,'entered',false
local m17=menu(); construct(m17)
s.tab.event(60); assert(s.closes==5 and not s.tab.page_shown())
p.built=true
-- A page that turns off while shown: SB's close, the co-op menu, one line.
local m18,b18=menu(); construct(m18)
s.tab.event(70); s.now=9
p.off=true; p.on=false
s.tab.nav('down',70.1)
assert(logged('online page: off while shown; the pause menu closes and the co-op menu opens as before')
    and s.closes==6 and b18[9].defocus==1)
p.off=false
-- coop off with the page shown: hidden, SB's close once, one line; no more buttons.
local m19=menu(); construct(m19)
s.tab.event(80)
s.tab.stop()
assert(not s.tab.page_shown() and s.closes==7 and logged('online page hidden: coop off') and not s.tab.armed())
print('pause_tab_test ok')
