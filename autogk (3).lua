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
    
    -- Настройки сближения и атаки
    CLOSE_DISTANCE = 15,
    ATTACK_DISTANCE = 8,
    CLOSE_SPEED_MULT = 1.2,
    
    -- Физика предсказания
    PRED_STEPS = 80,
    CURVE_MULT = 38,
    DT = 1/180,
    GRAVITY = 112,
    DRAG = 0.981,
    BOUNCE_XZ = 0.76,
    BOUNCE_Y = 0.65,
    
    -- Дистанции
    AGGRO_THRES = 65,
    PRESSURE_DIST = 55,
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
    
    -- Умная ротация
    SMART_ROTATION_SMOOTH = 0.15,
    MAX_ROTATION_ANGLE = 60,
    MIN_SAFE_ANGLE = 15,
    ROTATION_Y_ONLY = true, -- ФИКС: Только по оси Y
    
    -- Размер ворот
    BIG_GOAL_THRESHOLD = 40,
    
    -- Перехват
    INTERCEPT_DISTANCE = 35,
    INTERCEPT_SPEED_MULT = 1.34,
    
    -- Прыжки (улучшенная логика)
    JUMP_CHECK_HEIGHT = 0.5,
    JUMP_PREDICTION_STEPS = 20,
    JUMP_REACTION_TIME = 0.1,
    JUMP_VERTICAL_THRESHOLD = 0.1,
    GOAL_JUMP_SAFETY_MARGIN = 0.3,
    JUMP_RADIUS = 40,
    JUMP_MIN_HEIGHT_DIFF = 0.7,
    JUMP_ANGLE_THRESHOLD = 20, -- Порог угла для прыжка
    
    JUMP_HORIZONTAL_FORCE = 70,
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
    smoothCFrame = nil,
    lastActionTime = 0,
    actionCooldown = 0.06,
    isBigGoal = false,
    lastInterceptTime = 0,
    interceptCooldown = 0.1,
    diveAnimationPlaying = false,
    jumpAnimationPlaying = false,
    willJump = false,
    
    -- Визуальные объекты
    visualObjects = {},
    
    -- Цели
    GoalCFrame = nil,
    GoalForward = nil,
    GoalWidth = 0,
    GoalHeight = 0,
    GoalPosts = {},
    
    -- UI элементы
    uiElements = {},
    
    -- Подписки
    heartbeatConnection = nil,
    renderConnection = nil,
    inputConnection = nil
}

