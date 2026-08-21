-- 殺人決闘 手動＋自動 サイレントエイム（壁貫通常時ON・武器別クールダウン）
-- Delta Executor 対応 / 主様専用

-- ★ 既存の競合スクリプトを停止
for _, v in pairs(getconnections(game:GetService("RunService").RenderStepped)) do
    if v.Function and string.find(debug.getinfo(v.Function).source or "", "Noob") then
        v:Disable()
    end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ★ キャッシュ
local character = LocalPlayer.Character
local characterRoot = character and character:FindFirstChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    characterRoot = newChar and newChar:FindFirstChild("HumanoidRootPart")
end)

-- ============================================================
-- ★★★ マッチングキャンセル・ブロック 自動無効化 ★★★
-- ============================================================
local blockedRemotes = {}
local function autoBlockCancellers()
    print("🔍 マッチングキャンセル/ブロックリモートをスキャン中...")
    local function processObject(obj)
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local name = obj.Name:lower()
            local keywords = {"cancel", "leave", "abort", "stop", "unqueue", "block", "ban", "kick"}
            local shouldBlock = false
            for _, kw in ipairs(keywords) do
                if name:find(kw) then shouldBlock = true; break end
            end
            if shouldBlock and not blockedRemotes[obj] then
                blockedRemotes[obj] = true
                pcall(function()
                    if obj:IsA("RemoteEvent") then
                        local oldFire = obj.FireServer
                        if oldFire then
                            obj.FireServer = function(self, ...)
                                print("🚫 キャンセルリモートをブロック:", obj.Name)
                                return
                            end
                        end
                    elseif obj:IsA("RemoteFunction") then
                        local oldInvoke = obj.InvokeServer
                        if oldInvoke then
                            obj.InvokeServer = function(self, ...)
                                print("🚫 キャンセル関数をブロック:", obj.Name)
                                return nil
                            end
                        end
                    end
                end)
            end
        end
        for _, child in ipairs(obj:GetChildren()) do processObject(child) end
    end
    processObject(ReplicatedStorage)
    print("✅ キャンセル/ブロックリモートの無効化完了（", #blockedRemotes, "個）")
end
autoBlockCancellers()

-- ============================================================
-- ★★★ 設定 ★★★
-- ============================================================
local SETTINGS = {
    AttackMode = "FOV",                -- "FOV" または "Nearest"
    FOV_Degrees = 80,
    MaxDistance = 300,
    -- ★ 射撃モード切り替え
    AutoShoot = false,                 -- ★ true=完全自動, false=手動（自分でクリック）
    -- ★ 射撃用クールダウン（自動時のみ有効）
    ShootInterval = 0.08,
    ShootRandomDelay = 0.02,
    -- ★ ナイフ用クールダウン（自動時のみ有効）
    KnifeInterval = 0.5,
    KnifeRandomDelay = 0.05,
    -- 部位設定
    HeadshotRate = 0.5,
    -- その他
    TeamCheck = true,
    Wallbang = true,                   -- ★ 常時ON
    ShowESP = true,
    ShowFOVCircle = true,
    AutoMatchmaking = true,
    MatchmakingModes = {"1v1", "2v2", "3v3", "4v4"},
    MatchmakingRetryInterval = 3,
}

SETTINGS.Wallbang = true

-- 安全ガード
if SETTINGS.ShootInterval < 0.03 then SETTINGS.ShootInterval = 0.03 end
if SETTINGS.KnifeInterval < 0.3 then SETTINGS.KnifeInterval = 0.3 end

-- ============================================================
-- ★★★ リモート取得 ★★★
-- ============================================================
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local shootRemote = remotes and remotes:FindFirstChild("ShootReplicate")
local throwRemote = remotes and remotes:FindFirstChild("ThrowReplicate")
local reportHitRemote = remotes and remotes:FindFirstChild("ReportHit")

local matchmakingShared = ReplicatedStorage:FindFirstChild("MatchmakingShared")
local queueModes = matchmakingShared and matchmakingShared:FindFirstChild("Remotes") and 
                   matchmakingShared.Remotes:FindFirstChild("QueueModes")

if not shootRemote then warn("ShootReplicate が見つかりません（射撃不可）") end
if not throwRemote or not reportHitRemote then warn("ThrowReplicate/ReportHit が見つかりません（ナイフ不可）") end
if not queueModes then warn("QueueModes が見つかりません。強制マッチング機能は無効です") end

local shotId = 0
local throwId = 0
local lastTarget = nil
local lastTargetTime = 0
local isMatchmaking = false

-- ============================================================
-- ★★★ 武器判定 ★★★
-- ============================================================
local function getCurrentWeapon()
    if not character then return nil end
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            return tool
        end
    end
    return nil
end

local function isKnifeEquipped()
    local tool = getCurrentWeapon()
    return tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("ナイフ"))
