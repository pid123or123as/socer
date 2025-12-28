-- [v35.43] AUTO SHOOT + AUTO PICKUP + FULL GUI + UI INTEGRATION (ПОЛНОСТЬЮ ИСПРАВЛЕННАЯ ВЕРСИЯ)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local BallAttachment = Character:WaitForChild("ball")
local Humanoid = Character:WaitForChild("Humanoid")

local Shooter = ReplicatedStorage.Remotes:WaitForChild("ShootTheBaII")
local PickupRemote
for _, r in ReplicatedStorage.Remotes:GetChildren() do
    if r:IsA("RemoteEvent") and r:GetAttribute("Attribute") then
        PickupRemote = r; break
    end
end

-- === АНИМАЦИЯ RShoot ===
local Animations = ReplicatedStorage:WaitForChild("Animations")
local RShootAnim = Humanoid:LoadAnimation(Animations:WaitForChild("RShoot"))
RShootAnim.Priority = Enum.AnimationPriority.Action4
local IsAnimating = false
local AnimationHoldTime = 0.6

-- === ПЕРЕМЕННЫЕ СОСТОЯНИЯ ===
local AutoShootEnabled = false
local AutoShootLegit = true
local AutoShootManualShot = true
local AutoShootShootKey = Enum.KeyCode.G
local AutoShootMaxDistance = 160
local AutoShootInset = 2
local AutoShootGravity = 110
local AutoShootMinPower = 4.0
local AutoShootMaxPower = 7.0
local AutoShootPowerPerStud = 0.025
local AutoShootMaxHeight = 100.0
local AutoShootDebugText = true
local AutoShootManualButton = false
local AutoShootButtonScale = 1.0

-- Параметры атак (БЕЗ ZOffset, с YReverse)
local Attacks = {
    SideRicochet = { Enabled = true, MinDist = 0, MaxDist = 60, Power = 3.5, XMult = 0.8, Spin = "None", HeightMult = 1.0, BaseHeightRange = {Min = 0.15, Max = 0.34}, DerivationMult = 0.0, YReverse = false },
    CloseSpin = { Enabled = true, MinDist = 0, MaxDist = 110, Power = 3.2, XMult = 1.1, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 0.3, Max = 0.9}, DerivationMult = 0.8, YReverse = false },
    SmartCorner = { Enabled = true, MinDist = 0, MaxDist = 100, PowerMin = 2.8, XMult = 0.3, Spin = "None", HeightMult = 0.82, BaseHeightRange = {Min = 0.5, Max = 0.7}, DerivationMult = 0.3, YReverse = false },
    SmartCandle = { Enabled = true, MinDist = 145, MaxDist = 180, Power = 3, XMult = 1.5, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 11, Max = 13}, DerivationMult = 2.8, YReverse = false },
    SmartRicochet = { Enabled = true, MinDist = 80, MaxDist = 140, Power = 3.6, XMult = 0.9, Spin = true, HeightMult = 0.7, BaseHeightRange = {Min = 0.95, Max = 1.5}, DerivationMult = 1.6, YReverse = false },
    SmartSpin = { Enabled = true, MinDist = 110, MaxDist = 155, PowerAdd = 0.6, XMult = 0.9, Spin = true, HeightMult = 0.75, BaseHeightRange = {Min = 0.7, Max = 1.5}, DerivationMult = 1.8, YReverse = false },
    SmartCandleMid = { Enabled = false, MinDist = 100, MaxDist = 165, PowerAdd = 0.4, XMult = 0.7, Spin = true, HeightMult = 0.9, BaseHeightRange = {Min = 0.15, Max = 0.55}, DerivationMult = 1.35, YReverse = false },
    FarSmartCandle = { Enabled = true, MinDist = 200, MaxDist = 300, Power = 60, XMult = 0.7, Spin = true, HeightMult = 1.8, BaseHeightRange = {Min = 40.0, Max = 80.0}, DerivationMult = 4.5, YReverse = false }
}

local AutoPickupEnabled = true
local AutoPickupDist = 180
local AutoPickupSpoofValue = 2.8

-- === STATUS ===
local AutoShootStatus = {
    Running = false,
    Connection = nil,
    RenderConnection = nil,
    Key = AutoShootShootKey,
    ManualShot = AutoShootManualShot,
    DebugText = AutoShootDebugText,
    ManualButton = AutoShootManualButton,
    ButtonScale = AutoShootButtonScale,
    InputConnection = nil,
    ButtonGui = nil,
    TouchStartTime = 0,
    Dragging = false,
    DragStart = Vector2.new(0, 0),
    StartPos = UDim2.new(0, 0, 0, 0)
}

local AutoPickupStatus = {
    Running = false,
    Connection = nil
}

-- === GUI (Drawing) ===
local Gui = nil
local function SetupGUI()
    Gui = {
        Status = Drawing.new("Text"), Dist = Drawing.new("Text"), Target = Drawing.new("Text"),
        Power = Drawing.new("Text"), Spin = Drawing.new("Text"), GK = Drawing.new("Text"),
        Debug = Drawing.new("Text"), Mode = Drawing.new("Text")
    }
    local s = Camera.ViewportSize
    local cx, y = s.X / 2, s.Y * 0.48
    for i, v in ipairs({Gui.Status, Gui.Dist, Gui.Target, Gui.Power, Gui.Spin, Gui.GK, Gui.Debug, Gui.Mode}) do
        v.Size = 18; v.Color = Color3.fromRGB(255, 255, 255); v.Outline = true; v.Center = true
        v.Position = Vector2.new(cx, y + (i-1)*20); v.Visible = AutoShootDebugText
    end
    Gui.Status.Text = "v35.43: Ready"
    Gui.Dist.Text = "Dist: --"; Gui.Target.Text = "Target: --"
    Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --"; Gui.GK.Text = "GK: --"
    Gui.Debug.Text = "Debug: Initializing"
    Gui.Mode.Text = "Mode: Manual (E)"
end

local function ToggleDebugText(value)
    if not Gui then return end
    for _, v in pairs(Gui) do
        v.Visible = value
    end
end

-- === 3D CUBES ===
local TargetCube, GoalCube, NoSpinCube = {}, {}, {}
local function InitializeCubes()
    for i = 1, 12 do
        if TargetCube[i] and TargetCube[i].Remove then TargetCube[i]:Remove() end
        if GoalCube[i] and GoalCube[i].Remove then GoalCube[i]:Remove() end
        if NoSpinCube[i] and NoSpinCube[i].Remove then NoSpinCube[i]:Remove() end
        TargetCube[i] = Drawing.new("Line")
        GoalCube[i] = Drawing.new("Line")
        NoSpinCube[i] = Drawing.new("Line")
    end
    local function SetupCube(cube, color, thickness)
        for _, line in ipairs(cube) do
            line.Color = color; line.Thickness = thickness or 2; line.Transparency = 0.7
            line.ZIndex = 1000; line.Visible = false
        end
    end
    SetupCube(TargetCube, Color3.fromRGB(0, 255, 0), 6)
    SetupCube(GoalCube, Color3.fromRGB(255, 0, 0), 4)
    SetupCube(NoSpinCube, Color3.fromRGB(0, 255, 255), 5)
end

local function DrawOrientedCube(cube, cframe, size)
    if not cframe or not size then
        for _, line in ipairs(cube) do line.Visible = false end
        return
    end
    pcall(function()
        local half = size / 2
        local corners = {
            cframe * Vector3.new(-half.X, -half.Y, -half.Z), cframe * Vector3.new(half.X, -half.Y, -half.Z),
            cframe * Vector3.new(half.X, half.Y, -half.Z), cframe * Vector3.new(-half.X, half.Y, -half.Z),
            cframe * Vector3.new(-half.X, -half.Y, half.Z), cframe * Vector3.new(half.X, -half.Y, half.Z),
            cframe * Vector3.new(half.X, half.Y, half.Z), cframe * Vector3.new(-half.X, half.Y, half.Z)
        }
        local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
        for i, edge in ipairs(edges) do
            local a, b = corners[edge[1]], corners[edge[2]]
            local aScreen, aVis = Camera:WorldToViewportPoint(a)
            local bScreen, bVis = Camera:WorldToViewportPoint(b)
            local line = cube[i]
            if aVis and bVis and aScreen.Z > 0 and bScreen.Z > 0 then
                line.From = Vector2.new(aScreen.X, aScreen.Y)
                line.To = Vector2.new(bScreen.X, bScreen.Y)
                line.Visible = true
            else
                line.Visible = false
            end
        end
    end)