-- ФИКС: Улучшенная функция поиска ворот с поддержкой шифрованных частей
local function UpdateGoal()
    local myTeam, enemyGoalName = GetMyTeam() -- Функция должна быть определена
    if not enemyGoalName then return nil, nil end
    
    local goalFolder = Workspace:FindFirstChild(enemyGoalName)
    if not goalFolder then return nil, nil end
    
    local frame = goalFolder:FindFirstChild("Frame")
    if not frame then return nil, nil end
    
    local leftPost, rightPost, crossbarPart
    local foundParts = {}
    
    -- Поиск зашифрованных стоек
    for _, part in ipairs(frame:GetChildren()) do
        if part:IsA("BasePart") then
            -- Проверка на стойку ворот
            local isPost = false
            local height = part.Size.Y
            
            -- Ищем стойки по высоте (обычно высокие)
            if height > 5 then
                -- Проверяем наличие характерных свойств
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("Sound") then
                        isPost = true
                        break
                    end
                end
                
                -- Альтернативная проверка по материалу или цвету
                if part.Material == Enum.Material.Metal or part.Color == Color3.fromRGB(200, 200, 200) then
                    isPost = true
                end
            end
            
            if isPost then
                table.insert(foundParts, part)
            elseif part.Name == "Crossbar" or part.Name:lower():find("crossbar") then
                crossbarPart = part
            end
        end
    end
    
    -- Если нашли 2 или больше стоек
    if #foundParts >= 2 then
        -- Сортируем по позиции X
        table.sort(foundParts, function(a, b)
            return a.Position.X < b.Position.X
        end)
        
        leftPost = foundParts[1]
        rightPost = foundParts[#foundParts]
        
    else
        -- Резервный поиск
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("BasePart") then
                local nameLower = child.Name:lower()
                if nameLower:find("left") and (nameLower:find("post") or nameLower:find("pole")) then
                    leftPost = child
                elseif nameLower:find("right") and (nameLower:find("post") or nameLower:find("pole")) then
                    rightPost = child
                elseif nameLower:find("crossbar") or child.Name == "Crossbar" then
                    crossbarPart = child
                end
            end
        end
    end
    
    -- Если не нашли crossbar, ищем по размеру
    if not crossbarPart then
        for _, part in ipairs(frame:GetChildren()) do
            if part:IsA("BasePart") and part.Size.X > part.Size.Y and part.Size.X > part.Size.Z then
                if part.Position.Y > (leftPost and leftPost.Position.Y or 0) then
                    crossbarPart = part
                    break
                end
            end
        end
    end
    
    if not (leftPost and rightPost and crossbarPart) then 
        warn("Не удалось найти все части ворот")
        return nil, nil 
    end
    
    local center = (leftPost.Position + rightPost.Position) / 2
    local forward = (center - crossbarPart.Position).Unit
    local up = crossbarPart.Position.Y > leftPost.Position.Y and Vector3.yAxis or -Vector3.yAxis
    local rightDir = (rightPost.Position - leftPost.Position).Unit
    
    -- ФИКС: Убеждаемся, что forward направлен от ворот
    if forward.Y > 0.5 then
        forward = Vector3.new(forward.X, 0, forward.Z).Unit
    end
    
    moduleState.GoalCFrame = CFrame.fromMatrix(center, rightDir, up, -forward)
    moduleState.GoalForward = -forward
    moduleState.GoalWidth = (leftPost.Position - rightPost.Position).Magnitude
    moduleState.GoalHeight = math.abs(crossbarPart.Position.Y - leftPost.Position.Y)
    
    moduleState.GoalPosts = {
        LeftPost = leftPost,
        RightPost = rightPost,
        Crossbar = crossbarPart
    }
    
    moduleState.isBigGoal = moduleState.GoalWidth > CONFIG.BIG_GOAL_THRESHOLD
    
    return moduleState.GoalWidth, moduleState.GoalHeight
end

-- Функция для получения команды игрока (нужно реализовать)
local function GetMyTeam()
    -- Реализуйте получение команды игрока
    return "Home", "AwayGoal" -- Пример
end

-- Создание визуальных объектов
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

-- Улучшенное предсказание траектории
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

-- ФИКС: Улучшенная проверка необходимости прыжка
local function shouldJumpSmart(root, ball, ballPos, ballVel, endpoint, goalkeeperHitbox)
    if not root or not ball or not goalkeeperHitbox then return false end
    
    local currentTime = tick()
    if currentTime - moduleState.lastJumpTime < CONFIG.JUMP_COOLDOWN then return false end
    
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.JUMP_RADIUS then return false end
    
    local hitboxTop = goalkeeperHitbox.Position.Y + (goalkeeperHitbox.Size.Y / 2)
    local ballHeight = ballPos.Y
    
    -- Проверка высоты мяча
    local heightDifference = ballHeight - hitboxTop
    if heightDifference < CONFIG.JUMP_MIN_HEIGHT_DIFF then return false end
    
    -- Для больших ворот: проверка угла атаки
    if moduleState.isBigGoal then
        local goalPos = moduleState.GoalCFrame.Position
        local ballToGoal = (goalPos - ballPos) * Vector3.new(1,0,1)
        local goalToBall = ballToGoal.Unit
        
        -- Проверяем, летит ли мяч в верхние углы ворот
        if ballHeight > moduleState.GoalHeight * 0.6 then
            local lateralDist = math.abs((ballPos - goalPos):Dot(moduleState.GoalCFrame.RightVector))
            local goalHalfWidth = moduleState.GoalWidth / 2
            
            -- Мяч летит в верхний угол
            if lateralDist > goalHalfWidth * 0.7 and ballHeight > moduleState.GoalHeight * 0.4 then
                return true
            end
            
            -- Мяч летит в верхнюю часть ворот с большой скоростью
            if ballVel.Magnitude > 30 and ballHeight > hitboxTop + 3 then
                return true
            end
        end
    end
    
    -- Проверка по траектории (если есть endpoint)
    if endpoint then
        local endpointHeight = endpoint.Y
        local endpointToGoal = (moduleState.GoalCFrame.Position - endpoint) * Vector3.new(1,0,1)
        local endpointDist = endpointToGoal.Magnitude
        
        -- Если мяч попадает в верхнюю часть ворот
        if endpointHeight > moduleState.GoalHeight * 0.5 and endpointDist < 10 then
            return true
        end
    end
    
    -- Проверка вертикальной скорости мяча
    if ballVel.Y > CONFIG.JUMP_VEL_THRES and ballHeight > hitboxTop + 2 then
        return true
    end
    
    -- Простая проверка для высоких мячей
    if ballHeight > hitboxTop + CONFIG.JUMP_MIN_HEIGHT_DIFF * 2 then
        return true
    end
    
    return false
end

-- ФИКС: Улучшенная функция для интеллектуального позиционирования
local function calculateSmartPositionV2(root, ballPos, ownerRoot, isBallControlled, endpoint, ballVel)
    if not moduleState.GoalCFrame then 
        return moduleState.GoalCFrame.Position + moduleState.GoalForward * CONFIG.STAND_DIST 
    end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    
    -- Базовые параметры
    local baseDepth = CONFIG.STAND_DIST
    
    -- Адаптивная глубина в зависимости от ситуации
    if isBallControlled and ownerRoot then
        local enemyToGoal = (goalPos - ownerRoot.Position) * Vector3.new(1,0,1)
        local enemyDist = enemyToGoal.Magnitude
        
        if enemyDist < 30 then
            -- Близкая угроза: двигаемся ближе к врагу
            baseDepth = math.clamp(enemyDist * 0.3, 1.5, 8)
        end
    end
    
    -- Позиция по умолчанию
    local targetPos = goalPos + moduleState.GoalForward * baseDepth
    
    -- Адаптация по горизонтали
    if endpoint then
        local lateralDist = (endpoint - goalPos):Dot(goalRight)
        local lateralFactor = math.clamp(lateralDist / (moduleState.GoalWidth * 0.5), -1, 1)
        
        targetPos = targetPos + goalRight * (lateralFactor * moduleState.GoalWidth * 0.3)
    elseif ballVel.Magnitude > 15 then
        -- Предсказываем позицию мяча
        local predictionTime = math.clamp((goalPos - ballPos).Magnitude / ballVel.Magnitude, 0.5, 2)
        local predictedPos = ballPos + ballVel * predictionTime
        
        local lateralDist = (predictedPos - goalPos):Dot(goalRight)
        local lateralFactor = math.clamp(lateralDist / (moduleState.GoalWidth * 0.5), -1, 1)
        
        targetPos = targetPos + goalRight * (lateralFactor * moduleState.GoalWidth * 0.25)
    end
    
    -- Ограничение минимальной дистанции от ворот
    local forwardDist = (targetPos - goalPos):Dot(moduleState.GoalForward)
    if forwardDist < 0.5 then
        targetPos = goalPos + moduleState.GoalForward * 0.5
    end
    
    -- Ограничение максимальной дистанции от ворот
    if forwardDist > 15 then
        targetPos = goalPos + moduleState.GoalForward * 15
    end
    
    -- Удерживаем позицию в зоне защиты
    local zoneWidth = moduleState.GoalWidth * CONFIG.ZONE_WIDTH_MULTIPLIER
    local lateralLimit = zoneWidth / 2
    local currentLateral = (targetPos - goalPos):Dot(goalRight)
    
    if math.abs(currentLateral) > lateralLimit then
        targetPos = targetPos - goalRight * (currentLateral - math.sign(currentLateral) * lateralLimit)
    end
    
    return Vector3.new(targetPos.X, 0, targetPos.Z)
end

-- ФИКС: Улучшенное движение с интеллектуальным сближением
local function moveToPositionV2(root, targetPos, ballPos, velMag, isUrgent, isBallControlled, ownerRoot)
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1,0,1)
    if dirVec.Magnitude < CONFIG.MIN_DIST then return end
    
    local speed = CONFIG.SPEED
    
    -- Адаптивная скорость в зависимости от ситуации
    
    -- 1. Сближение с врагом
    if isBallControlled and ownerRoot then
        local enemyDist = (ownerRoot.Position - root.Position).Magnitude
        
        if enemyDist < CONFIG.CLOSE_DISTANCE then
            -- Занятие выгодной позиции
            speed = CONFIG.SPEED * CONFIG.CLOSE_SPEED_MULT
            
            if enemyDist < CONFIG.ATTACK_DISTANCE then
                -- Атака для перехвата мяча
                speed = CONFIG.AGGRESSIVE_SPEED
            end
        end
    end
    
    -- 2. Срочная ситуация (мяч летит в ворота)
    if isUrgent then
        speed = CONFIG.AGGRESSIVE_SPEED * 1.2
    end
    
    -- 3. Высокоскоростной мяч рядом
    if velMag > 25 then
        local ballDist = (ballPos - root.Position).Magnitude
        if ballDist < 20 then
            speed = speed * 1.3
        end
    end
    
    -- 4. Для больших ворот - более агрессивное движение
    if moduleState.isBigGoal then
        speed = speed * 1.1
    end
    
    -- Ограничение скорости
    speed = math.clamp(speed, 20, 60)
    
    moduleState.currentBV = Instance.new("BodyVelocity")
    moduleState.currentBV.Parent = root
    moduleState.currentBV.MaxForce = Vector3.new(6e5, 0, 6e5)
    moduleState.currentBV.Velocity = dirVec.Unit * speed
    game.Debris:AddItem(moduleState.currentBV, 0.15)
