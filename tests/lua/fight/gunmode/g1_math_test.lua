-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gate G1's measurements on a hand-built pose with known answers: the chest frame, the pocket point, segment
-- distances, wrist and elbow angles, reach, the left palm on the handguard, the eye to the sight line, the median.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local M=require('fight.gunmode.g1_math')
local v=M.v
local close=function(a,b,eps) return math.abs(a-b)<=(eps or 1e-6) end

-- 1. Chest frame: up Spine1 to Neck, right across the shoulders, forward = right x up (UE: X forward, Y right, Z up).
local b={spine1=v(0,0,120),neck=v(0,0,146),head=v(0,0,152),l_upper=v(0,-11.5,140),r_upper=v(0,11.5,140)}
local C=M.chest(b)
assert(close(C.U.Z,1) and close(C.R.Y,1) and close(C.F.X,1))

-- 2. Pocket: 3.5 cm medial, 4.5 forward, 1.5 up from the right shoulder joint.
local P=M.pocket(b,C)
assert(close(P.X,4.5) and close(P.Y,8) and close(P.Z,141.5))

-- 3. Closest point and segment distance.
local c,t=M.closest(v(5,5,0),v(0,0,0),v(10,0,0))
assert(close(c.X,5) and close(c.Y,0) and close(t,0.5))
assert(close(M.segdist(v(0,3,0),v(10,3,0),v(5,-1,0),v(5,1,0)),2))

-- 4. A straight right hand along its forearm: no flexion, no deviation. Bent 30 deg toward the palm: flexion 30.
local function hand_at(origin,long,side,left)
    local function at(a,s) return M.add(M.add(origin,M.mul(long,a)),M.mul(side,s)) end
    return M.hand_axes(origin,at(8,1.5),at(8,0),at(7,-2),left)
end
local fwd,right,down=v(1,0,0),v(0,1,0),v(0,0,-1)
local H=hand_at(v(0,0,0),fwd,v(0,-1,0)) -- right hand, palm down: index on her left (-Y)
assert(close(H.palm.Z,-1)) -- the palm normal points down
local fl,dv=M.wrist(fwd,H)
assert(close(fl,0,1e-4) and close(dv,0,1e-4))
local bent=M.nrm(M.add(M.mul(fwd,math.cos(math.rad(30))),M.mul(down,math.sin(math.rad(30)))))
H=hand_at(v(0,0,0),bent,v(0,-1,0))
fl,dv=M.wrist(fwd,H)
assert(close(fl,30,1e-3) and close(dv,0,1e-3))
-- the left hand, palm down: index on her right (+Y), the palm normal still points down
assert(close(hand_at(v(0,0,0),fwd,v(0,1,0),true).palm.Z,-1))

-- 5. A whole sample: arms bent 90 deg at the elbow, rifle along X, the left palm under the handguard.
local function arm(side,s)
    local u=b[side..'_upper']
    b[side..'_fore']=M.add(u,v(0,0,-24.4))                 -- upper arm straight down
    b[side..'_hand']=M.add(b[side..'_fore'],v(24.4,0,0))   -- forearm straight forward: elbow 90 deg
    local h=b[side..'_hand']
    b[side..'_index']=M.add(h,v(8,-1.5*s,0)); b[side..'_middle']=M.add(h,v(8,0,0)); b[side..'_pinky']=M.add(h,v(7,2*s,0))
    b[side..'_tw_side']=v(0,-s,0)
end
arm('r',1); arm('l',-1)
b.r_clav=v(0,2.4,140); b.l_breast=v(4.6,-4.3,133); b.r_breast=v(4.6,4.3,133); b.eye=v(9,2.8,159)
local r={butt=P,heel=M.add(P,v(0,0,5)),toe=M.add(P,v(0,0,-5)),rear_top=M.add(P,v(5,0,8)),
    grip_base=v(40,11,100),mag_base=v(50,11,100),hg0=v(20,-11.5,112),hg1=v(50,-11.5,112),
    muzzle=v(100,8,150),breech=v(20,8,150),sight_r=v(25,8,159),sight_f=v(60,8,159)}
local m=M.measure(b,r,v(1,0,0),{r=0,l=0})
assert(close(m.pocket,0))
assert(close(m.elbow_min,90,1e-6) and close(m.elbow_max,90,1e-6) and close(m.elbow,90,1e-6))
assert(close(m.reach,math.sqrt(2)*24.4/48.8,1e-6))
assert(close(m.wrist_flex,0,1e-4) and close(m.wrist_dev,0,1e-4) and close(m.wrist_twist,0,1e-4))
assert(close(m.lfore_vert,90,1e-6)) -- a level forearm is 90 deg from vertical
assert(close(m.grip_fwd,24.4+4,1e-6)) -- grip = halfway between the hand and the middle finger's base
assert(close(m.bore,0,1e-4))
assert(close(m.eye_sight,5.2,1e-6)) -- eye (9,2.8,159) to the sight line y=8, z=159
-- left palm: hand at (24.4,-11.5,115.6), middle base 8 cm ahead, then 2 cm toward the palm (down): (28.4,-11.5,113.6),
-- 1.6 cm above the handguard line, 8.4 cm along its 30 cm
assert(close(m.lpalm_gap,1.6,1e-6) and close(m.lpalm_pos,8.4/30,1e-6))
assert(close(m.lpalm_angle,0,1e-4)) -- the palm faces down onto the handguard line below it

-- 6. Gate values: the breast measurement goes to the gate of its pitch.
local gv=M.gate_values(m,0); assert(gv.breast_0==m.breast and gv.breast_40==nil)
gv=M.gate_values(m,40); assert(gv.breast_0==nil and gv.breast_40==m.breast)

-- 7. Median, skipping nil and NaN.
assert(M.median({3,1,2})==2 and M.median({4,1,3,2})==2.5 and M.median({0/0})==nil and M.median({})==nil)

print('fight.gunmode g1_math_test ok')