end

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function GetKeyName(key)
    if key == Enum.KeyCode.Unknown then return "None" end
    local name = tostring(key):match("KeyCode%.(.+)") or tostring(key)
    local pretty = { LeftMouse = "LMB", RightMouse = "RMB", MiddleMouse = "MMB", Space = "Space", LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt", RightAlt = "RAlt" }
    return pretty[name] or name
end

local function UpdateModeText()
    if not Gui then return end
    Gui.Mode.Text = AutoShootManualShot and string.format("Mode: Manual (%s)", GetKeyName(AutoShootShootKey)) or "Mode: Auto"
end

local function GetMyTeam()
    local stats = Workspace:FindFirstChild("PlayerStats")
    if not stats then return nil, nil end
    if stats:FindFirstChild("Away") and stats.Away:FindFirstChild(LocalPlayer.Name) then return "Away", "HomeGoal"
    elseif stats:FindFirstChild("Home") and stats.Home:FindFirstChild(LocalPlayer.Name) then return "Home", "AwayGoal" end
    return nil, nil
end

local GoalCFrame, GoalWidth, GoalHeight
local function UpdateGoal()
    local myTeam, enemyGoalName = GetMyTeam()
    if not enemyGoalName then return nil, nil end
    
    local goalFolder = Workspace:FindFirstChild(enemyGoalName)
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
    GoalCFrame = CFrame.fromMatrix(center, rightDir, up, -forward)
    GoalWidth = (leftPost.Position - rightPost.Position).Magnitude
    GoalHeight = math.abs(crossbarPart.Position.Y - leftPost.Position.Y)
    
    return GoalWidth, GoalHeight
end

local function GetEnemyGoalie()
    local myTeam = GetMyTeam()
    if not myTeam then if Gui then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150) end; return nil, 0, 0, "None", false end
    local width = UpdateGoal()
    if not width then if Gui then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150) end; return nil, 0, 0, "None", false end
    local halfWidth = width / 2
    local goalies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team and player.Team.Name ~= myTeam then
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") and char.Humanoid.HipHeight >= 4 then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and GoalCFrame then
                    local distGoal = (hrp.Position - GoalCFrame.Position).Magnitude
                    local localX = GoalCFrame:PointToObjectSpace(hrp.Position).X
                    local localY = GoalCFrame:PointToObjectSpace(hrp.Position).Y
                    local isInGoal = distGoal < 18 and math.abs(localX) < halfWidth + 2
                    table.insert(goalies, { hrp=hrp, localX=localX, localY=localY, distGoal=distGoal, distPlayer=(hrp.Position - HumanoidRootPart.Position).Magnitude, name=player.Name, isInGoal=isInGoal })
                end
            end
        end
    end
    local goalieModelName = myTeam == "Away" and "HomeGoalie" or "Goalie"
    local goalieNPC = Workspace:FindFirstChild(goalieModelName)
    if goalieNPC and goalieNPC:FindFirstChild("HumanoidRootPart") then
        local hrp = goalieNPC.HumanoidRootPart
        local distGoal = (hrp.Position - GoalCFrame.Position).Magnitude
        local localX = GoalCFrame:PointToObjectSpace(hrp.Position).X
        local localY = GoalCFrame:PointToObjectSpace(hrp.Position).Y
        local isInGoal = distGoal < 18 and math.abs(localX) < halfWidth + 2
        table.insert(goalies, { hrp=hrp, localX=localX, localY=localY, distGoal=distGoal, distPlayer=(hrp.Position - HumanoidRootPart.Position).Magnitude, name="NPC", isInGoal=isInGoal })
    end
    if #goalies == 0 then if Gui then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150) end; return nil, 0, 0, "None", false end
    table.sort(goalies, function(a, b) if a.isInGoal ~= b.isInGoal then return a.isInGoal end; return a.distGoal < b.distGoal end)
    local best = goalies[1]
    local isAggressive = not best.isInGoal
    if Gui then
        Gui.GK.Text = string.format("GK: %s %s | X=%.1f, Y=%.1f", best.name, best.isInGoal and "(In Goal)" or "(Aggressive)", best.localX, best.localY)
        Gui.GK.Color = Color3.fromRGB(255, 200, 0)
    end
    return best.hrp, best.localX, best.localY, best.name, isAggressive
end

local function CalculateTrajectoryHeight(dist, power, attackName, isLowShot)
    local cfg = Attacks[attackName] or {}
    local baseHeightRange = cfg.BaseHeightRange or {Min = 0.15, Max = 0.45}
    local heightMult = cfg.HeightMult or 1.0
    local baseHeight
    
    if isLowShot then 
        baseHeight = 0.5
    elseif dist <= 80 then 
        baseHeight = math.clamp(baseHeightRange.Min + (dist / 400), baseHeightRange.Min, baseHeightRange.Max)
    elseif dist <= 100 then 
        baseHeight = math.clamp(baseHeightRange.Min + (dist / 200), baseHeightRange.Min, baseHeightRange.Max)
    elseif dist <= 140 then 
        baseHeight = math.clamp(baseHeightRange.Min + (dist / 80), baseHeightRange.Min, baseHeightRange.Max)
    else
        if attackName == "SmartCandle" then 
            baseHeight = math.clamp(8 + (dist / 25), baseHeightRange.Min, baseHeightRange.Max) * (dist >= 180 and 0.6 or 0.75)
        elseif attackName == "FarSmartCandle" then 
            baseHeight = math.clamp(40 + (dist / 5), baseHeightRange.Min, baseHeightRange.Max) * (dist >= 250 and 2.2 or 2.0)
        else 
            baseHeight = math.clamp(8 + (dist / 25), baseHeightRange.Min, baseHeightRange.Max) * 0.9 
        end
    end
    
    -- Применяем YReverse - увеличиваем высоту в 2 раза и инвертируем
    if cfg.YReverse then
        baseHeight = baseHeight * 2
        baseHeight = -baseHeight
    end
    
    local timeToTarget = dist / 200
    local gravityFall = attackName == "FarSmartCandle" and 10 or 0.5 * AutoShootGravity * timeToTarget^2
    
    -- Если YReverse включен, учитываем это при расчете итоговой высоты
    local height
    if cfg.YReverse then
        height = math.clamp(baseHeight - gravityFall, -AutoShootMaxHeight, isLowShot and -0.5 or -2.0)
    else
        height = math.clamp(baseHeight + gravityFall, isLowShot and 0.5 or 2.0, AutoShootMaxHeight)
    end
    
    if power < 1.5 and attackName ~= "FarSmartCandle" then 
        if cfg.YReverse then
            height = math.clamp(height * (power / 1.5), -AutoShootMaxHeight, height)
        else
            height = math.clamp(height * (power / 1.5), isLowShot and 0.5 or 2.0, height)
        end
    end
    
    if cfg.YReverse then
        height = math.clamp(height * heightMult, -AutoShootMaxHeight, -0.5)
    else
        height = math.clamp(height * heightMult, isLowShot and 0.5 or 2.0, AutoShootMaxHeight)
    end
    
    return height, timeToTarget, gravityFall, baseHeight
end

local TargetPoint, ShootDir, ShootVel, CurrentSpin, CurrentPower, CurrentType, NoSpinPoint
local LastShoot = 0
local CanShoot = true
local notify = function(title, text, success) 
    print("[" .. title .. "]: " .. text)
end

