local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- === 1. 設定 ===
_G.TrollConfig = _G.TrollConfig or {
    autoChest = false, autoKill = false, esp = false, npcEsp = false, chestEsp = false, fullBright = false,
    speedHack = false, antiAFK = true, showStats = true, walkSpeed = 100, scanRange = 2500,
    vfly = false, tpfly = false, fly = false, noclip = false, freeze = false, antiFling = false,
    vflySpeed = 50, tpflySpeed = 5, flySpeed = 50
}
local config = _G.TrollConfig

local bigChestUI, chestCountLabelObj
local activeBossTags = {}
local cachedBosses = {}
local flyBodyVelocity, flyBodyGyro

-- === 2. HUDレイヤー ===
local pgui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
if pgui:FindFirstChild("TrollHubHUD") then pgui.TrollHubHUD:Destroy() end
local hudGui = Instance.new("ScreenGui", pgui)
hudGui.Name = "TrollHubHUD"
hudGui.ResetOnSpawn = false

local espFolder = pgui:FindFirstChild("TrollBossESPFolder")
if espFolder then espFolder:Destroy() end
espFolder = Instance.new("Folder", pgui)
espFolder.Name = "TrollBossESPFolder"

-- 📱 モバイル用 UI表示トグル
local toggleBtn = Instance.new("TextButton", hudGui)
toggleBtn.Size = UDim2.new(0, 45, 0, 45)
toggleBtn.Position = UDim2.new(0.5, -22, 0, 10)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
toggleBtn.BackgroundTransparency = 0.3
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Text = "UI"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 16
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 12)

local dragging, dragInput, dragStart, startPos
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = toggleBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
toggleBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local clickTime = 0
toggleBtn.MouseButton1Click:Connect(function()
    if tick() - clickTime > 0.2 then
        local coreGui = game:GetService("CoreGui")
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local rGui = coreGui:FindFirstChild("Rayfield") or playerGui:FindFirstChild("Rayfield")
        if rGui then
            local mainFrame = rGui:FindFirstChild("Main")
            if mainFrame then mainFrame.Visible = not mainFrame.Visible end
        end
    end
    clickTime = tick()
end)

-- 📊 FPS/Ping表示
local sF = Instance.new("Frame", hudGui)
sF.Size = UDim2.new(0, 120, 0, 50)
sF.Position = UDim2.new(0.02, 0, 0.2, 0)
sF.BackgroundColor3 = Color3.new(0,0,0)
sF.BackgroundTransparency = 0.5
sF.Visible = config.showStats
Instance.new("UICorner", sF)

local fL = Instance.new("TextLabel", sF)
fL.Size = UDim2.new(1,0,0.5,0); fL.BackgroundTransparency = 1; fL.TextColor3 = Color3.new(0,1,0); fL.Text = "FPS: --"

local pL = Instance.new("TextLabel", sF)
pL.Size = UDim2.new(1,0,0.5,0); pL.Position = UDim2.new(0,0,0.5,0); pL.BackgroundTransparency = 1; pL.TextColor3 = Color3.new(1,1,0); pL.Text = "Ping: --"

-- 📦 でかいUI
bigChestUI = Instance.new("Frame", hudGui)
bigChestUI.Size = UDim2.new(0, 300, 0, 150)
bigChestUI.Position = UDim2.new(0.5, -150, 0.5, -75)
bigChestUI.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
bigChestUI.Visible = config.autoChest
Instance.new("UICorner", bigChestUI)

chestCountLabelObj = Instance.new("TextLabel", bigChestUI)
chestCountLabelObj.Size = UDim2.new(1, 0, 0.6, 0); chestCountLabelObj.Text = "残りチェスト: 検索中..."
chestCountLabelObj.TextColor3 = Color3.new(1, 1, 1); chestCountLabelObj.TextScaled = true; chestCountLabelObj.BackgroundTransparency = 1

local chestOffBtn = Instance.new("TextButton", bigChestUI)
chestOffBtn.Size = UDim2.new(0.6, 0, 0.3, 0); chestOffBtn.Position = UDim2.new(0.2, 0, 0.65, 0)
chestOffBtn.Text = "OFF"; chestOffBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); chestOffBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", chestOffBtn)

