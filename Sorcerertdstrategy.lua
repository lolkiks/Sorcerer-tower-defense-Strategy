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

-- ФУНКЦИЯ СЕРИАЛИЗАЦИИ (вызывается только в конце)
local function serializeValue(v)
    local t = typeof(v)
    if t == "CFrame" then
        return string.format("CFrame.new(%s)", tostring(v))
    elseif t == "Vector3" then
        return string.format("Vector3.new(%s)", tostring(v))
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "boolean" or t == "number" then
        return tostring(v)
    elseif t == "Instance" then
        -- Если это башня в воркспейсе
        return string.format("workspace:FindFirstChild('Towers') and workspace.Towers:FindFirstChild(%q)", v.Name)
    end
    return "nil"
end

local function finalSerialize(args)
    local out = {}
    for i, v in ipairs(args) do
        out[i] = string.format("[%d] = %s", i, serializeValue(v))
    end
    return "{" .. table.concat(out, ", ") .. "}"
end

-- GUI (Твой оригинальный дизайн)
local screenGui = Instance.new("ScreenGui", CoreGui)
screenGui.Name = "StrategyRecorderGui"

local panel = Instance.new("Frame", screenGui)
panel.Size = UDim2.new(0, 265, 0, 136)
panel.Position = UDim2.new(0.5, -132, 0, 70)
panel.BackgroundColor3 = Color3.fromRGB(26, 29, 36)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local header = Instance.new("Frame", panel)
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(41, 45, 56)
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -74, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.Text = "Strategy Recorder (Pro)"
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

local statusLabel = Instance.new("TextLabel", panel)
statusLabel.Position = UDim2.new(0, 12, 0, 42)
statusLabel.Size = UDim2.new(1, -24, 0, 24)
statusLabel.Text = "REC: ON"
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(122, 235, 143)
statusLabel.Font = Enum.Font.GothamBold

local stopBtn = Instance.new("TextButton", panel)
stopBtn.Size = UDim2.new(1, -24, 0, 38)
stopBtn.Position = UDim2.new(0, 12, 0, 80)
stopBtn.BackgroundColor3 = Color3.fromRGB(204, 62, 62)
stopBtn.Text = "STOP + COPY"
stopBtn.TextColor3 = Color3.new(1, 1, 1)
stopBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", stopBtn)

-- Dragging
local function makeDraggable(h, r)
    local dragStart, startPos, dragging
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = i.Position
            startPos = r.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - dragStart
            r.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
end
makeDraggable(header, panel)

-- МАКСИМАЛЬНО БЫСТРЫЙ ХУК (Сырая запись)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    
    if isRecording and (method == "InvokeServer" or method == "FireServer") then
        if VALID_REMOTES[self.Name] then
            -- Мгновенно пушим в таблицу, не тратя время на обработку строк
            table.insert(RecordedSteps, {
                RemotePath = self:GetFullName(),
                Name = self.Name,
                Method = method,
                Args = {...},
                Money = moneyValue.Value
            })
            print("Captured: " .. self.Name)
        end
    end
    return oldNamecall(self, ...)
end)

-- ГЕНЕРАЦИЯ КОДА ПРИ СТОПЕ
stopBtn.MouseButton1Click:Connect(function()
    if not isRecording then return end
    isRecording = false
    
    stopBtn.Text = "WAIT... PROCESSING"
    statusLabel.Text = "REC: OFF"
    statusLabel.TextColor3 = Color3.fromRGB(255, 184, 102)
    task.wait(0.5)
    
    local finalCode = "-- AUTO STRATEGY\nlocal player = game.Players.LocalPlayer\nlocal money = player.leaderstats.Money\n\n"
    
    for i, step in ipairs(RecordedSteps) do
        local sArgs = finalSerialize(step.Args)
        finalCode = finalCode .. "-- Step " .. i .. ": " .. step.Name .. "\n"
        finalCode = finalCode .. "repeat task.wait(0.05) until money.Value >= " .. step.Money .. "\n"
        -- Используем путь через game... чтобы точно найти Remote
        finalCode = finalCode .. "game." .. step.RemotePath .. ":" .. step.Method .. "(unpack(" .. sArgs .. "))\n"
        finalCode = finalCode .. "task.wait(0.1)\n\n"
    end
    
    if setclipboard then setclipboard(finalCode) end
    
    stopBtn.Text = "COPIED!"
    statusLabel.Text = "DONE!"
    statusLabel.TextColor3 = Color3.fromRGB(129, 221, 151)
    
    task.wait(2)
    screenGui:Destroy()
end)
