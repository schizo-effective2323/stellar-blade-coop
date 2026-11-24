-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Online page's arrangement (the pause menu's Online tab in the layout of SB's Settings page: a left list of
-- categories, section headers, rows), no engine call. It places ui/kit/model.lua's own rows: their ids, values,
-- defaults and show functions stay there. Ids only: ui_text gives the words. ui/kit/online_page.lua draws it in the
-- pause menu; the co-op menu still draws model.lua's pages (tests/lua/ui/kit/online_model_test.lua checks it).
local Model=require('ui.kit.model')
local M={}
-- The state a category names in states: 'session' while we host or join an online session, else 'solo' (no session,
-- or before Steam). A plain value, so a later state is one more name.
function M.state(ctx) return (ctx.mode=='host' or ctx.mode=='guest') and 'session' or 'solo' end
local BOTH,SESSION={solo=true,session=true},{session=true}
-- Today's rows: the main page's by id (its module pages row as 'pages'), Options' by setting name or id.
local MAIN,OPT={},{}
for _,row in ipairs(Model.MAIN) do
    local id=row.id or row.pages and 'pages'
    if id then MAIN[id]=row end
end
for _,row in ipairs(Model.OPTIONS) do
    local id=row.key or row.id
    if id then OPT[id]=row end
end
local function main(id) return (assert(MAIN[id],id)) end -- In brackets: assert gives its message too.
local function opt(id) return (assert(OPT[id],id)) end
-- The place of the mute rows (model.lua's, one per other player of the online session past the handshake).
M.MUTES={mutes=true}
-- Open the co-op menu: the one row of the page that is not model.lua's. It closes the pause menu and opens the co-op
-- menu, as the Online tab did before the page, so the page loses none of the menu's functions.
M.OPEN_MENU={id='open_menu'}
local function section(id,...) return {id=id,rows={...}} end
local function category(id,states,...) return {id=id,states=states,sections={...}} end
-- In order. A row with a show function is listed while it shows (model.lua's: the session rows by state, Friends join
-- without asking under Public and Invitation only). In a section, the rows the approved list names come first.
M.CATEGORIES={
    category('session',BOTH,
        section('menu',M.OPEN_MENU),
        section('play',main('host'),main('find'),main('join_code')),
        -- Chat shows with no session too: the loopback, the SBO lobby.
        section('current',main('invite'),main('copy'),main('chat'),main('leave')),
        section('hosting',opt('who_can_join'),opt('friends_ask'),opt('max_players'))),
    -- No blocked section: no row blocks a player today.
    category('players',SESSION,section('members',M.MUTES,main('remove'))),
    category('world',SESSION,
        -- Same place, same spawns and bosses: what shared enemies share.
        section('sharing',opt('shared_enemies'),opt('same_place'),opt('same_spawns'),opt('bosses'),
            opt('shared_quests'),opt('shared_world'),opt('shared_story'),opt('cutscene_wait')),
        section('travel',opt('follow_host'))),
    category('combat',SESSION,
        section('difficulty',opt('enemy_hp_scale'),opt('enemy_balance_scale'),opt('boss_hp_scale'),
            opt('enemy_extra')),
        section('rules',opt('aggro'),opt('boss_finish'),opt('kill_credit'),opt('hit_reactions'),
            opt('stagger_resist'),opt('revive'),opt('spectate'))),
    category('modes',SESSION,
        section('modes',opt('scoreattack'),opt('fishing'),opt('race_match'),opt('photohunt'))),
    category('controls',BOTH,
        section('keyboard',opt('menu_key'),opt('status_key'),opt('leave_key'),opt('follow_key'),opt('race_key'),
            opt('bike_key'),opt('gun_key'),opt('emote_key')),
        section('controller',opt('emote_pad')),
        section('features',opt('bike'),opt('bike_pose'),opt('gun_mode')),
        section('all',opt('reset_keys'))),
    category('display',BOTH,
        section('interface',opt('status_overlay'),opt('ui_scale'),opt('ui_language'),opt('ui_sounds'),
            opt('pause_tab'),opt('hide_popups')),
        section('names',opt('name_tag')),
        section('sky',opt('daynight'))),
    category('others',BOTH,
        section('look',opt('partner_bar'),opt('partner_arrow'),opt('partner_card'),opt('card_details'),
            opt('cloth'),opt('dyes'),opt('effects'),opt('drone'),opt('faces')),
        section('sound',opt('sounds')),
        section('motion',opt('collide'),opt('send_rate')),
        section('chat',opt('chat'))),
    category('photo',BOTH,
        section('photo',opt('photo_sync'),opt('photo_freeze_max'),opt('photo_ghost'),opt('photo_name_tag'),
            opt('photo_pause'))),
    category('saves',BOTH,section('saves',opt('auto_coop_save'))),
    category('help',BOTH,section('help',main('guide'),main('report'))),
    category('tools',BOTH,section('tools',main('pages'))),
}
-- Today's rows the page leaves out, each with why.
M.LEFT_OUT={
    [main('options')]='The page holds every option: no Options page to open.',
    [main('close')]='Esc and the key hints close the page.',
}
-- The page's categories now: {{id=, sections={{id=, rows={row, ...}}, ...}}, ...}. A section with no row shown and a
-- category with no section left are dropped. ctx: model.lua's (mode, chat, code, stranger, values, members, pages).
function M.new()
    -- model.lua's pages make the module page rows and the mute rows, the same table for each at every call.
    local self,main_page,options_page={},Model.new(),Model.new('options')
    function self.categories(ctx)
        local state,out,made=M.state(ctx),{},{[MAIN.pages]={},[M.MUTES]={}}
        for _,row in ipairs(main_page.rows(ctx)) do if row.page then table.insert(made[MAIN.pages],row) end end
        for _,row in ipairs(options_page.rows(ctx)) do if row.member then table.insert(made[M.MUTES],row) end end
        for _,cat in ipairs(M.CATEGORIES) do
            if cat.states[state] then
                local sections={}
                for _,sec in ipairs(cat.sections) do
                    local rows={}
                    for _,row in ipairs(sec.rows) do
                        if made[row] then for _,r in ipairs(made[row]) do rows[#rows+1]=r end
                        elseif not row.show or row.show(ctx) then rows[#rows+1]=row end
                    end
                    if #rows>0 then sections[#sections+1]={id=sec.id,rows=rows} end
                end
                if #sections>0 then out[#out+1]={id=cat.id,sections=sections} end
            end
        end
        return out
    end
    return self
end
return M
