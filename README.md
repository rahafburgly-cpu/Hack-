-- LocalScript inside StarterPlayerScripts
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- --- STATE & CONFIGURATION ---
local Settings = {
	SilentAimEnabled = true,
	ESPEnabled = true,
	VisibleOnly = true,
	FOV_Radius = 80, 
}

local UI_Toggle_Key = Enum.KeyCode.RightShift
local IsMassKilling = false
local ESP_Cache = {}

-- --- 1. 360° DYNAMIC VISUAL FOV CIRCLE ---
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 200, 255)
FOVCircle.Filled = false
FOVCircle.Transparency = 0.5
FOVCircle.NumSides = 64
FOVCircle.Visible = Settings.SilentAimEnabled

RunService.RenderStepped:Connect(function()
	if not Settings.SilentAimEnabled then 
		FOVCircle.Visible = false 
		return 
	end
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	FOVCircle.Position = center
	local cameraPerspectiveFactor = (Settings.FOV_Radius / (Camera.CFrame.Position - Camera.Focus.Position).Magnitude) * Camera.ViewportSize.Y
	FOVCircle.Radius = math.clamp(cameraPerspectiveFactor, 10, Camera.ViewportSize.X)
	FOVCircle.Visible = true
end)

-- --- 2. VECTOR BOX & TRACER ESP SYSTEM ---
local function createESPObjects()
	local box = Drawing.new("Square")
	box.Thickness = 1.5
	box.Color = Color3.fromRGB(255, 0, 75)
	box.Filled = false
	box.Transparency = 0.8
	box.Visible = false

	local tracer = Drawing.new("Line")
	tracer.Thickness = 1
	tracer.Color = Color3.fromRGB(255, 255, 255)
	tracer.Transparency = 0.6
	tracer.Visible = false

	return {Box = box, Tracer = tracer}
end

local function cleanESP(player)
	if ESP_Cache[player] then
		ESP_Cache[player].Box:Destroy()
		ESP_Cache[player].Tracer:Destroy()
		ESP_Cache[player] = nil
	end
end

local function updateESP()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		
		if not Settings.ESPEnabled then
			if ESP_Cache[player] then
				ESP_Cache[player].Box.Visible = false
				ESP_Cache[player].Tracer.Visible = false
			end
			continue
		end

		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if rootPart and humanoid and humanoid.Health > 0 then
			local _, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

			if onScreen then
				if not ESP_Cache[player] then
					ESP_Cache[player] = createESPObjects()
				end

				-- Calculate sizes based on character bound distances
				local extents = character:GetExtentsSize()
				local topWorld = (rootPart.CFrame * CFrame.new(0, extents.Y / 2, 0)).Position
				local bottomWorld = (rootPart.CFrame * CFrame.new(0, -extents.Y / 2, 0)).Position

				local topScreen, _ = Camera:WorldToViewportPoint(topWorld)
				local bottomScreen, _ = Camera:WorldToViewportPoint(bottomWorld)

				local boxHeight = math.abs(topScreen.Y - bottomScreen.Y)
				local boxWidth = boxHeight * 0.6 -- Standard humanoid aspect ratio helper

				local drawings = ESP_Cache[player]

				-- Configure 2D Box Position
				drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
				drawings.Box.Position = Vector2.new(topScreen.X - (boxWidth / 2), topScreen.Y)
				drawings.Box.Visible = true

				-- Configure Tracer starting from Top-Middle of Screen
				drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, 0)
				drawings.Tracer.To = Vector2.new(topScreen.X, topScreen.Y)
				drawings.Tracer.Visible = true
			else
				if ESP_Cache[player] then
					ESP_Cache[player].Box.Visible = false
					ESP_Cache[player].Tracer.Visible = false
				end
			end
		else
			if ESP_Cache[player] then
				ESP_Cache[player].Box.Visible = false
				ESP_Cache[player].Tracer.Visible = false
			end
		end
	end
end

Players.PlayerRemoving:Connect(cleanESP)
RunService.RenderStepped:Connect(updateESP)

-- --- 3. LINE OF SIGHT CHECK ---
local function isPlayerVisible(targetCharacter, targetHead)
	if not Settings.VisibleOnly then return true end
	
	local origin = Camera.CFrame.Position
	local direction = targetHead.Position - origin
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)
	return raycastResult == nil
end

-- --- 4. 360° TARGET ACQUISITION ---
local function getClosestPlayer360()
	if not Settings.SilentAimEnabled or not LocalPlayer.Character then return nil end
	
	local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end
	
	local closestPlayer = nil
	local shortestStudDistance = Settings.FOV_Radius

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
			local head = player.Character:FindFirstChild("Head")
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			
			if enemyRoot and head and humanoid and humanoid.Health > 0 then
				local studDistance = (enemyRoot.Position - myRoot.Position).Magnitude
				if studDistance < shortestStudDistance then
					if isPlayerVisible(player.Character, head) then
						shortestStudDistance = studDistance
						closestPlayer = player
					end
				end
			end
		end
	end
	return closestPlayer
end

