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
    PRED_STEPS = 60,
    CURVE_MULT = 38, -- Увеличено для лучшего предикта закрутки
    DT = 1/120, -- Более точный шаг для закрученных ударов
    GRAVITY = 112,
    DRAG = 0.981,
    BOUNCE_XZ = 0.76,
    BOUNCE_Y = 0.65,
    
    -- Дистанции
    AGGRO_THRES = 55,
    PRESSURE_DIST = 44,
    DIVE_DIST = 26,
    TOUCH_RANGE = 20,
    NEAR_BALL_DIST = 5.0,
    
    -- Пороги
    DIVE_VEL_THRES = 24,
    JUMP_VEL_THRES = 24,
    HIGH_BALL_THRES = 2,
    JUMP_THRES = 1,
    
    -- Кулдауны
    DIVE_COOLDOWN = 0.9,
    JUMP_COOLDOWN = 0.6,
    
    -- Производительность
    PRED_UPDATE_RATE = 1,
    ROT_SMOOTH = 0.25,
    
    -- Размер ворот
    BIG_GOAL_THRESHOLD = 40,
    
    -- Перехват
    INTERCEPT_DISTANCE = 35,
    INTERCEPT_SPEED_MULT = 1.34,
    
    -- Прыжки
    JUMP_CHECK_HEIGHT = 0.6,
    JUMP_PREDICTION_STEPS = 20,
    JUMP_REACTION_TIME = 0.1,
    JUMP_VERTICAL_THRESHOLD = 0.1,
    GOAL_JUMP_SAFETY_MARGIN = 0.6,
    JUMP_RADIUS = 40,
    JUMP_MIN_HEIGHT_DIFF = 0.7,
    
    JUMP_HORIZONTAL_FORCE = 70,
    SMALL_GOAL_DIVE_DISTANCE = 5,
    BIG_GOAL_DIVE_DISTANCE = 10,
    DIVE_DURATION = 0.44,
    
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
    
    -- Новые настройки
    USE_ROTATION = true, -- Включение/выключение ротации
    DIVE_FIXED_ROTATION = true, -- Фиксированная ротация во время нырка
    PREDICT_CURVE_BETTER = true, -- Улучшенный предикт закрутки
    CORNER_DEFENSE_MODE = true, -- Защита от угловых
    MIN_CORNER_DISTANCE = 15, -- Минимальная дистанция для защиты углов
    CORNER_POSITION_BIAS = 0.7 -- Смещение к углу при угловых
}

