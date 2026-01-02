-- Seliware Compatibility & Optimization
if not game:IsLoaded() then game.Loaded:Wait() end

-- Auto-execute check for teleports
local autoExecuteFile = "allahware_autoexec.txt"
local shouldAutoExecute = false

if isfile and isfile(autoExecuteFile) then
    shouldAutoExecute = true
    if delfile then
        delfile(autoExecuteFile)
    end
end

-- Save script source for auto-execution
local scriptSource = [[loadstring(game:HttpGet('YOUR_SCRIPT_URL_HERE'))()]]
-- If you're running from a local file, update the scriptSource variable above with your loadstring

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Initialize core services early
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Cursor visibility setup
local UserInputService = game:GetService("UserInputService")
local Mouse = LocalPlayer:GetMouse()

-- Show cursor when script GUI is active
local function setupCursor()
    Mouse.Icon = "rbxasset://textures/Cursor.png" -- Default cursor
end

task.spawn(setupCursor)

-- Auto-execute notification
if shouldAutoExecute then
    task.wait(2)
    Rayfield:Notify({
        Title = "Auto-Execute",
        Content = "Script auto-executed after teleport!",
        Duration = 5,
        Image = "check-circle",
    })
end

local Window = Rayfield:CreateWindow({
   Name = "AllahWare: Reborn",
   LoadingTitle = "AllahWare: Reborn",
   LoadingSubtitle = "by Nigga Hater",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "AllahWareReborn",
      FileName = "Config"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false,
   Theme = "Ocean"
})

local placeIds = {
    Tokyo = 14220581261,
    EntDistrict = 17231846331,
    Forest = 14220581641,
    Plains = 14220581884,
    SlayerVillage = 15240226383
}

local locationNames = {}
for name, _ in pairs(placeIds) do
    table.insert(locationNames, name)
end

local MainTab = Window:CreateTab("Teleports", "map-pin")
local LoggerTab = Window:CreateTab("Anim Logger", "activity")
local AutoparryTab = Window:CreateTab("Auto Parry", "shield")

local selectedLocation = nil

MainTab:CreateSection("World Teleports")

MainTab:CreateParagraph({Title = "Auto-Execute Info", Content = "When you teleport, the script will automatically save a flag. When you rejoin/load into the new server, simply re-execute this script and it will detect the auto-execute flag!"})

local TeleportDropdown = MainTab:CreateDropdown({
   Name = "Select Location",
   Options = locationNames,
   CurrentOption = {"Select Location"},
   MultipleOptions = false,
   Flag = "TeleportDropdown",
   Callback = function(Options)
      selectedLocation = Options[1]
   end,
})

MainTab:CreateButton({
   Name = "Teleport",
   Callback = function()
      if selectedLocation and placeIds[selectedLocation] then
         -- Set auto-execute flag before teleporting
         if writefile then
            writefile(autoExecuteFile, "true")
         end
         
         Rayfield:Notify({
            Title = "Teleporting",
            Content = "Teleporting to " .. selectedLocation .. "... Script will auto-execute!",
            Duration = 3,
            Image = "map-pin",
         })
         
         task.wait(1)
         TeleportService:Teleport(placeIds[selectedLocation], LocalPlayer)
      else
         Rayfield:Notify({
            Title = "Error",
            Content = "Please select a valid location first!",
            Duration = 5,
            Image = "alert-circle",
         })
      end
   end,
})

LoggerTab:CreateSection("Logger Controls")

local loggingEnabled = false
local loggedAnimations = {} -- Now stores: {id = {name, username, timestamp, count}}
local loggedAnimationsArray = {} -- Array version for display
local viewerGui = nil

-- Forward declaration
local updateAnimationViewer

local function saveAnimationsToFile()
    if not writefile then return end
    
    local content = "========================================\n"
    content = content .. "ANIMATION LOG - " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    content = content .. "========================================\n\n"
    
    if #loggedAnimationsArray == 0 then
        content = content .. "No animations logged yet.\n"
    else
        local animsByUser = {}
        for _, anim in ipairs(loggedAnimationsArray) do
            if not animsByUser[anim.username] then
                animsByUser[anim.username] = {}
            end
            table.insert(animsByUser[anim.username], anim)
        end
        
        for username, anims in pairs(animsByUser) do
            content = content .. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            content = content .. "USER: " .. username .. " (" .. #anims .. " animations)\n"
            content = content .. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            for idx, anim in ipairs(anims) do
                local timestamp = os.date("%H:%M:%S", anim.timestamp)
                content = content .. string.format(
                    "  [%d] Name: %s\n      ID: %s\n      Time: %s\n\n",
                    idx,
                    anim.name,
                    anim.id,
                    timestamp
                )
            end
        end
    end
    
    content = content .. "\n========================================\n"
    content = content .. "Total Animations Logged: " .. #loggedAnimationsArray .. "\n"
    content = content .. "========================================\n"
    
    writefile("animations_log.txt", content)
end

local function logAnimation(id, name, username)
    local cleanId = tostring(id):gsub("rbxassetid://", "")
    
    if not loggedAnimations[cleanId] then
        loggedAnimations[cleanId] = {
            name = name,
            username = username,
            timestamp = os.time(),
            count = 1
        }
        table.insert(loggedAnimationsArray, {
            id = cleanId,
            name = name,
            username = username,
            timestamp = os.time()
        })
        
        print("--------------------------------")
        print("Animation Logged:")
        print("Name: " .. tostring(name))
        print("ID: " .. cleanId)
        print("Username: " .. tostring(username))
        print("Full Path: " .. tostring(id))
        
        -- Save to file
        saveAnimationsToFile()
        
        -- Update the viewer if it's open
        updateAnimationViewer()
        
        -- Seliware clipboard support
        if setclipboard then
            setclipboard(cleanId)
        end
    else
        loggedAnimations[cleanId].count = (loggedAnimations[cleanId].count or 1) + 1
    end
end

local function setupLogger(character)
    local humanoid = character:WaitForChild("Humanoid")
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end
    
    humanoid.AnimationPlayed:Connect(function(animationTrack)
        if loggingEnabled then
            -- Check distance (only log if within 50 studs)
            local localChar = LocalPlayer.Character
            if not localChar then return end
            
            local localRoot = localChar:FindFirstChild("HumanoidRootPart")
            local targetRoot = character:FindFirstChild("HumanoidRootPart")
            
            if localRoot and targetRoot then
                local distance = (localRoot.Position - targetRoot.Position).Magnitude
                
                if distance <= 50 then
                    local anim = animationTrack.Animation
                    logAnimation(anim.AnimationId, anim.Name, player.Name)
                end
            end
        end
    end)
end

-- Setup logger for all existing players
for _, player in pairs(Players:GetPlayers()) do
    if player.Character then
        setupLogger(player.Character)
    end
    player.CharacterAdded:Connect(setupLogger)
end

-- Setup logger for new players
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(setupLogger)
    if player.Character then
        setupLogger(player.Character)
    end
end)

