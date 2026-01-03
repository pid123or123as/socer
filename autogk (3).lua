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
    
    -- Ротация
    ROTATION_SMOOTH = 0.15,
    
    -- Размер ворот
    BIG_GOAL_THRESHOLD = 40,
    
    -- Перехват
    INTERCEPT_DISTANCE = 35,
    INTERCEPT_SPEED_MULT = 1.34,
    
    -- Прыжки
    JUMP_RADIUS = 40,
    JUMP_MIN_HEIGHT_DIFF = 0.7,
    JUMP_VERTICAL_THRESHOLD = 0.8,
    
    JUMP_HORIZONTAL_FORCE = 70,
    DIVE_DURATION = 0.44,
    DIVE_DISTANCE = 8, -- Рывок на 8 studs
    
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

-- Функция поиска ворот
local function UpdateGoal()
    local isHPG = ws.Bools:FindFirstChild("HPG") and ws.Bools.HPG.Value == player
    local isAPG = ws.Bools:FindFirstChild("APG") and ws.Bools.APG.Value == player
    if not (isHPG or isAPG) then return nil, nil end
    
    local goalName = isHPG and "HomeGoal" or "AwayGoal"
    local goalFolder = ws:FindFirstChild(goalName)
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
                
                local axisDistances = {
                    {dist = max.X - localPos.X, normal = Vector3.new(1,0,0)},
                    {dist = localPos.X - min.X, normal = Vector3.new(-1,0,0)},
                    {dist = max.Y - localPos.Y, normal = Vector3.new(0,1,0)},
                    {dist = localPos.Y - min.Y, normal = Vector3.new(0,-1,0)},
                    {dist = max.Z - localPos.Z, normal = Vector3.new(0,0,1)},
                    {dist = localPos.Z - min.Z, normal = Vector3.new(0,0,-1)}
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

-- Предсказание траектории
local function predictTrajectory(ball)
    local points = {ball.Position}
    local pos, vel = ball.Position, ball.Velocity
    local dt = CONFIG.DT
    local gravity = CONFIG.GRAVITY
    local drag = CONFIG.DRAG
    local steps = CONFIG.PRED_STEPS
    
    for i = 1, steps do
        vel = vel * drag
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

-- Получение хитбокса вратаря
local function getGoalkeeperHitbox(char)
    if not char then return nil end
    local hitbox = char:FindFirstChild("Hitbox") or char:FindFirstChild("GoalkeeperHitbox")
    if hitbox then
        return hitbox
    end
    return char:FindFirstChild("HumanoidRootPart")
end

-- Умная ротация - ПРОСТАЯ И РАБОЧАЯ
local function smartRotation(root, ballPos, isDiving)
    if isDiving then return end
    
    local char = root.Parent
    if not char then return end
    
    -- Простая ротация: смотрим на мяч, но не поднимаем взгляд
    local toBall = (ballPos - root.Position) * Vector3.new(1,0,1)
    if toBall.Magnitude < 0.1 then return end
    
    toBall = toBall.Unit
    
    -- Горизонтальная ротация
    local lookCF = CFrame.new(root.Position, root.Position + toBall)
    
    -- Плавная интерполяция
    if not moduleState.smoothCFrame then
        moduleState.smoothCFrame = root.CFrame
    end
    
    local currentY = math.atan2(root.CFrame.LookVector.X, root.CFrame.LookVector.Z)
    local targetY = math.atan2(toBall.X, toBall.Z)
    
    local angleDiff = math.abs(((targetY - currentY + math.pi) % (2 * math.pi)) - math.pi)
    
    local smoothFactor = CONFIG.ROTATION_SMOOTH
    if angleDiff > math.rad(60) then
        smoothFactor = smoothFactor * 2
    elseif angleDiff < math.rad(10) then
        smoothFactor = smoothFactor * 0.5
    end
    
    local smoothedY = currentY * (1 - smoothFactor) + targetY * smoothFactor
    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, smoothedY, 0)
end

-- Проверка угловой атаки
local function isCornerAttack(endpoint)
    if not endpoint or not moduleState.GoalCFrame then return false end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    
    local lateralDist = math.abs((endpoint - goalPos):Dot(goalRight))
    local goalHalfWidth = moduleState.GoalWidth / 2
    
    return lateralDist > goalHalfWidth * 0.6
end

