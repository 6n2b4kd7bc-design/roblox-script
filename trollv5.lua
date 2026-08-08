local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local cfg = {
    api = "8d65b9f4-b94e-4aef-b3d0-68710a307194",
    service = "universal troll",
    provider = "minitomato1900",
    discord = "https://work.ink/29FJ/first-step",
    logo = "rbxassetid://121595097202790",
    barColor = Color3.fromRGB(90,170,255),
    keyFile = "&R4_key2.txt"
}

local notifActive = {}

local function createNotification(title,content,length,iconId)
    local screen = Instance.new("ScreenGui")
    screen.Name = "NotifGui"
    screen.ResetOnSpawn = false
    screen.DisplayOrder = 2147483647
    screen.Parent = CoreGui

    local scale = math.clamp(math.min(workspace.CurrentCamera.ViewportSize.X,workspace.CurrentCamera.ViewportSize.Y)/1366,0.6,1.6)
    local w = math.clamp(320*scale,200,520)
    local h = math.clamp(72*scale,54,140)

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0,w,0,h)
    main.Position = UDim2.new(1,-12,1,-12-h-16)
    main.AnchorPoint = Vector2.new(1,1)
    main.BackgroundTransparency = 0
    main.BackgroundColor3 = Color3.fromRGB(20,40,70)
    main.BorderSizePixel = 0
    main.Parent = screen

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,10)
    corner.Parent = main

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,4)
    bar.Position = UDim2.new(0,0,1,-4)
    bar.BackgroundColor3 = cfg.barColor
    bar.BorderSizePixel = 0
    bar.ClipsDescendants = true
    bar.Parent = main

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0,2)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1,0,1,0)
    fill.Position = UDim2.new(0,0,0,0)
    fill.BackgroundColor3 = cfg.barColor
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0,h,1,0)
    icon.Position = UDim2.new(0,0,0,0)
    icon.BackgroundTransparency = 1
    icon.Image = iconId or cfg.logo
    icon.ImageColor3 = cfg.barColor
    icon.ScaleType = Enum.ScaleType.Stretch
    icon.Parent = main

    local txt = Instance.new("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Size = UDim2.new(1,-h-8,0.4,0)
    txt.Position = UDim2.new(0,h+8,0,0)
    txt.Font = Enum.Font.Code
    txt.TextSize = math.clamp(14*scale,12,20)
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextYAlignment = Enum.TextYAlignment.Top
    txt.TextColor3 = Color3.new(1,1,1)
    txt.Text = title
    txt.Parent = main

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1,-h-8,0.5,0)
    sub.Position = UDim2.new(0,h+8,0.4,0)
    sub.Font = Enum.Font.Code
    sub.TextSize = math.clamp(12*scale,10,16)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextYAlignment = Enum.TextYAlignment.Top
    sub.TextColor3 = Color3.fromRGB(200,200,200)
    sub.Text = content
    sub.TextWrapped = true
    sub.Parent = main

    local id = tostring(math.floor(tick()*1000)).."-"..HttpService:GenerateGUID(false)
    table.insert(notifActive,{id=id,frame=main,sizeY=h})

    local function restack()
        local spacing = 8*scale
        local yoff = 0
        for i = #notifActive,1,-1 do
            local node = notifActive[i]
            if node and node.frame and node.frame.Parent then
                local target = -12-yoff-node.sizeY
                TweenService:Create(node.frame,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(1,-12,1,target)}):Play()
                yoff = yoff+node.sizeY+spacing
            end
        end
    end

    restack()

    local function destroy()
        for i = 1,#notifActive do
            if notifActive[i].id == id then
                table.remove(notifActive,i)
                break
            end
        end
        TweenService:Create(main,TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(1,16,main.Position.Y.Scale,main.Position.Y.Offset),BackgroundTransparency=1}):Play()
        TweenService:Create(txt,TweenInfo.new(0.35),{TextTransparency=1}):Play()
        TweenService:Create(sub,TweenInfo.new(0.35),{TextTransparency=1}):Play()
        TweenService:Create(icon,TweenInfo.new(0.35),{ImageTransparency=1}):Play()
        task.wait(0.35)
        pcall(function() main:Destroy() end)
        restack()
    end

    if length and length > 0 then
        TweenService:Create(fill,TweenInfo.new(length,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),{Size=UDim2.new(0,0,1,0)}):Play()
        task.delay(length,destroy)
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 10
    btn.Parent = main
    btn.MouseButton1Click:Connect(destroy)

    return {Close=destroy}
end

local function saveKey(key)
    if writefile then
        pcall(function() writefile(cfg.keyFile,key) end)
    end
end

local function loadKey()
    if readfile then
        local ok,data = pcall(function() return readfile(cfg.keyFile) end)
        if ok then return data end
    end
    return ""
end