updateAnimationViewer = function()
    if not viewerGui then return end
    
    local mainFrame = viewerGui:FindFirstChild("MainFrame")
    if not mainFrame then return end
    
    local scrollFrame = mainFrame:FindFirstChild("ScrollFrame")
    if not scrollFrame then return end
    
    local scrollContent = scrollFrame:FindFirstChild("ScrollContent")
    if not scrollContent then return end
    
    -- Update stats label
    local statsLabel = mainFrame:FindFirstChild("StatsLabel")
    if statsLabel then
        statsLabel.Text = "Total Animations: " .. #loggedAnimationsArray
    end
    
    -- Clear existing content
    for _, child in ipairs(scrollContent:GetChildren()) do
        if child:IsA("UIListLayout") then continue end
        child:Destroy()
    end
    
    if #loggedAnimationsArray == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        emptyLabel.TextSize = 14
        emptyLabel.Font = Enum.Font.GothamMedium
        emptyLabel.Text = "No animations logged yet.\nEnable logger and perform actions."
        emptyLabel.TextWrapped = true
        emptyLabel.Size = UDim2.new(1, -20, 0, 100)
        emptyLabel.Parent = scrollContent
    else
        for index, anim in ipairs(loggedAnimationsArray) do
            local timestamp = os.date("%H:%M:%S", anim.timestamp)
            
            -- Animation container card
            local animCard = Instance.new("Frame")
            animCard.Name = "AnimCard"
            animCard.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
            animCard.BorderSizePixel = 0
            animCard.Size = UDim2.new(1, -20, 0, 110)
            animCard.Parent = scrollContent
            
            -- Add rounded corners
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = animCard
            
            -- Index badge
            local indexBadge = Instance.new("TextLabel")
            indexBadge.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
            indexBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
            indexBadge.TextSize = 12
            indexBadge.Font = Enum.Font.GothamBold
            indexBadge.Text = "#" .. index
            indexBadge.Size = UDim2.new(0, 40, 0, 20)
            indexBadge.Position = UDim2.new(0, 8, 0, 8)
            indexBadge.Parent = animCard
            
            local badgeCorner = Instance.new("UICorner")
            badgeCorner.CornerRadius = UDim.new(0, 4)
            badgeCorner.Parent = indexBadge
            
            -- Animation name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
            nameLabel.TextSize = 13
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Text = anim.name
            nameLabel.TextWrapped = true
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Size = UDim2.new(1, -60, 0, 20)
            nameLabel.Position = UDim2.new(0, 55, 0, 8)
            nameLabel.Parent = animCard
            
            -- User label
            local userLabel = Instance.new("TextLabel")
            userLabel.BackgroundTransparency = 1
            userLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            userLabel.TextSize = 11
            userLabel.Font = Enum.Font.Gotham
            userLabel.Text = "👤 " .. anim.username
            userLabel.TextXAlignment = Enum.TextXAlignment.Left
            userLabel.Size = UDim2.new(1, -16, 0, 18)
            userLabel.Position = UDim2.new(0, 8, 0, 32)
            userLabel.Parent = animCard
            
            -- ID label
            local idLabel = Instance.new("TextLabel")
            idLabel.BackgroundTransparency = 1
            idLabel.TextColor3 = Color3.fromRGB(150, 180, 255)
            idLabel.TextSize = 11
            idLabel.Font = Enum.Font.GothamMedium
            idLabel.Text = "🆔 " .. anim.id
            idLabel.TextXAlignment = Enum.TextXAlignment.Left
            idLabel.Size = UDim2.new(1, -16, 0, 18)
            idLabel.Position = UDim2.new(0, 8, 0, 52)
            idLabel.Parent = animCard
            
            -- Time label
            local timeLabel = Instance.new("TextLabel")
            timeLabel.BackgroundTransparency = 1
            timeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            timeLabel.TextSize = 10
            timeLabel.Font = Enum.Font.Gotham
            timeLabel.Text = "🕐 " .. timestamp
            timeLabel.TextXAlignment = Enum.TextXAlignment.Left
            timeLabel.Size = UDim2.new(0.5, -16, 0, 18)
            timeLabel.Position = UDim2.new(0, 8, 0, 72)
            timeLabel.Parent = animCard
            
            -- Copy button
            local idCopy = anim.id
            local copyBtn = Instance.new("TextButton")
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 180)
            copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            copyBtn.TextSize = 11
            copyBtn.Font = Enum.Font.GothamBold
            copyBtn.Text = "📋 Copy ID"
            copyBtn.Size = UDim2.new(0.45, -8, 0, 26)
            copyBtn.Position = UDim2.new(0.55, 0, 1, -34)
            copyBtn.BorderSizePixel = 0
            copyBtn.Parent = animCard
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = copyBtn
            
            copyBtn.MouseButton1Click:Connect(function()
                if setclipboard then
                    setclipboard(idCopy)
                    copyBtn.Text = "✓ Copied!"
                    copyBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 100)
                    task.wait(1)
                    copyBtn.Text = "📋 Copy ID"
                    copyBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 180)
                end
            end)
        end
    end
end

local function createAnimationViewer()
    if viewerGui then
        viewerGui:Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AnimationViewerGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    viewerGui = ScreenGui
    
    -- Main window frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    MainFrame.BorderSizePixel = 0
    MainFrame.Size = UDim2.new(0, 650, 0, 750)
    MainFrame.Position = UDim2.new(0.5, -325, 0.5, -375)
    MainFrame.Parent = ScreenGui
    
    -- Add shadow/border effect
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = MainFrame
    
    local borderGradient = Instance.new("UIStroke")
    borderGradient.Color = Color3.fromRGB(80, 140, 220)
    borderGradient.Thickness = 2
    borderGradient.Parent = MainFrame
    
    -- Make frame draggable
    local dragging, dragInput, dragStart, startPos
    local UserInputService = game:GetService("UserInputService")
    
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Make frame resizable
    local ResizeHandle = Instance.new("TextButton")
    ResizeHandle.Name = "ResizeHandle"
    ResizeHandle.BackgroundColor3 = Color3.fromRGB(80, 140, 220)
    ResizeHandle.BorderSizePixel = 0
    ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
    ResizeHandle.Position = UDim2.new(1, -20, 1, -20)
    ResizeHandle.Text = "⬀"
    ResizeHandle.TextSize = 16
    ResizeHandle.TextColor3 = Color3.fromRGB(255, 255, 255)
    ResizeHandle.Font = Enum.Font.GothamBold
    ResizeHandle.ZIndex = 10
    ResizeHandle.Parent = MainFrame
    
    local resizeCorner = Instance.new("UICorner")
    resizeCorner.CornerRadius = UDim.new(0, 6)
    resizeCorner.Parent = ResizeHandle
    
    local resizing = false
    local resizeStart, sizeStart
    
    ResizeHandle.MouseButton1Down:Connect(function()
        resizing = true
        resizeStart = UserInputService:GetMouseLocation()
        sizeStart = MainFrame.Size
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and resizing then
            local mousePos = UserInputService:GetMouseLocation()
            local delta = mousePos - resizeStart
            
            local newWidth = math.max(400, sizeStart.X.Offset + delta.X)
            local newHeight = math.max(300, sizeStart.Y.Offset + delta.Y)
            
            MainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
        end
    end)
    
    -- Title bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.BackgroundColor3 = Color3.fromRGB(30, 60, 120)
    TitleBar.BorderSizePixel = 0
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.Parent = MainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = TitleBar
    
    -- Cover bottom corners
    local titleCover = Instance.new("Frame")
    titleCover.BackgroundColor3 = Color3.fromRGB(30, 60, 120)
    titleCover.BorderSizePixel = 0
    titleCover.Size = UDim2.new(1, 0, 0, 12)
    titleCover.Position = UDim2.new(0, 0, 1, -12)
    titleCover.Parent = TitleBar
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 20
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "🎬 Animation Logger"
    TitleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    TitleLabel.Position = UDim2.new(0, 15, 0, 0)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar
    
    -- Stats label
    local StatsLabel = Instance.new("TextLabel")
    StatsLabel.Name = "StatsLabel"
    StatsLabel.BackgroundTransparency = 1
    StatsLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    StatsLabel.TextSize = 12
    StatsLabel.Font = Enum.Font.Gotham
    StatsLabel.Text = "Total Animations: 0"
    StatsLabel.Size = UDim2.new(0.35, 0, 1, 0)
    StatsLabel.Position = UDim2.new(0.5, 0, 0, 0)
    StatsLabel.TextXAlignment = Enum.TextXAlignment.Right
    StatsLabel.Parent = TitleBar
    
    -- Close button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 18
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "✕"
    CloseButton.Size = UDim2.new(0, 35, 0, 35)
    CloseButton.Position = UDim2.new(1, -45, 0, 7.5)
    CloseButton.BorderSizePixel = 0
    CloseButton.Parent = TitleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = CloseButton
    
    CloseButton.MouseButton1Click:Connect(function()
        viewerGui:Destroy()
        viewerGui = nil
    end)
    
    CloseButton.MouseEnter:Connect(function()
        CloseButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    end)
    
    CloseButton.MouseLeave:Connect(function()
        CloseButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    end)
    
    -- Scrolling frame for animations
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "ScrollFrame"
    ScrollFrame.BackgroundColor3 = Color3.fromRGB(22, 25, 35)
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.Size = UDim2.new(1, -20, 1, -120)
    ScrollFrame.Position = UDim2.new(0, 10, 0, 60)
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 140, 220)
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.Parent = MainFrame
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 8)
    scrollCorner.Parent = ScrollFrame
    
    local ScrollContent = Instance.new("Frame")
    ScrollContent.Name = "ScrollContent"
    ScrollContent.BackgroundTransparency = 1
    ScrollContent.BorderSizePixel = 0
    ScrollContent.Size = UDim2.new(1, 0, 1, 0)
    ScrollContent.Parent = ScrollFrame
    
    -- Add UIListLayout for automatic positioning
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = ScrollContent
    
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)
    
    -- Bottom button frame
    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Name = "ButtonFrame"
    ButtonFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
    ButtonFrame.BorderSizePixel = 0
    ButtonFrame.Size = UDim2.new(1, -20, 0, 50)
    ButtonFrame.Position = UDim2.new(0, 10, 1, -60)
    ButtonFrame.Parent = MainFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = ButtonFrame
    
    local SaveButton = Instance.new("TextButton")
    SaveButton.Name = "SaveButton"
    SaveButton.BackgroundColor3 = Color3.fromRGB(50, 150, 100)
    SaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveButton.TextSize = 13
    SaveButton.Font = Enum.Font.GothamBold
    SaveButton.Text = "💾 Save to File"
    SaveButton.Size = UDim2.new(0.5, -8, 1, -12)
    SaveButton.Position = UDim2.new(0, 6, 0, 6)
    SaveButton.BorderSizePixel = 0
    SaveButton.Parent = ButtonFrame
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 8)
    saveCorner.Parent = SaveButton
    
    SaveButton.MouseButton1Click:Connect(function()
        saveAnimationsToFile()
        SaveButton.Text = "✓ Saved!"
        task.wait(1)
        SaveButton.Text = "💾 Save to File"
    end)
    
    local ClearButton = Instance.new("TextButton")
    ClearButton.Name = "ClearButton"
    ClearButton.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
    ClearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearButton.TextSize = 13
    ClearButton.Font = Enum.Font.GothamBold
    ClearButton.Text = "🗑️ Clear & Save"
    ClearButton.Size = UDim2.new(0.5, -8, 1, -12)
    ClearButton.Position = UDim2.new(0.5, 2, 0, 6)
    ClearButton.BorderSizePixel = 0
    ClearButton.Parent = ButtonFrame
    
    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 8)
    clearCorner.Parent = ClearButton
    
    ClearButton.MouseButton1Click:Connect(function()
        saveAnimationsToFile()
        loggedAnimations = {}
        loggedAnimationsArray = {}
        updateAnimationViewer()
    end)
    
    updateAnimationViewer()
