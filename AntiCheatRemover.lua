local AntiCheatRemover = {}
print('2')

-- ====================== CONFIG ======================
AntiCheatRemover.Config = {
    DevConsoleBypass = {
        Enabled = false,
        ToggleKey = nil,
        UseAlternativeMethod = false
    },
    BaseACBypass = {
        Enabled = false,
        ToggleKey = nil
    },
    MobileCameraACBypass = {
        Enabled = false,
        ToggleKey = nil,
        UseAlternativeMethod = false
    }
}

-- ====================== STATUS TABLES ======================
local DevConsoleBypassStatus = {
    Running = false,
    Enabled = AntiCheatRemover.Config.DevConsoleBypass.Enabled,
    Status = "Disabled",
    ScriptName = "None",
    FoundScript = nil,
    label = nil,
    Connection = nil,
    MethodUsed = 1  -- 1 = основной метод, 2 = альтернативный
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
    label = nil,
    MethodUsed = 1  -- 1 = основной (87 констант), 2 = альтернативный (72 константы + 20 protos)
}

-- ====================== SERVICES & HELPERS ======================
local Services = nil
local notify = nil
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ====================== ОБНОВЛЕНИЕ UI ======================
local function updateDevConsoleLabel()
    if DevConsoleBypassStatus.label then
        local methodText = DevConsoleBypassStatus.MethodUsed == 2 and " [M2]" or ""
        DevConsoleBypassStatus.label:UpdateName("Status: " .. DevConsoleBypassStatus.Status .. " | Pointer: " .. DevConsoleBypassStatus.ScriptName .. methodText)
    end
end

local function updateBaseACLabel()
    if BaseACBypassStatus.label then
        BaseACBypassStatus.label:UpdateName("Status: " .. BaseACBypassStatus.Status .. " | Pointer: " .. BaseACBypassStatus.ScriptName)
    end
end

local function updateMobileCameraLabel()
    if MobileCameraACStatus.label then
        local methodText = MobileCameraACStatus.MethodUsed == 2 and " [M2]" or ""
        MobileCameraACStatus.label:UpdateName("Status: " .. MobileCameraACStatus.Status .. " | Pointer: " .. MobileCameraACStatus.ScriptName .. methodText)
    end
end

-- ====================== NEUTRALIZE FUNCTIONS ======================
local function neutralizeCoreGuiSetter(scriptObj, mainClosure, method)
    if not scriptObj or not mainClosure or not scriptObj.Parent then return false end

    DevConsoleBypassStatus.FoundScript = scriptObj
    DevConsoleBypassStatus.ScriptName = scriptObj.Name
    DevConsoleBypassStatus.Status = "Neutralized"
    DevConsoleBypassStatus.MethodUsed = method or 1
    updateDevConsoleLabel()

    -- Полная деактивация скрипта
    pcall(function()
        scriptObj.Disabled = true
        scriptObj:Destroy()
    end)

    -- Порча всех констант
    local constants = debug.getconstants(mainClosure)
    if constants then
        for i = 1, #constants do
            pcall(debug.setconstant, mainClosure, i, "DC_BROKEN_" .. math.random(10000, 99999))
        end
    end

    -- Отключение всех соединений
    if getconnections then
        local events = {game:GetService("RunService").Heartbeat, game:GetService("RunService").RenderStepped, game:GetService("RunService").Stepped}
        for _, event in ipairs(events) do
            for _, conn in ipairs(getconnections(event)) do
                if conn.Function == mainClosure then
                    pcall(conn.Disable, conn)
                    pcall(conn.Disconnect, conn)
                end
            end
        end
    end

    notify("AntiCheatRemover", "DevConsole bypassed [M" .. (method or 1) .. "]", false)
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
        for i = 1, #constants do
            pcall(debug.setconstant, mainClosure, i, "BASE_BROKEN_" .. math.random(10000, 99999))
        end
    end

    if getconnections then
        local events = {game:GetService("RunService").Heartbeat, game:GetService("RunService").RenderStepped, game:GetService("RunService").Stepped}
        for _, event in ipairs(events) do
            for _, conn in ipairs(getconnections(event)) do
                if conn.Function == mainClosure then
                    pcall(conn.Disable, conn)
                    pcall(conn.Disconnect, conn)
                end
            end
        end
    end

    notify("AntiCheatRemover", "Base AC broken", false)
    return true
