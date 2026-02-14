local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- === 1. 設定管理 ===
_G.TrollConfig = _G.TrollConfig or {
    autoChest = false, autoKill = false, esp = false, 
    fullBright = false, speedHack = false, walkSpeed = 150, 
    scanRange = 1200, -- 指定の範囲1200
    waitHeight = 150
}
local config = _G.TrollConfig
local processing = false

-- === 2. 安全な足場管理 ===
local function getPlatform()
    local pName = "TrollSafetyBase_V94"
    local p = workspace:FindFirstChild(pName)
    if not p then
        p = Instance.new("Part", workspace)
        p.Name = pName; p.Size = Vector3.new(100, 1, 100); p.Anchored = true
        p.Transparency = 0.5; p.BrickColor = BrickColor.new("Neon orange")
        p.Position = Vector3.new(0, config.waitHeight, 0)
    end
    return p
end

-- === 3. ESP機能 ===
task.spawn(function()
    while true do
        pcall(function()
            if config.esp then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
                        local h = p.Character.Head
                        local t = h:FindFirstChild("TrollTag") or Instance.new("BillboardGui", h)
                        t.Name = "TrollTag"; t.AlwaysOnTop = true; t.Size = UDim2.new(0,100,0,40); t.Enabled = true
                        local l = t:FindFirstChild("L") or Instance.new("TextLabel", t)
                        l.Name = "L"; l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1; l.TextColor3 = Color3.new(1,1,1); l.TextStrokeTransparency = 0
                        local hp = p.Character:FindFirstChild("Humanoid") and math.floor(p.Character.Humanoid.Health) or 0
                        l.Text = p.DisplayName .. "\nHP: " .. hp
                    end
                end
            else
                for _, p in pairs(Players:GetPlayers()) do
                    if p.Character and p.Character:FindFirstChild("Head") and p.Character.Head:FindFirstChild("TrollTag") then
                        p.Character.Head.TrollTag:Destroy()
                    end
                end
            end
        end)
        task.wait(1)
    end
end)

