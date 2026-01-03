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
    
    -- Размер ворот
    BIG_GOAL_THRESHOLD = 40,
    
    -- Перехват
    INTERCEPT_DISTANCE = 35,
    INTERCEPT_SPEED_MULT = 1.34,
    
    -- Прыжки
    JUMP_CHECK_HEIGHT = 0.5,
    JUMP_PREDICTION_STEPS = 20,
    JUMP_REACTION_TIME = 0.1,
    JUMP_VERTICAL_THRESHOLD = 0.1,
    GOAL_JUMP_SAFETY_MARGIN = 0.3,
    JUMP_RADIUS = 40,
    JUMP_MIN_HEIGHT_DIFF = 0.7,
    
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

-- ФУНКЦИЯ ДЛЯ ПОИСКА ЗАШИФРОВАННЫХ ВОРОТ
local function GetMyTeam()
    local humanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil, nil end
    
    local homeGoal = Workspace:FindFirstChild("HomeGoal")
    local awayGoal = Workspace:FindFirstChild("AwayGoal")
    
    if not (homeGoal and awayGoal) then return nil, nil end
    
    local homePos = homeGoal.Frame and homeGoal.Frame.Position or homeGoal.Position
    local awayPos = awayGoal.Frame and awayGoal.Frame.Position or awayGoal.Position
    
    local distToHome = (humanoidRootPart.Position - homePos).Magnitude
    local distToAway = (humanoidRootPart.Position - awayPos).Magnitude
    
    if distToHome < distToAway then
        return "home", "AwayGoal"
    else
        return "away", "HomeGoal"
    end
end

-- ОБНОВЛЕННАЯ ФУНКЦИЯ ДЛЯ ПОИСКА ВОРОТ (решает проблему с зашифрованными частями)
local function UpdateGoal()
    local myTeam, enemyGoalName = GetMyTeam()
    if not enemyGoalName then return nil, nil end
    
    local goalFolder = Workspace:FindFirstChild(enemyGoalName)
    if not goalFolder then return nil, nil end
    
    local frame = goalFolder:FindFirstChild("Frame")
    if not frame then return nil, nil end
    
    local leftPost, rightPost, crossbarPart
    local foundParts = {}
    
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
    
    if #foundParts >= 2 then
        leftPost = foundParts[1]
        rightPost = foundParts[2]
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
        leftPost = frame:FindFirstChild("LeftPost")
        rightPost = frame:FindFirstChild("RightPost")
    end
    
    if not crossbarPart then
        crossbarPart = frame:FindFirstChild("Crossbar")
    end
    
    if not (leftPost and rightPost and crossbarPart) then return nil, nil end
    
    local center = (leftPost.Position + rightPost.Position) / 2
    local forward = (center - crossbarPart.Position).Unit
    local up = crossbarPart.Position.Y > leftPost.Position.Y and Vector3.yAxis or -Vector3.yAxis
    local rightDir = (rightPost.Position - leftPost.Position).Unit
    moduleState.GoalCFrame = CFrame.fromMatrix(center, rightDir, up, -forward)
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
    if not (moduleState.GoalCFrame and moduleState.GoalForward) then 
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

