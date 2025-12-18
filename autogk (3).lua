-- GK Helper v48 — Advanced Defense Module with Color Customization
-- Improved version with smart attack prediction, fixed dive bug, and color customization

local player = game.Players.LocalPlayer
local ws = workspace
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- V48 ADVANCED DEFENSE - CONFIGURATION
local CONFIG = {
    -- === BASIC SETTINGS ===
    ENABLED = false,
    
    -- === MOVEMENT ===
    SPEED = 34,                     -- Base movement speed
    STAND_DIST = 2.6,               -- Standard distance from goal
    MIN_DIST = 1.3,                 -- Minimum distance to start moving
    MAX_CHASE_DIST = 40,            -- Maximum chase distance
    
    -- === DISTANCES ===
    AGGRO_THRES = 45,               -- Distance to enemy for aggressive mode
    DIVE_DIST = 14,                 -- Maximum distance for dive
    ENDPOINT_DIVE = 4,              -- Distance to endpoint for dive
    TOUCH_RANGE = 8.5,              -- Hand touch range
    NEAR_BALL_DIST = 7,             -- "Close to ball" distance for auto save
    
    -- === DEFENSE ZONE ===
    ZONE_DIST = 56,                 -- Defense zone depth (green cube)
    ZONE_WIDTH = 2.5,               -- Zone width relative to goal width
    
    -- === THRESHOLDS ===
    DIVE_VEL_THRES = 18,            -- Minimum ball speed for dive
    JUMP_VEL_THRES = 31,            -- Minimum ball speed for jump
    HIGH_BALL_THRES = 6.8,          -- Ball height for jump
    CLOSE_THREAT_DIST = 4.0,        -- Close threat distance
    JUMP_THRES = 5.0,               -- Height threshold for jump
    GATE_COVERAGE = 0.99,           -- Goal coverage (1.0 = full coverage)
    CENTER_BIAS_DIST = 21,          -- Center bias distance
    LATERAL_MAX_MULT = 0.45,        -- Max lateral movement relative to goal width
    
    -- === COOLDOWNS ===
    DIVE_COOLDOWN = 1.3,            -- Cooldown between dives
    JUMP_COOLDOWN = 0.95,           -- Cooldown between jumps
    ATTACK_COOLDOWN = 1.5,          -- Cooldown between attack target changes
    
    -- === DIVE SPEED ===
    DIVE_SPEED = 40,                -- Dive speed
    
    -- === VISUAL SETTINGS ===
    SHOW_TRAJECTORY = true,         -- Show ball trajectory
    SHOW_ENDPOINT = true,           -- Show endpoint
    SHOW_GOAL_CUBE = true,          -- Show goal cube (red)
    SHOW_ZONE = true,               -- Show defense zone (green cube)
    SHOW_BALL_BOX = true,           -- Show ball cube
    SHOW_ATTACK_TARGET = true,      -- Show attack target prediction
    
    -- === VISUAL COLORS ===
    TRAJECTORY_COLOR = Color3.fromRGB(0, 255, 255),    -- Cyan
    ENDPOINT_COLOR = Color3.fromRGB(255, 255, 0),      -- Yellow
    GOAL_CUBE_COLOR = Color3.fromRGB(255, 0, 0),       -- Red
    ZONE_COLOR = Color3.fromRGB(0, 255, 0),           -- Green
    BALL_BOX_SAFE_COLOR = Color3.fromRGB(0, 255, 0),  -- Green (safe)
    BALL_BOX_THREAT_COLOR = Color3.fromRGB(255, 0, 0),-- Red (threat)
    BALL_BOX_HIGH_COLOR = Color3.fromRGB(255, 255, 0),-- Yellow (high)
    BALL_BOX_NORMAL_COLOR = Color3.fromRGB(0, 200, 255), -- Light blue (normal)
    ATTACK_TARGET_COLOR = Color3.fromRGB(255, 105, 180), -- Pink
    
    -- === ROTATION ===
    ROT_SMOOTH = 0.79,              -- Rotation smoothness (0-1, higher = smoother)
    
    -- === ADVANCED DEFENSE ===
    BALL_INTERCEPT_RANGE = 4.5,     -- Ball interception range
    MIN_INTERCEPT_TIME = 0.1,       -- Minimum intercept time
    ADVANCE_DISTANCE = 3.8,         -- Advance forward distance
    DIVE_LOOK_AHEAD = 0.25,         -- Look ahead for dive
    
    -- === ATTACK SETTINGS ===
    PRIORITY = "attack",            -- Priority: "defense" or "attack"
    AUTO_ATTACK_IN_ZONE = true,     -- Auto attack enemies in defense zone
    ATTACK_DISTANCE = 34,           -- Distance to approach enemy
    ATTACK_PREDICT_TIME = 0.15,     -- Time to predict enemy position (server lag compensation)
    BLOCK_ANGLE_MULT = 0.85,        -- Enemy FOV blocking multiplier (0-1)
    AGGRESSIVE_MODE = false,        -- Aggressive mode (constantly chase enemy)
    ATTACK_WHEN_CLOSE_TO_BALL = true, -- Attack enemy with ball
    
    -- === PREDICTION SETTINGS ===
    PRED_STEPS = 120,               -- Trajectory prediction steps
    CURVE_MULT = 38,                -- Curve multiplier
    DT = 1/60,                      -- Delta time for physics
    GRAVITY = 110,                  -- Gravity for prediction
    DRAG = 0.982,                   -- Air resistance
    BOUNCE_XZ = 0.72,               -- Horizontal bounce
    BOUNCE_Y = 0.68                 -- Vertical bounce
}

