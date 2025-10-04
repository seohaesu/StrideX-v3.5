local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ====== Modern Theme System v5.0 ======
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
local SAVE_FILE = "WalkRecorderData_v50.json"
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

-- ====== Full Body Recording System v5.0 ======
local BodyRecorder = {}
BodyRecorder.__index = BodyRecorder

function BodyRecorder.new(character)
    local self = setmetatable({}, BodyRecorder)
    self.character = character
    self.motors = {}
    self.originalC0s = {}
    self.smoothBuffers = {}
    
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            local motorName = descendant.Name
            self.motors[motorName] = descendant
            self.originalC0s[motorName] = descendant.C0
            self.smoothBuffers[motorName] = {}
        end
    end
    
    return self
end

function BodyRecorder:captureFrame()
    local frame = {
        Motors = {}
    }
    
    for name, motor in pairs(self.motors) do
        if motor and motor.Parent then
            local c0 = motor.C0
            local c1 = motor.C1
            frame.Motors[name] = {
                C0 = {c0:GetComponents()},
                C1 = {c1:GetComponents()}
            }
        end
    end
    
    return frame
end

function BodyRecorder:applyFrame(frame, smoothness)
    smoothness = smoothness or 0.4
    
    for name, data in pairs(frame.Motors) do
        local motor = self.motors[name]
        if motor and motor.Parent then
            local c0Components = data.C0
            local c1Components = data.C1
            
            if c0Components and #c0Components == 12 then
                local targetC0 = CFrame.new(unpack(c0Components))
                
                table.insert(self.smoothBuffers[name], targetC0)
                if #self.smoothBuffers[name] > 3 then
                    table.remove(self.smoothBuffers[name], 1)
                end
                
                local avgC0 = targetC0
                if #self.smoothBuffers[name] > 1 then
                    local sumPos = Vector3.new()
                    local rotations = {}
                    for _, cf in ipairs(self.smoothBuffers[name]) do
                        sumPos = sumPos + cf.Position
                        table.insert(rotations, cf.Rotation)
                    end
                    local avgPos = sumPos / #self.smoothBuffers[name]
                    avgC0 = CFrame.new(avgPos) * rotations[#rotations]
                end
                
                motor.C0 = motor.C0:Lerp(avgC0, smoothness)
            end
            
            if c1Components and #c1Components == 12 then
                local targetC1 = CFrame.new(unpack(c1Components))
                motor.C1 = motor.C1:Lerp(targetC1, smoothness)
            end
        end
    end
end

function BodyRecorder:reset()
    for name, motor in pairs(self.motors) do
        if motor and motor.Parent and self.originalC0s[name] then
            motor.C0 = self.originalC0s[name]
        end
    end
    self.smoothBuffers = {}
    for name in pairs(self.motors) do
        self.smoothBuffers[name] = {}
    end
end

function BodyRecorder:cleanup()
    self:reset()
    self.motors = {}
    self.originalC0s = {}
    self.smoothBuffers = {}
end

-- ====== UNIVERSAL Jump Detector v5.0 ======
local JumpDetector = {}
JumpDetector.__index = JumpDetector

function JumpDetector.new(character)
    local self = setmetatable({}, JumpDetector)
    self.character = character
    self.humanoid = character:WaitForChild("Humanoid")
    self.humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Jump detection data
    self.wasGrounded = true
    self.isJumping = false
    self.isFalling = false
    self.jumpStartTime = 0
    self.jumpStartHeight = 0
    self.lastGroundedTime = 0
    self.maxJumpDuration = 1.2
    self.minJumpHeight = 3
    self.lastHeight = 0
    self.heightBuffer = {}
    self.bufferSize = 5
    self.groundCheckRay = 5
    
    -- Humanoid state tracking
    self.lastState = nil
    self.stateChangeTime = 0
    
    return self
end

function JumpDetector:isOnGround()
    if not self.humanoidRootPart or not self.humanoidRootPart.Parent then
        return false
    end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {self.character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local result = workspace:Raycast(
        self.humanoidRootPart.Position,
        Vector3.new(0, -self.groundCheckRay, 0),
        rayParams
    )
    
    return result ~= nil
end

function JumpDetector:detectJumpState(velocity)
    local currentTime = tick()
    local currentHeight = self.humanoidRootPart.Position.Y
    local isGrounded = self:isOnGround()
    local verticalVel = velocity.Y
    
    -- Update height buffer
    table.insert(self.heightBuffer, currentHeight)
    if #self.heightBuffer > self.bufferSize then
        table.remove(self.heightBuffer, 1)
    end
    
    -- Calculate height change
    local heightChange = 0
    if #self.heightBuffer >= 2 then
        heightChange = self.heightBuffer[#self.heightBuffer] - self.heightBuffer[1]
    end
    
    -- Detect jump START (transition from grounded to airborne with upward motion)
    if self.wasGrounded and not isGrounded then
        -- Check if we have upward velocity OR significant upward height change
        if verticalVel > 5 or heightChange > 0.5 then
            self.isJumping = true
            self.isFalling = false
            self.jumpStartTime = currentTime
            self.jumpStartHeight = currentHeight
            self.lastGroundedTime = currentTime
        end
    end
    
    -- Maintain jump state during ascent
    if self.isJumping then
        local jumpDuration = currentTime - self.jumpStartTime
        local totalHeightGained = currentHeight - self.jumpStartHeight
        
        -- Stay in jump state while:
        -- 1. Still going up (positive velocity or increasing height)
        -- 2. Haven't exceeded max jump duration
        -- 3. Not grounded yet
        if jumpDuration < self.maxJumpDuration and not isGrounded then
            -- If velocity becomes negative but we're still high up, continue jump
            if verticalVel > -10 or (totalHeightGained > self.minJumpHeight and jumpDuration < 0.6) then
                self.isFalling = false
            else
                -- Transition to falling
                self.isJumping = false
                self.isFalling = true
            end
        else
            -- Jump ended
            self.isJumping = false
            if not isGrounded then
                self.isFalling = true
            else
                self.isFalling = false
            end
        end
    end
    
    -- Detect pure falling (no jump before)
    if not self.isJumping and not isGrounded and verticalVel < -15 then
        local timeSinceGrounded = currentTime - self.lastGroundedTime
        if timeSinceGrounded > 0.3 then -- Only consider falling if been airborne for a bit
            self.isFalling = true
        end
    end
    
    -- Reset states when grounded
    if isGrounded then
        if not self.wasGrounded then
            self.lastGroundedTime = currentTime
        end
        self.isJumping = false
        self.isFalling = false
    end
    
    self.wasGrounded = isGrounded
    self.lastHeight = currentHeight
    
    -- Return appropriate state
    if self.isJumping then
        return "Jumping"
    elseif self.isFalling then
        return "Falling"
    end
    
    return nil
end

function JumpDetector:reset()
    self.wasGrounded = true
    self.isJumping = false
    self.isFalling = false
    self.jumpStartTime = 0
    self.jumpStartHeight = 0
    self.lastGroundedTime = 0
    self.heightBuffer = {}
end

function JumpDetector:cleanup()
    self:reset()
end

-- ====== Enhanced Animation Controller v5.0 ======
local AnimationController = {}
AnimationController.__index = AnimationController

function AnimationController.new(character)
    local self = setmetatable({}, AnimationController)
    self.character = character
    self.humanoid = character:WaitForChild("Humanoid")
    self.jumpDetector = JumpDetector.new(character)
    self.currentState = "Idle"
    self.targetCFrame = nil
    self.lerpAlpha = 0.35
    self.previousVelocity = Vector3.new()
    self.stateBuffer = {}
    self.bufferSize = 5
    self.positionBuffer = {}
    self.positionBufferSize = 3
    return self
end

function AnimationController:smoothMoveTo(targetCF, velocity)
    if not self.character or not self.character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local hrp = self.character.HumanoidRootPart
    local smoothedVelocity = self.previousVelocity:Lerp(velocity, 0.45)
    self.previousVelocity = smoothedVelocity
    
    table.insert(self.positionBuffer, targetCF)
    if #self.positionBuffer > self.positionBufferSize then
        table.remove(self.positionBuffer, 1)
    end
    
    local avgPosition = targetCF.Position
    local avgLookVector = targetCF.LookVector
    if #self.positionBuffer > 1 then
        local sumPos = Vector3.new()
        local sumLook = Vector3.new()
        for _, cf in ipairs(self.positionBuffer) do
            sumPos = sumPos + cf.Position
            sumLook = sumLook + cf.LookVector
        end
        avgPosition = sumPos / #self.positionBuffer
        avgLookVector = (sumLook / #self.positionBuffer).Unit
    end
    
    local smoothCF = CFrame.lookAt(avgPosition, avgPosition + avgLookVector)
    hrp.CFrame = hrp.CFrame:Lerp(smoothCF, self.lerpAlpha)
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
    elseif dominantState == "Walking" then
        self.humanoid.WalkSpeed = 16
    elseif dominantState == "Running" then
        self.humanoid.WalkSpeed = 24
    elseif dominantState == "Jumping" then
        self.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    elseif dominantState == "Falling" then
        self.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    end
end

function AnimationController:detectState(velocity)
    -- First check for jump/fall using the universal detector
    local jumpState = self.jumpDetector:detectJumpState(velocity)
    if jumpState then
        return jumpState
    end
    
    -- Then check horizontal movement
    local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude
    
    if horizontalSpeed > 20 then
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
    self.positionBuffer = {}
    self.previousVelocity = Vector3.new()
    if self.jumpDetector then
        self.jumpDetector:reset()
    end
    if self.humanoid then
        self.humanoid.WalkSpeed = 16
    end
end

function AnimationController:cleanup()
    self:stopAll()
    if self.jumpDetector then
        self.jumpDetector:cleanup()
    end
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

-- ====== Speed Input Box ======
local currentSpeed = 1
local speedInputBox, speedInputStroke

local function createSpeedInput(parent)
    local inputContainer = Instance.new("Frame", parent)
    inputContainer.Size = UDim2.new(1, -16, 0, 64)
    inputContainer.Position = UDim2.new(0, 8, 0, 192)
    inputContainer.BackgroundTransparency = 1
    inputContainer.ZIndex = 11
    
    local speedLabel = Instance.new("TextLabel", inputContainer)
    speedLabel.Size = UDim2.new(1, 0, 0, 16)
    speedLabel.Position = UDim2.new(0, 0, 0, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Playback Speed"
    speedLabel.Font = Enum.Font.GothamBold
    speedLabel.TextSize = 11
    speedLabel.TextColor3 = activeTheme.TextMuted
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.TextYAlignment = Enum.TextYAlignment.Top
    speedLabel.ZIndex = 12
    
    local inputBox = Instance.new("Frame", inputContainer)
    inputBox.Size = UDim2.new(1, 0, 0, 36)
    inputBox.Position = UDim2.new(0, 0, 0, 20)
    inputBox.BackgroundColor3 = activeTheme.BoxBg
    inputBox.BorderSizePixel = 0
    inputBox.ZIndex = 12
    
    addCorner(inputBox, 8)
    speedInputStroke = addStroke(inputBox, activeTheme.Border, 1)
    
    speedInputBox = Instance.new("TextBox", inputBox)
    speedInputBox.Size = UDim2.new(1, -20, 1, 0)
    speedInputBox.Position = UDim2.new(0, 10, 0, 0)
    speedInputBox.BackgroundTransparency = 1
    speedInputBox.Text = tostring(currentSpeed)
    speedInputBox.Font = Enum.Font.GothamMedium
    speedInputBox.TextSize = 11
    speedInputBox.TextColor3 = activeTheme.TextPrimary
    speedInputBox.PlaceholderText = "0.1 - 5.0"
    speedInputBox.PlaceholderColor3 = activeTheme.TextMuted
    speedInputBox.TextXAlignment = Enum.TextXAlignment.Left
    speedInputBox.ClearTextOnFocus = false
    speedInputBox.ZIndex = 13
    
    local hintLabel = Instance.new("TextLabel", inputContainer)
    hintLabel.Size = UDim2.new(1, 0, 0, 12)
    hintLabel.Position = UDim2.new(0, 0, 0, 58)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Text = "Range: 0.1x - 5.0x"
    hintLabel.Font = Enum.Font.GothamMedium
    hintLabel.TextSize = 8
    hintLabel.TextColor3 = activeTheme.TextMuted
    hintLabel.TextXAlignment = Enum.TextXAlignment.Left
    hintLabel.ZIndex = 12
    
    speedInputBox.Focused:Connect(function()
        TweenService:Create(speedInputStroke, TweenInfo.new(0.2), {
            Color = activeTheme.Accent,
            Thickness = 2
        }):Play()
    end)
    
    speedInputBox.FocusLost:Connect(function(enterPressed)
        TweenService:Create(speedInputStroke, TweenInfo.new(0.2), {
            Color = activeTheme.Border,
            Thickness = 1
        }):Play()
        
        local inputText = speedInputBox.Text
        local speedValue = tonumber(inputText)
        
        if speedValue then
            speedValue = math.clamp(speedValue, 0.1, 5.0)
            currentSpeed = speedValue
            speedInputBox.Text = string.format("%.2f", speedValue)
            
            TweenService:Create(speedInputStroke, TweenInfo.new(0.3), {
                Color = activeTheme.Success
            }):Play()
            task.wait(0.5)
            TweenService:Create(speedInputStroke, TweenInfo.new(0.3), {
                Color = activeTheme.Border
            }):Play()
        else
            speedInputBox.Text = string.format("%.2f", currentSpeed)
            
            TweenService:Create(speedInputStroke, TweenInfo.new(0.3), {
                Color = activeTheme.Danger
            }):Play()
            task.wait(0.5)
            TweenService:Create(speedInputStroke, TweenInfo.new(0.3), {
                Color = activeTheme.Border
            }):Play()
        end
    end)
    
    speedInputBox.MouseEnter:Connect(function()
        if not speedInputBox:IsFocused() then
            TweenService:Create(inputBox, TweenInfo.new(0.2), {
                BackgroundColor3 = activeTheme.ItemBg
            }):Play()
        end
    end)
    
    speedInputBox.MouseLeave:Connect(function()
        if not speedInputBox:IsFocused() then
            TweenService:Create(inputBox, TweenInfo.new(0.2), {
                BackgroundColor3 = activeTheme.BoxBg
            }):Play()
        end
    end)
    
    return inputContainer
end

-- ====== Main UI Setup [v5.0] ======
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
mainPanel.Size = UDim2.new(0, 380, 0, 500)
mainPanel.Position = UDim2.new(0.5, -190, 0.5, -250)
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
    while mainPanel.Parent do
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
titleLabel.Text = "StrideX System v5.0"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.TextColor3 = activeTheme.TextPrimary
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local subtitleLabel = Instance.new("TextLabel", header)
subtitleLabel.Size = UDim2.new(1, -160, 0, 12)
subtitleLabel.Position = UDim2.new(0, 24, 0, 30)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "Universal Jump Detection"
subtitleLabel.Font = Enum.Font.GothamMedium
subtitleLabel.TextSize = 9
subtitleLabel.TextColor3 = activeTheme.TextMuted
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local themeBtn = Instance.new("TextButton", header)
themeBtn.Size = UDim2.new(0, 30, 0, 30)
themeBtn.Position = UDim2.new(1, -104, 0.5, -15)
themeBtn.BackgroundColor3 = activeTheme.BoxBg
themeBtn.Text = currentTheme == "Dark" and "🌙" or "☀️"
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

local minimizedBtn = Instance.new("TextButton", screenGui)
minimizedBtn.Size = UDim2.new(0, 60, 0, 60)
minimizedBtn.Position = UDim2.new(0.5, -30, 0.5, -30)
minimizedBtn.BackgroundColor3 = activeTheme.Accent
minimizedBtn.BorderSizePixel = 0
minimizedBtn.Text = "S"
minimizedBtn.Font = Enum.Font.GothamBold
minimizedBtn.TextSize = 28
minimizedBtn.Visible = false
minimizedBtn.ZIndex = 50
minimizedBtn.Active = true
minimizedBtn.Draggable = true

addCorner(minimizedBtn, 30)
addStroke(minimizedBtn, activeTheme.Border, 2)

local controlBox = Instance.new("Frame", contentContainer)
controlBox.Size = UDim2.new(1, -24, 0, 320)
controlBox.Position = UDim2.new(0, 12, 0, 66)
controlBox.BackgroundColor3 = activeTheme.BoxBg
controlBox.BorderSizePixel = 0
controlBox.ZIndex = 10

addCorner(controlBox, 12)

local statusIconBg = Instance.new("Frame", controlBox)
statusIconBg.Size = UDim2.new(0, 40, 0, 40)
statusIconBg.Position = UDim2.new(0, 11, 0, 11)
statusIconBg.BackgroundColor3 = activeTheme.Accent
statusIconBg.BorderSizePixel = 0
statusIconBg.ZIndex = 11

addCorner(statusIconBg, 10)

local statusIcon = Instance.new("TextLabel", statusIconBg)
statusIcon.Size = UDim2.new(1, 0, 1, 0)
statusIcon.BackgroundTransparency = 1
statusIcon.Text = "▶️"
statusIcon.Font = Enum.Font.GothamBold
statusIcon.TextSize = 20
statusIcon.TextColor3 = Color3.new(1, 1, 1)
statusIcon.ZIndex = 12

local statusTitle = Instance.new("TextLabel", controlBox)
statusTitle.Size = UDim2.new(1, -64, 0, 18)
statusTitle.Position = UDim2.new(0, 58, 0, 14)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "Ready"
statusTitle.Font = Enum.Font.GothamBold
statusTitle.TextSize = 13
statusTitle.TextColor3 = activeTheme.TextPrimary
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.ZIndex = 11

local statusDesc = Instance.new("TextLabel", controlBox)
statusDesc.Size = UDim2.new(1, -64, 0, 14)
statusDesc.Position = UDim2.new(0, 58, 0, 34)
statusDesc.BackgroundTransparency = 1
statusDesc.Text = "Universal Jump Detection • Frames: 0"
statusDesc.Font = Enum.Font.GothamMedium
statusDesc.TextSize = 10
statusDesc.TextColor3 = activeTheme.TextSecondary
statusDesc.TextXAlignment = Enum.TextXAlignment.Left
statusDesc.ZIndex = 11

local separator1 = Instance.new("Frame", controlBox)
separator1.Size = UDim2.new(1, -16, 0, 1)
separator1.Position = UDim2.new(0, 8, 0, 64)
separator1.BackgroundColor3 = activeTheme.Border
separator1.BorderSizePixel = 0
separator1.ZIndex = 11

local controlTitle = Instance.new("TextLabel", controlBox)
controlTitle.Size = UDim2.new(1, -16, 0, 16)
controlTitle.Position = UDim2.new(0, 8, 0, 74)
controlTitle.BackgroundTransparency = 1
controlTitle.Text = "Controls"
controlTitle.Font = Enum.Font.GothamBold
controlTitle.TextSize = 11
controlTitle.TextColor3 = activeTheme.TextMuted
controlTitle.TextXAlignment = Enum.TextXAlignment.Left
controlTitle.ZIndex = 11

local recordBtn, recordEmoji, recordLabel = createModernButton(controlBox, "Record", "⏺️", UDim2.new(0.48, -4, 0, 36), UDim2.new(0, 8, 0, 96), activeTheme.Danger)
recordBtn.ZIndex = 11
if recordEmoji then recordEmoji.ZIndex = 12 end
recordLabel.ZIndex = 12

local saveBtn, saveEmoji, saveLabel = createModernButton(controlBox, "Save", "💾", UDim2.new(0.48, -4, 0, 36), UDim2.new(0.52, 4, 0, 96), activeTheme.Success)
saveBtn.ZIndex = 11
if saveEmoji then saveEmoji.ZIndex = 12 end
saveLabel.ZIndex = 12

local loadBtn, loadEmoji, loadLabel = createModernButton(controlBox, "Load", "📂", UDim2.new(0.48, -4, 0, 36), UDim2.new(0, 8, 0, 138), activeTheme.Accent)
loadBtn.ZIndex = 11
if loadEmoji then loadEmoji.ZIndex = 12 end
loadLabel.ZIndex = 12

local queueBtn, queueEmoji, queueLabel = createModernButton(controlBox, "Queue", "📋", UDim2.new(0.48, -4, 0, 36), UDim2.new(0.52, 4, 0, 138), Color3.fromRGB(138, 100, 220))
queueBtn.ZIndex = 11
if queueEmoji then queueEmoji.ZIndex = 12 end
queueLabel.ZIndex = 12

local separator2 = Instance.new("Frame", controlBox)
separator2.Size = UDim2.new(1, -16, 0, 1)
separator2.Position = UDim2.new(0, 8, 0, 186)
separator2.BackgroundColor3 = activeTheme.Border
separator2.BorderSizePixel = 0
separator2.ZIndex = 11

local speedInput = createSpeedInput(controlBox)

local replayBox = Instance.new("Frame", contentContainer)
replayBox.Size = UDim2.new(1, -24, 0, 90)
replayBox.Position = UDim2.new(0, 12, 0, 398)
replayBox.BackgroundColor3 = activeTheme.BoxBg
replayBox.BorderSizePixel = 0
replayBox.ZIndex = 10

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
replayTitle.ZIndex = 11

local replayScroll = Instance.new("ScrollingFrame", replayBox)
replayScroll.Size = UDim2.new(1, -16, 1, -32)
replayScroll.Position = UDim2.new(0, 8, 0, 28)
replayScroll.BackgroundTransparency = 1
replayScroll.BorderSizePixel = 0
replayScroll.ScrollBarThickness = 4
replayScroll.ScrollBarImageColor3 = activeTheme.Border
replayScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
replayScroll.ZIndex = 11

local replayLayout = Instance.new("UIListLayout", replayScroll)
replayLayout.SortOrder = Enum.SortOrder.LayoutOrder
replayLayout.Padding = UDim.new(0, 4)

replayLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    replayScroll.CanvasSize = UDim2.new(0, 0, 0, replayLayout.AbsoluteContentSize.Y + 4)
end)

local copyrightLabel = Instance.new("TextLabel", contentContainer)
copyrightLabel.Size = UDim2.new(1, 0, 0, 12)
copyrightLabel.Position = UDim2.new(0, 0, 1, -12)
copyrightLabel.BackgroundTransparency = 1
copyrightLabel.Text = "© Hunwo 2025 • v5.0 Universal Jump"
copyrightLabel.Font = Enum.Font.GothamMedium
copyrightLabel.TextSize = 8
copyrightLabel.TextColor3 = activeTheme.TextMuted
copyrightLabel.TextXAlignment = Enum.TextXAlignment.Center
copyrightLabel.ZIndex = 11

local function applyTheme()
    activeTheme = Themes[currentTheme]
    mainPanel.BackgroundColor3 = activeTheme.MainBg
    header.BackgroundColor3 = activeTheme.SecondaryBg
    titleLabel.TextColor3 = activeTheme.TextPrimary
    subtitleLabel.TextColor3 = activeTheme.TextMuted
    controlBox.BackgroundColor3 = activeTheme.BoxBg
    statusTitle.TextColor3 = activeTheme.TextPrimary
    statusDesc.TextColor3 = activeTheme.TextSecondary
    statusIconBg.BackgroundColor3 = activeTheme.Accent
    controlTitle.TextColor3 = activeTheme.TextMuted
    separator1.BackgroundColor3 = activeTheme.Border
    separator2.BackgroundColor3 = activeTheme.Border
    replayBox.BackgroundColor3 = activeTheme.BoxBg
    replayTitle.TextColor3 = activeTheme.TextMuted
    replayScroll.ScrollBarImageColor3 = activeTheme.Border
    copyrightLabel.TextColor3 = activeTheme.TextMuted
    themeBtn.BackgroundColor3 = activeTheme.BoxBg
    themeBtn.Text = currentTheme == "Dark" and "🌙" or "☀️"
    minimizeBtn.BackgroundColor3 = activeTheme.BoxBg
    minimizeBtn.TextColor3 = activeTheme.TextPrimary
    minimizedBtn.BackgroundColor3 = activeTheme.Accent
    
    if speedInputBox then
        speedInputBox.TextColor3 = activeTheme.TextPrimary
        speedInputBox.PlaceholderColor3 = activeTheme.TextMuted
        if speedInputStroke then
            speedInputStroke.Color = activeTheme.Border
        end
    end
    
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
    TweenService:Create(themeBtn, TweenInfo.new(0.2), {BackgroundColor3 = activeTheme.ItemBg}):Play()
end)

themeBtn.MouseLeave:Connect(function()
    TweenService:Create(themeBtn, TweenInfo.new(0.2), {BackgroundColor3 = activeTheme.BoxBg}):Play()
end)

minimizeBtn.MouseEnter:Connect(function()
    TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {BackgroundColor3 = activeTheme.ItemBg}):Play()
end)

minimizeBtn.MouseLeave:Connect(function()
    TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {BackgroundColor3 = activeTheme.BoxBg}):Play()
end)

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 80, 90)}):Play()
end)

closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = activeTheme.Danger}):Play()
end)

local isMinimized = false
local originalSize = mainPanel.Size
local originalPosition = mainPanel.Position

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    
    if isMinimized then
        local targetPos = UDim2.new(0.5, -30, 0.5, -30)
        TweenService:Create(mainPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = targetPos,
            BackgroundTransparency = 1
        }):Play()
        TweenService:Create(contentContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(0, 0, 0, -500)
        }):Play()
        task.wait(0.4)
        mainPanel.Visible = false
        minimizedBtn.Visible = true
        minimizedBtn.Size = UDim2.new(0, 0, 0, 0)
        minimizedBtn.BackgroundTransparency = 0
        TweenService:Create(minimizedBtn, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 60, 0, 60)
        }):Play()
    else
        TweenService:Create(minimizedBtn, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        task.wait(0.3)
        minimizedBtn.Visible = false
        mainPanel.Visible = true
        mainPanel.Size = UDim2.new(0, 0, 0, 0)
        mainPanel.BackgroundTransparency = 1
        TweenService:Create(mainPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = originalSize,
            Position = originalPosition,
            BackgroundTransparency = 0
        }):Play()
        TweenService:Create(contentContainer, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
    end
end)

minimizedBtn.MouseButton1Click:Connect(function()
    isMinimized = false
    TweenService:Create(minimizedBtn, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    task.wait(0.3)
    minimizedBtn.Visible = false
    mainPanel.Visible = true
    mainPanel.Size = UDim2.new(0, 0, 0, 0)
    mainPanel.BackgroundTransparency = 1
    TweenService:Create(mainPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = originalSize,
        Position = originalPosition,
        BackgroundTransparency = 0
    }):Play()
    TweenService:Create(contentContainer, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
end)

minimizedBtn.MouseEnter:Connect(function()
    TweenService:Create(minimizedBtn, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 70, 0, 70),
        BackgroundColor3 = activeTheme.AccentHover
    }):Play()
