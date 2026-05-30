if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- [[ 20分放置キック防止 (Anti-AFK) ]]
LP.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local function GetGuiParent()
    local success, core = pcall(function() return game:GetService("CoreGui") end)
    return (success and core) or LP:WaitForChild("PlayerGui")
end

-- [[ UIの初期化 ]]
local GuiName = "MM2_RobustHub"
local oldGui = GetGuiParent():FindFirstChild(GuiName)
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui", GetGuiParent())
ScreenGui.Name = GuiName

-- [[ Hub メインフレーム ]]
local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 200, 0, 110)
Main.Position = UDim2.new(0.5, -100, 0.1, 0)
Main.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Main.BorderSizePixel = 0
Main.Draggable = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.Text = "MM2 Auto Hub"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14

-- [[ ファーム トグルボタン ]]
local FarmBtn = Instance.new("TextButton", Main)
FarmBtn.Size = UDim2.new(0.9, 0, 0, 30)
FarmBtn.Position = UDim2.new(0.05, 0, 0, 35)
FarmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
FarmBtn.Text = "Auto Farm: OFF"
FarmBtn.TextColor3 = Color3.new(1, 1, 1)
FarmBtn.Font = Enum.Font.GothamSemibold

-- [[ 自動復帰 トグルボタン ]]
local RecoveryBtn = Instance.new("TextButton", Main)
RecoveryBtn.Size = UDim2.new(0.9, 0, 0, 30)
RecoveryBtn.Position = UDim2.new(0.05, 0, 0, 70)
RecoveryBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
RecoveryBtn.Text = "Auto Recovery: OFF"
RecoveryBtn.TextColor3 = Color3.new(1, 1, 1)
RecoveryBtn.Font = Enum.Font.GothamSemibold

-- [[ 変数群 ]]
local AutoFarm = false
local AutoRecovery = false
local IgnoredCoins = {}
local CurrentTween = nil
local FLY_SPEED = 21 

-- [[ ロビー判定関数 ]]
local function IsInLobby(root)
    local votePad = nil
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and string.find(v.Name, "VotePad") then
            votePad = v
            break
        end
    end
    if votePad and (root.Position - votePad.Position).Magnitude <= 100 then
        return true
    end
    return false
end

-- [[ ボタンクリック処理 ]]
FarmBtn.MouseButton1Click:Connect(function()
    AutoFarm = not AutoFarm
    FarmBtn.Text = "Auto Farm: " .. (AutoFarm and "ON" or "OFF")
    FarmBtn.BackgroundColor3 = AutoFarm and Color3.fromRGB(46, 139, 87) or Color3.fromRGB(200, 50, 50)
    
    if not AutoFarm and CurrentTween then
        CurrentTween:Cancel()
        CurrentTween = nil
    end
end)

RecoveryBtn.MouseButton1Click:Connect(function()
    AutoRecovery = not AutoRecovery
    RecoveryBtn.Text = "Auto Recovery: " .. (AutoRecovery and "ON" or "OFF")
    RecoveryBtn.BackgroundColor3 = AutoRecovery and Color3.fromRGB(46, 139, 87) or Color3.fromRGB(200, 50, 50)
end)

-- [[ 1分間停止・スタック検知＆自動復帰ループ ]]
task.spawn(function()
    local lastPos = Vector3.new()
    local stuckSeconds = 0

    while true do
        task.wait(1)
        if AutoRecovery and AutoFarm then
            local char = LP.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local root = char.HumanoidRootPart
                
                -- マップ内にいる時のみカウント
                if not IsInLobby(root) and root:IsDescendantOf(workspace) then
                    local currentPos = root.Position
                    
                    -- 1秒間で3スタッド未満しか動いていない場合は「止まっている」と判定
                    if (currentPos - lastPos).Magnitude < 3 then
                        stuckSeconds = stuckSeconds + 1
                        
                        -- 60秒間止まっていたら強制リセット発動
                        if stuckSeconds >= 60 then
                            if CurrentTween then CurrentTween:Cancel() end
                            IgnoredCoins = {} 
                            
                            -- 地形への引っかかりを直すため、キャラを上にワープ
                            root.CFrame = root.CFrame + Vector3.new(0, 15, 0)
                            
                            -- ファームを強制再開
                            AutoFarm = true 
                            FarmBtn.Text = "Auto Farm: ON"
                            FarmBtn.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
                            
                            stuckSeconds = 0
                        end
                    else
                        stuckSeconds = 0
                        lastPos = currentPos
                    end
                else
                    stuckSeconds = 0 
                end
            else
                stuckSeconds = 0
            end
        end
    end
end)

-- [[ メインファームループ ]]
task.spawn(function()
    while true do
        task.wait(0.05) 
        
        if AutoFarm and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character:FindFirstChild("Humanoid") then
            local root = LP.Character.HumanoidRootPart
            if not root:IsDescendantOf(workspace) then continue end
            
            if IsInLobby(root) then
                IgnoredCoins = {}
                root.Velocity = Vector3.new(0,0,0)
                continue 
            end
            
            root.Parent.Humanoid:ChangeState(11) 
            for _, p in pairs(root.Parent:GetDescendants()) do 
                if p:IsA("BasePart") then p.CanCollide = false end 
            end
            root.Velocity = Vector3.new(0, 0, 0) 

            local target = nil
            local dist = math.huge
            local validCoinsExist = false
            local unignoredCount = 0
            
            for _, v in pairs(workspace:GetDescendants()) do
                if v.Name == "Coin_Server" and v:IsA("BasePart") then
                    validCoinsExist = true
                    if not IgnoredCoins[v] then
                        unignoredCount = unignoredCount + 1
                        local d = (root.Position - v.Position).Magnitude
                        if d < dist then dist = d; target = v end
                    end
                end
            end

            -- 触っていないコインが無くなったら3秒待機
            if not target and validCoinsExist and unignoredCount == 0 then
                task.wait(3) 
                IgnoredCoins = {}
                continue
            end

            if target and AutoFarm and not IsInLobby(root) then
                local travelTime = dist / FLY_SPEED
                CurrentTween = TweenService:Create(root, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {CFrame = target.CFrame})
                CurrentTween:Play()
                
                local startTick = tick()
                local maxWait = travelTime + 0.5 
                
                while CurrentTween and CurrentTween.PlaybackState == Enum.PlaybackState.Playing and (tick() - startTick) < maxWait do
                    if not AutoFarm or IsInLobby(root) or not root:IsDescendantOf(workspace) then 
                        if CurrentTween then CurrentTween:Cancel() end
                        break 
                    end
                    task.wait(0.03)
                end
                
                if AutoFarm and target and target.Parent and not IsInLobby(root) and root:IsDescendantOf(workspace) then
                    root.CFrame = target.CFrame
                    
                    if type(firetouchinterest) == "function" then
                        firetouchinterest(root, target, 0)
                        task.wait(0.05)
                        firetouchinterest(root, target, 1)
                    end
                    
                    IgnoredCoins[target] = true
                    task.wait(0.05) 
                end
            end
        end
    end
end)
