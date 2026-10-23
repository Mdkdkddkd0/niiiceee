local __SDWGXYZ_OK, __SDWGXYZ_ERR = pcall(function()
--[[
 Аварийный ключ: SdwgAdmin2026
    SdwgXyz v2.0 — Full UI + Logic
    Author: Sdwg.xyz
    Style: dark monochrome, sliding selector, shimmer, vector icons
]]

if _G.SdwgXyzUnload then pcall(_G.SdwgXyzUnload) end

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local TextService      = game:GetService("TextService")
local GuiService       = game:GetService("GuiService")
local HttpService      = game:GetService("HttpService")
local Stats            = game:GetService("Stats")
local TeleportService  = game:GetService("TeleportService")
local KEY_CONFIG = {
    serverUrl = "https://sdwg-key-server.onrender.com/check",
    saveFile  = "sdwg_key.txt",
    minLen    = 8,
}

local function getHWID()
    local parts = { tostring(player.UserId), tostring(game.PlaceId) }
    pcall(function() if gethwid then table.insert(parts, gethwid()) end end)
    pcall(function() if syn and syn.get_hwid then table.insert(parts, syn.get_hwid()) end end)
    local str = table.concat(parts, "|")
    local hash = 0
    for i = 1, #str do hash = (hash * 31 + string.byte(str, i)) % 2147483647 end
    return string.format("%08X", hash)
end

local function saveKeyToFile(key) pcall(function() if writefile then writefile(KEY_CONFIG.saveFile, key) end end) end

local function loadKeyFromFile()
    local key
    pcall(function() 
        if isfile and isfile(KEY_CONFIG.saveFile) and readfile then 
            key = readfile(KEY_CONFIG.saveFile):gsub("%s+", "") 
            if key == "" then key = nil end 
        end 
    end)
    return key
end

local function deleteKeyFile() pcall(function() if delfile and isfile and isfile(KEY_CONFIG.saveFile) then delfile(KEY_CONFIG.saveFile) end end) end

local function validateKey(key)
    -- 1. СЕКРЕТНЫЙ ПАРОЛЬ (Пускает ВСЕГДА)
    if key == "SdwgAdmin2026" then 
        return true, 9999999999 
    end

    -- 2. Если ключ сохранен из прошлого раза, тоже пускаем
    local saved = loadKeyFromFile()
    if saved and saved == key then
        return true, 9999999999
    end

    -- 3. Любой ключ длиннее 8 символов ПУСКАЕМ (временно, пока нет сети)
    if key and #key >= 8 then
        return true, 9999999999
    end

    return false, "key too short"
end
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- ============================================================
-- 0. УТИЛИТЫ
-- ============================================================
local toggleKey  = Enum.KeyCode.RightShift
local blurSize   = 16
local connections = {}
local gradients   = {}
local keyListener

local bgColor     = Color3.fromRGB(14, 14, 14)
local panelColor  = Color3.fromRGB(20, 20, 20)
local elemColor   = Color3.fromRGB(27, 27, 27)
local hoverColor  = Color3.fromRGB(36, 36, 36)
local strokeColor = Color3.fromRGB(42, 42, 42)
local textColor   = Color3.fromRGB(230, 230, 230)
local dimColor    = Color3.fromRGB(120, 120, 120)
local mutedColor  = Color3.fromRGB(85, 85, 85)
local accentColor = Color3.fromRGB(255, 255, 255)

local function connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(connections, c)
    return c
end

local function create(cls, props)
    local inst = Instance.new(cls)
    local parent = props.Parent
    props.Parent = nil
    for k, v in pairs(props) do inst[k] = v end
    inst.Parent = parent
    return inst
end

local function addCorner(inst, r)
    create("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = inst })
end
local function makeRound(inst)
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = inst })
end
local function addStroke(inst, color)
    return create("UIStroke", {
        Color = color or strokeColor, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst,
    })
end
local function tween(inst, t, props, dir, style)
    local tw = TweenService:Create(inst, TweenInfo.new(
        t or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function addGradient(target)
    local g = create("UIGradient", { Parent = target })
    table.insert(gradients, g)
    return g
end
local function shimmerSeq(t)
    local kps = {}
    for i = 0, 8 do
        local x = i / 8
        local v = 0.5 + 0.5 * math.sin((x - t) * math.pi * 2)
        local c = math.floor(80 + v * 175)
        kps[#kps + 1] = ColorSequenceKeypoint.new(x, Color3.fromRGB(c, c, c))
    end
    return ColorSequence.new(kps)
end
local function line(parent, x1, y1, x2, y2, th, color)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local f = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
        Size = UDim2.fromOffset(len + th * 0.6, th),
        Rotation = math.deg(math.atan2(dy, dx)),
        BackgroundColor3 = color or dimColor,
        BorderSizePixel = 0, Parent = parent,
    })
    makeRound(f)
    return f
end
local function dot(parent, x, y, size)
    local f = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = dimColor, BorderSizePixel = 0, Parent = parent,
    })
    makeRound(f)
    return f
end

local function getHumanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function findTool(p, name)
    local char, bp = p and p.Character, p and p:FindFirstChildOfClass("Backpack")
    return char and char:FindFirstChild(name) or bp and bp:FindFirstChild(name)
end

local function alive(p)
    local char = p and p.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hrp and hum and hum.Health > 0 then return hrp, hum, char end
end

local function getPing()
    local ok, ping = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(ping) == "number" then return ping end
    ok, ping = pcall(function() return player:GetNetworkPing() * 2000 end)
    return ok and ping or 0
end

-- Лобби MM2
local lobbyCache, lobbyCFrame, lobbyHalfSize, lobbyCacheAt
local function inLobby(pos)
    local now = os.clock()
    if not lobbyCacheAt or now - lobbyCacheAt > 1 or not lobbyCache or not lobbyCache.Parent then
        lobbyCacheAt = now
        lobbyCache = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("RegularLobby")
        lobbyCFrame, lobbyHalfSize = nil, nil
        if lobbyCache then
            local ok, cf, size = pcall(lobbyCache.GetBoundingBox, lobbyCache)
            if ok then
                lobbyCFrame = cf
                lobbyHalfSize = size / 2 + Vector3.new(10, 30, 10)
            end
        end
    end
    if not lobbyCFrame then return false end
    local rel = lobbyCFrame:PointToObjectSpace(pos)
    return math.abs(rel.X) <= lobbyHalfSize.X
       and math.abs(rel.Y) <= lobbyHalfSize.Y
       and math.abs(rel.Z) <= lobbyHalfSize.Z
end

-- Роли через серверный RemoteFunction GetPlayerData
local roleCache, roleCacheAt = {}, 0
local function refreshRoles()
    if os.clock() - roleCacheAt < 1 then return end
    roleCacheAt = os.clock()
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("GetPlayerData", true)
    if not (remote and remote:IsA("RemoteFunction")) then return end
    local ok, data = pcall(remote.InvokeServer, remote)
    if not ok or type(data) ~= "table" then return end
    local newRoles = {}
    for name, info in pairs(data) do
        if type(info) == "table" and type(info.Role) == "string"
            and not info.Dead and not info.Killed then
            newRoles[name] = info.Role
        end
    end
    roleCache = newRoles
end

local function hasRole(p, role)
    if role == "Murderer" and findTool(p, "Knife") then return true end
    if role == "Sheriff" and findTool(p, "Gun") then return true end
    local v = roleCache[p.Name]
    return (role == "Murderer" and v == "Murderer")
        or (role == "Sheriff" and (v == "Sheriff" or v == "Hero"))
end

-- ============================================================
-- 1. ВЕКТОРНЫЕ ИКОНКИ
-- ============================================================
local function createIcon(kind, parent)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1,
        ZIndex = 3, Parent = parent,
    })
    local scale = create("UIScale", { Parent = holder })
    local parts = {}
    local function add(inst, prop) table.insert(parts, { inst, prop or "BackgroundColor3" }) end

    if kind == "move" then
        add(dot(holder, 11.5, 2.8, 4.6))
        for _, s in ipairs({
            {10,6,8,11},{9.6,7,12.6,9},{12.6,9,15,7.4},
            {9.6,7,6.6,8.6},{6.6,8.6,4.6,7},{8,11,11,13.4},
            {11,13.4,10.6,17},{8,11,6,14},{6,14,2.6,15}
        }) do add(line(holder, s[1], s[2], s[3], s[4], 2)) end
    elseif kind == "eye" then
        local eye = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 9),
            Size = UDim2.fromOffset(16, 10), BackgroundTransparency = 1, Parent = holder,
        })
        makeRound(eye)
        add(create("UIStroke", { Color = dimColor, Thickness = 1.6, Parent = eye }), "Color")
        add(dot(holder, 9, 9, 5))
    elseif kind == "sliders" then
        for _, r in ipairs({ {4,6},{9,12},{14,8} }) do
            add(line(holder, 2, r[1], 16, r[1], 1.6))
            add(dot(holder, r[2], r[1], 5))
        end
    elseif kind == "star" then
        add(line(holder, 9, 1.5, 9, 16.5, 2))
        add(line(holder, 1.5, 9, 16.5, 9, 2))
        add(line(holder, 5, 5, 13, 13, 1.4))
        add(line(holder, 13, 5, 5, 13, 1.4))
        add(dot(holder, 9, 9, 5))
    elseif kind == "gear" then
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 9),
            Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = holder,
        })
        makeRound(ring)
        add(create("UIStroke", { Color = dimColor, Thickness = 2.6, Parent = ring }), "Color")
        for i = 0, 7 do
            local a = math.rad(i * 45)
            add(line(holder,
                9 + math.cos(a) * 5.5, 9 + math.sin(a) * 5.5,
                9 + math.cos(a) * 8,   9 + math.sin(a) * 8, 3))
        end
    elseif kind == "target" then
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 9),
            Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = holder,
        })
        makeRound(ring)
        add(create("UIStroke", { Color = dimColor, Thickness = 1.6, Parent = ring }), "Color")
        add(line(holder, 9, 0.5, 9, 4.5, 1.6))
        add(line(holder, 9, 13.5, 9, 17.5, 1.6))
        add(line(holder, 0.5, 9, 4.5, 9, 1.6))
        add(line(holder, 13.5, 9, 17.5, 9, 1.6))
        add(dot(holder, 9, 9, 3))
    elseif kind == "smile" then
        add(dot(holder, 5.5, 6, 3.4))
        add(dot(holder, 12.5, 6, 3.4))
        add(line(holder, 4, 11, 6.8, 13.8, 2))
        add(line(holder, 6.8, 13.8, 11.2, 13.8, 2))
        add(line(holder, 11.2, 13.8, 14, 11, 2))
    elseif kind == "bolt" then
        add(line(holder, 12, 1.5, 5.5, 10, 2.4))
        add(line(holder, 5.5, 10, 12.5, 8, 2.4))
        add(line(holder, 12.5, 8, 6, 16.5, 2.4))
    elseif kind == "globe" then
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 9),
            Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Parent = holder,
        })
        makeRound(ring)
        add(create("UIStroke", { Color = dimColor, Thickness = 1.5, Parent = ring }), "Color")
        local meridian = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 9),
            Size = UDim2.fromOffset(7, 16), BackgroundTransparency = 1, Parent = holder,
        })
        makeRound(meridian)
        add(create("UIStroke", { Color = dimColor, Thickness = 1.3, Parent = meridian }), "Color")
        add(line(holder, 1.5, 9, 16.5, 9, 1.3))
        add(line(holder, 3, 5, 15, 5, 1.1))
        add(line(holder, 3, 13, 15, 13, 1.1))
    elseif kind == "drone" then
        for _, c in ipairs({ {4,4},{14,4},{4,14},{14,14} }) do
            add(line(holder, 9, 9, c[1], c[2], 1.8))
            local r = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c[1], c[2]),
                Size = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, Parent = holder,
            })
            makeRound(r)
            add(create("UIStroke", { Color = dimColor, Thickness = 1.4, Parent = r }), "Color")
        end
        add(dot(holder, 9, 9, 5))
    elseif kind == "grid" then
        for _, p in ipairs({ {4.5,4.5},{13.5,4.5},{4.5,13.5},{13.5,13.5} }) do
            local sq = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p[1], p[2]),
                Size = UDim2.fromOffset(6.5, 6.5), BackgroundColor3 = dimColor,
                BorderSizePixel = 0, Parent = holder,
            })
            addCorner(sq, 2)
            add(sq)
        end
    elseif kind == "pin" then
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 7),
            Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = holder,
        })
        makeRound(ring)
        add(create("UIStroke", { Color = dimColor, Thickness = 1.8, Parent = ring }), "Color")
        add(line(holder, 4.8, 9.6, 9, 16.5, 1.8))
        add(line(holder, 13.2, 9.6, 9, 16.5, 1.8))
        add(dot(holder, 9, 7, 3))
    end

    local icon = {}
    icon.color = function(c, t)
        for _, p in ipairs(parts) do
            tween(p[1], t or 0.2, { [p[2]] = c })
        end
    end
    icon.pop = function()
        scale.Scale = 0.7
        tween(scale, 0.35, { Scale = 1 }, Enum.EasingDirection.Out, Enum.EasingStyle.Back)
    end
    return icon
end

-- ============================================================
-- 2. SCREEN GUI
-- ============================================================
local gui = create("ScreenGui", {
    Name = "Sdwg.xyz", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
})
local parented = false
if gethui then parented = pcall(function() gui.Parent = gethui() end) end
if not parented then parented = pcall(function() gui.Parent = game:GetService("CoreGui") end) end
if not parented then gui.Parent = player:WaitForChild("PlayerGui") end
pcall(function()
    gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    gui.ClipToDeviceSafeArea = true
end)

local blur = create("BlurEffect", { Name = "SdwgBlur", Size = 0, Parent = Lighting })

-- ============================================================
-- 3. ГЛАВНОЕ ОКНО + ТОП-БАР
-- ============================================================
local main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(680, 470),
    BackgroundColor3 = bgColor, BorderSizePixel = 0, Visible = false,
    ZIndex = 2, Parent = gui,
})
addCorner(main, 10)
local mainStroke = create("UIStroke", { Thickness = 1, Color = accentColor, Transparency = 0.3, Parent = main })
addGradient(mainStroke)
local mainScale = create("UIScale", { Scale = 0, Parent = main })
local menuOpen = false
local responsiveScale = 1

local topBar = create("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = main })

local logo = create("TextLabel", {
    Text = "Sdwg.xyz t.me/Sdwg_xyz",
    Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = accentColor,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 205, 1, 0),
    Parent = topBar,
})
addGradient(logo)

create("TextLabel", {
    Text = "v2.0", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = dimColor,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
    Position = UDim2.fromOffset(219, 1), Size = UDim2.new(0, 40, 1, 0), Parent = topBar,
})

local closeBtn = create("TextButton", {
    Text = "x", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = dimColor,
    BackgroundColor3 = elemColor, BackgroundTransparency = 1, AutoButtonColor = false,
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(24, 24), Parent = topBar,
})
addCorner(closeBtn, 6)
connect(closeBtn.MouseEnter, function() tween(closeBtn, 0.15, { TextColor3 = accentColor, BackgroundTransparency = 0 }) end)
connect(closeBtn.MouseLeave, function() tween(closeBtn, 0.15, { TextColor3 = dimColor, BackgroundTransparency = 1 }) end)

local headerLine = create("Frame", {
    Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = accentColor, BorderSizePixel = 0, Parent = main,
})
addGradient(headerLine)

-- ============================================================
-- 4. САЙДБАР + СЕЛЕКТОР
-- ============================================================
local sidebar = create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 39), Size = UDim2.new(0, 170, 1, -39),
    BackgroundTransparency = 1, ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
    CanvasSize = UDim2.new(), Parent = main,
})

local tabSelector = create("Frame", {
    Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, 32),
    BackgroundColor3 = accentColor, BorderSizePixel = 0, ZIndex = 1, Parent = sidebar,
})
addCorner(tabSelector, 8)
create("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(105,105,105), Color3.fromRGB(62,62,62)),
    Parent = tabSelector,
})
local selectorStroke = create("UIStroke", {
    Color = accentColor, Thickness = 1, Transparency = 0.75,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tabSelector,
})
local sweepGradient = create("UIGradient", { Parent = selectorStroke })
local sweepSeq = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 1),
    NumberSequenceKeypoint.new(0.85, 0.2),
    NumberSequenceKeypoint.new(1, 0),
})
local sweepId, sweepTween = 0, nil
local function playSweep()
    sweepId += 1
    local id = sweepId
    if sweepTween then sweepTween:Cancel() end
    sweepGradient.Transparency = sweepSeq
    sweepGradient.Rotation = -90
    sweepTween = tween(sweepGradient, 0.5, { Rotation = 270 }, Enum.EasingDirection.InOut, Enum.EasingStyle.Sine)
    sweepTween.Completed:Connect(function(state)
        if id ~= sweepId or state ~= Enum.PlaybackState.Completed then return end
        sweepGradient.Transparency = NumberSequence.new(0)
        selectorStroke.Transparency = 0.4
        tween(selectorStroke, 0.4, { Transparency = 0.75 })
    end)
end

local tabList = create("Frame", {
    Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 1, -10),
    BackgroundTransparency = 1, ZIndex = 2, Parent = sidebar,
})
local tabLayout = create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })

create("Frame", {
    Position = UDim2.fromOffset(170, 39), Size = UDim2.new(0, 1, 1, -39),
    BackgroundColor3 = strokeColor, BorderSizePixel = 0, Parent = main,
})

local content = create("Frame", {
    Position = UDim2.fromOffset(184, 50), Size = UDim2.new(1, -196, 1, -60),
    BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 1, Parent = main,
})
local fadeOverlay = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = bgColor,
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Parent = content,
})

local tabs = {}
local currentTab
local tabY, layoutOrder = 10, 0

local function selectTab(tab)
    if currentTab == tab then return end
    local old = currentTab
    currentTab = tab
    for _, t in ipairs(tabs) do if t ~= tab then t.page.Visible = false end end
    local y = tab.y
    if old then
        tween(tabSelector, 0.3, { Position = UDim2.fromOffset(8, y) },
            Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
    else
        tabSelector.Position = UDim2.fromOffset(8, y)
    end
    playSweep()
    if old then
        tween(old.label, 0.2, { TextColor3 = dimColor })
        old.label.Font = Enum.Font.GothamMedium
        old.icon.color(dimColor)
        tween(old.chevron, 0.3, { Rotation = 0 }, Enum.EasingDirection.Out, Enum.EasingStyle.Back)
    end
    tween(tab.label, 0.2, { TextColor3 = accentColor })
    tab.label.Font = Enum.Font.GothamBold
    tab.icon.color(accentColor)
    tab.icon.pop()
    tween(tab.chevron, 0.3, { Rotation = 90 }, Enum.EasingDirection.Out, Enum.EasingStyle.Back)
    tab.page.CanvasPosition = Vector2.zero
    tab.page.Position = UDim2.fromOffset(0, 14)
    tab.page.Visible = true
    tween(tab.page, 0.35, { Position = UDim2.fromOffset(0, 0) },
        Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
    fadeOverlay.BackgroundTransparency = 0
    tween(fadeOverlay, 0.3, { BackgroundTransparency = 1 })
end

-- Раскладка таба с учётом поиска
local searchTerms
local function layoutTab(tab)
    if tab.custom then return end
    local y = 46
    if searchTerms then
        for _, s in ipairs(tab.sections) do
            local rowY, any = 30, false
            for _, item in ipairs(s.items) do
                local key = item.key .. " " .. s.name:lower() .. " " .. tab.label.Text:lower()
                local ok = true
                for _, w in ipairs(searchTerms) do
                    if not key:find(w, 1, true) then ok = false; break end
                end
                item.row.Visible = ok
                if ok then
                    item.row.Position = UDim2.fromOffset(8, rowY)
                    rowY += item.h + 6
                    any = true
                end
            end
            s.card.Visible = any
            if any then
                local h = rowY + 8 - 6
                s.card.Position = UDim2.fromOffset(2, y)
                s.card.Size = UDim2.new(1, -8, 0, h)
                y += h + 10
            end
        end
        tab.page.CanvasSize = UDim2.fromOffset(0, y - 10 + 6)
        return
    end
    for _, s in ipairs(tab.sections) do
        s.card.Visible = not tab.subs or s.group == tab.sub
        if s.card.Visible then
            s.card.Position = UDim2.fromOffset(2, y)
            s.card.Size = UDim2.new(1, -8, 0, s.height)
            y += s.height + 10
        end
    end
    tab.page.CanvasSize = UDim2.fromOffset(0, y - 10 + 6)
end

local function addTab(name, iconName, desc)
    layoutOrder += 1
    local y = tabY
    tabY += 35

    local tabBtn = create("TextButton", {
        Text = "", BackgroundColor3 = elemColor, BackgroundTransparency = 1,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 32),
        LayoutOrder = layoutOrder, Parent = tabList,
    })
    addCorner(tabBtn, 7)

    local icon = createIcon(iconName, tabBtn)

    local label = create("TextLabel", {
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = dimColor,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -60, 1, 0),
        ZIndex = 3, Parent = tabBtn,
    })

    local chevron = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(6, 10), BackgroundTransparency = 1, ZIndex = 3, Parent = tabBtn,
    })
    local ct = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(2, 2.5),
        Size = UDim2.fromOffset(5, 1.5), BackgroundColor3 = mutedColor,
        BorderSizePixel = 0, Parent = chevron,
    })
    makeRound(ct)
    local cb = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(2, 7.5),
        Size = UDim2.fromOffset(5, 1.5), BackgroundColor3 = mutedColor,
        BorderSizePixel = 0, Parent = chevron,
    })
    makeRound(cb)

    local page = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = dimColor,
        CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        VerticalScrollBarInset = Enum.ScrollBarInset.Always,
        ScrollBarImageTransparency = 0.4, ClipsDescendants = true,
        Visible = false, ZIndex = 1, Parent = content,
    })
    create("TextLabel", {
        Text = name, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = accentColor,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 22), Parent = page,
    })
    create("TextLabel", {
        Text = desc or "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = dimColor,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -8, 0, 16), Parent = page,
    })

    local tab = {
        index = #tabs + 1, y = y, btn = tabBtn, label = label, icon = icon,
        chevron = chevron, page = page, sections = {}, custom = false,
    }
    table.insert(tabs, tab)

    connect(tabBtn.MouseButton1Click, function() selectTab(tab) end)
    connect(tabBtn.MouseEnter, function()
        if currentTab ~= tab then
            tween(label, 0.15, { TextColor3 = textColor })
            icon.color(textColor, 0.15)
        end
    end)
    connect(tabBtn.MouseLeave, function()
        if currentTab ~= tab then
            tween(label, 0.15, { TextColor3 = dimColor })
            icon.color(dimColor, 0.15)
        end
    end)
    return tab
end

local function setSubTabs(tab, items)
    tab.subs = items
    tab.sub  = items[1]
    local cur = 1
    local titleW = TextService:GetTextSize(tab.page:FindFirstChildOfClass("TextLabel").Text,
        18, Enum.Font.GothamBold, Vector2.new(400, 40)).X
    local bar = create("Frame", {
        Position = UDim2.fromOffset(titleW + 16, 6),
        Size = UDim2.new(1, -(titleW + 16) - 8, 0, 28),
        BackgroundTransparency = 1, ZIndex = 3, Parent = tab.page,
    })
    local subButtons = {}
    local x = 0
    for i, sub in ipairs(items) do
        local tw = TextService:GetTextSize(sub, 12, Enum.Font.GothamMedium, Vector2.new(300, 40)).X
        local w = tw + 34
        local b = create("TextButton", {
            Text = "", AutoButtonColor = false,
            BackgroundColor3 = Color3.fromRGB(90, 90, 90),
            BackgroundTransparency = i == cur and 0.35 or 1,
            Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 28),
            ZIndex = 3, Parent = bar,
        })
        addCorner(b, 9)
        local pip = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 13, 0.5, 0),
            Size = UDim2.fromOffset(i == cur and 6 or 0, i == cur and 6 or 0),
            BackgroundColor3 = accentColor, BorderSizePixel = 0, ZIndex = 4, Parent = b,
        })
        makeRound(pip)
        local lbl = create("TextLabel", {
            Text = sub, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = i == cur and accentColor or dimColor,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(i == cur and 22 or 12, 0),
            Size = UDim2.new(1, -22, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = b,
        })
        subButtons[i] = { b = b, dot = pip, lbl = lbl }
        x += w + 4
    end

    local function refresh(i, on)
        local o = subButtons[i]
        tween(o.b, 0.25, { BackgroundTransparency = on and 0.35 or 1 },
            Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
        tween(o.dot, 0.25, { Size = UDim2.fromOffset(on and 6 or 0, on and 6 or 0) },
            Enum.EasingDirection.Out, Enum.EasingStyle.Back)
        tween(o.lbl, 0.25, {
            TextColor3 = on and accentColor or dimColor,
            Position = UDim2.fromOffset(on and 22 or 12, 0),
        }, Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
    end

    local function set(i)
        if i == cur then return end
        refresh(cur, false)
        cur = i
        tab.sub = items[i]
        refresh(i, true)
        layoutTab(tab)
        tab.page.CanvasPosition = Vector2.zero
    end

    for i, o in ipairs(subButtons) do
        connect(o.b.MouseButton1Click, function() set(i) end)
        connect(o.b.MouseEnter, function()
            if i ~= cur then tween(o.lbl, 0.15, { TextColor3 = textColor }) end
        end)
        connect(o.b.MouseLeave, function()
            if i ~= cur then tween(o.lbl, 0.15, { TextColor3 = dimColor }) end
        end)
    end
    layoutTab(tab)
end

-- ============================================================
-- 5. СЕКЦИИ И КОНТРОЛЫ
-- ============================================================
local Section = {}
Section.__index = Section

local function addSection(tab, name, group)
    local card = create("Frame", { BackgroundColor3 = panelColor, Parent = tab.page })
    addCorner(card, 10)
    local stroke = addStroke(card)
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(accentColor, Color3.fromRGB(190, 190, 190)),
        Parent = card,
    })
    local highlight = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0, 15),
        Size = UDim2.fromOffset(3, 12), BackgroundColor3 = accentColor,
        BorderSizePixel = 0, Parent = card,
    })
    makeRound(highlight)
    addGradient(highlight)
    create("TextLabel", {
        Text = string.upper(name), Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = textColor, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0),
        Size = UDim2.new(1, -34, 0, 30), Parent = card,
    })
    connect(card.MouseEnter, function() tween(stroke, 0.2, { Color = Color3.fromRGB(56, 56, 56) }) end)
    connect(card.MouseLeave, function() tween(stroke, 0.2, { Color = strokeColor }) end)

    local s = setmetatable({
        tab = tab, card = card, name = name,
        items = {}, rows = {}, y = 30, height = 32,
        group = group or tab.subs and tab.subs[1],
    }, Section)
    table.insert(tab.sections, s)
    layoutTab(tab)
    return s
end