end)

minimizedBtn.MouseLeave:Connect(function()
    TweenService:Create(minimizedBtn, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 60, 0, 60),
        BackgroundColor3 = activeTheme.Accent
    }):Play()
end)

closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(mainPanel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
    task.wait(0.3)
    screenGui:Destroy()
end)

-- ====== Logic Variables ======
local character, humanoidRootPart, animController, bodyRecorder
local isRecording, isPaused = false, false
local recordData = {}
local currentReplayToken = nil
local autoQueueRunning = false
local frameCount = 0
local recordingConnection = nil

local function onCharacterAdded(char)
    character = char
    humanoidRootPart = char:WaitForChild("HumanoidRootPart", 10)
    
    if animController then
        animController:cleanup()
    end
    if bodyRecorder then
        bodyRecorder:cleanup()
    end
    
    if character:FindFirstChild("Humanoid") then
        animController = AnimationController.new(character)
        bodyRecorder = BodyRecorder.new(character)
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

local function updateStatus(state, animation, frames)
    statusTitle.Text = state or "Ready"
    statusDesc.Text = string.format("Universal Jump Detection • Frames: %d", frames or 0)
    
    local emojiMap = {
        Idle = "▶️",
        Walking = "🚶",
        Running = "🏃",
        Jumping = "⬆️",
        Falling = "⬇️"
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

-- ====== Recording System with Animation Tracking ======
local function startRecording()
    if not humanoidRootPart or not humanoidRootPart.Parent or not bodyRecorder then
        warn("Cannot start recording: Character not found")
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
    
    -- Track current playing animation track for jump detection
    local humanoid = character:FindFirstChild("Humanoid")
    local lastJumpTrack = nil
    
    recordingConnection = RunService.Heartbeat:Connect(function()
        if not isRecording then return end
        
        local currentTime = tick()
        if currentTime - lastRecordTime < recordInterval then
            return
        end
        lastRecordTime = currentTime
        
        if humanoidRootPart and humanoidRootPart.Parent and character and character.Parent and bodyRecorder and humanoid then
            local cf = humanoidRootPart.CFrame
            local velocity = humanoidRootPart.AssemblyLinearVelocity
            local state = "Idle"
            
            -- Detect state using animation tracks (more accurate for custom animations)
            local isJumpAnimPlaying = false
            local isFallAnimPlaying = false
            local isClimbAnimPlaying = false
            
            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                local animId = track.Animation.AnimationId:lower()
                
                -- Check if jump animation is playing
                if animId:find("jump") then
                    isJumpAnimPlaying = true
                    state = "Jumping"
                    break
                elseif animId:find("fall") then
                    isFallAnimPlaying = true
                    state = "Falling"
                    break
                elseif animId:find("climb") then
                    isClimbAnimPlaying = true
                    state = "Climbing"
                    break
                end
            end
            
            -- If no special animation detected, use jump detector
            if not isJumpAnimPlaying and not isFallAnimPlaying and not isClimbAnimPlaying then
                if animController then
                    state = animController:detectState(velocity)
                end
            end
            
            local bodyFrame = bodyRecorder:captureFrame()
            
            table.insert(recordData, {
                Position = {cf.Position.X, cf.Position.Y, cf.Position.Z},
                LookVector = {cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z},
                UpVector = {cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z},
                Velocity = {velocity.X, velocity.Y, velocity.Z},
                State = state,
                BodyFrame = bodyFrame
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

-- ====== Playback System v5.0 (SIMPLE HUMANOID ONLY) ======
local function playReplay(data)
    if not humanoidRootPart or not humanoidRootPart.Parent or not bodyRecorder then
        warn("Cannot play replay: Character not found")
        return
    end
    
    local token = {}
    currentReplayToken = token
    isPaused = false
    
    task.spawn(function()
        local i = 1
        local totalFrames = #data
        local speed = currentSpeed
        
        while i <= totalFrames do
            if currentReplayToken ~= token then break end
            
            while isPaused and currentReplayToken == token do
                updateStatus("Paused", "Idle", math.floor(i))
                task.wait(0.05)
            end
            
            if humanoidRootPart and humanoidRootPart.Parent and character and character.Parent then
                local f = data[math.floor(i)]
                if not f then break end
                
                local pos = Vector3.new(f.Position[1], f.Position[2], f.Position[3])
                local look = Vector3.new(f.LookVector[1], f.LookVector[2], f.LookVector[3])
                local up = Vector3.new(f.UpVector[1], f.UpVector[2], f.UpVector[3])
                local vel = Vector3.new(f.Velocity[1], f.Velocity[2], f.Velocity[3])
                
                -- Set CFrame and Velocity
                humanoidRootPart.CFrame = CFrame.lookAt(pos, pos + look, up)
                humanoidRootPart.AssemblyLinearVelocity = vel * speed
                
                -- Apply body frame
                if f.BodyFrame and f.BodyFrame.Motors then
                    bodyRecorder:applyFrame(f.BodyFrame, 0.4)
                end
                
                -- Apply humanoid state directly
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid and f.State then
                    if f.State == "Jumping" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    elseif f.State == "Falling" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                    elseif f.State == "Climbing" then
                        humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                    elseif f.State == "Running" then
                        humanoid.WalkSpeed = 24
                    elseif f.State == "Walking" then
                        humanoid.WalkSpeed = 16
                    else
                        humanoid.WalkSpeed = 0
                    end
                end
                
                if i % 5 == 0 then
                    updateStatus("Playing", f.State or "Idle", math.floor(i))
                end
            else
                break
            end
            
            i = i + speed
            RunService.Heartbeat:Wait()
        end
        
        if bodyRecorder then bodyRecorder:reset() end
        if character and character:FindFirstChild("Humanoid") then
            character.Humanoid.WalkSpeed = 16
        end
        if currentReplayToken == token then
            currentReplayToken = nil
            updateStatus("Ready", "Idle", totalFrames)
        end
    end)
end then
        warn("Cannot play replay: Character not found")
        return
    end
    
    local token = {}
    currentReplayToken = token
    isPaused = false
    
    -- Check if premium animations are available
    local isPremium = false
    local animEnabled = true
    
    -- Try to find animation controller for custom animations
    local animController = character:FindFirstChild("Humanoid"):FindFirstChildOfClass("Animator")
    
    -- Load custom animation IDs if available (you can change these)
    local customAnims = {
        Jump = nil, -- Set to animation ID if you have custom jump
        Climb = nil -- Set to animation ID if you have custom climb
    }
    
    local function playAnim(animName)
        if not animEnabled then return end
        
        if animController and customAnims[animName] then
            -- Play custom animation
            local anim = Instance.new("Animation")
            anim.AnimationId = customAnims[animName]
            local track = animController:LoadAnimation(anim)
            track:Play()
        else
            -- Use humanoid state for default animations
            if animName == "Jump" then
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            elseif animName == "Climb" then
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            elseif animName == "Run" then
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
            elseif animName == "Idle" then
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
                character.Humanoid.WalkSpeed = 0
            end
        end
    end
    
    task.spawn(function()
        local index, totalFrames = 1, #data
        local speedMultiplier = currentSpeed
        
        while index <= totalFrames do
            if currentReplayToken ~= token then break end
            
            while isPaused and currentReplayToken == token do
                if animController then animController:stopAll() end
                updateStatus("Paused", "Idle", math.floor(index))
                task.wait(0.05)
            end
            
            if humanoidRootPart and humanoidRootPart.Parent and character and character.Parent and currentReplayToken == token and bodyRecorder then
                local frame = data[math.floor(index)]
                if not frame then break end
                
                local currentPos = humanoidRootPart.Position
                local targetPos = Vector3.new(frame.Position[1], frame.Position[2], frame.Position[3])
                local lookVec = Vector3.new(frame.LookVector[1], frame.LookVector[2], frame.LookVector[3])
                local upVec = Vector3.new(frame.UpVector[1], frame.UpVector[2], frame.UpVector[3])
                local velocity = Vector3.new(frame.Velocity[1], frame.Velocity[2], frame.Velocity[3]) * speedMultiplier
                
                local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookVec, upVec)
                
                pcall(function()
                    humanoidRootPart.CFrame = targetCFrame
                    humanoidRootPart.AssemblyLinearVelocity = velocity
                    
                    -- Apply full body animation FIRST
                    if frame.BodyFrame and frame.BodyFrame.Motors then
                        bodyRecorder:applyFrame(frame.BodyFrame, 0.4)
                    end
                end)
                
                -- FIXED: Animation detection based on next frame direction (like your friend's code)
                if isPremium and animEnabled then
                    if frame.State == "Jumping" or frame.State == "Falling" then
                        playAnim("Jump")
                    elseif frame.State == "Climbing" then
                        playAnim("Climb")
                    else
                        -- Check next frame for movement
                        local nextIndex = math.floor(index + 1)
                        if nextIndex <= totalFrames then
                            local nextFrame = data[nextIndex]
                            if nextFrame then
                                local dir = Vector3.new(
                                    nextFrame.Position[1] - currentPos.X,
                                    nextFrame.Position[2] - currentPos.Y,
                                    nextFrame.Position[3] - currentPos.Z
                                )
                                
                                if dir.Magnitude > 0.1 then
                                    playAnim("Run")
                                else
                                    playAnim("Idle")
                                end
                            end
                        end
                    end
                end
                
                -- Always apply the recorded state to humanoid
                if frame.State then
                    if frame.State == "Jumping" then
                        character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    elseif frame.State == "Falling" then
                        character.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                    elseif frame.State == "Climbing" then
                        character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                    elseif frame.State == "Running" then
                        character.Humanoid.WalkSpeed = 24
                        character.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    elseif frame.State == "Walking" then
                        character.Humanoid.WalkSpeed = 16
                        character.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    else
                        character.Humanoid.WalkSpeed = 0
                    end
                end
                
                if index % 5 == 0 then
                    updateStatus("Playing", frame.State or "Idle", math.floor(index))
                end
            else
                break
            end
            
            index = index + speedMultiplier
            RunService.Heartbeat:Wait()
        end
        
        if animController then animController:stopAll() end
        if bodyRecorder then bodyRecorder:reset() end
        if currentReplayToken == token then
            currentReplayToken = nil
            updateStatus("Ready", "Idle", totalFrames)
        end
    end)
end

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

-- ====== Replay List Item ======
function createReplayItem(saved, index)
    local item = Instance.new("Frame", replayScroll)
    item.Size = UDim2.new(1, 0, 0, 46)
    item.BackgroundColor3 = activeTheme.ItemBg
    item.BorderSizePixel = 0
    item.LayoutOrder = index
    item.ZIndex = 12
    
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
    checkbox.ZIndex = 13
    
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
    nameLabel.ZIndex = 13
    
    local infoLabel = Instance.new("TextLabel", item)
    infoLabel.Size = UDim2.new(0, 100, 0, 12)
    infoLabel.Position = UDim2.new(0, 34, 0, 26)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = string.format("%d frames • ~%ds", #saved.Frames, math.floor(#saved.Frames / 60))
    infoLabel.Font = Enum.Font.GothamMedium
    infoLabel.TextSize = 8
    infoLabel.TextColor3 = activeTheme.TextSecondary
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.ZIndex = 13
    
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
        btn.ZIndex = 13
        
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
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
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
    if bodyRecorder then
        bodyRecorder:cleanup()
    end
    if currentReplayToken then 
        currentReplayToken = nil 
    end
    autoQueueRunning = false
    isRecording = false
end)

print("╔═══════════════════════════════════════════╗")
print("║  AUTO WALK RECORDER PRO v5.0              ║")
print("║    UNIVERSAL JUMP DETECTION               ║")
print("╚═══════════════════════════════════════════╝")
print("")
print("✨ NEW IN v5.0:")
print("   • UNIVERSAL JUMP DETECTION")
print("   • Works with ALL animations (default & custom)")
print("   • Advanced ground detection with raycast")
print("   • Height-based jump tracking")
print("   • Velocity buffer system")
print("   • Smart state transitions")
print("")
print("🎮 Jump Detection Features:")
print("   • Detects jump start (grounded → airborne)")
print("   • Tracks upward motion & height gain")
print("   • Distinguishes jump from fall")
print("   • Works with custom animation packs")
print("   • Min jump height: 3 studs")
print("   • Max jump duration: 1.2 seconds")
print("")
print("💡 How it works:")
print("   1. Records your actual state during recording")
print("   2. Jump detected by:")
print("      - Ground check (raycast)")
print("      - Upward velocity (> 5)")
print("      - Height change buffer")
print("      - Time-based tracking")
print("   3. Plays back EXACT recorded state")
print("")
print("✅ Jump now works with ANY animation!")
