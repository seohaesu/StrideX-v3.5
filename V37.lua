local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ====== Modern Theme System v3.7 [Extended] ======
local Themes = {
    Dark = {
        MainBg = Color3.fromRGB(18, 18, 24),
        SecondaryBg = Color3.fromRGB(24, 24, 32),
        BoxBg = Color3.fromRGB(28, 28, 36),
        ItemBg = Color3.fromRGB(32, 32, 42),
        Border = Color3.fromRGB(45, 45, 60),
        Accent = Color3.fromRGB(88, 101, 242),
        AccentHover = Color3.fromRGB(108, 121, 255),
        Success = Color3.fromRGB(67, 181, 129),
        Warning = Color3.fromRGB(250, 166, 26),
        Danger = Color3.fromRGB(237, 66, 69),
        TextPrimary = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(142, 146, 166),
        TextMuted = Color3.fromRGB(96, 101, 123)
    },
    Light = {
        MainBg = Color3.fromRGB(255, 255, 255),
        SecondaryBg = Color3.fromRGB(249, 249, 251),
        BoxBg = Color3.fromRGB(245, 245, 248),
        ItemBg = Color3.fromRGB(240, 240, 245),
        Border = Color3.fromRGB(228, 228, 234),
        Accent = Color3.fromRGB(88, 101, 242),
        AccentHover = Color3.fromRGB(108, 121, 255),
        Success = Color3.fromRGB(67, 181, 129),
        Warning = Color3.fromRGB(250, 166, 26),
        Danger = Color3.fromRGB(237, 66, 69),
        TextPrimary = Color3.fromRGB(23, 25, 35),
        TextSecondary = Color3.fromRGB(96, 101, 123),
        TextMuted = Color3.fromRGB(142, 146, 166)
    }
}

local currentTheme = "Dark"
local activeTheme = Themes[currentTheme]

-- ====== File System ======
local SAVE_FILE = "WalkRecorderData.json"
local hasFileAPI = (writefile and readfile and isfile) and true or false

local function safeWrite(data)
    if hasFileAPI then 
        pcall(function()
            writefile(SAVE_FILE, HttpService:JSONEncode(data))
        end)
    end
end

local function safeRead()
    if hasFileAPI and isfile(SAVE_FILE) then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(SAVE_FILE))
        end)
        if ok and decoded then return decoded end
    end
    return {}
end

local savedReplays = safeRead()

-- ====== Enhanced Animation Controller [FIXED SLOPES] ======
local AnimationController = {}
AnimationController.__index = AnimationController

function AnimationController.new(character)
    local self = setmetatable({}, AnimationController)
    self.character = character
    self.humanoid = character:WaitForChild("Humanoid")
    self.currentState = "Idle"
    self.targetCFrame = nil
    self.lerpAlpha = 0.25
    self.previousVelocity = Vector3.new()
    self.stateBuffer = {}
    self.bufferSize = 5
    return self
end

function AnimationController:smoothMoveTo(targetCF, velocity)
    if not self.character or not self.character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local hrp = self.character.HumanoidRootPart
    
    local smoothedVelocity = self.previousVelocity:Lerp(velocity, 0.3)
    self.previousVelocity = smoothedVelocity
    
    hrp.CFrame = hrp.CFrame:Lerp(targetCF, self.lerpAlpha)
    hrp.AssemblyLinearVelocity = smoothedVelocity
end

function AnimationController:applyState(state)
    table.insert(self.stateBuffer, state)
    if #self.stateBuffer > self.bufferSize then
        table.remove(self.stateBuffer, 1)
    end
    
    local stateCount = {}
    for _, s in ipairs(self.stateBuffer) do
        stateCount[s] = (stateCount[s] or 0) + 1
    end
    
    local dominantState = state
    local maxCount = 0
    for s, count in pairs(stateCount) do
        if count > maxCount then
            maxCount = count
            dominantState = s
        end
    end
    
    if self.currentState == dominantState or not self.humanoid then return end
    
    self.currentState = dominantState
    
    if dominantState == "Idle" then
        self.humanoid.WalkSpeed = 0
        self.humanoid:ChangeState(Enum.HumanoidStateType.Running)
        
    elseif dominantState == "Walking" then
        self.humanoid.WalkSpeed = 16
        self.humanoid:ChangeState(Enum.HumanoidStateType.Running)
        
    elseif dominantState == "Running" then
        self.humanoid.WalkSpeed = 24
        self.humanoid:ChangeState(Enum.HumanoidStateType.Running)
        
    elseif dominantState == "Jumping" then
        self.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        
    elseif dominantState == "Falling" then
        self.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        
    elseif dominantState == "Climbing" then
        self.humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
    end
end

function AnimationController:detectState(velocity)
    local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
    local verticalSpeed = velocity.Y
    
    if verticalSpeed > 18 then
        return "Jumping"
    elseif verticalSpeed < -18 then
        return "Falling"
    elseif horizontalSpeed > 20 then
        return "Running"
    elseif horizontalSpeed > 2 then
        return "Walking"
    else
        return "Idle"
    end
