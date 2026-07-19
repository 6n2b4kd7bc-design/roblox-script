local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- === 1. Hub UIのベース作成 ===
local pgui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
if pgui:FindFirstChild("MotobuHubUI") then
    pgui.MotobuHubUI:Destroy()
end

local screenGui = Instance.new("ScreenGui", pgui)
screenGui.Name = "MotobuHubUI"
screenGui.ResetOnSpawn = false

-- メインフレーム
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 300, 0, 350)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

-- ヘッダー (ドラッグ移動可能)
local header = Instance.new("Frame", mainFrame)
header.Size = UDim2.new(1, 0, 0, 35)
header.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

local headerFix = Instance.new("Frame", header)
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
headerFix.BorderSizePixel = 0

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "MotobuV20 - Main Hub"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

-- 収納ボタン (-)
local collapseBtn = Instance.new("TextButton", header)
collapseBtn.Size = UDim2.new(0, 35, 0, 35)
collapseBtn.Position = UDim2.new(1, -35, 0, 0)
collapseBtn.BackgroundTransparency = 1
collapseBtn.Text = "-"
collapseBtn.TextColor3 = Color3.new(1, 1, 1)
collapseBtn.TextSize = 20
collapseBtn.Font = Enum.Font.GothamBold

-- スクロール可能なコンテンツエリア
local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
scrollFrame.Size = UDim2.new(1, 0, 1, -35)
scrollFrame.Position = UDim2.new(0, 0, 0, 35)
scrollFrame.BackgroundTransparency = 1
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 650)
scrollFrame.ScrollBarThickness = 5
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 110)

-- === 2. UIの操作ロジック (移動・収納) ===
local dragging, dragInput, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local isCollapsed = false
collapseBtn.MouseButton1Click:Connect(function()
    isCollapsed = not isCollapsed
    scrollFrame.Visible = not isCollapsed
    if isCollapsed then
        mainFrame.Size = UDim2.new(0, 300, 0, 35)
        collapseBtn.Text = "+"
    else
        mainFrame.Size = UDim2.new(0, 300, 0, 350)
        collapseBtn.Text = "-"
    end
end)

local function createFeatureButton(text, yPos)
    local btn = Instance.new("TextButton", scrollFrame)
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

-- === 3. 各機能ボタンの組み込み ===

-- 【機能 1】モバイル用 銃撃連打 (HipShot)
local loadSpammerBtn = createFeatureButton("🔫 モバイル用連打をロード", 15)
loadSpammerBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Camera = workspace.CurrentCamera
        local Event = ReplicatedStorage:WaitForChild("WeaponRemotes"):WaitForChild("Initiate")

        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("MobileSpammerUI") then coreGui.MobileSpammerUI:Destroy() end
        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "MobileSpammerUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.75, -70, 0.7, -30)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        toggleBtn.Text = "💥 連打: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 16
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        local btnDragging, btnDragInput, btnDragStart, btnStartPos
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                btnDragging = true
                btnDragStart = input.Position
                btnStartPos = toggleBtn.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
            end
        end)
        toggleBtn.InputChanged:Connect(function(input)
            if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - btnDragStart
                toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
            end
        end)

        local function getCenterTargetPosition()
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            if LocalPlayer.Character then raycastParams.FilterDescendantsInstances = {LocalPlayer.Character} end
            local rayOrigin = Camera.CFrame.Position
            local rayDirection = Camera.CFrame.LookVector * 1000
            local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
            return raycastResult and raycastResult.Position or (rayOrigin + rayDirection)
        end

        local isSpamming = false
        toggleBtn.MouseButton1Click:Connect(function()
            isSpamming = not isSpamming
            if isSpamming then
                toggleBtn.Text = "🔥 連打: ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                task.spawn(function()
                    while isSpamming do
                        pcall(function() Event:FireServer("HipShot", {GunCF = Camera.CFrame, MousePos = getCenterTargetPosition()}) end)
                        task.wait(0.02) 
                    end
                end)
            else
                toggleBtn.Text = "💥 連打: OFF"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            end
        end)
    end)
    loadSpammerBtn.Text = "✅ ロード完了！"
    loadSpammerBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    task.delay(1.5, function() loadSpammerBtn.Text = "🔫 モバイル用連打をロード" loadSpammerBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200) end)
end)

