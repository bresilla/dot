return {
    {
        'numToStr/Navigator.nvim',
        config = function()
            local navigator = require('Navigator')
            navigator.setup({
                auto_save = 'current'
            })

            vim.keymap.set('n', '<C-l>', [[<CMD>lua require('Navigator').right()<CR>]], {silent = true })
            vim.keymap.set('i', '<C-l>', [[<CMD>lua require('Navigator').right()<CR>]], {silent = true })

            vim.keymap.set('n', '<C-h>', [[<CMD>lua require('Navigator').left()<CR>]], {silent = true })
            vim.keymap.set('i', '<C-h>', [[<CMD>lua require('Navigator').left()<CR>]], {silent = true })

            vim.keymap.set('n', '<C-j>', [[<CMD>lua require('Navigator').down()<CR>]], {silent = true })
            vim.keymap.set('i', '<C-j>', [[<CMD>lua require('Navigator').down()<CR>]], {silent = true })

            vim.keymap.set('n', '<C-k>', [[<CMD>lua require('Navigator').up()<CR>]], {silent = true })
            vim.keymap.set('i', '<C-k>', [[<CMD>lua require('Navigator').up()<CR>]], {silent = true })
        end
    }
}