function Section:_row(name, desc, height)
    local h = height or (desc and 40 or 32)
    local row = create("TextButton", {
        Text = "", BackgroundColor3 = elemColor, AutoButtonColor = false,
        Position = UDim2.fromOffset(8, self.y), Size = UDim2.new(1, -16, 0, h),
        ClipsDescendants = true, Parent = self.card,
    })
    addCorner(row, 7)
    local rowStroke = addStroke(row)
    table.insert(self.rows, row)
    table.insert(self.items, {
        row = row, y = self.y, h = h, name = name, desc = desc,
        key = (name .. " " .. (desc or "")):lower(),
    })

    local accent = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(2, 0), BackgroundColor3 = accentColor,
        BorderSizePixel = 0, ZIndex = 2, Parent = row,
    })
    addCorner(accent, 1)

    local title = create("TextLabel", {
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = textColor,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(12, desc and 6 or 0),
        Size = UDim2.new(1, -150, 0, desc and 15 or h), Parent = row,
    })
    if desc then
        create("TextLabel", {
            Text = desc, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = mutedColor,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 21),
            Size = UDim2.new(1, -150, 0, 13), Parent = row,
        })
    end

    local hovered, active = false, false
    local function refresh()
        tween(accent, 0.3, { Size = UDim2.fromOffset(2, active and h - 14 or (hovered and 12 or 0)) },
            Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
        tween(row, 0.15, { BackgroundColor3 = hovered and hoverColor or elemColor })
        tween(title, 0.2, {
            TextColor3 = (hovered or active) and accentColor or textColor,
            Position = UDim2.fromOffset(hovered and 15 or 12, title.Position.Y.Offset),
        }, Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
        tween(rowStroke, 0.2, { Color = active and Color3.fromRGB(88,88,88)
            or (hovered and Color3.fromRGB(62,62,62) or strokeColor) })
    end
    connect(row.MouseEnter, function() hovered = true; refresh() end)
    connect(row.MouseLeave, function() hovered = false; refresh() end)

    self.y += h + 6
    self.height = self.y + 8 - 6
    layoutTab(self.tab)
    return row, title, function(on) active = on; refresh() end
end

function Section:Toggle(name, desc, callback)
    local state = false
    local row, _, highlight = self:_row(name, desc)
    local track = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(34, 18), BackgroundColor3 = bgColor,
        BorderSizePixel = 0, Parent = row,
    })
    makeRound(track)
    local trackStroke = addStroke(track)
    local glow = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = accentColor,
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = track,
    })
    makeRound(glow)
    create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(150,150,150), accentColor), Parent = glow })
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 9, 0.5, 0),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = dimColor,
        BorderSizePixel = 0, ZIndex = 2, Parent = track,
    })
    makeRound(knob)

    local function apply(v, silent)
        state = v
        knob.Size = UDim2.fromOffset(18, 12)
        tween(knob, 0.35, {
            Position = UDim2.new(0, state and 25 or 9, 0.5, 0),
            Size = UDim2.fromOffset(12, 12),
            BackgroundColor3 = state and bgColor or dimColor,
        }, Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
        tween(glow, 0.25, { BackgroundTransparency = state and 0 or 1 })
        tween(trackStroke, 0.25, { Color = state and accentColor or strokeColor })
        highlight(state)
        if not silent then task.spawn(callback, state) end
    end
    connect(row.MouseButton1Click, function() apply(not state) end)
    return { Set = function(v, s) if v ~= state then apply(v, s) end end, Get = function() return state end }
end

function Section:Slider(name, min, max, default, callback, fmt)
    fmt = fmt or tostring
    local row, title = self:_row(name, nil, 44)
    title.Position = UDim2.fromOffset(12, 7)
    title.Size = UDim2.new(1, -70, 0, 16)
    local valueLabel = create("TextLabel", {
        Text = fmt(default), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = textColor,
        BackgroundColor3 = bgColor, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(50, 18), Parent = row,
    })
    addCorner(valueLabel, 6)
    local valueStroke = addStroke(valueLabel)
    local bar = create("Frame", {
        Position = UDim2.new(0, 12, 0, 31), Size = UDim2.new(1, -24, 0, 5),
        BackgroundColor3 = bgColor, BorderSizePixel = 0, Parent = row,
    })
    makeRound(bar)
    addStroke(bar)
    local pct = (default - min) / (max - min)
    local fill = create("Frame", {
        Size = UDim2.new(pct, 6 - 12 * pct, 1, 0), BackgroundColor3 = accentColor,
        BorderSizePixel = 0, Parent = bar,
    })
    makeRound(fill)
    create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(95,95,95), accentColor), Parent = fill })
    local track = create("Frame", {
        Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 1, 0),
        BackgroundTransparency = 1, ZIndex = 2, Parent = bar,
    })
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(pct, 0.5),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = accentColor,
        BorderSizePixel = 0, ZIndex = 2, Parent = track,
    })
    makeRound(knob)
    create("UIStroke", { Color = elemColor, Thickness = 2, Parent = knob })
    local hit = create("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 22),
        ZIndex = 3, Parent = row,
    })
    local last = default
    local function render(val, t)
        local r = (val - min) / (max - min)
        tween(knob, t, { Position = UDim2.fromScale(r, 0.5) }, Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
        tween(fill, t, { Size = UDim2.new(r, 6 - 12 * r, 1, 0) }, Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
        valueLabel.Text = fmt(val)
    end
    local dragging = false
    local function set(x)
        local w = math.max(track.AbsoluteSize.X, 1)
        local rel = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        local val = math.floor(min + (max - min) * rel + 0.5)
        render(val, 0.08)
        if val ~= last then last = val; task.spawn(callback, val) end
    end
    connect(hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            set(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            set(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
        end
    end)
    return { Set = function(v, s) render(v, 0.3); last = v; if not s then task.spawn(callback, v) end end,
             Get = function() return last end }
end
function Section:Keybind(name, desc, getKey, setKey)
    local row = self:_row(name, desc)
    local badge = create("TextLabel", {
        Text = getKey().Name, Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = textColor, TextTruncate = Enum.TextTruncate.AtEnd,
        BackgroundColor3 = bgColor,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(84, 22), Parent = row,
    })
    addCorner(badge, 6)
    local badgeStroke = addStroke(badge)
    connect(row.MouseButton1Click, function()
        if keyListener then return end
        badge.Text = "press a key..."
        tween(badgeStroke, 0.15, { Color = accentColor })
        tween(badge, 0.15, { BackgroundColor3 = hoverColor })
        keyListener = function(k)
            if k and k ~= Enum.KeyCode.Escape then
                setKey(k)
            end
            badge.Text = getKey().Name
            tween(badgeStroke, 0.3, { Color = strokeColor })
            tween(badge, 0.3, { BackgroundColor3 = bgColor })
        end
    end)
end
function Section:Button(name, desc, callback)
    local row = self:_row(name, desc)
    local holder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(22, 22), BackgroundColor3 = bgColor,
        ZIndex = 2, Parent = row,
    })
    makeRound(holder)
    local circleStroke = addStroke(holder)
    create("TextLabel", {
        Text = ">", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = dimColor,
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = holder,
    })
    connect(row.MouseEnter, function()
        tween(holder, 0.2, { BackgroundColor3 = accentColor })
        tween(circleStroke, 0.2, { Color = accentColor })
    end)
    connect(row.MouseLeave, function()
        tween(holder, 0.2, { BackgroundColor3 = bgColor })
        tween(circleStroke, 0.2, { Color = strokeColor })
    end)
    connect(row.MouseButton1Click, function()
        local w = row.AbsoluteSize.X * 1.15
        local ripple = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(0, 0), BackgroundColor3 = accentColor,
            BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = row,
        })
        makeRound(ripple)
        tween(ripple, 0.55, { Size = UDim2.fromOffset(w, w), BackgroundTransparency = 1 })
        task.delay(0.6, function() ripple:Destroy() end)
        task.spawn(callback)
    end)
end

function Section:Segmented(name, options, default, callback)
    local cur = table.find(options, default) or 1
    local n = #options
    local row, title = self:_row(name, nil, 34)
    local totalW = n * 60
    title.Size = UDim2.new(1, -(totalW + 24), 1, 0)
    local pill = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.fromOffset(totalW, 24), BackgroundColor3 = bgColor, Parent = row,
    })
    addCorner(pill, 7)
    local pillStroke = addStroke(pill)
    local thumb = create("Frame", {
        Position = UDim2.new((cur - 1) / n, 2, 0, 2),
        Size = UDim2.new(1 / n, -4, 1, -4),
        BackgroundColor3 = accentColor, BorderSizePixel = 0, ZIndex = 2, Parent = pill,
    })
    addCorner(thumb, 6)
    create("UIGradient", { Rotation = 90, Color = ColorSequence.new(accentColor, Color3.fromRGB(185,185,185)), Parent = thumb })
    local buttons = {}
    for i, opt in ipairs(options) do
        local b = create("TextButton", {
            Text = opt, Font = i == cur and Enum.Font.GothamBold or Enum.Font.GothamMedium,
            TextSize = 11, TextColor3 = i == cur and bgColor or dimColor,
            BackgroundTransparency = 1, AutoButtonColor = false,
            Position = UDim2.fromScale((i - 1) / n, 0), Size = UDim2.fromScale(1 / n, 1),
            ZIndex = 3, Parent = pill,
        })
        buttons[i] = b
    end
    local function set(i, silent)
        if i == cur then return end
        tween(buttons[cur], 0.2, { TextColor3 = dimColor })
        buttons[cur].Font = Enum.Font.GothamMedium
        cur = i
        tween(buttons[i], 0.2, { TextColor3 = bgColor })
        buttons[i].Font = Enum.Font.GothamBold
        tween(thumb, 0.35, { Position = UDim2.new((i - 1) / n, 2, 0, 2) },
            Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
        pillStroke.Color = accentColor
        tween(pillStroke, 0.45, { Color = strokeColor })
        if not silent then task.spawn(callback, options[i]) end
    end
    for i, b in ipairs(buttons) do
        connect(b.MouseButton1Click, function() set(i) end)
        connect(b.MouseEnter, function() if i ~= cur then tween(b, 0.15, { TextColor3 = textColor }) end end)
        connect(b.MouseLeave, function() if i ~= cur then tween(b, 0.15, { TextColor3 = dimColor }) end end)
    end
    return { Set = function(v, s) local i = table.find(options, v); if i then set(i, s) end end,
             Get = function() return options[cur] end }
end

function Section:Select(name, desc, options, default, callback)
    local cur = table.find(options, default) or 1
    local n = #options
    local row = self:_row(name, desc)
    local badge = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(130, 24), BackgroundColor3 = bgColor,
        ClipsDescendants = true, Parent = row,
    })
    addCorner(badge, 6)
    local badgeStroke = addStroke(badge)

    local dots = {}
    if n <= 8 then
        for i = 1, n do
            local d = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, (i - (n + 1) / 2) * 6, 1, -3),
                Size = UDim2.fromOffset(i == cur and 5 or 2, 2),
                BackgroundColor3 = i == cur and accentColor or mutedColor,
                BorderSizePixel = 0, ZIndex = 2, Parent = badge,
            })
            makeRound(d)
            dots[i] = d
        end
    end
    local lbl = create("TextLabel", {
        Text = options[cur], Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = textColor, TextTruncate = Enum.TextTruncate.AtEnd,
        BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, #dots > 0 and -2 or 0),
        Size = UDim2.new(1, -36, 1, 0), Parent = badge,
    })

    local function choose(i, silent)
        if i == cur then return end
        if dots[cur] then
            tween(dots[cur], 0.25, { Size = UDim2.fromOffset(2, 2), BackgroundColor3 = mutedColor })
        end
        cur = i
        if dots[cur] then
            tween(dots[cur], 0.25, { Size = UDim2.fromOffset(5, 2), BackgroundColor3 = accentColor },
                Enum.EasingDirection.Out, Enum.EasingStyle.Back)
        end
        lbl.Text = options[cur]
        badgeStroke.Color = accentColor
        tween(badgeStroke, 0.4, { Color = strokeColor })
        if not silent then task.spawn(callback, options[cur]) end
    end

    connect(row.MouseButton1Click, function() choose((cur - 1 + 1) % n + 1) end)
    connect(row.MouseButton2Click, function() choose((cur - 2 + n) % n + 1) end)
    return { Set = function(v, s) local i = table.find(options, v); if i then choose(i, s) end end,
             Get = function() return options[cur] end }
end

-- ============================================================
-- 6. СОСТОЯНИЕ ФИЧ
-- ============================================================
local charMods = { speed = nil, jump = nil, infJump = false, noclip = false, antiFling = false }
local noclipParts = {}
connect(RunService.Heartbeat, function()
    local hum = getHumanoid()
    if hum then
        if charMods.speed and hum.WalkSpeed ~= charMods.speed then hum.WalkSpeed = charMods.speed end
        if charMods.jump then
            hum.UseJumpPower = true
            if hum.JumpPower ~= charMods.jump then hum.JumpPower = charMods.jump end
        end
    end
end)
connect(RunService.Stepped, function()
    if not charMods.noclip then return end
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            noclipParts[part] = true
            part.CanCollide = false
        end
    end
end)
local function disableNoclip()
    charMods.noclip = false
    for part in pairs(noclipParts) do
        if part.Parent then part.CanCollide = true end
    end
    table.clear(noclipParts)
end

connect(UserInputService.JumpRequest, function()
    if not charMods.infJump then return end
    local hum = getHumanoid()
    if hum and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ============================================================
-- 7. ВКЛАДКИ
-- ============================================================
local function safeAddTab(name, icon, desc)
    local ok, tab = pcall(addTab, name, icon, desc)
    if not ok then
        local gui2 = Instance.new("ScreenGui", game:GetService("CoreGui"))
        local f = Instance.new("Frame", gui2)
        f.Size = UDim2.new(0, 600, 0, 200)
        f.Position = UDim2.new(0.5, -300, 0.5, -100)
        f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        local t = Instance.new("TextLabel", f)
        t.Size = UDim2.new(1, -20, 1, -20)
        t.Position = UDim2.new(0, 10, 0, 10)
        t.BackgroundTransparency = 1
        t.Text = "addTab('" .. name .. "') упал:\n\n" .. tostring(tab)
        t.TextColor3 = Color3.fromRGB(255, 100, 100)
        t.TextWrapped = true
        t.Font = Enum.Font.Code
        t.TextSize = 12
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextYAlignment = Enum.TextYAlignment.Top
        task.wait(5)
        error(tab)
    end
    return tab
end

local mainTab    = safeAddTab("Main", "gear", "speed, jumps and character")
local combatTab  = safeAddTab("Combat", "target", "silent aim, fling, desync")
local droneTab   = safeAddTab("Drone", "drone", "fly a Shahed or FPV drone")
local trollTab   = safeAddTab("Troll Fun", "smile", "fun and trolling")
local playersTab = safeAddTab("Players", "eye", "player list and quick actions")
local voteTab    = safeAddTab("Vote Dupe", "pin", "vote for a map over and over")
local animsTab   = safeAddTab("Free anims", "move", "animation packs")
local visualsTab = safeAddTab("Visuals", "globe", "shader, esp, backtrack")
setSubTabs(visualsTab, { "Shader", "ESP", "Models" })
local skinTab    = safeAddTab("Skin Changer", "star", "every MM2 skin")
local serverTab  = safeAddTab("Server", "globe", "server and utilities")
local settingsTab= safeAddTab("Settings", "sliders", "menu settings")
local worldTab   = safeAddTab("WorldSpace", "grid", "workspace scanner (beta)")

-- ============================================================
-- УВЕДОМЛЕНИЯ (notify)
-- ============================================================
local notifications = {}

local function layoutNotifications()
    for i, t in ipairs(notifications) do
        local y = -20 - (i - 1) * 68
        tween(t.card, 0.35, {
            Position = UDim2.new(1, -20, 1, y),
        }, Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
    end
end

local notify = function(head, body)
    if type(head) ~= "string" then return end
    local accent = accentColor
    local h = head:lower()
    if h:find("murderer") then accent = Color3.fromRGB(255, 70, 70) end
    if h:find("sheriff") then accent = Color3.fromRGB(70, 150, 255) end
    if h:find(": on") then accent = Color3.fromRGB(110, 230, 140) end
    if h:find(": off") then accent = Color3.fromRGB(150, 150, 158) end

    local card = create("TextButton", {
        Text = "", AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 330, 1, -20),
        Size = UDim2.fromOffset(270, 58),
        BackgroundColor3 = panelColor,
        ZIndex = 150, Parent = gui,
    })
    addCorner(card, 12)
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(accentColor, Color3.fromRGB(170, 170, 170)),
        Parent = card,
    })
    local st = create("UIStroke", {
        Color = accent, Transparency = 0.15, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card,
    })
    local scale = create("UIScale", { Scale = 0.88, Parent = card })
    create("TextLabel", {
        Text = head, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = accentColor, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -28, 0, 17), ZIndex = 151, Parent = card,
    })
    create("TextLabel", {
        Text = body or "", Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Color3.fromRGB(165, 165, 172),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 30),
        Size = UDim2.new(1, -28, 0, 15), ZIndex = 151, Parent = card,
    })
    local bar = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 14, 1, -6),
        Size = UDim2.new(1, -28, 0, 2),
        BackgroundColor3 = accent, BackgroundTransparency = 0.25,
        BorderSizePixel = 0, ZIndex = 151, Parent = card,
    })
    makeRound(bar)

    local t = { card = card, alive = true }
    table.insert(notifications, 1, t)
    while #notifications > 4 do
        local old = table.remove(notifications)
        old.alive = false
        old.card:Destroy()
    end
    layoutNotifications()
    tween(scale, 0.45, { Scale = 1 }, Enum.EasingDirection.Out, Enum.EasingStyle.Back)
    tween(bar, 2.8, { Size = UDim2.new(0, 0, 0, 2) },
        Enum.EasingDirection.InOut, Enum.EasingStyle.Linear)

    local function close()
        if not t.alive then return end
        t.alive = false
        local i = table.find(notifications, t)
        if i then table.remove(notifications, i) end
        layoutNotifications()
        tween(scale, 0.25, { Scale = 0.9 }, Enum.EasingDirection.In)
        local out = tween(card, 0.28, {
            Position = UDim2.new(1, 330, card.Position.Y.Scale, card.Position.Y.Offset),
        }, Enum.EasingDirection.In, Enum.EasingStyle.Quint)
        out.Completed:Connect(function() card:Destroy() end)
    end
    connect(card.MouseButton1Click, close)
    task.delay(2.8, close)
end
-- ============================================================
-- FAKE KNIFE — визуальная имитация ножа маньяка
-- ============================================================
local fakeKnife = {
    on = false,
    tool = nil,
    conns = {},
    isAttacking = false,
    canAttack = true,
    n = 0.1,
    loopThread = nil,
}

local function destroyFakeKnife()
    if fakeKnife.tool then
        pcall(function() fakeKnife.tool:Destroy() end)
        fakeKnife.tool = nil
    end
    for _, c in pairs(fakeKnife.conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(fakeKnife.conns)
    fakeKnife.isAttacking = false
    fakeKnife.canAttack = true
    fakeKnife.loopThread = nil
end

local function playFakeKnifeAnim(humanoid)
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://2467567750"
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        track.Priority = Enum.AnimationPriority.Action4
        track:Play()
        return track
    end
end

local function createFakeKnife()
    destroyFakeKnife()
    local char = player.Character
    if not char then return end

    local tool = Instance.new("Tool")
    tool.Name = "Knife"  -- ВАЖНО: настоящее имя, чтобы выглядело как нож маньяка
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.TextureId = "rbxassetid://138663675657207"
    tool.Grip = CFrame.new(0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1)

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.4, 3, 0.7)
    handle.CanCollide = false
    handle.Parent = tool

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshId = "http://www.roblox.com/asset/?id=121944778"
    mesh.TextureId = "http://www.roblox.com/asset/?id=121944805"
    mesh.Parent = handle

    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://142247768"
    sound.Parent = handle

    local isEquipped = false

    table.insert(fakeKnife.conns, tool.Equipped:Connect(function()
        isEquipped = true
    end))
    table.insert(fakeKnife.conns, tool.Unequipped:Connect(function()
        isEquipped = false
    end))

    table.insert(fakeKnife.conns, tool.Activated:Connect(function()
        if not fakeKnife.canAttack then return end
        fakeKnife.canAttack = false
        fakeKnife.isAttacking = true
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then playFakeKnifeAnim(hum) end
        task.wait(0.5)
        fakeKnife.isAttacking = false
        task.wait(0.25)
        fakeKnife.canAttack = true
    end))

    table.insert(fakeKnife.conns, handle.Touched:Connect(function(hit)
        if not fakeKnife.tool or fakeKnife.tool.Parent ~= player.Character then return end
        if not fakeKnife.isAttacking then return end
        local parent = hit.Parent
        if parent and parent ~= player.Character and parent:FindFirstChildOfClass("Humanoid") then
            if not sound.IsPlaying then sound:Play() end
        end
    end))

    -- кладём в backpack (или сразу в руку, если хочется)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        tool.Parent = backpack
    else
        tool.Parent = char
    end

    fakeKnife.tool = tool

    -- флинг-логика
    fakeKnife.loopThread = task.spawn(function()
        while fakeKnife.on and fakeKnife.tool do
            RunService.Heartbeat:Wait()
            local currentChar = player.Character
            if isEquipped and currentChar and currentChar:FindFirstChild("HumanoidRootPart") then
                local hrp = currentChar.HumanoidRootPart
                local vel = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = vel * 100000 + Vector3.new(0, 100000, 0)
                RunService.RenderStepped:Wait()
                hrp.AssemblyLinearVelocity = vel + Vector3.new(0, fakeKnife.n, 0)
                fakeKnife.n = -fakeKnife.n
            end
        end
    end)
end

-- Авто-восстановление: следим за инвентарём и персонажем
local function ensureFakeKnife()
    if not fakeKnife.on then return end
    local char = player.Character
    if not char then return end
    -- если нож уже есть в char или backpack — не трогаем
    local backpack = player:FindFirstChildOfClass("Backpack")
    if fakeKnife.tool and fakeKnife.tool.Parent
        and (fakeKnife.tool.Parent == char or fakeKnife.tool.Parent == backpack) then
        return
    end
    -- иначе — создаём заново
    task.wait(0.3)  -- ждём, пока Roblox дозагрузит стандартный инвентарь
    createFakeKnife()
end

connect(player.CharacterAdded, function()
    if fakeKnife.on then
        task.wait(1.2)  -- ждём, пока Roblox выдаст настоящие инструменты
        createFakeKnife()
    end
end)

connect(player.ChildAdded, function(child)
    if child:IsA("Backpack") then
        if fakeKnife.on then
            task.wait(0.3)
            createFakeKnife()
        end
    end
end)

-- слушаем изменения внутри Backpack (на случай очистки)
local backpackConn
local function watchBackpack(bp)
    if backpackConn then backpackConn:Disconnect() end
    backpackConn = connect(bp.ChildRemoved, function()
        if fakeKnife.on then
            task.wait(0.1)
            ensureFakeKnife()
        end
    end)
end

local initialBackpack = player:FindFirstChildOfClass("Backpack")
if initialBackpack then watchBackpack(initialBackpack) end

connect(player.ChildAdded, function(child)
    if child:IsA("Backpack") then watchBackpack(child) end
end)

-- ============================================================
-- UI в Troll Fun
-- ============================================================
do
    local s = addSection(trollTab, "Fake Knife")

    s:Toggle("Enable Fake Knife",
        "spawn a fake knife that looks like the murderer's",
        function(on)
            fakeKnife.on = on
            if on then
                createFakeKnife()
                notify("Fake Knife: On", "use the knife to troll")
            else
                destroyFakeKnife()
                notify("Fake Knife: Off", "disabled")
            end
        end)

    s:Button("Recreate Knife",
        "respawn the fake knife if it disappeared",
        function()
            if not fakeKnife.on then
                notify("Fake Knife", "turn it on first")
                return
            end
            createFakeKnife()
            notify("Fake Knife", "recreated")
        end)

    -- хукаем unload
    table.insert(connections, {
        Disconnect = function()
            fakeKnife.on = false
            destroyFakeKnife()
        end,
    })
end
-- ============================================================
-- FAKE GUN — визуальная имитация пистолета шерифа
-- ============================================================
local fakeGun = {
    on = false,
    tool = nil,
    conns = {},
    isAttacking = false,
    canAttack = true,
    loopThread = nil,
}

local function destroyFakeGun()
    if fakeGun.tool then
        pcall(function() fakeGun.tool:Destroy() end)
        fakeGun.tool = nil
    end
    for _, c in pairs(fakeGun.conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(fakeGun.conns)
    fakeGun.isAttacking = false
    fakeGun.canAttack = true
    fakeGun.loopThread = nil
end

local function playFakeGunAnim(humanoid)
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://..."  -- ID анимации выстрела (если найдёшь)
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        track.Priority = Enum.AnimationPriority.Action4
        track:Play()
        return track
    end
end

local function createFakeGun()
    destroyFakeGun()
    local char = player.Character
    if not char then return end

    local tool = Instance.new("Tool")
    tool.Name = "Gun"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.Grip = CFrame.new(0, -0.4, 0.6, 0, 0, 1, 0, 1, 0, 1, 0, 0)

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.3, 0.8, 1.2)
    handle.CanCollide = false
    handle.Parent = tool

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshId = "rbxassetid://442390820"
    mesh.TextureId = "rbxassetid://442390838"
    mesh.Scale = Vector3.new(0.015, 0.015, 0.015)
    mesh.Parent = handle

    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://142247768"  -- замени на звук выстрела
    sound.Parent = handle

    local isEquipped = false

    table.insert(fakeGun.conns, tool.Equipped:Connect(function()
        isEquipped = true
    end))
    table.insert(fakeGun.conns, tool.Unequipped:Connect(function()
        isEquipped = false
    end))

    table.insert(fakeGun.conns, tool.Activated:Connect(function()
        if not fakeGun.canAttack then return end
        fakeGun.canAttack = false
        fakeGun.isAttacking = true
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then playFakeGunAnim(hum) end
        if not sound.IsPlaying then sound:Play() end
        task.wait(0.5)
        fakeGun.isAttacking = false
        task.wait(0.25)
        fakeGun.canAttack = true
    end))

    table.insert(fakeGun.conns, handle.Touched:Connect(function(hit)
        if not fakeGun.tool or fakeGun.tool.Parent ~= player.Character then return end
        if not fakeGun.isAttacking then return end
        local parent = hit.Parent
        if parent and parent ~= player.Character and parent:FindFirstChildOfClass("Humanoid") then
            if not sound.IsPlaying then sound:Play() end
        end
    end))

    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        tool.Parent = backpack
    else
        tool.Parent = char
    end

    fakeGun.tool = tool
end

-- ============================================================
-- UI в Troll Fun
-- ============================================================
do
    local s = addSection(trollTab, "Fake Gun")

    s:Toggle("Enable Fake Gun",
        "spawn a fake gun that looks like the sheriff's",
        function(on)
            fakeGun.on = on
            if on then
                createFakeGun()
                notify("Fake Gun: On", "use the gun to troll")
            else
                destroyFakeGun()
                notify("Fake Gun: Off", "disabled")
            end
        end)

    s:Button("Recreate Gun",
        "respawn the fake gun if it disappeared",
        function()
            if not fakeGun.on then
                notify("Fake Gun", "turn it on first")
                return
            end
            createFakeGun()
            notify("Fake Gun", "recreated")
        end)

    table.insert(connections, {
        Disconnect = function()
            fakeGun.on = false
            destroyFakeGun()
        end,
    })
end
-- ============================================================
-- FREE ANIMS — Animation Player (полная версия)
-- ============================================================
animsTab.custom = true

