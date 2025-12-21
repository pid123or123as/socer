-- Улучшенный модуль AutoGK ULTRA
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
    CURVE_MULT = 42, -- Увеличен для лучшего отслеживания закрученных ударов
    CURVE_FORCE_MULT = 0.05, -- Новый параметр для силы закрутки
    DT = 1/180,
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
    
    -- Улучшенное позиционирование для углов
    CORNER_PROTECTION_DISTANCE = 6.5, -- Дистанция защиты углов
    CORNER_ADVANCE_DISTANCE = 4.2, -- Насколько выдвигаться для защиты углов
    
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
    BALL_BOX_SAFE_COLOR = Color3.new(0, 1, 0)
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
    
    -- Новые параметры для улучшения ротации
    lockRotationDuringDive = false,
    diveStartRotation = nil,
    rotationEnabled = true,
    
    -- Трекер для закрученных ударов
    curveTracker = {
        lastCurveTime = 0,
        curveIntensity = 0,
        curveDirection = Vector3.new(0, 0, 0)
    },
    
    -- Трекер для угловых атак
    cornerAttackTracker = {
        lastCornerTime = 0,
        isCornerAttack = false,
        cornerSide = 0, -- -1 левый, 1 правый
        cornerProtectionActive = false
    },
    
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

-- УЛУЧШЕННОЕ: Предсказание траектории с учетом закрутки
local function predictTrajectory(ball)
    local points = {ball.Position}
    local pos, vel = ball.Position, ball.Velocity
    local dt = CONFIG.DT
    local gravity = CONFIG.GRAVITY
    local drag = CONFIG.DRAG
    local steps = CONFIG.PRED_STEPS
    
    -- Улучшенная система отслеживания закрутки
    local spinCurve = Vector3.new(0,0,0)
    local curveForce = CONFIG.CURVE_FORCE_MULT
    
    pcall(function()
        if ws.Bools.Curve and ws.Bools.Curve.Value then 
            local curveTime = tick()
            local timeSinceLastCurve = curveTime - moduleState.curveTracker.lastCurveTime
            
            -- Определяем интенсивность закрутки
            local curveIntensity = CONFIG.CURVE_MULT * 0.04
            
            -- Учитываем направление закрутки
            spinCurve = ball.CFrame.RightVector * curveIntensity
            moduleState.curveTracker.curveIntensity = curveIntensity
            moduleState.curveTracker.curveDirection = ball.CFrame.RightVector
            moduleState.curveTracker.lastCurveTime = curveTime
            
            -- Усиливаем эффект закрутки для дальних ударов
            local ballSpeed = vel.Magnitude
            if ballSpeed > 25 then
                curveForce = CONFIG.CURVE_FORCE_MULT * 1.3
            end
        end
        
        if ws.Bools.Header and ws.Bools.Header.Value then 
            spinCurve = spinCurve + Vector3.new(0, 32, 0) 
        end
    end)
    
    -- Если была недавняя закрутка, добавляем остаточный эффект
    if tick() - moduleState.curveTracker.lastCurveTime < 0.5 then
        local fadeFactor = 1 - ((tick() - moduleState.curveTracker.lastCurveTime) / 0.5)
        spinCurve = spinCurve + moduleState.curveTracker.curveDirection * moduleState.curveTracker.curveIntensity * fadeFactor * 0.5
    end
    
    for i = 1, steps do
        local curveFade = 1 - (i/steps) * 0.7 -- Увеличенный затухающий эффект
        vel = vel * drag + spinCurve * dt * curveFade * curveForce
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

-- УЛУЧШЕННОЕ: Обнаружение угловых атак
local function detectCornerAttack(ballPos, ballVel)
    if not moduleState.GoalCFrame then return false end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    local goalForward = moduleState.GoalForward
    
    -- Позиция мяча относительно ворот
    local toGoal = ballPos - goalPos
    local lateralDist = toGoal:Dot(goalRight)
    local forwardDist = toGoal:Dot(goalForward)
    
    -- Угловая атака если мяч сбоку и летит в сторону ворот
    local isCornerAttack = false
    local cornerSide = 0
    
    -- Проверяем, находится ли мяч в зоне угловой атаки
    if math.abs(lateralDist) > moduleState.GoalWidth * 0.35 and forwardDist > -5 and forwardDist < 15 then
        local velTowardGoal = ballVel:Dot(-goalForward)
        local lateralVel = ballVel:Dot(goalRight)
        
        -- Мяч должен лететь в сторону ворот и иметь боковую составляющую
        if velTowardGoal > 10 and math.abs(lateralVel) > 5 then
            isCornerAttack = true
            cornerSide = lateralDist > 0 and 1 or -1
            
            -- Обновляем трекер
            moduleState.cornerAttackTracker.lastCornerTime = tick()
            moduleState.cornerAttackTracker.isCornerAttack = true
            moduleState.cornerAttackTracker.cornerSide = cornerSide
            moduleState.cornerAttackTracker.cornerProtectionActive = true
        end
    end
    
    -- Сбрасываем состояние если прошло время
    if tick() - moduleState.cornerAttackTracker.lastCornerTime > 2.0 then
        moduleState.cornerAttackTracker.isCornerAttack = false
        moduleState.cornerAttackTracker.cornerProtectionActive = false
    end
    
    return isCornerAttack, cornerSide
