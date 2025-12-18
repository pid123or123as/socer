-- [v2.3] AUTO DRIBBLE + AUTO TACKLE + FULL GUI + UI INTEGRATION (С MANUAL BUTTON ИСПРАВЛЕННАЯ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

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

-- === CONFIG ===
local AutoTackleConfig = {
    Enabled = false,
    Mode = "OnlyDribble", -- "OnlyDribble", "EagleEye", "ManualTackle"
    MaxDistance = 20,
    TackleDistance = 0,
    OptimalDistanceMin = 3,
    OptimalDistanceMax = 15,
    TackleSpeed = 47,
    PredictionTime = 0.8,
    OnlyPlayer = true,
    RotationMethod = "Snap",
    RotationType = "CFrame",
    MaxAngle = 360,
    DribbleDelayTime = 0.3,
    EagleEyeMinDelay = 0.1,
    EagleEyeMaxDelay = 0.6,
    ManualTackleEnabled = true,
    ManualTackleKeybind = Enum.KeyCode.Q,
    ManualTackleCooldown = 0.5,
    ManualButton = false,
    ButtonScale = 1.0
}

local AutoDribbleConfig = {
    Enabled = false,
    MaxDribbleDistance = 30,
    DribbleActivationDistance = 16,
    MaxAngle = 360,
    PredictionTime = 0.098,
    MaxPredictionAngle = 38,
    TacklePredictionTime = 0.3,
    TackleAngleThreshold = 0.7
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
    RenderConnection = nil,
    InputConnection = nil,
    DebugConnection = nil,
    ButtonGui = nil,
    TouchStartTime = 0,
    Dragging = false,
    DragStart = Vector2.new(0, 0),
    StartPos = UDim2.new(0, 0, 0, 0)
}
local AutoDribbleStatus = {
    Running = false,
    Connection = nil,
    DebugConnection = nil
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
        TargetRingLines = {},
        TargetRings = {},
        
        -- Раздельные контейнеры для отключения
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
        Gui.ModeLabel, Gui.ManualTackleLabel
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
    Gui.ManualTackleLabel.Position = Vector2.new(centerX, offsetTackleY)
    
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
    
    -- Обновляем видимость меток AutoTackle
    local tackleVisible = DebugConfig.Enabled and AutoTackleConfig.Enabled
    for _, label in ipairs(Gui.TackleDebugLabels) do
        label.Visible = tackleVisible
    end
    
    -- Обновляем видимость меток AutoDribble
    local dribbleVisible = DebugConfig.Enabled and AutoDribbleConfig.Enabled
    for _, label in ipairs(Gui.DribbleDebugLabels) do
        label.Visible = dribbleVisible
    end
    
    -- Обновляем кольца цели
    if not AutoTackleConfig.Enabled then
        for _, line in ipairs(Gui.TargetRingLines) do
            line.Visible = false
        end
    end
    
    -- Обновляем видимость кнопки ManualTackle
    if AutoTackleStatus.ButtonGui and AutoTackleStatus.ButtonGui:FindFirstChild("ManualTackleButton") then
        AutoTackleStatus.ButtonGui.ManualTackleButton.Visible = AutoTackleConfig.ManualButton and AutoTackleConfig.Enabled
    end
end

local function CleanupDebugText()
    if not Gui then return end
    
    -- Очищаем текст меток AutoTackle при выключении
    if not AutoTackleConfig.Enabled then
        Gui.TackleWaitLabel.Text = "Wait: 0.00"
        Gui.TackleTargetLabel.Text = "Target: None"
        Gui.TackleDribblingLabel.Text = "isDribbling: false"
        Gui.TackleTacklingLabel.Text = "isTackling: false"
        Gui.EagleEyeLabel.Text = "EagleEye: Idle"
        Gui.ManualTackleLabel.Text = "ManualTackle: Ready [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
        Gui.ModeLabel.Text = "Mode: " .. AutoTackleConfig.Mode
    end
    
    -- Очищаем текст меток AutoDribble при выключении
    if not AutoDribbleConfig.Enabled then
        Gui.DribbleStatusLabel.Text = "Dribble: Ready"
        Gui.DribbleTargetLabel.Text = "Targets: 0"
        Gui.DribbleTacklingLabel.Text = "Nearest: None"
        Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
    end
end

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function CheckIfTypingInChat()
    local success, result = pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        local chatGui = playerGui:FindFirstChild("Chat")
        
        if chatGui then
            local chatBar = chatGui:FindFirstChild("Frame") and chatGui.Frame:FindFirstChild("ChatBar")
            if chatBar then
                local container = chatBar:FindFirstChild("Container")
                if container then
                    local frame = container:FindFirstChild("Frame")
                    if frame then
                        local textBox = frame:FindFirstChild("TextBox")
                        if textBox then
                            return textBox:IsFocused()
                        end
                    end
                end
            end
        end
        
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

local function CreateTargetRing()
    local ring = {}
    for i = 1, 24 do
        local line = Drawing.new("Line")
        line.Thickness = 3
        line.Color = Color3.fromRGB(255, 0, 0)
        line.Visible = false
        table.insert(ring, line)
    end
    return ring
end

local function UpdateTargetRing(ball, distance)
    for _, line in ipairs(Gui.TargetRingLines) do line.Visible = false end
    if not ball or not ball.Parent then return end
    if not AutoTackleConfig.Enabled then return end
    
    local center = ball.Position - Vector3.new(0, 0.5, 0)
    local radius = 2
    local segments = #Gui.TargetRingLines
    local points = {}
    for i = 1, segments do
        local angle = (i - 1) * 2 * math.pi / segments
        local point = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        table.insert(points, point)
    end
    for i, line in ipairs(Gui.TargetRingLines) do
        local startPoint = points[i]
        local endPoint = points[i % segments + 1]
        local startScreen, startOnScreen = Camera:WorldToViewportPoint(startPoint)
        local endScreen, endOnScreen = Camera:WorldToViewportPoint(endPoint)
        if startOnScreen and endOnScreen and startScreen.Z > 0.1 and endScreen.Z > 0.1 then
            line.From = Vector2.new(startScreen.X, startScreen.Y)
            line.To = Vector2.new(endScreen.X, endScreen.Y)
            if distance <= AutoTackleConfig.TackleDistance then
                line.Color = Color3.fromRGB(0, 255, 0)
            elseif distance <= AutoTackleConfig.OptimalDistanceMax then
                line.Color = Color3.fromRGB(255, 165, 0)
            else
                line.Color = Color3.fromRGB(255, 0, 0)
            end
            line.Visible = true
        end
    end
end

local function UpdateTargetRings()
    for player, ring in pairs(Gui.TargetRings) do
        for _, line in ipairs(ring) do line.Visible = false end
    end
    
    if not AutoDribbleConfig.Enabled then return end
    
    for player, data in pairs(PrecomputedPlayers) do
        if not data.IsValid or not TackleStates[player].IsTackling then continue end
        local targetRoot = data.RootPart
        if not targetRoot then continue end
        local center = targetRoot.Position - Vector3.new(0, 0.5, 0)
        local radius = 2
        local segments = 24
        local points = {}
        for i = 1, segments do
            local angle = (i - 1) * 2 * math.pi / segments
            local point = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            table.insert(points, point)
        end
        local ring = Gui.TargetRings[player]
        for i, line in ipairs(ring) do
            local startPoint = points[i]
            local endPoint = points[i % segments + 1]
            local startScreen, startOnScreen = Camera:WorldToViewportPoint(startPoint)
            local endScreen, endOnScreen = Camera:WorldToViewportPoint(endPoint)
            if startOnScreen and endOnScreen and startScreen.Z > 0.1 and endScreen.Z > 0.1 then
                line.From = Vector2.new(startScreen.X, startScreen.Y)
                line.To = Vector2.new(endScreen.X, endScreen.Y)
                if data.Distance <= AutoDribbleConfig.DribbleActivationDistance then
                    line.Color = Color3.fromRGB(0, 255, 0)
                elseif data.Distance <= AutoDribbleConfig.MaxDribbleDistance then
                    line.Color = Color3.fromRGB(255, 165, 0)
                else
                    line.Color = Color3.fromRGB(255, 0, 0)
                end
                line.Visible = true
            end
        end
    end
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

local function IsPowerShooting(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local bools = targetPlayer.Character:FindFirstChild("Bools")
    if bools and bools:FindFirstChild("PowerShooting") then
        return bools.PowerShooting.Value
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
        PowerShootingPlayers[player] = IsPowerShooting(player)
        
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

        if not Gui.TargetRings[player] then Gui.TargetRings[player] = CreateTargetRing() end

        local predictedPos = targetRoot.Position + targetRoot.AssemblyLinearVelocity * AutoDribbleConfig.PredictionTime

        PrecomputedPlayers[player] = {
            Distance = distance,
            PredictedPos = predictedPos,
            IsValid = true,
            IsTackling = TackleStates[player].IsTackling,
            RootPart = targetRoot
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

local function PredictBallPosition(ball)
    if not ball or not ball.Parent then return nil end
    return ball.Position + ball.AssemblyLinearVelocity * AutoTackleConfig.PredictionTime
end

local function RotateToTarget(targetPos)
    if AutoTackleConfig.RotationType == "CFrame" then
        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, targetPos)
    end
end

local function PerformTackle(ball, owner)
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.TackleDebounce.Value or bools.Tackled.Value or Character:FindFirstChild("Bools") and Character.Bools.Debounce.Value then return end
    if AutoTackleConfig.RotationMethod == "Snap" and ball then
        local predictedPos = PredictBallPosition(ball) or ball.Position
        RotateToTarget(predictedPos)
    end
    pcall(function() ActionRemote:FireServer("TackIe") end)
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Parent = HumanoidRootPart
    bodyVelocity.Velocity = HumanoidRootPart.CFrame.LookVector * AutoTackleConfig.TackleSpeed
    bodyVelocity.MaxForce = Vector3.new(50000000, 0, 50000000)
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Parent = HumanoidRootPart
    bodyGyro.Name = "TackleGyro"
    bodyGyro.P = 950000
    bodyGyro.MaxTorque = Vector3.new(0, 100000, 0)
    bodyGyro.CFrame = HumanoidRootPart.CFrame
    Debris:AddItem(bodyVelocity, 0.65)
    Debris:AddItem(bodyGyro, 0.65)
    if owner and ball:FindFirstChild("playerWeld") then
        local distance = (HumanoidRootPart.Position - ball.Position).Magnitude
        pcall(function() SoftDisPlayerRemote:FireServer(owner, distance, false, ball.Size) end)
    end
end

local function PerformDribble()
    local bools = Workspace:FindFirstChild(LocalPlayer.Name) and Workspace[LocalPlayer.Name]:FindFirstChild("Bools")
    if not bools or bools.dribbleDebounce.Value then return end
    pcall(function() ActionRemote:FireServer("Deke") end)
    if Gui and AutoDribbleConfig.Enabled then
        Gui.DribbleStatusLabel.Text = "Dribble: Cooldown"
        Gui.DribbleStatusLabel.Color = Color3.fromRGB(255, 0, 0)
        Gui.AutoDribbleLabel.Text = "AutoDribble: DEKE (Slide Tackle!)"
    end
end

-- Функция ManualTackleAction должна быть объявлена ДО SetupManualTackleButton
local function ManualTackleAction()
    local currentTime = tick()
    if currentTime - LastManualTackleTime < AutoTackleConfig.ManualTackleCooldown then 
        return false 
    end
    
    local canTackle, ball, distance, owner
    
    if AutoTackleConfig.Mode == "ManualTackle" then
        canTackle, ball, distance, owner = CanTackle()
    else
        if CurrentTargetOwner and CurrentTargetOwner.Parent then
            local canTackleTemp, ballTemp, distanceTemp, _ = CanTackle()
            if canTackleTemp and ballTemp and ballTemp.creator and ballTemp.creator.Value == CurrentTargetOwner then
                canTackle = canTackleTemp
                ball = ballTemp
                distance = distanceTemp
                owner = CurrentTargetOwner
            else
                canTackle, ball, distance, owner = CanTackle()
            end
        else
            canTackle, ball, distance, owner = CanTackle()
        end
    end
    
    if canTackle then
        LastManualTackleTime = currentTime
        PerformTackle(ball, owner)
        if Gui and AutoTackleConfig.Enabled then
            Gui.ManualTackleLabel.Text = "ManualTackle: EXECUTED! [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
            Gui.ManualTackleLabel.Color = Color3.fromRGB(0, 255, 0)
        end
        
        task.delay(0.3, function()
            if Gui and AutoTackleConfig.Enabled then
                Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 255, 255)
            end
        end)
        return true
    else
        if Gui and AutoTackleConfig.Enabled then
            Gui.ManualTackleLabel.Text = "ManualTackle: FAILED [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
            Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 0, 0)
        end
        
        task.delay(0.3, function()
            if Gui and AutoTackleConfig.Enabled then
                Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 255, 255)
            end
        end)
        return false
    end