local function GetTarget(dist, goalieX, goalieY, isAggressive, goaliePos, playerAngle)
    if not GoalCFrame or not GoalWidth then return nil, "None", "None", 0 end
    if dist > AutoShootMaxDistance then return nil, "None", "None", 0 end
    local startPos = HumanoidRootPart.Position
    local halfWidth = (GoalWidth / 2) - AutoShootInset
    local halfHeight = (GoalHeight / 2) - AutoShootInset
    local targetSide = goalieX > 0 and -1 or 1
    local playerLocalX = GoalCFrame:PointToObjectSpace(startPos).X
    local isOffAngle = math.abs(playerAngle) > 30
    local isClose = dist < 30
    local isLowShot = (dist < 80 and math.random() < 0.3) or (isAggressive and goalieY > 3)
    local candidates = {}
    local ricochetPoints = {
        {x=halfWidth, y=halfHeight, normal=Vector3.new(-1, 0, 0), type="RightPost"},
        {x=-halfWidth, y=halfHeight, normal=Vector3.new(1, 0, 0), type="LeftPost"},
        {x=0, y=GoalHeight-0.5, normal=Vector3.new(0, -1, 0), type="Crossbar"},
        {x=halfWidth, y=0.5, normal=Vector3.new(-1, 0, 0), type="RightLower"},
        {x=-halfWidth, y=0.5, normal=Vector3.new(1, 0, 0), type="LeftLower"}
    }
    
    for name, cfg in pairs(Attacks) do
        if not cfg.Enabled or dist < cfg.MinDist or dist > math.min(cfg.MaxDist, AutoShootMaxDistance) then continue end
        local spin = cfg.Spin and (dist >= 110 or name == "CloseSpin") and (targetSide > 0 and "Right" or "Left") or "None"
        if name == "CloseSpin" and isOffAngle then spin = (playerLocalX > 0 and "Left" or "Right") end
        local xMult = cfg.XMult or 1
        local heightAdjust = 0
        
        if name == "CloseSpin" and isOffAngle then 
            heightAdjust = GoalHeight - 0.5
            xMult = 1.0 
        end
        
        if name == "CloseSpin" or name == "SmartCorner" then
            if (playerLocalX < 0 and targetSide < 0) or (playerLocalX > 0 and targetSide > 0) then 
                xMult = math.clamp(xMult * 0.7, 0.5, 0.8) 
            end
        end
        
        local targets = {{x=targetSide * halfWidth * xMult, y=0, type="Direct"}}
        if name == "CloseSpin" and isOffAngle then 
            targets = {{x=(playerLocalX > 0 and -halfWidth or halfWidth) * 0.95, y=GoalHeight - 0.5, type="Corner"}}
        elseif name == "SmartCorner" then 
            targets = ricochetPoints 
        end
        
        for _, target in ipairs(targets) do
            local x = target.x; local y = target.y; local targetType = target.type; local ricochetNormal = target.normal
            local randX = (name == "SideRicochet" or name == "CloseSpin" or name == "SmartCorner") and math.random(-0.15, 0.15) * halfWidth or 0
            local randY = (name == "SideRicochet" or name == "CloseSpin" or name == "SmartCorner") and math.random(-0.15, 0.15) * halfHeight or 0
            local power = cfg.Power or math.clamp(AutoShootMinPower + dist * AutoShootPowerPerStud, cfg.PowerMin or AutoShootMinPower, AutoShootMaxPower)
            power = power + (cfg.PowerAdd or 0)
            local derivation = 0
            
            if cfg.Spin and (dist >= 110 or name == "CloseSpin") then
                local derivationBase = (dist / 100)^1.5 * (cfg.DerivationMult or 1.3) * power
                if name == "CloseSpin" and isOffAngle then derivationBase = derivationBase * (math.abs(playerAngle) / 45) end
                derivation = (spin == "Left" and 1 or -1) * derivationBase
                if dist < 80 then derivation = derivation * (dist / 80) end
            elseif name == "SideRicochet" or name == "SmartCorner" then
                derivation = math.random(-0.5, 0.5)
            end
            
            local height = CalculateTrajectoryHeight(dist, power, name, isLowShot)
            if heightAdjust > 0 then 
                height = math.clamp(heightAdjust, 2.0, AutoShootMaxHeight)
            elseif isLowShot then 
                height = 0.5 
            end
            
            local noSpinPos = GoalCFrame * Vector3.new(math.clamp(x + randX, -halfWidth+0.5, halfWidth-0.5), height + randY, 0)
            local worldPos = GoalCFrame * Vector3.new(x + derivation + randX, height + randY, 0)
            local shootDir = (worldPos - startPos).Unit
            local goalNormal = GoalCFrame.LookVector
            local angleScore = math.abs(shootDir:Dot(goalNormal))
            local postPenalty = math.abs(playerLocalX - (x + derivation + randX)) < halfWidth * 0.5 and 5 or 0
            local goaliePenalty = math.abs(goalieX - (x + derivation + randX)) * 3
            local goalieYDist = math.abs(goalieY - (height + randY))
            local distToTarget = goaliePos and (worldPos - goaliePos).Magnitude or 999
            local goalieBlockPenalty = distToTarget < 5 and 10 or 0
            
            if goaliePos then
                local goalieDir = (goaliePos - startPos).Unit
                if shootDir:Dot(goalieDir) > 0.9 then goalieBlockPenalty = goalieBlockPenalty + 15 end
            end
            
            local ricochetScore = 0
            if name == "SmartCorner" and ricochetNormal then
                local reflectDir = shootDir - 2 * shootDir:Dot(ricochetNormal) * ricochetNormal
                local reflectAwayFromGoalie = goalieX > 0 and reflectDir.X < 0 or goalieX < 0 and reflectDir.X > 0
                ricochetScore = reflectAwayFromGoalie and 5 or 0
            end
            
            local score = goaliePenalty - angleScore * 2 - goalieYDist * 0.5 + math.random() - postPenalty - goalieBlockPenalty + ricochetScore
            if name == "CloseSpin" and isOffAngle then score = score + 5 elseif isClose then score = score + 3 end
            table.insert(candidates, { pos=worldPos, noSpinPos=noSpinPos, spin=spin, power=power, name=name, score=score, targetType=targetType })
        end
    end
    
    if #candidates == 0 then
        local x = targetSide * halfWidth * 0.9
        local power = math.clamp(AutoShootMinPower + dist * AutoShootPowerPerStud, AutoShootMinPower, AutoShootMaxPower)
        local height = CalculateTrajectoryHeight(dist, power, "FALLBACK", isLowShot)
        local spin = dist >= 110 and (targetSide > 0 and "Right" or "Left") or "None"
        local derivation = dist >= 110 and (spin == "Left" and 1 or -1) * (dist / 100)^1.5 * 1.3 * power or 0
        local targets = ricochetPoints
        
        for _, target in ipairs(targets) do
            local x = target.x; local y = target.y; local targetType = target.type; local ricochetNormal = target.normal
            local randX = math.random(-0.15, 0.15) * halfWidth
            local randY = math.random(-0.15, 0.15) * halfHeight
            local noSpinPos = GoalCFrame * Vector3.new(math.clamp(x + randX, -halfWidth+0.5, halfWidth-0.5), height + randY, 0)
            local worldPos = GoalCFrame * Vector3.new(x + derivation + randX, height + randY, 0)
            local shootDir = (worldPos - startPos).Unit
            local goalNormal = GoalCFrame.LookVector
            local angleScore = math.abs(shootDir:Dot(goalNormal))
            local postPenalty = math.abs(playerLocalX - (x + derivation + randX)) < halfWidth * 0.5 and 5 or 0
            local goaliePenalty = math.abs(goalieX - (x + derivation + randX)) * 3
            local goalieYDist = math.abs(goalieY - (height + randY))
            local distToTarget = goaliePos and (worldPos - goaliePos).Magnitude or 999
            local goalieBlockPenalty = distToTarget < 5 and 10 or 0
            
            if goaliePos then
                local goalieDir = (goaliePos - startPos).Unit
                if shootDir:Dot(goalieDir) > 0.9 then goalieBlockPenalty = goalieBlockPenalty + 15 end
            end
            
            local ricochetScore = 0
            if ricochetNormal then
                local reflectDir = shootDir - 2 * shootDir:Dot(ricochetNormal) * ricochetNormal
                local reflectAwayFromGoalie = goalieX > 0 and reflectDir.X < 0 or goalieX < 0 and reflectDir.X > 0
                ricochetScore = reflectAwayFromGoalie and 5 or 0
            end
            
            local score = goaliePenalty - angleScore * 2 - goalieYDist * 0.5 + math.random() - postPenalty - goalieBlockPenalty + ricochetScore
            if isClose then score = score + 3 end
            table.insert(candidates, { pos=worldPos, noSpinPos=noSpinPos, spin=spin, power=power, name="FALLBACK", score=score, targetType=targetType })
        end
    end
    
    table.sort(candidates, function(a, b) return a.score > b.score end)
    local selected = candidates[1]
    if not selected then return nil, "None", "None", 0 end
    return selected.pos, selected.spin, selected.name .. " (" .. selected.targetType .. ")", selected.power, selected.noSpinPos
end

local function CalculateTarget()
    local width = UpdateGoal()
    if not GoalCFrame or not width then 
        TargetPoint = nil; NoSpinPoint = nil; 
        if Gui then 
            Gui.Target.Text = "Target: --"; 
            Gui.Power.Text = "Power: --"; 
            Gui.Spin.Text = "Spin: --" 
        end; 
        return 
    end
    
    local dist = (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude
    if Gui then 
        Gui.Dist.Text = string.format("Dist: %.1f (Max: %.1f)", dist, AutoShootMaxDistance) 
    end
    
    if dist > AutoShootMaxDistance then 
        TargetPoint = nil; NoSpinPoint = nil; 
        if Gui then 
            Gui.Target.Text = "Target: --"; 
            Gui.Power.Text = "Power: --"; 
            Gui.Spin.Text = "Spin: --" 
        end; 
        return 
    end
    
    local startPos = HumanoidRootPart.Position
    local goalDir = (GoalCFrame.Position - startPos).Unit
    local forwardDir = (HumanoidRootPart.CFrame.LookVector).Unit
    local playerAngle = math.deg(math.acos(goalDir:Dot(forwardDir)))
    local goalieHrp, goalieX, goalieY, _, isAggressive = GetEnemyGoalie()
    local goaliePos = goalieHrp and goalieHrp.Position or nil
    local worldTarget, spin, name, power, noSpinPos = GetTarget(dist, goalieX or 0, goalieY or 0, isAggressive or false, goaliePos, playerAngle)
    
    if not worldTarget then 
        TargetPoint = nil; NoSpinPoint = nil; 
        if Gui then 
            Gui.Target.Text = "Target: --"; 
            Gui.Power.Text = "Power: --"; 
            Gui.Spin.Text = "Spin: --" 
        end; 
        return 
    end
    
    TargetPoint = worldTarget
    NoSpinPoint = noSpinPos
    CurrentSpin = spin
    CurrentType = name
    CurrentPower = power
    ShootDir = (worldTarget - startPos).Unit
    ShootVel = ShootDir * (power * 1400)
    
    if Gui then
        Gui.Target.Text = "Target: " .. name
        Gui.Power.Text = string.format("Power: %.2f", power)
        Gui.Spin.Text = "Spin: " .. spin
    end
end

-- === MANUAL BUTTON ===
local function SetupManualButton()
    if AutoShootStatus.ButtonGui then AutoShootStatus.ButtonGui:Destroy() end
    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "ManualShootButtonGui"
    buttonGui.ResetOnSpawn = false
    buttonGui.IgnoreGuiInset = false
    buttonGui.Parent = game:GetService("CoreGui")
    local size = 50 * AutoShootButtonScale
    local screenSize = Camera.ViewportSize
    local initialX = screenSize.X / 2 - size / 2
    local initialY = screenSize.Y / 2 - size / 2
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0, size, 0, size)
    buttonFrame.Position = UDim2.new(0, initialX, 0, initialY)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Visible = AutoShootManualButton
    buttonFrame.Parent = buttonGui
    Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)
    local buttonIcon = Instance.new("ImageLabel")
    buttonIcon.Size = UDim2.new(0, size*0.6, 0, size*0.6)
    buttonIcon.Position = UDim2.new(0.5, -size*0.3, 0.5, -size*0.3)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Image = "rbxassetid://73279554401260"
    buttonIcon.Parent = buttonFrame
    
    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            AutoShootStatus.TouchStartTime = tick()
            local mousePos = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
            AutoShootStatus.Dragging = true
            AutoShootStatus.DragStart = mousePos
            AutoShootStatus.StartPos = buttonFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and AutoShootStatus.Dragging then
            local mousePos = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or UserInputService:GetMouseLocation()
            local delta = mousePos - AutoShootStatus.DragStart
            buttonFrame.Position = UDim2.new(AutoShootStatus.StartPos.X.Scale, AutoShootStatus.StartPos.X.Offset + delta.X, AutoShootStatus.StartPos.Y.Scale, AutoShootStatus.StartPos.Y.Offset + delta.Y)
        end
    end)
    
    buttonFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            AutoShootStatus.Dragging = false
            if AutoShootStatus.TouchStartTime > 0 and tick() - AutoShootStatus.TouchStartTime < 0.2 then
                local ball = Workspace:FindFirstChild("ball")
                local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
                if hasBall and TargetPoint then
                    pcall(CalculateTarget)
                    if ShootDir then
                        if AutoShootLegit and not IsAnimating then
                            IsAnimating = true
                            RShootAnim:Play()
                            task.delay(AnimationHoldTime, function() IsAnimating = false end)
                        end
                        local success = pcall(function()
                            Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
                        end)
                        if success then
                            notify("AutoShoot", "Manual Shoot", true)
                            if Gui then
                                Gui.Status.Text = "MANUAL SHOT! [" .. CurrentType .. "]"
                                Gui.Status.Color = Color3.fromRGB(0,255,0)
                            end
                            LastShoot = tick()
                            CanShoot = false
                            task.delay(0.3, function() CanShoot = true end)
                        end
                    end
                end
            end
            AutoShootStatus.TouchStartTime = 0
        end
    end)
    
    AutoShootStatus.ButtonGui = buttonGui