end

function AnimationController:stopAll()
    self.currentState = "Idle"
    self.targetCFrame = nil
    self.stateBuffer = {}
    self.previousVelocity = Vector3.new()
    if self.humanoid then
        self.humanoid.WalkSpeed = 16
        self.humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
end

function AnimationController:cleanup()
    self:stopAll()
end

-- ====== UI Helper Functions ======
local function addCorner(parent, radius)
    local corner = Instance.new("UICorner", parent)
    corner.CornerRadius = UDim.new(0, radius or 12)
    return corner
end

local function addStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke", parent)
    stroke.Color = color or activeTheme.Border
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Transparency = 0
    return stroke
end

local function createModernButton(parent, text, emoji, size, position, color)
    local button = Instance.new("TextButton", parent)
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color or activeTheme.Accent
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = ""
    button.AutoButtonColor = false
    
    addCorner(button, 10)
    
    local emojiLabel = nil
    if emoji then
        emojiLabel = Instance.new("TextLabel", button)
        emojiLabel.Size = UDim2.new(0, 20, 0, 20)
        emojiLabel.Position = UDim2.new(0, 10, 0.5, -10)
        emojiLabel.BackgroundTransparency = 1
        emojiLabel.Text = emoji
        emojiLabel.Font = Enum.Font.GothamBold
        emojiLabel.TextSize = 16
        emojiLabel.TextColor3 = Color3.new(1, 1, 1)
    end
    
    local label = Instance.new("TextLabel", button)
    label.Size = UDim2.new(1, emoji and -36 or -20, 1, 0)
    label.Position = UDim2.new(0, emoji and 32 or 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Color3.fromRGB(
                math.min((color or activeTheme.Accent).R * 255 + 15, 255) / 255,
                math.min((color or activeTheme.Accent).G * 255 + 15, 255) / 255,
                math.min((color or activeTheme.Accent).B * 255 + 15, 255) / 255
            )
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = color or activeTheme.Accent
        }):Play()
    end)
    
    return button, emojiLabel, label
end