-- УЛУЧШЕННАЯ ПРОВЕРКА НЕОБХОДИМОСТИ ПРЫЖКА
local function shouldJump(root, ballPos, ballVel, ballHeight, goalkeeperHitbox)
    if not root or not ballPos or not goalkeeperHitbox then return false end
    
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.JUMP_RADIUS then return false end
    
    -- Проверяем, летит ли мяч высоко над нами
    local hitboxTop = goalkeeperHitbox.Position.Y + (goalkeeperHitbox.Size.Y / 2)
    local heightDiff = ballPos.Y - hitboxTop
    
    if heightDiff < CONFIG.JUMP_MIN_HEIGHT_DIFF then return false end
    
    -- Проверяем, приближается ли мяч к нам
    local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1,0,1)
    local ballToGoalDist = ballToGoal.Magnitude
    
    if ballToGoalDist > 30 then return false end
    
    -- Проверяем вертикальную скорость мяча
    local verticalVel = ballVel.Y
    if math.abs(verticalVel) < 10 then return false end
    
    -- Проверяем, находится ли мяч в зоне прыжка (над воротами)
    local ballLocalPos = moduleState.GoalCFrame:PointToObjectSpace(ballPos)
    local halfWidth = moduleState.GoalWidth / 2 * 1.2
    
    if math.abs(ballLocalPos.X) > halfWidth then return false end
    
    -- Для больших ворот проверяем вероятность гола с высоты
    if moduleState.isBigGoal then
        local timeToReach = math.max(0, (ballPos.Y - hitboxTop) / math.abs(verticalVel))
        local horizontalDist = (ballPos - root.Position) * Vector3.new(1,0,1)
        
        -- Если мяч летит высоко и есть шанс гола, прыгаем
        if heightDiff > 3 and ballToGoalDist < 15 and timeToReach < 0.5 then
            return true
        end
    end
    
    -- Стандартная проверка для высоких мячей
    if heightDiff > 2 and ballToGoalDist < 20 and verticalVel < -10 then
        return true
    end
    
    return false
end

-- УЛУЧШЕННАЯ ЛОГИКА ПОЗИЦИОНИРОВАНИЯ
local function calculateSmartPosition(root, ballPos, ballOwner, isBallControlled, endpoint, ballVel)
    if not moduleState.GoalCFrame then 
        return moduleState.GoalCFrame.Position + moduleState.GoalForward * CONFIG.STAND_DIST 
    end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    local goalForward = -goalRight:Cross(Vector3.new(0,1,0)).Unit
    
    -- Базовые параметры
    local ballToGoal = (goalPos - ballPos) * Vector3.new(1,0,1)
    local ballDist = ballToGoal.Magnitude
    
    -- 1. Если владеем мячом или мяч под контролем врага
    if isBallControlled and ballOwner and ballOwner.Character then
        local enemyRoot = ballOwner.Character:FindFirstChild("HumanoidRootPart")
        if enemyRoot then
            local enemyPos = enemyRoot.Position
            local enemyToGoal = (goalPos - enemyPos) * Vector3.new(1,0,1)
            local enemyDist = enemyToGoal.Magnitude
            
            -- АТАКА - подходим ближе к врагу для перехвата
            if enemyDist < CONFIG.ATTACK_DISTANCE then
                local attackPos = enemyPos + (enemyPos - goalPos).Unit * 2
                attackPos = Vector3.new(attackPos.X, 0, attackPos.Z)
                
                -- Ограничиваем дистанцию от ворот
                local forwardDist = (attackPos - goalPos):Dot(goalForward)
                if forwardDist < 1.0 then
                    attackPos = goalPos + goalForward * 1.0
                end
                
                return attackPos
            -- СБЛИЖЕНИЕ - занимаем выгодную позицию
            elseif enemyDist < CONFIG.CLOSE_DISTANCE then
                local angleToGoal = math.atan2(
                    (enemyPos - goalPos):Dot(goalRight),
                    (enemyPos - goalPos):Dot(goalForward)
                )
                
                local depth = math.clamp(enemyDist * 0.4, 3, 10)
                local lateralMultiplier = math.sin(angleToGoal) * 0.8
                local lateralOffset = goalRight * (lateralMultiplier * moduleState.GoalWidth * 0.4)
                
                local interceptPoint = enemyPos + (enemyPos - goalPos).Unit * 5
                interceptPoint = Vector3.new(interceptPoint.X, 0, interceptPoint.Z)
                
                local basePos = goalPos + goalForward * depth
                local closingFactor = math.clamp(1 - (enemyDist / CONFIG.CLOSE_DISTANCE), 0, 0.7)
                local finalPos = (basePos * (1 - closingFactor) + interceptPoint * closingFactor) + lateralOffset
                
                local forwardDist = (finalPos - goalPos):Dot(goalForward)
                if forwardDist < 0.5 then
                    finalPos = goalPos + goalForward * 0.5
                end
                
                return finalPos
            end
        end
    end
    
    -- 2. Если мяч летит и есть endpoint
    if endpoint and ballVel and ballVel.Magnitude > 15 then
        local endpointToGoal = (goalPos - endpoint) * Vector3.new(1,0,1)
        local endpointDist = endpointToGoal.Magnitude
        
        if endpointDist < 25 then
            local angleToGoal = math.atan2(
                (endpoint - goalPos):Dot(goalRight),
                (endpoint - goalPos):Dot(goalForward)
            )
            
            -- Адаптивная глубина в зависимости от угла
            local depth
            local lateralDist = math.abs((endpoint - goalPos):Dot(goalRight))
            
            if lateralDist > moduleState.GoalWidth * 0.4 then
                -- Угловая атака - ближе к воротам
                depth = math.clamp(endpointDist * 0.2, 1.5, 4)
            else
                -- Центральная атака - нормальная глубина
                depth = math.clamp(endpointDist * 0.3, 2, 8)
            end
            
            local lateralMultiplier = math.sin(angleToGoal) * 0.9
            local lateralOffset = goalRight * (lateralMultiplier * moduleState.GoalWidth * 0.5)
            
            local targetPos = goalPos + goalForward * depth + lateralOffset
            
            local forwardDist = (targetPos - goalPos):Dot(goalForward)
            if forwardDist < 0.3 then
                targetPos = goalPos + goalForward * 0.3
            end
            
            return targetPos
        end
    end
    
    -- 3. Базовая позиция с учетом дистанции до мяча
    local angleToGoal = math.atan2(
        (ballPos - goalPos):Dot(goalRight),
        (ballPos - goalPos):Dot(goalForward)
    )
    
    local depth
    if ballDist < 30 then
        depth = math.clamp(ballDist * 0.25, 1, 6)
    elseif ballDist < 60 then
        depth = math.clamp(ballDist * 0.2, 3, 10)
    else
        depth = CONFIG.STAND_DIST
    end
    
    local lateralMultiplier = math.sin(angleToGoal) * 0.7
    local lateralOffset = goalRight * (lateralMultiplier * moduleState.GoalWidth * 0.4)
    
    return goalPos + goalForward * depth + lateralOffset