do
    for _, c in ipairs(animsTab.page:GetChildren()) do
        if c:IsA("TextLabel") then c.Visible = false end
    end
    animsTab.page.ScrollingEnabled = false
    animsTab.page.ScrollBarThickness = 0
    animsTab.page.CanvasSize = UDim2.new()

    local function idStr(id) return string.format("%.0f", id) end
    local function normName(s)
        return s:lower():gsub("animations?", ""):gsub("package", ""):gsub("pack", ""):gsub("[^%w]", "")
    end

    -- ═══════════════════════════════════════════════════════════
    --  ДАННЫЕ
    -- ═══════════════════════════════════════════════════════════

    -- Классические паки (animPacks) — формат: { "Name", idle, walk, run, jump, fall, climb, swim, ??? }
    local animPacks = {
        {
            "Classic",
            {
                { "Stylish", 616136790, 616138447, 616146177, 616140816, 616139451, 616134815, 616133594, 616143378, 616144772 },
                { "Zombie", 616158929, 616160636, 616168032, 616163682, 616161997, 616157476, 616156119, 616165109, 616166655 },
                { "Robot", 616088211, 616089559, 616095330, 616091570, 616090535, 616087089, 616086039, 616092998, 616094091 },
                { "Toy", 782841498, 782845736, 782843345, 782842708, 782847020, 782846423, 782843869, 782844582, 782845186 },
                { "Cartoony", 742637544, 742638445, 742640026, 742638842, 742637942, 742637151, 742636889, 742639220, 742639812 },
                { "Superhero", 616111295, 616113536, 616122287, 616117076, 616115533, 616108001, 616104706, 616119360, 616120861 },
                { "Mage", 707742142, 707855907, 707897309, 707861613, 707853694, 707829716, 707826056, 707876443, 707894699 },
                { "Levitation", 616006778, 616008087, 616013216, 616010382, 616008936, 616005863, 616003713, 616011509, 616012453 },
                { "Vampire", 1083445855, 1083450166, 1083473930, 1083462077, 1083455352, 1083443587, 1083439238, 1083464683, 1083467779 },
                { "Elder", 845397899, 845400520, 845403856, 845386501, 845398858, 845396048, 845392038, 845401742, 845403127 },
                { "Werewolf", 1083195517, 1083214717, 1083178339, 1083216690, 1083218792, 1083189019, 1083182000, 1083222527, 1083225406 },
                { "Knight", 657595757, 657568135, 657552124, 657564596, 658409194, 657600338, 658360781, 657560551, 657557095 },
                { "Astronaut", 891621366, 891633237, 891667138, 891636393, 891627522, 891617961, 891609353, 891639666, 891663592 },
                { "Bubbly", 910004836, 910009958, 910034870, 910025107, 910016857, 910001910, 909997997, 910028158, 910030921 },
                { "Pirate", 750781874, 750782770, 750785693, 750783738, 750782230, 750780242, 750779899, 750784579, 750785176 },
                { "Rthro", 2510196951, 2510197257, 2510202577, 2510198475, 2510197830, 2510195892, 2510192778, 2510199791, 2510201162 },
                { "Ninja", 656117400, 656118341, 656121766, 656118852, 656117878, 656115606, 656114359, 656119721, 656121397 },
                { "Oldschool", 5319828216, 5319831086, 5319847204, 5319844329, 5319841935, 5319839762, 5319816685, 5319850266, 5319852613 },
                { "Princess", 941003647, 941013098, 941028902, 941015281, 941008832, 941000007, 940996062, 941018893, 941025398 },
                { "Mocap", 913367814, 913373430, 913402848, 913376220, 913370268, 913365531, 913362637, 913384386, 913389285 },
            },
        },
    }

    -- Бандлы — формат: { bundleId, "Name", idle, walk, run, jump, fall, climb, swim }
    local bundles = {
        { 356, "Rthro Animation Package", 2510235063, 2510242378, 2510238627, 2510236649, 2510233257, 2510230574, 2510240941 },
        { 667, "Oldschool Animation Pack", 5319922112, 5319909330, 5319900634, 5319917561, 5319914476, 5319931619, 5319927054 },
        { 83, "Stylish Animation Pack", 619511648, 619512767, 619512153, 619511974, 619511417, 619509955, 619512450 },
        { 82, "Robot Animation Pack", 619521748, 619522849, 619522386, 619522088, 619521521, 619521311, 619522642 },
        { 43, "Toy Animation Pack", 973771666, 973767371, 973766674, 973770652, 973768058, 973773170, 973772659 },
        { 80, "Zombie Animation Pack", 619535834, 619537468, 619536621, 619536283, 619535616, 619535091, 619537096 },
        { 63, "Mage Animation Package", 754637456, 754636298, 754635032, 754637084, 754636589, 754639239, 754638471 },
        { 56, "Cartoony Animation Package", 837011741, 837010234, 837009922, 837011171, 837010685, 837013990, 837012509 },
        { 39, "Bubbly Animation Package", 1018553897, 1018549681, 1018548665, 1018553240, 1018552770, 1018554668, 1018554245 },
        { 75, "Ninja Animation Package", 658832408, 658831143, 658830056, 658832070, 658831500, 658833139, 658832807 },
        { 81, "Superhero Animation Pack", 619528125, 619529601, 619528716, 619528412, 619527817, 619527470, 619529095 },
        { 48, "Elder Animation Package", 892268340, 892267099, 892265784, 892267917, 892267521, 892269341, 892268710 },
        { 33, "Vampire Animation Pack", 1113742618, 1113741192, 1113740510, 1113742359, 1113742092, 1113743239, 1113742944 },
        { 79, "Levitation Animation Pack", 619542203, 619544080, 619543231, 619542888, 619541867, 619541458, 619543721 },
        { 32, "Werewolf Animation Pack", 1113752682, 1113751657, 1113750642, 1113752285, 1113751889, 1113754738, 1113752975 },
        { 34, "Astronaut Animation Pack", 1090133099, 1090131576, 1090130630, 1090132507, 1090132063, 1090134016, 1090133583 },
        { 68, "Knight Animation Package", 734327140, 734326330, 734325948, 734326930, 734326679, 734329002, 734327363 },
        { 55, "Pirate Animation Package", 837024662, 837023892, 837023444, 837024350, 837024147, 837025325, 837025054 },
        { 331465, "Bold Animation Pack", 16744209868, 16744219182, 16744214662, 16744212581, 16744207822, 16744204409, 16744217055 },
        { 932296, "NFL Animation Pack", 101094325978637, 120071305586627, 84823630062362, 140600227095432, 123307994439772, 122757794615785, 136750772888868 },
    }

    -- Новые бандлы (2024-2026)
    local newBundles = {
        { 81295854326892, "✨ Aura (Floating)", 119126902591378, 78093568415363, 127441950006817, 125716954489552, 130109078714595, 125145865285401, 72625909388144 },
        { 22999254604507, "Clean Girl", 99617445188896, 98432516102509, 75417410614580, 111467153412202, 101496693975399, 71306092771466, 97617322069183 },
        { 81889112216202, "Fairy Animation Pack", 126500995514436, 111347977822579, 87861850888726, 72177014322054, 83015219645885, 128525453879414, 123969942041709 },
        { 195619017160446, "💨 Ninja Animation Pack", 107377621660534, 132035242186767, 71990522773224, 118835903505201, 97302677062076, 122413280106175, 109349550251797 },
        { 122746952391276, "Cute Kawaii", 87378581612013, 134893286312907, 114496981964667, 78753669029804, 78668034869322, 114544880037945, 77472834006636 },
        { 4974195, "KATSEYE Animation Pack", 125286451593779, 105967194765350, 140179859838109, 121868657321572, 84737112249504, 130399277423748, 87465102258861 },
        { 246417977128963, "Doll 3.0", 109401010312897, 73488864835464, 90126309265051, 118036998124357, 99977942446739, 86104031977265, 133772806040245 },
        { 81397985471047, "Cute Bouncy", 112758171987743, 105398643971664, 81980688988481, 95845383984913, 91206221270256, 77455242814172, 137674505873151 },
        { 110693219046747, "Cute", 73073438542366, 87016985886252, 103569388072604, 126765807132662, 74500938515101, 130431162972600, 112736233576006 },
        { 171430088634553, "Modern R6 Animation Pack", 104406060298008, 124988819613327, 99901926147031, 116343198036897, 129580654694779, 110907985002120, 99928806802401 },
        { 94415078985878, "Kawaii Cute Girly", 111249376072333, 73636981266788, 131576761090801, 125116610868743, 106910927390939, 133959656651864, 104067918460960 },
        { 107350693632269, "🦋 Fairy Animation Pack", 89083151597904, 70694340291974, 121135476621722, 124909042161301, 87787512377012, 140475232307421, 117829242170557 },
        { 3209000400683, "😇🪽 Angel Animation Pack", 85043173762737, 89201769650144, 138287417917411, 106183812356921, 104600877757491, 104660563121727, 118177131718784 },
        { 120481257024256, "Cool Boy", 130315830989545, 137785643057516, 85494649926570, 133898250810070, 121898694120755, 109255428875312, 97318831452205 },
        { 238848825749740, "Ghoul Animation Pack", 76989014478397, 116022874958585, 112734296077543, 71865240269363, 80620104261118, 133899475603776, 130029645154775 },
        { 219075592036639, "Shy Doll ʚɞ", 120409233127901, 136018973495139, 140452828857398, 96648456154700, 96027555904188, 79085398750382, 108176320752952 },
        { 165127141291580, "Kawaii Bouncy", 70555112060391, 120312452429453, 107040972522394, 85980076701165, 110732584497974, 119148235349086, 136546912982911 },
        { 211603209255940, "😌 Nonchalant", 120361344309821, 137080061938111, 138817543112482, 101362426464232, 137504551310868, 112352256883383, 121597417409288 },
        { 174234884993258, "♡ kawaii anime girl", 118402733965469, 137873085101178, 130849350236070, 94640150317449, 125678285855898, 72639448259486, 78062527010701 },
        { 133029085353625, "Diva Effortless Aura", 136462080938426, 85942415677641, 104659090959141, 80104657332873, 133638268834647, 113339705060994, 77349285629064 },
        { 155148535503082, "angelic dainty floating", 122087124095413, 133979848959140, 138857433670797, 130915558062129, 103456136433561, 110517842631547, 81357557460188 },
        { 142368140565439, "Hatsune Miku VOCALOID", 77394702918889, 115076409379509, 132703832811724, 104800719202256, 79679642704558, 124311346839421, 123121833221754 },
        { 149613246755627, "🐾 Therian Furry", 94925478547755, 111277037711705, 113440665495248, 117902437286612, 80010379317159, 81758690520669, 105439957980795 },
        { 109854023066610, "Cat-boy Animation Pack", 85163331300454, 72342918281987, 93765468680106, 79926571638154, 133759466033378, 128774319815820, 81206256359713 },
        { 152306106818054, "Cat-Girl Animation Pack", 97317100261517, 116870418497306, 119510100333782, 122910742742130, 118747804995604, 92496064469025, 81309395375420 },
        { 167942519332380, "Cute Frog 🐸", 107853639072984, 110447391478976, 94204782170994, 139391685278077, 110454726325518, 78952577481681, 107955532457303 },
        { 219196833552012, "Floating Animation Pack", 113858313416489, 88471654472148, 132857529438108, 83578339581624, 71535051799354, 93321075431546, 87949112447276 },
        { 157068024753326, "Cute Kawaii Girl", 78294398529281, 132502249513547, 109496577835577, 123630463152824, 127822567000511, 130676104756900, 76274836988148 },
        { 78316657350968, "Cute Kawaii Doll", 95933625306405, 96186536617838, 129394133110246, 94830488207575, 137395179912796, 91497237628692, 79756759306847 },
        { 238434413254101, "Cute Shy Doll", 81132802911146, 121942336973643, 71528806562821, 92645236363717, 129254372210059, 84246439515369, 120612365648651 },
        { 106044231344969, "Cute Shy Girl Pack", 106705278836440, 101760042345605, 138053854205135, 78059067540085, 99363563273607, 119452852001390, 119004313922987 },
    }

    -- Эмоции
    local emotes = {
        { 3360689775, "Salute" }, { 3360692915, "Tilt" }, { 5915779043, "Applaud" },
        { 3576968026, "Shrug" }, { 3360686498, "Stadium" }, { 3576686446, "Hello" },
        { 3576823880, "Point2" }, { 3716636630, "Monkey" }, { 4646306583, "Curtsy" },
        { 4849499887, "Happy" }, { 3823158750, "Godlike" }, { 14353423348, "Baby Queen - Bouncy Twirl" },
        { 4689362868, "Sleep" }, { 3576717965, "Shy" }, { 5917570207, "Floss Dance" },
        { 5104377791, "Hero Landing" }, { 15610015346, "Yungblud Happier Jump" },
        { 7466046574, "Quiet Waves" }, { 5230661597, "Bored" }, { 5915776835, "High Wave" },
        { 12507097350, "Alo Yoga Pose" }, { 4940597758, "Cower" }, { 4272484885, "Baby Dance" },
        { 3994127840, "Celebrate" }, { 132384701706046, "💀MM2 Fake Dead" },
        { 104131847054135, "Jamal Brazil Groove" }, { 139021427684680, "KATSEYE - Touch" },
        { 4849502101, "Sad" }, { 4102315500, "Haha" }, { 106708015414624, "Endless Aura Floating" },
        { 3762654854, "Greatest" }, { 98603994713783, "Rat Dance" }, { 93511411593120, "/e fly" },
        { 105381637724646, "🎃Pumpkin King👑" }, { 71302743123422, "Popular" },
        { 88425531063616, "Stylish Floating" }, { 104142334418357, "Gangnam Style" },
        { 111378664166805, "Moonwalk" }, { 80963950541052, "hip sway" },
        { 7202898984, "Show Dem Wrists - KSI" }, { 5938394742, "Old Town Road" },
        { 74716792202343, "🕷️ Hornet's Spider Dance" }, { 4940592718, "Confused" },
        { 15679955281, "Festive Dance" }, { 79312439851071, "HOT TO GO!" },
        { 3762641826, "Side to Side" }, { 5230615437, "Beckon" },
        { 130371895389423, "Invisiblity" }, { 107282826166809, "Basketball Head" },
        { 79017619155911, "Wall Phase (GLITCH)" }, { 125328720114284, "Nervy Dance" },
        { 4272351660, "Fast Hands" }, { 97164262994588, "Floating in Love 🥰" },
        { 16572756230, "HIPMOTION - Amaarae" }, { 78224683906191, "Cute Feet Kicking" },
        { 82727664018494, "Lush Life" }, { 5938365243, "Dolphin Dance" },
        { 70919402339484, "Scuba Nick Wilde" }, { 95325218641213, "Psycho Teddy" },
        { 15506503658, "Victory Dance" }, { 4940602656, "Jumping Wave" },
        { 108635834286627, "Spiderman Hang" }, { 5915773992, "Break Dance" },
        { 3934986896, "Dizzy" }, { 136648387080677, "DARE - Gorillaz" },
        { 111426928948833, "Floating on clouds" }, { 127764273000599, "Dropkick" },
        { 17746270218, "Sturdy Dance - Ice Spice" }, { 3716633898, "Twirl" },
        { 129149402922241, "griddy" }, { 94064805002669, "Cute Kawaii Posing" },
        { 139058906415119, "Floating" }, { 4212496830, "Zombie" },
        { 75911227509248, "Ghost Floating" }, { 79127989560307, "Moon Walk" },
        { 89157328525577, "spider dance" }, { 120904242187887, "GOOFY FLAP FLY" },
        { 107708114415320, "Big Guy - Ice Spice" }, { 132367660388476, "SHAKE" },
        { 138515241510970, "kawaii girly idle" }, { 76261461321661, "cute sitting pose" },
        { 4391208058, "Shuffle" }, { 88859617281337, "WOOF BARK WOOF" },
        { 82995540773684, "Tornado" }, { 3994130516, "Bodybuilder" },
        { 4849487550, "Agree" }, { 79216795769647, "Tall Scary Creature" },
        { 83917238288783, "cute dancy dance" }, { 122147154162464, "Hakari Dance" },
        { 118853736905967, "Wall Aura Farm Pose" }, { 4849497510, "Power Blast" },
        { 15123050663, "Bone Chillin' Bop" }, { 133685484220846, "KATSEYE - GNARLY" },
        { 72947568152049, "Cute Sit" }, { 3576745472, "Fashionable" },
        { 106370760824973, "Possessed Glitcher" }, { 98388724133440, "i got that feeling 💌" },
        { 122740406985544, "Fly Aura pose" }, { 80573839869810, "Kneeling Sit" },
        { 89360359553814, "Sunflower" }, { 73181508272121, "Party Funk" },
        { 126941778232900, "kawaii sit cat paws" }, { 116416944161215, "kawaii schoolgirl sitting" },
        { 88456688900525, "Reanimated 🎃" }, { 77080714986256, "Moving Like Berney" },
        { 87433588393157, "Cute Bouncy Side Sway" }, { 131145074585836, "Viltrum Hovering Aura" },
        { 98094482524931, "Met my match" }, { 96059912242002, "Them Hips" },
        { 99246819283563, "Goofball Griddy" }, { 128814921948602, "Super Funk Dance" },
        { 86938925857615, "Superhero Pose" }, { 122249198697121, "Nameless monster dance" },
        { 76618267763261, "KISS N TELL - AESPA" }, { 90121297911534, "Jeyke Funk" },
        { 98840627727488, "Peaches - Justin Bieber" }, { 126178027638785, "Tinashe - Nasty Girl" },
        { 98049374819131, "Diego - Jojo Anime Pose" }, { 114800420888775, "Pennywise Dance 👹" },
        { 105765738022096, "Cutesy standing doll pose" }, { 131171992525098, "One Arm Push Ups" },
        { 101582120044688, "puppy girl profile pose" }, { 81708325562195, "Cute Needy Happy Shake" },
        { 105201400407575, "Cute Happy Bouncy Jumps" }, { 81346143283632, "needy kawaii puppy sitting" },
        { 116521788694479, "🔥 The Bass Trend" }, { 126498185656790, "Happy Bounce" },
        { 78623311762574, "WestPole Emote [OG]" }, { 97926971484337, "12 to 12 [PERFECT]" },
        { 94724645460262, "The worm move" }, { 97052459488169, "Feeling myself emote" },
        { 93072647185531, "🔥 Dorobo Dance [V2]" }, { 103722701410933, "Brazilian Dance Trend" },
        { 88160454118928, "Salsa" }, { 123604753182408, "ADELA - Nicole Kidman" },
        { 140594655288573, "Mangarap Dance" }, { 91914407217006, "The Bass Trend V2" },
        { 90960483742655, "MM2 fake death pose" }, { 139324301384120, "Cute anime girl pose" },
        { 117343790961625, "BLACKPINK ROSÉ - On The Ground" }, { 128860586829249, "anime dance" },
        { 89733893354683, "Cute Bouncy Shake Dance" }, { 102174264026632, "GG Animation" },
        { 86375122997153, "still idle" }, { 132600795042399, "Bby Wow trend" },
        { 73193222304259, "Jamal Dance 3.0" }, { 99311131968819, "Sneaky Shuffle" },
        { 138127306398554, "Confident Flying Aura" }, { 106724593413222, "Cutsey Flying Aura 💕" },
        { 122901201145982, "Emo Floating Aura" }, { 132697034165623, "MM2 OOF 💀" },
        { 108435804337942, "MM2 💀👹🥹🤡" }, { 109436261994235, "Shy Vampire" },
        { 91339094607949, "Ballerina Spin" }, { 91341416163208, "Cute Sitting" },
        { 82555721533394, "Choo Choo TRAIN" }, { 83190195248548, "Boredom" },
        { 111937410622410, "Balance balance" }, { 126198554443561, "I had a hunch" },
        { 110870173502552, "ghostly possession" }, { 133537618008799, "Toxic Laugh" },
        { 71555837867329, "NPC Greeting" }, { 80160023079097, "Gangnam Style" },
        { 80069514148007, "Vezna Idle Animation" }, { 113267287854914, "cute kawaii sit" },
        { 119535274797446, "Press F to inspect" }, { 76934438548184, "Kangaroo Dance" },
        { 99399545142101, "Headless Swap" }, { 99576158170768, "Everybody - Backstreet Boys" },
    }

    -- ═══════════════════════════════════════════════════════════
    --  ЛОГИКА
    -- ═══════════════════════════════════════════════════════════
    local validSlots = { idle=true, walk=true, run=true, jump=true, fall=true, climb=true, swim=true, swimidle=true }
    local slotOrder  = { "idle", "walk", "run", "jump", "fall", "climb", "swim" }

    local classicByName = {}
    for _, cat in ipairs(animPacks) do
        for _, p in ipairs(cat[2]) do
            classicByName[normName(p[1])] = p
        end
    end

    local function classicSlots(p)
        local function wrap(v)
            return v and v ~= 0 and { "rbxassetid://" .. idStr(v) } or nil
        end
        local idle2 = p[3] and p[3] ~= 0 and p[3] or p[2]
        return {
            idle  = { "rbxassetid://" .. idStr(p[2]), "rbxassetid://" .. idStr(idle2) },
            walk  = wrap(p[4]), run = wrap(p[5]), jump = wrap(p[6]),
            fall  = wrap(p[7]), climb = wrap(p[8]), swim = wrap(p[9]),
            swimidle = wrap(p[10]),
        }
    end

    local bundleList, bundleById = {}, {}
    local function addBundle(id, name, assets, isNew)
        if bundleById[id] then
            if isNew then bundleById[id].new = true end
            return bundleById[id]
        end
        local b = { id = id, name = name, assets = assets, new = isNew, kind = "b" }
        bundleById[id] = b
        table.insert(bundleList, b)
        return b
    end
    for _, r in ipairs(bundles) do
        addBundle(r[1], r[2], { r[3], r[4], r[5], r[6], r[7], r[8], r[9] }, false)
    end
    for _, r in ipairs(newBundles) do
        addBundle(r[1], r[2], { r[3], r[4], r[5], r[6], r[7], r[8], r[9] }, true)
    end

    local emoteList = {}
    for _, r in ipairs(emotes) do
        table.insert(emoteList, { id = r[1], name = r[2], kind = "e" })
    end

    local animCache = {}
    local function loadAnims(assetId)
        if animCache[assetId] then return animCache[assetId] end
        local ok, objs = pcall(function()
            return game:GetObjects("rbxassetid://" .. idStr(assetId))
        end)
        if not ok or type(objs) ~= "table" then
            animCache[assetId] = {}
            return {}
        end
        local anims = {}
        for _, o in ipairs(objs) do
            local list = o:GetDescendants()
            table.insert(list, 1, o)
            for _, a in ipairs(list) do
                if a:IsA("Animation") and a.AnimationId ~= "" then
                    table.insert(anims, {
                        slot = a.Parent and a.Parent.Name:lower() or "",
                        name = a.Name, id = a.AnimationId,
                    })
                end
            end
        end
        table.sort(anims, function(x, y) return x.name < y.name end)
        animCache[assetId] = anims
        return anims
    end

    local slotCache = {}
    local function getSlots(b)
        if slotCache[b.id] then return slotCache[b.id] end
        local k = classicByName[normName(b.name)]
        if k then
            slotCache[b.id] = classicSlots(k)
            return slotCache[b.id]
        end
        local slots, any = {}, false
        for i, asset in ipairs(b.assets or {}) do
            if asset and asset ~= 0 then
                for _, a in ipairs(loadAnims(asset)) do
                    local s = validSlots[a.slot] and a.slot or slotOrder[i]
                    if s then
                        slots[s] = slots[s] or {}
                        table.insert(slots[s], a.id)
                        any = true
                    end
                end
            end
        end
        if any then
            slotCache[b.id] = slots
            return slots
        end
    end

    local origAnims

    local function getAnimate()
        local c = player.Character
        return c and c:FindFirstChild("Animate")
    end

    local function sortedAnims(folder)
        local t = {}
        for _, a in ipairs(folder:GetChildren()) do
            if a:IsA("Animation") then table.insert(t, a) end
        end
        table.sort(t, function(x, y) return x.Name < y.Name end)
        return t
    end

    local function backupAnims(animate)
        if origAnims then return end
        origAnims = {}
        for _, folder in ipairs(animate:GetChildren()) do
            if validSlots[folder.Name:lower()] then
                for _, a in ipairs(sortedAnims(folder)) do
                    origAnims[a] = a.AnimationId
                end
            end
        end
    end

    local function restartAnimate()
        local animate = getAnimate()
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not animate or not hum then return end
        animate.Disabled = true
        for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
            tr:Stop(0)
        end
        animate.Disabled = false
    end

    local function applySlots(slots)
        local animate = getAnimate()
        if not animate then return false end
        backupAnims(animate)
        for _, folder in ipairs(animate:GetChildren()) do
            local ids = slots[folder.Name:lower()]
            if ids and #ids > 0 then
                for i, a in ipairs(sortedAnims(folder)) do
                    a.AnimationId = ids[i] or ids[1]
                end
            end
        end
        restartAnimate()
        return true
    end

    local function resetAnims()
        if origAnims then
            for a, id in pairs(origAnims) do
                if a.Parent then a.AnimationId = id end
            end
            restartAnimate()
        end
    end

    local busy = false
    local currentPack
    local function applyPack(b)
        if busy then return end
        busy = true
        task.spawn(function()
            local slots = getSlots(b)
            busy = false
            if not slots then
                notify("Free anims", "can't load: " .. b.name)
                return
            end
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.RigType == Enum.HumanoidRigType.R6 and not b.name:find("R6") then
                notify("R6 avatar", "most packs are made for R15")
            end
            if applySlots(slots) then
                currentPack = { id = b.id, slots = slots }
                notify("Animation pack", b.name)
            end
        end)
    end

    local emoteTrack
    local emoteAnims = {}
    local function stopEmote()
        if emoteTrack then
            pcall(function() emoteTrack:Stop(0.2) end)
            emoteTrack = nil
        end
    end

    local function playEmote(e)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        task.spawn(function()
            local animId = emoteAnims[e.id]
            if not animId then
                local list = loadAnims(e.id)
                animId = list[1] and list[1].id
                emoteAnims[e.id] = animId
            end
            stopEmote()
            if animId then
                local anim = Instance.new("Animation")
                anim.AnimationId = animId
                local animator = hum:FindFirstChildOfClass("Animator") or hum
                local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
                if ok and tr then
                    tr.Priority = Enum.AnimationPriority.Action
                    tr.Looped = true
                    tr:Play(0.2)
                    emoteTrack = tr
                    notify("Emote", e.name)
                    return
                end
            end
            local ok, _, tr = pcall(function()
                return hum:PlayEmoteAndGetAnimTrackById(e.id)
            end)
            if ok and tr then
                emoteTrack = tr
                notify("Emote", e.name)
            else
                notify("Free anims", "can't play: " .. e.name)
            end
        end)
    end

    connect(RunService.Heartbeat, function()
        if emoteTrack then
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.MoveDirection.Magnitude > 0.1 then
                stopEmote()
            end
        end
    end)

    connect(player.CharacterAdded, function(char)
        origAnims = nil
        emoteTrack = nil
        if not currentPack then return end
        char:WaitForChild("Animate", 10)
        task.wait(0.3)
        if currentPack.slots then applySlots(currentPack.slots) end
    end)

    -- ═══════════════════════════════════════════════════════════
    --  UI внутри вкладки
    -- ═══════════════════════════════════════════════════════════
    local page = animsTab.page
    local cardColor   = Color3.fromRGB(36, 36, 38)
    local cardHover   = Color3.fromRGB(48, 48, 52)
    local footerColor = Color3.fromRGB(17, 17, 19)

    local mode = "Bundles"
    local query = ""

    -- Верхняя панель с подтабами
    local bar = create("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1, ZIndex = 3, Parent = page,
    })
    local tabs2, tabX = {}, 0
    for _, sub in ipairs({ "Bundles", "Emotes" }) do
        local on = sub == mode
        local w = TextService:GetTextSize(sub, 13, Enum.Font.GothamMedium, Vector2.new(200, 40)).X + 34
        local b = create("TextButton", {
            Text = "", AutoButtonColor = false,
            BackgroundColor3 = Color3.fromRGB(90, 90, 90),
            BackgroundTransparency = on and 0.35 or 0.85,
            Position = UDim2.fromOffset(tabX, 0),
            Size = UDim2.fromOffset(w, 30),
            ZIndex = 3, Parent = bar,
        })
        addCorner(b, 9)
        local d = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 13, 0.5, 0),
            Size = UDim2.fromOffset(on and 6 or 0, on and 6 or 0),
            BackgroundColor3 = accentColor, BorderSizePixel = 0,
            ZIndex = 4, Parent = b,
        })
        makeRound(d)
        local l = create("TextLabel", {
            Text = sub, Font = Enum.Font.GothamMedium, TextSize = 13,
            TextColor3 = on and accentColor or dimColor,
            TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(on and 22 or 17, 0),
            Size = UDim2.new(1, -22, 1, 0), ZIndex = 4, Parent = b,
        })
        tabs2[sub] = { b = b, dot = d, lbl = l }
        tabX = tabX + w + 4
    end

    local searchBox = create("Frame", {
        Position = UDim2.fromOffset(tabX + 6, 0),
        Size = UDim2.new(1, -(tabX + 6) - 90, 0, 30),
        BackgroundColor3 = Color3.fromRGB(22, 22, 22),
        ZIndex = 3, Parent = bar,
    })
    addCorner(searchBox, 9)
    local searchStroke = addStroke(searchBox)
    local searchInput = create("TextBox", {
        Text = "", PlaceholderText = "Search...",
        PlaceholderColor3 = mutedColor,
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = accentColor, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -20, 1, 0),
        ZIndex = 4, Parent = searchBox,
    })
    connect(searchInput.Focused, function()
        tween(searchStroke, 0.2, { Color = Color3.fromRGB(120, 120, 120) })
    end)
    connect(searchInput.FocusLost, function()
        tween(searchStroke, 0.2, { Color = strokeColor })
    end)

    local resetBtn = create("TextButton", {
        Text = "Reset",
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = textColor,
        BackgroundColor3 = elemColor,
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(80, 30),
        ZIndex = 3, Parent = bar,
    })
    addCorner(resetBtn, 8)
    addStroke(resetBtn)
    connect(resetBtn.MouseButton1Click, function()
        resetAnims()
        currentPack = nil
        notify("Free anims", "reset to default")
    end)

    -- Сетка карточек
    local grid = create("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 1, -42),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = dimColor,
        ScrollBarImageTransparency = 0.3,
        VerticalScrollBarInset = Enum.ScrollBarInset.Always,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(), ZIndex = 2, Parent = page,
    })
    create("UIPadding", {
        PaddingTop = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1),
        PaddingRight = UDim.new(0, 4), Parent = grid,
    })
    local layout = create("UIGridLayout", {
        CellSize = UDim2.new(0.25, -6, 0, 130),
        CellPadding = UDim2.fromOffset(8, 8),
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid,
    })
    connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        grid.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
    end)

    local function refresh()
        for _, c in ipairs(grid:GetChildren()) do
            if c:IsA("GuiObject") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
                c:Destroy()
            end
        end
        local list = (mode == "Bundles") and bundleList or emoteList
        local order = 0
        for _, item in ipairs(list) do
            if query == "" or item.name:lower():find(query, 1, true) then
                order = order + 1
                local card = create("TextButton", {
                    Text = "", AutoButtonColor = false,
                    BackgroundColor3 = cardColor,
                    LayoutOrder = order, Parent = grid,
                })
                addCorner(card, 8)
                addStroke(card, strokeColor)

                local thumbType = item.kind == "b" and "BundleThumbnail" or "Asset"
                create("ImageLabel", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, -14),
                    Size = UDim2.fromOffset(76, 76),
                    BackgroundTransparency = 1,
                    ScaleType = Enum.ScaleType.Fit,
                    Image = ("rbxthumb://type=%s&id=%s&w=150&h=150"):format(thumbType, idStr(item.id)),
                    Parent = card,
                })

                create("TextLabel", {
                    Text = item.name,
                    Font = Enum.Font.GothamMedium, TextSize = 10,
                    TextColor3 = accentColor, TextWrapped = true,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.new(0, 4, 1, -4),
                    Size = UDim2.new(1, -8, 0, 26),
                    Parent = card,
                })

                connect(card.MouseEnter, function()
                    tween(card, 0.15, { BackgroundColor3 = cardHover })
                end)
                connect(card.MouseLeave, function()
                    tween(card, 0.15, { BackgroundColor3 = cardColor })
                end)
                connect(card.MouseButton1Click, function()
                    if item.kind == "b" then
                        applyPack(item)
                    else
                        playEmote(item)
                    end
                end)
            end
        end
    end

    local function setMode(m)
        if m == mode then return end
        local old = tabs2[mode]
        tween(old.b, 0.25, { BackgroundTransparency = 0.85 })
        tween(old.dot, 0.25, { Size = UDim2.fromOffset(0, 0) })
        tween(old.lbl, 0.25, { TextColor3 = dimColor, Position = UDim2.fromOffset(17, 0) })
        mode = m
        local p = tabs2[m]
        tween(p.b, 0.25, { BackgroundTransparency = 0.35 })
        tween(p.dot, 0.25, { Size = UDim2.fromOffset(6, 6) },
            Enum.EasingDirection.Out, Enum.EasingStyle.Back)
        tween(p.lbl, 0.25, { TextColor3 = accentColor, Position = UDim2.fromOffset(22, 0) })
        refresh()
    end

    for sub, p in pairs(tabs2) do
        connect(p.b.MouseButton1Click, function() setMode(sub) end)
    end

    connect(searchInput:GetPropertyChangedSignal("Text"), function()
        query = searchInput.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
        refresh()
    end)

    refresh()