end

local function ToggleManualButton(value)
    AutoShootManualButton = value
    AutoShootStatus.ManualButton = value
    if value then
        SetupManualButton()
    else
        if AutoShootStatus.ButtonGui then 
            AutoShootStatus.ButtonGui:Destroy(); 
            AutoShootStatus.ButtonGui = nil 
        end
    end
end

local function SetButtonScale(value)
    AutoShootButtonScale = value
    AutoShootStatus.ButtonScale = value
    if AutoShootManualButton then SetupManualButton() end
end

-- === AUTO SHOOT ===
local AutoShoot = {}
AutoShoot.Start = function()
    if AutoShootStatus.Running then return end
    AutoShootStatus.Running = true
    SetupGUI()
    InitializeCubes()
    UpdateModeText()
    if AutoShootManualButton then SetupManualButton() end
    
    AutoShootStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoShootEnabled then return end
        pcall(CalculateTarget)
        local ball = Workspace:FindFirstChild("ball")
        local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
        local dist = GoalCFrame and (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude or 999
        
        if hasBall and TargetPoint and dist <= AutoShootMaxDistance then
            if Gui then
                Gui.Status.Text = AutoShootManualShot and "Ready (Press " .. GetKeyName(AutoShootShootKey) .. ")" or "Aiming..."
                Gui.Status.Color = Color3.fromRGB(0,255,0)
            end
        elseif hasBall then
            if Gui then
                Gui.Status.Text = dist > AutoShootMaxDistance and "Too Far" or "No Target"
                Gui.Status.Color = Color3.fromRGB(255,100,0)
            end
        else
            if Gui then
                Gui.Status.Text = "No Ball"
                Gui.Status.Color = Color3.fromRGB(255,165,0)
            end
        end
        
        if hasBall and TargetPoint and dist <= AutoShootMaxDistance and not AutoShootManualShot and tick() - LastShoot >= 0.3 then
            if AutoShootLegit and not IsAnimating then
                IsAnimating = true
                RShootAnim:Play()
                task.delay(AnimationHoldTime, function() IsAnimating = false end)
            end
            pcall(function()
                Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
            end)
            if Gui then
                Gui.Status.Text = "AUTO SHOT! [" .. CurrentType .. "]"
                Gui.Status.Color = Color3.fromRGB(0,255,0)
            end
            LastShoot = tick()
        end
    end)
    
    AutoShootStatus.InputConnection = UserInputService.InputBegan:Connect(function(inp, gp)
        if gp or not AutoShootEnabled or not AutoShootManualShot or not CanShoot then return end
        if inp.KeyCode == AutoShootShootKey then
            local ball = Workspace:FindFirstChild("ball")
            local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
            if hasBall and TargetPoint then
                pcall(CalculateTarget)
                if ShootDir then
                    if AutoShootLegit and not IsAnimating then
                        IsAnimating = true
                        RShootAnim:Play()
                        task.delay(AnimationHoldTime, function() IsAnimating = false end)
                    end
                    local success = pcall(function()
                        Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
                    end)
                    if success then
                        notify("AutoShoot", "Manual Shoot", true)
                        if Gui then
                            Gui.Status.Text = "MANUAL SHOT! [" .. CurrentType .. "]"
                            Gui.Status.Color = Color3.fromRGB(0,255,0)
                        end
                        LastShoot = tick()
                        CanShoot = false
                        task.delay(0.3, function() CanShoot = true end)
                    end
                end
            end
        end
    end)
    
    AutoShootStatus.RenderConnection = RunService.RenderStepped:Connect(function()
        local width = UpdateGoal()
        if GoalCFrame and width then 
            DrawOrientedCube(GoalCube, GoalCFrame, Vector3.new(width, GoalHeight, 2)) 
        else 
            for _, l in ipairs(GoalCube) do l.Visible = false end 
        end
        
        if TargetPoint then 
            DrawOrientedCube(TargetCube, CFrame.new(TargetPoint), Vector3.new(4,4,4)) 
        else 
            for _, l in ipairs(TargetCube) do l.Visible = false end 
        end
        
        if NoSpinPoint then 
            DrawOrientedCube(NoSpinCube, CFrame.new(NoSpinPoint), Vector3.new(3,3,3)) 
        else 
            for _, l in ipairs(NoSpinCube) do l.Visible = false end 
        end
    end)
    
    notify("AutoShoot", "Started", true)
end

AutoShoot.Stop = function()
    if AutoShootStatus.Connection then AutoShootStatus.Connection:Disconnect(); AutoShootStatus.Connection = nil end
    if AutoShootStatus.RenderConnection then AutoShootStatus.RenderConnection:Disconnect(); AutoShootStatus.RenderConnection = nil end
    if AutoShootStatus.InputConnection then AutoShootStatus.InputConnection:Disconnect(); AutoShootStatus.InputConnection = nil end
    AutoShootStatus.Running = false
    
    if Gui then
        for _, v in pairs(Gui) do if v.Remove then v:Remove() end end
        Gui = nil
    end
    
    for i = 1, 12 do 
        if TargetCube[i] and TargetCube[i].Remove then TargetCube[i]:Remove() end
        if GoalCube[i] and GoalCube[i].Remove then GoalCube[i]:Remove() end
        if NoSpinCube[i] and NoSpinCube[i].Remove then NoSpinCube[i]:Remove() end
    end
    
    if AutoShootStatus.ButtonGui then 
        AutoShootStatus.ButtonGui:Destroy(); 
        AutoShootStatus.ButtonGui = nil 
    end
    
    notify("AutoShoot", "Stopped", true)
end

AutoShoot.SetDebugText = function(value)
    AutoShootDebugText = value
    AutoShootStatus.DebugText = value
    ToggleDebugText(value)
    notify("AutoShoot", "Debug Text " .. (value and "Enabled" or "Disabled"), true)
end

-- === AUTO PICKUP ===
local AutoPickup = {}
AutoPickup.Start = function()
    if AutoPickupStatus.Running then return end
    AutoPickupStatus.Running = true
    AutoPickupStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoPickupEnabled or not PickupRemote then return end
        local ball = Workspace:FindFirstChild("ball")
        if not ball or ball:FindFirstChild("playerWeld") then return end
        if (HumanoidRootPart.Position - ball.Position).Magnitude <= AutoPickupDist then
            pcall(function() PickupRemote:FireServer(AutoPickupSpoofValue) end)
        end
    end)
    notify("AutoPickup", "Started", true)
end

AutoPickup.Stop = function()
    if AutoPickupStatus.Connection then AutoPickupStatus.Connection:Disconnect(); AutoPickupStatus.Connection = nil end
    AutoPickupStatus.Running = false
    notify("AutoPickup", "Stopped", true)
end

