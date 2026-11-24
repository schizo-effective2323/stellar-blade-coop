-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The pause menu's Online page (ui/kit/online_page.lua) over fakes. Pure: each row's part kind; its words and value as
-- the co-op menu draws them; the cursor over ui/kit/online_model.lua's categories in solo and while hosting (the list
-- wraps, right and select land on Open the co-op menu, the rows skip headers and wrap, select there opens the co-op
-- menu, select elsewhere and left do nothing, back goes to the list, back in the list closes, a long category keeps
-- the cursor inside the 12 slots). Engine: the build adds one collapsed canvas last to the master's root; each of the
-- six SB classes says once that it was built; each part's Blueprint texts are set before it enters the canvas and its
-- TextBlocks and calls after; a class whose Create raises is drawn with a TextBlock and a Border in its place, one line
-- for it, the others SB's; show makes the canvas SelfHitTestInvisible with the focused item's PlayFocusAnim and the
-- category's word in the pane; right gives Select, StateFocus on Open the co-op menu and its words in the pane; a click
-- moves the cursor to the hovered row, on Open the co-op menu it answers 'open_menu'; a refused look is logged once; a
-- canvas that cannot be made turns the page off with one line; visibility() names SB's eight pages with their state.
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
for _,row in ipairs({main('host'),O.OPEN_MENU,opt('menu_key'),{id='page',page=PAGE},opt('reset_keys')}) do
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
assert(Page.label(w,gw,O.OPEN_MENU,CTX)=='Open the co-op menu' and Page.value(w,O.OPEN_MENU,CTX)==nil)
assert(Page.value(w,opt('menu_key'),CTX)=='F5' and Page.value(w,opt('who_can_join'),CTX)=='Public')
assert(Page.label(w,gw,{id='page',page=PAGE},CTX)=='Tools')

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
    Page.move(cur,cats,'right'); assert(not cur.list and id_at(cats,cur)=='open_menu','Right: Open the co-op menu')
    assert(Page.move(cur,cats,'select')=='open_menu','Select on it opens the co-op menu')
    Page.move(cur,cats,'back'); assert(cur.list,'Back: the list')
    Page.move(cur,cats,'select'); assert(not cur.list and id_at(cats,cur)=='open_menu','Select: the same')
    Page.move(cur,cats,'down')
    assert(id_at(cats,cur)==(cats==solo and 'host' or 'invite'),'Down skips the play header: '..id_at(cats,cur))
    assert(Page.move(cur,cats,'select')==nil and Page.move(cur,cats,'left')==nil and not cur.list,
        'Select on another row and left do nothing')
    Page.move(cur,cats,'up'); Page.move(cur,cats,'up')
    assert(id_at(cats,cur)=='max_players','Up from the first row wraps to the last')
    Page.move(cur,cats,'back')
    assert(Page.move(cur,cats,'back')=='close' and cur.list,'Back in the list closes the pause menu')
