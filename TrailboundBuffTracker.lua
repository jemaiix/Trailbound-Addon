-- Short-lived important player auras, including external casters and consumables.
ForeverAssistBuffTracker={Version="1.8.54"}
local T=ForeverAssistBuffTracker
function T.Suspend()
 T.suspended=true;T.unlocked=false
 if ForeverAssistImportantBuffTracker then ForeverAssistImportantBuffTracker:Hide() end
 if ForeverAssistImportantBuffOptions then ForeverAssistImportantBuffOptions:Hide() end
 if ForeverAssistBuffCatalogue then ForeverAssistBuffCatalogue:Hide() end
end
local getSettings,root,options
local icons,active,castEstimates={},{},{}
local shieldIDs={[17]=true,[592]=true,[600]=true,[3747]=true,[6065]=true,[6066]=true,[10898]=true,[10899]=true,[10900]=true,[10901]=true}
local sentCasts,focusConsumed,focusSpells={},false,nil
local castUntimed={[14751]=true}
local castDuration={[20554]=10,[26297]=10}
for id in pairs(shieldIDs) do castDuration[id]=30 end
local defaults={enabled=true,minDuration=1,maxDuration=30,iconSize=42,columns=8,showNames=false,combatOnly=false,immunity=true,defense=true,speed=true,offense=true,potions=true,selfCast=true,otherCast=true,castFallback=true,stealth=true,x=0,y=15}
local potionIDs={[2379]='speed',[2430]='immunity',[3169]='immunity',[24364]='immunity'}
local racialNames={['Elemental Blessing']='speed',['Skysight']='speed'}
local plainsrunningID=1299038 -- Active stacking aura, not the passive racial spell.
local stealthIDs={[1784]=true,[1785]=true,[1786]=true,[1787]=true,[5215]=true,[6783]=true,[9913]=true,[20580]=true,[11327]=true,[11329]=true}
local fallbackIDs={
 [642]='immunity',[1020]='immunity',[498]='defense',[5573]='defense',
 [1022]='immunity',[5599]='immunity',[10278]='immunity',[1044]='immunity',
 [45438]='immunity',[871]='defense',[12975]='defense',[5277]='defense',[26669]='defense',[19263]='defense',
 [2983]='speed',[8696]='speed',[11305]='speed',[1850]='speed',[9821]='speed',
 [14751]='offense',[10060]='offense',[13750]='offense',[13877]='offense',[12328]='offense',[1719]='offense',[20572]='offense',[20554]='offense',[26297]='offense',
}
local function config()
 local s=getSettings();s.shortBuffs=s.shortBuffs or {};local c=s.shortBuffs
 for k,v in pairs(defaults) do if c[k]==nil then c[k]=v end end
 c.minDuration,c.maxDuration=1,30;c.castFallback=true
 c.include=c.include or {};c.exclude=c.exclude or {};c.discovered=c.discovered or {};return c
end
local function safe(v) return not issecretvalue or not issecretvalue(v) end
local function say(s) print('|cffd2b077Trailbound:|r '..s) end
function T.ShouldTrack(a)
 local c=config();if not c.enabled or not a then return false end
 if not safe(a.isHarmful) or not safe(a.isHelpful) or a.isHarmful==true or a.isHelpful==false then return false end
 local id=a.spellId or a.spellID
 if not safe(id) or not safe(a.duration) or not safe(a.expirationTime) then return false end
 if type(id)~='number' or type(a.duration)~='number' or type(a.expirationTime)~='number' then return false end
 if id~=plainsrunningID and id~=14751 and C_Spell and C_Spell.IsSpellPassive then local ok,passive=pcall(C_Spell.IsSpellPassive,id);if ok and passive then return false end end
 local untimed=(stealthIDs[id] or id==plainsrunningID or id==14751) and a.duration==0 and a.expirationTime==0
 if (not untimed and (a.duration<c.minDuration or a.duration>c.maxDuration or a.expirationTime<=GetTime())) or c.exclude[id] then return false end
 local source=safe(a.sourceUnit) and a.sourceUnit
 local mine=source=='player' or source and UnitIsUnit and UnitIsUnit(source,'player')
 if mine and not c.selfCast or not mine and not c.otherCast then return false end
 if potionIDs[id] and not c.potions then return false end
 if c.include[id] then return true,'custom' end
 local racial=safe(a.name) and racialNames[a.name]
 if racial then c.discovered[id]=racial end
 local category=racial or stealthIDs[id] and 'stealth' or potionIDs[id] or ForeverAssistImportantBuffs and ForeverAssistImportantBuffs[id] or fallbackIDs[id] or c.discovered[id]
 return category and c[category]==true or false,category
