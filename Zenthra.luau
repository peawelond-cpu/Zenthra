
--[[
    AUTO FARM HALLOWEEN
    Candy + Trick or Treat Doors
    Settings UI Edition

    Default Speed: 150
    Search Radius: 5000
    Door Cooldown: 6 seconds
]]

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

--==================================================
-- CONFIGURATION
--==================================================

local Config = {
    Speed = 500,
    MinSpeed = 10,
    MaxSpeed = 500,

    SearchRadius = 2500,

    DoorCooldown = 14,
    DoorWait = 0.6,
    InteractDistance = 4,

    ScanInterval = 0.35,
    RetryDelay = 0.5,

    CollectCandy = true,
    FarmDoors = true,

    CandyFirst = true,
    Highlight = true,

    DoorMode = "Nearest",
}

local CandyKeywords = {
    "candy",
    "candies",
    "sweet",
    "lollipop",
    "chocolate",
    "candycorn",
    "candy_corn",
    "pumpkin_candy",
    "halloween_candy",
}

local DoorKeywords = {
    "trick",
    "treat",
    "halloween",
}

local Theme = {
    BG = Color3.fromRGB(10, 10, 10),
    Surface = Color3.fromRGB(24, 24, 24),
    Border = Color3.fromRGB(55, 55, 55),

    Text = Color3.fromRGB(255, 255, 255),
    Muted = Color3.fromRGB(145, 145, 145),

    Green = Color3.fromRGB(34, 197, 94),
    Red = Color3.fromRGB(239, 68, 68),

    OnBG = Color3.fromRGB(10, 40, 10),
    OffBG = Color3.fromRGB(40, 10, 10),
}

--==================================================
-- STATE
--==================================================

local Enabled = false
local Destroyed = false
local Minimized = false

local FarmThread = nil
local CurrentTween = nil
local MovementConnection = nil

local IgnoredObjects = {}
local GlobalConnections = {}

--==================================================
-- HELPERS
--==================================================

local function track(connection)
    table.insert(GlobalConnections, connection)
    return connection
end

local function getParent()
    local success, result = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
    end)

    if success and result then
        return result
    end

    return Player:WaitForChild("PlayerGui")
end

