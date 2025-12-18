local MovementEnhancements = {}

local Services = nil
local PlayerData = nil
local notify = nil
local LocalPlayerObj = nil
local core = nil

MovementEnhancements.Config = {
    Timer = {
        Enabled = false,
        Speed = 2.5,
        ToggleKey = nil
    },
    Disabler = {
        Enabled = false,
        ToggleKey = nil
    },
    Speed = {
        Enabled = false,
        AutoJump = false,
        Method = "CFrame",
        Speed = 16,
        JumpInterval = 0.3,
        PulseTPDist = 5,
        PulseTPDelay = 0.2,
        ToggleKey = nil,
        SmoothnessFactor = 0.2
    },
    Fly = {
        Enabled = false,
        Speed = 50,
        VerticalSpeed = 25,
        ToggleKey = nil,
        VerticalKeys = "E/Q"
    },
    InfStamina = {
        Enabled = false,
        SprintKey = "LeftShift",
        AlwaysSprint = false,
        RestoreGui = true,
        ToggleKey = nil,
        WalkSpeed = 21,
        RunSpeed = 35
    },
    AntiAFK = {
        Enabled = false,
        CustomAFKTime = 60
    }
}

-- Status tables
local TimerStatus = {
    Running = false,
    Connection = nil,
    Speed = MovementEnhancements.Config.Timer.Speed,
    Key = MovementEnhancements.Config.Timer.ToggleKey,
    Enabled = MovementEnhancements.Config.Timer.Enabled
}

local DisablerStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Disabler.ToggleKey,
    Enabled = MovementEnhancements.Config.Disabler.Enabled
}

local SpeedStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Speed.ToggleKey,
    Enabled = MovementEnhancements.Config.Speed.Enabled,
    Method = MovementEnhancements.Config.Speed.Method,
    Speed = MovementEnhancements.Config.Speed.Speed,
    AutoJump = MovementEnhancements.Config.Speed.AutoJump,
    LastJumpTime = 0,
    JumpCooldown = 0.5,
    JumpInterval = MovementEnhancements.Config.Speed.JumpInterval,
    PulseTPDistance = MovementEnhancements.Config.Speed.PulseTPDist,
    PulseTPFrequency = MovementEnhancements.Config.Speed.PulseTPDelay,
    SmoothnessFactor = MovementEnhancements.Config.Speed.SmoothnessFactor,
    CurrentMoveDirection = Vector3.new(0, 0, 0),
    LastPulseTPTime = 0
}

local FlyStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Fly.ToggleKey,
    Enabled = MovementEnhancements.Config.Fly.Enabled,
    Speed = MovementEnhancements.Config.Fly.Speed,
    VerticalSpeed = MovementEnhancements.Config.Fly.VerticalSpeed,
    VerticalKeys = MovementEnhancements.Config.Fly.VerticalKeys,
    IsFlying = false,
    LastPosition = nil,
    LastTime = 0
}

local InfStaminaStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.InfStamina.ToggleKey,
    Enabled = MovementEnhancements.Config.InfStamina.Enabled,
    SprintKey = MovementEnhancements.Config.InfStamina.SprintKey,
    AlwaysSprint = MovementEnhancements.Config.InfStamina.AlwaysSprint,
    RestoreGui = MovementEnhancements.Config.InfStamina.RestoreGui,
    WalkSpeed = MovementEnhancements.Config.InfStamina.WalkSpeed,
    RunSpeed = MovementEnhancements.Config.InfStamina.RunSpeed,
    IsSprinting = false,
    LastSentSpeed = nil,
    GuiMainProtectionConnection = nil,
    SpeedUpdateConnection = nil
}

local AntiAFKStatus = {
    Running = false,
    Connection = nil,
    Enabled = MovementEnhancements.Config.AntiAFK.Enabled,
    CustomAFKTime = MovementEnhancements.Config.AntiAFK.CustomAFKTime,
    LastInputTime = os.time(),
    InputConnection = nil,
    HeartbeatConnection = nil,
    OriginalFireServer = nil
}

-- Helper functions
local function getCharacterData()
    local character = LocalPlayerObj and LocalPlayerObj.Character
    if not character then return nil, nil end
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    return humanoid, rootPart
end

local function isCharacterValid(humanoid, rootPart)
    return humanoid and rootPart and humanoid.Health > 0
end

local function isInVehicle(rootPart)
    local currentPart = rootPart
    while currentPart do
        if currentPart:IsA("Seat") or currentPart:IsA("VehicleSeat") then
            return true
        end
        currentPart = currentPart.Parent
    end
    return false
end

local function isInputFocused()
    return Services and Services.UserInputService and Services.UserInputService:GetFocusedTextBox() ~= nil
end

