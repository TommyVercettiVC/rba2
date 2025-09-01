-- Ragebot Aimbot v2.4
-- With loading notification and performance tracking

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local startTime = os.clock() -- Track script start time

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Initialize variables
local Camera = workspace.CurrentCamera
local FOVCircle = Drawing.new("Circle")
local ESPObjects = {}
local CurrentTarget = nil
local Connections = {}
local AimingMode = "Mouse"
local LastESPUpdate = 0
local TargetHistory = {} -- For prediction calculations

-- Enhanced Configuration Settings
local Config = {
    Enabled = true,
    FOV = 120,
    Smoothness = 0.45,
    MaxLockSpeed = 0.8,
    ActivationDelay = 0,
    TeamCheck = true,
    VisibilityCheck = false,
    TargetPart = "Head",
    AimingMode = "Mouse",
    
    -- Stabilization Settings
    StabilizationEnabled = true,
    MaxAngleChange = 2.5,
    HumanizationFactor = 0.3,
    
    -- FOV Circle Visual Properties
    FOVCircleVisible = true,
    FOVCircleColor = Color3.fromRGB(255, 50, 50),
    FOVCircleTransparency = 0.7,
    FOVCircleSides = 64,
    
    -- ESP Settings
    ESPEnabled = true,
    ESPColor = Color3.fromRGB(255, 50, 50),
    ESPRefreshRate = 0.05,
    
    -- GUI Settings
    GUIVisible = true,
    
    -- Prediction Settings
    PredictionEnabled = true,
    PredictionStrength = 0.15, -- How far ahead to predict (0-1)
}

-- Custom notification function
function showNotification(message, duration)
    duration = duration or 5
    
    -- Create notification GUI
    local notification = Instance.new("ScreenGui")
    notification.Name = "Notification"
    notification.Parent = game.CoreGui
    notification.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 60)
    frame.Position = UDim2.new(1, -260, 1, -70) -- Bottom right
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = notification
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = frame
    
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Thickness = 2
    UIStroke.Color = Color3.fromRGB(80, 80, 100)
    UIStroke.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, -20)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.Text = message
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextWrapped = true
    label.Parent = frame
    
    -- Animate in
    frame.Position = UDim2.new(1, 10, 1, -70) -- Start offscreen to the right
    local tweenIn = TweenService:Create(
        frame,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, -260, 1, -70)}
    )
    tweenIn:Play()
    
    -- Animate out after duration
    delay(duration, function()
        local tweenOut = TweenService:Create(
            frame,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = UDim2.new(1, 10, 1, -70)}
        )
        tweenOut:Play()
        
        tweenOut.Completed:Connect(function()
            notification:Destroy()
        end)
    end)
    
    return notification
end

