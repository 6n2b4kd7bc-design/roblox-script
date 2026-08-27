-- サイレントエイム + ESP + FOV円 + 自前GUI（右上ボタン + テキストボックス詳細設定）
-- 製作者: CAT (Interdimensional Coding Champion)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- ============================================================
-- ★★★ 設定（GUIで変更可） ★★★
-- ============================================================
local SETTINGS = {
    TeamCheck = true,
    AimPart = "Head",
    WallCheck = true,
    MaxRange = 300,
    FOV = 360,
    ShowESP = true,
    ESP_Box = true,
    ESP_Tracer = true,
    ESP_Label = true,
    ESP_ColorCycle = true,
    ShowFOVCircle = true,
}

-- ============================================================
-- ★★★ 元スクリプト関数（castRayフック用） ★★★
-- ============================================================
local function IsHostile(Char)
    local ok, Val = pcall(function() return Char:GetAttribute("Hostile") end)
    if ok and Val ~= nil then return Val == true end
    local V = Char:FindFirstChild("Hostile")
    if V and V:IsA("BoolValue") then return V.Value end
    return false
end

local function CanDamage(P)
    local Char = P.Character
    if not Char then return false end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum or Hum.Health <= 0 then return false end
    if Char:FindFirstChild("ForceField") then return false end
    if SETTINGS.TeamCheck then
        local MyTeam = LocalPlayer.Team
        local TheirTeam = P.Team
        if MyTeam and TheirTeam and MyTeam == TheirTeam then return false end
        if MyTeam and MyTeam.Name == "Guards" then
            if not IsHostile(Char) then return false end
        end
    end
    return true
end

local function IsVisible(Char, Origin)
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = LocalPlayer.Character and { LocalPlayer.Character } or {}
    local CheckParts = {
        Char:FindFirstChild(SETTINGS.AimPart), Char:FindFirstChild("Head"),
        Char:FindFirstChild("HumanoidRootPart"), Char:FindFirstChild("UpperTorso"),
        Char:FindFirstChild("LowerTorso"), Char:FindFirstChild("Torso"),
    }
    for _, CP in ipairs(CheckParts) do
        if not CP then continue end
        local Dir = CP.Position - Origin
        if Dir.Magnitude <= 0 then continue end
        local Result = Workspace:Raycast(Origin, Dir, Params)
        if not Result or Result.Instance:FindFirstAncestorOfClass("Model") == Char then return CP end
    end
    return nil
end

local function GetTarget(Origin)
    if typeof(Origin) ~= "Vector3" then
        local Cam = Workspace.CurrentCamera
        Origin = Cam and Cam.CFrame.Position or Vector3.new()
    end
    local Cam = Workspace.CurrentCamera
    if not Cam then return nil end

    local screenCenter = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
    local BestDist = SETTINGS.FOV
    local BestPart = nil

    for _, P in pairs(Players:GetPlayers()) do
        if P == LocalPlayer then continue end
        if not CanDamage(P) then continue end
        local Char = P.Character
        local Part = Char:FindFirstChild(SETTINGS.AimPart) or Char:FindFirstChild("Head")
        if not Part then continue end
        if SETTINGS.MaxRange and (Origin - Part.Position).Magnitude > SETTINGS.MaxRange then continue end
        local Pos, OnScreen = Cam:WorldToViewportPoint(Part.Position)
        if not OnScreen then continue end
        if (Part.Position - Cam.CFrame.Position):Dot(Cam.CFrame.LookVector) <= 0 then continue end
        local SDist = (Vector2.new(Pos.X, Pos.Y) - screenCenter).Magnitude
        if SDist >= BestDist then continue end
        if SETTINGS.WallCheck then
            local VisPart = IsVisible(Char, Origin)
            if not VisPart then continue end
            Part = VisPart
        end
        BestPart = Part
        BestDist = SDist
    end
    return BestPart
end

local function GetAttr(Tool, Attr)
    if typeof(Tool) == "Instance" then
        local ok, Val = pcall(function() return Tool:GetAttribute(Attr) end)
        if ok then return Val end
    end
    return nil
end

local function NormalCast(p1, p2, p3)
    local Origin, Aim, Tool
    if typeof(p1) == "Vector3" then
        Origin = p1
        if typeof(p2) == "Vector3" then Aim = p2 elseif typeof(p3) == "Vector3" then Aim = p3 end
        if typeof(p2) == "Instance" then Tool = p2 elseif typeof(p3) == "Instance" then Tool = p3 end
    else
        Tool = p1
        if typeof(p2) == "Vector3" then Origin = p2 end
        if typeof(p3) == "Vector3" then Aim = p3 elseif typeof(p2) == "Vector3" then Aim = p2 end
    end
    if not Origin or not Aim then return nil, Vector3.new() end
    local Dir = Aim - Origin
    if Dir.Magnitude <= 0 then Dir = Vector3.new(0, 0, -1) end
    local Range = GetAttr(Tool, "Range") or 200
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = LocalPlayer.Character and { LocalPlayer.Character } or {}
    Params.CollisionGroup = "ClientBullet"
    local Result = Workspace:Raycast(Origin, Dir.Unit * Range, Params)
    if Result then return Result.Instance, Result.Position end
    return nil, Origin + Dir.Unit * Range
