-- 殺人決闘 射撃＋ナイフ サイレントエイム（壁貫通常時ON・クールダウン変更可）
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
-- ★★★ 設定（クールダウン自由変更） ★★★
-- ============================================================
local SETTINGS = {
    AttackMode = "FOV",
    FOV_Degrees = 150,
    MaxDistance = 1000,
    -- ★ 射撃用クールダウン
    ShootInterval = 0.08,
    ShootRandomDelay = 0.02,
    -- ★ ナイフ用クールダウン（別途設定可能）
    KnifeInterval = 0,
    KnifeRandomDelay = 0,
    -- 部位設定
    HeadshotRate = 1,
    -- その他
    TeamCheck = true,
    Wallbang = true,
    ShowESP = true,
    ShowFOVCircle = true,
    AutoMatchmaking = true,
    MatchmakingModes = {"1v1", "2v2", "3v3", "4v4"},
    MatchmakingRetryInterval = 3,
}

-- ★ 壁貫通強制ON
SETTINGS.Wallbang = true

-- 安全ガード
if SETTINGS.ShootInterval < 0.03 then SETTINGS.ShootInterval = 0.03 end
if SETTINGS.KnifeInterval < 0 then SETTINGS.KnifeInterval = 0 end

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
-- ★★★ ターゲット検出（壁貫通常時ONで高速化） ★★★
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
-- ★★★ 射撃攻撃送信 ★★★
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
-- ★★★ ナイフ攻撃送信（ThrowReplicate + ReportHit） ★★★
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

    -- ★ ThrowReplicate 送信（投擲）
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

    -- ★ ReportHit 送信（ヒット報告）
    local vel = (hitPos - origin).Unit * 400  -- 適当な速度ベクトル
    local reportData = {
        hitPos = hitPos,
        ownerUserId = LocalPlayer.UserId,
        origin = origin,
        vel = vel,
        headshot = isHeadshot,
        targetUserId = target.Player and target.Player.UserId or 0,
        targetModel = target.Model,
        to = hitPos + Vector3.new(0, 0.5, 0),  -- 微調整
        throwId = throwId,
        kind = "throw",
        at = 0.5,
        hitPart = isHeadshot and target.Head or target.Model:FindFirstChild("Torso") or target.Head,
    }

    pcall(function()
        throwRemote:FireServer(throwData)
        task.wait(0.02)  -- 少し間隔を開ける（サーバー負荷対策）
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
-- ★★★ メインループ（武器別クールダウン制御） ★★★
-- ============================================================
local lastAttackTime = 0
RunService.RenderStepped:Connect(function()
    pcall(updateFOVCircle)

    local target = findTarget()
    if target then
        highlightTarget(target.Model)

        -- ★ 武器に応じてクールダウンを切り替え
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

print("✅ 射撃＋ナイフ サイレントエイム起動（壁貫通常時ON）")
print("📌 射撃間隔: " .. SETTINGS.ShootInterval .. "秒（ランダム ±" .. SETTINGS.ShootRandomDelay .. "）")
print("📌 ナイフ間隔: " .. SETTINGS.KnifeInterval .. "秒（ランダム ±" .. SETTINGS.KnifeRandomDelay .. "）")
print("📌 ヘッドショット率: " .. (SETTINGS.HeadshotRate * 100) .. "%")
print("📌 装備中武器を自動判定（ナイフ→投擲、それ以外→射撃）")