end

-- УЛУЧШЕННОЕ: Умное позиционирование с учетом углов
local function calculateSmartPosition(ballPos, ownerRoot, isBallControlled, endpoint, ballVel)
    if not moduleState.GoalCFrame then 
        return moduleState.GoalCFrame.Position + moduleState.GoalForward * CONFIG.STAND_DIST 
    end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    local goalForward = moduleState.GoalForward
    
    -- Проверяем угловую атаку
    local isCornerAttack, cornerSide = detectCornerAttack(ballPos, ballVel)
    
    -- Если обнаружена угловая атака, используем специальную позицию
    if isCornerAttack then
        local advanceDistance = CONFIG.CORNER_ADVANCE_DISTANCE
        local lateralOffset = goalRight * (cornerSide * moduleState.GoalWidth * 0.4)
        
        -- Позиция для защиты угла
        local cornerPos = goalPos + goalForward * advanceDistance + lateralOffset
        
        -- Не подходим слишком близко к углу
        local toGoal = cornerPos - goalPos
        local lateralDist = math.abs(toGoal:Dot(goalRight))
        
        if lateralDist > moduleState.GoalWidth * 0.45 then
            cornerPos = goalPos + goalForward * advanceDistance + goalRight * (cornerSide * moduleState.GoalWidth * 0.45)
        end
        
        return cornerPos
    end
    
    -- Стандартная логика позиционирования
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

-- УЛУЧШЕННОЕ: Умное вращение с фиксацией во время нырка
local function smartRotation(root, ballPos, ballVel, isDiving, diveTarget, isMyBall)
    if isMyBall then 
        moduleState.rotationEnabled = false
        if moduleState.currentGyro then 
            pcall(function() moduleState.currentGyro:Destroy() end) 
            moduleState.currentGyro = nil 
        end
        return 
    end
    
    -- Отключаем ротацию во время нырка
    if moduleState.lockRotationDuringDive then
        if moduleState.diveStartRotation then
            if moduleState.currentGyro then 
                pcall(function() moduleState.currentGyro:Destroy() end) 
                moduleState.currentGyro = nil 
            end
            
            moduleState.currentGyro = Instance.new("BodyGyro")
            moduleState.currentGyro.Parent = root
            moduleState.currentGyro.P = 8000000 -- Увеличенный P для жесткой фиксации
            moduleState.currentGyro.MaxTorque = Vector3.new(0, math.huge, 0)
            moduleState.currentGyro.CFrame = moduleState.diveStartRotation
            game.Debris:AddItem(moduleState.currentGyro, 0.05)
        end
        return
    end
    
    -- Включаем ротацию только когда это нужно
    local shouldRotate = false
    local targetLookPos = ballPos
    
    -- Определяем, нужно ли вращение
    if ballVel.Magnitude > 8 then -- Мяч движется
        shouldRotate = true
        if ballVel.Magnitude > 15 then -- Быстрый мяч - смотрим дальше
            local predictionPoint = ballPos + ballVel.Unit * 8
            targetLookPos = predictionPoint
        end
    elseif (root.Position - ballPos).Magnitude < 10 then -- Мяч близко
        shouldRotate = true
    end
    
    if not shouldRotate then
        moduleState.rotationEnabled = false
        if moduleState.currentGyro then 
            pcall(function() moduleState.currentGyro:Destroy() end) 
            moduleState.currentGyro = nil 
        end
        return
    end
    
    moduleState.rotationEnabled = true
    
    if not moduleState.smoothCFrame then 
        moduleState.smoothCFrame = root.CFrame 
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