end

-- ============================================================
-- ★★★ 強制マッチング機能 ★★★
-- ============================================================
local function forceMatchmaking()
    if not queueModes or isMatchmaking then return end
    isMatchmaking = true
    print("🔄 強制マッチング開始...")
    local success, result = pcall(function()
        return queueModes:InvokeServer(SETTINGS.MatchmakingModes)
    end)
    if success then
        print("✅ マッチングキューイング成功:", result)
    else
        print("❌ マッチングキューイング失敗:", result)
        isMatchmaking = false
        task.delay(1, function()
            isMatchmaking = false
            if SETTINGS.AutoMatchmaking then forceMatchmaking() end
        end)
    end
end

-- 属性監視
if LocalPlayer then
    LocalPlayer:GetAttributeChangedSignal("LobbySpectateMatchId"):Connect(function()
        local id = LocalPlayer:GetAttribute("LobbySpectateMatchId")
        if (not id or id == "") then
            print("⚠️ マッチングキャンセルを検出！（属性変化）")
            isMatchmaking = false
            if SETTINGS.AutoMatchmaking then
                task.wait(0.5)
                forceMatchmaking()
            end
        else
            print("✅ マッチング成立確認:", id)
            isMatchmaking = true
        end
    end)
end

task.spawn(function()
    while SETTINGS.AutoMatchmaking do
        task.wait(SETTINGS.MatchmakingRetryInterval)
        local lobby = LocalPlayer:GetAttribute("LobbySpectateMatchId")
        if (not lobby or lobby == "") and not isMatchmaking then
            print("⚠️ マッチングキャンセルを検出！（定期チェック）")
            forceMatchmaking()
        end
    end
end)

if SETTINGS.AutoMatchmaking and queueModes then
    task.wait(1.5)
    forceMatchmaking()
end

-- ============================================================
-- ★★★ FOV円 ★★★
-- ============================================================
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.Color = Color3.fromRGB(0, 255, 255)
fovCircle.Transparency = 0.5
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Visible = false

local function updateFOVCircle()
    if not SETTINGS.ShowFOVCircle then
        fovCircle.Visible = false
        return
    end
    local viewSize = Camera.ViewportSize
    local centerX = viewSize.X / 2
    local centerY = viewSize.Y / 2
    fovCircle.Position = Vector2.new(centerX, centerY)
    local camFOV = Camera.FieldOfView
    local radius = math.tan(math.rad(SETTINGS.FOV_Degrees) / 2) * (viewSize.Y / 2) / math.tan(math.rad(camFOV) / 2)
    fovCircle.Radius = math.clamp(radius, 10, viewSize.Y * 0.8)
    fovCircle.Visible = true
end
pcall(updateFOVCircle)

-- ============================================================
-- ★★★ 敵対判定 ★★★
-- ============================================================
local myTeam = LocalPlayer.Team
local mySide = LocalPlayer:GetAttribute("MatchSide")

local function isEnemy(player)
    if player == LocalPlayer then return false end
    if not SETTINGS.TeamCheck then return true end
    local pTeam = player.Team
    local pSide = player:GetAttribute("MatchSide")
    if myTeam and pTeam then return myTeam ~= pTeam end
    if mySide and pSide then return mySide ~= pSide end
    return true
end

-- ============================================================
-- ★★★ ターゲット検出（壁貫通常時ON） ★★★
-- ============================================================
local function findTarget()
    if not characterRoot then return nil end
    local camPos = Camera.CFrame.Position
    local camLook = Camera.CFrame.LookVector
    local pos = characterRoot.Position

    local bestTarget = nil
    local bestDist = SETTINGS.MaxDistance + 1

    local charactersFolder = Workspace:FindFirstChild("Characters")
    local playerList = charactersFolder and charactersFolder:GetChildren() or Players:GetPlayers()

    for _, item in ipairs(playerList) do
        local player, char
        if charactersFolder then
            char = item
            if char == character then continue end
            if not char:IsA("Model") then continue end
            player = Players:GetPlayerFromCharacter(char)
            if not player then continue end
        else
            player = item
            if player == LocalPlayer then continue end
            char = player.Character
            if not char then continue end
        end

        if not isEnemy(player) then continue end
        local hum = char:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local targetRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not targetRoot or not targetRoot:IsA("BasePart") then continue end

        local targetPos = targetRoot.Position
        local dist = (targetPos - pos).Magnitude
        if dist > SETTINGS.MaxDistance then continue end

        -- ★ 壁貫通チェックなし（常にスキップ）
        local dirToTarget = (targetPos - camPos).Unit
        local angle = math.deg(math.acos(math.clamp(camLook:Dot(dirToTarget), -1, 1)))
        if SETTINGS.AttackMode == "FOV" and angle > SETTINGS.FOV_Degrees then continue end

        if dist < bestDist then
            bestDist = dist
            local headPart = char:FindFirstChild("Head") or char:FindFirstChild("head") or targetRoot
            bestTarget = {
                Model = char,
                Head = headPart,
                Position = targetPos,
                Distance = dist,
                Angle = angle,
                Name = player.Name,
                Player = player,
            }
        end
    end

    return bestTarget
