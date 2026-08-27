-- [[ Rscripts Risk Notice ]]
-- This script is not verified by rscripts.net. Deal with caution.
--
-- Stay safe:
--   • Never log in on unofficial Roblox sites or lookalike domains.
--   • Real Roblox links use roblox.com (check the .com ending).
--   • Treat fake Roblox login / "claim reward" pages as phishing.
-- [[ End Rscripts Risk Notice ]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")


-- Config 
local TeamCheck = true
local AimPart = "Head"
local WallCheck = true
local MaxRange = 300
local FOV = 360

local function IsHostile(Char)
    local ok, Val = pcall(function() return Char:GetAttribute("Hostile") end)
    if ok and Val ~= nil then return Val == true end
    local V = Char:FindFirstChild("Hostile")
    if V and V:IsA("BoolValue") then return V.Value end
    return false
end

local function CanDamage(P)
    local Char = P.Character
    if not Char then return false end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum or Hum.Health <= 0 then return false end
    if Char:FindFirstChild("ForceField") then return false end
    if TeamCheck then
        local MyTeam = LocalPlayer.Team
        local TheirTeam = P.Team
        if MyTeam and TheirTeam and MyTeam == TheirTeam then return false end
        if MyTeam and MyTeam.Name == "Guards" then
            if not IsHostile(Char) then return false end
        end
    end
    return true
end

local function IsVisible(Char, Origin)
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = LocalPlayer.Character and { LocalPlayer.Character } or {}
    local CheckParts = {
        Char:FindFirstChild(AimPart), Char:FindFirstChild("Head"),
        Char:FindFirstChild("HumanoidRootPart"), Char:FindFirstChild("UpperTorso"),
        Char:FindFirstChild("LowerTorso"), Char:FindFirstChild("Torso"),
    }
    for _, CP in ipairs(CheckParts) do
        if not CP then continue end
        local Dir = CP.Position - Origin
        if Dir.Magnitude <= 0 then continue end
        local Result = Workspace:Raycast(Origin, Dir, Params)
        if not Result or Result.Instance:FindFirstAncestorOfClass("Model") == Char then return CP end
    end
    return nil
end

local function GetTarget(Origin)
    if typeof(Origin) ~= "Vector3" then
        local Cam = Workspace.CurrentCamera
        Origin = Cam and Cam.CFrame.Position or Vector3.new()
    end
    local Cam = Workspace.CurrentCamera
    if not Cam then return nil end
    local BestDist = FOV
    local BestPart = nil
    local MyChar = LocalPlayer.Character
    for _, P in pairs(Players:GetPlayers()) do
        if P == LocalPlayer then continue end
        if not CanDamage(P) then continue end
        local Char = P.Character
        local Part = Char:FindFirstChild(AimPart) or Char:FindFirstChild("Head")
        if not Part then continue end
        if MaxRange and (Origin - Part.Position).Magnitude > MaxRange then continue end
        local Pos, OnScreen = Cam:WorldToViewportPoint(Part.Position)
        if not OnScreen then continue end
        if (Part.Position - Cam.CFrame.Position):Dot(Cam.CFrame.LookVector) <= 0 then continue end
        local SDist = (Vector2.new(Pos.X, Pos.Y) - UserInputService:GetMouseLocation()).Magnitude
        if SDist >= BestDist then continue end
        if WallCheck then
            local VisPart = IsVisible(Char, Origin)
            if not VisPart then continue end
            Part = VisPart
        end
        BestPart = Part
        BestDist = SDist
    end
    return BestPart
end

local function GetAttr(Tool, Attr)
    if typeof(Tool) == "Instance" then
        local ok, Val = pcall(function() return Tool:GetAttribute(Attr) end)
        if ok then return Val end
    end
    return nil
end

local function NormalCast(p1, p2, p3)
    local Origin, Aim, Tool
    if typeof(p1) == "Vector3" then
        Origin = p1
        if typeof(p2) == "Vector3" then Aim = p2 elseif typeof(p3) == "Vector3" then Aim = p3 end
        if typeof(p2) == "Instance" then Tool = p2 elseif typeof(p3) == "Instance" then Tool = p3 end
    else
        Tool = p1
        if typeof(p2) == "Vector3" then Origin = p2 end
        if typeof(p3) == "Vector3" then Aim = p3 elseif typeof(p2) == "Vector3" then Aim = p2 end
    end
    if not Origin or not Aim then return nil, Vector3.new() end
    local Dir = Aim - Origin
    if Dir.Magnitude <= 0 then Dir = Vector3.new(0, 0, -1) end
    local Range = GetAttr(Tool, "Range") or 200
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = LocalPlayer.Character and { LocalPlayer.Character } or {}
    Params.CollisionGroup = "ClientBullet"
    local Result = Workspace:Raycast(Origin, Dir.Unit * Range, Params)
    if Result then return Result.Instance, Result.Position end
    return nil, Origin + Dir.Unit * Range
end

local function HookCast(p1, p2, p3)
    local Origin
    if typeof(p1) == "Vector3" then Origin = p1
    elseif typeof(p2) == "Vector3" then Origin = p2
    elseif typeof(p3) == "Vector3" then Origin = p3 end
    if Origin then
        local Char = LocalPlayer.Character
        local Root = Char and Char:FindFirstChild("HumanoidRootPart")
        if Root and (Origin - Root.Position).Magnitude <= 75 then
            local Target = GetTarget(Origin)
            if Target and Target.Parent then
                return Target, Target.Position
            end
        end
    end
    return NormalCast(p1, p2, p3)
end


if not _G.SilentAimHooked then
    _G.SilentAimHooked = true
    task.spawn(function()
        local hooked = 0
        for _, Func in next, getgc(true) do
            if type(Func) == "function" then
                local Info = debug.getinfo(Func, "nS")
                if Info and Info.name == "castRay" then
                    pcall(hookfunction, Func, HookCast)
                    hooked = hooked + 1
                end
            end
            if hooked >= 5 then break end
        end
    end)
end