local function corner(object, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = object
    return c
end

local function stroke(object, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.Parent = object
    return s
end

local function createButton(parent, text, size, position)
    local button = Instance.new("TextButton")

    button.Size = size
    button.Position = position

    button.BackgroundColor3 = Theme.Surface
    button.BorderSizePixel = 0

    button.Text = text
    button.TextColor3 = Theme.Text

    button.Font = Enum.Font.GothamBold
    button.TextSize = 12

    button.AutoButtonColor = true
    button.Parent = parent

    corner(button, 7)
    stroke(button)

    return button
end

local function createLabel(parent, text, size, position)
    local label = Instance.new("TextLabel")

    label.Size = size
    label.Position = position

    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Theme.Text

    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left

    label.Parent = parent

    return label
end

local function setStatus(text, success)
    if not StatusLabel or not StatusLabel.Parent then
        return
    end

    StatusLabel.Text = "Status: " .. text
    StatusLabel.TextColor3 = success and Theme.Green or Theme.Muted
end

--==================================================
-- GUI PARENT
--==================================================

local GuiParent = getParent()

local old = GuiParent:FindFirstChild("AutoFarmGui")

if old then
    old:Destroy()
end

local Gui = Instance.new("ScreenGui")

Gui.Name = "AutoFarmGui"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = GuiParent

--==================================================
-- MAIN WINDOW
--==================================================

local Main = Instance.new("Frame")

Main.Name = "Main"
Main.Size = UDim2.fromOffset(290, 220)
Main.Position = UDim2.new(0.5, -145, 0.08, 0)

Main.BackgroundColor3 = Theme.BG
Main.BorderSizePixel = 0

Main.Active = true
Main.Parent = Gui

corner(Main, 12)
stroke(Main, Theme.Border, 1.5)

local MainTitle = createLabel(
    Main,
    "Auto Farm 🎃",
    UDim2.new(1, -110, 0, 32),
    UDim2.fromOffset(10, 3)
)

MainTitle.Font = Enum.Font.GothamBold
MainTitle.TextSize = 15

local SettingsButton = createButton(
    Main,
    "SETTINGS",
    UDim2.fromOffset(62, 26),
    UDim2.new(1, -98, 0, 6)
)

local MinButton = createButton(
    Main,
    "-",
    UDim2.fromOffset(26, 26),
    UDim2.new(1, -32, 0, 6)
)

local Body = Instance.new("Frame")

Body.Size = UDim2.new(1, -20, 1, -46)
Body.Position = UDim2.fromOffset(10, 42)

Body.BackgroundTransparency = 1
Body.Parent = Main

local FarmButton = createButton(
    Body,
    "AUTO FARM: OFF",
    UDim2.new(1, 0, 0, 38),
    UDim2.fromOffset(0, 0)
)

local StatusLabel = createLabel(
    Body,
    "Status: Idle",
    UDim2.new(1, -4, 0, 16),
    UDim2.fromOffset(2, 44)
)

local SpeedLabel = createLabel(
    Body,
    "Speed: " .. Config.Speed,
    UDim2.new(1, -4, 0, 16),
    UDim2.fromOffset(2, 68)
)

local MinusButton = createButton(
    Body,
    "-",
    UDim2.fromOffset(42, 26),
    UDim2.new(0, 0, 0, 94)
)

local PlusButton = createButton(
    Body,
    "+",
    UDim2.fromOffset(42, 26),
    UDim2.new(1, -42, 0, 94)
)

local RadiusLabel = createLabel(
    Body,
    "Radius: " .. Config.SearchRadius,
    UDim2.new(1, -100, 0, 26),
    UDim2.new(0, 50, 0, 94)
)

RadiusLabel.TextXAlignment = Enum.TextXAlignment.Center

--==================================================
-- DRAGGING
--==================================================

local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart
    local startPosition

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    track(UIS.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - dragStart

            frame.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))
end

makeDraggable(Main, MainTitle)

--==================================================
-- SETTINGS WINDOW
--==================================================

local Settings = Instance.new("Frame")

Settings.Name = "Settings"
Settings.Size = UDim2.fromOffset(310, 455)
Settings.Position = UDim2.new(0.5, -155, 0.5, -227)

Settings.BackgroundColor3 = Theme.BG
Settings.BorderSizePixel = 0

Settings.Active = true
Settings.Visible = false
Settings.Parent = Gui

corner(Settings, 12)
stroke(Settings, Theme.Border, 1.5)

local SettingsTitle = createLabel(
    Settings,
    "⚙ FARM SETTINGS",
    UDim2.new(1, -50, 0, 36),
    UDim2.fromOffset(12, 3)
)

SettingsTitle.Font = Enum.Font.GothamBold
SettingsTitle.TextSize = 14

local CloseSettings = createButton(
    Settings,
    "X",
    UDim2.fromOffset(27, 27),
    UDim2.new(1, -35, 0, 6)
)

makeDraggable(Settings, SettingsTitle)

local SettingsScroll = Instance.new("ScrollingFrame")

SettingsScroll.Size = UDim2.new(1, -16, 1, -52)
SettingsScroll.Position = UDim2.fromOffset(8, 44)

SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0

SettingsScroll.ScrollBarThickness = 3
SettingsScroll.ScrollBarImageColor3 = Theme.Border

SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.None

SettingsScroll.Parent = Settings

local SettingsLayout = Instance.new("UIListLayout")

SettingsLayout.Padding = UDim.new(0, 6)
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder

SettingsLayout.Parent = SettingsScroll

local SettingsPadding = Instance.new("UIPadding")

SettingsPadding.PaddingTop = UDim.new(0, 3)
SettingsPadding.PaddingBottom = UDim.new(0, 8)

SettingsPadding.PaddingLeft = UDim.new(0, 2)
SettingsPadding.PaddingRight = UDim.new(0, 2)

SettingsPadding.Parent = SettingsScroll

SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    SettingsScroll.CanvasSize = UDim2.new(
        0,
        0,
        0,
        SettingsLayout.AbsoluteContentSize.Y + 15
    )
end)