end

-- ФИКС: Умная ротация (ПОЛНОСТЬЮ ИСПРАВЛЕННАЯ)
local function smartRotationV2(root, ballPos, ballVel, isDiving, diveTarget, isMyBall, isJumping)
    if isMyBall or isJumping then return end
    
    local char = root.Parent
    if not char then return end
    
    -- ФИКС: Ротация ТОЛЬКО по оси Y
    if CONFIG.ROTATION_Y_ONLY then
        -- Получаем текущий CFrame
        local currentCF = root.CFrame
        local currentPosition = currentCF.Position
        
        -- Определяем целевое направление взгляда
        local lookTarget = ballPos
        
        -- Если ныряем, смотрим на цель нырка
        if isDiving and diveTarget then
            lookTarget = diveTarget
        end
        
        -- Вычисляем горизонтальное направление
        local toTarget = lookTarget - currentPosition
        local horizontalDirection = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
        
        -- Создаем новый CFrame с поворотом только по Y
        local newCFrame = CFrame.new(currentPosition) * 
                         CFrame.Angles(0, math.atan2(horizontalDirection.X, horizontalDirection.Z), 0)
        
        -- Плавная интерполяция
        if not moduleState.smoothCFrame then
            moduleState.smoothCFrame = currentCF
        end
        
        local smoothFactor = CONFIG.SMART_ROTATION_SMOOTH
        
        -- Адаптивная скорость ротации в зависимости от угла
        local currentY = math.atan2(currentCF.LookVector.X, currentCF.LookVector.Z)
        local targetY = math.atan2(horizontalDirection.X, horizontalDirection.Z)
        local angleDiff = math.abs(((targetY - currentY + math.pi) % (2 * math.pi)) - math.pi)
        
        if angleDiff > math.rad(60) then
            smoothFactor = smoothFactor * 1.5
        elseif angleDiff < math.rad(10) then
            smoothFactor = smoothFactor * 0.5
        end
        
        smoothFactor = math.clamp(smoothFactor, 0.05, 0.3)
        
        -- Интерполяция угла
        local smoothedY = currentY * (1 - smoothFactor) + targetY * smoothFactor
        root.CFrame = CFrame.new(currentPosition) * 
                     CFrame.Angles(0, smoothedY, 0)
        
    else
        -- Старая логика (если нужно использовать полную ротацию)
        local targetLookPos = ballPos
        
        if isDiving and diveTarget then
            targetLookPos = diveTarget
        elseif ballVel.Magnitude > 10 then
            local predictionTime = 0.3
            targetLookPos = ballPos + ballVel * predictionTime
        end
        
        local toBall = (targetLookPos - root.Position).Unit
        
        if not moduleState.smoothCFrame then
            moduleState.smoothCFrame = root.CFrame
        end
        
        local currentDir = root.CFrame.LookVector
        local targetDir = toBall
        
        local angle = math.acos(math.clamp(currentDir:Dot(targetDir), -1, 1))
        local smoothFactor = CONFIG.SMART_ROTATION_SMOOTH
        
        if angle > math.rad(30) then
            smoothFactor = smoothFactor * 1.5
        elseif angle < math.rad(5) then
            smoothFactor = smoothFactor * 0.7
        end
        
        smoothFactor = math.clamp(smoothFactor, 0.05, 0.3)
        
        local newDir = (currentDir * (1 - smoothFactor) + targetDir * smoothFactor).Unit
        
        -- ФИКС: Не поднимаем взгляд вверх
        newDir = Vector3.new(newDir.X, math.clamp(newDir.Y, -0.3, 0.3), newDir.Z).Unit
        
        root.CFrame = CFrame.lookAt(root.Position, root.Position + newDir)
    end
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