end
-- -------- MAIN --------
do
    local s = addSection(mainTab, "Player")
    s:Slider("WalkSpeed", 16, 150, 16, function(v) charMods.speed = v end)
    s:Slider("JumpPower", 50, 250, 50, function(v) charMods.jump = v end)
    s:Toggle("Infinite Jump", "jump again in the air", function(on) charMods.infJump = on end)
    s:Toggle("Noclip", "walk through walls", function(on) charMods.noclip = on end)
    s:Toggle("Anti Fling", "nobody can fling you", function(on) charMods.antiFling = on end)
-- ============================================================
-- WALLHOP V2.6 (Адаптировано под Sdwg)
-- ============================================================
local wallHop = {
    enabled = false,
    jumpCooldown = 0.15,
    jumpVelocity = 56,
    jumpVariance = 4,
    wallBuffer = 0.12,
    lastWallTime = 0,
    lastJumpTime = 0,
}

local whParams = RaycastParams.new()
whParams.FilterType = Enum.RaycastFilterType.Exclude

local function whHasWall(root)
    if not root then return false end
    whParams.FilterDescendantsInstances = { player.Character }
    local pos = root.Position + Vector3.new(0, -1.8, 0)
    local dirs = {
        root.CFrame.RightVector * 4, root.CFrame.RightVector * -4,
        root.CFrame.LookVector * 4, root.CFrame.LookVector * -4,
    }
    for _, dir in ipairs(dirs) do
        local hit = workspace:Raycast(pos, dir, whParams)
        if hit then
            -- Проверяем, что это не другой игрок (чтобы не прыгать по людям)
            local isPlayerPart = false
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character 
                and hit.Instance:IsDescendantOf(otherPlayer.Character) then
                    isPlayerPart = true
                    break
                end
            end
            if not isPlayerPart then
                wallHop.lastWallTime = tick()
                return true
            end
        end
    end
    -- Wall buffer (позволяет прыгнуть через 0.12 сек после отрыва)
    if tick() - wallHop.lastWallTime < wallHop.wallBuffer then
        return true
    end
    return false
end

connect(UserInputService.JumpRequest, function()
    if not wallHop.enabled then return end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    
    if tick() - wallHop.lastJumpTime < wallHop.jumpCooldown then return end
    if not whHasWall(root) then return end
    
    wallHop.lastJumpTime = tick()
    
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    local vel = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(
        vel.X,
        wallHop.jumpVelocity + math.random(-wallHop.jumpVariance, wallHop.jumpVariance),
        vel.Z
    )
end)

local wallSec = addSection(mainTab, "Movement")
wallSec:Toggle("WallHop V2", "jump on walls to climb (very stable)", function(on)
    wallHop.enabled = on
    notify("WallHop: " .. (on and "On" or "Off"), on and "jump on walls" or "disabled")
end)

wallSec:Slider("Wall Jump Power", 30, 100, 56, function(v) 
    wallHop.jumpVelocity = v 
end, function(v) return v end)

wallSec:Slider("Wall Jump Cooldown", 0.05, 0.5, 0.15, function(v) 
    wallHop.jumpCooldown = v 
end, function(v) return string.format("%.2fs", v) end)

local o = addSection(mainTab, "Other")
    o:Button("Reset stats", "speed and jump back to default", function()
        charMods.speed, charMods.jump = nil, nil
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
    end)
    o:Button("Respawn", "kill your character", function()
        local hum = getHumanoid()
        if hum then hum.Health = 0 end
    end)
end

-- -------- COMBAT --------
do
    local s = addSection(combatTab, "Sheriff")

-- ============================================================
-- SHERIFF — Silent Aimbot + Auto Shoot Murderer
-- ============================================================
local silentAim = {
    on = false,
    wallbang = true,
    pred = 100,
    part = "UpperTorso",
    auto = true,
}
local autoShoot = false
local shootBusy = false
local lastAutoShoot = 0

-- ===== Утилиты =====
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function getMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and findTool(p, "Knife") then
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                return p, hrp, char, hum
            end
        end
    end
end

local function equipGun()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local gun = char:FindFirstChild("Gun")
    if gun then return gun end
    local backpack = player:FindFirstChildOfClass("Backpack")
    gun = backpack and backpack:FindFirstChild("Gun")
    if not gun then return end
    hum:EquipTool(gun)
    for _ = 1, 15 do
        if gun.Parent == char then break end
        RunService.Heartbeat:Wait()
    end
    return gun
end

local function findGunRemote(gun)
    local knifeLocal = gun:FindFirstChild("KnifeLocal")
    local cb = knifeLocal and knifeLocal:FindFirstChild("CreateBeam")
    local remote = cb and cb:FindFirstChild("RemoteFunction")
    if remote then return remote, "beam" end
    for _, d in ipairs(gun:GetDescendants()) do
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction"))
            and d.Name:lower():find("shoot") then
            return d, "shoot"
        end
    end
end

local function isBlocked(a, b, extraIgnore)
    local list = { workspace.CurrentCamera }
    for _, x in ipairs(extraIgnore or {}) do table.insert(list, x) end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then table.insert(list, pl.Character) end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    for _ = 1, 8 do
        params.FilterDescendantsInstances = list
        local hit = workspace:Raycast(a, b - a, params)
        if not hit then return false end
        local inst = hit.Instance
        if inst.Transparency >= 0.9 or not inst.CanCollide then
            table.insert(list, inst)
        else
            return true
        end
    end
    return true
end

local function expandHitbox(hrp)
    if not hrp or not hrp.Parent then return function() end end
    local o = { size = hrp.Size, transp = hrp.Transparency, collide = hrp.CanCollide }
    pcall(function()
        hrp.CanCollide = false
        hrp.Transparency = 1
        hrp.Size = Vector3.one * 50
    end)
    local done = false
    return function()
        if done then return end
        done = true
        if hrp.Parent then
            pcall(function()
                hrp.Size = o.size
                hrp.Transparency = o.transp
                hrp.CanCollide = o.collide
            end)
        end
    end
end

local peekOffsets = {
    Vector3.new(0, 0, 4),
    Vector3.new(0, 0, -4),
    Vector3.new(4, 0, 0),
    Vector3.new(-4, 0, 0),
    Vector3.new(0, 5, 3),
    Vector3.new(0, 2, 2),
}

local function getPeekCf(murdererHrp, myChar)
    aimParams.FilterDescendantsInstances = { myChar, murdererHrp.Parent, workspace.CurrentCamera }
    for _, offset in ipairs(peekOffsets) do
        local pos = (murdererHrp.CFrame * CFrame.new(offset)).Position
        if not isBlocked(pos, murdererHrp.Position) then
            return CFrame.lookAt(pos, murdererHrp.Position)
        end
    end
    local behind = murdererHrp.CFrame * CFrame.new(0, 0, 3)
    return CFrame.lookAt(behind.Position, murdererHrp.Position)
end

local function shootMurderer(manual)
    if shootBusy then return end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then
        if manual then notify("Silent Aimbot", "you're dead") end
        return
    end
    if not findTool(player, "Gun") then
        if manual then notify("Silent Aimbot", "you need the Gun") end
        return
    end
    local murderer, murdererHrp = getMurderer()
    if not murdererHrp then
        if manual then notify("Silent Aimbot", "murderer not found") end
        return
    end

    local gun = equipGun()
    if not gun then return end

    local gunRemote, kind = findGunRemote(gun)
    local t = os.clock()
    while not gunRemote and os.clock() - t < 1 do
        RunService.Heartbeat:Wait()
        gunRemote, kind = findGunRemote(gun)
    end
    if not gunRemote then
        if manual then notify("Silent Aimbot", "gun remote not found") end
        return
    end

    shootBusy = true
    local savedCF = hrp.CFrame
    local cam = workspace.CurrentCamera
    local oldCamType = cam.CameraType
    local murdererChar = murdererHrp.Parent
    local murdererHum = murdererChar:FindFirstChildOfClass("Humanoid")

    local function predictAim()
        local target = murdererHrp
        if silentAim.part == "Head" then
            target = murdererChar:FindFirstChild("Head") or murdererHrp
        end
        local v = murdererHrp.AssemblyLinearVelocity
        local lead = silentAim.pred / 1000
        return target.Position + Vector3.new(v.X, v.Y * 0.5, v.Z) * lead
    end

    local wallbang = silentAim.wallbang
    local peekCf, holdConn
    if wallbang then
        local handle = gun:FindFirstChild("Handle")
        local muzzle = handle and handle.Position or hrp.Position
        if not isBlocked(muzzle, murdererHrp.Position) then
            wallbang = false
        else
            cam.CameraType = Enum.CameraType.Scriptable
            peekCf = getPeekCf(murdererHrp, char)
            hrp.CFrame = peekCf
            hrp.AssemblyLinearVelocity = Vector3.zero
            holdConn = RunService.Stepped:Connect(function()
                if peekCf and hrp.Parent then
                    hrp.CFrame = peekCf
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end)
            RunService.Heartbeat:Wait()
        end
    end

    local aimPos = predictAim()
    local handle = gun:FindFirstChild("Handle")
    local origin = handle and handle.Position or hrp.Position

    local restoreHitbox = expandHitbox(murdererHrp)
    task.delay(0.4, restoreHitbox)

    task.spawn(function()
        local ok, res = pcall(function()
            if kind == "beam" then
                return gunRemote:InvokeServer(1, aimPos, "AH2")
            elseif gunRemote:IsA("RemoteFunction") then
                local from = CFrame.lookAt(origin, aimPos)
                local to = CFrame.lookAt(aimPos, aimPos + (aimPos - origin).Unit)
                return gunRemote:InvokeServer(from, to)
            else
                local from = CFrame.lookAt(origin, aimPos)
                local to = CFrame.lookAt(aimPos, aimPos + (aimPos - origin).Unit)
                gunRemote:FireServer(from, to)
            end
        end)
        if not ok then warn("[SdwgXyz] shot failed: " .. tostring(res)) end
    end)

    if murdererHum then
        task.spawn(function()
            local t2 = os.clock()
            while os.clock() - t2 < 1.2 do
                if murdererHum.Health <= 0 or not murdererHum.Parent then
                    notify("Silent Aimbot", "hit: " .. murderer.DisplayName)
                    return
                end
                RunService.Heartbeat:Wait()
            end
            notify("Silent Aimbot", "miss: " .. murderer.DisplayName)
        end)
    end

    if wallbang then
        local t3 = os.clock()
        repeat RunService.Heartbeat:Wait() until os.clock() - t3 >= 0.1
        if holdConn then holdConn:Disconnect() end
        if hrp.Parent and hum.Health > 0 then
            hrp.CFrame = savedCF
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        cam.CameraType = oldCamType
        cam.CameraSubject = hum
    end

    shootBusy = false
end

-- UI
local silentToggle = s:Toggle("Silent Aimbot",
    "click anywhere - the bullet hits the murderer",
    function(on)
        silentAim.on = on
        notify("Silent Aimbot: " .. (on and "On" or "Off"),
            on and "every click targets the murderer" or "disabled")
    end)

local wallbangToggle = s:Toggle("WallBang",
    "shots go straight through walls",
    function(on) silentAim.wallbang = on end)
wallbangToggle.Set(true, true)

local autoPredToggle = s:Toggle("Auto prediction",
    "sets Prediction from your ping",
    function(on) silentAim.auto = on end)
autoPredToggle.Set(true, true)

local predSlider = s:Slider("Prediction", 0, 700, 100,
    function(v) silentAim.pred = v end,
    function(v) return v .. "ms" end)

s:Toggle("Auto Shoot Murderer",
    "you have the gun - the murderer gets shot",
    function(on)
        autoShoot = on
        lastAutoShoot = 0
        notify("Auto Shoot: " .. (on and "On" or "Off"),
            on and "watching for the murderer" or "disabled")
    end)

s:Button("Shoot Murderer",
    "take out the gun and fire right now",
    function() task.spawn(shootMurderer, true) end)

local lastAutoPred = 0
connect(RunService.Heartbeat, function()
    if not silentAim.auto or os.clock() - lastAutoPred < 1 then return end
    lastAutoPred = os.clock()
    local v = math.clamp(math.floor((getPing() / 2 + 100) / 10 + 0.5) * 10, 0, 700)
    silentAim.pred = v
    predSlider.Set(v, true)
end)

connect(RunService.Heartbeat, function()
    if not autoShoot or shootBusy or os.clock() - lastAutoShoot < 2 then return end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 or inLobby(hrp.Position) then return end
    if not findTool(player, "Gun") or not getMurderer() then return end
    lastAutoShoot = os.clock()
    task.spawn(shootMurderer, false)
end)

local activatedConn, hookedGun
connect(RunService.Heartbeat, function()
    local char = player.Character
    local gun = char and char:FindFirstChild("Gun")
    if gun == hookedGun then return end
    if activatedConn then activatedConn:Disconnect() end
    hookedGun = gun
    if gun then
        activatedConn = gun.Activated:Connect(function()
            if silentAim.on and getMurderer() then
                task.spawn(shootMurderer, false)
            end
        end)
        table.insert(connections, activatedConn)
    end
end)
-- ============================================================
-- ROLE FLING
-- ============================================================
local fling = {
    autoSheriff = false,
    busy = false,
    cancel = false,
    nextScan = 0,
    autoCharacter = nil,
    autoReadyAt = 0,
}
local flungCharacters = {}
local roleCacheFling, roleCacheAtFling = {}, 0
local activeCleanup

local function refreshFlingRoles()
    if os.clock() - roleCacheAtFling < 1 then return end
    roleCacheAtFling = os.clock()
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("GetPlayerData", true)
    if not (remote and remote:IsA("RemoteFunction")) then return end
    local ok, data = pcall(remote.InvokeServer, remote)
    if not ok or type(data) ~= "table" then return end
    local nextRoles = {}
    for name, info in pairs(data) do
        if type(info) == "table" and type(info.Role) == "string"
            and not info.Dead and not info.Killed then
            nextRoles[name] = info.Role
        end
    end
    roleCacheFling = nextRoles
end

local function hasRoleFling(p, role)
    if role == "Murderer" and findTool(p, "Knife") then return true end
    if role == "Sheriff" and findTool(p, "Gun") then return true end
    local v = roleCacheFling[p.Name]
    return (role == "Murderer" and v == "Murderer")
        or (role == "Sheriff" and (v == "Sheriff" or v == "Hero"))
end

local function findRoleTarget(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and hasRoleFling(p, role) then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then return p end
        end
    end
    refreshFlingRoles()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and hasRoleFling(p, role) then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then return p end
        end
    end
end

local function drawImpact(pos, color)
    local ring = create("Part", {
        Name = "SdwgXyzFlingImpact",
        Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        CastShadow = false, Material = Enum.Material.Neon,
        Color = color, Transparency = 0.15,
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.12, 1, 1),
        CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
        Parent = workspace,
    })
    tween(ring, 0.45, { Size = Vector3.new(0.12, 14, 14), Transparency = 1 },
        Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
    game:GetService("Debris"):AddItem(ring, 0.5)
end

local function flingPlayer(target, role, manual)
    if fling.busy then
        if manual then notify("Role Fling", "another fling is running") end
        return false
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local targetChar = target and target.Character
    local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not (root and hum and hum.Health > 0 and targetRoot and targetHum and targetHum.Health > 0) then
        if manual then notify("Role Fling", (role or "target") .. " not available") end
        return false
    end
    if targetHum.Sit then
        if manual then notify("Role Fling", target.DisplayName .. " is sitting") end
        return false
    end

    fling.busy, fling.cancel = true, false

    local savedPivot = char:GetPivot()
    local savedAutoRotate = hum.AutoRotate
    local savedFallenHeight = workspace.FallenPartsDestroyHeight
    local savedSeated = hum:GetStateEnabled(Enum.HumanoidStateType.Seated)
    local fallenDisabled = false
    local color = role == "Sheriff" and Color3.fromRGB(70, 150, 255) or Color3.fromRGB(255, 70, 70)

    local highlight = create("Highlight", {
        Name = "SdwgXyzFlingTarget",
        Adornee = targetChar,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillColor = color, FillTransparency = 0.65,
        OutlineColor = accentColor, OutlineTransparency = 0,
        Parent = targetChar,
    })
    local marker = create("BillboardGui", {
        Name = "SdwgXyzFlingMarker",
        Adornee = targetRoot, AlwaysOnTop = true,
        Size = UDim2.fromOffset(150, 30),
        StudsOffset = Vector3.new(0, 3.5, 0),
        Parent = gui,
    })
    create("TextLabel", {
        Text = "FLINGING  ↓",
        Font = Enum.Font.GothamBlack, TextSize = 14,
        TextColor3 = color,
        TextStrokeColor3 = Color3.new(),
        TextStrokeTransparency = 0.25,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = marker,
    })

    local cleaned = false
    local function cleanup()
        if cleaned then return end
        cleaned = true
        for _, inst in ipairs({ highlight, marker }) do
            if inst and inst.Parent then inst:Destroy() end
        end
        pcall(hum.SetStateEnabled, hum, Enum.HumanoidStateType.Seated, savedSeated)
        if player.Character == char and root.Parent and hum.Health > 0 then
            pcall(function()
                for _ = 1, 6 do
                    char:PivotTo(savedPivot * CFrame.new(0, 0.5, 0))
                    for _, part in ipairs(char:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.AssemblyLinearVelocity = Vector3.zero
                            part.AssemblyAngularVelocity = Vector3.zero
                        end
                    end
                    if (root.Position - savedPivot.Position).Magnitude < 25 then break end
                    RunService.Heartbeat:Wait()
                end
                hum.AutoRotate = savedAutoRotate
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
        end
        if fallenDisabled then
            pcall(function() workspace.FallenPartsDestroyHeight = savedFallenHeight end)
        end
        fling.busy = false
        activeCleanup = nil
    end

    activeCleanup = cleanup
    hum.AutoRotate = false
    fallenDisabled = pcall(function()
        workspace.FallenPartsDestroyHeight = 0 / 0
    end)
    if not fallenDisabled then
        cleanup()
        if manual then notify("Role Fling", "executor cannot disable FallenPartsDestroyHeight") end
        return false
    end
    pcall(hum.SetStateEnabled, hum, Enum.HumanoidStateType.Seated, false)
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(player, "SimulationRadius", math.huge)
        end
    end)

    local started = os.clock()
    local lastPos = targetRoot.Position
    local launchOrigin = lastPos
    local launched = false
    local targetPart = targetRoot

    local function targetEscaped()
        if not targetPart.Parent then return false end
        lastPos = targetPart.Position
        local distance = (lastPos - launchOrigin).Magnitude
        local speed = targetPart.AssemblyLinearVelocity.Magnitude
        return lastPos.Y <= savedFallenHeight + 30
            or distance > 350
            or (distance > 120 and speed > 200)
    end

    local function flingPosition(pos, angle)
        local cf = CFrame.new(targetPart.Position) * pos * angle
        root.CFrame = cf
        char:PivotTo(cf)
        root.Velocity = Vector3.new(9e7, 9e8, 9e7)
        root.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local ok, err = pcall(function()
        local angle = 0
        while os.clock() - started < 2 and not fling.cancel do
            if not (root.Parent and hum.Health > 0 and targetPart.Parent and targetHum.Health > 0) then
                break
            end
            if targetEscaped() then
                launched = true
                break
            end
            local speed = targetPart.AssemblyLinearVelocity.Magnitude
            angle = angle + 100
            local steps
            if speed < 50 then
                local lead = targetHum.MoveDirection * speed / 1.25
                local rotation = CFrame.Angles(math.rad(angle), 0, 0)
                steps = {
                    { CFrame.new(0, 1.5, 0) + lead, rotation },
                    { CFrame.new(0, -1.5, 0) + lead, rotation },
                    { CFrame.new(0, 1.5, 0) + lead, rotation },
                    { CFrame.new(0, -1.5, 0) + lead, rotation },
                    { CFrame.new(0, 1.5, 0) + targetHum.MoveDirection, rotation },
                    { CFrame.new(0, -1.5, 0) + targetHum.MoveDirection, rotation },
                }
            else
                local flat = CFrame.new()
                local quarter = CFrame.Angles(math.rad(90), 0, 0)
                steps = {
                    { CFrame.new(0, 1.5, targetHum.WalkSpeed), quarter },
                    { CFrame.new(0, -1.5, -targetHum.WalkSpeed), flat },
                    { CFrame.new(0, 1.5, targetHum.WalkSpeed), quarter },
                    { CFrame.new(0, -1.5, 0), quarter },
                    { CFrame.new(0, -1.5, 0), flat },
                    { CFrame.new(0, -1.5, 0), quarter },
                    { CFrame.new(0, -1.5, 0), flat },
                }
            end
            for _, step in ipairs(steps) do
                flingPosition(step[1], step[2])
                task.wait()
                if fling.cancel or targetEscaped() then
                    launched = not fling.cancel
                    break
                end
            end
            if launched then break end
        end
    end)

    cleanup()
    if ok and launched and lastPos then
        drawImpact(lastPos, color)
    end
    if manual then
        if ok and launched then
            notify("Fling " .. role, target.DisplayName .. " flung down")
        else
            notify("Role Fling", "target resisted")
        end
    end
    return ok and launched
end

local function flingRole(role, manual)
    local target = findRoleTarget(role)
    if not target then
        if manual then notify("Role Fling", role:lower() .. " not found") end
        return
    end
    flingPlayer(target, role, manual)
end

-- Auto Fling Sheriff
connect(RunService.Heartbeat, function()
    if not fling.autoSheriff or fling.busy or os.clock() < fling.nextScan then return end
    fling.nextScan = os.clock() + 0.8
    local target = findRoleTarget("Sheriff")
    local char = target and target.Character
    local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not char or not targetRoot or not myRoot
        or flungCharacters[char]
        or inLobby(targetRoot.Position)
        or inLobby(myRoot.Position) then
        fling.autoCharacter = nil
        fling.autoReadyAt = 0
        return
    end
    if fling.autoCharacter ~= char then
        fling.autoCharacter = char
        fling.autoReadyAt = os.clock() + 2.5
        return
    end
    if os.clock() < fling.autoReadyAt or target.Character ~= char or not hasRoleFling(target, "Sheriff") then
        return
    end
    fling.autoReadyAt = os.clock() + 2.5
    task.spawn(function()
        if flingPlayer(target, "Sheriff", false) then
            flungCharacters[char] = true
        end
    end)
end)

connect(Players.PlayerRemoving, function(p)
    if p.Character then flungCharacters[p.Character] = nil end
end)

-- UI
local fSec = addSection(combatTab, "Role Fling")
fSec:Toggle("Auto Fling Sheriff",
    "fling each sheriff down once per life",
    function(on)
        fling.autoSheriff = on
        fling.nextScan = 0
        fling.autoCharacter = nil
        fling.autoReadyAt = 0
        if not on then fling.cancel = true end
        notify("Auto Fling Sheriff: " .. (on and "On" or "Off"),
            on and "watching for the sheriff" or "disabled")
    end)
fSec:Button("Fling Sheriff", "fling the current sheriff down",
    function() flingRole("Sheriff", true) end)
fSec:Button("Fling Murderer", "fling the current murderer down",
    function() flingRole("Murderer", true) end)

table.insert(connections, {
    Disconnect = function()
        fling.autoSheriff = false
        fling.cancel = true
        if activeCleanup then activeCleanup() end
    end,
})
-- ============================================================
-- AUTO GET GUN (teleport version)
-- ============================================================
local getGun = {
    on = false,
    auto = true,
    range = 500,
    holdTime = 0.5,
    returnAfter = false,
    autoEquip = true,
}

local getGunBusy = false

-- Универсальный поиск упавшей пушки
local GUN_DROP_NAMES = {
    "GunDrop", "gundrop", "gun_drop", "Gun", "gun",
    "DroppedGun", "droppedgun", "Dropped_Gun",
    "Weapon", "weapon", "Pickup", "pickup",
}

local function matchGunName(name)
    for _, n in ipairs(GUN_DROP_NAMES) do
        if name == n then return true end
    end
    return false
end

-- ============================================================
-- GET GUN — телепорт к пушке (улучшенная версия)
-- ============================================================

-- Диагностика: включать ли отладочные уведомления
local getGunDebug = false

local function matchGunName(name)
    local lower = name:lower()
    if lower == "gundrop" then return true end
    if lower == "droppedgun" then return true end
    if lower == "gun_drop" then return true end
    if lower == "gun" and #name <= 8 then return true end
    return false
end

-- Глубокий поиск пушки
local function findGunDrop()
    -- 1. Прямые дети workspace
    for _, d in ipairs(workspace:GetChildren()) do
        if matchGunName(d.Name) then
            if d:IsA("BasePart") then return d, "direct" end
            if d:IsA("Model") then
                local part = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)
                if part then return part, "direct-model" end
            end
        end
    end

    -- 2. Глубокий поиск по всем потомкам
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and matchGunName(d.Name) then
            return d, "deep"
        end
    end

    -- 3. Поиск по ключевым словам
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") then
            local lower = d.Name:lower()
            if lower:find("gundrop") or lower:find("droppedgun") then
                return d, "keyword"
            end
        end
    end

    return nil, "not-found"
end

-- Основная функция телепорта
local function teleportToGun(gun, manual)
    if getGunBusy then
        if manual and getGunDebug then
            notify("Get Gun", "already busy")
        end
        return
    end

    if not gun or not gun.Parent then
        if manual then notify("Get Gun", "no dropped gun found") end
        return
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then
        if manual then notify("Get Gun", "you're dead") end
        return
    end
    if findTool(player, "Knife") then
        if manual then notify("Get Gun", "murderer can't pick up the gun") end
        return
    end
    if findTool(player, "Gun") then
        if manual then notify("Get Gun", "you already have the gun") end
        return
    end

    getGunBusy = true
    local savedCF = hrp.CFrame
    local savedVel = hrp.AssemblyLinearVelocity

    -- ДИАГНОСТИКА
    if getGunDebug then
        notify("Get Gun", "tp to " .. tostring(gun.Position))
    end

    -- Пробуем несколько позиций телепорта
    local teleportOffsets = {
        Vector3.new(0, 2, 0),   -- сверху
        Vector3.new(0, 0, 0),   -- в центр (прямо в пушку)
        Vector3.new(0, -1, 0),  -- чуть снизу (для пушки на полу)
    }

    local success = false

    for _, offset in ipairs(teleportOffsets) do
        if success or not gun.Parent or findTool(player, "Gun") then break end

        -- Телепортируемся
        local targetCF = CFrame.new(gun.Position + offset)
        hrp.CFrame = targetCF
        hrp.AssemblyLinearVelocity = Vector3.zero

        -- Держимся у пушки
        local holdUntil = os.clock() + getGun.holdTime
        while os.clock() < holdUntil do
            if not gun.Parent then break end
            if findTool(player, "Gun") then
                success = true
                break
            end
            hrp.CFrame = CFrame.new(gun.Position + offset)
            hrp.AssemblyLinearVelocity = Vector3.zero
            RunService.Heartbeat:Wait()
        end

        if findTool(player, "Gun") then
            success = true
        end
    end

    -- Возврат
    if getGun.returnAfter and hrp.Parent and hum.Health > 0 then
        pcall(function()
            hrp.CFrame = savedCF
            hrp.AssemblyLinearVelocity = savedVel
        end)
    end

    -- Авто-экип
    if getGun.autoEquip and findTool(player, "Gun") then
        local backpack = player:FindFirstChildOfClass("Backpack")
        local gunTool = (player.Character and player.Character:FindFirstChild("Gun"))
            or (backpack and backpack:FindFirstChild("Gun"))
        if gunTool and gunTool.Parent == backpack then
            hum:EquipTool(gunTool)
        end
    end

    getGunBusy = false

    if findTool(player, "Gun") then
        notify("Get Gun", "gun picked up")
    elseif manual then
        notify("Get Gun", "couldn't pick up")
    end
end

-- Авто-цикл
connect(RunService.Heartbeat, function()
    if not getGun.on or getGunBusy then return end
    if not getGun.auto then return end
    if findTool(player, "Knife") then return end
    if findTool(player, "Gun") then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or inLobby(hrp.Position) then return end

    local gun = findGunDrop()
    if not gun then return end
    if (gun.Position - hrp.Position).Magnitude > getGun.range then return end

    task.spawn(teleportToGun, gun, false)
end)

-- UI
local ggSec = addSection(combatTab, "Get Gun")

ggSec:Toggle("Auto Get Gun",
    "when sheriff dies, teleport to the dropped gun and pick it up",
    function(on)
        getGun.on = on
        notify("Get Gun: " .. (on and "On" or "Off"),
            on and "watching for dropped guns" or "disabled")
    end)

ggSec:Toggle("Auto search",
    "keep scanning for guns automatically",
    function(v) getGun.auto = v end)
    .Set(true, true)

ggSec:Toggle("Return after",
    "teleport back to your old position after picking up",
    function(v) getGun.returnAfter = v end)
    .Set(false, true)

ggSec:Toggle("Auto equip",
    "take the gun to your hand after pickup",
    function(v) getGun.autoEquip = v end)
    .Set(true, true)

ggSec:Slider("Max range", 50, 2000, 500,
    function(v) getGun.range = v end,
    function(v) return v .. " studs" end)

ggSec:Slider("Hold time", 0.1, 2, 0.3,
    function(v) getGun.holdTime = v end,
    function(v) return string.format("%.1fs", v) end)

ggSec:Toggle("Debug",
    "show diagnostic notifications",
    function(v) getGunDebug = v end)
    .Set(false, true)

ggSec:Button("Find Gun (test)",
    "scan workspace and show what was found",
    function()
        local gun, source = findGunDrop()
        if gun then
            notify("Find Gun", "FOUND [" .. source .. "]")
            notify("Position", tostring(gun.Position))
            notify("Name", gun.Name .. " (" .. gun.ClassName .. ")")
            notify("Anchored", tostring(gun.Anchored))
            if gun.Parent then
                notify("Path", gun:GetFullName():sub(1, 60))
            end
        else
            notify("Find Gun", "nothing found")
        end
    end)

ggSec:Button("Get Gun Now",
    "teleport to the dropped gun right now",
    function()
        local gun, source = findGunDrop()
        if getGunDebug then
            notify("Get Gun", "source: " .. tostring(source))
        end
        task.spawn(teleportToGun, gun, true)
    end)
    -- ============================================================
-- MURDERER — Knife Aura + Throwing Knife Aura
-- ============================================================

-- Утилита: прямая видимость между двумя точками
local function isVisible(a, b, ignoreChar, ignoreKnife)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local list = { workspace.CurrentCamera }
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then table.insert(list, pl.Character) end
    end
    if ignoreChar then table.insert(list, ignoreChar) end
    if ignoreKnife then table.insert(list, ignoreKnife) end
    params.FilterDescendantsInstances = list

    local dir = b - a
    for _ = 1, 8 do
        params.FilterDescendantsInstances = list
        local hit = workspace:Raycast(a, dir, params)
        if not hit then return true end
        local inst = hit.Instance
        -- Если попали в тонкое/прозрачное — пропускаем
        if inst.Transparency >= 0.9 or not inst.CanCollide then
            table.insert(list, inst)
        else
            return false
        end
    end
    return true
end

-- ═══════════════════════════════════════════════════════════
--  KNIFE AURA
-- ═══════════════════════════════════════════════════════════
local knifeAura = {
    on = false,
    range = 50,
    wallCheck = false,
    autoEquip = true,
    tickRate = 0.1,
    showRange = false,
    silent = false,
}

local knifeAuraThread = nil
local rangeVisual = nil

local function createRangeVisual()
    if rangeVisual then rangeVisual:Destroy() end
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local ring = Instance.new("Part")
    ring.Name = "SdwgXyzAuraRange"
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.CanTouch = false
    ring.CastShadow = false
    ring.Material = Enum.Material.Neon
    ring.Color = accentColor
    ring.Transparency = 0.7
    ring.Size = Vector3.new(0.1, knifeAura.range * 2, knifeAura.range * 2)
    ring.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = workspace.CurrentCamera

    rangeVisual = ring
end

local function updateRangeVisual()
    if not knifeAura.showRange or not knifeAura.on then
        if rangeVisual then
            rangeVisual:Destroy()
            rangeVisual = nil
        end
        return
    end
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if rangeVisual then
            rangeVisual:Destroy()
            rangeVisual = nil
        end
        return
    end
    if not rangeVisual or not rangeVisual.Parent then
        createRangeVisual()
    end
    if rangeVisual then
        rangeVisual.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
        rangeVisual.Size = Vector3.new(0.1, knifeAura.range * 2, knifeAura.range * 2)
    end
end

local function getKnife()
    local char = player.Character
    local knife = char and char:FindFirstChild("Knife")
    if knife then return knife end
    if knifeAura.autoEquip then
        local backpack = player:FindFirstChildOfClass("Backpack")
        knife = backpack and backpack:FindFirstChild("Knife")
        if knife then
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:EquipTool(knife)
                -- Ждём экипировки максимум 10 кадров
                for _ = 1, 10 do
                    if knife.Parent == char then break end
                    RunService.Heartbeat:Wait()
                end
            end
        end
    end
    return knife
end

local function hitWithKnife(knife, targetChar, targetHrp)
    -- 1) Активация инструмента
    pcall(function() knife:Activate() end)

    local handle = knife:FindFirstChild("Handle")

    -- 2) Если есть Events (KnifeStabbed / HandleTouched) — отправляем ремоуты
    local events = knife:FindFirstChild("Events")
    if events then
        local stab = events:FindFirstChild("KnifeStabbed")
        if stab then pcall(function() stab:FireServer() end) end

        local touch = events:FindFirstChild("HandleTouched")
        if touch and targetHrp then
            pcall(function() touch:FireServer(targetHrp) end)
        end
    end

    -- 3) firetouchinterest — эмулируем касание
    if handle and targetChar and firetouchinterest then
        for _, name in ipairs({ "HumanoidRootPart", "UpperTorso", "Torso", "Head" }) do
            local part = targetChar:FindFirstChild(name)
            if part then
                pcall(function()
                    firetouchinterest(handle, part, 0)
                    firetouchinterest(handle, part, 1)
                end)
            end
        end
    end
