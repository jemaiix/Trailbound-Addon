-- Read-only bank snapshots. The real BankFrame and its actions are untouched.
ForeverAssistBank={Version='1.8.54'}
local B=ForeverAssistBank
local account,character,bankOpen=false,nil,false
local viewer,selectedKey,selectedTab
local tabs,slots={},{}
local dirty,clock,retryUntil=false,0,0
local function key() return UnitGUID and UnitGUID('player') or (GetRealmName()..':'..UnitName('player')) end
local function copy(v) return ForeverAssistExtras.Copy(v) end
local function safe(v) return not issecretvalue or not issecretvalue(v) end
local function bankType() return Enum and Enum.BankType and Enum.BankType.Character end
local function containers()
 local kind=bankType()
 if C_Bank and C_Bank.FetchPurchasedBankTabData and kind~=nil then
  local ok,data=pcall(C_Bank.FetchPurchasedBankTabData,kind)
  if not ok or type(data)~='table' then return end
  local list={}
  for _,tab in ipairs(data) do
   if safe(tab.ID) and type(tab.ID)=='number' then list[#list+1]={id=tab.ID,name=tab.name or 'Bank',icon=tab.icon or 133639} end
  end
  return list,'tabs'
 end
 local list={{id=BANK_CONTAINER or -1,name=BANK or 'Bank',icon=133639}}
 local start=(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)+1
 for id=start,start+(NUM_BANKBAGSLOTS or 7)-1 do list[#list+1]={id=id,name='Bank bag '..(id-start+1),icon=133639} end
 if REAGENTBANK_CONTAINER then list[#list+1]={id=REAGENTBANK_CONTAINER,name=REAGENT_BANK or 'Reagent Bank',icon=133639} end
 return list,'bags'
end
function B.Initialize(a,c)
 account,character=a,c;bankOpen=false
 selectedKey=nil;selectedTab=nil;dirty=false
 account.bankCharacters=account.bankCharacters or {}
 if c.bankSnapshot then
  local r=c.bankSnapshot;local id=key()
  if not account.bankCharacters[id] or (account.bankCharacters[id].updatedAt or 0)<(r.updatedAt or 0) then account.bankCharacters[id]=copy(r) end
 end
end
function B.Record()
 if not account or not bankOpen then return false end
 local kind=bankType()
 if C_Bank and C_Bank.CanViewBank and kind~=nil then local ok,can=pcall(C_Bank.CanViewBank,kind);if not ok or not can then return false end end
 local list,layout=containers();if not list then return false end
 local readSlots=C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
 local read=C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
 if not readSlots or not read then return false end
 local id=key();local old=account.bankCharacters[id]
 local name,realm=UnitName('player'),GetRealmName()
 if not name or name=='Unknown' then return false end
 if #list==0 and old and #(old.order or {})>0 then return false end
 local record={name=name,realm=realm,layout=layout,order={},containers={},updatedAt=time()}
 local valid=0
 for _,tab in ipairs(list) do
  local ok,size=pcall(readSlots,tab.id)
  if not ok or not safe(size) or type(size)~='number' or size<0 then return false end
  local previous=old and old.containers and old.containers[tab.id]
  if size==0 and previous and previous.size>0 and (layout=='tabs' or tab.id==(BANK_CONTAINER or -1)) then return false end
  if size>0 then
   local bag={id=tab.id,name=tab.name,icon=tab.icon,size=size,items={}}
   if layout=='bags' then
    local fn=C_Container and C_Container.GetBagName or GetBagName
    if fn then local got,n=pcall(fn,tab.id);if got and n then bag.name=n end end
   end
   for slot=1,size do
    local item
    if C_Container and C_Container.GetContainerItemInfo then
     local got,value=pcall(read,tab.id,slot);if not got then return false end;item=value
    else
     local got,icon,count,_,quality,_,_,link,_,_,itemID=pcall(read,tab.id,slot)
     if not got then return false end
     if icon then item={itemID=itemID,iconFileID=icon,stackCount=count,quality=quality,hyperlink=link} end
    end
    if item then
     for _,field in ipairs({'itemID','iconFileID','stackCount','hyperlink','quality'}) do if not safe(item[field]) then return false end end
     local itemID=item.itemID or item.hyperlink and tonumber(item.hyperlink:match('item:(%d+)'))
     if not itemID and C_Container and C_Container.GetContainerItemID then local got,value=pcall(C_Container.GetContainerItemID,tab.id,slot);if got and safe(value) then itemID=value end end
     if not itemID then return false end
     bag.items[slot]={id=itemID,icon=item.iconFileID,count=item.stackCount or 1,link=item.hyperlink,quality=item.quality}
    end
   end
   record.order[#record.order+1]=tab.id;record.containers[tab.id]=bag;valid=valid+1
  end
 end
 if valid==0 then return false end
 -- Publish only a complete read, so loading failures never erase saved items.
 account.bankCharacters[id]=record;character.bankSnapshot=copy(record)
 for oldKey,r in pairs(account.bankCharacters) do if oldKey~=id and r.name==name and r.realm==realm then account.bankCharacters[oldKey]=nil end end
 B.Refresh();return true
end
local function label(r) return r.name..' - '..r.realm end
function B.CharacterKeys()
 local result,seen={},{}
 for id,r in pairs(account.characters or {}) do result[#result+1]=id;seen[id]=true end
 for id in pairs(account.bankCharacters) do if not seen[id] then result[#result+1]=id end end
 table.sort(result,function(a,b)return label(account.bankCharacters[a] or account.characters[a])<label(account.bankCharacters[b] or account.characters[b]) end)
 return result
end
local function font(parent,text,x,y,width)
 local f=parent:CreateFontString(nil,'OVERLAY','TrailboundSmall');f:SetPoint('TOPLEFT',x,y);f:SetText(text);if width then f:SetWidth(width);f:SetJustifyH('LEFT') end;return f
end
local function button(parent,text,x,y,width,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetPoint('TOPLEFT',x,y);b:SetSize(width,24);b:SetText(text);b:SetScript('OnClick',fn);return b
end
function B.SelectCharacter(id) selectedKey=id;selectedTab=nil;B.Refresh() end
function B.Refresh()
 if not viewer or not viewer:IsShown() then return end
 local keys=B.CharacterKeys()
 if not selectedKey or not account.bankCharacters[selectedKey] and not (account.characters or {})[selectedKey] then selectedKey=(account.bankCharacters[key()] or (account.characters or {})[key()]) and key() or keys[1] end
 if viewer.forget then viewer.forget:SetEnabled(ForeverAssistExtras.CanForgetCharacter(selectedKey)) end
 local r=account.bankCharacters[selectedKey];local who=r or (account.characters or {})[selectedKey]
 local characterLabel=who and label(who) or UnitName('player')..' - '..GetRealmName()
 viewer.character:SetText(characterLabel)
 if viewer.selector and viewer.selector.SetDefaultText then viewer.selector:SetDefaultText(characterLabel) end
 for _,b in ipairs(tabs) do b:Hide() end;for _,b in ipairs(slots) do b:Hide() end
 if not r then viewer.tabName:SetText('Bank not recorded');viewer.notice:SetText('Visit the bank on this character once with Trailbound enabled.\nChoose another character above to browse its saved bank.');return end
 if not selectedTab or not r.containers[selectedTab] then selectedTab=r.order[1] end
 for i,id in ipairs(r.order) do
  local b=tabs[i]
  if not b then
   b=CreateFrame('Button',nil,viewer);b:SetSize(32,32);b:SetPoint('TOPLEFT',viewer,'TOPRIGHT',3,-48-(i-1)*40)
   b.bg=b:CreateTexture(nil,'BACKGROUND');b.bg:SetAllPoints();b.bg:SetTexture('Interface/Buttons/UI-EmptySlot')
   b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',3,-3);b.icon:SetPoint('BOTTOMRIGHT',-3,3)
   b:SetScript('OnClick',function(self) selectedTab=self.id;B.Refresh() end)
   b:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine(self.tabName);GameTooltip:Show() end);b:SetScript('OnLeave',function()GameTooltip:Hide()end);tabs[i]=b
  end
  b.id=id;b.tabName=r.containers[id].name;b.icon:SetTexture(r.containers[id].icon);b.icon:SetVertexColor(id==selectedTab and 1 or .55,id==selectedTab and 1 or .55,id==selectedTab and 1 or .55);b:Show()
 end
 local bag=r.containers[selectedTab];viewer.tabName:SetText(bag and bag.name or 'Bank')
 if bag then
  -- Forever's native bank fills seven rows down each column, grouping columns in pairs.
  local rows=7
  local columns=math.ceil(bag.size/rows);local pitch=40
  local width=26+columns*pitch+math.floor((columns-1)/2)*11+42
  viewer:SetWidth(math.max(738,width));if viewer.selector then viewer.selector:SetWidth(viewer:GetWidth()-110) end;viewer.notice:SetWidth(viewer:GetWidth()-52)
  for slot=1,bag.size do
   local b=slots[slot]
   if not b then
    b=CreateFrame('Button',nil,viewer);b:SetSize(32,32)
    b.bg=b:CreateTexture(nil,'BACKGROUND');b.bg:SetAllPoints();if b.bg.SetAtlas then b.bg:SetAtlas('bags-item-slot64') else b.bg:SetTexture('Interface/Buttons/UI-EmptySlot') end
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',2,-2);b.icon:SetPoint('BOTTOMRIGHT',-2,2)
    b.count=b:CreateFontString(nil,'OVERLAY','NumberFontNormal');b.count:SetPoint('BOTTOMRIGHT',-1,1)
    b:SetScript('OnEnter',function(self)
     GameTooltip:SetOwner(self,'ANCHOR_RIGHT');if self.item then if self.item.link then GameTooltip:SetHyperlink(self.item.link) else GameTooltip:SetItemByID(self.item.id) end else GameTooltip:AddLine('Empty slot') end
     GameTooltip:AddLine('Saved bank • Slot '..self.slot,.7,.7,.7);GameTooltip:Show()
    end);b:SetScript('OnLeave',function()GameTooltip:Hide()end);slots[slot]=b
   end
   local col=math.floor((slot-1)/rows);local row=(slot-1)%rows
   b:ClearAllPoints();b:SetPoint('TOPLEFT',26+col*pitch+math.floor(col/2)*11,-104-row*42)
   local item=bag.items[slot];b.item=item;b.slot=slot;b.icon:SetTexture(item and (item.icon or 134400));b.icon:SetShown(item~=nil);b.count:SetText(item and item.count>1 and item.count or '');b:Show()
  end
 end
 local when=date('%Y-%m-%d %H:%M',r.updatedAt)
 viewer.notice:SetText('Saved '..when..' • Read only\nBank contents update when this character visits the bank. Items cannot be withdrawn remotely.')
end
function B.Toggle()
 if not account then return end
 if bankOpen then B.Record() end
 if not viewer then
  -- Reuse only Blizzard's visual frame template, never the interactive bank mixin.
  viewer=CreateFrame('Frame','ForeverAssistSavedBank',UIParent,'PortraitFrameTemplate');viewer:SetSize(738,474);viewer:SetPoint('CENTER');viewer:SetFrameStrata('DIALOG');viewer:SetClampedToScreen(true);viewer:SetMovable(true);viewer:EnableMouse(true);viewer:RegisterForDrag('LeftButton');viewer:SetScript('OnDragStart',viewer.StartMoving);viewer:SetScript('OnDragStop',viewer.StopMovingOrSizing)
  local bg=viewer:CreateTexture(nil,'BACKGROUND');bg:SetPoint('TOPLEFT',1,-20);bg:SetPoint('BOTTOMRIGHT',-1,1);bg:SetAtlas('bank-frame-background')
  local portrait=viewer.PortraitContainer and viewer.PortraitContainer.portrait or viewer.Portrait
  if portrait then portrait:SetTexture('Interface/Icons/INV_Misc_Bag_10') end
  if viewer.SetTitle then viewer:SetTitle('Bank — saved view') else local t=font(viewer,'Bank — saved view',80,-9,550) end
  if viewer.CloseButton then viewer.CloseButton:SetScript('OnClick',function()viewer:Hide()end) else local close=CreateFrame('Button',nil,viewer,'UIPanelCloseButton');close:SetPoint('TOPRIGHT');close:SetScript('OnClick',function()viewer:Hide()end) end
  viewer.character=font(viewer,'',80,-48,628);viewer.tabName=font(viewer,'',26,-80,600);viewer.notice=font(viewer,'',26,-394,680);viewer.notice:SetHeight(36)
  viewer.forget=button(viewer,'Forget character',0,0,160,function()ForeverAssistExtras.RequestForgetCharacter(selectedKey)end);viewer.forget:ClearAllPoints();viewer.forget:SetPoint('BOTTOMRIGHT',-24,12)
  local selector=CreateFrame('DropdownButton',nil,viewer,'WowStyle1DropdownTemplate');selector:SetSize(628,24);selector:SetPoint('TOPLEFT',80,-48)
  if selector.SetupMenu then
   viewer.selector=selector;viewer.character:Hide()
   selector:SetupMenu(function(_,root)
    for _,id in ipairs(B.CharacterKeys()) do
     local r=account.bankCharacters[id] or account.characters[id]
     local title=label(r)..(account.bankCharacters[id] and '' or ' (not recorded)')
     root:CreateRadio(title,function()return selectedKey==id end,function()B.SelectCharacter(id)end)
    end
   end)
  else selector:Hide() end
  viewer:SetScript('OnShow',B.Refresh);table.insert(UISpecialFrames,'ForeverAssistSavedBank');viewer:Hide()
 end
 viewer:SetShown(not viewer:IsShown());B.Refresh()
end
local events=CreateFrame('Frame')
for _,event in ipairs({'BANKFRAME_OPENED','BANKFRAME_CLOSED','PLAYERBANKSLOTS_CHANGED','BAG_UPDATE_DELAYED','BANK_TAB_SETTINGS_UPDATED','BANK_TABS_CHANGED','PLAYER_LOGOUT'}) do pcall(events.RegisterEvent,events,event) end
events:SetScript('OnEvent',function(_,event)
 if not account then return end
 if event=='BANKFRAME_OPENED' then bankOpen=true;retryUntil=GetTime()+5;B.Record();dirty=true
 elseif event=='BANKFRAME_CLOSED' then B.Record();bankOpen=false;dirty=false
 elseif event=='PLAYER_LOGOUT' then B.Record()
 elseif bankOpen then dirty=true;retryUntil=GetTime()+5 end
end)
events:SetScript('OnUpdate',function(_,elapsed) clock=clock+elapsed;if dirty and clock>=.25 then clock=0;local recorded=B.Record();dirty=not recorded and bankOpen and GetTime()<retryUntil end end)
SLASH_FOREVERASSISTBANK1='/tbbank';SlashCmdList.FOREVERASSISTBANK=B.Toggle
