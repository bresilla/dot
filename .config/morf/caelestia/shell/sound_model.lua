-- Audio snapshots and actions shared by the visual themes. The native audio
-- model drives updates; hidden pages hold their last snapshot without polling.
local morf=require("morf")
local M={}
local function dry_run()
  local value=morf.env("CAELESTIA_DRY_RUN")
  return value~=nil and value~="" and value~="0"
end
local function volume(value)
  if type(value)~="number" or value~=value or math.abs(value)==math.huge then return nil end
  return math.max(0,math.min(1.5,value))
end
function M.new(kind,active)
  assert(kind=="output" or kind=="input","unknown audio page")
  local audio=morf.audio
  local key=kind=="output" and "sound" or "microphone"
  local snapshot=morf.signal("caelestia."..key..".audio",{available=false,devices={},streams={}})
  local rows=morf.state {devices={},streams={},channels={}}
  local model={key=key,kind=kind,active=active,devices=rows.devices,streams=rows.streams,channels=rows.channels}
  local function read_list(list,accept)
    local result={}
    if list then for i=1,list:len() do
      local row=list:get(i)
      if row and accept(row) then result[#result+1]=row end
    end end
    return result
  end
  morf.effect("caelestia."..key..".audio-read",function()
    if not active() then return end
    local ok,value=pcall(function()
      if not audio or not audio.available() then return {available=false,devices={},streams={}} end
      local equalizer_id
      local default=kind=="output" and audio.default_sink() or kind=="input" and audio.default_source() or nil
      local devices=read_list(kind=="output" and audio.sinks or audio.sources,function(row)
        if row.name=="morf.equalizer.input" then equalizer_id=row.id return false end
        return kind=="output" or not tostring(row.name or ""):match("%.monitor$")
      end)
      local streams=kind=="output" and read_list(audio.streams,function(row)
        return row.direction=="playback" and row.app_id~="morf.equalizer"
          and not (row.binary=="pipewire" and row.media_name=="Morf Equalizer")
      end) or {}
      -- Smart filters attach apps to an internal sink. Show the physical
      -- default behind that filter as their destination in routing chips.
      for _,stream in ipairs(streams) do
        if equalizer_id and stream.device==equalizer_id and default then stream.device=default.id end
      end
      return {available=true,devices=devices,streams=streams,default=default}
    end)
    if not ok then value={available=false,devices={},streams={}} end
    -- A replacement with a reused native ID must also get fresh UI callbacks.
    -- Keep descriptions/volume out of the key so ordinary updates keep hover.
    for _,row in ipairs(value.devices) do
      row.key=morf.json.encode({row.id,row.name or "",row.kind or ""})
    end
    for _,row in ipairs(value.streams) do
      row.key=morf.json.encode({row.id,row.pid or 0,row.app_id or "",row.binary or "",row.direction or ""})
    end
    snapshot:set(value)
    rows.devices:replace(value.devices,"key")
    rows.streams:replace(value.streams,"key")
    local channels={}
    local device=value.default
    for i=1,device and device.channels or 0 do
      channels[i]={id=i,name=device.channels==2 and (i==1 and "L" or "R") or tostring(i)}
    end
    rows.channels:replace(channels,"id")
  end)
  function model.available() return snapshot:get().available end
  function model.default() return snapshot:get().default end
  local function cached(collection,target)
    local id=type(target)=="table" and target.id or target
    for _,row in ipairs(snapshot:get()[collection]) do
      if row.id==id then return row end
    end
  end
  function model.device(target) return cached("devices",target) end
  function model.stream(target) return cached("streams",target) end
  local function live(target,stream)
    if not active() or dry_run() or type(target)~="table" then return nil end
    local ok,row=pcall(function()
      if not audio or not audio.available() then return nil end
      return stream and audio.stream(target.id) or not stream and audio.device(target.id) or nil
    end)
    if not ok or not row then return nil end
    -- Native IDs can be reused after removal. Reject controls retaining a row
    -- whose device name or stream owner no longer matches that ID.
    for _,field in ipairs(stream and {"direction","pid","app_id","binary"} or {"name","kind"}) do
      if row[field]~=target[field] then return nil end
    end
    return row
  end
  local function send(command,...)
    local ok,result=pcall(command,...)
    return ok and result~=false
  end
  function model.set_device_volume(target,value)
    local row,v=live(target,false),volume(value)
    return row~=nil and v~=nil and send(audio.set_volume,row.id,v)
  end
  function model.set_stream_volume(target,value)
    local row,v=live(target,true),volume(value)
    return row~=nil and v~=nil and send(audio.set_volume,row.id,v)
  end
  function model.toggle_device(target)
    local row=live(target,false)
    return row~=nil and send(audio.set_mute,row.id,not row.muted)
  end
  function model.toggle_stream(target)
    local row=live(target,true)
    return row~=nil and send(audio.set_mute,row.id,not row.muted)
  end
  function model.select_device(target)
    local row=live(target,false)
    return row~=nil and send(audio.set_default,row.id)
  end
  function model.route(target,destination)
    local stream,device=live(target,true),live(destination,false)
    return stream~=nil and device~=nil and stream.direction=="playback" and device.kind=="sink"
      and send(audio.move_stream,stream.id,device.id)
  end
  function model.channel(index)
    local device=model.default()
    return device and ((device.volumes or {})[index] or device.volume) or 0
  end
  function model.set_channel(index,value)
    local row,v=live(model.default(),false),volume(value)
    if not row or not v or type(index)~="number" or index%1~=0 or index<1 or index>(row.channels or 0) then return false end
    local values={}
    for i=1,row.channels do values[i]=(row.volumes or {})[i] or row.volume or 0 end
    values[index]=v
    return send(audio.set_channel_volumes,row.id,values)
  end
  return model
end
return M
