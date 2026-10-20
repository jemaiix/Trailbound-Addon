-- Gathering, account inventory, separated training, professions and camera.
ForeverAssistSystems = {Version="1.8.54"}
local S = ForeverAssistSystems
local account, character, getSettings, currentKey
local moneyReadyAt=0
local moneySessionEnding=false
local professionSkillIDs = {}
local function Print(text) print("|cffd2b077Trailbound:|r "..text) end
local function Known(id)
    local fn = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell or IsSpellKnown
    if not fn then return false end
    local ok, value = pcall(fn,id)
    return ok and value == true
end
local function SpellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info=pcall(C_Spell.GetSpellInfo,id)
        if ok and info then return info.name,info.iconID end
    elseif GetSpellInfo then local name,_,icon=GetSpellInfo(id);return name,icon end
end
function S.LearnedProfessions()
    local result={}
    if GetProfessions and GetProfessionInfo then
        local indices={GetProfessions()}
        for i=1,6 do
            local index=indices[i]
            if index then
                local ok,name,icon,rank,maxRank,_,_,id=pcall(GetProfessionInfo,index)
                if ok and name and id then result[id]={id=id,name=name,icon=icon,rank=rank or 0,maxRank=maxRank or 0} end
            end
        end
    end
    if not GetProfessions or not GetProfessionInfo then
        for id, spells in pairs(professionSkillIDs) do
            for _,spell in ipairs(spells) do
                if Known(spell) then
                    result[id]={id=id,name=ForeverAssistProfessionData[id].name,rank=0}
                    break
                end
            end
        end
    end
    if Known(2580) and not result[186] then result[186]={id=186,name="Mining",rank=0} end
    if Known(2383) and not result[182] then result[182]={id=182,name="Herbalism",rank=0} end
    return result
