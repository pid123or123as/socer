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
    
    -- === JUMP SETTINGS ===
    JUMP_POWER = 32,
    JUMP_HEIGHT = 6,
    JUMP_PREDICTION_TIME = 0.3,
    
    -- === GATE PROTECTION ===
    GATE_EDGE_MARGIN = 2.0,
    GATE_HEIGHT_PROTECTION = 8.0,
    
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
    USE_SMART_POSITIONING = true,
    USE_INTERCEPT_LOGIC = true,
    
    -- === GATE DETECTION ===
    GATE_DETECTION_METHOD = "advanced", -- "simple" or "advanced"
    
    -- === BIG GATE SETTINGS ===
    BIG_GATE_THRESHOLD = 40, -- Ширина для больших ворот
    USE_DIVE_JUMPS = true, -- Прыжки с дайвом только на больших воротах
    DIVE_JUMP_LEFT_ENABLED = true,
    DIVE_JUMP_RIGHT_ENABLED = true,
    
    -- === DEBUG SETTINGS ===
    SHOW_GATE_INFO = true, -- Показывать информацию о воротах
    DEBUG_FONT_SIZE = 18,
    DEBUG_POSITION = Vector2.new(10, 100)
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
    
    -- Enhanced gate detection
    gateDetection = {
        leftPost = nil,
        rightPost = nil,
        gateWidth = 0,
        isBigGate = false,
        lastDetectionTime = 0,
        detectionMethod = "advanced",
        debugText = nil
    },
    
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
        timeToImpact = 999,
        ballHeight = 0
    },
    
    positioning = {
        optimalPosition = nil,
        lastSideChoice = 0,
        sideBiasTimer = 0,
        gateCoveragePoints = {},
        vulnerabilityMap = {},
        lastGoodPosition = nil,
        avoidCornerTimer = 0
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
        jumpTarget = nil,
        jumpType = "normal" -- "normal", "left", "right"
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
    lastVisualUpdate = 0
}

-- Global variables
local GoalCFrame, GoalForward, GoalWidth, GoalRight = nil, nil, 0, nil
local maxDistFromGoal = 50

-- Create debug text for gate info
local function createDebugText()
    if moduleState.gateDetection.debugText then
        moduleState.gateDetection.debugText:Remove()
    end
    
    moduleState.gateDetection.debugText = Drawing.new("Text")
    moduleState.gateDetection.debugText.Visible = false
    moduleState.gateDetection.debugText.Text = "Gate Info: Detecting..."
    moduleState.gateDetection.debugText.Color = Color3.new(1, 1, 1)
    moduleState.gateDetection.debugText.Size = CONFIG.DEBUG_FONT_SIZE
    moduleState.gateDetection.debugText.Outline = true
    moduleState.gateDetection.debugText.OutlineColor = Color3.new(0, 0, 0)
    moduleState.gateDetection.debugText.Position = CONFIG.DEBUG_POSITION
end

