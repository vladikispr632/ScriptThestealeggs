-- ═══════════════════════════════════════════════════════════
-- STEAL A EGG HUB v3 — Arceus X Edition
-- Активация: напиши в чат "scripterkrutoj"
-- ═══════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════
-- НАСТРОЙКИ
-- ═══════════════════════════════════════════════════════════
local KEY = "scripterkrutoj"
local FLY_SPEED = 250
local FLY_HEIGHT = 5
local STEP_SIZE = 8
local GRAB_RADIUS = 20
local AUTO_GRAB_DELAY = 0.15

local BEST_KEYWORDS = {"secret","mythic","cosmic","eternal","divine","legendary","epic"}

-- ═══════════════════════════════════════════════════════════
-- СОСТОЯНИЕ
-- ═══════════════════════════════════════════════════════════
local state = {
    savedPos = nil,
    flying = false,
    autoSteal = false,
    autoGrab = false,   -- автоподбор яиц рядом через E
    onlyBest = true,
    espEnabled = false,
    unlocked = false,
}

-- ═══════════════════════════════════════════════════════════
-- ХЕЛПЕРЫ
-- ═══════════════════════════════════════════════════════════
local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function notify(t, txt)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = t, Text = txt, Duration = 2
        })
    end)
end

-- Симуляция нажатия клавиши E
local function pressE()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

-- ═══════════════════════════════════════════════════════════
-- СОХРАНЕНИЕ ПОЗИЦИИ
-- ═══════════════════════════════════════════════════════════
local function savePos()
    local r = root()
    if not r then return end
    state.savedPos = r.Position
    notify("💾 Сохранено", string.format("%.0f, %.0f, %.0f", r.Position.X, r.Position.Y, r.Position.Z))
end

-- ═══════════════════════════════════════════════════════════
-- БЫСТРЫЙ ПОЛЁТ (телепорт-степпинг)
-- ═══════════════════════════════════════════════════════════
local function flyTo(target)
    local r = root()
    if not r then return end

    state.flying = true

    local oldG = workspace.Gravity
    workspace.Gravity = 0

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = r

    local oldC = r.CanCollide
    r.CanCollide = false

    local start = r.Position + Vector3.new(0, FLY_HEIGHT, 0)
    r.CFrame = CFrame.new(start)

    local dist = (target - start).Magnitude
    local steps = math.max(5, math.min(300, math.floor(dist / STEP_SIZE)))

    for i = 1, steps do
        if not root() then break end
        r.CFrame = CFrame.new(start:Lerp(target, i / steps))
        RunService.Heartbeat:Wait()
    end

    if root() then
        r.CFrame = CFrame.new(target)
    end

    workspace.Gravity = oldG
    if root() then r.CanCollide = oldC end
    bv:Destroy()
    state.flying = false
end

local function goSaved()
    if state.flying or not state.savedPos then
        notify("❌ Ошибка", "Сначала сохрани позицию")
        return
    end
    notify("🚀 Полёт", "К сохранённой точке...")
    flyTo(state.savedPos + Vector3.new(0, FLY_HEIGHT, 0))
    notify("📍 Готово", "На месте")
end

-- ═══════════════════════════════════════════════════════════
-- ПОИСК ЯИЦ
-- ═══════════════════════════════════════════════════════════
local function goodEgg(obj)
    if not state.onlyBest then return true end
    local n = obj.Name:lower()
    for _, k in ipairs(BEST_KEYWORDS) do
        if n:find(k) then return true end
    end
    local ok, rarity = pcall(function() return obj:GetAttribute("Rarity") end)
    if ok and rarity then
        local r = tostring(rarity):lower()
        for _, k in ipairs(BEST_KEYWORDS) do
            if r:find(k) then return true end
        end
    end
    return false
end

local function findBestEgg()
    local r = root()
    if not r then return nil end

    local best, minD = nil, math.huge
    for _, o in ipairs(workspace:GetDescendants()) do
        if (o:IsA("BasePart") or o:IsA("Model")) and o.Name:lower():find("egg") then
            if goodEgg(o) then
                local part = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart")
                if part then
                    local d = (part.Position - r.Position).Magnitude
                    if d < minD and d < 600 then
                        minD = d
                        best = part
                    end
                end
            end
        end
    end
    return best
end