-- 【機能 2】モバイル用 アイテム・近接連打 (ActivateItem)
local loadItemSpammerBtn = createFeatureButton("🔪 アイテム連打をロード", 65)
loadItemSpammerBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Camera = workspace.CurrentCamera
        local Event = ReplicatedStorage:WaitForChild("WeaponRemotes"):WaitForChild("ActivateItem")

        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("ItemSpammerUI") then coreGui.ItemSpammerUI:Destroy() end
        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "ItemSpammerUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.75, -70, 0.5, -30)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
        toggleBtn.Text = "🔪 アイテム連打: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 14
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        local btnDragging, btnDragInput, btnDragStart, btnStartPos
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                btnDragging = true
                btnDragStart = input.Position
                btnStartPos = toggleBtn.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
            end
        end)
        toggleBtn.InputChanged:Connect(function(input)
            if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - btnDragStart
                toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
            end
        end)

        local isSpamming = false
        toggleBtn.MouseButton1Click:Connect(function()
            isSpamming = not isSpamming
            if isSpamming then
                toggleBtn.Text = "🔥 アイテム連打: ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
                task.spawn(function()
                    while isSpamming do
                        pcall(function() Event:FireServer("R", "L", Camera.CFrame) end)
                        task.wait(0.05) 
                    end
                end)
            else
                toggleBtn.Text = "🔪 アイテム連打: OFF"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
            end
        end)
    end)
    loadItemSpammerBtn.Text = "✅ ロード完了！"
    loadItemSpammerBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    task.delay(1.5, function() loadItemSpammerBtn.Text = "🔪 アイテム連打をロード" loadItemSpammerBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200) end)
end)

-- 【機能 3】Buddy自動回収 (HoldObject)
local loadBuddyBtn = createFeatureButton("🧸 Buddy自動回収をロード", 115)
loadBuddyBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Event = ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("AntiquesAndHolding"):WaitForChild("HoldObject")

        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("BuddySpammerUI") then coreGui.BuddySpammerUI:Destroy() end
        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "BuddySpammerUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.75, -70, 0.3, -30)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200) 
        toggleBtn.Text = "🧸 Buddy回収: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 14
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        local btnDragging, btnDragInput, btnDragStart, btnStartPos
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                btnDragging = true
                btnDragStart = input.Position
                btnStartPos = toggleBtn.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
            end
        end)
        toggleBtn.InputChanged:Connect(function(input)
            if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - btnDragStart
                toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
            end
        end)

        local isSpamming = false
        toggleBtn.MouseButton1Click:Connect(function()
            isSpamming = not isSpamming
            if isSpamming then
                toggleBtn.Text = "🧸 Buddy回収: ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 250)
                task.spawn(function()
                    while isSpamming do
                        pcall(function()
                            local buddytv = workspace:FindFirstChild("BUDDYTV")
                            if buddytv then
                                local buddy = buddytv:FindFirstChild("Buddy")
                                if buddy then
                                    Event:FireServer("Start", buddy, "BuddyHold")
                                end
                            end
                        end)
                        task.wait(0.5) 
                    end
                end)
            else
                toggleBtn.Text = "🧸 Buddy回収: OFF"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
            end
        end)
    end)
    loadBuddyBtn.Text = "✅ ロード完了！"
    loadBuddyBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    task.delay(1.5, function() loadBuddyBtn.Text = "🧸 Buddy自動回収をロード" loadBuddyBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200) end)
end)

