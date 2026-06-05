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

-- Smoothly rotate NPC toward target
local function SmoothLook(character, targetPos, smoothness)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local goal = CFrame.lookAt(
        root.Position,
        Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    )

    root.CFrame = root.CFrame:Lerp(goal, smoothness)
end

-- Check if target is visible
local function HasLineOfSight(originPart, targetPart)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {
        originPart.Parent,
        targetPart.Parent
    }

    local direction = targetPart.Position - originPart.Position

    local result = workspace:Raycast(
        originPart.Position,
        direction,
        params
    )

    if not result then
        return true
    end

    return result.Instance:IsDescendantOf(targetPart.Parent)
end

-- Find closest target
local function GetClosestTarget(npc, targets, maxDistance)
    local bestTarget = nil
    local shortestDistance = maxDistance

    local root = npc:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    for _, target in ipairs(targets) do
        local hrp = target:FindFirstChild("HumanoidRootPart")
        local humanoid = target:FindFirstChildOfClass("Humanoid")

        if hrp and humanoid and humanoid.Health > 0 then
            local distance =
                (hrp.Position - root.Position).Magnitude

            if distance < shortestDistance then
                shortestDistance = distance
                bestTarget = target
            end
        end
    end

    return bestTarget
end

return {
    Config = Config,
    SmoothLook = SmoothLook,
    HasLineOfSight = HasLineOfSight,
    GetClosestTarget = GetClosestTarget
}