-- GUI Creation Function
function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RagebotGUI"
    ScreenGui.Parent = game.CoreGui
    ScreenGui.ResetOnSpawn = false

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 300, 0, 400)
    MainFrame.Position = UDim2.new(0, 10, 0, 10)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    MainFrame.BackgroundTransparency = 0.2
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Thickness = 2
    UIStroke.Color = Color3.fromRGB(80, 80, 100)
    UIStroke.Parent = MainFrame

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 40)
    Title.Position = UDim2.new(0, 10, 0, 10)
    Title.Text = "Ragebot Aimbot v2.4"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -30, 0, 10)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 14
    CloseButton.Parent = MainFrame
    
    UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 4)
    UICorner.Parent = CloseButton
    
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        Config.GUIVisible = false
    end)

    -- Toggle Buttons
    local buttonYPosition = 60
    local function createToggleButton(name, configField, yOffset)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 130, 0, 30)
        button.Position = UDim2.new(0, 10, 0, yOffset)
        button.Text = name .. ": " .. (Config[configField] and "ON" or "OFF")
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.BackgroundColor3 = Config[configField] and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
        button.Font = Enum.Font.Gotham
        button.TextSize = 14
        button.Parent = MainFrame
        
        UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 4)
        UICorner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            Config[configField] = not Config[configField]
            button.Text = name .. ": " .. (Config[configField] and "ON" or "OFF")
            button.BackgroundColor3 = Config[configField] and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
            
            if configField == "FOVCircleVisible" then
                FOVCircle.Visible = Config.FOVCircleVisible
            elseif configField == "ESPEnabled" then
                -- Clear ESP objects when toggling
                for _, obj in pairs(ESPObjects) do
                    if obj then
                        obj:Remove()
                    end
                end
                ESPObjects = {}
            end
        end)
        
        return button
    end

    createToggleButton("Aimbot", "Enabled", 60)
    createToggleButton("Team Check", "TeamCheck", 100)
    createToggleButton("Visibility Check", "VisibilityCheck", 140)
    createToggleButton("Stabilization", "StabilizationEnabled", 180)
    createToggleButton("ESP", "ESPEnabled", 220)
    createToggleButton("Prediction", "PredictionEnabled", 260)

    -- Mode Selection
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(0, 120, 0, 20)
    modeLabel.Position = UDim2.new(0, 10, 0, 300)
    modeLabel.Text = "Aiming Mode:"
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.TextSize = 14
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.Parent = MainFrame

    local modeDropdown = Instance.new("TextButton")
    modeDropdown.Size = UDim2.new(0, 120, 0, 30)
    modeDropdown.Position = UDim2.new(0, 10, 0, 320)
    modeDropdown.Text = Config.AimingMode
    modeDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    modeDropdown.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    modeDropdown.Font = Enum.Font.Gotham
    modeDropdown.TextSize = 14
    modeDropdown.Parent = MainFrame
    
    UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 4)
    UICorner.Parent = modeDropdown
    
    modeDropdown.MouseButton1Click:Connect(function()
        if Config.AimingMode == "Mouse" then
            Config.AimingMode = "Camera"
        else
            Config.AimingMode = "Mouse"
        end
        modeDropdown.Text = Config.AimingMode
    end)

    -- Slider Controls
    local function createSlider(name, configField, minValue, maxValue, yOffset)
        local sliderLabel = Instance.new("TextLabel")
        sliderLabel.Size = UDim2.new(0, 120, 0, 20)
        sliderLabel.Position = UDim2.new(0, 150, 0, yOffset)
        sliderLabel.Text = name .. ": " .. Config[configField]
        sliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        sliderLabel.BackgroundTransparency = 1
        sliderLabel.Font = Enum.Font.Gotham
        sliderLabel.TextSize = 12
        sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
        sliderLabel.Parent = MainFrame

        local slider = Instance.new("Frame")
        slider.Size = UDim2.new(0, 120, 0, 5)
        slider.Position = UDim2.new(0, 150, 0, yOffset + 20)
        slider.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
        slider.BorderSizePixel = 0
        slider.Parent = MainFrame
        
        UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(1, 0)
        UICorner.Parent = slider

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((Config[configField] - minValue) / (maxValue - minValue), 0, 1, 0)
        fill.Position = UDim2.new(0, 0, 0, 0)
        fill.BackgroundColor3 = Color3.fromRGB(80, 160, 80)
        fill.BorderSizePixel = 0
        fill.Parent = slider
        
        UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(1, 0)
        UICorner.Parent = fill

        local sliderButton = Instance.new("TextButton")
        sliderButton.Size = UDim2.new(0, 120, 0, 20)
        sliderButton.Position = UDim2.new(0, 150, 0, yOffset + 15)
        sliderButton.Text = ""
        sliderButton.BackgroundTransparency = 1
        sliderButton.Parent = MainFrame
        
        sliderButton.MouseButton1Down:Connect(function()
            local connection
            connection = RunService.RenderStepped:Connect(function()
                local mousePos = UserInputService:GetMouseLocation()
                local relativeX = math.clamp(mousePos.X - slider.AbsolutePosition.X, 0, slider.AbsoluteSize.X)
                local value = minValue + (relativeX / slider.AbsoluteSize.X) * (maxValue - minValue)
                Config[configField] = math.floor(value * 100) / 100
                fill.Size = UDim2.new((value - minValue) / (maxValue - minValue), 0, 1, 0)
                sliderLabel.Text = name .. ": " .. Config[configField]
                
                if configField == "FOV" then
                    FOVCircle.Radius = Config.FOV
                end
            end)
            
            local disconnect
            disconnect = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    connection:Disconnect()
                    disconnect:Disconnect()
                end
            end)
        end)
    end

    createSlider("FOV", "FOV", 50, 250, 60)
    createSlider("Smoothness", "Smoothness", 0.1, 1, 100)
    createSlider("Max Speed", "MaxLockSpeed", 0.1, 2, 140)
    createSlider("Humanization", "HumanizationFactor", 0, 0.5, 180)
    createSlider("Prediction", "PredictionStrength", 0, 0.3, 220)
end

-- Initialize GUI
createGUI()

-- Configure FOV circle visualization 
function configureFOVCircle()
    FOVCircle.Visible = Config.FOVCircleVisible
    FOVCircle.Radius = Config.FOV
    FOVCircle.Color = Config.FOVCircleColor
    FOVCircle.Transparency = Config.FOVCircleTransparency
    FOVCircle.NumSides = Config.FOVCircleSides
    FOVCircle.Thickness = 2
    FOVCircle.Filled = false