-- === 3. Rayfield UI ===
local Window = Rayfield:CreateWindow({
    Name = "Troll Hub v7.9.1 (Chest ESP Fixed)",
    LoadingTitle = "Troll Hub Loading...",
    LoadingSubtitle = "by Troll",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)
local PlayerTab = Window:CreateTab("Player", 4483362458)
local EspTab = Window:CreateTab("ESP", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)

local AutoChestToggle = MainTab:CreateToggle({ Name = "AUTO CHEST", CurrentValue = config.autoChest, Flag = "AutoChest", Callback = function(Value) config.autoChest = Value; bigChestUI.Visible = Value end })
chestOffBtn.MouseButton1Click:Connect(function() if AutoChestToggle then AutoChestToggle:Set(false) end end)

MainTab:CreateToggle({ Name = "AUTO KILL", CurrentValue = config.autoKill, Flag = "AutoKill", Callback = function(Value) config.autoKill = Value end })

PlayerTab:CreateToggle({ Name = "VFly", CurrentValue = config.vfly, Flag = "VFly", Callback = function(Value) config.vfly = Value end })
PlayerTab:CreateSlider({ Name = "VFly Speed", Range = {10, 300}, Increment = 5, CurrentValue = config.vflySpeed, Flag = "VFlySpeed", Callback = function(Value) config.vflySpeed = Value end })

PlayerTab:CreateToggle({ Name = "TPFly", CurrentValue = config.tpfly, Flag = "TPFly", Callback = function(Value) config.tpfly = Value end })
PlayerTab:CreateSlider({ Name = "TPFly Speed", Range = {1, 50}, Increment = 1, CurrentValue = config.tpflySpeed, Flag = "TPFlySpeed", Callback = function(Value) config.tpflySpeed = Value end })

PlayerTab:CreateToggle({
    Name = "Fly (Standard)",
    CurrentValue = config.fly,
    Flag = "Fly",
    Callback = function(Value) 
        config.fly = Value 
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if Value then
                flyBodyVelocity = Instance.new("BodyVelocity", root)
                flyBodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
                flyBodyVelocity.Velocity = Vector3.zero
                flyBodyGyro = Instance.new("BodyGyro", root)
                flyBodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
                flyBodyGyro.P = 9e4
            else
                if flyBodyVelocity then flyBodyVelocity:Destroy() end
                if flyBodyGyro then flyBodyGyro:Destroy() end
            end
        end
    end
})
PlayerTab:CreateSlider({ Name = "Fly Speed", Range = {10, 300}, Increment = 5, CurrentValue = config.flySpeed, Flag = "FlySpeed", Callback = function(Value) config.flySpeed = Value end })
PlayerTab:CreateToggle({ Name = "Noclip", CurrentValue = config.noclip, Flag = "Noclip", Callback = function(Value) config.noclip = Value end })
PlayerTab:CreateToggle({ Name = "Freeze (Anchored)", CurrentValue = config.freeze, Flag = "Freeze", Callback = function(Value) config.freeze = Value; local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if root then root.Anchored = Value end end })
PlayerTab:CreateToggle({ Name = "Anti-Fling (他プレイヤーとの衝突無効)", CurrentValue = config.antiFling, Flag = "AntiFling", Callback = function(Value) config.antiFling = Value end })
PlayerTab:CreateToggle({ Name = "SPEED HACK", CurrentValue = config.speedHack, Flag = "SpeedHack", Callback = function(Value) config.speedHack = Value; if not Value and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = 16 end end })

EspTab:CreateToggle({ Name = "PLAYER ESP", CurrentValue = config.esp, Flag = "PlayerEsp", Callback = function(Value) config.esp = Value end })
EspTab:CreateToggle({ Name = "BOSS / NPC ESP", CurrentValue = config.npcEsp, Flag = "BossEsp", Callback = function(Value) config.npcEsp = Value; if not Value then for obj, tag in pairs(activeBossTags) do if tag then tag:Destroy() end end; table.clear(activeBossTags) end end })
EspTab:CreateToggle({ Name = "CHEST ESP", CurrentValue = config.chestEsp, Flag = "ChestEsp", Callback = function(Value) config.chestEsp = Value end })

MiscTab:CreateToggle({ Name = "FULL BRIGHT", CurrentValue = config.fullBright, Flag = "FullBright", Callback = function(Value) config.fullBright = Value; if not Value then Lighting.Brightness = 1; Lighting.ClockTime = 12 end end })
MiscTab:CreateToggle({ Name = "STATS HUD", CurrentValue = config.showStats, Flag = "StatsHud", Callback = function(Value) config.showStats = Value; sF.Visible = Value end })

-- === 4. Physics / Movement (Stepped) ===
RunService.Stepped:Connect(function()
    if config.noclip and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
    end
    if config.antiFling then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
            end
        end
    end
end)

-- === 5. Render & Fly Loop (RenderStepped) ===
RunService.RenderStepped:Connect(function(dt)
    if config.showStats then fL.Text = "FPS: " .. math.floor(1/dt); pL.Text = "Ping: " .. math.floor(LocalPlayer:GetNetworkPing() * 1000) .. "ms" end
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
            local tag = p.Character.Head:FindFirstChild("TrollTag") or Instance.new("BillboardGui", p.Character.Head)
            tag.Name = "TrollTag"; tag.AlwaysOnTop = true; tag.Size = UDim2.new(0, 100, 0, 40); tag.Enabled = config.esp
            local lbl = tag:FindFirstChild("Label") or Instance.new("TextLabel", tag)
            lbl.Name = "Label"; lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.new(1,1,1); lbl.TextStrokeTransparency = 0
            local hp = p.Character:FindFirstChild("Humanoid") and math.floor(p.Character.Humanoid.Health) or 0
            lbl.Text = p.DisplayName .. "\nHP: " .. hp
        end
    end

    if config.npcEsp then
        local currentList = {}
        for _, obj in pairs(cachedBosses) do
            local head = obj:FindFirstChild("Head") or obj:FindFirstChild("Torso") or obj:FindFirstChild("HumanoidRootPart")
            local hum = obj:FindFirstChild("Humanoid")
            if head and hum and hum.Health > 0 then
                currentList[obj] = true
                local tag = activeBossTags[obj]
                if not tag or not tag.Parent then
                    tag = Instance.new("BillboardGui"); tag.Name = "BossTag"; tag.AlwaysOnTop = true; tag.Size = UDim2.new(0, 100, 0, 40); tag.Adornee = head; tag.Parent = espFolder
                    local lbl = Instance.new("TextLabel", tag); lbl.Name = "Label"; lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(255, 50, 50); lbl.TextStrokeTransparency = 0; lbl.Font = Enum.Font.SourceSansBold
                    activeBossTags[obj] = tag
                end
                local displayName = obj.Name
                local healthBar = head:FindFirstChild("BossHealthBar")
                if healthBar then
                    local bossText = healthBar:FindFirstChild("boss")
                    if bossText and bossText:IsA("TextLabel") and bossText.Text ~= "" then displayName = bossText.Text end
                end
                tag.Label.Text = "[" .. displayName .. "]\nHP: " .. math.floor(hum.Health)
            end
        end
        for obj, tag in pairs(activeBossTags) do if not currentList[obj] or not obj.Parent then if tag then tag:Destroy() end; activeBossTags[obj] = nil end end
    end
    
    -- === 3D 飛行ロジック ===
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    if root and hum then
        local moveDir = hum.MoveDirection
        local dir3D = Vector3.zero
        
        if moveDir.Magnitude > 0 then
            local camCFrame = Camera.CFrame
            local flatLook = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z)
            if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
            
            local flatRight = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z)
            if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
            
            local forwardAmt = moveDir:Dot(flatLook)
            local rightAmt = moveDir:Dot(flatRight)
            
            dir3D = (camCFrame.LookVector * forwardAmt) + (camCFrame.RightVector * rightAmt)
            if dir3D.Magnitude > 0 then dir3D = dir3D.Unit end
        end
        
        if config.fly and flyBodyVelocity and flyBodyGyro then
            flyBodyGyro.CFrame = Camera.CFrame
            flyBodyVelocity.Velocity = dir3D * config.flySpeed
        end

        if config.vfly then
            if moveDir.Magnitude > 0 then root.Velocity = dir3D * config.vflySpeed
            else root.Velocity = Vector3.new(0, 0.1, 0) end
        end

        if config.tpfly then
            if moveDir.Magnitude > 0 then root.CFrame = root.CFrame + (dir3D * (config.tpflySpeed * (dt * 60))) end
            root.Velocity = Vector3.zero
        end
        
        if config.speedHack then hum.WalkSpeed = config.walkSpeed end
    end

    if config.fullBright then Lighting.Brightness = 2; Lighting.ClockTime = 14 end
