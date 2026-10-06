-- The equalizer and its audiogram editor, in the page template
-- (themes/layouts/page.lua): each part a section, switches on rows, the
-- kit's chart, sliders and input wells inside the cards.
local ui=require("morf.ui")
local theme=require("theme")
local kit=require("kit")
local rows=require("themes.layouts.rows")
local P=require("themes.layouts.page")
local C=theme.color
local M={}
local function note(text,width)
  return kit.subtitle {text=text,width=width,wrap=true,font_size=theme.size.small,color=kit.ink("lo")}
end
--- A switch on a row of its own.
local function flag(id,label,subtitle,w,on,set,icon)
  return P.row {id=id.."-row",width=w,icon=icon,on=on,title=label,subtitle=subtitle,
    trailing=P.switch {id=id,name=label,on=on,on_toggled=set}}
end
local function number_slider(id,label,w,get,set,low,high,units)
  return ui.Column {width=w,gap=2,
    ui.Item {width=w,height=18,
      kit.subtitle {text=label,width=w-90,elide="right",font_size=theme.size.small,color=kit.ink("lo")},
      kit.text {text=function() return ("%.1f%s"):format(get(),units or "") end,font_size=theme.size.small,
        width=90,horizontal_alignment="right",anchors={right=true}}},
    kit.slider {id=id,accessible_name=label,width=w,height=22,label=false,value=function() return (get()-low)/(high-low) end,
      set=function(v) set(math.floor((low+v*(high-low))*10+.5)/10) end}}
end
--- A button that fits its label, in the middle of the card's width.
local function centred(w,spec)
  return ui.Item {width=w,height=P.BUTTON_H,ui.Row {anchors={horizontal_center=true},P.button(spec)}}
end
function M.build(model,w,h)
  local inner=P.inner(w)
  local modes={width=inner}
  for _,entry in ipairs {{"auto","Auto"},{"headphones","Headphones"},{"speakers","Speakers"}} do
    local key,label=entry[1],entry[2]
    modes[#modes+1]={id="equalizer-mode-"..key,group="equalizer-mode",label=label,
      selected=function() return model.get("mode")==key end,on_clicked=function() model.set("mode",key) end}
  end
  local curve=function() return model.curve:get() end
  local function series(ear) return function() local c=curve() return c and c[ear] or {} end end
  -- The response on the theme's chart: left filled, right as its second line.
  local chart=kit.chart {width=inner,height=114,first=series("response_left"),second=series("response_right"),
    samples=160,bottom=-36,top=12,columns=8}
  local bands={id="equalizer-bands",width=w,title="Bands",
    note("Tone adjustments · −12 to +12 dB",inner)}
  for i,hz in ipairs(model.frequencies) do
    bands[#bands+1]=number_slider("equalizer-band-"..i,hz<1000 and hz.." Hz" or hz/1000 .." kHz",inner,
      function() return model.current("bands")[i] end,function(v) model.set_band(i,v) end,-12,12," dB")
  end
  bands[#bands+1]=ui.Item {width=1,height=4}
  bands[#bands+1]=centred(inner,{id="equalizer-reset",icon="restart_alt",label="Reset tone adjustments",
    on_clicked=model.reset_bands})
  return P.page {id="equalizer-scroll",width=w,height=h,
    P.section {id="equalizer-controls",width=w,title="Equalizer",
      flag("equalizer-enabled","Equalizer",function()
          local status=model.status:get()
          if model.error:get()~="" then return model.error:get() end
          if not model.get("enabled") then return "Bypassed · original audio" end
          return status=="starting" and "Starting audio filter…" or status=="preview" and "Preview · audio unchanged"
            or "Active · "..model.preset()
        end,inner,function() return model.get("enabled") end,function(v) model.set("enabled",v) end,"equalizer"),
      P.buttons(modes),
      note("Auto follows the active output. Each mode keeps its own settings.",inner),
    },
    P.section {id="equalizer-curve",width=w,title="Response",
      ui.Item {id="equalizer-response",width=inner,height=114,chart},
      note(function() local c=curve() return ("L filled / R line · 20 Hz–20 kHz · headroom %.1f dB"):format(c and c.preamp or 0) end,inner)},
    P.section {id="equalizer-compensation",width=w,title="Audiogram compensation",
      flag("equalizer-compensation-enabled","Use audiogram","Lift what the audiogram says is quiet",inner,
        function() return model.get("compensation") end,function(v) model.set("compensation",v) end,"hearing"),
      number_slider("equalizer-strength","Strength",inner,function() return model.current("strength") end,
        function(v) model.set_current("strength",v) end,0,100,"%"),
      flag("equalizer-per-ear","Separate left / right","Each ear its own curve",inner,
        function() return model.current("per_ear") end,function(v) model.set_current("per_ear",v) end,"hearing"),
      P.row {id="equalizer-audiogram",width=inner,icon="graphic_eq",title="Audiogram",
        subtitle=function() return model.get("profile.label") end,trailing=P.chevron(),on_clicked=model.open_editor},
      note("Enter existing measured thresholds. This adjusts listening audio; it does not measure hearing.",inner),
    },
    P.section(bands),
    P.section {id="equalizer-headroom",width=w,title="Output headroom",
      number_slider("equalizer-trim","Additional attenuation",inner,function() return model.current("trim") end,
        function(v) model.set_current("trim",v) end,-24,0," dB"),
      note("Automatic attenuation includes overlapping boosts. It is not a limiter.",inner),
    },
  }