end

local function neutralizeMobileCameraAC(scriptObj, mainClosure, method)
    if not scriptObj or not mainClosure then return false end

    MobileCameraACStatus.FoundScript = scriptObj
    MobileCameraACStatus.ScriptName = scriptObj.Name
    MobileCameraACStatus.Status = "Neutralized"
    MobileCameraACStatus.MethodUsed = method or 1
    updateMobileCameraLabel()

    -- 1. Порча всех констант
    local constants = debug.getconstants(mainClosure)
    if constants then
        for i = 1, #constants do
            pcall(debug.setconstant, mainClosure, i, "MC_BROKEN_" .. math.random(10000, 99999))
        end
    end

    -- 2. Порча всех protos
    if debug.getproto then
        for protoIndex = 1, 30 do
            local success, proto = pcall(debug.getproto, mainClosure, protoIndex)
            if not success or not proto then break end
            
            local protoConstants = debug.getconstants(proto)
            if protoConstants then
                for i = 1, #protoConstants do
                    pcall(debug.setconstant, proto, i, "PROTO_BROKEN_" .. math.random(1000, 9999))
                end
            end
        end
    end

    -- 3. Удаление всех connections
    if getconnections then
        -- Удаляем connections из RunService
        local runService = game:GetService("RunService")
        local events = {runService.Heartbeat, runService.RenderStepped, runService.Stepped}
        
        for _, event in ipairs(events) do
            for _, conn in ipairs(getconnections(event)) do
                if conn.Function == mainClosure then
                    pcall(conn.Disable, conn)
                    pcall(conn.Disconnect, conn)
                end
            end
        end

        -- Удаляем connections из Humanoid
        local character = scriptObj.Parent
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                for _, conn in ipairs(getconnections(humanoid:GetPropertyChangedSignal("WalkSpeed"))) do
                    if conn.Function == mainClosure then
                        pcall(conn.Disable, conn)
                        pcall(conn.Disconnect, conn)
                    end
                end
                
                for _, conn in ipairs(getconnections(humanoid:GetPropertyChangedSignal("JumpPower"))) do
                    if conn.Function == mainClosure then
                        pcall(conn.Disable, conn)
                        pcall(conn.Disconnect, conn)
                    end
                end
            end

            -- Удаляем connections из HRP
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, conn in ipairs(getconnections(hrp:GetPropertyChangedSignal("CFrame"))) do
                    if conn.Function == mainClosure then
                        pcall(conn.Disable, conn)
                        pcall(conn.Disconnect, conn)
                    end
                end
                
                for _, conn in ipairs(getconnections(hrp:GetPropertyChangedSignal("Velocity"))) do
                    if conn.Function == mainClosure then
                        pcall(conn.Disable, conn)
                        pcall(conn.Disconnect, conn)
                    end
                end
            end
        end
    end

    -- 4. Деактивация и уничтожение скрипта
    pcall(function()
        scriptObj.Disabled = true
        scriptObj:Destroy()
    end)

    notify("AntiCheatRemover", "Character bypassed [M" .. (method or 1) .. "]", false)
    return true
end