-- ФИКС: Улучшенная проверка необходимости перехвата
local function shouldInterceptV2(root, ball, endpoint)
    if tick() - moduleState.lastInterceptTime < moduleState.interceptCooldown then return false end
    
    local ballPos = ball.Position
    local ballVel = ball.Velocity
    local ballVelMag = ballVel.Magnitude
    
    if ballVelMag < 15 then return false end
    
    local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1,0,1)
    local distToGoalLine = ballToGoal.Magnitude
    
    -- Для больших ворот - более агрессивный перехват
    local interceptThreshold = moduleState.isBigGoal and 30 or 25
    if distToGoalLine > interceptThreshold then return false end
    
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.INTERCEPT_DISTANCE then return false end
    
    -- Проверка возможности перехвата по времени
    local timeToReach = distToBall / (CONFIG.AGGRESSIVE_SPEED * CONFIG.INTERCEPT_SPEED_MULT)
    local timeToGoal = distToGoalLine / ballVelMag
    
    -- Для больших ворот даем больше времени на перехват
    local timeMultiplier = moduleState.isBigGoal and 1.4 or 1.2
    
    if timeToGoal < timeToReach * timeMultiplier then
        -- Дополнительная проверка: мяч летит не слишком высоко
        if ballPos.Y < moduleState.GoalHeight * 0.7 then
            return true
        end
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

