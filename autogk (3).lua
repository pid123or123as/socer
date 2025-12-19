local player = game.Players.LocalPlayer
local ws = workspace
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- V50 ADVANCED AI DEFENSE - ENHANCED CONFIGURATION
local CONFIG = {
    -- === BASIC SETTINGS ===
    ENABLED = false,
    
    -- === MOVEMENT ===
    SPEED = 36,
    STAND_DIST = 2.4,
    MIN_DIST = 0.8,
    MAX_CHASE_DIST = 38,
    
    -- === DISTANCES ===
    AGGRO_THRES = 32,
    DIVE_DIST = 12,
    ENDPOINT_DIVE = 3.2,
    TOUCH_RANGE = 7.5,
    NEAR_BALL_DIST = 6,
    
    -- === DEFENSE ZONE ===
    ZONE_DIST = 48,
    ZONE_WIDTH = 2.3,
    
    -- === THRESHOLDS ===
    DIVE_VEL_THRES = 16,
    JUMP_VEL_THRES = 28,
    HIGH_BALL_THRES = 5.8,
    CLOSE_THREAT_DIST = 3.2,
    JUMP_THRES = 4.5,
    GATE_COVERAGE = 1.02,
    CENTER_BIAS_DIST = 18,
    LATERAL_MAX_MULT = 0.48,
    
    -- === COOLDOWNS ===
    DIVE_COOLDOWN = 1.1,
    JUMP_COOLDOWN = 0.8,
    ATTACK_COOLDOWN = 1.2,
    
    -- === DIVE SETTINGS ===
    DIVE_SPEED = 38,
    
    -- === VISUAL SETTINGS ===
    SHOW_TRAJECTORY = true,
    SHOW_ENDPOINT = true,
    SHOW_GOAL_CUBE = true,
    SHOW_ZONE = true,
    SHOW_BALL_BOX = true,
    SHOW_ATTACK_TARGET = true,
    
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
    
    -- === ROTATION SETTINGS ===
    ROT_SMOOTH = 0.82,
    USE_SMOOTH_ROTATION = true,
    LOOK_AT_BALL_WHEN_CLOSE = true,
    MIN_LOOK_DISTANCE = 10,
    
    -- === ADVANCED DEFENSE ===
    BALL_INTERCEPT_RANGE = 4.0,
    MIN_INTERCEPT_TIME = 0.08,
    ADVANCE_DISTANCE = 3.2,
    DIVE_LOOK_AHEAD = 0.18,
    
    -- === INTELLIGENT POSITIONING ===
    REACTION_TIME = 0.15,
    ANTICIPATION_DIST = 1.5,
    CORNER_BIAS = 0.7,
    SIDE_POSITIONING = 0.65,
    
    -- === ATTACK SETTINGS ===
    PRIORITY = "defense",
    AUTO_ATTACK_IN_ZONE = true,
    ATTACK_DISTANCE = 30,
    ATTACK_PREDICT_TIME = 0.12,
    AGGRESSIVE_MODE = false,
    PRESSURE_DISTANCE = 15,
    BLOCK_ANGLE_THRESHOLD = 45,
    
    -- === JUMP SETTINGS ===
    JUMP_POWER = 32,
    JUMP_HEIGHT = 6,
    JUMP_WHEN_HIGH_BALL = true,
    JUMP_PREDICTION_TIME = 0.3,
    
    -- === GATE PROTECTION ===
    GATE_EDGE_MARGIN = 2.0,
    GATE_HEIGHT_PROTECTION = 8.0,
    GATE_CENTER_PRIORITY = 0.8,
    
    -- === PREDICTION SETTINGS ===
    PRED_STEPS = 140,
    CURVE_MULT = 42,
    DT = 1/90,
    GRAVITY = 108,
    DRAG = 0.984,
    BOUNCE_XZ = 0.74,
    BOUNCE_Y = 0.72,
    
    -- === ENHANCED AI SETTINGS ===
    PREDICT_ENEMY_MOVEMENT = true,
    USE_ADAPTIVE_TACTICS = true,
    LEARN_ENEMY_PATTERNS = false,
    THREAT_LEVEL_HIGH = 0.8,
    THREAT_LEVEL_MEDIUM = 0.5,
    THREAT_LEVEL_LOW = 0.2,
    
    -- === PERFORMANCE OPTIMIZATION ===
    UPDATE_RATE = 0.016,
    VISUAL_UPDATE_RATE = 0.1,
    CACHE_PREDICTIONS = true,
    MAX_CACHE_TIME = 0.5
}

-- Module state
local moduleState = {
    enabled = false,
    lastDiveTime = 0,
    lastJumpTime = 0,
    lastAttackTime = 0,
    lastTouchTime = 0,
    isDiving = false,
    isJumping = false,
    endpointRadius = 3.5,
    currentTargetType = nil,
    frameCounter = 0,
    cachedPoints = nil,
    cachedPointsTime = 0,
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
    
    -- Enhanced decision making
    threatAnalysis = {
        lastThreatPos = nil,
        threatDirection = nil,
        threatSpeed = 0,
        threatLevel = 0,
        isCloseRange = false,
        isCornerKick = false,
        isDirectShot = false,
        predictedImpactPoint = nil,
        timeToImpact = 999
    },
    
    positioning = {
        optimalPosition = nil,
        lastSideChoice = 0,
        sideBiasTimer = 0,
        gateCoveragePoints = {},
        vulnerabilityMap = {}
    },
    
    -- Physics control
    divePhysics = {
        activeBV = nil,
        activeGyro = nil,
        diveStartTime = 0,
        diveDirection = nil
    },
    
    -- Jump control
    jumpPhysics = {
        isJumping = false,
        jumpStartTime = 0,
        jumpTarget = nil
    },
    
    -- Enemy tracking
    enemyDatabase = {
        players = {},
        patterns = {},
        lastPositions = {},
        shootingHabits = {}
    },
    
    -- Performance
    lastUpdateTime = 0,
    lastVisualUpdate = 0,
    predictionCache = {}
}

-- Global variables
local GoalCFrame, GoalForward, GoalWidth, GoalRight = nil, nil, 0, nil
local maxDistFromGoal = 50

-- Create enhanced visuals function
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
    
    -- Gate coverage visualization
    moduleState.visualObjects.gateCoverage = {}
    for i = 1, 10 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = Color3.fromRGB(255, 165, 0)
        line.Transparency = 0.3
        line.Visible = false
        moduleState.visualObjects.gateCoverage[i] = line
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
    
    if moduleState.visualObjects.trajLines then
        local baseH, baseS, baseV = CONFIG.TRAJECTORY_COLOR:ToHSV()
        for i, line in ipairs(moduleState.visualObjects.trajLines) do
            if line then
                local hue = (baseH + (i / CONFIG.PRED_STEPS) * 0.3) % 1
                line.Color = Color3.fromHSV(hue, baseS, baseV)
            end
        end
    end
    
    if moduleState.visualObjects.gateCoverage then
        for _, line in ipairs(moduleState.visualObjects.gateCoverage) do
            if line then
                line.Color = Color3.fromRGB(255, 165, 0)
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

-- Enhanced goalkeeper check
local function checkIfGoalkeeper()
    if tick() - moduleState.lastGoalkeeperCheck < 0.5 then 
        return moduleState.isGoalkeeper 
    end
    
    moduleState.lastGoalkeeperCheck = tick()
    local isHPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("HPG") and ws.Bools.HPG.Value == player
    local isAPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("APG") and ws.Bools.APG.Value == player
    
    local wasGoalkeeper = moduleState.isGoalkeeper
    moduleState.isGoalkeeper = isHPG or isAPG
    
    if wasGoalkeeper and not moduleState.isGoalkeeper then
        hideAllVisuals()
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
    end
    
    if moduleState.isGoalkeeper and not wasGoalkeeper and moduleState.enabled then
        createVisuals()
    end
    
    return moduleState.isGoalkeeper
end

-- Enhanced goal update with caching
local lastGoalUpdate = 0
local goalCacheValid = false

local function updateGoals()
    if tick() - lastGoalUpdate < 1 and goalCacheValid then 
        return true 
    end
    
    if not checkIfGoalkeeper() then 
        return false 
    end
    
    local isHPG = ws.Bools.HPG.Value == player
    local isAPG = ws.Bools.APG.Value == player
    
    local posModelName = isHPG and "HomePosition" or "AwayPosition"
    local posModel = ws:FindFirstChild(posModelName)
    if not posModel then 
        return false 
    end
    
    local parts = {}
    for _, obj in posModel:GetDescendants() do 
        if obj:IsA("BasePart") then 
            table.insert(parts, obj) 
        end 
    end
    if #parts == 0 then 
        return false 
    end
    
    local center = Vector3.new()
    for _, part in ipairs(parts) do 
        center = center + part.Position 
    end 
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
            GoalRight = rightDir
            
            local fieldDir = center - gcenter
            fieldDir = fieldDir - fieldDir:Dot(rightDir) * rightDir  
            fieldDir = Vector3.new(fieldDir.X, 0, fieldDir.Z)
            
            local fwdMag = fieldDir.Magnitude
            if fwdMag > 0.1 then
                GoalForward = fieldDir.Unit
            else
                GoalForward = rightDir:Cross(Vector3.new(0, 1, 0)).Unit
            end
            
            local minDist, maxDist = math.huge, -math.huge
            for _, part in ipairs(parts) do
                local rel = part.Position - gcenter  
                local dist = rel:Dot(GoalForward)
                minDist = math.min(minDist, dist)
                maxDist = math.max(maxDist, dist)
            end
            
            if maxDist - minDist < 10 or maxDist < 10 then
                GoalForward = -GoalForward
                minDist, maxDist = math.huge, -math.huge
                for _, part in ipairs(parts) do
                    local rel = part.Position - gcenter
                    local dist = rel:Dot(GoalForward)
                    minDist = math.min(minDist, dist)
                    maxDist = math.max(maxDist, dist)
                end
            end
            
            GoalCFrame = CFrame.fromMatrix(gcenter, rightDir, Vector3.new(0, 1, 0), -GoalForward)
            GoalWidth = (right.Position - left.Position).Magnitude
            maxDistFromGoal = math.max(34, maxDist - minDist + 15)
            
            -- Calculate gate coverage points
            moduleState.positioning.gateCoveragePoints = {
                left = left.Position,
                right = right.Position,
                topLeft = left.Position + Vector3.new(0, CONFIG.GATE_HEIGHT_PROTECTION, 0),
                topRight = right.Position + Vector3.new(0, CONFIG.GATE_HEIGHT_PROTECTION, 0),
                center = gcenter,
                centerTop = gcenter + Vector3.new(0, CONFIG.GATE_HEIGHT_PROTECTION / 2, 0)
            }
            
            lastGoalUpdate = tick()
            goalCacheValid = true
            return true
        end
    end
    return false