-- === UI ===
local uiElements = {}
local function SetupUI(UI)
    if UI.Sections.AutoShoot then
        UI.Sections.AutoShoot:Header({ Name = "AutoShoot" })
        UI.Sections.AutoShoot:Divider()
        
        uiElements.AutoShootEnabled = UI.Sections.AutoShoot:Toggle({ 
            Name = "Enabled", 
            Default = AutoShootEnabled, 
            Callback = function(v) 
                AutoShootEnabled = v
                if v then 
                    AutoShoot.Start() 
                else 
                    AutoShoot.Stop() 
                end
            end
        }, "AutoShootEnabled")
        
        uiElements.AutoShootLegit = UI.Sections.AutoShoot:Toggle({ 
            Name = "Legit Animation", 
            Default = AutoShootLegit, 
            Callback = function(v) 
                AutoShootLegit = v
            end
        }, "AutoShootLegit")
        
        UI.Sections.AutoShoot:Divider()
        
        uiElements.AutoShootManual = UI.Sections.AutoShoot:Toggle({ 
            Name = "Manual Shot", 
            Default = AutoShootManualShot, 
            Callback = function(v) 
                AutoShootManualShot = v
                UpdateModeText()
            end
        }, "AutoShootManual")
        
        uiElements.AutoShootKey = UI.Sections.AutoShoot:Keybind({ 
            Name = "Shoot Key", 
            Default = AutoShootShootKey, 
            Callback = function(v) 
                AutoShootShootKey = v
                AutoShootStatus.Key = v
                UpdateModeText()
            end
        }, "AutoShootKey")
        
        uiElements.AutoShootManualButton = UI.Sections.AutoShoot:Toggle({ 
            Name = "Manual Button", 
            Default = AutoShootManualButton, 
            Callback = function(v) 
                AutoShootManualButton = v
                ToggleManualButton(v)
            end
        }, "AutoShootManualButton")
        
        uiElements.AutoShootButtonScale = UI.Sections.AutoShoot:Slider({ 
            Name = "Button Scale", 
            Minimum = 0.5, 
            Maximum = 2.0, 
            Default = AutoShootButtonScale, 
            Precision = 2, 
            Callback = function(v) 
                AutoShootButtonScale = v
                SetButtonScale(v)
            end
        }, "AutoShootButtonScale")
        
        UI.Sections.AutoShoot:Divider()
        
        uiElements.AutoShootMaxDist = UI.Sections.AutoShoot:Slider({ 
            Name = "Max Distance", 
            Minimum = 50, 
            Maximum = 300, 
            Default = AutoShootMaxDistance, 
            Precision = 1, 
            Callback = function(v) 
                AutoShootMaxDistance = v
            end
        }, "AutoShootMaxDist")
        
        uiElements.AutoShootDebugText = UI.Sections.AutoShoot:Toggle({ 
            Name = "Debug Text", 
            Default = AutoShootDebugText, 
            Callback = function(v) 
                AutoShootDebugText = v
                AutoShoot.SetDebugText(v)
            end
        }, "AutoShootDebugText")
    end

    if UI.Sections.AutoPickup then
        UI.Sections.AutoPickup:Header({ Name = "AutoPickup" })
        UI.Sections.AutoPickup:Divider()
        
        uiElements.AutoPickupEnabled = UI.Sections.AutoPickup:Toggle({ 
            Name = "Enabled", 
            Default = AutoPickupEnabled, 
            Callback = function(v) 
                AutoPickupEnabled = v
                if v then 
                    AutoPickup.Start() 
                else 
                    AutoPickup.Stop() 
                end
            end
        }, "AutoPickupEnabled")
        
        uiElements.AutoPickupDist = UI.Sections.AutoPickup:Slider({ 
            Name = "Pickup Distance", 
            Minimum = 10, 
            Maximum = 100, 
            Default = AutoPickupDist, 
            Precision = 1, 
            Callback = function(v) 
                AutoPickupDist = v
            end
        }, "AutoPickupDist")
        
        UI.Sections.AutoPickup:Divider()
        
        uiElements.AutoPickupSpoof = UI.Sections.AutoPickup:Slider({ 
            Name = "Spoof Value", 
            Minimum = 0.1, 
            Maximum = 5.0, 
            Default = AutoPickupSpoofValue, 
            Precision = 2, 
            Callback = function(v) 
                AutoPickupSpoofValue = v
            end
        }, "AutoPickupSpoof")
        
        UI.Sections.AutoPickup:SubLabel({Text = '[💠] The distance from you to the ball that is sent to the server'})
    end

    if UI.Sections.AdvancedPrediction then
        UI.Sections.AdvancedPrediction:Header({ Name = "Advanced Prediction (AutoShoot)" })
        UI.Sections.AdvancedPrediction:Divider()
        
        uiElements.AdvancedInset = UI.Sections.AdvancedPrediction:Slider({ 
            Name = "Goal Inset", 
            Minimum = 0, 
            Maximum = 5, 
            Default = AutoShootInset, 
            Precision = 1, 
            Callback = function(v) 
                AutoShootInset = v
            end
        }, "AdvancedInset")
        
        UI.Sections.AdvancedPrediction:SubLabel({Text ='[💠] Indentation from the edges of the gate (in studs)'})
        UI.Sections.AdvancedPrediction:Divider()
        
        uiElements.AdvancedGravity = UI.Sections.AdvancedPrediction:Slider({ 
            Name = "Gravity", 
            Minimum = 50, 
            Maximum = 200, 
            Default = AutoShootGravity, 
            Precision = 1, 
            Callback = function(v) 
                AutoShootGravity = v
            end
        }, "AdvancedGravity")
        
        UI.Sections.AdvancedPrediction:Divider()
        
        uiElements.AdvancedMinPower = UI.Sections.AdvancedPrediction:Slider({ 
            Name = "Min Power", 
            Minimum = 1.0, 
            Maximum = 10.0, 
            Default = AutoShootMinPower, 
            Precision = 2, 
            Callback = function(v) 
                AutoShootMinPower = v
            end
        }, "AdvancedMinPower")
        
        uiElements.AdvancedMaxPower = UI.Sections.AdvancedPrediction:Slider({ 
            Name = "Max Power", 
            Minimum = 5.0, 
            Maximum = 15.0, 
            Default = AutoShootMaxPower, 
            Precision = 2, 
            Callback = function(v) 
                AutoShootMaxPower = v
            end
        }, "AdvancedMaxPower")
        
        uiElements.AdvancedPowerPerStud = UI.Sections.AdvancedPrediction:Slider({ 
            Name = "Power Per Stud", 
            Minimum = 0.001, 
            Maximum = 0.1, 
            Default = AutoShootPowerPerStud, 
            Precision = 3, 
            Callback = function(v) 
                AutoShootPowerPerStud = v
            end
        }, "AdvancedPowerPerStud")
        
        UI.Sections.AdvancedPrediction:Divider()
        
        uiElements.AdvancedMaxHeight = UI.Sections.AdvancedPrediction:Slider({ 
            Name = "Max Height", 
            Minimum = 50, 
            Maximum = 200, 
            Default = AutoShootMaxHeight, 
            Precision = 1, 
            Callback = function(v) 
                AutoShootMaxHeight = v
            end
        }, "AdvancedMaxHeight")
        
        UI.Sections.AdvancedPrediction:SubLabel({Text ='[💠] The maximum height of the ball flight (in studs)'})
    end

    if UI.Sections.Attacks then
        UI.Sections.Attacks:Header({ Name = "AutoShoot Attacks" })
        UI.Sections.Attacks:Divider()
        UI.Sections.Attacks:Paragraph({
            Header = "Information",
            Body = "Min Dist - Minimum Distance for attack, Max Dist - Maximum Distance, X Mult - horizontal position multiplier (from center), Base Min/ Base Max - basic altitude range, DerivationMult - Prediction force of the ball deflection, Y Reverse - инвертирует высоту траектории и увеличивает её в 2 раза"
        })
        UI.Sections.Attacks:Divider()
        
        -- SideRicochet
        UI.Sections.Attacks:Header({ Name = "SideRicochet" })
        
        uiElements.SideRicochetEnabled = UI.Sections.Attacks:Toggle({ 
            Name = "Enabled", 
            Default = Attacks.SideRicochet.Enabled, 
            Callback = function(v) 
                Attacks.SideRicochet.Enabled = v
            end
        }, "SideRicochetEnabled")
        
        uiElements.SideRicochetMinDist = UI.Sections.Attacks:Slider({ 
            Name = "Min Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SideRicochet.MinDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SideRicochet.MinDist = v
            end
        }, "SideRicochetMinDist")
        
        uiElements.SideRicochetMaxDist = UI.Sections.Attacks:Slider({ 
            Name = "Max Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SideRicochet.MaxDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SideRicochet.MaxDist = v
            end
        }, "SideRicochetMaxDist")
        
        uiElements.SideRicochetPower = UI.Sections.Attacks:Slider({ 
            Name = "Power", 
            Minimum = 0.5, 
            Maximum = 100.0, 
            Default = Attacks.SideRicochet.Power, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SideRicochet.Power = v
            end
        }, "SideRicochetPower")
        
        uiElements.SideRicochetXMult = UI.Sections.Attacks:Slider({ 
            Name = "X Mult", 
            Minimum = 0.1, 
            Maximum = 2.0, 
            Default = Attacks.SideRicochet.XMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SideRicochet.XMult = v
            end
        }, "SideRicochetXMult")
        
        uiElements.SideRicochetHeightMult = UI.Sections.Attacks:Slider({ 
            Name = "Height Mult", 
            Minimum = 0.1, 
            Maximum = 3.0, 
            Default = Attacks.SideRicochet.HeightMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SideRicochet.HeightMult = v
            end
        }, "SideRicochetHeightMult")
        
        uiElements.SideRicochetBaseMin = UI.Sections.Attacks:Slider({ 
            Name = "Base Min", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SideRicochet.BaseHeightRange.Min, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SideRicochet.BaseHeightRange.Min = v
            end
        }, "SideRicochetBaseMin")
        
        uiElements.SideRicochetBaseMax = UI.Sections.Attacks:Slider({ 
            Name = "Base Max", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SideRicochet.BaseHeightRange.Max, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SideRicochet.BaseHeightRange.Max = v
            end
        }, "SideRicochetBaseMax")
        
        uiElements.SideRicochetDerivationMult = UI.Sections.Attacks:Slider({ 
            Name = "Derivation Mult", 
            Minimum = 0.0, 
            Maximum = 10.0, 
            Default = Attacks.SideRicochet.DerivationMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SideRicochet.DerivationMult = v
            end
        }, "SideRicochetDerivationMult")
        
        uiElements.SideRicochetYReverse = UI.Sections.Attacks:Toggle({ 
            Name = "Y Reverse", 
            Default = Attacks.SideRicochet.YReverse, 
            Callback = function(v) 
                Attacks.SideRicochet.YReverse = v
            end
        }, "SideRicochetYReverse")
        
        UI.Sections.Attacks:Divider()
        
        -- CloseSpin
        UI.Sections.Attacks:Header({ Name = "CloseSpin" })
        
        uiElements.CloseSpinEnabled = UI.Sections.Attacks:Toggle({ 
            Name = "Enabled", 
            Default = Attacks.CloseSpin.Enabled, 
            Callback = function(v) 
                Attacks.CloseSpin.Enabled = v
            end
        }, "CloseSpinEnabled")
        
        uiElements.CloseSpinMinDist = UI.Sections.Attacks:Slider({ 
            Name = "Min Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.CloseSpin.MinDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.CloseSpin.MinDist = v
            end
        }, "CloseSpinMinDist")
        
        uiElements.CloseSpinMaxDist = UI.Sections.Attacks:Slider({ 
            Name = "Max Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.CloseSpin.MaxDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.CloseSpin.MaxDist = v
            end
        }, "CloseSpinMaxDist")
        
        uiElements.CloseSpinPower = UI.Sections.Attacks:Slider({ 
            Name = "Power", 
            Minimum = 0.5, 
            Maximum = 100.0, 
            Default = Attacks.CloseSpin.Power, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.CloseSpin.Power = v
            end
        }, "CloseSpinPower")
        
        uiElements.CloseSpinXMult = UI.Sections.Attacks:Slider({ 
            Name = "X Mult", 
            Minimum = 0.1, 
            Maximum = 2.0, 
            Default = Attacks.CloseSpin.XMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.CloseSpin.XMult = v
            end
        }, "CloseSpinXMult")
        
        uiElements.CloseSpinSpin = UI.Sections.Attacks:Toggle({ 
            Name = "Spin", 
            Default = Attacks.CloseSpin.Spin, 
            Callback = function(v) 
                Attacks.CloseSpin.Spin = v
            end
        }, "CloseSpinSpin")
        
        uiElements.CloseSpinHeightMult = UI.Sections.Attacks:Slider({ 
            Name = "Height Mult", 
            Minimum = 0.1, 
            Maximum = 3.0, 
            Default = Attacks.CloseSpin.HeightMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.CloseSpin.HeightMult = v
            end
        }, "CloseSpinHeightMult")
        
        uiElements.CloseSpinBaseMin = UI.Sections.Attacks:Slider({ 
            Name = "Base Min", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.CloseSpin.BaseHeightRange.Min, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.CloseSpin.BaseHeightRange.Min = v
            end
        }, "CloseSpinBaseMin")
        
        uiElements.CloseSpinBaseMax = UI.Sections.Attacks:Slider({ 
            Name = "Base Max", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.CloseSpin.BaseHeightRange.Max, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.CloseSpin.BaseHeightRange.Max = v
            end
        }, "CloseSpinBaseMax")
        
        uiElements.CloseSpinDerivationMult = UI.Sections.Attacks:Slider({ 
            Name = "Derivation Mult", 
            Minimum = 0.0, 
            Maximum = 10.0, 
            Default = Attacks.CloseSpin.DerivationMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.CloseSpin.DerivationMult = v
            end
        }, "CloseSpinDerivationMult")
        
        uiElements.CloseSpinYReverse = UI.Sections.Attacks:Toggle({ 
            Name = "Y Reverse", 
            Default = Attacks.CloseSpin.YReverse, 
            Callback = function(v) 
                Attacks.CloseSpin.YReverse = v
            end
        }, "CloseSpinYReverse")
        
        UI.Sections.Attacks:Divider()
        
        -- SmartCorner
        UI.Sections.Attacks:Header({ Name = "SmartCorner" })
        
        uiElements.SmartCornerEnabled = UI.Sections.Attacks:Toggle({ 
            Name = "Enabled", 
            Default = Attacks.SmartCorner.Enabled, 
            Callback = function(v) 
                Attacks.SmartCorner.Enabled = v
            end
        }, "SmartCornerEnabled")
        
        uiElements.SmartCornerMinDist = UI.Sections.Attacks:Slider({ 
            Name = "Min Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartCorner.MinDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartCorner.MinDist = v
            end
        }, "SmartCornerMinDist")
        
        uiElements.SmartCornerMaxDist = UI.Sections.Attacks:Slider({ 
            Name = "Max Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartCorner.MaxDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartCorner.MaxDist = v
            end
        }, "SmartCornerMaxDist")
        
        uiElements.SmartCornerPowerMin = UI.Sections.Attacks:Slider({ 
            Name = "Power Min", 
            Minimum = 0.5, 
            Maximum = 10.0, 
            Default = Attacks.SmartCorner.PowerMin, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCorner.PowerMin = v
            end
        }, "SmartCornerPowerMin")
        
        uiElements.SmartCornerXMult = UI.Sections.Attacks:Slider({ 
            Name = "X Mult", 
            Minimum = 0.1, 
            Maximum = 2.0, 
            Default = Attacks.SmartCorner.XMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCorner.XMult = v
            end
        }, "SmartCornerXMult")
        
        uiElements.SmartCornerHeightMult = UI.Sections.Attacks:Slider({ 
            Name = "Height Mult", 
            Minimum = 0.1, 
            Maximum = 3.0, 
            Default = Attacks.SmartCorner.HeightMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCorner.HeightMult = v
            end
        }, "SmartCornerHeightMult")
        
        uiElements.SmartCornerBaseMin = UI.Sections.Attacks:Slider({ 
            Name = "Base Min", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartCorner.BaseHeightRange.Min, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCorner.BaseHeightRange.Min = v
            end
        }, "SmartCornerBaseMin")
        
        uiElements.SmartCornerBaseMax = UI.Sections.Attacks:Slider({ 
            Name = "Base Max", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartCorner.BaseHeightRange.Max, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCorner.BaseHeightRange.Max = v
            end
        }, "SmartCornerBaseMax")
        
        uiElements.SmartCornerDerivationMult = UI.Sections.Attacks:Slider({ 
            Name = "Derivation Mult", 
            Minimum = 0.0, 
            Maximum = 10.0, 
            Default = Attacks.SmartCorner.DerivationMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCorner.DerivationMult = v
            end
        }, "SmartCornerDerivationMult")
        
        uiElements.SmartCornerYReverse = UI.Sections.Attacks:Toggle({ 
            Name = "Y Reverse", 
            Default = Attacks.SmartCorner.YReverse, 
            Callback = function(v) 
                Attacks.SmartCorner.YReverse = v
            end
        }, "SmartCornerYReverse")
        
        UI.Sections.Attacks:Divider()
        
        -- SmartCandle
        UI.Sections.Attacks:Header({ Name = "SmartCandle" })
        
        uiElements.SmartCandleEnabled = UI.Sections.Attacks:Toggle({ 
            Name = "Enabled", 
            Default = Attacks.SmartCandle.Enabled, 
            Callback = function(v) 
                Attacks.SmartCandle.Enabled = v
            end
        }, "SmartCandleEnabled")
        
        uiElements.SmartCandleMinDist = UI.Sections.Attacks:Slider({ 
            Name = "Min Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartCandle.MinDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartCandle.MinDist = v
            end
        }, "SmartCandleMinDist")
        
        uiElements.SmartCandleMaxDist = UI.Sections.Attacks:Slider({ 
            Name = "Max Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartCandle.MaxDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartCandle.MaxDist = v
            end
        }, "SmartCandleMaxDist")
        
        uiElements.SmartCandlePower = UI.Sections.Attacks:Slider({ 
            Name = "Power", 
            Minimum = 0.5, 
            Maximum = 100.0, 
            Default = Attacks.SmartCandle.Power, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandle.Power = v
            end
        }, "SmartCandlePower")
        
        uiElements.SmartCandleXMult = UI.Sections.Attacks:Slider({ 
            Name = "X Mult", 
            Minimum = 0.1, 
            Maximum = 2.0, 
            Default = Attacks.SmartCandle.XMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandle.XMult = v
            end
        }, "SmartCandleXMult")
        
        uiElements.SmartCandleSpin = UI.Sections.Attacks:Toggle({ 
            Name = "Spin", 
            Default = Attacks.SmartCandle.Spin, 
            Callback = function(v) 
                Attacks.SmartCandle.Spin = v
            end
        }, "SmartCandleSpin")
        
        uiElements.SmartCandleHeightMult = UI.Sections.Attacks:Slider({ 
            Name = "Height Mult", 
            Minimum = 0.1, 
            Maximum = 3.0, 
            Default = Attacks.SmartCandle.HeightMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandle.HeightMult = v
            end
        }, "SmartCandleHeightMult")
        
        uiElements.SmartCandleBaseMin = UI.Sections.Attacks:Slider({ 
            Name = "Base Min", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartCandle.BaseHeightRange.Min, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandle.BaseHeightRange.Min = v
            end
        }, "SmartCandleBaseMin")
        
        uiElements.SmartCandleBaseMax = UI.Sections.Attacks:Slider({ 
            Name = "Base Max", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartCandle.BaseHeightRange.Max, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandle.BaseHeightRange.Max = v
            end
        }, "SmartCandleBaseMax")
        
        uiElements.SmartCandleDerivationMult = UI.Sections.Attacks:Slider({ 
            Name = "Derivation Mult", 
            Minimum = 0.0, 
            Maximum = 10.0, 
            Default = Attacks.SmartCandle.DerivationMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandle.DerivationMult = v
            end
        }, "SmartCandleDerivationMult")
        
        uiElements.SmartCandleYReverse = UI.Sections.Attacks:Toggle({ 
            Name = "Y Reverse", 
            Default = Attacks.SmartCandle.YReverse, 
            Callback = function(v) 
                Attacks.SmartCandle.YReverse = v
            end
        }, "SmartCandleYReverse")
        
        UI.Sections.Attacks:Divider()
        
        -- SmartRicochet
        UI.Sections.Attacks:Header({ Name = "SmartRicochet" })
        
        uiElements.SmartRicochetEnabled = UI.Sections.Attacks:Toggle({ 
            Name = "Enabled", 
            Default = Attacks.SmartRicochet.Enabled, 
            Callback = function(v) 
                Attacks.SmartRicochet.Enabled = v
            end
        }, "SmartRicochetEnabled")
        
        uiElements.SmartRicochetMinDist = UI.Sections.Attacks:Slider({ 
            Name = "Min Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartRicochet.MinDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartRicochet.MinDist = v
            end
        }, "SmartRicochetMinDist")
        
        uiElements.SmartRicochetMaxDist = UI.Sections.Attacks:Slider({ 
            Name = "Max Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartRicochet.MaxDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartRicochet.MaxDist = v
            end
        }, "SmartRicochetMaxDist")
        
        uiElements.SmartRicochetPower = UI.Sections.Attacks:Slider({ 
            Name = "Power", 
            Minimum = 0.5, 
            Maximum = 100.0, 
            Default = Attacks.SmartRicochet.Power, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartRicochet.Power = v
            end
        }, "SmartRicochetPower")
        
        uiElements.SmartRicochetXMult = UI.Sections.Attacks:Slider({ 
            Name = "X Mult", 
            Minimum = 0.1, 
            Maximum = 2.0, 
            Default = Attacks.SmartRicochet.XMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartRicochet.XMult = v
            end
        }, "SmartRicochetXMult")
        
        uiElements.SmartRicochetSpin = UI.Sections.Attacks:Toggle({ 
            Name = "Spin", 
            Default = Attacks.SmartRicochet.Spin, 
            Callback = function(v) 
                Attacks.SmartRicochet.Spin = v
            end
        }, "SmartRicochetSpin")
        
        uiElements.SmartRicochetHeightMult = UI.Sections.Attacks:Slider({ 
            Name = "Height Mult", 
            Minimum = 0.1, 
            Maximum = 3.0, 
            Default = Attacks.SmartRicochet.HeightMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartRicochet.HeightMult = v
            end
        }, "SmartRicochetHeightMult")
        
        uiElements.SmartRicochetBaseMin = UI.Sections.Attacks:Slider({ 
            Name = "Base Min", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartRicochet.BaseHeightRange.Min, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartRicochet.BaseHeightRange.Min = v
            end
        }, "SmartRicochetBaseMin")
        
        uiElements.SmartRicochetBaseMax = UI.Sections.Attacks:Slider({ 
            Name = "Base Max", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartRicochet.BaseHeightRange.Max, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartRicochet.BaseHeightRange.Max = v
            end
        }, "SmartRicochetBaseMax")
        
        uiElements.SmartRicochetDerivationMult = UI.Sections.Attacks:Slider({ 
            Name = "Derivation Mult", 
            Minimum = 0.0, 
            Maximum = 10.0, 
            Default = Attacks.SmartRicochet.DerivationMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartRicochet.DerivationMult = v
            end
        }, "SmartRicochetDerivationMult")
        
        uiElements.SmartRicochetYReverse = UI.Sections.Attacks:Toggle({ 
            Name = "Y Reverse", 
            Default = Attacks.SmartRicochet.YReverse, 
            Callback = function(v) 
                Attacks.SmartRicochet.YReverse = v
            end
        }, "SmartRicochetYReverse")
        
        UI.Sections.Attacks:Divider()
        
        -- SmartSpin
        UI.Sections.Attacks:Header({ Name = "SmartSpin" })
        
        uiElements.SmartSpinEnabled = UI.Sections.Attacks:Toggle({ 
            Name = "Enabled", 
            Default = Attacks.SmartSpin.Enabled, 
            Callback = function(v) 
                Attacks.SmartSpin.Enabled = v
            end
        }, "SmartSpinEnabled")
        
        uiElements.SmartSpinMinDist = UI.Sections.Attacks:Slider({ 
            Name = "Min Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartSpin.MinDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartSpin.MinDist = v
            end
        }, "SmartSpinMinDist")
        
        uiElements.SmartSpinMaxDist = UI.Sections.Attacks:Slider({ 
            Name = "Max Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartSpin.MaxDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartSpin.MaxDist = v
            end
        }, "SmartSpinMaxDist")
        
        uiElements.SmartSpinPowerAdd = UI.Sections.Attacks:Slider({ 
            Name = "Power Add", 
            Minimum = -5.0, 
            Maximum = 5.0, 
            Default = Attacks.SmartSpin.PowerAdd, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartSpin.PowerAdd = v
            end
        }, "SmartSpinPowerAdd")
        
        uiElements.SmartSpinXMult = UI.Sections.Attacks:Slider({ 
            Name = "X Mult", 
            Minimum = 0.1, 
            Maximum = 2.0, 
            Default = Attacks.SmartSpin.XMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartSpin.XMult = v
            end
        }, "SmartSpinXMult")
        
        uiElements.SmartSpinSpin = UI.Sections.Attacks:Toggle({ 
            Name = "Spin", 
            Default = Attacks.SmartSpin.Spin, 
            Callback = function(v) 
                Attacks.SmartSpin.Spin = v
            end
        }, "SmartSpinSpin")
        
        uiElements.SmartSpinHeightMult = UI.Sections.Attacks:Slider({ 
            Name = "Height Mult", 
            Minimum = 0.1, 
            Maximum = 3.0, 
            Default = Attacks.SmartSpin.HeightMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartSpin.HeightMult = v
            end
        }, "SmartSpinHeightMult")
        
        uiElements.SmartSpinBaseMin = UI.Sections.Attacks:Slider({ 
            Name = "Base Min", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartSpin.BaseHeightRange.Min, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartSpin.BaseHeightRange.Min = v
            end
        }, "SmartSpinBaseMin")
        
        uiElements.SmartSpinBaseMax = UI.Sections.Attacks:Slider({ 
            Name = "Base Max", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartSpin.BaseHeightRange.Max, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartSpin.BaseHeightRange.Max = v
            end
        }, "SmartSpinBaseMax")
        
        uiElements.SmartSpinDerivationMult = UI.Sections.Attacks:Slider({ 
            Name = "Derivation Mult", 
            Minimum = 0.0, 
            Maximum = 10.0, 
            Default = Attacks.SmartSpin.DerivationMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartSpin.DerivationMult = v
            end
        }, "SmartSpinDerivationMult")
        
        uiElements.SmartSpinYReverse = UI.Sections.Attacks:Toggle({ 
            Name = "Y Reverse", 
            Default = Attacks.SmartSpin.YReverse, 
            Callback = function(v) 
                Attacks.SmartSpin.YReverse = v
            end
        }, "SmartSpinYReverse")
        
        UI.Sections.Attacks:Divider()
        
        -- SmartCandleMid
        UI.Sections.Attacks:Header({ Name = "SmartCandleMid" })
        
        uiElements.SmartCandleMidEnabled = UI.Sections.Attacks:Toggle({ 
            Name = "Enabled", 
            Default = Attacks.SmartCandleMid.Enabled, 
            Callback = function(v) 
                Attacks.SmartCandleMid.Enabled = v
            end
        }, "SmartCandleMidEnabled")
        
        uiElements.SmartCandleMidMinDist = UI.Sections.Attacks:Slider({ 
            Name = "Min Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartCandleMid.MinDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartCandleMid.MinDist = v
            end
        }, "SmartCandleMidMinDist")
        
        uiElements.SmartCandleMidMaxDist = UI.Sections.Attacks:Slider({ 
            Name = "Max Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.SmartCandleMid.MaxDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.SmartCandleMid.MaxDist = v
            end
        }, "SmartCandleMidMaxDist")
        
        uiElements.SmartCandleMidPowerAdd = UI.Sections.Attacks:Slider({ 
            Name = "Power Add", 
            Minimum = -5.0, 
            Maximum = 5.0, 
            Default = Attacks.SmartCandleMid.PowerAdd, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandleMid.PowerAdd = v
            end
        }, "SmartCandleMidPowerAdd")
        
        uiElements.SmartCandleMidXMult = UI.Sections.Attacks:Slider({ 
            Name = "X Mult", 
            Minimum = 0.1, 
            Maximum = 2.0, 
            Default = Attacks.SmartCandleMid.XMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandleMid.XMult = v
            end
        }, "SmartCandleMidXMult")
        
        uiElements.SmartCandleMidSpin = UI.Sections.Attacks:Toggle({ 
            Name = "Spin", 
            Default = Attacks.SmartCandleMid.Spin, 
            Callback = function(v) 
                Attacks.SmartCandleMid.Spin = v
            end
        }, "SmartCandleMidSpin")
        
        uiElements.SmartCandleMidHeightMult = UI.Sections.Attacks:Slider({ 
            Name = "Height Mult", 
            Minimum = 0.1, 
            Maximum = 3.0, 
            Default = Attacks.SmartCandleMid.HeightMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandleMid.HeightMult = v
            end
        }, "SmartCandleMidHeightMult")
        
        uiElements.SmartCandleMidBaseMin = UI.Sections.Attacks:Slider({ 
            Name = "Base Min", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartCandleMid.BaseHeightRange.Min, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandleMid.BaseHeightRange.Min = v
            end
        }, "SmartCandleMidBaseMin")
        
        uiElements.SmartCandleMidBaseMax = UI.Sections.Attacks:Slider({ 
            Name = "Base Max", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.SmartCandleMid.BaseHeightRange.Max, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandleMid.BaseHeightRange.Max = v
            end
        }, "SmartCandleMidBaseMax")
        
        uiElements.SmartCandleMidDerivationMult = UI.Sections.Attacks:Slider({ 
            Name = "Derivation Mult", 
            Minimum = 0.0, 
            Maximum = 10.0, 
            Default = Attacks.SmartCandleMid.DerivationMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.SmartCandleMid.DerivationMult = v
            end
        }, "SmartCandleMidDerivationMult")
        
        uiElements.SmartCandleMidYReverse = UI.Sections.Attacks:Toggle({ 
            Name = "Y Reverse", 
            Default = Attacks.SmartCandleMid.YReverse, 
            Callback = function(v) 
                Attacks.SmartCandleMid.YReverse = v
            end
        }, "SmartCandleMidYReverse")
        
        UI.Sections.Attacks:Divider()
        
        -- FarSmartCandle
        UI.Sections.Attacks:Header({ Name = "FarSmartCandle" })
        
        uiElements.FarSmartCandleEnabled = UI.Sections.Attacks:Toggle({ 
            Name = "Enabled", 
            Default = Attacks.FarSmartCandle.Enabled, 
            Callback = function(v) 
                Attacks.FarSmartCandle.Enabled = v
            end
        }, "FarSmartCandleEnabled")
        
        uiElements.FarSmartCandleMinDist = UI.Sections.Attacks:Slider({ 
            Name = "Min Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.FarSmartCandle.MinDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.FarSmartCandle.MinDist = v
            end
        }, "FarSmartCandleMinDist")
        
        uiElements.FarSmartCandleMaxDist = UI.Sections.Attacks:Slider({ 
            Name = "Max Dist", 
            Minimum = 0, 
            Maximum = 300, 
            Default = Attacks.FarSmartCandle.MaxDist, 
            Precision = 1, 
            Callback = function(v) 
                Attacks.FarSmartCandle.MaxDist = v
            end
        }, "FarSmartCandleMaxDist")
        
        uiElements.FarSmartCandlePower = UI.Sections.Attacks:Slider({ 
            Name = "Power", 
            Minimum = 0.5, 
            Maximum = 100.0, 
            Default = Attacks.FarSmartCandle.Power, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.FarSmartCandle.Power = v
            end
        }, "FarSmartCandlePower")
        
        uiElements.FarSmartCandleXMult = UI.Sections.Attacks:Slider({ 
            Name = "X Mult", 
            Minimum = 0.1, 
            Maximum = 2.0, 
            Default = Attacks.FarSmartCandle.XMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.FarSmartCandle.XMult = v
            end
        }, "FarSmartCandleXMult")
        
        uiElements.FarSmartCandleSpin = UI.Sections.Attacks:Toggle({ 
            Name = "Spin", 
            Default = Attacks.FarSmartCandle.Spin, 
            Callback = function(v) 
                Attacks.FarSmartCandle.Spin = v
            end
        }, "FarSmartCandleSpin")
        
        uiElements.FarSmartCandleHeightMult = UI.Sections.Attacks:Slider({ 
            Name = "Height Mult", 
            Minimum = 0.1, 
            Maximum = 3.0, 
            Default = Attacks.FarSmartCandle.HeightMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.FarSmartCandle.HeightMult = v
            end
        }, "FarSmartCandleHeightMult")
        
        uiElements.FarSmartCandleBaseMin = UI.Sections.Attacks:Slider({ 
            Name = "Base Min", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.FarSmartCandle.BaseHeightRange.Min, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.FarSmartCandle.BaseHeightRange.Min = v
            end
        }, "FarSmartCandleBaseMin")
        
        uiElements.FarSmartCandleBaseMax = UI.Sections.Attacks:Slider({ 
            Name = "Base Max", 
            Minimum = 0.0, 
            Maximum = 100.0, 
            Default = Attacks.FarSmartCandle.BaseHeightRange.Max, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.FarSmartCandle.BaseHeightRange.Max = v
            end
        }, "FarSmartCandleBaseMax")
        
        uiElements.FarSmartCandleDerivationMult = UI.Sections.Attacks:Slider({ 
            Name = "Derivation Mult", 
            Minimum = 0.0, 
            Maximum = 10.0, 
            Default = Attacks.FarSmartCandle.DerivationMult, 
            Precision = 2, 
            Callback = function(v) 
                Attacks.FarSmartCandle.DerivationMult = v
            end
        }, "FarSmartCandleDerivationMult")
        
        uiElements.FarSmartCandleYReverse = UI.Sections.Attacks:Toggle({ 
            Name = "Y Reverse", 
            Default = Attacks.FarSmartCandle.YReverse, 
            Callback = function(v) 
                Attacks.FarSmartCandle.YReverse = v
            end
        }, "FarSmartCandleYReverse")
    end
