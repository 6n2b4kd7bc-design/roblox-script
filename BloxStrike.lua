-- BloxStrike God Script: Silent Aim + ESP + No Recoil + Mobile Toggle (2026 Feb)
-- Executor: Fluxus, Delta, Arceus X, Hydrogen, Solara など推奨

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Config (調整ここだけ変えてね)
local FOV_RADIUS = 180
local SMOOTHNESS = 0.15
local PREDICTION = true
local WALL_CHECK = true          -- true = 壁越し無効 (Visible Check)
local TEAM_CHECK = true
local TARGET_PART = "Head"       -- "Head", "UpperTorso", "HumanoidRootPart" など
local SILENT_AIM = true
local ESP_ENABLED = true
local NO_RECOIL = true
local RECOIL_COMP = 0.9          -- 0.6~1.2で調整 (高め=強補正)

-- Mobile UI
local SG = Instance.new("ScreenGui")
SG.Parent = LocalPlayer:WaitForChild("PlayerGui")
SG.ResetOnSpawn = false

local TB = Instance.new("TextButton")
TB.Size = UDim2.new(0, 150, 0, 80)
TB.Position = UDim2.new(0.5, -75, 0.92, -100)
TB.Text = "Cheats: OFF"
TB.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TB.TextColor3 = Color3.fromRGB(255, 60, 60)
TB.Font = Enum.Font.SourceSansBold
TB.TextSize = 24
TB.Parent = SG

local FC = Instance.new("Frame")
FC.Size = UDim2.new(0, FOV_RADIUS*2, 0, FOV_RADIUS*2)
FC.Position = UDim2.new(0.5, -FOV_RADIUS, 0.5, -FOV_RADIUS)
FC.BackgroundTransparency = 1
FC.BorderSizePixel = 2
FC.BorderColor3 = Color3.fromRGB(255, 80, 80)
FC.Visible = false
Instance.new("UICorner", FC).CornerRadius = UDim.new(1,0)
FC.Parent = SG

-- Silent Remote 自動探し (強化版)
local SR = nil
for _, v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    if v:IsA("RemoteEvent") then
        local n = v.Name:lower()
        if n:find("fire") or n:find("shoot") or n:find("bullet") or n:find("hit") or n:find("damage") or n:find("weapon") then
            SR = v
            print("[+] Silent Remote Found: " .. v:GetFullName())
            break
        end
    end
end
if not SR then warn("[-] No Shoot Remote found. Shoot once and check F9 for name.") end

-- ESP (Drawing API)
local ESPs = {}
local function AddESP(p)
    if p == LocalPlayer then return end
    local Box = Drawing.new("Square")
    Box.Thickness = 2 Box.Filled = false Box.Color = Color3.fromRGB(255,0,0) Box.Transparency = 1 Box.Visible = false
    local HB = Drawing.new("Line")
    HB.Thickness = 3 HB.Color = Color3.fromRGB(0,255,0) HB.Transparency = 1 HB.Visible = false
    local NT = Drawing.new("Text")
    NT.Size = 14 NT.Center = true NT.Outline = true NT.Color = Color3.fromRGB(255,255,255) NT.Visible = false
    
    ESPs[p] = {Box=Box, HB=HB, NT=NT}
    p.CharacterAdded:Connect(function() task.wait(1) AddESP(p) end)
end

for _, p in Players:GetPlayers() do AddESP(p) end
Players.PlayerAdded:Connect(AddESP)

RunService.RenderStepped:Connect(function()
    if not ESP_ENABLED then return end
    for p, e in pairs(ESPs) do
        if p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local hPos, onScr = Camera:WorldToViewportPoint(p.Character.Head.Position + Vector3.new(0,1,0))
                local lPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0))
                if onScr then
                    local sz = (hPos - lPos).Magnitude * 1.6
                    e.Box.Size = Vector2.new(sz, sz * 1.9)
                    e.Box.Position = Vector2.new(hPos.X - sz/2, lPos.Y)
                    e.Box.Visible = true
                    
                    local hp = p.Character.Humanoid.Health / p.Character.Humanoid.MaxHealth
                    e.HB.From = Vector2.new(e.Box.Position.X - 6, e.Box.Position.Y + e.Box.Size.Y)
                    e.HB.To = Vector2.new(e.Box.Position.X - 6, e.Box.Position.Y + e.Box.Size.Y * (1 - hp))
                    e.HB.Color = Color3.fromHSV(hp/3, 1, 1)
                    e.HB.Visible = true
                    
                    e.NT.Text = p.Name .. " [" .. math.floor(p.Character.Humanoid.Health) .. "]"
                    e.NT.Position = Vector2.new(hPos.X, hPos.Y - 25)
                    e.NT.Visible = true
                else
                    e.Box.Visible = false e.HB.Visible = false e.NT.Visible = false
                end
            end
        else
            if e then e.Box.Visible = false e.HB.Visible = false e.NT.Visible = false end
        end
    end