end

-- Enhanced cube drawing
local function drawCube(cube, cf, size, color)
    if not cube or not cf or not cf.Position then 
        if cube then
            for _, l in ipairs(cube) do 
                if l then 
                    l.Visible = false 
                end 
            end 
        end
        return 
    end
    
    local cam = ws.CurrentCamera
    if not cam then 
        return 
    end
    
    local h = size / 2
    local corners = {
        cf * Vector3.new(-h.X, -h.Y, -h.Z), 
        cf * Vector3.new( h.X, -h.Y, -h.Z), 
        cf * Vector3.new( h.X,  h.Y, -h.Z), 
        cf * Vector3.new(-h.X,  h.Y, -h.Z),
        cf * Vector3.new(-h.X, -h.Y,  h.Z), 
        cf * Vector3.new( h.X, -h.Y,  h.Z), 
        cf * Vector3.new( h.X,  h.Y,  h.Z), 
        cf * Vector3.new(-h.X,  h.Y,  h.Z)
    }
    
    local edges = {
        {1,2}, {2,3}, {3,4}, {4,1},
        {5,6}, {6,7}, {7,8}, {8,5},
        {1,5}, {2,6}, {3,7}, {4,8}
    }
    
    for i, e in ipairs(edges) do
        local a, b = corners[e[1]], corners[e[2]]
        local sa, sb = cam:WorldToViewportPoint(a), cam:WorldToViewportPoint(b)
        local l = cube[i]
        
        if l then
            l.From = Vector2.new(sa.X, sa.Y) 
            l.To = Vector2.new(sb.X, sb.Y) 
            l.Color = color or l.Color or Color3.new(1, 1, 1)
            l.Visible = sa.Z > 0 and sb.Z > 0
        end
    end
end

local function drawFlatZone()
    if not (GoalCFrame and GoalForward and GoalWidth) or not moduleState.visualObjects.LimitCube then 
        if moduleState.visualObjects.LimitCube then
            for _, l in ipairs(moduleState.visualObjects.LimitCube) do 
                if l then 
                    l.Visible = false 
                end 
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
                if l then 
                    l.Visible = false 
                end 
            end 
        end
        return 
    end
    
    local cam = ws.CurrentCamera 
    if not cam then 
        return 
    end
    
    local step = math.pi * 2 / 24
    for i = 1, 24 do
        local a1, a2 = (i - 1) * step, i * step
        local p1 = pos + Vector3.new(math.cos(a1) * moduleState.endpointRadius, 0, math.sin(a1) * moduleState.endpointRadius)
        local p2 = pos + Vector3.new(math.cos(a2) * moduleState.endpointRadius, 0, math.sin(a2) * moduleState.endpointRadius)
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
                if l then 
                    l.Visible = false 
                end 
            end 
        end
        moduleState.attackTargetVisible = false
        return 
    end
    
    local cam = ws.CurrentCamera 
    if not cam then 
        return 
    end
    
    local footPos = Vector3.new(pos.X, 0.5, pos.Z)
    local step = math.pi * 2 / 36
    local radius = 2.0
    
    for i = 1, 36 do
        local a1, a2 = (i - 1) * step, i * step
        local p1 = footPos + Vector3.new(math.cos(a1) * radius, 0.1, math.sin(a1) * radius)
        local p2 = footPos + Vector3.new(math.cos(a2) * radius, 0.1, math.sin(a2) * radius)
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

local function hideAttackTarget()
    if moduleState.visualObjects.attackTarget then
        for _, l in ipairs(moduleState.visualObjects.attackTarget) do 
            if l then 
                l.Visible = false 
            end
        end
    end
    moduleState.attackTargetVisible = false
    moduleState.currentAttackTarget = nil
end

-- Enhanced trajectory prediction with caching
local function predictTrajectory(ball)
    if CONFIG.CACHE_PREDICTIONS and moduleState.cachedPoints and tick() - moduleState.cachedPointsTime < CONFIG.MAX_CACHE_TIME then
        return moduleState.cachedPoints
    end
    
    local points = {ball.Position}
    local pos, vel = ball.Position, ball.Velocity
    local dt = CONFIG.DT
    local gravity = CONFIG.GRAVITY
    local drag = CONFIG.DRAG
    local steps = CONFIG.PRED_STEPS
    local spinCurve = Vector3.new(0, 0, 0)
    
    pcall(function()
        if ws.Bools.Curve and ws.Bools.Curve.Value then 
            spinCurve = ball.CFrame.RightVector * CONFIG.CURVE_MULT * 0.035
        end
        if ws.Bools.Header and ws.Bools.Header.Value then 
            spinCurve = spinCurve + Vector3.new(0, 26, 0) 
        end
    end)
    
    for i = 1, steps do
        local curveFade = 1 - (i / steps) * 0.5
        vel = vel * drag + spinCurve * dt * curveFade
        vel = vel - Vector3.new(0, gravity * dt * 1.02, 0)
        pos = pos + vel * dt
        
        if pos.Y < 0.5 then
            pos = Vector3.new(pos.X, 0.5, pos.Z)
            vel = Vector3.new(vel.X * CONFIG.BOUNCE_XZ, math.abs(vel.Y) * CONFIG.BOUNCE_Y, vel.Z * CONFIG.BOUNCE_XZ)
        end
        table.insert(points, pos)
    end
    
    if CONFIG.CACHE_PREDICTIONS then
        moduleState.cachedPoints = points
        moduleState.cachedPointsTime = tick()
    end
    
    return points
end

-- Enhanced movement to target
local function moveToTarget(root, targetPos)
    if moduleState.currentBV then 
        pcall(function() 
            moduleState.currentBV:Destroy() 
        end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1, 0, 1)
    local distance = dirVec.Magnitude
    
    if distance < CONFIG.MIN_DIST then 
        return 
    end
    
    local speed = CONFIG.SPEED
    if distance < 5 then
        speed = speed * 0.7
    end
    
    moduleState.currentBV = Instance.new("BodyVelocity")
    moduleState.currentBV.Parent = root
    moduleState.currentBV.MaxForce = Vector3.new(4e5, 0, 4e5)
    moduleState.currentBV.Velocity = dirVec.Unit * speed
    
    game.Debris:AddItem(moduleState.currentBV, 0.8)
    
    if ts then
        ts:Create(moduleState.currentBV, tweenInfo, {Velocity = Vector3.new()}):Play()
    end
end

-- ENHANCED: Smart rotation that looks where needed
local function rotateSmooth(root, targetPos, isOwner, isDivingNow, ballVel)
    if isOwner then 
        if moduleState.currentGyro then 
            pcall(function() 
                moduleState.currentGyro:Destroy() 
            end) 
            moduleState.currentGyro = nil
        end
        moduleState.currentTargetType = "owner"
        return 
    end
    
    if isDivingNow then
        if moduleState.currentGyro then 
            pcall(function() 
                moduleState.currentGyro:Destroy() 
            end) 
            moduleState.currentGyro = nil
        end
        moduleState.currentTargetType = "dive"
        return
    end
    
    if not CONFIG.USE_SMOOTH_ROTATION then
        if moduleState.currentGyro then 
            pcall(function() 
                moduleState.currentGyro:Destroy() 
            end) 
            moduleState.currentGyro = nil
        end
        return
    end
    
    if not moduleState.smoothCFrame then 
        moduleState.smoothCFrame = root.CFrame 
    end
    
    local finalLookPos = targetPos
    local distanceToTarget = (root.Position - targetPos).Magnitude
    
    -- Decide where to look based on situation
    if CONFIG.LOOK_AT_BALL_WHEN_CLOSE and distanceToTarget < CONFIG.MIN_LOOK_DISTANCE then
        -- Look at ball when it's close
        finalLookPos = targetPos
        moduleState.currentTargetType = "ball_close"
    elseif GoalCFrame then
        -- When ball is far, look at the most dangerous part of the goal
        local goalCenter = GoalCFrame.Position
        local toGoal = (goalCenter - root.Position).Unit
        
        -- Predict ball trajectory to goal
        local ball = ws:FindFirstChild("ball")
        if ball then
            local points = predictTrajectory(ball)
            if points and #points > 0 then
                local endpoint = points[#points]
                local threatLateral = (endpoint - goalCenter):Dot(GoalRight)
                
                if math.abs(threatLateral) > GoalWidth * 0.3 then
                    -- Ball heading to side of goal, look at that side
                    local sidePos = goalCenter + GoalRight * threatLateral
                    finalLookPos = sidePos
                    moduleState.currentTargetType = "goal_side"
                else
                    -- Ball heading to center, look at ball
                    finalLookPos = targetPos
                    moduleState.currentTargetType = "ball"
                end
            else
                finalLookPos = goalCenter
                moduleState.currentTargetType = "goal_center"
            end
        else
            finalLookPos = goalCenter
            moduleState.currentTargetType = "goal_center"
        end
    end
    
    local targetLook = CFrame.lookAt(root.Position, finalLookPos)
    moduleState.smoothCFrame = moduleState.smoothCFrame:Lerp(targetLook, CONFIG.ROT_SMOOTH)
    
    if moduleState.currentGyro then 
        pcall(function() 
            moduleState.currentGyro:Destroy() 
        end) 
        moduleState.currentGyro = nil
    end
    
    moduleState.currentGyro = Instance.new("BodyGyro")
    moduleState.currentGyro.Name = "GKRoto"
    moduleState.currentGyro.Parent = root
    moduleState.currentGyro.P = 2800000
    moduleState.currentGyro.MaxTorque = Vector3.new(0, 4e6, 0)
    moduleState.currentGyro.CFrame = moduleState.smoothCFrame
    
    game.Debris:AddItem(moduleState.currentGyro, 0.18)
end

-- Enhanced jump function
local function playJumpAnimation(hum)
    pcall(function()
        local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK.Jump)
        anim.Priority = Enum.AnimationPriority.Action4
        anim:Play()
    end)
end

