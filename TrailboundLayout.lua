-- Addon-only layout previews: never open NPC windows or Blizzard Edit Mode.
ForeverAssistLayout={Version='1.8.46',active=false}
local L=ForeverAssistLayout
local getSettings,toolbar
local movers={}
local definitions={
 {'Experience bar','xpPosition',600,35,0,-210,'Level 20   |   Experience bar'},
 {'Swing timers','swingPosition',240,66,0,-140,'Main hand  1.8s\nOff hand  1.2s\nRanged  2.0s'},
 {'Recovery timer','nutritionPosition',420,58,0,145,'Eating / drinking: 25 seconds'},
 {'Buff reminders',false,270,65,0,15,'Class buff / gathering / pet reminders'},
 {'External buffs','externalPosition',560,60,0,230,'Power Infusion on you for next 15 seconds.'},
 {'Campfire Sit','campSitPosition',174,40,0,-65,'Sit at campfire'},
 {'Campfire timer','campWelcomePosition',300,54,0,75,'Welcoming Campfire: 12 seconds'},
 {'Mana rule bar','fsrPosition',160,22,-350,-80,'Five-second mana rule'},
 {'Flight timer','flightPosition',420,45,0,300,'Flight path — 2:15 remaining'},
 {'Level times','levelTimesPosition',230,160,-370,120,'Level 7 in 3:26:42\n/played 3:31:27\nThis level 4:45'},
}
function L.Apply()
 if not getSettings then return end
 local s=getSettings()
 for i,d in ipairs(definitions) do
  local f=movers[i]
  if not f then
   f=CreateFrame('Frame',nil,UIParent,'BackdropTemplate');movers[i]=f;f:SetFrameStrata('DIALOG');f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
   TrailboundTheme.Panel(f,true)
   f.label=f:CreateFontString(nil,'OVERLAY','TrailboundText');f.label:SetPoint('CENTER');f.label:SetWidth(d[3]-8);f.label:SetText(d[1]..' — drag to move\n'..d[7])
   f:SetScript('OnDragStart',function(self)if L.active and not InCombatLockdown() then self:StartMoving()end end)
   f:SetScript('OnDragStop',function(self)
    self:StopMovingOrSizing();if not L.active or InCombatLockdown() then return end
    local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter();local scale=self:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if x and ux then if d[2] then getSettings()[d[2]]={x*scale-ux,y*scale-uy} else getSettings().buffX=x*scale-ux;getSettings().buffY=y*scale-uy end end
    if ForeverAssistApplyLayout then ForeverAssistApplyLayout() end
   end)
  end
  local p;if d[2] then p=s[d[2]] else p={s.buffX or d[5],s.buffY or d[6]} end
  f:SetSize(d[2]=='swingPosition' and (s.swingWidth or 240) or d[3],d[2]=='swingPosition' and 3*((s.swingHeight or 18)+(s.swingGap or 4)) or d[4])
  f:ClearAllPoints();f:SetPoint('CENTER',UIParent,'CENTER',p and p[1] or d[5],p and p[2] or d[6]);f:SetShown(L.active)
 end
end
function L.Set(active)
 if active and InCombatLockdown() then print('|cffd2b077Trailbound:|r Enter edit mode after combat.');return end
 L.active=active and true or false
 for _,f in ipairs(movers) do f:StopMovingOrSizing();f:SetShown(L.active) end
 if not toolbar then
  toolbar=CreateFrame('Frame','ForeverAssistLayoutToolbar',UIParent,'BackdropTemplate');toolbar:SetSize(420,65);toolbar:SetPoint('TOP',UIParent,'TOP',0,-45);toolbar:SetFrameStrata('TOOLTIP')
  TrailboundTheme.Panel(toolbar,true)
  local t=toolbar:CreateFontString(nil,'OVERLAY','TrailboundText');t:SetPoint('TOP',0,-8);t:SetText('Trailbound edit mode — drag the outlined previews')
  local b=CreateFrame('Button',nil,toolbar,'UIPanelButtonTemplate');b:SetSize(170,25);b:SetPoint('BOTTOM',0,5);b:SetText('Done — lock positions');b:SetScript('OnClick',function()L.Set(false)end);ForeverAssistStyleButton(b)
  toolbar:SetScript('OnHide',function()if L.active then L.Set(false) end end)
  if UISpecialFrames then table.insert(UISpecialFrames,'ForeverAssistLayoutToolbar') end
 end
 toolbar:SetShown(L.active)
 if L.active then if ForeverAssistOptions then ForeverAssistOptions:Hide() end;L.Apply() end
 if not InCombatLockdown() and ForeverAssistApplyLayout then ForeverAssistApplyLayout() end
end
function L.Initialize(get) getSettings=get end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_REGEN_DISABLED');events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent',function(_,event)if event=='PLAYER_REGEN_DISABLED' and L.active then L.Set(false) elseif event=='PLAYER_REGEN_ENABLED' and ForeverAssistApplyLayout then ForeverAssistApplyLayout() end end)
