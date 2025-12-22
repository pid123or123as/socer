-- [v35.43] AUTO SHOOT + AUTO PICKUP + FULL GUI + UI INTEGRATION (РАБОЧАЯ ВЕРСИЯ С ИСПРАВЛЕНИЯМИ)
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

-- === CONFIG ===
local AutoShootConfig = {
    Enabled = false,
    Legit = true,
    ManualShot = true,
    ShootKey = Enum.KeyCode.G,
    MaxDistance = 160,
    Inset = 2,
    Gravity = 110,
    MinPower = 4.0,
    MaxPower = 7.0,
    PowerPerStud = 0.025,
    MaxHeight = 100.0,
    DebugText = true,
    ManualButton = false,
    ButtonScale = 1.0,
    Attacks = {
        SideRicochet = { Enabled = true, MinDist = 0, MaxDist = 60, Power = 3.5, XMult = 0.8, Spin = "None", HeightMult = 1.0, BaseHeightRange = {Min = 0.15, Max = 0.34}, DerivationMult = 0.0, ZOffset = 2.0 },
        CloseSpin = { Enabled = true, MinDist = 0, MaxDist = 110, Power = 3.2, XMult = 1.1, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 0.3, Max = 0.9}, DerivationMult = 0.8, ZOffset = -5.0 },
        SmartCorner = { Enabled = true, MinDist = 0, MaxDist = 100, PowerMin = 2.8, XMult = 0.3, Spin = "None", HeightMult = 0.82, BaseHeightRange = {Min = 0.5, Max = 0.7}, DerivationMult = 0.3, ZOffset = 0.65 },
        SmartCandle = { Enabled = true, MinDist = 145, MaxDist = 180, Power = 3, XMult = 1.5, Spin = true, HeightMult = 1.1, BaseHeightRange = {Min = 11, Max = 13}, DerivationMult = 2.8, ZOffset = -10 },
        SmartRicochet = { Enabled = true, MinDist = 80, MaxDist = 140, Power = 3.6, XMult = 0.9, Spin = true, HeightMult = 0.7, BaseHeightRange = {Min = 0.95, Max = 1.5}, DerivationMult = 1.6, ZOffset = 2 },
        SmartSpin = { Enabled = true, MinDist = 110, MaxDist = 155, PowerAdd = 0.6, XMult = 0.9, Spin = true, HeightMult = 0.75, BaseHeightRange = {Min = 0.7, Max = 1.5}, DerivationMult = 1.8, ZOffset = -5 },
        SmartCandleMid = { Enabled = false, MinDist = 100, MaxDist = 165, PowerAdd = 0.4, XMult = 0.7, Spin = true, HeightMult = 0.9, BaseHeightRange = {Min = 0.15, Max = 0.55}, DerivationMult = 1.35, ZOffset = 0.0 },
        FarSmartCandle = { Enabled = true, MinDist = 200, MaxDist = 300, Power = 60, XMult = 0.7, Spin = true, HeightMult = 1.8, BaseHeightRange = {Min = 40.0, Max = 80.0}, DerivationMult = 4.5, ZOffset = -10 }
    }
}
local AutoPickupConfig = {
    Enabled = true,
    PickupDist = 180,
    SpoofValue = 2.8
}
-- === STATUS ===
local AutoShootStatus = {
    Running = false,
    Connection = nil,
    RenderConnection = nil,
    Key = AutoShootConfig.ShootKey,
    ManualShot = AutoShootConfig.ManualShot,
    DebugText = AutoShootConfig.DebugText,
    ManualButton = AutoShootConfig.ManualButton,
    ButtonScale = AutoShootConfig.ButtonScale,
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
        v.Position = Vector2.new(cx, y + (i-1)*20); v.Visible = AutoShootStatus.DebugText
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
    Gui.Mode.Text = AutoShootStatus.ManualShot and string.format("Mode: Manual (%s)", GetKeyName(AutoShootStatus.Key)) or "Mode: Auto"
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
    local left, right, crossbar = frame:FindFirstChild("LeftPost"), frame:FindFirstChild("RightPost"), frame:FindFirstChild("Crossbar")
    if not (left and right and crossbar) then return nil, nil end
    local center = (left.Position + right.Position) / 2
    local forward = (center - crossbar.Position).Unit
    local up = crossbar.Position.Y > left.Position.Y and Vector3.yAxis or -Vector3.yAxis
    local rightDir = (right.Position - left.Position).Unit
    GoalCFrame = CFrame.fromMatrix(center, rightDir, up, -forward)
    GoalWidth = (left.Position - right.Position).Magnitude
    GoalHeight = math.abs(crossbar.Position.Y - left.Position.Y)
    return GoalWidth, GoalHeight
end
local function GetEnemyGoalie()
    local myTeam = GetMyTeam()
    if not myTeam then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150); return nil, 0, 0, "None", false end
    local width = UpdateGoal()
    if not width then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150); return nil, 0, 0, "None", false end
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
    if #goalies == 0 then Gui.GK.Text = "GK: None"; Gui.GK.Color = Color3.fromRGB(150,150,150); return nil, 0, 0, "None", false end
    table.sort(goalies, function(a, b) if a.isInGoal ~= b.isInGoal then return a.isInGoal end; return a.distGoal < b.distGoal end)
    local best = goalies[1]
    local isAggressive = not best.isInGoal
    Gui.GK.Text = string.format("GK: %s %s | X=%.1f, Y=%.1f", best.name, best.isInGoal and "(In Goal)" or "(Aggressive)", best.localX, best.localY)
    Gui.GK.Color = Color3.fromRGB(255, 200, 0)
    return best.hrp, best.localX, best.localY, best.name, isAggressive
end
local function CalculateTrajectoryHeight(dist, power, attackName, isLowShot)
    local cfg = AutoShootConfig.Attacks[attackName] or {}
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
    local gravityFall = attackName == "FarSmartCandle" and 10 or 0.5 * AutoShootConfig.Gravity * timeToTarget^2
    local height = math.clamp(baseHeight + gravityFall, isLowShot and 0.5 or 2.0, AutoShootConfig.MaxHeight)
    if power < 1.5 and attackName ~= "FarSmartCandle" then height = math.clamp(height * (power / 1.5), isLowShot and 0.5 or 2.0, height) end
    height = math.clamp(height * heightMult, isLowShot and 0.5 or 2.0, AutoShootConfig.MaxHeight)
    return height, timeToTarget, gravityFall, baseHeight
