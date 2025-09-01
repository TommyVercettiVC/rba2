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

--- v1
-- Enhanced Experimental Ragebot Aimbot with GUI
-- Designed for third-party executors (Solara, Xeno, Seliware, etc.)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

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
local AimingMode = "Mouse"  -- "Mouse" or "Camera"

-- Enhanced Configuration Settings
local Config = {
    Enabled = true,
    FOV = 120,
    Smoothness = 0.45,
    MaxLockSpeed = 0.8,      -- Prevents overly rapid locking
    ActivationDelay = 0,  -- Delay before locking onto new targets
    TeamCheck = true,
    VisibilityCheck = false,
    TargetPart = "Head",
    AimingMode = "Mouse",    -- "Mouse" or "Camera"
    
    -- Stabilization Settings
    StabilizationEnabled = true,
    MaxAngleChange = 2.5,    -- Degrees per frame max change
    HumanizationFactor = 0.3, -- Adds human-like imperfection
    
    -- FOV Circle Visual Properties
    FOVCircleVisible = true,
    FOVCircleColor = Color3.fromRGB(255, 50, 50),
    FOVCircleTransparency = 0.7,
    FOVCircleSides = 64,
    
    -- ESP Settings
    ESPEnabled = true,
    ESPColor = Color3.fromRGB(255, 50, 50),
    ESPRefreshRate = 0.1,
    
    -- GUI Settings
    GUIVisible = true,
}

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
    Title.Text = "Ragebot Aimbot v2.0"
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
            end
        end)
        
        return button
    end

    createToggleButton("Aimbot", "Enabled", 60)
    createToggleButton("Team Check", "TeamCheck", 100)
    createToggleButton("Visibility Check", "VisibilityCheck", 140)
    createToggleButton("Stabilization", "StabilizationEnabled", 180)
    createToggleButton("ESP", "ESPEnabled", 220)

    -- Mode Selection
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(0, 120, 0, 20)
    modeLabel.Position = UDim2.new(0, 10, 0, 260)
    modeLabel.Text = "Aiming Mode:"
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.TextSize = 14
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.Parent = MainFrame

    local modeDropdown = Instance.new("TextButton")
    modeDropdown.Size = UDim2.new(0, 120, 0, 30)
    modeDropdown.Position = UDim2.new(0, 10, 0, 280)
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

-- Enhanced target finding with stabilization
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
        
        -- Calculate screen position
        local targetPosition, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        -- Check visibility if enabled
        if Config.VisibilityCheck then
            local origin = Camera.CFrame.Position
            local direction = (targetPart.Position - origin).Unit * (origin - targetPart.Position).Magnitude
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

-- Stabilized aiming function with dual modes
function stabilizedAim(targetPosition)
    if not targetPosition then return end
    
    local mousePosition = UserInputService:GetMouseLocation()
    local targetVector = Vector2.new(targetPosition.X, targetPosition.Y)
    local direction = (targetVector - mousePosition)
    
    -- Apply stabilization to prevent haywire movement
    if Config.StabilizationEnabled then
        -- Limit the maximum angle change per frame
        local maxChange = Config.MaxAngleChange
        local currentAngle = math.atan2(direction.Y, direction.X)
        local currentMagnitude = direction.Magnitude
        local limitedAngle = currentAngle
        
        if CurrentTarget then
            -- Gradually approach the target rather than snapping
            limitedAngle = limitedAngle * math.min(1, Config.MaxLockSpeed / currentMagnitude)
        end
        
        direction = Vector2.new(
            math.cos(limitedAngle) * currentMagnitude,
            math.sin(limitedAngle) * currentMagnitude
        )
        
        -- Add human-like imperfection
        if Config.HumanizationFactor > 0 then
            local imperfection = Vector2.new(
                (math.random() * 2 - 1) * Config.HumanizationFactor,
                (math.random() * 2 - 1) * Config.HumanizationFactor
            )
            direction = direction + imperfection
        end
    end
    
    -- Apply smoothing
    local smoothAdjustment = direction * Config.Smoothness
    
    -- Apply based on aiming mode
    if Config.AimingMode == "Mouse" then
        mousemoverel(smoothAdjustment.X, smoothAdjustment.Y)
    else
        -- Camera mode: Adjust the camera directly
        local camCFrame = Camera.CFrame
        local lookVector = camCFrame.LookVector
        local rightVector = camCFrame.RightVector
        local upVector = camCFrame.UpVector
        
        -- Calculate adjustment angles
        local deltaX = smoothAdjustment.X / 1000
        local deltaY = smoothAdjustment.Y / 1000
        
        -- Apply rotation to camera
        local newCFrame = camCFrame * CFrame.fromEulerAnglesXYZ(-deltaY, -deltaX, 0)
        Camera.CFrame = newCFrame
    end
end

-- Always-on targeting logic with stabilization
function rageAimbot()
    if not Config.Enabled or not LocalPlayer.Character then return end
    
    local target, position = findTarget()
    if target then
        CurrentTarget = target
        stabilizedAim(position)
        
        if Config.AutoFire and LocalPlayer.Character:FindFirstChildWhichIsA("Tool") then
            LocalPlayer.Character:FindFirstChildWhichIsA("Tool"):Activate()
        end
    else
        CurrentTarget = nil
    end
end

-- Enhanced ESP function 
function updateESP()
    if not Config.ESPEnabled then return end
    
    -- Clean up old ESP objects
    for _, obj in pairs(ESPObjects) do
        if obj then
            obj:Remove()
        end
    end
    ESPObjects = {}
    
    -- Create ESP for all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local highlight = Instance.new("Highlight")
            highlight.Parent = player.Character
            highlight.FillColor = Config.ESPColor
            highlight.OutlineColor = Config.ESPColor
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            
            table.insert(ESPObjects, highlight)
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
end

-- Initialize the script
configureFOVCircle()
initializeConnections()

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

--- v2

-- Complete Fixed Ragebot Aimbot with All Features
-- Legit aim mode, improved ESP, custom crosshairs, safety indicator

