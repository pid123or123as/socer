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

local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local tweenInfoFast = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

-- Конфигурация
local CONFIG = {
    ENABLED = false,
    
    -- Основные настройки
    SPEED = 32,
    AGGRESSIVE_SPEED = 38,
    STAND_DIST = 2.8,
    MIN_DIST = 0.8,
    
    -- Физика предсказания
    PRED_STEPS = 80,
    CURVE_MULT = 42,
    DT = 1/120,
    GRAVITY = 108,
    DRAG = 0.984,
    BOUNCE_XZ = 0.74,
    BOUNCE_Y = 0.72,
    
    -- Дистанции
    AGGRO_THRES = 55,
    PRESSURE_DIST = 44,
    DIVE_DIST = 26,
    TOUCH_RANGE = 20,
    NEAR_BALL_DIST = 5.0,
    CORNER_DEFENSE_DIST = 18,
    
    -- Пороги
    DIVE_VEL_THRES = 24,
    JUMP_VEL_THRES = 28,
    HIGH_BALL_THRES = 5.8,
    JUMP_THRES = 4.5,
    
    -- Кулдауны
    DIVE_COOLDOWN = 1.1,
    JUMP_COOLDOWN = 0.8,
    
    -- Производительность
    PRED_UPDATE_RATE = 1,
    ROT_SMOOTH = 0.82,
    USE_SMOOTH_ROTATION = true,
    
    -- Размер ворот
    BIG_GOAL_THRESHOLD = 40,
    
    -- Перехват
    INTERCEPT_DISTANCE = 35,
    INTERCEPT_SPEED_MULT = 1.34,
    INTERCEPT_PREDICT_TIME = 0.15,
    
    -- Прыжки
    JUMP_CHECK_HEIGHT = 0.6,
    JUMP_PREDICTION_STEPS = 30,
    JUMP_REACTION_TIME = 0.15,
    JUMP_VERTICAL_THRESHOLD = 0.1,
    GOAL_JUMP_SAFETY_MARGIN = 0.6,
    JUMP_RADIUS = 40,
    JUMP_MIN_HEIGHT_DIFF = 0.7,
    JUMP_POWER = 32,
    JUMP_HEIGHT = 6,
    
    JUMP_HORIZONTAL_FORCE = 70,
    SMALL_GOAL_DIVE_DISTANCE = 5,
    BIG_GOAL_DIVE_DISTANCE = 10,
    DIVE_DURATION = 0.44,
    DIVE_SPEED = 38,
    
    -- Зона защиты
    ZONE_WIDTH_MULTIPLIER = 2.5,
    ZONE_DEPTH = 56,
    ZONE_HEIGHT = 0.2,
    ZONE_OFFSET_MULTIPLIER = 35,
    
    -- Визуальные настройки
    SHOW_TRAJECTORY = true,
    SHOW_ENDPOINT = true,
    SHOW_GOAL_CUBE = true,
    SHOW_ZONE = true,
    SHOW_BALL_BOX = true,
    
    -- Цвета
    TRAJECTORY_COLOR = Color3.fromHSV(0.5, 1, 1),
    ENDPOINT_COLOR = Color3.new(1, 1, 0),
    GOAL_CUBE_COLOR = Color3.new(1, 0, 0),
    ZONE_COLOR = Color3.new(0, 1, 0),
    BALL_BOX_COLOR = Color3.new(0, 0.8, 1),
    BALL_BOX_JUMP_COLOR = Color3.new(1, 0, 1),
    BALL_BOX_SAFE_COLOR = Color3.new(0, 1, 0),
    BALL_BOX_THREAT_COLOR = Color3.new(1, 0, 0),
    BALL_BOX_HIGH_COLOR = Color3.new(1, 1, 0),
    
    -- Улучшенное позиционирование
    GATE_COVERAGE = 1.02,
    CENTER_BIAS_DIST = 18,
    LATERAL_MAX_MULT = 0.48,
    AVOID_CORNERS = true,
    CORNER_AVOID_DISTANCE = 2.0,
    REACTION_TIME = 0.15,
    ANTICIPATION_DIST = 1.5,
    
    -- Улучшенный перехват
    BALL_INTERCEPT_RANGE = 4.0,
    MIN_INTERCEPT_TIME = 0.08,
    ADVANCE_DISTANCE = 3.2,
    DIVE_LOOK_AHEAD = 0.18,
    
    -- Угловые атаки
    CORNER_DEFENSE_ENABLED = true,
    CORNER_DEFENSE_LATERAL = 0.7,
    CORNER_DEFENSE_FORWARD = 1.2,
    
    -- Ротация
    SMART_ROTATION_ENABLED = true,
    MIN_ROTATION_DIST = 8.0,
    MAX_ROTATION_ANGLE = 45,
    DIVE_ROTATION_OFFSET = 15
}

-- Состояние модуля
local moduleState = {
    enabled = false,
    lastDiveTime = 0,
    lastJumpTime = 0,
    isDiving = false,
    isJumping = false,
    endpointRadius = 3.5,
    frameCounter = 0,
    cachedPoints = nil,
    cachedPointsTime = 0,
    lastBallVelMag = 0,
    currentBV = nil,
    currentGyro = nil,
    smoothCFrame = nil,
    lastActionTime = 0,
    actionCooldown = 0.06,
    isBigGoal = false,
    lastInterceptTime = 0,
    interceptCooldown = 0.3,
    diveAnimationPlaying = false,
    jumpAnimationPlaying = false,
    willJump = false,
    lastTouchTime = 0,
    isGoalkeeper = false,
    lastGoalkeeperCheck = 0,
    
    -- Визуальные объекты
    visualObjects = {},
    
    -- Цели
    GoalCFrame = nil,
    GoalForward = nil,
    GoalRight = nil,
    GoalWidth = 0,
    GoalPosts = {},
    
    -- Улучшенное отслеживание
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
    
    -- UI элементы
    uiElements = {},
    
    -- Подписки
    heartbeatConnection = nil,
    renderConnection = nil,
    inputConnection = nil
}

-- Создание визуальных объектов
local function createVisuals()
    -- Очистка старых объектов
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
    
    -- Куб ворот
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
    
    -- Зона защиты
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
    
    -- Бокс мяча
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
    
    -- Траектория
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
    
    -- Конечная точка
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
    
    -- Текст отладки
    moduleState.visualObjects.debugText = Drawing.new("Text")
    moduleState.visualObjects.debugText.Visible = false
    moduleState.visualObjects.debugText.Size = 18
    moduleState.visualObjects.debugText.Color = Color3.new(1, 1, 1)
    moduleState.visualObjects.debugText.Outline = true
    moduleState.visualObjects.debugText.OutlineColor = Color3.new(0, 0, 0)
    moduleState.visualObjects.debugText.Position = Vector2.new(10, 10)
end

-- Очистка визуализации
local function clearAllVisuals()
    for _, objList in pairs(moduleState.visualObjects) do
        if type(objList) == "table" then
            for _, drawing in pairs(objList) do
                if drawing then
                    pcall(function()
                        drawing.Visible = false
                        if drawing.Remove then
                            drawing:Remove()
                        end
                    end)
                end
            end
        end
    end
    moduleState.visualObjects = {}
end

-- Скрытие визуализации
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

-- Проверка вратаря
local function checkIfGoalkeeper()
    if tick() - moduleState.lastGoalkeeperCheck < 0.5 then 
        return moduleState.isGoalkeeper 
    end
    
    moduleState.lastGoalkeeperCheck = tick()
    local isHPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("HPG") and ws.Bools.HPG.Value == player
    local isAPG = ws:FindFirstChild("Bools") and ws.Bools:FindFirstChild("APG") and ws.Bools.APG.Value == player
    
    moduleState.isGoalkeeper = isHPG or isAPG
    return moduleState.isGoalkeeper
