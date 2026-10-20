-- Original utility UI; no third-party addon code is embedded.
ForeverAssistPlay = {}
ForeverAssistPlay.Version='1.8.46'
local P=ForeverAssistPlay
local account,character,settings
local function say(s) print('|cffd2b077Trailbound:|r '..s) end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function duration(n) n=math.max(0,math.floor(n or 0));return ('%dh %02dm %02ds'):format(math.floor(n/3600),math.floor(n/60)%60,n%60) end
local function text(parent) return parent:CreateFontString(nil,'OVERLAY','TrailboundSmall') end
local function button(parent,label,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w or 150,24);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',fn);if ForeverAssistStyleButton then ForeverAssistStyleButton(b) end;return b
end
local function window(name,title,w,h)
 local f=CreateFrame('Frame',name,UIParent,'BackdropTemplate');f:SetSize(w,h);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG')
 TrailboundTheme.Panel(f)
 local t=text(f);t:SetPoint('TOP',0,-15);t:SetText(title);button(f,'X',w-35,-8,25,function() f:Hide() end)
 f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag('LeftButton');f:SetScript('OnDragStart',function(self) self:StartMoving() end);f:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
 if UISpecialFrames then table.insert(UISpecialFrames,name) end;f:Hide();return f
end
local function position(f,key,x,y)
 local p=settings()[key];f:ClearAllPoints();f:SetPoint('CENTER',UIParent,'CENTER',p and p[1] or x,p and p[2] or y)
end
local function movable(f,key)
 f:EnableMouse(true);f:SetMovable(true);f:SetClampedToScreen(true);f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',function(self) if not combat() and (key~='xpPosition' or not settings().xpLocked) and (key~='swingPosition' or P.swingUnlocked) and (key~='nutritionPosition' or P.nutritionUnlocked) then self:StartMoving() end end)
 f:SetScript('OnDragStop',function(self) self:StopMovingOrSizing();local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter();if x and ux then settings()[key]={x-ux,y-uy} end end)
end
function P.ApplyLayout()
 if not settings or combat() then return end
 for _,entry in ipairs({{'ForeverAssistXP','xpPosition',0,-210},{'ForeverAssistSwings','swingPosition',0,-140},{'ForeverAssistNutrition','nutritionPosition',0,145},{'ForeverAssistCampSit','campSitPosition',0,-65},{'ForeverAssistCampWelcome','campWelcomePosition',0,75}}) do
  local f=_G[entry[1]];if f then position(f,entry[2],entry[3],entry[4]) end
 end
end
local function known(id)
 if C_SpellBook and C_SpellBook.IsSpellKnown then local ok,v=pcall(C_SpellBook.IsSpellKnown,id);if ok then return v end end
 return IsSpellKnown and IsSpellKnown(id) or IsPlayerSpell and IsPlayerSpell(id)
end
-- Cache static spell/rank lookups until the spellbook changes.
local paladinCache
-- Paladin blessing alternatives distinguish caster and compare known ranks.
function P.PaladinReminder(auras)
 if not paladinCache then
 local families={might={"Blessing of Might","Greater Blessing of Might"},wisdom={"Blessing of Wisdom","Greater Blessing of Wisdom"},kings={"Blessing of Kings","Greater Blessing of Kings"},sanctuary={"Blessing of Sanctuary","Greater Blessing of Sanctuary"},light={"Blessing of Light","Greater Blessing of Light"},salvation={"Blessing of Salvation","Greater Blessing of Salvation"}}
 local byID,byName,best={},{},{}
 for _,spell in ipairs(ForeverAssistSpellData.PALADIN or {}) do
  for family,names in pairs(families) do
   if spell.name==names[1] or spell.name==names[2] then
    local info=C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell.spellID)
    local entry={family=family,level=spell.level,id=spell.spellID,name=info and info.name or spell.name,icon=info and info.iconID}
    byID[spell.spellID]=entry;byName[spell.name]=entry;if info then byName[info.name]=entry end
    if known(spell.spellID) and (not best[family] or best[family].level<entry.level or (best[family].level==entry.level and spell.name==names[1])) then best[family]=entry end
   end
  end
 end
 paladinCache={byID=byID,byName=byName,best=best}
 end
 local byID,byName,best=paladinCache.byID,paladinCache.byName,paladinCache.best
 local foreign,own={},{}
 for _,a in ipairs(auras or {}) do
  local e=byID[a.spellId or a.spellID] or byName[a.name]
  if e then
   local source=a.sourceUnit;local mine=source=='player' or source and UnitIsUnit and UnitIsUnit(source,'player')
   local target=mine and own or foreign
   target[e.family]=math.max(target[e.family] or 0,e.level)
  end
 end
 for family,level in pairs(own) do
  local b=best[family];if b and b.level>level then return {label=b.name.." (higher rank)",icon=b.icon,spell=b.name} end
  return nil
 end
 local highest,index=0,3
 if GetTalentTabInfo then for i=1,3 do local _,_,points=GetTalentTabInfo(i);if type(points)=='number' and points>highest then highest,index=points,i end end end
 local spec=({'holy','protection','retribution'})[index]

 local priorities=spec=='holy' and {'wisdom','kings','might','sanctuary'} or spec=='protection' and {'sanctuary','kings','might','wisdom'} or {'might','kings','wisdom','sanctuary'}
 -- Upgrade weaker blessings first; otherwise complement an equal or stronger foreign blessing.
 for _,family in ipairs(priorities) do local b=best[family];if b and foreign[family] and b.level>foreign[family] then return {label=b.name.." (higher rank)",icon=b.icon,spell=b.name} end end
 for _,family in ipairs(priorities) do local b=best[family];if b and not foreign[family] then return {label=b.name,icon=b.icon,spell=b.name} end end
 return nil
end
-- Buying back pauses automatic sales for this vendor visit and remembers the item type.
local buybackRows,paused={},false
function P.CacheBuybacks()
 if not GetNumBuybackItems or not GetBuybackItemLink then return end
 for i=1,GetNumBuybackItems() do local l=GetBuybackItemLink(i);buybackRows[i]=l and tonumber(l:match('item:(%d+)')) or nil end
end
function P.BoughtBack(index)
 if not character then return end
 paused=true;ForeverAssistExtras.CancelAutomaticSale()
 local id=buybackRows[index];if id then character.keptJunk[id]=true;say('Bought-back item protected from automatic selling. /tbplay keep clear clears this list.') end
end
function P.AutoSellAllowed(id) return not paused and not (character and character.keptJunk[id]) end
-- Filter only recognized resource/range/cooldown errors; keep other errors visible.
local suppressed={}
local errorNames={'ERR_OUT_OF_RANGE','ERR_SPELL_OUT_OF_RANGE','ERR_SPELL_COOLDOWN','ERR_ABILITY_COOLDOWN','ERR_ITEM_COOLDOWN','ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS','ERR_SPELL_FAILED_NOT_READY','ERR_SPELL_FAILED_S','SPELL_FAILED_OUT_OF_RANGE','SPELL_FAILED_NOT_READY','SPELL_FAILED_NO_POWER','SPELL_FAILED_SPELL_IN_PROGRESS','SPELL_FAILED_CASTER_AURASTATE'}
local errorNumbers={}
local errorRelay,errorRelayActive,lastError,lastErrorAt
local function setupErrors()
 for _,suffix in ipairs({'NO_ATTACK_TARGET','ATTACK_NO_ACTIONS','GENERIC_NO_VALID_TARGETS','GENERIC_NO_TARGET','INVALID_ATTACK_TARGET','SPELL_FAILED_BAD_TARGETS','OUT_OF_RANGE','SPELL_OUT_OF_RANGE','SPELL_COOLDOWN','ABILITY_COOLDOWN','ITEM_COOLDOWN','OUT_OF_MANA','OUT_OF_RAGE','OUT_OF_ENERGY','OUT_OF_FOCUS','OUT_OF_POWER_DISPLAY','SPELL_FAILED_ANOTHER_IN_PROGRESS'}) do local id=_G['LE_GAME_ERR_'..suffix];if type(id)=='number' then errorNumbers[id]=true end end
 for _,n in ipairs(errorNames) do if _G[n] and n~='ERR_SPELL_FAILED_S' then suppressed[_G[n]]=true end;if Enum and Enum.GameError and Enum.GameError[n] then errorNumbers[Enum.GameError[n]]=true end end
 for _,n in ipairs({'SPELL_FAILED_NO_MANA','SPELL_FAILED_NO_RAGE','SPELL_FAILED_NO_ENERGY','SPELL_FAILED_NO_FOCUS','ERR_NOT_ENOUGH_MANA','ERR_NOT_ENOUGH_RAGE','ERR_NOT_ENOUGH_ENERGY','ERR_NOT_ENOUGH_FOCUS','ERR_OUT_OF_MANA','ERR_OUT_OF_RAGE','ERR_OUT_OF_ENERGY','ERR_OUT_OF_FOCUS','ERR_NO_ATTACK_TARGET','SPELL_FAILED_NO_TARGETS','ERR_GENERIC_NO_TARGET','ERR_GENERIC_NO_VALID_TARGETS','SPELL_FAILED_BAD_TARGETS','SPELL_FAILED_NO_VALID_TARGETS','ERR_INVALID_ATTACK_TARGET','ERR_ATTACK_NO_ACTIONS'}) do if _G[n] then suppressed[_G[n]]=true end end
 if not UIErrorsFrame then return end
 -- Never replace Blizzard scripts or methods. Own only this event while the
 -- filter is enabled, and render allowed errors through the engine method.
 if not errorRelay then
  errorRelay=CreateFrame('Frame')
  errorRelay:SetScript('OnEvent',function(_,event,id,message)
   local msg=type(message)=='string' and message or type(id)=='string' and id
   if not msg then return end
   local restricted=issecretvalue and (issecretvalue(msg) or issecretvalue(id))
   local voice,sound
   if not restricted and type(id)=='number' and GetGameMessageInfo then
    local ok,key,kit,vocal=pcall(GetGameMessageInfo,id)
    if ok then
     if type(key)=='string' and suppressed[_G[key]] then errorNumbers[id]=true end
     voice,sound=vocal,kit
    end
   end
   if not restricted then
    if settings().quietErrors and (suppressed[msg] or errorNumbers[id]) then return end
    local now=GetTime();if msg==lastError and now-(lastErrorAt or 0)<.5 then return end
    lastError,lastErrorAt=msg,now
   end
   if UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg,1,.1,.1,1) end
   if not restricted then
    if voice and C_Sound and C_Sound.PlayVocalErrorSound then C_Sound.PlayVocalErrorSound(voice)
    elseif sound and PlaySound then PlaySound(sound) end
   end
  end)
 end
 if settings().quietErrors then
  UIErrorsFrame:UnregisterEvent('UI_ERROR_MESSAGE');errorRelay:RegisterEvent('UI_ERROR_MESSAGE');errorRelayActive=true
 elseif errorRelayActive then
  errorRelay:UnregisterEvent('UI_ERROR_MESSAGE');UIErrorsFrame:RegisterEvent('UI_ERROR_MESSAGE');errorRelayActive=false
 end
