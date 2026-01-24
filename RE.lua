-- [[ OMNI-RECURSION: V10.3 FINAL STABLE ]]
local _0xPLRS = game:GetService("Players")
local _0xRUN  = game:GetService("RunService")
local _0xUIS  = game:GetService("UserInputService")
local _0xLP   = _0xPLRS.LocalPlayer
local _0xCAM  = workspace.CurrentCamera

-- 1. グローバル設定
_G.Config = {
    Aim = false, Fly = false, Noclip = false,
    Speed = false, InfJump = false, 
    ESP = false, TeamCheck = true, WallCheck = true,
    FOV = 150, Power = 60
}
local Minimized = false

-- 2. チーム・可視性判定
local function IsEnemy(plr)
    if not _G.Config.TeamCheck then return true end
    return plr.Team ~= _0xLP.Team
end

local function IsVisible(part)
    if not _G.Config.WallCheck then return true end
    local res = _0xCAM:GetPartsObscuringTarget({part.Position}, {_0xLP.Character, part.Parent})
    return #res == 0
end

-- 3. ESP & ハイライト (最適化)
local function ApplyESP(plr)
    local function Update()
        local char = plr.Character
        if not _G.Config.ESP or plr == _0xLP or not char or not IsEnemy(plr) then
            if char then
                if char:FindFirstChild("DAN_HL") then char.DAN_HL:Destroy() end
                if char:FindFirstChild("Head") and char.Head:FindFirstChild("DAN_BBG") then char.Head.DAN_BBG:Destroy() end
            end
            return
        end

        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not head or not hum then return end

        local hl = char:FindFirstChild("DAN_HL") or Instance.new("Highlight", char)
        hl.Name = "DAN_HL"; hl.FillColor = plr.TeamColor.Color; hl.FillTransparency = 0.5; hl.OutlineColor = Color3.new(1,1,1)

        local bbg = head:FindFirstChild("DAN_BBG") or Instance.new("BillboardGui", head)
        bbg.Name = "DAN_BBG"; bbg.Size = UDim2.new(0, 100, 0, 50); bbg.AlwaysOnTop = true; bbg.StudsOffset = Vector3.new(0, 3, 0)
        
        local txt = bbg:FindFirstChild("Label") or Instance.new("TextLabel", bbg)
        txt.Name = "Label"; txt.Size = UDim2.new(1, 0, 1, 0); txt.BackgroundTransparency = 1; txt.TextStrokeTransparency = 0; txt.TextScaled = true
        txt.TextColor3 = Color3.new(1, hum.Health/hum.MaxHealth, hum.Health/hum.MaxHealth)
        txt.Text = string.format("%s\nHP: %d", plr.Name, math.floor(hum.Health))
    end
    _0xRUN.RenderStepped:Connect(Update)
end