end

-- Обновление целей
local function updateGoals()
    if not checkIfGoalkeeper() then return false end
    
    local isHPG = ws.Bools.HPG.Value == player
    local isAPG = ws.Bools.APG.Value == player
    
    local posModelName = isHPG and "HomePosition" or "AwayPosition"
    local posModel = ws:FindFirstChild(posModelName)
    if not posModel then return false end
    
    local parts = {}
    for _, obj in posModel:GetDescendants() do 
        if obj:IsA("BasePart") then 
            table.insert(parts, obj) 
        end 
    end
    if #parts == 0 then return false end
    
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
            moduleState.GoalRight = rightDir
            
            local fieldDir = center - gcenter
            fieldDir = fieldDir - fieldDir:Dot(rightDir) * rightDir  
            fieldDir = Vector3.new(fieldDir.X, 0, fieldDir.Z)
            
            local fwdMag = fieldDir.Magnitude
            if fwdMag > 0.1 then
                moduleState.GoalForward = fieldDir.Unit
            else
                moduleState.GoalForward = rightDir:Cross(Vector3.new(0, 1, 0)).Unit
            end
            
            local minDist, maxDist = math.huge, -math.huge
            for _, part in ipairs(parts) do
                local rel = part.Position - gcenter  
                local dist = rel:Dot(moduleState.GoalForward)
                minDist = math.min(minDist, dist)
                maxDist = math.max(maxDist, dist)
            end
            
            if maxDist - minDist < 10 or maxDist < 10 then
                moduleState.GoalForward = -moduleState.GoalForward
                minDist, maxDist = math.huge, -math.huge
                for _, part in ipairs(parts) do
                    local rel = part.Position - gcenter
                    dist = rel:Dot(moduleState.GoalForward)
                    minDist = math.min(minDist, dist)
                    maxDist = math.max(maxDist, dist)
                end
            end
            
            moduleState.GoalCFrame = CFrame.fromMatrix(gcenter, rightDir, Vector3.new(0, 1, 0), -moduleState.GoalForward)
            moduleState.GoalWidth = (right.Position - left.Position).Magnitude
            
            moduleState.isBigGoal = moduleState.GoalWidth > CONFIG.BIG_GOAL_THRESHOLD
            
            if moduleState.visualObjects.debugText then
                moduleState.visualObjects.debugText.Visible = true
                moduleState.visualObjects.debugText.Text = string.format("Goal Width: %.1f | Big Goal: %s", moduleState.GoalWidth, moduleState.isBigGoal and "YES" or "NO")
            end
            
            return true
        end
    end
    return false
end

-- Проверка столкновения с воротами
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

-- Улучшенное предсказание траектории с закруткой
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
            spinCurve = spinCurve + Vector3.new(0, 26, 0) 
        end
    end)
    
    for i = 1, steps do
        local curveFade = 1 - (i/steps) * 0.5
        vel = vel * drag + spinCurve * dt * curveFade
        vel = vel - Vector3.new(0, gravity * dt * 1.02, 0)
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
            vel = Vector3.new(vel.X * CONFIG.BOUNCE_XZ, math.abs(vel.Y) * CONFIG.BOUNCE_Y, vel.Z * CONFIG.BOUNCE_XZ)
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

-- Отрисовка куба
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

-- Отрисовка зоны
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
        drawCube(moduleState.visualObjects.LimitCube, flatCF, 
            Vector3.new(moduleState.GoalWidth * CONFIG.ZONE_WIDTH_MULTIPLIER, CONFIG.ZONE_HEIGHT, CONFIG.ZONE_DEPTH), 
            CONFIG.ZONE_COLOR)
    end
end

-- Отрисовка конечной точки
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

-- Очистка траектории и точки
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

-- Улучшенная умная ротация
local function smartRotation(root, ballPos, ballVel, isDiving, diveTarget, isMyBall, isThreat)
    if isMyBall or not CONFIG.SMART_ROTATION_ENABLED then 
        if moduleState.currentGyro then 
            pcall(function() moduleState.currentGyro:Destroy() end) 
            moduleState.currentGyro = nil 
        end
        return 
    end
    
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall < CONFIG.MIN_ROTATION_DIST then
        if moduleState.currentGyro then 
            pcall(function() moduleState.currentGyro:Destroy() end) 
            moduleState.currentGyro = nil 
        end
        return
    end
    
    if not moduleState.smoothCFrame then 
        moduleState.smoothCFrame = root.CFrame 
    end
    
    local targetLookPos = ballPos
    
    if isDiving and diveTarget then
        -- При нырке смотрим в сторону от ворот
        local toGoal = (moduleState.GoalCFrame.Position - root.Position).Unit
        local diveDir = (diveTarget - root.Position).Unit
        local angle = math.deg(math.acos(diveDir:Dot(toGoal)))
        
        if angle < CONFIG.MAX_ROTATION_ANGLE then
            targetLookPos = root.Position - toGoal * 10
        else
            targetLookPos = diveTarget
        end
    elseif isThreat and ballVel.Magnitude > 20 then
        -- При угрозе смотрим на мяч, но не прямо в ворота
        local toGoal = (moduleState.GoalCFrame.Position - ballPos).Unit
        local lookDir = ballVel.Unit
        
        if lookDir:Dot(toGoal) > 0.7 then
            targetLookPos = ballPos + lookDir * 5
        else
            targetLookPos = ballPos + ballVel.Unit * 8
        end
    elseif ballVel.Magnitude > 10 then
        targetLookPos = ballPos + ballVel.Unit * 5
    end
    
    local targetLook = CFrame.lookAt(root.Position, targetLookPos)
    moduleState.smoothCFrame = moduleState.smoothCFrame:Lerp(targetLook, CONFIG.ROT_SMOOTH)
    
    if moduleState.currentGyro then 
        pcall(function() 
            moduleState.currentGyro:Destroy() 
        end) 
        moduleState.currentGyro = nil 
    end
    
    moduleState.currentGyro = Instance.new("BodyGyro")
    moduleState.currentGyro.Parent = root
    moduleState.currentGyro.P = 2800000
    moduleState.currentGyro.MaxTorque = Vector3.new(0, 4e6, 0)
    moduleState.currentGyro.CFrame = moduleState.smoothCFrame
    game.Debris:AddItem(moduleState.currentGyro, 0.18)
end

-- Получение хитбокса вратаря
local function getGoalkeeperHitbox(char)
    if not char then return nil end
    local hitbox = char:FindFirstChild("Hitbox") or char:FindFirstChild("GoalkeeperHitbox")
    if hitbox then
        return hitbox
    end
    return char:FindFirstChild("HumanoidRootPart")
end

-- Проверка необходимости прыжка
local function shouldJumpSimple(root, ballPos, goalkeeperHitbox)
    if not root or not ballPos or not goalkeeperHitbox then return false end
    
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.JUMP_RADIUS then return false end
    
    local hitboxTop = goalkeeperHitbox.Position.Y + (goalkeeperHitbox.Size.Y / 2)
    local ballHeight = ballPos.Y
    
    if ballHeight > hitboxTop + CONFIG.JUMP_MIN_HEIGHT_DIFF then
        return true
    end
    
    return false
end

