return {
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
            local lualine = require('lualine')
            lualine.setup {
                options = {
                    icons_enabled = true,
                    theme = '16color',
                    component_separators = { left = '|', right = '|'},
                    section_separators = { left = '', right = ''},
                    disabled_filetypes = {
                        statusline = {},
                        winbar = {},
                    },
                    ignore_focus = {},
                    always_divide_middle = true,
                    always_show_tabline = true,
                    globalstatus = true,
                    refresh = {
                        statusline = 100,
                        tabline = 100,
                        winbar = 100,
                    }
                },
                sections = {
                    lualine_a = {
                        {'mode', color = 'LuaLineMode'}
                    },
                    -- lualine_b = {'branch', 'diff', 'diagnostics'},
                    lualine_b = {
                        {"branch", color = "LuaLineBranch"},
                        {"diff", color = "LuaLineDiff"},
                        {"diagnostics", color = "LuaLineDiagnostic"},
                    },
                    -- lualine_c = {'filename'},
                    lualine_c = {
                        {"filename", color = "LuaLineFilename"},
                    },
                    -- lualine_x = {'encoding', 'fileformat', 'filetype'},
                    lualine_x = {
                        {"encoding", color = "LuaLineEncoding"},
                        {"fileformat", color = "LuaLineFileFormat"},
                        {"filetype", color = "LuaLineFileType"},
                    },
                    -- lualine_y = {'progress'},
                    lualine_y = {
                        {"progress", color = "LuaLineProgress"},
                    },
                    -- lualine_z = {'location'}
                    lualine_z = {
                        {'location', color = 'LuaLineLocation'}
                    },
                },
                inactive_sections = {
                    lualine_a = {},
                    lualine_b = {},
                    -- lualine_c = {'filename'},
                    lualine_c = {
                        {"filename", color = "LuaLineFilename"},
                    },
                    -- lualine_x = {'location'},
                    lualine_x = {
                        {'location', color = 'LuaLineLocation'}
                    },
                    lualine_y = {},
                    lualine_z = {}
                },
                tabline = {},
                winbar = {},
                inactive_winbar = {},
                extensions = {}
            } 
        end,
    }
}