--==================================================
-- SETTINGS ROWS
--==================================================

local function createRow(name)
    local row = Instance.new("Frame")

    row.Size = UDim2.new(1, -4, 0, 42)
    row.BackgroundColor3 = Theme.Surface
    row.BorderSizePixel = 0

    row.Parent = SettingsScroll

    corner(row, 7)

    local label = createLabel(
        row,
        name,
        UDim2.new(0.57, 0, 1, 0),
        UDim2.fromOffset(10, 0)
    )

    label.TextSize = 11

    return row
end

local function addNumberSetting(name, key, minimum, maximum, integer)
    local row = createRow(name)

    local box = Instance.new("TextBox")

    box.Size = UDim2.new(0.36, -5, 0, 28)
    box.Position = UDim2.new(0.62, 0, 0.5, -14)

    box.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    box.BorderSizePixel = 0

    box.TextColor3 = Theme.Text
    box.PlaceholderColor3 = Theme.Muted

    box.Font = Enum.Font.GothamBold
    box.TextSize = 12

    box.ClearTextOnFocus = false
    box.Text = tostring(Config[key])

    box.Parent = row

    corner(box, 6)
    stroke(box, Theme.Border)

    box.FocusLost:Connect(function()
        local value = tonumber(box.Text)

        if value then
            value = math.clamp(value, minimum, maximum)

            if integer then
                value = math.floor(value + 0.5)
            else
                value = math.floor(value * 100 + 0.5) / 100
            end

            Config[key] = value
        end

        box.Text = tostring(Config[key])

        SpeedLabel.Text = "Speed: " .. Config.Speed
        RadiusLabel.Text = "Radius: " .. Config.SearchRadius
    end)
end

local function addToggleSetting(name, key)
    local row = createRow(name)

    local button = createButton(
        row,
        Config[key] and "ON" or "OFF",
        UDim2.new(0.32, 0, 0, 27),
        UDim2.new(0.65, 0, 0.5, -13)
    )

    local function update()
        button.Text = Config[key] and "ON" or "OFF"

        button.BackgroundColor3 = Config[key]
            and Theme.OnBG
            or Theme.OffBG

        local outline = button:FindFirstChildOfClass("UIStroke")

        if outline then
            outline.Color = Config[key]
                and Theme.Green
                or Theme.Red
        end
    end

    update()

    button.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        update()
    end)
end

local function addCycleSetting(name, key, options)
    local row = createRow(name)

    local button = createButton(
        row,
        tostring(Config[key]),
        UDim2.new(0.38, 0, 0, 27),
        UDim2.new(0.59, 0, 0.5, -13)
    )

    button.MouseButton1Click:Connect(function()
        local currentIndex = table.find(options, Config[key]) or 1

        currentIndex += 1

        if currentIndex > #options then
            currentIndex = 1
        end

        Config[key] = options[currentIndex]
        button.Text = tostring(Config[key])
    end)
end

--==================================================
-- BUILD ALL SETTINGS
--==================================================

addNumberSetting(
    "Movement Speed",
    "Speed",
    10,
    500,
    true
)

addNumberSetting(
    "Search Radius",
    "SearchRadius",
    10,
    5000,
    true
)

addNumberSetting(
    "Door Cooldown (sec)",
    "DoorCooldown",
    0,
    60,
    false
)

addNumberSetting(
    "Door Waiting (sec)",
    "DoorWait",
    0,
    10,
    false
)

addNumberSetting(
    "Interact Distance",
    "InteractDistance",
    1,
    20,
    false
)

addNumberSetting(
    "Scan Interval (sec)",
    "ScanInterval",
    0.1,
    5,
    false
)

