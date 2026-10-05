-- Device selection and services stay shared across visual packages.
local source=require("performance_model")
local model=source.new(require("dashboard_state").context(3))
local view=require("themes").view("dashboard_performance")
local visual=view.build(model)
return {WIDTH=view.WIDTH,HEIGHT=view.HEIGHT,page=visual.page,
  width=visual.width or view.WIDTH,height=visual.height or view.HEIGHT,resize=visual.resize,navigation=visual.navigation,
  cpu_name=source.cpu_name,disk_of=source.disk_of,disks=source.disks,process_count=source.process_count}
