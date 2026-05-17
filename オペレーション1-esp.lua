-- ==========================================================
-- 🌫️ Viewmodels専用：薄型ハイライトESP
-- 全体を光らせつつ、透明度を高くして「薄く」表示します。
-- 角かっこ（Drawing API）は使用せず、標準のHighlightを使用します。
-- ==========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- --- 設定（ここで薄さを調整してください） ---
local Config = {
    Color = Color3.fromRGB(0, 255, 150), -- エメラルドグリーン（薄くしても見やすい色）
    FillTransparency = 0.8,             -- 塗りつぶしの透明度 (0:濃い ～ 1:見えない)
    OutlineTransparency = 0.5,          -- 外枠の透明度 (0:ハッキリ ～ 1:見えない)
    Enabled = true
}

-- 🛡️ 描画コンテナの作成
local HiddenUI = (gethui and gethui()) or game:GetService("CoreGui")
if HiddenUI:FindFirstChild("FaintView_ESP") then HiddenUI.FaintView_ESP:Destroy() end

local ScreenGui = Instance.new("ScreenGui", HiddenUI)
ScreenGui.Name = "FaintView_ESP"

local Cache = {}

-- ハイライトを適用・更新する関数
local function applyFaintHighlight(model)
    if not model:IsA("Model") then return end

    -- 🛡️ フィルター: 自分の腕（LocalPlayerのモデル）は除外
    local nameLower = model.Name:lower()
    if nameLower:find(LP.Name:lower()) or nameLower:find("local") then
        if Cache[model] then
            Cache[model].Enabled = false
        end
        return
    end

    -- ハイライトの作成または更新
    local highlight = Cache[model]
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "ThinHighlight"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = ScreenGui
        Cache[model] = highlight
    end

    -- 見た目の設定
    highlight.Adornee = model
    highlight.FillColor = Config.Color
    highlight.OutlineColor = Color3.new(1, 1, 1) -- 外枠は白にすると綺麗に見えます
    highlight.FillTransparency = Config.FillTransparency
    highlight.OutlineTransparency = Config.OutlineTransparency
    highlight.Enabled = Config.Enabled
end

-- メインループ
RunService.RenderStepped:Connect(function()
    local ViewmodelsFolder = workspace:FindFirstChild("Viewmodels")
    if not ViewmodelsFolder then return end

    -- フォルダ内のモデルをスキャン
    for _, child in ipairs(ViewmodelsFolder:GetChildren()) do
        applyFaintHighlight(child)
    end

    -- 削除されたモデルのキャッシュを掃除
    for model, highlight in pairs(Cache) do
        if not model or not model.Parent or not model:IsDescendantOf(ViewmodelsFolder) then
            highlight:Destroy()
            Cache[model] = nil
        end
    end
end)

print("Faint Viewmodels ESP Loaded. Transparency: " .. Config.FillTransparency)
