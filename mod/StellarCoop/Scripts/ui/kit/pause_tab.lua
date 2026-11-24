-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The pause menu's Online tab and its page. SB's pause menu (WB_GameMenu_Master) has 8 tabs; this adds a 9th button
-- after them. SB's GameMenu logic maps tabs 1 to 8 to its own pages in code, so the Online page is SBO's own widget in
-- the master (ui/kit/online_page.lua). The button and its Button_Action take the mouse as SB's last button's do (their
-- visibilities copied): the class binds that Button's OnHovered and OnUnhovered to its Hover and UnHover animations
-- (WB_Common_Tab_Btn's ComponentDelegateBinding), so the hover look plays as on SB's tabs. SB binds each tab's click
-- once, at its GameMenu logic's init (FUN_141d90210, vtable 0x145c266f8 slot 7, calls FUN_141d929b0 -> FUN_141d7f2f0 ->
-- FUN_141d49a00 -> FUN_141d49700: action 3 Bind, event 1 OnClicked on Button_Action at the path
-- WB_Tap_Set/WB_Common_Tabs/<the tab's ESBUILogicType name>, split at '/' and resolved by name in FUN_142535310): ours
-- is made later under another name, so SB's click binding never reaches it. A left click (main/keys.lua's mouse bind)
-- asks the Button's IsHovered. RB on Settings reaches the tab through the native part (ui/pause_tab.h: RB on the
-- highest enabled tab and LB on the lowest become coop_pad's event 12; the keyboard's keys too, as SB maps them to the
-- same actions). Either one enters the page: the native part's coop_pause_enter runs the shown SB page's deactivate (as
-- SB's own tab change does), then writes 9 as the open tab. The page shows. Our button takes SB's focus look; SB's
-- button of the tab left loses it. While the page shows, the open tab is read each frame (coop_pause_page). SB's
-- previous and next (LB, RB, the arrows), a click on one of SB's tabs and SB's close (the pause key) leave tab 9 by
-- SB's own code: the page hides as soon as the tab is not 9. The native part keeps SB's Back from SB on tab 9, so
-- main/keys.lua and main/input.lua hand Esc, the pad's B and the navigation words to the page (nav). Back in its left
-- list runs SB's close (coop_pause_close, what SB's Back runs). Open the co-op menu runs SB's close, then the co-op
-- menu. The page hides at coop off (with SB's close) and when the master is gone. With no page (it did not load or
-- build, or an older DLL without the two exports) the tab does what it did before the page: SB's close, then the co-op
-- menu once the game is unpaused, as menu_key does; still paused after WAIT s, it gives up with one log line and one
-- notice. A page that turns off while shown hides, closes the pause menu and opens the co-op menu, with one line. A
-- close the native part cannot make at all stops the tab as an error does.
--
-- The button copies its text style from SB's last button. A container rebuilt without it gets it again from the 250 ms
-- loop while the game is paused. A rooted, never-shown master keeps the class in memory, so the hook stays on it. Every
-- engine call runs in pcall on the game thread; the first error stops the tab until the next Lua load with one STOP
-- line. The native part is then asked pausetab off, so RB on Settings wraps to Equipment as in the game. Only UI: no
-- save, trophy or inventory call of its own (SB's close saves only as it does on Back). Its [PT] lines answer what only
-- the game can tell: whether the Button and the button are hovered on a click (both answers each click, until a game
-- test shows the Button's holds), SB's tab one frame after that click, what SB's deactivate left shown (at the entry
-- and LOOK s later).
-- tests/lua/ui/kit/pause_tab_test.lua covers it over fakes.
local U=require('core.unreal')
local Keep=require('core.keep')
local Tab={WAIT=2,LOOK=0.5}
local MASTER='/Game/Art/UI/Widget/GameMenu/WB_GameMenu_Master.WB_GameMenu_Master'
local KEEPER=MASTER..'.StellarCoop_PauseTabKeeper'
local PUBLIC,ROOT_SET=0x1,0x40000000 -- As online/group/region_tabs.lua: RF_Public; EInternalObjectFlags::RootSet.
local STYLE={'TextWidthValue','MinTextMargin','TextColor','TextFont','TextShadowColor'}

-- A class by its asset's path: the keep's (core/keep.lua) when it serves it, else loaded when it is not in memory.
local function class_of(asset)
    if Keep.serves(asset..'_C') then return assert(Keep.get(asset..'_C'),asset..' is not in memory') end
    local class=U.valid(StaticFindObject(asset..'_C'))
    if class then return class end
    pcall(LoadAsset,asset)
    return assert(U.valid(StaticFindObject(asset..'_C')),asset..' is not in this game build')
end

-- o: {log=function(line), ready=function() the game is far enough to load the menu's class, enabled=function() the
-- pause_tab setting, word=function() the tab's word in the menu's language, paused=function() the game is paused,
-- open=function() the co-op menu as menu_key opens it, notice=function() the give-up notice on screen,
-- ask=function(line) the native ask: ok, why, close=function() SB's close of the pause menu through the native part:
-- true, or false and why with lasting true when no later close can work, page=ui/kit/online_page.lua's or nil,
-- enter=function() the native entry: 'entered', 'shown', 'none', 'locked', 'off', or nil and why, tab=function() the
-- open tab: 1 to 9, 'other', 'none', 'off', or nil and why}.
function Tab.new(o)
    local log,page=o.log,o.page
    local hooked,failed,stopped=false,false,false
    local master,button,closed_at=nil,nil,nil
    local asked,refused=nil,nil -- The last ask written (true: on); the last refusal logged.
    -- The page shown by us; when to log SB's pages again; a click to report at the next tick; a refused tab look said.
    local showing,look_at,clicked,look_said=false,nil,false,false
    local sound=o.sound or function() end -- The kit's sounds by name.
    local over,over_at=false,0 -- Whether the mouse was on our tab at the last look; when to look again.
    Keep.want({MASTER..'_C'})
    local function fail(e)
        failed=true
        log('STOP: '..tostring(e)..'; the pause menu keeps its 8 tabs until the mod reloads')
    end
    -- Ours after SB's buttons, unless it is already the last one. No half-made button stays.
    local function add()
        local tabs=assert(U.valid(master.WB_Tap_Set),'the pause menu has no WB_Tap_Set')
        tabs=assert(U.valid(tabs.WB_Common_Tabs),'WB_Tap_Set has no WB_Common_Tabs')
        local row=assert(U.valid(tabs.TabButtonContainer),'the tabs have no TabButtonContainer')
        local n=row:GetChildrenCount()
        assert(n>0,'the tab row is empty')
        local last=assert(U.valid(row:GetChildAt(n-1)),'the tab row has no last button')
        if button and U.address(last)==U.address(button) then return end
        local made=assert(U.valid(tabs:CreateDynamicChildUserWidget(tabs.TabButtonClass,row)),'no tab button')
        local ok,e=pcall(function()
            for _,k in ipairs(STYLE) do made[k]=last[k] end
            local word=o.word()
            made.TextValue=FText(word)
            assert(U.valid(made.TextBlock),'the tab button has no TextBlock'):SetText(FText(word))
            made:RefreshDesign()
            -- Ours takes the mouse as SB's buttons do: the button and its Button_Action as SB's last one has them.
            made:SetVisibility(last:GetVisibility())
            local sb=assert(U.valid(last.Button_Action),"SB's last tab button has no Button_Action")
            assert(U.valid(made.Button_Action),'the tab button has no Button_Action'):SetVisibility(sb:GetVisibility())
        end)
        if not ok then
            pcall(row.RemoveChild,row,made)
            error(e,0)
        end
        button=made
    end
    local function on_construct(ctx)
        if failed or stopped or not o.enabled() then return end
        local ok,e=pcall(function()
            local m=assert(U.valid(ctx),'Construct gave no pause menu')
            if showing and not (master and U.valid(master) and U.address(master)==U.address(m)) then
                showing=false
                page.forget()
                log('online page hidden: the pause menu was made again')
            end
            master=m
            add()
        end)
        if not ok then fail(e) end
    end
    local function install()
        local class=class_of(MASTER)
        if not U.valid(StaticFindObject(KEEPER)) then
            assert(U.valid(StaticConstructObject(class,class:GetOuter(),FName('StellarCoop_PauseTabKeeper',1),PUBLIC,
                ROOT_SET)),'no keeper')
        end
        RegisterHook(MASTER..'_C:Construct',on_construct)
        log('hook on: WB_GameMenu_Master_C:Construct')
    end
    -- SB's focus look on a tab button: FocusTabButton or DefocusTabButton; a refusal logged once a Lua load.
    local function tab_look(b,focus)
        local ok,why=pcall(function()
            b=assert(U.valid(b),'no tab button')
            if focus then b:FocusTabButton() else b:DefocusTabButton() end
        end)
        if not ok and not look_said then
            look_said=true
            log('online page: tab looks refused: '..U.why(why))
        end
    end
    -- SB's button of tab t (1 to 8): the row's button t - 1, only while the row holds that many before ours.
    local function sb_button(t)
        if type(t)~='number' or t<1 or t>8 then return nil end
        local ok,b=pcall(function()
            local row=master.WB_Tap_Set.WB_Common_Tabs.TabButtonContainer
            if t>row:GetChildrenCount()-1 then return nil end
            local x=U.valid(row:GetChildAt(t-1))
            if x and button and U.address(x)==U.address(button) then return nil end
            return x
        end)
        return ok and b or nil
    end
    -- The page hidden by us, our button's focus look off, with why in a line.
    local function hide(why)
        showing=false
        page.show(false)
        tab_look(button,false)
        if why then log('online page hidden: '..why) end
    end
    -- The pause menu closed through SB's own close (the page hidden first); then_menu: the co-op menu opens from tick
    -- once the game runs again.
    local function close(now,then_menu)
        if showing then hide() end
        local shown=U.valid(master)
        master=nil
        if not shown then return log('pause tab: the pause menu was gone; nothing closed') end
        local ok,why,lasting=o.close()
        if lasting then return fail(why) end
        if not ok then return log('pause tab: nothing closed: '..tostring(why)) end
        if then_menu then closed_at=now end
    end
    -- A page that turned off while shown: the pause menu closed and the co-op menu opened, as before the page.
    local function fault(now)
        log('online page: off while shown; the pause menu closes and the co-op menu opens as before')
        showing=false
        tab_look(button,false)
        close(now,true)
    end
    -- The page entered from SB's tab now (RB or a click: by), or the path before the page when it cannot be.
    local function enter(now,by)
        if not (page and not page.off() and o.enter and o.tab) then return close(now,true) end
        local from=o.tab()
        if not page.build(master) then return close(now,true) end -- The page logged why it is off.
        local answer,why=o.enter()
        if answer=='entered' or answer=='shown' and not page.shown() then
            page.show(true)
            if page.off() then return fault(now) end
            showing=true
            tab_look(button,true)
            local left=sb_button(from)
            if left then tab_look(left,false) end
            log('online page shown (from tab '..tostring(from)..', by '..by..')')
            sound('tab_top')
            log("online page: SB's pages after the deactivate: "..page.visibility())
            look_at=now+Tab.LOOK
        elseif answer=='locked' then log("online page: SB's tab lock is on; nothing changed")
        elseif answer=='none' then log('online page: the game has no pause menu open')
        elseif answer~='shown' then
            -- No promise here: with the native part off, the close below is refused too and the tab stops.
            log('online page: not entered ('..tostring(answer or why)..')')
            close(now,true)
        end
    end
    local self={}
    -- Whether a left click may be ours: a pause menu got our button. No engine call: the key thread reads it.
    function self.armed() return master~=nil and button~=nil and not failed and not stopped and o.enabled() end
    -- Whether the page shows (the keys and the pad go to nav then). No engine call: the key thread reads it.
    function self.page_shown() return page~=nil and page.shown() end
    -- Each frame: the hook once a Lua load, as soon as the game is far enough and the keep settled; the tab one frame
    -- after a click; while the page shows, the open tab, hidden when it is not 9 or the pause menu is gone, else the
    -- page's mouse look; then, after a close, the co-op menu once the game is unpaused, or the give-up after WAIT s.
    function self.tick(now)
        if not hooked and not stopped and o.ready() and (not Keep.wanted(MASTER..'_C') or Keep.ready()) then
            hooked=true
            local ok,e=pcall(install)
            if not ok then fail(e) end
        end
        -- The mouse onto our tab: a hover sound once as it arrives, since SB's own tabs sound under the mouse and ours
        -- plays none. A refused read is only no sound.
        -- shortcut: the kit's move cue (UI_Common_Hover_Cue); SB's own tab hover cue is native and not read yet.
        if not showing and now>=over_at and self.armed() and o.paused() then
            over_at=now+0.1
            local ok,on=pcall(function() return button.Button_Action:IsHovered()==true end)
            on=ok and on
            if on and not over then sound('move') end
            over=on
        end
        if clicked then
            clicked=false
            local t,why=o.tab()
            local now_tab=t=='none' and 'is closed' or 'shows tab '..tostring(t or why)
            log("click: one frame later SB's pause menu "..now_tab)
        end
        if showing then
            if page.off() then fault(now)
            elseif not U.valid(master) then
                showing,master=false,nil
                page.forget()
                log('online page hidden: the pause menu is gone')
            else
                local t,why=o.tab()
                if t~=9 then
                    hide(type(t)=='number' and 'SB shows tab '..t or t=='none' and 'the pause menu closed'
                        or 'the native part answers '..tostring(t or why))
                else
                    if look_at and now>=look_at then
                        look_at=nil
                        log("online page: SB's pages "..Tab.LOOK..' s after the deactivate: '..page.visibility())
                    end
                    page.tick(now) -- The item the mouse moved onto takes the focus look.
                    if page.off() then fault(now) end
                end
            end
        end
        if not closed_at then return end
        if not o.paused() then
            closed_at=nil
            return o.open()
        end
        if now-closed_at<Tab.WAIT then return end
        closed_at=nil
        log("pause tab: the game stayed paused for 2 s; the pause menu is the player's")
        o.notice()
    end
    -- Every 250 ms: the native part asked on or off whenever that changes (a refused ask again at the next pass, logged
    -- once), then ours back after SB's buttons if a rebuild dropped it while the game is paused.
    function self.slow()
        if stopped then return end
        local want=o.enabled() and not failed
        if want~=asked then
            local line=want and 'pausetab on' or 'pausetab off'
            local ok,why=o.ask(line)
            if ok then
                asked,refused=want,nil
            else
                local text='pause tab: '..line..' not asked: '..tostring(why)
                if text~=refused then refused=text; log(text) end
            end
        end
        if not (want and master and o.paused()) then return end
        local ok,e=pcall(function()
            master=U.valid(master)
            if master then add() end
        end)
        if not ok then fail(e) end
    end
    -- RB on Settings or LB on the first tab (coop_pad's event 12): the page entered. With the tab on, no button made
    -- (no Construct seen yet) and no close waiting, one line each time: the native part took the press.
    function self.event(now)
        if self.armed() then return enter(now,'LB or RB') end
        if not (failed or stopped or closed_at) and o.enabled() then
            log('pause tab: LB or RB at an end of the tab row with no Online tab shown; nothing opened')
        end
    end
    -- A left click while armed and paused: the page's while it shows (Open the co-op menu runs; the Online tab written
    -- off closes the pause menu), else the page entered when the mouse is over our Button_Action. Its IsHovered and the
    -- button's, logged each click.
    function self.click(now)
        if not self.armed() or not o.paused() then return end
        if showing then
            local action=page.click(now)
            if page.off() then return fault(now) end
            if action=='open_menu' then close(now,true) elseif action=='close' then close(now,false) end
            return
        end
        local ok,over=pcall(function()
            return assert(U.valid(button.Button_Action),'the tab button lost its Button_Action'):IsHovered()==true
        end)
        if not ok then return fail(over) end
        -- shortcut: both answers each click while unproven; the Button's alone once a game test shows it holds. The
        -- tab button's own answer is only for the log: a refusal there never stops the tab.
        local asked,widget=pcall(function() return button:IsHovered()==true end)
        local function yes(b) return b and 'yes' or 'no' end
        log('click: Online tab hovered: Button_Action '..yes(over)..', tab button '
            ..(asked and yes(widget) or 'refused'))
        if not over then return end
        clicked=o.tab~=nil
        enter(now,'a click')
    end
    -- A navigation word on the game thread while the page shows ('up', 'down', 'left', 'right', 'select', 'back'), at
    -- now: Open the co-op menu closes the pause menu and opens the co-op menu; back in the list and the Online tab
    -- written off on the page close the pause menu.
    function self.nav(word,now)
        if not showing then return end
        local action=page.nav(word,now)
        if page.off() then return fault(now) end
        if action=='open_menu' then close(now,true) elseif action=='close' then close(now,false) end
    end
    -- A key pressed (main/keys.lua's F-keys, keybind.text's name) while the page shows: true when one of its key rows
    -- waited for it. A page that turned off doing it takes the fault path.
    function self.capture(name,now)
        if not showing then return false end
        local took=page.capture(name)
        if page.off() then
            fault(now)
            return true
        end
        return took
    end
    -- coop off: the page hidden with SB's close, as Back; no more buttons. The native part puts its slot back.
    function self.stop()
        if showing then
            hide('coop off')
            local ok,why=o.close()
            if not ok then log('pause tab: nothing closed: '..tostring(why)) end
        end
        stopped=true
    end
    return self
end
return Tab
