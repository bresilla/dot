-- The controller supplies shared Lule state; themes own all composition.
local view=require("themes").view("lule_page")
local model=require("lule_model").new()
local visual=view.build(model)
return {WIDTH=view.WIDTH,HEIGHT=view.HEIGHT,page=visual.page,
  width=visual.width or view.WIDTH,height=visual.height or view.HEIGHT,resize=visual.resize}
