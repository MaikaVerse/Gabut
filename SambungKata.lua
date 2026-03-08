local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenSvc = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
local PGui = LP:WaitForChild("PlayerGui")

local Remotes = RS:WaitForChild("Remotes", 9e9)
local R_MatchUI = Remotes:WaitForChild("MatchUI", 9e9)
local R_Submit = Remotes:WaitForChild("SubmitWord", 9e9)
local R_Billboard = Remotes:WaitForChild("BillboardUpdate", 9e9)
local R_UsedWarn = Remotes:WaitForChild("UsedWordWarn", 9e9)
local R_TypeSnd = Remotes:WaitForChild("TypeSound", 9e9)
local R_RequestIndex = Remotes:WaitForChild("RequestWordIndex", 9e9)
local R_Join = Remotes:WaitForChild("JoinTable", 9e9)
local R_Visibility = Remotes:WaitForChild("UpdatePromptVisibility", 9e9)

local MatchUIGui = PGui:WaitForChild("MatchUI", 20)
local BottomUI = MatchUIGui and MatchUIGui:FindFirstChild("BottomUI")
local TopUI = BottomUI and BottomUI:FindFirstChild("TopUI")
local WordSubmitF = TopUI and TopUI:FindFirstChild("WordSubmit")
local WordTmpl = TopUI and TopUI:FindFirstChild("Templates") and TopUI.Templates:FindFirstChild("Word")
local WordSrvLbl = TopUI and TopUI:FindFirstChild("WordServerFrame") and TopUI.WordServerFrame:FindFirstChild("WordServer")

local WordDB = {}
local ServerIndex = {}
local UsedWords = {}
local RejectedWords = {}
local ActiveClones = {}
local TableStatusDB = {}

local IsDBReady = false
local ServerLetter = ""
local IsMyTurn = false
local CurThread = nil
local ModeAuto = false
local ModeManual = false
local AutoJoin = false
local UseIndexPriority = true
local SelectedTarget = "Semua Meja"
local WordLengthPref = "Random"
local AntiAFKEnabled = true

local AutoCfg = { 
    DelayTerima = 1.2, 
    DelayKetik = 0.22, 
    DelaySubmit = 0.65, 
    TargetSuffix = "",
    HumanChance = 20
}

local ManCfg = { DelayKetik = 0.22, DelaySubmit = 0.65 }

local function PlayGameSnd(id, vol)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = vol or 1
    s.Parent = PGui
    s:Play()
    Debris:AddItem(s, 2)
end