-- ====== Modern Rename Dialog ======
local screenGui
local function createRenameDialog(currentName, callback)
    local dialogBg = Instance.new("Frame", screenGui)
    dialogBg.Size = UDim2.new(1, 0, 1, 0)
    dialogBg.Position = UDim2.new(0, 0, 0, 0)
    dialogBg.BackgroundColor3 = Color3.new(0, 0, 0)
    dialogBg.BackgroundTransparency = 0.6
    dialogBg.BorderSizePixel = 0
    dialogBg.ZIndex = 100
    
    local dialog = Instance.new("Frame", dialogBg)
    dialog.Size = UDim2.new(0, 0, 0, 0)
    dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
    dialog.AnchorPoint = Vector2.new(0.5, 0.5)
    dialog.BackgroundColor3 = activeTheme.MainBg
    dialog.BorderSizePixel = 0
    dialog.ZIndex = 101
    
    addCorner(dialog, 16)
    addStroke(dialog, activeTheme.Border, 1)
    
    TweenService:Create(dialog, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 400, 0, 180)
    }):Play()
    
    local titleLabel = Instance.new("TextLabel", dialog)
    titleLabel.Size = UDim2.new(1, -32, 0, 24)
    titleLabel.Position = UDim2.new(0, 16, 0, 16)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Rename Replay"
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextColor3 = activeTheme.TextPrimary
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 102
    
    local inputContainer = Instance.new("Frame", dialog)
    inputContainer.Size = UDim2.new(1, -32, 0, 48)
    inputContainer.Position = UDim2.new(0, 16, 0, 56)
    inputContainer.BackgroundColor3 = activeTheme.BoxBg
    inputContainer.BorderSizePixel = 0
    inputContainer.ZIndex = 102
    
    addCorner(inputContainer, 10)
    local inputStroke = addStroke(inputContainer, activeTheme.Border, 1)
    
    local inputBox = Instance.new("TextBox", inputContainer)
    inputBox.Size = UDim2.new(1, -20, 1, -4)
    inputBox.Position = UDim2.new(0, 10, 0, 2)
    inputBox.BackgroundTransparency = 1
    inputBox.Text = currentName
    inputBox.Font = Enum.Font.GothamMedium
    inputBox.TextSize = 14
    inputBox.TextColor3 = activeTheme.TextPrimary
    inputBox.PlaceholderText = "Enter replay name..."
    inputBox.PlaceholderColor3 = activeTheme.TextMuted
    inputBox.ClearTextOnFocus = false
    inputBox.ZIndex = 103
    
    inputBox.Focused:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.2), {
            Color = activeTheme.Accent,
            Thickness = 2
        }):Play()
    end)
    
    inputBox.FocusLost:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.2), {
            Color = activeTheme.Border,
            Thickness = 1
        }):Play()
    end)
    
    local buttonContainer = Instance.new("Frame", dialog)
    buttonContainer.Size = UDim2.new(1, -32, 0, 44)
    buttonContainer.Position = UDim2.new(0, 16, 1, -60)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.ZIndex = 102
    
    local cancelBtn = Instance.new("TextButton", buttonContainer)
    cancelBtn.Size = UDim2.new(0.48, 0, 1, 0)
    cancelBtn.Position = UDim2.new(0, 0, 0, 0)
    cancelBtn.BackgroundColor3 = activeTheme.ItemBg
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = "Cancel"
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 13
    cancelBtn.TextColor3 = activeTheme.TextPrimary
    cancelBtn.ZIndex = 103
    
    addCorner(cancelBtn, 10)
    
    local saveBtn = Instance.new("TextButton", buttonContainer)
    saveBtn.Size = UDim2.new(0.48, 0, 1, 0)
    saveBtn.Position = UDim2.new(0.52, 0, 0, 0)
    saveBtn.BackgroundColor3 = activeTheme.Accent
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "Save"
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 13
    saveBtn.TextColor3 = Color3.new(1, 1, 1)
    saveBtn.ZIndex = 103
    
    addCorner(saveBtn, 10)
    
    cancelBtn.MouseEnter:Connect(function()
        TweenService:Create(cancelBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = activeTheme.BoxBg
        }):Play()
    end)
    
    cancelBtn.MouseLeave:Connect(function()
        TweenService:Create(cancelBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = activeTheme.ItemBg
        }):Play()
    end)
    
    saveBtn.MouseEnter:Connect(function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = activeTheme.AccentHover
        }):Play()
    end)
    
    saveBtn.MouseLeave:Connect(function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = activeTheme.Accent
        }):Play()
    end)
    
    saveBtn.MouseButton1Click:Connect(function()
        local newName = inputBox.Text
        if newName and newName ~= "" and newName ~= currentName then
            callback(newName)
        end
        TweenService:Create(dialog, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        task.wait(0.2)
        dialogBg:Destroy()
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        TweenService:Create(dialog, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        task.wait(0.2)
        dialogBg:Destroy()
    end)
    
    task.wait(0.1)
    inputBox:CaptureFocus()
    
    return dialogBg
end

-- ====== Main UI Setup [REDESIGNED SQUARE LAYOUT] ======
local guiName = "AutoWalkRecorderPro"
local oldGui = playerGui:FindFirstChild(guiName)
if oldGui then oldGui:Destroy() end

screenGui = Instance.new("ScreenGui")
screenGui.Name = guiName
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainPanel = Instance.new("Frame", screenGui)
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 380, 0, 540)
mainPanel.Position = UDim2.new(0.5, -190, 0.5, -270)
mainPanel.BackgroundColor3 = activeTheme.MainBg
mainPanel.BorderSizePixel = 0
mainPanel.Active = true
mainPanel.Draggable = true
mainPanel.ClipsDescendants = true

addCorner(mainPanel, 16)
addStroke(mainPanel, activeTheme.Border, 1)

local contentContainer = Instance.new("Frame", mainPanel)
contentContainer.Name = "ContentContainer"
contentContainer.Size = UDim2.new(1, 0, 1, 0)
contentContainer.Position = UDim2.new(0, 0, 0, 0)
contentContainer.BackgroundTransparency = 1
contentContainer.BorderSizePixel = 0

local header = Instance.new("Frame", mainPanel)
header.Size = UDim2.new(1, 0, 0, 54)
header.BackgroundColor3 = activeTheme.SecondaryBg
header.BorderSizePixel = 0
header.ZIndex = 2

addCorner(header, 16)

local statusIndicator = Instance.new("Frame", header)
statusIndicator.Size = UDim2.new(0, 10, 0, 10)
statusIndicator.Position = UDim2.new(0, 10, 0.5, -5)
statusIndicator.BackgroundColor3 = activeTheme.Success
statusIndicator.BorderSizePixel = 0

addCorner(statusIndicator, 5)

task.spawn(function()
    while true do
        TweenService:Create(statusIndicator, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
            BackgroundTransparency = 0.7
        }):Play()
        task.wait(0.8)
        TweenService:Create(statusIndicator, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
            BackgroundTransparency = 0
        }):Play()
        task.wait(0.8)
    end
end)

local titleLabel = Instance.new("TextLabel", header)
titleLabel.Size = UDim2.new(1, -160, 0, 20)
titleLabel.Position = UDim2.new(0, 24, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "StrideX System - hyunwo"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.TextColor3 = activeTheme.TextPrimary
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local subtitleLabel = Instance.new("TextLabel", header)
subtitleLabel.Size = UDim2.new(1, -160, 0, 12)
subtitleLabel.Position = UDim2.new(0, 24, 0, 30)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "v3.7 Extended - Slope Fix & Normal Speed"
subtitleLabel.Font = Enum.Font.GothamMedium
subtitleLabel.TextSize = 9
subtitleLabel.TextColor3 = activeTheme.TextMuted
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local themeBtn = Instance.new("TextButton", header)
themeBtn.Size = UDim2.new(0, 30, 0, 30)
themeBtn.Position = UDim2.new(1, -104, 0.5, -15)
themeBtn.BackgroundColor3 = activeTheme.BoxBg
themeBtn.Text = "🌙"
themeBtn.Font = Enum.Font.GothamBold
themeBtn.TextSize = 16
themeBtn.BorderSizePixel = 0

addCorner(themeBtn, 10)

local minimizeBtn = Instance.new("TextButton", header)
minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
minimizeBtn.Position = UDim2.new(1, -70, 0.5, -15)
minimizeBtn.BackgroundColor3 = activeTheme.BoxBg
minimizeBtn.Text = "─"
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.TextColor3 = activeTheme.TextPrimary
minimizeBtn.BorderSizePixel = 0

addCorner(minimizeBtn, 10)

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -36, 0.5, -15)
closeBtn.BackgroundColor3 = activeTheme.Danger
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BorderSizePixel = 0

