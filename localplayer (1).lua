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
    InfStamina = {
        Enabled = false,
        SprintKey = "LeftShift",
        AlwaysSprint = false,
        RestoreGui = true,
        ToggleKey = nil,
        WalkSpeed = 21,
        RunSpeed = 35
    },
    AutoGKSelect = {
        Enabled = false
    },
    AntiAFK = {
        Enabled = false
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

-- AutoGK Variables
local AutoGKStatus = {
    Running = false,
    Enabled = MovementEnhancements.Config.AutoGKSelect.Enabled,
    Players = nil,
    ReplicatedStorage = nil,
    Workspace = nil,
    Remotes = nil,
    TeamChange = nil,
    AFKRemote = nil,
    Bools = nil,
    VIPServer = nil,
    Intermission = nil,
    PlayerStats = nil,
    AwayTeamFolder = nil,
    HomeTeamFolder = nil,
    AWAY_GK_ARGS = {BrickColor.new(23), "Goalie"},
    HOME_GK_ARGS = {BrickColor.new(141), "Goalie"},
    ANTI_AFK_ARGS = {true},
    lastFireTime = 0,
    COOLDOWN = 1,
    sentInIntermission = {away = false, home = false},
    lastOccupied = {away = false, home = false},
    Connection = nil
}

-- AntiAFK Variables
local AntiAFKStatus = {
    Running = false,
    Enabled = MovementEnhancements.Config.AntiAFK.Enabled,
    Players = nil,
    RunService = nil,
    ReplicatedStorage = nil,
    LocalPlayer = nil,
    PlayerScripts = nil,
    AFKRemote = nil,
    foundAndDisabled = false,
    currentScriptName = "None",
    label = nil,
    checkConnection = nil
}

-- JoinTeam Variables
local JoinTeamStatus = {
    Players = nil,
    ReplicatedStorage = nil,
    Workspace = nil,
    Remotes = nil,
    TeamChange = nil,
    PlayerStats = nil,
    AwayTeamFolder = nil,
    HomeTeamFolder = nil,
    AWAY_ARGS = {BrickColor.new(23), "Player"},
    HOME_ARGS = {BrickColor.new(141), "Player"},
    awayLabel = nil,
    homeLabel = nil,
    monitoringConnection = nil,
    lastAwayCount = 0,
    lastHomeCount = 0
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

-- AutoGK Functions
local function initializeAutoGK()
    if not Services then return false end
    
    AutoGKStatus.Players = Services.Players
    AutoGKStatus.ReplicatedStorage = Services.ReplicatedStorage
    AutoGKStatus.Workspace = Services.Workspace
    AutoGKStatus.LocalPlayer = AutoGKStatus.Players.LocalPlayer
    
    local success, result = pcall(function()
        AutoGKStatus.Remotes = AutoGKStatus.ReplicatedStorage:WaitForChild("Remotes", 5)
        AutoGKStatus.TeamChange = AutoGKStatus.Remotes:WaitForChild("TeamChange", 5)
        AutoGKStatus.AFKRemote = AutoGKStatus.Remotes:WaitForChild("AFKRemote", 5)
        
        AutoGKStatus.Bools = AutoGKStatus.Workspace:WaitForChild("Bools", 5)
        AutoGKStatus.VIPServer = AutoGKStatus.Bools:WaitForChild("VIPServer", 5)
        AutoGKStatus.Intermission = AutoGKStatus.Bools:WaitForChild("Intermission", 5)
        
        AutoGKStatus.PlayerStats = AutoGKStatus.Workspace:WaitForChild("PlayerStats", 5)
        AutoGKStatus.AwayTeamFolder = AutoGKStatus.PlayerStats:WaitForChild("Away", 5)
        AutoGKStatus.HomeTeamFolder = AutoGKStatus.PlayerStats:WaitForChild("Home", 5)
        
        return true
    end)
    
    if not success then
        notify("AutoGK", "Failed to initialize: " .. tostring(result), true)
        return false
    end
    
    return true
end

local function getPlayerTeam(playerName)
    if not playerName or not AutoGKStatus.AwayTeamFolder or not AutoGKStatus.HomeTeamFolder then return nil end
    
    if AutoGKStatus.AwayTeamFolder:FindFirstChild(playerName) then
        return "Away"
    end
    
    if AutoGKStatus.HomeTeamFolder:FindFirstChild(playerName) then
        return "Home"
    end
    
    return nil
end

local function getOccupiedGKSlots()
    local occupied = {away = false, home = false}
    
    if not AutoGKStatus.Players then return occupied end
    
    for _, player in pairs(AutoGKStatus.Players:GetPlayers()) do
        if player.Character then
            local hitbox = player.Character:FindFirstChild("Hitbox")
            if hitbox and hitbox:IsA("BasePart") then
                local team = getPlayerTeam(player.Name)
                
                if team == "Away" then
                    occupied.away = player.Name
                elseif team == "Home" then
                    occupied.home = player.Name
                else
                    occupied.away = player.Name
                    occupied.home = player.Name
                end
            end
        end
    end
    
    if occupied.away ~= AutoGKStatus.lastOccupied.away or occupied.home ~= AutoGKStatus.lastOccupied.home then
        AutoGKStatus.lastOccupied = {away = occupied.away, home = occupied.home}
    end
    
    return occupied
end

local function isCurrentlyGK()
    if not AutoGKStatus.LocalPlayer or not AutoGKStatus.LocalPlayer.Character then return false end
    local hitbox = AutoGKStatus.LocalPlayer.Character:FindFirstChild("Hitbox")
    return hitbox ~= nil and hitbox:IsA("BasePart")
end

local function sendAntiAFK()
    if not AutoGKStatus.AFKRemote then return end
    pcall(function()
        AutoGKStatus.AFKRemote:FireServer(unpack(AutoGKStatus.ANTI_AFK_ARGS))
    end)
end

local function tryBecomeGK(args, teamName, isAway)
    local now = tick()
    if now - AutoGKStatus.lastFireTime < AutoGKStatus.COOLDOWN then
        notify("AutoGK", "Cooldown active - " .. teamName, false)
        return false
    end

    sendAntiAFK()
    task.wait(0.05)

    local success = pcall(function()
        AutoGKStatus.TeamChange:FireServer(unpack(args))
        AutoGKStatus.lastFireTime = now
        notify("AutoGK", "Sent: " .. teamName .. " GK + AntiAFK", false)
    end)

    if success and AutoGKStatus.Intermission and AutoGKStatus.Intermission.Value then
        if isAway then 
            AutoGKStatus.sentInIntermission.away = true
        else 
            AutoGKStatus.sentInIntermission.home = true 
        end
    end
    return success
end

local function attemptGK()
    if not AutoGKStatus.Enabled then return end
    
    if isCurrentlyGK() then
        return
    end

    local slots = getOccupiedGKSlots()
    
    if not slots.away then
        tryBecomeGK(AutoGKStatus.AWAY_GK_ARGS, "AWAY", true)
    elseif not slots.home then
        tryBecomeGK(AutoGKStatus.HOME_GK_ARGS, "HOME", false)
    end
end

local function selectGKAway()
    if not initializeAutoGK() then 
        notify("AutoGK", "Failed to initialize AutoGK", true)
        return 
    end
    
    local slots = getOccupiedGKSlots()
    if slots.away then
        notify("AutoGK", "Away GK already occupied: " .. slots.away, true)
        return
    end
    
    if tryBecomeGK(AutoGKStatus.AWAY_GK_ARGS, "AWAY", true) then
        notify("AutoGK", "Selected Away team", false)
    end
end

local function selectGKHome()
    if not initializeAutoGK() then 
        notify("AutoGK", "Failed to initialize AutoGK", true)
        return 
    end
    
    local slots = getOccupiedGKSlots()
    if slots.home then
        notify("AutoGK", "Home GK already occupied: " .. slots.home, true)
        return
    end
    
    if tryBecomeGK(AutoGKStatus.HOME_GK_ARGS, "HOME", false) then
        notify("AutoGK", "Selected Home team", false)
    end
end

local function startAutoGK()
    if AutoGKStatus.Running then return end
    
    if not initializeAutoGK() then
        notify("AutoGK", "Failed to find required objects", true)
        return
    end
    
    AutoGKStatus.Running = true
    
    AutoGKStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not AutoGKStatus.Enabled then return end
        attemptGK()
    end)
    
    notify("AutoGK", "AutoGKSelect started", true)
end

local function stopAutoGK()
    if AutoGKStatus.Connection then
        AutoGKStatus.Connection:Disconnect()
        AutoGKStatus.Connection = nil
    end
    
    AutoGKStatus.Running = false
    notify("AutoGK", "AutoGKSelect stopped", true)
end

-- JoinTeam Functions
local function initializeJoinTeam()
    if not Services then return false end
    
    JoinTeamStatus.Players = Services.Players
    JoinTeamStatus.ReplicatedStorage = Services.ReplicatedStorage
    JoinTeamStatus.Workspace = Services.Workspace
    
    local success, result = pcall(function()
        JoinTeamStatus.Remotes = JoinTeamStatus.ReplicatedStorage:WaitForChild("Remotes", 5)
        JoinTeamStatus.TeamChange = JoinTeamStatus.Remotes:WaitForChild("TeamChange", 5)
        
        JoinTeamStatus.PlayerStats = JoinTeamStatus.Workspace:WaitForChild("PlayerStats", 5)
        JoinTeamStatus.AwayTeamFolder = JoinTeamStatus.PlayerStats:WaitForChild("Away", 5)
        JoinTeamStatus.HomeTeamFolder = JoinTeamStatus.PlayerStats:WaitForChild("Home", 5)
        
        return true
    end)
    
    if not success then
        notify("JoinTeam", "Failed to initialize: " .. tostring(result), true)
        return false
    end
    
    return true
end

local function getTeamCounts()
    local awayCount = 0
    local homeCount = 0
    
    if JoinTeamStatus.AwayTeamFolder and JoinTeamStatus.HomeTeamFolder then
        awayCount = #JoinTeamStatus.AwayTeamFolder:GetChildren()
        homeCount = #JoinTeamStatus.HomeTeamFolder:GetChildren()
    end
    
    return awayCount, homeCount
end

local function updateTeamLabels()
    if not JoinTeamStatus.awayLabel or not JoinTeamStatus.homeLabel then return end
    
    local awayCount, homeCount = getTeamCounts()
    
    -- Update only if counts changed
    if awayCount ~= JoinTeamStatus.lastAwayCount then
        JoinTeamStatus.awayLabel:UpdateName("Away Count: " .. awayCount)
        JoinTeamStatus.lastAwayCount = awayCount
    end
    
    if homeCount ~= JoinTeamStatus.lastHomeCount then
        JoinTeamStatus.homeLabel:UpdateName("Home Count: " .. homeCount)
        JoinTeamStatus.lastHomeCount = homeCount
    end
end

local function startTeamMonitoring()
    if JoinTeamStatus.monitoringConnection then return end
    
    -- Initialize first
    if not initializeJoinTeam() then return end
    
    -- Update labels immediately
    updateTeamLabels()
    
    -- Start monitoring for team changes
    JoinTeamStatus.monitoringConnection = Services.RunService.Heartbeat:Connect(function()
        updateTeamLabels()
    end)
    
    -- Also monitor folder changes
    if JoinTeamStatus.AwayTeamFolder then
        JoinTeamStatus.AwayTeamFolder.ChildAdded:Connect(function()
            updateTeamLabels()
        end)
        JoinTeamStatus.AwayTeamFolder.ChildRemoved:Connect(function()
            updateTeamLabels()
        end)
    end
    
    if JoinTeamStatus.HomeTeamFolder then
        JoinTeamStatus.HomeTeamFolder.ChildAdded:Connect(function()
            updateTeamLabels()
        end)
        JoinTeamStatus.HomeTeamFolder.ChildRemoved:Connect(function()
            updateTeamLabels()
        end)
    end
end

local function joinAwayTeam()
    if not initializeJoinTeam() then 
        notify("JoinTeam", "Failed to initialize JoinTeam", true)
        return 
    end
    
    local success = pcall(function()
        JoinTeamStatus.TeamChange:FireServer(unpack(JoinTeamStatus.AWAY_ARGS))
        notify("JoinTeam", "Joined Away team as Player", false)
        
        -- Update counts after joining
        task.wait(0.1)
        updateTeamLabels()
    end)
    
    if not success then
        notify("JoinTeam", "Failed to join Away team", true)
    end
end

local function joinHomeTeam()
    if not initializeJoinTeam() then 
        notify("JoinTeam", "Failed to initialize JoinTeam", true)
        return 
    end
    
    local success = pcall(function()
        JoinTeamStatus.TeamChange:FireServer(unpack(JoinTeamStatus.HOME_ARGS))
        notify("JoinTeam", "Joined Home team as Player", false)
        
        -- Update counts after joining
        task.wait(0.1)
        updateTeamLabels()
    end)
    
    if not success then
        notify("JoinTeam", "Failed to join Home team", true)
    end
end

local function stopTeamMonitoring()
    if JoinTeamStatus.monitoringConnection then
        JoinTeamStatus.monitoringConnection:Disconnect()
        JoinTeamStatus.monitoringConnection = nil
    end
end

-- AntiAFK Functions
local function neutralizeAFKScript(afkScript)
    if not afkScript or AntiAFKStatus.foundAndDisabled then return end
    
    local disabledCount = 0
    
    pcall(function()
        -- Disable RenderStepped connections
        for _, conn in pairs(getconnections(AntiAFKStatus.RunService.RenderStepped)) do
            if conn.Function and getfenv(conn.Function).script == afkScript then
                conn:Disable()
                disabledCount = disabledCount + 1
            end
        end
        
        -- Disable OnClientEvent connections
        for _, conn in pairs(getconnections(AntiAFKStatus.AFKRemote.OnClientEvent)) do
            if conn.Function and getfenv(conn.Function).script == afkScript then
                conn:Disable()
                disabledCount = disabledCount + 1
            end
        end
    end)
    
    if disabledCount > 0 then
        AntiAFKStatus.foundAndDisabled = true
        AntiAFKStatus.currentScriptName = afkScript.Name .. " (Neutralized)"
        notify("AntiAFK", "AFKClient found and neutralized! Script: " .. afkScript.Name, false)
        
        if AntiAFKStatus.label then
            AntiAFKStatus.label:UpdateName("AntiAFK pointer: " .. AntiAFKStatus.currentScriptName)
        end
    end
end

local function updateAntiAFKLabel()
    if AntiAFKStatus.label then
        AntiAFKStatus.label:UpdateName("AntiAFK pointer: " .. AntiAFKStatus.currentScriptName)
    end
end

local function startAntiAFK()
    if AntiAFKStatus.Running then return end
    
    AntiAFKStatus.Players = Services.Players
    AntiAFKStatus.RunService = Services.RunService
    AntiAFKStatus.ReplicatedStorage = Services.ReplicatedStorage
    AntiAFKStatus.LocalPlayer = AntiAFKStatus.Players.LocalPlayer
    
    local success, result = pcall(function()
        local remotes = AntiAFKStatus.ReplicatedStorage:WaitForChild("Remotes", 10)
        AntiAFKStatus.AFKRemote = remotes:WaitForChild("AFKRemote", 10)
        AntiAFKStatus.PlayerScripts = AntiAFKStatus.LocalPlayer:WaitForChild("PlayerScripts", 10)
        return true
    end)
    
    if not success then
        AntiAFKStatus.currentScriptName = "AFKRemote not found"
        updateAntiAFKLabel()
        notify("AntiAFK", "Failed to initialize: AFKRemote not found", true)
        return
    end
    
    AntiAFKStatus.Running = true
    AntiAFKStatus.foundAndDisabled = false
    AntiAFKStatus.currentScriptName = "Scanning..."
    updateAntiAFKLabel()
    
    -- Optimized check every 3 seconds
    AntiAFKStatus.checkConnection = task.spawn(function()
        while AntiAFKStatus.Running and AntiAFKStatus.Enabled and not AntiAFKStatus.foundAndDisabled do
            task.wait(3)  -- Check every 3 seconds, no FPS drop
            
            if AntiAFKStatus.foundAndDisabled then break end
            
            local candidateScript = nil
            
            -- Step 1: Check AFKRemote.OnClientEvent connections
            pcall(function()
                for _, conn in pairs(getconnections(AntiAFKStatus.AFKRemote.OnClientEvent)) do
                    if conn.Function and conn.Enabled then
                        local env = getfenv(conn.Function)
                        if env and env.script and env.script:IsA("LocalScript") and env.script.Parent == AntiAFKStatus.PlayerScripts then
                            candidateScript = env.script
                            break
                        end
                    end
                end
            end)
            
            -- Step 2: If candidate found, verify RenderStepped connection
            if candidateScript then
                AntiAFKStatus.currentScriptName = candidateScript.Name .. " (Checking)"
                updateAntiAFKLabel()
                
                local hasRenderStepped = false
                
                pcall(function()
                    for _, conn in pairs(getconnections(AntiAFKStatus.RunService.RenderStepped)) do
                        if conn.Function and getfenv(conn.Function).script == candidateScript then
                            hasRenderStepped = true
                            break
                        end
                    end
                end)
                
                if hasRenderStepped then
                    neutralizeAFKScript(candidateScript)
                else
                    AntiAFKStatus.currentScriptName = candidateScript.Name .. " (No RenderStepped)"
                    updateAntiAFKLabel()
                end
            else
                AntiAFKStatus.currentScriptName = "No AFK script found"
                updateAntiAFKLabel()
            end
        end
        
        -- Final state update
        if AntiAFKStatus.foundAndDisabled then
            AntiAFKStatus.currentScriptName = AntiAFKStatus.currentScriptName or "Neutralized"
            notify("AntiAFK", "AntiAFK monitoring completed successfully", false)
        else
            AntiAFKStatus.currentScriptName = "Monitoring stopped"
        end
        updateAntiAFKLabel()
    end)
    
    notify("AntiAFK", "AntiAFK started (checking every 3s)", true)
end

local function stopAntiAFK()
    AntiAFKStatus.Running = false
    AntiAFKStatus.foundAndDisabled = false
    
    if AntiAFKStatus.checkConnection then
        task.cancel(AntiAFKStatus.checkConnection)
        AntiAFKStatus.checkConnection = nil
    end
    
    AntiAFKStatus.currentScriptName = "Disabled"
    updateAntiAFKLabel()
    
    notify("AntiAFK", "AntiAFK stopped", true)
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
    
    InfStaminaStatus.GuiMainProtectionConnection = Services.RunService.Heartbeat:Connect(function()
        if not InfStaminaStatus.Enabled then return end
        InfStamina.ForceDisableGuiMain()
    end)
    
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
        
        UI.Sections.InfStamina:Toggle({
            Name = "Always Sprint",
            Default = MovementEnhancements.Config.InfStamina.AlwaysSprint,
            Callback = function(value)
                InfStamina.SetAlwaysSprint(value)
            end
        })
        
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

    -- AutoGKSelect Section
    if UI.Sections.AutoGKSelect then
        UI.Sections.AutoGKSelect:Header({ Name = "AutoGK Selector" })
        
        UI.Sections.AutoGKSelect:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.AutoGKSelect.Enabled,
            Callback = function(value)
                AutoGKStatus.Enabled = value
                MovementEnhancements.Config.AutoGKSelect.Enabled = value
                if value then 
                    startAutoGK()
                else 
                    stopAutoGK()
                end
            end
        })
        
        UI.Sections.AutoGKSelect:Button({
            Name = "Select GK Away",
            Callback = function()
                selectGKAway()
            end
        })
        
        UI.Sections.AutoGKSelect:Button({
            Name = "Select GK Home",
            Callback = function()
                selectGKHome()
            end
        })
    end

    -- AntiAFK Section
    if UI.Sections.AntiAFK then
        UI.Sections.AntiAFK:Header({ Name = "AntiAFK" })
        
        UI.Sections.AntiAFK:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.AntiAFK.Enabled,
            Callback = function(value)
                AntiAFKStatus.Enabled = value
                MovementEnhancements.Config.AntiAFK.Enabled = value
                if value then 
                    startAntiAFK()
                else 
                    stopAntiAFK()
                end
            end
        })
        
        -- Label for AntiAFK status
        AntiAFKStatus.label = UI.Sections.AntiAFK:Label({
            Text = "AntiAFK pointer: " .. AntiAFKStatus.currentScriptName
        })
    end

    -- JoinTeam Section
    if UI.Sections.JoinTeam then
        UI.Sections.JoinTeam:Header({ Name = "Team Joiner" })
        UI.Sections.JoinTeam:SubLabel({ Text = "bypasses limits, you can join a team with more people than the other"})
        -- Team count labels
        JoinTeamStatus.awayLabel = UI.Sections.JoinTeam:Label({
            Text = "Away Count: 0"
        })
        
        JoinTeamStatus.homeLabel = UI.Sections.JoinTeam:Label({
            Text = "Home Count: 0"
        })
        
        -- Buttons
        UI.Sections.JoinTeam:Button({
            Name = "Join Away",
            Callback = function()
                joinAwayTeam()
            end
        })
        
        UI.Sections.JoinTeam:Button({
            Name = "Join Home",
            Callback = function()
                joinHomeTeam()
            end
        })
        
        -- Start monitoring team counts
        startTeamMonitoring()
    end
