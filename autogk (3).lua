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
    
    -- Дистанции для сближения и атаки
    APPROACH_DISTANCE = 40,
    ATTACK_DISTANCE = 25,
    RETREAT_DISTANCE = 15,
    
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
    ROTATION_Y_SPEED = 0.25,
    DIVE_ROTATION_SPEED = 0.9,
    MAX_ROTATION_ANGLE = 75,
    
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
    SMALL_GOAL_DIVE_DISTANCE = 5,
    BIG_GOAL_DIVE_DISTANCE = 16,
    DIVE_DURATION = 0.44,
    DIVE_SPEED_BOOST = 2.2,
    DIVE_FORCE_MULTIPLIER = 1.8,
    
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
    lastActionTime = 0,
    actionCooldown = 0.06,
    isBigGoal = false,
    lastInterceptTime = 0,
    interceptCooldown = 0.1,
    diveAnimationPlaying = false,
    jumpAnimationPlaying = false,
    willJump = false,
    lastDiveSide = nil,
    diveDirectionConfidence = 0,
    
    -- Визуальные объекты
    visualObjects = {},
    
    -- Цели
    GoalCFrame = nil,
    GoalForward = nil,
    GoalRight = nil,
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
    
    if not left or not right then return false end
    
    moduleState.GoalPosts = {
        LeftPost = left,
        RightPost = right
    }
    
    local gcenter = (left.Position + right.Position) / 2
    local rightVec = (right.Position - left.Position).Unit
    moduleState.GoalRight = rightVec
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
        
        local gravityMultiplier = 1.04
        if spinCurve.Y > 20 then
            gravityMultiplier = 0.95
        end
        vel = vel - Vector3.new(0, gravity * dt * gravityMultiplier, 0)
        
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

local function getGoalkeeperHitbox(char)
    if not char then return nil end
    local hitbox = char:FindFirstChild("Hitbox") or char:FindFirstChild("GoalkeeperHitbox")
    if hitbox then
        return hitbox
    end
    return char:FindFirstChild("HumanoidRootPart")
end

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

-- НОВАЯ: Определение направления отбития мяча
local function calculateDeflectionDirection(root, ballPos, ballVel)
    if not moduleState.GoalCFrame then return Vector3.new(0,0,1) end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalRight
    local goalForward = moduleState.GoalForward
    
    -- Вектор от ворот к мячу
    local ballToGoal = (goalPos - ballPos) * Vector3.new(1,0,1)
    local ballToGoalDir = ballToGoal.Unit
    
    -- Проекция на правый вектор ворот (определяем лево/право)
    local lateralComponent = ballToGoalDir:Dot(goalRight)
    
    -- Определяем безопасное направление отбития
    local deflectionDir
    
    if math.abs(lateralComponent) < 0.3 then
        -- Мяч летит почти по центру - отбиваем вперед или под углом
        deflectionDir = goalForward * -1  -- Вперед от ворот
    else
        -- Мяч летит сбоку - отбиваем в противоположную сторону от центра
        if lateralComponent > 0 then
            -- Мяч справа - отбиваем влево (от ворот)
            deflectionDir = (goalForward * -0.7 + goalRight * -0.7).Unit
        else
            -- Мяч слева - отбиваем вправо (от ворот)
            deflectionDir = (goalForward * -0.7 + goalRight * 0.7).Unit
        end
    end
    
    return deflectionDir
end

