-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The pause menu's Online page. SB's pause menu (WB_GameMenu_Master) maps its tabs 1 to 8 to its own pages in
-- code, so this page is SBO's own widget: a CanvasPanel added last to the master's root (its WidgetTree's RootWidget,
-- CanvasPanel_0), full screen as SB's pages are, collapsed until ui/kit/pause_tab.lua shows it on tab 9. It lays out
-- ui/kit/online_model.lua's categories for the state now where SB's Settings page has its parts (WB_Setting_Set's
-- layout): the left list, the section headers, the rows with their values and the description pane. Each kind is made
-- from SB's own Settings class (ui/kit/parts.lua's paths) with WidgetBlueprintLibrary:Create, as kit.part does. A class
-- that cannot be made or filled is drawn with UMG TextBlocks and Borders in the kit's THEME instead, one log line per
-- class at its first build saying which way it went. The mouse: the kit's pointer (ui/kit/kit.lua's, in the viewport's
-- layout units, the page's own) over the boxes the page placed its list items and rows in (Page.under). Every HOVER s
-- the item the mouse moved onto takes the focus look, as on the Sessions screen; a resting mouse never moves the
-- cursor. A left click selects the item under the mouse. Inside the page: up and down in the list, right or select into
-- the rows, up and down there over the headers, back to the list; back in the list closes the pause menu. In the rows,
-- as on SB's Settings page: left and right change the focused row's value, select gives a list row its next value or
-- runs an action row, a click on a row's value part goes down on its left half and up on its right half, a click
-- elsewhere on a row is select. Each press runs through the co-op menu's own model and code (o.act: ui/kit/menu.lua's
-- act), so both menus change a value and run a row the same way. A press the co-op menu's rules refuse (a row not
-- shown now, a range at its end, a write refused) plays SB's refusal sound and changes nothing; the pane says why when
-- there is a why. Select on a key row waits for the next key as the co-op menu does: the row reads Press a key, the
-- pane says which keys; an F-key (main/keys.lua through ui/kit/pause_tab.lua's capture) is checked against the other
-- keys by the co-op menu's own bind, Enter puts back its default, Esc or B stops the wait, the mouse and the other
-- words do nothing meanwhile. Select or a click on Open the co-op menu or a Test tools row opens the co-op menu. Every
-- engine call runs in pcall on the game thread. An engine error that is not a part's own turns the page off until the
-- mod reloads with one line; the Online tab then opens the co-op menu as before. A look a part refuses is logged once
-- a kind. Only UI: no save, no SetInputMode, no Slate focus taken. main/input.lua builds it behind its own guard.
-- tests/lua/ui/kit/online_page_test.lua covers it over fakes.
local U=require('core.unreal')
local Keep=require('core.keep')
local Parts=require('ui.kit.parts')
local Model=require('ui.kit.model')
local Online=require('ui.kit.online_model')
local Join=require('core.line')
local Page={ROWS=12,HOVER=0.1} -- Slots in the rows area (a longer category scrolls); seconds between mouse looks.
-- WB_Setting_Set's layout in 3840 by 2160 units, read in its class export: from x 0 at y 384, a 200 spacer, the left
-- list (356 wide, items 100 high), a 120 spacer, the rows (1640 wide, 130 a slot), a 120 spacer, the description pane
-- (780 by 1344, 68 down).
Page.AT={list={x=200,y=384,pitch=100,w=356,h=100},rows={x=676,y=384,pitch=130,w=1640,h=130},
    detail={x=2436,y=452,w=780,h=1344}}
-- The value part of WB_Setting_Rolling_Slot and of WB_Setting_Slider_Slot, from the row's left edge: HorizontalBox_1
-- holds SizeBox_3 (580 wide, the title), then SizeBox_1 (960 wide after a left padding of 30, the value). Read in
-- their class exports. SB's own click button of the rolling row (Button_Action_ForClick) spans the whole row.
Page.AT.value={x=610,w=960}
Page.KINDS={'tab','header','option','rolling','slider','detail'}
-- The master's page widgets of tabs 1 to 8 (WB_Tap_Set's TabDataArray order, the tab numbers of the GameMenu logic's
-- init 0x141d90210), for the log line that says what SB's deactivate left shown.
Page.SB_PAGES={'WB_Equip_Set','WB_QuestJournal','WB_Map_Set','WB_Bag_Set','WB_NewSkill_Master','WB_Album_Set',
    'WB_Manual_Set','WB_GameMenu_Setting'}
