-- Character milestones use the server's /played counters, never wall-clock dates.
ForeverAssistLevels={Version='1.8.46'}
local L=ForeverAssistLevels
local character,settings,window,total,levelSeconds,sampledAt
local function publicNumber(v)return (not issecretvalue or not issecretvalue(v))and type(v)=='number'and v>=0 end
function L.Time(seconds)
 if not publicNumber(seconds)then return 'Waiting for /played'end
 seconds=math.floor(seconds);return ('%d:%02d:%02d'):format(math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
end
function L.Apply()
 if not character or not window then return end
 local s=settings();local p=s.levelTimesPosition
 if not InCombatLockdown()then window:ClearAllPoints();window:SetPoint('CENTER',UIParent,'CENTER',p and p[1]or -370,p and p[2]or 120)end
 window:SetShown(s.levelTimes~=false)
 L.Refresh()
end
local function create()
 window=CreateFrame('Frame','ForeverAssistLevelTimes',UIParent,'BackdropTemplate');window:SetWidth(230);window:SetClampedToScreen(true);window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag('LeftButton')
 TrailboundTheme.Panel(window,true)
 window:SetScript('OnDragStart',function(self)if not InCombatLockdown()then self:StartMoving()end end)
 window:SetScript('OnDragStop',function(self)
  self:StopMovingOrSizing();if InCombatLockdown()then return end
  local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter();local scale=self:GetEffectiveScale()/UIParent:GetEffectiveScale()
  if x and ux then settings().levelTimesPosition={x*scale-ux,y*scale-uy}end
 end)
 local function text(font,x,y,width)
  local t=window:CreateFontString(nil,'OVERLAY',font);t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');return t
 end
 window.title=text('TrailboundHeading',10,-8,205);window.title:SetText('Level times');window.title:SetTextColor(unpack(TrailboundTheme.accent))
 window.rows={}
 for i=1,10 do
  local row={label=text('TrailboundSmall',10,-30-(i-1)*19,70),value=text('TrailboundSmall',83,-30-(i-1)*19,137)}
  row.value:SetTextColor(unpack(TrailboundTheme.accent));window.rows[i]=row
 end
 window.played=text('TrailboundSmall',10,-60,210);window.current=text('TrailboundSmall',10,-80,210)
 window.note=text('TrailboundMuted',10,-100,210)
 window:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine('Drag to move. Milestones are total /played when each level began.');GameTooltip:Show()end)
 window:SetScript('OnLeave',function()GameTooltip:Hide()end)
end
function L.Refresh()
 if not character or not window then return end
 local level=UnitLevel('player');if not publicNumber(level)or level<1 then return end
 local known={}
 for n=math.max(1,level-9),level do local entry=character.levelTimes[n];if entry and publicNumber(entry.at)then known[#known+1]={level=n,entry=entry}end end
 local count=#known
 for i,row in ipairs(window.rows)do
  local record=known[i];local n=record and record.level;local entry=record and record.entry
  row.label:SetShown(i<=count);row.value:SetShown(i<=count)
  if i<=count then
   row.label:SetText('Level '..n)
   row.value:SetText((entry.estimated and '~ 'or '')..L.Time(entry.at))
  end
 end
 local y=-35-count*19
 window.played:ClearAllPoints();window.played:SetPoint('TOPLEFT',10,y)
 window.current:ClearAllPoints();window.current:SetPoint('TOPLEFT',10,y-22)
 window.note:Hide()
 local elapsed=sampledAt and math.max(0,GetTime()-sampledAt)or 0
 window.played:SetText('/played   '..L.Time(total and total+elapsed))
 window.current:SetText('This level   '..L.Time(levelSeconds and levelSeconds+elapsed))
 window:SetHeight(count*19+85)
end
function L.Event(_,event,a,b)
 if not character then return end
 if event=='TIME_PLAYED_MSG'then
  if not publicNumber(a)or not publicNumber(b)or b>a then return end
  total,levelSeconds,sampledAt=a,b,GetTime()
  local level=UnitLevel('player')
  if publicNumber(level)and level>=1 then character.levelTimes[level]={at=a-b}end
 elseif event=='PLAYER_LEVEL_UP'then
  if not publicNumber(a)or a<1 then return end
  local played=total and total+math.max(0,GetTime()-sampledAt)
  if played then character.levelTimes[a]={at=math.floor(played),estimated=true};total,levelSeconds,sampledAt=played,0,GetTime()end
  -- Exact new-level start replaces the provisional timestamp on response.
  if RequestTimePlayed then RequestTimePlayed()end
 elseif event=='PLAYER_REGEN_ENABLED'then L.Apply()end
 L.Refresh()
end
function L.Initialize(db,get)
 character,settings=db,get;character.levelTimes=character.levelTimes or {};character.levelTimes[1]=character.levelTimes[1]or {at=0}
 total,levelSeconds,sampledAt=nil,nil,nil
 if not window then create()end;L.Apply()
end
local frame=CreateFrame('Frame')
for _,event in ipairs({'TIME_PLAYED_MSG','PLAYER_LEVEL_UP','PLAYER_REGEN_ENABLED'})do frame:RegisterEvent(event)end
frame:SetScript('OnEvent',L.Event)
local elapsed=0;frame:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>=1 then elapsed=0;if window and window:IsShown()then L.Refresh()end end end)