end

local function HookCast(p1, p2, p3)
    local Origin
    if typeof(p1) == "Vector3" then Origin = p1
    elseif typeof(p2) == "Vector3" then Origin = p2
    elseif typeof(p3) == "Vector3" then Origin = p3 end
    if Origin then
        local Char = LocalPlayer.Character
        local Root = Char and Char:FindFirstChild("HumanoidRootPart")
        if Root and (Origin - Root.Position).Magnitude <= 75 then
            local Target = GetTarget(Origin)
            if Target and Target.Parent then
                return Target, Target.Position
            end
        end
    end
    return NormalCast(p1, p2, p3)
end

-- ============================================================
-- ★★★ castRay フック ★★★
-- ============================================================
if not _G.SilentAimHooked then
    _G.SilentAimHooked = true
    task.spawn(function()
        local hooked = 0
        for _, Func in next, getgc(true) do
            if type(Func) == "function" then
                local Info = debug.getinfo(Func, "nS")
                if Info and Info.name == "castRay" then
                    pcall(hookfunction, Func, HookCast)
                    hooked = hooked + 1
                end
            end
            if hooked >= 5 then break end
        end
    end)
end

-- ============================================================
-- ★★★ FOV円（Drawing） ★★★
-- ============================================================
local fovCircle
pcall(function()
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.Color = Color3.fromRGB(255, 182, 193)
    fovCircle.Transparency = 0.5
    fovCircle.NumSides = 64
    fovCircle.Filled = false
    fovCircle.Visible = false
end)

local function updateFOVCircle()
    if not fovCircle then return end
    if not SETTINGS.ShowFOVCircle then
        fovCircle.Visible = false
        return
    end
    fovCircle.Position = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y / 2)
    fovCircle.Radius = SETTINGS.FOV
    fovCircle.Visible = true
end

-- ============================================================
-- ★★★ ESPシステム ★★★
-- ============================================================
local function getParent()
    if gethui then return gethui() end
    local success, result = pcall(function() return game:GetService("CoreGui") end)
    if success and result then return result end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local espGui = Instance.new("ScreenGui")
espGui.Name = "CAT_ESP"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.Parent = getParent()

local espObjects = {}

local function createESP(player)
    local obj = {}
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.Parent = espGui
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = box
    obj.Box = box
    obj.Stroke = stroke

    local tracer = Instance.new("Frame")
    tracer.BackgroundColor3 = Color3.fromRGB(255, 182, 193)
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.Visible = false
    tracer.Parent = espGui
    obj.Tracer = tracer

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextSize = 14
    label.Font = Enum.Font.SourceSansBold
    label.Visible = false
    label.Parent = espGui
    obj.Label = label

    espObjects[player] = obj
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        createESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        for _, v in pairs(espObjects[player]) do
            v:Destroy()
        end
        espObjects[player] = nil
    end
end)

local function getCyclingColor()
    local t = tick() % 6
    local pink = Color3.fromRGB(255, 105, 180)
    local lightPink = Color3.fromRGB(255, 182, 193)
    local lightPurple = Color3.fromRGB(200, 162, 200)
    if t < 2 then
        return pink:Lerp(lightPink, t / 2)
    elseif t < 4 then
        return lightPink:Lerp(lightPurple, (t - 2) / 2)
    else
        return lightPurple:Lerp(pink, (t - 4) / 2)
    end
end