-- НОВАЯ: Умное позиционирование с учетом сближения и атаки
local function calculateSmartPosition(root, ballPos, ownerRoot, isBallControlled, endpoint, ballVel)
    if not moduleState.GoalCFrame then 
        return moduleState.GoalCFrame.Position + moduleState.GoalForward * CONFIG.STAND_DIST 
    end
    
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalRight
    local goalForward = moduleState.GoalForward
    
    local ballToGoal = (goalPos - ballPos) * Vector3.new(1,0,1)
    local distToGoal = ballToGoal.Magnitude
    
    -- Определяем фазу игры
    local isApproachPhase = distToGoal < CONFIG.APPROACH_DISTANCE and distToGoal > CONFIG.ATTACK_DISTANCE
    local isAttackPhase = distToGoal <= CONFIG.ATTACK_DISTANCE and distToGoal > CONFIG.RETREAT_DISTANCE
    local isRetreatPhase = distToGoal <= CONFIG.RETREAT_DISTANCE
    
    -- Базовая позиция
    local basePos = goalPos + goalForward * CONFIG.STAND_DIST
    
    if isApproachPhase then
        -- Фаза сближения: занимаем позицию между мячом и центром ворот
        local ballLateral = (ballPos - goalPos):Dot(goalRight)
        local lateralOffset = goalRight * (ballLateral * 0.3)
        
        local depth = math.clamp(distToGoal * 0.3, 2, 10)
        return goalPos + goalForward * depth + lateralOffset
        
    elseif isAttackPhase then
        -- Фаза атаки: более агрессивная позиция
        if endpoint then
            local endpointToGoal = (goalPos - endpoint) * Vector3.new(1,0,1)
            local endpointDist = endpointToGoal.Magnitude
            
            if endpointDist < 30 then
                local angleToGoal = math.atan2(
                    (endpoint - goalPos):Dot(goalRight),
                    (endpoint - goalPos):Dot(goalForward)
                )
                
                local depth = math.clamp(endpointDist * 0.25, 1.5, 8)
                local lateralMultiplier = math.sin(angleToGoal) * 0.8
                local lateralOffset = goalRight * (lateralMultiplier * moduleState.GoalWidth * 0.35)
                
                return goalPos + goalForward * depth + lateralOffset
            end
        end
        
        -- Позиция между мячом и ближайшей стойкой
        local ballLateral = (ballPos - goalPos):Dot(goalRight)
        local goalHalfWidth = moduleState.GoalWidth / 2
        
        if math.abs(ballLateral) > goalHalfWidth * 0.6 then
            -- Мяч с краю - защищаем ближний угол
            local lateralSign = ballLateral > 0 and 1 or -1
            local lateralPos = goalRight * (lateralSign * goalHalfWidth * 0.7)
            local depth = math.clamp(distToGoal * 0.2, 1.2, 5)
            return goalPos + goalForward * depth + lateralPos
        else
            -- Мяч по центру - обычная позиция
            local depth = math.clamp(distToGoal * 0.25, 1.5, 6)
            return goalPos + goalForward * depth
        end
        
    elseif isRetreatPhase then
        -- Фаза отхода: ближе к воротам
        local depth = math.clamp(distToGoal * 0.15, 0.8, 3)
        return goalPos + goalForward * depth
        
    else
        -- Мяч далеко - стандартная позиция
        return basePos
    end
end

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