local function getCustomMoveDirection()
    if not Services.UserInputService or not Services.Workspace.CurrentCamera then
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
        return Vector3.new(0, 0, 0)
    end

    local camera = Services.Workspace.CurrentCamera
    local cameraCFrame = camera.CFrame
    local flatCameraForward = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)
    local flatCameraRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)
    if flatCameraForward.Magnitude == 0 or flatCameraRight.Magnitude == 0 then
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
        return Vector3.new(0, 0, 0)
    end
    flatCameraForward = flatCameraForward.Unit
    flatCameraRight = flatCameraRight.Unit

    local w = Services.UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0
    local s = Services.UserInputService:IsKeyDown(Enum.KeyCode.S) and -1 or 0
    local a = Services.UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0
    local d = Services.UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0

    local inputVector = Vector3.new(a + d, 0, w + s)
    local targetDirection = Vector3.new(0, 0, 0)
    if inputVector.Magnitude > 0 then
        inputVector = inputVector.Unit
        targetDirection = (flatCameraForward * inputVector.Z + flatCameraRight * inputVector.X)
        if targetDirection.Magnitude > 0 then
            targetDirection = targetDirection.Unit
        end
        local alpha = SpeedStatus.SmoothnessFactor
        SpeedStatus.CurrentMoveDirection = SpeedStatus.CurrentMoveDirection * (1 - alpha) + targetDirection * alpha
        if SpeedStatus.CurrentMoveDirection.Magnitude > 0 then
            SpeedStatus.CurrentMoveDirection = SpeedStatus.CurrentMoveDirection.Unit
        end
    else
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
    end
    return SpeedStatus.CurrentMoveDirection
end

-- Timer Module
local Timer = {}
Timer.Start = function()
    if TimerStatus.Running or not Services then return end
    local success = pcall(function()
        setfflag("SimEnableStepPhysics", "True")
        setfflag("SimEnableStepPhysicsSelective", "True")
    end)
    if not success then
        warn("Timer: Failed to enable physics flags")
        notify("Timer", "Failed to enable physics simulation.", true)
        return
    end
    TimerStatus.Running = true
    TimerStatus.Connection = Services.RunService.RenderStepped:Connect(function(dt)
        if not TimerStatus.Enabled or TimerStatus.Speed <= 1 then return end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then return end
        local success, err = pcall(function()
            Services.RunService:Pause()
            Services.Workspace:StepPhysics(dt * (TimerStatus.Speed - 1), {rootPart})
            Services.RunService:Run()
        end)
        if not success then
            warn("Timer physics step failed: " .. tostring(err))
            Timer.Stop()
            notify("Timer", "Physics step failed. Timer stopped.", true)
        end
    end)
    notify("Timer", "Started with speed: " .. TimerStatus.Speed, true)
end

Timer.Stop = function()
    if TimerStatus.Connection then
        TimerStatus.Connection:Disconnect()
        TimerStatus.Connection = nil
    end
    TimerStatus.Running = false
    notify("Timer", "Stopped", true)
end

Timer.SetSpeed = function(newSpeed)
    TimerStatus.Speed = math.clamp(newSpeed, 1, 15)
    MovementEnhancements.Config.Timer.Speed = TimerStatus.Speed
    notify("Timer", "Speed set to: " .. TimerStatus.Speed, false)
end