local function findNearEgg()
    local r = root()
    if not r then return nil end
    for _, o in ipairs(workspace:GetDescendants()) do
        if (o:IsA("BasePart") or o:IsA("Model")) and o.Name:lower():find("egg") then
            local part = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart")
            if part and (part.Position - r.Position).Magnitude < GRAB_RADIUS then
                return part
            end
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════
-- АВТОКРАЖА
-- ═══════════════════════════════════════════════════════════
local function autoStealLoop()
    while state.autoSteal do
        if not state.flying and root() then
            local egg = findBestEgg()
            if egg then
                -- Летим к яйцу
                flyTo(egg.Position + Vector3.new(0, FLY_HEIGHT, 0))
                task.wait(0.1)

                -- Нажимаем E несколько раз
                for i = 1, 3 do
                    pressE()
                    task.wait(0.1)
                end

                -- Пытаемся взять напрямую
                pcall(function()
                    local t = LP.Character:FindFirstChildWhichIsA("Tool") or
                              LP.Backpack:FindFirstChildWhichIsA("Tool")
                    if t then t:Activate() end
                    egg.CFrame = root().CFrame
                end)

                task.wait(0.2)

                -- Назад на базу
                if state.savedPos then
                    flyTo(state.savedPos + Vector3.new(0, FLY_HEIGHT, 0))
                end
            end
        end
        task.wait(0.4)
    end
end

-- ═══════════════════════════════════════════════════════════
-- АВТОПОДБОР (нажимает E рядом с яйцами)
-- ═══════════════════════════════════════════════════════════
local function autoGrabLoop()
    while state.autoGrab do
        if root() then
            local egg = findNearEgg()
            if egg then
                pressE()
                task.wait(AUTO_GRAB_DELAY)
            end
        end
        task.wait(0.1)
    end
end

-- ═══════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════
local old = PG:FindFirstChild("SEH")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "SEH"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PG

-- ═════ АКТИВАЦИЯ ПО КЛЮЧУ ═════
local keyPanel = Instance.new("Frame")
keyPanel.Size = UDim2.new(0, 300, 0, 60)
keyPanel.Position = UDim2.new(0.5, -150, 0.4, 0)
keyPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
keyPanel.BorderSizePixel = 0
keyPanel.Parent = gui
Instance.new("UICorner", keyPanel).CornerRadius = UDim.new(0, 12)

local kStroke = Instance.new("UIStroke", keyPanel)
kStroke.Color = Color3.fromRGB(0, 150, 255)
kStroke.Thickness = 2

local keyLbl = Instance.new("TextLabel")
keyLbl.Size = UDim2.new(1, -20, 1, 0)
keyLbl.Position = UDim2.new(0, 10, 0, 0)
keyLbl.BackgroundTransparency = 1
keyLbl.Text = '🔑 Напиши в чат: "' .. KEY .. '"'
keyLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
keyLbl.TextSize = 13
keyLbl.Font = Enum.Font.GothamBold
keyLbl.Parent = keyPanel

-- ═════ ГЛАВНАЯ ПАНЕЛЬ ═════
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 300, 0, 480)
panel.Position = UDim2.new(0.5, -150, 0.5, -240)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Active = true
panel.Draggable = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local pStroke = Instance.new("UIStroke", panel)
pStroke.Color = Color3.fromRGB(0, 150, 255)
pStroke.Thickness = 2

-- Заголовок с градиентом
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 20)
titleFix.Position = UDim2.new(0, 0, 1, -20)
titleFix.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🥚 STEAL EGG HUB"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeX = Instance.new("TextButton")
closeX.Size = UDim2.new(0, 30, 0, 30)
closeX.Position = UDim2.new(1, -38, 0, 10)
closeX.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
closeX.Text = "✖"
closeX.TextColor3 = Color3.fromRGB(255, 255, 255)
closeX.TextSize = 14
closeX.Font = Enum.Font.GothamBold
closeX.BorderSizePixel = 0
closeX.Parent = titleBar
Instance.new("UICorner", closeX).CornerRadius = UDim.new(0, 8)

-- Статус
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 26)
status.Position = UDim2.new(0, 10, 0, 58)
status.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
status.Text = "✅ Скрипт загружен"
status.TextColor3 = Color3.fromRGB(80, 220, 120)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.BorderSizePixel = 0
status.Parent = panel
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

-- Функция кнопок
local function makeBtn(text, y, col, parent)
    parent = parent or panel
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 40)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = col
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(255, col.R * 255 + 40),
                math.min(255, col.G * 255 + 40),
                math.min(255, col.B * 255 + 40)
            )
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = col
        }):Play()
    end)
    return b
end

-- Кнопки
local y = 92

local bSave = makeBtn("💾 СОХРАНИТЬ ПОЗИЦИЮ", y, Color3.fromRGB(0, 170, 80))
bSave.MouseButton1Click:Connect(function()
    savePos()
    if state.savedPos then
        status.Text = string.format("💾 Сохранено %.0f %.0f %.0f", state.savedPos.X, state.savedPos.Y, state.savedPos.Z)
        status.TextColor3 = Color3.fromRGB(80, 220, 120)
    end
end)
y = y + 46

