-- Follow the operating system's default playback endpoint through WoW's
-- device-change event. No polling, microphone changes, or native UI hooks.
ForeverAssistAudio={Version='1.8.46'}
local A=ForeverAssistAudio
local getSettings,pendingAt,lastRestart,applying,active
local frame=CreateFrame('Frame')
local function now() return GetTime() end
local function readDriver()
 local get=C_CVar and C_CVar.GetCVar or GetCVar
 if not get then return end
 local ok,value=pcall(get,'Sound_OutputDriverIndex')
 if ok and not (issecretvalue and issecretvalue(value)) then return tonumber(value) end
end
local function stop()
 pendingAt=nil;frame:SetScript('OnUpdate',nil)
end
local function tick()
 if not pendingAt or now()<pendingAt then return end
 stop()
 if not getSettings or not getSettings().audioFollowSystem or readDriver()~=0 then return end
 if not Sound_GameSystem_RestartSoundSystem then A.status='Sound restart is unavailable on this client.';return end
 -- Some clients emit another device event while restarting their sound engine.
 applying=true;lastRestart=now()
 local ok=pcall(Sound_GameSystem_RestartSoundSystem)
 applying=false
 A.status=ok and 'Sound refreshed on System Default.' or 'This client could not restart its sound system.'
end
local function request()
 if applying or not getSettings or not getSettings().audioFollowSystem then return end
 if lastRestart and now()-lastRestart<5 then return end
 if readDriver()~=0 then return end
 pendingAt=now()+.75;frame:SetScript('OnUpdate',tick)
end
function A.ApplySettings()
 if not getSettings then return end
 if not getSettings().audioFollowSystem then active=false;stop();A.status='Automatic audio switching is off.';return end
 if not Sound_GameSystem_RestartSoundSystem then A.status='Sound restart is unavailable on this client.';return end
 local driver=readDriver()
 if driver==nil then A.status='The audio output setting is unavailable.';return end
 if driver~=0 then
  local set=C_CVar and C_CVar.SetCVar or SetCVar
  if not set then A.status='The audio output setting cannot be changed.';return end
  applying=true;local ok=pcall(set,'Sound_OutputDriverIndex',0);applying=false
  if not ok or readDriver()~=0 then A.status='Select System Default in Blizzard Audio options.';return end
  request()
 end
 if not active then request() end
 active=true
 A.status=A.deviceEventAvailable and 'Following System Default.' or 'Device events unavailable; use Refresh audio.'
end
function A.Refresh()
 if not getSettings or not getSettings().audioFollowSystem then
  print('|cffd2b077Trailbound:|r Enable Follow Windows audio output first.');return
 end
 A.ApplySettings();request()
end
function A.Initialize(settings)
 getSettings=settings
 if getSettings().audioFollowSystem==nil then getSettings().audioFollowSystem=true end
 local ok=pcall(frame.RegisterEvent,frame,'VOICE_CHAT_OUTPUT_DEVICES_UPDATED')
 A.deviceEventAvailable=ok
 frame:SetScript('OnEvent',function()request()end)
end
function A.Debug()
 print('|cffd2b077Trailbound:|r Audio '..A.Version..' | follow '..tostring(getSettings and getSettings().audioFollowSystem)..' | output index '..tostring(readDriver())..' | device event '..tostring(A.deviceEventAvailable)..' | '..tostring(A.status or 'Waiting for login.'))
end