-- --- 5. METATABLE INDEX HOOK ---
local oldIndex
oldIndex = hookmetamethod(game, "__index", function(self, index)
	if self == Mouse and (index == "Hit" or index == "Target") then
		if Settings.SilentAimEnabled then
			local targetPlayer = getClosestPlayer360()
			if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") then
				if index == "Hit" then
					return targetPlayer.Character.Head.CFrame
				elseif index == "Target" then
					return targetPlayer.Character.Head
				end
			end
		end
	end
	return oldIndex(self, index)
end)

-- --- 6. MASS KILL LOGIC ---
local function executeMassKill()
	if IsMassKilling then return end
	IsMassKilling = true
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
			local targetHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			
			if targetRoot and targetHumanoid and targetHumanoid.Health > 0 and myRoot then
				myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 3, 2)
				task.wait(0.1)
				
				while targetHumanoid and targetHumanoid.Health > 0 and IsMassKilling do
					Mouse.Target = player.Character:FindFirstChild("Head")
					
					local activeTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
					if activeTool then
						activeTool:Activate()
					end
					
					task.wait(0.05)
				end
			end
		end
		if not IsMassKilling then break end
	end
	
	IsMassKilling = false
end

-- --- 7. DYNAMIC UI PANEL ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DevTestingSuiteSuite"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 310)
MainFrame.Position = UDim2.new(0, 50, 0, 50)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(22, 28, 35)
Title.Text = "  Developer Suite [RShift]"
Title.TextColor3 = Color3.fromRGB(0, 200, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 1, -250)
Container.Position = UDim2.new(0, 10, 0, 50)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.Parent = Container

local function createToggle(name, defaultStatus, callback)
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1, 0, 0, 35)
	Button.BackgroundColor3 = defaultStatus and Color3.fromRGB(40, 150, 100) or Color3.fromRGB(150, 50, 50)
	Button.Font = Enum.Font.SourceSansSemibold
	Button.TextSize = 15
	Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	Button.Text = name .. ": " .. (defaultStatus and "ON" or "OFF")
	Button.Parent = Container
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = Button
	
	local enabled = defaultStatus
	Button.MouseButton1Click:Connect(function()
		enabled = not enabled
		Button.BackgroundColor3 = enabled and Color3.fromRGB(40, 150, 100) or Color3.fromRGB(150, 50, 50)
		Button.Text = name .. ": " .. (enabled and "ON" or "OFF")
		callback(enabled)
	end)
end

local function createSlider(name, min, max, default, callback)
	local SliderFrame = Instance.new("Frame")
	SliderFrame.Size = UDim2.new(1, 0, 0, 45)
	SliderFrame.BackgroundTransparency = 1
	SliderFrame.Parent = Container
	
	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, 0, 0, 20)
	Label.BackgroundTransparency = 1
	Label.Text = name .. ": " .. tostring(default) .. " Studs"
	Label.TextColor3 = Color3.fromRGB(200, 200, 200)
	Label.Font = Enum.Font.SourceSans
	Label.TextSize = 14
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = SliderFrame
	
	local SliderBack = Instance.new("TextButton")
	SliderBack.Size = UDim2.new(1, 0, 0, 8)
	SliderBack.Position = UDim2.new(0, 0, 0, 25)
	SliderBack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	SliderBack.Text = ""
	SliderBack.Parent = SliderFrame
	
	local SliderMain = Instance.new("Frame")
	local relativePct = (default - min) / (max - min)
	SliderMain.Size = UDim2.new(relativePct, 0, 1, 0)
	SliderMain.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
	SliderMain.BorderSizePixel = 0
	SliderMain.Parent = SliderBack
	
	local function updateSlider(input)
		local xOffset = math.clamp(input.Position.X - SliderBack.AbsolutePosition.X, 0, SliderBack.AbsoluteSize.X)
		local percentage = xOffset / SliderBack.AbsoluteSize.X
		SliderMain.Size = UDim2.new(percentage, 0, 1, 0)
		
		local rawValue = min + (percentage * (max - min))
		local finalValue = math.round(rawValue)
		Label.Text = name .. ": " .. tostring(finalValue) .. " Studs"
		callback(finalValue)
	end
	
	local sliding = false
	SliderBack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			updateSlider(input)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSlider(input)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = false
		end
	end)
end

createToggle("Silent 360 Engine", Settings.SilentAimEnabled, function(val)
	Settings.SilentAimEnabled = val
end)

createToggle("Wall Occlusion Check", Settings.VisibleOnly, function(val)
	Settings.VisibleOnly = val
end)

createToggle("2D Box & Tracer ESP", Settings.ESPEnabled, function(val)
	Settings.ESPEnabled = val
end)

createSlider("360 FOV Max Range", 10, 500, Settings.FOV_Radius, function(val)
	Settings.FOV_Radius = val
end)

local MassKillButton = Instance.new("TextButton")
MassKillButton.Size = UDim2.new(1, 0, 0, 35)
MassKillButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
MassKillButton.Font = Enum.Font.SourceSansBold
MassKillButton.TextSize = 16
MassKillButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MassKillButton.Text = "EXECUTE MASS KILL"
MassKillButton.Parent = Container

local killCorner = Instance.new("UICorner")
killCorner.CornerRadius = UDim.new(0, 6)
killCorner.Parent = MassKillButton

MassKillButton.MouseButton1Click:Connect(function()
	if not IsMassKilling then
		task.spawn(executeMassKill)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == UI_Toggle_Key then
		MainFrame.Visible = not MainFrame.Visible
	end
end)