end

LoggerTab:CreateToggle({
   Name = "Enable Logger",
   CurrentValue = false,
   Flag = "LoggerToggle",
   Callback = function(Value)
      loggingEnabled = Value
      if loggingEnabled then
          Rayfield:Notify({
              Title = "Logger Enabled",
              Content = "Now logging all played animations to console and notifications.",
              Duration = 3,
              Image = "play",
          })
      end
   end,
})

LoggerTab:CreateButton({
   Name = "View Logged Animations",
   Callback = function()
      createAnimationViewer()
   end,
})

LoggerTab:CreateButton({
   Name = "Clear Log Cache",
   Callback = function()
      saveAnimationsToFile()
      loggedAnimations = {}
      loggedAnimationsArray = {}
      Rayfield:Notify({
          Title = "Cache Cleared",
          Content = "Animation log has been saved and cleared.",
          Duration = 3,
          Image = "trash-2",
      })
   end,
})

LoggerTab:CreateSection("Instructions")
LoggerTab:CreateLabel("Animations will be printed to the F9 console.")
LoggerTab:CreateLabel("Copy IDs from the console or notifications.")

-- Autoparry System
-- Autoparry storage
local autoparryAnimations = {} -- {animId = {name, timing, enabled, range}}
local autoparryEnabled = false
local parryKey = Enum.KeyCode.F
local defaultTiming = 0.15

-- Anti-spam tracking
local activeParryQueue = {} -- Track queued parries to prevent duplicates
local feintedPlayers = {} -- Track players who just feinted

-- Feint detection - unqueue parries when opponent feints
local function setupFeintDetection()
    local success, err = pcall(function()
        local feintSoundId = "rbxassetid://5763723309"
        local localPlayer = game:GetService("Players").LocalPlayer
    
        -- Monitor for feint sounds from other players
        local function checkForFeintSound(sound)
            if not sound:IsA("Sound") then return end
            if tostring(sound.SoundId) ~= feintSoundId then return end
            
            -- Find which player this sound belongs to
            local character = sound:FindFirstAncestorOfClass("Model")
            if not character then return end
            
            local player = game:GetService("Players"):GetPlayerFromCharacter(character)
            if not player or player == localPlayer then return end
            
            -- Check distance - ignore if over 25 studs
            local myChar = localPlayer.Character
            if not myChar then return end
            local myRoot = myChar:FindFirstChild("HumanoidRootPart")
            local theirRoot = character:FindFirstChild("HumanoidRootPart")
            if not myRoot or not theirRoot then return end
            
            local distance = (myRoot.Position - theirRoot.Position).Magnitude
            if distance > 25 then return end
            
            local playerName = player.Name
            
            -- Mark player as feinted
            feintedPlayers[playerName] = tick()
            
            -- Remove all queued parries for this player
            local cancelled = 0
            for queueKey, _ in pairs(activeParryQueue) do
                if string.find(queueKey, "_" .. playerName) then
                    activeParryQueue[queueKey] = nil
                    cancelled = cancelled + 1
                end
            end
            
            if cancelled > 0 then
                print("[FEINT] " .. playerName .. " feinted (sound detected) - cancelled " .. cancelled .. " queued parry(ies)")
            end
            
            -- Clear feint flag almost immediately (game is fast-paced)
            task.delay(0.1, function()
                feintedPlayers[playerName] = nil
            end)
        end
        
        -- Monitor existing sounds and new sounds added to workspace
        local function monitorCharacter(character)
            local function hookSound(sound)
                -- Check on Played event
                sound.Played:Connect(function()
                    checkForFeintSound(sound)
                end)
                -- Also check when Playing property changes
                sound:GetPropertyChangedSignal("Playing"):Connect(function()
                    if sound.Playing then
                        checkForFeintSound(sound)
                    end
                end)
                -- Check immediately if already playing
                if sound.Playing and tostring(sound.SoundId) == feintSoundId then
                    checkForFeintSound(sound)
                end
            end
            
            -- Check existing sounds
            for _, desc in ipairs(character:GetDescendants()) do
                if desc:IsA("Sound") then
                    hookSound(desc)
                end
            end
            
            -- Monitor new sounds
            character.DescendantAdded:Connect(function(desc)
                if desc:IsA("Sound") then
                    hookSound(desc)
                end
            end)
        end
        
        -- Monitor all players
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            if player ~= localPlayer and player.Character then
                monitorCharacter(player.Character)
            end
            player.CharacterAdded:Connect(function(char)
                if player ~= localPlayer then
                    monitorCharacter(char)
                end
            end)
        end
        
        game:GetService("Players").PlayerAdded:Connect(function(player)
            player.CharacterAdded:Connect(function(char)
                if player ~= localPlayer then
                    monitorCharacter(char)
                end
            end)
        end)
        
        print("[AUTOPARRY] Feint detection enabled (sound-based)")
    end)
    
    if not success then
        warn("[AUTOPARRY] Feint detection failed: " .. tostring(err))
    end
end

-- Initialize feint detection
task.spawn(setupFeintDetection)

-- Manual parry learning system
-- Track animations PER PLAYER to avoid learning wrong animations when multiple fights nearby
local recentEnemyAnimations = {} -- {animId = {name, timestamp, playerName, distance}}
local recentAnimationsByPlayer = {} -- {playerName = {animId, timestamp, name, distance}} - most recent per player
local manualParryTimestamp = 0
local autoLearnEnabled = true
local scriptRunning = true -- Flag to stop background loops on cleanup

-- ============================================
-- GLOBAL ANIMATION DATABASE (npoint.io)
-- ============================================
-- npoint.io API for reading/writing global animations
local GLOBAL_ANIMS_URL = "https://api.npoint.io/648f4993a0a4db7ba15a"
local autoSubmitEnabled = true
local lastGlobalSync = 0
local HttpService = game:GetService("HttpService")

-- Forward declarations for persistence helpers
local saveAutoparryAsJSON
local loadAutoparryFromFile
local saveBlacklist
local loadBlacklist
local autoparryBlacklist = {}
local AUTOPARRY_BLACKLIST_FILE = "autoparry_blacklist.txt"

-- Save as JSON for better compatibility
function saveAutoparryAsJSON()
    if not writefile or not HttpService then return end
    local json = HttpService:JSONEncode(autoparryAnimations)
    writefile("autoparry_animations_data.txt", json)
end

-- Legacy stub (JSON is primary)
local function saveAutoparryToFile()
    saveAutoparryAsJSON()
end

-- Load autoparry animations from disk
function loadAutoparryFromFile()
    if not isfile or not isfile("autoparry_animations_data.txt") then 
        return 
    end
    local content = readfile("autoparry_animations_data.txt")
    if not content then return end
    local success, result = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if success and result then
        autoparryAnimations = result
        local count = 0
        for _ in pairs(autoparryAnimations) do
            count = count + 1
        end
        if count > 0 then
            Rayfield:Notify({
                Title = "Loaded",
                Content = "Loaded " .. count .. " autoparry animation" .. (count == 1 and "" or "s"),
                Duration = 3,
                Image = "check-circle",
            })
        end
    end
end

-- Blacklist helpers (local only)
function saveBlacklist()
    if not writefile or not HttpService then return end
    writefile(AUTOPARRY_BLACKLIST_FILE, HttpService:JSONEncode(autoparryBlacklist))
end

