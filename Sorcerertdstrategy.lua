local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local moneyValue = lp:WaitForChild("leaderstats"):WaitForChild("Money")

local RecordedSteps = {}
local isRecording = true

local VALID_REMOTES = {
    SpawnNewTower = true,
    UpgradeTower = true,
    SellTower = true,
}

-- Сериализация только на этапе финальной сборки кода
local function finalSerialize(args)
    local s = "{"
    for i, v in ipairs(args) do
        if typeof(v) == "CFrame" then
            s = s .. "[" .. i .. "] = CFrame.new(" .. tostring(v) .. "),"
        elseif typeof(v) == "string" then
            s = s .. "[" .. i .. "] = " .. string.format("%q", v) .. ","
        elseif typeof(v) == "Instance" then
            s = s .. "[" .. i .. "] = workspace.Towers:FindFirstChild('" .. v.Name .. "'),"
        else
            s = s .. "[" .. i .. "] = " .. (tostring(v) or "nil") .. ","
        end
    end
    return s .. "}"
end

local function makeDraggable(handle, root)
    local dragging = false
    local dragStart
    local startPos

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
panel.ClipsDescendants = true
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
hintLabel.Text = "Records summon/upgrade/sell actions"
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

    if expanded then
        content.Visible = true
    end

    local tween = TweenService:Create(
        panel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = expanded and expandedSize or collapsedSize }
    )

    tween:Play()
    tween.Completed:Once(function()
        if not expanded then
            content.Visible = false
        end
    end)
end)

-- Старая логика записи действий: сырое сохранение Obj/Method/Args/Money
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()

    if isRecording and (method == "InvokeServer" or method == "FireServer") then
        if typeof(self) == "Instance" and VALID_REMOTES[self.Name] then
            table.insert(RecordedSteps, {
                Obj = self,
                Method = method,
                Args = { ... },
                Money = moneyValue.Value,
            })
            print("Captured: " .. self.Name)
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
    task.wait(0.5)

    local finalCode = "-- AUTO STRATEGY\nlocal money = game.Players.LocalPlayer.leaderstats.Money\n\n"

    for i, step in ipairs(RecordedSteps) do
        local serializedArgs = finalSerialize(step.Args)
        finalCode = finalCode .. "-- Step " .. i .. ": " .. step.Obj.Name .. "\n"
        finalCode = finalCode .. "repeat task.wait(0.1) until money.Value >= " .. step.Money .. "\n"
        finalCode = finalCode .. "game." .. step.Obj:GetFullName() .. ":" .. step.Method .. "(unpack(" .. serializedArgs .. "))\n\n"
    end

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