end

-- === MANUAL TACKLE BUTTON ===
local function SetupManualTackleButton()
    if AutoTackleStatus.ButtonGui then 
        AutoTackleStatus.ButtonGui:Destroy() 
        AutoTackleStatus.ButtonGui = nil 
    end
    
    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "ManualTackleButtonGui"
    buttonGui.ResetOnSpawn = false
    buttonGui.IgnoreGuiInset = false
    buttonGui.Parent = game:GetService("CoreGui")
    
    local size = 50 * AutoTackleConfig.ButtonScale
    local screenSize = Camera.ViewportSize
    local initialX = screenSize.X / 2 - size / 2
    local initialY = screenSize.Y * 0.7
    
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ManualTackleButton"
    buttonFrame.Size = UDim2.new(0, size, 0, size)
    buttonFrame.Position = UDim2.new(0, initialX, 0, initialY)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Visible = AutoTackleConfig.ManualButton and AutoTackleConfig.Enabled
    buttonFrame.Parent = buttonGui
    
    Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)
    
    local buttonIcon = Instance.new("ImageLabel")
    buttonIcon.Size = UDim2.new(0, size*0.6, 0, size*0.6)
    buttonIcon.Position = UDim2.new(0.5, -size*0.3, 0.5, -size*0.3)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Image = "rbxassetid://73279554401260"
    buttonIcon.Parent = buttonFrame
    
    -- Логика перетаскивания
    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            AutoTackleStatus.TouchStartTime = tick()
            local mousePos = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
            AutoTackleStatus.Dragging = true
            AutoTackleStatus.DragStart = mousePos
            AutoTackleStatus.StartPos = buttonFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and AutoTackleStatus.Dragging then
            local mousePos = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
            local delta = mousePos - AutoTackleStatus.DragStart
            buttonFrame.Position = UDim2.new(AutoTackleStatus.StartPos.X.Scale, AutoTackleStatus.StartPos.X.Offset + delta.X, AutoTackleStatus.StartPos.Y.Scale, AutoTackleStatus.StartPos.Y.Offset + delta.Y)
        end
    end)
    
    buttonFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            AutoTackleStatus.Dragging = false
            
            if AutoTackleStatus.TouchStartTime > 0 and tick() - AutoTackleStatus.TouchStartTime < 0.2 then
                ManualTackleAction()
            end
            
            AutoTackleStatus.TouchStartTime = 0
        end
    end)
    
    AutoTackleStatus.ButtonGui = buttonGui
