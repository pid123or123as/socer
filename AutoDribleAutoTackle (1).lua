-- [v2.5] AUTO DRIBBLE + AUTO TACKLE + УПРОЩЕННЫЙ GUI
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local ActionRemote = ReplicatedStorage.Remotes:WaitForChild("Action")
local SoftDisPlayerRemote = ReplicatedStorage.Remotes:WaitForChild("SoftDisPlayer")
local Animations = ReplicatedStorage:WaitForChild("Animations")
local DribbleAnims = Animations:WaitForChild("Dribble")

-- === АНИМАЦИИ ===
local DribbleAnimIds = {}
for _, anim in pairs(DribbleAnims:GetChildren()) do
    if anim:IsA("Animation") then
        table.insert(DribbleAnimIds, anim.AnimationId)
    end
end

-- === ПИНГ ===
local function GetPing()
    local success, pingValue = pcall(function()
        local pingStat = Stats.Network.ServerStatsItem["Data Ping"]
        local pingStr = pingStat:GetValueString()
        local ping = tonumber(pingStr:match("%d+"))
        return ping or 0
    end)
    
    if success and pingValue then
        return pingValue / 1000 -- конвертируем в секунды
    end
    
    return 0.1 -- fallback значение
end

-- === CONFIG ===
local AutoTackleConfig = {
    Enabled = false,
    Mode = "OnlyDribble", -- "OnlyDribble", "EagleEye", "ManualTackle"
    MaxDistance = 20,
    TackleDistance = 0,
    OptimalDistanceMin = 3,
    OptimalDistanceMax = 15,
    TackleSpeed = 47,
    OnlyPlayer = true,
    RotationMethod = "Snap",
    RotationType = "SmoothCFrame",
    MaxAngle = 360,
    DribbleDelayTime = 0.3,
    EagleEyeMinDelay = 0.1,
    EagleEyeMaxDelay = 0.6,
    ManualTackleEnabled = true,
    ManualTackleKeybind = Enum.KeyCode.Q,
    ManualTackleCooldown = 0.5,
    ManualButton = false,
    ButtonScale = 1.0,
    
    -- Улучшенный предикт
    UseAdvancedPrediction = true,
    TackleLeadTime = 0.2, -- время упреждения для такла
}

local AutoDribbleConfig = {
    Enabled = false,
    MaxDribbleDistance = 30,
    DribbleActivationDistance = 16,
    PredictionTime = 0.098,
    TacklePredictionTime = 0.3,
    
    -- Улучшенный AutoDribble
    UseServerPosition = true, -- использовать серверную позицию
    DribbleReactionTime = 0.05, -- время реакции на противника
    MinDribbleDelay = 0.01, -- минимальная задержка между дриблами
    AccelerationFactor = 1.2, -- фактор ускорения реакции
    PredictiveDribble = true, -- предиктивный дрибл
    SmartAngleCheck = true, -- проверка угла атаки
    MinAngleForDribble = 30, -- минимальный угол для дрибла
}

-- === DEBUG CONFIG ===
local DebugConfig = {
    Enabled = true,
    MoveEnabled = false,
    Position = Vector2.new(0.5, 0.5)
}

-- === STATES ===
local AutoTackleStatus = {
    Running = false,
    Connection = nil,
    HeartbeatConnection = nil,
    InputConnection = nil,
    ButtonGui = nil,
    TouchStartTime = 0,
    Dragging = false,
    DragStart = Vector2.new(0, 0),
    StartPos = UDim2.new(0, 0, 0, 0),
    
    -- Для улучшенного предикта
    TargetHistory = {},
    Ping = 0.1,
    LastPingUpdate = 0,
    LastPredictionUpdate = 0,
    PredictionCache = {}
}
local AutoDribbleStatus = {
    Running = false,
    Connection = nil,
    
    -- Для улучшенного AutoDribble
    LastDribbleTime = 0,
    ServerPosition = Vector3.new(0, 0, 0),
    ReactionBoost = 1.0,
    LastTackleDetectionTime = 0
}

-- === SHARED STATES ===
local DribbleStates = {}
local TackleStates = {}
local PrecomputedPlayers = {}
local HasBall = false
local CanDribbleNow = false
local DribbleCooldownList = {}
local PowerShootingPlayers = {}
local EagleEyeTimers = {}
local IsTypingInChat = false
local LastManualTackleTime = 0
local CurrentTargetOwner = nil

local SPECIFIC_TACKLE_ID = "rbxassetid://14317040670"