end
local TargetPoint, ShootDir, ShootVel, CurrentSpin, CurrentPower, CurrentType, NoSpinPoint
local LastShoot = 0
local CanShoot = true
local function GetTarget(dist, goalieX, goalieY, isAggressive, goaliePos, playerAngle)
    if not GoalCFrame or not GoalWidth then return nil, "None", "None", 0 end
    if dist > AutoShootConfig.MaxDistance then return nil, "None", "None", 0 end
    local startPos = HumanoidRootPart.Position
    local halfWidth = (GoalWidth / 2) - AutoShootConfig.Inset
    local halfHeight = (GoalHeight / 2) - AutoShootConfig.Inset
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
    for name, cfg in pairs(AutoShootConfig.Attacks) do
        if not cfg.Enabled or dist < cfg.MinDist or dist > math.min(cfg.MaxDist, AutoShootConfig.MaxDistance) then continue end
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
            local power = cfg.Power or math.clamp(AutoShootConfig.MinPower + dist * AutoShootConfig.PowerPerStud, cfg.PowerMin or AutoShootConfig.MinPower, AutoShootConfig.MaxPower)
            power += cfg.PowerAdd or 0
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
            if heightAdjust > 0 then height = math.clamp(heightAdjust, 2.0, AutoShootConfig.MaxHeight)
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
        local power = math.clamp(AutoShootConfig.MinPower + dist * AutoShootConfig.PowerPerStud, AutoShootConfig.MinPower, AutoShootConfig.MaxPower)
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
    if not GoalCFrame or not width then TargetPoint = nil; NoSpinPoint = nil; Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --"; return end
    local dist = (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude
    Gui.Dist.Text = string.format("Dist: %.1f (Max: %.1f)", dist, AutoShootConfig.MaxDistance)
    if dist > AutoShootConfig.MaxDistance then TargetPoint = nil; NoSpinPoint = nil; Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --"; return end
    local startPos = HumanoidRootPart.Position
    local goalDir = (GoalCFrame.Position - startPos).Unit
    local forwardDir = (HumanoidRootPart.CFrame.LookVector).Unit
    local playerAngle = math.deg(math.acos(goalDir:Dot(forwardDir)))
    local goalieHrp, goalieX, goalieY, _, isAggressive = GetEnemyGoalie()
    local goaliePos = goalieHrp and goalieHrp.Position or nil
    local worldTarget, spin, name, power, noSpinPos = GetTarget(dist, goalieX or 0, goalieY or 0, isAggressive or false, goaliePos, playerAngle)
    if not worldTarget then TargetPoint = nil; NoSpinPoint = nil; Gui.Target.Text = "Target: --"; Gui.Power.Text = "Power: --"; Gui.Spin.Text = "Spin: --"; return end
    TargetPoint = worldTarget
    NoSpinPoint = noSpinPos
    CurrentSpin = spin
    CurrentType = name
    CurrentPower = power
    ShootDir = (worldTarget - startPos).Unit
    ShootVel = ShootDir * (power * 1400)
    Gui.Target.Text = "Target: " .. name
    Gui.Power.Text = string.format("Power: %.2f", power)
    Gui.Spin.Text = "Spin: " .. spin
end
-- === MANUAL BUTTON ===
local function SetupManualButton()
    if AutoShootStatus.ButtonGui then AutoShootStatus.ButtonGui:Destroy() end
    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "ManualShootButtonGui"
    buttonGui.ResetOnSpawn = false
    buttonGui.IgnoreGuiInset = false
    buttonGui.Parent = game:GetService("CoreGui")
    local size = 50 * AutoShootStatus.ButtonScale
    local screenSize = Camera.ViewportSize
    local initialX = screenSize.X / 2 - size / 2
    local initialY = screenSize.Y / 2 - size / 2
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0, size, 0, size)
    buttonFrame.Position = UDim2.new(0, initialX, 0, initialY)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Visible = AutoShootStatus.ManualButton
    buttonFrame.Parent = buttonGui
    Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)
    local buttonIcon = Instance.new("ImageLabel")
    buttonIcon.Size = UDim2.new(0, size*0.6, 0, size*0.6)
    buttonIcon.Position = UDim2.new(0.5, -size*0.3, 0.5, -size*0.3)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Image = "rbxassetid://73279554401260" -- Замените на подходящую иконку
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
                        if AutoShootConfig.Legit and not IsAnimating then
                            IsAnimating = true
                            RShootAnim:Play()
                            task.delay(AnimationHoldTime, function() IsAnimating = false end)
                        end
                        local success = pcall(function()
                            Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
                        end)
                        if success then
                            notify("AutoShoot", "Manual Shoot", true)
                            Gui.Status.Text = "MANUAL SHOT! [" .. CurrentType .. "]"
                            Gui.Status.Color = Color3.fromRGB(0,255,0)
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
    AutoShootStatus.ManualButton = value
    AutoShootConfig.ManualButton = value
    if value then
        SetupManualButton()
    else
        if AutoShootStatus.ButtonGui then AutoShootStatus.ButtonGui:Destroy(); AutoShootStatus.ButtonGui = nil end
    end
end
local function SetButtonScale(value)
    AutoShootStatus.ButtonScale = value
    AutoShootConfig.ButtonScale = value
    if AutoShootStatus.ManualButton then SetupManualButton() end