end

local function ToggleManualTackleButton(value)
    AutoTackleConfig.ManualButton = value
    
    if value then
        SetupManualTackleButton()
    else
        if AutoTackleStatus.ButtonGui then 
            AutoTackleStatus.ButtonGui:Destroy() 
            AutoTackleStatus.ButtonGui = nil 
        end
    end
    UpdateDebugVisibility()
end

local function SetTackleButtonScale(value)
    AutoTackleConfig.ButtonScale = value
    if AutoTackleConfig.ManualButton then 
        SetupManualTackleButton() 
    end
end

local function ProcessEagleEyeMode(owner, ball)
    if not owner then return false, 0, "NoTarget" end
    
    local state = DribbleStates[owner] or {
        IsDribbling = false,
        LastDribbleEnd = 0,
        HasUsedDribble = false,
        IsProcessingDelay = false
    }
    
    local currentTime = tick()
    local isDribbling = state.IsDribbling
    local inCooldownList = DribbleCooldownList[owner] ~= nil
    local isPowerShooting = PowerShootingPlayers[owner] or false
    local timeSinceEnd = currentTime - state.LastDribbleEnd
    
    if isPowerShooting then
        return true, 0, "PowerShooting"
    end
    
    if inCooldownList then
        return true, 0, "InCooldownList"
    end
    
    if isDribbling or state.IsProcessingDelay then
        if state.IsProcessingDelay then
            if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                if not EagleEyeTimers[owner] then
                    EagleEyeTimers[owner] = {
                        startTime = currentTime,
                        waitTime = AutoTackleConfig.EagleEyeMinDelay + 
                                   math.random() * (AutoTackleConfig.EagleEyeMaxDelay - AutoTackleConfig.EagleEyeMinDelay)
                    }
                end
                
                local timer = EagleEyeTimers[owner]
                local eagleElapsed = currentTime - timer.startTime
                
                if eagleElapsed >= timer.waitTime then
                    return true, 0, "EagleEyeReady"
                else
                    return false, timer.waitTime - eagleElapsed, "EagleEyeWaiting"
                end
            else
                return false, AutoTackleConfig.DribbleDelayTime - timeSinceEnd, "WaitingDribbleDelay"
            end
        else
            return false, 999, "StillDribbling"
        end
    end
    
    if not EagleEyeTimers[owner] then
        EagleEyeTimers[owner] = {
            startTime = currentTime,
            waitTime = AutoTackleConfig.EagleEyeMinDelay + 
                       math.random() * (AutoTackleConfig.EagleEyeMaxDelay - AutoTackleConfig.EagleEyeMinDelay)
        }
    end
    
    local timer = EagleEyeTimers[owner]
    local eagleElapsed = currentTime - timer.startTime
    
    if eagleElapsed >= timer.waitTime then
        return true, 0, "EagleEyeReady"
    else
        return false, timer.waitTime - eagleElapsed, "EagleEyeWaiting"
    end