local lastESPUpdate = 0
RunService.RenderStepped:Connect(function()
    updateFOVCircle()

    if not SETTINGS.ShowESP then
        for _, obj in pairs(espObjects) do
            obj.Box.Visible = false
            obj.Tracer.Visible = false
            obj.Label.Visible = false
        end
        return
    end

    if tick() - lastESPUpdate < 0.05 then return end
    lastESPUpdate = tick()

    local cam = Workspace.CurrentCamera
    local currentColor = SETTINGS.ESP_ColorCycle and getCyclingColor() or Color3.fromRGB(255, 105, 180)

    for player, obj in pairs(espObjects) do
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if char and humanoid and humanoid.Health > 0 and hrp then
            local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
            if onScreen then
                -- Box
                if SETTINGS.ESP_Box then
                    local headPos = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                    local legPos = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.5, 0))
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 1.5
                    obj.Stroke.Color = currentColor
                    obj.Box.Size = UDim2.new(0, width, 0, height)
                    obj.Box.Position = UDim2.new(0, pos.X - width/2, 0, pos.Y - height/2)
                    obj.Box.Visible = true
                else
                    obj.Box.Visible = false
                end

                -- Label
                if SETTINGS.ESP_Label then
                    local dist = math.floor((cam.CFrame.Position - hrp.Position).Magnitude)
                    obj.Label.Text = string.format("%s\n%dHP | %dm", player.Name, humanoid.Health, dist)
                    obj.Label.TextColor3 = currentColor
                    obj.Label.Size = UDim2.new(0, 100, 0, 30)
                    obj.Label.Position = UDim2.new(0, pos.X - 50, 0, pos.Y - (math.abs(cam:WorldToViewportPoint(hrp.Position + Vector3.new(0,3,0)).Y - pos.Y)/2) - 35)
                    obj.Label.Visible = true
                else
                    obj.Label.Visible = false
                end

                -- Tracer
                if SETTINGS.ESP_Tracer then
                    local screenX, screenY = cam.ViewportSize.X, cam.ViewportSize.Y
                    local startPos = Vector2.new(screenX / 2, screenY)
                    local endPos = Vector2.new(pos.X, pos.Y)
                    local distance = (endPos - startPos).Magnitude
                    local center = (startPos + endPos) / 2
                    local angle = math.atan2(endPos.Y - startPos.Y, endPos.X - startPos.X)
                    obj.Tracer.BackgroundColor3 = currentColor
                    obj.Tracer.Size = UDim2.new(0, distance, 0, 1.5)
                    obj.Tracer.Position = UDim2.new(0, center.X, 0, center.Y)
                    obj.Tracer.Rotation = math.deg(angle)
                    obj.Tracer.Visible = true
                else
                    obj.Tracer.Visible = false
                end
            else
                obj.Box.Visible = false
                obj.Tracer.Visible = false
                obj.Label.Visible = false
            end
        else
            obj.Box.Visible = false
            obj.Tracer.Visible = false
            obj.Label.Visible = false
        end
    end
end)