-- Улучшенное умное позиционирование
local function calculateSmartPosition(ballPos, ownerRoot, isBallControlled, endpoint, ballVel)
    if not moduleState.GoalCFrame then 
        return moduleState.GoalCFrame.Position + moduleState.GoalForward * CONFIG.STAND_DIST 
    end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    local goalForward = moduleState.GoalForward
    
    -- Проверка на угловую атаку
    local isCornerAttack = false
    if endpoint then
        local endpointToGoal = (goalPos - endpoint) * Vector3.new(1,0,1)
        local lateralDist = math.abs(endpointToGoal:Dot(goalRight))
        local forwardDist = endpointToGoal:Dot(goalForward)
        
        if lateralDist > moduleState.GoalWidth * 0.45 and forwardDist < CONFIG.CORNER_DEFENSE_DIST then
            isCornerAttack = true
        end
    end
    
    -- Защита от угловых
    if isCornerAttack and CONFIG.CORNER_DEFENSE_ENABLED then
        local lateralSign = (endpoint - goalPos):Dot(goalRight) > 0 and 1 or -1
        local lateralOffset = goalRight * (lateralSign * moduleState.GoalWidth * CONFIG.CORNER_DEFENSE_LATERAL)
        local forwardOffset = goalForward * (CONFIG.STAND_DIST * CONFIG.CORNER_DEFENSE_FORWARD)
        
        local cornerPos = goalPos + forwardOffset + lateralOffset
        
        -- Не подходим слишком близко к углу
        local toGoal = cornerPos - goalPos
        local lateralDist = math.abs(toGoal:Dot(goalRight))
        
        if lateralDist > moduleState.GoalWidth * 0.35 then
            cornerPos = goalPos + goalForward * CONFIG.STAND_DIST
        end
        
        return cornerPos
    end
    
    local threatDistance = moduleState.isBigGoal and 50 or 30
    local enemyDistance = moduleState.isBigGoal and 70 or 40
    local ballDistance = moduleState.isBigGoal and 100 or 60
    
    if isBallControlled and ownerRoot then
        local enemyPos = ownerRoot.Position
        local enemyToGoal = (goalPos - enemyPos) * Vector3.new(1,0,1)
        local enemyDist = enemyToGoal.Magnitude
        
        if enemyDist < enemyDistance then
            local angleToGoal = math.atan2(
                (enemyPos - goalPos):Dot(goalRight),
                (enemyPos - goalPos):Dot(goalForward)
            )
            
            local optimalDepth = math.clamp(enemyDist * 0.4, 3, 15)
            
            local lateralMultiplier = math.sin(angleToGoal) * 0.75
            local lateralOffset = goalRight * (lateralMultiplier * moduleState.GoalWidth * 0.45)
            
            local interceptPoint = enemyPos + (enemyPos - goalPos).Unit * 10
            interceptPoint = Vector3.new(interceptPoint.X, 0, interceptPoint.Z)
            
            local basePos = goalPos + goalForward * optimalDepth
            
            local closingFactor = math.clamp(1 - (enemyDist / enemyDistance), 0, 0.8)
            local finalPos = (basePos * (1 - closingFactor) + interceptPoint * closingFactor) + lateralOffset
            
            local forwardDist = (finalPos - goalPos):Dot(goalForward)
            if forwardDist < 0.5 then
                finalPos = goalPos + goalForward * 0.5
            end
            
            return finalPos
        end
    end
    
    if endpoint then
        local endpointToGoal = (goalPos - endpoint) * Vector3.new(1,0,1)
        local endpointDist = endpointToGoal.Magnitude
        
        if endpointDist < threatDistance then
            local angleToGoal = math.atan2(
                (endpoint - goalPos):Dot(goalRight),
                (endpoint - goalPos):Dot(goalForward)
            )
            
            local depth = math.clamp(endpointDist * 0.3, 2, 10)
            local lateralMultiplier = math.sin(angleToGoal) * 0.9
            local lateralOffset = goalRight * (lateralMultiplier * moduleState.GoalWidth * 0.5)
            
            local targetPos = goalPos + goalForward * depth + lateralOffset
            
            local forwardDist = (targetPos - goalPos):Dot(goalForward)
            if forwardDist < 0.5 then
                targetPos = goalPos + goalForward * 0.5
            end
            
            return targetPos
        end
    end
    
    if ballVel and ballVel.Magnitude > 20 then
        local ballToGoal = (goalPos - ballPos) * Vector3.new(1,0,1)
        local ballDist = ballToGoal.Magnitude
        
        if ballDist < ballDistance then
            local angleToGoal = math.atan2(
                (ballPos - goalPos):Dot(goalRight),
                (ballPos - goalPos):Dot(goalForward)
            )
            
            local depth = math.clamp(ballDist * 0.25, 2, 8)
            local lateralMultiplier = math.sin(angleToGoal) * 0.8
            local lateralOffset = goalRight * (lateralMultiplier * moduleState.GoalWidth * 0.4)
            
            return goalPos + goalForward * depth + lateralOffset
        end
    end
    
    local ballToGoal = (goalPos - ballPos) * Vector3.new(1,0,1)
    local ballDist = ballToGoal.Magnitude
    
    if ballDist < 80 then
        local angleToGoal = math.atan2(
            (ballPos - goalPos):Dot(goalRight),
            (ballPos - goalPos):Dot(goalForward)
        )
        local depth = math.clamp(ballDist * 0.2, 3, 12)
        local lateralMultiplier = math.sin(angleToGoal) * 0.6
        local lateralOffset = goalRight * (lateralMultiplier * moduleState.GoalWidth * 0.35)
        return goalPos + goalForward * depth + lateralOffset
    end
    
    return goalPos + goalForward * CONFIG.STAND_DIST
end

-- Движение к позиции
local function moveToPosition(root, targetPos, ballPos, velMag, isUrgent)
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1,0,1)
    if dirVec.Magnitude < CONFIG.MIN_DIST then return end
    
    local speed = CONFIG.SPEED
    if isUrgent then
        speed = CONFIG.AGGRESSIVE_SPEED
    end
    
    local ballDist = (ballPos - root.Position).Magnitude
    if velMag > 25 and ballDist < 30 then
        speed = speed * 1.3
    end
    
    moduleState.currentBV = Instance.new("BodyVelocity")
    moduleState.currentBV.Parent = root
    moduleState.currentBV.MaxForce = Vector3.new(6e5, 0, 6e5)
    moduleState.currentBV.Velocity = dirVec.Unit * speed
    game.Debris:AddItem(moduleState.currentBV, 0.15)
end

-- Улучшенный прыжок
local function performJump(char, hum, targetPosition)
    if tick() - moduleState.lastJumpTime < CONFIG.JUMP_COOLDOWN or moduleState.isJumping then 
        return false 
    end
    
    moduleState.isJumping = true
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
    
    -- Сохраняем оригинальные значения
    local oldPower = hum.JumpPower
    local oldJumpHeight = hum.JumpHeight
    
    -- Устанавливаем параметры прыжка
    hum.JumpPower = CONFIG.JUMP_POWER
    hum.JumpHeight = CONFIG.JUMP_HEIGHT
    hum.Jump = true
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    
    -- Применяем легкий импульс вперед если прыгаем к мячу
    if targetPosition then
        local dir = (targetPosition - root.Position) * Vector3.new(1, 0, 1)
        if dir.Magnitude > 0.1 then
            dir = dir.Unit
            local bv = Instance.new("BodyVelocity")
            bv.Parent = root
            bv.MaxForce = Vector3.new(20000, 0, 20000)
            bv.Velocity = dir * 10
            game.Debris:AddItem(bv, 0.2)
        end
    end
    
    -- Сбрасываем после прыжка
    task.delay(0.6, function()
        if hum and hum.Parent then
            hum.JumpPower = oldPower
            hum.JumpHeight = oldJumpHeight
        end
        moduleState.isJumping = false
    end)
    
    return true
end