-- === GUI (Drawing) ===
local Gui = nil
local function SetupGUI()
    Gui = {
        TackleWaitLabel = Drawing.new("Text"),
        TackleTargetLabel = Drawing.new("Text"),
        TackleDribblingLabel = Drawing.new("Text"),
        TackleTacklingLabel = Drawing.new("Text"),
        EagleEyeLabel = Drawing.new("Text"),
        DribbleStatusLabel = Drawing.new("Text"),
        DribbleTargetLabel = Drawing.new("Text"),
        DribbleTacklingLabel = Drawing.new("Text"),
        AutoDribbleLabel = Drawing.new("Text"),
        CooldownListLabel = Drawing.new("Text"),
        ModeLabel = Drawing.new("Text"),
        ManualTackleLabel = Drawing.new("Text"),
        PingLabel = Drawing.new("Text"),
        TargetRingLines = {},
        TargetRings = {},
        
        TackleDebugLabels = {},
        DribbleDebugLabels = {}
    }
    
    local screenSize = Camera.ViewportSize
    local centerX = screenSize.X / 2
    local tackleY = screenSize.Y * 0.6
    local offsetTackleY = tackleY + 30
    local offsetDribbleY = tackleY - 50
    
    -- Текстовые метки AutoTackle
    local tackleLabels = {
        Gui.TackleWaitLabel, Gui.TackleTargetLabel, Gui.TackleDribblingLabel,
        Gui.TackleTacklingLabel, Gui.EagleEyeLabel, Gui.CooldownListLabel,
        Gui.ModeLabel, Gui.ManualTackleLabel, Gui.PingLabel
    }
    
    for _, label in ipairs(tackleLabels) do
        label.Size = 16
        label.Color = Color3.fromRGB(255, 255, 255)
        label.Outline = true
        label.Center = true
        label.Visible = DebugConfig.Enabled and AutoTackleConfig.Enabled
        table.insert(Gui.TackleDebugLabels, label)
    end
    
    Gui.TackleWaitLabel.Color = Color3.fromRGB(255, 165, 0)
    Gui.TackleWaitLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.TackleTargetLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.TackleDribblingLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.TackleTacklingLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.EagleEyeLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.CooldownListLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.ModeLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.ManualTackleLabel.Position = Vector2.new(centerX, offsetTackleY); offsetTackleY += 15
    Gui.PingLabel.Position = Vector2.new(centerX, offsetTackleY)
    
    -- Текстовые метки AutoDribble
    local dribbleLabels = {
        Gui.DribbleStatusLabel, Gui.DribbleTargetLabel,
        Gui.DribbleTacklingLabel, Gui.AutoDribbleLabel
    }
    
    for _, label in ipairs(dribbleLabels) do
        label.Size = 16
        label.Color = Color3.fromRGB(255, 255, 255)
        label.Outline = true
        label.Center = true
        label.Visible = DebugConfig.Enabled and AutoDribbleConfig.Enabled
        table.insert(Gui.DribbleDebugLabels, label)
    end
    
    Gui.DribbleStatusLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.DribbleTargetLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.DribbleTacklingLabel.Position = Vector2.new(centerX, offsetDribbleY); offsetDribbleY += 15
    Gui.AutoDribbleLabel.Position = Vector2.new(centerX, offsetDribbleY)
    
    Gui.TackleWaitLabel.Text = "Wait: 0.00"
    Gui.TackleTargetLabel.Text = "Target: None"
    Gui.TackleDribblingLabel.Text = "isDribbling: false"
    Gui.TackleTacklingLabel.Text = "isTackling: false"
    Gui.EagleEyeLabel.Text = "EagleEye: Idle"
    Gui.CooldownListLabel.Text = "CooldownList: 0"
    Gui.ModeLabel.Text = "Mode: " .. AutoTackleConfig.Mode
    Gui.ManualTackleLabel.Text = "ManualTackle: Ready [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
    Gui.PingLabel.Text = "Ping: 0ms"
    Gui.DribbleStatusLabel.Text = "Dribble: Ready"
    Gui.DribbleTargetLabel.Text = "Targets: 0"
    Gui.DribbleTacklingLabel.Text = "Nearest: None"
    Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
    
    for i = 1, 24 do
        local line = Drawing.new("Line")
        line.Thickness = 3
        line.Color = Color3.fromRGB(255, 0, 0)
        line.Visible = false
        table.insert(Gui.TargetRingLines, line)
    end
end

local function UpdateDebugVisibility()
    if not Gui then return end
    
    local tackleVisible = DebugConfig.Enabled and AutoTackleConfig.Enabled
    for _, label in ipairs(Gui.TackleDebugLabels) do
        label.Visible = tackleVisible
    end
    
    local dribbleVisible = DebugConfig.Enabled and AutoDribbleConfig.Enabled
    for _, label in ipairs(Gui.DribbleDebugLabels) do
        label.Visible = dribbleVisible
    end
    
    if not AutoTackleConfig.Enabled then
        for _, line in ipairs(Gui.TargetRingLines) do
            line.Visible = false
        end
    end
    
    if AutoTackleStatus.ButtonGui and AutoTackleStatus.ButtonGui:FindFirstChild("ManualTackleButton") then
        AutoTackleStatus.ButtonGui.ManualTackleButton.Visible = AutoTackleConfig.ManualButton and AutoTackleConfig.Enabled
    end
end

local function CleanupDebugText()
    if not Gui then return end
    
    if not AutoTackleConfig.Enabled then
        Gui.TackleWaitLabel.Text = "Wait: 0.00"
        Gui.TackleTargetLabel.Text = "Target: None"
        Gui.TackleDribblingLabel.Text = "isDribbling: false"
        Gui.TackleTacklingLabel.Text = "isTackling: false"
        Gui.EagleEyeLabel.Text = "EagleEye: Idle"
        Gui.ManualTackleLabel.Text = "ManualTackle: Ready [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
        Gui.ModeLabel.Text = "Mode: " .. AutoTackleConfig.Mode
        Gui.PingLabel.Text = "Ping: 0ms"
    end
    
    if not AutoDribbleConfig.Enabled then
        Gui.DribbleStatusLabel.Text = "Dribble: Ready"
        Gui.DribbleTargetLabel.Text = "Targets: 0"
        Gui.DribbleTacklingLabel.Text = "Nearest: None"
        Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
    end
end

-- === ОСНОВНЫЕ ФУНКЦИИ ===
local function UpdatePing()
    local currentTime = tick()
    if currentTime - AutoTackleStatus.LastPingUpdate > 1 then
        AutoTackleStatus.Ping = GetPing()
        AutoTackleStatus.LastPingUpdate = currentTime
        
        if Gui and AutoTackleConfig.Enabled then
            Gui.PingLabel.Text = string.format("Ping: %dms", math.round(AutoTackleStatus.Ping * 1000))
        end
    end