local function forceJump(hum, targetPosition)
    if moduleState.isJumping then 
        return 
    end
    
    moduleState.isJumping = true
    moduleState.jumpPhysics.isJumping = true
    moduleState.jumpPhysics.jumpStartTime = tick()
    moduleState.jumpPhysics.jumpTarget = targetPosition
    
    -- Store original values
    local oldPower = hum.JumpPower
    local oldJumpHeight = hum.JumpHeight
    
    -- Set jump parameters
    hum.JumpPower = CONFIG.JUMP_POWER
    hum.Jump = true
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    
    -- Play jump animation
    playJumpAnimation(hum)
    
    -- Apply slight forward momentum if jumping toward ball
    if targetPosition then
        local dir = (targetPosition - hum.Parent.HumanoidRootPart.Position) * Vector3.new(1, 0, 1)
        if dir.Magnitude > 0.1 then
            dir = dir.Unit
            local bv = Instance.new("BodyVelocity")
            bv.Parent = hum.Parent.HumanoidRootPart
            bv.MaxForce = Vector3.new(20000, 0, 20000)
            bv.Velocity = dir * 15
            game.Debris:AddItem(bv, 0.3)
        end
    end
    
    -- Reset after jump
    task.delay(0.5, function()
        if hum and hum.Parent then
            hum.JumpPower = oldPower
        end
        moduleState.isJumping = false
        moduleState.jumpPhysics.isJumping = false
        moduleState.lastJumpTime = tick()
    end)
    
    -- Safety reset
    task.delay(1.0, function()
        moduleState.isJumping = false
        moduleState.jumpPhysics.isJumping = false
    end)
end

-- Enhanced smart positioning with gate protection
local function getSmartPosition(defenseBase, rightVec, lateral, goalWidth, threatLateral, enemyLateral, isAggro, ballPos, ballVel)
    local maxLateral = goalWidth * CONFIG.LATERAL_MAX_MULT
    local baseLateral = math.clamp(lateral, -maxLateral, maxLateral)
    
    -- Calculate threat level
    local threatLevel = moduleState.threatAnalysis.threatLevel or 0
    
    if threatLateral ~= 0 then 
        local threatWeight = 0.85 + (threatLevel * 0.14)  -- 0.85 to 0.99
        
        if ballPos and GoalCFrame then
            local ballDist = (ballPos - GoalCFrame.Position).Magnitude
            if ballDist < 20 then
                threatWeight = 0.92 + (threatLevel * 0.07)
            end
            
            -- Adjust for gate edges
            local gateEdgeLeft = -goalWidth/2 + CONFIG.GATE_EDGE_MARGIN
            local gateEdgeRight = goalWidth/2 - CONFIG.GATE_EDGE_MARGIN
            
            if threatLateral < gateEdgeLeft or threatLateral > gateEdgeRight then
                threatWeight = threatWeight * 1.1  -- Prioritize edges more
            end
        end
        
        baseLateral = threatLateral * threatWeight 
    end
    
    if enemyLateral ~= 0 and isAggro then 
        local enemyWeight = 0.82 + (threatLevel * 0.1)
        baseLateral = enemyLateral * enemyWeight
    end
    
    -- Ball trajectory anticipation
    if ballPos and ballVel and threatLateral ~= 0 then
        local ballToGoal = (GoalCFrame.Position - ballPos).Unit
        local rightDot = ballToGoal:Dot(rightVec)
        
        if math.abs(rightDot) > 0.3 then
            local anticipation = rightDot * CONFIG.ANTICIPATION_DIST * (1 + threatLevel)
            baseLateral = baseLateral + anticipation
        end
        
        -- Predict curve
        local ball = ws:FindFirstChild("ball")
        if ball then
            pcall(function()
                if ws.Bools.Curve and ws.Bools.Curve.Value then
                    local curveDir = ball.CFrame.RightVector
                    local curveDot = curveDir:Dot(rightVec)
                    baseLateral = baseLateral + curveDot * CONFIG.CURVE_MULT * 0.02
                end
            end)
        end
    end
    
    -- Center bias for high balls
    if ballPos and ballPos.Y > CONFIG.HIGH_BALL_THRES then
        local centerBias = math.max(0, 1 - (ballPos.Y - CONFIG.HIGH_BALL_THRES) / 10)
        baseLateral = baseLateral * (1 - centerBias * 0.3)
    end
    
    local finalLateral = math.clamp(baseLateral, -maxLateral * CONFIG.GATE_COVERAGE, maxLateral * CONFIG.GATE_COVERAGE)
    local finalPos = Vector3.new(
        defenseBase.X + rightVec.X * finalLateral, 
        defenseBase.Y, 
        defenseBase.Z + rightVec.Z * finalLateral
    )
    
    -- Ensure we stay in front of goal
    if GoalCFrame then
        local toGoal = finalPos - GoalCFrame.Position
        local forwardDist = toGoal:Dot(GoalForward)
        
        if forwardDist < CONFIG.STAND_DIST * 0.5 then
            finalPos = GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST * 0.5
        elseif forwardDist > CONFIG.ZONE_DIST * 0.8 then
            finalPos = GoalCFrame.Position + GoalForward * CONFIG.ZONE_DIST * 0.8
        end
    end
    
    moduleState.positioning.optimalPosition = finalPos
    
    return finalPos
end

local function clearTrajAndEndpoint()
    if moduleState.visualObjects.trajLines then
        for _, l in ipairs(moduleState.visualObjects.trajLines) do 
            if l then 
                l.Visible = false 
            end 
        end
    end
    
    if moduleState.visualObjects.endpointLines then
        for _, l in ipairs(moduleState.visualObjects.endpointLines) do 
            if l then 
                l.Visible = false 
            end 
        end
    end
end

