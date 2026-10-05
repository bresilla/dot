local morf=require("morf")
local backend=require("lib.util.equalizer")
local presentation=require("presentation")
local M={frequencies=backend.frequencies}
local zeros={0,0,0,0,0,0,0,0}
local cfg=require("lib.util.settings").open {name="caelestia.equalizer",path=morf.state_path("caelestia-equalizer.json"),
  write_when=function() return not morf.primary or morf.primary() end,
  defaults={enabled=false,mode="auto",compensation=false,
    profile={label="My audiogram",left=zeros,right=zeros},
    headphones={strength=30,per_ear=true,bands=zeros,trim=0},
    speakers={strength=30,per_ear=false,bands=zeros,trim=0}}}
local auto=morf.signal("caelestia.equalizer.auto","speakers")
M.status=morf.signal("caelestia.equalizer.status","off")
M.error=morf.signal("caelestia.equalizer.error","")
M.curve=morf.signal("caelestia.equalizer.curve",nil)
M.editor_error=morf.signal("caelestia.equalizer.editor_error","")
M.draft=morf.signal("caelestia.equalizer.draft",{label="My audiogram",left=zeros,right=zeros})
function M.get(key) return cfg.get(key) end
function M.preset()
  local mode=cfg.get("mode")
  return mode=="headphones" and "headphones" or mode=="speakers" and "speakers" or auto:get()
end
function M.current(key) return cfg.get(M.preset().."."..key) end
local function dry()
  local value=morf.env("CAELESTIA_DRY_RUN")
  return value~=nil and value~="" and value~="0"
end
local function primary() return not morf.primary or morf.primary() end
local function number(v,lo,hi) return type(v)=="number" and v==v and v>=lo and v<=hi end
local function valid_list(values,lo,hi)
  if type(values)~="table" or #values~=8 then return false end
  for i=1,8 do if not number(values[i],lo,hi) then return false end end
  return true
end
local function accepts(key,value)
  if key=="mode" then return value=="auto" or value=="headphones" or value=="speakers" end
  if key=="enabled" or key=="compensation" or key:match("^%a+%.per_ear$") then return type(value)=="boolean" end
  if key=="profile.label" then return type(value)=="string" and #value>0 and #value<=80 end
  if key=="profile.left" or key=="profile.right" then return valid_list(value,-10,120) end
  if key:match("^%a+%.bands$") then return valid_list(value,-12,12) end
  if key:match("^%a+%.strength$") then return number(value,0,100) end
  if key:match("^%a+%.trim$") then return number(value,-24,0) end
  return false
end
function M.set(key,value)
  if not cfg.accepts(key,value) or not accepts(key,value) then return false end
  cfg.set(key,value)
  -- Send edits to the single DSP owner immediately; the watched settings
  -- file also restores them after reload and synchronizes other outputs.
  if not primary() and morf.broadcast then morf.broadcast("equalizer-setting",key,morf.json.encode(value)) end
  return true
end
function M.set_current(key,value) return M.set(M.preset().."."..key,value) end
function M.set_band(i,value)
  if i<1 or i>8 or not number(value,-12,12) then return false end
  local bands=M.current("bands") local copy={table.unpack(bands)} copy[i]=value
  return M.set_current("bands",copy)
end
function M.reset_bands() M.set_current("bands",zeros) M.set_current("trim",0) end
function M.open_editor() require("utilities").request("sound/equalizer/audiogram") end
function M.edit(ear,i,value)
  local draft=M.draft:get()
  local next={label=draft.label,left={table.unpack(draft.left)},right={table.unpack(draft.right)}}
  if ear=="label" then next.label=value else next[ear][i]=value end
  M.draft:set(next) M.editor_error:set("")
end
function M.save_profile()
  local draft=M.draft:get() local left,right={},{}
  for i=1,8 do left[i]=tonumber(draft.left[i]) right[i]=tonumber(draft.right[i]) end
  if not accepts("profile.label",draft.label) or not valid_list(left,-10,120) or not valid_list(right,-10,120) then
    M.editor_error:set("Enter a name and eight values per ear between −10 and 120 dB HL.") return false
  end
  M.set("profile.label",draft.label) M.set("profile.left",left) M.set("profile.right",right)
  cfg.flush() require("utilities").back() return true
