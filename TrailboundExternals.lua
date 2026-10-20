-- External notices require readable, timed auras from a confirmed other player.
ForeverAssistExternals={Version='1.8.54'}
local X=ForeverAssistExternals
local getSettings,root,options
local spells={[10060]=true,[29166]=true,[1022]=true,[5599]=true,[10278]=true,[1044]=true,
 [6940]=true,[20729]=true,[33206]=true,[402004]=true,[6346]=true,
 [17]=true,[592]=true,[600]=true,[3747]=true,[6065]=true,[6066]=true,
 [10898]=true,[10899]=true,[10900]=true,[10901]=true}
local function safe(v) return not issecretvalue or not issecretvalue(v) end
function X.Accept(a)
 if type(a)~='table' or issecrettable and issecrettable(a) or not safe(a.spellId) or not spells[a.spellId] then return false end
 for _,key in ipairs({'sourceUnit','name','duration','expirationTime','isHelpful','isHarmful'}) do if not safe(a[key]) then return false end end
 if a.isHarmful or a.isHelpful==false or type(a.name)~='string' or type(a.duration)~='number' or a.duration<=0 or type(a.expirationTime)~='number' or a.expirationTime<=GetTime() then return false end
 local source=a.sourceUnit
 if type(source)~='string' or source=='player' or not UnitIsUnit or not UnitIsPlayer then return false end
 local ok,mine=pcall(UnitIsUnit,source,'player');if not ok or not safe(mine) or mine then return false end
 local valid,player=pcall(UnitIsPlayer,source);return valid and safe(player) and player==true
end
function X.Refresh()
 if not getSettings then return end
 if not root then
  root=CreateFrame('Frame','ForeverAssistExternalsText',UIParent);root:SetSize(560,90);root:SetFrameStrata('HIGH')
  root.label=root:CreateFontString(nil,'OVERLAY','TrailboundText');root.label:SetAllPoints();root.label:SetJustifyH('CENTER')
 end
 local c=getSettings();local p=c.externalPosition;root:ClearAllPoints();root:SetPoint('CENTER',UIParent,'CENTER',p and p[1] or 0,p and p[2] or 230)
 root.label:SetFont(STANDARD_TEXT_FONT,c.externalFontSize or 18,'OUTLINE');root.label:SetTextColor(unpack(TrailboundTheme.accent))
 local lines={}
 if c.externalNotices~=false and not (ForeverAssistLayout and ForeverAssistLayout.active) then
  for i=1,255 do
   local a,readable=ForeverAssistReadPlayerAura(i)
   if not readable then lines={};break end
   if not a then break end
   if X.Accept(a) then lines[#lines+1]=('%s on you for next %d seconds.'):format(a.name,math.ceil(a.expirationTime-GetTime())) end
  end
 end
 root.label:SetText(table.concat(lines,'\n'));root:SetHeight(math.max(30,#lines*((c.externalFontSize or 18)+5)));root:SetShown(#lines>0)
end
function X.Initialize(get) getSettings=get;X.Refresh() end
function X.Options()
 if not options then
  options=CreateFrame('Frame','ForeverAssistExternalOptions',UIParent,'BackdropTemplate');options:SetSize(490,320)
  local title=options:CreateFontString(nil,'OVERLAY','TrailboundTitle');title:SetPoint('TOPLEFT',20,-20);title:SetText('External buff notices')
  local c=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate');c:SetPoint('TOPLEFT',20,-65)
  local label=c:CreateFontString(nil,'OVERLAY','TrailboundText');label:SetPoint('LEFT',c,'RIGHT',3,0);label:SetText('Show important buffs from other players')
  c:SetScript('OnClick',function(self)getSettings().externalNotices=self:GetChecked() and true or false;X.Refresh()end)
  options:SetScript('OnShow',function()c:SetChecked(getSettings().externalNotices~=false)end)
  local help=options:CreateFontString(nil,'OVERLAY','TrailboundText');help:SetPoint('TOPLEFT',20,-115);help:SetWidth(440);help:SetJustifyH('LEFT');help:SetText('Power Infusion, Innervate, protection, freedom, sacrifice, Fear Ward and shields from another player.\n\nOnly confirmed aura durations are shown. Restricted or unknown casters are hidden.\n\nUse Edit mode to move the text notice. Your own cooldowns are excluded.')
  options:Hide()
 end
 if ForeverAssistShowEditor then ForeverAssistShowEditor(options) else options:Show() end
end
local events=CreateFrame('Frame');events:RegisterEvent('UNIT_AURA');events:RegisterEvent('PLAYER_ENTERING_WORLD')
events:SetScript('OnEvent',function(_,event,unit)if event~='UNIT_AURA' or safe(unit) and unit=='player' then X.Refresh() end end)
local elapsed=0
events:SetScript('OnUpdate',function(_,dt)elapsed=elapsed+dt;if elapsed>=.25 then elapsed=0;X.Refresh() end end)