end

local function CheckIfTypingInChat()
    local success, result = pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name == "Chat" or gui.Name:find("Chat")) then
                local textBox = gui:FindFirstChild("TextBox", true)
                if textBox then
                    return textBox:IsFocused()
                end
            end
        end
        return false
    end)
    
    return success and result or false
end

local function IsDribbling(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Parent or targetPlayer.TeamColor == LocalPlayer.TeamColor then return false end
    local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
    if not targetHumanoid then return false end
    local animator = targetHumanoid:FindFirstChild("Animator")
    if not animator then return false end
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Animation and table.find(DribbleAnimIds, track.Animation.AnimationId) then
            return true
        end
    end
    return false
end

local function IsSpecificTackle(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Parent or targetPlayer.TeamColor == LocalPlayer.TeamColor then
        return false
    end
    local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    local animator = humanoid:FindFirstChild("Animator")
    if not animator then return false end
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId == SPECIFIC_TACKLE_ID then
            return true
        end
    end
    return false
end

local function UpdateDribbleStates()
    local currentTime = tick()
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Parent or player.TeamColor == LocalPlayer.TeamColor then continue end
        
        if not DribbleStates[player] then
            DribbleStates[player] = {
                IsDribbling = false,
                LastDribbleEnd = 0,
                HasUsedDribble = false,
                IsProcessingDelay = false
            }
        end
        
        local state = DribbleStates[player]
        local isDribblingNow = IsDribbling(player)
        
        if isDribblingNow and not state.IsDribbling then
            state.IsDribbling = true
            state.IsProcessingDelay = false
            state.HasUsedDribble = true
        elseif not isDribblingNow and state.IsDribbling then
            state.IsDribbling = false
            state.LastDribbleEnd = currentTime
            state.IsProcessingDelay = true
        elseif state.IsProcessingDelay and not isDribblingNow then
            local timeSinceEnd = currentTime - state.LastDribbleEnd
            if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                DribbleCooldownList[player] = currentTime + 3.5
                state.IsProcessingDelay = false
            end
        end
    end
    
    local toRemove = {}
    for player, endTime in pairs(DribbleCooldownList) do
        if not player or not player.Parent then
            table.insert(toRemove, player)
        elseif currentTime >= endTime then
            table.insert(toRemove, player)
        end
    end
    
    for _, player in ipairs(toRemove) do
        DribbleCooldownList[player] = nil
        EagleEyeTimers[player] = nil
    end
    
    if Gui and AutoTackleConfig.Enabled then
        Gui.CooldownListLabel.Text = "CooldownList: " .. tostring(table.count(DribbleCooldownList))
    end
end

-- === УЛУЧШЕННЫЙ PREDICT ДЛЯ AUTOTACKLE ===
local function PredictBallPositionAdvanced(ball, owner)
    if not ball or not ball.Parent or not owner then return ball.Position end
    
    local currentTime = tick()
    local cacheKey = tostring(owner) .. "_" .. tostring(math.floor(currentTime * 10))
    
    -- Используем кеш для оптимизации
    if AutoTackleStatus.PredictionCache[cacheKey] then
        return AutoTackleStatus.PredictionCache[cacheKey]
    end
    
    local ownerChar = owner.Character
    local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
    
    if not ownerRoot then
        return ball.Position
    end
    
    -- Получаем историю движений
    local ownerHistory = AutoTackleStatus.TargetHistory[owner] or {}
    table.insert(ownerHistory, {
        time = currentTime,
        position = ownerRoot.Position,
        velocity = ownerRoot.AssemblyLinearVelocity
    })
    
    -- Ограничиваем размер истории
    if #ownerHistory > 10 then
        table.remove(ownerHistory, 1)
    end
    AutoTackleStatus.TargetHistory[owner] = ownerHistory
    
    -- Рассчитываем время с учетом пинга и скорости такла
    local distanceToBall = (HumanoidRootPart.Position - ball.Position).Magnitude
    local timeToReach = distanceToBall / AutoTackleConfig.TackleSpeed
    local totalPredictionTime = timeToReach + AutoTackleStatus.Ping + AutoTackleConfig.TackleLeadTime
    
    -- Используем историю для предсказания
    local predictedPos = ownerRoot.Position
    local currentVelocity = ownerRoot.AssemblyLinearVelocity
    
    if #ownerHistory >= 3 then
        -- Рассчитываем ускорение
        local recentEntries = {}
        for i = math.max(1, #ownerHistory - 2), #ownerHistory do
            table.insert(recentEntries, ownerHistory[i])
        end
        
        if #recentEntries >= 3 then
            local accelerations = {}
            for i = 2, #recentEntries do
                local dt = recentEntries[i].time - recentEntries[i-1].time
                if dt > 0 then
                    local acceleration = (recentEntries[i].velocity - recentEntries[i-1].velocity) / dt
                    table.insert(accelerations, acceleration)
                end
            end
            
            if #accelerations > 0 then
                -- Усредняем ускорение
                local avgAcceleration = Vector3.new(0, 0, 0)
                for _, acc in ipairs(accelerations) do
                    avgAcceleration = avgAcceleration + acc
                end
                avgAcceleration = avgAcceleration / #accelerations
                
                -- Применяем ускорение к предсказанию
                predictedPos = predictedPos + currentVelocity * totalPredictionTime + 
                              avgAcceleration * totalPredictionTime * totalPredictionTime * 0.5
            else
                predictedPos = predictedPos + currentVelocity * totalPredictionTime
            end
        else
            predictedPos = predictedPos + currentVelocity * totalPredictionTime
        end
    else
        predictedPos = predictedPos + currentVelocity * totalPredictionTime
    end
    
    -- Кешируем результат
    AutoTackleStatus.PredictionCache[cacheKey] = predictedPos
    
    -- Очищаем старый кеш
    for key, _ in pairs(AutoTackleStatus.PredictionCache) do
        if not key:find(tostring(owner)) then
            AutoTackleStatus.PredictionCache[key] = nil
        end
    end
    
    return predictedPos
end

-- === УЛУЧШЕННЫЙ AUTODRIBBLE ===
local function UpdateServerPosition()
    if not AutoDribbleConfig.UseServerPosition then return end
    
    local ping = AutoTackleStatus.Ping
    AutoDribbleStatus.ServerPosition = HumanoidRootPart.Position - HumanoidRootPart.AssemblyLinearVelocity * ping * 0.5
end

local function ShouldDribbleNow(specificTarget, tacklerData)
    if not specificTarget or not tacklerData then return false end
    
    local currentTime = tick()
    local timeSinceLastDribble = currentTime - AutoDribbleStatus.LastDribbleTime
    
    -- Проверяем минимальную задержку
    if timeSinceLastDribble < AutoDribbleConfig.MinDribbleDelay then
        return false
    end
    
    -- Улучшенная проверка угла атаки
    if AutoDribbleConfig.SmartAngleCheck then
        local myPosition = AutoDribbleConfig.UseServerPosition and AutoDribbleStatus.ServerPosition or HumanoidRootPart.Position
        local tacklerPosition = tacklerData.RootPart.Position
        local tacklerVelocity = tacklerData.Velocity
        
        -- Вектор от меня к таклеру
        local toTackler = (tacklerPosition - myPosition)
        local distance = toTackler.Magnitude
        
        -- Если слишком далеко, не дриблим
        if distance > AutoDribbleConfig.MaxDribbleDistance then
            return false
        end
        
        -- Проверяем угол атаки
        local myLookVector = HumanoidRootPart.CFrame.LookVector
        local angleToTackler = math.deg(math.acos(myLookVector:Dot(toTackler.Unit)))
        
        -- Если таклер идет прямо на нас, используем дрибл
        local tacklerToMe = (myPosition - tacklerPosition).Unit
        local tacklerLookVector = tacklerVelocity.Unit
        local tacklerAngleToMe = math.deg(math.acos(tacklerLookVector:Dot(tacklerToMe)))
        
        -- Условия для использования дрибла:
        -- 1. Таклер находится впереди нас (меньше 90 градусов)
        -- 2. Таклер идет почти прямо на нас (малый угол)
        -- 3. Расстояние подходит для активации
        if angleToTackler < 90 and tacklerAngleToMe < AutoDribbleConfig.MinAngleForDribble then
            local timeToCollision = distance / (tacklerVelocity.Magnitude + HumanoidRootPart.AssemblyLinearVelocity.Magnitude)
            
            -- Используем дрибл, когда до столкновения осталось мало времени
            if timeToCollision < 0.4 then -- 0.4 секунды до столкновения
                return true
            end
        end
    end
    
    -- Стандартная проверка расстояния
    local distance = tacklerData.Distance
    if distance <= AutoDribbleConfig.DribbleActivationDistance then
        return true
    end
    
    return false
end

local function PerformDribble()
    local currentTime = tick()
    local timeSinceLastDribble = currentTime - AutoDribbleStatus.LastDribbleTime
    
    if timeSinceLastDribble < AutoDribbleConfig.MinDribbleDelay then
        return
    end
    
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.dribbleDebounce.Value then return end
    
    -- Выполняем дрибл
    pcall(function() ActionRemote:FireServer("Deke") end)
    AutoDribbleStatus.LastDribbleTime = currentTime
    
    -- Динамически корректируем скорость реакции
    if timeSinceLastDribble < 0.5 then
        AutoDribbleStatus.ReactionBoost = math.min(AutoDribbleStatus.ReactionBoost * AutoDribbleConfig.AccelerationFactor, 2.0)
    else
        AutoDribbleStatus.ReactionBoost = math.max(AutoDribbleStatus.ReactionBoost * 0.95, 1.0)
    end
    
    if Gui and AutoDribbleConfig.Enabled then
        Gui.DribbleStatusLabel.Text = "Dribble: Cooldown"
        Gui.DribbleStatusLabel.Color = Color3.fromRGB(255, 0, 0)
        Gui.AutoDribbleLabel.Text = "AutoDribble: DEKE!"
    end
end

-- === ОСТАЛЬНЫЕ ФУНКЦИИ (упрощенные) ===
local function PrecomputePlayers()
    PrecomputedPlayers = {}
    HasBall = false
    CanDribbleNow = false

    local ball = Workspace:FindFirstChild("ball")
    if ball and ball:FindFirstChild("playerWeld") and ball:FindFirstChild("creator") then
        HasBall = ball.creator.Value == LocalPlayer
    end

    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if bools then
        CanDribbleNow = not bools.dribbleDebounce.Value
        if Gui and AutoDribbleConfig.Enabled then
            Gui.DribbleStatusLabel.Text = bools.dribbleDebounce.Value and "Dribble: Cooldown" or "Dribble: Ready"
            Gui.DribbleStatusLabel.Color = bools.dribbleDebounce.Value and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
        end
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Parent or player.TeamColor == LocalPlayer.TeamColor then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.HipHeight >= 4 then continue end
        local targetRoot = character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then continue end

        TackleStates[player] = TackleStates[player] or { IsTackling = false }
        TackleStates[player].IsTackling = IsSpecificTackle(player)

        local distance = (targetRoot.Position - HumanoidRootPart.Position).Magnitude
        if distance > AutoDribbleConfig.MaxDribbleDistance then continue end

        -- Улучшенный предикт для AutoDribble
        local predictedPos
        if AutoDribbleConfig.PredictiveDribble then
            predictedPos = targetRoot.Position + targetRoot.AssemblyLinearVelocity * AutoDribbleConfig.PredictionTime
        else
            predictedPos = targetRoot.Position
        end

        PrecomputedPlayers[player] = {
            Distance = distance,
            PredictedPos = predictedPos,
            IsValid = true,
            IsTackling = TackleStates[player].IsTackling,
            RootPart = targetRoot,
            Velocity = targetRoot.AssemblyLinearVelocity
        }
    end
end

local function CanTackle()
    local ball = Workspace:FindFirstChild("ball")
    if not ball or not ball.Parent then return false, nil, nil, nil end
    local hasOwner = ball:FindFirstChild("playerWeld") and ball:FindFirstChild("creator")
    local owner = hasOwner and ball.creator.Value or nil
    if AutoTackleConfig.OnlyPlayer and (not hasOwner or not owner or not owner.Parent) then
        return false, nil, nil, nil
    end
    local isEnemy = not owner or (owner and owner.TeamColor ~= LocalPlayer.TeamColor)
    if not isEnemy then return false, nil, nil, nil end
    if Workspace:FindFirstChild("Bools") and (Workspace.Bools.APG.Value == LocalPlayer or Workspace.Bools.HPG.Value == LocalPlayer) then
        return false, nil, nil, nil
    end
    local distance = (HumanoidRootPart.Position - ball.Position).Magnitude
    if distance > AutoTackleConfig.MaxDistance then
        return false, nil, nil, nil
    end
    if owner and owner.Character then
        local targetHumanoid = owner.Character:FindFirstChild("Humanoid")
        if targetHumanoid and targetHumanoid.HipHeight >= 4 then
            return false, nil, nil, nil
        end
    end
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if bools and (bools.TackleDebounce.Value or bools.Tackled.Value or Character:FindFirstChild("Bools") and Character.Bools.Debounce.Value) then
        return false, nil, nil, nil
    end
    return true, ball, distance, owner
end

local function RotateToTarget(targetPos)
    if AutoTackleConfig.RotationType == "SmoothCFrame" then
        local currentCFrame = HumanoidRootPart.CFrame
        local targetCFrame = CFrame.new(HumanoidRootPart.Position, Vector3.new(targetPos.X, HumanoidRootPart.Position.Y, targetPos.Z))
        local newCFrame = currentCFrame:Lerp(targetCFrame, 0.3)
        HumanoidRootPart.CFrame = newCFrame
    elseif AutoTackleConfig.RotationType == "CFrame" then
        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, Vector3.new(targetPos.X, HumanoidRootPart.Position.Y, targetPos.Z))
    end
end

local function PerformTackle(ball, owner)
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.TackleDebounce.Value or bools.Tackled.Value or Character:FindFirstChild("Bools") and Character.Bools.Debounce.Value then return end
    
    -- Используем улучшенный предикт
    local predictedPos
    if AutoTackleConfig.UseAdvancedPrediction then
        predictedPos = PredictBallPositionAdvanced(ball, owner)
    else
        predictedPos = ball.Position
    end
    
    -- Ротация перед таклом
    if AutoTackleConfig.RotationMethod == "Snap" or AutoTackleConfig.RotationMethod == "Always" then
        RotateToTarget(predictedPos)
    end
    
    -- Выполняем такл
    pcall(function() ActionRemote:FireServer("TackIe") end)
    
    -- Создаем BodyVelocity для движения
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Parent = HumanoidRootPart
    bodyVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * AutoTackleConfig.TackleSpeed
    bodyVelocity.MaxForce = Vector3.new(50000000, 0, 50000000)
    
    -- Плавная ротация во время такла
    local tackleStartTime = tick()
    local tackleDuration = 0.65
    
    local rotateConnection = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - tackleStartTime
        if elapsed < tackleDuration then
            RotateToTarget(predictedPos)
        else
            rotateConnection:Disconnect()
        end
    end)
    
    Debris:AddItem(bodyVelocity, tackleDuration)
    
    task.delay(tackleDuration, function()
        if rotateConnection then
            rotateConnection:Disconnect()
        end
    end)
    
    if owner and ball:FindFirstChild("playerWeld") then
        local distance = (HumanoidRootPart.Position - ball.Position).Magnitude
        pcall(function() SoftDisPlayerRemote:FireServer(owner, distance, false, ball.Size) end)
    end
end

-- === MODULES ===
local AutoTackle = {}
AutoTackle.Start = function()
    if AutoTackleStatus.Running then return end
    AutoTackleStatus.Running = true
    
    if not Gui then SetupGUI() end
    
    AutoTackleStatus.HeartbeatConnection = RunService.Heartbeat:Connect(function()
        pcall(UpdatePing)
        pcall(UpdateDribbleStates)
        pcall(PrecomputePlayers)
        IsTypingInChat = CheckIfTypingInChat()
    end)
    
    AutoTackleStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoTackleConfig.Enabled then 
            CleanupDebugText()
            UpdateDebugVisibility()
            return 
        end
        
        pcall(function()
            local canTackle, ball, distance, owner = CanTackle()
            if not canTackle or not ball then
                if Gui then
                    Gui.TackleTargetLabel.Text = "Target: None"
                    Gui.TackleDribblingLabel.Text = "isDribbling: false"
                    Gui.TackleTacklingLabel.Text = "isTackling: false"
                    Gui.TackleWaitLabel.Text = "Wait: 0.00"
                    if AutoTackleConfig.Mode == "ManualTackle" then
                        Gui.ManualTackleLabel.Text = "ManualTackle: NO TARGET [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
                        Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 0, 0)
                    end
                end
                CurrentTargetOwner = nil
                return
            end
            
            if distance <= AutoTackleConfig.TackleDistance then
                PerformTackle(ball, owner)
            else
                -- Обработка различных режимов
                if AutoTackleConfig.Mode ~= "ManualTackle" then
                    local shouldTackle = false
                    
                    if owner then
                        local state = DribbleStates[owner] or {IsDribbling = false, LastDribbleEnd = 0}
                        local inCooldownList = DribbleCooldownList[owner] ~= nil
                        
                        if AutoTackleConfig.Mode == "EagleEye" then
                            shouldTackle = inCooldownList or (state.IsDribbling and (tick() - state.LastDribbleEnd >= AutoTackleConfig.DribbleDelayTime))
                        elseif AutoTackleConfig.Mode == "OnlyDribble" then
                            shouldTackle = inCooldownList
                        end
                    end
                    
                    if shouldTackle then
                        PerformTackle(ball, owner)
                    end
                end
            end
        end)
    end)
    
    UpdateDebugVisibility()
    if notify then
        notify("AutoTackle", "Started", true)
    end
