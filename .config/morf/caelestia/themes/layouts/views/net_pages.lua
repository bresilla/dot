-- Wired, mesh, tunnel and Tor settings, in the page template
-- (themes/layouts/page.lua): each kind of link a section, a link a row
-- with its button.
local ui=require("morf.ui")
local theme=require("theme")
local kit=require("kit")
local P=require("themes.layouts.page")
local M={}

--- A link's row: its icon, name and state, and the button that brings it
--- up or down (the primary one while it is down).
local function link_row(w, spec)
  local trailing
  if spec.toggle then
    trailing = P.button {
      id = spec.id .. "-switch",
      label = function() return spec.on() and (spec.off_word or "Disconnect") or (spec.on_word or "Connect") end,
      tone = function() return spec.on() and "plain" or "primary" end,
      visible = function() return spec.can == nil or spec.can() end,
      on_clicked = function() spec.toggle(not spec.on()) end,
    }
  end
  local row = P.row { id = spec.id, width = P.inner(w), icon = spec.icon, on = spec.on, title = spec.name,
    subtitle = spec.detail, trailing = trailing }
  if spec.visible then row.visible = spec.visible end
  return row
end

local function note(w, text, visible)
  local n = kit.subtitle { width = w, wrap = true, font_size = theme.size.small, text = text,
    color = kit.ink("lo") }
  if visible then n.visible = visible end
  return n
end

local function entry(model,w,row)
  local function live() return model.row(row) or row end
  return link_row(w,{
    id=row.id,icon=function() return live().icon end,name=function() return live().name end,
    on=function() return live().on end,detail=function() return live().detail end,
    can=function() return live().can end,on_word=row.on_word,off_word=row.off_word,
    toggle=row.source~="readout" and function(on) model.toggle(row,on) end or nil,
  })
end

--- The rows of `rows_model`; a row saying `none` while it has none.
local function list(model, w, rows_model, none)
  return ui.Column { width = P.inner(w), gap = P.ROW_GAP,
    ui.Repeater { as = "column", gap = P.ROW_GAP, width = P.inner(w), model = rows_model,
      delegate = function(row) return entry(model, w, row) end },
    P.row { width = P.inner(w), icon = "info", on = function() return false end, title = none or "Nothing here",
      visible = function() return rows_model:len() == 0 end } }
end

function M.build(model,w,h)
  local kind=model.kind
  local blocks={}
  if kind=="wired" then
    blocks[#blocks+1]=P.section {id="wired-ports",caption_id="wired-ports-title",width=w,title="Ports",
      list(model,w,model.network,"No wired ports")}
    blocks[#blocks+1]=note(w,function() return model.has_network() and model.note or "NetworkManager is not running." end)
  elseif kind=="tor" then
    blocks[#blocks+1]=P.section {id="tor-services",width=w,title="Tor",list(model,w,model.tor)}
    blocks[#blocks+1]=note(w,function() return model.available() and model.note or "Tor is not installed." end)
  else
    if kind=="tunnel" then
      blocks[#blocks+1]=P.section {id="vpn-tunnel-network",caption_id="vpn-tunnel-network-title",width=w,
        title="NetworkManager",visible=function() return model.network:len()>0 end,
        list(model,w,model.network)}
    end
    local apps={id="vpn-"..kind.."-apps",caption_id=kind=="tunnel" and "vpn-tunnel-apps-title" or nil,width=w,
      title="Apps",visible=kind=="tunnel" and model.has_network or nil}
    for _,id in ipairs(model.tools) do
      local function row() return model.row("app:"..id) end
      apps[#apps+1]=link_row(w,{
        id="vpn-"..id,icon=kind=="mesh" and "hub" or "shield",name=model.names[id],
        on=function() local r=row() return r~=nil and r.on end,
        detail=function() local r=row() return r and r.detail or "Reading…" end,
        can=function() local r=row() return r~=nil and r.can end,
        on_word=kind=="mesh" and "Up" or "Connect",off_word=kind=="mesh" and "Down" or "Disconnect",
        toggle=function(on) model.toggle("app:"..id,on) end,
        visible=function() return model.apps:len()==0 or row()~=nil end,
      })
    end
    blocks[#blocks+1]=P.section(apps)
    blocks[#blocks+1]=note(w,model.note)
    if kind=="tunnel" then
      local present=function() return model.tor:len()>0 end
      blocks[#blocks+1]=P.section {id="vpn-tunnel-tor",caption_id="vpn-tunnel-tor-title",width=w,title="Tor",
        visible=present,list(model,w,model.tor)}
      blocks[#blocks+1]=note(w,"Tor runs a SOCKS proxy for apps configured to use it. Starting it does not route all system traffic through Tor.",present)
    end
  end
  local page=P.page {id=(kind=="mesh" or kind=="tunnel") and "vpn-"..kind.."-scroll" or kind.."-scroll",
    width=w,height=h,active=model.active,table.unpack(blocks)}
  if kind=="wired" or kind=="tor" then
    local present=kind=="wired" and model.has_network or model.available
    page.visible=present
    local missing=P.empty {width=w,icon=kind=="wired" and "lan" or "shield",
      title=kind=="wired" and "No network service" or "Tor is not installed",
      text=kind=="wired" and "NetworkManager is not running." or "Install Tor to run its proxy here."}
    missing.visible=function() return not present() end
    return ui.Item {width=w,height=h,page,missing}
  end
  return page
end
return M
