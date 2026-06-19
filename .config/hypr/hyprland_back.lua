local home = assert(os.getenv("HOME"), "HOME is not set")
local config_dir = home .. "/.config/hypr"
local util = dofile(config_dir .. "/lua/lib.lua")

local ctx = {
    home = home,
    config_dir = config_dir,
    util = util,
}

dofile(config_dir .. "/lua/env.lua")(ctx)
dofile(config_dir .. "/lua/monitors.lua")(ctx)
dofile(config_dir .. "/lua/options.lua")(ctx)
dofile(config_dir .. "/lua/rules.lua")(ctx)
dofile(config_dir .. "/lua/startup.lua")(ctx)
dofile(config_dir .. "/lua/binds.lua")(ctx)