if not game:IsLoaded() then
    game.Loaded:Wait()
end

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
local LastTargetPosition = nil
local SmoothAimProgress = 0
local SafetyWarning = nil
local Crosshair = nil
local ESPCache = {}

-- Enhanced Configuration Settings
local Config = {
    Enabled = true,
    FOV = 120,
    Smoothness = 0.45,
    MaxLockSpeed = 0.8,
    ActivationDelay = 0.15,
    TeamCheck = true,
    VisibilityCheck = true,
    TargetPart = "Head",
    AimingMode = "Mouse",
    
    -- New: Aim Method
    AimMethod = "Rage", -- "Rage" or "Legit"
    
    -- Prediction Settings
    Prediction = true,
    PredictionAmount = 0.12,
    PredictionScale = 1.0,
    
    -- Stabilization Settings
    StabilizationEnabled = true,
    MaxAngleChange = 2.5,
    HumanizationFactor = 0.3,
    LockThreshold = 5,
    LockStrength = 0.8,
    
    -- FOV Circle Visual Properties
    FOVCircleVisible = true,
    FOVCircleColor = Color3.fromRGB(255, 50, 50),
    FOVCircleTransparency = 0.7,
    FOVCircleSides = 64,
    
    -- New: ESP Settings
    ESPEnabled = true,
    ESPColor = Color3.fromRGB(255, 50, 50),
    ESPRefreshRate = 0.1,
    ESPBoxes = true,
    ESPNames = true,
    ESPTracers = true,
    TracerOrigin = "Mouse", -- "Mouse", "Center", "Bottom", "Top"
    ESPHealth = true,
    ESPDistance = true,
    
    -- New: Safety Aim
    SafetyAimEnabled = true,
    
    -- New: Crosshair Settings
    CrosshairEnabled = true,
    CrosshairType = "Circle", -- "Circle", "Triangle", "Octagon", "Cross", "Dot"
    CrosshairColor = Color3.fromRGB(255, 255, 255),
    CrosshairSize = 12,
    CrosshairThickness = 1,
    
    -- GUI Settings
    GUIVisible = true,
    UIOpacity = 1,
}

-- Fixed safety warning initialization
function createSafetyWarning()
    if SafetyWarning then 
        SafetyWarning:Remove()
        SafetyWarning = nil
    end
    
    SafetyWarning = Drawing.new("Text")
    if not SafetyWarning then
        warn("Failed to create safety warning drawing")
        return
    end
    
    SafetyWarning.Visible = false
    SafetyWarning.Text = "!"
    SafetyWarning.Color = Color3.fromRGB(255, 50, 50)
    SafetyWarning.Size = 25
    SafetyWarning.Center = true
    SafetyWarning.Outline = true
    SafetyWarning.OutlineColor = Color3.fromRGB(0, 0, 0)
    SafetyWarning.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 4)
    SafetyWarning.Transparency = 0
end

-- Fixed crosshair initialization
function createCrosshair()
    if Crosshair then
        Crosshair:Remove()
        Crosshair = nil
    end

    -- Create crosshair based on type
    if Config.CrosshairType == "Circle" then
        Crosshair = Drawing.new("Circle")
        Crosshair.Radius = Config.CrosshairSize
        Crosshair.Thickness = Config.CrosshairThickness
    elseif Config.CrosshairType == "Triangle" then
        -- Using circle for triangle placeholder
        Crosshair = Drawing.new("Circle")
        Crosshair.Radius = Config.CrosshairSize
        Crosshair.Thickness = Config.CrosshairThickness
    elseif Config.CrosshairType == "Octagon" then
        Crosshair = Drawing.new("Circle")
        Crosshair.Radius = Config.CrosshairSize
        Crosshair.Thickness = Config.CrosshairThickness
        Crosshair.NumSides = 8
    elseif Config.CrosshairType == "Cross" then
        -- Using circle for cross placeholder
        Crosshair = Drawing.new("Circle")
        Crosshair.Radius = Config.CrosshairSize
        Crosshair.Thickness = Config.CrosshairThickness
    elseif Config.CrosshairType == "Dot" then
        Crosshair = Drawing.new("Circle")
        Crosshair.Radius = 2
        Crosshair.Filled = true
    end

    -- Check if crosshair was created successfully
    if not Crosshair then
        warn("Failed to create crosshair drawing")
        return
    end

    Crosshair.Visible = Config.CrosshairEnabled
    Crosshair.Color = Config.CrosshairColor
    Crosshair.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    Crosshair.Transparency = 0
    Crosshair.ZIndex = 10
end

-- Configure FOV circle visualization 
function configureFOVCircle()
    if not FOVCircle then
        FOVCircle = Drawing.new("Circle")
    end
    
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
    if FOVCircle then
        FOVCircle.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
    end
end

-- Enhanced prediction function based on target velocity 
function predictPosition(target, targetPart)
    if not target or not target.Character or not targetPart then
        return nil
    end
    
    if not Config.Prediction then
        return targetPart.Position
    end
    
    -- Get target velocity
    local velocity = Vector3.new(0, 0, 0)
    if target.Character:FindFirstChild("HumanoidRootPart") then
        velocity = target.Character.HumanoidRootPart.Velocity
    end
    
    -- Calculate predicted position
    local predictedPosition = targetPart.Position + (velocity * Config.PredictionAmount) * Config.PredictionScale
    
    return predictedPosition
end

-- Get target part based on selection
function getTargetPart(character)
    if Config.TargetPart == "Dynamic" then
        -- Find part closest to mouse/camera
        local mousePos = UserInputService:GetMouseLocation()
        local closestPart = nil
        local closestDistance = math.huge
        
        local parts = {
            character:FindFirstChild("Head"),
            character:FindFirstChild("UpperTorso"),
            character:FindFirstChild("LowerTorso"),
            character:FindFirstChild("HumanoidRootPart"),
            character:FindFirstChild("LeftLeg"),
            character:FindFirstChild("RightLeg")
        }
        
        for _, part in ipairs(parts) do
            if part then
                local screenPos, visible = Camera:WorldToViewportPoint(part.Position)
                if visible then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPart = part
                    end
                end
            end
        end
        
        return closestPart or character:FindFirstChild("HumanoidRootPart")
    else
        return character:FindFirstChild(Config.TargetPart) or character:FindFirstChild("HumanoidRootPart")
    end