end

AutoTackle.Stop = function()
    if AutoTackleStatus.Connection then AutoTackleStatus.Connection:Disconnect(); AutoTackleStatus.Connection = nil end
    if AutoTackleStatus.HeartbeatConnection then AutoTackleStatus.HeartbeatConnection:Disconnect(); AutoTackleStatus.HeartbeatConnection = nil end
    if AutoTackleStatus.InputConnection then AutoTackleStatus.InputConnection:Disconnect(); AutoTackleStatus.InputConnection = nil end
    AutoTackleStatus.Running = false
    
    CleanupDebugText()
    UpdateDebugVisibility()
    
    if notify then
        notify("AutoTackle", "Stopped", true)
    end
end

local AutoDribble = {}
AutoDribble.Start = function()
    if AutoDribbleStatus.Running then return end
    AutoDribbleStatus.Running = true
    
    AutoDribbleStatus.Connection = RunService.RenderStepped:Connect(function()
        if not AutoDribbleConfig.Enabled then
            CleanupDebugText()
            UpdateDebugVisibility()
            return
        end

        pcall(function()
            UpdateServerPosition()
            
            local specificTarget = nil
            local minDist = math.huge
            local targetCount = 0
            local nearestTacklerData = nil

            for player, data in pairs(PrecomputedPlayers) do
                if data.IsValid and TackleStates[player].IsTackling then
                    targetCount += 1
                    if data.Distance < minDist then
                        minDist = data.Distance
                        specificTarget = player
                        nearestTacklerData = data
                    end
                end
            end

            if Gui then
                Gui.DribbleTargetLabel.Text = "Targets: " .. targetCount
                Gui.DribbleTacklingLabel.Text = specificTarget and string.format("Tackle: %.1f", minDist) or "Tackle: None"
            end

            if HasBall and CanDribbleNow and specificTarget and nearestTacklerData then
                if ShouldDribbleNow(specificTarget, nearestTacklerData) then
                    PerformDribble()
                else
                    if Gui then
                        Gui.AutoDribbleLabel.Text = "AutoDribble: Waiting"
                    end
                end
            else
                if Gui then
                    Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
                end
            end
        end)
    end)
    
    UpdateDebugVisibility()
    if notify then
        notify("AutoDribble", "Started", true)
    end