-- Module state
local moduleState = {
    enabled = false,
    lastDiveTime = 0,
    lastJumpTime = 0,
    lastAttackTime = 0,
    isDiving = false,
    endpointRadius = 4.0,
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
    colorPickers = {}
}

-- Global variables
local GoalCFrame, GoalForward, GoalWidth = nil, nil, 0
local maxDistFromGoal = 50

-- Create visuals function
local function createVisuals()
    -- Clear old visuals if exist
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
            line.Color = Color3.fromHSV(i / CONFIG.PRED_STEPS, 1, 1) -- Градиентный цвет
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
        -- Create smoother circle with more segments
        moduleState.visualObjects.attackTarget = {}
        for i = 1, 36 do -- Increased from 24 to 36 for smoother circle
            local line = Drawing.new("Line")
            line.Thickness = 3 
            line.Color = CONFIG.ATTACK_TARGET_COLOR
            line.Transparency = 0.7
            line.Visible = false
            moduleState.visualObjects.attackTarget[i] = line
        end
    end
end

-- Update all visual colors
local function updateVisualColors()
    -- Update Goal Cube color
    if moduleState.visualObjects.GoalCube then
        for _, line in ipairs(moduleState.visualObjects.GoalCube) do
            if line then
                line.Color = CONFIG.GOAL_CUBE_COLOR
            end
        end
    end
    
    -- Update Zone color
    if moduleState.visualObjects.LimitCube then
        for _, line in ipairs(moduleState.visualObjects.LimitCube) do
            if line then
                line.Color = CONFIG.ZONE_COLOR
            end
        end
    end
    
    -- Update Endpoint color
    if moduleState.visualObjects.endpointLines then
        for _, line in ipairs(moduleState.visualObjects.endpointLines) do
            if line then
                line.Color = CONFIG.ENDPOINT_COLOR
            end
        end
    end
    
    -- Update Attack Target color
    if moduleState.visualObjects.attackTarget then
        for _, line in ipairs(moduleState.visualObjects.attackTarget) do
            if line then
                line.Color = CONFIG.ATTACK_TARGET_COLOR
            end
        end
    end
    
    -- Update Trajectory color (gradient based on CONFIG.TRAJECTORY_COLOR)
    if moduleState.visualObjects.trajLines then
        local baseH, baseS, baseV = CONFIG.TRAJECTORY_COLOR:ToHSV()
        for i, line in ipairs(moduleState.visualObjects.trajLines) do
            if line then
                -- Create gradient based on base color
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
    if tick() - moduleState.lastGoalkeeperCheck < 1 then return moduleState.isGoalkeeper end
    
    moduleState.lastGoalkeeperCheck = tick()
    local isHPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("HPG") and ws.Bools.HPG.Value == player
    local isAPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("APG") and ws.Bools.APG.Value == player
    
    local wasGoalkeeper = moduleState.isGoalkeeper
    moduleState.isGoalkeeper = isHPG or isAPG
    
    -- If stopped being goalkeeper - clear visuals
    if wasGoalkeeper and not moduleState.isGoalkeeper then
        hideAllVisuals()
        if moduleState.currentBV then pcall(function() moduleState.currentBV:Destroy() end) moduleState.currentBV = nil end
        if moduleState.currentGyro then pcall(function() moduleState.currentGyro:Destroy() end) moduleState.currentGyro = nil end
    end
    
    -- If became goalkeeper - create visuals
    if moduleState.isGoalkeeper and not wasGoalkeeper and moduleState.enabled then
        createVisuals()
    end
    
    return moduleState.isGoalkeeper
end

local function updateGoals()
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
    for _, part in parts do center = center + part.Position end 
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
            for _, part in parts do
                local rel = part.Position - gcenter  
                local dist = rel:Dot(GoalForward)
                minDist = math.min(minDist, dist)
                maxDist = math.max(maxDist, dist)
            end
            
            if maxDist - minDist < 10 or maxDist < 10 then
                GoalForward = -GoalForward
                minDist, maxDist = math.huge, -math.huge
                for _, part in parts do
                    local rel = part.Position - gcenter
                    dist = rel:Dot(GoalForward)
                    minDist = math.min(minDist, dist)
                    maxDist = math.max(maxDist, dist)
                end
            end
            
            GoalCFrame = CFrame.fromMatrix(gcenter, rightDir, Vector3.new(0,1,0), -GoalForward)
            GoalWidth = (right.Position - left.Position).Magnitude
            maxDistFromGoal = math.max(34, maxDist - minDist + 15)
            return true
        end
    end
    return false
end

local function drawCube(cube, cf, size, color)
    if not cube or not cf or not cf.Position then 
        if cube then
            for _, l in cube do 
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
            for _, l in moduleState.visualObjects.LimitCube do 
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
            for _, l in moduleState.visualObjects.endpointLines do 
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

