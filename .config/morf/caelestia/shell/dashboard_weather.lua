-- Weather controller: one service model, with replaceable visual builders.
local source=require("weather_model")
local view=require("themes").view("dashboard_weather")
local model=source.new(require("dashboard_state").context(5))
local visual=view.build(model)
return {WIDTH=view.WIDTH,HEIGHT=view.HEIGHT,page=visual.page,
  width=visual.width or view.WIDTH,height=visual.height or view.HEIGHT,
  resize=visual.resize,place_name=source.place_name,clock=source.clock}
