local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local State = {
    Running   = true,
    AutoSpawn = false,
    AutoBuy   = false,
    AntiAFK   = true,
    SpawnDelay = 0.6,
    BuyDelay   = 0.25,
    Packs  = {},   -- [ชื่อแพ็ก] = true/false (ไม่เลือกเลย = ซื้อทุกแพ็ก)
    Status = {},   -- [คำสถานะ]  = true/false (ไม่เลือกเลย = ซื้อทุกสถานะ)
    SpawnCount = 0,
    BuyCount   = 0,
}

local PACK_LIST = {
    "Academy Pack", "Alchemy Pack", "Arcane Pack", "Azure Pack", "Beast Pack",
    "Blaze Pack", "Blossom Pack", "Brawler Pack", "Bull Pack",
    "Chainsaw Pack", "Chrono Pack", "Conquest Pack", "Contract Pack",
    "Cosmos Pack", "Crimson Pack", "Duel Pack", "Dunk Pack", "Dynasty Pack",
    "Emblem Pack", "Eternity Pack", "Fallen Pack", "Fiber Pack", "Grail Pack",
    "Justice Pack", "Lunar Pack", "Mecha Pack", "Moon Pack", "Moonfang Pack",
    "Moonlight Pack", "Nightfall Pack", "Occult Pack", "Power Pack",
    "Psychic Pack", "Raven Pack", "Reaper Pack", "Rebellion Pack",
    "Requiem Pack", "Revenge Pack", "Shield Pack", "Smash Pack", "Soul Pack",
    "Spider Pack", "Swordsman Pack", "Valkyrie Pack", "Zenith Pack",
}
local STATUS_LIST = {
    "Normal", "Golden", "Diamond", "Rainbow", "Sakura", "Venomous", "Candy",
    "Blessed", "Glitch", "Radioactive",
    "Starfallen", "Admin", "Nullstar", "Unknown", "Nightmare",
}

----------------------------------------------------------------
-- ANTI AFK
----------------------------------------------------------------
local afkConn = player.Idled:Connect(function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

----------------------------------------------------------------
-- GAME LOGIC
----------------------------------------------------------------
local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getMyPlot()
    local hrp = getHRP()
    local plots = workspace:FindFirstChild("MAP") and workspace.MAP:FindFirstChild("Plots")
    if not (plots and hrp) then return end
    local best, bestDist
    for _, group in ipairs(plots:GetChildren()) do
        for _, plot in ipairs(group:GetChildren()) do
            local ok, pos = pcall(function() return plot:GetPivot().Position end)
            if ok then
                local d = (pos - hrp.Position).Magnitude
                if not bestDist or d < bestDist then best, bestDist = plot, d end
            end
        end
    end
    return best
end

local myPlot
local function plot()
    if not myPlot or not myPlot.Parent then myPlot = getMyPlot() end
    return myPlot
end

local function anySelected(t)
    for _, v in pairs(t) do if v then return true end end
    return false
end

local function itemLabels(item) -- ข้อความทุกช่องบนการ์ด (ตัวพิมพ์เล็ก)
    local set = {}
    for _, d in ipairs(item:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = d.Text:gsub("^%s+", ""):gsub("%s+$", "")
            set[t:lower()] = true
        end
    end
    return set
end

local ensurePack -- ประกาศไว้ก่อน (ฟังก์ชันจริงอยู่ในส่วน UI)

local function shouldBuy(item)
    ensurePack(item.Name)
    if anySelected(State.Packs) and not State.Packs[item.Name] then return false end
    if anySelected(State.Status) then
        local labels, ok = itemLabels(item), false
        for k, v in pairs(State.Status) do
            if v and labels[k:lower()] then ok = true break end
        end
        if not ok then return false end
    end
    return true
end

task.spawn(function() -- Auto Spawn
    while State.Running do
        task.wait(State.SpawnDelay)
        if State.AutoSpawn then
            local p = plot()
            local btn = p and p:FindFirstChild("ButtonPart")
            local cd = btn and btn:FindFirstChildWhichIsA("ClickDetector")
            if cd then fireclickdetector(cd); State.SpawnCount += 1 end
        end
    end
end)

task.spawn(function() -- Auto Buy
    while State.Running do
        task.wait(State.BuyDelay)
        local p = plot()
        local conv = p and p:FindFirstChild("LocalConveyorModels")
        if conv then
            for _, item in ipairs(conv:GetChildren()) do
                local main = item:FindFirstChild("Main")
                local pp = main and main:FindFirstChildWhichIsA("ProximityPrompt")
                if pp then
                    local ok = shouldBuy(item) -- ใส่ชื่อแพ็กใหม่ลงเมนูอัตโนมัติด้วย
                    if State.AutoBuy and ok and pp.Enabled and pp.ActionText == "Buy" then
                        pp.HoldDuration = 0
                        pp.RequiresLineOfSight = false
                        pp.MaxActivationDistance = 100
                        fireproximityprompt(pp)
                        State.BuyCount += 1
                    end
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- UI
----------------------------------------------------------------
local C = {
    bg = Color3.fromRGB(24, 24, 32), panel = Color3.fromRGB(33, 33, 44),
    accent = Color3.fromRGB(120, 90, 255), on = Color3.fromRGB(70, 200, 120),
    off = Color3.fromRGB(70, 70, 85), text = Color3.fromRGB(235, 235, 245),
    sub = Color3.fromRGB(150, 150, 170),
}
local FONT, FONTB = Enum.Font.SourceSans, Enum.Font.SourceSansBold

local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 8) c.Parent = o end
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local old = parentGui:FindFirstChild("CardFarmUI")
if old then old:Destroy() end

local gui = new("ScreenGui", { Name = "CardFarmUI", ResetOnSpawn = false }, parentGui)

local main = new("Frame", {
    Size = UDim2.fromOffset(360, 430), Position = UDim2.new(0.5, -180, 0.5, -215),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true,
}, gui)
corner(main, 12)
new("UIStroke", { Color = C.accent, Thickness = 1.5, Transparency = 0.3 }, main)

-- Title bar
local title = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, main)
new("TextLabel", {
    Text = "🃏  Card Farm", Font = FONTB, TextSize = 20, TextColor3 = C.text,
    BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(14, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, title)

local function titleBtn(txt, xoff, color)
    local b = new("TextButton", {
        Text = txt, Font = FONTB, TextSize = 18, TextColor3 = C.text, BackgroundColor3 = color,
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xoff, 0.5, -13), AutoButtonColor = true,
    }, title)
    corner(b, 6)
    return b
end
local btnMin = titleBtn("–", -64, C.off)
local btnClose = titleBtn("✕", -32, Color3.fromRGB(200, 70, 80))

-- Drag
do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Tabs
local tabBar = new("Frame", {
    Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 48), BackgroundTransparency = 1,
}, main)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
}, tabBar)