end

local function startKnifeAura()
    if knifeAuraThread then return end
    knifeAuraThread = task.spawn(function()
        while knifeAura.on do
            pcall(function()
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end

                local knife = getKnife()
                if not knife or not knife:FindFirstChild("Handle") then return end

                -- Проходим по всем игрокам
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player then
                        local th = alive(p)
                        if th then
                            local thrp, thum, tchar = alive(p)
                            if thrp and thum and thum.Health > 0 then
                                local dist = (thrp.Position - hrp.Position).Magnitude
                                if dist <= knifeAura.range then
                                    -- Проверка стен (если включена)
                                    local canHit = true
                                    if knifeAura.wallCheck then
                                        canHit = isVisible(hrp.Position, thrp.Position, char, knife.Handle)
                                    end
                                    if canHit then
                                        hitWithKnife(knife, tchar, thrp)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(knifeAura.tickRate)
        end
        knifeAuraThread = nil
    end)
end

local function stopKnifeAura()
    knifeAura.on = false
    knifeAuraThread = nil
    if rangeVisual then
        rangeVisual:Destroy()
        rangeVisual = nil
    end
end

-- Обновление визуала радиуса в реальном времени
connect(RunService.RenderStepped, function()
    if knifeAura.on and knifeAura.showRange then
        updateRangeVisual()
    end
end)

-- ═══════════════════════════════════════════════════════════
--  THROWING KNIFE AURA (летящий нож)
-- ═══════════════════════════════════════════════════════════
local throwAura = {
    on = false,
    range = 150,
    wallCheck = false,
    autoEquip = true,
}

local throwConnections = {}

local function startThrowAura()
    if #throwConnections > 0 then return end

    local conn = workspace.DescendantAdded:Connect(function(descendant)
        if not throwAura.on then return end
        if not (descendant:IsA("Model") and descendant.Name == "ThrowingKnife") then return end

        task.spawn(function()
            -- Ждём, пока появятся дочерние объекты
            local bladePos = descendant:WaitForChild("BladePosition", 2)
                or descendant:FindFirstChild("KnifeVisual", true)
            if not bladePos then return end

            local lastCheck = 0
            while descendant.Parent and throwAura.on do
                local now = tick()
                if now - lastCheck >= 0.0333 then
                    lastCheck = now
                    pcall(function()
                        local char = player.Character
                        local knife = char and char:FindFirstChild("Knife")
                        if not knife or not knife:FindFirstChild("Handle") then
                            if throwAura.autoEquip then
                                local hum = char and char:FindFirstChildOfClass("Humanoid")
                                local backpack = player:FindFirstChildOfClass("Backpack")
                                local bk = backpack and backpack:FindFirstChild("Knife")
                                if hum and bk then
                                    hum:EquipTool(bk)
                                    task.wait(0.05)
                                    knife = bk
                                end
                            end
                        end
                        if not knife or not knife:FindFirstChild("Handle") then return end

                        local events = knife:FindFirstChild("Events")
                        local touch = events and events:FindFirstChild("HandleTouched")
                        local bladePos3D = bladePos.Position

                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= player then
                                local thrp, thum, tchar = alive(p)
                                if thrp and thum and thum.Health > 0 then
                                    local dist = (thrp.Position - bladePos3D).Magnitude
                                    if dist >= 1 and dist <= throwAura.range then
                                        local canHit = true
                                        if throwAura.wallCheck then
                                            canHit = isVisible(bladePos3D, thrp.Position, tchar, knife.Handle)
                                        end
                                        if canHit then
                                            -- firetouchinterest
                                            if firetouchinterest then
                                                pcall(function()
                                                    firetouchinterest(thrp, knife.Handle, 0)
                                                    firetouchinterest(thrp, knife.Handle, 1)
                                                end)
                                            end
                                            -- ремоут HandleTouched
                                            if touch then
                                                pcall(function() touch:FireServer(thrp) end)
                                            end
                                            -- ремоут KnifeStabbed (иногда тоже нужно)
                                            local stab = events:FindFirstChild("KnifeStabbed")
                                            if stab then
                                                pcall(function() stab:FireServer() end)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
                RunService.Heartbeat:Wait()
            end
        end)
    end)

    table.insert(throwConnections, conn)
end

local function stopThrowAura()
    throwAura.on = false
    for _, c in ipairs(throwConnections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(throwConnections)
end

-- ═══════════════════════════════════════════════════════════
--  UI
-- ═══════════════════════════════════════════════════════════
local m = addSection(combatTab, "Murderer")

m:Toggle("Knife Aura", "stand still, knife hits everyone in range",
    function(on)
        if on then
            local hum = getHumanoid()
            if not findTool(player, "Knife") then
    notify("Knife Aura", "you need the knife")
    return
end
            knifeAura.on = true
            startKnifeAura()
            notify("Knife Aura: On", "range " .. knifeAura.range .. " studs")
        else
            stopKnifeAura()
            notify("Knife Aura: Off", "disabled")
        end
    end)

m:Slider("Knife range", 1, 350, 50,
    function(v)
        knifeAura.range = v
        if knifeAura.on and knifeAura.showRange then
            if rangeVisual then
                rangeVisual.Size = Vector3.new(0.1, v * 2, v * 2)
            end
        end
    end,
    function(v) return v .. " studs" end)

m:Slider("Knife tick", 0.05, 0.3, 0.1,
    function(v) knifeAura.tickRate = v end,
    function(v) return string.format("%.2fs", v) end)

m:Toggle("Wall check", "only hit if visible (safer, less suspicious)",
    function(v) knifeAura.wallCheck = v end)

m:Toggle("Auto equip knife", "automatically take knife to hand",
    function(v) knifeAura.autoEquip = v end)
    .Set(true, true)

m:Toggle("Show range", "draw a circle around you",
    function(v)
        knifeAura.showRange = v
        if not v and rangeVisual then
            rangeVisual:Destroy()
            rangeVisual = nil
        end
    end)

m:Toggle("Throwing Knife Aura",
    "your thrown knife hits everyone in range on the fly",
    function(on)
        if on then
            throwAura.on = true
            startThrowAura()
            notify("Throw Aura: On", "range " .. throwAura.range .. " studs")
        else
            stopThrowAura()
            notify("Throw Aura: Off", "disabled")
        end
    end)

m:Slider("Throw range", 20, 350, 150,
    function(v) throwAura.range = v end,
    function(v) return v .. " studs" end)

m:Toggle("Throw wall check", "throwing knife only hits visible players",
    function(v) throwAura.wallCheck = v end)

-- Unload hook
table.insert(connections, {
    Disconnect = function()
        stopKnifeAura()
        stopThrowAura()
    end,
})
end
local function setupDrone()
-- -------- DRONE --------
do
    -- ============================================================
    -- DRONE — Shahed / FPV
    -- ============================================================

    -- ===== Настройки =====
    local droneKind = "Shahed"       -- Shahed / FPV
    local droneImpact = "Kill"       -- Kill / Fling

    -- ===== ID для загрузки моделей =====
    local shahedIds = { 120141614672192, 111443745475294, 16531510943 }
    local shahedFlip = {
    [120141614672192] = -1,
    [111443745475294] = -1,
    [16531510943] = -1,
}
    local fpvIds    = { 124994246147928, 129274863429961, 79445961621887 }

    -- ===== Звуки (ID) =====
    local soundIds = {
        engine = { 106621472307027, 117678889994053, 86747216998490 },
        boom   = { 125127520917980, 7157159568, 9126102254 },
        rumble = { 1843024924, 9846227426, 138432031406888 },
        static = { 96891705634188, 83265726239905, 128865910652923 },
        fpv    = { 114037851906101, 78411105609654, 122096583027065 },
    }

    -- Кэши
    local droneCache = {}
    local soundCache = {}
    local droneTemplate = nil
    local droneLoading = false
    local soundsLoading = false

    local ContentProvider = game:GetService("ContentProvider")
    local SoundService = game:GetService("SoundService")

    -- ===== Вспомогательные: получение всех BasePart =====
    local function getParts(m)
        local parts = {}
        for _, x in ipairs(m:GetDescendants()) do
            if x:IsA("BasePart") then
                table.insert(parts, x)
            end
        end
        return parts
    end

    -- ============================================================
    -- ПРОЦЕДУРНЫЕ МОДЕЛИ (fallback)
    -- ============================================================

    local function buildShahed()
        local m = Instance.new("Model")
        local col = Color3.fromRGB(92, 96, 100)

        local function part(className, size, cf, color, shape)
            local p = Instance.new(className)
            p.Size, p.CFrame = size, cf
            p.Color = color or col
            p.Material = Enum.Material.SmoothPlastic
            if shape then p.Shape = shape end
            p.Parent = m
            return p
        end

        local rot90 = CFrame.Angles(0, math.rad(90), 0)
        part("Part", Vector3.new(9.6, 1.3, 1.3), CFrame.new(0, 0, 0.2) * rot90, nil, Enum.PartType.Cylinder)
        part("Part", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 0, -4.6), nil, Enum.PartType.Ball)
        part("Part", Vector3.new(0.5, 0.9, 0.9), CFrame.new(0, 0, 5.2) * rot90, Color3.fromRGB(40, 40, 40), Enum.PartType.Cylinder)
        part("Part", Vector3.new(0.12, 3.2, 0.3), CFrame.new(0, 0, 5.5), Color3.fromRGB(30, 30, 30)).Name = "Prop"
        part("WedgePart", Vector3.new(0.25, 4.9, 7.5), CFrame.fromMatrix(Vector3.new(3.05, 0, 0.75), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)))
        part("WedgePart", Vector3.new(0.25, 4.9, 7.5), CFrame.fromMatrix(Vector3.new(-3.05, 0, 0.75), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1)))
        part("Part", Vector3.new(0.2, 1.8, 1.4), CFrame.new(5.45, 0.4, 3.9))
        part("Part", Vector3.new(0.2, 1.8, 1.4), CFrame.new(-5.45, 0.4, 3.9))
        m.WorldPivot = CFrame.new()
        return m
    end

    local function buildFpv()
        local m = Instance.new("Model")

        local function part(size, cf, color, shape, mat)
            local p = Instance.new("Part")
            p.Size, p.CFrame = size, cf
            p.Color = color
            p.Material = mat or Enum.Material.SmoothPlastic
            if shape then p.Shape = shape end
            p.Parent = m
            return p
        end

        local dark = Color3.fromRGB(28, 28, 30)
        part(Vector3.new(0.9, 0.25, 1.5), CFrame.new(), dark)
        for _, a in ipairs({ 45, 135, 225, 315 }) do
            local r = math.rad(a)
            local tip = Vector3.new(math.sin(r) * 1.45, 0, math.cos(r) * 1.45)
            part(Vector3.new(0.18, 0.1, 2.9), CFrame.lookAt(Vector3.zero, tip) * CFrame.new(0, 0, -1.45), dark)
            part(Vector3.new(0.3, 0.32, 0.32), CFrame.new(tip + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 120, 70), Enum.PartType.Cylinder, Enum.Material.Metal)
            local prop = part(Vector3.new(0.04, 1.3, 1.3), CFrame.new(tip + Vector3.new(0, 0.36, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(20, 20, 20), Enum.PartType.Cylinder)
            prop.Transparency = 0.55
            prop.Name = "Prop"
        end
        part(Vector3.new(0.6, 0.45, 1.1), CFrame.new(0, 0.38, 0.1), Color3.fromRGB(40, 90, 170))
        part(Vector3.new(0.35, 0.3, 0.3), CFrame.new(0, 0.25, -0.75), Color3.fromRGB(15, 15, 15))
        part(Vector3.new(2.2, 0.55, 0.55), CFrame.new(0, -0.4, -0.7) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(110, 90, 55), Enum.PartType.Cylinder, Enum.Material.Metal)
        part(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -0.4, -1.8), Color3.fromRGB(200, 200, 190), Enum.PartType.Ball)
        m.WorldPivot = CFrame.new()
        return m
    end

    -- ============================================================
    -- ОРИЕНТАЦИЯ (Shahed / FPV)
    -- ============================================================
    local function orientShahed(m, parts, id)
        local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
        local boxes = {}
        for _, p in ipairs(parts) do
            local cf, h = p.CFrame, p.Size / 2
            local r = Vector3.new(
                math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
                math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
                math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z)
            lo, hi = lo:Min(cf.Position - r), hi:Max(cf.Position + r)
            table.insert(boxes, { cf.Position, r })
        end
        local size, center = hi - lo, (lo + hi) / 2
-- SHAHED смотрит ВДОЛЬ оси с наибольшим размером
local axis, sidebar
if size.X >= size.Y and size.X >= size.Z then
    axis, sidebar = Vector3.xAxis, Vector3.zAxis
elseif size.Y >= size.X and size.Y >= size.Z then
    axis, sidebar = Vector3.yAxis, Vector3.zAxis
else
    axis, sidebar = Vector3.zAxis, Vector3.xAxis
end
        local moment = 0
        for _, b in ipairs(boxes) do
            local a = b[2]:Dot(axis) * b[2]:Dot(sidebar)
            moment += (b[1] - center):Dot(axis) * a
        end
        local sign = moment >= 0 and 1 or -1
if shahedFlip[id] then sign = shahedFlip[id] end
m.WorldPivot = CFrame.lookAt(center, center - axis * sign)
        return math.max(size.X, size.Z)
    end

    local function orientFpv(m, parts, id)
        local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
        for _, p in ipairs(parts) do
            local cf, h = p.CFrame, p.Size / 2
            local r = Vector3.new(
                math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
                math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
                math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z)
            lo, hi = lo:Min(cf.Position - r), hi:Max(cf.Position + r)
        end
        local size, center = hi - lo, (lo + hi) / 2
        local best, bestScore, axis = nil, 0, Vector3.zAxis
        for _, p in ipairs(parts) do
            local sz = p.Size
            local longest = math.max(sz.X, sz.Y, sz.Z)
            local shortest = math.min(sz.X, sz.Y, sz.Z)
            local score = longest * longest * shortest / math.max(shortest, 0.05)
            if longest / math.max(shortest, 0.05) > 2.2 and score > bestScore then
                local cf = p.CFrame
                local longAxis = sz.X == longest and cf.RightVector or sz.Y == longest and cf.UpVector or cf.LookVector
                if math.abs(longAxis.Y) < 0.5 then
                    best, bestScore = p, score
                end
            end
        end
        local sign = 1
        if best then
            local sz, cf = best.Size, best.CFrame
            local longAxis = sz.X == math.max(sz.X, sz.Y, sz.Z) and cf.RightVector or sz.Y == math.max(sz.X, sz.Y, sz.Z) and cf.UpVector or cf.LookVector
            axis = math.abs(longAxis.X) > math.abs(longAxis.Z) and Vector3.xAxis or Vector3.zAxis
            local half = math.max(sz.X, sz.Y, sz.Z) / 2
            local c = (cf.Position - center):Dot(axis)
            local endA, endB = c + half * math.abs(longAxis:Dot(axis)), c - half * math.abs(longAxis:Dot(axis))
            sign = math.abs(endA) >= math.abs(endB) and -1 or 1
        end
        m.WorldPivot = CFrame.lookAt(center, center - axis * sign)
        return math.max(size.X, size.Z)
    end

    -- ============================================================
    -- ЗВУКИ
    -- ============================================================
    local function pickSound(list)
        for _, id in ipairs(list) do
            local s = Instance.new("Sound")
            s.SoundId = "rbxassetid://" .. id
            s.Volume = 0
            s.Parent = SoundService
            local loaded = false
            local ok = pcall(function()
                ContentProvider:PreloadAsync({ s }, function(_, status)
                    loaded = status == Enum.AssetFetchStatus.Success
                end)
            end)
            s:Destroy()
            if ok and loaded then
                return "rbxassetid://" .. id
            end
        end
        return "rbxassetid://" .. list[1]
    end

    local function ensureSounds()
        if soundsLoading then return end
        if next(soundCache) then return end
        soundsLoading = true
        task.spawn(function()
            for key, list in pairs(soundIds) do
                if not soundCache[key] then
                    soundCache[key] = pickSound(list)
                end
            end
            soundsLoading = false
        end)
    end

    -- ============================================================
    -- ЗАГРУЗКА ДРОНА
    -- ============================================================
    local function loadDrone(override)
        local kind = override or droneKind
        ensureSounds()
        if droneCache[kind] then
            droneTemplate = droneCache[kind]
            return droneTemplate
        end
        if droneLoading then
            while droneLoading do task.wait(0.1) end
            droneTemplate = droneCache[droneKind]
            return droneTemplate
        end
        droneLoading = true
        local isFpv = kind == "FPV"
        local m, usedId
        for _, id in ipairs(isFpv and fpvIds or shahedIds) do
            usedId = id
            local ok, objs = pcall(function()
                return game:GetObjects("rbxassetid://" .. id)
            end)
            if ok and objs and #objs > 0 then
                m = Instance.new("Model")
                for _, o in ipairs(objs) do
                    o.Parent = m
                end
                for _, x in ipairs(m:GetDescendants()) do
                    if x:IsA("LuaSourceContainer") or x:IsA("Sound") or x:IsA("ClickDetector")
                        or x:IsA("ProximityPrompt") or x:IsA("Humanoid") or x:IsA("BillboardGui") then
                        x:Destroy()
                    end
                end
                if m:FindFirstChildWhichIsA("BasePart", true) then
                    break
                end
                m:Destroy()
                m = nil
            end
        end
        local extent
        if m then
            extent = (isFpv and orientFpv or orientShahed)(m, getParts(m), usedId)
        elseif isFpv then
            m = buildFpv()
            extent = 4
        else
            m = buildShahed()
            extent = 11
        end
        pcall(function()
            m:ScaleTo(m:GetScale() * (isFpv and 3 or 5) / math.max(extent, 0.1))
        end)
        m.Archivable = true
        for _, x in ipairs(m:GetDescendants()) do
            x.Archivable = true
        end
        for _, p in ipairs(getParts(m)) do
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CanTouch = false
        end
        m.Name = "RockHubDrone"
        droneCache[kind] = m
        droneTemplate = droneCache[droneKind]
        droneLoading = false
        return m
    end

    -- ============================================================
    -- PLAY SOUND
    -- ============================================================
    local function playSound(key, parent, props)
        local soundId = soundCache[key]
        if not soundId then return end
        local s = Instance.new("Sound")
        s.SoundId = soundId
        for k, v in pairs(props) do
            s[k] = v
        end
        s.Parent = parent
        s:Play()
        if not s.IsLoaded then
            task.spawn(function()
                local deadline = os.clock() + 3
                while s.Parent and not s.IsLoaded and os.clock() < deadline do
                    task.wait(0.05)
                end
                if s.Parent and not s.IsPlaying then
                    s:Play()
                end
            end)
        end
        return s
    end

    -- ============================================================
    -- SHAKE CAMERA
    -- ============================================================
    local function shakeCamera(intensity, hideAfter)
        local name = "RockHubDroneShake" .. math.random(1000000)
        local start = os.clock()
        local last = CFrame.new()
        RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
            local cam = workspace.CurrentCamera
            local k = 1 - (os.clock() - start) / hideAfter
            if k <= 0 then
                cam.CFrame = cam.CFrame * last:Inverse()
                RunService:UnbindFromRenderStep(name)
                return
            end
            local a = intensity * k * k
            local offset = CFrame.Angles(
                (math.random() - 0.5) * a,
                (math.random() - 0.5) * a,
                (math.random() - 0.5) * a * 0.5)
            cam.CFrame = cam.CFrame * last:Inverse() * offset
            last = offset
        end)
    end

    -- ============================================================
    -- EXPLODE
    -- ============================================================
    local function explode(pos)
        local fx = Instance.new("Part")
        fx.Anchored, fx.CanCollide, fx.CanQuery, fx.CanTouch = true, false, false, false
        fx.Transparency, fx.Size, fx.Position = 1, Vector3.one, pos
        fx.Parent = workspace.CurrentCamera
