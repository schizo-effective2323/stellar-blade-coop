-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Online page's arrangement (ui/kit/online_model.lua): its categories in the solo state and in an online session,
-- each with its sections and the rows visible now. Open the co-op menu comes first in Session in both states, alone in
-- its section. Every row of today's main page and Options is placed once or left out with a reason. Hidden rows, empty
-- sections and empty categories drop. The order stays the same from call to call. Only ui/kit/online_page.lua
-- requires it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local O=require('ui.kit.online_model')
local Model=require('ui.kit.model')

local function name(row)
    return row.member and 'mute:'..row.member or row.page and 'page:'..row.n or row.id or row.key
end
-- One string per category: id(section:row row|section:row).
local function dump(cats)
    local out={}
    for _,cat in ipairs(cats) do
        local secs={}
        for _,sec in ipairs(cat.sections) do
            local rows={}
            for _,row in ipairs(sec.rows) do rows[#rows+1]=name(row) end
            secs[#secs+1]=sec.id..':'..table.concat(rows,' ')
        end
        out[#out+1]=cat.id..'('..table.concat(secs,'|')..')'
    end
    return out
end
local function ids(cats)
    local out={}
    for _,cat in ipairs(cats) do out[#out+1]=cat.id end
    return table.concat(out,' ')
end
local function same(got,want,what)
    for i=1,math.max(#got,#want) do
        assert(got[i]==want[i],(what or '')..' #'..i..'\n got: '..tostring(got[i])..'\nwant: '..tostring(want[i]))
    end
end
local function find(cats,cat_id,sec_id)
    for _,cat in ipairs(cats) do
        if cat.id==cat_id then
            for _,sec in ipairs(cat.sections) do
                if sec.id==sec_id then
                    local out={}
                    for _,row in ipairs(sec.rows) do out[#out+1]=name(row) end
                    return table.concat(out,' ')
                end
            end
        end
    end
end

local VALUES=Model.read('') -- Every setting at its default: who_can_join=public, so Friends join without asking shows.
local PAGE={title=function() return 'Tools' end,rows=function() return {} end}
local PAGES={PAGE,{title=function() return 'Viewer' end,rows=function() return {} end}}
local SOLO={mode='none',values=VALUES,pages=PAGES}
local NIL={} -- In hosting's extra: that field left out.
local function hosting(extra)
    local ctx={mode='host',chat=true,code='0CS-CBMH',stranger={id='9',name='S'},values=VALUES,pages=PAGES,
        members={{id='7',name='A',linked=true,muted=false},{id='8',name='B',linked=true,muted=true}}}
    for k,v in pairs(extra or {}) do if v==NIL then ctx[k]=nil else ctx[k]=v end end
    return ctx
end

-- The state: an online session while we host or join, else solo (no session, or before Steam).
assert(O.state({mode='none'})=='solo' and O.state({})=='solo')
assert(O.state({mode='host'})=='session' and O.state({mode='guest'})=='session')

-- The two states' category lists, in the approved order.
local page=O.new()
local got=ids(page.categories(SOLO))
assert(got=='session world combat modes controls display others photo saves help tools',got)
assert(not got:find('players',1,true),'Solo: no players category, its rows are the online session\'s')
got=ids(page.categories(hosting()))
assert(got=='session players world combat modes controls display others photo saves help tools',got)
assert(ids(page.categories(hosting({mode='guest'})))==got,'A guest sees the same categories')

-- Each category's sections and rows with every row shown.
local BOTH={
    'controls(keyboard:menu_key status_key leave_key follow_key race_key bike_key gun_key emote_key'
        ..'|controller:emote_pad|features:bike bike_pose gun_mode|all:reset_keys)',
    'display(interface:status_overlay ui_scale ui_language ui_sounds pause_tab hide_popups|names:name_tag'
        ..'|sky:daynight)',
    'others(look:partner_bar partner_arrow partner_card card_details cloth dyes effects drone faces|sound:sounds'
        ..'|motion:collide send_rate|chat:chat)',
    'photo(photo:photo_sync photo_freeze_max photo_ghost photo_name_tag photo_pause)',
    'saves(saves:auto_coop_save)',
    'help(help:guide report)',
    'tools(tools:page:1 page:2)',
}
-- Shared world, Combat and Game modes in both states: a host sets her rules before she hosts.
local RULES={
    'world(sharing:shared_enemies same_place same_spawns bosses shared_quests shared_world shared_story cutscene_wait'
        ..'|travel:follow_host)',
    'combat(difficulty:enemy_hp_scale enemy_balance_scale boss_hp_scale enemy_extra'
        ..'|rules:aggro boss_finish kill_credit hit_reactions stagger_resist revive spectate)',
    'modes(modes:scoreattack fishing race_match photohunt)',
}
local want={'session(menu:open_menu|play:host find join_code|hosting:who_can_join friends_ask max_players)'}
for _,line in ipairs(RULES) do want[#want+1]=line end
for _,line in ipairs(BOTH) do want[#want+1]=line end
same(dump(page.categories(SOLO)),want,'solo')
want={
    'session(menu:open_menu|current:invite copy chat leave|hosting:who_can_join friends_ask max_players)',
    'players(members:mute:7 mute:8 remove)',
}
for _,line in ipairs(RULES) do want[#want+1]=line end
for _,line in ipairs(BOTH) do want[#want+1]=line end
same(dump(page.categories(hosting())),want,'online session')

-- Every row of today's main page and Options is placed once, or left out with a reason. Nothing else is placed but
-- the mute rows' place.
local placed={}
for _,cat in ipairs(O.CATEGORIES) do
    assert(type(cat.id)=='string' and next(cat.states),cat.id)
    for _,sec in ipairs(cat.sections) do
        assert(type(sec.id)=='string' and #sec.rows>0,cat.id)
        for _,row in ipairs(sec.rows) do placed[row]=(placed[row] or 0)+1 end
    end
end
local today={[O.MUTES]=true,[O.OPEN_MENU]=true}
local left={}
for _,list in ipairs({Model.MAIN,Model.OPTIONS}) do
    for _,row in ipairs(list) do
        if not row.head then
            local what=row.pages and 'pages' or row.id or row.key
            today[row]=true
            if O.LEFT_OUT[row] then
                assert(not placed[row],what..' is placed and left out')
                assert(type(O.LEFT_OUT[row])=='string' and #O.LEFT_OUT[row]>0,what..' is left out with no reason')
                left[#left+1]=what
            else
                assert(placed[row]==1,what..' is placed '..(placed[row] or 0)..' times')
            end
        end
    end
end
assert(placed[O.MUTES]==1 and placed[O.OPEN_MENU]==1,'The mute rows and Open the co-op menu have one place each')
for row in pairs(placed) do assert(today[row],'A placed row that is no row of today: '..tostring(row.id or row.key)) end
for row in pairs(O.LEFT_OUT) do assert(today[row],'A left-out row that is no row of today') end
table.sort(left)
assert(table.concat(left,' ')=='close options',table.concat(left,' '))
-- The rows are model.lua's own tables: their values, defaults and show functions are written once.
local friends_ask
for _,row in ipairs(Model.OPTIONS) do if row.key=='friends_ask' then friends_ask=row end end
local sec=page.categories(SOLO)[1].sections[3]
assert(sec.id=='hosting' and rawequal(sec.rows[2],friends_ask))

-- Hidden rows drop: each row shows by its own show function.
local FRIENDS=Model.values({who_can_join='friends'})
assert(find(page.categories({mode='none',values=FRIENDS}),'session','hosting')=='who_can_join max_players',
    'Friends join without asking under Public and Invitation only')
assert(find(page.categories(hosting({code=NIL})),'session','current')=='invite chat leave','No code: no copy')
assert(find(page.categories(hosting({mode='guest',code=NIL,chat=false})),'session','current')=='leave',
    'A guest: no invite; no chat box: no chat')
assert(find(page.categories(hosting({members={{id='7',name='A',linked=false},{id='8',name='B',linked=true}}})),
    'players','members')=='mute:8 remove','A member not past the handshake has no mute row')
assert(find(page.categories(hosting({stranger=NIL})),'players','members')=='mute:7 mute:8','No stranger: no remove')

-- Empty sections drop; a category with no section left drops too.
assert(dump(page.categories(SOLO))[1]
    =='session(menu:open_menu|play:host find join_code|hosting:who_can_join friends_ask max_players)',
    'Solo with no chat box: no current section')
assert(dump(page.categories({mode='none',chat=true,values=VALUES}))[1]
    =='session(menu:open_menu|play:host find join_code|current:chat|hosting:who_can_join friends_ask max_players)',
    'The loopback or the SBO lobby chats with no session')
assert(dump(page.categories({values=VALUES}))[1]
    =='session(menu:open_menu|hosting:who_can_join friends_ask max_players)',
    'Before Steam: no play section')
assert(dump(page.categories({mode='guest',chat=true,values=VALUES,pages=PAGES}))[1]
    =='session(menu:open_menu|current:chat leave|hosting:who_can_join friends_ask max_players)','A guest')
local lone=page.categories({mode='guest',values=VALUES,pages=PAGES,members={}})
assert(ids(lone)=='session world combat modes controls display others photo saves help tools',
    'No other player and no stranger: no players category')
assert(ids(page.categories({mode='none',values=VALUES}))
    =='session world combat modes controls display others photo saves help',
    'No module page: no test tools category')

-- The order is stable: the same rows, the same tables, in the same order from call to call; the mute rows in the
-- members' order, each the same table for her with her name and mute now; solo's categories in the session's order.
local a,b=page.categories(hosting()),page.categories(hosting())
same(dump(a),dump(b),'two calls')
for i,cat in ipairs(a) do
    for j,s in ipairs(cat.sections) do
        for k,row in ipairs(s.rows) do assert(rawequal(row,b[i].sections[j].rows[k]),name(row)) end
    end
end
local m1=a[2].sections[1].rows[1]
assert(m1.member=='7' and m1.name=='A' and m1.muted==false)
local swapped=page.categories(hosting({members={{id='8',name='B',linked=true,muted=false},
    {id='7',name='A2',linked=true,muted=true}}}))
assert(find(swapped,'players','members')=='mute:8 mute:7 remove','The members\' order')
assert(rawequal(swapped[2].sections[1].rows[2],m1) and m1.name=='A2' and m1.muted==true,'Her row, updated')
local at=1
local session_ids={}
for id in ids(page.categories(hosting())):gmatch('%S+') do session_ids[#session_ids+1]=id end
for id in ids(page.categories(SOLO)):gmatch('%S+') do
    while session_ids[at] and session_ids[at]~=id do at=at+1 end
    assert(session_ids[at]==id,'Solo\'s '..id..' out of the session\'s order')
end

-- The co-op menu's model behind each row: the Options page's for its rows and the mute rows, the main page's for its
-- rows, none for Open the co-op menu and a Test tools row. A row's confirm runs through that model's 3 s window;
-- forget() drops a first Select, as the co-op menu's move does.
do
    local p=O.new()
    local function opt_row(id) for _,r in ipairs(Model.OPTIONS) do if (r.key or r.id)==id then return r end end end
    local function main_row(id) for _,r in ipairs(Model.MAIN) do if r.id==id then return r end end end
    local ctx=hosting()
    local cats=p.categories(ctx)
    local mute,tools=cats[2].sections[1].rows[1],cats[#cats].sections[1].rows[1]
    assert(mute.member=='7' and tools.page==PAGE,'A mute row and a Test tools row')
    local opts,mains=p.owner(opt_row('who_can_join')),p.owner(main_row('host'))
    assert(opts.page()=='options' and mains.page()=='main','The Options page and the main page')
    assert(p.owner(opt_row('reset_keys'))==opts and p.owner(opt_row('menu_key'))==opts and p.owner(mute)==opts)
    assert(p.owner(main_row('leave'))==mains and p.owner(main_row('remove'))==mains
        and p.owner(main_row('copy'))==mains)
    assert(p.owner(O.OPEN_MENU)==nil and p.owner(tools)==nil,'Not the co-op menu\'s rows')
    local reset=opt_row('reset_keys')
    opts.point(ctx,reset)
    assert(opts.select(ctx,10,VALUES)=='confirm_reset_keys' and opts.select(ctx,11,VALUES)=='reset_keys')
    assert(opts.select(ctx,20,VALUES)=='confirm_reset_keys')
    p.forget()
    assert(opts.select(ctx,21,VALUES)=='confirm_reset_keys','Forgotten: asked again')
    local leave=main_row('leave')
    mains.point(ctx,leave)
    assert(mains.select(ctx,30,VALUES)=='confirm_leave' and mains.select(ctx,31,VALUES)=='leave')
    assert(mains.select(ctx,40,VALUES)=='confirm_leave')
    p.forget()
    assert(mains.select(ctx,41,VALUES)=='confirm_leave','Leave forgotten too')
end

-- Only the pause menu's Online page (ui/kit/online_page.lua) requires it: the co-op menu still draws model.lua's pages.
local scripts=0
for path in io.popen("find mod/StellarCoop/Scripts -name '*.lua'"):lines() do
    if not path:find('ui/kit/online_model.lua',1,true) and not path:find('ui/kit/online_page.lua',1,true) then
        local file=assert(io.open(path))
        local text=file:read('a')
        file:close()
        assert(not text:find('ui.kit.online_model',1,true) and not text:find('ui/kit/online_model',1,true),
            path..' requires ui/kit/online_model.lua')
    end
    scripts=scripts+1
end
assert(scripts>=50,'The scripts were listed')
print('online_model_test ok')
