local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- === 1. ロード画面の作成 ===
local pgui
local success = pcall(function() pgui = CoreGui end)
if not success or not pgui then pgui = LocalPlayer:WaitForChild("PlayerGui") end

if pgui:FindFirstChild("MotobuLoadingUI") then
    pgui.MotobuLoadingUI:Destroy()
end

local loadGui = Instance.new("ScreenGui", pgui)
loadGui.Name = "MotobuLoadingUI"
loadGui.IgnoreGuiInset = true
loadGui.ResetOnSpawn = false

local bg = Instance.new("Frame", loadGui)
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
bg.BackgroundTransparency = 0.4

local mainFrame = Instance.new("Frame", bg)
mainFrame.Size = UDim2.new(0, 320, 0, 120)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -60)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "MotobuV20 起動中..."
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18

local statusText = Instance.new("TextLabel", mainFrame)
statusText.Size = UDim2.new(1, 0, 0, 20)
statusText.Position = UDim2.new(0, 0, 0, 45)
statusText.BackgroundTransparency = 1
statusText.Text = "システムを初期化しています..."
statusText.TextColor3 = Color3.fromRGB(180, 180, 180)
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 13

local barBg = Instance.new("Frame", mainFrame)
barBg.Size = UDim2.new(0.85, 0, 0, 10)
barBg.Position = UDim2.new(0.075, 0, 0, 85)
barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

local barFill = Instance.new("Frame", barBg)
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

local function updateLoad(text, percent)
    statusText.Text = text
    TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
    task.wait(0.3)
end

