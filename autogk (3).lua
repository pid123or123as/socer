-- GK Helper v55 — Advanced AI Defense with Enhanced Accuracy & Smart Positioning
-- Optimized for fast reaction, intelligent positioning, and improved shot blocking

local player = game.Players.LocalPlayer
local ws = workspace
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- V55 ENHANCED AI DEFENSE - OPTIMIZED CONFIGURATION
local CONFIG = {
    -- === BASIC SETTINGS ===
    ENABLED = false,
    
    -- === MOVEMENT ===
    SPEED = 38,
    STAND_DIST = 2.2,
    MIN_DIST = 0.6,
    MAX_CHASE_DIST = 35,
    
    -- === DISTANCES ===
    AGGRO_THRES = 28,
    DIVE_DIST = 10,
    ENDPOINT_DIVE = 2.8,
    TOUCH_RANGE = 6.5,
    NEAR_BALL_DIST = 5,
    CLOSE_THREAT_DIST = 2.5,
    
    -- === DEFENSE ZONE ===
    ZONE_DIST = 42,
    ZONE_WIDTH = 2.0,
    
    -- === THRESHOLDS ===
    DIVE_VEL_THRES = 18,
    JUMP_VEL_THRES = 32,
    HIGH_BALL_THRES = 5.2,
    JUMP_THRES = 4.0,
    GATE_COVERAGE = 1.05,
    CENTER_BIAS_DIST = 16,
    LATERAL_MAX_MULT = 0.45,
    
    -- === COOLDOWNS ===
    DIVE_COOLDOWN = 0.9,
    JUMP_COOLDOWN = 0.6,
    ATTACK_COOLDOWN = 1.0,
    
    -- === DIVE SETTINGS ===
    DIVE_SPEED = 42,
    DIVE_MAX_DURATION = 0.22,
    
    -- === REACTION SETTINGS ===
    REACTION_TIME = 0.12,
    ANTICIPATION_DIST = 1.2,
    PREDICTION_AGGRESSION = 1.8,
    
    -- === POSITIONING ===
    SIDE_BIAS = 0.65,
    CORNER_BIAS = 0.65,
    ADVANCE_MULTIPLIER = 1.3,
    RETREAT_SPEED = 28,
    
    -- === VISUAL SETTINGS ===
    SHOW_TRAJECTORY = true,
    SHOW_ENDPOINT = true,
    SHOW_GOAL_CUBE = true,
    SHOW_ZONE = true,
    SHOW_BALL_BOX = true,
    SHOW_ATTACK_TARGET = true,
    SHOW_THREAT_LINES = true,
    
    -- === VISUAL COLORS ===
    TRAJECTORY_COLOR = Color3.fromRGB(0, 255, 255),
    ENDPOINT_COLOR = Color3.fromRGB(255, 255, 0),
    GOAL_CUBE_COLOR = Color3.fromRGB(255, 0, 0),
    ZONE_COLOR = Color3.fromRGB(0, 255, 0),
    BALL_BOX_SAFE_COLOR = Color3.fromRGB(0, 255, 0),
    BALL_BOX_THREAT_COLOR = Color3.fromRGB(255, 0, 0),
    BALL_BOX_HIGH_COLOR = Color3.fromRGB(255, 255, 0),
    BALL_BOX_NORMAL_COLOR = Color3.fromRGB(0, 200, 255),
    ATTACK_TARGET_COLOR = Color3.fromRGB(255, 105, 180),
    THREAT_LINE_COLOR = Color3.fromRGB(255, 50, 50),
    
    -- === ROTATION ===
    ROT_SMOOTH = 0.85,
    
    -- === ADVANCED DEFENSE ===
    BALL_INTERCEPT_RANGE = 3.5,
    MIN_INTERCEPT_TIME = 0.06,
    ADVANCE_DISTANCE = 2.8,
    DIVE_LOOK_AHEAD = 0.15,
    BLOCK_ANGLE = 45,
    
    -- === ATTACK SETTINGS ===
    PRIORITY = "defense",
    AUTO_ATTACK_IN_ZONE = true,
    ATTACK_DISTANCE = 25,
    ATTACK_PREDICT_TIME = 0.10,
    AGGRESSIVE_MODE = false,
    PRESS_DISTANCE = 12,
    
    -- === PREDICTION SETTINGS ===
    PRED_STEPS = 120,
    CURVE_MULT = 45,
    DT = 1/120,
    GRAVITY = 112,
    DRAG = 0.987,
    BOUNCE_XZ = 0.76,
    BOUNCE_Y = 0.68
}

-- Module state
local moduleState = {
    enabled = false,
    lastDiveTime = 0,
    lastJumpTime = 0,
    lastAttackTime = 0,
    isDiving = false,
    endpointRadius = 3.0,
    currentTargetType = nil,
    frameCounter = 0,
    cachedPoints = nil,
    lastBallVelMag = 0,
    isGoalkeeper = false,
    lastGoalkeeperCheck = 0,
    currentBV = nil,
    currentGyro = nil,
    smoothCFrame = nil,
    visualObjects = {},
    heartbeatConnection = nil,
    uiElements = {},
    attackTargetHistory = {},
    predictedEnemyPositions = {},
    currentAttackTarget = nil,
    attackTargetVisible = false,
    colorPickers = {},
    lastShotTime = 0,
    
    -- Enhanced decision making
    threatAnalysis = {
        lastThreatPos = nil,
        threatDirection = nil,
        threatSpeed = 0,
        isCloseRange = false,
        isCornerKick = false,
        shotAngle = 0,
        predictedEndHeight = 0
    },
    positioning = {
        optimalPosition = nil,
        lastSideChoice = 0,
        sideBiasTimer = 0,
        advanceLevel = 0,
        retreating = false
    },
    
    -- Physics control
    divePhysics = {
        activeBV = nil,
        activeGyro = nil,
        diveStartTime = 0
    }
}

-- Global variables
local GoalCFrame, GoalForward, GoalWidth = nil, nil, 0
local maxDistFromGoal = 45

-- Create visuals function
local function createVisuals()
    for _, objList in pairs(moduleState.visualObjects) do
        if type(objList) == "table" then
            for _, drawing in pairs(objList) do
                if drawing and drawing.Remove then
                    pcall(function() drawing:Remove() end)
                end
            end
        end
    end
    moduleState.visualObjects = {}
    
    if CONFIG.SHOW_GOAL_CUBE then
        moduleState.visualObjects.GoalCube = {}
        for i = 1, 12 do 
            local line = Drawing.new("Line")
            line.Thickness = 4 
            line.Transparency = 0.5
            line.Visible = false
            line.Color = CONFIG.GOAL_CUBE_COLOR
            moduleState.visualObjects.GoalCube[i] = line
        end
    end
    
    if CONFIG.SHOW_ZONE then
        moduleState.visualObjects.LimitCube = {}
        for i = 1, 12 do 
            local line = Drawing.new("Line")
            line.Thickness = 4 
            line.Transparency = 0.5
            line.Visible = false
            line.Color = CONFIG.ZONE_COLOR
            moduleState.visualObjects.LimitCube[i] = line
        end
    end
    
    if CONFIG.SHOW_BALL_BOX then
        moduleState.visualObjects.BallBox = {}
        for i = 1, 12 do 
            local line = Drawing.new("Line")
            line.Thickness = 4 
            line.Transparency = 0.5
            line.Visible = false
            moduleState.visualObjects.BallBox[i] = line
        end
    end
    
    if CONFIG.SHOW_TRAJECTORY then
        moduleState.visualObjects.trajLines = {}
        for i = 1, CONFIG.PRED_STEPS do
            local line = Drawing.new("Line")
            line.Thickness = 2.5 
            line.Color = Color3.fromHSV(i / CONFIG.PRED_STEPS, 1, 1)
            line.Transparency = 0.45
            line.Visible = false
            moduleState.visualObjects.trajLines[i] = line
        end
    end
    
    if CONFIG.SHOW_ENDPOINT then
        moduleState.visualObjects.endpointLines = {}
        for i = 1, 24 do
            local line = Drawing.new("Line")
            line.Thickness = 3 
            line.Color = CONFIG.ENDPOINT_COLOR
            line.Transparency = 0.5
            line.Visible = false
            moduleState.visualObjects.endpointLines[i] = line
        end
    end
    
    if CONFIG.SHOW_ATTACK_TARGET then
        moduleState.visualObjects.attackTarget = {}
        for i = 1, 36 do
            local line = Drawing.new("Line")
            line.Thickness = 3 
            line.Color = CONFIG.ATTACK_TARGET_COLOR
            line.Transparency = 0.7
            line.Visible = false
            moduleState.visualObjects.attackTarget[i] = line
        end
    end
    
    if CONFIG.SHOW_THREAT_LINES then
        moduleState.visualObjects.threatLines = {}
        for i = 1, 4 do
            local line = Drawing.new("Line")
            line.Thickness = 2
            line.Color = CONFIG.THREAT_LINE_COLOR
            line.Transparency = 0.8
            line.Visible = false
            moduleState.visualObjects.threatLines[i] = line
        end
    end
end

-- Update all visual colors
local function updateVisualColors()
    if moduleState.visualObjects.GoalCube then
        for _, line in ipairs(moduleState.visualObjects.GoalCube) do
            if line then
                line.Color = CONFIG.GOAL_CUBE_COLOR
            end
        end
    end
    
    if moduleState.visualObjects.LimitCube then
        for _, line in ipairs(moduleState.visualObjects.LimitCube) do
            if line then
                line.Color = CONFIG.ZONE_COLOR
            end
        end
    end
    
    if moduleState.visualObjects.endpointLines then
        for _, line in ipairs(moduleState.visualObjects.endpointLines) do
            if line then
                line.Color = CONFIG.ENDPOINT_COLOR
            end
        end
    end
    
    if moduleState.visualObjects.attackTarget then
        for _, line in ipairs(moduleState.visualObjects.attackTarget) do
            if line then
                line.Color = CONFIG.ATTACK_TARGET_COLOR
            end
        end
    end
    
    if moduleState.visualObjects.threatLines then
        for _, line in ipairs(moduleState.visualObjects.threatLines) do
            if line then
                line.Color = CONFIG.THREAT_LINE_COLOR
            end
        end
    end
    
    if moduleState.visualObjects.trajLines then
        local baseH, baseS, baseV = CONFIG.TRAJECTORY_COLOR:ToHSV()
        for i, line in ipairs(moduleState.visualObjects.trajLines) do
            if line then
                local hue = (baseH + (i / CONFIG.PRED_STEPS) * 0.3) % 1
                line.Color = Color3.fromHSV(hue, baseS, baseV)
            end
        end
    end
end

local function clearAllVisuals()
    for _, objList in pairs(moduleState.visualObjects) do
        if type(objList) == "table" then
            for _, drawing in pairs(objList) do
                if drawing then
                    pcall(function()
                        drawing.Visible = false
                        drawing:Remove()
                    end)
                end
            end
        end
    end
    moduleState.visualObjects = {}
    moduleState.attackTargetVisible = false
    moduleState.currentAttackTarget = nil
end

