function term(cmd)
    local newterm = require('toggleterm.terminal').Terminal:new({
        cmd = cmd,
        dir = "git_dir",
        -- shade_filetypes = {},
        -- shade_terminals = false,
        hide_numbers = true,
        start_in_insert = true,
        insert_mappings = true,
        close_on_exit = true,
        shell = vim.o.shell,
        direction = "float",
        highlights = {
            NormalFloat = {
                link = 'ToggleTermNormalFloat',
            },
            Normal = {
                link = 'ToggleTermNormal',
            },
            FloatBorder = {
                link = 'ToggleTermFloatBorder',
            },
        },
        float_opts = {
            border = 'rounded',
            width = function(term)
                return math.floor(vim.o.columns * 0.8)
              end,
            height = function(term)
                return math.floor(vim.o.lines * 0.7)
              end,
            winblend = 0,
        },
        -- function to run on opening the terminal
        on_open = function(term)
            vim.cmd("startinsert!")
            vim.api.nvim_buf_set_keymap(term.bufnr, "i", "<ESC>", "<cmd>close<CR>", {noremap = true, silent = true})
            vim.api.nvim_buf_set_keymap(term.bufnr, "n", "<ESC>", "<cmd>close<CR>", {noremap = true, silent = true})
            vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<ESC>", "<cmd>close<CR>", {noremap = true, silent = true})

            vim.api.nvim_buf_set_keymap(term.bufnr, "i", "<CR>", "<cmd>close<CR>", {noremap = true, silent = true})
            vim.api.nvim_buf_set_keymap(term.bufnr, "n", "<CR>", "<cmd>close<CR>", {noremap = true, silent = true})
            vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<CR>", "<cmd>close<CR>", {noremap = true, silent = true})
        end,
        on_close = function(term) -- function to run on closing the terminal
            vim.cmd("CloseTerminal")
        end,
    })
    newterm:toggle()
end

vim.keymap.set({'n', 'i'}, '<F7>', [[<CMD>lua term('build')<CR>]], {noremap = true, silent = true})
vim.keymap.set('t', '<F7>', [[<CMD>ToggleTerm<CR>]], {noremap = true, silent = true})


return{    
    {
        -- amongst your other plugins
        'akinsho/toggleterm.nvim', 
        version = "*", 
        config = function()
            local tterm = require("toggleterm")
            tterm.setup({})
        end,
    },
}