-- Улучшенный перехват
local function shouldIntercept(root, ball, endpoint)
    if tick() - moduleState.lastInterceptTime < moduleState.interceptCooldown then return false end
    
    local ballPos = ball.Position
    local ballVel = ball.Velocity
    local ballVelMag = ballVel.Magnitude
    
    if ballVelMag < 15 then return false end
    
    local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1,0,1)
    local distToGoalLine = ballToGoal.Magnitude
    
    if distToGoalLine > 25 then return false end
    
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.INTERCEPT_DISTANCE then return false end
    
    -- Рассчитываем точку перехвата с учетом времени
    local interceptPoint = ballPos + ballVel * CONFIG.INTERCEPT_PREDICT_TIME
    local distToIntercept = (root.Position - interceptPoint).Magnitude
    
    local timeToReach = distToIntercept / (CONFIG.AGGRESSIVE_SPEED * CONFIG.INTERCEPT_SPEED_MULT)
    local timeToGoal = distToGoalLine / ballVelMag
    
    if timeToGoal < timeToReach + CONFIG.MIN_INTERCEPT_TIME then
        return true, interceptPoint
    end
    
    return false, nil
end

-- Выполнение перехвата
local function performIntercept(root, char, ball, interceptPoint)
    moduleState.lastInterceptTime = tick()
    
    local ballPos = ball.Position
    local dirVec = (interceptPoint - root.Position) * Vector3.new(1,0,1)
    
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    moduleState.currentBV = Instance.new("BodyVelocity")
    moduleState.currentBV.Parent = root
    moduleState.currentBV.MaxForce = Vector3.new(8e5, 0, 8e5)
    moduleState.currentBV.Velocity = dirVec.Unit * CONFIG.AGGRESSIVE_SPEED * CONFIG.INTERCEPT_SPEED_MULT
    game.Debris:AddItem(moduleState.currentBV, 0.3)
    
    -- Попытка касания
    for _, hand in {char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand")} do
        if hand and (hand.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
            firetouchinterest(hand, ball, 0)
            task.wait(0.05)
            firetouchinterest(hand, ball, 1)
            moduleState.lastTouchTime = tick()
            break
        end
    end
end

-- Проверка необходимости нырка
local function shouldDive(root, ball, velMag, endpoint)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving then return false end
    if velMag < CONFIG.DIVE_VEL_THRES then return false end
    
    local ballPos = ball.Position
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.DIVE_DIST then return false end
    
    local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1,0,1)
    local distToGoalLine = ballToGoal.Magnitude
    
    if distToGoalLine < 25 then
        local timeToReach = distToBall / CONFIG.AGGRESSIVE_SPEED
        local timeToGoal = distToGoalLine / velMag
        
        if timeToGoal < timeToReach * 1.3 then
            return true, ballPos
        end
    end
    
    if endpoint then
        local timeToReachBall = distToBall / CONFIG.AGGRESSIVE_SPEED
        local ballTravelDist = (endpoint - ballPos).Magnitude
        local timeToEndpoint = ballTravelDist / velMag
        
        if timeToEndpoint < timeToReachBall * 1.4 then
            return true, endpoint
        end
    end
    
    return false, nil
end

-- Улучшенный нырок с правильной ротацией
local function performDive(root, hum, targetPos, ballHeight, ball)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving or moduleState.diveAnimationPlaying then return end
    
    moduleState.isDiving = true
    moduleState.diveAnimationPlaying = true
    moduleState.lastDiveTime = tick()
    
    local rel = (targetPos - root.Position) * Vector3.new(1,0,1)
    local lateral = rel:Dot(root.CFrame.RightVector)
    local dir = lateral > 0 and "Right" or "Left"
    
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir.."dive", root.CFrame)
    end)
    
    local char = hum.Parent
    local animations = ReplicatedStorage:WaitForChild("Animations")
    local gkAnimations = animations.GK
    
    local diveAnim
    local diveDistance = moduleState.isBigGoal and CONFIG.BIG_GOAL_DIVE_DISTANCE or CONFIG.SMALL_GOAL_DIVE_DISTANCE
    local diveSpeed = CONFIG.DIVE_SPEED
    
    if dir == "Right" then
        if ballHeight <= 10 then
            diveAnim = hum:LoadAnimation(gkAnimations:WaitForChild("RightLowDive"))
        else
            diveAnim = hum:LoadAnimation(gkAnimations:WaitForChild("RightDive"))
        end
    else
        if ballHeight <= 10 then
            diveAnim = hum:LoadAnimation(gkAnimations:WaitForChild("LeftLowDive"))
        else
            diveAnim = hum:LoadAnimation(gkAnimations:WaitForChild("LeftDive"))
        end
    end
    
    diveAnim.Priority = Enum.AnimationPriority.Action4
    diveAnim:Play()
    
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    
    -- Вектор ныряния с учетом направления от ворот
    local toGoal = (moduleState.GoalCFrame.Position - root.Position).Unit
    local diveDir
    
    if dir == "Right" then
        diveDir = (root.CFrame.RightVector - toGoal * 0.3).Unit
    else
        diveDir = (-root.CFrame.RightVector - toGoal * 0.3).Unit
    end
    
    local diveBV = Instance.new("BodyVelocity")
    diveBV.Parent = root
    diveBV.MaxForce = Vector3.new(1e7, 0, 1e7)
    diveBV.Velocity = diveDir * diveSpeed
    
    game.Debris:AddItem(diveBV, CONFIG.DIVE_DURATION)
    
    -- Ротация при нырке (смотрим от ворот)
    local lookTarget = root.Position - toGoal * 5
    local diveGyro = Instance.new("BodyGyro")
    diveGyro.Name = "GKGyro"
    diveGyro.Parent = root
    diveGyro.P = 1200000
    diveGyro.MaxTorque = Vector3.new(0, 100000, 0)
    diveGyro.CFrame = CFrame.lookAt(root.Position, lookTarget)
    game.Debris:AddItem(diveGyro, CONFIG.DIVE_DURATION)
    
    -- Касание мяча
    if ball then
        task.delay(0.1, function()
            for _, partName in pairs({"HumanoidRootPart", "RightHand", "LeftHand"}) do
                local part = char:FindFirstChild(partName)
                if part and (part.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
                    firetouchinterest(part, ball, 0)
                    task.wait(0.05)
                    firetouchinterest(part, ball, 1)
                    moduleState.lastTouchTime = tick()
                end
            end
        end)
    end
    
    task.delay(CONFIG.DIVE_DURATION, function() 
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) 
    end)
    
    task.delay(CONFIG.DIVE_DURATION + 0.1, function() 
        moduleState.isDiving = false 
        moduleState.diveAnimationPlaying = false
    end)
end

-- Проверка необходимости блока
local function shouldBlock(root, ball, velMag)
    local distToBall = (root.Position - ball.Position).Magnitude
    if distToBall > CONFIG.NEAR_BALL_DIST then return false end
    
    if velMag < 15 then
        return true
    end
    
    local ballToRoot = (root.Position - ball.Position) * Vector3.new(1,0,1)
    local approachSpeed = ball.Velocity:Dot(ballToRoot.Unit)
    
    if approachSpeed > 12 and distToBall < 3.5 then
        return true
    end
    
    return false
end