local function hideAllVisuals()
    for _, objList in pairs(moduleState.visualObjects) do
        if type(objList) == "table" then
            for _, drawing in pairs(objList) do
                if drawing then
                    drawing.Visible = false
                end
            end
        end
    end
    moduleState.attackTargetVisible = false
end

-- Check if goalkeeper
local function checkIfGoalkeeper()
    if tick() - moduleState.lastGoalkeeperCheck < 0.3 then return moduleState.isGoalkeeper end
    
    moduleState.lastGoalkeeperCheck = tick()
    local isHPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("HPG") and ws.Bools.HPG.Value == player
    local isAPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("APG") and ws.Bools.APG.Value == player
    
    local wasGoalkeeper = moduleState.isGoalkeeper
    moduleState.isGoalkeeper = isHPG or isAPG
    
    if wasGoalkeeper and not moduleState.isGoalkeeper then
        hideAllVisuals()
        if moduleState.currentBV then pcall(function() moduleState.currentBV:Destroy() end) moduleState.currentBV = nil end
        if moduleState.currentGyro then pcall(function() moduleState.currentGyro:Destroy() end) moduleState.currentGyro = nil end
        if moduleState.divePhysics.activeBV then pcall(function() moduleState.divePhysics.activeBV:Destroy() end) moduleState.divePhysics.activeBV = nil end
        if moduleState.divePhysics.activeGyro then pcall(function() moduleState.divePhysics.activeGyro:Destroy() end) moduleState.divePhysics.activeGyro = nil end
    end
    
    if moduleState.isGoalkeeper and not wasGoalkeeper and moduleState.enabled then
        createVisuals()
    end
    
    return moduleState.isGoalkeeper
end

-- Goal update with caching
local lastGoalUpdate = 0
local goalCacheValid = false

local function updateGoals()
    if tick() - lastGoalUpdate < 0.8 and goalCacheValid then return true end
    
    if not checkIfGoalkeeper() then return false end
    
    local isHPG = ws.Bools.HPG.Value == player
    local isAPG = ws.Bools.APG.Value == player
    
    local posModelName = isHPG and "HomePosition" or "AwayPosition"
    local posModel = ws:FindFirstChild(posModelName)
    if not posModel then return false end
    
    local parts = {}
    for _, obj in posModel:GetDescendants() do 
        if obj:IsA("BasePart") then table.insert(parts, obj) end 
    end
    if #parts == 0 then return false end
    
    local center = Vector3.new()
    for _, part in pairs(parts) do center = center + part.Position end 
    center = center / #parts
    
    local goalName = isHPG and "HomeGoal" or "AwayGoal"
    local goal = ws:FindFirstChild(goalName)
    
    if goal and goal:FindFirstChild("Frame") then
        local frame = goal.Frame
        local left = frame:FindFirstChild("LeftPost")
        local right = frame:FindFirstChild("RightPost")
        
        if left and right then
            local gcenter = (left.Position + right.Position) / 2
            local rightDir = (right.Position - left.Position).Unit
            local fieldDir = center - gcenter
            fieldDir = fieldDir - fieldDir:Dot(rightDir) * rightDir  
            fieldDir = Vector3.new(fieldDir.X, 0, fieldDir.Z)
            
            local fwdMag = fieldDir.Magnitude
            if fwdMag > 0.1 then
                GoalForward = fieldDir.Unit
            else
                GoalForward = rightDir:Cross(Vector3.new(0,1,0)).Unit
            end
            
            local minDist, maxDist = math.huge, -math.huge
            for _, part in pairs(parts) do
                local rel = part.Position - gcenter  
                local dist = rel:Dot(GoalForward)
                minDist = math.min(minDist, dist)
                maxDist = math.max(maxDist, dist)
            end
            
            if maxDist - minDist < 8 or maxDist < 8 then
                GoalForward = -GoalForward
                minDist, maxDist = math.huge, -math.huge
                for _, part in pairs(parts) do
                    local rel = part.Position - gcenter
                    local dist = rel:Dot(GoalForward)
                    minDist = math.min(minDist, dist)
                    maxDist = math.max(maxDist, dist)
                end
            end
            
            GoalCFrame = CFrame.fromMatrix(gcenter, rightDir, Vector3.new(0,1,0), -GoalForward)
            GoalWidth = (right.Position - left.Position).Magnitude
            maxDistFromGoal = math.max(30, maxDist - minDist + 12)
            
            lastGoalUpdate = tick()
            goalCacheValid = true
            return true
        end
    end
    return false
end

-- Draw functions remain the same (drawCube, drawFlatZone, drawEndpoint, drawAttackTarget)
local function drawCube(cube, cf, size, color)
    if not cube or not cf or not cf.Position then 
        if cube then
            for _, l in ipairs(cube) do 
                if l then l.Visible = false end 
            end 
        end
        return 
    end
    
    local cam = ws.CurrentCamera
    if not cam then return end
    
    local h = size / 2
    local corners = {
        cf * Vector3.new(-h.X, -h.Y, -h.Z), cf * Vector3.new( h.X, -h.Y, -h.Z), 
        cf * Vector3.new( h.X,  h.Y, -h.Z), cf * Vector3.new(-h.X,  h.Y, -h.Z),
        cf * Vector3.new(-h.X, -h.Y,  h.Z), cf * Vector3.new( h.X, -h.Y,  h.Z), 
        cf * Vector3.new( h.X,  h.Y,  h.Z), cf * Vector3.new(-h.X,  h.Y,  h.Z)
    }
    
    local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    
    for i, e in ipairs(edges) do
        local a, b = corners[e[1]], corners[e[2]]
        local sa, sb = cam:WorldToViewportPoint(a), cam:WorldToViewportPoint(b)
        local l = cube[i]
        
        if l then
            l.From = Vector2.new(sa.X, sa.Y) 
            l.To = Vector2.new(sb.X, sb.Y) 
            l.Color = color or l.Color or Color3.new(1,1,1)
            l.Visible = sa.Z > 0 and sb.Z > 0
        end
    end
end

local function drawFlatZone()
    if not (GoalCFrame and GoalForward and GoalWidth) or not moduleState.visualObjects.LimitCube then 
        if moduleState.visualObjects.LimitCube then
            for _, l in ipairs(moduleState.visualObjects.LimitCube) do 
                if l then l.Visible = false end 
            end 
        end
        return 
    end
    
    local center = GoalCFrame.Position + GoalForward * (CONFIG.ZONE_DIST / 2)
    local flatCF = CFrame.new(center.X, 0, center.Z) * GoalCFrame.Rotation
    drawCube(moduleState.visualObjects.LimitCube, flatCF, Vector3.new(GoalWidth * CONFIG.ZONE_WIDTH, 0.2, CONFIG.ZONE_DIST), CONFIG.ZONE_COLOR)
end

local function drawEndpoint(pos)
    if not pos or not moduleState.visualObjects.endpointLines then 
        if moduleState.visualObjects.endpointLines then
            for _, l in ipairs(moduleState.visualObjects.endpointLines) do 
                if l then l.Visible = false end 
            end 
        end
        return 
    end
    
    local cam = ws.CurrentCamera 
    if not cam then return end
    
    local step = math.pi * 2 / 24
    for i = 1, 24 do
        local a1, a2 = (i-1)*step, i*step
        local p1 = pos + Vector3.new(math.cos(a1)*moduleState.endpointRadius, 0, math.sin(a1)*moduleState.endpointRadius)
        local p2 = pos + Vector3.new(math.cos(a2)*moduleState.endpointRadius, 0, math.sin(a2)*moduleState.endpointRadius)
        local s1, s2 = cam:WorldToViewportPoint(p1), cam:WorldToViewportPoint(p2)
        local l = moduleState.visualObjects.endpointLines[i]
        
        if l then
            l.From = Vector2.new(s1.X, s1.Y) 
            l.To = Vector2.new(s2.X, s2.Y)
            l.Visible = s1.Z > 0 and s2.Z > 0
        end
    end
end

local function drawAttackTarget(pos)
    if not pos or not moduleState.visualObjects.attackTarget then 
        if moduleState.visualObjects.attackTarget then
            for _, l in ipairs(moduleState.visualObjects.attackTarget) do 
                if l then l.Visible = false end 
            end 
        end
        moduleState.attackTargetVisible = false
        return 
    end
    
    local cam = ws.CurrentCamera 
    if not cam then return end
    
    local footPos = Vector3.new(pos.X, 0.5, pos.Z)
    
    local step = math.pi * 2 / 36
    local radius = 2.0
    
    for i = 1, 36 do
        local a1, a2 = (i-1)*step, i*step
        local p1 = footPos + Vector3.new(math.cos(a1)*radius, 0.1, math.sin(a1)*radius)
        local p2 = footPos + Vector3.new(math.cos(a2)*radius, 0.1, math.sin(a2)*radius)
        local s1, s2 = cam:WorldToViewportPoint(p1), cam:WorldToViewportPoint(p2)
        local l = moduleState.visualObjects.attackTarget[i]
        
        if l then
            l.From = Vector2.new(s1.X, s1.Y) 
            l.To = Vector2.new(s2.X, s2.Y)
            l.Visible = s1.Z > 0 and s2.Z > 0
        end
    end
    
    moduleState.attackTargetVisible = true
end

local function drawThreatLine(fromPos, toPos)
    if not fromPos or not toPos or not moduleState.visualObjects.threatLines then 
        if moduleState.visualObjects.threatLines then
            for _, l in ipairs(moduleState.visualObjects.threatLines) do 
                l.Visible = false 
            end 
        end
        return 
    end
    
    local cam = ws.CurrentCamera 
    if not cam then return end
    
    local s1 = cam:WorldToViewportPoint(fromPos)
    local s2 = cam:WorldToViewportPoint(toPos)
    
    local line = moduleState.visualObjects.threatLines[1]
    if line and s1.Z > 0 and s2.Z > 0 then
        line.From = Vector2.new(s1.X, s1.Y)
        line.To = Vector2.new(s2.X, s2.Y)
        line.Visible = true
    end
end

local function hideAttackTarget()
    if moduleState.visualObjects.attackTarget then
        for _, l in ipairs(moduleState.visualObjects.attackTarget) do 
            if l then l.Visible = false end 
        end
    end
    moduleState.attackTargetVisible = false
    moduleState.currentAttackTarget = nil
end

-- ENHANCED Trajectory prediction with better accuracy
local function predictTrajectory(ball)
    local points = {ball.Position}
    local pos, vel = ball.Position, ball.Velocity
    local dt = CONFIG.DT
    local gravity = CONFIG.GRAVITY
    local drag = CONFIG.DRAG
    local steps = CONFIG.PRED_STEPS
    local spinCurve = Vector3.new(0,0,0)
    
    pcall(function()
        if ws.Bools.Curve and ws.Bools.Curve.Value then 
            spinCurve = ball.CFrame.RightVector * CONFIG.CURVE_MULT * 0.03
        end
        if ws.Bools.Header and ws.Bools.Header.Value then 
            spinCurve = spinCurve + Vector3.new(0, 22, 0) 
        end
    end)
    
    for i = 1, steps do
        local curveFade = 1 - (i/steps) * 0.7
        vel = vel * drag + spinCurve * dt * curveFade
        vel = vel - Vector3.new(0, gravity * dt * 1.04, 0)
        pos = pos + vel * dt
        
        if pos.Y < 0.5 then
            pos = Vector3.new(pos.X, 0.5, pos.Z)
            vel = Vector3.new(vel.X * CONFIG.BOUNCE_XZ, math.abs(vel.Y) * CONFIG.BOUNCE_Y, vel.Z * CONFIG.BOUNCE_XZ)
        end
        table.insert(points, pos)
    end
    return points
