-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gate G1's limits: each kind of gate judged at and past its limit, the pitch filter, the logged-only gate.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Gates=require('fight.gunmode.gates')

-- 1. A 'max' gate passes at its limit and fails just over it. A missing or NaN value fails.
assert(Gates.judge('pocket',1)=='PASS' and Gates.judge('pocket',1.01)=='FAIL')
assert(Gates.judge('pocket',nil)=='FAIL' and Gates.judge('pocket',0/0)=='FAIL')

-- 2. A 'min' gate passes at its limit and fails just under it.
assert(Gates.judge('wrist_neck',6)=='PASS' and Gates.judge('wrist_neck',5.99)=='FAIL')

-- 3. A 'range' gate passes inside its two ends only.
assert(Gates.judge('elbow',60)=='PASS' and Gates.judge('elbow',150)=='PASS')
assert(Gates.judge('elbow',59.9)=='FAIL' and Gates.judge('elbow',150.1)=='FAIL')

-- 4. Pitch filter: the breast gates split by pitch, the eye gate only at 0.
assert(Gates.judge('breast_0',0.5,0)=='FAIL' and Gates.judge('breast_0',0.5,40)==nil)
assert(Gates.judge('breast_40',-0.5,40)=='PASS' and Gates.judge('breast_40',-0.5,-40)=='PASS')
assert(Gates.judge('eye_sight',4,0)=='PASS' and Gates.judge('eye_sight',4,-40)==nil)

-- 5. The fingertip gate is recorded only. An unknown id is an error.
assert(Gates.judge('fingertip',9)=='LOG')
assert(not pcall(Gates.judge,'no_such_gate',1))

-- 6. Every gate has an id, a description and a known kind. The three pitches are -40, 0 and +40.
for _,g in ipairs(Gates.G1) do
    assert(g.id and g.what and (g.op=='max' or g.op=='min' or g.op=='range' or g.op=='log'))
end
assert(#Gates.PITCHES==3 and Gates.PITCHES[1]==-40 and Gates.PITCHES[3]==40)

print('fight.gunmode gates_test ok')
