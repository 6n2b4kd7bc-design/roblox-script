local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- === 1. 設定 ===
_G.TrollConfig = _G.TrollConfig or {
    autoChest = false, autoKill = false, esp = false, fullBright = false,
    speedHack = false, antiAFK = true, showStats = true,
    walkSpeed = 100, scanRange = 2500
}
local config = _G.TrollConfig

-- 【追加】でかいUI操作用の参照変数
local bigChestUI, chestCountLabelObj, mainChestBtnObj

-- === 2. ドラッグ移動 (PC/Mobile対応) ===
local function makeDraggable(gui, dragPart)
    local dragging, dragStart, startPos
    dragPart.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = gui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- === 3. ESP & ステータス更新 (描画ループ) ===
local function setupUI()
    local pgui = LocalPlayer:WaitForChild("PlayerGui")
    if pgui:FindFirstChild("TrollHubV63") then pgui.TrollHubV63:Destroy() end
    local gui = Instance.new("ScreenGui", pgui); gui.Name = "TrollHubV63"; gui.ResetOnSpawn = false
    
    -- FPS/Ping表示
    local sF = Instance.new("Frame", gui); sF.Size = UDim2.new(0, 120, 0, 50); sF.Position = UDim2.new(0.02, 0, 0.2, 0); sF.BackgroundColor3 = Color3.new(0,0,0); sF.BackgroundTransparency = 0.5; sF.Visible = config.showStats; Instance.new("UICorner", sF)
    local fL = Instance.new("TextLabel", sF); fL.Size = UDim2.new(1,0,0.5,0); fL.BackgroundTransparency = 1; fL.TextColor3 = Color3.new(0,1,0); fL.Text = "FPS: --"
    local pL = Instance.new("TextLabel", sF); pL.Size = UDim2.new(1,0,0.5,0); pL.Position = UDim2.new(0,0,0.5,0); pL.BackgroundTransparency = 1; pL.TextColor3 = Color3.new(1,1,0); pL.Text = "Ping: --"

    -- メインUI
    local main = Instance.new("Frame", gui); main.Size = UDim2.new(0, 160, 0, 350); main.Position = UDim2.new(0.02, 0, 0.3, 0); main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); main.ClipsDescendants = true; Instance.new("UICorner", main)
    local title = Instance.new("TextLabel", main); title.Size = UDim2.new(1, 0, 0, 30); title.Text = "Troll v6.4"; title.TextColor3 = Color3.new(1, 1, 1); title.BackgroundColor3 = Color3.fromRGB(40, 40, 60); Instance.new("UICorner", title)
    makeDraggable(main, title)

    local hB = Instance.new("TextButton", title); hB.Size = UDim2.new(0, 25, 0, 25); hB.Position = UDim2.new(1, -28, 0, 2.5); hB.Text = "-"; hB.TextColor3 = Color3.new(1,1,1); hB.BackgroundTransparency = 1
    local col = false; hB.MouseButton1Click:Connect(function()
        col = not col; main:TweenSize(col and UDim2.new(0, 160, 0, 30) or UDim2.new(0, 160, 0, 350), "Out", "Quart", 0.3, true); hB.Text = col and "+" or "-"
    end)

    -- 【追加】でかいUI（画面中央）
    bigChestUI = Instance.new("Frame", gui)
    bigChestUI.Size = UDim2.new(0, 300, 0, 150)
    bigChestUI.Position = UDim2.new(0.5, -150, 0.5, -75) -- 画面ド真ん中
    bigChestUI.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    bigChestUI.Visible = config.autoChest
    Instance.new("UICorner", bigChestUI)

    chestCountLabelObj = Instance.new("TextLabel", bigChestUI)
    chestCountLabelObj.Size = UDim2.new(1, 0, 0.6, 0)
    chestCountLabelObj.Text = "残りチェスト: 検索中..."
    chestCountLabelObj.TextColor3 = Color3.new(1, 1, 1)
    chestCountLabelObj.TextScaled = true
    chestCountLabelObj.BackgroundTransparency = 1

    local chestOffBtn = Instance.new("TextButton", bigChestUI)
    chestOffBtn.Size = UDim2.new(0.6, 0, 0.3, 0)
    chestOffBtn.Position = UDim2.new(0.2, 0, 0.65, 0)
    chestOffBtn.Text = "OFF"
    chestOffBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    chestOffBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", chestOffBtn)

    -- 【追加】OFFボタンを押したときの処理
    chestOffBtn.MouseButton1Click:Connect(function()
        config.autoChest = false
        bigChestUI.Visible = false
        if mainChestBtnObj then
            mainChestBtnObj.BackgroundColor3 = Color3.fromRGB(30, 30, 40) -- メインUIのボタン色を元に戻す
        end
    end)

    local function createToggle(text, y, key, cb)
        local b = Instance.new("TextButton", main); b.Size = UDim2.new(0, 140, 0, 35); b.Position = UDim2.new(0, 10, 0, 40 + y); b.Text = text; b.BackgroundColor3 = config[key] and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(30, 30, 40); b.TextColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", b)
        
        -- 【追加】AUTO CHESTボタンの参照を保存しておく
        if key == "autoChest" then mainChestBtnObj = b end

        b.MouseButton1Click:Connect(function() 
            config[key] = not config[key]; b.BackgroundColor3 = config[key] and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(30, 30, 40)
            if cb then cb(config[key]) end 
        end)
    end
    
    -- 【変更】AUTO CHESTのコールバックで、でかいUIの表示/非表示を切り替えるように指定
    createToggle("AUTO CHEST", 0, "autoChest", function(v) if bigChestUI then bigChestUI.Visible = v end end); 
    createToggle("AUTO KILL", 45, "autoKill"); createToggle("ESP", 90, "esp"); createToggle("BRIGHT", 135, "fullBright"); createToggle("SPEED", 180, "speedHack"); createToggle("STATS", 225, "showStats", function(v) sF.Visible = v end)

    -- 更新ループ (FPS/Ping/ESP)
    RunService.RenderStepped:Connect(function(dt)
        if sF.Visible then
            fL.Text = "FPS: " .. math.floor(1/dt)
            pL.Text = "Ping: " .. math.floor(LocalPlayer:GetNetworkPing() * 1000) .. "ms"
        end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
                local tag = p.Character.Head:FindFirstChild("TrollTag") or Instance.new("BillboardGui", p.Character.Head)
                tag.Name = "TrollTag"; tag.AlwaysOnTop = true; tag.Size = UDim2.new(0, 100, 0, 40); tag.Enabled = config.esp
                local lbl = tag:FindFirstChild("Label") or Instance.new("TextLabel", tag)
                lbl.Name = "Label"; lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.new(1,1,1); lbl.TextStrokeTransparency = 0
                local hp = p.Character:FindFirstChild("Humanoid") and math.floor(p.Character.Humanoid.Health) or 0
                lbl.Text = p.DisplayName .. "\nHP: " .. hp
            end
        end
        if config.speedHack and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = config.walkSpeed end
        if config.fullBright then Lighting.Brightness = 2; Lighting.ClockTime = 14 end
    end)