-- Умная позиция
local function calculateSmartPosition(root, ballPos, ownerRoot, isBallControlled, endpoint, ballVel)
    if not moduleState.GoalCFrame then 
        return moduleState.GoalCFrame.Position + moduleState.GoalForward * CONFIG.STAND_DIST 
    end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    
    -- Базовая позиция
    local targetPos = goalPos + moduleState.GoalForward * CONFIG.STAND_DIST
    
    -- Если мяч контролируется врагом
    if isBallControlled and ownerRoot then
        local enemyToGoal = (goalPos - ownerRoot.Position) * Vector3.new(1,0,1)
        local enemyDist = enemyToGoal.Magnitude
        
        if enemyDist < 30 then
            -- Сближаемся с врагом
            local approachDist = math.clamp(enemyDist * 0.4, 3, 12)
            targetPos = ownerRoot.Position + (ownerRoot.Position - goalPos).Unit * approachDist
            
            -- Ограничиваем минимальную дистанцию
            local forwardDist = (targetPos - goalPos):Dot(moduleState.GoalForward)
            if forwardDist < 1.5 then
                targetPos = goalPos + moduleState.GoalForward * 1.5
            end
        end
    end
    
    -- Если есть endpoint (мяч летит)
    if endpoint then
        local endpointToGoal = (goalPos - endpoint) * Vector3.new(1,0,1)
        local endpointDist = endpointToGoal.Magnitude
        
        if endpointDist < 20 then
            -- Двигаемся к точке падения мяча
            local lateralDist = (endpoint - goalPos):Dot(goalRight)
            local lateralFactor = math.clamp(lateralDist / (moduleState.GoalWidth * 0.5), -1, 1)
            
            local baseDepth = math.clamp(endpointDist * 0.3, 2, 8)
            targetPos = goalPos + moduleState.GoalForward * baseDepth + goalRight * (lateralFactor * moduleState.GoalWidth * 0.3)
        end
    end
    
    -- Удерживаем позицию в зоне
    local zoneWidth = moduleState.GoalWidth * CONFIG.ZONE_WIDTH_MULTIPLIER
    local lateralLimit = zoneWidth / 2
    local currentLateral = (targetPos - goalPos):Dot(goalRight)
    
    if math.abs(currentLateral) > lateralLimit then
        targetPos = targetPos - goalRight * (currentLateral - math.sign(currentLateral) * lateralLimit)
    end
    
    return Vector3.new(targetPos.X, 0, targetPos.Z)
end

-- Движение к позиции
local function moveToPosition(root, targetPos, ballPos, velMag)
    if moduleState.currentBV then 
        pcall(function() moduleState.currentBV:Destroy() end) 
        moduleState.currentBV = nil 
    end
    
    local dirVec = (targetPos - root.Position) * Vector3.new(1,0,1)
    if dirVec.Magnitude < CONFIG.MIN_DIST then return end
    
    local speed = CONFIG.SPEED
    
    -- Проверяем нужно ли сближаться
    local ballDist = (ballPos - root.Position).Magnitude
    
    if ballDist < CONFIG.CLOSE_DISTANCE then
        speed = CONFIG.SPEED * CONFIG.CLOSE_SPEED_MULT
        
        if ballDist < CONFIG.ATTACK_DISTANCE then
            speed = CONFIG.AGGRESSIVE_SPEED
        end
    end
    
    -- Если мяч летит быстро - более агрессивно
    if velMag > 25 and ballDist < 25 then
        speed = speed * 1.2
    end
    
    moduleState.currentBV = Instance.new("BodyVelocity")
    moduleState.currentBV.Parent = root
    moduleState.currentBV.MaxForce = Vector3.new(6e5, 0, 6e5)
    moduleState.currentBV.Velocity = dirVec.Unit * speed
    game.Debris:AddItem(moduleState.currentBV, 0.15)
end

-- Проверка прыжка
local function shouldJump(root, ballPos, goalkeeperHitbox)
    if not root or not ballPos or not goalkeeperHitbox then return false end
    
    local currentTime = tick()
    if currentTime - moduleState.lastJumpTime < CONFIG.JUMP_COOLDOWN then return false end
    
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.JUMP_RADIUS then return false end
    
    local hitboxTop = goalkeeperHitbox.Position.Y + (goalkeeperHitbox.Size.Y / 2)
    local ballHeight = ballPos.Y
    
    -- Проверяем высоту мяча
    if ballHeight > hitboxTop + CONFIG.JUMP_VERTICAL_THRESHOLD then
        return true
    end
    
    return false
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

