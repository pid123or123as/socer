local AntiCheatRemover = {}
print('2')

-- ====================== CONFIG ======================
AntiCheatRemover.Config = {
    DevConsoleBypass = {
        Enabled = false,
        ToggleKey = nil,
        UseAlternativeMethod = false -- Флаг для альтернативного метода
    },
    BaseACBypass = {
        Enabled = false,
        ToggleKey = nil
    },
    MobileCameraACBypass = {
        Enabled = false,
        ToggleKey = nil,
        UseAlternativeMethod = false -- Флаг для альтернативного метода
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
    MethodUsed = nil -- Запоминаем какой метод сработал
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
    MethodUsed = nil -- Запоминаем какой метод сработал
}

-- ====================== SERVICES & HELPERS ======================
local Services = nil
local notify = nil
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ====================== ОБНОВЛЕНИЕ ЛЕЙБЛОВ ======================
local function updateDevConsoleLabel()
    if DevConsoleBypassStatus.label then
        DevConsoleBypassStatus.label:UpdateName("Status: " .. DevConsoleBypassStatus.Status .. " | Pointer: " .. DevConsoleBypassStatus.ScriptName .. (DevConsoleBypassStatus.MethodUsed and " (" .. DevConsoleBypassStatus.MethodUsed .. ")" or ""))
    end
end

local function updateBaseACLabel()
    if BaseACBypassStatus.label then
        BaseACBypassStatus.label:UpdateName("Status: " .. BaseACBypassStatus.Status .. " | Pointer: " .. BaseACBypassStatus.ScriptName)
    end
end

local function updateMobileCameraLabel()
    if MobileCameraACStatus.label then
        MobileCameraACStatus.label:UpdateName("Status: " .. MobileCameraACStatus.Status .. " | Pointer: " .. MobileCameraACStatus.ScriptName .. (MobileCameraACStatus.MethodUsed and " (" .. MobileCameraACStatus.MethodUsed .. ")" or ""))
    end
end

-- ====================== ОБЩИЕ ФУНКЦИИ НЕЙТРАЛИЗАЦИИ ======================
local function neutralizeScriptAdvanced(scriptObj, mainClosure)
    if not scriptObj or not mainClosure then return false end
    
    -- 1. Отключаем и уничтожаем скрипт
    pcall(function()
        scriptObj.Disabled = true
        scriptObj:Destroy()
    end)
    
    -- 2. Портим все константы
    if debug.getconstants then
        local constants = debug.getconstants(mainClosure)
        if constants then
            for i = 1, #constants do
                pcall(debug.setconstant, mainClosure, i, "CORRUPTED_" .. math.random(10000, 99999))
            end
        end
    end
    
    -- 3. Портим все protos
    if debug.getproto then
        for protoIndex = 1, 50 do
            local success, proto = pcall(debug.getproto, mainClosure, protoIndex)
            if not success or not proto then break end
            
            -- Портим константы proto
            if debug.getconstants then
                local protoConstants = debug.getconstants(proto)
                if protoConstants then
                    for i = 1, #protoConstants do
                        pcall(debug.setconstant, proto, i, "BROKEN_" .. math.random(1000, 9999))
                    end
                end
            end
            
            -- Портим upvalues proto
            if debug.setupvalue then
                for i = 1, 20 do
                    pcall(debug.setupvalue, proto, i, function() end)
                end
            end
        end
    end
    
    -- 4. Отключаем все connections
    if getconnections then
        -- Стандартные события
        local events = {
            Services.RunService.Heartbeat,
            Services.RunService.RenderStepped,
            Services.RunService.Stepped,
            scriptObj.AncestryChanged,
            scriptObj.Changed
        }
        
        for _, event in ipairs(events) do
            for _, conn in ipairs(getconnections(event)) do
                if conn.Function == mainClosure then
                    pcall(conn.Disable, conn)
                    pcall(conn.Disconnect, conn)
                end
            end
        end
    end
    
    -- 5. Портим метатаблицу
    pcall(function()
        local mt = getrawmetatable(scriptObj)
        if mt then
            mt.__index = nil
            mt.__newindex = function() end
            mt.__namecall = function() end
        end
    end)
    
    -- 6. Портим upvalues
    if debug.setupvalue then
        for i = 1, 20 do
            pcall(debug.setupvalue, mainClosure, i, function() end)
        end
    end
    
    return true
end

-- ====================== DevConsole: МЕТОД 1 (оригинальный) ======================
local function neutralizeDevConsoleMethod1(scriptObj, mainClosure)
    if not scriptObj or not mainClosure then return false end
    
    DevConsoleBypassStatus.FoundScript = scriptObj
    DevConsoleBypassStatus.ScriptName = scriptObj.Name
    DevConsoleBypassStatus.Status = "Neutralized"
    DevConsoleBypassStatus.MethodUsed = "Method1"
    updateDevConsoleLabel()
    
    neutralizeScriptAdvanced(scriptObj, mainClosure)
    notify("AntiCheatRemover", "DevConsole bypassed (Method1)", false)
    return true
end

-- ====================== DevConsole: МЕТОД 2 (альтернативный) ======================
local function neutralizeDevConsoleMethod2(scriptObj, mainClosure)
    if not scriptObj or not mainClosure then return false end
    
    DevConsoleBypassStatus.FoundScript = scriptObj
    DevConsoleBypassStatus.ScriptName = scriptObj.Name
    DevConsoleBypassStatus.Status = "Neutralized"
    DevConsoleBypassStatus.MethodUsed = "Method2"
    updateDevConsoleLabel()
    
    neutralizeScriptAdvanced(scriptObj, mainClosure)
    notify("AntiCheatRemover", "DevConsole bypassed (Method2)", false)
    return true
end

-- ====================== MobileCamera: МЕТОД 1 (оригинальный - 87 констант) ======================
local function neutralizeMobileCameraMethod1(scriptObj, mainClosure)
    if not scriptObj or not mainClosure then return false end
    
    MobileCameraACStatus.FoundScript = scriptObj
    MobileCameraACStatus.ScriptName = scriptObj.Name
    MobileCameraACStatus.Status = "Neutralized"
    MobileCameraACStatus.MethodUsed = "Method1"
    updateMobileCameraLabel()
    
    neutralizeScriptAdvanced(scriptObj, mainClosure)
    notify("AntiCheatRemover", "Character bypassed (Method1)", false)
    return true
end

-- ====================== MobileCamera: МЕТОД 2 (72 константы, 20 protos) ======================
local function neutralizeMobileCameraMethod2(scriptObj, mainClosure)
    if not scriptObj or not mainClosure then return false end
    
    MobileCameraACStatus.FoundScript = scriptObj
    MobileCameraACStatus.ScriptName = scriptObj.Name
    MobileCameraACStatus.Status = "Neutralized"
    MobileCameraACStatus.MethodUsed = "Method2"
    updateMobileCameraLabel()
    
    neutralizeScriptAdvanced(scriptObj, mainClosure)
    notify("AntiCheatRemover", "Character bypassed (Method2)", false)
    return true
end

-- ====================== SCAN FUNCTIONS ======================
-- DevConsole: Поиск только в PlayerGui
local function scanDevConsole()
    if not DevConsoleBypassStatus.Enabled or DevConsoleBypassStatus.Status == "Neutralized" then return false end
    
    DevConsoleBypassStatus.Status = "Scanning..."
    DevConsoleBypassStatus.ScriptName = "Searching..."
    updateDevConsoleLabel()
    
    -- МЕТОД 1: Оригинальный (28 констант)
    if not AntiCheatRemover.Config.DevConsoleBypass.UseAlternativeMethod then
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if not obj:IsA("LocalScript") then continue end
            
            local mainClosure = getscriptclosure and getscriptclosure(obj)
            if not mainClosure or not islclosure(mainClosure) then continue end
            
            local constants = debug.getconstants(mainClosure)
            if constants and #constants == 28 then
                DevConsoleBypassStatus.Status = "Found"
                updateDevConsoleLabel()
                neutralizeDevConsoleMethod1(obj, mainClosure)
                return true
            end
        end
    end
    
    -- Если метод 1 не сработал, переключаемся на метод 2
    AntiCheatRemover.Config.DevConsoleBypass.UseAlternativeMethod = true
    
    -- МЕТОД 2: Поиск скриптов блокирующих DeveloperConsole
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if not obj:IsA("LocalScript") then continue end
        
        local mainClosure = getscriptclosure and getscriptclosure(obj)
        if not mainClosure then continue end
        
        local constants = debug.getconstants(mainClosure)
        if constants then
            -- Ищем ключевые слова
            for _, const in ipairs(constants) do
                if type(const) == "string" and (const:find("CoreGui") or const:find("DevConsole") or const:find("DeveloperConsole")) then
                    DevConsoleBypassStatus.Status = "Found"
                    updateDevConsoleLabel()
                    neutralizeDevConsoleMethod2(obj, mainClosure)
                    return true
                end
            end
        end
    end
    
    return false
end

-- MobileCamera: Поиск в персонаже
local function scanMobileCamera()
    if not MobileCameraACStatus.Enabled or MobileCameraACStatus.Status == "Neutralized" then return false end
    
    MobileCameraACStatus.Status = "Scanning..."
    MobileCameraACStatus.ScriptName = "Searching..."
    updateMobileCameraLabel()
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    -- МЕТОД 1: Оригинальный (87 констант)
    if not AntiCheatRemover.Config.MobileCameraACBypass.UseAlternativeMethod then
        for _, obj in ipairs(character:GetDescendants()) do
            if not obj:IsA("LocalScript") then continue end
            
            local mainClosure = getscriptclosure and getscriptclosure(obj)
            if not mainClosure then continue end
            
            local constants = debug.getconstants(mainClosure)
            if constants and #constants == 87 then
                MobileCameraACStatus.Status = "Found"
                updateMobileCameraLabel()
                neutralizeMobileCameraMethod1(obj, mainClosure)
                return true
            end
        end
    end
    
    -- Если метод 1 не сработал, переключаемся на метод 2
    AntiCheatRemover.Config.MobileCameraACBypass.UseAlternativeMethod = true
    
    -- МЕТОД 2: Поиск по сигнатуре (72 константы, проверка protos)
    for _, obj in ipairs(character:GetDescendants()) do
        if not obj:IsA("LocalScript") then continue end
        
        local mainClosure = getscriptclosure and getscriptclosure(obj)
        if not mainClosure then continue end
        
        local constants = debug.getconstants(mainClosure)
        if not constants or #constants ~= 72 then continue end
        
        -- Проверяем protos count (20)
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
            MobileCameraACStatus.Status = "Found"
            updateMobileCameraLabel()
            neutralizeMobileCameraMethod2(obj, mainClosure)
            return true
        end
    end
    
    return false
end

-- ====================== START/STOP FUNCTIONS ======================
local function startDevConsoleBypass()
    if DevConsoleBypassStatus.Running then return end
    DevConsoleBypassStatus.Running = true
    
    if DevConsoleBypassStatus.Connection then
        DevConsoleBypassStatus.Connection:Disconnect()
        DevConsoleBypassStatus.Connection = nil
    end
    
    -- Отслеживаем респавн
    DevConsoleBypassStatus.Connection = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2)
        if DevConsoleBypassStatus.Enabled then
            DevConsoleBypassStatus.FoundScript = nil
            DevConsoleBypassStatus.Status = "Scanning..."
            DevConsoleBypassStatus.ScriptName = "None"
            updateDevConsoleLabel()
            scanDevConsole()
        end
    end)
    
    -- Первоначальный поиск
    scanDevConsole()
    
    -- Периодическая проверка
    while DevConsoleBypassStatus.Running do
        task.wait(3)
        if DevConsoleBypassStatus.Status ~= "Neutralized" then
            scanDevConsole()
        end
    end