-- ИСПРАВЛЕННАЯ: Ротация только по оси Y
local function smartRotation(root, ballPos, ballVel, isDiving, diveTarget, isMyBall, isJumping)
    if isMyBall or isJumping then return end
    
    local char = root.Parent
    if not char then return end
    
    -- Если ныряем, используем специальную логику
    if isDiving and diveTarget then
        -- Определяем направление отбития для нырка
        local deflectionDir = calculateDeflectionDirection(root, ballPos, ballVel)
        local lookTarget = root.Position + deflectionDir * 10
        
        -- Мгновенная ротация только по Y
        local currentCF = root.CFrame
        local targetCF = CFrame.lookAt(root.Position, Vector3.new(lookTarget.X, root.Position.Y, lookTarget.Z))
        
        -- Сохраняем текущую высоту и наклон
        local _, y, _, z = currentCF:ToOrientation()
        local newCF = CFrame.new(root.Position) * CFrame.fromOrientation(0, y, 0)
        
        -- Плавный поворот к цели
        local targetY = math.atan2(targetCF.LookVector.X, targetCF.LookVector.Z)
        local currentY = math.atan2(newCF.LookVector.X, newCF.LookVector.Z)
        
        local angleDiff = (targetY - currentY + math.pi) % (2 * math.pi) - math.pi
        local newY = currentY + angleDiff * CONFIG.DIVE_ROTATION_SPEED
        
        root.CFrame = CFrame.new(root.Position) * CFrame.fromOrientation(0, newY, 0)
        return
    end
    
    -- Обычная ротация (не во время нырка)
    if not isDiving then
        local targetLookPos = ballPos
        
        -- Предсказываем позицию мяча
        if ballVel.Magnitude > 10 then
            local predictionPoint = ballPos + ballVel.Unit * 2
            targetLookPos = predictionPoint
        end
        
        -- Ротация только по Y (игнорируем высоту мяча)
        local currentCF = root.CFrame
        local targetCF = CFrame.lookAt(root.Position, Vector3.new(targetLookPos.X, root.Position.Y, targetLookPos.Z))
        
        local currentY = math.atan2(currentCF.LookVector.X, currentCF.LookVector.Z)
        local targetY = math.atan2(targetCF.LookVector.X, targetCF.LookVector.Z)
        
        local angleDiff = (targetY - currentY + math.pi) % (2 * math.pi) - math.pi
        
        -- Ограничиваем максимальный угол поворота за кадр
        local maxAngle = math.rad(CONFIG.MAX_ROTATION_ANGLE) * rs.RenderStepped:Wait()
        angleDiff = math.clamp(angleDiff, -maxAngle, maxAngle)
        
        local newY = currentY + angleDiff * CONFIG.ROTATION_Y_SPEED
        
        root.CFrame = CFrame.new(root.Position) * CFrame.fromOrientation(0, newY, 0)
    end
end

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

-- ИСПРАВЛЕННАЯ: Определение направления нырка
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
        local endpointToGoal = (moduleState.GoalCFrame.Position - endpoint) * Vector3.new(1,0,1)
        local endpointDist = endpointToGoal.Magnitude
        
        if endpointDist < 20 then
            local timeToReachBall = distToBall / CONFIG.AGGRESSIVE_SPEED
            local ballTravelDist = (endpoint - ballPos).Magnitude
            local timeToEndpoint = ballTravelDist / velMag
            
            if timeToEndpoint < timeToReachBall * 1.4 then
                return true
            end
        end
    end
    
    return false
end

