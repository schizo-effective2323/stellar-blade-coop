-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- (dev only, setting gun_g1=on) Gate G1 of the v3 plan, measured in game: the standing aim at camera pitch -40, 0
-- and +40, judged against fight/gunmode/gates.lua, with fixed-camera pictures of each pitch.
--   * gun mode off, standing: each hand's roll against its forearm twist bone, the reference for the twist gate
--   * once per load, 1.5 s into an aim: for each pitch the camera is set there, 8 samples are taken, then the AimRot
--     test (both shoulder joints in Spine2 space, AimRot written to 0 for 0.5 s, measured again, AimRot put back),
--     then four pictures (right side and front from 3 m with a 20 deg lens, the left hand from below-left-front and the
--     right wrist and neck from front-right-above at 80 cm) and one from the game camera
--   * the medians and each gate's PASS/FAIL go to the log ("g1," lines) and to cap_g1\<run>_report.txt
-- On the post-process instance it only reads and writes AimRot (a property). Hold still while it runs (~40 s).
local Gates=require('fight.gunmode.gates')
local M=require('fight.gunmode.g1_math')
local G1={}

-- Rifle points in the rifle mesh's own space (UE cm), measured in Blender on GunNikke_Weapon (NikkeGunBuild\blend\
-- rifle10, 2026-11-19). The barrel runs along -X at Z 9.88, level with FX_Fire. rear_top is approximate.
G1.PTS={
    butt={X=14.4,Y=0,Z=8.72}, heel={X=14.56,Y=-0.97,Z=12.69}, toe={X=13.96,Y=0,Z=2.62}, rear_top={X=2.4,Y=0,Z=12.9},
    grip_base={X=-1.34,Y=-0.85,Z=-1.32}, mag_base={X=-11.33,Y=0,Z=-1.75},
    hg0={X=-20.78,Y=0,Z=-0.22}, hg1={X=-40.36,Y=0,Z=-0.44},
    sight_r={X=-11.72,Y=-0.8,Z=17.77}, sight_f={X=-38.72,Y=-0.06,Z=13.7},
    breech={X=0,Y=0,Z=9.88}, fx_fire={X=-53.42,Y=0,Z=9.88},
}
-- The right eye from the glabella bone, in the chest frame (rest pose, Blender): 2.8 cm to her right, 1.7 cm back.
G1.EYE={r=2.8,f=-1.7,u=-0.1}

local BONES={spine1='Bip001-Spine1',spine2='Bip001-Spine2',neck='Bip001-Neck',head='Bip001-Head',glabella='SC_Glabella',
    l_breast='Ab-L-Breast',r_breast='Ab-R-Breast',r_clav='Bip001-R-Clavicle'}
for _,s in ipairs({'L','R'}) do
    local k=s:lower()
    BONES[k..'_upper']=('Bip001-%s-UpperArm'):format(s); BONES[k..'_fore']=('Bip001-%s-Forearm'):format(s)
    BONES[k..'_hand']=('Bip001-%s-Hand'):format(s); BONES[k..'_index']=('Bip001-%s-Finger1'):format(s)
    BONES[k..'_middle']=('Bip001-%s-Finger2'):format(s); BONES[k..'_pinky']=('Bip001-%s-Finger4'):format(s)
end
local TWIST={r='Ab-R-Forearm-Tw1',l='Ab-L-Forearm-Tw1'}
local TIPS={'Bip001-L-Finger22','Bip001-L-Finger2Nub'} -- the first that exists is the fingertip