addCorner(closeBtn, 10)

local statusBox = Instance.new("Frame", contentContainer)
statusBox.Size = UDim2.new(1, -24, 0, 62)
statusBox.Position = UDim2.new(0, 12, 0, 66)
statusBox.BackgroundColor3 = activeTheme.BoxBg
statusBox.BorderSizePixel = 0

addCorner(statusBox, 12)

local statusIconBg = Instance.new("Frame", statusBox)
statusIconBg.Size = UDim2.new(0, 40, 0, 40)
statusIconBg.Position = UDim2.new(0, 11, 0.5, -20)
statusIconBg.BackgroundColor3 = activeTheme.Accent
statusIconBg.BorderSizePixel = 0

addCorner(statusIconBg, 10)

local statusIcon = Instance.new("TextLabel", statusIconBg)
statusIcon.Size = UDim2.new(1, 0, 1, 0)
statusIcon.BackgroundTransparency = 1
statusIcon.Text = "▶️"
statusIcon.Font = Enum.Font.GothamBold
statusIcon.TextSize = 20
statusIcon.TextColor3 = Color3.new(1, 1, 1)

local statusTitle = Instance.new("TextLabel", statusBox)
statusTitle.Size = UDim2.new(1, -64, 0, 18)
statusTitle.Position = UDim2.new(0, 58, 0, 11)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "Ready"
statusTitle.Font = Enum.Font.GothamBold
statusTitle.TextSize = 13
statusTitle.TextColor3 = activeTheme.TextPrimary
statusTitle.TextXAlignment = Enum.TextXAlignment.Left

local statusDesc = Instance.new("TextLabel", statusBox)
statusDesc.Size = UDim2.new(1, -64, 0, 14)
statusDesc.Position = UDim2.new(0, 58, 0, 33)
statusDesc.BackgroundTransparency = 1
statusDesc.Text = "Animation: Idle • Frames: 0"
statusDesc.Font = Enum.Font.GothamMedium
statusDesc.TextSize = 10
statusDesc.TextColor3 = activeTheme.TextSecondary
statusDesc.TextXAlignment = Enum.TextXAlignment.Left

local recordBox = Instance.new("Frame", contentContainer)
recordBox.Size = UDim2.new(1, -24, 0, 88)
recordBox.Position = UDim2.new(0, 12, 0, 140)
recordBox.BackgroundColor3 = activeTheme.BoxBg
recordBox.BorderSizePixel = 0

addCorner(recordBox, 12)

local recordTitle = Instance.new("TextLabel", recordBox)
recordTitle.Size = UDim2.new(1, -16, 0, 16)
recordTitle.Position = UDim2.new(0, 8, 0, 8)
recordTitle.BackgroundTransparency = 1
recordTitle.Text = "Recording"
recordTitle.Font = Enum.Font.GothamBold
recordTitle.TextSize = 11
recordTitle.TextColor3 = activeTheme.TextMuted
recordTitle.TextXAlignment = Enum.TextXAlignment.Left

local recordBtn, recordEmoji, recordLabel = createModernButton(recordBox, "Record", "⏺️", UDim2.new(0, 168, 0, 40), UDim2.new(0, 8, 0, 38), activeTheme.Danger)
local saveBtn, saveEmoji, saveLabel = createModernButton(recordBox, "Save", "💾", UDim2.new(0, 168, 0, 40), UDim2.new(1, -176, 0, 38), activeTheme.Success)

local playbackBox = Instance.new("Frame", contentContainer)
playbackBox.Size = UDim2.new(1, -24, 0, 88)
playbackBox.Position = UDim2.new(0, 12, 0, 240)
playbackBox.BackgroundColor3 = activeTheme.BoxBg
playbackBox.BorderSizePixel = 0

addCorner(playbackBox, 12)

local playbackTitle = Instance.new("TextLabel", playbackBox)
playbackTitle.Size = UDim2.new(1, -16, 0, 16)
playbackTitle.Position = UDim2.new(0, 8, 0, 8)
playbackTitle.BackgroundTransparency = 1
playbackTitle.Text = "Playback"
playbackTitle.Font = Enum.Font.GothamBold
playbackTitle.TextSize = 11
playbackTitle.TextColor3 = activeTheme.TextMuted
playbackTitle.TextXAlignment = Enum.TextXAlignment.Left