end

local function ProcessOnlyDribbleMode(owner, ball)
    if not owner then return false, 0, "NoTarget" end
    
    local state = DribbleStates[owner] or {
        IsDribbling = false,
        LastDribbleEnd = 0,
        HasUsedDribble = false,
        IsProcessingDelay = false
    }
    
    local currentTime = tick()
    local isDribbling = state.IsDribbling
    local inCooldownList = DribbleCooldownList[owner] ~= nil
    local isPowerShooting = PowerShootingPlayers[owner] or false
    local timeSinceEnd = currentTime - state.LastDribbleEnd
    
    if isPowerShooting then
        return true, 0, "PowerShooting"
    end
    
    if inCooldownList then
        return true, 0, "InCooldownList"
    end
    
    if isDribbling or state.IsProcessingDelay then
        if state.IsProcessingDelay then
            if timeSinceEnd >= AutoTackleConfig.DribbleDelayTime then
                return true, 0, "DribbleDelayEnded"
            else
                return false, AutoTackleConfig.DribbleDelayTime - timeSinceEnd, "WaitingDribbleDelay"
            end
        else
            return false, 999, "StillDribbling"
        end
    end
    
    return false, 0, "NotApplicable"
end

local function ProcessManualTackleMode(owner, ball)
    if not owner then return false, 0, "Press " .. tostring(AutoTackleConfig.ManualTackleKeybind) .. " to tackle" end
    
    local canTackle, _, distance, _ = CanTackle()
    
    if canTackle then
        if Gui and AutoTackleConfig.Enabled then
            Gui.ManualTackleLabel.Text = "ManualTackle: READY [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
            Gui.ManualTackleLabel.Color = Color3.fromRGB(0, 255, 0)
        end
        return false, 0, "Ready - Press " .. tostring(AutoTackleConfig.ManualTackleKeybind)
    else
        if Gui and AutoTackleConfig.Enabled then
            Gui.ManualTackleLabel.Text = "ManualTackle: NOT READY [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
            Gui.ManualTackleLabel.Color = Color3.fromRGB(255, 0, 0)
        end
        return false, 0, "Cannot tackle now"
    end
end