-- ====================== SCAN FUNCTIONS ======================
-- DEV CONSOLE: Метод 1 (28 констант)
local function scanCoreGuiSetterMethod1()
    if not DevConsoleBypassStatus.Enabled or DevConsoleBypassStatus.Status == "Neutralized" then return false end

    DevConsoleBypassStatus.Status = "Scanning [M1]..."
    DevConsoleBypassStatus.ScriptName = "Searching..."
    updateDevConsoleLabel()

    -- Ищем ТОЛЬКО в PlayerGui
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if not obj:IsA("LocalScript") then continue end
        
        local mainClosure = getscriptclosure and getscriptclosure(obj)
        if not mainClosure or not islclosure(mainClosure) then continue end
        
        local upvalues = debug.getupvalues(mainClosure)
        if upvalues and #upvalues ~= 0 then continue end
        
        local constants = debug.getconstants(mainClosure)
        if constants and #constants == 28 then
            DevConsoleBypassStatus.Status = "Found [M1]"
            updateDevConsoleLabel()
            neutralizeCoreGuiSetter(obj, mainClosure, 1)
            return true
        end
    end
    
    return false
end

-- DEV CONSOLE: Метод 2 (альтернативный поиск в PlayerGui)
local function scanCoreGuiSetterMethod2()
    if not DevConsoleBypassStatus.Enabled or DevConsoleBypassStatus.Status == "Neutralized" then return false end

    DevConsoleBypassStatus.Status = "Scanning [M2]..."
    DevConsoleBypassStatus.ScriptName = "Searching..."
    updateDevConsoleLabel()

    -- Ищем любой LocalScript в PlayerGui, который работает с CoreGui
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if not obj:IsA("LocalScript") then continue end
        
        local mainClosure = getscriptclosure and getscriptclosure(obj)
        if not mainClosure then continue end
        
        local constants = debug.getconstants(mainClosure)
        if constants then
            -- Проверяем, содержит ли скрипт ключевые слова
            for _, const in ipairs(constants) do
                if type(const) == "string" and (const:find("CoreGui") or const:find("DeveloperConsole") or const:find("DevConsole")) then
                    DevConsoleBypassStatus.Status = "Found [M2]"
                    updateDevConsoleLabel()
                    neutralizeCoreGuiSetter(obj, mainClosure, 2)
                    return true
                end
            end
        end
    end
    
    return false
end

-- Общая функция сканирования DevConsole
local function scanCoreGuiSetter()
    if DevConsoleBypassStatus.MethodUsed == 1 then
        if scanCoreGuiSetterMethod1() then
            return true
        else
            DevConsoleBypassStatus.MethodUsed = 2
            return scanCoreGuiSetterMethod2()
        end
    else
        return scanCoreGuiSetterMethod2()
    end
end

-- MOBILE CAMERA: Метод 1 (87 констант)
local function scanMobileCameraACMethod1()
    if not MobileCameraACStatus.Enabled or MobileCameraACStatus.Status == "Neutralized" then return false end

    MobileCameraACStatus.Status = "Scanning [M1]..."
    MobileCameraACStatus.ScriptName = "Searching..."
    updateMobileCameraLabel()

    local character = LocalPlayer.Character
    if not character then return false end

    for _, child in ipairs(character:GetDescendants()) do
        if not child:IsA("LocalScript") then continue end

        local mainClosure = getscriptclosure and getscriptclosure(child)
        if not mainClosure or not islclosure(mainClosure) then continue end

        local constants = debug.getconstants(mainClosure)
        if constants and #constants == 87 then
            MobileCameraACStatus.Status = "Found [M1]"
            updateMobileCameraLabel()
            neutralizeMobileCameraAC(child, mainClosure, 1)
            return true
        end
    end
    
    return false
end