local loadBtn, loadEmoji, loadLabel = createModernButton(playbackBox, "Load", "📂", UDim2.new(0, 168, 0, 40), UDim2.new(0, 8, 0, 38), activeTheme.Accent)
local queueBtn, queueEmoji, queueLabel = createModernButton(playbackBox, "Queue", "📋", UDim2.new(0, 168, 0, 40), UDim2.new(1, -176, 0, 38), Color3.fromRGB(138, 100, 220))

local replayBox = Instance.new("Frame", contentContainer)
replayBox.Size = UDim2.new(1, -24, 0, 166)
replayBox.Position = UDim2.new(0, 12, 0, 340)
replayBox.BackgroundColor3 = activeTheme.BoxBg
replayBox.BorderSizePixel = 0

addCorner(replayBox, 12)

local replayTitle = Instance.new("TextLabel", replayBox)
replayTitle.Size = UDim2.new(1, -16, 0, 16)
replayTitle.Position = UDim2.new(0, 8, 0, 8)
replayTitle.BackgroundTransparency = 1
replayTitle.Text = "Saved Replays"
replayTitle.Font = Enum.Font.GothamBold
replayTitle.TextSize = 11
replayTitle.TextColor3 = activeTheme.TextMuted
replayTitle.TextXAlignment = Enum.TextXAlignment.Left

local replayScroll = Instance.new("ScrollingFrame", replayBox)
replayScroll.Size = UDim2.new(1, -16, 1, -32)
replayScroll.Position = UDim2.new(0, 8, 0, 28)
replayScroll.BackgroundTransparency = 1
replayScroll.BorderSizePixel = 0
replayScroll.ScrollBarThickness = 4
replayScroll.ScrollBarImageColor3 = activeTheme.Border
replayScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local replayLayout = Instance.new("UIListLayout", replayScroll)
replayLayout.SortOrder = Enum.SortOrder.LayoutOrder
replayLayout.Padding = UDim.new(0, 4)

replayLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    replayScroll.CanvasSize = UDim2.new(0, 0, 0, replayLayout.AbsoluteContentSize.Y + 4)
end)

local copyrightLabel = Instance.new("TextLabel", contentContainer)
copyrightLabel.Size = UDim2.new(1, 0, 0, 18)
copyrightLabel.Position = UDim2.new(0, 0, 1, -18)
copyrightLabel.BackgroundTransparency = 1
copyrightLabel.Text = "© Hunwo 2025 • v3.7 Extended"
copyrightLabel.Font = Enum.Font.GothamMedium
copyrightLabel.TextSize = 9
copyrightLabel.TextColor3 = activeTheme.TextMuted
copyrightLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ====== Theme Toggle Function ======
local function applyTheme()
    activeTheme = Themes[currentTheme]
    
    mainPanel.BackgroundColor3 = activeTheme.MainBg
    header.BackgroundColor3 = activeTheme.SecondaryBg
    titleLabel.TextColor3 = activeTheme.TextPrimary
    subtitleLabel.TextColor3 = activeTheme.TextMuted
    
    statusBox.BackgroundColor3 = activeTheme.BoxBg
    statusTitle.TextColor3 = activeTheme.TextPrimary
    statusDesc.TextColor3 = activeTheme.TextSecondary
    statusIconBg.BackgroundColor3 = activeTheme.Accent
    
    recordBox.BackgroundColor3 = activeTheme.BoxBg
    recordTitle.TextColor3 = activeTheme.TextMuted
    
    playbackBox.BackgroundColor3 = activeTheme.BoxBg
    playbackTitle.TextColor3 = activeTheme.TextMuted
    
    replayBox.BackgroundColor3 = activeTheme.BoxBg
    replayTitle.TextColor3 = activeTheme.TextMuted
    replayScroll.ScrollBarImageColor3 = activeTheme.Border
    
    copyrightLabel.TextColor3 = activeTheme.TextMuted
    
    themeBtn.BackgroundColor3 = activeTheme.BoxBg
    themeBtn.Text = currentTheme == "Dark" and "🌙" or "☀️"
    minimizeBtn.BackgroundColor3 = activeTheme.BoxBg
    minimizeBtn.TextColor3 = activeTheme.TextPrimary
    
    for _, item in ipairs(replayScroll:GetChildren()) do
        if item:IsA("Frame") then
            item.BackgroundColor3 = activeTheme.ItemBg
        end
    end
end

themeBtn.MouseButton1Click:Connect(function()
    currentTheme = currentTheme == "Dark" and "Light" or "Dark"
    applyTheme()
    refreshReplayList()
end)

themeBtn.MouseEnter:Connect(function()
    TweenService:Create(themeBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = activeTheme.ItemBg
    }):Play()
end)

themeBtn.MouseLeave:Connect(function()
    TweenService:Create(themeBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = activeTheme.BoxBg
    }):Play()
end)

minimizeBtn.MouseEnter:Connect(function()
    TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = activeTheme.ItemBg
    }):Play()