local function ProcessTackle(ball, owner)
    if not owner or not owner.Character or not ball then
        if Gui and AutoTackleConfig.Enabled then
            Gui.TackleTargetLabel.Text = "Target: None"
            Gui.TackleDribblingLabel.Text = "isDribbling: false"
            Gui.TackleTacklingLabel.Text = "isTackling: false"
            Gui.TackleWaitLabel.Text = "Wait: 0.00"
            Gui.ManualTackleLabel.Text = "ManualTackle: NO TARGET [" .. tostring(AutoTackleConfig.ManualTackleKeybind) .. "]"
        end
        UpdateTargetRing(nil, math.huge)
        CurrentTargetOwner = nil
        return false
    end

    local targetRoot = owner.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end

    local predictedPos = PredictBallPosition(ball) or ball.Position
    local distance = (HumanoidRootPart.Position - predictedPos).Magnitude

    if AutoTackleConfig.RotationMethod == "Always" and distance <= AutoTackleConfig.MaxDistance then
        RotateToTarget(predictedPos)
    end

    local state = DribbleStates[owner] or {
        IsDribbling = false,
        LastDribbleEnd = 0,
        HasUsedDribble = false,
        IsProcessingDelay = false
    }
    
    local isDribbling = state.IsDribbling
    local isTacklingNow = IsSpecificTackle(owner)

    if Gui and AutoTackleConfig.Enabled then
        Gui.TackleTargetLabel.Text = "Target: " .. owner.Name
        Gui.TackleDribblingLabel.Text = "isDribbling: " .. tostring(isDribbling)
        Gui.TackleTacklingLabel.Text = "isTackling: " .. tostring(isTacklingNow)
    end

    local shouldTackle = false
    local waitTime = 0
    local reason = ""
    
    CurrentTargetOwner = owner
    
    if AutoTackleConfig.Mode == "EagleEye" then
        shouldTackle, waitTime, reason = ProcessEagleEyeMode(owner, ball)
    elseif AutoTackleConfig.Mode == "OnlyDribble" then
        shouldTackle, waitTime, reason = ProcessOnlyDribbleMode(owner, ball)
    elseif AutoTackleConfig.Mode == "ManualTackle" then
        shouldTackle, waitTime, reason = ProcessManualTackleMode(owner, ball)
    end
    
    if waitTime > 0 and waitTime < 999 then
        if Gui and AutoTackleConfig.Enabled then
            Gui.TackleWaitLabel.Text = string.format("Wait: %.2f", waitTime)
            Gui.EagleEyeLabel.Text = "Status: " .. reason
        end
    else
        if Gui and AutoTackleConfig.Enabled then
            Gui.TackleWaitLabel.Text = "Wait: 0.00"
            Gui.EagleEyeLabel.Text = "Status: " .. reason
        end
    end
    
    UpdateTargetRing(ball, distance)
    
    if shouldTackle and AutoTackleConfig.Mode ~= "ManualTackle" then
        local canTackle, _, _, _ = CanTackle()
        if canTackle then
            PerformTackle(ball, owner)
            EagleEyeTimers[owner] = nil
            return true
        end
    end
    
    return false
end

-- === ФУНКЦИИ ДЛЯ ПЕРЕМЕЩЕНИЯ DEBUG ТЕКСТА ===
local function SetupDebugMovement()
    if not DebugConfig.MoveEnabled or not Gui then return end
    
    local isDragging = false
    local dragStart = Vector2.new(0, 0)
    local startPositions = {}
    
    -- Сохраняем начальные позиции всех меток
    for _, label in ipairs(Gui.TackleDebugLabels) do
        startPositions[label] = label.Position
    end
    for _, label in ipairs(Gui.DribbleDebugLabels) do
        startPositions[label] = label.Position
    end
    
    local function updateAllPositions(delta)
        for label, startPos in pairs(startPositions) do
            if label.Visible then
                label.Position = startPos + delta
            end
        end
    end
    
    -- Обработчик для ПК
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not DebugConfig.MoveEnabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = UserInputService:GetMouseLocation()
            
            -- Проверяем, кликнули ли по любой видимой метке
            for label, startPos in pairs(startPositions) do
                if label.Visible then
                    local pos = label.Position
                    local textBounds = Vector2.new(label.TextBounds.X, label.TextBounds.Y)
                    local rect = {
                        x1 = pos.X - textBounds.X/2,
                        y1 = pos.Y - textBounds.Y/2,
                        x2 = pos.X + textBounds.X/2,
                        y2 = pos.Y + textBounds.Y/2
                    }
                    
                    if mousePos.X >= rect.x1 and mousePos.X <= rect.x2 and
                       mousePos.Y >= rect.y1 and mousePos.Y <= rect.y2 then
                        isDragging = true
                        dragStart = mousePos
                        break
                    end
                end
            end
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not DebugConfig.MoveEnabled then return end
        if not isDragging then return end
        
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = UserInputService:GetMouseLocation()
            local delta = mousePos - dragStart
            updateAllPositions(delta)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not DebugConfig.MoveEnabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if isDragging then
                local mousePos = UserInputService:GetMouseLocation()
                local delta = mousePos - dragStart
                
                -- Обновляем стартовые позиции
                for label, startPos in pairs(startPositions) do
                    startPositions[label] = startPos + delta
                end
                
                DebugConfig.Position = DebugConfig.Position + Vector2.new(delta.X / Camera.ViewportSize.X, delta.Y / Camera.ViewportSize.Y)
            end
            isDragging = false
        end
    end)
    
    -- Обработчик для тач-устройств
    UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
        if gameProcessed then return end
        if not DebugConfig.MoveEnabled then return end
        
        local touchPos = touch.Position
        
        for label, startPos in pairs(startPositions) do
            if label.Visible then
                local pos = label.Position
                local textBounds = Vector2.new(label.TextBounds.X, label.TextBounds.Y)
                local rect = {
                    x1 = pos.X - textBounds.X/2,
                    y1 = pos.Y - textBounds.Y/2,
                    x2 = pos.X + textBounds.X/2,
                    y2 = pos.Y + textBounds.Y/2
                }
                
                if touchPos.X >= rect.x1 and touchPos.X <= rect.x2 and
                   touchPos.Y >= rect.y1 and touchPos.Y <= rect.y2 then
                    isDragging = true
                    dragStart = touchPos
                    break
                end
            end
        end
    end)
    
    UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
        if gameProcessed then return end
        if not DebugConfig.MoveEnabled then return end
        if not isDragging then return end
        
        local touchPos = touch.Position
        local delta = touchPos - dragStart
        updateAllPositions(delta)
    end)
    
    UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
        if gameProcessed then return end
        if not DebugConfig.MoveEnabled then return end
        
        if isDragging then
            local touchPos = touch.Position
            local delta = touchPos - dragStart
            
            for label, startPos in pairs(startPositions) do
                startPositions[label] = startPos + delta
            end
            
            DebugConfig.Position = DebugConfig.Position + Vector2.new(delta.X / Camera.ViewportSize.X, delta.Y / Camera.ViewportSize.Y)
        end
        isDragging = false
    end)