end
local function readAura(i) return ForeverAssistReadPlayerAura(i) end
local function anchor()
 local c=config();root:ClearAllPoints();root:SetPoint('CENTER',UIParent,'CENTER',c.x,c.y)
end
local function savePosition()
 root:StopMovingOrSizing();local x,y=root:GetCenter();local ux,uy=UIParent:GetCenter();if x and ux then config().x,config().y=x-ux,y-uy end
end
local function startMoving() if T.unlocked and not (InCombatLockdown and InCombatLockdown()) then root:StartMoving() end end
local function create()
 if root then return end
 root=CreateFrame('Frame','ForeverAssistImportantBuffTracker',UIParent,'BackdropTemplate')
 root:SetFrameStrata('HIGH');root:SetMovable(true);root:SetClampedToScreen(true);root:EnableMouse(true);root:RegisterForDrag('LeftButton')
 root:SetScript('OnDragStart',startMoving);root:SetScript('OnDragStop',savePosition)
 root:SetBackdrop({bgFile='Interface/Tooltips/UI-Tooltip-Background'});root:SetBackdropColor(.10,.065,.035,.4)
 anchor();root:Hide()
end
local function icon(i)
 if icons[i] then return icons[i] end
 local b=CreateFrame('Button',nil,root);b.tex=b:CreateTexture(nil,'ARTWORK');b.tex:SetAllPoints();b.tex:SetTexCoord(.07,.93,.07,.93)
 b.cooldown=CreateFrame('Cooldown',nil,b,'CooldownFrameTemplate');b.cooldown:SetAllPoints();b.cooldown:SetDrawEdge(false);b.cooldown:SetHideCountdownNumbers(true)
 b.overlay=CreateFrame('Frame',nil,b);b.overlay:SetAllPoints();b.overlay:SetFrameLevel(b.cooldown:GetFrameLevel()+1)
 b.time=b.overlay:CreateFontString(nil,'OVERLAY','TrailboundText');b.time:SetPoint('CENTER');b.time:SetFont(STANDARD_TEXT_FONT,16,'OUTLINE')
 b.stacks=b.overlay:CreateFontString(nil,'OVERLAY','NumberFontNormal');b.stacks:SetPoint('BOTTOMRIGHT',-2,2)
 b.label=b:CreateFontString(nil,'OVERLAY','TrailboundSmall');b.label:SetPoint('TOP',b,'BOTTOM',0,-3)
 b:RegisterForDrag('LeftButton');b:SetScript('OnDragStart',startMoving);b:SetScript('OnDragStop',savePosition)
 b:SetScript('OnEnter',function(self)
  if not self.aura then return end;GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
  if self.aura.index and GameTooltip.SetUnitAura and ForeverAssistAuraReadable(self.aura.index) then local ok=pcall(GameTooltip.SetUnitAura,GameTooltip,'player',self.aura.index,'HELPFUL');if not ok then GameTooltip:SetSpellByID(self.aura.spellId) end else GameTooltip:SetSpellByID(self.aura.spellId) end
  if self.aura.readUnavailable or self.aura.estimated and self.aura.duration==0 then GameTooltip:AddLine('Last confirmed or cast-estimated state. Combat restrictions may hide early removal.',1,.8,.3,true) end
  if self.aura.estimated then GameTooltip:AddLine("Estimated from your successful cast; may end early if the buff is removed.",1,.8,.3,true) end
  local source=self.aura.sourceUnit
  if source and safe(source) then GameTooltip:AddLine('From: '..(UnitName(source) or source),.7,.7,.7) end
  GameTooltip:AddLine('Edit spell rules in options • ID '..self.aura.spellId,.7,.7,.7);GameTooltip:Show()
 end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 b:SetScript('OnClick',nil)
 icons[i]=b;return b
end
function T.Refresh()
 if T.suspended then if root then root:Hide() end;return end
 if not getSettings then return end;create();local c=config();local previous=active;active={}
 T.auraUnavailable=false
 if c.enabled then
  for i=1,255 do
   local a,readable=readAura(i);if not readable then active={};T.auraUnavailable=true;break end;if not a then break end
   if T.ShouldTrack(a) and not (a.spellId==14751 and focusConsumed) then
    active[#active+1]={name=safe(a.name) and a.name or 'Buff',spellId=a.spellId or a.spellID,icon=safe(a.icon) and a.icon or 134400,
     applications=safe(a.applications) and a.applications or 0,duration=a.duration,expirationTime=a.expirationTime,sourceUnit=safe(a.sourceUnit) and a.sourceUnit,index=i,auraInstanceID=a.auraInstanceID,isHelpful=true}
   end
  end
 end
 if T.auraUnavailable and c.enabled then
  -- Keep only last confirmed, still-unexpired entries when enumeration is unavailable.
  for _,a in ipairs(previous) do
   if not a.estimated and not (a.spellId==14751 and focusConsumed) and (a.duration==0 or a.expirationTime>GetTime()) and T.ShouldTrack(a) then a.readUnavailable=true;active[#active+1]=a end
  end
 end
 local seen={};for _,a in ipairs(active) do if not a.readUnavailable then seen[a.spellId]=true end end
 for id,a in pairs(castEstimates) do
  if seen[id] or a.duration>0 and a.expirationTime<=GetTime() or a.duration==0 and not T.auraUnavailable and GetTime()-(a.castAt or 0)>.5 then castEstimates[id]=nil
  elseif c.castFallback and T.ShouldTrack(a) then
   local replaced=false
   for i,entry in ipairs(active) do if entry.spellId==id then active[i]=a;replaced=true;break end end
   if not replaced then active[#active+1]=a end
  end
 end
 table.sort(active,function(a,b) if a.expirationTime~=b.expirationTime then return a.expirationTime<b.expirationTime end;return a.spellId<b.spellId end)
 local list=active
 if T.unlocked and #list==0 then list={{name='Drag tracker',icon=134400,preview=true,spellId=642,duration=20,expirationTime=GetTime()+20},{name='Preview',icon=134400,preview=true,spellId=10060,duration=15,expirationTime=GetTime()+15}} end
 local size=c.iconSize;local columns=c.columns;local pitch=size+(c.showNames and 23 or 8)
 root:SetSize(math.max(1,math.min(columns,math.max(1,#list))*(size+8)),math.max(1,math.ceil(math.max(1,#list)/columns)*pitch))
 root:SetBackdropColor(.1,.4,.15,T.unlocked and .4 or 0);root:SetFrameStrata(T.unlocked and 'TOOLTIP' or 'HIGH')
 for i,a in ipairs(list) do
  local b=icon(i);b.aura=a;b:SetSize(size,size);b:ClearAllPoints();b:SetPoint('TOPLEFT',((i-1)%columns)*(size+8),-math.floor((i-1)/columns)*pitch)
  b.tex:SetTexture(a.icon or 134400);if a.duration>0 then b.cooldown:SetCooldown(a.expirationTime-a.duration,a.duration) else b.cooldown:Clear() end
  local stacks=a.applications or 0;b.stacks:SetText((stacks>1 or a.spellId==plainsrunningID and stacks>0) and stacks or '');b.label:SetWidth(size+6);b.label:SetText(c.showNames and a.name or '');b:Show()
 end
 for i=#list+1,#icons do icons[i]:Hide();icons[i].aura=nil end
 root:SetShown(T.unlocked or c.enabled and #list>0 and (not c.combatOnly or UnitAffectingCombat('player')))
end
function T.Update()
 if not root or not root:IsShown() then return end
 local expired=false
 for _,b in ipairs(icons) do
  if b.aura and b:IsShown() then
   local remaining=math.max(0,b.aura.expirationTime-GetTime())
   b.time:SetText((b.aura.duration==0 and 'Active' or remaining<10 and ('%.1f'):format(remaining) or tostring(math.ceil(remaining)))..((b.aura.readUnavailable or b.aura.estimated) and '?' or ''))
   b.time:SetTextColor(1,b.aura.duration>0 and remaining<=5 and .25 or 1,b.aura.duration>0 and remaining<=5 and .25 or 1)
   if remaining==0 and b.aura.duration>0 and not b.aura.preview then expired=true end
  end
 end
 if expired then T.Refresh() end
end
local function button(parent,label,x,y,width,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(width,24);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',fn);if ForeverAssistStyleButton then ForeverAssistStyleButton(b) end;return b
end
local catalogue,catalogueRows,search=nil,{},nil
local categoryNames={immunity='Immunity / freedom',defense='Defense / shields',speed='Movement',offense='Damage / haste',stealth='Stealth',custom='Custom'}
function T.RefreshCatalogue()
 if not catalogue then return end
 local c=config();local ids={}
 for id,cat in pairs(ForeverAssistImportantBuffs or {}) do ids[id]=cat end
 for id,cat in pairs(fallbackIDs) do ids[id]=ids[id] or cat end
 for id,cat in pairs(c.discovered) do ids[id]=cat end
 for id,cat in pairs(potionIDs) do ids[id]=cat end
 for id in pairs(stealthIDs) do ids[id]='stealth' end
 for id in pairs(c.include) do ids[id]=ids[id] or 'custom' end
 for id in pairs(c.exclude) do ids[id]=ids[id] or 'custom' end
 local list={};local query=search:GetText():lower()
 for id,category in pairs(ids) do
  local info=C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
  local name=info and info.name or ForeverAssistImportantBuffNames and ForeverAssistImportantBuffNames[id] or ('Spell '..id)
  if query=='' or name:lower():find(query,1,true) or tostring(id):find(query,1,true) then list[#list+1]={id=id,name=name,category=category,icon=info and info.iconID or 134400} end
 end
 table.sort(list,function(a,b) if a.name~=b.name then return a.name<b.name end;return a.id<b.id end)
 for _,row in ipairs(catalogueRows) do row:Hide() end
 for i,e in ipairs(list) do
  local row=catalogueRows[i]
  if not row then
   row=CreateFrame('Frame',nil,catalogue.content);row:SetSize(525,38);row.check=CreateFrame('CheckButton',nil,row,'UICheckButtonTemplate');row.check:SetPoint('LEFT',0,0)
   row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(28,28);row.icon:SetPoint('LEFT',row.check,'RIGHT',4,0)
   row.name=row:CreateFontString(nil,'OVERLAY','TrailboundSmall');row.name:SetPoint('TOPLEFT',70,-5);row.name:SetWidth(280);row.name:SetJustifyH('LEFT')
   row.detail=row:CreateFontString(nil,'OVERLAY','TrailboundMuted');row.detail:SetPoint('BOTTOMLEFT',70,5)
   row.status=row:CreateFontString(nil,'OVERLAY','TrailboundSmall');row.status:SetPoint('RIGHT',-5,0)
   row.check:SetScript('OnClick',function(self) local id=self:GetParent().entry.id;if self:GetChecked() then config().exclude[id]=nil;config().include[id]=true else config().exclude[id]=true;config().include[id]=nil end;T.Refresh();T.RefreshCatalogue() end)
   row:EnableMouse(true);row:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetSpellByID(self.entry.id);GameTooltip:AddLine('Rules still require a helpful aura and the caster and category rules.',1,1,1,true);GameTooltip:Show() end);row:SetScript('OnLeave',function() GameTooltip:Hide() end)
   catalogueRows[i]=row
  end
  row.entry=e;row:SetPoint('TOPLEFT',0,-(i-1)*38);row.icon:SetTexture(e.icon);row.name:SetText(e.name);row.detail:SetText((categoryNames[e.category] or e.category)..' • ID '..e.id)
  row.check:SetChecked(not c.exclude[e.id]);row.status:SetText(c.exclude[e.id] and 'Excluded' or c.include[e.id] and 'Included' or (c[e.category]==false or potionIDs[e.id] and not c.potions) and 'Category off' or 'Automatic');row:Show()
 end
 catalogue.content:SetHeight(math.max(1,#list*38))
end
function T.Catalogue()
 if T.suspended then return end
 if not catalogue then
  catalogue=CreateFrame('Frame','ForeverAssistBuffCatalogue',UIParent,'BackdropTemplate');catalogue:SetSize(600,530);catalogue:SetPoint('CENTER');catalogue:SetFrameStrata('DIALOG');catalogue:SetClampedToScreen(true);catalogue:SetMovable(true);catalogue:EnableMouse(true);catalogue:RegisterForDrag('LeftButton');catalogue:SetScript('OnDragStart',catalogue.StartMoving);catalogue:SetScript('OnDragStop',catalogue.StopMovingOrSizing)
  catalogue:SetBackdrop({bgFile='Interface/Tooltips/UI-Tooltip-Background',edgeFile='Interface/Tooltips/UI-Tooltip-Border',edgeSize=16,insets={left=4,right=4,top=4,bottom=4}});catalogue:SetBackdropColor(.10,.065,.035,.97)
  local title=catalogue:CreateFontString(nil,'OVERLAY','TrailboundTitle');title:SetPoint('TOP',0,-15);title:SetText('Important buff spell rules')
  local close=CreateFrame('Button',nil,catalogue,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-3,-3);close.faEditorClose=true;tinsert(UISpecialFrames,'ForeverAssistBuffCatalogue')
  local help=catalogue:CreateFontString(nil,'OVERLAY','TrailboundSmall');help:SetPoint('TOPLEFT',20,-45);help:SetWidth(560);help:SetJustifyH('LEFT');help:SetText('Search by name or spell ID. Uncheck to exclude; check to explicitly include.\nAutomatic rules track short helpful buffs. Stealth and Plainsrunning may be untimed. Elemental Blessing is recognized when received.')
  search=CreateFrame('EditBox',nil,catalogue,'InputBoxTemplate');search:SetSize(545,24);search:SetPoint('TOPLEFT',25,-85);search:SetAutoFocus(false);search:SetScript('OnTextChanged',T.RefreshCatalogue)
  local scroll=CreateFrame('ScrollFrame',nil,catalogue,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',20,-122);scroll:SetPoint('BOTTOMRIGHT',-40,130)
  catalogue.content=CreateFrame('Frame',nil,scroll);catalogue.content:SetSize(525,1);scroll:SetScrollChild(catalogue.content)
  local custom=CreateFrame('EditBox',nil,catalogue,'InputBoxTemplate');custom:SetSize(100,24);custom:SetPoint('TOPLEFT',25,-410);custom:SetAutoFocus(false);custom:SetNumeric(true)
  local label=catalogue:CreateFontString(nil,'OVERLAY','TrailboundSmall');label:SetPoint('TOPLEFT',25,-390);label:SetText('Custom spell ID')
  local function spellID() local id=tonumber(custom:GetText());return id and id>0 and math.floor(id) end
  button(catalogue,'Track spell',140,-410,135,function()local id=spellID();if id then config().include[id]=true;config().exclude[id]=nil;T.Refresh();T.RefreshCatalogue()end end)
  button(catalogue,'Hide spell',285,-410,135,function()local id=spellID();if id then config().exclude[id]=true;config().include[id]=nil;T.Refresh();T.RefreshCatalogue()end end)
  button(catalogue,'Use automatic rule',430,-410,145,function()local id=spellID();if id then config().include[id]=nil;config().exclude[id]=nil;T.Refresh();T.RefreshCatalogue()end end)
  button(catalogue,'Use automatic rules for all spells',20,-447,560,function()config().include={};config().exclude={};T.Refresh();T.RefreshCatalogue()end)
  button(catalogue,'Back to buff options',20,-485,560,function() catalogue:Hide();T.Options() end)
  catalogue:Hide()
 end
 T.RefreshCatalogue();if catalogue:IsShown() then catalogue:Hide() elseif ForeverAssistShowEditor then ForeverAssistShowEditor(catalogue) else catalogue:Show() end
end

function T.Options()
 if T.suspended then return end
 if not getSettings then return end
 if not options then
  options=CreateFrame('Frame','ForeverAssistImportantBuffOptions',UIParent,'BackdropTemplate');options:SetSize(490,600);options:SetPoint('CENTER');options:SetFrameStrata('DIALOG');options:SetClampedToScreen(true);options:EnableMouse(true);options:SetMovable(true);options:RegisterForDrag('LeftButton');options:SetScript('OnDragStart',options.StartMoving);options:SetScript('OnDragStop',options.StopMovingOrSizing)
  options:SetBackdrop({bgFile='Interface/Tooltips/UI-Tooltip-Background',edgeFile='Interface/Tooltips/UI-Tooltip-Border',edgeSize=16,insets={left=4,right=4,top=4,bottom=4}});options:SetBackdropColor(.10,.065,.035,.97)
  local title=options:CreateFontString(nil,'OVERLAY','TrailboundTitle');title:SetPoint('TOP',0,-15);title:SetText('Important short buffs')
  local close=CreateFrame('Button',nil,options,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-3,-3);close.faEditorClose=true;tinsert(UISpecialFrames,'ForeverAssistImportantBuffOptions')
  local entries={{'enabled','Enable tracker'},{'combatOnly','Only show in combat'},{'selfCast','My own spells'},{'otherCast','Other players / unknown caster'},{'immunity','Immunity / freedom'},{'defense','Damage reduction / shields'},{'speed','Movement speed'},{'offense','Damage / haste / stat boosts'},{'potions','Short potion effects'},{'showNames','Show buff names'},{'stealth','Stealth / Prowl / Shadowmeld'}}
  for i,e in ipairs(entries) do local key,label=e[1],e[2];local cb=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate');cb:SetPoint('TOPLEFT',20+((i-1)%2)*235,-45-math.floor((i-1)/2)*30)
   local t=cb:CreateFontString(nil,'OVERLAY','TrailboundSmall');t:SetPoint('LEFT',cb,'RIGHT',0,0);t:SetText(label)
   cb:SetScript('OnClick',function(self) config()[key]=self:GetChecked() and true or false;T.Refresh() end);cb:HookScript('OnShow',function(self) self:SetChecked(config()[key]) end)
  end
  local function number(label,key,x,y,min,max)
   local t=options:CreateFontString(nil,'OVERLAY','TrailboundSmall');t:SetPoint('TOPLEFT',x,y);t:SetText(label)
   local input=CreateFrame('EditBox',nil,options,'InputBoxTemplate');input:SetSize(70,24);input:SetPoint('TOPLEFT',x+145,y+4);input:SetAutoFocus(false);input:SetNumeric(true)
   input:HookScript('OnShow',function(self) self:SetText(config()[key]) end)
   input:SetScript('OnEnterPressed',function(self) local n=tonumber(self:GetText());if n then config()[key]=math.max(min,math.min(max,math.floor(n)));local c=config();if c.minDuration>c.maxDuration then c.maxDuration=c.minDuration end end;self:SetText(config()[key]);self:ClearFocus();T.Refresh() end)
  end
  number('Icon size','iconSize',20,-235,20,80);number('Icons per row','columns',255,-235,1,12)
  button(options,'Unlock / lock position',20,-280,215,function() T.unlocked=not T.unlocked;T.Refresh() end)
  button(options,'Reset position',255,-280,215,function() config().x,config().y=0,15;anchor();T.Refresh() end)
  button(options,'Browse tracked spell rules',20,-325,450,function() options:Hide();T.Catalogue() end)
  local help=options:CreateFontString(nil,'OVERLAY','TrailboundSmall');help:SetPoint('TOPLEFT',20,-375);help:SetWidth(450);help:SetJustifyH('LEFT');help:SetText('Choose individual spells in Browse tracked spell rules.\nBerserking uses a cast-based timer if its aura is restricted in combat; this does not estimate haste strength.\nUnlock to drag the tracker. Settings are included in saved profiles.')
  button(options,'Back to settings',20,-565,450,function() options:Hide();if ForeverAssistOptions then ForeverAssistOptions:Show() end end)
  options:SetScript('OnHide',function() T.unlocked=false;T.Refresh() end);options:Hide()
 end
 if options:IsShown() then options:Hide() elseif ForeverAssistShowEditor then ForeverAssistShowEditor(options) else if ForeverAssistPlay then ForeverAssistPlay.CloseOptions() end;options:Show() end
end
local events=CreateFrame('Frame');local clock,accessClock=0,0
function T.CastSent(unit,target,guid,id)
 if unit~='player' or not safe(id) or not shieldIDs[id] or not safe(guid) or type(guid)~='string' or not safe(target) or type(target)~='string' then return end
 local name=UnitName('player');if not name then return end;local realm=GetRealmName and GetRealmName()
 sentCasts[guid]={selfTarget=target==name or realm and target==name..'-'..realm:gsub('%s',''),at=GetTime()}
 for key,value in pairs(sentCasts) do if GetTime()-value.at>15 then sentCasts[key]=nil end end
end
local function consumesFocus(id)
 if not focusSpells then
  focusSpells={}
  for _,spell in ipairs(ForeverAssistSpellData and ForeverAssistSpellData.PRIEST or {}) do
   -- Desperate Prayer is free and does not consume the next mana-spell effect.
   if spell.name~='Desperate Prayer' and spell.name~='Inner Focus' then focusSpells[spell.spellID]=true end
  end
 end
 return focusSpells[id]==true
end
function T.CastSucceeded(unit,id,guid)
 if unit~='player' or not safe(id) or not getSettings then return end
 local focused=castEstimates[14751]~=nil
 for _,a in ipairs(active) do if a.spellId==14751 then focused=true;break end end
 local consumed=focused and id~=14751 and consumesFocus(id)
 if consumed then
  focusConsumed=true;castEstimates[14751]=nil
  for i=#active,1,-1 do if active[i].spellId==14751 then table.remove(active,i) end end
 end
 if id==14751 then focusConsumed=false end
 if (not castDuration[id] and not castUntimed[id]) or not config().castFallback then if consumed then T.Refresh() end;return end
 if shieldIDs[id] then
  local sent=safe(guid) and sentCasts[guid];if safe(guid) and guid then sentCasts[guid]=nil end
  if not sent or not sent.selfTarget then T.Refresh();return end
  -- Remove stale shield ranks so reapplication produces one refreshed shield timer.
  for key in pairs(castEstimates) do if shieldIDs[key] then castEstimates[key]=nil end end
  for i=#active,1,-1 do if shieldIDs[active[i].spellId] then table.remove(active,i) end end
 end
 local info=C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
 castEstimates[id]={spellId=id,name=info and info.name or (id==14751 and 'Inner Focus' or shieldIDs[id] and 'Power Word: Shield' or 'Berserking'),icon=info and info.iconID or 136012,applications=0,duration=castDuration[id] or 0,expirationTime=castDuration[id] and GetTime()+castDuration[id] or 0,castAt=GetTime(),sourceUnit='player',isHelpful=true,estimated=true}
 T.Refresh()
end
function T.Initialize(get)
 getSettings=get;focusSpells=nil;config()
 for _,e in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_SENT','UNIT_AURA','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED'}) do pcall(events.RegisterEvent,events,e) end
end
function T.ApplySettings() if getSettings then config();create();anchor();T.Refresh() end end
function T.RemovedAuras(info)
 if type(info)~='table' or issecrettable and issecrettable(info) then return end
 local removed=info.removedAuraInstanceIDs
 if type(removed)~='table' or issecrettable and issecrettable(removed) then return end
 for _,id in ipairs(removed) do if safe(id) then
  for i=#active,1,-1 do if active[i].auraInstanceID and active[i].auraInstanceID==id then castEstimates[active[i].spellId]=nil;table.remove(active,i) end end
 end end
end
function T.AuraUpdate(info)
 T.RemovedAuras(info)
 if type(info)~='table' or issecrettable and issecrettable(info) then return end
 local added=info.addedAuras
 if type(added)~='table' or issecrettable and issecrettable(added) then return end
 for _,data in ipairs(added) do
  local a=ForeverAssistCleanAura and ForeverAssistCleanAura(data)
  if a and T.ShouldTrack(a) then
   if a.spellId==14751 then focusConsumed=false end
   if shieldIDs[a.spellId] then
    for id in pairs(castEstimates) do if shieldIDs[id] then castEstimates[id]=nil end end
    for i=#active,1,-1 do if shieldIDs[active[i].spellId] then table.remove(active,i) end end
   end
   for i=#active,1,-1 do if active[i].spellId==a.spellId or a.auraInstanceID and active[i].auraInstanceID==a.auraInstanceID then table.remove(active,i) end end
   a.isHelpful=true;active[#active+1]=a;castEstimates[a.spellId]=nil
  end
 end
end
events:SetScript('OnEvent',function(_,event,unit,arg2,arg3,arg4)
 if T.suspended then return end
 if event=='UNIT_SPELLCAST_SENT' then T.CastSent(unit,arg2,arg3,arg4)
 elseif event=='UNIT_SPELLCAST_SUCCEEDED' then T.CastSucceeded(unit,arg3,arg2)
 elseif getSettings and (event~='UNIT_AURA' or unit=='player') then
  if event=='UNIT_AURA' then T.AuraUpdate(arg2) end
  T.Refresh()
 end
end)
events:SetScript('OnUpdate',function(_,elapsed) if not getSettings then return end;accessClock=accessClock+elapsed;if accessClock>=1 then accessClock=0;if T.auraUnavailable or not ForeverAssistAuraReadable() then T.Refresh() end end;clock=clock+elapsed;if clock>=.1 then clock=0;T.Update() end end)