-- IMPROVED: Smooth attack target rendering at foot level
local function drawAttackTarget(pos)
    if not pos or not moduleState.visualObjects.attackTarget then 
        if moduleState.visualObjects.attackTarget then
            for _, l in moduleState.visualObjects.attackTarget do 
                if l then l.Visible = false end 
            end 
        end
        moduleState.attackTargetVisible = false
        return 
    end
    
    local cam = ws.CurrentCamera 
    if not cam then return end
    
    -- Position at foot level (ground level + small offset)
    local footPos = Vector3.new(pos.X, 0.5, pos.Z)
    
    local step = math.pi * 2 / 36
    local radius = 2.0 -- Slightly smaller radius
    
    -- Smooth rendering - update every frame
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

-- Function to hide attack target immediately
local function hideAttackTarget()
    if moduleState.visualObjects.attackTarget then
        for _, l in moduleState.visualObjects.attackTarget do 
            if l then l.Visible = false end 
        end
    end
    moduleState.attackTargetVisible = false
    moduleState.currentAttackTarget = nil
end

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
            spinCurve = ball.CFrame.RightVector * CONFIG.CURVE_MULT * 0.035
        end
        if ws.Bools.Header and ws.Bools.Header.Value then 
            spinCurve = spinCurve + Vector3.new(0, 28, 0) 
        end
    end)
    
    for i = 1, steps do
        local curveFade = 1 - (i/steps) * 0.5
        vel = vel * drag + spinCurve * dt * curveFade
        vel = vel - Vector3.new(0, gravity * dt * 1.02, 0)
        pos = pos + vel * dt
        
        if pos.Y < 0.5 then
            pos = Vector3.new(pos.X, 0.5, pos.Z)
            vel = Vector3.new(vel.X * CONFIG.BOUNCE_XZ, math.abs(vel.Y) * CONFIG.BOUNCE_Y, vel.Z * CONFIG.BOUNCE_XZ)
        end
        table.insert(points, pos)
    end
    return points
end

local function moveToTarget(root, targetPos)
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1,0,1)
    if dirVec.Magnitude < CONFIG.MIN_DIST then return end
    
    moduleState.currentBV = Instance.new("BodyVelocity", root)
    moduleState.currentBV.MaxForce = Vector3.new(4e5, 0, 4e5)
    moduleState.currentBV.Velocity = dirVec.Unit * CONFIG.SPEED
    game.Debris:AddItem(moduleState.currentBV, 1.4)
    
    if ts then
        ts:Create(moduleState.currentBV, tweenInfo, {Velocity = Vector3.new()}):Play()
    end
end

local function rotateSmooth(root, targetPos, isOwner, isDivingNow, ballVel)
    if isOwner then 
        if moduleState.currentGyro then 
            pcall(function() moduleState.currentGyro:Destroy() end) 
            moduleState.currentGyro = nil
        end
        moduleState.currentTargetType = "owner"
        return 
    end
    
    if not moduleState.smoothCFrame then moduleState.smoothCFrame = root.CFrame end
    
    local finalLookPos
    
    if isDivingNow and ballVel then
        -- During dive, look where the ball is going (with slight lead)
        finalLookPos = targetPos + ballVel.Unit * CONFIG.DIVE_LOOK_AHEAD
        moduleState.currentTargetType = "dive"
    else
        -- Otherwise look at the ball
        finalLookPos = targetPos
        moduleState.currentTargetType = "ball"
    end
    
    local targetLook = CFrame.lookAt(root.Position, finalLookPos)
    moduleState.smoothCFrame = moduleState.smoothCFrame:Lerp(targetLook, CONFIG.ROT_SMOOTH)
    
    if moduleState.currentGyro then 
        pcall(function() moduleState.currentGyro:Destroy() end) 
        moduleState.currentGyro = nil
    end
    
    moduleState.currentGyro = Instance.new("BodyGyro", root)
    moduleState.currentGyro.Name = "GKRoto"
    moduleState.currentGyro.P = 2500000
    moduleState.currentGyro.MaxTorque = Vector3.new(0, 4e6, 0)
    moduleState.currentGyro.CFrame = moduleState.smoothCFrame
    game.Debris:AddItem(moduleState.currentGyro, 0.22)
end

local function playJumpAnimation(hum)
    pcall(function()
        local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK.Jump)
        anim.Priority = Enum.AnimationPriority.Action4
        anim:Play()
    end)
end

local function forceJump(hum)
    local oldPower = hum.JumpPower
    hum.JumpPower = 42
    hum.Jump = true
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    playJumpAnimation(hum)
    task.wait(0.04)
    hum.JumpPower = oldPower
end

local function getSmartPosition(defenseBase, rightVec, lateral, goalWidth, threatLateral, enemyLateral, isAggro)
    local maxLateral = goalWidth * CONFIG.LATERAL_MAX_MULT
    local baseLateral = math.clamp(lateral, -maxLateral, maxLateral)
    
    if threatLateral ~= 0 then 
        baseLateral = threatLateral * 0.97 
    end
    
    if enemyLateral ~= 0 and isAggro then 
        baseLateral = enemyLateral * 0.92 
    end
    
    local finalLateral = math.clamp(baseLateral, -maxLateral * CONFIG.GATE_COVERAGE, maxLateral * CONFIG.GATE_COVERAGE)
    return Vector3.new(defenseBase.X + rightVec.X * finalLateral, defenseBase.Y, defenseBase.Z + rightVec.Z * finalLateral)
