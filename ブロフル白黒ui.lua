-- ============================================================
-- Blox Fruits Attack Aura Hub v20 (フルーツ版統合・Dragon対応)
-- モバイル最適化版 (内部ロジック変更なし) ・ モノトーンUI版
-- ============================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

-- ============================================================
-- ★ 設定 (Attack Aura + フルーツ版)
-- ============================================================
local Settings = {
    -- Attack Aura (近接)
    Enabled = false,
    Range = 50,
    Speed = 0.3,
    TargetMode = "Nearest",
    IgnorePlayers = false,
    IgnoreNPC = false,
    DisableAttackAnim = true,
    -- PvP Orbit
    OrbitEnabled = false,
    OrbitRadius = 12,
    OrbitHeight = 5,
    OrbitSpeed = 1.5,
    -- ★ Fruit Aura (フルーツ版)
    FruitEnabled = false,
    FruitRange = 80,
    FruitSpeed = 0.5,
    FruitTargetMode = "Nearest",
    FruitRemoteType = "Both",  -- "LeftClick" / "Backpack" / "Both"
    -- ESP
    LabelESP = false,
    TracerESP = false,
    HitboxESP = false,
    -- Movement
    TPWall = false,
    SpeedValue = 16,
    JumpPowerValue = 50,
}

local auraRunning = false
local auraThread = nil
local currentTarget = nil
local orbitAngle = 0
local statusLabel
local miniStatus
local remoteStatusLabel

-- ============================================================
-- ★ フルーツリモート (キャッシュ)
-- ============================================================
local fruitRemotes = {
    LeftClick = nil,
    Backpack = nil,
}

local function findFruitRemotes()
    local char = LP.Character
    local bp = LP.Backpack
    
    if char then
        local dragon = char:FindFirstChild("Dragon-Dragon")
        if dragon then
            fruitRemotes.LeftClick = dragon:FindFirstChild("LeftClickRemote")
        end
    end
    
    if bp then
        local dragonBp = bp:FindFirstChild("Dragon-Dragon")
        if dragonBp then
            fruitRemotes.Backpack = dragonBp:FindFirstChild("RemoteEvent")
        end
    end
    
    print("[FruitAura] LeftClickRemote: " .. (fruitRemotes.LeftClick and "✅" or "❌"))
    print("[FruitAura] Backpack RemoteEvent: " .. (fruitRemotes.Backpack and "✅" or "❌"))
end

local function refreshFruitRemotes()
    findFruitRemotes()
    for _, lbl in ipairs(LP.PlayerGui:GetDescendants()) do
        if lbl:IsA("TextLabel") and lbl.Name == "FruitStatusLabel" then
            local lc = fruitRemotes.LeftClick and "✅" or "❌"
            local bp = fruitRemotes.Backpack and "✅" or "❌"
            lbl.Text = "LeftClick:" .. lc .. " Backpack:" .. bp
        end
    end
end

-- ============================================================
-- ★ TPWalk 管理 (TranslateBy)
-- ============================================================
local tpwalking = false
local tpwalkConn = nil

local function startTpwalk()
    if tpwalking then return end
    tpwalking = true
    if tpwalkConn then tpwalkConn:Disconnect() end
    tpwalkConn = RunService.Heartbeat:Connect(function()
        if not tpwalking then return end
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        if hum.MoveDirection.Magnitude > 0 then
            hrp:TranslateBy(hum.MoveDirection * (Settings.SpeedValue / 60))
        end
    end)
end

local function stopTpwalk()
    tpwalking = false
    if tpwalkConn then
        tpwalkConn:Disconnect()
        tpwalkConn = nil
    end
end

-- ============================================================
-- ★ ESP 管理 (自分以外の全プレイヤー対象)
-- ============================================================
local espObjects = {}
local espConn = nil
local selectedPlayer = nil

-- ============================================================
-- ★ リモート群 (近接用)
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
    findFruitRemotes()  -- フルーツリモートも検出
end
findAllRemotes()

-- ============================================================
-- ★ 攻撃アニメーション抑制 (近接用)
-- ============================================================
local function suppressAttackAnimation()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not Settings.DisableAttackAnim then return end
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        local name = track.Name:lower()
        if name:find("attack") or name:find("melee") or name:find("sword") or name:find("slash") or name:find("combo") or name:find("hit") or name:find("punch") or name:find("kick") then
            pcall(function() track:Stop() end)
        end
    end
end

-- ============================================================
-- ★ ターゲット取得 (共通)
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
-- ★ 近接攻撃実行 (既存)
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

    pcall(function()
        local lookAt = CFrame.lookAt(hrp.Position, target.HRP.Position)
        hrp.CFrame = hrp.CFrame:Lerp(lookAt, 0.3)
    end)

    local success = false
    if remotes.RegisterHit then
        pcall(function()
            remotes.RegisterHit:FireServer(target.HRP)
            success = true
        end)
        if not success then pcall(function() remotes.RegisterHit:FireServer(target.HRP, target.Object) success = true end) end
        if not success then pcall(function() remotes.RegisterHit:FireServer(target.HRP.Position) success = true end) end
    end
    if remotes.RegisterAttack then
        pcall(function()
            remotes.RegisterAttack:FireServer(target.HRP)
            task.wait(0.02)
            if remotes.RegisterHit then remotes.RegisterHit:FireServer(target.HRP) end
            success = true
        end)
    end
    if remotes.Melee then pcall(function() remotes.Melee:FireServer(target.HRP) success = true end) end
    if remotes.Sword then pcall(function() remotes.Sword:FireServer(target.HRP) success = true end) end
    if remotes.Combat then pcall(function() remotes.Combat:FireServer(target.HRP) success = true end) end
    if remotes.Click then pcall(function() remotes.Click:FireServer(target.HRP) success = true end) end
    if not success then
        pcall(function()
            local uis = game:GetService("UserInputService")
            if uis.TouchEnabled then uis:TouchTap(Vector2.new(0.5, 0.5)) end
            success = true
        end)
    end

    if Settings.DisableAttackAnim then
        pcall(function()
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                local name = track.Name:lower()
                if name:find("attack") or name:find("melee") or name:find("sword") or name:find("slash") or name:find("combo") then
                    track:Stop()
                end
            end
        end)
    end
    return success
end

-- ============================================================
-- ★ ★ ★ フルーツ攻撃実行 (Dragon-Dragon) ★ ★ ★
-- ============================================================
local function doFruitAttack(target)
    if not target or not target.HRP or not target.HRP.Parent then return false end

    if not fruitRemotes.LeftClick and not fruitRemotes.Backpack then
        return false
    end

    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local targetPos = target.HRP.Position

    pcall(function()
        local lookAt = CFrame.lookAt(hrp.Position, targetPos)
        hrp.CFrame = hrp.CFrame:Lerp(lookAt, 0.2)
    end)

    local success = false

    -- LeftClickRemote (Character 内)
    if fruitRemotes.LeftClick and (Settings.FruitRemoteType == "LeftClick" or Settings.FruitRemoteType == "Both") then
        pcall(function()
            fruitRemotes.LeftClick:FireServer(targetPos, 1)
            success = true
        end)
    end

    -- Backpack RemoteEvent (Backpack 内)
    if fruitRemotes.Backpack and (Settings.FruitRemoteType == "Backpack" or Settings.FruitRemoteType == "Both") then
        pcall(function()
            fruitRemotes.Backpack:FireServer(false)
            success = true
        end)
    end

    return success
end