-- Анализ угрозы
local function analyzeThreat(ballPos, ballVel, endpoint, rootPos)
    local analysis = {
        isThreat = false,
        isHighBall = false,
        isCorner = false,
        urgency = 0,
        threatLevel = 0
    }
    
    if not endpoint or not moduleState.GoalCFrame then return analysis end
    
    local ballHeight = ballPos.Y
    local ballSpeed = ballVel.Magnitude
    
    -- Проверка высоты
    analysis.isHighBall = ballHeight > CONFIG.HIGH_BALL_THRES
    
    -- Проверка угрозы ворот
    local toGoal = (moduleState.GoalCFrame.Position - endpoint) * Vector3.new(1,0,1)
    local forwardDist = toGoal:Dot(moduleState.GoalForward)
    local lateralDist = math.abs(toGoal:Dot(moduleState.GoalRight))
    
    analysis.isThreat = forwardDist < 2.6 and lateralDist < moduleState.GoalWidth / 2.0
    
    -- Проверка углового удара
    analysis.isCorner = lateralDist > moduleState.GoalWidth * 0.4 and forwardDist < CONFIG.CORNER_DEFENSE_DIST
    
    -- Уровень угрозы
    if analysis.isThreat then
        analysis.threatLevel = 2
        analysis.urgency = ballSpeed / 30
    elseif analysis.isCorner then
        analysis.threatLevel = 1
        analysis.urgency = 0.5
    end
    
    -- Обновление состояния
    moduleState.threatAnalysis.isThreat = analysis.isThreat
    moduleState.threatAnalysis.isCornerKick = analysis.isCorner
    moduleState.threatAnalysis.ballHeight = ballHeight
    moduleState.threatAnalysis.threatSpeed = ballSpeed
    moduleState.threatAnalysis.predictedImpactPoint = endpoint
    
    return analysis
end

-- Основной цикл рендера
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
        
        if not updateGoals() then 
            hideAllVisuals()
            return 
        end
        
        local hasWeld = ball:FindFirstChild("playerWeld")
        local owner = ball:FindFirstChild("creator") and ball.creator.Value
        local isMyBall = owner == player
        local oRoot = owner and owner ~= player and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
        
        local velMag = ball.Velocity.Magnitude
        
        -- Обнаружение нового удара
        if velMag > 18 and moduleState.lastBallVelMag <= 18 then
            moduleState.cachedPoints = nil
            clearTrajAndEndpoint()
        end
        moduleState.lastBallVelMag = velMag
        
        local isBallControlled = hasWeld and owner ~= player
        local shouldPredict = not isMyBall and not hasWeld
        
        -- Предсказание траектории
        if shouldPredict and (moduleState.frameCounter % CONFIG.PRED_UPDATE_RATE == 0 or not moduleState.cachedPoints) then
            moduleState.cachedPoints = predictTrajectory(ball)
        elseif not shouldPredict then
            moduleState.cachedPoints = nil
        end
        
        local endpoint = moduleState.cachedPoints and moduleState.cachedPoints[#moduleState.cachedPoints]
        
        -- Анализ угрозы
        local threatAnalysis = analyzeThreat(ball.Position, ball.Velocity, endpoint, root.Position)
        
        if not isMyBall and not moduleState.isDiving and not moduleState.isJumping then
            local targetPos = calculateSmartPosition(ball.Position, oRoot, isBallControlled, endpoint, ball.Velocity)
            local isUrgent = threatAnalysis.isThreat or threatAnalysis.isCorner or (velMag > 30)
            
            moveToPosition(root, targetPos, ball.Position, velMag, isUrgent)
            
            -- Умная ротация только когда нужно
            smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall, threatAnalysis.isThreat)
            
            if tick() - moduleState.lastActionTime > moduleState.actionCooldown then
                local goalkeeperHitbox = getGoalkeeperHitbox(char)
                
                moduleState.willJump = shouldJumpSimple(root, ball.Position, goalkeeperHitbox)
                
                -- Приоритет действий: перехват > нырок > прыжок > блок
                local shouldInterceptFlag, interceptPoint = shouldIntercept(root, ball, endpoint)
                if shouldInterceptFlag then
                    performIntercept(root, char, ball, interceptPoint)
                    moduleState.lastActionTime = tick()
                else
                    local shouldDiveFlag, diveTarget = shouldDive(root, ball, velMag, endpoint)
                    if shouldDiveFlag then
                        performDive(root, hum, diveTarget or ball.Position, ball.Position.Y, ball)
                        moduleState.lastActionTime = tick()
                    elseif moduleState.willJump then
                        performJump(char, hum, ball.Position)
                        moduleState.lastActionTime = tick()
                    elseif shouldBlock(root, ball, velMag) then
                        for _, hand in {char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand")} do
                            if hand and (hand.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
                                firetouchinterest(hand, ball, 0)
                                task.wait(0.05)
                                firetouchinterest(hand, ball, 1)
                                moduleState.lastTouchTime = tick()
                                break
                            end
                        end
                        moduleState.lastActionTime = tick()
                    end
                end
            end
        else
            if moduleState.currentBV then 
                pcall(function() moduleState.currentBV:Destroy() end) 
                moduleState.currentBV = nil 
            end
            smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall, false)
        end
        
        moduleState.frameCounter = moduleState.frameCounter + 1
    end)
end