function G1.new(g)
    local self={}
    local st={phase='idle',base=nil,idle={r={},l={}},done=false,run=os.date('%Y%m%d_%H%M%S')}
    local function valid(o) return o~=nil and g.try(function() return o:IsValid() end)==true end
    local function ml() return StaticFindObject('/Script/Engine.Default__KismetMathLibrary') end
    local function f1(x) return x and ('%.2f'):format(x) or '-' end
    local function rot(q,a) -- rotate vector a by quaternion q {X,Y,Z,W}
        local x,y,z,w=q.X,q.Y,q.Z,q.W
        local tx,ty,tz=2*(y*a.Z-z*a.Y),2*(z*a.X-x*a.Z),2*(x*a.Y-y*a.X)
        return {X=a.X+w*tx+(y*tz-z*ty),Y=a.Y+w*ty+(z*tx-x*tz),Z=a.Z+w*tz+(x*ty-y*tx)}
    end
    local function has(mesh,name) return (g.try(function() return mesh:GetBoneIndex(FName(name)) end) or -1)>=0 end
    local function at(mesh,name) return mesh:GetSocketLocation(FName(name)) end

    -- A twist bone's side axis: its local axis most at right angles to the forearm, chosen once per side.
    local axis_of={}
    local function tw_side(mesh,side,fore)
        local q=mesh:GetSocketTransform(FName(TWIST[side]),0).Rotation -- 0 = RTS_World
        local axes={{X=1,Y=0,Z=0},{X=0,Y=1,Z=0},{X=0,Y=0,Z=1}}
        if not axis_of[side] then
            local best,bi=2,1
            for i,a in ipairs(axes) do local d=math.abs(M.dot(M.nrm(rot(q,a)),M.nrm(fore))); if d<best then best,bi=d,i end end
            axis_of[side]=bi
        end
        return rot(q,axes[axis_of[side]])
    end

    local function body(mesh)
        local b={}
        for k,name in pairs(BONES) do b[k]=at(mesh,name) end
        for _,s in ipairs({'r','l'}) do b[s..'_tw_side']=tw_side(mesh,s,M.sub(b[s..'_hand'],b[s..'_fore'])) end
        for _,t in ipairs(TIPS) do if has(mesh,t) then b.l_tip=at(mesh,t); break end end
        local C=M.chest(b)
        b.eye=M.add(M.add(M.add(b.glabella,M.mul(C.R,G1.EYE.r)),M.mul(C.F,G1.EYE.f)),M.mul(C.U,G1.EYE.u))
        return b
    end
    local function rifle_pts(rifle)
        local T=rifle:K2_GetComponentToWorld(); local r={}
        for k,p in pairs(G1.PTS) do r[k]=ml():TransformLocation(T,p) end
        r.muzzle=r.fx_fire
        return r
    end
    -- Both shoulder joints in Spine2 space (cm).
    local function shoulders(mesh)
        local T=mesh:GetSocketTransform(FName('Bip001-Spine2'),0)
        return ml():InverseTransformLocation(T,at(mesh,BONES.r_upper)),ml():InverseTransformLocation(T,at(mesh,BONES.l_upper))
    end

    -- Gun mode off: each hand's roll against its twist bone, median over 20 samples, the twist gate's reference.
    function self.idle(p,now)
        if st.base or not valid(p) or (st.idle_last and now-st.idle_last<0.1) then return end
        st.idle_last=now
        local ok,e=pcall(function()
            local b=body(p.Mesh)
            for _,s in ipairs({'r','l'}) do
                local H=M.hand_axes(b[s..'_hand'],b[s..'_index'],b[s..'_middle'],b[s..'_pinky'],s=='l')
                table.insert(st.idle[s],M.about(M.sub(b[s..'_hand'],b[s..'_fore']),b[s..'_tw_side'],H.side))
            end
            if #st.idle.r>=20 then
                st.base={r=M.median(st.idle.r),l=M.median(st.idle.l)}
                g.log(('g1 idle twist reference: right %s deg, left %s deg'):format(f1(st.base.r),f1(st.base.l)))
            end
        end)
        if not ok and not st.err then st.err=true; g.log('g1 idle: '..tostring(e)) end
    end

    -- The hidden capture camera (one SceneCapture2D, moved for each view).
    local function cam_actor(p)
        if st.cap and valid(st.cap) then return st.cap end
        local world=p:GetWorld()
        local kr=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
        local a=world:SpawnActor(StaticFindObject('/Script/Engine.SceneCapture2D'),{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0})
        assert(valid(a),'could not spawn a SceneCapture2D')
        local c=a.CaptureComponent2D
        c.TextureTarget=kr:CreateRenderTarget2D(world,1024,1024,2,{R=0,G=0,B=0,A=1},false) -- 2 = RTF_RGBA8
        c.bCaptureEveryFrame=false; c.bCaptureOnMovement=false; c.CaptureSource=2 -- SCS_FinalColorLDR
        st.cap=a
        return a
    end
    local function capture(pc,p,pitch,b)
        local a=cam_actor(p); local c=a.CaptureComponent2D
        local world=p:GetWorld(); local kr=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
        local dir=os.getenv('USERPROFILE')..'\\Downloads\\Modding Tools\\NikkeGunBuild\\cap_g1'
        os.execute('mkdir "'..dir..'" 2>nul')
        local C=M.chest(b); local chest=b.spine2
        local lpalm=M.mid(b.l_hand,b.l_middle); local rw=M.mid(b.r_hand,b.neck)
        local function from(t,r,f,u,dist) return M.add(t,M.mul(M.nrm(M.add(M.add(M.mul(C.R,r),M.mul(C.F,f)),M.mul(C.U,u))),dist)) end
        local views={
            {'side',from(chest,1,0,0,300),chest,20},
            {'front',from(chest,0,1,0,300),chest,20},
            {'lhand',from(lpalm,-0.5,0.5,-0.7,80),lpalm,40},
            {'rwrist',from(rw,0.5,0.6,0.6,80),rw,40},
        }
        local tag=('%s_p%+d'):format(st.run,pitch)
        for _,vw in ipairs(views) do
            c.FOVAngle=vw[4]
            a:K2_SetActorLocationAndRotation(vw[2],ml():FindLookAtRotation(vw[2],vw[3]),false,{},false)
            c:CaptureScene(); kr:ExportRenderTarget(world,c.TextureTarget,dir,tag..'_'..vw[1]..'.png')
        end
        pcall(function()
            local cm=pc.PlayerCameraManager
            c.FOVAngle=cm:GetFOVAngle()
            a:K2_SetActorLocationAndRotation(cm:GetCameraLocation(),cm:GetCameraRotation(),false,{},false)
            c:CaptureScene(); kr:ExportRenderTarget(world,c.TextureTarget,dir,tag..'_gamecam.png')
        end)
        g.log('g1 pictures -> cap_g1\\'..tag..'_*.png')
        return dir
    end

    local function report(lines)
        local dir=os.getenv('USERPROFILE')..'\\Downloads\\Modding Tools\\NikkeGunBuild\\cap_g1'
        os.execute('mkdir "'..dir..'" 2>nul')
        local fh=io.open(dir..'\\'..st.run..'_report.txt','w')
        if fh then fh:write(table.concat(lines,'\n'),'\n'); fh:close() end
    end

    -- Judge one pitch: the median of each measurement against its gate.
    local function judge(pitch,samples,shoulder_shift)
        local lines={}
        local fails=0
        for _,gate in ipairs(Gates.G1) do
            if Gates.applies(gate,pitch) then
                local vals={}
                for _,m in ipairs(samples) do vals[#vals+1]=M.gate_values(m,pitch)[gate.id] end
                local med=(gate.id=='shoulders') and shoulder_shift or M.median(vals)
                local verdict=(med==nil and gate.op~='log') and 'NO DATA' or Gates.judge(gate.id,med,pitch)
                if verdict=='FAIL' or verdict=='NO DATA' then fails=fails+1 end
                lines[#lines+1]=('g1,%+d,%s,%s,%s,%s'):format(pitch,gate.id,f1(med),verdict,gate.what)
            end
        end
        lines[#lines+1]=('g1,%+d,summary,%d gates failed'):format(pitch,fails)
        for _,l in ipairs(lines) do g.log(l) end
        return lines
    end

    -- The sequence, one step per tick: set pitch, settle, sample, AimRot test, pictures, next pitch.
    function self.tick(pc,p,rifle,mode,now)
        if st.done or not (valid(p) and valid(rifle)) then return end
        if mode~='aim' then st.aim_at=nil; if st.phase~='idle' then g.log('g1 stopped: left the aim'); st.phase='idle' end; return end
        st.aim_at=st.aim_at or now
        local ok,e=pcall(function()
            local mesh=p.Mesh
            if st.phase=='idle' then
                if now-st.aim_at<1.5 then return end
                if not st.base then g.log('g1: no idle twist reference yet (stand with gun mode off first); twist is not judged') end
                local fr=M.len(M.sub(ml():InverseTransformLocation(rifle:K2_GetComponentToWorld(),rifle:GetSocketLocation(FName('FX_Fire'))),G1.PTS.fx_fire))
                g.log(('g1 check: FX_Fire in rifle space is %.2f cm from the Blender value'):format(fr))
                st.ctrl0=pc:GetControlRotation(); st.i=0; st.lines={('g1 run %s'):format(st.run)}
                st.phase='set'
            end
            if st.phase=='set' then
                st.i=st.i+1
                local pitch=Gates.PITCHES[st.i]
                if not pitch then
                    report(st.lines); pc:SetControlRotation(st.ctrl0)
                    g.log('g1 done: cap_g1\\'..st.run..'_report.txt'); st.done=true; return
                end
                st.pitch=pitch; st.samples={}
                pc:SetControlRotation({Pitch=pitch,Yaw=st.ctrl0.Yaw,Roll=0})
                st.t=now; st.phase='settle'
            elseif st.phase=='settle' then
                pc:SetControlRotation({Pitch=st.pitch,Yaw=st.ctrl0.Yaw,Roll=0})
                if now-st.t>=1.0 then st.phase='sample'; st.t=now end
            elseif st.phase=='sample' then
                if now-st.t<0.15 then return end
                st.t=now
                local cm=pc.PlayerCameraManager
                local camf=ml():GetForwardVector(cm:GetCameraRotation())
                local m=M.measure(body(mesh),rifle_pts(rifle),camf,st.base)
                st.samples[#st.samples+1]=m
                if #st.samples>=8 then
                    st.cam_pitch=cm:GetCameraRotation().Pitch
                    st.sh0r,st.sh0l=shoulders(mesh)
                    local ppi=mesh:GetPostProcessInstance()
                    st.aimrot=g.try(function() local r=ppi.AimRot; return {Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll} end)
                    if st.aimrot then pcall(function() ppi.AimRot={Pitch=0,Yaw=0,Roll=0} end) end
                    st.t=now; st.phase='aimrot'
                end
            elseif st.phase=='aimrot' then
                if now-st.t<0.5 then return end
                local r1,l1=shoulders(mesh)
                local shift=math.max(M.len(M.sub(r1,st.sh0r)),M.len(M.sub(l1,st.sh0l)))
                if st.aimrot then pcall(function() mesh:GetPostProcessInstance().AimRot=st.aimrot end) end
                st.lines[#st.lines+1]=('g1,%+d,camera pitch %.1f, AimRot was %s, shoulders moved %.2f cm with AimRot 0'):format(
                    st.pitch,st.cam_pitch or 0/0,st.aimrot and ('%.1f/%.1f/%.1f'):format(st.aimrot.Pitch,st.aimrot.Yaw,st.aimrot.Roll) or 'unreadable',shift)
                g.log(st.lines[#st.lines])
                for _,l in ipairs(judge(st.pitch,st.samples,st.aimrot and shift or nil)) do st.lines[#st.lines+1]=l end
                local okc,ec=pcall(capture,pc,p,st.pitch,body(mesh))
                if not okc then g.log('g1 pictures: '..tostring(ec)) end
                st.phase='set'
            end
        end)
        if not ok then g.log('g1 error: '..tostring(e)); st.done=true; pcall(function() if st.ctrl0 then pc:SetControlRotation(st.ctrl0) end end) end
    end
    return self
end

return G1
