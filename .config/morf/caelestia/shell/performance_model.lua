-- Performance data, device identity and read-only probes. Themes own the UI.
local morf=require("morf")
local sysinfo=require("lib.services.sysinfo")
local M={}
--- The processor's name without its trademarks and generation: "Intel
--- Core i7-11800H @ 2.30GHz", as the reference prints it.
function M.cpu_name(model)
  model = tostring(model or "")
  model = model:gsub("%(R%)", ""):gsub("%(TM%)", ""):gsub("%(tm%)", "")
  model = model:gsub("^%s*%d+%a%a Gen ", ""):gsub(" CPU ", " "):gsub("%s+Processor", "")
  model = model:gsub("%s+", " "):match("^%s*(.-)%s*$")
  if model == "" then return "Unknown processor" end
  return model
end

--- The physical disk a partition is on: nvme0n1p2 -> nvme0n1, sda3 -> sda.
function M.disk_of(device)
  local name = tostring(device or ""):match("([^/]+)$") or ""
  local base = name:match("^(nvme%d+n%d+)p%d+$") or name:match("^(mmcblk%d+)p%d+$")
  if base then return base end
  if name:match("^[shv]d%a+%d+$") then return (name:gsub("%d+$", "")) end
  return name
end

--- The machine's disks, each a physical device with its filesystems' space
--- summed (a device mounted twice counted once), largest first.
function M.disks(list)
  local by, order = {}, {}
  for _, d in ipairs(list or {}) do
    local name = M.disk_of(d.device)
    if name ~= "" and (d.total or 0) > 0 then
      local disk = by[name]
      if not disk then
        disk = { name = name, total = 0, used = 0, seen = {} }
        by[name] = disk
        order[#order + 1] = disk
      end
      if not disk.seen[d.device] then
        disk.seen[d.device] = true
        disk.total = disk.total + (d.total or 0)
        disk.used = disk.used + (d.used or 0)
      end
    end
  end
  table.sort(order, function(a, b) return a.total > b.total end)
  for _, disk in ipairs(order) do
    disk.seen = nil
    disk.percent = disk.total > 0 and 100 * disk.used / disk.total or 0
  end
  return order
end

function M.bytes(n)
  n=tonumber(n) or 0
  local units={"B","KiB","MiB","GiB","TiB","PiB"}
  local i=1
  while n>=1024 and i<#units do n=n/1024 i=i+1 end
  return (n<10 and i>1) and ("%.1f"):format(n) or ("%d"):format(math.floor(n+.5)),units[i]
end
--- A rate as Mission Center prints it: "83 KiB/s".
local function rate_text(bytes)
  local text, unit = M.bytes(bytes or 0)
  return text .. " " .. unit .. "/s"
end

local function size_text(bytes)
  local text, unit = M.bytes(bytes or 0)
  return text .. " " .. unit
end

local function ghz(mhz)
  if not mhz or mhz <= 0 then return "--" end
  if mhz >= 1000 then return ("%.2f GHz"):format(mhz / 1000) end
  return ("%d MHz"):format(math.floor(mhz + 0.5))
end

local function duration_text(seconds)
  seconds = math.floor(seconds or 0)
  local d, h = seconds // 86400, (seconds % 86400) // 3600
  local m, s = (seconds % 3600) // 60, seconds % 60
  return ("%d:%02d:%02d:%02d"):format(d, h, m, s)
end

--- How many processes run: the numbered folders in /proc.
function M.process_count()
  local ok, entries = pcall(morf.fs.list, "/proc")
  if not ok or type(entries) ~= "table" then return "--" end
  local count = 0
  for _, e in ipairs(entries) do if e.name:match("^%d+$") then count = count + 1 end end
  return tostring(count)
end

function M.new(ctx)
  local info=sysinfo.cpu_info()
  local opened = ctx.opened
  local shown = function() return opened() end

  local function read(section, fallback)
    local last=fallback
    return function()
      if shown() then
        local ok,v=pcall(sysinfo[section])
        last=ok and type(v)=="table" and v or fallback
      end
      return last
    end
  end
  local cpu = read("cpu", { usage = 0, model = "", cores = {}, count = 0, frequency = 0 })
  local memory = read("memory", { total = 0, used = 0, percent = 0, available = 0, cached = 0,
    committed = 0, swap = { total = 0, used = 0, free = 0 } })
  local drives = read("drives", { drives = {} })
  local network = read("network", { interfaces = {} })
  local gpus = read("gpu", { cards = {} })
  local fans = read("fans", { fans = {} })
  local temps = read("temperatures", {})
  local system = read("system", { uptime = 0 })

  local cache={}
  local catalog=morf.signal("caelestia.performance.history-keys",{})
  local function history(name)
    if shown() and catalog:get()[name] then
      local ok,values=pcall(sysinfo.history,name)
      cache[name]=ok and type(values)=="table" and values or {}
    end
    return cache[name] or {}
  end

  -- ------------------------------------------------------------ devices --
  -- Each a row: `key` ("cpu", "drive:nvme0n1", ...), its kind and what it
  -- names. The readings are bindings on the samples, so a row is only
  -- rebuilt when a device comes or goes.
  local list = morf.state { devices = {} }
  local selected = morf.signal("caelestia.performance.device", "cpu")
  local displayed = morf.signal("caelestia.performance.displayed", "cpu")

  local function find(items, field, value)
    for _, item in ipairs(items or {}) do if item[field] == value then return item end end
    return nil
  end
  local function drive(name) return find(drives().drives, "name", name) or { units = {} } end
  local function iface(name) return find(network().interfaces, "name", name) or {} end
  local function card(name) return find(gpus().cards, "name", name) or {} end
  local function fan(key) return find(fans().fans, "key", key) or {} end

  morf.effect("caelestia.performance.devices", function()
    if not shown() then return end
    local rows = { { key = "cpu", kind = "cpu", ref = "" }, { key = "memory", kind = "memory", ref = "" } }
    for _, d in ipairs(drives().drives) do rows[#rows + 1] = { key = "drive:" .. d.name, kind = "drive", ref = d.name } end
    for _, i in ipairs(network().interfaces) do
      if not i.virtual then rows[#rows + 1] = { key = "net:" .. i.name, kind = "net", ref = i.name } end
    end
    for index, g in ipairs(gpus().cards) do
      rows[#rows + 1] = { key = "gpu:" .. g.name, kind = "gpu", ref = g.name, index = index - 1 }
    end
    for index, f in ipairs(fans().fans) do
      rows[#rows + 1] = { key = "fan:" .. f.key, kind = "fan", ref = f.key, index = index - 1 }
    end
    local allowed={cpu=true,memory=true,swap=true}
    for i=0,math.max(1,info.logical or 1)-1 do allowed["core"..i]=true end
    for _,row in ipairs(rows) do
      if row.kind=="drive" then
        for _,field in ipairs {"busy","read","write"} do allowed["disk:"..row.ref..":"..field]=true end
      elseif row.kind=="net" then allowed["rx:"..row.ref],allowed["tx:"..row.ref]=true,true
      elseif row.kind=="gpu" then
        for _,prefix in ipairs {"gpu:","gpuenc:","gpudec:","gpumem:"} do allowed[prefix..row.ref]=true end
      elseif row.kind=="fan" then allowed[row.ref]=true end
    end
    for key in pairs(cache) do if not allowed[key] then cache[key]=nil end end
    catalog:set(allowed)
    list.devices:replace(rows, "key")
    local found=false
    for _,row in ipairs(rows) do if row.key==selected:get() then found=true break end end
    if not found then selected:set("cpu") displayed:set("cpu") end
    local present=false
    for _,row in ipairs(rows) do if row.key==displayed:get() then present=true break end end
    if not present then displayed:set("cpu") end
  end)

  -- What the picked device is: its kind and name ("drive", "nvme0n1").
  local function picked()
    local key = displayed:get()
    local kind, ref = key:match("^(%a+):(.*)$")
    return kind or key, ref or ""
  end
  local function on(kind) return function() return (picked()) == kind end end

  local function drive_ref() local _, ref = picked() return ref end
  local function the_drive() return drive(drive_ref()) end
  local units = morf.state { rows = {} }
  morf.effect("caelestia.performance.units", function()
    if not shown() or (picked()) ~= "drive" then return end
    local rows = {}
    for _, u in ipairs(the_drive().units or {}) do
      rows[#rows + 1] = { name = u.name }
    end
    units.rows:replace(rows, "name")
  end)
  local function unit(name) return find(the_drive().units, "name", name) or { mounts = {} } end
  local function net_ref() local _, ref = picked() return ref end
  local function the_iface() return iface(net_ref()) end
  -- Addresses and the network's name, asked once per interface picked.
  local addresses = morf.signal("caelestia.performance.addresses", { v4 = "", v6 = "", ssid = "" })
  local asked,generation = "",0
  morf.effect("caelestia.performance.addresses", function()
    if not shown() or (picked()) ~= "net" then asked = "" generation=generation+1 return end
    local name = net_ref()
    if name == asked then return end
    asked = name
    generation=generation+1
    local own=generation
    local function current() return own==generation and shown() and (picked())=="net" and net_ref()==name end
    addresses:set({ v4 = "", v6 = "", ssid = "" })
    morf.run({ "ip", "-j", "addr", "show", "dev", name }, {}, function(result)
      if not current() or not (result and result.ok) then return end
      local ok, data = pcall(morf.json.decode, result.stdout or "")
      if not ok or type(data) ~= "table" or not data[1] then return end
      local v4, v6 = {}, {}
      for _, a in ipairs(data[1].addr_info or {}) do
        if a.family == "inet" then v4[#v4 + 1] = a["local"] end
        if a.family == "inet6" and a.scope == "global" then v6[#v6 + 1] = a["local"] end
      end
      local now = addresses:get()
      addresses:set({ v4 = table.concat(v4, ", "), v6 = table.concat(v6, ", "), ssid = now.ssid })
    end)
    if the_iface().wireless then
      morf.run({ "nmcli", "-t", "-g", "GENERAL.CONNECTION", "device", "show", name }, {}, function(result)
        if not current() or not (result and result.ok) then return end
        local now = addresses:get()
        addresses:set({ v4 = now.v4, v6 = now.v6, ssid = (tostring(result.stdout or ""):gsub("%s+$", "")) })
      end)
    end
  end)
  local function totals()
    local i = the_iface()
    return i.rx_bytes or 0, i.tx_bytes or 0
  end
  local function gpu_ref() local _, ref = picked() return ref end
  local function the_card() return card(gpu_ref()) end
  local function gpu_index()
    for index, g in ipairs(gpus().cards) do if g.name == gpu_ref() then return index - 1 end end
    return 0
  end
  local function fan_ref() local _, ref = picked() return ref end
  local function the_fan() return fan(fan_ref()) end
  local function row_title(row)
    if row.kind == "cpu" then return "CPU" end
    if row.kind == "memory" then return "Memory" end
    if row.kind == "drive" then return ("%s (%s)"):format(drive(row.ref).kind or "Drive", row.ref) end
    if row.kind == "net" then return ("%s (%s)"):format(iface(row.ref).wireless and "Wi-Fi" or "Ethernet", row.ref) end
    if row.kind == "gpu" then return ("GPU %d"):format(row.index or 0) end
    return ("Fan %d"):format(row.index or 0)
  end
  local function row_sub(row)
    if row.kind == "cpu" then return M.cpu_name(info.model) end
    if row.kind == "memory" then
      local m = memory()
      return ("%s / %s"):format(size_text(m.used), size_text(m.total))
    end
    if row.kind == "drive" then return drive(row.ref).model or "" end
    if row.kind == "net" then
      local i = iface(row.ref)
      return ("S: %s  R: %s"):format(rate_text(i.tx_rate), rate_text(i.rx_rate))
    end
    if row.kind == "gpu" then return card(row.ref).model or "" end
    return fan(row.ref).label or ""
  end
  local function row_value(row)
    if row.kind == "cpu" then
      local t = temps().cpu
      return ("%d%%%s"):format(math.floor((cpu().usage or 0) + 0.5), t and (" (%d °C)"):format(math.floor(t + 0.5)) or "")
    end
    if row.kind == "memory" then return ("%d%%"):format(math.floor((memory().percent or 0) + 0.5)) end
    if row.kind == "drive" then return ("%d%%"):format(math.floor((drive(row.ref).busy or 0) + 0.5)) end
    if row.kind == "net" then return iface(row.ref).state or "" end
    if row.kind == "gpu" then
      local g = card(row.ref)
      if g.suspended then return "Suspended" end
      return g.busy and ("%d%%"):format(math.floor(g.busy + 0.5)) or "Active"
    end
    return ("%d RPM"):format(fan(row.ref).rpm or 0)
  end
  local function row_series(row)
    if row.kind == "cpu" then return function() return history("cpu") end, nil, 100 end
    if row.kind == "memory" then return function() return history("memory") end, nil, 100 end
    if row.kind == "drive" then return function() return history("disk:" .. row.ref .. ":busy") end, nil, 100 end
    if row.kind == "net" then
      return function() return history("rx:" .. row.ref) end, function() return history("tx:" .. row.ref) end, nil
    end
    if row.kind == "gpu" then return function() return history("gpu:" .. row.ref) end, nil, 100 end
    return function() return history(row.ref) end, nil, function()
      local f = fan(row.ref)
      return (f.max and f.max > 0) and f.max or 8000
    end
  end

  local intervals={}
  for name,source in pairs(sysinfo.sources) do intervals[name]=source.interval end
  local model={active=opened,list=list,selected=selected,displayed=displayed,picked=picked,on=on,history=history,
    cpu=cpu,memory=memory,drives=drives,network=network,gpus=gpus,fans=fans,temps=temps,system=system,
    drive=drive,iface=iface,card=card,fan=fan,drive_ref=drive_ref,the_drive=the_drive,units=units,unit=unit,
    net_ref=net_ref,the_iface=the_iface,addresses=addresses,totals=totals,
    gpu_ref=gpu_ref,the_card=the_card,gpu_index=gpu_index,fan_ref=fan_ref,the_fan=the_fan,
    row_title=row_title,row_sub=row_sub,row_value=row_value,row_series=row_series,
    info=info,samples=sysinfo.history_size,intervals=intervals,
    cpu_name=M.cpu_name,size=size_text,rate=rate_text,ghz=ghz,duration=duration_text,
    process_count=function() return shown() and (picked())=="cpu" and M.process_count() or "--" end}
  function model.present(key)
    if key==selected:get() then displayed:set(key) end
  end
  model.readouts=require("performance_readouts").build(model)
  return model
end
return M