-- ============================================================
-- ★ 近接 メインループ (既存)
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
            
            if Settings.OrbitEnabled and selected.Distance <= Settings.Range then
                local targetPos = selected.HRP.Position
                orbitAngle = orbitAngle + (Settings.OrbitSpeed * 0.05)
                if orbitAngle > 2 * math.pi then orbitAngle = orbitAngle - 2 * math.pi end
                local offsetX = math.cos(orbitAngle) * Settings.OrbitRadius
                local offsetZ = math.sin(orbitAngle) * Settings.OrbitRadius
                local newPos = CFrame.new(
                    targetPos.X + offsetX,
                    targetPos.Y + Settings.OrbitHeight,
                    targetPos.Z + offsetZ
                )
                pcall(function()
                    hrp.CFrame = hrp.CFrame:Lerp(newPos, 0.4)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end)
            end
            
            doAttack(selected)
        end

        task.wait(Settings.Speed)
    end
end

-- ============================================================
-- ★ ★ ★ フルーツメインループ (Fruit Aura) ★ ★ ★
-- ============================================================
local function fruitAuraMain()
    while auraRunning do
        if not Settings.FruitEnabled then
            task.wait(0.1)
            continue
        end

        local char = LP.Character
        if not char then task.wait(0.5) continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then task.wait(0.5) continue end

        -- フルーツ装備チェック
        local dragon = char:FindFirstChild("Dragon-Dragon")
        if not dragon then
            if Settings.FruitEnabled then
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "⚠️ フルーツ未装備",
                    Text = "Dragon-Dragon を装備してください",
                    Duration = 3
                })
                Settings.FruitEnabled = false
                for _, btn in ipairs(LP.PlayerGui:GetDescendants()) do
                    if btn:IsA("TextButton") and btn.Parent and btn.Parent.Name == "FruitTab" and btn.Text:find("START") then
                        btn.Text = "▶ START"
                        btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
                    end
                end
                for _, lbl in ipairs(LP.PlayerGui:GetDescendants()) do
                    if lbl:IsA("TextLabel") and lbl.Name == "FruitStatusLabel" then
                        lbl.Text = "○ OFF"
                        lbl.TextColor3 = Color3.fromRGB(120,120,120)
                    end
                end
            end
            task.wait(1)
            continue
        end

        local allTargets = getTargets()
        local inRange = {}
        for _, t in ipairs(allTargets) do
            if t.Distance <= Settings.FruitRange then
                table.insert(inRange, t)
            end
        end

        if #inRange == 0 then
            task.wait(0.3)
            continue
        end

        local selected = nil
        if Settings.FruitTargetMode == "Nearest" then
            table.sort(inRange, function(a, b) return a.Distance < b.Distance end)
            selected = inRange[1]
        else
            table.sort(inRange, function(a, b) return a.Humanoid.Health < b.Humanoid.Health end)
            selected = inRange[1]
        end

        if selected then
            doFruitAttack(selected)
        end

        task.wait(Settings.FruitSpeed)
    end
end

-- ============================================================
-- ★ トグル関数 (近接)
-- ============================================================
local function toggleAura(state)
    Settings.Enabled = state
    if state then
        if not auraRunning then
            auraRunning = true
            auraThread = task.spawn(auraMain)
            task.spawn(fruitAuraMain)  -- フルーツも同時起動
        end
        if statusLabel then
            statusLabel.Text = "● ACTIVE"
            statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        if miniStatus then
            miniStatus.Text = "●"
            miniStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    else
        auraRunning = false
        if auraThread then task.cancel(auraThread); auraThread = nil end
        currentTarget = nil
        orbitAngle = 0
        if statusLabel then
            statusLabel.Text = "○ OFF"
            statusLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
        end
        if miniStatus then
            miniStatus.Text = "○"
            miniStatus.TextColor3 = Color3.fromRGB(120, 120, 120)
        end
    end
end

-- ============================================================
-- ★ リモート状態更新 (近接 + フルーツ)
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
        if lbl:IsA("TextLabel") and lbl.Name == "FruitStatusLabel" then
            local lc = fruitRemotes.LeftClick and "✅" or "❌"
            local bp = fruitRemotes.Backpack and "✅" or "❌"
            lbl.Text = "LeftClick:" .. lc .. " Backpack:" .. bp
        end
    end
end

-- ============================================================
-- ★ ESP 関数 (自分以外の全プレイヤー対象)
-- ============================================================
local function clearESP()
    for _, obj in ipairs(espObjects) do
        pcall(function() obj:Destroy() end)
    end
    espObjects = {}
end

local function updateESP()
    clearESP()
    if not Settings.LabelESP and not Settings.TracerESP and not Settings.HitboxESP then return end

    local myChar = LP.Character
    if not myChar then return end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local myPos = myHrp.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        
        local char = plr.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end

        local pos = hrp.Position
        local dist = (pos - myPos).Magnitude

        if Settings.LabelESP then
            local label = Instance.new("BillboardGui")
            label.Size = UDim2.new(0, 200, 0, 30)
            label.Adornee = hrp
            label.StudsOffset = Vector3.new(0, 4, 0)
            label.Parent = hrp
            label.AlwaysOnTop = true
            label.MaxDistance = 200
            
            local text = Instance.new("TextLabel", label)
            text.Size = UDim2.new(1, 0, 1, 0)
            text.BackgroundTransparency = 1
            text.Text = "👤 " .. plr.Name .. " (" .. math.floor(dist) .. "s)"
            text.Font = Enum.Font.GothamBold
            text.TextSize = 14
            text.TextColor3 = Color3.fromRGB(255, 255, 255)
            text.TextStrokeTransparency = 0.3
            text.TextXAlignment = Enum.TextXAlignment.Center
            table.insert(espObjects, label)
        end

        if Settings.TracerESP then
            local tracer = Instance.new("LineHandleAdornment")
            tracer.Adornee = myHrp
            tracer.ZIndex = 5
            tracer.AlwaysOnTop = true
            tracer.Points = {myPos, pos}
            tracer.Color3 = Color3.fromRGB(200, 200, 200)
            tracer.Thickness = 2
            tracer.Transparency = 0.5
            tracer.Parent = myHrp
            table.insert(espObjects, tracer)
        end

        if Settings.HitboxESP then
            local box = Instance.new("SelectionBox")
            box.Adornee = char
            box.Color3 = Color3.fromRGB(200, 200, 200)
            box.LineThickness = 0.1
            box.Transparency = 0.5
            box.Parent = char
            table.insert(espObjects, box)
        end
    end
end

local function startESP()
    if espConn then espConn:Disconnect(); espConn = nil end
    espConn = RunService.RenderStepped:Connect(function()
        if Settings.LabelESP or Settings.TracerESP or Settings.HitboxESP then
            updateESP()
        else
            clearESP()
        end
    end)
end

local function stopESP()
    if espConn then espConn:Disconnect(); espConn = nil end
    clearESP()
end

-- ============================================================
-- ★ TPWall (ノークリップ)
-- ============================================================
local noclipConn = nil

local function toggleTPWall(state)
    Settings.TPWall = state
    if state then
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = RunService.Heartbeat:Connect(function()
            local char = LP.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        local char = LP.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- ============================================================
-- ★ スピード(TPWalk)・ジャンプパワー適用
-- ============================================================
local function applyMovement()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    hum.WalkSpeed = 16
    hum.JumpPower = Settings.JumpPowerValue

    if Settings.SpeedValue > 16 then
        startTpwalk()
    else
        stopTpwalk()
    end
end

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    applyMovement()
    refreshFruitRemotes()
end)