end

local function clearTrajAndEndpoint()
    if moduleState.visualObjects.trajLines then
        for _, l in moduleState.visualObjects.trajLines do 
            if l then l.Visible = false end 
        end
    end
    
    if moduleState.visualObjects.endpointLines then
        for _, l in moduleState.visualObjects.endpointLines do 
            if l then l.Visible = false end 
        end
    end
end

-- Find intercept point
local function findBestInterceptPoint(rootPos, ballPos, ballVel, points)
    if not points or #points < 2 then return nil end
    
    local bestPoint = nil
    local bestScore = math.huge
    
    for i = 2, #points do
        local point = points[i]
        local distToPoint = (rootPos - point).Magnitude
        local ballTravelDist = 0
        
        -- Calculate ball travel distance to this point
        for j = 1, i-1 do
            ballTravelDist = ballTravelDist + (points[j+1] - points[j]).Magnitude
        end
        
        local timeToPoint = ballTravelDist / math.max(1, ballVel.Magnitude)
        local timeToReach = distToPoint / CONFIG.SPEED
        
        -- If we can reach the point before the ball
        if timeToReach < timeToPoint - CONFIG.MIN_INTERCEPT_TIME then
            local score = distToPoint + (point - GoalCFrame.Position):Dot(GoalForward) * 0.5
            if score < bestScore then
                bestScore = score
                bestPoint = point
            end
        end
    end
    
    return bestPoint
end

-- Check if player is in defense zone
local function isInDefenseZone(position)
    if not (GoalCFrame and GoalForward) then return false end
    
    local relPos = position - GoalCFrame.Position
    local distForward = relPos:Dot(GoalForward)
    local distLateral = math.abs(relPos:Dot(GoalCFrame.RightVector))
    
    return distForward > 0 and distForward < CONFIG.ZONE_DIST and 
           distLateral < (GoalWidth * CONFIG.ZONE_WIDTH) / 2
end

-- Predict enemy position based on velocity and direction
local function predictEnemyPosition(enemyRoot)
    if not enemyRoot then return enemyRoot.Position end
    
    local currentTime = tick()
    local enemyId = tostring(enemyRoot.Parent:GetDebugId())
    
    -- Store current position and velocity in history
    if not moduleState.attackTargetHistory[enemyId] then
        moduleState.attackTargetHistory[enemyId] = {}
    end
    
    local history = moduleState.attackTargetHistory[enemyId]
    
    -- Add current data to history
    table.insert(history, {
        time = currentTime,
        position = enemyRoot.Position,
        velocity = enemyRoot.Velocity
    })
    
    -- Keep only recent history (last 0.5 seconds)
    while #history > 0 and currentTime - history[1].time > 0.5 do
        table.remove(history, 1)
    end
    
    -- If we have enough history, calculate predicted position
    if #history >= 2 then
        local avgVelocity = Vector3.new(0, 0, 0)
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
            
            -- Predict position with server lag compensation
            local predictedPos = enemyRoot.Position + avgVelocity * CONFIG.ATTACK_PREDICT_TIME
            
            -- Store for visualization
            moduleState.predictedEnemyPositions[enemyId] = predictedPos
            
            return predictedPos
        end
    end
    
    -- Fallback: use current position
    return enemyRoot.Position
end

-- Find attack target (reduce enemy FOV)
local function findAttackTarget(rootPos, ball)
    local bestTarget = nil
    local bestScore = -math.huge
    
    for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            local targetRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = otherPlayer.Character:FindFirstChild("Humanoid")
            
            if targetRoot and targetHum and targetHum.Health > 0 then
                -- Check if enemy
                local isEnemy = true
                pcall(function()
                    if ws.Bools.HPG.Value == otherPlayer or ws.Bools.APG.Value == otherPlayer then
                        isEnemy = false
                    end
                end)
                
                if isEnemy then
                    local distToTarget = (rootPos - targetRoot.Position).Magnitude
                    local inZone = isInDefenseZone(targetRoot.Position)
                    
                    -- Calculate target score
                    local score = 0
                    
                    -- Priority to targets in defense zone
                    if inZone then
                        score = score + 50
                    end
                    
                    -- Priority to targets with ball
                    local hasBall = false
                    pcall(function()
                        if ball:FindFirstChild("creator") and ball.creator.Value == otherPlayer then
                            hasBall = true
                            score = score + 100
                        end
                    end)
                    
                    -- Priority to closest targets
                    score = score + (100 - math.min(distToTarget, 100))
                    
                    -- Priority to targets looking at goal
                    local targetLook = targetRoot.CFrame.LookVector
                    local toGoalDir = (GoalCFrame.Position - targetRoot.Position).Unit
                    local angleToGoal = math.deg(math.acos(math.clamp(targetLook:Dot(toGoalDir), -1, 1)))
                    
                    if angleToGoal < 45 then -- If enemy is looking at goal
                        score = score + 30
                    end
                    
                    -- Consider priority setting
                    if CONFIG.PRIORITY == "attack" then
                        score = score * 1.5
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