-- Disabler Module
local Disabler = {}
Disabler.DisableSignals = function(character)
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("CFrame"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("Velocity"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
end

Disabler.Start = function()
    if DisablerStatus.Running or not LocalPlayerObj then return end
    DisablerStatus.Running = true
    DisablerStatus.Connection = LocalPlayerObj.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        Disabler.DisableSignals(char)
    end)
    if LocalPlayerObj.Character then
        Disabler.DisableSignals(LocalPlayerObj.Character)
    end
    notify("Disabler", "Started", true)
end

Disabler.Stop = function()
    if DisablerStatus.Connection then
        DisablerStatus.Connection:Disconnect()
        DisablerStatus.Connection = nil
    end
    DisablerStatus.Running = false
    notify("Disabler", "Stopped", true)
end

-- Speed Module
local Speed = {}
Speed.UpdateMovement = function(humanoid, rootPart, moveDirection, currentTime, dt)
    if not isCharacterValid(humanoid, rootPart) then return end
    if SpeedStatus.Method == "CFrame" then
        if moveDirection.Magnitude > 0 then
            local newCFrame = rootPart.CFrame + (moveDirection * SpeedStatus.Speed * dt)
            rootPart.CFrame = CFrame.new(newCFrame.Position, newCFrame.Position + moveDirection)
        end
    elseif SpeedStatus.Method == "PulseTP" then
        if moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastPulseTPTime >= SpeedStatus.PulseTPFrequency then
            local scaledDistance = SpeedStatus.PulseTPDistance * (SpeedStatus.Speed / 16)
            local teleportVector = moveDirection.Unit * scaledDistance
            local destination = rootPart.Position + teleportVector
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayerObj.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local raycastResult = Services.Workspace:Raycast(rootPart.Position, teleportVector, raycastParams)
            if not raycastResult then
                rootPart.CFrame = CFrame.new(destination, destination + moveDirection)
                SpeedStatus.LastPulseTPTime = currentTime
            end
        end
    end
end

Speed.UpdateJumps = function(humanoid, rootPart, currentTime, moveDirection)
    if not isCharacterValid(humanoid, rootPart) then return end
    if SpeedStatus.AutoJump and moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            SpeedStatus.LastJumpTime = currentTime
        end
    end
end

Speed.Start = function()
    if SpeedStatus.Running or not Services then return end
    SpeedStatus.Running = true
    SpeedStatus.Connection = Services.RunService.Heartbeat:Connect(function(dt)
        if not SpeedStatus.Enabled then
            SpeedStatus.Running = false
            return
        end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then return end
        local currentTime = tick()
        local moveDirection = getCustomMoveDirection()
        Speed.UpdateMovement(humanoid, rootPart, moveDirection, currentTime, dt)
        Speed.UpdateJumps(humanoid, rootPart, currentTime, moveDirection)
    end)
    notify("Speed", "Started with Method: " .. SpeedStatus.Method, true)
end

Speed.Stop = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end
    SpeedStatus.Running = false
    notify("Speed", "Stopped", true)
end

Speed.SetSpeed = function(newSpeed)
    SpeedStatus.Speed = math.clamp(newSpeed, 16, 250)
    MovementEnhancements.Config.Speed.Speed = SpeedStatus.Speed
    notify("Speed", "Speed set to: " .. SpeedStatus.Speed, false)
end

Speed.SetMethod = function(newMethod)
    SpeedStatus.Method = newMethod
    MovementEnhancements.Config.Speed.Method = newMethod
    notify("Speed", "Method set to: " .. newMethod, false)
    if SpeedStatus.Running then
        Speed.Stop()
        Speed.Start()
    end
end

Speed.SetPulseTPDistance = function(value)
    SpeedStatus.PulseTPDistance = math.clamp(value, 1, 20)
    MovementEnhancements.Config.Speed.PulseTPDist = SpeedStatus.PulseTPDistance
    notify("Speed", "Pulse TP Distance set to: " .. SpeedStatus.PulseTPDistance, false)
end

Speed.SetPulseTPFrequency = function(value)
    SpeedStatus.PulseTPFrequency = math.clamp(value, 0.1, 2)
    MovementEnhancements.Config.Speed.PulseTPDelay = SpeedStatus.PulseTPFrequency
    notify("Speed", "Pulse TP Frequency set to: " .. SpeedStatus.PulseTPFrequency, false)
end

Speed.SetSmoothnessFactor = function(value)
    SpeedStatus.SmoothnessFactor = math.clamp(value, 0, 1)
    MovementEnhancements.Config.Speed.SmoothnessFactor = SpeedStatus.SmoothnessFactor
    notify("Speed", "Smoothness Factor set to: " .. SpeedStatus.SmoothnessFactor, false)
end

-- Fly Module (ПРАВИЛЬНЫЙ CFrame метод)
local Fly = {}

-- Получаем вектор движения для полета
Fly.GetFlyVector = function()
    if not Services.UserInputService or not Services.Workspace.CurrentCamera then
        return Vector3.new(0, 0, 0)
    end
    
    local camera = Services.Workspace.CurrentCamera
    local cameraCFrame = camera.CFrame
    
    -- Получаем направления камеры
    local cameraForward = cameraCFrame.LookVector
    local cameraRight = cameraCFrame.RightVector
    local cameraUp = cameraCFrame.UpVector
    
    -- Обрабатываем ввод
    local forward = 0
    local right = 0
    local up = 0
    
    -- WASD для горизонтального движения
    if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then
        forward = forward + 1
    end
    if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then
        forward = forward - 1
    end
    if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then
        right = right - 1
    end
    if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then
        right = right + 1
    end
    
    -- Вертикальное движение
    local upKey, downKey = FlyStatus.VerticalKeys:match("(.+)/(.+)")
    if upKey and downKey then
        if Services.UserInputService:IsKeyDown(Enum.KeyCode[upKey]) then
            up = up + 1
        end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode[downKey]) then
            up = up - 1
        end
    end
    
    -- Комбинируем векторы
    local moveVector = Vector3.new(0, 0, 0)
    
    if forward ~= 0 then
        moveVector = moveVector + (cameraForward * forward)
    end
    if right ~= 0 then
        moveVector = moveVector + (cameraRight * right)
    end
    if up ~= 0 then
        moveVector = moveVector + (cameraUp * up)
    end
    
    -- Нормализуем если есть движение
    if moveVector.Magnitude > 0 then
        moveVector = moveVector.Unit
    end
    
    return moveVector
end