end

-- Движение к позиции с учетом сближения
local function moveToPosition(root, targetPos, ballPos, velMag, isUrgent)
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1,0,1)
    if dirVec.Magnitude < CONFIG.MIN_DIST then return end
    
    local speed = CONFIG.SPEED
    
    -- Проверяем дистанцию до мяча для сближения
    local ballDist = (ballPos - root.Position).Magnitude
    
    if ballDist < CONFIG.CLOSE_DISTANCE then
        speed = CONFIG.SPEED * CONFIG.CLOSE_SPEED_MULT
        
        if ballDist < CONFIG.ATTACK_DISTANCE then
            speed = CONFIG.AGGRESSIVE_SPEED
        end
    elseif isUrgent then
        speed = CONFIG.AGGRESSIVE_SPEED
    end
    
    if velMag > 25 and ballDist < 30 then
        speed = speed * 1.3
    end
    
    moduleState.currentBV = Instance.new("BodyVelocity")
    moduleState.currentBV.Parent = root
    moduleState.currentBV.MaxForce = Vector3.new(6e5, 0, 6e5)
    moduleState.currentBV.Velocity = dirVec.Unit * speed
    game.Debris:AddItem(moduleState.currentBV, 0.15)
end

-- УМНАЯ РОТАЦИЯ (ПОЛНОСТЬЮ ПЕРЕДЕЛАННАЯ) - РЕШЕНА ПРОБЛЕМА С ПОВОРОТОМ ВВЕРХ
local function smartRotation(root, ballPos, ballVel, isDiving, diveTarget, isMyBall, isJumping)
    if isMyBall or isJumping then return end
    
    local char = root.Parent
    if not char then return end
    
    -- Если ныряем, используем специальную ротацию для Dive
    if isDiving and diveTarget then
        -- Ротация от ворот для безопасного отбития
        local goalToBall = (diveTarget - moduleState.GoalCFrame.Position) * Vector3.new(1,0,1)
        local safeDirection = goalToBall.Unit
        
        -- Ротация ТОЛЬКО по Y оси (горизонтальный поворот)
        local currentCF = root.CFrame
        local targetLookPos = root.Position + safeDirection * 10
        
        -- Создаем CFrame только с горизонтальным поворотом
        local lookCFrame = CFrame.lookAt(root.Position, Vector3.new(targetLookPos.X, root.Position.Y, targetLookPos.Z))
        root.CFrame = lookCFrame
        
        return
    end
    
    -- Обычная интеллектуальная ротация
    if not isDiving then
        local targetLookPos = ballPos
        
        -- Предсказываем позицию мяча с учетом его скорости
        if ballVel.Magnitude > 10 then
            local predictionPoint = ballPos + ballVel.Unit * 2
            targetLookPos = predictionPoint
        end
        
        -- Определяем вектор к мячу (только горизонтальный)
        local toBall = (targetLookPos - root.Position) * Vector3.new(1,0,1)
        if toBall.Magnitude < 0.1 then return end
        
        local toBallDirection = toBall.Unit
        
        -- Ротация ТОЛЬКО по Y оси (горизонтальный поворот)
        local lookCFrame = CFrame.lookAt(root.Position, Vector3.new(targetLookPos.X, root.Position.Y, targetLookPos.Z))
        
        -- Плавная интерполяция
        if not moduleState.smoothCFrame then
            moduleState.smoothCFrame = root.CFrame
        end
        
        local currentLook = moduleState.smoothCFrame.LookVector * Vector3.new(1,0,1)
        local targetLook = lookCFrame.LookVector * Vector3.new(1,0,1)
        
        if currentLook.Magnitude > 0 and targetLook.Magnitude > 0 then
            local angle = math.acos(math.clamp(currentLook:Dot(targetLook), -1, 1))
            local smoothFactor = CONFIG.SMART_ROTATION_SMOOTH
            
            if angle > math.rad(30) then
                smoothFactor = smoothFactor * 1.5
            elseif angle < math.rad(5) then
                smoothFactor = smoothFactor * 0.7
            end
            
            smoothFactor = math.clamp(smoothFactor, 0.05, 0.3)
            
            local interpolatedLook = (currentLook * (1 - smoothFactor) + targetLook * smoothFactor).Unit
            local finalCFrame = CFrame.lookAt(root.Position, root.Position + interpolatedLook * 10)
            
            root.CFrame = finalCFrame
            moduleState.smoothCFrame = finalCFrame
        else
            root.CFrame = lookCFrame
            moduleState.smoothCFrame = lookCFrame
        end
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

