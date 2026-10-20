ForeverAssistFlight={Version='1.8.46'}
local F=ForeverAssistFlight
local account,character,settings,root,nodes,pending,flight
local function readable(v)return not issecretvalue or not issecretvalue(v)end
local function clock(n)n=math.max(0,math.ceil(n));return ('%d:%02d'):format(math.floor(n/60),n%60)end
function F.CaptureNodes()
 nodes={};local origin
 if not NumTaxiNodes or not TaxiNodeName or not TaxiNodePosition or not TaxiNodeGetType then return end
 for i=1,NumTaxiNodes()do
  local name=TaxiNodeName(i);local x,y=TaxiNodePosition(i)
  if readable(name) and readable(x) and readable(y) and name then
   nodes[i]={name=name,point=('%s:%.4f:%.4f'):format(name,x or 0,y or 0)}
   if TaxiNodeGetType(i)=='CURRENT' then origin=nodes[i].point end
  end
 end
 nodes.origin=origin;nodes.map=GetTaxiMapID and GetTaxiMapID() or 0
end
function F.Select(index)
 if not account or not nodes or not nodes.origin or not nodes[index] then return end
 local faction=UnitFactionGroup and UnitFactionGroup('player') or ''
 pending={key=table.concat({GetRealmName(),faction,tostring(nodes.map),nodes.origin,nodes[index].point},'|'),destination=nodes[index].name,at=GetTime()}
end
function F.Update()
 if not settings or not F.ready then return end
 local flying=UnitOnTaxi and UnitOnTaxi('player');if not readable(flying) then return end
 if flying and not flight then
  if pending then
   flight={key=pending.key,destination=pending.destination,start=GetTime(),startedAt=time()};pending=nil;character.flightSession=flight
  elseif character.flightSession then
   flight=character.flightSession;flight.start=GetTime()-math.max(0,time()-flight.startedAt)
  else flight={destination='Flight path',start=GetTime(),untracked=true} end
 end
 if pending and GetTime()-pending.at>30 then pending=nil end
 if flight and not flying then
  local seconds=GetTime()-flight.start
  if not flight.interrupted and not flight.untracked and seconds>=5 and seconds<7200 then account.flightTimes[flight.key]={seconds=seconds,updatedAt=time()} end
  flight=nil;character.flightSession=nil
 end
 if not flying and not flight then character.flightSession=nil end
 if not root then
  root=CreateFrame('Frame','ForeverAssistFlightTimer',UIParent);root:SetSize(420,45);root:SetFrameStrata('HIGH')
  root.label=root:CreateFontString(nil,'OVERLAY','TrailboundText');root.label:SetAllPoints();root.label:SetFont(STANDARD_TEXT_FONT,16,'OUTLINE')
 end
 local p=settings().flightPosition;root:ClearAllPoints();root:SetPoint('CENTER',UIParent,'CENTER',p and p[1] or 0,p and p[2] or 300)
 root:SetShown(flight~=nil and settings().flightTimer~=false and not (ForeverAssistLayout and ForeverAssistLayout.active))
 if flight then
  local elapsed=GetTime()-flight.start;local saved=flight.key and account.flightTimes[flight.key]
  local remaining=saved and saved.seconds-elapsed
  local detail=remaining and remaining>0 and ('~'..clock(remaining)..' remaining / '..clock(saved.seconds)..' total') or saved and 'Arriving soon — '..clock(elapsed)..' elapsed' or clock(elapsed)..' elapsed — learning this route'
  root.label:SetText(flight.destination..'\n'..detail)
 end
end
function F.Initialize(a,c,get)
 account,character,settings=a,c,get;account.flightTimes=account.flightTimes or {}
 if not F.hooked and hooksecurefunc then
  if TakeTaxiNode then hooksecurefunc('TakeTaxiNode',F.Select) end
  if TaxiRequestEarlyLanding then hooksecurefunc('TaxiRequestEarlyLanding',function()if flight then flight.interrupted=true end end) end
  F.hooked=true
 end
 F.Update()
end
local events=CreateFrame('Frame');for _,e in ipairs({'TAXIMAP_OPENED','PLAYER_ENTERING_WORLD','PLAYER_CONTROL_LOST','PLAYER_CONTROL_GAINED','PLAYER_LOGOUT'})do events:RegisterEvent(e)end
events:SetScript('OnEvent',function(_,event)
 if event=='TAXIMAP_OPENED' then F.CaptureNodes() elseif event=='PLAYER_LOGOUT' then F.ready=false;return else if event=='PLAYER_ENTERING_WORLD'then F.ready=true end;F.Update()end
end)
local elapsed=0;events:SetScript('OnUpdate',function(_,dt)if not settings or not (pending or flight)then return end;elapsed=elapsed+dt;if elapsed>=.2 then elapsed=0;F.Update()end end)