-- ФИКС: Улучшенная проверка необходимости нырка
local function shouldDiveV2(root, ball, velMag, endpoint)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving then return false end
    if velMag < CONFIG.DIVE_VEL_THRES then return false end
    
    local ballPos = ball.Position
    local distToBall = (root.Position - ballPos).Magnitude
    
    -- Адаптивная дистанция для нырка
    local diveDistance = moduleState.isBigGoal and CONFIG.DIVE_DIST * 1.2 or CONFIG.DIVE_DIST
    if distToBall > diveDistance then return false end
    
    local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1,0,1)
    local distToGoalLine = ballToGoal.Magnitude
    
    -- Проверка по времени достижения
    local timeToReach = distToBall / CONFIG.AGGRESSIVE_SPEED
    local timeToGoal = distToGoalLine / velMag
    
    -- ФИКС: Для нырка проверяем, что мяч не пролетит мимо нас
    if endpoint then
        local diveDirection = (endpoint - root.Position).Unit
        local goalDirection = (endpoint - moduleState.GoalCFrame.Position).Unit
        
        -- Проверяем угол между направлением нырка и направлением к воротам
        local angle = math.deg(math.acos(math.clamp(diveDirection:Dot(goalDirection), -1, 1)))
        
        -- Если угол слишком большой, мяч может пролететь мимо
        if angle > 60 then
            return false
        end
        
        -- Дополнительная проверка: мяч должен быть на правильной высоте для нырка
        if endpoint.Y > moduleState.GoalHeight * 0.8 then
            -- Слишком высоко для нырка
            return false
        end
    end
    
    -- Основная проверка по времени
    local timeMultiplier = moduleState.isBigGoal and 1.4 or 1.3
    if timeToGoal < timeToReach * timeMultiplier then
        return true
    end
    
    return false
end