end

AutoDribble.Stop = function()
    if AutoDribbleStatus.Connection then AutoDribbleStatus.Connection:Disconnect(); AutoDribbleStatus.Connection = nil end
    AutoDribbleStatus.Running = false
    
    CleanupDebugText()
    UpdateDebugVisibility()
    if notify then
        notify("AutoDribble", "Stopped", true)
    end
end

-- === UI С УПРОЩЕННЫМИ НАСТРОЙКАМИ ===
local uiElements = {}
local function SetupUI(UI)
    -- Секция AutoTackle
    if UI.Sections.AutoTackle then
        UI.Sections.AutoTackle:Header({ Name = "AutoTackle" })
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleEnabled = UI.Sections.AutoTackle:Toggle({ 
            Name = "Enabled", 
            Default = AutoTackleConfig.Enabled, 
            Callback = function(v) 
                AutoTackleConfig.Enabled = v
                if v then 
                    AutoTackle.Start() 
                else 
                    AutoTackle.Stop() 
                end
                UpdateDebugVisibility()
            end
        }, "AutoTackleEnabled")
        
        uiElements.AutoTackleMode = UI.Sections.AutoTackle:Dropdown({
            Name = "Mode",
            Default = AutoTackleConfig.Mode,
            Options = {"OnlyDribble", "EagleEye", "ManualTackle"},
            Callback = function(v)
                AutoTackleConfig.Mode = v
                if Gui then
                    Gui.ModeLabel.Text = "Mode: " .. v
                end
            end
        }, "AutoTackleMode")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleMaxDistance = UI.Sections.AutoTackle:Slider({
            Name = "Max Distance",
            Minimum = 5,
            Maximum = 50,
            Default = AutoTackleConfig.MaxDistance,
            Precision = 1,
            Callback = function(v) AutoTackleConfig.MaxDistance = v end
        }, "AutoTackleMaxDistance")
        
        uiElements.AutoTackleTackleDistance = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Distance",
            Minimum = 0,
            Maximum = 20,
            Default = AutoTackleConfig.TackleDistance,
            Precision = 1,
            Callback = function(v) AutoTackleConfig.TackleDistance = v end
        }, "AutoTackleTackleDistance")
        
        uiElements.AutoTackleTackleSpeed = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Speed",
            Minimum = 10,
            Maximum = 100,
            Default = AutoTackleConfig.TackleSpeed,
            Precision = 1,
            Callback = function(v) AutoTackleConfig.TackleSpeed = v end
        }, "AutoTackleTackleSpeed")
        
        uiElements.AutoTackleTackleLeadTime = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Lead Time",
            Minimum = 0.0,
            Maximum = 0.5,
            Default = AutoTackleConfig.TackleLeadTime,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.TackleLeadTime = v end
        }, "AutoTackleTackleLeadTime")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleOnlyPlayer = UI.Sections.AutoTackle:Toggle({
            Name = "Only Player",
            Default = AutoTackleConfig.OnlyPlayer,
            Callback = function(v) AutoTackleConfig.OnlyPlayer = v end
        }, "AutoTackleOnlyPlayer")
        
        uiElements.AutoTackleUseAdvancedPrediction = UI.Sections.AutoTackle:Toggle({
            Name = "Advanced Prediction",
            Default = AutoTackleConfig.UseAdvancedPrediction,
            Callback = function(v) AutoTackleConfig.UseAdvancedPrediction = v end
        }, "AutoTackleUseAdvancedPrediction")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleManualTackleEnabled = UI.Sections.AutoTackle:Toggle({
            Name = "Manual Tackle Enabled",
            Default = AutoTackleConfig.ManualTackleEnabled,
            Callback = function(v) AutoTackleConfig.ManualTackleEnabled = v end
        }, "AutoTackleManualTackleEnabled")
        
        uiElements.AutoTackleManualTackleKeybind = UI.Sections.AutoTackle:Keybind({
            Name = "Manual Tackle Key",
            Default = AutoTackleConfig.ManualTackleKeybind,
            Callback = function(v) AutoTackleConfig.ManualTackleKeybind = v end
        }, "AutoTackleManualTackleKeybind")
        
        UI.Sections.AutoTackle:Divider()
        UI.Sections.AutoTackle:Paragraph({
            Header = "Information",
            Body = "OnlyDribble: Tackle when enemy dribble is on cooldown\nEagleEye: Wait for dribble cooldown\nManualTackle: Only tackle when you press the key"
        })
    end
    
    -- Секция AutoDribble
    if UI.Sections.AutoDribble then
        UI.Sections.AutoDribble:Header({ Name = "AutoDribble" })
        UI.Sections.AutoDribble:Divider()
        
        uiElements.AutoDribbleEnabled = UI.Sections.AutoDribble:Toggle({ 
            Name = "Enabled", 
            Default = AutoDribbleConfig.Enabled, 
            Callback = function(v) 
                AutoDribbleConfig.Enabled = v
                if v then 
                    AutoDribble.Start() 
                else 
                    AutoDribble.Stop() 
                end
                UpdateDebugVisibility()
            end
        }, "AutoDribbleEnabled")
        
        UI.Sections.AutoDribble:Divider()
        
        uiElements.AutoDribbleMaxDistance = UI.Sections.AutoDribble:Slider({
            Name = "Max Dribble Distance",
            Minimum = 10,
            Maximum = 50,
            Default = AutoDribbleConfig.MaxDribbleDistance,
            Precision = 1,
            Callback = function(v) AutoDribbleConfig.MaxDribbleDistance = v end
        }, "AutoDribbleMaxDistance")
        
        uiElements.AutoDribbleActivationDistance = UI.Sections.AutoDribble:Slider({
            Name = "Activation Distance",
            Minimum = 5,
            Maximum = 30,
            Default = AutoDribbleConfig.DribbleActivationDistance,
            Precision = 1,
            Callback = function(v) AutoDribbleConfig.DribbleActivationDistance = v end
        }, "AutoDribbleActivationDistance")
        
        uiElements.AutoDribbleDribbleReactionTime = UI.Sections.AutoDribble:Slider({
            Name = "Reaction Time",
            Minimum = 0.01,
            Maximum = 0.2,
            Default = AutoDribbleConfig.DribbleReactionTime,
            Precision = 3,
            Callback = function(v) AutoDribbleConfig.DribbleReactionTime = v end
        }, "AutoDribbleDribbleReactionTime")
        
        uiElements.AutoDribbleMinAngleForDribble = UI.Sections.AutoDribble:Slider({
            Name = "Min Attack Angle",
            Minimum = 0,
            Maximum = 90,
            Default = AutoDribbleConfig.MinAngleForDribble,
            Precision = 0,
            Callback = function(v) AutoDribbleConfig.MinAngleForDribble = v end
        }, "AutoDribbleMinAngleForDribble")
        
        UI.Sections.AutoDribble:Divider()
        
        uiElements.AutoDribbleUseServerPosition = UI.Sections.AutoDribble:Toggle({
            Name = "Use Server Position",
            Default = AutoDribbleConfig.UseServerPosition,
            Callback = function(v) AutoDribbleConfig.UseServerPosition = v end
        }, "AutoDribbleUseServerPosition")
        
        uiElements.AutoDribblePredictiveDribble = UI.Sections.AutoDribble:Toggle({
            Name = "Predictive Dribble",
            Default = AutoDribbleConfig.PredictiveDribble,
            Callback = function(v) AutoDribbleConfig.PredictiveDribble = v end
        }, "AutoDribblePredictiveDribble")
        
        uiElements.AutoDribbleSmartAngleCheck = UI.Sections.AutoDribble:Toggle({
            Name = "Smart Angle Check",
            Default = AutoDribbleConfig.SmartAngleCheck,
            Callback = function(v) AutoDribbleConfig.SmartAngleCheck = v end
        }, "AutoDribbleSmartAngleCheck")
        
        UI.Sections.AutoDribble:Divider()
        UI.Sections.AutoDribble:Paragraph({
            Header = "Information",
            Body = "AutoDribble: Automatically use dribble when enemy is tackling\nSmart Angle Check: Only dribble when enemy is attacking head-on\nPredictive Dribble: Predict enemy movement for better timing"
        })
    end
    
    -- Секция Debug
    if UI.Sections.Debug then
        UI.Sections.Debug:Header({ Name = "Debug" })
        UI.Sections.Debug:SubLabel({Text = '* Only for AutoDribble/AutoTackle'})
        UI.Sections.Debug:Divider()
        
        uiElements.DebugEnabled = UI.Sections.Debug:Toggle({
            Name = "Debug Text Enabled",
            Default = DebugConfig.Enabled,
            Callback = function(v)
                DebugConfig.Enabled = v
                UpdateDebugVisibility()
            end
        }, "DebugEnabled")
    end
