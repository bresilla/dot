local model=require("equalizer_model")
local view=require("themes").view("equalizer_page")
return {page=function(w,h) return view.build(model,w,h) end,
  audiogram=function(w,h) return view.audiogram(model,w,h) end}
