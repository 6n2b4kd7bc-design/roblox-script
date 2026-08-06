-- ============================================================
-- ライブラリロード（Orion）
-- ============================================================
local OrionLib = nil
local retryCount = 0
while not OrionLib and retryCount < 5 do
    pcall(function()
        OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/BlizTBr/scripts/main/Orion%20X'))()
    end)
    if not OrionLib then
        retryCount = retryCount + 1
        task.wait(1)
    end
end
if not OrionLib then error("Orionライブラリの読み込みに失敗") end

-- ============================================================
-- 基本セットアップ
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Window = OrionLib:MakeWindow({
    Name = "Destroy Panel [完全アンチ対策版]",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "DestroyPanelConfig"
})

local MainTab = Window:MakeTab({Name = "Destroy Server", Icon = "rbxassetid://4483345998", PremiumOnly = false})
local VisualTab = Window:MakeTab({Name = "Visual", Icon = "rbxassetid://4483345998", PremiumOnly = false})

-- ============================================================
-- 変数宣言
-- ============================================================
local selectedHeight = "Spawn"
local selectedTarget = nil
local autoLoop = false
local isAttacking = false
local espEnabled = false
local espObjects = {}
local targetDropdown = nil

-- ★ アンチラグドール用変数
local antiRagdollEnabled = false
local antiRagdollConns = {}

-- ============================================================
-- ★ 自分用アンチラグドール（あなたのコードを簡略統合）
-- ============================================================
local function cleanRagdoll(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum then
        local s = hum:GetState()
        if s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown then
            if hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Running) end
        end
        Camera.CameraSubject = hum
    end
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then
            d:Destroy()
        elseif d:IsA("Motor6D") and d.Enabled == false then
            d.Enabled = true
        end
    end
end

local function startAntiRagdollLoops(char)
    local antiConn = RunService.Heartbeat:Connect(function()
        if not antiRagdollEnabled then return end
        if not LocalPlayer.Character then return end
        local c = LocalPlayer.Character
        local hum = c:FindFirstChildOfClass("Humanoid")
        local root = c:FindFirstChild("HumanoidRootPart")
        if not (hum and root) then return end

        local s = hum:GetState()
        local ragdolled = (s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown)
        if ragdolled then
            cleanRagdoll(c)
        end
    end)
    table.insert(antiRagdollConns, antiConn)
end

local function stopAntiRagdollLoops()
    for _, c in ipairs(antiRagdollConns) do
        pcall(function() c:Disconnect() end)
    end
    antiRagdollConns = {}
end

local function setupAntiRagdoll(char)
    if not antiRagdollEnabled then return end
    task.wait(0.1)
    startAntiRagdollLoops(char)
end

-- キャラクター追加時に適用
if LocalPlayer.Character then setupAntiRagdoll(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    if antiRagdollEnabled then setupAntiRagdoll(char) end
end)

-- ============================================================
-- ★ 自分用アンチグラブ（以前のコードから継続）
-- ============================================================
local AntiGrabProc = false
local AGWalk = false

local function FWC(Parent, Name, Time)
    return Parent:FindFirstChild(Name) or Parent:WaitForChild(Name, Time or 5)
end

local function setupAntiGrab(char)
    if not char then return end
    local hrp = FWC(char, "HumanoidRootPart")
    local hum = FWC(char, "Humanoid")
    local head = FWC(char, "Head")

    head.ChildAdded:Connect(function(PartOwner)
        if PartOwner.Name == "PartOwner" then
            if not AntiGrabProc then
                AntiGrabProc = true
                hum.Sit = false
                local rs = ReplicatedStorage
                local Struggle = rs.CharacterEvents and rs.CharacterEvents:FindFirstChild("Struggle")
                local RagdollRemote = rs.CharacterEvents and rs.CharacterEvents:FindFirstChild("RagdollRemote")
                if Struggle and RagdollRemote then
                    task.spawn(function()
                        while head and head:FindFirstChild("PartOwner") do
                            pcall(function()
                                Struggle:FireServer(LocalPlayer)
                                RagdollRemote:FireServer(hrp, 0)
                            end)
                            task.wait()
                        end
                    end)
                end
                hrp.Anchored = true
                if not AGWalk then
                    AGWalk = true
                    while LocalPlayer.IsHeld and LocalPlayer.IsHeld.Value and task.wait() do
                        hrp.CFrame = hrp.CFrame + hum.MoveDirection * 0.43
                    end
                end
                hrp.Anchored = false
                AntiGrabProc = false
                AGWalk = false
            end
        end
    end)

    local ragdolled = FWC(hum, "Ragdolled")
    ragdolled.Changed:Connect(function()
        if hum.Ragdolled.Value then
            for _, v in pairs(char:GetChildren()) do
                if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                    v.BallSocketConstraint.Enabled = false
                    if v:FindFirstChild("RagdollLimbPart") then
                        v.RagdollLimbPart.WeldConstraint.Enabled = false
                    end
                end
            end
        end
    end)

    local weldHRP = FWC(hrp, "WeldHRP")
    weldHRP.Changed:Connect(function()
        if hrp.WeldHRP.Enabled then
            while not hum.Sit do task.wait() end
            hum.Sit = false
            hum.AutoRotate = true
            hum.HipHeight = 1
            while hrp.WeldHRP.Enabled and task.wait() do
                head.CFrame = hrp.CFrame + Vector3.new(0, 1.35, 0)
            end
            hum.HipHeight = 0
        end
    end)

    for _, v in pairs(char:GetChildren()) do
        if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
            v.BallSocketConstraint.Enabled = false
            if v:FindFirstChild("RagdollLimbPart") then
                v.RagdollLimbPart.WeldConstraint.Enabled = false
            end
        end
    end