-- 【機能 4】お金(Celz) 自動回収 (CelzCollect)
local loadMoneyBtn = createFeatureButton("💰 お金(Celz)自動回収をロード", 165)
loadMoneyBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Event = ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("Shop"):WaitForChild("CelzCollect")

        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("MoneySpammerUI") then coreGui.MoneySpammerUI:Destroy() end
        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "MoneySpammerUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.75, -70, 0.1, -30)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 20)
        toggleBtn.Text = "💰 お金回収: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 14
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        local btnDragging, btnDragInput, btnDragStart, btnStartPos
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                btnDragging = true
                btnDragStart = input.Position
                btnStartPos = toggleBtn.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
            end
        end)
        toggleBtn.InputChanged:Connect(function(input)
            if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - btnDragStart
                toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
            end
        end)

        local isSpamming = false
        toggleBtn.MouseButton1Click:Connect(function()
            isSpamming = not isSpamming
            if isSpamming then
                toggleBtn.Text = "💸 お金回収: ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(250, 200, 50)
                task.spawn(function()
                    while isSpamming do
                        local foundCelz = {}
                        for _, obj in workspace:GetDescendants() do
                            if obj.Name:match("^Celz%d+$") then table.insert(foundCelz, obj) end
                        end
                        pcall(function()
                            for _, obj in getnilinstances() do
                                if obj.Name:match("^Celz%d+$") then table.insert(foundCelz, obj) end
                            end
                        end)

                        for _, obj in foundCelz do
                            local valueStr = obj.Name:match("%d+")
                            if valueStr then
                                pcall(function() Event:FireServer(tonumber(valueStr), obj) end)
                            end
                        end
                        task.wait(1) 
                    end
                end)
            else
                toggleBtn.Text = "💰 お金回収: OFF"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 20)
            end
        end)
    end)
    loadMoneyBtn.Text = "✅ ロード完了！"
    loadMoneyBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    task.delay(1.5, function() loadMoneyBtn.Text = "💰 お金(Celz)自動回収をロード" loadMoneyBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200) end)
end)

-- 【機能 5】Stains(汚れ) 近距離ESP
local loadStainBtn = createFeatureButton("🧽 Stains近距離ESPをロード", 215)
loadStainBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("StainEspUI") then coreGui.StainEspUI:Destroy() end
        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "StainEspUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.25, -70, 0.3, -30)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 50)
        toggleBtn.Text = "🧽 Stains ESP: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 14
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        local btnDragging, btnDragInput, btnDragStart, btnStartPos
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                btnDragging = true
                btnDragStart = input.Position
                btnStartPos = toggleBtn.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
            end
        end)
        toggleBtn.InputChanged:Connect(function(input)
            if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - btnDragStart
                toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
            end
        end)

        local isSpamming = false
        toggleBtn.MouseButton1Click:Connect(function()
            isSpamming = not isSpamming
            if isSpamming then
                toggleBtn.Text = "✨ Stains ESP: ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 200, 50)
                task.spawn(function()
                    while isSpamming do
                        pcall(function()
                            local char = LocalPlayer.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            local addedStains = workspace:FindFirstChild("AddedStains")

                            if hrp and addedStains then
                                for _, stain in addedStains:GetChildren() do
                                    local targetPart = stain:IsA("BasePart") and stain or stain:FindFirstChildWhichIsA("BasePart")
                                    if targetPart then
                                        local dist = (targetPart.Position - hrp.Position).Magnitude
                                        local espGui = targetPart:FindFirstChild("StainESP_Motobu")
                                        
                                        if dist <= 80 then
                                            if not espGui then
                                                espGui = Instance.new("BillboardGui", targetPart)
                                                espGui.Name = "StainESP_Motobu"
                                                espGui.Size = UDim2.new(0, 80, 0, 20)
                                                espGui.AlwaysOnTop = true
                                                
                                                local text = Instance.new("TextLabel", espGui)
                                                text.Size = UDim2.new(1, 0, 1, 0)
                                                text.BackgroundTransparency = 1
                                                text.Text = "🧽 汚れ"
                                                text.TextColor3 = Color3.new(0.5, 1, 0.5)
                                                text.TextStrokeTransparency = 0.5
                                                text.TextScaled = true
                                                text.Font = Enum.Font.GothamBold
                                            end
                                            espGui.Enabled = true
                                        else
                                            if espGui then espGui.Enabled = false end
                                        end
                                    end
                                end
                            end
                        end)
                        task.wait(0.5)
                    end
                    
                    local addedStains = workspace:FindFirstChild("AddedStains")
                    if addedStains then
                        for _, stain in addedStains:GetDescendants() do
                            if stain.Name == "StainESP_Motobu" then stain:Destroy() end
                        end
                    end
                end)
            else
                toggleBtn.Text = "🧽 Stains ESP: OFF"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 50)
            end
        end)
    end)
    loadStainBtn.Text = "✅ ロード完了！"
    loadStainBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    task.delay(1.5, function() loadStainBtn.Text = "🧽 Stains近距離ESPをロード" loadStainBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200) end)
end)

