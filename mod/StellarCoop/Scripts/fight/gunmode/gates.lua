-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- (dev only) Gate G1 of the v3 plan: the pass limits for the standing aim at camera pitch -40, 0 and +40, written down
-- before the build so the build is judged against them, not tuned to them. Distances in cm, angles in degrees.
-- Each gate: id, what it measures, how a value passes ('max': value <= limit, 'min': value >= limit, 'range': lo..hi,
-- 'log': recorded only) and the pitches it applies to (nil: all three).
local Gates={}

Gates.PITCHES={-40,0,40}

Gates.G1={
    {id='pocket',      what='butt centre to pocket point',                        op='max', limit=1},
    {id='shoulders',   what='both shoulder joints in Spine2 space vs layer off',  op='max', limit=2},
    {id='wrist_neck',  what='right wrist to neck capsule',                         op='min', limit=6},
    {id='fore_neck',   what='right forearm to neck capsule',                       op='min', limit=3},
    {id='grip_fwd',    what='grip forward of the right shoulder joint',            op='min', limit=15},
    {id='stock_clear', what='stock samples vs neck, collar and chest proxies',     op='min', limit=0.5},
    {id='breast_0',    what='rifle and forearms vs breast proxies at 0',           op='min', limit=1, pitches={0}},
    {id='breast_40',   what='rifle and forearms vs breast proxies at +-40',        op='min', limit=-1, pitches={-40,40}},
    {id='eye_sight',   what='eye to sight line at 0',                              op='max', limit=5, pitches={0}},
    {id='bore',        what='bore to camera ray, two-point, at rest',              op='max', limit=0.5},
    {id='wrist_flex',  what='wrist flexion or extension, both hands',              op='max', limit=45},
    {id='wrist_dev',   what='wrist deviation, both hands',                         op='max', limit=30},
    {id='wrist_twist', what='residual wrist twist, both hands',                    op='max', limit=30},
    {id='elbow',       what='elbow interior angle, both arms',                     op='range', lo=60, hi=150},
    {id='lfore_vert',  what='left forearm from vertical',                          op='min', limit=30},
    {id='reach',       what='reach as a fraction of arm length, both arms',        op='max', limit=0.90},
    {id='lpalm_angle', what='left palm normal to the handguard axis',              op='max', limit=25},
    {id='lpalm_gap',   what='left palm gap to the handguard',                      op='max', limit=1.5},
    {id='lpalm_pos',   what='left palm along the handguard underside, from its rear (0..1)', op='max', limit=0.40},
    {id='fingertip',   what='fingertip to rifle surface (expected to fail until G4)', op='log'},
}

local by_id={}
for _,g in ipairs(Gates.G1) do by_id[g.id]=g end

-- Whether a gate applies at this pitch.
function Gates.applies(g,pitch)
    if not g.pitches then return true end
    for _,p in ipairs(g.pitches) do if p==pitch then return true end end
    return false
end

-- 'PASS', 'FAIL', 'LOG' (recorded only) or nil when the gate does not apply at this pitch. Unknown ids are an error.
function Gates.judge(id,value,pitch)
    local g=assert(by_id[id],'no G1 gate '..tostring(id))
    if pitch~=nil and not Gates.applies(g,pitch) then return nil end
    if g.op=='log' then return 'LOG' end
    if value==nil or value~=value then return 'FAIL' end
    if g.op=='max' then return value<=g.limit and 'PASS' or 'FAIL' end
    if g.op=='min' then return value>=g.limit and 'PASS' or 'FAIL' end
    return (value>=g.lo and value<=g.hi) and 'PASS' or 'FAIL'
end

return Gates