end
-- Mail addresses are realm scoped. Sending is still a manual Blizzard action.
local mailPending,mailRows,mailWindow
function P.MailNames()
 local names={};local realm=GetRealmName();local me=UnitName('player');local seen={}
 for name in pairs(account.mailRecipients[realm] or {}) do if name~=me then seen[name]=true end end
 for _,c in pairs(account.characters or {}) do if c.realm==realm and c.name~=me then seen[c.name]=true end end
 for n in pairs(seen) do names[#names+1]=n end;table.sort(names);return names
end
function P.RememberRecipient(name)
 if type(name)~='string' then return end;name=name:match('^%s*(.-)%s*$');if name=='' then return end
 local realm=GetRealmName();account.mailRecipients[realm]=account.mailRecipients[realm] or {};account.mailRecipients[realm][name]=true
end
function P.MailMenu()
 if not mailWindow then mailWindow=window('ForeverAssistMailRecipients','Remembered mail recipients',320,360);mailRows={} end
 for _,r in ipairs(mailRows) do r:Hide() end
 local names=P.MailNames()
 if not mailWindow.content then
  local scroll=CreateFrame('ScrollFrame',nil,mailWindow,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',15,-45);scroll:SetPoint('BOTTOMRIGHT',-35,20)
  mailWindow.content=CreateFrame('Frame',nil,scroll);mailWindow.content:SetSize(260,1);scroll:SetScrollChild(mailWindow.content)
 end
 for i,n in ipairs(names) do local name=n;local b=mailRows[i] or button(mailWindow.content,'',0,-(i-1)*27,255,function() end);mailRows[i]=b;b:SetText(name);b:SetScript('OnClick',function() if SendMailNameEditBox then SendMailNameEditBox:SetText(name);SendMailNameEditBox:ClearFocus() end;mailWindow:Hide() end);b:Show() end
 mailWindow.content:SetHeight(math.max(1,#names*27));mailWindow:SetShown(not mailWindow:IsShown())
end
local function hookMail()
 if SendMailFrame and not SendMailFrame.faRecipients then SendMailFrame.faRecipients=button(SendMailFrame,'Recipients',180,-38,100,P.MailMenu) end
end
-- Completed quest rewards: query by quest ID without changing the selected quest.
function P.QuestXP()
 local rows,total,unknown={},0,0
 if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then return rows,total,unknown end
 for i=1,C_QuestLog.GetNumQuestLogEntries() do
  local q=C_QuestLog.GetInfo(i)
  if q and not q.isHeader and q.questID and C_QuestLog.IsComplete(q.questID) then
   local xp; if GetQuestLogRewardXP then local ok,v=pcall(GetQuestLogRewardXP,q.questID);if ok and type(v)=='number' then xp=v end end
   if xp then total=total+xp else unknown=unknown+1 end
   rows[#rows+1]={name=q.title or tostring(q.questID),xp=xp,id=q.questID}
  end
 end
 return rows,total,unknown
end
local xpFrame,xpFill,questFill,restFill,xpLabels,sessionStart,sessionXP= nil,nil,nil,nil,nil,0,0
local prevXP,prevMax,prevLevel,playedTotal,playedLevel,playedAt,levelPlayedAt
local questRows,questTotal,questUnknown={},0,0
-- Use only kill-XP chat events, so quest/exploration rewards cannot inflate this estimate.
local mobSamples,mobPatterns={},nil
local function xpPattern(template)
 local parts,types={},{};local offset=1
 while true do
  local first,last,slot,kind=template:find('%%(%d*)%$?([sd])',offset)
  if not first then parts[#parts+1]=template:sub(offset):gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1');break end
  parts[#parts+1]=template:sub(offset,first-1):gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1')
  parts[#parts+1]=kind=='d' and '([%d,%.%s]+)' or '(.-)'
  types[#types+1]={kind=kind,slot=tonumber(slot) or #types+1};offset=last+1
 end
 return '^'..table.concat(parts)..'$',types
end
function P.RecordMobXP(message)
 if type(message)~='string' or issecretvalue and issecretvalue(message) then return end
 if not mobPatterns then
  mobPatterns={}
  for key,value in pairs(_G) do
   if type(key)=='string' and key:match('^COMBATLOG_XPGAIN_FIRSTPERSON') and type(value)=='string' then
    local pattern,types=xpPattern(value);mobPatterns[#mobPatterns+1]={pattern=pattern,types=types}
   end
  end
 end
 for _,rule in ipairs(mobPatterns) do
  local matches={message:match(rule.pattern)}
  if #matches>0 then
   for i,t in ipairs(rule.types) do
    if t.kind=='d' and t.slot==2 then
     local gain=tonumber(((matches[i] or ''):gsub('[,%s%.]','')))
     if gain and gain>0 then
      mobSamples[#mobSamples+1]={xp=gain,at=GetTime(),level=UnitLevel('player')}
      if #mobSamples>20 then table.remove(mobSamples,1) end
     end
     return
    end
   end
  end
 end
end
function P.MobEstimate(needed)
 local total,count=0,0;local now,level=GetTime(),UnitLevel('player')
 for i=#mobSamples,1,-1 do
  local sample=mobSamples[i]
  if sample.level~=level or now-sample.at>600 then table.remove(mobSamples,i)
  else total=total+sample.xp;count=count+1 end
 end
 if count==0 then return nil end
 local average=total/count;return math.ceil(math.max(0,needed)/average),average,count
end
function P.RecordXP()
 local x,m,l=UnitXP('player'),UnitXPMax('player'),UnitLevel('player')
 if prevXP then
  if l==prevLevel then sessionXP=sessionXP+math.max(0,x-prevXP)
  elseif l==prevLevel+1 then sessionXP=sessionXP+math.max(0,prevMax-prevXP+x);playedLevel=0;levelPlayedAt=GetTime()
  else prevXP=nil;say('XP rate resumed after a level jump; skipped levels cannot be measured accurately.') end
 end
 prevXP,prevMax,prevLevel=x,m,l
end
function P.RefreshQuests() questRows,questTotal,questUnknown=P.QuestXP() end
local function createXP()
 xpFrame=CreateFrame('Frame','ForeverAssistXP',UIParent,'BackdropTemplate');xpFrame:SetSize(600,24);position(xpFrame,'xpPosition',0,-210);movable(xpFrame,'xpPosition')
 xpFrame:SetBackdrop({bgFile='Interface/Buttons/WHITE8X8'});xpFrame:SetBackdropColor(.10,.065,.035,.85)
 local function fill(r,g,b) local t=xpFrame:CreateTexture(nil,'ARTWORK');t:SetColorTexture(r,g,b,1);t:SetHeight(22);return t end
 xpFill=fill(.1,.8,.25);questFill=fill(1,.82,.05);restFill=fill(.15,.45,1)
 local function label(anchor,relative,x,y,width,justify)
  local t=text(xpFrame);t:SetPoint(anchor,xpFrame,relative,x,y);t:SetWidth(width);t:SetJustifyH(justify);t:SetFont(STANDARD_TEXT_FONT,11,'OUTLINE');return t
 end
 xpLabels=label('CENTER','CENTER',0,0,300,'CENTER')
 xpFrame.levelLabel=label('LEFT','LEFT',4,0,120,'LEFT')
 xpFrame.percentLabel=label('RIGHT','RIGHT',-4,0,120,'RIGHT')
 xpFrame.levelTimeLabel=label('BOTTOMLEFT','TOPLEFT',2,3,290,'LEFT')
 xpFrame.sessionLabel=label('BOTTOMRIGHT','TOPRIGHT',-2,3,290,'RIGHT')
 xpFrame.rateLabel=label('TOPLEFT','BOTTOMLEFT',2,-3,395,'LEFT')
 xpFrame.bonusLabel=label('TOPRIGHT','BOTTOMRIGHT',-2,-3,200,'RIGHT')
 xpFrame:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:AddLine('Experience');if xpFrame.details then for line in xpFrame.details:gmatch('[^\n]+') do GameTooltip:AddLine(line,1,1,1) end end;GameTooltip:AddLine('Completed quest rewards')
  for _,q in ipairs(questRows) do GameTooltip:AddDoubleLine(q.name,q.xp and (q.xp..' XP') or 'Loading / unavailable') end
  GameTooltip:AddLine('Green: earned XP. Yellow: completed quests. Blue: rested XP.',.7,.7,.7)
  GameTooltip:AddLine('Quest and rested segments extend after earned XP, capped at this level.',.7,.7,.7)
  GameTooltip:AddLine('Drag to move when unlocked.',.7,.7,.7);GameTooltip:Show()
 end);xpFrame:SetScript('OnLeave',function() GameTooltip:Hide() end)
end
-- Suppress only the native XP frame's visual alpha, outside combat. Do not
-- replace manager methods, run native layouts, or install native script hooks.
local nativeXPAlpha={}
function P.NativeXP()
 if InCombatLockdown and InCombatLockdown() then return end
 local enabled=settings().xpDetails and UnitLevel('player')<60 and UnitXPMax('player')>0
 local function suppress(frame,wanted)
  if wanted==nil then wanted=enabled end
  if not frame or not frame.SetAlpha or not frame.GetAlpha then return end
  local alpha=frame:GetAlpha()
  if issecretvalue and issecretvalue(alpha) then return end
  if wanted then
   if nativeXPAlpha[frame]==nil then nativeXPAlpha[frame]=alpha end
   if alpha~=0 then frame:SetAlpha(0) end
  elseif nativeXPAlpha[frame]~=nil then
   frame:SetAlpha(nativeXPAlpha[frame]);nativeXPAlpha[frame]=nil
  end
 end
 local visited={}
 local function suppressTree(frame,depth,wanted,excluded)
  if not frame or visited[frame] or depth>8 then return end
  if excluded and excluded[frame] then return end
  visited[frame]=true;suppress(frame,wanted)
  if frame.GetStatusBarTexture then suppress(frame:GetStatusBarTexture(),wanted) end
  -- XP decorations can ignore parent alpha; suppress their own visuals too.
  if frame.GetRegions then for _,region in ipairs({frame:GetRegions()}) do suppress(region,wanted) end end
  if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do suppressTree(child,depth+1,wanted,excluded) end end
 end
 suppressTree(MainMenuExpBar,0);suppressTree(ExperienceBar,0)
 suppressTree(MainMenuBar and MainMenuBar.ExpBar,0)
 -- Legacy clients attach XP dividers/frame artwork outside the bar itself.
 for i=0,3 do suppress(_G['MainMenuXPBarTexture'..i]) end
 for i=1,19 do suppress(_G['MainMenuXPBarDiv'..i]);suppress(_G['MainMenuExpBarDiv'..i]) end
 suppressTree(OverrideActionBarExpBar,0)
 suppress(ExhaustionTick)
 local index=(StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum and StatusTrackingBarInfo.BarsEnum.Experience) or 4
 local hosts,seen={},{}
 local function addHost(host) if host and not seen[host] then seen[host]=true;hosts[#hosts+1]=host end end
 addHost(StatusTrackingBarManager);addHost(MainStatusTrackingBarContainer);addHost(SecondaryStatusTrackingBarContainer)
 if StatusTrackingBarManager and StatusTrackingBarManager.barContainers then
  for _,host in pairs(StatusTrackingBarManager.barContainers) do addHost(host) end
 end
 for _,host in ipairs(hosts) do
  if host and host.bars and index then
   local bar=host.bars[index];suppressTree(bar,0)
   local shown=host.shownBarIndex
   if not (issecretvalue and issecretvalue(shown)) then
    local showingXP=shown==index or shown==nil and bar and bar.IsShown and bar:IsShown()
    -- The border belongs to the container, not its XP child. Leave container
    -- alpha/animations and all manager state untouched; restore for other bars.
    suppress(host.BarFrameTexture,enabled and showingXP or false)
    -- Client variants also place separators directly on the container.
    if host.GetRegions then
     for _,region in ipairs({host:GetRegions()}) do suppress(region,enabled and showingXP or false) end
    end
    -- Container-owned child frames can carry decorative rows of their own.
    -- Exclude every actual bar so reputation/honor never inherit suppression.
    if host.GetChildren then
     local excluded={};for _,other in pairs(host.bars) do excluded[other]=true end
     for _,child in ipairs({host:GetChildren()}) do
      suppressTree(child,0,enabled and showingXP or false,excluded)
     end
    end
   end
  end
 end
 if not enabled then
  for frame,alpha in pairs(nativeXPAlpha) do frame:SetAlpha(alpha);nativeXPAlpha[frame]=nil end
 end
end
function P.XPDebug()
 say('XP visuals • '..P.Version..' • custom '..tostring(settings().xpDetails)..' • combat '..tostring(combat()))
 local count,seen=0,{}
 local function show(name,frame,depth)
  depth=depth or 0
  if seen[frame] or count>=60 then return end
  if not frame then say(name..': unavailable');return end
  seen[frame]=true;count=count+1
  local alpha=frame.GetAlpha and frame:GetAlpha()
  if issecretvalue and issecretvalue(alpha) then alpha='restricted' end
  say(name..': alpha '..tostring(alpha)..' • shown '..tostring(frame.IsShown and frame:IsShown()))
  if frame.GetRegions then
   for i,r in ipairs({frame:GetRegions()}) do
    local atlas=r.GetAtlas and r:GetAtlas();local a=r.GetAlpha and r:GetAlpha()
    if issecretvalue and issecretvalue(atlas) then atlas='restricted' end
    if issecretvalue and issecretvalue(a) then a='restricted' end
    say('  Region '..i..': '..tostring(atlas or 'no atlas')..' • alpha '..tostring(a))
   end
  end
  if frame.GetChildren and depth<3 then
   for i,child in ipairs({frame:GetChildren()}) do
    local childName=child.GetName and child:GetName() or name..'/child '..i
    show(childName or name..'/child '..i,child,depth+1)
   end
  end
 end
 for _,name in ipairs({'MainMenuExpBar','MainStatusTrackingBarContainer','SecondaryStatusTrackingBarContainer','StatusTrackingBarManager','OverrideActionBarExpBar','EllesmereEAB_XPBar'}) do show(name,_G[name]) end
end
function P.UpdateXP()
 if not xpFrame then return end
 P.NativeXP()
 local x,max=UnitXP('player'),UnitXPMax('player');local show=settings().xpDetails and UnitLevel('player')<60 and max>0;xpFrame:SetShown(show);if not show then return end
 local width=598;local rest=GetXPExhaustion and GetXPExhaustion() or 0
 xpFill:ClearAllPoints();xpFill:SetPoint('TOPLEFT',1,-1);xpFill:SetWidth(math.max(.01,width*x/max));xpFill:SetShown(x>0)
 local quest=math.min(math.max(0,questTotal),math.max(0,max-x))
 local rested=math.min(math.max(0,rest),math.max(0,max-x-quest))
 questFill:ClearAllPoints();questFill:SetPoint('TOPLEFT',1+width*x/max,-1);questFill:SetWidth(math.max(.01,width*quest/max));questFill:SetShown(quest>0)
 restFill:ClearAllPoints();restFill:SetPoint('TOPLEFT',1+width*(x+quest)/max,-1);restFill:SetWidth(math.max(.01,width*rested/max));restFill:SetShown(rested>0)
 local elapsed=GetTime()-sessionStart;local rate=elapsed>0 and sessionXP*3600/elapsed or 0;local eta=rate>0 and duration((max-x)*3600/rate) or 'estimating'
 local playedElapsed=playedAt and GetTime()-playedAt or 0
 xpFrame.details=(('Level %d: %.1f%%  |  Needed %.1f%%  |  Rested %.1f%%\nCompleted quests: %s XP (%.1f%%)%s\nXP/hour %.0f  |  Level in %s  |  Session %s / %d XP\nPlayed this level %s  |  Total played %s'):format(UnitLevel('player'),x/max*100,(max-x)/max*100,rest/max*100,questTotal,questTotal/max*100,questUnknown>0 and (' + '..questUnknown..' unknown') or '',rate,eta,duration(elapsed),sessionXP,playedLevel and duration(playedLevel+(levelPlayedAt and GetTime()-levelPlayedAt or playedElapsed)) or 'pending',playedTotal and duration(playedTotal+playedElapsed) or 'pending'))
 xpLabels:SetText(('%d / %d (%d)'):format(x,max,max-x))
 xpFrame.levelLabel:SetText(('Level %d'):format(UnitLevel('player')))
 xpFrame.percentLabel:SetText(('%.1f%% (%.1f%%)'):format(x/max*100,(max-x)/max*100))
 xpFrame.levelTimeLabel:SetText('Time this level: '..(playedLevel and duration(playedLevel+(levelPlayedAt and GetTime()-levelPlayedAt or playedElapsed)) or 'pending'))
 xpFrame.sessionLabel:SetText('Time this session: '..duration(elapsed))
 xpFrame.bonusLabel:SetText(('Completed: %.0f%% • Rested: %.0f%%'):format(questTotal/max*100,rest/max*100))
 local kills,average,count=P.MobEstimate(max-x)
 local killText=kills and ('~%d mobs to level'):format(kills) or 'Mobs: estimating'
 xpFrame.rateLabel:SetText(('Level in %s • %.0f XP/hour • %s'):format(eta,rate,killText))
 if kills then xpFrame.details=xpFrame.details..('\nRecent kills: %.0f XP/mob over %d kills • ~%d mobs to level'):format(average,count,kills) end
end
-- Native Forever swing events, main-hand / off-hand / ranged (including wand autos).
local swingFrame,swingBars,swingEnds,swingDurations=nil,{}, {},{}
local function createSwings()
 swingFrame=CreateFrame('Frame','ForeverAssistSwings',UIParent);position(swingFrame,'swingPosition',0,-140);movable(swingFrame,'swingPosition')
 for i,label in ipairs({'Main hand','Off hand','Ranged'}) do
  local b=CreateFrame('StatusBar',nil,swingFrame);b:SetStatusBarTexture('Interface/TargetingFrame/UI-StatusBar');b:SetStatusBarColor(.95,.7,.15);b:SetPoint('TOPLEFT',0,-(i-1)*22)
  local bg=b:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.06,.06,.06,.75);b.bg=bg;b.label=text(b);b.label:SetPoint('CENTER');b.caption=label;swingBars[i]=b;b:Hide()
 end
end
function P.Swing(seconds,kind)
 if type(seconds)~='number' or type(kind)~='number' or seconds<=0 or kind<0 or kind>2 then return end
 swingEnds[kind+1]=GetTime()+seconds;swingDurations[kind+1]=seconds
end
local nativeSwingState={}
local function animateSwings()
 if not swingFrame or not settings then return end
 local c=settings();local now=GetTime()
 for i,b in ipairs(swingBars)do
  local remaining=math.max(0,(swingEnds[i]or 0)-now);local preview=P.swingUnlocked and remaining==0
  local seconds=swingDurations[i]or 1
  if preview then seconds=1.8+(i-1)*.4;remaining=seconds-now%seconds end
  b:SetMinMaxValues(0,seconds);b:SetValue(remaining);b:SetShown(P.swingUnlocked or c.swingTimer and remaining>0)
  local caption=(c.swingCaptions~=false and b.caption or '')..(c.swingSeconds~=false and (' %.1fs'):format(remaining)or '')
  if b.lastCaption~=caption then b.label:SetText(caption);b.lastCaption=caption end
 end
end
local function updateSwings()
 if not swingFrame then return end
 for _,native in pairs({SwingTimerMainHandFrame,SwingTimerOffHandFrame,SwingTimerRangedFrame}) do
  if native then
   if settings().swingTimer then if not nativeSwingState[native] then nativeSwingState[native]={shown=native:IsShown()} end;native:Hide()
   elseif nativeSwingState[native] then native:SetShown(nativeSwingState[native].shown);nativeSwingState[native]=nil end
  end
 end
 swingFrame:SetFrameStrata(P.swingUnlocked and 'TOOLTIP' or 'MEDIUM')
 local c=settings();local w=c.swingWidth or 240;local h=c.swingHeight or 18;local gap=c.swingGap or 4;swingFrame:SetSize(w,3*(h+gap))
 local colors={{.95,.7,.15},{.15,.8,.65},{.3,.65,1},{.85,.35,.8}};local color=colors[c.swingColor or 1] or colors[1]
 swingFrame:SetAlpha(c.swingOpacity or 1)
 for i,b in ipairs(swingBars) do
  local remaining=math.max(0,(swingEnds[i] or 0)-GetTime());local preview=P.swingUnlocked and remaining==0
  b:SetSize(w,h);b:ClearAllPoints();b:SetPoint('TOPLEFT',0,-(i-1)*(h+gap));b:SetMinMaxValues(0,swingDurations[i] or 1);b:SetValue(remaining);b:SetShown(P.swingUnlocked or c.swingTimer and remaining>0);if preview then b:SetMinMaxValues(0,1);b:SetValue(.6) end
  local texture=c.swingFlat and 'Interface/Buttons/WHITE8X8' or 'Interface/TargetingFrame/UI-StatusBar'
  if b.faSwingTexture~=texture then b:SetStatusBarTexture(texture);b.faSwingTexture=texture end;b:SetStatusBarColor(unpack(color))
  if b.SetReverseFill then b:SetReverseFill(c.swingReverse==true) end
  b.label:SetFont(STANDARD_TEXT_FONT,c.swingFontSize or 11,'OUTLINE')
  b.lastCaption=nil
 end
 animateSwings()
end
-- Craft-all queue estimates use the observed cast duration.
local craft,craftLabel
function P.CraftStart(id,count)
 if type(count)=='number' and count>1 then craft={id=id,remaining=count,total=count,started=GetTime(),castID=nil};end
end
local function updateCraft()
 if not craft then if craftLabel then craftLabel:Hide() end;return end
 local bar=PlayerCastingBarFrame or CastingBarFrame
 if not bar then return end
 if not craftLabel then craftLabel=text(bar);craftLabel:SetPoint('TOP',bar,'BOTTOM',0,-24);craftLabel:SetFont(STANDARD_TEXT_FONT,12,'OUTLINE') end
 local _,_,_,startMS,endMS,_,castID,_,spellID=UnitCastingInfo('player')
 if startMS and endMS and (not craft.id or spellID==craft.id) then
  craft.castSeconds=(endMS-startMS)/1000;character.craftTimes=character.craftTimes or {};if spellID then character.craftTimes[spellID]=craft.castSeconds end;craft.castID=castID;craft.activeSpell=spellID;craft.lastActive=GetTime()
  local eta=(craft.remaining-1)*craft.castSeconds+math.max(0,endMS/1000-GetTime())
  craftLabel:SetText(('Create all: %d remaining • about %s'):format(craft.remaining,duration(eta)));craftLabel:Show()
 elseif GetTime()-(craft.lastActive or craft.started)>4 then craft=nil;craftLabel:Hide() end
end
local craftPreview
function P.CraftPreview()
 local host=ProfessionsFrame or TradeSkillFrame
 local btn=ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.CreateAllButton or TradeSkillCreateAllButton
 if not host or not btn then if craftPreview then craftPreview:Hide() end;return end
 if not craftPreview then craftPreview=text(host);craftPreview:SetFont(STANDARD_TEXT_FONT,11,'OUTLINE') end
 craftPreview:ClearAllPoints();craftPreview:SetPoint('TOP',btn,'BOTTOM',0,-8)
 local id,count
 local form=ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
 if form and form.GetRecipeInfo then local info=form:GetRecipeInfo();id=info and info.recipeID end
 local page=ProfessionsFrame and ProfessionsFrame.CraftingPage
 if id and page and page.GetCraftableCount then local ok,n=pcall(page.GetCraftableCount,page);if ok then count=n end
 elseif id and C_TradeSkillUI and C_TradeSkillUI.GetCraftableCount then count=C_TradeSkillUI.GetCraftableCount(id) end
 if not id and GetTradeSkillSelectionIndex then local index=GetTradeSkillSelectionIndex();local link=GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(index);id=link and tonumber(link:match('spell:(%d+)'));if GetTradeSkillInfo then local _,_,n=GetTradeSkillInfo(index);count=n end end
 local info=id and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
 local seconds=character.craftTimes and character.craftTimes[id] or info and info.castTime and info.castTime/1000
 if (not seconds or seconds<=0) and craft and craft.id==id then seconds=craft.castSeconds end
 craftPreview:SetText(count and count>0 and seconds and seconds>0 and ('Create all: about '..duration(count*seconds)) or 'Create all: time available after first cast')
 craftPreview:SetShown(host:IsShown() and btn:IsShown())
end
-- Buy one currently available trainer service at a time and verify it changes.
local trainButton,training,trainWait= nil,nil,0
function P.TrainAll()
 if combat() then say('Train after combat.');return end
 if training then training=nil;say('Train all stopped.');return end
 training={attempts={},learned=0};say('Training affordable available services. Click again to stop.')
end
local function trainTick(elapsed)
 if not training then return end
 local trainer=ClassTrainerFrame or TrainerFrame
 if not trainer or not trainer:IsShown() or combat() then training=nil;return end
 trainWait=trainWait+elapsed;if trainWait<.4 then return end;trainWait=0
 for i=1,(GetNumTrainerServices and GetNumTrainerServices() or 0) do
  local name,a,b,c,rank=GetTrainerServiceInfo(i);local status=a; if a~='available' and a~='unavailable' and a~='used' then status=b;rank=a end
  local key=tostring(name)..'|'..tostring(rank or '')
  if status=='available' and not training.attempts[key] then
   local cost=GetTrainerServiceCost(i) or 0
   if cost>GetMoney() then training.attempts[key]=true
   else training.attempts[key]=true;local ok=pcall(BuyTrainerService,i);if not ok then training=nil;say('Trainer rejected the purchase.');return end;training.learned=training.learned+1;return end
  end
 end
 say('Train all finished; '..training.learned..' purchase(s) requested. Unaffordable or unavailable services were skipped.');training=nil
end
local function hookTrainer()
 local trainer=ClassTrainerFrame or TrainerFrame
 if trainer and not trainButton then trainButton=button(trainer,'Train all',15,-35,100,P.TrainAll) end
end
-- Bag movement uses a dedicated handle; item dragging retains its normal behavior.
local bagFrameNames={'ContainerFrameCombinedBags','ContainerFrame1','ContainerFrame2','ContainerFrame3','ContainerFrame4','ContainerFrame5','ContainerFrame6'}
function P.ApplyBagPositions()
 if combat() or not settings().moveBags then return end
 for _,name in ipairs(bagFrameNames) do
  local f=_G[name];local p=settings().bagPositions and settings().bagPositions[name]
  if f and p and not f.faDragging then
   f:SetMovable(true);if f.SetUserPlaced then f:SetUserPlaced(true) end
   f:ClearAllPoints();f:SetPoint('CENTER',UIParent,'CENTER',p[1],p[2])
  end
 end
end
function P.ResetBags()
 if combat() then return end
 settings().bagPositions={}
 for _,name in ipairs(bagFrameNames) do local f=_G[name];if f and f.SetUserPlaced then f:SetUserPlaced(false) end end
 if UpdateContainerFrameAnchors then UpdateContainerFrameAnchors() end
end
local function hookBags()
 for _,name in ipairs(bagFrameNames) do
  local f=_G[name]
  if f and not f.faMoveHandle then
   local h=CreateFrame('Button',nil,UIParent);f.faMoveHandle=h;h:SetSize(140,20);h:SetPoint('BOTTOM',f,'TOP',0,2);h:SetFrameStrata('HIGH');h:SetFrameLevel(f:GetFrameLevel()+10);h:EnableMouse(true)
   local t=text(h);t:SetPoint('CENTER');t:SetText('Drag bag');h:RegisterForDrag('LeftButton')
   h:SetScript('OnDragStart',function() if settings().moveBags and not combat() then f.faDragging=true;f:SetMovable(true);f:SetClampedToScreen(true);if f.SetUserPlaced then f:SetUserPlaced(true) end;f:StartMoving() end end)
   h:SetScript('OnDragStop',function()
    f:StopMovingOrSizing();f.faDragging=false;local x,y=f:GetCenter();local ux,uy=UIParent:GetCenter();settings().bagPositions=settings().bagPositions or {}
    if x and ux then local scale=f.GetEffectiveScale and f:GetEffectiveScale() or 1;local base=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1;settings().bagPositions[name]={x*scale/base-ux,y*scale/base-uy} end
    P.ApplyBagPositions()
   end)
   f:HookScript('OnShow',function() h:SetShown(settings().moveBags and f:IsShown());P.ApplyBagPositions() end)
   f:HookScript('OnHide',function() h:Hide() end)
  end
  if f and f.faMoveHandle then f.faMoveHandle:SetShown(settings().moveBags and f:IsShown()) end
 end
 P.ApplyBagPositions()
end
-- Camp IDs are Forever spell records, not assumed buff names or fixed durations.
local campWarned,nearbyWas,tentWas={},false,false
local campSit,campTimer,campAura,campVisibility
local function createCampUI()
 if campTimer then return end
 if combat() then return end
 campSit=CreateFrame('Button','ForeverAssistCampSit',UIParent,'SecureActionButtonTemplate,BackdropTemplate')
 campSit:SetSize(174,40);position(campSit,'campSitPosition',0,-65);movable(campSit,'campSitPosition');campSit:SetFrameStrata('HIGH')
 campSit:SetBackdrop({bgFile='Interface/Buttons/WHITE8X8',edgeFile='Interface/Tooltips/UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 campSit:SetBackdropColor(.10,.065,.035,.96);campSit:SetBackdropBorderColor(.6,.48,.31,1)
 campSit.icon=campSit:CreateTexture(nil,'ARTWORK');campSit.icon:SetSize(26,26);campSit.icon:SetPoint('LEFT',9,0);campSit.icon:SetTexture(135805);campSit.icon:SetTexCoord(.07,.93,.07,.93)
 campSit.label=text(campSit);campSit.label:SetPoint('LEFT',campSit.icon,'RIGHT',8,0);campSit.label:SetText('Sit at campfire');campSit.label:SetFont(STANDARD_TEXT_FONT,12,'OUTLINE');campSit.label:SetTextColor(1,.86,.57)
 campSit:SetHighlightTexture('Interface/Buttons/WHITE8X8');campSit:GetHighlightTexture():SetVertexColor(1,.7,.25,.12)
 campSit:SetScript('OnMouseDown',function()campSit.icon:SetVertexColor(.75,.75,.75)end);campSit:SetScript('OnMouseUp',function()campSit.icon:SetVertexColor(1,1,1)end)
 campSit:RegisterForClicks('AnyUp','AnyDown');campSit:SetAttribute('useOnKeyDown',false);campSit:SetAttribute('type','macro');campSit:SetAttribute('macrotext','/sit')
 campSit:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:AddLine('Sit at the nearby campfire');GameTooltip:AddLine('Click to /sit. Drag to move this button outside combat.',1,1,1);GameTooltip:Show() end)
 campSit:SetScript('OnLeave',function() GameTooltip:Hide() end)
 campSit:Hide()
 campTimer=CreateFrame('Frame','ForeverAssistCampWelcome',UIParent);campTimer:SetSize(300,54);position(campTimer,'campWelcomePosition',0,75);campTimer:SetFrameStrata('HIGH')
 campTimer.icon=campTimer:CreateTexture(nil,'ARTWORK');campTimer.icon:SetSize(40,40);campTimer.icon:SetPoint('LEFT',8,0)
 campTimer.title=text(campTimer);campTimer.title:SetPoint('TOPLEFT',58,-7);campTimer.title:SetText('Welcoming Campfire');campTimer.title:SetFont(STANDARD_TEXT_FONT,14,'OUTLINE')
 campTimer.count=text(campTimer);campTimer.count:SetPoint('BOTTOMLEFT',58,7);campTimer.count:SetFont(STANDARD_TEXT_FONT,18,'OUTLINE');campTimer:Hide()
end
local function campButton(show)
 if not campSit or combat() then return end
 local rule=show and '[combat] hide; show' or 'hide'
 if RegisterStateDriver then
  if rule~=campVisibility then RegisterStateDriver(campSit,'visibility',rule);campVisibility=rule end
 else campSit:SetShown(show) end
end
function P.UpdateCampTimer()
 if not campTimer then return end
 if not settings().campNotices or not campAura then campTimer:Hide();return end
 local expires=campAura.expirationTime or 0
 if expires>0 then
  local remaining=math.max(0,expires-GetTime())
  if remaining==0 then campAura=nil;campTimer:Hide();return end
  campTimer.count:SetText(('%.1f seconds'):format(remaining))
 else campTimer.count:SetText('Active') end
 campTimer:Show()
end
function P.CheckCamp()
 if not settings().campNotices then campAura=nil;campButton(false);P.UpdateCampTimer();return end
 createCampUI()
 if not ForeverAssistAuraReadable() then campButton(false);P.UpdateCampTimer();return end
 local benefits,near,welcome,tent
 for i=1,255 do
  local a,readable=ForeverAssistReadPlayerAura(i)
  if not readable then campButton(false);P.UpdateCampTimer();return end
  if not a then break end
  if a.spellId==1229741 then benefits=a
  elseif a.spellId==1283391 then near=a
  elseif a.spellId==1229739 or a.name=='Welcoming Campfire' then welcome=a
  elseif a.spellId==1229487 then tent=a end
 end
 near=near or welcome
 campButton(near~=nil and welcome==nil)
 campAura=welcome
 if welcome and campTimer then campTimer.icon:SetTexture(welcome.icon or 135805) end
 P.UpdateCampTimer()
 if near and not nearbyWas and not benefits then say('Camp nearby: click Sit at campfire to receive its welcome effect.') end
 if tent and not tentWas then say('Leatherworking tent nearby: sit to receive its rested-XP benefit.') end
 nearbyWas,tentWas=not not near,not not tent
 if benefits and type(benefits.expirationTime)=='number' and benefits.expirationTime>0 then
  local remaining=benefits.expirationTime-GetTime();local key=benefits.expirationTime
  if remaining>0 and remaining<=300 and not campWarned[key] then campWarned[key]=true;say('Camp benefits expire in '..duration(remaining)..'.') end
 end
end
-- Rings are secure click-to-select radial menus with account-wide editable definitions.
local ringWindows,ringOpeners,ringMacroOpeners={},{},{}
local function RingMacroBody(def)
 return '/click ForeverAssistRingMacro'..def.macroID..' LeftButton 0'
end
local function NormalizeRingMacro(body)
 if type(body)~='string' then return end
 return body:gsub('\r',''):gsub('^%s+',''):gsub('%s+$','')
end
function P.EnsureRingMacro(name,pickup)
 if combat() then if pickup then say('Create or pick up ring macros after combat.') end;return end
 local def=account.rings[name]
 if not def or not def.macroID or not CreateMacro or not GetMacroInfo or not GetNumMacros then return end
 local body=RingMacroBody(def);local general,character=GetNumMacros();local index
 for i=1,(MAX_ACCOUNT_MACROS or 120)+(MAX_CHARACTER_MACROS or 18) do
  local _,_,existing=GetMacroInfo(i);if NormalizeRingMacro(existing)==body then index=i;break end
 end
 if not index then
  local perCharacter=general>=(MAX_ACCOUNT_MACROS or 120)
  if perCharacter and character>=(MAX_CHARACTER_MACROS or 18) then if pickup then say('No free macro slots. Remove an unused macro, then try again.') end;return end
  local label='FA '..name
  if #label>16 then label='FA Ring '..def.macroID end
  local ok,result=pcall(CreateMacro,label,134400,body,perCharacter)
  if ok then index=result end
  if not index and pickup then say('Could not create the ring macro. Check your free macro slots.') end
 end
 if index and pickup and PickupMacro then PickupMacro(index) end
 return index
end
local portals={3561,3562,3563,3565,3566,3567,10059,11416,11417,11418,11419,11420}
local professions={2259,2018,7411,4036,45357,25229,2108,3908,2550,3273,2575,8613,2366,7620,2656,2580,2383,13262,818}
local warlockPets={688,697,712,713,691,1122,18540}
local hunterPets={883,2641,1515,6991,982,1462,1002,1494,19577,19574}
local mendPetRanks={13544,13543,13542,3662,3661,3111,136}
local function RingSource(def)
 if def.auto=='portals' then return portals end
 if def.auto=='professions' then return professions end
 local _,class=UnitClass('player')
 if def.auto=='warlockPets' and class=='WARLOCK' then return warlockPets end
 if def.auto=='hunterPets' and class=='HUNTER' then
  local list={};for _,id in ipairs(hunterPets) do list[#list+1]=id end
  for _,id in ipairs(mendPetRanks) do if known(id) then list[#list+1]=id;break end end
  return list
 end
 return {}
end
local function spellInfo(id)
 if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(id) end
 if GetSpellInfo then local n,_,icon=GetSpellInfo(id);return n and {name=n,iconID=icon} end
end
function P.RingEntries(name)
 local def=account.rings[name];local list={}
 local source=RingSource(def)
 for _,id in ipairs(source) do if known(id) and not (def.excluded and def.excluded[id]) then list[#list+1]={kind='spell',id=id} end end
 for _,entry in ipairs(def.entries or {}) do if entry.kind=='item' or known(entry.id) then list[#list+1]=entry end end
 return list
end
function P.BuildRings()
 if combat() then P.ringsPending=true;return end
 P.ringsPending=false
 -- Saved IDs keep macro targets stable across reloads and unordered table iteration.
 local names={};local used={};local nextID=tonumber(account.nextRingMacroID) or 0
 for name,def in pairs(account.rings) do
  names[#names+1]=name
  if type(def.macroID)=='number' and def.macroID>0 and def.macroID==math.floor(def.macroID) then nextID=math.max(nextID,def.macroID) else def.macroID=nil end
 end
 table.sort(names)
 for _,name in ipairs(names) do local def=account.rings[name];if not def.macroID or used[def.macroID] then nextID=nextID+1;def.macroID=nextID end;used[def.macroID]=true end
 account.nextRingMacroID=nextID
 for name,def in pairs(account.rings) do
  local root=ringWindows[name]
  if not root then
   local index=0;for _ in pairs(ringWindows) do index=index+1 end;index=index+1
   root=CreateFrame('Frame','ForeverAssistRing'..index,UIParent,'SecureHandlerBaseTemplate');root:SetSize(310,310);root:SetPoint('CENTER');root:SetFrameStrata('DIALOG');root.buttons={};root:Hide();ringWindows[name]=root
   local opener=CreateFrame('Button','ForeverAssistRingToggle'..index,UIParent,'SecureHandlerClickTemplate');opener:SetFrameRef('ring',root);opener:RegisterForClicks('AnyDown','AnyUp');opener:SetAttribute('pressAndHoldAction',true)
   opener:SetAttribute('_onclick',[[local r=self:GetFrameRef('ring');if self:GetAttribute('holdToShow') then if down then r:Show() else r:Hide() end elseif not down then if r:IsShown() then r:Hide() else r:Show() end end]])
   root:SetFrameRef('opener',opener);ringOpeners[name]=opener
   local close=CreateFrame('Button',nil,root,'SecureHandlerClickTemplate');close:SetSize(70,32);close:SetPoint('CENTER');close:SetFrameRef('ring',root);close:SetAttribute('_onclick',[[self:GetFrameRef('ring'):Hide()]])
   local t=text(close);t:SetPoint('CENTER');t:SetText('Close')
  end
  local macroOpener=ringMacroOpeners[name]
  if not macroOpener then
   macroOpener=CreateFrame('Button','ForeverAssistRingMacro'..def.macroID,UIParent,'SecureHandlerClickTemplate');macroOpener:RegisterForClicks('AnyUp');macroOpener:SetFrameRef('ring',root)
   macroOpener:SetAttribute('_onclick',[[if self:GetAttribute('active') and not down then local r=self:GetFrameRef('ring');if r:IsShown() then r:Hide() else r:Show() end end]])
   ringMacroOpeners[name]=macroOpener
  end
  macroOpener:SetAttribute('active',true)
  root:Hide();for _,b in ipairs(root.buttons) do b:Hide();b:SetAttribute('type',nil) end
  local entries=P.RingEntries(name);local count=#entries
  for i,e in ipairs(entries) do
   local b=root.buttons[i]
   if not b then
    b=CreateFrame('Button',nil,root,'SecureActionButtonTemplate,SecureHandlerBaseTemplate');b:SetSize(44,44);b:RegisterForClicks('AnyUp','AnyDown');b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints();b:SetFrameRef('ring',root)
    b:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_RIGHT');if self.entry.kind=='spell' then GameTooltip:SetSpellByID(self.entry.id) else GameTooltip:SetItemByID(self.entry.id) end;GameTooltip:Show() end);b:SetScript('OnLeave',function() GameTooltip:Hide() end);root.buttons[i]=b
   end
   local angle=(i-1)*2*math.pi/math.max(1,count);local radius=count>12 and 145 or 110
   b:ClearAllPoints();b:SetPoint('CENTER',root,'CENTER',math.sin(angle)*radius,math.cos(angle)*radius);b.entry=e
   b:SetAttribute('useOnKeyDown',false);b:SetAttribute('type',e.kind);b:SetAttribute('spell',e.kind=='spell' and e.id or nil);b:SetAttribute('item',e.kind=='item' and ('item:'..e.id) or nil)
   local info=e.kind=='spell' and spellInfo(e.id);local icon=info and info.iconID or C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id) or 134400;b.icon:SetTexture(icon);b:Show()
  end
  local opener=ringOpeners[name];opener:SetAttribute('holdToShow',def.holdToShow==true);ClearOverrideBindings(opener)
  local key=character.ringBindings[name]
  if key and key~='' then local ok,result=pcall(SetOverrideBindingClick,opener,false,key,opener:GetName(),'LeftButton');if not ok or result==false then say('Could not bind '..name..' to '..key..'. Use a valid WoW binding such as ALT-R.') end end
 end
end
local ringEditor,ringName,ringStatus
local ringSelection='Portals'
local ringRows,ringSlices={},{}
local ringCapture=false
function P.AddRingCursor()
 if combat() then say('Edit rings after combat.');return end
 local d=account.rings[ringSelection];if not d then return end
 local kind,id,bank,spellID=GetCursorInfo()
 if kind=='spell' then
  if spellID then id=spellID
  elseif C_SpellBook and C_SpellBook.GetSpellBookItemInfo then local info=C_SpellBook.GetSpellBookItemInfo(id,bank or Enum.SpellBookSpellBank.Player);id=info and info.spellID
  elseif GetSpellBookItemInfo then local _,sid=GetSpellBookItemInfo(id,bank or BOOKTYPE_SPELL);id=sid end
 end
 if (kind~='spell' and kind~='item') or type(id)~='number' then say('Drag a spell from your spellbook or an item from your bags.');return end
 d.entries=d.entries or {};d.excluded=d.excluded or {};d.excluded[id]=nil
 for _,e in ipairs(d.entries) do if e.id==id and e.kind==kind then ClearCursor();return end end
 local auto=RingSource(d)
 for _,sid in ipairs(auto) do if kind=='spell' and sid==id then ClearCursor();P.BuildRings();P.RefreshRingEditor();return end end
 d.entries[#d.entries+1]={kind=kind,id=id};ClearCursor();P.BuildRings();P.RefreshRingEditor()
end
function P.DeleteRing(name)
 if combat() then say('Delete rings after combat.');return false end
 if not account.rings[name] then return false end
 local opener=ringOpeners[name];if opener then ClearOverrideBindings(opener);opener:Hide() end
 local macroOpener=ringMacroOpeners[name];if macroOpener then macroOpener:SetAttribute('active',false);ringMacroOpeners[name]=nil end
 local root=ringWindows[name];if root then root:Hide();for _,b in ipairs(root.buttons) do b:Hide();b:SetAttribute('type',nil) end end
 account.rings[name]=nil;character.ringBindings[name]=nil;ringCapture=false
 P.RefreshRingEditor();return true
end
function P.RefreshRingEditor()
 if not ringEditor then return end
 local names={};for n in pairs(account.rings) do names[#names+1]=n end;table.sort(names)
 if not account.rings[ringSelection] then ringSelection=names[1] end
 for _,b in ipairs(ringRows) do b:Hide() end
 for i,n in ipairs(names) do
  local name=n;local b=ringRows[i] or button(ringEditor.names,'',0,-(i-1)*31,155,function() end);ringRows[i]=b
  b:SetText((name==ringSelection and '> ' or '')..name);b:SetScript('OnClick',function() ringSelection=name;ringCapture=false;ringEditor.pendingDelete=nil;ringEditor.delete:SetText('Delete selected ring');P.RefreshRingEditor() end);b:Show()
 end
 ringEditor.names:SetHeight(math.max(1,#names*31))
 if not account.rings[ringSelection] then ringSelection=names[1] end
 for _,b in ipairs(ringSlices) do b:Hide() end
 local d=account.rings[ringSelection]
 ringEditor.bind:SetEnabled(d~=nil);ringEditor.hold:SetEnabled(d~=nil);ringEditor.delete:SetEnabled(d~=nil)
 if ringEditor.macro then ringEditor.macro:SetEnabled(d~=nil) end
 if not d then ringStatus:SetText('No rings. Create one below.');return end
 local key=character.ringBindings[ringSelection]
 ringStatus:SetText(ringSelection..'  •  '..(key and key~='' and key or 'No key assigned for this character'))
 if ringEditor.hold then ringEditor.hold:SetChecked(d.holdToShow==true) end
 ringEditor.bind:SetText(ringCapture and 'Press a key combination…' or 'Assign key')
 for _,b in ipairs(ringSlices) do b:Hide() end
 local entries={};local auto=RingSource(d)
 for _,id in ipairs(auto) do if known(id) and not (d.excluded and d.excluded[id]) then entries[#entries+1]={kind='spell',id=id,auto=true} end end
 for i,e in ipairs(d.entries or {}) do entries[#entries+1]={kind=e.kind,id=e.id,customIndex=i} end
 for i,e in ipairs(entries) do
  local b=ringSlices[i]
  if not b then
   b=CreateFrame('Button',nil,ringEditor.slices);b:SetSize(70,74);b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(42,42);b.icon:SetPoint('TOP');b.label=text(b);b.label:SetPoint('TOP',b.icon,'BOTTOM',0,-3);b.label:SetWidth(70);b.label:SetHeight(27);b.label:SetMaxLines(2)
   b:RegisterForClicks('LeftButtonUp','RightButtonUp');b:SetScript('OnReceiveDrag',P.AddRingCursor)
   b:SetScript('OnClick',function(self,mouse)
    if combat() then return end
    if mouse=='RightButton' then local def=account.rings[ringSelection];local entry=self.entry;if entry.auto then def.excluded=def.excluded or {};def.excluded[entry.id]=true else table.remove(def.entries,entry.customIndex) end;P.BuildRings();P.RefreshRingEditor() else P.AddRingCursor() end
   end)
   b:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_RIGHT');if self.entry.kind=='spell' then GameTooltip:SetSpellByID(self.entry.id) else GameTooltip:SetItemByID(self.entry.id) end;GameTooltip:AddLine('Right-click to remove this slice.',1,1,1);GameTooltip:Show() end);b:SetScript('OnLeave',function() GameTooltip:Hide() end)
   ringSlices[i]=b
  end
  b.entry=e;b:SetPoint('TOPLEFT',((i-1)%5)*74,-math.floor((i-1)/5)*80)
  local info=e.kind=='spell' and spellInfo(e.id);local itemName=e.kind=='item' and GetItemInfo and GetItemInfo(e.id)
  b.icon:SetTexture(info and info.iconID or C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id) or 134400);b.label:SetText(info and info.name or itemName or ('Item '..e.id));b:Show()
 end
 ringEditor.slices:SetHeight(math.max(180,math.ceil(#entries/5)*80))
end
function P.RingEditor()
 if not ringEditor then
  ringEditor=window('ForeverAssistRingEditor','Rings',620,490)
  local help=text(ringEditor);help:SetPoint('TOPLEFT',20,-42);help:SetWidth(580);help:SetJustifyH('LEFT');help:SetText('Drag spells or bag items into a ring. Right-click a slice to remove it.\nRings are shared across your account. Key assignments apply only to this character.')
  local names=CreateFrame('ScrollFrame',nil,ringEditor,'UIPanelScrollFrameTemplate');names:SetPoint('TOPLEFT',20,-88);names:SetSize(155,260);ringEditor.names=CreateFrame('Frame',nil,names);ringEditor.names:SetSize(155,1);names:SetScrollChild(ringEditor.names)
  ringStatus=text(ringEditor);ringStatus:SetPoint('TOPLEFT',215,-88);ringStatus:SetWidth(370);ringStatus:SetJustifyH('LEFT')
  local scroll=CreateFrame('ScrollFrame',nil,ringEditor,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',215,-120);scroll:SetSize(370,230)
  ringEditor.slices=CreateFrame('Frame',nil,scroll);ringEditor.slices:SetSize(370,230);scroll:SetScrollChild(ringEditor.slices)
  for _,f in ipairs({ringEditor,scroll,ringEditor.slices}) do f:EnableMouse(true);f:SetScript('OnReceiveDrag',P.AddRingCursor);f:SetScript('OnMouseUp',function(_,mouse) if mouse=='LeftButton' and GetCursorInfo() then P.AddRingCursor() end end) end
  ringEditor.bind=button(ringEditor,'Assign key',215,-368,175,function() if not combat() then ringCapture=not ringCapture;ringName:ClearFocus();P.RefreshRingEditor() end end)
  button(ringEditor,'Clear key',405,-368,175,function() if not combat() and account.rings[ringSelection] then character.ringBindings[ringSelection]=nil;ringCapture=false;P.BuildRings();P.RefreshRingEditor() end end)
  local newLabel=text(ringEditor);newLabel:SetPoint('TOPLEFT',20,-353);newLabel:SetText('New ring name')
  ringName=CreateFrame('EditBox',nil,ringEditor,'InputBoxTemplate');ringName:SetSize(155,25);ringName:SetPoint('TOPLEFT',25,-372);ringName:SetAutoFocus(false);ringName:SetMaxLetters(30)
  local function newRing() if combat() then return end;local n=ringName:GetText():match('^%s*(.-)%s*$');if n=='' then say('Enter a name for your new ring.');return end;account.rings[n]=account.rings[n] or {entries={},key=''};ringSelection=n;ringName:SetText('');ringName:ClearFocus();P.BuildRings();P.EnsureRingMacro(n);P.RefreshRingEditor() end
  button(ringEditor,'Create named ring',20,-408,160,newRing)
  ringEditor.delete=button(ringEditor,'Delete selected ring',20,-446,160,function(self)
   if combat() or not ringSelection then return end
   if ringEditor.pendingDelete~=ringSelection then ringEditor.pendingDelete=ringSelection;self:SetText('Confirm delete ring');return end
   local name=ringSelection;ringEditor.pendingDelete=nil;self:SetText('Delete selected ring');P.DeleteRing(name)
  end)
  ringName:SetScript('OnEnterPressed',newRing)
  button(ringEditor,'Restore automatic slices',215,-408,365,function() if not combat() and account.rings[ringSelection] then account.rings[ringSelection].excluded={};P.BuildRings();P.RefreshRingEditor() end end)
  ringEditor:SetHeight(570)
  local hold=CreateFrame('CheckButton',nil,ringEditor,'UICheckButtonTemplate');hold:SetPoint('TOPLEFT',215,-446);ringEditor.hold=hold
  local holdLabel=text(hold);holdLabel:SetPoint('LEFT',hold,'RIGHT',0,0);holdLabel:SetText('Hold key to show (release to close)')
  hold:SetScript('OnClick',function(self)if combat() then self:SetChecked(account.rings[ringSelection].holdToShow==true);return end;account.rings[ringSelection].holdToShow=self:GetChecked() and true or false;P.BuildRings();P.RefreshRingEditor()end)
  local behavior=text(ringEditor);behavior:SetPoint('TOPLEFT',215,-480);behavior:SetWidth(370);behavior:SetText('Unchecked: press once to open; press again or click Close to dismiss.')
  ringEditor.macro=button(ringEditor,'Pick up macro',215,-512,175,function() if ringSelection then P.EnsureRingMacro(ringSelection,true) end end)
  local macroHelp=text(ringEditor);macroHelp:SetPoint('TOPLEFT',405,-512);macroHelp:SetWidth(175);macroHelp:SetText('Drop onto an action bar.\nMacros always toggle the ring.')
  local note=text(ringEditor);note:SetPoint('TOPLEFT',20,-552);note:SetText('Automatic rings fill with learned spells. Delete selected ring asks for a second click to confirm.')
  ringEditor:SetHeight(595)
  ringEditor:EnableKeyboard(true);ringEditor:SetPropagateKeyboardInput(true)
  ringEditor:SetScript('OnKeyDown',function(self,key)
   if combat() or not ringCapture then if not combat() then self:SetPropagateKeyboardInput(true) end;return end
   self:SetPropagateKeyboardInput(false)
   if key=='ESCAPE' then ringCapture=false;P.RefreshRingEditor();return end
   if key=='LSHIFT' or key=='RSHIFT' or key=='LCTRL' or key=='RCTRL' or key=='LALT' or key=='RALT' then return end
   local binding=(IsAltKeyDown() and 'ALT-' or '')..(IsControlKeyDown() and 'CTRL-' or '')..(IsShiftKeyDown() and 'SHIFT-' or '')..key
   if settings().junkKey==binding then say('That key already opens the junk manager.');return end
   for name in pairs(account.rings) do if name~=ringSelection and character.ringBindings[name]==binding then say('That key already opens '..name..'.');return end end
   character.ringBindings[ringSelection]=binding;ringCapture=false;P.BuildRings();P.RefreshRingEditor()
  end)
  button(ringEditor,'Back',455,-12,115,function() ringEditor:Hide();if ForeverAssistOptions then ForeverAssistOptions:Show() end end)
  ringEditor:SetScript('OnHide',function() ringCapture=false end)
 end
 P.RefreshRingEditor();if ringEditor:IsShown() then ringEditor:Hide() elseif ForeverAssistShowEditor then ForeverAssistShowEditor(ringEditor) else ringEditor:Show() end
end
local squareBorder,roundMask,roundDecorations
function P.ApplySquareMinimap()
 if not Minimap or not Minimap.SetMaskTexture or combat() then return end
 if roundMask==nil then
  roundMask=Minimap.GetMaskTexture and Minimap:GetMaskTexture() or 'Textures/MinimapMask'
  roundDecorations={}
  local container=MinimapCluster and MinimapCluster.MinimapContainer
  for _,f in pairs({MinimapBorder,MinimapBorderTop,MinimapCompassTexture,container and container.Border,container and container.CompassTexture}) do
   if f and f.Hide then roundDecorations[f]=f:IsShown() end
  end
  squareBorder=CreateFrame('Frame','ForeverAssistSquareMinimapBorder',UIParent,'BackdropTemplate');squareBorder:SetPoint('TOPLEFT',Minimap,'TOPLEFT',-2,2);squareBorder:SetPoint('BOTTOMRIGHT',Minimap,'BOTTOMRIGHT',2,-2);squareBorder:SetFrameStrata(Minimap:GetFrameStrata());squareBorder:SetFrameLevel(Minimap:GetFrameLevel()+2)
  squareBorder:SetBackdrop({edgeFile='Interface/Tooltips/UI-Tooltip-Border',edgeSize=12});squareBorder:SetBackdropBorderColor(.6,.48,.31,1)
  Minimap:HookScript('OnHide',function() squareBorder:Hide() end);Minimap:HookScript('OnShow',function() squareBorder:SetShown(settings().squareMinimap) end)
 end
 local enabled=settings().squareMinimap
 Minimap:SetMaskTexture(enabled and 'Interface/Buttons/WHITE8X8' or roundMask)
 for f,wasShown in pairs(roundDecorations) do if enabled then f:Hide() else f:SetShown(wasShown) end end
 squareBorder:SetShown(enabled and Minimap:IsShown())
end

-- Proxy launchers leave each addon's original position, size and scripts intact.
local launcherWindow,launchers,launcherOrder=nil,{},{}
local ownButton=nil
local launcherPool={}
local nativeNames={MinimapZoomIn=true,MinimapZoomOut=true,MiniMapTracking=true,MiniMapTrackingButton=true,MiniMapMailFrame=true,GameTimeFrame=true,TimeManagerClockButton=true,QueueStatusMinimapButton=true,GarrisonLandingPageMinimapButton=true,MiniMapWorldMapButton=true,MinimapBackdrop=true,MinimapCompassTexture=true}
local function layoutLaunchers()
 if not launcherWindow or combat() then return end
 local visible={}
 for _,d in ipairs(launcherOrder) do if not (d.source.db and d.source.db.hide) then visible[#visible+1]=d end;d.proxy:Hide() end
 local count=#visible
 local maxRows=math.max(1,math.floor(((UIParent:GetHeight() or 768)-100)/40))
 local columns=math.max(3,math.ceil(math.sqrt(math.max(1,count))),math.ceil(count/maxRows))
 local rows=math.max(1,math.ceil(count/columns))
 launcherWindow:SetSize(columns*40+24,rows*40+42)
 for i,d in ipairs(visible) do
  local b=d.proxy
  local source=d.source;local texture=source.icon or source.Icon or source.GetNormalTexture and source:GetNormalTexture()
  if texture and texture.GetTexture then b.icon:SetTexture(texture:GetTexture()) end
  b:ClearAllPoints();b:SetPoint('TOPLEFT',12+((i-1)%columns)*40,-34-math.floor((i-1)/columns)*40);b:Show()
 end
end
local function gatherLaunchers()
 if not Minimap or combat() or not settings().minimapMenu then return end
 if not launcherWindow then
  launcherWindow=CreateFrame('Frame','ForeverAssistLaunchers',UIParent,'BackdropTemplate');launcherWindow:SetPoint('TOPRIGHT',Minimap,'TOPLEFT',-10,0);launcherWindow:SetFrameStrata('DIALOG');launcherWindow:SetClampedToScreen(true)
  launcherWindow:SetBackdrop({bgFile='Interface/Buttons/WHITE8X8',edgeFile='Interface/Tooltips/UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});launcherWindow:SetBackdropColor(.10,.065,.035,0);launcherWindow:SetBackdropBorderColor(.6,.48,.31,0)
  local title=text(launcherWindow);title:SetPoint('TOPLEFT',13,-12);title:SetText('Addons')
  local close=button(launcherWindow,'X',0,0,22,function()launcherWindow:Hide()end);close:ClearAllPoints();close:SetPoint('TOPRIGHT',-6,-5)
  if UISpecialFrames then table.insert(UISpecialFrames,'ForeverAssistLaunchers') end
  launcherWindow:Hide()
 end
 local candidates={};local labels={};if ownButton then candidates[#candidates+1]=ownButton;labels[ownButton]='Trailbound' end
 local lib=LibStub and LibStub('LibDBIcon-1.0',true)
 if lib and lib.objects then for name,b in pairs(lib.objects) do candidates[#candidates+1]=b;labels[b]=name end end
 for _,parent in pairs({Minimap,MinimapBackdrop}) do
  if parent and parent.GetChildren then for _,b in ipairs({parent:GetChildren()}) do
   local n=b:GetName();if n and not nativeNames[n] and b:GetObjectType()=='Button' and b:GetScript('OnClick') then candidates[#candidates+1]=b end
  end end
 end
 for _,b in ipairs(candidates) do
  local parent=b and b:GetParent()
  -- Respect other minimap collectors and protected/native controls.
  if b and not launchers[b] and b:GetObjectType()=='Button' and (b==ownButton or parent==Minimap or parent==MinimapBackdrop) and not (b.IsProtected and b:IsProtected()) and not (b.db and b.db.hide) and (b==ownButton or b:IsShown()) then
   local label=labels[b] or (b:GetName() or 'Addon'):gsub('^LibDBIcon10_','')
   local proxy=launcherPool[b] and launcherPool[b].proxy or CreateFrame('Button',nil,launcherWindow);proxy:SetSize(34,34);proxy:RegisterForClicks('LeftButtonUp','RightButtonUp','MiddleButtonUp')
   proxy.icon=proxy.icon or proxy:CreateTexture(nil,'ARTWORK');proxy.icon:SetPoint('TOPLEFT',2,-2);proxy.icon:SetPoint('BOTTOMRIGHT',-2,2);proxy.icon:SetTexture('Interface/Icons/INV_Misc_QuestionMark')
   proxy:SetHighlightTexture('Interface/Buttons/WHITE8X8');proxy:GetHighlightTexture():SetVertexColor(1,1,1,.15)
   local d={source=b,proxy=proxy,label=label,shown=b:IsShown()};launchers[b]=d;launcherPool[b]=d;launcherOrder[#launcherOrder+1]=d
   proxy:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:AddLine(d.label,1,1,1);GameTooltip:AddLine('Left / right click to open this addon.',.7,.7,.7);GameTooltip:Show()end)
   proxy:SetScript('OnLeave',function()GameTooltip:Hide()end)
   proxy:SetScript('OnClick',function(_,key)
    if combat() then return end
    launcherWindow:Hide();GameTooltip:Hide()
    local click=b:GetScript('OnClick');if click then click(b,key or 'LeftButton',false) end
   end)
   if not b.faLauncherHideHook then
    b.faLauncherHideHook=true
    b:HookScript('OnShow',function(self)if launchers[self] and settings().minimapMenu and not combat() then self:Hide()end end)
   end
   b:Hide()
  end
 end
 table.sort(launcherOrder,function(a,b)return a.label:lower()<b.label:lower()end)
end
function P.MinimapMenu()
 if combat() then say('Open the addon menu after combat.');return end
 if launcherWindow and launcherWindow:IsShown() then launcherWindow:Hide();return end
 gatherLaunchers();if launcherWindow then layoutLaunchers();launcherWindow:Show() end
end
local function restoreLaunchers()
 if combat() then return end
 for b,d in pairs(launchers) do launchers[b]=nil;b:SetShown(d.shown);d.proxy:Hide() end
 launcherOrder={};if ownButton then ownButton:Hide() end;if launcherWindow then launcherWindow:Hide() end
end
local function setupMinimap()
 if not Minimap then return end
 if not ownButton then
  ownButton=CreateFrame('Button','ForeverAssistMinimapButton',UIParent);ownButton:SetSize(30,30);ownButton:RegisterForClicks('LeftButtonUp','RightButtonUp');local icon=ownButton:CreateTexture(nil,'ARTWORK');ownButton.icon=icon;icon:SetAllPoints();icon:SetTexture('Interface/AddOns/Trailbound/Media/TrailboundMark')
  ownButton:SetScript('OnClick',function() if ForeverAssistOptions then ForeverAssistOptions:SetShown(not ForeverAssistOptions:IsShown()) end end)
  -- Consume right-click before the native handler can send a party ping.
  local originalMouseUp=Minimap:GetScript('OnMouseUp')
  Minimap:SetScript('OnMouseUp',function(self,key,...)
   if key=='RightButton' then if settings().minimapMenu then P.MinimapMenu() end;return end
   if key=='LeftButton' and originalMouseUp then originalMouseUp(self,key,...) end
  end)
 end
 if settings().minimapMenu then gatherLaunchers() else ownButton:Hide() end
end
local lootedSlots={}
local speedyLootActive=false
local lootOpened=false
function P.CloseEmptyLoot()
 if not speedyLootActive or not lootOpened or not GetNumLootItems then return end
 for slot=1,GetNumLootItems() do
  if GetLootSlotType then local kind=GetLootSlotType(slot);if kind and kind~=0 then return end end
  if GetLootSlotInfo then local _,name=GetLootSlotInfo(slot);if name then return end end
  if LootSlotHasItem and LootSlotHasItem(slot) then return end
 end
 speedyLootActive=false
 if CloseLoot then CloseLoot() end
end
function P.FastLoot()
 if not settings().fastLoot or not GetNumLootItems or not LootSlot then return end
 local auto
 if C_CVar and C_CVar.GetCVarBool then auto=C_CVar.GetCVarBool('autoLootDefault')
 elseif GetCVarBool then auto=GetCVarBool('autoLootDefault')
 else local get=C_CVar and C_CVar.GetCVar or GetCVar;auto=get and get('autoLootDefault')=='1' end
 local modified=IsModifiedClick and IsModifiedClick('AUTOLOOTTOGGLE') or false
 if (auto==true)==(modified==true) then return end
 local method=GetLootMethod and GetLootMethod() or C_PartyInfo and C_PartyInfo.GetLootMethod and C_PartyInfo.GetLootMethod()
 if method=='master' or method==2 then return end
 speedyLootActive=true
 for slot=GetNumLootItems(),1,-1 do
  local locked
  if GetLootSlotInfo then local _,_,_,_,_,isLocked=GetLootSlotInfo(slot);locked=isLocked end
  if not locked and not lootedSlots[slot] then lootedSlots[slot]=true;pcall(LootSlot,slot) end
 end
end
-- Food and drink use their real helpful auras; Well Fed is a short ready notice.
local nutritionFrame,nutritionAuras,wellFedToken,wellFedUntil=nil,{},nil,0
local foodNames={Food='food',Drink='drink',Refreshment='both',['Food & Drink']='both',['Well Fed']='ready',Cannibalize='cannibalize',Bandage='bandage',Bandaging='bandage',['First Aid']='bandage'}
local function nutritionNames()
 for id,kind in pairs({[430]='food',[431]='drink',[433]='food',[19705]='ready',[20577]='cannibalize',[746]='bandage',[1159]='bandage',[3267]='bandage',[3268]='bandage',[7926]='bandage',[7927]='bandage',[10838]='bandage',[10839]='bandage'}) do
  local fn=C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
  if fn then local ok,v=pcall(fn,id);if ok then local name=type(v)=='table' and v.name or v;if name then foodNames[name]=kind end end end
 end
end
function P.CheckNutrition()
 if not settings().nutritionTimers then nutritionAuras={};wellFedUntil=0;P.UpdateNutrition();return end
 if not ForeverAssistAuraReadable() then return end
 local found,ready={},nil
 local channeling=false
 if UnitChannelInfo then
  local ok,name,_,icon,_,ends,_,_,id=pcall(UnitChannelInfo,'player')
  local secret=issecretvalue and (issecretvalue(name) or issecretvalue(id) or issecretvalue(ends) or issecretvalue(icon))
  if ok and not secret and (id==20577 or foodNames[name]=='cannibalize' or foodNames[name]=='bandage') and type(ends)=='number' and ends/1000>GetTime() then
   channeling=foodNames[name]=='bandage' and 'bandage' or 'cannibalize';found[#found+1]={aura={icon=icon,expirationTime=ends/1000},label=channeling=='bandage' and 'Bandaging' or 'Cannibalize'}
  end
 end
 for i=1,255 do
  local aura,readable=ForeverAssistReadPlayerAura(i);if not readable then return end;if not aura then break end
  local kind=(aura.spellId==20577 or aura.spellId==20578) and 'cannibalize' or foodNames[aura.name]
  if aura.isHarmful~=true and aura.isHelpful~=false and kind then
   if kind=='ready' then ready=tostring(aura.spellId or aura.name)..':'..tostring(aura.expirationTime or aura.auraInstanceID or 0)
   elseif kind~=channeling then found[#found+1]={aura=aura,label=kind=='bandage' and 'Bandaging' or kind=='cannibalize' and 'Cannibalize' or kind=='food' and 'Eating' or kind=='drink' and 'Drinking' or 'Eating and drinking'} end
  end
 end
 nutritionAuras=found
 if ready and ready~=wellFedToken then wellFedUntil=GetTime()+6;say('Well Fed — ready!') end
 wellFedToken=ready
 P.UpdateNutrition()
end
function P.UpdateNutrition()
 if not settings().nutritionTimers and not P.nutritionUnlocked then if nutritionFrame then nutritionFrame:Hide() end;return end
 if #nutritionAuras==0 and wellFedUntil<=GetTime() and not P.nutritionUnlocked then if nutritionFrame then nutritionFrame:Hide() end;return end
 local lines={};local now=GetTime()
 for _,entry in ipairs(nutritionAuras) do
  local expires=entry.aura.expirationTime or 0
  if expires==0 or expires>now then
   local icon=entry.aura.icon and ('|T'..entry.aura.icon..':24|t ') or ''
   lines[#lines+1]=icon..entry.label..(expires>0 and (' — %.1f seconds'):format(expires-now) or ' — active')
  end
 end
 if wellFedUntil>now then lines[#lines+1]='|cff66ff88Well Fed — ready!|r' end
 if #lines==0 and P.nutritionUnlocked then lines[1]='|T134400:24|t Eating — 25.0 seconds';lines[2]='Drag this recovery timer to move it' end
 if #lines==0 then if nutritionFrame then nutritionFrame:Hide() end;return end
 if not nutritionFrame then
  nutritionFrame=CreateFrame('Frame','ForeverAssistNutrition',UIParent);nutritionFrame:SetSize(340,90);position(nutritionFrame,'nutritionPosition',0,145);movable(nutritionFrame,'nutritionPosition');nutritionFrame:SetFrameStrata('HIGH')
  nutritionFrame.label=text(nutritionFrame);nutritionFrame.label:SetAllPoints();nutritionFrame.label:SetFontObject(GameFontNormalLarge)
 end
 nutritionFrame:SetFrameStrata(P.nutritionUnlocked and 'TOOLTIP' or 'HIGH');nutritionFrame:EnableMouse(P.nutritionUnlocked==true)
 nutritionFrame.label:SetText(table.concat(lines,'\n'));nutritionFrame:Show()
end
local junkBindingButton,junkBindingWindow,junkCapture
function P.ApplyJunkBinding()
 if combat() then return end
 if not junkBindingButton then
  junkBindingButton=CreateFrame('Button','ForeverAssistJunkBinding',UIParent);junkBindingButton:SetSize(1,1);junkBindingButton:SetPoint('TOPLEFT');junkBindingButton:SetAlpha(0)
  junkBindingButton:SetScript('OnClick',function() ForeverAssistExtras.ToggleJunk() end)
 end
 ClearOverrideBindings(junkBindingButton)
 if settings().junkKey and settings().junkKey~='' then local ok,result=pcall(SetOverrideBindingClick,junkBindingButton,false,settings().junkKey,'ForeverAssistJunkBinding','LeftButton');if not ok or result==false then say('Could not assign junk manager key. Choose another key outside combat.') end end
end
function P.JunkBindingOptions()
 if not junkBindingWindow then
  local f=window('ForeverAssistJunkBindingOptions','Junk manager keybind',400,230);junkBindingWindow=f
  f.label=text(f);f.label:SetPoint('TOPLEFT',20,-50);f.label:SetWidth(360)
  button(f,'Assign key',20,-115,170,function() if combat() then say('Assign keys outside combat.');return end;junkCapture=true;f.label:SetText('Press a key combination. Escape cancels.');f:SetPropagateKeyboardInput(false) end)
  button(f,'Clear key',210,-115,170,function() if combat() then return end;settings().junkKey='';junkCapture=false;P.ApplyJunkBinding();f.label:SetText('Current key: Unbound') end)
  f:EnableKeyboard(true);f:SetPropagateKeyboardInput(true)
  f:SetScript('OnKeyDown',function(self,key)
   if not junkCapture or combat() then self:SetPropagateKeyboardInput(true);return end
   self:SetPropagateKeyboardInput(false)
   if key=='ESCAPE' then junkCapture=false;self:SetPropagateKeyboardInput(true);self.label:SetText('Current key: '..(settings().junkKey or 'Unbound'));return end
   if key:find('SHIFT') or key:find('CTRL') or key:find('ALT') then return end
   local binding=(IsAltKeyDown() and 'ALT-' or '')..(IsControlKeyDown() and 'CTRL-' or '')..(IsShiftKeyDown() and 'SHIFT-' or '')..key
   for name in pairs(account.rings) do if character.ringBindings[name]==binding then self.label:SetText('That key opens '..name..'. Choose another key.');return end end
   settings().junkKey=binding;junkCapture=false;P.ApplyJunkBinding();self:SetPropagateKeyboardInput(true);self.label:SetText('Current key: '..binding..'\nOpens the same manager as /junk.')
  end)
  f:SetScript('OnHide',function(self) junkCapture=false;self:SetPropagateKeyboardInput(true) end)
  button(f,'Back to vendor options',20,-180,360,function() f:Hide();if ForeverAssistOptions then ForeverAssistOptions:Show() end;if ForeverAssistJunkOptions then ForeverAssistJunkOptions:Show() end end)
 end
 junkBindingWindow.label:SetText('Current key: '..((settings().junkKey and settings().junkKey~='') and settings().junkKey or 'Unbound')..'\nOpens the same manager as /junk. Assigned keys take priority over existing bindings.')
 if ForeverAssistShowEditor then ForeverAssistShowEditor(junkBindingWindow) else junkBindingWindow:Show() end
end

local playOptions={}
function P.CloseOptions() if junkBindingWindow then junkBindingWindow:Hide() end;for _,f in pairs(playOptions) do f:Hide() end;if ringEditor then ringEditor:Hide() end end
function P.Options(category)
 if not category and ForeverAssistOptions then ForeverAssistOptions:SetShown(not ForeverAssistOptions:IsShown());return end
 category=category or 'combat'
 local page=playOptions[category]
 if not page then
  local titles={combat='Combat messages',xp='Experience bar',swing='Swing timer',nutrition='Food and drink',camp='Camp notices',bags='Bag movement',minimap='Minimap buttons',loot='Looting'}
  page=window('ForeverAssistPlayOptions_'..category,titles[category] or 'Gameplay',440,300);playOptions[category]=page
  local function check(key,label,y)
   local c=CreateFrame('CheckButton',nil,page,'UICheckButtonTemplate');c:SetPoint('TOPLEFT',20,y);local t=text(c);t:SetPoint('LEFT',c,'RIGHT',3,0);t:SetText(label)
   c:SetScript('OnClick',function(self) settings()[key]=self:GetChecked() and true or false;P.ApplySettings() end);c:HookScript('OnShow',function(self) self:SetChecked(settings()[key]) end)
  end
  if category=='swing' then
   page:ClearAllPoints();page:SetPoint('CENTER',UIParent,'CENTER',-360,100)
   check('swingTimer','Enable weapon and wand swing timers',-48)
   page:SetHeight(550)
   local controls={}
   local function slider(key,title,x,y,lo,hi,step,default)
    local value=text(page);value:SetPoint('TOPLEFT',x,y);value:SetWidth(190);value:SetText(title..': '..string.format('%g',settings()[key]or default))
    local name='ForeverAssistSwing_'..key
    local s=CreateFrame('Slider',name,page,'OptionsSliderTemplate');s:SetPoint('TOPLEFT',x,y-25);s:SetSize(185,18);s:SetMinMaxValues(lo,hi);s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local low=s.Low or _G[name..'Low'];local high=s.High or _G[name..'High'];local titleText=s.Text or _G[name..'Text']
    if low then low:SetText(lo) end;if high then high:SetText(hi) end;if titleText then titleText:SetText('') end
    s:SetScript('OnValueChanged',function(self,v)
     v=math.max(lo,math.min(hi,math.floor(v/step+.5)*step));value:SetText(title..': '..string.format('%g',v));if self.syncing then return end;settings()[key]=v;updateSwings()
     if ForeverAssistLayout and ForeverAssistLayout.active then ForeverAssistLayout.Apply() end
    end)
    controls[#controls+1]=function()local v=settings()[key] or default;s.syncing=true;s:SetValue(v);s.syncing=false;value:SetText(title..': '..string.format('%g',v))end
   end
   slider('swingWidth','Width',20,-100,100,600,10,240);slider('swingHeight','Height',230,-100,8,40,1,18)
   slider('swingGap','Spacing',20,-175,0,20,1,4);slider('swingFontSize','Text size',230,-175,8,24,1,11)
   slider('swingOpacity','Opacity',20,-250,.2,1,.05,1)
   local function option(key,title,y,default)
    local c=CreateFrame('CheckButton',nil,page,'UICheckButtonTemplate');c:SetPoint('TOPLEFT',230,y);local t=text(c);t:SetPoint('LEFT',c,'RIGHT',2,0);t:SetText(title)
    c:SetScript('OnClick',function(self)settings()[key]=self:GetChecked() and true or false;updateSwings()end)
    controls[#controls+1]=function()local v=settings()[key];if v==nil then v=default end;c:SetChecked(v)end
   end
   option('swingCaptions','Show weapon names',-245,true);option('swingSeconds','Show seconds',-280,true);option('swingReverse','Reverse fill direction',-315,false)
   local style=button(page,'Texture: Shaded',20,-365,190,function(self)settings().swingFlat=not settings().swingFlat;self:SetText(settings().swingFlat and 'Texture: Flat' or 'Texture: Shaded');updateSwings()end)
   local colorNames={'Gold','Teal','Blue','Purple'}
   local color=button(page,'Color: Gold',230,-365,190,function(self)settings().swingColor=(settings().swingColor or 1)%4+1;self:SetText('Color: '..colorNames[settings().swingColor]);updateSwings()end)
   button(page,'Reset appearance and position',20,-410,400,function()
    for _,key in ipairs({'swingPosition','swingWidth','swingHeight','swingGap','swingFontSize','swingOpacity','swingCaptions','swingSeconds','swingReverse','swingFlat','swingColor'}) do settings()[key]=nil end
    position(swingFrame,'swingPosition',0,-140);for _,refresh in ipairs(controls) do refresh() end;style:SetText('Texture: Shaded');color:SetText('Color: Gold');updateSwings()
   end)
   local note=text(page);note:SetPoint('TOPLEFT',20,-460);note:SetWidth(400);note:SetText('Live preview: drag the bars to move them. Sliders update instantly.\nClose this editor to finish, or use Edit mode to arrange every display.')
   page.Refresh=function()for _,refresh in ipairs(controls) do refresh() end;style:SetText(settings().swingFlat and 'Texture: Flat' or 'Texture: Shaded');color:SetText('Color: '..(colorNames[settings().swingColor or 1] or 'Gold'))end
   page:SetScript('OnShow',function()page.Refresh();P.swingUnlocked=true;updateSwings()end);page:SetScript('OnHide',function() P.swingUnlocked=false;updateSwings() end)
  elseif category=='xp' then
   check('xpDetails','Enable custom experience bar',-48)
   button(page,'Reset XP bar position',20,-100,400,function() settings().xpPosition=nil;position(xpFrame,'xpPosition',0,-210) end)
   local note=text(page);note:SetPoint('TOPLEFT',20,-150);note:SetWidth(400);note:SetText('Drag the XP bar to move it. Numbers, time to level and estimated mobs stay visible.\nHover for rested XP, session totals, played time, quest rewards and recent kill XP.')
  elseif category=='combat' then check('quietErrors','Hide and mute common combat errors',-48)
  elseif category=='nutrition' then
   check('nutritionTimers','Food, drink, bandage & Cannibalize timers',-48)
   local unlock=button(page,'Unlock and preview timer',20,-100,400,function(self)
    P.nutritionUnlocked=not P.nutritionUnlocked;self:SetText(P.nutritionUnlocked and 'Lock timer' or 'Unlock and preview timer');P.UpdateNutrition()
   end)
   button(page,'Reset timer position',20,-140,400,function() settings().nutritionPosition=nil;if nutritionFrame then position(nutritionFrame,'nutritionPosition',0,145) end end)
   local note=text(page);note:SetPoint('TOPLEFT',20,-185);note:SetWidth(400);note:SetText('Unlock to show a draggable preview without eating or bandaging. Closing this editor locks the timer. Its position is saved in your profile.')
   page:SetScript('OnHide',function() P.nutritionUnlocked=false;unlock:SetText('Unlock and preview timer');P.UpdateNutrition() end)
  elseif category=='camp' then check('campNotices','Camp notices, Sit button and welcome timer',-48)
  elseif category=='bags' then check('moveBags','Enable movable bag handles',-48);button(page,'Reset bag positions',20,-100,400,function() P.ResetBags();say('Bag positions reset.') end)
  elseif category=='minimap' then check('minimapMenu','Show addon icons on minimap right-click',-48);check('squareMinimap','Use a square minimap',-88)
  elseif category=='loot' then check('fastLoot','Faster auto looting and instant window close',-48) end
  button(page,'Back to settings',20,-260,400,function() page:Hide();if ForeverAssistOptions then ForeverAssistOptions:Show() end end)
 end
 for _,other in pairs(playOptions) do if other~=page then other:Hide() end end
 if page.Refresh then page.Refresh()end
 if page:IsShown() then page:Hide() elseif ForeverAssistShowEditor then ForeverAssistShowEditor(page) else page:Show() end
end
local events=CreateFrame('Frame');local clock,slowClock,swingClock=0,0,0
function P.Initialize(a,c,get)
 account,character,settings=a,c,get;
 ForeverAssistBuffTracker.Initialize(get)
 if not character.cameraFourMigration then settings().cameraFactor=4;settings().cameraRequest="4";character.cameraFourMigration=true end
character.keptJunk=character.keptJunk or {};account.mailRecipients=account.mailRecipients or {};account.rings=account.rings or {Portals={auto='portals',key='',entries={}},Professions={auto='professions',key='',entries={}}}
 character.ringBindings=character.ringBindings or {}
 -- Adopt old account binds on this character once, then remove their shared source.
 for name,def in pairs(account.rings) do
  if character.ringBindings[name]==nil and def.key and def.key~='' then character.ringBindings[name]=def.key end
  def.key=nil
 end
 if not account.petRingDefaultsAdded then
  account.rings['Warlock pets']=account.rings['Warlock pets'] or {auto='warlockPets',entries={},key=''}
  account.rings['Hunter pets']=account.rings['Hunter pets'] or {auto='hunterPets',entries={},key=''}
  account.petRingDefaultsAdded=true
 end
 if settings().xpLocked==nil then settings().xpLocked=true end
 for _,key in ipairs({'quietErrors','xpDetails','swingTimer','campNotices','moveBags','minimapMenu','fastLoot','squareMinimap','nutritionTimers'}) do if settings()[key]==nil then settings()[key]=true end end
 for _,event in ipairs({'LOOT_READY','LOOT_OPENED','LOOT_SLOT_CLEARED','LOOT_CLOSED','PLAYER_LOGIN','ADDON_LOADED','PLAYER_XP_UPDATE','CHAT_MSG_COMBAT_XP_GAIN','QUEST_LOG_UPDATE','QUEST_DATA_LOAD_RESULT','UPDATE_EXHAUSTION','TIME_PLAYED_MSG','UNIT_AURA','UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_UPDATE','UNIT_SPELLCAST_CHANNEL_STOP','PLAYER_SWING','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_INTERRUPTED','MERCHANT_SHOW','MERCHANT_UPDATE','MERCHANT_CLOSED','MAIL_SHOW','MAIL_SEND_SUCCESS','MAIL_FAILED','MAIL_CLOSED','TRAINER_SHOW','TRAINER_CLOSED','BAG_UPDATE_DELAYED','SPELLS_CHANGED','PLAYER_REGEN_ENABLED'}) do pcall(events.RegisterEvent,events,event) end
 if BuybackItem then hooksecurefunc('BuybackItem',P.BoughtBack) end
 if SendMail then hooksecurefunc('SendMail',function(name) mailPending=name end) end
 if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then hooksecurefunc(C_TradeSkillUI,'CraftRecipe',function(id,count) P.CraftStart(id,count) end) end
 if DoTradeSkill then hooksecurefunc('DoTradeSkill',function(_,count) P.CraftStart(nil,count) end) end
 if UpdateContainerFrameAnchors then hooksecurefunc('UpdateContainerFrameAnchors',P.ApplyBagPositions) end
end
local stanceHooks={}
function P.ApplyStanceBar()
 if combat() then return end
 for _,name in ipairs({'StanceBar','StanceBarFrame','ShapeshiftBarFrame'}) do
  local f=_G[name]
  if f then
   if not stanceHooks[f] then
    stanceHooks[f]={shown=f:IsShown()}
    f:HookScript('OnShow',function(self) if settings().hideStanceBar and not combat() then self:Hide() end end)
   end
   local state=stanceHooks[f]
   if settings().hideStanceBar then
    if not state.hidden then state.shown=f:IsShown();state.hidden=true end
    f:Hide()
   elseif state.hidden then state.hidden=false;if state.shown then f:Show() end end
  end
 end
end
function P.ApplySettings() if not account then return end;ForeverAssistBuffTracker.ApplySettings();for _,key in ipairs({'quietErrors','xpDetails','swingTimer','campNotices','moveBags','minimapMenu','fastLoot','squareMinimap','nutritionTimers'}) do if settings()[key]==nil then settings()[key]=true end end;P.BuildRings();P.ApplyStanceBar();P.ApplyJunkBinding();setupErrors();hookBags();P.CheckCamp();P.CheckNutrition();if nutritionFrame then position(nutritionFrame,'nutritionPosition',0,145) end;P.ApplySquareMinimap();if settings().minimapMenu then setupMinimap() else restoreLaunchers() end end
function P.Event(_,event,a,b,c)
 if not account then return end
 if event=='LOOT_READY' then P.FastLoot()
 elseif event=='LOOT_OPENED' then lootOpened=true;P.FastLoot();P.CloseEmptyLoot()
 elseif event=='LOOT_SLOT_CLEARED' then P.CloseEmptyLoot()
 elseif event=='LOOT_CLOSED' then lootedSlots={};speedyLootActive=false;lootOpened=false
 elseif event=='PLAYER_LOGIN' then
  P.ApplyStanceBar();say('Version '..P.Version..' loaded.');sessionStart=GetTime();sessionXP=0;P.RecordXP();createXP();createSwings();P.ApplySquareMinimap();P.RefreshQuests();nutritionNames();P.CheckNutrition();P.ApplyJunkBinding();setupErrors();hookMail();hookTrainer();hookBags();setupMinimap();P.BuildRings();if RequestTimePlayed then RequestTimePlayed() end
 elseif (event=='UNIT_AURA' or event=='UNIT_SPELLCAST_CHANNEL_START' or event=='UNIT_SPELLCAST_CHANNEL_UPDATE' or event=='UNIT_SPELLCAST_CHANNEL_STOP') and a=='player' then P.CheckNutrition();P.CheckCamp()
 elseif event=='CHAT_MSG_COMBAT_XP_GAIN' then P.RecordMobXP(a)
 elseif event=='PLAYER_XP_UPDATE' and a=='player' then P.RecordXP()
 elseif event=='TIME_PLAYED_MSG' then playedTotal,playedLevel,playedAt,levelPlayedAt=a,b,GetTime(),GetTime()
 elseif event=='QUEST_LOG_UPDATE' or event=='QUEST_DATA_LOAD_RESULT' then P.RefreshQuests()
 elseif event=='PLAYER_SWING' then P.Swing(a,b)
 elseif event=='MERCHANT_SHOW' then paused=false;P.CacheBuybacks()
 elseif event=='MERCHANT_UPDATE' then P.CacheBuybacks()
 elseif event=='MERCHANT_CLOSED' then paused=false;ForeverAssistExtras.CancelAutomaticSale()
 elseif event=='MAIL_SHOW' then hookMail()
 elseif event=='MAIL_SEND_SUCCESS' then if mailPending then P.RememberRecipient(mailPending);mailPending=nil end
 elseif event=='MAIL_FAILED' or event=='MAIL_CLOSED' then mailPending=nil;if mailWindow then mailWindow:Hide() end
 elseif event=='TRAINER_SHOW' then hookTrainer()
 elseif event=='TRAINER_CLOSED' then training=nil
 elseif event=='UNIT_SPELLCAST_SUCCEEDED' and a=='player' and craft and (not craft.id or c==craft.id or c==craft.activeSpell) then craft.remaining=craft.remaining-1;if craft.remaining<=0 then craft=nil end
 elseif (event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_INTERRUPTED') and a=='player' then craft=nil
 elseif event=='ADDON_LOADED' then P.ApplyStanceBar();setupErrors();hookBags();hookMail();hookTrainer()
 elseif event=='SPELLS_CHANGED' then paladinCache=nil;P.BuildRings()
 elseif event=='PLAYER_REGEN_ENABLED' then P.ApplySettings()
 elseif event=='BAG_UPDATE_DELAYED' then hookBags()
 end
end
events:SetScript('OnEvent',P.Event)
events:SetScript('OnUpdate',function(_,elapsed)
 animateSwings()
 if not account then return end;trainTick(elapsed);clock=clock+elapsed
 swingClock=swingClock+elapsed;if swingClock>=.05 then swingClock=0;updateSwings() end;slowClock=slowClock+elapsed
 if clock>=.1 then clock=0;P.UpdateCampTimer();P.UpdateNutrition();updateCraft() end
 if slowClock>=1 then slowClock=0;P.UpdateXP();P.CraftPreview();P.CheckCamp();P.CheckNutrition() end
end)
SLASH_FOREVERASSISTPLAY1='/tbplay'
SlashCmdList.FOREVERASSISTPLAY=function(msg)
 if not account then return end
 if msg=='rings' then P.RingEditor() elseif msg=='keep clear' then character.keptJunk={};say('Bought-back item protection cleared.') elseif msg=='mail' then P.MailMenu() else P.Options() end
end
