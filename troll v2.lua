-- ==========================================
-- 古いバージョンのスクリプト無効化・キック処理
-- ==========================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ロードされた瞬間にプレイヤーをキックし、メッセージを表示
if LocalPlayer then
    LocalPlayer:Kick("⚠️ このスクリプトは古いバージョンです。\n新しいスクリプトを使用してください！")
end