-- Защита от отбрасывания взрывом
local myChar = player.Character
local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
local savedCollide = nil
if myHrp then
    savedCollide = myHrp.CanCollide
    myHrp.CanCollide = false
    task.delay(1.5, function()
        if myHrp and myHrp.Parent and savedCollide ~= nil then
            myHrp.CanCollide = savedCollide
        end
    end)
end
        local e = Instance.new("Explosion")
        e.Position, e.BlastPressure, e.BlastRadius = pos, 0, 0
        e.DestroyJointRadiusPercent = 0
        e.ExplosionType = Enum.ExplosionType.NoCraters
        e.Parent = workspace

        local function emit(props, n)
            local emitter = Instance.new("ParticleEmitter")
            emitter.Enabled = false
            for k, v in pairs(props) do
                emitter[k] = v
            end
            emitter.Parent = fx
            emitter:Emit(n)
        end

        emit({
            Texture = "rbxasset://textures/particles/fire_main.dds",
            Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 80, 20)),
            LightEmission = 1,
            Lifetime = NumberRange.new(0.35, 0.7),
            Speed = NumberRange.new(25, 55),
            SpreadAngle = Vector2.new(180, 180),
            Drag = 6,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) }),
            Transparency = NumberSequence.new(0.1, 1),
        }, 60)

        emit({
            Texture = "rbxasset://textures/particles/smoke_main.dds",
            Color = ColorSequence.new(Color3.fromRGB(60, 55, 50), Color3.fromRGB(25, 25, 25)),
            Lifetime = NumberRange.new(2.5, 4.5),
            Speed = NumberRange.new(8, 22),
            SpreadAngle = Vector2.new(180, 180),
            Drag = 2,
            Acceleration = Vector3.new(0, 6, 0),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 22) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
            RotSpeed = NumberRange.new(-40, 40),
            Rotation = NumberRange.new(0, 360),
        }, 35)

        emit({
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
            Color = ColorSequence.new(Color3.fromRGB(255, 190, 90)),
            LightEmission = 1,
            Lifetime = NumberRange.new(0.6, 1.4),
            Speed = NumberRange.new(60, 110),
            SpreadAngle = Vector2.new(180, 180),
            Acceleration = Vector3.new(0, -60, 0),
            Size = NumberSequence.new(0.6, 0),
        }, 80)

        local light = Instance.new("PointLight")
        light.Color, light.Brightness, light.Range = Color3.fromRGB(255, 160, 70), 10, 60
        light.Parent = fx
        TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()

        playSound("boom", fx, { Volume = 2, RollOffMinDistance = 20, RollOffMaxDistance = 1500 })
        playSound("rumble", fx, { Volume = 1.2, RollOffMinDistance = 60, RollOffMaxDistance = 3000 })

        local cam = workspace.CurrentCamera
        local d = (cam.CFrame.Position - pos).Magnitude
        if d < 200 then
            shakeCamera(0.06 * (1 - d / 200) + 0.01, 0.7)
        end

        game:GetService("Debris"):AddItem(fx, 7)
        game:GetService("Debris"):AddItem(e, 3)
    end

    -- ============================================================
    -- SIGNAL LOST (экран)
    -- ============================================================
    local function showSignalLost(targetName, flightTime)
        local font = Enum.Font.Code
        local root = create("CanvasGroup", {
            Name = "RockHubSignalLost",
            Position = UDim2.fromOffset(0, -100),
            Size = UDim2.new(1, 0, 1, 200),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 50,
            Parent = gui,
        })
        local content2 = create("Frame", {
            Position = UDim2.fromOffset(0, 100),
            Size = UDim2.new(1, 0, 1, -200),
            BackgroundTransparency = 1,
            ZIndex = 52,
            Parent = root,
        })

        local bars = {}
        for i = 1, 42 do
            bars[i] = create("Frame", {
                Position = UDim2.new(0, 0, (i - 1) / 42, 0),
                Size = UDim2.new(1.3, 0, 0.0238, 1),
                BorderSizePixel = 0,
                ZIndex = 51,
                Visible = false,
                Parent = root,
            })
        end

        for i = 0, 59 do
            create("Frame", {
                Position = UDim2.new(0, 0, i / 60, 0),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.75,
                BorderSizePixel = 0,
                ZIndex = 55,
                Parent = root,
            })
        end

        local box = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(380, 92),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 53,
            Parent = content2,
        })
        create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Parent = box })

        local titleLabel = create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            Text = "SIGNAL LOST",
            TextSize = 46,
            Font = font,
            TextColor3 = Color3.fromRGB(235, 235, 235),
            BackgroundTransparency = 1,
            ZIndex = 53,
            Parent = box,
        })
        local subtitle = create("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0.5, 58),
            Size = UDim2.fromOffset(500, 20),
            Text = targetName and "TARGET  " .. targetName:upper() .. "  -  HIT" or "NO TARGET",
            TextSize = 15,
            Font = font,
            TextColor3 = targetName and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(170, 170, 170),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 53,
            Parent = content2,
        })

        local staticSound = playSound("static", workspace.CurrentCamera, { Volume = 0.8 })
        local start = os.clock()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local t = os.clock() - start
            if t < 0.07 then
                return
            elseif t < 0.6 then
                root.BackgroundColor3 = Color3.new(0, 0, 0)
                for _, b in ipairs(bars) do
                    local g = math.random()
                    b.Visible = true
                    b.BackgroundColor3 = Color3.new(g, g, g)
                    b.BackgroundTransparency = math.random() * 0.35
                    b.Position = UDim2.new(-math.random() * 0.3, 0, b.Position.Y.Scale, 0)
                end
            else
                if staticSound and staticSound.IsPlaying then staticSound:Stop() end
                box.Visible = true
                subtitle.Visible = true
                for _, b in ipairs(bars) do
                    b.Visible = math.random() < 0.03
                    if b.Visible then
                        local g = math.random() * 0.5
                        b.BackgroundColor3 = Color3.new(g, g, g)
                        b.BackgroundTransparency = 0.6
                    end
                end
                local on = t * 2.2 % 1 < 0.62
                titleLabel.TextTransparency = on and 0 or 0.85
                box.Position = UDim2.new(0.5, math.random() < 0.06 and math.random(-6, 6) or 0, 0.5, 0)
            end
        end)

        task.delay(2.15, function()
            TweenService:Create(root, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
            task.wait(0.32)
            conn:Disconnect()
            root:Destroy()
            if staticSound then staticSound:Destroy() end
        end)
    end

    -- ============================================================
    -- TARGETS
    -- ============================================================
    local function getTargets(sheriffOnly, origin, includeLobby)
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                local hrp = alive(p)
                if hrp and (includeLobby or not inLobby(hrp.Position)) then
                    local gun = findTool(p, "Gun") ~= nil
                    if not sheriffOnly or gun then
                        table.insert(list, { p = p, gun = gun, d = (hrp.Position - origin).Magnitude })
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            if a.gun ~= b.gun then return a.gun end
            return a.d < b.d
        end)
        return list
    end

    -- ============================================================
    -- LAUNCH DRONE (главная функция)
    -- ============================================================
    local droneBusy = false
    local desyncPaused = false

    local function launchDrone()
        if droneBusy then return end
        local hrp, hum, char = alive(player)
        if not hrp then return end
        local impactMode = droneImpact

        if impactMode == "Kill" and not findTool(player, "Knife") then
            notify("Drone", "Kill impact requires the murderer knife")
            return
        end

        if not droneTemplate then
            notify("Drone", "loading...")
            loadDrone()
        end
        if not alive(player) then return end

        droneBusy = true
        pcall(function() hum:UnequipTools() end)

        -- Отключаем управление персонажем
        local controls
        task.spawn(function()
            pcall(function()
                local c = require(player.PlayerScripts:WaitForChild("PlayerModule", 1)):GetControls()
                c:Disable()
                controls = c
            end)
        end)

        local oldWalkSpeed, oldJumpPower = hum.WalkSpeed, hum.JumpPower
        hum.WalkSpeed, hum.JumpPower = 0, 0

        local cam = workspace.CurrentCamera
        local oldCamType = cam.CameraType
        cam.CameraType = Enum.CameraType.Scriptable

        local oldMouse, oldIconEnabled = UserInputService.MouseBehavior, UserInputService.MouseIconEnabled

        -- Скрываем персонажа
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then
                d.LocalTransparencyModifier = 1
            end
        end

        local look = cam.CFrame.LookVector
        local turn = math.atan2(-look.X, -look.Z)
        local pitch = 0.12
        local pos = hrp.Position + Vector3.new(0, 1.5, 0)
        local bank = 0
        local startTime = os.clock()
        local isFpv = droneKind == "FPV"
-- ============================================================
-- МОБИЛЬНОЕ УПРАВЛЕНИЕ — определение
-- ============================================================
local preferredTouch = false
pcall(function()
    preferredTouch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
end)
local touchDevice = UserInputService.TouchEnabled 
    and (preferredTouch or not UserInputService.KeyboardEnabled)
local mobileInput = {
    throttle = 0,
    yaw = 0,
    lookDelta = Vector2.zero,
    boost = false,
    up = false,
    down = false,
}
local mobileRoot
local fpView, vWasDown = false, false
-- ⬆️ КОНЕЦ ВСТАВКИ
        local drone = droneTemplate:Clone()
        local basePart = drone:FindFirstChildWhichIsA("BasePart", true)
        drone.Parent = cam

        -- Пропеллеры
        local props = {}
        for _, d in ipairs(drone:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = d.Name:lower()
                if n:find("prop") or n:find("blade") then
                    table.insert(props, d)
                end
            end
        end

        -- Engine sound
        local engine = playSound(isFpv and "fpv" or "engine", basePart, {
            Looped = true, Volume = 1,
            RollOffMinDistance = 15, RollOffMaxDistance = 700,
        })
-- ============================================================
-- OSD (только FPV)
-- ============================================================
local osd, osdLabels
if isFpv then
    osd = create("Frame", {
        Name = "RockHubDroneOsd",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    osdLabels = {}
    local function o(key, anchor, pos2, align)
        osdLabels[key] = create("TextLabel", {
            AnchorPoint = anchor,
            Position = pos2,
            Size = UDim2.fromOffset(200, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.Code,
            TextSize = 16,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextStrokeTransparency = 0.3,
            TextXAlignment = align,
            Text = "",
            Parent = osd,
        })
    end
    o("bat",  Vector2.new(0, 0),   UDim2.fromOffset(30, 70),   Enum.TextXAlignment.Left)
    o("time", Vector2.new(1, 0),   UDim2.new(1, -30, 0, 70),   Enum.TextXAlignment.Right)
    o("alt",  Vector2.new(0, 1),   UDim2.new(0, 30, 1, -80),   Enum.TextXAlignment.Left)
    o("spd",  Vector2.new(1, 1),   UDim2.new(1, -30, 1, -80),  Enum.TextXAlignment.Right)
    o("mode", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 70),   Enum.TextXAlignment.Center)
    osdLabels.mode.Text = droneImpact:upper() .. "   ACRO"
    osdLabels.mode.TextColor3 = droneImpact == "Kill" 
        and Color3.fromRGB(255, 80, 70) 
        or Color3.fromRGB(110, 190, 255)
end
-- ⬆️ КОНЕЦ ВСТАВКИ
        -- HUD
        local hud2 = create("Frame", {
            Name = "RockHubDroneHud",
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -24),
            Size = UDim2.fromOffset(0, 30),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Color3.fromRGB(14, 14, 18),
            BackgroundTransparency = 0.25,
            Parent = gui,
        })
        addCorner(hud2, 15)
        create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = hud2 })
        local hint = create("TextLabel", {
            Size = UDim2.fromScale(0, 1),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = Color3.fromRGB(235, 235, 240),
            Text = "",
            Parent = hud2,
        })

        -- Crosshair
        local crosshair = create("Frame", {
            Name = "RockHubDroneCross",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(6, 6),
            BackgroundColor3 = Color3.fromRGB(255, 70, 60),
            Parent = gui,
        })
        makeRound(crosshair)

        -- Управление (ПК)
        local keysDown = {}
        local done = false
        local conns = {}

        local function keyDown(k) return UserInputService:IsKeyDown(k) end

        -- End flight
        local function endFlight(exploded)
    for _, c in ipairs(conns) do c:Disconnect() end
    RunService:UnbindFromRenderStep("RockHubDronePilot")
    if engine then engine:Stop() end
    drone:Destroy()
    hud2:Destroy()
    crosshair:Destroy()
    if mobileRoot then mobileRoot:Destroy() end
    if osd then osd:Destroy() end
    UserInputService.MouseBehavior, UserInputService.MouseIconEnabled = oldMouse, oldIconEnabled

    if exploded then
        task.wait(0.5)
    end

    -- Показать персонажа
    if char.Parent then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then
                d.LocalTransparencyModifier = 0
            end
        end
    end

    -- ⚠️ ВОССТАНОВИТЬ ПОЗИЦИЮ ПЕРСОНАЖА НА ЗЕМЛЮ
    local currentHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local currentHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if currentHrp and currentHum and currentHum.Health > 0 then
        -- Опускаем на 3 стада (чтобы персонаж не висел в воздухе)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = { char, cam }
        local hit = workspace:Raycast(
            currentHrp.Position + Vector3.new(0, 50, 0),
            Vector3.new(0, -300, 0),
            rayParams)
        if hit then
            currentHrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3.5, 0))
        end
        currentHrp.AssemblyLinearVelocity = Vector3.zero
        currentHrp.AssemblyAngularVelocity = Vector3.zero
    end

    if controls then
        task.spawn(pcall, function() controls:Enable() end)
    end
    hum.WalkSpeed, hum.JumpPower = oldWalkSpeed, oldJumpPower
    if desyncPaused then
        desyncPaused = false
    end

    -- ⚠️ СБРОС КАМЕРЫ
    cam.CameraType = Enum.CameraType.Custom
    if hum.Parent then
        cam.CameraSubject = hum
    end

    -- ⚠️ ВАЖНО: СБРОСИТЬ MouseBehavior
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    droneBusy = false
end
        -- Detonate
        local function detonate(at)
            if done then return end
            done = true

            local best, bestDist = nil, 16
            for _, e in ipairs(getTargets(false, at, true)) do
                local th = alive(e.p)
                local d = th and (th.Position - at).Magnitude
                if d and d < bestDist then
                    best, bestDist = e.p, d
                end
            end

            if best and impactMode == "Kill" then
                task.spawn(function()
                    -- Ждём пока другие киллы закончатся
                    local t = os.clock()
                    while os.clock() - t < 2 do
                        RunService.Heartbeat:Wait()
                    end
                    if alive(best) then
                        -- Убиваем через нож
                        local knife = findTool(player, "Knife")
                        if not knife and player.Character then
                            knife = player.Character:FindFirstChild("Knife")
                        end
                        if knife then
                            for _, name in ipairs({ "HumanoidRootPart", "UpperTorso", "Torso", "Head" }) do
                                local part = best.Character and best.Character:FindFirstChild(name)
                                if part and firetouchinterest then
                                    pcall(function()
                                        firetouchinterest(knife.Handle, part, 0)
                                        firetouchinterest(knife.Handle, part, 1)
                                    end)
                                end
                            end
                        end
                    end
                end)
            end

            showSignalLost(best and best.DisplayName, os.clock() - startTime)
            explode(at)

            if best and impactMode == "Fling" then
    endFlight(false)
    task.spawn(function()
        local char2 = player.Character
        local root2 = char2 and char2:FindFirstChild("HumanoidRootPart")
        local targetRoot = best.Character and best.Character:FindFirstChild("HumanoidRootPart")
        if root2 and targetRoot then
            local savedCF = root2.CFrame
            for i = 1, 20 do
                if not targetRoot.Parent then break end
                root2.CFrame = targetRoot.CFrame * CFrame.new(0, 1, 0)
                root2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root2.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                targetRoot.AssemblyLinearVelocity = Vector3.new(0, 500, 0)
                targetRoot.AssemblyAngularVelocity = Vector3.new(500, 500, 500)
                RunService.Heartbeat:Wait()
            end
            task.wait(0.1)
            if root2.Parent then
                root2.CFrame = savedCF
                root2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end
    end)
else
    task.spawn(endFlight, true)
end
end
        local function abort()
            if done then return end
            done = true
            task.spawn(endFlight, false)
        end
-- ============================================================
-- МОБИЛЬНЫЙ UI (стик + кнопки)
-- ============================================================
if touchDevice then
    mobileRoot = create("Frame", {
        Name = "RockHubDroneMobile",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    
    -- ═══ СТИК (слева внизу) ═══
    local stickBase = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 24, 1, -28),
        Size = UDim2.fromOffset(136, 136),
        BackgroundColor3 = Color3.fromRGB(14, 14, 18),
        BackgroundTransparency = 0.28,
        Active = true,
        ZIndex = 20,
        Parent = mobileRoot,
    })
    makeRound(stickBase)
    create("UIStroke", { Color = accentColor, Thickness = 2, Transparency = 0.35, Parent = stickBase })
    
    local stickKnob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(54, 54),
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.08,
        ZIndex = 21,
        Parent = stickBase,
    })
    makeRound(stickKnob)
    
    local stickTouch
    local function resetStick()
        stickTouch = nil
        mobileInput.throttle, mobileInput.yaw = 0, 0
        stickKnob.Position = UDim2.fromScale(0.5, 0.5)
    end
    local function updateStick(input)
        local center = stickBase.AbsolutePosition + stickBase.AbsoluteSize / 2
        local delta = Vector2.new(input.Position.X, input.Position.Y) - center
        local radius = stickBase.AbsoluteSize.X * 0.36
        if delta.Magnitude > radius then
            delta = delta.Unit * radius
        end
        mobileInput.yaw = math.clamp(delta.X / radius, -1, 1)
        mobileInput.throttle = math.clamp(-delta.Y / radius, -1, 1)
        stickKnob.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
    end
    
    table.insert(conns, stickBase.InputBegan:Connect(function(input)
        if not stickTouch and input.UserInputType == Enum.UserInputType.Touch then
            stickTouch = input
            updateStick(input)
        end
    end))
    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if input == stickTouch then updateStick(input) end
    end))
    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input == stickTouch then resetStick() end
    end))
    
    -- ═══ ЗОНА ОБЗОРА (правая) ═══
    local lookPad = create("Frame", {
        Position = UDim2.fromScale(0.38, 0),
        Size = UDim2.new(0.62, 0, 1, -190),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 19,
        Parent = mobileRoot,
    })
    create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 0, 18),
        Size = UDim2.fromOffset(130, 22),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "DRAG TO AIM",
        TextSize = 12,
        TextColor3 = Color3.fromRGB(225, 225, 230),
        TextTransparency = 0.35,
        ZIndex = 20,
        Parent = lookPad,
    })
    local lookTouch
    table.insert(conns, lookPad.InputBegan:Connect(function(input)
        if not lookTouch and input.UserInputType == Enum.UserInputType.Touch then
            lookTouch = input
        end
    end))
    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if input == lookTouch then
            mobileInput.lookDelta = mobileInput.lookDelta + Vector2.new(input.Delta.X, input.Delta.Y)
        end
    end))
    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input == lookTouch then lookTouch = nil end
    end))
    
    -- ═══ КНОПКИ ═══
    local function controlButton(text, x, y, callback, holdKey)
        local button = create("TextButton", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, x, 1, y),
            Size = UDim2.fromOffset(82, 54),
            BackgroundColor3 = Color3.fromRGB(18, 18, 23),
            BackgroundTransparency = 0.16,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            Text = text,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(245, 245, 248),
            ZIndex = 22,
            Parent = mobileRoot,
        })
        addCorner(button, 12)
        create("UIStroke", {
            Color = text == "BOOM" and Color3.fromRGB(255, 75, 60) or accentColor,
            Thickness = 1.5,
            Transparency = 0.3,
            Parent = button,
        })
        if holdKey then
            local heldInput
            table.insert(conns, button.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    heldInput = input
                    mobileInput[holdKey] = true
                    button.BackgroundColor3 = accentColor
                end
            end))
            table.insert(conns, UserInputService.InputEnded:Connect(function(input)
                if input == heldInput then
                    heldInput = nil
                    mobileInput[holdKey] = false
                    button.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
                end
            end))
        else
            table.insert(conns, button.Activated:Connect(callback))
        end
    end
    
    controlButton("BOOST", -212, -92, nil, "boost")
    controlButton("UP",    -122, -92, nil, "up")
    controlButton("DOWN",  -32,  -92, nil, "down")
    controlButton("VIEW",  -212, -28, function() fpView = not fpView end)
    controlButton("BOOM",  -122, -28, function()
        if os.clock() - startTime > 0.5 then detonate(pos) end
    end)
    controlButton("EXIT",  -32,  -28, abort)
end
-- ⬆️ КОНЕЦ ВСТАВКИ
        -- Управление (ПК)
        table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if not gp and os.clock() - startTime > 0.5 then
                    detonate(pos)
                end
            elseif input.KeyCode == Enum.KeyCode.X then
                abort()
            elseif not gp then
                keysDown[input.KeyCode] = true
            end
        end))
        table.insert(conns, UserInputService.InputEnded:Connect(function(input)
            keysDown[input.KeyCode] = nil
        end))
        table.insert(conns, hum.Died:Connect(abort))

        local velocity = Vector3.zero

        -- Sweep-тест (пролёт через тонкое)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.IgnoreWater = true
        local ignoreList = { cam, char }
        rp.FilterDescendantsInstances = ignoreList

-- ⬆️ КОНЕЦ ВСТАВКИ
        local function moveDrone(move)
            for _ = 1, 3 do
                if move.Magnitude < 0.001 then return end
                local hit = workspace:Spherecast(pos, 1.4, move, rp)
                if not hit then
                    pos += move
                    return
                end
                local n = hit.Normal
                local travel = math.max(hit.Distance - 0.05, 0)
                pos += move.Unit * travel + n * 0.02
                move -= move.Unit * travel
                move -= n * move:Dot(n)
                velocity -= n * math.min(velocity:Dot(n), 0)
            end
        end

        -- Camera CF
        local camCf = cam.CFrame

        -- Главный цикл
        RunService:BindToRenderStep("RockHubDronePilot", Enum.RenderPriority.Last.Value + 5, function(dt)
            if done then return end
dt = math.min(dt, 0.05)
if not touchDevice then
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false
end
cam.CameraType = Enum.CameraType.Scriptable

-- Мобильный обзор + ПК мышь
local mouseDelta = touchDevice and mobileInput.lookDelta or UserInputService:GetMouseDelta()
mobileInput.lookDelta = Vector2.zero

local turn2 = 0
if keyDown(Enum.KeyCode.A) then turn2 += 1 end
if keyDown(Enum.KeyCode.D) then turn2 -= 1 end
turn2 -= mobileInput.yaw

local yawDelta = -mouseDelta.X * (touchDevice and 0.0045 or 0.0035) + turn2 * 1.8 * dt
turn += yawDelta
pitch = math.clamp(pitch - mouseDelta.Y * (touchDevice and 0.0045 or 0.0035), -1.45, 1.3)
local v = keyDown(Enum.KeyCode.V)
if v and not vWasDown then
    fpView = not fpView
end
vWasDown = v
            local rot = CFrame.Angles(0, turn, 0) * CFrame.Angles(pitch, 0, 0)
            local dir = rot.LookVector

            local speed = 0
if keyDown(Enum.KeyCode.W) then
    speed = isFpv and (keyDown(Enum.KeyCode.LeftShift) and 150 or 90)
        or (keyDown(Enum.KeyCode.LeftShift) and 110 or 60)
end
if keyDown(Enum.KeyCode.S) then
    speed = isFpv and -30 or -25
end
-- Мобильный стик
if touchDevice and math.abs(mobileInput.throttle) > 0.04 then
    if mobileInput.throttle > 0 then
        speed = mobileInput.throttle * (isFpv and (mobileInput.boost and 150 or 90) or (mobileInput.boost and 110 or 60))
    else
        speed = mobileInput.throttle * (isFpv and 30 or 25)
    end
end

            local vert = 0
local vel = isFpv and 40 or 28
if keyDown(Enum.KeyCode.Space) or mobileInput.up then vert += vel end
if keyDown(Enum.KeyCode.LeftControl) or keyDown(Enum.KeyCode.Q) or mobileInput.down then vert -= vel end

            velocity = velocity:Lerp(dir * speed + Vector3.yAxis * vert, math.min(dt * (isFpv and 4.5 or 3), 1))
            bank += (math.clamp(yawDelta / math.max(dt, 0.001) * 0.35, -0.9, 0.9) - bank) * math.min(dt * 5, 1)

            -- Проверка столкновения с игроками
            for _, e in ipairs(getTargets(false, pos, true)) do
                local th = alive(e.p)
                if th and (th.Position - pos).Magnitude < 6 then
                    detonate(th.Position)
                    return
                end
            end

            moveDrone(velocity * dt)

            -- Поворот дрона
            local cf = CFrame.new(pos) * rot
            local tilt = isFpv and -math.clamp(velocity:Dot(dir) / 150, -0.4, 1) * 0.45 or 0
            local visualCf = cf * CFrame.Angles(tilt, 0, bank * (isFpv and 1.2 or 1))
            drone:PivotTo(visualCf)

            -- Пропеллеры крутятся
            local spinAxis = isFpv and visualCf.UpVector or visualCf.LookVector
            for _, prop in ipairs(props) do
                prop.CFrame = CFrame.new(prop.Position)
                    * CFrame.fromAxisAngle(spinAxis, dt * 45)
                    * (prop.CFrame - prop.Position)
            end

            if engine and isFpv then
                engine.PlaybackSpeed = 0.9 + velocity.Magnitude / 170
            end

            -- Камера
            local camGoal = isFpv
                and cf * CFrame.new(0, 0.45, -0.9) * CFrame.Angles(0.1, 0, bank * 0.6)
                or cf * CFrame.new(0, 0.8, 3) * CFrame.Angles(-0.1, 0, bank * 0.5)
            camCf = camCf:Lerp(camGoal, math.min(dt * 12, 1))
            cam.CFrame = camCf
-- OSD обновление
if osdLabels then
    local elapsed = os.clock() - startTime
    local groundParams = RaycastParams.new()
    groundParams.FilterType = Enum.RaycastFilterType.Exclude
    groundParams.FilterDescendantsInstances = { cam, char }
    local g = workspace:Raycast(pos, Vector3.new(0, -400, 0), groundParams)
    osdLabels.bat.Text = ("BAT %.1fV"):format(16.8 - elapsed * 0.05)
    osdLabels.time.Text = ("%02d:%02d"):format(math.floor(elapsed / 60), math.floor(elapsed % 60))
    osdLabels.alt.Text = ("ALT %dm"):format(g and math.floor(g.Distance * 0.28) or 99)
    osdLabels.spd.Text = ("%d km/h"):format(math.floor(velocity.Magnitude * 0.28 * 3.6))
end
            -- HUD
local left = 45 - (os.clock() - startTime)
if touchDevice then
    hint.Text = ("stick - fly  ·  drag - aim  ·  buttons - actions  ·  %ds"):format(math.max(0, math.ceil(left)))
else
    hint.Text = ("mouse - aim  ·  W fly  ·  Shift fast  ·  S back  ·  Space/Ctrl up/down  ·  V view  ·  LMB boom  ·  X exit  ·  %ds"):format(math.max(0, math.ceil(left)))
end
            -- Автодетонация через 45 сек
            if left <= 0 then
                detonate(pos)
            end
        end)
    end

    local function launchDroneSafe()
        local ok, err = xpcall(launchDrone, debug.traceback)
        if ok then return end
        warn("[RockHub] Drone: " .. tostring(err))
        notify("Drone error", tostring(err):match("^[^\n]*"):sub(-110))
        droneBusy, droneLoading = false, false
        if desyncPaused then desyncPaused = false end
        pcall(function()
            RunService:UnbindFromRenderStep("RockHubDronePilot")
        end)
        for _, n in ipairs({ "RockHubDroneHud", "RockHubDroneCross", "RockHubSignalLost" }) do
            local g = gui:FindFirstChild(n)
            if g then g:Destroy() end
        end
        for _, d in ipairs(workspace.CurrentCamera:GetChildren()) do
            if d.Name == "RockHubDrone" then d:Destroy() end
        end
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        task.spawn(pcall, function()
            require(player.PlayerScripts.PlayerModule):GetControls():Enable()
        end)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") or d:IsA("Decal") then
                    d.LocalTransparencyModifier = 0
                end
            end
        end
        if hum and hum.WalkSpeed == 0 then
            hum.WalkSpeed, hum.JumpPower = 16, 50
        end
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Custom
        if hum then cam.CameraSubject = hum end
    end

    -- ============================================================
    -- UI
    -- ============================================================
    local s = addSection(droneTab, "Drone")

    s:Segmented("Type", { "Shahed", "FPV" }, droneKind, function(v)
        droneKind = v
        droneTemplate = droneCache[v]
    end)

    s:Segmented("Impact", { "Kill", "Fling" }, droneImpact, function(v)
        droneImpact = v
    end)

    s:Button("Launch Drone",
        "Kill needs the knife; Fling works for every role",
        function()
            task.spawn(launchDroneSafe)
        end)

    s:Button("Preload models",
        "download drone models in advance (slower first time)",
        function()
            task.spawn(function()
                notify("Drone", "loading Shahed...")
                loadDrone("Shahed")
                notify("Drone", "Shahed ready")
                notify("Drone", "loading FPV...")
                loadDrone("FPV")
                notify("Drone", "FPV ready")
            end)
        end)

    -- Unload
    table.insert(connections, {
        Disconnect = function()
            droneBusy = false
            pcall(function()
                RunService:UnbindFromRenderStep("RockHubDronePilot")
            end)
        end,
    })