end

-- IMPROVED Movement to target with smoother acceleration
local function moveToTarget(root, targetPos, speedMult)
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1,0,1)
    if dirVec.Magnitude < CONFIG.MIN_DIST then return end
    
    local speed = CONFIG.SPEED * (speedMult or 1.0)
    
    moduleState.currentBV = Instance.new("BodyVelocity", root)
    moduleState.currentBV.MaxForce = Vector3.new(4e5, 0, 4e5)
    moduleState.currentBV.Velocity = dirVec.Unit * speed
    game.Debris:AddItem(moduleState.currentBV, 0.6)
    
    if ts then
        ts:Create(moduleState.currentBV, tweenInfo, {Velocity = Vector3.new()}):Play()
    end
end

-- IMPROVED Smooth rotation
local function rotateSmooth(root, targetPos, isOwner, isDivingNow, ballVel)
    if isOwner or isDivingNow then 
        if moduleState.currentGyro then 
            pcall(function() moduleState.currentGyro:Destroy() end) 
            moduleState.currentGyro = nil
        end
        return 
    end
    
    if not moduleState.smoothCFrame then moduleState.smoothCFrame = root.CFrame end
    
    local finalLookPos = targetPos
    
    local targetLook = CFrame.lookAt(root.Position, finalLookPos)
    moduleState.smoothCFrame = moduleState.smoothCFrame:Lerp(targetLook, CONFIG.ROT_SMOOTH)
    
    if moduleState.currentGyro then 
        pcall(function() moduleState.currentGyro:Destroy() end) 
        moduleState.currentGyro = nil
    end
    
    moduleState.currentGyro = Instance.new("BodyGyro", root)
    moduleState.currentGyro.Name = "GKRoto"
    moduleState.currentGyro.P = 3200000
    moduleState.currentGyro.MaxTorque = Vector3.new(0, 4e6, 0)
    moduleState.currentGyro.CFrame = moduleState.smoothCFrame
    game.Debris:AddItem(moduleState.currentGyro, 0.15)
end

-- Jump function
local function playJumpAnimation(hum)
    pcall(function()
        local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK.Jump)
        anim.Priority = Enum.AnimationPriority.Action4
        anim:Play()
    end)
end

local function forceJump(hum)
    local oldPower = hum.JumpPower
    hum.JumpPower = 34
    hum.Jump = true
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    playJumpAnimation(hum)
    task.wait(0.03)
    hum.JumpPower = oldPower
end

-- ENHANCED Smart positioning
local function getSmartPosition(defenseBase, rightVec, lateral, goalWidth, threatLateral, enemyLateral, isAggro, ballPos, ballVel)
    local maxLateral = goalWidth * CONFIG.LATERAL_MAX_MULT * CONFIG.GATE_COVERAGE
    local baseLateral = math.clamp(lateral, -maxLateral, maxLateral)
    
    -- Улучшенная логика угрозы
    if threatLateral ~= 0 then 
        local threatWeight = 0.98
        
        if ballPos and ballVel then
            local ballSpeed = ballVel.Magnitude
            local ballDist = (ballPos - GoalCFrame.Position).Magnitude
            
            if ballDist < 18 then
                threatWeight = 0.995
            elseif ballSpeed > 30 then
                threatWeight = 0.99
            end
            
            -- Учитываем угол удара
            local toGoal = (GoalCFrame.Position - ballPos).Unit
            local shotAngle = math.deg(math.acos(math.clamp(ballVel.Unit:Dot(toGoal), -1, 1)))
            
            if shotAngle < 25 then
                threatWeight = threatWeight + 0.02
            end
        end
        
        baseLateral = threatLateral * threatWeight 
    end
    
    -- Улучшенная логика противника
    if enemyLateral ~= 0 and isAggro then 
        local enemyWeight = 0.88 + (moduleState.positioning.advanceLevel * 0.1)
        baseLateral = enemyLateral * enemyWeight 
    end
    
    -- Антиципация для ударов под углом
    if ballPos and ballVel and threatLateral ~= 0 then
        local ballToGoal = (GoalCFrame.Position - ballPos).Unit
        local rightDot = ballToGoal:Dot(rightVec)
        local velDot = ballVel.Unit:Dot(rightVec)
        
        if math.abs(rightDot) > 0.25 or math.abs(velDot) > 0.25 then
            local anticipation = (rightDot + velDot * 0.5) * CONFIG.ANTICIPATION_DIST * CONFIG.PREDICTION_AGGRESSION
            baseLateral = baseLateral + anticipation
        end
    end
    
    local finalLateral = math.clamp(baseLateral, -maxLateral, maxLateral)
    local finalPos = Vector3.new(defenseBase.X + rightVec.X * finalLateral, defenseBase.Y, defenseBase.Z + rightVec.Z * finalLateral)
    
    moduleState.positioning.optimalPosition = finalPos
    
    return finalPos
end

local function clearTrajAndEndpoint()
    if moduleState.visualObjects.trajLines then
        for _, l in ipairs(moduleState.visualObjects.trajLines) do 
            if l then l.Visible = false end 
        end
    end
    
    if moduleState.visualObjects.endpointLines then
        for _, l in ipairs(moduleState.visualObjects.endpointLines) do 
            if l then l.Visible = false end 
        end
    end
    
    if moduleState.visualObjects.threatLines then
        for _, l in ipairs(moduleState.visualObjects.threatLines) do 
            l.Visible = false 
        end
    end
end