local function buildUI()
    local Part1 = {}
    local Part2 = {}
    local Part3 = {}

    Part1.Screen = Instance.new("ScreenGui")
    Part1.Screen.Name = "&R4 Tuff"
    Part1.Screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
    Part1.Screen.ResetOnSpawn = false
    Part1.Screen.IgnoreGuiInset = true
    Part1.Screen.Parent = CoreGui

    Part1.Main = Instance.new("Frame")
    Part1.Main.Name = "Main"
    Part1.Main.Size = UDim2.new(0,370,0,200)
    Part1.Main.Position = UDim2.new(0.5,0,0.5,0)
    Part1.Main.AnchorPoint = Vector2.new(0.5,0.5)
    Part1.Main.BackgroundColor3 = Color3.fromRGB(20,30,50)
    Part1.Main.BackgroundTransparency = 0
    Part1.Main.BorderSizePixel = 0
    Part1.Main.ClipsDescendants = false
    Part1.Main.Parent = Part1.Screen

    Part1.Corner = Instance.new("UICorner")
    Part1.Corner.CornerRadius = UDim.new(0,10)
    Part1.Corner.Parent = Part1.Main

    Part2.Top = Instance.new("Frame")
    Part2.Top.Name = "Top"
    Part2.Top.Size = UDim2.new(1,0,0,35)
    Part2.Top.Position = UDim2.new(0,0,0,0)
    Part2.Top.BackgroundColor3 = Color3.fromRGB(30,60,100)
    Part2.Top.BorderSizePixel = 0
    Part2.Top.Parent = Part1.Main

    Part2.TopCorner = Instance.new("UICorner")
    Part2.TopCorner.CornerRadius = UDim.new(0,10)
    Part2.TopCorner.Parent = Part2.Top

    Part2.TopCover = Instance.new("Frame")
    Part2.TopCover.Name = "TopCover"
    Part2.TopCover.Size = UDim2.new(1,0,0,20)
    Part2.TopCover.Position = UDim2.new(0,0,1,-20)
    Part2.TopCover.BackgroundColor3 = Color3.fromRGB(30,60,100)
    Part2.TopCover.BorderSizePixel = 0
    Part2.TopCover.Parent = Part2.Top

    Part2.Line = Instance.new("Frame")
    Part2.Line.Name = "Line"
    Part2.Line.Size = UDim2.new(1,0,0,1)
    Part2.Line.Position = UDim2.new(0,0,1,0)
    Part2.Line.BackgroundColor3 = Color3.fromRGB(25,50,90)
    Part2.Line.BorderSizePixel = 0
    Part2.Line.Parent = Part2.Top

    Part2.Logo = Instance.new("ImageLabel")
    Part2.Logo.Name = "Logo"
    Part2.Logo.Size = UDim2.new(0,20,0,20)
    Part2.Logo.Position = UDim2.new(0,10,0,7)
    Part2.Logo.BackgroundTransparency = 1
    Part2.Logo.Image = cfg.logo
    Part2.Logo.ImageColor3 = cfg.barColor
    Part2.Logo.Parent = Part2.Top

    Part2.Title = Instance.new("TextLabel")
    Part2.Title.Name = "Title"
    Part2.Title.Size = UDim2.new(0,100,0,35)
    Part2.Title.Position = UDim2.new(0,35,0,0)
    Part2.Title.BackgroundTransparency = 1
    Part2.Title.Text = "&R4 Hideout"
    Part2.Title.TextColor3 = Color3.fromRGB(200,230,255)
    Part2.Title.TextSize = 18
    Part2.Title.Font = Enum.Font.GothamBold
    Part2.Title.TextXAlignment = Enum.TextXAlignment.Left
    Part2.Title.Parent = Part2.Top

    Part2.Close = Instance.new("ImageButton")
    Part2.Close.Name = "Close"
    Part2.Close.Size = UDim2.new(0,20,0,20)
    Part2.Close.Position = UDim2.new(1,-10,0.5,0)
    Part2.Close.AnchorPoint = Vector2.new(1,0.5)
    Part2.Close.BackgroundTransparency = 1
    Part2.Close.Image = "rbxassetid://122931434733842"
    Part2.Close.ImageColor3 = Color3.fromRGB(200,230,255)
    Part2.Close.ScaleType = Enum.ScaleType.Fit
    Part2.Close.Parent = Part2.Top

    Part3.Input = Instance.new("Frame")
    Part3.Input.Name = "Input"
    Part3.Input.Size = UDim2.new(0.9,0,0,35)
    Part3.Input.Position = UDim2.new(0.5,0,0,60)
    Part3.Input.AnchorPoint = Vector2.new(0.5,0)
    Part3.Input.BackgroundColor3 = Color3.fromRGB(15,35,65)
    Part3.Input.BackgroundTransparency = 0.3
    Part3.Input.BorderSizePixel = 0
    Part3.Input.Parent = Part1.Main

    Part3.InputStroke = Instance.new("UIStroke")
    Part3.InputStroke.Color = cfg.barColor
    Part3.InputStroke.Thickness = 1
    Part3.InputStroke.Transparency = 0.5
    Part3.InputStroke.Parent = Part3.Input

    Part3.InputCorner = Instance.new("UICorner")
    Part3.InputCorner.CornerRadius = UDim.new(0,6)
    Part3.InputCorner.Parent = Part3.Input

    Part3.Box = Instance.new("TextBox")
    Part3.Box.Name = "Box"
    Part3.Box.Size = UDim2.new(0.9,0,1,0)
    Part3.Box.Position = UDim2.new(0.5,0,0.5,0)
    Part3.Box.AnchorPoint = Vector2.new(0.5,0.5)
    Part3.Box.BackgroundTransparency = 1
    Part3.Box.Text = loadKey()
    Part3.Box.TextColor3 = Color3.fromRGB(200,230,255)
    Part3.Box.PlaceholderText = "00000000-0000-0000-0000-000000000000"
    Part3.Box.PlaceholderColor3 = Color3.fromRGB(100,120,150)
    Part3.Box.TextSize = 14
    Part3.Box.Font = Enum.Font.Gotham
    Part3.Box.ClearTextOnFocus = false
    Part3.Box.Parent = Part3.Input

    Part3.Buttons = Instance.new("Frame")
    Part3.Buttons.Name = "Buttons"
    Part3.Buttons.Size = UDim2.new(0.9,0,0,30)
    Part3.Buttons.Position = UDim2.new(0.5,0,1,-40)
    Part3.Buttons.AnchorPoint = Vector2.new(0.5,1)
    Part3.Buttons.BackgroundTransparency = 1
    Part3.Buttons.Parent = Part1.Main

    local btnColor = Color3.fromRGB(30,80,150)

    Part3.GetKey = Instance.new("TextButton")
    Part3.GetKey.Name = "GetKey"
    Part3.GetKey.Size = UDim2.new(0.45,-4,1,0)
    Part3.GetKey.Position = UDim2.new(0.25,0,0,0)
    Part3.GetKey.AnchorPoint = Vector2.new(0.5,0)
    Part3.GetKey.BackgroundColor3 = btnColor
    Part3.GetKey.BorderSizePixel = 0
    Part3.GetKey.Text = ""
    Part3.GetKey.AutoButtonColor = false
    Part3.GetKey.Parent = Part3.Buttons

    local getKeyIco = Instance.new("ImageLabel")
    getKeyIco.Size = UDim2.new(0,16,0,16)
    getKeyIco.Position = UDim2.new(0.5,-20,0.5,0)
    getKeyIco.AnchorPoint = Vector2.new(0.5,0.5)
    getKeyIco.BackgroundTransparency = 1
    getKeyIco.Image = "rbxassetid://96510194465420"
    getKeyIco.ImageColor3 = Color3.new(1,1,1)
    getKeyIco.Parent = Part3.GetKey

    local getKeyTxt = Instance.new("TextLabel")
    getKeyTxt.Size = UDim2.new(1,0,1,0)
    getKeyTxt.Position = UDim2.new(0.5,8,0,0)
    getKeyTxt.AnchorPoint = Vector2.new(0.5,0)
    getKeyTxt.BackgroundTransparency = 1
    getKeyTxt.Text = "Get Key"
    getKeyTxt.TextColor3 = Color3.new(1,1,1)
    getKeyTxt.TextSize = 12
    getKeyTxt.Font = Enum.Font.GothamBold
    getKeyTxt.Parent = Part3.GetKey

    Part3.GetKeyCorner = Instance.new("UICorner")
    Part3.GetKeyCorner.CornerRadius = UDim.new(0,8)
    Part3.GetKeyCorner.Parent = Part3.GetKey

    Part3.Verify = Instance.new("TextButton")
    Part3.Verify.Name = "Verify"
    Part3.Verify.Size = UDim2.new(0.45,-4,1,0)
    Part3.Verify.Position = UDim2.new(0.75,0,0,0)
    Part3.Verify.AnchorPoint = Vector2.new(0.5,0)
    Part3.Verify.BackgroundColor3 = btnColor
    Part3.Verify.BorderSizePixel = 0
    Part3.Verify.Text = ""
    Part3.Verify.AutoButtonColor = false
    Part3.Verify.Parent = Part3.Buttons

    local verifyIco = Instance.new("ImageLabel")
    verifyIco.Size = UDim2.new(0,16,0,16)
    verifyIco.Position = UDim2.new(0.5,-20,0.5,0)
    verifyIco.AnchorPoint = Vector2.new(0.5,0.5)
    verifyIco.BackgroundTransparency = 1
    verifyIco.Image = "rbxassetid://87354736164608"
    verifyIco.ImageColor3 = Color3.new(1,1,1)
    verifyIco.Parent = Part3.Verify

    local verifyTxt = Instance.new("TextLabel")
    verifyTxt.Size = UDim2.new(1,0,1,0)
    verifyTxt.Position = UDim2.new(0.5,8,0,0)
    verifyTxt.AnchorPoint = Vector2.new(0.5,0)
    verifyTxt.BackgroundTransparency = 1
    verifyTxt.Text = "Verify"
    verifyTxt.TextColor3 = Color3.new(1,1,1)
    verifyTxt.TextSize = 12
    verifyTxt.Font = Enum.Font.GothamBold
    verifyTxt.Parent = Part3.Verify

    Part3.VerifyCorner = Instance.new("UICorner")
    Part3.VerifyCorner.CornerRadius = UDim.new(0,8)
    Part3.VerifyCorner.Parent = Part3.Verify

    return {
        gui = Part1.Screen,
        main = Part1.Main,
        box = Part3.Box,
        verify = Part3.Verify,
        getKey = Part3.GetKey,
        close = Part2.Close,
        top = Part2.Top
    }