end

-- === AUTO TACKLE MODULE ===
local AutoTackle = {}
AutoTackle.Start = function()
    if AutoTackleStatus.Running then return end
    AutoTackleStatus.Running = true
    
    if not Gui then SetupGUI() end
    
    -- Heartbeat для обновления состояний
    AutoTackleStatus.HeartbeatConnection = RunService.Heartbeat:Connect(function()
        pcall(UpdateDribbleStates)
        pcall(PrecomputePlayers)
        pcall(UpdateTargetRings)
        IsTypingInChat = CheckIfTypingInChat()
    end)
    
    -- Heartbeat для логики такла
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
                UpdateTargetRing(nil, math.huge)
                CurrentTargetOwner = nil
                return
            end
            
            if distance <= AutoTackleConfig.TackleDistance then
                PerformTackle(ball, owner)
            else
                ProcessTackle(ball, owner)
            end
        end)
    end)
    
    -- Обработчик ручного такла по клавише
    AutoTackleStatus.InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not AutoTackleConfig.Enabled then return end
        if not AutoTackleConfig.ManualTackleEnabled then return end
        
        if IsTypingInChat then return end
        
        if input.KeyCode == AutoTackleConfig.ManualTackleKeybind then
            ManualTackleAction()
        end
    end)
    
    -- Настройка кнопки Manual Tackle
    if AutoTackleConfig.ManualButton then 
        SetupManualTackleButton() 
    end
    
    -- Настройка перемещения debug текста
    if DebugConfig.MoveEnabled then
        SetupDebugMovement()
    end
    
    UpdateDebugVisibility()
    notify("AutoTackle", "Started", true)
end

AutoTackle.Stop = function()
    if AutoTackleStatus.Connection then AutoTackleStatus.Connection:Disconnect(); AutoTackleStatus.Connection = nil end
    if AutoTackleStatus.HeartbeatConnection then AutoTackleStatus.HeartbeatConnection:Disconnect(); AutoTackleStatus.HeartbeatConnection = nil end
    if AutoTackleStatus.InputConnection then AutoTackleStatus.InputConnection:Disconnect(); AutoTackleStatus.InputConnection = nil end
    if AutoTackleStatus.RenderConnection then AutoTackleStatus.RenderConnection:Disconnect(); AutoTackleStatus.RenderConnection = nil end
    AutoTackleStatus.Running = false
    
    CleanupDebugText()
    UpdateDebugVisibility()
    
    if AutoTackleStatus.ButtonGui then 
        AutoTackleStatus.ButtonGui:Destroy() 
        AutoTackleStatus.ButtonGui = nil 
    end
    
    notify("AutoTackle", "Stopped", true)
end

-- === AUTO DRIBBLE MODULE ===
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
            local specificTarget = nil
            local minDist = math.huge
            local targetCount = 0

            for player, data in pairs(PrecomputedPlayers) do
                if data.IsValid and TackleStates[player].IsTackling then
                    targetCount += 1
                    if data.Distance < minDist then
                        minDist = data.Distance
                        specificTarget = player
                    end
                end
            end

            if Gui then
                Gui.DribbleTargetLabel.Text = "Targets: " .. targetCount
                Gui.DribbleTacklingLabel.Text = specificTarget and string.format("Tackle: %.1f", minDist) or "Tackle: None"
            end

            if HasBall and CanDribbleNow and specificTarget and minDist <= AutoDribbleConfig.DribbleActivationDistance then
                PerformDribble()
            else
                if Gui then
                    Gui.AutoDribbleLabel.Text = "AutoDribble: Idle"
                end
            end
        end)
    end)
    
    UpdateDebugVisibility()
    notify("AutoDribble", "Started", true)
end

AutoDribble.Stop = function()
    if AutoDribbleStatus.Connection then AutoDribbleStatus.Connection:Disconnect(); AutoDribbleStatus.Connection = nil end
    AutoDribbleStatus.Running = false
    
    CleanupDebugText()
    UpdateDebugVisibility()
    notify("AutoDribble", "Stopped", true)
end

