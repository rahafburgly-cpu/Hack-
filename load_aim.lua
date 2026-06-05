-- Self-executing loadstring script: Auto-aim (client-side)
-- Fetch and execute with: loadstring(game:HttpGet("https://raw.githubusercontent.com/rahafburgly-cpu/Hack-/main/load_aim.lua"))()
-- WARNING: Executing remote code can be risky. Only run this in a permitted environment and with trusted code.

-- Configuration
local Config = {
    Enabled = false,
    FOV = 120,
    Smoothness = 0.15,
    WallCheck = true,
    TargetSwitch = true,
    AutoCombat = false,
    AttackRange = 8,
    DetectionRange = 150
}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

if not localPlayer then
    -- If LocalPlayer is nil, the environment may not be a client context. Still continue and try to wait.
    warn("LocalPlayer not available right away. This script should run in a client context (LocalScript).")
    -- Try to wait briefly for a local player (helps in some injected environments)
    for i = 1, 10 do
        wait(0.1)
        localPlayer = Players.LocalPlayer
        if localPlayer then break end
    end
    if not localPlayer then
        warn("LocalPlayer still not found. Script will not run until a LocalPlayer is available.")
    end
end

-- Smoothly rotate character toward target
local function SmoothLook(character, targetPos, smoothness)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local goal = CFrame.lookAt(
        root.Position,
        Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    )

    root.CFrame = root.CFrame:Lerp(goal, smoothness)
end

-- Check if target is visible
local function HasLineOfSight(originPart, targetPart)
    if not originPart or not targetPart then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {
        originPart.Parent,
        targetPart.Parent
    }

    local direction = targetPart.Position - originPart.Position
    local result = workspace:Raycast(originPart.Position, direction, params)

    if not result then
        return true
    end

    return result.Instance and result.Instance:IsDescendantOf(targetPart.Parent)
end

-- Find closest target
local function GetClosestTarget(npc, targets, maxDistance)
    local bestTarget = nil
    local shortestDistance = maxDistance or math.huge

    local root = npc and npc:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    for _, target in ipairs(targets) do
        local hrp = target and target:FindFirstChild("HumanoidRootPart")
        local humanoid = target and target:FindFirstChildOfClass("Humanoid")

        if hrp and humanoid and humanoid.Health > 0 then
            local distance = (hrp.Position - root.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                bestTarget = target
            end
        end
    end

    return bestTarget
end

local function getTargets()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if localPlayer and p ~= localPlayer or (not localPlayer) then
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

-- Main loop
local connected = false
local function startLoop()
    if connected then return end
    connected = true

    RunService.RenderStepped:Connect(function()
        if not Config.Enabled then return end
        if not localPlayer then return end

        local char = localPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end

        local targets = getTargets()
        if #targets == 0 then return end

        local closest = GetClosestTarget(char, targets, Config.DetectionRange)
        if not closest then return end

        local localHRP = char:FindFirstChild("HumanoidRootPart")
        local targetHRP = closest:FindFirstChild("HumanoidRootPart")
        if not localHRP or not targetHRP then return end

        if not Config.WallCheck or HasLineOfSight(localHRP, targetHRP) then
            SmoothLook(char, targetHRP.Position, Config.Smoothness)

            -- AutoCombat placeholder: implement game-specific attack logic here if desired
            -- if Config.AutoCombat then
            --     -- e.g., fire a RemoteEvent or simulate input
            -- end
        end
    end)

    -- Toggle with RightAlt
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightAlt then
            Config.Enabled = not Config.Enabled
            print("Auto-aim enabled:", Config.Enabled)
        end
    end)
end

-- Attempt to start immediately or when LocalPlayer appears
if localPlayer then
    startLoop()
else
    Players.PlayerAdded:Connect(function(player)
        if player == Players.LocalPlayer then
            localPlayer = player
            startLoop()
        end
    end)
end
