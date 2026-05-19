-- [[ motobu:) - Radio & ID Saver Hub (Volume Slider & Loop) ]]
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- 既存のUIをクリーンアップ
if CoreGui:FindFirstChild("MotobuHub") then
    CoreGui.MotobuHub:Destroy()
end

-- セーブファイルの設定
local SAVE_FILE = "motobu_saved_ids.txt"

-- 保存されたIDを読み込む関数
local function loadSavedIds()
    local ids = {}
    if isfile and readfile and isfile(SAVE_FILE) then
        local success, result = pcall(function() return readfile(SAVE_FILE) end)
        if success and result then
            for id in string.gmatch(result, "[^\r\n]+") do
                table.insert(ids, id)
            end
        end
    end
    return ids
end

-- IDを新しく保存する関数
local function saveNewId(newId)
    local currentIds = loadSavedIds()
    for _, v in ipairs(currentIds) do
        if v == tostring(newId) then return false end
    end
    
    table.insert(currentIds, tostring(newId))
    if writefile then
        pcall(function() writefile(SAVE_FILE, table.concat(currentIds, "\n")) end)
    end
    return true
end

-- ==========================================
-- 1. GUIのベース作成
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MotobuHub"
ScreenGui.Parent = CoreGui

-- トグルボタン
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0, 20, 0, 20)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleBtn.Text = "📻"
ToggleBtn.TextSize = 24
ToggleBtn.Active = true
ToggleBtn.Draggable = true
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0.5, 0)

-- メインフレーム (音量バーの分、縦幅を450に拡張)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 450)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local RainbowStroke = Instance.new("UIStroke")
RainbowStroke.Thickness = 3
RainbowStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "motobu:)"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Parent = MainFrame

-- ==========================================
-- 2. 再生エリア (上部)
-- ==========================================
local PlayInput = Instance.new("TextBox")
PlayInput.Size = UDim2.new(0, 260, 0, 35)
PlayInput.Position = UDim2.new(0, 20, 0, 50)
PlayInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
PlayInput.PlaceholderText = "再生するIDを入力..."
PlayInput.Font = Enum.Font.Gotham
PlayInput.TextSize = 14
PlayInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayInput.Text = ""
PlayInput.ClearTextOnFocus = false
PlayInput.Parent = MainFrame
Instance.new("UICorner", PlayInput).CornerRadius = UDim.new(0, 6)

local PlayBtn = Instance.new("TextButton")
PlayBtn.Size = UDim2.new(0, 190, 0, 35)
PlayBtn.Position = UDim2.new(0, 20, 0, 95)
PlayBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
PlayBtn.Text = "▶ 再生"
PlayBtn.Font = Enum.Font.GothamBold
PlayBtn.TextSize = 14
PlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayBtn.Parent = MainFrame
Instance.new("UICorner", PlayBtn).CornerRadius = UDim.new(0, 6)

local LoopBtn = Instance.new("TextButton")
LoopBtn.Size = UDim2.new(0, 60, 0, 35)
LoopBtn.Position = UDim2.new(0, 220, 0, 95)
LoopBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
LoopBtn.Text = "🔁 オフ"
LoopBtn.Font = Enum.Font.GothamBold
LoopBtn.TextSize = 12
LoopBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
LoopBtn.Parent = MainFrame
Instance.new("UICorner", LoopBtn).CornerRadius = UDim.new(0, 6)

-- ==========================================
-- 3. 音量スライダー (Max 10)
-- ==========================================
local VolLabel = Instance.new("TextLabel")
VolLabel.Size = UDim2.new(0, 70, 0, 20)
VolLabel.Position = UDim2.new(0, 20, 0, 140)
VolLabel.BackgroundTransparency = 1
VolLabel.Text = "音量: 5.0"
VolLabel.Font = Enum.Font.GothamBold
VolLabel.TextSize = 13
VolLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
VolLabel.TextXAlignment = Enum.TextXAlignment.Left
VolLabel.Parent = MainFrame

local SliderBase = Instance.new("TextButton")
SliderBase.Size = UDim2.new(0, 180, 0, 10)
SliderBase.Position = UDim2.new(0, 100, 0, 145)
SliderBase.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SliderBase.Text = ""
SliderBase.AutoButtonColor = false
SliderBase.Parent = MainFrame
Instance.new("UICorner", SliderBase).CornerRadius = UDim.new(1, 0)

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0.5, 0, 1, 0) -- 初期値5 (50%)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderBase
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(0, 260, 0, 2)
Divider.Position = UDim2.new(0, 20, 0, 175)
Divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
Divider.BorderSizePixel = 0
Divider.Parent = MainFrame

-- ==========================================
-- 4. 保存エリア (下部)
-- ==========================================
local SaveInput = Instance.new("TextBox")
SaveInput.Size = UDim2.new(0, 180, 0, 30)
SaveInput.Position = UDim2.new(0, 20, 0, 190)
SaveInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
SaveInput.PlaceholderText = "保存するID..."
SaveInput.Font = Enum.Font.Gotham
SaveInput.TextSize = 14
SaveInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveInput.Text = ""
SaveInput.ClearTextOnFocus = false
SaveInput.Parent = MainFrame
Instance.new("UICorner", SaveInput).CornerRadius = UDim.new(0, 6)

