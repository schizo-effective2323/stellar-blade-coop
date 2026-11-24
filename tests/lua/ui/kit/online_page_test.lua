-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The pause menu's Online page (ui/kit/online_page.lua) over fakes. Pure: each row's part kind; its words and value as
-- the co-op menu draws them; the cursor over ui/kit/online_model.lua's categories in solo and while hosting (the list
-- wraps, right and select land on the first row, the rows skip headers and wrap, select and left in the rows
-- move nothing, back goes to the list, back in the list closes, a long category scrolls by height inside SB's rows
-- window with the cursor's line shown); no Test tools category and no row that opens the co-op menu (F5 keeps them);
-- what a press asks of each kind of row (Page.press) and which press a click
-- makes on a row's value part (Page.word_at); what is under the mouse in the boxes where SB draws the page's parts (a
-- list item, a row, never a header, a band or a line past the window, edges exclusive). Engine: the build adds one
-- collapsed canvas last to the master's root, nothing in it before the show; each of the six SB classes says once that
-- it was built; the parts sit where SB's Settings page puts its own (the list items, the headers and rows by their
-- heights, the pane), a long category's lines end above the key hints; each part's
-- Blueprint texts are set before it enters the canvas and its TextBlocks and calls after; a class whose Create raises
-- is drawn with a TextBlock and a Border in its place, one line for it, the others SB's; show makes the canvas
-- SelfHitTestInvisible with the focused item's PlayFocusAnim and the category's word in the pane, no description, the
-- pane's Thumbnail collapsed (one line when the pane has none); right gives Select, StateFocus on Host a session
-- and its words in the pane; a click (the kit's pointer) selects the row under the mouse, on Find a session it
-- opens its sub-page, on Host a session it asks first, on a header or with no pointer it does nothing, on a list item
-- it shows that category; the mouse
-- look (tick, every HOVER s) only notes what is under the mouse at its first look, then the item the mouse moved onto
-- takes the cursor, while a resting mouse never does, even after the keys moved the cursor; a refused look is logged
-- once; a canvas that cannot be made turns the page off with one line; visibility() names SB's eight pages with their
-- state. The rows act through the co-op menu's model and a fake act: right, left and select on a list row (the next
-- value, the wrap, a row shown or hidden by it with the cursor kept), a range held at its end with the refusal sound,
-- a click on each half of a value part, a write refused with its note in the pane, nothing on left or right of an
-- action row, the Online tab written off answering 'close', a row no longer shown refused and gone, Leave asked again
-- after a move of the keys, of the mouse look or of a click and after its 3 s, its question in the pane, Host a session
-- asking first then hosting in place, Copy my code, Invite and Write a bug report run in place, a run refused with its
-- why, a mute row kept under the cursor and muted by select too, Remove and Reset
-- all keys asking first then running, a key row waiting for a key (Press a key, the capture words, a key
-- refused or taken through a fake bind, select for the default, back to stop, the mouse and the other words doing
-- nothing meanwhile), an act that raises turning the page off. The state read again every Page.REFRESH s while the
-- page shows (an online session that begins or ends, the cursor kept or put on its category's first row). A sub-page's
-- rows (their kind, words, value and press); the Guide sub-page in Help's rows (a header, one row a guide page, its
-- body in the pane, the list kept, back to Guide, a click opening it, a click on a list item leaving it). Find a
-- session in Session's rows through a fake of the Sessions screen's enter, texts and ask (Search, Refresh, the
-- sessions with their details, a join answering 'close', the refusals, the list read again, the sub-page gone when an
-- online session begins or the sessions go off, Select refused with one line while they are off).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local U=require('core.unreal')
local T=require('ui.text')
local G=require('ui.text.guide')
local Model=require('ui.kit.model')
local O=require('ui.kit.online_model')
local Parts=require('ui.kit.parts')
local Page=require('ui.kit.online_page')
local w,gw=T.en,G.en

-- Pure: the kinds.
local function opt(key) for _,r in ipairs(Model.OPTIONS) do if r.key==key or r.id==key then return r end end end
local function main(id) for _,r in ipairs(Model.MAIN) do if r.id==id then return r end end end
local PAGE={title=function() return 'Tools' end,rows=function() return {} end}
for _,row in ipairs({main('host'),main('find'),opt('menu_key'),opt('reset_keys')}) do
    assert(Page.kind(row)=='option',tostring(row.id or row.key))
end
for _,row in ipairs({opt('who_can_join'),opt('pause_tab'),{id='mute',member='7',name='A',muted=false}}) do
    assert(Page.kind(row)=='rolling',tostring(row.id or row.key))
end
for _,row in ipairs({opt('ui_scale'),opt('photo_freeze_max'),opt('max_players')}) do
    assert(Page.kind(row)=='slider',row.key)
end
-- Words and values: the co-op menu's (ui/kit/menu.lua's draw).
local VALUES=Model.read('')
local CTX={mode='host',chat=true,code='0CS-CBMH',stranger={id='9',name='S'},values=VALUES,pages={PAGE},
    members={{id='7',name='A',linked=true,muted=false}}}
local mute={id='mute',member='7',name='A',muted=false}
assert(Page.label(w,gw,main('remove'),CTX)=='Remove S' and Page.value(w,main('remove'),CTX)==nil)
assert(Page.label(w,gw,main('remove'),{})=='Remove A player','No stranger read: the menu\'s word for one')
assert(Page.label(w,gw,mute,CTX)=='Mute A' and Page.value(w,mute,CTX)=='Off')
assert(Page.label(w,gw,main('guide'),CTX)==gw.row and gw.row=='Guide')
assert(Page.label(w,gw,main('copy'),CTX)=='Copy my code' and Page.value(w,main('copy'),CTX)=='0CS-CBMH')
assert(Page.label(w,gw,opt('photo_freeze_max'),CTX)==w.row.photo_freeze_max
    and Page.value(w,opt('photo_freeze_max'),CTX)=='10 min')
assert(Page.label(w,gw,main('host'),CTX)=='Host a session' and Page.value(w,main('host'),CTX)==nil)
assert(Page.value(w,opt('menu_key'),CTX)=='F5' and Page.value(w,opt('who_can_join'),CTX)=='Public')

-- Pure: the cursor.
local model=O.new()
local SOLO={mode='none',values=VALUES,pages={PAGE}}
local solo,hosting=model.categories(SOLO),model.categories(CTX)
local function id_at(cats,cur)
    local n=0
    for _,sec in ipairs(cats[cur.cat].sections) do
        n=n+1
        for _,row in ipairs(sec.rows) do n=n+1; if n==cur.row then return row.id or row.key or row.member end end
    end
