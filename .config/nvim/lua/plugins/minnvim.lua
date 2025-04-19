return {
    {
        { 
            'echasnovski/mini.nvim', 
            version = '*', 
            config = function()
                require('mini.surround').setup({ })
                require('mini.pairs').setup({ })
                -- require('mini.jump2d').setup({ })
                require('mini.ai').setup({ })
                require('mini.comment').setup({
                      -- Module mappings. Use `''` (empty string) to disable one.
                    mappings = {
                        comment_line = '#',
                        comment_visual = '#',
                        textobject = '#',
                    },
                })
                -- require('mini.indentscope').setup({ })
                require('mini.move').setup({
                    mappings = {
                        -- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
                        left = '<M-C-Left>',
                        right = '<M-C-Right>',
                        down = '<M-C-Down>',
                        up = '<M-C-Up>',
                        -- Move current line in Normal mode
                        line_left = '<M-C-Left>',
                        line_right = '<M-C-Right>',
                        line_down = '<M-C-Down>',
                        line_up = '<M-C-Up>',
                    },
                    options = {
                        reindent_linewise = true,
                    },
                })
            end,
        },
    }
}