end

-- Enhanced target finding with proper stabilization
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
        
        -- Get target body part based on selection
        local targetPart = getTargetPart(player.Character)
        if not targetPart then continue end
        
        -- Calculate screen position
        local targetPosition, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        -- Check visibility if enabled
        if Config.VisibilityCheck then
            local origin = Camera.CFrame.Position
            local direction = (targetPart.Position - origin).Unit * (origin - targetPart.Position).Magnitude
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
        end
    end
    
    -- Stabilization: Prevent rapid target switching
    if CurrentTarget and bestTarget and CurrentTarget ~= bestTarget then
        if os.clock() - lastTargetTime < Config.ActivationDelay then
            -- Keep the current target for a bit longer to prevent rapid switching
            bestTarget = CurrentTarget
            if bestTarget.Character then
                local targetPart = getTargetPart(bestTarget.Character)
                if targetPart then
                    bestTargetPosition = Camera:WorldToViewportPoint(targetPart.Position)
                end
            end
        else
            lastTargetTime = os.clock()
        end
    end
    
    return bestTarget, bestTargetPosition
end

-- Proper stabilization aiming function with Legit mode
function stabilizedAim(targetPosition, target)
    if not targetPosition or not target then 
        SmoothAimProgress = 0
        LastTargetPosition = nil
        return 
    end
    
    local mousePosition = UserInputService:GetMouseLocation()
    local targetVector = Vector2.new(targetPosition.X, targetPosition.Y)
    local direction = (targetVector - mousePosition)
    local currentMagnitude = direction.Magnitude
    
    -- Reset progress if target changed
    if LastTargetPosition ~= targetPosition then
        SmoothAimProgress = 0
        LastTargetPosition = targetPosition
    end
    
    -- Apply prediction if enabled
    if Config.Prediction and target.Character then
        local targetPart = getTargetPart(target.Character)
        if targetPart then
            local predictedPosition = predictPosition(target, targetPart)
            if predictedPosition then
                local predictedScreenPosition = Camera:WorldToViewportPoint(predictedPosition)
                if predictedScreenPosition then
                    targetVector = Vector2.new(predictedScreenPosition.X, predictedScreenPosition.Y)
                    direction = (targetVector - mousePosition)
                    currentMagnitude = direction.Magnitude
                end
            end
        end
    end
    
    -- Only aim if we're close enough to the target
    if currentMagnitude > Config.LockThreshold then
        -- Apply stabilization to prevent haywire movement
        if Config.StabilizationEnabled then
            -- Adjust based on aim method
            local smoothnessFactor = Config.Smoothness
            local maxChangeFactor = Config.MaxAngleChange
            local humanizationFactor = Config.HumanizationFactor
            
            if Config.AimMethod == "Legit" then
                -- Legit mode is smoother and more human-like
                smoothnessFactor = math.min(0.8, smoothnessFactor + 0.2)
                maxChangeFactor = math.min(1.5, maxChangeFactor * 0.7)
                humanizationFactor = math.min(0.5, humanizationFactor + 0.2)
            end
            
            -- Gradually increase smooth aim progress
            SmoothAimProgress = math.min(1, SmoothAimProgress + (1 - smoothnessFactor) * 0.1)
            
            -- Calculate the desired direction with smoothing
            local smoothDirection = direction * (1 - SmoothAimProgress)
            
            -- Apply maximum angle change limit
            if maxChangeFactor > 0 then
                local maxChange = maxChangeFactor * (1 - SmoothAimProgress)
                if smoothDirection.Magnitude > maxChange then
                    smoothDirection = smoothDirection.Unit * maxChange
                end
            end
            
            -- Apply lock strength
            smoothDirection = smoothDirection * Config.LockStrength
            
            -- Add human-like imperfection
            if humanizationFactor > 0 then
                local imperfection = Vector2.new(
                    (math.random() * 2 - 1) * humanizationFactor * (1 - SmoothAimProgress),
                    (math.random() * 2 - 1) * humanizationFactor * (1 - SmoothAimProgress)
                )
                smoothDirection = smoothDirection + imperfection
            end
            
            direction = smoothDirection
        end
        
        -- Apply based on aiming mode
        if Config.AimingMode == "Mouse" then
            mousemoverel(direction.X, direction.Y)
        else
            -- Camera mode: Adjust the camera directly
            local camCFrame = Camera.CFrame
            local deltaX = direction.X / 1000
            local deltaY = direction.Y / 1000
            
            -- Apply rotation to camera
            local newCFrame = camCFrame * CFrame.fromEulerAnglesXYZ(-deltaY, -deltaX, 0)
            Camera.CFrame = newCFrame
        end
    else
        -- We're close enough to the target, maintain position
        SmoothAimProgress = 1
    end
end

-- Always-on targeting logic with stabilization
function rageAimbot()
    if not Config.Enabled or not LocalPlayer.Character then return end
    
    local target, position = findTarget()
    if target then
        CurrentTarget = target
        stabilizedAim(position, target)
    else
        CurrentTarget = nil
        SmoothAimProgress = 0
        LastTargetPosition = nil
    end
end

