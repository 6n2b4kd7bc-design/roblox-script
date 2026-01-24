-- [[ OMNI-RECURSION: FINAL INTEGRATED ARCHITECTURE ]]
local _0xPLRS = game:GetService("Players")
local _0xRUN  = game:GetService("RunService")
local _0xUIS  = game:GetService("UserInputService")
local _0xLP   = _0xPLRS.LocalPlayer
local _0xCAM  = workspace.CurrentCamera

-- 1. 設定管理
_G.Config = {
    Aim = false, Fly = false, Noclip = false, ESP = false,
    Speed = false, InfJump = false, FOV = 150, Power = 50
}

-- 2. 壁チェック関数 (Raycast)
local function IsVisible(targetPart)
    local char = _0xLP.Character
    if not char then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, _0xCAM}
    local result = workspace:Raycast(_0xCAM.CFrame.Position, targetPart.Position - _0xCAM.CFrame.Position, params)
    return not result or result.Instance:IsDescendantOf(targetPart.Parent)
end

-- 3. GUI構築 (ドラッグ移動対応)
local MainGui = Instance.new("ScreenGui", _0xLP.PlayerGui)
local Frame = Instance.new("Frame", MainGui)
Frame.Size = UDim2.new(0, 180, 0, 320); Frame.Position = UDim2.new(0.1, 0, 0.2, 0)
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Frame.BackgroundTransparency = 0.2
Instance.new("UICorner", Frame)

local Header = Instance.new("TextLabel", Frame)
Header.Size = UDim2.new(1, 0, 0, 40); Header.Text = "DAN HUB v4.0"; Header.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Header.TextColor3 = Color3.fromRGB(0, 255, 255); Instance.new("UICorner", Header)

-- ドラッグ操作
local drag, dStart, sPos
Header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; dStart = i.Position; sPos = Frame.Position end end)
_0xUIS.InputChanged:Connect(function(i) if drag and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
    local delta = i.Position - dStart
    Frame.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + delta.X, sPos.Y.Scale, sPos.Y.Offset + delta.Y)
end end)
_0xUIS.InputEnded:Connect(function() drag = false end)

-- ボタン生成
local function AddToggle(name, y, key)
    local b = Instance.new("TextButton", Frame)
    b.Size = UDim2.new(0.9, 0, 0, 35); b.Position = UDim2.new(0.05, 0, 0, y)
    b.Text = name .. ": OFF"; b.BackgroundColor3 = Color3.fromRGB(45, 45, 45); b.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        _G.Config[key] = not _G.Config[key]
        b.Text = name .. ": " .. (_G.Config[key] and "ON" or "OFF")
        b.BackgroundColor3 = _G.Config[key] and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(45, 45, 45)
    end)
end

AddToggle("AIMBOT", 50, "Aim"); AddToggle("FLY", 95, "Fly"); AddToggle("NOCLIP", 140, "Noclip")
AddToggle("ESP", 185, "ESP"); AddToggle("SPEED", 230, "Speed"); AddToggle("INF JUMP", 275, "InfJump")

-- 4. FOVサークル
local Cir = Drawing.new("Circle")
Cir.Thickness = 1; Cir.Color = Color3.fromRGB(0, 255, 255); Cir.Filled = false; Cir.Visible = false

-- 5. 統合メインループ
_0xRUN.Stepped:Connect(function()
    local c = _0xLP.Character; if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
    if _G.Config.Noclip then for _,v in pairs(c:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end end
    if _G.Config.Fly and r then
        local bv = r:FindFirstChild("FlyV") or Instance.new("BodyVelocity", r)
        bv.Name = "FlyV"; bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.Velocity = _0xCAM.CFrame.LookVector * _G.Config.Power
    elseif r and r:FindFirstChild("FlyV") then r.FlyV:Destroy() end
    if c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = _G.Config.Speed and _G.Config.Power or 16 end
end)

_0xRUN.RenderStepped:Connect(function()
    local cent = Vector2.new(_0xCAM.ViewportSize.X/2, _0xCAM.ViewportSize.Y/2)
    Cir.Position = cent; Cir.Radius = _G.Config.FOV; Cir.Visible = _G.Config.Aim
    
    for _,p in pairs(_0xPLRS:GetPlayers()) do
        if p ~= _0xLP and p.Character then
            if _G.Config.ESP then
                if not p.Character:FindFirstChild("U_ESP") then
                    local h = Instance.new("Highlight", p.Character); h.Name = "U_ESP"; h.FillColor = Color3.fromRGB(0, 255, 255); h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
            elseif p.Character:FindFirstChild("U_ESP") then p.Character.U_ESP:Destroy() end
        end
    end

    if _G.Config.Aim then
        local t, mD = nil, _G.Config.FOV
        for _,p in pairs(_0xPLRS:GetPlayers()) do
            if p ~= _0xLP and p.Character and p.Character:FindFirstChild("Head") then
                local h = p.Character.Head; local pos, os = _0xCAM:WorldToViewportPoint(h.Position)
                if os and (Vector2.new(pos.X, pos.Y) - cent).Magnitude < mD and IsVisible(h) then
                    t = h; mD = (Vector2.new(pos.X, pos.Y) - cent).Magnitude
                end
            end
        end
        if t then _0xCAM.CFrame = _0xCAM.CFrame:Lerp(CFrame.lookAt(_0xCAM.CFrame.Position, t.Position), 0.15) end
    end
end)

_0xUIS.JumpRequest:Connect(function() if _G.Config.InfJump and _0xLP.Character and _0xLP.Character:FindFirstChildOfClass("Humanoid") then _0xLP.Character.Humanoid:ChangeState("Jumping") end end)
