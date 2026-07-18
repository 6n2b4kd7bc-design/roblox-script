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

-- ヘッダー (ここを掴んでドラッグ移動可能)
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
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 500) -- 機能が増えたらここを広げられます
scrollFrame.ScrollBarThickness = 5
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 110)

-- === 2. UIの操作ロジック (移動・収納) ===
-- ドラッグ機能
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

-- 折りたたみ機能
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

-- ハブ内ボタン作成用共通関数
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

-- ----------------------------------------------------
-- 【機能 1】モバイル用 銃撃連打 (HipShot)
-- ----------------------------------------------------
local loadSpammerBtn = createFeatureButton("🔫 モバイル用連打をロード", 15)

loadSpammerBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Camera = workspace.CurrentCamera
        local Event = ReplicatedStorage:WaitForChild("WeaponRemotes"):WaitForChild("Initiate")

        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("MobileSpammerUI") then
            coreGui.MobileSpammerUI:Destroy()
        end

        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "MobileSpammerUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.75, -70, 0.7, -30) -- 画面右下
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        toggleBtn.Text = "💥 連打: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 16
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        -- 個別ボタンのドラッグ移動
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
                        local currentCF = Camera.CFrame
                        local targetPos = getCenterTargetPosition()
                        pcall(function()
                            Event:FireServer("HipShot", {GunCF = currentCF, MousePos = targetPos})
                        end)
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
    task.delay(1.5, function()
        loadSpammerBtn.Text = "🔫 モバイル用連打をロード"
        loadSpammerBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
    end)
end)

-- ----------------------------------------------------
-- 【機能 2】モバイル用 アイテム・近接連打 (ActivateItem)
-- ----------------------------------------------------
local loadItemSpammerBtn = createFeatureButton("🔪 アイテム連打をロード", 65)

loadItemSpammerBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local Camera = workspace.CurrentCamera
        local Event = ReplicatedStorage:WaitForChild("WeaponRemotes"):WaitForChild("ActivateItem")

        local coreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
        if coreGui:FindFirstChild("ItemSpammerUI") then
            coreGui.ItemSpammerUI:Destroy()
        end

        local spamGui = Instance.new("ScreenGui", coreGui)
        spamGui.Name = "ItemSpammerUI"
        spamGui.ResetOnSpawn = false

        local toggleBtn = Instance.new("TextButton", spamGui)
        toggleBtn.Size = UDim2.new(0, 140, 0, 60)
        toggleBtn.Position = UDim2.new(0.75, -70, 0.5, -30) -- 銃ボタンと被らないように少し上に配置
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
        toggleBtn.Text = "🔪 アイテム連打: OFF"
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 14
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

        -- 個別ボタンのドラッグ移動
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
                        local currentCF = Camera.CFrame
                        pcall(function()
                            Event:FireServer("R", "L", currentCF)
                        end)
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
    task.delay(1.5, function()
        loadItemSpammerBtn.Text = "🔪 アイテム連打をロード"
        loadItemSpammerBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
    end)
end)