local SaveBtn = Instance.new("TextButton")
SaveBtn.Size = UDim2.new(0, 70, 0, 30)
SaveBtn.Position = UDim2.new(0, 210, 0, 190)
SaveBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
SaveBtn.Text = "保存"
SaveBtn.Font = Enum.Font.GothamBold
SaveBtn.TextSize = 14
SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveBtn.Parent = MainFrame
Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 6)

-- ==========================================
-- 5. スクロールリスト (保存されたIDの表示)
-- ==========================================
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(0, 260, 0, 200)
ScrollFrame.Position = UDim2.new(0, 20, 0, 235)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 6
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.Parent = MainFrame
Instance.new("UICorner", ScrollFrame).CornerRadius = UDim.new(0, 6)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ScrollFrame
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
end)

local function addIdToScrollList(idText)
    local Item = Instance.new("Frame")
    Item.Size = UDim2.new(1, -10, 0, 35)
    Item.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Item.Parent = ScrollFrame
    Instance.new("UICorner", Item).CornerRadius = UDim.new(0, 4)

    local IdLabel = Instance.new("TextBox")
    IdLabel.Size = UDim2.new(0, 160, 1, 0)
    IdLabel.Position = UDim2.new(0, 10, 0, 0)
    IdLabel.BackgroundTransparency = 1
    IdLabel.Text = idText
    IdLabel.Font = Enum.Font.Gotham
    IdLabel.TextSize = 14
    IdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    IdLabel.TextXAlignment = Enum.TextXAlignment.Left
    IdLabel.TextEditable = false
    IdLabel.ClearTextOnFocus = false
    IdLabel.Parent = Item

    local CopyBtn = Instance.new("TextButton")
    CopyBtn.Size = UDim2.new(0, 60, 0, 25)
    CopyBtn.Position = UDim2.new(1, -70, 0.5, -12.5)
    CopyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    CopyBtn.Text = "コピー"
    CopyBtn.Font = Enum.Font.Gotham
    CopyBtn.TextSize = 12
    CopyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CopyBtn.Parent = Item
    Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 4)

    CopyBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(idText)
            CopyBtn.Text = "完了!"
            CopyBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
            task.wait(1)
            CopyBtn.Text = "コピー"
            CopyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
    end)
end

for _, savedId in ipairs(loadSavedIds()) do
    addIdToScrollList(savedId)
end

-- ==========================================
-- 6. 各種ロジック処理
-- ==========================================
ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)
RunService.RenderStepped:Connect(function()
    local hue = tick() % 3 / 3
    RainbowStroke.Color = Color3.fromHSV(hue, 1, 1)
    ToggleBtn.BackgroundColor3 = Color3.fromHSV(hue, 0.8, 0.5)
end)

local Sound = workspace:FindFirstChild("MotobuSound") or Instance.new("Sound")
Sound.Name = "MotobuSound"
Sound.Parent = workspace
Sound.Volume = 5 -- 初期音量を5に設定
local isPlaying = false
local isLooping = false

-- 【音量スライダーのロジック】
local isDraggingSlider = false
local MAX_VOLUME = 10

local function updateSlider(input)
    local sliderX = SliderBase.AbsolutePosition.X
    local sliderWidth = SliderBase.AbsoluteSize.X
    local mouseX = input.Position.X
    
    local percent = math.clamp((mouseX - sliderX) / sliderWidth, 0, 1)
    SliderFill.Size = UDim2.new(percent, 0, 1, 0)
    
    local vol = math.floor(percent * MAX_VOLUME * 10) / 10 -- 小数点1位まで
    Sound.Volume = vol
    VolLabel.Text = string.format("音量: %.1f", vol)
end

SliderBase.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true
        updateSlider(input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = false
    end
end)

-- ループボタン
LoopBtn.MouseButton1Click:Connect(function()
    isLooping = not isLooping
    Sound.Looped = isLooping
    if isLooping then
        LoopBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
        LoopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        LoopBtn.Text = "🔁 オン"
    else
        LoopBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        LoopBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        LoopBtn.Text = "🔁 オフ"
    end
end)

-- 再生ボタン
PlayBtn.MouseButton1Click:Connect(function()
    if isPlaying then
        isPlaying = false
        Sound:Stop()
        PlayBtn.Text = "▶ 再生"
        PlayBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    else
        local cleanId = PlayInput.Text:match("%d+")
        if cleanId then
            isPlaying = true
            PlayBtn.Text = "■ 停止"
            PlayBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
            Sound.SoundId = "rbxassetid://" .. cleanId
            Sound:Play()
        else
            PlayBtn.Text = "IDが無効です"
            PlayBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
            task.wait(1)
            if not isPlaying then
                PlayBtn.Text = "▶ 再生"
                PlayBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
            end
        end
    end
end)

-- 保存ボタン
SaveBtn.MouseButton1Click:Connect(function()
    local cleanId = SaveInput.Text:match("%d+")
    if cleanId then
        local success = saveNewId(cleanId)
        if success then
            addIdToScrollList(cleanId)
            SaveBtn.Text = "成功"
        else
            SaveBtn.Text = "済"
        end
        SaveInput.Text = ""
        task.wait(1)
        SaveBtn.Text = "保存"
    end
end)