local content = new("Frame", {
    Size = UDim2.new(1, -20, 1, -96), Position = UDim2.fromOffset(10, 88), BackgroundTransparency = 1,
}, main)

local pages, tabButtons = {}, {}
local function showPage(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabButtons) do
        TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = (n == name) and C.accent or C.panel }):Play()
    end
end
local function newPage(name, label)
    local b = new("TextButton", {
        Text = label, Font = FONTB, TextSize = 16, TextColor3 = C.text,
        BackgroundColor3 = C.panel, Size = UDim2.new(1 / 3, -4, 1, 0), AutoButtonColor = false,
    }, tabBar)
    corner(b, 8)
    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, content)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    pages[name], tabButtons[name] = page, b
    b.MouseButton1Click:Connect(function() showPage(name) end)
    return page
end

-- Components
local function makeToggle(parent, text, init, cb, order)
    local row = new("Frame", {
        Size = UDim2.new(1, -6, 0, 40), BackgroundColor3 = C.panel, LayoutOrder = order or 0,
    }, parent)
    corner(row, 8)
    new("TextLabel", {
        Text = text, Font = FONT, TextSize = 18, TextColor3 = C.text, BackgroundTransparency = 1,
        Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(12, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = new("Frame", {
        Size = UDim2.fromOffset(44, 22), Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = init and C.on or C.off,
    }, row)
    corner(pill, 11)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.new(1, 1, 1),
        Position = init and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2),
    }, pill)
    corner(knob, 9)
    local state = init
    local function set(v)
        state = v
        TweenService:Create(pill, TweenInfo.new(0.15), { BackgroundColor3 = v and C.on or C.off }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = v and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2),
        }):Play()
    end
    local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, row)
    hit.MouseButton1Click:Connect(function() set(not state); cb(state) end)
    return set, row
end

