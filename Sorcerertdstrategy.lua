-- 1. Запускаем SimpleSpy
task.spawn(function()
    loadstring(game:HttpGet("https://github.com/exxtremestuffs/SimpleSpySource/raw/master/SimpleSpy.lua"))()
end)

task.wait(2) -- Даем SimpleSpy время на запуск

-- 2. Твой регистратор стратегии (Zero-Lag версия)
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local moneyValue = lp:WaitForChild("leaderstats"):WaitForChild("Money")

local RecordedSteps = {}
local isRecording = true

-- Создаем маленькую кнопку поверх SimpleSpy
local screenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
local stopBtn = Instance.new("TextButton", screenGui)
stopBtn.Size = UDim2.new(0, 150, 0, 40)
stopBtn.Position = UDim2.new(0.5, -75, 0, 10) -- Кнопка в самом верху по центру
stopBtn.Text = "STOP & COPY STRAT"
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.ZIndex = 10000
Instance.new("UICorner", stopBtn)

local function finalSerialize(args)
    local s = "{"
    for i, v in ipairs(args) do
        if typeof(v) == "CFrame" then
            s = s .. "["..i.."] = CFrame.new(" .. tostring(v) .. "),"
        elseif typeof(v) == "string" then
            s = s .. "["..i.."] = '" .. v .. "',"
        elseif typeof(v) == "Instance" then
            -- Пытаемся сохранить путь к юниту максимально точно
            s = s .. "["..i.."] = workspace.Towers:FindFirstChild('" .. v.Name .. "'),"
        else
            s = s .. "["..i.."] = " .. (tostring(v) or "nil") .. ","
        end
    end
    return s .. "}"
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    
    if isRecording and (method == "InvokeServer" or method == "FireServer") then
        if self.Name == "SpawnNewTower" or self.Name == "UpgradeTower" or self.Name == "SellTower" then
            table.insert(RecordedSteps, {
                Obj = self,
                Method = method,
                Args = {...},
                Money = moneyValue.Value
            })
            print("Captured for Strategy: " .. self.Name)
        end
    end
    
    return oldNamecall(self, ...)
end)

stopBtn.MouseButton1Click:Connect(function()
    isRecording = false
    stopBtn.Text = "COPYING..."
    
    local finalCode = "-- AUTO STRATEGY\nlocal money = game.Players.LocalPlayer.leaderstats.Money\n\n"
    
    for i, step in ipairs(RecordedSteps) do
        local serializedArgs = finalSerialize(step.Args)
        finalCode = finalCode .. "-- Step " .. i .. ": " .. step.Obj.Name .. "\n"
        finalCode = finalCode .. "repeat task.wait(0.1) until money.Value >= " .. step.Money .. "\n"
        finalCode = finalCode .. "game." .. step.Obj:GetFullName() .. ":" .. step.Method .. "(unpack(" .. serializedArgs .. "))\n\n"
    end
    
    if setclipboard then 
        setclipboard(finalCode) 
        stopBtn.Text = "COPIED TO CLIPBOARD!"
    else
        print(finalCode)
        stopBtn.Text = "CHECK CONSOLE"
    end
    
    task.wait(3)
    screenGui:Destroy()
end)

warn("ALL SYSTEMS LOADED: SimpleSpy + Recorder")