-- ============================================================
-- ★★★ 自前GUI（右上ボタン + テキストボックス設定） ★★★
-- ============================================================
local function createSettingsGUI()
    local parent = getParent()
    local gui = Instance.new("ScreenGui")
    gui.Name = "CAT_Settings"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = parent

    -- 設定ボタン（右上）
    local settingsButton = Instance.new("TextButton")
    settingsButton.Size = UDim2.new(0, 100, 0, 40)
    settingsButton.Position = UDim2.new(1, -110, 0, 10) -- 右上
    settingsButton.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
    settingsButton.Text = "設定"
    settingsButton.TextColor3 = Color3.new(1,1,1)
    settingsButton.TextSize = 16
    settingsButton.Font = Enum.Font.SourceSansBold
    settingsButton.Parent = gui

    -- 設定パネル（右上ボタンの下）
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 220, 0, 340)
    panel.Position = UDim2.new(1, -230, 0, 60)
    panel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
    title.Text = "CAT Silent Aim"
    title.TextColor3 = Color3.new(1,1,1)
    title.TextSize = 18
    title.Font = Enum.Font.SourceSansBold
    title.Parent = panel

    local yOffset = 40
    local function addToggle(name, key)
        local toggleButton = Instance.new("TextButton")
        toggleButton.Size = UDim2.new(1, -20, 0, 25)
        toggleButton.Position = UDim2.new(0, 10, 0, yOffset)
        toggleButton.BackgroundColor3 = SETTINGS[key] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
        toggleButton.Text = name .. ": " .. (SETTINGS[key] and "ON" or "OFF")
        toggleButton.TextColor3 = Color3.new(1,1,1)
        toggleButton.TextSize = 14
        toggleButton.Font = Enum.Font.SourceSansBold
        toggleButton.Parent = panel
        toggleButton.Activated:Connect(function()
            SETTINGS[key] = not SETTINGS[key]
            toggleButton.BackgroundColor3 = SETTINGS[key] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
            toggleButton.Text = name .. ": " .. (SETTINGS[key] and "ON" or "OFF")
        end)
        yOffset = yOffset + 30
    end

    addToggle("Team Check", "TeamCheck")
    addToggle("Wall Check", "WallCheck")
    addToggle("Show ESP", "ShowESP")
    addToggle("ESP Box", "ESP_Box")
    addToggle("ESP Tracer", "ESP_Tracer")
    addToggle("ESP Label", "ESP_Label")
    addToggle("Color Cycle", "ESP_ColorCycle")
    addToggle("FOV Circle", "ShowFOVCircle")

    -- テキストボックス: MaxRange
    local rangeLabel = Instance.new("TextLabel")
    rangeLabel.Size = UDim2.new(0, 80, 0, 20)
    rangeLabel.Position = UDim2.new(0, 10, 0, yOffset)
    rangeLabel.BackgroundTransparency = 1
    rangeLabel.Text = "MaxRange:"
    rangeLabel.TextColor3 = Color3.new(1,1,1)
    rangeLabel.TextSize = 14
    rangeLabel.Parent = panel

    local rangeInput = Instance.new("TextBox")
    rangeInput.Size = UDim2.new(0, 100, 0, 20)
    rangeInput.Position = UDim2.new(0, 100, 0, yOffset)
    rangeInput.BackgroundColor3 = Color3.fromRGB(60,60,60)
    rangeInput.TextColor3 = Color3.new(1,1,1)
    rangeInput.Text = tostring(SETTINGS.MaxRange)
    rangeInput.Font = Enum.Font.SourceSans
    rangeInput.TextSize = 14
    rangeInput.Parent = panel
    rangeInput.FocusLost:Connect(function(enterPressed)
        local num = tonumber(rangeInput.Text)
        if num then
            SETTINGS.MaxRange = math.clamp(num, 50, 1000)
            rangeInput.Text = tostring(SETTINGS.MaxRange)
        else
            rangeInput.Text = tostring(SETTINGS.MaxRange)
        end
    end)
    yOffset = yOffset + 30

    -- テキストボックス: FOV
    local fovLabel = Instance.new("TextLabel")
    fovLabel.Size = UDim2.new(0, 80, 0, 20)
    fovLabel.Position = UDim2.new(0, 10, 0, yOffset)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Text = "FOV:"
    fovLabel.TextColor3 = Color3.new(1,1,1)
    fovLabel.TextSize = 14
    fovLabel.Parent = panel

    local fovInput = Instance.new("TextBox")
    fovInput.Size = UDim2.new(0, 100, 0, 20)
    fovInput.Position = UDim2.new(0, 100, 0, yOffset)
    fovInput.BackgroundColor3 = Color3.fromRGB(60,60,60)
    fovInput.TextColor3 = Color3.new(1,1,1)
    fovInput.Text = tostring(SETTINGS.FOV)
    fovInput.Font = Enum.Font.SourceSans
    fovInput.TextSize = 14
    fovInput.Parent = panel
    fovInput.FocusLost:Connect(function(enterPressed)
        local num = tonumber(fovInput.Text)
        if num then
            SETTINGS.FOV = math.clamp(num, 50, 800)
            fovInput.Text = tostring(SETTINGS.FOV)
        else
            fovInput.Text = tostring(SETTINGS.FOV)
        end
    end)
    yOffset = yOffset + 30

    -- テキストボックス: AimPart
    local aimLabel = Instance.new("TextLabel")
    aimLabel.Size = UDim2.new(0, 80, 0, 20)
    aimLabel.Position = UDim2.new(0, 10, 0, yOffset)
    aimLabel.BackgroundTransparency = 1
    aimLabel.Text = "AimPart:"
    aimLabel.TextColor3 = Color3.new(1,1,1)
    aimLabel.TextSize = 14
    aimLabel.Parent = panel

    local aimInput = Instance.new("TextBox")
    aimInput.Size = UDim2.new(0, 100, 0, 20)
    aimInput.Position = UDim2.new(0, 100, 0, yOffset)
    aimInput.BackgroundColor3 = Color3.fromRGB(60,60,60)
    aimInput.TextColor3 = Color3.new(1,1,1)
    aimInput.Text = SETTINGS.AimPart
    aimInput.Font = Enum.Font.SourceSans
    aimInput.TextSize = 14
    aimInput.Parent = panel
    aimInput.FocusLost:Connect(function(enterPressed)
        local validParts = {"Head", "Torso", "HumanoidRootPart"}
        local found = false
        for _, p in ipairs(validParts) do
            if aimInput.Text == p then
                found = true
                break
            end
        end
        if found then
            SETTINGS.AimPart = aimInput.Text
        else
            aimInput.Text = SETTINGS.AimPart
        end
    end)
    yOffset = yOffset + 30

    -- パネル開閉
    settingsButton.Activated:Connect(function()
        panel.Visible = not panel.Visible
    end)
end

task.spawn(createSettingsGUI)

print("✅ サイレントエイム + ESP + FOV円 + 自前GUI（右上ボタン+テキストボックス） 起動完了")
print("📌 画面右上の「設定」ボタンでパネルを開閉、テキストボックスで数値・部位を変更できます")