end

-- === 4. 厳選テレポート (NPC/置物スルー) ===
task.spawn(function()
    while true do
        pcall(function()
            if not (config.autoChest or config.autoKill) then task.wait(0.5) return end
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not root then task.wait(0.5) return end
            
            local target, isChest, dist = nil, false, config.scanRange
            local currentChestCount = 0 -- 【追加】チェストの数を数える変数
            
            if config.autoChest then
                for _, p in pairs(workspace:GetDescendants()) do
                    if p:IsA("ProximityPrompt") and p.Enabled then
                        local obj = p.Parent
                        if obj:IsA("BasePart") then
                            local txt = (obj.Name .. obj.Parent.Name .. p.ActionText):lower()
                            -- 宝箱キーワードが含まれ、かつショップ/NPCワードが含まれない場合のみ
                            if (txt:find("chest") or txt:find("drop") or txt:find("loot")) and 
                               not (txt:find("shop") or txt:find("npc") or txt:find("buy") or txt:find("talk")) then
                                
                                currentChestCount = currentChestCount + 1 -- 【追加】チェストの数をカウント

                                local d = (root.Position - obj.Position).Magnitude
                                if d < dist then target = obj; dist = d; isChest = true end
                            end
                        end
                    end
                end
            end
            
            -- 【修正】でかいUIのチェスト数を毎秒更新（3個ズレ修正＆対象なしの時は0）
            if chestCountLabelObj and config.autoChest then
                local displayCount = currentChestCount - 3
                if not target or displayCount < 0 then
                    displayCount = 0
                end
                chestCountLabelObj.Text = "残りチェスト: " .. displayCount
            end

            if not target and config.autoKill then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if p.Character.Humanoid.Health > 0 then
                            local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                            if d < dist then target = p.Character.HumanoidRootPart; dist = d; isChest = false end
                        end
                    end
                end
            end
            if target then
                root.CFrame = isChest and target.CFrame or target.CFrame * CFrame.new(0, 0, 3)
                if isChest then
                    task.wait(0.1); fireproximityprompt(target:FindFirstChildOfClass("ProximityPrompt") or target.Parent:FindFirstChildOfClass("ProximityPrompt"))
                else
                    game:GetService("VirtualUser"):Button1Down(Vector2.new(0,0))
                end
            end
        end)
        task.wait(0.1)
    end
end)

setupUI()