end

-- === СИНХРОНИЗАЦИЯ КОНФИГА (как в примере) ===
local function SynchronizeConfigValues()
    if not uiElements then return end
    
    -- Синхронизируем AutoTackle слайдеры
    if uiElements.AutoTackleMaxDistance and uiElements.AutoTackleMaxDistance.GetValue then
        AutoTackleConfig.MaxDistance = uiElements.AutoTackleMaxDistance:GetValue()
    end
    
    if uiElements.AutoTackleTackleDistance and uiElements.AutoTackleTackleDistance.GetValue then
        AutoTackleConfig.TackleDistance = uiElements.AutoTackleTackleDistance:GetValue()
    end
    
    if uiElements.AutoTackleTackleSpeed and uiElements.AutoTackleTackleSpeed.GetValue then
        AutoTackleConfig.TackleSpeed = uiElements.AutoTackleTackleSpeed:GetValue()
    end
    
    if uiElements.AutoTackleTackleLeadTime and uiElements.AutoTackleTackleLeadTime.GetValue then
        AutoTackleConfig.TackleLeadTime = uiElements.AutoTackleTackleLeadTime:GetValue()
    end
    
    -- Синхронизируем AutoDribble слайдеры
    if uiElements.AutoDribbleMaxDistance and uiElements.AutoDribbleMaxDistance.GetValue then
        AutoDribbleConfig.MaxDribbleDistance = uiElements.AutoDribbleMaxDistance:GetValue()
    end
    
    if uiElements.AutoDribbleActivationDistance and uiElements.AutoDribbleActivationDistance.GetValue then
        AutoDribbleConfig.DribbleActivationDistance = uiElements.AutoDribbleActivationDistance:GetValue()
    end
    
    if uiElements.AutoDribbleDribbleReactionTime and uiElements.AutoDribbleDribbleReactionTime.GetValue then
        AutoDribbleConfig.DribbleReactionTime = uiElements.AutoDribbleDribbleReactionTime:GetValue()
    end
    
    if uiElements.AutoDribbleMinAngleForDribble and uiElements.AutoDribbleMinAngleForDribble.GetValue then
        AutoDribbleConfig.MinAngleForDribble = uiElements.AutoDribbleMinAngleForDribble:GetValue()
    end
