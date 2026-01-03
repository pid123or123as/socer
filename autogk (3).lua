local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local ws = Workspace
local rs = RunService
local uis = UserInputService
local ts = TweenService

-- Configuration
local CONFIG = {
    ENABLED = false,
    
    -- Basic settings
    SPEED = 32,
    AGGRESSIVE_SPEED = 38,
    STAND_DIST = 2.8,
    MIN_DIST = 0.8,
    
    -- Closing and attack settings
    CLOSE_DISTANCE = 15,
    ATTACK_DISTANCE = 8,
    CLOSE_SPEED_MULT = 1.2,
    AGGRESSION_DISTANCE = 25,
    STEAL_DISTANCE = 4.5,
    
    -- Physics prediction
    PRED_STEPS = 80,
    CURVE_MULT = 38,
    DT = 1/180,
    GRAVITY = 112,
    DRAG = 0.981,
    BOUNCE_XZ = 0.76,
    BOUNCE_Y = 0.65,
    
    -- Distances and thresholds
    DIVE_DIST = 26,
    TOUCH_RANGE = 20,
    NEAR_BALL_DIST = 5.0,
    DIVE_VEL_THRES = 24,
    JUMP_VEL_THRES = 24,
    HIGH_BALL_THRES = 8,
    JUMP_THRES = 1,
    DIVE_COOLDOWN = 0.9,
    JUMP_COOLDOWN = 0.6,
    PRED_UPDATE_RATE = 1,
    
    -- Smart rotation
    SMART_ROTATION_SMOOTH = 0.15,
    MAX_ROTATION_ANGLE = 60,
    MIN_SAFE_ANGLE = 15,
    ROTATION_HEIGHT_FACTOR = 0.08,
    PREDICTION_LOOK_AHEAD = 3,
    
    -- Goal size
    BIG_GOAL_THRESHOLD = 40,
    BIG_GOAL_STAND_DIST = 4.0,
    
    -- Intercept
    INTERCEPT_DISTANCE = 35,
    INTERCEPT_SPEED_MULT = 1.34,
    INTERCEPT_COOLDOWN = 0.1,
    
    -- Jumps
    JUMP_RADIUS = 40,
    JUMP_MIN_HEIGHT_DIFF = 0.7,
    JUMP_PREDICTION_TIME = 0.3,
    JUMP_REACTION_TIME = 0.1,
    
    -- Dynamic positioning
    ZONE_WIDTH_MULTIPLIER = 2.5,
    ZONE_DEPTH = 56,
    ZONE_HEIGHT = 0.2,
    ZONE_OFFSET = 28,
    
    -- Attack logic
    PRESS_DISTANCE = 55,
    PRESSURE_DISTANCE = 40,
    ANGLING_FACTOR = 0.6,
    SIDE_ANGLE_LIMIT = 45,
    
    -- Visual settings
    SHOW_TRAJECTORY = true,
    SHOW_ENDPOINT = true,
    SHOW_GOAL_CUBE = true,
    SHOW_ZONE = true,
    SHOW_BALL_BOX = true,
    
    -- Colors
    TRAJECTORY_COLOR = Color3.fromHSV(0.5, 1, 1),
    ENDPOINT_COLOR = Color3.new(1, 1, 0),
    GOAL_CUBE_COLOR = Color3.new(1, 0, 0),
    ZONE_COLOR = Color3.new(0, 1, 0),
    BALL_BOX_COLOR = Color3.new(0, 0.8, 1),
    BALL_BOX_JUMP_COLOR = Color3.new(1, 0, 1),
    BALL_BOX_SAFE_COLOR = Color3.new(0, 1, 0)
}

-- Module state
local moduleState = {
    enabled = false,
    lastDiveTime = 0,
    lastJumpTime = 0,
    lastInterceptTime = 0,
    lastAttackTime = 0,
    isDiving = false,
    isAttacking = false,
    isClosing = false,
    endpointRadius = 3.5,
    frameCounter = 0,
    cachedPoints = nil,
    cachedPointsTime = 0,
    lastBallVelMag = 0,
    currentBV = nil,
    smoothCFrame = nil,
    isBigGoal = false,
    diveAnimationPlaying = false,
    jumpAnimationPlaying = false,
    willJump = false,
    currentAction = "IDLE",
    visualObjects = {},
    GoalCFrame = nil,
    GoalForward = nil,
    GoalWidth = 0,
    GoalHeight = 0,
    GoalPosts = {},
    heartbeatConnection = nil,
    renderConnection = nil,
    inputConnection = nil,
    uiElements = {}
}

-- ==================== FIXED GOAL DETECTION ====================

local function GetMyTeam()
    local myTeam = nil
    local myGoalName = nil
    
    if ws.Bools:FindFirstChild("HPG") and ws.Bools.HPG.Value == player then
        myTeam = "Home"
        myGoalName = "HomeGoal"
    elseif ws.Bools:FindFirstChild("APG") and ws.Bools.APG.Value == player then
        myTeam = "Away"
        myGoalName = "AwayGoal"
    end
    
    return myTeam, myGoalName
end