end

local function stopDevConsoleBypass()
    DevConsoleBypassStatus.Running = false
    DevConsoleBypassStatus.Status = "Disabled"
    DevConsoleBypassStatus.ScriptName = "None"
    DevConsoleBypassStatus.MethodUsed = nil
    
    if DevConsoleBypassStatus.Connection then
        DevConsoleBypassStatus.Connection:Disconnect()
        DevConsoleBypassStatus.Connection = nil
    end
    
    updateDevConsoleLabel()
end

local function startMobileCameraBypass()
    if MobileCameraACStatus.Running then return end
    MobileCameraACStatus.Running = true
    
    -- Первоначальный поиск
    scanMobileCamera()
    
    -- Отслеживаем респавн
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2)
        if MobileCameraACStatus.Enabled then
            MobileCameraACStatus.FoundScript = nil
            MobileCameraACStatus.Status = "Scanning..."
            MobileCameraACStatus.ScriptName = "None"
            MobileCameraACStatus.MethodUsed = nil
            updateMobileCameraLabel()
            scanMobileCamera()
        end
    end)
    
    -- Периодическая проверка
    while MobileCameraACStatus.Running do
        task.wait(3)
        if MobileCameraACStatus.Status ~= "Neutralized" then
            scanMobileCamera()
        end
    end
end

local function stopMobileCameraBypass()
    MobileCameraACStatus.Running = false
    MobileCameraACStatus.Status = "Disabled"
    MobileCameraACStatus.ScriptName = "None"
    MobileCameraACStatus.MethodUsed = nil
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
end

function AntiCheatRemover:Destroy()
    stopDevConsoleBypass()
    stopBaseACBypass()
    stopMobileCameraBypass()
    notify("AntiCheatRemover", "Module unloaded and bypasses stopped", true)
end

return AntiCheatRemover