-- 4. GUI構築 (チャット・収納・トグル)
local function BuildUI()
    if _0xLP.PlayerGui:FindFirstChild("DAN_HUB_V103") then _0xLP.PlayerGui.DAN_HUB_V103:Destroy() end
    local MainGui = Instance.new("ScreenGui", _0xLP.PlayerGui); MainGui.Name = "DAN_HUB_V103"; MainGui.ResetOnSpawn = false

    local FOVFrame = Instance.new("Frame", MainGui); FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5); FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0); FOVFrame.BackgroundTransparency = 1; FOVFrame.Size = UDim2.new(0, _G.Config.FOV * 2, 0, _G.Config.FOV * 2); FOVFrame.Visible = false
    local UIStroke = Instance.new("UIStroke", FOVFrame); UIStroke.Thickness = 2; UIStroke.Color = Color3.new(1,1,1); UIStroke.Transparency = 0.5
    Instance.new("UICorner", FOVFrame).CornerRadius = UDim.new(1, 0)

    local Frame = Instance.new("Frame", MainGui); Frame.Size = UDim2.new(0, 210, 0, 420); Frame.Position = UDim2.new(0, 30, 0.2, 0); Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Frame.Active = true; Frame.Draggable = true; Instance.new("UICorner", Frame)
    local Header = Instance.new("TextLabel", Frame); Header.Size = UDim2.new(1, 0, 0, 40); Header.Text = "  DAN HUB v10.3"; Header.TextColor3 = Color3.fromRGB(0, 255, 150); Header.BackgroundColor3 = Color3.fromRGB(30, 30, 30); Header.TextXAlignment = Enum.TextXAlignment.Left; Instance.new("UICorner", Header)
    
    local MinBtn = Instance.new("TextButton", Header); MinBtn.Size = UDim2.new(0, 30, 0, 30); MinBtn.Position = UDim2.new(1, -35, 0, 5); MinBtn.Text = "-"; MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); MinBtn.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", MinBtn)

    local Content = Instance.new("Frame", Frame); Content.Size = UDim2.new(1, 0, 1, -40); Content.Position = UDim2.new(0, 0, 0, 40); Content.BackgroundTransparency = 1; Content.ClipsDescendants = true
    local ChatBox = Instance.new("TextBox", Content); ChatBox.Size = UDim2.new(0.9, 0, 0, 35); ChatBox.Position = UDim2.new(0.05, 0, 0, 10); ChatBox.PlaceholderText = "BYPASS CHAT..."; ChatBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40); ChatBox.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", ChatBox)
    local Scroll = Instance.new("ScrollingFrame", Content); Scroll.Size = UDim2.new(1, 0, 1, -55); Scroll.Position = UDim2.new(0, 0, 0, 55); Scroll.BackgroundTransparency = 1; Scroll.CanvasSize = UDim2.new(0,0,0,550)
    
    MinBtn.MouseButton1Click:Connect(function()
        Minimized = not Minimized
        MinBtn.Text = Minimized and "+" or "-"
        Frame:TweenSize(Minimized and UDim2.new(0, 210, 0, 40) or UDim2.new(0, 210, 0, 420), "Out", "Quad", 0.3, true)
        Content.Visible = not Minimized
    end)

    local function AddToggle(name, y, key)
        local b = Instance.new("TextButton", Scroll); b.Size = UDim2.new(0.9, 0, 0, 35); b.Position = UDim2.new(0.05, 0, 0, y); b.Text = name .. ": OFF"; b.BackgroundColor3 = Color3.fromRGB(45, 45, 45); b.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(function()
            _G.Config[key] = not _G.Config[key]
            b.Text = name .. ": " .. (_G.Config[key] and "ON" or "OFF")
            b.BackgroundColor3 = _G.Config[key] and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(45, 45, 45)
            if key == "Aim" then FOVFrame.Visible = _G.Config.Aim end
        end)
    end

    AddToggle("AIMBOT", 10, "Aim"); AddToggle("TEAM CHECK", 55, "TeamCheck"); AddToggle("WALL CHECK", 100, "WallCheck")
    AddToggle("TACTICAL ESP", 145, "ESP"); AddToggle("FORCE FLY", 190, "Fly"); AddToggle("NOCLIP", 235, "Noclip")
    AddToggle("SPEED HACK", 280, "Speed"); AddToggle("INF JUMP", 325, "InfJump")

    ChatBox.FocusLost:Connect(function(enter)
        if enter and ChatBox.Text ~= "" then
            local msg = ChatBox.Text
            pcall(function() _0xLP.Character.Humanoid.DisplayName = "["..msg.."]" end)
            task.delay(5, function() pcall(function() _0xLP.Character.Humanoid.DisplayName = _0xLP.Name end) end)
            _0xLP:SetAttribute("DanMsg", msg); ChatBox.Text = ""
        end
    end)
end

-- 5. Aimbot & 物理ループ
_0xRUN.RenderStepped:Connect(function()
    if _G.Config.Aim then
        local target, dist = nil, _G.Config.FOV
        local center = Vector2.new(_0xCAM.ViewportSize.X/2, _0xCAM.ViewportSize.Y/2)
        for _, p in pairs(_0xPLRS:GetPlayers()) do
            if p ~= _0xLP and p.Character and p.Character:FindFirstChild("Head") and IsEnemy(p) then
                local h = p.Character.Head
                local pos, vis = _0xCAM:WorldToViewportPoint(h.Position)
                local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if vis and d < dist and IsVisible(h) then target = h; dist = d end
            end
        end
        if target then _0xCAM.CFrame = CFrame.lookAt(_0xCAM.CFrame.Position, target.Position) end
    end
end)

_0xRUN.Stepped:Connect(function()
    pcall(function()
        local c = _0xLP.Character; if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        local r = c:FindFirstChild("HumanoidRootPart")
        if _G.Config.Fly and r then
            local bv = r:FindFirstChild("DanFly") or Instance.new("BodyVelocity", r)
            bv.Name = "DanFly"; bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bv.Velocity = hum.MoveDirection.Magnitude > 0 and _0xCAM.CFrame.LookVector * _G.Config.Power or Vector3.new(0, 0.1, 0)
        elseif r and r:FindFirstChild("DanFly") then r.DanFly:Destroy() end
        if _G.Config.Speed and hum then hum.WalkSpeed = _G.Config.Power end
        if _G.Config.Noclip then for _,v in pairs(c:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end end
    end)
end)

-- 6. 無限ジャンプ (修正版: Velocity式)
_0xUIS.JumpRequest:Connect(function()
    if _G.Config.InfJump then
        local c = _0xLP.Character
        if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChildOfClass("Humanoid") then
            c.HumanoidRootPart.Velocity = Vector3.new(c.HumanoidRootPart.Velocity.X, c.Humanoid:FindFirstChildOfClass("Humanoid").JumpPower or 50, c.HumanoidRootPart.Velocity.Z)
            c.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- 初期化
for _, p in pairs(_0xPLRS:GetPlayers()) do ApplyESP(p) end
_0xPLRS.PlayerAdded:Connect(ApplyESP)
BuildUI()