end

-- === МОДУЛЬ ===
local AutoDribbleTackleModule = {}
function AutoDribbleTackleModule.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer
    
    SetupUI(UI)
    
    -- Запускаем синхронизацию конфига каждую секунду
    local synchronizationTimer = 0
    RunService.Heartbeat:Connect(function(deltaTime)
        synchronizationTimer = synchronizationTimer + deltaTime
        
        if synchronizationTimer >= 1.0 then
            synchronizationTimer = 0
            SynchronizeConfigValues()
        end
    end)
    
    -- Первоначальная синхронизация
    task.spawn(function()
        task.wait(0.5)
        SynchronizeConfigValues()
    end)
    
    LocalPlayerObj.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
        
        -- Сбрасываем состояния
        DribbleStates = {}
        TackleStates = {}
        PrecomputedPlayers = {}
        DribbleCooldownList = {}
        EagleEyeTimers = {}
        AutoTackleStatus.TargetHistory = {}
        AutoTackleStatus.PredictionCache = {}
        CurrentTargetOwner = nil
        
        -- Перезапускаем модули если они были включены
        if AutoTackleConfig.Enabled then
            if not AutoTackleStatus.Running then
                AutoTackle.Start()
            end
        end
        
        if AutoDribbleConfig.Enabled then
            if not AutoDribbleStatus.Running then
                AutoDribble.Start()
            end
        end
    end)
end

function AutoDribbleTackleModule:Destroy()
    AutoTackle.Stop()
    AutoDribble.Stop()
end

return AutoDribbleTackleModule