end)

minimizeBtn.MouseLeave:Connect(function()
    TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = activeTheme.BoxBg
    }):Play()
end)

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = Color3.fromRGB(255, 80, 90)
    }):Play()
end)

closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {
        BackgroundColor3 = activeTheme.Danger
    }):Play()
end)

local isMinimized = false
local originalSize = mainPanel.Size

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    
    if isMinimized then
        TweenService:Create(mainPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Size = UDim2.new(0, 380, 0, 54)
        }):Play()
        
        TweenService:Create(contentContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Position = UDim2.new(0, 0, 0, -500)
        }):Play()
    else
        TweenService:Create(mainPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Size = originalSize
        }):Play()
        
        TweenService:Create(contentContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(mainPanel, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    task.wait(0.2)
    screenGui:Destroy()
end)

-- ====== Logic Variables ======
local character, humanoidRootPart, animController
local isRecording, isPaused = false, false
local recordData = {}
local currentReplayToken = nil
local autoQueueRunning = false
local frameCount = 0
local recordingConnection = nil

-- ====== Character Setup ======
local function onCharacterAdded(char)
    character = char
    humanoidRootPart = char:WaitForChild("HumanoidRootPart", 10)
    
    if animController then
        animController:cleanup()
    end
    
    if character:FindFirstChild("Humanoid") then
        animController = AnimationController.new(character)
    end
    
    if isRecording then
        stopRecording()
    end
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then 
    task.spawn(function()
        onCharacterAdded(player.Character)
    end)
end

-- ====== Status Updates ======
local function updateStatus(state, animation, frames)
    statusTitle.Text = state or "Ready"
    statusDesc.Text = string.format("Animation: %s • Frames: %d", animation or "Idle", frames or 0)
    
    local emojiMap = {
        Idle = "▶️",
        Walking = "🚶",
        Running = "🏃",
        Jumping = "⬆️",
        Falling = "⬇️",
        Climbing = "🧗"
    }
    
    statusIcon.Text = emojiMap[animation] or "▶️"
    
    local colorMap = {
        Recording = activeTheme.Danger,
        Playing = activeTheme.Accent,
        Paused = activeTheme.Warning,
        Ready = activeTheme.Success
    }
    
    local color = colorMap[state] or activeTheme.Accent
    TweenService:Create(statusIconBg, TweenInfo.new(0.3), {BackgroundColor3 = color}):Play()
end

-- ====== Recording System [OPTIMIZED] ======
local function startRecording()
    if not humanoidRootPart or not humanoidRootPart.Parent then
        warn("⚠️ Cannot start recording: Character not found")
        return
    end
    
    recordData = {}
    frameCount = 0
    isRecording = true
    
    recordLabel.Text = "Stop"
    if recordEmoji then recordEmoji.Text = "⏹️" end
    recordBtn.BackgroundColor3 = activeTheme.Warning
    updateStatus("Recording", "Idle", 0)
    
    if recordingConnection then
        recordingConnection:Disconnect()
        recordingConnection = nil
    end
    
    local lastRecordTime = tick()
    local recordInterval = 1/60
    
    recordingConnection = RunService.Heartbeat:Connect(function()
        if not isRecording then return end
        
        local currentTime = tick()
        if currentTime - lastRecordTime < recordInterval then
            return
        end
        lastRecordTime = currentTime
        
        if humanoidRootPart and humanoidRootPart.Parent and character and character.Parent then
            local cf = humanoidRootPart.CFrame
            local velocity = humanoidRootPart.AssemblyLinearVelocity
            local state = "Idle"
            
            if animController then
                state = animController:detectState(velocity)
            end
            
            table.insert(recordData, {
                Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                Velocity = {velocity.X, velocity.Y, velocity.Z},
                State = state
            })
            
            frameCount = #recordData
            if frameCount % 15 == 0 then
                updateStatus("Recording", state, frameCount)
            end
        else
            stopRecording()
        end
    end)
end

local function stopRecording()
    isRecording = false
    
    if recordingConnection then
        recordingConnection:Disconnect()
        recordingConnection = nil
    end
    
    recordLabel.Text = "Record"
    if recordEmoji then recordEmoji.Text = "⏺️" end
    recordBtn.BackgroundColor3 = activeTheme.Danger
    updateStatus("Ready", "Idle", frameCount)
end

-- ====== Smooth Playback System [FIXED - ALL NORMAL SPEED] ======
local function playReplay(data)
    if not humanoidRootPart or not humanoidRootPart.Parent then
        warn("⚠️ Cannot play replay: Character not found")
        return
    end
    
    local token = {}
    currentReplayToken = token
    isPaused = false
    
    task.spawn(function()
        local index, totalFrames = 1, #data
        local lastState = nil
        
        while index <= totalFrames do
            if currentReplayToken ~= token then break end
            
            while isPaused and currentReplayToken == token do
                if animController then animController:stopAll() end
                updateStatus("Paused", "Idle", math.floor(index))
                task.wait(0.05)
            end
            
            if humanoidRootPart and humanoidRootPart.Parent and character and character.Parent and currentReplayToken == token then
                local frame = data[math.floor(index)]
                if not frame then break end
                
                local targetPos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
                local lookVec = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
                local upVec = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
                local velocity = Vector3.new(frame.Velocity[1], frame.Velocity[2], frame.Velocity[3])
                
                local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookVec, upVec)
                
                pcall(function()
                    if animController then
                        animController:smoothMoveTo(targetCFrame, velocity)
                    else
                        humanoidRootPart.CFrame = targetCFrame
                        humanoidRootPart.AssemblyLinearVelocity = velocity
                    end
                end)
                
                if frame.State and frame.State ~= lastState then
                    if animController then
                        animController:applyState(frame.State)
                    end
                    lastState = frame.State
                end
                
                if index % 5 == 0 then
                    updateStatus("Playing", frame.State or "Idle", math.floor(index))
                end
            else
                break
            end
            
            index = index + 1
            task.wait()
        end
        
        if animController then animController:stopAll() end
        if currentReplayToken == token then
            currentReplayToken = nil
            updateStatus("Ready", "Idle", totalFrames)
        end
    end)
