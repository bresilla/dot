-- Shared labels and formatted readings for each device kind. No visual nodes.
local M={}
function M.build(model)
  local cpu,memory,temps,system=model.cpu,model.memory,model.temps,model.system
  local the_drive,the_iface,the_card,the_fan=model.the_drive,model.the_iface,model.the_card,model.the_fan
  local net_ref,gpu_ref,totals,addresses=model.net_ref,model.gpu_ref,model.totals,model.addresses
  local info=model.info
  local rate_text,size_text,ghz,duration_text=model.rate,model.size,model.ghz,model.duration
  local function stat(label,value,mark,kind) return {label=label,value=value,mark=mark,kind=kind} end
  return {
    cpu={stats={
        stat("Utilization", function() return ("%d%%"):format(math.floor((cpu().usage or 0) + 0.5)) end),
        stat("Speed", function() return ghz(cpu().frequency) end),
        stat("Processes", function() cpu() return model.process_count() end),
        stat("Threads", function() return tostring(cpu().threads or "--") end),
        stat("Temperature", function()
          local t = temps().cpu
          return t and ("%d °C"):format(math.floor(t + 0.5)) or "--"
        end),
        stat("Up time", function() return duration_text(system().uptime) end),
      },facts={
        { "Base speed:", ghz(info.base_mhz) },
        { "Max speed:", ghz(info.max_mhz) },
        { "Sockets:", tostring(info.sockets) },
        { "Virtual processors:", tostring(info.logical) },
        { "Virtualization:", info.virtualization ~= "" and info.virtualization or "No" },
        { "L1 cache:", size_text((info.caches.L1d or 0) + (info.caches.L1i or 0)) },
        { "L2 cache:", size_text(info.caches.L2 or 0) },
        { "L3 cache:", size_text(info.caches.L3 or 0) },
        { "Cpufreq driver:", info.driver },
        { "Cpufreq governor:", info.governor },
        { "Power preference:", info.preference },
      }},
    memory={stats={
        stat("In use", function() return size_text(memory().used) end, "solid", "memory"),
        stat("Available", function() return size_text(memory().available) end),
        stat("Committed", function() return size_text(memory().committed) end),
        stat("Cached", function() return size_text(memory().cached) end),
        stat("Swap used", function() return size_text(memory().swap.used) end),
        stat("Swap available", function() return size_text(memory().swap.free) end),
      },facts={
        { "Total:", function() return size_text(memory().total) end },
        { "Shared:", function() return size_text(memory().shared) end },
        { "Buffers:", function() return size_text(memory().buffers) end },
        { "Dirty:", function() return size_text(memory().dirty) end },
        { "Commit limit:", function() return size_text(memory().commit_limit) end },
      }},
    drive={stats={
        stat("Read speed", function() return rate_text(the_drive().read_rate) end, "solid", "drive"),
        stat("Write speed", function() return rate_text(the_drive().write_rate) end, "dashed", "drive"),
        stat("Total read", function() return size_text(the_drive().read_total) end),
        stat("Total written", function() return size_text(the_drive().write_total) end),
        stat("Active time", function() return ("%d%%"):format(math.floor((the_drive().busy or 0) + 0.5)) end),
      },facts={
        { "Capacity:", function() return size_text(the_drive().capacity) end },
        { "System disk:", function() return the_drive().system and "Yes" or "No" end },
        { "Type:", function() return the_drive().kind or "" end },
        { "Removable:", function() return the_drive().removable and "Yes" or "No" end },
        { "Logical units:", function() return tostring(#(the_drive().units or {})) end },
      }},
    net={stats={
        stat("Receive", function() return rate_text(the_iface().rx_rate) end, "solid", "net"),
        stat("Send", function() return rate_text(the_iface().tx_rate) end, "dashed", "net"),
        stat("Total received", function() return size_text((totals())) end),
        stat("Total sent", function() local _, tx = totals() return size_text(tx) end),
      },facts={
        { "Interface name:", net_ref },
        { "Connection type:", function() return the_iface().wireless and "Wireless" or "Wired" end },
        { "Network:", function() local a = addresses:get() return a.ssid ~= "" and a.ssid or "--" end },
        { "Link speed:", function() local sp = the_iface().speed return sp and (sp .. " Mb/s") or "--" end },
        { "State:", function() return the_iface().state or "" end },
        { "Hardware address:", function() return the_iface().address or "" end },
        { "IPv4 address:", function() local a = addresses:get() return a.v4 ~= "" and a.v4 or "N/A" end },
        { "IPv6 address:", function() local a = addresses:get() return a.v6 ~= "" and a.v6 or "N/A" end },
      }},
    gpu={stats={
        stat("Utilization", function()
          local g = the_card()
          if g.suspended then return "Off" end
          return g.busy and ("%d%%"):format(math.floor(g.busy + 0.5)) or "--"
        end),
        stat("Clock speed", function()
          local g = the_card()
          if g.suspended or not g.clock_mhz then return "--" end
          return ghz(g.clock_mhz)
        end),
        stat("Memory usage", function()
          local g = the_card()
          if not g.vram_total then return "Shared" end
          return size_text(g.vram_used)
        end),
        stat("Temperature", function()
          local g = the_card()
          return g.temperature and ("%d °C"):format(g.temperature) or "--"
        end),
        stat("Video encode", function() local g = the_card() return g.encoder and ("%d%%"):format(g.encoder) or "--" end,
          "solid", "gpu"),
        stat("Video decode", function() local g = the_card() return g.decoder and ("%d%%"):format(g.decoder) or "--" end,
          "dashed", "gpu"),
        stat("Power draw", function()
          local g = the_card()
          if not g.power then return "--" end
          return g.power_limit and ("%d / %d W"):format(math.floor(g.power + 0.5), math.floor(g.power_limit + 0.5))
            or ("%d W"):format(math.floor(g.power + 0.5))
        end),
        stat("State", function() return the_card().suspended and "Suspended" or "Active" end),
      },facts={
        { "Vendor:", function() return the_card().vendor or "" end },
        { "Max clock:", function() return ghz(the_card().max_mhz) end },
        { "Memory speed:", function()
          local g = the_card()
          return g.memory_clock_mhz and ("%s / %s"):format(ghz(g.memory_clock_mhz), ghz(g.memory_max_mhz)) or "--"
        end },
        { "Driver version:", function() return the_card().driver_version or "--" end },
        { "Driver:", function() return the_card().driver or "" end },
        { "PCI bus address:", function() return the_card().slot or "" end },
        { "Card:", gpu_ref },
      }},
    fan={stats={
        stat("Speed", function() return ("%d RPM"):format(the_fan().rpm or 0) end, "solid", "fan"),
        stat("Temperature", function()
          local t = temps().cpu
          return t and ("%d °C"):format(math.floor(t + 0.5)) or "--"
        end),
      },facts={
        { "Label:", function() return the_fan().label or "" end },
        { "Sensor chip:", function() return the_fan().chip or "" end },
        { "Maximum:", function() local f = the_fan() return f.max and (f.max .. " RPM") or "--" end },
      }},
  }
end
return M
