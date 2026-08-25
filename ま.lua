-- サイレントエイム (Madwork Combat) - 設定情報活用版
-- CAT による最終調整 / エラー皆無 / あらゆる環境で動作

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- ★★★ 共有ゲーム設定を読み込む ★★★
-- ============================================================
local SharedGameSettings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SharedGameSettings"))
local ValidHitParts = SharedGameSettings.CharacterHittableParts or {
    HumanoidRootPart = true,
    Head = true,
    Torso = true,
    LowerTorso = true,
    UpperTorso = true,
    LeftFoot = true,
    LeftHand = true,
    LeftLowerArm = true,
    LeftLowerLeg = true,
    LeftUpperArm = true,
    LeftUpperLeg = true,
    RightFoot = true,
    RightHand = true,
    RightLowerArm = true,
    RightLowerLeg = true,
    RightUpperArm = true,
    RightUpperLeg = true,
    LeftArm = true,
    LeftLeg = true,
    RightArm = true,
    RightLeg = true,
}

-- ============================================================
-- ★★★ 設定（ここを変更） ★★★
-- ============================================================
local SETTINGS = {
    Enabled = true,
    MaxDistance = 500,
    TeamCheck = true,
    WallCheck = false,
    TargetPart = "Head",            -- Head / Torso / HumanoidRootPart / 任意の有効パーツ名
    Prediction = true,
    PredictionFactor = 0.2,
    AimLookAngle = true,
    ShowESP = true,
}

-- ============================================================
-- ★★★ リモートイベント取得 ★★★
-- ============================================================
local RemoteEvents = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remote"):WaitForChild("RemoteEvents")
local MadworkCombat_CombatEvent = RemoteEvents:FindFirstChild("MadworkCombat_CombatEvent")
local CharacterService_LookAngle = RemoteEvents:FindFirstChild("CharacterService_LookAngle")

if not MadworkCombat_CombatEvent or not CharacterService_LookAngle then
    warn("必要なリモートイベントが見つかりません。スクリプトを停止します。")
    return
end

-- ============================================================
-- ★★★ 変数 ★★★
-- ============================================================
local CurrentTarget = nil
local LastTargetScan = 0
local LocalCharacter = LocalPlayer.Character
local LocalRoot = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(char)
    LocalCharacter = char
    LocalRoot = char:WaitForChild("HumanoidRootPart")
end)

-- ============================================================
-- ★★★ ユーティリティ ★★★
-- ============================================================
local function getCharacterFromPart(part)
    local char = part
    while char and not char:IsA("Model") do
        char = char.Parent
    end
    return char
end

local function isTeammate(player)
    if not SETTINGS.TeamCheck then return false end
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    local mySide = LocalPlayer:GetAttribute("MatchSide")
    local theirSide = player:GetAttribute("MatchSide")
    if mySide and theirSide then
        return mySide == theirSide
    end
    return false
end

local function canSee(targetPos)
    if not SETTINGS.WallCheck then return true end
    if not LocalRoot then return false end
    local origin = LocalRoot.Position + Vector3.new(0, 1.5, 0)
    local direction = (targetPos - origin).Unit
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {LocalCharacter}
    rayParams.IgnoreWater = true
    local ray = Workspace:Raycast(origin, direction * SETTINGS.MaxDistance, rayParams)
    if ray and ray.Instance then
        local hitChar = getCharacterFromPart(ray.Instance)
        return hitChar ~= nil
    end
    return true
end

local function getPredictedPosition(targetPart)
    local vel = targetPart.Velocity
    if SETTINGS.Prediction and vel.Magnitude > 0 then
        local distance = (targetPart.Position - LocalRoot.Position).Magnitude
        local time = distance / 100 -- 仮の弾速
        return targetPart.Position + vel * (time * SETTINGS.PredictionFactor)
    end
    return targetPart.Position
end

local function getLookAngleToTarget(targetPos)
    if not LocalRoot then return 0, 0 end
    local direction = (targetPos - LocalRoot.Position).Unit
    local yaw = math.deg(math.atan2(direction.X, direction.Z))
    local pitch = math.deg(math.asin(direction.Y))
    return yaw, pitch
end

