-- Additional reminder rules. All aura fields come through the restricted-aura guard.
ForeverAssistReminders={Version='1.8.54'}
local R=ForeverAssistReminders
local function safe(v) return not issecretvalue or not issecretvalue(v) end
local abilityCache,selectedCache={},{}
local function known(id)
 if abilityCache[id]~=nil then return abilityCache[id] end
 for _,fn in pairs({C_SpellBook and C_SpellBook.IsSpellKnown,IsPlayerSpell,IsSpellKnown}) do
  if fn then local ok,v=pcall(fn,id);if ok and safe(v) and v==true then abilityCache[id]=true;return true end end
 end
 abilityCache[id]=false;return false
end
local nameCache={}
local function spellName(id)
 if nameCache[id] then return nameCache[id] end
 local fn=C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
 if fn then local ok,v=pcall(fn,id);if ok and safe(v) then
  local name=type(v)=='table' and v.name or v
  if safe(name) and type(name)=='string' then nameCache[id]=name;return name end
 end end
end
local function scanSelected(ids)
 local names={}
 for _,id in ipairs(ids) do if known(id) then return true end;local name=spellName(id);if name then names[name]=true end end
 -- Classic talent spells are not always reported by the spellbook API.
 if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
  local ok,tabs=pcall(GetNumTalentTabs)
  if ok and safe(tabs) and type(tabs)=='number' then
   for tab=1,tabs do
    local got,n=pcall(GetNumTalents,tab)
    if got and safe(n) and type(n)=='number' then for index=1,n do
     local valid,name,_,_,_,rank=pcall(GetTalentInfo,tab,index)
     if valid and safe(name) and safe(rank) and names[name] and type(rank)=='number' and rank>0 then return true end
    end end
   end
  end
 end
 return false
end
local function selected(ids)
 local key=ids[1]
 if selectedCache[key]==nil then selectedCache[key]=scanSelected(ids) end
 return selectedCache[key]
end
function R.Invalidate() abilityCache,selectedCache,nameCache={},{},{};R.bagCacheAt=nil end
local loneWolf={1310684,415370,409979,155228}
local sacrifice={18788,108503}
local pact={425464}
local sacrificeAuras={[18789]=true,[18790]=true,[18791]=true,[18792]=true,[35701]=true,[108503]=true,[196099]=true}
function R.PetReminder(auras)
 local _,class=UnitClass('player')
 if class~='HUNTER' and class~='WARLOCK' then return end
 if UnitExists then local ok,exists=pcall(UnitExists,'pet');if not ok or not safe(exists) or exists then return end end
 if UnitHasVehicleUI and UnitHasVehicleUI('player') then return end
 if class=='HUNTER' then
  -- Call Pet alone can be granted before a hunter has learned to tame a pet.
  if not known(883) or not known(1515) or selected(loneWolf) then return end
  for _,a in ipairs(auras or {}) do for _,id in ipairs(loneWolf) do if a.spellId==id then return end end end
  return {label='Call pet',shortLabel='Pet',icon=132161}
 end
 local canSummon=false
 for _,id in ipairs({688,697,712,691,30146}) do if known(id) then canSummon=true;break end end
 if not canSummon then return end
 -- Demonic Pact permits a new pet alongside sacrifice; otherwise respect petless builds.
 if not selected(pact) then
  if selected(sacrifice) then return end
  for _,a in ipairs(auras or {}) do if sacrificeAuras[a.spellId] then return end end
 end
 return {label='Summon demon',shortLabel='Pet',icon=136218}
end
local cities={[1453]=true,[1454]=true,[1455]=true,[1456]=true,[1457]=true,[1458]=true,[1947]=true,[1954]=true}
local cityNames={['Stormwind City']=true,Stormwind=true,Ironforge=true,Darnassus=true,Orgrimmar=true,['Thunder Bluff']=true,Undercity=true,['The Exodar']=true,Exodar=true,['Silvermoon City']=true}
function R.InCapital()
 if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
  local ok,id=pcall(C_Map.GetBestMapForUnit,'player')
  if ok and safe(id) then for i=1,8 do
   if not id or id==0 then break end
   if cities[id] then return true end
   local got,info=pcall(C_Map.GetMapInfo,id);if not got or not info then break end
   id=info.parentMapID
  end end
  -- Use translated city names when the client's best-map result is a continent.
  for id in pairs(cities) do
   if not R.cityNamesLoaded then local got,info=pcall(C_Map.GetMapInfo,id);if got and info and info.name then cityNames[info.name]=true end end
  end
  R.cityNamesLoaded=true
 end
 local zone=GetRealZoneText and GetRealZoneText() or GetZoneText and GetZoneText()
 return zone and safe(zone) and cityNames[zone]==true or false