-- Улучшенная проверка необходимости нырка
local function shouldDive(root, ball, velMag, endpoint)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving then return false end
    if velMag < CONFIG.DIVE_VEL_THRES then return false end
    
    local ballPos = ball.Position
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.DIVE_DIST then return false end
    
    local ballToGoal = (moduleState.GoalCFrame.Position - ballPos) * Vector3.new(1,0,1)
    local distToGoalLine = ballToGoal.Magnitude
    
    -- Более агрессивный нырок для угловых атак
    local isDangerousAngle = false
    if endpoint then
        local lateralDist = math.abs((endpoint - moduleState.GoalCFrame.Position):Dot(moduleState.GoalCFrame.RightVector))
        if lateralDist > moduleState.GoalWidth * 0.4 then
            isDangerousAngle = true
            if distToBall < CONFIG.DIVE_DIST * 1.2 then
                return true
            end
        end
    end
    
    if distToGoalLine < 25 then
        local timeToReach = distToBall / CONFIG.AGGRESSIVE_SPEED
        local timeToGoal = distToGoalLine / velMag
        
        if timeToGoal < timeToReach * 1.3 then
            return true
        end
    end
    
    if endpoint and not isDangerousAngle then
        local timeToReachBall = distToBall / CONFIG.AGGRESSIVE_SPEED
        local ballTravelDist = (endpoint - ballPos).Magnitude
        local timeToEndpoint = ballTravelDist / velMag
        
        if timeToEndpoint < timeToReachBall * 1.4 then
            return true
        end
    end
    
    return false