end
assert(Page.move(Page.cursor(),{},'back')=='close' and Page.move(Page.cursor(),{},'down')==nil,'No category')
-- A long category (Controls: 4 headers, 13 rows) keeps the cursor inside the 12 slots, the first header shown at top.
do
    local cur,at=Page.cursor(),nil
    for i,cat in ipairs(solo) do if cat.id=='controls' then at=i end end
    for _=1,at-1 do Page.move(cur,solo,'down') end
    Page.move(cur,solo,'right')
    local moved=false
    for _=1,20 do
        Page.move(cur,solo,'down')
        assert(cur.row>cur.top and cur.row<=cur.top+Page.ROWS,cur.row..' '..cur.top)
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
                return fake(name..' slot')
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
    detail={'Text_ItemName','Text_Desc'}}
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
local ctx=SOLO
local function new()
    events,logs,made,constructed,raising,no_canvas={},{},{},{},{},false
    return Page.new({log=function(line) logs[#logs+1]=line end,words=function() return w end,
        guide_words=function() return gw end,ctx=function() return ctx end,theme=THEME})
end
local function first_made(kind) for _,m in ipairs(made) do if m.kind==kind then return m.o end end end
local function made_n(kind)
    local n=0
    for _,m in ipairs(made) do if m.kind==kind then n=n+1 end end
    return n
end

-- The build: one canvas, collapsed, added last to the master's root; its 12 list and 12 row hit boxes; no part yet.
local page=new()
local m,root=master()
assert(page.build(m)==true and not page.off() and not page.shown())
local canvas=root.props.children[1]
assert(#root.props.children==1 and canvas.name:find('^CanvasPanel') and canvas.props.visibility==1,'A collapsed canvas')
assert(constructed[1].outer==m.props.WidgetTree,'Made in the master\'s WidgetTree')
assert(#canvas.props.children==24 and #made==0,'The hit boxes, no part before the show')
assert(page.build(m)==true and #root.props.children==1,'The same master: built once')
-- Show: SelfHitTestInvisible; solo's Session drawn from SB's six classes, each said once; the first item focused.
page.show(true)
assert(page.shown() and canvas.props.visibility==4,'Shown, hit tests to its children only')
assert(made_n('tab')==8 and made_n('header')==3 and made_n('option')==4 and made_n('rolling')==2
    and made_n('slider')==1 and made_n('detail')==1,'Solo\'s Session: '..#made..' parts')
for _,kind in ipairs(Page.KINDS) do
    assert(lines_with(Parts.CLASS[kind]:match('[^.]+$')..' built from SB\'s class')==1,kind)
end
assert(logged('online page: built in ') and logged(': 19 SB parts, 0 drawn by the kit'),table.concat(logs,'|'))
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
assert(header.props.Category_Name=='Co-op menu' and option.props.Text_TitleValue=='Open the co-op menu'
    and option.props.Text_ItemValue==nil,'Open the co-op menu keeps SB\'s own value word')
assert(rolling.props.Text_TitleValue=='Who can join' and rolling.props.Text_Btn_name.props.text=='Public',
    tostring(rolling.props.Text_TitleValue))
assert(slider.props.ItemTextRange.Min==2 and slider.props.ItemTextRange.Max==4 and slider.props.CurrentPercent==1
    and slider.props.Text_VolumeValue.props.text=='4','Max players at 4 of 2 to 4')
assert(tab.props.visibility==3 and option.props.visibility==3,'SB\'s parts never take the mouse')
-- Looks: the first item focused, the pane the category's word.
assert(called(tab,'PlayFocusAnim')==1 and detail.props.Text_ItemName.props.text=='Session'
    and detail.props.Text_Desc.props.text=='')
-- Right: the item selected, Open the co-op menu focused, its words in the pane.
assert(page.nav('right')==nil)
local open_menu
for _,x in ipairs(made) do
    if x.kind=='option' and x.o.props.Text_TitleValue=='Open the co-op menu' then open_menu=x.o end
end
assert(called(tab,'StopFocusAnim')==1 and called(tab,'Select')==1,'The category selected')
assert(open_menu.calls[#open_menu.calls][1]=='EventNotification' and open_menu.calls[#open_menu.calls][2]=='StateFocus')
assert(detail.props.Text_ItemName.props.text=='Open the co-op menu' and detail.props.Text_Desc.props.text=='')
assert(page.nav('select')=='open_menu' and page.nav('back')==nil and page.nav('back')=='close')
assert(called(tab,'PlayFocusAnim')==2,'Back in the list: focused again')
-- Nothing made again while the rows stay: the same parts, looks on change only.
local parts=#made
page.nav('right'); page.nav('down'); page.nav('up')
assert(#made==parts,'Moving in the rows makes no part again')
-- A click: the row under the mouse takes the cursor; on Open the co-op menu it answers open_menu.
local function hit_row(i) return canvas.props.children[12+i] end
hit_row(4).props.hovered=true -- Slot 4: Host a session.
assert(page.click()==nil)
local host
for _,x in ipairs(made) do if x.kind=='option' and x.o.props.Text_TitleValue=='Host a session' then host=x.o end end
assert(host.calls[#host.calls][2]=='StateFocus' and open_menu.calls[#open_menu.calls][2]=='StateNormal')
assert(detail.props.Text_ItemName.props.text=='Host a session')
hit_row(4).props.hovered=false; hit_row(2).props.hovered=true
assert(page.click()=='open_menu','A click on Open the co-op menu')
hit_row(2).props.hovered=false
assert(hit_row(1).props.visibility==1 and hit_row(2).props.visibility==0,'No hit box over a header')
-- Another category: its rows made, the tab parts kept.
canvas.props.children[2].props.hovered=true -- The second list item: Controls.
local tabs=made_n('tab')
assert(page.click()==nil and made_n('tab')==tabs and detail.props.Text_ItemName.props.text=='Controls')
canvas.props.children[2].props.hovered=false
-- visibility(): SB's eight page widgets by name.
assert(page.visibility()=='WB_Equip_Set=Hidden WB_QuestJournal=Hidden WB_Map_Set=Hidden WB_Bag_Set=Hidden '
    ..'WB_NewSkill_Master=Hidden WB_Album_Set=Hidden WB_Manual_Set=Hidden WB_GameMenu_Setting=Collapsed',
    page.visibility())
-- Hidden: collapsed; nav and click do nothing.
page.show(false)
assert(not page.shown() and canvas.props.visibility==1 and page.nav('back')==nil and page.click()==nil)
-- forget(): no engine call; the next build makes a new canvas in the new master.
page.forget()
local m2,root2=master()
assert(page.build(m2) and #root2.props.children==1)

-- A refused look: logged once a kind.
do
    page=new()
    local m3=master()
    page.build(m3)
    local saved=objects['/Script/UMG.Default__WidgetBlueprintLibrary'].props.Create
    objects['/Script/UMG.Default__WidgetBlueprintLibrary'].props.Create=function(...)
        local x=saved(...)
        if x.name:find('^tab') then x.props.PlayFocusAnim=function() error('not callable') end end
        return x
    end
    page.show(true)
    page.nav('down'); page.nav('up')
    assert(lines_with('online page: tab look refused: not callable')==1 and page.shown() and not page.off(),
        table.concat(logs,'|'))
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
    and made_n('option')==4 and lines_with('built from SB\'s class')==5,
    table.concat(logs,'|'))
local texts={}
for _,c in ipairs(constructed) do texts[c.umg]=(texts[c.umg] or 0)+1 end
assert(texts.TextBlock==4 and texts.Border==24+4,'Two rows drawn: a label, a value, a back and a bar each')
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