-- Fixed ESP system
function updateESP()
    if not Config.ESPEnabled then 
        -- Clean up ESP if disabled
        for player, drawings in pairs(ESPCache) do
            for _, drawing in ipairs(drawings) do
                drawing:Remove()
            end
        end
        ESPCache = {}
        return 
    end

    -- Update ESP for all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        -- Remove old ESP if player is gone
        if not player or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            if ESPCache[player] then
                for _, drawing in ipairs(ESPCache[player]) do
                    drawing:Remove()
                end
                ESPCache[player] = nil
            end
            continue
        end

        local character = player.Character
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local head = character:FindFirstChild("Head")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not head or not rootPart then continue end

        -- Calculate screen positions
        local headPos, headVisible = Camera:WorldToViewportPoint(head.Position)
        local rootPos, rootVisible = Camera:WorldToViewportPoint(rootPart.Position)
        
        if not headVisible or not rootVisible then
            -- Player is not on screen, remove ESP
            if ESPCache[player] then
                for _, drawing in ipairs(ESPCache[player]) do
                    drawing:Remove()
                end
                ESPCache[player] = nil
            end
            continue
        end

        -- Create or update ESP
        if not ESPCache[player] then
            ESPCache[player] = {}
        else
            -- Clear existing drawings
            for _, drawing in ipairs(ESPCache[player]) do
                drawing:Remove()
            end
            ESPCache[player] = {}
        end

        -- Calculate box dimensions
        local height = (headPos.Y - rootPos.Y) * 2
        local width = height / 2.5

        -- Box ESP
        if Config.ESPBoxes then
            local box = Drawing.new("Square")
            box.Visible = true
            box.Color = Config.ESPColor
            box.Thickness = 2
            box.Size = Vector2.new(width, height)
            box.Position = Vector2.new(rootPos.X - width/2, rootPos.Y - height/2)
            box.Filled = false
            box.ZIndex = 5
            table.insert(ESPCache[player], box)
        end

        -- Name ESP
        if Config.ESPNames then
            local name = Drawing.new("Text")
            name.Visible = true
            name.Color = Config.ESPColor
            name.Size = 16
            name.Center = true
            name.Outline = true
            name.OutlineColor = Color3.fromRGB(0, 0, 0)
            name.Text = player.Name
            name.Position = Vector2.new(rootPos.X, rootPos.Y - height/2 - 20)
            name.ZIndex = 5
            table.insert(ESPCache[player], name)
        end

        -- Health ESP
        if Config.ESPHealth then
            local health = Drawing.new("Text")
            health.Visible = true
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local healthColor = Color3.new(1 - healthPercent, healthPercent, 0)
            health.Color = healthColor
            health.Size = 14
            health.Center = true
            health.Outline = true
            health.OutlineColor = Color3.fromRGB(0, 0, 0)
            health.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
            health.Position = Vector2.new(rootPos.X, rootPos.Y - height/2 - 40)
            health.ZIndex = 5
            table.insert(ESPCache[player], health)
        end

        -- Distance ESP
        if Config.ESPDistance then
            local distance = (rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            local distText = Drawing.new("Text")
            distText.Visible = true
            distText.Color = Config.ESPColor
            distText.Size = 14
            distText.Center = true
            distText.Outline = true
            distText.OutlineColor = Color3.fromRGB(0, 0, 0)
            distText.Text = math.floor(distance) .. " studs"
            distText.Position = Vector2.new(rootPos.X, rootPos.Y + height/2 + 10)
            distText.ZIndex = 5
            table.insert(ESPCache[player], distText)
        end

        -- Tracer ESP
        if Config.ESPTracers then
            local tracer = Drawing.new("Line")
            tracer.Visible = true
            tracer.Color = Config.ESPColor
            tracer.Thickness = 1
            tracer.ZIndex = 5
            
            -- Set origin based on config
            local origin
            if Config.TracerOrigin == "Mouse" then
                origin = UserInputService:GetMouseLocation()
            elseif Config.TracerOrigin == "Center" then
                origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            elseif Config.TracerOrigin == "Bottom" then
                origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            elseif Config.TracerOrigin == "Top" then
                origin = Vector2.new(Camera.ViewportSize.X / 2, 0)
            end
            
            tracer.From = origin
            tracer.To = Vector2.new(rootPos.X, rootPos.Y)
            table.insert(ESPCache[player], tracer)
        end
    end
end

-- Safety aim detection
function checkSafetyAim()
    if not Config.SafetyAimEnabled or not LocalPlayer.Character or not SafetyWarning then 
        if SafetyWarning then
            SafetyWarning.Visible = false
        end
        return 
    end
    
    local localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    
    local someoneAiming = false
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            local humanoid = player.Character.Humanoid
            if humanoid.Health <= 0 then continue end
            
            local head = player.Character:FindFirstChild("Head")
            if not head then continue end
            
            -- Check if player is looking at us
            local direction = (localRoot.Position - head.Position).Unit
            local lookVector = head.CFrame.LookVector
            
            -- Calculate angle between look direction and direction to us
            local dotProduct = lookVector:Dot(direction)
            local angle = math.acos(math.clamp(dotProduct, -1, 1)) * (180 / math.pi)
            
            -- If angle is small, they're looking at us
            if angle < 30 then
                someoneAiming = true
                break
            end
        end
    end
    
    -- Update safety warning
    if SafetyWarning then
        SafetyWarning.Visible = someoneAiming
        
        if someoneAiming then
            -- Pulse effect
            local pulse = math.sin(os.clock() * 5) * 0.5 + 0.5
            SafetyWarning.Transparency = 1 - pulse
        else
            SafetyWarning.Transparency = 0
        end
    end
end

-- GUI Creation Function
function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RagebotGUI"
    ScreenGui.Parent = game.CoreGui
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 400, 0, 600)
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

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 40)
    Title.Position = UDim2.new(0, 10, 0, 10)
    Title.Text = "Enhanced Ragebot Aimbot"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame

    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -40, 0, 10)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 14
    CloseButton.Parent = MainFrame
    
    local closeUICorner = Instance.new("UICorner")
    closeUICorner.CornerRadius = UDim.new(0, 4)
    closeUICorner.Parent = CloseButton
    
    -- Close button functionality
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        Config.GUIVisible = false
    end)

    -- Toggle Buttons
    local buttonYPosition = 60
    local function createToggleButton(name, configField, yOffset)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 180, 0, 30)
        button.Position = UDim2.new(0, 10, 0, yOffset)
        button.Text = name .. ": " .. (Config[configField] and "ON" or "OFF")
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.BackgroundColor3 = Config[configField] and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
        button.Font = Enum.Font.Gotham
        button.TextSize = 14
        button.Parent = MainFrame
        
        local buttonUICorner = Instance.new("UICorner")
        buttonUICorner.CornerRadius = UDim.new(0, 4)
        buttonUICorner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            Config[configField] = not Config[configField]
            button.Text = name .. ": " .. (Config[configField] and "ON" or "OFF")
            button.BackgroundColor3 = Config[configField] and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
            
            if configField == "FOVCircleVisible" then
                FOVCircle.Visible = Config.FOVCircleVisible
            elseif configField == "CrosshairEnabled" then
                if Crosshair then
                    Crosshair.Visible = Config.CrosshairEnabled
                else
                    createCrosshair()
                end
            elseif configField == "SafetyAimEnabled" then
                if SafetyWarning then
                    SafetyWarning.Visible = Config.SafetyAimEnabled
                else
                    createSafetyWarning()
                end
            end
        end)
        
        return button
    end

    createToggleButton("Aimbot", "Enabled", 60)
    createToggleButton("Team Check", "TeamCheck", 100)
    createToggleButton("Visibility Check", "VisibilityCheck", 140)
    createToggleButton("Stabilization", "StabilizationEnabled", 180)
    createToggleButton("ESP", "ESPEnabled", 220)
    createToggleButton("ESP Boxes", "ESPBoxes", 260)
    createToggleButton("ESP Names", "ESPNames", 300)
    createToggleButton("ESP Tracers", "ESPTracers", 340)
    createToggleButton("ESP Health", "ESPHealth", 380)
    createToggleButton("ESP Distance", "ESPDistance", 420)
    createToggleButton("Prediction", "Prediction", 460)
    createToggleButton("Safety Aim", "SafetyAimEnabled", 500)
    createToggleButton("Crosshair", "CrosshairEnabled", 540)

    -- Mode Selection
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(0, 120, 0, 20)
    modeLabel.Position = UDim2.new(0, 200, 0, 60)
    modeLabel.Text = "Aim Method:"
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.TextSize = 14
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.Parent = MainFrame

    local aimMethodDropdown = Instance.new("TextButton")
    aimMethodDropdown.Size = UDim2.new(0, 120, 0, 30)
    aimMethodDropdown.Position = UDim2.new(0, 200, 0, 80)
    aimMethodDropdown.Text = Config.AimMethod
    aimMethodDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimMethodDropdown.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    aimMethodDropdown.Font = Enum.Font.Gotham
    aimMethodDropdown.TextSize = 14
    aimMethodDropdown.Parent = MainFrame
    
    local aimMethodUICorner = Instance.new("UICorner")
    aimMethodUICorner.CornerRadius = UDim.new(0, 4)
    aimMethodUICorner.Parent = aimMethodDropdown
    
    aimMethodDropdown.MouseButton1Click:Connect(function()
        if Config.AimMethod == "Rage" then
            Config.AimMethod = "Legit"
        else
            Config.AimMethod = "Rage"
        end
        aimMethodDropdown.Text = Config.AimMethod
    end)

    -- Target Part Selection
    local partLabel = Instance.new("TextLabel")
    partLabel.Size = UDim2.new(0, 120, 0, 20)
    partLabel.Position = UDim2.new(0, 200, 0, 120)
    partLabel.Text = "Target Part:"
    partLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    partLabel.BackgroundTransparency = 1
    partLabel.Font = Enum.Font.Gotham
    partLabel.TextSize = 14
    partLabel.TextXAlignment = Enum.TextXAlignment.Left
    partLabel.Parent = MainFrame

    local partDropdown = Instance.new("TextButton")
    partDropdown.Size = UDim2.new(0, 120, 0, 30)
    partDropdown.Position = UDim2.new(0, 200, 0, 140)
    partDropdown.Text = Config.TargetPart
    partDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    partDropdown.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    partDropdown.Font = Enum.Font.Gotham
    partDropdown.TextSize = 14
    partDropdown.Parent = MainFrame
    
    local partUICorner = Instance.new("UICorner")
    partUICorner.CornerRadius = UDim.new(0, 4)
    partUICorner.Parent = partDropdown
    
    partDropdown.MouseButton1Click:Connect(function()
        local parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftLeg", "RightLeg", "Dynamic"}
        local currentIndex = 1
        for i, part in ipairs(parts) do
            if part == Config.TargetPart then
                currentIndex = i
                break
            end
        end
        
        local nextIndex = (currentIndex % #parts) + 1
        Config.TargetPart = parts[nextIndex]
        partDropdown.Text = Config.TargetPart
    end)

    -- Tracer Origin Selection
    local tracerLabel = Instance.new("TextLabel")
    tracerLabel.Size = UDim2.new(0, 120, 0, 20)
    tracerLabel.Position = UDim2.new(0, 200, 0, 180)
    tracerLabel.Text = "Tracer Origin:"
    tracerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    tracerLabel.BackgroundTransparency = 1
    tracerLabel.Font = Enum.Font.Gotham
    tracerLabel.TextSize = 14
    tracerLabel.TextXAlignment = Enum.TextXAlignment.Left
    tracerLabel.Parent = MainFrame

    local tracerDropdown = Instance.new("TextButton")
    tracerDropdown.Size = UDim2.new(0, 120, 0, 30)
    tracerDropdown.Position = UDim2.new(0, 200, 0, 200)
    tracerDropdown.Text = Config.TracerOrigin
    tracerDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    tracerDropdown.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    tracerDropdown.Font = Enum.Font.Gotham
    tracerDropdown.TextSize = 14
    tracerDropdown.Parent = MainFrame
    
    local tracerUICorner = Instance.new("UICorner")
    tracerUICorner.CornerRadius = UDim.new(0, 4)
    tracerUICorner.Parent = tracerDropdown
    
    tracerDropdown.MouseButton1Click:Connect(function()
        local origins = {"Mouse", "Center", "Bottom", "Top"}
        local currentIndex = 1
        for i, origin in ipairs(origins) do
            if origin == Config.TracerOrigin then
                currentIndex = i
                break
            end
        end
        
        local nextIndex = (currentIndex % #origins) + 1
        Config.TracerOrigin = origins[nextIndex]
        tracerDropdown.Text = Config.TracerOrigin
    end)

    -- Crosshair Type Selection
    local crosshairLabel = Instance.new("TextLabel")
    crosshairLabel.Size = UDim2.new(0, 120, 0, 20)
    crosshairLabel.Position = UDim2.new(0, 200, 0, 240)
    crosshairLabel.Text = "Crosshair Type:"
    crosshairLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    crosshairLabel.BackgroundTransparency = 1
    crosshairLabel.Font = Enum.Font.Gotham
    crosshairLabel.TextSize = 14
    crosshairLabel.TextXAlignment = Enum.TextXAlignment.Left
    crosshairLabel.Parent = MainFrame

    local crosshairDropdown = Instance.new("TextButton")
    crosshairDropdown.Size = UDim2.new(0, 120, 0, 30)
    crosshairDropdown.Position = UDim2.new(0, 200, 0, 260)
    crosshairDropdown.Text = Config.CrosshairType
    crosshairDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    crosshairDropdown.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    crosshairDropdown.Font = Enum.Font.Gotham
    crosshairDropdown.TextSize = 14
    crosshairDropdown.Parent = MainFrame
    
    local crosshairUICorner = Instance.new("UICorner")
    crosshairUICorner.CornerRadius = UDim.new(0, 4)
    crosshairUICorner.Parent = crosshairDropdown
    
    crosshairDropdown.MouseButton1Click:Connect(function()
        local types = {"Circle", "Triangle", "Octagon", "Cross", "Dot"}
        local currentIndex = 1
        for i, type in ipairs(types) do
            if type == Config.CrosshairType then
                currentIndex = i
                break
            end
        end
        
        local nextIndex = (currentIndex % #types) + 1
        Config.CrosshairType = types[nextIndex]
        crosshairDropdown.Text = Config.CrosshairType
        
        -- Update crosshair
        createCrosshair()
    end)

    -- Slider Controls
    local function createSlider(name, configField, minValue, maxValue, yOffset, precision)
        precision = precision or 2
        local sliderLabel = Instance.new("TextLabel")
        sliderLabel.Size = UDim2.new(0, 120, 0, 20)
        sliderLabel.Position = UDim2.new(0, 200, 0, yOffset)
        sliderLabel.Text = name .. ": " .. Config[configField]
        sliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        sliderLabel.BackgroundTransparency = 1
        sliderLabel.Font = Enum.Font.Gotham
        sliderLabel.TextSize = 12
        sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
        sliderLabel.Parent = MainFrame

        local slider = Instance.new("Frame")
        slider.Size = UDim2.new(0, 120, 0, 5)
        slider.Position = UDim2.new(0, 200, 0, yOffset + 20)
        slider.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
        slider.BorderSizePixel = 0
        slider.Parent = MainFrame
        
        local sliderUICorner = Instance.new("UICorner")
        sliderUICorner.CornerRadius = UDim.new(1, 0)
        sliderUICorner.Parent = slider

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((Config[configField] - minValue) / (maxValue - minValue), 0, 1, 0)
        fill.Position = UDim2.new(0, 0, 0, 0)
        fill.BackgroundColor3 = Color3.fromRGB(80, 160, 80)
        fill.BorderSizePixel = 0
        fill.Parent = slider
        
        local fillUICorner = Instance.new("UICorner")
        fillUICorner.CornerRadius = UDim.new(1, 0)
        fillUICorner.Parent = fill

        local sliderButton = Instance.new("TextButton")
        sliderButton.Size = UDim2.new(0, 120, 0, 20)
        sliderButton.Position = UDim2.new(0, 200, 0, yOffset + 15)
        sliderButton.Text = ""
        sliderButton.BackgroundTransparency = 1
        sliderButton.Parent = MainFrame
        
        sliderButton.MouseButton1Down:Connect(function()
            local connection
            connection = RunService.RenderStepped:Connect(function()
                local mousePos = UserInputService:GetMouseLocation()
                local relativeX = math.clamp(mousePos.X - slider.AbsolutePosition.X, 0, slider.AbsoluteSize.X)
                local value = minValue + (relativeX / slider.AbsoluteSize.X) * (maxValue - minValue)
                Config[configField] = math.floor(value * (10 ^ precision)) / (10 ^ precision)
                fill.Size = UDim2.new((value - minValue) / (maxValue - minValue), 0, 1, 0)
                sliderLabel.Text = name .. ": " .. Config[configField]
                
                if configField == "FOV" then
                    FOVCircle.Radius = Config.FOV
                elseif configField == "CrosshairSize" then
                    createCrosshair()
                elseif configField == "CrosshairThickness" then
                    createCrosshair()
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

    -- Sliders with lower FOV range
    createSlider("FOV", "FOV", 10, 250, 300, 0)
    createSlider("Smoothness", "Smoothness", 0.1, 1, 340, 2)
    createSlider("Max Speed", "MaxLockSpeed", 0.1, 2, 380, 2)
    createSlider("Humanization", "HumanizationFactor", 0, 0.5, 420, 2)
    createSlider("Prediction", "PredictionAmount", 0, 0.5, 460, 3)
    createSlider("Pred Scale", "PredictionScale", 0.1, 2, 500, 2)
    createSlider("Lock Strength", "LockStrength", 0.1, 1, 540, 2)
    createSlider("Lock Threshold", "LockThreshold", 1, 20, 580, 1)
    createSlider("Crosshair Size", "CrosshairSize", 5, 30, 620, 0)
    createSlider("Crosshair Thick", "CrosshairThickness", 1, 5, 660, 0)

    return ScreenGui
end

-- Set up connections
function initializeConnections()
    -- Clean up any existing connections
    for _, connection in ipairs(Connections) do
        connection:Disconnect()
    end
    Connections = {}

    -- Main aimbot loop
    table.insert(Connections, RunService.RenderStepped:Connect(function()
        updateFOVCircle()
        rageAimbot()
        if Crosshair then
            Crosshair.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        end
    end))
    
    -- ESP update loop (less frequent for performance)
    table.insert(Connections, RunService.Heartbeat:Connect(function()
        updateESP()
        checkSafetyAim()
    end))
    
    -- GUI toggle hotkey
    table.insert(Connections, UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Insert then
            local gui = game.CoreGui:FindFirstChild("RagebotGUI")
            if gui then
                gui.Enabled = not gui.Enabled
                Config.GUIVisible = gui.Enabled
            else
                createGUI()
            end
        end
        
        -- Toggle aimbot with a hotkey
        if input.KeyCode == Enum.KeyCode.F then
            Config.Enabled = not Config.Enabled
        end
        
        -- Reset stabilization with a hotkey
        if input.KeyCode == Enum.KeyCode.R then
            SmoothAimProgress = 0
            LastTargetPosition = nil
            print("Stabilization reset")
        end
    end))
end

-- Safe initialization
local function safeInitialize()
    local success, err = pcall(function()
        configureFOVCircle()
        createSafetyWarning()
        createCrosshair()
        initializeConnections()
    end)
    
    if not success then
        warn("Initialization error: " .. tostring(err))
        -- Attempt to recover
        task.wait(1)
        safeInitialize()
    end
end

-- Cleanup function
function cleanup()
    for _, connection in ipairs(Connections) do
        connection:Disconnect()
    end
    
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    for _, obj in pairs(ESPObjects) do
        if obj then
            obj:Remove()
        end
    end
    
    for player, espData in pairs(ESPCache) do
        for _, drawing in ipairs(espData) do
            drawing:Remove()
        end
    end
    
    if SafetyWarning then
        SafetyWarning:Remove()
    end
    
    if Crosshair then
        Crosshair:Remove()
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

-- Start the script
safeInitialize()

print("Enhanced Ragebot Aimbot loaded successfully!")
print("Press INSERT to toggle GUI")
print("Press F to toggle Aimbot")
print("Press R to reset stabilization")
print("Features: Legit/Rage aim, Improved ESP, Custom crosshairs, Safety indicator")

--- v3

-- Pulsing Ragebot Aimbot v2.1
-- Enhanced with visual effects and optimized performance

if not game:IsLoaded() then
    game.Loaded:Wait()
end

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
local PulseTween = nil
local PulseDirection = 1
local PulseValue = 0

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
    ESPRefreshRate = 0.1,
    
    -- GUI Settings
    GUIVisible = true,
    
    -- Pulsing Effect Settings
    PulseEnabled = true,
    PulseSpeed = 1,
}

-- GUI Creation Function with Pulsing Title
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

    -- Title with Pulsing Effect
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 40)
    Title.Position = UDim2.new(0, 10, 0, 10)
    Title.Text = "Ragebot Aimbot v2.1"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame

    -- Start the pulsing animation
    startPulsingTitle(Title)

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
            elseif configField == "PulseEnabled" then
                if Config.PulseEnabled then
                    startPulsingTitle(Title)
                else
                    if PulseTween then
                        PulseTween:Pause()
                    end
                    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                end
            end
        end)
        
        return button
    end

    createToggleButton("Aimbot", "Enabled", 60)
    createToggleButton("Team Check", "TeamCheck", 100)
    createToggleButton("Visibility Check", "VisibilityCheck", 140)
    createToggleButton("Stabilization", "StabilizationEnabled", 180)
    createToggleButton("ESP", "ESPEnabled", 220)
    createToggleButton("Pulse Effect", "PulseEnabled", 260)

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
    createSlider("Pulse Speed", "PulseSpeed", 0.5, 3, 220)
end

-- Pulsing title animation
function startPulsingTitle(titleLabel)
    if not Config.PulseEnabled then return end
    
    if PulseTween then
        PulseTween:Cancel()
    end
    
    local pulseTime = 1 / Config.PulseSpeed
    local goal1 = {TextColor3 = Color3.fromRGB(255, 100, 100)}
    local goal2 = {TextColor3 = Color3.fromRGB(255, 255, 255)}
    
    PulseTween = TweenService:Create(
        titleLabel,
        TweenInfo.new(pulseTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        goal1
    )
    
    PulseTween:Play()
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

-- Enhanced target finding with stabilization
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
        
        -- Calculate screen position
        local targetPosition, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        -- Check visibility if enabled
        if Config.VisibilityCheck then
            local origin = Camera.CFrame.Position
            local direction = (targetPart.Position - origin).Unit * (origin - targetPart.Position).Magnitude
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

-- Stabilized aiming function with dual modes
function stabilizedAim(targetPosition)
    if not targetPosition then return end
    
    local mousePosition = UserInputService:GetMouseLocation()
    local targetVector = Vector2.new(targetPosition.X, targetPosition.Y)
    local direction = (targetVector - mousePosition)
    
    -- Apply stabilization to prevent haywire movement
    if Config.StabilizationEnabled then
        -- Limit the maximum angle change per frame
        local maxChange = Config.MaxAngleChange
        local currentAngle = math.atan2(direction.Y, direction.X)
        local currentMagnitude = direction.Magnitude
        local limitedAngle = currentAngle
        
        if CurrentTarget then
            -- Gradually approach the target rather than snapping
            limitedAngle = limitedAngle * math.min(1, Config.MaxLockSpeed / currentMagnitude)
        end
        
        direction = Vector2.new(
            math.cos(limitedAngle) * currentMagnitude,
            math.sin(limitedAngle) * currentMagnitude
        )
        
        -- Add human-like imperfection
        if Config.HumanizationFactor > 0 then
            local imperfection = Vector2.new(
                (math.random() * 2 - 1) * Config.HumanizationFactor,
                (math.random() * 2 - 1) * Config.HumanizationFactor
            )
            direction = direction + imperfection
        end
    end
    
    -- Apply smoothing
    local smoothAdjustment = direction * Config.Smoothness
    
    -- Apply based on aiming mode
    if Config.AimingMode == "Mouse" then
        mousemoverel(smoothAdjustment.X, smoothAdjustment.Y)
    else
        -- Camera mode: Adjust the camera directly
        local camCFrame = Camera.CFrame
        local lookVector = camCFrame.LookVector
        local rightVector = camCFrame.RightVector
        local upVector = camCFrame.UpVector
        
        -- Calculate adjustment angles
        local deltaX = smoothAdjustment.X / 1000
        local deltaY = smoothAdjustment.Y / 1000
        
        -- Apply rotation to camera
        local newCFrame = camCFrame * CFrame.fromEulerAnglesXYZ(-deltaY, -deltaX, 0)
        Camera.CFrame = newCFrame
    end
end

-- Always-on targeting logic with stabilization
function rageAimbot()
    if not Config.Enabled or not LocalPlayer.Character then return end
    
    local target, position = findTarget()
    if target then
        CurrentTarget = target
        stabilizedAim(position)
        
        if Config.AutoFire and LocalPlayer.Character:FindFirstChildWhichIsA("Tool") then
            LocalPlayer.Character:FindFirstChildWhichIsA("Tool"):Activate()
        end
    else
        CurrentTarget = nil
    end
end

-- Enhanced ESP function 
function updateESP()
    if not Config.ESPEnabled then return end
    
    -- Clean up old ESP objects
    for _, obj in pairs(ESPObjects) do
        if obj then
            obj:Remove()
        end
    end
    ESPObjects = {}
    
    -- Create ESP for all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local highlight = Instance.new("Highlight")
            highlight.Parent = player.Character
            highlight.FillColor = Config.ESPColor
            highlight.OutlineColor = Config.ESPColor
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            
            table.insert(ESPObjects, highlight)
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
end

-- Initialize the script
configureFOVCircle()
initializeConnections()

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

--- v4

-- Ragebot Aimbot v2.3
-- Enhanced with prediction and auto-adjust intelligence

if not game:IsLoaded() then
    game.Loaded:Wait()
end

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
    
    -- Auto-Adjust Settings
    AutoAdjustEnabled = false,
    LastAutoAdjustTime = 0,
}

-- GUI Creation Function with Auto-Adjust Button
function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RagebotGUI"
    ScreenGui.Parent = game.CoreGui
    ScreenGui.ResetOnSpawn = false

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 300, 0, 430) -- Increased height for new buttons
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
    Title.Text = "Ragebot Aimbot v2.3"
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
            elseif configField == "AutoAdjustEnabled" then
                -- Reset auto-adjust timer when toggled
                Config.LastAutoAdjustTime = os.clock()
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
    createToggleButton("Auto Adjust", "AutoAdjustEnabled", 300)

    -- Mode Selection
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(0, 120, 0, 20)
    modeLabel.Position = UDim2.new(0, 10, 0, 340)
    modeLabel.Text = "Aiming Mode:"
    modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Font = Enum.Font.Gotham
    modeLabel.TextSize = 14
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.Parent = MainFrame

    local modeDropdown = Instance.new("TextButton")
    modeDropdown.Size = UDim2.new(0, 120, 0, 30)
    modeDropdown.Position = UDim2.new(0, 10, 0, 360)
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