-- УЛУЧШЕННОЕ: Выполнение нырка с фиксацией ротации
local function performDive(root, hum, targetPos, ballHeight, ball)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving or moduleState.diveAnimationPlaying then return end
    
    moduleState.isDiving = true
    moduleState.diveAnimationPlaying = true
    moduleState.lastDiveTime = tick()
    
    -- Фиксируем ротацию перед нырком
    moduleState.lockRotationDuringDive = true
    moduleState.diveStartRotation = root.CFrame
    
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
    
    local diveGyro = Instance.new("BodyGyro")
    diveGyro.Name = "GKGyro"
    diveGyro.Parent = root
    diveGyro.P = 1200000
    diveGyro.MaxTorque = Vector3.new(0, 100000, 0)
    diveGyro.CFrame = CFrame.lookAt(root.Position, targetPos)
    game.Debris:AddItem(diveGyro, CONFIG.DIVE_DURATION)
    
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
        moduleState.lockRotationDuringDive = false
        moduleState.diveStartRotation = nil
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
            
            if moduleState.isDiving then
                smartRotation(root, ball.Position, ball.Velocity, true, endpoint, isMyBall)
            else
                smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall)
            end
            
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
            smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall)
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
    moduleState.lockRotationDuringDive = false
    moduleState.diveStartRotation = nil
    moduleState.rotationEnabled = false
    moduleState.curveTracker = {
        lastCurveTime = 0,
        curveIntensity = 0,
        curveDirection = Vector3.new(0, 0, 0)
    }
    moduleState.cornerAttackTracker = {
        lastCornerTime = 0,
        isCornerAttack = false,
        cornerSide = 0,
        cornerProtectionActive = false
    }
end


local AutoGKUltraModule = {}

function AutoGKUltraModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
    moduleState.notify = notifyFunc
    
    if UI.Sections.AutoGoalKeeper then
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalKeeper ULTRA v9.7" })
        
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
                    notifyFunc("Syllinse", "AutoGK ULTRA v9.7 Enabled", true)
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
        
        moduleState.uiElements.CORNER_PROTECTION_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Corner Protection",
            Minimum = 4.0,
            Maximum = 10.0,
            Default = CONFIG.CORNER_PROTECTION_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.CORNER_PROTECTION_DISTANCE = v end
        }, 'AutoGKUltraCornerProtection')
        
        moduleState.uiElements.CORNER_ADVANCE_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Corner Advance",
            Minimum = 2.0,
            Maximum = 8.0,
            Default = CONFIG.CORNER_ADVANCE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.CORNER_ADVANCE_DISTANCE = v end
        }, 'AutoGKUltraCornerAdvance')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- Настройки закрученных ударов
        UI.Sections.AutoGoalKeeper:Header({ Name = "Curve Shot Settings" })
        
        moduleState.uiElements.CURVE_MULT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Curve Multiplier",
            Minimum = 25,
            Maximum = 60,
            Default = CONFIG.CURVE_MULT,
            Precision = 1,
            Callback = function(v) CONFIG.CURVE_MULT = v end
        }, 'AutoGKUltraCurveMult')
        
        moduleState.uiElements.CURVE_FORCE_MULT = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Curve Force",
            Minimum = 0.02,
            Maximum = 0.1,
            Default = CONFIG.CURVE_FORCE_MULT,
            Precision = 3,
            Callback = function(v) CONFIG.CURVE_FORCE_MULT = v end
        }, 'AutoGKUltraCurveForce')
        
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
        
        moduleState.uiElements.PRED_UPDATE_RATE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Prediction Update",
            Minimum = 1,
            Maximum = 10,
            Default = CONFIG.PRED_UPDATE_RATE,
            Precision = 0,
            Callback = function(v) CONFIG.PRED_UPDATE_RATE = v end
        }, 'AutoGKUltraPredUpdateRate')
        
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
            Header = "AutoGK ULTRA v9.7 - Улучшения",
            Body = [[
Основные улучшения:

1. ФИКСИРОВАННАЯ РОТАЦИЯ ПРИ НЫРКАХ:
   - Теперь вратарь не меняет направление взгляда во время нырка
   - Предотвращает пропуск мячей из-за смены ротации
   - Фиксация ротации начинается перед нырком и длится всю его продолжительность

2. УЛУЧШЕННОЕ ОБНАРУЖЕНИЕ ЗАКРУЧЕННЫХ УДАРОВ:
   - Увеличен CURVE_MULT с 32 до 42
   - Добавлен параметр CURVE_FORCE_MULT
   - Система запоминает недавние закрученные удары
   - Улучшенное предсказание траектории с закруткой

3. ЗАЩИТА УГЛОВЫХ АТАК:
   - Новая система обнаружения угловых атак
   - Параметры Corner Protection и Corner Advance
   - Специальное позиционирование для защиты углов
   - Автоматическое срабатывание при угловых ударах

4. УМНАЯ РОТАЦИЯ ТОЛЬКО КОГДА НУЖНО:
   - Ротация включается только при движении мяча > 8 скорости
   - При близком мяче (<10 единиц) - всегда следим
   - При владении мячом - ротация отключается
   - Экономия производительности

5. ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ:
   - Zone Offset Multiplier
   - Параметры для угловых атак
   - Настройки закрученных ударов
   - Улучшенная система предсказания

Рекомендуемые настройки для больших ворот:
- Corner Protection: 6.5
- Corner Advance: 4.2  
- Curve Multiplier: 42
- Rotation Smoothness: 0.25
]]
        })
        
        -- Кнопка сброса настроек
        UI.Sections.AutoGoalKeeper:Button({
            Name = "Reset to Recommended",
            Callback = function()
                CONFIG.CURVE_MULT = 42
                CONFIG.CURVE_FORCE_MULT = 0.05
                CONFIG.CORNER_PROTECTION_DISTANCE = 6.5
                CONFIG.CORNER_ADVANCE_DISTANCE = 4.2
                CONFIG.ROT_SMOOTH = 0.25
                
                if moduleState.uiElements.CURVE_MULT then
                    moduleState.uiElements.CURVE_MULT:SetValue(CONFIG.CURVE_MULT)
                end
                if moduleState.uiElements.CURVE_FORCE_MULT then
                    moduleState.uiElements.CURVE_FORCE_MULT:SetValue(CONFIG.CURVE_FORCE_MULT)
                end
                if moduleState.uiElements.CORNER_PROTECTION_DISTANCE then
                    moduleState.uiElements.CORNER_PROTECTION_DISTANCE:SetValue(CONFIG.CORNER_PROTECTION_DISTANCE)
                end
                if moduleState.uiElements.CORNER_ADVANCE_DISTANCE then
                    moduleState.uiElements.CORNER_ADVANCE_DISTANCE:SetValue(CONFIG.CORNER_ADVANCE_DISTANCE)
                end
                if moduleState.uiElements.ROT_SMOOTH then
                    moduleState.uiElements.ROT_SMOOTH:SetValue(CONFIG.ROT_SMOOTH)
                end
                
                notifyFunc("Syllinse", "Recommended settings applied", true)
            end
        })
    end
    
    -- Секция синхронизации в Config
    if UI.Tabs.Config then
        local syncSection = UI.Tabs.Config:Section({Name = 'AutoGK ULTRA Sync', Side = 'Right'})
        
        syncSection:Header({ Name = "AutoGK ULTRA v9.7 Config Sync" })
        
        syncSection:Paragraph({
            Header = "Sync Information",
            Body = [[
This section manually syncs all configuration values.
Use when settings don't apply automatically.
v9.7 improvements:
- Fixed dive rotation
- Better curve shot prediction
- Corner attack protection
- Smart rotation system
]]
        })
        
        syncSection:Divider()
        
        syncSection:Button({
            Name = "Sync Configuration Now",
            Callback = function()
                -- Правильная синхронизация каждого элемента
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
                CONFIG.CORNER_PROTECTION_DISTANCE = moduleState.uiElements.CORNER_PROTECTION_DISTANCE and moduleState.uiElements.CORNER_PROTECTION_DISTANCE:GetValue()
                CONFIG.CORNER_ADVANCE_DISTANCE = moduleState.uiElements.CORNER_ADVANCE_DISTANCE and moduleState.uiElements.CORNER_ADVANCE_DISTANCE:GetValue()
                CONFIG.CURVE_MULT = moduleState.uiElements.CURVE_MULT and moduleState.uiElements.CURVE_MULT:GetValue()
                CONFIG.CURVE_FORCE_MULT = moduleState.uiElements.CURVE_FORCE_MULT and moduleState.uiElements.CURVE_FORCE_MULT:GetValue()
                CONFIG.SHOW_TRAJECTORY = moduleState.uiElements.SHOW_TRAJECTORY and moduleState.uiElements.SHOW_TRAJECTORY:GetState()
                CONFIG.SHOW_ENDPOINT = moduleState.uiElements.SHOW_ENDPOINT and moduleState.uiElements.SHOW_ENDPOINT:GetState()
                CONFIG.SHOW_GOAL_CUBE = moduleState.uiElements.SHOW_GOAL_CUBE and moduleState.uiElements.SHOW_GOAL_CUBE:GetState()
                CONFIG.SHOW_ZONE = moduleState.uiElements.SHOW_ZONE and moduleState.uiElements.SHOW_ZONE:GetState()
                CONFIG.SHOW_BALL_BOX = moduleState.uiElements.SHOW_BALL_BOX and moduleState.uiElements.SHOW_BALL_BOX:GetState()
                CONFIG.PRED_UPDATE_RATE = moduleState.uiElements.PRED_UPDATE_RATE and moduleState.uiElements.PRED_UPDATE_RATE:GetValue()
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
                    
                    notifyFunc("Syllinse", "AutoGK ULTRA v9.7 Enabled", true)
                else
                    cleanup()
                    notifyFunc("Syllinse", "AutoGK Disabled", true)
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