end
-- === AUTO SHOOT ===
local AutoShoot = {}
AutoShoot.Start = function()
    if AutoShootStatus.Running then return end
    AutoShootStatus.Running = true
    SetupGUI()
    InitializeCubes()
    UpdateModeText()
    if AutoShootStatus.ManualButton then SetupManualButton() end
    AutoShootStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoShootConfig.Enabled then return end
        pcall(CalculateTarget)
        local ball = Workspace:FindFirstChild("ball")
        local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
        local dist = GoalCFrame and (HumanoidRootPart.Position - GoalCFrame.Position).Magnitude or 999
        if hasBall and TargetPoint and dist <= AutoShootConfig.MaxDistance then
            Gui.Status.Text = AutoShootStatus.ManualShot and "Ready (Press " .. GetKeyName(AutoShootStatus.Key) .. ")" or "Aiming..."
            Gui.Status.Color = Color3.fromRGB(0,255,0)
        elseif hasBall then
            Gui.Status.Text = dist > AutoShootConfig.MaxDistance and "Too Far" or "No Target"
            Gui.Status.Color = Color3.fromRGB(255,100,0)
        else
            Gui.Status.Text = "No Ball"
            Gui.Status.Color = Color3.fromRGB(255,165,0)
        end
        if hasBall and TargetPoint and dist <= AutoShootConfig.MaxDistance and not AutoShootStatus.ManualShot and tick() - LastShoot >= 0.3 then
            if AutoShootConfig.Legit and not IsAnimating then
                IsAnimating = true
                RShootAnim:Play()
                task.delay(AnimationHoldTime, function() IsAnimating = false end)
            end
            pcall(function()
                Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
            end)
            Gui.Status.Text = "AUTO SHOT! [" .. CurrentType .. "]"
            Gui.Status.Color = Color3.fromRGB(0,255,0)
            LastShoot = tick()
        end
    end)
    -- Ручной выстрел по клавише
    AutoShootStatus.InputConnection = UserInputService.InputBegan:Connect(function(inp, gp)
        if gp or not AutoShootConfig.Enabled or not AutoShootStatus.ManualShot or not CanShoot then return end
        if inp.KeyCode == AutoShootStatus.Key then
            local ball = Workspace:FindFirstChild("ball")
            local hasBall = ball and ball:FindFirstChild("playerWeld") and ball.creator.Value == LocalPlayer
            if hasBall and TargetPoint then
                pcall(CalculateTarget)
                if ShootDir then
                    if AutoShootConfig.Legit and not IsAnimating then
                        IsAnimating = true
                        RShootAnim:Play()
                        task.delay(AnimationHoldTime, function() IsAnimating = false end)
                    end
                    local success = pcall(function()
                        Shooter:FireServer(ShootDir, BallAttachment.CFrame, CurrentPower, ShootVel, false, false, CurrentSpin, nil, false)
                    end)
                    if success then
                        notify("AutoShoot", "Manual Shoot", true)
                        Gui.Status.Text = "MANUAL SHOT! [" .. CurrentType .. "]"
                        Gui.Status.Color = Color3.fromRGB(0,255,0)
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
    AutoShootStatus.DebugText = value
    AutoShootConfig.DebugText = value
    ToggleDebugText(value)
    notify("AutoShoot", "Debug Text " .. (value and "Enabled" or "Disabled"), true)
end
-- === AUTO PICKUP ===
local AutoPickup = {}
AutoPickup.Start = function()
    if AutoPickupStatus.Running then return end
    AutoPickupStatus.Running = true
    AutoPickupStatus.Connection = RunService.Heartbeat:Connect(function()
        if not AutoPickupConfig.Enabled or not PickupRemote then return end
        local ball = Workspace:FindFirstChild("ball")
        if not ball or ball:FindFirstChild("playerWeld") then return end
        if (HumanoidRootPart.Position - ball.Position).Magnitude <= AutoPickupConfig.PickupDist then
            pcall(function() PickupRemote:FireServer(AutoPickupConfig.SpoofValue) end)
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
        uiElements.AutoShootEnabled = UI.Sections.AutoShoot:Toggle({ Name = "Enabled", Default = AutoShootConfig.Enabled, Callback = function(v) AutoShootConfig.Enabled = v; if v then AutoShoot.Start() else AutoShoot.Stop() end end }, "AutoShootEnabled")
        uiElements.AutoShootLegit = UI.Sections.AutoShoot:Toggle({ Name = "Legit Animation", Default = AutoShootConfig.Legit, Callback = function(v) AutoShootConfig.Legit = v end }, "AutoShootLegit")
        UI.Sections.AutoShoot:Divider()
        uiElements.AutoShootManual = UI.Sections.AutoShoot:Toggle({ Name = "Manual Shot", Default = AutoShootConfig.ManualShot, Callback = function(v) AutoShootStatus.ManualShot = v; AutoShootConfig.ManualShot = v; UpdateModeText() end }, "AutoShootManual")
        uiElements.AutoShootKey = UI.Sections.AutoShoot:Keybind({ Name = "Shoot Key", Default = AutoShootConfig.ShootKey, Callback = function(v) AutoShootStatus.Key = v; AutoShootConfig.ShootKey = v; UpdateModeText() end }, "AutoShootKey")
        uiElements.AutoShootManualButton = UI.Sections.AutoShoot:Toggle({ Name = "Manual Button", Default = AutoShootConfig.ManualButton, Callback = ToggleManualButton }, "AutoShootManualButton")
        uiElements.AutoShootButtonScale = UI.Sections.AutoShoot:Slider({ Name = "Button Scale", Minimum = 0.5, Maximum = 2.0, Default = AutoShootConfig.ButtonScale, Precision = 2, Callback = SetButtonScale }, "AutoShootButtonScale")
        UI.Sections.AutoShoot:Divider()
        uiElements.AutoShootMaxDist = UI.Sections.AutoShoot:Slider({ Name = "Max Distance", Minimum = 50, Maximum = 300, Default = AutoShootConfig.MaxDistance, Precision = 1, Callback = function(v) AutoShootConfig.MaxDistance = v end }, "AutoShootMaxDist")
        uiElements.AutoShootDebugText = UI.Sections.AutoShoot:Toggle({ Name = "Debug Text", Default = AutoShootConfig.DebugText, Callback = function(v) AutoShoot.SetDebugText(v) end }, "AutoShootDebugText")
    end

    if UI.Sections.AutoPickup then
        UI.Sections.AutoPickup:Header({ Name = "AutoPickup" })
        UI.Sections.AutoPickup:Divider()
        uiElements.AutoPickupEnabled = UI.Sections.AutoPickup:Toggle({ Name = "Enabled", Default = AutoPickupConfig.Enabled, Callback = function(v) AutoPickupConfig.Enabled = v; if v then AutoPickup.Start() else AutoPickup.Stop() end end }, "AutoPickupEnabled")
        uiElements.AutoPickupDist = UI.Sections.AutoPickup:Slider({ Name = "Pickup Distance", Minimum = 10, Maximum = 100, Default = AutoPickupConfig.PickupDist, Precision = 1, Callback = function(v) AutoPickupConfig.PickupDist = v end }, "AutoPickupDist")
        UI.Sections.AutoPickup:Divider()
        uiElements.AutoPickupSpoof = UI.Sections.AutoPickup:Slider({ Name = "Spoof Value", Minimum = 0.1, Maximum = 5.0, Default = AutoPickupConfig.SpoofValue, Precision = 2, Callback = function(v) AutoPickupConfig.SpoofValue = v end }, "AutoPickupSpoof")
        UI.Sections.AutoPickup:SubLabel({
            Text = '[💠] The distance from you to the ball that is sent to the server'
        })
    end



    if UI.Sections.AdvancedPrediction then
        UI.Sections.AdvancedPrediction:Header({ Name = "Advanced Prediction (AutoShoot)" })
    UI.Sections.AdvancedPrediction:Divider()
    uiElements.AdvancedInset = UI.Sections.AdvancedPrediction:Slider({ 
        Name = "Goal Inset", Minimum = 0, Maximum = 5, Default = AutoShootConfig.Inset, Precision = 1, 
        Callback = function(v) AutoShootConfig.Inset = v end 
    }, "AdvancedInset")
    UI.Sections.AdvancedPrediction:SubLabel({
        Text ='[💠] Indentation from the edges of the gate (in studs) / reduces the hitting area so that the ball does not hit the bars/crossbar.'
    })
    UI.Sections.AdvancedPrediction:Divider()
    uiElements.AdvancedGravity = UI.Sections.AdvancedPrediction:Slider({ 
        Name = "Gravity", Minimum = 50, Maximum = 200, Default = AutoShootConfig.Gravity, Precision = 1, 
        Callback = function(v) AutoShootConfig.Gravity = v end 
    }, "AdvancedGravity")
    UI.Sections.AdvancedPrediction:Divider()
    uiElements.AdvancedMinPower = UI.Sections.AdvancedPrediction:Slider({ 
        Name = "Min Power", Minimum = 1.0, Maximum = 10.0, Default = AutoShootConfig.MinPower, Precision = 2, 
        Callback = function(v) AutoShootConfig.MinPower = v end 
    }, "AdvancedMinPower")

    uiElements.AdvancedMaxPower = UI.Sections.AdvancedPrediction:Slider({ 
        Name = "Max Power", Minimum = 5.0, Maximum = 15.0, Default = AutoShootConfig.MaxPower, Precision = 2, 
        Callback = function(v) AutoShootConfig.MaxPower = v end 
    }, "AdvancedMaxPower")

    uiElements.AdvancedPowerPerStud = UI.Sections.AdvancedPrediction:Slider({ 
        Name = "Power Per Stud", Minimum = 0.001, Maximum = 0.1, Default = AutoShootConfig.PowerPerStud, Precision = 3, 
        Callback = function(v) AutoShootConfig.PowerPerStud = v end 
    }, "AdvancedPowerPerStud")
    UI.Sections.AdvancedPrediction:Divider()
    uiElements.AdvancedMaxHeight = UI.Sections.AdvancedPrediction:Slider({ 
        Name = "Max Height", Minimum = 50, Maximum = 200, Default = AutoShootConfig.MaxHeight, Precision = 1, 
        Callback = function(v) AutoShootConfig.MaxHeight = v end 
    }, "AdvancedMaxHeight")
    UI.Sections.AdvancedPrediction:SubLabel({
        Text ='[💠] The maximum height of the ball flight (in studs)'
    })
end

if UI.Sections.Attacks then
    UI.Sections.Attacks:Header({ Name = "AutoShoot Attacks" })
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Paragraph({
         Header = "Information",
         Body = "Min Dist - Minimum Distance for attack, Max Dist - Maximum Distance, X Mult - horizontal position multiplier (from center), Base Min/ Base Max - basic altitude range, DerivationMult - Prediction force of the ball deflection, Z Offset - target offset along the Z-axis (forward/backward from the goal line)"
    })
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Header({ Name = "SideRicochet" })
    
    uiElements.SideRicochetEnabled = UI.Sections.Attacks:Toggle({ 
        Name = "Enabled", Default = AutoShootConfig.Attacks.SideRicochet.Enabled, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.Enabled = v end 
    }, "SideRicochetEnabled")
    
    uiElements.SideRicochetMinDist = UI.Sections.Attacks:Slider({ 
        Name = "Min Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SideRicochet.MinDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.MinDist = v end 
    }, "SideRicochetMinDist")
    
    uiElements.SideRicochetMaxDist = UI.Sections.Attacks:Slider({ 
        Name = "Max Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SideRicochet.MaxDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.MaxDist = v end 
    }, "SideRicochetMaxDist")
    
    uiElements.SideRicochetPower = UI.Sections.Attacks:Slider({ 
        Name = "Power", Minimum = 0.5, Maximum = 100.0, Default = AutoShootConfig.Attacks.SideRicochet.Power, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.Power = v end 
    }, "SideRicochetPower")
    
    uiElements.SideRicochetXMult = UI.Sections.Attacks:Slider({ 
        Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = AutoShootConfig.Attacks.SideRicochet.XMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.XMult = v end 
    }, "SideRicochetXMult")
    
    -- Spin = "None", так что нет тоггла
    
    uiElements.SideRicochetHeightMult = UI.Sections.Attacks:Slider({ 
        Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = AutoShootConfig.Attacks.SideRicochet.HeightMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.HeightMult = v end 
    }, "SideRicochetHeightMult")
    
    uiElements.SideRicochetBaseMin = UI.Sections.Attacks:Slider({ 
        Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SideRicochet.BaseHeightRange.Min, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.BaseHeightRange.Min = v end 
    }, "SideRicochetBaseMin")
    
    uiElements.SideRicochetBaseMax = UI.Sections.Attacks:Slider({ 
        Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SideRicochet.BaseHeightRange.Max, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.BaseHeightRange.Max = v end 
    }, "SideRicochetBaseMax")
    
    uiElements.SideRicochetDerivationMult = UI.Sections.Attacks:Slider({ 
        Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = AutoShootConfig.Attacks.SideRicochet.DerivationMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.DerivationMult = v end 
    }, "SideRicochetDerivationMult")
    
    uiElements.SideRicochetZOffset = UI.Sections.Attacks:Slider({ 
        Name = "Z Offset", Minimum = -20.0, Maximum = 20.0, Default = AutoShootConfig.Attacks.SideRicochet.ZOffset, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SideRicochet.ZOffset = v end 
    }, "SideRicochetZOffset")
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Header({ Name = "CloseSpin" })
    
    uiElements.CloseSpinEnabled = UI.Sections.Attacks:Toggle({ 
        Name = "Enabled", Default = AutoShootConfig.Attacks.CloseSpin.Enabled, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.Enabled = v end 
    }, "CloseSpinEnabled")
    
    uiElements.CloseSpinMinDist = UI.Sections.Attacks:Slider({ 
        Name = "Min Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.CloseSpin.MinDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.MinDist = v end 
    }, "CloseSpinMinDist")
    
    uiElements.CloseSpinMaxDist = UI.Sections.Attacks:Slider({ 
        Name = "Max Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.CloseSpin.MaxDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.MaxDist = v end 
    }, "CloseSpinMaxDist")
    
    uiElements.CloseSpinPower = UI.Sections.Attacks:Slider({ 
        Name = "Power", Minimum = 0.5, Maximum = 100.0, Default = AutoShootConfig.Attacks.CloseSpin.Power, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.Power = v end 
    }, "CloseSpinPower")
    
    uiElements.CloseSpinXMult = UI.Sections.Attacks:Slider({ 
        Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = AutoShootConfig.Attacks.CloseSpin.XMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.XMult = v end 
    }, "CloseSpinXMult")
    
    uiElements.CloseSpinSpin = UI.Sections.Attacks:Toggle({ 
        Name = "Spin", Default = AutoShootConfig.Attacks.CloseSpin.Spin, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.Spin = v end 
    }, "CloseSpinSpin")
    
    uiElements.CloseSpinHeightMult = UI.Sections.Attacks:Slider({ 
        Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = AutoShootConfig.Attacks.CloseSpin.HeightMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.HeightMult = v end 
    }, "CloseSpinHeightMult")
    
    uiElements.CloseSpinBaseMin = UI.Sections.Attacks:Slider({ 
        Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.CloseSpin.BaseHeightRange.Min, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.BaseHeightRange.Min = v end 
    }, "CloseSpinBaseMin")
    
    uiElements.CloseSpinBaseMax = UI.Sections.Attacks:Slider({ 
        Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.CloseSpin.BaseHeightRange.Max, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.BaseHeightRange.Max = v end 
    }, "CloseSpinBaseMax")
    
    uiElements.CloseSpinDerivationMult = UI.Sections.Attacks:Slider({ 
        Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = AutoShootConfig.Attacks.CloseSpin.DerivationMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.DerivationMult = v end 
    }, "CloseSpinDerivationMult")
    
    uiElements.CloseSpinZOffset = UI.Sections.Attacks:Slider({ 
        Name = "Z Offset", Minimum = -20.0, Maximum = 20.0, Default = AutoShootConfig.Attacks.CloseSpin.ZOffset, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.CloseSpin.ZOffset = v end 
    }, "CloseSpinZOffset")
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Header({ Name = "SmartCorner" })
    
    uiElements.SmartCornerEnabled = UI.Sections.Attacks:Toggle({ 
        Name = "Enabled", Default = AutoShootConfig.Attacks.SmartCorner.Enabled, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.Enabled = v end 
    }, "SmartCornerEnabled")
    
    uiElements.SmartCornerMinDist = UI.Sections.Attacks:Slider({ 
        Name = "Min Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartCorner.MinDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.MinDist = v end 
    }, "SmartCornerMinDist")
    
    uiElements.SmartCornerMaxDist = UI.Sections.Attacks:Slider({ 
        Name = "Max Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartCorner.MaxDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.MaxDist = v end 
    }, "SmartCornerMaxDist")
    
    uiElements.SmartCornerPowerMin = UI.Sections.Attacks:Slider({ 
        Name = "Power Min", Minimum = 0.5, Maximum = 10.0, Default = AutoShootConfig.Attacks.SmartCorner.PowerMin, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.PowerMin = v end 
    }, "SmartCornerPowerMin")
    
    uiElements.SmartCornerXMult = UI.Sections.Attacks:Slider({ 
        Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = AutoShootConfig.Attacks.SmartCorner.XMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.XMult = v end 
    }, "SmartCornerXMult")
    
    -- Spin = "None", нет тоггла
    
    uiElements.SmartCornerHeightMult = UI.Sections.Attacks:Slider({ 
        Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = AutoShootConfig.Attacks.SmartCorner.HeightMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.HeightMult = v end 
    }, "SmartCornerHeightMult")
    
    uiElements.SmartCornerBaseMin = UI.Sections.Attacks:Slider({ 
        Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartCorner.BaseHeightRange.Min, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.BaseHeightRange.Min = v end 
    }, "SmartCornerBaseMin")
    
    uiElements.SmartCornerBaseMax = UI.Sections.Attacks:Slider({ 
        Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartCorner.BaseHeightRange.Max, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.BaseHeightRange.Max = v end 
    }, "SmartCornerBaseMax")
    
    uiElements.SmartCornerDerivationMult = UI.Sections.Attacks:Slider({ 
        Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = AutoShootConfig.Attacks.SmartCorner.DerivationMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.DerivationMult = v end 
    }, "SmartCornerDerivationMult")
    
    uiElements.SmartCornerZOffset = UI.Sections.Attacks:Slider({ 
        Name = "Z Offset", Minimum = -20.0, Maximum = 20.0, Default = AutoShootConfig.Attacks.SmartCorner.ZOffset, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCorner.ZOffset = v end 
    }, "SmartCornerZOffset")
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Header({ Name = "SmartCandle" })
    
    uiElements.SmartCandleEnabled = UI.Sections.Attacks:Toggle({ 
        Name = "Enabled", Default = AutoShootConfig.Attacks.SmartCandle.Enabled, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.Enabled = v end 
    }, "SmartCandleEnabled")
    
    uiElements.SmartCandleMinDist = UI.Sections.Attacks:Slider({ 
        Name = "Min Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartCandle.MinDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.MinDist = v end 
    }, "SmartCandleMinDist")
    
    uiElements.SmartCandleMaxDist = UI.Sections.Attacks:Slider({ 
        Name = "Max Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartCandle.MaxDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.MaxDist = v end 
    }, "SmartCandleMaxDist")
    
    uiElements.SmartCandlePower = UI.Sections.Attacks:Slider({ 
        Name = "Power", Minimum = 0.5, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartCandle.Power, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.Power = v end 
    }, "SmartCandlePower")
    
    uiElements.SmartCandleXMult = UI.Sections.Attacks:Slider({ 
        Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = AutoShootConfig.Attacks.SmartCandle.XMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.XMult = v end 
    }, "SmartCandleXMult")
    
    uiElements.SmartCandleSpin = UI.Sections.Attacks:Toggle({ 
        Name = "Spin", Default = AutoShootConfig.Attacks.SmartCandle.Spin, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.Spin = v end 
    }, "SmartCandleSpin")
    
    uiElements.SmartCandleHeightMult = UI.Sections.Attacks:Slider({ 
        Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = AutoShootConfig.Attacks.SmartCandle.HeightMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.HeightMult = v end 
    }, "SmartCandleHeightMult")
    
    uiElements.SmartCandleBaseMin = UI.Sections.Attacks:Slider({ 
        Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartCandle.BaseHeightRange.Min, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.BaseHeightRange.Min = v end 
    }, "SmartCandleBaseMin")
    
    uiElements.SmartCandleBaseMax = UI.Sections.Attacks:Slider({ 
        Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartCandle.BaseHeightRange.Max, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.BaseHeightRange.Max = v end 
    }, "SmartCandleBaseMax")
    
    uiElements.SmartCandleDerivationMult = UI.Sections.Attacks:Slider({ 
        Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = AutoShootConfig.Attacks.SmartCandle.DerivationMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.DerivationMult = v end 
    }, "SmartCandleDerivationMult")
    
    uiElements.SmartCandleZOffset = UI.Sections.Attacks:Slider({ 
        Name = "Z Offset", Minimum = -20.0, Maximum = 20.0, Default = AutoShootConfig.Attacks.SmartCandle.ZOffset, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandle.ZOffset = v end 
    }, "SmartCandleZOffset")
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Header({ Name = "SmartRicochet" })
    
    uiElements.SmartRicochetEnabled = UI.Sections.Attacks:Toggle({ 
        Name = "Enabled", Default = AutoShootConfig.Attacks.SmartRicochet.Enabled, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.Enabled = v end 
    }, "SmartRicochetEnabled")
    
    uiElements.SmartRicochetMinDist = UI.Sections.Attacks:Slider({ 
        Name = "Min Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartRicochet.MinDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.MinDist = v end 
    }, "SmartRicochetMinDist")
    
    uiElements.SmartRicochetMaxDist = UI.Sections.Attacks:Slider({ 
        Name = "Max Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartRicochet.MaxDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.MaxDist = v end 
    }, "SmartRicochetMaxDist")
    
    uiElements.SmartRicochetPower = UI.Sections.Attacks:Slider({ 
        Name = "Power", Minimum = 0.5, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartRicochet.Power, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.Power = v end 
    }, "SmartRicochetPower")
    
    uiElements.SmartRicochetXMult = UI.Sections.Attacks:Slider({ 
        Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = AutoShootConfig.Attacks.SmartRicochet.XMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.XMult = v end 
    }, "SmartRicochetXMult")
    
    uiElements.SmartRicochetSpin = UI.Sections.Attacks:Toggle({ 
        Name = "Spin", Default = AutoShootConfig.Attacks.SmartRicochet.Spin, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.Spin = v end 
    }, "SmartRicochetSpin")
    
    uiElements.SmartRicochetHeightMult = UI.Sections.Attacks:Slider({ 
        Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = AutoShootConfig.Attacks.SmartRicochet.HeightMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.HeightMult = v end 
    }, "SmartRicochetHeightMult")
    
    uiElements.SmartRicochetBaseMin = UI.Sections.Attacks:Slider({ 
        Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartRicochet.BaseHeightRange.Min, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.BaseHeightRange.Min = v end 
    }, "SmartRicochetBaseMin")
    
    uiElements.SmartRicochetBaseMax = UI.Sections.Attacks:Slider({ 
        Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartRicochet.BaseHeightRange.Max, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.BaseHeightRange.Max = v end 
    }, "SmartRicochetBaseMax")
    
    uiElements.SmartRicochetDerivationMult = UI.Sections.Attacks:Slider({ 
        Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = AutoShootConfig.Attacks.SmartRicochet.DerivationMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.DerivationMult = v end 
    }, "SmartRicochetDerivationMult")
    
    uiElements.SmartRicochetZOffset = UI.Sections.Attacks:Slider({ 
        Name = "Z Offset", Minimum = -60.0, Maximum = 20.0, Default = AutoShootConfig.Attacks.SmartRicochet.ZOffset, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartRicochet.ZOffset = v end 
    }, "SmartRicochetZOffset")
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Header({ Name = "SmartSpin" })
    
    uiElements.SmartSpinEnabled = UI.Sections.Attacks:Toggle({ 
        Name = "Enabled", Default = AutoShootConfig.Attacks.SmartSpin.Enabled, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.Enabled = v end 
    }, "SmartSpinEnabled")
    
    uiElements.SmartSpinMinDist = UI.Sections.Attacks:Slider({ 
        Name = "Min Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartSpin.MinDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.MinDist = v end 
    }, "SmartSpinMinDist")
    
    uiElements.SmartSpinMaxDist = UI.Sections.Attacks:Slider({ 
        Name = "Max Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartSpin.MaxDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.MaxDist = v end 
    }, "SmartSpinMaxDist")
    
    uiElements.SmartSpinPowerAdd = UI.Sections.Attacks:Slider({ 
        Name = "Power Add", Minimum = -5.0, Maximum = 5.0, Default = AutoShootConfig.Attacks.SmartSpin.PowerAdd, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.PowerAdd = v end 
    }, "SmartSpinPowerAdd")
    
    uiElements.SmartSpinXMult = UI.Sections.Attacks:Slider({ 
        Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = AutoShootConfig.Attacks.SmartSpin.XMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.XMult = v end 
    }, "SmartSpinXMult")
    
    uiElements.SmartSpinSpin = UI.Sections.Attacks:Toggle({ 
        Name = "Spin", Default = AutoShootConfig.Attacks.SmartSpin.Spin, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.Spin = v end 
    }, "SmartSpinSpin")
    
    uiElements.SmartSpinHeightMult = UI.Sections.Attacks:Slider({ 
        Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = AutoShootConfig.Attacks.SmartSpin.HeightMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.HeightMult = v end 
    }, "SmartSpinHeightMult")
    
    uiElements.SmartSpinBaseMin = UI.Sections.Attacks:Slider({ 
        Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartSpin.BaseHeightRange.Min, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.BaseHeightRange.Min = v end 
    }, "SmartSpinBaseMin")
    
    uiElements.SmartSpinBaseMax = UI.Sections.Attacks:Slider({ 
        Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartSpin.BaseHeightRange.Max, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.BaseHeightRange.Max = v end 
    }, "SmartSpinBaseMax")
    
    uiElements.SmartSpinDerivationMult = UI.Sections.Attacks:Slider({ 
        Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = AutoShootConfig.Attacks.SmartSpin.DerivationMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.DerivationMult = v end 
    }, "SmartSpinDerivationMult")
    
    uiElements.SmartSpinZOffset = UI.Sections.Attacks:Slider({ 
        Name = "Z Offset", Minimum = -20.0, Maximum = 20.0, Default = AutoShootConfig.Attacks.SmartSpin.ZOffset, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartSpin.ZOffset = v end 
    }, "SmartSpinZOffset")
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Header({ Name = "SmartCandleMid" })
    
    uiElements.SmartCandleMidEnabled = UI.Sections.Attacks:Toggle({ 
        Name = "Enabled", Default = AutoShootConfig.Attacks.SmartCandleMid.Enabled, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.Enabled = v end 
    }, "SmartCandleMidEnabled")
    
    uiElements.SmartCandleMidMinDist = UI.Sections.Attacks:Slider({ 
        Name = "Min Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartCandleMid.MinDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.MinDist = v end 
    }, "SmartCandleMidMinDist")
    
    uiElements.SmartCandleMidMaxDist = UI.Sections.Attacks:Slider({ 
        Name = "Max Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.SmartCandleMid.MaxDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.MaxDist = v end 
    }, "SmartCandleMidMaxDist")
    
    uiElements.SmartCandleMidPowerAdd = UI.Sections.Attacks:Slider({ 
        Name = "Power Add", Minimum = -5.0, Maximum = 5.0, Default = AutoShootConfig.Attacks.SmartCandleMid.PowerAdd, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.PowerAdd = v end 
    }, "SmartCandleMidPowerAdd")
    
    uiElements.SmartCandleMidXMult = UI.Sections.Attacks:Slider({ 
        Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = AutoShootConfig.Attacks.SmartCandleMid.XMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.XMult = v end 
    }, "SmartCandleMidXMult")
    
    uiElements.SmartCandleMidSpin = UI.Sections.Attacks:Toggle({ 
        Name = "Spin", Default = AutoShootConfig.Attacks.SmartCandleMid.Spin, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.Spin = v end 
    }, "SmartCandleMidSpin")
    
    uiElements.SmartCandleMidHeightMult = UI.Sections.Attacks:Slider({ 
        Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = AutoShootConfig.Attacks.SmartCandleMid.HeightMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.HeightMult = v end 
    }, "SmartCandleMidHeightMult")
    
    uiElements.SmartCandleMidBaseMin = UI.Sections.Attacks:Slider({ 
        Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartCandleMid.BaseHeightRange.Min, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.BaseHeightRange.Min = v end 
    }, "SmartCandleMidBaseMin")
    
    uiElements.SmartCandleMidBaseMax = UI.Sections.Attacks:Slider({ 
        Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.SmartCandleMid.BaseHeightRange.Max, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.BaseHeightRange.Max = v end 
    }, "SmartCandleMidBaseMax")
    
    uiElements.SmartCandleMidDerivationMult = UI.Sections.Attacks:Slider({ 
        Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = AutoShootConfig.Attacks.SmartCandleMid.DerivationMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.DerivationMult = v end 
    }, "SmartCandleMidDerivationMult")
    
    uiElements.SmartCandleMidZOffset = UI.Sections.Attacks:Slider({ 
        Name = "Z Offset", Minimum = -20.0, Maximum = 20.0, Default = AutoShootConfig.Attacks.SmartCandleMid.ZOffset, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.SmartCandleMid.ZOffset = v end 
    }, "SmartCandleMidZOffset")
    UI.Sections.Attacks:Divider()
    UI.Sections.Attacks:Header({ Name = "FarSmartCandle" })
    
    uiElements.FarSmartCandleEnabled = UI.Sections.Attacks:Toggle({ 
        Name = "Enabled", Default = AutoShootConfig.Attacks.FarSmartCandle.Enabled, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.Enabled = v end 
    }, "FarSmartCandleEnabled")
    
    uiElements.FarSmartCandleMinDist = UI.Sections.Attacks:Slider({ 
        Name = "Min Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.FarSmartCandle.MinDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.MinDist = v end 
    }, "FarSmartCandleMinDist")
    
    uiElements.FarSmartCandleMaxDist = UI.Sections.Attacks:Slider({ 
        Name = "Max Dist", Minimum = 0, Maximum = 300, Default = AutoShootConfig.Attacks.FarSmartCandle.MaxDist, Precision = 1, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.MaxDist = v end 
    }, "FarSmartCandleMaxDist")
    
    uiElements.FarSmartCandlePower = UI.Sections.Attacks:Slider({ 
        Name = "Power", Minimum = 0.5, Maximum = 100.0, Default = AutoShootConfig.Attacks.FarSmartCandle.Power, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.Power = v end 
    }, "FarSmartCandlePower")
    
    uiElements.FarSmartCandleXMult = UI.Sections.Attacks:Slider({ 
        Name = "X Mult", Minimum = 0.1, Maximum = 2.0, Default = AutoShootConfig.Attacks.FarSmartCandle.XMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.XMult = v end 
    }, "FarSmartCandleXMult")
    
    uiElements.FarSmartCandleSpin = UI.Sections.Attacks:Toggle({ 
        Name = "Spin", Default = AutoShootConfig.Attacks.FarSmartCandle.Spin, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.Spin = v end 
    }, "FarSmartCandleSpin")
    
    uiElements.FarSmartCandleHeightMult = UI.Sections.Attacks:Slider({ 
        Name = "Height Mult", Minimum = 0.1, Maximum = 3.0, Default = AutoShootConfig.Attacks.FarSmartCandle.HeightMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.HeightMult = v end 
    }, "FarSmartCandleHeightMult")
    
    uiElements.FarSmartCandleBaseMin = UI.Sections.Attacks:Slider({ 
        Name = "Base Min", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.FarSmartCandle.BaseHeightRange.Min, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.BaseHeightRange.Min = v end 
    }, "FarSmartCandleBaseMin")
    
    uiElements.FarSmartCandleBaseMax = UI.Sections.Attacks:Slider({ 
        Name = "Base Max", Minimum = 0.0, Maximum = 100.0, Default = AutoShootConfig.Attacks.FarSmartCandle.BaseHeightRange.Max, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.BaseHeightRange.Max = v end 
    }, "FarSmartCandleBaseMax")
    
    uiElements.FarSmartCandleDerivationMult = UI.Sections.Attacks:Slider({ 
        Name = "Derivation Mult", Minimum = 0.0, Maximum = 10.0, Default = AutoShootConfig.Attacks.FarSmartCandle.DerivationMult, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.DerivationMult = v end 
    }, "FarSmartCandleDerivationMult")
    
    uiElements.FarSmartCandleZOffset = UI.Sections.Attacks:Slider({ 
        Name = "Z Offset", Minimum = -20.0, Maximum = 20.0, Default = AutoShootConfig.Attacks.FarSmartCandle.ZOffset, Precision = 2, 
        Callback = function(v) AutoShootConfig.Attacks.FarSmartCandle.ZOffset = v end 
    }, "FarSmartCandleZOffset")
end

    local syncSection = UI.Tabs.Config:Section({ Name = "AutoShoot & AutoPickup Sync", Side = "Right" })
    syncSection:Header({ Name = "AutoShoot/AutoPickup" })
    syncSection:Button({ Name = "Sync Config", Callback = function()
        AutoShootConfig.Enabled = uiElements.AutoShootEnabled:GetState()
        AutoShootConfig.Legit = uiElements.AutoShootLegit:GetState()
        AutoShootConfig.ManualShot = uiElements.AutoShootManual:GetState()
        AutoShootConfig.ShootKey = uiElements.AutoShootKey:GetBind()
        AutoShootConfig.MaxDistance = uiElements.AutoShootMaxDist:GetValue()
        AutoShootConfig.DebugText = uiElements.AutoShootDebugText:GetState()
        AutoShootConfig.ManualButton = uiElements.AutoShootManualButton:GetState()
        AutoShootConfig.ButtonScale = uiElements.AutoShootButtonScale:GetValue()
        AutoShootConfig.Inset = uiElements.AdvancedInset:GetValue()
        AutoShootConfig.Gravity = uiElements.AdvancedGravity:GetValue()
        AutoShootConfig.MinPower = uiElements.AdvancedMinPower:GetValue()
        AutoShootConfig.MaxPower = uiElements.AdvancedMaxPower:GetValue()
        AutoShootConfig.PowerPerStud = uiElements.AdvancedPowerPerStud:GetValue()
        AutoShootConfig.MaxHeight = uiElements.AdvancedMaxHeight:GetValue()
        AutoShootConfig.Attacks.SideRicochet.MinDist = uiElements.SideRicochetMinDist:GetValue()
        AutoShootConfig.Attacks.SideRicochet.MaxDist = uiElements.SideRicochetMaxDist:GetValue()
        AutoShootConfig.Attacks.SideRicochet.Power = uiElements.SideRicochetPower:GetValue()
        AutoShootConfig.Attacks.SideRicochet.XMult = uiElements.SideRicochetXMult:GetValue()
        AutoShootConfig.Attacks.SideRicochet.HeightMult = uiElements.SideRicochetHeightMult:GetValue()
        AutoShootConfig.Attacks.SideRicochet.BaseHeightRange.Min = uiElements.SideRicochetBaseMin:GetValue()
        AutoShootConfig.Attacks.SideRicochet.BaseHeightRange.Max = uiElements.SideRicochetBaseMax:GetValue()
        AutoShootConfig.Attacks.SideRicochet.DerivationMult = uiElements.SideRicochetDerivationMult:GetValue()
        AutoShootConfig.Attacks.SideRicochet.ZOffset = uiElements.SideRicochetZOffset:GetValue()
        AutoShootConfig.Attacks.CloseSpin.MinDist = uiElements.CloseSpinMinDist:GetValue()
        AutoShootConfig.Attacks.CloseSpin.MaxDist = uiElements.CloseSpinMaxDist:GetValue()
        AutoShootConfig.Attacks.CloseSpin.Power = uiElements.CloseSpinPower:GetValue()
        AutoShootConfig.Attacks.CloseSpin.XMult = uiElements.CloseSpinXMult:GetValue()
        AutoShootConfig.Attacks.CloseSpin.Spin = uiElements.CloseSpinSpin:GetState()
        AutoShootConfig.Attacks.CloseSpin.HeightMult = uiElements.CloseSpinHeightMult:GetValue()
        AutoShootConfig.Attacks.CloseSpin.BaseHeightRange.Min = uiElements.CloseSpinBaseMin:GetValue()
        AutoShootConfig.Attacks.CloseSpin.BaseHeightRange.Max = uiElements.CloseSpinBaseMax:GetValue()
        AutoShootConfig.Attacks.CloseSpin.DerivationMult = uiElements.CloseSpinDerivationMult:GetValue()
        AutoShootConfig.Attacks.CloseSpin.ZOffset = uiElements.CloseSpinZOffset:GetValue()
        AutoShootConfig.Attacks.SmartCorner.MinDist = uiElements.SmartCornerMinDist:GetValue()
        AutoShootConfig.Attacks.SmartCorner.MaxDist = uiElements.SmartCornerMaxDist:GetValue()
        AutoShootConfig.Attacks.SmartCorner.PowerMin = uiElements.SmartCornerPowerMin:GetValue()
        AutoShootConfig.Attacks.SmartCorner.XMult = uiElements.SmartCornerXMult:GetValue()
        AutoShootConfig.Attacks.SmartCorner.HeightMult = uiElements.SmartCornerHeightMult:GetValue()
        AutoShootConfig.Attacks.SmartCorner.BaseHeightRange.Min = uiElements.SmartCornerBaseMin:GetValue()
        AutoShootConfig.Attacks.SmartCorner.BaseHeightRange.Max = uiElements.SmartCornerBaseMax:GetValue()
        AutoShootConfig.Attacks.SmartCorner.DerivationMult = uiElements.SmartCornerDerivationMult:GetValue()
        AutoShootConfig.Attacks.SmartCorner.ZOffset = uiElements.SmartCornerZOffset:GetValue()
        AutoShootConfig.Attacks.SmartCandle.MinDist = uiElements.SmartCandleMinDist:GetValue()
        AutoShootConfig.Attacks.SmartCandle.MaxDist = uiElements.SmartCandleMaxDist:GetValue()
        AutoShootConfig.Attacks.SmartCandle.Power = uiElements.SmartCandlePower:GetValue()
        AutoShootConfig.Attacks.SmartCandle.XMult = uiElements.SmartCandleXMult:GetValue()
        AutoShootConfig.Attacks.SmartCandle.Spin = uiElements.SmartCandleSpin:GetState()
        AutoShootConfig.Attacks.SmartCandle.HeightMult = uiElements.SmartCandleHeightMult:GetValue()
        AutoShootConfig.Attacks.SmartCandle.BaseHeightRange.Min = uiElements.SmartCandleBaseMin:GetValue()
        AutoShootConfig.Attacks.SmartCandle.BaseHeightRange.Max = uiElements.SmartCandleBaseMax:GetValue()
        AutoShootConfig.Attacks.SmartCandle.DerivationMult = uiElements.SmartCandleDerivationMult:GetValue()
        AutoShootConfig.Attacks.SmartCandle.ZOffset = uiElements.SmartCandleZOffset:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.MinDist = uiElements.SmartRicochetMinDist:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.MaxDist = uiElements.SmartRicochetMaxDist:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.Power = uiElements.SmartRicochetPower:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.XMult = uiElements.SmartRicochetXMult:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.Spin = uiElements.SmartRicochetSpin:GetState()
        AutoShootConfig.Attacks.SmartRicochet.HeightMult = uiElements.SmartRicochetHeightMult:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.BaseHeightRange.Min = uiElements.SmartRicochetBaseMin:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.BaseHeightRange.Max = uiElements.SmartRicochetBaseMax:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.DerivationMult = uiElements.SmartRicochetDerivationMult:GetValue()
        AutoShootConfig.Attacks.SmartRicochet.ZOffset = uiElements.SmartRicochetZOffset:GetValue()
        AutoShootConfig.Attacks.SmartSpin.MinDist = uiElements.SmartSpinMinDist:GetValue()
        AutoShootConfig.Attacks.SmartSpin.MaxDist = uiElements.SmartSpinMaxDist:GetValue()
        AutoShootConfig.Attacks.SmartSpin.PowerAdd = uiElements.SmartSpinPowerAdd:GetValue()
        AutoShootConfig.Attacks.SmartSpin.XMult = uiElements.SmartSpinXMult:GetValue()
        AutoShootConfig.Attacks.SmartSpin.Spin = uiElements.SmartSpinSpin:GetState()
        AutoShootConfig.Attacks.SmartSpin.HeightMult = uiElements.SmartSpinHeightMult:GetValue()
        AutoShootConfig.Attacks.SmartSpin.BaseHeightRange.Min = uiElements.SmartSpinBaseMin:GetValue()
        AutoShootConfig.Attacks.SmartSpin.BaseHeightRange.Max = uiElements.SmartSpinBaseMax:GetValue()
        AutoShootConfig.Attacks.SmartSpin.DerivationMult = uiElements.SmartSpinDerivationMult:GetValue()
        AutoShootConfig.Attacks.SmartSpin.ZOffset = uiElements.SmartSpinZOffset:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.MinDist = uiElements.SmartCandleMidMinDist:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.MaxDist = uiElements.SmartCandleMidMaxDist:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.PowerAdd = uiElements.SmartCandleMidPowerAdd:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.XMult = uiElements.SmartCandleMidXMult:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.Spin = uiElements.SmartCandleMidSpin:GetState()
        AutoShootConfig.Attacks.SmartCandleMid.HeightMult = uiElements.SmartCandleMidHeightMult:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.BaseHeightRange.Min = uiElements.SmartCandleMidBaseMin:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.BaseHeightRange.Max = uiElements.SmartCandleMidBaseMax:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.DerivationMult = uiElements.SmartCandleMidDerivationMult:GetValue()
        AutoShootConfig.Attacks.SmartCandleMid.ZOffset = uiElements.SmartCandleMidZOffset:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.MinDist = uiElements.FarSmartCandleMinDist:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.MaxDist = uiElements.FarSmartCandleMaxDist:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.Power = uiElements.FarSmartCandlePower:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.XMult = uiElements.FarSmartCandleXMult:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.Spin = uiElements.FarSmartCandleSpin:GetState()
        AutoShootConfig.Attacks.FarSmartCandle.HeightMult = uiElements.FarSmartCandleHeightMult:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.BaseHeightRange.Min = uiElements.FarSmartCandleBaseMin:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.BaseHeightRange.Max = uiElements.FarSmartCandleBaseMax:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.DerivationMult = uiElements.FarSmartCandleDerivationMult:GetValue()
        AutoShootConfig.Attacks.FarSmartCandle.ZOffset = uiElements.FarSmartCandleZOffset:GetValue()
        AutoShootStatus.Key = AutoShootConfig.ShootKey
        AutoShootStatus.ManualShot = AutoShootConfig.ManualShot
        AutoShootStatus.DebugText = AutoShootConfig.DebugText
        AutoShootStatus.ManualButton = AutoShootConfig.ManualButton
        AutoShootStatus.ButtonScale = AutoShootConfig.ButtonScale
        UpdateModeText()
        ToggleDebugText(AutoShootStatus.DebugText)
        ToggleManualButton(AutoShootStatus.ManualButton)
        if AutoShootConfig.Enabled then if not AutoShootStatus.Running then AutoShoot.Start() end else if AutoShootStatus.Running then AutoShoot.Stop() end end
        if AutoPickupConfig.Enabled then if not AutoPickupStatus.Running then AutoPickup.Start() end else if AutoPickupStatus.Running then AutoPickup.Stop() end end
        notify("Syllinse", "Config synchronized!", true)
    end })
end
-- === МОДУЛЬ ===
local AutoShootModule = {}
function AutoShootModule.Init(UI, coreParam, notifyFunc)
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
        BallAttachment = newChar:WaitForChild("ball")
        RShootAnim = Humanoid:LoadAnimation(Animations:WaitForChild("RShoot"))
        RShootAnim.Priority = Enum.AnimationPriority.Action4
        GoalCFrame = nil; TargetPoint = nil; NoSpinPoint = nil; LastShoot = 0; IsAnimating = false; CanShoot = true
        if AutoShootConfig.Enabled then AutoShoot.Start() end
        if AutoPickupConfig.Enabled then AutoPickup.Start() end
    end)
end
function AutoShootModule:Destroy()
    AutoShoot.Stop()
    AutoPickup.Stop()
end
return AutoShootModule