function loadBlacklist()
    if not isfile or not isfile(AUTOPARRY_BLACKLIST_FILE) then return end
    local content = readfile(AUTOPARRY_BLACKLIST_FILE)
    if not content or content == "" then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if ok and type(data) == "table" then
        autoparryBlacklist = data
    end
end

local function addToBlacklist(animId)
    local id = tostring(animId or ""):gsub("rbxassetid://", "")
    if id == "" then
        return false, "Empty ID"
    end
    autoparryBlacklist[id] = true
    saveBlacklist()
    return true, id
end

local function isBlacklisted(animId)
    return autoparryBlacklist[tostring(animId or ""):gsub("rbxassetid://", "")]
end

local function pruneBlacklistedAutoparry()
    local removed = false
    for animId, _ in pairs(autoparryAnimations) do
        if isBlacklisted(animId) then
            autoparryAnimations[animId] = nil
            removed = true
        end
    end
    if removed then
        saveAutoparryAsJSON()
    end
end

-- Fetch global animations from npoint.io (supports executor request fallbacks)
local function fetchGlobalAnimations()
    local function decode(jsonText)
        if not jsonText or jsonText == "" then return nil end
        local ok, decoded = pcall(function()
            return game:GetService("HttpService"):JSONDecode(jsonText)
        end)
        if ok and decoded and type(decoded) == "table" then
            return decoded
        end
        return nil
    end

    -- Try native HttpGet
    local ok, result = pcall(function()
        return game:HttpGet(GLOBAL_ANIMS_URL)
    end)
    if ok then
        local decoded = decode(result)
        if decoded then return decoded end
    end

    -- Executor request fallbacks
    local requestFuncs = {syn and syn.request, http_request, request}
    for _, fn in ipairs(requestFuncs) do
        if fn then
            local resp = fn({Url = GLOBAL_ANIMS_URL, Method = "GET"})
            local body = resp and (resp.Body or resp.body)
            local decoded = decode(body)
            if decoded then return decoded end
        end
    end

    warn("[GLOBAL DB] Failed to fetch global animations")
    return nil
end

-- Merge global animations with local using provided schema
local function mergeGlobalAnimations(globalAnims)
    if not globalAnims then return 0 end
    
    local added = 0
    local updated = 0
    
    for animId, data in pairs(globalAnims) do
        if not isBlacklisted(animId) then
            local incoming = {
            name = data.name or "Unknown",
            timing = data.timing or 0.15,
            enabled = data.enabled ~= false,
            range = data.range or 15,
            source = "global"
        }
            if not autoparryAnimations[animId] then
                autoparryAnimations[animId] = incoming
                added = added + 1
            else
                -- Update timing/name/range/enabled for non-manual entries
                local localAnim = autoparryAnimations[animId]
                if localAnim.source ~= "manual" then
                    localAnim.name = incoming.name
                    localAnim.timing = incoming.timing
                    localAnim.range = incoming.range
                    localAnim.enabled = incoming.enabled
                    localAnim.source = "global"
                    updated = updated + 1
                end
            end
        end
    end
    
    if added > 0 or updated > 0 then
        saveAutoparryAsJSON()
    end
    
    return added, updated
end

-- Auto-submit animation to npoint.io when learned
local function submitLearnedAnimation(animId, animData, isUpdate)
    if not autoSubmitEnabled then return end
    
    task.spawn(function()
        local success, err = pcall(function()
            local HttpService = game:GetService("HttpService")

            -- Fetch latest global data
            local currentData = fetchGlobalAnimations() or {}

            -- Merge our animation into the global data (schema: enabled, range, name, timing)
            local existingAnim = currentData[animId]
            if existingAnim then
                existingAnim.enabled = animData.enabled ~= false
                existingAnim.range = animData.range or existingAnim.range or 15
                existingAnim.name = animData.name or existingAnim.name or "Unknown"
                if isUpdate and existingAnim.timing then
                    existingAnim.timing = (existingAnim.timing + animData.timing) / 2
                else
                    existingAnim.timing = animData.timing
                end
            else
                currentData[animId] = {
                    name = animData.name or "Unknown",
                    timing = animData.timing,
                    range = animData.range or 15,
                    enabled = animData.enabled ~= false
                }
            end

            -- Upload merged data back to npoint.io (overwrite payload)
            local jsonPayload = HttpService:JSONEncode(currentData)
            local reqBody = {
                Url = GLOBAL_ANIMS_URL,
                Method = "PUT",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonPayload
            }
            local requestFuncs = {syn and syn.request, http_request, request}
            for _, fn in ipairs(requestFuncs) do
                if fn then
                    fn(reqBody)
                    return
                end
            end
            -- Fallback to HttpPost
            game:HttpPost(GLOBAL_ANIMS_URL, jsonPayload)
        end)

        if not success then
            warn("[GLOBAL DB] Submit failed: " .. tostring(err))
        end
    end)
end

-- Virtual Input Service
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

-- Parry tracking for failure detection
local parryAttempts = {} -- {animId = {timestamp, animData, playerName, distance, compensation}}
local lastHealth = 100
local pingCompensation = 0

-- Measured round-trip ping storage (seconds)
local measuredPing = 0.05 -- Default 50ms RTT
local pingSamples = {}
local MAX_PING_SAMPLES = 8

local function median(values)
    if #values == 0 then return nil end
    table.sort(values)
    local mid = math.floor(#values / 2) + 1
    return values[mid]
end

-- Function to measure actual round-trip ping from a simple, deterministic path
local function measureActualPing()
    local ok, result = pcall(function()
        local stats = game:GetService("Stats")
        local net = stats and stats.Network

        -- 1) Direct Data Ping from ServerStatsItem / Network child / legacy Stats child
        local function tryDataPing()
            local item = net and net.ServerStatsItem and net.ServerStatsItem["Data Ping"]
            if item then
                if item.GetValue then return item:GetValue() / 1000 end
                if item.Value then return item.Value / 1000 end
                if item.GetAverage then return item:GetAverage() / 1000 end
            end

            local netChild = net and net:FindFirstChild("Data Ping")
            if netChild then
                if netChild.GetValue then return netChild:GetValue() / 1000 end
                if netChild.Value then return netChild.Value / 1000 end
            end

            if stats then
                local legacy = stats:FindFirstChild("Data Ping")
                if legacy then
                    if legacy.GetValue then return legacy:GetValue() / 1000 end
                    if legacy.Value then return legacy.Value / 1000 end
                end
            end
            return nil
        end

        local dataPing = tryDataPing()
        if dataPing then
            return dataPing
        end

        -- 2) PerformanceStats Ping
        if stats then
            local perfStats = stats:FindFirstChild("PerformanceStats")
            if perfStats then
                local pingItem = perfStats:FindFirstChild("Ping")
                if pingItem and pingItem.GetValue then
                    local val = pingItem:GetValue()
                    if val and val > 0 then
                        return val / 1000
                    end
                end
            end
        end

        -- 3) Any ServerStatsItem numeric value as fallback
        if net and net.ServerStatsItem then
            for _, item in pairs(net.ServerStatsItem) do
                if typeof(item) == "Instance" then
                    local val = nil
                    if item.GetValue then val = item:GetValue() end
                    if not val and item.Value then val = item.Value end
                    if not val and item.GetAverage then val = item:GetAverage() end
                    if val and val > 0 then
                        return val / 1000
                    end
                end
            end
        end

        -- 4) In-game UI label scan
        local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetDescendants()) do
                if gui:IsA("TextLabel") then
                    local text = gui.Text:lower()
                    local pingMatch = text:match("(%d+)%s*ms")
                    if pingMatch then
                        local pingVal = tonumber(pingMatch)
                        if pingVal and pingVal > 0 and pingVal < 5000 then
                            return pingVal / 1000
                        end
                    end
                end
            end
        end

        -- 5) Last resort RTT timing
        local startTime = tick()
        local _ = game:GetService("Workspace"):GetServerTimeNow()
        local endTime = tick()
        local roundTrip = math.max(endTime - startTime, 0.001)
        return roundTrip
    end)

    if not ok then
        return nil
    end

    -- Reject bad values to avoid freezing at defaults
    if result and result > 0 and result < 5 then
        return result
    end

    return nil
end

-- Quick, on-demand ping fetch straight from Data Ping (no smoothing)
local function fetchImmediatePing()
    local stats = game:GetService("Stats")
    local net = stats and stats.Network
    local item = net and net.ServerStatsItem and net.ServerStatsItem["Data Ping"]
    if item then
        local ok, val = pcall(function()
            return item.GetValue and item:GetValue() or item.Value
        end)
        if ok and val and val > 0 then
            return val / 1000
        end
    end
    return nil
end

-- Function to get one-way ping compensation (half RTT, clamped)
local function getPingCompensation()
    local oneWay = measuredPing * 0.5
    return math.clamp(oneWay, 0.005, 0.35)