-- Enhanced intercept point finding
local function findBestInterceptPoint(rootPos, ballPos, ballVel, points)
    if not points or #points < 2 then 
        return nil 
    end
    
    local bestPoint = nil
    local bestScore = math.huge
    local ballSpeed = ballVel.Magnitude
    
    for i = 2, math.min(#points, 80) do
        local point = points[i]
        local distToPoint = (rootPos - point).Magnitude
        local ballTravelDist = 0
        
        for j = 1, i - 1 do
            ballTravelDist = ballTravelDist + (points[j + 1] - points[j]).Magnitude
        end
        
        local timeToPoint = ballTravelDist / math.max(1, ballSpeed)
        local timeToReach = distToPoint / CONFIG.SPEED
        
        if timeToReach < timeToPoint - CONFIG.MIN_INTERCEPT_TIME then
            local score = distToPoint
            
            -- Penalize points behind us
            if GoalCFrame then
                local toGoal = (point - GoalCFrame.Position)
                local forwardDist = toGoal:Dot(GoalForward)
                if forwardDist < 0 then
                    score = score + 100  -- Heavy penalty for behind goal
                end
                
                -- Bonus for points in front of goal
                local lateralDist = math.abs(toGoal:Dot(GoalRight))
                if lateralDist < GoalWidth / 2 then
                    score = score - 20
                end
            end
            
            if score < bestScore then
                bestScore = score
                bestPoint = point
            end
        end
    end
    
    return bestPoint
end

-- Enhanced defense zone check
local function isInDefenseZone(position)
    if not (GoalCFrame and GoalForward) then 
        return false 
    end
    
    local relPos = position - GoalCFrame.Position
    local distForward = relPos:Dot(GoalForward)
    local distLateral = math.abs(relPos:Dot(GoalCFrame.RightVector))
    
    return distForward > 0 and distForward < CONFIG.ZONE_DIST and 
           distLateral < (GoalWidth * CONFIG.ZONE_WIDTH) / 2
end

-- Enhanced enemy position prediction
local function predictEnemyPosition(enemyRoot)
    if not enemyRoot then 
        return enemyRoot and enemyRoot.Position 
    end
    
    local currentTime = tick()
    local enemyId = tostring(enemyRoot.Parent:GetDebugId())
    
    if not moduleState.attackTargetHistory[enemyId] then
        moduleState.attackTargetHistory[enemyId] = {}
    end
    
    local history = moduleState.attackTargetHistory[enemyId]
    
    table.insert(history, {
        time = currentTime,
        position = enemyRoot.Position,
        velocity = enemyRoot.Velocity,
        lookVector = enemyRoot.CFrame.LookVector
    })
    
    while #history > 0 and currentTime - history[1].time > 0.5 do
        table.remove(history, 1)
    end
    
    if #history >= 2 then
        local avgVelocity = Vector3.new(0, 0, 0)
        local avgLook = Vector3.new(0, 0, 0)
        local count = 0
        
        for i = 2, #history do
            local timeDiff = history[i].time - history[i - 1].time
            if timeDiff > 0 then
                local vel = (history[i].position - history[i - 1].position) / timeDiff
                avgVelocity = avgVelocity + vel
                avgLook = avgLook + history[i].lookVector
                count = count + 1
            end
        end
        
        if count > 0 then
            avgVelocity = avgVelocity / count
            avgLook = avgLook / count
            
            -- Predict position with acceleration
            local predictedPos = enemyRoot.Position + avgVelocity * CONFIG.ATTACK_PREDICT_TIME
            
            -- Add look direction influence
            local lookInfluence = avgLook * 2
            predictedPos = predictedPos + lookInfluence * CONFIG.ATTACK_PREDICT_TIME
            
            moduleState.predictedEnemyPositions[enemyId] = predictedPos
            
            return predictedPos
        end
    end
    
    return enemyRoot.Position
end

-- Enhanced attack target finding
local function findAttackTarget(rootPos, ball)
    local bestTarget = nil
    local bestScore = -math.huge
    
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
                    local distToTarget = (rootPos - targetRoot.Position).Magnitude
                    local inZone = isInDefenseZone(targetRoot.Position)
                    
                    local score = 0
                    
                    -- High priority for enemies in zone
                    if inZone then
                        score = score + 70
                    end
                    
                    -- Very high priority for enemies with ball
                    local hasBall = false
                    pcall(function()
                        if ball:FindFirstChild("creator") and ball.creator.Value == otherPlayer then
                            hasBall = true
                            score = score + 150
                            
                            -- Extra bonus if they're facing goal
                            local targetLook = targetRoot.CFrame.LookVector
                            local toGoal = (GoalCFrame.Position - targetRoot.Position).Unit
                            local angle = math.deg(math.acos(math.clamp(targetLook:Dot(toGoal), -1, 1)))
                            
                            if angle < CONFIG.BLOCK_ANGLE_THRESHOLD then
                                score = score + 50
                            end
                        end
                    end)
                    
                    -- Distance scoring
                    score = score + (100 - math.min(distToTarget, 100))
                    
                    -- Position relative to goal
                    if GoalCFrame then
                        local toGoal = (GoalCFrame.Position - targetRoot.Position)
                        local forwardDist = toGoal:Dot(GoalForward)
                        
                        if forwardDist > 0 and forwardDist < CONFIG.AGGRO_THRES then
                            score = score + 40
                        end
                    end
                    
                    -- Aggressive mode bonus
                    if CONFIG.PRIORITY == "attack" or CONFIG.AGGRESSIVE_MODE then
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

-- Enhanced enemy blocking
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
    local toGoalDir = (goalCenter - predictedEnemyPos).Unit
    
    local enemyVelocity = targetRoot.Velocity
    local enemySpeed = enemyVelocity.Magnitude
    
    local predictedBlockPos = predictedEnemyPos
    
    -- Enhanced prediction
    if enemySpeed > 5 then
        local enemyMoveDir = enemyVelocity.Unit
        local enemyMoveDistance = enemySpeed * CONFIG.ATTACK_PREDICT_TIME * 1.8
        predictedBlockPos = predictedEnemyPos + enemyMoveDir * enemyMoveDistance
        
        -- Add look direction influence
        local lookDir = targetRoot.CFrame.LookVector
        predictedBlockPos = predictedBlockPos + lookDir * enemySpeed * 0.3
    end
    
    local blockDistance = CONFIG.ATTACK_DISTANCE
    
    -- Adjust distance based on ball possession
    local hasBall = false
    pcall(function()
        if ball:FindFirstChild("creator") and ball.creator.Value == targetPlayer then
            hasBall = true
            blockDistance = CONFIG.PRESSURE_DISTANCE  -- Get closer when they have ball
            
            -- Predict shot direction
            local enemyLook = targetRoot.CFrame.LookVector
            local shotTarget = predictedEnemyPos + enemyLook * 30
            predictedBlockPos = (predictedEnemyPos + shotTarget) / 2
        end
    end)
    
    local enemyToGoal = (goalCenter - predictedBlockPos).Unit
    local blockPos = predictedBlockPos + enemyToGoal * blockDistance
    
    -- Lateral adjustment based on enemy movement
    if enemySpeed > 3 then
        local rightVec = GoalCFrame.RightVector
        local lateralOffset = enemyToGoal:Cross(Vector3.new(0, 1, 0)).Unit
        local dotProduct = lateralOffset:Dot(rightVec)
        
        if math.abs(dotProduct) > 0.3 then
            local sideOffset = lateralOffset * (enemySpeed * 0.15)
            blockPos = blockPos + sideOffset
        end
    end
    
    -- Ensure we're between enemy and goal
    local toGoalFromBlock = (goalCenter - blockPos).Unit
    local toEnemyFromBlock = (predictedBlockPos - blockPos).Unit
    
    if toGoalFromBlock:Dot(toEnemyFromBlock) < 0.7 then
        blockPos = (predictedBlockPos + goalCenter) / 2
    end
    
    blockPos = Vector3.new(blockPos.X, root.Position.Y, blockPos.Z)
    
    if CONFIG.SHOW_ATTACK_TARGET and moduleState.enabled then
        drawAttackTarget(predictedBlockPos)
    end
    
    moveToTarget(root, blockPos)
    
    -- Look at enemy when blocking
    rotateSmooth(root, predictedBlockPos, false, false, Vector3.new())
    
    if hasBall and distToTarget < CONFIG.PRESSURE_DISTANCE * 1.5 then
        moduleState.lastAttackTime = tick()
        return true
    end
    
    return false
end

-- ENHANCED: Intelligent shot situation analysis
local function analyzeShotSituation(ballPos, ballVel, endpoint, rootPos, points)
    local analysis = {
        action = "none",      -- "jump", "dive", "stand", "touch", "block"
        confidence = 0,
        reason = "",
        urgency = 0,
        targetPosition = nil
    }
    
    if not ballPos or not endpoint then 
        return analysis 
    end
    
    local ballHeight = ballPos.Y
    local ballSpeed = ballVel.Magnitude
    local endpointHeight = endpoint.Y
    local distToEndpoint = (endpoint - rootPos).Magnitude
    local toEndpoint = (endpoint - rootPos).Unit
    local verticalAngle = math.deg(math.asin(math.clamp(ballVel.Y / math.max(ballSpeed, 0.1), -1, 1)))
    
    -- Calculate threat level
    local threatLevel = 0
    if GoalCFrame then
        local toGoal = (endpoint - GoalCFrame.Position)
        local forwardDist = toGoal:Dot(GoalForward)
        local lateralDist = math.abs(toGoal:Dot(GoalRight))
        
        if forwardDist < 2.6 and lateralDist < GoalWidth / 2 then
            threatLevel = 1.0  -- Direct shot at goal
        elseif forwardDist < 5 and lateralDist < GoalWidth then
            threatLevel = 0.7  -- Near goal
        elseif forwardDist < 10 then
            threatLevel = 0.4  -- In defense zone
        end
    end
    
    moduleState.threatAnalysis.threatLevel = threatLevel
    
    -- Determine if it's a high ball
    local isHighBall = ballHeight > CONFIG.HIGH_BALL_THRES
    local isVeryHighBall = ballHeight > CONFIG.HIGH_BALL_THRES + 3
    local isEndpointHigh = endpointHeight > CONFIG.JUMP_THRES
    
    -- Distance analysis
    local isVeryClose = distToEndpoint < CONFIG.ENDPOINT_DIVE
    local isClose = distToEndpoint < CONFIG.DIVE_DIST
    local isReachable = distToEndpoint < 12
    
    -- Speed analysis
    local isFastBall = ballSpeed > CONFIG.JUMP_VEL_THRES
    local isVeryFast = ballSpeed > CONFIG.JUMP_VEL_THRES + 15
    
    -- Angle analysis
    local isHighAngle = verticalAngle > 25
    local isLowAngle = verticalAngle < 15
    local isDirectShot = verticalAngle > 10 and verticalAngle < 30
    
    -- Time to react
    local timeToReach = distToEndpoint / math.max(ballSpeed, 1)
    
    -- DECISION MAKING WITH PRIORITIES
    
    -- 1. VERY CLOSE FAST BALL = EMERGENCY DIVE
    if isVeryClose and ballSpeed > CONFIG.DIVE_VEL_THRES * 1.2 then
        analysis.action = "dive"
        analysis.confidence = 0.95
        analysis.urgency = 1.0
        analysis.reason = "Экстренное ныряние: очень близкий быстрый мяч"
        analysis.targetPosition = endpoint
        return analysis
    end
    
    -- 2. HIGH BALL NEAR GOAL = JUMP
    if isEndpointHigh and isReachable and threatLevel > 0.5 then
        analysis.action = "jump"
        analysis.confidence = 0.9
        analysis.urgency = 0.9
        analysis.reason = "Прыжок: высокий мяч у ворот"
        analysis.targetPosition = endpoint + Vector3.new(0, CONFIG.JUMP_HEIGHT, 0)
        return analysis
    end
    
    -- 3. DIRECT SHOT WITH TIME = POSITION AND BLOCK
    if isDirectShot and isReachable and timeToReach > 0.5 then
        analysis.action = "block"
        analysis.confidence = 0.85
        analysis.urgency = 0.7
        analysis.reason = "Блок: прямой удар с запасом времени"
        analysis.targetPosition = endpoint
        return analysis
    end
    
    -- 4. CLOSE LOW FAST BALL = DIVE
    if isClose and isFastBall and isLowAngle then
        analysis.action = "dive"
        analysis.confidence = 0.8
        analysis.urgency = 0.8
        analysis.reason = "Ныряние: быстрый низкий мяч рядом"
        analysis.targetPosition = endpoint
        return analysis
    end
    
    -- 5. VERY HIGH BALL FROM DISTANCE = POSITIONING
    if isVeryHighBall and not isReachable then
        analysis.action = "stand"
        analysis.confidence = 0.75
        analysis.urgency = 0.5
        analysis.reason = "Позиционирование: высокий мяч издалека"
        
        -- Predict where it will come down
        if points then
            for i = #points, 1, -1 do
                if points[i].Y < CONFIG.HIGH_BALL_THRES then
                    analysis.targetPosition = points[i]
                    break
                end
            end
        end
        
        return analysis
    end
    
    -- 6. SLOW BALL IN RANGE = TOUCH
    if distToEndpoint < CONFIG.BALL_INTERCEPT_RANGE and ballSpeed < 20 then
        analysis.action = "touch"
        analysis.confidence = 0.7
        analysis.urgency = 0.6
        analysis.reason = "Касание: медленный мяч в досягаемости"
        analysis.targetPosition = ballPos
        return analysis
    end
    
    -- 7. DEFAULT = SMART POSITIONING
    analysis.action = "stand"
    analysis.confidence = 0.6
    analysis.urgency = 0.4
    analysis.reason = "Умное позиционирование"
    
    -- Find optimal position based on trajectory
    if points and GoalCFrame then
        local bestPos = nil
        local bestScore = math.huge
        
        for i = 2, math.min(#points, 50) do
            local point = points[i]
            local toGoal = (point - GoalCFrame.Position)
            local forwardDist = toGoal:Dot(GoalForward)
            local lateralDist = math.abs(toGoal:Dot(GoalRight))
            
            if forwardDist > 0 and forwardDist < 15 and lateralDist < GoalWidth / 2 then
                local distToPoint = (rootPos - point).Magnitude
                local ballTravelDist = 0
                
                for j = 1, i - 1 do
                    ballTravelDist = ballTravelDist + (points[j + 1] - points[j]).Magnitude
                end
                
                local timeToPoint = ballTravelDist / math.max(ballSpeed, 1)
                local timeToReachPoint = distToPoint / CONFIG.SPEED
                
                if timeToReachPoint < timeToPoint then
                    local score = distToPoint + math.abs(lateralDist) * 0.5
                    if score < bestScore then
                        bestScore = score
                        bestPos = point
                    end
                end
            end
        end
        
        if bestPos then
            analysis.targetPosition = bestPos + GoalForward * CONFIG.ADVANCE_DISTANCE
        end
    end
    
    return analysis
end

-- ENHANCED DIVE FUNCTION - OPTIMIZED FOR GATE PROTECTION
local function performDive(root, hum, diveTarget)
    if moduleState.isDiving then 
        return 
    end
    
    moduleState.isDiving = true
    moduleState.lastDiveTime = tick()
    moduleState.divePhysics.diveStartTime = tick()
    
    -- Clean up existing physics
    if moduleState.divePhysics.activeBV then 
        pcall(function() 
            moduleState.divePhysics.activeBV:Destroy() 
        end) 
        moduleState.divePhysics.activeBV = nil 
    end
    
    if moduleState.divePhysics.activeGyro then 
        pcall(function() 
            moduleState.divePhysics.activeGyro:Destroy() 
        end) 
        moduleState.divePhysics.activeGyro = nil 
    end
    
    -- Calculate dive direction relative to goal
    local relToGoal = diveTarget - GoalCFrame.Position
    local lateralDist = relToGoal:Dot(GoalRight)
    local dir = lateralDist > 0 and "Right" or "Left"
    moduleState.divePhysics.diveDirection = dir

    -- Fire server event
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir .. "Dive", root.CFrame)
    end)

    -- Calculate dive vector
    local toTarget = diveTarget - root.Position
    local horizontalDir = Vector3.new(toTarget.X, 0, toTarget.Z)
    
    if horizontalDir.Magnitude > 0.1 then
        horizontalDir = horizontalDir.Unit
    else
        -- Default dive forward if target is straight ahead
        horizontalDir = -GoalForward
    end
    
    -- Apply dive physics
    local diveSpeed = math.min(CONFIG.DIVE_SPEED, 35)  -- Limit speed for control
    
    moduleState.divePhysics.activeBV = Instance.new("BodyVelocity")
    moduleState.divePhysics.activeBV.Parent = root
    moduleState.divePhysics.activeBV.MaxForce = Vector3.new(1000000, 0, 1000000)
    moduleState.divePhysics.activeBV.Velocity = horizontalDir * diveSpeed
    
    -- Short duration for controlled dive
    game.Debris:AddItem(moduleState.divePhysics.activeBV, 0.3)
    
    -- Smooth deceleration
    if ts then
        ts:Create(moduleState.divePhysics.activeBV, 
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
            {Velocity = Vector3.new()}
        ):Play()
    end

    -- Disable auto-rotate during dive
    hum.AutoRotate = false

    -- Choose dive animation based on ball height
    local lowDive = (diveTarget.Y <= 3.5)
    pcall(function()
        local animName = dir .. (lowDive and "LowDive" or "Dive")
        local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK[animName])
        anim.Priority = Enum.AnimationPriority.Action4
        anim:Play()
    end)

    -- Disable jumping during dive
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    
    -- Automatic recovery
    task.delay(0.8, function()
        if hum and hum.Parent then
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum.AutoRotate = true
        end
        
        -- Cleanup physics
        if moduleState.divePhysics.activeBV then 
            pcall(function() 
                moduleState.divePhysics.activeBV.Velocity = Vector3.new()
                moduleState.divePhysics.activeBV:Destroy() 
            end) 
            moduleState.divePhysics.activeBV = nil 
        end
        
        moduleState.isDiving = false
    end)
    
    -- Safety reset
    task.delay(1.2, function()
        moduleState.isDiving = false
    end)
