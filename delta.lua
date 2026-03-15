local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- [[ 設定変数 ]]
_G.ESP_Master = false
_G.ESP_Skeleton = false
_G.ESP_HP = false
_G.ESP_Distance = false
_G.Aimbot_Enabled = false
_G.Aimbot_WallCheck = false
_G.Fullbright_Enabled = false
_G.BigHead_Enabled = false
_G.Aimbot_FOV = 100
_G.Hitbox_Size = 5

-- [[ ターゲットリストのキャッシュ（軽量化の鍵） ]]
local TargetCache = {}
local function UpdateTargetCache()
    local newCache = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent ~= LocalPlayer.Character then
            table.insert(newCache, obj.Parent)
        end
    end
    TargetCache = newCache
end
task.spawn(function() while task.wait(1) do UpdateTargetCache() end end)

-- [[ 描画オブジェクト (FOV) ]]
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5; fovCircle.Color = Color3.new(1, 0, 0); fovCircle.Transparency = 1; fovCircle.Filled = false; fovCircle.Visible = false

-- [[ 壁チェック判定 ]]
local function IsVisible(part)
    if not _G.Aimbot_WallCheck then return true end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local res = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rayParams)
    return not res or res.Instance:IsDescendantOf(part.Parent)
end

-- [[ ESP エンジン（スケルトン復活版） ]]
local Visuals = {}
local Bones = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}

local function CreateESP(model)
    if Visuals[model] then return end
    local isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
    local themeColor = isPlayer and Color3.new(1, 0, 0) or Color3.new(1, 1, 1)

    local parts = {
        name = Drawing.new("Text"),
        hpBg = Drawing.new("Square"),
        hpBar = Drawing.new("Square"),
        skeleton = {}
    }
    parts.name.Size = 14; parts.name.Center = true; parts.name.Outline = true; parts.name.Color = themeColor
    parts.hpBg.Filled = true; parts.hpBg.Color = Color3.new(0,0,0)
    parts.hpBar.Filled = true; parts.hpBar.Color = Color3.new(0,1,0)
    for _ = 1, #Bones do
        local l = Drawing.new("Line"); l.Thickness = 1; l.Color = themeColor
        table.insert(parts.skeleton, l)
    end

    Visuals[model] = RunService.RenderStepped:Connect(function()
        local hum = model:FindFirstChildOfClass("Humanoid")
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if _G.ESP_Master and hum and hrp and hum.Health > 0 then
            local pos, onS = Camera:WorldToViewportPoint(hrp.Position)
            if onS then
                local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
                local sizeY = (1000 / dist) * 1.5
                parts.name.Visible = true; parts.name.Position = Vector2.new(pos.X, pos.Y - sizeY - 20)
                parts.name.Text = string.format("%s%s [%d]%s", isPlayer and "[P] " or "[N] ", model.Name, hum.Health, _G.ESP_Distance and " ["..dist.."m]" or "")
                
                if _G.ESP_HP then
                    parts.hpBg.Visible = true; parts.hpBg.Position = Vector2.new(pos.X - (sizeY*0.3) - 10, pos.Y - sizeY/2); parts.hpBg.Size = Vector2.new(4, sizeY)
                    parts.hpBar.Visible = true; parts.hpBar.Position = Vector2.new(pos.X - (sizeY*0.3) - 9, pos.Y - sizeY/2 + (sizeY * (1 - hum.Health/hum.MaxHealth))); parts.hpBar.Size = Vector2.new(2, sizeY * (hum.Health/hum.MaxHealth))
                else parts.hpBg.Visible = false; parts.hpBar.Visible = false end

                if _G.ESP_Skeleton then
                    for i, bone in pairs(Bones) do
                        local p1, p2 = model:FindFirstChild(bone[1]), model:FindFirstChild(bone[2])
                        if p1 and p2 then
                            local v1, o1 = Camera:WorldToViewportPoint(p1.Position); local v2, o2 = Camera:WorldToViewportPoint(p2.Position)
                            parts.skeleton[i].Visible = o1 and o2; parts.skeleton[i].From = Vector2.new(v1.X, v1.Y); parts.skeleton[i].To = Vector2.new(v2.X, v2.Y)
                        else parts.skeleton[i].Visible = false end
                    end
                else for _, l in pairs(parts.skeleton) do l.Visible = false end end
            else parts.name.Visible = false; parts.hpBg.Visible = false; parts.hpBar.Visible = false; for _, l in pairs(parts.skeleton) do l.Visible = false end end
        else
            parts.name.Visible = false; parts.hpBg.Visible = false; parts.hpBar.Visible = false; for _, l in pairs(parts.skeleton) do l.Visible = false end
            if not model.Parent then parts.name:Remove(); parts.hpBg:Remove(); parts.hpBar:Remove(); for _, l in pairs(parts.skeleton) do l:Remove() end; Visuals[model]:Disconnect(); Visuals[model] = nil end
        end
    end)