end

-- Update ping measurement regularly (stops when script closes)
task.spawn(function()
    while scriptRunning and task.wait(1) do
        local newPing = measureActualPing()
        if newPing then
            table.insert(pingSamples, newPing)
            if #pingSamples > MAX_PING_SAMPLES then
                table.remove(pingSamples, 1)
            end

            -- Use median of rolling samples to avoid spikes
            local temp = {}
            for i = 1, #pingSamples do
                temp[i] = pingSamples[i]
            end
            measuredPing = median(temp)
        end
        pingCompensation = getPingCompensation()
    end
end)

-- Sync global animations on startup (delayed to not slow down load)
task.spawn(function()
    task.wait(3) -- Wait for script to fully load
    if autoSubmitEnabled then
        local globalAnims = fetchGlobalAnimations()
        if globalAnims then
            local added, updated = mergeGlobalAnimations(globalAnims)
            if added > 0 or updated > 0 then
                Rayfield:Notify({
                    Title = "🌐 Global Sync",
                    Content = "Added " .. added .. " new, updated " .. updated .. " animations",
                    Duration = 4,
                    Image = "globe",
                })
            end
            lastGlobalSync = tick()
        end
    end
end)

-- Function to press F key (no cooldown for spammy games like Demon Hunter)
local function pressParryKey()
    VirtualInputManager:SendKeyEvent(true, parryKey, false, game)
    task.wait(0.03)
    VirtualInputManager:SendKeyEvent(false, parryKey, false, game)
    return true
end

-- Common animation name patterns to ignore (not attacks)
local ignoredAnimPatterns = {
    "idle", "walk", "run", "jump", "fall", "land", "climb",
    "sit", "swim", "tool", "wave", "point", "dance", "cheer",
    "laugh", "equip", "unequip", "hold", "locomotion", "pose",
    "emote", "gesture", "movement", "stand", "crouch",
    "block", "dodge", "parry", "guard", "defend", "roll", "evade", "dash"
}

-- Check if animation name matches ignored patterns
local function isIgnoredAnimation(animName)
    local lowerName = string.lower(animName or "")
    for _, pattern in ipairs(ignoredAnimPatterns) do
        if string.find(lowerName, pattern) then
            return true
        end
    end
    return false
end

-- Track enemy animations for manual parry learning (with distance check)
local function trackEnemyAnimation(animId, animName, playerName, distance, animTrack)
    local rawId = tostring(animId)
    
    -- Filter out likely non-attack animations by name
    if isIgnoredAnimation(animName) then
        return
    end
    
    -- Only track animations from enemies within parry range
    if distance and distance > 20 then
        return
    end
    
    -- Check animation track properties if available
    if animTrack then
        -- Looping animations are usually not attacks (idle, walk cycles)
        if animTrack.Looped then
            return
        end
        
        -- Very long animations (>1.5s) are usually not quick attacks
        if animTrack.Length and animTrack.Length > 1.5 then
            return
        end
        
        -- Very short animations (<0.1s) are usually glitches or transitions
        if animTrack.Length and animTrack.Length < 0.1 then
            return
        end
    end
    
    local cleanId = rawId:gsub("rbxassetid://", "")

    if isBlacklisted(cleanId) then
        return
    end
    
    -- Don't track if already in our autoparry list
    if autoparryAnimations[cleanId] then
        return
    end
    
    local timestamp = tick()
    
    recentEnemyAnimations[cleanId] = {
        name = animName,
        timestamp = timestamp,
        playerName = playerName,
        distance = distance,
        length = animTrack and animTrack.Length or nil
    }
    
    -- Also track per-player (most recent animation from each player)
    -- This helps us identify WHO hit us when we take damage
    recentAnimationsByPlayer[playerName] = {
        animId = cleanId,
        name = animName,
        timestamp = timestamp,
        distance = distance
    }
    
    -- Clean up old entries after 2 seconds
    task.delay(2, function()
        if recentEnemyAnimations[cleanId] and tick() - recentEnemyAnimations[cleanId].timestamp >= 2 then
            recentEnemyAnimations[cleanId] = nil
        end
        -- Also clean up per-player tracking
        if recentAnimationsByPlayer[playerName] and tick() - recentAnimationsByPlayer[playerName].timestamp >= 2 then
            recentAnimationsByPlayer[playerName] = nil
        end
    end)
end

-- Track last damage time for learning validation
local lastDamageTime = 0
local lastDamageAnimations = {}
local parryAnimDetected = false
local parryAnimTimestamp = 0

-- The animation ID that plays when you successfully parry
local PARRY_SUCCESS_ANIM_ID = "13021922061"

-- Monitor for parry success animation on local player
local function setupParryAnimationDetection()
    local function watchForParryAnim(character)
        if not character then return end
        
        local humanoid = character:WaitForChild("Humanoid", 5)
        if not humanoid then return end
        
        humanoid.AnimationPlayed:Connect(function(animationTrack)
            local anim = animationTrack.Animation
            local animId = tostring(anim.AnimationId):gsub("rbxassetid://", "")
            
            if animId == PARRY_SUCCESS_ANIM_ID then
                parryAnimDetected = true
                parryAnimTimestamp = tick()
                print("[PARRY DETECTOR] Parry success animation detected!")
            end
        end)
    end
    
    -- Watch current character
    if LocalPlayer.Character then
        watchForParryAnim(LocalPlayer.Character)
    end
    
    -- Watch future characters
    LocalPlayer.CharacterAdded:Connect(watchForParryAnim)
end

-- Initialize parry animation detection
task.spawn(setupParryAnimationDetection)

-- Called when player takes damage - stores which animations were active
local function onDamageTakenForLearning()
    lastDamageTime = tick()
    -- Copy current animations that could have caused damage
    lastDamageAnimations = {}
    for animId, animData in pairs(recentEnemyAnimations) do
        local timeSinceAnim = lastDamageTime - animData.timestamp
        -- Animation played 0.1-1.5s before damage = likely the attack that hit us
        if timeSinceAnim >= 0.1 and timeSinceAnim <= 1.5 then
            lastDamageAnimations[animId] = {
                name = animData.name,
                playerName = animData.playerName,
                timingNeeded = timeSinceAnim -- This is how early we should have parried
            }
        end
    end
end

-- Detect manual parry input and learn from it
local function setupManualParryDetection()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == parryKey and autoLearnEnabled then
            manualParryTimestamp = tick()
            parryAnimDetected = false -- Reset before parry attempt
            
            -- Wait to see if parry success animation plays
            task.delay(0.2, function()
                -- Check if we got a parry success animation (not just a block)
                local successfulParry = parryAnimDetected and (parryAnimTimestamp >= manualParryTimestamp)
                
                if successfulParry then
                    print("[LEARNING] Parry animation confirmed - checking enemy animations...")
                    
                    -- Find the closest animation to our parry timing
                    local bestMatch = nil
                    local bestTiming = math.huge
                    
                    for animId, animData in pairs(recentEnemyAnimations) do
                        local timeSinceAnim = manualParryTimestamp - animData.timestamp
                        
                        -- Animation must have played 0.05s to 0.8s before our parry
                        if timeSinceAnim >= 0.05 and timeSinceAnim <= 0.8 then
                            -- Prefer animations closer to our parry time
                            if timeSinceAnim < bestTiming then
                                bestTiming = timeSinceAnim
                                bestMatch = {id = animId, data = animData, timing = timeSinceAnim}
                            end
                        end
                    end
                    
                    -- Only learn the best matching animation (or update if timing differs by >0.05s)
                    if bestMatch then
                        local animId = bestMatch.id
                        local animData = bestMatch.data
                        local calculatedTiming = bestMatch.timing
                        
                        if isBlacklisted(animId) then
                            Rayfield:Notify({
                                Title = "Blocked Animation",
                                Content = "ID " .. animId .. " is blacklisted and won't be learned",
                                Duration = 3,
                                Image = "slash",
                            })
                            return
                        end
                        
                        local existingAnim = autoparryAnimations[animId]
                        local shouldLearn = false
                        local isUpdate = false
                        
                        if not existingAnim then
                            -- New animation - learn it
                            shouldLearn = true
                        else
                            -- Existing animation - check if timing difference is significant (>0.05s)
                            local timingDiff = math.abs(existingAnim.timing - calculatedTiming)
                            if timingDiff > 0.05 then
                                shouldLearn = true
                                isUpdate = true
                            end
                        end
                        
                        if shouldLearn then
                            local oldTiming = existingAnim and existingAnim.timing or nil
                            
                            -- Add/update autoparry list
                            autoparryAnimations[animId] = {
                                name = animData.name,
                                timing = calculatedTiming,
                                enabled = true,
                                range = existingAnim and existingAnim.range or 15,
                                source = "manual"
                            }
                            
                            -- Auto-submit to global database
                            submitLearnedAnimation(animId, autoparryAnimations[animId], isUpdate)
                            
                            -- Save
                            saveAutoparryAsJSON()
                            
                            if isUpdate then
                                print("========================================")
                                print("🔄 UPDATED ANIMATION TIMING")
                                print("Name: " .. animData.name)
                                print("ID: " .. animId)
                                print("Old Timing: " .. string.format("%.3f", oldTiming) .. "s")
                                print("New Timing: " .. string.format("%.3f", calculatedTiming) .. "s")
                                print("From: " .. animData.playerName)
                                print("========================================")
                                
                                Rayfield:Notify({
                                    Title = "🔄 Updated Timing",
                                    Content = animData.name .. ": " .. string.format("%.2f", oldTiming) .. "s → " .. string.format("%.2f", calculatedTiming) .. "s",
                                    Duration = 4,
                                    Image = "refresh-cw",
                                })
                            else
                                print("========================================")
                                print("✅ AUTO-LEARNED NEW ANIMATION")
                                print("Name: " .. animData.name)
                                print("ID: " .. animId)
                                print("Timing: " .. string.format("%.3f", calculatedTiming) .. "s")
                                print("From: " .. animData.playerName)
                                print("========================================")
                                
                                Rayfield:Notify({
                                    Title = "✅ Learned Animation",
                                    Content = animData.name .. " - " .. string.format("%.2f", calculatedTiming) .. "s timing",
                                    Duration = 4,
                                    Image = "plus-circle",
                                })
                            end
                            
                            -- Clear recent animations after learning to prevent duplicates
                            recentEnemyAnimations = {}
                        end
                    end
                else
                    print("[LEARNING] No parry animation detected (block or miss)")
                end
            end)
        end
    end)