-- SMART BLOCK: Predict enemy movement and block where they're going, not where they are
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
    
    -- Update attack target
    moduleState.currentAttackTarget = targetPlayer
    
    -- Predict enemy position with server lag compensation
    local predictedEnemyPos = predictEnemyPosition(targetRoot)
    local distToTarget = (root.Position - targetRoot.Position).Magnitude
    
    -- Calculate smart blocking position
    local goalCenter = GoalCFrame.Position
    local toGoalDir = (goalCenter - predictedEnemyPos).Unit
    
    -- Calculate enemy's movement direction
    local enemyVelocity = targetRoot.Velocity
    local enemySpeed = enemyVelocity.Magnitude
    
    -- If enemy is moving, predict their future position
    local predictedBlockPos = predictedEnemyPos
    if enemySpeed > 5 then -- If enemy is moving significantly
        local enemyMoveDir = enemyVelocity.Unit
        local enemyMoveDistance = enemySpeed * CONFIG.ATTACK_PREDICT_TIME * 1.5
        predictedBlockPos = predictedEnemyPos + enemyMoveDir * enemyMoveDistance
    end
    
    -- Calculate blocking position between predicted enemy position and goal
    local blockDistance = CONFIG.ATTACK_DISTANCE
    
    -- If enemy has ball, get closer
    local hasBall = false
    pcall(function()
        if ball:FindFirstChild("creator") and ball.creator.Value == targetPlayer then
            hasBall = true
            blockDistance = blockDistance * 0.7 -- Get closer if enemy has ball
        end
    end)
    
    -- Smart positioning: slightly ahead of enemy's predicted path to goal
    local enemyToGoal = (goalCenter - predictedBlockPos).Unit
    local blockPos = predictedBlockPos + enemyToGoal * blockDistance
    
    -- Add lateral offset based on enemy's movement direction
    if enemySpeed > 3 then
        local rightVec = GoalCFrame.RightVector
        local lateralOffset = enemyToGoal:Cross(Vector3.new(0, 1, 0)).Unit
        local dotProduct = lateralOffset:Dot(rightVec)
        
        -- Move slightly to the side enemy is moving towards
        if math.abs(dotProduct) > 0.3 then
            local sideOffset = lateralOffset * (enemySpeed * 0.1)
            blockPos = blockPos + sideOffset
        end
    end
    
    -- Adjust height
    blockPos = Vector3.new(blockPos.X, root.Position.Y, blockPos.Z)
    
    -- Draw predicted attack target at foot level
    if CONFIG.SHOW_ATTACK_TARGET and moduleState.enabled then
        drawAttackTarget(predictedBlockPos)
    end
    
    -- Move to blocking position
    moveToTarget(root, blockPos)
    
    -- Smart rotation: look at predicted enemy position, not current position
    rotateSmooth(root, predictedBlockPos, false, false, Vector3.new())
    
    -- If enemy has ball and we're close enough, we can block the shot
    if hasBall and distToTarget < CONFIG.ATTACK_DISTANCE * 1.2 then
        -- Look directly at enemy to block shot
        rotateSmooth(root, predictedBlockPos, false, false, Vector3.new())
        moduleState.lastAttackTime = tick()
        return true
    end
    
    return false
end

-- FIXED DIVE FUNCTION - NO MORE FLYING BUG
local function performDive(root, hum, diveTarget)
    moduleState.isDiving = true
    moduleState.lastDiveTime = tick()
    
    -- Determine dive direction relative to goal
    local relToGoal = diveTarget - GoalCFrame.Position
    local lateralDist = relToGoal:Dot(GoalCFrame.RightVector)
    local dir = lateralDist > 0 and "Right" or "Left"

    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir.."Dive", root.CFrame)
    end)

    -- FIXED: Calculate dive direction with proper limits
    local toTarget = diveTarget - root.Position
    local horizontalDir = Vector3.new(toTarget.X, 0, toTarget.Z)
    
    -- Normalize and limit the direction
    if horizontalDir.Magnitude > 0.1 then
        horizontalDir = horizontalDir.Unit
    else
        -- If already at target, dive forward
        horizontalDir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
        if horizontalDir.Magnitude > 0 then
            horizontalDir = horizontalDir.Unit
        else
            horizontalDir = Vector3.new(1, 0, 0) -- Default direction
        end
    end
    
    -- FIXED: Limit speed more aggressively to prevent launching
    local diveSpeed = math.min(CONFIG.DIVE_SPEED, 35) -- Reduced from 45 to 35
    
    -- FIXED: Create dive velocity with much shorter duration and lower force
    local diveBV = Instance.new("BodyVelocity", root)
    diveBV.MaxForce = Vector3.new(2000000, 2000000, 2000000) -- Reduced vertical force
    diveBV.Velocity = horizontalDir * diveSpeed + Vector3.new(0, 8, 0) -- Small vertical boost
    
    -- FIXED: Much shorter duration
    game.Debris:AddItem(diveBV, 0.3) -- Reduced from 0.6 to 0.3
    
    -- FIXED: Quick deceleration with stronger tween
    if ts then
        ts:Create(diveBV, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = Vector3.new()}):Play()
    end

    -- FIXED: Create gyro for stability with reduced torque
    local diveGyro = Instance.new("BodyGyro", root)
    diveGyro.P = 1500000 -- Reduced
    diveGyro.MaxTorque = Vector3.new(0, 2000000, 0) -- Reduced torque
    diveGyro.CFrame = CFrame.lookAt(root.Position, diveTarget)
    game.Debris:AddItem(diveGyro, 0.5) -- Reduced duration

    -- Play dive animation
    local lowDive = (diveTarget.Y <= 3.8)
    pcall(function()
        local animName = dir .. (lowDive and "LowDive" or "Dive")
        local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK[animName])
        anim.Priority = Enum.AnimationPriority.Action4
        anim:Play()
    end)

    -- Disable jumping during dive
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    
    -- FIXED: Add downward force after dive to prevent flying
    task.delay(0.15, function()
        if root and root.Parent then
            local downForce = Instance.new("BodyVelocity", root)
            downForce.MaxForce = Vector3.new(0, 4500000, 0)
            downForce.Velocity = Vector3.new(0, -25, 0) -- Strong downward force
            game.Debris:AddItem(downForce, 0.25)
            
            -- Quick deceleration
            if ts then
                ts:Create(downForce, TweenInfo.new(0.15), {Velocity = Vector3.new()}):Play()
            end
        end
    end)
    
    -- Re-enable after dive
    task.delay(0.8, function()
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        end
        moduleState.isDiving = false
        
        -- Clean up physics
        if diveBV then 
            pcall(function() diveBV:Destroy() end) 
        end
        if diveGyro then 
            pcall(function() diveGyro:Destroy() end) 
        end
    end)
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
    
    clearAllVisuals()
    moduleState.isDiving = false
    moduleState.cachedPoints = nil
    moduleState.smoothCFrame = nil
    moduleState.attackTargetHistory = {}
    moduleState.predictedEnemyPositions = {}
    moduleState.currentAttackTarget = nil
    moduleState.attackTargetVisible = false