local function UpdateGoal()
    local myTeam, myGoalName = GetMyTeam()
    if not myGoalName then 
        moduleState.GoalCFrame = nil
        moduleState.GoalForward = nil
        moduleState.GoalWidth = 0
        moduleState.GoalHeight = 0
        moduleState.GoalPosts = {}
        return false 
    end
    
    local goalFolder = Workspace:FindFirstChild(myGoalName)
    if not goalFolder then 
        moduleState.GoalCFrame = nil
        moduleState.GoalForward = nil
        moduleState.GoalWidth = 0
        moduleState.GoalHeight = 0
        moduleState.GoalPosts = {}
        return false 
    end
    
    local frame = goalFolder:FindFirstChild("Frame")
    if not frame then 
        moduleState.GoalCFrame = nil
        moduleState.GoalForward = nil
        moduleState.GoalWidth = 0
        moduleState.GoalHeight = 0
        moduleState.GoalPosts = {}
        return false 
    end
    
    local leftPost, rightPost, crossbarPart
    local foundParts = {}
    
    -- Search for posts by criteria (Sound + CylinderMesh + Script)
    for _, part in ipairs(frame:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "Crossbar" then
            local hasSound = false
            local hasCylinder = false
            local hasScript = false
            
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("Sound") then hasSound = true
                elseif child:IsA("CylinderMesh") then hasCylinder = true
                elseif child:IsA("Script") then hasScript = true end
            end
            
            if hasSound and hasCylinder and hasScript then
                table.insert(foundParts, part)
            end
        elseif part:IsA("BasePart") and part.Name == "Crossbar" then
            crossbarPart = part
        end
    end
    
    -- Determine left and right posts
    if #foundParts >= 2 then
        leftPost = foundParts[1]
        rightPost = foundParts[2]
        
        -- If more than 2 parts found, determine by X coordinate
        if #foundParts > 2 then
            for i = 3, #foundParts do
                if foundParts[i].Position.X < leftPost.Position.X then
                    leftPost = foundParts[i]
                elseif foundParts[i].Position.X > rightPost.Position.X then
                    rightPost = foundParts[i]
                end
            end
        end
    else
        -- Fallback search by names
        leftPost = frame:FindFirstChild("LeftPost")
        rightPost = frame:FindFirstChild("RightPost")
    end
    
    if not crossbarPart then
        crossbarPart = frame:FindFirstChild("Crossbar")
    end
    
    if not (leftPost and rightPost and crossbarPart) then 
        moduleState.GoalCFrame = nil
        moduleState.GoalForward = nil
        moduleState.GoalWidth = 0
        moduleState.GoalHeight = 0
        moduleState.GoalPosts = {}
        return false 
    end
    
    -- Save goal posts information
    moduleState.GoalPosts = {
        LeftPost = leftPost,
        RightPost = rightPost,
        Crossbar = crossbarPart
    }
    
    -- Calculate goal center
    local center = (leftPost.Position + rightPost.Position) / 2
    
    -- Determine forward direction (from crossbar to center)
    local forward = (center - crossbarPart.Position).Unit
    
    -- Determine up direction
    local up = crossbarPart.Position.Y > leftPost.Position.Y and Vector3.yAxis or -Vector3.yAxis
    
    -- Determine right direction
    local rightDir = (rightPost.Position - leftPost.Position).Unit
    
    -- Create CFrame
    moduleState.GoalCFrame = CFrame.fromMatrix(center, rightDir, up, -forward)
    moduleState.GoalForward = -forward
    moduleState.GoalWidth = (leftPost.Position - rightPost.Position).Magnitude
    moduleState.GoalHeight = math.abs(crossbarPart.Position.Y - leftPost.Position.Y)
    
    -- Determine if big goal
    moduleState.isBigGoal = moduleState.GoalWidth > CONFIG.BIG_GOAL_THRESHOLD
    
    return true
end

-- ==================== VISUALIZATION ====================

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
    
    moduleState.visualObjects.debugText = Drawing.new("Text")
    moduleState.visualObjects.debugText.Visible = false
    moduleState.visualObjects.debugText.Size = 18
    moduleState.visualObjects.debugText.Color = Color3.new(1, 1, 1)
    moduleState.visualObjects.debugText.Outline = true
    moduleState.visualObjects.debugText.OutlineColor = Color3.new(0, 0, 0)
    moduleState.visualObjects.debugText.Position = Vector2.new(10, 10)
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
end

local function drawCube(cube, cf, size, color)
    if not cf or not cube then 
        for _, l in ipairs(cube) do 
            if l then 
                l.Visible = false 
            end 
        end 
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
    
    local cam = ws.CurrentCamera
    for i, e in ipairs(edges) do
        local a, b = corners[e[1]], corners[e[2]]
        local sa, sb = cam:WorldToViewportPoint(a), cam:WorldToViewportPoint(b)
        local l = cube[i]
        
        if l then
            l.From = Vector2.new(sa.X, sa.Y) 
            l.To = Vector2.new(sb.X, sb.Y) 
            l.Color = color or l.Color
            l.Thickness = 4 
            l.Transparency = 0.5
            l.Visible = sa.Z > 0 and sb.Z > 0
        end
    end
end

local function drawFlatZone()
    if not (moduleState.GoalCFrame and moduleState.GoalForward and moduleState.GoalWidth) then 
        if moduleState.visualObjects.LimitCube then
            for _, l in ipairs(moduleState.visualObjects.LimitCube) do 
                if l then 
                    l.Visible = false 
                end 
            end 
        end
        return 
    end
    
    local offset = moduleState.isBigGoal and CONFIG.ZONE_OFFSET_MULTIPLIER or 28
    local center = moduleState.GoalCFrame.Position + moduleState.GoalForward * offset
    center = Vector3.new(center.X, 0, center.Z)
    local flatCF = CFrame.new(center) * CFrame.Angles(0, math.atan2(moduleState.GoalForward.X, moduleState.GoalForward.Z), 0)
    
    if moduleState.visualObjects.LimitCube then
        drawCube(moduleState.visualObjects.LimitCube, flatCF, Vector3.new(moduleState.GoalWidth * CONFIG.ZONE_WIDTH_MULTIPLIER, CONFIG.ZONE_HEIGHT, CONFIG.ZONE_DEPTH), CONFIG.ZONE_COLOR)
    end
end

-- Функция для отрисовки endpoint круга
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

-- ==================== TRAJECTORY PREDICTION ====================

local function checkGoalCollision(pos, nextPos, radius)
    for _, part in pairs(moduleState.GoalPosts) do
        if part then
            local partCFrame = part.CFrame
            local partSize = part.Size
            
            local localPos = partCFrame:PointToObjectSpace(pos)
            local localNextPos = partCFrame:PointToObjectSpace(nextPos)
            
            local min = -partSize/2 - Vector3.new(radius, radius, radius)
            local max = partSize/2 + Vector3.new(radius, radius, radius)
            
            if localNextPos.X >= min.X and localNextPos.X <= max.X and
               localNextPos.Y >= min.Y and localNextPos.Y <= max.Y and
               localNextPos.Z >= min.Z and localNextPos.Z <= max.Z then
               
                local normal = Vector3.new(0,0,0)
                local penetration = math.huge
                
                local axisDistances = {
                    {dist = max.X - localPos.X, normal = Vector3.new(1,0,0), axis = "X"},
                    {dist = localPos.X - min.X, normal = Vector3.new(-1,0,0), axis = "X"},
                    {dist = max.Y - localPos.Y, normal = Vector3.new(0,1,0), axis = "Y"},
                    {dist = localPos.Y - min.Y, normal = Vector3.new(0,-1,0), axis = "Y"},
                    {dist = max.Z - localPos.Z, normal = Vector3.new(0,0,1), axis = "Z"},
                    {dist = localPos.Z - min.Z, normal = Vector3.new(0,0,-1), axis = "Z"}
                }
                
                table.sort(axisDistances, function(a,b) return a.dist < b.dist end)
                
                normal = axisDistances[1].normal
                normal = partCFrame:VectorToWorldSpace(normal)
                
                return true, normal
            end
        end
    end
    return false, Vector3.new(0,0,0)
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
            local ballCFrame = ball.CFrame
            local rightVec = ballCFrame.RightVector
            local upVec = ballCFrame.UpVector
            
            local speedFactor = math.clamp(vel.Magnitude / 50, 0.3, 1.5)
            local curveStrength = CONFIG.CURVE_MULT * 0.045 * speedFactor
            
            local isTopSpin = math.abs(upVec:Dot(vel.Unit)) > 0.7
            local isSideSpin = math.abs(rightVec:Dot(vel.Unit)) > 0.7
            
            if isTopSpin then
                spinCurve = upVec * curveStrength
            elseif isSideSpin then
                spinCurve = rightVec * curveStrength
            else
                spinCurve = (rightVec + upVec * 0.5) * curveStrength
            end
        end
        
        if ws.Bools.Header and ws.Bools.Header.Value then 
            local headerStrength = 32 + math.min(vel.Magnitude * 0.2, 15)
            spinCurve = spinCurve + Vector3.new(0, headerStrength, 0) 
        end
    end)
    
    for i = 1, steps do
        local curveFade = 1 - (i/steps) * 0.5
        
        vel = vel * drag + spinCurve * dt * curveFade
        vel = vel - Vector3.new(0, gravity * dt * 1.04, 0)
        
        local nextPos = pos + vel * dt
        
        local collided, normal = checkGoalCollision(pos, nextPos, 1.1)
        if collided then
            local reflection = vel - 2 * vel:Dot(normal) * normal
            vel = reflection * 0.75
            pos = pos + normal * 0.25
        else
            pos = nextPos
        end
        
        if pos.Y < 0.5 then
            pos = Vector3.new(pos.X, 0.5, pos.Z)
            local bounceXZ = CONFIG.BOUNCE_XZ
            local bounceY = CONFIG.BOUNCE_Y
            
            if spinCurve.Y > 0 then
                bounceY = bounceY * 0.9
            end
            
            vel = Vector3.new(vel.X * bounceXZ, math.abs(vel.Y) * bounceY, vel.Z * bounceXZ)
        end
        
        table.insert(points, pos)
        
        if pos.Y < 0.6 and vel.Magnitude < 1.5 then
            break
        end
    end
    
    moduleState.cachedPoints = points
    moduleState.cachedPointsTime = tick()
    
    return points
