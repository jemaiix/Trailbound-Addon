-- Live minimap-tooltip observations only; never enumerate hidden world objects.
ForeverAssistGathering={Version='1.8.46'}
local G=ForeverAssistGathering
local settings,character,options
local icons,glows={},{}
local grid,index,hits,geometry={},1,{},nil
local probeTooltip
local pinned={}
G.diagnostics={scans=0,probes=0,matched=0,shown=0}
-- Item IDs and baseline gathering requirements, not spawn locations.
local rows={
 {'Peacebloom',2447,182,1},{'Silverleaf',765,182,1},{'Earthroot',2449,182,15},
 {'Mageroyal',785,182,50},{'Briarthorn',2450,182,70},{'Stranglekelp',3820,182,85},
 {'Bruiseweed',2453,182,100},{'Wild Steelbloom',3355,182,115},{'Grave Moss',3369,182,120},
 {'Kingsblood',3356,182,125},{'Liferoot',3357,182,150},{'Fadeleaf',3818,182,160},
 {'Goldthorn',3821,182,170},{"Khadgar's Whisker",3358,182,185},{'Wintersbite',3819,182,195},
 {'Firebloom',4625,182,205},{'Purple Lotus',8831,182,210},{"Arthas' Tears",8836,182,220},
 {'Sungrass',8838,182,230},{'Blindweed',8839,182,235},{'Ghost Mushroom',8845,182,245},
 {'Gromsblood',8846,182,250},{'Golden Sansam',13464,182,260},{'Dreamfoil',13463,182,270},
 {'Mountain Silversage',13465,182,280},{'Plaguebloom',13466,182,285},{'Icecap',13467,182,290},
 {'Black Lotus',13468,182,300},
 {'Copper Vein',2770,186,1},{'Tin Vein',2771,186,65},{'Silver Vein',2775,186,75},
 {'Iron Deposit',2772,186,125},{'Gold Vein',2776,186,155},{'Mithril Deposit',3858,186,175},
 {'Truesilver Deposit',7911,186,230},{'Small Thorium Vein',10620,186,245},
 {'Rich Thorium Vein',10620,186,275},{'Dark Iron Deposit',11370,186,230},
}
local aliases={}
for _,row in ipairs(rows)do aliases[row[1]]=row end
local function safe(v)return not issecretvalue or not issecretvalue(v)end
local function publicTable(v)return safe(v)and type(v)=='table'and not (issecrettable and issecrettable(v))end
local function combat()return InCombatLockdown and InCombatLockdown()end
local function number(v)return safe(v)and type(v)=='number'end
local function call(fn,...)
 if type(fn)~='function'then return end
 local ok,a,b=pcall(fn,...);if ok then return a,b end
end
-- Public player/map geometry only. Pins are session observations, never spawn data.
function G.View()
 if combat()or not Minimap or not C_Map or not C_Minimap then return end
 local map=call(C_Map.GetBestMapForUnit,'player');if not number(map)then return end
 local pos=call(C_Map.GetPlayerMapPosition,map,'player');if not safe(pos)or not pos or (issecrettable and issecrettable(pos))or not pos.GetXY then return end
 local x,y=call(pos.GetXY,pos);local w,h=call(C_Map.GetMapWorldSize,map)
 local radius=call(C_Minimap.GetViewRadius)
 if not (number(x)and number(y)and number(w)and number(h)and number(radius))or w<=0 or h<=0 or radius<=0 then return end
 local facing=0;local get=C_CVar and C_CVar.GetCVar or GetCVar
 local rotate=call(get,'rotateMinimap');local ignored=call(C_Minimap.IsRotateMinimapIgnored)
 if safe(rotate)and (rotate=='1'or rotate==1)and safe(ignored)and not ignored then
  facing=call(GetPlayerFacing);if not number(facing)then return end
 end
 return {map=map,x=x*w,y=y*h,radius=radius,width=Minimap:GetWidth(),height=Minimap:GetHeight(),c=math.cos(facing),s=math.sin(facing)}
end
function G.World(x,y,v)
 local east=(x-v.width/2)*2*v.radius/v.width;local north=(y-v.height/2)*2*v.radius/v.height
 return v.x+east*v.c-north*v.s,v.y-east*v.s-north*v.c
end
function G.Screen(x,y,v)
 local east,north=x-v.x,v.y-y
 return v.width/2+(east*v.c+north*v.s)*v.width/(2*v.radius),v.height/2+(-east*v.s+north*v.c)*v.height/(2*v.radius)