-- Analyze environment and auto-adjust settings
function autoAdjustSettings()
    if not Config.AutoAdjustEnabled then return end
    
    -- Check if it's time to adjust (every 0.01 seconds)
    local now = os.clock()
    if now - Config.LastAutoAdjustTime < 0.01 then return end
    Config.LastAutoAdjustTime = now
    
    -- Analyze the environment
    local enemyCount = 0
    local totalDistance = 0
    local closestEnemyDistance = math.huge
    local fastestEnemySpeed = 0
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and 
           player.Character.Humanoid.Health > 0 and player.Character:FindFirstChild("HumanoidRootPart") then
            
            if Config.TeamCheck and player.Team == LocalPlayer.Team then continue end
            
            enemyCount = enemyCount + 1
            local distance = (player.Character.HumanoidRootPart.Position - Camera.CFrame.Position).Magnitude
            totalDistance = totalDistance + distance
            
            if distance < closestEnemyDistance then
                closestEnemyDistance = distance
            end
            
            -- Calculate enemy speed
            if TargetHistory[player] and #TargetHistory[player] > 1 then
                local history = TargetHistory[player]
                local latest = history[#history]
                local previous = history[1]
                
                local timeDiff = latest.time - previous.time
                if timeDiff > 0 then
                    local distanceMoved = (latest.position - previous.position).Magnitude
                    local speed = distanceMoved / timeDiff
                    
                    if speed > fastestEnemySpeed then
                        fastestEnemySpeed = speed
                    end
                end
            end
        end
    end
    
    -- Adjust settings based on analysis
    if enemyCount > 0 then
        local averageDistance = totalDistance / enemyCount
        
        -- Adjust FOV based on number of enemies and their distance
        Config.FOV = math.clamp(60 + (enemyCount * 15) + (averageDistance / 10), 50, 250)
        FOVCircle.Radius = Config.FOV
        
        -- Adjust smoothness based on distance and enemy speed
        Config.Smoothness = math.clamp(0.2 + (averageDistance / 100) - (fastestEnemySpeed / 50), 0.1, 0.8)
        
        -- Adjust prediction based on enemy speed
        Config.PredictionStrength = math.clamp(fastestEnemySpeed / 50, 0.05, 0.3)
        
        -- Adjust stabilization based on number of enemies
        Config.StabilizationEnabled = enemyCount <= 3
        
        -- Adjust humanization based on situation
        Config.HumanizationFactor = math.clamp(0.1 + (enemyCount / 20), 0.1, 0.4)
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
        autoAdjustSettings() -- Run auto-adjust every frame
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

--- v5 

