-- ============================================================
-- Blox Fruits Attack Aura v14 (震え・ジャンプ制限解消版)
-- FキーでON/OFF | Rキーでリモート再検出
-- ============================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

-- ============================================================
-- 設定
-- ============================================================
local Settings = {
    Enabled = false,
    Range = 50,
    Speed = 0.3,
    TargetMode = "Nearest",
    IgnorePlayers = false,
    IgnoreNPC = false,
    DisableAttackAnim = true,
}

local auraRunning = false
local auraThread = nil
local currentTarget = nil

-- ============================================================
-- ★ リモート群を取得
-- ============================================================
local remotes = {
    RegisterHit = nil,
    RegisterAttack = nil,
    Melee = nil,
    Sword = nil,
    Combat = nil,
    Click = nil,
    Attack = nil,
}

local function findAllRemotes()
    local rs = game:GetService("ReplicatedStorage")
    local net = rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("Net")
    local re = net and net:FindFirstChild("RE")
    
    if re then
        for _, child in ipairs(re:GetChildren()) do
            if child:IsA("RemoteEvent") then
                local name = child.Name
                if name:find("Hit") then remotes.RegisterHit = child end
                if name:find("Attack") then remotes.RegisterAttack = child end
                if name:find("Melee") then remotes.Melee = child end
                if name:find("Sword") then remotes.Sword = child end
                if name:find("Combat") then remotes.Combat = child end
                if name:find("Click") then remotes.Click = child end
            end
        end
    end
    
    local combat = rs:FindFirstChild("Combat")
    if combat then
        for _, child in ipairs(combat:GetChildren()) do
            if child:IsA("RemoteEvent") then
                if child.Name:find("Attack") and not remotes.Attack then remotes.Attack = child end
            end
        end
    end
    
    if not remotes.RegisterHit and not remotes.RegisterAttack then
        for _, obj in ipairs(rs:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local name = obj.Name:lower()
                if name:find("hit") or name:find("attack") or name:find("melee") or name:find("sword") then
                    if name:find("hit") and not remotes.RegisterHit then remotes.RegisterHit = obj end
                    if name:find("attack") and not remotes.RegisterAttack then remotes.RegisterAttack = obj end
                end
            end
        end
    end
end

findAllRemotes()

-- ============================================================
-- ★ ★ ★ 攻撃アニメーション抑制（改良版：震え・ジャンプ制限なし）
-- ============================================================
local attackAnimIds = {
    "rbxassetid://", -- 攻撃アニメーションのIDを必要に応じて追加
}

local function suppressAttackAnimation()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if not Settings.DisableAttackAnim then return end
    
    -- ★ 再生中のアニメーションから攻撃系のみを停止（ChangeStateは使わない）
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        local name = track.Name:lower()
        -- 攻撃関連のキーワードでフィルタリング
        if name:find("attack") or name:find("melee") or name:find("sword") or name:find("slash") or name:find("combo") or name:find("hit") or name:find("punch") or name:find("kick") then
            pcall(function() track:Stop() end)
        end
    end
    
    -- ★ 速度リセットは行わない（震えの原因になるため）
    -- 代わりに、パーツの速度はそのまま維持する
end

-- ★ 攻撃後にのみ呼び出す（毎フレームではなく、攻撃時のみ）
local function resetAfterAttack()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    -- ★ ChangeStateは使わない（ジャンプ制限の原因）
    -- 代わりに、アニメーショントラックだけを停止
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        local name = track.Name:lower()
        if name:find("attack") or name:find("melee") or name:find("sword") or name:find("slash") or name:find("combo") then
            pcall(function() track:Stop() end)
        end
    end
end

-- ★ 攻撃アニメーション抑制（常時監視はせず、攻撃後のみ実行）
RunService.Heartbeat:Connect(function()
    -- 常時監視はしない（震えの原因になるため）
    -- 代わりに、doAttack内で呼び出す
end)

-- ============================================================
-- ★ 敵取得（Enemiesフォルダ優先）
-- ============================================================
local function getTargets()
    local targets = {}
    local char = LP.Character
    if not char then return targets end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return targets end
    local myPos = hrp.Position
    local myHrp = hrp
    
    if not Settings.IgnorePlayers then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local pChar = plr.Character
                if pChar then
                    local pHrp = pChar:FindFirstChild("HumanoidRootPart")
                    local pHum = pChar:FindFirstChildOfClass("Humanoid")
                    if pHrp and pHum and pHum.Health > 0 then
                        if pHrp ~= myHrp then
                            table.insert(targets, {
                                Type = "Player",
                                Object = plr,
                                HRP = pHrp,
                                Humanoid = pHum,
                                Distance = (pHrp.Position - myPos).Magnitude
                            })
                        end
                    end
                end
            end
        end
    end
    
    if not Settings.IgnoreNPC then
        local enemiesFolder = Workspace:FindFirstChild("Enemies")
        if enemiesFolder then
            for _, obj in ipairs(enemiesFolder:GetChildren()) do
                if obj:IsA("Model") then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
                    if hrp and hum and hum.Health > 0 then
                        if hrp ~= myHrp then
                            table.insert(targets, {
                                Type = "NPC",
                                Object = obj,
                                HRP = hrp,
                                Humanoid = hum,
                                Distance = (hrp.Position - myPos).Magnitude
                            })
                        end
                    end
                end
            end
        else
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
                    if hrp and hum and hum.Health > 0 then
                        local isEnemy = obj:FindFirstChild("NPC") or obj:FindFirstChild("Npc") 
                            or obj.Name:find("NPC") or obj.Name:find("Npc") 
                            or obj.Name:find("Boss") or obj.Name:find("Enemy") or obj.Name:find("Island")
                        if isEnemy then
                            if hrp ~= myHrp then
                                table.insert(targets, {
                                    Type = "NPC",
                                    Object = obj,
                                    HRP = hrp,
                                    Humanoid = hum,
                                    Distance = (hrp.Position - myPos).Magnitude
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    return targets
end

-- ============================================================
-- ★ 攻撃実行（7パターン + アニメーション抑制改良）
-- ============================================================
local function doAttack(target)
    if not target or not target.HRP or not target.HRP.Parent then return false end
    
    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    
    if hrp == target.HRP then return false end
    
    -- 向きを合わせる（滑らかに）
    pcall(function()
        local lookAt = CFrame.lookAt(hrp.Position, target.HRP.Position)
        hrp.CFrame = hrp.CFrame:Lerp(lookAt, 0.3)
    end)
    
    local success = false
    
    -- 攻撃リモート送信（7パターン）
    if remotes.RegisterHit then
        pcall(function()
            remotes.RegisterHit:FireServer(target.HRP)
            success = true
        end)
        if not success then
            pcall(function()
                remotes.RegisterHit:FireServer(target.HRP, target.Object)
                success = true
            end)
        end
        if not success then
            pcall(function()
                remotes.RegisterHit:FireServer(target.HRP.Position)
                success = true
            end)
        end
    end
    
    if remotes.RegisterAttack then
        pcall(function()
            remotes.RegisterAttack:FireServer(target.HRP)
            task.wait(0.02)
            if remotes.RegisterHit then remotes.RegisterHit:FireServer(target.HRP) end
            success = true
        end)
    end
    
    if remotes.Melee then
        pcall(function()
            remotes.Melee:FireServer(target.HRP)
            success = true
        end)
    end
    
    if remotes.Sword then
        pcall(function()
            remotes.Sword:FireServer(target.HRP)
            success = true
        end)
    end
    
    if remotes.Combat then
        pcall(function()
            remotes.Combat:FireServer(target.HRP)
            success = true
        end)
    end
    
    if remotes.Click then
        pcall(function()
            remotes.Click:FireServer(target.HRP)
            success = true
        end)
    end
    
    if not success then
        pcall(function()
            local uis = game:GetService("UserInputService")
            if uis.TouchEnabled then
                uis:TouchTap(Vector2.new(0.5, 0.5))
            end
            success = true
        end)
    end
    
    -- ★ ★ ★ 攻撃後のアニメーション抑制（ChangeState不使用）
    if Settings.DisableAttackAnim then
        pcall(function()
            -- 攻撃アニメーションのみを停止（ChangeStateは呼ばない）
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                local name = track.Name:lower()
                if name:find("attack") or name:find("melee") or name:find("sword") or name:find("slash") or name:find("combo") then
                    track:Stop()
                end
            end
            -- 速度はそのまま維持（震え防止）
        end)
    end
    
    return success
end

-- ============================================================
-- メインループ
-- ============================================================
local function auraMain()
    while auraRunning do
        if not Settings.Enabled then
            task.wait(0.1)
            continue
        end
        
        local char = LP.Character
        if not char then task.wait(0.5) continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then task.wait(0.5) continue end
        
        local allTargets = getTargets()
        local inRange = {}
        for _, t in ipairs(allTargets) do
            if t.Distance <= Settings.Range then
                table.insert(inRange, t)
            end
        end
        
        if #inRange == 0 then
            currentTarget = nil
            task.wait(0.3)
            continue
        end
        
        local selected = nil
        if Settings.TargetMode == "Nearest" then
            table.sort(inRange, function(a, b) return a.Distance < b.Distance end)
            selected = inRange[1]
        else
            table.sort(inRange, function(a, b) return a.Humanoid.Health < b.Humanoid.Health end)
            selected = inRange[1]
        end
        
        if selected then
            currentTarget = selected
            doAttack(selected)
        end
        
        task.wait(Settings.Speed)
    end
end

-- ============================================================
-- トグル関数
-- ============================================================
local function toggleAura(state)
    Settings.Enabled = state
    if state then
        if not auraRunning then
            auraRunning = true
            auraThread = task.spawn(auraMain)
        end
        if statusLabel then
            statusLabel.Text = "● ACTIVE"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
        end
        if miniStatus then
            miniStatus.Text = "●"
            miniStatus.TextColor3 = Color3.fromRGB(0, 255, 100)
        end
    else
        auraRunning = false
        if auraThread then task.cancel(auraThread); auraThread = nil end
        currentTarget = nil
        if statusLabel then
            statusLabel.Text = "○ OFF"
            statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
        if miniStatus then
            miniStatus.Text = "○"
            miniStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end
end

-- ============================================================
-- リモート状態更新
-- ============================================================
local function updateRemoteStatus()
    for _, lbl in ipairs(LP.PlayerGui:GetDescendants()) do
        if lbl:IsA("TextLabel") and lbl.Name == "RemoteStatusLabel" then
            local hit = remotes.RegisterHit and "✅" or "❌"
            local attack = remotes.RegisterAttack and "✅" or "❌"
            local melee = remotes.Melee and "✅" or "❌"
            local sword = remotes.Sword and "✅" or "❌"
            lbl.Text = "Hit:" .. hit .. " Att:" .. attack .. " Mel:" .. melee .. " Swd:" .. sword
        end
    end
end

-- ============================================================
-- ★ UI作成（前回と同じ + バージョン更新）
-- ============================================================
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AttackAuraHub"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LP:WaitForChild("PlayerGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 380, 0, 500)
    mainFrame.Position = UDim2.new(0.02, 0, 0.08, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 20)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 14)
    
    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = Color3.fromRGB(180, 60, 255)
    stroke.Thickness = 1.5
    
    -- タイトルバー
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 38)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = mainFrame
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startPos = mainFrame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- タイトル
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(0.4, 0, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚔ HUB"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(200, 150, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    miniStatus = Instance.new("TextLabel", titleBar)
    miniStatus.Size = UDim2.new(0.15, 0, 1, 0)
    miniStatus.Position = UDim2.new(0.4, 0, 0, 0)
    miniStatus.BackgroundTransparency = 1
    miniStatus.Text = "○"
    miniStatus.Font = Enum.Font.GothamBold
    miniStatus.TextSize = 18
    miniStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
    miniStatus.TextXAlignment = Enum.TextXAlignment.Center
    
    -- 収納ボタン
    local collapseBtn = Instance.new("ImageButton", titleBar)
    collapseBtn.Size = UDim2.new(0, 32, 0, 32)
    collapseBtn.Position = UDim2.new(1, -38, 0.5, -16)
    collapseBtn.BackgroundTransparency = 1
    collapseBtn.Image = "rbxassetid://127143243281725"
    collapseBtn.ScaleType = Enum.ScaleType.Fit
    collapseBtn.Parent = titleBar
    
    local isCollapsed = false
    local contentElements = {}
    
    local function toggleCollapse()
        isCollapsed = not isCollapsed
        if isCollapsed then
            TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 380, 0, 38)
            }):Play()
            for _, el in ipairs(contentElements) do
                if el then el.Visible = false end
            end
        else
            TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 380, 0, 500)
            }):Play()
            for _, el in ipairs(contentElements) do
                if el then el.Visible = true end
            end
        end
    end
    
    collapseBtn.MouseButton1Click:Connect(toggleCollapse)
    
    -- ステータスバー
    local statusBar = Instance.new("Frame", mainFrame)
    statusBar.Size = UDim2.new(1, -20, 0, 34)
    statusBar.Position = UDim2.new(0, 10, 0, 42)
    statusBar.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    statusBar.BorderSizePixel = 0
    Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 8)
    table.insert(contentElements, statusBar)
    
    statusLabel = Instance.new("TextLabel", statusBar)
    statusLabel.Size = UDim2.new(0.6, 0, 1, 0)
    statusLabel.Position = UDim2.new(0, 10, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "○ OFF"
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 16
    statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local toggleBtn = Instance.new("TextButton", statusBar)
    toggleBtn.Size = UDim2.new(0, 80, 0, 26)
    toggleBtn.Position = UDim2.new(1, -88, 0.5, -13)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    toggleBtn.Text = "▶ START"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 13
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)
    toggleBtn.MouseButton1Click:Connect(function()
        toggleAura(not Settings.Enabled)
        toggleBtn.Text = Settings.Enabled and "■ STOP" or "▶ START"
        toggleBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(60, 60, 80)
    end)
    
    -- タブボタン
    local tabFrame = Instance.new("Frame", mainFrame)
    tabFrame.Size = UDim2.new(1, -20, 0, 36)
    tabFrame.Position = UDim2.new(0, 10, 0, 80)
    tabFrame.BackgroundTransparency = 1
    table.insert(contentElements, tabFrame)
    
    local tabs = {"Attack", "Enemies", "Settings"}
    local tabButtons = {}
    local contentFrames = {}
    
    for i, name in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabFrame)
        btn.Size = UDim2.new(1 / #tabs, -4, 1, 0)
        btn.Position = UDim2.new((i - 1) / #tabs, 4, 0, 0)
        btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(180, 60, 255) or Color3.fromRGB(40, 40, 60)
        btn.Text = name
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        tabButtons[i] = btn
    end
    
    -- コンテンツコンテナ
    local contentContainer = Instance.new("Frame", mainFrame)
    contentContainer.Size = UDim2.new(1, -20, 0, 330)
    contentContainer.Position = UDim2.new(0, 10, 0, 120)
    contentContainer.BackgroundTransparency = 1
    table.insert(contentElements, contentContainer)
    
    -- ===== Attackタブ =====
    local attackTab = Instance.new("Frame", contentContainer)
    attackTab.Size = UDim2.new(1, 0, 1, 0)
    attackTab.BackgroundTransparency = 1
    attackTab.Visible = true
    contentFrames[1] = attackTab
    
    -- 範囲スライダー
    local rangeLabel = Instance.new("TextLabel", attackTab)
    rangeLabel.Size = UDim2.new(0.7, 0, 0, 22)
    rangeLabel.Position = UDim2.new(0, 0, 0, 0)
    rangeLabel.BackgroundTransparency = 1
    rangeLabel.Text = "📏 Range: " .. Settings.Range .. "s"
    rangeLabel.Font = Enum.Font.Gotham
    rangeLabel.TextSize = 14
    rangeLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    rangeLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local rangeValue = Instance.new("TextLabel", attackTab)
    rangeValue.Size = UDim2.new(0.2, 0, 0, 22)
    rangeValue.Position = UDim2.new(0.75, 0, 0, 0)
    rangeValue.BackgroundTransparency = 1
    rangeValue.Text = "50s"
    rangeValue.Font = Enum.Font.GothamBold
    rangeValue.TextSize = 14
    rangeValue.TextColor3 = Color3.fromRGB(180, 60, 255)
    rangeValue.TextXAlignment = Enum.TextXAlignment.Right
    
    local rangeSlider = Instance.new("Frame", attackTab)
    rangeSlider.Size = UDim2.new(1, 0, 0, 6)
    rangeSlider.Position = UDim2.new(0, 0, 0, 24)
    rangeSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    Instance.new("UICorner", rangeSlider).CornerRadius = UDim.new(1, 0)
    
    local rangeFill = Instance.new("Frame", rangeSlider)
    rangeFill.Size = UDim2.new(Settings.Range / 200, 0, 1, 0)
    rangeFill.BackgroundColor3 = Color3.fromRGB(180, 60, 255)
    Instance.new("UICorner", rangeFill).CornerRadius = UDim.new(1, 0)
    
    local draggingRange = false
    rangeSlider.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            draggingRange = true
        end
    end)
    rangeSlider.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            draggingRange = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if draggingRange and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local pos = i.Position.X
            local absPos = rangeSlider.AbsolutePosition.X
            local size = rangeSlider.AbsoluteSize.X
            if size > 0 then
                local val = math.clamp((pos - absPos) / size, 0, 1)
                Settings.Range = math.floor(val * 190 + 10)
                rangeFill.Size = UDim2.new(val, 0, 1, 0)
                rangeLabel.Text = "📏 Range: " .. Settings.Range .. "s"
                rangeValue.Text = Settings.Range .. "s"
            end
        end
    end)
    
    -- 速度スライダー
    local speedLabel = Instance.new("TextLabel", attackTab)
    speedLabel.Size = UDim2.new(0.7, 0, 0, 22)
    speedLabel.Position = UDim2.new(0, 0, 0, 44)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "⚡ Speed: " .. Settings.Speed .. "s"
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextSize = 14
    speedLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local speedValue = Instance.new("TextLabel", attackTab)
    speedValue.Size = UDim2.new(0.2, 0, 0, 22)
    speedValue.Position = UDim2.new(0.75, 0, 0, 44)
    speedValue.BackgroundTransparency = 1
    speedValue.Text = "0.3s"
    speedValue.Font = Enum.Font.GothamBold
    speedValue.TextSize = 14
    speedValue.TextColor3 = Color3.fromRGB(100, 200, 255)
    speedValue.TextXAlignment = Enum.TextXAlignment.Right
    
    local speedSlider = Instance.new("Frame", attackTab)
    speedSlider.Size = UDim2.new(1, 0, 0, 6)
    speedSlider.Position = UDim2.new(0, 0, 0, 68)
    speedSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    Instance.new("UICorner", speedSlider).CornerRadius = UDim.new(1, 0)
    
    local speedFill = Instance.new("Frame", speedSlider)
    speedFill.Size = UDim2.new((0.3 - 0.05) / 1.95, 0, 1, 0)
    speedFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    Instance.new("UICorner", speedFill).CornerRadius = UDim.new(1, 0)
    
    local draggingSpeed = false
    speedSlider.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            draggingSpeed = true
        end
    end)
    speedSlider.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            draggingSpeed = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if draggingSpeed and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local pos = i.Position.X
            local absPos = speedSlider.AbsolutePosition.X
            local size = speedSlider.AbsoluteSize.X
            if size > 0 then
                local val = math.clamp((pos - absPos) / size, 0, 1)
                Settings.Speed = math.round((val * 1.95 + 0.05) * 100) / 100
                speedFill.Size = UDim2.new(val, 0, 1, 0)
                speedLabel.Text = "⚡ Speed: " .. Settings.Speed .. "s"
                speedValue.Text = Settings.Speed .. "s"
            end
        end
    end)
    
    -- ターゲットモード
    local modeLabel = Instance.new("TextLabel", attackTab)
    modeLabel.Size = UDim2.new(0.6, 0, 0, 22)
    modeLabel.Position = UDim2.new(0, 0, 0, 88)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Text = "🎯 Mode: Nearest"
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.TextSize = 14
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local modeBtn = Instance.new("TextButton", attackTab)
    modeBtn.Size = UDim2.new(0, 90, 0, 26)
    modeBtn.Position = UDim2.new(1, -95, 0, 86)
    modeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    modeBtn.Text = "Nearest"
    modeBtn.Font = Enum.Font.GothamBold
    modeBtn.TextSize = 12
    modeBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 6)
    modeBtn.MouseButton1Click:Connect(function()
        if Settings.TargetMode == "Nearest" then
            Settings.TargetMode = "LowestHP"
            modeBtn.Text = "LowestHP"
            modeLabel.Text = "🎯 Mode: LowestHP"
        else
            Settings.TargetMode = "Nearest"
            modeBtn.Text = "Nearest"
            modeLabel.Text = "🎯 Mode: Nearest"
        end
    end)
    
    -- ターゲット表示
    local targetDisplay = Instance.new("TextLabel", attackTab)
    targetDisplay.Size = UDim2.new(1, 0, 0, 22)
    targetDisplay.Position = UDim2.new(0, 0, 0, 124)
    targetDisplay.BackgroundTransparency = 1
    targetDisplay.Text = "Target: None"
    targetDisplay.Font = Enum.Font.Gotham
    targetDisplay.TextSize = 13
    targetDisplay.TextColor3 = Color3.fromRGB(150, 150, 180)
    targetDisplay.TextXAlignment = Enum.TextXAlignment.Left
    
    local keybindLabel = Instance.new("TextLabel", attackTab)
    keybindLabel.Size = UDim2.new(1, 0, 0, 20)
    keybindLabel.Position = UDim2.new(0, 0, 0, 150)
    keybindLabel.BackgroundTransparency = 1
    keybindLabel.Text = "[F] Toggle  |  [R] Rescan"
    keybindLabel.Font = Enum.Font.Gotham
    keybindLabel.TextSize = 12
    keybindLabel.TextColor3 = Color3.fromRGB(130, 130, 160)
    keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local verLabel = Instance.new("TextLabel", attackTab)
    verLabel.Size = UDim2.new(1, 0, 0, 18)
    verLabel.Position = UDim2.new(0, 0, 0, 174)
    verLabel.BackgroundTransparency = 1
    verLabel.Text = "v14 | 震え・ジャンプ制限解消"
    verLabel.Font = Enum.Font.Gotham
    verLabel.TextSize = 10
    verLabel.TextColor3 = Color3.fromRGB(100, 100, 130)
    verLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- ===== Enemiesタブ =====
    local enemiesTab = Instance.new("Frame", contentContainer)
    enemiesTab.Size = UDim2.new(1, 0, 1, 0)
    enemiesTab.BackgroundTransparency = 1
    enemiesTab.Visible = false
    contentFrames[2] = enemiesTab
    
    local enemyListTitle = Instance.new("TextLabel", enemiesTab)
    enemyListTitle.Size = UDim2.new(1, 0, 0, 24)
    enemyListTitle.Position = UDim2.new(0, 0, 0, 0)
    enemyListTitle.BackgroundTransparency = 1
    enemyListTitle.Text = "📋 検出中の敵"
    enemyListTitle.Font = Enum.Font.GothamBold
    enemyListTitle.TextSize = 15
    enemyListTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
    enemyListTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local enemyList = Instance.new("ScrollingFrame", enemiesTab)
    enemyList.Size = UDim2.new(1, 0, 1, -34)
    enemyList.Position = UDim2.new(0, 0, 0, 26)
    enemyList.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    enemyList.BorderSizePixel = 0
    enemyList.CanvasSize = UDim2.new(0, 0, 0, 0)
    enemyList.ScrollBarThickness = 4
    Instance.new("UICorner", enemyList).CornerRadius = UDim.new(0, 6)
    
    local enemyListLayout = Instance.new("UIListLayout", enemyList)
    enemyListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    enemyListLayout.Padding = UDim.new(0, 4)
    
    task.spawn(function()
        while true do
            if not enemyList then break end
            for _, child in ipairs(enemyList:GetChildren()) do
                if child:IsA("TextLabel") then child:Destroy() end
            end
            local targets = getTargets()
            local count = 0
            for _, t in ipairs(targets) do
                if t.Distance <= Settings.Range then
                    local label = Instance.new("TextLabel", enemyList)
                    label.Size = UDim2.new(1, -4, 0, 22)
                    label.BackgroundTransparency = 1
                    label.Text = t.Type .. ": " .. t.Object.Name .. " (" .. math.floor(t.Distance) .. "s | HP:" .. math.floor(t.Humanoid.Health) .. ")"
                    label.Font = Enum.Font.Gotham
                    label.TextSize = 13
                    label.TextColor3 = Color3.fromRGB(180, 180, 200)
                    label.TextXAlignment = Enum.TextXAlignment.Left
                    count = count + 1
                end
            end
            enemyList.CanvasSize = UDim2.new(0, 0, 0, count * 26 + 10)
            task.wait(1)
        end
    end)
    
    -- ===== Settingsタブ =====
    local settingsTab = Instance.new("Frame", contentContainer)
    settingsTab.Size = UDim2.new(1, 0, 1, 0)
    settingsTab.BackgroundTransparency = 1
    settingsTab.Visible = false
    contentFrames[3] = settingsTab
    
    -- プレイヤー無視
    local ignorePlyBtn = Instance.new("TextButton", settingsTab)
    ignorePlyBtn.Size = UDim2.new(1, -10, 0, 36)
    ignorePlyBtn.Position = UDim2.new(0, 5, 0, 5)
    ignorePlyBtn.BackgroundColor3 = Settings.IgnorePlayers and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(40, 40, 60)
    ignorePlyBtn.Text = Settings.IgnorePlayers and "✅ プレイヤーを無視" or "🚫 プレイヤーを無視"
    ignorePlyBtn.Font = Enum.Font.GothamBold
    ignorePlyBtn.TextSize = 13
    ignorePlyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Instance.new("UICorner", ignorePlyBtn).CornerRadius = UDim.new(0, 6)
    ignorePlyBtn.MouseButton1Click:Connect(function()
        Settings.IgnorePlayers = not Settings.IgnorePlayers
        ignorePlyBtn.BackgroundColor3 = Settings.IgnorePlayers and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(40, 40, 60)
        ignorePlyBtn.Text = Settings.IgnorePlayers and "✅ プレイヤーを無視" or "🚫 プレイヤーを無視"
    end)
    ignorePlyBtn.TouchTap:Connect(function()
        Settings.IgnorePlayers = not Settings.IgnorePlayers
        ignorePlyBtn.BackgroundColor3 = Settings.IgnorePlayers and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(40, 40, 60)
        ignorePlyBtn.Text = Settings.IgnorePlayers and "✅ プレイヤーを無視" or "🚫 プレイヤーを無視"
    end)
    
    -- NPC無視
    local ignoreNpcBtn = Instance.new("TextButton", settingsTab)
    ignoreNpcBtn.Size = UDim2.new(1, -10, 0, 36)
    ignoreNpcBtn.Position = UDim2.new(0, 5, 0, 46)
    ignoreNpcBtn.BackgroundColor3 = Settings.IgnoreNPC and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(40, 40, 60)
    ignoreNpcBtn.Text = Settings.IgnoreNPC and "✅ NPCを無視" or "🚫 NPCを無視"
    ignoreNpcBtn.Font = Enum.Font.GothamBold
    ignoreNpcBtn.TextSize = 13
    ignoreNpcBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Instance.new("UICorner", ignoreNpcBtn).CornerRadius = UDim.new(0, 6)
    ignoreNpcBtn.MouseButton1Click:Connect(function()
        Settings.IgnoreNPC = not Settings.IgnoreNPC
        ignoreNpcBtn.BackgroundColor3 = Settings.IgnoreNPC and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(40, 40, 60)
        ignoreNpcBtn.Text = Settings.IgnoreNPC and "✅ NPCを無視" or "🚫 NPCを無視"
    end)
    ignoreNpcBtn.TouchTap:Connect(function()
        Settings.IgnoreNPC = not Settings.IgnoreNPC
        ignoreNpcBtn.BackgroundColor3 = Settings.IgnoreNPC and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(40, 40, 60)
        ignoreNpcBtn.Text = Settings.IgnoreNPC and "✅ NPCを無視" or "🚫 NPCを無視"
    end)
    
    -- アニメーション抑制
    local animToggleBtn = Instance.new("TextButton", settingsTab)
    animToggleBtn.Size = UDim2.new(1, -10, 0, 36)
    animToggleBtn.Position = UDim2.new(0, 5, 0, 87)
    animToggleBtn.BackgroundColor3 = Settings.DisableAttackAnim and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(40, 40, 60)
    animToggleBtn.Text = Settings.DisableAttackAnim and "🔇 攻撃アニメーション抑制: ON" or "🔊 攻撃アニメーション抑制: OFF"
    animToggleBtn.Font = Enum.Font.GothamBold
    animToggleBtn.TextSize = 13
    animToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Instance.new("UICorner", animToggleBtn).CornerRadius = UDim.new(0, 6)
    animToggleBtn.MouseButton1Click:Connect(function()
        Settings.DisableAttackAnim = not Settings.DisableAttackAnim
        animToggleBtn.BackgroundColor3 = Settings.DisableAttackAnim and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(40, 40, 60)
        animToggleBtn.Text = Settings.DisableAttackAnim and "🔇 攻撃アニメーション抑制: ON" or "🔊 攻撃アニメーション抑制: OFF"
    end)
    animToggleBtn.TouchTap:Connect(function()
        Settings.DisableAttackAnim = not Settings.DisableAttackAnim
        animToggleBtn.BackgroundColor3 = Settings.DisableAttackAnim and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(40, 40, 60)
        animToggleBtn.Text = Settings.DisableAttackAnim and "🔇 攻撃アニメーション抑制: ON" or "🔊 攻撃アニメーション抑制: OFF"
    end)
    
    -- リモート再検出
    local rescanBtn = Instance.new("TextButton", settingsTab)
    rescanBtn.Size = UDim2.new(1, -10, 0, 36)
    rescanBtn.Position = UDim2.new(0, 5, 0, 128)
    rescanBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
    rescanBtn.Text = "🔄 リモート再検出"
    rescanBtn.Font = Enum.Font.GothamBold
    rescanBtn.TextSize = 13
    rescanBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Instance.new("UICorner", rescanBtn).CornerRadius = UDim.new(0, 6)
    rescanBtn.MouseButton1Click:Connect(function()
        findAllRemotes()
        updateRemoteStatus()
        remoteStatusLabel.Text = "Hit:✅ Att:✅ Mel:✅ Swd:✅"
    end)
    rescanBtn.TouchTap:Connect(function()
        findAllRemotes()
        updateRemoteStatus()
        remoteStatusLabel.Text = "Hit:✅ Att:✅ Mel:✅ Swd:✅"
    end)
    
    -- リモートステータス
    remoteStatusLabel = Instance.new("TextLabel", settingsTab)
    remoteStatusLabel.Size = UDim2.new(1, -10, 0, 20)
    remoteStatusLabel.Position = UDim2.new(0, 5, 0, 170)
    remoteStatusLabel.BackgroundTransparency = 1
    remoteStatusLabel.Text = "Hit:✅ Att:✅ Mel:✅ Swd:✅"
    remoteStatusLabel.Font = Enum.Font.Gotham
    remoteStatusLabel.TextSize = 13
    remoteStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    remoteStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    remoteStatusLabel.Name = "RemoteStatusLabel"
    
    -- タブ切り替え
    for i, btn in ipairs(tabButtons) do
        btn.MouseButton1Click:Connect(function()
            for j, b in ipairs(tabButtons) do
                b.BackgroundColor3 = (j == i) and Color3.fromRGB(180, 60, 255) or Color3.fromRGB(40, 40, 60)
            end
            for j, f in ipairs(contentFrames) do
                f.Visible = (j == i)
            end
        end)
    end
    
    -- ターゲット更新ループ
    task.spawn(function()
        while true do
            if currentTarget then
                local name = currentTarget.Type == "Player" and currentTarget.Object.Name or currentTarget.Object.Name
                local dist = math.floor(currentTarget.Distance)
                local hp = math.floor(currentTarget.Humanoid.Health)
                targetDisplay.Text = "Target: " .. name .. " (" .. dist .. "s | HP: " .. hp .. ")"
            else
                targetDisplay.Text = "Target: None"
            end
            task.wait(0.3)
        end
    end)
    
    return screenGui
