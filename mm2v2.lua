If not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
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

-- [[ UI初期化 ]]
local GuiName = "MM2_RobustHub_V3"
local oldGui = GetGuiParent():FindFirstChild(GuiName)
if oldGui then pcall(function() oldGui:Destroy() end) end

local ScreenGui = Instance.new("ScreenGui", GetGuiParent())
ScreenGui.Name = GuiName

-- [[ Hub メインフレーム ]]
local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 200, 0, 150)
Main.Position = UDim2.new(0.5, -100, 0.1, 0)
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Main.BorderSizePixel = 0
Main.Draggable = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Title.Text = "MM2 Coin Hub V3"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14

local function CreateButton(text, pos, color)
    local btn = Instance.new("TextButton", Main)
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamSemibold
    btn.BorderSizePixel = 0
    return btn
end

local FarmBtn = CreateButton("Auto Farm: OFF", UDim2.new(0.05, 0, 0, 35), Color3.fromRGB(200, 50, 50))
local RecoveryBtn = CreateButton("Auto Recovery: OFF", UDim2.new(0.05, 0, 0, 70), Color3.fromRGB(200, 50, 50))

-- [[ ステータス・カウントダウン表示 ]]
local StatusLabel = Instance.new("TextLabel", Main)
StatusLabel.Size = UDim2.new(0.9, 0, 0, 35)
StatusLabel.Position = UDim2.new(0.05, 0, 0, 105)
StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
StatusLabel.Text = "Status: Waiting..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 12

-- [[ 変数群 ]]
local AutoFarm = false
local AutoRecovery = false
local IgnoredCoins = {}
local CurrentTween = nil
local FLY_SPEED = 21 
local STUCK_LIMIT = 30 -- 30秒で再ロード

-- [[ 安全なロビー判定（エラー落ち防止） ]]
local function IsInLobby(root)
    if not root or not root:IsDescendantOf(workspace) then return false end
    local success, result = pcall(function()
        local votePad = nil
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and string.find(v.Name, "VotePad") then
                votePad = v; break
            end
        end
        if votePad and (root.Position - votePad.Position).Magnitude <= 100 then return true end
        return false
    end)
    return success and result or false
end

-- [[ ボタンイベント ]]
FarmBtn.MouseButton1Click:Connect(function()
    AutoFarm = not AutoFarm
    FarmBtn.Text = "Auto Farm: " .. (AutoFarm and "ON" or "OFF")
    FarmBtn.BackgroundColor3 = AutoFarm and Color3.fromRGB(46, 139, 87) or Color3.fromRGB(200, 50, 50)
    if not AutoFarm and CurrentTween then pcall(function() CurrentTween:Cancel() end) end
end)

RecoveryBtn.MouseButton1Click:Connect(function()
    AutoRecovery = not AutoRecovery
    RecoveryBtn.Text = "Auto Recovery: " .. (AutoRecovery and "ON" or "OFF")
    RecoveryBtn.BackgroundColor3 = AutoRecovery and Color3.fromRGB(46, 139, 87) or Color3.fromRGB(200, 50, 50)
end)