end

-- Update FOV circle position
function updateFOVCircle()
    FOVCircle.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
end

-- Calculate predicted position based on target velocity
function calculatePredictedPosition(targetPart, timeToTarget)
    if not targetPart or not targetPart.Velocity then
        return targetPart.Position
    end
    
    -- Get target velocity
    local velocity = targetPart.Velocity
    
    -- Calculate predicted position
    local predictedPosition = targetPart.Position + (velocity * timeToTarget * Config.PredictionStrength)
    
    return predictedPosition
end

-- Enhanced target finding with stabilization and prediction
function findTarget()
    local bestTarget = nil
    local bestTargetPosition = nil
    local closestDistance = Config.FOV
    local lastTargetTime = os.clock()
    
    for _, player in ipairs(Players:GetPlayers()) do
        -- Skip invalid targets
        if player == LocalPlayer then continue end
        if not player.Character then continue end
        if not player.Character:FindFirstChild("Humanoid") then continue end
        if not player.Character:FindFirstChild("HumanoidRootPart") then continue end
        if player.Character.Humanoid.Health <= 0 then continue end
        if Config.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        -- Get target body part
        local targetPart = player.Character:FindFirstChild(Config.TargetPart)
        if not targetPart then
            targetPart = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
        end
        
        -- Calculate predicted position if enabled
        local targetWorldPosition = targetPart.Position
        if Config.PredictionEnabled then
            -- Estimate time to target based on distance
            local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
            local timeToTarget = distance / 1000 -- Rough estimation
            
            targetWorldPosition = calculatePredictedPosition(targetPart, timeToTarget)
        end
        
        -- Calculate screen position
        local targetPosition, onScreen = Camera:WorldToViewportPoint(targetWorldPosition)
        if not onScreen then continue end
        
        -- Check visibility if enabled
        if Config.VisibilityCheck then
            local origin = Camera.CFrame.Position
            local direction = (targetWorldPosition - origin).Unit * (origin - targetWorldPosition).Magnitude
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
            
            local raycastResult = workspace:Raycast(origin, direction, raycastParams)
            if raycastResult and raycastResult.Instance:FindFirstAncestor(player.Name) == nil then
                continue  -- Target is not visible
            end
        end
        
        -- Calculate distance to mouse
        local mousePosition = UserInputService:GetMouseLocation()
        local distance = (Vector2.new(targetPosition.X, targetPosition.Y) - Vector2.new(mousePosition.X, mousePosition.Y)).Magnitude
        
        -- Check if target is within FOV and closest
        if distance < closestDistance then
            closestDistance = distance
            bestTarget = player
            bestTargetPosition = targetPosition
            
            -- Store target history for prediction
            if not TargetHistory[player] then
                TargetHistory[player] = {}
            end
            
            table.insert(TargetHistory[player], {
                position = targetPart.Position,
                time = os.clock()
            })
            
            -- Keep only recent history
            while #TargetHistory[player] > 5 do
                table.remove(TargetHistory[player], 1)
            end
        end
    end
    
    -- Stabilization: Prevent rapid target switching
    if CurrentTarget and bestTarget and CurrentTarget ~= bestTarget then
        if os.clock() - lastTargetTime < Config.ActivationDelay then
            -- Keep the current target for a bit longer to prevent rapid switching
            bestTarget = CurrentTarget
            if bestTarget.Character and bestTarget.Character:FindFirstChild(Config.TargetPart) then
                local targetPart = bestTarget.Character:FindFirstChild(Config.TargetPart)
                bestTargetPosition = Camera:WorldToViewportPoint(targetPart.Position)
            end
        else
            lastTargetTime = os.clock()
        end
    end
    
    return bestTarget, bestTargetPosition
end