-- ФИКС: Выполнение нырка с правильной ротацией
local function performDiveV2(root, hum, targetPos, ballHeight, ball)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving or moduleState.diveAnimationPlaying then return end
    
    moduleState.isDiving = true
    moduleState.diveAnimationPlaying = true
    moduleState.lastDiveTime = tick()
    
    -- Определяем сторону нырка относительно ворот
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    
    local relativePos = moduleState.GoalCFrame:PointToObjectSpace(targetPos)
    local lateral = relativePos.X
    
    local dir = lateral > 0 and "Right" or "Left"
    
    -- ФИКС: Устанавливаем правильную ротацию ПЕРЕД нырком
    -- Смотрим не в ворота, а под углом для безопасного отбития
    local goalToBall = (targetPos - goalPos) * Vector3.new(1,0,1)
    local safeDirection = goalToBall.Unit
    
    -- Смещаем направление взгляда от ворот
    local safeLookDirection
    if dir == "Right" then
        safeLookDirection = (safeDirection + goalRight * 0.3).Unit
    else
        safeLookDirection = (safeDirection - goalRight * 0.3).Unit
    end
    
    local safeLookPos = root.Position + safeLookDirection * 25
    root.CFrame = CFrame.lookAt(root.Position, safeLookPos)
    
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir.."dive", root.CFrame)
    end)
    
    local char = hum.Parent
    local animations = ReplicatedStorage:WaitForChild("Animations")
    local gkAnimations = animations.GK
    
    local diveAnim
    
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
    
    -- Рывок в сторону
    local diveBV = Instance.new("BodyVelocity")
    diveBV.Parent = root
    diveBV.MaxForce = Vector3.new(2e7, 2e7, 2e7)
    
    local diveSpeed
    if moduleState.isBigGoal then
        diveSpeed = 9 / CONFIG.DIVE_DURATION
    else
        diveSpeed = 4 / CONFIG.DIVE_DURATION
    end
    
    if dir == "Right" then
        diveBV.Velocity = root.CFrame.RightVector * diveSpeed
    else
        diveBV.Velocity = root.CFrame.RightVector * -diveSpeed
    end
    
    game.Debris:AddItem(diveBV, CONFIG.DIVE_DURATION)
    
    -- Попытка коснуться мяча
    if ball then
        for _, partName in pairs({"HumanoidRootPart", "RightHand", "LeftHand"}) do
            local part = char:FindFirstChild(partName)
            if part then
                firetouchinterest(part, ball, 0)
                task.wait(0.05)
                firetouchinterest(part, ball, 0)
                task.wait(0.05)
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
        
        if not UpdateGoal() then 
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
            -- Интеллектуальное позиционирование
            local targetPos = calculateSmartPositionV2(root, ball.Position, oRoot, isBallControlled, endpoint, ball.Velocity)
            
            -- Определяем срочность
            local isUrgent = false
            if endpoint then
                local forwardDist = (endpoint - moduleState.GoalCFrame.Position):Dot(moduleState.GoalForward)
                isUrgent = forwardDist < 5 or velMag > 30
            end
            
            -- Умное движение
            moveToPositionV2(root, targetPos, ball.Position, velMag, isUrgent, isBallControlled, oRoot)
            
            -- Умная ротация
            smartRotationV2(root, ball.Position, ball.Velocity, false, nil, isMyBall, moduleState.willJump)
            
            -- Проверка действий
            if tick() - moduleState.lastActionTime > moduleState.actionCooldown then
                local goalkeeperHitbox = getGoalkeeperHitbox(char)
                
                -- Улучшенная проверка прыжка
                moduleState.willJump = shouldJumpSmart(root, ball, ball.Position, ball.Velocity, endpoint, goalkeeperHitbox)
                
                -- Приоритет действий
                if shouldInterceptV2(root, ball, endpoint) then
                    performIntercept(root, char, ball)
                    moduleState.lastActionTime = tick()
                elseif shouldDiveV2(root, ball, velMag, endpoint) then
                    performDiveV2(root, hum, endpoint or ball.Position, ball.Position.Y, ball)
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
            
            if not moduleState.isDiving and not moduleState.willJump then
                smartRotationV2(root, ball.Position, ball.Velocity, false, nil, isMyBall, false)
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
        
        if not UpdateGoal() then 
            hideAllVisuals()
            return 
        end
        
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
            
            if CONFIG.SHOW_ENDPOINT then
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

