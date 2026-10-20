--------------------------------------------------------------------
-- Trailbound 1.8.46
--  * Auto-opens vendor (and optionally trainer) gossip
--  * Auto accepts / turns in quests (skips quests with a reward choice)
--  * Auto-sells gray junk when a vendor window opens
--  * Five-second-rule bar under the player's mana bar
--  * Buff reminders (movable, resizable)
--  * Spellbook panel: unlearned class spells, level + cost
--  * Quest-object highlight (best effort, client setting)
--  * Settings window: /tb
-- Hold SHIFT while talking to an NPC / opening a vendor to bypass automation.
--------------------------------------------------------------------
local DB, characterDB
local defaults = {
    gossipVendor = true, gossipTrainer = false,
    acceptQuests = true, turnInQuests = true,
    sellJunk = true, junkReport = true,
    fsr = true, fsrScale = 1,
    book = true, gathering = true, accountBags = true, professionBook = true,
    cameraMax = true, cameraFactor = 4, cameraRequest = "4",
    sparkle = true,
    petReminder = true, sleepingBagReminder = true, audioFollowSystem = true, flightTimer = true, levelTimes = true, craftProfit = true,
    buffs = true, buffsHideCombat = false, buffsHideMounted = true,
    buffSize = 48, buffTextSize = 14, buffX = 0, buffY = 150,
}
local skipQuests = {}

local function Print(msg) print("|cffd2b077Trailbound:|r " .. msg) end

--------------------------------------------------------------------
-- Gossip
--------------------------------------------------------------------
local ICON_VENDOR, ICON_TRAINER = 132060, 132058

local function OptionKind(o)
    if o.type then return o.type end
    local icon = o.overrideIconID or o.icon
    if icon == ICON_VENDOR then return "vendor" end
    if icon == ICON_TRAINER then return "trainer" end
end

local function HandleGossip()
    if IsShiftKeyDown() or not C_GossipInfo then return end

    if DB.acceptQuests then
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            C_GossipInfo.SelectAvailableQuest(q.questID)
            return
        end
    end
    if DB.turnInQuests then
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete and not skipQuests[q.questID] then
                C_GossipInfo.SelectActiveQuest(q.questID)
                return
            end
        end
    end

    for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do
        local kind = OptionKind(o)
        if (kind == "vendor" and DB.gossipVendor) or (kind == "trainer" and DB.gossipTrainer) then
            C_GossipInfo.SelectOption(o.gossipOptionID)
            return
        end
    end
end

--------------------------------------------------------------------
-- Quests
--------------------------------------------------------------------
local function IsTitleComplete(title)
    if C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetNumQuestLogEntries then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.title == title then
                return C_QuestLog.IsComplete(info.questID)
            end
        end
    elseif GetQuestLogTitle then
        for i = 1, GetNumQuestLogEntries() do
            local t, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
            if not isHeader and t == title then return isComplete == 1 or isComplete == true end
        end
    end
    return false
end

local function HandleQuestGreeting()
    if IsShiftKeyDown() then return end
    if DB.acceptQuests then
        for i = 1, GetNumAvailableQuests() do SelectAvailableQuest(i) return end
    end
    if DB.turnInQuests then
        for i = 1, GetNumActiveQuests() do
            if IsTitleComplete(GetActiveTitle(i)) then SelectActiveQuest(i) return end
        end
    end
end

local function HandleQuestComplete()
    if IsShiftKeyDown() or not DB.turnInQuests then return end
    if GetNumQuestChoices() > 1 then
        local id = GetQuestID and GetQuestID()
        if id then skipQuests[id] = true end
        return
    end
    GetQuestReward(1)
end

--------------------------------------------------------------------
-- Junk seller
--------------------------------------------------------------------
local function SellJunk()
    if IsShiftKeyDown() or not DB.sellJunk then return end
    ForeverAssistExtras.RequestAutoSale()
end

--------------------------------------------------------------------
-- Quest object highlight (best effort)
-- Quest-object highlighting uses the client's native outline setting.
-- Toggle only if the setting exists; gathering overlays are a separate module.
--------------------------------------------------------------------
local function ApplySparkle(report)
    local ok, cur = pcall(GetCVar, "outlineMode")
    if not ok or cur == nil then
        if report then Print("This client has no object-highlight setting I can change.") end
        return
    end
    if DB.sparkle then
        if DB.sparkleOrig == nil then DB.sparkleOrig = cur end
        pcall(SetCVar, "outlineMode", "2")
    elseif DB.sparkleOrig ~= nil then
        pcall(SetCVar, "outlineMode", DB.sparkleOrig)
        DB.sparkleOrig = nil
    end
end

--------------------------------------------------------------------
-- Five second rule bar
--------------------------------------------------------------------
local fsr = CreateFrame("StatusBar", "ForeverAssistFSR", UIParent)
fsr:SetSize(119, 10)
fsr:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
fsr:SetStatusBarColor(0.9, 0.3, 0.2)
fsr:SetMinMaxValues(0, 5)
fsr:SetFrameStrata("MEDIUM")
fsr.bg = fsr:CreateTexture(nil, "BACKGROUND")
fsr.bg:SetAllPoints()
fsr.bg:SetColorTexture(0, 0, 0, 0.6)
fsr.text = fsr:CreateFontString(nil, "OVERLAY", "TrailboundSmall")
fsr.text:SetPoint("CENTER")
fsr:Hide()

local function AnchorFSR()
    if DB and DB.fsrPosition then
        fsr:SetParent(UIParent);fsr:ClearAllPoints();fsr:SetPoint('CENTER',UIParent,'CENTER',DB.fsrPosition[1],DB.fsrPosition[2]);fsr:SetSize(160,10*(DB.fsrScale or 1));return true
    end
    local main = PlayerFrame and PlayerFrame.PlayerFrameContent
    main = main and main.PlayerFrameContentMain
    local target = main and main.ManaBarArea and main.ManaBarArea.ManaBar
        or PlayerFrameManaBar
    if not target then fsr:Hide(); return false end
    fsr:SetParent(target)
    fsr:ClearAllPoints()
    fsr:SetScale(1)
    fsr:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -2)
    fsr:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -2)
    fsr:SetHeight(10 * (DB and DB.fsrScale or 1))
    fsr:SetFrameLevel(target:GetFrameLevel() + 5)
    return true
end

local endTime, flashUntil = 0, 0
fsr:SetScript("OnUpdate", function(self)
    if not DB or not DB.fsr then self:Hide(); return end
    local now = GetTime()
    if now < endTime then
        self:SetValue(5 - (endTime - now))
        self.text:SetFormattedText("%.1fs", endTime - now)
    elseif now < flashUntil then
        self:SetValue(5)
        self:SetStatusBarColor(0.2, 0.9, 0.3)
        self.text:SetText("Mana regen!")
    else
        self:Hide()
    end
end)