-- ИСПРАВЛЕННАЯ: Нырок с правильным рывком и ротацией
local function performDive(root, hum, targetPos, ballHeight, ball)
    if tick() - moduleState.lastDiveTime < CONFIG.DIVE_COOLDOWN or moduleState.isDiving or moduleState.diveAnimationPlaying then return end
    
    moduleState.isDiving = true
    moduleState.diveAnimationPlaying = true
    moduleState.lastDiveTime = tick()
    
    -- Определяем сторону нырка относительно мяча и ворот
    local ballPos = ball.Position
    local goalPos = moduleState.GoalCFrame.Position
    local goalRight = moduleState.GoalRight
    
    local ballToGoal = (goalPos - ballPos) * Vector3.new(1,0,1)
    local lateralComponent = ballToGoal.Unit:Dot(goalRight)
    
    -- Определяем направление с учетом уверенности
    local dir
    if math.abs(lateralComponent) < 0.2 then
        -- Мяч почти по центру - используем последнее направление или случайное
        if moduleState.lastDiveSide and moduleState.diveDirectionConfidence > 0.5 then
            dir = moduleState.lastDiveSide
        else
            dir = math.random() > 0.5 and "Right" or "Left"
        end
    else
        -- Четкое направление
        if lateralComponent > 0 then
            dir = "Right"  -- Мяч справа - нырок вправо
        else
            dir = "Left"   -- Мяч слева - нырок влево
        end
        moduleState.lastDiveSide = dir
        moduleState.diveDirectionConfidence = math.min(moduleState.diveDirectionConfidence + 0.3, 1.0)
    end
    
    pcall(function()
        ReplicatedStorage.Remotes.Action:FireServer(dir.."dive", root.CFrame)
    end)
    
    local char = hum.Parent
    local animations = ReplicatedStorage:WaitForChild("Animations")
    local gkAnimations = animations.GK
    
    local diveAnim
    local diveDistance = moduleState.isBigGoal and CONFIG.BIG_GOAL_DIVE_DISTANCE or CONFIG.SMALL_GOAL_DIVE_DISTANCE
    
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
    
    -- Сильный рывок с увеличенной скоростью
    local diveSpeed = (diveDistance * CONFIG.DIVE_SPEED_BOOST) / CONFIG.DIVE_DURATION
    
    -- Определяем направление рывка (перпендикулярно взгляду от ворот)
    local currentLook = root.CFrame.LookVector
    local diveDirection
    
    if dir == "Right" then
        diveDirection = Vector3.new(-currentLook.Z, 0, currentLook.X)  -- Перпендикулярно вправо
    else
        diveDirection = Vector3.new(currentLook.Z, 0, -currentLook.X)  -- Перпендикулярно влево
    end
    
    local diveBV = Instance.new("BodyVelocity")
    diveBV.Parent = root
    diveBV.MaxForce = Vector3.new(1e7, 0, 1e7)
    diveBV.Velocity = diveDirection.Unit * diveSpeed * CONFIG.DIVE_FORCE_MULTIPLIER
    
    game.Debris:AddItem(diveBV, CONFIG.DIVE_DURATION * 0.7)
    
    if ball then
        for _, partName in pairs({"HumanoidRootPart", "RightHand", "LeftHand"}) do
            local part = char:FindFirstChild(partName)
            if part then
                firetouchinterest(part, ball, 0)
                task.wait(0.05)
                firetouchinterest(part, ball, 1)
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
        moduleState.diveDirectionConfidence = math.max(moduleState.diveDirectionConfidence - 0.1, 0)
    end)
end

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
            local targetPos = calculateSmartPosition(root, ball.Position, oRoot, isBallControlled, endpoint, ball.Velocity)
            local urgentDistance = moduleState.isBigGoal and 10 or 5
            local isUrgent = (endpoint and (endpoint - moduleState.GoalCFrame.Position):Dot(moduleState.GoalForward) < urgentDistance) or (velMag > 30)
            
            moveToPosition(root, targetPos, ball.Position, velMag, isUrgent)
            
            if not moduleState.isDiving then
                smartRotation(root, ball.Position, ball.Velocity, false, nil, isMyBall, moduleState.willJump)
            end
            
            if tick() - moduleState.lastActionTime > moduleState.actionCooldown then
                local goalkeeperHitbox = getGoalkeeperHitbox(char)
                
                moduleState.willJump = shouldJumpSimple(root, ball.Position, goalkeeperHitbox)
                
                if shouldIntercept(root, ball, endpoint) then
                    performIntercept(root, char, ball)
                    moduleState.lastActionTime = tick()
                elseif shouldDive(root, ball, velMag, endpoint) then
                    if endpoint then
                        local deflectionDir = calculateDeflectionDirection(root, ball.Position, ball.Velocity)
                        local diveTarget = root.Position + deflectionDir * 5
                        smartRotation(root, ball.Position, ball.Velocity, true, diveTarget, isMyBall, false)
                    end
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
    moduleState.lastDiveSide = nil
    moduleState.diveDirectionConfidence = 0
end

-- Модуль AutoGK ULTRA с исправлениями
local AutoGKUltraModule = {}