end)

-- === 6. スキャナー ===
task.spawn(function()
    while true do
        pcall(function()
            if config.npcEsp then
                local found = {}
                local targets = { workspace:FindFirstChild("ActiveNPCs"), workspace:FindFirstChild("Map Boss"), workspace:FindFirstChild("Map folder") }
                for _, folder in pairs(targets) do
                    if folder then
                        for _, obj in pairs(folder:GetDescendants()) do
                            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and (obj:FindFirstChild("Head") or obj:FindFirstChild("HumanoidRootPart")) then
                                if not Players:GetPlayerFromCharacter(obj) then table.insert(found, obj) end
                            end
                        end
                    end
                end
                cachedBosses = found
            end
        end)
        task.wait(1)
    end
end)

-- === 7. 厳選テレポート (一切変更なし) ===
task.spawn(function()
    while true do
        pcall(function()
            if not (config.autoChest or config.autoKill) then task.wait(0.5) return end
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not root then task.wait(0.5) return end
            
            local target, isChest, dist = nil, false, config.scanRange
            local currentChestCount = 0 
            
            if config.autoChest then
                for _, p in pairs(workspace:GetDescendants()) do
                    if p:IsA("ProximityPrompt") and p.Enabled then
                        local obj = p.Parent
                        if obj:IsA("BasePart") then
                            local txt = (obj.Name .. obj.Parent.Name .. p.ActionText):lower()
                            if (txt:find("chest") or txt:find("drop") or txt:find("loot")) and 
                               not (txt:find("shop") or txt:find("npc") or txt:find("buy") or txt:find("talk")) then
                                
                                currentChestCount = currentChestCount + 1 
                                local d = (root.Position - obj.Position).Magnitude
                                if d < dist then target = obj; dist = d; isChest = true end
                            end
                        end
                    end
                end
            end
            
            if chestCountLabelObj and config.autoChest then
                local displayCount = currentChestCount - 3
                if not target or displayCount < 0 then displayCount = 0 end
                chestCountLabelObj.Text = "残りチェスト: " .. displayCount
            end

            if not target and config.autoKill then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if p.Character.Humanoid.Health > 0 then
                            local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                            if d < dist then target = p.Character.HumanoidRootPart; dist = d; isChest = false end
                        end
                    end
                end
            end
            
            if target then
                root.CFrame = isChest and target.CFrame or target.CFrame * CFrame.new(0, 0, 3)
                if isChest then
                    task.wait(0.1)
                    fireproximityprompt(target:FindFirstChildOfClass("ProximityPrompt") or target.Parent:FindFirstChildOfClass("ProximityPrompt"))
                else
                    game:GetService("VirtualUser"):Button1Down(Vector2.new(0,0))
                end
            end
        end)
        task.wait(0.1)
    end
end)