local function CostsMana(spellID)
    local fn = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
    if fn then
        local ok, costs = pcall(fn, spellID)
        if ok and type(costs) == "table" then
            for _, c in ipairs(costs) do
                if c.type == 0 and (c.cost or 0) > 0 then return true end
            end
            return false
        end
    end
    return UnitPowerType("player") == 0
end

local function StartFSR()
    if not AnchorFSR() then return end
    endTime = GetTime() + 5
    flashUntil = endTime + 0.8
    fsr:SetStatusBarColor(0.9, 0.3, 0.2)
    fsr:Show()
end

--------------------------------------------------------------------
-- Known spells (spellbook scan)
--------------------------------------------------------------------
local function BuildKnown()
    local set, names, ids = {}, {}, {}
    local getName
    if C_SpellBook and C_SpellBook.GetSpellBookItemName and Enum and Enum.SpellBookSpellBank then
        getName = function(i) return C_SpellBook.GetSpellBookItemName(i, Enum.SpellBookSpellBank.Player) end
    else
        local f = GetSpellBookItemName or GetSpellName
        getName = function(i) if f then return f(i, BOOKTYPE_SPELL or "spell") end end
    end
    for i = 1, 1024 do
        local ok, name, rank = pcall(getName, i)
        if not ok or not name then break end
        rank = ForeverAssistSystems.NormalizeRank(rank)
        local learned = true
        if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
            local got, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, Enum.SpellBookSpellBank.Player)
            local future = Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell or 2
            if got and info and info.itemType == future then learned = false end
        end
        if learned then
            local id
            if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
                local ok,info=pcall(C_SpellBook.GetSpellBookItemInfo,i,Enum.SpellBookSpellBank.Player)
                if ok and info then id=info.spellID end
            elseif GetSpellBookItemInfo then
                local ok,_,spellID=pcall(GetSpellBookItemInfo,i,BOOKTYPE_SPELL or "spell");if ok then id=spellID end
            end
            if id then ids[id]=true end
            set[name .. "|" .. (rank or "")] = true
            names[name] = true
        end
    end
    return set, names, ids
end

--------------------------------------------------------------------
-- Trainer scan (feeds the spellbook panel)
--------------------------------------------------------------------
local function ScanTrainer()
    if not GetNumTrainerServices then return end
    local professionTrainer = IsTradeskillTrainer and IsTradeskillTrainer() or false
    local n = GetNumTrainerServices()
    if not n or n == 0 then return end
    for i = 1, n do
        local name, second, third, reqLevel, fifth = GetTrainerServiceInfo(i)
        local rank, cat
        if second == "available" or second == "unavailable" or second == "used" or second == "header" then
            cat, rank = second, type(fifth) == "string" and fifth or ""
        else
            rank, cat = second, third
        end
        if name and cat ~= "header" then
            rank = ForeverAssistSystems.NormalizeRank(rank)
            local key = name .. "|" .. rank
            local level=type(reqLevel)=='number'and (not issecretvalue or not issecretvalue(reqLevel))and reqLevel or 0
            if GetTrainerServiceLevelReq then local ok,value=pcall(GetTrainerServiceLevelReq,i);if ok and (not issecretvalue or not issecretvalue(value))and type(value)=='number'then level=value end end
            local record = {
                name = name, rank = rank, icon=GetTrainerServiceIcon and GetTrainerServiceIcon(i) or nil,
                level = level,
                cost = GetTrainerServiceCost(i) or 0,
                available = cat == "available",
            }
            ForeverAssistSystems.StoreTraining(key, record, i, professionTrainer, cat == "used")
        end
    end
end

--------------------------------------------------------------------
-- Spellbook panel
--------------------------------------------------------------------
local book, content, rows, header, footer = nil, nil, {}, nil, nil
local bookHost, bookRoot
local ROW_H = 30