end
function G.Follow(view)
 if combat()then return end
 view=view or G.View()
 for _,icon in ipairs(icons)do
  local pin=icon.pin
  if pin then
   if not view or pin.map~=view.map then icon:Hide()
   else
    local x,y=G.Screen(pin.x,pin.y,view)
    local inside=x>=7 and y>=7 and x<=view.width-7 and y<=view.height-7
    if settings and not settings().squareMinimap then inside=inside and (x-view.width/2)^2+(y-view.height/2)^2<=(math.min(view.width,view.height)/2-7)^2 end
    icon:ClearAllPoints();icon:SetPoint('CENTER',Minimap,'BOTTOMLEFT',x,y);icon:SetShown(inside and settings().gatherNodeIcons~=false)
   end
  end
 end
end
function G.Resolve(name)
 if not safe(name)or type(name)~='string'then return end
 name=name:gsub('|T.-|t',''):gsub('|A.-|a',''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):match('^%s*(.-)%s*$');return aliases[name]
end
function G.Skills()
 local result={}
 if GetProfessions and GetProfessionInfo then
  result[182],result[186]=0,0
  for _,i in pairs({GetProfessions()})do
   local ok,_,_,rank,_,_,_,id=pcall(GetProfessionInfo,i)
   if ok and safe(id)and safe(rank)and (id==182 or id==186)and type(rank)=='number'then result[id]=rank end
  end
 end
 return result