end

local function drag(ui)
    local dragInput,dragStart,startPos
    ui.top.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragInput = inp
            dragStart = inp.Position
            startPos = ui.main.Position
            inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragInput = nil end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp == dragInput and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inp.Position - dragStart
            ui.main.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
end

local function pulse(btn)
    local orig = btn.BackgroundColor3
    local pop = Color3.new(math.min(orig.R*1.3,1),math.min(orig.G*1.3,1),math.min(orig.B*1.3,1))
    TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=pop}):Play()
    task.wait(0.15)
    TweenService:Create(btn,TweenInfo.new(0.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{BackgroundColor3=orig}):Play()
end

local function loadScript()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local PlaceId = game.PlaceId

-- === 1. グローバル設定 ===
_G.TrollConfig = _G.TrollConfig or {
    -- 共通設定
    antiAFK = true, showStats = true,
    vfly = false, tpfly = false, fly = false, noclip = false, freeze = false, antiFling = false,
    vflySpeed = 50, tpflySpeed = 5, flySpeed = 50, speedHack = false, walkSpeed = 100,
    esp = false, fullBright = false, removeShadows = false, removeFog = false,
    
    -- ゲーム専用設定 (13946738101)
    autoChest = false, safeAutoChest = false, autoKill = false, npcEsp = false, chestEsp = false, itemEsp = false,
    scanRange = 2500, tpwalkSpeed = 5
}
local config = _G.TrollConfig

local bigChestUI, chestCountLabelObj
local activeBossTags = {}
local cachedBosses = {}
local flyBodyVelocity, flyBodyGyro

-- === 2. ANTI AFK (放置キック防止) ===
LocalPlayer.Idled:Connect(function()
    if config.antiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- === 3. HUDレイヤー (共通) ===
local pgui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
if pgui:FindFirstChild("TrollHubHUD") then pgui.TrollHubHUD:Destroy() end
local hudGui = Instance.new("ScreenGui", pgui)
hudGui.Name = "TrollHubHUD"
hudGui.ResetOnSpawn = false

local espFolder = pgui:FindFirstChild("TrollBossESPFolder")
if espFolder then espFolder:Destroy() end
espFolder = Instance.new("Folder", pgui)
espFolder.Name = "TrollBossESPFolder"

-- 📱 モバイル用 UI表示トグル
local toggleBtn = Instance.new("TextButton", hudGui)
toggleBtn.Size = UDim2.new(0, 45, 0, 45)
toggleBtn.Position = UDim2.new(0.5, -22, 0, 10)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
toggleBtn.BackgroundTransparency = 0.3
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Text = "UI"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 16
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 12)

local dragging, dragInput, dragStart, startPos
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = toggleBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
toggleBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local clickTime = 0
toggleBtn.MouseButton1Click:Connect(function()
    if tick() - clickTime > 0.2 then
        local coreGui = game:GetService("CoreGui")
        local rGui = coreGui:FindFirstChild("Rayfield") or pgui:FindFirstChild("Rayfield")
        if rGui then
            local mainFrame = rGui:FindFirstChild("Main")
            if mainFrame then mainFrame.Visible = not mainFrame.Visible end
        end
    end
    clickTime = tick()
end)

-- 📊 FPS/Ping表示
local sF = Instance.new("Frame", hudGui)
sF.Size = UDim2.new(0, 120, 0, 50)
sF.Position = UDim2.new(0.02, 0, 0.2, 0)
sF.BackgroundColor3 = Color3.new(0,0,0)
sF.BackgroundTransparency = 0.5
sF.Visible = config.showStats
Instance.new("UICorner", sF)
local fL = Instance.new("TextLabel", sF)
fL.Size = UDim2.new(1,0,0.5,0); fL.BackgroundTransparency = 1; fL.TextColor3 = Color3.new(0,1,0); fL.Text = "FPS: --"
local pL = Instance.new("TextLabel", sF)
pL.Size = UDim2.new(1,0,0.5,0); pL.Position = UDim2.new(0,0,0.5,0); pL.BackgroundTransparency = 1; pL.TextColor3 = Color3.new(1,1,0); pL.Text = "Ping: --"


-- === 4. Rayfield UI 初期化 ===
local Window = Rayfield:CreateWindow({
    Name = "Troll Hub v9.2 (Item ESP)",
    LoadingTitle = "Troll Hub Loading...",
    LoadingSubtitle = "by Troll",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main (Game)", 4483362458)
local PlayerTab = Window:CreateTab("Player", 4483362458)
local EspTab = Window:CreateTab("ESP", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)
local ScriptTab = Window:CreateTab("Scripts", 4483362458)


-- ==========================================
-- 🎮 ゲーム別専用ロジックの分岐
-- ==========================================

if PlaceId == 13946738101 then
    MainTab:CreateSection("Target Game: 13946738101")

    -- 📦 でかいUI (チェスト数表示)
    bigChestUI = Instance.new("Frame", hudGui)
    bigChestUI.Size = UDim2.new(0, 300, 0, 150)
    bigChestUI.Position = UDim2.new(0.5, -150, 0.5, -75)
    bigChestUI.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    bigChestUI.Visible = config.autoChest or config.safeAutoChest
    Instance.new("UICorner", bigChestUI)

    chestCountLabelObj = Instance.new("TextLabel", bigChestUI)
    chestCountLabelObj.Size = UDim2.new(1, 0, 0.6, 0); chestCountLabelObj.Text = "残りチェスト: 検索中..."
    chestCountLabelObj.TextColor3 = Color3.new(1, 1, 1); chestCountLabelObj.TextScaled = true; chestCountLabelObj.BackgroundTransparency = 1

    local chestOffBtn = Instance.new("TextButton", bigChestUI)
    chestOffBtn.Size = UDim2.new(0.6, 0, 0.3, 0); chestOffBtn.Position = UDim2.new(0.2, 0, 0.65, 0)
    chestOffBtn.Text = "OFF"; chestOffBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); chestOffBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", chestOffBtn)

    local AutoChestToggle = MainTab:CreateToggle({ 
        Name = "AUTO CHEST (TP: BANリスク高)", 
        CurrentValue = config.autoChest, 
        Flag = "AutoChest", 
        Callback = function(Value) 
            config.autoChest = Value; 
            bigChestUI.Visible = Value or config.safeAutoChest 
        end 
    })

    local SafeAutoChestToggle = MainTab:CreateToggle({ 
        Name = "SAFE AUTO CHEST (無重力 + TPWalk)", 
        CurrentValue = config.safeAutoChest, 
        Flag = "SafeAutoChest", 
        Callback = function(Value) 
            config.safeAutoChest = Value; 
            bigChestUI.Visible = Value or config.autoChest
            if not Value then workspace.Gravity = 196.2 end
        end 
    })

    MainTab:CreateSlider({ 
        Name = "TPWalk Speed (Safe Farm用)", 
        Range = {1, 20}, Increment = 1, CurrentValue = config.tpwalkSpeed, 
        Flag = "TPWalkSpeed", 
        Callback = function(Value) config.tpwalkSpeed = Value end 
    })

    chestOffBtn.MouseButton1Click:Connect(function() 
        if AutoChestToggle then AutoChestToggle:Set(false) end 
        if SafeAutoChestToggle then SafeAutoChestToggle:Set(false) end
    end)

    MainTab:CreateToggle({ Name = "AUTO KILL", CurrentValue = config.autoKill, Flag = "AutoKill", Callback = function(Value) config.autoKill = Value end })

    EspTab:CreateSection("Game Specific ESP")
    EspTab:CreateToggle({ Name = "BOSS / NPC ESP", CurrentValue = config.npcEsp, Flag = "BossEsp", Callback = function(Value) config.npcEsp = Value; if not Value then for obj, tag in pairs(activeBossTags) do if tag then tag:Destroy() end end; table.clear(activeBossTags) end end })
    EspTab:CreateToggle({ Name = "CHEST ESP", CurrentValue = config.chestEsp, Flag = "ChestEsp", Callback = function(Value) config.chestEsp = Value end })
    EspTab:CreateToggle({ Name = "ITEM ESP (チェスト以外のアイテム)", CurrentValue = config.itemEsp, Flag = "ItemEsp", Callback = function(Value) config.itemEsp = Value end })

    -- 厳選テレポート (SAFE FARM = 修正版TPWalk)
    task.spawn(function()
        while true do
            pcall(function()
                if not (config.autoChest or config.safeAutoChest or config.autoKill) then task.wait(0.1) return end
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not root then task.wait(0.1) return end
                
                local target, isChest, dist = nil, false, config.scanRange
                local currentChestCount = 0 
                
                if config.autoChest or config.safeAutoChest then
                    for _, p in pairs(workspace:GetDescendants()) do
                        if p:IsA("ProximityPrompt") and p.Enabled then
                            local obj = p.Parent
                            if obj:IsA("BasePart") then
                                local txt = (obj.Name .. obj.Parent.Name .. p.ActionText):lower()
                                if (txt:find("chest") or txt:find("drop") or txt:find("loot")) and 
                                   not (txt:find("shop") or txt:find("npc") or txt:find("buy") or txt:find("talk")) then
                                    
                                    currentChestCount = currentChestCount + 1 
                                    local d = (root.Position - obj.Position).Magnitude
                                    if d < dist then target = obj; dist = d; isChest = true end
                                end
                            end
                        end
                    end
                end
                
                if chestCountLabelObj and (config.autoChest or config.safeAutoChest) then
                    local displayCount = currentChestCount - 3
                    if not target or displayCount < 0 then displayCount = 0 end
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
                    if config.safeAutoChest then
                        workspace.Gravity = 0
                        
                        -- 💥 吹っ飛び防止対策①: セーフファーム稼働中は強制的にキャラ全体の衝突判定を無くす(Noclip状態)
                        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                        
                        local distToTarget = (target.Position - root.Position).Magnitude
                        
                        if distToTarget > 4 then
                            local dir = (target.Position - root.Position).Unit
                            
                            -- 💥 吹っ飛び防止対策②: 位置が重なった時のNaN(計算不能バグ)を徹底的に弾く
                            if dir.X == dir.X and dir.Y == dir.Y and dir.Z == dir.Z then
                                local moveDist = math.min(config.tpwalkSpeed, distToTarget)
                                local nextPos = root.Position + (dir * moveDist)
                                
                                -- lookAtバグを防ぐため、十分な距離がある時だけ向きを変える
                                if (target.Position - nextPos).Magnitude > 0.5 then
                                    root.CFrame = CFrame.lookAt(nextPos, target.Position)
                                else
                                    root.CFrame = CFrame.new(nextPos) * (root.CFrame - root.Position)
                                end
                            end
                            -- 💥 吹っ飛び防止対策③: 物理エンジンの残存速度・回転速度を完全リセット
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                        else
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                            if isChest then
                                task.wait(0.1)
                                fireproximityprompt(target:FindFirstChildOfClass("ProximityPrompt") or target.Parent:FindFirstChildOfClass("ProximityPrompt"))
                            else
                                VirtualUser:Button1Down(Vector2.new(0,0))
                            end
                        end
                    else
                        -- 従来の急移動TP (BANリスク高)
                        root.CFrame = isChest and target.CFrame or target.CFrame * CFrame.new(0, 0, 3)
                        if isChest then
                            task.wait(0.1)
                            fireproximityprompt(target:FindFirstChildOfClass("ProximityPrompt") or target.Parent:FindFirstChildOfClass("ProximityPrompt"))
                        else
                            VirtualUser:Button1Down(Vector2.new(0,0))
                        end
                    end
                end
            end)
            task.wait(0.05) -- 少し周期を早めて移動をより滑らかに
        end
    end)

    -- スキャナー
    task.spawn(function()
        while true do
            pcall(function()
                if config.npcEsp then
                    local found = {}
                    local targets = { workspace:FindFirstChild("ActiveNPCs"), workspace:FindFirstChild("boss's"), workspace:FindFirstChild("Map Boss"), workspace:FindFirstChild("Map folder") }
                    for _, folder in pairs(targets) do
                        if folder then
                            for _, obj in pairs(folder:GetDescendants()) do
                                if obj:IsA("Model") and (obj:FindFirstChild("Humanoid") or obj:FindFirstChild("Head")) then
                                    if not Players:GetPlayerFromCharacter(obj) then table.insert(found, obj) end
                                end
                            end
                        end
                    end
                    cachedBosses = found
                end
            end)
            task.wait(1)
        end
    end)

    -- =====================================
    -- 📦 Chest ESP ロジック
    -- =====================================
    local folderName = "AllChestESP_Folder"
    if pgui:FindFirstChild(folderName) then pgui[folderName]:Destroy() end
    local chestEspFolder = Instance.new("Folder")
    chestEspFolder.Name = folderName
    chestEspFolder.Parent = pgui

    local function createESP(target)
        task.spawn(function()
            local displayName, espColor = "", Color3.new(1, 1, 1)
            if target.Name == "Chest_Spawn" then displayName = "📦 Chest"; espColor = Color3.fromRGB(255, 215, 0)
            elseif target.Name == "LightChest_Spawn" then displayName = "✨ Light Chest"; espColor = Color3.fromRGB(255, 255, 150)
            elseif target.Name == "DarkChest_Spawn" then displayName = "🌑 Dark Chest"; espColor = Color3.fromRGB(180, 50, 255)
            elseif target.Name == "RadioactiveChest_Spawn" then displayName = "☢️ Radioactive Chest"; espColor = Color3.fromRGB(50, 255, 50)
            elseif target.Name == "MachineChest_p" then displayName = "⚙️ Machine Chest"; espColor = Color3.fromRGB(0, 200, 255)
            else return end

            local attachPart = target:FindFirstChild("Handle") or target:FindFirstChild("MachineChest_p") or target:FindFirstChildWhichIsA("BasePart", true)
            if not attachPart and target:IsA("Model") then
                for i = 1, 10 do task.wait(0.2); if not target.Parent then return end; attachPart = target:FindFirstChild("Handle") or target:FindFirstChild("MachineChest_p") or target:FindFirstChildWhichIsA("BasePart", true); if attachPart then break end end
            end
            if not attachPart and target:IsA("BasePart") then attachPart = target end
            if not attachPart then return end

            local billboard = Instance.new("BillboardGui"); billboard.Name = "ChestLabel"; billboard.Adornee = attachPart; billboard.Size = UDim2.new(0, 200, 0, 30); billboard.StudsOffset = Vector3.new(0, 3, 0); billboard.AlwaysOnTop = true
            local label = Instance.new("TextLabel", billboard); label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1; label.Text = displayName; label.TextColor3 = espColor; label.TextStrokeTransparency = 0; label.Font = Enum.Font.GothamBold; label.TextSize = 14
            billboard.Parent = chestEspFolder

            local connection
            connection = RunService.RenderStepped:Connect(function()
                if not target or not target.Parent or not attachPart or not attachPart.Parent then billboard:Destroy(); connection:Disconnect(); return end
                billboard.Enabled = config.chestEsp
                if config.chestEsp then
                    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if root then label.Text = displayName .. " [" .. math.floor((root.Position - attachPart.Position).Magnitude) .. "m]" end
                end
            end)
        end)
    end
    for _, v in pairs(workspace:GetDescendants()) do createESP(v) end
    workspace.DescendantAdded:Connect(function(v) createESP(v) end)

    -- =====================================
    -- 💎 Item ESP ロジック (チェスト以外を監視)
    -- =====================================
    local itemFolderName = "AllItemESP_Folder"
    if pgui:FindFirstChild(itemFolderName) then pgui[itemFolderName]:Destroy() end
    local itemEspFolder = Instance.new("Folder")
    itemEspFolder.Name = itemFolderName
    itemEspFolder.Parent = pgui

    local function createItemESP(target)
        task.spawn(function()
            local displayName, espColor = "", Color3.new(1, 1, 1)
            
            -- チェスト類は除外
            if target.Name:match("Chest") or target.Name:match("chest") then return end
            
            -- 画像9枚目で確認できた WeepSoul_P を対象
            if target.Name == "WeepSoul_P" then 
                displayName = "👻 Weep Soul"
                espColor = Color3.fromRGB(150, 255, 255)
            -- その他 _P などの命名規則があるドロップアイテムを汎用的に拾う
            elseif target.Name:match("_P$") or target.Name:match("_p$") then
                displayName = "🔹 " .. target.Name:gsub("_[Pp]$", "")
                espColor = Color3.fromRGB(200, 200, 255)
            else
                return 
            end

            -- 監視対象のパーツを取得
            local attachPart = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
            if not attachPart then return end

            local billboard = Instance.new("BillboardGui")
            billboard.Name = "ItemLabel"
            billboard.Adornee = attachPart
            billboard.Size = UDim2.new(0, 200, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.AlwaysOnTop = true
            
            local label = Instance.new("TextLabel", billboard)
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = displayName
            label.TextColor3 = espColor
            label.TextStrokeTransparency = 0
            label.Font = Enum.Font.GothamBold
            label.TextSize = 12
            billboard.Parent = itemEspFolder

            local connection
            connection = RunService.RenderStepped:Connect(function()
                if not target or not target.Parent or not attachPart or not attachPart.Parent then 
                    billboard:Destroy()
                    connection:Disconnect()
                    return 
                end
                billboard.Enabled = config.itemEsp
                if config.itemEsp then
                    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if root then 
                        label.Text = displayName .. " [" .. math.floor((root.Position - attachPart.Position).Magnitude) .. "m]" 
                    end
                end
            end)
        end)
    end
    for _, v in pairs(workspace:GetDescendants()) do createItemESP(v) end
    workspace.DescendantAdded:Connect(function(v) createItemESP(v) end)

elseif PlaceId == 123456789 then
    MainTab:CreateSection("別のゲーム専用の機能")
    MainTab:CreateLabel("ここに別ゲームの機能を書けます")
else
    MainTab:CreateSection("Universal Game")
    MainTab:CreateLabel("このゲーム専用の機能はまだありません。")
end


-- ==========================================
-- 🌍 共通機能 (どのゲームでも使える機能)
-- ==========================================

-- 🧍 Player タブ
PlayerTab:CreateToggle({ Name = "VFly", CurrentValue = config.vfly, Flag = "VFly", Callback = function(Value) config.vfly = Value end })
PlayerTab:CreateSlider({ Name = "VFly Speed", Range = {10, 300}, Increment = 5, CurrentValue = config.vflySpeed, Flag = "VFlySpeed", Callback = function(Value) config.vflySpeed = Value end })

PlayerTab:CreateToggle({ Name = "TPFly", CurrentValue = config.tpfly, Flag = "TPFly", Callback = function(Value) config.tpfly = Value end })
PlayerTab:CreateSlider({ Name = "TPFly Speed", Range = {1, 50}, Increment = 1, CurrentValue = config.tpflySpeed, Flag = "TPFlySpeed", Callback = function(Value) config.tpflySpeed = Value end })

PlayerTab:CreateToggle({
    Name = "Fly (Standard)", CurrentValue = config.fly, Flag = "Fly",
    Callback = function(Value) 
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        config.fly = Value 
        if root then
            if Value then
                flyBodyVelocity = Instance.new("BodyVelocity", root); flyBodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000); flyBodyVelocity.Velocity = Vector3.zero
                flyBodyGyro = Instance.new("BodyGyro", root); flyBodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000); flyBodyGyro.P = 9e4
            else
                if flyBodyVelocity then flyBodyVelocity:Destroy() end; if flyBodyGyro then flyBodyGyro:Destroy() end
            end
        end
    end
})
PlayerTab:CreateSlider({ Name = "Fly Speed", Range = {10, 300}, Increment = 5, CurrentValue = config.flySpeed, Flag = "FlySpeed", Callback = function(Value) config.flySpeed = Value end })
PlayerTab:CreateToggle({ Name = "Noclip", CurrentValue = config.noclip, Flag = "Noclip", Callback = function(Value) config.noclip = Value end })
PlayerTab:CreateToggle({ Name = "Freeze (Anchored)", CurrentValue = config.freeze, Flag = "Freeze", Callback = function(Value) config.freeze = Value; local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if root then root.Anchored = Value end end })
PlayerTab:CreateToggle({ Name = "Anti-Fling (衝突無効)", CurrentValue = config.antiFling, Flag = "AntiFling", Callback = function(Value) config.antiFling = Value end })
PlayerTab:CreateToggle({ Name = "SPEED HACK", CurrentValue = config.speedHack, Flag = "SpeedHack", Callback = function(Value) config.speedHack = Value; if not Value and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = 16 end end })

-- 🔵 ESP タブ (汎用)
EspTab:CreateSection("Universal ESP")
EspTab:CreateToggle({ Name = "PLAYER ESP", CurrentValue = config.esp, Flag = "PlayerEsp", Callback = function(Value) config.esp = Value end })

-- 🟠 Misc タブ
MiscTab:CreateToggle({ Name = "ANTI AFK (放置キック防止)", CurrentValue = config.antiAFK, Flag = "AntiAFK", Callback = function(Value) config.antiAFK = Value end })
MiscTab:CreateButton({
    Name = "ANTI LAG (軽量化・元に戻せません)",
    Callback = function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("MeshPart") then v.Material = Enum.Material.SmoothPlastic
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
        end
        Lighting.GlobalShadows = false
    end,
})
MiscTab:CreateToggle({ Name = "REMOVE SHADOWS (影削除)", CurrentValue = config.removeShadows, Flag = "RemoveShadows", Callback = function(Value) config.removeShadows = Value end })
MiscTab:CreateToggle({ Name = "REMOVE FOG (霧削除)", CurrentValue = config.removeFog, Flag = "RemoveFog", Callback = function(Value) config.removeFog = Value end })
MiscTab:CreateToggle({ Name = "FULL BRIGHT", CurrentValue = config.fullBright, Flag = "FullBright", Callback = function(Value) config.fullBright = Value; if not Value then Lighting.Brightness = 1; Lighting.ClockTime = 12 end end })
MiscTab:CreateToggle({ Name = "STATS HUD", CurrentValue = config.showStats, Flag = "StatsHud", Callback = function(Value) config.showStats = Value; sF.Visible = Value end })

-- 📜 Scripts タブ 
ScriptTab:CreateButton({ Name = "Unstability || Universal", Callback = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/ILOVETHECOFFINOFANDYANDLEYLEY/THE-HACK-/main/script%20omg"))() end })

-- === 共通 Physics / Movement ループ ===
RunService.Stepped:Connect(function()
    if (config.noclip or (config.safeAutoChest and PlaceId == 13946738101)) and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
    end
    if config.antiFling then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, part in pairs(p.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if config.showStats then fL.Text = "FPS: " .. math.floor(1/dt); pL.Text = "Ping: " .. math.floor(LocalPlayer:GetNetworkPing() * 1000) .. "ms" end
    
    -- Player ESP
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

    -- Boss ESP 更新 (ゲームID一致時のみ動作)
    if config.npcEsp and PlaceId == 13946738101 then
        local currentList = {}
        for _, obj in pairs(cachedBosses) do
            local head = obj:FindFirstChild("Head") or obj:FindFirstChild("Torso") or obj:FindFirstChild("HumanoidRootPart")
            local hum = obj:FindFirstChild("Humanoid")
            if head and hum and hum.Health > 0 then
                currentList[obj] = true
                local tag = activeBossTags[obj]
                if not tag or not tag.Parent then
                    tag = Instance.new("BillboardGui"); tag.Name = "BossTag"; tag.AlwaysOnTop = true; tag.Size = UDim2.new(0, 100, 0, 40); tag.Adornee = head; tag.Parent = espFolder
                    local lbl = Instance.new("TextLabel", tag); lbl.Name = "Label"; lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(255, 50, 50); lbl.TextStrokeTransparency = 0; lbl.Font = Enum.Font.SourceSansBold
                    activeBossTags[obj] = tag
                end
                local displayName = obj.Name
                local healthBar = head:FindFirstChild("BossHealthBar")
                if healthBar then
                    local bossText = healthBar:FindFirstChild("boss")
                    if bossText and bossText:IsA("TextLabel") and bossText.Text ~= "" then displayName = bossText.Text end
                end
                tag.Label.Text = "[" .. displayName .. "]\nHP: " .. math.floor(hum.Health)
            end
        end
        for obj, tag in pairs(activeBossTags) do if not currentList[obj] or not obj.Parent then if tag then tag:Destroy() end; activeBossTags[obj] = nil end end
    end
    
    -- 3D 飛行ロジック
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    if root and hum then
        local moveDir = hum.MoveDirection
        local dir3D = Vector3.zero
        
        if moveDir.Magnitude > 0 then
            local camCFrame = Camera.CFrame
            local flatLook = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z)
            if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
            local flatRight = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z)
            if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end
            
            local forwardAmt = moveDir:Dot(flatLook)
            local rightAmt = moveDir:Dot(flatRight)
            dir3D = (camCFrame.LookVector * forwardAmt) + (camCFrame.RightVector * rightAmt)
            if dir3D.Magnitude > 0 then dir3D = dir3D.Unit end
        end
        
        if config.fly and flyBodyVelocity and flyBodyGyro then
            flyBodyGyro.CFrame = Camera.CFrame
            flyBodyVelocity.Velocity = dir3D * config.flySpeed
        end
        if config.vfly then
            if moveDir.Magnitude > 0 then root.Velocity = dir3D * config.vflySpeed else root.Velocity = Vector3.new(0, 0.1, 0) end
        end
        if config.tpfly then
            if moveDir.Magnitude > 0 then root.CFrame = root.CFrame + (dir3D * (config.tpflySpeed * (dt * 60))) end
            root.Velocity = Vector3.zero
        end
        if config.speedHack then hum.WalkSpeed = config.walkSpeed end
    end

    if config.removeShadows then Lighting.GlobalShadows = false end
    if config.removeFog then Lighting.FogEnd = 100000; Lighting.FogStart = 0; local atm = Lighting:FindFirstChildOfClass("Atmosphere"); if atm then atm.Density = 0 end end
    if config.fullBright then Lighting.Brightness = 2; Lighting.ClockTime = 14 end
end)
end

local function main()
    if getgenv().JunkieUILoaded then return end
    getgenv().JunkieUILoaded = true
    
    local ui = buildUI()
    drag(ui)

    local function validate()
        local key = ui.box.Text:gsub("%s+","")
        if key == "" then 
            createNotification("Key Required","Please enter a key to continue.",3,"rbxassetid://82094603330968") 
            return 
        end
        
        createNotification("Checking...","Validating your key, please wait.",2,"rbxassetid://92630967969808")
        
        local success, sdk = pcall(function()
            return loadstring(game:HttpGet("https://junkie-development.de/sdk/JunkieKeySystem.lua"))()
        end)
        
        if not success then
            createNotification("Error", "Failed to load SDK. Please try again.", 3, "rbxassetid://78733624425654")
            return
        end
        
        local ok = sdk.verifyKey(cfg.api, key, cfg.service)
        
        if ok then
            saveKey(key)
            createNotification("Success!", "Key verified. Loading script...", 3, "rbxassetid://87094841427580")
            TweenService:Create(ui.main, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, -0.5, 0),
                BackgroundTransparency = 1
            }):Play()
            task.wait(0.4)
            ui.gui:Destroy()
            loadScript()
        else
            createNotification("Invalid Key", "The key you entered is incorrect.", 3, "rbxassetid://78733624425654")
        end
    end

    ui.verify.MouseButton1Click:Connect(function()
        pulse(ui.verify)
        validate()
    end)

    ui.box.FocusLost:Connect(function(enter) 
        if enter then 
            validate() 
        end 
    end)

    ui.getKey.MouseButton1Click:Connect(function()
        pulse(ui.getKey)
        createNotification("Getting Key...", "Generating your key link...", 2, "rbxassetid://83281479437771")
        
        local success, sdk = pcall(function()
            return loadstring(game:HttpGet("https://junkie-development.de/sdk/JunkieKeySystem.lua"))()
        end)
        
        if success then
            local link = sdk.getLink(cfg.api, cfg.provider, cfg.service)
            if link and setclipboard then
                setclipboard(link)
                createNotification("Link Copied", "Get-key link has been copied to clipboard.", 3, "rbxassetid://128463727794542")
            else
                createNotification("Failed", "Could not generate get-key link.", 3, "rbxassetid://78733624425654")
            end
        else
            createNotification("Error", "Failed to load SDK. Please try again.", 3, "rbxassetid://78733624425654")
        end
    end)

    ui.close.MouseButton1Click:Connect(function()
        createNotification("Closing...", "See you next time!", 2, "rbxassetid://116998807311805")
        TweenService:Create(ui.main, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, -0.5, 0),
            BackgroundTransparency = 1
        }):Play()
        task.wait(0.4)
        ui.gui:Destroy()
    end)

    ui.box.Focused:Connect(function()
        TweenService:Create(ui.box.Parent, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
    end)

    ui.box.FocusLost:Connect(function()
        TweenService:Create(ui.box.Parent, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
    end)

    for _,btn in ipairs({ui.verify, ui.getKey}) do
        btn.MouseEnter:Connect(function()
            local orig = btn.BackgroundColor3
            local bright = Color3.new(math.min(orig.R*1.15,1), math.min(orig.G*1.15,1), math.min(orig.B*1.15,1))
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = bright}):Play()
        end)
        btn.MouseLeave:Connect(function()
            local orig = btn.BackgroundColor3
            local dim = Color3.new(orig.R/1.15, orig.G/1.15, orig.B/1.15)
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = dim}):Play()
        end)
    end
end

main()