local COLLAPSED,HIT_TEST_INVISIBLE,SELF_HIT_TEST_INVISIBLE=1,3,4 -- ESlateVisibility.
local SHOWN={[0]='Visible','Collapsed','Hidden','HitTestInvisible','SelfHitTestInvisible'}
local WIDGETS='/Script/UMG.Default__WidgetBlueprintLibrary'
local BOLD='/Game/Art/Font/Bold.Bold' -- The kit's item font (ui/kit/kit.lua's GAME_FONT), for the kit's drawing.

-- A row's part: a range is a slider, a choice, a toggle or a mute row a rolling row, any other an option row (the
-- action rows, the key rows, the module page rows, Copy my code).
function Page.kind(row)
    if row.key and row.min then return 'slider' end
    if row.member or row.key and row.values then return 'rolling' end
    return 'option'
end
-- A row's words, as ui/kit/menu.lua's draw makes them (w: ui/text's, gw: ui/text/guide's, ctx: online_model's).
function Page.label(w,gw,row,ctx)
    if row.id=='open_menu' then return w.online_page.open_menu end
    if row.page then return row.page.title(w) or '' end
    if row.member then return w.lobby.set.mute:format(Join.name(row.name) or '') end
    if row.id=='guide' then return gw.row end
    local label=w.row[row.id or row.key] or ''
    if row.id=='remove' then label=label:format(Join.name(ctx.stranger and ctx.stranger.name) or w.ask.someone) end
    return label
end
-- A row's value in w's words, as the co-op menu shows it, or nil (an action row: SB's own word stays).
function Page.value(w,row,ctx)
    if row.id=='copy' then return ctx.code end
    if row.member then return w.value[row.muted and 'on' or 'off'] end
    local v=row.key and ctx.values and ctx.values[row.key]
    if v==nil or row.bind then return v end
    return Model.shown(w,row,v)
end
-- A range's place between its ends, 0 to 1.
local function percent(row,ctx)
    local n=tonumber(ctx.values and ctx.values[row.key]) or tonumber(row.default) or row.min
    return math.max(0,math.min(1,(n-row.min)/(row.max-row.min)))
end
-- A category's lines: its sections' headers ({head=id}) and rows ({row=row}) in order.
local function lines(cat)
    local out={}
    for _,sec in ipairs(cat.sections) do
        out[#out+1]={head=sec.id}
        for _,row in ipairs(sec.rows) do out[#out+1]={row=row} end
    end
    return out
end
local function first(list) for i,line in ipairs(list) do if not line.head then return i end end end
-- The cursor: in the left list (list) or in the rows, its category, its line in that category and the first line
-- shown (top).
function Page.cursor() return {list=true,cat=1,row=2,top=0} end
-- Keeps the cursor's line in view with one line around it (a header above the first row shows).
local function scroll(cur,n)
    local top=math.max(0,math.min(cur.top,n-Page.ROWS))
    if cur.row<=top+1 then top=math.max(0,cur.row-2)
    elseif cur.row>=top+Page.ROWS then top=math.min(n-Page.ROWS,cur.row-Page.ROWS+1) end
    cur.top=math.max(0,top)
end
-- A navigation word ('up', 'down', 'left', 'right', 'select', 'back') over cats (online_model's categories now): the
-- cursor moves (up and down wrap; in the rows they skip the headers); right or select goes into the rows, on the
-- first one; back goes from the rows to the list. 'close' for back in the list, else nil. In the rows, left, right
-- and select are presses on the row (Page.press): the page's nav runs them, this does nothing with them.
function Page.move(cur,cats,word)
    if #cats==0 then return word=='back' and 'close' or nil end
    cur.cat=math.max(1,math.min(cur.cat,#cats))
    local list=lines(cats[cur.cat])
    if cur.list then
        if word=='up' or word=='down' then
            cur.cat=(cur.cat-1+(word=='up' and -1 or 1))%#cats+1
            cur.row,cur.top=first(lines(cats[cur.cat])),0
        elseif word=='right' or word=='select' then cur.list,cur.row,cur.top=false,first(list),0
        elseif word=='back' then return 'close' end
        return nil
    end
    if not list[cur.row] or list[cur.row].head then cur.row=first(list) end -- The rows changed meanwhile.
    if word=='up' or word=='down' then
        repeat cur.row=(cur.row-1+(word=='up' and -1 or 1))%#list+1 until not list[cur.row].head
        scroll(cur,#list)
    elseif word=='back' then cur.list=true end
    return nil
end
-- What a press (word: 'select', 'left' or 'right') asks of a row: 'open_menu' and its module page (nil for Open the
-- co-op menu) for select on Open the co-op menu or a Test tools row; 'change' and -1 or 1 for left or right on a
-- setting row with values or a range; 'select' for select on any other row and for left or right on a mute row (drawn
-- as a two-value row: the arrows mute or unmute); else nil (left or right on an action, key or Test tools row).
function Page.press(row,word)
    if word~='select' and word~='left' and word~='right' then return nil end
    if row.id=='open_menu' or row.page then
        if word=='select' then return 'open_menu',row.page end
        return nil
    end
    if row.member or word=='select' then return 'select' end
    if row.key and not row.bind then return 'change',word=='left' and -1 or 1 end
end
-- The press a left click at x (the page's units) makes on row: left or right on the two halves of a rolling or slider
-- row's value part (Page.AT.value), select elsewhere on the row.
function Page.word_at(row,x)
    local from,w=Page.AT.rows.x+Page.AT.value.x,Page.AT.value.w
    if Page.kind(row)=='option' or x<from or x>=from+w then return 'select' end
    return x<from+w/2 and 'left' or 'right'
end
-- What is under x, y (the kit's pointer, in the page's units) in the boxes the page placed: 'list' and the category, or
-- 'row' and the slot of a row (a header's slot is no row), or nil.
function Page.under(cats,cur,x,y)
    local function inside(at,i)
        local top=at.y+(i-1)*at.pitch
        return x>=at.x and x<at.x+at.w and y>=top and y<top+at.h
    end
    local A=Page.AT
    for i=1,#cats do if inside(A.list,i) then return 'list',i end end
    local list=cats[cur.cat] and lines(cats[cur.cat]) or {}
    for i=1,Page.ROWS do
        local line=list[cur.top+i]
        if line and not line.head and inside(A.rows,i) then return 'row',i end
    end
end
-- What to draw: list {kind='tab', label=, look=} per category; rows, one per slot ({kind='header', head=true,
-- label=}, {kind=, label=, value=, percent= (a slider's), row=, look=} or false); detail {title=, desc=}. look:
-- 'focus' (the cursor, or the list item under the mouse, cur.over), 'select' (the category the rows show while the
-- cursor is in them or the mouse is on another item) or 'normal'. The pane's description is the last press's note
-- (cur.note: a confirm's question, a refusal's why, the reload note) while the cursor is in the rows.
function Page.specs(cats,cur,w,gw,ctx)
    local out={list={},rows={},detail={title='',desc=''}}
    if #cats==0 then
        for i=1,Page.ROWS do out.rows[i]=false end
        return out
    end
    cur.cat=math.max(1,math.min(cur.cat,#cats))
    for i,cat in ipairs(cats) do
        out.list[i]={kind='tab',label=w.online_page.cat[cat.id] or cat.id,
            look=i==cur.over and 'focus' or i~=cur.cat and 'normal' or (cur.list and not cur.over) and 'focus'
                or 'select'}
    end
    local list=lines(cats[cur.cat])
    for i=1,Page.ROWS do
        local line=list[cur.top+i]
        if not line then out.rows[i]=false
        elseif line.head then out.rows[i]={kind='header',head=true,label=w.online_page.sec[line.head] or line.head}
        else
            local row=line.row
            local s={kind=Page.kind(row),row=row,label=Page.label(w,gw,row,ctx),value=Page.value(w,row,ctx),
                look=(not cur.list and cur.top+i==cur.row) and 'focus' or 'normal'}
            if row.bind and row.key==cur.capturing then s.value=w.press end -- Waiting for a key, as in the co-op menu.
            if s.kind=='slider' then s.percent=percent(row,ctx) end
            out.rows[i]=s
        end
    end
    -- The F5 menu's rows have no description today: the pane shows the name alone, its media part collapsed (draw).
    local line=not cur.list and list[cur.row]
    out.detail.title=line and line.row and Page.label(w,gw,line.row,ctx) or out.list[cur.cat].label
    out.detail.desc=not cur.list and cur.note or ''
    return out
end

-- A class by its asset's path, as ui/kit/pause_tab.lua's class_of: the keep's when it serves it, else in memory, else
-- loaded.
local function class_of(asset)
    if Keep.serves(asset..'_C') then return assert(Keep.get(asset..'_C'),asset..' is not in memory') end
    local class=U.valid(StaticFindObject(asset..'_C'))
    if class then return class end
    pcall(LoadAsset,asset)
    return assert(U.valid(StaticFindObject(asset..'_C')),asset..' is not in this game build')
end
-- Each kind's fill of SB's part: before it enters the canvas (the Blueprint's own text properties, which its
-- PreConstruct may copy) and after (its TextBlocks and calls), from the class exports of 26123051.
local function text_of(w,name) return assert(U.valid(w[name]),'no '..name) end
local FILL={
    tab={before=function(w,s) w.TabName=FText(s.label) end,
        after=function(w,s) text_of(w,'Text_side_name'):SetText(FText(s.label)) end},
    header={before=function(w,s) w.Category_Name=FText(s.label) end},
    -- No value: Text_ItemValue keeps SB's own word (UI_Accept).
    option={before=function(w,s)
        w.Text_TitleValue=FText(s.label)
        if s.value then w.Text_ItemValue=FText(s.value) end
    end},
    rolling={before=function(w,s)
        w.Text_TitleValue=FText(s.label)
        w.Text_ItemValue=FText(s.value or '')
    end,after=function(w,s)
        text_of(w,'Text_Title'):SetText(FText(s.label))
        text_of(w,'Text_Btn_name'):SetText(FText(s.value or ''))
    end},
    slider={before=function(w,s)
        w.TextTitleValue=FText(s.label)
        w.CurrentPercent=s.percent
        w.ItemTextRange={Min=s.row.min,Max=s.row.max}
    end,after=function(w,s)
        w:UpdatePercentOffset(s.percent)
        text_of(w,'Text_VolumeValue'):SetText(FText(s.value or ''))
    end},
    detail={before=function() end,after=function(w,s)
        text_of(w,'Text_ItemName'):SetText(FText(s.title))
        text_of(w,'Text_Desc'):SetText(FText(s.desc))
    end},
}
-- o: {log=function(line) ([PT] lines), words=function() ui/text's words now, guide_words=function() ui/text/guide's,
-- ctx=function() online_model's ctx (mode, chat, code, stranger, values, members, pages), theme=ui/kit/kit.lua's
-- THEME, pointer=function() the mouse in the viewport's layout units (ui/kit/kit.lua's pointer): x, y, or nil,
-- act=function(action, key, text, ctx) the co-op menu's run of what its model answered (ui/kit/menu.lua's act): ok,
-- note, bind=function(key, name) the co-op menu's take of a key pressed for a key row (ui/kit/menu.lua's bind):
-- taken, written, note}.
function Page.new(o)
    local log,theme=o.log,o.theme
    local wanted={}
    for _,kind in ipairs(Page.KINDS) do wanted[#wanted+1]=Parts.CLASS[kind] end
    Keep.want(wanted)
    local model=Online.new()
    local LIST=#Online.CATEGORIES -- The most categories a state shows.
    local self={}
    local off=nil -- Why the page is off for the Lua load, or nil.
    local master,tree,canvas=nil,nil,nil
    local shown,cur,ctx,cats=false,Page.cursor(),{},{}
    local slots={list={},rows={}}
    -- The item under the mouse at the last look ('list1', 'row3'; nil: none; false: no look yet); when to look again.
    local hover,hover_at=false,0
    -- The kit's sounds by name: 'tab' is the focus sound of SB's Settings page; 'wheel_move' is ui_move, the wave
    -- SB's Settings list item holds in its Movesound animation, played here when a click shows another category.
    local sound=o.sound or function() end
    local broken,said,refused={},{},{} -- Kinds drawn by the kit; class lines said; look refusals said.
    local built_at,made=nil,{sb=0,kit=0} -- The clock of a build whose first draw is not logged yet; parts it made.
    local function short(kind) return Parts.CLASS[kind]:match('[^.]+$') end
    local function new_widget(class)
        local w=U.valid(StaticConstructObject(U.find('/Script/UMG.'..class),tree))
        return assert(w,'no '..class..' made')
    end
    local function put(w,x,y,width,height)
        local slot=assert(U.valid(canvas:AddChildToCanvas(w)),'the page canvas took no '..tostring(w))
        slot:SetPosition({X=x,Y=y})
        if width then slot:SetSize({X=width,Y=height}) else slot:SetAutoSize(true) end
    end
    -- The kit's drawing of a kind, in place of SB's part: a clear back, a Beta bar and the words.
    local function text(str,color,size,x,y)
        local t=new_widget('TextBlock')
        t:SetVisibility(HIT_TEST_INVISIBLE)
        pcall(function() -- The kit's font when the keep holds it; the size either way, or the default font.
            local font=U.value_of(t.Font)
            if Keep.serves(BOLD) then font.FontObject=Keep.get(BOLD) end
            font.Size=size
        end)
        t:SetText(FText(str or ''))
        t:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0})
        put(t,x,y)
        return t
    end
    local function border(color,x,y,width,height)
        local b=new_widget('Border')
        b:SetVisibility(HIT_TEST_INVISIBLE)
        b:SetBrushColor(color)
        put(b,x,y,width,height)
        return b
    end
    local function drawn(kind,s,x,y)
        local rec={kind=kind,kit=true,look='normal',widgets={}}
        local function keep(w) rec.widgets[#rec.widgets+1]=w; return w end
        if kind=='detail' then
            rec.title=keep(text(s.title,theme.text,40,x,y))
            rec.desc=keep(text(s.desc,theme.grey,34,x,y+90))
            return rec
        end
        if kind=='header' then
            keep(text(s.label,theme.grey,34,x+36,y+30))
            return rec
        end
        local at=kind=='tab' and Page.AT.list or Page.AT.rows
        rec.back=keep(border(theme.clear,x,y,at.w,at.h-10))
        rec.bar=keep(border(theme.beta,x,y,6,at.h-10))
        rec.bar:SetVisibility(COLLAPSED)
        keep(text(s.label,theme.text,kind=='tab' and 34 or 40,x+36,y+24))
        if kind~='tab' then keep(text(s.value or '',theme.text,40,x+at.w-600,y+24)) end
        return rec
    end
    -- A part of kind at x, y from spec s: SB's, or the kit's drawing once SB's class failed. An error in the kit's
    -- drawing is the page's (the caller's pcall).
    local function make(kind,s,x,y)
        if not broken[kind] then
            local w
            local ok,why=pcall(function()
                local pc=assert(U.controller(),'no player controller')
                w=assert(U.valid(U.find(WIDGETS):Create(pc,class_of(Parts.ASSET[kind]),pc)),'Create gave no widget')
                w:SetVisibility(HIT_TEST_INVISIBLE)
                FILL[kind].before(w,s)
                put(w,x,y)
                if FILL[kind].after then FILL[kind].after(w,s) end
            end)
            if ok then
                if not said[kind] then said[kind]=true; log('online page: '..short(kind)..' built from SB\'s class') end
                made.sb=made.sb+1
                return {kind=kind,o=w,look='normal',widgets={w}} -- Construct played Normal.
            end
            if w then pcall(function() w:RemoveFromParent() end) end
            broken[kind],said[kind]=true,true
            log('online page: '..short(kind)..' not built ('..U.why(why)..'); the kit\'s drawing in its place')
        end
        made.kit=made.kit+1
        return drawn(kind,s,x,y)
    end
    local function drop(rec)
        for _,w in ipairs(rec.widgets) do pcall(function() if U.valid(w) then w:RemoveFromParent() end end) end
    end
    -- A call on SB's part; a refusal logged once a what (its kind's look, the pane's words).
    local function call(what,f)
        local ok,why=pcall(f)
        if not ok and not refused[what] then
            refused[what]=true
            log('online page: '..what..' refused: '..U.why(why))
        end
    end
    -- A part's look, on change only. SB's tab: PlayFocusAnim, or StopFocusAnim then Select or SetNormal; SB's rows:
    -- EventNotification StateFocus or StateNormal; the kit's: the focus tint and the Beta bar.
    local function look(rec,want)
        if rec.look==want then return end
        rec.look=want
        local w=rec.o
        call(rec.kind..' look',function()
            if rec.kit then
                if rec.back then rec.back:SetBrushColor(want=='focus' and theme.focus or theme.clear) end
                if rec.bar then rec.bar:SetVisibility(want=='normal' and COLLAPSED or HIT_TEST_INVISIBLE) end
            elseif rec.kind=='tab' then
                if want=='focus' then w:PlayFocusAnim()
                else
                    w:StopFocusAnim()
                    if want=='select' then w:Select() else w:SetNormal() end
                end
            elseif rec.kind~='header' then w:EventNotification(want=='focus' and 'StateFocus' or 'StateNormal') end
        end)
    end
    -- Slot i of set as spec s at x, y: made again when its kind, words, value or place changed.
    local function sync(set,i,s,x,y)
        local sig=s and table.concat({s.kind,s.label or '',tostring(s.value),tostring(s.percent),x,y},'|')
        local have=set[i]
        if have and have.sig~=sig then drop(have); set[i],have=nil,nil end
        if s and not have then
            have=make(s.kind,s,x,y)
            have.sig,set[i]=sig,have
        end
        if have then look(have,s.look or 'normal') end
    end
    local function draw()
        local w,gw=o.words(),o.guide_words()
        cats=model.categories(ctx)
        local s=Page.specs(cats,cur,w,gw,ctx)
        local A=Page.AT
        for i=1,LIST do sync(slots.list,i,s.list[i],A.list.x,A.list.y+(i-1)*A.list.pitch) end
        for i=1,Page.ROWS do sync(slots.rows,i,s.rows[i],A.rows.x,A.rows.y+(i-1)*A.rows.pitch) end
        local d=slots.detail
        if not d then
            d=make('detail',s.detail,A.detail.x,A.detail.y)
            d.title_now,d.desc_now,slots.detail=s.detail.title,s.detail.desc,d
            -- No item of the page has media (the F5 menu has none). SB's pane keeps its media part above the title:
            -- WB_Setting_SlotDetail's Thumbnail (an Image, 780 by 468, in OL_Thumbnail, the first slot of
            -- VerticalBox_235). Collapsed, the title moves up.
            if not d.kit then
                call('detail media',function()
                    assert(U.valid(d.o.Thumbnail),'no Thumbnail'):SetVisibility(COLLAPSED)
                end)
            end
        elseif d.title_now~=s.detail.title or d.desc_now~=s.detail.desc then
            d.title_now,d.desc_now=s.detail.title,s.detail.desc
            if d.kit then
                d.title:SetText(FText(s.detail.title))
                d.desc:SetText(FText(s.detail.desc))
            else call('detail words',function() FILL.detail.after(d.o,s.detail) end) end
        end
        if built_at then
            log(string.format('online page: built in %.0f ms: %d SB parts, %d drawn by the kit',
                (os.clock()-built_at)*1000,made.sb,made.kit))
            built_at=nil
        end
    end
    local function fail(why)
        off=U.why(why)
        shown=false
        pcall(function() if U.valid(canvas) then canvas:SetVisibility(COLLAPSED) end end)
        log('online page: off until the mod reloads: '..off..'; the Online tab opens the co-op menu as before')
    end
    -- The page in this pause menu (m, its WB_GameMenu_Master): its canvas, once a master. true, or false and why (the
    -- page is then off).
    function self.build(m)
        if off then return false,off end
        if canvas and master and U.valid(canvas) and U.valid(m) and U.address(m)==U.address(master) then return true end
        self.forget()
        local started=os.clock()
        local ok,why=pcall(function()
            tree=assert(U.valid(m.WidgetTree),'the pause menu has no WidgetTree')
            local root=assert(U.valid(tree.RootWidget),'its WidgetTree has no root widget')
            canvas=new_widget('CanvasPanel')
            canvas:SetVisibility(COLLAPSED)
            local slot=assert(U.valid(root:AddChildToCanvas(canvas)),'the root widget took no canvas')
            slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
            slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
            master=m
        end)
        if not ok then
            fail(why)
            return false,off
        end
        built_at,made=started,{sb=0,kit=0}
        return true
    end
    -- Shown (its parts drawn for the state now, the cursor on the first category, no confirm pending) or collapsed.
    function self.show(on)
        if off or not canvas then shown=false; return end
        local ok,why=pcall(function()
            if on then
                ctx,cur,hover=o.ctx(),Page.cursor(),false
                model.forget()
                draw()
                canvas:SetVisibility(SELF_HIT_TEST_INVISIBLE)
            elseif U.valid(canvas) then canvas:SetVisibility(COLLAPSED) end
        end)
        shown=on and ok
        if not ok then fail(why) end
    end
    -- No engine call: the key thread reads it.
    function self.shown() return shown end
    -- Where the cursor is: in the list or the rows, its category and its row (the row itself: a write that shows or
    -- hides another row moves its line, not the cursor).
    local function where()
        local cat=cats[cur.cat]
        local line=cat and not cur.list and lines(cat)[cur.row]
        return tostring(cur.list)..' '..(cat and cat.id or '')..' '..tostring(line and line.row or cur.row)
    end
    -- The cursor left its row: no confirm pending, no note in the pane, as the co-op menu's move.
    local function moved(was)
        if where()==was then return false end
        model.forget()
        cur.note=nil
        return true
    end
    -- A press the co-op menu's rules refuse: SB's refusal sound, nothing changed, the why in the pane (or none).
    local function refuse(n) sound('refuse'); cur.note=n end
    -- A press (Page.press's words) on row at now, through the co-op menu's model for that row (online_model's owner:
    -- the same change, select, show rules and confirm window as the co-op menu) and its code (o.act). The ctx is read
    -- again before and after. 'open_menu' and the module page, 'close' once the Online tab was written off (the pause
    -- menu closes as Back closes it), else nil.
    local function act(row,word,now)
        local how,dir=Page.press(row,word)
        if not how then return nil end
        if how=='open_menu' then sound('confirm'); return 'open_menu',dir end
        ctx=o.ctx()
        local m=model.owner(row)
        if not m then refuse(); return nil end
        m.point(ctx,row)
        if m.current(ctx)~=row then refuse(); return nil end -- Not shown now: the session ended, the code went.
        local action,key,text
        if how=='change' then action,key,text=m.change(ctx,ctx.values,dir)
        else action,key,text=m.select(ctx,now,ctx.values) end
        if not action then refuse(); return nil end -- A range at its end, a confirm whose row went.
        if action=='rebind' then -- The row waits for the next key: capture, or Enter for its default.
            cur.capturing,cur.note=key,o.words().capture
            sound('confirm')
            return nil
        end
        -- shortcut: a row that needs the game world opens the co-op menu (stage 1's path) until the page closes the
        -- pause menu and runs it.
        if Model.AWAY[action] or action=='report' then sound('confirm'); return 'open_menu' end
        local ok,n=o.act(action,key,text,ctx)
        cur.note=n
        sound(not ok and 'refuse' or (action=='set' or action=='mute') and 'change' or 'confirm')
        ctx=o.ctx()
        if ok and action=='set' and key=='pause_tab' and text=='off' then return 'close' end
    end
    -- The cursor on row again in category id after a press: the categories may have changed (a row shown or hidden,
    -- the session's categories gone); a row gone puts it on its category's first row.
    local function keep(id,row)
        cats=model.categories(ctx)
        if #cats==0 then return end
        for i,cat in ipairs(cats) do if cat.id==id then cur.cat=i end end
        cur.cat=math.min(cur.cat,#cats)
        local list=lines(cats[cur.cat])
        cur.row=first(list)
        for i,line in ipairs(list) do if line.row==row then cur.row=i end end
        scroll(cur,#list)
    end
    -- The row under the cursor pressed with word at now; act's answer.
    local function press(word,now)
        local id,row=cats[cur.cat].id,lines(cats[cur.cat])[cur.row].row
        local a,b=act(row,word,now)
        keep(id,row)
        return a,b
    end
    -- A key pressed (keybind.text's: 'Shift+F7', 'Enter') for the key row that waits: through the co-op menu's bind,
    -- which checks it against the other keys. Taken: the wait ends. Refused: the wait goes on, the why in the pane.
    local function take(name)
        local taken,ok,n=o.bind(cur.capturing,name)
        cur.note=n
        if taken then cur.capturing=nil end
        sound(taken and ok and 'change' or 'refuse')
        ctx=o.ctx()
    end
    -- A navigation word while shown, at now: in the rows, left, right and select press the cursor's row; other words
    -- move the cursor (Page.move). While a key row waits: back stops the wait, select puts back its default, the other
    -- words do nothing. The page drawn again; the answer: 'close', 'open_menu' and a module page, or nil.
    function self.nav(word,now)
        if off or not shown then return nil end
        local ok,a,b=pcall(function()
            if cur.capturing then
                if word=='back' then
                    cur.capturing,cur.note=nil,nil
                    sound('back')
                elseif word=='select' then take('Enter') end -- Space or the pad's A, as Enter: the default.
                draw()
                return nil
            end
            local was=where()
            cur.over=nil -- The keys take the cursor back from the mouse's list item.
            local line=not cur.list and cats[cur.cat] and lines(cats[cur.cat])[cur.row]
            local a,b
            if line and line.row and (word=='select' or word=='left' or word=='right') then a,b=press(word,now)
            else a=Page.move(cur,cats,word) end
            if moved(was) then sound('tab') end
            draw()
            return a,b
        end)
        if not ok then fail(a); return nil end
        return a,b
    end
    -- The cursor on what is under the mouse (Page.under's kind and slot): a category in the list, or a row; true when
    -- there is one.
    local function point(kind,i)
        local was=where()
        if kind=='list' then
            if i~=cur.cat or not cur.list then cur.list,cur.cat,cur.row,cur.top=true,i,first(lines(cats[i])),0 end
        elseif kind=='row' then cur.list,cur.row=false,cur.top+i
        else return false end
        moved(was)
        draw()
        return true
    end
    -- What is under the mouse: Page.under's kind and slot, then the mouse's x.
    local function under()
        local x,y=o.pointer()
        if x then
            local kind,i=Page.under(cats,cur,x,y)
            return kind,i,x
        end
    end
    -- A key pressed while shown (main/keys.lua's F-keys): true when a key row waited for it, taken or refused.
    function self.capture(name)
        if off or not shown or not cur.capturing then return false end
        local ok,why=pcall(function()
            take(name)
            draw()
        end)
        if not ok then fail(why) end
        return true
    end
    -- A left click while shown, at now: the list item or row under the mouse selected; on a row, the press its place
    -- makes (Page.word_at) and act's answer. Nothing while a key row waits.
    function self.click(now)
        if off or not shown or cur.capturing then return nil end
        local ok,a,b=pcall(function()
            local kind,i,x=under()
            local shown_cat=cur.cat
            if not point(kind,i) then return nil end
            if kind~='row' then
                if cur.cat~=shown_cat then sound('wheel_move') end
                return nil
            end
            local was=where()
            local a,b=press(Page.word_at(lines(cats[cur.cat])[cur.row].row,x),now)
            moved(was) -- A row gone: the cursor on another one.
            draw()
            return a,b
        end)
        if not ok then fail(a); return nil end
        return a,b
    end
    -- Each frame while shown: every HOVER s, the item the mouse moved onto (another one than at the last look). A row
    -- takes the cursor and its focus look. A list item is lit only, as in SB's Settings: a click shows its rows. Both
    -- play SB's move sound. A resting mouse never moves anything, even while the keys move the cursor under it.
    function self.tick(now)
        if off or not shown or now<hover_at or cur.capturing then return end
        hover_at=now+Page.HOVER
        local ok,why=pcall(function()
            local kind,i=under()
            local key=kind and kind..i
            local moved=hover~=false and key~=hover
            hover=key
            if not moved then return end
            local over=kind=='list' and i or nil
            if kind=='row' then
                cur.over=nil
                point(kind,i)
            elseif over~=cur.over then
                cur.over=over
                draw()
            end
            if key then sound('tab') end
        end)
        if not ok then fail(why) end
    end
    -- SB's eight page widgets' visibilities by name ('WB_Equip_Set=Hidden ...'): what SB's deactivate left.
    function self.visibility()
        local out={}
        for _,name in ipairs(Page.SB_PAGES) do
            local ok,v=pcall(function()
                local w=U.valid(master[name])
                if not w then return 'none' end
                local n=w:GetVisibility()
                return SHOWN[n] or tostring(n)
            end)
            out[#out+1]=name..'='..(ok and v or 'unread')
        end
        return table.concat(out,' ')
    end
    -- The master went (a map change, the menu destroyed): every reference dropped, no engine call.
    function self.forget()
        master,tree,canvas,shown=nil,nil,nil,false
        slots={list={},rows={}}
    end
    function self.off() return off~=nil end
    return self
end
return Page
