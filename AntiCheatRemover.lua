local AntiCheatRemover = {}
print('3')

-- ====================== CONFIG ======================
AntiCheatRemover.Config = {
    DevConsoleBypass = {
        Enabled = false,
        ToggleKey = nil
    },
    BaseACBypass = {
        Enabled = false,
        ToggleKey = nil
    },
    MobileCameraACBypass = {
        Enabled = false,
        ToggleKey = nil
    }
}

-- ====================== STATUS TABLES ======================
local DevConsoleBypassStatus = {
    Running = false,
    Enabled = AntiCheatRemover.Config.DevConsoleBypass.Enabled,
    Status = "Disabled",
    ScriptName = "None",
    FoundScript = nil,
    label = nil
}

local BaseACBypassStatus = {
    Running = false,
    Enabled = AntiCheatRemover.Config.BaseACBypass.Enabled,
    Status = "Disabled",
    ScriptName = "None",
    FoundScript = nil,
    label = nil
}

local MobileCameraACStatus = {
    Running = false,
    Enabled = AntiCheatRemover.Config.MobileCameraACBypass.Enabled,
    Status = "Disabled",
    ScriptName = "None",
    FoundScript = nil,
    label = nil
}

-- ====================== SERVICES & HELPERS ======================
local Services = nil
local notify = nil
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function updateDevConsoleLabel()
    if DevConsoleBypassStatus.label then
        DevConsoleBypassStatus.label:UpdateName("Status: " .. DevConsoleBypassStatus.Status .. " | Pointer: " .. DevConsoleBypassStatus.ScriptName)
    end
end

local function updateBaseACLabel()
    if BaseACBypassStatus.label then
        BaseACBypassStatus.label:UpdateName("Status: " .. BaseACBypassStatus.Status .. " | Pointer: " .. BaseACBypassStatus.ScriptName)
    end
end

local function updateMobileCameraLabel()
    if MobileCameraACStatus.label then
        MobileCameraACStatus.label:UpdateName("Status: " .. MobileCameraACStatus.Status .. " | Pointer: " .. MobileCameraACStatus.ScriptName)
    end
end

-- ====================== NEUTRALIZE FUNCTIONS ======================
local function neutralizeCoreGuiSetter(scriptObj, mainClosure)
    if not scriptObj or not mainClosure or not scriptObj.Parent then return false end

    DevConsoleBypassStatus.FoundScript = scriptObj
    DevConsoleBypassStatus.ScriptName = scriptObj.Name
    DevConsoleBypassStatus.Status = "Neutralized"
    updateDevConsoleLabel()

    pcall(function()
        scriptObj.Disabled = true
    end)

    local constants = debug.getconstants(mainClosure)
    if constants and #constants == 28 then
        for i = 1, 28 do
            pcall(debug.setconstant, mainClosure, i, "broken_" .. math.random(1000, 9999))
        end
    end

    if getconnections and Services.RunService then
        local events = {Services.RunService.Heartbeat, Services.RunService.RenderStepped, Services.RunService.Stepped}
        for _, event in ipairs(events) do
            for _, conn in ipairs(getconnections(event)) do
                if conn.Function == mainClosure then
                    pcall(conn.Disable, conn)
                    pcall(conn.Disconnect, conn)
                end
            end
        end
    end

    notify("AntiCheatRemover", "DevConsole unlocked", false)
    return true
end