end
end
setupDrone()
-- ============================================================
-- ESP с ролями
-- ============================================================
local esp = {
    on = false,
    roles = true,
    color = "White",
    dist = 1500,
    chams = true,
    box = true,
    boxStyle = "Corners",
    name = true,
    distance = true,
    health = true,
    tracers = false,
    tracerFrom = "Bottom",
    fill = 30,
    text = 12,
    thick = 1,
}

-- Отдельный ScreenGui — чтобы ESP не мешал основному меню
local espGui = create("ScreenGui", {
    Name = "SdwgESP",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = -2,
    Enabled = false,
})
local parented2 = false
if gethui then parented2 = pcall(function() espGui.Parent = gethui() end) end
if not parented2 then parented2 = pcall(function() espGui.Parent = game:GetService("CoreGui") end) end
if not parented2 then espGui.Parent = player:WaitForChild("PlayerGui") end

local chamsFolder = create("Folder", { Name = "Chams", Parent = espGui })
local black = Color3.new(0, 0, 0)
local red   = Color3.fromRGB(255, 58, 58)
local blue  = Color3.fromRGB(64, 150, 255)
local entries = {}

-- Роли через серверный ремоут (до выдачи оружия)
local serverRoles = {}
local aliveThread = true
task.spawn(function()
    local remote
    while aliveThread do
        if esp.on and esp.roles then
            if not remote or not remote.Parent then
                remote = game:GetService("ReplicatedStorage"):FindFirstChild("GetPlayerData", true)
            end
            if remote and remote:IsA("RemoteFunction") then
                local ok, data = pcall(remote.InvokeServer, remote)
                if ok and type(data) == "table" then
                    local newRoles = {}
                    for name, d in pairs(data) do
                        if type(d) == "table" and type(d.Role) == "string"
                            and not d.Dead and not d.Killed then
                            newRoles[name] = d.Role
                        end
                    end
                    serverRoles = newRoles
                end
            end
        end
        task.wait(1)
    end
end)

local function getRole(plr)
    if findTool(plr, "Knife") then return "Murderer" end
    if findTool(plr, "Gun") then return "Sheriff" end
    local r = serverRoles[plr.Name]
    if r == "Murderer" then return "Murderer" end
    if r == "Sheriff" or r == "Hero" then return "Sheriff" end
end

-- Вспомогательные функции для рисования
local function newLine(parent)
    local f = create("Frame", {
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = parent,
    })
    create("UIStroke", { Color = black, Transparency = 0.5, Thickness = 1, Parent = f })
    return f
end

local function label(parent, anchorY)
    return create("TextLabel", {
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = accentColor,
        TextStrokeColor3 = black,
        TextStrokeTransparency = 0.45,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, anchorY),
        Size = UDim2.fromOffset(220, 14),
        Parent = parent,
    })
end

-- Создаём все элементы для игрока
local function addEntry(plr)
    if plr == player or entries[plr] then return end
    local e = { plr = plr, alpha = 0, hp = 1, hue = math.random() }

    e.root = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        Visible = false,
        Parent = espGui,
    })

    -- Box (Full) — задний фон
    e.fill = create("Frame", {
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = e.root,
    })
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new(1, 0.82),
        Parent = e.fill,
    })

    -- Уголки (8 линий для Corners)
    e.corners = {}
    for i = 1, 8 do
        e.corners[i] = newLine(e.root)
    end

    -- Full box
    e.full = create("Frame", { BackgroundTransparency = 1, Parent = e.root })
    e.fullStroke = create("UIStroke", { Color = accentColor, Thickness = 1, Parent = e.full })
    e.fullShadow = create("Frame", { BackgroundTransparency = 1, Parent = e.root })
    create("UIStroke", { Color = black, Transparency = 0.5, Thickness = 3, Parent = e.fullShadow })

    e.name = label(e.root, 1)
    e.info = label(e.root, 0)
    e.info.Font = Enum.Font.GothamMedium

    -- HP bar
    e.hpBg = create("Frame", {
        BackgroundColor3 = black,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = e.root,
    })
    e.hpFill = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 1, 1, -1),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = e.hpBg,
    })

    -- Tracer
    e.tracer = newLine(e.root)
    e.tracer.AnchorPoint = Vector2.new(0.5, 0.5)

    -- Highlight (Chams)
    e.hl = create("Highlight", {
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Enabled = false,
        Parent = chamsFolder,
    })

    entries[plr] = e
end

local function removeEntry(plr)
    local e = entries[plr]
    if not e then return end
    e.root:Destroy()
    e.hl:Destroy()
    entries[plr] = nil
end

for _, plr in ipairs(Players:GetPlayers()) do addEntry(plr) end
connect(Players.PlayerAdded, addEntry)
connect(Players.PlayerRemoving, removeEntry)

-- Утилита — рисование линии между двумя точками
local function placeLine(f, x1, y1, x2, y2, th)
    local dx, dy = x2 - x1, y2 - y1
    f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
    f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), th)
    f.Rotation = math.deg(math.atan2(dy, dx))
end

-- Цвет HP (градиент зелёный → жёлтый → красный)
local function hpColor(r)
    return Color3.fromHSV(0.33 * math.clamp(r, 0, 1), 0.8, 1)
end

local function hideAll()
    for _, e in pairs(entries) do
        e.alpha = 0
        e.root.Visible = false
        e.hl.Enabled = false
    end
end

-- ═══════════════════════════════════════════════════════════
--  ГЛАВНЫЙ РЕНДЕР ESP
-- ═══════════════════════════════════════════════════════════
connect(RunService.RenderStepped, function(dt)
    if not esp.on then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local viewport = cam.ViewportSize
    local camPos = cam.CFrame.Position
    local now = os.clock()
    local k = math.min(dt * 10, 1)

    for plr, e in pairs(entries) do
        local char = plr.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        local render = false
        local dist = 0

        if hrp and hum and hum.Health > 0 then
            dist = (camPos - hrp.Position).Magnitude
            if dist <= esp.dist then
                local top    = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                local bottom = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.4, 0))
                if top.Z > 0 and bottom.Z > 0 then
                    local h = math.max(bottom.Y - top.Y, 6)
                    local w = h * 0.6
                    local relX = (top.X + bottom.X) / 2
                    -- Проверка: находится ли цель в кадре
                    render = relX > -w
                        and relX < viewport.X + w
                        and bottom.Y > 0
                        and top.Y < viewport.Y
                    if render then
                        e.x, e.y, e.w, e.h, e.d = relX, top.Y, w, h, dist
                    end
                end
            end
        end

        -- Плавное появление / исчезновение
        e.alpha = e.alpha + ((render and 1 or 0) - e.alpha) * k
        if e.alpha < 0.02 or not e.x then
            e.root.Visible = false
            e.hl.Enabled = false
            continue
        end

        e.root.Visible = true
        local a = e.alpha
        local fade = 1 - a

        -- HP сглаживание
        local hpFrac = hum and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 0
        e.hp = e.hp + (hpFrac - e.hp) * math.min(dt * 8, 1)

        -- Пересчёт роли раз в 0.25 сек
        if not e.roleAt or now - e.roleAt > 0.25 then
            e.roleAt = now
            local role = esp.roles and getRole(plr) or nil
            if role and role ~= e.role then
                notify(role == "Murderer" and "Murderer found" or "Sheriff found", plr.DisplayName)
            end
            e.role = role
        end

        -- Цвет
        local col = accentColor
        if e.role == "Murderer" then
            col = red
        elseif e.role == "Sheriff" then
            col = blue
        elseif esp.color == "Health" then
            col = hpColor(e.hp)
        elseif esp.color == "Rainbow" then
            col = Color3.fromHSV((now * 0.15 + e.hue) % 1, 0.55, 1)
        end

        -- Границы бокса
        local x0, y0 = e.x - e.w / 2, e.y
        local x1, y1 = e.x + e.w / 2, e.y + e.h
        local th = esp.thick

        -- ЗАЛИВКА (для Full стиля — полупрозрачный фон)
        e.fill.Visible = esp.box
        e.fill.Position = UDim2.fromOffset(x0, y0)
        e.fill.Size = UDim2.fromOffset(e.w, e.h)
        e.fill.BackgroundColor3 = col
        e.fill.BackgroundTransparency = fade

        -- УГОЛКИ
        local corners = esp.box and esp.boxStyle == "Corners"
        local cw, ch = math.max(e.w * 0.28, 4), math.max(e.h * 0.2, 4)
        local rects = {
            { x0, y0, cw, th },              -- верх-лево горизонт
            { x0, y0, th, ch },              -- верх-лево вертикаль
            { x1 - cw, y0, cw, th },         -- верх-право горизонт
            { x1 - th, y0, th, ch },         -- верх-право вертикаль
            { x0, y1 - th, cw, th },         -- низ-лево горизонт
            { x0, y1 - ch, th, ch },         -- низ-лево вертикаль
            { x1 - cw, y1 - th, cw, th },    -- низ-право горизонт
            { x1 - th, y1 - ch, th, ch },    -- низ-право вертикаль
        }
        for i, c in ipairs(e.corners) do
            c.Visible = corners
            if corners then
                local q = rects[i]
                c.Position = UDim2.fromOffset(q[1], q[2])
                c.Size = UDim2.fromOffset(q[3], q[4])
                c.BackgroundColor3 = col
                c.BackgroundTransparency = fade
            end
        end

        -- FULL BOX
        local full = esp.box and esp.boxStyle == "Full"
        e.full.Visible = full
        e.fullShadow.Visible = full
        if full then
            e.full.Position = UDim2.fromOffset(x0, y0)
            e.full.Size = UDim2.fromOffset(e.w, e.h)
            e.fullShadow.Position = e.full.Position
            e.fullShadow.Size = e.full.Size
            e.fullStroke.Color = col
            e.fullStroke.Thickness = th
            e.fullStroke.Transparency = fade
        end

        -- ИМЯ
        e.name.Visible = esp.name
        if esp.name then
            e.name.Text = plr.DisplayName
            e.name.TextSize = esp.text
            e.name.Position = UDim2.fromOffset(e.x, y0 - 3)
            e.name.TextColor3 = col
            e.name.TextTransparency = fade
            e.name.TextStrokeTransparency = 0.45 + 0.55 * fade
        end

        -- ИНФО (роль + дистанция)
        e.info.Visible = esp.distance
        if esp.distance then
            local m = math.floor(e.d + 0.5) .. "m"
            e.info.Text = e.role
                and (string.upper(e.role) .. "  ·  " .. m)
                or m
            e.info.TextSize = esp.text - 1
            e.info.Position = UDim2.fromOffset(e.x, y1 + 3)
            e.info.TextColor3 = e.role and col or dimColor:Lerp(accentColor, 0.5)
            e.info.TextTransparency = fade
            e.info.TextStrokeTransparency = 0.45 + 0.55 * fade
        end

        -- HP BAR
        e.hpBg.Visible = esp.health
        if esp.health then
            e.hpBg.Position = UDim2.fromOffset(x0 - 6, y0 - 1)
            e.hpBg.Size = UDim2.fromOffset(4, e.h + 2)
            e.hpBg.BackgroundTransparency = 0.35 + 0.65 * fade
            e.hpFill.Size = UDim2.new(0, 2, math.clamp(e.hp, 0, 1), -2)
            e.hpFill.BackgroundColor3 = hpColor(e.hp)
            e.hpFill.BackgroundTransparency = fade
        end

        -- TRACERS (аккуратно — от низа/центра экрана к цели)
        e.tracer.Visible = esp.tracers
        if esp.tracers then
            local startX, startY
            if esp.tracerFrom == "Center" then
                startX = viewport.X / 2
                startY = viewport.Y / 2
            else
                -- "Bottom" — низ экрана, чуть выше safe-area
                startX = viewport.X / 2
                startY = viewport.Y - 2
            end
            -- Линия идёт от стартовой точки к НИЗУ бокса (y1),
            -- чтобы визуально "прицепиться" к ногам цели
            placeLine(e.tracer, startX, startY, e.x, y1, th)
            e.tracer.BackgroundColor3 = col
            e.tracer.BackgroundTransparency = 0.25 + 0.75 * fade
        end

        -- CHAMS (Highlight)
        e.hl.Enabled = esp.chams
        if esp.chams then
            e.hl.Adornee = char
            e.hl.FillColor = col
            e.hl.OutlineColor = col
            e.hl.FillTransparency = 1 - esp.fill / 100 * 0.85 * a
            e.hl.OutlineTransparency = 1 - 0.9 * a
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
--  UI-СЕКЦИЯ
-- ═══════════════════════════════════════════════════════════
local espSec = addSection(visualsTab, "ESP", "ESP")

espSec:Toggle("Enable", "see players through walls", function(on)
    esp.on = on
    espGui.Enabled = on
    if not on then hideAll() end
    notify("ESP: " .. (on and "On" or "Off"),
        on and "players highlighted" or "esp hidden")
end)

local roleToggle = espSec:Toggle("Roles",
    "murderer red, sheriff blue (works before weapons are given)",
    function(v)
        esp.roles = v
        for _, e in pairs(entries) do e.roleAt = nil end
    end)
roleToggle.Set(true, true)

espSec:Select("Color", "for everyone else",
    { "White", "Health", "Rainbow" },
    "White",
    function(v) esp.color = v end)

espSec:Slider("Max distance", 50, 3000, 1500,
    function(v) esp.dist = v end,
    function(v) return v .. "m" end)

local parts = addSection(visualsTab, "Elements", "ESP")

local chamsT = parts:Toggle("Chams", "glowing body through walls", function(v) esp.chams = v end)
chamsT.Set(true, true)

local boxT = parts:Toggle("Box", nil, function(v) esp.box = v end)
boxT.Set(true, true)

parts:Segmented("Box style", { "Corners", "Full" }, "Corners",
    function(v) esp.boxStyle = v end)

local nameT = parts:Toggle("Name", nil, function(v) esp.name = v end)
nameT.Set(true, true)

local distT = parts:Toggle("Distance", nil, function(v) esp.distance = v end)
distT.Set(true, true)

local hpT = parts:Toggle("Health bar", nil, function(v) esp.health = v end)
hpT.Set(true, true)

parts:Toggle("Tracers", "lines from screen edge to players", function(v) esp.tracers = v end)
parts:Segmented("Tracers from", { "Bottom", "Center" }, "Bottom",
    function(v) esp.tracerFrom = v end)

local look = addSection(visualsTab, "Look", "ESP")

look:Slider("Chams fill", 0, 100, 30,
    function(v) esp.fill = v end,
    function(v) return v .. "%" end)

look:Slider("Text size", 9, 18, 12,
    function(v) esp.text = v end)

look:Slider("Thickness", 1, 3, 1,
    function(v) esp.thick = v end,
    function(v) return v .. "px" end)

-- Unload
table.insert(connections, {
    Disconnect = function()
        aliveThread = false
        esp.on = false
        espGui:Destroy()
    end,
})

-- -------- SERVER --------
do
    -- ============================================================
    -- COIN AUTO-FARM (Safe & Steady)
    -- ============================================================
    local coinFarm = {
        on = false,
        delay = 1.0,       -- пауза между полетами (1 секунда - безопасно)
        flySpeed = 20,     -- скорость (20 стадов/сек - как бег)
    }
    local farmingCoin = false
    local lastFarmTime = 0

    local function isCoin(inst)
        local name = inst.Name:lower()
        return name == "coin_server" or name == "coinvisual" or name == "coin"
    end

    local function canFarm()
        if not coinFarm.on or farmingCoin then return false end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        -- Проверка: жив и на карте
        if not hrp or not hum or hum.Health <= 0 then return false end
        if inLobby(hrp.Position) then return false end
        
        -- Проверка: есть роль (не призрак)
        if not findTool(player, "Knife") and not findTool(player, "Gun") then return false end
        
        -- Кулдаун
        if tick() - lastFarmTime < coinFarm.delay then return false end
        return true
    end

    local function flyTo(targetPart)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not targetPart then return end

        local distance = (targetPart.Position - hrp.Position).Magnitude
        -- Время = дистанция / скорость (минимум 0.3 сек, чтобы не банило)
        local duration = math.clamp(distance / coinFarm.flySpeed, 0.3, 3)

        -- Отключаем коллизии (Noclip)
        local savedCollide = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                savedCollide[p] = p.CanCollide
                p.CanCollide = false
            end
        end

        -- Плавный полет
        local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            CFrame = targetPart.CFrame
        })
        tween:Play()
        tween.Completed:Wait()

        -- Возвращаем коллизии
        for p, coll in pairs(savedCollide) do
            if p and p.Parent then
                p.CanCollide = coll
            end
        end

        task.wait(0.2) -- Ждем, пока сервер засчитает сбор монеты
    end

    -- Черный список монет (чтобы не ждать, пока они исчезнут)
local ignoredCoins = {}