Fly.Start = function()
    if FlyStatus.Running or not Services then return end
    
    local humanoid, rootPart = getCharacterData()
    if not isCharacterValid(humanoid, rootPart) or isInVehicle(rootPart) then return end
    
    FlyStatus.Running = true
    FlyStatus.IsFlying = true
    FlyStatus.LastPosition = rootPart.Position
    FlyStatus.LastTime = tick()
    
    -- Сохраняем начальное состояние
    local originalGravity = humanoid.JumpPower
    humanoid.JumpPower = 0
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    
    notify("Fly", "Started with Speed: " .. FlyStatus.Speed, true)
    
    -- Основной цикл полета
    FlyStatus.Connection = Services.RunService.Heartbeat:Connect(function(dt)
        if not FlyStatus.Enabled then
            FlyStatus.Running = false
            return
        end
        
        local _, currentRootPart = getCharacterData()
        if not currentRootPart then return end
        
        local currentTime = tick()
        local deltaTime = currentTime - FlyStatus.LastTime
        FlyStatus.LastTime = currentTime
        
        -- Получаем вектор движения
        local flyVector = Fly.GetFlyVector()
        
        -- Если есть движение, обновляем позицию
        if flyVector.Magnitude > 0 then
            -- Вычисляем расстояние для движения
            local horizontalDistance = FlyStatus.Speed * deltaTime
            local verticalDistance = FlyStatus.VerticalSpeed * deltaTime
            
            -- Разделяем вектор на горизонтальную и вертикальную компоненты
            local horizontalComponent = Vector3.new(flyVector.X, 0, flyVector.Z)
            local verticalComponent = Vector3.new(0, flyVector.Y, 0)
            
            -- Нормализуем если нужно
            if horizontalComponent.Magnitude > 0 then
                horizontalComponent = horizontalComponent.Unit * horizontalDistance
            end
            if verticalComponent.Magnitude > 0 then
                verticalComponent = verticalComponent.Unit * verticalDistance
            end
            
            -- Вычисляем новую позицию
            local newPosition = currentRootPart.Position + horizontalComponent + verticalComponent
            
            -- Получаем направление взгляда
            local camera = Services.Workspace.CurrentCamera
            local lookDirection
            if camera then
                lookDirection = camera.CFrame.LookVector
            else
                lookDirection = Vector3.new(0, 0, 1)
            end
            
            -- Обнуляем вертикальную компоненту для горизонтального взгляда
            local horizontalLook = Vector3.new(lookDirection.X, 0, lookDirection.Z)
            if horizontalLook.Magnitude == 0 then
                horizontalLook = Vector3.new(0, 0, 1)
            end
            
            -- Создаем новый CFrame
            local newCFrame = CFrame.new(newPosition, newPosition + horizontalLook)
            
            -- Применяем CFrame
            currentRootPart.CFrame = newCFrame
            
            -- Обнуляем физику
            currentRootPart.Velocity = Vector3.new(0, 0, 0)
            currentRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            currentRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            -- Сохраняем позицию
            FlyStatus.LastPosition = newPosition
        else
            -- Если нет движения, просто стабилизируем позицию
            local camera = Services.Workspace.CurrentCamera
            if camera then
                local lookDirection = camera.CFrame.LookVector
                local horizontalLook = Vector3.new(lookDirection.X, 0, lookDirection.Z)
                if horizontalLook.Magnitude == 0 then
                    horizontalLook = Vector3.new(0, 0, 1)
                end
                
                local currentCFrame = currentRootPart.CFrame
                local newCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + horizontalLook)
                currentRootPart.CFrame = newCFrame
            end
            
            -- Обнуляем физику при стоянии на месте
            currentRootPart.Velocity = Vector3.new(0, 0, 0)
            currentRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            currentRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

Fly.Stop = function()
    if FlyStatus.Connection then
        FlyStatus.Connection:Disconnect()
        FlyStatus.Connection = nil
    end
    
    -- Восстанавливаем состояние
    local humanoid, rootPart = getCharacterData()
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        humanoid.JumpPower = 50 -- Стандартное значение
    end
    
    if rootPart then
        rootPart.Velocity = Vector3.new(0, 0, 0)
    end
    
    FlyStatus.Running = false
    FlyStatus.IsFlying = false
    FlyStatus.LastPosition = nil
    
    notify("Fly", "Stopped", true)
end

Fly.SetSpeed = function(newSpeed)
    FlyStatus.Speed = math.clamp(newSpeed, 10, 200)
    MovementEnhancements.Config.Fly.Speed = FlyStatus.Speed
    notify("Fly", "Speed set to: " .. FlyStatus.Speed, false)
end

Fly.SetVerticalSpeed = function(newSpeed)
    FlyStatus.VerticalSpeed = math.clamp(newSpeed, 10, 200)
    MovementEnhancements.Config.Fly.VerticalSpeed = FlyStatus.VerticalSpeed
    notify("Fly", "Vertical Speed set to: " .. FlyStatus.VerticalSpeed, false)
end

Fly.SetVerticalKeys = function(newKeys)
    FlyStatus.VerticalKeys = newKeys
    MovementEnhancements.Config.Fly.VerticalKeys = newKeys
    notify("Fly", "Vertical Keys set to: " .. newKeys, false)
end

-- InfStamina Module
local InfStamina = {}
InfStamina.GetStaminaGuiElements = function()
    local playerGui = LocalPlayerObj and LocalPlayerObj:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local staminaFrame = playerGui:FindFirstChild("Stamina")
    if not staminaFrame then return nil end
    
    local frame = staminaFrame:FindFirstChild("Frame")
    if not frame then return nil end
    
    return {
        Frame = frame,
        Speeds = frame:FindFirstChild("Speeds"),
        SpeedRemote = frame:FindFirstChild("Speed"),
        GreenBar = frame:FindFirstChild("GreenBar"),
        StaminaLabel = frame:FindFirstChild("Stamina"),
        Enabled = frame:FindFirstChild("Enabled"),
        GuiMain = frame:FindFirstChild("GuiMain"),
        Rest1 = frame:FindFirstChild("Rest1"),
        Rest2 = frame:FindFirstChild("Rest2")
    }
