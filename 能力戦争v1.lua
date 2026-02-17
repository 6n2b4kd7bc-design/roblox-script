local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- === 設定フラグ ===
local config = {
    antiVoid = false, -- 初期状態はOFF
    hitbox = false,
    cameraFly = false
}
local flySpeed = 1.8
local camOffset = Vector3.new(0, 8, 0)
local verticalMove = 0
local menuOpen = true

-- 🔴 復帰地点の調整 (地面に近い高さに設定)
local ARENA_CENTER = Vector3.new(0, 10, 0) 

local ControlModule = require(LocalPlayer:WaitForChild("PlayerScripts").PlayerModule:WaitForChild("ControlModule"))

-- ヒットボックスリセット
local function resetHitboxes()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = p.Character.HumanoidRootPart
            hrp.Size = Vector3.new(2, 2, 1)
            hrp.Transparency = 0
            hrp.CanCollide = true
        end
    end
end

-- === UI構築 (ドラッグ・収納対応) ===
local screenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
screenGui.Name = "GeminiMobileFixed"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 150, 0, 220)
mainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.Active = true
mainFrame.ClipsDescendants = true
Instance.new("UICorner", mainFrame)

local titleBar = Instance.new("TextButton", mainFrame)
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
titleBar.Text = "GEMINI HUB [Close]"
titleBar.TextColor3 = Color3.new(1, 1, 1)
titleBar.Font = Enum.Font.GothamBold
Instance.new("UICorner", titleBar)

local container = Instance.new("Frame", mainFrame)
container.Size = UDim2.new(1, 0, 1, -30)
container.Position = UDim2.new(0, 0, 0, 30)
container.BackgroundTransparency = 1
Instance.new("UIListLayout", container).Padding = UDim.new(0, 5)
container.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- 収納 & ドラッグ
titleBar.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    mainFrame:TweenSize(menuOpen and UDim2.new(0, 150, 0, 220) or UDim2.new(0, 150, 0, 30), "Out", "Quad", 0.3, true)
    titleBar.Text = menuOpen and "GEMINI HUB [Close]" or "GEMINI HUB [Open]"
end)

local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function() dragging = false end)

-- トグルボタン生成
local function createToggle(name, key)
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Text = name .. ": OFF"
    btn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    Instance.new("UICorner", btn)

    btn.MouseButton1Click:Connect(function()
        config[key] = not config[key]
        btn.Text = name .. ": " .. (config[key] and "ON" or "OFF")
        btn.BackgroundColor3 = config[key] and Color3.fromRGB(30, 100, 30) or Color3.fromRGB(100, 30, 30)
        
        if key == "cameraFly" and not config[key] then
            local char = LocalPlayer.Character
            Camera.CameraType = Enum.CameraType.Custom
            if char and char:FindFirstChild("Humanoid") then
                Camera.CameraSubject = char.Humanoid
            end
            camOffset = Vector3.new(0, 8, 0)
        end
        if key == "hitbox" and not config[key] then resetHitboxes() end
    end)
end

-- スピードボタン
local speedBtn = Instance.new("TextButton", container)
speedBtn.Size = UDim2.new(0.9, 0, 0, 35); speedBtn.Text = "Fly Speed: x1.8"; speedBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
speedBtn.TextColor3 = Color3.new(1, 1, 1); speedBtn.Font = Enum.Font.GothamBold; speedBtn.TextSize = 10; Instance.new("UICorner", speedBtn)
local speeds = {1.8, 3.0, 5.0, 0.5}; local speedIndex = 1
speedBtn.MouseButton1Click:Connect(function()
    speedIndex = speedIndex % #speeds + 1; flySpeed = speeds[speedIndex]; speedBtn.Text = "Fly Speed: x" .. tostring(flySpeed)
end)

createToggle("Anti-Void (Center)", "antiVoid")
createToggle("Hitbox (Safe)", "hitbox")
createToggle("Camera Fly", "cameraFly")

-- 上下ボタン
local function createNavBtn(text, pos, val)
    local b = Instance.new("TextButton", screenGui)
    b.Size = UDim2.new(0, 60, 0, 60); b.Position = pos; b.Text = text
    b.BackgroundColor3 = Color3.new(0,0,0); b.BackgroundTransparency = 0.5; b.TextColor3 = Color3.new(1,1,1)
    b.Visible = false; Instance.new("UICorner", b)
    b.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then verticalMove = val end end)
    b.InputEnded:Connect(function() verticalMove = 0 end)
    return b
end
local upBtn = createNavBtn("▲", UDim2.new(0.85, -30, 0.4, 0), 1)
local downBtn = createNavBtn("▼", UDim2.new(0.85, -30, 0.4, 70), -1)

-- === メインループ ===
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- 🔴 Anti-Void: config.antiVoid が ON の時だけ動作するように修正
    if config.antiVoid == true then
        if root.Position.Y < -35 then
            root.CFrame = CFrame.new(ARENA_CENTER)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end

    if config.hitbox then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                p.Character.HumanoidRootPart.Size = Vector3.new(6, 6, 6)
                p.Character.HumanoidRootPart.Transparency = 0.7
                p.Character.HumanoidRootPart.CanCollide = false
            end
        end
    end

    upBtn.Visible = config.cameraFly
    downBtn.Visible = config.cameraFly

    if config.cameraFly then
        Camera.CameraType = Enum.CameraType.Custom
        local moveVec = ControlModule:GetMoveVector()
        local look = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        local horizontalMove = (Vector3.new(look.X, 0, look.Z).Unit * -moveVec.Z) + (Vector3.new(right.X, 0, right.Z).Unit * moveVec.X)
        camOffset = camOffset + (horizontalMove * flySpeed) + Vector3.new(0, verticalMove * flySpeed, 0)
        Camera.CFrame = CFrame.new(root.Position + camOffset) * Camera.CFrame.Rotation
        Camera.CameraSubject = root
    end
end)