local bGo = makeBtn("🚀 ЛЕТЕТЬ К ПОЗИЦИИ", y, Color3.fromRGB(200, 40, 40))
bGo.MouseButton1Click:Connect(function()
    goSaved()
end)
y = y + 46

local bSteal = makeBtn("🎯 АВТОКРАЖА: ВЫКЛ", y, Color3.fromRGB(60, 60, 90))
bSteal.MouseButton1Click:Connect(function()
    state.autoSteal = not state.autoSteal
    if state.autoSteal then
        bSteal.Text = "🎯 АВТОКРАЖА: ВКЛ"
        bSteal.BackgroundColor3 = Color3.fromRGB(150, 50, 150)
        status.Text = "🎯 Автокража работает"
        status.TextColor3 = Color3.fromRGB(200, 100, 255)
        task.spawn(autoStealLoop)
    else
        bSteal.Text = "🎯 АВТОКРАЖА: ВЫКЛ"
        bSteal.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        status.Text = "⏸️ Автокража выключена"
        status.TextColor3 = Color3.fromRGB(150, 150, 170)
    end
end)
y = y + 46

local bGrab = makeBtn("🔽 АВТОПОДБОР (E): ВЫКЛ", y, Color3.fromRGB(60, 60, 90))
bGrab.MouseButton1Click:Connect(function()
    state.autoGrab = not state.autoGrab
    if state.autoGrab then
        bGrab.Text = "🔽 АВТОПОДБОР (E): ВКЛ"
        bGrab.BackgroundColor3 = Color3.fromRGB(50, 150, 150)
        status.Text = "🔽 Автоподбор яиц работает"
        status.TextColor3 = Color3.fromRGB(100, 220, 220)
        task.spawn(autoGrabLoop)
    else
        bGrab.Text = "🔽 АВТОПОДБОР (E): ВЫКЛ"
        bGrab.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        status.Text = "⏸️ Автоподбор выключен"
        status.TextColor3 = Color3.fromRGB(150, 150, 170)
    end
end)
y = y + 46

local bBest = makeBtn("⭐ ТОЛЬКО ЛУЧШИЕ: ВКЛ", y, Color3.fromRGB(150, 100, 0))
bBest.MouseButton1Click:Connect(function()
    state.onlyBest = not state.onlyBest
    if state.onlyBest then
        bBest.Text = "⭐ ТОЛЬКО ЛУЧШИЕ: ВКЛ"
        bBest.BackgroundColor3 = Color3.fromRGB(150, 100, 0)
    else
        bBest.Text = "⭐ ТОЛЬКО ЛУЧШИЕ: ВЫКЛ"
        bBest.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    end
end)
y = y + 46

-- Кнопка движения (открывает подпанель)
local bMove = makeBtn("🎮 ПАНЕЛЬ ДВИЖЕНИЯ", y, Color3.fromRGB(80, 80, 140))
y = y + 46

local bHide = makeBtn("✖ СКРЫТЬ", y, Color3.fromRGB(50, 50, 60))
bHide.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

-- ═════ ПАНЕЛЬ ДВИЖЕНИЯ (открывается отдельно) ═════
local movePanel = Instance.new("Frame")
movePanel.Size = UDim2.new(0, 200, 0, 240)
movePanel.Position = UDim2.new(0, 20, 0.2, 0)
movePanel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
movePanel.BorderSizePixel = 0
movePanel.Visible = false
movePanel.Draggable = true
movePanel.Active = true
movePanel.Parent = gui
Instance.new("UICorner", movePanel).CornerRadius = UDim.new(0, 14)

local mStroke = Instance.new("UIStroke", movePanel)
mStroke.Color = Color3.fromRGB(150, 100, 255)
mStroke.Thickness = 2

local mTitle = Instance.new("TextLabel")
mTitle.Size = UDim2.new(1, -40, 0, 32)
mTitle.Position = UDim2.new(0, 10, 0, 5)
mTitle.BackgroundTransparency = 1
mTitle.Text = "🎮 ДВИЖЕНИЕ"
mTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
mTitle.TextSize = 14
mTitle.Font = Enum.Font.GothamBold
mTitle.TextXAlignment = Enum.TextXAlignment.Left
mTitle.Parent = movePanel

local mClose = Instance.new("TextButton")
mClose.Size = UDim2.new(0, 26, 0, 26)
mClose.Position = UDim2.new(1, -34, 0, 8)
mClose.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
mClose.Text = "✖"
mClose.TextColor3 = Color3.fromRGB(255, 255, 255)
mClose.TextSize = 12
mClose.Font = Enum.Font.GothamBold
mClose.BorderSizePixel = 0
mClose.Parent = movePanel
Instance.new("UICorner", mClose).CornerRadius = UDim.new(0, 6)
mClose.MouseButton1Click:Connect(function()
    movePanel.Visible = false
end)