-- Enhanced gate detection function
local function detectGatePosts(goal)
    if not goal then return nil, nil end
    
    local leftPost, rightPost = nil, nil
    local posts = {}
    
    if CONFIG.GATE_DETECTION_METHOD == "advanced" then
        -- Advanced detection using part properties
        for _, part in ipairs(goal:GetDescendants()) do
            if part:IsA("BasePart") then
                local hasSound, hasCylinder, hasScript = false, false, false
                
                -- Check children for specific properties
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("Sound") then 
                        hasSound = true
                    elseif child:IsA("CylinderMesh") then 
                        hasCylinder = true
                    elseif child:IsA("Script") then 
                        hasScript = true 
                    end
                end
                
                -- This is likely a goal post if it has at least 2 of these features
                local score = (hasSound and 1 or 0) + (hasCylinder and 1 or 0) + (hasScript and 1 or 0)
                if score >= 2 then
                    table.insert(posts, {
                        part = part,
                        position = part.Position,
                        score = score
                    })
                end
            end
        end
        
        -- If we found posts, sort them by X position
        if #posts >= 2 then
            table.sort(posts, function(a, b)
                return a.position.X < b.position.X
            end)
            
            leftPost = posts[1].part
            rightPost = posts[#posts].part
        end
    else
        -- Simple detection by name
        leftPost = goal:FindFirstChild("LeftPost") or goal:FindFirstChild("leftpost") or goal:FindFirstChild("Left")
        rightPost = goal:FindFirstChild("RightPost") or goal:FindFirstChild("rightpost") or goal:FindFirstChild("Right")
        
        -- If not found by name, try to find in Frame
        if not (leftPost and rightPost) then
            local frame = goal:FindFirstChild("Frame")
            if frame then
                leftPost = frame:FindFirstChild("LeftPost") or frame:FindFirstChild("leftpost")
                rightPost = frame:FindFirstChild("RightPost") or frame:FindFirstChild("rightpost")
            end
        end
    end
    
    return leftPost, rightPost
end

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
    
    -- Create debug text
    if CONFIG.SHOW_GATE_INFO then
        createDebugText()
    end
    
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
end

-- Update debug text with gate info
local function updateDebugText()
    if not moduleState.gateDetection.debugText or not CONFIG.SHOW_GATE_INFO then return end
    
    local text = string.format("Gate Width: %.1f\nBig Gate: %s\nMethod: %s", 
        moduleState.gateDetection.gateWidth or 0,
        moduleState.gateDetection.isBigGate and "YES" or "NO",
        CONFIG.GATE_DETECTION_METHOD)
    
    moduleState.gateDetection.debugText.Text = text
    moduleState.gateDetection.debugText.Visible = moduleState.enabled
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
    
    if moduleState.gateDetection.debugText then
        pcall(function()
            moduleState.gateDetection.debugText:Remove()
        end)
        moduleState.gateDetection.debugText = nil
    end
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
    
    if moduleState.gateDetection.debugText then
        moduleState.gateDetection.debugText.Visible = false
    end
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

-- Enhanced goal update with improved gate detection
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
    
    if goal then
        -- Enhanced gate detection
        local leftPost, rightPost = detectGatePosts(goal)
        
        if leftPost and rightPost then
            local gcenter = (leftPost.Position + rightPost.Position) / 2
            local rightDir = (rightPost.Position - leftPost.Position).Unit
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
                    dist = rel:Dot(GoalForward)
                    minDist = math.min(minDist, dist)
                    maxDist = math.max(maxDist, dist)
                end
            end
            
            GoalCFrame = CFrame.fromMatrix(gcenter, rightDir, Vector3.new(0, 1, 0), -GoalForward)
            GoalWidth = (rightPost.Position - leftPost.Position).Magnitude
            maxDistFromGoal = math.max(34, maxDist - minDist + 15)
            
            -- Update gate detection info
            moduleState.gateDetection.leftPost = leftPost
            moduleState.gateDetection.rightPost = rightPost
            moduleState.gateDetection.gateWidth = GoalWidth
            moduleState.gateDetection.isBigGate = GoalWidth >= CONFIG.BIG_GATE_THRESHOLD
            moduleState.gateDetection.lastDetectionTime = tick()
            
            -- Update debug text
            updateDebugText()
            
            -- Calculate gate coverage points
            moduleState.positioning.gateCoveragePoints = {
                left = leftPost.Position,
                right = rightPost.Position,
                topLeft = leftPost.Position + Vector3.new(0, CONFIG.GATE_HEIGHT_PROTECTION, 0),
                topRight = rightPost.Position + Vector3.new(0, CONFIG.GATE_HEIGHT_PROTECTION, 0),
                center = gcenter,
                centerTop = gcenter + Vector3.new(0, CONFIG.GATE_HEIGHT_PROTECTION / 2, 0)
            }
            
            lastGoalUpdate = tick()
            goalCacheValid = true
            return true
        else
            -- Failed to detect posts
            moduleState.gateDetection.leftPost = nil
            moduleState.gateDetection.rightPost = nil
            moduleState.gateDetection.gateWidth = 0
            moduleState.gateDetection.isBigGate = false
            updateDebugText()
            return false
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

-- Enhanced trajectory prediction
local function predictTrajectory(ball)
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
    
    moduleState.cachedPoints = points
    moduleState.cachedPointsTime = tick()
    
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
    if isOwner or isDivingNow then 
        if moduleState.currentGyro then 
            pcall(function() 
                moduleState.currentGyro:Destroy() 
            end) 
            moduleState.currentGyro = nil
        end
        moduleState.currentTargetType = isOwner and "owner" or "dive"
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
    
    -- Всегда смотрим на мяч, когда он в полете
    local finalLookPos = targetPos
    moduleState.currentTargetType = "ball"
    
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

-- ENHANCED: Jump animations with dive jumps for big gates
local function playJumpAnimation(hum, jumpType)
    pcall(function()
        local anim
        if jumpType == "left" and CONFIG.DIVE_JUMP_LEFT_ENABLED and moduleState.gateDetection.isBigGate then
            anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK.JumpLeftNew)
            moduleState.jumpPhysics.jumpType = "left"
        elseif jumpType == "right" and CONFIG.DIVE_JUMP_RIGHT_ENABLED and moduleState.gateDetection.isBigGate then
            anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK.JumpRightNew)
            moduleState.jumpPhysics.jumpType = "right"
        else
            anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK.Jump)
            moduleState.jumpPhysics.jumpType = "normal"
        end
        
        if anim then
            anim.Priority = Enum.AnimationPriority.Action4
            anim:Play()
        end
    end)
end