end

if LocalPlayer.Character then setupAntiGrab(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char)
    AntiGrabProc = false
    AGWalk = false
    task.defer(setupAntiGrab, char)
end)

-- ============================================================
-- ★ 相手のアンチ対策（ラグドール強制含む）
-- ============================================================
local function preGrabDisable(targetPlayer)
    if not targetPlayer then return end
    local char = targetPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    -- 1. 相手を強制的にSit状態に
    pcall(function() hum.Sit = true end)

    -- 2. 相手のリモートを先に連射
    local rs = ReplicatedStorage
    local Struggle = rs.CharacterEvents and rs.CharacterEvents:FindFirstChild("Struggle")
    local RagdollRemote = rs.CharacterEvents and rs.CharacterEvents:FindFirstChild("RagdollRemote")
    if Struggle then
        for _ = 1, 10 do pcall(function() Struggle:FireServer(targetPlayer) end) task.wait(0.01) end
    end
    if RagdollRemote then
        for _ = 1, 5 do pcall(function() RagdollRemote:FireServer(hrp, 0) end) task.wait(0.01) end
    end

    -- 3. 相手のHeadを透明化
    local head = char:FindFirstChild("Head")
    if head then
        pcall(function()
            head.CanCollide = false
            head.Transparency = 1
        end)
    end

    -- 4. ★ 相手にラグドール強制（BallSocketConstraintを追加して物理的に拘束）
    for _, part in pairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "Head" then
            pcall(function()
                -- 既存のConstraintを一旦無効化
                for _, c in pairs(part:GetChildren()) do
                    if c:IsA("Constraint") then c.Enabled = false end
                end
                -- 新しいBallSocketConstraintで固定
                local att0 = Instance.new("Attachment", part)
                local att1 = Instance.new("Attachment", hrp)
                local bsc = Instance.new("BallSocketConstraint", part)
                bsc.Attachment0 = att0
                bsc.Attachment1 = att1
                bsc.LimitsEnabled = true
                bsc.TwistLimitsEnabled = true
                bsc.UpperAngle = 0
                bsc.LowerAngle = 0
                bsc.TwistLowerAngle = 0
                bsc.TwistUpperAngle = 0
                bsc.Enabled = true
            end)
        end
    end
end

-- ============================================================
-- プレイヤーリスト
-- ============================================================
local function getPlayerNames()
    local names = {"全員"}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then table.insert(names, plr.Name) end
    end
    return names
end

local function createDropdown()
    targetDropdown = MainTab:AddDropdown({
        Name = "ターゲット指定",
        Default = "全員",
        Options = getPlayerNames(),
        Callback = function(Value)
            if Value == "全員" then
                selectedTarget = nil
            else
                selectedTarget = Players:FindFirstChild(Value)
            end
            local displayName = selectedTarget and selectedTarget.Name or "全員"
            OrionLib:MakeNotification({Name = "ターゲット", Content = "対象: " .. displayName, Image = "rbxassetid://4483345998", Time = 2})
            if espEnabled then updateESP() end
        end
    })
end

-- ============================================================
-- ターゲット取得
-- ============================================================
local function getTargetPlayers()
    if selectedTarget then
        if selectedTarget.Character and selectedTarget.Character:FindFirstChild("HumanoidRootPart") then
            return {selectedTarget}
        else
            selectedTarget = nil
            return {}
        end
    else
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    table.insert(list, plr)
                end
            end
        end
        return list
    end
end

-- ============================================================
-- GrabEvents
-- ============================================================
local GrabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")