end

-- ============================================================
-- ★★★ ハイライト ★★★
-- ============================================================
local currentHighlight = nil
local function highlightTarget(targetModel)
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
    if not targetModel then return end
    local highlight = Instance.new("Highlight")
    highlight.Parent = targetModel
    highlight.Adornee = targetModel
    highlight.FillColor = Color3.fromRGB(255, 50, 50)
    highlight.FillTransparency = 0.3
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.1
    currentHighlight = highlight
end

-- ============================================================
-- ★★★ 射撃攻撃送信（手動・自動兼用） ★★★
-- ============================================================
local function sendShootAttack(target)
    if not target or not target.Head then return end
    if not shootRemote then return end

    local now = tick()
    if lastTarget == target.Model and now - lastTargetTime < 0.12 then
        return
    end

    lastTarget = target.Model
    lastTargetTime = now
    shotId = shotId + 1

    local origin = characterRoot and characterRoot.Position + Vector3.new(0, 1.5, 0) or Vector3.new(0, 0, 0)
    local isHeadshot = math.random() < SETTINGS.HeadshotRate
    local hitPos = isHeadshot and target.Head.Position or target.Position

    local data = {
        hitPos = hitPos,
        to = hitPos,
        origin = origin,
        id = shotId,
        hitNormal = Vector3.new(0, 1, 0),
        effects = { Frost = 0, Ricochet = 0, Barrage = 0 },
        hitInstance = isHeadshot and target.Head or nil,
        kind = "bullet",
        isCharacterHit = true,
        mode = "single",
        ownerUserId = LocalPlayer.UserId,
        isADS = false
    }

    if shotId % 100 == 0 then
        local part = isHeadshot and "頭" or "体"
        print(string.format("🔫 %s (ID:%d) 距離:%.1fm 部位:%s", target.Name, shotId, target.Distance, part))
    end

    pcall(function() shootRemote:FireServer(data) end)
end

-- ============================================================
-- ★★★ ナイフ攻撃送信（手動・自動兼用） ★★★
-- ============================================================
local function sendKnifeAttack(target)
    if not target or not target.Head then return end
    if not throwRemote or not reportHitRemote then return end

    local now = tick()
    if lastTarget == target.Model and now - lastTargetTime < 0.3 then
        return
    end

    lastTarget = target.Model
    lastTargetTime = now
    throwId = throwId + 1

    local origin = characterRoot and characterRoot.Position + Vector3.new(0, 1.5, 0) or Vector3.new(0, 0, 0)
    local isHeadshot = math.random() < SETTINGS.HeadshotRate
    local hitPos = isHeadshot and target.Head.Position or target.Position

    local throwData = {
        toolName = "Knife",
        id = throwId,
        ownerUserId = LocalPlayer.UserId,
        origin = origin,
        isExplosive = false,
        power = 1,
        target = hitPos,
        effects = {
            Shotgun = 0,
            Portal = 0,
            Smoke = 0,
            Explosive = 0,
            Flammable = 0
        }
    }

    local vel = (hitPos - origin).Unit * 400
    local reportData = {
        hitPos = hitPos,
        ownerUserId = LocalPlayer.UserId,
        origin = origin,
        vel = vel,
        headshot = isHeadshot,
        targetUserId = target.Player and target.Player.UserId or 0,
        targetModel = target.Model,
        to = hitPos + Vector3.new(0, 0.5, 0),
        throwId = throwId,
        kind = "throw",
        at = 0.5,
        hitPart = isHeadshot and target.Head or target.Model:FindFirstChild("Torso") or target.Head,
    }

    pcall(function()
        throwRemote:FireServer(throwData)
        task.wait(0.02)
        reportHitRemote:FireServer(reportData)
    end)

    if throwId % 20 == 0 then
        local part = isHeadshot and "頭" or "体"
        print(string.format("🔪 %s (ThrowID:%d) 距離:%.1fm 部位:%s", target.Name, throwId, target.Distance, part))
    end