-- Сетка кнопок движения
local function mBtn(text, x, y, col, key)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 50, 0, 50)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = col
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 18
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = movePanel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

    -- Нажатие = движение
    b.MouseButton1Down:Connect(function()
        local h = hum()
        if h then h:Move(Vector3.new(0, 0, 0), true) end
        local c = LP.Character
        if c then
            local moveDir = Vector3.new()
            if text == "W" then moveDir = Vector3.new(0, 0, -1)
            elseif text == "S" then moveDir = Vector3.new(0, 0, 1)
            elseif text == "A" then moveDir = Vector3.new(-1, 0, 0)
            elseif text == "D" then moveDir = Vector3.new(1, 0, 0)
            elseif text == "⤴" then
                local r = root()
                if r then r.CFrame = r.CFrame + Vector3.new(0, 8, 0) end
                return
            elseif text == "⤵" then
                local r = root()
                if r then r.CFrame = r.CFrame - Vector3.new(0, 8, 0) end
                return
            elseif text == "↑" then
                if h then h.Jump = true end
                return
            end
            if h then
                h:Move(moveDir, false)
            end
        end
    end)

    b.MouseButton1Up:Connect(function()
        local h = hum()
        if h then h:Move(Vector3.new(0, 0, 0), true) end
    end)
    return b
end

-- Сетка: W / A / S / D + JUMP + UP + DOWN
mBtn("W", 75, 50, Color3.fromRGB(60, 60, 90))
mBtn("A", 20, 105, Color3.fromRGB(60, 60, 90))
mBtn("S", 75, 105, Color3.fromRGB(60, 60, 90))
mBtn("D", 130, 105, Color3.fromRGB(60, 60, 90))
mBtn("↑", 130, 50, Color3.fromRGB(80, 150, 80))
mBtn("⤴", 20, 160, Color3.fromRGB(80, 80, 150))
mBtn("⤵", 75, 160, Color3.fromRGB(80, 80, 150))

local mStop = Instance.new("TextButton")
mStop.Size = UDim2.new(1, -20, 0, 32)
mStop.Position = UDim2.new(0, 10, 0, 195)
mStop.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
mStop.Text = "🛑 СТОП"
mStop.TextColor3 = Color3.fromRGB(255, 255, 255)
mStop.TextSize = 12
mStop.Font = Enum.Font.GothamBold
mStop.BorderSizePixel = 0
mStop.Parent = movePanel
Instance.new("UICorner", mStop).CornerRadius = UDim.new(0, 8)
mStop.MouseButton1Click:Connect(function()
    local h = hum()
    if h then h:Move(Vector3.new(0, 0, 0), true) end
end)

-- Открытие панели движения
bMove.MouseButton1Click:Connect(function()
    movePanel.Visible = not movePanel.Visible
end)

-- Кнопка скрытия
closeX.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

-- ═════ АКТИВАЦИЯ ПО КЛЮЧУ В ЧАТЕ ═════
LP.Chatted:Connect(function(msg)
    if msg:lower() == KEY:lower() then
        if not state.unlocked then
            state.unlocked = true
            panel.Visible = true
            keyPanel.Visible = false
            notify("🔓 АКТИВИРОВАНО", "Ключ принят: " .. KEY)
        else
            panel.Visible = not panel.Visible
        end
    end
end)

-- ═════ АНИМАЦИЯ ПУЛЬСАЦИИ ═════
task.spawn(function()
    while gui.Parent do
        if panel.Visible then
            local t = tick()
            local pulse = (math.sin(t * 3) + 1) / 2
            pStroke.Transparency = 1 - pulse * 0.6
        end
        task.wait(0.05)
    end
end)

-- ═════ АНИМАЦИЯ ЗАГОЛОВКА (градиент) ═════
task.spawn(function()
    while gui.Parent do
        for i = 0, 100, 5 do
            if not gui.Parent then break end
            local r = 0
            local g = 100 + i
            local b = 200 + math.floor(math.sin(i/10)*55)
            titleBar.BackgroundColor3 = Color3.fromRGB(r, g, b)
            titleFix.BackgroundColor3 = titleBar.BackgroundColor3
            task.wait(0.05)
        end
        task.wait(0.5)
    end
end)

-- ═════ ГОРЯЧИЕ КЛАВИШИ ═════
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Z then savePos() end
    if input.KeyCode == Enum.KeyCode.X then goSaved() end
    if input.KeyCode == Enum.KeyCode.E then
        if state.autoGrab then pressE() end
    end
end)
-- ═════ СТАРТ ═════
notify("🥚 Steal Egg Hub", 'Напиши в чат: "' .. KEY .. '"')
print("[StealEggHub] Загружен. Ключ: " .. KEY)
print("[StealEggHub] Z = сохранить, X = лететь, E = взять яйцо")