-- MOBILE CAMERA: Метод 2 (72 константы + 20 protos)
local function scanMobileCameraACMethod2()
    if not MobileCameraACStatus.Enabled or MobileCameraACStatus.Status == "Neutralized" then return false end

    MobileCameraACStatus.Status = "Scanning [M2]..."
    MobileCameraACStatus.ScriptName = "Searching..."
    updateMobileCameraLabel()

    local character = LocalPlayer.Character
    if not character then return false end

    for _, child in ipairs(character:GetDescendants()) do
        if not child:IsA("LocalScript") then continue end

        local mainClosure = getscriptclosure and getscriptclosure(child)
        if not mainClosure then continue end

        -- Проверяем константы (72)
        local constants = debug.getconstants(mainClosure)
        if not constants or #constants ~= 72 then continue end

        -- Проверяем protos (20) с обработкой ошибки
        local protoCount = 0
        if debug.getproto then
            for i = 1, 30 do
                local success, proto = pcall(debug.getproto, mainClosure, i)
                if not success or not proto then break end
                protoCount = protoCount + 1
                if protoCount > 20 then break end
            end
        end

        if protoCount == 20 then
            MobileCameraACStatus.Status = "Found [M2]"
            updateMobileCameraLabel()
            neutralizeMobileCameraAC(child, mainClosure, 2)
            return true
        end
    end
    
    return false
end

-- Общая функция сканирования Mobile Camera
local function scanMobileCameraAC()
    if MobileCameraACStatus.MethodUsed == 1 then
        if scanMobileCameraACMethod1() then
            return true
        else
            MobileCameraACStatus.MethodUsed = 2
            return scanMobileCameraACMethod2()
        end
    else
        return scanMobileCameraACMethod2()
    end
end

-- ====================== START/STOP FUNCTIONS ======================
local function startDevConsoleBypass()
    if DevConsoleBypassStatus.Running then return end
    DevConsoleBypassStatus.Running = true
    
    if DevConsoleBypassStatus.Connection then
        DevConsoleBypassStatus.Connection:Disconnect()
    end
    
    -- При респавне пробуем оба метода снова
    DevConsoleBypassStatus.Connection = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        if DevConsoleBypassStatus.Running then
            DevConsoleBypassStatus.MethodUsed = 1
            DevConsoleBypassStatus.FoundScript = nil
            DevConsoleBypassStatus.Status = "Scanning..."
            updateDevConsoleLabel()
            scanCoreGuiSetter()
        end
    end)
    
    scanCoreGuiSetter()
end

local function startMobileCameraBypass()
    if MobileCameraACStatus.Running then return end
    MobileCameraACStatus.Running = true
    
    scanMobileCameraAC()
    
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if MobileCameraACStatus.Running then
            MobileCameraACStatus.MethodUsed = 1
            MobileCameraACStatus.FoundScript = nil
            MobileCameraACStatus.Status = "Scanning..."
            updateMobileCameraLabel()
            scanMobileCameraAC()
        end
    end)
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
                    DevConsoleBypassStatus.Running = false
                    DevConsoleBypassStatus.Status = "Disabled"
                    updateDevConsoleLabel()
                end
            end
        }, 'BypassDevConsole')

        DevConsoleBypassStatus.label = UI.Sections.AntiCheatRemover:SubLabel({
            Text = "Status: " .. DevConsoleBypassStatus.Status .. " | Pointer: " .. DevConsoleBypassStatus.ScriptName
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
                    MobileCameraACStatus.Running = false
                    MobileCameraACStatus.Status = "Disabled"
                    updateMobileCameraLabel()
                end
            end
        }, 'BypassCharacter')

        MobileCameraACStatus.label = UI.Sections.AntiCheatRemover:SubLabel({
            Text = "Status: " .. MobileCameraACStatus.Status .. " | Pointer: " .. MobileCameraACStatus.ScriptName
        })
    end
end

-- ====================== INIT ======================
function AntiCheatRemover.Init(UI, coreParam, notifyFunc)
    Services = coreParam.Services
    notify = notifyFunc

    SetupUI(UI)

    if AntiCheatRemover.Config.DevConsoleBypass.Enabled then
        startDevConsoleBypass()
    end
    
    if AntiCheatRemover.Config.MobileCameraACBypass.Enabled then
        startMobileCameraBypass()
    end
end

return AntiCheatRemover