end
function R.ShortLabel(entry)
 if entry.shortLabel then return entry.shortLabel end
 local label=entry.label or '?'
 return label:gsub(' %(higher rank%)',' +'):gsub('^Greater Blessing of ',''):gsub('^Blessing of ',''):gsub('^Aspect of the ',''):gsub('^Aspect of ',''):gsub('^Power Word: ',''):gsub('^Mark of the Wild$','Mark'):gsub('^Gift of the Wild$','Gift'):gsub('^Find ',''):gsub('^Demon Armor$','Armor'):gsub('^Demon Skin$','Armor')
end
local sleepingItem,sleepingAura=211527,429959
local sleepSeen,sleepExpiration,sleepStacks=false,nil,nil
local notice,noticeUntil
local function popup()
 if not notice then
  notice=CreateFrame('Frame','ForeverAssistSleepingBagReady',UIParent);notice:SetSize(420,44);notice:SetPoint('CENTER',UIParent,'CENTER',0,205);notice:SetFrameStrata('HIGH')
  notice.text=notice:CreateFontString(nil,'OVERLAY','TrailboundTitle');notice.text:SetAllPoints();notice.text:SetTextColor(unpack(TrailboundTheme.accent))
  notice:SetScript('OnUpdate',function(self) if GetTime()>=noticeUntil then self:Hide() end end)
 end
 notice.text:SetText('Well-Rested refreshed — 3 stacks, 120 minutes');noticeUntil=GetTime()+3;notice:Show()
end
function R.ResetSleepingBag() sleepSeen,sleepExpiration,sleepStacks=false,nil,nil;if notice then notice:Hide() end end
local function readBagReady()
 local itemCount=C_Item and C_Item.GetItemCount or GetItemCount
 if itemCount then local ok,count=pcall(itemCount,sleepingItem,false,false,false);if ok and safe(count) and type(count)=="number" and count==0 then return false end end
 local slots=C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
 local modern=C_Container and C_Container.GetContainerItemInfo
 if not slots or not (modern or GetContainerItemInfo) then return false end
 for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
  local ok,count=pcall(slots,bag)
  if not ok or not safe(count) or type(count)~='number' then return false end
  for slot=1,count do
   local id
   if modern then local got,item=pcall(modern,bag,slot);if got and item then id=item.itemID end
   else local got,_,_,_,_,_,_,link,_,_,itemID=pcall(GetContainerItemInfo,bag,slot);if got then id=itemID or link and tonumber(link:match('item:(%d+)')) end end
   if safe(id) and id==sleepingItem then
    local cooldown=C_Container and C_Container.GetContainerItemCooldown or GetContainerItemCooldown
    if not cooldown then return false end
    local got,start,duration,enabled=pcall(cooldown,bag,slot)
    if not got or not safe(start) or not safe(duration) or not safe(enabled) or type(start)~='number' or type(duration)~='number' then return false end
    return (enabled==1 or enabled==true) and (duration==0 or start+duration<=GetTime())
   end
  end
 end
 return false
end
local function bagReady()
 if R.bagCacheAt and GetTime()-R.bagCacheAt<1 then return R.bagCacheReady end
 R.bagCacheReady=readBagReady();R.bagCacheAt=GetTime();return R.bagCacheReady
end
local events=CreateFrame('Frame')
for _,event in ipairs({'SPELLS_CHANGED','PLAYER_TALENT_UPDATE','CHARACTER_POINTS_CHANGED','BAG_UPDATE_DELAYED','BAG_UPDATE_COOLDOWN','PLAYER_ENTERING_WORLD'}) do pcall(events.RegisterEvent,events,event) end
events:SetScript('OnEvent',R.Invalidate)
function R.SleepingBagReminder(auras,enabled)
 if not enabled then R.ResetSleepingBag();return end
 local aura
 for _,a in ipairs(auras or {}) do if a.spellId==sleepingAura then aura=a;break end end
 local expires=aura and aura.expirationTime or 0
 local stacks=aura and aura.applications or 0
 local remaining=expires-GetTime()
 if sleepSeen and stacks>=3 and remaining>=7180 and (not sleepExpiration or expires>sleepExpiration+5 or (sleepStacks or 0)<3) then popup() end
 sleepSeen,sleepExpiration,sleepStacks=true,expires,stacks
 if aura and remaining>=300 then return end
 if not IsOutdoors or not IsOutdoors() or R.InCapital() or (IsResting and IsResting()) then return end
 local inside=IsInInstance and IsInInstance();if inside then return end
 if bagReady() then return {label=aura and 'Refresh Well-Rested (under 5 minutes)' or 'Gain Well-Rested',shortLabel='Sleep bag',icon=133851} end
end
