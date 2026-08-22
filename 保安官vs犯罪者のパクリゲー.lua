-- 統合版：タッチモード対応（モバイル最適化）
-- 5スタッド以内は味方（青）、それ以外は敵（赤）
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- =====================================================
-- 0. タッチモード設定
-- =====================================================
local TOUCH_MODE = true  -- trueでモバイルタッチ最適化

-- =====================================================
-- 1. ESP設定
-- =====================================================
local ESP_SETTINGS = {
    ShowBox = true,
    ShowLabel = true,
    FriendlyColor = Color3.fromRGB(0, 150, 255),
    EnemyColor = Color3.fromRGB(255, 0, 0),
    TextColor = Color3.fromRGB(255, 255, 255),
    PROXIMITY_THRESHOLD = 5
}

local function IsProximity(targetPart)
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    local root = myChar:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local dist = (targetPart.Position - root.Position).Magnitude
    return dist <= ESP_SETTINGS.PROXIMITY_THRESHOLD
end

-- =====================================================
-- 2. ESP作成
-- =====================================================
local function createESP(player)
    if player == LocalPlayer then return end

    local function setupCharacter(character)
        local rootPart = character:WaitForChild("HumanoidRootPart", 5)
        local humanoid = character:WaitForChild("Humanoid", 5)
        local head = character:WaitForChild("Head", 5)
        if not rootPart or not humanoid or not head then return end

        local highlight = character:FindFirstChild("ESPHighlight")
        if ESP_SETTINGS.ShowBox and not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "ESPHighlight"
            highlight.Adornee = character
            highlight.FillTransparency = 1
            highlight.OutlineTransparency = 0
            highlight.Parent = character
        end

        local billboard = head:FindFirstChild("ESPBillboard")
        if ESP_SETTINGS.ShowLabel and not billboard then
            billboard = Instance.new("BillboardGui")
            billboard.Name = "ESPBillboard"
            billboard.Size = UDim2.new(0, 100, 0, 50)
            billboard.StudsOffset = Vector3.new(0, 2.5, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = head

            local textLabel = Instance.new("TextLabel")
            textLabel.Name = "ESPText"
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextColor3 = ESP_SETTINGS.TextColor
            textLabel.TextSize = 14
            textLabel.Font = Enum.Font.SourceSansBold
            textLabel.TextStrokeTransparency = 0
            textLabel.Parent = billboard

            local connection
            connection = RunService.RenderStepped:Connect(function()
                if not character or not character.Parent or humanoid.Health <= 0 then
                    if connection then connection:Disconnect() end
                    return
                end

                local isFriendly = IsProximity(rootPart)
                local boxColor = isFriendly and ESP_SETTINGS.FriendlyColor or ESP_SETTINGS.EnemyColor

                if highlight then
                    highlight.OutlineColor = boxColor
                    highlight.Enabled = true
                end

                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude)
                    local label = (isFriendly and "[味方] " or "[敵] ") .. player.Name .. "\n[" .. distance .. "m]"
                    textLabel.Text = label
                    textLabel.TextColor3 = isFriendly and ESP_SETTINGS.FriendlyColor or ESP_SETTINGS.EnemyColor
                end
            end)
        end
    end

    if player.Character then
        task.spawn(function() setupCharacter(player.Character) end)
    end
    player.CharacterAdded:Connect(function(newCharacter)
        task.spawn(function() setupCharacter(newCharacter) end)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    createESP(player)
end
Players.PlayerAdded:Connect(createESP)

-- =====================================================
-- 3. リモート取得
-- =====================================================
local function GetNil(Name, DebugId)
    for _, Object in getnilinstances() do
        if Object.Name == Name and Object:GetDebugId() == DebugId then
            return Object
        end
    end
end

local function FindRemoteByName(parent, name)
    if not parent then return nil end
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == name and child:IsA("RemoteEvent") then
            return child
        end
        local found = FindRemoteByName(child, name)
        if found then return found end
    end
    return nil
end

local LockRemote = GetNil("Lock", "1_124191") or FindRemoteByName(workspace, "Lock")
local ShootRemote = GetNil("ShootStart", "1_142658") or FindRemoteByName(workspace, "ShootStart")
if not ShootRemote then
    local char = LocalPlayer.Character
    if char then
        local gun = char:FindFirstChild("Gun")
        if gun then
            local gunServer = gun:FindFirstChild("GunServer")
            if gunServer then
                ShootRemote = gunServer:FindFirstChild("ShootStart")
            end
        end
    end
end
print("LockRemote:", LockRemote and "OK" or "なし")
print("ShootRemote:", ShootRemote and "OK" or "なし")

-- =====================================================
-- 4. ターゲット取得
-- =====================================================
local function GetClosestTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local root = myChar:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local origin = root.Position

    local closest = nil
    local closestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local pchar = player.Character
        if not pchar then continue end
        local humanoid = pchar:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then continue end

        local target = pchar:FindFirstChild("Head") or pchar:FindFirstChild("UpperTorso") or pchar:FindFirstChild("HumanoidRootPart")
        if not target then continue end

        if IsProximity(target) then
            continue
        end

        local dist = (target.Position - origin).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = target
        end
    end
    return closest
end

-- =====================================================
-- 5. 銃口位置
-- =====================================================
local function GetMuzzlePosition()
    local char = LocalPlayer.Character
    if not char then return nil end
    local gun = char:FindFirstChild("Gun")
    if not gun then return nil end
    local muzzle = gun:FindFirstChild("Handle") or gun:FindFirstChild("Tip") or gun:FindFirstChild("Part")
    if muzzle and muzzle:IsA("BasePart") then
        return muzzle.Position
    else
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            return root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1.5, 0)
        end
    end
    return nil