end

InfStamina.ForceDisableGuiMain = function()
    if not InfStaminaStatus.Enabled then return end
    
    local elements = InfStamina.GetStaminaGuiElements()
    if elements and elements.GuiMain then
        elements.GuiMain.Disabled = true
    end
end

InfStamina.UpdateStaminaValues = function()
    if not InfStaminaStatus.Enabled then return end
    
    local elements = InfStamina.GetStaminaGuiElements()
    if elements then
        if elements.Speeds then
            local walkSpeedVal = elements.Speeds:FindFirstChild("Walk")
            local runSpeedVal = elements.Speeds:FindFirstChild("Run")
            
            if walkSpeedVal then
                InfStaminaStatus.WalkSpeed = walkSpeedVal.Value
            end
            if runSpeedVal then
                InfStaminaStatus.RunSpeed = runSpeedVal.Value
            end
        end
        
        if InfStaminaStatus.RestoreGui and elements.GreenBar and elements.StaminaLabel then
            elements.GreenBar.Size = UDim2.new(1, 0, 0, 32)
            elements.GreenBar.Image = "rbxassetid://119528804"
            elements.StaminaLabel.Visible = true
            
            if elements.Rest1 then
                elements.Rest1.Visible = false
            end
            if elements.Rest2 then
                elements.Rest2.Visible = false
            end
        end
    end
end

InfStamina.Start = function()
    if InfStaminaStatus.Running or not Services then return end
    if not LocalPlayerObj then return end
    
    InfStaminaStatus.Running = true
    
    -- Защита GuiMain
    InfStaminaStatus.GuiMainProtectionConnection = Services.RunService.Heartbeat:Connect(function()
        if not InfStaminaStatus.Enabled then return end
        InfStamina.ForceDisableGuiMain()
    end)
    
    -- Обновление значений скорости
    InfStaminaStatus.SpeedUpdateConnection = Services.RunService.Heartbeat:Connect(function()
        if not InfStaminaStatus.Enabled then return end
        
        local humanoid = getCharacterData()
        if not humanoid then return end
        
        InfStamina.UpdateStaminaValues()
        
        local shouldSprint = InfStaminaStatus.AlwaysSprint or 
                           (Services.UserInputService and 
                            Services.UserInputService:IsKeyDown(Enum.KeyCode[InfStaminaStatus.SprintKey]))
        
        local targetSpeed = shouldSprint and InfStaminaStatus.RunSpeed or InfStaminaStatus.WalkSpeed
        humanoid.WalkSpeed = targetSpeed
        
        local elements = InfStamina.GetStaminaGuiElements()
        if elements and elements.SpeedRemote and targetSpeed ~= InfStaminaStatus.LastSentSpeed then
            pcall(function()
                elements.SpeedRemote:FireServer(10525299, targetSpeed)
                InfStaminaStatus.LastSentSpeed = targetSpeed
            end)
        end
    end)
    
    -- Обработка ввода для спринта
    if Services.UserInputService then
        Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not InfStaminaStatus.Enabled or InfStaminaStatus.AlwaysSprint then return end
            
            if input.KeyCode == Enum.KeyCode[InfStaminaStatus.SprintKey] then
                InfStaminaStatus.IsSprinting = true
            end
        end)
        
        Services.UserInputService.InputEnded:Connect(function(input, gameProcessed)
            if gameProcessed or not InfStaminaStatus.Enabled or InfStaminaStatus.AlwaysSprint then return end
            
            if input.KeyCode == Enum.KeyCode[InfStaminaStatus.SprintKey] then
                InfStaminaStatus.IsSprinting = false
            end
        end)
    end
    
    -- Инициализация
    InfStamina.ForceDisableGuiMain()
    InfStamina.UpdateStaminaValues()
    
    notify("InfStamina", "Started", true)
end

InfStamina.Stop = function()
    if InfStaminaStatus.GuiMainProtectionConnection then
        InfStaminaStatus.GuiMainProtectionConnection:Disconnect()
        InfStaminaStatus.GuiMainProtectionConnection = nil
    end
    
    if InfStaminaStatus.SpeedUpdateConnection then
        InfStaminaStatus.SpeedUpdateConnection:Disconnect()
        InfStaminaStatus.SpeedUpdateConnection = nil
    end
    
    InfStaminaStatus.Running = false
    InfStaminaStatus.LastSentSpeed = nil
    notify("InfStamina", "Stopped", true)
end

InfStamina.SetSprintKey = function(newKey)
    InfStaminaStatus.SprintKey = newKey
    MovementEnhancements.Config.InfStamina.SprintKey = newKey
    notify("InfStamina", "Sprint key set to: " .. newKey, false)