end
function S.GatheringReminders()
    if not getSettings or not getSettings().gathering then return {} end
    local learned=S.LearnedProfessions()
    local reminders={}
    for _,spec in ipairs({{profession=186,spell=2580,name="Find Minerals",icon=136025},{profession=182,spell=2383,name="Find Herbs",icon=133939}}) do
        if learned[spec.profession] then
            local name,icon=SpellInfo(spec.spell)
            name,icon=name or spec.name,icon or spec.icon
            local active=false
            local num=C_Minimap and C_Minimap.GetNumTrackingTypes or GetNumTrackingTypes
            local info=C_Minimap and C_Minimap.GetTrackingInfo or GetTrackingInfo
            if num and info then
                local ok,count=pcall(num)
                if ok and type(count)=="number" then
                    for i=1,count do
                        local got,value,texture,enabled=pcall(info,i)
                        if got then
                            if type(value)=="table" then
                                if value.spellID==spec.spell or value.name==name or value.texture==icon then active=value.active==true or value.active==1 end
                            elseif value==name or texture==icon then active=enabled==true or enabled==1 end
                        end
                    end
                end
            else
                -- Older clients can expose the tracking spell as an aura.
                for i=1,40 do
                    local aura,readable=ForeverAssistReadPlayerAura(i)
                    if not readable then active=true;break end
                    if not aura then break end
                    if aura.spellId==spec.spell or aura.name==name then active=true end
                end
            end
            if not active then reminders[#reminders+1]={label=name,icon=icon,spell=name} end
        end
    end
    return reminders
end

function S.NormalizeRank(rank)
    if type(rank) ~= "string" then return "" end
    rank = rank:match("^%s*(.-)%s*$")
    return rank == "r" and "" or rank
end
local classNames, professionNames, ridingNames={},{},{}
local function BuildTrainingNames()
    local _,class=UnitClass("player")
    for _,spell in ipairs(ForeverAssistSpellData[class] or {}) do
        classNames[spell.name]=true
        local localized=SpellInfo(spell.spellID)
        if localized then classNames[localized]=true end
    end
    for id,profession in pairs(ForeverAssistProfessionData or {}) do
        professionNames[profession.name]=id
        professionSkillIDs[id] = {}
        for _,spell in ipairs(profession.records) do
            if spell.kind == "training" then professionSkillIDs[id][#professionSkillIDs[id]+1] = spell.spellID end
            professionNames[spell.name]=id
            local localized=SpellInfo(spell.spellID)
            if localized then professionNames[localized]=id end
        end
    end
    for _,id in ipairs({33388,33391,34090,34091,90265}) do local name=SpellInfo(id);if name then ridingNames[name]=true end end
    for id,profession in pairs(S.LearnedProfessions()) do professionNames[profession.name]=id end
end
function S.TrainingCategory(name,index,isProfession)
    if classNames[name] then return "class" end
    if ridingNames[name] or name:lower():find("riding",1,true) or name:lower():find("rider",1,true) then return "riding" end
    local id=professionNames[name]
    if not id and index then
        for _,fn in ipairs({GetTrainerServiceSkillLine or false,GetTrainerServiceSkillReq or false}) do
            if fn then local ok,skill=pcall(fn,index);if ok then id=professionNames[skill];if id then break end end end
        end
    end
    if id then return "profession",id end
    return isProfession and "professionUnknown" or "other"
end
function S.StoreTraining(key,record,index,isProfession,used)
    if index and GetTrainerServiceSkillReq then
        local ok,name,rank,met=pcall(GetTrainerServiceSkillReq,index)
        if ok and (not issecretvalue or not issecretvalue(rank)and not issecretvalue(name))and type(name)=='string'and type(rank)=='number'and rank>=0 then
            record.requiredSkill=rank;record.requiredSkillName=name;record.skillMetAtScan=met
        end
    end
    local kind,id=S.TrainingCategory(record.name,index,isProfession)
    local target
    if kind=="class" then record.observedClassTrainer=index~=nil or record.observedClassTrainer;target=character.trainer
    elseif kind=="riding" then target=character.ridingTraining
    elseif kind=="profession" then
        character.professionTraining[id]=character.professionTraining[id] or {}
        target=character.professionTraining[id]
    else target=character.otherTraining end
    if used then target[key]=nil else record.group=kind;record.professionID=id;target[key]=record end
end
local function InventoryTime(r) return r and (r.bagsUpdatedAt or r.updatedAt or 0) or 0 end
local function HasBags(r) return r and next(r.bags or {})~=nil end
local function RestoreInventory(key,backup)
    if type(backup)~="table" or not backup.name or not backup.realm then return end
    local r=account.characters[key]
    if not r then r=ForeverAssistExtras.Copy(backup);account.characters[key]=r
    elseif HasBags(backup) and (not HasBags(r) or InventoryTime(backup)>InventoryTime(r)) then
        for _,field in ipairs({"bags","bagSizes","bagNames","items","bagsUpdatedAt"}) do r[field]=ForeverAssistExtras.Copy(backup[field]) end
        r.name,r.realm=backup.name,backup.realm
    end
    local ledger=account.goldLedger[key]
    local stamp=backup.moneyUpdatedAt or backup.updatedAt or 0
    if type(backup.money)=="number" and (not ledger or stamp>(ledger.updatedAt or 0)) then
        account.goldLedger[key]={money=backup.money,name=backup.name,realm=backup.realm,updatedAt=stamp}
    end
end
local function BackUpInventory(key,record)
    account.characterBackups[key]=ForeverAssistExtras.Copy(record)
    character.inventorySnapshot=ForeverAssistExtras.Copy(record)
end
local function ResolveCharacterKey(name,realm)
    local guid=UnitGUID and UnitGUID("player")
    local fallback=realm..":"..name
    -- During loading, keep using the saved GUID instead of moving it to a temporary key.
    if not guid then
        for key,r in pairs(account.characters) do if r.name==name and r.realm==realm then return key end end
        return fallback
    end
    if guid~=fallback and account.characters[fallback] then
        RestoreInventory(guid,account.characters[fallback])
        local old=account.goldLedger[fallback];local ledger=account.goldLedger[guid]
        if old and (not ledger or (old.updatedAt or 0)>(ledger.updatedAt or 0)) then account.goldLedger[guid]=ForeverAssistExtras.Copy(old) end
        if account.characterBackups[fallback] then RestoreInventory(guid,account.characterBackups[fallback]) end
        account.characterBackups[guid]=ForeverAssistExtras.Copy(account.characters[guid])
        account.characters[fallback]=nil;account.goldLedger[fallback]=nil;account.characterBackups[fallback]=nil
    end
    return guid
end
function S.Initialize(a,c,get,goldBackup)
    account,character,getSettings=a,c,get
    ForeverAssistBank.Initialize(a,c)
    currentKey=nil;moneyReadyAt=(GetTime and GetTime() or 0)+3
    moneySessionEnding=false
    account.characters=account.characters or {}
    account.goldLedger=account.goldLedger or {}
    account.characterBackups=account.characterBackups or {}
    -- A separate account SavedVariable survives damage/reset of the main DB.
    for key,r in pairs(goldBackup or {}) do
        local saved=account.goldLedger[key]
        if type(r)=="table" and type(r.money)=="number" and r.name and r.realm and
            (not saved or (r.updatedAt or 0)>(saved.updatedAt or 0)) then
            account.goldLedger[key]=ForeverAssistExtras.Copy(r)
        end
    end
    for key,r in pairs(account.characterBackups) do RestoreInventory(key,r) end
    for key,r in pairs(account.characters) do RestoreInventory(key,r) end
    if character.inventorySnapshot then
        local r=character.inventorySnapshot;local key=(UnitGUID and UnitGUID("player")) or r.realm..":"..r.name
        RestoreInventory(key,r)
    end
    local name=UnitName('player');local realm=GetRealmName and GetRealmName() or 'Realm'
    local ownKey=ResolveCharacterKey(name,realm)
    local own=character.goldSnapshot
    if own and own.name==name and own.realm==realm then
        RestoreInventory(ownKey,{name=name,realm=realm,money=own.money,moneyUpdatedAt=own.updatedAt})
    elseif type(character.lastMoney)=="number" and not account.goldLedger[ownKey] then
        RestoreInventory(ownKey,{name=name,realm=realm,money=character.lastMoney,moneyUpdatedAt=0})
    end
    -- Restore labels too, so recovered offline gold appears in every viewer.
    for key,r in pairs(account.goldLedger) do
        if not account.characters[key] and r.name and r.realm then
            account.characters[key]={name=r.name,realm=r.realm,money=r.money,moneyUpdatedAt=r.updatedAt,items={},bags={}}
        end
    end
    -- Seed independent backups for existing offline records when upgrading.
    for key,r in pairs(account.characters) do
        if not account.characterBackups[key] then account.characterBackups[key]=ForeverAssistExtras.Copy(r) end
    end
    character.trainer=character.trainer or {}
    character.ridingTraining=character.ridingTraining or {}
    character.professionTraining=character.professionTraining or {}
    character.otherTraining=character.otherTraining or {}
    character.knownRecipes=character.knownRecipes or {}
    BuildTrainingNames()
    local oldTraining = character.trainer
    character.trainer = {}
    for _,record in pairs(oldTraining) do
        record.rank = S.NormalizeRank(record.rank)
        S.StoreTraining(record.name .. "|" .. record.rank, record)
    end
end

local function CharacterKey()
    return ResolveCharacterKey(UnitName("player"),(GetRealmName and GetRealmName() or "Realm"))
end
local function Label(record) return record.name.." - "..record.realm end
function S.ReadMoney()
    if not GetMoney then return nil,"GetMoney is unavailable" end
    local ok,value=pcall(GetMoney)
    if not ok then return nil,"GetMoney failed" end
    if issecretvalue and issecretvalue(value) then return nil,"Money is restricted" end
    local amount=tonumber(value)
    if not amount or amount<0 then return nil,"GetMoney returned "..type(value) end
    return math.floor(amount),"GetMoney returned "..type(value)
end
function S.RecordMoney(force)
    if not account or moneySessionEnding then return end
    local name=UnitName('player');if not name or name=='Unknown' then return end
    local key=CharacterKey();local money=S.ReadMoney();if money==nil then return end
    local record=account.characters[key] or {items={},bags={}}
    local ledger=account.goldLedger[key]
    local saved=ledger and ledger.money or record.money or 0
    -- Character loading can briefly report zero before the real balance arrives.
    if money==0 and saved>0 and (GetTime()<moneyReadyAt or not force) then return end
    local changed=saved~=money or not ledger
    record.name,record.realm=name,GetRealmName and GetRealmName() or 'Realm'
    record.mailName=ForeverAssistFullMailName('player') or record.mailName
    record.money=money;record.moneyUpdatedAt=changed and time() or ledger.updatedAt
    account.characters[key]=record
    ledger=ledger or {};ledger.money,ledger.name,ledger.realm,ledger.updatedAt=money,record.name,record.realm,record.moneyUpdatedAt
    account.goldLedger[key]=ledger
    local backup=account.characterBackups[key]
    if not backup then backup={name=record.name,realm=record.realm,items={},bags={}};account.characterBackups[key]=backup end
    backup.money=money;backup.moneyUpdatedAt=record.moneyUpdatedAt
    if character.inventorySnapshot then character.inventorySnapshot.money=money;character.inventorySnapshot.moneyUpdatedAt=record.moneyUpdatedAt end
    local own=character.goldSnapshot or {};character.goldSnapshot=own
    own.money,own.name,own.realm,own.updatedAt=money,record.name,record.realm,record.moneyUpdatedAt
    character.lastMoney=money;currentKey=key
    if changed then if S.RefreshGoldDisplays then S.RefreshGoldDisplays() end;if S.RefreshInventory then S.RefreshInventory() end end
end
function S.Snapshot()
    if not account or moneySessionEnding then return false end
    local name=UnitName('player');if not name or name=='Unknown' then return false end
    currentKey=CharacterKey()
    local realm=GetRealmName and GetRealmName() or 'Realm'
    -- Money is saved separately even when bags are still loading.
    S.RecordMoney()
    local old=account.characters[currentKey] or {name=name,realm=realm,items={},bags={}}
    if HasBags(old) and GetTime()<moneyReadyAt then return false end
    local record={}
    -- Build fresh containers without copying the old bags that are about to be replaced.
    for k,v in pairs(old) do if k~="bags" and k~="bagSizes" and k~="bagNames" and k~="items" then record[k]=v end end
    record.name,record.realm=name,realm
    record.mailName=ForeverAssistFullMailName('player') or record.mailName
    record.money=S.CharacterGold(currentKey,old)
    record.bags={};record.bagSizes={};record.bagNames={}
    local slots=C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local modern=C_Container and C_Container.GetContainerItemInfo
    if not slots or not (modern or GetContainerItemInfo) then return false end
    local ready,n=pcall(slots,0)
    if not ready or type(n)~="number" or n<=0 then return false end
    local function EquippedBag(bag)
        -- If available, distinguish a bag that was removed from one still loading.
        if not ContainerIDToInventoryID or not GetInventoryItemID then return nil end
        local ok,slot=pcall(ContainerIDToInventoryID,bag);if not ok or not slot then return nil end
        local got,id=pcall(GetInventoryItemID,"player",slot);if not got then return nil end
        return id~=nil
    end
    for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        local ok,count=pcall(slots,bag)
        if not ok or type(count)~='number' or count<0 then return false end
        if count==0 and (old.bagSizes and old.bagSizes[bag] or 0)>0 and EquippedBag(bag)~=false then return false end
        local contents={};record.bagSizes[bag]=count
        local getName=C_Container and C_Container.GetBagName or GetBagName
        if getName then local got,value=pcall(getName,bag);if got then record.bagNames[bag]=value end end
        for slot=1,count do
            local item
            if modern then
                local got,info=pcall(modern,bag,slot);if not got then return false end;item=info
            else
                local got,icon,quantity,_,quality,_,_,link,_,_,id=pcall(GetContainerItemInfo,bag,slot)
                if not got then return false end
                if icon then item={itemID=id,stackCount=quantity,hyperlink=link,iconFileID=icon,quality=quality} end
            end
            if item then
                local id=item.itemID or item.hyperlink and tonumber(item.hyperlink:match('item:(%d+)'))
                if not id and C_Container and C_Container.GetContainerItemID then
                    local got,value=pcall(C_Container.GetContainerItemID,bag,slot);if got then id=value end
                end
                if not id then return false end
                contents[slot]={id=id,count=item.stackCount or 1,link=item.hyperlink,icon=item.iconFileID,quality=item.quality}
            end
        end
        record.bags[bag]=contents
    end
    record.items={}
    for _,contents in pairs(record.bags) do for _,item in pairs(contents) do record.items[item.id]=(record.items[item.id] or 0)+item.count end end
    record.updatedAt=time();record.bagsUpdatedAt=record.updatedAt
    account.characters[currentKey]=record
    BackUpInventory(currentKey,record)
    if S.RefreshGoldDisplays then S.RefreshGoldDisplays() end
    return true
end
function S.CharacterGold(key,record)
    local saved=account.goldLedger and account.goldLedger[key]
    if record and type(record.money)=='number' and (not saved or (record.moneyUpdatedAt or record.updatedAt or 0)>(saved.updatedAt or 0)) then return record.money end
    return saved and tonumber(saved.money) or record and tonumber(record.money) or 0
end
function S.GoldReport()
    S.RecordMoney()
    local live,status=S.ReadMoney();local list={}
    for key,record in pairs(account.characters) do list[#list+1]={key=key,record=record} end
    table.sort(list,function(a,b)return Label(a.record)<Label(b.record) end)
    Print("Gold diagnostics • "..S.Version.." • "..status.." • live "..(live and (ForeverAssistMoney(live).." ["..live.." copper]") or "unavailable"))
    Print("Saved characters: "..#list.." • Account total: "..ForeverAssistMoney(S.AccountGold()).." • Account bags "..(getSettings().accountBags and "enabled" or "disabled"))
    for _,entry in ipairs(list) do
        local ledger=account.goldLedger[entry.key]
        Print(Label(entry.record)..": "..ForeverAssistMoney(S.CharacterGold(entry.key,entry.record)).." • saved copper "..tostring(entry.record.money).." • ledger copper "..(ledger and tostring(ledger.money) or "missing"))
    end
end
function S.AccountGold()
    local total,seen=0,{}
    for key,record in pairs(account.characters) do total=total+S.CharacterGold(key,record);seen[key]=true end
    for key,record in pairs(account.goldLedger or {}) do if not seen[key] then total=total+(record.money or 0) end end
    return total
end
function S.ItemCounts(id)
    local list,total={},0
    for key,record in pairs(account.characters) do
        local count=record.items and record.items[id] or 0
        if count>0 then list[#list+1]={key=key,name=Label(record),count=count};total=total+count end
    end
    table.sort(list,function(a,b)return a.name<b.name end)
    return list,total
end
function S.ItemTooltip(tooltip,id)
    if not account or not getSettings().accountBags or not id or id==6948 or id==2901 or id==7005 or id==5956 then return end
    if tooltip.faInventoryItem==id then return end
    tooltip.faInventoryItem=id
    local list,total=S.ItemCounts(id)
    if #list==0 then return end
    tooltip:AddLine(" ")
    tooltip:AddLine("Account bags (last recorded)",0.3,1,0.6)
    for _,entry in ipairs(list) do tooltip:AddDoubleLine(entry.name,tostring(entry.count),1,1,1,1,1,1) end
    tooltip:AddDoubleLine("Total in bags",tostring(total),0.3,1,0.6,0.3,1,0.6)
end
local tooltipInstalled=false
local function HookTooltips()
    if tooltipInstalled or not GameTooltip then return end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tooltip,data) S.ItemTooltip(tooltip,data and data.id) end)
        tooltipInstalled=true
    else
        local ok=pcall(GameTooltip.HookScript,GameTooltip,"OnTooltipSetItem",function(tooltip)
            local _,link=tooltip:GetItem()
            S.ItemTooltip(tooltip,link and tonumber(link:match("item:(%d+)")))
        end)
        tooltipInstalled=ok
    end
    pcall(GameTooltip.HookScript,GameTooltip,"OnTooltipCleared",function(self) self.faInventoryItem=nil end)
    GameTooltip:HookScript("OnHide",function(self) self.faInventoryItem=nil end)
end
function S.GoldTooltip(owner)
    if not account or not getSettings().accountBags then return end
    GameTooltip:SetOwner(owner,"ANCHOR_TOP")
    if GameTooltip.ClearLines then GameTooltip:ClearLines() end
    GameTooltip:AddLine("Account gold",0.3,1,0.6)
    local list={}
    for key,record in pairs(account.characters) do list[#list+1]={key=key,record=record} end
    for key,record in pairs(account.goldLedger or {}) do if not account.characters[key] then list[#list+1]={key=key,record=record} end end
    table.sort(list,function(a,b)return Label(a.record)<Label(b.record) end)
    for _,entry in ipairs(list) do
        local amount=S.CharacterGold(entry.key,entry.record)
        GameTooltip:AddDoubleLine(Label(entry.record),ForeverAssistMoney(amount),1,1,1,1,1,1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Account total",ForeverAssistMoney(S.AccountGold()),0.3,1,0.6,1,1,1)
    GameTooltip:AddLine("Offline characters: last recorded money.",0.7,0.7,0.7)
    GameTooltip:Show()
end
local function HookMoney(frame)
    if not frame or type(frame)~="table" and type(frame)~="userdata" then return end
    if not frame.HookScript then return end
    if not frame.faGoldHook then
    frame.faGoldHook=true
    if frame.EnableMouse then frame:EnableMouse(true) end
    frame:HookScript("OnEnter",S.GoldTooltip)
    frame:HookScript("OnLeave",function() GameTooltip:Hide() end)
    end
    if frame.GetChildren then
        local children={frame:GetChildren()}
        for _,child in ipairs(children) do
            if child.HookScript then HookMoney(child) end
        end
    end
end
local function Window(name,title,width,height,parent)
    local f=CreateFrame("Frame",name,parent or UIParent,"BackdropTemplate")
    f:SetSize(width,height);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true)
    f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
    local t=f:CreateFontString(nil,"OVERLAY","TrailboundTitle");t:SetPoint("TOP",0,-14);t:SetText(title)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-4,-4)
    tinsert(UISpecialFrames,name);f:Hide();return f
end
local function Scroll(parent,x,y,right,bottom,width)
    local scroll=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",x,y);scroll:SetPoint("BOTTOMRIGHT",right,bottom)
    local content=CreateFrame("Frame",nil,scroll);content:SetSize(width,1);scroll:SetScrollChild(content)
    return content
end
local inventory, itemContent, itemRows, inventoryInfo, selectedCharacter
function S.SelectCharacter(key) selectedCharacter=key;S.RefreshInventory() end
function S.RefreshInventory()
    if not inventory or not inventory:IsShown() then return end
    local keys={}
    for key in pairs(account.characters) do keys[#keys+1]=key end
    table.sort(keys,function(a,b)return Label(account.characters[a])<Label(account.characters[b]) end)
    if not selectedCharacter or not account.characters[selectedCharacter] then selectedCharacter=account.characters[currentKey] and currentKey or keys[1] end
    if inventory.forget then inventory.forget:SetEnabled(ForeverAssistExtras.CanForgetCharacter(selectedCharacter)) end
    local selected=account.characters[selectedCharacter]
    if inventory.selector and inventory.selector.SetDefaultText then inventory.selector:SetDefaultText(selected and Label(selected) or "Choose a character") end
    local record=account.characters[selectedCharacter]
    local capacity=0
    for bag,contents in pairs(record and record.bags or {}) do
        local size=record.bagSizes and record.bagSizes[bag] or 0
        if size==0 then for slot in pairs(contents) do size=math.max(size,slot) end end
        capacity=capacity+size
    end
    local columns=capacity<=40 and 10 or 13
    local width=columns==10 and 520 or 640
    inventory:SetWidth(width);inventory.selector:SetWidth(width-110);itemContent:SetWidth(columns*44-4);inventoryInfo:SetWidth(width-52)
    inventory.gold:SetWidth(width-230)
    for _,row in ipairs(itemRows) do row:Hide() end
    inventory.bagHeaders=inventory.bagHeaders or {}
    for _,header in pairs(inventory.bagHeaders) do header:Hide() end
    local y,index=0,0
    if record then
        for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
            local slots=(record.bags or {})[bag] or {}
            local size=record.bagSizes and record.bagSizes[bag]
            if not size then size=0;for slot in pairs(slots) do size=math.max(size,slot) end end
            if size>0 then
                for slot=1,size do
                    index=index+1;local row=itemRows[index]
                    if not row then
                        row=CreateFrame("Button",nil,itemContent);row:SetSize(40,40)
                        local bg=row:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();if bg.SetAtlas then bg:SetAtlas("bags-item-slot64") else bg:SetTexture("Interface/Buttons/UI-EmptySlot") end
                        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",3,-3);row.icon:SetPoint("BOTTOMRIGHT",-3,3)
                        row.count=row:CreateFontString(nil,"OVERLAY","NumberFontNormal");row.count:SetPoint("BOTTOMRIGHT",-3,3)
                        row:SetScript("OnEnter",function(self)
                            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                            if self.link then GameTooltip:SetHyperlink(self.link) elseif self.id then GameTooltip:SetItemByID(self.id) else GameTooltip:AddLine("Empty slot") end
                            GameTooltip:AddLine("Saved account bags • Read only",.7,.7,.7);GameTooltip:Show()
                        end)
                        row:SetScript("OnLeave",function() GameTooltip:Hide() end);itemRows[index]=row
                    end
                    row:ClearAllPoints();row:SetPoint("TOPLEFT",((index-1)%columns)*44,-math.floor((index-1)/columns)*44)
                    local item=slots[slot];row.bag,row.slot=bag,slot;row.id,row.link=item and item.id,item and item.link
                    local icon=item and item.icon
                    if item and not icon and C_Item and C_Item.GetItemIconByID then icon=C_Item.GetItemIconByID(item.id) end
                    row.icon:SetTexture(icon or (item and 134400));row.icon:SetShown(item~=nil);row.count:SetText(item and item.count>1 and item.count or "");row:Show()
                end
            end
        end
    end
    y=math.ceil(index/columns)*44
    itemContent:SetHeight(math.max(1,y))
    local screenHeight=UIParent:GetHeight() or 900
    inventory:SetHeight(math.min(math.max(280,y+198),math.max(280,screenHeight-100)))
    local when=record and date and date("%Y-%m-%d %H:%M",record.updatedAt or 0) or "last login"
    inventory.goldText:SetText("Account: "..ForeverAssistMoney(S.AccountGold()))
    inventoryInfo:SetText(record and (Label(record).." • Character gold: "..ForeverAssistMoney(S.CharacterGold(selectedCharacter,record)).."\nAccount total: "..ForeverAssistMoney(S.AccountGold()).." • Saved "..when) or "Log each character in once to record its bags.")
end
function S.ToggleInventory()
    S.Snapshot()
    if not inventory then
        inventory=CreateFrame("Frame","ForeverAssistAccountBags",UIParent,"PortraitFrameTemplate");inventory:SetSize(640,520);inventory:SetPoint("CENTER");inventory:SetFrameStrata("DIALOG");inventory:SetClampedToScreen(true)
        inventory:SetMovable(true);inventory:EnableMouse(true);inventory:RegisterForDrag("LeftButton");inventory:SetScript("OnDragStart",inventory.StartMoving);inventory:SetScript("OnDragStop",inventory.StopMovingOrSizing)
        local bg=inventory:CreateTexture(nil,"BACKGROUND");bg:SetPoint("TOPLEFT",1,-20);bg:SetPoint("BOTTOMRIGHT",-1,1);bg:SetAtlas("bank-frame-background")
        local portrait=inventory.PortraitContainer and inventory.PortraitContainer.portrait or inventory.Portrait
        if portrait then portrait:SetTexture("Interface/Icons/INV_Misc_Bag_10") end
        if inventory.SetTitle then inventory:SetTitle("Account Bags — saved view") else local title=inventory:CreateFontString(nil,"OVERLAY","TrailboundTitle");title:SetPoint("TOPLEFT",80,-9);title:SetText("Account Bags — saved view") end
        if inventory.CloseButton then inventory.CloseButton:SetScript("OnClick",function()inventory:Hide()end) else local close=CreateFrame("Button",nil,inventory,"UIPanelCloseButton");close:SetPoint("TOPRIGHT");close:SetScript("OnClick",function()inventory:Hide()end) end
        tinsert(UISpecialFrames,"ForeverAssistAccountBags");inventory:Hide()
        local selector=CreateFrame("DropdownButton",nil,inventory,"WowStyle1DropdownTemplate");selector:SetSize(530,24);selector:SetPoint("TOPLEFT",80,-48)
        inventory.selector=selector
        if selector.SetupMenu then selector:SetupMenu(function(_,menu)
            local keys={};for key in pairs(account.characters) do keys[#keys+1]=key end
            table.sort(keys,function(a,b)return Label(account.characters[a])<Label(account.characters[b]) end)
            for _,key in ipairs(keys) do menu:CreateRadio(Label(account.characters[key]),function()return selectedCharacter==key end,function()S.SelectCharacter(key)end) end
        end) end
        local bags=inventory:CreateFontString(nil,"OVERLAY","TrailboundHeading");bags:SetPoint("TOPLEFT",26,-76);bags:SetText("SAVED BAGS • READ ONLY")
        inventory.gold=CreateFrame("Frame",nil,inventory);inventory.gold:SetSize(350,22);inventory.gold:SetPoint("BOTTOMLEFT",26,10);inventory.gold:EnableMouse(true);inventory.gold:SetScript("OnEnter",S.GoldTooltip);inventory.gold:SetScript("OnLeave",function()GameTooltip:Hide()end)
        inventory.goldText=inventory.gold:CreateFontString(nil,"OVERLAY","TrailboundSmall");inventory.goldText:SetAllPoints();inventory.goldText:SetJustifyH("LEFT")
        itemRows={};itemContent=Scroll(inventory,26,-96,-42,78,572)
        inventoryInfo=inventory:CreateFontString(nil,"OVERLAY","TrailboundSmall");inventoryInfo:SetPoint("BOTTOMLEFT",26,43);inventoryInfo:SetWidth(600);inventoryInfo:SetHeight(26);inventoryInfo:SetJustifyH("LEFT")
        inventory.forget=CreateFrame("Button",nil,inventory,"UIPanelButtonTemplate");inventory.forget:SetSize(160,24);inventory.forget:SetPoint("BOTTOMRIGHT",-20,10);inventory.forget:SetText("Forget character")
        inventory.forget:SetScript("OnClick",function() ForeverAssistExtras.RequestForgetCharacter(selectedCharacter) end)
        inventory:SetScript("OnShow",S.RefreshInventory)
    end
    inventory:SetShown(not inventory:IsShown());S.RefreshInventory()
end
local bagHooks={}
function S.RefreshGoldDisplays()
 for frame in pairs(bagHooks) do
  if frame.faAccountGold then
   frame.faAccountGold.text:SetText("Account: "..ForeverAssistMoney(S.AccountGold()))
   frame.faAccountGold:SetShown(getSettings().accountBags~=false and frame:IsShown())
  end
 end
end
local function InstallBagFrame(frame)
    if not frame or not frame.HookScript then return end
    if not bagHooks[frame] then
        bagHooks[frame]=true
        local button=CreateFrame("Button",nil,UIParent);button:SetSize(26,26);button:SetPoint("TOPRIGHT",frame,"TOPLEFT",-8,-32);button:SetFrameStrata("HIGH")
        local icon=button:CreateTexture(nil,"ARTWORK");icon:SetAllPoints();icon:SetTexture("Interface/Icons/INV_Misc_Bag_08")
        button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Other characters’ bags");GameTooltip:AddLine("Browse saved bag layouts",.7,.7,.7);GameTooltip:Show() end)
        button:SetScript("OnLeave",function() GameTooltip:Hide() end)
        button:SetScript("OnClick",S.ToggleInventory);frame.faAccountButton=button
        local bank=CreateFrame("Button",nil,UIParent);bank:SetSize(26,26);bank:SetPoint("TOPRIGHT",frame,"TOPLEFT",-8,-64);bank:SetFrameStrata("HIGH")
        local bankIcon=bank:CreateTexture(nil,"ARTWORK");bankIcon:SetAllPoints();bankIcon:SetTexture("Interface/Icons/INV_Misc_Bag_10")
        bank:SetScript("OnClick",ForeverAssistBank.Toggle);frame.faBankButton=bank
        bank:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Bank — current & other characters");GameTooltip:AddLine("Browse saved banks in the normal bank layout.\nVisit the bank on each character once to record it.",.7,.7,.7,true);GameTooltip:Show() end)
        bank:SetScript("OnLeave",function()GameTooltip:Hide()end)
        local gold=CreateFrame("Frame",nil,UIParent);frame.faAccountGold=gold;gold:SetSize(220,23);gold:SetPoint("BOTTOMRIGHT",frame,"TOPRIGHT",0,3);gold:SetFrameStrata("HIGH");gold:SetClampedToScreen(true);gold:EnableMouse(true)
        gold.text=gold:CreateFontString(nil,"OVERLAY","TrailboundSmall");gold.text:SetAllPoints();gold.text:SetJustifyH("RIGHT")
        gold:SetScript("OnEnter",S.GoldTooltip);gold:SetScript("OnLeave",function()GameTooltip:Hide()end)
        frame:HookScript("OnHide",function(self) self.faAccountButton:Hide();self.faBankButton:Hide();self.faAccountGold:Hide() end)
        frame:HookScript("OnShow",function(self)
            self.faAccountButton:SetShown(getSettings().accountBags ~= false)
            self.faBankButton:SetShown(getSettings().accountBags ~= false)
            S.Snapshot();S.HookWindows()
        end)
    end
    frame.faAccountButton:SetShown(getSettings().accountBags ~= false and frame:IsShown())
    frame.faBankButton:SetShown(getSettings().accountBags ~= false and frame:IsShown())
    S.RefreshGoldDisplays()
    HookMoney(frame.MoneyFrame)
    HookMoney(frame.moneyFrame)
    if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do local n=child:GetName();if n and n:lower():find("money",1,true) then HookMoney(child) end end end
    if frame.Footer then HookMoney(frame.Footer.MoneyFrame) end
    if frame.GetName then local name=frame:GetName();if name then HookMoney(_G[name.."MoneyFrame"]) end end
end

local professionWindow, professionContent, professionRows, professionHeader, professionButtons, selectedProfession
function S.CurrentProfession()
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local ok,info=pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok and info then return info.professionID or info.skillLineID,info end
    end
    if GetTradeSkillLine then
        local name=GetTradeSkillLine()
        for id,info in pairs(S.LearnedProfessions()) do if info.name==name then return id,info end end
    end
end
function S.RecordRecipes()
    local id=S.CurrentProfession()
    if not id or not S.LearnedProfessions()[id] then return end
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo then
        local ok,recipes=pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if ok and recipes then
            for _,recipe in ipairs(recipes) do
                local got,info=pcall(C_TradeSkillUI.GetRecipeInfo,recipe)
                if got and info and info.learned==true then character.knownRecipes[recipe]=true end
            end
        end
    end
end
function S.ProfessionList(id)
    local learned=S.LearnedProfessions()
    if not learned[id] then return {} end
    local reference=ForeverAssistProfessionData and ForeverAssistProfessionData[id]
    local entries,seen={},{}
    if reference then
        for _,spell in ipairs(reference.records) do
            -- Reference-backed scans must not fall through as ID-less extras
            -- after their learned reference entry has been filtered out.
            seen[spell.name..'|'..spell.rank]=true
            local confirmed=character.professionTraining[id] and character.professionTraining[id][spell.name.."|"..spell.rank]
            if confirmed and not character.knownRecipes[spell.spellID] and not Known(spell.spellID) then
                local copy=ForeverAssistExtras.Copy(spell)
                local scanned=character.professionTraining[id] and character.professionTraining[id][spell.name.."|"..spell.rank]
                if scanned then copy.cost=scanned.cost;copy.available=scanned.available;copy.icon=scanned.icon;copy.scanned=true;copy.requiredSkill=scanned.requiredSkill;copy.requiredSkillName=scanned.requiredSkillName;copy.level=scanned.level end
                entries[#entries+1]=copy
            end
        end
    end
    for key,spell in pairs(character.professionTraining[id] or {}) do
        if not seen[key] and not (spell.spellID and (Known(spell.spellID) or character.knownRecipes[spell.spellID])) then local copy=ForeverAssistExtras.Copy(spell);copy.scanned=true;entries[#entries+1]=copy end
    end
    table.sort(entries,function(a,b)if (a.requiredSkill or 0)~=(b.requiredSkill or 0) then return (a.requiredSkill or 0)<(b.requiredSkill or 0) end;return a.name<b.name end)
    return entries
end
function S.RefreshProfessions()
    if not professionWindow or not professionWindow:IsShown() then return end
    local learned=S.LearnedProfessions()
    selectedProfession=S.CurrentProfession()
    local info=learned[selectedProfession]
    local list=selectedProfession and S.ProfessionList(selectedProfession) or {}
    professionHeader:SetText(info and (info.name..' '..(info.rank or 0)..'/'..(info.maxRank or '?')..'  •  '..#list..' recipes')or 'Open a profession to see its trainer recipes.')
    for i,spell in ipairs(list) do
        local row=professionRows[i]
        if not row then
            row=CreateFrame("Button",nil,professionContent);row:SetSize(285,28);row:SetPoint("TOPLEFT",0,-(i-1)*29)
            row.text=row:CreateFontString(nil,"OVERLAY","TrailboundSmall");row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(22,22);row.icon:SetPoint("LEFT",0,0)
            row.text:SetPoint('TOPLEFT',30,-1);row.text:SetWidth(255);row.text:SetJustifyH('LEFT');row.text:SetMaxLines(1);row.text:SetWordWrap(false)
            row.requirement=row:CreateFontString(nil,'OVERLAY','TrailboundSmall');row.requirement:SetPoint('BOTTOMLEFT',30,1);row.requirement:SetWidth(138);row.requirement:SetJustifyH('LEFT');row.requirement:SetMaxLines(1)
            row.cost=row:CreateFontString(nil,'OVERLAY','TrailboundSmall');row.cost:SetPoint('BOTTOMRIGHT',-8,1);row.cost:SetWidth(104);row.cost:SetJustifyH('RIGHT');row.cost:SetWordWrap(false)
            row:SetScript("OnEnter",function(self)GameTooltip:SetOwner(self,"ANCHOR_RIGHT");if self.spell.spellID then GameTooltip:SetSpellByID(self.spell.spellID) else GameTooltip:AddLine(self.spell.name) end;GameTooltip:AddLine(self.requirement:GetText());if not self.spell.requiredSkill then GameTooltip:AddLine('Visit the trainer to record the skill requirement.',1,.82,.48,true)end;GameTooltip:Show() end)
            row:SetScript("OnLeave",function()GameTooltip:Hide() end);professionRows[i]=row
        end
        row.spell=spell
        local icon=C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell.spellID or spell.name)
        row.icon:SetTexture(spell.icon or icon and icon.iconID or 134400)
        local required=spell.requiredSkill;local current=info and info.rank
        local tooLow=required and current and current<required or (spell.level or 0)>UnitLevel('player')or required==nil and spell.available==false
        local color=tooLow and '|cffff5555'or '|cffeacc91'
        local requirement=required and ('Skill '..required)or 'Skill ?'
        if (spell.level or 0)>0 then requirement=requirement..' • Lv '..spell.level end
        row.text:SetText(color..spell.name..(spell.rank and spell.rank~=''and (' ('..spell.rank..')')or '')..'|r')
        row.requirement:SetText(color..requirement..'|r');row.cost:SetText(spell.cost~=nil and ForeverAssistMoney(spell.cost)or '—');row:Show()
    end
    for i=#list+1,#professionRows do professionRows[i]:Hide() end
    professionContent:SetHeight(math.max(1,#list*29))
end
function S.CreateProfessionPanel(host)
    if professionWindow then return end
    professionWindow=Window("ForeverAssistProfessionBook","Profession Catalogue",345,440,host or UIParent)
    if host then professionWindow:ClearAllPoints();professionWindow:SetPoint("TOPLEFT",host,"TOPRIGHT",65,-5) end
    professionRows,professionButtons={},{}
    professionHeader=professionWindow:CreateFontString(nil,"OVERLAY","TrailboundSmall");professionHeader:SetPoint("TOPLEFT",18,-45);professionHeader:SetWidth(305);professionHeader:SetJustifyH("LEFT")
    professionContent=Scroll(professionWindow,18,-67,-32,30,285)
    local note=professionWindow:CreateFontString(nil,"OVERLAY","TrailboundMuted");note:SetPoint("BOTTOM",0,14);note:SetText("Confirmed trainer services")
    professionWindow:SetScript("OnShow",S.RefreshProfessions)
end
function S.ProfessionOptionChanged()
    if professionWindow and not getSettings().professionBook then professionWindow:Hide() end
    S.HookWindows()
end
function S.ToggleProfessions()
    S.RecordRecipes();S.CreateProfessionPanel()
    professionWindow:SetShown(not professionWindow:IsShown());S.RefreshProfessions()
end
local professionHooks={}
function S.HookWindows()
    if not account then return end
    InstallBagFrame(ContainerFrameCombinedBags)
    InstallBagFrame(ContainerFrame1)
    for i=2,6 do HookMoney(_G["ContainerFrame"..i.."MoneyFrame"]) end
    HookMoney(ContainerFrame1MoneyFrame)
    local host=ProfessionsFrame or TradeSkillFrame or CraftFrame
    if host and host.HookScript and not professionHooks[host] then
        professionHooks[host]=true
        host:HookScript("OnShow",function(self)
            if getSettings().professionBook then
                S.RecordRecipes();S.CreateProfessionPanel(self)
                professionWindow:SetParent(self);professionWindow:ClearAllPoints();professionWindow:SetPoint("TOPLEFT",self,"TOPRIGHT",65,-5)
                local id=S.CurrentProfession();if id then selectedProfession=id end
                professionWindow:Show()
            end
        end)
    end
    HookTooltips()
end
function S.Camera(value,report)
    if not getSettings then return end
    local set=C_CVar and C_CVar.SetCVar or SetCVar
    local get=C_CVar and C_CVar.GetCVar or GetCVar
    if not set or not get then if report then Print("Camera setting is unavailable on this client.") end;return end
    local requested=value=="max" and 4 or tonumber(value or getSettings().cameraFactor or 4)
    if not requested or requested<=0 or requested>100 then Print("Use /tb camera max or /tb camera NUMBER (0–100).");return end
    local ok,result=pcall(set,"cameraDistanceMaxZoomFactor",tostring(requested))
    if not ok or result==false then
        if value=="max" then pcall(set,"cameraDistanceMaxZoomFactor","4") end
    end
    local read,accepted=pcall(get,"cameraDistanceMaxZoomFactor")
    accepted=read and tonumber(accepted)
    if accepted then getSettings().cameraFactor=accepted;getSettings().cameraRequest=value=="max" and "max" or tostring(requested) end
    if report then
        Print("Camera zoom factor: "..tostring(accepted or "unavailable").." (requested "..requested.."). The client enforces its maximum.")
    end
end
local bagsDirty=false
local f=CreateFrame("Frame")
local recipeRefreshPending=false
local function RefreshRecipesSoon()
    if recipeRefreshPending or not C_Timer or not C_Timer.After then return end
    recipeRefreshPending=true
    C_Timer.After(.2,function()recipeRefreshPending=false;if account then S.RecordRecipes();S.RefreshProfessions()end end)
end
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","BAG_UPDATE","BAG_UPDATE_DELAYED","PLAYER_MONEY","PLAYER_LOGOUT","ADDON_LOADED","TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","NEW_RECIPE_LEARNED","SKILL_LINES_CHANGED"}) do pcall(f.RegisterEvent,f,event) end
f:SetScript("OnEvent",function(_,event,recipeID,recipeLevel,baseRecipeID)
    if not account then return end
    if event=="PLAYER_LOGOUT" or event=="PLAYER_LEAVING_WORLD" then
        -- Money is already captured on money events. During teardown GetMoney
        -- can return zero; never replace the last confirmed balance here.
        moneySessionEnding=true;return
    elseif event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" then
        moneySessionEnding=false
        moneyReadyAt=(GetTime and GetTime() or 0)+3
        bagsDirty=not S.Snapshot();S.HookWindows()
    elseif event=="BAG_UPDATE" then bagsDirty=true
    elseif event=="BAG_UPDATE_DELAYED" or event=="PLAYER_MONEY" then
        S.RecordMoney(event=="PLAYER_MONEY");bagsDirty=not S.Snapshot();S.RefreshInventory()
    elseif event=="ADDON_LOADED" then S.HookWindows()
    else
        if event=='NEW_RECIPE_LEARNED'then
            for _,id in pairs({recipeID,baseRecipeID})do
                if (not issecretvalue or not issecretvalue(id))and type(id)=='number'and id>0 then character.knownRecipes[id]=true end
            end
        end
        S.RecordRecipes()
        if event=="TRADE_SKILL_SHOW" then
            S.HookWindows()
            if getSettings().professionBook then
                local host=ProfessionsFrame or TradeSkillFrame or CraftFrame
                S.CreateProfessionPanel(host)
                if host then
                    professionWindow:SetParent(host);professionWindow:ClearAllPoints();professionWindow:SetPoint("TOPLEFT",host,"TOPRIGHT",65,-5)
                end
                local id=S.CurrentProfession();if id then selectedProfession=id end
                professionWindow:Show()
            end
        end
        S.RefreshProfessions()
        RefreshRecipesSoon()
    end
end)
SLASH_FOREVERASSISTBAGS1="/tbbags"
SlashCmdList["FOREVERASSISTBAGS"]=function() if account then S.ToggleInventory() end end

-- Merge observed services into rank-aware reference entries before filtering learned ranks.
function S.ClassSpellList(reference,training,known,knownIDs,isKnown,eligible)
 local byKey,byName,highest={},{},{}
 local function key(s) return s.name..'|'..S.NormalizeRank(s.rank) end
 local function rank(s) return tonumber(S.NormalizeRank(s.rank):match('%d+')) or 0 end
 for _,s in ipairs(reference) do
  byName[s.name]=byName[s.name] or {};table.insert(byName[s.name],s)
  if known[key(s)] or s.spellID and knownIDs[s.spellID] or isKnown(s) then highest[s.name]=math.max(highest[s.name] or -1,rank(s)) end
 end
 for k in pairs(known) do local name,r=k:match('^(.-)|(.*)$');local n=tonumber(r and r:match('%d+'));if n then highest[name]=math.max(highest[name] or -1,n) end end
 local function unlearned(s) return not known[key(s)] and not (s.spellID and knownIDs[s.spellID]) and not isKnown(s) and (highest[s.name]==nil or rank(s)>highest[s.name]) end
 for _,s in ipairs(reference) do if eligible(s) and unlearned(s) and s.level<=60 then byKey[key(s)]=ForeverAssistExtras.Copy(s) end end
 for _,s in pairs(training or {}) do
  local ref
  for _,candidate in ipairs(byName[s.name] or {}) do
   if S.NormalizeRank(candidate.rank)==S.NormalizeRank(s.rank) or S.NormalizeRank(s.rank)=='' and candidate.level==s.level then
    if ref then ref=false;break end;ref=candidate
   end
  end
  -- Unranked observations of ranked names must match a reference level; otherwise ignore ambiguous old data.
  if ref or S.NormalizeRank(s.rank)~='' or not byName[s.name] then
   local copy=ForeverAssistExtras.Copy(ref or s)
   copy.cost,copy.available,copy.icon=s.cost,s.available,s.icon or copy.icon
   if eligible(copy) and unlearned(copy) and copy.level<=60 and (ref or s.observedClassTrainer) then byKey[key(copy)]=copy end
  end
 end
 local list={};for _,s in pairs(byKey) do list[#list+1]=s end
 table.sort(list,function(a,b) if a.level~=b.level then return a.level<b.level end;if a.name~=b.name then return a.name<b.name end;return rank(a)<rank(b) end)
 return list
end

local bagClock,goldClock=0,0
f:SetScript("OnUpdate",function(_,elapsed) goldClock=goldClock+elapsed;if account and goldClock>=2 then goldClock=0;S.RecordMoney() end;bagClock=bagClock+elapsed;if account and bagsDirty and bagClock>=.5 then bagClock=0;bagsDirty=not S.Snapshot();S.RefreshInventory() end end)
