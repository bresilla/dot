-- Define a Lua function to conditionally handle the 'n' key press
-- This function will check if there's an active search pattern
-- If there's no active search pattern, it will set one using the current word under the cursor
local function conditional_search_next()
    local search_pattern = vim.fn.getreg('/')
    if search_pattern == "" then
        local current_word = vim.fn.expand('<cword>')
        -- if #(current_word) > 1 then
        if string.match(current_word, "^%w") then
            local escaped_word = vim.fn.escape(current_word, '\\/.*[]~$^')
            vim.fn.setreg('/', '\\<' .. escaped_word .. '\\>')
            vim.o.hlsearch = true
            require('hlslens').start()
            vim.cmd('normal! n')
        end
    else    
        vim.cmd('normal! n')
    end
end

vim.keymap.set('n', 'n', conditional_search_next, { noremap = true, silent = true })

return {
    {
        "RRethy/vim-illuminate",
        event = "BufRead",
        config = function()
            local illuminate = require("illuminate")
            illuminate.configure({
                providers = {
                    'treesitter',
                    'regex',
                    'lsp',
                },
            })
        end,
    },
    {
        'kevinhwang91/nvim-hlslens',
        config = function()
            local hlslens = require('hlslens')
            hlslens.setup({
                override_lens = "relIdx",
                build_position_cb = function(plist, _, _, _)
                    require("scrollbar.handlers.search").handler.show(plist.start_pos)
                end,
            })
        end,
    }
}