end

InfStamina.SetAlwaysSprint = function(enabled)
    InfStaminaStatus.AlwaysSprint = enabled
    MovementEnhancements.Config.InfStamina.AlwaysSprint = enabled
    notify("InfStamina", "Always sprint " .. (enabled and "enabled" or "disabled"), false)
end

InfStamina.SetRestoreGui = function(enabled)
    InfStaminaStatus.RestoreGui = enabled
    MovementEnhancements.Config.InfStamina.RestoreGui = enabled
    notify("InfStamina", "Restore GUI " .. (enabled and "enabled" or "disabled"), false)
end

-- AntiAFK Module
local AntiAFK = {}

AntiAFK.Start = function()
    if AntiAFKStatus.Running or not Services then return end
    
    AntiAFKStatus.Running = true
    AntiAFKStatus.LastInputTime = os.time()
    
    -- Находим AFKRemote
    local afkRemote
    local success, err = pcall(function()
        afkRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("AFKRemote")
    end)
    
    if success and afkRemote then
        -- Хук для перехвата FireServer
        local originalNamecall
        originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local args = {...}
            local method = getnamecallmethod()
            
            if self == afkRemote and method == "FireServer" then
                if AntiAFKStatus.Enabled and args[1] == true then
                    notify("AntiAFK", "Blocked AFK activation", false)
                    return nil
                end
            end
            
            return originalNamecall(self, ...)
        end)
        
        AntiAFKStatus.OriginalFireServer = originalNamecall
    end
    
    -- Обработчик ввода
    AntiAFKStatus.InputConnection = Services.UserInputService.InputBegan:Connect(function()
        AntiAFKStatus.LastInputTime = os.time()
    end)
    
    -- Основной цикл для симуляции ввода
    AntiAFKStatus.HeartbeatConnection = Services.RunService.Heartbeat:Connect(function()
        if not AntiAFKStatus.Enabled then
            AntiAFKStatus.Running = false
            return
        end
        
        local currentTime = os.time()
        local timeSinceLastInput = currentTime - AntiAFKStatus.LastInputTime
        
        if timeSinceLastInput > AntiAFKStatus.CustomAFKTime then
            AntiAFKStatus.LastInputTime = currentTime
            
            -- Симуляция ввода
            local virtualInput = game:GetService("VirtualInputManager")
            if virtualInput then
                virtualInput:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.05)
                virtualInput:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end
            
            notify("AntiAFK", "Prevented AFK kick", false)
        end
    end)
    
    notify("AntiAFK", "Started (Timeout: " .. AntiAFKStatus.CustomAFKTime .. "s)", true)
end

AntiAFK.Stop = function()
    if AntiAFKStatus.InputConnection then
        AntiAFKStatus.InputConnection:Disconnect()
        AntiAFKStatus.InputConnection = nil
    end
    
    if AntiAFKStatus.HeartbeatConnection then
        AntiAFKStatus.HeartbeatConnection:Disconnect()
        AntiAFKStatus.HeartbeatConnection = nil
    end
    
    -- Восстанавливаем оригинальный __namecall
    if AntiAFKStatus.OriginalFireServer then
        hookmetamethod(game, "__namecall", AntiAFKStatus.OriginalFireServer)
    end
    
    AntiAFKStatus.Running = false
    notify("AntiAFK", "Stopped", true)
end

AntiAFK.SetAFKTime = function(newTime)
    AntiAFKStatus.CustomAFKTime = math.clamp(newTime, 30, 300)
    MovementEnhancements.Config.AntiAFK.CustomAFKTime = AntiAFKStatus.CustomAFKTime
    notify("AntiAFK", "AFK time set to: " .. AntiAFKStatus.CustomAFKTime .. "s", false)
end