-- ============================================================
-- ★ ★ ★ UI作成 (モバイル最適化サイズ調整のみ) ★ ★ ★
-- ============================================================
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AttackAuraHub"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LP:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    -- モバイル対応: 縦横のサイズを小型化し、画面中央に配置
    mainFrame.Size = UDim2.new(0, 340, 0, 280)
    mainFrame.Position = UDim2.new(0.5, -170, 0.5, -140)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = Color3.fromRGB(200, 200, 200)
    stroke.Thickness = 1.5

    -- タイトルバー
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 38)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = mainFrame

    -- ドラッグ機能
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
    title.Size = UDim2.new(0.25, 0, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚔ HUB"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    -- Attack ステータス
    miniStatus = Instance.new("TextLabel", titleBar)
    miniStatus.Size = UDim2.new(0.08, 0, 1, 0)
    miniStatus.Position = UDim2.new(0.25, 0, 0, 0)
    miniStatus.BackgroundTransparency = 1
    miniStatus.Text = "○"
    miniStatus.Font = Enum.Font.GothamBold
    miniStatus.TextSize = 16
    miniStatus.TextColor3 = Color3.fromRGB(120, 120, 120)
    miniStatus.TextXAlignment = Enum.TextXAlignment.Center
    miniStatus.Parent = titleBar

    -- 展開/収納 トグルボタン
    local toggleBtn = Instance.new("TextButton", titleBar)
    toggleBtn.Size = UDim2.new(0, 50, 0, 30)
    toggleBtn.Position = UDim2.new(1, -58, 0.5, -15)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    toggleBtn.Text = "📂"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 16
    toggleBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)
    toggleBtn.Parent = titleBar

    local isCollapsed = false
    local function toggleCollapse()
        isCollapsed = not isCollapsed
        if isCollapsed then
            TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 340, 0, 38)
            }):Play()
            toggleBtn.Text = "📁"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        else
            TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 340, 0, 280)
            }):Play()
            toggleBtn.Text = "📂"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end
    toggleBtn.MouseButton1Click:Connect(toggleCollapse)
    toggleBtn.TouchTap:Connect(toggleCollapse)

    -- ===== タブボタン (6タブ: Attack, Fruit, Enemies, PvP, Players, Settings) =====
    local tabFrame = Instance.new("Frame", mainFrame)
    tabFrame.Size = UDim2.new(1, -10, 0, 30)
    tabFrame.Position = UDim2.new(0, 5, 0, 42)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = mainFrame

    local tabs = {"Attack", "Fruit", "Enemies", "PvP", "Players", "Settings"}
    local tabButtons = {}
    local contentFrames = {}

    for i, name in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabFrame)
        btn.Size = UDim2.new(1 / #tabs, -2, 1, 0)
        btn.Position = UDim2.new((i-1) / #tabs, 1, 0, 0)
        btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(35, 35, 35)
        btn.Text = name
        btn.Font = Enum.Font.GothamBold
        btn.TextScaled = true 
        btn.TextColor3 = Color3.new(1,1,1)
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.Parent = tabFrame
        
        local textPadding = Instance.new("UIPadding", btn)
        textPadding.PaddingTop = UDim.new(0, 4)
        textPadding.PaddingBottom = UDim.new(0, 4)
        
        local function switchTab()
            for j, b in ipairs(tabButtons) do
                b.BackgroundColor3 = (j == i) and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(35, 35, 35)
            end
            for j, f in ipairs(contentFrames) do
                f.Visible = (j == i)
            end
        end
        btn.MouseButton1Click:Connect(switchTab)
        btn.TouchTap:Connect(switchTab)
        tabButtons[i] = btn
    end

    -- ===== スクロール対応 コンテンツコンテナ (モバイル対応の相対高さ) =====
    local contentContainer = Instance.new("ScrollingFrame", mainFrame)
    contentContainer.Size = UDim2.new(1, -20, 1, -85) 
    contentContainer.Position = UDim2.new(0, 10, 0, 78)
    contentContainer.BackgroundTransparency = 1
    contentContainer.BorderSizePixel = 0
    contentContainer.CanvasSize = UDim2.new(0, 0, 0, 320)
    contentContainer.ScrollBarThickness = 6
    contentContainer.Parent = mainFrame

    -- ============================================================
    -- ★ Attackタブ (近接) - 既存
    -- ============================================================
    local attackTab = Instance.new("Frame", contentContainer)
    attackTab.Size = UDim2.new(1, 0, 0, 220)
    attackTab.BackgroundTransparency = 1
    attackTab.Visible = true
    attackTab.Parent = contentContainer
    contentFrames[1] = attackTab
    attackTab.Name = "AttackTab"

    local attackStatusBar = Instance.new("Frame", attackTab)
    attackStatusBar.Size = UDim2.new(1, 0, 0, 34)
    attackStatusBar.Position = UDim2.new(0, 0, 0, 0)
    attackStatusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    attackStatusBar.BorderSizePixel = 0
    Instance.new("UICorner", attackStatusBar).CornerRadius = UDim.new(0,8)
    attackStatusBar.Parent = attackTab

    statusLabel = Instance.new("TextLabel", attackStatusBar)
    statusLabel.Size = UDim2.new(0.6, 0, 1, 0)
    statusLabel.Position = UDim2.new(0, 10, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "○ OFF"
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 16
    statusLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = attackStatusBar

    local attackToggleBtn = Instance.new("TextButton", attackStatusBar)
    attackToggleBtn.Size = UDim2.new(0, 80, 0, 26)
    attackToggleBtn.Position = UDim2.new(1, -88, 0.5, -13)
    attackToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    attackToggleBtn.Text = "▶ START"
    attackToggleBtn.Font = Enum.Font.GothamBold
    attackToggleBtn.TextSize = 13
    attackToggleBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", attackToggleBtn).CornerRadius = UDim.new(0,6)
    attackToggleBtn.Parent = attackStatusBar
    local function toggleAttack()
        toggleAura(not Settings.Enabled)
        attackToggleBtn.Text = Settings.Enabled and "■ STOP" or "▶ START"
        attackToggleBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(45, 45, 45)
    end
    attackToggleBtn.MouseButton1Click:Connect(toggleAttack)
    attackToggleBtn.TouchTap:Connect(toggleAttack)

    -- Range
    local rangeLabel = Instance.new("TextLabel", attackTab)
    rangeLabel.Size = UDim2.new(0.3, 0, 0, 22)
    rangeLabel.Position = UDim2.new(0, 0, 0, 40)
    rangeLabel.BackgroundTransparency = 1
    rangeLabel.Text = "📏 Range:"
    rangeLabel.Font = Enum.Font.Gotham
    rangeLabel.TextSize = 14
    rangeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    rangeLabel.TextXAlignment = Enum.TextXAlignment.Left
    rangeLabel.Parent = attackTab

    local rangeBox = Instance.new("TextBox", attackTab)
    rangeBox.Size = UDim2.new(0.2, 0, 0, 26)
    rangeBox.Position = UDim2.new(0.7, 0, 0, 38)
    rangeBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    rangeBox.Text = tostring(Settings.Range)
    rangeBox.Font = Enum.Font.GothamBold
    rangeBox.TextSize = 14
    rangeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    rangeBox.ClearTextOnFocus = false
    Instance.new("UICorner", rangeBox).CornerRadius = UDim.new(0, 4)
    rangeBox.Parent = attackTab
    rangeBox.FocusLost:Connect(function()
        local val = tonumber(rangeBox.Text)
        if val then
            Settings.Range = val
            rangeBox.Text = tostring(Settings.Range)
        else
            rangeBox.Text = tostring(Settings.Range)
        end
    end)

    -- Speed
    local speedLabel = Instance.new("TextLabel", attackTab)
    speedLabel.Size = UDim2.new(0.3, 0, 0, 22)
    speedLabel.Position = UDim2.new(0, 0, 0, 80)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "⚡ Speed:"
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextSize = 14
    speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.Parent = attackTab

    local speedBox = Instance.new("TextBox", attackTab)
    speedBox.Size = UDim2.new(0.2, 0, 0, 26)
    speedBox.Position = UDim2.new(0.7, 0, 0, 78)
    speedBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    speedBox.Text = string.format("%.2f", Settings.Speed)
    speedBox.Font = Enum.Font.GothamBold
    speedBox.TextSize = 14
    speedBox.TextColor3 = Color3.fromRGB(255,255,255)
    speedBox.ClearTextOnFocus = false
    Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 4)
    speedBox.Parent = attackTab
    speedBox.FocusLost:Connect(function()
        local val = tonumber(speedBox.Text)
        if val then
            Settings.Speed = val
            speedBox.Text = tostring(Settings.Speed)
        else
            speedBox.Text = tostring(Settings.Speed)
        end
    end)

    -- ターゲットモード
    local modeLabel = Instance.new("TextLabel", attackTab)
    modeLabel.Size = UDim2.new(0.6, 0, 0, 22)
    modeLabel.Position = UDim2.new(0, 0, 0, 120)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Text = "🎯 Mode: Nearest"
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.TextSize = 14
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.Parent = attackTab

    local modeBtn = Instance.new("TextButton", attackTab)
    modeBtn.Size = UDim2.new(0, 90, 0, 26)
    modeBtn.Position = UDim2.new(1, -95, 0, 118)
    modeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    modeBtn.Text = "Nearest"
    modeBtn.Font = Enum.Font.GothamBold
    modeBtn.TextSize = 12
    modeBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0,6)
    modeBtn.Parent = attackTab
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
    modeBtn.TouchTap:Connect(function()
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
    targetDisplay.Position = UDim2.new(0, 0, 0, 158)
    targetDisplay.BackgroundTransparency = 1
    targetDisplay.Text = "Target: None"
    targetDisplay.Font = Enum.Font.Gotham
    targetDisplay.TextSize = 13
    targetDisplay.TextColor3 = Color3.fromRGB(150, 150, 150)
    targetDisplay.TextXAlignment = Enum.TextXAlignment.Left
    targetDisplay.Parent = attackTab

    local keybindLabel = Instance.new("TextLabel", attackTab)
    keybindLabel.Size = UDim2.new(1, 0, 0, 20)
    keybindLabel.Position = UDim2.new(0, 0, 0, 184)
    keybindLabel.BackgroundTransparency = 1
    keybindLabel.Text = "👆 [Mobile] UIのSTARTボタンでON/OFF"
    keybindLabel.Font = Enum.Font.Gotham
    keybindLabel.TextSize = 12
    keybindLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
    keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
    keybindLabel.Parent = attackTab

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

    -- ============================================================
    -- ★ ★ ★ Fruitタブ (新規) ★ ★ ★
    -- ============================================================
    local fruitTab = Instance.new("Frame", contentContainer)
    fruitTab.Size = UDim2.new(1, 0, 0, 280)
    fruitTab.BackgroundTransparency = 1
    fruitTab.Visible = false
    fruitTab.Parent = contentContainer
    contentFrames[2] = fruitTab
    fruitTab.Name = "FruitTab"

    -- Fruit ステータスバー
    local fruitStatusBar = Instance.new("Frame", fruitTab)
    fruitStatusBar.Size = UDim2.new(1, 0, 0, 34)
    fruitStatusBar.Position = UDim2.new(0, 0, 0, 0)
    fruitStatusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    fruitStatusBar.BorderSizePixel = 0
    Instance.new("UICorner", fruitStatusBar).CornerRadius = UDim.new(0,8)
    fruitStatusBar.Parent = fruitTab

    local fruitStatusLabel = Instance.new("TextLabel", fruitStatusBar)
    fruitStatusLabel.Size = UDim2.new(0.6, 0, 1, 0)
    fruitStatusLabel.Position = UDim2.new(0, 10, 0, 0)
    fruitStatusLabel.BackgroundTransparency = 1
    fruitStatusLabel.Text = "○ OFF"
    fruitStatusLabel.Font = Enum.Font.GothamBold
    fruitStatusLabel.TextSize = 16
    fruitStatusLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    fruitStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    fruitStatusLabel.Parent = fruitStatusBar
    fruitStatusLabel.Name = "FruitStatusLabel"

    local fruitToggleBtn = Instance.new("TextButton", fruitStatusBar)
    fruitToggleBtn.Size = UDim2.new(0, 80, 0, 26)
    fruitToggleBtn.Position = UDim2.new(1, -88, 0.5, -13)
    fruitToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    fruitToggleBtn.Text = "▶ START"
    fruitToggleBtn.Font = Enum.Font.GothamBold
    fruitToggleBtn.TextSize = 13
    fruitToggleBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", fruitToggleBtn).CornerRadius = UDim.new(0,6)
    fruitToggleBtn.Parent = fruitStatusBar
    local function toggleFruit()
        Settings.FruitEnabled = not Settings.FruitEnabled
        fruitToggleBtn.Text = Settings.FruitEnabled and "■ STOP" or "▶ START"
        fruitToggleBtn.BackgroundColor3 = Settings.FruitEnabled and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(45, 45, 45)
        fruitStatusLabel.Text = Settings.FruitEnabled and "● ACTIVE" or "○ OFF"
        fruitStatusLabel.TextColor3 = Settings.FruitEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120)
        if Settings.FruitEnabled and not auraRunning then
            auraRunning = true
            task.spawn(fruitAuraMain)
        end
    end
    fruitToggleBtn.MouseButton1Click:Connect(toggleFruit)
    fruitToggleBtn.TouchTap:Connect(toggleFruit)

    -- Fruit Range
    local fruitRangeLabel = Instance.new("TextLabel", fruitTab)
    fruitRangeLabel.Size = UDim2.new(0.3, 0, 0, 22)
    fruitRangeLabel.Position = UDim2.new(0, 0, 0, 40)
    fruitRangeLabel.BackgroundTransparency = 1
    fruitRangeLabel.Text = "🍎 Fruit Range:"
    fruitRangeLabel.Font = Enum.Font.Gotham
    fruitRangeLabel.TextSize = 14
    fruitRangeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fruitRangeLabel.TextXAlignment = Enum.TextXAlignment.Left
    fruitRangeLabel.Parent = fruitTab

    local fruitRangeBox = Instance.new("TextBox", fruitTab)
    fruitRangeBox.Size = UDim2.new(0.2, 0, 0, 26)
    fruitRangeBox.Position = UDim2.new(0.7, 0, 0, 38)
    fruitRangeBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    fruitRangeBox.Text = tostring(Settings.FruitRange)
    fruitRangeBox.Font = Enum.Font.GothamBold
    fruitRangeBox.TextSize = 14
    fruitRangeBox.TextColor3 = Color3.fromRGB(255,255,255)
    fruitRangeBox.ClearTextOnFocus = false
    Instance.new("UICorner", fruitRangeBox).CornerRadius = UDim.new(0, 4)
    fruitRangeBox.Parent = fruitTab
    fruitRangeBox.FocusLost:Connect(function()
        local val = tonumber(fruitRangeBox.Text)
        if val then
            Settings.FruitRange = val
            fruitRangeBox.Text = tostring(Settings.FruitRange)
        else
            fruitRangeBox.Text = tostring(Settings.FruitRange)
        end
    end)

    -- Fruit Speed
    local fruitSpeedLabel = Instance.new("TextLabel", fruitTab)
    fruitSpeedLabel.Size = UDim2.new(0.3, 0, 0, 22)
    fruitSpeedLabel.Position = UDim2.new(0, 0, 0, 80)
    fruitSpeedLabel.BackgroundTransparency = 1
    fruitSpeedLabel.Text = "⚡ Fruit Speed:"
    fruitSpeedLabel.Font = Enum.Font.Gotham
    fruitSpeedLabel.TextSize = 14
    fruitSpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fruitSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    fruitSpeedLabel.Parent = fruitTab

    local fruitSpeedBox = Instance.new("TextBox", fruitTab)
    fruitSpeedBox.Size = UDim2.new(0.2, 0, 0, 26)
    fruitSpeedBox.Position = UDim2.new(0.7, 0, 0, 78)
    fruitSpeedBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    fruitSpeedBox.Text = string.format("%.2f", Settings.FruitSpeed)
    fruitSpeedBox.Font = Enum.Font.GothamBold
    fruitSpeedBox.TextSize = 14
    fruitSpeedBox.TextColor3 = Color3.fromRGB(255,255,255)
    fruitSpeedBox.ClearTextOnFocus = false
    Instance.new("UICorner", fruitSpeedBox).CornerRadius = UDim.new(0, 4)
    fruitSpeedBox.Parent = fruitTab
    fruitSpeedBox.FocusLost:Connect(function()
        local val = tonumber(fruitSpeedBox.Text)
        if val then
            Settings.FruitSpeed = val
            fruitSpeedBox.Text = tostring(Settings.FruitSpeed)
        else
            fruitSpeedBox.Text = tostring(Settings.FruitSpeed)
        end
    end)

    -- Fruit ターゲットモード
    local fruitModeLabel = Instance.new("TextLabel", fruitTab)
    fruitModeLabel.Size = UDim2.new(0.6, 0, 0, 22)
    fruitModeLabel.Position = UDim2.new(0, 0, 0, 120)
    fruitModeLabel.BackgroundTransparency = 1
    fruitModeLabel.Text = "🎯 Mode: Nearest"
    fruitModeLabel.Font = Enum.Font.Gotham
    fruitModeLabel.TextSize = 14
    fruitModeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fruitModeLabel.TextXAlignment = Enum.TextXAlignment.Left
    fruitModeLabel.Parent = fruitTab

    local fruitModeBtn = Instance.new("TextButton", fruitTab)
    fruitModeBtn.Size = UDim2.new(0, 90, 0, 26)
    fruitModeBtn.Position = UDim2.new(1, -95, 0, 118)
    fruitModeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    fruitModeBtn.Text = "Nearest"
    fruitModeBtn.Font = Enum.Font.GothamBold
    fruitModeBtn.TextSize = 12
    fruitModeBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", fruitModeBtn).CornerRadius = UDim.new(0,6)
    fruitModeBtn.Parent = fruitTab
    fruitModeBtn.MouseButton1Click:Connect(function()
        if Settings.FruitTargetMode == "Nearest" then
            Settings.FruitTargetMode = "LowestHP"
            fruitModeBtn.Text = "LowestHP"
            fruitModeLabel.Text = "🎯 Mode: LowestHP"
        else
            Settings.FruitTargetMode = "Nearest"
            fruitModeBtn.Text = "Nearest"
            fruitModeLabel.Text = "🎯 Mode: Nearest"
        end
    end)
    fruitModeBtn.TouchTap:Connect(function()
        if Settings.FruitTargetMode == "Nearest" then
            Settings.FruitTargetMode = "LowestHP"
            fruitModeBtn.Text = "LowestHP"
            fruitModeLabel.Text = "🎯 Mode: LowestHP"
        else
            Settings.FruitTargetMode = "Nearest"
            fruitModeBtn.Text = "Nearest"
            fruitModeLabel.Text = "🎯 Mode: Nearest"
        end
    end)

    -- Fruit リモートタイプ選択 (ドロップダウン)
    local remoteTypeLabel = Instance.new("TextLabel", fruitTab)
    remoteTypeLabel.Size = UDim2.new(0.5, 0, 0, 22)
    remoteTypeLabel.Position = UDim2.new(0, 0, 0, 160)
    remoteTypeLabel.BackgroundTransparency = 1
    remoteTypeLabel.Text = "🔧 Remote Type:"
    remoteTypeLabel.Font = Enum.Font.Gotham
    remoteTypeLabel.TextSize = 14
    remoteTypeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    remoteTypeLabel.TextXAlignment = Enum.TextXAlignment.Left
    remoteTypeLabel.Parent = fruitTab

    local remoteTypeBtn = Instance.new("TextButton", fruitTab)
    remoteTypeBtn.Size = UDim2.new(0.35, 0, 0, 26)
    remoteTypeBtn.Position = UDim2.new(0.6, 0, 0, 158)
    remoteTypeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    remoteTypeBtn.Text = Settings.FruitRemoteType
    remoteTypeBtn.Font = Enum.Font.GothamBold
    remoteTypeBtn.TextSize = 12
    remoteTypeBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", remoteTypeBtn).CornerRadius = UDim.new(0, 6)
    remoteTypeBtn.Parent = fruitTab
    remoteTypeBtn.MouseButton1Click:Connect(function()
        local types = {"LeftClick", "Backpack", "Both"}
        for i, t in ipairs(types) do
            if t == Settings.FruitRemoteType then
                local nextIdx = i % #types + 1
                Settings.FruitRemoteType = types[nextIdx]
                remoteTypeBtn.Text = Settings.FruitRemoteType
                break
            end
        end
    end)
    remoteTypeBtn.TouchTap:Connect(function()
        local types = {"LeftClick", "Backpack", "Both"}
        for i, t in ipairs(types) do
            if t == Settings.FruitRemoteType then
                local nextIdx = i % #types + 1
                Settings.FruitRemoteType = types[nextIdx]
                remoteTypeBtn.Text = Settings.FruitRemoteType
                break
            end
        end
    end)

    -- Fruit リモートステータス表示
    local fruitStatusRemote = Instance.new("TextLabel", fruitTab)
    fruitStatusRemote.Size = UDim2.new(1, -20, 0, 20)
    fruitStatusRemote.Position = UDim2.new(0, 10, 0, 198)
    fruitStatusRemote.BackgroundTransparency = 1
    fruitStatusRemote.Text = "LeftClick: ❌  Backpack: ❌"
    fruitStatusRemote.Font = Enum.Font.Gotham
    fruitStatusRemote.TextSize = 12
    fruitStatusRemote.TextColor3 = Color3.fromRGB(200, 200, 200)
    fruitStatusRemote.TextXAlignment = Enum.TextXAlignment.Left
    fruitStatusRemote.Parent = fruitTab
    fruitStatusRemote.Name = "FruitStatusLabel"

    -- 更新ボタン
    local fruitRefreshBtn = Instance.new("TextButton", fruitTab)
    fruitRefreshBtn.Size = UDim2.new(0.5, 0, 0, 24)
    fruitRefreshBtn.Position = UDim2.new(0.25, 0, 0, 226)
    fruitRefreshBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    fruitRefreshBtn.Text = "🔄 リモート再検出"
    fruitRefreshBtn.Font = Enum.Font.GothamBold
    fruitRefreshBtn.TextSize = 12
    fruitRefreshBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", fruitRefreshBtn).CornerRadius = UDim.new(0, 6)
    fruitRefreshBtn.Parent = fruitTab
    fruitRefreshBtn.MouseButton1Click:Connect(function()
        refreshFruitRemotes()
    end)
    fruitRefreshBtn.TouchTap:Connect(function()
        refreshFruitRemotes()
    end)

    -- フルーツ装備チェック表示
    local fruitEquipLabel = Instance.new("TextLabel", fruitTab)
    fruitEquipLabel.Size = UDim2.new(1, -20, 0, 18)
    fruitEquipLabel.Position = UDim2.new(0, 10, 0, 256)
    fruitEquipLabel.BackgroundTransparency = 1
    fruitEquipLabel.Text = "💡 Dragon-Dragon 装備が必要です"
    fruitEquipLabel.Font = Enum.Font.Gotham
    fruitEquipLabel.TextSize = 11
    fruitEquipLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    fruitEquipLabel.TextXAlignment = Enum.TextXAlignment.Left
    fruitEquipLabel.Parent = fruitTab

    -- ============================================================
    -- ★ Enemiesタブ (contentFrames[3])
    -- ============================================================
    local enemiesTab = Instance.new("Frame", contentContainer)
    enemiesTab.Size = UDim2.new(1, 0, 0, 220)
    enemiesTab.BackgroundTransparency = 1
    enemiesTab.Visible = false
    enemiesTab.Parent = contentContainer
    contentFrames[3] = enemiesTab

    local enemyListTitle = Instance.new("TextLabel", enemiesTab)
    enemyListTitle.Size = UDim2.new(1, 0, 0, 24)
    enemyListTitle.Position = UDim2.new(0, 0, 0, 0)
    enemyListTitle.BackgroundTransparency = 1
    enemyListTitle.Text = "📋 検出中の敵"
    enemyListTitle.Font = Enum.Font.GothamBold
    enemyListTitle.TextSize = 15
    enemyListTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    enemyListTitle.TextXAlignment = Enum.TextXAlignment.Left
    enemyListTitle.Parent = enemiesTab

    local enemyList = Instance.new("ScrollingFrame", enemiesTab)
    enemyList.Size = UDim2.new(1, 0, 1, -34)
    enemyList.Position = UDim2.new(0, 0, 0, 26)
    enemyList.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    enemyList.BorderSizePixel = 0
    enemyList.CanvasSize = UDim2.new(0, 0, 0, 0)
    enemyList.ScrollBarThickness = 4
    Instance.new("UICorner", enemyList).CornerRadius = UDim.new(0,6)
    enemyList.Parent = enemiesTab

    local enemyListLayout = Instance.new("UIListLayout", enemyList)
    enemyListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    enemyListLayout.Padding = UDim.new(0, 4)
    enemyListLayout.Parent = enemyList

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
                    label.TextColor3 = Color3.fromRGB(180, 180, 180)
                    label.TextXAlignment = Enum.TextXAlignment.Left
                    label.Parent = enemyList
                    count = count + 1
                end
            end
            enemyList.CanvasSize = UDim2.new(0, 0, 0, count * 26 + 10)
            task.wait(1)
        end
    end)

    -- ============================================================
    -- ★ PvPタブ (contentFrames[4])
    -- ============================================================
    local pvpTab = Instance.new("Frame", contentContainer)
    pvpTab.Size = UDim2.new(1, 0, 0, 260)
    pvpTab.BackgroundTransparency = 1
    pvpTab.Visible = false
    pvpTab.Parent = contentContainer
    contentFrames[4] = pvpTab

    local pvpStatusBar = Instance.new("Frame", pvpTab)
    pvpStatusBar.Size = UDim2.new(1, 0, 0, 34)
    pvpStatusBar.Position = UDim2.new(0, 0, 0, 0)
    pvpStatusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    pvpStatusBar.BorderSizePixel = 0
    Instance.new("UICorner", pvpStatusBar).CornerRadius = UDim.new(0,8)
    pvpStatusBar.Parent = pvpTab

    local pvpStatusLabel = Instance.new("TextLabel", pvpStatusBar)
    pvpStatusLabel.Size = UDim2.new(0.6, 0, 1, 0)
    pvpStatusLabel.Position = UDim2.new(0, 10, 0, 0)
    pvpStatusLabel.BackgroundTransparency = 1
    pvpStatusLabel.Text = "○ OFF"
    pvpStatusLabel.Font = Enum.Font.GothamBold
    pvpStatusLabel.TextSize = 16
    pvpStatusLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    pvpStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    pvpStatusLabel.Parent = pvpStatusBar
    pvpStatusLabel.Name = "PvPStatusLabel"

    local pvpToggleBtn = Instance.new("TextButton", pvpStatusBar)
    pvpToggleBtn.Size = UDim2.new(0, 80, 0, 26)
    pvpToggleBtn.Position = UDim2.new(1, -88, 0.5, -13)
    pvpToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    pvpToggleBtn.Text = "▶ START"
    pvpToggleBtn.Font = Enum.Font.GothamBold
    pvpToggleBtn.TextSize = 13
    pvpToggleBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", pvpToggleBtn).CornerRadius = UDim.new(0,6)
    pvpToggleBtn.Parent = pvpStatusBar
    local function togglePvP()
        Settings.OrbitEnabled = not Settings.OrbitEnabled
        pvpToggleBtn.Text = Settings.OrbitEnabled and "■ STOP" or "▶ START"
        pvpToggleBtn.BackgroundColor3 = Settings.OrbitEnabled and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(45, 45, 45)
        pvpStatusLabel.Text = Settings.OrbitEnabled and "● ACTIVE" or "○ OFF"
        pvpStatusLabel.TextColor3 = Settings.OrbitEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120)
        orbitAngle = 0
    end
    pvpToggleBtn.MouseButton1Click:Connect(togglePvP)
    pvpToggleBtn.TouchTap:Connect(togglePvP)

    local function createPvPSlider(y, labelText, min, max, default, callback)
        local label = Instance.new("TextLabel", pvpTab)
        label.Size = UDim2.new(0.65, 0, 0, 22)
        label.Position = UDim2.new(0, 0, 0, y)
        label.BackgroundTransparency = 1
        label.Text = labelText .. default
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = pvpTab

        local valueLabel = Instance.new("TextLabel", pvpTab)
        valueLabel.Size = UDim2.new(0.25, 0, 0, 22)
        valueLabel.Position = UDim2.new(0.75, 0, 0, y)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(default)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 14
        valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = pvpTab

        local slider = Instance.new("Frame", pvpTab)
        slider.Size = UDim2.new(1, 0, 0, 6)
        slider.Position = UDim2.new(0, 0, 0, y + 24)
        slider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        Instance.new("UICorner", slider).CornerRadius = UDim.new(1,0)
        slider.Parent = pvpTab

        local fill = Instance.new("Frame", slider)
        local valNorm = (default - min) / (max - min)
        fill.Size = UDim2.new(valNorm, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
        fill.Parent = slider

        local dragging = false
        slider.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
        end)
        slider.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local pos = i.Position.X
                local absPos = slider.AbsolutePosition.X
                local size = slider.AbsoluteSize.X
                if size > 0 then
                    local val = math.clamp((pos - absPos) / size, 0, 1)
                    local realVal = math.floor(val * (max - min) + min)
                    fill.Size = UDim2.new(val, 0, 1, 0)
                    label.Text = labelText .. realVal
                    valueLabel.Text = tostring(realVal)
                    callback(realVal)
                end
            end
        end)
    end

    createPvPSlider(42, "🌀 Orbit Radius: ", 3, 30, Settings.OrbitRadius, function(v) Settings.OrbitRadius = v end)
    createPvPSlider(86, "⬆ Orbit Height: ", 0, 20, Settings.OrbitHeight, function(v) Settings.OrbitHeight = v end)
    createPvPSlider(130, "⚡ Orbit Speed: ", 0.5, 5.0, Settings.OrbitSpeed, function(v) Settings.OrbitSpeed = math.round(v * 10) / 10 end)

    local pvpInfo = Instance.new("TextLabel", pvpTab)
    pvpInfo.Size = UDim2.new(1, -20, 0, 40)
    pvpInfo.Position = UDim2.new(0, 10, 0, 180)
    pvpInfo.BackgroundTransparency = 1
    pvpInfo.Text = "🔹 周回追尾モード (範囲制限付き)\nターゲットの周りを回りながら攻撃します"
    pvpInfo.Font = Enum.Font.Gotham
    pvpInfo.TextSize = 13
    pvpInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
    pvpInfo.TextXAlignment = Enum.TextXAlignment.Left
    pvpInfo.TextYAlignment = Enum.TextYAlignment.Top
    pvpInfo.Parent = pvpTab

    -- ============================================================
    -- ★ Playersタブ (contentFrames[5])
    -- ============================================================
    local playersTab = Instance.new("Frame", contentContainer)
    playersTab.Size = UDim2.new(1, 0, 0, 320)
    playersTab.BackgroundTransparency = 1
    playersTab.Visible = false
    playersTab.Parent = contentContainer
    contentFrames[5] = playersTab

    local playersTitle = Instance.new("TextLabel", playersTab)
    playersTitle.Size = UDim2.new(1, 0, 0, 24)
    playersTitle.Position = UDim2.new(0, 0, 0, 0)
    playersTitle.BackgroundTransparency = 1
    playersTitle.Text = "👥 プレイヤーメニュー"
    playersTitle.Font = Enum.Font.GothamBold
    playersTitle.TextSize = 15
    playersTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    playersTitle.TextXAlignment = Enum.TextXAlignment.Left
    playersTitle.Parent = playersTab

    local playerDropdown = Instance.new("TextBox", playersTab)
    playerDropdown.Size = UDim2.new(1, -10, 0, 28)
    playerDropdown.Position = UDim2.new(0, 5, 0, 28)
    playerDropdown.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    playerDropdown.PlaceholderText = "プレイヤー名を入力..."
    playerDropdown.Font = Enum.Font.Gotham
    playerDropdown.TextSize = 13
    playerDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerDropdown.ClearTextOnFocus = false
    Instance.new("UICorner", playerDropdown).CornerRadius = UDim.new(0, 4)
    playerDropdown.Parent = playersTab
    playerDropdown.FocusLost:Connect(function()
        local name = playerDropdown.Text
        if name and name ~= "" then
            local plr = Players:FindFirstChild(name)
            if plr then
                selectedPlayer = plr
                game:GetService("StarterGui"):SetCore("SendNotification", {Title = "✅ 選択", Text = "ターゲット: " .. plr.Name, Duration = 2})
            else
                game:GetService("StarterGui"):SetCore("SendNotification", {Title = "❌ エラー", Text = "プレイヤーが見つかりません", Duration = 2})
            end
        end
    end)

    local refreshBtn = Instance.new("TextButton", playersTab)
    refreshBtn.Size = UDim2.new(0.4, 0, 0, 24)
    refreshBtn.Position = UDim2.new(0.5, -5, 0, 60)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    refreshBtn.Text = "🔄 リスト更新"
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)
    refreshBtn.Parent = playersTab
    refreshBtn.MouseButton1Click:Connect(function()
        local list = ""
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                list = list .. plr.Name .. ", "
            end
        end
        if list == "" then list = "（プレイヤーなし）" end
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "📋 プレイヤー一覧", Text = list, Duration = 5})
    end)
    refreshBtn.TouchTap:Connect(function()
        local list = ""
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                list = list .. plr.Name .. ", "
            end
        end
        if list == "" then list = "（プレイヤーなし）" end
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "📋 プレイヤー一覧", Text = list, Duration = 5})
    end)

    -- ===== ESP セクション =====
    local espSection = Instance.new("TextLabel", playersTab)
    espSection.Size = UDim2.new(1, 0, 0, 20)
    espSection.Position = UDim2.new(0, 0, 0, 92)
    espSection.BackgroundTransparency = 1
    espSection.Text = "--- ESP ---"
    espSection.Font = Enum.Font.GothamBold
    espSection.TextSize = 13
    espSection.TextColor3 = Color3.fromRGB(255, 255, 255)
    espSection.TextXAlignment = Enum.TextXAlignment.Center
    espSection.Parent = playersTab

    local function createESPToggle(y, text, settingKey)
        local label = Instance.new("TextLabel", playersTab)
        label.Size = UDim2.new(0.6, 0, 0, 22)
        label.Position = UDim2.new(0, 5, 0, y)
        label.BackgroundTransparency = 1
        label.Text = text
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = playersTab

        local btn = Instance.new("TextButton", playersTab)
        btn.Size = UDim2.new(0.3, 0, 0, 22)
        btn.Position = UDim2.new(0.65, 0, 0, y)
        btn.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
        btn.Text = Settings[settingKey] and "ON" or "OFF"
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.Parent = playersTab
        btn.MouseButton1Click:Connect(function()
            Settings[settingKey] = not Settings[settingKey]
            btn.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
            btn.Text = Settings[settingKey] and "ON" or "OFF"
            if Settings[settingKey] then startESP() else updateESP() end
        end)
        btn.TouchTap:Connect(function()
            Settings[settingKey] = not Settings[settingKey]
            btn.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
            btn.Text = Settings[settingKey] and "ON" or "OFF"
            if Settings[settingKey] then startESP() else updateESP() end
        end)
    end

    createESPToggle(116, "🏷️ ラベルESP", "LabelESP")
    createESPToggle(142, "📏 トレーサーESP", "TracerESP")
    createESPToggle(168, "📦 Hitbox ESP", "HitboxESP")

    -- ===== Movement セクション =====
    local moveSection = Instance.new("TextLabel", playersTab)
    moveSection.Size = UDim2.new(1, 0, 0, 20)
    moveSection.Position = UDim2.new(0, 0, 0, 196)
    moveSection.BackgroundTransparency = 1
    moveSection.Text = "--- 移動設定 ---"
    moveSection.Font = Enum.Font.GothamBold
    moveSection.TextSize = 13
    moveSection.TextColor3 = Color3.fromRGB(255, 255, 255)
    moveSection.TextXAlignment = Enum.TextXAlignment.Center
    moveSection.Parent = playersTab

    -- TPWall トグル
    local tpwallLabel = Instance.new("TextLabel", playersTab)
    tpwallLabel.Size = UDim2.new(0.6, 0, 0, 22)
    tpwallLabel.Position = UDim2.new(0, 5, 0, 220)
    tpwallLabel.BackgroundTransparency = 1
    tpwallLabel.Text = "🧱 TPWall (壁抜け)"
    tpwallLabel.Font = Enum.Font.Gotham
    tpwallLabel.TextSize = 13
    tpwallLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    tpwallLabel.TextXAlignment = Enum.TextXAlignment.Left
    tpwallLabel.Parent = playersTab

    local tpwallBtn = Instance.new("TextButton", playersTab)
    tpwallBtn.Size = UDim2.new(0.3, 0, 0, 22)
    tpwallBtn.Position = UDim2.new(0.65, 0, 0, 220)
    tpwallBtn.BackgroundColor3 = Settings.TPWall and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
    tpwallBtn.Text = Settings.TPWall and "ON" or "OFF"
    tpwallBtn.Font = Enum.Font.GothamBold
    tpwallBtn.TextSize = 12
    tpwallBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", tpwallBtn).CornerRadius = UDim.new(0, 4)
    tpwallBtn.Parent = playersTab
    tpwallBtn.MouseButton1Click:Connect(function()
        toggleTPWall(not Settings.TPWall)
        tpwallBtn.BackgroundColor3 = Settings.TPWall and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
        tpwallBtn.Text = Settings.TPWall and "ON" or "OFF"
    end)
    tpwallBtn.TouchTap:Connect(function()
        toggleTPWall(not Settings.TPWall)
        tpwallBtn.BackgroundColor3 = Settings.TPWall and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
        tpwallBtn.Text = Settings.TPWall and "ON" or "OFF"
    end)

    -- ★ スピード調整 (TPWalk速度)
    local speedMoveLabel = Instance.new("TextLabel", playersTab)
    speedMoveLabel.Size = UDim2.new(0.55, 0, 0, 22)
    speedMoveLabel.Position = UDim2.new(0, 5, 0, 248)
    speedMoveLabel.BackgroundTransparency = 1
    speedMoveLabel.Text = "🏃 TPWalk: " .. Settings.SpeedValue
    speedMoveLabel.Font = Enum.Font.Gotham
    speedMoveLabel.TextSize = 13
    speedMoveLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    speedMoveLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedMoveLabel.Parent = playersTab
    speedMoveLabel.Name = "SpeedMoveLabel"

    local speedMoveBox = Instance.new("TextBox", playersTab)
    speedMoveBox.Size = UDim2.new(0.25, 0, 0, 22)
    speedMoveBox.Position = UDim2.new(0.7, 0, 0, 248)
    speedMoveBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    speedMoveBox.Text = tostring(Settings.SpeedValue)
    speedMoveBox.Font = Enum.Font.GothamBold
    speedMoveBox.TextSize = 13
    speedMoveBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    speedMoveBox.ClearTextOnFocus = false
    Instance.new("UICorner", speedMoveBox).CornerRadius = UDim.new(0, 4)
    speedMoveBox.Parent = playersTab
    speedMoveBox.FocusLost:Connect(function()
        local val = tonumber(speedMoveBox.Text)
        if val then
            Settings.SpeedValue = val
            speedMoveBox.Text = tostring(Settings.SpeedValue)
            speedMoveLabel.Text = "🏃 TPWalk: " .. Settings.SpeedValue
            applyMovement()
        else
            speedMoveBox.Text = tostring(Settings.SpeedValue)
        end
    end)

    -- ジャンプパワー調整
    local jumpMoveLabel = Instance.new("TextLabel", playersTab)
    jumpMoveLabel.Size = UDim2.new(0.55, 0, 0, 22)
    jumpMoveLabel.Position = UDim2.new(0, 5, 0, 276)
    jumpMoveLabel.BackgroundTransparency = 1
    jumpMoveLabel.Text = "🦘 ジャンプ: " .. Settings.JumpPowerValue
    jumpMoveLabel.Font = Enum.Font.Gotham
    jumpMoveLabel.TextSize = 13
    jumpMoveLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    jumpMoveLabel.TextXAlignment = Enum.TextXAlignment.Left
    jumpMoveLabel.Parent = playersTab
    jumpMoveLabel.Name = "JumpMoveLabel"

    local jumpMoveBox = Instance.new("TextBox", playersTab)
    jumpMoveBox.Size = UDim2.new(0.25, 0, 0, 22)
    jumpMoveBox.Position = UDim2.new(0.7, 0, 0, 276)
    jumpMoveBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    jumpMoveBox.Text = tostring(Settings.JumpPowerValue)
    jumpMoveBox.Font = Enum.Font.GothamBold
    jumpMoveBox.TextSize = 13
    jumpMoveBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    jumpMoveBox.ClearTextOnFocus = false
    Instance.new("UICorner", jumpMoveBox).CornerRadius = UDim.new(0, 4)
    jumpMoveBox.Parent = playersTab
    jumpMoveBox.FocusLost:Connect(function()
        local val = tonumber(jumpMoveBox.Text)
        if val then
            Settings.JumpPowerValue = val
            jumpMoveBox.Text = tostring(Settings.JumpPowerValue)
            jumpMoveLabel.Text = "🦘 ジャンプ: " .. Settings.JumpPowerValue
            applyMovement()
        else
            jumpMoveBox.Text = tostring(Settings.JumpPowerValue)
        end
    end)

    -- ============================================================
    -- ★ Settingsタブ (contentFrames[6])
    -- ============================================================
    local settingsTab = Instance.new("Frame", contentContainer)
    settingsTab.Size = UDim2.new(1, 0, 0, 220)
    settingsTab.BackgroundTransparency = 1
    settingsTab.Visible = false
    settingsTab.Parent = contentContainer
    contentFrames[6] = settingsTab

    local function createSettingButton(parent, y, text, callback)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(1, -10, 0, 36)
        btn.Position = UDim2.new(0, 5, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        btn.Text = text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
        btn.Parent = parent
        btn.MouseButton1Click:Connect(callback)
        btn.TouchTap:Connect(callback)
        return btn
    end

    local plyBtn = createSettingButton(settingsTab, 5, "🚫 プレイヤーを無視", function()
        Settings.IgnorePlayers = not Settings.IgnorePlayers
        plyBtn.BackgroundColor3 = Settings.IgnorePlayers and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
        plyBtn.Text = Settings.IgnorePlayers and "✅ プレイヤーを無視" or "🚫 プレイヤーを無視"
    end)
    if Settings.IgnorePlayers then plyBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120); plyBtn.Text = "✅ プレイヤーを無視" end

    local npcBtn = createSettingButton(settingsTab, 46, "🚫 NPCを無視", function()
        Settings.IgnoreNPC = not Settings.IgnoreNPC
        npcBtn.BackgroundColor3 = Settings.IgnoreNPC and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
        npcBtn.Text = Settings.IgnoreNPC and "✅ NPCを無視" or "🚫 NPCを無視"
    end)
    if Settings.IgnoreNPC then npcBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120); npcBtn.Text = "✅ NPCを無視" end

    local animBtn = createSettingButton(settingsTab, 87, "🔇 攻撃アニメーション抑制: ON", function()
        Settings.DisableAttackAnim = not Settings.DisableAttackAnim
        animBtn.BackgroundColor3 = Settings.DisableAttackAnim and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(35, 35, 35)
        animBtn.Text = Settings.DisableAttackAnim and "🔇 攻撃アニメーション抑制: ON" or "🔊 攻撃アニメーション抑制: OFF"
    end)
    if not Settings.DisableAttackAnim then animBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35); animBtn.Text = "🔊 攻撃アニメーション抑制: OFF" end

    local rescanBtn = createSettingButton(settingsTab, 128, "🔄 リモート再検出", function()
        findAllRemotes()
        updateRemoteStatus()
        remoteStatusLabel.Text = "Hit:✅ Att:✅ Mel:✅ Swd:✅"
    end)

    remoteStatusLabel = Instance.new("TextLabel", settingsTab)
    remoteStatusLabel.Size = UDim2.new(1, -10, 0, 20)
    remoteStatusLabel.Position = UDim2.new(0, 5, 0, 170)
    remoteStatusLabel.BackgroundTransparency = 1
    remoteStatusLabel.Text = "Hit:✅ Att:✅ Mel:✅ Swd:✅"
    remoteStatusLabel.Font = Enum.Font.Gotham
    remoteStatusLabel.TextSize = 13
    remoteStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    remoteStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    remoteStatusLabel.Parent = settingsTab
    remoteStatusLabel.Name = "RemoteStatusLabel"

    return screenGui
end

-- ============================================================
-- ★ 起動時処理
-- ============================================================
createUI()
updateRemoteStatus()
applyMovement()
startESP()
refreshFruitRemotes()

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Attack Aura Hub v20 (モバイル対応版)",
        Text = "UIのSTARTボタンでAuraを切り替えてください",
        Duration = 6
    })
end)

print("==========================================")
print("✅ Attack Aura Hub Loaded! (Monotone UI)")
print("==========================================")
