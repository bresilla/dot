-- One composition for every theme: the kit supplies the cards, controls,
-- the response chart and the input wells; nothing here picks a shape.
local morf=require("morf")
local ui=require("morf.ui")
local theme=require("theme")
local kit=require("kit")
local rows=require("themes.layouts.rows")
local C=theme.color
local M={}
local SCOPE="settings.sound/equalizer"
local function title(text,width,scope)
  return kit.heading {text=text,width=width,elide="right",scope=scope or SCOPE,level="section"}
end
local function note(text,width)
  return kit.subtitle {text=text,width=width,wrap=true,font_size=theme.size.small}
end
local function box(id,w,height,children)
  local column=ui.Column {x=16,y=14,width=w-32,gap=8,table.unpack(children)}
  return kit.card {id=id,width=w,height=function() return math.max(height,(column.layout_height or 0)+28) end,column}
end
local function flag(id,label,w,on,set)
  return ui.Item {width=w,height=32,
    kit.menu_label {width=w-72,text=label,anchors={vertical_center=true}},
    kit.switch {id=id,accessible_name=label,on=on,on_toggled=set,anchors={right=true,vertical_center=true}}}
end
local function number_slider(id,label,w,get,set,low,high,units)
  return ui.Column {width=w,gap=0,
    ui.Item {width=w,height=18,
      kit.subtitle {text=label,width=w-90,font_size=theme.size.small},
      kit.text {text=function() return ("%.1f%s"):format(get(),units or "") end,font_size=theme.size.small,
        width=90,horizontal_alignment="right",anchors={right=true}}},
    kit.slider {id=id,accessible_name=label,width=w,height=22,label=false,value=function() return (get()-low)/(high-low) end,
      set=function(v) set(math.floor((low+v*(high-low))*10+.5)/10) end}}