local function forceJump(hum, targetPosition, jumpType)
    if moduleState.isJumping then 
        return 
    end
    
    moduleState.isJumping = true
    moduleState.jumpPhysics.isJumping = true
    moduleState.jumpPhysics.jumpStartTime = tick()
    moduleState.jumpPhysics.jumpTarget = targetPosition
    moduleState.lastJumpTime = tick()
    
    -- Сохраняем оригинальные значения
    local oldPower = hum.JumpPower
    local oldJumpHeight = hum.JumpHeight
    
    -- Устанавливаем параметры прыжка
    hum.JumpPower = CONFIG.JUMP_POWER
    hum.JumpHeight = CONFIG.JUMP_HEIGHT
    hum.Jump = true
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    
    -- Проигрываем анимацию прыжка
    playJumpAnimation(hum, jumpType or "normal")
    
    -- Применяем импульс в нужном направлении
    if targetPosition then
        local root = hum.Parent:FindFirstChild("HumanoidRootPart")
        if root then
            local dir = (targetPosition - root.Position) * Vector3.new(1, 0, 1)
            if dir.Magnitude > 0.1 then
                dir = dir.Unit
                local impulseMultiplier = 12
                
                -- Для прыжков с дайвом увеличиваем импульс
                if jumpType == "left" or jumpType == "right" then
                    impulseMultiplier = 18
                    
                    -- Добавляем боковой импульс для дайва
                    if jumpType == "left" then
                        dir = (dir + GoalRight * -0.7).Unit
                    elseif jumpType == "right" then
                        dir = (dir + GoalRight * 0.7).Unit
                    end
                end
                
                local bv = Instance.new("BodyVelocity")
                bv.Parent = root
                bv.MaxForce = Vector3.new(20000, 0, 20000)
                bv.Velocity = dir * impulseMultiplier
                game.Debris:AddItem(bv, 0.25)
            end
        end
    end
    
    -- Сбрасываем после прыжка
    task.delay(0.6, function()
        if hum and hum.Parent then
            hum.JumpPower = oldPower
            hum.JumpHeight = oldHeight
        end
        moduleState.isJumping = false
        moduleState.jumpPhysics.isJumping = false
        moduleState.jumpPhysics.jumpType = "normal"
    end)
    
    -- Безопасный сброс
    task.delay(1.0, function()
        moduleState.isJumping = false
        moduleState.jumpPhysics.isJumping = false
        moduleState.jumpPhysics.jumpType = "normal"
    end)
end

-- Умное позиционирование с учетом размера ворот
local function getSmartPosition(defenseBase, rightVec, lateral, goalWidth, threatLateral, enemyLateral, isAggro, ballPos, ballVel, ballHeight)
    local maxLateral = goalWidth * CONFIG.LATERAL_MAX_MULT
    local baseLateral = 0
    
    -- Для больших ворот даем больше свободы перемещения
    if moduleState.gateDetection.isBigGate then
        maxLateral = maxLateral * 1.3
    end
    
    -- Если мяч высоко, остаемся в центре
    if ballHeight and ballHeight > CONFIG.HIGH_BALL_THRES then
        baseLateral = 0
        moduleState.positioning.lastGoodPosition = defenseBase
        return Vector3.new(defenseBase.X, defenseBase.Y, defenseBase.Z)
    end
    
    -- Основная логика позиционирования
    if threatLateral ~= 0 then 
        local centerOffset = math.abs(threatLateral) / (goalWidth / 2)
        
        if centerOffset > 0.7 then
            baseLateral = threatLateral * 0.4
        else
            baseLateral = threatLateral * 0.2
        end
    end
    
    -- Учет позиции врага с мячом
    if enemyLateral ~= 0 and isAggro then 
        local enemyOffset = math.abs(enemyLateral) / (goalWidth / 2)
        
        if enemyOffset > 0.6 then
            baseLateral = enemyLateral * 0.3
        else
            baseLateral = enemyLateral * 0.15
        end
    end
    
    -- Для больших ворот можно быть более агрессивным
    if moduleState.gateDetection.isBigGate and isAggro then
        baseLateral = baseLateral * 1.2
    end
    
    -- Центральный bias
    local centerBias = CONFIG.POSITION_CENTER_BIAS
    baseLateral = baseLateral * (1 - centerBias)
    
    local finalLateral = math.clamp(baseLateral, -maxLateral * CONFIG.GATE_COVERAGE, maxLateral * CONFIG.GATE_COVERAGE)
    local finalPos = Vector3.new(
        defenseBase.X + rightVec.X * finalLateral, 
        defenseBase.Y, 
        defenseBase.Z + rightVec.Z * finalLateral
    )
    
    -- Ограничиваем максимальное удаление от ворот
    if GoalCFrame then
        local toGoal = finalPos - GoalCFrame.Position
        local forwardDist = toGoal:Dot(GoalForward)
        
        if forwardDist < CONFIG.STAND_DIST * 0.8 then
            finalPos = GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST * 0.8
        elseif forwardDist > CONFIG.ZONE_DIST * 0.7 then
            finalPos = GoalCFrame.Position + GoalForward * CONFIG.ZONE_DIST * 0.7
        end
    end
    
    moduleState.positioning.optimalPosition = finalPos
    moduleState.positioning.lastGoodPosition = finalPos
    
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