function AutoGKUltraModule.Init(UI, coreParam, notifyFunc)
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
                    notifyFunc("Syllinse", "AutoGK Enabled", true)
                else
                    cleanup()
                    notifyFunc("Syllinse", "AutoGK Disabled", true)
                end
            end
        }, 'AutoGKUltraEnabled')
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        -- НОВЫЕ: Настройки дистанций сближения и атаки
        UI.Sections.AutoGoalKeeper:Header({ Name = "Distance Settings" })
        
        moduleState.uiElements.APPROACH_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Approach Distance",
            Minimum = 20,
            Maximum = 60,
            Default = CONFIG.APPROACH_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.APPROACH_DISTANCE = v end
        }, 'AutoGKUltraApproachDist')
        
        moduleState.uiElements.ATTACK_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Attack Distance",
            Minimum = 10,
            Maximum = 40,
            Default = CONFIG.ATTACK_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.ATTACK_DISTANCE = v end
        }, 'AutoGKUltraAttackDist')
        
        moduleState.uiElements.RETREAT_DISTANCE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Retreat Distance",
            Minimum = 5,
            Maximum = 25,
            Default = CONFIG.RETREAT_DISTANCE,
            Precision = 1,
            Callback = function(v) CONFIG.RETREAT_DISTANCE = v end
        }, 'AutoGKUltraRetreatDist')
        
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
        
        -- НАСТРОЙКИ РОТАЦИИ
        UI.Sections.AutoGoalKeeper:Header({ Name = "Rotation Settings" })
        
        moduleState.uiElements.ROTATION_Y_SPEED = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Rotation Speed (Y axis)",
            Minimum = 0.1,
            Maximum = 0.8,
            Default = CONFIG.ROTATION_Y_SPEED,
            Precision = 2,
            Callback = function(v) CONFIG.ROTATION_Y_SPEED = v end
        }, 'AutoGKUltraRotYSpeed')
        
        moduleState.uiElements.MAX_ROTATION_ANGLE = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Max Rotation Angle",
            Minimum = 30,
            Maximum = 120,
            Default = CONFIG.MAX_ROTATION_ANGLE,
            Precision = 1,
            Callback = function(v) CONFIG.MAX_ROTATION_ANGLE = v end
        }, 'AutoGKUltraMaxRotAngle')
        
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
        
        moduleState.uiElements.DIVE_SPEED_BOOST = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Speed Boost",
            Minimum = 1.0,
            Maximum = 3.5,
            Default = CONFIG.DIVE_SPEED_BOOST,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_SPEED_BOOST = v end
        }, 'AutoGKUltraDiveSpeedBoost')
        
        moduleState.uiElements.DIVE_FORCE_MULTIPLIER = UI.Sections.AutoGoalKeeper:Slider({
            Name = "Dive Force Multiplier",
            Minimum = 1.0,
            Maximum = 3.0,
            Default = CONFIG.DIVE_FORCE_MULTIPLIER,
            Precision = 1,
            Callback = function(v) CONFIG.DIVE_FORCE_MULTIPLIER = v end
        }, 'AutoGKUltraDiveForceMult')
        
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
        
        UI.Sections.AutoGoalKeeper:Divider()
        
        UI.Sections.AutoGoalKeeper:Header({ Name = "Исправления" })
        
        UI.Sections.AutoGoalKeeper:Paragraph({
            Header = "Основные исправления в этой версии:",
            Body = [[
1. РОТАЦИЯ:
   - Исправлен наклон при взгляде на высокий мяч
   - Теперь вращение ТОЛЬКО по оси Y
   - Добавлен лимит максимального угла поворота
   - Исправлена логика направления взгляда

2. НЫРОК (DIVE):
   - Добавлен сильный рывок (работает через DIVE_FORCE_MULTIPLIER)
   - Исправлено определение стороны нырка
   - Добавлена система уверенности в выборе направления
   - Ротация во время нырка учитывает отскок мяча

3. НОВЫЕ НАСТРОЙКИ В UI:
   - APPROACH_DISTANCE: дистанция для сближения
   - ATTACK_DISTANCE: дистанция для атаки
   - RETREAT_DISTANCE: дистанция для отхода
   - MAX_ROTATION_ANGLE: максимальный угол поворота
   - DIVE_FORCE_MULTIPLIER: сила рывка при нырке

4. ЛОГИКА ОТБИТИЯ:
   - Мяч теперь отбивается в безопасном направлении
   - Учитывается позиция относительно ворот
   - Исправлены ошибки с определением сторон
   - Мяч не отбивается в собственные ворота
]]
        })
        
    end
    
    if UI.Tabs.Config then
        local syncSection = UI.Tabs.Config:Section({Name = 'AutoGK Sync', Side = 'Right'})
        
        syncSection:Header({ Name = "AutoGK Config Sync" })
        
        syncSection:Button({
            Name = "Sync Configuration Now",
            Callback = function()
                CONFIG.ENABLED = moduleState.uiElements.Enabled and moduleState.uiElements.Enabled:GetState()
                CONFIG.APPROACH_DISTANCE = moduleState.uiElements.APPROACH_DISTANCE and moduleState.uiElements.APPROACH_DISTANCE:GetValue()
                CONFIG.ATTACK_DISTANCE = moduleState.uiElements.ATTACK_DISTANCE and moduleState.uiElements.ATTACK_DISTANCE:GetValue()
                CONFIG.RETREAT_DISTANCE = moduleState.uiElements.RETREAT_DISTANCE and moduleState.uiElements.RETREAT_DISTANCE:GetValue()
                CONFIG.SPEED = moduleState.uiElements.SPEED and moduleState.uiElements.SPEED:GetValue()
                CONFIG.AGGRESSIVE_SPEED = moduleState.uiElements.AGGRESSIVE_SPEED and moduleState.uiElements.AGGRESSIVE_SPEED:GetValue()
                CONFIG.STAND_DIST = moduleState.uiElements.STAND_DIST and moduleState.uiElements.STAND_DIST:GetValue()
                CONFIG.MIN_DIST = moduleState.uiElements.MIN_DIST and moduleState.uiElements.MIN_DIST:GetValue() 
                CONFIG.ROTATION_Y_SPEED = moduleState.uiElements.ROTATION_Y_SPEED and moduleState.uiElements.ROTATION_Y_SPEED:GetValue()
                CONFIG.MAX_ROTATION_ANGLE = moduleState.uiElements.MAX_ROTATION_ANGLE and moduleState.uiElements.MAX_ROTATION_ANGLE:GetValue()
                CONFIG.DIVE_DIST = moduleState.uiElements.DIVE_DIST and moduleState.uiElements.DIVE_DIST:GetValue()
                CONFIG.DIVE_VEL_THRES = moduleState.uiElements.DIVE_VEL_THRES and moduleState.uiElements.DIVE_VEL_THRES:GetValue()
                CONFIG.DIVE_COOLDOWN = moduleState.uiElements.DIVE_COOLDOWN and moduleState.uiElements.DIVE_COOLDOWN:GetValue()
                CONFIG.DIVE_SPEED_BOOST = moduleState.uiElements.DIVE_SPEED_BOOST and moduleState.uiElements.DIVE_SPEED_BOOST:GetValue()
                CONFIG.DIVE_FORCE_MULTIPLIER = moduleState.uiElements.DIVE_FORCE_MULTIPLIER and moduleState.uiElements.DIVE_FORCE_MULTIPLIER:GetValue()
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
                CONFIG.SHOW_TRAJECTORY = moduleState.uiElements.SHOW_TRAJECTORY and moduleState.uiElements.SHOW_TRAJECTORY:GetState()
                CONFIG.SHOW_ENDPOINT = moduleState.uiElements.SHOW_ENDPOINT and moduleState.uiElements.SHOW_ENDPOINT:GetState()
                CONFIG.SHOW_GOAL_CUBE = moduleState.uiElements.SHOW_GOAL_CUBE and moduleState.uiElements.SHOW_GOAL_CUBE:GetState()
                CONFIG.SHOW_ZONE = moduleState.uiElements.SHOW_ZONE and moduleState.uiElements.SHOW_ZONE:GetState()
                CONFIG.SHOW_BALL_BOX = moduleState.uiElements.SHOW_BALL_BOX and moduleState.uiElements.SHOW_BALL_BOX:GetState()
                
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