end
function M.build(model,w,h)
  local inner=w-32
  local mode_buttons={width=inner,gap=6}
  for _,entry in ipairs {{"auto","Auto"},{"headphones","Headphones"},{"speakers","Speakers"}} do
    local key,label=entry[1],entry[2]
    local function on() return model.get("mode")==key end
    mode_buttons[#mode_buttons+1]=rows.choice {id="equalizer-mode-"..key,group="equalizer-mode",width=(inner-12)/3,height=32,on=on,
      tone="primary",tile=true,on_clicked=function() model.set("mode",key) end,
      kit.menu_label {anchors={center_in=true},text=label,font_size=theme.size.small,font_weight=600,
        width=(inner-12)/3-12,elide="right",horizontal_alignment="center",
        color=rows.ink(on,true,C.onSurfaceVariant)}}
  end
  local curve=function() return model.curve:get() end
  local function series(ear) return function() local c=curve() return c and c[ear] or {} end end
  -- The response on the theme's chart: left filled, right as its second line.
  local chart=kit.chart {width=inner,height=114,first=series("response_left"),second=series("response_right"),
    samples=160,bottom=-36,top=12,columns=8}
  local graph=ui.Item {id="equalizer-response",width=inner,height=114,chart}
  local band_rows={title("Bands",inner),note("Tone adjustments · −12 to +12 dB",inner)}
  for i,hz in ipairs(model.frequencies) do
    band_rows[#band_rows+1]=number_slider("equalizer-band-"..i,hz<1000 and hz.." Hz" or hz/1000 .." kHz",inner,
      function() return model.current("bands")[i] end,function(v) model.set_band(i,v) end,-12,12," dB")
  end
  band_rows[#band_rows+1]=kit.pill {id="equalizer-reset",width=inner,height=32,label="Reset tone adjustments",on_clicked=model.reset_bands}
  return (kit.scroll({id="equalizer-scroll",width=w,height=h,clip=true,
    ui.Column {width=w,gap=12,
      box("equalizer-controls",w,168,{
        flag("equalizer-enabled","Equalizer",inner,function() return model.get("enabled") end,function(v) model.set("enabled",v) end),
        note(function()
          local status=model.status:get()
          if model.error:get()~="" then return model.error:get() end
          if not model.get("enabled") then return "Bypassed · original audio" end
          return status=="starting" and "Starting audio filter…" or status=="preview" and "Preview · audio unchanged"
            or "Active · "..model.preset()
        end,inner),
        ui.Row(mode_buttons),
        note("Auto follows the active output. Each mode keeps its own settings.",inner),
      }),
      box("equalizer-curve",w,198,{title("Response",inner),graph,
        note(function() local c=curve() return ("L filled / R line · 20 Hz–20 kHz · headroom %.1f dB"):format(c and c.preamp or 0) end,inner)}),
      box("equalizer-compensation",w,270,{
        title("Audiogram compensation",inner),
        flag("equalizer-compensation-enabled","Use audiogram",inner,function() return model.get("compensation") end,
          function(v) model.set("compensation",v) end),
        number_slider("equalizer-strength","Strength",inner,function() return model.current("strength") end,
          function(v) model.set_current("strength",v) end,0,100,"%"),
        flag("equalizer-per-ear","Separate left / right",inner,function() return model.current("per_ear") end,
          function(v) model.set_current("per_ear",v) end),
        kit.pill {id="equalizer-audiogram",width=inner,height=36,
          label=function() return model.get("profile.label").."  ›" end,on_clicked=model.open_editor},
        note("Enter existing measured thresholds. This adjusts listening audio; it does not measure hearing.",inner),
      }),
      box("equalizer-bands",w,484,band_rows),
      box("equalizer-headroom",w,140,{
        title("Output headroom",inner),
        number_slider("equalizer-trim","Additional attenuation",inner,function() return model.current("trim") end,
          function(v) model.set_current("trim",v) end,-24,0," dB"),
        note("Automatic attenuation includes overlapping boosts. It is not a limiter.",inner),
      }),
    }}))
end
function M.audiogram(model,w,h)
  local inner=w-32
  local function input(id,ear,index,width)
    local name=ear=="label" and "Profile name"
      or ("%s ear at %s Hz"):format(ear=="left" and "Left" or "Right",tostring(model.frequencies[index]))
    local node_node, node = kit.text_field("numeric_entry", {id=id,accessible_name=name,width=width-16,height=30,x=8,
      text=function() local draft=model.draft:get() return tostring(ear=="label" and draft.label or draft[ear][index]) end,
      font_family=theme.font,font_size=theme.size.normal,color=function() return C.onSurface end,
      caret_color=function() return C.primary end,selection_color=function() return C.primary:alpha(.25) end,
      on_text_changed=function(value) model.edit(ear,index,value) end})
    return rows.well {width=width,height=34,node_node}
  end
  local rows={width=inner,gap=10}
  rows[#rows+1]=ui.Row {width=inner,gap=8,
    kit.subtitle {width=64,text="Hz",font_size=theme.size.small},
    kit.subtitle {width=(inner-80)/2,text="Left · dB HL",font_size=theme.size.small},
    kit.subtitle {width=(inner-80)/2,text="Right · dB HL",font_size=theme.size.small}}
  for i,hz in ipairs(model.frequencies) do
    rows[#rows+1]=ui.Row {width=inner,gap=8,align="center",
      kit.text {width=64,text=tostring(hz),font_size=theme.size.normal},
      input("audiogram-left-"..i,"left",i,(inner-80)/2),
      input("audiogram-right-"..i,"right",i,(inner-80)/2)}
  end
  return (kit.scroll({id="audiogram-scroll",width=w,height=h,clip=true,
    box("audiogram-editor",w,646,{
      title("Measured thresholds",inner,"settings.sound/equalizer/audiogram"),
      note("Copy an existing audiogram. Values can range from −10 to 120 dB HL; blank profiles start at zero.",inner),
      input("audiogram-label","label",nil,inner),
      ui.Column(rows),
      note(function() return model.editor_error:get() end,inner),
      kit.pill {id="audiogram-save",width=inner,height=36,label="Save audiogram",on_clicked=model.save_profile},
      note("Back discards unsaved edits.",inner),
    })}))
end
return M