end

-- ==================== CORE FUNCTIONS ====================

-- SMART ROTATION (COMPLETELY REWRITTEN)
local function smartRotation(root, ballPos, ballVel, isDiving, diveTarget, isMyBall, isJumping)
    if isMyBall or isJumping or not root then return end
    
    local char = root.Parent
    if not char then return end
    
    -- Skip rotation if diving
    if isDiving then return end
    
    local targetLookPos = ballPos
    
    -- Predict ball position for smoother tracking
    if ballVel.Magnitude > 10 then
        local predictionTime = math.clamp(ballPos.Y / 20, 0.1, 0.5)
        targetLookPos = ballPos + ballVel.Unit * CONFIG.PREDICTION_LOOK_AHEAD
    end
    
    -- Determine vector to ball
    local toBall = (targetLookPos - root.Position)
    local horizontalDist = Vector3.new(toBall.X, 0, toBall.Z).Magnitude
    
    -- Horizontal angle (only Y rotation)
    local horizontalDir = Vector3.new(toBall.X, 0, toBall.Z)
    if horizontalDir.Magnitude > 0.1 then
        horizontalDir = horizontalDir.Unit
    else
        horizontalDir = root.CFrame.LookVector * Vector3.new(1, 0, 1)
    end
    
    -- Smooth interpolation
    local currentCF = root.CFrame
    local currentLook = currentCF.LookVector * Vector3.new(1, 0, 1)
    
    if currentLook.Magnitude > 0.1 then
        currentLook = currentLook.Unit
    else
        currentLook = Vector3.new(0, 0, -1)
    end
    
    local smoothFactor = CONFIG.SMART_ROTATION_SMOOTH
    if ballVel.Magnitude > 25 then
        smoothFactor = smoothFactor * 1.5
    end
    
    -- Interpolate direction
    local newDir = currentLook:Lerp(horizontalDir, smoothFactor).Unit
    
    -- Apply rotation (Y ONLY)
    local lookAtPos = root.Position + newDir * 10
    root.CFrame = CFrame.lookAt(root.Position, Vector3.new(lookAtPos.X, root.Position.Y, lookAtPos.Z))
end

-- Rotation for Dive (SPECIAL LOGIC)
local function diveRotation(root, targetPos)
    if not root or not targetPos then return end
    
    -- For dive use direction from goal to ball
    if moduleState.GoalCFrame then
        local goalToTarget = (targetPos - moduleState.GoalCFrame.Position) * Vector3.new(1, 0, 1)
        if goalToTarget.Magnitude > 0.1 then
            local horizontalDir = goalToTarget.Unit
            local lookAtPos = root.Position + horizontalDir * 10
            root.CFrame = CFrame.lookAt(root.Position, Vector3.new(lookAtPos.X, root.Position.Y, lookAtPos.Z))
        end
    end
end

-- Smart positioning
local function calculateSmartPosition(ballPos, ownerRoot, isBallControlled, endpoint, ballVel)
    if not moduleState.GoalCFrame then 
        return moduleState.GoalCFrame and (moduleState.GoalCFrame.Position + moduleState.GoalForward * CONFIG.STAND_DIST) or Vector3.zero
    end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    local goalForward = moduleState.GoalForward
    
    -- Basic parameters
    local standDist = moduleState.isBigGoal and CONFIG.BIG_GOAL_STAND_DIST or CONFIG.STAND_DIST
    
    -- 1. DANGER ANALYSIS
    local dangerLevel = 0
    local targetPos = goalPos + goalForward * standDist
    
    if endpoint then
        -- Determine how dangerous endpoint position is
        local endpointToGoal = (endpoint - goalPos) * Vector3.new(1, 0, 1)
        local endpointDist = endpointToGoal.Magnitude
        
        if endpointDist < CONFIG.PRESSURE_DISTANCE then
            dangerLevel = math.clamp(1 - (endpointDist / CONFIG.PRESSURE_DISTANCE), 0, 1)
            
            -- Determine attack side
            local lateralDist = (endpoint - goalPos):Dot(goalRight)
            local lateralRatio = lateralDist / (moduleState.GoalWidth / 2)
            
            -- Move towards ball side
            local lateralOffset = goalRight * (lateralRatio * moduleState.GoalWidth * 0.4)
            
            -- Adjust depth based on danger
            local depth = standDist * (1 - dangerLevel * 0.5)
            
            targetPos = goalPos + goalForward * depth + lateralOffset
        end
    end
    
    -- 2. CLOSING LOGIC
    if isBallControlled and ownerRoot then
        local enemyPos = ownerRoot.Position
        local enemyToGoal = (enemyPos - goalPos) * Vector3.new(1, 0, 1)
        local enemyDist = enemyToGoal.Magnitude
        
        if enemyDist < CONFIG.AGGRESSION_DISTANCE then
            -- Close in on enemy
            local closeRatio = math.clamp(1 - (enemyDist / CONFIG.AGGRESSION_DISTANCE), 0, 1)
            local closeDistance = standDist + (CONFIG.ATTACK_DISTANCE - standDist) * closeRatio
            
            -- Determine optimal position for angle reduction
            local angleToGoal = math.atan2(enemyPos.X - goalPos.X, enemyPos.Z - goalPos.Z)
            local optimalPos = enemyPos - enemyToGoal.Unit * closeDistance
            
            -- Limit zone
            local maxLateral = moduleState.GoalWidth * 0.4
            local lateral = (optimalPos - goalPos):Dot(goalRight)
            lateral = math.clamp(lateral, -maxLateral, maxLateral)
            
            local depth = (optimalPos - goalPos):Dot(goalForward)
            depth = math.max(depth, standDist * 0.5)
            
            targetPos = goalPos + goalForward * depth + goalRight * lateral
        end
    end
    
    -- 3. ATTACK LOGIC
    if ballVel and ballVel.Magnitude > 15 and not isBallControlled then
        local ballToGoal = (ballPos - goalPos) * Vector3.new(1, 0, 1)
        local ballDist = ballToGoal.Magnitude
        
        if ballDist < CONFIG.PRESS_DISTANCE then
            -- Attack the ball
            local attackRatio = math.clamp(1 - (ballDist / CONFIG.PRESS_DISTANCE), 0, 1)
            local attackDistance = standDist + (CONFIG.ATTACK_DISTANCE - standDist) * attackRatio
            
            -- Predict intercept position
            local timeToGoal = ballDist / ballVel.Magnitude
            local interceptTime = math.min(timeToGoal * 0.7, 1.0)
            local interceptPos = ballPos + ballVel.Unit * (ballVel.Magnitude * interceptTime)
            
            -- Move to intercept point
            local toIntercept = (interceptPos - goalPos) * Vector3.new(1, 0, 1)
            local lateral = (interceptPos - goalPos):Dot(goalRight)
            local maxLateral = moduleState.GoalWidth * 0.35
            lateral = math.clamp(lateral, -maxLateral, maxLateral)
            
            targetPos = goalPos + goalForward * attackDistance + goalRight * lateral
        end
    end
    
    -- 4. ZONE LIMITATION
    local maxLateral = moduleState.GoalWidth * 0.5 * CONFIG.ZONE_WIDTH_MULTIPLIER
    local lateral = (targetPos - goalPos):Dot(goalRight)
    lateral = math.clamp(lateral, -maxLateral, maxLateral)
    
    local maxDepth = CONFIG.ZONE_DEPTH
    local depth = (targetPos - goalPos):Dot(goalForward)
    depth = math.clamp(depth, CONFIG.MIN_DIST, maxDepth)
    
    -- Guarantee minimum distance from goal
    if depth < CONFIG.STAND_DIST * 0.8 then
        depth = CONFIG.STAND_DIST * 0.8
    end
    
    return goalPos + goalForward * depth + goalRight * lateral