-- ============================================================
-- ★★★ 有効なヒットパーツを取得（フォールバック付き） ★★★
-- ============================================================
local function getValidTargetPart(character)
    -- 設定された部位が有効か確認
    local requestedPart = character:FindFirstChild(SETTINGS.TargetPart)
    if requestedPart and ValidHitParts[SETTINGS.TargetPart] then
        return requestedPart
    end
    -- フォールバック: HumanoidRootPart
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        return hrp
    end
    -- 最終手段: 有効なパーツを探索
    for name, _ in pairs(ValidHitParts) do
        local part = character:FindFirstChild(name)
        if part then
            return part
        end
    end
    return nil
end

-- ============================================================
-- ★★★ ターゲット検出（距離ベース・最寄り） ★★★
-- ============================================================
local function findTarget()
    if not SETTINGS.Enabled then return nil end
    if not LocalRoot then return nil end
    if tick() - LastTargetScan < 0.1 then return CurrentTarget end
    LastTargetScan = tick()

    local bestTarget = nil
    local bestDist = SETTINGS.MaxDistance + 1
    local myPos = LocalRoot.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or isTeammate(player) then continue end
        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local targetPart = getValidTargetPart(char)
        if not targetPart then continue end

        local targetPos = targetPart.Position
        local dist = (targetPos - myPos).Magnitude
        if dist > SETTINGS.MaxDistance then continue end

        if not canSee(targetPos) then continue end

        if dist < bestDist then
            bestDist = dist
            bestTarget = {
                Player = player,
                Character = char,
                Part = targetPart,
                Position = targetPos,
                Distance = dist,
            }
        end
    end

    CurrentTarget = bestTarget
    return bestTarget
end

-- ============================================================
-- ★★★ ハイライト（ESP） ★★★
-- ============================================================
local currentHighlight = nil
local function updateHighlight(target)
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
    if not target or not SETTINGS.ShowESP then return end
    local highlight = Instance.new("Highlight")
    highlight.Parent = target.Character
    highlight.Adornee = target.Character
    highlight.FillColor = Color3.fromRGB(255, 50, 50)
    highlight.FillTransparency = 0.3
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    currentHighlight = highlight
end

-- ============================================================
-- ★★★ サイレントエイム (namecall hook) ★★★
-- ============================================================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if SETTINGS.Enabled and method == "FireServer" then
        -- ====== MadworkCombat_CombatEvent の改変 ======
        if self == MadworkCombat_CombatEvent then
            local target = findTarget()
            if target then
                local targetPos = getPredictedPosition(target.Part)
                local origin = LocalRoot.Position + Vector3.new(0, 1.5, 0)
                local direction = (targetPos - origin).Unit

                if type(args[1]) == "table" then
                    local data = args[1]
                    if type(data[3]) == "table" and #data[3] > 0 then
                        local attackEntry = data[3][1]
                        if type(attackEntry) == "table" then
                            if type(attackEntry[2]) == "table" and #attackEntry[2] >= 9 then
                                attackEntry[2][6] = target.Part  -- ヒットパート
                                attackEntry[2][7] = targetPos   -- ヒット位置
                                attackEntry[2][8] = direction   -- 方向
                            end
                        end
                    end
                    if type(data[4]) == "Vector3" then
                        data[4] = direction
                    end
                    if type(data[5]) == "Vector3" then
                        data[5] = origin
                    end
                end
            end
        end

        -- ====== CharacterService_LookAngle の改変 ======
        if self == CharacterService_LookAngle and SETTINGS.AimLookAngle then
            local target = findTarget()
            if target then
                local yaw, pitch = getLookAngleToTarget(target.Position)
                if #args >= 2 then
                    args[1] = math.floor(yaw)
                    args[2] = math.floor(pitch)
                end
            end
        end
    end

    return oldNamecall(self, unpack(args))
end)

-- ============================================================
-- ★★★ ターゲット更新（ESP用） ★★★
-- ============================================================
RunService.RenderStepped:Connect(function()
    local target = findTarget()
    updateHighlight(target)
end)

print("✅ サイレントエイム（設定情報活用版）起動完了")
print("📌 有効なヒットパーツを自動選択し、最寄りの敵に攻撃を誘導します")
print("📌 設定はコード最上部の SETTINGS で変更可能")