end

-- Main heartbeat cycle
local function startHeartbeat()
    moduleState.heartbeatConnection = rs.Heartbeat:Connect(function()
        if not moduleState.enabled then 
            hideAllVisuals()
            return 
        end
        
        moduleState.frameCounter = moduleState.frameCounter + 1
        
        -- Check if still goalkeeper
        if not checkIfGoalkeeper() then
            hideAllVisuals()
            if moduleState.currentBV then pcall(function() moduleState.currentBV:Destroy() end) moduleState.currentBV = nil end
            if moduleState.currentGyro then pcall(function() moduleState.currentGyro:Destroy() end) moduleState.currentGyro = nil end
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
                moveToTarget(root, GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST) 
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

        -- Draw visuals
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

        -- Find attack target (smart block enemy FOV)
        if CONFIG.PRIORITY == "attack" or CONFIG.AUTO_ATTACK_IN_ZONE then
            attackTargetPlayer = findAttackTarget(root.Position, ball)
            
            -- If enemy found in defense zone and auto attack enabled
            if attackTargetPlayer and CONFIG.AUTO_ATTACK_IN_ZONE then
                local targetRoot = attackTargetPlayer.Character and attackTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot and isInDefenseZone(targetRoot.Position) then
                    -- Smart block enemy FOV with prediction
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

        if owner and owner ~= player and owner.Character then
            oRoot = owner.Character:FindFirstChild("HumanoidRootPart")
            if oRoot then
                local rel = oRoot.Position - GoalCFrame.Position
                enemyDistFromLine = rel:Dot(GoalForward)
                enemyLateral = rel:Dot(GoalCFrame.RightVector)
                distToEnemy = (root.Position - oRoot.Position).Magnitude
                isAggro = enemyDistFromLine < CONFIG.AGGRO_THRES and distToEnemy < CONFIG.MAX_CHASE_DIST and hasWeld
                
                -- Smart block enemy with ball (with prediction)
                if isAggro and not smartBlockActive then
                    smartBlockActive = true
                    -- Use predicted position for blocking
                    local predictedEnemyPos = predictEnemyPosition(oRoot)
                    local viewBlockPos = (predictedEnemyPos + GoalCFrame.Position) / 2 + GoalForward * 1.2
                    viewBlockPos = Vector3.new(viewBlockPos.X, root.Position.Y, viewBlockPos.Z)
                    moveToTarget(root, viewBlockPos)
                    
                    -- Draw predicted position at foot level
                    if CONFIG.SHOW_ATTACK_TARGET then
                        drawAttackTarget(predictedEnemyPos)
                    end
                elseif not isAggro and moduleState.currentAttackTarget == owner then
                    -- If enemy is no longer a threat, hide target immediately
                    hideAttackTarget()
                end
            end
        end

        -- If aggressive mode enabled and enemy has ball, chase them with prediction
        if CONFIG.AGGRESSIVE_MODE and owner and owner ~= player and oRoot and not smartBlockActive then
            local predictedPos = predictEnemyPosition(oRoot)
            local targetPos = predictedPos + GoalForward * CONFIG.ATTACK_DISTANCE
            moveToTarget(root, targetPos)
            smartBlockActive = true
            
            -- Draw predicted position
            if CONFIG.SHOW_ATTACK_TARGET then
                drawAttackTarget(predictedPos)
            end
        elseif CONFIG.AGGRESSIVE_MODE and not owner and moduleState.currentAttackTarget then
            -- If aggressive mode but no enemy with ball, hide target
            hideAttackTarget()
        end

        -- Hide attack target if no active target
        if not attackTargetPlayer and not isAggro and not CONFIG.AGGRESSIVE_MODE then
            if moduleState.currentAttackTarget then
                hideAttackTarget()
            end
        end

        local points, endpoint = nil, nil
        local threatLateral = 0
        local isShot = not hasWeld and owner ~= player
        local distEnd = math.huge
        local velMag = ball.Velocity.Magnitude
        local distBall = (root.Position - ball.Position).Magnitude
        local isThreat = false
        local timeToEndpoint = 999

        -- Update prediction on new shot
        local freshShot = false
        if velMag > 18 and moduleState.lastBallVelMag <= 18 then
            freshShot = true
            moduleState.cachedPoints = nil
            clearTrajAndEndpoint()
        end
        moduleState.lastBallVelMag = velMag

        if isShot and (moduleState.frameCounter % 2 == 0 or freshShot or not moduleState.cachedPoints) then
            moduleState.cachedPoints = predictTrajectory(ball)
        end
        points = moduleState.cachedPoints
        
        if points then
            endpoint = points[#points]
            distEnd = (root.Position - endpoint).Magnitude
            threatLateral = (endpoint - GoalCFrame.Position):Dot(GoalCFrame.RightVector)
            isThreat = (endpoint - GoalCFrame.Position):Dot(GoalForward) < 2.6 and math.abs(threatLateral) < GoalWidth / 2.0
            local distBallEnd = (ball.Position - endpoint).Magnitude
            timeToEndpoint = distBallEnd / math.max(1, velMag)
        else
            clearTrajAndEndpoint()
        end

        -- Draw trajectory (always render every frame)
        if CONFIG.SHOW_TRAJECTORY and points and moduleState.visualObjects.trajLines then
            local cam = ws.CurrentCamera
            for i = 1, math.min(CONFIG.PRED_STEPS, #points - 1) do
                local p1 = cam:WorldToViewportPoint(points[i])
                local p2 = cam:WorldToViewportPoint(points[i + 1])
                local l = moduleState.visualObjects.trajLines[i]
                if l then
                    l.From = Vector2.new(p1.X, p1.Y)
                    l.To = Vector2.new(p2.X, p2.Y)
                    l.Visible = p1.Z > 0 and p2.Z > 0 and (points[i + 1] - root.Position).Magnitude < 70
                end
            end
            if CONFIG.SHOW_ENDPOINT and endpoint then
                drawEndpoint(endpoint)
            end
        else 
            clearTrajAndEndpoint() 
        end

        -- Draw ball box (always render every frame)
        if CONFIG.SHOW_BALL_BOX and distBall < 70 and moduleState.visualObjects.BallBox then 
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
            drawCube(moduleState.visualObjects.BallBox, CFrame.new(ball.Position), Vector3.new(3.5, 3.5, 3.5), col)
        elseif moduleState.visualObjects.BallBox then 
            drawCube(moduleState.visualObjects.BallBox, nil) 
        end

        local rightVec = GoalCFrame.RightVector
        local defenseBase = GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST
        local lateral = 0

        -- Only if not smart blocking enemy
        if not smartBlockActive then
            if isMyBall then
                lateral = 0
            elseif oRoot and isAggro then
                local targetDist = math.max(2.0, enemyDistFromLine - 1.5)
                defenseBase = GoalCFrame.Position + GoalForward * targetDist
                lateral = enemyLateral * 1.02
            elseif not hasWeld then
                lateral = threatLateral * 0.82
                defenseBase = GoalCFrame.Position + GoalForward * math.min(6.0, distBall * 0.085)
            else
                local targetDist = math.max(CONFIG.STAND_DIST, math.min(8.0, enemyDistFromLine * 0.50))
                defenseBase = GoalCFrame.Position + GoalForward * targetDist
                local centerBias = math.max(0, 1 - (enemyDistFromLine / CONFIG.CENTER_BIAS_DIST))
                lateral = enemyLateral * centerBias
            end

            local threatWeight = isThreat and 0.99 or (distEnd < CONFIG.CLOSE_THREAT_DIST and 0.96 or 0.45)
            lateral = threatLateral * threatWeight + lateral * (1 - threatWeight)

            local bestPos = getSmartPosition(defenseBase, rightVec, lateral, GoalWidth, threatLateral, enemyLateral, isAggro)
            
            -- Improved logic: Try to intercept ball, not just run to endpoint
            if isShot and points and isThreat then
                local interceptPoint = findBestInterceptPoint(root.Position, ball.Position, ball.Velocity, points)
                if interceptPoint then
                    -- If can intercept - go to intercept point
                    local adjustedPos = interceptPoint + GoalForward * CONFIG.ADVANCE_DISTANCE
                    adjustedPos = Vector3.new(adjustedPos.X, root.Position.Y, adjustedPos.Z)
                    bestPos = adjustedPos
                elseif distEnd > 8 and timeToEndpoint > 1.0 then
                    -- If ball is flying slowly - advance forward
                    local advancePos = defenseBase + GoalForward * CONFIG.ADVANCE_DISTANCE * 2
                    bestPos = Vector3.new(advancePos.X, root.Position.Y, advancePos.Z)
                end
            end
            
            moveToTarget(root, bestPos)
        end

        -- Improved rotation (look at ball, except when smart blocking enemy)
        if smartBlockActive and attackTargetPlayer then
            local targetRoot = attackTargetPlayer.Character and attackTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                -- Look at predicted enemy position for better blocking
                local predictedPos = moduleState.predictedEnemyPositions[tostring(targetRoot.Parent:GetDebugId())] or targetRoot.Position
                rotateSmooth(root, predictedPos, isMyBall, moduleState.isDiving, ball.Velocity)
            else
                rotateSmooth(root, ball.Position, isMyBall, moduleState.isDiving, ball.Velocity)
            end
        else
            rotateSmooth(root, ball.Position, isMyBall, moduleState.isDiving, ball.Velocity)
        end

        -- ACTIONS
        if not isMyBall and not moduleState.isDiving then
            -- Intercept ball nearby
            if distBall < CONFIG.BALL_INTERCEPT_RANGE and velMag < CONFIG.DIVE_VEL_THRES * 0.82 then
                for _, hand in {char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand")} do
                    if hand and (hand.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
                        firetouchinterest(hand, ball, 0)
                        task.wait(0.025)
                        firetouchinterest(hand, ball, 1)
                    end
                end
            end

            -- Jump for high balls
            local highThreat = isThreat and endpoint and endpoint.Y > CONFIG.HIGH_BALL_THRES and distEnd < 10.0 and velMag > CONFIG.JUMP_VEL_THRES
            if highThreat and tick() - moduleState.lastJumpTime > CONFIG.JUMP_COOLDOWN then
                forceJump(hum)
                moduleState.lastJumpTime = tick()
            end

            -- Dive
            local emergency = false
            if isThreat then
                if distEnd < CONFIG.ENDPOINT_DIVE then
                    emergency = true
                elseif timeToEndpoint < 0.40 then
                    emergency = true
                elseif distBall < CONFIG.DIVE_DIST and velMag > CONFIG.DIVE_VEL_THRES then
                    emergency = true
                end
            end
            
            -- Use fixed dive function
            if emergency and tick() - moduleState.lastDiveTime > CONFIG.DIVE_COOLDOWN then
                performDive(root, hum, endpoint or ball.Position)
            end
        else
            if isMyBall then 
                moduleState.isDiving = false 
            end
        end

        if not isShot or not points then
            clearTrajAndEndpoint()
        end
    end)
end

-- Sync configuration with UI
local function syncConfig()
    -- Update config from UI elements
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
    CONFIG.SHOW_TRAJECTORY = moduleState.uiElements.ShowTrajectory and moduleState.uiElements.ShowTrajectory:GetState()
    CONFIG.SHOW_ENDPOINT = moduleState.uiElements.ShowEndpoint and moduleState.uiElements.ShowEndpoint:GetState()
    CONFIG.SHOW_GOAL_CUBE = moduleState.uiElements.ShowGoalCube and moduleState.uiElements.ShowGoalCube:GetState()
    CONFIG.SHOW_ZONE = moduleState.uiElements.ShowZone and moduleState.uiElements.ShowZone:GetState()
    CONFIG.SHOW_BALL_BOX = moduleState.uiElements.ShowBallBox and moduleState.uiElements.ShowBallBox:GetState()
    CONFIG.SHOW_ATTACK_TARGET = moduleState.uiElements.ShowAttackTarget and moduleState.uiElements.ShowAttackTarget:GetState()
    
    -- Update colors
    
    -- Update visual colors
    updateVisualColors()
    
    -- Update module state
    moduleState.enabled = CONFIG.ENABLED
    
    -- Restart if needed
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
    
    -- Store notify function for later use
    moduleState.notify = notifyFunc
    
    -- Create main section in AutoGoalKeeper
    if UI.Sections.AutoGoalKeeper then
        -- BASIC SETTINGS
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
        
        -- Movement Settings
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
        
        -- ADVANCED SETTINGS SECTION
        UI.Sections.AutoGoalKeeper:Header({ Name = "Dive & Jump Settings" })
        
        -- Dive Settings
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
        
        -- Jump Settings
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
        
        -- DEFENSE ZONE SECTION
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
        
        -- SMART ATTACK SETTINGS SECTION
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
        
        -- PREDICTION SETTINGS SECTION
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
        
        -- ADVANCED DEFENSE SECTION
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
        
        -- VISUAL SETTINGS SECTION
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
        
        -- COLOR SETTINGS SECTION
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
        
        -- Information Section
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

PREDICTION:
21 Prediction Steps: Accuracy of ball trajectory prediction
22 Gravity: Ball gravity in prediction
23 Air Drag: Air resistance for ball
24 Curve Multiplier: How much curve affects trajectory
25 Bounce settings: How ball bounces off surfaces

ADVANCED DEFENSE:
26 Ball Intercept Range: Distance for intercepting ball
27 Min Intercept Time: Minimum time needed to intercept
28 Advance Distance: How far to advance from goal
29 Rotation Smoothness: Smoothness of turning
30 Dive Look Ahead: How far ahead to look during dive
]]
        })
    end
    
    -- Create Sync section in Config tab
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


