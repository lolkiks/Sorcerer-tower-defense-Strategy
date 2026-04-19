local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

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
        id = instance:GetDebugId(1),
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

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StrategyRecorderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local stopBtn = Instance.new("TextButton")
stopBtn.Parent = screenGui
stopBtn.Size = UDim2.new(0, 190, 0, 50)
stopBtn.Position = UDim2.new(0.5, -95, 0, 70)
stopBtn.Text = "REC: ON (STOP)"
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
stopBtn.TextColor3 = Color3.new(1, 1, 1)
stopBtn.TextSize = 16
Instance.new("UICorner", stopBtn)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()

    if isRecording and (method == "InvokeServer" or method == "FireServer") then
        if typeof(self) == "Instance" and VALID_REMOTES[self.Name] then
            local args = { ... }
            captureStep(self, method, args)
        end
    end

    return oldNamecall(self, ...)
end)

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
            table.insert(code, string.format("if not getTower(%q) then task.wait(0.15) end", step.TowerState.name))
        end

        table.insert(code, string.format("local args = %s", argsText))
        table.insert(code, string.format("remotes[%q]:%s(unpack(args))", step.Remote, step.Method))
        table.insert(code, "task.wait(0.1)")
        table.insert(code, "")
    end

    return table.concat(code, "\n")
end

stopBtn.MouseButton1Click:Connect(function()
    if not isRecording then
        return
    end

    isRecording = false
    stopBtn.Text = "WAIT... PROCESSING"
    task.wait(0.3)

    local finalCode = buildReplayCode()

    print("\n" .. string.rep("=", 30) .. "\n" .. finalCode .. "\n" .. string.rep("=", 30))

    if setclipboard then
        setclipboard(finalCode)
    end

    stopBtn.Text = "COPIED!"
    task.wait(2)
    screenGui:Destroy()
end)