-- [[ 1: 自動復帰＆カウントダウン監視ループ (エラー保護済) ]]
task.spawn(function()
    local lastPos = Vector3.new()
    local stuckSeconds = 0

    while true do
        task.wait(1)
        -- pcallで包むことで、キャラ死亡時などのエラーでこの監視ループが絶対に消滅しないようにする
        pcall(function()
            if AutoRecovery and AutoFarm then
                local char = LP.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                
                if root and not IsInLobby(root) and root:IsDescendantOf(workspace) then
                    if (root.Position - lastPos).Magnitude < 2 then
                        stuckSeconds = stuckSeconds + 1
                        local remaining = STUCK_LIMIT - stuckSeconds
                        StatusLabel.Text = "STUCK! Reboot in: " .. remaining .. "s"
                        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                        
                        -- 30秒経過で【完全システム再ロード】を実行
                        if stuckSeconds >= STUCK_LIMIT then
                            StatusLabel.Text = "SYSTEM REBOOTING..."
                            StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                            
                            -- ① ファームを強制停止してTweenを完全消滅させる
                            AutoFarm = false
                            if CurrentTween then 
                                pcall(function() CurrentTween:Cancel() end) 
                                CurrentTween = nil
                            end
                            IgnoredCoins = {}
                            
                            -- ② 物理的なスタック解除（生きていれば上空へ、死んでいればそのままでリスポーン待ち）
                            pcall(function() root.CFrame = root.CFrame + Vector3.new(0, 30, 0) end)
                            
                            task.wait(1.5) -- 初期化のための安全な猶予時間
                            
                            -- ③ システム再起動
                            stuckSeconds = 0
                            AutoFarm = true
                            FarmBtn.Text = "Auto Farm: ON"
                            FarmBtn.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
                        end
                    else
                        stuckSeconds = 0
                        lastPos = root.Position
                        StatusLabel.Text = "Status: Farming..."
                        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                    end
                else
                    stuckSeconds = 0
                    StatusLabel.Text = IsInLobby(root) and "Status: In Lobby" or "Status: Idle"
                    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                    if root then lastPos = root.Position end
                end
            else
                stuckSeconds = 0
                StatusLabel.Text = "Recovery: Disabled"
                StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            end
        end)
    end
end)

-- [[ 2: メインファームループ (エラー保護済) ]]
task.spawn(function()
    while true do
        task.wait(0.05)
        if AutoFarm then
            -- ファーム処理全体を保護。途中でエラーが起きても次のループへ強制移行させ、スクリプトを止めさせない
            local success, err = pcall(function()
                if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character:FindFirstChild("Humanoid") then
                    local root = LP.Character.HumanoidRootPart
                    if not root:IsDescendantOf(workspace) then return end
                    if IsInLobby(root) then 
                        IgnoredCoins = {}; task.wait(0.5); return 
                    end
                    
                    LP.Character.Humanoid:ChangeState(11)
                    for _, p in pairs(LP.Character:GetDescendants()) do 
                        if p:IsA("BasePart") then p.CanCollide = false end 
                    end
                    root.Velocity = Vector3.new(0,0,0)

                    local target, dist = nil, math.huge
                    local coins = {}
                    for _, v in pairs(workspace:GetDescendants()) do
                        if v.Name == "Coin_Server" and v:IsA("BasePart") then
                            table.insert(coins, v)
                            if not IgnoredCoins[v] then
                                local d = (root.Position - v.Position).Magnitude
                                if d < dist then dist = d; target = v end
                            end
                        end
                    end

                    if not target and #coins > 0 then
                        task.wait(2); IgnoredCoins = {}; return
                    end

                    if target and AutoFarm and not IsInLobby(root) then
                        local travelTime = dist / FLY_SPEED
                        CurrentTween = TweenService:Create(root, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {CFrame = target.CFrame})
                        CurrentTween:Play()
                        
                        local startTick = tick()
                        while CurrentTween and CurrentTween.PlaybackState == Enum.PlaybackState.Playing and (tick() - startTick) < travelTime + 0.5 do
                            if not AutoFarm or IsInLobby(root) or not root:IsDescendantOf(workspace) then 
                                if CurrentTween then pcall(function() CurrentTween:Cancel() end) end 
                                break 
                            end
                            task.wait(0.05)
                        end
                        
                        if AutoFarm and target and target.Parent and not IsInLobby(root) and root:IsDescendantOf(workspace) then
                            root.CFrame = target.CFrame
                            if firetouchinterest then
                                firetouchinterest(root, target, 0)
                                task.wait(0.05)
                                firetouchinterest(root, target, 1)
                            end
                            IgnoredCoins[target] = true
                        end
                    end
                end
            end)
            if not success then
                -- 万が一内部エラーが起きてもログに吐き出すだけで、ループは継続する
                warn("Farm Loop Interrupted: " .. tostring(err))
            end
        end
    end
end)