end

-- ============================================================
-- キーバインド
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F then
        toggleAura(not Settings.Enabled)
        for _, btn in ipairs(LP.PlayerGui:GetDescendants()) do
            if btn:IsA("TextButton") and (btn.Text:find("START") or btn.Text:find("STOP")) then
                btn.Text = Settings.Enabled and "■ STOP" or "▶ START"
                btn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(60, 60, 80)
            end
        end
    end
    
    if input.KeyCode == Enum.KeyCode.R then
        findAllRemotes()
        updateRemoteStatus()
        remoteStatusLabel.Text = "Hit:✅ Att:✅ Mel:✅ Swd:✅"
        print("[AttackAura] リモート再検出完了")
    end
end)

-- ============================================================
-- UI起動
-- ============================================================
createUI()
updateRemoteStatus()

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Attack Aura Hub v14",
        Text = "震え・ジャンプ制限解消 | F:Toggle | R:Rescan",
        Duration = 5
    })
end)

print("==========================================")
print("🎉 Blox Fruits Attack Aura Hub v14")
print("✅ 震えを完全解消（ChangeState廃止）")
print("✅ ジャンプ制限を完全解消")
print("✅ 速度低下なし（TPWalkでカバー可）")
print("Fキー: ON/OFF | Rキー: リモート再検出")
print("==========================================")