local function spamOwnership(hrp)
    if not GrabEvents then return end
    local setOwner = GrabEvents:FindFirstChild("SetNetworkOwner")
    if setOwner and hrp then pcall(function() setOwner:FireServer(hrp, hrp.CFrame) end) end
end

local function teleportToPlayer(myHrp, targetHrp)
    if not myHrp or not targetHrp then return end
    pcall(function()
        myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 5, 5)
        myHrp.AssemblyLinearVelocity = Vector3.zero
    end)
end

local function destroyLineOnPlayer(hrp)
    if not GrabEvents then return end
    local createLine = GrabEvents:FindFirstChild("CreateGrabLine")
    local destroyLine = GrabEvents:FindFirstChild("DestroyGrabLine")
    if not createLine or not destroyLine then return end
    pcall(function()
        createLine:FireServer(hrp, CFrame.new(0, 1e9, 0))
        task.wait()
        destroyLine:FireServer(hrp)
    end)
end

-- ★ 相手を掴む前にアンチ対策＋ラグドール強制
local function grabWithAntiCounter(targetHrp, targetPlayer)
    if not targetPlayer then return end
    preGrabDisable(targetPlayer)
    task.wait(0.05)
    spamOwnership(targetHrp)
    task.wait(0.05)
    local rs = ReplicatedStorage
    local Struggle = rs.CharacterEvents and rs.CharacterEvents:FindFirstChild("Struggle")
    if Struggle then
        for _ = 1, 5 do pcall(function() Struggle:FireServer(targetPlayer) end) task.wait(0.01) end
    end
end

-- ============================================================
-- ラインラグ
-- ============================================================
local lineLagThread = nil
local lineLagEnabled = false

local function startLineLag()
    if lineLagEnabled then return end
    lineLagEnabled = true
    lineLagThread = coroutine.create(function()
        if not GrabEvents then return end
        local createLine = GrabEvents:FindFirstChild("CreateGrabLine")
        if not createLine then return end
        while lineLagEnabled do
            local spawnLocation = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("Spawn") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
            if spawnLocation then
                local randomX = math.random(-1e9, 1e9)
                local randomZ = math.random(-1e9, 1e9)
                local directions = {CFrame.new(randomX, 0, randomZ), CFrame.new(-randomX, 0, -randomZ), CFrame.new(randomX, 0, -randomZ), CFrame.new(-randomX, 0, randomZ)}
                for _, pos in pairs(directions) do createLine:FireServer(spawnLocation, pos) end
            end
            task.wait()
        end
    end)
    coroutine.resume(lineLagThread)
end

local function stopLineLag()
    lineLagEnabled = false
    if lineLagThread then coroutine.close(lineLagThread); lineLagThread = nil end
end