end

-- ====== Auto Queue System ======
local function playQueue()
    if autoQueueRunning then
        autoQueueRunning = false
        queueLabel.Text = "Queue"
        if queueEmoji then queueEmoji.Text = "📋" end
        queueBtn.BackgroundColor3 = Color3.fromRGB(138, 100, 220)
        updateStatus("Ready", "Idle", 0)
        return
    end
    
    autoQueueRunning = true
    queueLabel.Text = "Stop"
    if queueEmoji then queueEmoji.Text = "⏹️" end
    queueBtn.BackgroundColor3 = activeTheme.Warning
    
    task.spawn(function()
        while autoQueueRunning do
            local queue = {}
            for _, r in ipairs(savedReplays) do
                if r.Selected then
                    table.insert(queue, r.Frames)
                end
            end
            
            if #queue == 0 then
                autoQueueRunning = false
                queueLabel.Text = "Queue"
                if queueEmoji then queueEmoji.Text = "📋" end
                queueBtn.BackgroundColor3 = Color3.fromRGB(138, 100, 220)
                updateStatus("Ready", "Idle", 0)
                return
            end
            
            for i, frames in ipairs(queue) do
                if not autoQueueRunning then break end
                
                playReplay(frames)
                
                while currentReplayToken do
                    task.wait(0.1)
                end
                task.wait(0.5)
            end
            
            if character and character:FindFirstChild("Humanoid") then
                character.Humanoid.Health = 0
            end
            player.CharacterAdded:Wait()
            onCharacterAdded(player.Character)
            task.wait(1)
        end
    end)
end