end

-- Setup manual parry detection
task.spawn(setupManualParryDetection)

-- Monitor health changes to detect failed parries
local function setupHealthMonitoring()
    if not LocalPlayer.Character then return end
    
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    lastHealth = humanoid.Health
    
    humanoid.HealthChanged:Connect(function(newHealth)
        if newHealth < lastHealth then
            local damage = lastHealth - newHealth
            local currentTime = tick()
            local parryFailed = false
            
            -- Check if we recently attempted a parry (within last 1.5 seconds with ping comp)
            for attemptKey, attemptData in pairs(parryAttempts) do
                local timeSinceAttempt = currentTime - attemptData.timestamp
                
                -- Detect parry failure: damage taken within reasonable window after parry attempt
                if timeSinceAttempt >= 0.01 and timeSinceAttempt <= 1.5 then
                    -- We took damage shortly after parry attempt - likely failed
                    parryFailed = true
                    
                    local animId = attemptData.animId
                    
                    -- DON'T auto-update timing from failed parries - the logic of "add time" is unreliable
                    -- Failed parry could mean we parried too early OR too late
                    -- Only log the failure, let manual parries or damage-based learning fix it
                    
                    print("========================================")
                    print("⚠️ PARRY FAILED")
                    print("========================================")
                    print("Animation: " .. attemptData.animData.name)
                    print("ID: " .. animId)
                    print("Attacker: " .. attemptData.playerName)
                    print("Distance: " .. attemptData.distance .. " studs")
                    print("Current Timing: " .. string.format("%.3f", attemptData.animData.timing) .. "s")
                    print("Time Since Parry: " .. string.format("%.3f", timeSinceAttempt) .. "s")
                    print("TIP: Manually parry this attack successfully to update timing")
                    print("========================================\n")
                    
                    -- Remove from tracking
                    parryAttempts[attemptKey] = nil
                    break
                end
            end
            
            -- LEARN FROM FAILED PARRIES: If we took damage and there's a recent enemy animation, learn it
            if autoLearnEnabled and not parryFailed then
                -- Find the CLOSEST player who recently attacked us (not just most recent animation)
                -- This prevents learning wrong animations when multiple fights are happening nearby
                local bestMatch = nil
                local bestScore = math.huge -- Lower is better (combines distance and timing)
                
                for playerName, playerData in pairs(recentAnimationsByPlayer) do
                    local timeSinceAnim = currentTime - playerData.timestamp
                    local distance = playerData.distance or 20
                    
                    -- Animation must have played 0.01s to 1.0s before we took damage
                    if timeSinceAnim >= 0.01 and timeSinceAnim <= 1.0 then
                        -- Score based on distance (prioritize closest) and timing
                        -- Closer players are more likely to have hit us
                        local score = distance + (timeSinceAnim * 10)
                        
                        if score < bestScore then
                            bestScore = score
                            bestMatch = {
                                id = playerData.animId, 
                                data = {
                                    name = playerData.name,
                                    playerName = playerName,
                                    distance = distance
                                }, 
                                timing = timeSinceAnim
                            }
                        end
                    end
                end
                
                -- Learn from the damage - we need to parry EARLIER than when damage hit
                if bestMatch and not autoparryAnimations[bestMatch.id] and not isBlacklisted(bestMatch.id) then
                    local animId = bestMatch.id
                    local animData = bestMatch.data
                    -- Parry timing should be slightly before when damage occurred
                    -- Use a conservative offset (parry ~70% into the attack timing)
                    -- This is an initial guess - manual parrying will refine it
                    local calculatedTiming = math.max(0.05, bestMatch.timing * 0.7)
                    
                    -- Clamp to reasonable range for attack timings
                    calculatedTiming = math.clamp(calculatedTiming, 0.05, 0.5)
                    
                    -- Add to autoparry list
                    autoparryAnimations[animId] = {
                        name = animData.name,
                        timing = calculatedTiming,
                        enabled = true,
                        range = 15,
                        source = "damage"
                    }
                    
                    -- Auto-submit to global database
                    submitLearnedAnimation(animId, autoparryAnimations[animId], false)
                    
                    -- Save
                    saveAutoparryAsJSON()
                    
                    print("========================================")
                    print("📚 LEARNED NEW ANIMATION (initial timing)")
                    print("Name: " .. animData.name)
                    print("ID: " .. animId)
                    print("Timing: " .. string.format("%.3f", calculatedTiming) .. "s (estimate)")
                    print("From: " .. animData.playerName)
                    print("Distance: " .. math.floor(animData.distance) .. " studs")
                    print("TIP: Manually parry this attack to refine timing")
                    print("========================================")
                    
                    Rayfield:Notify({
                        Title = "📚 Learned (needs refinement)",
                        Content = animData.name .. " - " .. string.format("%.2f", calculatedTiming) .. "s (parry manually to fix)",
                        Duration = 5,
                        Image = "book-open",
                    })
                    
                    -- Clear recent animations after learning to prevent duplicates
                    recentEnemyAnimations = {}
                    recentAnimationsByPlayer = {}
                end
            end
            
            -- Clean up old attempts (older than 1.5s)
            for attemptKey, attemptData in pairs(parryAttempts) do
                if currentTime - attemptData.timestamp > 1.5 then
                    parryAttempts[attemptKey] = nil
                end
            end
        end
        
        lastHealth = newHealth
    end)
end

-- Setup health monitoring when character spawns
LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(1)
    -- Reset health tracking for new life
    lastHealth = 100
    -- Clear stale learning data from previous life
    clearLearningData()
    -- Clear parry attempts from previous life
    parryAttempts = {}
    setupHealthMonitoring()
end)

if LocalPlayer.Character then
    setupHealthMonitoring()
end

-- Track active animations
local activeAnimations = {}