end

-- ============================================================
-- ★★★ 統合攻撃送信（武器に応じて切り替え） ★★★
-- ============================================================
local function sendAttack(target)
    if not target then return end
    if isKnifeEquipped() then
        sendKnifeAttack(target)
    else
        sendShootAttack(target)
    end
end

-- ============================================================
-- ★★★ 手動射撃検知（マウス左クリック） ★★★
-- ============================================================
local function onInputBegan(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if not SETTINGS.AutoShoot then
            -- ★ 手動モード：クリック時にターゲットが居れば攻撃
            local target = findTarget()
            if target then
                highlightTarget(target.Model)
                sendAttack(target)
            else
                if currentHighlight then
                    currentHighlight:Destroy()
                    currentHighlight = nil
                end
            end
        end
    end
end

UserInputService.InputBegan:Connect(onInputBegan)

-- ============================================================
-- ★★★ ESP ★★★
-- ============================================================
local function createESP(player)
    if player == LocalPlayer or not SETTINGS.ShowESP then return end

    local function setupCharacter(char)
        local head = char:FindFirstChild("Head")
        if not head then return end
        if char:FindFirstChild("PlayerESP_Box") then return end

        local isEnemyFlag = isEnemy(player)
        local outlineColor = isEnemyFlag and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 150, 255)
        if not SETTINGS.TeamCheck then outlineColor = Color3.fromRGB(255, 255, 255) end

        local hl = Instance.new("Highlight")
        hl.Name = "PlayerESP_Box"
        hl.Adornee = char
        hl.FillTransparency = 1
        hl.OutlineColor = outlineColor
        hl.OutlineTransparency = 0
        hl.Parent = char

        local bill = Instance.new("BillboardGui")
        bill.Name = "PlayerESP_Label"
        bill.AlwaysOnTop = true
        bill.Size = UDim2.new(0, 150, 0, 30)
        bill.StudsOffset = Vector3.new(0, 2.5, 0)

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = player.Name .. (isEnemyFlag and " ⚔️" or " 🤝")
        txt.TextColor3 = isEnemyFlag and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 200, 255)
        txt.TextStrokeTransparency = 0
        txt.TextSize = 14
        txt.Font = Enum.Font.SourceSansBold
        txt.Parent = bill
        bill.Parent = head
    end

    if player.Character then task.spawn(setupCharacter, player.Character) end
    player.CharacterAdded:Connect(setupCharacter)
end

if SETTINGS.ShowESP then
    for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
    Players.PlayerAdded:Connect(createESP)
end

-- ============================================================
-- ★★★ 自動射撃ループ（AutoShoot = true 時のみ動作） ★★★
-- ============================================================
if SETTINGS.AutoShoot then
    local lastAttackTime = 0
    RunService.RenderStepped:Connect(function()
        pcall(updateFOVCircle)

        local target = findTarget()
        if target then
            highlightTarget(target.Model)

            local interval, randomDelay
            if isKnifeEquipped() then
                interval = SETTINGS.KnifeInterval
                randomDelay = SETTINGS.KnifeRandomDelay
            else
                interval = SETTINGS.ShootInterval
                randomDelay = SETTINGS.ShootRandomDelay
            end

            local delay = interval + math.random(-randomDelay * 1000, randomDelay * 1000) / 1000
            if delay < 0.03 then delay = 0.03 end

            if tick() - lastAttackTime >= delay then
                sendAttack(target)
                lastAttackTime = tick()
            end
        else
            if currentHighlight then
                currentHighlight:Destroy()
                currentHighlight = nil
            end
            lastTarget = nil
            lastTargetTime = 0
        end
    end)
    print("✅ 自動射撃モード ON")
else
    -- ★ 手動モードではFOV円とESPだけ更新
    RunService.RenderStepped:Connect(function()
        pcall(updateFOVCircle)
        -- 手動モードではターゲットハイライトを常時更新（クリック時に反応）
        local target = findTarget()
        if target then
            highlightTarget(target.Model)
        else
            if currentHighlight then
                currentHighlight:Destroy()
                currentHighlight = nil
            end
        end
    end)
    print("✅ 手動射撃モード ON（マウス左クリックでサイレントエイム発動）")
end

print("✅ 手動＋自動 サイレントエイム起動（壁貫通常時ON）")
print("📌 射撃モード: " .. (SETTINGS.AutoShoot and "自動" or "手動（クリックで発動）"))
print("📌 ヘッドショット率: " .. (SETTINGS.HeadshotRate * 100) .. "%")
-- ============================================================
-- ★★★ モバイル最適化ダッシュボードUI（既存ロジック無変更） ★★★
-- ============================================================
local CoreGui = game:GetService("CoreGui")