end

-- === МОДУЛЬ ===
local AutoShootModule = {}
function AutoShootModule.Init(UI, coreParam, notifyFunc)
    notify = notifyFunc
    
    -- Функция для инициализации значений из UI
    local function InitializeValuesFromUI()
        -- Эти значения будут установлены при первом создании UI
        -- UI библиотека автоматически загрузит сохраненные значения
    end
    
    SetupUI(UI)
    
    -- Запускаем таймер для проверки и обновления значений из UI
    -- Это фиксит проблему с загрузкой конфига
    local checkTimer = 0
    local function CheckUIValues()
        checkTimer = checkTimer + 1
        
        -- Проверяем и обновляем значения каждые 30 кадров (примерно 0.5 секунды)
        if checkTimer % 30 == 0 then
            -- Обновляем основные значения из UI элементов
            if uiElements.AutoShootMaxDist then
                local uiValue = uiElements.AutoShootMaxDist:GetValue()
                if uiValue ~= AutoShootMaxDistance then
                    AutoShootMaxDistance = uiValue
                    notify("AutoShoot", "Max Distance updated from UI: " .. uiValue, true)
                end
            end
            
            -- Обновляем другие слайдеры аналогично
            if uiElements.AdvancedInset then
                AutoShootInset = uiElements.AdvancedInset:GetValue()
            end
            
            if uiElements.AdvancedGravity then
                AutoShootGravity = uiElements.AdvancedGravity:GetValue()
            end
            
            if uiElements.AdvancedMinPower then
                AutoShootMinPower = uiElements.AdvancedMinPower:GetValue()
            end
            
            if uiElements.AdvancedMaxPower then
                AutoShootMaxPower = uiElements.AdvancedMaxPower:GetValue()
            end
            
            if uiElements.AdvancedPowerPerStud then
                AutoShootPowerPerStud = uiElements.AdvancedPowerPerStud:GetValue()
            end
            
            if uiElements.AdvancedMaxHeight then
                AutoShootMaxHeight = uiElements.AdvancedMaxHeight:GetValue()
            end
            
            -- Обновляем значения атак
            if uiElements.SideRicochetMinDist then
                Attacks.SideRicochet.MinDist = uiElements.SideRicochetMinDist:GetValue()
                Attacks.SideRicochet.MaxDist = uiElements.SideRicochetMaxDist:GetValue()
                Attacks.SideRicochet.Power = uiElements.SideRicochetPower:GetValue()
                Attacks.SideRicochet.XMult = uiElements.SideRicochetXMult:GetValue()
                Attacks.SideRicochet.HeightMult = uiElements.SideRicochetHeightMult:GetValue()
                Attacks.SideRicochet.BaseHeightRange.Min = uiElements.SideRicochetBaseMin:GetValue()
                Attacks.SideRicochet.BaseHeightRange.Max = uiElements.SideRicochetBaseMax:GetValue()
                Attacks.SideRicochet.DerivationMult = uiElements.SideRicochetDerivationMult:GetValue()
                Attacks.SideRicochet.YReverse = uiElements.SideRicochetYReverse:GetState()
            end
            
            -- Аналогично для других атак...
        end
    end
    
    -- Подключаем проверку значений
    local heartbeatConnection
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        CheckUIValues()
    end)
    
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(1)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
        BallAttachment = newChar:WaitForChild("ball")
        RShootAnim = Humanoid:LoadAnimation(Animations:WaitForChild("RShoot"))
        RShootAnim.Priority = Enum.AnimationPriority.Action4
        GoalCFrame = nil; TargetPoint = nil; NoSpinPoint = nil; LastShoot = 0; IsAnimating = false; CanShoot = true
        
        if AutoShootEnabled then AutoShoot.Start() end
        if AutoPickupEnabled then AutoPickup.Start() end
    end)
    
    -- Сохраняем соединение для очистки
    AutoShootModule.HeartbeatConnection = heartbeatConnection
end

function AutoShootModule:Destroy()
    AutoShoot.Stop()
    AutoPickup.Stop()
    if self.HeartbeatConnection then
        self.HeartbeatConnection:Disconnect()
        self.HeartbeatConnection = nil
    end
end

return AutoShootModule