end
function M.audiogram(model,w,h)
  local inner=P.inner(w)
  local function input(id,ear,index,width)
    local name=ear=="label" and "Profile name"
      or ("%s ear at %s Hz"):format(ear=="left" and "Left" or "Right",tostring(model.frequencies[index]))
    local node_node = kit.text_field("numeric_entry", {id=id,accessible_name=name,width=width-16,height=30,x=8,
      text=function() local draft=model.draft:get() return tostring(ear=="label" and draft.label or draft[ear][index]) end,
      font_family=theme.font,font_size=theme.size.normal,color=function() return C.onSurface end,
      caret_color=function() return C.primary end,selection_color=function() return C.primary:alpha(.25) end,
      on_text_changed=function(value) model.edit(ear,index,value) end})
    return rows.well {width=width,height=34,node_node}
  end
  local col=math.floor((inner-80)/2)
  local table_rows={width=inner,gap=8}
  table_rows[#table_rows+1]=ui.Row {width=inner,gap=8,
    kit.subtitle {width=64,text="Hz",font_size=theme.size.small,color=kit.ink("lo")},
    kit.subtitle {width=col,text="Left · dB HL",elide="right",font_size=theme.size.small,color=kit.ink("lo")},
    kit.subtitle {width=col,text="Right · dB HL",elide="right",font_size=theme.size.small,color=kit.ink("lo")}}
  for i,hz in ipairs(model.frequencies) do
    table_rows[#table_rows+1]=ui.Row {width=inner,gap=8,align="center",
      kit.text {width=64,text=tostring(hz),font_size=theme.size.normal},
      input("audiogram-left-"..i,"left",i,col),
      input("audiogram-right-"..i,"right",i,col)}
  end
  return P.page {id="audiogram-scroll",width=w,height=h,
    P.section {id="audiogram-profile",width=w,title="Profile",
      input("audiogram-label","label",nil,inner),
      note("Copy an existing audiogram. Values can range from −10 to 120 dB HL; blank profiles start at zero.",inner)},
    P.section {id="audiogram-editor",width=w,title="Measured thresholds",
      ui.Column(table_rows),
      note(function() return model.editor_error:get() end,inner),
      ui.Item {width=1,height=4},
      centred(inner,{id="audiogram-save",icon="save",label="Save audiogram",tone="primary",on_clicked=model.save_profile}),
      note("Back discards unsaved edits.",inner)},
  }
end
return M