end

-- Smart jump logic
local function shouldJump(root, ball, velMag)
    if tick() - moduleState.lastJumpTime < CONFIG.JUMP_COOLDOWN then return false end
    
    local char = root.Parent
    if not char then return false end
    
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    
    local ballPos = ball.Position
    local ballHeight = ballPos.Y
    local rootHeight = root.Position.Y
    
    -- Check only if ball is high
    if ballHeight - rootHeight < CONFIG.JUMP_MIN_HEIGHT_DIFF then return false end
    
    -- Check distance
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.JUMP_RADIUS then return false end
    
    -- Check if ball is coming towards our goal
    if not moduleState.GoalCFrame then return false end
    local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1, 0, 1)
    if ballToGoal.Magnitude > 30 then return false end
    
    -- Predict if we need to jump
    if velMag > CONFIG.JUMP_VEL_THRES then
        local timeToGoal = ballToGoal.Magnitude / velMag
        if timeToGoal < CONFIG.JUMP_PREDICTION_TIME then
            return true
        end
    end
    
    -- Check high balls
    if ballHeight > CONFIG.HIGH_BALL_THRES then
        local ballDir = (ballPos - root.Position).Unit
        local verticalAngle = math.deg(math.asin(ballDir.Y))
        
        if verticalAngle > 20 and distToBall < 20 then
            return true
        end
    end
    
    return false
end

-- Attack/Closing logic
local function updateActionLogic(root, ball, ownerRoot, isBallControlled, ballPos, velMag)
    local currentAction = "IDLE"
    
    if isBallControlled and ownerRoot then
        local enemyDist = (ownerRoot.Position - root.Position).Magnitude
        
        -- ATTACK (if very close)
        if enemyDist < CONFIG.STEAL_DISTANCE then
            currentAction = "ATTACKING"
            moduleState.isAttacking = true
            
        -- CLOSING (if medium distance)
        elseif enemyDist < CONFIG.CLOSE_DISTANCE then
            currentAction = "CLOSING"
            moduleState.isClosing = true
            
        else
            moduleState.isAttacking = false
            moduleState.isClosing = false
        end
        
    elseif velMag > 15 then
        if not moduleState.GoalCFrame then return "IDLE" end
        
        local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1, 0, 1)
        local distToGoal = ballToGoal.Magnitude
        
        -- INTERCEPT (if ball is flying towards goal)
        if distToGoal < CONFIG.INTERCEPT_DISTANCE and velMag > 20 then
            local timeToGoal = distToGoal / velMag
            local timeToReach = (root.Position - ballPos).Magnitude / (CONFIG.AGGRESSIVE_SPEED * CONFIG.INTERCEPT_SPEED_MULT)
            
            if timeToGoal > timeToReach * 1.1 then
                currentAction = "INTERCEPTING"
            end
        end
    end
    
    moduleState.currentAction = currentAction
    return currentAction
end

-- Movement with action consideration
local function smartMovement(root, targetPos, ballPos, currentAction, velMag)
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1, 0, 1)
    if dirVec.Magnitude < CONFIG.MIN_DIST then return end
    
    local speed = CONFIG.SPEED
    
    -- Speed adjustment based on action
    if currentAction == "ATTACKING" then
        speed = CONFIG.AGGRESSIVE_SPEED * 1.2
    elseif currentAction == "CLOSING" then
        speed = CONFIG.SPEED * CONFIG.CLOSE_SPEED_MULT
    elseif currentAction == "INTERCEPTING" then
        speed = CONFIG.AGGRESSIVE_SPEED * CONFIG.INTERCEPT_SPEED_MULT
    elseif velMag > 25 then
        speed = CONFIG.AGGRESSIVE_SPEED
    end
    
    -- Dynamic braking when approaching target
    local distToTarget = dirVec.Magnitude
    if distToTarget < 5 then
        speed = speed * math.clamp(distToTarget / 5, 0.3, 1)
    end
    
    moduleState.currentBV = Instance.new("BodyVelocity")
    moduleState.currentBV.Parent = root
    moduleState.currentBV.MaxForce = Vector3.new(6e5, 0, 6e5)
    moduleState.currentBV.Velocity = dirVec.Unit * speed
    game.Debris:AddItem(moduleState.currentBV, 0.15)
end

-- Improved dive logic
local function shouldDive(root, ball, velMag, endpoint)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving then return false end
    if velMag < CONFIG.DIVE_VEL_THRES then return false end
    
    local ballPos = ball.Position
    local rootPos = root.Position
    
    -- Check if ball is in dive zone
    local distToBall = (rootPos - ballPos).Magnitude
    if distToBall > CONFIG.DIVE_DIST then return false end
    
    if not moduleState.GoalCFrame then return false end
    
    -- Analyze ball direction
    local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1, 0, 1)
    local distToGoalLine = ballToGoal.Magnitude
    
    -- Determine how dangerous the situation is
    if distToGoalLine < 25 then
        local timeToReach = distToBall / CONFIG.AGGRESSIVE_SPEED
        local timeToGoal = distToGoalLine / velMag
        
        -- Dive only if we can make it
        if timeToGoal < timeToReach * 1.3 then
            return true
        end
    end
    
    -- Check endpoint if available
    if endpoint then
        local ballToEndpoint = (endpoint - ballPos).Magnitude
        local timeToEndpoint = ballToEndpoint / velMag
        local timeToReachEndpoint = (endpoint - rootPos).Magnitude / CONFIG.AGGRESSIVE_SPEED
        
        if timeToEndpoint < timeToReachEndpoint * 1.4 then
            return true
        end
    end
    
    return false
end