local function neutralizeAdvertisementHandler(scriptObj, mainClosure)
    if not scriptObj or not mainClosure or not scriptObj.Parent then return false end

    BaseACBypassStatus.FoundScript = scriptObj
    BaseACBypassStatus.ScriptName = scriptObj.Name
    BaseACBypassStatus.Status = "Neutralized"
    updateBaseACLabel()

    local constants = debug.getconstants(mainClosure)
    if constants and #constants == 35 then
        pcall(debug.setconstant, mainClosure, 3, nil)
        pcall(debug.setconstant, mainClosure, 5, nil)
        pcall(debug.setconstant, mainClosure, 6, "FakeService")
        pcall(debug.setconstant, mainClosure, 13, nil)
        pcall(debug.setconstant, mainClosure, 14, nil)
        pcall(debug.setconstant, mainClosure, 16, nil)
        pcall(debug.setconstant, mainClosure, 19, nil)
        pcall(debug.setconstant, mainClosure, 22, nil)
        pcall(debug.setconstant, mainClosure, 24, nil)
        pcall(debug.setconstant, mainClosure, 26, nil)
        pcall(debug.setconstant, mainClosure, 30, nil)
        pcall(debug.setconstant, mainClosure, 31, nil)
        pcall(debug.setconstant, mainClosure, 35, nil)

        for i = 1, 35 do
            pcall(debug.setconstant, mainClosure, i, string.char(math.random(65, 90)) .. math.random(1, 9999))
        end
    end

    if getconnections and Services.RunService then
        local events = {Services.RunService.Heartbeat, Services.RunService.RenderStepped, Services.RunService.Stepped}
        for _, event in ipairs(events) do
            for _, conn in ipairs(getconnections(event)) do
                if conn.Function == mainClosure then
                    pcall(conn.Disable, conn)
                    pcall(conn.Disconnect, conn)
                end
            end
        end
    end

    if debug.setupvalue then
        for i = 1, 10 do
            pcall(debug.setupvalue, mainClosure, i, function() end)
        end
    end

    pcall(function()
        local mt = getrawmetatable(scriptObj)
        if mt then
            mt.__index = nil
            mt.__newindex = function() end
        end
    end)

    notify("AntiCheatRemover", "Base AC broken", false)
    return true
end

local function neutralizeMobileCameraAC(scriptObj, mainClosure)
    if not scriptObj or not mainClosure then return false end

    MobileCameraACStatus.FoundScript = scriptObj
    MobileCameraACStatus.ScriptName = scriptObj.Name
    MobileCameraACStatus.Status = "Neutralized"
    updateMobileCameraLabel()

    local constants = debug.getconstants(mainClosure)
    if #constants == 87 then
        -- Двойная полная порча всех констант
        for i = 1, 87 do
            pcall(debug.setconstant, mainClosure, i, string.char(math.random(65, 90)) .. math.random(10000, 99999))
        end
        task.wait()
        for i = 1, 87 do
            pcall(debug.setconstant, mainClosure, i, math.random(-999999, 999999))
        end
    end

    -- setupvalue на пустую
    if debug.setupvalue then
        for i = 1, 20 do
            pcall(debug.setupvalue, mainClosure, i, function() end)
        end
    end

    -- Порча метатаблицы
    pcall(function()
        local mt = getrawmetatable(scriptObj)
        if mt then
            mt.__index = nil
            mt.__newindex = function() end
            mt.__namecall = function() end
        end
    end)

    -- Отписка от соединений (оптимизировано)
    if getconnections then
        local events = {Services.RunService.Heartbeat, Services.RunService.RenderStepped, Services.RunService.Stepped}
        for _, event in ipairs(events) do
            for _, conn in ipairs(getconnections(event)) do
                if conn.Function == mainClosure then
                    pcall(conn.Disable, conn)
                    pcall(conn.Disconnect, conn)
                end
            end
        end

        local character = scriptObj.Parent
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        local signals = {}
        if hrp then
            table.insert(signals, hrp:GetPropertyChangedSignal("CFrame"))
            table.insert(signals, hrp:GetPropertyChangedSignal("Velocity"))
        end
        if humanoid then
            table.insert(signals, humanoid:GetPropertyChangedSignal("WalkSpeed"))
        end
        for _, sig in ipairs(signals) do
            for _, conn in ipairs(getconnections(sig)) do
                if conn.Function == mainClosure then
                    pcall(conn.Disable, conn)
                    pcall(conn.Disconnect, conn)
                end
            end
        end
    end

    notify("AntiCheatRemover", "MobileCamera AC broken", false)
    return true
end

