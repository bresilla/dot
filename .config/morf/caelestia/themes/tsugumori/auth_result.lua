local morf=require("morf")
return function(theme)
  local registration=require("themes.tsugumori.registration")(theme)
  return function(host,id,spec)
    local cue=registration(host,id)
    local previous
    morf.effect(id..".result-cue."..(spec.scope or ""),function()
      if not spec.active() then previous=nil cue(nil) return end
      local state,key=spec.read()
      local token=tostring(state)..":"..tostring(key or "")
      if token==previous then return end
      previous=token
      local success=state=="done" or state=="ok" or state=="opening"
      local failure=state=="wrong" or state=="refused" or state=="failed"
      cue(success and "success" or failure and "failure" or nil)
    end,{owner=host})
  end
end