-- Поиск точки перехвата с учетом направления для дайва
local function findBestInterceptPoint(rootPos, ballPos, ballVel, points)
    if not points or #points < 2 then 
        return nil, "normal"
    end
    
    local bestPoint = nil
    local bestScore = math.huge
    local bestJumpType = "normal"
    local ballSpeed = ballVel.Magnitude
    
    for i = 2, math.min(#points, 60) do
        local point = points[i]
        local pointHeight = point.Y
        
        if pointHeight >= 2 and pointHeight <= 10 then
            local distToPoint = (rootPos - point).Magnitude
            local ballTravelDist = 0
            
            for j = 1, i - 1 do
                ballTravelDist = ballTravelDist + (points[j + 1] - points[j]).Magnitude
            end
            
            local timeToPoint = ballTravelDist / math.max(1, ballSpeed)
            local timeToReach = distToPoint / CONFIG.SPEED
            
            if timeToReach < timeToPoint - 0.2 then
                local score = distToPoint
                local jumpType = "normal"
                
                -- Определяем нужен ли дайв-прыжок
                if GoalCFrame then
                    local toGoal = (point - GoalCFrame.Position)
                    local lateralDist = toGoal:Dot(GoalRight)
                    
                    -- Для больших ворот используем дайв-прыжки
                    if moduleState.gateDetection.isBigGate and CONFIG.USE_DIVE_JUMPS then
                        if lateralDist < -GoalWidth * 0.25 and distToPoint < 15 then
                            jumpType = "left"
                            score = score - 10  -- Бонус за дайв-прыжки
                        elseif lateralDist > GoalWidth * 0.25 and distToPoint < 15 then
                            jumpType = "right"
                            score = score - 10
                        end
                    end
                    
                    local forwardDist = toGoal:Dot(GoalForward)
                    
                    if forwardDist < 0 then
                        score = score + 50
                    elseif forwardDist > 15 then
                        score = score + 20
                    end
                    
                    if forwardDist > 0 and forwardDist < 8 then
                        score = score - 15
                    end
                end
                
                if score < bestScore then
                    bestScore = score
                    bestPoint = point
                    bestJumpType = jumpType
                end
            end
        end
    end
    
    return bestPoint, bestJumpType
end

-- Проверка зоны защиты
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

-- Предсказание позиции врага
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
        local count = 0
        
        for i = 2, #history do
            local timeDiff = history[i].time - history[i - 1].time
            if timeDiff > 0 then
                local vel = (history[i].position - history[i - 1].position) / timeDiff
                avgVelocity = avgVelocity + vel
                count = count + 1
            end
        end
        
        if count > 0 then
            avgVelocity = avgVelocity / count
            local predictedPos = enemyRoot.Position + avgVelocity * CONFIG.ATTACK_PREDICT_TIME
            
            moduleState.predictedEnemyPositions[enemyId] = predictedPos
            
            return predictedPos
        end
    end
    
    return enemyRoot.Position
end

-- Поиск цели для атаки
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
                    
                    if inZone then
                        score = score + 70
                    end
                    
                    local hasBall = false
                    pcall(function()
                        if ball:FindFirstChild("creator") and ball.creator.Value == otherPlayer then
                            hasBall = true
                            score = score + 150
                        end
                    end)
                    
                    score = score + (100 - math.min(distToTarget, 100))
                    
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

-- Блокировка врага
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
    
    if enemySpeed > 5 then
        local enemyMoveDir = enemyVelocity.Unit
        local enemyMoveDistance = enemySpeed * CONFIG.ATTACK_PREDICT_TIME * 1.5
        predictedBlockPos = predictedEnemyPos + enemyMoveDir * enemyMoveDistance
    end
    
    local blockDistance = CONFIG.ATTACK_DISTANCE
    
    local hasBall = false
    pcall(function()
        if ball:FindFirstChild("creator") and ball.creator.Value == targetPlayer then
            hasBall = true
            blockDistance = blockDistance * 0.7
        end
    end)
    
    local enemyToGoal = (goalCenter - predictedBlockPos).Unit
    local blockPos = predictedBlockPos + enemyToGoal * blockDistance
    
    blockPos = Vector3.new(blockPos.X, root.Position.Y, blockPos.Z)
    
    if CONFIG.SHOW_ATTACK_TARGET and moduleState.enabled then
        drawAttackTarget(predictedBlockPos)
    end
    
    moveToTarget(root, blockPos)
    rotateSmooth(root, predictedBlockPos, false, false, Vector3.new())
    
    if hasBall and distToTarget < CONFIG.ATTACK_DISTANCE * 1.2 then
        moduleState.lastAttackTime = tick()
        return true
    end
    
    return false
end

-- Анализ ситуации для прыжков с учетом размера ворот
local function analyzeShotSituation(ballPos, ballVel, endpoint, rootPos, points)
    local analysis = {
        action = "none",
        confidence = 0,
        reason = "",
        urgency = 0,
        targetPosition = nil,
        jumpType = "normal"
    }
    
    if not ballPos then 
        return analysis 
    end
    
    local ballHeight = ballPos.Y
    local ballSpeed = ballVel.Magnitude
    local distToBall = (rootPos - ballPos).Magnitude
    
    moduleState.threatAnalysis.ballHeight = ballHeight
    
    -- Определяем, является ли мяч высоким
    local isHighBall = ballHeight > CONFIG.HIGH_BALL_THRES
    local isVeryHighBall = ballHeight > CONFIG.HIGH_BALL_THRES + 3
    local isEndpointHigh = endpoint and endpoint.Y > CONFIG.JUMP_THRES
    
    -- Определяем скорость
    local isFastBall = ballSpeed > CONFIG.JUMP_VEL_THRES
    local isVeryFast = ballSpeed > CONFIG.JUMP_VEL_THRES + 10
    
    -- Угол полета
    local verticalAngle = math.deg(math.asin(math.clamp(ballVel.Y / math.max(ballSpeed, 0.1), -1, 1)))
    local isHighAngle = verticalAngle > 25
    local isLowAngle = verticalAngle < 15
    
    -- Время реакции
    local timeToReach = distToBall / math.max(ballSpeed, 1)
    
    -- ПРИОРИТЕТ 1: ВЫСОКИЙ МЯЧ - ПРЫЖОК
    if isHighBall and ballSpeed > 20 and isHighAngle then
        analysis.action = "jump"
        analysis.confidence = 0.9
        analysis.urgency = 0.9
        analysis.reason = "ПРЫЖОК: высокий мяч с большой скоростью"
        
        -- Определяем тип прыжка
        if GoalCFrame and endpoint then
            local lateralDist = (endpoint - GoalCFrame.Position):Dot(GoalRight)
            
            -- Для больших ворот используем дайв-прыжки
            if moduleState.gateDetection.isBigGate and CONFIG.USE_DIVE_JUMPS then
                if lateralDist < -GoalWidth * 0.3 and distToBall < 18 then
                    analysis.jumpType = "left"
                    analysis.reason = "ДАЙВ-ПРЫЖОК ВЛЕВО: большой ворота, мяч в левом углу"
                elseif lateralDist > GoalWidth * 0.3 and distToBall < 18 then
                    analysis.jumpType = "right"
                    analysis.reason = "ДАЙВ-ПРЫЖОК ВПРАВО: большой ворота, мяч в правом углу"
                end
            end
        end
        
        -- Определяем, куда прыгать
        if points then
            for i = 2, math.min(#points, 40) do
                local point = points[i]
                if point.Y >= 2 and point.Y <= 10 then
                    local distToPoint = (rootPos - point).Magnitude
                    if distToPoint < 15 then
                        analysis.targetPosition = point
                        break
                    end
                end
            end
        end
        
        if not analysis.targetPosition then
            analysis.targetPosition = ballPos + Vector3.new(0, CONFIG.JUMP_HEIGHT, 0)
        end
        
        return analysis
    end
    
    -- ПРИОРИТЕТ 2: БЫСТРЫЙ НИЗКИЙ МЯЧ БЛИЗКО - НЫРЯНИЕ
    if not isHighBall and ballSpeed > CONFIG.DIVE_VEL_THRES and distToBall < CONFIG.DIVE_DIST then
        analysis.action = "dive"
        analysis.confidence = 0.85
        analysis.urgency = 0.8
        analysis.reason = "НЫРЯНИЕ: быстрый низкий мяч рядом"
        analysis.targetPosition = ballPos
        
        return analysis
    end
    
    -- ПРИОРИТЕТ 3: МЯЧ НА ВЫСОТЕ ДЛЯ КАСАНИЯ
    if ballHeight > 2 and ballHeight < 6 and distToBall < CONFIG.TOUCH_RANGE and ballSpeed < 25 then
        analysis.action = "touch"
        analysis.confidence = 0.75
        analysis.urgency = 0.7
        analysis.reason = "КАСАНИЕ: мяч на доступной высоте"
        analysis.targetPosition = ballPos
        
        return analysis
    end
    
    -- ПРИОРИТЕТ 4: ПОЗИЦИОНИРОВАНИЕ
    analysis.action = "position"
    analysis.confidence = 0.6
    analysis.urgency = 0.4
    analysis.reason = "ПОЗИЦИОНИРОВАНИЕ: стандартная ситуация"
    
    return analysis
end

-- Функция ныряния
local function performDive(root, hum, diveTarget)
    if moduleState.isDiving then 
        return 
    end
    
    moduleState.isDiving = true
    moduleState.lastDiveTime = tick()
    moduleState.divePhysics.diveStartTime = tick()
    
    -- Очистка физики
    if moduleState.divePhysics.activeBV then 
        pcall(function() 
            moduleState.divePhysics.activeBV:Destroy() 
        end) 
        moduleState.divePhysics.activeBV = nil 
    end
    
    -- Определяем направление ныряния
    local relToGoal = diveTarget - GoalCFrame.Position
    local lateralDist = relToGoal:Dot(GoalRight)
    local dir = lateralDist > 0 and "Right" or "Left"
    moduleState.divePhysics.diveDirection = dir

    -- Отправляем на сервер
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir .. "Dive", root.CFrame)
    end)

    -- Вектор ныряния
    local toTarget = diveTarget - root.Position
    local horizontalDir = Vector3.new(toTarget.X, 0, toTarget.Z)
    
    if horizontalDir.Magnitude > 0.1 then
        horizontalDir = horizontalDir.Unit
    else
        horizontalDir = -GoalForward
    end
    
    -- Применяем физику ныряния
    local diveSpeed = math.min(CONFIG.DIVE_SPEED, 35)
    
    moduleState.divePhysics.activeBV = Instance.new("BodyVelocity")
    moduleState.divePhysics.activeBV.Parent = root
    moduleState.divePhysics.activeBV.MaxForce = Vector3.new(1000000, 0, 1000000)
    moduleState.divePhysics.activeBV.Velocity = horizontalDir * diveSpeed
    
    game.Debris:AddItem(moduleState.divePhysics.activeBV, 0.3)
    
    -- Плавное замедление
    if ts then
        ts:Create(moduleState.divePhysics.activeBV, 
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
            {Velocity = Vector3.new()}
        ):Play()
    end

    -- Отключаем авто-ротацию
    hum.AutoRotate = false

    -- Анимация ныряния
    local lowDive = (diveTarget.Y <= 3.5)
    pcall(function()
        local animName = dir .. (lowDive and "LowDive" or "Dive")
        local anim = hum:LoadAnimation(ReplicatedStorage.Animations.GK[animName])
        anim.Priority = Enum.AnimationPriority.Action4
        anim:Play()
    end)

    -- Отключаем прыжки во время ныряния
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    
    -- Автоматическое восстановление
    task.delay(0.8, function()
        if hum and hum.Parent then
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum.AutoRotate = true
        end
        
        -- Очистка физики
        if moduleState.divePhysics.activeBV then 
            pcall(function() 
                moduleState.divePhysics.activeBV.Velocity = Vector3.new()
                moduleState.divePhysics.activeBV:Destroy() 
            end) 
            moduleState.divePhysics.activeBV = nil 
        end
        
        moduleState.isDiving = false
    end)
    
    -- Безопасный сброс
    task.delay(1.2, function()
        moduleState.isDiving = false
    end)
