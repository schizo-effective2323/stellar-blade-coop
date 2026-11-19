-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- (dev only) Gate G1's measurements as pure functions of world points, so lua5.4 tests them without the game.
-- fight/gunmode/g1.lua reads the points in game and passes them here. Vectors are {X,Y,Z} in cm (UE axes: X forward,
-- Y right, Z up, left-handed, so forward = cross(right, up)). Angles in degrees.
local M={}

local function v(x,y,z) return {X=x,Y=y,Z=z} end
local function add(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
local function sub(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
local function mul(a,k) return v(a.X*k,a.Y*k,a.Z*k) end
local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b) return v(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end
local function len(a) return math.sqrt(dot(a,a)) end
local function nrm(a) local l=len(a); return l>1e-9 and mul(a,1/l) or v(0,0,0) end
local function reject(a,n) return sub(a,mul(n,dot(a,n))) end
local function angle(a,b) return math.deg(math.acos(math.max(-1,math.min(1,dot(nrm(a),nrm(b)))))) end
local function mid(a,b) return mul(add(a,b),0.5) end
M.v,M.add,M.sub,M.mul,M.dot,M.cross,M.len,M.nrm,M.angle,M.mid=v,add,sub,mul,dot,cross,len,nrm,angle,mid

-- Closest point to p on the segment a..b, and its fraction along it (0 at a, 1 at b).
function M.closest(p,a,b)
    local ab=sub(b,a); local d=dot(ab,ab)
    local t=d>1e-9 and math.max(0,math.min(1,dot(sub(p,a),ab)/d)) or 0
    return add(a,mul(ab,t)),t
end
-- Shortest distance between segments p1..q1 and p2..q2 (sampled, 24 steps along the first, exact on the second).
function M.segdist(p1,q1,p2,q2)
    local best=math.huge
    for i=0,24 do
        local p=add(p1,mul(sub(q1,p1),i/24))
        local c=M.closest(p,p2,q2); best=math.min(best,len(sub(p,c)))
    end
    return best
end

-- The chest frame of the v3 plan (round 2, 1.2): up from Spine1 to Neck, right across the shoulder joints, forward.
function M.chest(b)
    local up=nrm(sub(b.neck,b.spine1))
    local right=nrm(reject(sub(b.r_upper,b.l_upper),up))
    return {R=right,F=cross(right,up),U=up}
end

-- The pocket point: 3.5 cm medial, 4.5 cm forward and 1.5 cm above the right shoulder joint, in the chest frame.
M.POCKET={r=-3.5,f=4.5,u=1.5}
function M.pocket(b,C)
    return add(add(add(b.r_upper,mul(C.R,M.POCKET.r)),mul(C.F,M.POCKET.f)),mul(C.U,M.POCKET.u))
end

-- Proxy radii (round 2, 2.1) and sample radii, in cm.
M.R={neck=5.5,chest=9.5,collar=4,deltoid=5.5,breast=10,forearm=3.2,wrist=3,stock=1.5,rifle=2}

-- A hand's axes from its bones: long (wrist to the middle finger's base), side (pinky base to index base) and the palm
-- normal. UE is left-handed: for the right hand long x side points out of the palm, for the left hand side x long does.
function M.hand_axes(hand,index,middle,pinky,left)
    local long=nrm(sub(middle,hand))
    local side=nrm(reject(sub(index,pinky),long))
    local palm=left and cross(side,long) or cross(long,side)
    return {long=long,side=side,palm=nrm(palm)}
end

-- Signed angle about axis n from a to b, both projected onto the plane normal to n.
function M.about(n,a,b)
    n=nrm(n); local pa,pb=nrm(reject(a,n)),nrm(reject(b,n))
    return math.deg(math.atan(dot(cross(pa,pb),n),dot(pa,pb)))
end

-- Wrist angles of a hand against its forearm axis, from the straight line: flexion/extension is the turn about the
-- hand's side axis (toward the palm or the back), deviation the turn about the palm normal (toward thumb or pinky).
function M.wrist(fore_axis,H)
    return math.abs(M.about(H.side,fore_axis,H.long)),math.abs(M.about(H.palm,fore_axis,H.long))
end
local function wrap(a) a=(a+180)%360-180; return a end

-- Every G1 measurement from one sample. b: body points (world), r: rifle points (world), cam: camera forward.
-- base: the hand-to-twist-bone roll of each hand at idle (gun mode off), so twist is the change from her own pose.
function M.measure(b,r,cam,base)
    local C=M.chest(b)
    local out={}
    out.pocket=len(sub(r.butt,M.pocket(b,C)))
    -- the neck capsule runs from Neck to Head
    out.wrist_neck=M.segdist(b.r_hand,b.r_hand,b.neck,b.head)-M.R.neck
    out.fore_neck=M.segdist(b.r_fore,b.r_hand,b.neck,b.head)-M.R.neck-M.R.forearm
    local rgrip=mid(b.r_hand,b.r_middle)
    out.grip_fwd=dot(sub(rgrip,b.r_upper),C.F)
    -- the stock samples (heel, toe, receiver rear top) against the neck, the chest, the collar and the deltoid
    local stock=math.huge
    for _,s in ipairs({r.heel,r.toe,r.rear_top}) do
        stock=math.min(stock,
            M.segdist(s,s,b.neck,b.head)-M.R.neck,
            M.segdist(s,s,b.spine1,b.neck)-M.R.chest,
            len(sub(s,mid(b.r_clav,b.r_upper)))-M.R.collar,
            len(sub(s,b.r_upper))-M.R.deltoid)
    end
    out.stock_clear=stock-M.R.stock
    -- the rifle (grip base, magazine base, handguard rear) and both forearms against the breast spheres
    local br=math.huge
    for _,c in ipairs({b.l_breast,b.r_breast}) do
        for _,s in ipairs({r.grip_base,r.mag_base,r.hg0}) do br=math.min(br,len(sub(s,c))-M.R.breast-M.R.rifle) end
        br=math.min(br,M.segdist(b.r_fore,b.r_hand,c,c)-M.R.breast-M.R.forearm,
                       M.segdist(b.l_fore,b.l_hand,c,c)-M.R.breast-M.R.forearm)
    end
    out.breast=br
    -- the eye (right eye, from the glabella) to the sight line through the rear and front sights
    local eye=b.eye
    local sp=M.closest(eye,sub(r.sight_r,mul(sub(r.sight_f,r.sight_r),3)),add(r.sight_f,mul(sub(r.sight_f,r.sight_r),3)))
    out.eye_sight=len(sub(eye,sp))
    out.bore=angle(sub(r.muzzle,r.breech),cam)
    -- wrists, elbows, reach
    local worst={flex=0,dev=0,twist=0}
    out.elbow_min,out.elbow_max,out.reach=180,0,0
    local twist={}
    for _,side in ipairs({'r','l'}) do
        local H=M.hand_axes(b[side..'_hand'],b[side..'_index'],b[side..'_middle'],b[side..'_pinky'],side=='l')
        local fore=sub(b[side..'_hand'],b[side..'_fore'])
        local fl,dv=M.wrist(fore,H)
        worst.flex=math.max(worst.flex,fl); worst.dev=math.max(worst.dev,dv)
        twist[side]=M.about(fore,b[side..'_tw_side'],H.side)
        if base and base[side] then worst.twist=math.max(worst.twist,math.abs(wrap(twist[side]-base[side]))) end
        local el=angle(sub(b[side..'_upper'],b[side..'_fore']),sub(b[side..'_hand'],b[side..'_fore']))
        out.elbow_min,out.elbow_max=math.min(out.elbow_min,el),math.max(out.elbow_max,el)
        local arm=len(sub(b[side..'_fore'],b[side..'_upper']))+len(fore)
        out.reach=math.max(out.reach,len(sub(b[side..'_hand'],b[side..'_upper']))/arm)
        if side=='l' then
            out.lfore_vert=90-math.abs(90-angle(fore,C.U))
            -- the left palm against the handguard underside line hg0..hg1
            local palm=add(mid(b.l_hand,b.l_middle),mul(H.palm,2))
            local c,t=M.closest(palm,r.hg0,r.hg1)
            out.lpalm_gap=len(sub(palm,c))
            out.lpalm_angle=angle(H.palm,sub(c,palm))
            out.lpalm_pos=t
            out.fingertip=b.l_tip and len(sub(b.l_tip,(M.closest(b.l_tip,r.hg0,r.hg1)))) or nil
        end
    end
    out.wrist_flex,out.wrist_dev=worst.flex,worst.dev
    out.wrist_twist=base and worst.twist or nil
    out.twist_raw=twist
    -- the elbow gate is a range: pass both ends to it as the value furthest outside 60..150
    out.elbow=(out.elbow_min<60) and out.elbow_min or out.elbow_max
    out.chest=C
    return out
end

-- The gate ids fed by each measurement (breast splits by pitch in fight/gunmode/gates.lua).
function M.gate_values(m,pitch)
    return {pocket=m.pocket,wrist_neck=m.wrist_neck,fore_neck=m.fore_neck,grip_fwd=m.grip_fwd,stock_clear=m.stock_clear,
        breast_0=pitch==0 and m.breast or nil,breast_40=pitch~=0 and m.breast or nil,eye_sight=m.eye_sight,bore=m.bore,
        wrist_flex=m.wrist_flex,wrist_dev=m.wrist_dev,wrist_twist=m.wrist_twist,elbow=m.elbow,lfore_vert=m.lfore_vert,
        reach=m.reach,lpalm_angle=m.lpalm_angle,lpalm_gap=m.lpalm_gap,lpalm_pos=m.lpalm_pos,fingertip=m.fingertip,
        shoulders=m.shoulders}
end

-- The median of a list of numbers (nil entries skipped), or nil.
function M.median(t)
    local s={}
    for _,x in pairs(t) do if type(x)=='number' and x==x then s[#s+1]=x end end
    if #s==0 then return nil end
    table.sort(s)
    return #s%2==1 and s[(#s+1)//2] or (s[#s//2]+s[#s//2+1])/2
end

return M
