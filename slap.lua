local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ==========================================
-- 1. モバイル用の安全なUI配置先（Bypass）
-- ==========================================
local uiParent
local success = pcall(function()
    if gethui then
        uiParent = gethui()
    else
        uiParent = game:GetService("CoreGui")
    end
end)

-- CoreGuiが使えないエグゼキューターの場合は通常の画面に配置する
if not uiParent or not success then
    uiParent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- 古いUIの削除
if uiParent:FindFirstChild("MobileSafePickerUI") then
    uiParent:FindFirstChild("MobileSafePickerUI"):Destroy()
end

-- ==========================================
-- 2. リモート設定
-- ==========================================
local remoteNames = {
    "Rockmode",
    "ZZZZZZZSleep",
    "Duplicate",
    "Glovel Combo (同時連打)"
}

local selectedName = remoteNames[1]
local active = false
local delayTime = 0.01

-- ==========================================
-- 3. UI構築
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MobileSafePickerUI"
screenGui.ResetOnSpawn = false -- 死んでも消えないようにする
screenGui.Parent = uiParent

local main = Instance.new("Frame", screenGui)
main.Size = UDim2.new(0, 240, 0, 320)
main.Position = UDim2.new(0.5, -120, 0.2, 0) -- モバイルで見やすい位置
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.Active = true
main.Draggable = true

local corner = Instance.new("UICorner", main)
corner.CornerRadius = UDim.new(0, 8)

-- ステータスラベル
local statusLabel = Instance.new("TextLabel", main)
statusLabel.Size = UDim2.new(0.9, 0, 0, 25)
statusLabel.Position = UDim2.new(0.05, 0, 0.02, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: UI Loaded Safely"
statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
statusLabel.TextScaled = true

-- ボタン生成ループ
local yPos = 0.12
for _, name in ipairs(remoteNames) do
    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, yPos, 0)
    btn.Text = "Select: " .. name
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 4)
    
    btn.MouseButton1Click:Connect(function()
        selectedName = name
        statusLabel.Text = "Selected: " .. name
        statusLabel.TextColor3 = Color3.new(1, 1, 1)
    end)
    yPos = yPos + 0.11
end

-- スピード設定TextBox
local speedBox = Instance.new("TextBox", main)
speedBox.Size = UDim2.new(0.9, 0, 0, 30)
speedBox.Position = UDim2.new(0.05, 0, yPos + 0.02, 0)
speedBox.PlaceholderText = "Delay (0.01 Recommended)"
speedBox.Text = "0.01"
speedBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
speedBox.TextColor3 = Color3.new(1, 1, 1)
speedBox.ClearTextOnFocus = false

-- 実行ボタン
local toggleBtn = Instance.new("TextButton", main)
toggleBtn.Size = UDim2.new(0.9, 0, 0, 40)
toggleBtn.Position = UDim2.new(0.05, 0, yPos + 0.15, 0)
toggleBtn.Text = "START"
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold

local toggleCorner = Instance.new("UICorner", toggleBtn)
toggleCorner.CornerRadius = UDim.new(0, 4)

-- ==========================================
-- 4. 実行ロジック（モバイルクラッシュ対策済）
-- ==========================================
toggleBtn.MouseButton1Click:Connect(function()
    active = not active
    toggleBtn.Text = active and "STOP" or "START"
    toggleBtn.BackgroundColor3 = active and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(40, 180, 40)
    
    if active then
        task.spawn(function()
            while active do
                delayTime = tonumber(speedBox.Text) or 0.01
                -- モバイルでの過負荷（フリーズ）を防ぐための強制待機
                if delayTime < 0.01 then delayTime = 0.01 end 
                
                if selectedName == "Glovel Combo (同時連打)" then
                    statusLabel.Text = "Firing: Glovel Combo"
                    local func = ReplicatedStorage:FindFirstChild("GlovelFunc", true)
                    local cancel = ReplicatedStorage:FindFirstChild("GlovelCancel", true)
                    
                    if func and func:IsA("RemoteFunction") then
                        task.spawn(function() pcall(function() func:InvokeServer() end) end)
                    end
                    if cancel and cancel:IsA("RemoteEvent") then
                        task.spawn(function() pcall(function() cancel:FireServer() end) end)
                    end
                    
                else
                    local targetRemote = ReplicatedStorage:FindFirstChild(selectedName, true)
                    if targetRemote then
                        statusLabel.Text = "Firing: " .. selectedName
                        task.spawn(function()
                            pcall(function()
                                if targetRemote:IsA("RemoteEvent") then
                                    targetRemote:FireServer()
                                elseif targetRemote:IsA("RemoteFunction") then
                                    targetRemote:InvokeServer()
                                end
                            end)
                        end)
                    else
                        statusLabel.Text = "Error: Remote Not Found!"
                        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    end
                end
                
                task.wait(delayTime)
            end
        end)
    else
        statusLabel.Text = "Status: Stopped"
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end)