-- ENHANCED Find intercept point
local function findBestInterceptPoint(rootPos, ballPos, ballVel, points)
    if not points or #points < 2 then return nil end
    
    local bestPoint = nil
    local bestScore = math.huge
    
    for i = 2, math.min(#points, 60) do
        local point = points[i]
        local distToPoint = (rootPos - point).Magnitude
        
        -- Быстрая проверка на досягаемость
        if distToPoint < 15 then
            local ballTravelDist = 0
            for j = 1, i-1 do
                ballTravelDist = ballTravelDist + (points[j+1] - points[j]).Magnitude
            end
            
            local ballSpeed = ballVel.Magnitude
            local timeToPoint = ballTravelDist / math.max(1, ballSpeed)
            local timeToReach = distToPoint / CONFIG.SPEED
            
            if timeToReach < timeToPoint - CONFIG.MIN_INTERCEPT_TIME then
                local goalDist = (point - GoalCFrame.Position):Dot(GoalForward)
                local lateralDist = math.abs((point - GoalCFrame.Position):Dot(GoalCFrame.RightVector))
                
                -- Улучшенная система очков
                local score = distToPoint * 0.7 + goalDist * 0.3 + lateralDist * 0.1
                
                if score < bestScore then
                    bestScore = score
                    bestPoint = point
                end
            end
        end
    end
    
    return bestPoint
end

-- Check if in defense zone
local function isInDefenseZone(position)
    if not (GoalCFrame and GoalForward) then return false end
    
    local relPos = position - GoalCFrame.Position
    local distForward = relPos:Dot(GoalForward)
    local distLateral = math.abs(relPos:Dot(GoalCFrame.RightVector))
    
    return distForward > 0 and distForward < CONFIG.ZONE_DIST and 
           distLateral < (GoalWidth * CONFIG.ZONE_WIDTH) / 2
end

-- ENHANCED Predict enemy position
local function predictEnemyPosition(enemyRoot)
    if not enemyRoot then return enemyRoot.Position end
    
    local currentTime = tick()
    local enemyId = tostring(enemyRoot.Parent:GetDebugId())
    
    if not moduleState.attackTargetHistory[enemyId] then
        moduleState.attackTargetHistory[enemyId] = {}
    end
    
    local history = moduleState.attackTargetHistory[enemyId]
    
    table.insert(history, {
        time = currentTime,
        position = enemyRoot.Position,
        velocity = enemyRoot.Velocity
    })
    
    while #history > 0 and currentTime - history[1].time > 0.4 do
        table.remove(history, 1)
    end
    
    if #history >= 2 then
        local avgVelocity = Vector3.new(0, 0, 0)
        local recentVelocity = enemyRoot.Velocity
        local count = 0
        
        for i = 2, #history do
            local timeDiff = history[i].time - history[i-1].time
            if timeDiff > 0 then
                local vel = (history[i].position - history[i-1].position) / timeDiff
                avgVelocity = avgVelocity + vel
                count = count + 1
            end
        end
        
        if count > 0 then
            avgVelocity = avgVelocity / count
            -- Комбинация средней и текущей скорости для лучшего предсказания
            local combinedVel = (avgVelocity * 0.6 + recentVelocity * 0.4)
            local predictedPos = enemyRoot.Position + combinedVel * CONFIG.ATTACK_PREDICT_TIME
            
            moduleState.predictedEnemyPositions[enemyId] = predictedPos
            
            return predictedPos
        end
    end
    
    return enemyRoot.Position
end

-- ENHANCED Find attack target with priority
local function findAttackTarget(rootPos, ball)
    local bestTarget = nil
    local bestScore = -math.huge
    local goalCenter = GoalCFrame.Position
    
    for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local targetRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = otherPlayer.Character:FindFirstChild("Humanoid")
            
            if targetRoot and targetHum and targetHum.Health > 0 then
                local isEnemy = true
                pcall(function()
                    if ws.Bools.HPG.Value == otherPlayer or ws.Bools.APG.Value == otherPlayer then
                        isEnemy = false
                    end
                end)
                
                if isEnemy then
                    local targetPos = targetRoot.Position
                    local distToTarget = (rootPos - targetPos).Magnitude
                    local distToGoal = (goalCenter - targetPos).Magnitude
                    local inZone = isInDefenseZone(targetPos)
                    
                    local score = 0
                    
                    -- Близость к воротам (самый важный фактор)
                    if distToGoal < 25 then
                        score = score + 80 * (1 - distToGoal / 25)
                    end
                    
                    -- В зоне защиты
                    if inZone then
                        score = score + 60
                    end
                    
                    -- Контролирует мяч
                    local hasBall = false
                    pcall(function()
                        if ball:FindFirstChild("creator") and ball.creator.Value == otherPlayer then
                            hasBall = true
                            score = score + 100
                        end
                    end)
                    
                    -- Смотрит на ворота
                    local targetLook = targetRoot.CFrame.LookVector
                    local toGoalDir = (goalCenter - targetPos).Unit
                    local angleToGoal = math.deg(math.acos(math.clamp(targetLook:Dot(toGoalDir), -1, 1)))
                    
                    if angleToGoal < CONFIG.BLOCK_ANGLE then
                        score = score + 40 * (1 - angleToGoal / CONFIG.BLOCK_ANGLE)
                    end
                    
                    -- Близко к вратарю
                    if distToTarget < 20 then
                        score = score + 30 * (1 - distToTarget / 20)
                    end
                    
                    -- Двигается к воротам
                    local velTowardGoal = targetRoot.Velocity:Dot(toGoalDir)
                    if velTowardGoal > 5 then
                        score = score + 20
                    end
                    
                    if CONFIG.PRIORITY == "attack" then
                        score = score * 1.3
                    end
                    
                    if score > bestScore then
                        bestScore = score
                        bestTarget = otherPlayer
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- ENHANCED Smart block enemy - более агрессивный подход
local function smartBlockEnemyView(root, targetPlayer, ball)
    if tick() - moduleState.lastAttackTime < CONFIG.ATTACK_COOLDOWN then
        return false
    end
    
    if not targetPlayer or not targetPlayer.Character then
        hideAttackTarget()
        return false
    end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then 
        hideAttackTarget()
        return false 
    end
    
    moduleState.currentAttackTarget = targetPlayer
    
    local predictedEnemyPos = predictEnemyPosition(targetRoot)
    local distToTarget = (root.Position - targetRoot.Position).Magnitude
    local goalCenter = GoalCFrame.Position
    
    -- Определяем, насколько срочно нужно блокировать
    local isUrgent = distToTarget < 15
    local hasBall = false
    pcall(function()
        if ball:FindFirstChild("creator") and ball.creator.Value == targetPlayer then
            hasBall = true
        end
    end)
    
    -- Расчет позиции блокировки
    local enemyToGoal = (goalCenter - predictedEnemyPos).Unit
    local blockDistance = CONFIG.ATTACK_DISTANCE
    
    if hasBall then
        -- Если у врага мяч, подходим ближе
        blockDistance = math.max(8, math.min(blockDistance * 0.6, distToTarget * 0.7))
    elseif isUrgent then
        -- Срочная ситуация - ближе
        blockDistance = math.max(6, blockDistance * 0.8)
    end
    
    -- Позиция между врагом и воротами
    local blockPos = predictedEnemyPos + enemyToGoal * blockDistance
    
    -- Учитываем движение врага
    local enemyVelocity = targetRoot.Velocity
    local enemySpeed = enemyVelocity.Magnitude
    
    if enemySpeed > 3 then
        local moveDir = enemyVelocity.Unit
        local moveProjection = moveDir:Dot(enemyToGoal:Cross(Vector3.new(0, 1, 0)))
        
        if math.abs(moveProjection) > 0.3 then
            local sideOffset = moveDir * (enemySpeed * 0.08 * blockDistance)
            blockPos = blockPos + sideOffset
        end
    end
    
    -- Ограничиваем высоту
    blockPos = Vector3.new(blockPos.X, root.Position.Y, blockPos.Z)
    
    -- Если враг очень близко к воротам, идем в прессинг
    local distEnemyToGoal = (goalCenter - targetRoot.Position).Magnitude
    if distEnemyToGoal < 12 and hasBall then
        blockPos = predictedEnemyPos + enemyToGoal * math.max(5, blockDistance * 0.4)
        moduleState.positioning.advanceLevel = 1.0
    else
        moduleState.positioning.advanceLevel = math.max(0, 1 - (distEnemyToGoal / 30))
    end
    
    -- Визуализация
    if CONFIG.SHOW_ATTACK_TARGET and moduleState.enabled then
        drawAttackTarget(predictedEnemyPos)
        if CONFIG.SHOW_THREAT_LINES then
            drawThreatLine(root.Position, predictedEnemyPos)
        end
    end
    
    -- Двигаемся к позиции блокировки
    moveToTarget(root, blockPos, hasBall and 1.2 or 1.0)
    rotateSmooth(root, predictedEnemyPos, false, false, Vector3.new())
    
    -- Если враг с мячом рядом - активируем атаку
    if hasBall and distToTarget < CONFIG.PRESS_DISTANCE then
        moduleState.lastAttackTime = tick()
        return true
    end
    
    return false
end

-- ADVANCED Shot analysis
local function analyzeShotSituation(ballPos, ballVel, endpoint, rootPos, points)
    local analysis = {
        action = "stand",
        confidence = 0,
        reason = "",
        urgency = 0
    }
    
    if not ballPos or not endpoint then return analysis end
    
    local ballHeight = ballPos.Y
    local ballSpeed = ballVel.Magnitude
    local endpointHeight = endpoint.Y
    local distToEndpoint = (endpoint - rootPos).Magnitude
    local toEndpoint = (endpoint - rootPos).Unit
    local goalDist = (endpoint - GoalCFrame.Position):Dot(GoalForward)
    
    -- Вычисляем угрозу
    local isGoalThreat = goalDist < 2.5
    local isHighBall = ballHeight > CONFIG.HIGH_BALL_THRES
    local isEndpointHigh = endpointHeight > CONFIG.JUMP_THRES
    local isFastBall = ballSpeed > CONFIG.JUMP_VEL_THRES
    local isVeryFast = ballSpeed > 40
    
    -- Анализ угла
    local verticalAngle = math.deg(math.asin(math.clamp(ballVel.Y / math.max(ballSpeed, 0.1), -1, 1)))
    local isHighAngle = verticalAngle > 20
    local isLowAngle = verticalAngle < 10
    
    -- Срочность (0-1)
    analysis.urgency = math.clamp((ballSpeed / 50) * (1 - distToEndpoint / 20), 0, 1)
    
    -- Приоритет 1: Очень близкий быстрый мяч в створ - НЫРОК
    if distToEndpoint < CONFIG.ENDPOINT_DIVE and isFastBall and isGoalThreat then
        analysis.action = "dive"
        analysis.confidence = 0.95
        analysis.reason = "Срочный нырок - мяч близко к воротам"
        return analysis
    end
    
    -- Приоритет 2: Высокий мяч рядом - ПРЫЖОК
    if distToEndpoint < 8 and isEndpointHigh and isHighAngle then
        analysis.action = "jump"
        analysis.confidence = 0.9
        analysis.reason = "Высокий мяч - прыжок"
        return analysis
    end
    
    -- Приоритет 3: Быстрый мяч по центру - НЫРОК
    if distToEndpoint < CONFIG.DIVE_DIST and isFastBall and isGoalThreat and not isHighAngle then
        analysis.action = "dive"
        analysis.confidence = 0.85
        analysis.reason = "Быстрый низкий мяч - нырок"
        return analysis
    end
    
    -- Приоритет 4: Медленный мяч рядом - КАСАНИЕ
    if distToEndpoint < CONFIG.BALL_INTERCEPT_RANGE and ballSpeed < 18 then
        analysis.action = "touch"
        analysis.confidence = 0.8
        analysis.reason = "Медленный мяч - касание"
        return analysis
    end
    
    -- Приоритет 5: Высокий мяч с расстояния - ПОЗИЦИОНИРОВАНИЕ
    if isHighBall and verticalAngle > 25 then
        analysis.action = "position"
        analysis.confidence = 0.75
        analysis.reason = "Высокий мяч - позиционирование"
        return analysis
    end
    
    -- По умолчанию: активное позиционирование
    analysis.action = "advance"
    analysis.confidence = 0.7
    analysis.reason = "Активное позиционирование"
    
    return analysis
end

-- OPTIMIZED DIVE FUNCTION
local function performDive(root, hum, diveTarget)
    if moduleState.isDiving then return end
    
    moduleState.isDiving = true
    moduleState.lastDiveTime = tick()
    
    -- Clean up existing physics
    if moduleState.divePhysics.activeBV then 
        pcall(function() moduleState.divePhysics.activeBV:Destroy() end) 
        moduleState.divePhysics.activeBV = nil 
    end
    
    -- Определяем направление ныряния
    local relToGoal = diveTarget - GoalCFrame.Position
    local lateralDist = relToGoal:Dot(GoalCFrame.RightVector)
    local dir = lateralDist > 0 and "Right" or "Left"

    -- Fire server event
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir.."Dive", root.CFrame)
    end)

    -- Вычисляем направление ныряния
    local toTarget = (diveTarget - root.Position) * Vector3.new(1,0,1)
    local horizontalDir = toTarget.Magnitude > 0.1 and toTarget.Unit or GoalForward * -1
    
    -- Dive physics
    local diveSpeed = math.min(CONFIG.DIVE_SPEED, 35)
    moduleState.divePhysics.activeBV = Instance.new("BodyVelocity", root)
    moduleState.divePhysics.activeBV.MaxForce = Vector3.new(1000000, 0, 1000000)
    moduleState.divePhysics.activeBV.Velocity = horizontalDir * diveSpeed
    
    -- Short duration
    game.Debris:AddItem(moduleState.divePhysics.activeBV, CONFIG.DIVE_MAX_DURATION)
    
    -- Quick deceleration
    if ts then
        ts:Create(moduleState.divePhysics.activeBV, 
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
            {Velocity = Vector3.new()}
        ):Play()
    end

    -- Dive animation
    local lowDive = (diveTarget.Y <= 3.0)
    pcall(function()
        local animName = dir .. (lowDive and "LowDive" or "Dive")
        local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK[animName])
        anim.Priority = Enum.AnimationPriority.Action4
        anim:Play()
    end)

    -- Disable jumping during dive
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    
    -- Quick recovery
    task.delay(0.6, function()
        if hum and hum.Parent then
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        end
        
        if moduleState.divePhysics.activeBV then 
            pcall(function() 
                moduleState.divePhysics.activeBV.Velocity = Vector3.new()
                moduleState.divePhysics.activeBV:Destroy() 
            end) 
            moduleState.divePhysics.activeBV = nil 
        end
        
        moduleState.isDiving = false
    end)
end

-- ENHANCED Corner positioning
local function handleCornerPositioning(root, ballPos, ballVel)
    if not ballPos then return end
    
    local rightVec = GoalCFrame.RightVector
    local ballLateral = (ballPos - GoalCFrame.Position):Dot(rightVec)
    
    local sideChoice = ballLateral > 0 and 1 or -1
    moduleState.positioning.lastSideChoice = sideChoice
    
    -- Расчет позиции для углового
    local baseDist = CONFIG.STAND_DIST
    if ballVel then
        local ballSpeed = ballVel.Magnitude
        if ballSpeed > 30 then
            baseDist = baseDist * 1.3
        end
    end
    
    local lateralOffset = sideChoice * GoalWidth * 0.32 * CONFIG.CORNER_BIAS
    local basePos = GoalCFrame.Position + GoalForward * baseDist
    
    local targetPos = Vector3.new(
        basePos.X + rightVec.X * lateralOffset,
        root.Position.Y,
        basePos.Z + rightVec.Z * lateralOffset
    )
    
    moveToTarget(root, targetPos, 1.1)
    rotateSmooth(root, ballPos, false, false, ballVel or Vector3.new())
    
    return targetPos
end

-- ENHANCED Retreat function
local function retreatToGoal(root, speedMult)
    if not GoalCFrame then return end
    
    local retreatPos = GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST
    local distToGoal = (root.Position - retreatPos).Magnitude
    
    if distToGoal > 3 then
        moveToTarget(root, retreatPos, speedMult or 1.0)
        moduleState.positioning.retreating = true
        return true
    end
    
    moduleState.positioning.retreating = false
    return false
