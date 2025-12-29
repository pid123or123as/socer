local AntiCheatRemover = {}

-- ====================== CONFIG ======================
AntiCheatRemover.Config = {
    DevConsoleBypass = {
        Enabled = false,
        ToggleKey = nil
    },
    BaseACBypass = {
        Enabled = false,
        ToggleKey = nil
    }
}

-- ====================== STATUS TABLES ======================
local DevConsoleBypassStatus = {
    Running = false,
    Enabled = AntiCheatRemover.Config.DevConsoleBypass.Enabled,
    Status = "Disabled",             -- Disabled / Scanning... / Found / Neutralized
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

-- ====================== SERVICES & HELPERS ======================
local Services = nil
local notify = nil

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

-- ====================== NEUTRALIZE FUNCTIONS ======================
local function neutralizeCoreGuiSetter(scriptObj, mainClosure)
    if not scriptObj or not mainClosure then return false end

    DevConsoleBypassStatus.FoundScript = scriptObj
    DevConsoleBypassStatus.ScriptName = scriptObj.Name
    DevConsoleBypassStatus.Status = "Neutralized"
    updateDevConsoleLabel()

    local constants = debug.getconstants(mainClosure)
    if constants and #constants == 28 then
        for i = 1, 28 do
            local trash = "r" .. string.char(math.random(97, 122)) .. math.random(100, 999)
            pcall(debug.setconstant, mainClosure, i, trash)
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
    if not scriptObj or not mainClosure then return false end

    BaseACBypassStatus.FoundScript = scriptObj
    BaseACBypassStatus.ScriptName = scriptObj.Name
    BaseACBypassStatus.Status = "Neutralized"
    updateBaseACLabel()

    local constants = debug.getconstants(mainClosure)
    if constants and #constants == 35 then
        for i = 1, 35 do
            local trash = string.char(math.random(65, 90)) .. math.random(1000, 9999)
            pcall(debug.setconstant, mainClosure, i, trash)
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

    notify("AntiCheatRemover", "Removed", false)
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
    end
end

-- ====================== INIT & DESTROY ======================
function AntiCheatRemover.Init(UI, coreParam, notifyFunc)
    Services = coreParam.Services
    notify = notifyFunc

    SetupUI(UI)

    -- Автозапуск если в конфиге включено (опционально)
    if AntiCheatRemover.Config.DevConsoleBypass.Enabled then
        startDevConsoleBypass()
    end
    if AntiCheatRemover.Config.BaseACBypass.Enabled then
        startBaseACBypass()
    end
end

function AntiCheatRemover:Destroy()
    stopDevConsoleBypass()
    stopBaseACBypass()
    notify("AntiCheatRemover", "Module unloaded and bypasses stopped", true)
end

return AntiCheatRemover