end
for _,cats in ipairs({solo,hosting}) do
    local cur=Page.cursor()
    assert(cur.list and cur.cat==1 and cur.top==0)
    Page.move(cur,cats,'up'); assert(cur.cat==#cats,'The list wraps up')
    Page.move(cur,cats,'down'); assert(cur.cat==1,'and down')
    assert(Page.move(cur,cats,'left')==nil and cur.list,'Left does nothing')
    local first=cats==solo and 'host' or 'invite'
    Page.move(cur,cats,'right'); assert(not cur.list and id_at(cats,cur)==first,'Right: the first row')
    assert(Page.move(cur,cats,'select')==nil and not cur.list,'Select in the rows: a press, which the page\'s nav runs')
    Page.move(cur,cats,'back'); assert(cur.list,'Back: the list')
    Page.move(cur,cats,'select'); assert(not cur.list and id_at(cats,cur)==first,'Select: the same')
    Page.move(cur,cats,'down')
    assert(id_at(cats,cur)==(cats==solo and 'find' or 'copy'),'Down: the next row: '..id_at(cats,cur))
    assert(Page.move(cur,cats,'select')==nil and Page.move(cur,cats,'left')==nil and not cur.list,
        'Select on another row and left do nothing')
    Page.move(cur,cats,'up'); Page.move(cur,cats,'up')
    assert(id_at(cats,cur)=='max_players','Up from the first row wraps to the last')
    Page.move(cur,cats,'back')
    assert(Page.move(cur,cats,'back')=='close' and cur.list,'Back in the list closes the pause menu')
end
assert(Page.move(Page.cursor(),{},'back')=='close' and Page.move(Page.cursor(),{},'down')==nil,'No category')
-- Pure: what a press asks of each kind of row, as SB's Settings rows take it.
do
    local function said(row,word)
        local a,b=Page.press(row,word)
        return tostring(a)..' '..tostring(b)
    end
    for _,key in ipairs({'who_can_join','max_players','pause_tab','emote_pad','photo_freeze_max'}) do
        assert(said(opt(key),'select')=='select nil' and said(opt(key),'left')=='change -1'
            and said(opt(key),'right')=='change 1',key)
    end
    for _,row in ipairs({opt('menu_key'),main('host'),opt('reset_keys'),main('leave')}) do
        local what=row.id or row.key
        assert(said(row,'select')=='select nil' and said(row,'left')=='nil nil' and said(row,'right')=='nil nil',what)
    end
    for _,word in ipairs({'select','left','right'}) do assert(said(mute,word)=='select nil','A mute row: '..word) end
    -- No category is Test tools and no row opens the co-op menu, module pages in the ctx or not: F5 keeps them.
    for _,cats in ipairs({solo,hosting}) do
        for _,cat in ipairs(cats) do
            assert(cat.id~='tools','No Test tools category')
            for _,sec in ipairs(cat.sections) do
                for _,row in ipairs(sec.rows) do
                    assert(not row.page and said(row,'select')~='open_menu nil','A row that opens the co-op menu')
                end
            end
        end
    end
    assert(said({id='page',page=PAGE},'select')=='select nil','Page.press opens the co-op menu no more')
    -- A sub-page's row: its own kind, words and value; select is its press, left and right on a rolling one only.
    local p1={sub='guide',id='p1',kind='option',text='T',shown='',desc='D'}
    assert(Page.kind(p1)=='option' and Page.label(w,gw,p1,CTX)=='T' and Page.value(w,p1,CTX)=='','A sub-page row')
    assert(said(p1,'select')=='sub 1' and said(p1,'left')=='nil nil' and said(p1,'right')=='nil nil')
    local c1={sub='join_code',id='c1',kind='rolling',text='1',shown='_'}
    assert(Page.kind(c1)=='rolling' and Page.value(w,c1,CTX)=='_' and said(c1,'left')=='sub -1'
        and said(c1,'right')=='sub 1' and said(c1,'select')=='sub 1' and said(c1,'up')=='nil nil','A rolling one')
    assert(said(opt('who_can_join'),'up')=='nil nil' and said(opt('who_can_join'),'back')=='nil nil')
    -- A click: the value part of a rolling or slider row runs from x 1406 to 2366 in the page's units (the rows at
    -- 736, drawn 60 right of it, the value 610 in, 960 wide), its left half down, its right half up; elsewhere on a
    -- row, select.
    local who=opt('who_can_join')
    assert(Page.word_at(who,1406)=='left' and Page.word_at(who,1420)=='left' and Page.word_at(who,1885)=='left')
    assert(Page.word_at(who,1886)=='right' and Page.word_at(who,2360)=='right' and Page.word_at(who,2366)=='select')
    assert(Page.word_at(who,1405)=='select' and Page.word_at(who,820)=='select')
    assert(Page.word_at(opt('max_players'),1420)=='left' and Page.word_at(mute,2120)=='right')
    assert(Page.word_at(main('host'),1420)=='select' and Page.word_at(opt('menu_key'),2120)=='select','Option rows')