-- ====== Modern Replay List Item ======
function createReplayItem(saved, index)
    local item = Instance.new("Frame", replayScroll)
    item.Size = UDim2.new(1, 0, 0, 46)
    item.BackgroundColor3 = activeTheme.ItemBg
    item.BorderSizePixel = 0
    item.LayoutOrder = index
    
    addCorner(item, 10)
    
    local checkbox = Instance.new("TextButton", item)
    checkbox.Size = UDim2.new(0, 20, 0, 20)
    checkbox.Position = UDim2.new(0, 8, 0.5, -10)
    checkbox.BackgroundColor3 = saved.Selected and activeTheme.Success or activeTheme.BoxBg
    checkbox.BorderSizePixel = 0
    checkbox.Text = saved.Selected and "✓" or ""
    checkbox.Font = Enum.Font.GothamBold
    checkbox.TextSize = 13
    checkbox.TextColor3 = Color3.new(1, 1, 1)
    
    addCorner(checkbox, 6)
    addStroke(checkbox, saved.Selected and activeTheme.Success or activeTheme.Border, 2)
    
    checkbox.MouseButton1Click:Connect(function()
        saved.Selected = not saved.Selected
        checkbox.Text = saved.Selected and "✓" or ""
        TweenService:Create(checkbox, TweenInfo.new(0.2), {
            BackgroundColor3 = saved.Selected and activeTheme.Success or activeTheme.BoxBg
        }):Play()
        local stroke = checkbox:FindFirstChildOfClass("UIStroke")
        if stroke then
            TweenService:Create(stroke, TweenInfo.new(0.2), {
                Color = saved.Selected and activeTheme.Success or activeTheme.Border
            }):Play()
        end
        safeWrite(savedReplays)
    end)
    
    local nameLabel = Instance.new("TextLabel", item)
    nameLabel.Size = UDim2.new(0, 100, 0, 16)
    nameLabel.Position = UDim2.new(0, 34, 0, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = saved.Name
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 10
    nameLabel.TextColor3 = activeTheme.TextPrimary
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    local infoLabel = Instance.new("TextLabel", item)
    infoLabel.Size = UDim2.new(0, 100, 0, 12)
    infoLabel.Position = UDim2.new(0, 34, 0, 26)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = string.format("%d frames • ~%ds", #saved.Frames, math.floor(#saved.Frames / 60))
    infoLabel.Font = Enum.Font.GothamMedium
    infoLabel.TextSize = 8
    infoLabel.TextColor3 = activeTheme.TextSecondary
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local function createEmojiBtn(emoji, pos, color, callback)
        local btn = Instance.new("TextButton", item)
        btn.Size = UDim2.new(0, 28, 0, 28)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.BorderSizePixel = 0
        btn.Text = emoji
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.TextColor3 = Color3.new(1, 1, 1)
        
        addCorner(btn, 8)
        
        btn.MouseButton1Click:Connect(callback)
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(
                    math.min(color.R * 255 + 15, 255) / 255,
                    math.min(color.G * 255 + 15, 255) / 255,
                    math.min(color.B * 255 + 15, 255) / 255
                )
            }):Play()
        end)
        
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = color
            }):Play()
        end)
        
        return btn
    end
    
    createEmojiBtn("▶️", UDim2.new(0, 148, 0.5, -14), activeTheme.Accent, function()
        playReplay(saved.Frames)
    end)
    
    createEmojiBtn("⏸️", UDim2.new(0, 182, 0.5, -14), activeTheme.Warning, function()
        isPaused = not isPaused
    end)
    
    createEmojiBtn("✏️", UDim2.new(0, 216, 0.5, -14), Color3.fromRGB(138, 100, 220), function()
        createRenameDialog(saved.Name, function(newName)
            saved.Name = newName
            nameLabel.Text = newName
            safeWrite(savedReplays)
        end)
    end)
    
    createEmojiBtn("🗑️", UDim2.new(0, 250, 0.5, -14), activeTheme.Danger, function()
        TweenService:Create(item, TweenInfo.new(0.3), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1
        }):Play()
        task.wait(0.3)
        table.remove(savedReplays, index)
        refreshReplayList()
        safeWrite(savedReplays)
    end)
    
    local upBtn = createEmojiBtn("⬆️", UDim2.new(0, 284, 0, 6), activeTheme.BoxBg, function()
        if index > 1 then
            savedReplays[index], savedReplays[index - 1] = savedReplays[index - 1], savedReplays[index]
            refreshReplayList()
            safeWrite(savedReplays)
        end
    end)
    upBtn.Size = UDim2.new(0, 28, 0, 14)
    upBtn.TextSize = 9
    
    local downBtn = createEmojiBtn("⬇️", UDim2.new(0, 284, 1, -20), activeTheme.BoxBg, function()
        if index < #savedReplays then
            savedReplays[index], savedReplays[index + 1] = savedReplays[index + 1], savedReplays[index]
            refreshReplayList()
            safeWrite(savedReplays)
        end
    end)
    downBtn.Size = UDim2.new(0, 28, 0, 14)
    downBtn.TextSize = 9
end

function refreshReplayList()
    for _, c in ipairs(replayScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    for i, r in ipairs(savedReplays) do
        createReplayItem(r, i)
    end
end

refreshReplayList()

-- ====== Button Connections ======
recordBtn.MouseButton1Click:Connect(function()
    if isRecording then
        stopRecording()
    else
        startRecording()
    end
end)

saveBtn.MouseButton1Click:Connect(function()
    if #recordData > 0 then
        local timestamp = os.date("%H:%M:%S")
        createRenameDialog("Replay " .. timestamp, function(newName)
            table.insert(savedReplays, {
                Name = newName,
                Frames = recordData,
                Selected = false
            })
            refreshReplayList()
            safeWrite(savedReplays)
            recordData = {}
            frameCount = 0
            stopRecording()
            updateStatus("Ready", "Idle", 0)
        end)
    end
end)

loadBtn.MouseButton1Click:Connect(function()
    savedReplays = safeRead()
    refreshReplayList()
    updateStatus("Ready", "Idle", 0)
end)

queueBtn.MouseButton1Click:Connect(playQueue)

-- ====== Cleanup ======
screenGui.Destroying:Connect(function()
    if recordingConnection then
        recordingConnection:Disconnect()
    end
    if animController then 
        animController:cleanup() 
    end
    if currentReplayToken then 
        currentReplayToken = nil 
    end
    autoQueueRunning = false
    isRecording = false
end)

-- ====== Startup Message ======
print("╔═══════════════════════════════════════════╗")
print("║  AUTO WALK RECORDER PRO v3.7 Extended    ║")
print("║        Slope Fix Edition by hyunwo       ║")
print("╚═══════════════════════════════════════════╝")
print("")
print("✨ FIXED: Smooth animations on slopes/hills")
print("✨ FIXED: All playback at normal speed (1x)")
print("✨ OPTIMIZED: Square UI layout")
print("✨ ENHANCED: Better state buffering")
print("✨ ENHANCED: Improved velocity smoothing")
print("")
print("🎮 Features:")
print("   • Smooth slope detection")
print("   • State transition buffering")
print("   • Velocity interpolation")
print("   • Normal speed playback only")
print("")
print("💡 All animations play at recorded speed!")