end
function G.TooLow(row,skills)return row and type(skills[row[3]])=='number'and skills[row[3]]<row[4]end
local function hideIcons()for _,icon in ipairs(icons)do icon:Hide();icon.pin=nil end;pinned={}end
local function hideGlows()for _,glow in pairs(glows)do glow:Hide()end end
-- Tracker menus vary between client builds. Probe actual dots even when the
-- menu reports no entries; tooltip identification is the authoritative filter.
local function tooltipData()
 if C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover then
  local ok,data=pcall(C_TooltipInfo.GetMinimapMouseover)
  G.diagnostics.reader='TooltipInfo'
  -- Empty is a valid probe result. A display tooltip can contain quest-addon
  -- additions, so never use it to replace an empty structured result.
  if ok and publicTable(data)and publicTable(data.lines)then return data end
  return
 end
 if not probeTooltip then
  probeTooltip=CreateFrame('GameTooltip','ForeverAssistNodeProbeTooltip',UIParent,'GameTooltipTemplate')
 end
 if not probeTooltip.SetMinimapMouseover then probeTooltip:Hide();G.diagnostics.reader='unavailable';return end
 probeTooltip:SetOwner(UIParent,'ANCHOR_NONE');probeTooltip:ClearLines()
 local ok=pcall(probeTooltip.SetMinimapMouseover,probeTooltip)
 local lines={}
 if ok then
  for i=1,probeTooltip:NumLines()do
   local label=_G['ForeverAssistNodeProbeTooltipTextLeft'..i]
   if label then lines[#lines+1]={leftText=label:GetText()}end
  end
 end
 probeTooltip:Hide();G.diagnostics.reader='GameTooltip';return {lines=lines}
end
function G.Record(data,x,y,view)
 if not publicTable(data)or not publicTable(data.lines)then return end
 for _,line in ipairs(data.lines)do
  if publicTable(line)then
   local text=line.leftText
   if safe(text)and type(text)=='string'then
   G.diagnostics.lastText=text:sub(1,180)
   for name in text:gmatch('[^\r\n]+')do
   local row=G.Resolve(name)
   if row then
    G.diagnostics.lastNode=row[1]
    G.diagnostics.matched=G.diagnostics.matched+1
    local duplicate=false
    for _,hit in ipairs(hits)do if hit.row==row and hit.x==x and hit.y==y then duplicate=true;break end end
    if not duplicate then
     local hit={row=row,x=x,y=y}
     if view then hit.map=view.map;hit.wx,hit.wy=G.World(x,y,view)end
     hits[#hits+1]=hit
    end
   end
   end
   end
  end
 end
end
-- Connected probe patches represent dots. Grouping against a moving average
-- splits the two edges of a single dot; adjacency is independent of scan order.
function G.Cluster(points)
 local result,visited={},{}
 for i,first in ipairs(points)do
  if not visited[i]then
   local queue={i};visited[i]=true;local head=1
   local left,right,bottom,top=first.x,first.x,first.y,first.y
   while head<=#queue do
    local p=points[queue[head]];head=head+1
    left=math.min(left,p.x);right=math.max(right,p.x);bottom=math.min(bottom,p.y);top=math.max(top,p.y)
    for j,q in ipairs(points)do
     if not visited[j]and q.row==first.row and (q.x-p.x)^2+(q.y-p.y)^2<=128 then visited[j]=true;queue[#queue+1]=j end
    end
   end
   result[#result+1]={row=first.row,x=(left+right)/2,y=(bottom+top)/2,count=#queue}
  end
 end
 return result
end
function G.Render()
 local view=G.View();local points={}
 for _,hit in ipairs(hits)do
  if hit.map and view and hit.map==view.map then
   local x,y=G.Screen(hit.wx,hit.wy,view);points[#points+1]={row=hit.row,x=x,y=y}
  elseif not hit.map then points[#points+1]=hit end
 end
 local nodes=G.Cluster(points);local nextPins,used={},{}
 G.diagnostics.scans=G.diagnostics.scans+1;G.diagnostics.shown=#nodes
 G.status=#nodes>0 and 'Node icons active'or 'No recognized nodes in last scan'
 local skills=G.Skills()
 for i,hit in ipairs(nodes)do
  local icon=icons[i]
  if not icon then
   icon=CreateFrame('Frame',nil,Minimap,'BackdropTemplate');icon:SetSize(14,14);icon:EnableMouse(false);icon:SetFrameLevel(Minimap:GetFrameLevel()+8)
   icon.background=icon:CreateTexture(nil,'BACKGROUND');icon.background:SetAllPoints(icon);icon.background:SetTexture('Interface/AddOns/Trailbound/Media/NodeCircle');icon.background:SetVertexColor(.025,.025,.025)
   icon.texture=icon:CreateTexture(nil,'ARTWORK');icon.texture:SetPoint('TOPLEFT',1,-1);icon.texture:SetPoint('BOTTOMRIGHT',-1,1);icon.texture:SetTexCoord(.04,.96,.04,.96)
   if icon.texture.SetSnapToPixelGrid then icon.texture:SetSnapToPixelGrid(false);icon.texture:SetTexelSnappingBias(0)end
   if icon.CreateMaskTexture and icon.texture.AddMaskTexture then
    icon.mask=icon:CreateMaskTexture();icon.mask:SetAllPoints(icon.texture);icon.mask:SetTexture('Interface/AddOns/Trailbound/Media/NodeCircle');icon.texture:AddMaskTexture(icon.mask)
   end
   icon.ring=icon:CreateTexture(nil,'OVERLAY');icon.ring:SetAllPoints(icon);icon.ring:SetTexture('Interface/AddOns/Trailbound/Media/NodeRing')
   icons[i]=icon
  end
  local row=hit.row;local texture=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(row[2])or 134400
  icon.pin=nil
  if view then
   local wx,wy=G.World(hit.x,hit.y,view);local chosen,best
   local reach=(12*2*view.radius/view.width)^2
   for j,pin in ipairs(pinned)do
    if not used[j]and pin.map==view.map and pin.row==row then
     local distance=(pin.x-wx)^2+(pin.y-wy)^2
     if distance<=reach and (not best or distance<best)then chosen,best=j,distance end
    end
   end
   local pin=chosen and pinned[chosen]or {map=view.map,x=wx,y=wy,row=row}
   if chosen then used[chosen]=true end
   nextPins[#nextPins+1]=pin;icon.pin=pin
  end
  icon.texture:SetTexture(texture or 134400)
  local low=G.TooLow(row,skills);icon.texture:SetVertexColor(1,low and .2 or 1,low and .2 or 1);icon.ring:SetVertexColor(1,low and .1 or .8,low and .1 or .2,1)
  icon:ClearAllPoints();icon:SetPoint('CENTER',Minimap,'BOTTOMLEFT',hit.x,hit.y);icon:Show()
 end
 for i=#nodes+1,#icons do icons[i]:Hide()end
 for i=#nodes+1,#icons do icons[i].pin=nil end
 pinned=nextPins;G.Follow(view)
end
function G.Scan()
 if not settings then G.status='Not initialized';return end
 if combat()then G.status='Paused in combat';hideIcons();return end
 if settings().gatherNodeIcons==false then G.status='Node icons disabled in options';hideIcons();return end
 if not Minimap or not Minimap:IsShown()then G.status='Minimap hidden';hideIcons();return end
 if not Minimap.UpdateMouseoverAtPoint then G.status='Minimap probing API unavailable';hideIcons();return end
 if MouseIsOver and MouseIsOver(Minimap)then G.status='Paused while mouse is over minimap';index=1;hits={};return end
 local width,height=Minimap:GetWidth(),Minimap:GetHeight();local scale=Minimap:GetEffectiveScale();local left,bottom=Minimap:GetLeft(),Minimap:GetBottom()
 if not left or not bottom or width<=0 or height<=0 then return end
 local key=width..':'..height..':'..tostring(settings().squareMinimap)
 if key~=geometry then
  grid={};index=1;hits={};geometry=key
  for y=4,height-4,8 do for x=4,width-4,8 do
   if settings().squareMinimap or (x-width/2)^2+(y-height/2)^2<=(math.min(width,height)/2-2)^2 then grid[#grid+1]={x,y}end
  end end
 end
 local soft=Minimap.SetUsingSoftCursor
 if not soft then G.status='Minimap soft cursor API unavailable';hideIcons();return end
 local enabled=pcall(soft,Minimap,true)
 if not enabled then pcall(soft,Minimap,false);G.status='Minimap soft cursor rejected by client';hideIcons();return end
 local batch,failed={},false;local view=G.View()
 for _=1,48 do
  local point=grid[index];if not point then break end
  local ok,data=pcall(function()
   Minimap:UpdateMouseoverAtPoint((left+point[1])*scale,(bottom+point[2])*scale)
   return tooltipData()
  end)
  if not ok then failed=true;break end
  G.diagnostics.probes=G.diagnostics.probes+1
  batch[#batch+1]={data=data,x=point[1],y=point[2]}
  index=index+1
 end
 -- Release before processing data or rendering, including failed native calls.
 pcall(soft,Minimap,false)
 if GetCursorPosition then local x,y=GetCursorPosition();pcall(Minimap.UpdateMouseoverAtPoint,Minimap,x,y)end
 if failed then G.status='Minimap probing rejected by client';index=1;hits={};hideIcons();return end
 for _,sample in ipairs(batch)do G.Record(sample.data,sample.x,sample.y,view)end
 if not grid[index]then G.Render();index=1;hits={}end
end
function G.Debug()
 local d=G.diagnostics
 print('|cffd2b077Trailbound nodes:|r '..G.Version..' / '..(G.status or 'Starting')..' / reader='..(d.reader or 'none')..' / scans='..d.scans..' probes='..d.probes..' matches='..d.matched..' icons='..d.shown)
 local text=d.lastText
 if text then print('Last minimap text: '..text:gsub('|','||'):gsub('[\r\n]',' / '))end
 if d.lastNode then print('Last recognized node: '..d.lastNode)end
end
local wanted={softTargetInteract='3',SoftTargetIconGameObject='1',SoftTargetInteractArc='2',SoftTargetInteractRange='30'}
local function same(a,b)return safe(a)and safe(b)and (a==b or tonumber(a)and tonumber(a)==tonumber(b))end
function G.ApplySettings()
 if not settings or not character or combat()then return end
 local get=C_CVar and C_CVar.GetCVar or GetCVar;local set=C_CVar and C_CVar.SetCVar or SetCVar
 character.gatherInteractRestore=character.gatherInteractRestore or {}
 if get and set then
  for name,value in pairs(wanted)do
   local ok,current=pcall(get,name);local saved=character.gatherInteractRestore[name]
   if ok and safe(current)and current~=nil then
    if settings().gatherSparkles~=false then
     if not saved or same(current,saved.applied)then
      if not same(current,value)then
       local changed=pcall(set,name,value);local read,accepted=pcall(get,name)
       if changed and read and same(accepted,value)then character.gatherInteractRestore[name]={before=saved and saved.before or current,applied=value}end
      end
     end
    elseif saved then
     if same(current,saved.applied)then pcall(set,name,saved.before)end;character.gatherInteractRestore[name]=nil
    end
   end
  end
 end
 if settings().gatherSparkles==false then hideGlows()end
 if settings().gatherNodeIcons==false then hideIcons()end
end
function G.Sparkles()
 if not settings or combat()or settings().gatherSparkles==false or not C_NamePlate or not C_NamePlate.GetNamePlates or not UnitIsGameObject then hideGlows();return end
 local seen={}
 local plates=C_NamePlate.GetNamePlates();if not publicTable(plates)then hideGlows();return end
 for _,plate in ipairs(plates)do
  if not (plate.IsForbidden and plate:IsForbidden())then
   local unit=plate.namePlateUnitToken or plate.UnitFrame and plate.UnitFrame.unit
   if safe(unit)and type(unit)=='string'then
    local ok,object=pcall(UnitIsGameObject,unit);local got,name=pcall(UnitName,unit)
    if ok and safe(object)and object and got and G.Resolve(name)then
     local glow=glows[plate]
     if not glow then
      glow=CreateFrame('Frame');glow:SetParent(plate);glow:SetSize(130,120);glow:SetPoint('CENTER',plate,'BOTTOM',0,-85);glow:EnableMouse(false);glow.parts={}
      for i=1,20 do local t=glow:CreateTexture(nil,'OVERLAY');t:SetTexture('Interface/CastingBar/UI-CastingBar-Spark');t:SetSize(12+i%3*3,20+i%4*3);t:SetVertexColor(1,.9,.45);if t.SetBlendMode then t:SetBlendMode('ADD')end;glow.parts[i]=t end
      glow:SetScript('OnUpdate',function(self)
       if combat()then self:Hide();return end
       local now=GetTime()
       for i,t in ipairs(self.parts)do local phase=now*.7+i*2.39996;t:ClearAllPoints();t:SetPoint('CENTER',self,'CENTER',math.sin(phase)*54,math.cos(phase*1.37)*48);t:SetAlpha(.3+.7*(1+math.sin(phase*2.8))/2)end
      end);glows[plate]=glow
     end
     seen[plate]=true;glow:Show()
    end
   end
  end
 end
 for plate,glow in pairs(glows)do if not seen[plate]then glow:Hide()end end
end
function G.Initialize(db,get)
 character,settings=db,get
 for _,row in ipairs(rows)do
  if row[3]==182 and C_Item and C_Item.GetItemNameByID then local name=C_Item.GetItemNameByID(row[2]);if safe(name)and type(name)=='string'then aliases[name]=row end end
 end
 G.ApplySettings()
end
function G.Options()
 if not options then
  options=CreateFrame('Frame','ForeverAssistGatherOptions',UIParent,'BackdropTemplate');options:SetSize(490,450)
  local title=options:CreateFontString(nil,'OVERLAY','TrailboundTitle');title:SetPoint('TOPLEFT',20,-20);title:SetText('Herbs and mining nodes')
  for i,entry in ipairs({{'gatherNodeIcons','Item icons on visible minimap nodes'},{'gatherSparkles','Sparkles on nearby herb / ore objects'}})do
   local c=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate');c:SetPoint('TOPLEFT',20,-60-i*42)
   local label=c:CreateFontString(nil,'OVERLAY','TrailboundText');label:SetPoint('LEFT',c,'RIGHT',3,0);label:SetText(entry[2])
   c:SetScript('OnClick',function(self)settings()[entry[1]]=self:GetChecked()and true or false;G.ApplySettings()end);c:HookScript('OnShow',function(self)self:SetChecked(settings()[entry[1]]~=false)end)
  end
  local help=options:CreateFontString(nil,'OVERLAY','TrailboundText');help:SetPoint('TOPLEFT',20,-185);help:SetWidth(440);help:SetJustifyH('LEFT');help:SetText('Keep Find Herbs or Find Minerals active. Red means your profession rank is below a known node requirement.\n\nSparkles enable Interact Key and object icons, with an all-around detection arc up to 30 yards. This does not auto-gather or increase gathering reach. Disabling sparkles restores settings the addon changed, unless you changed them yourself.\n\nScanning pauses in combat and while hovering the minimap. Unrecognized/restricted nodes stay unchanged. New beta nodes, changed skill requirements and other languages need live verification.');options:Hide()
 end
 ForeverAssistShowEditor(options)
end
local frame=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','PLAYER_ENTERING_WORLD','SKILL_LINES_CHANGED','NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','PLAYER_SOFT_INTERACT_CHANGED'})do pcall(frame.RegisterEvent,frame,event)end
frame:SetScript('OnEvent',function(_,event)
 if event=='PLAYER_REGEN_DISABLED'then hideIcons();hideGlows();index=1;hits={}else G.ApplySettings();G.Sparkles()end
end)
local scanElapsed,glowElapsed=0,0
frame:SetScript('OnUpdate',function(_,dt)
 if not settings then return end
 scanElapsed=scanElapsed+dt;glowElapsed=glowElapsed+dt
 if not combat()and settings().gatherNodeIcons~=false then G.Follow()end
 if scanElapsed>=.02 then scanElapsed=0;G.Scan()end
 if glowElapsed>=.2 then glowElapsed=0;G.Sparkles()end
end)