end
-- SB's Settings page in the page's units, read in WB_Setting_Set, WB_Setting_Tab, WB_Setting_TabButton,
-- WB_Setting_Category, the WB_Setting_*_Slot classes and WB_Display_Detail: list items 416 by 100 from 200, 452, one
-- every 120; the rows from y 452, a header 100 high with a band of 100 above it but the first, a row 130, each row
-- drawn 1640 wide from x 796 (placed at 736, SB's render translation of 60). The middle of line i of a category shown
-- from its first line, heads its header lines (solo's Session by default).
local SESSION_HEADS,HOSTING_HEADS,CONTROLS_HEADS={1,5},{1,6},{1,10,12,16}
local function row_at(i,heads)
    local head,y={},452
    for _,n in ipairs(heads or SESSION_HEADS) do head[n]=true end
    for n=1,i-1 do y=y+(head[n] and 100 or 130)+(head[n+1] and 100 or 0) end
    return 1000,y+(head[i] and 50 or 65)
end
local function item_at(i) return 300,452+(i-1)*120+50 end
-- Pure: what is under the mouse.
do
    local function under(cur,x,y) return table.concat({Page.under(solo,cur,x,y)},' ') end
    local cur=Page.cursor()
    assert(under(cur,item_at(1))=='list 1' and under(cur,item_at(#solo))=='list '..#solo,'The list items')
    assert(under(cur,item_at(#solo+1))=='','No item past the last category')
    assert(under(cur,200,452)=='list 1' and under(cur,615,452)=='list 1' and under(cur,616,452)==''
        and under(cur,199,452)=='' and under(cur,300,451)=='','Edges')
    assert(under(cur,300,551)=='list 1' and under(cur,300,552)=='' and under(cur,300,571)==''
        and under(cur,300,572)=='list 2','The 20 between two items is no item')
    assert(under(cur,row_at(1))=='' and under(cur,row_at(2))=='row 2' and under(cur,row_at(4))=='row 4',
        'A header is no row: '..under(cur,row_at(1)))
    local y=select(2,row_at(2))
    assert(under(cur,796,y)=='row 2' and under(cur,795,y)=='' and under(cur,2435,y)=='row 2' and under(cur,2436,y)=='',
        'Where SB draws the row')
    assert(under(cur,1000,552)=='row 2' and under(cur,1000,681)=='row 2' and under(cur,1000,682)=='row 3'
        and under(cur,1000,941)=='row 4' and under(cur,1000,942)=='' and under(cur,1000,1041)==''
        and under(cur,1000,1141)=='' and under(cur,1000,1142)=='row 6',
        'A row 130 high, the band and the header no row')
    assert(under(cur,row_at(8))=='row 8' and under(cur,row_at(9))=='','Past the last line')
    assert(under(cur,700,500)=='','Between the list and the rows')
end
-- A long category (Controls: 4 headers, 13 rows) scrolls by height: the lines shown end inside SB's rows window (y
-- 1900, above the key hints), the line after the cursor's shows, the first header shown at top.
do
    local cur,at=Page.cursor(),nil
    for i,cat in ipairs(solo) do if cat.id=='controls' then at=i end end
    for _=1,at-1 do Page.move(cur,solo,'down') end
    Page.move(cur,solo,'right')
    local list={} -- Controls' lines as the page makes them: {head=id} or {row=row}.
    for _,sec in ipairs(solo[at].sections) do
        list[#list+1]={head=sec.id}
        for _,row in ipairs(sec.rows) do list[#list+1]={row=row} end
    end
    assert(#list==17 and list[10].head and list[12].head and list[16].head,'Controls: '..#list..' lines')
    local moved=false
    for _=1,20 do
        Page.move(cur,solo,'down')
        local shown,seen=Page.place(list,cur.top),{}
        for _,p in ipairs(shown) do seen[p.i]=true end
        local last=shown[#shown]
        assert(shown[1].i==cur.top+1 and seen[cur.row] and (seen[cur.row+1] or cur.row==#list)
            and last.y+last.h<=1900,cur.row..' '..cur.top)
        moved=moved or cur.top>0
    end
    assert(moved,'The rows scrolled')
    while cur.row~=2 do Page.move(cur,solo,'down') end
    assert(cur.top==0,'Back at the first row: its header shows')
end

-- Engine fakes. fake(name, props): a UObject whose property writes and method calls go into events in order; a
-- method it has no prop for is recorded and answers as the engine's would for the few that answer.
local events,logs,objects,constructed={},{},{},{}
local addresses,raising,no_canvas,count=0,{},false,0
local function fake(name,props)
    addresses=addresses+8
    local address,calls=addresses,{}
    props=props or {}
    return setmetatable({},{__index=function(_,k)
        if k=='type' then return function() return 'UObject' end end
        if k=='IsValid' then return function() return true end end
        if k=='GetAddress' then return function() return address end end
        if k=='props' then return props end
        if k=='calls' then return calls end
        if k=='name' then return name end
        if props[k]~=nil then return props[k] end
        return function(_,...)
            local args={...}
            calls[#calls+1]={k,...}
            events[#events+1]=name..':'..k
            if k=='SetVisibility' then props.visibility=args[1]
            elseif k=='GetVisibility' then return props.visibility
            elseif k=='IsHovered' then return props.hovered==true
            elseif k=='SetText' then props.text=args[1]
            elseif k=='AddChildToCanvas' then
                props.children=props.children or {}
                table.insert(props.children,args[1])
                events[#events]=name..':add '..args[1].name
                local slot=fake(name..' slot')
                args[1].props.canvas_slot=slot -- Where it went: its SetPosition.
                return slot
            end
        end
    end,__newindex=function(_,k,v) props[k]=v; events[#events+1]=name..'.'..k end})
end
local function called(x,method)
    local n=0
    for _,c in ipairs(x.calls) do if c[1]==method then n=n+1 end end
    return n
end
local function at(event) for i,e in ipairs(events) do if e==event then return i end end end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end end
local function lines_with(text)
    local n=0
    for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end
    return n
end
FText=function(s) return s end
FName=function(s) return s end
LoadAsset=function() end
StaticFindObject=function(path) return objects[path] end
StaticConstructObject=function(class,outer)
    if no_canvas and class.props.umg=='CanvasPanel' then return nil end
    count=count+1
    constructed[#constructed+1]={umg=class.props.umg,outer=outer}
    return fake(class.props.umg..'#'..count)
end
local SUB={tab={'Text_side_name'},rolling={'Text_Title','Text_Btn_name'},slider={'Text_VolumeValue'},
    detail={'Text_ItemName','Text_Desc','Thumbnail'}}
local PC=fake('pc')
U.controller=function() return PC end
for _,umg in ipairs({'CanvasPanel','Border','TextBlock'}) do objects['/Script/UMG.'..umg]=fake(umg,{umg=umg}) end
local made={}
objects['/Script/UMG.Default__WidgetBlueprintLibrary']=fake('library',{Create=function(_,pc,class,owner)
    assert(pc==PC and owner==PC,'Create as kit.part makes parts')
    if raising[class.props.kind] then error('Create refused '..class.props.kind) end
    count=count+1
    local name=class.props.kind..'#'..count
    local props={}
    for _,sub in ipairs(SUB[class.props.kind] or {}) do props[sub]=fake(name..'.'..sub) end
    local x=fake(name,props)
    made[#made+1]={kind=class.props.kind,o=x}
    return x
end})
for _,kind in ipairs(Page.KINDS) do objects[Parts.CLASS[kind]]=fake('class '..kind,{kind=kind}) end
local function master()
    local root=fake('CanvasPanel_0',{children={}})
    local m=fake('master',{WidgetTree=fake('tree',{RootWidget=root})})
    for i,name in ipairs(Page.SB_PAGES) do m.props[name]=fake(name,{visibility=i==8 and 1 or 2}) end
    return m,root
end
local THEME={text='text',grey='grey',beta='beta',focus='focus',clear='clear'}
local ctx={mode='none',values=Model.read(''),pages={PAGE}} -- Solo, its own values: the presses write them.
local mouse=nil -- The kit's pointer: {x, y} or nil.
local sounds={} -- The kit's sounds asked, by name.
-- The co-op menu's act (ui/kit/menu.lua's): each call as 'action key text'; act_ok and act_note its answer, a set
-- written into the ctx's values when ok; act_raise: it raises that. Its bind: each call as 'key name'; bound its
-- answer (taken, written, note), the key written into the ctx's values when taken and written.
local acts,act_ok,act_note,act_raise={},true,nil,nil
local binds,bound={},{true,true,nil}
-- A confirm's first step: the co-op menu's act answers with its question (ui/kit/menu.lua's here).
local ASKS={confirm_leave=w.confirm_leave,confirm_remove=w.confirm_remove:format('S'),
    confirm_reset_keys=w.confirm_reset_keys,confirm_host=w.confirm_host}
-- The Sessions screen's three for the page (online/session/ui/sessions.lua's enter, texts and ask): each call in
-- fs.calls ('enter', 'ask <what> <i>'), fs.texts what texts gives, fs.ok what ask answers; fs.gone: the online
-- sessions off (the page's sessions() gives nil).
local fs={}
local function sessions()
    if fs.gone then return nil end
    return {enter=function() fs.calls[#fs.calls+1]='enter'; return true end,texts=function() return fs.texts end,
        ask=function(what,i) fs.calls[#fs.calls+1]='ask '..what..(i and ' '..i or ''); return fs.ok end}
end
local function new()
    events,logs,made,constructed,raising,no_canvas,mouse,sounds={},{},{},{},{},false,nil,{}
    acts,act_ok,act_note,act_raise={},true,nil,nil
    binds,bound={},{true,true,nil}
    fs.calls,fs.ok,fs.gone,fs.texts={},true,false,{tab='Public',refresh='Refresh',status='',footer='',rows={}}
    return Page.new({log=function(line) logs[#logs+1]=line end,words=function() return w end,
        guide_words=function() return gw end,ctx=function() return ctx end,theme=THEME,
        pointer=function() if mouse then return mouse[1],mouse[2] end end,
        sound=function(name) sounds[#sounds+1]=name end,
        act=function(a,k,t,c)
            assert(c==ctx,'The ctx read for the press')
            if act_raise then error(act_raise) end
            acts[#acts+1]=a..' '..tostring(k)..' '..tostring(t)
            if a=='set' and act_ok then ctx.values[k]=t end
            return act_ok,act_note or ASKS[a]
        end,
        bind=function(k,name)
            binds[#binds+1]=k..' '..name
            if bound[1] and bound[2] then ctx.values[k]=name end
            return bound[1],bound[2],bound[3]
        end,sessions=sessions})
end
local function first_made(kind) for _,m in ipairs(made) do if m.kind==kind then return m.o end end end
local function made_n(kind)
    local n=0
    for _,m in ipairs(made) do if m.kind==kind then n=n+1 end end
    return n
end

-- The build: one canvas, collapsed, added last to the master's root; nothing in it yet.
local page=new()
local m,root=master()
assert(page.build(m)==true and not page.off() and not page.shown())
local canvas=root.props.children[1]
assert(#root.props.children==1 and canvas.name:find('^CanvasPanel') and canvas.props.visibility==1,'A collapsed canvas')
assert(constructed[1].outer==m.props.WidgetTree,'Made in the master\'s WidgetTree')
assert(#(canvas.props.children or {})==0 and #made==0,'No part before the show')
assert(page.build(m)==true and #root.props.children==1,'The same master: built once')
-- Show: SelfHitTestInvisible; solo's Session drawn from SB's six classes, each said once; the first item focused.
page.show(true)
assert(page.shown() and canvas.props.visibility==4,'Shown, hit tests to its children only')
assert(made_n('tab')==10 and made_n('header')==2 and made_n('option')==3 and made_n('rolling')==2
    and made_n('slider')==1 and made_n('detail')==1,'Solo\'s Session: '..#made..' parts')
for _,kind in ipairs(Page.KINDS) do
    assert(lines_with(Parts.CLASS[kind]:match('[^.]+$')..' built from SB\'s class')==1,kind)
end
assert(logged('online page: built in ') and logged(': 19 SB parts, 0 drawn by the kit'),table.concat(logs,'|'))
-- Where the parts sit, as SB's Settings page puts its own: the list items from 200, 452 every 120; Session's lines from
-- 736, 452, each header 100 high with a band of 100 above it but the first, each row 130; the pane at 2556, 452.
local function placed(x)
    for _,c in ipairs(x.props.canvas_slot.calls) do if c[1]=='SetPosition' then return c[2].X,c[2].Y end end
end
do
    local rows,n={},0
    for _,m in ipairs(made) do
        local x,y=placed(m.o)
        if m.kind=='tab' then
            assert(x==200 and y==452+n*120,'Item '..(n+1)..' at '..x..', '..y)
            n=n+1
        elseif m.kind~='detail' then rows[#rows+1]=x..','..y end
    end
    assert(n==10 and table.concat(rows,' ')=='736,452 736,552 736,682 736,812 736,1042 736,1142 736,1272 736,1402',
        table.concat(rows,' '))
    local x,y=placed(first_made('detail'))
    assert(x==2556 and y==452,'The pane at '..x..', '..y)
end
-- Each Blueprint text before AddChildToCanvas, each TextBlock and call after it.
local function order(x,before,after)
    local added=assert(at(canvas.name..':add '..x.name),x.name..' not added')
    for _,e in ipairs(before) do assert(at(x.name..e) and at(x.name..e)<added,x.name..e..' before the canvas') end
    for _,e in ipairs(after) do assert(at(x.name..e) and at(x.name..e)>added,x.name..e..' after the canvas') end
end
local tab,header,option=first_made('tab'),first_made('header'),first_made('option')
local rolling,slider,detail=first_made('rolling'),first_made('slider'),first_made('detail')
order(tab,{'.TabName'},{'.Text_side_name:SetText'})
order(header,{'.Category_Name'},{})
order(option,{'.Text_TitleValue'},{})
order(rolling,{'.Text_TitleValue','.Text_ItemValue'},{'.Text_Title:SetText','.Text_Btn_name:SetText'})
order(slider,{'.TextTitleValue','.CurrentPercent','.ItemTextRange'},
    {':UpdatePercentOffset','.Text_VolumeValue:SetText'})
order(detail,{},{'.Text_ItemName:SetText','.Text_Desc:SetText'})
assert(tab.props.TabName=='Session' and tab.props.Text_side_name.props.text=='Session')
assert(header.props.Category_Name=='Play online' and option.props.Text_TitleValue=='Host a session'
    and option.props.Text_ItemValue==nil,'Host a session keeps SB\'s own value word')
assert(rolling.props.Text_TitleValue=='Who can join' and rolling.props.Text_Btn_name.props.text=='Public',
    tostring(rolling.props.Text_TitleValue))
assert(slider.props.ItemTextRange.Min==2 and slider.props.ItemTextRange.Max==4 and slider.props.CurrentPercent==1
    and slider.props.Text_VolumeValue.props.text=='4','Max players at 4 of 2 to 4')
assert(tab.props.visibility==3 and option.props.visibility==3,'SB\'s parts never take the mouse')
-- Looks: the first item focused, the pane the category's word with no description and its media part collapsed.
assert(called(tab,'PlayFocusAnim')==1 and detail.props.Text_ItemName.props.text=='Session'
    and detail.props.Text_Desc.props.text=='')
assert(detail.props.Thumbnail.props.visibility==1 and called(detail.props.Thumbnail,'SetVisibility')==1,
    'The pane\'s Thumbnail collapsed once: no item has media')
-- Right: the item selected, Host a session focused, its words in the pane. Select asks first.
assert(page.nav('right')==nil)
local function part(title)
    local found
    for _,x in ipairs(made) do if x.kind=='option' and x.o.props.Text_TitleValue==title then found=x.o end end
    return found
end
local host=part('Host a session')
assert(called(tab,'StopFocusAnim')==1 and called(tab,'Select')==1,'The category selected')
assert(host.calls[#host.calls][1]=='EventNotification' and host.calls[#host.calls][2]=='StateFocus')
assert(detail.props.Text_ItemName.props.text=='Host a session' and detail.props.Text_Desc.props.text=='')
assert(page.nav('select',0)==nil and acts[1]=='confirm_host nil nil' and page.nav('back')==nil
    and page.nav('back')=='close')
assert(called(tab,'PlayFocusAnim')==2,'Back in the list: focused again')
-- Nothing made again while the rows stay: the same parts, looks on change only.
local parts=#made
page.nav('right'); page.nav('down'); page.nav('up')
assert(#made==parts,'Moving in the rows makes no part again')
-- A click: the row under the kit's pointer selected. On Find a session, its sub-page in the rows (the Sessions
-- screen's search asked, SB's focus sound, the cursor on Search); back: on Find a session again.
mouse={row_at(3)}
assert(page.click(1)==nil and #acts==1 and fs.calls[1]=='enter' and sounds[#sounds]=='tab'
    and detail.props.Text_ItemName.props.text=='Search',detail.props.Text_ItemName.props.text)
assert(page.nav('back')==nil and sounds[#sounds]=='tab')
local find=part('Find a session')
host=part('Host a session')
assert(find.calls[#find.calls][2]=='StateFocus' and called(host,'EventNotification')==0)
assert(detail.props.Text_ItemName.props.text=='Find a session')
mouse={row_at(2)} -- Slot 2: Host a session, which asks first: its question in the pane, nothing hosted yet.
assert(table.concat({page.click(2)},' ')=='' and #acts==2 and acts[2]=='confirm_host nil nil'
    and sounds[#sounds]=='confirm' and detail.props.Text_Desc.props.text==w.confirm_host,tostring(acts[2]))
mouse={row_at(1)}
assert(page.click()==nil and detail.props.Text_ItemName.props.text=='Host a session','A header takes no click')
mouse=nil
assert(page.click()==nil and detail.props.Text_ItemName.props.text=='Host a session','No pointer: nothing')
-- Another category: its rows made, the tab parts kept.
mouse={item_at(5)} -- The fifth list item: Controls.
local tabs,was=made_n('tab'),#made
assert(page.click()==nil and made_n('tab')==tabs and detail.props.Text_ItemName.props.text=='Controls')
-- Controls (4 headers, 13 rows): the lines that end inside SB's rows window (y 1900, above the key hints), its
-- keyboard rows then the controller header.
do
    local ends={}
    for i=was+1,#made do
        local y=select(2,placed(made[i].o))
        ends[#ends+1]=y+(made[i].kind=='header' and 100 or 130)
    end
    assert(#ends==10 and ends[1]==552 and ends[9]==1592 and ends[10]==1792,table.concat(ends,' '))
end
-- The mouse look: the first look notes only; the item the mouse moved onto takes the cursor; a resting mouse never.
page.show(true)
local function pane() return detail.props.Text_ItemName.props.text end
mouse={row_at(2)}
page.tick(40); assert(pane()=='Session','The first look moves nothing')
mouse={row_at(3)}
page.tick(40.05) -- The very next frame: the mouse answers at once, as SB's own menus do.
page.tick(40.1)
find=part('Find a session') -- The latest one: Session's rows were made again after Controls.
assert(pane()=='Find a session' and find.calls[#find.calls][2]=='StateFocus','Moved onto Find a session')
assert(sounds[#sounds]=='tab',"A row under the mouse: SB's Settings focus sound")
local n=#sounds
page.nav('up'); assert(pane()=='Host a session' and #sounds==n+1 and sounds[n+1]=='tab','The keys: the same sound')
page.tick(40.3); assert(pane()=='Host a session' and #sounds==n+1,'A resting mouse never moves the cursor')
-- A list item under the mouse is lit and sounds; its rows show at a click only, as in SB's Settings.
local function tab_part(name)
    for _,m in ipairs(made) do if m.kind=='tab' and m.o.props.TabName==name then return m.o end end
end
mouse={item_at(5)}
page.tick(40.4)
assert(pane()=='Host a session' and sounds[#sounds]=='wheel_move' and #sounds==n+2,
    "Lit, not shown, with the sound of SB's list items")
local controls,session=tab_part('Controls'),tab_part('Session')
local boxes=called(controls,'PlayFocusAnim')
assert(controls.calls[#controls.calls][1]=='Select' and session.calls[#session.calls][1]=='Select',
    'Under the mouse: white as the shown category, never the white box')
assert(page.click()==nil and pane()=='Controls' and sounds[#sounds]=='tab','A click shows its rows')
assert(called(controls,'PlayFocusAnim')==boxes+1,'The click puts the cursor on it: the white box')
mouse={item_at(1)} -- The cursor stays on Controls while the mouse lights Session.
page.tick(40.45)
assert(session.calls[#session.calls][1]=='Select' and called(controls,'PlayFocusAnim')==boxes+1
    and controls.calls[#controls.calls][1]=='PlayFocusAnim' and pane()=='Controls')
mouse={row_at(1)} -- Controls' first header: no item.
page.tick(40.5); assert(pane()=='Controls')
n=#sounds
mouse=nil
page.tick(40.6); assert(pane()=='Controls' and not page.off() and #sounds==n,'Off everything: no sound')
-- visibility(): SB's eight page widgets by name.
assert(page.visibility()=='WB_Equip_Set=Hidden WB_QuestJournal=Hidden WB_Map_Set=Hidden WB_Bag_Set=Hidden '
    ..'WB_NewSkill_Master=Hidden WB_Album_Set=Hidden WB_Manual_Set=Hidden WB_GameMenu_Setting=Collapsed',
    page.visibility())
-- Hidden: collapsed; nav and click do nothing.
page.show(false)
mouse={row_at(4)}
page.tick(50)
assert(not page.shown() and canvas.props.visibility==1 and page.nav('back')==nil and page.click()==nil)
-- forget(): no engine call; the next build makes a new canvas in the new master.
page.forget()
local m2,root2=master()
assert(page.build(m2) and #root2.props.children==1)

local function rows_shown() -- The headers' and rows' words shown, top down.
    local shown={}
    for _,x in ipairs(made) do
        local p=x.o.props
        if (x.kind=='header' or x.kind=='option' or x.kind=='rolling') and called(x.o,'RemoveFromParent')==0 then
            shown[#shown+1]={y=select(2,placed(x.o)),word=x.kind=='header' and 'H:'..p.Category_Name
                or p.Text_TitleValue..'='..tostring(p.Text_ItemValue)}
        end
    end
    table.sort(shown,function(a,b) return a.y<b.y end)
    local out={}
    for i,s in ipairs(shown) do out[i]=s.word end
    return table.concat(out,'|')
end
local function tabs_shown()
    local k=0
    for _,x in ipairs(made) do if x.kind=='tab' and called(x.o,'RemoveFromParent')==0 then k=k+1 end end
    return k
end
-- The rows act as SB's Settings rows: each press through the co-op menu's model for that row, then its act (the fake
-- above). Solo, Session.
do
    ctx={mode='none',values=Model.read(''),pages={PAGE}}
    page=new()
    page.build(master())
    page.show(true)
    local d=first_made('detail')
    local function pane() return d.props.Text_ItemName.props.text end
    local function desc() return d.props.Text_Desc.props.text end
    local function to(label)
        for _=1,40 do if pane()==label then return end page.nav('down',0) end
        error('no row '..label)
    end
    local function heard() return sounds[#sounds] end
    local function latest(kind,title) -- The newest part of kind made for that row.
        for i=#made,1,-1 do
            local x=made[i]
            local p=x.o.props
            if x.kind==kind and (p.Text_TitleValue==title or p.TextTitleValue==title) then return x.o end
        end
    end
    local function rolling(title) return latest('rolling',title).props.Text_Btn_name.props.text end
    page.nav('right',0)
    to('Who can join')
    -- Right: the next value written, SB's select cue, the part made again; Friends join without asking hides (Public
    -- and Invitation only) and the cursor stays on Who can join.
    page.nav('right',1)
    assert(acts[#acts]=='set who_can_join friends' and heard()=='change' and pane()=='Who can join'
        and rolling('Who can join')=='Friends only',tostring(acts[#acts]))
    assert(called(latest('rolling','Friends join without asking'),'RemoveFromParent')==1,'Friends join: hidden')
    page.nav('down',1); assert(pane()=='Players','Down from Who can join: Players, the hidden row skipped')
    page.nav('up',1)
    -- Left goes down and wraps as the co-op menu's list rows do; select is the next value.
    page.nav('left',2); page.nav('left',2)
    assert(table.concat(acts,'|',2)=='set who_can_join public|set who_can_join closed',table.concat(acts,'|'))
    page.nav('select',3); assert(acts[#acts]=='set who_can_join public' and rolling('Who can join')=='Public')
    -- Players (2 to 4, at 4): right at the end is refused with SB's refusal sound, no note; left steps down by 1.
    to('Players')
    local n=#acts
    page.nav('right',4)
    assert(#acts==n and heard()=='refuse' and desc()=='' and pane()=='Players','At its end: refused')
    page.nav('left',4)
    assert(acts[#acts]=='set max_players 3' and heard()=='change'
        and latest('slider','Players').props.CurrentPercent==0.5,'Made again at 3 of 2 to 4')
    -- A click on Who can join's value part: its left half down, its right half up; elsewhere on the row, select.
    local y=select(2,row_at(6)) -- Slot 6: Who can join (Friends join without asking under it while Public).
    mouse={1420,y}; page.click(5); assert(acts[#acts]=='set who_can_join closed' and pane()=='Who can join')
    mouse={2360,y}; page.click(5); assert(acts[#acts]=='set who_can_join public')
    mouse={820,y}; page.click(5); assert(acts[#acts]=='set who_can_join friends')
    mouse=nil
    -- A write the co-op menu refuses: SB's refusal sound, its note in the pane; a move clears the note.
    act_ok,act_note=false,'Not saved: x'
    page.nav('right',6)
    assert(acts[#acts]=='set who_can_join invitation' and heard()=='refuse' and desc()=='Not saved: x'
        and ctx.values.who_can_join=='friends','Refused: nothing changed')
    act_ok,act_note=true,nil
    page.nav('down',6); assert(desc()=='','A move clears the note')
    -- Left or right on Host a session or on Join with a code: nothing, no sound.
    n=#acts
    for _,label in ipairs({'Host a session','Join with a code'}) do
        to(label)
        local s=#sounds
        assert(page.nav('left',7)==nil and page.nav('right',7)==nil and #acts==n and #sounds==s,label)
    end
    -- Select on a row that needs the game world: 'away' and its id with SB's confirm cue, nothing run on the page.
    local function away(label,id)
        to(label)
        local a,b=page.nav('select',7)
        assert(a=='away' and b==id and #acts==n and heard()=='confirm',label..': '..tostring(a)..' '..tostring(b))
    end
    -- Host a session asks first (its question in the pane, SB's confirm cue, the pause menu stays), then hosts in
    -- place on a second Select within 3 s; a Select 4 s after the first asks again.
    to('Host a session')
    assert(page.nav('select',7)==nil and acts[#acts]=='confirm_host nil nil' and desc()==w.confirm_host
        and heard()=='confirm','Host a session asks first')
    assert(page.nav('select',8)==nil and acts[#acts]=='host nil nil' and heard()=='confirm','The second Select hosts')
    page.nav('select',10); page.nav('select',14)
    assert(table.concat(acts,'|',#acts-1)=='confirm_host nil nil|confirm_host nil nil' and desc()==w.confirm_host,
        'Past 3 s: asked again')
    n=#acts
    away('Join with a code','join_code')
    page.nav('back',15); to('Help'); page.nav('right',15)
    -- Guide opens in the rows: a header Guide, then a row a guide page with its title, SB's value word off; the list
    -- stays with Help in SB's select look; the pane the page's title and its body. Nothing is run or asked.
    to('Guide')
    assert(page.nav('select',15)==nil and #acts==n and heard()=='tab','Guide: a sub-page, nothing run')
    local want={'H:Guide'}
    for i,p in ipairs(gw.pages) do want[i+1]=p.title..'=' end
    assert(#gw.pages==9 and rows_shown()==table.concat(want,'|'),rows_shown())
    assert(tabs_shown()==10 and tab_part('Help').calls[#tab_part('Help').calls][1]=='Select','The list stays')
    assert(pane()==gw.pages[1].title and desc()==gw.pages[1].body,pane())
    page.nav('down',15); assert(pane()==gw.pages[2].title and desc()==gw.pages[2].body,'Down: the next page')
    local s=#sounds
    assert(page.nav('select',15)==nil and page.nav('right',15)==nil and #acts==n and #sounds==s,'A page: nothing')
    -- Back: on Guide again, the category's rows. A click on Guide opens it too; a click on a list item shows that
    -- category's rows, the sub-page gone.
    assert(page.nav('back',15)==nil and pane()=='Guide' and heard()=='tab' and rows_shown()
        =='H:Help|Guide=nil|Write a bug report=nil',rows_shown())
    mouse={row_at(2,{1})}
    assert(page.click(15)==nil and pane()==gw.pages[1].title and heard()=='tab' and #acts==n,'A click opens it')
    mouse={item_at(1)}
    assert(page.click(15)==nil and pane()=='Session' and rows_shown():find('^H:Play online|Host a session=nil'),
        rows_shown())
    mouse=nil
    to('Help'); page.nav('right',15)
    -- Write a bug report runs in place: the pause menu stays.
    to('Write a bug report')
    assert(page.nav('select',15)==nil and acts[#acts]=='report nil nil' and heard()=='confirm','The report in place')
    n=#acts
    -- No Test tools in the list, though the ctx has a module page: F5 keeps them.
    for _,x in ipairs(made) do assert(not (x.kind=='tab' and x.o.props.TabName=='Test tools'),'A Test tools item') end
    -- The Online tab written off on the page: 'close', the pause menu closes as Back closes it.
    page.nav('back',8)
    to('Display')
    page.nav('right',8)
    to('Online tab in the pause menu')
    assert(page.nav('right',8)=='close' and acts[#acts]=='set pause_tab off')
    ctx.values.pause_tab='on'
    -- Hosting: a row the co-op menu does not show now (no code) is refused and goes at the redraw; the cursor on the
    -- category's first row.
    ctx={mode='host',chat=true,code='0CS-CBMH',stranger={id='9',name='S'},values=Model.read(''),pages={PAGE},
        members={{id='7',name='A',linked=true,muted=false},{id='8',name='B',linked=true,muted=false}}}
    page.show(true)
    page.nav('right',9)
    to('Copy my code')
    n=#acts
    ctx.code=nil
    page.nav('select',9)
    assert(#acts==n and sounds[#sounds-1]=='refuse' and heard()=='tab' and pane()=='Invite a friend (Steam)',pane())
    for _=1,6 do page.nav('down',9); assert(pane()~='Copy my code','Copy my code went') end
    ctx.code='0CS-CBMH'
    -- Leave asks twice within 3 s (the co-op menu's model); a move in between forgets the first Select.
    to('Leave the session')
    page.nav('select',20); page.nav('down',20); page.nav('up',20); page.nav('select',21)
    assert(table.concat(acts,'|',n+1)=='confirm_leave nil nil|confirm_leave nil nil',table.concat(acts,'|',n+1))
    page.nav('select',22); assert(acts[#acts]=='leave nil nil' and heard()=='confirm','The second Select leaves')
    -- The 3 s window (model.lua's): a second Select 4 s later asks again, the question in the pane.
    page.nav('select',30); page.nav('select',34)
    assert(table.concat(acts,'|',#acts-1)=='confirm_leave nil nil|confirm_leave nil nil' and desc()==w.confirm_leave
        and heard()=='confirm','Past 3 s: asked again')
    -- The mouse look leaving the row and coming back forgets the first Select (slot 5 Leave, slot 7 Who can join).
    local leave,who={row_at(5,HOSTING_HEADS)},{row_at(7,HOSTING_HEADS)}
    mouse=leave; page.tick(39.5)
    page.nav('select',40); mouse=who; page.tick(40.5); mouse=leave; page.tick(41); page.nav('select',41)
    assert(table.concat(acts,'|',#acts-1)=='confirm_leave nil nil|confirm_leave nil nil','Asked again after the mouse')
    -- So does a click on another row: Leave, Who can join's name (its next value), Leave again within 3 s.
    page.click(45); mouse=who; page.click(45); mouse=leave; page.click(46)
    assert(table.concat(acts,'|',#acts-2)=='confirm_leave nil nil|set who_can_join friends|confirm_leave nil nil',
        table.concat(acts,'|',#acts-2))
    mouse=nil
    -- Copy my code runs in place with SB's confirm cue; a run the co-op menu refuses: the beep, its why in the pane.
    page.nav('up',50); page.nav('up',50)
    page.nav('select',50); assert(pane()=='Copy my code' and acts[#acts]=='copy nil nil' and heard()=='confirm')
    act_ok,act_note=false,'x'
    page.nav('select',51); assert(acts[#acts]=='copy nil nil' and heard()=='refuse' and desc()=='x','Refused')
    act_ok,act_note=true,nil
    -- Invite runs in place (Steam's overlay is no screen of ours); Chat still closes the pause menu first.
    to('Invite a friend (Steam)')
    assert(page.nav('select',52)==nil and acts[#acts]=='invite nil nil' and heard()=='confirm','Invite in place')
    n=#acts
    away('Chat','chat')
    -- A mute row: right mutes her (its select); the cursor stays on her row when the row above it goes.
    page.nav('back',23)
    to('Players')
    page.nav('right',23); page.nav('down',23)
    assert(pane()=='Mute B')
    ctx.members={{id='8',name='B',linked=true,muted=false}}
    page.nav('right',24)
    assert(acts[#acts]=='mute 8 false' and heard()=='change' and pane()=='Mute B',pane())
    n=#acts
    page.nav('select',24); assert(#acts==n+1 and acts[#acts]=='mute 8 false' and heard()=='change','Select mutes too')
    -- Remove S asks first in the co-op menu's words, then removes on a second Select within 3 s.
    page.nav('down',25); page.nav('select',25)
    assert(pane()=='Remove S' and acts[#acts]=='confirm_remove nil nil'
        and desc()=='Select again within 3 s to remove and block S.' and heard()=='confirm',desc())
    page.nav('select',26); assert(acts[#acts]=='remove nil nil' and heard()=='confirm')
    -- A key row: select waits for the next key (Press a key in the row, the capture words in the pane, SB's confirm
    -- cue); the keys move nothing meanwhile. Each key goes through the co-op menu's bind: refused, the wait goes on
    -- with its note; taken, the row shows it. Enter (select) asks for the default; back stops the wait with no bind.
    page.nav('back',30)
    to('Controls')
    page.nav('right',30)
    assert(pane()=='Open this menu' and page.capture('F6')==false,'No wait: a key is not the page\'s')
    page.nav('select',30)
    assert(latest('option','Open this menu').props.Text_ItemValue=='Press a key' and desc()==w.capture
        and heard()=='confirm',tostring(latest('option','Open this menu').props.Text_ItemValue))
    page.nav('down',30); page.nav('left',30); page.nav('right',30)
    assert(pane()=='Open this menu' and desc()==w.capture and #binds==0,'Waiting: the other words do nothing')
    mouse={row_at(3,CONTROLS_HEADS)}; page.tick(30); mouse={row_at(4,CONTROLS_HEADS)}; page.tick(31)
    assert(page.click(31)==nil and pane()=='Open this menu','Waiting: the mouse moves nothing')
    mouse=nil
    bound={false,nil,'Show the status already uses this key.'}
    assert(page.capture('F6')==true and binds[1]=='menu_key F6' and heard()=='refuse'
        and desc()=='Show the status already uses this key.'
        and latest('option','Open this menu').props.Text_ItemValue=='Press a key','Refused: still waiting')
    bound={true,true,nil}
    assert(page.capture('F7')==true and heard()=='change' and desc()==''
        and latest('option','Open this menu').props.Text_ItemValue=='F7','Taken: the row shows it')
    assert(page.capture('F8')==false and #binds==2,'Not waiting any more')
    page.nav('select',32); page.nav('select',32)
    assert(binds[3]=='menu_key Enter' and ctx.values.menu_key=='Enter','Select while waiting: the default asked')
    page.nav('select',33); page.nav('back',33)
    assert(#binds==3 and heard()=='back' and desc()==''
        and latest('option','Open this menu').props.Text_ItemValue=='Enter','Back: the wait stopped, no bind')
    -- Reset all keys asks first, then resets on a second Select within 3 s.
    to('Reset all keys')
    page.nav('select',60); assert(acts[#acts]=='confirm_reset_keys nil nil' and desc()==w.confirm_reset_keys)
    page.nav('select',61); assert(acts[#acts]=='reset_keys nil nil' and heard()=='confirm')
    page.nav('back',33)
    to('Session'); page.nav('right',34); to('Who can join')
    -- An act that raises: the page off with one line.
    act_raise='no act today'
    page.nav('right',25)
    assert(page.off() and not page.shown() and lines_with('online page: off until the mod reloads: ')==1
        and logged('no act today'),table.concat(logs,'|'))
    ctx=SOLO
end

-- The page follows the online session's state: every Page.REFRESH s while it shows (tick) it reads the ctx again, the
-- list and the rows drawn for it, the cursor kept on its row or put on its category's first row when the row went,
-- with no sound and no act; a first Select stays while its row stays; a read that raises turns the page off.
do
    ctx={mode='none',values=Model.read(''),pages={PAGE}}
    page=new()
    page.build(master())
    page.show(true)
    local d=first_made('detail')
    local function pane() return d.props.Text_ItemName.props.text end
    local function desc() return d.props.Text_Desc.props.text end
    local function to(label)
        for _=1,40 do if pane()==label then return end page.nav('down',0) end
        error('no row '..label)
    end
    local function list() -- The list items shown, top down.
        local shown={}
        for _,x in ipairs(made) do
            if x.kind=='tab' and called(x.o,'RemoveFromParent')==0 then
                shown[#shown+1]={y=select(2,placed(x.o)),name=x.o.props.TabName}
            end
        end
        table.sort(shown,function(a,b) return a.y<b.y end)
        local names={}
        for i,t in ipairs(shown) do names[i]=t.name end
        return names
    end
    page.nav('right',0); to('Who can join')
    local s,a=#sounds,#acts
    -- An online session begins: Players shows second, the cursor stays on Who can join.
    ctx.mode,ctx.code,ctx.chat,ctx.members='host','0CS-CBMH',true,{{id='7',name='A',linked=true,muted=false}}
    page.tick(100)
    assert(#list()==11 and list()[2]=='Players' and pane()=='Who can join' and #sounds==s and #acts==a,
        table.concat(list(),' ')..' / '..pane())
    -- The next change shows at the next read only.
    ctx.members={}
    page.tick(100.1); assert(#list()==11 and Page.REFRESH==0.25,'Read again before REFRESH s')
    page.tick(100.25); assert(#list()==10 and pane()=='Who can join','Read again: no other player, no Players')
    -- The cursor's row goes (Host a session once the online session began): the category's first row, no note.
    ctx.mode,ctx.code,ctx.members='none',nil,nil
    page.tick(101); to('Host a session')
    page.nav('select',101); assert(desc()==w.confirm_host)
    s=#sounds
    ctx.mode,ctx.code='host','0CS-CBMH'
    page.tick(102)
    assert(pane()=='Invite a friend (Steam)' and desc()=='' and #sounds==s,pane()..' / '..desc())
    -- A first Select of Leave survives a read that changes nothing: the second Select within 3 s leaves.
    to('Leave the session')
    page.nav('select',110); page.tick(110.5); page.nav('select',111)
    assert(table.concat(acts,'|',#acts-1)=='confirm_leave nil nil|leave nil nil',table.concat(acts,'|',#acts-1))
    -- A read that raises: the page off with one line.
    ctx.members=5
    page.tick(120)
    assert(page.off() and not page.shown() and lines_with('online page: off until the mod reloads: ')==1,
        table.concat(logs,'|'))
    ctx=SOLO
end

-- Find a session in the rows through the Sessions screen's own functions (fs): Search with the tab, Refresh, a header
-- naming the tab over the sessions with their values; the pane on Search the status and our version, on a session its
-- name and details. Right on Search: the other tab. Refresh asked, then refused inside the gap with the status in the
-- pane. Select on a session: its join, 'close'. Read again each REFRESH s: a status in the header, the cursor on
-- Search when its row went; an online session begun or the sessions off: no sub-page, the cursor on Session's first
-- row. Back: on Find a session. The sessions off: Select refused with one line, no sub-page.
do
    ctx={mode='none',values=Model.read(''),pages={PAGE}}
    page=new()
    page.build(master())
    page.show(true)
    local d=first_made('detail')
    local function pane() return d.props.Text_ItemName.props.text end
    local function desc() return d.props.Text_Desc.props.text end
    local function heard() return sounds[#sounds] end
    local function to(label)
        for _=1,40 do if pane()==label then return end page.nav('down',11) end
        error('no row '..label)
    end
    fs.texts={tab='Public',refresh='Refresh',status='',footer='Our version',rows={
        {lobby='11',name='Host1',value='Xion · 1/2 · 41 ms',details='Xion\n1/2 · 41 ms'},
        {lobby='12',name='Host2',value='f01 · 1/2 · 42 ms',details='f01\nSteam friend'}}}
    page.nav('right',0); page.nav('down',0)
    assert(pane()=='Find a session')
    assert(page.nav('select',1)==nil and table.concat(fs.calls,'|')=='enter' and #acts==0 and heard()=='tab')
    assert(rows_shown()=='H:Find a session|Search=Public|Refresh=nil|H:Public|Host1=Xion · 1/2 · 41 ms'
        ..'|Host2=f01 · 1/2 · 42 ms',rows_shown())
    assert(pane()=='Search' and desc()=='Our version' and tabs_shown()==10,pane()..' / '..desc())
    page.nav('down',1); page.nav('down',1)
    assert(pane()=='Host1' and desc()=='Xion\n1/2 · 41 ms','A session: its details in the pane')
    -- Right on Search: the other tab (the screen's), SB's change cue.
    page.nav('up',2); page.nav('up',2)
    assert(pane()=='Search' and page.nav('right',2)==nil and fs.calls[2]=='ask tab' and heard()=='change')
    assert(page.nav('left',2)==nil and fs.calls[3]=='ask tab','Left too: two tabs')
    -- Refresh: asked with SB's confirm cue; refused inside the gap, the status in the pane.
    page.nav('down',3)
    assert(pane()=='Refresh' and page.nav('select',3)==nil and fs.calls[4]=='ask refresh' and heard()=='confirm')
    assert(page.nav('left',3)==nil and #fs.calls==4,'Left on Refresh: nothing')
    fs.ok,fs.texts.status=false,'You can search again in 4 s.'
    assert(page.nav('select',3)==nil and fs.calls[5]=='ask refresh' and heard()=='refuse'
        and desc()=='You can search again in 4 s.\nOur version' and pane()=='Refresh',desc())
    -- Select on the second session: its join through the screen, 'close' (the join goes on over the game).
    fs.ok=true
    page.nav('down',4); page.nav('down',4)
    assert(pane()=='Host2' and page.nav('select',4)=='close' and fs.calls[6]=='ask join 2' and heard()=='confirm'
        and #acts==0,tostring(fs.calls[6]))
    fs.ok=false
    page.nav('up',4)
    assert(page.nav('select',4)==nil and fs.calls[7]=='ask join 1' and heard()=='refuse','A join refused')
    fs.ok=true
    -- The list read again: no row left, the status in the header, the cursor on Search; no sound, no ask.
    local s,c=#sounds,#fs.calls
    fs.texts.rows,fs.texts.status={},'No open session.'
    page.tick(10)
    assert(rows_shown()=='H:Find a session|Search=Public|Refresh=nil|H:No open session.' and pane()=='Search'
        and #sounds==s and #fs.calls==c,rows_shown()..' / '..pane())
    -- An online session begun: Find a session shows no more, the cursor on Session's first row.
    ctx.mode='guest'
    page.tick(10.5)
    assert(pane()=='Leave the session' and not rows_shown():find('Search',1,true),rows_shown())
    ctx.mode='none'
    page.tick(11)
    to('Find a session'); page.nav('select',11); assert(pane()=='Search' and fs.calls[#fs.calls]=='enter')
    -- The sessions off while it shows: no sub-page at the next read.
    fs.gone=true
    page.tick(12)
    assert(pane()=='Host a session' and not rows_shown():find('Search',1,true),pane())
    fs.gone=false
    -- Back: on Find a session with SB's focus sound.
    to('Find a session'); page.nav('select',13); assert(pane()=='Search')
    assert(page.nav('back',13)==nil and pane()=='Find a session' and heard()=='tab'
        and rows_shown():find('^H:Play online|Host a session=nil|Find a session=nil'),rows_shown())
    -- The sessions off: Select refused with one line, no sub-page, nothing asked.
    fs.gone=true
    c=#fs.calls
    assert(page.nav('select',14)==nil and heard()=='refuse' and pane()=='Find a session' and #fs.calls==c
        and lines_with('online page: find not shown: the online session module is off')==1,table.concat(logs,'|'))
    assert(not page.off() and page.shown())
    ctx=SOLO
end

-- A refused look: logged once a kind. A pane with no Thumbnail: one line, the page shown.
do
    page=new()
    local m3=master()
    page.build(m3)
    local saved=objects['/Script/UMG.Default__WidgetBlueprintLibrary'].props.Create
    objects['/Script/UMG.Default__WidgetBlueprintLibrary'].props.Create=function(...)
        local x=saved(...)
        if x.name:find('^tab') then x.props.PlayFocusAnim=function() error('not callable') end end
        if x.name:find('^detail') then x.props.Thumbnail=nil end
        return x
    end
    page.show(true)
    page.nav('down'); page.nav('up')
    assert(lines_with('online page: tab look refused: not callable')==1 and page.shown() and not page.off(),
        table.concat(logs,'|'))
    assert(lines_with('online page: detail media refused: no Thumbnail')==1,table.concat(logs,'|'))
    objects['/Script/UMG.Default__WidgetBlueprintLibrary'].props.Create=saved
end

-- A class whose Create raises: the kit's TextBlocks and Borders in its place, one line; the other kinds SB's.
page=new()
raising.rolling=true
local m4=master()
page.build(m4)
page.show(true)
assert(lines_with('WB_Setting_Rolling_Slot_C not built (')==1
    and logged('Create refused rolling); the kit\'s drawing in its place') and made_n('rolling')==0
    and made_n('option')==3 and lines_with('built from SB\'s class')==5,
    table.concat(logs,'|'))
local texts={}
for _,c in ipairs(constructed) do texts[c.umg]=(texts[c.umg] or 0)+1 end
assert(texts.TextBlock==4 and texts.Border==4,'Two rows drawn: a label, a value, a back and a bar each')
local public=false
for _,child in ipairs(m4.props.WidgetTree.props.RootWidget.props.children[1].props.children) do
    if child.props.text=='Public' or child.props.text=='Who can join' then public=true end
end
assert(public and logged(': 17 SB parts, 2 drawn by the kit'),table.concat(logs,'|'))
page.nav('down')
assert(page.shown() and not page.off(),'The kit\'s drawing moves with the cursor')

-- A canvas that cannot be made: off for the Lua load with one line; nothing shows or is made later.
page=new()
no_canvas=true
local m5,root5=master()
local ok,why=page.build(m5)
assert(ok==false and why=='no CanvasPanel made' and page.off() and #root5.props.children==0)
assert(#logs==1 and logs[1]=='online page: off until the mod reloads: no CanvasPanel made; the Online tab opens the '
    ..'co-op menu as before',logs[1])
page.show(true)
assert(not page.shown() and #made==0 and page.nav('down')==nil and page.click()==nil and page.build(master())==false)
no_canvas=false
print('online_page_test ok')