end

-- Выполнение нырка с УЛУЧШЕННОЙ РОТАЦИЕЙ
local function performDive(root, hum, targetPos, ballHeight, ball)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving or moduleState.diveAnimationPlaying then return end
    
    moduleState.isDiving = true
    moduleState.diveAnimationPlaying = true
    moduleState.lastDiveTime = tick()
    
    -- Определяем сторону нырка
    local relativePos = moduleState.GoalCFrame:PointToObjectSpace(targetPos)
    local lateral = relativePos.X
    
    local dir = lateral > 0 and "Right" or "Left"
    
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
    
    -- УСТАНОВКА ПРАВИЛЬНОЙ РОТАЦИИ (только горизонтальной)
    local goalToBall = (targetPos - moduleState.GoalCFrame.Position) * Vector3.new(1,0,1)
    local safeDirection = goalToBall.Unit
    local safeLookPos = root.Position + safeDirection * 25
    
    -- Ротация ТОЛЬКО по Y оси
    local lookCFrame = CFrame.lookAt(root.Position, Vector3.new(safeLookPos.X, root.Position.Y, safeLookPos.Z))
    root.CFrame = lookCFrame
    
    -- РЫВОК с фиксированной скоростью
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
        
        if not moduleState.GoalCFrame then
            UpdateGoal()
            if not moduleState.GoalCFrame then
                hideAllVisuals()
                return
            end
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
            local targetPos = calculateSmartPosition(root, ball.Position, owner, isBallControlled, endpoint, ball.Velocity)
            local urgentDistance = moduleState.isBigGoal and 10 or 5
            local isUrgent = (endpoint and (endpoint - moduleState.GoalCFrame.Position):Dot(moduleState.GoalForward) < urgentDistance) or (velMag > 30)
            
            moveToPosition(root, targetPos, ball.Position, velMag, isUrgent)
            
            -- Ротация ТОЛЬКО когда не ныряем
            if not moduleState.isDiving then
                smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall, moduleState.willJump)
            end
            
            if tick() - moduleState.lastActionTime > moduleState.actionCooldown then
                local goalkeeperHitbox = getGoalkeeperHitbox(char)
                
                -- УЛУЧШЕННАЯ ПРОВЕРКА ПРЫЖКА
                moduleState.willJump = shouldJump(root, ball.Position, ball.Velocity, ball.Position.Y, goalkeeperHitbox)
                
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
            
            if not moduleState.isDiving and not moduleState.willJump then
                smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall, false)
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
        
        if not moduleState.GoalCFrame then
            UpdateGoal()
            if not moduleState.GoalCFrame then
                hideAllVisuals()
                return
            end
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
        UI.Sections.AutoGoalKeeper:Header({ Name = "AutoGoalKeeper ULTRA v2.0" })
        
        moduleState.uiElements.Enabled = UI.Sections.AutoGoalKeeper:Toggle({ 
            Name = "Enabled", 
            Default = CONFIG.ENABLED, 
            Callback = function(v) 
                CONFIG.ENABLED = v
                moduleState.enabled = v
                if v then
                    createVisuals()
                    UpdateGoal() -- Инициализируем ворота
                    startRenderLoop()
                    startHeartbeat()
                    notifyFunc("AutoGK ULTRA", "Вратарь активирован", true)
                    
                    -- Добавляем хоткей
                    if not moduleState.inputConnection then
                        moduleState.inputConnection = uis.InputBegan:Connect(function(input)
                            if input.KeyCode == Enum.KeyCode.Insert then
                                moduleState.enabled = not moduleState.enabled
                                CONFIG.ENABLED = moduleState.enabled
                                
                                if moduleState.uiElements.Enabled then
                                    moduleState.uiElements.Enabled:SetState(moduleState.enabled)
                                end
                                
                                notifyFunc("AutoGK ULTRA", moduleState.enabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН", true)
                            end
                        end)
                    end
                else
                    cleanup()
                    notifyFunc("AutoGK ULTRA", "Вратарь деактивирован", true)
                end
            end
        }, 'AutoGKUltraEnabled')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Основные настройки" })
        
        moduleState.uiElements.SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Скорость движения",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.SPEED = v end
        }, 'AutoGKUltraSpeed')
        
        moduleState.uiElements.AGGRESSIVE_SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Агрессивная скорость",
            Minimum = 25,
            Maximum = 60,
            Default = CONFIG.AGGRESSIVE_SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.AGGRESSIVE_SPEED = v end
        }, 'AutoGKUltraAggressiveSpeed')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Настройки атаки/сближения" })
        
        moduleState.uiElements.CLOSE_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Дистанция сближения",
            Minimum = 5,
            Maximum = 30,
            Default = CONFIG.CLOSE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.CLOSE_DISTANCE = v end
        }, 'AutoGKUltraCloseDist')
        
        moduleState.uiElements.ATTACK_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Дистанция атаки",
            Minimum = 3,
            Maximum = 15,
            Default = CONFIG.ATTACK_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_DISTANCE = v end
        }, 'AutoGKUltraAttackDist')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Умная ротация" })
        
        moduleState.uiElements.SMART_ROTATION_SMOOTH = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Плавность поворота",
            Minimum = 0.05,
            Maximum = 0.3,
            Default = CONFIG.SMART_ROTATION_SMOOTH,
            Precision = 2,
            Callback = function(v) CONFIG.SMART_ROTATION_SMOOTH = v end
        }, 'AutoGKUltraSmartRotSmooth')
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "Умная ротация v2.0",
            Body = [[
ПРОБЛЕМЫ РЕШЕНЫ:
✅ Только горизонтальный поворот (без наклона вверх)
✅ Интеллектуальная ротация в зависимости от ситуации
✅ Правильная ротация при нырке (от ворот)
✅ Плавное отслеживание мяча

ОСОБЕННОСТИ:
• Автоматически определяет тип атаки
• Адаптируется к угловым/центральным атакам
• Не смотрит в ворота при отбитии
• Плавная интерполяция поворотов
]]
        })
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Нырок и прыжок" })
        
        moduleState.uiElements.DIVE_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Дистанция нырка",
            Minimum = 15,
            Maximum = 40,
            Default = CONFIG.DIVE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_DIST = v end
        }, 'AutoGKUltraDiveDist')
        
        moduleState.uiElements.JUMP_RADIUS = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Радиус прыжка",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.JUMP_RADIUS,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_RADIUS = v end
        }, 'AutoGKUltraJumpRadius')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Зона защиты" })
        
        moduleState.uiElements.ZONE_WIDTH_MULTIPLIER = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Ширина зоны",
            Minimum = 1.0,
            Maximum = 4.0,
            Default = CONFIG.ZONE_WIDTH_MULTIPLIER,
            Precision = 1,
            Callback = function(v) CONFIG.ZONE_WIDTH_MULTIPLIER = v end
        }, 'AutoGKUltraZoneWidthMult')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Визуализация" })
        
        moduleState.uiElements.SHOW_TRAJECTORY = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Показывать траекторию",
            Default = CONFIG.SHOW_TRAJECTORY,
            Callback = function(v) 
                CONFIG.SHOW_TRAJECTORY = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        }, 'AutoGKUltraShowTrajectory')
        
        moduleState.uiElements.SHOW_ZONE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Показывать зону защиты",
            Default = CONFIG.SHOW_ZONE,
            Callback = function(v) 
                CONFIG.SHOW_ZONE = v 
                if moduleState.enabled then
                    createVisuals()
                end
            end
        }, 'AutoGKUltraShowZone')
        
    end
    
    notifyFunc("AutoGK ULTRA v2.0", "Модуль загружен! Исправлены все основные проблемы.", true)
end

function AutoGKUltraModule:Destroy()
    cleanup()
    moduleState.enabled = false
    CONFIG.ENABLED = false
end

return AutoGKUltraModule
