-- Move standard panels without tainting Blizzard's native show/hide decisions.
ForeverAssistWindows={Version='1.8.46'}
local W=ForeverAssistWindows
local character
local frames={}
local names={
 'CharacterFrame','SpellBookFrame','PlayerSpellsFrame','TalentFrame','PlayerTalentFrame',
 'ClassTalentFrame','TradeSkillFrame','CraftFrame','ProfessionsFrame','ProfessionsBookFrame',
 'MerchantFrame','ClassTrainerFrame','QuestLogFrame','QuestFrame','GossipFrame',
 'BankFrame','MailFrame','AuctionFrame','AuctionHouseFrame','TradeFrame','InspectFrame',
 'FriendsFrame','GuildFrame','PVPFrame','PVEFrame','LFGParentFrame','LFGListFrame',
 'MacroFrame','AchievementFrame','CollectionsJournal','DressUpFrame','ItemTextFrame',
 'TaxiFrame','PetStableFrame','TabardFrame','PetitionFrame','ItemSocketingFrame',
 'GuildBankFrame','CalendarFrame','LootFrame','EncounterJournal','CommunitiesFrame',
 'ForeverAssistBook','ForeverAssistJunk','ForeverAssistSavedBank','ForeverAssistAccountBags',
 'WorldMapFrame','QuestLogPopupDetailFrame','LegacySystemFrame','LegacyFrame',
 'LegacyPointsFrame','LegacySystemUI',
}
local function combat() return InCombatLockdown and InCombatLockdown() end
local function restore(frame,name)
 if combat() then return end
 local p=character.windowPositions[name]
 if p then frame:ClearAllPoints();frame:SetPoint('CENTER',UIParent,'CENTER',p[1],p[2])
 elseif frame:GetNumPoints()==0 then frame:SetPoint('CENTER',UIParent,'CENTER',0,0) end
end
function W.Apply()
 if not character or combat() then return end
 -- Custom client Legacy panel names can vary; inspect registrations read-only.
 local included={};for _,name in ipairs(names) do included[name]=true end
 for name in pairs(UIPanelWindows or {}) do
  if type(name)=='string' and name:lower():find('legacy',1,true) and not included[name] then names[#names+1]=name;included[name]=true end
 end
 for _,name in ipairs(names) do
  local frame=_G[name]
  if frame and not (frame.IsForbidden and frame:IsForbidden()) then
   if not frames[frame] then
    frames[frame]=true
    frame:SetMovable(true);frame:SetClampedToScreen(true)
    local handle=CreateFrame('Button',nil,frame)
    handle:SetPoint('TOPLEFT',frame,'TOPLEFT',48,-3)
    handle:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-38,-3);handle:SetHeight(25)
    handle:SetFrameLevel(frame:GetFrameLevel()+50);handle:RegisterForDrag('LeftButton');handle:EnableMouse(true)
    frame.faWindowMoveHandle=handle
    handle:SetScript('OnMouseDown',function() if not combat() and frame.Raise then frame:Raise() end end)
    handle:SetScript('OnDragStart',function()
     if combat() then return end
     frame:StartMoving();frame.faWindowDragging=true
     if frame.Raise then frame:Raise() end
    end)
    local function stop()
     if combat() or not frame.faWindowDragging then return end
     frame:StopMovingOrSizing();frame.faWindowDragging=nil
     local x,y=frame:GetCenter();local ux,uy=UIParent:GetCenter()
     if x and y and ux and uy then
      local scale=frame:GetEffectiveScale();local base=UIParent:GetEffectiveScale()
      character.windowPositions[name]={x-ux*base/scale,y-uy*base/scale}
      restore(frame,name)
     end
    end
    handle:SetScript('OnDragStop',stop)
    frame:HookScript('OnHide',stop)
    frame:HookScript('OnShow',function() restore(frame,name) end)
    -- Native panel registration, layout attributes and Escape handling stay intact.
   end
   restore(frame,name)
  end
 end
end
function W.Initialize(db)
 character=db;character.windowPositions=character.windowPositions or {}
 W.Apply()
end
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','ADDON_LOADED','PLAYER_REGEN_ENABLED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function(_,event)
 if event=='PLAYER_REGEN_ENABLED' then
  for frame in pairs(frames) do
   if frame.faWindowDragging then frame:StopMovingOrSizing();frame.faWindowDragging=nil end
  end
 end
 W.Apply()
end)
