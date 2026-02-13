local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- === 1. 設定の永続化 ===
if not _G.TrollConfig then
    _G.TrollConfig = {
        autoChest = false, 
        autoKill = false,
        antiAFK = true,
        fullBright = false,
        speedHack = false,
        esp = false,
        walkSpeed = 65,
        scanRange = 8000,
        whitelist = {}
    }
end
local config = _G.TrollConfig

-- === 2. 独立型 ESP システム (修正版) ===
local function applyESP(player)
    if player == LocalPlayer then return end
    
    local function setupVisuals()
        local char = player.Character or player.CharacterAdded:Wait()
        
        -- Highlight (外枠)
        local hl = char:FindFirstChild("TrollHL") or Instance.new("Highlight", char)
        hl.Name = "TrollHL"
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.5

        -- Billboard (名前・HP)
        local head = char:WaitForChild("Head", 5)
        if head then
            local bill = head:FindFirstChild("TrollTags") or Instance.new("BillboardGui", head)
            bill.Name = "TrollTags"
            bill.AlwaysOnTop = true
            bill.Size = UDim2.new(0, 200, 0, 50)
            bill.ExtentsOffset = Vector3.new(0, 3, 0)
            
            local label = bill:FindFirstChild("Info") or Instance.new("TextLabel", bill)
            label.Name = "Info"
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextStrokeTransparency = 0
            label.TextSize = 14
        end
    end

    -- 毎フレーム更新 (色と表示状態)
    RunService.RenderStepped:Connect(function()
        if player.Character and player.Character:FindFirstChild("TrollHL") then
            local char = player.Character
            local hl = char.TrollHL
            local bill = char:FindFirstChild("Head") and char.Head:FindFirstChild("TrollTags")
            
            if config.esp then
                hl.Enabled = true
                local isWL = table.find(config.whitelist, player.Name) or table.find(config.whitelist, player.DisplayName)
                hl.FillColor = isWL and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
                
                if bill then
                    bill.Enabled = true
                    local hum = char:FindFirstChild("Humanoid")
                    bill.Info.Text = string.format("%s\n[HP: %d]", player.DisplayName, (hum and hum.Health or 0))
                    bill.Info.TextColor3 = isWL and Color3.new(0, 1, 0) or Color3.new(1, 1, 1)
                end
            else
                hl.Enabled = false
                if bill then bill.Enabled = false end
            end
        elseif player.Character and config.esp then
            setupVisuals()
        end
    end)
end

-- 全員に適用
for _, p in pairs(Players:GetPlayers()) do applyESP(p) end
Players.PlayerAdded:Connect(applyESP)

-- === 3. 高速テレポート & 判定 ===
local function isRealChest(obj)
    if not obj:IsA("BasePart") then return false end
    local name = (obj.Name .. obj.Parent.Name):lower()
    if name:find("chest") or name:find("drop") or name:find("treasure") then
        local p = obj:FindFirstChildOfClass("ProximityPrompt") or obj.Parent:FindFirstChildOfClass("ProximityPrompt")
        return p and p.Enabled
    end
    return false
end

task.spawn(function()
    while true do
        pcall(function()
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
            local root = LocalPlayer.Character.HumanoidRootPart
            local targetObj = nil
            local isChest = false

            if config.autoChest then
                local dist = config.scanRange
                for _, v in pairs(workspace:GetDescendants()) do
                    if isRealChest(v) then
                        local d = (root.Position - v.Position).Magnitude
                        if d < dist then targetObj = v; dist = d; isChest = true end
                    end
                end
            end

            if not targetObj and config.autoKill then
                local dist = 2000
                for _, p in pairs(Players:GetPlayers()) do
                    local isWL = table.find(config.whitelist, p.Name) or table.find(config.whitelist, p.DisplayName)
                    if p ~= LocalPlayer and not isWL and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                        local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                        if d < dist then targetObj = p.Character.HumanoidRootPart; dist = d; isChest = false end
                    end
                end
            end

            if targetObj then
                root.CFrame = isChest and targetObj.CFrame or targetObj.CFrame * CFrame.new(0, 0, 3)
                if isChest then
                    task.wait(0.05)
                    local p = targetObj:FindFirstChildOfClass("ProximityPrompt") or targetObj.Parent:FindFirstChildOfClass("ProximityPrompt")
                    if p then fireproximityprompt(p) end
                    task.wait(0.4)
                else
                    game:GetService("VirtualUser"):Button1Down(Vector2.new())
                    task.wait(0.05)
                end
            end
        end)
        task.wait(0.1)
    end
end)

-- === 4. UI 構築 ===
local function setupUI()
    local pgui = LocalPlayer:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("TrollHubV38") then pgui.TrollHubV38:Destroy() end
    local gui = Instance.new("ScreenGui", pgui); gui.Name = "TrollHubV38"; gui.ResetOnSpawn = false
    local main = Instance.new("Frame", gui); main.Size = UDim2.new(0, 160, 0, 310); main.Position = UDim2.new(0.02, 0, 0.3, 0); main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); main.BackgroundTransparency = 0.2; main.Active = true; main.ClipsDescendants = true; Instance.new("UICorner", main)
    local title = Instance.new("TextLabel", main); title.Size = UDim2.new(1, 0, 0, 30); title.Text = "Troll v3.8 Stable"; title.TextColor3 = Color3.new(1, 1, 1); title.BackgroundColor3 = Color3.fromRGB(40, 40, 60); Instance.new("UICorner", title)
    
    local hideBtn = Instance.new("TextButton", title); hideBtn.Size = UDim2.new(0, 25, 0, 25); hideBtn.Position = UDim2.new(1, -28, 0, 2.5); hideBtn.Text = "-"; hideBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80); hideBtn.TextColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", hideBtn)
    local isS = false; hideBtn.MouseButton1Click:Connect(function() isS = not isS; main:TweenSize(isS and UDim2.new(0, 160, 0, 30) or UDim2.new(0, 160, 0, 310), "Out", "Quart", 0.3, true); hideBtn.Text = isS and "+" or "-" end)
    
    local dragging, dragStart, startPos
    main.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPos = main.Position end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = input.Position - dragStart; main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
    UserInputService.InputEnded:Connect(function() dragging = false end)

    local function createToggle(text, y, key)
        local b = Instance.new("TextButton", main); b.Size = UDim2.new(0, 140, 0, 35); b.Position = UDim2.new(0, 10, 0, 40 + y); b.Text = text; b.BackgroundColor3 = config[key] and Color3.fromRGB(0, 160, 180) or Color3.fromRGB(30, 30, 40); b.TextColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(function() config[key] = not config[key]; b.BackgroundColor3 = config[key] and Color3.fromRGB(0, 160, 180) or Color3.fromRGB(30, 30, 40) end)
    end
    createToggle("AUTO CHEST", 0, "autoChest"); createToggle("AUTO KILL", 45, "autoKill"); createToggle("PLAYER ESP", 90, "esp"); createToggle("FULL BRIGHT", 135, "fullBright"); createToggle("SPEED HACK", 180, "speedHack"); createToggle("ANTI-AFK", 225, "antiAFK")
end

RunService.Heartbeat:Connect(function()
    if config.speedHack and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = config.walkSpeed end
    if config.fullBright then Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 1e5; Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.new(1, 1, 1) end
end)

LocalPlayer.CharacterAdded:Connect(function() task.wait(1); setupUI() end); setupUI()