-- Animation detection function - properly connects to each player's humanoid
local function setupAutoparryForPlayer(player)
    if player == LocalPlayer then return end
    
    local function onCharacterAdded(character)
        task.wait(0.5) -- Wait for character to load
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        humanoid.AnimationPlayed:Connect(function(animationTrack)
            local anim = animationTrack.Animation
            local rawAnimId = tostring(anim.AnimationId)
            local cleanId = rawAnimId:gsub("rbxassetid://", "")

            if isBlacklisted(cleanId) then
                return
            end
            
            -- Try to get a meaningful animation name from multiple sources
            local animName = "Unknown"
            
            -- 1. Try AnimationTrack.Name (sometimes has proper names)
            if animationTrack.Name and animationTrack.Name ~= "" and animationTrack.Name ~= "Animation" then
                animName = animationTrack.Name
            -- 2. Try Animation.Name
            elseif anim.Name and anim.Name ~= "" and anim.Name ~= "Animation" then
                animName = anim.Name
            -- 3. Try to get parent folder name (animations are often in named folders)
            elseif anim.Parent and anim.Parent.Name and anim.Parent.Name ~= "Animation" then
                animName = anim.Parent.Name
            -- 4. Fall back to using the ID as name
            else
                animName = "Anim_" .. cleanId
            end
            
            -- Calculate distance
            local distance = math.huge
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local localRoot = LocalPlayer.Character.HumanoidRootPart
                local targetRoot = character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    distance = (localRoot.Position - targetRoot.Position).Magnitude
                end
            end
            
            -- Track this animation for manual parry learning (works even with autoparry off)
            -- Skip looped animations for learning only (not for autoparry)
            if autoLearnEnabled and distance <= 20 and not animationTrack.Looped then
                trackEnemyAnimation(rawAnimId, animName, player.Name, distance, animationTrack)
            end
            
            -- Autoparry logic only runs if enabled
            if not autoparryEnabled then return end
            
            -- Check if this animation is in our autoparry list
            if autoparryAnimations[cleanId] and autoparryAnimations[cleanId].enabled then
                local animData = autoparryAnimations[cleanId]
                local timing = animData.timing or defaultTiming
                
                -- Check if already queued
                local queueKey = cleanId .. "_" .. player.Name
                if activeParryQueue[queueKey] then
                    return
                end
                
                -- Distance/hitbox check
                local shouldParry = false
                local distance = 0
                
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local localRoot = LocalPlayer.Character.HumanoidRootPart
                    local targetRoot = character:FindFirstChild("HumanoidRootPart")
                    
                    if targetRoot then
                        distance = (localRoot.Position - targetRoot.Position).Magnitude
                        
                        -- Calculate combined hitbox size
                        local localSize = localRoot.Size
                        local targetSize = targetRoot.Size
                        
                        -- Get hitbox radius for both characters
                        local localRadius = math.max(localSize.X, localSize.Z) / 2
                        local targetRadius = math.max(targetSize.X, targetSize.Z) / 2
                        
                        -- Account for typical melee attack range (add extra range for weapons/abilities)
                        local attackRange = animData.range or 15 -- Default 15 studs attack range
                        local combinedHitbox = localRadius + targetRadius + attackRange
                        
                        -- Check if hitboxes would overlap
                        if distance <= combinedHitbox then
                            shouldParry = true
                        end
                    end
                end
                
                if shouldParry then
                    -- Refresh ping right before timing for best accuracy
                    local livePing = fetchImmediatePing()
                    if livePing then
                        measuredPing = livePing
                        pingCompensation = getPingCompensation()
                    end

                    -- Apply ping compensation to timing (one-way latency)
                    local compensatedTiming = math.max(0.01, timing - pingCompensation)
                    
                    -- Mark as queued
                    activeParryQueue[queueKey] = true
                    
                    -- Log the detection
                    print("========================================")
                    print("AUTOPARRY TRIGGERED")
                    print("Animation: " .. animData.name)
                    print("ID: " .. cleanId)
                    print("Player: " .. player.Name)
                    print("Distance: " .. math.floor(distance) .. " studs")
                    print("Base Timing: " .. string.format("%.3f", timing) .. "s")
                    print("Ping RTT: " .. string.format("%.0f", measuredPing * 1000) .. "ms")
                    print("Ping Comp (one-way): " .. string.format("%.0f", pingCompensation * 1000) .. "ms")
                    print("Final Timing: " .. string.format("%.3f", compensatedTiming) .. "s")
                    print("========================================")
                    
                    -- Wait for timing with continuous feint checking
                    -- Break the delay into small chunks and check for feints between each
                    task.spawn(function()
                        local waitTime = compensatedTiming
                        local checkInterval = 0.02 -- Check every 20ms
                        local elapsed = 0
                        
                        while elapsed < waitTime do
                            -- Check for feint before each wait
                            if feintedPlayers[player.Name] then
                                activeParryQueue[queueKey] = nil
                                print("[AUTOPARRY] " .. player.Name .. " feinted - parry cancelled (during wait)")
                                return
                            end
                            
                            local sleepTime = math.min(checkInterval, waitTime - elapsed)
                            task.wait(sleepTime)
                            elapsed = elapsed + sleepTime
                        end
                        
                        -- Remove from queue
                        activeParryQueue[queueKey] = nil
                        
                        -- Final feint check right before parry
                        if feintedPlayers[player.Name] then
                            print("[AUTOPARRY] " .. player.Name .. " feinted - parry cancelled")
                            return
                        end
                        
                        -- Final distance check before parrying (player might have moved)
                        local finalDistance = distance
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local localRoot = LocalPlayer.Character.HumanoidRootPart
                            local targetRoot = character:FindFirstChild("HumanoidRootPart")
                            if targetRoot then
                                finalDistance = (localRoot.Position - targetRoot.Position).Magnitude
                            end
                        end
                        
                        -- Only parry if still in range (with some tolerance)
                        if finalDistance > (animData.range or 15) + 10 then
                            print("[AUTOPARRY] Target moved out of range, skipping parry")
                            return
                        end
                        
                        -- Track parry attempt for failure detection (use unique key per player)
                        local attemptKey = cleanId .. "_" .. player.Name
                        parryAttempts[attemptKey] = {
                            timestamp = tick(),
                            animData = animData,
                            playerName = player.Name,
                            distance = math.floor(finalDistance),
                            compensation = pingCompensation,
                            animId = cleanId
                        }
                        
                        -- Execute parry
                        local parrySuccess = pressParryKey()
                        
                        if parrySuccess then
                            -- Smaller notification for successful parry attempts
                            Rayfield:Notify({
                                Title = "Parry: " .. animData.name,
                                Content = player.Name .. " • " .. math.floor(finalDistance) .. " studs",
                                Duration = 1.5,
                                Image = "shield",
                            })
                        end
                        
                        -- Auto-remove from tracking after 1.5s if no damage taken (successful parry)
                        task.delay(1.5, function()
                            if parryAttempts[attemptKey] and tick() - parryAttempts[attemptKey].timestamp >= 1.5 then
                                -- Successful parry - removed from tracking silently
                                parryAttempts[attemptKey] = nil
                            end
                        end)
                    end)
                else
                    -- Animation detected but out of range
                    print("Animation detected but out of range: " .. animData.name .. " (" .. math.floor(distance) .. " studs)")
                end
            end
        end)
    end
    
    -- Connect to existing character
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    -- Connect to future character spawns
    player.CharacterAdded:Connect(onCharacterAdded)
end

