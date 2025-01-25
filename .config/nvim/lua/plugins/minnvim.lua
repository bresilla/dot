return {
    {
        { 
            'echasnovski/mini.nvim', 
            version = '*', 
            config = function()
                require('mini.surround').setup({ })
                require('mini.pairs').setup({ })
                require('mini.jump2d').setup({ })
                -- require('mini.indentscope').setup({ })
                require('mini.move').setup({
                    mappings = {
                        -- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
                        left = '<M-S-Left>',
                        right = '<M-S-Right>',
                        down = '<M-S-Down>',
                        up = '<M-S-Up>',
                        -- Move current line in Normal mode
                        line_left = '<M-S-Left>',
                        line_right = '<M-S-Right>',
                        line_down = '<M-S-Down>',
                        line_up = '<M-S-Up>',
                    },
                    -- Options which control moving behavior
                    options = {
                        -- Automatically reindent selection during linewise vertical move
                        reindent_linewise = false,
                    },
                })
            end,
        },
    }
}