end

-- Enhanced corner positioning
local function handleCornerPositioning(root, ballPos, ballVel)
    if not ballPos or not GoalCFrame then 
        return nil 
    end
    
    local rightVec = GoalCFrame.RightVector
    local ballLateral = (ballPos - GoalCFrame.Position):Dot(rightVec)
    
    local sideChoice = ballLateral > 0 and 1 or -1
    moduleState.positioning.lastSideChoice = sideChoice
    
    -- Calculate optimal corner position
    local lateralOffset = sideChoice * GoalWidth * 0.4 * CONFIG.CORNER_BIAS
    local forwardOffset = CONFIG.STAND_DIST * 1.5
    
    -- Adjust for ball velocity
    if ballVel then
        local velLateral = ballVel:Dot(rightVec)
        if math.abs(velLateral) > 5 then
            lateralOffset = lateralOffset + velLateral * 0.1
        end
    end
    
    local basePos = GoalCFrame.Position + GoalForward * forwardOffset
    local targetPos = Vector3.new(
        basePos.X + rightVec.X * lateralOffset,
        root.Position.Y,
        basePos.Z + rightVec.Z * lateralOffset
    )
    
    -- Ensure we don't go too far from goal
    local toGoal = targetPos - GoalCFrame.Position
    local forwardDist = toGoal:Dot(GoalForward)
    
    if forwardDist > CONFIG.ZONE_DIST * 0.6 then
        targetPos = GoalCFrame.Position + GoalForward * (CONFIG.ZONE_DIST * 0.6)
    end
    
    moveToTarget(root, targetPos)
    
    -- Look at ball during corner
    rotateSmooth(root, ballPos, false, false, ballVel or Vector3.new())
    
    return targetPos
end