-- === 4. 高精度テレポート (範囲1200 / 全回収 / 1往復) ===
task.spawn(function()
    while true do
        if config.autoChest and not processing then
            pcall(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                
                local target, dist = nil, config.scanRange
                for _, v in pairs(workspace:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Enabled then
                        local name = (v.Parent.Name .. (v.Parent.Parent and v.Parent.Parent.Name or "") .. v.ActionText):lower()
                        -- フィルター
                        if (name:find("chest") or name:find("core")) and 
                           not (name:find("cup") or name:find("mug") or name:find("shop") or name:find("npc")) then
                            local d = (root.Position - v.Parent.Position).Magnitude
                            if d < dist then target = v.Parent; dist = d end
                        end
                    end
                end

                if target then
                    processing = true
                    -- 1. 現場へ
                    root.CFrame = target.CFrame * CFrame.new(0, 3, 0)
                    task.wait(0.15)
                    
                    -- 2. 周囲の全アイテムを拾う
                    for _, v in pairs(workspace:GetDescendants()) do
                        if v:IsA("ProximityPrompt") and v.Enabled then
                            if (root.Position - v.Parent.Position).Magnitude < 15 then
                                fireproximityprompt(v)
                            end
                        end
                    end
                    task.wait(0.1)
                    
                    -- 3. 足場へ戻る (1回)
                    root.CFrame = getPlatform().CFrame * CFrame.new(0, 4, 0)
                    task.wait(0.3)
                    processing = false
                else
                    -- 待機時
                    if (root.Position - getPlatform().Position).Magnitude > 15 then
                        root.CFrame = getPlatform().CFrame * CFrame.new(0, 4, 0)
                    end
                end
            end)
        end
        task.wait(0.05)
    end
end)

-- === 5. UI構築 ===
local function setupUI()
    local pgui = LocalPlayer:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("TrollHubV94") then pgui.TrollHubV94:Destroy() end
    local gui = Instance.new("ScreenGui", pgui); gui.Name = "TrollHubV94"; gui.ResetOnSpawn = false
    
    local main = Instance.new("Frame", gui); main.Size = UDim2.new(0, 160, 0, 30); main.Position = UDim2.new(0.05, 0, 0.3, 0); main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); main.BorderSizePixel = 0; main.Active = true; main.ClipsDescendants = true; Instance.new("UICorner", main)
    local title = Instance.new("TextLabel", main); title.Size = UDim2.new(1, -30, 0, 30); title.Text = "Troll v9.4 (1200)"; title.TextColor3 = Color3.new(1, 1, 1); title.BackgroundTransparency = 1;
    
    local content = Instance.new("Frame", main); content.Size = UDim2.new(1, 0, 0, 300); content.Position = UDim2.new(0, 0, 0, 30); content.BackgroundTransparency = 1; content.Visible = false;

    local d, dS, sP; main.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = true; dS = i.Position; sP = main.Position end end)
    UserInputService.InputChanged:Connect(function(i) if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local delta = i.Position - dS; main.Position = UDim2.new(sP.X.Scale, sP.X.Offset + delta.X, sP.Y.Scale, sP.Y.Offset + delta.Y) end end)
    UserInputService.InputEnded:Connect(function() d = false end)

    local hB = Instance.new("TextButton", main); hB.Size = UDim2.new(0, 30, 0, 30); hB.Position = UDim2.new(1, -30, 0, 0); hB.Text = "+"; hB.TextColor3 = Color3.new(1,1,1); hB.BackgroundTransparency = 1
    hB.MouseButton1Click:Connect(function()
        content.Visible = not content.Visible
        main.Size = content.Visible and UDim2.new(0, 160, 0, 240) or UDim2.new(0, 160, 0, 30)
        hB.Text = content.Visible and "-" or "+"
    end)

    local function createToggle(text, y, key)
        local b = Instance.new("TextButton", content); b.Size = UDim2.new(0, 140, 0, 35); b.Position = UDim2.new(0, 10, 0, 10 + y); b.Text = text; b.BackgroundColor3 = config[key] and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(30, 30, 40); b.TextColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(function() 
            config[key] = not config[key]
            b.BackgroundColor3 = config[key] and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(30, 30, 40)
            if key == "speedHack" and not config[key] then if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = 20 end end
        end)
    end
    
    createToggle("AUTO CHEST", 0, "autoChest")
    createToggle("AUTO KILL", 40, "autoKill")
    createToggle("ESP", 80, "esp")
    createToggle("SPEED", 120, "speedHack")
    createToggle("FULL BRIGHT", 160, "fullBright")
end

-- === 6. ループ更新 (速度・青空・オートキル) ===
task.spawn(function()
    while true do
        pcall(function()
            if config.speedHack and LocalPlayer.Character then LocalPlayer.Character.Humanoid.WalkSpeed = config.walkSpeed end
            
            if config.autoKill and not config.autoChest then
                local root = LocalPlayer.Character.HumanoidRootPart
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if p.Character.Humanoid.Health > 0 then
                            root.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                            game:GetService("VirtualUser"):CaptureController()
                            game:GetService("VirtualUser"):Button1Down(Vector2.new(0,0))
                        end
                    end
                end
            end

            if config.fullBright then
                Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 9e9; Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
                for _, v in pairs(Lighting:GetDescendants()) do
                    if v:IsA("Atmosphere") or v:IsA("Clouds") or v:IsA("FogEnd") then v.Parent = game:GetService("TestService") end
                end
            else
                for _, v in pairs(game:GetService("TestService"):GetChildren()) do
                    if v:IsA("Atmosphere") or v:IsA("Clouds") then v.Parent = Lighting end
                end
            end
        end)
        task.wait(0.1)
    end
end)

setupUI()