local function makeLabel(parent, text, order, height)
    return new("TextLabel", {
        Text = text, Font = FONT, TextSize = 15, TextColor3 = C.sub, BackgroundTransparency = 1,
        Size = UDim2.new(1, -6, 0, height or 34), TextWrapped = true, LayoutOrder = order or 0,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, parent)
end

local function makeButton(parent, text, order, cb, color)
    local b = new("TextButton", {
        Text = text, Font = FONTB, TextSize = 16, TextColor3 = C.text,
        BackgroundColor3 = color or C.accent, Size = UDim2.new(1, -6, 0, 34), LayoutOrder = order or 0,
    }, parent)
    corner(b, 8)
    b.MouseButton1Click:Connect(cb)
    return b
end

----------------------------------------------------------------
-- หน้า: หลัก
----------------------------------------------------------------
local pMain = newPage("main", "หลัก")
makeToggle(pMain, "⚡ ออโต้สปาวการ์ด", false, function(v) State.AutoSpawn = v end, 1)
makeToggle(pMain, "🛒 ออโต้ซื้อการ์ด", false, function(v) State.AutoBuy = v end, 2)
makeToggle(pMain, "🛡️ Anti AFK (กันเตะ)", true, function(v) State.AntiAFK = v end, 3)
local stats = makeLabel(pMain, "", 4, 40)
makeLabel(pMain, "💡 เลือกแพ็ก/สถานะที่ต้องการในแท็บถัดไป ถ้าไม่เลือกเลยจะซื้อทุกอย่าง\nซ่อน/แสดงเมนู: RightShift", 5, 60)
task.spawn(function()
    while State.Running do
        stats.Text = ("สปาวไปแล้ว: %d  |  กดซื้อไปแล้ว: %d"):format(State.SpawnCount, State.BuyCount)
        task.wait(0.5)
    end
end)

----------------------------------------------------------------
-- หน้า: แพ็ก
----------------------------------------------------------------
local pPacks = newPage("packs", "แพ็ก")
makeLabel(pPacks, "เลือกแพ็กที่จะซื้อ (ไม่เลือกเลย = ซื้อทุกแพ็ก)\nแพ็กใหม่บนสายพานจะเพิ่มในรายการเอง", 0, 40)
local packSetters = {}
function ensurePack(name)
    if packSetters[name] then return end
    State.Packs[name] = false
    packSetters[name] = makeToggle(pPacks, name, false, function(v) State.Packs[name] = v end, 10)
end
for _, n in ipairs(PACK_LIST) do ensurePack(n) end
makeButton(pPacks, "ล้างการเลือกทั้งหมด", 1, function()
    for n, set in pairs(packSetters) do set(false); State.Packs[n] = false end
end, C.off)

----------------------------------------------------------------
-- หน้า: สถานะ
----------------------------------------------------------------
local pStatus = newPage("status", "สถานะ")
makeLabel(pStatus, "เลือกสถานะที่จะซื้อ (ไม่เลือกเลย = ซื้อทุกสถานะ)\nเช็คจากข้อความบนป้ายของแพ็กบนสายพาน", 0, 40)
local statusSetters = {}
local function ensureStatus(name)
    if statusSetters[name] then return end
    State.Status[name] = false
    statusSetters[name] = makeToggle(pStatus, name, false, function(v) State.Status[name] = v end, 10)
end
for _, n in ipairs(STATUS_LIST) do ensureStatus(n) end

local box = new("TextBox", {
    PlaceholderText = "พิมพ์ชื่อสถานะเพิ่ม แล้วกดปุ่มด้านล่าง", Text = "", Font = FONT, TextSize = 16,
    TextColor3 = C.text, PlaceholderColor3 = C.sub, BackgroundColor3 = C.panel,
    Size = UDim2.new(1, -6, 0, 34), LayoutOrder = 1, ClearTextOnFocus = false,
}, pStatus)
corner(box, 8)
makeButton(pStatus, "+ เพิ่มสถานะ", 2, function()
    local t = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then ensureStatus(t); box.Text = "" end
end)
makeButton(pStatus, "ล้างการเลือกทั้งหมด", 3, function()
    for n, set in pairs(statusSetters) do set(false); State.Status[n] = false end
end, C.off)

----------------------------------------------------------------
-- ปุ่มระบบ
----------------------------------------------------------------
local minimized = false
btnMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(main, TweenInfo.new(0.2), {
        Size = minimized and UDim2.fromOffset(360, 40) or UDim2.fromOffset(360, 430),
    }):Play()
end)
btnClose.MouseButton1Click:Connect(function()
    State.Running = false
    State.AutoSpawn, State.AutoBuy, State.AntiAFK = false, false, false
    afkConn:Disconnect()
    gui:Destroy()
end)
UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
end)

showPage("main")