end

-- Cleanup function
local function cleanup()
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    if moduleState.currentGyro then 
        pcall(function() moduleState.currentGyro:Destroy() end) 
        moduleState.currentGyro = nil 
    end
    
    if moduleState.divePhysics.activeBV then 
        pcall(function() moduleState.divePhysics.activeBV:Destroy() end) 
        moduleState.divePhysics.activeBV = nil 
    end
    
    if moduleState.divePhysics.activeGyro then 
        pcall(function() moduleState.divePhysics.activeGyro:Destroy() end) 
        moduleState.divePhysics.activeGyro = nil 
    end
    
    clearAllVisuals()
    moduleState.isDiving = false
    moduleState.cachedPoints = nil
    moduleState.smoothCFrame = nil
    moduleState.attackTargetHistory = {}
    moduleState.predictedEnemyPositions = {}
    moduleState.currentAttackTarget = nil
    moduleState.attackTargetVisible = false
    moduleState.threatAnalysis = {
        lastThreatPos = nil,
        threatDirection = nil,
        threatSpeed = 0,
        isCloseRange = false,
        isCornerKick = false,
        shotAngle = 0,
        predictedEndHeight = 0
    }
    moduleState.positioning = {
        optimalPosition = nil,
        lastSideChoice = 0,
        sideBiasTimer = 0,
        advanceLevel = 0,
        retreating = false
    }
end