addNumberSetting(
    "Retry Delay (sec)",
    "RetryDelay",
    0.1,
    10,
    false
)

addToggleSetting(
    "Collect Candy",
    "CollectCandy"
)

addToggleSetting(
    "Farm Doors",
    "FarmDoors"
)

addToggleSetting(
    "Candy Priority",
    "CandyFirst"
)

addToggleSetting(
    "Object Highlight",
    "Highlight"
)

addCycleSetting(
    "Door Target Mode",
    "DoorMode",
    {"Nearest", "Farthest"}
)

--==================================================
-- SETTINGS VISIBILITY
--==================================================

SettingsButton.MouseButton1Click:Connect(function()
    Settings.Visible = not Settings.Visible
end)

CloseSettings.MouseButton1Click:Connect(function()
    Settings.Visible = false
end)

--==================================================
-- CHARACTER
--==================================================

local function getCharacter()
    local character = Player.Character

    if not character then
        return nil, nil, nil
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    return character, root, humanoid
end

--==================================================
-- HIGHLIGHT
--==================================================

local function highlightObject(object)
    if not Config.Highlight or not object or not object.Parent then
        return
    end

    if object:FindFirstChild("HalloweenCham") then
        return
    end

    local highlight = Instance.new("Highlight")

    highlight.Name = "HalloweenCham"
    highlight.Adornee = object

    highlight.FillColor = Config.CandyColor or Color3.fromRGB(255, 100, 0)
    highlight.FillTransparency = 0.4

    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0

    highlight.Parent = object
end

local function clearHighlights()
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Highlight")
            and object.Name == "HalloweenCham" then

            object:Destroy()
        end
    end
end

--==================================================
-- OBJECT HELPERS
--==================================================

local function getPart(object)
    if not object or not object.Parent then
        return nil
    end

    if object:IsA("BasePart") then
        return object
    end

    if object:IsA("Model") then
        return object.PrimaryPart
            or object:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function hasKeyword(text, keywords)
    text = string.lower(text or "")

    for _, keyword in ipairs(keywords) do
        if text:find(keyword, 1, true) then
            return true
        end
    end

    return false
end

local function isIgnored(object)
    if not object then
        return true
    end

    return IgnoredObjects[object] == true
end

--==================================================
-- CANDY SEARCH
--==================================================

local function findCandy()
    if not Config.CollectCandy then
        return nil
    end

    local _, root = getCharacter()

    if not root then
        return nil
    end

    local selected = nil
    local bestDistance = Config.SearchRadius

    for _, object in ipairs(workspace:GetDescendants()) do
        if (object:IsA("BasePart") or object:IsA("Model"))
            and hasKeyword(object.Name, CandyKeywords)
            and not isIgnored(object) then

            local part = getPart(object)

            if part then
                local distance = (root.Position - part.Position).Magnitude

                if distance <= bestDistance then
                    bestDistance = distance
                    selected = object
                end
            end
        end
    end

    return selected
end

--==================================================
-- DOOR SEARCH
--==================================================

local function getPromptPart(prompt)
    local current = prompt.Parent

    while current and current ~= workspace do
        local part = getPart(current)

        if part then
            return part
        end

        current = current.Parent
    end

    return nil
end

