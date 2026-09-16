-- The same twenty-joint rig is used by all courier outfits and the officer.
local rig = require('rig')
local identity = Mat4.identity()
local function pose(seconds: number, state: number, speed: number): {Mat4}
    local cycle = seconds * (speed / 12) * 9
    local swing = math.sin(cycle)
    local angles = table.create(20, 0)
    local rootY = 0.025 * math.cos(cycle*2)
    local lean = .10
    if state == 0 then
        rootY = math.sin(seconds*2)*.008
        lean = 0
    elseif state == 1 or state == 8 then
        -- Two-bone leg IK: each planted foot travels backwards at a steady pace.
        for _, hip in {13,16} do
            local phase = (cycle/(2*math.pi)+(if hip==13 then 0 else .5))%1
            local z = if phase < .6 then .35-phase/.6*.7 else -.35+(phase-.6)/.4*.7
            local y = -.79 + (if phase < .6 then 0 else math.sin((phase-.6)/.4*math.pi)*.23)
            local d = math.clamp(math.sqrt(z*z+y*y),.12,.825)
            angles[hip] = -math.atan2(z,-y)-math.acos(math.clamp((.44*.44+d*d-.39*.39)/(2*.44*d),-1,1))
            angles[hip+1] = math.pi-math.acos(math.clamp((.44*.44+.39*.39-d*d)/(2*.44*.39),-1,1))
            angles[hip+2] = -angles[hip]-angles[hip+1]
        end
        angles[7]=swing*.65; angles[10]=-swing*.65
        angles[8]=-.8-math.max(0,-swing)*.3; angles[11]=-.8-math.max(0,swing)*.3
    elseif state == 2 or state == 3 then
        angles[13]=-.7; angles[14]=1.1; angles[16]=.35; angles[17]=.6
        angles[7]=-1.1; angles[10]=-.5; angles[8]=-.6; angles[11]=-.7
        lean=-.08
    elseif state == 4 then
        rootY=-.15; angles[13]=-.5; angles[14]=1; angles[16]=-.5; angles[17]=1
        lean=.25
    elseif state == 5 then
        rootY=-.62; lean=-.5
        angles[13]=-1.25; angles[16]=-1.15; angles[14]=.1; angles[17]=.25
        angles[7]=.5; angles[10]=.4; angles[8]=-.4; angles[11]=-.4
    elseif state == 6 then
        lean=.45; angles[7]=-1.4; angles[10]=-1.1; angles[14]=.4; angles[17]=.5
    elseif state == 7 then
        rootY=-.6; lean=1.3; angles[7]=-1.3; angles[10]=-1.3; angles[14]=.7; angles[17]=.7
    elseif state == 9 then
        angles[7]=-1.2; angles[10]=-1.2; angles[8]=-.8; angles[11]=-.8
    end
    local world: {Mat4} = table.create(20, identity)
    local skins: {Mat4} = table.create(20, identity)
    for i,j in rig do
        local localPose=Mat4.fromTranslation(j[2],j[3],j[4])*Mat4.fromRotationX(angles[i])
        if i==1 then localPose=Mat4.fromTranslation(0,rootY,0)*Mat4.fromRotationX(lean) end
        if i==19 then localPose=localPose*Mat4.fromRotationX(math.sin(cycle*2)*.045) end
        local parent=if j[1]<0 then identity else world[j[1]+1]
        world[i]=parent*localPose
        skins[i]=world[i]*Mat4.fromTranslation(-j[5],-j[6],-j[7])
    end
    return skins
end
return pose