end

-- Позиционирование при угловых
local function handleCornerPositioning(root, ballPos, ballVel)
    if not ballPos or not GoalCFrame then 
        return nil 
    end
    
    local rightVec = GoalCFrame.RightVector
    local ballLateral = (ballPos - GoalCFrame.Position):Dot(rightVec)
    
    local sideChoice = ballLateral > 0 and 1 or -1
    moduleState.positioning.lastSideChoice = sideChoice
    
    -- Позиция для защиты от углового
    local lateralOffset = sideChoice * GoalWidth * 0.25
    local forwardOffset = CONFIG.STAND_DIST * 1.2
    
    local basePos = GoalCFrame.Position + GoalForward * forwardOffset
    local targetPos = Vector3.new(
        basePos.X + rightVec.X * lateralOffset,
        root.Position.Y,
        basePos.Z + rightVec.Z * lateralOffset
    )
    
    -- Не подходим слишком близко к углу
    local toGoal = targetPos - GoalCFrame.Position
    local lateralDist = math.abs(toGoal:Dot(rightVec))
    
    if lateralDist > GoalWidth * 0.35 then
        targetPos = GoalCFrame.Position + GoalForward * forwardOffset
    end
    
    moveToTarget(root, targetPos)
    rotateSmooth(root, ballPos, false, false, ballVel or Vector3.new())
    
    return targetPos
