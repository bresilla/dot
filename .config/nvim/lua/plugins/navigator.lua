return {
    -- {
    --     'numToStr/Navigator.nvim',
    --     config = function()
    --         local navigator = require('Navigator')
    --         navigator.setup({
    --             auto_save = 'current'
    --         })
    --
    --         vim.keymap.set('n', '<C-l>', [[<CMD>lua require('Navigator').right()<CR>]], {silent = true })
    --         vim.keymap.set('i', '<C-l>', [[<CMD>lua require('Navigator').right()<CR>]], {silent = true })
    --         -- vim.keymap.set('n', '<C-Right>', [[<CMD>lua require('Navigator').right()<CR>]], {silent = true })
    --         -- vim.keymap.set('i', '<C-Right>', [[<CMD>lua require('Navigator').right()<CR>]], {silent = true })
    --
    --         vim.keymap.set('n', '<C-h>', [[<CMD>lua require('Navigator').left()<CR>]], {silent = true })
    --         vim.keymap.set('i', '<C-h>', [[<CMD>lua require('Navigator').left()<CR>]], {silent = true })
    --         -- vim.keymap.set('n', '<C-Left>', [[<CMD>lua require('Navigator').left()<CR>]], {silent = true })
    --         -- vim.keymap.set('i', '<C-Left>', [[<CMD>lua require('Navigator').left()<CR>]], {silent = true })
    --
    --         vim.keymap.set('n', '<C-j>', [[<CMD>lua require('Navigator').down()<CR>]], {silent = true })
    --         vim.keymap.set('i', '<C-j>', [[<CMD>lua require('Navigator').down()<CR>]], {silent = true })
    --         -- vim.keymap.set('n', '<C-Down>', [[<CMD>lua require('Navigator').down()<CR>]], {silent = true })
    --         -- vim.keymap.set('i', '<C-Down>', [[<CMD>lua require('Navigator').down()<CR>]], {silent = true })
    --
    --         vim.keymap.set('n', '<C-k>', [[<CMD>lua require('Navigator').up()<CR>]], {silent = true })
    --         vim.keymap.set('i', '<C-k>', [[<CMD>lua require('Navigator').up()<CR>]], {silent = true })
    --         -- vim.keymap.set('n', '<C-Up>', [[<CMD>lua require('Navigator').up()<CR>]], {silent = true })
    --         -- vim.keymap.set('i', '<C-Up>', [[<CMD>lua require('Navigator').up()<CR>]], {silent = true })
    --     end
    -- },
    { 'alexghergh/nvim-tmux-navigation', config = function()

        local nvim_tmux_nav = require('nvim-tmux-navigation')

            nvim_tmux_nav.setup {
                disable_when_zoomed = true -- defaults to false
            }

            vim.keymap.set('n', "<C-h>", nvim_tmux_nav.NvimTmuxNavigateLeft)
            vim.keymap.set('n', "<C-j>", nvim_tmux_nav.NvimTmuxNavigateDown)
            vim.keymap.set('n', "<C-k>", nvim_tmux_nav.NvimTmuxNavigateUp)
            vim.keymap.set('n', "<C-l>", nvim_tmux_nav.NvimTmuxNavigateRight)
        end
    }
}