-- 【機能 6】Antiques(骨董品) 自動回収
local loadAntiqueBtn = createFeatureButton("🏺 骨董品自動回収をロード", 265)
loadAntiqueBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Event = ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("AntiquesAndHolding"):WaitForChild("HoldObject")

        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("AntiqueSpammerUI") then coreGui.AntiqueSpammerUI:Destroy() end
        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "AntiqueSpammerUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.25, -70, 0.5, -30)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
        toggleBtn.Text = "🏺 骨董品回収: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 14
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        local btnDragging, btnDragInput, btnDragStart, btnStartPos
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                btnDragging = true
                btnDragStart = input.Position
                btnStartPos = toggleBtn.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
            end
        end)
        toggleBtn.InputChanged:Connect(function(input)
            if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - btnDragStart
                toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
            end
        end)

        local isSpamming = false
        toggleBtn.MouseButton1Click:Connect(function()
            isSpamming = not isSpamming
            if isSpamming then
                toggleBtn.Text = "✨ 骨董品回収: ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 130, 50)
                task.spawn(function()
                    while isSpamming do
                        pcall(function()
                            local addedAntiques = workspace:FindFirstChild("AddedAntiques")
                            if addedAntiques then
                                for _, antique in addedAntiques:GetChildren() do
                                    Event:FireServer("Start", antique, "NormalHold")
                                end
                            end
                        end)
                        task.wait(1) 
                    end
                end)
            else
                toggleBtn.Text = "🏺 骨董品回収: OFF"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
            end
        end)
    end)
    loadAntiqueBtn.Text = "✅ ロード完了！"
    loadAntiqueBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    task.delay(1.5, function() loadAntiqueBtn.Text = "🏺 骨董品自動回収をロード" loadAntiqueBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200) end)
end)

-- ----------------------------------------------------
-- 【機能 7】Kill Aura (遠隔モンスターキル) [NEW]
-- ----------------------------------------------------
local loadKillAuraBtn = createFeatureButton("⚔️ 遠隔キル(Kill Aura)をロード", 315)
loadKillAuraBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Event = ReplicatedStorage:WaitForChild("WeaponRemotes"):WaitForChild("Attack")

        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("KillAuraUI") then coreGui.KillAuraUI:Destroy() end
        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "KillAuraUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.5, -70, 0.2, -30) -- 中央上部に配置
        toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
        toggleBtn.Text = "⚔️ 遠隔キル: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 14
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        local btnDragging, btnDragInput, btnDragStart, btnStartPos
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                btnDragging = true
                btnDragStart = input.Position
                btnStartPos = toggleBtn.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
            end
        end)
        toggleBtn.InputChanged:Connect(function(input)
            if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - btnDragStart
                toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
            end
        end)

        local isSpamming = false
        toggleBtn.MouseButton1Click:Connect(function()
            isSpamming = not isSpamming
            if isSpamming then
                toggleBtn.Text = "☠️ 遠隔キル: ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
                task.spawn(function()
                    while isSpamming do
                        pcall(function()
                            local monsterContainer = workspace:FindFirstChild("MonsterContainer")
                            if monsterContainer then
                                for _, monster in monsterContainer:GetChildren() do
                                    -- 攻撃判定の的(Icosphere)か、その他のメインパーツを探す
                                    local targetPart = monster:FindFirstChild("Icosphere") or monster:FindFirstChildWhichIsA("BasePart")
                                    
                                    if targetPart then
                                        -- 持っている武器の名前を取得（無ければBroom）
                                        local weaponName = "Broom"
                                        local char = LocalPlayer.Character
                                        if char then
                                            local equippedTool = char:FindFirstChildOfClass("Tool")
                                            if equippedTool then
                                                weaponName = equippedTool.Name
                                            end
                                        end

                                        -- ダメージ判定のリモートを対象の現在位置(CFrame)で送信
                                        Event:FireServer(
                                            targetPart,
                                            weaponName,
                                            { CFrame = targetPart.CFrame }
                                        )
                                    end
                                end
                            end
                        end)
                        task.wait(0.2) -- ラグやキック対策のため0.2秒間隔で攻撃
                    end
                end)
            else
                toggleBtn.Text = "⚔️ 遠隔キル: OFF"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
            end
        end)
    end)
    loadKillAuraBtn.Text = "✅ ロード完了！"
    loadKillAuraBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    task.delay(1.5, function() loadKillAuraBtn.Text = "⚔️ 遠隔キル(Kill Aura)をロード" loadKillAuraBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200) end)
end)