-- UI Setup
local function SetupUI(UI)
    -- Timer Section
    if UI.Sections.Timer then
        UI.Sections.Timer:Header({ Name = "Timer" })
        UI.Sections.Timer:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Timer.Enabled,
            Callback = function(value)
                TimerStatus.Enabled = value
                MovementEnhancements.Config.Timer.Enabled = value
                if value then Timer.Start() else Timer.Stop() end
            end
        })
        
        UI.Sections.Timer:Slider({
            Name = "Speed",
            Minimum = 1,
            Maximum = 15,
            Default = MovementEnhancements.Config.Timer.Speed,
            Precision = 1,
            Callback = function(value)
                Timer.SetSpeed(value)
            end
        })
        
        UI.Sections.Timer:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Timer.ToggleKey,
            Callback = function(value)
                TimerStatus.Key = value
                MovementEnhancements.Config.Timer.ToggleKey = value
                if isInputFocused() then return end
                if TimerStatus.Enabled then
                    if TimerStatus.Running then Timer.Stop() else Timer.Start() end
                else
                    notify("Timer", "Enable Timer to use keybind.", true)
                end
            end
        })
    end

    -- Disabler Section
    if UI.Sections.Disabler then
        UI.Sections.Disabler:Header({ Name = "Disabler" })
        UI.Sections.Disabler:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Disabler.Enabled,
            Callback = function(value)
                DisablerStatus.Enabled = value
                MovementEnhancements.Config.Disabler.Enabled = value
                if value then Disabler.Start() else Disabler.Stop() end
            end
        })
        
        UI.Sections.Disabler:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Disabler.ToggleKey,
            Callback = function(value)
                DisablerStatus.Key = value
                MovementEnhancements.Config.Disabler.ToggleKey = value
                if isInputFocused() then return end
                if DisablerStatus.Enabled then
                    if DisablerStatus.Running then Disabler.Stop() else Disabler.Start() end
                else
                    notify("Disabler", "Enable Disabler to use keybind.", true)
                end
            end
        })
    end

    -- Speed Section
    if UI.Sections.Speed then
        UI.Sections.Speed:Header({ Name = "Speed" })
        UI.Sections.Speed:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Speed.Enabled,
            Callback = function(value)
                SpeedStatus.Enabled = value
                MovementEnhancements.Config.Speed.Enabled = value
                if value then Speed.Start() else Speed.Stop() end
            end
        })
        
        UI.Sections.Speed:Toggle({
            Name = "Auto Jump",
            Default = MovementEnhancements.Config.Speed.AutoJump,
            Callback = function(value)
                SpeedStatus.AutoJump = value
                MovementEnhancements.Config.Speed.AutoJump = value
            end
        })
        
        UI.Sections.Speed:Dropdown({
            Name = "Method",
            Options = {"CFrame", "PulseTP"},
            Default = MovementEnhancements.Config.Speed.Method,
            Callback = function(value)
                Speed.SetMethod(value)
            end
        })
        
        UI.Sections.Speed:Slider({
            Name = "Speed",
            Minimum = 16,
            Maximum = 250,
            Default = MovementEnhancements.Config.Speed.Speed,
            Precision = 1,
            Callback = function(value)
                Speed.SetSpeed(value)
            end
        })
        
        UI.Sections.Speed:Slider({
            Name = "Jump Interval",
            Minimum = 0.1,
            Maximum = 2,
            Default = MovementEnhancements.Config.Speed.JumpInterval,
            Precision = 2,
            Callback = function(value)
                SpeedStatus.JumpInterval = value
                MovementEnhancements.Config.Speed.JumpInterval = value
                notify("Speed", "Jump Interval set to: " .. value, false)
            end
        })
        
        UI.Sections.Speed:Slider({
            Name = "Pulse TP Distance",
            Minimum = 1,
            Maximum = 20,
            Default = MovementEnhancements.Config.Speed.PulseTPDist,
            Precision = 1,
            Callback = function(value)
                Speed.SetPulseTPDistance(value)
            end
        })
        
        UI.Sections.Speed:Slider({
            Name = "Pulse TP Frequency",
            Minimum = 0.1,
            Maximum = 2,
            Default = MovementEnhancements.Config.Speed.PulseTPDelay,
            Precision = 2,
            Callback = function(value)
                Speed.SetPulseTPFrequency(value)
            end
        })
        
        UI.Sections.Speed:Slider({
            Name = "Smoothness Factor",
            Minimum = 0,
            Maximum = 1,
            Default = MovementEnhancements.Config.Speed.SmoothnessFactor,
            Precision = 2,
            Callback = function(value)
                Speed.SetSmoothnessFactor(value)
            end
        })
        
        UI.Sections.Speed:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Speed.ToggleKey,
            Callback = function(value)
                SpeedStatus.Key = value
                MovementEnhancements.Config.Speed.ToggleKey = value
                if isInputFocused() then return end
                if SpeedStatus.Enabled then
                    if SpeedStatus.Running then Speed.Stop() else Speed.Start() end
                else
                    notify("Speed", "Enable Speed to use keybind.", true)
                end
            end
        })
    end

    -- Fly Section
    if UI.Sections.Fly then
        UI.Sections.Fly:Header({ Name = "Fly" })
        UI.Sections.Fly:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Fly.Enabled,
            Callback = function(value)
                FlyStatus.Enabled = value
                MovementEnhancements.Config.Fly.Enabled = value
                if value then Fly.Start() else Fly.Stop() end
            end
        })
        
        UI.Sections.Fly:Slider({
            Name = "Speed",
            Minimum = 10,
            Maximum = 200,
            Default = MovementEnhancements.Config.Fly.Speed,
            Precision = 1,
            Callback = function(value)
                Fly.SetSpeed(value)
            end
        })
        
        UI.Sections.Fly:Slider({
            Name = "Vertical Speed",
            Minimum = 10,
            Maximum = 200,
            Default = MovementEnhancements.Config.Fly.VerticalSpeed,
            Precision = 1,
            Callback = function(value)
                Fly.SetVerticalSpeed(value)
            end
        })
        
        UI.Sections.Fly:Dropdown({
            Name = "Vertical Keys",
            Options = {"E/Q", "Space/LeftControl"},
            Default = MovementEnhancements.Config.Fly.VerticalKeys,
            Callback = function(value)
                Fly.SetVerticalKeys(value)
            end
        })
        
        UI.Sections.Fly:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Fly.ToggleKey,
            Callback = function(value)
                FlyStatus.Key = value
                MovementEnhancements.Config.Fly.ToggleKey = value
                if isInputFocused() then return end
                if FlyStatus.Enabled then
                    if FlyStatus.Running then Fly.Stop() else Fly.Start() end
                else
                    notify("Fly", "Enable Fly to use keybind.", true)
                end
            end
        })
    end

    -- InfStamina Section
    if UI.Sections.InfStamina then
        UI.Sections.InfStamina:Header({ Name = "Infinity Stamina" })
        
        UI.Sections.InfStamina:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.InfStamina.Enabled,
            Callback = function(value)
                InfStaminaStatus.Enabled = value
                MovementEnhancements.Config.InfStamina.Enabled = value
                if value then InfStamina.Start() else InfStamina.Stop() end
            end
        })

        UI.Sections.InfStamina:SubLabel({ Text = '[❗] Ban risk, should be undetected \n but anticheat can detect it easily' })
        
        UI.Sections.InfStamina:Toggle({
            Name = "Always Sprint",
            Default = MovementEnhancements.Config.InfStamina.AlwaysSprint,
            Callback = function(value)
                InfStamina.SetAlwaysSprint(value)
            end
        })
        UI.Sections.InfStamina:SubLabel({Text = '[❗] Ban risk, not recommend to use always sprint'})
        UI.Sections.InfStamina:Toggle({
            Name = "Restore GUI",
            Default = MovementEnhancements.Config.InfStamina.RestoreGui,
            Callback = function(value)
                InfStamina.SetRestoreGui(value)
            end
        })
        
        UI.Sections.InfStamina:Dropdown({
            Name = "Sprint Key",
            Options = {"LeftShift", "Space", "C", "V"},
            Default = MovementEnhancements.Config.InfStamina.SprintKey,
            Callback = function(value)
                InfStamina.SetSprintKey(value)
            end
        })
        
        UI.Sections.InfStamina:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.InfStamina.ToggleKey,
            Callback = function(value)
                InfStaminaStatus.Key = value
                MovementEnhancements.Config.InfStamina.ToggleKey = value
                if isInputFocused() then return end
                if InfStaminaStatus.Enabled then
                    if InfStaminaStatus.Running then InfStamina.Stop() else InfStamina.Start() end
                else
                    notify("InfStamina", "Enable InfStamina to use keybind.", true)
                end
            end
        })
    end

    -- AntiAFK Section
    if UI.Sections.AntiAFK then
        UI.Sections.AntiAFK:Header({ Name = "Anti-AFK" })
        
        UI.Sections.AntiAFK:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.AntiAFK.Enabled,
            Callback = function(value)
                AntiAFKStatus.Enabled = value
                MovementEnhancements.Config.AntiAFK.Enabled = value
                if value then AntiAFK.Start() else AntiAFK.Stop() end
            end
        })
        
        UI.Sections.AntiAFK:Slider({
            Name = "AFK Time (seconds)",
            Minimum = 30,
            Maximum = 300,
            Default = MovementEnhancements.Config.AntiAFK.CustomAFKTime,
            Precision = 1,
            Callback = function(value)
                AntiAFK.SetAFKTime(value)
            end
        })
    end