-- Состояние модуля
local moduleState = {
    enabled = false,
    lastDiveTime = 0,
    lastJumpTime = 0,
    isDiving = false,
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
    lastRotationTime = 0,
    rotationCooldown = 0.1,
    isCornerAttack = false,
    cornerSide = 0, -- -1 = левый угол, 1 = правый угол
    diveTargetCFrame = nil, -- Фиксированный CFrame для нырка
    
    -- Визуальные объекты
    visualObjects = {},
    
    -- Цели
    GoalCFrame = nil,
    GoalForward = nil,
    GoalWidth = 0,
    GoalPosts = {},
    
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

-- Обновление целей
local function updateGoals()
    local isHPG = ws.Bools:FindFirstChild("HPG") and ws.Bools.HPG.Value == player
    local isAPG = ws.Bools:FindFirstChild("APG") and ws.Bools.APG.Value == player
    if not (isHPG or isAPG) then return false end
    
    local goalName = isHPG and "HomeGoal" or "AwayGoal"
    local goal = ws:FindFirstChild(goalName)
    
    if not goal or not goal:FindFirstChild("Frame") then return false end
    
    local frame = goal.Frame
    local left = frame:FindFirstChild("LeftPost")
    local right = frame:FindFirstChild("RightPost")
    local crossbar = frame:FindFirstChild("Crossbar")
    
    if not left or not right then return false end
    
    moduleState.GoalPosts = {
        LeftPost = left,
        RightPost = right,
        Crossbar = crossbar
    }
    
    local gcenter = (left.Position + right.Position) / 2
    local rightVec = (right.Position - left.Position).Unit
    moduleState.GoalForward = -rightVec:Cross(Vector3.new(0,1,0)).Unit
    moduleState.GoalCFrame = CFrame.fromMatrix(gcenter, rightVec, Vector3.new(0,1,0), moduleState.GoalForward)
    moduleState.GoalWidth = (right.Position - left.Position).Magnitude
    
    moduleState.isBigGoal = moduleState.GoalWidth > CONFIG.BIG_GOAL_THRESHOLD
    
    if moduleState.visualObjects.debugText then
        moduleState.visualObjects.debugText.Visible = true
        moduleState.visualObjects.debugText.Text = string.format("Goal Width: %.1f | Big Goal: %s", moduleState.GoalWidth, moduleState.isBigGoal and "YES" or "NO")
    end
    
    return true
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

-- УЛУЧШЕННЫЙ ПРЕДИКТ ТРАЕКТОРИИ С УЧЕТОМ ЗАКРУТКИ
local function predictTrajectory(ball)
    local points = {ball.Position}
    local pos, vel = ball.Position, ball.Velocity
    local dt = CONFIG.DT
    local gravity = CONFIG.GRAVITY
    local drag = CONFIG.DRAG
    local steps = CONFIG.PRED_STEPS
    local spinCurve = Vector3.new(0,0,0)
    local curveStrength = 1.0
    
    pcall(function()
        if ws.Bools.Curve and ws.Bools.Curve.Value then 
            -- Улучшенный расчет закрутки
            local curveMultiplier = CONFIG.CURVE_MULT
            if CONFIG.PREDICT_CURVE_BETTER then
                -- Учитываем скорость мяча для силы закрутки
                curveStrength = math.clamp(vel.Magnitude / 30, 0.5, 2.0)
                curveMultiplier = CONFIG.CURVE_MULT * curveStrength
            end
            
            -- Вектор закрутки с учетом направления удара
            local spinDirection = ball.CFrame.RightVector
            local velocityDirection = vel.Unit
            local angleBetween = math.acos(math.clamp(spinDirection:Dot(velocityDirection), -1, 1))
            
            -- Усиливаем закрутку если удар под углом
            if angleBetween > math.pi/4 then
                curveMultiplier = curveMultiplier * 1.5
            end
            
            spinCurve = spinDirection * curveMultiplier * 0.05
        end
        
        if ws.Bools.Header and ws.Bools.Header.Value then 
            -- Улучшенный расчет навеса
            local headerStrength = math.clamp(vel.Magnitude / 25, 0.5, 1.5)
            spinCurve = spinCurve + Vector3.new(0, 32 * headerStrength, 0) 
        end
    end)
    
    for i = 1, steps do
        local curveFade = 1 - (i/steps) * 0.7  -- Более плавное затухание закрутки
        local currentCurve = spinCurve * curveFade
        
        vel = vel * drag + currentCurve * dt
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
            vel = Vector3.new(vel.X * CONFIG.BOUNCE_XZ, math.abs(vel.Y) * CONFIG.BOUNCE_Y, vel.Z * CONFIG.BOUNCE_XZ)
            
            -- Уменьшаем закрутку после отскока
            if CONFIG.PREDICT_CURVE_BETTER then
                spinCurve = spinCurve * 0.5
            end
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

-- Определение угловой атаки
local function checkCornerAttack(ballPos, ballVel)
    if not moduleState.GoalCFrame then return false, 0 end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    
    -- Вектор от мяча к воротам
    local toGoal = (goalPos - ballPos) * Vector3.new(1,0,1)
    local distToGoal = toGoal.Magnitude
    
    -- Если мяч слишком далеко, не считаем угловой атакой
    if distToGoal > CONFIG.MIN_CORNER_DISTANCE then return false, 0 end
    
    -- Латеральное смещение мяча относительно центра ворот
    local lateral = (ballPos - goalPos):Dot(goalRight)
    local normalizedLateral = lateral / (moduleState.GoalWidth / 2)
    
    -- Определяем угол полета мяча
    local velDir = ballVel.Unit
    local toGoalDir = toGoal.Unit
    local angleToGoal = math.deg(math.acos(math.clamp(velDir:Dot(toGoalDir), -1, 1)))
    
    -- Проверяем условия для угловой атаки:
    -- 1. Мяч летит под углом к воротам
    -- 2. Мяч находится сбоку от ворот
    -- 3. Высота мяча достаточна для навеса
    local isHighBall = ballPos.Y > 5
    local isWideAngle = math.abs(normalizedLateral) > 0.6
    local isCurvedTrajectory = angleToGoal > 30
    
    if (isHighBall or isCurvedTrajectory) and isWideAngle then
        moduleState.isCornerAttack = true
        moduleState.cornerSide = normalizedLateral > 0 and 1 or -1
        return true, moduleState.cornerSide
    end
    
    moduleState.isCornerAttack = false
    return false, 0
end

-- Позиционирование для защиты от угловых
local function getCornerDefensePosition(root, ballPos, cornerSide)
    if not moduleState.GoalCFrame then return root.Position end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalForward = moduleState.GoalForward
    local goalRight = moduleState.GoalCFrame.RightVector
    
    -- Базовое положение - ближе к углу который атакуют
    local baseDistance = CONFIG.STAND_DIST * 1.2
    local basePos = goalPos + goalForward * baseDistance
    
    -- Смещение к углу
    local lateralOffset = cornerSide * moduleState.GoalWidth * 0.35 * CONFIG.CORNER_POSITION_BIAS
    local targetPos = basePos + goalRight * lateralOffset
    
    -- Не даем уйти слишком далеко от ворот
    local maxLateral = moduleState.GoalWidth * 0.4
    if math.abs(lateralOffset) > maxLateral then
        targetPos = basePos + goalRight * (maxLateral * (lateralOffset > 0 and 1 or -1))
    end
    
    -- Смотрим на мяч
    local toBall = (ballPos - targetPos) * Vector3.new(1,0,1)
    if toBall.Magnitude > 1 then
        local lookCFrame = CFrame.lookAt(targetPos, ballPos)
        moduleState.smoothCFrame = lookCFrame
    end
    
    return targetPos
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
        drawCube(moduleState.visualObjects.LimitCube, flatCF, Vector3.new(moduleState.GoalWidth * CONFIG.ZONE_WIDTH_MULTIPLIER, CONFIG.ZONE_HEIGHT, CONFIG.ZONE_DEPTH), CONFIG.ZONE_COLOR)
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

-- Умное позиционирование с учетом угловых атак
local function calculateSmartPosition(ballPos, ownerRoot, isBallControlled, endpoint, ballVel)
    if not moduleState.GoalCFrame then 
        return moduleState.GoalCFrame.Position + moduleState.GoalForward * CONFIG.STAND_DIST 
    end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    local goalForward = moduleState.GoalForward
    
    -- Проверяем угловую атаку
    local isCornerAttack, cornerSide = checkCornerAttack(ballPos, ballVel)
    if CONFIG.CORNER_DEFENSE_MODE and isCornerAttack then
        return getCornerDefensePosition(ownerRoot or ballPos, ballPos, cornerSide)
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

-- УЛУЧШЕННОЕ УМНОЕ ВРАЩЕНИЕ (ТОЛЬКО КОГДА НУЖНО)
local function smartRotation(root, ballPos, ballVel, isDiving, diveTarget, isMyBall)
    -- Не вращаемся если отключено или если это наш мяч
    if not CONFIG.USE_ROTATION or isMyBall or moduleState.isDiving then 
        if moduleState.currentGyro then 
            pcall(function() moduleState.currentGyro:Destroy() end) 
            moduleState.currentGyro = nil 
        end
        return 
    end
    
    -- Кулдаун на вращение чтобы не менять его слишком часто
    if tick() - moduleState.lastRotationTime < moduleState.rotationCooldown then
        return
    end
    
    -- Фиксированная ротация во время нырка
    if isDiving and CONFIG.DIVE_FIXED_ROTATION then
        if moduleState.diveTargetCFrame then
            if moduleState.currentGyro then 
                pcall(function() moduleState.currentGyro:Destroy() end) 
                moduleState.currentGyro = nil 
            end
            
            moduleState.currentGyro = Instance.new("BodyGyro")
            moduleState.currentGyro.Parent = root
            moduleState.currentGyro.P = 1200000
            moduleState.currentGyro.MaxTorque = Vector3.new(0, 100000, 0)
            moduleState.currentGyro.CFrame = moduleState.diveTargetCFrame
            game.Debris:AddItem(moduleState.currentGyro, CONFIG.DIVE_DURATION)
        end
        return
    end
    
    -- Ротация нужна только в определенных ситуациях:
    -- 1. Мяч близко и летит в ворота
    -- 2. Мы в позиции для защиты
    local distToBall = (root.Position - ballPos).Magnitude
    local ballSpeed = ballVel.Magnitude
    
    -- Определяем нужно ли вращение
    local shouldRotate = false
    
    if ballSpeed > 15 and distToBall < 20 then
        -- Мяч быстрый и близко - нужно смотреть на мяч
        shouldRotate = true
    elseif moduleState.isCornerAttack then
        -- При угловой атаке всегда смотрим на мяч
        shouldRotate = true
    elseif ballPos.Y > 5 and distToBall < 30 then
        -- Высокий мяч рядом - нужно следить
        shouldRotate = true
    end
    
    if not shouldRotate then
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
    
    -- При быстром мяче смотрим немного вперед по траектории
    if ballSpeed > 20 then
        local predictionDistance = math.min(ballSpeed * 0.2, 10)
        targetLookPos = ballPos + ballVel.Unit * predictionDistance
    end
    
    local targetLook = CFrame.lookAt(root.Position, targetLookPos)
    moduleState.smoothCFrame = moduleState.smoothCFrame:Lerp(targetLook, CONFIG.ROT_SMOOTH)
    
    if moduleState.currentGyro then 
        pcall(function() moduleState.currentGyro:Destroy() end) 
        moduleState.currentGyro = nil 
    end
    
    moduleState.currentGyro = Instance.new("BodyGyro")
    moduleState.currentGyro.Parent = root
    moduleState.currentGyro.P = 6000000
    moduleState.currentGyro.MaxTorque = Vector3.new(0, math.huge, 0)
    moduleState.currentGyro.CFrame = moduleState.smoothCFrame
    game.Debris:AddItem(moduleState.currentGyro, 0.1)
    
    moduleState.lastRotationTime = tick()
end

-- Выполнение прыжка
local function performJump(char, hum)
    if tick() - moduleState.lastJumpTime < CONFIG.JUMP_COOLDOWN or moduleState.jumpAnimationPlaying then return false end
    
    moduleState.lastJumpTime = tick()
    moduleState.jumpAnimationPlaying = true
    
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
    
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    task.delay(0.8, function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        moduleState.jumpAnimationPlaying = false
    end)
    
    return true
end

-- Проверка необходимости перехвата
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
    
    local timeToReach = distToBall / (CONFIG.AGGRESSIVE_SPEED * CONFIG.INTERCEPT_SPEED_MULT)
    local timeToGoal = distToGoalLine / ballVelMag
    
    if timeToGoal < timeToReach * 1.2 then
        return true
    end
    
    return false
end

-- Выполнение перехвата
local function performIntercept(root, char, ball)
    moduleState.lastInterceptTime = tick()
    
    local ballPos = ball.Position
    local ballVel = ball.Velocity
    local interceptPoint = ballPos + ballVel.Unit * 3
    
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
    
    for _, hand in {char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand")} do
        if hand and (hand.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
            firetouchinterest(hand, ball, 0)
            task.wait(0.1)
            firetouchinterest(hand, ball, 0)
            task.wait(0.1)
            firetouchinterest(hand, ball, 0)
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
            return true
        end
    end
    
    if endpoint then
        local timeToReachBall = distToBall / CONFIG.AGGRESSIVE_SPEED
        local ballTravelDist = (endpoint - ballPos).Magnitude
        local timeToEndpoint = ballTravelDist / velMag
        
        if timeToEndpoint < timeToReachBall * 1.4 then
            return true
        end
    end
    
    return false
end

-- УЛУЧШЕННОЕ ВЫПОЛНЕНИЕ НЫРКА С ФИКСИРОВАННОЙ РОТАЦИЕЙ
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
    
    -- ФИКСИРУЕМ РОТАЦИЮ НА ВРЕМЯ НЫРКА
    if CONFIG.DIVE_FIXED_ROTATION then
        -- Запоминаем CFrame куда смотреть (на мяч или точку перехвата)
        local lookPos = targetPos
        moduleState.diveTargetCFrame = CFrame.lookAt(root.Position, lookPos)
    end
    
    local char = hum.Parent
    local animations = ReplicatedStorage:WaitForChild("Animations")
    local gkAnimations = animations.GK
    
    local diveAnim
    local diveDistance = moduleState.isBigGoal and CONFIG.BIG_GOAL_DIVE_DISTANCE or CONFIG.SMALL_GOAL_DIVE_DISTANCE
    local diveSpeed = diveDistance / CONFIG.DIVE_DURATION
    
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
    
    local diveBV = Instance.new("BodyVelocity")
    diveBV.Parent = root
    diveBV.MaxForce = Vector3.new(1e7, 0, 1e7)
    
    if dir == "Right" then
        diveBV.Velocity = root.CFrame.RightVector * diveSpeed
    else
        diveBV.Velocity = root.CFrame.RightVector * -diveSpeed
    end
    
    game.Debris:AddItem(diveBV, CONFIG.DIVE_DURATION)
    
    -- ФИКСИРОВАННАЯ РОТАЦИЯ НА ВРЕМЯ НЫРКА
    if CONFIG.DIVE_FIXED_ROTATION and moduleState.diveTargetCFrame then
        local diveGyro = Instance.new("BodyGyro")
        diveGyro.Name = "GKGyro"
        diveGyro.Parent = root
        diveGyro.P = 1200000
        diveGyro.MaxTorque = Vector3.new(0, 100000, 0)
        diveGyro.CFrame = moduleState.diveTargetCFrame
        game.Debris:AddItem(diveGyro, CONFIG.DIVE_DURATION)
    end
    
    if ball then
        for _, partName in pairs({"HumanoidRootPart", "RightHand", "LeftHand"}) do
            local part = char:FindFirstChild(partName)
            if part then
                firetouchinterest(part, ball, 0)
                task.wait(0.1)
                firetouchinterest(part, ball, 0)
                task.wait(0.1)
                firetouchinterest(part, ball, 0)
            end
        end
    end
    
    task.delay(CONFIG.DIVE_DURATION, function() 
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) 
    end)
    
    task.delay(CONFIG.DIVE_DURATION + 0.1, function() 
        moduleState.isDiving = false 
        moduleState.diveAnimationPlaying = false
        moduleState.diveTargetCFrame = nil -- Сбрасываем фиксированную ротацию
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
        
        if velMag > 20 and moduleState.lastBallVelMag <= 20 then
            moduleState.cachedPoints = nil
        end
        moduleState.lastBallVelMag = velMag
        
        local isBallControlled = hasWeld and owner ~= player
        local shouldPredict = not isMyBall and not hasWeld
        
        if shouldPredict and (moduleState.frameCounter % CONFIG.PRED_UPDATE_RATE == 0 or not moduleState.cachedPoints) then
            moduleState.cachedPoints = predictTrajectory(ball)
        elseif not shouldPredict then
            moduleState.cachedPoints = nil
        end
        
        local endpoint = moduleState.cachedPoints and moduleState.cachedPoints[#moduleState.cachedPoints]
        
        if not isMyBall and not moduleState.isDiving then
            local targetPos = calculateSmartPosition(ball.Position, oRoot, isBallControlled, endpoint, ball.Velocity)
            local urgentDistance = moduleState.isBigGoal and 10 or 5
            local isUrgent = (endpoint and (endpoint - moduleState.GoalCFrame.Position):Dot(moduleState.GoalForward) < urgentDistance) or (velMag > 30)
            
            moveToPosition(root, targetPos, ball.Position, velMag, isUrgent)
            
            -- Умное вращение только когда нужно
            smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall)
            
            if tick() - moduleState.lastActionTime > moduleState.actionCooldown then
                local goalkeeperHitbox = getGoalkeeperHitbox(char)
                
                moduleState.willJump = shouldJumpSimple(root, ball.Position, goalkeeperHitbox)
                
                if shouldIntercept(root, ball, endpoint) then
                    performIntercept(root, char, ball)
                    moduleState.lastActionTime = tick()
                elseif shouldDive(root, ball, velMag, endpoint) then
                    performDive(root, hum, endpoint or ball.Position, ball.Position.Y, ball)
                    moduleState.lastActionTime = tick()
                elseif shouldBlock(root, ball, velMag) then
                    for _, hand in {char:FindFirstChild("RightHand"), char:FindFirstChild("LeftHand")} do
                        if hand and (hand.Position - ball.Position).Magnitude < CONFIG.TOUCH_RANGE then
                            firetouchinterest(hand, ball, 0)
                            task.wait(0.1)
                            firetouchinterest(hand, ball, 0)
                            task.wait(0.1)
                            firetouchinterest(hand, ball, 0)
                            break
                        end
                    end
                    moduleState.lastActionTime = tick()
                elseif moduleState.willJump then
                    performJump(char, hum)
                    moduleState.lastActionTime = tick()
                end
            end
        else
            if moduleState.currentBV then 
                pcall(function() moduleState.currentBV:Destroy() end) 
                moduleState.currentBV = nil 
            end
            -- При нашем мяче не вращаемся
            if not isMyBall then
                smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall)
            end
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
            drawCube(moduleState.visualObjects.GoalCube, moduleState.GoalCFrame, Vector3.new(moduleState.GoalWidth, 8, 2), CONFIG.GOAL_CUBE_COLOR)
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
        
        -- Отрисовка бокса мяча
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
    moduleState.diveAnimationPlaying = false
    moduleState.jumpAnimationPlaying = false
    moduleState.cachedPoints = nil
    moduleState.willJump = false
    moduleState.isCornerAttack = false
    moduleState.diveTargetCFrame = nil
end

local AutoGKUltraModule = {}

function AutoGKUltraModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
    moduleState.notify = notifyFunc
    
    if UI.Sections.AutoGoalKeeper then
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalKeeper" })
        
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
                    notifyFunc("Syllinse", "AutoGK Enabled", true)
                else
                    cleanup()
                    notifyFunc("Syllinse", "AutoGK Disabled", true)
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
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки прыжка
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
            Name = "Height Difference",
            Minimum = 0.1,
            Maximum = 3.0,
            Default = CONFIG.JUMP_MIN_HEIGHT_DIFF,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_MIN_HEIGHT_DIFF = v end
        }, 'AutoGKUltraJumpMinHeightDiff')
        
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
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Улучшенные настройки
        UI.Sections.AutoGoalKeeper:Header({ Name = "Improved Settings" })
        
        moduleState.uiElements.USE_ROTATION = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Use Rotation",
            Default = CONFIG.USE_ROTATION,
            Callback = function(v) 
                CONFIG.USE_ROTATION = v 
            end
        }, 'AutoGKUltraUseRotation')
        
        moduleState.uiElements.DIVE_FIXED_ROTATION = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Dive Fixed Rotation",
            Default = CONFIG.DIVE_FIXED_ROTATION,
            Callback = function(v) 
                CONFIG.DIVE_FIXED_ROTATION = v 
            end
        }, 'AutoGKUltraDiveFixedRotation')
        
        moduleState.uiElements.PREDICT_CURVE_BETTER = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Better Curve Predict",
            Default = CONFIG.PREDICT_CURVE_BETTER,
            Callback = function(v) 
                CONFIG.PREDICT_CURVE_BETTER = v 
            end
        }, 'AutoGKUltraPredictCurveBetter')
        
        moduleState.uiElements.CORNER_DEFENSE_MODE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Corner Defense Mode",
            Default = CONFIG.CORNER_DEFENSE_MODE,
            Callback = function(v) 
                CONFIG.CORNER_DEFENSE_MODE = v 
            end
        }, 'AutoGKUltraCornerDefenseMode')
        
        moduleState.uiElements.CORNER_POSITION_BIAS = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Corner Position Bias",
            Minimum = 0.3,
            Maximum = 1.0,
            Default = CONFIG.CORNER_POSITION_BIAS,
            Precision = 2,
            Callback = function(v) CONFIG.CORNER_POSITION_BIAS = v end
        }, 'AutoGKUltraCornerPositionBias')
        
        moduleState.uiElements.CURVE_MULT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Curve Multiplier",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.CURVE_MULT,
            Precision = 1,
            Callback = function(v) CONFIG.CURVE_MULT = v end
        }, 'AutoGKUltraCurveMult')
        
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
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки производительности
        UI.Sections.AutoGoalKeeper:Header({ Name = "Performance Settings" })
        
        moduleState.uiElements.ROT_SMOOTH = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Rotation Smoothness",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = CONFIG.ROT_SMOOTH,
            Precision = 2,
            Callback = function(v) CONFIG.ROT_SMOOTH = v end
        }, 'AutoGKUltraRotSmooth')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Информация
        UI.Sections.AutoGoalKeeper:Header({ Name = "Settings Information" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "Improved Settings Guide",
            Body = [[
Movement Settings:
1 Normal Speed: Base movement speed when positioning
2 Aggressive Speed: Speed used for urgent situations like intercepts
3 Stand Distance: How far to stand from the goal line (2.8 = good default)
4 Minimum Distance: Stop moving when this close to target position

Dive Settings:
5 Dive Distance: Maximum distance at which the GK will attempt a dive
6 Dive Velocity Threshold: Minimum ball speed required to trigger a dive
7 Dive Cooldown: Time that must pass between consecutive dives

Jump Settings:
8 Jump Velocity Threshold: Ball speed needed to consider jumping
9 Jump Cooldown: Recovery time between jumps
10 Jump Radius: Maximum distance from ball to attempt a jump
11 Jump Min Height Diff: Required height difference between ball and GK to jump

Intercept & Touch Settings:
12 Intercept Distance: Maximum range for intercepting the ball
13 Intercept Speed Multiplier: Speed boost applied during intercepts
14 Touch Distance: How far the GK's hands can reach to touch the ball
15 Near Ball Distance: Auto-block when ball is within this range

Defense Zone Settings:
16 Zone Width Multiplier: Controls width of defensive area (higher = wider)
17 Zone Depth: How far forward the defensive zone extends

Improved Settings:
18 Use Rotation: Enable/disable head rotation (disable for better dive accuracy)
19 Dive Fixed Rotation: Fix rotation during dive to prevent missing saves
20 Better Curve Predict: Improved prediction for curved shots
21 Corner Defense Mode: Better positioning for corner attacks
22 Corner Position Bias: How close to stand to corner during corner attacks
23 Curve Multiplier: Strength of curve prediction

Visual Settings:
24 Toggle visibility of different visual elements
25 Helps with debugging and understanding AI behavior

Color Settings:
26 Customize colors for all visual elements
27 Helps distinguish between different elements

Performance Settings:
28 Rotation Smoothness: How smoothly the GK rotates (higher = smoother but slower response)
]]
        })
        
    
    -- Секция синхронизации в Config
    if UI.Tabs.Config then
        local syncSection = UI.Tabs.Config:Section({Name = 'AutoGK ULTRA Sync', Side = 'Right'})
        
        syncSection:Header({ Name = "AutoGK ULTRA Config Sync" })
        
        syncSection:Button({
            Name = "Sync Configuration Now",
            Callback = function()
                -- Правильная синхронизация как в примере - каждый элемент отдельно
                CONFIG.ENABLED = moduleState.uiElements.Enabled and moduleState.uiElements.Enabled:GetState()
                CONFIG.SPEED = moduleState.uiElements.SPEED and moduleState.uiElements.SPEED:GetValue()
                CONFIG.AGGRESSIVE_SPEED = moduleState.uiElements.AGGRESSIVE_SPEED and moduleState.uiElements.AGGRESSIVE_SPEED:GetValue()
                CONFIG.STAND_DIST = moduleState.uiElements.STAND_DIST and moduleState.uiElements.STAND_DIST:GetValue()
                CONFIG.MIN_DIST = moduleState.uiElements.MIN_DIST and moduleState.uiElements.MIN_DIST:GetValue() 
                CONFIG.DIVE_DIST = moduleState.uiElements.DIVE_DIST and moduleState.uiElements.DIVE_DIST:GetValue()
                CONFIG.DIVE_VEL_THRES = moduleState.uiElements.DIVE_VEL_THRES and moduleState.uiElements.DIVE_VEL_THRES:GetValue()
                CONFIG.DIVE_COOLDOWN = moduleState.uiElements.DIVE_COOLDOWN and moduleState.uiElements.DIVE_COOLDOWN:GetValue()
                CONFIG.JUMP_VEL_THRES = moduleState.uiElements.JUMP_VEL_THRES and moduleState.uiElements.JUMP_VEL_THRES:GetValue()
                CONFIG.JUMP_COOLDOWN = moduleState.uiElements.JUMP_COOLDOWN and moduleState.uiElements.JUMP_COOLDOWN:GetValue()
                CONFIG.JUMP_RADIUS = moduleState.uiElements.JUMP_RADIUS and moduleState.uiElements.JUMP_RADIUS:GetValue()
                CONFIG.JUMP_MIN_HEIGHT_DIFF = moduleState.uiElements.JUMP_MIN_HEIGHT_DIFF and moduleState.uiElements.JUMP_MIN_HEIGHT_DIFF:GetValue()
                CONFIG.INTERCEPT_DISTANCE = moduleState.uiElements.INTERCEPT_DISTANCE and moduleState.uiElements.INTERCEPT_DISTANCE:GetValue()
                CONFIG.INTERCEPT_SPEED_MULT = moduleState.uiElements.INTERCEPT_SPEED_MULT and moduleState.uiElements.INTERCEPT_SPEED_MULT:GetValue()
                CONFIG.TOUCH_RANGE = moduleState.uiElements.TOUCH_RANGE and moduleState.uiElements.TOUCH_RANGE:GetValue()
                CONFIG.NEAR_BALL_DIST = moduleState.uiElements.NEAR_BALL_DIST and moduleState.uiElements.NEAR_BALL_DIST:GetValue()
                CONFIG.ZONE_WIDTH_MULTIPLIER = moduleState.uiElements.ZONE_WIDTH_MULTIPLIER and moduleState.uiElements.ZONE_WIDTH_MULTIPLIER:GetValue()
                CONFIG.ZONE_DEPTH = moduleState.uiElements.ZONE_DEPTH and moduleState.uiElements.ZONE_DEPTH:GetValue()
                CONFIG.ZONE_OFFSET_MULTIPLIER = moduleState.uiElements.ZONE_OFFSET_MULTIPLIER and moduleState.uiElements.ZONE_OFFSET_MULTIPLIER:GetValue()
                CONFIG.USE_ROTATION = moduleState.uiElements.USE_ROTATION and moduleState.uiElements.USE_ROTATION:GetState()
                CONFIG.DIVE_FIXED_ROTATION = moduleState.uiElements.DIVE_FIXED_ROTATION and moduleState.uiElements.DIVE_FIXED_ROTATION:GetState()
                CONFIG.PREDICT_CURVE_BETTER = moduleState.uiElements.PREDICT_CURVE_BETTER and moduleState.uiElements.PREDICT_CURVE_BETTER:GetState()
                CONFIG.CORNER_DEFENSE_MODE = moduleState.uiElements.CORNER_DEFENSE_MODE and moduleState.uiElements.CORNER_DEFENSE_MODE:GetState()
                CONFIG.CORNER_POSITION_BIAS = moduleState.uiElements.CORNER_POSITION_BIAS and moduleState.uiElements.CORNER_POSITION_BIAS:GetValue()
                CONFIG.CURVE_MULT = moduleState.uiElements.CURVE_MULT and moduleState.uiElements.CURVE_MULT:GetValue()
                CONFIG.SHOW_TRAJECTORY = moduleState.uiElements.SHOW_TRAJECTORY and moduleState.uiElements.SHOW_TRAJECTORY:GetState()
                CONFIG.SHOW_ENDPOINT = moduleState.uiElements.SHOW_ENDPOINT and moduleState.uiElements.SHOW_ENDPOINT:GetState()
                CONFIG.SHOW_GOAL_CUBE = moduleState.uiElements.SHOW_GOAL_CUBE and moduleState.uiElements.SHOW_GOAL_CUBE:GetState()
                CONFIG.SHOW_ZONE = moduleState.uiElements.SHOW_ZONE and moduleState.uiElements.SHOW_ZONE:GetState()
                CONFIG.SHOW_BALL_BOX = moduleState.uiElements.SHOW_BALL_BOX and moduleState.uiElements.SHOW_BALL_BOX:GetState()
                CONFIG.ROT_SMOOTH = moduleState.uiElements.ROT_SMOOTH and moduleState.uiElements.ROT_SMOOTH:GetValue()
                
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
                                    notifyFunc("AutoGK", moduleState.enabled and "ON" or "OFF", true)
                                end
                            end
                        end)
                    end
                    
                else
                    cleanup()
                end
                
                notifyFunc("Syllinse", "Configuration synchronized", true)
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
