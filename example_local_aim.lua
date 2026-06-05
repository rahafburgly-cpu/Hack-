-- Example LocalScript: Auto-aim using module from GitHub
-- Place this as a LocalScript (StarterPlayerScripts) and ensure HttpEnabled is on if using loadstring+HttpGet.

local ok, Module = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/rahafburgly-cpu/Hack-/main/script.lua"))()
end)

if not ok or type(Module) ~= "table" then
    error("Failed to load module from GitHub. Make sure HttpEnabled is true and the URL is reachable.")
end

local Config = Module.Config
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

if not localPlayer then
    warn("LocalPlayer not found. This script should be a LocalScript placed in a client context (StarterPlayerScripts).")
    return
end

local function getTargets()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            local c = p.Character
            local humanoid = c and c:FindFirstChildOfClass("Humanoid")
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if c and humanoid and hrp and humanoid.Health > 0 then
                table.insert(list, c)
            end
        end
    end
    return list
end

-- Main loop: smoothly look at the closest target when enabled
RunService.RenderStepped:Connect(function()
    if not Config.Enabled then return end

    local char = localPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local targets = getTargets()
    if #targets == 0 then return end

    local closest = Module.GetClosestTarget(char, targets, Config.DetectionRange)
    if not closest then return end

    local localHRP = char:FindFirstChild("HumanoidRootPart")
    local targetHRP = closest:FindFirstChild("HumanoidRootPart")
    if not localHRP or not targetHRP then return end

    if not Config.WallCheck or Module.HasLineOfSight(localHRP, targetHRP) then
        Module.SmoothLook(char, targetHRP.Position, Config.Smoothness)

        -- Optional: Auto-combat placeholder. Implement your game's attack logic here.
        -- if Config.AutoCombat then
        --     -- e.g., fire a remote event, simulate input, or call an ability function
        -- end
    end
end)

-- Quick helper: toggle the feature with a keybind (RightAlt)
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightAlt then
        Config.Enabled = not Config.Enabled
        print("Auto-aim enabled:", Config.Enabled)
    end
end)
