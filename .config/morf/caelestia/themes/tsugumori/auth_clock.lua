-- A finite mechanical roll on entry and when a digit actually changes.
-- The clock signal still comes from the controller; no polling, no new timer.
local morf=require("morf")
local ui=require("morf.ui")
return function(ctx)
  return function(props)
    local id,size,source=props.id,props.font_size,props.text
    local function value() return type(source)=="function" and source() or source end
    local row=ui.Row {id=id,gap=0}
    local handles,previous={},nil
    local glyphs,slots={},{}
    for i=1,5 do
      local function glyph(suffix)
        return ctx.text {id=id.."-"..i..suffix,text=value():sub(i,i),font_size=size,
          font_weight=props.font_weight,color=props.color}
      end
      local old,new=glyph("-old"),glyph("-digit")
      local strip=ui.Item {old,new}
      local cell=ui.Item {id=id.."-cell-"..i,clip=true,
        width=function() return new.layout_width or size*.6 end,
        height=function() return new.layout_height or size*1.3 end,strip}
      old.y=function() return -(new.layout_height or size*1.3) end
      ui.reparent(cell,row)
      glyphs[i]={old,new} slots[i]=strip
    end
    morf.effect(id..".roll."..(ctx.output_name or ""),function()
      local time=value()
      local showing=ctx.stage:get()=="rest" or ctx.stage:get()=="sheet"
      if not showing then previous=nil return end
      if time==previous then return end
      for i=1,5 do
        local letter=time:sub(i,i)
        if not previous or letter~=previous:sub(i,i) then
          if handles[i] then handles[i]:stop() end
          local old,new=glyphs[i][1],glyphs[i][2]
          old.text=previous and previous:sub(i,i) or (i==3 and ":" or "/")
          new.text=letter
          handles[i]=morf.animation.play {{node=slots[i],property="translate_y",
            from=new.layout_height or size*1.3,to=0,
            delay=previous and 0 or 60+(i-1)*28,duration=230,easing="out_expo"}}
        end
      end
      previous=time
    end,{owner=row})
    return row
  end
end
