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

-- Параметры атак
local Attacks = {
    SideRicochet = { Enabled = true, MinDist = 0, MaxDist = 60, Power = 3.5, XMult = 0.8, Spin = "None", HeightMult = 1.0, BaseHeightRange = {Min = 0.15, Max = 0.34}, DerivationMult = 0.0, ZOffset = 2.0 },
    CloseSpin = { Enabled = true, MinDist = 0, MaxDist = 110, Power = 3.2, XMult = 1.1, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 0.3, Max = 0.9}, DerivationMult = 0.8, ZOffset = -5.0 },
    SmartCorner = { Enabled = true, MinDist = 0, MaxDist = 100, PowerMin = 2.8, XMult = 0.3, Spin = "None", HeightMult = 0.82, BaseHeightRange = {Min = 0.5, Max = 0.7}, DerivationMult = 0.3, ZOffset = 0.65 },
    SmartCandle = { Enabled = true, MinDist = 145, MaxDist = 180, Power = 3, XMult = 1.5, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 11, Max = 13}, DerivationMult = 2.8, ZOffset = -10 },
    SmartRicochet = { Enabled = true, MinDist = 80, MaxDist = 140, Power = 3.6, XMult = 0.9, Spin = true, HeightMult = 0.7, BaseHeightRange = {Min = 0.95, Max = 1.5}, DerivationMult = 1.6, ZOffset = 2 },
    SmartSpin = { Enabled = true, MinDist = 110, MaxDist = 155, PowerAdd = 0.6, XMult = 0.9, Spin = true, HeightMult = 0.75, BaseHeightRange = {Min = 0.7, Max = 1.5}, DerivationMult = 1.8, ZOffset = -5 },
    SmartCandleMid = { Enabled = false, MinDist = 100, MaxDist = 165, PowerAdd = 0.4, XMult = 0.7, Spin = true, HeightMult = 0.9, BaseHeightRange = {Min = 0.15, Max = 0.55}, DerivationMult = 1.35, ZOffset = 0.0 },
    FarSmartCandle = { Enabled = true, MinDist = 200, MaxDist = 300, Power = 60, XMult = 0.7, Spin = true, HeightMult = 1.8, BaseHeightRange = {Min = 40.0, Max = 80.0}, DerivationMult = 4.5, ZOffset = -10 }
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
    if isLowShot then baseHeight = 0.5
    elseif dist <= 80 then baseHeight = math.clamp(baseHeightRange.Min + (dist / 400), baseHeightRange.Min, baseHeightRange.Max)
    elseif dist <= 100 then baseHeight = math.clamp(baseHeightRange.Min + (dist / 200), baseHeightRange.Min, baseHeightRange.Max)
    elseif dist <= 140 then baseHeight = math.clamp(baseHeightRange.Min + (dist / 80), baseHeightRange.Min, baseHeightRange.Max)
    else
        if attackName == "SmartCandle" then baseHeight = math.clamp(8 + (dist / 25), baseHeightRange.Min, baseHeightRange.Max) * (dist >= 180 and 0.6 or 0.75)
        elseif attackName == "FarSmartCandle" then baseHeight = math.clamp(40 + (dist / 5), baseHeightRange.Min, baseHeightRange.Max) * (dist >= 250 and 2.2 or 2.0)
        else baseHeight = math.clamp(8 + (dist / 25), baseHeightRange.Min, baseHeightRange.Max) * 0.9 end
    end
    local timeToTarget = dist / 200
    local gravityFall = attackName == "FarSmartCandle" and 10 or 0.5 * AutoShootGravity * timeToTarget^2
    local height = math.clamp(baseHeight + gravityFall, isLowShot and 0.5 or 2.0, AutoShootMaxHeight)
    if power < 1.5 and attackName ~= "FarSmartCandle" then height = math.clamp(height * (power / 1.5), isLowShot and 0.5 or 2.0, height) end
    height = math.clamp(height * heightMult, isLowShot and 0.5 or 2.0, AutoShootMaxHeight)
    return height, timeToTarget, gravityFall, baseHeight
