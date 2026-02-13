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
        esp = false, -- 新機能
        walkSpeed = 65,
        scanRange = 5000,
        whitelist = {} -- 友達の名前を入れる例: {"Player1"}
    }
end
local config = _G.TrollConfig

-- === 2. ESP機能 (名前・HP・ハイライト) ===
local function createESP(player)
    if player == LocalPlayer then return end
    
    local function updateESP()
        local char = player.Character
        if not char then return end
        
        -- Highlight (外枠)
        local hl = char:FindFirstChild("TrollHL") or Instance.new("Highlight", char)
        hl.Name = "TrollHL"
        hl.Enabled = config.esp
        -- ホワイトリストなら緑、それ以外は赤
        local isWL = table.find(config.whitelist, player.Name)
        hl.FillColor = isWL and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.5

        -- BillboardGui (名前/HPラベル)
        local head = char:FindFirstChild("Head")
        if head then
            local bill = head:FindFirstChild("TrollTags") or Instance.new("BillboardGui", head)
            bill.Name = "TrollTags"
            bill.AlwaysOnTop = true
            bill.Size = UDim2.new(0, 200, 0, 50)
            bill.ExtentsOffset = Vector3.new(0, 3, 0)
            bill.Enabled = config.esp

            local label = bill:FindFirstChild("Info") or Instance.new("TextLabel", bill)
            label.Name = "Info"
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = isWL and Color3.new(0, 1, 0) or Color3.new(1, 1, 1)
            label.TextStrokeTransparency = 0
            label.TextScaled = false
            label.TextSize = 14
            
            local hum = char:FindFirstChild("Humanoid")
            local hp = hum and math.floor(hum.Health) or 0
            label.Text = string.format("%s\n[HP: %d]", player.DisplayName or player.Name, hp)
        end
    end

    RunService.RenderStepped:Connect(function()
        if player.Parent and player.Character then
            updateESP()
        end
    end)
end

-- 全プレイヤーにESPを適用
for _, p in pairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)

-- === 3. 機能ロジック (明るさ・判定・ループ) ===
local function applyLighting()
    if config.fullBright then
        Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.FogEnd = 1e5
        Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        Lighting.GlobalShadows = true
    end
end

local function getTarget()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
    local root = LocalPlayer.Character.HumanoidRootPart
    if config.autoChest then
        local nearest, dist = nil, config.scanRange
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsDescendantOf(LocalPlayer.Character) then
                local p = v:FindFirstChildOfClass("ProximityPrompt") or v.Parent:FindFirstChildOfClass("ProximityPrompt")
                if p and p.Enabled then
                    local txt = (p.ActionText .. p.ObjectText):lower()
                    if not txt:find("入る") and not txt:find("設計図") and not txt:find("shop") then
                        if (v.Name .. v.Parent.Name):lower():find("chest") or (v.Name .. v.Parent.Name):lower():find("drop") then
                            local d = (root.Position - v.Position).Magnitude
                            if d < dist then nearest = v; dist = d end
                        end
                    end
                end
            end
        end
        if nearest then return nearest, "chest" end
    end
    if config.autoKill then
        local closest, dist = nil, 1000
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local h = p.Character:FindFirstChild("Humanoid")
                if h and h.Health > 0 and not table.find(config.whitelist, p.Name) then
                    local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if d < dist then closest = p; dist = d end
                end
            end
        end
        if closest then return closest, "player" end
    end
end

task.spawn(function()
    while true do
        pcall(function()
            local target, tType = getTarget()
            if target and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local root = LocalPlayer.Character.HumanoidRootPart
                if tType == "chest" then
                    root.CFrame = target.CFrame; task.wait(0.2)
                    local p = target:FindFirstChildOfClass("ProximityPrompt") or target.Parent:FindFirstChildOfClass("ProximityPrompt")
                    if p then fireproximityprompt(p) end; task.wait(1.2)
                else
                    root.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                    game:GetService("VirtualUser"):Button1Down(Vector2.new()); task.wait(0.1)
                end
            end
        end)
        task.wait(0.5)
    end
end)

-- === 4. UI構築 (v3.4) ===
local function setupUI()
    local pgui = LocalPlayer:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("TrollHubV34") then pgui.TrollHubV34:Destroy() end
    local gui = Instance.new("ScreenGui", pgui); gui.Name = "TrollHubV34"; gui.ResetOnSpawn = false
    
    local main = Instance.new("Frame", gui); main.Size = UDim2.new(0, 160, 0, 310); main.Position = UDim2.new(0.02, 0, 0.3, 0); main.BackgroundColor3 = Color3.fromRGB(20, 20, 25); main.BackgroundTransparency = 0.2; main.Active = true; main.ClipsDescendants = true; Instance.new("UICorner", main)
    local title = Instance.new("TextLabel", main); title.Size = UDim2.new(1, 0, 0, 30); title.Text = "Troll v3.4 [ESP]"; title.TextColor3 = Color3.new(1, 1, 1); title.BackgroundColor3 = Color3.fromRGB(40, 40, 60); Instance.new("UICorner", title)
    
    local hideBtn = Instance.new("TextButton", title); hideBtn.Size = UDim2.new(0, 25, 0, 25); hideBtn.Position = UDim2.new(1, -28, 0, 2.5); hideBtn.Text = "-"; hideBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90); hideBtn.TextColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", hideBtn)
    local isS = false; hideBtn.MouseButton1Click:Connect(function()
        isS = not isS
        main:TweenSize(isS and UDim2.new(0, 160, 0, 30) or UDim2.new(0, 160, 0, 310), "Out", "Quart", 0.3, true)
        hideBtn.Text = isS and "+" or "-"
    end)
    
    local dragging, dragStart, startPos
    main.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPos = main.Position end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = input.Position - dragStart; main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
    UserInputService.InputEnded:Connect(function() dragging = false end)

    local function createToggle(text, y, key)
        local b = Instance.new("TextButton", main); b.Size = UDim2.new(0, 140, 0, 35); b.Position = UDim2.new(0, 10, 0, 40 + y); b.Text = text; b.BackgroundColor3 = config[key] and Color3.fromRGB(0, 180, 200) or Color3.fromRGB(35, 35, 45); b.TextColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(function() 
            config[key] = not config[key]; b.BackgroundColor3 = config[key] and Color3.fromRGB(0, 180, 200) or Color3.fromRGB(35, 35, 45)
            if key == "fullBright" then applyLighting() end
        end)
    end
    
    createToggle("AUTO CHEST", 0, "autoChest")
    createToggle("AUTO KILL", 45, "autoKill")
    createToggle("PLAYER ESP", 90, "esp")
    createToggle("FULL BRIGHT", 135, "fullBright")
    createToggle("SPEED HACK", 180, "speedHack")
    createToggle("ANTI-AFK", 225, "antiAFK")
end

RunService.Heartbeat:Connect(function()
    if config.speedHack and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = config.walkSpeed end
    if config.fullBright then applyLighting() end
end)

LocalPlayer.CharacterAdded:Connect(function() task.wait(1); setupUI() end); setupUI()
