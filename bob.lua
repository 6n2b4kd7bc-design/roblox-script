-- [[ 1. 初期設定とサービスの取得 ]]
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
getgenv().AutoBobEnabled = false
local startTime = os.time()

-- [[ 2. Anti-AFK機能 ]]
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- [[ 3. UIの作成 ]]
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoBobGui"
ScreenGui.ResetOnSpawn = false
-- ExecutorのCoreGuiに保護して配置（対応していない場合はPlayerGuiにフォールバック）
local success, err = pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not success then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- メインフレーム
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true -- ドラッグ移動を有効化
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

-- 収納（最小化）ボタン
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -35, 0, 5)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.SourceSansBold
MinimizeBtn.TextSize = 20
MinimizeBtn.Parent = MainFrame

local MinUICorner = Instance.new("UICorner")
MinUICorner.CornerRadius = UDim.new(0, 5)
MinUICorner.Parent = MinimizeBtn

-- 経過時間表示（タイマー）
local TimeLabel = Instance.new("TextLabel")
TimeLabel.Size = UDim2.new(1, -40, 0, 30)
TimeLabel.Position = UDim2.new(0, 20, 0, 35)
TimeLabel.BackgroundTransparency = 1
TimeLabel.Text = "Time: 00:00:00"
TimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TimeLabel.Font = Enum.Font.SourceSansBold
TimeLabel.TextSize = 18
TimeLabel.Parent = MainFrame

-- オンオフボタン
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 120, 0, 40)
ToggleBtn.Position = UDim2.new(0.5, -60, 0, 80)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleBtn.Text = "OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.TextSize = 20
ToggleBtn.Parent = MainFrame

local ToggleUICorner = Instance.new("UICorner")
ToggleUICorner.CornerRadius = UDim.new(0, 8)
ToggleUICorner.Parent = ToggleBtn

-- [[ 4. UI機能のロジック ]]
-- 収納機能
local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0, 200, 0, 40)
        TimeLabel.Visible = false
        ToggleBtn.Visible = false
        MinimizeBtn.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 200, 0, 150)
        TimeLabel.Visible = true
        ToggleBtn.Visible = true
        MinimizeBtn.Text = "-"
    end
end)

-- タイマー更新ロジック
RunService.RenderStepped:Connect(function()
    local elapsedTime = os.time() - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    TimeLabel.Text = string.format("Time: %02d:%02d:%02d", hours, minutes, seconds)
end)

-- [[ 5. Auto Bob コアロジック ]]
-- Teleport1を効率よく探すための変数
local teleportTarget = nil

local function startAutoBob()
    task.spawn(function()
        while getgenv().AutoBobEnabled do
            local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local Humanoid = Character:WaitForChild("Humanoid", 5)
            local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 5)
            
            if Humanoid and HumanoidRootPart and Humanoid.Health > 0 then
                -- 1. Teleport1 にテレポート (再帰検索を有効化してどこにあっても見つけるように修正)
                if not teleportTarget then
                    -- 第2引数を true にすることでフォルダの中まで全て検索します
                    teleportTarget = workspace:FindFirstChild("Teleport1", true)
                end

                if teleportTarget then
                    -- テレポート実行
                    HumanoidRootPart.CFrame = teleportTarget.CFrame
                else
                    warn("Teleport1 が見つかりません。")
                end
                
                -- テレポート後の少しの待機 (サーバー同期のため)
                task.wait(0.2)
                
                -- 2. Eボタンを連打 (Replicaのグローブ能力発動)
                if getgenv().AutoBobEnabled and Humanoid.Health > 0 then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end
                
                -- 3. 0.5秒待機
                task.wait(0.5)
                
                -- 4. 強制キャラクターリセット
                if getgenv().AutoBobEnabled and Humanoid and Humanoid.Health > 0 then
                    Humanoid.Health = 0
                end
            end
            
            -- 次のスポーンまで待機 (ループの負荷軽減)
            task.wait(1.5)
        end
    end)
end

-- トグルボタンのクリックイベント
ToggleBtn.MouseButton1Click:Connect(function()
    getgenv().AutoBobEnabled = not getgenv().AutoBobEnabled
    
    if getgenv().AutoBobEnabled then
        ToggleBtn.Text = "ON"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        startAutoBob()
    else
        ToggleBtn.Text = "OFF"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end)