-- ============================================================
-- Kick All（全員を自分の周りにテレポート＋ラグドール強制）
-- ============================================================
local function kickAllToMe()
    local myChar = LocalPlayer.Character
    if not myChar then
        OrionLib:MakeNotification({Name = "エラー", Content = "キャラクターが見つかりません", Image = "rbxassetid://4483345998", Time = 2})
        return
    end
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then
        OrionLib:MakeNotification({Name = "エラー", Content = "HRPが見つかりません", Image = "rbxassetid://4483345998", Time = 2})
        return
    end

    local myPos = myHrp.Position
    local targets = getTargetPlayers()
    if #targets == 0 then
        OrionLib:MakeNotification({Name = "Kick All", Content = "対象プレイヤーがいません", Image = "rbxassetid://4483345998", Time = 2})
        return
    end

    local radius = 5
    for i, plr in ipairs(targets) do
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local angle = (i - 1) * (2 * math.pi / #targets)
                local x = myPos.X + math.cos(angle) * radius
                local z = myPos.Z + math.sin(angle) * radius
                local newPos = Vector3.new(x, myPos.Y + 2, z)
                pcall(function()
                    hrp.CFrame = CFrame.new(newPos)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end)
                -- 相手のアンチ対策＋ラグドール強制
                preGrabDisable(plr)
                local bp = Instance.new("BodyPosition")
                bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                bp.P = 100000
                bp.Position = newPos
                bp.Parent = hrp
                task.delay(1, function() pcall(function() bp:Destroy() end) end)
            end
        end
    end
    OrionLib:MakeNotification({Name = "Kick All", Content = string.format("%d人を自分の周りに集めました", #targets), Image = "rbxassetid://4483345998", Time = 3})
end

-- ============================================================
-- コア攻撃処理（アンチ対策付き）
-- ============================================================
local function executeAttack()
    if isAttacking then return end
    isAttacking = true
    task.spawn(function()
        local height = (selectedHeight == "Heaven") and 1e9 or 35
        local players = getTargetPlayers()
        if #players == 0 then
            OrionLib:MakeNotification({Name = "Destroy", Content = "対象プレイヤーがいません", Image = "rbxassetid://4483345998", Time = 3})
            isAttacking = false
            return
        end

        local myChar = LocalPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp then isAttacking = false; return end

        local playerData = {}
        for _, plr in ipairs(players) do
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then table.insert(playerData, {player = plr, hrp = hrp}) end
        end
        if #playerData == 0 then isAttacking = false; return end

        for _, data in ipairs(playerData) do
            teleportToPlayer(myHrp, data.hrp)
            task.wait(0.15)
            grabWithAntiCounter(data.hrp, data.player)
            task.wait(0.15)
        end

        local radius = 40
        local angleStep = (math.pi * 2) / #playerData
        for idx, data in ipairs(playerData) do
            local angle = (idx - 1) * angleStep
            local x = math.cos(angle) * radius
            local z = math.sin(angle) * radius
            pcall(function()
                data.hrp.CFrame = CFrame.new(x, height, z)
                data.hrp.AssemblyLinearVelocity = Vector3.zero
            end)
            local bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bp.P = 40000000
            bp.Position = Vector3.new(x, height, z)
            bp.Parent = data.hrp
            task.delay(2, function() pcall(function() bp:Destroy() end) end)
            task.wait()
        end

        for i = 1, 8 do
            for _, data in ipairs(playerData) do destroyLineOnPlayer(data.hrp) end
            task.wait(0.3)
        end
        
        local targetName = selectedTarget and selectedTarget.Name or "全員"
        OrionLib:MakeNotification({Name = "Destroy", Content = string.format("完了！対象: %s", targetName), Image = "rbxassetid://4483345998", Time = 2})
        isAttacking = false
    end)
end

-- ============================================================
-- 自動ループ
-- ============================================================
local loopThread = nil
local loopRunning = false

local function startAutoLoop()
    if loopRunning then return end
    loopRunning = true
    loopThread = task.spawn(function()
        while loopRunning do
            if not isAttacking then
                startLineLag()
                task.wait(1)
                executeAttack()
            end
            task.wait(3)
        end
    end)
end

local function stopAutoLoop()
    loopRunning = false
    if loopThread then task.cancel(loopThread); loopThread = nil end
end

-- ============================================================
-- プレイヤー追加/削除
-- ============================================================
Players.PlayerAdded:Connect(function(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        task.wait(2)
        if autoLoop and not isAttacking then
            if not selectedTarget or selectedTarget == plr then
                executeAttack()
            end
        end
        if espEnabled then updateESP() end
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    if selectedTarget == plr then selectedTarget = nil end
    if espEnabled then updateESP() end
end)

-- ============================================================
-- ESP
-- ============================================================
local function clearESP()
    for _, obj in ipairs(espObjects) do pcall(function() obj:Destroy() end) end
    espObjects = {}
end

local function updateESP()
    clearESP()
    if not espEnabled then return end
    local targets = getTargetPlayers()
    for _, plr in ipairs(targets) do
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local box = Instance.new("SelectionBox")
                box.Adornee = hrp.Parent
                box.Color3 = Color3.fromRGB(255, 0, 0)
                box.LineThickness = 0.1
                box.Transparency = 0.5
                box.Parent = hrp.Parent
                table.insert(espObjects, box)
            end
        end
    end
end

local espLoopRunning = false
local espLoopThread = nil

local function startESPLoop()
    if espLoopRunning then return end
    espLoopRunning = true
    espLoopThread = task.spawn(function()
        while espLoopRunning do
            if espEnabled then updateESP() else clearESP() end
            task.wait(0.5)
        end
    end)
end

local function stopESPLoop()
    espLoopRunning = false
    if espLoopThread then task.cancel(espLoopThread); espLoopThread = nil end
    clearESP()
end

-- ============================================================
-- ラグ専用
-- ============================================================
local lagOnlyRunning = false
local lagOnlyThread = nil

local function startLagOnly()
    if lagOnlyRunning then return end
    lagOnlyRunning = true
    startLineLag()
    lagOnlyThread = task.spawn(function()
        while lagOnlyRunning do task.wait(1) end
    end)
    OrionLib:MakeNotification({Name = "ラグ専用", Content = "開始", Image = "rbxassetid://4483345998", Time = 2})
end

local function stopLagOnly()
    lagOnlyRunning = false
    if lagOnlyThread then task.cancel(lagOnlyThread); lagOnlyThread = nil end
    stopLineLag()
    OrionLib:MakeNotification({Name = "ラグ専用", Content = "停止", Image = "rbxassetid://4483345998", Time = 2})
end

-- ============================================================
-- UI (MainTab)
-- ============================================================
createDropdown()

MainTab:AddButton({
    Name = "🔄 プレイヤーリスト更新",
    Callback = function() createDropdown() 
        OrionLib:MakeNotification({Name = "更新", Content = "リストを更新しました", Image = "rbxassetid://4483345998", Time = 2})
    end
})

MainTab:AddToggle({
    Name = "自動連続攻撃（アンチ対策付き）",
    Default = false,
    Callback = function(state)
        autoLoop = state
        if state then
            startAutoLoop()
            OrionLib:MakeNotification({Name = "自動ループ", Content = "開始", Image = "rbxassetid://4483345998", Time = 2})
        else
            stopAutoLoop()
            OrionLib:MakeNotification({Name = "自動ループ", Content = "停止", Image = "rbxassetid://4483345998", Time = 2})
        end
    end
})

MainTab:AddDropdown({
    Name = "破壊の高さモード",
    Options = {"Spawn (地上)", "Heaven (天国)"},
    Default = "Spawn (地上)",
    Callback = function(Value)
        selectedHeight = (Value == "Heaven (天国)") and "Heaven" or "Spawn"
    end
})

MainTab:AddButton({
    Name = "Destroy Server（手動・アンチ対策付き）",
    Callback = function()
        startLineLag()
        task.wait(1)
        executeAttack()
    end
})

MainTab:AddButton({
    Name = "Kick All（全員を自分の周りに集める）",
    Callback = function()
        kickAllToMe()
    end
})

MainTab:AddButton({
    Name = "Stop Lag (ラグを止める)",
    Callback = function()
        stopLineLag()
        OrionLib:MakeNotification({Name = "Lag", Content = "停止しました", Image = "rbxassetid://4483345998", Time = 2})
    end
})

MainTab:AddToggle({
    Name = "ラグ専用モード（攻撃なし）",
    Default = false,
    Callback = function(state)
        if state then startLagOnly() else stopLagOnly() end
    end
})

-- ============================================================
-- UI (VisualTab) - アンチラグドールトグル追加
-- ============================================================
VisualTab:AddDropdown({
    Name = "カメラモード",
    Options = {"Classic", "LockFirstPerson", "Track"},
    Default = "LockFirstPerson",
    Callback = function(Value)
        local modes = {
            Classic = Enum.CameraMode.Classic,
            LockFirstPerson = Enum.CameraMode.LockFirstPerson,
            Track = Enum.CameraMode.Track
        }
        local mode = modes[Value]
        if mode then
            Camera.CameraMode = mode
            OrionLib:MakeNotification({Name = "カメラ", Content = Value .. " に変更", Image = "rbxassetid://4483345998", Time = 2})
        end
    end
})

VisualTab:AddToggle({
    Name = "プレイヤーHitbox ESP",
    Default = false,
    Callback = function(state)
        espEnabled = state
        if state then
            startESPLoop()
            OrionLib:MakeNotification({Name = "ESP", Content = "有効", Image = "rbxassetid://4483345998", Time = 2})
        else
            stopESPLoop()
            OrionLib:MakeNotification({Name = "ESP", Content = "無効", Image = "rbxassetid://4483345998", Time = 2})
        end
    end
})

-- ★ アンチラグドールトグル（自分用）
VisualTab:AddToggle({
    Name = "アンチラグドール（自分）",
    Default = false,
    Callback = function(state)
        antiRagdollEnabled = state
        if state then
            if LocalPlayer.Character then setupAntiRagdoll(LocalPlayer.Character) end
            OrionLib:MakeNotification({Name = "アンチラグドール", Content = "有効", Image = "rbxassetid://4483345998", Time = 2})
        else
            stopAntiRagdollLoops()
            OrionLib:MakeNotification({Name = "アンチラグドール", Content = "無効", Image = "rbxassetid://4483345998", Time = 2})
        end
    end
})

-- ============================================================
-- 初期化
-- ============================================================
espEnabled = false
stopESPLoop()
clearESP()
Camera.CameraMode = Enum.CameraMode.LockFirstPerson

-- アンチラグドール初期OFF
antiRagdollEnabled = false
stopAntiRagdollLoops()

OrionLib:MakeNotification({
    Name = "起動完了",
    Content = "アンチグラブ + アンチラグドール統合版",
    Image = "rbxassetid://4483345998",
    Time = 5
})

OrionLib:Init()