local function GetRow(i)
    local r = rows[i]
    if not r then
        r = CreateFrame("Frame", nil, content)
        r:SetSize(290, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r.left = r:CreateFontString(nil, "OVERLAY", "TrailboundHeading")
        r.icon=r:CreateTexture(nil,"ARTWORK");r.icon:SetSize(22,22);r.icon:SetPoint("LEFT",0,0)
        r.left:SetPoint("TOPLEFT", 28, -1)
        r.left:SetWidth(258)
        r.left:SetJustifyH("LEFT")
        r.left:SetHeight(14)
        r.left:SetMaxLines(1);r.left:SetWordWrap(false)
        r.level = r:CreateFontString(nil,"OVERLAY","TrailboundSmall");r.level:SetPoint("BOTTOMLEFT",28,2)
        r.right = r:CreateFontString(nil, "OVERLAY", "TrailboundSmall")
        r.right:SetPoint("BOTTOMRIGHT", 0, 2)
        r.right:SetJustifyH("RIGHT")
        r.right:SetWidth(75)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local spell = self.spell
            if spell and spell.spellID then GameTooltip:SetSpellByID(spell.spellID)
            elseif spell then GameTooltip:AddLine(spell.name .. " " .. (spell.rank or "")) end
            GameTooltip:AddLine("Class trainer spell. Prices update when you visit a trainer.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end
    return r
end

local function SpellKnown(spell)
    if not spell.spellID then return false end
    for _,fn in pairs({C_SpellBook and C_SpellBook.IsSpellKnown,IsPlayerSpell,IsSpellKnown}) do
        local ok,known=pcall(fn,spell.spellID);if ok and known then return true end
    end
    return false
end
local function TrainerEligible(spell)
    if spell.trainer == false or spell.talent or spell.passive then return false end
    if spell.faction and UnitFactionGroup and UnitFactionGroup("player") ~= spell.faction then return false end
    if spell.races and UnitRace then local _,_,race=UnitRace("player");local matches=false;for _,id in ipairs(spell.races) do if race==id then matches=true end end;if not matches then return false end end
    if spell.spellID and C_Spell then
        if C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spell.spellID) then return false end
        if C_Spell.IsClassTalentSpell and C_Spell.IsClassTalentSpell(spell.spellID) then return false end
    end
    return true
end
local function RefreshBook()
    if not book or not book:IsShown() then return end
    local _, class = UnitClass("player")
    local lvl = UnitLevel("player")
    local known,_,knownIDs = BuildKnown()
    local list = ForeverAssistSystems.ClassSpellList(ForeverAssistSpellData and ForeverAssistSpellData[class] or {},characterDB.trainer,known,knownIDs,SpellKnown,TrainerEligible)
    local totalNow = 0
    for i, spell in ipairs(list) do
        local row = GetRow(i)
        row.spell = spell
        local info=spell.spellID and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell.spellID)
        row.icon:SetTexture(spell.icon or info and info.iconID or 134400)
        local color = spell.level <= lvl and "|cffeacc91" or "|cffff5555"
        local rank = spell.rank and spell.rank ~= "" and (" (" .. spell.rank .. ")") or ""
        row.left:SetText(color..spell.name .. rank..'|r')
        row.level:SetText(color .. "Level " .. spell.level .. "|r")
        row.right:SetText(spell.cost ~= nil and ForeverAssistMoney(spell.cost) or "—")
        row:Show()
        if spell.cost and spell.level <= lvl and spell.available ~= false then totalNow = totalNow + spell.cost end
    end
    for i=#list+1,#rows do rows[i]:Hide() end
    content:SetHeight(math.max(1,#list*ROW_H))
    header:SetText("Unlearned trainer spells through level 60")
    footer:SetText(totalNow > 0 and ("Available scanned cost: " .. ForeverAssistMoney(totalNow)) or "Visit your class trainer to update prices.")
end

local function CreateBook()
    if book then return end
    bookRoot = PlayerSpellsFrame or SpellBookFrame
    bookHost = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame or SpellBookFrame
    if not bookHost then return end
    book = CreateFrame("Frame", "ForeverAssistBook", bookHost,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    book:SetSize(350, 420)
    book:SetPoint("TOPLEFT", bookRoot, "TOPRIGHT", 4, -10)
    book:SetClampedToScreen(true)
    book:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    local title = book:CreateFontString(nil, "OVERLAY", "TrailboundHeading")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Trainable Spells")
    header = book:CreateFontString(nil, "OVERLAY", "TrailboundSmall")
    header:SetPoint("TOP", 0, -32)
    footer = book:CreateFontString(nil, "OVERLAY", "TrailboundHeading")
    footer:SetPoint("BOTTOM", 0, 14)
    footer:SetWidth(280)

    local close = CreateFrame("Button", nil, book, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:HookScript("OnClick", function() DB.book = false end)

    local scroll = CreateFrame("ScrollFrame", "ForeverAssistBookScroll", book, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -58)
    scroll:SetPoint("BOTTOMRIGHT", -32, 38)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(290, 1)
    scroll:SetScrollChild(content)

    book:SetScript("OnShow", RefreshBook)
    bookHost:HookScript("OnShow", function()
        book:SetShown(DB.book)
        RefreshBook()
    end)
    book:SetShown(DB.book and bookHost:IsShown())
end

local function SetBookShown()
    CreateBook()
    if book then
        book:SetShown(DB.book and bookHost:IsShown())
        RefreshBook()
    end
end

--------------------------------------------------------------------
-- Class buff reminders
--------------------------------------------------------------------
-- Each group = alternatives; having ANY of them counts as buffed.
-- Spell IDs are only used to look up localized names/icons.
local BUFF_GROUPS = {
    WARRIOR = { { 6673 } },
    PALADIN = { { 19740, 19742, 20217, 1038, 19977, 20911,
                  25782, 25894, 25898, 25895, 25890, 25899 } },
    PRIEST  = { { 1243, 21562 }, { 588 } },
    MAGE    = { { 1459, 23028 }, { 168, 7302, 6117, 30482 } },
    WARLOCK = { { 687, 706, 28176 } },
    DRUID   = { { 1126, 21849 }, { 467 } },
    HUNTER  = { { 13165, 13163, 5118, 13159, 13161, 20043, 34074, 61846 } },
    SHAMAN  = { { 324, 24398 } },
}

local function SpellNameIcon(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(id)
        if i then return i.name, i.iconID end
        return nil
    end
    local name, _, icon = GetSpellInfo(id)
    return name, icon
end

local activeGroups = {}

local function BuildBuffGroups()
    activeGroups = {}
    local _, class = UnitClass("player")
    local defs = BUFF_GROUPS[class]
    if not defs then return end
    local _, knownNames = BuildKnown()
    for _, ids in ipairs(defs) do
        local g = { names = {} }
        for _, id in ipairs(ids) do
            local name, icon = SpellNameIcon(id)
            if name then
                g.names[#g.names + 1] = name
                if knownNames[name] and not g.label then g.label, g.icon, g.spell = name, icon, name end
            end
        end
        if g.label then activeGroups[#activeGroups + 1] = g end
    end
end

local function PlayerBuffNames()
    local set,auras = {},{}
    for i = 1, 255 do
        local aura,readable=ForeverAssistReadPlayerAura(i)
        if not readable then return nil,{} end
        if not aura then break end
        local name=aura.name
        if name then auras[#auras+1]=aura;set[name]=true end
    end
    return set,auras
end

local rem
local unlocked = false

local function GetReminderIcon(i)
    local b = rem.icons[i]
    if not b then
        b = CreateFrame("Button", nil, rem, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("useOnKeyDown", false)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.label = b:CreateFontString(nil, "OVERLAY")
        b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
        b:EnableMouse(true);b:RegisterForDrag("LeftButton")
        b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine(self.fullLabel or "Reminder",1,1,1);if self.castSpell then GameTooltip:AddLine("Click to cast on yourself",.45,1,.65) end;GameTooltip:Show() end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        b:SetScript("OnDragStart",function() if unlocked and not InCombatLockdown() then rem:StartMoving() end end)
        b:SetScript("OnDragStop",function() local fn=rem:GetScript("OnDragStop");if fn then fn(rem) end end)
        rem.icons[i] = b
    end
    return b
end

local function AnchorReminder()
    if InCombatLockdown() then return end
    rem:ClearAllPoints()
    rem:SetPoint("CENTER", UIParent, "CENTER", DB.buffX, DB.buffY)
end

local function LayoutReminder(list)
    if RegisterStateDriver then
        local rule=DB.buffsHideCombat and "[combat] hide; show" or nil
        if rem.faVisibilityRule~=rule then
            if rule then RegisterStateDriver(rem,"visibility",rule)
            elseif UnregisterStateDriver then UnregisterStateDriver(rem,"visibility") end
            rem.faVisibilityRule=rule
        end
    end
    local size, tsize = DB.buffSize, DB.buffTextSize
    tsize=math.min(tsize,12)
    local spacing = size + 12
    for i, g in ipairs(list) do
        local b = GetReminderIcon(i)
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("LEFT", rem, "LEFT", (i - 1) * spacing + (spacing - size) / 2, 0)
        b.tex:SetTexture(g.icon or 134400)
        b.label:SetFont(STANDARD_TEXT_FONT, tsize, "OUTLINE")
        b.label:SetWidth(spacing-4);b.label:SetHeight(tsize*2+4);b.label:SetJustifyH("CENTER");b.label:SetWordWrap(true)
        b.fullLabel=g.label
        b.castSpell=not unlocked and g.spell or nil
        b:SetAttribute("type",b.castSpell and "spell" or nil)
        b:SetAttribute("spell",b.castSpell)
        b:SetAttribute("unit","player")
        b.label:SetText("|cffff4040" .. ForeverAssistReminders.ShortLabel(g) .. "|r")
        b:Show()
    end
    for i = #list + 1, #rem.icons do rem.icons[i]:Hide() end
    rem:SetSize(math.max(1, #list * spacing), size)
    rem:SetShown(#list > 0)
end

local function UpdateReminder()
    if not rem or InCombatLockdown() then return end
    local list = {}
    local have,auras
    if not unlocked then
        have,auras=PlayerBuffNames()
        if not have then LayoutReminder({});return end
    end
    local sleeping=not unlocked and ForeverAssistReminders.SleepingBagReminder(auras,DB.sleepingBagReminder)
    if unlocked then
        list = { { label = "Drag me", icon = 134400 }, { label = "Preview", icon = 134400 } }
    elseif (DB.buffs or DB.gathering or DB.petReminder or DB.sleepingBagReminder)
        and not ForeverAssistReminders.InCapital()
        and not UnitIsDeadOrGhost("player")
        and not (DB.buffsHideCombat and UnitAffectingCombat("player"))
        and not (DB.buffsHideMounted and ((IsMounted and IsMounted()) or UnitOnTaxi("player"))) then
        local _,class=UnitClass("player")
        if DB.buffs and class=="PALADIN" then
            local blessing=ForeverAssistPlay.PaladinReminder(auras);if blessing then list[#list+1]=blessing end
        end
        for _, g in ipairs(DB.buffs and class~="PALADIN" and activeGroups or {}) do
            local ok = false
            for _, n in ipairs(g.names) do
                if have[n] then ok = true break end
            end
            if not ok then list[#list + 1] = g end
        end
        for _, g in ipairs(ForeverAssistSystems.GatheringReminders()) do list[#list + 1] = g end
        if DB.petReminder then local pet=ForeverAssistReminders.PetReminder(auras);if pet then list[#list+1]=pet end end
        if sleeping then list[#list+1]=sleeping end
    end
    LayoutReminder(list)
end

local optionsRefresh -- defined later

local function SetUnlocked(v)
    if InCombatLockdown() then Print("Change reminder position after combat.");return end
    unlocked = v
    rem:EnableMouse(v)
    rem.bg:SetShown(v)
    UpdateReminder()
    if optionsRefresh then optionsRefresh() end
end
function ForeverAssistApplyLayout()
    if InCombatLockdown() or not DB then return end
    ForeverAssistPlay.ApplyLayout()
    if rem then AnchorReminder() end
    AnchorFSR()
    if ForeverAssistExternals then ForeverAssistExternals.Refresh() end
    if ForeverAssistLevels then ForeverAssistLevels.Apply() end
end

local function CreateReminder()
    rem = CreateFrame("Frame", "ForeverAssistReminder", UIParent, "SecureHandlerStateTemplate")
    rem.icons = {}
    rem:SetFrameStrata("HIGH")
    rem:SetClampedToScreen(true)
    rem:SetMovable(true)
    rem:RegisterForDrag("LeftButton")
    rem.bg = rem:CreateTexture(nil, "BACKGROUND")
    rem.bg:SetPoint("TOPLEFT", -6, 6)
    rem.bg:SetPoint("BOTTOMRIGHT", 6, -24)
    rem.bg:SetColorTexture(0.2, 0.8, 0.2, 0.35)
    rem.bg:Hide()
    rem:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
    rem:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        DB.buffX = math.floor(cx - ux + 0.5)
        DB.buffY = math.floor(cy - uy + 0.5)
        AnchorReminder()
        if optionsRefresh then optionsRefresh() end
    end)
    AnchorReminder()
    rem:Hide()
end

--------------------------------------------------------------------
-- Settings window
--------------------------------------------------------------------
local opt
local refreshers = {}

local function Header(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "TrailboundHeading")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
end

local function Check(parent, key, label, x, y, onChange)
    local name = "FACheck" .. key
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[name .. "Text"]:SetText(label)
    if _G[name .. "Text"].SetFontObject then _G[name .. "Text"]:SetFontObject('TrailboundText')end
    cb:SetScript("OnClick", function(self)
        DB[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(DB[key]) end
end

local function Slider(parent, key, label, x, y, minV, maxV, step, onChange)
    local name = "FASlider" .. key
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(200)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    _G[name .. "Low"]:SetText(minV)
    _G[name .. "High"]:SetText(maxV)
    if _G[name .. "Low"].SetFontObject then _G[name .. "Low"]:SetFontObject('TrailboundSmall');_G[name .. "High"]:SetFontObject('TrailboundSmall')end
    local text = _G[name .. "Text"]
    s:SetScript("OnValueChanged", function(self, v)
        v = tonumber(string.format("%.2f", math.floor(v / step + 0.5) * step))
        text:SetText(label .. ": " .. string.format("%g", v))
        if self.syncing then return end
        DB[key] = v
        if onChange then onChange() end
    end)
    refreshers[#refreshers + 1] = function()
        s.syncing = true
        s:SetValue(DB[key])
        text:SetText(label .. ": " .. string.format("%g", DB[key]))
        s.syncing = false
    end
end

local function Button(parent, label, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(170, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    if ForeverAssistStyleButton then ForeverAssistStyleButton(b) end
    return b
end

local unlockButton

optionsRefresh = function()
    for _, fn in ipairs(refreshers) do fn() end
    if unlockButton then unlockButton:SetText(unlocked and "Lock reminder position" or "Unlock & move reminder") end
end

local function CreateOptions()
    local function label(parent,value,x,y,width,font)
        local t=parent:CreateFontString(nil,"OVERLAY",font or "TrailboundSmall");t:SetPoint("TOPLEFT",x,y);t:SetWidth(width or 460);t:SetJustifyH("LEFT");t:SetText(value);return t
    end
    local function tint(parent,x,y,width,height,r,g,b,a)
        local t=parent:CreateTexture(nil,"BACKGROUND");t:SetPoint("TOPLEFT",x,y);t:SetSize(width,height);t:SetColorTexture(r,g,b,a or 1);return t
    end
    opt=CreateFrame("Frame","ForeverAssistOptions",UIParent,"BackdropTemplate")
    opt:SetSize(860,680);opt:SetPoint("CENTER");opt:SetFrameStrata("DIALOG");opt:SetClampedToScreen(true);opt:SetMovable(true);opt:EnableMouse(true);opt:RegisterForDrag("LeftButton");opt:SetScript("OnDragStart",opt.StartMoving);opt:SetScript("OnDragStop",opt.StopMovingOrSizing)
    opt:SetBackdrop({bgFile="Interface/DialogFrame/UI-DialogBox-Background",edgeFile="Interface/DialogFrame/UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}});opt:SetBackdropColor(.22,.17,.12,1);opt:SetBackdropBorderColor(.6,.48,.31,1)
    tint(opt,8,-8,844,56,.10,.065,.035);tint(opt,8,-65,186,587,.075,.05,.03);tint(opt,194,-65,1,587,.42,.30,.15)
    local brand=opt:CreateTexture(nil,"ARTWORK");brand:SetSize(44,44);brand:SetPoint("TOPLEFT",18,-10)
    brand:SetTexture("Interface/AddOns/Trailbound/Media/TrailboundMark");opt.brandIcon=brand
    local wordmark=label(opt,"Trailbound",74,-14,380,"TrailboundTitle");wordmark:SetFont('Fonts/FRIZQT__.TTF',24,'');wordmark:SetTextColor(.94,.80,.48)
    label(opt,"Quality-of-life tools for your adventures    •    Jemai    •    v"..ForeverAssistPlay.Version,75,-43,545)
    local footer=label(opt,"/tb   •   Changes save as you go   •   Drag the header to move",22,0,800);footer:ClearAllPoints();footer:SetPoint("BOTTOMLEFT",22,16);opt.footer=footer
    local close=CreateFrame("Button",nil,opt,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-5,-5);tinsert(UISpecialFrames,"ForeverAssistOptions")
    local edit=Button(opt,'Edit mode',660,-19,function()ForeverAssistLayout.Set(true)end);edit:SetSize(145,28);opt.editModeButton=edit
    local sections,nav={},{};local selected='general'
    local activeEditor
    local editorScroll=CreateFrame("ScrollFrame",nil,opt,"UIPanelScrollFrameTemplate")
    editorScroll:SetPoint("TOPLEFT",opt,"TOPLEFT",210,-74);editorScroll:SetPoint("BOTTOMRIGHT",opt,"BOTTOMRIGHT",-35,42);editorScroll:Hide();opt.editorScroll=editorScroll
    local editors={}
    function ForeverAssistShowEditor(editor)
        if not opt:IsShown() then opt:Show() end
        if activeEditor and activeEditor~=editor then activeEditor:Hide() end
        for _,page in pairs(sections) do page:Hide() end
        if not editors[editor] then
            editors[editor]=true;if editor.SetBackdrop then editor:SetBackdrop(nil) end;editor:SetMovable(false);editor:SetClampedToScreen(false)
            editor:SetScript("OnDragStart",nil);editor:SetScript("OnDragStop",nil)
            for _,child in ipairs({editor:GetChildren()}) do
                local value=child.GetText and child:GetText()
                if type(value)=="string" and (value:match("^Back") or value=="X") then child:Hide() end
                -- Template close buttons have no text; own editor constructors mark them.
                if child.faEditorClose then child:Hide() end
            end
            editor:HookScript("OnHide",function(self)
                if activeEditor==self then activeEditor=nil;editorScroll:Hide();for name,page in pairs(sections) do page:SetShown(name==selected) end end
            end)
        end
        editor:SetParent(editorScroll);editor:ClearAllPoints();editor:SetPoint("TOPLEFT",editorScroll,"TOPLEFT",0,0)
        editorScroll:SetScrollChild(editor);if editorScroll.SetVerticalScroll then editorScroll:SetVerticalScroll(0) end
        activeEditor=editor;editorScroll:Show();editor:Show()
    end
    opt:SetScript("OnHide",function() if activeEditor then activeEditor:Hide() end end)
    local function section(key,name,title,description)
        local f=CreateFrame("Frame",name,opt);f:SetSize(500,465);f:SetPoint("TOPLEFT",216,-83);f:Hide();sections[key]=f
        f.journalTitle=title;label(f,title,0,0,490,"TrailboundTitle");label(f,description,0,-29,490);return f
    end
    local function heading(f,title,y)
        label(f,title,0,y,490,"TrailboundHeading");tint(f,0,y-23,490,1,.38,.27,.14)
    end
    local function applyPlay() ForeverAssistPlay.ApplySettings() end
    local general=section('general','ForeverAssistGeneralOptions','Quests & class training','Quest interactions, NPC shortcuts, and your class spell catalogue.')
    heading(general,'Interactions',-70)
    Check(general,"gossipVendor","Auto-open vendor window",0,-99)
    Check(general,"gossipTrainer","Auto-open trainer window",0,-132)
    Check(general,"acceptQuests","Auto-accept quests",0,-165)
    Check(general,"turnInQuests","Auto turn-in without reward choice",0,-198)
    Check(general,"sparkle","Highlight quest objects",0,-231,function() ApplySparkle(true) end)
    label(general,'Hold Shift while talking to an NPC to bypass gossip, quest acceptance and automatic turn-ins.',2,-270,470)
    heading(general,'Training catalogues',-324)
    Check(general,"book","Show class spells in spellbook",0,-353,SetBookShown)
    local junk=section('inventory','ForeverAssistJunkOptions','Bags, banks & vendors','Account inventory, bag movement, looting, and automatic selling.')
    heading(junk,'Vendor junk',-70)
    Check(junk,"sellJunk","Auto-sell gray items",0,-99,function() if not DB.sellJunk then ForeverAssistExtras.CancelAutomaticSale() end end)
    Check(junk,"junkReport","Print sale summary",0,-132)
    Button(junk,"Open junk manager",0,-180,function() opt:Hide();ForeverAssistExtras.ToggleJunk() end)
    Button(junk,"Assign junk keybind",220,-180,function() ForeverAssistPlay.JunkBindingOptions() end)
    label(junk,'Hold Shift when opening a vendor to skip automatic selling.',2,-216,470)
    heading(junk,'Account inventory & movement',-260)
    Check(junk,"accountBags","Account bags, saved banks, gold & item counts",0,-289,function() ForeverAssistSystems.HookWindows() end)
    Check(junk,"moveBags","Enable movable bag handles",0,-322,applyPlay)
    Button(junk,"Browse account bags",0,-369,function() opt:Hide();ForeverAssistSystems.ToggleInventory() end)
    Button(junk,"Reset bag positions",220,-369,function() ForeverAssistPlay.ResetBags() end)
    Check(junk,"fastLoot","Faster auto looting",0,-421,applyPlay)
    local recovery=section('recovery','ForeverAssistRecoveryOptions','Combat & recovery','Combat errors, mana, food, drink, and camp timers.')
    heading(recovery,'Combat',-70)
    Check(recovery,"quietErrors","Hide and mute common combat errors",0,-99,applyPlay)
    Check(recovery,"hideStanceBar","Hide stance / shapeshift bar",0,-132,applyPlay)
    Check(recovery,"fsr","Enable five-second mana-rule bar",0,-165)
    Slider(recovery,"fsrScale","Mana bar height",6,-216,.5,2,.1,AnchorFSR)
    heading(recovery,'Recovery',-244)
    Check(recovery,"nutritionTimers","Food, drink, bandage & Cannibalize timers",0,-273,applyPlay)
    Check(recovery,"campNotices","Camp notices, Sit button and welcome timer",0,-306,applyPlay)
    Button(recovery,"Move recovery timer",0,-348,function() ForeverAssistPlay.Options("nutrition") end)
    label(recovery,"Food and drink show their remaining time in the middle of the screen. Well Fed gives a ready notice. Bandaging and Cannibalize follow their channels and stop when interrupted.",2,-394,460)
    local progress=section('progress','ForeverAssistProgressOptions','Experience & travel','Your experience bar, recorded level times, and flight-path timer.')
    heading(progress,'Experience bar',-70)
    Check(progress,'xpDetails','Show custom experience bar',0,-103,function()ForeverAssistPlay.UpdateXP()end)
    Check(progress,'xpLocked','Lock experience bar position',0,-136)
    heading(progress,'Level times',-193)
    Check(progress,'levelTimes','Show recorded level times',0,-226,function()ForeverAssistLevels.Apply()end)
    label(progress,'Only recorded levels appear. Drag the window to move it, or use Edit mode.',2,-268,470)
    heading(progress,'Flight paths',-331)
    Check(progress,'flightTimer','Show flight-path timer',0,-364)
    label(progress,'The first trip records the route duration. Later trips show an estimated countdown.',2,-408,470)
    local professions=section('professions','ForeverAssistProfessionOptions','Professions & prices','Profession catalogue, recipe profit, and auction-price sources.')
    heading(professions,'Profession window',-70)
    Check(professions,'professionBook','Show profession catalogue',0,-103,function()ForeverAssistSystems.ProfessionOptionChanged()end)
    Check(professions,'craftProfit','Show crafting profit and recipe-list estimates',0,-136,function()ForeverAssistEconomy.Refresh()end)
    Button(professions,'Prices & profit settings',0,-194,ForeverAssistEconomy.Options)
    label(professions,'Choose Auctionator, TSM, or remembered auction prices. Configure fees and price age in Prices & profit settings.',2,-237,470)
    heading(professions,'Gathering',-317)
    Button(professions,'Herb & ore display',0,-353,ForeverAssistGathering.Options)
    label(professions,'Round minimap icons, skill warnings, and world sparkles for gathering nodes.',2,-396,470)
    local display=section('display','ForeverAssistDisplayOptions','Minimap, sound & camera','Map shape, addon launchers, audio output, and camera zoom.')
    heading(display,'Minimap',-70)
    Check(display,"minimapMenu","Reveal addon icons on minimap right-click",0,-99,applyPlay)
    Check(display,"squareMinimap","Use a square minimap",0,-132,applyPlay)
    local gathering=Button(display,'Gathering display',220,-132,ForeverAssistGathering.Options);gathering:SetSize(240,24)
    heading(display,'Audio',-166)
    Check(display,"audioFollowSystem","Follow Windows audio output",0,-199,function() ForeverAssistAudio.ApplySettings() end)
    Button(display,"Refresh audio",300,-199,function() ForeverAssistAudio.Refresh() end)
    label(display,'Audio follows System Default and briefly restarts sound when your output device changes.',2,-248,470)
    heading(display,'Camera',-321)
    label(display,'Extended zoom is applied on login. Use the mouse wheel to zoom out. To set another limit, use /tb camera NUMBER (0–100).',2,-364,470)
    local buffOpt=CreateFrame("Frame","ForeverAssistBuffOptions",UIParent,"BackdropTemplate")
    buffOpt:SetSize(410,640);buffOpt:SetPoint("CENTER");buffOpt:SetFrameStrata("DIALOG");buffOpt:SetClampedToScreen(true)
    buffOpt:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/Tooltips/UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}});buffOpt:SetBackdropColor(.04,.04,.07,.96)
    buffOpt:SetMovable(true);buffOpt:EnableMouse(true);buffOpt:RegisterForDrag("LeftButton");buffOpt:SetScript("OnDragStart",buffOpt.StartMoving);buffOpt:SetScript("OnDragStop",buffOpt.StopMovingOrSizing)
    local closeBuff=CreateFrame("Button",nil,buffOpt,"UIPanelCloseButton");closeBuff:SetPoint("TOPRIGHT",-2,-2);closeBuff.faEditorClose=true
    tinsert(UISpecialFrames,"ForeverAssistBuffOptions")
    Header(buffOpt, "Buff reminders", 20, -42)
    Check(buffOpt, "buffs", "Enable buff reminders", 20, -58, UpdateReminder)
    Check(buffOpt, "buffsHideCombat", "Hide in combat", 20, -82, UpdateReminder)
    Check(buffOpt, "buffsHideMounted", "Hide while mounted / on taxi", 20, -106, UpdateReminder)
    Check(buffOpt,"petReminder","Missing hunter / warlock pet",20,-130,UpdateReminder)
    Check(buffOpt,"sleepingBagReminder","Cozy Sleeping Bag reminder",20,-154,UpdateReminder)
    Slider(buffOpt, "buffSize", "Icon size", 26, -206, 24, 96, 2, UpdateReminder)
    Slider(buffOpt, "buffTextSize", "Text size", 26, -250, 8, 12, 1, UpdateReminder)
    Slider(buffOpt, "buffX", "Position X", 26, -294, -1000, 1000, 5, AnchorReminder)
    Slider(buffOpt, "buffY", "Position Y", 26, -338, -600, 600, 5, AnchorReminder)
    unlockButton = Button(buffOpt, "Unlock & move reminder", 26, -376, function() SetUnlocked(not unlocked) end)
    Button(buffOpt, "Reset position & size", 26, -406, function()
        DB.buffX, DB.buffY, DB.buffSize, DB.buffTextSize =
            defaults.buffX, defaults.buffY, defaults.buffSize, defaults.buffTextSize
        AnchorReminder()
        UpdateReminder()
        optionsRefresh()
    end)

    Check(buffOpt,"gathering","Gathering tracking reminders",20,-442,UpdateReminder)
    local note=buffOpt:CreateFontString(nil,"OVERLAY","TrailboundSmall");note:SetPoint("TOPLEFT",22,-485);note:SetWidth(350);note:SetJustifyH("LEFT");note:SetText("Hidden in capital cities. Click buff / tracking icons to cast on yourself. Combat keeps the last safe set until combat ends. Hover for full names. Pet reminders respect petless talents. Sleeping-bag reminders require the item ready to use outdoors. Paladin blessings are automatic.")
    buffOpt:SetScript("OnShow",function() optionsRefresh() end)
    buffOpt:SetScript("OnHide",function() if unlocked then SetUnlocked(false) end end)
    local backBuff=Button(buffOpt,"Back to settings",22,-554,function() buffOpt:Hide();opt:Show() end)
    backBuff:ClearAllPoints();backBuff:SetPoint("BOTTOMLEFT",22,12)
    buffOpt:Hide()

    local function select(key)
        selected=key;opt.selectedCategory=key
        footer:SetText('Trailbound / '..sections[key].journalTitle..'     •     Changes save as you go')
        for name,page in pairs(sections) do page:SetShown(name==key) end
        for _,entry in ipairs(nav) do
            local active=entry.key==key
            entry.bg:SetColorTexture(active and .24 or .075,active and .16 or .05,active and .07 or .03,1)
            entry.mark:SetShown(active)
        end
        optionsRefresh()
    end
    local function navigation(key,title,y,action,keywords)
        local b=CreateFrame("Button",nil,opt);b:SetSize(174,34);b:SetPoint("TOPLEFT",10,y);b.navLabel=title;b.key=key
        b.bg=tint(b,0,0,174,34,.075,.05,.03);b.mark=tint(b,0,0,3,34,.85,.64,.26);b.mark:Hide()
        b.originalY=y;b.searchText=(title..' '..(keywords or '')):lower()
        label(b,title,20,-10,148)
        b:SetScript("OnClick",function()
            if action then action();footer:SetText('Trailbound / '..title..'     •     Changes save as you go')
                for _,entry in ipairs(nav)do entry.mark:SetShown(entry==b);entry.bg:SetColorTexture(entry==b and .24 or .075,entry==b and .16 or .05,entry==b and .07 or .03,1)end
            else if activeEditor then activeEditor:Hide() end;select(key) end
        end)
        b:SetScript("OnEnter",function(self) if self.key~=selected then self.bg:SetColorTexture(.18,.12,.06,1) end end)
        b:SetScript("OnLeave",function(self) if self.key~=selected then self.bg:SetColorTexture(.075,.05,.03,1) end end)
        nav[#nav+1]=b
    end
    local function groupHeading(title,y)
        tint(opt,14,y+7,164,1,.38,.27,.14)
        local t=label(opt,title,18,y,164,"TrailboundHeading")
        t:SetFont(STANDARD_TEXT_FONT,10,"");t:SetTextColor(.73,.58,.34)
        if t.EnableMouse then t:EnableMouse(false) end
        return t
    end
    local finder=CreateFrame('EditBox',nil,opt,'InputBoxTemplate');finder:SetSize(154,24);finder:SetPoint('TOPLEFT',24,-82);finder:SetAutoFocus(false);opt.finder=finder
    label(opt,'Find a setting',24,-112,155)
    opt.preferencesHeading=groupHeading('SETTINGS',-146)
    navigation('general','Quests & training',-166,nil,'quest spellbook auto accept turn in highlight')
    navigation('inventory','Bags & vendors',-200,nil,'bank gold inventory junk loot')
    navigation('recovery','Combat & recovery',-234,nil,'food drink mana errors stance camp')
    navigation('progress','Experience & travel',-268,nil,'xp levels played flight leveling')
    navigation('professions','Professions & prices',-302,nil,'crafting profit auction ah materials tsm auctionator herbs ore gathering nodes sparkle')
    navigation('display','Minimap & sound',-336,nil,'display camera audio map launchers')
    opt.editorsHeading=groupHeading('DISPLAYS & CONTROLS',-390)
    navigation(nil,'Buff & pet reminders',-411,function() ForeverAssistShowEditor(buffOpt) end,'sleeping bag tracking')
    navigation(nil,'External buff notices',-445,ForeverAssistExternals.Options,'power infusion')
    navigation(nil,'Swing timer',-479,function() ForeverAssistPlay.Options('swing') end,'weapon appearance')
    navigation(nil,'Action rings & keys',-513,ForeverAssistPlay.RingEditor,'keybind macro')
    navigation(nil,'Chat appearance',-547,ForeverAssistChat.Options,'url copy icons channel font')
    navigation(nil,'Settings profiles',-581,ForeverAssistExtras.ToggleProfiles,'account character')
    local noResults=label(opt,'No matching section.',22,-180,160);noResults:Hide();opt.noResults=noResults
    finder:SetScript('OnTextChanged',function(self)
        local query=(self:GetText()or ''):lower():match('^%s*(.-)%s*$');local count=0
        opt.preferencesHeading:SetShown(query=='');opt.editorsHeading:SetShown(query=='')
        for _,entry in ipairs(nav)do
            local show=query==''or entry.searchText:find(query,1,true)~=nil
            entry:SetShown(show);entry:ClearAllPoints();entry:SetPoint('TOPLEFT',10,query==''and entry.originalY or -150-count*36)
            if show then count=count+1 end
        end
        noResults:SetShown(count==0)
    end)
    finder:SetScript('OnEscapePressed',function(self)self:SetText('');self:ClearFocus()end)
    opt:SetScript("OnShow",function()
        ForeverAssistPlay.CloseOptions();buffOpt:Hide()
        if ForeverAssistImportantBuffOptions then ForeverAssistImportantBuffOptions:Hide() end
        if ForeverAssistBuffCatalogue then ForeverAssistBuffCatalogue:Hide() end
        select(selected)
    end)
    opt:Hide()
end

local function ToggleOptions()
    if not opt then return end
    opt:SetShown(not opt:IsShown())
end

local function RegisterBlizzardPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Trailbound"
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(200, 26)
    btn:SetPoint("TOPLEFT", 20, -20)
    btn:SetText("Open Trailbound settings")
    btn:SetScript("OnClick", function()
        if HideUIPanel and SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
        if opt then opt:Show() end
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(cat)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- Default settings are shared; named profiles remain explicit snapshots.
local function ApplyLoadedSettings(settings)
    DB = settings
    if not DB.sellJunk then ForeverAssistExtras.CancelAutomaticSale() end
    for k,v in pairs(defaults) do if DB[k] == nil then DB[k] = v end end
    AnchorFSR()
    AnchorReminder()
    UpdateReminder()
    SetBookShown()
    ForeverAssistSystems.HookWindows()
    if ForeverAssistPlay then ForeverAssistPlay.ApplySettings() end
    if ForeverAssistAudio then ForeverAssistAudio.ApplySettings() end
    if ForeverAssistGathering then ForeverAssistGathering.ApplySettings() end
    if ForeverAssistLevels then ForeverAssistLevels.Apply() end
    if optionsRefresh then optionsRefresh() end
end

--------------------------------------------------------------------
-- Events
--------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 ~= "Trailbound" then
            if DB then CreateBook() end
            return
        end
        TrailboundPrepareMigration()
        ForeverAssistDB = ForeverAssistDB or {}
        characterDB = ForeverAssistDB
        ForeverAssistAccountDB = ForeverAssistAccountDB or {}
        local account = ForeverAssistAccountDB
        DB = ForeverAssistExtras.Initialize(account, characterDB, defaults)
        ForeverAssistExtras.Configure(function() return DB end, ApplyLoadedSettings)
        if DB.quests ~= nil then -- migrate from 1.0
            DB.acceptQuests, DB.turnInQuests = DB.quests, DB.quests
            DB.quests = nil
        end
        for k, v in pairs(defaults) do if DB[k] == nil then DB[k] = v end end
        characterDB.trainer = characterDB.trainer or {}
        ForeverAssistGoldDB = ForeverAssistGoldDB or {}
        ForeverAssistSystems.Initialize(account, characterDB, function() return DB end, ForeverAssistGoldDB)
        ForeverAssistGoldDB = account.goldLedger
        ForeverAssistPlay.Initialize(account, characterDB, function() return DB end)
        ForeverAssistBuffTracker.Suspend()
        ForeverAssistExternals.Initialize(function() return DB end)
        ForeverAssistLayout.Initialize(function() return DB end)
        ForeverAssistFlight.Initialize(account,characterDB,function()return DB end)
        ForeverAssistChat.Initialize(function()return DB end)
        ForeverAssistEconomy.Initialize(account,function()return DB end)
        ForeverAssistGathering.Initialize(characterDB,function()return DB end)
        ForeverAssistLevels.Initialize(characterDB,function()return DB end)
        ForeverAssistAudio.Initialize(function() return DB end)
        ForeverAssistWindows.Initialize(characterDB)
        for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL",
            "QUEST_PROGRESS", "QUEST_COMPLETE", "UNIT_SPELLCAST_SUCCEEDED", "TRAINER_SHOW",
            "TRAINER_UPDATE", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "MERCHANT_SHOW",
            "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UNIT_AURA", "UNIT_PET", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
            pcall(self.RegisterEvent, self, e)
        end
    elseif event == "PLAYER_LOGIN" then
        CreateBook()
        AnchorFSR()
        CreateReminder()
        CreateOptions()
        RegisterBlizzardPanel()
        BuildBuffGroups()
        ForeverAssistExtras.DefaultLogin()
        ForeverAssistAudio.ApplySettings()
        ForeverAssistSystems.Camera("4",false)
    elseif event == "UNIT_AURA" or event == "UNIT_PET" then
        if arg1=="player" then UpdateReminder() end
    elseif event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then UpdateReminder()
    elseif event == "PLAYER_LOGOUT" then ForeverAssistExtras.DefaultLogout()
    elseif event == "PLAYER_ENTERING_WORLD" then
        AnchorFSR()
        CreateBook()
        UpdateReminder()
    elseif event == "PLAYER_REGEN_ENABLED" then
        AnchorFSR()
        UpdateReminder()
    elseif event == "GOSSIP_SHOW" then
        HandleGossip()
    elseif event == "QUEST_GREETING" then
        HandleQuestGreeting()
    elseif event == "QUEST_DETAIL" then
        if DB.acceptQuests and not IsShiftKeyDown() then AcceptQuest() end
    elseif event == "QUEST_PROGRESS" then
        if DB.turnInQuests and not IsShiftKeyDown() and IsQuestCompletable() then CompleteQuest() end
    elseif event == "QUEST_COMPLETE" then
        HandleQuestComplete()
    elseif event == "MERCHANT_SHOW" then
        SellJunk()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 == "player" and DB.fsr and CostsMana(arg3) then StartFSR() end
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        if event == "TRAINER_SHOW" and SetTrainerServiceTypeFilter then
            pcall(SetTrainerServiceTypeFilter, "available", 1)
            pcall(SetTrainerServiceTypeFilter, "unavailable", 1)
            pcall(SetTrainerServiceTypeFilter, "used", 1)
        end
        ScanTrainer()
        ForeverAssistSystems.RefreshProfessions()
        RefreshBook()
    else -- level up / spells changed
        if event == "SPELLS_CHANGED" and DB then BuildBuffGroups() end
        RefreshBook()
    end
end)

-- reminder refresh ticker
local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc >= 0.5 then
        acc = 0
        if DB and rem then UpdateReminder() end
    end
end)

--------------------------------------------------------------------
-- Slash commands: /tb and /trailbound
--------------------------------------------------------------------
local function Toggle(key, label, after)
    DB[key] = not DB[key]
    Print(label .. ": " .. (DB[key] and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    if after then after() end
    if optionsRefresh then optionsRefresh() end
end

SLASH_FOREVERASSIST1, SLASH_FOREVERASSIST2 = "/tb", "/trailbound"
SlashCmdList["FOREVERASSIST"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "camera" or msg:match("^camera%s+") then
        local value = msg:match("^camera%s+(.-)%s*$") or "4"
        ForeverAssistSystems.Camera(value, true)
        return
    end
    if msg == "version" then Print("Version 1.8.46 | Gameplay "..tostring(ForeverAssistPlay.Version or "old/unversioned").." | Buff rules "..tostring(ForeverAssistBuffRulesVersion or "old/unversioned").." | Bags "..tostring(ForeverAssistSystems.Version or "old/unversioned"))
    elseif msg == "edit" then ForeverAssistLayout.Set(not ForeverAssistLayout.active)
    elseif msg == "gold" then ForeverAssistSystems.GoldReport()
    elseif msg == "audiodebug" then ForeverAssistAudio.Debug()
    elseif msg == "audio" then ForeverAssistAudio.Refresh()
    elseif msg == "xpdebug" then ForeverAssistPlay.XPDebug()
    elseif msg == "bank" then ForeverAssistBank.Toggle()
    elseif msg == 'rings' then ForeverAssistPlay.RingEditor()
    elseif msg == "" or msg == "options" or msg == "config" then ToggleOptions()
    elseif msg == "vendor" then Toggle("gossipVendor", "Auto vendor")
    elseif msg == "trainer" then Toggle("gossipTrainer", "Auto trainer")
    elseif msg == "quests" then
        Toggle("acceptQuests", "Auto-accept quests")
        DB.turnInQuests = DB.acceptQuests
    elseif msg == "sell" then Toggle("sellJunk", "Auto-sell junk", function()
        if not DB.sellJunk then ForeverAssistExtras.CancelAutomaticSale() end
    end)
    elseif msg == "fsr" then Toggle("fsr", "5-second bar")
    elseif msg == "buffs" then Toggle("buffs", "Buff reminders", UpdateReminder)
    elseif msg == "sparkle" then Toggle("sparkle", "Quest object highlight", function() ApplySparkle(true) end)
    elseif msg == "book" then Toggle("book", "Spellbook panel", SetBookShown)
    elseif msg == "profile" or msg == "profiles" then
        ForeverAssistExtras.ToggleProfiles()
    elseif msg == "junk" then ForeverAssistExtras.ToggleJunk()
    elseif msg == "nodes" then ForeverAssistGathering.Debug()
    elseif msg == "levels" then Toggle('levelTimes','Level-times window',function()ForeverAssistLevels.Apply()end)
    elseif msg == "bags" then ForeverAssistSystems.ToggleInventory()
    elseif msg == "professions" then ForeverAssistSystems.ToggleProfessions()
    elseif msg == "debug" then
        for _, o in ipairs((C_GossipInfo and C_GossipInfo.GetOptions()) or {}) do
            Print(("option '%s' type=%s icon=%s"):format(tostring(o.name), tostring(o.type), tostring(o.icon)))
        end
    else
        Print("/tb (settings window) | vendor | trainer | quests | sell | fsr | buffs | sparkle | book | profiles | bags | professions | camera [max/number] | debug")
    end
end
-- Add a shortcut only when another addon or the client has not claimed it.
local function ShortCommand(command,key,callback)
    for name,value in pairs(_G)do if type(name)=='string' and name:match('^SLASH_') and type(value)=='string' and (not issecretvalue or not issecretvalue(value)) and value==command then return end end
    _G['SLASH_'..key..'1']=command;SlashCmdList[key]=callback
end
ShortCommand('/rl','FOREVERASSISTRELOAD',function()if C_UI and C_UI.Reload then C_UI.Reload()elseif ReloadUI then ReloadUI()end end)
ShortCommand('/tbo','TRAILBOUNDOPEN',ToggleOptions)
ShortCommand('/tbedit','TRAILBOUNDEDIT',function()ForeverAssistLayout.Set(not ForeverAssistLayout.active)end)