end
morf.ipc["equalizer-setting"]=function(key,payload)
  if not primary() then return end
  local ok,value=pcall(morf.json.decode,payload or "")
  if ok then M.set(key,value) end
end
morf.ipc["equalizer-status"]=function(payload)
  if primary() then return end
  local ok,state=pcall(morf.json.decode,payload or "")
  if ok and type(state)=="table" then
    M.status:set(state.status or "off") M.error:set(state.error or "")
    if state.auto=="headphones" or state.auto=="speakers" then auto:set(state.auto) end
  end
end
local function publish()
  if morf.broadcast then morf.broadcast("equalizer-status",morf.json.encode {
    status=M.status:get(),error=M.error:get(),auto=auto:get()}) end
end
morf.ipc["equalizer-status-request"]=function() if primary() then publish() end end
local service=backend.new {name="caelestia.equalizer.backend"}
local mode_query,mode_timer,mode_token=nil,nil,0
-- Never in a dry run (the shell reaches no audio stack then) and never
-- without a default sink to classify.
local function classify()
  if mode_timer then mode_timer:cancel() mode_timer=nil end
  if dry() or not morf.audio.default_sink() then return end
  mode_timer=morf.timer(400,function()
    mode_timer=nil
    if dry() or not primary() or not cfg.get("enabled") then return end
    mode_token=mode_token+1 local token=mode_token
    if mode_query then mode_query:kill() end
    local sink=morf.audio.default_sink() if not sink then return end
    mode_query=morf.run({"pactl","--format=json","list","sinks"},{timeout_ms=2000,max_output=1024*1024},function(result)
      if token~=mode_token then return end mode_query=nil
      local ok,rows=pcall(morf.json.decode,result.stdout or "")
      if result.ok and not result.truncated and ok and type(rows)=="table" then
        for _,row in ipairs(rows) do if row.name==sink.name then auto:set(backend.classify(row)) return end end
      end
      auto:set(backend.classify(sink))
    end)
  end,false)
end
if morf.audio.on_changed then
  morf.audio.on_changed(function(what)
    if primary() and cfg.get("enabled") and (what.defaults or what.devices or what.available) then classify() end
  end)
end
morf.effect("caelestia.equalizer.prescription",function()
  local mode=M.preset()
  local opts={enabled=cfg.get("enabled"),compensation=cfg.get("compensation"),left=cfg.get("profile.left"),
    right=cfg.get("profile.right"),bands=cfg.get(mode..".bands"),strength=cfg.get(mode..".strength"),
    trim=cfg.get(mode..".trim"),per_ear=cfg.get(mode..".per_ear")}
  local ok,curve=pcall(function() return morf.audio.equalizer_curve(opts) end)
  if ok then M.curve:set(curve)
  else M.curve:set(nil) M.error:set("Equalizer unavailable: update Morf or check saved profile values.") end
end)
morf.effect("caelestia.equalizer.lifecycle",function()
  local owns=primary() local enabled=cfg.get("enabled") local curve=M.curve:get()
  if owns and enabled and curve and not dry() then service.start(curve)
  else service.stop() end
end)
morf.effect("caelestia.equalizer.feedback",function()
  if not primary() then return end
  M.status:set(dry() and cfg.get("enabled") and "preview" or service.status:get())
  if M.curve:get() then M.error:set(service.error:get()) end
  publish()
end)
if not primary() and morf.broadcast then
  morf.timer(1,function() morf.broadcast("equalizer-status-request") end,false)
end
morf.effect("caelestia.equalizer.detect",function()
  local owns=primary() local enabled=cfg.get("enabled")
  if owns and enabled and not dry() then classify()
  else
    mode_token=mode_token+1
    if mode_timer then mode_timer:cancel() mode_timer=nil end
    if mode_query then mode_query:kill() mode_query=nil end
  end
end)
local editor_refresh
morf.effect("caelestia.equalizer.editor",function()
  if editor_refresh then editor_refresh:cancel() editor_refresh=nil end
  if presentation.active("settings.sound/equalizer/audiogram")() then
    -- Read without subscribing while editing: an external update cannot
    -- erase unfinished input. Re-entry takes a fresh copy of the profile.
    editor_refresh=morf.timer(1,function()
      editor_refresh=nil M.draft:set(cfg.get("profile")) M.editor_error:set("")
    end,false)
  end
end)
return M