-- Perform dive with correct rotation
local function performDive(root, hum, targetPos, ball)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving then return end
    
    moduleState.isDiving = true
    moduleState.lastDiveTime = tick()
    
    -- Set correct rotation before dive
    diveRotation(root, targetPos)
    
    -- Determine dive side
    local relativePos = moduleState.GoalCFrame:PointToObjectSpace(targetPos)
    local lateral = relativePos.X
    local dir = lateral > 0 and "Right" or "Left"
    
    -- Send dive request
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir.."dive", root.CFrame)
    end)
    
    local char = hum.Parent
    local animations = ReplicatedStorage:WaitForChild("Animations")
    local gkAnimations = animations.GK
    
    local diveAnim
    local ballHeight = targetPos.Y - root.Position.Y
    
    if dir == "Right" then
        diveAnim = ballHeight <= 10 and 
            hum:LoadAnimation(gkAnimations:WaitForChild("RightLowDive")) or
            hum:LoadAnimation(gkAnimations:WaitForChild("RightDive"))
    else
        diveAnim = ballHeight <= 10 and 
            hum:LoadAnimation(gkAnimations:WaitForChild("LeftLowDive")) or
            hum:LoadAnimation(gkAnimations:WaitForChild("LeftDive"))
    end
    
    if diveAnim then
        diveAnim.Priority = Enum.AnimationPriority.Action4
        diveAnim:Play()
    end
    
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    
    -- Create dive impulse
    local diveBV = Instance.new("BodyVelocity")
    diveBV.Parent = root
    diveBV.MaxForce = Vector3.new(2e7, 2e7, 2e7)
    
    -- Dive direction (slightly forward from goal)
    local diveDirection = (targetPos - root.Position).Unit
    local diveSpeed = moduleState.isBigGoal and 80 or 60
    diveBV.Velocity = diveDirection * diveSpeed
    
    game.Debris:AddItem(diveBV, 0.4)
    
    -- Try to touch the ball
    if ball then
        for _, partName in pairs({"RightHand", "LeftHand", "RightFoot", "LeftFoot"}) do
            local part = char:FindFirstChild(partName)
            if part then
                task.spawn(function()
                    wait(0.1)
                    firetouchinterest(part, ball, 0)
                    wait(0.05)
                    firetouchinterest(part, ball, 1)
                end)
            end
        end
    end
    
    -- Restore state after dive
    task.delay(0.8, function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        moduleState.isDiving = false
    end)
end