-- Цикл визуализации
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
        
        if not updateGoals() then 
            hideAllVisuals()
            return 
        end
        
        -- Отрисовка ворот
        if CONFIG.SHOW_GOAL_CUBE and moduleState.visualObjects.GoalCube then
            drawCube(moduleState.visualObjects.GoalCube, moduleState.GoalCFrame, 
                Vector3.new(moduleState.GoalWidth, 8, 2), CONFIG.GOAL_CUBE_COLOR)
        end
        
        -- Отрисовка зоны
        if CONFIG.SHOW_ZONE then 
            drawFlatZone() 
        end
        
        local root = char.HumanoidRootPart
        local distBall = (root.Position - ball.Position).Magnitude
        
        -- Отрисовка траектории
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
            
            -- Отрисовка конечной точки
            if CONFIG.SHOW_ENDPOINT then
                drawEndpoint(moduleState.cachedPoints[#moduleState.cachedPoints])
            end
        else
            clearTrajAndEndpoint()
        end
        
        -- Отрисовка бокса мяча с учетом дистанции зоны
        local maxBallBoxDist = CONFIG.ZONE_DEPTH * 1.2
        if CONFIG.SHOW_BALL_BOX and distBall < maxBallBoxDist and moduleState.visualObjects.BallBox then 
            local col
            local ballHeight = ball.Position.Y
            
            if moduleState.willJump then
                col = CONFIG.BALL_BOX_JUMP_COLOR
            elseif moduleState.threatAnalysis.isThreat then
                col = CONFIG.BALL_BOX_THREAT_COLOR
            elseif ballHeight > CONFIG.HIGH_BALL_THRES then
                col = CONFIG.BALL_BOX_HIGH_COLOR
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

-- Очистка
local function cleanup()
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    if moduleState.currentGyro then 
        pcall(function() moduleState.currentGyro:Destroy() end) 
        moduleState.currentGyro = nil 
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
    moduleState.isJumping = false
    moduleState.diveAnimationPlaying = false
    moduleState.jumpAnimationPlaying = false
    moduleState.cachedPoints = nil
    moduleState.willJump = false
end


local AutoGKUltraModule = {}

function AutoGKUltraModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
    moduleState.notify = notifyFunc
    
    if UI.Sections.AutoGoalKeeper then
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalKeeper ULTRA v10.0" })
        
        -- Основной переключатель
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
                    notifyFunc("AutoGK", "Enabled v10.0", true)
                else
                    cleanup()
                    notifyFunc("AutoGK", "Disabled", true)
                end
            end
        }, 'AutoGKUltraEnabled')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки движения
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
        
        -- Настройки нырка
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
            Name = "Dive Velocity",
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
        
        moduleState.uiElements.DIVE_SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Speed",
            Minimum = 25,
            Maximum = 50,
            Default = CONFIG.DIVE_SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_SPEED = v end
        }, 'AutoGKUltraDiveSpeed')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки прыжка
        UI.Sections.AutoGoalKeeper:Header({ Name = "Jump Settings" })
        
        moduleState.uiElements.JUMP_VEL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Velocity",
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
            Name = "Height Difference",
            Minimum = 0.1,
            Maximum = 3.0,
            Default = CONFIG.JUMP_MIN_HEIGHT_DIFF,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_MIN_HEIGHT_DIFF = v end
        }, 'AutoGKUltraJumpMinHeightDiff')
        
        moduleState.uiElements.JUMP_POWER = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Power",
            Minimum = 25,
            Maximum = 50,
            Default = CONFIG.JUMP_POWER,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_POWER = v end
        }, 'AutoGKUltraJumpPower')
        
        moduleState.uiElements.JUMP_HEIGHT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Height",
            Minimum = 4,
            Maximum = 12,
            Default = CONFIG.JUMP_HEIGHT,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_HEIGHT = v end
        }, 'AutoGKUltraJumpHeight')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки перехвата и касания
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
            Name = "Intercept Speed",
            Minimum = 1.0,
            Maximum = 2.0,
            Default = CONFIG.INTERCEPT_SPEED_MULT,
            Precision = 2,
            Callback = function(v) CONFIG.INTERCEPT_SPEED_MULT = v end
        }, 'AutoGKUltraInterceptSpeedMult')
        
        moduleState.uiElements.TOUCH_RANGE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Touch Distance",
            Minimum = 5,
            Maximum = 30,
            Default = CONFIG.TOUCH_RANGE,
            Precision = 1,
            Callback = function(v) CONFIG.TOUCH_RANGE = v end
        }, 'AutoGKUltraTouchRange')
        
        moduleState.uiElements.NEAR_BALL_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Near Ball Dist",
            Minimum = 2,
            Maximum = 10,
            Default = CONFIG.NEAR_BALL_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.NEAR_BALL_DIST = v end
        }, 'AutoGKUltraNearBallDist')
        
        moduleState.uiElements.INTERCEPT_PREDICT_TIME = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Intercept Predict Time",
            Minimum = 0.05,
            Maximum = 0.3,
            Default = CONFIG.INTERCEPT_PREDICT_TIME,
            Precision = 2,
            Callback = function(v) CONFIG.INTERCEPT_PREDICT_TIME = v end
        }, 'AutoGKUltraInterceptPredict')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки зоны защиты
        UI.Sections.AutoGoalKeeper:Header({ Name = "Defense Zone Settings" })
        
        moduleState.uiElements.ZONE_WIDTH_MULTIPLIER = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Width",
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
        
        moduleState.uiElements.ZONE_OFFSET_MULTIPLIER = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Zone Offset",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.ZONE_OFFSET_MULTIPLIER,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_OFFSET_MULTIPLIER = v end
        }, 'AutoGKUltraZoneOffset')
        
        moduleState.uiElements.CORNER_DEFENSE_ENABLED = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Corner Defense",
            Default = CONFIG.CORNER_DEFENSE_ENABLED,
            Callback = function(v) CONFIG.CORNER_DEFENSE_ENABLED = v end
        }, 'AutoGKUltraCornerDefense')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки визуализации
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
        
        -- Цветовые настройки
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
        
        moduleState.uiElements.BALL_BOX_THREAT_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box Threat Color",
            Default = CONFIG.BALL_BOX_THREAT_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_THREAT_COLOR = v
            end
        }, 'AutoGKUltraBallBoxThreatColor')
        
        moduleState.uiElements.BALL_BOX_HIGH_COLOR = UI.Sections.AutoGoalKeeper:Colorpicker({
            Name = "Ball Box High Color",
            Default = CONFIG.BALL_BOX_HIGH_COLOR,
            Callback = function(v) 
                CONFIG.BALL_BOX_HIGH_COLOR = v
            end
        }, 'AutoGKUltraBallBoxHighColor')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки ротации и производительности
        UI.Sections.AutoGoalKeeper:Header({ Name = "Rotation & Performance Settings" })
        
        moduleState.uiElements.SMART_ROTATION_ENABLED = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Smart Rotation",
            Default = CONFIG.SMART_ROTATION_ENABLED,
            Callback = function(v) CONFIG.SMART_ROTATION_ENABLED = v end
        }, 'AutoGKUltraSmartRotation')
        
        moduleState.uiElements.ROT_SMOOTH = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Rotation Smoothness",
            Minimum = 0.1,
            Maximum = 0.9,
            Default = CONFIG.ROT_SMOOTH,
            Precision = 2,
            Callback = function(v) CONFIG.ROT_SMOOTH = v end
        }, 'AutoGKUltraRotSmooth')
        
        moduleState.uiElements.MIN_ROTATION_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Min Rotation Distance",
            Minimum = 2.0,
            Maximum = 15.0,
            Default = CONFIG.MIN_ROTATION_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.MIN_ROTATION_DIST = v end
        }, 'AutoGKUltraMinRotDist')
        
        moduleState.uiElements.MAX_ROTATION_ANGLE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Max Rotation Angle",
            Minimum = 20,
            Maximum = 70,
            Default = CONFIG.MAX_ROTATION_ANGLE,
            Precision = 0,
            Callback = function(v) CONFIG.MAX_ROTATION_ANGLE = v end
        }, 'AutoGKUltraMaxRotAngle')
        
        moduleState.uiElements.PRED_UPDATE_RATE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Prediction Update Rate",
            Minimum = 1,
            Maximum = 10,
            Default = CONFIG.PRED_UPDATE_RATE,
            Precision = 0,
            Callback = function(v) CONFIG.PRED_UPDATE_RATE = v end
        }, 'AutoGKUltraPredUpdateRate')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Улучшенное позиционирование
        UI.Sections.AutoGoalKeeper:Header({ Name = "Advanced Positioning" })
        
        moduleState.uiElements.AVOID_CORNERS = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Avoid Corners",
            Default = CONFIG.AVOID_CORNERS,
            Callback = function(v) CONFIG.AVOID_CORNERS = v end
        }, 'AutoGKUltraAvoidCorners')
        
        moduleState.uiElements.CENTER_BIAS_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Center Bias Distance",
            Minimum = 10,
            Maximum = 30,
            Default = CONFIG.CENTER_BIAS_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.CENTER_BIAS_DIST = v end
        }, 'AutoGKUltraCenterBias')
        
        moduleState.uiElements.GATE_COVERAGE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Gate Coverage",
            Minimum = 0.8,
            Maximum = 1.2,
            Default = CONFIG.GATE_COVERAGE,
            Precision = 2,
            Callback = function(v) CONFIG.GATE_COVERAGE = v end
        }, 'AutoGKUltraGateCoverage')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Информация
        UI.Sections.AutoGoalKeeper:Header({ Name = "Settings Information" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "AutoGK ULTRA v10.0 - Improvements",
            Body = [[
УЛУЧШЕНИЯ В ВЕРСИИ 10.0:

1. УЛУЧШЕННАЯ РОТАЦИЯ:
   • При нырке смотрит от ворот, а не в них
   • Ротация включается только на нужных дистанциях
   • Умное определение направления взгляда

2. УЛУЧШЕННЫЙ ПРЕДИКТ:
   • Учет закрученных ударов (Curve shots)
   • Лучшая физика отскоков от стоек
   • Более точное предсказание траектории

3. ЗАЩИТА ОТ УГЛОВЫХ:
   • Улучшено позиционирование при угловых
   • Автоматическое смещение к углу ворот
   • Предотвращение пропуска угловых атак

4. УЛУЧШЕННЫЙ ПЕРЕХВАТ:
   • Учет времени предсказания
   • Более точный расчет точки перехвата
   • Улучшенное касание мяча

5. АДАПТИВНАЯ ВИЗУАЛИЗАЦИЯ:
   • Дистанция показа мяча зависит от глубины зоны
   • Разные цвета для разных типов угроз
   • Информативный бокс отладки

НАСТРОЙКИ РОТАЦИИ:
• Smart Rotation: Включает умную систему ротации
• Rotation Smoothness: Плавность поворота
• Min Rotation Distance: Минимальная дистанция для ротации
• Max Rotation Angle: Максимальный угол поворота

НАСТРОЙКИ ПОЗИЦИОНИРОВАНИЯ:
• Avoid Corners: Избегать позиций в углах
• Center Bias Distance: Стремление к центру
• Gate Coverage: Покрытие ворот

УПРАВЛЕНИЕ:
• Insert: Вкл/Выкл
• Автоматическая работа при назначении вратарем
]]
        })
        
        -- Кнопка сброса настроек
        UI.Sections.AutoGoalKeeper:Button({
            Name = "Reset to Defaults",
            Callback = function()
                -- Сброс всех значений конфигурации
                local defaultConfig = {
                    ENABLED = false,
                    SPEED = 32,
                    AGGRESSIVE_SPEED = 38,
                    STAND_DIST = 2.8,
                    MIN_DIST = 0.8,
                    PRED_STEPS = 80,
                    CURVE_MULT = 42,
                    DT = 1/120,
                    GRAVITY = 108,
                    DRAG = 0.984,
                    BOUNCE_XZ = 0.74,
                    BOUNCE_Y = 0.72,
                    AGGRO_THRES = 55,
                    PRESSURE_DIST = 44,
                    DIVE_DIST = 26,
                    TOUCH_RANGE = 20,
                    NEAR_BALL_DIST = 5.0,
                    DIVE_VEL_THRES = 24,
                    JUMP_VEL_THRES = 28,
                    HIGH_BALL_THRES = 5.8,
                    JUMP_THRES = 4.5,
                    DIVE_COOLDOWN = 1.1,
                    JUMP_COOLDOWN = 0.8,
                    PRED_UPDATE_RATE = 1,
                    ROT_SMOOTH = 0.82,
                    SMART_ROTATION_ENABLED = true,
                    BIG_GOAL_THRESHOLD = 40,
                    INTERCEPT_DISTANCE = 35,
                    INTERCEPT_SPEED_MULT = 1.34,
                    INTERCEPT_PREDICT_TIME = 0.15,
                    JUMP_CHECK_HEIGHT = 0.6,
                    JUMP_PREDICTION_STEPS = 30,
                    JUMP_REACTION_TIME = 0.15,
                    JUMP_VERTICAL_THRESHOLD = 0.1,
                    GOAL_JUMP_SAFETY_MARGIN = 0.6,
                    JUMP_RADIUS = 40,
                    JUMP_MIN_HEIGHT_DIFF = 0.7,
                    JUMP_POWER = 32,
                    JUMP_HEIGHT = 6,
                    JUMP_HORIZONTAL_FORCE = 70,
                    SMALL_GOAL_DIVE_DISTANCE = 5,
                    BIG_GOAL_DIVE_DISTANCE = 10,
                    DIVE_DURATION = 0.44,
                    DIVE_SPEED = 38,
                    ZONE_WIDTH_MULTIPLIER = 2.5,
                    ZONE_DEPTH = 56,
                    ZONE_HEIGHT = 0.2,
                    ZONE_OFFSET_MULTIPLIER = 35,
                    SHOW_TRAJECTORY = true,
                    SHOW_ENDPOINT = true,
                    SHOW_GOAL_CUBE = true,
                    SHOW_ZONE = true,
                    SHOW_BALL_BOX = true,
                    TRAJECTORY_COLOR = Color3.fromHSV(0.5, 1, 1),
                    ENDPOINT_COLOR = Color3.new(1, 1, 0),
                    GOAL_CUBE_COLOR = Color3.new(1, 0, 0),
                    ZONE_COLOR = Color3.new(0, 1, 0),
                    BALL_BOX_COLOR = Color3.new(0, 0.8, 1),
                    BALL_BOX_JUMP_COLOR = Color3.new(1, 0, 1),
                    BALL_BOX_SAFE_COLOR = Color3.new(0, 1, 0),
                    BALL_BOX_THREAT_COLOR = Color3.new(1, 0, 0),
                    BALL_BOX_HIGH_COLOR = Color3.new(1, 1, 0),
                    GATE_COVERAGE = 1.02,
                    CENTER_BIAS_DIST = 18,
                    LATERAL_MAX_MULT = 0.48,
                    AVOID_CORNERS = true,
                    CORNER_AVOID_DISTANCE = 2.0,
                    REACTION_TIME = 0.15,
                    ANTICIPATION_DIST = 1.5,
                    BALL_INTERCEPT_RANGE = 4.0,
                    MIN_INTERCEPT_TIME = 0.08,
                    ADVANCE_DISTANCE = 3.2,
                    DIVE_LOOK_AHEAD = 0.18,
                    CORNER_DEFENSE_ENABLED = true,
                    CORNER_DEFENSE_LATERAL = 0.7,
                    CORNER_DEFENSE_FORWARD = 1.2,
                    MIN_ROTATION_DIST = 8.0,
                    MAX_ROTATION_ANGLE = 45,
                    DIVE_ROTATION_OFFSET = 15
                }
                
                for key, value in pairs(defaultConfig) do
                    CONFIG[key] = value
                    if moduleState.uiElements[key] then
                        if moduleState.uiElements[key].SetState then
                            moduleState.uiElements[key]:SetState(value)
                        elseif moduleState.uiElements[key].SetValue then
                            moduleState.uiElements[key]:SetValue(value)
                        end
                    end
                end
                
                moduleState.enabled = CONFIG.ENABLED
                if moduleState.enabled then
                    createVisuals()
                    startRenderLoop()
                    startHeartbeat()
                else
                    cleanup()
                end
                
                notifyFunc("AutoGK", "Settings reset to defaults", true)
            end
        })
    end
    
    -- Секция синхронизации в Config
    if UI.Tabs.Config then
        local syncSection = UI.Tabs.Config:Section({Name = 'AutoGK ULTRA Sync', Side = 'Right'})
        
        syncSection:Header({ Name = "AutoGK ULTRA Config Sync" })
        
        syncSection:Button({
            Name = "Sync Configuration Now",
            Callback = function()
                -- Синхронизация каждого элемента отдельно
                CONFIG.ENABLED = moduleState.uiElements.Enabled and moduleState.uiElements.Enabled:GetState()
                CONFIG.SPEED = moduleState.uiElements.SPEED and moduleState.uiElements.SPEED:GetValue()
                CONFIG.AGGRESSIVE_SPEED = moduleState.uiElements.AGGRESSIVE_SPEED and moduleState.uiElements.AGGRESSIVE_SPEED:GetValue()
                CONFIG.STAND_DIST = moduleState.uiElements.STAND_DIST and moduleState.uiElements.STAND_DIST:GetValue()
                CONFIG.MIN_DIST = moduleState.uiElements.MIN_DIST and moduleState.uiElements.MIN_DIST:GetValue()
                CONFIG.DIVE_DIST = moduleState.uiElements.DIVE_DIST and moduleState.uiElements.DIVE_DIST:GetValue()
                CONFIG.DIVE_VEL_THRES = moduleState.uiElements.DIVE_VEL_THRES and moduleState.uiElements.DIVE_VEL_THRES:GetValue()
                CONFIG.DIVE_COOLDOWN = moduleState.uiElements.DIVE_COOLDOWN and moduleState.uiElements.DIVE_COOLDOWN:GetValue()
                CONFIG.DIVE_SPEED = moduleState.uiElements.DIVE_SPEED and moduleState.uiElements.DIVE_SPEED:GetValue()
                CONFIG.JUMP_VEL_THRES = moduleState.uiElements.JUMP_VEL_THRES and moduleState.uiElements.JUMP_VEL_THRES:GetValue()
                CONFIG.JUMP_COOLDOWN = moduleState.uiElements.JUMP_COOLDOWN and moduleState.uiElements.JUMP_COOLDOWN:GetValue()
                CONFIG.JUMP_RADIUS = moduleState.uiElements.JUMP_RADIUS and moduleState.uiElements.JUMP_RADIUS:GetValue()
                CONFIG.JUMP_MIN_HEIGHT_DIFF = moduleState.uiElements.JUMP_MIN_HEIGHT_DIFF and moduleState.uiElements.JUMP_MIN_HEIGHT_DIFF:GetValue()
                CONFIG.JUMP_POWER = moduleState.uiElements.JUMP_POWER and moduleState.uiElements.JUMP_POWER:GetValue()
                CONFIG.JUMP_HEIGHT = moduleState.uiElements.JUMP_HEIGHT and moduleState.uiElements.JUMP_HEIGHT:GetValue()
                CONFIG.INTERCEPT_DISTANCE = moduleState.uiElements.INTERCEPT_DISTANCE and moduleState.uiElements.INTERCEPT_DISTANCE:GetValue()
                CONFIG.INTERCEPT_SPEED_MULT = moduleState.uiElements.INTERCEPT_SPEED_MULT and moduleState.uiElements.INTERCEPT_SPEED_MULT:GetValue()
                CONFIG.TOUCH_RANGE = moduleState.uiElements.TOUCH_RANGE and moduleState.uiElements.TOUCH_RANGE:GetValue()
                CONFIG.NEAR_BALL_DIST = moduleState.uiElements.NEAR_BALL_DIST and moduleState.uiElements.NEAR_BALL_DIST:GetValue()
                CONFIG.INTERCEPT_PREDICT_TIME = moduleState.uiElements.INTERCEPT_PREDICT_TIME and moduleState.uiElements.INTERCEPT_PREDICT_TIME:GetValue()
                CONFIG.ZONE_WIDTH_MULTIPLIER = moduleState.uiElements.ZONE_WIDTH_MULTIPLIER and moduleState.uiElements.ZONE_WIDTH_MULTIPLIER:GetValue()
                CONFIG.ZONE_DEPTH = moduleState.uiElements.ZONE_DEPTH and moduleState.uiElements.ZONE_DEPTH:GetValue()
                CONFIG.ZONE_OFFSET_MULTIPLIER = moduleState.uiElements.ZONE_OFFSET_MULTIPLIER and moduleState.uiElements.ZONE_OFFSET_MULTIPLIER:GetValue()
                CONFIG.CORNER_DEFENSE_ENABLED = moduleState.uiElements.CORNER_DEFENSE_ENABLED and moduleState.uiElements.CORNER_DEFENSE_ENABLED:GetState()
                CONFIG.SHOW_TRAJECTORY = moduleState.uiElements.SHOW_TRAJECTORY and moduleState.uiElements.SHOW_TRAJECTORY:GetState()
                CONFIG.SHOW_ENDPOINT = moduleState.uiElements.SHOW_ENDPOINT and moduleState.uiElements.SHOW_ENDPOINT:GetState()
                CONFIG.SHOW_GOAL_CUBE = moduleState.uiElements.SHOW_GOAL_CUBE and moduleState.uiElements.SHOW_GOAL_CUBE:GetState()
                CONFIG.SHOW_ZONE = moduleState.uiElements.SHOW_ZONE and moduleState.uiElements.SHOW_ZONE:GetState()
                CONFIG.SHOW_BALL_BOX = moduleState.uiElements.SHOW_BALL_BOX and moduleState.uiElements.SHOW_BALL_BOX:GetState()
                CONFIG.TRAJECTORY_COLOR = moduleState.uiElements.TRAJECTORY_COLOR and moduleState.uiElements.TRAJECTORY_COLOR:GetValue()
                CONFIG.ENDPOINT_COLOR = moduleState.uiElements.ENDPOINT_COLOR and moduleState.uiElements.ENDPOINT_COLOR:GetValue()
                CONFIG.GOAL_CUBE_COLOR = moduleState.uiElements.GOAL_CUBE_COLOR and moduleState.uiElements.GOAL_CUBE_COLOR:GetValue()
                CONFIG.ZONE_COLOR = moduleState.uiElements.ZONE_COLOR and moduleState.uiElements.ZONE_COLOR:GetValue()
                CONFIG.BALL_BOX_COLOR = moduleState.uiElements.BALL_BOX_COLOR and moduleState.uiElements.BALL_BOX_COLOR:GetValue()
                CONFIG.BALL_BOX_JUMP_COLOR = moduleState.uiElements.BALL_BOX_JUMP_COLOR and moduleState.uiElements.BALL_BOX_JUMP_COLOR:GetValue()
                CONFIG.BALL_BOX_THREAT_COLOR = moduleState.uiElements.BALL_BOX_THREAT_COLOR and moduleState.uiElements.BALL_BOX_THREAT_COLOR:GetValue()
                CONFIG.BALL_BOX_HIGH_COLOR = moduleState.uiElements.BALL_BOX_HIGH_COLOR and moduleState.uiElements.BALL_BOX_HIGH_COLOR:GetValue()
                CONFIG.SMART_ROTATION_ENABLED = moduleState.uiElements.SMART_ROTATION_ENABLED and moduleState.uiElements.SMART_ROTATION_ENABLED:GetState()
                CONFIG.ROT_SMOOTH = moduleState.uiElements.ROT_SMOOTH and moduleState.uiElements.ROT_SMOOTH:GetValue()
                CONFIG.MIN_ROTATION_DIST = moduleState.uiElements.MIN_ROTATION_DIST and moduleState.uiElements.MIN_ROTATION_DIST:GetValue()
                CONFIG.MAX_ROTATION_ANGLE = moduleState.uiElements.MAX_ROTATION_ANGLE and moduleState.uiElements.MAX_ROTATION_ANGLE:GetValue()
                CONFIG.PRED_UPDATE_RATE = moduleState.uiElements.PRED_UPDATE_RATE and moduleState.uiElements.PRED_UPDATE_RATE:GetValue()
                CONFIG.AVOID_CORNERS = moduleState.uiElements.AVOID_CORNERS and moduleState.uiElements.AVOID_CORNERS:GetState()
                CONFIG.CENTER_BIAS_DIST = moduleState.uiElements.CENTER_BIAS_DIST and moduleState.uiElements.CENTER_BIAS_DIST:GetValue()
                CONFIG.GATE_COVERAGE = moduleState.uiElements.GATE_COVERAGE and moduleState.uiElements.GATE_COVERAGE:GetValue()
                
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
                                
                                notifyFunc("AutoGK", moduleState.enabled and "ON" or "OFF", true)
                            end
                        end)
                    end
                    
                    notifyFunc("AutoGK", "Enabled v10.0", true)
                else
                    cleanup()
                    notifyFunc("AutoGK", "Disabled", true)
                end
                
                notifyFunc("AutoGK", "Configuration synchronized", true)
            end
        })
    end
end

function AutoGKUltraModule:Destroy()
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
    
    cleanup()
    moduleState.enabled = false
    CONFIG.ENABLED = false
end

return AutoGKUltraModule