end

-- =====================================================
-- 6. ビーム生成
-- =====================================================
local function CreateBeam(weapon, targetPos, color)
    if not weapon or not weapon:FindFirstChild("Handle") then return end

    local function createPointPart(pos)
        local part = Instance.new("Part")
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        part.CFrame = CFrame.new(pos)
        Instance.new("Attachment").Parent = part
        game:GetService("Debris"):AddItem(part, 1)
        part.Parent = workspace
        return part
    end

    local point1 = createPointPart(weapon.Handle.Position)
    local point2 = createPointPart(targetPos)

    local beam
    if weapon:FindFirstChild("CustomBeam") then
        beam = weapon.CustomBeam:Clone()
    else
        beam = Instance.new("Beam")
        beam.Width0 = 0.2
        beam.Width1 = 0.2
        beam.LightEmission = 0.5
        beam.LightInfluence = 0
    end

    beam.Attachment0 = point1.Attachment
    beam.Attachment1 = point2.Attachment
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.202, 0.95),
        NumberSequenceKeypoint.new(1, 0.6)
    })
    beam.FaceCamera = true
    beam.Color = ColorSequence.new(color or Color3.fromRGB(255, 0, 0))
    beam.Parent = point1

    local sparksScript = script:FindFirstChild("Sparks")
    if sparksScript then
        local spark = sparksScript:Clone()
        spark.Color = ColorSequence.new(beam.Color)
        spark.Parent = point2
        spark:Emit(7)
    end

    task.wait(0.03)
    local tween = game:GetService("TweenService")
    tween:Create(beam, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
        Width0 = 0
    }):Play()
    tween:Create(beam, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
        Width1 = 0
    }):Play()
end

-- =====================================================
-- 7. 射撃関数
-- =====================================================
local function FireGun()
    if not ShootRemote then return end
    local target = GetClosestTarget()
    if not target then return end

    local fakeMuzzlePos = target.Position + Vector3.new(0, 1.5, -2)
    if LockRemote then LockRemote:FireServer(9999) end
    ShootRemote:FireServer(fakeMuzzlePos, target)

    local weapon = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
    if weapon then
        pcall(function()
            CreateBeam(weapon, target.Position, Color3.fromRGB(255, 0, 0))
        end)
    end
end

-- =====================================================
-- 8. タッチモード（自動連射＋ホールド連射）
-- =====================================================
local AUTO_FIRE_ENABLED = true
local FIRE_INTERVAL = 0.03
local lastFire = 0

-- 自動連射（常時発射）
RunService.Heartbeat:Connect(function()
    if not AUTO_FIRE_ENABLED then return end
    if not LocalPlayer.Character then return end
    if tick() - lastFire >= FIRE_INTERVAL then
        FireGun()
        lastFire = tick()
    end
end)

-- タッチ／クリック用
local isHolding = false
local holdConnection = nil

local function startHoldFire()
    if isHolding then return end
    isHolding = true
    FireGun() -- 最初の1発

    -- ホールド中は0.05秒間隔で連射
    if holdConnection then holdConnection:Disconnect() end
    holdConnection = RunService.Heartbeat:Connect(function()
        if isHolding and LocalPlayer.Character then
            FireGun()
            task.wait(0.05)
        end
    end)
end

local function stopHoldFire()
    isHolding = false
    if holdConnection then
        holdConnection:Disconnect()
        holdConnection = nil
    end
end

-- マウス／タッチ入力
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if TOUCH_MODE then
            startHoldFire()
        else
            FireGun()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if TOUCH_MODE then
            stopHoldFire()
        end
    end
end)

print("統合版（タッチモード対応）起動完了！")
print("タップで発射 / 長押しで連射（モバイル最適化）")
print("5スタッド以内は味方（青色）・それ以外は敵（赤色）")
