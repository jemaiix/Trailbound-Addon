-- Shared addon-only typography and surfaces. Never restyle Blizzard font objects.
TrailboundTheme={accent={.94,.80,.48},text={.96,.89,.76},muted={.73,.64,.51}}
local theme=TrailboundTheme
if CreateFont then
 for name,definition in pairs({TrailboundText={12,theme.text},TrailboundSmall={11,theme.text},TrailboundHeading={12,theme.accent},TrailboundTitle={16,theme.accent},TrailboundMuted={10,theme.muted}})do
  local font=CreateFont(name);font:SetFont('Fonts/FRIZQT__.TTF',definition[1],'');font:SetTextColor(unpack(definition[2]))
 end
end
function theme.Panel(frame,compact)
 if not frame or not frame.SetBackdrop then return end
 frame:SetBackdrop({bgFile='Interface/DialogFrame/UI-DialogBox-Background',edgeFile=compact and 'Interface/Buttons/WHITE8X8'or 'Interface/DialogFrame/UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=compact and 1 or 24,insets={left=compact and 1 or 6,right=compact and 1 or 6,top=compact and 1 or 6,bottom=compact and 1 or 6}})
 frame:SetBackdropColor(.22,.17,.12,.96);frame:SetBackdropBorderColor(.6,.48,.31,1)
end
-- Money formatting across modern and older client API layouts.
function ForeverAssistMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local fn = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString or GetMoneyString
    if fn then
        local ok, text = pcall(fn, copper)
        if ok and type(text) == "string" then return text end
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local coins = copper % 100
    if gold > 0 then return ("%dg %ds %dc"):format(gold, silver, coins) end
    if silver > 0 then return ("%ds %dc"):format(silver, coins) end
    return coins .. "c"
end

-- Never enumerate restricted auras. Nil,false means unavailable, not "no buffs".
local auraRetryAt=0
function ForeverAssistAuraReadable(index)
 if GetTime and GetTime()<auraRetryAt then return false end
 if C_Secrets then
  if C_Secrets.ShouldAurasBeSecret then local ok,restricted=pcall(C_Secrets.ShouldAurasBeSecret);if not ok or restricted then return false end end
  if C_Secrets.ShouldUnitAuraIndexBeSecret then local ok,restricted=pcall(C_Secrets.ShouldUnitAuraIndexBeSecret,'player',index or 1);if not ok or restricted then return false end end
 end
 return true
end
function ForeverAssistReadPlayerAura(index)
 if not ForeverAssistAuraReadable(index) then return nil,false end
 local ok,a
 if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then ok,a=pcall(C_UnitAuras.GetAuraDataByIndex,'player',index,'HELPFUL')
 elseif UnitBuff then
  local name,icon,count,dispel,seconds,expires,source,steal,personal,id
  ok,name,icon,count,dispel,seconds,expires,source,steal,personal,id=pcall(UnitBuff,'player',index)
  if name then a={name=name,icon=icon,applications=count,duration=seconds,expirationTime=expires,sourceUnit=source,spellId=id} end
 else return nil,true end
 if not ok then auraRetryAt=(GetTime and GetTime() or 0)+5;return nil,false end
 if not a then return nil,true end
 return ForeverAssistCleanAura(a)
end
function ForeverAssistCleanAura(a)
 if type(a)~="table" then return nil,false end
 if issecrettable and issecrettable(a) then return nil,false end
 local clean={}
 for _,key in ipairs({'name','icon','applications','duration','expirationTime','sourceUnit','spellId','spellID','isHelpful','isHarmful','auraInstanceID'}) do
  local value=a[key]
  if issecretvalue and issecretvalue(value) then return nil,false end
  clean[key]=value
 end
 return clean,true
end

-- Shared styling for ForeverAssist-owned text buttons only.
function ForeverAssistStyleButton(b)
 if not b or b.faButtonSkin then return b end
 for _,method in ipairs({'GetNormalTexture','GetPushedTexture','GetHighlightTexture','GetDisabledTexture'}) do
  if b[method] then local texture=b[method](b);if texture then texture:Hide() end end
 end
 for _,key in ipairs({'Left','Middle','Right'}) do if b[key] and b[key].Hide then b[key]:Hide() end end
 local skin=CreateFrame('Frame',nil,b,'BackdropTemplate');skin:SetAllPoints(b);skin:EnableMouse(false)
 if skin.SetFrameLevel and b.GetFrameLevel then skin:SetFrameLevel(b:GetFrameLevel()+1) end
 skin:SetBackdrop({bgFile='Interface/Buttons/WHITE8X8',edgeFile='Interface/Buttons/WHITE8X8',edgeSize=1})
 skin:SetBackdropColor(.14,.09,.045,1);skin:SetBackdropBorderColor(.48,.34,.17,1)
 local label=skin:CreateFontString(nil,'OVERLAY','TrailboundSmall');label:SetPoint('CENTER');label:SetText(b:GetText() or '');label:SetTextColor(.96,.86,.65)
 if b.GetFontString then local old=b:GetFontString();if old then old:Hide() end end
 b.faButtonSkin=skin;skin.label=label
 hooksecurefunc(b,'SetText',function(_,value)label:SetText(value or '')end)
 b:HookScript('OnEnter',function()skin:SetBackdropColor(.26,.17,.07,1)end)
 b:HookScript('OnLeave',function()skin:SetBackdropColor(.14,.09,.045,1)end)
 b:HookScript('OnDisable',function()label:SetTextColor(.47,.42,.33)end)
 b:HookScript('OnEnable',function()label:SetTextColor(.96,.86,.65)end)
 return b
end
-- Keep mail addresses separate from display names and stable character keys.
function ForeverAssistFullMailName(unit)
 for _,api in ipairs({'UnitNameUnmodified','UnitFullName','UnitName'}) do
  if type(_G[api])=='function' then
   local ok,name=pcall(_G[api],unit)
   if ok and type(name)=='string' and name:find('%S+%s+%S+') then return name:match('^%s*(.-)%s*$') end
  end
 end
end