-- ====================== SCAN FUNCTIONS ======================
local function scanCoreGuiSetter()
    if not DevConsoleBypassStatus.Enabled or DevConsoleBypassStatus.Status == "Neutralized" then return end

    DevConsoleBypassStatus.Status = "Scanning..."
    DevConsoleBypassStatus.ScriptName = "Searching..."
    updateDevConsoleLabel()

    for _, obj in ipairs(game:GetDescendants()) do
        if not obj:IsA("LocalScript") then continue end
        local mainClosure = nil
        if getscriptclosure then
            local success, closure = pcall(getscriptclosure, obj)
            if success and closure then mainClosure = closure end
        end
        if not mainClosure and getclosure then
            local success, closure = pcall(getclosure, obj)
            if success and closure then mainClosure = closure end
        end
        if not mainClosure or not islclosure(mainClosure) then continue end
        local upvalues = debug.getupvalues(mainClosure)
        if not upvalues or #upvalues ~= 0 then continue end
        local constants = debug.getconstants(mainClosure)
        if constants and #constants == 28 then
            DevConsoleBypassStatus.Status = "Found"
            updateDevConsoleLabel()
            neutralizeCoreGuiSetter(obj, mainClosure)
            return
        end
    end
end

local function scanAdvertisementHandler()
    if not BaseACBypassStatus.Enabled or BaseACBypassStatus.Status == "Neutralized" then return end

    BaseACBypassStatus.Status = "Scanning..."
    BaseACBypassStatus.ScriptName = "Searching..."
    updateBaseACLabel()

    local replicatedFirst = game:GetService("ReplicatedFirst")
    if not replicatedFirst then return end

    for _, obj in ipairs(replicatedFirst:GetChildren()) do
        if not obj:IsA("LocalScript") then continue end
        local mainClosure = nil
        if getscriptclosure then
            local success, closure = pcall(getscriptclosure, obj)
            if success and closure then mainClosure = closure end
        end
        if not mainClosure and getclosure then
            local success, closure = pcall(getclosure, obj)
            if success and closure then mainClosure = closure end
        end
        if not mainClosure or not islclosure(mainClosure) then continue end
        local upvalues = debug.getupvalues(mainClosure)
        if not upvalues or #upvalues ~= 0 then continue end
        local constants = debug.getconstants(mainClosure)
        if constants and #constants == 35 then
            BaseACBypassStatus.Status = "Found"
            updateBaseACLabel()
            neutralizeAdvertisementHandler(obj, mainClosure)
            return
        end
    end
end

local function scanMobileCameraAC()
    if not MobileCameraACStatus.Enabled then return end

    MobileCameraACStatus.Status = "Scanning..."
    MobileCameraACStatus.ScriptName = "Searching..."
    updateMobileCameraLabel()

    local character = LocalPlayer.Character
    if not character then return end

    for _, child in ipairs(character:GetChildren()) do
        if not child:IsA("LocalScript") then continue end

        local mainClosure = nil
        if getscriptclosure then
            local success, closure = pcall(getscriptclosure, child)
            if success and closure then mainClosure = closure end
        end
        if not mainClosure and getclosure then
            local success, closure = pcall(getclosure, child)
            if success and closure then mainClosure = closure end
        end

        if not mainClosure or not islclosure(mainClosure) then continue end

        local constants = debug.getconstants(mainClosure)
        if #constants == 87 then
            MobileCameraACStatus.Status = "Found"
            updateMobileCameraLabel()
            neutralizeMobileCameraAC(child, mainClosure)
            return
        end
    end
end

-- ====================== START/STOP ======================
local function startDevConsoleBypass()
    if DevConsoleBypassStatus.Running then return end
    DevConsoleBypassStatus.Running = true
    scanCoreGuiSetter()
    task.delay(1, scanCoreGuiSetter)
end

local function stopDevConsoleBypass()
    DevConsoleBypassStatus.Running = false
    DevConsoleBypassStatus.Status = "Disabled"
    DevConsoleBypassStatus.ScriptName = "None"
    updateDevConsoleLabel()
end

local function startBaseACBypass()
    if BaseACBypassStatus.Running then return end
    BaseACBypassStatus.Running = true
    scanAdvertisementHandler()
    task.delay(0.5, scanAdvertisementHandler)
end