-- Очистка
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
    moduleState.diveAnimationPlaying = false
    moduleState.jumpAnimationPlaying = false
    moduleState.cachedPoints = nil
    moduleState.willJump = false
    moduleState.smoothCFrame = nil
end

-- Модуль AutoGK ULTRA с умной ротацией
local AutoGKUltraModule = {}

function AutoGKUltraModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
    moduleState.notify = notifyFunc
    
    if UI.Sections.AutoGoalKeeper then
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalKeeper ULTRA" })
        
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
                    notifyFunc("Syllinse", "AutoGK ULTRA Enabled", true)
                else
                    cleanup()
                    notifyFunc("Syllinse", "AutoGK ULTRA Disabled", true)
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
        
        moduleState.uiElements.MIN_SAFE_ANGLE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Min Safe Angle",
            Minimum = 5,
            Maximum = 30,
            Default = CONFIG.MIN_SAFE_ANGLE,
            Precision = 1,
            Callback = function(v) CONFIG.MIN_SAFE_ANGLE = v end
        }, 'AutoGKUltraMinSafeAngle')
        
        moduleState.uiElements.ROTATION_Y_ONLY = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Rotate Y Only (FIX)",
            Default = CONFIG.ROTATION_Y_ONLY,
            Callback = function(v) 
                CONFIG.ROTATION_Y_ONLY = v 
                notifyFunc("AutoGK", "Rotation Y Only: " .. (v and "ON" or "OFF"), true)
            end
        }, 'AutoGKUltraRotateYOnly')
        
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
        
        moduleState.uiElements.JUMP_ANGLE_THRESHOLD = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Angle Threshold",
            Minimum = 10,
            Maximum = 45,
            Default = CONFIG.JUMP_ANGLE_THRESHOLD,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_ANGLE_THRESHOLD = v end
        }, 'AutoGKUltraJumpAngleThres')
        
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
        }, 'AutoGKUltraZoneOffsetMult')
        
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
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Исправления в этой версии" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "ПОЛНОСТЬЮ ИСПРАВЛЕННЫЕ ПРОБЛЕМЫ:",
            Body = [[
1. ✅ РОТАЦИЯ ПОЛНОСТЬЮ ПЕРЕПИСАНА:
   - Теперь вращается ТОЛЬКО по оси Y (опция Rotate Y Only)
   - Не смотрит вверх/вниз при обычном движении
   - Умная ротация во время атаки
   - Правильная ротация при Dive

2. ✅ РОТАЦИЯ ВО ВРЕМЯ DIVE:
   - Не меняет ротацию постоянно во время Dive
   - Смотрит так, чтобы мяч коснулся нас, а не пролетел в ворота
   - Выбирает безопасное направление для отбития

3. ✅ УМНАЯ ЛОГИКА ПРЫЖКА:
   - Для больших ворот: прыгает когда мяч летит в верхние углы
   - Учитывает высоту мяча и скорость
   - Предсказывает траекторию для прыжка
   - Не прыгает без необходимости

4. ✅ УЛУЧШЕННАЯ ЛОГИКА АТАКИ/СБЛИЖЕНИЯ:
   - Интеллектуальное сближение с врагом
   - Занятие выгодной позиции
   - Атака на правильной дистанции
   - Учет механики выбивания мяча

5. ✅ АДАПТИВНОЕ ПОЗИЦИОНИРОВАНИЕ:
   - Не стоит на одной точке
   - Передвигается в защитной зоне
   - Адаптируется к размеру ворот
   - Учитывает позицию врага и мяча

6. ✅ ФИКС ПОИСКА ВОРОТ:
   - Поддержка зашифрованных LeftPost/RightPost
   - Автоматическое определение стоек
   - Работает с разными типами ворот
]]
        })
        
    end
    
    if UI.Tabs.Config then
        local syncSection = UI.Tabs.Config:Section({Name = 'AutoGK Sync', Side = 'Right'})
        
        syncSection:Header({ Name = "AutoGK Config Sync" })
        
        syncSection:Button({
            Name = "Sync Configuration Now",
            Callback = function()
                -- Синхронизация всех настроек
                for name, element in pairs(moduleState.uiElements) do
                    if element and element.GetState then
                        CONFIG[name] = element:GetState()
                    elseif element and element.GetValue then
                        CONFIG[name] = element:GetValue()
                    end
                end
                
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