local function isDoor(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then
        return false
    end

    local text = (prompt.ObjectText or "")
        .. " "
        .. (prompt.ActionText or "")
        .. " "
        .. prompt.Parent.Name

    return hasKeyword(text, DoorKeywords)
end

local function findDoor()
    if not Config.FarmDoors then
        return nil, nil
    end

    local _, root = getCharacter()

    if not root then
        return nil, nil
    end

    local chosenPart = nil
    local chosenPrompt = nil

    local bestDistance = Config.DoorMode == "Farthest"
        and -math.huge
        or Config.SearchRadius

    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and isDoor(prompt) then
            local part = getPromptPart(prompt)

            if part and not isIgnored(part) then
                local distance = (root.Position - part.Position).Magnitude

                if distance <= Config.SearchRadius then
                    local better = false

                    if Config.DoorMode == "Farthest" then
                        better = distance > bestDistance
                    else
                        better = distance < bestDistance
                    end

                    if better then
                        bestDistance = distance
                        chosenPart = part
                        chosenPrompt = prompt
                    end
                end
            end
        end
    end

    return chosenPart, chosenPrompt
end

--==================================================
-- MOVEMENT
--==================================================

local function cancelMovement()
    if MovementConnection then
        MovementConnection:Disconnect()
        MovementConnection = nil
    end

    if CurrentTween then
        local tween = CurrentTween
        CurrentTween = nil

        pcall(function()
            tween:Cancel()
        end)
    end
end

local function moveTo(target)
    if not Enabled then
        return false
    end

    local character, root, humanoid = getCharacter()

    if not character or not root or not humanoid then
        return false
    end

    if humanoid.Health <= 0 then
        return false
    end

    cancelMovement()

    local distance = (root.Position - target.Position).Magnitude

    if distance <= 1.5 then
        return true
    end

    local duration = math.max(
        distance / math.max(Config.Speed, 1),
        0.05
    )

    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = target}
    )

    CurrentTween = tween

    MovementConnection = RunService.Heartbeat:Connect(function()
        if not Enabled or not root.Parent or humanoid.Health <= 0 then
            cancelMovement()
            return
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    tween:Play()

    local result = tween.Completed:Wait()

    if MovementConnection then
        MovementConnection:Disconnect()
        MovementConnection = nil
    end

    if CurrentTween == tween then
        CurrentTween = nil
    end

    return result == Enum.PlaybackState.Completed and Enabled
end

--==================================================
-- COLLECT CANDY
--==================================================

local function collectCandy(candy)
    if not Enabled or not candy or not candy.Parent then
        return false
    end

    local part = getPart(candy)

    if not part then
        IgnoredObjects[candy] = true
        return false
    end

    highlightObject(candy)

    setStatus("Collecting candy...", true)

    local arrived = moveTo(
        part.CFrame * CFrame.new(0, 1, 0)
    )

    if not arrived or not Enabled then
        return false
    end

    task.wait(0.3)

    if not candy.Parent then
        IgnoredObjects[candy] = true
        return true
    end

    local newPart = getPart(candy)
    local _, root = getCharacter()

    if newPart and root then
        local distance = (root.Position - newPart.Position).Magnitude

        if distance <= 5 then
            -- Avoid repeatedly targeting the same object.
            IgnoredObjects[candy] = true
        end
    end

    return true
end

--==================================================
-- OPEN DOOR
--==================================================

local function interactDoor(part, prompt)
    if not Enabled or not part or not part.Parent then
        return false
    end

    if not prompt or not prompt.Parent or not prompt.Enabled then
        return false
    end

    highlightObject(part)

    setStatus("Going to door...", true)

    local arrived = moveTo(
        part.CFrame * CFrame.new(
            0,
            0,
            Config.InteractDistance
        )
    )

    if not arrived or not Enabled then
        return false
    end

    setStatus("Waiting at door...", true)

    task.wait(Config.DoorWait)

    if not Enabled or not prompt.Parent or not prompt.Enabled then
        return false
    end

    setStatus("Opening door...", true)

    local success = pcall(function()
        if type(fireproximityprompt) == "function" then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()

            task.wait(prompt.HoldDuration + 0.05)

            prompt:InputHoldEnd()
        end
    end)

    if success then
        IgnoredObjects[part] = true
        IgnoredObjects[prompt] = true

        setStatus(
            "Door cooldown: " .. Config.DoorCooldown .. "s",
            true
        )

        task.wait(Config.DoorCooldown)
    end

    return success
end

--==================================================
-- MAIN FARM
--==================================================

local function farmLoop()
    setStatus("Searching...", true)

    while Enabled and not Destroyed do
        local worked = false

        if Config.CandyFirst then
            local candy = findCandy()

            if candy then
                worked = true
                collectCandy(candy)
            end

            if not worked and Enabled then
                local part, prompt = findDoor()

                if part and prompt then
                    worked = true
                    interactDoor(part, prompt)
                end
            end
        else
            local part, prompt = findDoor()

            if part and prompt then
                worked = true
                interactDoor(part, prompt)
            end

            if not worked and Enabled then
                local candy = findCandy()

                if candy then
                    worked = true
                    collectCandy(candy)
                end
            end
        end

        if not worked then
            setStatus("Searching within " .. Config.SearchRadius, false)
            task.wait(Config.RetryDelay)
        else
            task.wait(Config.ScanInterval)
        end
    end

    if not Destroyed then
        setStatus("Stopped", false)
    end
end

--==================================================
-- START
--==================================================

local function startFarm()
    if not Enabled or Destroyed then
        return
    end

    if FarmThread then
        return
    end

    FarmThread = task.spawn(function()
        local success, errorMessage = pcall(farmLoop)

        if not success then
            warn("[AutoFarm] Error:", errorMessage)
            setStatus("Error - see console", false)
        end

        FarmThread = nil
    end)
end

--==================================================
-- STOP
--==================================================

local function stopFarm()
    Enabled = false

    cancelMovement()
    clearHighlights()

    if FarmThread then
        local thread = FarmThread
        FarmThread = nil

        pcall(function()
            task.cancel(thread)
        end)
    end

    setStatus("Off", false)
end

--==================================================
-- MAIN BUTTONS
--==================================================

FarmButton.MouseButton1Click:Connect(function()
    if Destroyed then
        return
    end

    Enabled = not Enabled

    FarmButton.Text = Enabled
        and "AUTO FARM: ON"
        or "AUTO FARM: OFF"

    FarmButton.BackgroundColor3 = Enabled
        and Theme.OnBG
        or Theme.OffBG

    local outline = FarmButton:FindFirstChildOfClass("UIStroke")

    if outline then
        outline.Color = Enabled and Theme.Green or Theme.Red
    end

    if Enabled then
        IgnoredObjects = {}
        startFarm()
    else
        stopFarm()
    end
end)

MinusButton.MouseButton1Click:Connect(function()
    Config.Speed = math.max(
        Config.MinSpeed,
        Config.Speed - 10
    )

    SpeedLabel.Text = "Speed: " .. Config.Speed
end)

PlusButton.MouseButton1Click:Connect(function()
    Config.Speed = math.min(
        Config.MaxSpeed,
        Config.Speed + 50
    )

    SpeedLabel.Text = "Speed: " .. Config.Speed
end)

MinButton.MouseButton1Click:Connect(function()
    Minimized = not Minimized

    Body.Visible = not Minimized

    Main.Size = Minimized
        and UDim2.fromOffset(290, 40)
        or UDim2.fromOffset(290, 220)

    MinButton.Text = Minimized and "+" or "-"
end)

--==================================================
-- RESPAWN
--==================================================

track(Player.CharacterAdded:Connect(function()
    cancelMovement()

    IgnoredObjects = {}

    if Enabled and not Destroyed then
        task.delay(1, function()
            if Enabled and not Destroyed then
                if not FarmThread then
                    startFarm()
                end
            end
        end)
    end
end))

--==================================================
-- CLEANUP
--==================================================

Gui.Destroying:Connect(function()
    Destroyed = true
    Enabled = false

    cancelMovement()
    clearHighlights()

    if FarmThread then
        local thread = FarmThread
        FarmThread = nil

        pcall(function()
            task.cancel(thread)
        end)
    end

    for _, connection in ipairs(GlobalConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(GlobalConnections)
end)

--==================================================
-- LOADED
--==================================================

print("================================")
print("     AUTO FARM HALLOWEEN")
print("================================")
print("Speed:", Config.Speed)
print("Radius:", Config.SearchRadius)
print("Door cooldown:", Config.DoorCooldown)
print("Settings UI: Enabled")
print("================================")