local function stopBaseACBypass()
    BaseACBypassStatus.Running = false
    BaseACBypassStatus.Status = "Disabled"
    BaseACBypassStatus.ScriptName = "None"
    updateBaseACLabel()
end

local function startMobileCameraBypass()
    if MobileCameraACStatus.Running then return end
    MobileCameraACStatus.Running = true
    scanMobileCameraAC()

    -- Ломаем при респавне
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        scanMobileCameraAC()
        task.delay(3, scanMobileCameraAC)
    end)
end

local function stopMobileCameraBypass()
    MobileCameraACStatus.Running = false
    MobileCameraACStatus.Status = "Disabled"
    MobileCameraACStatus.ScriptName = "None"
    updateMobileCameraLabel()
end

-- ====================== UI SETUP ======================
local function SetupUI(UI)
    if UI.Sections.AntiCheatRemover then
        UI.Sections.AntiCheatRemover:Header({ Name = "AntiCheat Remover" })

        UI.Sections.AntiCheatRemover:Toggle({
            Name = "Bypass DevConsole",
            Default = AntiCheatRemover.Config.DevConsoleBypass.Enabled,
            Callback = function(value)
                AntiCheatRemover.Config.DevConsoleBypass.Enabled = value
                DevConsoleBypassStatus.Enabled = value
                if value then
                    startDevConsoleBypass()
                else
                    stopDevConsoleBypass()
                end
            end
        }, 'BypassDevConsole')

        DevConsoleBypassStatus.label = UI.Sections.AntiCheatRemover:SubLabel({
            Text = "Status: " .. DevConsoleBypassStatus.Status .. " | Pointer: " .. DevConsoleBypassStatus.ScriptName
        })

        UI.Sections.AntiCheatRemover:Toggle({
            Name = "Bypass BaseAC",
            Default = AntiCheatRemover.Config.BaseACBypass.Enabled,
            Callback = function(value)
                AntiCheatRemover.Config.BaseACBypass.Enabled = value
                BaseACBypassStatus.Enabled = value
                if value then
                    startBaseACBypass()
                else
                    stopBaseACBypass()
                end
            end
        }, 'BypassBaseAC')

        BaseACBypassStatus.label = UI.Sections.AntiCheatRemover:SubLabel({
            Text = "Status: " .. BaseACBypassStatus.Status .. " | Pointer: " .. BaseACBypassStatus.ScriptName
        })

        UI.Sections.AntiCheatRemover:Toggle({
            Name = "Bypass Character",
            Default = AntiCheatRemover.Config.MobileCameraACBypass.Enabled,
            Callback = function(value)
                AntiCheatRemover.Config.MobileCameraACBypass.Enabled = value
                MobileCameraACStatus.Enabled = value
                if value then
                    startMobileCameraBypass()
                else
                    stopMobileCameraBypass()
                end
            end
        }, 'BypassMobileCameraAC')

        MobileCameraACStatus.label = UI.Sections.AntiCheatRemover:SubLabel({
            Text = "Status: " .. MobileCameraACStatus.Status .. " | Pointer: " .. MobileCameraACStatus.ScriptName
        })
    end
end

-- ====================== INIT & DESTROY ======================
function AntiCheatRemover.Init(UI, coreParam, notifyFunc)
    Services = coreParam.Services
    notify = notifyFunc

    SetupUI(UI)

    if AntiCheatRemover.Config.DevConsoleBypass.Enabled then
        startDevConsoleBypass()
    end
    if AntiCheatRemover.Config.BaseACBypass.Enabled then
        startBaseACBypass()
    end
    if AntiCheatRemover.Config.MobileCameraACBypass.Enabled then
        startMobileCameraBypass()
    end

    -- Для DevConsole — ломать при респавне (как ты просил)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if AntiCheatRemover.Config.DevConsoleBypass.Enabled then
            scanCoreGuiSetter()
        end
    end)
end

function AntiCheatRemover:Destroy()
    stopDevConsoleBypass()
    stopBaseACBypass()
    stopMobileCameraBypass()
    notify("AntiCheatRemover", "Module unloaded and bypasses stopped", true)
end

return AntiCheatRemover