-- Setup autoparry for new players that join (connect early so we don't miss anyone)
Players.PlayerAdded:Connect(setupAutoparryForPlayer)

-- Load animations and setup players in background (don't block UI)
task.spawn(function()
    -- Load blacklist first so we don't load blocked animations
    loadBlacklist()
    -- Load animations on startup
    loadAutoparryFromFile()
    pruneBlacklistedAutoparry()
    
    -- Setup autoparry for all existing players
    for _, player in pairs(Players:GetPlayers()) do
        setupAutoparryForPlayer(player)
    end
end)

AutoparryTab:CreateSection("Autoparry Controls")

AutoparryTab:CreateToggle({
   Name = "Enable Autoparry",
   CurrentValue = false,
   Flag = "AutoparryToggle",
   Callback = function(Value)
      autoparryEnabled = Value
      if autoparryEnabled then
          Rayfield:Notify({
              Title = "Autoparry Enabled",
              Content = "Will automatically parry registered animations.",
              Duration = 3,
              Image = "shield",
          })
      else
          Rayfield:Notify({
              Title = "Autoparry Disabled",
              Content = "Autoparry has been disabled.",
              Duration = 3,
              Image = "shield-off",
          })
      end
   end,
})

AutoparryTab:CreateSection("Animation Builder")

local newAnimId = ""
local newAnimName = ""
local newAnimTiming = 0.15

AutoparryTab:CreateInput({
   Name = "Animation ID",
   PlaceholderText = "Enter Roblox Animation ID",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      newAnimId = Text
   end,
})

AutoparryTab:CreateInput({
   Name = "Animation Name",
   PlaceholderText = "Enter a name for this animation",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      newAnimName = Text
   end,
})

AutoparryTab:CreateInput({
   Name = "Parry Timing (seconds)",
   PlaceholderText = "0.15",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      local num = tonumber(Text)
      if num then
          newAnimTiming = num
      end
   end,
})

AutoparryTab:CreateButton({
   Name = "Add Animation to List",
   Callback = function()
      local cleanId = newAnimId:gsub("rbxassetid://", "")
      
      if cleanId == "" or newAnimName == "" then
          Rayfield:Notify({
              Title = "Error",
              Content = "Please enter both Animation ID and Name!",
              Duration = 5,
              Image = "alert-circle",
          })
          return
      end

      if isBlacklisted(cleanId) then
          Rayfield:Notify({
              Title = "Blacklisted",
              Content = "This ID is blacklisted and cannot be added",
              Duration = 4,
              Image = "slash",
          })
          return
      end
      
      autoparryAnimations[cleanId] = {
          name = newAnimName,
          timing = newAnimTiming,
          enabled = true,
          range = 15,
          source = "manual"
      }
      
      -- Auto-submit to global database
      submitLearnedAnimation(cleanId, autoparryAnimations[cleanId], false)
      
      Rayfield:Notify({
          Title = "Animation Added",
          Content = "Added " .. newAnimName .. " (ID: " .. cleanId .. ") with " .. newAnimTiming .. "s timing",
          Duration = 4,
          Image = "check-circle",
      })
      
      -- Save both formats
      saveAutoparryToFile()
      saveAutoparryAsJSON()
   end,
})

AutoparryTab:CreateButton({
   Name = "Add From Last Logged Animation",
   Callback = function()
      if #loggedAnimationsArray == 0 then
          Rayfield:Notify({
              Title = "Error",
              Content = "No animations logged yet!",
              Duration = 5,
              Image = "alert-circle",
          })
          return
      end
      
      local lastAnim = loggedAnimationsArray[#loggedAnimationsArray]

      if isBlacklisted(lastAnim.id) then
          Rayfield:Notify({
              Title = "Blacklisted",
              Content = "Last logged animation is blacklisted",
              Duration = 4,
              Image = "slash",
          })
          return
      end
      
      autoparryAnimations[lastAnim.id] = {
          name = lastAnim.name,
          timing = defaultTiming,
          enabled = true,
          source = "manual"
      }
      
      -- Auto-submit to global database
      submitLearnedAnimation(lastAnim.id, autoparryAnimations[lastAnim.id], false)
      
      Rayfield:Notify({
          Title = "Animation Added",
          Content = "Added " .. lastAnim.name .. " from logger with " .. defaultTiming .. "s timing",
          Duration = 4,
          Image = "check-circle",
      })
      
      -- Save
      saveAutoparryAsJSON()
   end,
})

AutoparryTab:CreateSection("Animation List")

AutoparryTab:CreateButton({
   Name = "View Autoparry Animations",
   Callback = function()
      if next(autoparryAnimations) == nil then
          Rayfield:Notify({
              Title = "Empty List",
              Content = "No animations in autoparry list yet!",
              Duration = 3,
              Image = "info",
          })
          return
      end
      
      print("\n========================================")
      print("AUTOPARRY ANIMATION LIST")
      print("========================================")
      for id, data in pairs(autoparryAnimations) do
          print(string.format(
              "\nName: %s\nID: %s\nTiming: %.2fs\nEnabled: %s",
              data.name,
              id,
              data.timing,
              tostring(data.enabled)
          ))
          print("----------------------------------------")
      end
      print("========================================\n")
      
      Rayfield:Notify({
          Title = "Animation List",
          Content = "Check console (F9) for full list!",
          Duration = 3,
          Image = "list",
      })
   end,
})

AutoparryTab:CreateButton({
   Name = "Clear All Animations",
   Callback = function()
      autoparryAnimations = {}
      saveAutoparryAsJSON()
      Rayfield:Notify({
          Title = "List Cleared",
          Content = "All autoparry animations have been removed.",
          Duration = 3,
          Image = "trash-2",
      })
   end,
})

AutoparryTab:CreateSection("Settings")

AutoparryTab:CreateSlider({
   Name = "Default Parry Timing",
   Range = {0.01, 1.0},
   Increment = 0.01,
   CurrentValue = 0.15,
   Flag = "DefaultTimingSlider",
   Callback = function(Value)
      defaultTiming = Value
   end,
})

AutoparryTab:CreateSlider({
   Name = "Default Attack Range (studs)",
   Range = {5, 50},
   Increment = 1,
   CurrentValue = 15,
   Flag = "DefaultRangeSlider",
   Callback = function(Value)
      -- Update default range for new animations
   end,
})

AutoparryTab:CreateSection("Blacklist (local only)")

local lastBlacklistInput = ""

AutoparryTab:CreateInput({
   Name = "Add Animation ID to Blacklist",
   PlaceholderText = "Enter animation ID (enter to save)",
   RemoveTextAfterFocusLost = true,
   Callback = function(Text)
      lastBlacklistInput = Text or ""
      local ok, idOrErr = addToBlacklist(lastBlacklistInput)
      if ok then
          if autoparryAnimations[idOrErr] then
              autoparryAnimations[idOrErr] = nil
              saveAutoparryAsJSON()
          end
          Rayfield:Notify({
              Title = "Blacklisted",
              Content = "Blocked animation ID " .. idOrErr,
              Duration = 3,
              Image = "slash",
          })
      else
          Rayfield:Notify({
              Title = "Blacklist Error",
              Content = idOrErr,
              Duration = 3,
              Image = "alert-circle",
          })
      end
   end,
})

AutoparryTab:CreateButton({
   Name = "View Blacklist",
   Callback = function()
      if next(autoparryBlacklist) == nil then
          Rayfield:Notify({
              Title = "Blacklist Empty",
              Content = "No animations are currently blocked",
              Duration = 2,
              Image = "info",
          })
          return
      end
      print("\n===== AUTOPARRY BLACKLIST =====")
      for id, _ in pairs(autoparryBlacklist) do
          print(id)
      end
      print("================================\n")
      Rayfield:Notify({
          Title = "Blacklist Printed",
          Content = "Check console (F9) for IDs",
          Duration = 2,
          Image = "list",
      })
   end,
})

AutoparryTab:CreateButton({
   Name = "Clear Blacklist",
   Callback = function()
      autoparryBlacklist = {}
      saveBlacklist()
      pruneBlacklistedAutoparry()
      Rayfield:Notify({
          Title = "Blacklist Cleared",
          Content = "All blocked IDs removed",
          Duration = 2,
          Image = "trash-2",
      })
   end,
})

AutoparryTab:CreateSection("🌐 Global Database")

AutoparryTab:CreateButton({
   Name = "Sync from Global Database",
   Callback = function()
      Rayfield:Notify({
          Title = "Syncing...",
          Content = "Fetching global animations from npoint.io",
          Duration = 2,
          Image = "loader",
      })
      
      task.spawn(function()
          local globalAnims = fetchGlobalAnimations()
          if globalAnims then
              local added, updated = mergeGlobalAnimations(globalAnims)
              Rayfield:Notify({
                  Title = "🌐 Sync Complete",
                  Content = "Added " .. added .. " new, updated " .. updated .. " animations",
                  Duration = 4,
                  Image = "check-circle",
              })
              lastGlobalSync = tick()
          else
              Rayfield:Notify({
                  Title = "Sync Failed",
                  Content = "Could not fetch global database",
                  Duration = 4,
                  Image = "x-circle",
              })
          end
      end)
   end,
})

AutoparryTab:CreateToggle({
   Name = "Auto-submit learned animations",
   CurrentValue = true,
   Flag = "AutoSubmitAnims",
   Callback = function(Value)
      autoSubmitEnabled = Value
      Rayfield:Notify({
          Title = Value and "Auto-Submit Enabled" or "Auto-Submit Disabled",
          Content = Value and "New animations will be submitted" or "Animations won't be submitted",
          Duration = 2,
          Image = Value and "upload" or "upload-off",
      })
   end,
})

AutoparryTab:CreateSection("Debug Info")

AutoparryTab:CreateButton({
   Name = "Show Current Ping",
   Callback = function()
      Rayfield:Notify({
          Title = "Current Ping",
          Content = "Measured: " .. string.format("%.0f", measuredPing * 1000) .. "ms\nCompensation: " .. string.format("%.0f", pingCompensation * 1000) .. "ms",
          Duration = 3,
          Image = "wifi",
      })
   end,
})

AutoparryTab:CreateButton({
   Name = "Test Parry Key",
   Callback = function()
      local success = pressParryKey()
      if success then
          Rayfield:Notify({
              Title = "Parry Test",
              Content = "Parry key pressed successfully!",
              Duration = 2,
              Image = "check-circle",
          })
      else
          Rayfield:Notify({
              Title = "Parry Test Failed",
              Content = "Parry on cooldown or blocked by state",
              Duration = 2,
              Image = "x-circle",
          })
      end
   end,
})

AutoparryTab:CreateParagraph({Title = "How to Use", Content = "1. Enable the animation logger\n2. Watch enemy attacks and note their animations\n3. Add animations to the autoparry list with ID and timing\n4. Enable autoparry toggle\n5. The script will automatically press F when detected animations play"})

AutoparryTab:CreateParagraph({Title = "Timing Tips", Content = "• Lower timing = parry earlier\n• Higher timing = parry later\n• Most M1 attacks: 0.10-0.20s\n• Heavy attacks: 0.30-0.50s\n• Abilities: 0.15-0.40s\n• Script auto-learns from failed parries"})

Rayfield:LoadConfiguration()