-- 既存のUIがあれば削除（重複起動防止）
if CoreGui:FindFirstChild("MobileDashboardUI") then
    CoreGui.MobileDashboardUI:Destroy()
end

local DashboardGui = Instance.new("ScreenGui")
DashboardGui.Name = "MobileDashboardUI"
DashboardGui.ResetOnSpawn = false
DashboardGui.Parent = CoreGui

-- 1. 開閉用トグルボタン（左上配置・円形）
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0, 15, 0, 15)
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleButton.Text = "⚙️"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 24
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = DashboardGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0.5, 0)
ToggleCorner.Parent = ToggleButton

-- 2. メインパネル（モバイル対応の相対サイズ）
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0.85, 0, 0.75, 0)
MainFrame.Position = UDim2.new(0.075, 0, 0.125, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Visible = false
MainFrame.ClipsDescendants = true
MainFrame.Parent = DashboardGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

-- 3. タイトル
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundTransparency = 1
Title.Text = " Dashboard UI"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitlePadding = Instance.new("UIPadding")
TitlePadding.PaddingLeft = UDim.new(0, 15)
TitlePadding.Parent = Title

-- 4. スクロール領域
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -55)
ScrollFrame.Position = UDim2.new(0, 10, 0, 45)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.ScrollBarThickness = 5
ScrollFrame.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 10)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ScrollFrame

-- ====== UI要素作成用ヘルパー関数 ======

-- ON/OFF トグルボタン生成
local function CreateToggle(settingName, displayName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 45)
    btn.BackgroundColor3 = SETTINGS[settingName] and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(150, 50, 50)
    btn.Text = displayName .. " : " .. (SETTINGS[settingName] and "ON" or "OFF")
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 15
    btn.Parent = ScrollFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        SETTINGS[settingName] = not SETTINGS[settingName]
        local state = SETTINGS[settingName]
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(150, 50, 50)
        btn.Text = displayName .. " : " .. (state and "ON" or "OFF")
    end)
end

-- モード切り替えボタン生成 (FOV / Nearest など)
local function CreateModeSwitch(settingName, displayName, option1, option2)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 45)
    btn.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
    btn.Text = displayName .. " : " .. tostring(SETTINGS[settingName])
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 15
    btn.Parent = ScrollFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        if SETTINGS[settingName] == option1 then
            SETTINGS[settingName] = option2
        else
            SETTINGS[settingName] = option1
        end
        btn.Text = displayName .. " : " .. tostring(SETTINGS[settingName])
    end)
end

-- 数値入力フィールド生成
local function CreateNumberInput(settingName, displayName)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 45)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    frame.Parent = ScrollFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.55, 0, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = displayName
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.4, 0, 0.7, 0)
    input.Position = UDim2.new(0.55, 0, 0.15, 0)
    input.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    input.Text = tostring(SETTINGS[settingName])
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.Font = Enum.Font.Gotham
    input.TextSize = 14
    input.Parent = frame

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = input

    input.FocusLost:Connect(function()
        local num = tonumber(input.Text)
        if num then
            SETTINGS[settingName] = num
        else
            input.Text = tostring(SETTINGS[settingName]) -- 無効な入力はリセット
        end
    end)
end

-- ====== メニュー要素の配置 ======

-- [スイッチ系]
CreateModeSwitch("AttackMode", "ターゲット優先", "FOV", "Nearest")
CreateToggle("TeamCheck", "チームキル防止 (TeamCheck)")
CreateToggle("ShowESP", "ESP表示 (ShowESP)")
CreateToggle("ShowFOVCircle", "FOV円表示 (ShowFOVCircle)")
CreateToggle("AutoMatchmaking", "自動マッチング (AutoMatch)")

-- [数値設定系]
CreateNumberInput("HeadshotRate", "HS確率 (0.0~1.0)")
CreateNumberInput("FOV_Degrees", "FOV範囲 (Degrees)")
CreateNumberInput("MaxDistance", "最大距離 (Distance)")
CreateNumberInput("ShootInterval", "射撃間隔 (ShootInterval)")
CreateNumberInput("KnifeInterval", "ナイフ間隔 (KnifeInterval)")

-- スクロールサイズを自動調整
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 20)
ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 20)
end)

-- ====== 開閉アニメーション ======
local isOpen = false
ToggleButton.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    MainFrame.Visible = isOpen
    if isOpen then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        ToggleButton.Text = "✖"
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        ToggleButton.Text = "⚙️"
    end
end)