-- Function to try blocking the ball
local function tryBlockBall(root, char, ball)
    for _, partName in pairs({"RightHand", "LeftHand", "RightFoot", "LeftFoot", "Torso"}) do
        local part = char:FindFirstChild(partName)
        if part and (part.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
            firetouchinterest(part, ball, 0)
            wait(0.05)
            firetouchinterest(part, ball, 1)
            return true
        end
    end
    return false
end

-- Intercept function
local function performIntercept(root, char, ball)
    if tick() - moduleState.lastInterceptTime < CONFIG.INTERCEPT_COOLDOWN then return end
    
    moduleState.lastInterceptTime = tick()
    
    local interceptPoint = ball.Position + ball.Velocity.Unit * 3
    
    local dirVec = (interceptPoint - root.Position) * Vector3.new(1, 0, 1)
    
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    moduleState.currentBV = Instance.new("BodyVelocity")
    moduleState.currentBV.Parent = root
    moduleState.currentBV.MaxForce = Vector3.new(8e5, 0, 8e5)
    moduleState.currentBV.Velocity = dirVec.Unit * CONFIG.AGGRESSIVE_SPEED * CONFIG.INTERCEPT_SPEED_MULT
    game.Debris:AddItem(moduleState.currentBV, 0.3)
    
    -- Try to touch the ball
    for _, partName in pairs({"RightHand", "LeftHand"}) do
        local part = char:FindFirstChild(partName)
        if part and (part.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
            firetouchinterest(part, ball, 0)
            wait(0.05)
            firetouchinterest(part, ball, 1)
            break
        end
    end
end

-- Jump function
local function performJump(char, hum)
    if tick() - moduleState.lastJumpTime < CONFIG.JUMP_COOLDOWN then return false end
    
    moduleState.lastJumpTime = tick()
    
    local root = char.HumanoidRootPart
    
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer("GKJump", root.CFrame)
    end)
    
    local animations = ReplicatedStorage:WaitForChild("Animations")
    local gkAnimations = animations.GK
    
    local anim = hum:LoadAnimation(gkAnimations:WaitForChild("Jump"))
    anim.Priority = Enum.AnimationPriority.Action4
    anim:Play()
    
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    
    return true
end

-- ==================== MAIN LOOPS ====================

local function startRenderLoop()
    if moduleState.renderConnection then
        moduleState.renderConnection:Disconnect()
    end
    
    moduleState.renderConnection = rs.RenderStepped:Connect(function(dt)
        if not moduleState.enabled then return end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then return end
        
        local root = char.HumanoidRootPart
        local hum = char.Humanoid
        local ball = ws:FindFirstChild("ball")
        
        if not ball then
            hideAllVisuals()
            return
        end
        
        if not UpdateGoal() then 
            hideAllVisuals()
            return 
        end
        
        local hasWeld = ball:FindFirstChild("playerWeld")
        local owner = ball:FindFirstChild("creator") and ball.creator.Value
        local isMyBall = owner == player
        local oRoot = owner and owner ~= player and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
        
        local velMag = ball.Velocity.Magnitude
        local ballPos = ball.Position
        
        -- Update trajectory prediction
        local shouldPredict = not isMyBall and not hasWeld
        if shouldPredict and (moduleState.frameCounter % CONFIG.PRED_UPDATE_RATE == 0 or not moduleState.cachedPoints) then
            moduleState.cachedPoints = predictTrajectory(ball)
        elseif not shouldPredict then
            moduleState.cachedPoints = nil
        end
        
        local endpoint = moduleState.cachedPoints and moduleState.cachedPoints[#moduleState.cachedPoints]
        
        if not isMyBall and not moduleState.isDiving then
            -- Determine current action
            local currentAction = updateActionLogic(root, ball, oRoot, hasWeld and owner ~= player, ballPos, velMag)
            
            -- Calculate target position
            local targetPos = calculateSmartPosition(ballPos, oRoot, hasWeld and owner ~= player, endpoint, ball.Velocity)
            
            -- Move to position
            smartMovement(root, targetPos, ballPos, currentAction, velMag)
            
            -- Apply rotation (if not performing special action)
            if not moduleState.willJump then
                smartRotation(root, ballPos, ball.Velocity, false, nil, isMyBall, false)
            end
            
            -- Check for jump necessity
            moduleState.willJump = shouldJump(root, ball, velMag)
            
            -- Execute actions
            if moduleState.willJump then
                performJump(char, hum)
                moduleState.willJump = false
                
            elseif shouldDive(root, ball, velMag, endpoint) then
                performDive(root, hum, endpoint or ballPos, ball)
                
            elseif currentAction == "INTERCEPTING" then
                performIntercept(root, char, ball)
            end
            
            -- Check for blocking possibility
            if (root.Position - ballPos).Magnitude < CONFIG.NEAR_BALL_DIST then
                tryBlockBall(root, char, ball)
            end
            
        else
            -- If ball is ours, just track it
            if moduleState.currentBV then 
                pcall(function() moduleState.currentBV:Destroy() end) 
                moduleState.currentBV = nil 
            end
            
            if not moduleState.isDiving then
                smartRotation(root, ballPos, ball.Velocity, false, nil, true, false)
            end
        end
        
        moduleState.frameCounter = moduleState.frameCounter + 1
    end)
end

local function startHeartbeat()
    if moduleState.heartbeatConnection then
        moduleState.heartbeatConnection:Disconnect()
    end
    
    moduleState.heartbeatConnection = rs.Heartbeat:Connect(function()
        if not moduleState.enabled then 
            hideAllVisuals()
            return 
        end
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local ball = ws:FindFirstChild("ball")
        if not ball then
            hideAllVisuals()
            return
        end
        
        if not UpdateGoal() then 
            hideAllVisuals()
            return 
        end
        
        -- Visualization
        if CONFIG.SHOW_GOAL_CUBE and moduleState.visualObjects.GoalCube then
            drawCube(moduleState.visualObjects.GoalCube, moduleState.GoalCFrame, Vector3.new(moduleState.GoalWidth, 8, 2), CONFIG.GOAL_CUBE_COLOR)
        end
        
        if CONFIG.SHOW_ZONE then 
            drawFlatZone() 
        end
        
        local root = char.HumanoidRootPart
        local distBall = (root.Position - ball.Position).Magnitude
        
        if CONFIG.SHOW_TRAJECTORY and moduleState.cachedPoints and moduleState.visualObjects.trajLines then
            local cam = ws.CurrentCamera
            for i = 1, math.min(CONFIG.PRED_STEPS, #moduleState.cachedPoints - 1) do
                local p1 = cam:WorldToViewportPoint(moduleState.cachedPoints[i])
                local p2 = cam:WorldToViewportPoint(moduleState.cachedPoints[i + 1])
                local l = moduleState.visualObjects.trajLines[i]
                if l then
                    l.From = Vector2.new(p1.X, p1.Y)
                    l.To = Vector2.new(p2.X, p2.Y)
                    l.Visible = p1.Z > 0 and p2.Z > 0 and distBall < 100
                end
            end
            
            -- Draw endpoint circle
            if CONFIG.SHOW_ENDPOINT and moduleState.cachedPoints[#moduleState.cachedPoints] then
                drawEndpoint(moduleState.cachedPoints[#moduleState.cachedPoints])
            end
        else
            clearTrajAndEndpoint()
        end
        
        if CONFIG.SHOW_BALL_BOX and distBall < 80 and moduleState.visualObjects.BallBox then 
            local col
            if moduleState.willJump then
                col = CONFIG.BALL_BOX_JUMP_COLOR
            elseif moduleState.cachedPoints then
                col = CONFIG.BALL_BOX_COLOR
            else
                col = CONFIG.BALL_BOX_SAFE_COLOR
            end
            drawCube(moduleState.visualObjects.BallBox, CFrame.new(ball.Position), Vector3.new(3.5, 3.5, 3.5), col)
        elseif moduleState.visualObjects.BallBox then
            drawCube(moduleState.visualObjects.BallBox, nil) 
        end
    end)
end

-- Cleanup
local function cleanup()
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    if moduleState.heartbeatConnection then
        moduleState.heartbeatConnection:Disconnect()
        moduleState.heartbeatConnection = nil
    end
    
    if moduleState.renderConnection then
        moduleState.renderConnection:Disconnect()
        moduleState.renderConnection = nil
    end
    
    if moduleState.inputConnection then
        moduleState.inputConnection:Disconnect()
        moduleState.inputConnection = nil
    end
    
    hideAllVisuals()
    moduleState.isDiving = false
    moduleState.isAttacking = false
    moduleState.isClosing = false
    moduleState.currentAction = "IDLE"
    moduleState.cachedPoints = nil
    moduleState.willJump = false
end

-- ==================== MODULE INITIALIZATION ====================

local AutoGKUltraModule = {}

function AutoGKUltraModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
    moduleState.notify = notifyFunc
    
    if UI.Sections.AutoGoalKeeper then
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalkeeper ULTRA" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "Enhanced Goalkeeper AI",
            Body = [[
ULTRA VERSION - COMPLETELY REWRITTEN:

1. SMART ROTATION:
   - Y-axis rotation only (no upward tilt)
   - Intelligent ball tracking
   - Correct dive rotation
   - Speed adaptation

2. IMPROVED DIVE:
   - Ball touches us, doesn't fly into goal
   - Correct dive direction
   - Goal size consideration

3. INTELLIGENT JUMP:
   - Determines when to jump
   - Considers ball height
   - Analyzes trajectory

4. ADAPTIVE LOGIC:
   - Smart positioning
   - Automatic closing
   - Intelligent attack
   - Dynamic interception

5. DYNAMIC POSITIONING:
   - Doesn't stay on one spot
   - Occupies advantageous positions
   - Reduces opponent's shooting angle
]]
        })
        
        moduleState.uiElements.Enabled = UI.Sections.AutoGoalKeeper:Toggle({ 
            Name = "Enabled", 
            Default = CONFIG.ENABLED, 
            Callback = function(v) 
                CONFIG.ENABLED = v
                moduleState.enabled = v
                if v then
                    createVisuals()
                    startRenderLoop()
                    startHeartbeat()
                    notifyFunc("Syllinse", "AutoGK Ultra Enabled", true)
                else
                    cleanup()
                    notifyFunc("Syllinse", "AutoGK Ultra Disabled", true)
                end
            end
        }, 'AutoGKUltraEnabled')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Approach & Attack Settings" })
        
        moduleState.uiElements.CLOSE_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Close Distance",
            Minimum = 5,
            Maximum = 30,
            Default = CONFIG.CLOSE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.CLOSE_DISTANCE = v end
        }, 'AutoGKUltraCloseDist')
        
        moduleState.uiElements.ATTACK_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Distance",
            Minimum = 3,
            Maximum = 15,
            Default = CONFIG.ATTACK_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_DISTANCE = v end
        }, 'AutoGKUltraAttackDist')
        
        moduleState.uiElements.CLOSE_SPEED_MULT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Close Speed Multiplier",
            Minimum = 1.0,
            Maximum = 2.0,
            Default = CONFIG.CLOSE_SPEED_MULT,
            Precision = 2,
            Callback = function(v) CONFIG.CLOSE_SPEED_MULT = v end
        }, 'AutoGKUltraCloseSpeedMult')
        
        moduleState.uiElements.AGGRESSION_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Aggression Distance",
            Minimum = 15,
            Maximum = 40,
            Default = CONFIG.AGGRESSION_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.AGGRESSION_DISTANCE = v end
        }, 'AutoGKUltraAggressionDist')
        
        moduleState.uiElements.STEAL_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Steal Distance",
            Minimum = 3,
            Maximum = 8,
            Default = CONFIG.STEAL_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.STEAL_DISTANCE = v end
        }, 'AutoGKUltraStealDist')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Movement Settings" })
        
        moduleState.uiElements.SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Normal Speed",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.SPEED = v end
        }, 'AutoGKUltraSpeed')
        
        moduleState.uiElements.AGGRESSIVE_SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Aggressive Speed",
            Minimum = 25,
            Maximum = 60,
            Default = CONFIG.AGGRESSIVE_SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.AGGRESSIVE_SPEED = v end
        }, 'AutoGKUltraAggressiveSpeed')
        
        moduleState.uiElements.STAND_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Stand Distance",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = CONFIG.STAND_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.STAND_DIST = v end
        }, 'AutoGKUltraStandDist')
        
        moduleState.uiElements.MIN_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Min Distance",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = CONFIG.MIN_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.MIN_DIST = v end
        }, 'AutoGKUltraMinDist')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Smart Rotation Settings" })
        
        moduleState.uiElements.SMART_ROTATION_SMOOTH = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Rotation Smoothness",
            Minimum = 0.05,
            Maximum = 0.3,
            Default = CONFIG.SMART_ROTATION_SMOOTH,
            Precision = 2,
            Callback = function(v) CONFIG.SMART_ROTATION_SMOOTH = v end
        }, 'AutoGKUltraSmartRotSmooth')
        
        moduleState.uiElements.MAX_ROTATION_ANGLE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Max Rotation Angle",
            Minimum = 30,
            Maximum = 90,
            Default = CONFIG.MAX_ROTATION_ANGLE,
            Precision = 1,
            Callback = function(v) CONFIG.MAX_ROTATION_ANGLE = v end
        }, 'AutoGKUltraMaxRotAngle')
        
        moduleState.uiElements.PREDICTION_LOOK_AHEAD = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Prediction Look Ahead",
            Minimum = 1,
            Maximum = 10,
            Default = CONFIG.PREDICTION_LOOK_AHEAD,
            Precision = 1,
            Callback = function(v) CONFIG.PREDICTION_LOOK_AHEAD = v end
        }, 'AutoGKUltraPredictionLookAhead')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Dive Settings" })
        
        moduleState.uiElements.DIVE_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Distance",
            Minimum = 15,
            Maximum = 40,
            Default = CONFIG.DIVE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_DIST = v end
        }, 'AutoGKUltraDiveDist')
        
        moduleState.uiElements.DIVE_VEL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Velocity Threshold",
            Minimum = 15,
            Maximum = 40,
            Default = CONFIG.DIVE_VEL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_VEL_THRES = v end
        }, 'AutoGKUltraDiveVelThres')
        
        moduleState.uiElements.DIVE_COOLDOWN = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Cooldown",
            Minimum = 0.5,
            Maximum = 2.0,
            Default = CONFIG.DIVE_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_COOLDOWN = v end
        }, 'AutoGKUltraDiveCD')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Jump Settings" })
        
        moduleState.uiElements.JUMP_VEL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Velocity Threshold",
            Minimum = 15,
            Maximum = 40,
            Default = CONFIG.JUMP_VEL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_VEL_THRES = v end
        }, 'AutoGKUltraJumpVelThres')
        
        moduleState.uiElements.JUMP_COOLDOWN = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Cooldown",
            Minimum = 0.3,
            Maximum = 1.5,
            Default = CONFIG.JUMP_COOLDOWN,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_COOLDOWN = v end
        }, 'AutoGKUltraJumpCD')
        
        moduleState.uiElements.JUMP_RADIUS = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Radius",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.JUMP_RADIUS,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_RADIUS = v end
        }, 'AutoGKUltraJumpRadius')
        
        moduleState.uiElements.JUMP_MIN_HEIGHT_DIFF = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Min Height Difference",
            Minimum = 0.1,
            Maximum = 3.0,
            Default = CONFIG.JUMP_MIN_HEIGHT_DIFF,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_MIN_HEIGHT_DIFF = v end
        }, 'AutoGKUltraJumpMinHeightDiff')
        
        moduleState.uiElements.HIGH_BALL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "High Ball Threshold",
            Minimum = 5,
            Maximum = 15,
            Default = CONFIG.HIGH_BALL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.HIGH_BALL_THRES = v end
        }, 'AutoGKUltraHighBallThres')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Intercept & Touch Settings" })
        
        moduleState.uiElements.INTERCEPT_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Intercept Distance",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.INTERCEPT_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.INTERCEPT_DISTANCE = v end
        }, 'AutoGKUltraInterceptDist')
        
        moduleState.uiElements.INTERCEPT_SPEED_MULT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Intercept Speed Multiplier",
            Minimum = 1.0,
            Maximum = 2.0,
            Default = CONFIG.INTERCEPT_SPEED_MULT,
            Precision = 2,
            Callback = function(v) CONFIG.INTERCEPT_SPEED_MULT = v end
        }, 'AutoGKUltraInterceptSpeedMult')
        
        moduleState.uiElements.TOUCH_RANGE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Touch Range",
            Minimum = 5,
            Maximum = 30,
            Default = CONFIG.TOUCH_RANGE,
            Precision = 1,
            Callback = function(v) CONFIG.TOUCH_RANGE = v end
        }, 'AutoGKUltraTouchRange')
        
        moduleState.uiElements.NEAR_BALL_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Near Ball Distance",
            Minimum = 2,
            Maximum = 10,
            Default = CONFIG.NEAR_BALL_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.NEAR_BALL_DIST = v end
        }, 'AutoGKUltraNearBallDist')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Defense Zone Settings" })
        
        moduleState.uiElements.ZONE_WIDTH_MULTIPLIER = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Width Multiplier",
            Minimum = 1.0,
            Maximum = 4.0,
            Default = CONFIG.ZONE_WIDTH_MULTIPLIER,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_WIDTH_MULTIPLIER = v end
        }, 'AutoGKUltraZoneWidthMult')
        
        moduleState.uiElements.ZONE_DEPTH = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Depth",
            Minimum = 30,
            Maximum = 80,
            Default = CONFIG.ZONE_DEPTH,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_DEPTH = v end
        }, 'AutoGKUltraZoneDepth')
        
        moduleState.uiElements.ZONE_OFFSET = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Offset",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.ZONE_OFFSET,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_OFFSET = v end
        }, 'AutoGKUltraZoneOffset')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Visual Settings" })
        
        moduleState.uiElements.SHOW_TRAJECTORY = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Trajectory",
            Default = CONFIG.SHOW_TRAJECTORY,
            Callback = function(v) 
                CONFIG.SHOW_TRAJECTORY = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        }, 'AutoGKUltraShowTrajectory')
        
        moduleState.uiElements.SHOW_ENDPOINT = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Endpoint",
            Default = CONFIG.SHOW_ENDPOINT,
            Callback = function(v) 
                CONFIG.SHOW_ENDPOINT = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        }, 'AutoGKUltraShowEndpoint')
        
        moduleState.uiElements.SHOW_GOAL_CUBE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Goal Cube",
            Default = CONFIG.SHOW_GOAL_CUBE,
            Callback = function(v) 
                CONFIG.SHOW_GOAL_CUBE = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        }, 'AutoGKUltraShowGoalCube')
        
        moduleState.uiElements.SHOW_ZONE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Defense Zone",
            Default = CONFIG.SHOW_ZONE,
            Callback = function(v) 
                CONFIG.SHOW_ZONE = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        }, 'AutoGKUltraShowZone')
        
        moduleState.uiElements.SHOW_BALL_BOX = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Ball Box",
            Default = CONFIG.SHOW_BALL_BOX,
            Callback = function(v) 
                CONFIG.SHOW_BALL_BOX = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        }, 'AutoGKUltraShowBallBox')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Color Settings" })
        
        moduleState.uiElements.TRAJECTORY_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Trajectory Color",
            Default = CONFIG.TRAJECTORY_COLOR,
            Callback = function(v) 
                CONFIG.TRAJECTORY_COLOR = v
                if moduleState.enabled and moduleState.visualObjects.trajLines then
                    local baseH, baseS, baseV = v:ToHSV()
                    for i, line in ipairs(moduleState.visualObjects.trajLines) do
                        if line then
                            local hue = (baseH + (i / CONFIG.PRED_STEPS) * 0.3) % 1
                            line.Color = Color3.fromHSV(hue, baseS, baseV)
                        end
                    end
                end
            end
        }, 'AutoGKUltraTrajectoryColor')
        
        moduleState.uiElements.ENDPOINT_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Endpoint Color",
            Default = CONFIG.ENDPOINT_COLOR,
            Callback = function(v) 
                CONFIG.ENDPOINT_COLOR = v
                if moduleState.enabled and moduleState.visualObjects.endpointLines then
                    for _, line in ipairs(moduleState.visualObjects.endpointLines) do
                        if line then
                            line.Color = v
                        end
                    end
                end
            end
        }, 'AutoGKUltraEndpointColor')
        
        moduleState.uiElements.GOAL_CUBE_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Goal Cube Color",
            Default = CONFIG.GOAL_CUBE_COLOR,
            Callback = function(v) 
                CONFIG.GOAL_CUBE_COLOR = v
                if moduleState.enabled and moduleState.visualObjects.GoalCube then
                    for _, line in ipairs(moduleState.visualObjects.GoalCube) do
                        if line then
                            line.Color = v
                        end
                    end
                end
            end
        }, 'AutoGKUltraGoalCubeColor')
        
        moduleState.uiElements.ZONE_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Zone Color",
            Default = CONFIG.ZONE_COLOR,
            Callback = function(v) 
                CONFIG.ZONE_COLOR = v
                if moduleState.enabled and moduleState.visualObjects.LimitCube then
                    for _, line in ipairs(moduleState.visualObjects.LimitCube) do
                        if line then
                            line.Color = v
                        end
                    end
                end
            end
        }, 'AutoGKUltraZoneColor')
        
        moduleState.uiElements.BALL_BOX_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box Color",
            Default = CONFIG.BALL_BOX_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_COLOR = v
            end
        }, 'AutoGKUltraBallBoxColor')
        
        moduleState.uiElements.BALL_BOX_JUMP_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box Jump Color",
            Default = CONFIG.BALL_BOX_JUMP_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_JUMP_COLOR = v
            end
        }, 'AutoGKUltraBallBoxJumpColor')
        
        moduleState.uiElements.BALL_BOX_SAFE_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box Safe Color",
            Default = CONFIG.BALL_BOX_SAFE_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_SAFE_COLOR = v
            end
        }, 'AutoGKUltraBallBoxSafeColor')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Physics Settings" })
        
        moduleState.uiElements.PRED_STEPS = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Prediction Steps",
            Minimum = 40,
            Maximum = 120,
            Default = CONFIG.PRED_STEPS,
            Precision = 1,
            Callback = function(v) CONFIG.PRED_STEPS = v end
        }, 'AutoGKUltraPredSteps')
        
        moduleState.uiElements.CURVE_MULT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Curve Multiplier",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.CURVE_MULT,
            Precision = 1,
            Callback = function(v) CONFIG.CURVE_MULT = v end
        }, 'AutoGKUltraCurveMult')
        
        moduleState.uiElements.GRAVITY = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Gravity",
            Minimum = 90,
            Maximum = 130,
            Default = CONFIG.GRAVITY,
            Precision = 1,
            Callback = function(v) CONFIG.GRAVITY = v end
        }, 'AutoGKUltraGravity')
        
        moduleState.uiElements.PRED_UPDATE_RATE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Prediction Update Rate",
            Minimum = 1,
            Maximum = 10,
            Default = CONFIG.PRED_UPDATE_RATE,
            Precision = 1,
            Callback = function(v) CONFIG.PRED_UPDATE_RATE = v end
        }, 'AutoGKUltraPredUpdateRate')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Goal Size Settings" })
        
        moduleState.uiElements.BIG_GOAL_THRESHOLD = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Big Goal Threshold",
            Minimum = 30,
            Maximum = 60,
            Default = CONFIG.BIG_GOAL_THRESHOLD,
            Precision = 1,
            Callback = function(v) CONFIG.BIG_GOAL_THRESHOLD = v end
        }, 'AutoGKUltraBigGoalThreshold')
        
        moduleState.uiElements.BIG_GOAL_STAND_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Big Goal Stand Distance",
            Minimum = 3.0,
            Maximum = 6.0,
            Default = CONFIG.BIG_GOAL_STAND_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.BIG_GOAL_STAND_DIST = v end
        }, 'AutoGKUltraBigGoalStandDist')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Advanced Settings" })
        
        moduleState.uiElements.PRESS_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Press Distance",
            Minimum = 30,
            Maximum = 80,
            Default = CONFIG.PRESS_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.PRESS_DISTANCE = v end
        }, 'AutoGKUltraPressDistance')
        
        moduleState.uiElements.PRESSURE_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Pressure Distance",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.PRESSURE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.PRESSURE_DISTANCE = v end
        }, 'AutoGKUltraPressureDistance')
        
        moduleState.uiElements.ANGLING_FACTOR = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Angling Factor",
            Minimum = 0.3,
            Maximum = 0.9,
            Default = CONFIG.ANGLING_FACTOR,
            Precision = 2,
            Callback = function(v) CONFIG.ANGLING_FACTOR = v end
        }, 'AutoGKUltraAnglingFactor')
        
    end
    
    if UI.Tabs.Config then
        local syncSection = UI.Tabs.Config:Section({Name = 'AutoGK Sync', Side = 'Right'})
        
        syncSection:Header({ Name = "AutoGK Ultra Config Sync" })
        
        syncSection:Button({
            Name = "Sync Configuration Now",
            Callback = function()
                CONFIG.ENABLED = moduleState.uiElements.Enabled and moduleState.uiElements.Enabled:GetState()
                
                moduleState.enabled = CONFIG.ENABLED
                
                if CONFIG.ENABLED then
                    createVisuals()
                    startRenderLoop()
                    startHeartbeat()
                    
                    if not moduleState.inputConnection then
                        moduleState.inputConnection = uis.InputBegan:Connect(function(inp)
                            if inp.KeyCode == Enum.KeyCode.Insert then
                                moduleState.enabled = not moduleState.enabled
                                CONFIG.ENABLED = moduleState.enabled
                                
                                if moduleState.uiElements.Enabled then
                                    moduleState.uiElements.Enabled:SetState(moduleState.enabled)
                                end
                                
                                if not moduleState.enabled then
                                    cleanup()
                                else
                                    createVisuals()
                                    startRenderLoop()
                                    startHeartbeat()
                                end
                                
                                if notifyFunc then
                                    notifyFunc("AutoGK Ultra", moduleState.enabled and "ON" or "OFF", true)
                                end
                            end
                        end)
                    end
                    
                else
                    cleanup()
                end
                
                notifyFunc("AutoGK Ultra", "Configuration synchronized", true)
            end
        })
    end
end

function AutoGKUltraModule:Destroy()
    cleanup()
    moduleState.enabled = false
    CONFIG.ENABLED = false
end

return AutoGKUltraModule
