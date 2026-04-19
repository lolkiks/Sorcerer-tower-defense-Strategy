local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local moneyValue = lp:WaitForChild("leaderstats"):WaitForChild("Money")

local RecordedSteps = {}
local isRecording = true
local recordStart = os.clock()

local VALID_REMOTES = {
    SpawnNewTower = true,
    UpgradeTower = true,
    SellTower = true,
}

local function towerState(instance)
    if typeof(instance) ~= "Instance" or not instance.Parent then
        return nil
    end

    local levelObj = instance:FindFirstChild("Upgrade")
    local level = (levelObj and levelObj:IsA("IntValue")) and levelObj.Value or nil

    return {
        name = instance.Name,
        level = level,
    }
end

local function serializeValue(v)
    local t = typeof(v)

    if t == "CFrame" then
        return string.format("CFrame.new(%s)", tostring(v))
    elseif t == "Vector3" then
        return string.format("Vector3.new(%s)", tostring(v))
    elseif t == "Vector2" then
        return string.format("Vector2.new(%s)", tostring(v))
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "boolean" or t == "number" then
        return tostring(v)
    elseif t == "Instance" then
        return string.format("workspace:FindFirstChild(\"Towers\") and workspace.Towers:FindFirstChild(%q)", v.Name)
    elseif t == "nil" then
        return "nil"
    end

    return "nil"
end