end

-- Main Initialization
function MovementEnhancements.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer

    -- Global functions
    _G.setTimerSpeed = Timer.SetSpeed
    _G.setSpeed = Speed.SetSpeed
    _G.setFlySpeed = Fly.SetSpeed
    _G.setFlyVerticalSpeed = Fly.SetVerticalSpeed
    _G.setFlyVerticalKeys = Fly.SetVerticalKeys
    _G.setInfStaminaSprintKey = InfStamina.SetSprintKey
    _G.setAntiAFKTime = AntiAFK.SetAFKTime

    -- Character added connections
    if LocalPlayerObj then
        local function handleCharacterChange()
            task.wait(0.5)
            
            if DisablerStatus.Enabled then
                Disabler.DisableSignals(LocalPlayerObj.Character)
            end
            if SpeedStatus.Enabled then
                Speed.Start()
            end
            if FlyStatus.Enabled then
                Fly.Stop()
                task.wait(0.1)
                Fly.Start()
            end
            if InfStaminaStatus.Enabled then
                task.wait(1)
                InfStamina.Start()
            end
        end
        
        LocalPlayerObj.CharacterAdded:Connect(handleCharacterChange)
        
        -- Handle initial character
        if LocalPlayerObj.Character then
            task.spawn(handleCharacterChange)
        end
    end

    SetupUI(UI)
end

-- Cleanup function
function MovementEnhancements:Destroy()
    -- Timer
    Timer.Stop()
    
    -- Disabler
    Disabler.Stop()
    
    -- Speed
    Speed.Stop()
    
    -- Fly
    Fly.Stop()
    
    -- InfStamina
    InfStamina.Stop()
    
    -- AntiAFK
    AntiAFK.Stop()
    
    notify("MovementEnhancements", "All modules stopped", true)
end

return MovementEnhancements
