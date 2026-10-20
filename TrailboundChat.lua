ForeverAssistChat={Version='1.8.46'}
local C=ForeverAssistChat
local settings,options,copyWindow,copyBox
local identities,wrapped={},{ }
local function safe(v)return not issecretvalue or not issecretvalue(v)end
local events={'SAY','YELL','WHISPER','WHISPER_INFORM','PARTY','PARTY_LEADER','RAID','RAID_LEADER','RAID_WARNING','GUILD','OFFICER','CHANNEL','INSTANCE_CHAT','INSTANCE_CHAT_LEADER'}
function C.Remember(author,guid)
 if not safe(author) or not safe(guid) or type(author)~='string' or type(guid)~='string' or not GetPlayerInfoByGUID then return end
 local ok,_,class,_,race,sex=pcall(GetPlayerInfoByGUID,guid)
 if not ok or not safe(class) or not safe(race) or not safe(sex) then return end
 if type(class)=='string' and type(race)=='string' then identities[author]={class=class,race=race,sex=sex} end
end
local function hex(s)return (s:gsub('.',function(c)return ('%02x'):format(c:byte())end))end
local function unhex(s)if #s%2~=0 or s:find('[^%x]')then return end;return (s:gsub('%x%x',function(v)return string.char(tonumber(v,16))end))end
function C.Copy(value)
 if not copyWindow then
  copyWindow=CreateFrame('Frame','ForeverAssistChatCopy',UIParent,'BackdropTemplate');copyWindow:SetSize(610,340);copyWindow:SetPoint('CENTER');copyWindow:SetFrameStrata('DIALOG');copyWindow:SetClampedToScreen(true)
  copyWindow:SetBackdrop({bgFile='Interface/Buttons/WHITE8X8',edgeFile='Interface/Buttons/WHITE8X8',edgeSize=1});copyWindow:SetBackdropColor(.10,.065,.035,.98)
  local title=copyWindow:CreateFontString(nil,'OVERLAY','TrailboundText');title:SetPoint('TOPLEFT',16,-15);title:SetText('Copy chat / link — Ctrl+C, then Escape')
  local close=CreateFrame('Button',nil,copyWindow,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-3,-3)
  local scroll=CreateFrame('ScrollFrame',nil,copyWindow,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',16,-45);scroll:SetPoint('BOTTOMRIGHT',-35,15)
  copyBox=CreateFrame('EditBox',nil,scroll);copyBox:SetMultiLine(true);copyBox:SetFontObject('ChatFontNormal');copyBox:SetSize(550,260);copyBox:SetAutoFocus(false);scroll:SetScrollChild(copyBox)
  copyBox:SetScript('OnTextChanged',function(self)local _,lines=self:GetText():gsub('\n','');self:SetHeight(math.max(260,(lines+1)*18))end)
  copyBox:SetScript('OnEscapePressed',function()copyWindow:Hide()end);table.insert(UISpecialFrames,'ForeverAssistChatCopy')
 end
 copyWindow:Show();copyBox:SetText(value);copyBox:HighlightText();copyBox:SetFocus()
end
function C.Link(link)
 local data=safe(link)and type(link)=='string' and link:match('^faurl:(%x+)$');if not data then return false end
 local value=unhex(data);if value then C.Copy(value)end;return true
end
local function urls(text)
 local function convert(url)
  local tail=url:match('([%.,!%?%;%)]*)$') or '';url=url:sub(1,#url-#tail)
  return '|cff65d9ff|Hfaurl:'..hex(url)..'|h['..url..']|h|r'..tail
 end
 local parts,at={},1
 while true do
  local http=text:find('https?://',at);local www=text:find('www%.',at)
  local first=http and www and math.min(http,www)or http or www
  if not first then parts[#parts+1]=text:sub(at);break end
  local url=text:sub(first):match('^[^%s|<>]+');if not url then break end
  parts[#parts+1]=text:sub(at,first-1);parts[#parts+1]=convert(url);at=first+#url
 end
 return table.concat(parts)
end
function C.Format(message)
 if not settings or not safe(message) or type(message)~='string' then return message end
 if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return message end
 local c=settings();local s=message
 if c.chatCompact then
  local channels={Guild='G',Party='P',Raid='R',Officer='O',Instance='I',['Raid Leader']='RL',['Party Leader']='PL'}
  for long,short in pairs(channels)do s=s:gsub('%['..long..'%]','['..short..']')end
  s=s:gsub('%[(%d+)%. [^%]]+%]','[%1]')
 end
 s=s:gsub('(|Hplayer:([^|]+)|h.-|h)',function(link,payload)
  local name=payload:match('^([^:]+)');local data=identities[name];if not data then return link end
  local prefix=''
  local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[data.class]
  if c.chatClassIcons and coords then prefix=prefix..('|TInterface/GLUES/CHARACTERCREATE/UI-CHARACTERCREATE-CLASSES:14:14:0:0:256:256:%d:%d:%d:%d|t '):format(coords[1]*256,coords[2]*256,coords[3]*256,coords[4]*256) end
  if c.chatRaceIcons then
   local atlas='raceicon128-'..data.race:lower()..'-'..(data.sex==3 and 'female' or 'male')
   if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)then prefix=prefix..'|A:'..atlas..':14:14|a 'end
  end
  return prefix..link -- Existing class-colored player hyperlink stays intact.
 end)
 if c.chatCopyLinks~=false then
  local parts={};local at=1
  while true do
   local first,last=s:find('|H.-|h.-|h',at)
   if not first then parts[#parts+1]=urls(s:sub(at));break end
   parts[#parts+1]=urls(s:sub(at,first-1));parts[#parts+1]=s:sub(first,last);at=last+1
  end
  s=table.concat(parts)
 end
 return s
end
function C.CopyHistory(frame)
 if not frame or not frame.GetNumMessages then return end
 local lines={};for i=math.max(1,frame:GetNumMessages()-299),frame:GetNumMessages()do
  local text=frame:GetMessageInfo(i)
  if safe(text) and type(text)=='string'then lines[#lines+1]=text:gsub('|H.-|h(.-)|h','%1'):gsub('|T.-|t',''):gsub('|A.-|a',''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')end
 end
 C.Copy(table.concat(lines,'\n'))
end
function C.Apply()
 if not settings then return end
 for i=1,(NUM_CHAT_WINDOWS or 10)do
  local frame=_G['ChatFrame'..i]
  if frame and frame.AddMessage and i~=2 then
   if not wrapped[frame]then
    local original=frame.AddMessage;local click=frame:GetScript('OnHyperlinkClick')
    frame.AddMessage=function(self,msg,...)return original(self,C.Format(msg),...)end
    frame:SetScript('OnHyperlinkClick',function(self,link,label,...)
     if C.Link(link)then return end
     if settings().chatCopyLinks~=false and IsControlKeyDown and IsControlKeyDown()and safe(label)and safe(link)and type(link)=='string'then C.Copy(type(label)=='string'and label or link);return end
     if click then return click(self,link,label,...)end
    end)
    wrapped[frame]={}
   end
   local state=wrapped[frame];local cfg=settings()
   if cfg.chatFontSize then
    local font,size,flags=frame:GetFont();state.font=state.font or {font,size,flags};frame:SetFont(font,cfg.chatFontSize,flags)
   elseif state.font then frame:SetFont(unpack(state.font));state.font=nil end
   if frame.SetFading then
    if cfg.chatNoFade then if state.fading==nil and frame.GetFading then state.fading=frame:GetFading()end;frame:SetFading(false)
    elseif state.fading~=nil then frame:SetFading(state.fading);state.fading=nil end
   end
   if frame.SetSpacing then
    if cfg.chatTight then if state.spacing==nil and frame.GetSpacing then state.spacing=frame:GetSpacing()end;frame:SetSpacing(0)
    elseif state.spacing~=nil then frame:SetSpacing(state.spacing);state.spacing=nil end
   end
   if state.copy then state.copy:Hide()end
  end
 end
end
function C.Initialize(get)
 settings=get
 if not C.filters and ChatFrame_AddMessageEventFilter then
  local filter=function(_,_,_,author,...)C.Remember(author,select(10,...));return false end
  for _,event in ipairs(events)do ChatFrame_AddMessageEventFilter('CHAT_MSG_'..event,filter)end
  C.filters=true
 end
 C.Apply()
end
function C.Options()
 if not options then
  options=CreateFrame('Frame','ForeverAssistChatOptions',UIParent,'BackdropTemplate');options:SetSize(490,520)
  local t=options:CreateFontString(nil,'OVERLAY','TrailboundTitle');t:SetPoint('TOPLEFT',20,-20);t:SetText('Chat appearance')
  local rows={{'chatClassIcons','Class icon before player names'},{'chatRaceIcons','Race icon before player names'},{'chatCompact','Short channel names (G, P, R, 1...)'},{'chatNoFade','Keep messages visible (no fading)'},{'chatTight','Compact line spacing'},{'chatCopyLinks','Clickable URLs and Ctrl-click link copying',true}}
  for i,r in ipairs(rows)do
   local c=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate');c:SetPoint('TOPLEFT',20,-55-i*38);local label=c:CreateFontString(nil,'OVERLAY','TrailboundText');label:SetPoint('LEFT',c,'RIGHT',3,0);label:SetText(r[2])
   c:SetScript('OnClick',function(self)settings()[r[1]]=self:GetChecked()and true or false;C.Apply()end)
   c:HookScript('OnShow',function(self)local v=settings()[r[1]];self:SetChecked(v==nil and r[3] or v)end)
  end
  local b=CreateFrame('Button',nil,options,'UIPanelButtonTemplate');b:SetSize(290,26);b:SetPoint('TOPLEFT',20,-345)
  local function caption()b:SetText('Chat font size: '..tostring(settings().chatFontSize or 'Default'))end
  b:SetScript('OnClick',function()local n=settings().chatFontSize or 12;if n>=20 then settings().chatFontSize=nil else settings().chatFontSize=n+1 end;C.Apply();caption()end);b:HookScript('OnShow',caption);ForeverAssistStyleButton(b)
  local help=options:CreateFontString(nil,'OVERLAY','TrailboundText');help:SetPoint('TOPLEFT',20,-395);help:SetWidth(440);help:SetJustifyH('LEFT');help:SetText('Existing class name colors are preserved. Icons need known sender data; unknown or restricted identities remain unchanged.\n\nClick a URL, or Ctrl-click an item/player link, then Ctrl+C. Use /copychat to copy recent chat history. Normal clicks retain their usual behavior.');options:Hide()
 end
 ForeverAssistShowEditor(options)
end
local frame=CreateFrame('Frame');frame:RegisterEvent('PLAYER_ENTERING_WORLD');frame:RegisterEvent('UPDATE_CHAT_WINDOWS');frame:SetScript('OnEvent',C.Apply)
SLASH_FOREVERASSISTCOPYCHAT1='/copychat';SlashCmdList.FOREVERASSISTCOPYCHAT=function()C.CopyHistory(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)end
