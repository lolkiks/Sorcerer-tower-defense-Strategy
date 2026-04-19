local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local moneyValue = lp:WaitForChild("leaderstats"):WaitForChild("Money")

local RecordedSteps = {}
local isRecording = true

-- GUI
local screenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
local stopBtn = Instance.new("TextButton", screenGui)
stopBtn.Size = UDim2.new(0, 150, 0, 50)
stopBtn.Position = UDim2.new(0.5, -75, 0, 70)
stopBtn.Text = "REC: ON (STOP)"
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
stopBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", stopBtn)

-- Функция превращения в текст (теперь работает только в конце)
local function finalSerialize(args)
    local s = "{"
    for i, v in ipairs(args) do
        if typeof(v) == "CFrame" then
            s = s .. "["..i.."] = CFrame.new(" .. tostring(v) .. "),"
        elseif typeof(v) == "string" then
            s = s .. "["..i.."] = '" .. v .. "',"
        elseif typeof(v) == "Instance" then
            s = s .. "["..i.."] = workspace.Towers:FindFirstChild('" .. v.Name .. "'),"
        else
            s = s .. "["..i.."] = " .. (tostring(v) or "nil") .. ","
        end
    end
    return s .. "}"
end

-- МАКСИМАЛЬНО БЫСТРЫЙ ХУК
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    
    if isRecording and (method == "InvokeServer" or method == "FireServer") then
        if self.Name == "SpawnNewTower" or self.Name == "UpgradeTower" or self.Name == "SellTower" then
            -- Мгновенно сохраняем сырые данные, не тратя время на обработку
            table.insert(RecordedSteps, {
                Obj = self,
                Method = method,
                Args = {...},
                Money = moneyValue.Value
            })
            print("Captured: " .. self.Name)
        end
    end
    
    return oldNamecall(self, ...)
end)

stopBtn.MouseButton1Click:Connect(function()
    isRecording = false
    stopBtn.Text = "WAIT... PROCESSING"
    task.wait(0.5)
    
    local finalCode = "-- AUTO STRATEGY\nlocal money = game.Players.LocalPlayer.leaderstats.Money\n\n"
    
    for i, step in ipairs(RecordedSteps) do
        local serializedArgs = finalSerialize(step.Args)
        finalCode = finalCode .. "-- Step " .. i .. ": " .. step.Obj.Name .. "\n"
        finalCode = finalCode .. "repeat task.wait(0.1) until money.Value >= " .. step.Money .. "\n"
        finalCode = finalCode .. "game." .. step.Obj:GetFullName() .. ":" .. step.Method .. "(unpack(" .. serializedArgs .. "))\n\n"
    end
    
    print("\n" .. string.rep("=", 30) .. "\n" .. finalCode .. "\n" .. string.rep("=", 30))
    
    if setclipboard then setclipboard(finalCode) end
    stopBtn.Text = "COPIED!"
    task.wait(2)
    screenGui:Destroy()
end)