end

-- Main Initialization
function MovementEnhancements.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer

    _G.setTimerSpeed = Timer.SetSpeed
    _G.setSpeed = Speed.SetSpeed
    _G.setInfStaminaSprintKey = InfStamina.SetSprintKey

    if LocalPlayerObj then
        local function handleCharacterChange()
            task.wait(0.5)
            
            if DisablerStatus.Enabled then
                Disabler.DisableSignals(LocalPlayerObj.Character)
            end
            if SpeedStatus.Enabled then
                Speed.Start()
            end
            if InfStaminaStatus.Enabled then
                task.wait(1)
                InfStamina.Start()
            end
            if AutoGKStatus.Enabled then
                startAutoGK()
            end
            if AntiAFKStatus.Enabled then
                startAntiAFK()
            end
        end
        
        LocalPlayerObj.CharacterAdded:Connect(handleCharacterChange)
        
        if LocalPlayerObj.Character then
            task.spawn(handleCharacterChange)
        end
    end

    SetupUI(UI)
end

function MovementEnhancements:Destroy()
    Timer.Stop()
    Disabler.Stop()
    Speed.Stop()
    InfStamina.Stop()
    stopAutoGK()
    stopAntiAFK()
    stopTeamMonitoring()
    
    notify("MovementEnhancements", "All modules stopped", true)
end

return MovementEnhancements