-- Touch ball function
local function touchBall(character, ball)
    if tick() - moduleState.lastTouchTime < 0.3 then
        return
    end
    
    for _, handName in pairs({"RightHand", "LeftHand", "RightFoot", "LeftFoot"}) do
        local hand = character:FindFirstChild(handName)
        if hand and (hand.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
            firetouchinterest(hand, ball, 0)
            task.wait(0.02)
            firetouchinterest(hand, ball, 1)
            moduleState.lastTouchTime = tick()
            break
        end
    end
end

-- Cleanup function
local function cleanup()
    if moduleState.currentBV then 
        pcall(function() 
            moduleState.currentBV:Destroy() 
        end) 
        moduleState.currentBV = nil 
    end
    
    if moduleState.currentGyro then 
        pcall(function() 
            moduleState.currentGyro:Destroy() 
        end) 
        moduleState.currentGyro = nil 
    end
    
    if moduleState.divePhysics.activeBV then 
        pcall(function() 
            moduleState.divePhysics.activeBV:Destroy() 
        end) 
        moduleState.divePhysics.activeBV = nil 
    end
    
    if moduleState.divePhysics.activeGyro then 
        pcall(function() 
            moduleState.divePhysics.activeGyro:Destroy() 
        end) 
        moduleState.divePhysics.activeGyro = nil 
    end
    
    clearAllVisuals()
    moduleState.isDiving = false
    moduleState.isJumping = false
    moduleState.cachedPoints = nil
    moduleState.cachedPointsTime = 0
    moduleState.smoothCFrame = nil
    moduleState.attackTargetHistory = {}
    moduleState.predictedEnemyPositions = {}
    moduleState.currentAttackTarget = nil
    moduleState.attackTargetVisible = false
    moduleState.threatAnalysis = {
        lastThreatPos = nil,
        threatDirection = nil,
        threatSpeed = 0,
        threatLevel = 0,
        isCloseRange = false,
        isCornerKick = false,
        isDirectShot = false,
        predictedImpactPoint = nil,
        timeToImpact = 999
    }
    moduleState.positioning = {
        optimalPosition = nil,
        lastSideChoice = 0,
        sideBiasTimer = 0,
        gateCoveragePoints = {},
        vulnerabilityMap = {}
    }
    moduleState.jumpPhysics = {
        isJumping = false,
        jumpStartTime = 0,
        jumpTarget = nil
    }
    moduleState.predictionCache = {}
end

-- Main heartbeat cycle
local function startHeartbeat()
    if moduleState.heartbeatConnection then
        moduleState.heartbeatConnection:Disconnect()
    end
    
    moduleState.heartbeatConnection = rs.Heartbeat:Connect(function(deltaTime)
        if not moduleState.enabled then 
            hideAllVisuals()
            return 
        end
        
        moduleState.frameCounter = moduleState.frameCounter + 1
        
        -- Performance optimization
        local currentTime = tick()
        if currentTime - moduleState.lastUpdateTime < CONFIG.UPDATE_RATE then
            return
        end
        moduleState.lastUpdateTime = currentTime
        
        -- Update visuals at lower rate
        local updateVisuals = currentTime - moduleState.lastVisualUpdate >= CONFIG.VISUAL_UPDATE_RATE
        if updateVisuals then
            moduleState.lastVisualUpdate = currentTime
        end
        
        if not checkIfGoalkeeper() then
            hideAllVisuals()
            if moduleState.currentBV then 
                pcall(function() 
                    moduleState.currentBV:Destroy() 
                end) 
                moduleState.currentBV = nil 
            end
            if moduleState.currentGyro then 
                pcall(function() 
                    moduleState.currentGyro:Destroy() 
                end) 
                moduleState.currentGyro = nil 
            end
            if moduleState.divePhysics.activeBV then 
                pcall(function() 
                    moduleState.divePhysics.activeBV:Destroy() 
                end) 
                moduleState.divePhysics.activeBV = nil 
            end
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

        -- Update visuals
        if updateVisuals then
            if CONFIG.SHOW_GOAL_CUBE and moduleState.visualObjects.GoalCube then
                drawCube(moduleState.visualObjects.GoalCube, GoalCFrame, Vector3.new(GoalWidth, 8, 2), CONFIG.GOAL_CUBE_COLOR)
            end
            
            if CONFIG.SHOW_ZONE then 
                drawFlatZone() 
            end
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

        -- Attack target selection
        if CONFIG.PRIORITY == "attack" or CONFIG.AUTO_ATTACK_IN_ZONE or CONFIG.AGGRESSIVE_MODE then
            attackTargetPlayer = findAttackTarget(root.Position, ball)
            
            if attackTargetPlayer then
                local targetRoot = attackTargetPlayer.Character and attackTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
                local shouldAttack = false
                
                if CONFIG.AGGRESSIVE_MODE then
                    shouldAttack = true
                elseif CONFIG.AUTO_ATTACK_IN_ZONE and targetRoot then
                    shouldAttack = isInDefenseZone(targetRoot.Position)
                elseif CONFIG.PRIORITY == "attack" then
                    shouldAttack = true
                end
                
                if shouldAttack then
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

        -- Enemy tracking
        if owner and owner ~= player and owner.Character then
            oRoot = owner.Character:FindFirstChild("HumanoidRootPart")
            if oRoot then
                local rel = oRoot.Position - GoalCFrame.Position
                enemyDistFromLine = rel:Dot(GoalForward)
                enemyLateral = rel:Dot(GoalRight)
                distToEnemy = (root.Position - oRoot.Position).Magnitude
                isAggro = enemyDistFromLine < CONFIG.AGGRO_THRES and distToEnemy < CONFIG.MAX_CHASE_DIST and hasWeld
                
                if isAggro and not smartBlockActive then
                    smartBlockActive = true
                    local predictedEnemyPos = predictEnemyPosition(oRoot)
                    local viewBlockPos = (predictedEnemyPos + GoalCFrame.Position) / 2 + GoalForward * 1.5
                    viewBlockPos = Vector3.new(viewBlockPos.X, root.Position.Y, viewBlockPos.Z)
                    moveToTarget(root, viewBlockPos)
                    
                    if CONFIG.SHOW_ATTACK_TARGET and updateVisuals then
                        drawAttackTarget(predictedEnemyPos)
                    end
                elseif not isAggro and moduleState.currentAttackTarget == owner then
                    hideAttackTarget()
                end
            end
        end

        -- Aggressive pressure
        if CONFIG.AGGRESSIVE_MODE and owner and owner ~= player and oRoot and not smartBlockActive then
            local predictedPos = predictEnemyPosition(oRoot)
            local targetPos = predictedPos + GoalForward * CONFIG.PRESSURE_DISTANCE
            moveToTarget(root, targetPos)
            smartBlockActive = true
            
            if CONFIG.SHOW_ATTACK_TARGET and updateVisuals then
                drawAttackTarget(predictedPos)
            end
        elseif CONFIG.AGGRESSIVE_MODE and not owner and moduleState.currentAttackTarget then
            hideAttackTarget()
        end

        if not attackTargetPlayer and not isAggro and not CONFIG.AGGRESSIVE_MODE then
            if moduleState.currentAttackTarget then
                hideAttackTarget()
            end
        end

        -- Ball trajectory prediction
        local points, endpoint = nil, nil
        local threatLateral = 0
        local isShot = not hasWeld and owner ~= player
        local distEnd = math.huge
        local velMag = ball.Velocity.Magnitude
        local distBall = (root.Position - ball.Position).Magnitude
        local isThreat = false
        local timeToEndpoint = 999

        -- Detect new shots
        local freshShot = false
        if velMag > 18 and moduleState.lastBallVelMag <= 18 then
            freshShot = true
            moduleState.cachedPoints = nil
            clearTrajAndEndpoint()
        end
        moduleState.lastBallVelMag = velMag

        if isShot and (freshShot or not moduleState.cachedPoints or moduleState.frameCounter % 3 == 0) then
            moduleState.cachedPoints = predictTrajectory(ball)
        end
        points = moduleState.cachedPoints
        
        if points then
            endpoint = points[#points]
            distEnd = (root.Position - endpoint).Magnitude
            
            if GoalCFrame then
                threatLateral = (endpoint - GoalCFrame.Position):Dot(GoalRight)
                isThreat = (endpoint - GoalCFrame.Position):Dot(GoalForward) < 2.6 and math.abs(threatLateral) < GoalWidth / 2.0
                
                -- Update threat analysis
                moduleState.threatAnalysis.lastThreatPos = endpoint
                moduleState.threatAnalysis.threatDirection = (endpoint - ball.Position).Unit
                moduleState.threatAnalysis.threatSpeed = velMag
                moduleState.threatAnalysis.isCloseRange = distEnd < CONFIG.CLOSE_THREAT_DIST
                moduleState.threatAnalysis.predictedImpactPoint = endpoint
                
                local distBallEnd = (ball.Position - endpoint).Magnitude
                moduleState.threatAnalysis.timeToImpact = distBallEnd / math.max(1, velMag)
            end
        else
            clearTrajAndEndpoint()
        end

        -- Show trajectory visuals
        if CONFIG.SHOW_TRAJECTORY and points and moduleState.visualObjects.trajLines and updateVisuals then
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
        elseif updateVisuals then 
            clearTrajAndEndpoint() 
        end

        -- Ball box visualization
        if CONFIG.SHOW_BALL_BOX and distBall < 70 and moduleState.visualObjects.BallBox and updateVisuals then 
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
        elseif moduleState.visualObjects.BallBox and updateVisuals then 
            drawCube(moduleState.visualObjects.BallBox, nil) 
        end

        -- Positioning logic (only if not blocking)
        if not smartBlockActive then
            local rightVec = GoalRight
            local defenseBase = GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST
            local lateral = 0

            -- Check for corner kick
            local isCornerKick = false
            if ball.Position.Y > 8 and distBall > 30 and math.abs(threatLateral) > GoalWidth * 0.4 then
                isCornerKick = true
                local cornerPos = handleCornerPositioning(root, ball.Position, ball.Velocity)
                if cornerPos then
                    defenseBase = cornerPos
                    lateral = 0
                end
            end

            if not isCornerKick then
                if isMyBall then
                    lateral = 0
                elseif oRoot and isAggro then
                    local targetDist = math.max(1.8, enemyDistFromLine - 1.5)
                    defenseBase = GoalCFrame.Position + GoalForward * targetDist
                    lateral = enemyLateral * 1.05
                elseif not hasWeld then
                    lateral = threatLateral * 0.9
                    
                    -- Advance based on ball speed and distance
                    local advanceMultiplier = math.min(1.0, velMag / 35)
                    local advanceDist = math.min(6.0, distBall * 0.12 + advanceMultiplier * 2.5)
                    defenseBase = GoalCFrame.Position + GoalForward * advanceDist
                else
                    local targetDist = math.max(CONFIG.STAND_DIST, math.min(8.0, enemyDistFromLine * 0.5))
                    defenseBase = GoalCFrame.Position + GoalForward * targetDist
                    local centerBias = math.max(0, 1 - (enemyDistFromLine / CONFIG.CENTER_BIAS_DIST))
                    lateral = enemyLateral * centerBias
                end

                -- Threat weighting
                local threatWeight = 0.4
                if isThreat then
                    threatWeight = 0.95
                elseif distEnd < CONFIG.CLOSE_THREAT_DIST then
                    threatWeight = 0.75
                elseif distEnd < 15 then
                    threatWeight = 0.6
                end
                
                lateral = threatLateral * threatWeight + lateral * (1 - threatWeight)

                -- Get optimal position
                local bestPos = getSmartPosition(defenseBase, rightVec, lateral, GoalWidth, threatLateral, enemyLateral, isAggro, ball.Position, ball.Velocity)
                
                -- Intercept logic for shots
                if isShot and points and isThreat then
                    local interceptPoint = findBestInterceptPoint(root.Position, ball.Position, ball.Velocity, points)
                    if interceptPoint then
                        local adjustedPos = interceptPoint + GoalForward * CONFIG.ADVANCE_DISTANCE
                        adjustedPos = Vector3.new(adjustedPos.X, root.Position.Y, adjustedPos.Z)
                        
                        -- Only use intercept if it's better than current position
                        local toIntercept = (interceptPoint - root.Position).Magnitude
                        local toBest = (bestPos - root.Position).Magnitude
                        
                        if toIntercept < toBest * 1.5 then
                            bestPos = adjustedPos
                        end
                    elseif distEnd > 8 and moduleState.threatAnalysis.timeToImpact > 1.0 then
                        -- Advance if we have time
                        local advancePos = defenseBase + GoalForward * CONFIG.ADVANCE_DISTANCE * 2.0
                        bestPos = Vector3.new(advancePos.X, root.Position.Y, advancePos.Z)
                    end
                end
                
                moveToTarget(root, bestPos)
            end
        end

        -- Rotation
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

        -- INTELLIGENT ACTIONS BASED ON ANALYSIS
        if not isMyBall and not moduleState.isDiving and not moduleState.isJumping then
            
            -- Analyze shot situation
            local shotAnalysis = analyzeShotSituation(ball.Position, ball.Velocity, endpoint, root.Position, points)
            
            -- Execute actions based on analysis
            if shotAnalysis.action == "touch" and distBall < CONFIG.TOUCH_RANGE then
                touchBall(char, ball)
            end
            
            if shotAnalysis.action == "jump" and tick() - moduleState.lastJumpTime > CONFIG.JUMP_COOLDOWN then
                if CONFIG.JUMP_WHEN_HIGH_BALL then
                    forceJump(hum, shotAnalysis.targetPosition)
                end
            end
            
            if shotAnalysis.action == "dive" and tick() - moduleState.lastDiveTime > CONFIG.DIVE_COOLDOWN then
                performDive(root, hum, shotAnalysis.targetPosition or endpoint or ball.Position)
            end
            
            if shotAnalysis.action == "block" then
                -- Position ourselves to block the shot
                if shotAnalysis.targetPosition then
                    moveToTarget(root, shotAnalysis.targetPosition)
                end
            end
        else
            if isMyBall then 
                moduleState.isDiving = false 
                moduleState.isJumping = false
            end
        end

        -- Clear visuals if no shot
        if not isShot or not points then
            if updateVisuals then
                clearTrajAndEndpoint()
            end
        end
    end)
end

-- Sync configuration with UI
local function syncConfig()
    -- Sync all config values from UI
    for key, element in pairs(moduleState.uiElements) do
        if element and element.GetState then
            CONFIG[key] = element:GetState()
        elseif element and element.GetValue then
            CONFIG[key] = element:GetValue()
        end
    end
    
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
    moduleState.notify = notifyFunc
    
    if UI.Sections.AutoGoalKeeper then
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalKeeper V2.0 - Enhanced AI" })
        
        -- Basic settings
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
                    notifyFunc("AutoGK", "Enhanced AI Enabled", true)
                else
                    if moduleState.heartbeatConnection then
                        moduleState.heartbeatConnection:Disconnect()
                        moduleState.heartbeatConnection = nil
                    end
                    cleanup()
                    notifyFunc("AutoGK", "Disabled", true)
                end
            end
        }, 'AutoGKEnabled')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Movement settings
        UI.Sections.AutoGoalKeeper:Header({ Name = "Movement Settings" })
        
        moduleState.uiElements.SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Movement Speed",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.SPEED = v end
        }, 'AutoGKMovementSpeed')
        
        moduleState.uiElements.STAND_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Stand Distance",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = CONFIG.STAND_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.STAND_DIST = v end
        }, 'StandDistanceGK')
        
        moduleState.uiElements.MIN_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Minimum Distance",
            Minimum = 0.5,
            Maximum = 2.0,
            Default = CONFIG.MIN_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.MIN_DIST = v end
        }, 'MinDistanceGK')
        
        -- Dive & Jump settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Dive & Jump Settings" })
        
        moduleState.uiElements.DIVE_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Distance",
            Minimum = 5,
            Maximum = 25,
            Default = CONFIG.DIVE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_DIST = v end
        }, 'DiveDistanceGK')
        
        moduleState.uiElements.ENDPOINT_DIVE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Endpoint Dive Distance",
            Minimum = 2,
            Maximum = 16,
            Default = CONFIG.ENDPOINT_DIVE,
            Precision = 1,
            Callback = function(v) CONFIG.ENDPOINT_DIVE = v end
        }, 'EndpointDiveDistanceGK')
        
        moduleState.uiElements.DIVE_SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Speed",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.DIVE_SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_SPEED = v end
        }, 'DiveSpeedGK')
        
        moduleState.uiElements.DIVE_VEL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Velocity Threshold",
            Minimum = 10,
            Maximum = 40,
            Default = CONFIG.DIVE_VEL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_VEL_THRES = v end
        }, 'DiveVelocityGK')
        
        moduleState.uiElements.DIVE_COOLDOWN = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Cooldown",
            Minimum = 0.5,
            Maximum = 3.0,
            Default = CONFIG.DIVE_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_COOLDOWN = v end
        }, 'DiveCDGK')
        
        moduleState.uiElements.JUMP_VEL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Velocity Threshold",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.JUMP_VEL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_VEL_THRES = v end
        }, 'JumpVelocityGK')
        
        moduleState.uiElements.HIGH_BALL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "High Ball Threshold",
            Minimum = 4.0,
            Maximum = 16.0,
            Default = CONFIG.HIGH_BALL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.HIGH_BALL_THRES = v end
        }, 'HighBallGk')
        
        moduleState.uiElements.JUMP_COOLDOWN = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Cooldown",
            Minimum = 0.5,
            Maximum = 2.0,
            Default = CONFIG.JUMP_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_COOLDOWN = v end
        }, 'JMPCDGK')
        
        moduleState.uiElements.JUMP_POWER = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Power",
            Minimum = 25,
            Maximum = 50,
            Default = CONFIG.JUMP_POWER,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_POWER = v end
        }, 'JumpPowerGK')
        
        moduleState.uiElements.JUMP_HEIGHT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Height",
            Minimum = 4,
            Maximum = 12,
            Default = CONFIG.JUMP_HEIGHT,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_HEIGHT = v end
        }, 'JumpHeightGK')
        
        moduleState.uiElements.JUMP_WHEN_HIGH_BALL = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Jump for High Balls",
            Default = CONFIG.JUMP_WHEN_HIGH_BALL,
            Callback = function(v) CONFIG.JUMP_WHEN_HIGH_BALL = v end
        }, 'JumpHighBallGK')
        
        -- Defense Zone settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Defense Zone Settings" })
        
        moduleState.uiElements.ZONE_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Distance",
            Minimum = 30,
            Maximum = 200,
            Default = CONFIG.ZONE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_DIST = v end
        }, 'ZONEDISTGK')
        
        moduleState.uiElements.ZONE_WIDTH = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Width Multiplier",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = CONFIG.ZONE_WIDTH,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_WIDTH = v end
        }, 'ZONEWIDTHGK')
        
        moduleState.uiElements.AGGRO_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Aggro Threshold",
            Minimum = 20,
            Maximum = 80,
            Default = CONFIG.AGGRO_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.AGGRO_THRES = v end
        }, 'AGGROTHRESGK')
        
        moduleState.uiElements.MAX_CHASE_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Max Chase Distance",
            Minimum = 20,
            Maximum = 80,
            Default = CONFIG.MAX_CHASE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.MAX_CHASE_DIST = v end
        }, 'MAXCHASEDISTGK')
        
        -- Gate Protection settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Gate Protection Settings" })
        
        moduleState.uiElements.GATE_COVERAGE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Goal Coverage",
            Minimum = 0.5,
            Maximum = 1.0,
            Default = CONFIG.GATE_COVERAGE,
            Precision = 2,
            Callback = function(v) CONFIG.GATE_COVERAGE = v end
        }, 'GOALCOVERAGEGK')
        
        moduleState.uiElements.LATERAL_MAX_MULT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Lateral Movement Multiplier",
            Minimum = 0.2,
            Maximum = 0.8,
            Default = CONFIG.LATERAL_MAX_MULT,
            Precision = 2,
            Callback = function(v) CONFIG.LATERAL_MAX_MULT = v end
        }, 'LATERALMOVEMENTMULTIGK')
        
        moduleState.uiElements.GATE_EDGE_MARGIN = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Gate Edge Margin",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = CONFIG.GATE_EDGE_MARGIN,
            Precision = 1,
            Callback = function(v) CONFIG.GATE_EDGE_MARGIN = v end
        }, 'GateEdgeMarginGK')
        
        moduleState.uiElements.GATE_HEIGHT_PROTECTION = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Gate Height Protection",
            Minimum = 6.0,
            Maximum = 15.0,
            Default = CONFIG.GATE_HEIGHT_PROTECTION,
            Precision = 1,
            Callback = function(v) CONFIG.GATE_HEIGHT_PROTECTION = v end
        }, 'GateHeightProtectionGK')
        
        -- Attack & Pressure settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Attack & Pressure Settings" })
        
        moduleState.uiElements.PRIORITY = UI.Sections.AutoGoalKeeper:Dropdown({
            Name = "Priority",
            Default = CONFIG.PRIORITY,
            Options = {"defense", "attack"},
            Callback = function(v) CONFIG.PRIORITY = v end
        }, 'PRIOTIRYGK')
        
        moduleState.uiElements.AGGRESSIVE_MODE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Aggressive Mode",
            Default = CONFIG.AGGRESSIVE_MODE,
            Callback = function(v) CONFIG.AGGRESSIVE_MODE = v end
        }, 'AggressiveModeGK')
        
        moduleState.uiElements.AUTO_ATTACK_IN_ZONE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Auto Attack in Zone",
            Default = CONFIG.AUTO_ATTACK_IN_ZONE,
            Callback = function(v) CONFIG.AUTO_ATTACK_IN_ZONE = v end
        }, 'AUTOTAATACKINZONEGK')
        
        moduleState.uiElements.ATTACK_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Distance",
            Minimum = 20,
            Maximum = 80,
            Default = CONFIG.ATTACK_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_DISTANCE = v end
        }, 'ATTACKDISTGK')
        
        moduleState.uiElements.PRESSURE_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Pressure Distance",
            Minimum = 10,
            Maximum = 30,
            Default = CONFIG.PRESSURE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.PRESSURE_DISTANCE = v end
        }, 'PressureDistanceGK')
        
        moduleState.uiElements.ATTACK_PREDICT_TIME = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Predict Time",
            Minimum = 0.05,
            Maximum = 0.3,
            Default = CONFIG.ATTACK_PREDICT_TIME,
            Precision = 2,
            Tooltip = "Time to predict enemy position (compensates for server lag)",
            Callback = function(v) CONFIG.ATTACK_PREDICT_TIME = v end
        }, 'ATTACKPREDICTGK')
        
        moduleState.uiElements.ATTACK_COOLDOWN = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Cooldown",
            Minimum = 0.5,
            Maximum = 3.0,
            Default = CONFIG.ATTACK_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_COOLDOWN = v end
        }, 'ATTACKCDGK')
        
        moduleState.uiElements.BLOCK_ANGLE_THRESHOLD = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Block Angle Threshold",
            Minimum = 30,
            Maximum = 60,
            Default = CONFIG.BLOCK_ANGLE_THRESHOLD,
            Precision = 1,
            Callback = function(v) CONFIG.BLOCK_ANGLE_THRESHOLD = v end
        }, 'BlockAngleGK')
        
        -- Rotation settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Rotation Settings" })
        
        moduleState.uiElements.USE_SMOOTH_ROTATION = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Use Smooth Rotation",
            Default = CONFIG.USE_SMOOTH_ROTATION,
            Callback = function(v) CONFIG.USE_SMOOTH_ROTATION = v end
        }, 'UseSmoothRotationGK')
        
        moduleState.uiElements.ROT_SMOOTH = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Rotation Smoothness",
            Minimum = 0.5,
            Maximum = 0.95,
            Default = CONFIG.ROT_SMOOTH,
            Precision = 2,
            Callback = function(v) CONFIG.ROT_SMOOTH = v end
        }, 'ROTSMOOTHGK')
        
        moduleState.uiElements.LOOK_AT_BALL_WHEN_CLOSE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Look at Ball When Close",
            Default = CONFIG.LOOK_AT_BALL_WHEN_CLOSE,
            Callback = function(v) CONFIG.LOOK_AT_BALL_WHEN_CLOSE = v end
        }, 'LookAtBallCloseGK')
        
        moduleState.uiElements.MIN_LOOK_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Min Look Distance",
            Minimum = 5,
            Maximum = 30,
            Default = CONFIG.MIN_LOOK_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.MIN_LOOK_DISTANCE = v end
        }, 'MinLookDistanceGK')
        
        -- Intelligent Positioning settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Intelligent Positioning" })
        
        moduleState.uiElements.REACTION_TIME = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Reaction Time",
            Minimum = 0.05,
            Maximum = 0.3,
            Default = CONFIG.REACTION_TIME,
            Precision = 2,
            Callback = function(v) CONFIG.REACTION_TIME = v end
        }, 'REACTIONTIMEGK')
        
        moduleState.uiElements.ANTICIPATION_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Anticipation Distance",
            Minimum = 0.5,
            Maximum = 3.0,
            Default = CONFIG.ANTICIPATION_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.ANTICIPATION_DIST = v end
        }, 'ANTICIPATIONDISTGK')
        
        moduleState.uiElements.CORNER_BIAS = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Corner Bias",
            Minimum = 0.3,
            Maximum = 1.0,
            Default = CONFIG.CORNER_BIAS,
            Precision = 2,
            Callback = function(v) CONFIG.CORNER_BIAS = v end
        }, 'CORNERBIASGK')
        
        moduleState.uiElements.SIDE_POSITIONING = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Side Positioning",
            Minimum = 0.3,
            Maximum = 1.0,
            Default = CONFIG.SIDE_POSITIONING,
            Precision = 2,
            Callback = function(v) CONFIG.SIDE_POSITIONING = v end
        }, 'SIDEPOSITIONINGGK')
        
        moduleState.uiElements.CENTER_BIAS_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Center Bias Distance",
            Minimum = 10,
            Maximum = 30,
            Default = CONFIG.CENTER_BIAS_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.CENTER_BIAS_DIST = v end
        }, 'CenterBiasDistGK')
        
        moduleState.uiElements.GATE_CENTER_PRIORITY = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Gate Center Priority",
            Minimum = 0.5,
            Maximum = 1.0,
            Default = CONFIG.GATE_CENTER_PRIORITY,
            Precision = 2,
            Callback = function(v) CONFIG.GATE_CENTER_PRIORITY = v end
        }, 'GateCenterPriorityGK')
        
        -- Prediction settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Prediction Settings" })
        
        moduleState.uiElements.PRED_STEPS = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Prediction Steps",
            Minimum = 60,
            Maximum = 200,
            Default = CONFIG.PRED_STEPS,
            Precision = 0,
            Callback = function(v) CONFIG.PRED_STEPS = v end
        }, 'PREDSTEPSGK')
        
        moduleState.uiElements.GRAVITY = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Gravity",
            Minimum = 80,
            Maximum = 198.2,
            Default = CONFIG.GRAVITY,
            Precision = 1,
            Callback = function(v) CONFIG.GRAVITY = v end
        }, 'GRAVITYGK')
        
        moduleState.uiElements.DRAG = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Air Drag",
            Minimum = 0.95,
            Maximum = 0.995,
            Default = CONFIG.DRAG,
            Precision = 3,
            Callback = function(v) CONFIG.DRAG = v end
        }, 'AIRDRAGGK')
        
        moduleState.uiElements.CURVE_MULT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Curve Multiplier",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.CURVE_MULT,
            Precision = 1,
            Callback = function(v) CONFIG.CURVE_MULT = v end
        }, 'CURVEMULTIGK')
        
        moduleState.uiElements.BOUNCE_XZ = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Horizontal Bounce",
            Minimum = 0.5,
            Maximum = 0.9,
            Default = CONFIG.BOUNCE_XZ,
            Precision = 2,
            Callback = function(v) CONFIG.BOUNCE_XZ = v end
        }, 'HORIZONTALBOUNCEGK')
        
        moduleState.uiElements.BOUNCE_Y = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Vertical Bounce",
            Minimum = 0.5,
            Maximum = 0.9,
            Default = CONFIG.BOUNCE_Y,
            Precision = 2,
            Callback = function(v) CONFIG.BOUNCE_Y = v end
        }, 'VERTICALBOUNCEGK')
        
        -- Advanced Defense settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Advanced Defense Settings" })
        
        moduleState.uiElements.BALL_INTERCEPT_RANGE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Ball Intercept Range",
            Minimum = 2.0,
            Maximum = 12.0,
            Default = CONFIG.BALL_INTERCEPT_RANGE,
            Precision = 1,
            Callback = function(v) CONFIG.BALL_INTERCEPT_RANGE = v end
        }, 'BALLINTERCEPTRANGEGK')
        
        moduleState.uiElements.MIN_INTERCEPT_TIME = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Min Intercept Time",
            Minimum = 0.05,
            Maximum = 0.5,
            Default = CONFIG.MIN_INTERCEPT_TIME,
            Precision = 2,
            Callback = function(v) CONFIG.MIN_INTERCEPT_TIME = v end
        }, 'MININTERCEPTTIMEGK')
        
        moduleState.uiElements.ADVANCE_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Advance Distance",
            Minimum = 1.0,
            Maximum = 8.0,
            Default = CONFIG.ADVANCE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ADVANCE_DISTANCE = v end
        }, 'ADVANCEDISTGK')
        
        moduleState.uiElements.DIVE_LOOK_AHEAD = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Look Ahead",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = CONFIG.DIVE_LOOK_AHEAD,
            Precision = 2,
            Callback = function(v) CONFIG.DIVE_LOOK_AHEAD = v end
        }, 'DIVELOOKAHEADGK')
        
        moduleState.uiElements.TOUCH_RANGE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Touch Range",
            Minimum = 5.0,
            Maximum = 20.0,
            Default = CONFIG.TOUCH_RANGE,
            Precision = 1,
            Callback = function(v) CONFIG.TOUCH_RANGE = v end
        }, 'TouchRangeGK')
        
        moduleState.uiElements.NEAR_BALL_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Near Ball Distance",
            Minimum = 3.0,
            Maximum = 16.0,
            Default = CONFIG.NEAR_BALL_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.NEAR_BALL_DIST = v end
        }, 'NearBallDistanceGK')
        
        moduleState.uiElements.CLOSE_THREAT_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Close Threat Distance",
            Minimum = 2.0,
            Maximum = 8.0,
            Default = CONFIG.CLOSE_THREAT_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.CLOSE_THREAT_DIST = v end
        }, 'CloseThreatDistGK')
        
        moduleState.uiElements.JUMP_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Threshold",
            Minimum = 3.0,
            Maximum = 10.0,
            Default = CONFIG.JUMP_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_THRES = v end
        }, 'JumpThreshGK')
        
        -- Enhanced AI settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Enhanced AI Settings" })
        
        moduleState.uiElements.PREDICT_ENEMY_MOVEMENT = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Predict Enemy Movement",
            Default = CONFIG.PREDICT_ENEMY_MOVEMENT,
            Callback = function(v) CONFIG.PREDICT_ENEMY_MOVEMENT = v end
        }, 'PredictEnemyMovementGK')
        
        moduleState.uiElements.USE_ADAPTIVE_TACTICS = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Use Adaptive Tactics",
            Default = CONFIG.USE_ADAPTIVE_TACTICS,
            Callback = function(v) CONFIG.USE_ADAPTIVE_TACTICS = v end
        }, 'AdaptiveTacticsGK')
        
        moduleState.uiElements.CACHE_PREDICTIONS = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Cache Predictions",
            Default = CONFIG.CACHE_PREDICTIONS,
            Callback = function(v) CONFIG.CACHE_PREDICTIONS = v end
        }, 'CachePredictionsGK')
        
        moduleState.uiElements.MAX_CACHE_TIME = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Max Cache Time",
            Minimum = 0.1,
            Maximum = 1.0,
            Default = CONFIG.MAX_CACHE_TIME,
            Precision = 2,
            Callback = function(v) CONFIG.MAX_CACHE_TIME = v end
        }, 'MaxCacheTimeGK')
        
        -- Performance settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Performance Settings" })
        
        moduleState.uiElements.UPDATE_RATE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Update Rate (s)",
            Minimum = 0.01,
            Maximum = 0.1,
            Default = CONFIG.UPDATE_RATE,
            Precision = 3,
            Callback = function(v) CONFIG.UPDATE_RATE = v end
        }, 'UpdateRateGK')
        
        moduleState.uiElements.VISUAL_UPDATE_RATE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Visual Update Rate (s)",
            Minimum = 0.05,
            Maximum = 0.5,
            Default = CONFIG.VISUAL_UPDATE_RATE,
            Precision = 2,
            Callback = function(v) CONFIG.VISUAL_UPDATE_RATE = v end
        }, 'VisualUpdateRateGK')
        
        -- Visual settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Visual Settings" })
        
        moduleState.uiElements.SHOW_TRAJECTORY = UI.Sections.AutoGoalKeeper:Toggle({
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
        
        moduleState.uiElements.SHOW_ENDPOINT = UI.Sections.AutoGoalKeeper:Toggle({
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
        
        moduleState.uiElements.SHOW_GOAL_CUBE = UI.Sections.AutoGoalKeeper:Toggle({
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
        
        moduleState.uiElements.SHOW_ZONE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Zone",
            Default = CONFIG.SHOW_ZONE,
            Callback = function(v) 
                CONFIG.SHOW_ZONE = v 
                if moduleState.enabled then
                    createVisuals()
                    updateVisualColors()
                end
            end
        }, 'ShowZoneGK')
        
        moduleState.uiElements.SHOW_BALL_BOX = UI.Sections.AutoGoalKeeper:Toggle({
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
        
        moduleState.uiElements.SHOW_ATTACK_TARGET = UI.Sections.AutoGoalKeeper:Toggle({
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
        
        -- Color settings
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Color Settings" })
        
        moduleState.colorPickers.TRAJECTORY_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Trajectory Color",
            Default = CONFIG.TRAJECTORY_COLOR,
            Callback = function(v) 
                CONFIG.TRAJECTORY_COLOR = v
                updateVisualColors()
            end
        }, 'TRAJECTORYCOLORGK')
        
        moduleState.colorPickers.ENDPOINT_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Endpoint Color",
            Default = CONFIG.ENDPOINT_COLOR,
            Callback = function(v) 
                CONFIG.ENDPOINT_COLOR = v
                updateVisualColors()
            end
        }, 'ENDPOINTCOLORGK')
        
        moduleState.colorPickers.GOAL_CUBE_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Goal Cube Color",
            Default = CONFIG.GOAL_CUBE_COLOR,
            Callback = function(v) 
                CONFIG.GOAL_CUBE_COLOR = v
                updateVisualColors()
            end
        }, 'GOALCUBECOLORGK')
        
        moduleState.colorPickers.ZONE_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Zone Color",
            Default = CONFIG.ZONE_COLOR,
            Callback = function(v) 
                CONFIG.ZONE_COLOR = v
                updateVisualColors()
            end
        }, 'ZONECOLORGK')
        
        moduleState.colorPickers.ATTACK_TARGET_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Attack Target Color",
            Default = CONFIG.ATTACK_TARGET_COLOR,
            Callback = function(v) 
                CONFIG.ATTACK_TARGET_COLOR = v
                updateVisualColors()
            end
        }, 'ATTACKTARGETCOLORGK')
        
        -- Information section
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Information" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "AutoGK V2.0 - Enhanced AI Goalkeeper",
            Body = [[
ENHANCEMENTS:
1. Improved Gate Protection: Better positioning relative to goal edges
2. Enhanced Jump System: Proper jumping for high balls with prediction
3. Intelligent Rotation: Looks where needed (ball, enemy, or goal)
4. Advanced Threat Analysis: Calculates threat levels and optimal responses
5. Predictive Enemy Tracking: Anticipates enemy movements for blocking
6. Corner Kick Handling: Special positioning for corner situations
7. Performance Optimization: Configurable update rates for smooth operation

KEY FEATURES:
- Smart positioning based on ball trajectory and enemy positions
- Intelligent dive/jump decisions with confidence levels
- Aggressive mode for pressuring enemies
- Visual feedback for debugging and understanding AI decisions
- Configurable behavior for different play styles

TIPS:
1. Adjust "Goal Coverage" for wider or narrower protection
2. Use "Aggressive Mode" to pressure enemies with ball
3. Enable "Predict Enemy Movement" for better blocking
4. Adjust "Update Rate" if experiencing lag
5. Use visualizations to understand AI decision making
]]
        })
    end
    
    -- Config sync section
    if UI.Tabs.Config then
        moduleState.syncSection = UI.Tabs.Config:Section({Name = 'AutoGoalKeeper Sync', Side = 'Right'})
        
        moduleState.syncSection:Header({ Name = "AutoGoalKeeper Config Sync" })
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