-- === 8. Chest ESP (追加・遅延ロード対応版) ===
local folderName = "AllChestESP_Folder"
if pgui:FindFirstChild(folderName) then pgui[folderName]:Destroy() end

local chestEspFolder = Instance.new("Folder")
chestEspFolder.Name = folderName
chestEspFolder.Parent = pgui

local function createESP(target)
    -- 新規スポーン時、中身のパーツが揃うまで少し待つ処理を追加
    task.spawn(function()
        local displayName = ""
        local espColor = Color3.new(1, 1, 1)
        
        if target.Name == "Chest_Spawn" then
            displayName = "📦 Chest"
            espColor = Color3.fromRGB(255, 215, 0)
        elseif target.Name == "LightChest_Spawn" then
            displayName = "✨ Light Chest"
            espColor = Color3.fromRGB(255, 255, 150)
        elseif target.Name == "DarkChest_Spawn" then
            displayName = "🌑 Dark Chest"
            espColor = Color3.fromRGB(180, 50, 255)
        elseif target.Name == "RadioactiveChest_Spawn" then
            displayName = "☢️ Radioactive Chest"
            espColor = Color3.fromRGB(50, 255, 50)
        elseif target.Name == "MachineChest_p" then
            displayName = "⚙️ Machine Chest"
            espColor = Color3.fromRGB(0, 200, 255)
        else
            return
        end

        local attachPart = target:FindFirstChild("Handle") or target:FindFirstChild("MachineChest_p") or target:FindFirstChildWhichIsA("BasePart", true)
        
        -- アタッチするパーツが見つからなければ、数回リトライしてロードを待つ
        if not attachPart and target:IsA("Model") then
            for i = 1, 10 do
                task.wait(0.2)
                if not target.Parent then return end -- 消滅したら中断
                attachPart = target:FindFirstChild("Handle") or target:FindFirstChild("MachineChest_p") or target:FindFirstChildWhichIsA("BasePart", true)
                if attachPart then break end
            end
        end

        if not attachPart and target:IsA("BasePart") then
            attachPart = target
        end
        if not attachPart then return end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ChestLabel"
        billboard.Adornee = attachPart
        billboard.Size = UDim2.new(0, 200, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        
        local label = Instance.new("TextLabel")
        label.Parent = billboard
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = displayName
        label.TextColor3 = espColor
        label.TextStrokeTransparency = 0
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        
        billboard.Parent = chestEspFolder

        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not target or not target.Parent or not attachPart or not attachPart.Parent then
                billboard:Destroy()
                connection:Disconnect()
                return
            end
            
            billboard.Enabled = config.chestEsp
            
            if config.chestEsp then
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local distance = math.floor((root.Position - attachPart.Position).Magnitude)
                    label.Text = displayName .. " [" .. distance .. "m]"
                end
            end
        end)
    end)
end

-- 既存のチェストに適用
for _, v in pairs(workspace:GetDescendants()) do
    createESP(v)
end

-- 新規追加チェストに適用
workspace.DescendantAdded:Connect(function(v)
    createESP(v)
end)