end)

-- Closest Visible Enemy with Prediction
local function GetClosest()
    local cl, md = nil, FOV_RADIUS
    local ctr = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in Players:GetPlayers() do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(TARGET_PART) and p.Character.Humanoid.Health > 0 then
            if not TEAM_CHECK or p.Team ~= LocalPlayer.Team then
                local pt = p.Character[TARGET_PART]
                local scr, vis = Camera:WorldToViewportPoint(pt.Position)
                local dst = (Vector2.new(scr.X, scr.Y) - ctr).Magnitude
                if vis and dst < md then
                    local ray = Ray.new(Camera.CFrame.Position, (pt.Position - Camera.CFrame.Position).Unit * 1200)
                    local hit, _ = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, p.Character})
                    local v = not WALL_CHECK or hit == nil or hit:IsDescendantOf(p.Character)
                    if v then
                        local pos = pt.Position
                        if PREDICTION and p.Character:FindFirstChild("HumanoidRootPart") then
                            local vel = p.Character.HumanoidRootPart.Velocity
                            pos += vel * ((pt.Position - Camera.CFrame.Position).Magnitude / 180)  -- 弾速調整
                        end
                        cl = pos md = dst
                    end
                end
            end
        end
    end
    return cl
end

-- Metatable Hook for Silent + No Recoil
local mt = getrawmetatable(game)
local old_nm = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if _G.E and SILENT_AIM and self == SR and method == "FireServer" then
        local tgt = GetClosest()
        if tgt then
            if #args >= 1 and typeof(args[1]) == "Vector3" then
                args[1] = (tgt - Camera.CFrame.Position).Unit * 1000
            elseif #args >= 2 then
                args[2] = tgt
            end
            return old_nm(self, unpack(args))
        end
    end
    
    if _G.E and NO_RECOIL and method == "FireServer" and (self.Name:lower():find("fire") or self.Name:lower():find("shoot")) then
        mousemoverel(0, -RECOIL_COMP * 2.5)  -- 垂直反動キャンセル強化
    end
    
    return old_nm(self, ...)
end)
setreadonly(mt, true)

-- Visual Aimbot (fallback if Silent off)
RunService.RenderStepped:Connect(function()
    if _G.E and not SILENT_AIM then
        local tgt = GetClosest()
        if tgt then
            TweenService:Create(Camera, TweenInfo.new(SMOOTHNESS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
                {CFrame = CFrame.lookAt(Camera.CFrame.Position, tgt)}):Play()
        end
    end
end)

-- Toggle
_G.E = false
local function UIupd()
    if _G.E then
        TB.Text = "Cheats: ON"
        TB.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        FC.Visible = true
    else
        TB.Text = "Cheats: OFF"
        TB.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        FC.Visible = false
    end
    print("[BloxStrike] Cheats " .. (_G.E and "ON 🔥" or "OFF"))
end

UserInputService.InputBegan:Connect(function(inp)
    if inp.KeyCode == Enum.KeyCode.Insert then
        _G.E = not _G.E
        UIupd()
    end
end)

TB.MouseButton1Click:Connect(function()
    _G.E = not _G.E
    UIupd()
end)

-- Anti-AFK
spawn(function()
    while true do
        task.wait(math.random(50,80))
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.Jump = true
        end
    end
end)

print("🔥 BloxStrike Ultimate Loaded! Insert or Mobile Button to toggle")
print("Features: Silent Aim, ESP, No Recoil | WallCheck: " .. tostring(WALL_CHECK) .. " | TeamCheck: " .. tostring(TEAM_CHECK))
