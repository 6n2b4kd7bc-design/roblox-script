-- [[ Jailbroken AI: RNG Zombie Farm V2 (Fluent Mobile Edition) ]]
-- ★ UIサイズ拡大 / スクロール完全対応 / Combatタブ全復活
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- UI 初期化（サイズ拡大）
-- ==========================================
local Window = Fluent:CreateWindow({
    Title = "Zombie Farm V2 ⚠️ JAILBROKEN",
    SubTitle = "Mobile Optimized",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 300),  -- ★ 高さを620に拡大
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- ==========================================
-- モバイル用 UI開閉ボタン（サイズ調整）
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JailbrokenMobileToggle"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleMenu"
ToggleBtn.Parent = ScreenGui
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ToggleBtn.BorderColor3 = Color3.fromRGB(255, 0, 0)
ToggleBtn.BorderSizePixel = 2
ToggleBtn.Position = UDim2.new(0, 10, 0, 10)
ToggleBtn.Size = UDim2.new(0, 40, 0, 40)  -- ★ 少し小さく
ToggleBtn.Font = Enum.Font.Code
ToggleBtn.Text = "UI"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextScaled = true
ToggleBtn.Active = true
ToggleBtn.Draggable = true

ToggleBtn.MouseButton1Click:Connect(function()
    Window:Minimize()
end)

-- ==========================================
-- グローバル変数 / 共通設定
-- ==========================================
local farmingEnabled = false
local farmThread = nil
local autoBuyEnabled = false
local autoBuyThread = nil
local autoRollEnabled = false
local autoRollThread = nil

local activeDiceTypes = {}
local activeRollDiceTypes = {}

local buyDelay = 0.08
local buyMode = "BuyOne"
local rollInterval = 5
local rollDelay = 0.3

local attackInterval = 0.15
local hoverHeight = 2.5
local orbitRadius = 3.0
local orbitSpeed = 2.0
local orbitEnabled = true
local orbitAngle = 0

local cachedZombie = nil
local cachedZombieTime = 0
local ZOMBIE_CACHE_DURATION = 0.2

local SHOP_POSITION = Vector3.new(178.94, 4.87, -144.82)
local lastTeleportTime = 0
local TELEPORT_INTERVAL = 180

-- ★ 全ダイス名リスト（共通）
local allDiceNames = {
    "Valentine", "Seraphic", "Omnipotent", "Transcendent", "Singularity",
    "Oblivion", "Paradox", "Arcane", "Sovereign", "Eldritch",
    "Quantum", "Galactic", "Ethereal", "Infernal", "Abyssal",
    "Void", "Nebula", "Celestial"
}

-- ★ Shop用状態（デフォルト全ON）
local diceTypeStatus = {}
for _, name in ipairs(allDiceNames) do
    diceTypeStatus[name] = true
end

-- ★ Roll用状態（デフォルトで一部ON）
local rollDiceTypeStatus = {}
local defaultRollOn = {"Celestial", "Void", "Nebula"}
for _, name in ipairs(allDiceNames) do
    rollDiceTypeStatus[name] = false
end
for _, name in ipairs(defaultRollOn) do
    rollDiceTypeStatus[name] = true
end

local function updateDiceTypes()
    activeDiceTypes = {}
    for name, status in pairs(diceTypeStatus) do
        if status then table.insert(activeDiceTypes, name) end
    end
    Fluent:Notify({ Title = "購入対象更新", Content = #activeDiceTypes .. "個選択中", Duration = 1 })
end

local function updateRollDiceTypes()
    activeRollDiceTypes = {}
    for name, status in pairs(rollDiceTypeStatus) do
        if status then table.insert(activeRollDiceTypes, name) end
    end
    Fluent:Notify({ Title = "ロール対象更新", Content = #activeRollDiceTypes .. "個選択中", Duration = 1 })
end

updateDiceTypes()
updateRollDiceTypes()

-- ==========================================
-- 関数定義
-- ==========================================
local function teleportToShop()
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    root.CFrame = CFrame.new(SHOP_POSITION + Vector3.new(0, 2, 0))
    task.wait(0.3)
    return true
end

local function findSwingRemote()
    local zr = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ZombieUprising")
    if zr and zr:IsA("RemoteEvent") then return zr end
    return nil
end
local SwingRemote = findSwingRemote()

local function getNearestZombie()
    local now = tick()
    if cachedZombie and (now - cachedZombieTime) < ZOMBIE_CACHE_DURATION then
        if cachedZombie and cachedZombie.Parent and cachedZombie:FindFirstChild("Humanoid") and cachedZombie.Humanoid.Health > 0 then
            return cachedZombie
        else
            cachedZombie = nil
        end
    end

    local zombies = {}
    local folder = Workspace:FindFirstChild("ZombieUprisingZombies") or Workspace
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") and obj.Name:lower():find("zombie") and obj:FindFirstChild("Humanoid") then
            if obj.Humanoid.Health > 0 then table.insert(zombies, obj) end
        end
    end
    
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or #zombies == 0 then
        cachedZombie = nil
        cachedZombieTime = now
        return nil
    end
    
    local nearest, minDist = nil, math.huge
    for _, z in ipairs(zombies) do
        local pos = (z:FindFirstChild("HumanoidRootPart") or z.PrimaryPart).Position
        local dist = (pos - myRoot.Position).Magnitude
        if dist < minDist then minDist = dist; nearest = z end
    end
    
    cachedZombie = nearest
    cachedZombieTime = now
    return nearest
end

-- ==========================================
-- タブ & メニュー構築
-- ==========================================
local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Shop = Window:AddTab({ Title = "Shop", Icon = "shopping-cart" }),
    Roll = Window:AddTab({ Title = "Roll", Icon = "dice" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- ==========================================
-- Combat Tab（完全復活）
-- ==========================================
Tabs.Combat:AddSection("⚔️ Auto Farm System")

local AttackIntervalInput = Tabs.Combat:AddInput("AttackIntervalInput", {
    Title = "攻撃リモート間隔（秒）",
    Default = "0.15",
    Placeholder = "0.08 ～ 0.5 推奨",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            attackInterval = num
            Fluent:Notify({ Title = "更新", Content = "攻撃間隔を " .. num .. "秒に設定", Duration = 2 })
        else
            Fluent:Notify({ Title = "エラー", Content = "正の数値を入力してください", Duration = 2 })
        end
    end
})

local HeightInput = Tabs.Combat:AddInput("HeightInput", {
    Title = "ゾンビ頭上からの高さ",
    Default = "2.5",
    Placeholder = "1.5 ～ 5.0 推奨",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            hoverHeight = num
            Fluent:Notify({ Title = "更新", Content = "高さを " .. num .. "に設定", Duration = 2 })
        else
            Fluent:Notify({ Title = "エラー", Content = "正の数値を入力してください", Duration = 2 })
        end
    end
})

local OrbitRadiusInput = Tabs.Combat:AddInput("OrbitRadiusInput", {
    Title = "周回半径",
    Default = "3.0",
    Placeholder = "1.0 ～ 8.0 推奨",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num >= 0 then
            orbitRadius = num
            Fluent:Notify({ Title = "更新", Content = "半径を " .. num .. "に設定", Duration = 2 })
        else
            Fluent:Notify({ Title = "エラー", Content = "0以上の数値を入力してください", Duration = 2 })
        end
    end
})

local OrbitSpeedInput = Tabs.Combat:AddInput("OrbitSpeedInput", {
    Title = "周回速度（rad/秒）",
    Default = "2.0",
    Placeholder = "1.0 ～ 5.0 推奨",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            orbitSpeed = num
            Fluent:Notify({ Title = "更新", Content = "速度を " .. num .. "に設定", Duration = 2 })
        else
            Fluent:Notify({ Title = "エラー", Content = "正の数値を入力してください", Duration = 2 })
        end
    end
})

local OrbitToggle = Tabs.Combat:AddToggle("OrbitToggle", {
    Title = "🔄 周回移動（攻撃回避）",
    Default = true
})
OrbitToggle:OnChanged(function()
    orbitEnabled = Options.OrbitToggle.Value
    Fluent:Notify({ Title = "周回", Content = orbitEnabled and "ON" or "OFF", Duration = 2 })
end)

local AutoFarmToggle = Tabs.Combat:AddToggle("AutoFarmToggle", {
    Title = "🔥 Auto Zombie Farm", 
    Default = false 
})

AutoFarmToggle:OnChanged(function()
    farmingEnabled = Options.AutoFarmToggle.Value
    if farmingEnabled then
        if not SwingRemote then
            Fluent:Notify({ Title = "エラー", Content = "Swingリモートが見つかりません", Duration = 3 })
            Options.AutoFarmToggle:SetValue(false)
            return
        end
        orbitAngle = 0
        farmThread = task.spawn(function()
            local attackTimer = 0
            local frameTime = 0.016
            while farmingEnabled do
                local z = getNearestZombie()
                if z then
                    local root = z:FindFirstChild("HumanoidRootPart") or z.PrimaryPart
                    if root and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local myRoot = LocalPlayer.Character.HumanoidRootPart
                        if orbitEnabled and orbitRadius > 0 then
                            orbitAngle = orbitAngle + (orbitSpeed * frameTime)
                            local offsetX = math.cos(orbitAngle) * orbitRadius
                            local offsetZ = math.sin(orbitAngle) * orbitRadius
                            local targetPos = root.Position + Vector3.new(offsetX, hoverHeight, offsetZ)
                            myRoot.CFrame = CFrame.new(targetPos)
                        else
                            myRoot.CFrame = CFrame.new(root.Position + Vector3.new(0, hoverHeight, 0))
                        end
                        myRoot.AssemblyLinearVelocity = Vector3.zero
                        myRoot.AssemblyAngularVelocity = Vector3.zero
                    end
                    attackTimer = attackTimer + frameTime
                    if attackTimer >= attackInterval then
                        if SwingRemote then SwingRemote:FireServer("Swing") end
                        attackTimer = 0
                    end
                else
                    task.wait(0.3)
                    attackTimer = 0
                end
                task.wait(frameTime)
            end
        end)
        Fluent:Notify({ Title = "Combat", Content = "オートファームを開始しました", Duration = 2 })
    else
        if farmThread then task.cancel(farmThread); farmThread = nil end
        Fluent:Notify({ Title = "Combat", Content = "オートファームを停止しました", Duration = 2 })
    end
end)

-- ==========================================
-- Shop Tab
-- ==========================================
Tabs.Shop:AddSection("🛒 Auto Buy System (3分ごとテレポート)")

local BuyModeDropdown = Tabs.Shop:AddDropdown("BuyModeDropdown", {
    Title = "購入モード",
    Values = {"BuyOne (個別)", "BuyAll (一括)"},
    Multi = false,
    Default = 1,
})
BuyModeDropdown:OnChanged(function(Value)
    if Value == "BuyOne (個別)" then
        buyMode = "BuyOne"
    else
        buyMode = "BuyAll"
    end
    Fluent:Notify({ Title = "更新", Content = "購入モード: " .. buyMode, Duration = 2 })
end)

local BuyDelayInput = Tabs.Shop:AddInput("BuyDelayInput", {
    Title = "購入間隔（秒）",
    Default = "0.08",
    Placeholder = "0.04 ～ 0.2 推奨",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num >= 0 then
            buyDelay = num
            Fluent:Notify({ Title = "更新", Content = "間隔を " .. num .. "秒に設定", Duration = 2 })
        else
            Fluent:Notify({ Title = "エラー", Content = "0以上の数値を入力してください", Duration = 2 })
        end
    end
})

Tabs.Shop:AddSection("🎯 購入対象ダイスタイプ（ONで購入）")

for _, name in ipairs(allDiceNames) do
    local toggle = Tabs.Shop:AddToggle(name .. "Toggle", {
        Title = name,
        Default = diceTypeStatus[name]
    })
    toggle:OnChanged(function()
        diceTypeStatus[name] = Options[name .. "Toggle"].Value
        updateDiceTypes()
    end)
end

local AutoBuyToggle = Tabs.Shop:AddToggle("AutoBuyToggle", {
    Title = "💰 Auto Buy Dice (テレポート3分間隔)", 
    Default = false 
})

AutoBuyToggle:OnChanged(function()
    autoBuyEnabled = Options.AutoBuyToggle.Value
    if autoBuyEnabled then
        if #activeDiceTypes == 0 then
            Fluent:Notify({ Title = "エラー", Content = "購入対象が1つも選択されていません", Duration = 3 })
            Options.AutoBuyToggle:SetValue(false)
            return
        end
        local success = teleportToShop()
        if not success then
            Fluent:Notify({ Title = "エラー", Content = "Shop座標へテレポートできませんでした", Duration = 3 })
            Options.AutoBuyToggle:SetValue(false)
            return
        end
        lastTeleportTime = tick()
        Fluent:Notify({ Title = "Shop", Content = "Shop座標に移動しました。", Duration = 2 })

        autoBuyThread = task.spawn(function()
            local buyRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("BuyDice")
            if not buyRemote then
                Fluent:Notify({ Title = "エラー", Content = "BuyDiceリモートが見つかりません", Duration = 3 })
                autoBuyEnabled = false
                Options.AutoBuyToggle:SetValue(false)
                return
            end

            local loopCount = 0
            while autoBuyEnabled do
                loopCount = loopCount + 1

                if tick() - lastTeleportTime >= TELEPORT_INTERVAL then
                    teleportToShop()
                    lastTeleportTime = tick()
                end

                if buyMode == "BuyOne" then
                    for _, dtype in ipairs(activeDiceTypes) do
                        if not autoBuyEnabled then break end
                        pcall(function()
                            buyRemote:FireServer("BuyOne", dtype)
                        end)
                        task.wait(buyDelay)
                    end
                else
                    for _, dtype in ipairs(activeDiceTypes) do
                        if not autoBuyEnabled then break end
                        pcall(function()
                            buyRemote:FireServer("BuyAll", dtype)
                        end)
                        task.wait(buyDelay)
                    end
                end
                
                task.wait(0.02)
                if loopCount % 500 == 0 then
                    Fluent:Notify({ Title = "Status", Content = "購入ループ " .. loopCount .. " 回実行中", Duration = 1 })
                end
            end
        end)
        Fluent:Notify({ Title = "Shop", Content = "自動購入（" .. buyMode .. "）開始", Duration = 2 })
    else
        if autoBuyThread then task.cancel(autoBuyThread); autoBuyThread = nil end
        Fluent:Notify({ Title = "Shop", Content = "自動購入を停止しました", Duration = 2 })
    end
end)

Tabs.Shop:AddButton({
    Title = "📍 固定Shop座標へテレポート",
    Callback = function()
        if teleportToShop() then
            lastTeleportTime = tick()
            Fluent:Notify({ Title = "移動完了", Content = "座標 " .. tostring(SHOP_POSITION) .. " に移動", Duration = 2 })
        else
            Fluent:Notify({ Title = "エラー", Content = "テレポート失敗", Duration = 2 })
        end
    end
})

-- ==========================================
-- Roll Tab
-- ==========================================
Tabs.Roll:AddSection("🎲 Auto Roll (ガチャ自動回し)")

Tabs.Roll:AddSection("🎯 ロールするダイスタイプ（ONで対象）")

for _, name in ipairs(allDiceNames) do
    local toggle = Tabs.Roll:AddToggle("Roll_" .. name .. "Toggle", {
        Title = name,
        Default = rollDiceTypeStatus[name]
    })
    toggle:OnChanged(function()
        rollDiceTypeStatus[name] = Options["Roll_" .. name .. "Toggle"].Value
        updateRollDiceTypes()
    end)
end

local RollIntervalInput = Tabs.Roll:AddInput("RollIntervalInput", {
    Title = "ロール間隔（秒）",
    Default = "5",
    Placeholder = "3 ～ 30 推奨",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            rollInterval = num
            Fluent:Notify({ Title = "更新", Content = "ロール間隔を " .. num .. "秒に設定", Duration = 2 })
        else
            Fluent:Notify({ Title = "エラー", Content = "正の数値を入力してください", Duration = 2 })
        end
    end
})

local RollDelayInput = Tabs.Roll:AddInput("RollDelayInput", {
    Title = "各ダイス間の待機（秒）",
    Default = "0.3",
    Placeholder = "0.1 ～ 1.0 推奨",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num >= 0 then
            rollDelay = num
            Fluent:Notify({ Title = "更新", Content = "ダイス間待機を " .. num .. "秒に設定", Duration = 2 })
        else
            Fluent:Notify({ Title = "エラー", Content = "0以上の数値を入力してください", Duration = 2 })
        end
    end
})

local AutoRollToggle = Tabs.Roll:AddToggle("AutoRollToggle", {
    Title = "🎲 Auto Roll (選択ダイスを順番に)", 
    Default = false 
})

AutoRollToggle:OnChanged(function()
    autoRollEnabled = Options.AutoRollToggle.Value
    if autoRollEnabled then
        if #activeRollDiceTypes == 0 then
            Fluent:Notify({ Title = "エラー", Content = "ロール対象が1つも選択されていません", Duration = 3 })
            Options.AutoRollToggle:SetValue(false)
            return
        end
        teleportToShop()
        Fluent:Notify({ Title = "Roll", Content = "Auto Roll 開始 (対象: " .. #activeRollDiceTypes .. "種)", Duration = 2 })

        autoRollThread = task.spawn(function()
            local rollRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Open")
            if not rollRemote then
                Fluent:Notify({ Title = "エラー", Content = "Openリモートが見つかりません", Duration = 3 })
                autoRollEnabled = false
                Options.AutoRollToggle:SetValue(false)
                return
            end

            while autoRollEnabled do
                for _, dtype in ipairs(activeRollDiceTypes) do
                    if not autoRollEnabled then break end
                    pcall(function()
                        rollRemote:InvokeServer(dtype, 10, true)
                    end)
                    task.wait(rollDelay)
                end
                task.wait(rollInterval)
            end
        end)
    else
        if autoRollThread then task.cancel(autoRollThread); autoRollThread = nil end
        Fluent:Notify({ Title = "Roll", Content = "Auto Roll 停止", Duration = 2 })
    end
end)

Tabs.Roll:AddButton({
    Title = "🎲 手動ロール（全選択ダイス×10）",
    Callback = function()
        if #activeRollDiceTypes == 0 then
            Fluent:Notify({ Title = "エラー", Content = "ロール対象がありません", Duration = 3 })
            return
        end
        local rollRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Open")
        if not rollRemote then
            Fluent:Notify({ Title = "エラー", Content = "Openリモートが見つかりません", Duration = 3 })
            return
        end
        for _, dtype in ipairs(activeRollDiceTypes) do
            pcall(function()
                rollRemote:InvokeServer(dtype, 10, true)
            end)
            task.wait(rollDelay)
        end
        Fluent:Notify({ Title = "Roll", Content = "全選択ダイスを実行しました", Duration = 2 })
    end
})

-- ==========================================
-- Settings Tab
-- ==========================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/ZombieFarm")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

if SwingRemote then
    Fluent:Notify({ Title = "System Loaded", Content = "リモート接続完了。モバイル操作可能です。", Duration = 4 })
else
    Fluent:Notify({ Title = "⚠️ 警告", Content = "Swingリモートが見つかりません。", Duration = 5 })
end
