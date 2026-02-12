local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- === 1. 設定フラグ ===
local config = {
    aimbot = false,
    autoShoot = false,
    wallCheck = true,
    teamCheck = true,
    esp = false,
    itemEsp = false,
    infStamina = false,
    rainbow = false,
    outlineOnly = false,
    crosshair = true,
    fov120 = false,
    fovSize = 150
}

-- === 2. 陣営判定 (財団同盟 & 反乱軍同盟) ===
local function isEnemy(p)
    if not config.teamCheck then return true end
    if not p.Team or not LocalPlayer.Team then return true end
    local myT, enT = LocalPlayer.Team.Name:lower(), p.Team.Name:lower()
    if myT == enT then return false end
    local isMyFound = myT:find("security") or myT:find("task force") or myT:find("scientific") or myT:find("foundation") or myT:find("medical") or myT:find("logic") or myT:find("admin")
    local isEnFound = enT:find("security") or enT:find("task force") or enT:find("scientific") or enT:find("foundation") or enT:find("medical") or enT:find("logic") or enT:find("admin")
    local isMyHostile = myT:find("class") or myT:find("chaos")
    local isEnHostile = enT:find("class") or enT:find("chaos")
    if (isMyFound and isEnFound) or (isMyHostile and isEnHostile) then return false end
    return true
end

-- === 3. UI構築 (安定化版) ===
local function setupUI()
    local old = LocalPlayer.PlayerGui:FindFirstChild("UltraV66")
    if old then old:Destroy() end
    
    local gui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    gui.Name = "UltraV66"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999 -- 最前面に表示

    local main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, 180, 0, 320)
    main.Position = UDim2.new(0.1, 0, 0.3, 0)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.Active = true
    main.ClipsDescendants = true -- これがないと収納時に中身がはみ出る
    Instance.new("UICorner", main)

    -- ドラッグ機能
    local dragging, dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function() dragging = false end)

    -- タイトルバー兼収納ボタン
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    title.Text = "  UltraHub v6.6"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = "SourceSansBold"

    local hideBtn = Instance.new("TextButton", main)
    hideBtn.Size = UDim2.new(0, 30, 0, 30)
    hideBtn.Position = UDim2.new(1, -30, 0, 0)
    hideBtn.Text = "-"
    hideBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
    hideBtn.TextColor3 = Color3.new(1, 1, 1)
    hideBtn.ZIndex = 10 -- 常に上に

    local isShrunk = false
    hideBtn.MouseButton1Click:Connect(function()
        isShrunk = not isShrunk
        main:TweenSize(isShrunk and UDim2.new(0, 180, 0, 30) or UDim2.new(0, 180, 0, 320), "Out", "Quart", 0.3, true)
        hideBtn.Text = isShrunk and "+" or "-"
    end)

    -- スクロールエリア
    local scroll = Instance.new("ScrollingFrame", main)
    scroll.Size = UDim2.new(1, 0, 1, -30)
    scroll.Position = UDim2.new(0, 0, 0, 30)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0, 0, 0, 550)
    scroll.ScrollBarThickness = 3

    local btns = {}
    local function create(text, y, key)
        local b = Instance.new("TextButton", scroll)
        b.Size = UDim2.new(0, 160, 0, 35)
        b.Position = UDim2.new(0, 10, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Text = text .. ": OFF"
        Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(function() config[key] = not config[key] end)
        btns[key] = b
    end

    create("Aimbot", 5, "aimbot"); create("Auto Shoot", 45, "autoShoot"); create("Wall Check", 85, "wallCheck")
    create("Team Check", 125, "teamCheck"); create("Player ESP", 165, "esp"); create("Item ESP", 205, "itemEsp")
    create("Inf Stamina", 245, "infStamina"); create("Weapon Glow", 285, "rainbow"); create("Outline Only", 325, "outlineOnly")
    create("FOV 120", 365, "fov120"); create("Crosshair", 405, "crosshair")

    -- クロスヘア
    local chGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui); chGui.Name = "UltraCH"; chGui.IgnoreGuiInset = true
    local ch = Instance.new("Frame", chGui); ch.Size = UDim2.new(0, 0, 0, 0); ch.Position = UDim2.new(0.5, 0, 0.5, 0); ch.BackgroundTransparency = 1
    local hl = Instance.new("Frame", ch); hl.Size = UDim2.new(0, 14, 0, 2); hl.BorderSizePixel = 0; hl.AnchorPoint = Vector2.new(0.5, 0.5)
    local vl = Instance.new("Frame", ch); vl.Size = UDim2.new(0, 2, 0, 14); vl.BorderSizePixel = 0; vl.AnchorPoint = Vector2.new(0.5, 0.5)

    return btns, ch, hl, vl
