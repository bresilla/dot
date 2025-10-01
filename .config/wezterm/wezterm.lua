local wezterm = require 'wezterm'
local conf = wezterm.config_builder()

conf.enable_tab_bar = false

conf.font = wezterm.font('GohuFont 14 Nerd Font Mono')
conf.font_size = 18

return conf