end

-- Касание мяча
local function touchBall(character, ball)
    if tick() - moduleState.lastTouchTime < 0.3 then
        return
    end
    
    for _, handName in pairs({"RightHand", "LeftHand"}) do
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

-- Очистка
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
        timeToImpact = 999,
        ballHeight = 0
    }
    moduleState.positioning = {
        optimalPosition = nil,
        lastSideChoice = 0,
        sideBiasTimer = 0,
        gateCoveragePoints = {},
        vulnerabilityMap = {},
        lastGoodPosition = nil,
        avoidCornerTimer = 0
    }
    moduleState.jumpPhysics = {
        isJumping = false,
        jumpStartTime = 0,
        jumpTarget = nil,
        jumpType = "normal"
    }
    moduleState.gateDetection = {
        leftPost = nil,
        rightPost = nil,
        gateWidth = 0,
        isBigGate = false,
        lastDetectionTime = 0,
        detectionMethod = "advanced",
        debugText = nil
    }
end

-- Основной цикл с плавной визуализацией
local function startHeartbeat()
    if moduleState.heartbeatConnection then
        moduleState.heartbeatConnection:Disconnect()
    end
    
    moduleState.heartbeatConnection = rs.Heartbeat:Connect(function()
        if not moduleState.enabled then 
            hideAllVisuals()
            return 
        end
        
        moduleState.frameCounter = moduleState.frameCounter + 1
        
        -- ВИЗУАЛИЗАЦИЯ: обновляем КАЖДЫЙ кадр
        local updateVisuals = true
        
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

        -- ВИЗУАЛИЗАЦИЯ: обновляем каждый кадр
        if updateVisuals then
            if CONFIG.SHOW_GOAL_CUBE and moduleState.visualObjects.GoalCube then
                drawCube(moduleState.visualObjects.GoalCube, GoalCFrame, Vector3.new(GoalWidth, 8, 2), CONFIG.GOAL_CUBE_COLOR)
            end
            
            if CONFIG.SHOW_ZONE then 
                drawFlatZone() 
            end
            
            -- Обновляем debug текст
            updateDebugText()
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

        -- Поиск цели для атаки
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

        -- Отслеживание врага
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

        -- Агрессивное давление
        if CONFIG.AGGRESSIVE_MODE and owner and owner ~= player and oRoot and not smartBlockActive then
            local predictedPos = predictEnemyPosition(oRoot)
            local targetPos = predictedPos + GoalForward * 20
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

        -- Предсказание траектории мяча
        local points, endpoint = nil, nil
        local threatLateral = 0
        local isShot = not hasWeld and owner ~= player
        local distEnd = math.huge
        local velMag = ball.Velocity.Magnitude
        local distBall = (root.Position - ball.Position).Magnitude
        local isThreat = false
        local timeToEndpoint = 999

        -- Обнаружение новых ударов
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
                
                -- Обновляем анализ угрозы
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

        -- ВИЗУАЛИЗАЦИЯ траектории
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

        -- ВИЗУАЛИЗАЦИЯ бокса мяча
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

        -- Логика позиционирования
        if not smartBlockActive then
            local rightVec = GoalRight
            local defenseBase = GoalCFrame.Position + GoalForward * CONFIG.STAND_DIST
            
            -- Проверка на угловой
            local isCornerKick = false
            if ball.Position.Y > 8 and distBall > 30 and math.abs(threatLateral) > GoalWidth * 0.4 then
                isCornerKick = true
                local cornerPos = handleCornerPositioning(root, ball.Position, ball.Velocity)
                if cornerPos then
                    defenseBase = cornerPos
                end
            end

            if not isCornerKick then
                if isMyBall then
                    -- С мячом - просто стоим перед воротами
                    local bestPos = getSmartPosition(defenseBase, rightVec, 0, GoalWidth, 0, 0, false, ball.Position, ball.Velocity, ball.Position.Y)
                    moveToTarget(root, bestPos)
                elseif oRoot and isAggro then
                    -- Враг с мячом - блокируем линию удара
                    local targetDist = math.max(1.8, enemyDistFromLine - 1.5)
                    defenseBase = GoalCFrame.Position + GoalForward * targetDist
                    
                    local bestPos = getSmartPosition(defenseBase, rightVec, enemyLateral * 0.3, GoalWidth, 0, enemyLateral, true, ball.Position, ball.Velocity, ball.Position.Y)
                    moveToTarget(root, bestPos)
                elseif not hasWeld then
                    -- Мяч в полете - защищаем центр ворот
                    local advanceMultiplier = math.min(1.0, velMag / 35)
                    local advanceDist = math.min(5.0, distBall * 0.1 + advanceMultiplier * 2.0)
                    defenseBase = GoalCFrame.Position + GoalForward * advanceDist
                    
                    local bestPos = getSmartPosition(defenseBase, rightVec, 0, GoalWidth, 0, 0, false, ball.Position, ball.Velocity, ball.Position.Y)
                    moveToTarget(root, bestPos)
                else
                    -- Мяч у врага, но не в агрессивной дистанции
                    local targetDist = math.max(CONFIG.STAND_DIST, math.min(7.0, enemyDistFromLine * 0.4))
                    defenseBase = GoalCFrame.Position + GoalForward * targetDist
                    
                    local bestPos = getSmartPosition(defenseBase, rightVec, enemyLateral * 0.2, GoalWidth, 0, enemyLateral, false, ball.Position, ball.Velocity, ball.Position.Y)
                    moveToTarget(root, bestPos)
                end
            end
        end

        -- Вращение
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

        -- УМНЫЕ ДЕЙСТВИЯ С ПРАВИЛЬНЫМИ ПРЫЖКАМИ
        if not isMyBall and not moduleState.isDiving and not moduleState.isJumping then
            
            -- Анализ ситуации
            local shotAnalysis = analyzeShotSituation(ball.Position, ball.Velocity, endpoint, root.Position, points)
            
            -- Касание мяча
            if shotAnalysis.action == "touch" and distBall < CONFIG.TOUCH_RANGE then
                touchBall(char, ball)
            end
            
            -- ПРЫЖОК: исправленная логика с учетом дайв-прыжков
            if shotAnalysis.action == "jump" and tick() - moduleState.lastJumpTime > CONFIG.JUMP_COOLDOWN then
                local ballHeight = ball.Position.Y
                local ballSpeed = ball.Velocity.Magnitude
                
                if ballHeight > CONFIG.HIGH_BALL_THRES and ballSpeed > 20 then
                    local toGoal = (GoalCFrame.Position - ball.Position).Unit
                    local ballDir = ball.Velocity.Unit
                    local angleToGoal = math.deg(math.acos(math.clamp(ballDir:Dot(toGoal), -1, 1)))
                    
                    if angleToGoal < 60 then
                        forceJump(hum, shotAnalysis.targetPosition, shotAnalysis.jumpType)
                    end
                end
            end
            
            -- Ныряние
            if shotAnalysis.action == "dive" and tick() - moduleState.lastDiveTime > CONFIG.DIVE_COOLDOWN then
                performDive(root, hum, shotAnalysis.targetPosition or ball.Position)
            end
        else
            if isMyBall then 
                moduleState.isDiving = false 
                moduleState.isJumping = false
            end
        end

        -- Очистка визуализации если нет удара
        if not isShot or not points then
            if updateVisuals then
                clearTrajAndEndpoint()
            end
        end
    end)