-- === 2. スクリプトのロード開始 ===
task.spawn(function()
    updateLoad("環境変数を確認中...", 0.2)
    task.wait(0.5)

    updateLoad("Rayfield UI をダウンロード中 (時間がかかります)...", 0.4)
    
    -- UIライブラリの読み込み
    local Rayfield
    local loadSuccess, loadError = pcall(function()
        Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)

    if not loadSuccess or not Rayfield then
        updateLoad("UIのダウンロードに失敗しました！", 0)
        statusText.TextColor3 = Color3.new(1, 0.3, 0.3)
        task.wait(3)
        loadGui:Destroy()
        return
    end

    updateLoad("UIウィンドウを構築中...", 0.7)
    
    local Window = Rayfield:CreateWindow({
       Name = "MotobuV20 - Rayfield Hub",
       LoadingTitle = "MotobuV20 Hub",
       LoadingSubtitle = "by Motobu",
       ConfigurationSaving = { Enabled = false },
       Discord = { Enabled = false },
       KeySystem = false
    })

    local TabMain = Window:CreateTab("メイン機能", 4483362458)
    local TabCustom = Window:CreateTab("カスタマイズ", 4483362458)
    local TabESP = Window:CreateTab("ESP / 視覚化", 4483362458)

    updateLoad("各機能モジュールをセットアップ中...", 0.9)

    -- =========================================
    -- 【新規】 カスタマイズ機能タブ
    -- =========================================
    TabCustom:CreateSection("キャラクター変更 (未所持使用可)")
    TabCustom:CreateDropdown({
       Name = "👤 キャラクターを選択",
       Options = {"RANGER", "LOBBER", "ZOOMER", "BLASTER"},
       CurrentOption = {"RANGER"},
       Flag = "ClassSelect",
       Callback = function(Option)
          local selectedClass = type(Option) == "table" and Option[1] or Option
          pcall(function()
             ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("ChangeClass"):FireServer(selectedClass)
          end)
          Rayfield:Notify({Title = "クラス変更", Content = selectedClass .. " に変更しました", Duration = 2})
       end,
    })

    TabCustom:CreateSection("スキン(色)変更")
    TabCustom:CreateDropdown({
       Name = "🎨 スキンカラーを選択",
       Options = {"Rusty Brown", "White", "Blackberry"},
       CurrentOption = {"Rusty Brown"},
       Flag = "ColorSelect",
       Callback = function(Option)
          local selectedColor = type(Option) == "table" and Option[1] or Option
          pcall(function()
             ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("ChangeColor"):FireServer(selectedColor)
          end)
          Rayfield:Notify({Title = "カラー変更", Content = selectedColor .. " に変更しました", Duration = 2})
       end,
    })

    TabCustom:CreateSection("武器スキン変更")
    TabCustom:CreateDropdown({
       Name = "🧹 武器スキンを選択",
       Options = {"Snare Smacker", "Bubble Wand", "Last Supper", "Undercover", "Toilet Brush"},
       CurrentOption = {"Snare Smacker"},
       Flag = "BroomSelect",
       Callback = function(Option)
          local selectedBroom = type(Option) == "table" and Option[1] or Option
          pcall(function()
             ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("ChangeBroom"):FireServer(selectedBroom)
          end)
          Rayfield:Notify({Title = "武器スキン変更", Content = selectedBroom .. " に変更しました", Duration = 2})
       end,
    })

    -- =========================================
    -- メイン機能タブ: ボタンロード ＆ 射撃カスタマイズ
    -- =========================================
    TabMain:CreateSection("🔫 射撃カスタマイズ & ボタン")

    local currentGunMode = "SmallShot"
    TabMain:CreateDropdown({
       Name = "🎯 射撃モード選択",
       Options = {"SmallShot", "HipShot", "Both"},
       CurrentOption = {"SmallShot"},
       Flag = "GunModeSelect",
       Callback = function(Option)
          currentGunMode = type(Option) == "table" and Option[1] or Option
          Rayfield:Notify({Title = "モード変更", Content = "射撃モードを [" .. currentGunMode .. "] に設定しました", Duration = 2})
       end,
    })

    TabMain:CreateButton({
       Name = "🔫 モバイル用 銃撃連打ボタンをロード",
       Callback = function()
          task.spawn(function()
             local Event = ReplicatedStorage:WaitForChild("WeaponRemotes"):WaitForChild("Initiate")
             if pgui:FindFirstChild("MobileSpammerUI") then pgui.MobileSpammerUI:Destroy() end
             
             local spamGui = Instance.new("ScreenGui", pgui)
             spamGui.Name = "MobileSpammerUI"
             spamGui.ResetOnSpawn = false

             local toggleBtn = Instance.new("TextButton", spamGui)
             toggleBtn.Size = UDim2.new(0, 140, 0, 60)
             toggleBtn.Position = UDim2.new(0.75, -70, 0.7, -30)
             toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
             toggleBtn.Text = "💥 連打: OFF"
             toggleBtn.TextColor3 = Color3.new(1, 1, 1)
             toggleBtn.Font = Enum.Font.GothamBold
             toggleBtn.TextSize = 16
             Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

             local btnDragging, btnDragStart, btnStartPos
             toggleBtn.InputBegan:Connect(function(input)
                 if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                     btnDragging = true; btnDragStart = input.Position; btnStartPos = toggleBtn.Position
                     input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
                 end
             end)
             toggleBtn.InputChanged:Connect(function(input)
                 if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                     local delta = input.Position - btnDragStart
                     toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
                 end
             end)

             local function getCenterTargetPosition()
                 local raycastParams = RaycastParams.new()
                 raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                 if LocalPlayer.Character then raycastParams.FilterDescendantsInstances = {LocalPlayer.Character} end
                 local rayOrigin = Camera.CFrame.Position
                 local rayDirection = Camera.CFrame.LookVector * 1000
                 local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                 return raycastResult and raycastResult.Position or (rayOrigin + rayDirection)
             end

             local function sendShot(gunCF, mousePos)
                 local data = {GunCF = gunCF, MousePos = mousePos}
                 if currentGunMode == "SmallShot" then
                     Event:FireServer("SmallShot", data)
                 elseif currentGunMode == "HipShot" then
                     Event:FireServer("HipShot", data)
                 elseif currentGunMode == "Both" then
                     Event:FireServer("SmallShot", data)
                     Event:FireServer("HipShot", data)
                 end
             end

             local isSpamming = false
             toggleBtn.MouseButton1Click:Connect(function()
                 isSpamming = not isSpamming
                 if isSpamming then
                     toggleBtn.Text = "🔥 連打: ON"
                     toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                     task.spawn(function()
                         while isSpamming do
                             pcall(function() sendShot(Camera.CFrame, getCenterTargetPosition()) end)
                             task.wait(0.02)
                         end
                     end)
                 else
                     toggleBtn.Text = "💥 連打: OFF"
                     toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                 end
             end)
             Rayfield:Notify({Title = "ロード完了", Content = "モード切替対応の連打ボタンを表示しました", Duration = 2})
          end)
       end,
    })

    TabMain:CreateButton({
       Name = "🔪 モバイル用 アイテム連打ボタンをロード",
       Callback = function()
          task.spawn(function()
             local Event = ReplicatedStorage:WaitForChild("WeaponRemotes"):WaitForChild("ActivateItem")
             if pgui:FindFirstChild("ItemSpammerUI") then pgui.ItemSpammerUI:Destroy() end
             local spamGui = Instance.new("ScreenGui", pgui)
             spamGui.Name = "ItemSpammerUI"
             spamGui.ResetOnSpawn = false

             local toggleBtn = Instance.new("TextButton", spamGui)
             toggleBtn.Size = UDim2.new(0, 140, 0, 60)
             toggleBtn.Position = UDim2.new(0.75, -70, 0.5, -30)
             toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
             toggleBtn.Text = "🔪 アイテム連打: OFF"
             toggleBtn.TextColor3 = Color3.new(1, 1, 1)
             toggleBtn.Font = Enum.Font.GothamBold
             toggleBtn.TextSize = 14
             Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

             local btnDragging, btnDragStart, btnStartPos
             toggleBtn.InputBegan:Connect(function(input)
                 if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                     btnDragging = true; btnDragStart = input.Position; btnStartPos = toggleBtn.Position
                     input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then btnDragging = false end end)
                 end
             end)
             toggleBtn.InputChanged:Connect(function(input)
                 if btnDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                     local delta = input.Position - btnDragStart
                     toggleBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
                 end
             end)

             local isSpamming = false
             toggleBtn.MouseButton1Click:Connect(function()
                 isSpamming = not isSpamming
                 if isSpamming then
                     toggleBtn.Text = "🔥 アイテム連打: ON"
                     toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
                     task.spawn(function()
                         while isSpamming do
                             pcall(function() Event:FireServer("endCharge", "R", Camera.CFrame) end)
                             task.wait(0.05)
                         end
                     end)
                 else
                     toggleBtn.Text = "🔪 アイテム連打: OFF"
                     toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
                 end
             end)
             Rayfield:Notify({Title = "ロード完了", Content = "アイテム連打ボタンを表示しました", Duration = 2})
          end)
       end,
    })

    TabMain:CreateSection("自動化・戦闘トグル")

    local isBuddyActive = false
    TabMain:CreateToggle({
       Name = "🧸 Buddy自動回収",
       CurrentValue = false,
       Flag = "BuddyToggle",
       Callback = function(Value)
          isBuddyActive = Value
          if isBuddyActive then
             task.spawn(function()
                local Event = ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("AntiquesAndHolding"):WaitForChild("HoldObject")
                while isBuddyActive do
                   pcall(function()
                      local buddytv = workspace:FindFirstChild("BUDDYTV")
                      if buddytv then
                         local buddy = buddytv:FindFirstChild("Buddy")
                         if buddy then Event:FireServer("Start", buddy, "BuddyHold") end
                      end
                   end)
                   task.wait(0.5)
                end
             end)
          end
       end,
    })

    local isMoneyActive = false
    TabMain:CreateToggle({
       Name = "💰 お金(Celz)自動回収",
       CurrentValue = false,
       Flag = "MoneyToggle",
       Callback = function(Value)
          isMoneyActive = Value
          if isMoneyActive then
             task.spawn(function()
                local Event = ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("Shop"):WaitForChild("CelzCollect")
                while isMoneyActive do
                   local foundCelz = {}
                   for _, obj in pairs(workspace:GetDescendants()) do
                      if obj.Name:match("^Celz%d+$") then table.insert(foundCelz, obj) end
                   end
                   pcall(function()
                      if getnilinstances then
                         for _, obj in pairs(getnilinstances()) do
                            if obj and obj.Name:match("^Celz%d+$") then table.insert(foundCelz, obj) end
                         end
                      end
                   end)
                   for _, obj in pairs(foundCelz) do
                      local valueStr = obj.Name:match("%d+")
                      if valueStr then pcall(function() Event:FireServer(tonumber(valueStr), obj) end) end
                   end
                   task.wait(1)
                end
             end)
          end
       end,
    })

    local isAntiqueActive = false
    TabMain:CreateToggle({
       Name = "🏺 骨董品自動回収",
       CurrentValue = false,
       Flag = "AntiqueToggle",
       Callback = function(Value)
          isAntiqueActive = Value
          if isAntiqueActive then
             task.spawn(function()
                local Event = ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("AntiquesAndHolding"):WaitForChild("HoldObject")
                while isAntiqueActive do
                   pcall(function()
                      local addedAntiques = workspace:FindFirstChild("AddedAntiques")
                      if addedAntiques then
                         for _, antique in pairs(addedAntiques:GetChildren()) do
                            Event:FireServer("Start", antique, "NormalHold")
                         end
                      end
                   end)
                   task.wait(1)
                end
             end)
          end
       end,
    })

    local isKillAuraActive = false
    TabMain:CreateToggle({
       Name = "⚔️ 遠隔キル (Kill Aura)",
       CurrentValue = false,
       Flag = "KillAuraToggle",
       Callback = function(Value)
          isKillAuraActive = Value
          if isKillAuraActive then
             task.spawn(function()
                local Event = ReplicatedStorage:WaitForChild("WeaponRemotes"):WaitForChild("Attack")
                while isKillAuraActive do
                   pcall(function()
                      local monsterContainer = workspace:FindFirstChild("MonsterContainer")
                      if monsterContainer then
                         for _, monster in pairs(monsterContainer:GetChildren()) do
                            local targetPart = monster:FindFirstChild("Icosphere") or monster:FindFirstChildWhichIsA("BasePart")
                            if targetPart then
                               local weaponName = "Broom"
                               local char = LocalPlayer.Character
                               if char then
                                  local equippedTool = char:FindFirstChildOfClass("Tool")
                                  if equippedTool then weaponName = equippedTool.Name end
                               end
                               Event:FireServer(targetPart, weaponName, { CFrame = targetPart.CFrame })
                            end
                         end
                      end
                   end)
                   task.wait(0.2)
                end
             end)
          end
       end,
    })

    local isAutoCleanActive = false
    TabMain:CreateToggle({
       Name = "🧹 自動掃除 (Stains)",
       CurrentValue = false,
       Flag = "AutoCleanToggle",
       Callback = function(Value)
          isAutoCleanActive = Value
          if isAutoCleanActive then
             task.spawn(function()
                local Event = ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("WeaponsEtc"):WaitForChild("CleaningFurniture")
                while isAutoCleanActive do
                   pcall(function()
                      local addedStains = workspace:FindFirstChild("AddedStains")
                      if addedStains then
                         local stains = addedStains:GetChildren()
                         for i = 1, #stains do
                            if not isAutoCleanActive then break end
                            for j = 1, 5 do Event:FireServer(stains[i], 1) end
                         end
                      end
                   end)
                   task.wait(0.5)
                end
             end)
          end
       end,
    })

    local isFurnitureCleanActive = false
    TabMain:CreateToggle({
       Name = "⚡ 超高速オート家具掃除",
       CurrentValue = false,
       Flag = "FurnitureCleanToggle",
       Callback = function(Value)
          isFurnitureCleanActive = Value
          if isFurnitureCleanActive then
             task.spawn(function()
                local Event = ReplicatedStorage:WaitForChild("ChillAhhRemotes"):WaitForChild("WeaponsEtc"):WaitForChild("CleaningFurniture")
                while isFurnitureCleanActive do
                   pcall(function()
                      local mapGen = workspace:FindFirstChild("MapGen")
                      if mapGen then
                         for _, room in pairs(mapGen:GetChildren()) do
                            for _, furniture in pairs(room:GetChildren()) do
                               if not isFurnitureCleanActive then break end
                               if furniture:IsA("Model") or furniture:IsA("BasePart") then
                                  for i = 1, 5 do Event:FireServer(furniture, 1) end
                                  task.wait(0.001)
                               end
                            end
                         end
                      end
                   end)
                   task.wait(0.1)
                end
             end)
          end
       end,
    })

    -- =========================================
    -- ESP 機能タブ
    -- =========================================
    TabESP:CreateSection("視覚化 (ESP)")

    local isStainEspActive = false
    TabESP:CreateToggle({
       Name = "🧽 Stains 近距離ESP (80studs)",
       CurrentValue = false,
       Flag = "StainEspToggle",
       Callback = function(Value)
          isStainEspActive = Value
          if isStainEspActive then
             task.spawn(function()
                while isStainEspActive do
                   pcall(function()
                      local char = LocalPlayer.Character
                      local hrp = char and char:FindFirstChild("HumanoidRootPart")
                      local addedStains = workspace:FindFirstChild("AddedStains")

                      if hrp and addedStains then
                         for _, stain in pairs(addedStains:GetChildren()) do
                            local targetPart = stain:IsA("BasePart") and stain or stain:FindFirstChildWhichIsA("BasePart")
                            if targetPart then
                               local dist = (targetPart.Position - hrp.Position).Magnitude
                               local espGui = targetPart:FindFirstChild("StainESP_Motobu")
                               if dist <= 80 then
                                  if not espGui then
                                     espGui = Instance.new("BillboardGui", targetPart)
                                     espGui.Name = "StainESP_Motobu"
                                     espGui.Size = UDim2.new(0, 80, 0, 20)
                                     espGui.AlwaysOnTop = true
                                     local text = Instance.new("TextLabel", espGui)
                                     text.Size = UDim2.new(1, 0, 1, 0)
                                     text.BackgroundTransparency = 1
                                     text.Text = "🧽 汚れ"
                                     text.TextColor3 = Color3.new(0.5, 1, 0.5)
                                     text.TextStrokeTransparency = 0.5
                                     text.TextScaled = true
                                     text.Font = Enum.Font.GothamBold
                                  end
                                  espGui.Enabled = true
                               else
                                  if espGui then espGui.Enabled = false end
                               end
                            end
                         end
                      end
                   end)
                   task.wait(0.5)
                end
                local addedStains = workspace:FindFirstChild("AddedStains")
                if addedStains then
                   for _, stain in pairs(addedStains:GetDescendants()) do
                      if stain.Name == "StainESP_Motobu" then stain:Destroy() end
                   end
                end
             end)
          end
       end,
    })

    local isMonsterEspActive = false
    TabESP:CreateToggle({
       Name = "👹 敵 (Monster) ESP",
       CurrentValue = false,
       Flag = "MonsterEspToggle",
       Callback = function(Value)
          isMonsterEspActive = Value
          if isMonsterEspActive then
             task.spawn(function()
                while isMonsterEspActive do
                   pcall(function()
                      local monsterContainer = workspace:FindFirstChild("MonsterContainer")
                      if monsterContainer then
                         for _, monster in pairs(monsterContainer:GetChildren()) do
                            local targetPart = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChildWhichIsA("BasePart") or monster
                            if targetPart and not monster:FindFirstChild("ESP_Highlight_Motobu") then
                               local highlight = Instance.new("Highlight")
                               highlight.Name = "ESP_Highlight_Motobu"
                               highlight.Parent = monster
                               highlight.FillColor = Color3.new(1, 0, 0)
                               highlight.OutlineColor = Color3.new(1, 1, 1)
                               highlight.FillTransparency = 0.5
                               highlight.OutlineTransparency = 0

                               local billboard = Instance.new("BillboardGui")
                               billboard.Name = "ESP_Billboard_Motobu"
                               billboard.Parent = targetPart
                               billboard.Size = UDim2.new(0, 100, 0, 30)
                               billboard.AlwaysOnTop = true
                               billboard.StudsOffset = Vector3.new(0, 3, 0)

                               local text = Instance.new("TextLabel", billboard)
                               text.Size = UDim2.new(1, 0, 1, 0)
                               text.BackgroundTransparency = 1
                               text.Text = "👹 敵"
                               text.TextColor3 = Color3.new(1, 0.2, 0.2)
                               text.TextStrokeTransparency = 0
                               text.TextScaled = true
                               text.Font = Enum.Font.GothamBold
                            end
                         end
                      end
                   end)
                   task.wait(1)
                end
                pcall(function()
                   local monsterContainer = workspace:FindFirstChild("MonsterContainer")
                   if monsterContainer then
                      for _, monster in pairs(monsterContainer:GetChildren()) do
                         local hl = monster:FindFirstChild("ESP_Highlight_Motobu")
                         if hl then hl:Destroy() end
                         local targetPart = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChildWhichIsA("BasePart") or monster
                         if targetPart then
                            local bb = targetPart:FindFirstChild("ESP_Billboard_Motobu")
                            if bb then bb:Destroy() end
                         end
                      end
                   end
                end)
             end)
          end
       end,
    })

    updateLoad("完了！UIを起動します...", 1)
    task.wait(0.5)

    -- ロード画面を削除
    if loadGui then loadGui:Destroy() end
end)