end

local btns, chFrame, hLine, vLine = setupUI()

-- === 4. メインループ ===
RunService.RenderStepped:Connect(function()
    local rainbow = Color3.fromHSV((tick() * 0.5) % 1, 0.8, 1)
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for k, b in pairs(btns) do
        if config[k] then b.BackgroundColor3 = Color3.fromRGB(30, 150, 30) else b.BackgroundColor3 = Color3.fromRGB(60, 20, 20) end
        b.Text = k:upper():gsub("TEAMCHECK", "TEAM CHECK") .. ": " .. (config[k] and "ON" or "OFF")
    end

    local target = nil
    local dist = config.fovSize

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
            local char = p.Character
            if config.esp then
                local hl = char:FindFirstChild("ESPHL") or Instance.new("Highlight", char); hl.Name = "ESPHL"; hl.FillColor = p.TeamColor.Color; hl.DepthMode = 0
                local tag = char.Head:FindFirstChild("ESPTag") or Instance.new("BillboardGui", char.Head); tag.Name = "ESPTag"; tag.Size = UDim2.new(0,100,0,40); tag.AlwaysOnTop = true; tag.StudsOffset = Vector3.new(0,3,0)
                local l = tag:FindFirstChild("Info") or Instance.new("TextLabel", tag); l.Name = "Info"; l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1; l.TextColor3 = p.TeamColor.Color; l.TextSize = 10; l.Font = "SourceSansBold"
                l.Text = string.format("%s\nHP:%d", p.Name, math.floor(char.Humanoid.Health))
            else
                if char:FindFirstChild("ESPHL") then char.ESPHL:Destroy() end
                if char.Head:FindFirstChild("ESPTag") then char.Head.ESPTag:Destroy() end
            end
            if char.Humanoid.Health > 0 and isEnemy(p) then
                local pos, on = Camera:WorldToViewportPoint(char.Head.Position)
                if on then
                    local mag = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if mag < dist and (not config.wallCheck or #Camera:GetPartsObscuringTarget({Camera.CFrame.Position, char.Head.Position}, {LocalPlayer.Character, char}) == 0) then target = char.Head; dist = mag end
                end
            end
        end
    end

    if config.aimbot and target then Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), 0.8) end
    if config.infStamina and LocalPlayer.Character:FindFirstChild("Stamina") then LocalPlayer.Character.Stamina.Value = 100 end
    Camera.FieldOfView = config.fov120 and 120 or 70

    if config.crosshair then
        chFrame.Visible = true; chFrame.Rotation = (chFrame.Rotation + 6) % 360
        hLine.BackgroundColor3 = rainbow; vLine.BackgroundColor3 = rainbow
    else chFrame.Visible = false end

    -- 武器光り (Viewmodel対応)
    if config.rainbow then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            local hl = tool:FindFirstChild("WG") or Instance.new("Highlight", tool); hl.Name = "WG"; hl.OutlineColor = rainbow; hl.FillColor = rainbow; hl.FillTransparency = config.outlineOnly and 1 or 0.4; hl.DepthMode = 0
        end
        for _, v in pairs(Camera:GetChildren()) do
            if v:IsA("Model") or v.Name:lower():find("gun") then
                local hl = v:FindFirstChild("WG") or Instance.new("Highlight", v); hl.Name = "WG"; hl.OutlineColor = rainbow; hl.FillColor = rainbow; hl.FillTransparency = config.outlineOnly and 1 or 0.4; hl.DepthMode = 0
            end
        end
    end
end)