-- ENHANCED Main heartbeat cycle
local function startHeartbeat()
    moduleState.heartbeatConnection = rs.Heartbeat:Connect(function()
        if not moduleState.enabled then 
            hideAllVisuals()
            return 
        end
        
        moduleState.frameCounter = moduleState.frameCounter + 1
        
        if not checkIfGoalkeeper() then
            hideAllVisuals()
            if moduleState.currentBV then pcall(function() moduleState.currentBV:Destroy() end) moduleState.currentBV = nil end
            if moduleState.currentGyro then pcall(function() moduleState.currentGyro:Destroy() end) moduleState.currentGyro = nil end
            if moduleState.divePhysics.activeBV then pcall(function() moduleState.divePhysics.activeBV:Destroy() end) moduleState.divePhysics.activeBV = nil end
            return
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then 
            hideAllVisuals()
            return 
        end
        
        local root = char.HumanoidRootPart
        local hum = char.Humanoid
        local ball = ws:FindFirstChild("ball")
        
        if not ball then 
            clearTrajAndEndpoint()
            hideAttackTarget()
            if GoalCFrame then 
                retreatToGoal(root, 1.2)
            end
            moduleState.isDiving = false
            moduleState.currentTargetType = nil
            moduleState.cachedPoints = nil
            moduleState.currentAttackTarget = nil
            return 
        end
        
        if not updateGoals() then 
            clearTrajAndEndpoint()
            hideAttackTarget()
            return 
        end

        -- Visuals
        if CONFIG.SHOW_GOAL_CUBE and moduleState.visualObjects.GoalCube then
            drawCube(moduleState.visualObjects.GoalCube, GoalCFrame, Vector3.new(GoalWidth, 8, 2), CONFIG.GOAL_CUBE_COLOR)
        end
        
        if CONFIG.SHOW_ZONE then 
            drawFlatZone() 
        end

        local hasWeld = ball:FindFirstChild("playerWeld")
        local owner = ball:FindFirstChild("creator") and ball.creator.Value
        local isMyBall = owner == player
        local oRoot = nil
        local enemyDistFromLine = math.huge
        local enemyLateral = 0
        local distToEnemy = math.huge
        local isAggro = false
        local smartBlockActive = false
        local attackTargetPlayer = nil

        -- Атака и прессинг
        if CONFIG.PRIORITY == "attack" or CONFIG.AUTO_ATTACK_IN_ZONE then
            attackTargetPlayer = findAttackTarget(root.Position, ball)
            
            if attackTargetPlayer and CONFIG.AUTO_ATTACK_IN_ZONE then
                local targetRoot = attackTargetPlayer.Character and attackTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot and isInDefenseZone(targetRoot.Position) then
                    smartBlockActive = smartBlockEnemyView(root, attackTargetPlayer, ball)
                else
                    hideAttackTarget()
                end
            else
                hideAttackTarget()
            end
        else
            hideAttackTarget()
        end

        -- Анализ угрозы от владельца мяча
        if owner and owner ~= player and owner.Character then
            oRoot = owner.Character:FindFirstChild("HumanoidRootPart")
            if oRoot then
                local rel = oRoot.Position - GoalCFrame.Position
                enemyDistFromLine = rel:Dot(GoalForward)
                enemyLateral = rel:Dot(GoalCFrame.RightVector)
                distToEnemy = (root.Position - oRoot.Position).Magnitude
                isAggro = enemyDistFromLine < CONFIG.AGGRO_THRES and distToEnemy < CONFIG.MAX_CHASE_DIST
                
                -- Если враг с мячом близко к воротам - срочный прессинг
                if hasWeld and enemyDistFromLine < 15 then
                    if not smartBlockActive then
                        smartBlockActive = true
                        local predictedEnemyPos = predictEnemyPosition(oRoot)
                        local pressPos = predictedEnemyPos + GoalForward * 8
                        pressPos = Vector3.new(pressPos.X, root.Position.Y, pressPos.Z)
                        moveToTarget(root, pressPos, 1.3)
                        
                        if CONFIG.SHOW_ATTACK_TARGET then
                            drawAttackTarget(predictedEnemyPos)
                        end
                    end
                elseif not smartBlockActive and enemyDistFromLine < CONFIG.AGGRO_THRES then
                    -- Стандартное отслеживание врага
                    local predictedEnemyPos = predictEnemyPosition(oRoot)
                    local trackPos = GoalCFrame.Position + GoalForward * math.max(CONFIG.STAND_DIST, enemyDistFromLine * 0.5)
                    local lateralOffset = enemyLateral * 0.7
                    trackPos = trackPos + GoalCFrame.RightVector * lateralOffset
                    
                    moveToTarget(root, trackPos)
                end
            end
        end

        -- Агрессивный режим
        if CONFIG.AGGRESSIVE_MODE and owner and owner ~= player and oRoot and not smartBlockActive then
            local predictedPos = predictEnemyPosition(oRoot)
            local targetPos = predictedPos + GoalForward * CONFIG.ATTACK_DISTANCE
            moveToTarget(root, targetPos, 1.2)
            smartBlockActive = true
            
            if CONFIG.SHOW_ATTACK_TARGET then
                drawAttackTarget(predictedPos)
            end
        end

        -- Предсказание траектории
        local points, endpoint = nil, nil
        local threatLateral = 0
        local isShot = not hasWeld and owner ~= player
        local distEnd = math.huge
        local velMag = ball.Velocity.Magnitude
        local distBall = (root.Position - ball.Position).Magnitude
        local isThreat = false
        local timeToEndpoint = 999

        local freshShot = false
        if velMag > 20 and moduleState.lastBallVelMag <= 20 then
            freshShot = true
            moduleState.cachedPoints = nil
            moduleState.lastShotTime = tick()
            clearTrajAndEndpoint()
        end
        moduleState.lastBallVelMag = velMag

        if isShot and (moduleState.frameCounter % 1 == 0 or freshShot or not moduleState.cachedPoints) then
            moduleState.cachedPoints = predictTrajectory(ball)
        end
        points = moduleState.cachedPoints
        
        if points then
            endpoint = points[#points]
            distEnd = (root.Position - endpoint).Magnitude
            threatLateral = (endpoint - GoalCFrame.Position):Dot(GoalCFrame.RightVector)
            isThreat = (endpoint - GoalCFrame.Position):Dot(GoalForward) < 2.2 and math.abs(threatLateral) < GoalWidth / 2.0
            local distBallEnd = (ball.Position - endpoint).Magnitude
            timeToEndpoint = distBallEnd / math.max(1, velMag)
        else
            clearTrajAndEndpoint()
        end

        -- ИНТЕЛЛЕКТУАЛЬНЫЙ АНАЛИЗ СИТУАЦИИ
        local shotAnalysis = analyzeShotSituation(ball.Position, ball.Velocity, endpoint, root.Position, points)

        -- Визуализация траектории
        if CONFIG.SHOW_TRAJECTORY and points and moduleState.visualObjects.trajLines then
            local cam = ws.CurrentCamera
            local maxDist = 60
            for i = 1, math.min(CONFIG.PRED_STEPS, #points - 1) do
                if (points[i + 1] - root.Position).Magnitude < maxDist then
                    local p1 = cam:WorldToViewportPoint(points[i])
                    local p2 = cam:WorldToViewportPoint(points[i + 1])
                    local l = moduleState.visualObjects.trajLines[i]
                    if l then
                        l.From = Vector2.new(p1.X, p1.Y)
                        l.To = Vector2.new(p2.X, p2.Y)
                        l.Visible = p1.Z > 0 and p2.Z > 0
                    end
                else
                    if moduleState.visualObjects.trajLines[i] then
                        moduleState.visualObjects.trajLines[i].Visible = false
                    end
                end
            end
            if CONFIG.SHOW_ENDPOINT and endpoint then
                drawEndpoint(endpoint)
            end
        else 
            clearTrajAndEndpoint() 
        end

        -- Бокс мяча
        if CONFIG.SHOW_BALL_BOX and distBall < 60 and moduleState.visualObjects.BallBox then 
            local col
            if endpoint then
                if isThreat then
                    col = CONFIG.BALL_BOX_THREAT_COLOR
                elseif endpoint.Y > CONFIG.JUMP_THRES then
                    col = CONFIG.BALL_BOX_HIGH_COLOR
                else
                    col = CONFIG.BALL_BOX_NORMAL_COLOR
                end
            else
                col = CONFIG.BALL_BOX_SAFE_COLOR
            end
            drawCube(moduleState.visualObjects.BallBox, CFrame.new(ball.Position), Vector3.new(3.0, 3.0, 3.0), col)
        elseif moduleState.visualObjects.BallBox then 
            drawCube(moduleState.visualObjects.BallBox, nil) 
        end

        -- УМНОЕ ПОЗИЦИОНИРОВАНИЕ
        local rightVec = GoalCFrame.RightVector
        local defenseBase = GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST
        local lateral = 0

        -- Угловые удары
        local isCornerKick = false
        if ball.Position.Y > 7 and distBall > 25 and math.abs(threatLateral) > GoalWidth * 0.35 then
            isCornerKick = true
            local cornerPos = handleCornerPositioning(root, ball.Position, ball.Velocity)
            if cornerPos then
                defenseBase = cornerPos
                lateral = 0
            end
        end

        -- Основная логика позиционирования
        if not smartBlockActive and not isCornerKick then
            if isMyBall then
                lateral = 0
                retreatToGoal(root, 1.1)
            elseif oRoot and isAggro then
                -- Позиционирование против владельца мяча
                local targetDist = math.max(CONFIG.STAND_DIST, enemyDistFromLine - 1.5)
                defenseBase = GoalCFrame.Position + GoalForward * targetDist
                lateral = enemyLateral * 0.85
            elseif not hasWeld and isShot then
                -- Позиционирование против удара
                lateral = threatLateral * 0.9
                
                -- Активное выдвижение для быстрых ударов
                if velMag > 25 and distBall < 30 then
                    local advanceDist = math.min(6.0, distBall * 0.25)
                    defenseBase = GoalCFrame.Position + GoalForward * (CONFIG.STAND_DIST + advanceDist)
                elseif velMag > 15 then
                    defenseBase = GoalCFrame.Position + GoalForward * (CONFIG.STAND_DIST + 1.5)
                end
            else
                -- Стандартное позиционирование
                local targetDist = math.max(CONFIG.STAND_DIST, math.min(6.5, enemyDistFromLine * 0.4))
                defenseBase = GoalCFrame.Position + GoalForward * targetDist
                local centerBias = math.max(0, 1 - (enemyDistFromLine / CONFIG.CENTER_BIAS_DIST))
                lateral = enemyLateral * centerBias
            end

            -- Вес угрозы
            local threatWeight = isThreat and 0.992 or (distEnd < CONFIG.CLOSE_THREAT_DIST and 0.97 or 0.45)
            lateral = threatLateral * threatWeight + lateral * (1 - threatWeight)

            -- Получение оптимальной позиции
            local bestPos = getSmartPosition(defenseBase, rightVec, lateral, GoalWidth, 
                threatLateral, enemyLateral, isAggro, ball.Position, ball.Velocity)
            
            -- Перехват мяча
            if isShot and points and isThreat and shotAnalysis.urgency > 0.6 then
                local interceptPoint = findBestInterceptPoint(root.Position, ball.Position, ball.Velocity, points)
                if interceptPoint then
                    local adjustedPos = interceptPoint + GoalForward * CONFIG.ADVANCE_DISTANCE * shotAnalysis.urgency
                    adjustedPos = Vector3.new(adjustedPos.X, root.Position.Y, adjustedPos.Z)
                    bestPos = adjustedPos
                end
            end
            
            -- Движение к позиции
            moveToTarget(root, bestPos, shotAnalysis.urgency > 0.7 and 1.2 or 1.0)
        end

        -- Поворот
        if smartBlockActive and attackTargetPlayer then
            local targetRoot = attackTargetPlayer.Character and attackTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local predictedPos = moduleState.predictedEnemyPositions[tostring(targetRoot.Parent:GetDebugId())] or targetRoot.Position
                rotateSmooth(root, predictedPos, isMyBall, moduleState.isDiving, ball.Velocity)
            else
                rotateSmooth(root, ball.Position, isMyBall, moduleState.isDiving, ball.Velocity)
            end
        else
            rotateSmooth(root, ball.Position, isMyBall, moduleState.isDiving, ball.Velocity)
        end

        -- ИНТЕЛЛЕКТУАЛЬНЫЕ ДЕЙСТВИЯ
        if not isMyBall and not moduleState.isDiving and tick() - moduleState.lastShotTime < 1.5 then
            
            -- Срочные действия на основе анализа
            if shotAnalysis.urgency > 0.8 then
                -- Касание мяча при близкой угрозе
                if shotAnalysis.action == "touch" and distEnd < CONFIG.BALL_INTERCEPT_RANGE * 1.5 then
                    for _, hand in {char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand")} do
                        if hand and (hand.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
                            firetouchinterest(hand, ball, 0)
                            task.wait(0.015)
                            firetouchinterest(hand, ball, 1)
                        end
                    end
                end
                
                -- Прыжок
                if shotAnalysis.action == "jump" and tick() - moduleState.lastJumpTime > CONFIG.JUMP_COOLDOWN then
                    forceJump(hum)
                    moduleState.lastJumpTime = tick()
                end
                
                -- Ныряние
                if shotAnalysis.action == "dive" and tick() - moduleState.lastDiveTime > CONFIG.DIVE_COOLDOWN then
                    performDive(root, hum, endpoint or ball.Position)
                end
            end
        else
            if isMyBall then 
                moduleState.isDiving = false 
            end
        end

        -- Очистка визуализации
        if not isShot or not points then
            clearTrajAndEndpoint()
        end
    end)
end

-- Sync configuration with UI (остается без изменений)
local function syncConfig()
    CONFIG.ENABLED = moduleState.uiElements.Enabled and moduleState.uiElements.Enabled:GetState()
    CONFIG.SPEED = moduleState.uiElements.Speed and moduleState.uiElements.Speed:GetValue()
    CONFIG.STAND_DIST = moduleState.uiElements.StandDist and moduleState.uiElements.StandDist:GetValue()
    CONFIG.DIVE_DIST = moduleState.uiElements.DiveDist and moduleState.uiElements.DiveDist:GetValue()
    CONFIG.ENDPOINT_DIVE = moduleState.uiElements.EndpointDive and moduleState.uiElements.EndpointDive:GetValue()
    CONFIG.TOUCH_RANGE = moduleState.uiElements.TouchRange and moduleState.uiElements.TouchRange:GetValue()
    CONFIG.NEAR_BALL_DIST = moduleState.uiElements.NearBallDist and moduleState.uiElements.NearBallDist:GetValue()
    CONFIG.DIVE_SPEED = moduleState.uiElements.DiveSpeed and moduleState.uiElements.DiveSpeed:GetValue()
    CONFIG.DIVE_VEL_THRES = moduleState.uiElements.DiveVelThresh and moduleState.uiElements.DiveVelThresh:GetValue()
    CONFIG.DIVE_COOLDOWN = moduleState.uiElements.DiveCooldown and moduleState.uiElements.DiveCooldown:GetValue()
    CONFIG.JUMP_VEL_THRES = moduleState.uiElements.JumpVelThresh and moduleState.uiElements.JumpVelThresh:GetValue()
    CONFIG.HIGH_BALL_THRES = moduleState.uiElements.HighBallThresh and moduleState.uiElements.HighBallThresh:GetValue()
    CONFIG.JUMP_COOLDOWN = moduleState.uiElements.JumpCooldown and moduleState.uiElements.JumpCooldown:GetValue()
    CONFIG.ZONE_DIST = moduleState.uiElements.ZoneDist and moduleState.uiElements.ZoneDist:GetValue()
    CONFIG.ZONE_WIDTH = moduleState.uiElements.ZoneWidth and moduleState.uiElements.ZoneWidth:GetValue()
    CONFIG.AGGRO_THRES = moduleState.uiElements.AggroThresh and moduleState.uiElements.AggroThresh:GetValue()
    CONFIG.MAX_CHASE_DIST = moduleState.uiElements.MaxChaseDist and moduleState.uiElements.MaxChaseDist:GetValue()
    CONFIG.GATE_COVERAGE = moduleState.uiElements.GateCoverage and moduleState.uiElements.GateCoverage:GetValue()
    CONFIG.LATERAL_MAX_MULT = moduleState.uiElements.LateralMaxMult and moduleState.uiElements.LateralMaxMult:GetValue()
    CONFIG.AUTO_ATTACK_IN_ZONE = moduleState.uiElements.AutoAttackInZone and moduleState.uiElements.AutoAttackInZone:GetState()
    CONFIG.ATTACK_DISTANCE = moduleState.uiElements.AttackDistance and moduleState.uiElements.AttackDistance:GetValue()
    CONFIG.ATTACK_PREDICT_TIME = moduleState.uiElements.AttackPredictTime and moduleState.uiElements.AttackPredictTime:GetValue()
    CONFIG.ATTACK_COOLDOWN = moduleState.uiElements.AttackCooldown and moduleState.uiElements.AttackCooldown:GetValue()
    CONFIG.PRED_STEPS = moduleState.uiElements.PredSteps and moduleState.uiElements.PredSteps:GetValue()
    CONFIG.GRAVITY = moduleState.uiElements.Gravity and moduleState.uiElements.Gravity:GetValue()
    CONFIG.DRAG = moduleState.uiElements.Drag and moduleState.uiElements.Drag:GetValue()
    CONFIG.CURVE_MULT = moduleState.uiElements.CurveMult and moduleState.uiElements.CurveMult:GetValue()
    CONFIG.BOUNCE_XZ = moduleState.uiElements.BounceXZ and moduleState.uiElements.BounceXZ:GetValue()
    CONFIG.BOUNCE_Y = moduleState.uiElements.BounceY and moduleState.uiElements.BounceY:GetValue()
    CONFIG.BALL_INTERCEPT_RANGE = moduleState.uiElements.BallInterceptRange and moduleState.uiElements.BallInterceptRange:GetValue()
    CONFIG.MIN_INTERCEPT_TIME = moduleState.uiElements.MinInterceptTime and moduleState.uiElements.MinInterceptTime:GetValue()
    CONFIG.ADVANCE_DISTANCE = moduleState.uiElements.AdvanceDistance and moduleState.uiElements.AdvanceDistance:GetValue()
    CONFIG.ROT_SMOOTH = moduleState.uiElements.RotSmooth and moduleState.uiElements.RotSmooth:GetValue()
    CONFIG.DIVE_LOOK_AHEAD = moduleState.uiElements.DiveLookAhead and moduleState.uiElements.DiveLookAhead:GetValue()
    CONFIG.REACTION_TIME = moduleState.uiElements.ReactionTime and moduleState.uiElements.ReactionTime:GetValue()
    CONFIG.ANTICIPATION_DIST = moduleState.uiElements.AnticipationDist and moduleState.uiElements.AnticipationDist:GetValue()
    CONFIG.CORNER_BIAS = moduleState.uiElements.CornerBias and moduleState.uiElements.CornerBias:GetValue()
    CONFIG.SIDE_POSITIONING = moduleState.uiElements.SidePositioning and moduleState.uiElements.SidePositioning:GetValue()
    CONFIG.SHOW_TRAJECTORY = moduleState.uiElements.ShowTrajectory and moduleState.uiElements.ShowTrajectory:GetState()
    CONFIG.SHOW_ENDPOINT = moduleState.uiElements.ShowEndpoint and moduleState.uiElements.ShowEndpoint:GetState()
    CONFIG.SHOW_GOAL_CUBE = moduleState.uiElements.ShowGoalCube and moduleState.uiElements.ShowGoalCube:GetState()
    CONFIG.SHOW_ZONE = moduleState.uiElements.ShowZone and moduleState.uiElements.ShowZone:GetState()
    CONFIG.SHOW_BALL_BOX = moduleState.uiElements.ShowBallBox and moduleState.uiElements.ShowBallBox:GetState()
    CONFIG.SHOW_ATTACK_TARGET = moduleState.uiElements.ShowAttackTarget and moduleState.uiElements.ShowAttackTarget:GetState()
    
    updateVisualColors()
    
    moduleState.enabled = CONFIG.ENABLED
    
    if CONFIG.ENABLED then
        if moduleState.heartbeatConnection then
            moduleState.heartbeatConnection:Disconnect()
            moduleState.heartbeatConnection = nil
        end
        createVisuals()
        updateVisualColors()
        startHeartbeat()
        if moduleState.notify then
            moduleState.notify("AutoGK", "Enabled with synced config", true)
        end
    else
        if moduleState.heartbeatConnection then
            moduleState.heartbeatConnection:Disconnect()
            moduleState.heartbeatConnection = nil
        end
        cleanup()
        if moduleState.notify then
            moduleState.notify("AutoGK", "Disabled", true)
        end
    end
    
    if moduleState.notify then
        moduleState.notify("AutoGK", "Configuration synchronized successfully!", true)
    end
end

-- GK Helper Module
local GKHelperModule = {}

function GKHelperModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
    local notify = notifyFunc
    
    moduleState.notify = notifyFunc
    
    if UI.Sections.AutoGoalKeeper then
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalKeeper" })
        
        moduleState.uiElements.Enabled = UI.Sections.AutoGoalKeeper:Toggle({ 
            Name = "Enabled", 
            Default = CONFIG.ENABLED, 
            Callback = function(v) 
                CONFIG.ENABLED = v
                moduleState.enabled = v
                if v then
                    createVisuals()
                    updateVisualColors()
                    startHeartbeat()
                    notify("AutoGK", "Enabled", true)
                else
                    if moduleState.heartbeatConnection then
                        moduleState.heartbeatConnection:Disconnect()
                        moduleState.heartbeatConnection = nil
                    end
                    cleanup()
                    notify("AutoGK", "Disabled", true)
                end
            end
        }, 'AutoGKEnabled')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        moduleState.uiElements.Speed = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Movement Speed",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.SPEED = v end
        }, 'AutoGKMovementSpeed')
        
        moduleState.uiElements.StandDist = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Stand Distance",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = CONFIG.STAND_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.STAND_DIST = v end
        }, 'StandDistanceGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Dive & Jump Settings" })
        
        moduleState.uiElements.DiveDist = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Distance",
            Minimum = 5,
            Maximum = 25,
            Default = CONFIG.DIVE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_DIST = v end
        }, 'DiveDistanceGK')
        
        moduleState.uiElements.EndpointDive = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Endpoint Dive Distance",
            Minimum = 2,
            Maximum = 16,
            Default = CONFIG.ENDPOINT_DIVE,
            Precision = 1,
            Callback = function(v) CONFIG.ENDPOINT_DIVE = v end
        }, 'EndpointDiveDistanceGK')
        
        moduleState.uiElements.TouchRange = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Hand Touch Range",
            Minimum = 5.0,
            Maximum = 20.0,
            Default = CONFIG.TOUCH_RANGE,
            Precision = 1,
            Callback = function(v) CONFIG.TOUCH_RANGE = v end
        }, 'HandTouchRangeGK')
        
        moduleState.uiElements.NearBallDist = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Near Ball Distance",
            Minimum = 3.0,
            Maximum = 16.0,
            Default = CONFIG.NEAR_BALL_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.NEAR_BALL_DIST = v end
        }, 'NearBallDistanceGK')
        
        moduleState.uiElements.DiveSpeed = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Speed",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.DIVE_SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_SPEED = v end
        }, 'DiveSpeedGK')
        
        moduleState.uiElements.DiveVelThresh = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Velocity Threshold",
            Minimum = 10,
            Maximum = 40,
            Default = CONFIG.DIVE_VEL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_VEL_THRES = v end
        }, 'DiveVelocityGK')
        
        moduleState.uiElements.DiveCooldown = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Cooldown",
            Minimum = 0.5,
            Maximum = 3.0,
            Default = CONFIG.DIVE_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_COOLDOWN = v end
        }, 'DiveCDGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        moduleState.uiElements.JumpVelThresh = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Velocity Threshold",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.JUMP_VEL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_VEL_THRES = v end
        }, 'JumpVelocityGK')
        
        moduleState.uiElements.HighBallThresh = UI.Sections.AutoGoalKeeper:Slider({
            Name = "High Ball Threshold",
            Minimum = 4.0,
            Maximum = 16.0,
            Default = CONFIG.HIGH_BALL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.HIGH_BALL_THRES = v end
        }, 'HighBallGk')
        
        moduleState.uiElements.JumpCooldown = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Cooldown",
            Minimum = 0.5,
            Maximum = 2.0,
            Default = CONFIG.JUMP_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_COOLDOWN = v end
        }, 'JMPCDGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Defense Zone Settings" })
        
        moduleState.uiElements.ZoneDist = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Distance",
            Minimum = 30,
            Maximum = 200,
            Default = CONFIG.ZONE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_DIST = v end
        }, 'ZONEDISTGK')
        
        moduleState.uiElements.ZoneWidth = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Width Multiplier",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = CONFIG.ZONE_WIDTH,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_WIDTH = v end
        }, 'ZONEWIDTHGK')
        
        moduleState.uiElements.AggroThresh = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Aggro Threshold",
            Minimum = 20,
            Maximum = 80,
            Default = CONFIG.AGGRO_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.AGGRO_THRES = v end
        }, 'AGGROTHRESGK')
        
        moduleState.uiElements.MaxChaseDist = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Max Chase Distance",
            Minimum = 20,
            Maximum = 80,
            Default = CONFIG.MAX_CHASE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.MAX_CHASE_DIST = v end
        }, 'MAXCHASEDISTGK')
        
        moduleState.uiElements.GateCoverage = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Goal Coverage",
            Minimum = 0.5,
            Maximum = 1.0,
            Default = CONFIG.GATE_COVERAGE,
            Precision = 2,
            Callback = function(v) CONFIG.GATE_COVERAGE = v end
        }, 'GOALCOVERAGEGK')
        
        moduleState.uiElements.LateralMaxMult = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Lateral Movement Multiplier",
            Minimum = 0.2,
            Maximum = 0.8,
            Default = CONFIG.LATERAL_MAX_MULT,
            Precision = 2,
            Callback = function(v) CONFIG.LATERAL_MAX_MULT = v end
        }, 'LATERALMOVEMENTMULTIGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Smart Attack Settings" })
        
        moduleState.uiElements.Priority = UI.Sections.AutoGoalKeeper:Dropdown({
            Name = "Priority",
            Default = CONFIG.PRIORITY,
            Options = {"defense", "attack"},
            Callback = function(v) CONFIG.PRIORITY = v end
        }, 'PRIOTIRYGK')
        
        moduleState.uiElements.AutoAttackInZone = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Auto Attack in Zone",
            Default = CONFIG.AUTO_ATTACK_IN_ZONE,
            Callback = function(v) CONFIG.AUTO_ATTACK_IN_ZONE = v end
        }, 'AUTOTAATACKINZONEGK')
        
        moduleState.uiElements.AttackDistance = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Distance",
            Minimum = 20,
            Maximum = 80,
            Default = CONFIG.ATTACK_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_DISTANCE = v end
        }, 'ATTACKDISTGK')
        
        moduleState.uiElements.AttackPredictTime = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Predict Time",
            Minimum = 0.05,
            Maximum = 0.3,
            Default = CONFIG.ATTACK_PREDICT_TIME,
            Precision = 2,
            Tooltip = "Time to predict enemy position (compensates for server lag)",
            Callback = function(v) CONFIG.ATTACK_PREDICT_TIME = v end
        }, 'ATTACKPREDICTGK')
        
        moduleState.uiElements.AttackCooldown = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Cooldown",
            Minimum = 0.5,
            Maximum = 3.0,
            Default = CONFIG.ATTACK_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_COOLDOWN = v end
        }, 'ATTACKCDGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Intelligent Positioning" })
        
        moduleState.uiElements.ReactionTime = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Reaction Time",
            Minimum = 0.05,
            Maximum = 0.3,
            Default = CONFIG.REACTION_TIME,
            Precision = 2,
            Callback = function(v) CONFIG.REACTION_TIME = v end
        }, 'REACTIONTIMEGK')
        
        moduleState.uiElements.AnticipationDist = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Anticipation Distance",
            Minimum = 0.5,
            Maximum = 3.0,
            Default = CONFIG.ANTICIPATION_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.ANTICIPATION_DIST = v end
        }, 'ANTICIPATIONDISTGK')
        
        moduleState.uiElements.CornerBias = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Corner Bias",
            Minimum = 0.3,
            Maximum = 1.0,
            Default = CONFIG.CORNER_BIAS,
            Precision = 2,
            Callback = function(v) CONFIG.CORNER_BIAS = v end
        }, 'CORNERBIASGK')
        
        moduleState.uiElements.SidePositioning = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Side Positioning",
            Minimum = 0.3,
            Maximum = 1.0,
            Default = CONFIG.SIDE_POSITIONING,
            Precision = 2,
            Callback = function(v) CONFIG.SIDE_POSITIONING = v end
        }, 'SIDEPOSITIONINGGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Prediction Settings" })
        
        moduleState.uiElements.PredSteps = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Prediction Steps",
            Minimum = 60,
            Maximum = 200,
            Default = CONFIG.PRED_STEPS,
            Precision = 0,
            Callback = function(v) CONFIG.PRED_STEPS = v end
        }, 'PREDSTEPSGK')
        
        moduleState.uiElements.Gravity = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Gravity",
            Minimum = 80,
            Maximum = 198.2,
            Default = CONFIG.GRAVITY,
            Precision = 1,
            Callback = function(v) CONFIG.GRAVITY = v end
        }, 'GRAVITYGK')
        
        moduleState.uiElements.Drag = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Air Drag",
            Minimum = 0.95,
            Maximum = 0.995,
            Default = CONFIG.DRAG,
            Precision = 3,
            Callback = function(v) CONFIG.DRAG = v end
        }, 'AIRDRAGGK')
        
        moduleState.uiElements.CurveMult = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Curve Multiplier",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.CURVE_MULT,
            Precision = 1,
            Callback = function(v) CONFIG.CURVE_MULT = v end
        }, 'CURVEMULTIGK')
        
        moduleState.uiElements.BounceXZ = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Horizontal Bounce",
            Minimum = 0.5,
            Maximum = 0.9,
            Default = CONFIG.BOUNCE_XZ,
            Precision = 2,
            Callback = function(v) CONFIG.BOUNCE_XZ = v end
        }, 'HORIZONTALBOUNCEGK')
        
        moduleState.uiElements.BounceY = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Vertical Bounce",
            Minimum = 0.5,
            Maximum = 0.9,
            Default = CONFIG.BOUNCE_Y,
            Precision = 2,
            Callback = function(v) CONFIG.BOUNCE_Y = v end
        }, 'VERTICALBOUNCEGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Advanced Defense Settings" })
        
        moduleState.uiElements.BallInterceptRange = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Ball Intercept Range",
            Minimum = 2.0,
            Maximum = 12.0,
            Default = CONFIG.BALL_INTERCEPT_RANGE,
            Precision = 1,
            Callback = function(v) CONFIG.BALL_INTERCEPT_RANGE = v end
        }, 'BALLINTERCEPTRANGEGK')
        
        moduleState.uiElements.MinInterceptTime = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Min Intercept Time",
            Minimum = 0.05,
            Maximum = 0.5,
            Default = CONFIG.MIN_INTERCEPT_TIME,
            Precision = 2,
            Callback = function(v) CONFIG.MIN_INTERCEPT_TIME = v end
        }, 'MININTERCEPTTIMEGK')
        
        moduleState.uiElements.AdvanceDistance = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Advance Distance",
            Minimum = 1.0,
            Maximum = 8.0,
            Default = CONFIG.ADVANCE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ADVANCE_DISTANCE = v end
        }, 'ADVANCEDISTGK')
        
        moduleState.uiElements.RotSmooth = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Rotation Smoothness",
            Minimum = 0.5,
            Maximum = 0.95,
            Default = CONFIG.ROT_SMOOTH,
            Precision = 2,
            Callback = function(v) CONFIG.ROT_SMOOTH = v end
        }, 'ROTSMOOTHGK')
        
        moduleState.uiElements.DiveLookAhead = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Look Ahead",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = CONFIG.DIVE_LOOK_AHEAD,
            Precision = 2,
            Callback = function(v) CONFIG.DIVE_LOOK_AHEAD = v end
        }, 'DIVELOOKAHEADGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Visual Settings" })
        
        moduleState.uiElements.ShowTrajectory = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Trajectory",
            Default = CONFIG.SHOW_TRAJECTORY,
            Callback = function(v) 
                CONFIG.SHOW_TRAJECTORY = v 
                if moduleState.enabled then
                    createVisuals()
                    updateVisualColors()
                end
            end
        }, 'SHOWTRAJECTORYGK')
        
        moduleState.uiElements.ShowEndpoint = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Endpoint",
            Default = CONFIG.SHOW_ENDPOINT,
            Callback = function(v) 
                CONFIG.SHOW_ENDPOINT = v 
                if moduleState.enabled then
                    createVisuals()
                    updateVisualColors()
                end
            end
        }, 'SHOWENDPOINTGK')
        
        moduleState.uiElements.ShowGoalCube = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Goal Cube",
            Default = CONFIG.SHOW_GOAL_CUBE,
            Callback = function(v) 
                CONFIG.SHOW_GOAL_CUBE = v 
                if moduleState.enabled then
                    createVisuals()
                    updateVisualColors()
                end
            end
        }, 'SHOWGOALCUBEGK')
        
        moduleState.uiElements.ShowZone = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Zone",
            Default = CONFIG.SHOW_ZONE,
            Callback = function(v) 
                CONFIG.SHOW_ZONE = v 
                if moduleState.enabled then
                    createVisuals()
                    updateVisualColors()
                end
            end
        })
        
        moduleState.uiElements.ShowBallBox = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Ball Box",
            Default = CONFIG.SHOW_BALL_BOX,
            Callback = function(v) 
                CONFIG.SHOW_BALL_BOX = v 
                if moduleState.enabled then
                    createVisuals()
                    updateVisualColors()
                end
            end
        }, 'SHOWBALLBOXGK')
        
        moduleState.uiElements.ShowAttackTarget = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Attack Target",
            Default = CONFIG.SHOW_ATTACK_TARGET,
            Callback = function(v) 
                CONFIG.SHOW_ATTACK_TARGET = v 
                if moduleState.enabled then
                    createVisuals()
                    updateVisualColors()
                end
            end
        }, 'SHOWATTACKTARGETGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Color Settings" })
        
        moduleState.colorPickers.TrajectoryColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Trajectory Color",
            Default = CONFIG.TRAJECTORY_COLOR,
            Callback = function(v) 
                CONFIG.TRAJECTORY_COLOR = v
                updateVisualColors()
            end
        }, 'TRAJECTORYCOLORGK')
        
        moduleState.colorPickers.EndpointColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Endpoint Color",
            Default = CONFIG.ENDPOINT_COLOR,
            Callback = function(v) 
                CONFIG.ENDPOINT_COLOR = v
                updateVisualColors()
            end
        }, 'ENDPOINTCOLORGK')
        
        moduleState.colorPickers.GoalCubeColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Goal Cube Color",
            Default = CONFIG.GOAL_CUBE_COLOR,
            Callback = function(v) 
                CONFIG.GOAL_CUBE_COLOR = v
                updateVisualColors()
            end
        }, 'GOALCUBECOLORGK')
        
        moduleState.colorPickers.ZoneColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Zone Color",
            Default = CONFIG.ZONE_COLOR,
            Callback = function(v) 
                CONFIG.ZONE_COLOR = v
                updateVisualColors()
            end
        }, 'ZONECOLORGK')
        
        moduleState.colorPickers.AttackTargetColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Attack Target Color",
            Default = CONFIG.ATTACK_TARGET_COLOR,
            Callback = function(v) 
                CONFIG.ATTACK_TARGET_COLOR = v
                updateVisualColors()
            end
        }, 'ATTACKTARGETCOLORGK')
        
        moduleState.colorPickers.BallBoxSafeColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box Safe Color",
            Default = CONFIG.BALL_BOX_SAFE_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_SAFE_COLOR = v
            end
        }, 'BALLBOXSAFECOLORGK')
        
        moduleState.colorPickers.BallBoxThreatColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box Threat Color",
            Default = CONFIG.BALL_BOX_THREAT_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_THREAT_COLOR = v
            end
        }, 'BALLBOXTHREATCOLORGK')
        
        moduleState.colorPickers.BallBoxHighColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box High Color",
            Default = CONFIG.BALL_BOX_HIGH_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_HIGH_COLOR = v
            end
        }, 'BALLBOXHIGHCOLORGK')
        
        moduleState.colorPickers.BallBoxNormalColor = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box Normal Color",
            Default = CONFIG.BALL_BOX_NORMAL_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_NORMAL_COLOR = v
            end
        }, 'BALLBOXNORMALCOLORGK')
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Enhanced Settings" })
        
        moduleState.uiElements.PRESS_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Press Distance",
            Minimum = 8,
            Maximum = 20,
            Default = CONFIG.PRESS_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.PRESS_DISTANCE = v end
        }, 'PRESSDISTANCEGK')
        
        moduleState.uiElements.PREDICTION_AGGRESSION = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Prediction Aggression",
            Minimum = 1.0,
            Maximum = 3.0,
            Default = CONFIG.PREDICTION_AGGRESSION,
            Precision = 1,
            Callback = function(v) CONFIG.PREDICTION_AGGRESSION = v end
        }, 'PREDICTIONAGGRESSIONGK')
        
        moduleState.uiElements.BLOCK_ANGLE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Block Angle",
            Minimum = 30,
            Maximum = 60,
            Default = CONFIG.BLOCK_ANGLE,
            Precision = 0,
            Callback = function(v) CONFIG.BLOCK_ANGLE = v end
        }, 'BLOCKANGLEGK')
        
        moduleState.uiElements.RETREAT_SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Retreat Speed",
            Minimum = 24,
            Maximum = 40,
            Default = CONFIG.RETREAT_SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.RETREAT_SPEED = v end
        }, 'RETREATSPEEDGK')
        
        moduleState.uiElements.DIVE_MAX_DURATION = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Max Duration",
            Minimum = 0.15,
            Maximum = 0.5,
            Default = CONFIG.DIVE_MAX_DURATION,
            Precision = 2,
            Callback = function(v) CONFIG.DIVE_MAX_DURATION = v end
        }, 'DIVEMAXDURATIONGK')
        
        moduleState.uiElements.ADVANCE_MULTIPLIER = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Advance Multiplier",
            Minimum = 1.0,
            Maximum = 2.0,
            Default = CONFIG.ADVANCE_MULTIPLIER,
            Precision = 1,
            Callback = function(v) CONFIG.ADVANCE_MULTIPLIER = v end
        }, 'ADVANCEMULTIPLIERGK')
        
        moduleState.uiElements.SHOW_THREAT_LINES = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Threat Lines",
            Default = CONFIG.SHOW_THREAT_LINES,
            Callback = function(v) 
                CONFIG.SHOW_THREAT_LINES = v 
                if moduleState.enabled then
                    createVisuals()
                    updateVisualColors()
                end
            end
        }, 'SHOWTHREATLINESGK')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Information" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "AutoGK V1.5 - Color Customization & Improved",
            Body = [[
BASIC SETTINGS:
0 Movement Speed: How fast the goalkeeper moves
1 Stand Distance: Default distance from goal when idle

DIVE & JUMP:
2 Dive Distance: Max distance to perform a dive
3 Endpoint Dive: Distance to predicted ball endpoint for dive
4 Hand Touch Range: Distance for automatic ball touching
5 Near Ball Distance: Distance considered "close" to ball
6 Dive Speed: Speed of dive movement
7 Dive Velocity Threshold: Minimum ball speed to trigger dive
8 Jump Velocity Threshold: Minimum ball speed to trigger jump
9 High Ball Threshold: Ball height that requires a jump

DEFENSE ZONE:
10 Zone Distance: Depth of green defense zone
11 Zone Width: Width of defense zone relative to goal
12 Aggro Threshold: Distance to enemy for aggressive mode
13 Max Chase Distance: Maximum distance to chase enemies
14 Goal Coverage: How much of goal to cover (1.0 = full)
15 Lateral Movement: Side-to-side movement multiplier

SMART ATTACK:
16 Priority: Defense = protect goal, Attack = pressure enemies
17 Auto Attack in Zone: Attack enemies inside defense zone
18 Attack Distance: Distance to approach enemy for blocking
19 Attack Predict Time: Time to predict enemy position (server lag)
20 Attack Cooldown: Time between attack target changes

INTELLIGENT POSITIONING:
21 Reaction Time: How fast the goalkeeper reacts to threats
22 Anticipation Distance: How far to anticipate shot direction
23 Corner Bias: Positioning adjustment for corner kicks
24 Side Positioning: Lateral positioning intelligence

PREDICTION:
25 Prediction Steps: Accuracy of ball trajectory prediction
26 Gravity: Ball gravity in prediction
27 Air Drag: Air resistance for ball
28 Curve Multiplier: How much curve affects trajectory
29 Bounce settings: How ball bounces off surfaces

ADVANCED DEFENSE:
30 Ball Intercept Range: Distance for intercepting ball
31 Min Intercept Time: Minimum time needed to intercept
32 Advance Distance: How far to advance from goal
33 Rotation Smoothness: Smoothness of turning
34 Dive Look Ahead: How far ahead to look during dive
]]
        })
    end
    
    if UI.Tabs.Config then
        moduleState.syncSection = UI.Tabs.Config:Section({Name = 'AutoGoalKeeper Sync', Side = 'Right'})
        
        moduleState.syncSection:Header({ Name = "AutoGoalKeeper config sync" })
        moduleState.syncSection:Divider()
        
        moduleState.syncSection:Button({
            Name = "Sync Current Config",
            Callback = function()
                syncConfig()
            end
        })
    end
    

    
    if UI.Tabs.Config then
        moduleState.syncSection = UI.Tabs.Config:Section({Name = 'AutoGoalKeeper Sync', Side = 'Right'})
        
        moduleState.syncSection:Header({ Name = "AutoGoalKeeper config sync" })
        moduleState.syncSection:Divider()
        
        moduleState.syncSection:Button({
            Name = "Sync Current Config",
            Callback = function()
                syncConfig()
            end
        })
    end
end

function GKHelperModule:Destroy()
    if moduleState.heartbeatConnection then
        moduleState.heartbeatConnection:Disconnect()
        moduleState.heartbeatConnection = nil
    end
    cleanup()
    moduleState.enabled = false
end

return GKHelperModule