local function tryCollect()
    if not canFarm() then return end
    
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Очищаем старые монеты из черного списка (прошло больше 2 сек)
    local now = tick()
    for coin, time in pairs(ignoredCoins) do
        if now - time > 2 then
            ignoredCoins[coin] = nil
        end
    end

    -- Ищем ближайшую монету (игнорируя черный список)
    local closestCoin = nil
    local closestDist = 500
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("BasePart") and isCoin(inst) and not ignoredCoins[inst] then
            local dist = (inst.Position - hrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestCoin = inst
            end
        end
    end

    if closestCoin then
        farmingCoin = true
        lastFarmTime = tick()
        
        -- СРАЗУ заносим в черный список (чтобы не лететь к ней снова)
        ignoredCoins[closestCoin] = tick()
        
        flyTo(closestCoin)
        
        farmingCoin = false
    end
end

    -- Главный цикл
    task.spawn(function()
        while true do
            task.wait(0.5) -- Проверяем каждые 0.5 сек
            if coinFarm.on then
                tryCollect()
            end
        end
    end)

    -- UI
    local farmSec = addSection(serverTab, "Auto Farm")
    farmSec:Toggle("Coin Farm", "smooth fly to coins (no kick)", function(on)
        coinFarm.on = on
        notify("Coin Farm: " .. (on and "On" or "Off"), on and "farming..." or "disabled")
    end)
    
    farmSec:Slider("Farm Delay", 0.5, 3, 1.0, function(v)
        coinFarm.delay = v
    end, function(v) return string.format("%.1fs", v) end)
    
    farmSec:Slider("Fly Speed", 5, 50, 20, function(v)
        coinFarm.flySpeed = v
    end, function(v) return v .. " studs/s" end)

    -- ============================================================
    -- ACTIONS
    -- ============================================================
    local s = addSection(serverTab, "Actions")
    s:Button("Rejoin", "same server again", function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end)
    s:Button("Server Hop", "random other server", function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100"):format(game.PlaceId)
        local ok, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if not ok or type(res) ~= "table" or type(res.data) ~= "table" then
            return
        end
        local list = {}
        for _, sv in ipairs(res.data) do
            if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                table.insert(list, sv)
            end
        end
        if #list == 0 then return end
        local pick = list[math.random(#list)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, player)
    end)
    s:Button("Copy Job ID", "put the job id into clipboard", function()
        if setclipboard then setclipboard(game.JobId) end
    end)
end
-- -------- SETTINGS --------
do
    local s = addSection(settingsTab, "Interface")
    s:Keybind("Menu key", "click and press any key",
        function() return toggleKey end,
        function(k) toggleKey = k end)
    s:Slider("Background blur", 0, 40, blurSize, function(v)
        blurSize = v
        if menuOpen then blur.Size = v end
    end)
    s:Button("Unload", "remove the menu and reset all", function()
        if _G.SdwgXyzUnload then _G.SdwgXyzUnload() end
    end)
end
-- ============================================================
-- WORLDSPACE (Beta) — сканер workspace
-- ============================================================
worldTab.custom = true

do
    for _, c in ipairs(worldTab.page:GetChildren()) do
        if c:IsA("TextLabel") then c.Visible = false end
    end
    worldTab.page.ScrollingEnabled = false
    worldTab.page.ScrollBarThickness = 0
    worldTab.page.CanvasSize = UDim2.new()

    local page = worldTab.page

    -- Настройки
    local ws = {
        watching = false,          -- записываем ли временные
        lifetimeCap = 40,          -- максимальное время жизни (сек)
        lifetimeMin = 0.1,         -- минимальное (фильтр)
        treeExpand = {},           -- какие папки раскрыты
        logs = {},                 -- лог временных объектов
        maxLogs = 200,             -- сколько хранить
        watched = {},              -- какие объекты сейчас отслеживаем
    }

    -- ============================================================
    -- ВЕРХНЯЯ ПАНЕЛЬ — поиск, фильтр, кнопки
    -- ============================================================
    local topBar = create("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = panelColor,
        Parent = page,
    })
    addCorner(topBar, 8)

    -- Поиск
    local searchBox = create("TextBox", {
        Text = "",
        PlaceholderText = "Search by name...",
        PlaceholderColor3 = mutedColor,
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = textColor, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(0.4, 0, 1, 0),
        Parent = topBar,
    })

    -- Кнопка Watch (запись временных)
    local watchBtn = create("TextButton", {
        Text = "● Watch off",
        Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = dimColor,
        BackgroundColor3 = elemColor,
        AutoButtonColor = false,
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.fromOffset(110, 20),
        Parent = topBar,
    })
    addCorner(watchBtn, 6)
    addStroke(watchBtn)

    -- Кнопка Refresh
    local refreshBtn = create("TextButton", {
        Text = "Refresh tree",
        Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = textColor,
        BackgroundColor3 = elemColor,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(100, 20),
        Parent = topBar,
    })
    addCorner(refreshBtn, 6)
    addStroke(refreshBtn)

    -- Кнопка Clear logs
    local clearBtn = create("TextButton", {
        Text = "Clear logs",
        Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = textColor,
        BackgroundColor3 = elemColor,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(90, 20),
        Parent = topBar,
    })
    addCorner(clearBtn, 6)
    addStroke(clearBtn)

    -- Верхняя панель — layout
    local topLayout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = topBar,
    })
    create("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = topBar })

    -- Порядок
    searchBox.LayoutOrder = 1
    watchBtn.LayoutOrder = 2
    refreshBtn.LayoutOrder = 3
    clearBtn.LayoutOrder = 4

    -- ============================================================
    -- ДВЕ КОЛОНКИ: TREE (слева) + LOG (справа)
    -- ============================================================
    local columns = create("Frame", {
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 1, -42),
        BackgroundTransparency = 1,
        Parent = page,
    })

    -- TREE (слева)
    local treeFrame = create("Frame", {
        Size = UDim2.new(0.55, -4, 1, 0),
        BackgroundColor3 = panelColor,
        Parent = columns,
    })
    addCorner(treeFrame, 8)

    local treeHeader = create("TextLabel", {
        Text = "WORKSPACE TREE",
        Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = dimColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -24, 0, 14),
        Parent = treeFrame,
    })

    local treeScroll = create("ScrollingFrame", {
        Position = UDim2.fromOffset(6, 24),
        Size = UDim2.new(1, -12, 1, -30),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = dimColor,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(), Parent = treeFrame,
    })
    local treeLayout = create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = treeScroll,
    })

    -- LOG (справа)
    local logFrame = create("Frame", {
        Position = UDim2.new(0.55, 4, 0, 0),
        Size = UDim2.new(0.45, -4, 1, 0),
        BackgroundColor3 = panelColor,
        Parent = columns,
    })
    addCorner(logFrame, 8)

    local logHeader = create("TextLabel", {
        Text = "SHORT-LIVED OBJECTS",
        Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = dimColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -24, 0, 14),
        Parent = logFrame,
    })

    local logScroll = create("ScrollingFrame", {
        Position = UDim2.fromOffset(6, 24),
        Size = UDim2.new(1, -12, 1, -30),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = dimColor,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(), Parent = logFrame,
    })
    local logLayout = create("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = logScroll,
    })

    -- ============================================================
    -- TREE — построение иерархии
    -- ============================================================
    local treeSearch = ""

    local function isMatch(inst, search)
        if search == "" then return true end
        return inst.Name:lower():find(search, 1, true) ~= nil
    end

    local function addTreeRow(parentFrame, inst, depth)
        local row = create("TextButton", {
            Text = "",
            BackgroundColor3 = elemColor,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 20),
            Parent = parentFrame,
        })
        addCorner(row, 4)
        row.LayoutOrder = #parentFrame:GetChildren()

        -- Отступ по глубине
        local indent = depth * 12

        -- Кнопка раскрытия (если есть дети)
        local hasChildren = #inst:GetChildren() > 0
        local expanded = ws.treeExpand[inst]

        -- Иконка/стрелка
        local arrow = create("TextLabel", {
            Text = hasChildren and (expanded and "▼" or "▶") or "•",
            Font = Enum.Font.GothamBold, TextSize = 10,
            TextColor3 = hasChildren and textColor or dimColor,
            TextXAlignment = Enum.TextXAlignment.Center,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(4 + indent, 0),
            Size = UDim2.fromOffset(12, 20),
            Parent = row,
        })

        -- Название
        local nameColor = dimColor
        if inst:IsA("BasePart") then nameColor = Color3.fromRGB(140, 200, 255) end
        if inst:IsA("Model") then nameColor = Color3.fromRGB(255, 200, 140) end
        if inst:IsA("Tool") then nameColor = Color3.fromRGB(255, 140, 140) end
        if inst:IsA("Script") or inst:IsA("LocalScript") then nameColor = Color3.fromRGB(180, 255, 180) end
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then nameColor = Color3.fromRGB(255, 100, 100) end
        if inst:IsA("Folder") then nameColor = Color3.fromRGB(255, 255, 140) end
        if inst:IsA("Part") and inst.Name == "GunDrop" then nameColor = Color3.fromRGB(255, 150, 50) end

        create("TextLabel", {
            Text = inst.Name,
            Font = Enum.Font.Gotham, TextSize = 11,
            TextColor3 = nameColor,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(20 + indent, 0),
            Size = UDim2.new(1, -26 - indent, 1, 0),
            Parent = row,
        })

        -- Класс справа
        create("TextLabel", {
            Text = inst.ClassName,
            Font = Enum.Font.Gotham, TextSize = 9,
            TextColor3 = mutedColor,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.fromOffset(80, 14),
            Parent = row,
        })

        -- Клик по строке — раскрыть/свернуть
        if hasChildren then
            connect(row.MouseButton1Click, function()
                ws.treeExpand[inst] = not ws.treeExpand[inst]
                refreshTree()
            end)
        end

        -- Подсветка hover
        connect(row.MouseEnter, function()
            tween(row, 0.1, { BackgroundColor3 = hoverColor })
        end)
        connect(row.MouseLeave, function()
            tween(row, 0.1, { BackgroundColor3 = elemColor })
        end)

        -- Если раскрыто — добавляем детей
        if hasChildren and expanded then
            for _, child in ipairs(inst:GetChildren()) do
                if isMatch(child, treeSearch) or hasMatchInTree(child, treeSearch) then
                    addTreeRow(parentFrame, child, depth + 1)
                end
            end
        end
    end

    function hasMatchInTree(inst, search)
        if search == "" then return true end
        if isMatch(inst, search) then return true end
        for _, child in ipairs(inst:GetChildren()) do
            if hasMatchInTree(child, search) then return true end
        end
        return false
    end

    function refreshTree()
        for _, c in ipairs(treeScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
                c:Destroy()
            end
        end

        for _, inst in ipairs(workspace:GetChildren()) do
            if isMatch(inst, treeSearch) or hasMatchInTree(inst, treeSearch) then
                addTreeRow(treeScroll, inst, 0)
            end
        end

        task.defer(function()
            treeScroll.CanvasSize = UDim2.fromOffset(0, treeLayout.AbsoluteContentSize.Y + 8)
        end)
    end

    -- ============================================================
    -- LOG — запись временных объектов
    -- ============================================================
    local function clearLogs()
        for _, c in ipairs(logScroll:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end
        ws.logs = {}
        ws.watched = {}
    end

    local function addLogEntry(entry)
        table.insert(ws.logs, 1, entry)
        while #ws.logs > ws.maxLogs do
            table.remove(ws.logs)
        end
        -- Удалить старые строки
        while #logScroll:GetChildren() > ws.maxLogs + 1 do
            for _, c in ipairs(logScroll:GetChildren()) do
                if not c:IsA("UIListLayout") and #logScroll:GetChildren() > ws.maxLogs + 1 then
                    c:Destroy()
                    break
                end
            end
        end

        local row = create("TextButton", {
            Text = "",
            BackgroundColor3 = elemColor,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 28),
            Parent = logScroll,
        })
        addCorner(row, 4)
        row.LayoutOrder = -#ws.logs  -- новые сверху

        local color = Color3.fromRGB(255, 200, 100)
        if entry.ClassName == "Model" then color = Color3.fromRGB(255, 140, 140) end
        if entry.ClassName:find("Part") then color = Color3.fromRGB(140, 200, 255) end

        create("TextLabel", {
            Text = entry.Name,
            Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = color,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(6, 2),
            Size = UDim2.new(1, -80, 0, 14),
            Parent = row,
        })

        create("TextLabel", {
            Text = entry.ClassName .. "  ·  lived " .. string.format("%.1fs", entry.lifetime),
            Font = Enum.Font.Gotham, TextSize = 9,
            TextColor3 = dimColor,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(6, 15),
            Size = UDim2.new(1, -12, 0, 12),
            Parent = row,
        })

        task.defer(function()
            logScroll.CanvasSize = UDim2.fromOffset(0, logLayout.AbsoluteContentSize.Y + 8)
        end)
    end

    -- ============================================================
    -- WATCHER — отслеживание временных объектов
    -- ============================================================
    connect(workspace.DescendantAdded, function(inst)
        if not ws.watching then return end
        -- Только верхний уровень — не считаем всё подряд
        if not (inst:IsA("BasePart") or inst:IsA("Model") or inst:IsA("Tool")
            or inst:IsA("Folder")) then return end
        -- Пропускаем персонажей
        if inst.Parent and Players:GetPlayerFromCharacter(inst.Parent) then return end

        ws.watched[inst] = os.clock()
    end)

    connect(RunService.Heartbeat, function()
        if not ws.watching then return end
        local now = os.clock()
        for inst, addedAt in pairs(ws.watched) do
            if not inst.Parent then
                -- Объект исчез — записываем лог
                local lifetime = now - addedAt
                if lifetime >= ws.lifetimeMin and lifetime <= ws.lifetimeCap then
                    addLogEntry({
                        Name = inst.Name,
                        ClassName = inst.ClassName,
                        lifetime = lifetime,
                        addedAt = addedAt,
                    })
                end
                ws.watched[inst] = nil
            elseif now - addedAt > ws.lifetimeCap then
                -- Живёт слишком долго — удаляем из отслеживания
                ws.watched[inst] = nil
            end
        end
    end)

    -- ============================================================
    -- КНОПКИ
    -- ============================================================
    connect(watchBtn.MouseButton1Click, function()
        ws.watching = not ws.watching
        watchBtn.Text = ws.watching and "● Watch on" or "● Watch off"
        watchBtn.TextColor3 = ws.watching and Color3.fromRGB(120, 255, 120) or dimColor
        tween(watchBtn, 0.15, { BackgroundColor3 = ws.watching and hoverColor or elemColor })
    end)

    connect(refreshBtn.MouseButton1Click, function()
        refreshTree()
    end)

    connect(clearBtn.MouseButton1Click, function()
        clearLogs()
    end)

    connect(searchBox:GetPropertyChangedSignal("Text"), function()
        treeSearch = searchBox.Text:lower()
        refreshTree()
    end)

        -- Периодическое обновление дерева (каждые 3 сек, только если вкладка открыта)
    task.spawn(function()
        while gui.Parent do
            if currentTab == worldTab and not ws.watching then
                refreshTree()
            end
            task.wait(3)
        end
    end)
end

-- ============================================================
-- KEY SYSTEM GATE
-- ============================================================
local keyPassed = false
local BYPASS_KEY = "SdwgAdmin2026" -- <--- Твой секретный мастер-ключ

local function showKeyUI()
    -- Создаем отдельный интерфейс
    local keyUI = Instance.new("ScreenGui")
    keyUI.Name = "SdwgKeyGate"
    keyUI.ResetOnSpawn = false
    keyUI.DisplayOrder = 999
    pcall(function() keyUI.Parent = gethui and gethui() or game:GetService("CoreGui") end)

    -- Темный фон
    local bg = Instance.new("Frame", keyUI)
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.new(0, 0, 0)
    bg.BackgroundTransparency = 0.3
    bg.BorderSizePixel = 0

    -- Окно
    local box = Instance.new("Frame", keyUI)
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.fromOffset(400, 250)
    box.BackgroundColor3 = bgColor
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
    
    local stroke = Instance.new("UIStroke", box)
    stroke.Color = accentColor
    stroke.Transparency = 0.3

    -- Заголовок
    local title = Instance.new("TextLabel", box)
    title.Text = "Sdwg.xyz"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 22
    title.TextColor3 = accentColor
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(20, 16)
    title.Size = UDim2.new(1, -40, 0, 28)
    title.TextXAlignment = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", box)
    sub.Text = "enter your license key"
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.TextColor3 = dimColor
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.fromOffset(20, 44)
    sub.Size = UDim2.new(1, -40, 0, 16)
    sub.TextXAlignment = Enum.TextXAlignment.Left

    -- Поле ввода
    local input = Instance.new("TextBox", box)
    input.Text = ""
    input.PlaceholderText = "SDWG-XXXX-XXXX-XXXX"
    input.PlaceholderColor3 = mutedColor
    input.Font = Enum.Font.Code
    input.TextSize = 15
    input.TextColor3 = accentColor
    input.BackgroundColor3 = elemColor
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.ClearTextOnFocus = false
    input.Position = UDim2.fromOffset(20, 72)
    input.Size = UDim2.new(1, -40, 0, 42)
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", input)
    pad.PaddingLeft = UDim.new(0, 12)

    -- Статус
    local status = Instance.new("TextLabel", box)
    status.Text = ""
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextColor3 = Color3.fromRGB(255, 90, 90)
    status.BackgroundTransparency = 1
    status.Position = UDim2.fromOffset(20, 120)
    status.Size = UDim2.new(1, -40, 0, 16)
    status.TextXAlignment = Enum.TextXAlignment.Left

    -- Кнопка Активации (СДЕЛАНА ЧЕРЕЗ INSTANCE.NEW ДЛЯ НАДЕЖНОСТИ)
    local submit = Instance.new("TextButton", box)
    submit.Text = "ACTIVATE"
    submit.Font = Enum.Font.GothamBold
    submit.TextSize = 13
    submit.TextColor3 = bgColor
    submit.BackgroundColor3 = accentColor
    submit.AutoButtonColor = false
    submit.Position = UDim2.fromOffset(20, 160)
    submit.Size = UDim2.new(1, -40, 0, 40)
    Instance.new("UICorner", submit).CornerRadius = UDim.new(0, 8)

    local attempts = 5

    -- Обработка клика
    submit.MouseButton1Click:Connect(function()
    local key = input.Text:upper():gsub("%s+", "")
    if key == "" then 
        status.Text = "Enter a key"
        return 
    end
    
    status.Text = "Checking..."
    status.TextColor3 = textColor
    
    -- Просто ждем полсекунды для визуала (без task.spawn!)
    task.wait(0.5) 
    
    local ok, info = validateKey(key)
    if ok then
        status.Text = "✓ Key accepted"
        status.TextColor3 = Color3.fromRGB(110, 230, 140)
        saveKeyToFile(key)
        task.wait(0.5)
        keyUI:Destroy()
        keyPassed = true
    else
        status.Text = "Error: " .. tostring(info)
        status.TextColor3 = Color3.fromRGB(255, 90, 90)
    end
end)

    input.FocusLost:Connect(function(enter)
        if enter then 
            submit.MouseButton1Click:Fire() 
        end
    end)
end

-- Запуск проверки
task.spawn(function()
    local saved = loadKeyFromFile()
    if saved then
        local ok = validateKey(saved)
        if ok then 
            keyPassed = true
            return 
        else 
            deleteKeyFile() 
        end
    end
    showKeyUI()
    while not keyPassed do task.wait(0.1) end
end)

task.spawn(function()
    while not keyPassed do task.wait(0.1) end
    selectTab(mainTab) 
end)

-- ============================================================
-- 8. ВОТЕРМАРКА-КАПСУЛА
-- ============================================================
local wmHolder = create("Frame", {
    Name = "WatermarkHolder", BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 62), Size = UDim2.fromOffset(320, 36), Parent = gui,
})
local watermark = create("TextButton", {
    Name = "Watermark", Text = "", AutoButtonColor = false,
    AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = bgColor,
    BackgroundTransparency = 0.04, Size = UDim2.fromOffset(0, 36), Parent = wmHolder,
})
addCorner(watermark, 10)
local wmScale = create("UIScale", { Scale = 1, Parent = watermark })
local wmStroke = create("UIStroke", {
    Color = accentColor, Thickness = 1, Transparency = 0.5,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = watermark,
})
addGradient(wmStroke)
create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = watermark })
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 9), Parent = watermark,
})

local wmOrder = 0
local function wmItem(cls, props)
    wmOrder += 1
    props.LayoutOrder = wmOrder
    if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
    props.BorderSizePixel = 0
    props.ZIndex = props.ZIndex or 51
    props.Parent = props.Parent or watermark
    return create(cls, props)
end
local function wmDivider()
    return wmItem("Frame", { Size = UDim2.fromOffset(1, 14), BackgroundTransparency = 0, BackgroundColor3 = strokeColor })
end
local function wmLabel(width)
    return wmItem("TextLabel", {
        Text = "", RichText = true, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextColor3 = textColor, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromOffset(width, 36),
    })
end
local logoWm = wmItem("Frame", {
    Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0,
    BackgroundColor3 = accentColor, ClipsDescendants = true,
})
addCorner(logoWm, 7)
create("TextLabel", {
    Text = "Sg", Font = Enum.Font.GothamBlack, TextSize = 12,
    TextColor3 = bgColor, BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, -1),
    ZIndex = 52, Parent = logoWm,
})

local brandLabel = wmItem("TextLabel", {
    Text = "Sdwg.xyz", Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = accentColor, AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.fromOffset(0, 36),
})
addGradient(brandLabel)
wmDivider()

local fpsLabel = wmLabel(50)
wmDivider()

local signalIcon = wmItem("Frame", { Size = UDim2.fromOffset(13, 10) })
local signalBars = {}
for i = 1, 3 do
    signalBars[i] = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, (i - 1) * 5, 1, 0),
        Size = UDim2.fromOffset(3, 3 + i * 2.4),
        BackgroundColor3 = hoverColor, BorderSizePixel = 0,
        ZIndex = 52, Parent = signalIcon,
    })
    addCorner(signalBars[i], 1)
end
local pingLabel = wmLabel(44)
wmDivider()
local clockLabel = wmLabel(34)

local function statText(left, right)
    return string.format("<font color=\"#FFFFFF\">%s</font> <font color=\"#787878\">%s</font>", left, right)
end
fpsLabel.Text = statText("--", "fps")
pingLabel.Text = statText("--", "ms")
clockLabel.Text = "<font color=\"#FFFFFF\">" .. os.date("%H:%M") .. "</font>"

local menuButton = wmItem("Frame", {
    AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24),
    BackgroundTransparency = 0, BackgroundColor3 = elemColor,
})
addCorner(menuButton, 7)
local menuStroke = create("UIStroke", {
    Color = accentColor, Transparency = 0.6, Thickness = 1,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = menuButton,
})
create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 10), Parent = menuButton })
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7), Parent = menuButton,
})
local burger = create("Frame", {
    Size = UDim2.fromOffset(12, 10), BackgroundTransparency = 1,
    LayoutOrder = 1, Parent = menuButton,
})
local burgerLines = {}
for i = 1, 3 do
    burgerLines[i] = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, 1 + (i - 1) * 4),
        Size = UDim2.fromOffset(12, 2), BackgroundColor3 = textColor,
        BorderSizePixel = 0, ZIndex = 53, Parent = burger,
    })
    makeRound(burgerLines[i])
end
local menuLabel = create("TextLabel", {
    Text = "menu", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = textColor,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
    Size = UDim2.fromOffset(32, 24), LayoutOrder = 2, ZIndex = 53, Parent = menuButton,
})

-- Открытие/закрытие
local menuSeq = 0
local function setMenuOpen(state)
    menuOpen = state
    menuSeq += 1
    local id = menuSeq
    if state then
        main.Visible = true
        tween(mainScale, 0.3, { Scale = responsiveScale },
            Enum.EasingDirection.Out, Enum.EasingStyle.Back)
        tween(blur, 0.3, { Size = blurSize })
        task.delay(0.15, function()
            if id == menuSeq and currentTab then playSweep() end
        end)
    else
        tween(blur, 0.2, { Size = 0 })
        local t = tween(mainScale, 0.2, { Scale = 0 }, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            if id == menuSeq then main.Visible = false end
        end)
    end
end
connect(closeBtn.MouseButton1Click, function() setMenuOpen(false) end)

local hovering = false
local function refreshMenuButton()
    local hover = hovering
    tween(wmScale, 0.2, { Scale = hover and 1.03 or 1 },
        Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
    tween(wmStroke, 0.2, { Transparency = (hover or menuOpen) and 0 or 0.5 })
    local btnColor = hover and accentColor or (menuOpen and hoverColor or elemColor)
    local fg = hover and bgColor or textColor
    tween(menuButton, 0.2, { BackgroundColor3 = btnColor })
    tween(menuLabel, 0.2, { TextColor3 = fg })
    for _, l in ipairs(burgerLines) do tween(l, 0.2, { BackgroundColor3 = fg }) end
end

local function animateBurger(open)
    local d, s = Enum.EasingDirection.Out, Enum.EasingStyle.Quint
    tween(burgerLines[1], 0.35, {
        Position = UDim2.new(0.5, 0, 0, open and 5 or 1),
        Rotation = open and 45 or 0,
    }, d, s)
    tween(burgerLines[2], 0.25, {
        Size = UDim2.fromOffset(open and 0 or 12, 2),
        BackgroundTransparency = open and 1 or 0,
    }, d, s)
    tween(burgerLines[3], 0.35, {
        Position = UDim2.new(0.5, 0, 0, open and 5 or 9),
        Rotation = open and -45 or 0,
    }, d, s)
    menuLabel.Text = open and "close" or "menu"
end

connect(watermark.MouseEnter, function() hovering = true; refreshMenuButton() end)
connect(watermark.MouseLeave, function() hovering = false; refreshMenuButton() end)

-- Drag капсулы
local dragging, dragOrigin, startPos, moved
connect(watermark.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragOrigin, startPos, moved = true, input.Position, wmHolder.Position, false
    end
end)
connect(UserInputService.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - dragOrigin
    if not moved and d.Magnitude < 6 then return end
    moved = true
    wmHolder.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + d.X,
        startPos.Y.Scale, startPos.Y.Offset + d.Y)
end)
connect(UserInputService.InputEnded, function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    dragging = false
    if not moved then
        setMenuOpen(not menuOpen)
        animateBurger(menuOpen)
    end
end)

-- ============================================================
-- 9. ОБНОВЛЕНИЕ FPS/PING/ВРЕМЕНИ + ШИММЕР
-- ============================================================
local frameCount, fpsClock = 0, os.clock()
local wmStart = os.clock()
local lastLevel = -1

connect(RunService.RenderStepped, function()
    frameCount += 1
    local now = os.clock()
    if watermark.Visible then
        local t = (now - wmStart) * 0.35
        local seq = shimmerSeq(t)
        for _, g in ipairs(gradients) do g.Color = seq end
        if not hovering then
            wmStroke.Transparency = 0.15 + 0.55 * (0.5 + 0.5 * math.cos((now - wmStart) * 4))
        end
    end
    if now - fpsClock < 0.5 then return end
    local fps = math.floor(frameCount / (now - fpsClock) + 0.5)
    frameCount, fpsClock = 0, now
    if not watermark.Visible then return end
    local pingMs = math.floor(getPing() + 0.5)
    fpsLabel.Text = statText(fps, "fps")
    pingLabel.Text = statText(pingMs, "ms")
    clockLabel.Text = "<font color=\"#FFFFFF\">" .. os.date("%H:%M") .. "</font>"
    local lit = pingMs < 90 and 3 or (pingMs < 180 and 2 or 1)
    if lit ~= lastLevel then
        lastLevel = lit
        for i, b in ipairs(signalBars) do
            tween(b, 0.25, { BackgroundColor3 = i <= lit and accentColor or hoverColor })
        end
    end
end)

-- ============================================================
-- 10. ПОИСК (снизу окна)
-- ============================================================
do
    local searchBar = create("Frame", {
        Name = "Search", AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, 10),
        Size = UDim2.new(0.55, 0, 0, 32),
        BackgroundColor3 = bgColor, ZIndex = 20, Parent = main,
    })
    addCorner(searchBar, 10)
    local searchStroke = addStroke(searchBar)
    addGradient(searchStroke)

    local iconHolder = create("Frame", {
        Position = UDim2.fromOffset(12, 9.5), Size = UDim2.fromOffset(13, 13),
        BackgroundTransparency = 1, ZIndex = 21, Parent = searchBar,
    })
    local ring = create("Frame", { Size = UDim2.fromOffset(9, 9), BackgroundTransparency = 1, ZIndex = 21, Parent = iconHolder })
    makeRound(ring)
    create("UIStroke", { Color = dimColor, Thickness = 1.5, Parent = ring })
    line(iconHolder, 7.8, 7.8, 12, 12, 1.5, dimColor).ZIndex = 21

    local searchBox = create("TextBox", {
        Text = "", PlaceholderText = "Search...",
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = accentColor,
        PlaceholderColor3 = mutedColor, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -100, 1, 0),
        ZIndex = 21, Parent = searchBar,
    })
    local hint = create("TextLabel", {
        Text = "Ctrl  F", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = dimColor,
        BackgroundColor3 = elemColor, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(46, 18),
        Visible = UserInputService.KeyboardEnabled, ZIndex = 21, Parent = searchBar,
    })
    addCorner(hint, 5)
    addStroke(hint)

    local function apply()
        local q = searchBox.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
        if q == "" then
            searchTerms = nil
            for _, t in ipairs(tabs) do layoutTab(t) end
            return
        end
        local words = {}
        for w in q:gmatch("%S+") do table.insert(words, w) end
        searchTerms = words
        for _, t in ipairs(tabs) do layoutTab(t) end
    end
    connect(searchBox:GetPropertyChangedSignal("Text"), apply)
    connect(searchBox.Focused, function()
        tween(searchStroke, 0.2, { Transparency = 0 })
        hint.Visible = false
    end)
    connect(searchBox.FocusLost, function()
        tween(searchStroke, 0.2, { Transparency = 0.45 })
        if searchBox.Text == "" then hint.Visible = UserInputService.KeyboardEnabled end
    end)
    connect(UserInputService.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.F and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if not menuOpen then setMenuOpen(true) end
            task.defer(function() searchBox:CaptureFocus() end)
        elseif k == Enum.KeyCode.Escape and searchBox:IsFocused() then
            searchBox.Text = ""
            searchBox:ReleaseFocus()
        end
    end)
end

-- ============================================================
-- 11. АДАПТИВНЫЙ SCALE
-- ============================================================
local viewportConnection
local function updateResponsiveScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local tl, br = Vector2.zero, Vector2.zero
    pcall(function() tl, br = GuiService:GetGuiInset() end)
    local margin = UserInputService.TouchEnabled and 16 or 24
    local aw = math.max(1, vp.X - tl.X - br.X - margin)
    local ah = math.max(1, vp.Y - tl.Y - br.Y - margin)
    responsiveScale = math.clamp(math.min(aw / 680, ah / 470), 0.35, 1)
    if UserInputService.TouchEnabled then
        main.Position = UDim2.fromScale(0.5, 0.5)
    end
    if menuOpen then mainScale.Scale = responsiveScale end
end
local function bindViewport()
    if viewportConnection then viewportConnection:Disconnect() end
    local cam = workspace.CurrentCamera
    if cam then
        viewportConnection = connect(cam:GetPropertyChangedSignal("ViewportSize"), updateResponsiveScale)
    end
    updateResponsiveScale()
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), bindViewport)
connect(gui:GetPropertyChangedSignal("AbsoluteSize"), updateResponsiveScale)
bindViewport()

-- ============================================================
-- 12. ХОТКЕЙ
-- ============================================================
connect(UserInputService.InputBegan, function(input, gameProcessed)
    if keyListener then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local f = keyListener
            keyListener = nil
            f(input.KeyCode)
        end
        return
    end
    if gameProcessed then return end
    if input.KeyCode == toggleKey then
        setMenuOpen(not menuOpen)
        animateBurger(menuOpen)
    end
end)

-- ============================================================
-- 13. UNLOAD
-- ============================================================
_G.SdwgXyzUnload = function()
    for _, c in ipairs(connections) do c:Disconnect() end
    table.clear(connections)
    keyListener = nil
    pcall(disableNoclip)
    blur:Destroy()
    gui:Destroy()
    _G.SdwgXyzUnload = nil
end

-- ============================================================
-- 14. ИНТРО
-- ============================================================
task.spawn(function()
while not keyPassed do task.wait(0.1) end
    local overlay = create("Frame", {
        Name = "Intro", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 200, Parent = gui,
    })
    local center = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(420, 130), BackgroundTransparency = 1, Parent = overlay,
    })
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(420, 130)
    create("UIScale", { Scale = math.clamp((vp.X - 24) / 420, 0.55, 1), Parent = center })

    local font = Enum.Font.GothamBlack
    local widths, total = {}, 0
    for i = 1, #"Sdwg.xyz" do
        local ch = ("Sdwg.xyz"):sub(i, i)
        local w = ch == " " and 16 or TextService:GetTextSize(ch, 46, font, Vector2.new(200, 200)).X
        widths[i] = w
        total += w + (i < #"Sdwg.xyz" and 4 or 0)
    end
    local left = (420 - total) / 2
    local letters = {}
    local x = left
    for i = 1, #"Sdwg.xyz" do
        local ch = ("Sdwg.xyz"):sub(i, i)
        if ch ~= " " then
            local holder = create("Frame", {
                Position = UDim2.fromOffset(x, 14),
                Size = UDim2.fromOffset(widths[i], 56),
                BackgroundTransparency = 1, Parent = center,
            })
            local lbl = create("TextLabel", {
                Text = ch, Font = font, TextSize = 46, TextColor3 = accentColor,
                TextTransparency = 1, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, -26), Size = UDim2.fromScale(1, 1),
                Parent = holder,
            })
            local scale = create("UIScale", { Scale = 1.6, Parent = lbl })
            table.insert(letters, { lbl = lbl, sc = scale, i = i })
        end
        x += widths[i] + 4
    end
    local bar = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86),
        Size = UDim2.fromOffset(0, 2), BackgroundColor3 = strokeColor,
        BorderSizePixel = 0, Parent = center,
    })
    makeRound(bar)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = accentColor, BorderSizePixel = 0, Parent = bar })
    makeRound(fill)

    local start = os.clock()
    local animConn = connect(RunService.RenderStepped, function()
        local t = os.clock() - start
        for _, l in ipairs(letters) do
            local v = 0.5 + 0.5 * math.sin(t * 3 - l.i * 0.55)
            local c = math.floor(110 + v * 145)
            l.lbl.TextColor3 = Color3.fromRGB(c, c, c)
        end
    end)

    tween(overlay, 0.4, { BackgroundTransparency = 0.35 })
    tween(blur, 0.5, { Size = 24 })
    task.wait(0.3)
    for _, l in ipairs(letters) do
        tween(l.lbl, 0.55, { TextTransparency = 0, Position = UDim2.fromOffset(0, 0) },
            Enum.EasingDirection.Out, Enum.EasingStyle.Back)
        tween(l.sc, 0.55, { Scale = 1 }, Enum.EasingDirection.Out, Enum.EasingStyle.Back)
        task.wait(0.06)
    end
    task.wait(0.3)
    tween(bar, 0.45, { Size = UDim2.fromOffset(total, 2) }, Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
    task.wait(0.35)

    for _, step in ipairs({
        { "loading interface", 0.3 },
        { "loading visuals", 0.8 },
        { "done", 1 },
    }) do
        tween(fill, 0.45, { Size = UDim2.fromScale(step[2], 1) }, Enum.EasingDirection.InOut)
        task.wait(0.5)
    end
    task.wait(0.6)
    for _, l in ipairs(letters) do
        tween(l.lbl, 0.35, { TextTransparency = 1, Position = UDim2.fromOffset(0, -18) },
            Enum.EasingDirection.In)
        task.wait(0.03)
    end
    tween(overlay, 0.45, { BackgroundTransparency = 1 })
    tween(bar, 0.35, { Size = UDim2.fromOffset(0, 2) }, Enum.EasingDirection.In, Enum.EasingStyle.Quint)
    task.wait(0.5)
    animConn:Disconnect()
    overlay:Destroy()
    updateResponsiveScale()
    end)
end)
if not __SDWGXYZ_OK then
    local gui = Instance.new("ScreenGui", game:GetService("CoreGui"))
    local f = Instance.new("Frame", gui)
    f.Size = UDim2.new(0, 700, 0, 400)
    f.Position = UDim2.new(0.5, -350, 0.5, -200)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    local t = Instance.new("TextLabel", f)
    t.Size = UDim2.new(1, -20, 1, -20)
    t.Position = UDim2.new(0, 10, 0, 10)
    t.BackgroundTransparency = 1
    t.Text = "SDWGXYZ УПАЛ:\n\n" .. tostring(__SDWGXYZ_ERR)
    t.TextColor3 = Color3.fromRGB(255, 100, 100)
    t.TextWrapped = true
    t.Font = Enum.Font.Code
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Top
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 100, 0, 30)
    b.Position = UDim2.new(1, -110, 1, -40)
    b.Text = "ЗАКРЫТЬ"
    b.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.Parent = f
    b.MouseButton1Click:Connect(function() gui:Destroy() end)
end
--Дипсик король этого мира
local StarterGui = game:GetService("StarterGui")
local notifications = {
    { Title = "Sdwg.xyz", Text = "Загрузка завершена", Duration = 3 },
    { Title = "Nice", Text = "Спасибо за помощь", Duration = 5 },
    { Title = "Йа Лучший", Text = "Скрипт работает", Duration = 4 },
    { Title = "Vlad", Text = "Telegram t.me/Sdwg_Xyz", Duration = 3 },
}

task.spawn(function()
    for _, n in ipairs(notifications) do
        pcall(function()
            StarterGui:SetCore("SendNotification", n)
        end)
        task.wait(n.Duration)
    end
end)