end

-- Синхронизация конфигурации
local function syncConfig()
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
            moduleState.notify("AutoGK", "Enabled with enhanced gate detection", true)
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
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalKeeper V2.2 - Enhanced Gate Detection" })
        
        -- Основные настройки
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
                    notifyFunc("AutoGK", "Enhanced Gate Detection Enabled", true)
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
        
        -- НАСТРОЙКИ ДЕТЕКЦИИ ВОРОТ
        UI.Sections.AutoGoalKeeper:Header({ Name = "Gate Detection Settings" })
        
        moduleState.uiElements.GATE_DETECTION_METHOD = UI.Sections.AutoGoalKeeper:Dropdown({
            Name = "Detection Method",
            Default = CONFIG.GATE_DETECTION_METHOD,
            Options = {"advanced", "simple"},
            Callback = function(v) 
                CONFIG.GATE_DETECTION_METHOD = v 
                moduleState.gateDetection.detectionMethod = v
                notifyFunc("AutoGK", "Gate detection method: " .. v, true)
            end
        }, 'GateDetectionMethod')
        
        moduleState.uiElements.BIG_GATE_THRESHOLD = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Big Gate Threshold",
            Minimum = 30,
            Maximum = 50,
            Default = CONFIG.BIG_GATE_THRESHOLD,
            Precision = 1,
            Callback = function(v) CONFIG.BIG_GATE_THRESHOLD = v end
        }, 'BigGateThreshold')
        
        moduleState.uiElements.SHOW_GATE_INFO = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Gate Info",
            Default = CONFIG.SHOW_GATE_INFO,
            Callback = function(v) 
                CONFIG.SHOW_GATE_INFO = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        }, 'ShowGateInfo')
        
        -- Настройки прыжков с дайвом
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Dive Jump Settings (Big Gates Only)" })
        
        moduleState.uiElements.USE_DIVE_JUMPS = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Enable Dive Jumps",
            Default = CONFIG.USE_DIVE_JUMPS,
            Callback = function(v) 
                CONFIG.USE_DIVE_JUMPS = v 
                notifyFunc("AutoGK", v and "Dive jumps enabled for big gates" or "Dive jumps disabled", true)
            end
        }, 'UseDiveJumps')
        
        moduleState.uiElements.DIVE_JUMP_LEFT_ENABLED = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Enable Left Dive Jump",
            Default = CONFIG.DIVE_JUMP_LEFT_ENABLED,
            Callback = function(v) CONFIG.DIVE_JUMP_LEFT_ENABLED = v end
        }, 'DiveJumpLeftEnabled')
        
        moduleState.uiElements.DIVE_JUMP_RIGHT_ENABLED = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Enable Right Dive Jump",
            Default = CONFIG.DIVE_JUMP_RIGHT_ENABLED,
            Callback = function(v) CONFIG.DIVE_JUMP_RIGHT_ENABLED = v end
        }, 'DiveJumpRightEnabled')
        
        -- Настройки движения
        UI.Sections.AutoGoalKeeper:Divider()
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
        
        -- Настройки прыжков
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Jump Settings" })
        
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
        
        moduleState.uiElements.HIGH_BALL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "High Ball Threshold",
            Minimum = 4.0,
            Maximum = 10.0,
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
        
        -- Настройки ныряния
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Dive Settings" })
        
        moduleState.uiElements.DIVE_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Distance",
            Minimum = 5,
            Maximum = 25,
            Default = CONFIG.DIVE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_DIST = v end
        }, 'DiveDistanceGK')
        
        moduleState.uiElements.DIVE_COOLDOWN = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Cooldown",
            Minimum = 0.5,
            Maximum = 3.0,
            Default = CONFIG.DIVE_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_COOLDOWN = v end
        }, 'DiveCDGK')
        
        -- Визуальные настройки
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
        
        -- Информация
        UI.Sections.AutoGoalKeeper:Divider()
        UI.Sections.AutoGoalKeeper:Header({ Name = "Information" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "AutoGK V2.2 - ENHANCED GATE DETECTION",
            Body = [[
УЛУЧШЕНИЯ:
1. Детект ворот: Ищет leftpost/rightpost по наличию Sound, CylinderMesh, Script
2. Адаптивность: Работает с любыми воротами, даже с зашифрованными названиями
3. Большие ворота: Определяет ворота шириной >= 40 как "большие"
4. Прыжки с дайвом: JumpLeftNew и JumpRightNew только на больших воротах
5. Дебаг информация: Показывает размер ворот и тип в реальном времени

ОСОБЕННОСТИ:
- Advanced detection: Ищет части с CylinderMesh + Sound/Script
- Simple detection: Ищет по имени (LeftPost/RightPost)
- Big gates: Прыжки с дайвом только при ширине >= 40
- Adaptive positioning: Учитывает размер ворот при позиционировании

АНИМАЦИИ ПРЫЖКОВ:
1. Обычный прыжок: ReplicatedStorage.Animations.GK.Jump
2. Дайв влево: ReplicatedStorage.Animations.GK.JumpLeftNew (только большие ворота)
3. Дайв вправо: ReplicatedStorage.Animations.GK.JumpRightNew (только большие ворота)

ДЕБАГ ИНФОРМАЦИЯ:
- Показывает ширину ворот
- Определяет большие/малые ворота
- Метод детекции
]]
        })
    end
    
    -- Секция синхронизации конфигурации
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