-- Fixed stabilization aiming function
function stabilizedAim(targetPosition)
    if not targetPosition then return end
    
    local mousePosition = UserInputService:GetMouseLocation()
    local targetVector = Vector2.new(targetPosition.X, targetPosition.Y)
    local direction = (targetVector - mousePosition)
    
    -- Apply stabilization to prevent jittery movement
    if Config.StabilizationEnabled then
        -- Calculate the desired movement
        local desiredMovement = direction * Config.Smoothness
        
        -- Limit the maximum movement per frame
        local maxMovement = Config.MaxLockSpeed
        if desiredMovement.Magnitude > maxMovement then
            desiredMovement = desiredMovement.Unit * maxMovement
        end
        
        -- Apply human-like imperfection
        if Config.HumanizationFactor > 0 then
            local imperfection = Vector2.new(
                (math.random() * 2 - 1) * Config.HumanizationFactor,
                (math.random() * 2 - 1) * Config.HumanizationFactor
            )
            desiredMovement = desiredMovement + imperfection
        end
        
        -- Apply the movement
        if Config.AimingMode == "Mouse" then
            mousemoverel(desiredMovement.X, desiredMovement.Y)
        else
            -- Camera mode: Adjust the camera directly
            local camCFrame = Camera.CFrame
            local deltaX = desiredMovement.X / 500
            local deltaY = desiredMovement.Y / 500
            
            -- Apply rotation to camera
            local newCFrame = camCFrame * CFrame.Angles(-deltaY, -deltaX, 0)
            Camera.CFrame = newCFrame
        end
    else
        -- Simple smoothing without stabilization
        local smoothAdjustment = direction * Config.Smoothness
        
        if Config.AimingMode == "Mouse" then
            mousemoverel(smoothAdjustment.X, smoothAdjustment.Y)
        else
            -- Camera mode
            local camCFrame = Camera.CFrame
            local deltaX = smoothAdjustment.X / 500
            local deltaY = smoothAdjustment.Y / 500
            local newCFrame = camCFrame * CFrame.Angles(-deltaY, -deltaX, 0)
            Camera.CFrame = newCFrame
        end
    end
end

-- Always-on targeting logic with stabilization
function rageAimbot()
    if not Config.Enabled or not LocalPlayer.Character then return end
    
    local target, position = findTarget()
    if target then
        CurrentTarget = target
        stabilizedAim(position)
    else
        CurrentTarget = nil
    end
end

-- Improved ESP function with continuous updates
function updateESP()
    if not Config.ESPEnabled then return end
    
    -- Only update ESP at the configured refresh rate
    local now = os.clock()
    if now - LastESPUpdate < Config.ESPRefreshRate then return end
    LastESPUpdate = now
    
    -- Track which players currently have ESP
    local activePlayers = {}
    
    -- Update ESP for all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            activePlayers[player] = true
            
            -- Create ESP if it doesn't exist
            if not ESPObjects[player] then
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Config.ESPColor
                highlight.OutlineColor = Config.ESPColor
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = player.Character
                
                ESPObjects[player] = highlight
            else
                -- Update existing ESP
                local highlight = ESPObjects[player]
                highlight.Enabled = true
                highlight.FillColor = Config.ESPColor
                highlight.OutlineColor = Config.ESPColor
                
                -- Make sure it's parented to the current character
                if highlight.Parent ~= player.Character then
                    highlight.Parent = player.Character
                end
            end
        end
    end
    
    -- Remove ESP for players who left or are no longer valid
    for player, highlight in pairs(ESPObjects) do
        if not activePlayers[player] and highlight then
            highlight:Destroy()
            ESPObjects[player] = nil
        end
    end
end

-- Set up connections
function initializeConnections()
    -- Main aimbot loop
    table.insert(Connections, RunService.RenderStepped:Connect(function()
        updateFOVCircle()
        rageAimbot()
    end))
    
    -- ESP update loop
    table.insert(Connections, RunService.Heartbeat:Connect(function()
        updateESP()
    end))
    
    -- GUI toggle hotkey
    table.insert(Connections, UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Insert then
            local gui = game.CoreGui:FindFirstChild("RagebotGUI")
            if gui then
                gui.Enabled = not gui.Enabled
                Config.GUIVisible = gui.Enabled
            end
        end
    end))
    
    -- Clean up ESP when players leave
    table.insert(Connections, Players.PlayerRemoving:Connect(function(player)
        if ESPObjects[player] then
            ESPObjects[player]:Destroy()
            ESPObjects[player] = nil
        end
        
        -- Clean up target history
        TargetHistory[player] = nil
    end))
end

-- Initialize the script
configureFOVCircle()
initializeConnections()

-- Show loading notification
local loadTime = os.clock() - startTime
showNotification(string.format("Ragebot loaded in %.3f seconds", loadTime), 5)

-- Cleanup function
function cleanup()
    for _, connection in ipairs(Connections) do
        connection:Disconnect()
    end
    
    FOVCircle:Remove()
    
    for _, obj in pairs(ESPObjects) do
        if obj then
            obj:Remove()
        end
    end
    
    local gui = game.CoreGui:FindFirstChild("RagebotGUI")
    if gui then
        gui:Destroy()
    end
end

-- Automatic cleanup if script is stopped
local function onScriptStopped()
    cleanup()
end

-- Connect cleanup to script termination
if getgenv and getgenv().ScriptStop then
    getgenv().ScriptStop:Connect(onScriptStopped)
end