local function GetExistingText()
    local text = ""
    if WordSubmitF then
        local children = {}
        for _, child in ipairs(WordSubmitF:GetChildren()) do
            if child:IsA("TextLabel") and child.Visible then table.insert(children, child) end
        end
        table.sort(children, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        for _, child in ipairs(children) do text = text .. child.Text:lower() end
    end
    return text
end

local function ClearVisual()
    for _, obj in ipairs(ActiveClones) do pcall(function() obj:Destroy() end) end
    ActiveClones = {}
    if WordSubmitF then
        for _, child in ipairs(WordSubmitF:GetChildren()) do
            if child:IsA("TextLabel") and child.Name ~= "UIGridLayout" then child:Destroy() end
        end
    end
end

local function SpawnLetter(ch, order, animate)
    if not WordTmpl or not WordSubmitF then return end
    local obj = WordTmpl:Clone()
    obj.Text = ch:upper()
    obj.LayoutOrder = order
    obj.Visible = true
    obj.Parent = WordSubmitF
    if animate then
        local sc = Instance.new("UIScale")
        sc.Scale = 0.3
        sc.Parent = obj
        TweenSvc:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end
    table.insert(ActiveClones, obj)
    return obj
end

local function TypeWord(word, delayKetik, delaySubmit)
    if not IsMyTurn or not ModeAuto then return false end
    local targetWord = word:lower()
    local currentGUI = GetExistingText()
    
    local startIndex = 1
    if #currentGUI > 0 and targetWord:sub(1, #currentGUI) == currentGUI then
        startIndex = #currentGUI + 1
    end

    local suffix = targetWord:sub(startIndex)
    local currentFullString = targetWord:sub(1, startIndex - 1)
    
    for i = 1, #suffix do
        if not IsMyTurn or not ModeAuto then return false end
        
        if math.random(1, 100) <= AutoCfg.HumanChance then
            local typoChar = string.char(math.random(97, 122))
            local typoObj = SpawnLetter(typoChar, startIndex + i - 1, true)
            PlayGameSnd(9113873548, 0.6)
            task.wait(delayKetik * 1.5)
            if typoObj then typoObj:Destroy() end
            task.wait(delayKetik * 0.5)
        end

        local char = suffix:sub(i, i)
        currentFullString = currentFullString .. char
        SpawnLetter(char, startIndex + i - 1, true)
        
        pcall(function() 
            R_Billboard:FireServer(currentFullString)
            R_TypeSnd:FireServer()
        end)
        PlayGameSnd(9113873548, 0.6)
        
        local waitT = delayKetik
        if char:find("[aeiou]") then waitT = waitT * 0.8 end
        task.wait(waitT + (math.random(-15, 20)/1000))
    end
    task.wait(delaySubmit)
    return true
end

local function SyncIndex()
    local success, data = pcall(function() return R_RequestIndex:InvokeServer() end)
    if success and data and data.AllWords then ServerIndex = data.AllWords end
end

local Win = Rayfield:CreateWindow({
    Name = "Maika Studio v3.2 Elite",
    LoadingTitle = "Maika Studio Elite Engine v3.2",
    LoadingSubtitle = "Created by Maika",
})

local TBot = Win:CreateTab("Bot Otomatis", nil)
local L_StatusAuto = TBot:CreateLabel("Giliran: Menunggu...")

_G.ToggleAuto = TBot:CreateToggle({
    Name = "Aktifkan Bot Otomatis",
    CurrentValue = false,
    Callback = function(v) 
        ModeAuto = v 
        if not v then
            if CurThread then task.cancel(CurThread) CurThread = nil end
            ClearVisual()
        end
        if v and ModeManual then
            ModeManual = false
            _G.ToggleManual:Set(false)
            Rayfield:Notify({Title = "Mode Switch", Content = "Mode Manual dimatikan!"})
        end
    end
})

TBot:CreateDropdown({
    Name = "Preferensi Panjang Kata",
    Options = {"Random", "Pendek (Efektif)", "Panjang (Gaya)"},
    CurrentOption = {"Random"},
    Callback = function(Option) WordLengthPref = Option[1] end,
})

TBot:CreateInput({
    Name = "Filter Akhiran Kata",
    PlaceholderText = "Misal: x",
    Callback = function(v) AutoCfg.TargetSuffix = v:lower() end
})

TBot:CreateInput({
    Name = "Speed Bot Diterima (Epsan)",
    PlaceholderText = "Default: 1.2",
    Callback = function(v) AutoCfg.DelayTerima = tonumber(v) or 1.2 end
})

TBot:CreateInput({
    Name = "Speed Bot Ketikan",
    PlaceholderText = "Default: 0.22",
    Callback = function(v) AutoCfg.DelayKetik = tonumber(v) or 0.22 end
})

TBot:CreateInput({
    Name = "Speed Bot Submit",
    PlaceholderText = "Default: 0.65",
    Callback = function(v) AutoCfg.DelaySubmit = tonumber(v) or 0.65 end
})

local TMan = Win:CreateTab("Pilih Manual", nil)
local L_StatusMan = TMan:CreateLabel("Giliran: Menunggu...")

_G.ToggleManual = TMan:CreateToggle({
    Name = "Aktifkan Mode Manual",
    CurrentValue = false,
    Callback = function(v) 
        ModeManual = v 
        if v and ModeAuto then
            ModeAuto = false
            _G.ToggleAuto:Set(false)
            Rayfield:Notify({Title = "Mode Switch", Content = "Mode Otomatis dimatikan!"})
        end
    end
})

local ManualDropdown = TMan:CreateDropdown({
    Name = "Pilih Jawaban", Options = {"Kosong - Bukan Giliranmu"}, CurrentOption = {"Kosong - Bukan Giliranmu"},
    Callback = function(opt)
        local picked = opt[1]:gsub("✨ ", ""):gsub("⭐ ", ""):lower()
        if not IsMyTurn or picked:find("kosong") then return end
        task.spawn(function()
            if TypeWord(picked, ManCfg.DelayKetik, ManCfg.DelaySubmit) and IsMyTurn then
                UsedWords[picked] = true
                R_Submit:FireServer(picked)
            end
        end)
    end
})

TMan:CreateInput({
    Name = "Speed Ketikan (Manual)", PlaceholderText = "0.22",
    Callback = function(v) ManCfg.DelayKetik = tonumber(v) or 0.22 end
})

TMan:CreateInput({
    Name = "Speed Submit (Manual)", PlaceholderText = "0.65",
    Callback = function(v) ManCfg.DelaySubmit = tonumber(v) or 0.65 end
})

local TTable = Win:CreateTab("Auto Join Meja", nil)
TTable:CreateToggle({
    Name = "Aktifkan Auto Join Meja", CurrentValue = false,
    Callback = function(v) AutoJoin = v end
})

local TableDropdown = TTable:CreateDropdown({
    Name = "Pilih Meja Spesifik", Options = {"Semua Meja"}, CurrentOption = {"Semua Meja"},
    Callback = function(Option) SelectedTarget = Option[1] end,
})

local TSet = Win:CreateTab("Settings", nil)

TSet:CreateToggle({
    Name = "Prioritas Non-Index (On/Off)",
    CurrentValue = true,
    Callback = function(v) UseIndexPriority = v end
})

TSet:CreateSlider({
    Name = "Human Typo Chance (%)",
    Range = {0, 100}, Increment = 1, Suffix = "%", CurrentValue = 20,
    Callback = function(v) AutoCfg.HumanChance = v end
})

TSet:CreateToggle({
    Name = "Anti-AFK (20m Bypass)",
    CurrentValue = true,
    Callback = function(v) AntiAFKEnabled = v end
})

TSet:CreateButton({
    Name = "Rejoin Server",
    Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end
})

task.spawn(function()
    for i = 97, 122 do WordDB[string.char(i)] = {} end
    local success, kbbi = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/geovedi/indonesian-wordlist/master/01-kbbi3-2001-sort-alpha.lst") end)
    if success then
        for line in kbbi:gmatch("[^\r\n]+") do
            local w = line:match("^%s*(.-)%s*$"):lower()
            if #w >= 3 then table.insert(WordDB[w:sub(1,1)], w) end
        end
        IsDBReady = true
    end
end)

local function GetBestWord(prefix)
    local prioNew, prioIndex, fallback = {}, {}, {}
    local pool = WordDB[prefix:sub(1,1)] or {}
    for _, word in ipairs(pool) do
        if not UsedWords[word] and not RejectedWords[word] and word:sub(1, #prefix) == prefix then
            local isSuffixMatch = (AutoCfg.TargetSuffix == "" or word:sub(-#AutoCfg.TargetSuffix) == AutoCfg.TargetSuffix)
            if isSuffixMatch then
                if UseIndexPriority and not ServerIndex[word] then table.insert(prioNew, word) else table.insert(prioIndex, word) end
            end
            table.insert(fallback, word)
        end
    end
    if WordLengthPref == "Pendek (Efektif)" then
        table.sort(prioNew, function(a,b) return #a < #b end)
        table.sort(prioIndex, function(a,b) return #a < #b end)
    elseif WordLengthPref == "Panjang (Gaya)" then
        table.sort(prioNew, function(a,b) return #a > #b end)
        table.sort(prioIndex, function(a,b) return #a > #b end)
    end
    if #prioNew > 0 then return prioNew[math.random(1, #prioNew)] end
    if #prioIndex > 0 then return prioIndex[math.random(1, #prioIndex)] end
    return #fallback > 0 and fallback[math.random(1, #fallback)] or nil
end

local function RunBot(letter)
    if CurThread then task.cancel(CurThread) end
    CurThread = task.spawn(function()
        task.wait(AutoCfg.DelayTerima)
        while IsMyTurn and ModeAuto do
            SyncIndex()
            local prefix = GetExistingText()
            if #prefix == 0 then prefix = letter:lower() end
            local chosen = GetBestWord(prefix)
            if chosen and ModeAuto then
                local success = TypeWord(chosen, AutoCfg.DelayKetik, AutoCfg.DelaySubmit)
                if success and IsMyTurn and ModeAuto then
                    R_Submit:FireServer(chosen)
                    task.wait(1)
                end
            else
                break
            end
            task.wait(0.5)
        end
    end)
end

R_MatchUI.OnClientEvent:Connect(function(cmd, val)
    if cmd == "UpdateServerLetter" then ServerLetter = tostring(val):lower()
    elseif cmd == "StartTurn" then
        IsMyTurn = true
        L_StatusAuto:Set("Giliran: SEDANG GILIRANMU!")
        L_StatusMan:Set("Giliran: SEDANG GILIRANMU!")
        if ModeAuto then RunBot(ServerLetter) 
        elseif ModeManual then
            SyncIndex()
            local prefix = GetExistingText() or ServerLetter
            local display = {}
            local pool = WordDB[prefix:sub(1,1)] or {}
            for _, w in ipairs(pool) do
                if not UsedWords[w] and not RejectedWords[w] and w:sub(1, #prefix) == prefix then
                    table.insert(display, (not ServerIndex[w] and "✨ " or "⭐ ") .. w:upper())
                    if #display >= 25 then break end
                end
            end
            ManualDropdown:Refresh(display, true)
        end
    elseif cmd == "EndTurn" or cmd == "HideMatchUI" then
        IsMyTurn = false
        L_StatusAuto:Set("Giliran: Menunggu...")
        L_StatusMan:Set("Giliran: Menunggu...")
        ManualDropdown:Refresh({"Kosong - Bukan Giliranmu"}, true)
        ClearVisual()
        if CurThread then task.cancel(CurThread) CurThread = nil end
    elseif cmd == "Mistake" then
        PlayGameSnd(550209561, 1.2)
        local lastWord = GetExistingText()
        if lastWord ~= "" then RejectedWords[lastWord] = true end
        ClearVisual()
        if ModeAuto and IsMyTurn then
            task.wait(0.2)
            RunBot(ServerLetter)
        end
    end
end)

R_Visibility.OnClientEvent:Connect(function(data)
    if type(data) == "table" then
        TableStatusDB = data
        local newOptions = {"Semua Meja"}
        for name, _ in pairs(data) do table.insert(newOptions, name) end
        table.sort(newOptions)
        TableDropdown:Refresh(newOptions, true)
    end
end)

task.spawn(function()
    while true do
        if AutoJoin and not LP:GetAttribute("CurrentTable") then
            for name, isLocked in pairs(TableStatusDB) do
                if (SelectedTarget == "Semua Meja" or SelectedTarget == name) and isLocked == false then
                    R_Join:FireServer(name)
                    break
                end
            end
        end
        task.wait(2)
    end
end)

LP.Idled:Connect(function()
    if AntiAFKEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

task.spawn(function()
    while true do
        if AntiAFKEnabled and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
            LP.Character.HumanoidRootPart.CFrame = LP.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0.01, 0)
        end
        task.wait(600)
    end
end)

task.spawn(function() while true do pcall(function() R_Join:FireServer() end) task.wait(5) end end)
R_Join:FireServer()
Rayfield:Notify({Title = "Maika Studio", Content = "V3.2 Final: Hard Kill-Switch Active!"})