end

-- [[ UI & ドラッグ機能 ]]
local sg = Instance.new("ScreenGui", (gethui and gethui()) or game:GetService("CoreGui")); sg.ResetOnSpawn = false
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 180, 0, 380); main.Position = UDim2.new(0.5, -90, 0.3, 0); main.BackgroundColor3 = Color3.fromRGB(20,20,20); main.Visible = false; main.Active = true; Instance.new("UICorner", main)
local title = Instance.new("TextLabel", main); title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundColor3 = Color3.fromRGB(10,10,10); title.Text = "GEMINI V3.5"; title.TextColor3 = Color3.new(1,1,1); title.Font = "SourceSansBold"; title.Active = true; Instance.new("UICorner", title)
local toggleBtn = Instance.new("TextButton", sg); toggleBtn.Size = UDim2.new(0, 70, 0, 35); toggleBtn.Position = UDim2.new(0.5, -35, 0, 15); toggleBtn.Text = "MENU"; toggleBtn.BackgroundColor3 = Color3.fromRGB(30,30,30); toggleBtn.TextColor3 = Color3.new(1,1,1); toggleBtn.Active = true; Instance.new("UICorner", toggleBtn)

local function Drag(g, t)
    local d, ds, sp; g.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = true; ds = i.Position; sp = t.Position end end)
    UserInputService.InputChanged:Connect(function(i) if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local delta = i.Position - ds; t.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end end)
end
Drag(title, main); Drag(toggleBtn, toggleBtn); toggleBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)

local list = Instance.new("UIListLayout", main); list.Padding = UDim.new(0, 3); list.HorizontalAlignment = "Center"; list.SortOrder = "LayoutOrder"
Instance.new("Frame", main).Size = UDim2.new(1, 0, 0, 42)

local function AddToggle(text, order, callback)
    local b = Instance.new("TextButton", main); b.Size = UDim2.new(0.9, 0, 0, 30); b.LayoutOrder = order; b.BackgroundColor3 = Color3.fromRGB(40,40,40); b.Text = text .. ": OFF"; b.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", b)
    local s = false; b.MouseButton1Click:Connect(function() s = not s; b.Text = text .. (s and ": ON" or ": OFF"); b.BackgroundColor3 = s and Color3.fromRGB(60,60,60) or Color3.fromRGB(40,40,40); callback(s) end)
end

AddToggle("Aimbot", 1, function(v) _G.Aimbot_Enabled = v end)
AddToggle("Wall Check", 2, function(v) _G.Aimbot_WallCheck = v end)
AddToggle("ESP Master", 3, function(v) _G.ESP_Master = v end)
AddToggle("Skeleton", 4, function(v) _G.ESP_Skeleton = v end)
AddToggle("Show HP", 5, function(v) _G.ESP_HP = v end)
AddToggle("Distance", 6, function(v) _G.ESP_Distance = v end)
AddToggle("Big Head", 7, function(v) _G.BigHead_Enabled = v end)
AddToggle("Fullbright", 8, function(v) _G.Fullbright_Enabled = v end)

-- [[ 統合メインループ ]]
RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2); fovCircle.Radius = _G.Aimbot_FOV; fovCircle.Visible = _G.Aimbot_Enabled

    local aimTarget, minD = nil, _G.Aimbot_FOV
    for _, model in pairs(TargetCache) do
        if model and model.Parent then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local head = model:FindFirstChild("Head")
            if hum and head and hum.Health > 0 then
                -- Aimbot 判定
                if _G.Aimbot_Enabled and IsVisible(head) then
                    local pos, onS = Camera:WorldToViewportPoint(head.Position)
                    if onS then
                        local d = (Vector2.new(pos.X, pos.Y) - fovCircle.Position).Magnitude
                        if d < minD then aimTarget = head; minD = d end
                    end
                end
                -- Big Head 判定
                if _G.BigHead_Enabled then
                    head.Size = Vector3.new(_G.Hitbox_Size, _G.Hitbox_Size, _G.Hitbox_Size)
                    head.Transparency = 0.6; head.CanCollide = false
                elseif head.Size.X == _G.Hitbox_Size then
                    head.Size = Vector3.new(1.2, 1.2, 1.2); head.Transparency = 0; head.CanCollide = true
                end
                -- ESP 自動作成
                if not Visuals[model] then CreateESP(model) end
            end
        end
    end
    if aimTarget then Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimTarget.Position) end
    if _G.Fullbright_Enabled then Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.Ambient = Color3.new(1,1,1) end
end)
