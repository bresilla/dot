c_header = {
    '                            ▄▄▄▄▄▄▄▄                             ' ,
    '                       ▄▄██████████████▄▄                        ' ,
    '                    ▄██████████████████████▄                     ' ,
    '                  ▄██████████████████████████▄                   ' ,
    '                ▄█▀▄████████████████████████▄▀█▄                 ' ,
    '               ▄█  ██████████████████████████  █▄                ' ,
    '              ▄█▀ ▄██████████████████████████▄ ▀█▄               ' ,
    '              █▀  ████████████████████████████  ▀█               ' ,
    '                ▄██████████████████████████████▄                 ' ,
    '              ████████████████████████████████████               ' ,
    '              ████████████████████████████████████               ' ,
    '              ▀██▀  ▀▀████████████████████▀▀  ▀██▀               ' ,
    '               ██       ▀██▀████████▀██▀       ██                ' ,
    '                ██        ▀█ ██████ █▀        ██                 ' ,
    '                 ██▄        █ ████ █        ▄██                  ' ,
    '                  ███▄▄▄     █ ██ █     ▄▄▄███                   ' ,
    '                   ▀▀▀▀▀████▄██████▄████▀▀▀▀▀                    ' ,
    '                      █▄ █████▄██▄█████ ▄█                       ' ,
    '                      ██▄ ████████████ ▄██                       ' ,
    '                       ▀█████▀▄▄▄▄▀█████▀                        ' ,
    '                         ▀▀██████████▀▀                          ' ,
    '                            ▀██████▀                             ' ,
    '▄                                                 ▄ ▄            ' ,
    '█                                                 █ █            ' ,
    '█▀▀▀▀▀▀▀▀▀█ █▀▀▀▀▀▀▀▀▀▀ █▀▀▀▀▀▀▀▀▀█ █▀▀▀▀▀▀▀▀▀▀ █ █ █ ▀▀▀▀▀▀▀▀▀▀█' ,
    '█         █ █           █▀▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀█ █ █ █ █▀▀▀▀▀▀▀▀▀█' ,
    '▀▀▀▀▀▀▀▀▀▀▀ ▀           ▀▀▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀▀ ▀ ▀ ▀ ▀▀▀▀▀▀▀▀▀▀▀' ,
    '                                                                 ' ,
}
local c_footer = {
    "LESS IS SIGNIFICANTLY MORE"
}


local c_center = {    
  { action = 'lua require("persistence").load()', desc = " Restore Session", icon = "", key = "s", key_format = "%s" },
  { action = "qa", desc = " Quit", icon = "", key = "q", key_format = "%s" },
}

return {
    {
       'nvimdev/dashboard-nvim',
        event = 'VimEnter',
        config = function()
            require('dashboard').setup({
                theme = "hyper",
                config = {
                    header = c_header,
                    shortcut = c_center,
                    footer = c_footer,
                    packages = { enable = false },
                    project = { enable = false },
                    mru = { enable = false },
                },
                hide = {
                    statusline,       -- hide statusline default is true
                    tabline   ,       -- hide the tabline
                    winbar    ,       -- hide winbar
                },
            })
        end,
        lazy = false,
        dependencies = { {'nvim-tree/nvim-web-devicons'}},
    },
}