-- Проверка перехвата
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
    
    return timeToGoal < timeToReach * 1.2
end

-- Проверка нырка - ТОЛЬКО КОГДА НЕОБХОДИМО
local function shouldDive(root, ball, velMag, endpoint)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving then return false end
    if velMag < CONFIG.DIVE_VEL_THRES then return false end
    
    local ballPos = ball.Position
    local distToBall = (root.Position - ballPos).Magnitude
    if distToBall > CONFIG.DIVE_DIST then return false end
    
    -- Проверяем, сможем ли мы дойти до мяча
    local timeToReach = distToBall / CONFIG.AGGRESSIVE_SPEED
    local ballTravelDist = (ballPos - endpoint).Magnitude
    local timeToArrive = ballTravelDist / velMag
    
    -- Ныряем ТОЛЬКО если не успеваем дойти
    if timeToArrive < timeToReach * 0.8 then
        -- Проверяем что мяч летит не прямо в нас
        local toBall = (ballPos - root.Position).Unit
        local ballDir = ball.Velocity.Unit
        
        local angle = math.deg(math.acos(toBall:Dot(ballDir)))
        if angle > 45 then -- Мяч летит не прямо в нас
            return true
        end
    end
    
    return false
end

-- Выполнение нырка с рывком 8 studs
local function performDive(root, hum, targetPos, ballHeight, ball)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving or moduleState.diveAnimationPlaying then return end
    
    moduleState.isDiving = true
    moduleState.diveAnimationPlaying = true
    moduleState.lastDiveTime = tick()
    
    -- Определяем сторону нырка
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalCFrame.RightVector
    
    local relativePos = moduleState.GoalCFrame:PointToObjectSpace(targetPos)
    local lateral = relativePos.X
    
    local dir = lateral > 0 and "Right" or "Left"
    
    -- Не меняем ротацию при нырке - смотрим туда же куда и смотрели
    local currentCF = root.CFrame
    
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir.."dive", currentCF)
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
    
    -- Рывок на 8 studs
    local diveBV = Instance.new("BodyVelocity")
    diveBV.Parent = root
    diveBV.MaxForce = Vector3.new(2e7, 2e7, 2e7)
    
    local diveSpeed = CONFIG.DIVE_DISTANCE / CONFIG.DIVE_DURATION
    
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
            -- Умное позиционирование
            local targetPos = calculateSmartPosition(root, ball.Position, oRoot, isBallControlled, endpoint, ball.Velocity)
            
            -- Двигаемся к позиции
            moveToPosition(root, targetPos, ball.Position, velMag)
            
            -- Ротация
            smartRotation(root, ball.Position, false)
            
            -- Проверка действий
            if tick() - moduleState.lastActionTime > moduleState.actionCooldown then
                local goalkeeperHitbox = getGoalkeeperHitbox(char)
                
                moduleState.willJump = shouldJump(root, ball.Position, goalkeeperHitbox)
                
                if shouldIntercept(root, ball, endpoint) then
                    -- Перехват
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
                    
                    moduleState.lastActionTime = tick()
                elseif shouldDive(root, ball, velMag, endpoint) then
                    performDive(root, hum, endpoint or ball.Position, ball.Position.Y, ball)
                    moduleState.lastActionTime = tick()
                elseif moduleState.willJump then
                    performJump(char, hum)
                    moduleState.lastActionTime = tick()
                else
                    -- Блок если мяч рядом
                    local distToBall = (root.Position - ball.Position).Magnitude
                    if distToBall < CONFIG.NEAR_BALL_DIST then
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
                    end
                end
            end
        else
            if moduleState.currentBV then 
                pcall(function() moduleState.currentBV:Destroy() end) 
                moduleState.currentBV = nil 
            end
            
            if not moduleState.isDiving and not moduleState.willJump then
                smartRotation(root, ball.Position, false)
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
        end
        
        if CONFIG.SHOW_BALL_BOX and distBall < 80 and moduleState.visualObjects.BallBox then 
            local col = moduleState.willJump and CONFIG.BALL_BOX_JUMP_COLOR or CONFIG.BALL_BOX_COLOR
            drawCube(moduleState.visualObjects.BallBox, CFrame.new(ball.Position), Vector3.new(3.5, 3.5, 3.5), col)
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

-- Модуль AutoGK
local AutoGKModule = {}

function AutoGKModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
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
                    startRenderLoop()
                    startHeartbeat()
                    notifyFunc("AutoGK", "Enabled", true)
                else
                    cleanup()
                    notifyFunc("AutoGK", "Disabled", true)
                end
            end
        }, 'AutoGKEnabled')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Movement Settings" })
        
        moduleState.uiElements.SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Speed",
            Minimum = 20,
            Maximum = 50,
            Default = CONFIG.SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.SPEED = v end
        }, 'AutoGKSpeed')
        
        moduleState.uiElements.AGGRESSIVE_SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Aggressive Speed",
            Minimum = 25,
            Maximum = 60,
            Default = CONFIG.AGGRESSIVE_SPEED,
            Precision = 1,
            Callback = function(v) CONFIG.AGGRESSIVE_SPEED = v end
        }, 'AutoGKAggressiveSpeed')
        
        moduleState.uiElements.STAND_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Stand Distance",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = CONFIG.STAND_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.STAND_DIST = v end
        }, 'AutoGKStandDist')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Attack Settings" })
        
        moduleState.uiElements.CLOSE_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Close Distance",
            Minimum = 5,
            Maximum = 30,
            Default = CONFIG.CLOSE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.CLOSE_DISTANCE = v end
        }, 'AutoGKCloseDist')
        
        moduleState.uiElements.ATTACK_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Distance",
            Minimum = 3,
            Maximum = 15,
            Default = CONFIG.ATTACK_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_DISTANCE = v end
        }, 'AutoGKAttackDist')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Dive Settings" })
        
        moduleState.uiElements.DIVE_DIST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Distance",
            Minimum = 15,
            Maximum = 40,
            Default = CONFIG.DIVE_DIST,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_DIST = v end
        }, 'AutoGKDiveDist')
        
        moduleState.uiElements.DIVE_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Rush Distance",
            Minimum = 4,
            Maximum = 12,
            Default = CONFIG.DIVE_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_DISTANCE = v end
        }, 'AutoGKDiveDistance')
        
        moduleState.uiElements.DIVE_VEL_THRES = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Velocity",
            Minimum = 15,
            Maximum = 40,
            Default = CONFIG.DIVE_VEL_THRES,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_VEL_THRES = v end
        }, 'AutoGKDiveVelThres')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Jump Settings" })
        
        moduleState.uiElements.JUMP_RADIUS = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Radius",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.JUMP_RADIUS,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_RADIUS = v end
        }, 'AutoGKJumpRadius')
        
        moduleState.uiElements.JUMP_VERTICAL_THRESHOLD = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Jump Height",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = CONFIG.JUMP_VERTICAL_THRESHOLD,
            Precision = 1,
            Callback = function(v) CONFIG.JUMP_VERTICAL_THRESHOLD = v end
        }, 'AutoGKJumpHeight')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Visual Settings" })
        
        moduleState.uiElements.SHOW_TRAJECTORY = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Trajectory",
            Default = CONFIG.SHOW_TRAJECTORY,
            Callback = function(v) CONFIG.SHOW_TRAJECTORY = v end
        }, 'AutoGKShowTrajectory')
        
        moduleState.uiElements.SHOW_ZONE = UI.Sections.AutoGoalKeeper:Toggle({
            Name = "Show Zone",
            Default = CONFIG.SHOW_ZONE,
            Callback = function(v) CONFIG.SHOW_ZONE = v end
        }, 'AutoGKShowZone')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Hotkey" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "Hotkey: INSERT",
            Body = "Press INSERT to toggle AutoGK on/off"
        })
        
        -- Hotkey для вкл/выкл
        moduleState.inputConnection = uis.InputBegan:Connect(function(inp)
            if inp.KeyCode == Enum.KeyCode.Insert then
                CONFIG.ENABLED = not CONFIG.ENABLED
                moduleState.enabled = CONFIG.ENABLED
                
                if moduleState.uiElements.Enabled then
                    moduleState.uiElements.Enabled:SetState(moduleState.enabled)
                end
                
                if moduleState.enabled then
                    createVisuals()
                    startRenderLoop()
                    startHeartbeat()
                    notifyFunc("AutoGK", "Enabled", true)
                else
                    cleanup()
                    notifyFunc("AutoGK", "Disabled", true)
                end
            end
        end)
    end
end

function AutoGKModule:Destroy()
    cleanup()
    CONFIG.ENABLED = false
    moduleState.enabled = false
    
    if moduleState.inputConnection then
        moduleState.inputConnection:Disconnect()
        moduleState.inputConnection = nil
    end
end

return AutoGKModule