-- === UI ===
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
        
        uiElements.AutoTackleOptimalDistanceMin = UI.Sections.AutoTackle:Slider({
            Name = "Optimal Distance Min",
            Minimum = 0,
            Maximum = 30,
            Default = AutoTackleConfig.OptimalDistanceMin,
            Precision = 1,
            Callback = function(v) AutoTackleConfig.OptimalDistanceMin = v end
        }, "AutoTackleOptimalDistanceMin")
        
        uiElements.AutoTackleOptimalDistanceMax = UI.Sections.AutoTackle:Slider({
            Name = "Optimal Distance Max",
            Minimum = 5,
            Maximum = 50,
            Default = AutoTackleConfig.OptimalDistanceMax,
            Precision = 1,
            Callback = function(v) AutoTackleConfig.OptimalDistanceMax = v end
        }, "AutoTackleOptimalDistanceMax")
        
        uiElements.AutoTackleTackleSpeed = UI.Sections.AutoTackle:Slider({
            Name = "Tackle Speed",
            Minimum = 10,
            Maximum = 100,
            Default = AutoTackleConfig.TackleSpeed,
            Precision = 1,
            Callback = function(v) AutoTackleConfig.TackleSpeed = v end
        }, "AutoTackleTackleSpeed")
        
        uiElements.AutoTacklePredictionTime = UI.Sections.AutoTackle:Slider({
            Name = "Prediction Time",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = AutoTackleConfig.PredictionTime,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.PredictionTime = v end
        }, "AutoTacklePredictionTime")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleOnlyPlayer = UI.Sections.AutoTackle:Toggle({
            Name = "Only Player",
            Default = AutoTackleConfig.OnlyPlayer,
            Callback = function(v) AutoTackleConfig.OnlyPlayer = v end
        }, "AutoTackleOnlyPlayer")
        
        uiElements.AutoTackleRotationMethod = UI.Sections.AutoTackle:Dropdown({
            Name = "Rotation Method",
            Default = AutoTackleConfig.RotationMethod,
            Options = {"Snap", "Always", "None"},
            Callback = function(v) AutoTackleConfig.RotationMethod = v end
        }, "AutoTackleRotationMethod")
        
        uiElements.AutoTackleRotationType = UI.Sections.AutoTackle:Dropdown({
            Name = "Rotation Type",
            Default = AutoTackleConfig.RotationType,
            Options = {"CFrame", "BodyGyro"},
            Callback = function(v) AutoTackleConfig.RotationType = v end
        }, "AutoTackleRotationType")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleDribbleDelayTime = UI.Sections.AutoTackle:Slider({
            Name = "Dribble Delay Time",
            Minimum = 0.0,
            Maximum = 2.0,
            Default = AutoTackleConfig.DribbleDelayTime,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.DribbleDelayTime = v end
        }, "AutoTackleDribbleDelayTime")
        
        uiElements.AutoTackleEagleEyeMinDelay = UI.Sections.AutoTackle:Slider({
            Name = "EagleEye Min Delay",
            Minimum = 0.0,
            Maximum = 2.0,
            Default = AutoTackleConfig.EagleEyeMinDelay,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.EagleEyeMinDelay = v end
        }, "AutoTackleEagleEyeMinDelay")
        
        uiElements.AutoTackleEagleEyeMaxDelay = UI.Sections.AutoTackle:Slider({
            Name = "EagleEye Max Delay",
            Minimum = 0.0,
            Maximum = 2.0,
            Default = AutoTackleConfig.EagleEyeMaxDelay,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.EagleEyeMaxDelay = v end
        }, "AutoTackleEagleEyeMaxDelay")
        
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
        
        uiElements.AutoTackleManualTackleCooldown = UI.Sections.AutoTackle:Slider({
            Name = "Manual Tackle Cooldown",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = AutoTackleConfig.ManualTackleCooldown,
            Precision = 2,
            Callback = function(v) AutoTackleConfig.ManualTackleCooldown = v end
        }, "AutoTackleManualTackleCooldown")
        
        UI.Sections.AutoTackle:Divider()
        
        uiElements.AutoTackleManualButton = UI.Sections.AutoTackle:Toggle({
            Name = "Manual Button",
            Default = AutoTackleConfig.ManualButton,
            Callback = ToggleManualTackleButton
        }, "AutoTackleManualButton")
        
        uiElements.AutoTackleButtonScale = UI.Sections.AutoTackle:Slider({
            Name = "Button Scale",
            Minimum = 0.5,
            Maximum = 2.0,
            Default = AutoTackleConfig.ButtonScale,
            Precision = 2,
            Callback = SetTackleButtonScale
        }, "AutoTackleButtonScale")
        
        UI.Sections.AutoTackle:Divider()
        UI.Sections.AutoTackle:Paragraph({
            Header = "Information",
            Body = "OnlyDribble: Tackle when enemy dribble is on cooldown\nEagleEye: Random delay + dribble cooldown tracking\nManualTackle: Only tackle when you press the key\n TackleDistance - the distance at which the tackle is immediately used\nPrediction Time - how long will the trajectory take to predict\nEagleEye Delays - random delay from min to max"
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
        
        uiElements.AutoDribblePredictionTime = UI.Sections.AutoDribble:Slider({
            Name = "Prediction Time",
            Minimum = 0.01,
            Maximum = 0.5,
            Default = AutoDribbleConfig.PredictionTime,
            Precision = 3,
            Callback = function(v) AutoDribbleConfig.PredictionTime = v end
        }, "AutoDribblePredictionTime")
        
        uiElements.AutoDribbleMaxAngle = UI.Sections.AutoDribble:Slider({
            Name = "Max Angle",
            Minimum = 0,
            Maximum = 360,
            Default = AutoDribbleConfig.MaxAngle,
            Precision = 0,
            Callback = function(v) AutoDribbleConfig.MaxAngle = v end
        }, "AutoDribbleMaxAngle")
        
        uiElements.AutoDribbleMaxPredictionAngle = UI.Sections.AutoDribble:Slider({
            Name = "Max Prediction Angle",
            Minimum = 0,
            Maximum = 360,
            Default = AutoDribbleConfig.MaxPredictionAngle,
            Precision = 0,
            Callback = function(v) AutoDribbleConfig.MaxPredictionAngle = v end
        }, "AutoDribbleMaxPredictionAngle")
        
        uiElements.AutoDribbleTacklePredictionTime = UI.Sections.AutoDribble:Slider({
            Name = "Tackle Prediction Time",
            Minimum = 0.01,
            Maximum = 1.0,
            Default = AutoDribbleConfig.TacklePredictionTime,
            Precision = 2,
            Callback = function(v) AutoDribbleConfig.TacklePredictionTime = v end
        }, "AutoDribbleTacklePredictionTime")
        
        uiElements.AutoDribbleTackleAngleThreshold = UI.Sections.AutoDribble:Slider({
            Name = "Tackle Angle Threshold",
            Minimum = 0.1,
            Maximum = 1.0,
            Default = AutoDribbleConfig.TackleAngleThreshold,
            Precision = 2,
            Callback = function(v) AutoDribbleConfig.TackleAngleThreshold = v end
        }, "AutoDribbleTackleAngleThreshold")
        
        UI.Sections.AutoDribble:Divider()
        UI.Sections.AutoDribble:Paragraph({
            Header = "Information",
            Body = "AutoDribble: Automatically use dribble when enemy is using tackle"
        })
    end
    
    -- Секция Debug
    if UI.Sections.Debug then
        wait(1)
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
        
        uiElements.DebugMoveEnabled = UI.Sections.Debug:Toggle({
            Name = "Move Debug Text",
            Default = DebugConfig.MoveEnabled,
            Callback = function(v)
                DebugConfig.MoveEnabled = v
                if v then
                    SetupDebugMovement()
                end
            end
        }, "DebugMoveEnabled")
    end
    
    -- Секция синхронизации
    local syncSection = UI.Tabs.Config:Section({ Name = "AutoDribble & AutoTackle Sync", Side = "Right" })
    syncSection:Header({ Name = "AutoDribble/AutoTackle" })
    syncSection:Button({ Name = "Sync Config", Callback = function()
        AutoTackleConfig.Enabled = uiElements.AutoTackleEnabled:GetState()
        AutoTackleConfig.MaxDistance = uiElements.AutoTackleMaxDistance:GetValue()
        AutoTackleConfig.TackleDistance = uiElements.AutoTackleTackleDistance:GetValue()
        AutoTackleConfig.OptimalDistanceMin = uiElements.AutoTackleOptimalDistanceMin:GetValue()
        AutoTackleConfig.OptimalDistanceMax = uiElements.AutoTackleOptimalDistanceMax:GetValue()
        AutoTackleConfig.TackleSpeed = uiElements.AutoTackleTackleSpeed:GetValue()
        AutoTackleConfig.PredictionTime = uiElements.AutoTacklePredictionTime:GetValue()
        AutoTackleConfig.OnlyPlayer = uiElements.AutoTackleOnlyPlayer:GetState()
        AutoTackleConfig.DribbleDelayTime = uiElements.AutoTackleDribbleDelayTime:GetValue()
        AutoTackleConfig.EagleEyeMinDelay = uiElements.AutoTackleEagleEyeMinDelay:GetValue()
        AutoTackleConfig.EagleEyeMaxDelay = uiElements.AutoTackleEagleEyeMaxDelay:GetValue()
        AutoTackleConfig.ManualTackleEnabled = uiElements.AutoTackleManualTackleEnabled:GetState()
        AutoTackleConfig.ManualTackleKeybind = uiElements.AutoTackleManualTackleKeybind:GetBind()
        AutoTackleConfig.ManualTackleCooldown = uiElements.AutoTackleManualTackleCooldown:GetValue()
        AutoTackleConfig.ManualButton = uiElements.AutoTackleManualButton:GetState()
        AutoTackleConfig.ButtonScale = uiElements.AutoTackleButtonScale:GetValue()
        
        AutoDribbleConfig.Enabled = uiElements.AutoDribbleEnabled:GetState()
        AutoDribbleConfig.MaxDribbleDistance = uiElements.AutoDribbleMaxDistance:GetValue()
        AutoDribbleConfig.DribbleActivationDistance = uiElements.AutoDribbleActivationDistance:GetValue()
        AutoDribbleConfig.PredictionTime = uiElements.AutoDribblePredictionTime:GetValue()
        AutoDribbleConfig.MaxAngle = uiElements.AutoDribbleMaxAngle:GetValue()
        AutoDribbleConfig.MaxPredictionAngle = uiElements.AutoDribbleMaxPredictionAngle:GetValue()
        AutoDribbleConfig.TacklePredictionTime = uiElements.AutoDribbleTacklePredictionTime:GetValue()
        AutoDribbleConfig.TackleAngleThreshold = uiElements.AutoDribbleTackleAngleThreshold:GetValue()
        
        DebugConfig.Enabled = uiElements.DebugEnabled:GetState()
        DebugConfig.MoveEnabled = uiElements.DebugMoveEnabled:GetState()
        
        if Gui then
            Gui.ModeLabel.Text = "Mode: " .. AutoTackleConfig.Mode
        end
        
        ToggleManualTackleButton(AutoTackleConfig.ManualButton)
        
        if AutoTackleConfig.Enabled then
            if not AutoTackleStatus.Running then
                AutoTackle.Start()
            end
        else
            if AutoTackleStatus.Running then
                AutoTackle.Stop()
            end
        end
        
        if AutoDribbleConfig.Enabled then
            if not AutoDribbleStatus.Running then
                AutoDribble.Start()
            end
        else
            if AutoDribbleStatus.Running then
                AutoDribble.Stop()
            end
        end
        
        UpdateDebugVisibility()
        notify("Syllinse", "Config synchronized!", true)
    end })
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
    
    LocalPlayerObj.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
        
        DribbleStates = {}
        TackleStates = {}
        PrecomputedPlayers = {}
        DribbleCooldownList = {}
        PowerShootingPlayers = {}
        EagleEyeTimers = {}
        CurrentTargetOwner = nil
        
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