local function serializeArgs(args)
    local out = table.create(#args)
    for i, v in ipairs(args) do
        out[i] = string.format("[%d] = %s", i, serializeValue(v))
    end
    return "{" .. table.concat(out, ", ") .. "}"
end

local function captureStep(remoteObj, method, args)
    local stepTime = os.clock() - recordStart
    local moneyBefore = moneyValue.Value

    local trackedTower = nil
    for _, arg in ipairs(args) do
        if typeof(arg) == "Instance" and arg:IsDescendantOf(workspace) then
            trackedTower = arg
            break
        end
    end

    local state = trackedTower and towerState(trackedTower) or nil

    table.insert(RecordedSteps, {
        Remote = remoteObj.Name,
        Method = method,
        Args = table.clone(args),
        MoneyBefore = moneyBefore,
        Timestamp = stepTime,
        TowerState = state,
    })

    print(string.format("Captured #%d: %s", #RecordedSteps, remoteObj.Name))
end

local function buildReplayCode()
    local code = {}

    table.insert(code, "-- AUTO STRATEGY (NO REMOTE LOADSTRING)")
    table.insert(code, "local player = game:GetService(\"Players\").LocalPlayer")
    table.insert(code, "local money = player:WaitForChild(\"leaderstats\"):WaitForChild(\"Money\")")
    table.insert(code, "local remotes = game:GetService(\"ReplicatedStorage\"):WaitForChild(\"RemoteEvents\")")
    table.insert(code, "local function getTower(name) return workspace:FindFirstChild(\"Towers\") and workspace.Towers:FindFirstChild(name) end")
    table.insert(code, "")

    local prevTimestamp = 0

    for i, step in ipairs(RecordedSteps) do
        local argsText = serializeArgs(step.Args)
        local delay = math.max(0, step.Timestamp - prevTimestamp)
        prevTimestamp = step.Timestamp

        table.insert(code, string.format("-- Step %d: %s", i, step.Remote))
        table.insert(code, string.format("repeat task.wait(0.1) until money.Value >= %d", step.MoneyBefore))

        if delay > 0.2 then
            table.insert(code, string.format("task.wait(%.2f)", delay))
        end

        if step.Remote == "UpgradeTower" and step.TowerState and step.TowerState.name then
            table.insert(code, string.format("repeat task.wait(0.05) until getTower(%q)", step.TowerState.name))
        elseif step.Remote == "SellTower" and step.TowerState and step.TowerState.name then
            table.insert(code, string.format("repeat task.wait(0.05) until getTower(%q)", step.TowerState.name))
        end

        table.insert(code, string.format("local args = %s", argsText))
        table.insert(code, string.format("remotes[%q]:%s(unpack(args))", step.Remote, step.Method))
        table.insert(code, "task.wait(0.1)")
        table.insert(code, "")
    end

    return table.concat(code, "\n")
end

local function makeDraggable(handle, root)
    local dragStart
    local startPos
    local dragging = false

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = root.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        root.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StrategyRecorderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local panel = Instance.new("Frame")
panel.Parent = screenGui
panel.Size = UDim2.new(0, 265, 0, 136)
panel.Position = UDim2.new(0.5, -132, 0, 70)
panel.BackgroundColor3 = Color3.fromRGB(26, 29, 36)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local header = Instance.new("Frame")
header.Parent = panel
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(41, 45, 56)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Parent = header
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -74, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.Text = "Strategy Recorder"
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamSemibold
title.TextSize = 14
title.TextColor3 = Color3.new(1, 1, 1)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Parent = header
toggleBtn.Size = UDim2.new(0, 28, 0, 24)
toggleBtn.Position = UDim2.new(1, -34, 0.5, -12)
toggleBtn.BackgroundColor3 = Color3.fromRGB(67, 72, 88)
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Text = "▾"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 17
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 7)

local content = Instance.new("Frame")
content.Parent = panel
content.BackgroundTransparency = 1
content.Position = UDim2.new(0, 0, 0, 34)
content.Size = UDim2.new(1, 0, 1, -34)

local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = content
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0, 12, 0, 8)
statusLabel.Size = UDim2.new(1, -24, 0, 24)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "REC: ON"
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(122, 235, 143)

local hintLabel = Instance.new("TextLabel")
hintLabel.Parent = content
hintLabel.BackgroundTransparency = 1
hintLabel.Position = UDim2.new(0, 12, 0, 30)
hintLabel.Size = UDim2.new(1, -24, 0, 21)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Text = "Drag panel without stopping record"
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 12
hintLabel.TextColor3 = Color3.fromRGB(187, 194, 219)

local stopBtn = Instance.new("TextButton")
stopBtn.Parent = content
stopBtn.Size = UDim2.new(1, -24, 0, 38)
stopBtn.Position = UDim2.new(0, 12, 0, 58)
stopBtn.BackgroundColor3 = Color3.fromRGB(204, 62, 62)
stopBtn.TextColor3 = Color3.new(1, 1, 1)
stopBtn.Text = "STOP + COPY"
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 15
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

makeDraggable(header, panel)

local expanded = true
local expandedSize = UDim2.new(0, 265, 0, 136)
local collapsedSize = UDim2.new(0, 265, 0, 34)

toggleBtn.MouseButton1Click:Connect(function()
    expanded = not expanded
    toggleBtn.Text = expanded and "▾" or "▸"

    TweenService:Create(
        panel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = expanded and expandedSize or collapsedSize }
    ):Play()
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()

    if isRecording and (method == "InvokeServer" or method == "FireServer") then
        if typeof(self) == "Instance" and VALID_REMOTES[self.Name] then
            local args = { ... }
            local ok, err = pcall(captureStep, self, method, args)
            if not ok then
                warn("[StrategyRecorder] capture failed: " .. tostring(err))
            end
        end
    end

    return oldNamecall(self, ...)
end)

stopBtn.MouseButton1Click:Connect(function()
    if not isRecording then
        return
    end

    isRecording = false
    stopBtn.Text = "WAIT... PROCESSING"
    statusLabel.Text = "REC: OFF"
    statusLabel.TextColor3 = Color3.fromRGB(255, 184, 102)
    task.wait(0.3)

    local finalCode = buildReplayCode()

    print("\n" .. string.rep("=", 30) .. "\n" .. finalCode .. "\n" .. string.rep("=", 30))

    if setclipboard then
        setclipboard(finalCode)
    end

    stopBtn.Text = "COPIED!"
    statusLabel.Text = "COPIED TO CLIPBOARD"
    statusLabel.TextColor3 = Color3.fromRGB(129, 221, 151)
    task.wait(2)
    screenGui:Destroy()
end)