end

local TargetPoint, ShootDir, ShootVel, CurrentSpin, CurrentPower, CurrentType, NoSpinPoint
local LastShoot = 0
local CanShoot = true
local notify = function(title, text, success) end

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
        local zOffset = cfg.ZOffset or 0
        local heightAdjust = 0
        if name == "CloseSpin" and isOffAngle then zOffset = cfg.ZOffset; heightAdjust = GoalHeight - 0.5; xMult = 1.0 end
        if name == "CloseSpin" or name == "SmartCorner" then
            if (playerLocalX < 0 and targetSide < 0) or (playerLocalX > 0 and targetSide > 0) then xMult = math.clamp(xMult * 0.7, 0.5, 0.8) end
        end
        local targets = {{x=targetSide * halfWidth * xMult, y=0, type="Direct"}}
        if name == "CloseSpin" and isOffAngle then targets = {{x=(playerLocalX > 0 and -halfWidth or halfWidth) * 0.95, y=GoalHeight - 0.5, type="Corner"}}
        elseif name == "SmartCorner" then targets = ricochetPoints end
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
            if heightAdjust > 0 then height = math.clamp(heightAdjust, 2.0, AutoShootMaxHeight)
            elseif isLowShot then height = 0.5 end
            local noSpinPos = GoalCFrame * Vector3.new(math.clamp(x + randX, -halfWidth+0.5, halfWidth-0.5), height + randY, 0)
            local worldPos = GoalCFrame * Vector3.new(x + derivation + randX, height + randY, zOffset)
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
        local zOffset = playerLocalX < 0 and 2.0 or 0
        local derivation = dist >= 110 and (spin == "Left" and 1 or -1) * (dist / 100)^1.5 * 1.3 * power or 0
        local targets = ricochetPoints
        for _, target in ipairs(targets) do
            local x = target.x; local y = target.y; local targetType = target.type; local ricochetNormal = target.normal
            local randX = math.random(-0.15, 0.15) * halfWidth
            local randY = math.random(-0.15, 0.15) * halfHeight
            local noSpinPos = GoalCFrame * Vector3.new(math.clamp(x + randX, -halfWidth+0.5, halfWidth-0.5), height + randY, 0)
            local worldPos = GoalCFrame * Vector3.new(x + derivation + randX, height + randY, zOffset)
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
    if not GoalCFrame or not width then TargetPoint = nil; NoSpinPoint = nil; if Gui then Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --" end; return end
    local dist = (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude
    if Gui then Gui.Dist.Text = string.format("Dist: %.1f (Max: %.1f)", dist, AutoShootMaxDistance) end
    if dist > AutoShootMaxDistance then TargetPoint = nil; NoSpinPoint = nil; if Gui then Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --" end; return end
    local startPos = HumanoidRootPart.Position
    local goalDir = (GoalCFrame.Position - startPos).Unit
    local forwardDir = (HumanoidRootPart.CFrame.LookVector).Unit
    local playerAngle = math.deg(math.acos(goalDir:Dot(forwardDir)))
    local goalieHrp, goalieX, goalieY, _, isAggressive = GetEnemyGoalie()
    local goaliePos = goalieHrp and goalieHrp.Position or nil
    local worldTarget, spin, name, power, noSpinPos = GetTarget(dist, goalieX or 0, goalieY or 0, isAggressive or false, goaliePos, playerAngle)
    if not worldTarget then TargetPoint = nil; NoSpinPoint = nil; if Gui then Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --" end; return end
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
        if AutoShootStatus.ButtonGui then AutoShootStatus.ButtonGui:Destroy(); AutoShootStatus.ButtonGui = nil end
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
        if GoalCFrame and width then DrawOrientedCube(GoalCube, GoalCFrame, Vector3.new(width, GoalHeight, 2)) else for _, l in ipairs(GoalCube) do l.Visible = false end end
        if TargetPoint then DrawOrientedCube(TargetCube, CFrame.new(TargetPoint), Vector3.new(4,4,4)) else for _, l in ipairs(TargetCube) do l.Visible = false end end
        if NoSpinPoint then DrawOrientedCube(NoSpinCube, CFrame.new(NoSpinPoint), Vector3.new(3,3,3)) else for _, l in ipairs(NoSpinCube) do l.Visible = false end end
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
    for i = 1, 12 do if TargetCube[i] and TargetCube[i].Remove then TargetCube[i]:Remove() end; if GoalCube[i] and GoalCube[i].Remove then GoalCube[i]:Remove() end; if NoSpinCube[i] and NoSpinCube[i].Remove then NoSpinCube[i]:Remove() end end
    if AutoShootStatus.ButtonGui then AutoShootStatus.ButtonGui:Destroy(); AutoShootStatus.ButtonGui = nil end
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
        uiElements.AutoShootEnabled = UI.Sections.AutoShoot:Toggle({ Name = "Enabled", Default = AutoShootEnabled, Callback = function(v) AutoShootEnabled = v; if v then AutoShoot.Start() else AutoShoot.Stop() end end }, "AutoShootEnabled")
        uiElements.AutoShootLegit = UI.Sections.AutoShoot:Toggle({ Name = "Legit Animation", Default = AutoShootLegit, Callback = function(v) AutoShootLegit = v end }, "AutoShootLegit")
        UI.Sections.AutoShoot:Divider()
        uiElements.AutoShootManual = UI.Sections.AutoShoot:Toggle({ Name = "Manual Shot", Default = AutoShootManualShot, Callback = function(v) AutoShootManualShot = v; UpdateModeText() end }, "AutoShootManual")
        uiElements.AutoShootKey = UI.Sections.AutoShoot:Keybind({ Name = "Shoot Key", Default = AutoShootShootKey, Callback = function(v) AutoShootShootKey = v; UpdateModeText() end }, "AutoShootKey")
        uiElements.AutoShootManualButton = UI.Sections.AutoShoot:Toggle({ Name = "Manual Button", Default = AutoShootManualButton, Callback = ToggleManualButton }, "AutoShootManualButton")
        uiElements.AutoShootButtonScale = UI.Sections.AutoShoot:Slider({ Name = "Button Scale", Minimum = 0.5, Maximum = 2.0, Default = AutoShootButtonScale, Precision = 2, Callback = SetButtonScale }, "AutoShootButtonScale")
        UI.Sections.AutoShoot:Divider()
        uiElements.AutoShootMaxDist = UI.Sections.AutoShoot:Slider({ Name = "Max Distance", Minimum = 50, Maximum = 300, Default = AutoShootMaxDistance, Precision = 1, Callback = function(v) AutoShootMaxDistance = v end }, "AutoShootMaxDist")
        uiElements.AutoShootDebugText = UI.Sections.AutoShoot:Toggle({ Name = "Debug Text", Default = AutoShootDebugText, Callback = function(v) AutoShoot.SetDebugText(v) end }, "AutoShootDebugText")
    end

    if UI.Sections.AutoPickup then
        UI.Sections.AutoPickup:Header({ Name = "AutoPickup" })
        UI.Sections.AutoPickup:Divider()
        uiElements.AutoPickupEnabled = UI.Sections.AutoPickup:Toggle({ Name = "Enabled", Default = AutoPickupEnabled, Callback = function(v) AutoPickupEnabled = v; if v then AutoPickup.Start() else AutoPickup.Stop() end end }, "AutoPickupEnabled")
        uiElements.AutoPickupDist = UI.Sections.AutoPickup:Slider({ Name = "Pickup Distance", Minimum = 10, Maximum = 100, Default = AutoPickupDist, Precision = 1, Callback = function(v) AutoPickupDist = v end }, "AutoPickupDist")
        UI.Sections.AutoPickup:Divider()
        uiElements.AutoPickupSpoof = UI.Sections.AutoPickup:Slider({ Name = "Spoof Value", Minimum = 0.1, Maximum = 5.0, Default = AutoPickupSpoofValue, Precision = 2, Callback = function(v) AutoPickupSpoofValue = v end }, "AutoPickupSpoof")
        UI.Sections.AutoPickup:SubLabel({Text = '[💠] The distance from you to the ball that is sent to the server'})
    end

    if UI.Sections.AdvancedPrediction then
        UI.Sections.AdvancedPrediction:Header({ Name = "Advanced Prediction (AutoShoot)" })
        UI.Sections.AdvancedPrediction:Divider()
        uiElements.AdvancedInset = UI.Sections.AdvancedPrediction:Slider({ Name = "Goal Inset", Minimum = 0, Maximum = 5, Default = AutoShootInset, Precision = 1, Callback = function(v) AutoShootInset = v end }, "AdvancedInset")
        UI.Sections.AdvancedPrediction:SubLabel({Text ='[💠] Indentation from the edges of the gate (in studs)'})
        UI.Sections.AdvancedPrediction:Divider()
        uiElements.AdvancedGravity = UI.Sections.AdvancedPrediction:Slider({ Name = "Gravity", Minimum = 50, Maximum = 200, Default = AutoShootGravity, Precision = 1, Callback = function(v) AutoShootGravity = v end }, "AdvancedGravity")
        UI.Sections.AdvancedPrediction:Divider()
        uiElements.AdvancedMinPower = UI.Sections.AdvancedPrediction:Slider({ Name = "Min Power", Minimum = 1.0, Maximum = 10.0, Default = AutoShootMinPower, Precision = 2, Callback = function(v) AutoShootMinPower = v end }, "AdvancedMinPower")
        uiElements.AdvancedMaxPower = UI.Sections.AdvancedPrediction:Slider({ Name = "Max Power", Minimum = 5.0, Maximum = 15.0, Default = AutoShootMaxPower, Precision = 2, Callback = function(v) AutoShootMaxPower = v end }, "AdvancedMaxPower")
        uiElements.AdvancedPowerPerStud = UI.Sections.AdvancedPrediction:Slider({ Name = "Power Per Stud", Minimum = 0.001, Maximum = 0.1, Default = AutoShootPowerPerStud, Precision = 3, Callback = function(v) AutoShootPowerPerStud = v end }, "AdvancedPowerPerStud")
        UI.Sections.AdvancedPrediction:Divider()
        uiElements.AdvancedMaxHeight = UI.Sections.AdvancedPrediction:Slider({ Name = "Max Height", Minimum = 50, Maximum = 200, Default = AutoShootMaxHeight, Precision = 1, Callback = function(v) AutoShootMaxHeight = v end }, "AdvancedMaxHeight")
        UI.Sections.AdvancedPrediction:SubLabel({Text ='[💠] The maximum height of the ball flight (in studs)'})
    end

    if UI.Sections.Attacks then
        UI.Sections.Attacks:Header({ Name = "AutoShoot Attacks" })
        UI.Sections.Attacks:Divider()
        
        for attackName, cfg in pairs(Attacks) do
            UI.Sections.Attacks:Header({ Name = attackName })
            uiElements[attackName.."Enabled"] = UI.Sections.Attacks:Toggle({ Name = "Enabled", Default = cfg.Enabled, Callback = function(v) Attacks[attackName].Enabled = v end }, attackName.."Enabled")
            
            if cfg.MinDist then
                uiElements[attackName.."MinDist"] = UI.Sections.Attacks:Slider({ Name = "Min Dist", Minimum = 0, Maximum = 300, Default = cfg.MinDist, Precision = 1, Callback = function(v) Attacks[attackName].MinDist = v end }, attackName.."MinDist")
            end
            
            if cfg.MaxDist then
                uiElements[attackName.."MaxDist"] = UI.Sections.Attacks:Slider({ Name = "Max Dist", Minimum = 0, Maximum = 300, Default = cfg.MaxDist, Precision = 1, Callback = function(v) Attacks[attackName].MaxDist = v end }, attackName.."MaxDist")
            end
            
            if cfg.Power then
                uiElements[attackName.."Power"] = UI.Sections.Attacks:Slider({ Name = "Power", Minimum = 0.5, Maximum = 100.0, Default = cfg.Power, Precision = 2, Callback = function(v) Attacks[attackName].Power = v end }, attackName.."Power")
            end
            
            if cfg.PowerMin then
                uiElements[attackName.."PowerMin"] = UI.Sections.Attacks:Slider({ Name = "Power Min", Minimum = 0.5, Maximum = 10.0, Default = cfg.PowerMin, Precision = 2, Callback = function(v) Attacks[attackName].PowerMin = v end }, attackName.."PowerMin")
            end
            
            if cfg.PowerAdd then
                uiElements[attackName.."PowerAdd"] = UI.Sections.Attacks:Slider({ Name = "Power Add", Minimum = -5.0, Maximum = 5.0, Default = cfg.PowerAdd, Precision = 2, Callback = function(v) Attacks[attackName].PowerAdd = v end }, attackName.."PowerAdd")
            end
            
            if cfg.XMult then
                uiElements[attackName.."XMult"] = UI.Sections.Attacks:Slider({ Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = cfg.XMult, Precision = 2, Callback = function(v) Attacks[attackName].XMult = v end }, attackName.."XMult")
            end
            
            if cfg.Spin and type(cfg.Spin) == "boolean" then
                uiElements[attackName.."Spin"] = UI.Sections.Attacks:Toggle({ Name = "Spin", Default = cfg.Spin, Callback = function(v) Attacks[attackName].Spin = v end }, attackName.."Spin")
            end
            
            if cfg.HeightMult then
                uiElements[attackName.."HeightMult"] = UI.Sections.Attacks:Slider({ Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = cfg.HeightMult, Precision = 2, Callback = function(v) Attacks[attackName].HeightMult = v end }, attackName.."HeightMult")
            end
            
            if cfg.BaseHeightRange then
                uiElements[attackName.."BaseMin"] = UI.Sections.Attacks:Slider({ Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = cfg.BaseHeightRange.Min, Precision = 2, Callback = function(v) Attacks[attackName].BaseHeightRange.Min = v end }, attackName.."BaseMin")
                uiElements[attackName.."BaseMax"] = UI.Sections.Attacks:Slider({ Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = cfg.BaseHeightRange.Max, Precision = 2, Callback = function(v) Attacks[attackName].BaseHeightRange.Max = v end }, attackName.."BaseMax")
            end
            
            if cfg.DerivationMult then
                uiElements[attackName.."DerivationMult"] = UI.Sections.Attacks:Slider({ Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = cfg.DerivationMult, Precision = 2, Callback = function(v) Attacks[attackName].DerivationMult = v end }, attackName.."DerivationMult")
            end
            
            if cfg.ZOffset then
                uiElements[attackName.."ZOffset"] = UI.Sections.Attacks:Slider({ Name = "Z Offset", Minimum = -20.0, Maximum = 20.0, Default = cfg.ZOffset, Precision = 2, Callback = function(v) Attacks[attackName].ZOffset = v end }, attackName.."ZOffset")
            end
            
            UI.Sections.Attacks:Divider()
        end
    end

    local syncSection = UI.Tabs.Config:Section({ Name = "AutoShoot & AutoPickup Sync", Side = "Right" })
    syncSection:Header({ Name = "AutoShoot/AutoPickup" })
    syncSection:Button({ Name = "Sync Config", Callback = function()
        AutoShootEnabled = uiElements.AutoShootEnabled:GetState()
        AutoShootLegit = uiElements.AutoShootLegit:GetState()
        AutoShootManualShot = uiElements.AutoShootManual:GetState()
        AutoShootShootKey = uiElements.AutoShootKey:GetBind()
        AutoShootMaxDistance = uiElements.AutoShootMaxDist:GetValue()
        AutoShootDebugText = uiElements.AutoShootDebugText:GetState()
        AutoShootManualButton = uiElements.AutoShootManualButton:GetState()
        AutoShootButtonScale = uiElements.AutoShootButtonScale:GetValue()
        AutoShootInset = uiElements.AdvancedInset:GetValue()
        AutoShootGravity = uiElements.AdvancedGravity:GetValue()
        AutoShootMinPower = uiElements.AdvancedMinPower:GetValue()
        AutoShootMaxPower = uiElements.AdvancedMaxPower:GetValue()
        AutoShootPowerPerStud = uiElements.AdvancedPowerPerStud:GetValue()
        AutoShootMaxHeight = uiElements.AdvancedMaxHeight:GetValue()
        
        for attackName, _ in pairs(Attacks) do
            if uiElements[attackName.."Enabled"] then Attacks[attackName].Enabled = uiElements[attackName.."Enabled"]:GetState() end
            if uiElements[attackName.."MinDist"] then Attacks[attackName].MinDist = uiElements[attackName.."MinDist"]:GetValue() end
            if uiElements[attackName.."MaxDist"] then Attacks[attackName].MaxDist = uiElements[attackName.."MaxDist"]:GetValue() end
            if uiElements[attackName.."Power"] then Attacks[attackName].Power = uiElements[attackName.."Power"]:GetValue() end
            if uiElements[attackName.."PowerMin"] then Attacks[attackName].PowerMin = uiElements[attackName.."PowerMin"]:GetValue() end
            if uiElements[attackName.."PowerAdd"] then Attacks[attackName].PowerAdd = uiElements[attackName.."PowerAdd"]:GetValue() end
            if uiElements[attackName.."XMult"] then Attacks[attackName].XMult = uiElements[attackName.."XMult"]:GetValue() end
            if uiElements[attackName.."Spin"] then Attacks[attackName].Spin = uiElements[attackName.."Spin"]:GetState() end
            if uiElements[attackName.."HeightMult"] then Attacks[attackName].HeightMult = uiElements[attackName.."HeightMult"]:GetValue() end
            if uiElements[attackName.."BaseMin"] then Attacks[attackName].BaseHeightRange.Min = uiElements[attackName.."BaseMin"]:GetValue() end
            if uiElements[attackName.."BaseMax"] then Attacks[attackName].BaseHeightRange.Max = uiElements[attackName.."BaseMax"]:GetValue() end
            if uiElements[attackName.."DerivationMult"] then Attacks[attackName].DerivationMult = uiElements[attackName.."DerivationMult"]:GetValue() end
            if uiElements[attackName.."ZOffset"] then Attacks[attackName].ZOffset = uiElements[attackName.."ZOffset"]:GetValue() end
        end
        
        AutoPickupEnabled = uiElements.AutoPickupEnabled:GetState()
        AutoPickupDist = uiElements.AutoPickupDist:GetValue()
        AutoPickupSpoofValue = uiElements.AutoPickupSpoof:GetValue()
        
        UpdateModeText()
        ToggleDebugText(AutoShootDebugText)
        ToggleManualButton(AutoShootManualButton)
        if AutoShootEnabled then if not AutoShootStatus.Running then AutoShoot.Start() end else if AutoShootStatus.Running then AutoShoot.Stop() end end
        if AutoPickupEnabled then if not AutoPickupStatus.Running then AutoPickup.Start() end else if AutoPickupStatus.Running then AutoPickup.Stop() end end
        notify("Syllinse", "Config synchronized!", true)
    end })
end

-- === МОДУЛЬ ===
local AutoShootModule = {}
function AutoShootModule.Init(UI, coreParam, notifyFunc)
    local core = coreParam
    notify = notifyFunc
    SetupUI(UI)
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
end

function AutoShootModule:Destroy()
    AutoShoot.Stop()
    AutoPickup.Stop()
end

return AutoShootModule
